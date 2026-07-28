# INFILTRAITOR — Current Project State

<!-- AUTO:BEGIN header -->
**Version:** 0.9.82 · **Updated:** 2026-07-28 · **Branch:** main
<!-- AUTO:END header -->

> **Executive snapshot of the entire project. Where we are right now — with honesty about what works and what does not.**

---

## Project Status

### Pending Prompts

<!-- AUTO:BEGIN pending_prompts -->
- RESUMO_SESSAO_2026-07-26_TEMPORAL_LIGHT_FOUNDATION.md
- RESUMO_SESSAO_2026-07-28_FLOOR_ZONE_BAKE.md
<!-- AUTO:END pending_prompts -->

### Inventory

<!-- AUTO:BEGIN inventory -->
**Code & Test Inventory**

- GDScript modules: 122
- Test scripts: 25
- Known maps: 3
- Shipped facade files: 0
- Archived prompts: 16
<!-- AUTO:END inventory -->

### Version History

<!-- AUTO:BEGIN version_history -->
- 09e03ee [DOCS] Session close: FLOOR-ZONE-BAKE reference, schema tables, VERSION 0.9.82
- f6e68b8 ALPHA TEMPORAL LIGHT FOUNDATION 0.9.81 - VL-D5 stone soot + session close
- 3260943 ALPHA VOXEL LIGHT 0.9.80 - VL-D4 wood: directional bias + ember-to-char glow
- b7ac34b ALPHA VOXEL LIGHT 0.9.79 - VL-03 incremental light-field repaint; flicker ON
- c74a146 ALPHA VOXEL LIGHT 0.9.78 - VL-D3 under-wall floor darkening
<!-- AUTO:END version_history -->

---

## Current Goal

**Primary target:** Investor Demo — functional, polished game mechanics in a single demo room.
Placeholder graphics, no audio, no narrative, no complex animations, no polished UI. The success criterion is *feeling*: stealth must be fun, guards must react believably, and the tension loop must be noticeable to anyone who plays for 5 minutes.

---

## Voxel Rendering System — Wall Architecture Refactor (VOXEL-01..07 Complete)

**Status: Phase 2 Complete (Runtime System 100%)**

The **Voxel Render Plane** replaces the legacy `WallContainer` + `Image.blend_rect` system with a native `TileMapLayer`-based architecture. The old approach suffered from cascading calibration dependencies; the new system is purely analytical — no empirical offsets. Phase 2 (Runtime) is now complete with full dirty flag tracking and TIC loop integration.

### What works (VOXEL-01..07)

✅ **Geometry & Asset Generation (VOXEL-01)**
- Voxel PNG tiles regenerated with correct 3D isometric geometry (32×36 px, 3 visible faces: top + left + right)
- 4 materials supported: concrete, metal, stone, wood
- Diamond top face (bright), left/right side faces (darkened 80%)
- All tiles visually validated in Godot

✅ **Coordinate System & Constants (VOXEL-02)**
- Voxel constants registered in `GeometryCoords` (`godot/scripts/geometry/geometry_coords.gd`): `VOXELS_PER_UNIT_AXIS=8`, `VOXEL_TILE_SIZE=Vector2i(32,16)`, `VOXEL_STEP_PX=20.0`
- Bidirectional coordinate conversion functions: `gu_to_voxel_origin()`, `voxel_to_gu()`, `voxel_local()`, `gu_voxels()`
- TileSet built at runtime in `_build_voxel_tileset()`, assigned to all 8 voxel layers per storey
- Layer positioning: `z_index = WALL_BASE_Z_INDEX + level`, `position.y = VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX × level`

✅ **Data Classes & Type Safety (VOXEL-03)**
- `VoxelRef`: individual voxel state (grid_pos, level, visible, dirty, damage_state, face_atlas_rect)
- `WallSlice`: primary container (1 edge × 1 adjacent GU × N storeys = 64 × storey_count voxels)
- `HighWall`: secondary container (group of WallSlices + junction_extras; unit of baking)
- Selftest (`voxel_selftest.gd`) validates 425 correctness checks — 100% passing
- Type hints resolved; no parse errors in Godot or headless mode

