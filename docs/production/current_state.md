# INFILTRAITOR — Current Project State

> **Executive snapshot of the entire project. Where we are right now — with honesty about what works and what does not.**

---

## Current Goal

**Primary target:** Investor Demo — functional, polished game mechanics in a single demo room.
Placeholder graphics, no audio, no narrative, no complex animations, no polished UI. The success criterion is *feeling*: stealth must be fun, guards must react believably, and the tension loop must be noticeable to anyone who plays for 5 minutes.

---

## Voxel Rendering System — Wall Architecture Refactor (VOXEL-01..04 Complete)

**Status: Partially Implemented (40% of planned work complete)**

The **Voxel Render Plane** replaces the legacy `WallContainer` + `Image.blend_rect` system with a native `TileMapLayer`-based architecture. The old approach suffered from cascading calibration dependencies; the new system is purely analytical — no empirical offsets.

### What works (VOXEL-01..04)

✅ **Geometry & Asset Generation (VOXEL-01)**
- Voxel PNG tiles regenerated with correct 3D isometric geometry (32×36 px, 3 visible faces: top + left + right)
- 4 materials supported: concrete, metal, stone, wood
- Diamond top face (bright), left/right side faces (darkened 80%)
- All tiles visually validated in Godot

✅ **Coordinate System & Constants (VOXEL-02)**
- Voxel constants registered in `SubcubeCoordsClass`: `VOXELS_PER_UNIT_AXIS=8`, `VOXEL_TILE_SIZE=Vector2i(32,16)`, `VOXEL_STEP_PX=20.0`
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

### What's pending (VOXEL-05..11)

⏳ **VOXEL-05** — Junction Detection + Extra Voxels
- Detect V-junctions (2 walls at vertex) and place junction_extras
- Populate `HighWall.junction_extras` array with gap-filling voxel positions
- Integrate into `_place_wall_voxels()` workflow

⏳ **VOXEL-06** — VoxelRegistry
- Centralized container for all WallSlice/HighWall instances
- Indexed lookup by edge key or wall direction
- Iteration API for TIC loop and baking pipelines

⏳ **VOXEL-07** — Dirty Flag + TIC Loop
- Per-voxel `dirty: bool` flag; dirty_count propagation up container hierarchy
- TIC loop processes dirty containers only — O(container_count) cost at idle
- Runtime destructibility via `ref.visible = false` + `erase_cell()`

⏳ **VOXEL-08..09** — Baking System
- VOXEL-08: Primary baking per WallSlice (Crop + Multiply from TextureCatalog)
- VOXEL-09: Secondary baking per HighWall (single large texture spanning all constituent voxels)
- Result: `VoxelRef.face_atlas_rect` populated; rendering path unchanged

⏳ **VOXEL-10** — Destructibility
- Damage states: `INTACT=0`, `CRACKED=1`, `DESTROYED=2`
- Overlay texture + visibility logic
- Integration with TIC loop and dirty flags

⏳ **VOXEL-11** — CODEMAP Update
- Register all voxel wall data in project codemap
- Enable runtime queries (e.g., "which walls can this agent see?")

### Technical Notes

- **Coordinate planes:** Gameplay plane (256×128 px, guards/AI unchanged) + Voxel render plane (32×16 px, 8×8 per GU)
- **No legacy offsets:** `FACE_CENTER_OFFSET`, `SUBCUBE_FACE_OFFSETS`, `is_x_varying`, `blend_rect` all archived
- **Preservation:** All subcube infrastructure, wall edge data, and map compiler contract remain unchanged
- **Godot status:** Loads clean; no parse errors or warnings; voxel rendering visually validated

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

⚠️ **Problem:**
- EnemyPhaseController calls non-existent methods on the guards — the enemy phase fails silently

---

### Enemy AI / Guard FSM (65% — Alpha, functional)

✅ **Functional:**
- `choose_next_cell()` is state-aware (PATROL → waypoint, SUSPICIOUS/ALERT/CHASE → agent, SEARCH → search queue)
- `tick_state()` timer-based de-escalation (ALERT→CHASE→SEARCH→SUSPICIOUS→PATROL)
- `observe_player()` escalates state when detection occurs
- `hear_noise()` with auditory thresholds (intensity ≥ 0.6 → SUSPICIOUS with last_known)
- Communication (whistle reaches 3 tiles, radio is global) — signals connected in `_spawn_guards`
- Excellent A* pathfinding
- `receive_alert()` with state hierarchy (never downgrades state)

⚠️ **Simplified vs. design intent:**
- Binary visual detection: any successful tic → immediate `STATE_ALERT`
- The detection meter accumulates visually but does not drive transitions (debug feedback only)
- No intermediate SUSPICIOUS for visual detection (only via audio/communication)
- `move_to_cell_animated` is fire-and-forget: multiple guards' animations may overlap

---

### Detection / Stealth (55% — Alpha, functional with limitations)

✅ **Functional:**
- Probabilistic visual detection (cone + distance + LOS + shadows + posture + cover)
- `_apply_tic_result` accumulates `guard.detection` AND escalates state via `observe_player()`
- Auditory detection with attenuation by walls and distance
- Guards react to the agent (fleeing to shadows, crouching has a real effect)
- FOW hides unrevealed guards

⚠️ **Incomplete:**
- Visual escalation is binary (detection → ALERT directly, no gradation)
- The `guard.detection` meter does not drive transitions (visual debug only)
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
| **Subcube Container system** | ✅ Implemented (wall faces + corner fills) | Alpha→Beta |
| **Direction system (vertex-aligned)** | ✅ Renamed RENAME-01 | Beta |
| **x/y-varying wall orientation fix** | ✅ Fixed RENAME-01b | Beta |
| **Corner fill (triangular gap cover)** | ✅ CONTAINER-04 complete | Alpha |
| **Dirty Flag + TIC updates** | ⏳ Planned CONTAINER-05 | — |
| **View occlusion (wall cutaway)** | 🔲 Planned VIS-01 Slice 4 | — |

---

**Last Updated:** 2026-06-28
**Maintained By:** Project Management
**Status:** ✅ FUNCTIONAL CONTAINER SYSTEM — Wall rendering via discrete per-face Images + corner fills; direction system vertex-aligned; ready for live geometry updates (CONTAINER-05)
