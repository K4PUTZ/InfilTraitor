# INFILTRAITOR — System Architecture

> **Engineering reference for the INFILTRAITOR runtime.** This document describes the systems **as currently implemented in code**, not as originally specified. Where the code diverges from a design spec (`docs/systems/*`, the master plans), the **code is authoritative**.

**Source of truth:** `godot/scripts/` (251 scripts, ~81 700 lines; [`tools/persistent/CODEMAP.md`](../tools/persistent/CODEMAP.md) is the generated, always-current index of every class and signal)
**Engine:** Godot 4.6, GDScript · **Main scene:** `res://godot/scenes/game/room.tscn` · **Targets:** Android/iOS handsets (portrait), desktop for development

**Reconciliation status (2026-09-30).** Rewritten against the code on this date: **§0 (the architecture today), §1 (runtime: load pipeline, node topology, control flow), §15 (debt), §16 (status matrix) and the Appendix**. The old "Voxel Render Plane" section (the deleted 2D `TileMapLayer` board, the bake, `VoxelLayer[]`) moved to
[`history/ARCHITECTURE_PRE_R3D_2026-09-25.md`](history/ARCHITECTURE_PRE_R3D_2026-09-25.md) verbatim. **§2-§14 (controllers, AI, detection, noise, exposure, shadow, lighting, height, fog, overlays, camera, turns, coordination) were last reconciled with the code in 2026-07** and were only spot-checked on
2026-09-30 (the perspective paragraph in §12 and the `FloorLayer` / `floor_layer` references in §2.7 and §11 were corrected; nothing else was re-audited): treat a claim there as "true in July", and confirm it in the code before building on it.

The rules that must not be broken are in [`CLAUDE.md`](../CLAUDE.md) ("Architecture — inviolable rules"); the vocabulary (compass, faces, banned terms) in [`DIRECTION_GLOSSARY.md`](DIRECTION_GLOSSARY.md); each subsystem's decisions in its master plan ([`README.md`](README.md)).

---

## 0. The architecture today (2026-09-30)

INFILTRAITOR is a turn-based tactical stealth game. **The board is drawn in Godot 3D, from a packed voxel store, under a 2D game** (ratified 2026-09-15, finished at R3D-END 2026-09-25, `RENDER3D_MASTER_PLAN`). Gameplay is 2D on a grid of **game units (GU)**; the world is **voxels, 8 per GU axis and 8 levels per storey**;
an orthographic 3D camera (30 degrees down, 45 degrees around) looks at it. Actors, the HUD, fog, selection and the tactical overlays are still 2D nodes drawn on top (actors and some props move to 3D at R3D-ACTORS).

### 0.1 The layers, from data to pixels

```
 CONTENT (data on disk)            maps/*.map.json (sections, versioned, owner-registered) · props/*.json · bombs/ · weapons/ · ASSETS/materials/<id>/ (row + grayscale facade + decals)
		│  two tiers everywhere: res:// (shipped) then user:// (a player's; user wins on id collision)
		▼
 LOAD PIPELINE (room.load_map)     FileMapSource/MapFileService -> MapCatalog -> MapSpec -> MapCompiler (the ONLY owner of the buffer offset) -> base layout (BASE coordinates, rotation-independent)
		│                          -> RoomBuilder.layout_with_perspective (PerspectiveMapper) -> RoomBuilder.build_from_layout
		▼
 GEOMETRY REGISTRIES               EdgeRegistry (Edge -> 2 Slices, D16) · SlabRegistry (FLOOR/CEILING/INTERIOR) · JunctionResolver columns · VoxelBoard prop containers (PropBlock) and mesh props (MeshPropInstance)
		│  VoxelBoard._rebuild_voxel_store -> VoxelStore.build(...)   (WalkWarmer then fills the walk cache in idle frames)
		▼
 STATE                             VoxelStore      the ONLY place voxel state lives: flat per-claim arrays (visible, damage tier, carved side, variant, substrate, material), a derived dense occupancy grid, `gone_claims`; `Voxel` is a 1-int wrapper
								   CellPlaneStore  one 512x512 RG8 image per level: R = per-face soot code (base 6, 172 = clean, 5 = charred), G = light bucket (0..11)
								   GroundGrid      the cell lattice as closed-form maths (no tiles)
								   Room._base_*    records of everything a mission did, in BASE coordinates (damage, soot, cracks, openings, shards, shattered props, debris): replayed after a rotation, saved by SaveState
		▼
 SIMULATION (pure -> commit)       DetonationPlanBuilder: a 14-phase, time-budgeted, resumable cook (SETUP, SLICES, JUNCTIONS, PROPS, ROOFS, FLOORS, WALK, BURN, SOOT, LIGHT, PACKAGE, EXPOSE, SOOTWAVE, SMOKE) that builds a WorldDelta: a DESCRIPTION of what would change
								   PredictionCache keys it on (signature, world_revision); `delta.commit(room)` is the only writer; DetonationPresenter plays one frame that writes everything, then N frames of effects
								   Firearms: AgentShotController / WeaponBench -> BlastCalculator.plan_point_impact (walls) or plan_prop_impact (prop voxels); WeaponDef + ShotPunchTable; Glass: GlassShatter / GlassCrack / GlassOpening
								   Light: VoxelLightField (12 directional buckets per face) <- LightRegistry/ShadowProjector (tactical, GU resolution); visual brightness is not tactical visibility
		▼
 RENDER (3D, then 2D on top)       Board3DLive (Node3D under Room): meshes the VoxelStore in 16-voxel chunks, faces merged by MATERIAL, three visible faces; colour = material base_color x facade luminance sampled in world space at 16 texels per voxel;
								   light and soot are read PER CELL from the planes (a Texture2DArray), so a light or soot change is a layer upload, not a remesh; `BoardLook` owns the look constants; glass panes read the screen behind them
								   3D extras: PropMesh3D (mesh props, lit by the same planes), FloorPile3D (debris/shard decals), CircleField3D / QuadField3D / ShardField3D (VFX: one MultiMesh draw each), ActorBillboard3D (2D sprite frames as depth-tested billboards), GroundCanvas3D, VisionCone3D
								   2D on top: HUD (hud.tscn), FogOfWar, Selection/Movement/Path overlays, guards and the agent (baked frames)
```

### 0.2 Five rules the whole architecture leans on
1. **Voxel state reaches the screen only through the store and the mesher** (rule 8, hook R8). Nothing writes a tile, an image blit or a sprite for it.
2. **A level, a material family, a HUD widget is asked, never typed/compared** (rules 9, 10, 11): `ground_plane_level()`, `GlassMaterials.is_glass()`, `HudController`.
3. **Simulate, then commit.** Anything that predicts (a throw preview, a cook) returns a `WorldDelta`; only `commit()` mutates; a new committed mutation bumps `Room.bump_world_revision()` or cached predictions go stale.
4. **Records are in BASE coordinates.** Until R3D-ROT makes rotation camera-only, a rotation re-lays the whole map out and replays every `_base_*` record; every new consequence of a blast needs a base record and a replay.
5. **Materials are data, and the registry is the palette.** A row in `ASSETS/materials/<id>/` (balance numbers, colour, facade) drives destruction, fire, soot, debris and colour; nothing hardcodes a material's behaviour (`PROPS_TIER4_PLAN` §2b adds families and fallbacks).

