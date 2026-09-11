#!/bin/bash

# The Claude CLI installs to ~/.local/bin, which mid-bootstrap shells lack.
export PATH="$HOME/.local/bin:$PATH"

# github. No env block: the server needs GITHUB_PERSONAL_ACCESS_TOKEN, and the
# ~/.local/bin/github-mcp-server wrapper resolves it from gh at launch so no
# token is written here.
#
# The excluded tools are the ones that write to a remote without passing any
# guard that watches shell commands -- the recursive-delete hook, the bash
# permission rules, and a repo's own push-approval hook all inspect a command
# line, which an MCP tool call does not have. Repository work goes through the
# gh CLI, which every one of these has a direct equivalent for, so losing them
# costs a redundant path rather than a capability. Reads, PR creation, issue
# writes and review writes all stay.
github_write_tools=create_or_update_file,push_files,delete_file
github_write_tools=$github_write_tools,create_repository,fork_repository
github_write_tools=$github_write_tools,merge_pull_request

claude mcp remove github -s user 2>/dev/null || true
claude mcp add-json -s user github \
  "{\"command\":\"github-mcp-server\",\"args\":[\"stdio\",\"--exclude-tools\",\"${github_write_tools}\"]}"