✅ **Wall Voxel Placement (VOXEL-04)**
- `_place_wall_voxels()` iterates all wall edges, creates 2 WallSlices per edge (S0 inner, S1 outer)
- `_voxel_slice_positions()` analytically calculates 8 voxel grid positions for each slice
- Edge directions supported: NW (-1,0), NE (0,-1), SE (1,0), SW (0,1)
- Voxels rendered via `TileMapLayer.set_cell()` — no Image operations, no legacy offsets
- All voxel layers created on demand; rendering fully functional in Godot editor

✅ **Junction Detection + Extra Voxels (VOXEL-05)**
- V-junction detection identifies 2 walls at vertex
- `_build_voxel_junction_extras()` analytically calculates gap-filling voxel positions
- `HighWall.junction_extras` array populated with corner voxels
- Integrated into wall rendering via separate layer; no gaps in corner walls

✅ **VoxelRegistry — Centralized Indexing (VOXEL-06)**
- `VoxelRegistry.new()` creates centralized container for all WallSlice/HighWall instances
- Indexed lookup by edge key and wall direction
- `all_high_walls()` iteration API for TIC loop and baking pipelines
- Integrated into `room.gd` during wall building phase

✅ **Dirty Flag + TIC Loop Integration (VOXEL-07)**
- Per-voxel `dirty: bool` flag with parent reference tracking
- Per-slice and per-HighWall `dirty_count` aggregation for efficient skipping
- `_tic_voxel_system()` processes only dirty containers — O(container_count) cost at idle
- `_apply_voxel_state()` renders/erases voxels based on visibility + damage state
- Runtime integration: called once per agent step via `_on_agent_step_finished()`
- All 12 acceptance tests passing; Godot loads clean

### What's built (VOXEL-08..09) and what's pending (VOXEL-10..11)

✅ **VOXEL-08** — Primary Baking System (COMPLETE — B3 CLOSED 2026-07-08, BAKE-FIX-14)

**What works (BAKE-FIX-01 through BAKE-FIX-07):**
- Master-strip facade baking: TextureResolver + FacadeSampler + run grouping (BAKE-FIX-01)
- Dictionary lookup infrastructure + field naming fixes (BAKE-FIX-05)
- H-flip junction mirroring + per-junction material overrides (BAKE-FIX-06, 3/3 tests PASS)
- Dual-path rendering validation: both generic and baked compile identical layouts (BAKE-FIX-07, 9/9 tests PASS across 3 phases)
- All walls support per-facade texture overlays via BakedTileLookup.resolve(edge, face, voxel) → (source_id, atlas_coords)
- `VoxelRef.face_atlas_rect` populated at map load
- BakeConfig.enabled gates between baked and generic rendering (default: false for safety)
- Run-continuity: facade veins flow across contiguous wall edges; deterministic via FNV-1a(edge_key)
- Junction continuity: corner columns render with mirrored neighboring silhouettes or material overrides

**B3 closure (2026-07-08, BAKE-FIX-14):**
- Pixel-by-pixel alpha comparison against the independently `load()`-ed canonical voxel texture: 41472 pixels across 4 materials, **0 alpha mismatches**
- No SubViewport required — `Texture2D.get_image()` decodes imported resources in `--headless` mode
- Junction mirroring verified through the public `VoxelRenderer.render()` API (3/3 PASS)
- Full closure record, evidence, and prior false-closure history: `docs/technical/BAKE_SYSTEM_REFERENCE.md`
- `BakeConfig.enabled` remains `false` by default; enabling in shipped builds is a Director config call (`user://bake_config.cfg`), no code change

⏳ **VOXEL-09** — Secondary Baking System (DEFERRED — Phase 5)
- Per-HighWall texture baking (single large texture spanning all constituent voxels)
- Architectural framework in place; implementation postponed
- No schema changes required; uses same `face_atlas_rect` field

⏳ **VOXEL-10** — Destructibility (DEFERRED)
- Damage states: `INTACT=0`, `CRACKED=1`, `DESTROYED=2`
- Overlay texture + visibility logic via dirty flags
- Integration with TIC loop
- No code impediment; design complete

