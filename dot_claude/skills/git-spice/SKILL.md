---
name: git-spice
description: Manages stacks of dependent Git branches and stacked PRs via the third-party git-spice CLI (`gs`). Use for stacked branches, splitting a branch into a stack, restacking after edits, or submitting a stack of PRs.
when_to_use: User mentions stacked diffs, dependent branch chains, restacking, or splitting one branch into multiple PRs.
---

# git-spice

CLI for managing stacks of Git branches and stacked GitHub/GitLab change requests.
Docs: https://abhinav.github.io/git-spice/. Context7 library: `/abhinav/git-spice`.

## When to use

- **Use git-spice for stacks of 2+ dependent branches/PRs.** Splitting a
  branch into a stack, adding a branch on top of an in-flight PR,
  restacking children after editing a parent, submitting a multi-PR stack.
- **Don't steer to git-spice for single-branch / single-PR work.** Plain
  `git` + `gh` is fine; switching mid-flow is noise.

## Invocation

The user has `gs = "git-spice"` aliased (set in `dot_config/nix-darwin/home.nix`).
Always invoke as `gs <subcommand>`. Equivalent forms: `git spice <subcommand>`,
`git-spice <subcommand>`.

## Crib sheet

| Action | Full command | Short |
|---|---|---|
| Initialize repo for git-spice | `gs repo init` | — |
| Create branch on top of current | `gs branch create <name>` | `gs bc <name>` |
| Track an existing branch (set parent for stacking) | `gs branch track [--base <parent>]` | — |
| Bulk-track a manually built stack from the top | `gs downstack track` | — |
| Check out a branch by name | `gs branch checkout <name>` | `gs bco <name>` |
| Move up one branch | `gs up` | — |
| Move down one branch | `gs down` | — |
| Jump to top of stack | `gs top` | — |
| Jump to bottom of stack | `gs bottom` | — |
| Jump to trunk | `gs trunk` | — |
| Restack the whole stack | `gs stack restack` | `gs sr` |
| Restack just current branch on its parent | `gs branch restack` | — |
| Sync trunk, prune merged branches | `gs repo sync` | `gs rs` |
| Same, plus restack current stack (see "After a PR merges") | `gs repo sync --restack` | — |
| Restack every tracked branch in the repo | `gs repo restack` | — |
| Submit / update PR for current branch only | `gs branch submit` | `gs bs` |
| Submit / update PRs for the whole stack (default) | `gs stack submit` | `gs ss` |
| Commit + auto-restack children | `gs commit create` | `gs cc` |
| Amend tip commit + auto-restack children | `gs commit amend` | `gs ca` |
| Squash staged changes into a downstack commit + restack | `gs commit fixup [<sha>]` | `gs cf` |
| Continue a gs-driven rebase after resolving conflicts | `gs rebase continue` | `gs rbc` |
| Abort a gs-driven rebase | `gs rebase abort` | `gs rba` |
| Compact stack listing | `gs log short` | `gs ls` |
| Detailed stack listing (with CR info) | `gs log long` | `gs ll` |

`--fill` on `submit` auto-fills PR title/body from commit messages — handy
on first submit (`gs ss --fill`).

**Default to `gs stack submit`, not `gs branch submit`.** Stack submit walks the
whole stack: it discovers existing parent CRs, posts/refreshes navigation
comments on every PR, and updates each PR's base branch. Branch submit only
touches the current branch's PR — sibling and parent nav comments are *not*
refreshed, so adding a child PR with `gs branch submit` leaves the parent PR's
nav comment without a link to the new child. Use `gs branch submit` only when
deliberately scoping a push to one branch.

If `gs ss` errors with `needs to be restacked` on a parent you don't want to
restack right now (main moved but the existing PR is approved and you don't
want to force-push it):

- `gs ss --force` — bypasses the restack guard. Creates new PRs and updates
  existing ones; will force-push any branch whose local commits diverge from
  the remote, so only safe when no parent commits actually changed.
- `gs ss --update-only --force` — refreshes metadata and nav comments on
  *existing* PRs only. Skips opening any new PRs, so don't use this on a first
  submit when the child PR hasn't been opened yet.

## Workflow patterns

**Start a stack from trunk.** `gs bc feat-1`, commit, `gs bc feat-2`, commit.
Each `gs bc` creates a branch on top of the current one, building the stack.

