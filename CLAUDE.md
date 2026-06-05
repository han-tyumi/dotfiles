# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed by chezmoi for macOS (specifically aarch64-darwin). The repository configures a complete development environment using:
- **Nix Darwin** with flakes for system-level package management
- **Home Manager** for user-level configuration
- **mise** for language version management
- **Homebrew** for macOS-specific applications

## Architecture

### Layers

Configuration is composed from **layers**, selected per machine by chezmoi data:

- **shared** (`modules/shared/`) — always applied: dev core plus every-machine apps
- **in-repo layers** (`modules/<name>/`) — e.g. `personal`: hobby/games/media, personal
  git identity, `private.nix` consumers, V/Roc, personal mise runtimes
- **overlay layers** (`overlays/<name>/`) — private repos declared per machine in
  chezmoi data and cloned by a chezmoi external next to the flake. Their
  `darwin.nix`/`home.nix` are imported when the layer is enabled, and chezmoi
  templates splice optional fragments from them (e.g. `vscode-settings.jsonc` into
  the VS Code settings). Home Manager symlinks an overlay's `skills/` into
  `~/.claude/skills/` via `mkOutOfStoreSymlink`, so the clone stays the live,
  editable copy.

A layer may exist in-repo, as an overlay, or both; any combination of layers works.
Selection flows from chezmoi data into the flake through the generated `machine.nix`:

```bash
# Space-separated; overlays are name=url pairs.
chezmoi init --promptString "layers=personal work,overlays=work=git@github.com:user/repo.git"
chezmoi data   # inspect current selection
```

`machine.nix` derives `hostname` from `scutil --get LocalHostName` (what
`darwin-rebuild` matches flake attrs against), not `.chezmoi.hostname` — they differ.

The flake exposes eval-only fixtures: `test-minimal` (shared only), `test-<name>` for
each in-repo layer, and `test-all` (every in-repo layer plus any overlay clone present
on disk):

```bash
nix eval ~/.config/nix-darwin#darwinConfigurations.test-all.system.drvPath
```

Caveats:
- Toggling a layer **off** orphans already-applied files (chezmoi never removes
  newly-ignored targets): manually `rm` leftovers like
  `~/.config/nix-darwin/private.nix`; Homebrew's `cleanup = "zap"` removes the
  casks/brews itself.
- Renaming the Mac (LocalHostName) breaks `darwin-rebuild`'s attr lookup until the
  next `chezmoi apply` re-renders `machine.nix` — the failure is loud, the fix is
  one apply.
- `bootstrap.sh` clones enabled overlays (with a prompted ssh key) before the first
  apply, so the initial rebuild already includes them. If bootstrapping by hand
  instead: clone overlays before the first rebuild — chezmoi's own external clone
  may lack ssh auth, and external clone failures are non-fatal and easy to miss
  (the flake just builds without the layer until the clone lands); each overlay
  repo's README documents its exact clone command.

### Configuration Hierarchy

1. **Chezmoi Layer** (root level): Manages all dotfiles with templating support
   - `.chezmoi.toml.tmpl`: Main chezmoi config with age encryption + layer prompts
   - `.chezmoiexternals/`: External resources (git repos, archives), one file per
     concern; plain TOML except the data-driven overlays template
   - `.chezmoilayers/<layer>.ignore`: Targets owned by a layer — regular files and
     external targets alike — ignored (and the externals skipped) when the layer is off
   - `.chezmoiignore`: Always-ignored paths plus a generic loop over `.chezmoilayers/`

2. **Nix Darwin Layer** (`dot_config/nix-darwin/`): System configuration
   - `flake.nix`: Inputs/outputs; assembles modules per `machine.nix`
   - `machine.nix.tmpl`: Per-machine hostname/username/layer list (chezmoi-rendered)
   - `modules/shared/{darwin,home}.nix`: Always-on system + Home Manager config
   - `modules/<layer>/{darwin,home}.nix`: In-repo layer config (e.g. `personal`)
   - `overlays/<layer>/{darwin,home}.nix`: Overlay layers (external clones, not in this repo)
   - `private.nix`: Private user data (git-ignored)
   - `encrypted_private.nix.age`: Encrypted private configuration

3. **Tool Configuration Layer** (`dot_config/`): Individual tool configs
   - `mise/config.toml`: Language runtime versions (personal/work runtimes layer in via `conf.d` fragments)
   - `starship.toml`: Shell prompt configuration

### Nix Darwin Structure

The Nix configuration uses a flake-based setup:
- `flake.nix` defines inputs (nixpkgs, nix-darwin, home-manager) and a `mkSystem`
  that imports `modules/shared` plus each enabled layer's modules from `modules/<name>`
  and `overlays/<name>` (missing files skipped)
- `*/darwin.nix` modules handle system-level concerns:
  - Homebrew taps, brews, casks, and Mac App Store apps
  - System defaults (Dark mode, finder settings, etc.)
  - User packages installed via Nix
- `*/home.nix` modules configure the user environment:
  - Shell configurations (nushell, zsh)
  - Git configuration with conditional includes for work/personal
  - Development tools and their settings
  - Session variables and PATH configuration