### 0.3 Cross-cutting systems
| System | What it is | Files |
|---|---|---|
| **Registries** (autoload) | Material, Prop, Bomb, Weapon catalogs; two-tier; user wins | `systems/registries_autoload.gd`, `material_registry.gd`, `prop_registry.gd`, `destruction/{bomb,weapon}_registry.gd` |
| **Dev harness** | `DevFlags` (environment variables on desktop, `dev_flags.cfg` inside an APK), `Telemetry` (one timeline), `ScenarioRunner` (a session as data), `FrameSplit`, `MemStage` | `systems/{dev_flags,telemetry,scenario_runner,frame_split,mem_stage}.gd` |
| **Verification** | `tools/persistent/verify.py` tiers (docs / quick / smoke / full), `project_lint.py`, `run_selftests.py` (51 selftests), identity gates (`board_probe`, `pixel_gate`, `ground_gate`, ...) | `tools/persistent/`, `godot/scripts/tools/*_selftest.gd` |
| **Device pipeline** | release APK via `export_android.py`, `device_run.py`, `device_record.py`, flags through `dev_flags.cfg` (Moto g04s and Galaxy A16 are the budget devices: 30 fps / 33.3 ms) | `tools/persistent/`, `docs/pipelines/device_video_recording.md` |
| **Persistence** | `SaveState` (checkpoint-scoped: capture / restore / clear_run_state of the base records); `.map.json` sections (`MapFileService`, loud-fail load, unknown sections round-trip) | `systems/save_state.gd`, `world/maps/persistence/` |
| **Localization** | `tr("domain.key")` through an autoload | `systems/localization/` |

### 0.4 What is NOT built yet (so nobody assumes it)
R3D-ACTORS (live skinned actors, D64), R3D-ROT (camera-only rotation), R3D-WORLD (world-space 2D overlays), R3D-SURFACES (photographic ground), R3D-LOOK, R3D-CLAIMS / BUFFER; Prop shadows, the colour grade and the drop-in model pipeline (slots, several models per slot, `.iprop`, `.vox` containers; decisions `ACTOR` D66-D69, plans [`PROPS_TIER4_PLAN`](../PROMPTS/PLANNING/PROPS_TIER4_PLAN.md) and [`PROP_PIPELINE_PLAN`](../PROMPTS/PLANNING/PROP_PIPELINE_PLAN.md)); the first content scene, a dormitory (`maps/DORM.map.json`); the run-state model of §1; detection consuming the exposure pipeline (§15.4).

---

## How to read this document

Each system is tagged with an explicit status:

- **Implemented** — present in code and exercised at runtime.
- **Partial** — present in code, but with a meaningful gap (not wired into gameplay, hardcoded data, or a dead path).
- **Planned** — described in design docs, no functional code path yet.

Legacy design docs under `docs/systems/` and `docs/pipelines/` use a phase vocabulary (`L-IMP-xx`, `LIGHT-xx`, `M2-xx`). Those tags survive only as comment markers in the source. They describe **intent**, not guaranteed runtime behavior. This file supersedes the roadmap framing in those documents for anything concerning *what the code actually does*.

---

---

## 1. Runtime Architecture

**Status: Implemented** (rewritten 2026-09-30)

The scene root is `room.gd` (`Node2D`, instantiated from `room.tscn`): the level container and the orchestration hub. It is still large (§15.1) and every controller is a slice of its former self.

### Node topology (as built)

```
Room (room.gd, Node2D)                 orchestrator
├── Board3DLive (Node3D, built by code after every map load)   THE board: Camera3D (orthographic, 30/45), chunk meshes, glass, decals, prop meshes, VFX fields, actor billboards, ground overlays
│     (`_start_board3d_live()`; a map reload removes and rebuilds it; `board3d()` answers with the live one)
├── VoxelBoard (VoxelBoard, Node2D, hidden)   NOT a renderer: the level registry, the cell planes' application, the dirty -> `voxel_destroyed` pass, glass crack/rim/shard records, prop containers
├── Camera2D · TurnManager · EnemyPhaseController
├── Agent (DebugAgent) · Enemies (GuardEnemy*, spawned at runtime)       baked-frame actors, mirrored into 3D by ActorBillboard3D
├── MovementOverlay · PathPreview · SelectionOverlay · TileLabelsOverlay · FogOfWarOverlay · VisionFogOverlay(FogRect)
├── StructureLayer (TileMapLayer, hidden while the 3D board is live: the one tile layer that survives, for the prop tiles and the TileSet `GroundGrid` was measured from)
├── HUD (hud.tscn)        reached ONLY through `HudController` (rule 11)
│
│   controllers added in code: LightingController · VisionController · HudController · CameraController · FowController · GuardCoordinator · TurnController
│   world/controllers: InputController · SelectionController · AgentShotController · TestZoneController (grenades, props) · WeaponBenchController · DebugToolsController · WorldMarkersOverlayController
```