⏳ **VOXEL-11** — CODEMAP Update (DEFERRED)
- Register all voxel wall data in project codemap
- Enable runtime queries (e.g., "which walls can this agent see?")

### Technical Notes

- **Coordinate planes:** Gameplay plane (256×128 px, guards/AI unchanged) + Voxel render plane (32×16 px, 8×8 per GU)
- **No legacy offsets:** `FACE_CENTER_OFFSET`, `SUBCUBE_FACE_OFFSETS`, `is_x_varying`, `blend_rect` all archived
- **Preservation:** Wall edge data and the map compiler contract remain unchanged (the subcube/WallContainer renderer itself was removed)
- **Godot status:** Loads clean; no parse errors or warnings; voxel rendering visually validated
- **Performance:** Dirty flag propagation is O(1) per change; TIC loop is O(container_count) at idle
- **Bake cache:** Sparse-usage page composition now composes only the referenced atoms for a facade page, shrinking page size for sparse maps while preserving the atlas content; the regression suite reports 7 PASS, 0 FAIL.

---

## AI State — What works vs. what is incomplete

The AI system is **functional but simplified** relative to the design intent.

**What works correctly:**
- Guards detect the agent probabilistically via `TicSystem.evaluate()`
- When detection occurs, the guard escalates to `STATE_SUSPICIOUS` (detection ≥ 0.30), `STATE_ALERT` (≥ 0.60), or `STATE_CHASE` (≥ 1.00)
- Escalation is gradual, based on the `guard.detection` meter accumulation
- `tick_state()` performs timer-based de-escalation (CHASE → ALERT → SEARCH → SUSPICIOUS → PATROL)
- Audio detection via `hear_noise()` with integrated thresholds
- Guard-to-guard communication (whistle / radio) functional via signals
- Correct, efficient A* pathfinding
- `choose_next_cell()` is state-aware (per-state behavior implemented)

**Visual Escalation Implementation:**
- Code in `room.gd:_apply_tic_result()` accumulates `guard.detection` per tic
- Defined thresholds: `DETECTION_THRESHOLD_SUSPICIOUS := 0.30`, `ALERT := 0.60`, `CHASE := 1.00`
- State transitions occur when the meter crosses a threshold while the agent is visible
- The meter decays slowly when the agent leaves the cone (different rate per state)

---

## Global Status Overview

| Category | Status | Maturity | Real Progress |
|----------|--------|----------|---------------|
| **Core Navigation & Movement** | Functional | Beta | 90% |
| **Turn System** | Functional | Beta | 85% |
| **Pathfinding (A\*)** | Functional | Production | 95% |
| **Noise System (math)** | Functional | Beta | 80% |
| **Lighting & Shadows** | Functional + Semantic Design | Alpha→Beta | 85% |
| **Fog of War** | Functional | Beta | 80% |
| **Enemy AI / Guard FSM** | Functional (gradual escalation) | Alpha | 75% |
| **Detection / Stealth** | Functional (probabilistic with gradation) | Alpha | 70% |
| **Perception (calculation)** | Functional | Beta | 75% |
| **Audio (SFX)** | Not started | — | 0% |
| **Animation (sprites)** | Not started | — | 0% |
| **UI/UX** | Prototype | Prototype | 30% |
| **Narrative** | Not started | — | 0% |
| **Combat** | Not started | — | 0% |
| **Content** | Sparse | Prototype | 15% |
| **Voxel Rendering System** | Partially Implemented | Alpha | 40% |

---

## Maturity Definitions

- **Prototype** — Proof of concept, may break
- **Alpha** — Core working, known limitations
- **Beta** — Feature-complete, refinement phase
- **Production-Ready** — Polished, tested, stable

---

## By Domain

### Core Navigation & Movement (90% — Beta)
✅ **Functional:**
- 4-direction grid movement with smooth tweening
- AP system (2 per turn)
- Dijkstra pathfinding for the movement overlay
- A* pathfinding for guards (excellent quality)
- Wall blocking via WallEdgeData

❌ **Not implemented:**
- Diagonal movement
- Rough terrain (cost modifiers)

