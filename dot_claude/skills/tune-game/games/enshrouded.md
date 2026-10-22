# Enshrouded (1.0, Vulkan)

- **Status:** verified 2026-10-16 in the starting vault at Ultra with FSR 3
  Quality: `Steady`, 60.0 fps, 1 held frame in 30 s, with the in-game vsync
  off and an RTSS 60 fps cap. A 9-minute session the same day, from the vault
  out through the outdoor tutorial, held 60 apart from two short stretches
  (see Captures). A 3.7-hour session that evening, with a new character and
  world, was `Steady` throughout (0.06% held), and so were a 4.1-hour one
  on 2026-10-18 (0.08% held) and a 9-hour one on 2026-10-19 (0.09% held).
  Big bases and the Shroud past the starting area are untested. The 890M
  profile (see [Per-GPU profiles](#per-gpu-profiles)) holds 40 at 1920x1200
  with the panel at 40 Hz: 0% late frames in most 5-minute windows of a
  2.3-hour session, apart from slowdowns after long pauses (2026-10-20).
- **Steam app id:** 1203620
- **Executable:** `D:\SteamLibrary\steamapps\common\Enshrouded\enshrouded.exe`
  (renders on the 9070 XT: its dedicated memory sits on the 9070 XT's LUID)
- **Config:** `%USERPROFILE%\Saved Games\keen games\Enshrouded\local_settings.json`
  (UTF-8 without BOM, tab-indented). On first launch the game migrates
  `enshrouded_local.json` from the install folder into it and ignores the
  install-folder file from then on, so edits there do nothing. The startup
  block of `enshrouded.log` in the install folder ("[g38_options] machine
  settings:") prints the values the game actually loaded, and later lines log
  each menu change. Steam Cloud syncs `userdata\<id>\1203620\remote\`
  (`user_settings.json` and the `.ksd` saves), not this file.
- **Backups:** `local_settings.json.pre-tuning-20261016` beside it (the
  game's Ultra defaults). The install folder's `enshrouded_local.json` was
  written during tuning and is unused.
- **Frame cap:** `C:\Program Files (x86)\RivaTuner Statistics Server\Profiles\enshrouded.exe.cfg`
  (`[Framerate]` `Limit=60`, or 40 on the 890M). The game has no frame limiter.
- **Target:** a locked 60 on the internal panel.

## Settings

| Setting | Key | Before | After | Why |
|---|---|---|---|---|
| Vsync | `graphics.vsync` | true | false | On this eGPU path the game's vsync made the CPU and GPU take turns: 37 fps with the GPU idle half of each frame, at any quality. Off, the same spot ran 149 fps uncapped. `Composed: Flip` still shows frames without tearing. |
| Frame cap | RTSS `Limit` | none | 60 | Replaces vsync as the cap. Radeon Chill at 60/60 held 11 frames in 30 s at High; RTSS held 1 at Ultra. |
| Upscaler | `antiAliasing`, `fsr3` | Fsr3, Quality | Fsr3, Quality | Unchanged. FSR 3 is the best upscaler the game offers. |
| Render preset | `preset` | Custom | Custom | Every quality key is set by hand. |

The game's Ultra defaults stayed: `shadows`, `dynamicGi`, `reflections`,
`water`, `fog` and `pointLightShadows` at Ultra, `textureAnisotropy` Ultra,
`models` Quality, and the Disabled/Low/Medium/High keys at High. Native output
(`forceFullscreenResolution` 0,0), `renderScale` 1, `automaticRenderScale`
false, HDR off.

## Game-specific notes

- Menu labels differ from the stored values: `High` shows as "Quality" and
  `Ultra` as "Ultra Quality".
- An invalid value logs "Failed to parse enum … Invalid value" and falls back
  to the default. The valid values, from the exe's reflection tables:
  - `preset`: Lowest, Low, Medium, High, Ultra, Custom
  - `antiAliasing`: None, FXAA, Fsr2, Fsr3, Dlss, Dlaa, Xess
  - `fsr3`: UltraPerformance, Performance, Balance, Quality, Native
  - `fsr2`: Performance, Balance, Quality, UltraQuality
  - `xess`: Auto, Native, UltraQualityPlus, UltraQuality, Quality, Balanced,
    Performance, UltraPerformance
  - `shadows`, `fog`: Low, Medium, High, Ultra
  - `dynamicGi`, `reflections`, `water`: Performance, Balance, High, Ultra
  - `pointLightShadows`: Lowest, Low, Medium, High, Ultra
  - `textureAnisotropy`: Off, Low, Medium, High, Ultra
  - `ssao`, `distantObjects`, `decoObjects`, `detailScattering`,
    `tessellation`: Disabled, Low, Medium, High
  - `contactShadows`: Disabled, Enabled
  - `voxelMeshQuality`: Low, High
  - `models`: Performance, Balance, Quality
- `RenderSettingsGpuTargetFps` (Target30Fps, Target60Fps) is the automatic
  render scale's target, not a frame limiter.
- The Adrenalin overlay (Alt+R) and Ctrl+Shift+O do nothing in this game.

## Captures

- **session (Ultra, vsync on, 24 min):** menus held 60 with GPU busy about
  9 ms. In the world, about 35 fps, GPU busy median 15.5 ms, P95 36 ms. The
  busiest CPU was on Zen 5 in 48% of 1,432 s.
- **vault-high (High, vsync on, 45 s):** 36.7 fps, 50% held, 1% low 19. GPU
  busy median 15.2 ms. Dropping six settings a tier saved 0.3 ms.
- **vault-fsrperf (High, FSR 3 Performance, vsync on, 30 s):** 37.1 fps, GPU
  busy 14.0 ms, CPU busy 31.7 ms. GPU-Z showed a 58 °C hot spot, 0-8%
  memory controller load and 40-130 W board power with GPU load flipping
  between 0% and 100%: a stall, not load.
  The busiest game thread used about 40% of a core.
- **vault-novsync (High, FSR 3 Performance, vsync off, 30 s):** 148.8 fps,
  1% low 106, GPU busy median 5.6 / P95 12.1 ms.
- **vault-chill (High, FSR 3 Quality, Chill 60/60, 30 s):** 59.8 fps, 11 held
  (0.62%), 1% low 55.5.
- **vault-ultra-rtss (Ultra, FSR 3 Quality, RTSS 60, 30 s):** `Steady`,
  60.0 fps, 1 held (0.06%), 1% low 55, GPU busy median 15.3 / P95 15.9 ms.
  Capped GPU busy here reads high because the card drops its clocks to the
  load; the uncapped headroom at Ultra is unmeasured.
- **session-ultra (Ultra, FSR 3 Quality, RTSS 60, 9 min):** 60.0 fps, held
  0.59% (199), 1% low 55.7, GPU busy median 15.3 / P95 15.9 ms. 167 of the
  held frames fell in two stretches: 1:10-1:50, which lines up with a
  `chezmoi apply` and GPU-Z reads run during play, and 8:20-8:30, near the
  exit. The rest of the session held about 0.1%. GPU-Z at the cap read
  105-115 W at 1.9-2.0 GHz, so the card has headroom.

Adrenalin's global Texture Filtering Quality went from Standard to High before
the next two sessions.

- **session (Ultra, FSR 3 Quality, RTSS 60, 6 min):** mostly character
  creation and the first world load, ending in an accidental quit. 61.3 fps,
  held 0.44% (88; 82 CPU-limited), 1% low 56.3, GPU busy median 9.7 /
  P95 15.6 ms. 64 of the held frames fell in 20 s about two minutes in, plus
  load hitches of 425 ms at startup and 703 ms later. The busiest CPU was on
  Zen 5 in 65% of 332 s.
- **session2 (same settings, 225 min):** `Steady`, 60.1 fps, held 0.06%
  (457; 351 GPU-limited), 1% low 55.6, 0.1% low 53.8, GPU busy median 15.3 /
  P95 16.0 ms (clocks down at the cap, as above). The worst stretch was
  65:30-65:50 with 164 held frames but no frame over 18.5 ms; what was on
  screen is unrecorded. The busiest CPU was on Zen 5 in 98% of 13,359 s.
- **session3 (same settings, 249 min, 2026-10-18):** `Steady`, 60.1 fps,
  held 0.08% (691; 563 GPU-limited), 1% low 53.3, 0.1% low 38, GPU busy
  median 15.2 / P95 16.0 ms. 1,310 frame-time spikes against session2's 17,
  most of them single frames. The worst stretch was 228:30-228:50, a 269 ms
  stall at 10 fps for a few seconds, likely a load (fast travel or a new
  area); the user noticed no hitches. The busiest CPU was on Zen 5 in 94% of
  14,757 s.
- **session4 (same settings, 537 min, 2026-10-19):** `Steady`, 60.1 fps,
  held 0.09% (1,820; 1,487 GPU-limited), 1% low 51.5, 0.1% low 36.3, GPU busy
  median 15.3 / P95 16.2 ms, 4,074 frame-time spikes, P99 animation error
  5.9 ms. The worst stretches were 61:00-65:00 (four windows of 9-13 held,
  worst frame 37.6 ms) and 279:00-284:00 (worst 38.0 ms). The busiest CPU was
  on Zen 5 in 91% of 31,900 s; the capture stopped on its own when the game
  exited.

## Per-GPU profiles

The game is in `~/.config/gpu-profiles/gpu-profiles.json` (see
[machine.md](../machine.md#per-gpu-profiles)), so its settings file and RTSS
cap follow the GPU present at logon:

- **rx-9070-xt:** the settings above, RTSS 60, native output pinned
  (`forceFullscreenResolution` 0,0) so a reseed never inherits the 890M's.
- **890m:** RTSS 40 with the panel at 40 Hz (the switcher sets each GPU's
  `panelHz`: 40 on the 890M, 60 on the eGPU), RTSS scanline sync off, vsync
  off, 1920x1200 output (`forceFullscreenResolution`
  1920,1200), FSR 3 Performance (960x600 internal), `shadows`, `fog`, `ssao`, `distantObjects`, `decoObjects`,
  `detailScattering`, `voxelMeshQuality` and `pointLightShadows` Low,
  `dynamicGi`, `reflections`, `water` and `models` Performance,
  `contactShadows` and `tessellation` Disabled, `textureAnisotropy` Medium.
  No 890M benchmark exists; a 780M runs under 30 fps at 720p and a Steam Deck
  about 30 at 800p on Lowest, so this is a starting point. Capture a session
  on it and tune from there; on battery the TDP drops, so test on AC first.
- **890m-session (2026-10-19, AC, 108 min, mostly paused at the base):** two
  phases. From 5 to 70 min, about 17 fps: median frame 33.5 ms (on the cap)
  but about 30% of frames over 40 ms, P95 frame and GPU busy both about 120 ms,
  so GPU-limited. From 70 to 110 min, a locked 30 with GPU busy median 25 /
  P95 27 ms, about 20% headroom. The laptop sat flat on a bed for the first
  hour and was moved around 70 min: the share of frames over 40 ms climbed
  steadily from 12% to 33% and then fell to 0, which fits thermal throttling
  with the intakes blocked. The user also saw fps sink the longer the game
  sat paused, and about 15 fps in the main menu on the first launch (likely
  first-run shader builds). The busiest CPU was on Zen 5 in 88%
  of 6,184 s. Analyze with `-RefreshHz 60`; held counts there count every
  30 fps frame, so read frame times instead.
- **890m-session2 (2026-10-20, AC, 42 min, hard surface):** no throttling;
  the ~120 ms frames did not return. Two 60 s spot captures at the base:
  - **30 W:** GPU busy median 28.0 / P95 32.1 ms, 3.6% of frames late
    (P99 displayed 50 ms).
  - **35 W:** GPU busy median 28.3 / P95 31.0 ms, 0.2% late, P99 displayed
    34 ms, `Steady` at `-RefreshHz 30`.

  Over the whole session, still 1.8–4.1% of frames per 5-minute window were
  shown for 50 ms (three 60 Hz refreshes) instead of 33, both before and after
  the switch to 35 W, mostly GPU-limited. FSR Balanced won't fit: P95 31 ms
  leaves no room under 33.3. The busiest CPU was on Zen 5 in 92% of 2,399 s.
  The session capture reported GPU busy 33.3 ms at the median in every window,
  while the spot capture recording the same minute alongside it read 28.3 ms
  with identical displayed times. Trust a spot capture's GPU busy over a
  long session's.
- **890m-session3 (2026-10-20, AC, 35 W, 171 min, questing):** a series of
  60 s spot captures, all at 1920x1200, each one change from the last:

  | Setup | Late | 1% low | GPU busy med / P95 |
  |---|---|---|---|
  | 30 cap, FSR 3 Quality | 2.2% | 28.3 | 26.1 / 28.1 ms |
  | + in-game vsync (at the base) | 7.0% | 18.8 | 24.5 / 30.1 ms |
  | scanline sync x/2 instead of vsync | 3.6% | 29.4 | 25.9 / 29.4 ms |
  | + FSR 3 Balance | 0.9% | 29.7 | 23.1 / 24.9 ms |
  | + FSR 3 Performance | 0.3% | 29.7 | 21.5 / 22.9 ms |
  | 40 Hz panel, RTSS 40, scanline sync off | 0.08%, `Steady` | 38.2 | 18.5 / 20.3 ms |

  - At a 30 cap on the 60 Hz panel, the late frames took a normal 32–34 ms
    to make. Each frame occupied about 30.5 ms of GPU time (busy plus gaps)
    of the 33.3 available, so when a frame finished drifted across a 60 Hz
    refresh, showing one frame for 50 ms and the next for 17. More GPU headroom
    fixed it; the cap and vsync did not.
  - On the iGPU the game's vsync with the RTSS 30 cap alternated 17 and 50 ms
    frames, worse than vsync off.
  - RTSS scanline sync x/2 (`SyncScanline0=800`, `SyncPeriods=1`) tightened
    frame times (P99 34.1 ms) but kept the late frames; it may need exclusive
    fullscreen, and the game presents `Composed: Flip`.
  - GPU busy fell at 40 fps compared with 30: at a 30 cap the 890M clocks
    itself down, so capped GPU busy overstates a frame's cost.
  - The user felt no difference among the 30 fps setups and found 40
    smoother.

  At 40 the session held 0–0.1% late in most 5-minute windows (P99 frame
  26.5–27.4 ms, GPU busy P95 about 22 ms). Two stretches fell apart, about
  23:02–23:15 and 23:56–23:57, plus 21:38–21:47 in the 30 fps part. Each came
  right after the user left the game paused for a while: the core log shows
  the pause at 23:53–23:55 (Zen 5 load 4%, still 40 fps at 18 ms GPU busy),
  and the drop begins on resume. During a stretch the median GPU busy stays
  about 20 ms, but a third of frames take 70–76 ms, so the frame rate sits
  near 23. It cleared by itself after 2–13 minutes. The busiest CPU was on
  Zen 5 in 81% of 3,943 s.

- **890m-session4** (2026-10-21, 65 min at 40 fps, 40 Hz, no long pause):
  `Steady`, 0.07% held, 1% low 36.8 fps, GPU busy median 20.2 ms and P95
  23.0 ms. The one blip was 21:39:40-21:40:00 (77 late frames, GPU busy P95
  31.5 ms). The busiest CPU was on Zen 5 in 97% of 3,822 s. The post-pause
  slowdown did not come up, since the game was never left paused.

## Next steps

On the 890M, find what makes a third of frames take about 75 ms of GPU time
after a long pause. When it next happens, read the game's dedicated and
shared GPU memory (a demoted allocation paging back in would look like this),
then try opening and closing the map, or reloading the save, to see whether
either clears it sooner.

Capture a later session at a large base with many lights or deep in the Shroud,
both heavier than what session2 covered.

- **If 60 slips GPU-side:** measure Ultra uncapped first. RTSS reads a
  profile when the game starts, so set `Limit=0` before launch, capture 30 s,
  and restore `Limit=60`. Then step `dynamicGi` and `shadows` to High, then
  FSR 3 Balance.
- **If 60 slips CPU-side:** check core placement with `watch-cores.ps1`,
  then `distantObjects` and `decoObjects`.
