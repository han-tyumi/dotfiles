---
name: tune-game
description: Tunes a PC game on this GPD Win Max 2 (Ryzen AI 9 HX 370, Radeon 890M driving the 2560x1600 60 Hz panel, RX 9070 XT eGPU) for the best image quality that holds a steady 60 fps. Finds and backs up the game's config, researches its settings, applies them, then verifies with PresentMon frame captures and iterates.
when_to_use: User names a game to optimize, tune, set up, or fix (stutter, low fps, frame drops, crashes) on this machine, or asks to capture or analyze a play session's frame rate.
argument-hint: <game name>
---

# tune-game

Game: $ARGUMENTS

Goal: **the best image quality that holds a locked 60 fps** on the internal
panel. Quality is spent only where 60 holds with headroom at the game's most
demanding spots.

Read [machine.md](machine.md) first: hardware, the eGPU display path, power, the
tool inventory, and known gotchas. Then check `games/` for a record of this game
from an earlier run and pick up from its status and next steps.

Scripts live in `${CLAUDE_SKILL_DIR}/scripts`; run each with
`pwsh -NoProfile -File <script> ...`. Each has a `.SYNOPSIS` with examples.

## Workflow

### 1. Identify the game

```powershell
pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/find-game.ps1" -Name '<game name>'
```

It prints the Steam app id, install path, the largest executables, and candidate
config folders. The candidates are leads: open them and find the actual settings
file. Confirm which executable renders (a launcher often starts the real exe; with
the game running, `Get-Process` shows it). Non-Steam games: locate the install and
config by hand.

### 2. Research

Before changing anything, establish for this game:

- **Where settings live**: file path and format (ini, json, xml, registry for
  Unity games under `HKCU\Software\<Company>\<Product>`). PCGamingWiki's
  "Configuration file(s) location" section is the fastest source.
- **What each setting costs**: per-setting benchmarks or optimized-settings
  guides (Digital Foundry, Hardware Unboxed, TechPowerUp, game-specific guides).
  Note whether each cost lands on the CPU or the GPU.
- **Known issues**: PCGamingWiki issues, the game's Steam forums and patch
  notes, and anything specific to RDNA 4, FSR 4, AMD drivers or DX12 on this
  driver branch.
- **Hidden settings** worth setting by file (an ini key with no menu option,
  values beyond the highest preset).

### 3. Back up

Copy each settings file to `<file>.pre-tuning-<yyyyMMdd>` beside it before the
first edit. Never overwrite an existing backup; if one exists for today, the
earlier backup is the one to keep. For registry-stored settings,
`reg export "<key>" "<backup>.reg"`.

When find-game lists a `userdata\<id>\<appid>` folder, the game uses Steam Cloud.
A settings file it syncs can come back from the cloud: if Steam reports a sync
conflict at launch, the user keeps the local copy. Note which files sync in the
game's record.

### 4. Choose settings

Apply these defaults unless the game's research says otherwise:

- **Output**: native 2560x1600, exclusive or borderless fullscreen. HDR off (the
  panel is SDR).
- **Upscaler**: FSR 4 > FSR 3.1 > XeSS > the game's TAA. Start at Quality. Turn
  off dynamic resolution unless it targets a fixed 60; it cannot help a
  CPU-bound frame.
- **Frame pacing**: the game's own 60 fps limiter plus vsync. Frame generation
  and AFMF stay off on the internal panel: at a 60 cap they render only 30 real
  frames, which doubles latency, and with no VRR every miss judders. Anti-Lag 2
  on when the game offers it.
- **Textures**: the highest tier that fits 16 GB of VRAM at this resolution.
- **Where quality goes**: textures, anisotropic filtering, then lighting and
  shadows. Ray tracing tiers next. Crowd density, draw distance and
  simulation settings are CPU costs; this CPU is the usual limit in dense
  open-world areas, so cut those first when drops are CPU-bound.
- **Avoid** in-menu presets after hand-editing a file; many games overwrite every
  key when a preset is clicked.

### 5. Apply

1. Edit the settings file, preserving its format, encoding and key order, while
   the game is closed: many games rewrite their settings on exit.
2. Route the game to the eGPU:
   ```powershell
   pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/set-gpu-preference.ps1" -ExePath '<game exe>'
   ```
   Once the game runs, confirm it renders there: the counter instance holding
   its dedicated memory carries the 9070 XT's LUID (LUIDs change across boots).
   ```powershell
   $gamePid = (Get-Process <ProcessName> | Select-Object -First 1).Id
   (Get-Counter "\GPU Process Memory(pid_$($gamePid)_*)\Dedicated Usage").CounterSamples | Select-Object InstanceName, CookedValue
   Get-ChildItem HKLM:\SOFTWARE\Microsoft\DirectX | Get-ItemProperty | Where-Object Description | ForEach-Object { '{0} 0x{1:x}' -f $_.Description, $_.AdapterLuid }
   ```
