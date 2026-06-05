#!/bin/bash

# Install Claude Code CLI
# https://docs.anthropic.com/en/docs/claude-code
if command -v claude &>/dev/null; then
  echo "Claude Code is already installed."
else
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
