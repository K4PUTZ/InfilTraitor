# INFILTRAITOR — System Architecture

> **Engineering reference for the INFILTRAITOR runtime.** This document describes the systems **as currently implemented in code**, not as originally specified. Where the code diverges from earlier design specs (`docs/systems/*`), the **code is authoritative**.

**Source of truth:** `godot/scripts/`
**Last reconciled with code:** 2026-06-17
**Engine:** Godot 4.x · **Main scene:** `res://godot/scenes/game/room.tscn`

---

## How to read this document

Each system is tagged with an explicit status:

- **Implemented** — present in code and exercised at runtime.
- **Partial** — present in code, but with a meaningful gap (not wired into gameplay, hardcoded data, or a dead path).
- **Planned** — described in design docs, no functional code path yet.

Legacy design docs under `docs/systems/` and `docs/pipelines/` use a phase vocabulary (`L-IMP-xx`, `LIGHT-xx`, `M2-xx`). Those tags survive only as comment markers in the source. They describe **intent**, not guaranteed runtime behavior. This file supersedes the roadmap framing in those documents for anything concerning *what the code actually does*.

---

## Subcube Render Plane (Planned)

The engine uses two coordinate spaces. The **gameplay plane** (the rest of this document, `CELL_SIZE 256×128`) is unchanged — guard AI, A\*, `blocked_*`, TicSystem, alarms, triggers, movement. A planned **geometry/render plane** (`SUBCUBE_SIZE 64×32`, 4×4 subcubes per gameplay unit) adds subcube stacking, face lighting, occlusion-by-deletion, and dynamic geometry. Conversions happen only at the seam (`map_compiler.gd`). Canonical spec: `PROMPTS/SUBCUBE_MASTER_PLAN.md`.

---

## 1. Runtime Architecture

**Status: Implemented**

INFILTRAITOR is a single-scene tactical prototype. The scene root is `room.gd` (`Node2D`), instantiated from `room.tscn`. It is both the level container and the orchestration hub.

### Boot sequence (`room.gd::_ready`)

1. Load the shared `TileSet`, assign it to every `TileMapLayer`, and set per-layer `z_index`.
2. Generate the macro level: `LevelGraph.generate(level_seed)` → `MapCatalog.get_spec(map_id, …)` resolves the active map to a `MapSpec` (authored in inner/segment coords) → `MapCompiler.compile(spec, …)` applies the buffer offset and produces the base layout dictionary (size, floor/wall/structure tiles, blocked cells, blocked edges, enemy defs, exits). See **Map pipeline** below.
3. Apply the active perspective (`_layout_with_perspective`) and build the tilemaps (`_build_room`).
4. Instantiate the six controllers as children of `room`, in dependency order:
   `LightingController` → `VisionController` → `HudController` → `CameraController` → `FowController` → `GuardCoordinator`.
5. Wire signals (HUD → room handlers; `LightingController.lighting_rebuilt` → `VisionController.request_redraw`; turn manager → room; agent → room).
6. Set up the remaining overlays created directly by room (trail, noise, tile overlays, guard-noise indicator, hover label).
7. Spawn guards, initialize fog, center the camera, start the player turn.

### Map pipeline (`world/maps/`)

`room.gd` is a **renderer**: it consumes a `layout` dictionary and paints tilemaps, with
no knowledge of how the map was produced. Permanent (hand-authored) maps and the future
procedural generator share one vocabulary (`MapSpec`) and one compiler.

```
@export map_id ──► MapCatalog.get_spec(map_id, {connections, segment_grid_pos, seed})
                        PLAYGROUND → PlaygroundMap.spec()
                        SIGMA_01   → Sigma01Map.spec()
                        PROCEDURAL → ProceduralMap.generate(seed)   (stub)
                              │  MapSpec (inner/segment coords)
                              ▼
                   MapCompiler.compile(spec, context)   ◄ sole owner of the buffer offset
                              │  layout dict (raw/grid coords) — unchanged contract
                              ▼
                   room.gd _build_room / _cache_blocked_cells   (renderer, untouched)
```

- **`MapGeometry`** — pure, coordinate-agnostic primitives (`build_room`, `place_inner_room`,
  wall/door tile picking, wall blocked-edges). The single source of wall logic.
