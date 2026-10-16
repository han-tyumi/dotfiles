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

1. `sandbox-browser status`. If it says `running: yes`, go to step 3.
2. `sandbox-browser start` must run outside the sandbox: request an unsandboxed run
   for exactly that command (add `--headed` when the user wants to watch). Only the
   user's approval or the harness's reviewer can allow it. Do not look for another
   way to launch a browser.
3. Run commands as `sandbox-browser <command>`: `sandbox-browser open <url>`,
   `sandbox-browser snapshot`, `sandbox-browser click @e3`,
   `sandbox-browser screenshot ./shot.png`, and so on.
   `sandbox-browser skills get core` prints the command reference.
4. `sandbox-browser stop` when finished, or leave it for the next task in the same
   worktree.

Each worktree has its own browser, so parallel agents do not share tabs or cookies.

## Rules

- The browser runs outside the sandbox with the user's full file access, so it is a
  way around the sandbox: it can write a screenshot or download anywhere and open
  `file://` URLs. Write screenshots and downloads inside the workspace only, open
  only URLs the task needs, and never navigate to `file://` URLs.
- If `sandbox-browser` reports that no browser is running, follow step 2; do not retry
  the failing command in a loop.
