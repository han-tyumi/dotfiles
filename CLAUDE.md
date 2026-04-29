# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed by chezmoi for macOS (specifically aarch64-darwin). The repository configures a complete development environment using:
- **Nix Darwin** with flakes for system-level package management
- **Home Manager** for user-level configuration
- **mise** for language version management
- **Homebrew** for macOS-specific applications

## Architecture

### Configuration Hierarchy

1. **Chezmoi Layer** (root level): Manages all dotfiles with templating support
   - `.chezmoi.toml.tmpl`: Main chezmoi config with age encryption
   - `.chezmoiexternal.toml`: External resources (git repos, archives)

2. **Nix Darwin Layer** (`dot_config/nix-darwin/`): System configuration
   - `flake.nix`: Main flake defining system inputs/outputs
   - `configuration.nix`: System-wide settings, packages, and Homebrew declarations
   - `home.nix`: User environment configuration via Home Manager
   - `private.nix`: Private user data (git-ignored)
   - `encrypted_private.nix.age`: Encrypted private configuration

3. **Tool Configuration Layer** (`dot_config/`): Individual tool configs
   - `mise/config.toml`: Language runtime versions
   - `starship.toml`: Shell prompt configuration
   - `neovide/`: Editor configs

### Nix Darwin Structure

The Nix configuration uses a flake-based setup:
- `flake.nix` defines inputs (nixpkgs, nix-darwin, home-manager)
- `configuration.nix` handles system-level concerns:
  - Homebrew taps, brews, casks, and Mac App Store apps
  - System defaults (Dark mode, finder settings, etc.)
  - User packages installed via Nix
- `home.nix` configures the user environment:
  - Shell configurations (fish, nushell, zsh)
  - Git configuration with conditional includes for work/personal
  - Development tools and their settings
  - Session variables and PATH configuration

### Run Scripts

Chezmoi uses special script naming conventions:
- `run_once_after_install-*.sh`: One-time installation scripts
  - `install-1.sh`: Installs Homebrew and Nix
  - `install-2.sh`: Installs Nix Darwin
- `run_onchange_after_*.tmpl`: Scripts that run when tracked files change
  - `1-mise-config.toml.tmpl`: Updates mise plugins and tools

## Common Commands

### System Management

Apply chezmoi changes:
```bash
chezmoi apply
```

Update and apply chezmoi:
```bash
chezmoi update
```

Rebuild Nix Darwin configuration:
```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
```

Update Nix flake inputs:
```bash
cd ~/.config/nix-darwin && nix flake update
```

### Language/Tool Management

Update mise tools:
```bash
mise plugins upgrade
mise upgrade
```

### Chezmoi Operations

Edit a file in the source directory:
```bash
chezmoi edit <file>
```

View differences before applying:
```bash
chezmoi diff
```

Add a new file to chezmoi:
```bash
chezmoi add <file>
```

### Git Configuration

This repository has two Git identities:
- **Personal**: Default identity (han-tyumi)
- **Work**: Automatically activated for Revvity repositories (chmmpagne)

SSH keys are identity-specific:
- Personal: `~/.ssh/git_han-tyumi`
- Work: `~/.ssh/git_chmmpagne`

## Key Technical Details

### File Naming Conventions

Chezmoi uses special prefixes:
- `dot_`: Converts to `.` (e.g., `dot_config` → `.config`)
- `private_`: Creates files with restricted permissions
- `encrypted_`: Files encrypted with age
- `.tmpl`: Template files processed by chezmoi

### Encryption Setup

The repository uses age encryption:
- Identity: `~/key.txt`
- Recipient: `age1zf3ruadchuuxhhc0sq96fdn5gazryegnfprwncrprylzqt2ce3aqzm5ekc`

### Shell Integration

Multiple shells are configured:
- **Fish**: Primary interactive shell with plugins (macos, plugin-git, tide, z)
- **Nushell**: Alternative shell with custom config/env files
- **Zsh**: Enabled as system shell

All shells integrate:
- Homebrew environment via `/opt/homebrew/bin/brew shellenv`
- mise activation for runtime management

### External Resources

External resources are managed in `.chezmoiexternal.toml`:
- **V language**: Git repo clone at `~/v`
- **Roc language**: Nightly builds for Apple Silicon (refreshed every 6h)

### Neovim Configuration

Neovim config is managed as an external git submodule (`dot_config/external_nvim/`) based on kickstart.nvim with custom plugins.

## Important Notes

- The main system configuration targets the hostname "Matts-MacBook-Pro"
- Node.js is pinned to version 22 via nixpkgs overlay
- Homebrew auto-updates and upgrades on activation
- Git ignores `.claude/*.local.*`, `.env.local`, `.mcp.local.json`, `CLAUDE.local.md`, and `mise.local.toml` globally
