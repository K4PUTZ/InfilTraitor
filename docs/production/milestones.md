# INFILTRAITOR — Milestones

> **Executable list of milestones with status, dependencies, and blockers.**

---

## ⚠️ Revision Note (2026-06-14)

Code audit (2026-06-14): the AI system is functional with GRADUAL detection implemented. Guards detect and react to the agent with correct escalation.

- **Code exists and works** — `choose_next_cell()`, `tick_state()`, `observe_player()`, `hear_noise()`, communication via signals
- **Detection is gradual** — Thresholds (0.30 SUSPICIOUS, 0.60 ALERT, 1.00 CHASE) implemented in `room.gd:_apply_tic_result()`
- **Functional for the demo** — M2.07 (Search) and M2.08 (Communication) work, guards react to the agent

Milestones AI-01, AI-02, AI-03 and CONTENT-01 (the former ID-01…ID-04 series)
represent integration refinements, not critical bug fixes.

---

## ⏸️ AI Track Deferred (2026-06-18) — gate re-evaluated 2026-07-26

The current guard AI is **provisional / placeholder**. All AI refinement
(AI-01, AI-02, AI-03) is **deferred until the visual system is complete** —
wall **view occlusion** and **floor shadow projection** (VIS-01 + the LIGHT
shadow rendering). Detection tuning depends on reading shadows and cover *on
screen*, so it cannot be calibrated before the visuals exist.

**This section was frozen from 2026-06-18 until this update — it predates the
entire voxel rendering pivot** (see "The Voxel Architecture Pivot" below).
The gate condition itself has since evolved a great deal:

- View occlusion — split out into `OCCLUSION_MASTER_PLAN.md`; Parts 1–3
  closed, paused 2026-07-21 (resume trigger: "a real map with placed
  objects/props to occlude against" — grenades now exist as placed objects,
  shipped 2026-07-22, one day *after* that pause; whether that satisfies the
  trigger is the Director's call, not decided here).
- Floor shadow projection — shipped (`shadow_projector.gd`, world-rendered,
  always-on).
- Voxel FACE lighting (a layer VIS-01 never anticipated) — shipped
  (`VOXEL_LIGHT_MASTER_PLAN.md`, VL-01 → VL-D5).

**Read literally, the original gate condition is largely met.** Whether AI
tuning (AI-02) actually resumes now, or waits for something else (animation
work, the shotgun/destruction-by-shot mechanism, content), is a sequencing
decision only the Director can make — flagging it here so it doesn't stay
silently stuck on a 2026-06-18 condition nobody re-checked.

---

## Completed Milestones

### ✅ M1.0 — Prototype Foundation
**Objective:** Core grid navigation, isometric rendering, and FOW system operational.

**Dependencies:** None (project start)

**Status:** ✅ Complete (2026-02-20)

**Deliverables:**
- Tile-based grid navigation (4 directions)
- Isometric 2.5D rendering
- Three-layer fog of war (unseen/peek/revealed)
- Basic movement mechanics (2 AP per turn)

**Validation:**
- Agent moves smoothly on grid
- FOW updates correctly with movement
- Rendering is consistent and performant

---

### ✅ M1.5 — Tile System & Navigation Polish
**Objective:** Tile-wall autotile system, movement overlays, and navigation polish.

**Dependencies:** M1.0

**Status:** ✅ Complete (2026-04-15)

**Deliverables:**
- Tile-wall autotile system (corner+edge+fill logic)
- Movement overlay (Dijkstra pathfinding visualization)
- Floor apron and biome hierarchy
- Phase 1 border and end-cap fixes

**Validation:**
- Tile walls render correctly with autotiling
- Movement paths are visible and accurate
- Floor apron is seamless

---

### ✅ M2.0 — Sound System Foundation
**Objective:** Event-driven detection, noise propagation, and audio perception.

**Dependencies:** M1.5

**Status:** ✅ Complete (2026-06-05)

**Deliverables:**
- TIC System (event-driven detection)
- Noise System (persistent grid with decay)
- Audio perception (independent of LoS)
- Organic patrol behavior

**Validation:**
- Detection events trigger on boundary crossing
- Noise persists and decays correctly
- Guards react to audio independently of vision
- Patrol behavior is variable and organic

---

### ✅ M2.01 — Visual Detection Cones
**Objective:** Color-coded probabilistic vision visualization.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-05-25)

**Deliverables:**
- Color-coded cone visualization (blue/yellow/red)
- Distance-based attenuation
- Lateral falloff (center/±1/±2 from heading)
- State-dependent appearance (PATROL/SUSPICIOUS/ALERT/CHASE)

**Validation:**
- Cones render correctly and are color-coded
- Attenuation matches distance curve
- Cones update in real-time

---

### ✅ M2.02 — Organic Patrol Behavior
**Objective:** Variable speed, spontaneous pauses, and look rotation.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-05-30)

**Deliverables:**
- Variable speed (0.60× patrol to 3.00× chase)
- Spontaneous pauses (~20% chance per step)
- Look rotation between cardinal directions
- Smooth animation and tween-based transitions

**Validation:**
- Speed multipliers apply correctly
- Pauses are frequent enough to feel organic
- Look rotation is smooth and responsive

---

### ✅ M2.03 — Audio Detection System
**Objective:** Noise-based detection independent of visual LoS.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-02)

**Deliverables:**
- Audio detection evaluation (separate from visual)
- Wall attenuation (0.6× per wall crossed)
- Distance falloff (linear over 2-tile radius)
- Thresholded reactions (≥0.6, ≥0.25, <0.25)
- Detection meter accumulation

**Validation:**
- Audio detection works independently of visual LOS
- Wall attenuation applies correctly
- Distance falloff is linear and predictable
- Reaction thresholds trigger correctly

---

### ✅ M2.04 — Noise Propagation & Decay
**Objective:** Persistent noise grid with decay and emission mechanics.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-01)

**Deliverables:**
- Noise grid (Dictionary<Vector2i, {intensity, age}>)
- Decay mechanics (-0.25 per enemy phase)
- Emission (~20% chance per guard step)
- Visualization (cyan cones with intensity-based alpha)

**Validation:**
- Noise persists across turns
- Decay is consistent (4-turn lifespan for 0.5 intensity)
- Emission rate feels natural
- Visualization is clear

---

### ✅ M2.05 — Guard Attention System
**Objective:** Decoupled vision angle and focus-based scanning behavior.

**Dependencies:** M2.0, M2.01

**Status:** ✅ Complete (2026-06-08)

**Deliverables:**
- Visual vision angle decoupled from facing angle
- GuardAttention inner class (3 focus modes)
- Smooth head rotation and scanning
- Interest management (IDLE scanning, WAYPOINT anticipation, AGENT tracking)

**Validation:**
- Vision angle updates independently of facing
- Head rotation is smooth and responsive
- Scanning behavior is clear and observable
- Focus modes trigger appropriately

---

### ✅ M2.06 — Tactical Shadows System
**Objective:** Shadow projection with DIRECT and PENUMBRA multipliers.

**Dependencies:** M1.5

**Status:** ✅ Complete (2026-05-20)