### The load pipeline (`room.load_map(map_id)`)
1. `MapCatalog.get_spec(map_id, ...)`: `maps/<id>.map.json` through `FileMapSource` / `MapFileService` first (res:// then user://), the code definitions (`world/maps/definitions/*_map.gd`) as fallback. `MapCompiler.compile()` applies the buffer offset (rule 7) and produces the **base layout** (`_base_layout`).
2. `RoomBuilder.layout_with_perspective(base, _active_perspective)` rotates it (`PerspectiveMapper`); `build_from_layout()` builds the registries (edges/slices, slabs, junction columns, prop containers and mesh props from the `props` section via `PropRegistry`).
3. `_rebuild_voxel_store()` builds the `VoxelStore` and starts `WalkWarmer`; the base records (`_base_damage`, `_soot_map`, ...) are cleared for a fresh map.
4. `_start_board3d_live()` builds the 3D board from the store and the registries; overlays, agent, guards, fog and the lighting controller are set up; the turn starts.
5. A rotation (`_set_perspective`) does steps 2-4 again and **replays the base records** (R3D-ROT retires this).

### Control-flow model
- **Input:** `InputController` turns mapped actions into signals `room` handles; `CameraController` gets first refusal on pointer events; a tile click is a GU pick (`Board3DLive.pick_cell()`: a ray against the ground plane plus each prop's box; walls are not asked, their cut-away is what lets the player click past them).
- **Per frame:** `room._process` advances temporal lights; `Board3DLive._process` re-aims its orthographic camera at `Camera2D`'s screen centre (the 2D camera is the one the player moves) and finishes a background remesh (`WorkerThreadPool`) when one is done; VFX fields advance; the prediction cook spends its time budget (`DetonationPrediction.step(budget)`).
- **Turn loop:** the player spends AP to move, shoot or throw; `end_turn()` -> `TurnManager.enemy_phase_started` -> `TurnController` drives `EnemyPhaseController` over each guard (sequential, deterministic) -> control returns.
- **A detonation:** throw -> (a cook may already be running from the aim preview) -> `DetonationPlanBuilder` delta -> `delta.commit(room)` (one write) -> `DetonationPresenter` effects -> prop consequences (`Room.apply_prop_proximity_effects`, `apply_prop_debris_fall`) -> soot stamped in timed steps -> light re-applied to the touched GUs -> `bump_world_revision()`.

---

### Interactive-object hit-testing — GU cell, not sprite *(Director, 2026-07-30)*

*"O clique para acessar o menu, ou executar uma ação é sempre diretamente na
GU, e não no objeto. O hitbox clicável fica no chão onde o objeto interativo
ou ator está posicionado, e não no sprite em si. Com algumas exceções, como
objetos quebráveis nas paredes ou lâmpadas no teto, que vão ser acionados por
clique/toque direto."*

**Default rule:** a floor-standing interactive object's (or actor's) click
target is the GU cell it occupies — `room._screen_to_tile(screen_pos)` resolved
against the object's own `gu_cell`/`cell` field — never a sprite bounding box
or radius. Shipped 2026-07-30 for the two floor props that had their own
sprite-radius `hit_test()`: `TestZoneController` (grenades) and
`WeaponBenchController` (bench weapons), both now GU-exact. `room._unhandled_input()`
is otherwise unaffected — it already resolves ordinary move-clicks through
`_screen_to_tile()`, so this brings prop hit-testing in line with the same
model rather than introducing a second one.

**Stated exception, not yet applicable:** wall-mounted breakables and
ceiling-mounted lamps click-test their own sprite directly — neither object
type exists in the codebase yet, so the exception is recorded but unbuilt.
When either is added, its `hit_test()` should NOT route through
`_screen_to_tile()`.

**Trap this closed, recorded so it isn't re-opened by accident:** a sprite
generally extends well above its own floor tile in screen space (that is what
"standing on a tile" looks like in isometric projection), so any code that
*synthesizes* a click on an object — not a real mouse/touch event — must
target the object's floor-cell screen position
(`room._tile_to_screen_center(cell)`, the exact inverse of `_screen_to_tile()`),
never a sprite-derived one (`_top_screen_pos()`/`_center_screen_pos()`-style
helpers). Getting this backwards is invisible in code review and only shows up
as a hit-test silently missing at runtime — it did, in this session's own dev
capture harness, before `_tile_to_screen_center()` was added specifically to
fix it.

### Run state model — three tiers *(Director, 2026-07-29; NOT built)*

A **segment IS a map**, and only one is loaded at a time; a set of segments makes
the larger level (`LevelGraph` → `MapCatalog.get_spec(map_id, {connections,
segment_grid_pos, seed})`, see the Map pipeline above). Segments connect through
matching entrances/exits, and **some puzzles require acting in one segment and
collecting the result in another** — so what the player changed has to outlive
unloading the segment they changed it in. There is **no deliberate save**: the
game is played in short infiltration waves with a beginning, middle and end.

| Tier | Holds | Written when | Lost when |
|---|---|---|---|
| **Live** | everything changed in the current segment since the last commit | continuously | **death** (rewind to the last commit) and quit |
| **Session** | per-segment environment deltas | **only** at a checkpoint step, or on leaving the segment | **quit** — the whole segment set reloads |
| **Persistent** | character RPG progression: skills, stats, clothing | automatically | never |

So death rewinds the agent in time to the segment's last committed state (its
load state, if no checkpoint has been reached yet); quitting mid-run discards
every segment's environment while leaving the character intact.

**Two consequences worth stating before anything is built:**

1. **The commit store cannot live on `room`.** `room` is destroyed when a segment
   unloads, which is exactly when a commit has to survive. It belongs in an
   autoload, the same lifecycle reason `Registries` owns the material/prop/bomb
   registries (see `FIX-SHUTDOWN-CRASH-01b`).
2. **Destruction is already in the right shape for this**, by accident rather
   than design: `room._base_damage` and `room._base_soot` are two
   `Dictionary[Vector3i → int]` in **base (un-rotated) coordinates** — snapshot
   is a duplicate, restore is a replace plus the `reapply_damage` pass that
   already exists for perspective rotation. Fog of war (`FogOfWarOverlay`, already
   described as segment-scoped and persistent) is a second such payload.
   **Scope of the rest confirmed by the Director (2026-07-30): "basicamente
   tudo que modifica o cenário"** — destruction (done), **puzzle pieces**,
   doors, collected items, and **dead (killed) enemies**. None of these four
   are inventoried anywhere yet; this is scope, not a mechanism — each still
   needs its own storage shape before a snapshot/restore or commit-on-checkpoint
   pass can cover it.

Full reasoning and the open half live in
[`DESTRUCTION_MASTER_PLAN.md`](../PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md) §7
question 0. This model deserves its own system doc once someone builds it; it is
recorded here because nothing else in the docs states it and it decides what has
to be serialisable.

---

## 2. Controller Architecture

**Status: Implemented** (extraction from the former monolith completed via MODULARIZE-01..06 and ENHANCE-08)

Seven controllers were extracted from `room.gd` (the `MODULARIZE-01..06` series, plus `ENHANCE-08: TurnController`). They share a common pattern: `room` instantiates them, calls `setup()` with references, and they either expose direct methods or emit signals. **None of them is fully decoupled** — most hold a `_room` back-reference and read room's underscore-prefixed members.

| Controller | Base | Comms style | Owns |
|---|---|---|---|
| VisionController | `Node2D` | Direct calls (no signals) | 7 overlays, vision-mode state |
| HudController | `Node` | Emits signals | UI node references |
| LightingController | `Node` | Emits `lighting_rebuilt` | LightRegistry, ShadowProjector, ExposureSystem |
| CameraController | `Node` | `handle_input()` returns bool | Camera state, perspective buttons |
| FowController | `Node` | Direct calls | Reveal delegation + shader params |
| GuardCoordinator | `Node` | Emits signals; routes to guards | Nothing (operates on `_room._guards`) |
| TurnController | `Object` | Callable references (callbacks) | Alert meter, detection decay, turn phase flow |

### 2.1 VisionController — `controllers/vision_controller.gd`

- **Responsibilities:** owns the three debug vision modes (`dev_vision`, `light_vision`, `heat_vision`) and instantiates/positions the seven analysis overlays (§12). Toggling a mode shows/hides the relevant overlays and the fog, and pushes `dev_vision` state into each guard.
- **Dependencies:** `_room` (read/write), `_fog_of_war` node, and `LightingController` accessors (`get_light_registry`, `get_exposure_system`, `get_tile_semantics_map`, `get_light_anchors`). It reaches through room into the projector: `_room._lighting_controller._shadow_projector`.
- **Events/signals:** none emitted. Receives `LightingController.lighting_rebuilt` (connected by room to `request_redraw`).
- **Room integration:** tight. It mutates `_room._tile_game`, `_room._trail_overlay`, `_room._fog_rect`, calls `_room._get_all_guards()`, `_room._update_enemy_visibility()`, and repaints room dev markers. This is the most room-coupled controller.

