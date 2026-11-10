# World of Warcraft: Forever (DX12)

- **Status:** verified 2026-11-10 on the Radeon 890M alone (no eGPU), at 40 Hz:
  a 10-minute questing capture after tuning was `Steady`.
- **Launcher:** Battle.net, product id `wowf` (see `~/.config/windows/games.json`).
- **Executable:** `D:\World of Warcraft\_forever_\Wow.exe`
- **Config:** `D:\World of Warcraft\_forever_\WTF\Config.wtf`. The settings below
  were changed in the in-game menu with the game running, so no file backup was
  taken; **Defaults** in the Graphics menu restores the game's own values.
- **Panel:** `wow-forever` in `gpu-profiles.json` sets 40 Hz on the 890M while
  `Wow.exe` runs. The game's vsync then caps at 40.
- **Target:** 40 fps at 40 Hz, iGPU only. 60 wasn't attempted: the untuned
  session missed 40 often.

## Menu settings

Changed from the game's detected defaults (Base Game Quality 5). The Raid and
Battleground tab was left alone.

| Setting | Before | After | Why |
|---|---|---|---|
| Render Scale | 100% | 78% (2005x1253, FSR 1.0) | Largest GPU saving; the first lever back up. |
| Shadow Quality | Good | Fair | GPU and draw-call cost. |
| Particle Density | Good | Fair | Spell effects in groups. |
| SSAO | Good | Low | GPU. |
| Depth Effects | Good | Low | GPU. |
| Compute Effects | Good | Fair | Volumetric fog; costly on iGPUs. |
| Secondary Lighting | Good | Fair | Lowest offered. |
| View Distance | 5 | 4 | CPU; most held frames were CPU-side. |
| Ground Clutter | 5 | 4 | CPU. |

Unchanged: Fullscreen (Windowed) 2560x1600, Vsync on, triple buffering, CMAA 2,
Texture Resolution High, 16x anisotropic, DirectX 12, Max Foreground FPS off.
Environment Detail stayed at 5: its left arrow didn't respond to clicks.

## Captures

| Capture | Held | 1% low | P95 GPU busy | P95 CPU busy | Steady |
|---|---|---|---|---|---|
| `Wow-wowf-session-20261110-121704.csv`, before (77 min, mostly the character creator) | 13.8% | 16 | 27.5 ms | 34.6 ms | False |
| `Wow-wowf-tuned-walk-20261110-152820.csv`, after (10 min questing in the starting area) | 3 (0.01%) | 38.8 | 15.2 ms | 19.6 ms | True |

During the after capture, the busiest CPU was a Zen 5 core in every second
(`Wow-wowf-tuned-walk-cores-20261110-152820.csv`, 643 s).

The before capture's 2-hour background task was killed at its time limit and
left its ETW session running, which blocked the next capture (see the
PresentMon notes in [machine.md](../machine.md)).

## Next steps

- Capture a busy town and a dungeon pull. If both hold, spend the ~6 ms of GPU
  headroom on Render Scale first (85-90%), then Shadow Quality.
- If CPU-side holds appear in crowds, drop View Distance and Particle Density
  before touching GPU settings.
