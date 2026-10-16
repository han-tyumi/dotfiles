# Hardspace: Shipbreaker (Unity HDRP, DX11)

- **Status:** routed to the Radeon 890M on 2026-10-14. The first session ran
  at the 2560x1600 Ultra defaults and averaged 52 fps on paper but displayed
  about 30, GPU-bound throughout. Retuned the same night to 1920x1200 High with
  vsync; untested.
- **Steam app id:** 1161580
- **Executable:** `D:\SteamLibrary\steamapps\common\Hardspace Shipbreaker\Shipbreaker.exe`
  (GPU preference `GpuPreference=1;`, the 890M)
- **Config:** `%USERPROFILE%\AppData\LocalLow\Blackbird Interactive\Hardspace_ Shipbreaker\user_config.ini`,
  a commented ini (UTF-8 without BOM, CRLF). Settings are in its `[Video]`
  section. Steam Cloud syncs only `Saves\`, not the ini.
- **Backups:** `user_config.ini.pre-tuning-20261014` beside it.
- **Target:** a locked 60 on the internal panel, iGPU only.

## Settings

| Setting | Key | Before | After | Why |
|---|---|---|---|---|
| Resolution | `Width`, `Height` | 2560x1600 | 1920x1200 | GPU busy was a median 21.3 ms at native (P95 28.6), twice the 60 fps budget. This resolution has 56% of native's pixels. The game has no upscaler; `mRenderScaleFactor` exists in `BBI.Unity.Game.dll` but nothing exposes it. |
| Quality | `Graphics profile level` | 3 (`PC_Ultra`) | 2 (`PC_High`) | Levels 0-3 are `PC_Low`, `PC_Medium`, `PC_High` and `PC_Ultra`. HDRP's Ultra tier is the next GPU cost after resolution. |
| Vsync | `VSyncMode` | 0 | 1 | The game has no frame limiter, so vsync is the 60 cap. Without it, frames tore and paced unevenly. |
| Display mode | `FullScreenMode` | `FullScreenWindow` | `ExclusiveFullScreen` | Borderless ran as `Composed: Flip`, a DWM copy that costs GPU time and adds a frame of latency. |
| Refresh rate | `RefreshRate` | 0 | 60 | Pins the exclusive mode to the panel's 60 Hz. |

Unchanged: `AntiAliasingEnabled=False`, `DynamicLightRangeLevel=1` (Low),
`DynamicLightShadowsEnabled=False`, `TextureQualityLevel=0` (full). The game
already started on the cheap end of its dynamic lighting.

## Captures

`Shipbreaker-session-20261014-210239.csv` (69 min, 2560x1600 Ultra, borderless,
vsync off): `Composed: Flip`, 52.4 fps average but 58,286 held frames (31%),
1% low 31.9. GPU-limited: 58,183 of the held frames were GPU-side. Median GPU
busy was 21.3 ms and P95 28.6 ms. The worst windows (24:50-26:50, about 34 fps)
were the ship interiors that players report as the heaviest scenes. The user
saw about 30 fps on screen. The busiest CPU was on a Zen 5 core in 92% of
4,065 logged seconds, so scheduling was fine.

## Next steps

Capture a session inside a ship at the new settings. The pass condition is
`Steady` with P95 GPU busy under about 14 ms.

- **If 60 still slips:** go to 1600x1000, then quality 1 (`PC_Medium`).
- **If there's headroom:** raise `DynamicLightRangeLevel` before
  resolution.
- **Fallback to 40 Hz:** if the user prefers native sharpness over 60, set
  the panel to 40 Hz and run 2560x1600 High with vsync on. The target at 40 is
  P95 GPU busy under about 21 ms.
- **If exclusive fullscreen misbehaves** (alt-tab or a resolution switch
  failing on the iGPU), go back to `FullScreenWindow`.