**Deliverables:**
- Shadow projection (adjacent tiles + 2-step penumbra)
- DIRECT multiplier (0.30×)
- PENUMBRA multiplier (0.55×)
- Perspective-aware rotation

**Validation:**
- Shadows project correctly in all 4 cardinal directions
- Multipliers apply correctly to detection
- Shadows update on perspective rotation

---

### ✅ M2.07 — Suspicion-Based Search
**Objective:** Physical investigation behavior for SEARCH state.

**Dependencies:** M2.0, M2.05

**Status:** ✅ Complete (2026-06-10)

**Deliverables:**
- Physical movement to search tiles
- Observational pauses at reached tiles
- Queue management for multi-point patrolling
- De-escalation to SUSPICIOUS after search complete

**Validation:**
- Guards move physically to search targets
- Pauses allow for focus sweeps
- Queue consumption is robust
- De-escalation occurs correctly

---

### ✅ M2.08 — Guard Communication System
**Objective:** Whistle and radio signal propagation.

**Dependencies:** M2.0, M2.07

**Status:** ✅ Complete (2026-06-10)

**Deliverables:**
- Whistle signal (ALERT state, 3-tile radius)
- Radio signal (CHASE state, global)
- Signal routing via room hub
- State escalation validation

**Validation:**
- Whistles reach nearby guards correctly
- Radios broadcast globally
- Guards ignore low-priority alerts (state hierarchy)
- Signal propagation is immediate

---

### ✅ M2.09 — Audio Direction Indicators
**Objective:** Floating indicators showing where guard noise originates.

**Dependencies:** M2.04

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- GuardNoiseIndicator script (renders "(((" and ")))" symbols)
- Floating animation and fade-out (1.8s duration)
- Color coding by intensity (low/high)
- Z-index placement (above all overlays)

**Validation:**
- Indicators display at correct positions
- Animation is smooth and readable
- Colors correspond to intensity
- Duration feels appropriate

---

### ✅ M2.10 — Decoupled Camera During Enemy Phase
**Objective:** Lock camera on agent; focus on guards only if revealed.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- Camera lock on agent during enemy phase (no following guards)
- Conditional focus gate: is_cell_revealed() check before guard focus
- Z-index ordering: shadow(1) < fog_of_war(2) < structures(3)

**Validation:**
- Camera stays centered on agent
- Revealed guards are shown; unrevealed guards are behind FOW
- Shadows visible in all cases (baked at z_index=1)

---

### ✅ M2.11 — Directional Shadow System Rewrite
**Objective:** Baked shadows using light source cone projection and 8-direction quantization.

**Dependencies:** M2.06

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- LightSource inner class (position, height, radius, intensity)
- Obstacle height mapping (tile types to heights)
- Cone projection geometry (shadow_len = height × (light_height - height) / distance)
- 8-direction quantization
- ShadowFullLayer and ShadowPartialLayer (baked, z_index=1)
- Shadow layer population via _bake_shadow_tiles()

**Validation:**
- Shadows cast in 8 directions (not just 4)
- Cone projection geometry is correct
- Shadows visible across entire map
- Baked layers never hidden by FOW

---

### ✅ M2.12 — GUI Cover Hints Removal
**Objective:** Remove old cover hint system; prepare for M2.15 redesign.

**Dependencies:** None

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- Removed _draw_cover_hints() from movement_overlay.gd
- Removed cover hint color constants
- Reserved for M2.15 wall-face icons redesign

**Validation:**
- No compilation errors
- No lingering references to cover hints

---

## In-Progress Milestones

### ✅ AI-01 — Detection Escalation Gradual — IMPLEMENTED

**Objective:** Connect the detection meter to the state thresholds for gradual escalation (PATROL → SUSPICIOUS → ALERT).

**Status:** ✅ RESOLVED (Implemented on 2026-06-14)

**Resolution Details:**
A code audit confirmed that gradual detection escalation **IS ALREADY IMPLEMENTED** in `room.gd:_apply_tic_result()`:
- Defined thresholds: `DETECTION_THRESHOLD_SUSPICIOUS := 0.30`, `ALERT := 0.60`, `CHASE := 1.00`
- The detection meter accumulates per tic and drives state transitions
- Automatic de-escalation via `_get_detection_decay()` works per state
- Audio detection integrated with the same threshold model

```gdscript
if guard.detection >= DETECTION_THRESHOLD_CHASE:
    guard.observe_player(true, 3, agent.cell)  # STATE_CHASE
elif guard.detection >= DETECTION_THRESHOLD_ALERT:
    guard.observe_player(true, 2, agent.cell)  # STATE_ALERT
elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
    guard.observe_player(true, 1, agent.cell)  # STATE_SUSPICIOUS
```

**Validation:** ✅ Complete
- Guards detect and escalate gradually
- Timer-based de-escalation works
- Audio + visual detection integrated
- Functional AI for the Investor Demo
**Objective:** Reorganize documentation into modular, scalable structure.

**Dependencies:** None (orthogonal to gameplay)

**Status:** 🟡 In Progress (2026-06-11)

**Deliverables:**
- `docs/vision/` — game_vision.md, design_philosophy.md, pillars.md
- `docs/systems/` — individual system documentation
- `docs/production/` — roadmap.md, milestones.md, backlog.md, pipeline.md
- `docs/technical/` — architecture.md, implementation guides
- `docs/history/` — sprint logs and refactors
- Central index (docs/README.md)

**Blockers:** None

**Next Steps:**
1. Create system documentation (perception.md, lighting.md, noise.md, etc.)
2. Create technical architecture documentation
3. Move history and refactor logs
4. Create central index
5. Clean up old documentation

**Validation:**
- No system docs duplicated across multiple files
- Philosophy separate from milestones
- Roadmap separate from system docs
- Central index navigable

---

### 🟡 VOX-BAKE-01 — Voxel Facade Baking System — PARTIALLY COMPLETE

**Objective:** Bake real facade textures onto voxel walls (side faces + tops)
with correct isometric projection, replacing flat material-color rendering,
without per-frame procedural cost (D12).

**Dependencies:** Voxel wall system (SLICE-02), texture resolver, material
registry.

**Status:** 🟡 Wall + top facades complete and Director-ratified
(`verified/v0.6.0`, "Alpha Top Texture", 2026-07-11). **Textured interiors
(destruction reveal) blocked on the destruction system existing** — that
blocker is now resolved (`DESTRUCTION_MASTER_PLAN.md` Parts 0–3 shipped,
2026-07-22; see "The Voxel Architecture Pivot" below), but Part 3 of this
plan (textured interiors specifically) has not itself been picked up. Tracked
in `PROMPTS/PLANNING/TOP_TEXTURE_MASTER_PLAN.md` (Part 3).

**Deliverables (done):**
- Continuous-plane facade model: wall side-faces render real material
  textures (stone, concrete, metal, wood) with correct isometric shear,
  seamless across atoms and through junction corners (`OVERLORD-FIX-01/02`)
- Horizontal "laje" tops: voxel tops project the same facade files through
  the diamond-plane transform, seamless with the sides (`TOP-SHEAR-01` /
  `TOP-CROP-02` / `TOP-JUNCTION-03`)
