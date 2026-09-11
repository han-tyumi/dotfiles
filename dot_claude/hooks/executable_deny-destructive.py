#!/usr/bin/env python3
"""Gate recursive deletes that reach outside the project an agent is working in.

Claude Code feeds a PreToolUse hook the pending tool call as JSON on stdin.
There are three answers: exit 0 to allow silently, a `permissionDecision` of
`ask` on stdout to route the command through the normal approval prompt, and
exit 2 to refuse outright with a reason on stderr the model can act on.

Reaching outside the project is a question, not a verdict — deleting a stale
clone or a cache under `~` is ordinary work, and only the person at the keyboard
knows whether this particular one was meant. So the default answer is `ask`.

Exit 2 is reserved for targets no confirmation should be able to authorise: the
whole account, the OS, a system directory.

An `ask` decision only reaches a human if something is willing to prompt, and
`permission_mode: bypassPermissions` is not — it turns every question into a
silent yes. Where the payload says nothing will ask, the question is put in a
macOS confirmation dialog instead, and anything but an explicit approval
(declined, timed out, no GUI to draw on) is a refusal. The harness's own prompt
is always preferred: it renders the command better and needs no window.

Python rather than shell because the decision hinges on tokenising a command
line correctly — `shlex` respects quoting and shell operators, where bash word
splitting would mis-read `rm -rf "$dir/a b"` and anything chained with `&&`.

Unresolvable targets are asked about rather than passed silently: a path built
from a variable this hook cannot expand is exactly the case that goes wrong.

Two flags, both of which can only make the answer stricter:
  --no-prompt  the caller cannot render an `ask` decision, so fall back to the
               dialog (the OpenCode plugin reuses this hook through its exit
               status alone).
  --no-dialog  never open a dialog; refuse instead. What the test suite uses to
               exercise the unanswerable case without opening windows.
"""

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

# Captures the name in $VAR and ${VAR} as an alternating split() group.
VARIABLE_PATTERN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")

# Commands whose recursive form can destroy a tree, and the flags that arm them.
RECURSIVE_LONG_FLAGS = {"--recursive", "--dir", "--delete", "--delete-before",
                        "--delete-during", "--delete-after", "--delete-excluded"}
GLOB_CHARS = ("*", "?", "[")
SEPARATORS = {";", "&&", "||", "|", "&"}
# A redirection operator and the filename after it are not delete targets.
REDIRECTIONS = {"<", "<<", "<<<", ">", ">>", ">|", "&>", "&>>", "2>", "2>>"}
HEREDOC_PATTERN = re.compile(r"<<-?\s*['\"]?(?P<delimiter>[A-Za-z_][A-Za-z0-9_]*)['\"]?")
# `find [global options] path... [expression]`: the paths end at the first
# primary, and only they are operands. `{}` stands for whatever find matched.
FIND_GLOBAL_OPTIONS = {"-E", "-H", "-L", "-P", "-X", "-d", "-s", "-x"}
FIND_EXPRESSION_START = {"!", "(", ")", ","}
FIND_EXEC_PRIMARIES = {"-exec", "-execdir", "-ok", "-okdir"}
FIND_EXEC_TERMINATORS = {";", "+"}
FIND_PLACEHOLDER = "{}"
LINE_CONTINUATION = re.compile(r"\\\n")
# Used only when the command cannot be tokenised: does it even mention a
# recursive delete? If not, a parse failure is harmless.
DESTRUCTIVE_HINT = re.compile(
    r"(^|[\s;&|(])(rm\s+(-\w*[rR]|--recursive)|find\s.*-delete|rsync\s.*--delete)"
)


def strip_heredocs(command):
    """Remove heredoc bodies, which are data rather than commands.

    Without this, prose that merely mentions a destructive command -- a commit
    message, a written note -- gets tokenised as if it were about to run.
    """
    lines = command.split("\n")
    kept, index = [], 0
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        index += 1
        for match in HEREDOC_PATTERN.finditer(line):
            delimiter = match.group("delimiter")
            while index < len(lines) and lines[index].strip() != delimiter:
                index += 1
            index += 1  # drop the delimiter line too
    return "\n".join(kept)


