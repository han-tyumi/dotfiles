# The Witcher 3: Wild Hunt (next-gen, DX12)

- **Status:** settings applied 2026-10-05; not yet verified with a capture.
- **Steam app id:** 292030
- **Executable:** `D:\SteamLibrary\steamapps\common\The Witcher 3\bin\x64_dx12\witcher3.exe`
  (GPU preference already `GpuPreference=2;`)
- **Config:** `Documents\The Witcher 3\dx12user.settings`
  (backup `dx12user.settings.pre-tuning-20261005`). Steam Cloud syncs the
  neighboring `user.settings` but not this file. `%APPDATA%\The Witcher 3` holds
  only launcher state.
- **Target:** 2560x1600 output at a locked 60 on the internal panel.

## Applied settings

| Section / key | Before → after | Why |
|---|---|---|
| `[Rendering/RT]` RTGIPreset | true → false (Quality → Performance) | RTGI Quality is the biggest RT cost. |
| `[Rendering/RT]` RTAOEnabled | true → false | GTAO High (next row) covers most of it far cheaper. |
| `[PostProcess]` GTAOQuality | added, 2 (High) | Screen-space AO in place of RTAO; the menu option is greyed out while RTAO is on. |
| `[Rendering/RT]` Shadows | 2 → 1 | RT shadows kept at Performance. They refine the sun and moon shadow maps rather than replace them (NVIDIA), so the cascade cuts below still apply. |
| `[PostProcess]` FSR2Quality | 0 → 2 (Auto → Quality) | Fixed internal resolution; Auto swings with load. |
| `[Rendering/DRS]` Enable | true → false | DRS can't help a CPU-bound frame and softens the image. |
| `[Viewport]` AMDAntiLag | 0 → 1 | Anti-Lag 2: lower latency at a vsynced 60. |
| `[Gameplay/EntityPool]` SpawnedLimit | 160 → 130 (Ultra+ → High) | Crowd count is the main CPU cost in Novigrad. |
| `[Rendering]` GrassDensity | 6000 → 3500 | CPU/GPU cost with little visual return past this. |
| `[Rendering]` MeshLODDistanceScale | 1.5 → 1.3 | Fewer draw calls. |
| `[Rendering]` TextureMipBias | -2 → -1 | Ultra+ → Uber textures; Ultra+ shimmers under FSR. |
| `[Rendering]` CascadeShadowmapSize | 4096 → 3072 | Shadows Ultra+ → Uber. |
| `[Rendering]` CascadeShadowDistanceScale0/1 | 1.8/1.5 → 1/1 | Cascade draw calls are CPU-bound. The Shadow Quality menu is greyed out while RT shadows are on, so these keys are set only here. |
| `[Rendering/SpeedTree]` GrassDistanceScale | 2.5 → 2 | Foliage visibility Ultra+ → High, two tiers: foliage draw distance costs CPU and GPU in Crookback Bog and Velen. Uber is 2.5 / 1.8 / 48 / 8388608 / 24 for these five keys. |
| `[Rendering/SpeedTree]` FoliageDistanceScale | 1.8 → 1.5 | Same. |
| `[Rendering/SpeedTree]` FoliageShadowDistanceScale | 54 → 16 | Same. |
| `[Rendering/SpeedTree]` GrassRingSize | 8388608 → 6291456 | Same. |
| `[Foliage]` MaxVisibilityDepth | 24 → 12 | Same. |
| `[LevelOfDetail]` DecalsHideDistance | 90 → 80 | Detail level Ultra+ → Uber. |
| `[Streaming/Textures]` CinematicModeMipBias | added, 1 | Matches the Uber texture preset. |

Unchanged on purpose: `[Viewport]` VSync=true, `[Engine]` LimitFPS=60,
`[Rendering]` HairWorksLevel=0, `[Visuals]` HdrEnabled=false (the panel is SDR),
`[Rendering/TAA]` EnableCAS=true with `[PostProcess]` SharpenAmount=0. Frame
generation and path tracing stay off.

## Game-specific notes

- FSR2Quality enum: 0 Auto, 1 Native AA, 2 Quality, 3 Balanced, 4 Performance,
  5 Ultra Performance. Native AA (1) is reported broken with FSR 4.
- SpawnedLimit menu values: Low 75, Medium 100, High 130, Ultra 150, Ultra+ 160.
- Clicking a graphics preset in the menu overwrites every key above; recheck the
  file after the first launch, since the game sometimes resets settings.
- Busy test spots: Novigrad's Hierarch Square (crowds, CPU), Crookback Bog
  (foliage, RT), Beauclair (draw distance).

## Next steps if 60 isn't steady

1. CPU-bound drops (Novigrad): SpawnedLimit 130 → 100. If that isn't enough,
   turn ray tracing off entirely (`[Rendering/RT]` EnableRT=false): this port's
   RT adds heavy CPU-side cost in dense areas, so it is the largest CPU lever
   left.
2. GPU-bound drops (Crookback Bog, Toussaint): FSR2Quality 2 → 3 (Balanced),
   then RT reflections off (`[Rendering/RT]` EnableRtRadiance=false) or RT
   shadows 1 → 0. RTGI has no off switch of its own; it goes only with
   EnableRT=false.
3. If neither holds 60, tune for the panel's 40 Hz mode instead (SKILL.md step
   8). The menu's limits are 30/60/75/90/120/144 with no 40, so set
   LimitFPS=0 and let VSync cap at 40, or try LimitFPS=40 in the file and check
   with a capture that it holds.