- MULTIPLY blend canon (preserves material color under facade detail);
  MATERIAL_ONLY/TEXTURE_ONLY as alternates; LINEAR_LIGHT/OVERLAY parked
  (render as TEXTURE_ONLY, logged) pending LUT variants
- Content-addressed disk cache for baked pages (`BAKE-CACHE-01` →
  `BAKE-CACHE-FORMAT-01` binary storage → `BAKE-CACHE-PAGESIZE-01-b` sparse-
  usage page composition, the corrective for an initial version of the
  page-size optimization that never actually shrank anything). Cold bake
  ~0.4–1.2 s; warm boot down from the original ~730–770 ms (PNG-decode-bound)
  to ~32 ms once both fixes landed — budget (≤150 ms) cleared. Sparse maps
  compose only the atom cells actually referenced (verified: an 8-col×4-row
  synthetic usage produces an 8× smaller page than the uncropped baseline;
  full-width maps like TEXTURES are unaffected by design). Regression suite:
  `bake_cache_test` 7/7. A production-map (non-synthetic) size-reduction
  benchmark was not taken — open item, not blocking.
- B3 (alpha-from-canon) closed with 0-mismatch evidence at both wall and
  page-composition granularity

**Deferred (Part 3, blocked):**
- Textured interiors / destruction-reveal substrate (512-atom local-period
  dictionary per material; D-TT3/D-TT4 ratified in direction, not built)
- Multi-GU volume tops (only single-voxel slice/junction tops ship)

**Validation:**
- Full bake test suite green (`bake_fix_02/09/11/12`, `bake_selftest`,
  `bake_cache_test`) — see `docs/technical/BAKE_SYSTEM_REFERENCE.md`
- Director visual ratification at `verified/v0.5.0`, `v0.5.1`, `v0.6.0`

---

## The Voxel Architecture Pivot (2026-06-28 → 2026-07-26) — retroactively documented 2026-07-26

