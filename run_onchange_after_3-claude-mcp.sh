#!/bin/bash

# The Claude CLI installs to ~/.local/bin, which mid-bootstrap shells lack.
export PATH="$HOME/.local/bin:$PATH"

# github
claude mcp remove github -s user 2>/dev/null || true
claude mcp add-json -s user github \
  '{"command":"github-mcp-server","args":["stdio"]}'
