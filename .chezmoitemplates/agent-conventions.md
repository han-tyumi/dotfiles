- Prefer descriptive variable names over comments. Prefer to let the code document itself rather than using verbose comments.
- Use punctuation for JSDoc parameters and similar.
- Avoid using the `any` type in TypeScript files.
- Avoid non-null assertions in TypeScript.
- Avoid using 1 letter variable names in TypeScript and JavaScript.
- Prefer JavaScript functions to have a maximum 2 arguments. Put the rest into an options object.

  When designing function interfaces, stick to the following rules:

  1. A function should take 0-2 required arguments, plus (if necessary) an options object (so max 3 total).

  2. Optional parameters should generally go into the options object.

     An optional parameter that's not in an options object might be acceptable if there is only one, and it seems inconceivable that we would add more optional parameters in the future.

  3. The 'options' argument is the only argument that is a regular 'Object'.

     Other arguments can be objects, but they must be distinguishable from a 'plain' Object runtime, by having either:
     - a distinguishing prototype (e.g. Array, Map, Date, class MyThing).
     - a well-known symbol property (e.g. an iterable with Symbol.iterator).

     This allows the API to evolve in a backwards compatible way, even when the position of the options object changes.

- Comments should use proper capitalization and punctuation when possible.
- Add a blank line before comments so they visually pair with the code they describe.
- Source comments describe the current code only. No internal-process references (`.scratch/`, `.claude/rules/*` labels like "Pattern 2" or "Phase 2c", audit/handoff names) and no history ("REVERSES X", "previously did Y", "renamed from Z", "added in v8"). A reader with only the file in front of them must be able to make sense of every comment. History belongs in `git log` and PR descriptions.
- Don't reference gitignored paths anywhere a reader outside your local checkout would land — not source comments, not commit messages, not PR descriptions.
- `.scratch/` is for transient files that stay close to me and to the directory we're working in — notes, logs, throwaway analysis, intermediate output. It's gitignored globally (`~/.config/git/ignore`), so it's local-only and never committed or shared. Create it in the directory we're actually working in, not a global location. Don't put durable or shared artifacts there; if something needs to outlive the session or reach teammates, commit it somewhere tracked instead.
- For mise, always use `mise outdated --bump` (or `-l`) to check for tool upgrades. Default `mise outdated` only reports updates *within* the configured version constraint, which means exact pins (e.g. `rclone 1.73.3`) always appear up to date even when newer versions exist.
- Don't prefix shell commands with `mise exec --`. mise installs shims on `PATH`, so `pnpm`, `node`, etc. resolve directly to the version pinned in `.tool-versions` / `mise.toml`. Using `mise exec` is redundant noise.

## Agent attribution

Agent-assisted work is marked so a reader can tell the tool from the person. The
marker is one trailer, copied from Apache magpie's convention:

    Assisted-by: <agent>:<model>

**Commits are stamped for you.** `git` runs a `prepare-commit-msg` hook that
writes the line wherever the repository is scoped for it, so an agent authoring a
commit message does not add it. That hook sees the message however it was
supplied — `-m`, `-F`, a heredoc, `--amend --no-edit`, an editor — and replaces a
trailing line already there, for the same reason.

**Bodies are stamped for you too, on macOS and Linux.** A PR description,
review, comment or issue body carries the same marker as its last line, behind a
🤖:

    🤖 Assisted-by: claude-code:claude-opus-5-5

The `gh` on `PATH` adds that line to every body given on the command line —
`--body`, `-b`, `--body-file`, or a `body=` field for `gh api` — and replaces a
trailing one already there. Write the body without it: an agent does not know
which model it resolved to, so a line it writes itself is a guess, and a wrong
guess is worse than the stamp that overwrites it.

A body gh supplies itself, from `--fill` or from an editor, is published as it
is. Pass a body when the write needs the marker.

That wrapper is a shell script at `~/.local/bin/gh`, so it does not run on
Windows. There the line is yours to write, and it must be the last line of the
body.

In a squash-merged repo the branch commit is discarded, so the PR description
carries the record — it becomes the squash commit body. That is the one place a
commit trailer cannot survive, which is why the description states it
explicitly.

It labels the tool; it does not attest authorship. The commit still authors as
the person accountable for the change, and `Co-authored-by:` stays reserved for
a human co-author.

An agent never submits an `APPROVE` review: a ruleset counts an approval the
moment it lands, and a later comment cannot undo it.

Never write to a remote under an identity you have not confirmed. One call per
session, before the first write:

    gh api user --jq .login

If that is not the account you expect — a bot session that should be acting as
`some-agent[bot]`, or a personal session that should not — stop and report it
instead of writing. The failure it catches is a missing token: `gh` then uses
whatever credentials are stored and exits successfully, so the write lands as
that account with nothing in the output to say the token was never used. An
expired or malformed token fails on its own with a 401.