**This whole phase was undocumented here until now.** Two months of work —
the majority of everything shipped since this file was last touched
(2026-06-18) — replaced the flat sprite/`WallContainer` renderer with the
voxel architecture and is nowhere reflected in the milestone list below.
Detail lives in `docs/production/current_state.md` (maintained, "the live
one") and the master plans; this entry exists so the milestone list stops
silently pretending nothing happened between VOX-BAKE-01 and now.

### ✅ VOXEL-01..08 — Wall Voxel Rendering System
**Status:** Complete. Native `TileMapLayer`-per-voxel rendering replaced the
legacy `WallContainer`/`Image.blend_rect` renderer entirely — no empirical
offsets, analytically derived positions (Transform Canon). Geometry module
(`Edge`, `Slice`, `HighWall`, `VoxelRegistry`) + dirty-flag/TIC integration +
junction filling all shipped and selftested (`geometry_selftest.gd` 29/29).
See `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`.

### 🟡 VOXEL-09 — Secondary (per-HighWall) Baking — DEFERRED, not started
Architectural framework in place (`high_wall.gd`); no implementation. Not
blocking anything currently in flight.

### ✅ Bake System (BAKE-FIX-01 through 14, BAKE-CACHE-01/PAGESIZE-01-b)
**Status:** Complete for walls + tops (B1–B6 invariants closed, B3 with real
pixel evidence). Warm boot ~32ms (budget ≤150ms cleared, was 730-770ms).
Textured interiors (destruction reveal) is the one open item — see
VOX-BAKE-01 above. See `docs/technical/BAKE_SYSTEM_REFERENCE.md`.

### 🟡 Occlusion (`OCCLUSION_MASTER_PLAN.md`) — Parts 1–3 done, PAUSED 2026-07-21
View occlusion (hiding structure from the player's camera so the agent stays
visible under walls/roofs) — occlusion-set computation, wireframe visual, and
agent-on-top rendering all shipped. Part 4 (interior cutaway) blocked on
Slab/roofs, which have since landed but Part 4 hasn't been picked back up.
Paused at the Director's call pending "a real map with placed objects to
occlude against" — see the AI-track gate note above for why that trigger may
now be satisfied.

### 🟡 Destruction (`DESTRUCTION_MASTER_PLAN.md`) — Parts 0–3 done, UNBLOCKED 2026-07-26
The dirty-flag/TIC destruction motor (built since the Voxel pivot, never
switched on) now has a real trigger: a thrown grenade detonates, computes a
wall-aware GU-ring blast via BFS, and marks real voxels destroyed through the
real render pipeline (`blast_calculator_selftest.gd` 11/11, verified against
the real running game via direct `TileMapLayer` cell readback, not just
selftests). Shipped as "Alpha Grenade Foundation," 2026-07-22. Paused
immediately after because destroyed voxels rendered fully lit regardless of
damage (craters invisible) — **that blocker is now closed** by Voxel Light
(below). Cover rule, noise-on-digging, rubble-as-terrain, fire/smoke remain
explicitly deferred (never in scope for this pass). Nobody has resumed the
plan yet.

### ✅ Voxel Light (`VOXEL_LIGHT_MASTER_PLAN.md`, VL-01 → VL-D5) — SHIPPED 2026-07-23 → 2026-07-26
"Alpha Temporal Light Foundation." Every voxel FACE (not just the floor) now
paints to one of 12 discrete brightness buckets from lamp distance/height/
facing + GU-level occlusion. Blast destruction reads visually: soot rings,
contiguous radial floor crater, directional destruction bias, under-wall
darkening, fading ember→char glow on freshly-blasted wood. Temporal lights
(flicker/pulse) repaint only their own influence set (~75ms worst case vs.
~590–675ms whole-map). Perspective rotation cost cut ~80%. Two items still
open: metal denting/warping (item 6) and the 4-view prebuild optimization —
neither blocking.

---

## Queued Milestones

---

### ⏸️ ART-01 — Materials & Objects Pipeline — SCHEDULED (Alpha → Beta window)
**Objective:** Dedicated art for horizontal surfaces (slab tops + roof tiles,
including stepped/sloped roofs), a single-writer materials dictionary, a voxel
objects dictionary rendered per-voxel, and an open-source `.vox` import
pipeline — completing the "everything is GU-multiple voxels" world model.

**Window:** Explicitly scheduled for **after scenario and gameplay are
complete — between Alpha and Beta** (Director, 2026-07-16). Not to be started
earlier; specs are pre-written so art production can begin the moment the
window opens.

**Canonical spec:** `ASSETS/ART_SPECIFICATIONS.md` (adopted 2026-07-16) —
the authoritative manual for all asset production under this milestone.
Feasibility findings recorded there (§3–§6): slabs are already 1-voxel-high
native units; stepped roofs are a generator concern, not a new mechanism;
PropDef schema already supports per-voxel `layers` (unconsumed by v1
renderer); `.vox` models need palette curation + GU-scale normalization.

**Dependencies:** Scenario + gameplay complete (Alpha); bake system
(VOX-BAKE-01 walls/tops — shipped); roof bake foundation (shipped
2026-07-16, `alpha-horizontal-bake-foundation`); destruction plan Part 3
(for prop destructibility integration).

**Deliverables (dependency order):**
1. Materials dictionary (`MaterialDef`) as single writer of material truth;
   `BakePolicy` and compositor become readers
2. Dedicated roof/slab texture family at Director-ratified dimensions
   (Overlord recommendation: 512×512, 32×32-voxel period) + separate
   roof-facade policy map
3. Stepped-roof profile generator spike on PLAYGROUND with **measured** voxel
   budget (flat baseline: 7,778 roof voxels) — Director ratifies pitch
   visually
4. Prop renderer v2: consume PropDef `layers` per-voxel through
   `_set_voxel_cell` (Rule 8 grants bake/theming/destruction for free);
   pin `layers` row/level ordering with a D-number
5. `.vox` → PropDef converter (offline Python, `tools/`) + palette→material
   curation workflow + per-asset license record
6. Footprint-aware rotation in `perspective_mapper` for multi-GU objects

**Acceptance Criteria (high level):**
- Roofs/slabs render dedicated art in all 4 views, seam-free, structure-local
- At least one stepped-roof fixture in PLAYGROUND, Director-ratified
- At least one imported open-source `.vox` object rendered per-voxel, baked,
  themed, and destructible like any wall voxel
- No consumer holds a private copy of material truth (anti-split-brain)
- Mobile budget spike documents voxel-count headroom before general rollout

---

### ⏸️ AI-02 — Detection Tuning & Game Feel — DEFERRED (provisional AI; resumes after VIS-01)
**Objective:** Calibrate the detection parameters so that stealth is genuinely tense and fair.

**Dependencies:** AI-01

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Internal playtest with functional guards (at least 10 sessions)
- Adjust the DISTANCE_CURVE based on feedback
- Adjust the posture multipliers (STANDING/CROUCHING/PRONE)
- Adjust the shadow multipliers (DIRECT/PENUMBRA)
- Adjust the escalation thresholds (SUSPICIOUS/ALERT/CHASE)
- Adjust the per-turn decay rate

**Acceptance Criteria:**
- Agent standing, lit, 2 tiles from a guard = detected in ~2 turns
- Agent crouched, in shadow, 4+ tiles away = detection < 15% per turn
- Possible to complete the demo room undetected (but it takes effort)
- De-escalation possible (guard returns to normal state if the agent disappears)

---

### ⏸️ CONTENT-01 — Demo Room Polish — DEFERRED (gated by the AI track + VIS-01)
**Objective:** Create a demo room that showcases all systems at once.

**Dependencies:** AI-02

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Layout with multiple shadows, corridors, and cover positions
- 2–3 guards with distinct, non-trivial patrols
- At least 1 guard with a patrol that crosses a lit area
- Vision cones colored by state (blue/yellow/orange/red)
- Visible, readable noise indicator
- Basic objective (reach the extraction tile)
- Minimal UI: turn phase, agent AP, overall detection state

**Acceptance Criteria:**
- An observer with no context can understand the situation in < 2 minutes
- The room demonstrates: stealth via shadow, vision-cone evasion, noise management
- Guards communicate alerts to each other when they detect the agent

---

### ⏸️ AI-03 — FSM Architecture Refactor — DEFERRED (provisional AI; resumes after VIS-01)
**Objective:** Refactor GuardEnemy's match/case to a Strategy pattern before adding combat.

**Dependencies:** AI-01 (guards working), before GAME-01

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Each guard state as a separate class (GuardStatePatrol, GuardStateSuspicious, etc.)
- Common interface (decide(), enter(), exit())
- GuardEnemy delegates to the current state object
- Personality traits as modifiers (not as new states)

**Acceptance Criteria:**
- Adding a new state = create a new class, without touching the existing if/match
- Current behavior preserved (no regression)
- More readable code (each state ~50 lines, not 200+ lines in the match)

---

### ⏳ VIS-01 — Overhead Visual Engine (ceiling + view occlusion)
**Objective:** Build the topmost (5th-floor) decorative/lighting layer AND the
view-occlusion system that keeps the agent readable under walls/ceiling. The two
are one system: ceiling props are the worst occluders, so they share the cutaway/
fade machine.

> **Terminology:** *view occlusion* here = hiding structure from the **player's
> camera** so they can see the agent. This is distinct from the gameplay
> *occlusion semantics* in `docs/systems/occlusion.md` (what blocks light/LoS/
> sound). Keep them separate.

**Dependencies (already in place):**
- Wall storeys / N-floor stacking ✅ (Alpha Wall Storeys)
- Map-driven lights (`MapSpec.lights` → omni `LightSource`) ✅
- Shader-based FOW (reusable cutout tech) ✅
- 4-way perspective rotation (manual override / "escape hatch") ✅

**Stages (etapas):**
1. **`MapSpec.ceiling` vocabulary** — data layer: `ceiling: [{cell, kind, height, …}]`,
   compiled by `MapCompiler` into `layout.ceiling_props`, rotated by perspective
   exactly like `props`/`lights`/`exit_cells`. No buffer math outside the compiler.
2. **`CeilingPropLayer` render** — Node2D above wall storey N (z = 10 + max_floors + 1).
   Fixtures are **sprites/scenes, not tilemap tiles** (double-height chandelier
   anchored at floor 5, drawn down to floor 4; cables/pipes cross cell borders).
3. **Spot / directional light type** — extend `LightSource` (omni-only today) to
   support cone/spot for holofotes pointing at the floor; feeds `LightingController`.
4. **View occlusion** — superseded in full by
   **`PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`** (Parts 1–4). See the boxed warning
   below: the old "cutaway by deletion" staging is retired, not merely reworded.
5. **Ceiling content + tactical hooks (optional, own follow-up milestones)** —
   populate maps (lamps, conduits, pipes, vents); defer gameplay hooks (security
   cameras as detectors, flicker → `temporal_overlay` shadow) to their own IDs.

**Locked architecture decisions (2026-06-18):**
- **Shadow model = hybrid (tiered + penumbra):** deterministic length
  `= height_tier[object] × light_factor[light] × distance_stretch`, direction away
  from the light, tip softens to penumbra. Not physical similar-triangles (kept
  uniform / mobile-cheap, "not random").
- **Light placement = tracks + anchors, with exceptions:** normal lights snap to
  canonical `MapSpec` tracks (uniform shadows, clean merge); special lights
  (sun / spot / fire) may be placed freely.

**Occlusion model and architecture:**

Canonical spec: **`PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`** (ratified 2026-07-12).

The two-plane model still holds — coarse gameplay grid (`256×128`: guards, A\*,
`blocked_edges`, TicSystem) vs fine geometry/render grid — but the fine plane is
**8×8 voxels per GAME UNIT at `32×16`**, not 4×4 subcubes at `64×32`.

> ### ⚠️ Retired: "occlusion = deletion"
>
> This section previously read: *"Occlusion and destruction are the same operation
> (`set_subcube → empty`); occlusion is the reversible, camera-driven case."*
> **That is retired and must not be implemented.**
>
> They are *not* the same operation, and conflating them produces a
> **save-corrupting bug**: `Voxel.visible` is owned solely by destruction
> (`set_damage()` forces `visible = false` on DESTROYED). If occlusion also wrote it,
> releasing an occlusion after a camera rotation would set `visible = true` and
> **resurrect a destroyed voxel** — reproducible only when someone rotates the camera
> over a crater.
>
> The cadence is wrong too: a detonation is rare and capped, an agent step is constant.
> Routing occlusion through the dirty flag would make the common case cost more than
> the rare one.
>
> Occlusion is **VIEW**: its own `_occluded_cells` set, never persisted, painted with
> TileSet alternative tiles (per-alternative `modulate`, same atlas region → zero extra
> memory). See `OCCLUSION_MASTER_PLAN.md` §2 for the single-writer table, and
> `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` for the destruction side.

**Progress:**

> **Baked Shadows Foundation (2026-06-18):** the shadow/lighting half of the visual
> gate is in place — geometric projection, always-on world-rendered floor shadows,
> map-driven lights (types + rails + special), and ceiling placeholders. Remaining
> for VIS-01: **view occlusion (wall cutaway)** + shadow tuning + verticality.

- ✅ **Floor shadow projection — geometric Slice 1** (`shadow_projector.gd`):
  replaced the LOS-occlusion classifier with geometric per-object casting; tunable
  `height_tier_length` / `light_height_factor` / `distance_stretch`. Acceptance
  tests pass (direction away from light; taller object & lower light → longer;
  floor-height → none); playground smoke: 8 props → shadow=8, penumbra=2.
  - Fix: blocked cells now default to HUMAN height for casting (were floor=0).
  - Next refinements: per-prop height by tile type; lateral penumbra; multi-tile
    silhouette width; wall-edge floor shadows.
- ✅ **Slice 2 — `MapSpec` light tracks / anchors** (`map_compiler.gd`): lights snap
  to canonical track cells via `{track, slot}`; special lights stay free via `{x, y}`.
  Playground migrated to a "central" rail — resolves to identical cells (no regression).
- ✅ **Slice 3 — ceiling light render** (`ceiling_prop_overlay.gd`): `CeilingPropOverlay`
  draws map lights as placeholder fixtures above the wall stack (z above the top storey),
  perspective-driven (refreshed on rotation). Lift/size tunable; real sprites later.
- ✅ **Light types wired** (`lighting_controller.gd`): MapSpec lights now honor
  `type` / `height_class` / `direction_deg` / `cone_deg` / `flicker` (was hardcoded
  omni + overhead); legacy `height` float reconciled; directional angle rotates with
  perspective. Cone-gating acceptance tests pass; playground has a demo cone spot.
  Unlocks the "not restrictive" branch — sun rays / spots / fire / candles.
- ✅ **Shadows are world-visible** (`_tile_shadow` ← `ExposureSystem`): geometric floor
  shadows now render always-on (multiply-blend), not only in LIGHT/HEAT vision — shadows
  are real-world elements. Ceiling lamp lift raised ~0.75 storey. Shadow tone/length
  still open for tuning; true "5th-floor" verticality needs taller storeys (pair with
  view occlusion so taller walls don't hide the interior).
- ✅ **Spill Foundation** (`_repaint_world_shadows` / `_compute_shadow_spill` + palette):
  each FULL-shadow cell now bleeds a soft cosmetic 2-tile halo (`SHADOW_SPILL_RADIUS`,
  Chebyshev rings) — purely visual (detection reads the exposure grid, never the overlay),
  so it softens the silhouette with zero hiding value. **Key fix:** `BLEND_MODE_MUL`
  discards source alpha (`out.rgb = floor.rgb × color.rgb`), so the shadow ramp now
  encodes intensity in **RGB** (0.48 → 0.70 → 0.82 → 0.92), not alpha — eliminating the
  flat "binary" multiply look. Rule documented in `docs/systems/rendering.md`. Brightness
  knobs are the RGB values (palette) + `SHADOW_SPILL_RADIUS` (room.gd).
- ✅ **Stacked-prop heights → bigger real shadows** (`map_compiler._prop_height_for_stack`,
  `room._prop_heights`, `lighting_controller._setup_tile_semantics`): a prop `stack` (1-4)
  in MapSpec now (a) renders that many stacked crate sprites (`_ensure_prop_stack_layers`,
  `CRATE_STACK_STEP_PX`) and (b) sets a real per-prop height class so `ShadowProjector`
  casts a longer shadow — **no projector change** (closes the VIS-01 per-prop-height TODO).
  Playground south cluster = stacks 1/2/3/4 to show the gradation (smoke: penumbra 2→5).
- ✅ **Spill: density + directional** (`_compute_shadow_spill` / `_spill_color`): the
  cosmetic halo now widens with real-shadow cluster density (tall stacks glow wider) and
  shades orthogonal tiles darker than diagonal — softer rings. Still **non-playable**
  (detection reads `ExposureSystem`, never the overlay). All knobs are `var`s on `room.gd`.
- ⏳ Next: **Slice C — spill onto walls/props** (per-layer modulate vs per-cell shader, plan
  calmly) and **Slice D — graded *playable* shadow strength** (DEEP_SHADOW tiers + elite/weak
  agent axis, separate approved prompt). Also Slice 4 view occlusion / floor tile variety (#3).

**Acceptance Criteria (high level):**
- Agent never fully hidden by a wall or ceiling prop from the player's view.
- Cover-bearing walls remain perceivable even when cut (faded/stub, not gone).
- Ceiling/occlusion stay coherent across all 4 perspective rotations.
- Mobile-friendly (per-layer fade + one cheap fragment shader; no per-frame O(n²)).

**Estimated Duration:** 3–5 weeks (staged; stages 1–2 + 4 are the minimum viable slice)

---

### ⏳ M2.13 — Suspicion Meter Integration (MERGED INTO AI-01)
**Objective:** Per-guard suspicion tracking and escalation mechanics.

**Dependencies:** AI-01 (this functionality was merged into AI-01)

**Estimated Duration:** (covered by AI-01)

**Deliverables:**
- Per-guard suspicion meter (0–100%)
- Visual meter display
- Meter increase triggers (visual detection, noise, communication)
- Meter decrease over time (de-escalation)
- State transitions based on meter (PATROL → SUSPICIOUS → ALERT → CHASE)

**Acceptance Criteria:**
- Meter updates responsively
- Escalation is visible and dramatic
- De-escalation is possible with planning

---

### ⏳ M2.14 — Investigation Patterns
**Objective:** Guards investigate last-known agent position.

**Dependencies:** M2.13

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Investigation target calculation (agent's last-known cell)
- Multi-guard convergence (multiple guards approach investigation target)
- Investigation completion trigger (guard reaches cell or timeout)
- De-escalation after fruitless search

**Acceptance Criteria:**
- Investigation creates multi-guard threat
- Convergence is coordinated and challenging
- Player can still evade with clever planning

---

### ⏳ GAMEPLAY-01 — The Non-Combat Turn *(new 2026-08-14, Director direct)*
**Objective:** The systems that make a turn playable *before* anyone shoots —
the home the Director assigned to every ownerless mechanic that came out of the
character conversation.

*"As questões sem dono entram em GAMEPLAY, que é paralelo ou anterior a combate.
Vai tocar em AI dos guardas, movimentação, destruição de lâmpadas, som,
detecção, etc."* (Director, 2026-08-14)

**Dependencies:** none hard. **Parallel to or prior to GAME-01** — the Director's
own framing, and the reason this milestone sits above it in this file.

**Estimated Duration:** not estimated — scope is an enumeration, not a design.

**Deliverables** *(the Director's own list, 2026-08-14 — recorded verbatim in
substance, NOT expanded into a designed scope by the agent)*:
- **Distraction / misdirection as an agent verb** — whistle to attract, throw a
  stone to distract, bang on walls, build noise-emitting devices (the Director's
  named reference: *Alien Isolation*).
- **Manipulable NPCs** — map NPCs that can be worked positively or negatively;
  not complex dialogue trees, but an interaction mechanic, up to and including
  the comic beat (*"olha o passarinho"*) that neutralises a guard.
- **Guard AI**, **movement**, **sound**, **detection** — the existing tracks
  (AI-02, AI-03, M2.14) are the detail owners; this milestone is where they meet
  the new verbs.
- **Lamp destruction** — shooting out a light to manufacture shadow. Connects
  three already-built systems (destruction, `LightRegistry`/`LightSource`,
  `exposure_system.gd`) that have never been wired to each other for this.

**Why it has no owner document yet:** noise is built (`DESIGN_MASTER_PLAN` §5)
and the sound lure exists as a gadget (§10.4), but *the agent* whistling is a new
verb and a manipulable NPC is a new system. The design belongs here, and is
**not written** — see `ACTOR_MASTER_PLAN` §7's closing note, which is where these
were parked before this milestone existed.

**Design lineage:** this is the mechanical translation of the persona ratified in
`ACTOR_MASTER_PLAN` D32 — a cunning operator who *"persuades and deceives."* In a
stealth game that is not dialogue; it is manipulating what the enemy **knows**,
which makes `GuardKnowledge` (§12.2) the system these verbs actually target.

---

### ⏳ GAME-01 — Combat System Foundation
**Objective:** Basic combat resolution and damage modeling.

**Dependencies:** M2.14

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Combat resolution (hit/miss)
- Damage calculation
- Health tracking
- Combat state machine (pre-combat, in-combat, post-combat)
- Basic enemy tactics (flanking, covering)
- Firearm aim mode — weapon slots, target cycling, hit %, pre-resolution
  (`WEAPON_MASTER_PLAN` §5c / D31–D36)
- **W-PRECOOK — firearm pre-production, as the LAST item of this milestone**
  *(Director-assigned 2026-08-13; moved here from M7.0 the same day)*

**Acceptance Criteria:**
- Combat is viable but not optimal
- Enemy tactics are coordinated and challenging
- Combat escalates threats appropriately
- **Firing a gun does not stall the frame it is fired on** (W-PRECOOK)

**W-PRECOOK — firearm pre-production (Director-assigned 2026-08-13).** Briefly
assigned to M7.0 earlier the same day, then pulled forward: *"pode colocar o
W-PRECOOK mais cedo, vamos fazer ele no final da milestone de combate."*

- **What it is:** firing a gun costs ~310 ms of synchronous CPU for nine voxels,
  entirely inside `_repaint_voxel_light_buckets()` — measured, `[SHOT-PROF]`. A
  grenade destroying 453 voxels commits in 0.5 ms, because it pre-computes
  during the throw. The firearm has no pre-production at all.
- **Why it is LAST in this milestone, not first:** the window it fills is the
  aiming window, so aim mode has to exist and be roughly settled before there is
  anything real to hide the cost inside. Doing it earlier means tuning against a
  mock — the Director's original reason for deferring it at all: *"pra não ficar
  testando com mecanismos visuais teóricos."*
- **Also needs:** an agent that exists as a model and holds a weapon (ACTOR
  living-beings track, Part 4).
- **Owner doc:** [`PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md`](../../PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md)
  §0 (measurement + the two candidate routes, unchanged) and D30.
- **Scope note (Director, 2026-08-13, closing §7c Q2):** the candidate target
  list is **not** capped — six visible enemies means six cyclable targets. This
  does not enlarge the pre-production problem, because D33 pre-resolves only the
  **current** target: peak cost is one plan regardless of how many candidates
  exist. What the candidate count changes is how often the player discards and
  recomputes by cycling, which is a responsiveness question, not a budget one.

---

### ⏳ M3.05 — Advanced Tactics
**Objective:** Overwatch, traps, and reactive mechanics.

**Dependencies:** GAME-01

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Overwatch system (hold action, reactive trigger)
- Trap mechanics (place, trigger, effects)
- Enemy reaction to traps
- Tactical depth through conditional mechanics

**Acceptance Criteria:**
- Overwatch adds strategic depth
- Traps create meaningful decisions
- Enemy reactions are intelligent

---

### ⏳ M4.0 — Campaign Narrative: Chapter 1
**Objective:** Tutorial chapter introducing visual perception mechanics.

**Dependencies:** M2.12

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Mission briefings
- Difficulty progression (tutorial → challenge)
- Narrative introduction (agent's background, first mission)

**Acceptance Criteria:**
- Chapter is playable start-to-finish
- Mechanics are introduced progressively
- Narrative is engaging and cohesive

---

### ⏳ M4.05 — Campaign Narrative: Chapter 2
**Objective:** Communication and escalation chapter.

**Dependencies:** M4.0, M2.13, M2.14

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Mission difficulty increase
- Narrative escalation (agent discovers deception)
- Guard coordination theme

**Acceptance Criteria:**
- Chapter is challenging but fair
- Coordination mechanics are showcased
- Narrative moves toward climax

---

### ⏳ M4.10 — Campaign Narrative: Chapter 3
**Objective:** Final confrontation and resolution chapter.

**Dependencies:** M4.05, GAME-01

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Maximum difficulty and coordination
- Narrative climax (agent's choice: destroy Agency or go public)
- Freelance mode unlock

**Acceptance Criteria:**
- Chapter is climactic and challenging
- Player choice feels meaningful
- Freelance mode is unlocked and ready

---

### ⏳ M5.0 — Freelance Mode: Procedural Generation
**Objective:** Procedurally generated missions and difficulty scaling.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Procedural mission layout generation
- Difficulty scaling (matches player progression)
- Mission variety (different objectives, layouts)
- Infinite mission chain

**Acceptance Criteria:**
- Missions feel fair and varied
- Difficulty scales appropriately
- Procedural variety is noticeable

---

### ⏳ M5.05 — Freelance Mode: Progression Systems
**Objective:** Character progression, upgrades, and infinite scaling.

**Dependencies:** M5.0

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Character leveling system
- Equipment upgrades
- Skill unlocks
- Difficulty scaling (keeps pace with character power)

**Acceptance Criteria:**
- Progression is rewarding
- Difficulty remains challenging
- No trivializing mechanics

---

### ⏳ MONET-01 — Shop, Economy & Social Surface *(new 2026-08-14, Director direct)*
**Objective:** The revenue half of the endless model — shop, currency, cosmetic
delivery, gifting, and the forum/lobby where a player's avatar is seen by other
players.

**Dependencies:** M5.05. Progression must exist before there are tiers to hang
cosmetics on, and before any of this can be balanced against a real game.

**Placed here deliberately, and NOT before optimization.** The Director asked
where this belongs (*"Colocar antes da otimização do código? Ou trabalhar nisso
quando a engine já estiver funcionando?"*). The answer is that monetisation has
**two halves with opposite schedules**, and only one of them is a milestone:

- **The asset contract — already ratified, and it lands with the character, not
  here.** What is a baked layer vs. a runtime uniform (`ACTOR_MASTER_PLAN` D34),
  cosmetics may express state but never grant it (D36), the tier→silhouette
  model (D33). These had to be settled *before the first character asset is
  authored*, because the asset pipeline is built around them — which is why they
  are D-rows in the actor plan and not deliverables in this milestone.
- **The store itself — this milestone.** Cannot be tuned before there is a game
  to tune it against.

Building the store early and deciding the asset contract late would have been the
two available mistakes; this split avoids both.

**Estimated Duration:** not estimated.

**Deliverables:**
- Shop + currency/economy; ads integration per `DESIGN_MASTER_PLAN` §16
- Cosmetic catalog and delivery — the natural carrier is `TextureResolver`'s
  `user:// → default:// → material-only` chain (`ACTOR_MASTER_PLAN` D38: the
  bake **compositor** does not transfer to characters, but that fallback ladder
  is exactly a per-player content-delivery contract)
- Gifting power-ups between players — *"sem ficar infernizando com lembretes, nem
  depender disso pra jogar"* (Director), and guarded by D36/§16: acceleration
  toward freely earnable power, never exclusive power or store-dependent
  readability
- Forum / lobby surface where the big 3D display model (D33/D35) is the avatar
- Item market (`DESIGN_MASTER_PLAN` §16, `[Future]`) — still future, still open
  in §18

**Acceptance Criteria:**
- The full campaign, Freelance and every power have a viable free/offline path;
  paid boosts only accelerate the same earnable progression
- Ads remain voluntary extra options after conventional play options, never an
  automatic toll on ordinary missions
- No purchased random rewards or FOMO mechanics in the all-ages product
- Every purchasable state indicator has a non-purchasable fallback (D36 / actor
  plan §7 #24)
- Economy is tunable from data, per §19 Rule 1

**Documentation review, 2026-08-14 (Director-requested — *"veja se não tem nada
sobre a monetização no arquivo histórico ou no repo"*).** Searched
`milestones.md`, `roadmap.md`, `current_state.md`, the design-concepts archive
and the whole repo. **Result: nothing existed.** No monetisation milestone
anywhere across 40+ milestones. The entire body of monetisation design is
`DESIGN_MASTER_PLAN` §16 (nine table rows) and its Portuguese original,
`docs/history/design-concepts/infiltraitor_master_design.md` §15 — the same nine
rows, not additional material — plus scattered `[Future]` mentions in
`roadmap.md`. Every other repo hit for "cosmetic" means *merely visual* (shadow
spill, halos), not commerce. **This milestone is therefore the first monetisation
artifact in the project.**

---

### ⏳ M6.0 — Audio Design
**Objective:** Complete sound design and music.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- SFX library (footsteps, detection, alarms, etc.)
- Music composition (adaptive soundtrack)
- Ambiance and environmental audio
- Localization (multiple languages)

**Acceptance Criteria:**
- Audio design supports stealth atmosphere
- Music is adaptive and responsive
- Localization is complete

---

### ⏳ M6.05 — Visual Polish
**Objective:** Animation, particles, and visual refinement.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Guard animations (movement, detection, investigation)
- Agent animations (various poses, states)
- Particle effects (noise, detection, alerts)
- UI animation and polish

**Acceptance Criteria:**
- Animations feel weighty and responsive
- Particles enhance readability
- UI feels native and polished

---

### ⏳ M7.0 — Release Prep: QA & Optimization
**Objective:** Bug fixing, performance optimization, and platform preparation.

**Dependencies:** M6.05

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Comprehensive QA pass
- Performance optimization (target 60 FPS on 5-year-old devices)
- **Baking System cache + decals — final verification pass** *(Director-assigned
  2026-08-13; see the note below)*
- **Pose and clothing bake cache** *(Director-assigned 2026-08-14)* — *"Vamos
  fazer o cache nas poses e roupas também se possível."* The character's frame
  catalog is far larger than the wall atlas it would extend: `CHARACTER_MASTER_PLAN`
  §8 puts the authored body sets in the hundreds-to-thousands, against a resident
  set measured in tens of MB. The existing cross-session bake cache
  (`BAKE_CODE_VERSION` / `DAMAGE_BAKE_LOCAL_VERSION`) is the precedent to extend,
  **not a new mechanism**. Lands here rather than earlier for the same reason as
  the row above: a cache's whole job is to be invisible until the art under it
  changes, so verifying it against placeholder poses proves the mechanism and not
  the shipping condition.
- Platform-specific builds (iOS, Android, Web)
- Final balance tuning

**~~W-PRECOOK~~ MOVED OUT 2026-08-13, same day it was assigned here** — the
Director pulled firearm pre-production forward to the **last item of GAME-01
(Combat System Foundation)**: *"pode colocar o W-PRECOOK mais cedo, vamos fazer
ele no final da milestone de combate."* See GAME-01 for the full note.

**Baking System cache + decals — final verification (Director-assigned
2026-08-13).** *"Coloca um lembrete para a gente tratar o cache do baking system
+ decals na última etapa da otimização."*

- **What to verify:** that swapping a texture set correctly invalidates the bake
  cache, that `BAKE_CODE_VERSION` / `DAMAGE_BAKE_LOCAL_VERSION` do what they
  promise, and that damage decals recomposite over new art.
- **Why it lands here and not earlier:** this is the pass that has to hold
  against the *final* art, and the cache's whole job is to be invisible until
  the art underneath it changes. Verifying it against placeholder sets proves
  the mechanism, not the shipping condition.
- **Not to be confused with the Director's own smoke test** — an informal check
  by swapping texture files in the folders directly, run by the Director in
  August 2026 and **explicitly off the agent's list**. That check answers "does
  it obviously work"; this deliverable answers "does it hold for release."
- **Reference:** `docs/technical/BAKE_SYSTEM_REFERENCE.md`,
  `ASSETS/ART_SPECIFICATIONS.md` §7 (damage decals).

**Acceptance Criteria:**
- Zero critical bugs
- Performance stable on target devices
- Deployment successful
- Analytics ready

---

### ⏳ M7.05 — Soft Launch & Analytics
**Objective:** Soft launch with analytics collection and user feedback.

**Dependencies:** M7.0

**Estimated Duration:** 2–4 weeks

**Deliverables:**
- Soft launch on limited markets
- Analytics dashboard
- User feedback collection
- Balance tuning based on data

**Acceptance Criteria:**
- Soft launch is successful
- Analytics are being collected
- User feedback is positive
- Balance tuning underway

---

## Blockers & Risks (updated 2026-07-26)

| Milestone | Blocker | Status | Mitigation |
|-----------|---------|--------|-----------|
| **VIS-01** | — | 🟡 Largely absorbed — occlusion split into `OCCLUSION_MASTER_PLAN.md` (Parts 1-3 done, paused), floor shadows + voxel light shipped | Remaining scope (Slice C/D, item #3 view-occlusion polish) is small; no active work |
| AI-01 / AI-02 / AI-03 | Visual system (VIS-01) | ⏸ Gate condition largely met — see re-evaluation note above | **Director decision needed:** resume AI tuning now, or sequence after animation/shotgun work? |
| CONTENT-01 | AI track + VIS-01 | ⏸ DEFERRED | Still gated by AI-02 tuning specifically |
| GAME-01 (Combat) | AI-03 complete | ⏸ DEFERRED | Do not start before the FSM refactor |
| Destruction Part 4+ (cover/noise/fire, shot-based destruction) | Lighting (VOXEL_LIGHT) | 🟢 UNBLOCKED 2026-07-26 | Ready to resume; not yet scheduled |
| Ranged weapon (shotgun) + shot-based wall destruction | ~~New mechanism~~ | 🟢 **BUILT (miss path) 2026-07-30 / 2026-08-02** — row updated 2026-08-13 | CONE (`select_cone_pellet_impacts()`) and LINE (`apply_point_impact()`) both ship and are selftested; a real shot breaks real voxels with material response, bullet marks and face-local soot. **What remains is the HIT half** — there is no actor to shoot at (`WEAPON_MASTER_PLAN` S8), which is the ACTOR track's job, not this row's |
| **Firearm aim mode** (weapon slots, target cycling, hit %, pre-resolution) | Agent model that holds a weapon | 🟡 **DESIGNED 2026-08-13, unbuilt — scheduled into GAME-01** | Flow + decisions: `WEAPON_MASTER_PLAN` §5c / D31–D36; gameplay statement: `DESIGN_MASTER_PLAN` §8.7. Of the six COMBAT-wave questions (§7c), **Q1 and Q2 were closed by the Director 2026-08-13** (D37/D38); four remain, none blocking the shape of the work |
| **W-PRECOOK** (firearm pre-production, ~310 ms/shot) | Aim mode built + an agent holding a weapon | ⏸ **DEFERRED 2026-08-13 → last item of GAME-01** | Assigned to M7.0 and pulled forward to the end of the combat milestone the same day. Measurement and both routes unchanged in `WEAPON_MASTER_PLAN` §0 |
| **Baking System cache + decals** — final verification against the shipping art | Final texture sets | ⏸ **SCHEDULED 2026-08-13 → M7.0** (last optimization stage) | Director runs an informal swap-the-files smoke test himself in the meantime; that is **not** this deliverable and is off the agent's list |
| **ACTOR living-beings track** (character model, poses, weapon layering) | ~~D18 sequencing deferral~~ | 🟢 **RUNNING.** Designed 2026-08-14 (D32–D45), extended 2026-08-15 (D46–D51). Part 0 CLOSED, Part 1 BUILT | Execution moved to `PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md` (v2.0); `ACTOR_MASTER_PLAN` keeps the decisions. **Reordered by D48** — the professional showcase model comes first and is the design authority, so Part 2 (and with it firearm aim mode + W-PRECOOK) waits on it |
| ART-01 (Materials & Objects) | Scenario + gameplay complete (Alpha) | ⏸ SCHEDULED (Alpha → Beta) | Specs pre-written in `ASSETS/ART_SPECIFICATIONS.md`; **Director is now asking about character/animation work ahead of this window — see engine assessment for the sequencing question** |
| M4.0 (Campaign) | Investment | Waiting on investor demo | — |
| M5.0 (Procedural) | Generation algorithm | At risk | Templates initially |
| M6.0 (Audio) | Audio assets | At risk | Hire externally if needed |

---

## Next Steps (updated 2026-07-26)

The original sequence (VIS-01 → AI track → CONTENT-01 → Investor Demo) was
overtaken by the two-month voxel architecture pivot — none of that work was
AI tuning, all of it was rendering/destruction/lighting engine work. That
work is now largely done. Concrete open decisions, in the order they were
raised:

1. **Shot-based destruction (shotgun)** — needs a new trigger analogous to
   the grenade one (`bomb_def.gd`/`blast_calculator.gd` pattern), a shotgun
   prop positioned at a GU, and likely a directional/cone blast shape instead
   of the grenade's omnidirectional rings. Not scoped yet — see engine
   assessment.
2. **Character/animation asset pipeline** — 3D-rendered low-poly sprites,
   per-object lighting coherent with the voxel scene, rotation-frame count.
   See engine assessment + the design-consultation answer for the specifics.
3. **AI tuning (AI-02) resume timing** — gate condition is largely met; needs
   an explicit Director call on sequencing against 1–2 above.
4. **ART-01 window** — was scheduled for "after scenario and gameplay are
   complete." If character/animation work starts now, that changes what
   "complete" means for this gate — flagging, not deciding.

See: `docs/production/roadmap.md` for the macro view of the phases
See: `docs/production/technical_debt.md` for blocker details
See: `docs/production/current_state.md` for the maintained per-domain status

---

## Next Steps — superseding update (2026-08-13)

The four items above were written on 2026-07-26 and three of them have since
been answered by events. Read this section, not that one, for what happens next.

1. **Shot-based destruction** — ✅ **done for the miss path.** CONE and LINE both
   ship; the hit path has no fixture because no actor can be shot at yet.
2. **Character/animation asset pipeline** — 🟢 **this is now the active work.**
   The Director lifted `ACTOR_MASTER_PLAN` D18's living-beings deferral on
   2026-08-13: *"Agora chegou a hora de produzir realmente o personagem."* The
   design conversation is open; no plan is written yet, and nothing should be
   built until it is. **This is also the gate on two other items** — W-PRECOOK
   (M7.0) and firearm aim mode both wait on an agent that holds a weapon.
3. **AI tuning (AI-02) resume timing** — still an open Director call, unchanged
   since 2026-07-26. Not raised in the 2026-08-13 session.
4. **ART-01 window** — the question flagged in 2026-07-26 ("if character work
   starts now, that changes what 'complete' means for this gate") is no longer
   hypothetical. Character work is starting. **ART-01's gate condition needs
   re-reading against that** — flagging, not deciding.
5. **New (2026-08-13):** firearm aim mode is designed and unbuilt
   (`WEAPON_MASTER_PLAN` §5c), and scheduled into **GAME-01** with W-PRECOOK as
   that milestone's last item. Of the six §7c questions, the two that would have
   changed the shape of the work were closed by the Director the same day:
   the loadout is **not** restricted to one weapon (D37) and the target list is
   **not** capped (D38). The four that remain are balance and scope questions.
6. **Off the agent's list (Director, 2026-08-13):** the Baking System cache
   check. The Director runs it himself by swapping texture files in the folders.
   A **separate**, formal verification of cache invalidation + decal
   recompositing against the shipping art is scheduled as the last optimization
   stage — M7.0.