---

### Turn System (85% — Beta)
✅ **Functional:**
- player → enemy sequence per turn
- AP economy
- EnemyPhaseController (structure exists)

✅ **Verified:**
- `EnemyPhaseController` calls `guard.choose_next_cell()`, `guard.move_to_cell_animated()`, and `guard.tick_state()` — all three exist on `GuardEnemy` (`godot/scripts/agents/guard_enemy.gd`)

---

### Enemy AI / Guard FSM (75% — Alpha, functional)

✅ **Functional:**
- `choose_next_cell()` is state-aware (PATROL → waypoint, SUSPICIOUS/ALERT/CHASE → agent, SEARCH → search queue)
- `tick_state()` timer-based de-escalation (ALERT→CHASE→SEARCH→SUSPICIOUS→PATROL)
- `observe_player()` escalates state when detection occurs
- `hear_noise()` with auditory thresholds (intensity ≥ 0.6 → SUSPICIOUS with last_known)
- Communication (whistle reaches 3 tiles, radio is global) — signals connected in `_spawn_guards`
- Excellent A* pathfinding
- `receive_alert()` with state hierarchy (never downgrades state)

⚠️ **Simplified vs. design intent:**
- Escalation is gradual and meter-driven: `turn_controller.gd::_apply_tic_result()` checks `guard.detection` against `DETECTION_THRESHOLD_SUSPICIOUS` (0.30), `DETECTION_THRESHOLD_ALERT` (0.60), and `DETECTION_THRESHOLD_CHASE` (1.00), calling `guard.observe_player(true, severity, ...)` with severity 1/2/3 respectively
- `move_to_cell_animated` is fire-and-forget: multiple guards' animations may overlap

---

### Detection / Stealth (70% — Alpha, functional with limitations)

✅ **Functional:**
- Probabilistic visual detection (cone + distance + LOS + shadows + posture + cover)
- `_apply_tic_result` accumulates `guard.detection` AND escalates state via `observe_player()`
- Auditory detection with attenuation by walls and distance
- Guards react to the agent (fleeing to shadows, crouching has a real effect)
- FOW hides unrevealed guards

⚠️ **Incomplete:**
- Visual escalation is gradual and meter-driven (see `turn_controller.gd::_apply_tic_result()`, thresholds 0.30/0.60/1.00) — the meter is the transition driver, not a debug overlay
- The distance curve has not been validated with playtesters

---

### Noise System — Math (80% — Beta)
✅ **Functional:**
- Persistent noise grid with per-turn decay
- ~20% emission per step
- Wall attenuation (0.6× per wall)
- Visualization (cyan circles)
- Direction indicators on guards
- **Guards react via `hear_noise()`** — auditory detection with a threshold (≥0.60 → SUSPICIOUS)

---

### Lighting & Shadows (Implemented — geometric projection + world-rendered)

✅ **Functional (Runtime) — VIS-01 shadow/lighting foundation:**
- **Geometric shadow projection** (`shadow_projector.gd`): per-object casting,
  length = object-height tier × light-height factor × distance, tip → penumbra
  (hybrid tiered + penumbra, deterministic — acceptance-tested)
- **Always-on world shadows**: geometric floor shadows render via the multiply-blend
  `_tile_shadow` under every vision mode — shadows are real-world elements, not debug-only
- **Map-driven lights** (`MapSpec.lights` + `light_tracks`): types omni / cone /
  directional, `height_class`, direction/cone, flicker — authored per map; normal
  lights snap to canonical "rails", special lights (sun / spot / fire) are free
- **Ceiling render**: lights drawn as overhead placeholders above the wall stack
- Multipliers applied to detection (SHADOW 0.30×, PENUMBRA 0.55×); exposure classes
  merged per-cell (lit wins over shadow)
- Perspective-coherent: shadows, lights, ceiling re-derive on rotation

✅ **Semantic Foundation (L-DOC Series — Completed 2026-06-14):**
- **L-DOC-01:** Lighting Taxonomy & Semantic Visibility Classes
  - 5 discrete visibility classes (FULL_LIT, DIM, PENUMBRA, SHADOW, DEEP_SHADOW)
  - Detection multiplier model (2.0× to 0.2×)
  - 7 light source types with behavior specifications
  - Separated tactical (gameplay) from visual (rendering)
