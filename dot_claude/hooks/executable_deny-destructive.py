#!/usr/bin/env python3
"""Deny recursive deletes that reach outside the project an agent is working in.

Claude Code feeds a PreToolUse hook the pending tool call as JSON on stdin.
Exit 0 allows it; exit 2 denies it and hands stderr back to the model so it can
choose a narrower command.

Python rather than shell because the decision hinges on tokenising a command
line correctly — `shlex` respects quoting and shell operators, where bash word
splitting would mis-read `rm -rf "$dir/a b"` and anything chained with `&&`.

Unresolvable targets are denied rather than allowed: a path built from a
variable this hook cannot expand is exactly the case that goes wrong.
"""

import json
import os
import re
import shlex
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
    if os.path.basename(argv[0]) != "find":
        return False
    return "-delete" in argv or "-exec" in argv or "-execdir" in argv


def is_deleting_rsync(argv):
    if os.path.basename(argv[0]) != "rsync":
        return False
    return any(flag.startswith("--delete") for flag in flags_of(argv))


def scratch_roots():
    """Temp directories a recursive delete may target: nothing durable lives there."""
    roots = ["/tmp", "/private/tmp", "/var/folders", "/private/var/folders"]
    for variable in ("TMPDIR", "TMP", "TEMP"):
        value = os.environ.get(variable)
        if value:
            roots.append(value)
    return [canonical(root) for root in roots]


def verdict(argv, cwd, project_dir, home):
    """Return a refusal reason, or None to allow."""
    if not argv:
        return None
    if not (is_recursive_rm(argv) or is_deleting_find(argv) or is_deleting_rsync(argv)):
        return None

    scratch = scratch_roots()

    for operand in operands_of(argv):
        expanded = expand(operand, home)
        if expanded is None:
            return (f"target {operand!r} depends on an expansion this hook cannot "
                    f"evaluate, so it cannot be shown to stay inside {project_dir}")

        target = canonical(Path(expanded) if os.path.isabs(expanded)
                           else Path(cwd) / expanded)

        if target == project_dir:
            return f"target {operand!r} is the project root {project_dir} itself"
        if project_dir in target.parents:
            continue
        if any(root in target.parents for root in scratch):
            continue
        if any(char in operand for char in GLOB_CHARS):
            return f"glob {operand!r} expands outside {project_dir}"
        return f"target {operand!r} resolves to {target}, outside {project_dir}"

    return None


def main():
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

    # A line whose quoting cannot be followed is only a problem if that line is
    # itself a recursive delete; otherwise its unreadability says nothing about
    # safety, and the parseable lines are still checked below.
    for line in unparsed:
        if DESTRUCTIVE_HINT.search(line):
            print("Blocked: this line contains a recursive delete but could not be "
                  f"parsed safely, so its targets cannot be checked:\n  {line.strip()}\n"
                  "Run the delete as its own simpler command.", file=sys.stderr)
            return 2

    for argv in commands:
        reason = verdict(argv, cwd, project_dir, home)
        if reason:
            print(
                f"Blocked a recursive delete: {reason}.\n"
                f"Recursive deletes are restricted to paths under the project "
                f"directory. If this is genuinely intended, run it yourself "
                f"outside the agent.",
                file=sys.stderr,
            )
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
