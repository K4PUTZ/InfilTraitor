# PERFORMANCE_BUDGET_MASTER_PLAN
## One content, many phones: the memory and time budget a segment has to fit — v0.3 (PB-0/1 ratified, PB-2 attributed and acted on)

> **Status: 🟢 v0.3, 2026-10-09 (session record `PROMPTS/RESUMO_SESSAO_2026-10-08_PERF_BUDGET_PB2.md`).** **PB-0 ratified** (§0b: Android 4 GB / Mali-G57 MP1 = the Moto g04s, 1.0 GiB TOTAL PSS at the peak; iOS A12 / 3 GB provisional). **PB-1 ratified** (§5, `segment_spec`, conservative). **PB-2 attributed and acted on** (§0c items 1-12): Android `Graphics` counts the Vulkan allocator's BLOCKS (32/64/128/256 MiB) and driver memory, and the two owners of the Galaxy's ~280 MiB jump were the glass pane's and the explosion flash's SCREEN READS — both replaced (screen-free glass, snapshot flash), plus facades as L8, dead cell-plane textures deleted, one Shader per source text. **Result, PLAYGROUND portrait: Moto PSS peak 890-914 MiB, Galaxy GL mtrack ~490 -> ~205 MiB (PSS ~785)** — both under the ceiling. Also built: the 30 fps default cap + an Options window (§0c, frame-cap study), the 3D aim dome and the cached aim update (§0c 11-12). **Resume at PB-3** (the marginal-cost table, segment-shaped maps) and PB-4 (the segment cycle); open questions in §6.
>
> v0.2 (2026-10-08): PB-0 ratified. v0.1: Opened by the Director on the Galaxy A16 round of 2026-10-08 (PSS at the 1.2 GB ceiling with ONE map and little content, while the game is going to gain many more props, walls, roofs, guard AI, skills and accessories). **Nothing here is built; the steps are planned and the first (the estimate of what a segment holds) is the next session, done with the Director.**
>
> **Where this lives.** The Director asked for this to go into the performance plan and to "move it forward". `PERFORMANCE_MASTER_PLAN` (in `PROMPTS/DONE/`) was ARCHIVED on 2026-10-07 at the Director's own request (3 400 lines of 2D-board history, "nothing open is carried"); resurrecting it would bury this under dead text, so this is its successor and the old file carries a pointer. The handset rows and the budget table stay in `DEVICE_DIAGNOSTICS_MASTER_PLAN` (§0.5: 30 fps / 33.3 ms); this plan owns the question "does the CONTENT we are going to author fit?". Overrule the placement and it moves in one commit.
>
> **Related:** `RENDER3D_MASTER_PLAN` (the board), `PROP_PIPELINE_PLAN` / `PROPS_TIER4_PLAN` (prop slots and budgets), `MOVEMENT_MASTER_PLAN` §6.0 and the roadmap step A1b (the agent model's budget), `docs/production/technical_debt.md` ("PSS against the 1.2 GB ceiling", "A1 Galaxy A16 round").

---

## 0. What the documents ALREADY say (read before estimating anything)

| Fact | Source | What it means for the budget |
|---|---|---|
| **A segment IS a map; only one is loaded at a time.** A level is a set of segments (`LevelGraph` → `MapCatalog.get_spec(map_id, {connections, segment_grid_pos, seed})`); what the player changed outlives the unload (checkpoint tiers). | `docs/ARCHITECTURE.md` (run state model), `docs/systems/MAP_MASTER_PLAN.md` | The unit of load, and so of memory, is ONE segment. The whole-map-built-at-load model does not have to scale to a 3×3 level. |
| Segment structure (locked): a **3×3 grid of 18×36 segments**, playable interior 7×25, 1 main + 1 secondary + 1 secret access per active edge, a 2-tile safe zone on the entry edge, full AP reset on entering a segment. | `docs/DESIGN_MASTER_PLAN.md` §14.1 | 18×36 = 648 GU² (+ the 5 GU buffer ring = 28×46 = 1 288 GU²). PLAYGROUND, the map every handset number so far comes from, is 44×22 = 968 GU² (+ ring 54×32 = 1 728): **bigger than a segment.** ⚠️ The doc says "tile" and the engine says GU, and the 7×25 interior is a second number: which one binds today is a question for the Director (§6, Q2). |
| A segment "does not hold many enemies (special maps aside)". | `DESIGN_MASTER_PLAN` §8.7 (target selection) | The STRESS map (24 guards, 60 props, 14 lights, 3×3 rooms) is deliberately beyond a typical segment: it is a ceiling test, not a typical one. |
| The cell plane is 512×512 cells (= 64 GU): a map past ~46 GU per side draws wrong. | `docs/measurements/scale_study_desktop_dense_2026-10-07.md` | A segment fits with room to spare. The plane's size is still a memory lever (§4). |
| Size alone is cheap, content is not: blast worst frame and idle `process` bend with props / guards / glass, not with floor area. | same study | The estimate must be in CONTENT, not in GU². |
| The frag grenade is the stress case and ships late-game; budgets are judged on it. | roadmap, 2026-10-07 decisions | The budget is "the strongest blast beside the densest segment". |

**Handset facts of 2026-10-08 (Galaxy A16, PLAYGROUND, release APK):** peak TOTAL PSS 1 257 MiB (other runs 1 198-1 230); at the peak Graphics 620 · System 301 · native heap 248 · code 43 (swap PSS 317). Load timeline: Graphics 0 -> 119 (boot) -> +64 (room build) -> +128 -> **+255 at the map-loaded submission**, then a ~590 MiB plateau that blasts do not raise; native heap peaks at ~450 MiB DURING the load. `COSMETIC_DENSITY` does not move the PSS. What owns the Graphics plateau is NOT attributed (`RenderingServer.get_rendering_info` reads nothing on Android release).

## 0b. PB-0 RATIFIED (Director, 2026-10-08): the floor device and the ceiling

| Decision | Value |
|---|---|
| **Android floor** | **4 GB RAM, GPU of the Mali-G57 MP1 class (Unisoc T606), Vulkan / GLES3: the Moto g04s `ZF524T5TG5` IS the floor device.** The Galaxy A16 is the mid reference |
| **Ceiling** | **1.0 GiB TOTAL PSS at the peak, the load's transient included** (GiB, because `dumpsys meminfo` reports MiB). RSS + swap is watched alongside it: it is closer to what gets the app killed |
| **Minimum quality at the floor** | 30 fps on play frames (§0.5 of `DEVICE_DIAGNOSTICS`); facades one mip level down (512×256) through a device profile (PB-8); the frag grenade in the heavy segment with the event-frame tolerance already ratified. 6 GB and up get full fidelity from the SAME content (§1) |
| **iOS floor (provisional, not measured)** | A12 / 3 GB (iPhone XR class). Its memory ceiling is a separate measurement (below) |

⚠️ **The ceiling is already broken:** the Galaxy A16 peaks at 1 198-1 257 MiB with ONE map larger than a segment, the Moto at 945-1 304 MB. PB-2 (attribute Graphics) is therefore the first technical step after PB-1, not an optional one.

**Device population (web research, 2026-10-08; order of magnitude, not a citation-grade figure).** Neither Google nor Apple publishes a clean count:
- Active Android devices: 3.3-3.9 billion (third-party estimates). Active iPhones: more than 1 billion; Counterpoint puts the iPhone at about 1 in 4 active smartphones (~1.2-1.5 billion). Apple's 2.35-2.5 billion counts every Apple device.
- Android by RAM: no authoritative public split was found. One unsourced market page gives 8 GB 38.5 %, 6 GB 25.3 %, 4 GB 16.3 %, 12 GB 13 % (it reads like NEW sales, not the installed base, and it omits <= 3 GB). Our estimate of the INSTALLED base, which lags sales by 2-4 years: <= 3 GB ~20-25 %, 4 GB ~25 %, >= 6 GB ~50 %. **A 4 GB floor reaches roughly 70-80 % of active Android.** The authoritative figure is the RAM section of Google Play Console's device catalog / distribution data once the game has a Play listing: replace this estimate with it then.
- Sources: [Android distribution dashboard](https://developer.android.com/about/dashboards), [market.us Android statistics](https://scoop.market.us/android-phones-statistics/), [Counterpoint via telecoms.com](https://www.telecoms.com/mobile-devices/iphones-make-up-nearly-one-in-four-active-smartphones), [Apple 2.35 B devices](https://mezha.ua/en/2025/01/31/apple-has-more-than-2-35-billion-active-devices-worldwide/).

**iOS against the Mali floor (the Director's question, 2026-10-08).** GPU and CPU: an A12 is several times faster than a Mali-G57 MP1 / Unisoc T606, so a frame that holds 30 fps on the Moto has wide margin on any iPhone iOS still supports. **Memory is NOT implied by the Moto:** iOS has no swap to page to (the Galaxy carried 317 MiB of swap PSS at the peak) and kills a foreground app at a hard per-device limit (jetsam) that Apple does not publish. A developer report reads `ActiveHard 2098 MB` on a 4 GB iPhone 12 ([Apple forums](https://developer.apple.com/forums/thread/688973)); a 3 GB XR is lower. The same 1.0 GiB ceiling probably fits, but on iOS it must be read from a real device's JetsamEvent log, and the Godot iOS export (Metal) has never been built for this project. Until then iOS is a provisional floor, not a measured one.

## 0c. PB-2 findings (2026-10-08, Galaxy A16 + desktop; IN PROGRESS)

Instrument: scenario op `gfx_census <name>` (`GfxCensus`: engine VRAM counters, textures and meshes by owner, cached imports,
distinct shaders) and `gpu_alloc <MiB>` (a known GPU allocation); `device_run.py --mem-poll` now also prints `Graphics:` and
`EGL mtrack`. **The engine's VRAM counters DO read on the Android release build** (they read 0 only before the first frame
is drawn, which is why every `MemStage` mark during the load prints 0).

1. **Android `Graphics` (= `GL mtrack` + `EGL mtrack` ~33 MiB) counts the Vulkan allocator's RESERVED BLOCKS, not the use.**
   Proven with `gpu_alloc` on OCCLUSION_ROOM: the first 20 MiB moved GL mtrack 288 -> 544 MiB (+256), six more (120 MiB of
   real use) moved nothing; in 4 MiB steps the block opened at ~215-219 MiB of engine `video`. Blocks grow 32 / 64 / 128 /
   256 MiB, which is the +64 / +128 / +255 step of the load timeline.
2. **About 55 bytes per PHYSICAL screen pixel** of render buffers: ~133-140 MiB of textures on the Galaxy (1080×2340),
   ~60 expected on the Moto (720×1612), ~12 on a 390×844 desktop window. `RENDER_SCALE` 0.5 did not move it (the world
   SubViewport is not where it lives). Not yet attributed buffer by buffer.
3. **Two cuts, no look change (`verify.py look` 0 px strict, commit `6b2a6608`):** facades stored as L8 (every sampler reads
   `.r`; ~16 MiB) and `CellPlaneStore`'s per-level `ImageTexture`s deleted (unread since R3D-END; ~1 MiB per level, ~32 MiB).
   Galaxy PLAYGROUND engine video **247 -> 193.5 MiB**; PSS 1 198-1 257 -> **1 118-1 164 MiB**.
4. **(RESOLVED in items 7-10: the owners were the glass's and the flash's screen reads.) GL mtrack did NOT fall with it** (~500-540 MiB). It jumps 69 -> 505 MiB inside ONE 4 s poll during the
   load, and OCCLUSION_ROOM at the same engine video (190) reads GL 286: PLAYGROUND holds **~215 MiB of driver memory no
   engine counter sees**. Ruled out by measurement: the staging buffer (`max_size_mb` 16: no change, twice), the
   `framing` resize, render scale, duplicate shaders (20 vs 12 distinct). Next: bisect PLAYGROUND's content (glass,
   actors' skinned meshes, props) against that gap.

5. **Moto g04s (the floor device) after the cuts, PLAYGROUND, two boots:** engine video 140.8 MiB, GL mtrack 238-263 MiB
   (the 256 MiB block never opens), **TOTAL PSS peak 890-914 MiB: inside the 1.0 GiB ceiling**, against 945-1 304 MB in
   the earlier rounds.

6. **Live allocator reads (2026-10-08, later):** `MemStage` now reads `RenderingDevice.get_memory_usage()` (the
   `RenderingServer` / `Performance` counters refresh once per DRAWN frame, and the whole load happens before one), with
   marks 12 / 20 / 25 / 30 / 35 inside `load_map()` and `[MEM-TRACE]` for the first 600 frames; `gfx_census` prints each
   texture's GPU format. **Moto, PLAYGROUND:** everything before the 3D board is 11.5 MiB; **`_start_board3d_live()` takes
   it to 83.5** (GL mtrack 67 -> 199: the first blocks open there); frame 2 peaks at 133.1, steady 140.8. Textures 107.6 on
   the Moto against ~50 on the desktop with the SAME scene textures (identical list and GPU formats: facades R8, planes
   RGBA8 512²×26, decals RGBA8 256²×42 with mips): **the difference is screen-sized buffers, ~50 B per pixel on the device**
   (~14 B/px measured on the desktop). `SCALE_3D=0.5` takes textures 107.6 -> 89.5: **~25 MiB of it is the 3D view's own
   buffers** at full resolution; the other ~45 is on the canvas / screen-copy side (the flash's warm screen copy is ~6 of
   it). GL mtrack sits 60-95 MiB over the engine total on the Moto (block slack, never the 256 block).
   **The Galaxy's open item is unchanged and needs the handset:** whether its load peaks past ~215 MiB (opening the 256
   MiB block that then stays) — the `[MEM-TRACE]` peak answers it in one run.

7. **Galaxy A16 trace (2026-10-08, night): the 256 MiB block is NOT opened by the engine's use.** GL mtrack goes 201 ->
   480 MiB DURING `_start_board3d_live()`, while the engine's allocator holds 89 MiB (peak over the first frames 193.6,
   steady 193.5): the jump is driver memory the engine does not count. Sharing one Shader per source text (20 -> 13
   resources, `466dcb98`, 0 px) moved GL 470-535 -> 458-522 and PSS 1 088-1 152 -> 1 035-1 099: real but small, not
   the cause. **The 3D render-scale lever does NOT touch it** (Galaxy, landscape, zoom 0.6, same scene): `SCALE_3D` 1.0 /
   0.7 FSR / 0.7 bilinear / 0.5 FSR read engine video 164.9 / 153.0 / 153.0 / 149.5 MiB and GL max 484 / 476 / 479 /
   475 MiB, PSS max 1 095 / 1 091 / 1 094 / 1 088. Captures (local, `Screenshots/lever_*.png`): 0.7 is slightly softer,
   0.5 shows stair-stepped voxel edges. **Verdict: restricting large screens buys ~12 MiB and costs sharpness: not worth
   it.** Next: what the driver allocates while the board is built (pipelines per material variant, the meshes' upload
   path), bisecting `_start_board3d_live()` with live GL reads.

