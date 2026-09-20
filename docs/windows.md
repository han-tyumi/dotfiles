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
| `run_once` (once, then recorded) | `60-nerdfont` · `70-psfzf` |

`35-registry-tweaks` pops a single UAC prompt, but only when its HKLM keys have
drifted. Windows features are **not** in this table — they're the opt-in
`windows-features` command (see below), kept out of the auto-apply path.

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

The captured optional features — .NET 2/3/4, legacy media (WMP + DirectPlay), a daily
registry-backup task, and the OpenSSH server — are enabled by the **`windows-features`**
command. It's opt-in (not run by `apploi`, since enabling them is slow and elevated),
self-elevates (one UAC prompt), and each step is a no-op when already enabled. Only the
OpenSSH server has a runtime footprint (an `sshd` service + inbound TCP 22); the rest
stay dormant until used. To turn SSH off: `Stop-Service sshd; Set-Service sshd
-StartupType Manual`.

## Drivers

winget does not service hardware drivers, and neither does anything here. Only the
policy half is automated: `35-registry-tweaks` sets `ExcludeWUDriversInQualityUpdate`
so Windows Update stops swapping a tuned GPU/OEM driver for a generic one (feature
updates reset it, which is why it's re-asserted rather than set once).

The rest is deliberate and manual. Non-GPU drivers (WiFi, Bluetooth, chipset) can go
through `PSWindowsUpdate` from an elevated shell — `Get-WindowsUpdate -UpdateType
Driver` to see what's on offer, then `Install-WindowsUpdate -UpdateType Driver
-AcceptAll -IgnoreReboot`. Never on a schedule and never with `-AutoReboot`: a
handheld can be mid-game. GPU (AMD Adrenalin / Intel Graphics), the OEM driver pack,
and BIOS/EC firmware are hand-installed; freeze a known-good GPU driver and move off
it on purpose.

## Games in Steam

Launchers hand a game off to a process Steam never started, so a plain non-Steam
shortcut reports "Playing" for a few seconds and then stops. `game-launch.ps1` stands
in for it: start the game, find its process, block until it exits. Steam reports the
shortcut as running for exactly as long as that script lives, which is what makes the
game show on the friends list.

Three files in `~/.config/windows/`, all owned by the `personal` layer:

| File | Role |
|---|---|
| `games.json` | registry — launchers, and the games that use them |
| `game-launch.ps1` | the runner (needs PowerShell 7) |
| `game-launch.vbs` | wscript front so no console flashes; takes the game key |

Steam shortcut fields, where `<key>` is a `games` key from the registry:

| Field | Value |
|---|---|
| Target | `C:\Windows\System32\wscript.exe` |
| Start In | `C:\Users\<you>\.config\windows` |
| Launch Options | `"C:\Users\<you>\.config\windows\game-launch.vbs" <key>` |

Every game reuses that one script pair and differs only in the trailing key. Progress
goes to `%LOCALAPPDATA%\game-launch.log`, which is the first place to look when a
launch does nothing.

### Strategies

A launcher declares how to get past its Play button:

- **`uri`** — the launcher handles a launch URI itself; nothing else needed.
- **`cdp`** — drive the launcher's embedded browser, for clients whose URI only
  navigates. Battle.net needs this.
- **`direct`** — run the game executable, for launcher-less installs.

Only `cdp` has been exercised. `uri` and `direct` are written but unproven — nothing
on this machine uses them.

Finding the game once it starts is shared by all three, and is the part that has to
be right: the runner records the time, issues the launch, then polls for a process
whose image sits under the game's `installDir` and that started after the stamp. That
beats matching on the executable name, which is ambiguous (`WowClassic.exe` is four
products) and wrong whenever a launcher hands off through a stub that exits — a
switcher for StarCraft II and Heroes of the Storm, an anti-cheat shim for many Epic
titles, `PlayGTAV.exe` for Rockstar. Point `installDir` at the game folder and the
hops stop mattering. The name remains a cheap prefilter and both fields are optional,
but a game with neither cannot be found.

Notes for the launchers not yet configured here, none of them verified on a machine:

| Launcher | Approach |
|---|---|
| GOG | `direct` — DRM-free; going through Galaxy is discouraged |
| Ubisoft | `direct` is better than `uri`; games start `upc.exe` themselves, and the Steam overlay is reported to break when launched through the client |
| Epic | `uri`, but the short `apps/<AppName>` form was removed — current is `com.epicgames.launcher://apps/<Namespace>%3A<CatalogId>%3A<AppName>?action=launch&silent=true`, with the ids read from the `.item` manifests in `%PROGRAMDATA%\Epic\EpicGamesLauncher\Data\Manifests` |
| Riot | `RiotClientServices.exe --launch-product=<x> --launch-patchline=live`; note a League *match* is a different process from the client, so track the game directory |
| Rockstar | No documented URI or CLI for launching a specific title; the worst fit |

Every one of these clients is CEF, so `cdp` is in principle available for all of them,
but the flag only takes effect at a cold start — reaching it means killing a client
that is already open. Treat it as the last resort it is for Battle.net. Riot shipped
such a port and then removed it in a patch, which is the standing risk: a vendor can
withdraw that surface, and the selectors are remote-served anyway.

### Why Battle.net needs `cdp`

`battlenet://<uid>` only opens the client on that game, and `--exec="launch_uid <uid>"`
selects the product without pressing Play. Nor can the launcher's credentials be
reused: Battle.net mints a single-use token per Play press and writes it to
`HKCU\Software\Blizzard Entertainment\Battle.net\Launch Options\WoW`, and replaying a
spent one gets an external-auth challenge the client cannot answer. Pressing Play is
the only way in.

The client is a CEF app that leaves remote debugging unset, so starting it with
`--remote-debugging-port` exposes a DevTools endpoint on the game list page. The
runner clicks `button.play-btn.play-action` over that protocol. Selecting by class
rather than screen coordinates keeps it independent of DPI scaling, window position
and layout: a promo takeover painted over the button does not block a dispatched
click, and the page is never marked inert.

Two guards before it clicks — the button label must read exactly `Play`, so a pending
patch showing `Update` is never triggered, and where `productMatch` is set the product
selector must contain it.

While the client runs under this, its DOM is reachable by any local process on
127.0.0.1:9222. Loopback-only and only while the client is open, but it is a real
widening of that surface.

### Adding a Battle.net game

Read the uid off the machine rather than trusting a list: the `Product` column of
`.build.info` in the install folder, or the `Games` keys in
`%APPDATA%\Battle.net\Battle.net.config`.

```json
"overwatch": {
  "launcher": "battlenet",
  "id": "pro",
  "process": "Overwatch",
  "installDir": "D:\\Overwatch"
}
```

`process` is the name without `.exe`. `installDir` is what makes the match reliable —
give it whenever you know the folder. `productMatch` is optional and belongs only on
games whose client shows a version dropdown; setting it where there is no selector
leaves a guard that can never pass.

| Game | uid | Process | Selector |
|---|---|---|---|
| WoW retail | `wow` | `Wow` | version |
| WoW Classic Era | `wow_classic_era` | `WowClassic` | version |
| WoW Forever beta | `wow_classic_beta` | `WowB` | version |
| Overwatch 2 | `pro` | `Overwatch` | none |
| Diablo IV | `fenris` | `Diablo IV` | none |
| Diablo II: Resurrected | `osi` | `D2R` | none |
| Hearthstone | `hsb` | `Hearthstone` | none |
| Heroes of the Storm | `hero` | `HeroesOfTheStorm_x64` | none |
| StarCraft II | `s2` | `SC2_x64` | region — unsupported |

StarCraft II and Heroes of the Storm start a switcher that exits once the real binary
is up. Because the runner polls by name instead of waiting on what it started, that
handoff is invisible — point `process` at the final binary.

### Known limits

- **Region pickers cannot be automated.** StarCraft II, Diablo III and Warcraft III
  put a region dropdown over Play with no way past it unattended.
- **The selectors are remote-served.** `play-btn` and friends come from
  `content-ui.battle.net` and appear in no installed file, so they can change with no
  client update. That is why they sit in `games.json` — a break is a config edit, not
  a code change.
- **Executable names are shared.** `WowClassic.exe` covers four WoW products and
  `WowB.exe` two, so the process name alone cannot tell flavors apart when several are
  installed.
- **Call of Duty is a poor fit**: `cod.exe` is a shared shell across several titles.
- **A uid can expire.** `wow_classic_beta` belongs to the Forever beta, which ends
  2026-10-21; re-read the uid after the 2026-11-04 release.

### Shortcuts do not travel

Steam Cloud syncs neither `shortcuts.vdf` nor the `config/grid/` artwork beside it;
both are per-machine. `chezmoi apply` brings the scripts, but each machine needs its
Steam shortcut added by hand. Non-Steam games appearing on another device is Remote
Play advertising from a running host rather than sync — they vanish when that host's
Steam closes.

## Deferred

- **O&O ShutUp10** — granular per-app privacy (camera/mic/location defaults,
  SmartScreen data, inking/typing data) that WinUtil doesn't cover; a candidate to
  add later.
- **Device-specific categories** — GPD/AMD/gaming tools, Fallout 4 config — kept out
  of the shared config for now.
