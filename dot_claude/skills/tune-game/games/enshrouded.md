# Enshrouded (1.0, Vulkan)

- **Status:** verified 2026-10-16 in the starting vault at Ultra with FSR 3
  Quality: `Steady`, 60.0 fps, 1 held frame in 30 s, with the in-game vsync
  off and an RTSS 60 fps cap. A 9-minute session the same day, from the vault
  out through the outdoor tutorial, held 60 apart from two short stretches
  (see Captures). A 3.7-hour session that evening, with a new character and
  world, was `Steady` throughout (0.06% held). Big bases and the Shroud past
  the starting area are untested.
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
  (`[Framerate]` `Limit=60`). The game has no frame limiter.
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

## Next steps

Capture a later session at a large base with many lights or deep in the Shroud,
both heavier than what session2 covered.

- **If 60 slips GPU-side:** measure Ultra uncapped first. RTSS reads a
  profile when the game starts, so set `Limit=0` before launch, capture 30 s,
  and restore `Limit=60`. Then step `dynamicGi` and `shadows` to High, then
  FSR 3 Balance.
- **If 60 slips CPU-side:** check core placement with `watch-cores.ps1`,
  then `distantObjects` and `decoObjects`.
