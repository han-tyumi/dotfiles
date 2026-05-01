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
| Check out a branch by name | `gs branch checkout <name>` | `gs bco <name>` |
| Move up one branch | `gs up` | — |
| Move down one branch | `gs down` | — |
| Jump to top of stack | `gs top` | — |
| Jump to bottom of stack | `gs bottom` | — |
| Jump to trunk | `gs trunk` | — |
| Restack the whole stack | `gs stack restack` | `gs sr` |
| Restack just current branch on its parent | `gs branch restack` | — |
| Sync trunk, prune merged branches, restack survivors | `gs repo sync` | `gs rs` |
| Submit / update PR for current branch | `gs branch submit` | `gs bs` |
| Submit / update PRs for the whole stack | `gs stack submit` | `gs ss` |
| Compact stack listing | `gs log short` | `gs ls` |
| Detailed stack listing (with CR info) | `gs log long` | `gs ll` |

`--fill` on `submit` auto-fills PR title/body from commit messages — handy
on first submit (`gs ss --fill`).

## Workflow patterns

**Start a stack from trunk.** `gs bc feat-1`, commit, `gs bc feat-2`, commit.
Each `gs bc` creates a branch on top of the current one, building the stack.

**Edit a parent mid-stack.** `gs down` (or `gs bottom` / `gs bco <parent>`),
commit edits, then `gs sr` to rebase all children onto the new parent.

**First submit of a stack.** `gs ss --fill`. git-spice creates one PR per
branch with correct base branches and posts navigation comments linking them.

**After a PR merges.** `gs rs` from anywhere — pulls trunk, deletes merged
branches locally, restacks remaining children onto trunk.

## Beyond the crib sheet

For config (`.spice.toml`, branch prefix, navigation comment formats),
conflict recovery, GitLab support, hooks, branch fold/squash, or anything not
listed above: query Context7 with library id `/abhinav/git-spice`. Don't guess
flag names or subcommands.

Official LLM doc index: https://abhinav.github.io/git-spice/llms.txt.