### 2.2 HudController — `controllers/hud_controller.gd`

- **Responsibilities:** UI wiring only. Holds button/label/banner references, connects button presses, and formats text (AP label, alert %, busted dialog, enemy-turn banner).
- **Dependencies:** the `@onready` UI nodes, passed in as a dictionary by `room`.
- **Events/signals:** `end_turn_requested`, `reset_requested`, `fullscreen_toggled(enabled)`, `viewport_toggled`, `numbers_toggled(enabled)`. Room connects these to its handlers.
- **Room integration:** clean-ish. The nodes still live in `room`'s scene tree; the controller only borrows references. The cleanest of the six.

### 2.3 LightingController — `controllers/lighting_controller.gd`

- **Responsibilities:** owns the entire lighting pipeline — creates `LightRegistry`, `ShadowProjector`, `ExposureSystem`; builds `tile_semantics_map` and `light_anchors`; runs the initial projection; rebuilds shadows+exposure on demand.
- **Dependencies:** `_room` for structural data (`_blocked_cells`, `_room_size`, `_current_blocked_edges`, `enemy_phase_controller.build_blocked_edge_set`).
- **Events/signals:** emits `lighting_rebuilt` after every `rebuild()`/`rebuild_all()` so overlays refresh. `rebuild_deferred()` defers a rebuild to the next idle frame (used by temporal lights).
- **Rebuild tiers:** `rebuild()` only re-projects shadows/exposure from the existing lights+semantics; `rebuild_all()` re-derives everything from the room's current layout — re-registers map lights (`_setup_lights_from_layout`), rebuilds `tile_semantics_map`, re-feeds the shadow projector (`_refresh_shadow_projector_inputs`), re-projects, and emits. `_set_perspective` calls `rebuild_all()` so lighting follows the rotated layout.
- **Room integration:** moderate. Reads room structural state; exposes accessors so VisionController never touches the systems directly (in principle — VisionController still reaches `_shadow_projector` through it).
- **Note:** lights are **map-driven** — `_setup_lights_from_layout` registers one `LightSource` per `room._current_light_sources` entry (the perspective-rotated `MapSpec.lights`); the old hardcoded `_setup_debug_lights` is retired. `tile_semantics_map` is still **inferred** from `blocked_cells`, not authored (§9, §10).

### 2.4 CameraController — `controllers/camera_controller.gd`

- **Responsibilities:** all camera interaction — left-drag pan, mouse-wheel zoom, two-finger pinch-zoom, an agent-centered leash with a quadratic soft-zone ease-out, and the four perspective buttons.
- **Dependencies:** the `Camera2D`, `_room`, and (deferred) the `VisionController` (to release the leash in `dev_vision`). Reads `_room.agent`, `_room.btn_perspective_*`.
- **Events/signals:** none. Exposes `handle_input(event) -> bool`; room calls it first in `_input`. Perspective buttons call `_room._set_perspective(dir)` directly.
- **Room integration:** moderate. Leash logic depends on `room.agent`; perspective is delegated back to room.

### 2.5 FowController — `controllers/fow_controller.gd`

- **Responsibilities:** owns *reveal bookkeeping* and the *vision-fog shader parameters*. Wraps `FogOfWarOverlay` (reveal_around, reset, peek reveals, is_cell_revealed) and computes the shader gradient uniforms (`update_vision_center`).
- **Dependencies:** `FogOfWarOverlay`, the `FogRect` ColorRect's `ShaderMaterial`, and `_room.WORLD_TILE_PX`.
- **Events/signals:** none.
- **Room integration:** thin. **Explicitly does NOT control FOW node visibility** — that belongs to `VisionController` (`_apply_fow_visibility`). This split is intentional but easy to trip over.

### 2.6 GuardCoordinator — `controllers/guard_coordinator.gd`

- **Responsibilities:** routes inter-guard coordination — whistle (nearby guards → SEARCH), radio (patrolling/suspicious guards → ALERT), alarm (all guards → CHASE + max alert), and per-move guard noise emission.
- **Dependencies:** operates on `_room._guards`, `_room._noise_system`, `_room._alert_meter`, `_room.agent`, and constants like `_room.WHISTLE_RADIUS`, `GUARD_NOISE_CHANCE_BY_STATE`.
- **Events/signals:** emits `guard_whistled`, `guard_radioed`, `alarm_raised`, `all_guards_alerted`. Connects each guard's `whistled`/`radioed` signals in `register_guard`.
- **Room integration:** tight. It owns no state; it is effectively a method-bag operating on room's arrays. `_on_guard_alarmed` and `_on_guard_emits_noise` are invoked directly from room's tic logic and enemy phase.

### 2.7 TurnController — `world/controllers/turn_controller.gd`

- **Responsibilities:** orchestrates turn phases, enemy AI execution, detection/alert system. Centralizes alert meter accumulation (Rule 5), detection decay, camera focus during enemy phase, and noise processing. Extracted in **ENHANCE-08**.
- **Dependencies:** `turn_manager`, `enemy_phase_controller`, `agent`, `camera`, `_fow_controller`, `_hud_controller`, `_vision_controller`, `_guard_coordinator`, `_noise_system`, `_noise_overlay`. Operates on `_guards`, `_blocked_cells`, `_current_blocked_edges`, `_room_size`.
- **Events/signals:** receives `turn_manager.player_turn_started` and `turn_manager.enemy_phase_started`; routes `_hud_controller.end_turn_requested`. Exposes callable references for TIC callbacks (`_apply_tic_result` function).
- **Key invariant:** **Only `_apply_tic_result()` accumulates `_alert_meter`** — all detection thresholds (CHASE/ALERT/SUSPICIOUS) trigger alert accumulation in one place, preventing duplicate logic.
- **Room integration:** moderate. Receives game state via `set_game_state()` after map loads or perspective changes. Most turn-phase functions are now delegated to it; room holds thin wrappers for backward compatibility.

---

## 3. Guard AI

**Status: Implemented** · file: `agents/guard_enemy.gd` (1 302 lines on 2026-09-15 — see §15.2)

A finite-state machine driven once per enemy phase plus continuous visual interpolation.

### States & transitions

States: `PATROL`, `SUSPICIOUS`, `SEARCH`, `ALERT`, `CHASE`. Escalation is **monotonic** — `receive_alert` and `observe_player` use an explicit priority map (`PATROL 0 < SUSPICIOUS 1 < SEARCH 2 < ALERT 3 < CHASE 4`) and never downgrade; de-escalation happens only via timers in `tick_state`.