3. Give the user the Adrenalin per-game profile to set by hand (it can't be
   scripted): see the baseline in [machine.md](machine.md#adrenalin-profile).
4. Check the power setup with the read-only commands in
   [machine.md](machine.md#power). If Motion Assistant isn't running, its title
   isn't the 2.2.3.1 build, it has no startup task, or the profile has
   `AutoSetTDP=False` or an `ACTDP` outside 28–35, tell the user what to change in
   its UI; it needs admin.

### 6. Verify with a capture

Captures need PresentMon (`presentmon` on PATH) and run unelevated. Each saves a
CSV under `%LOCALAPPDATA%\tune-game\captures` and prints a summary, analyzed at
the active panel's refresh rate (`-RefreshHz` overrides it). A new capture stops
a running one with the same `-Label`, so give concurrent captures different
labels.

- **At a test spot**: once the user is standing at the game's most demanding
  spot, capture 60 s:
  ```powershell
  pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/capture-frames.ps1" -Process <exe> -Seconds 60 -Label <spot>
  ```
  `-DelaySeconds 10` gives the user time to get back into the game.
- **A whole play session**: start before the user launches the game, in the
  background, and read the result when the game exits:
  ```powershell
  pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/capture-frames.ps1" -Process <exe> -Seconds 0 -Label session
  ```
  `WorstWindows` lists the worst 10 s stretches by time since the capture
  started (m:ss); ask the user what was on screen then.
- **Core placement**: start next to a session capture, also in the background
  before launch. It logs once a second to the captures folder until the game
  exits, then prints the share of seconds the busiest CPU was a Zen 5 core:
  ```powershell
  pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/watch-cores.ps1" -Process <exe> -Label session-cores
  ```
  Rows carry wall-clock times; line them up with the capture's windows by the
  capture's start time (in its file name). CPU-bound drops while `BusiestOnZen5`
  is 0 point at the [scheduler policy](machine.md#scheduler-policy), not the
  game's settings.
- **Re-analyze** a saved CSV (`-AsJson` for comparisons). It defaults to 60 Hz;
  pass `-RefreshHz 40` for a capture taken at 40 Hz:
  ```powershell
  pwsh -NoProfile -File "${CLAUDE_SKILL_DIR}/scripts/analyze-frames.ps1" -Path <csv> -Process <exe>
  ```

Read the summary:

| Field | Meaning |
|---|---|
| `Steady` | True when held frames are at most 0.25% and drops at most 1%. This is the pass condition. |
| `HeldFrames`, `HeldPercent`, `RepeatedRefreshes` | Frames shown for 2+ refreshes; each repeat is a visible hitch. |
| `HeldGpuLimited` / `HeldCpuLimited` | Which side made each held frame late: the GPU when that frame's GPU busy filled 90% of a refresh, otherwise the CPU or pacing. |
| `FrameTimeSpikes`, `P99AnimationErrorMs` | Uneven motion that didn't repeat a refresh: present intervals over 1.5 refreshes, and how far on-screen motion drifted from the game's timing. |
| `OnePercentLowFps` | 1% low from frame times. Under ~55 fps at a 60 cap means regular hitches. |
| `MedianGpuBusyMs`, `P95GpuBusyMs` | GPU headroom at the cap. P95 above ~14 ms leaves no margin for heavier scenes. |
| `LooksCapped` | The capture sat at the cap; CPU busy then includes the limiter's sleep. |
| `SwapChains` | Each swap chain with its frames, held count and time span. A game that recreates its swap chain is analyzed across all of them; one presenting at the same time (a second window) is excluded. |
| `PresentMode` | `Composed: Flip` is the normal cross-adapter path here. |
| `HybridPresentFrames` | Only meaningful when the capture started before the game launched. |

A warning that frames stayed on screen longer than `-RefreshHz` expects means the
panel ran at another rate; re-analyze with the matching `-RefreshHz`.

### 7. Find the bottleneck when 60 doesn't hold

A capped capture hides the limit. Temporarily set the limiter off and vsync off,
capture 30 s at the same spot, then restore both:

- `MedianGpuBusyMs` close to `MedianFrameMs` (within ~10%): **GPU-bound**. Lower
  the upscaler tier, then the costliest RT or lighting setting.
- `MedianGpuBusyMs` well below `MedianFrameMs`: **CPU- or platform-bound**. Check
  the TDP first ([machine.md](machine.md#power)), then cut crowds, draw distance,
  foliage, and RT (BVH updates cost CPU).
- An uncapped frame rate far above 60 with drops only at the cap points to
  pacing (limiter, vsync, shader compilation) rather than raw performance.

### 8. Iterate

Change one group of settings at a time and recapture at the same spot with a new
`-Label`. Compare against earlier CSVs in the captures folder. Stop when the
demanding spots are `Steady` with `P95GpuBusyMs` under ~14 ms; then spend any
remaining headroom on the next quality setting and recheck.

If 60 can't hold without cutting quality the user cares about, fall back to 40:
the user switches the panel to 40 Hz (Settings > System > Display > Advanced
display), and the game's limiter goes to 40 with vsync kept on. Captures pick up
40 Hz on their own; at 40 the targets are `P95GpuBusyMs` under ~21 ms and
`OnePercentLowFps` of at least ~37. Record which rate the settings were tuned
for.

### 9. Record

Write or update `games/<game-slug>.md` in the chezmoi **source**, not the
applied copy:

```powershell
$skillSource = chezmoi source-path "$HOME\.claude\skills\tune-game"
# Edit $skillSource\games\<game-slug>.md, then:
chezmoi apply "$HOME\.claude\skills\tune-game"
```

Follow [games/the-witcher-3.md](games/the-witcher-3.md): status (applied,
verified, or regressed, with dates), exe and config paths, backups, a table of
changed settings with before, after and why, capture results, test spots, and
the next steps if 60 doesn't hold. Don't commit unless the user asks.

## Report to the user

- A table of changed settings (before → after, why).
- What the user must do by hand: Adrenalin profile, TDP, in-game checks.
- The capture verdict (`Steady`, 1% low, worst windows) or that it is untested.
