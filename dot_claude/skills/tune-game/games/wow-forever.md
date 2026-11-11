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
| Render Scale | 100% | 86% (2218x1386, FSR 1.0) | 78% first; raised once 40 held with GPU to spare. |
| Shadow Quality | Good | Good | Fair at first; raised back once 86% showed ~13 ms GPU busy uncapped. |
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
| `Wow-wowf-tuned-walk-20261110-152820.csv`, 78% (10 min questing in the starting area) | 3 (0.01%) | 38.8 | 15.2 ms | 19.6 ms | True |
| `Wow-wowf-uncapped-play-20261110-184448.csv`, 78%, vsync off (45 s in a village) | — | 60.8 (73 fps average) | 14.4 ms | 15.6 ms | — |
| `Wow-wowf-rs86-20261110-185004.csv`, 86% (88 s; the user quit early) | 1 (0.03%) | 38.8 | 15.8 ms | 9.8 ms | True |
| `Wow-wowf-rs86-session-20261110-201736.csv`, 86% (29 min of play) | 41 (0.06%) | 38.6 | 25.9 ms* | 13.3 ms | True |

\* GPU busy read exactly 25.0 ms (one refresh) in every sixth of the session,
so it measured the vsync interval rather than GPU load and gives no headroom
reading. 32 of the 41 held frames fell in the first 20 s (loading into the
world); the rest were single hitches.

`Wow-wowf-rs86-uncapped-20261110-212322.csv` (86%, vsync off, standing with the
Options menu open): about 78 fps with 12.8 ms GPU busy while focused. It dropped
to exactly 30 fps whenever the window lost focus, the game's background cap.
With Shadow Quality Good and the menu still open, a 5 s capped probe read 14.5 ms
GPU busy.

`Wow-wowf-rs86-session2-20261110-211956.csv` (86%, Shadow Quality Good, 61 min):
the whole-file verdict is `Steady: False` (0.91% held, 1% low 29.8), but nearly
all of that came from 10 windows locked at 30 fps while the game was unfocused
and from the vsync-off test. Focused play after 7:00 (326 windows) had 0.08% of
frames over 37.5 ms, and no 10 s window fell below 39.3 fps. Busiest CPU on
Zen 5 in 95% of 3615 s (`Wow-wowf-rs86-session2-cores-20261110-211956.csv`).

60 was tested and declined on 2026-11-10: uncapped at 78% the 1% low was only
60.8 with GPU and CPU both within 2 ms of the 16.7 ms budget, so towns and
groups would miss on a panel without VRR. The user chose a sharper image at 40.

During the after capture, the busiest CPU was a Zen 5 core in every second
(`Wow-wowf-tuned-walk-cores-20261110-152820.csv`, 643 s).

The before capture's 2-hour background task was killed at its time limit and
left its ETW session running, which blocked the next capture (see the
PresentMon notes in [machine.md](../machine.md)).

## Next steps

- Shadow Quality Good held for an hour of questing. Still untested: a busy
  town and a dungeon pull.
- Unfocused stretches lock at 30 fps (the game's background cap) and count as
  held frames; split them out before judging a session.
- Capped captures here can pin GPU busy at one refresh; measure headroom with
  vsync off and the game window focused.
- Apply often needs a second click before a change takes effect; confirm with a
  5 s capture (40 fps capped, well above it uncapped).
- The Render Scale slider's arrows miss about half the clicks through Orca;
  read the percentage after each batch.
- If CPU-side holds appear in crowds, drop View Distance and Particle Density
  before touching GPU settings.