| From | Trigger | To |
|---|---|---|
| PATROL | severity-1 sighting / med noise | SUSPICIOUS |
| PATROL | high noise (≥0.6) | SUSPICIOUS (faster timer) |
| any | severity-2 sighting | ALERT |
| any | severity-3 sighting (detection ≥ 1.0) | CHASE |
| ALERT | `state_timer` expiry | CHASE |
| CHASE | timer + known last position | SEARCH |
| SEARCH | `_search_turns_remaining` exhausted | SUSPICIOUS |
| SUSPICIOUS | timer expiry | PATROL (clears last-known) |

Entering ALERT emits `whistled`; entering CHASE emits `radioed` — these feed the `GuardCoordinator`.

### Behaviors

- **Organic patrol** (`_do_idle_behavior`): random idle pauses and 45°-stepped look rotation while patrolling.
- **Active search** (`_build_search_queue`): shuffled square-spiral of cells (radius `SEARCH_RADIUS=2`) around the last-known cell; walks and inspects each.
- **Movement:** A* via `GuardPathfinder.find_path`, with per-target path caching (`_step_toward`) and animated stepping (`move_along_path` / `_step_next`, tween per step; step duration scales with state).
- **Attention** (`GuardAttention`): decoupled head/vision angle that diverges toward a focus cell (next waypoint, alert source, search target) and decays.
- **Detection** (`evaluate_detection`): the single source of truth for "can this guard detect this cell" (see §4).

---

## 4. Detection System

**Status: Implemented** (visual + audio) · **Partial** (exposure not wired)

Detection is **tic-based**: a discrete check fires whenever an actor crosses a tile. `TicSystem.evaluate` (`systems/tic_system.gd`) is called:

- on every agent step (`room._on_agent_step_finished`, per guard), and
- before and after each guard move (`EnemyPhaseController.run_single_guard_turn`).

### Pipeline (per tic)

1. `TicSystem.evaluate` delegates the geometric/probabilistic check to `guard.evaluate_detection(target, range, blocked_cells, blocked_edges, …, agent_ref)`.
2. `evaluate_detection` computes:
   - **Manhattan distance** gate (`fov_range`),
   - **angular** gate (`fov_degrees` half-cone vs `facing_angle_deg`),
   - **LOS** via `can_see_cell` (Bresenham with diagonal corner checks against blocked cells/edges),
   - base probability from `FOV_DISTANCE_CURVE`, scaled by `FOV_LATERAL_FALLOFF` (axis offset),
   - **shadow** multiplier from `_shadow_tiles` (see caveat below),
   - **posture** multiplier (`DebugAgent.POSTURE_DETECTION_MULT`: standing 1.0 / crouch 0.55 / prone 0.20),
   - **cover** multiplier (`COVER_FULL_MULT 0.20`, `COVER_PARTIAL_MULT 0.55`) with **flanking** that nullifies cover when the guard is on the exposed arc.
3. `TicSystem` applies a **state multiplier** (`STATE_MULTIPLIER`: patrol 0.55 … chase 2.80) and rolls `randf() < raw_chance` → `detected`.
4. `room._apply_tic_result` accumulates `guard.detection` (`DETECTION_GAIN_PER_TIC = 0.4`) or decays it (state-dependent), then escalates the guard via thresholds (`SUSPICIOUS 0.30`, `ALERT 0.60`, `CHASE 1.00`) and the global `_alert_meter`.

### Exposure integration — **Partial / not wired**

`TicSystem.evaluate` accepts an optional `exposure_system` parameter and, if provided, multiplies by `exposure_system.get_detection_multiplier(target_cell)`. **Every caller passes only four arguments** (`room.gd:673`, `enemy_phase_controller.gd:26,46`), so `exposure_system` is always `null`. The full ExposureSystem (§7) is computed and rendered by overlays but **does not currently affect guard detection**.

### `_shadow_tiles` — **dead data path**

`room._shadow_tiles` is declared, passed to guards via `set_los_data`, and read in `evaluate_detection`/`_draw_shadow_debug` — but **never populated** (`grep` confirms: declared `{}`, only read, never written). The shadow detection modifier in `evaluate_detection` is therefore inert. Tactical concealment currently comes from posture, cover, distance, and LOS — **not** from the lighting/shadow systems.

---

## 5. Noise System

**Status: Implemented** · file: `systems/noise_system.gd`

A persistent grid of noise intensities with per-turn decay.

- **Emission:** the agent rolls `NOISE_CHANCE_WALK = 0.20` per step (`NOISE_INTENSITY_WALK = 0.5`). Guards emit on move via `GuardCoordinator._on_guard_emits_noise`, with per-state chance/intensity tables (`GUARD_NOISE_CHANCE_BY_STATE`, `GUARD_NOISE_INTENSITY_BY_STATE`).
- **Storage:** `Vector2i → {intensity, age}`; `emit` keeps the max; `decay_all` subtracts `NOISE_DECAY_PER_TURN = 0.25` at end of enemy phase and prunes zeros.
- **Perception:** `TicSystem.evaluate_audio` attenuates by distance (`HEARING_RADIUS = 2`) and by walls (`pow(0.6, walls_crossed)` along a Bresenham path). `room._process_audio_detection` feeds the result to `guard.hear_noise`, which raises `detection` and can push PATROL→SUSPICIOUS.
- **Feedback:** `NoiseOverlay` renders sound waves (gameplay-visible, not dev-only); `GuardNoiseIndicator` shows a fuzzy (±2 tile) directional cue around the agent when a guard makes noise.

---

## 6. Exposure System — Classes, Stability, Confidence

**Status: Partial** — fully computed, consumed only by overlays · file: `systems/lighting/exposure_system.gd`

ExposureSystem converts merged shadow topology into discrete tactical classes. It is built and rebuilt by `LightingController` and queried by the heat-vision overlays. It is **not** queried by detection (§4).

### Visibility classes (actual enum values)

| Class | Value | Detection mult (`DETECTION_MULT`) | Meaning |
|---|---|---|---|
| `FULL_LIT` | 5 | 1.00 | Maximum exposure |
| `DIM` | 4 | 0.80 | Dimly lit |
| `PENUMBRA` | 3 | 0.55 | Shadow edge |
| `SHADOW` | 2 | 0.30 | Concealed |
| `DEEP_SHADOW` | 1 | 0.10 | Hidden |
| `OCCLUDED_VOID` | 0 | 0.01 | Structurally sealed niche |

> Naming note: the design brief refers to a `VOID` class; the implemented constant is **`OCCLUDED_VOID`** (value 0). There is no separate `VOID`. Unclassified tiles default to `DEEP_SHADOW`.

`rebuild_from_results` merges multiple `ShadowResult`s by **most-visible-wins** per tile, then runs two extra passes:

### Shadow Stability — **Implemented**

`_populate_stability_and_confidence` assigns each tile a stability class based on the least-stable light touching it:

