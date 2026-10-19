# Machine: GPD Win Max 2 2025 with an RX 9070 XT eGPU

## Hardware

- **CPU**: Ryzen AI 9 HX 370, 12 cores / 24 threads (4 Zen 5 + 8 Zen 5c).
  Logical CPUs 0-7 are the Zen 5 cores (about 5.15 GHz under game load); 8-23
  are Zen 5c (about 3.3 GHz). A game's main thread on a Zen 5c core runs at
  roughly two thirds the speed, so check placement before blaming settings (see
  [Scheduler policy](#scheduler-policy)). Clocks depend on the TDP (see
  [Power](#power)); dense open-world scenes are usually CPU-bound here, ray
  tracing included (BVH updates run on the CPU).
- **Memory**: 32 GB LPDDR5X-8000, 8 GB of it reserved for the 890M (Windows sees
  about 23.6 GB). The 8 GB reservation is deliberate; revisit it only if a game
  runs short of system RAM (the BIOS can lower it to 1–2 GB).
- **GPUs**:
  - RX 9070 XT (RDNA 4, 16 GB) over OCuLink: renders games. Resizable BAR (Smart
    Access Memory) is on (verified 2026-10-06): BAR0 is 16 GB, not 256 MB. The
    BIOS switch is Advanced > GFX Configuration > PCIE Resizable BAR support; it
    also needs the PCI Subsystem's Above 4G Decoding and Resizable BAR, both on,
    and the Above 4GB MMIO Limit is 40-bit. To check unelevated, run `reg query` on the
    card's `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\VEN_1002&DEV_7550&...\Control`
    `AllocConfig` and decode its first descriptor (type 7, length scaled by its
    `LARGE_40` flag). WMI's `Win32_DeviceMemoryAddress` omits ranges over 4 GB, so it
    shows only the 256 MB BAR2.
  - Radeon 890M (iGPU): drives the internal panel and composes the desktop.
- **Storage**: 2 TB NVMe. Steam library at `D:\SteamLibrary`.

## Display path

- The internal panel is 2560x1600 at 60 Hz, with a 40 Hz mode and **no VRR**. A
  frame that misses a refresh is shown twice: that hitch is what "steady 60"
  avoids.
- The panel hangs off the 890M, so every eGPU frame is copied across adapters
  (about 1 GB/s at 1600p60). PresentMon reports this path as
  `PresentMode = Composed: Flip`. Whether the driver uses the one-copy CASO path
  at this resolution is unverified.
- Frame generation (FSR FG, AFMF) belongs only in a profile for an external VRR
  monitor, never on the internal panel.
- Fallback when 60 can't hold: the panel's 40 Hz mode with a 40 fps cap. It's
  smoother than a 60 cap that misses.

## Power

- Docked play is on AC. TDP is set by **Motion Assistant** (GPD's 1.2.1.1 with the
  PawnIO Power Mod 2.2.3.1) at `C:\Program Files\Motion Assistant`. It requires
  admin, so only the user can launch it or change its settings.
- The TDP only applies while Motion Assistant runs **and** the profile has
  `AutoSetTDP=True` ("Auto Apply TDP" on the TDP tab); otherwise the board keeps
  its own default. One value per power source (`ACTDP`, `DCTDP`) sets STAPM, slow
  and fast together; GPD's range for this model is 15–35 W. The header's
  "TDP Limit" shows the applied value.
- Settings are ASCII INIs whose first line is `[]`, under `Profiles\`:
  `Global.ini`, `General\default.ini`, and per-game `Process\<ProcessName>.ini`,
  which replaces the default while that game runs. A per-game file name must
  match `Get-Process`'s `ProcessName` exactly (case-sensitive, no `.exe`). Files
  are edited (by the user, elevated) only while Motion Assistant is closed, never
  with a UTF-8 BOM; adding or deleting a profile in its UI rescans the folder.
  Read them unelevated to check:
  ```powershell
  $profiles = 'C:\Program Files\Motion Assistant\Profiles'
  Get-Item -LiteralPath "$profiles\General\default.ini", "$profiles\Process\<ProcessName>.ini" -ErrorAction SilentlyContinue |
    Select-String -Pattern '^(ACTDP|AutoSetTDP|ACRTSS)='
  Get-Process MotionAssistant -ErrorAction SilentlyContinue | Select-Object Id, StartTime, MainWindowTitle
  (Get-ScheduledTask -TaskName MotionAssistant -ErrorAction SilentlyContinue).Actions.Execute
  ```
  A returned process means it's running. While it sits minimized in the tray its
  title is empty; once the user opens its window, the title must end in
  `Power Mod 2.2.3.1` (see [Known gotchas](#known-gotchas)).
  The task exists once the user ticks "Start with windows" on the Advanced tab; it
  starts the Program Files exe elevated at logon, and "Minimized to tray" keeps it
  out of the way.
- Keep the FPS limit (`ACRTSS`) at 0. Motion Assistant writes it to RTSS's global
  profile whatever the value (0 means no cap), and a per-game profile also creates
  that game's `<exe>.cfg` in RTSS's profiles; any non-zero value starts RTSS and
  caps every game, fighting the game's own limiter.
- While its hardware monitor is on, Motion Assistant reapplies the TDP when
  package power runs above the TDP + 2 W (about every 2 s) or between 10 W and
  the TDP − 5 W (about every minute), so a TDP another tool sets doesn't stick.
- Target 28–30 W on AC. Go to 35 W when captures are CPU-bound and temperatures
  stay in range. During a drop, CPU package power well below the target (HWiNFO)
  means the TDP isn't applied.
- PCIe ASPM is off on AC and DC (the user set both with powercfg), which keeps
  the OCuLink link out of low-power link states and their wake-up latency, also
  through a brief AC drop.

### Scheduler policy

Windows defaults `SCHEDPOLICY`, `SHORTSCHEDPOLICY` and `HETEROPOLICY` to 5, 5
and 4 (automatic), which steer a game's busiest thread to the Zen 5 cores:
with them, Witcher 3's busiest CPU was a Zen 5 core in 100% of a 40-minute
session's seconds. Explicit overrides of 0 ("any processor") in the Balanced
plan stop the steering: with them it was 3% in one session and 61-85% of each
minute in the next. Motion Assistant writes these on every start (at logon, or
a relaunch from the tray) from the core dropdown on its TDP tab, for the active
power source only. "All Cores Auto", its default when the profile has no
`ACCoreSet`, writes 0, 0, 0; none of its options gives Windows' 5, 5, 4. Since
2026-10-16 the default profile has `ACCoreSet=AllCoresPrefPCore` ("Prefer
P-Cores"), which writes `SCHEDPOLICY` 2, `SHORTSCHEDPOLICY` 2 and `HETEROPOLICY`
1 on AC; DC keeps 5, 5, 4. A per-game profile replaces the default, so it needs
the same dropdown setting. They're hidden settings, so `/query`
prints nothing for them; read them unelevated with `/qh`:

```powershell
powercfg /qh SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY
powercfg /qh SCHEME_CURRENT SUB_PROCESSOR SHORTSCHEDPOLICY
powercfg /qh SCHEME_CURRENT SUB_PROCESSOR HETEROPOLICY
```

If AC reads 0, 0, 0, the user sets the dropdown back to "Prefer P-Cores" and
clicks that row's Apply, then restarts the game. Running powercfg by hand holds
only until Motion Assistant's next start (elevated; the same line with 0, 0, 0
undoes it):

```powershell
foreach ($setting in 'SCHEDPOLICY 5', 'SHORTSCHEDPOLICY 5', 'HETEROPOLICY 4') { $name, $value = $setting.Split(' '); powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR $name $value; powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR $name $value }; powercfg /setactive SCHEME_CURRENT
```

Leave
Windows Game Mode off: its power overlay sets `CPMINCORES1`, the minimum share
of unparked Zen 5 cores, to 0. `scripts/watch-cores.ps1` logs placement
during a session: a main thread near 100% of one core with the busiest logical
CPU at 8 or above means it's on Zen 5c.

## Machine state

[machine-state.json](machine-state.json) declares the machine-wide settings every
game relies on: the Adrenalin global Graphics settings per GPU and its
Preferences, per-game GPU preferences, Game Mode off, startup entries that should
stay out, the power-plan values above, the Motion Assistant default profile, the
processes and logon tasks that must exist, and the AMD driver version.
`scripts/check-machine.ps1` compares the machine with it, unelevated:

```powershell
pwsh -NoProfile -File scripts/check-machine.ps1          # report
pwsh -NoProfile -File scripts/check-machine.ps1 -Apply   # also fix what it can
```

`-Apply` fixes Adrenalin (its window must be open), GPU preferences, HKCU values
and startup entries. Power settings, Motion Assistant, RTSS and drivers need
admin, so they print as `manual` with what the user should do. A game that isn't
installed is skipped, and its preference stays declared for a reinstall. When a
machine-wide default changes, update the JSON in the same change. The Windows
settings chezmoi already provisions (GameDVR and the driver-update policy in
`run_onchange_after_35-registry-tweaks.ps1`, RTSS profiles in
`run_onchange_after_40-rtss.ps1`) aren't repeated here.

## Drivers

- AMD Adrenalin 26.9.2 (driver 32.0.32015.2008) on both GPUs. Windows Update can
  replace it with an older WHQL package: after a Windows feature update, confirm
  both adapters still report this version
  (`Get-CimInstance Win32_VideoController | Select Name, DriverVersion`).
- A driver install can bugcheck mid-swap on this machine (2026-10-05: 0x7E in
  `dxgmms2!VIDMM_GLOBAL::InitPagingProcessVaSpace` right after an `amdkmdag.sys`
  swap); rerunning the installer restores Adrenalin. Downloads from amd.com need an amd.com Referer; use the
  `-b` combined package.
- Leave the AMD User Experience Program unticked in the Adrenalin installer and
  off in Settings > Preferences. Its `AUEPMaster.exe` spawns `cmd.exe /C
  "powershell ..."` at logoff, which fails with 0xc0000142: one or more
  "cmd.exe - Application Error" popups at every shutdown (System event 26, then
  winsrvext 100 "AUEPMaster.exe is delaying system shutdown" ~5 s later). Every
  Adrenalin install so far has re-added it; the `\AMDInstallLauncher` task
  (`InstallManagerApp.exe /InstallAUEP`) can too.

## Adrenalin profile

The baseline lives in the global settings (Gaming > Graphics, set for both GPU 1
and GPU 2), so every game inherits it through "Use Global Experience". Both GPUs
matched it on 2026-10-16. A per-game override is for an exception that game
needs, recorded in its `games/` file; making one switches that game to its own
Custom Gaming Experience, so later global changes stop reaching it.

| Setting | Value | Why |
|---|---|---|
| Radeon Chill | Off | Fights the game's own limiter, and as a 60/60 cap it paces worse than RTSS ([Frame caps](#frame-caps)). |
| Enhanced Sync | Off | Lets frames tear below 60; use the game's vsync. |
| AFMF (Fluid Motion Frames) | Off | See [Display path](#display-path). |
| Radeon Image Sharpening | Off | Stacks on the game's own sharpening and sharpens the UI. Not offered as its own toggle on this driver. |
| Radeon Super Resolution | Off | Upscales UI too; use the game's upscaler. |
| Radeon Boost | Off | Drops resolution on motion. |
| AMD FSR Upscaling (9070 XT) | On | Upgrades a game's FSR 3.1 to FSR 4 where supported. |
| Wait for Vertical Refresh | Off, unless application specifies | The game's own vsync setting decides. |
| Anti-Lag | Off globally | Use the game's Anti-Lag 2 when offered; driver Anti-Lag is a per-game exception, worth an A/B only when GPU-bound. |
| Texture Filtering Quality | High | Costs next to nothing on either GPU; set 2026-10-16 (Standard before). |

[machine-state.json](machine-state.json) holds the full list for both GPUs,
Preferences included; see [Machine state](#machine-state).

`scripts/adrenalin.ps1` reads and sets these through the desktop app's
accessibility tree, unelevated, with no clicking. It needs the window open, not
only the tray icon; if it isn't, ask the user to open AMD Software. Its synopsis
has examples.

- A game on "Use Global Experience" can't take a per-game change directly:
  enabling a feature opens a dialog that would switch the game to a Custom
  Gaming Experience. The script prints the dialog and cancels it; rerun with
  `-Confirm` to accept.
- Global Gaming > Graphics has a GPU 1 / GPU 2 picker; GPU 1 is the 890M. Opening
  the page resets it to GPU 1, so pass `-Gpu 2` on every `-Graphics` call for the
  9070 XT. Per-game pages show the 9070 XT's options (the FSR ML-based upgrade),
  not the 890M's.
- Toggling a global setting and back can relabel the global experience from
  Custom to Default with every value unchanged. Clicking "Custom" restores the
  label and keeps the settings.
- The in-game overlay (Alt+R) is off (Settings > Preferences > In-Game Overlay),
  so it opens in no game; use the desktop app. Record & Stream isn't installed.
- AMD Noise Suppression is off and its `AMDNoiseSuppression` entry is out of
  the user's Run key (removed 2026-10-16); an Adrenalin install can add it back.

### Frame caps

For a game without its own limiter, or whose vsync stalls on the cross-adapter
path, cap it with RTSS. Caps are declared in the chezmoi source, so a rebuilt
machine gets them back:

1. Add `dot_config/rtss/profiles/<exe>.cfg` to the chezmoi source with only the
   keys to set, e.g. `[Framerate]` / `Limit=60`.
2. On `chezmoi apply`, `run_onchange_after_40-rtss.ps1` merges those keys into
   RTSS's `Profiles\<exe>.cfg`, keeping keys RTSS's own UI added. It also
   grants the user write access to `Profiles`, sets `StartWithWindows=1`, and
   registers the `RTSS` logon task, self-elevating once only when the grant or
   task is missing.
3. To cap now without waiting for an apply, write the same keys straight into
   RTSS's copy, ASCII (the folder is already user-writable here):
   ```powershell
   $profilePath = 'C:\Program Files (x86)\RivaTuner Statistics Server\Profiles\<exe>.cfg'
   [IO.File]::WriteAllText($profilePath, "[Framerate]`r`nLimit=60`r`n", [Text.Encoding]::ASCII)
   ```

- RTSS reads a profile when the game starts; editing it while the game runs
  changes nothing until the next launch.
- RTSS must be running before the game. The `RTSS` task starts it elevated at
  logon; otherwise only the user starts it, since it needs admin. Check with
  `Get-Process RTSS`.
- Motion Assistant writes RTSS's `Global` profile and, for each of its per-game
  profiles, that game's `<exe>.cfg` (see [Power](#power)). Before writing a cap,
  check that the game has no Motion Assistant profile under `Profiles\Process`,
  or its next start overwrites the cap.
- On Enshrouded, RTSS at 60 held 1 frame in 30 s where Radeon Chill at 60/60
  held 11.

## Tools

| Tool | Where | Notes |
|---|---|---|
| PresentMon (console) | `presentmon` on PATH (winget `Intel.PresentMon.Console`) | Unelevated, because the user is in Performance Log Users. Wrapped by `scripts/capture-frames.ps1`, which reads the refresh rate from the active display. |
| GPU-Z | `C:\Program Files (x86)\GPU-Z\GPU-Z.exe` (winget `TechPowerUp.GPU-Z`) | Requires admin, so the user starts it. Once it's open, `scripts/read-gpuz.ps1` reads its fields unelevated for the card selected in its dropdown: Bus Interface (`max @ current` link), Resizable BAR, driver, and the Sensors tab's load, board power, clocks, voltage, hot spot and VRAM. |
| HWiNFO64 (free) | `C:\Program Files\HWiNFO64\HWiNFO64.EXE` (winget `REALiX.HWiNFO`) | Requires admin, so the user runs it and clicks Logging start; command-line CSV logging (`-l`) is Pro-only. CPU package power, clocks, temperatures, GPU power. |
| RivaTuner Statistics Server | `C:\Program Files (x86)\RivaTuner Statistics Server` (winget `Guru3D.RTSS`) | Frame caps for games without a usable limiter; see [Frame caps](#frame-caps). Runs elevated: the `RTSS` logon task starts it, or the user does. |
| WinDbg | `kdX64.exe`, `cdbX64.exe`, `WinDbgX.exe` aliases (winget `Microsoft.WinDbg`) | Runs unelevated. See [crash dumps](#crash-dumps). |

Never pass `--restart_as_admin` to PresentMon; it triggers UAC. Never launch GPU-Z
or HWiNFO yourself: both raise a UAC prompt.

### PresentMon notes

- Hardware-accelerated GPU scheduling is on for both GPUs (`dxdiag /t <file>`,
  "Hardware Scheduling"), so GPU busy and wait times are approximate to about
  0.5 ms.
- Vulkan and OpenGL games report `PresentRuntime = Other`. Their CPU frame
  times, and the latencies derived from them, are slightly less accurate, and
  `CPUFramePacingStall` stays 0; GPU busy and displayed times are unaffected.
- Exit 6 means the trace session failed to start: a stale session (the script's
  `--stop_existing_session` handles it) or lost Performance Log Users access
  (`whoami /groups` should list S-1-5-32-559). `--help` prints to stderr and exits 1.
- The scripts parse columns by name, so adding flags is safe for them, but each
  `--track_*` beta flag adds columns.
- Column names depend on the schema. `capture-frames.ps1` passes
  `--v2_metrics`: `CPUStartTime`, `FrameTime`, `CPUBusy`, `GPUBusy`,
  `DisplayedTime`. A plain `presentmon` run writes the 2.x default:
  `CPUStartTimeInMs`, `MsBetweenPresents`, `MsCPUBusy`, `MsGPUBusy`,
  `MsBetweenDisplayChange`. `analyze-frames.ps1` reads both; an ad hoc script
  must use the names in the file's header. `DisplayedTime` is `NA` for a frame
  that was never shown.
- A second, short probe can run beside a long capture under its own session
  name, without disturbing it:
  ```powershell
  presentmon --process_name <exe> --output_file <probe.csv> --session_name tune-game-probe --timed 60 --terminate_after_timed --no_console_stats
  ```
- Unelevated, `--terminate_on_proc_exit` never fires: PresentMon can't see the
  game exit. `capture-frames.ps1 -Seconds 0` watches the game itself and stops
  the session about 10 s after it exits. A stray session from a raw
  `presentmon` run stops with `presentmon --terminate_existing_session
  --session_name <name>`; exit 7 ("no existing sessions found") means it had
  already ended and the CSV is complete.
- Killing `presentmon` with `Stop-Process` leaves its ETW session alive. The
  next capture then reports "ETW events were lost" and records no frames.
  Before capturing again, run the `--terminate_existing_session` line above for
  each `tune-game-<label>` session left over.

### OCuLink link check

Windows can't show the OCuLink link: `DEVPKEY_PciDevice_CurrentLinkSpeed` on the
9070 XT reports Gen5 x16, which is the link to Navi 48's on-package PCIe switch.
GPU-Z's Bus Interface does show the OCuLink link: `PCIe x16 5.0 @ x4 4.0` while the
GPU is active (verified 2026-10-06), dropping to `@ x4 1.1` at idle as power
management slows the link. Have the user open GPU-Z on the 9070 XT and start its
render test (the `?` beside Bus Interface) or a game, then run
`scripts/read-gpuz.ps1 -Samples 15`. The same samples show whether the card is
really working: at full load it draws about 250-300 W. GPU load flipping
between 0% and 100% at 40-130 W while PresentMon reports high GPU busy means
the GPU is waiting, not loaded (see SKILL.md step 7). Under load, anything other than `@ x4 4.0`
means a cable or seating problem. HWiNFO's GPU `PCIe Link Speed` sensor (16 GT/s is
Gen4) is the fallback.

### HWiNFO logs

The user starts logging from the sensors window. The CSV is Windows-1252 (the `°`
in `[°C]`), so read it with `Import-Csv -Encoding 1252`. Value names repeat across
the two GPUs, which breaks `Import-Csv`; ask for the "sensor name|value name" header
format, or read with `-Header`. Headers are prefixes of the full sensor names, so
match columns with `-like '*<name>*'`. A sensor that appears mid-log gets a
column `Import-Csv` drops, since it reads only the first header row. The last two
rows are a footer, written only when logging stops cleanly. Useful
columns: `CPU Package Power`, `CPU PPT`, `APU STAPM Limit`, `Thermal Limit`,
`Core Effective Clocks`, `Total GPU Power`, `GPU Clock`, `GPU Hot Spot Temperature`.
A sustained CPU package power below the Motion Assistant TDP during drops means
the TDP isn't applied.

### Crash dumps

Kernel minidumps are in `C:\Windows\Minidump`, readable only elevated: ask the
user to copy one from an elevated prompt
(`Copy-Item C:\Windows\Minidump\<file>.dmp $env:LOCALAPPDATA\tune-game\`).
Application dumps in `%LOCALAPPDATA%\CrashDumps` or the game's own folder read
directly. Then (first run downloads about 115 MB of symbols, about 2 minutes):

```powershell
$symbols = "srv*$env:LOCALAPPDATA\tune-game\symbols*https://msdl.microsoft.com/download/symbols"
'' | & kdX64.exe -z <dump> -y $symbols -logo <log.txt> -c '!analyze -v; lm t n; q'
```

Use `cdbX64.exe` with the same arguments for an application dump. Read
`BUGCHECK_CODE`, `SYMBOL_NAME`, `IMAGE_NAME` and `FAILURE_BUCKET_ID` from the log;
an `amdkmdag.sys` in the unloaded-module list means a driver swap happened before
the crash.

## Known gotchas

- **D3D12 device removal**: World of Warcraft crashed with device loss under
  D3D12 on this eGPU; forcing D3D11 (`SET gxApi "D3D11"` in `Config.wtf`) fixed
  it. Try the same for other games that crash with `DXGI_ERROR_DEVICE_REMOVED`,
  and treat turning off Hardware-accelerated GPU scheduling (on for both GPUs
  today) as an untested toggle if the error recurs.
- **eGPU surprise removal**: moving the charger cable between the USB-C ports
  dropped the RX 9070 XT off the bus 10 ms after AC loss, and Windows hung past
  a watchdog live dump until a forced power-off. A 9-second AC blip earlier the
  same day left the eGPU connected, so the OCuLink plug getting jostled is the
  likely cause, not the switch to battery. Change charger ports only with games
  closed, and steady the OCuLink plug while doing it.
- **Old Motion Assistant copy**: a backup of the previous build (title
  `Power Mod 2.1.1`) sits under `Documents\Backups` with its exe renamed to
  `MotionAssistant.exe.disabled`. It loads the old WinRing0 driver
  (`WinRing0_1_2_0`) and keeps its own `Profiles\`, and Motion Assistant allows
  one instance by process name, so a running old copy blocks the real one. Check
  the window title before trusting what the app shows.
- **Settings resets**: some games rewrite their config on launch or on a preset
  click. Recheck the file after the first launch.
- **Shader compilation**: the first launch after a driver update recompiles
  shaders; don't capture until the game has warmed its cache in the test area.
- **Speaker pops**: the built-in speakers popped during play while AirPods
  stayed clean. The speaker endpoint runs five DTS effect stages (DTS Sound
  Unbound / DTS:X Ultra); the first fix is Settings > System > Sound >
  Speakers > Audio enhancements Off and Spatial sound Off. An unconfirmed
  fallback, reported on the Win 4 2025: the catalog AMD HD Audio Controller
  driver with `MSISupported=1`. LatencyMon needs admin, so the user runs it.

## Device quirks

Researched 2026-10-06 (GPD, DroiX, owner reports). BIOS 0.21 and EC 0.10 are
the newest for this model.

- **Spacebar misses**: one switch under the centre of the bar. The owner fix
  from earlier models is a shim (about 1 mm of tape) on the keycap's underside
  where it meets the switch; there's no firmware fix. Self-repair damage voids
  DroiX's warranty, so consider warranty service first.
- **Controller**: `VID_2F24&PID_0135`, DMI `G1619-05`. GPD lists WinControls
  v1.16 and the GamePad Test Calibration Tool V1.03 for the 2025, and no
  gamepad firmware. Its downloads sit behind an image verification code, so
  the user fetches them. V1.02 and V1.03 are on the Desktop (unsigned, run
  without admin); WinControls is in `C:\Program Files (x86)\win3`. The
  calibration tool's UI is Chinese only: 开始校准 starts calibrating,
  校准成功! means it succeeded, 校准失败! that it failed, and a mode error
  means the gamepad/mouse switch is on mouse. Its status line reads 已校准
  (calibrated) and the controller firmware as X315K123. V1.03's window is
  titled "win3 Test V1.0.3" and opens over an unrelated "HJZ Controller
  Tester for PS3&PS4" window that reports the device disconnected. Don't flash firmware v3.14 /
  v1.23: it's listed only for the 6800U, 7640U and 7840U models.
- **Left stick, upper arc**: on this unit the left stick read only 72-85% of
  full scale from NE to NW, though it travels fully (XInput log, 2026-10-07).
  The module has vertical play: pressing the stick down lifts north from 75%
  to 91-100%, and it falls back once the stick recenters. The sticks are
  contactless magnetic (Hall), so dry-cleaning changed nothing. The unit had
  never been calibrated by the user (the status read 已校准 from the factory),
  and a first V1.03 calibration fixed it (98-121% in every direction, rest
  still 0,0). Roll the left stick around the rim with a light touch that
  reaches the edge, without pressing down, since pressing down reads high.
  Recalibrate if it comes back; the fallback is a Steam Input outer deadzone
  of about 75%, then warranty service through DroiX (2 years; no
  replacement module is sold). WinControls has only deadzone and centring offsets,
  no range scale.
- **GPD Tool 1.65** replaces Motion Assistant (TDP up to 40 W, vibration, back
  buttons). Don't run both at once.
- **Charge limit**: on the 2025 the BIOS charge-limit option reportedly changes
  only the LED behaviour, not the charging. Docked on AC all day, watch the
  battery for swelling.
- **Phantom touches** (GXTP7385 touchscreen): disabling the HID-compliant pen
  device is the owner fix.
- **eGPU**: OCuLink isn't hot-pluggable. Connect or disconnect it only with
  the laptop off, and power the eGPU on before the laptop. Fast startup makes
  Shut down a kernel hibernate, so a swap after it fails the resume
  (Kernel-Boot 29, `0xC00000D4`, then Kernel-Power 41) and cold-boots, losing
  the last unflushed writes, event log entries included. Hold Shift while
  clicking Shut down before a swap for a full power-off.
- **Don't flash**: BIOS 0.42, the touchpad firmware, or the gamepad firmware
  above; none are for the HX 370.