def tokenize(command):
    """Lex a command into per-command argv lists plus the lines that would not lex.

    Newlines separate commands in shell just as `;` does, so each line is lexed
    on its own -- otherwise a command following a heredoc terminator gets folded
    into the argv of the command that opened the heredoc. Lexing per line also
    contains the damage when one line has quoting this hook cannot follow: the
    rest of the command is still checked properly, and only the unreadable line
    falls back to a textual scan.
    """
    text = LINE_CONTINUATION.sub(" ", strip_heredocs(command))

    commands, unparsed = [], []
    for line in text.split("\n"):
        if not line.strip():
            continue
        lexer = shlex.shlex(line, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        try:
            tokens = list(lexer)
        except ValueError:
            unparsed.append(line)
            continue

        current = []
        for token in tokens:
            if token in SEPARATORS:
                if current:
                    commands.append(current)
                    current = []
            else:
                current.append(token)
        if current:
            commands.append(current)
    return commands, unparsed


def canonical(path):
    """Normalise without requiring the path to exist, resolving symlinks we can."""
    return Path(os.path.realpath(os.path.normpath(str(path))))


def expand(operand, home):
    """Expand ~ and environment variables; None when expansion can't be completed.

    An unset variable is the case that turns `rm -rf "$dir/build"` into
    `rm -rf /build`, so a reference this hook cannot resolve to a non-empty
    value is treated as unresolvable rather than substituted with nothing.
    """
    if operand.startswith("~"):
        operand = home + operand[1:]

    if "$(" in operand or "`" in operand:
        return None

    unresolved = []

    def substitute(match):
        name = match.group(1) or match.group(2)
        value = os.environ.get(name)
        if not value:
            unresolved.append(name)
            return ""
        return value

    operand = VARIABLE_PATTERN.sub(substitute, operand)
    if unresolved or "$" in operand:
        return None
    return operand


def operands_of(argv):
    """Positional arguments, honouring `--` and skipping redirection targets."""
    positional, flags_done, skip_next = [], False, False
    for token in argv[1:]:
        if skip_next:
            skip_next = False
            continue
        if token in REDIRECTIONS:
            skip_next = True
        elif flags_done:
            positional.append(token)
        elif token == "--":
            flags_done = True
        elif token.startswith("-") and token != "-":
            continue
        else:
            positional.append(token)
    return positional


def flags_of(argv):
    return [token for token in argv[1:] if token.startswith("-") and token != "-"]


def find_starting_paths(argv):
    """The paths find searches — every token before its expression begins.

    Reading the whole argv as operands is what makes `-type f` look like a path
    named `f`, and `-exec /bin/ls` like one named `/bin/ls`: neither is a path
    find touches.
    """
    tokens = argv[1:]
    index = 0
    while index < len(tokens) and tokens[index] in FIND_GLOBAL_OPTIONS:
        index += 1

    paths = []
    while index < len(tokens):
        token = tokens[index]
        if token.startswith("-") or token in FIND_EXPRESSION_START:
            break
        paths.append(token)
        index += 1
    return paths


def find_exec_commands(argv):
    """The commands a find expression would run, one argv each.

    A `\\;` terminator lexes to `;`, which has already ended this argv, so only
    a `+` terminator survives into it. The placeholder is dropped rather than
    read as a path, since what it stands for is decided by find's own paths.
    """
    commands, index = [], 1
    while index < len(argv):
        if argv[index] not in FIND_EXEC_PRIMARIES:
            index += 1
            continue
        index += 1
        nested = []
        while index < len(argv) and argv[index] not in FIND_EXEC_TERMINATORS:
            if argv[index] != FIND_PLACEHOLDER:
                nested.append(argv[index])
            index += 1
        if nested:
            commands.append(nested)
    return commands


def nested_commands_of(argv):
    """Commands this command would run in turn, to be judged on their own terms."""
    if os.path.basename(argv[0]) == "find":
        return find_exec_commands(argv)
    return []


def delete_targets(argv):
    if os.path.basename(argv[0]) == "find":
        return find_starting_paths(argv)
    return operands_of(argv)


def is_recursive_rm(argv):
    if os.path.basename(argv[0]) != "rm":
        return False
    for flag in flags_of(argv):
        if flag in RECURSIVE_LONG_FLAGS:
            return True
        if not flag.startswith("--") and "r" in flag.lower():
            return True
    return False


def is_deleting_find(argv):
    """Whether find's own search paths are deletion targets.

    `-delete` says so directly. An `-exec` that deletes says so indirectly: it
    acts on whatever find matched, so the search paths bound the damage even
    though the delete is spelled inside the expression. An `-exec` that does
    anything else -- listing, grepping, copying -- makes find a reader.
    """
    if os.path.basename(argv[0]) != "find":
        return False
    if "-delete" in argv:
        return True
    return any(is_recursive_rm(nested) or is_deleting_rsync(nested)
               for nested in find_exec_commands(argv))


def is_deleting_rsync(argv):
    if os.path.basename(argv[0]) != "rsync":
        return False
    return any(flag.startswith("--delete") for flag in flags_of(argv))


def is_modeled_delete(argv):
    """Whether this hook can read a delete's targets out of the argv itself."""
    return is_recursive_rm(argv) or is_deleting_find(argv) or is_deleting_rsync(argv)


# Directories whose deletion takes the machine, the account or the OS with it.
# No agent task legitimately needs one, so these are refused rather than asked
# about. Paths that merely live under one of them are still only asked about.
UNCONDITIONAL_ROOTS = ["/", "/Applications", "/Library", "/System", "/Users",
                       "/bin", "/cores", "/dev", "/etc", "/nix", "/opt",
                       "/private", "/sbin", "/tmp", "/usr", "/var", "/Volumes"]


def scratch_roots():
    """Temp directories a recursive delete may target: nothing durable lives there."""
    roots = ["/tmp", "/private/tmp", "/var/folders", "/private/var/folders"]
    for variable in ("TMPDIR", "TMP", "TEMP"):
        value = os.environ.get(variable)
        if value:
            roots.append(value)
    return [canonical(root) for root in roots]


def unconditional_reason(operand, target, home):
    """Why this target may not be deleted at all, or None if it is merely a question.

    A glob is measured by the directory it sits in: `rm -rf ~/*` names nothing
    catastrophic on its own, and empties the account.
    """
    protected = [canonical(root) for root in UNCONDITIONAL_ROOTS] + [canonical(home)]

    if target in protected:
        return f"target {operand!r} is {target}"
    if any(char in operand for char in GLOB_CHARS) and target.parent in protected:
        return f"glob {operand!r} would empty {target.parent}"
    return None


def verdict(argv, cwd, project_dir, home):
    """Return (decision, reason) — 'deny' or 'ask' — or None to allow."""
    if not argv:
        return None

    question = None

    if is_modeled_delete(argv):
        question = targets_verdict(argv, cwd, project_dir, home)
        if question and question[0] == "deny":
            return question

    # A command run by another one is judged as the command it is. Without this,
    # `find X -exec /bin/rm -rf Y \;` reports the utility name /bin/rm as its
    # target and never mentions Y, the path actually at risk. Its own paths are
    # the better reason when there is one, so it only fills in for their silence.
    for nested in nested_commands_of(argv):
        answer = verdict(nested, cwd, project_dir, home)
        # A delete reached through a wrapper -- `sh -c 'rm -rf ...'` -- has no
        # argv this hook can read targets out of, so its mere presence is the
        # question. A delete this hook does model has already been judged above
        # on its actual targets, and re-asking on the text would undo that.
        if (answer is None and not is_modeled_delete(nested)
                and DESTRUCTIVE_HINT.search(" ".join(nested))):
            answer = ("ask", f"-exec runs {' '.join(nested)!r}, which deletes "
                             f"recursively by a route this hook cannot resolve "
                             f"to a path")
        if answer and answer[0] == "deny":
            return answer
        question = question or answer

    return question


def targets_verdict(argv, cwd, project_dir, home):
    """Judge one delete command by the operands it would act on."""
    scratch = scratch_roots()
    question = None

    for operand in delete_targets(argv):
        expanded = expand(operand, home)
        if expanded is None:
            question = question or (
                "ask", f"target {operand!r} depends on an expansion this hook cannot "
                       f"evaluate, so it cannot be shown to stay inside {project_dir}")
            continue

        target = canonical(Path(expanded) if os.path.isabs(expanded)
                           else Path(cwd) / expanded)

        refusal = unconditional_reason(operand, target, home)
        if refusal:
            return "deny", refusal

        if question:
            continue
        if target == project_dir:
            question = ("ask", f"target {operand!r} is the project root "
                               f"{project_dir} itself")
        elif project_dir in target.parents:
            continue
        elif any(root in target.parents for root in scratch):
            continue
        elif any(char in operand for char in GLOB_CHARS):
            question = ("ask", f"glob {operand!r} expands outside {project_dir}")
        else:
            question = ("ask", f"target {operand!r} resolves to {target}, "
                               f"outside {project_dir}")

    return question


UNCONDITIONAL_ADVICE = ("This target is off limits regardless of approval. Narrow "
                        "the command to the paths that actually need deleting.")
UNAPPROVED_ADVICE = ("Not approved — declined, timed out, or there was nothing "
                     "able to ask. Narrow the command to the project, or say what "
                     "needs deleting and let the user run it.")

# The dialog has to answer inside the harness's own hook timeout (60s), or the
# command escapes the guard by the guard never having replied.
DIALOG_TIMEOUT_SECONDS = 40
OSASCRIPT = "/usr/bin/osascript"


def refuse(reason, advice):
    print(f"Blocked a recursive delete: {reason}.\n{advice}", file=sys.stderr)
    return 2


def ask(reason):
    """Hand the command to the harness's own approval prompt."""
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason":
            f"Recursive delete outside the project: {reason}. Approve only if "
            f"that is the path you meant.",
    }}))
    return 0


