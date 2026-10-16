# PowerWash Simulator (Unity URP, DX11)

- **Status:** routed to the Radeon 890M on 2026-10-14 and verified at the
  default 1280x800: a 73-minute session held 60. Native resolution untested.
  Shelved for now; the user wasn't in the mood for it.
- **Steam app id:** 1290000
- **Executable:** `D:\SteamLibrary\steamapps\common\PowerWash Simulator\PowerWashSimulator.exe`
  (GPU preference `GpuPreference=1;`, the 890M)
- **Config:** the graphics options live as JSON (`GAME_SETTINGS` →
  `m_graphicalSettings`) inside the binary, length-prefixed
  `%USERPROFILE%\AppData\LocalLow\FuturLab\PowerWash Simulator\SaveData\Preferences\FuturPlayerPrefs.sav`.
  Change them in the menu rather than by hand: a value whose length changes
  breaks the framing. Unity also keeps `Screenmanager` resolution and
  fullscreen-mode keys under `HKCU\Software\FuturLab\PowerWash Simulator`.
  Steam Cloud syncs `SaveData`, preferences included.
- **Backups:** `SaveData\Preferences\FuturPlayerPrefs.sav.pre-tuning-20261014`,
  `registry.pre-tuning-20261014.reg` (both in the LocalLow folder above).
- **Target:** 2560x1600 at a locked 60 on the internal panel, iGPU only.

## Settings

Defaults found on the first launch, and what to set in the menu:

| Setting | Key | Before | After | Why |
|---|---|---|---|---|
| Resolution | `Resolution` | 1280x800 | 2560x1600 | Native panel resolution. |
| Display mode | `m_fullScreenMode` | 1 (borderless) | Exclusive fullscreen if offered | Borderless ran as a composed copy in other games here, about a frame of added latency. |
| Frame cap / vsync | `MaxFrameRate`, `VSyncCount` | 60 / 1 | 60 / 1 | Already right. |
| Preset | `Preset` | 2 | High | Light game; render scale (`URPCustom_RenderScale`) is the first lever if 60 slips at native. |

## Known issues

Each launch writes a handful of Backtrace reports under `backtrace\`: Rewired's
HID layer failing with "All pipe instances are busy" while another process
holds the controller's HID device. They are logged exceptions, not crashes.

PresentMon warns at startup that, unelevated, it may not resolve the process,
and the capture didn't stop when the game exited. The CSV still recorded: it
reads 0 bytes while PresentMon buffers and fills in once it flushes, so stop
the capture by hand after the game quits.

## Captures

`PowerWashSimulator-session-20261014-142415.csv` (first launch, menus only,
1280x800 borderless): `Composed: Flip`, 10 held (0.16%), all but one CPU-side
and 7 of them in the load at 1:50-2:00. P95 GPU busy 1.9 ms, so native
resolution has ample headroom.

`PowerWashSimulator-session-20261014-191406.csv` (73 min, still at the
1280x800 defaults; paused for much of the last stretch): `Steady`, 417 held
(0.16%), 1% low 55.1, median GPU busy 7.0 ms and P95 7.9 ms. The held frames
cluster in 43:50-45:30 (worst window 15 fps, 354 of them GPU-side); the
busiest CPU was on a Zen 5 core in only 2% of 4,349 logged seconds.

## Next steps

Set the menu values above, then capture a play session at a busy, wide-open
level. At 7 ms GPU busy for 1280x800 in gameplay, native 2560x1600 may land
near the 14 ms limit; render scale is the lever if it does. Ask what was on
screen around 44-45 min if the GPU-side cluster recurs.
