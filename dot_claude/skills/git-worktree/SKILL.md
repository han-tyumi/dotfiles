---
name: git-worktree
description: Creates a git worktree of the current repo, pre-seeded with the gitignored local config (env files, mise config) a build needs, via the `wt` CLI. Use when creating, spinning up, or setting up a worktree for a branch.
when_to_use: User asks to create / spin up / set up a git worktree, make a worktree for a branch, or work on a branch in a separate checkout.
---

# git-worktree

`wt` creates a worktree of the current repo and provisions it so it builds
immediately. It's a personal nushell script on PATH (`~/.local/bin/wt`) and
assumes mise is installed (it always runs `mise trust`; the repo itself need not
use mise). Run `wt --help` for the full interface.

Reach for `wt` instead of hand-rolling `git worktree add` plus copying local
config — `wt` does both. Skipping it reintroduces the exact "the worktree won't
build" friction it exists to remove.

## When to use

- **Use `wt` whenever creating a worktree** of a repo that needs gitignored
  local config to build (env files, `mise.local.toml`, and the like) — which is
  essentially every JS/mise repo here.
- A plain `git worktree add` is only worth it for a repo with no gitignored
  build config. When unsure, use `wt`; it's a strict superset.

## Invocation

Run it **from inside the target repo** — it resolves the repo from the current
directory and creates the worktree as a sibling `<repo>.worktrees/<name>`.

| Goal | Command |
|---|---|
| Worktree for an existing local/remote branch | `wt <branch>` |
| Worktree with a custom directory name | `wt <branch> <name>` |
| New branch off the current HEAD | `wt <branch> --create` |
| Preview without changing anything | `wt <branch> --dry-run` |

`<name>` defaults to the branch with `/` replaced by `-`.

## What it already does (don't redo by hand)

In order: `git worktree add` → copy gitignored local config from the main
checkout (root-level files, plus nested local config like monorepo `apps/*/.env`
and `.claude/*.local.*`; junk like `.DS_Store`/`*.log` excluded) → `mise trust` →
`direnv allow` if there's an `.envrc` → install with the detected package manager
(yarn/pnpm/npm/bun) → run `typecheck` if that script exists. Once `wt` returns
the worktree is ready — do not separately copy env/Claude config, trust mise,
allow direnv, or install.

A repo with no `package.json` (Rust, Gleam, …) gets the worktree, seed, and
trust but no install or typecheck — run that project's own build yourself.

## Habits

- **Prefer `wt <branch> --dry-run` first** when unsure what it will seed or which
  branch resolves: it prints the plan (repo, worktree path, seed files, package
  manager) and changes nothing. Then run it for real.
- If `wt` fails at `git worktree add` (branch already checked out elsewhere, or
  the worktree dir exists), it stops before copying anything — fix the cause and
  re-run.
- Surface the final worktree path it prints so the user can `cd` there.
- **Cleanup is separate** — `wt` only creates. Remove a worktree you're done with
  via `git worktree remove <path>`.