- List options (casks, packages, `git.includes`) merge across modules; a layer can
  claim a default-when-absent option with `lib.mkIf` on `machine.layers` membership
  (e.g. an overlay's git identity becomes global default when `personal` is off)

### Run Scripts

Chezmoi runs scripts in lexical order of their source path, and `.chezmoiscripts/`
entries sort before repo-root scripts; the installers therefore live in
`.chezmoiscripts/0-install/`, whose leading digit sorts before any layer directory:
- `.chezmoiscripts/0-install/`: One-time installers, ordered before every layer's
  scripts
  - `run_once_after_1-homebrew-nix.sh`: Installs Homebrew and Nix
  - `run_once_after_2-nix-darwin.sh`: Installs Nix Darwin (channel ref read from
    the flake's nix-darwin input)
  - `run_once_after_3-claude-code.sh`: Installs Claude Code
- `run_onchange_after_*.tmpl`: Scripts that run when tracked files change
  - `1-mise-config.toml.tmpl`: Upgrades and installs mise tools
- `.chezmoiscripts/<layer>/`: Layer-owned scripts; they derive their layer name from
  their own path (`.chezmoi.sourceFile`) rather than hardcoding it
  - `personal/run_onchange_after_v.sh.tmpl`: Updates V; renders empty (skipped)
    unless `~/v` exists (the V external)

## Common Commands

### Bootstrap a fresh Mac

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.sh)"
```

Per-machine secrets:
- **personal layer**: `~/key.txt` (the age identity — from Bitwarden or the backup
  USB) is the only file that must be transported
- **private overlays**: a fresh SSH key per machine — `bootstrap.sh` offers to
  generate them and prints the public keys to register with the matching GitHub
  account; keys are referenced by name, so per-machine material works without
  transporting anything
- **work-only machines need no `key.txt`** — nothing encrypted is applied
- **App Store**: sign in before bootstrapping any machine whose layers include
  `masApps` — an unsigned `mas` hangs the first activation indefinitely (it
  retries rather than failing). For that reason `masApps` live only in layers
  that imply a signed-in Apple ID (personal), never in shared

For headless/unattended bootstraps, preset the interactive prompts and apply-time
data via environment variables; prompts that can't be answered (no terminal and no
preset) fail fast instead of hanging:
- `DOTFILES_SSH_KEYS="git_a git_b"` — SSH keys to generate (set empty to skip)
- `DOTFILES_OVERLAY_KEYS="work=git_b"` — ssh key name per overlay clone
- `DOTFILES_NO_APP_STORE=1` — renders `machine.nix` with `appStore = false`,
  dropping all `masApps` (an unsigned `mas` would hang activation waiting on the
  sign-in dialog)

The age identity must still be pre-placed at `~/key.txt` when an enabled layer
applies encrypted targets.

To smoke-test in a local VM (Apple Silicon):

```bash
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest dotfiles-test
tart run dotfiles-test   # log in (admin/admin), open Terminal, run the curl one-liner
```

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

Git identities are provided by layers:
- **Personal layer**: default identity (han-tyumi), SSH key `~/.ssh/git_han-tyumi`
- **Overlay layers** can add identities scoped via `includeIf` (directory and remote
  patterns) and become the global default when the personal layer is absent — see the
  overlay repo's README

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

Nu-based CLIs (`apploi`, `wt`) live in `~/.local/bin` as `#!/usr/bin/env nu`
scripts so they run from any shell or automated session. Each is also exposed
as a completable nu command via a `symlink_<name>.nu.tmpl` in the nushell
`commands/` dir plus an `export use` line in its `mod.nu` (a shebang parses as
a comment, so the one source serves both). Such scripts must stay module-clean:
consts and defs only, no top-level statements.

All shells integrate:
- Homebrew environment via `/opt/homebrew/bin/brew shellenv`
- mise activation for runtime management

### External Resources

External resources are managed in `.chezmoiexternals/`:
- `personal.toml` — **V language** (git clone at `~/v`) and **Roc** nightlies; pure
  TOML, gated by `.chezmoilayers/personal.ignore`
- `overlays.toml.tmpl` — per-machine overlay repos (from chezmoi data) cloned to
  `~/.config/nix-darwin/overlays/<name>`
- `shared.toml` — **Nushell community scripts** (`nu_scripts`) under the nushell
  scripts dir

### Neovim Configuration

Neovim config is managed as an external git submodule (`dot_config/external_nvim/`) based on kickstart.nvim with custom plugins.

## Important Notes

- The flake's machine attr is generated per host from `scutil --get LocalHostName`
  (via `machine.nix`), so `darwin-rebuild switch --flake ~/.config/nix-darwin` needs
  no explicit attribute
- Node.js is pinned to version 24 via nixpkgs overlay
- Homebrew auto-updates and upgrades on activation
- Git ignores `.claude/*.local.*`, `.env.local`, `.mcp.local.json`, `CLAUDE.local.md`, and `mise.local.toml` globally
