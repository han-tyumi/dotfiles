# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed by chezmoi for macOS (specifically aarch64-darwin). The repository configures a complete development environment using:
- **Nix Darwin** with flakes for system-level package management
- **Home Manager** for user-level configuration
- **mise** for language version management
- **Homebrew** for macOS-specific applications

## Architecture

### Profiles

Configuration is layered into three profiles, selected per machine by chezmoi data
(`personal` and `work` booleans, both prompted at `chezmoi init`, default `true`):

- **shared** — always applied: dev core plus every-machine apps
- **personal** — hobby/games/media, personal git identity, `private.nix` consumers, V/Roc
- **work** — lives in a separate **private repo** (`chmmpagne/dotfiles`), cloned by a
  work-gated chezmoi external to `~/.config/nix-darwin/work/`: work git identity,
  work casks, openconnect tooling (mise `conf.d` fragment), and work Claude skills
  (Home Manager symlinks them into `~/.claude/skills/` via `mkOutOfStoreSymlink`,
  so the clone stays the live, editable copy)

Any combination works (shared-only, +personal, +work, +both). The flags flow from
chezmoi data into the flake through the generated `profiles.nix`:

```bash
chezmoi init --promptBool personal=false,work=true   # change a machine's profiles
chezmoi data                                          # inspect current flags
```

`profiles.nix` derives `hostname` from `scutil --get LocalHostName` (what
`darwin-rebuild` matches flake attrs against), not `.chezmoi.hostname` — they differ.

The flake also exposes eval-only fixtures `test-{minimal,personal,work,full}` covering
every combination:

```bash
nix eval ~/.config/nix-darwin#darwinConfigurations.test-minimal.system.drvPath
```

Caveats:
- Toggling a profile **off** orphans already-applied files (chezmoi never removes
  newly-ignored targets): manually `rm ~/.config/nix-darwin/private.nix` (non-personal)
  and similar leftovers; Homebrew's `cleanup = "zap"` removes the casks/brews itself.
- On a fresh work machine the overlay clone needs the `chmmpagne/**` ssh include from
  the shared git config, which only exists after the first rebuild — so the first
  bootstrap may need a second `chezmoi apply --refresh-externals` + rebuild pass.
  External clone failures are non-fatal and easy to miss; the flake's `pathExists`
  guard just builds without the work layer until the clone lands.

### Configuration Hierarchy

1. **Chezmoi Layer** (root level): Manages all dotfiles with templating support
   - `.chezmoi.toml.tmpl`: Main chezmoi config with age encryption + profile prompts
   - `.chezmoiexternal.toml`: External resources (git repos, archives), profile-gated
   - `.chezmoiignore`: Profile-gated target exclusions

2. **Nix Darwin Layer** (`dot_config/nix-darwin/`): System configuration
   - `flake.nix`: Inputs/outputs; assembles modules per `profiles.nix`
   - `profiles.nix.tmpl`: Per-machine hostname/username/profile flags (chezmoi-rendered)
   - `modules/shared/{darwin,home}.nix`: Always-on system + Home Manager config
   - `modules/personal/{darwin,home}.nix`: Personal-profile config
   - `work/{darwin,home}.nix`: Work overlay (external clone, not in this repo)
   - `private.nix`: Private user data (git-ignored)
   - `encrypted_private.nix.age`: Encrypted private configuration

3. **Tool Configuration Layer** (`dot_config/`): Individual tool configs
   - `mise/config.toml`: Language runtime versions
   - `starship.toml`: Shell prompt configuration
   - `neovide/`: Editor configs

### Nix Darwin Structure

The Nix configuration uses a flake-based setup:
- `flake.nix` defines inputs (nixpkgs, nix-darwin, home-manager) and a `mkSystem`
  that imports `modules/shared` plus `modules/personal` / `work` per the profile flags
- `*/darwin.nix` modules handle system-level concerns:
  - Homebrew taps, brews, casks, and Mac App Store apps
  - System defaults (Dark mode, finder settings, etc.)
  - User packages installed via Nix
- `*/home.nix` modules configure the user environment:
  - Shell configurations (nushell, zsh)
  - Git configuration with conditional includes for work/personal
  - Development tools and their settings
  - Session variables and PATH configuration
- List options (casks, packages, `git.includes`) merge across modules; the work module
  sets the global git identity only under `lib.mkIf (!profiles.personal)`

### Run Scripts

Chezmoi uses special script naming conventions:
- `run_once_after_install-*.sh`: One-time installation scripts
  - `install-1.sh`: Installs Homebrew and Nix
  - `install-2.sh`: Installs Nix Darwin
- `run_onchange_after_*.tmpl`: Scripts that run when tracked files change
  - `1-mise-config.toml.tmpl`: Updates mise plugins and tools
  - `4-v.sh.tmpl`: Updates V; renders empty (skipped) unless the personal profile is on

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
- **Personal**: Default identity (han-tyumi) — from the personal profile
- **Work**: chmmpagne, activated for `~/Code/work/`, `Revvity/**` and `chmmpagne/**`
  remotes — from the work overlay; it becomes the global default on work-only machines

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
- **Nushell**: Primary interactive shell with custom config/env files
- **Zsh**: Enabled as system shell

All shells integrate:
- Homebrew environment via `/opt/homebrew/bin/brew shellenv`
- mise activation for runtime management

### External Resources

External resources are managed in `.chezmoiexternal.toml` (a template, profile-gated):
- **V language** (personal): Git repo clone at `~/v`
- **Roc language** (personal): Nightly builds for Apple Silicon (refreshed every 24h)
- **Work overlay** (work): private `chmmpagne/dotfiles` clone at `~/.config/nix-darwin/work`
- **Nushell community scripts**: `nu_scripts` clone under the nushell scripts dir

### Neovim Configuration

Neovim config is managed as an external git submodule (`dot_config/external_nvim/`) based on kickstart.nvim with custom plugins.

## Important Notes

- The flake's machine attr is generated per host from `scutil --get LocalHostName`
  (via `profiles.nix`), so `darwin-rebuild switch --flake ~/.config/nix-darwin` needs
  no explicit attribute
- Node.js is pinned to version 24 via nixpkgs overlay
- Homebrew auto-updates and upgrades on activation
- Git ignores `.claude/*.local.*`, `.env.local`, `.mcp.local.json`, `CLAUDE.local.md`, and `mise.local.toml` globally
