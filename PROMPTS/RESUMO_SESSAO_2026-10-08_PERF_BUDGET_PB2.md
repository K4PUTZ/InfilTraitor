# Session record — 2026-10-08/09: PERFORMANCE_BUDGET PB-0, PB-1, PB-2 (and what PB-2 found)

Started from `PERFORMANCE_BUDGET_MASTER_PLAN` v0.1 ("estimate one segment's content WITH the Director"). Every item below is on `main`
(`a03a3cdc` .. `a643a086`, 20 commits); `verify.py smoke` passed at every code commit, `verify.py look` at every look-affecting one (0 px, or
the intended GLASS change with the baseline retaken). The plan is now **v0.3**; every number and instrument is in its §0b / §0c.

## Decisions (Director)
- **PB-0 — floor device and ceiling:** Android 4 GB with a Mali-G57 MP1 class GPU (the Moto g04s), **1.0 GiB TOTAL PSS at the peak**, the
  load included; iOS A12 / 3 GB provisional (unmeasured; iOS has no swap and a hard per-device jetsam limit). Web research recorded (active
  devices by RAM: no authoritative split; a 4 GB floor reaches roughly 70-80 % of active Android).
- **PB-1 — `segment_spec`** (conservative): a segment is 18×36 GU (7×25 is design-only; 3×3 segments the default, more and smaller allowed);
  LOW / TYPICAL / HEAVY: guards 4 / 6 / 10, props 15 / 30 / 60, glass 4 / 8 / 12 GU of small panes, small interactive content and the HUD +
  visual-sound interface measured on their own.
- **Frame rate: 30 fps by default**, 60 / uncapped as a player choice; nothing under 30.
- **Options window from the Escape menu** (frame rate + language).
- **Adopt the screen-free glass** ("o vidro anterior estava melhor, mas se o ganho de performance é grande, vamos adotar").
- **The flash: "um resquício do método 2D"** — handled as Claude saw fit (a one-time snapshot).
- **Portrait is the default orientation**; landscape is a dev / later-unlocked view.
- **3D render scale:** 1.0 stays; 0.7 bilinear (maybe 0.8) is a candidate value for weaker devices (a device-profile value, PB-8).
- **Rebuild the aim dome in 3D and optimise the aim update.**

## Built
1. **Instruments:** scenario ops `gfx_census <name>` (engine VRAM counters, textures / meshes by owner with their GPU format, cached imports,
   distinct shaders and which read the screen / depth, nodes processing or drawing every frame) and `gpu_alloc <MiB>` (a known GPU allocation);
   `MemStage` reads `RenderingDevice.get_memory_usage()` live, with marks 12/20/25/30/35 inside `load_map()` and `[MEM-TRACE]` for the first
   600 frames; `device_run.py --mem-poll` prints `Graphics:` / `EGL mtrack`; flags `MAX_FPS`, `BOARD_STEP_MS`, `HIDE_NODES` (3D nodes too);
   FrameSplit labels on the aim update.
2. **Memory cuts:** facades stored as L8 (every sampler reads `.r`); `CellPlaneStore`'s per-level `ImageTexture`s deleted (unread since
   R3D-END, ~1 MiB each); one `Shader` per distinct source text on the board.
3. **Screen-free glass:** `glass_pane3d_mul` + `glass_pane3d_add` (multiply then add, each held to once per pixel by the stencil; the glass
   mark is 3), `glass_pane3d.gdshader` deleted. Explosion behaviour checked side by side.
4. **Snapshot flash:** the negative frame inverts a one-time `get_image()` of the last frame drawn at alpha over the live screen; the 2 s warm
   is deleted.
5. **`FrameRate`** (30 default, saved choice) + **`OptionsPanel`** (frame rate, language), the Main Menu fitted to a landscape phone.
6. **AIM-DOME-3D:** the dome is a shell + floor disc built once, one quad per wall, the wall section per pixel (`aim_dome3d*.gdshader`); the
   aim's two map-wide edge sets are cached by `room._world_revision`.

## Findings worth keeping
- **Android `Graphics` (GL mtrack + EGL mtrack) counts the Vulkan allocator's reserved BLOCKS (32 / 64 / 128 / 256 MiB) and driver memory, not
  the use.** Proven with `gpu_alloc`: +20 MiB moved GL 288 -> 544, six more moved nothing.
- **A material that reads the screen (or, measured free here, the depth buffer) costs ~250-295 MiB of driver memory on the Galaxy just by
  existing.** The two owners were the glass pane and the flash's warm. After both: Galaxy PLAYGROUND portrait GL ~490 -> ~205 MiB, PSS
  ~1 070 -> ~785; Moto PSS 890-914 MiB.
- The engine's VRAM counters DO read on Android release, but only after a frame is drawn (the whole load reads 0).
- ~55 B per physical screen pixel of buffers on the device; the 3D render scale moves almost nothing (Galaxy: ~12 MiB) and costs sharpness.
- A runtime orientation change reopens the Galaxy's 256 MiB block.
- Frame cap: on the Moto 60 and 30 are the same run (GPU ~23-29 ms); under 30 the blast stretches in wall time (effects age per frame).
- The aim dome was the one real 2D remnant with a cost: ~4-9 ms per redraw on the Galaxy; the aim update's dominant cost was rebuilding the
  map's edge sets per move. **Moto, dragging the aim: 44.5-45.1 -> 34.4-34.5 ms/frame.**
- Pre-existing, not from this session: a throw scenario ends with 8 resources still in use at exit (folded into the plan's PB-4).

## Resume point
1. **PB-3** — the marginal-cost table: segment-shaped synthetic maps (18×36), vary one content kind at a time per `segment_spec`, PSS / GL
   mtrack / load time on the Moto and the Galaxy (`scale_study.py` extended).
2. **PB-4** — the segment cycle: load / unload N segments, PSS and GL must stay flat.
3. Director questions in the plan's §6: Q3 (frag grenade only in heavy segments?), Q4 (guards share the agent's rig?), Q5 (load time between
   segments / prepare the next one), **Q6 (debounce the prediction while the aim is dragged)**.
4. PB-6's next lever: the 512×512 cell plane sized to the map.

Not done / owed: `verify.py full` was not run (nothing rewired the board state, light or ground); the iOS floor is unmeasured; the options
window was touch-tested on the Moto with the previous build's translucent box (the opaque box was checked on the desktop only).
