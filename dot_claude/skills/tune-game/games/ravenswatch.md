# Ravenswatch (DX12, OEngine)

- **Status:** verified 2026-10-13 on the Radeon 890M alone (no eGPU attached):
  a 31-minute session held 60 in gameplay. Shelved; the user didn't take to the
  game.
- **Steam app id:** 2071280
- **Executable:** `D:\SteamLibrary\steamapps\common\Ravenswatch\Ravenswatch.exe`
  (GPU preference `GpuPreference=1;`, the 890M)
- **Config:** graphics options are menu-only. `_Save\GameSettings.ini` in the
  install folder holds only EULA and news flags; the options persist in the
  binary `_Save\Profile_1.ob` with the save data. Steam Cloud syncs `_Save`.
  `DarkTalesResources\EngineSettings.ini` holds `[Render]` `RunIfNoFocus` and
  `FpsIfNoFocus`.
- **Backups:** `_Save\GameSettings.ini.pre-tuning-20261013`,
  `_Save\Profile_1.ob.pre-tuning-20261013`.
- **Target:** 2560x1600 at a locked 60 on the internal panel, iGPU only.

## Menu settings

The menu offers display mode, monitor, refresh rate, render resolution, render
scale, vsync (with an interval), a quality preset, and texture, environment,
shadow, and physics/animation quality. There is no upscaler and no frame
limiter apart from vsync.

| Setting | Value | Why |
|---|---|---|
| Display mode | Fullscreen | Steadiest pacing. |
| Render resolution / scale | 2560x1600 / 100% | Native; render scale is the first lever if 60 slips. |
| VSync | On, interval 1 | The only 60 cap the game has. |
| Quality preset | High, textures Ultra | Textures are free with 8 GB of UMA in a 3 GB game. |

Known issue: DX12 device-removed crashes (0x887a0005), for which the developer
advises dropping quality from High to Medium. None occurred.

## Captures

`Ravenswatch-session-20261013-212147.csv` (31 min, 60 Hz). Motion Assistant was
not running (board-default TDP) and the scheduler overrides were 0, 0, 0; the
busiest CPU was never a Zen 5 core.

| Span | Held | 1% low | P95 GPU busy | Steady |
|---|---|---|---|---|
| Whole session | 280 (0.25%) | 56.5 | 11.1 ms | False |
| Gameplay (1:38-31:24) | 6 (0.01%) | 56.7 | — | True |

Every held frame was CPU-side. The whole-session misses sit in the first
1.5 minutes (startup and menus, worst 732 ms) and the quit at 31:40.

## Next steps

None needed for 60. With power fixed (Motion Assistant at 30 W, scheduler
defaults restored), there is GPU headroom to try Ultra environment and shadows.