- **`MapCompiler`** — translates a `MapSpec` (authored in the 18×36 inner/segment space, same
  as `LevelGraph`) into the render-ready layout dict, applying the buffer offset in one place.
  Specs that set `access_from_graph` pull their doors from `LevelGraph` connections; otherwise
  they declare explicit `access_points`.
- **`MapCatalog`** — resolves `map_id` → `MapSpec`; unknown ids fall back to `PLAYGROUND`.
- **`definitions/*_map.gd`** — one `static func spec()` per permanent map. `PLAYGROUND` is the
  reference artwork mockup; `SIGMA_01` is the migrated test map; `ProceduralMap` is a stub.
- Note: outer walls block movement via `blocked_edges` only — they are **not** added to
  `blocked_cells` (interior bounded by edges). To add a map: author a definition + one
  `MapCatalog` branch. Map selection is the exported `map_id` on the Room node.
- **Wall storeys (N-floor):** `MapSpec.wall_height` (storeys for the outer perimeter; default 1)
  makes `MapCompiler` emit `wall_levels: Array[Array]` — `[0]` is the ground course (doors +
  dividers), `[k≥1]` the solid perimeter ring (no door gaps) so doorways stay normal-height with
  wall above. `room._build_room` renders level 0 on `StructureWallLayer` (z=10) and each higher
  level on a runtime `TileMapLayer` offset up by `WALL_FLOOR_STEP_PX` (=158px, the cube's
  side-face height) at `z=10+level`, so tops occlude sprites. `MapSpec.lights` feed the lighting
  system (§8). `@export wall_height_override` on Room forces a height for quick testing.

### Node topology (as built)

```
Room (room.gd, Node2D)              ← orchestrator + God Object (§13)
├── FloorLayer / StructureWall* / Structure* / Shadow* (TileMapLayer)
├── TurnManager            (TacticalTurnManager)   — scene node
├── EnemyPhaseController   (EnemyPhaseController)   — scene node
├── Agent                 (DebugAgent)
├── Enemies               (Node2D)  → GuardEnemy*  (spawned at runtime)
├── MovementOverlay / PathPreview / SelectionOverlay / TileLabelsOverlay
├── FogOfWarOverlay / VisionFogOverlay(FogRect)
├── Camera2D
├── HUD (buttons, labels, banners)
│
│   ── Controllers (added in code, not in .tscn) ──
├── LightingController     → LightRegistry, ShadowProjector, ExposureSystem
├── VisionController       → 7 debug/analysis overlays
├── HudController
├── CameraController
├── FowController
└── GuardCoordinator
```

### Control-flow model

- **Input:** `room._input` gives the `CameraController` first refusal (`handle_input` returns `true` when it consumes the event); otherwise room handles keyboard gameplay and hover. `room._unhandled_input` handles tile clicks / right-click move.
- **Per-frame:** `room._process` advances temporal lights, updates the vision-fog shader, and refreshes enemy visibility while guards animate.
- **Turn loop:** player spends AP to move → optionally ends turn → `TurnManager` emits `enemy_phase_started` → `room._run_enemy_phase` drives `EnemyPhaseController` over each guard → `finish_enemy_phase` returns control.

Data flow is **mostly** unidirectional for lighting (Light → Shadow → Exposure → overlays), but **not** for gameplay: controllers read and mutate room state directly (see §13).

---

## 2. Controller Architecture

**Status: Implemented** (extraction from the former monolith is in progress — see §13)

Six controllers were extracted from `room.gd` (the `MODULARIZE-01..06` series). They share a common pattern: `room` instantiates them, calls `setup()` with references, and they either expose direct methods or emit signals. **None of them is fully decoupled** — most hold a `_room` back-reference and read room's underscore-prefixed members.

| Controller | Base | Comms style | Owns |
|---|---|---|---|
| VisionController | `Node2D` | Direct calls (no signals) | 7 overlays, vision-mode state |
| HudController | `Node` | Emits signals | UI node references |
| LightingController | `Node` | Emits `lighting_rebuilt` | LightRegistry, ShadowProjector, ExposureSystem |
| CameraController | `Node` | `handle_input()` returns bool | Camera state, perspective buttons |
| FowController | `Node` | Direct calls | Reveal delegation + shader params |
| GuardCoordinator | `Node` | Emits signals; routes to guards | Nothing (operates on `_room._guards`) |

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

