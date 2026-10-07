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
  about 23.6 GB). Lowering the BIOS UMA reservation to 1–2 GB frees RAM for games
  that need it, but it's untested.
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
  (Get-Process MotionAssistant -ErrorAction SilentlyContinue).MainWindowTitle
  (Get-ScheduledTask -TaskName MotionAssistant -ErrorAction SilentlyContinue).Actions.Execute
  ```
  The title must end in `Power Mod 2.2.3.1` (see [Known gotchas](#known-gotchas)).
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

The Balanced plan carries explicit overrides of 0 ("any processor") for
`SCHEDPOLICY`, `SHORTSCHEDPOLICY` and `HETEROPOLICY`, where Windows defaults
to 5, 5 and 4 (automatic). With 0, nothing steers a game's busiest thread to
the Zen 5 cores: in one Witcher 3 session the busiest CPU was a Zen 5 core in
3% of seconds, in the next in 61-85% of each minute, with no settings change.
Read the values unelevated:

```powershell
powercfg /query SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY
powercfg /query SCHEME_CURRENT SUB_PROCESSOR SHORTSCHEDPOLICY
powercfg /query SCHEME_CURRENT SUB_PROCESSOR HETEROPOLICY
```

Restoring the defaults is the user's change; they run this, then restart the
game (the same line with 0, 0, 0 undoes it):

```powershell
foreach ($setting in 'SCHEDPOLICY 5', 'SHORTSCHEDPOLICY 5', 'HETEROPOLICY 4') { $name, $value = $setting.Split(' '); powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR $name $value; powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR $name $value }; powercfg /setactive SCHEME_CURRENT
```

Whether the defaults keep the main thread on Zen 5 is untested; if it still
lands on 8-23, try `SCHEDPOLICY 2` (prefer performant processors). Leave
Windows Game Mode off: its power overlay sets `CPMINCORES1`, the minimum share
of unparked Zen 5 cores, to 0. `scripts/watch-cores.ps1` logs placement
during a session: a main thread near 100% of one core with the busiest logical
CPU at 8 or above means it's on Zen 5c.

## Drivers

- AMD Adrenalin 26.9.2 (driver 32.0.32015.2008) on both GPUs. Windows Update can
  replace it with an older WHQL package: after a Windows feature update, confirm
  both adapters still report this version
  (`Get-CimInstance Win32_VideoController | Select Name, DriverVersion`).
- A driver install can bugcheck mid-swap on this machine (2026-10-05: 0x7E in
  `dxgmms2!VIDMM_GLOBAL::InitPagingProcessVaSpace` right after an `amdkmdag.sys`
  swap); rerunning the installer restores Adrenalin. Downloads from amd.com need an amd.com Referer; use the
  `-b` combined package.

## Adrenalin profile

Per-game profile baseline (Adrenalin > Gaming > the game):

| Setting | Value | Why |
|---|---|---|
| Radeon Chill | Off | Fights the game's own limiter. |
| Enhanced Sync | Off | Lets frames tear below 60; use the game's vsync. |
| AFMF (Fluid Motion Frames) | Off | See [Display path](#display-path). |
| Radeon Image Sharpening | Off | Stacks on the game's own sharpening and sharpens the UI. |
| Radeon Super Resolution | Off | Upscales UI too; use the game's upscaler. |
| Radeon Boost | Off | Drops resolution on motion. |
| Anti-Lag | Game's Anti-Lag 2 when offered | Driver Anti-Lag only for games without it. |

## Tools

| Tool | Where | Notes |
|---|---|---|
| PresentMon (console) | `presentmon` on PATH (winget `Intel.PresentMon.Console`) | Unelevated, because the user is in Performance Log Users. Wrapped by `scripts/capture-frames.ps1`, which reads the refresh rate from the active display. |
| GPU-Z | `C:\Program Files (x86)\GPU-Z\GPU-Z.exe` (winget `TechPowerUp.GPU-Z`) | Requires admin, so the user starts it. Once it's open, `scripts/read-gpuz.ps1` reads its fields unelevated for the card selected in its dropdown: Bus Interface (`max @ current` link), Resizable BAR, driver, GPU load. |
| HWiNFO64 (free) | `C:\Program Files\HWiNFO64\HWiNFO64.EXE` (winget `REALiX.HWiNFO`) | Requires admin, so the user runs it and clicks Logging start; command-line CSV logging (`-l`) is Pro-only. CPU package power, clocks, temperatures, GPU power. |
| RivaTuner Statistics Server | `C:\Program Files (x86)\RivaTuner Statistics Server` | On-screen overlay and frame cap fallback for games without a limiter. |
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
- `--terminate_on_proc_exit` sometimes leaves the session running after the
  game exits. `presentmon --terminate_existing_session --session_name <name>`
  stops it; exit 7 ("no existing sessions found") means it had already ended
  and the CSV is complete.

### OCuLink link check

Windows can't show the OCuLink link: `DEVPKEY_PciDevice_CurrentLinkSpeed` on the
9070 XT reports Gen5 x16, which is the link to Navi 48's on-package PCIe switch.
GPU-Z's Bus Interface does show the OCuLink link: `PCIe x16 5.0 @ x4 4.0` while the
GPU is active (verified 2026-10-06), dropping to `@ x4 1.1` at idle as power
management slows the link. Have the user open GPU-Z on the 9070 XT and start its
render test (the `?` beside Bus Interface) or a game, then run
`scripts/read-gpuz.ps1 -Samples 15`. Under load, anything other than `@ x4 4.0`
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
  gamepad firmware. Don't flash firmware v3.14 / v1.23: it's listed only for
  the 6800U, 7640U and 7840U models.
- **GPD Tool 1.65** replaces Motion Assistant (TDP up to 40 W, vibration, back
  buttons). Don't run both at once.
- **Charge limit**: on the 2025 the BIOS charge-limit option reportedly changes
  only the LED behaviour, not the charging. Docked on AC all day, watch the
  battery for swelling.
- **Phantom touches** (GXTP7385 touchscreen): disabling the HID-compliant pen
  device is the owner fix.
- **eGPU**: OCuLink isn't hot-pluggable. Connect or disconnect it only with
  the laptop off, and power the eGPU on before the laptop.
- **Don't flash**: BIOS 0.42, the touchpad firmware, or the gamepad firmware
  above; none are for the HX 370.
