# Super Fantasy Kingdom (Unity 2021.3, D3D11)

- **Status:** applied 2026-10-22 on the Radeon 890M alone (no eGPU attached).
  Not steady: a 79-minute session held 60 for its first 30 minutes, then held
  frames climbed to about 6%. Shelved 2026-10-23 until the game leaves Early
  Access; recapture then, since the full release may change its performance.
  The next steps below are untried.
- **Steam app id:** 2289750
- **Executable:** `D:\SteamLibrary\steamapps\common\Super Fantasy Kingdom\Super Fantasy Kingdom.exe`
  (GPU preference `GpuPreference=1;`, the 890M; the minimum spec is a GeForce
  8600 GT, too light to be worth the cross-adapter path)
- **Config:** Unity PlayerPrefs in `HKCU\Software\Super Fantasy Games\Super Fantasy Kingdom`.
  It holds only the display keys (2560x1600, `Fullscreen mode` 0 = exclusive,
  60 Hz) and input rebinds; graphics options, if any, haven't been mapped.
  `%USERPROFILE%\AppData\LocalLow\Super Fantasy Games\Super Fantasy Kingdom`
  holds `Player.log` and a `steam_autocloud.vdf`, so Steam Auto-Cloud syncs
  that folder.
- **Backups:** `registry.pre-tuning-20261022.reg` in the LocalLow folder.
- **Target:** 2560x1600 at a locked 60 on the internal panel, iGPU only. The
  890m profile sets the panel to 40 Hz at logon; this game needs it at 60.

## Captures

`Super Fantasy Kingdom-session-20261022-203809.csv` (79 min, 60 Hz, exclusive
fullscreen: `Hardware: Legacy Flip`, sync interval 1), with
`Super Fantasy Kingdom-session-cores-20261022-203810.csv`.

| Span | Held | 1% low | Steady |
|---|---|---|---|
| Whole session | 6,486 (2.35%) | 29.4 | False |
| 0:30-30:00 | 15 | — | True |
| 30-45 min | 720 | — | False |
| 45-79 min | about 5,750 (4-6% per 5 min) | — | False |

The held frames rise with play time, not in bursts. `GpuBusy` sits at the
refresh interval (P05 16.1 ms, median 16.7 ms) in every 5-minute bucket, the
clean first half included, so in exclusive fullscreen it counts the vsync wait
and can't show headroom. That is also why the analyzer files every held frame
under `HeldGpuLimited`. The busiest thread ran at about 91% of a core
throughout, likewise a wait spin rather than load. The busiest CPU was a Zen 5
core in 99% of 4,648 s. The worst windows (78:40-79:00) are the quit.

Driver at capture: 32.0.32015.7029 (machine-state expects .2008; Windows Update
likely replaced it). Motion Assistant's scheduler DC values were 0.

## Next steps

- Ask what changed around 30 minutes in (a later day or wave, a bigger kingdom).
- Map the options menu (vsync, frame limit, quality, render scale).
- In a late-game save, capture 30 s with vsync off to get the real frame cost,
  then decide between lower quality, borderless with an RTSS 60 cap, or 40 Hz.