**Prefer `gs cc` / `gs ca` over `git commit` / `git commit --amend` on
stacked branches.** Both gs variants auto-restack the upstack chain so children
don't go stale. Plain git leaves children pointing at the previous commit, and
you have to remember to `gs sr` afterward.

**Squash a follow-up edit into an earlier commit.** `gs cf [<sha>]` (commit
fixup) replaces the `git commit --fixup=<sha> && git rebase --autosquash main`
two-step. It applies the staged changes to the target commit and restacks
everything above it in one shot. Useful when responding to review feedback on
an earlier commit in the stack. If the staged changes can't apply cleanly to
the target — e.g. a later commit references a symbol you're removing — the
command fails before touching anything.

**Edit a parent mid-stack.** `gs down` (or `gs bottom` / `gs bco <parent>`),
edit + `gs ca`, and the upstack restack happens automatically. Or use `gs cf`
from anywhere in the stack to target a specific downstack commit without
moving.

**Resolve a gs-driven rebase conflict.** When `gs sr`, `gs cf`, `gs rs
--restack`, or any other gs command halts on a rebase conflict: resolve the
conflict (`git add` resolved files), then `gs rbc` to continue. To bail out:
`gs rba`. These wrap the underlying `git rebase --continue` / `--abort` and
also clean up gs's internal operation state, so prefer them over the plain
git equivalents.

`gs rbc` opens an editor for the commit message by default — pass `--no-edit`
to skip it (or set `spice.rebaseContinue.edit=false` to make `--no-edit` the
default). This is cleaner than the plain-git `GIT_EDITOR=: git rebase
--continue` workaround.

**First submit of a stack.** `gs ss --fill`. git-spice creates one PR per
branch with correct base branches and posts navigation comments linking them.

**After a PR merges.** `gs rs --restack` pulls trunk, deletes merged branches
locally (works for squash-merge, not just rebase-merge), and restacks remaining
children. It correctly skips the absorbed commits — no need for the plain-git
`git rebase --onto <last-shared-sha>` workaround.

**Caveat: when the merged branch was your current branch, `--restack` ends up
restacking every tracked branch in the repo, not just the current stack.**
Verified in source (internal/handler/sync/handler.go, marked `TODO`): when the
checked-out branch gets deleted because it was merged, gs drops you onto trunk
before invoking restack — and "current stack" of trunk is "all tracked
branches." If you have stale stacked branches that conflict with new trunk
(e.g. another in-flight stack), the restack halts mid-rebase. `gs rebase abort`
to bail out.

Workarounds when you only want to restack one stack:
- Check out a child branch first (`gs branch checkout <child>`), *then*
  `gs rs --restack`. Trunk-anchored restack-all only triggers when the current
  branch gets deleted.
- Or run `gs rs` (no `--restack`) to do the trunk pull + merged-branch
  cleanup, then `gs upstack restack` from the child to restack only the
  upstack chain.

**Stack a new branch on top of an existing untracked PR branch.** This is the
common case where someone has been working with plain `git` + `gh` on a PR,
and now wants to add a follow-up PR stacked on it. **Track the parent first**,
or the new branch silently gets `main` as its base and the PR targets main.

```bash
git fetch origin
git switch <parent-branch>          # the in-flight PR branch
gs branch track --base main          # now `gs ls` shows it
gs branch create <child-branch> --no-commit
# ...edit, commit normally...
gs stack submit --fill               # opens child PR + refreshes parent's nav comment
```

If the parent shows `(needs restack)` because main moved and you don't want to
force-push the in-flight PR, add `--force` to bypass the restack guard:
`gs stack submit --force --fill`.

`gs branch track` is an O(1) registration — it doesn't move commits or rewrite
history. It just tells git-spice "this branch's parent is X." If the base is
inferable, `gs branch track` alone (no `--base`) works.

To bulk-track a manually-built stack, check out the topmost branch and run
`gs downstack track` — git-spice walks down the chain registering each one.

## Beyond the crib sheet

For config (`.spice.toml`, branch prefix, navigation comment formats),
conflict recovery, GitLab support, hooks, branch fold/squash, or anything not
listed above: query Context7 with library id `/abhinav/git-spice`. Don't guess
flag names or subcommands.

Official LLM doc index: https://abhinav.github.io/git-spice/llms.txt.
