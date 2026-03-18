---
name: sync-vscode
description: Sync VS Code settings and keybindings from the live config to the chezmoi source directory
disable-model-invocation: true
allowed-tools: Bash(cp *), Bash(git diff *), Read, Write
---

# Sync VS Code Settings to Chezmoi

1. Copy the live VS Code configuration files to the chezmoi source directory:

   ```bash
   cp ~/Library/Application\ Support/Code/User/settings.json \
      ~/.local/share/chezmoi/private_Library/private_Application\ Support/private_Code/private_User/settings.json

   cp ~/Library/Application\ Support/Code/User/keybindings.json \
      ~/.local/share/chezmoi/private_Library/private_Application\ Support/private_Code/private_User/keybindings.json
   ```

2. Organize settings into logical sections with comment headers. The current sections are:
   - Appearance
   - Editor
   - Terminal
   - Privacy
   - Nix
   - Trust
   - Then extension-specific sections (e.g., Claude Code, Atlassian)

   New settings should be placed in the appropriate existing section or given a new section header if they don't fit.

3. Show a summary of what changed using `git diff`. If there are no changes, say "Already in sync."