8. **THE OWNER OF THE GALAXY'S DRIVER GAP: glass's screen read (2026-10-08, night, Galaxy A16).** Bisection:
   `BOARD_STEP_MS` (the main thread held after each phase of `build()`) shows the whole board build moving GL mtrack
   200 -> 201 MiB; the jump to ~500 comes with the FIRST DRAWN FRAMES. `HIDE_NODES` (now hides 3D nodes too) on actors,
   `Geometry` and the world canvases: no change. By map, same engine total, different driver total: SURFACES_GALLERY
   engine 190.8 / GL 267, DORM 151.5 / 208-214, GLASS 185.4 / ~500, PLAYGROUND 193.5 / ~500: only the maps WITH GLASS.
   **Ablation (GLASS map, the pane shader with its `hint_screen_texture` hint removed, nothing else): engine 185.4 ->
   150.0 MiB, GL mtrack ~500 -> ~208 MiB (-295).** A material that reads the screen in 3D costs ~35 MiB of engine
   buffers and ~250-295 MiB of driver memory on the Galaxy, even when no pane is drawn (the material existing is enough;
   hiding `Geometry` changed nothing). The Moto, whose 256 MiB block never opened, does not show it.
   The shader's maths (`max(behind × mul, body) + sheen`, in sRGB) can be approached WITHOUT the screen read by blending
   (a multiply pass, then an add pass), but not exactly: the `max(…, body)` floor over dark backgrounds is lost and two
   overlapping glass faces multiply twice (G-D2 wants the tint once). A look decision for the Director.
   **Lever captures on SURFACES_GALLERY** (local `Screenshots/lever_sg_*.png`): GL max 267 / 277 / 278 / 268 MiB for
   `SCALE_3D` 1.0 / 0.7 FSR / 0.7 bilinear / 0.5 FSR: the render scale buys nothing in memory.

