#!/bin/bash

# The Claude CLI installs to ~/.local/bin, which mid-bootstrap shells lack.
export PATH="$HOME/.local/bin:$PATH"

# github. No env block: the server needs GITHUB_PERSONAL_ACCESS_TOKEN, and the
# ~/.local/bin/github-mcp-server wrapper resolves it from gh at launch so no
# token is written here.
claude mcp remove github -s user 2>/dev/null || true
claude mcp add-json -s user github \
  '{"command":"github-mcp-server","args":["stdio"]}'
