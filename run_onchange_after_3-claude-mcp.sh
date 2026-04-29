#!/bin/bash

# github
claude mcp remove github -s user 2>/dev/null || true
claude mcp add-json -s user github \
  '{"command":"github-mcp-server","args":["stdio"]}'
