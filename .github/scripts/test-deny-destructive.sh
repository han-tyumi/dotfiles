#!/usr/bin/env bash
# Exercise the deny-destructive PreToolUse hook against the tool-call payloads
# Claude Code would hand it. Run directly, or from CI:
#   bash .github/scripts/test-deny-destructive.sh
#
# Fixtures live in this file rather than being passed on a command line, because
# some of them are themselves destructive commands and would be caught by the
# very hook under test.

set -uo pipefail

hook="${1:-$(cd "$(dirname "$0")/../.." && pwd)/dot_claude/hooks/executable_deny-destructive.py}"
[ -f "$hook" ] || { echo "hook not found: $hook" >&2; exit 1; }

# Deliberately not under mktemp's directory: the hook exempts system temp dirs,
# so a project rooted there would make `rm -rf ../..` legitimately allowed and
# the parent-escape case untestable.
sandbox="$HOME/.cache/deny-destructive-test.$$"
project="$sandbox/project"
mkdir -p "$project"
trap 'rm -rf "$sandbox"' EXIT

passes=0
failures=0

# One of three outcomes: allow (silent pass), ask (the approval prompt, decided
# by the person at the keyboard), deny (refused outright, exit 2).
outcome() {
  local command="$1" status stdout
  shift
  stdout="$(printf '%s' "$command" \
    | CLAUDE_PROJECT_DIR="$project" python3 "$hook" "$@" 2>/dev/null)"
  status=$?
  # The pipeline's exit status is python3's, captured via PIPESTATUS on bash 3.2.
  status="${PIPESTATUS[1]:-$status}"
  case "$status" in
    0) case "$stdout" in
         *'"permissionDecision": "ask"'*) echo ask ;;
         "") echo allow ;;
         *) echo "unexpected-stdout:$stdout" ;;
       esac ;;
    2) echo deny ;;
    *) echo "error-exit-$status" ;;
  esac
}

check() {
  local label="$1" expected="$2" command="$3" actual
  shift 3
  actual="$(outcome "$command" "$@")"
  if [ "$actual" = "$expected" ]; then
    passes=$((passes + 1))
    printf 'ok    %s\n' "$label"
  else
    failures=$((failures + 1))
    printf 'FAIL  %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
  fi
}

payload() {
  python3 -c '
import json, sys
payload = {"tool_name": "Bash", "cwd": sys.argv[1],
           "tool_input": {"command": sys.argv[2]}}
if len(sys.argv) > 3:
    payload["permission_mode"] = sys.argv[3]
print(json.dumps(payload))' "$project" "$1" ${2+"$2"}
}

# --- allowed silently ------------------------------------------------------
check "in-project delete"        allow "$(payload 'rm -rf node_modules dist')"
check "explicit temp path"       allow "$(payload 'rm -rf /tmp/scratch.abc')"
check "set variable"             allow "$(payload 'rm -rf "$TMPDIR/stage"')"
check "not a delete"             allow "$(payload 'ls -la ~ && cat /etc/hosts')"
check "non-recursive rm"         allow "$(payload 'rm ~/notes.txt')"
check "redirect to outside file" allow "$(payload 'rm -rf build > ~/log.txt')"
check "other tool"               allow '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
check "malformed payload"        allow 'not json at all'
check "apostrophe in heredoc"    allow "$(payload "git commit -F - <<'EOF'
Conductor's application support dir
EOF")"
check "heredoc mentions delete"  allow "$(payload "git commit -F - <<'EOF'
we ran rm -rf ~/Developer by mistake
EOF")"

# --- asked (approvable: outside the project, but plausibly meant) -----------
check "home dotdir"              ask "$(payload 'rm -rf ~/.claude')"
check "HOME variable"            ask "$(payload 'rm -rf $HOME/Developer')"
check "unset variable"           ask "$(payload 'rm -rf "$NOT_SET_ANYWHERE/stuff"')"
check "command substitution"     ask "$(payload 'rm -rf "$(cat target.txt)"')"
check "chained after install"    ask "$(payload 'pnpm i && rm -rf ~/Developer/github.com')"
check "parent escape"            ask "$(payload 'rm -rf ../..')"
check "project root itself"      ask "$(payload 'rm -rf .')"
check "find -delete outside"     ask "$(payload 'find ~/Developer -name node_modules -delete')"
check "rsync --delete outside"   ask "$(payload 'rsync -a --delete src/ ~/Developer/dst/')"
check "delete after heredoc"     ask "$(payload "git commit -F - <<'EOF'
msg
EOF
rm -rf ~/.claude")"
check "unparseable with delete"  ask "$(payload "rm -rf ~/Developer 'unbalanced")"
check "unparseable line, delete elsewhere" ask "$(payload "echo 'unbalanced
rm -rf ~/.claude")"

# An unreadable line next to an in-project delete must not stop the delete:
# quoting the hook cannot follow says nothing about the other line's targets.
check "unparseable line, safe delete" allow "$(payload "python3 -c 'print(\"it'\"'\"'s\")
rm -rf /tmp/scratch.abc")"

# --- denied outright (no approval can authorise these) ----------------------
check "home itself"              deny "$(payload 'rm -rf ~')"
check "HOME variable itself"     deny "$(payload 'rm -rf "$HOME"')"
check "home glob"                deny "$(payload 'rm -rf ~/*')"
check "filesystem root"          deny "$(payload 'rm -rf /')"
check "root glob"                deny "$(payload 'rm -rf /*')"
check "system directory"         deny "$(payload 'rm -rf /usr')"
check "users directory"          deny "$(payload 'rm -rf /Users')"
check "temp root itself"         deny "$(payload 'rm -rf /tmp')"
check "find -delete on home"     deny "$(payload 'find ~ -name .DS_Store -delete')"

# A refusal outranks a question anywhere in the same command.
check "safe delete then home"    deny "$(payload 'rm -rf dist && rm -rf ~')"
check "question then refusal"    deny "$(payload 'rm -rf ~/.cache/x && rm -rf /usr')"

# --- when nothing will prompt, the question becomes a refusal ----------------
check "bypassPermissions refuses" deny "$(payload 'rm -rf ~/.claude' bypassPermissions)"
check "bypassPermissions still allows in-project" allow \
  "$(payload 'rm -rf dist' bypassPermissions)"
check "prompting mode asks"       ask "$(payload 'rm -rf ~/.claude' default)"
check "acceptEdits mode asks"     ask "$(payload 'rm -rf ~/.claude' acceptEdits)"
check "no-prompt caller refuses"  deny "$(payload 'rm -rf ~/.claude')" --no-prompt
check "no-prompt caller, in-project" allow "$(payload 'rm -rf dist')" --no-prompt

printf '\n%s passed, %s failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