---

## 3. Guard AI

**Status: Implemented** · file: `agents/guard_enemy.gd` (~1,114 lines — see §13)

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

`EliteExposureOverlay` is the **only** consumer of stability/confidence (§6). HEAT overlays are inserted just above `FloorLayer`; LIGHT overlays render above structures.

### Gameplay / utility overlays (room)

`MovementOverlay`, `PathPreview`, `SelectionOverlay`, `TileLabelsOverlay`, `NoiseOverlay` (gameplay-visible), `GuardNoiseIndicator`, `TrailOverlay` (dev), and two `TileOverlay` instances (`_tile_shadow` MUL blend z=1, `_tile_game` MIX blend z=3) used for shadow tinting and markers. Each guard also draws its own vision cone (`_draw_vision_tiles` / `_draw_vision_smooth`) and dev debug label.

---

## 12. Camera & Perspective System

**Status: Implemented** · file: `controllers/camera_controller.gd` + `room._set_perspective`

- **Interaction:** left-drag pan with an 8px drag threshold, mouse-wheel zoom (`ZOOM_MIN 0.20 … ZOOM_MAX 1.20`, step 0.06), two-finger pinch-zoom.
- **Leash:** agent-centered hard radius `CAMERA_MAX_BORDER_TILES = 4` tiles with a 2-tile quadratic soft-zone ease-out; fully released in `dev_vision`.
- **Perspective:** four cardinal views (N/E/S/W). Switching re-lays-out the room: `_layout_with_perspective` rotates every cell/edge/route — `wall_levels` (all storeys), `structure_tiles`, `blocked_cells/edges`, `enemy_defs`, **`exit_cells`, and `light_sources`** — and remaps tile-name suffixes via `_PERSPECTIVE_SUFFIX_MAP`. `_set_perspective` then rebuilds tilemaps, re-spawns guards, re-derives blocked sets, re-initializes fog, re-centers, **redraws the tile-number overlay, calls `LightingController.rebuild_all()` (lights/semantics/shadows/exposure follow the rotation, refreshing the analysis overlays via `lighting_rebuilt`), and clears the now-stale dev trail.** Agent/selection cells are round-tripped through a base-coordinate transform (`_cell_to_base` / `_cell_from_base`) so positions survive the rotation. Principle: every per-cell system is re-derived from the rotated layout, exactly as initial `_ready` setup does.
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

## 15. Current Technical Debt

This section is descriptive, not aspirational. These are real properties of the code today.

### 15.1 `room.gd` is a residual God Object (~1,590 lines)

Despite the `MODULARIZE-01..06` extractions, `room.gd` still owns: input routing, turn handlers, agent move callbacks, tic application and escalation thresholds, audio detection, alert metering, busted/reset flows, perspective rotation math, isometric picking, guard spawning, LOS data fan-out, navigation blocked-cell assembly, temporal-light pumping, and most overlay creation. The controllers orbit it rather than replacing it.

### 15.2 `guard_enemy.gd` is oversized (~1,114 lines)

A single class mixes: FSM logic, A* movement + caching, detection math, attention, organic patrol, active search, comms emission, audio reaction, and three separate `_draw` routines (body, cone tiles, smooth cone, dev HUD). The detection/geometry core and the rendering/visual-interpolation concerns are strong candidates for separation.

### 15.3 Controller ↔ room coupling

Controllers are **not** isolated modules. They hold `_room` back-references and read/write room's underscore-prefixed members directly:
- `VisionController` mutates `_room._tile_game`, `_room._trail_overlay`, `_room._fog_rect`, and reaches `_room._lighting_controller._shadow_projector` (two-level reach-through).
- `GuardCoordinator` operates entirely on `_room._guards` / `_room._alert_meter` and is invoked from room's tic code.
- `CameraController` depends on `room.agent` and delegates perspective back to room.
Encapsulation is partial; these are extracted *responsibilities*, not yet *boundaries*.

### 15.4 Computed-but-unused lighting/exposure pipeline

