---
name: sandbox-browser
description: Drive a real browser (open pages, snapshot, click, type, screenshot) from inside an agent sandbox through `sandbox-browser`. Use whenever a browser, web UI or screenshot task runs in a sandboxed agent such as Codex, where `agent-browser` itself cannot launch Chromium.
---

# Browser from inside a sandbox

Chromium cannot launch inside a filesystem sandbox such as Codex's. A browser for this
worktree runs outside it, and `sandbox-browser` talks to that browser. In a sandboxed
agent, use `sandbox-browser` for every `agent-browser` command; calling `agent-browser`
directly picks the wrong session and tries to launch its own browser. An unsandboxed
agent can keep using `agent-browser` directly.

## Workflow

1. `sandbox-browser status`. If it says `running: yes` and its `limits` cover the
   domains the task needs, go to step 3.
2. `sandbox-browser start --allowed-domains <domains>` must run outside the sandbox:
   request an unsandboxed run for exactly that command, listing only the domains the
   task needs (for example `example.com,*.example.com`; add `--headed` when the user
   wants to watch). Only the user's approval or the harness's reviewer can allow it.
   Use `--unrestricted` instead only when the user asked for open-ended browsing. Do
   not look for another way to launch a browser. To change the domains, `stop` and
   start again.
3. Run commands as `sandbox-browser <command>`: `sandbox-browser open <url>`,
   `sandbox-browser snapshot`, `sandbox-browser click @e3`,
   `sandbox-browser screenshot ./shot.png`, and so on.
   `sandbox-browser skills get core` prints the command reference.
4. `sandbox-browser stop` when finished, or leave it for the next task in the same
   worktree.

Each worktree has its own browser, so parallel agents do not share tabs or cookies.

## Limits

With `--allowed-domains` the browser reaches only the listed domains: other domains,
`file://` and `data:` URLs are blocked, including links the page follows itself.
Only everyday page actions run; `download`, `upload`, `state save`, `pdf`, tracing,
recording and cookie reads are denied. If a command is denied, report it to the user
instead of working around it.

## Rules

- The browser runs outside the sandbox with the user's full file access, so it is a
  way around the sandbox. The limits above are a guard, not a boundary: a screenshot
  can still be written to any path. Write screenshots inside the workspace only, and
  never call `agent-browser` directly to widen the limits.
- If `sandbox-browser` reports that no browser is running, follow step 2; do not retry
  the failing command in a loop.
