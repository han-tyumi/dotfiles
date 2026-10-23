# Warhammer 40,000: Boltgun (Unreal Engine 4)

- **Status:** applied 2026-10-23 on the Radeon 890M alone (no eGPU attached).
  The first session, at the top tier in every group, nearly held: 0.35% held
  against the 0.25% bar, mostly GPU-limited. Shadows and post-process then went
  to High; that change is uncaptured.
- **Steam app id:** 2005010
- **Executable:** `D:\SteamLibrary\steamapps\common\Boltgun\Boltgun\Binaries\Win64\Boltgun-Win64-Shipping.exe`
  (GPU preference `GpuPreference=1;`, the 890M; the recommended GPU is an
  RX 580, light enough to skip the cross-adapter path).
  `Warhammer 40,000 Boltgun.exe` in the install root is only the launcher stub.
- **Config:** `%LOCALAPPDATA%\Boltgun\Saved\Config\WindowsNoEditor\GameUserSettings.ini`
  (ASCII, CRLF), created at first launch. The game's own section is
  `[/Script/Boltgun.BGGameUserSettings]`: resolution, `FullscreenMode`
  (0 = exclusive), `FrameRateLimit`, `MaterialQuality`, `AnisotropicFiltering`;
  quality is the standard `[ScalabilityGroups]` (0-3). It has no VSync key, yet
  the session presented with sync interval 1. Steam Cloud syncs only
  `Saved\SaveGames`, not the config.
- **Backups:** `GameUserSettings.ini.pre-tuning-20261023` beside it, holding the
  menu settings the first session ran with.
- **Target:** 2560x1600 at a locked 60 on the internal panel, iGPU only. A fast
  shooter, so 60 rather than the 30 cap heavier games get on the 890M.

## Settings

Set in the menu before the first session, then edited by file:

| Setting | Before | After | Why |
|---|---|---|---|
| Resolution, display | — | 2560x1600, exclusive fullscreen | Native panel |
| `FrameRateLimit`, vsync | — | 60, on | The game's own limiter |
| `[ScalabilityGroups]`, `MaterialQuality` | — | 3 (top tier), `sg.ResolutionQuality` 100 | Starting point |
| `AnisotropicFiltering` | — | 16 | Cheap |
| `sg.ShadowQuality` | 3 | 2 | GPU-limited held frames; P95 GPU busy 15.9 ms at 3 |
| `sg.PostProcessQuality` | 3 | 2 | Same; the two groups UE4's top tier costs most in |

## Captures

`Boltgun-Win64-Shipping-session-20261023-104057.csv` (86 min, 60 Hz, exclusive
fullscreen: `Hardware: Independent Flip`, sync interval 1), with
`Boltgun-Win64-Shipping-session-cores-20261023-104057.csv`.

| Settings | Held | 1% low | Median / P95 GPU busy | Steady |
|---|---|---|---|---|
| All groups 3 | 1,083 (0.35%), 933 GPU-limited | 31.9 | 13.5 / 15.9 ms | False |

Unlike Super Fantasy Kingdom's exclusive fullscreen, `GPUBusy` here shows
headroom (median 13.5 ms), so it can be read. The worst windows were
58:20-59:40 (down to 47.9 fps, one 238 ms frame) and 39:30 and 79:00 (53-55
fps). The user saw drops when things loaded in or the screen filled up; the
238 ms frame looks like a streaming or shader-compile hitch, which no setting
fixes. The busiest CPU was a Zen 5 core in 100% of 5,078 s.

## Next steps

- Recapture a session at shadows and post-process 2. Steady with P95 GPU busy
  under ~14 ms means done.
- If held frames stay GPU-limited, set `sg.ResolutionQuality` to 90; the
  pixel-art look hides it well.
- Hitches that stay at the same spots across sessions are loading, not
  settings.
