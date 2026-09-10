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

check() {
  local label="$1" expected="$2" command="$3" actual stderr
  stderr="$(printf '%s' "$command" \
    | CLAUDE_PROJECT_DIR="$project" python3 "$hook" 2>&1 >/dev/null)"
  actual=$?
  # The pipeline's exit status is python3's, captured via PIPESTATUS on bash 3.2.
  actual="${PIPESTATUS[1]:-$actual}"
  if [ "$actual" = "$expected" ]; then
    passes=$((passes + 1))
    printf 'ok    %s\n' "$label"
  else
    failures=$((failures + 1))
    printf 'FAIL  %s (expected %s, got %s) %s\n' "$label" "$expected" "$actual" "$stderr"
  fi
}

payload() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "cwd": sys.argv[1],
                  "tool_input": {"command": sys.argv[2]}}))' "$project" "$1"
}

# --- allowed ---------------------------------------------------------------
check "in-project delete"        0 "$(payload 'rm -rf node_modules dist')"
check "explicit temp path"       0 "$(payload 'rm -rf /tmp/scratch.abc')"
check "set variable"             0 "$(payload 'rm -rf "$TMPDIR/stage"')"
check "not a delete"             0 "$(payload 'ls -la ~ && cat /etc/hosts')"
check "non-recursive rm"         0 "$(payload 'rm ~/notes.txt')"
check "redirect to outside file" 0 "$(payload 'rm -rf build > ~/log.txt')"
check "other tool"               0 '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
check "malformed payload"        0 'not json at all'
check "apostrophe in heredoc"    0 "$(payload "git commit -F - <<'EOF'
Conductor's application support dir
EOF")"
check "heredoc mentions delete"  0 "$(payload "git commit -F - <<'EOF'
we ran rm -rf ~/Developer by mistake
EOF")"

# --- denied ----------------------------------------------------------------
check "home dotdir"              2 "$(payload 'rm -rf ~/.claude')"
check "HOME variable"            2 "$(payload 'rm -rf $HOME/Developer')"
check "unset variable"           2 "$(payload 'rm -rf "$NOT_SET_ANYWHERE/stuff"')"
check "command substitution"     2 "$(payload 'rm -rf "$(cat target.txt)"')"
check "chained after install"    2 "$(payload 'pnpm i && rm -rf ~/Developer/github.com')"
check "parent escape"            2 "$(payload 'rm -rf ../..')"
check "home glob"                2 "$(payload 'rm -rf ~/*')"
check "project root itself"      2 "$(payload 'rm -rf .')"
check "temp root itself"         2 "$(payload 'rm -rf /tmp')"
check "find -delete outside"     2 "$(payload 'find ~/Developer -name node_modules -delete')"
check "rsync --delete outside"   2 "$(payload 'rsync -a --delete src/ ~/Developer/dst/')"
check "delete after heredoc"     2 "$(payload "git commit -F - <<'EOF'
msg
EOF
rm -rf ~/.claude")"
check "unparseable with delete"  2 "$(payload "rm -rf ~/Developer 'unbalanced")"

printf '\n%s passed, %s failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
