# Windows dotfiles — how it works

This machine runs the native-Windows profile (nushell + PowerShell, Zed, git,
Claude Code), provisioned with **winget** and **mise** instead of the Mac's
Nix/Homebrew stack. Everything is driven by **chezmoi** (the engine) and
**`apploi`** (the one command you run).

## The model

- **chezmoi** renders the source repo (`~/.local/share/chezmoi`, upstream
  `han-tyumi/dotfiles`) onto the machine: it writes config files to their real
  locations and runs provisioner scripts. `.chezmoiignore` decides what is Windows
  vs macOS.
- **`apploi`** is the one command that drives chezmoi, defined in both the nushell
  config and the PowerShell profile.

## `apploi`

Mirrors the Mac `apploi`: **plain `apploi` does everything**; each flag runs only
that step.

| Command | What it does |
|---|---|
| `apploi` | pull + `chezmoi apply` + `winget upgrade --all` + `mise upgrade` |
| `apploi -c` | config only: pull + apply, skip the upgrades (a quick sync) |
| `apploi -w` | upgrade winget packages only |
| `apploi -m` | upgrade mise plugins + runtimes (and regenerate the nushell activations) |

Every run prints a step line and checks GitHub for a newer WinUtil release. A dirty
working tree (mid-edit) skips the pull; a dirty submodule does not.

## What `chezmoi apply` does

1. **Writes config files** — nushell/pwsh config, the winget manifest, the WinUtil
   config, `CLAUDE.md`, etc.
2. **Runs provisioner scripts:**

| Trigger | Scripts |
|---|---|
| `run_onchange` (re-runs when *its content* changes) | `10-winget` (install apps) · `20-mise` (runtimes) · `30-nushell` (shell activations) · `35-registry-tweaks` (dev/privacy registry — self-elevates for the HKLM bits) |
| `run_once` (once, then recorded) | `45-windows-features` (.NET / media / SSH / reg-backup — self-elevates) · `50-emdash` · `60-nerdfont` · `70-psfzf` |

The self-elevating ones (`35`, `45`) pop a single UAC prompt when they fire.

## WinUtil tweaks

The debloat / privacy / QoL tweaks are captured in `~/.config/winutil/config.json`
(a flat list of WinUtil tweak IDs, pinned to a specific WinUtil version). They are
**not** re-applied every sync — they're one-time system state — so apply them
deliberately:

```
winutil-apply
```

`winutil-apply` runs `~/.config/winutil/manage.ps1 -Apply`, which **self-elevates**
(one UAC prompt), downloads the pinned WinUtil build, works around WinUtil's broken
headless mode (a null-guard + WPF preload — see the comments in `manage.ps1`), and
applies the config with no GUI. Run it on a fresh machine, after a Windows update
resets tweaks, or after bumping the pinned version.

**Update flow:** `apploi` prints a yellow notice when a newer WinUtil release exists.
To take it: bump `$PinnedVersion` in `manage.ps1`, re-verify `config.json` still
matches (WinUtil renames tweak IDs across versions), then `winutil-apply`.

chezmoi's `35-registry-tweaks` owns the dev/registry tweaks WinUtil doesn't (Explorer
dev settings, LongPaths, Developer Mode, GameDVR, WU driver-exclusion, PS7 telemetry
opt-out), so the two tools don't fight over the same keys.

## Windows features

`run_once_after_45-windows-features` enables the captured optional features: .NET
2/3/4, legacy media (WMP + DirectPlay), a daily registry-backup task, and the OpenSSH
server. Only the OpenSSH server has a runtime footprint (an `sshd` service + inbound
TCP 22); the rest stay dormant until used. It self-elevates once. To turn SSH off:
`Stop-Service sshd; Set-Service sshd -StartupType Manual`.

## Deferred

- **O&O ShutUp10** — granular per-app privacy (camera/mic/location defaults,
  SmartScreen data, inking/typing data) that WinUtil doesn't cover; a candidate to
  add later.
- **Device-specific categories** — GPD/AMD/gaming tools, Fallout 4 config — kept out
  of the shared config for now.