| Constant | Value | Source |
|---|---|---|
| `STABILITY_STATIC` | `"static"` | structural / steady light |
| `STABILITY_TEMPORAL` | `"temporal"` | flicker or pulse enabled |
| `STABILITY_DYNAMIC` | `"dynamic"` | rotating or `mobile` light |
| `STABILITY_OCCLUDED` | `"occluded"` | sealed void |

### Exposure Confidence — **Implemented, limited inputs**

Per-cell `float` derived directly from stability (`confidence_static 0.90`, `confidence_dynamic 0.50`, `confidence_temporal 0.25`, `confidence_occluded 1.00`).
- **Current use:** read only by `EliteExposureOverlay` for the confidence/stability visualization.
- **Limitations:** purely a function of stability class — no temporal sampling, no per-frame variance, no gameplay consumer. With the current hardcoded static test lights, nearly everything resolves to `STATIC`/0.90.

### OCCLUDED_VOID detection — **Implemented (conservative v1)**

`_detect_occluded_void` scans every in-room, unblocked, unlit cell and marks it `OCCLUDED_VOID` only if **all four orthogonal neighbors are blocked or edge-sealed**. Conservative: only fully boxed-in cells qualify.

---

## 7. Shadow System

**Status: Implemented** · file: `systems/lighting/shadow_projector.gd`

`ShadowProjector` computes a per-light `ShadowResult` via LOS classification (not binary). Three phases:

