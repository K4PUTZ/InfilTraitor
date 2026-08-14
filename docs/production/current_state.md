# INFILTRAITOR — Current Project State

<!-- AUTO:BEGIN header -->
**Version:** 0.9.101 · **Updated:** 2026-08-14 · **Branch:** main
<!-- AUTO:END header -->

> **Executive snapshot of the entire project. Where we are right now — with honesty about what works and what does not.**

---

## Project Status

### Pending Prompts

<!-- AUTO:BEGIN pending_prompts -->
- D33_RUNTIME_DECAL_COMPOSITING.md
- ENGINE_PERFORMANCE_REVIEW.md
- INVESTIGACAO_EXPLOSAO_2026-08-04.md
- PLANO_PRE_FABRICATED_DAMAGE_VARIANTS.md
- RESUMO_SESSAO_2026-07-26_TEMPORAL_LIGHT_FOUNDATION.md
- RESUMO_SESSAO_2026-07-28_FLOOR_ZONE_BAKE.md
- RESUMO_SESSAO_2026-07-28_SHOTGUN_SHADOW.md
- RESUMO_SESSAO_2026-07-29_FLOOR_DEPTH_NEON_COLLECTIBLE.md
- RESUMO_SESSAO_2026-07-29_WEAPONS_BENCH_ARSENAL.md
- RESUMO_SESSAO_2026-07-30_31_DESTRUCTION_VISUALS.md
- RESUMO_SESSAO_2026-08-01_FACE_LIGHT_FOUNDATION.md
- RESUMO_SESSAO_2026-08-02_DAMAGE_DECALS.md
- RESUMO_SESSAO_2026-08-02_FACE_SOOT.md
- RESUMO_SESSAO_2026-08-02_FIREARM_DESTRUCTION.md
- RESUMO_SESSAO_2026-08-03_D33_SPIKE.md
- RESUMO_SESSAO_2026-08-04_GENERIC_DECALS.md
- RESUMO_SESSAO_2026-08-04_PERF02.md
- RESUMO_SESSAO_2026-08-04_VFX01_DETONATION_PERFORMANCE.md
- RESUMO_SESSAO_2026-08-05_EXPLOSION_REBUILD_PLAN.md
- RESUMO_SESSAO_2026-08-05_EXPLOSION_RESET.md
- RESUMO_SESSAO_2026-08-06_AUDIT_TASK0_MATERIAL_REFORM.md
- RESUMO_SESSAO_2026-08-06_EXPLOSION_REBUILD_ANSWERS.md
- RESUMO_SESSAO_2026-08-06_E_BAKE_TASK1B.md
- RESUMO_SESSAO_2026-08-06_E_MAT_TASK1A.md
- RESUMO_SESSAO_2026-08-07_E_PLAN_TASK4.md
- RESUMO_SESSAO_2026-08-07_E_RING_TASK2.md
- RESUMO_SESSAO_2026-08-07_E_SOOT_TASK3.md
- RESUMO_SESSAO_2026-08-07_E_WAVE_TASK5.md
- RESUMO_SESSAO_2026-08-07_POST_TASK5_SOOT_DIAG.md
- RESUMO_SESSAO_2026-08-08_09_EXPLOSION_WAVES.md
- RESUMO_SESSAO_2026-08-08_E_EARTH_D35.md
- RESUMO_SESSAO_2026-08-08_E_SEAM_D34.md
- RESUMO_SESSAO_2026-08-08_GPU_FLUSH_AND_SOOT_REVERSAL.md
- RESUMO_SESSAO_2026-08-09_EXPLOSION_FLOW.md
- RESUMO_SESSAO_2026-08-10_11_BUBBLE_FOUNDATION.md
- RESUMO_SESSAO_2026-08-10_GRENADE_SHRAPNEL_PLAN.md
- RESUMO_SESSAO_2026-08-10_SHRAPNEL_IMPLEMENTATION.md
- RESUMO_SESSAO_2026-08-11_GRENADE_SHADOW_ROLL.md
- RESUMO_SESSAO_2026-08-12_13_BUBBLE_WARM_SOOT.md
- RESUMO_SESSAO_2026-08-12_WALL_GRID_AND_SHRAPNEL_FIX.md
- RESUMO_SESSAO_2026-08-13_DOC_AUDIT_EMBER.md
- RESUMO_SESSAO_2026-08-13_EXPLOSION_REFINEMENT.md
- RESUMO_SESSAO_2026-08-13_E_CONTRAST_FLOOR_SHADE.md
- RESUMO_SESSAO_2026-08-13_FIREARM_DEFER_AIM_MODE.md
- RESUMO_SESSAO_2026-08-14_CHARACTER_PERSONA_AND_PART0.md
<!-- AUTO:END pending_prompts -->

### Inventory

<!-- AUTO:BEGIN inventory -->
**Code & Test Inventory**

- GDScript modules: 148
- Test scripts: 43
- Known maps: 3
- Shipped facade files: 0
- Archived prompts: 17
<!-- AUTO:END inventory -->

### Version History

<!-- AUTO:BEGIN version_history -->
- 1d20aa34 ALPHA EMBER TUNING 0.9.101 - E-EMBER-03 fast yellow-to-red ramp, doc sweep
- 767bc60f [DOCS] Session close 0.9.100 — E-CONTRAST-01/02/03 swept
- 01c41e0e ALPHA EXPLOSION REFINEMENT 0.9.99 - choreographer/z-index/junction fixes, doc sweep
- 0dc11df2 [DOCS] Session close 0.9.98 — sectioned dome, P-WARM, and the soot reform
- a1bc94ac [DOCS] Session close 0.9.97 — wall-grid attempt/pullback + E-FRAG fix swept
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
| **Voxel Rendering System** | Functional — the only wall renderer | Beta | 85% |

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

