# The Witcher 3: Wild Hunt (Remastered 5.00, DX12)

- **Status:** gameplay holds 60 apart from brief riding dips. The bar
  cutscene that stuttered in session10 replayed clean in session11, with the
  main thread on the Zen 5 cores. Next: restore the scheduler policy (see
  [machine.md](../machine.md#scheduler-policy)), then redo the Anti-Lag 2 A/B.
- **Version:** hotfix 5.00c (exe FileVersion 5.0.0.1044392, Steam build
  25646871, 2026-10-01). Patch notes through 5.00c mention no CPU or cutscene
  performance work.
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
| `[Rendering/RT]` EnableRtRadiance | true → false | RT reflections cost 6.5-7 ms GPU (uncapped A/B); SSR stays on. |
| `[Rendering/RT]` RTAOEnabled | true → false | GTAO High (next row) covers most of it far cheaper. |
| `[PostProcess]` GTAOQuality | added, 2 (High) | Screen-space AO in place of RTAO; the menu option is greyed out while RTAO is on. |
| `[Rendering/RT]` Shadows | 2 → 1 | RT shadows kept at Performance (1.5-2 ms GPU). They refine the sun and moon shadow maps rather than replace them (NVIDIA), so the cascade cuts below still apply. |
| `[PostProcess]` FSR2Quality | 0 → 2 (Auto → Quality) | Fixed internal resolution; Auto swings with load. |
| `[Rendering/DRS]` Enable | true → false | DRS can't help a CPU-bound frame and softens the image. |
| `[Viewport]` FullScreenMode | 2 → 1 (exclusive → borderless) | Alt-tab back into exclusive fullscreen took several tries; borderless works first time and still holds 60. |
| `[Viewport]` AMDAntiLag | 0 → 1 → 0 | Off as a test. Unresolved: session10 (off) stuttered with the main thread on Zen 5c, session11 (off) was clean with it on Zen 5. |
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
| `[Streaming/Textures]` CinematicModeMipBias | added, 1 | Matches the Uber texture preset. The game never writes this key; deleting it restores the default. |

Unchanged on purpose: `[Viewport]` VSync=true, `[Engine]` LimitFPS=60,
`[Rendering]` HairWorksLevel=0, `[Visuals]` HdrEnabled=false (the panel is SDR),
`[Rendering/TAA]` EnableCAS=true with `[PostProcess]` SharpenAmount=0. Frame
generation and path tracing stay off.

## Captures

- **session6 (exclusive fullscreen, 33 min):** held 1.51%, 1% low 32.9 fps.
  The worst windows were loads into in-game cutscenes.
- **session9 (borderless, 51 min):** held 0.42%, 1% low 48.7 fps, GPU busy
  median 14.8 / P95 15.3 ms. Open-world riding and combat held 60. One in-game
  cutscene ran about a minute at 42-50 fps: CPU busy 20-23.5 ms per frame,
  GPU busy 15-16.7 ms, no thermal throttling, about 25% total CPU. The game's
  main thread is the limit, not the GPU or heat.
- **session10 (Anti-Lag off):** 4.64% held in gameplay; the bar cutscene
  stuttered throughout. The busiest CPU was a Zen 5 core in only 3% of
  seconds, so the main thread ran mostly on Zen 5c.
- **session11 (Anti-Lag off, ASPM off on DC too, 48 min):** held 1.68% and 1%
  low 32.2 fps overall, inflated by the initial load and a death reload;
  0.62% held in gameplay. The bar cutscene replay held 44 of 35,920 frames,
  with the busiest CPU on Zen 5 in 61-85% of each minute. Riding dipped to
  about 55 fps: one 169 ms CPU stall (streaming or a shader compile), plus two
  stretches with GPU busy medians of 17.1-18.3 ms. Two 10-second stretches ran
  at 30 fps while CPU busy fell and the CPU jumped to 94-96 °C, the signature
  of a menu or paused game rather than gameplay. Peak CPU 96 °C, median
  81 °C, no throttling.
- Captures that span a long pause read as a perfect 60 overall; analyze only
  the minutes before the pause.

## Game-specific notes

- FSR2Quality enum: 0 Auto, 1 Native AA, 2 Quality, 3 Balanced, 4 Performance,
  5 Ultra Performance. Native AA (1) is reported broken with FSR 4.
- `AAMode=5` uses FSR 4 automatically on RDNA 4 (the game ships
  `amd_fidelityfx_upscaler_dx12.dll` 4.1.1); FSR 2 is only the fallback for
  older cards, so there is no cheaper upscaler. GPU busy at the cap already
  includes FSR 4's cost.
- SpawnedLimit menu values: Low 75, Medium 100, High 130, Ultra 150, Ultra+ 160.
- RT toggles apply live in the menu, so an uncapped A/B (LimitFPS=0, VSync off)
  measures each effect's GPU cost in one session.
- Ray tracing roughly doubles CPU frame time in CPU-bound scenes (Wccftech:
  179 → 90 fps on an i7-14700K). It is the largest CPU lever, and the only one
  big enough for the cutscene drops, at the cost of RTGI bounce light.
- First views of a cutscene hitch on shader compiles; a replay of the same scene
  shows whether a spike was a compile.
- `[PostProcess] AllowCutsceneDOF` exists in the exe and defaults to true;
  `=false` removes cutscene depth of field (GPU only, cutscenes only).
- Clicking a graphics preset in the menu overwrites every key above; recheck the
  file after the first launch, since the game sometimes resets settings.
- Busy test spots: Novigrad's Hierarch Square (crowds, CPU), Crookback Bog
  (foliage, RT), Beauclair (draw distance).
- Left paused in the background, the game pushes the CPU to 95-97 °C and can
  trip the 100 °C thermal limit; foreground play stays at 78-87 °C.
- With Anti-Lag 2 off, PresentMon's CPU busy and GPU busy medians both sit at
  about the frame interval (16.6 ms at 60 fps, about 31 ms at 30), so they may
  not tell a CPU-bound frame from a GPU-bound one (unverified). Judge those
  sessions by held frames and core placement, and recheck session10's
  32-36 ms cutscene GPU busy reading against a capture with Anti-Lag on.

## Next steps if 60 isn't steady

1. In-game cutscene drops (CPU-bound): test one change per session, logging
   core placement each time.
   1. Restore the scheduler policy (machine.md) and confirm the main thread
      stays on logical CPUs 0-7.
   2. With placement steady, redo the AMDAntiLag A/B: 1 for one session, 0
      for the next, same route and cutscene.
   3. RT shadows 1 → 0 (`[Rendering/RT]` Shadows=0), also trimming GPU peaks.
   4. `[Rendering/RT]` EnableRT=false, which is the user's call because it
      drops RTGI everywhere.
   5. Minor: TDP 30 → 35 W in Motion Assistant, `AllowCutsceneDOF=false`,
      CascadeShadowDistanceScale2/3 1.5 → 1.
2. CPU-bound drops in Novigrad: SpawnedLimit 130 → 100 (Wccftech saw little
   difference on 5.0), then EnableRT=false.
3. GPU-bound drops (Crookback Bog, Toussaint): FSR2Quality 2 → 3 (Balanced),
   then RT shadows 1 → 0. RTGI has no off switch of its own; it goes only with
   EnableRT=false.
4. If neither holds 60, tune for the panel's 40 Hz mode instead (SKILL.md step
   8). The menu's limits are 30/60/75/90/120/144 with no 40, so set
   LimitFPS=0 and let VSync cap at 40, or try LimitFPS=40 in the file and check
   with a capture that it holds. Session9's cutscene had 10% of frames over
   25 ms, so 40 Hz alone wouldn't smooth it.
5. Don't bother: `AllowClothSimulationOnGpu` (NVIDIA-only), the `[Budget]`
   keys, DX11 (Remastered has no DX11 renderer), core-affinity tools.