9. **Screen-free glass + the flash's warm (2026-10-09, Galaxy A16).** Director on the lever captures: 1.0 is clearly best;
   **0.7 bilinear is a candidate for weaker devices, maybe 0.8** (a device-profile value, PB-8). Glass: `GLASS_BLEND=1` draws
   the pane as a multiply pass + an add pass (`glass_pane3d_mul/_add`), each held to once per pixel by the stencil (mul: ref 1
   > stored 0, add: ref 3 > stored 0/1; the glass mark the overlays read is now 3 for both versions). GLASS map: GL ~490 ->
   ~205 MiB, PSS ~940 -> ~690. **PLAYGROUND has a SECOND owner: the explosion flash's 2 s warm** (a canvas
   `hint_screen_texture` draw, `ExplosionFlashOverlay.warm()`, kept for the Galaxy's ~190 ms first-flash hitch, round 0b):
   with `GLASS_BLEND=1` + `FLASH_WARM=0`, GL ~490 -> ~205 MiB and PSS ~1 070 -> ~785 (`GUARD_REVEAL`'s depth read did not
   matter). Look differences of the new glass (captures `Screenshots/glass_cmp_*.png`, local): what stands behind a pane is
   now tinted (the original showed actors drawn after its screen copy untinted), and a very dark subject behind it gets a light
   veil (the add pass is calibrated for a background of sRGB 0.35, `glass_add_base`). **Open, for the Director:** adopt the
   new glass; and the flash warm (≈ +260 MiB of driver memory on the Galaxy) against its first-flash hitch.