The most significant integration gap: ShadowProjector → ExposureSystem produces a full, graduated, stability-aware tactical map every build, but **detection never consumes it** (the `exposure_system` arg to `TicSystem.evaluate` is always `null`), and the legacy `_shadow_tiles` modifier is a dead path (declared, never populated). The lighting stack currently drives **only visualization**. Wiring `ExposureSystem.get_detection_multiplier` into the tic callers is the single highest-leverage integration task.

### 15.5 Hardcoded / inferred data

- Lights: now map-driven from `MapSpec.lights` (the hardcoded test lights are retired), but omni-only and no serialization/anchor-authoring tooling yet.
- Tile semantics / heights: inferred from `blocked_cells`, not authored.
- No authoring tooling exists for semantics/heights, despite the `LIGHT-03` spec.

### 15.6 Pending modularization targets

- Extract a `DetectionController` / tic pipeline out of `room.gd` and wire exposure into it.
- Split `guard_enemy.gd` into FSM + movement + rendering.
- Give controllers real interfaces (pass data in, emit results out) instead of `_room` reach-through.
- Replace direct `_room._lighting_controller._shadow_projector` access with an accessor.

---

## 16. System Status Matrix

| System | Status | Maturity | Notes |
|---|---|---|---|
| Runtime / scene orchestration | Implemented | Functional | room.gd hub; boot sequence stable, but God Object (§15.1) |
| Controller architecture | Implemented | Functional | 6 controllers extracted; coupling to room remains (§15.3) |
| Guard AI (FSM) | Implemented | Functional | 5 states, monotonic escalation, search + patrol behaviors |
| Detection — visual | Implemented | Functional | tic-based; cone + LOS + posture + cover + flanking |
| Detection — audio | Implemented | Functional | distance + wall attenuation, hearing radius 2 |
| Detection — exposure link | Partial | Experimental | `exposure_system` arg never passed; `_shadow_tiles` dead |
| Noise system | Implemented | Functional | grid intensity, decay, agent + guard emission |
| Exposure system | Partial | Functional | 6 classes + stability + confidence computed; overlay-only consumer |
| Shadow projection | Implemented | Functional | LOS, height-aware, penumbra/deep passes; not wired to gameplay |
| Lighting (runtime) | Partial | Functional | temporal effects live; lights map-driven (omni), no authoring yet |
| Height semantics | Partial | Experimental | model exists; data inferred from blocked_cells |
| Fog of war | Implemented | Functional | persistent reveal + live vision-fog shader + peek |
| Tactical overlays | Implemented | Functional | 7 analysis + several gameplay/util overlays |
| Camera & perspective | Implemented | Functional | leash, zoom/pinch, 4-way perspective re-layout |
| Turn system | Implemented | Functional | AP economy, deterministic sequential enemy phase |
| Guard coordination | Implemented | Functional | whistle / radio / alarm / noise routing |
| Light/semantic authoring & serialization | Planned | — | specced (LIGHT-03), no runtime code path |

---

## Appendix: File Map

| Concern | File |
|---|---|
| Orchestrator | `world/room.gd` |
| Controllers | `controllers/{vision,hud,lighting,camera,fow}_controller.gd`, `controllers/guard_coordinator.gd` |
| Guard AI | `agents/guard_enemy.gd`, `agents/guard_attention.gd` |
| Agent | `agents/agent.gd` |
| Detection | `systems/tic_system.gd` |
| Turns | `systems/turn_manager.gd`, `systems/enemy_phase_controller.gd` |
| Noise | `systems/noise_system.gd` |
| Lighting core | `systems/lighting/{light_source,light_registry,shadow_projector,shadow_result,exposure_system,light_anchor}.gd` |
| World semantics | `world/{tile_semantics,wall_edge_data,tile_registry,level_graph}.gd` |
| Map pipeline | `world/maps/{map_geometry,map_compiler,map_catalog}.gd`, `world/maps/definitions/{playground,sigma_01,procedural}_map.gd` |
| Navigation | `navigation/{guard_pathfinder,movement_overlay,path_preview}.gd` |
| Overlays | `overlays/*.gd`, `ui/fog_of_war_overlay.gd` |

> Legacy specification docs (`docs/systems/*`, `docs/pipelines/*`) describe intended design and use phase tags (`L-IMP/L-ARCH/M2`). Treat them as design intent; treat **this document and the code** as the description of current behavior.