- **L-DOC-02:** Vertical Lighting Topology & Height Semantics
  - 4 semantic vertical layers (L0–L3)
  - 5 discrete height classes for deterministic shadow casting
  - Shadow projection formula + 8-direction quantization
  - Shadow ownership matrix (walls cast, agents receive)
  - Runtime philosophy: grid-based, deterministic, low-overhead, gameplay-first
- **L-DOC-03:** Shadow System Calibration & Visual Polish (planned M2-14)

⚠️ **Next (tuning + occlusion):**
- Shadow tone/length tuning; per-prop heights (column TALL vs crate HUMAN)
- Lateral penumbra; multi-tile silhouette width; wall-edge floor shadows
- View occlusion (wall cutaway) — VIS-01 Slice 4
- Taller storeys for "5th-floor" verticality (pair with view occlusion)

✅ **Resolved:**
- Lights are no longer hardcoded — authored per map via `MapSpec` (omni/cone/
  directional, tracks + free special lights)
- Geometric projection (was M2-13 "next phase") is implemented and world-rendered

✅ **Voxel Face Lighting (VL-01..VL-D5, 2026-07-23→26) — the VISUAL half of the
canon above, full writeup in `PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md`:**
- Every voxel FACE (not just the floor) is painted to one of 12 discrete
  brightness buckets from lamp distance/height/facing + GU-level occlusion
  (`VoxelLightField` + `VoxelRenderer.apply_light_field()`), reusing the
  tactical shadow/exposure data above — canon split (brightness ≠ tactical
  visibility) preserved throughout
- Blast destruction reads visually: soot rings around holes, a contiguous
  radial floor crater (not a scatter), directional destruction bias toward
  the blast-facing side, under-wall floor darkening, a fading ember→char glow
  on freshly-blasted wood (`EmberOverlay`) — all material-agnostic except the
  ember seed condition