10. **ADOPTED (Director, 2026-10-09): the screen-free glass and a snapshot flash.** *"Visualmente o vidro anterior estava
   melhor, mas se o ganho de performance é grande, vamos adotar."* The screen-reading pane (`glass_pane3d.gdshader`) is
   deleted; `GLASS_BLEND` is gone. Explosions on GLASS checked side by side (cracks, holes, falling shards, piles, decals at
   the same places and frames; local `Screenshots/glass_explosions_cmp.png`). The flash (Director: *"um resquício do método
   2D"*) inverts a ONE-TIME snapshot of the last frame (`get_viewport().get_texture().get_image()`, freed at `clear()`),
   drawn at alpha `amount` over the live screen, so the blend gives mix(live, inverted snapshot, amount) with no screen read;
   the 2 s warm and `FLASH_WARM` are gone. Galaxy A16, PLAYGROUND portrait: **GL mtrack ~205 MiB** (was ~490), engine 137 MiB;
   snapshot 2340×1080 in 36-37 ms once per detonation; grenade worst frames 115 / 79 ms (the warm-era 94-108; the cold
   190 ms hitch is gone with the screen copy). Pixel gate: PLAYGROUND 0 px, GLASS differs (the intended glass look), new
   baseline taken. **New finding:** a runtime ORIENTATION change (the `framing landscape` step on a portrait boot) reopens
   the 256 MiB block on the Galaxy (GL 205 -> ~466): the screen buffers are rebuilt at the new size while the old ones still
   exist. Portrait play is unaffected; a game that lets the player rotate would pay it.

    **Orientation (Director, 2026-10-09): the game is PORTRAIT by default; landscape is an extra / dev view that gameplay
    may unlock later.** So the rebuild-on-rotation block does not reach a new player.
11. **2D-remnant audit (2026-10-09, Galaxy, uncapped, `FRAME_PROBE` + new FrameSplit labels).** Per-frame script work at
    idle is ~0.2 ms (vision fog, temporal lights, guard attention, enemy visibility); the processing dev overlays only redraw
    when visible. **The cost is the GRENADE AIM DOME** (`AimBubbleOverlay`, R3D-WORLD kept it as a 2D drawing tessellated on
    the CPU and placed on the camera plane by `WorldCanvas3D`): idle 12.7-14.3 ms/frame, aim held still 15.7-16.7, target
    moving every 3 frames 17.8-22.0; **one dome redraw ~4-9 ms and one target update (`_set_targeting_target`: rays +
    prediction) ~5-9 ms on the Galaxy** (≈15-35 ms each on the Moto). Proposed: a real 3D dome (one hemisphere mesh built
    once, the lat/long grid and the wall section in its shader from the nearby wall segments as uniforms, the wall patches as
    a few quads), so moving the target sets uniforms instead of re-tessellating.

12. **AIM-DOME-3D + aim update (Director, 2026-10-09: "refaz o domo em 3D e otimiza o cálculo do alvo").** The dome is 3D
    geometry now: a unit hemisphere shell and floor disc built once, one quad per wall that reaches it, and the section
    decided per pixel in `aim_dome3d*.gdshader` from the nearby walls as uniforms (the CPU's ~900 rays and thousands of
    polyline points per redraw are gone). Five passes, priorities 0-4 under the rays' 5: volume (front faces: one entry
    surface per pixel, so no doubled seam), floor section, grid, wall patches, rim. Lines keep the 2D widths (canvas px at
    zoom 1 -> render-target px through the ortho projection). Side by side with the 2D dome on four views (open floor, cut
    by the back block, by the metal block's side, view E; local `Screenshots/aim_dome_cmp.png`): same shape, cuts, patches
    and grid. The aim update's dominant cost was `_clamp_gu_to_throw_range()` rebuilding `room._movement_edge_set()` (every
    wall edge of the map, a string key each) on every move, and the flood rebuilding `_blocked_edges_dict()`: both are now
    cached for the aim by `room._world_revision`. **Galaxy A16, target moving every 3 frames, uncapped: aim update 1.55-2.87
    -> 0.42-0.82 ms/frame, dome 1.18-2.92 -> 0.09-0.22 ms/frame, frame 17.8-22.0 -> 17.0-18.1 ms; the dome's GPU ~+1.2 ms
    (the 2D one ~+1.6).** Desktop: aim update 1.24-1.63 -> 0.27-0.38 ms/frame (clamp 0.9-1.1 -> 0.02). `verify.py look`
    0 px. **Moto g04s (the floor device), same scenario, uncapped, two boots per build (the old build = the three scripts
    of `551e8470`, labels checked in the logs):** idle 28.9 / 28.9 ms, aim held still 29.6 / 29.8, **target moving 44.5-45.1
    -> 34.4-34.5 ms/frame** (GPU 28.5 -> 29.1). Old: dome redraw 5.8-8.3 + aim update 5.0-7.0 ms per frame on average
    (≈17-25 + 15-21 ms per move); new: aim update 1.5-1.9 ms per frame, of it prediction begin 0.66-0.74, dome 0.37-0.51,
    clamp 0.07-0.10. What is left over the 33.3 ms budget while dragging is the GPU floor (~29 ms, the same at idle) plus the
    prediction restarting on every hovered cell (P-COOK's "hover" trigger); a debounce there is the next lever, the
    Director's call because it moves when the cook starts. Pre-existing, not from this: a throw scenario that quits 9 s after the throw reports 8 resources still in use at
    exit (same on the code before the change).

**Frame-rate cap study (Director, 2026-10-08; Moto g04s, PLAYGROUND, zoom 0.2, grenade 0 centred; `MAX_FPS=<n>` flag;
videos `videos/fps_z02_<n>.mp4`, local):**

| cap | idle ms/frame (fps) | idle GPU ms | blast frames | blast wall clock | blast mean / worst ms |
|---|---|---|---|---|---|
| 60 | 33.3 (30.0) | 22.9 | 212 | 7.07 s | 33.3 / 66.1 |
| 30 | 33.3 (30.0) | 22.9 | 207 | 6.92 s | 33.4 / 70.3 |
| 24 | 44.7 (22.4) | 23.1 | 171 | 7.63 s | 44.6 / 65.8 |
| 18 | 55.9 (17.9) | 23.8 | 148 | 8.22 s | 55.5 / 77.3 |
| 15 | 66.7 (15.0) | 27.9 | 140 | 9.28 s | 66.3 / 97.1 |

Read: on the Moto **60 and 30 are the same run** (a frame costs ~23 ms of GPU, past 16.7, so vsync already holds 30).
Below 30 the cost PER FRAME does not fall (GPU ~23-28 ms, worst frame unchanged): only the work per second does
(battery, heat). And **the blast stretches in wall time** (6.9 -> 9.3 s at 15) because its effects age in drawn frames
(the "animate in frames" rule): a cap under 30 is a slow-motion explosion, not a cheaper one. A 30 cap costs nothing on
the floor device and saves power and heat on faster phones (the Galaxy throttled at 30 C); it is the Director's call.

## 1. The principle: ONE content, N profiles

Every multi-device game ships quality tiers; the cost is acceptable when a tier is a DERIVATION (texture size, density, particle counts, LOD set at import / export / boot from the same authored content) and unacceptable when it is a second hand-authored version. Authoring rule that follows: content is authored once, at the fidelity of the pipeline already canon (facade 1024×512 grayscale, props through slots and their budgets, 16 texels per voxel), and every per-device reduction lives in a profile.

**Cheap to change later (do not pre-optimise):** texture resolution and mipmaps per tier, cosmetic density, instance sharing, prop LOD. **Expensive to change later (decide now):** the unit of load (settled: a segment), the per-actor budget (A1b: the agent model, the guards share a rig?), the voxel conventions that decide how many claims a prop and a wall cost, the cell-plane size, what is built at load versus on demand.

## 2. The method: a budget is derived, never typed

```
floor device (RAM, GPU)  ->  app ceiling (what the OS leaves a foreground game)
  -> minus the engine's fixed cost (boot Graphics ~119, shaders, code ~43, the actors' rig)
  -> minus the transient peak of a LOAD (native ~450 MiB today)
  -> = what ONE segment of content may cost
  -> divided by the marginal cost of each kind of content = how much of each fits
```
A rule of thumb used only to frame the Director's choice, NOT a measurement: a foreground app keeps roughly 40-50 % of the device RAM before the system reclaims it, so 1.2 GB reads as a ~3 GB floor device. The number that decides being killed is closer to RSS plus swap pressure than to PSS (RSS peaked at 982 MiB while PSS read 1 257): to be settled in PB-0.

## 3. The steps (PB-0, PB-1 ratified; PB-2 done; PB-6 / PB-8 begun from PB-2's findings)

| Step | What | Who / when | Output |
|---|---|---|---|
| **PB-0** ✅ | **Decide the floor device** (RAM, GPU class), **the ceiling's unit** (GiB or decimal GB; plans say "1.2 GB" without saying) and **which number is the ceiling** (PSS or RSS+swap). Recommendation: a Moto g04s class floor (about 4 GB), ceiling 1.0-1.2 GB with margin. | Director, next session | a signed line in this plan + `DEVICE_DIAGNOSTICS` §0.5 |
| **PB-1** ✅ | **The estimate of a segment's content** — done TOGETHER with the Director, from the design docs: rooms, props by tier (1-4), guards by type, lights, glass panes, roofs, materials in use, destructible area, objectives; three specs: LOW / TYPICAL / HEAVY (the heavy one carries the frag grenade). Read first: `DESIGN_MASTER_PLAN` §14, §8.7, `MAP_MASTER_PLAN`, the dormitory in `PROP_PIPELINE_PLAN` §8, STRESS as the upper bound. Confirm the segment's size in GU (Q2). | **NEXT SESSION**, with the Director | `segment_spec` table (this plan, §5) |
| **PB-2** ✅ (2026-10-09, §0c) | **Attribute Graphics on the desktop**, per load stage: textures vs buffers vs render targets, by category (facades, decals, board meshes, cell planes, actors, props). `RenderingServer` info works on the desktop; the handset confirms only the total (`GL mtrack`). The `MEM_STAGES=1` markers exist (`mem_stage.gd`). | Claude, desktop | a table: who owns the +255 MiB and the 590 MiB plateau |
| **PB-3** | **Marginal-cost table** on the Galaxy and the Moto: extend `scale_study.py` to read PSS / RSS / load time and vary ONE thing at a time on segment-shaped synthetic maps (18×36 footprint): props (0 / 30 / 60 / 120, per tier), guards (0 / 6 / 12 / 24), lights, materials in use, glass panes, roofs. | Claude, handsets | "+10 props = X MiB, Y ms load" per kind |
| **PB-4** | **The segment cycle**: load and unload N segments in a row (scenario `reload` / `load_map`), PSS and RSS must stay FLAT, plus the load time and the transient native peak per segment on both handsets (the 6 s load above is the number to beat or hide). The game unloads and reloads segments for the whole run, so a leak or fragmentation that a single load never shows is a bug here. | Claude, handsets | a flat-or-not verdict + load seconds per device |
| **PB-5** | **The verdict**: PB-1's specs × PB-3's marginal costs, against PB-0's ceiling and the fixed cost. Fits / fits with a profile / does not fit. | Claude with the Director | one table, one decision |
| **PB-6** 🟡 (begun 2026-10-08/09: facades L8, dead per-level plane textures, one Shader per source text, screen-free glass, snapshot flash, the aim's edge-set cache — §0c; NOT yet: the plane sized to the map, decal arrays, mesh budgets) | **Levers, one at a time, each measured** (only if PB-5 says so), in order of saving per loss of quality: (1) texture size and mipmaps per device tier (facades, decals); (2) the cell planes (512×512 for an 18×36 segment + ring is 224×368 cells: check a non-square or smaller plane); (3) the load staging (the native peak of ~450 MiB); (4) instance sharing of props and actors; (5) mesh budgets per prop slot. `COSMETIC_DENSITY` is measured NOT to be one. | Claude | each lever: MiB saved, ms, look change (capture) |
| **PB-7** | **Enforcement**: a per-segment memory budget checked the way `apk_audit.py --max-mb` checks the package (and the prop slot budgets of `PropValidator`), so new content cannot silently exceed the ceiling; a tier of `verify.py` or a standalone gate. | Claude | the check + its place in `verify.py` |
| **PB-8** 🟡 (first members: `FrameRate` — 30 default / 60 / uncapped in Options; candidate value: 3D render scale 0.7-0.8 for weak devices, Director 2026-10-09) | **The device-profile mechanism** (texture tier, density, particle caps from one setting at boot, default by device class). Built only if PB-5 needs it; `CosmeticDensity` is its first member. | Claude | `DeviceProfile` + the per-device defaults |

**Order and parallelism:** PB-0 and PB-1 first (the Director's input; nothing else makes sense without them). PB-2 and PB-3 need no Director input and can start the moment PB-1 names the content kinds. PB-4 is independent and cheap: it can run any time. PB-5 closes the study; PB-6 to PB-8 are conditional.

## 4. What NOT to do

- Do not trim before PB-2 attributes the memory (it did, 2026-10-09: §0c). The lesson stands for every new owner: measure first.
- **Do not add a material that reads the screen or the depth buffer** (`hint_screen_texture`, `hint_depth_texture`, a `BaseMaterial3D` with refraction / proximity fade) without measuring GL mtrack on the Galaxy A16: the glass pane's and the flash's screen reads cost ~250-295 MiB of driver memory just by existing (§0c 8-10). The guard silhouette's depth read measured free; that is a measurement, not a rule.
- **Do not read the engine's VRAM counters (`Performance` / `RenderingServer.get_rendering_info`) during a load**: they refresh once per drawn frame and read 0 before the first one. `MemStage` reads `RenderingDevice.get_memory_usage()` live.
- **A runtime orientation change reopens the 256 MiB block on the Galaxy** (the screen buffers rebuild while the old ones live): portrait is the default (Director, 2026-10-09); landscape stays a dev / later-unlocked view.
- Do not chase the `System` bucket of `dumpsys meminfo` (it grew 7 -> 300 MiB over the run while native fell and swap rose: the OS compressing the app's pages).
- Do not author a second, lighter version of any content for phones.
- Do not widen the content before PB-1 and PB-3 exist: that is how the estimate becomes a guess again.

## 5. `segment_spec` (PB-1, ratified with the Director 2026-10-08)

**Rule: the estimate is CONSERVATIVE on purpose** (Director: compute on the generous side, trim later). The specs are the content PB-3's synthetic maps are built from and PB-5's verdict is judged against. STRESS (24 guards, 60 props, 14 lights) stays the ceiling test, above HEAVY.

| Kind | LOW | TYPICAL | HEAVY (frag grenade) | Notes |
|---|---|---|---|---|
| Footprint (GU) | 18×36 | 18×36 | 18×36 | Q2: default; a level may use more, smaller segments |
| Rooms | 3 | 5 | 8 | every room carries an encounter / puzzle / objective / reward (`DESIGN` §14.2) |
| Props (tiers 1-4, total) | 15 | 30 | 60 | the tier split is measured per tier in PB-3 |
| Guards | **4** | **6** | **10** (2 types) | Director raised the draft's 2 / 4 / 8 |
| Cameras / drones | 0 | 2 | 4 | |
| Lights | 3 | 6 | 10 | |
| Glass (GU of pane, total) | **4** | **8** | **12** | **ordinary windows and meeting-room sides: low and narrow panes, never GLASS's giant ones** (GLASS is the deliberate extreme). The glass cost may be revisited: the Director sees fat left to trim (the COMMIT frame, 650-770 ms on the Moto, is the known item) |
| Materials in use | 4 | 6 | 9 | |
| Roofs | 1 | 2 | 3 | one playable storey |
| Destroyed at once | 1 grenade | 1 grenade | 2 grenades in a row, near glass | |
| **Small interactive / decorative content** | yes | yes | yes | switches, alarms, pickups, pictures, banners (decals), stamps: NOT counted in the 30 props; PB-3 must measure them as their own kind |
| **Overlay cost on top** | — | — | — | the HUD and the planned VISUAL SOUND interface ride on every segment: budget them as a fixed cost, not per content |

## 6. Open questions (the Director's)

1. ~~**Q1 (PB-0)**~~ — ANSWERED 2026-10-08, §0b: 4 GB / Mali-G57 MP1 (Moto g04s), 1.0 GiB PSS.
2. ~~**Q2 (PB-1)**~~ — ANSWERED 2026-10-08 (Director): **a segment is 18×36 GU; the 7×25 interior is a design guide only, not an engine limit.** A 3×3 level (9 segments) is the default because it is easy to read; the numbers stay revisable: a level may have more, smaller segments (e.g. 12) when a case calls for it. Consequence for the budget: the segment's GU footprint is a parameter of PB-3's synthetic maps, not a constant, and a smaller segment buys memory headroom.
3. **Q3** — a typical versus a heavy segment: is the heavy one the only place the frag grenade appears?
4. **Q4 (A1b)** — do the guards share the agent's rig and mesh (instancing), or are they separate models?
5. **Q5** — is a load of a few seconds (about 6 s on the Galaxy at PLAYGROUND's size: stage `11` to `40`, 16:48:12 -> 16:48:18) acceptable between segments, or should the next segment be prepared while the player is still in the current one? (This changes PB-4's target and the transient peak.)
6. **Q6 (new, 2026-10-09)** — the prediction restarts on every hovered cell while the aim is dragged (P-COOK's "hover" trigger, ~2 ms per move on the Moto): debounce it (start the cook only once the aim rests a few frames)? It moves WHEN the cook starts.

## 7. Evidence log

- 2026-10-08/09 (this plan's PB-2): §0c holds every number with its instrument (`gfx_census`, `gpu_alloc`, `MemStage` live reads, `[MEM-TRACE]`, `BOARD_STEP_MS`, `HIDE_NODES` for 3D nodes, FrameSplit labels on the aim); device logs were in `/tmp` and are not kept. Captures (local, git-ignored or untracked): `Screenshots/lever_*.png`, `lever_sg_*.png`, `glass_cmp_*.png`, `glass_explosions_cmp.png`, `flash_cmp.png`, `aim_dome_cmp.png`; videos `videos/fpsL_*.mp4`, `videos/fps_z02_*.mp4`.
- 2026-10-08 Galaxy A16: `docs/production/technical_debt.md` ("A1 Galaxy A16 round", "PSS against the 1.2 GB ceiling"); logs in `/tmp` are not kept: the numbers are in that file.
- 2026-10-07 desktop scale study: `docs/measurements/scale_study_desktop_{dense,empty}_2026-10-07.md` (the 46 GU wall; content, not size, bends the cost).
- Moto g04s, 2026-10-05 (C4): PSS peak 945-967 MiB (R3D-CLAIMS), `DEVICE_DIAGNOSTICS_MASTER_PLAN` top blocks.