1. **LOS classification** — for each cell in radius: cone/directional angle filter, then Bresenham LOS (`_los_blocked`) with **height-aware occlusion** (`_obstacle_blocks_light`: low cover doesn't block overhead light, etc.) and wall-edge checks. Lit cells split into `fully_lit` (within `near_band_ratio = 0.65` of radius) vs `dim`.
2. **Penumbra pass** — shadow cells orthogonally adjacent to `fully_lit` become `penumbra`.
3. **Deep-shadow pass** — shadow cells with no lit cell in Chebyshev `deep_shadow_radius = 2` become `deep_shadow`.

Results carry five classes (`ShadowResult`: fully_lit / dim / penumbra / shadow / deep_shadow). The projector does **not** merge multiple lights or render — merging is ExposureSystem's job, rendering is the overlays'. Shadows are graduated and LOS-correct in code; the earlier "binary lit/shadow" framing in legacy docs is outdated. The gap is downstream: results feed overlays, **not** detection (§4).

---

## 8. Lighting System

**Status: Partial** — full runtime model, map-driven placement

- **`LightSource`** (RefCounted): position, `height_class`, `light_type` (omni/directional/cone/ambient/intermittent/emergency/mobile), radius, direction/cone angle, tactical energy, and temporal flags.
- **`LightRegistry`** (Node): id/cell-indexed storage; `get_all_lights`, `get_active_lights`, `get_lights_by_type`, `get_lights_affecting_cell` (radius-only, no occlusion), `update_temporal_all(delta)`.
- **Temporal effects — Implemented:** `LightSource.update_temporal_state` animates flicker, pulse, and rotation. `room._process` → `update_temporal_all` → if any light changed, `LightingController.rebuild_deferred()` re-projects shadows and exposure that frame. `TemporalOverlay` visualizes states.
- **Placement — map-driven:** lights come from `MapSpec.lights` → `layout.light_sources` (rotated by perspective) → `LightingController._setup_lights_from_layout` registers one omni `LightSource` per entry (`cell`, `radius`, `tactical_energy=intensity`, `height_class=HEIGHT_OVERHEAD`). The old hardcoded test lights are retired.
- **Authoring — still partial:** lights are placed by the map data but there is no runtime serialization/anchor-authoring tooling, and direction/cone/temporal params are not yet expressed in `MapSpec` (entries are omni `{x,y,height,radius,intensity}`). `LightAnchor` objects are synthesized from existing lights, not loaded.

---

## 9. Height Semantics

**Status: Partial** — model implemented, data inferred

- **`TileSemantics`** (RefCounted) defines height classes (`HEIGHT_FLOOR 0` … `HEIGHT_OVERHEAD 4`), structural categories (floor/low_cover/wall/tall/overhead), and vertical layers (`LAYER_SUBFLOOR..LAYER_OVERHEAD`), plus `blocks_light` / occluder flags.
- **Runtime use:** `LightingController._setup_tile_semantics` builds `tile_semantics_map` by **inferring** semantics from `blocked_cells` flags (`blocks_los`, `height`, `blocks_light`) — not from authored per-tile metadata. Heights feed `ShadowProjector` occlusion (`_get_obstacle_heights`) and `HeightOverlay`.
- **Limitation:** no height-painting workflow exists; semantics are reconstructed heuristically each build. `room.OBSTACLE_HEIGHTS` (crate/wall/column/…) is a separate legacy constant table not directly tied to the semantics map.

---

## 10. Fog of War

**Status: Implemented**

Two independent layers:

1. **`FogOfWarOverlay`** (`ui/fog_of_war_overlay.gd`) — segment-scoped, **persistent** discrete reveal. All tiles start hidden; `reveal_around(center, radius)` (Euclidean) marks cells permanently revealed for the segment. Supports temporary **peek** reveals (`add_peek_reveal` / `reset_peek_reveals`) used by the peek mechanic.
2. **Vision-fog shader** (`VisionFogOverlay/FogRect`) — a live screen-space gradient that tracks the agent and scales with zoom/viewport. Driven each frame by `FowController.update_vision_center` (inner/outer UV radii).

`FowController` owns reveal bookkeeping and shader params; `VisionController` owns whether the fog nodes are visible (hidden in any dev/light/heat mode). Reveal radius = `FOW_REVEAL_RADIUS (9) + vision_bonus_tiles`; shader gradient radius = `VISION_TILE_RADIUS (5) + bonus`.

---

## 11. Tactical Overlays

**Status: Implemented**

Two groups. **Analysis overlays** are owned by `VisionController` and gated by vision mode; **gameplay/util overlays** are created directly by `room`.

### Analysis overlays (VisionController)

| Overlay | File | Mode | Shows |
|---|---|---|---|
| `LightOverlay` | `overlays/light_overlay.gd` | LIGHT | light positions, radius, direction |
| `ShadowOverlay` | `overlays/shadow_overlay.gd` | LIGHT | projected shadow topology (5 classes) |
| `HeightOverlay` | `overlays/height_overlay.gd` | LIGHT | height classes, structure, anchors |
| `TemporalOverlay` | `overlays/temporal_overlay.gd` | LIGHT | live temporal light states |
| `ExposureOverlay` | `overlays/exposure_overlay.gd` | HEAT | visibility class per tile |
| `TileRiskOverlay` | `overlays/tile_risk_overlay.gd` | HEAT | detection-risk heatmap |
| `EliteExposureOverlay` | `overlays/elite_exposure_overlay.gd` | HEAT | shadow depth, confidence, stability |

`EliteExposureOverlay` is the **only** consumer of stability/confidence (§6). The HEAT / LIGHT overlays are 2D nodes drawn over the 3D board; their z-order is set in `room.gd` (`_apply_overhead_overlay_z`). (`FloorLayer` was deleted at R3D-END.)

### Gameplay / utility overlays (room)

`MovementOverlay`, `PathPreview`, `SelectionOverlay`, `TileLabelsOverlay`, `NoiseOverlay` (gameplay-visible), `GuardNoiseIndicator`, `TrailOverlay` (dev), and two `TileOverlay` instances (`_tile_shadow` MUL blend z=1, `_tile_game` MIX blend z=3) used for shadow tinting and markers. Each guard also draws its own vision cone (`_draw_vision_tiles` / `_draw_vision_smooth`) and dev debug label.

---

## 12. Camera & Perspective System

**Status: Implemented** · file: `controllers/camera_controller.gd` + `room._set_perspective`

- **Interaction:** left-drag pan with an 8px drag threshold, mouse-wheel zoom (`ZOOM_MIN 0.20 … ZOOM_MAX 1.20`, step 0.06), two-finger pinch-zoom.
- **Leash:** agent-centered hard radius `CAMERA_MAX_BORDER_TILES = 4` tiles with a 2-tile quadratic soft-zone ease-out; fully released in `dev_vision`.
- **Perspective:** four cardinal views (N/E/S/W). Switching re-lays-out the room (still the case on 2026-09-30: the ruling is camera-only rotation, built at R3D-ROT): `_layout_with_perspective` rotates every cell/edge/route — `wall_levels` (all storeys), `structure_tiles`, `blocked_cells/edges`, `enemy_defs`, **`exit_cells`, and `light_sources`** — and remaps tile-name suffixes via `_PERSPECTIVE_SUFFIX_MAP`. `_set_perspective` then rebuilds tilemaps, re-spawns guards, re-derives blocked sets, re-initializes fog, re-centers, **redraws the tile-number overlay, calls `LightingController.rebuild_all()` (lights/semantics/shadows/exposure follow the rotation, refreshing the analysis overlays via `lighting_rebuilt`), and clears the now-stale dev trail.** Agent/selection cells are round-tripped through a base-coordinate transform (`_cell_to_base` / `_cell_from_base`) so positions survive the rotation. Principle: every per-cell system is re-derived from the rotated layout, exactly as initial `_ready` setup does.
- **Isometric picking:** `_screen_to_tile` does a 3×3 diamond-center search to resolve the clicked tile across all four diamond quadrants.

---

## 13. Turn System

**Status: Implemented** · files: `systems/turn_manager.gd`, `systems/enemy_phase_controller.gd`

- **`TacticalTurnManager`**: AP economy — `max_ap = 2`, `move_points_per_ap = 3`. `spend_for_path_cost` converts path cost → AP (`ceil`); `consume_ap` for fixed costs (posture change, peek). Signals: `ap_changed`, `player_turn_started`, `enemy_phase_started`.
- **Player → enemy handoff:** `end_turn()` flips `is_enemy_phase` and emits `enemy_phase_started`; `room._on_enemy_phase_started` shows the banner, locks the camera, awaits the enemy phase, handles the busted/reset path, decays noise, and calls `finish_enemy_phase()` → `reset_player_turn()`.
- **`EnemyPhaseController.run_single_guard_turn`** runs each guard **sequentially and deterministically**: tic before move → `choose_next_cell` → animated move (+noise callback) → tic after move → `tick_state`. Tic results route back through `room._apply_tic_result` (passed as a `Callable`).

---

## 14. Guard Coordination

**Status: Implemented** · file: `controllers/guard_coordinator.gd` (see §2.6)

- **Whistle:** a guard entering ALERT emits `whistled`; guards within `WHISTLE_RADIUS = 3` are pushed to SEARCH at the last-known cell.
- **Radio:** a guard entering CHASE emits `radioed`; all PATROL/SUSPICIOUS guards escalate to ALERT.
- **Alarm:** when `_alert_meter` saturates (`_alert_max = 100`), `_on_guard_alarmed` puts every guard into CHASE on the agent's cell and emits `alarm_raised` / `all_guards_alerted`.
- **Noise:** `_on_guard_emits_noise` rolls per-state chance and feeds the global noise system + indicator.

All coordination operates directly on `room._guards`; the coordinator stores no guard list of its own.

---

---

## 15. Current Technical Debt

This section is descriptive, not aspirational. These are real properties of the code on 2026-09-30.

### 15.1 `room.gd` is a residual God Object (11 169 lines)
Despite `MODULARIZE-01..06`, `room.gd` still owns: input routing, turn handlers, agent move callbacks, tic application and alert metering, busted/reset flows, the perspective re-layout and every base-record replay, the picking glue, the dev capture/scenario/benchmark entry points, the prop consequence code, and the reads of 38+ distinct dev flags (`_dev_flag("NAME")`). It grew (11 909 lines on 2026-09-15, 11 169 now after R3D-END's deletions) because each track added its seam here. **R3D-ROT deletes the replay half; the dev entry points are the next extraction** (they are not game logic).

### 15.2 Other oversized files
`DetonationPlanBuilder` 3 057 lines (one cook, 14 phases: cohesive but huge), `TestZoneController` 1 611 (it became the grenade and prop controller, the name is the placeholder it started as), `guard_enemy.gd` 1 312 (FSM + movement + detection + three `_draw` routines), `VoxelBoard` 2 404 (state, planes, glass records, prop containers), `Board3DLive` (the whole 3D board in one node).

### 15.3 Controller <-> room coupling
Controllers hold `_room` back-references and read/write room's underscore members (`VisionController` reaches `_room._lighting_controller._shadow_projector`; `AgentShotController` calls `room._on_voxel_destroyed` and `room._release_destroyed_prop_cells`). They are extracted *responsibilities*, not yet *boundaries*. The one boundary that IS enforced is the HUD (rule 11, hook L3).

### 15.4 Computed-but-unused lighting/exposure pipeline
`ShadowProjector -> ExposureSystem` produces a graduated, stability-aware tactical map every build, but detection never consumes it (`TicSystem.evaluate`'s `exposure_system` argument is always null); the one consumer is `EliteExposureOverlay`.

### 15.5 State that is not yet consistent across a rotation
Until R3D-ROT, every mission consequence needs a base record + a replay (`_base_damage`, `_base_shattered_props`, `_base_debris`, ...); one soot round-trip diff is open on PLAYGROUND (2-4 texels at cell (216,24), bisected to `6d21893d`). A prop's blocked GU is erased in place (`_release_destroyed_prop_cells`) but the lamps' cached shadow map is not re-fed (same gap as a burnt wall).

### 15.6 Hardcoded / inferred data
Tile semantics and heights are inferred from `blocked_cells`; lights are map-driven (omni only) without authoring tooling; `TestZoneController` still seeds dev grenades; material rows are calibrated by eye with the Director, not derived.

### 15.7 Documentation debt
`docs/systems/*.md` (ai, lighting, movement, noise, perception, rendering, stealth), `docs/technical/{ASSET_MAP,TEXTURE_CATALOG,repo_structure,developer_setup}.md` and §2-§14 above pre-date R3D and were reconciled to the code only as far as their banners say.

---

## 16. System Status Matrix

| System | Status | Notes |
|---|---|---|
| Runtime / scene orchestration | Implemented | `room.gd` hub (§15.1) |
| **3D board (`Board3DLive`) + `VoxelStore`** | **Implemented** | the only board since R3D-END (2026-09-25); both budget handsets hold 30 fps idle |
| Voxel geometry (slices, slabs, junction columns, prop blocks) | Implemented | `VOXEL_MASTER_PLAN`; 8 voxels per GU axis, 8 levels per storey |
| Destruction (blast, firearm, fire, charred tone) | Implemented | `DESTRUCTION_MASTER_PLAN` (closed) + R3D-PROPS; tiers DEST/DENT/CRACK; one-layer ladder for props |
| Prediction (simulate -> `WorldDelta` -> commit) | Implemented | `systems/prediction/` (cache, reaper, warmer) |
| Glass (physics, shatter, crack, shards, panes) | Implemented | `GLASS_MASTER_PLAN` |
| Light (voxel buckets, cell planes) | Implemented | `VoxelLightField`; real 3D lamps rejected (+24 ms GPU on the Moto) |
| Props Tier 1/2 (hollow voxel crates), Tier 3/4 (real CC0 models) | Implemented | R3D-PROPS; Tier 4 voxel replacement + the persistent charred pile built 2026-09-30 (`PropVoxelizer`, `PropFragmentSim`, `PropFragments3D`); prop colour from the material registry and the wider charred tones built (P4/P5), shadows and the grade planned (`PROPS_TIER4_PLAN`) |
| Model pipeline: slots, several models per slot, validator, fallback chain | Implemented (PP1, 2026-09-30) | `SlotDef`, `PropValidator`, `PropRegistry.resolve_placement`; `.iprop`, the user tier for models and `.vox` are planned (`PROP_PIPELINE_PLAN`); first content: the dormitory scene |
| Actors (agent, guards) | Partial | baked 2D frames mirrored as billboards; live rigs at R3D-ACTORS (D64) |
| Rotation | Partial | four views by full re-layout + base-record replay; camera-only is R3D-ROT |
| Guard AI (FSM), detection (visual/audio), noise | Implemented | `docs/systems/AI_MASTER_PLAN.md` |
| Detection <-> exposure link | Partial | §15.4 |
| Shadow / exposure / height semantics | Partial | overlay-only consumers; data inferred |
| Fog of war, tactical overlays, camera, turns, coordination | Implemented | 2D on top of the 3D board |
| Map files (`.map.json`), two-tier maps | Implemented | `MAPFILE_REFERENCE.md` |
| Save (`SaveState`) | Partial | the plumbing; no slots/UI (`save model is checkpoint-scoped`) |
| Device harness (APK, `DevFlags`, `Telemetry`, scenarios, video) | Implemented | `DEVICE_DIAGNOSTICS_MASTER_PLAN` |
| Verification (`verify.py` tiers, selftests, identity gates) | Implemented | one known red in `full`: PLAYGROUND rotation soot (§15.5) |
| Light/semantic authoring & serialization | Planned | specced (LIGHT-03), no runtime code path |

---

## Visual Storeys

The INFILTRAITOR engine is fundamentally **two-dimensional in gameplay** and **multi-layered in rendering**.

Only **Storey 0** exists as a gameplay plane. Every other storey is a render-only layer whose purpose is to extend the world vertically without increasing gameplay complexity.

Gameplay systems operate exclusively on Storey 0, including:

- Pathfinding (A*)
- AI and Guard FSM
- Line of Sight (LOS)
- Collision
- Physics
- Alarms
- Tactical systems
- `blocked_cells`
- `blocked_edges`

Additional storeys do not participate in simulation. Instead, they are used to render:

- Extended walls
- Ceilings
- Structural beams
- Pipes and ducts
- Hanging lights
- Architectural details
- Decorative props
- Underground scenery
- Lava, water, smoke and atmospheric effects

This separation allows environments to appear vertically complex while preserving a strictly two-dimensional gameplay model.

> *The "Vertical Rendering and Parallax" note that used to follow (per-layer parallax factors for upper storeys, backgrounds) described the 2D layered board. It was never built and the 3D orthographic camera makes it moot; it is preserved in the history copy.*

---

## Appendix: Where things live

`godot/scripts/` (full API: [`CODEMAP.md`](../tools/persistent/CODEMAP.md), generated):

| Folder | Holds |
|---|---|
| `world/` | `room.gd` (hub), `world/builders/room_builder.gd`, `world/controllers/*`, `world/maps/` (catalog, compiler, file maps, persistence), `world/utilities/` (iso projection, perspective mapper), `wall_edge_data.gd` (the only source of edge keys) |
| `geometry/` | voxel geometry classes (`slice`, `slab`, `edge`, registries, generators, `junction_resolver`, `prop_block`, `mesh_prop_instance`), `voxel_board.gd`, **`board3d_live.gd`**, `board_look.gd`, `ground_grid.gd`, 3D fields (`circle_field3d`, `quad_field3d`, `shard_field3d`), `floor_pile3d`, `prop_mesh3d`, `actor_billboard3d`, glass helpers, `pick_math` |
| `systems/` | `voxel_store`, `cell_plane_store`, registries and their autoload, `save_state`, dev harness, `tic_system`, turn manager, noise, `occlusion_set`, material/texture resolvers |
| `systems/destruction/` | `blast_calculator`, `detonation_plan_builder`, `detonation_presenter`, weapon/bomb defs and registries, shot tables, glass shatter/crack, `material_resistance_table` |
| `systems/prediction/` | `world_delta`, `detonation_prediction`, `prediction_cache`, `prediction_reaper`, `walk_warmer` |
| `systems/lighting/` | `voxel_light_field`, `light_registry`, `shadow_projector`, `exposure_system`, `light_source` |
| `agents/`, `navigation/`, `controllers/` | actors and guard AI, pathfinding and movement overlays, the extracted room controllers (incl. `hud_controller`) |
| `overlays/`, `ui/` | 2D overlays and VFX, HUD panels, fog of war, menus |
| `tools/` | selftests (`*_selftest.gd`), fixtures, dev-only spikes and bake helpers; `spikes/` holds R3D-era experiments |

Outside `godot/`: `maps/` (`*.map.json`), `props/`, `bombs/`, `weapons/` (data rows), `ASSETS/` (local only: materials, art, audio), `tools/persistent/` (verification and device tooling), `docs/`, `PROMPTS/` (plans and session records).

> Legacy specification docs (`docs/systems/*`, `docs/pipelines/*`) describe intended design and use phase tags (`L-IMP/L-ARCH/M2`). Treat them as design intent; treat **this document and the code** as the description of current behavior.