ℹ️ **How escalation actually works** (this is the shipped design, not a gap):
gradual and meter-driven — see `turn_controller.gd::_apply_tic_result()`,
thresholds 0.30/0.60/1.00. The meter is the transition driver, not a debug
overlay.

⚠️ **Incomplete:**
- The distance curve has not been validated with playtesters
- Detection tops out at CHASE. The confrontation phase the design calls for
  at 100% ([`DESIGN_MASTER_PLAN.md`](../DESIGN_MASTER_PLAN.md) §8 — cover
  states, peek, flanking, smoke as pivot) does not exist

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
  on freshly-blasted combustible material (`EmberOverlay`) — all
  material-agnostic except the ember seed condition, which now reads the
  material table's `flammability` column instead of hardcoding wood
  (**the ember was dead code 2026-08-05 → 2026-08-13** while this line claimed
  otherwise; see E-EMBER-01 under Explosive Destruction below)
- Destruction (holes/soot) persists through perspective rotation via a
  base-coordinate registry, without prebuilding all 4 views (deferred to the
  project's finishing/optimization pass)
- Temporal lights (flicker/pulse) repaint only their own influence set
  (~75ms worst case) instead of the whole map (~590-675ms) — the mechanism
  behind the flicker demo lamp (the ember effect is a screen-space overlay and
  never used this path — see `EmberOverlay`'s own header on why a light bucket
  structurally cannot carry one voxel's time-varying colour)
- Perspective rotation cost cut ~80% (~5.7s → ~1.15s off-screen throttled) via
  lazy alt-minting, a baked-source cache across rotations, and light-field
  caching — independent of the above, found while investigating flicker cost

✅ **Firearm Destruction (D30/D31, 2026-08-02) — "Alpha Firearm Destruction",
full writeup in `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` D30/D31 and
`WEAPON_MASTER_PLAN.md` Part 3b:**
- **3 of 4 delivery shapes now real** — `RADIAL`, `CONE` and `LINE`
  (`NONE` is by definition no-op). `LINE` was the last unbuilt one: five
  rifled weapons declared it and loud-failed since D11, and now fire
  (`BlastCalculator.select_line_impact()`)
- **One readable destruction coefficient**, `punch`, replaces the old
  three-way probability roll: weapon × agent skill × distance × luck ÷
  material resistance, every factor centred on 1.0, printed on the `[SHOT]`
  line, all tunables in `shot_punch_table.gd`. Ladder runs CRACKED → DENTED
  → DESTROYED plus 0–8 neighbours; a stray shot always leaves at least a mark
- **Neighbours are destroyed but never marked** — a heavy round opens one
  contiguous breach instead of a spray of separate round holes, which is the
  invariant D28 was written to protect. Neighbour cascade into the wall's
  second layer is reserved for a future heavy weapon (threshold pinned above
  the shipped arsenal's measured worst case by a selftest that reads the real
  weapon JSONs)
- **The shotgun's spread is a disc that widens with range**, not a horizontal
  line — pellets sample the unit disc and carry a vertical axis that did not
  previously exist. Range is deliberately uncapped: a pellet that clears the
  near wall keeps travelling
- ❌ **Damage does NOT fall off with distance yet** — deliberately neutral for
  both shapes (D30-CAL); moved to the COMBAT work at the Director's call
- ❌ **No actor carries a skill stat** — `_agent_skill()` returns neutral 1.0
  and is the single seam for when one exists

---

### Explosive Destruction (85% — Alpha; **both master plans CLOSED 2026-08-13**, Phase A + B built, VFX foundation complete)

> **~~NEXT SESSION (Director-scheduled):~~ SUPERSEDED 2026-08-13 — W-PRECOOK
> DEFERRED, and the character is now the active work.** The banner below was
> written the morning of 2026-08-13 and overtaken the same day.
>
> **Firearm pre-production (W-PRECOOK) is deferred to the LAST ITEM OF GAME-01**,
> the combat milestone (`docs/production/milestones.md`). Nothing about the
> problem changed — a shot still costs ~310 ms of synchronous CPU for nine
> voxels — but the window it exists to fill is the *aiming* window, and there is
> no aim mode, no shooter and no agent holding a weapon to build it against.
> Director: *"quando o personagem já existir e conseguir empunhar as armas. Pra
> não ficar testando com mecanismos visuais teóricos"*, then, on the placement:
> *"pode colocar o W-PRECOOK mais cedo, vamos fazer ele no final da milestone de
> combate."*
>
> **In its place, aim mode is DESIGNED and unbuilt** — weapon selection on 1/2/3
> over an open carried arsenal, `S` to aim, every valid target cyclable with a
> visible hit percentage, the current target pre-resolved immediately, and a
> second input to fire. `WEAPON_MASTER_PLAN` §5c + D30–D38;
> `DESIGN_MASTER_PLAN` §8.7. **`DESIGN_MASTER_PLAN` §10.2's one-weapon-per-
> mission loadout rule is superseded** (D37) — the agent carries everything for
> now, and restricting it later is an open design lever.
>
> **The active work is the CHARACTER** — `ACTOR_MASTER_PLAN`'s living-beings
> track, deferral lifted by the Director 2026-08-13. Design conversation open,
> plan not yet written.
>
> **Off the agent's list:** the Baking System cache check — the Director runs it
> himself by swapping texture files in the folders. A separate formal pass
> (cache invalidation + decal recompositing against the shipping art) is
> scheduled as the **last optimization stage**, M7.0.
>
> *Original banner, kept:* firearm pre-production (W-PRECOOK) — a shot's entire
> cost is `_repaint_voxel_light_buckets()`, ~310 ms of synchronous CPU for nine
> voxels, against 0.5 ms for a 453-voxel blast that pre-computes during the
> throw. Full measurement and the two candidate routes: `WEAPON_MASTER_PLAN` §0.

✅ **A grenade detonates as ONE ORGANIC EVENT, and it no longer freezes the
camera** — right-click "Detonar" on a TEST-ZONE grenade runs the whole pipeline:
the damage is COMPUTED the moment the target is picked, then a burst built from
this game's own overlays, camera shake, a 4-frame white/negative strobe, and an
**expanding front** of per-voxel effects that ends at the widest circle.
Firearm destruction (above) is untouched and still works exactly as before.

✅ **0.9.94 "Alpha Explosion Flow" (2026-08-09)** — the session that made the
blast *flow*. Full record:
[`RESUMO_SESSAO_2026-08-09_EXPLOSION_FLOW.md`](../../PROMPTS/RESUMO_SESSAO_2026-08-09_EXPLOSION_FLOW.md).
- **The blast stopped being three frames.** `cells_due_now()`'s wall-clock
  deadline meant one slow frame made the next frame's quota the entire queue —
  measured, **2 057 of 2 185 steps on one frame**. That is why the radial front
  shipped two days earlier never read as a wave. Pacing is by FRAME COUNT now,
  snapped to visible bands; no wall-clock term survives in that path. **The
  Director's "ondas na água" needed no new feature.**
- **The detonation is three beats** (P-STROBE) — fire alone, then a 4-frame
  white/negative/white/negative strobe with the fire still burning under it, then
  the destruction clean. The timed fade was **deleted, not shortened**: a
  frame-driven strobe cannot express the E-FLASH-03 bug (a 150 ms frame burning
  half the fade curve in one step) by construction.
- **A complete PREDICTION layer**
  ([`PREDICTION_MASTER_PLAN`](../../PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md),
  all six tasks). `build_plan()` is **pure** — it returns a `WorldDelta`
  describing what a grenade *would* do, and `delta.commit()` is the only writer.
  The pipeline is an 11-phase resumable, cancellable state machine; predictions
  are cached on `(signature, world_revision)` and start when the player picks a
  target. **In the harness's harshest case the grenade cooks 16 frames (~0.27 s)
  with zero frozen frames.**
- **`tools/persistent/build_filmstrip.py`** puts every frame of ONE detonation on
  one contact sheet — three of the session's look calls were made from it,
  including one bloom direction that was simply wrong (the fire spread sideways
  because the burst was modelled as one squashed 2D circle; ground and altitude
  are different axes in isometric).
- ⚠️ **Two gates recorded as SHORT rather than declared met:** §4.4's 4 ms
  per-frame budget (worst unsuspendable visit 7–9 ms — the soot BFS and one large
  wall slice, both atomic by construction) and the total build cost (~192 ms vs a
  pre-refactor 178 ms — what purity costs). Neither freezes a frame.
- ⚠️ **The plan's own opening phase table was wrong**, and every decision in it
  had been reasoned from that table: the soot BFS is 10 ms not 66, the light
  field 0.1 ms not 35, and the map-wide voxel walk — never a separate phase — is
  66% of the cost. Corrected in §8.8.
- ⚠️ **Deliberately un-tuned:** the fire/flash/destruction timing. The Director's
  call — *"a gente só vai conseguir fazer o fine tuning da fluidez quando todo o
  mecanismo estiver bem estabelecido."* That pass is the next work.

✅ **0.9.93 "Alpha Explosion Waves" (2026-08-08/09)** — eight passes that took
the blast from "the waves fire" to something that reads right. Full record:
[`RESUMO_SESSAO_2026-08-08_09_EXPLOSION_WAVES.md`](../../PROMPTS/RESUMO_SESSAO_2026-08-08_09_EXPLOSION_WAVES.md).
- **The floor finally CRACKS** (E-CRACK-01). `apply_crater_damage()` had no
  crack roll at all, so `FLOOR/cracked` measured **0 on every material on every
  blast** — D19's "floors crack like walls" was closed in the data and never in
  the code. Found by a new per-(surface, material) `[E-PLAN]` census, which the
  old blended per-wave counts could not have shown.
- **The fixed 15-wave table is retired** (E-ORGANIC-01, E-RADIAL-01). The plan
  flattens into one queue of single-cell steps ordered by **radius from the
  epicentre**, paced against a deadline with catch-up. Categories interleave by
  where they physically are instead of arriving in per-category blocks —
  **171 category switches against ~15** before.
- **Smoke is per damaged voxel** (E-SMOKE-01) — 22 puffs → **465**, each one's
  intensity and lifetime from its damage tier, its ring, and a per-cell hash.
- **The imported fireball is gone** (E-NATIVE-01). Three rounds of tuning an
  authored sprite never fixed a style mismatch; the blast's core is now
  `Room.spawn_blast_burst()` — embers, sparks and dust from overlays that
  already existed.
- **The soot stamp is DELETED** (S-KILL-STAMP, 2026-08-12). It had been off at
  the live caller since E-DENT-01; shown to the Director in a three-way A/B/C it
  was rejected outright — it stamps once per CONTAINER, i.e. once per GU, so a
  hard GU boundary is the shape of the mechanism, not a tuning error. 346 lines
  out at **0 differing pixels**, which is the gate that proves a dormant deletion
  really was inert. `BombDef.soot_ring_tones` is parsed and ignored.
- Two measurements worth carrying: the sequence's cost is **per frame that
  writes to a TileMapLayer, not per cell** (a naive per-frame budget made the
  blast 3–20× slower while every log number improved), and the "engasgada" the
  Director kept feeling was a **150 ms frame**, not the flash.
- ✅ **The blast's playback stopped computing** (P-WARM, 2026-08-12). Queue
  flattening, tile-alternative minting and the composite page upload all
  survived past the prediction into the blast's own frames — **753 ms across 5
  wave frames**. Moved into the throw window they cost **84 ms**, at 0 differing
  pixels. The cause was NOT the big floor layer it looked like:
  `create_alternative_tile()` mutates the TileSet every layer SHARES, so one new
  alternative rebuilds the lot. `INFILTRAITOR_THROW_PROFILE=1` is the new seam,
  reporting a whole throw in ms AND frames.
- ✅ **Soot is one mechanism again** (`SOOT_MASTER_PLAN`, five tasks,
  2026-08-12/13): the sequence lives only in `BlastCalculator.build_soot_field()`
  now, shared by the detonation and the repaint, which had already drifted apart
  in three measurable ways. Plus a faint directional feather past the graded
  rings, soot on the voxels a blast reveals (they used to come up pristine inside
  a blackened crater), and a four-rung fade-in.
- ✅ **Dents and cracks are no longer re-gated by ring** (E-ORGANIC-02):
  `WAVE_TABLE`'s hardcoded pairs were a second gate on what the bomb's JSON
  already decides, and 18 ring-2 dents were planned and silently dropped on every
  blast.
- ✅ **The embers and the wood smoke are back** (E-EMBER-01 / E-SMOKE-TINT-01,
  2026-08-13, `EXPLOSION_REBUILD_MASTER_PLAN` §11b). Found by the Director's own
  doc-vs-code review: VL-D4's per-voxel ember→char glow had been **dead code
  since the 2026-08-05 `[RESET]`** — deleted with the destruction trigger, not
  restored when Task 5 reconnected it — while three documents, this one
  included, described it as shipped. Nothing had recorded it as a gap. Both
  effects needed the same missing thing (the plan's entries carried no
  material), and neither was fixed by reconnecting VFX-01's dispatch, which
  would double every puff against the staged smoke waves. The ember is now a
  real `ember` wave played inside the expanding front, gated on a new
  **`flammability` column in the material table** rather than a hardcoded wood
  check — today only wood is combustible; cardboard, fabric and light wood are
  the materials milestone. Real PLAYGROUND detonation: **290 embers** against
  `FLOOR/wood destroyed 137` + `WALL/wood destroyed 38`
  (`e_ember01_wood_embers_settled_2026-08-13.png`).
- ✅ **The ember became a fire that cools** (E-EMBER-02, same day). The Director
  diagnosed why the previous step was invisible: the fireball and the
  per-voxel embers share one overlay and one z_index, and at 46 px/s the fire
  climbed under two voxel steps in its whole life — it sat on the crater
  covering the thing it was meant to reveal. Fixed by raising the fire's
  buoyancy to 150 px/s (with per-ember jitter), **not** by shortening it, which
  would have broken P-STROBE. Plus: a yellow-hot → deep-red cooling ramp per
  ember; an upward creep that climbs one level at a time and stops at the first
  level that does not catch (FNV-1a per cell, never `randf()`, since it runs
  inside the pure `build_plan()`); and a darker, ember-sized puff on extinguish.
  **The first filmstrip rejected the first attempt** — every seed igniting on
  the same frame at the same hot tone made ~137 ADD circles sum into one molten
  sheet; fixed by cutting perceived density (radius, halo, value) and staggering
  the ignitions, not by cutting the count. Evidence in three parts:
  `e_ember02_filmstrip_wood_2026-08-13.png` (ignition, ~0.6 s — a 36-frame strip
  structurally cannot reach the cooling), plus stills at ~2 s and ~4 s
  (`e_ember02_wood_cooling_120f/240f_2026-08-13.png`).
- ✅ **0.9.101 "Alpha Ember Tuning" (E-EMBER-03)** — the colour ramps were linear
  in `t`, so an ember drifted through orange for its whole life and the vivid red
  never had a stretch of its own. Hue and brightness are now eased in OPPOSITE
  directions (hue exponent 0.40 reaches red early, value exponent 1.80 holds
  brightness and then drops), so the yellow is a flash and the red arrives fast
  AND bright. Easing the hue alone would have produced a red that was already dim
  on arrival. `e_ember03_vivid_red_70f_2026-08-13.png`.
- ⚠️ **Open:** the crack decal art barely survives the downsample to a voxel
  face — a faint tonal patch rather than a fracture. Art, not wiring.
- ✅ **The muzzle sequence reads** (E-SPARK-03 / E-MUZZLE-02, 2026-08-13).
  Sparks no longer fall (`spark_gravity` 260 → **0** — the Director's read is a
  radial burst that dies where it flew, and any gravity bends it into a
  fountain); the flash lives 0.30 s instead of 0.17; powder smoke is pale, aimed
  forward, barely rises and is gone quickly (`drift_scale`/`duration_scale`
  per-puff overrides, so no blast puff on the map moves). **The black hole in
  the middle of the flash was misdiagnosed twice**: it was never the muzzle's own
  pale smoke but the dark burn-out puff `EmberOverlay` hands over when ANY ember
  dies — correct for a coal, wrong for a flash whose eight big embers each
  dropped one. Chased through two spatial fixes and a delay on the wrong smoke
  before a +9-frame capture showed the blob was brown, not grey.
  `smoke_on_death` closes it. `e_muzzle02_flash_sequence_2026-08-13.png`.
- ✅ **Sparks, dust and a muzzle flash** (E-SPARK-02 / E-DUST-01 / E-MUZZLE-01,
  2026-08-13). Sparks: more, faster, ~2× the lifetime, and a **tapered fading
  trail** whose length follows the particle's own speed. Per-material ladder set
  by the Director — metal a lot, stone medium, concrete a little, wood none —
  applied to firearms AND blast debris. **Dust was invisible by construction,
  not too faint**: it waited 0.9–1.1 s before falling, ramped alpha `0→1` while
  falling (so it faded IN from nothing exactly while it moved), and drew 3–5
  specks at 1.6 px. Delay shortened, fade-in deleted, specks bigger and more
  numerous. **Muzzle flash + powder smoke** at the barrel, built from the
  project's own overlays per E-NATIVE-01 rather than from the authored sprite
  sheets the Director shared as reference — `Room.spawn_muzzle_flash()` takes a
  point and a direction, so an agent holding a rifle needs no new code. Two
  measured mistakes on the way, both fixed and recorded: the flash inherited the
  ember cooling ramp and photographed as a small RED fireball (`cool_rate` 0.0
  now pins it hot — a flash does not cool, it ends), and the powder smoke drew
  a dark disc straight over the core because SmokeSparkOverlay sits one z-index
  above EmberOverlay. `e_muzzle01_zoom_muzzle_and_impact_2026-08-13.png`.
- ✅ **A hit that does NOT destroy now throws VFX too** (E-SPARK-01,
  2026-08-13). Director-reported: *"o metal deveria gerar bastante faísca num
  tiro da shotgun."* It generated none — and neither did stone. Cause, measured
  from real `[SHOT]` lines: `_dispatch_destruction_vfx()` runs off the
  `voxel_destroyed` signal, and a shotgun on metal (punch 0.29–0.39) or stone
  (0.42–0.53) never crosses D30's DESTROYED threshold, so those two produced
  **nothing at all** while wood (0.78–1.06) got the full dispatch — the exact
  inverse of the intent. Same structural gap D33-SOOT-01 closed for soot with
  `apply_self_soot()`. `Room.dispatch_impact_vfx()` + a per-material
  `vfx_impact_profiles` table now serve the survivors: metal trades smoke for a
  dense spark burst, stone fewer sparks plus dust, concrete dust and light
  smoke, wood splinters and dark smoke.
  `e_spark01_shotgun_metal_sparks_2026-08-13.png`.
- ✅ **Dust, sparks and chips reach explosions** (E-DEBRIS-01) — the last piece
  of VFX-01, and the gap the master plan had flagged since 2026-08-07 with an
  explicit "ask first". A `debris` wave on the plan, not a reconnected
  `voxel_destroyed` dispatch (which would double every smoke puff). The blast
  rates are ONE documented fraction of the firearm rates
  (`blast_debris_rate_scale` 0.25) because those chances are per destroyed voxel
  and a shot destroys a handful where a grenade destroys 243–500 — a unit error,
  not a taste call. Real captures, one per material family: wood
  `chips=23 dust=13`, stone `dust=21 sparks=34`, metal `sparks=28`.
  `e_debris01_filmstrip_stone_2026-08-13.png`.

✅ **Tasks 0–5 of the rebuild are done — Phase A is functionally complete**
([`EXPLOSION_REBUILD_MASTER_PLAN`](../../PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md),
🟢 BUILDING, updated 2026-08-07):
- **Task 0** (2026-08-06) measured the bake-cost gate: ~737 ms for the
  atom set against a ~2 s ceiling — 2.7× headroom, no escape hatch needed.
- **Task 1a (E-MAT)** — one surface-independent material table
  (`res://materials/*.json`), `ground_* → slab_*`/`facade_*` texture split
  (D19/D20/D21). Commit `95d83cb`. **That split was later collapsed by D34**
  — see the D34 bullet below; only organic ground still resolves `slab_*`.
- **Task 1b (E-BAKE)** — the real load-time damage-atom pre-bake:
  **273 real atoms** on PLAYGROUND (not the projected 207 — bullet marks
  and ceiling-dented art turned out larger in scope), cache-verified
  (1498 ms → 31 ms on a second load). `apply_damage_voxel_swap()` resolves
  through it for real wall voxels — **firearm bullet marks already consume
  this pre-bake automatically**, a zero-code side effect of this task, not
  a separate rewiring. Commit `2d18a9e`.
- **Task 2 (E-RING)** — the ring/falloff calculation surface:
  `apply_container_damage()`'s vertical-ring step is spherical
  (`absi(level_offset) / LEVELS_PER_STOREY`, D14 — one ring step per 8
  voxels in every direction, `VOXELS_PER_UNIT_AXIS == LEVELS_PER_STOREY == 8`
  by construction) for wall **and** roof alike; per-tier
  destroy/dent/crack ring weights; `apply_crater_damage()` (floor) gained
  `deep_layer_unlocked` (D2, the two-layer floor rule) and
  `slab_pierce_multiplier` (D17). D16's blast-side atom routing needed zero
  calculation changes — a render-side fix in `apply_damage_voxel_swap()`
  routes a roof struck from above through the floor atom pool. Commit
  `a3f58ee`.
- **Task 3 (E-SOOT)** — ⛔ **superseded 2026-08-13 by `SOOT_MASTER_PLAN`; the
  stamp described here is deleted.** Blast-stamped soot
  (`stamp_container_soot()`/`stamp_crater_soot()`) closed the gap that ring 3
  (which destroys nothing) could never get soot from hole-derivation alone. A real design
  tension was raised and resolved with the Director this session: soot
  stays **fully per-face directional** everywhere (FACE-SOOT-01 and
  self-soot untouched) rather than collapsing to one tone per voxel, since
  the processing-cost reason for that collapse no longer applies now that
  explosions are pre-baked, not live-composited. Commit `fdcb5e9`.
- **Task 4 (E-PLAN)** — `DetonationPlanBuilder.build_plan()` resolves an
  entire detonation up front (real resolution, whole-map soot merge, one
  `VoxelLightField` query) into a `DetonationPlan`, proven never to touch
  the live TileMapLayer (a real before/after snapshot over 108,576 placed
  cells, byte-identical). Required a resolve-only seam on
  `VoxelRenderer._set_voxel_cell()`/`apply_damage_voxel_swap()` (trailing
  `apply` param, every existing caller byte-for-byte unaffected). Commit
  `ddbe7dd`.
- **Task 5 (E-WAVE)** — `DetonationChoreographer` plays the plan back and
  `TestZoneController.detonate_active()` is reconnected end to end. As shipped
  this was 15 fixed waves on independent `SceneTreeTimer`s at 40 ms; **both the
  table and the timers were retired on 2026-08-09** (E-ORGANIC-01/E-RADIAL-01,
  above) in favour of a radially-ordered queue paced against a deadline. Real bug caught by the capture itself: a `SceneTreeTimer`'s signal
  connection alone did not keep the (RefCounted) choreographer alive long
  enough — fixed with an explicit owner reference. Commit `98e9772`.
- **Upper storeys are not playable** (D18) — a roof hole is a **lighting**
  event, never an access route.
- **Phase B "Alpha Bubble Foundation" (2026-08-10/11, 0.9.96)** — the grenade
  aiming UI, built and running end to end: **G → aim → tap or Enter → arc →
  bounce → cook → detonation**. Full record:
  [`RESUMO_SESSAO_2026-08-10_11_BUBBLE_FOUNDATION.md`](../../PROMPTS/RESUMO_SESSAO_2026-08-10_11_BUBBLE_FOUNDATION.md);
  plan and open items:
  [`TARGETING_MASTER_PLAN`](../../PROMPTS/PLANNING/TARGETING_MASTER_PLAN.md).
  - **It did not run when the session opened.** The previous pass reported the
    feature complete and `34/34 selftests clean`; an audit found the throw
    aborted on its first frame (`SceneTree.get_physics_frame()` does not exist
    in Godot 4.6), ESC opened the Main Menu instead of cancelling, Enter was
    consumed before GUI input and had killed the context menu's focused button
    *and* the `test_zone_detonate` capture, the bubble was sized from the throw
    range rather than the blast, and the throw used the RAW hovered cell while
    the preview showed a clamped one. All reproduced before being fixed.
  - **`IsoProjection` is the one analytic home** for "a shape in GAME UNITS
    drawn on the isometric plane", and its basis is MEASURED against
    `tileset_blocks.tres` rather than reasoned from Godot's layout enum —
    `iso_projection_selftest.gd` asserts it there, since a self-comparison
    would pass whatever the constants said. Zero off-diagonal ⇒ every ellipse
    is screen-axis-aligned; a floor circle is exactly 2:1 at (181.02, 90.51)
    px/GU; a sphere is (181.02, 183.83) — very nearly a circle; and normalised
    radius equals `(grid distance / R)²` in every direction, which is what lets
    any radius here mean a real number of cells.
  - **Dome** — a 2 GU hemisphere (sphere ellipse closed underneath by the floor
    section, sharing a horizontal semi-axis so the seam is exact), orange.
    At exactly 2.0 the rim passes through the cells two out: the spill past the
    3×3 block is the message, not a rounding. **Deliberately not** the predicted
    footprint — the Director ruled out showing the silhouette with its holes.
  - **Shrapnel rays** — LightRayOverlay's mechanism pointed at a grenade.
    Directions come from the SAME wall-aware BFS the real blast floods with, so
    a cell behind a wall gets no ray; endpoints land on an ellipse so lengths
    are even; plus a lifted origin, ground braking on the downward ones, and a
    deterministic jitter (random would re-roll every hover and crawl).
  - **Virtual grenade cursor** — `GrenadeProp`'s real baked frames under
    `virtual_grenade.gdshader` (50% red overlay, 2 px stroke, 2 px diagonal
    hatch), replacing the magenta selection diamond while aiming. One place
    knows where grenade art lives, so the second explosive type inherits it.
  - **Throw** — a real ballistic arc that accounts for the grenade leaving the
    hand ABOVE the floor it lands on (apex at t ≈ 0.455, the fall the longer
    half); a flight tumble, a landing hop, and a 1 s cook, all driven by ONE
    continuous angular velocity from release to rest.
  - **Player vs. developer** — both red diagnostics (throw perimeter, damage
    footprint) are dev-vision-only. The player's HUD shows the dome, the rays,
    the virtual grenade and the arc. `dev_vision` defaults TRUE in this build,
    so `INFILTRAITOR_CAPTURE_NO_DEV=1` exists to capture the player's own view.
  - **Right-click "Detonar" is back**, alongside the G-key flow: G throws a NEW
    grenade, right-click detonates one already on the floor — which is what
    keeps the choreography and performance work testable.
  - **Closed since (`TARGETING_MASTER_PLAN` §6.1/§6.3):** the grenade's ground
    shadow (2026-08-11, `_sync_shadow_transform()` undoes the parent's whole
    transform so the shadow doesn't orbit the tumbling sprite); the settle roll
    now graduates freely with distance/energy instead of quantised 1/16-1/32
    fractions; E-FRAG's shrapnel and E-DEBUG-RAY's rays both fire for real now
    (2026-08-12 — wrong `VoxelRenderer` method name, then a near-black colour
    on `BLEND_MODE_ADD` that rendered every frame while being invisible).
  - **Wall sectioning of the dome — attempted 2026-08-11/12, paused.** A real
    lat/long wireframe grid was built (`IsoProjection.project_point()`), with
    each vertex cast as a 3D ray that clamps to the nearest wall whose real
    per-edge height (`room._wall_height_edges`, retained from `EdgeExtractor`
    instead of discarded) covers the hit point — verified against a real wall,
    a meridian bent into a straight line tracing its face. Reverted on sight:
    *"a distorção não é assim... vai ser uma coisa mais angulosa"* — wrong
    shape, needs a refined spec. The dome's grid is a plain undistorted
    wireframe for now; the height-aware data stays retained for the redo.
  - **`detonation_choreographer_selftest` — CLOSED 2026-08-13.** The prior
    diagnosis here (`[E-FUME]` pulling soot out of `WAVE_TABLE`) was
    superseded by E-ORGANIC-02 before it was ever applied and was never the
    real cause: the selftest's `_pick_source_gu()` detonated its fixture
    literally embedded in a wall (`Slice.gu_cell`, correct for a plan-
    correctness test, copied here by mistake for a pacing one), choking 91.2%
    of the queue into one frame. Fixed by stepping onto the open GU the wall
    faces (`Face.delta()`); real profile after matches the ~46% the live map
    already measured. Blast debris VFX (dust/spark/chip) also remains
    deliberately disconnected from Task 5.
  Stamped-blast soot's rotation-persistence stays unbuilt — currently
  unreachable to test since camera rotation is disabled (ROTATE-KILL-01);
  damage *state* already survives rotation correctly.
- **D34 — the SLAB/SLICE seam, unified (2026-08-08, commits `8dd926e`,
  `22b24be`, `9cd37ae`):** floor textures used to be a genuinely different
  art/render pipeline from wall textures, which is what made a concrete
  floor unable to read as the same material as a concrete wall. Removed:
  **a floor is a roof at the base of the scene**, so wall, roof and floor of
  a `has_facade` material all bake from the same grayscale `facade_<id>`
  under MULTIPLY, and roof and floor of one material now share a single
  page. `slab_<id>` survives only as the photographic exception for organic
  ground (`has_facade: false` — grass/dirt/sand/gravel), verified still
  intact on FLOOR_ZONES_TEST. Every horizontal surface projects at the
  isotropic 1024, reached by **mirrored vertical repeat rather than a
  stretch** (the Director's call) — which also closed a latent roof bug
  (cell rows past ~36 had no texels, hidden only by roof structures being
  small) and gave the floor its native vertical detail back. Floor dents
  wear their own material's decal art now (`decal_dent_concrete_*` etc.),
  with `earth` demoted from "the rule" to "the fallback for materials with
  no art of their own". `MaterialDef.slab_full_color` deleted — it was
  parsed by nothing and read by nothing while its doc comment claimed
  otherwise. Full contract: `BAKE_SYSTEM_REFERENCE.md` FLOOR-ZONE-BAKE's
  reversal block and B2.
- **D35 — earth is a buildable material (2026-08-08, `87fa023` + the
  Director's `facade_earth.png`):** closes the gap D34 left open. Walls,
  blocks and roofs of earth render through the same grayscale + multiply path
  as every other structural material — the "uma parede e um teto de terra"
  combo. Real capture: `Screenshots/history/e_earth_buildable.png`.
  `base_color [0.52, 0.39, 0.26]` is derived from the existing
  `voxel_earth_N` atoms, not picked. **Still scoped out:** earth as a
  DECLARED floor zone, because `"earth"` is also the sentinel for "no floor
  zone here" in five places that decide the whole floor's render; declaring it
  in `floor_zones` now warns loudly instead of vanishing.
- **GPU-upload flush bug, found and fixed (2026-08-08):**
  `DamageCompositeCache.store()` (every WALL/FLOOR/CEILING damage atom's
  compositor) defers the actual GPU texture upload to
  `flush_dirty_pages()`; two independent call sites never called it —
  a new diagnostic tool built this session (`damage_gallery_debug.gd`,
  fixed in commit `512fa5c`) and, more importantly,
  `DetonationChoreographer` itself, the only place a real `DetonationPlan`
  ever reaches `set_cell()` (fixed in commit `31bf069`). Both failures were
  silent — correct data, stale/wrong pixels on screen — found only by a
  real windowed capture, never by a headless check. Real WALL/FLOOR/CEILING
  damage decals are now confirmed rendering correctly (post-fix capture)
  for all 4 declared materials.
- **Post-Task-5 (2026-08-07), REVERSED 2026-08-08:** Director flagged the
  real crater's scorch as "quebradiça" (brittle/fragmented) rather than one
  uniform shade. The original A/B capture (3.3% pixels differ, mean
  0.76/255) that ruled out this rebuild's own soot stamp was itself
  comparing two captures both reading unflushed GPU texture content —
  `DetonationChoreographer` (the only place a `DetonationPlan` reaches
  `set_cell()`) never called `flush_damage_composite_pages()`, unlike every
  other real damage call site. Fixed; the identical A/B test re-run clean
  shows **the blast's own soot stamp genuinely is the cause** (4.1% of
  pixels differ, mean 101.6/255 — over 130x the earlier signal): ring 3
  (soot-only, zero dent/crack weight, so it can carry no dent-decal-art or
  D3 substrate variation at all) reads smooth with the stamp off and
  "quebradiça" with it on. Exact mechanism (uniform per-ring tone →
  checkered per-pixel result) not yet traced — see
  `EXPLOSION_REBUILD_MASTER_PLAN.md`'s Post-Post-Task-5 note and §11 point 2.

---

### Fog of War (80% — Beta)
✅ **Functional:**
- 3 layers (unseen/peek/revealed)
- Revelation as the agent moves
- Guards hidden behind the FOW

⚠️ **Technical debt:**
- O(n²) algorithm — can be slow on large maps

---

### Perception — Calculation (75% — Beta)
✅ **The calculation is correct:**
- Visual cone with angle, distance, and lateral falloff
- LOS verified via WallEdgeData
- Multipliers: posture (1.00/0.55/0.20, `agent.gd`), exposure class
  (1.00/0.80/0.55/0.30/0.10, `exposure_system.gd`), guard state
  (0.55/1.60/0.80/2.00/2.80, `tic_system.gd`), cover, flanking

✅ **Connected** (corrected 2026-08-06 — this section previously claimed the
opposite): the result drives guard state.
`turn_controller.gd:212-222` calls `guard.observe_player()` with severity
3/2/1 as `guard.detection` crosses 1.00 / 0.60 / 0.30. Same wiring mirrored in
`room.gd:1634-1644`.

⚠️ **Not built** (design exists in
[`DESIGN_MASTER_PLAN.md`](../DESIGN_MASTER_PLAN.md) §12): the peripheral
cone, the 3-layer guard state model, `GuardKnowledge`, and evidence detection
(cones reading noise trails with the agent absent).

---

### Audio SFX (0% — Not Started)
Deliberately deprioritized. The math noise grid works; real SFX awaits post-demo.

---

### Animation / Sprites (0% — 🟢 ACTIVE as of 2026-08-13)
Movement tweening works adequately for the demo. ~~Animated sprites await
post-demo.~~ **The character is now the active work** — the Director lifted
`ACTOR_MASTER_PLAN` D18's living-beings deferral on 2026-08-13: *"Agora chegou a
hora de produzir realmente o personagem."*

The agent on screen today is still a **44×61 px vector silhouette**
(`agent.gd`, `SILHOUETTE_WIDTH`/`SILHOUETTE_HEIGHT`) — no sprite, no pose, no
frames.

What already exists to build on, all proven on *objects* rather than characters:
- **The bake rig** — `actor_frame_bake_spike.gd`: N rotation frames from the
  same fixed isometric camera gameplay uses, each frame a pair (flat unlit
  albedo + view-space normal map).
- **The relight shader** — `flat_normal_relight.gdshader`: continuous per-pixel
  N·L + specular from the real `LightRegistry`, so a flat sprite reacts to the
  map's actual lights.
- **A runtime consumer** — `FloatingCollectible` (spinning pickup) and
  `GrenadeProp` (static prop), both on that pipeline, both with real ground
  shadows and real depth sorting.
- **A measured cost floor** — Part 0's spike: a ×8 voxel twin is 16 576 nodes
  and ~480–500 ms to compose per pose, which is why the runtime representation
  is *not* baked from the twin (D16).

What does **not** exist: any pose library, any damage/clothing layering, any
weapon in a character's hands (Part 4), and any decision on how a character is
authored in the first place. Plan: `PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md`
Parts 1/3/4 + §6; open questions in its §7.

**Two other items are gated on this** — firearm aim mode
(`WEAPON_MASTER_PLAN` §5c) and W-PRECOOK (M7.0) both need an agent that holds a
weapon.

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
| ~~Connect the detection meter to the state thresholds~~ | — | ✅ **Done** (`turn_controller.gd:212-222`) |
| Tune the detection curve (distance, shadow, posture) | 3–5 days | High (fairness) |
| Polish the demo room (layout, interesting patrols) | 3–5 days | High (first impression) |
| Visual feedback of guard state (cone colors already change) | 1–2 days | Medium |
| Difficulty testing and tuning | 3–5 days | Medium |

**The 2–4 week estimate that used to close this section was written on
2026-07-08 against the list above, and Phase 3's scope has expanded a long way
since (see [`roadmap.md`](roadmap.md) Phase 3). Treat the remaining rows as a
checklist, not a schedule.**

---

## Render System Status (last two rows corrected 2026-08-06)

| Item | Status | Maturity |
|------|--------|----------|
| **Voxel render system** (bake + slices + junctions) | ✅ Implemented — the only wall renderer | Beta |
| **Direction system (vertex-aligned)** | ✅ Renamed RENAME-01 | Beta |
| **x/y-varying wall orientation fix** | ✅ Fixed RENAME-01b | Beta |
| **Corner fill (triangular gap cover)** | ✅ CONTAINER-04 complete | Alpha |
| **Dirty Flag + TIC updates** | ✅ Shipped as VOXEL-07 (see that section above) — the "Planned CONTAINER-05" this row used to claim was superseded | Beta |
| **View occlusion (wall cutaway)** | ⏸️ Parts 1–3 closed, paused 2026-07-21 — `occlusion_set.gd`, `occlusion_overlay.gd`, wireframe + slice panel all exist. [`OCCLUSION_MASTER_PLAN`](../../PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md) is the arbiter | Alpha |

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

**This footer describes the ENHANCE series above, dated 2026-07-08 — it is not
the document's date.** The header block at the top of this file is the live
one, regenerated by `update_docs.py`.

**Status at that milestone:** ✅ ALPHA ENHANCE PLAN COMPLETE — 7 controllers extracted, room.gd refactored to 2,078 lines, all systems operational. Ready for perspective system implementation and further modularization.

> **2,078 lines is a point-in-time record of this milestone (2026-07-08),
> not a current figure.** Two more months of feature work (Voxel Light
> Foundation among others) grew `room.gd` to 2,896 lines as of 2026-07-26 —
> still the documented monolith (see `technical_debt.md`), not a regression
> from this refactor.