- Destruction (holes/soot) persists through perspective rotation via a
  base-coordinate registry, without prebuilding all 4 views (deferred to the
  project's finishing/optimization pass)
- Temporal lights (flicker/pulse) repaint only their own influence set
  (~75ms worst case) instead of the whole map (~590-675ms) — the mechanism
  behind both the flicker demo lamp and the wood ember effect
- Perspective rotation cost cut ~80% (~5.7s → ~1.15s off-screen throttled) via
  lazy alt-minting, a baked-source cache across rotations, and light-field
  caching — independent of the above, found while investigating flicker cost

---

### Fog of War (80% — Beta)
✅ **Functional:**
- 3 layers (unseen/peek/revealed)
- Revelation as the agent moves
- Guards hidden behind the FOW

⚠️ **Technical debt:**
- O(n²) algorithm — can be slow on large maps

---

### Perception — Calculation (60% — Alpha)
✅ **The calculation is correct:**
- Visual cone with angle, distance, and lateral falloff
- LOS verified via WallEdgeData
- Multipliers: posture, shadow, cover, flanking

🚨 **Not connected:**
- The calculation result is not used to change guard state

---

### Audio SFX (0% — Not Started)
Deliberately deprioritized. The math noise grid works; real SFX awaits post-demo.

---

### Animation / Sprites (0% — Not Started)
Movement tweening works adequately for the demo. Animated sprites await post-demo.

---

### UI & Presentation (30% — Prototype)
✅ **Implemented:**
- Movement overlay (Dijkstra)
- FOW overlay
- Turn indicator
- AP display
- Noise indicators

❌ **Not implemented:**
- Main menu
- Settings
- Tutorial
- Pause screen

---

### Narrative (0% — Not Started)
Intentionally deprioritized. Awaits post-investment.

---

### Content (15% — Prototype)
✅ **Implemented:**
- 1 test room
- 1 guard archetype
- 1 basic tileset

❌ **Not implemented:**
- Multiple rooms
- Guard variety
- Objectives
- Campaign content

---

## Infrastructure & Tooling (50% — Alpha)
✅ Godot 4.6, git, structured documentation
⚠️ No CI/CD, no automated tests, no analytics

---

## Path to Investor Demo

The game is already functional. Guards detect and react. For a convincing demo:

| Item | Effort | Impact |
|------|--------|--------|
| Connect the detection meter to the state thresholds | 1–2 weeks | High (game feel) |
| Tune the detection curve (distance, shadow, posture) | 3–5 days | High (fairness) |
| Polish the demo room (layout, interesting patrols) | 3–5 days | High (first impression) |
| Visual feedback of guard state (cone colors already change) | 1–2 days | Medium |
| Difficulty testing and tuning | 3–5 days | Medium |

**Total estimate for a convincing demo: 2–4 weeks of focused development.**

---

## Render System Status (updated 2026-06-28)

| Item | Status | Maturity |
|------|--------|----------|
| **Voxel render system** (bake + slices + junctions) | ✅ Implemented — the only wall renderer | Beta |
| **Direction system (vertex-aligned)** | ✅ Renamed RENAME-01 | Beta |
| **x/y-varying wall orientation fix** | ✅ Fixed RENAME-01b | Beta |
| **Corner fill (triangular gap cover)** | ✅ CONTAINER-04 complete | Alpha |
| **Dirty Flag + TIC updates** | ⏳ Planned CONTAINER-05 | — |
| **View occlusion (wall cutaway)** | 🔲 Planned VIS-01 Slice 4 | — |

---

## Code Modularization (ENHANCE-01..09 Complete)

**Status: Master Plan Complete** — Architecture refactored to improve maintainability and reduce monolithic room.gd.

### What was accomplished (ENHANCE series)

✅ **Task 00-01:** Residual Code & Documentation Purge
- Deleted 11 dead script files
- Removed 4 dead tileset subtiles
- Archived 7 outdated documentation locations

✅ **Task 02:** Error Handling & Quality Contract (ENHANCE-02)
- Systematic error handling: `push_error()` for critical paths, `push_warning()` for anomalies
- Converted 20 `printerr()` calls to `print_debug()`
- Implemented "validate-then-commit" pattern

✅ **Tasks 03-08:** Controller Extraction (7 modules)
1. **DebugToolsController** (~105 lines) — debug visualization
2. **PerspectiveMapper** (~67 lines) — coordinate transformations
3. **SelectionController** (~117 lines) — input routing
4. **WorldMarkersOverlayController** (~170 lines) — overlay management
5. **RoomBuilder** (~280 lines) — map construction
6. **TurnController** (~300+ lines) — turn phases + alert system
7. Architecture improvements to LightingController, VisionController, GuardCoordinator

✅ **Task 09:** Gate Verification & Final Documentation
- All systems validated (23 PASS selftest)
- ARCHITECTURE.md updated with new controllers
- Production-ready default configuration (Sigma-01 map, Wall Height 8)

### Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **room.gd lines** | 2,360 | 2,078 | -282 (-12%) |
| **New modules** | 0 | 7 controllers | +modular |
| **Lines extracted** | — | ~1,100+ | — |
| **Selftest** | 23 PASS | 23 PASS | ✅ maintained |
| **Inviolable Rules** | 8/8 | 8/8 | ✅ preserved |

### Key Improvements

- **Separation of Concerns:** Each controller owns one responsibility
- **Testability:** Extracted modules now unit-testable in isolation
- **Maintainability:** Clear module boundaries; reduced complexity
- **Modularity:** New levels and systems can reuse existing controllers

---

**Last Updated:** 2026-07-08
**Maintained By:** GitHub Copilot / Project Management
**Status:** ✅ ALPHA ENHANCE PLAN COMPLETE — 7 controllers extracted, room.gd refactored to 2,078 lines, all systems operational. Ready for perspective system implementation and further modularization.

> **2,078 lines is a point-in-time record of this milestone (2026-07-08),
> not a current figure.** Two more months of feature work (Voxel Light
> Foundation among others) grew `room.gd` to 2,896 lines as of 2026-07-26 —
> still the documented monolith (see `technical_debt.md`), not a regression
> from this refactor.
