---
name: sync
description: Resolve chezmoi diffs by reviewing diverged files and syncing live changes back to source or applying source to live
allowed-tools: Bash(chezmoi *), Bash(git diff *), Read, Write, Edit, AskUserQuestion
---

# Resolve Chezmoi Diffs

1. Run `chezmoi diff` to find all files that have diverged between source and live state.
   - If there are no diffs, say "Everything is in sync." and stop.

2. Present a summary of all diverged files to the user.

3. For each diverged file:
   a. Show the diff.
   b. Ask the user what to do:
      - **Keep live**: Run `chezmoi re-add <target-path>` to update the chezmoi source to match the live file.
      - **Keep source**: Run `chezmoi apply --force <target-path>` to overwrite the live file with the chezmoi source.
      - **Skip**: Leave the file as-is.

4. For settings/config files (JSON, TOML, etc.) synced back to source, organize content with logical section comment headers where appropriate (e.g., Appearance, Editor, Privacy, Extensions).

5. Show a `git diff` summary of all changes made to the chezmoi source directory.
