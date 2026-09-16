#!/bin/bash

# The Claude CLI installs to ~/.local/bin, which mid-bootstrap shells lack.
export PATH="$HOME/.local/bin:$PATH"

# The github MCP server is retired. Every tool it offered is reachable through
# the gh CLI — gh pr/issue/repo/release/run/search for the common verbs and gh
# api for the rest — and repo work already goes through gh on purpose, so the
# shell-inspecting guards (the recursive-delete hook, the bash permission rules,
# a repo's own push-approval hook) can see what reaches a remote, which an MCP
# tool call has no command line for. Keeping the server only added 37 tool
# schemas to every session's cached prefix.
#
# Idempotent removal, not a deletion of this script: it is a run_onchange, so
# editing it re-fires on machines that registered github while it was installed
# and drops the stale entry from ~/.claude.json. Once every machine has
# converged, this script and the github-mcp-server package/wrapper can go away.
claude mcp remove github -s user 2>/dev/null || true