def applescript_literal(text):
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def approved_by_dialog(reason, command):
    """Ask the person at the keyboard directly. True only on explicit approval.

    `giving up after` closes the dialog on its own if nobody is there, which
    reports `gave up:true` alongside the default button -- silence must not read
    as consent.
    """
    message = ("An agent wants to run a recursive delete outside its project.\n\n"
               f"{reason}\n\n{command.strip()[:600]}")
    script = (f"display dialog {applescript_literal(message)} "
              f'with title "Recursive delete" '
              f'buttons {{"Cancel", "Delete"}} default button "Cancel" '
              f"with icon caution giving up after {DIALOG_TIMEOUT_SECONDS}")
    try:
        answer = subprocess.run([OSASCRIPT, "-e", script], capture_output=True,
                                text=True, timeout=DIALOG_TIMEOUT_SECONDS + 5)
    except (OSError, subprocess.SubprocessError):
        return False
    if answer.returncode != 0:
        return False
    return ("button returned:Delete" in answer.stdout
            and "gave up:true" not in answer.stdout)


def main():
    caller_can_ask = "--no-prompt" not in sys.argv[1:]
    dialog_allowed = "--no-dialog" not in sys.argv[1:]

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not command:
        return 0

    home = os.path.expanduser("~")
    cwd = payload.get("cwd") or os.getcwd()
    project_dir = canonical(os.environ.get("CLAUDE_PROJECT_DIR") or cwd)

    commands, unparsed = tokenize(command)

    questions = []

    # A line whose quoting cannot be followed is only a problem if that line is
    # itself a recursive delete; otherwise its unreadability says nothing about
    # safety, and the parseable lines are still checked below.
    for line in unparsed:
        if DESTRUCTIVE_HINT.search(line):
            questions.append(f"this line contains a recursive delete but could not "
                             f"be parsed, so its targets are unknown: {line.strip()}")

    # Every command is checked before answering, so one catastrophic target in a
    # chain outweighs an earlier one that would only have prompted.
    for argv in commands:
        answer = verdict(argv, cwd, project_dir, home)
        if not answer:
            continue
        decision, reason = answer
        if decision == "deny":
            return refuse(reason, UNCONDITIONAL_ADVICE)
        questions.append(reason)

    if not questions:
        return 0

    reason = "; ".join(questions)

    # Every mode but bypassPermissions puts an `ask` in front of a human. A
    # missing mode means an older harness, which prompted.
    if caller_can_ask and payload.get("permission_mode") != "bypassPermissions":
        return ask(reason)
    if dialog_allowed and approved_by_dialog(reason, command):
        return 0
    return refuse(reason, UNAPPROVED_ADVICE)


if __name__ == "__main__":
    sys.exit(main())
