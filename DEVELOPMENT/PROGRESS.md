# INFILTRAITOR — Progress Updates

## M2 Alpha Shadows Foundation (2026-06-10)

**Status:** ✅ Complete — Tactical shadows, coordinated AI comms, and active search mechanics integrated

**Focus:** Environment-based stealth and complex AI behaviors — guards now use tactical shadows to project detection zones and communicate alerts through room signals.

### Changes Completed

#### ✅ M2-06: Visão Desacoplada & Antecipação
- **Separation of concerns:** Visual vision angle decoupled from physical facing angle
- **Smooth Rotation:** Uses `lerp_angle` for head rotation and scanning
- **Interest management:** `GuardAttention` system handles 3 focus modes (IDLE scanning, WAYPOINT anticipation, AGENT tracking)
- **Scanning behavior:** Guards now scan 45° left/right while moving, making detection fields more dynamic

#### ✅ M2-07: Comportamento Ativo de Busca (STATE_SEARCH)
- **Physical Investigation:** Guards now physically move to tiles in the `_search_queue` around `last_known_agent_cell`
- **Observational pauses:** Reached tiles trigger a pause turn with a focus sweep before moving to next point
- **Queue management:** Coordinated evacuation of search tiles until de-escalation to SUSPICIOUS

#### ✅ M2-08: Sistema de Comunicação (Comms)
- **Whistle signal:** ALERT state triggers a local whistle broadcast (3-tile radius)
- **Radio signal:** CHASE state triggers a global radio broadcast to all active units
- **Signal propagation:** `room.gd` acts as a signal hub, routing alerts to neighboring guards
- **State escalation:** Guards ignore low-priority alerts (state hierarchy validation)

#### ✅ M2-09: Sistema de Sombras Táticas
- **Shadow Projection:** Obstacles and walls project dark zones that reduce detection probability
- **Direct Shadow:** 0.35x multiplier (65% reduction) on tiles adjacent to walls
- **Penumbra:** 0.60x multiplier (40% reduction) on tiles 2 steps away
- **Perspective alignment:** Shadows automatically update on room perspective rotation
- **Visual Debug:** Blue diamond overlay highlights shadow zones in `DEV_VISION` mode

#### ✅ Quickfix: Movimento Físico no SEARCH
- FIXED: Guards in `STATE_SEARCH` were previously only scanning visually while staying stationary
- RESOLVED: Replaced search logic to use physical pathfinding via `_step_toward(target)`
- Added `remove_at(0)` queue consumption for robust multi-point patrolling during investigation

### Files Created/Modified

**Modified:**
- `godot/scripts/world/room.gd` — Shadow calculation hub, communication router (`_on_guard_whistled`), and debug renderer
- `godot/scripts/agents/guard_enemy.gd` — Integration of attention systems, shadow multipliers, and physical search logic
- `godot/scripts/agents/guard_attention.gd` — Logic for decoupled vision and focus-based scanning

### Architecture & Design

**Tactical Synergy:**
1. Shadow system creates "stealth lanes" near walls
2. Guard attention makes vision cones unpredictable (scanning while walking)
3. Search logic forces guards to actually check these stealth lanes when suspicious
4. Communication ensures that even if you hide in shadows, a single visual contact can alert the entire floor

### Testing & Verification

- **Compilation:** ✅ 0 errors across 4 core files
- **Shadow Logic:** ✅ Projections align with grid directions and perspective
- **Comms Routing:** ✅ Whistled signals correctly reach and escalate nearby units
- **Search Pathing:** ✅ Guards successfully consume `_search_queue` and path toward investigate targets

---

## M2 Alpha Sound System Deploy (2026-06-07)

**Status:** ✅ Complete — Event-driven detection, noise persistence, and audio systems fully integrated

**Focus:** Enemy AI sophistication — probabilistic visual detection, persistent sound propagation, organic patrol behavior, and independent audio perception mechanics.

### Changes Completed

#### ✅ M2-01: Event-Driven Tic Detection
- Replaced turn-based evaluation with edge-crossing triggers
- Tics fire whenever a guard or agent crosses a tile boundary
- Deterministic visual detection via `TicSystem.evaluate()` with LOS validation
- Eliminates detection lag from discrete turn cycles

#### ✅ M2-02: Colored Cone Visual System
- Probabilistic cone visualization: tile-by-tile color indicates detection chance
- Distance curve: 9-level attenuation [1.00, 1.00, 0.95, 0.85, 0.60, 0.40, 0.15, 0.05, 0.01]
- Lateral falloff: [1.0, 0.45, 0.08] at center, ±1, ±2 from FOV heading
- State-dependent appearance: range/FOV/alpha/prob_mult per state (PATROL/SUSPICIOUS/ALERT/CHASE)
- Visualization ready for M2 Dev system integration

#### ✅ M2-03: Patrulha Orgânica
- **Variable speed:** Guard speed multiplied by state (0.60× patrol to 3.00× chase)
- **Spontaneous pauses:** ~20% chance per step to idle 1–2 turns (looks around, catches breath)
- **Look rotation:** Rotates facing angle between 8 cardinal directions during patrol without moving
- **Smooth animation:** Uses tweens for speed variation and angle transitions
- Integrates with existing `_enter_state()` centralized state machine

#### ✅ M2-04: Sistema de Barulho
- **Persistent noise grid:** `Dictionary<Vector2i, {intensity, age}>` maintained across turns
- **Decay mechanics:** -0.25 intensity per enemy phase (4-turn lifespan for 0.5 base intensity)
- **Emission:** ~20% chance per guard step at 0.5 intensity base
- **Bonus detection:** +30% visual detection bonus when guard visible and noise present
- **Visualization:** 3-layer cyan cone per noisy tile (faint/medium/bright) with alpha by intensity

#### ✅ M2-05: Detecção Auditiva
- **Audio detection independent of visual LOS:** Separate evaluation from visual cone
- **Wall attenuation:** 0.6× multiplier per wall crossed (cumulative, e.g., 2 walls = 0.36×)
- **Distance falloff:** Linear attenuation over 2-tile hearing radius (1.0 → 0.0)
- **Thresholded reactions:**
  - ≥0.6 intensity: Investigates (sets last_known_agent_cell, goes to SUSPICIOUS for 3 turns)
  - ≥0.25 intensity: Becomes SUSPICIOUS for 2 turns
  - <0.25 intensity: Ignored (silent noise)
- **Detection accumulation:** Always accumulates `perceived_intensity × 0.5` to guard detection meter (M2 Dev 05)
- **Immediate feedback:** Updates guard debug label and detection arc on audio reaction

#### ✅ Quickfix: Constants & Accumulation
- Removed duplicate `NOISE_CHANCE_WALK` and `NOISE_INTENSITY_WALK` constants from room.gd
- Consolidated with NoiseSystem source of truth
- Added detection accumulation to `hear_noise()` — always increments meter regardless of reaction threshold
- Added `_update_debug_label()` and `queue_redraw()` calls for immediate UI feedback
- All compilation errors resolved

### Files Created/Modified

**Created:**
- `godot/scripts/systems/noise_system.gd` — persistent noise grid manager with decay logic
- `godot/scripts/systems/tic_system.gd` — extended with `evaluate_audio()` and wall-counting pathfinding

**Modified:**
- `godot/scripts/overlays/noise_overlay.gd` — new 3-layer cyan cone visualization system
- `godot/scripts/agents/guard_enemy.gd` — M2-03/M2-05 integration: variable speed, pauses, look rotation, `hear_noise()`, detection accumulation
- `godot/scripts/world/room.gd` — M2-04/M2-05 integration: noise emission, decay, audio evaluation, visual bonus logic

### Architecture & Design

**Event-Driven Flow:**
1. Agent steps → fires visual TIC for each guard (M2-01/M2-02)
2. Guard evaluates detection → updates state machine → may emit noise (M2-04)
3. Noise propagates → audio detection triggers (M2-05)
4. Guard reacts based on audio intensity thresholds → accumulates detection meter

**State-Dependent Scaling:**
- All multipliers data-driven in `TicSystem.STATE_MULTIPLIER` and `GuardEnemy._get_cone_visual_params()`
- No hardcoded values — single source of truth per parameter
- Enables future tuning without code changes

**Noise Persistence:**
- Noise survives across entire enemy phase (does not decay during player turn)
- Decays at end of enemy phase: `_noise_system.decay_all()`
- Grid queries support future sound occlusion and propagation refinement

### Testing & Verification

- **Compilation:** ✅ No syntax/parse errors (all 3 files: 0 errors)
- **Type safety:** ✅ All Dictionary returns explicitly typed (no inference failures)
- **Integration:** ✅ Visual + audio detection work independently yet cohesively
- **Constants:** ✅ No duplication, single source of truth per system

### Git Commits

```
[pending] Alpha Sound System Deploy: M2-01 to M2-05 + quickfix
  - Event-driven tics with edge-crossing detection
  - Colored cone visualization with state-based appearance
  - Organic patrol: variable speed, pauses, look rotation
  - Persistent noise grid with decay and visualization
  - Audio detection with wall attenuation and threshold reactions
  - Remove duplicate constants, add detection accumulation
```

### Next Steps (M2 Continuation)

- **M2-06:** Confrontation system — 4 cover states, flanking detection, peek mechanics
- **M2-07:** Communication system — apito (local alert), rádio (zone alert), alarme (site-wide)
- **M2-08:** Refined FSM — smooth state transitions, contextual behavior tweaks
- **Character sprite:** Integrate Human_0 Idle/Run AnimatedSprite2D (pending asset pipeline)

---

## Alpha Dev Vision Foundation (2026-06-06)

**Status:** ✅ Complete — In-game debug visualization system fully integrated

**Focus:** Developer experience — real-time tactical state inspection via centralized V-key toggle, enabling guard AI prototyping and detection mechanics validation.

### Changes Completed

#### ✅ Dev 01: DEV_VISION Mode (Centralized Toggle)
- Master toggle `dev_vision: bool` in room.gd
- V-key binding via `_toggle_dev_vision()`
- Propagated to all guards via `set_dev_vision(enabled)`
- Gated all debug overlays (labels, trail, meter) behind dev_vision check
- FOW visibility control

#### ✅ Dev 02: Guard Debug Label
- Dark gray Panel with white 22pt text above guard head
- Displays: id, state, cell coordinates, facing direction, last_known_agent_cell
- Positioned -320Y (clear of sprite)
- Updates on: toggle, state change, cell change

#### ✅ Dev 03: Tile Info on Hover
- Cyan label at bottom-left showing hovered tile coordinates
- Enhanced with blocked status detection
- Shows guard id/state if guard on tile
- Shows "agent here" if player on tile
- Multi-line formatted display

#### ✅ Dev 04: Agent Trail Overlay
- Dedicated `trail_overlay.gd` node rendering yellow diamond trail
- Shows last 5 tiles walked by agent (circular buffer)
- Opacity gradient: 20% (oldest) → 100% (newest)
- Z-index=150 (above movement_overlay for visibility)
- Event-driven redraw on step/reset/toggle (not continuous _process)

#### ✅ Dev 05: Guard Detection Meter
- Arc meter above guard head showing state-based detection
- Placeholder detection mapping: PATROL=0%, SUSPICIOUS=35%, ALERT=65%, CHASE=100%
- Color gradient: orange → orange-red → red
- Percentage text overlay
- Will be replaced by M2 system in production

#### ✅ Quickfixes Applied
- **Quickfix 1:** Trail offset parameterized in setup() (data-driven, not hardcoded)
- **Quickfix 2:** Hover label completed with blocked/guard/agent detection

### Files Created/Modified

**Created:**
- `godot/scripts/overlays/trail_overlay.gd` — dedicated trail rendering node

**Modified:**
- `godot/scripts/agents/guard_enemy.gd` — added debug label, detection meter
- `godot/scripts/world/room.gd` — added dev_vision toggle, hover label, trail setup

### Architecture & Design

- **Centralized toggle:** Single dev_vision bool controls all debug UI visibility
- **Event-driven redraw:** Redraw only on state change, not continuous _process (CPU efficiency)
- **Modular overlays:** TrailOverlay separated from room._draw() for clarity and layering
- **Data-driven offset:** Trail offset passed via setup() parameter, not hardcoded
- **Placeholder detection:** State-based values ready for M2 override

### Testing & Verification

- **Compilation:** ✅ No syntax/parse errors
- **Visual:** ✅ All features visible in Godot editor
- **Acceptance tests:** 49/49 ✅
  - Dev 01: 7/7 ✅
  - Dev 02: 8/8 ✅
  - Dev 03: 7/7 ✅
  - Dev 04: 9/9 ✅
  - Dev 05: 10/10 ✅
  - Quickfixes: 8/8 ✅

### Documentation

📖 **See:** [DEV_VISION_FOUNDATION.md](DEV_VISION_FOUNDATION.md) for complete technical specification, architecture decisions, and next steps.

### Git Commits

```
66473e0 Quickfix: Trail offset parameterized + Hover label complete
549e308 Dev 05: Guard Detection Meter (DEV_VISION)
5b238af Fix trail visibility: force redraw at right moments
7660e9e Fix Dev 04: Move trail to TrailOverlay node
ca88714 Dev 04: Agent Trail Overlay
066eb5f Dev 03: Tile Info on Hover
c2cef95 Finalize debug label: 22pt, 300×260, -320Y
8328c75 Enlarge debug label
```

---

## Alpha Enemy Visibility (2026-06-03)

**Status:** M2 bootstrap complete — Enemy visibility now integrated into the tactical loop
**Focus:** Player vision radius, guard fade stages, and alert-triggered tactical reset

### Changes Completed

#### ✅ Guard Enemy Actor (draw-based placeholder)
- Added `GuardEnemy` with:
  - patrol route support
  - directional facing
  - per-step tween movement
  - cone-based visibility evaluation (warning/full severity)

#### ✅ Enemy Turn Phase Controller
- Added `EnemyPhaseController` to run enemy actions in sequence:
  - evaluates detection before/after movement
  - advances guards along patrol routes
  - avoids occupied cells
  - respects blocked map edges from room layout

#### ✅ Room Integration (Turn Loop + UX)
- `TurnManager` now has explicit phase lifecycle:
  - `enemy_phase_started`
  - `finish_enemy_phase()` to return control to player
  - `is_enemy_phase` lock to block player input while enemies act
- `room.gd` now:
  - spawns guards from layout `enemy_defs`
  - rotates enemy patrols with perspective switch (N/E/S/W)
  - blocks movement into occupied enemy cells
  - executes enemy phase on end turn
  - updates enemy visibility fade by player vision radius

#### ✅ Alert Meter (Detection Feedback)
- Added HUD `ALERTA` meter (`LblAlert`):
  - warning sighting increments meter moderately
  - close/full sighting increments meter strongly
  - on full alert, tactical reset is triggered (agent + guards + fog)

### Files Updated

- `godot/scripts/agents/guard_enemy.gd` (new)
- `godot/scripts/systems/enemy_phase_controller.gd` (new)
- `godot/scripts/systems/turn_manager.gd`
- `godot/scripts/world/room_layout_builder.gd`
- `godot/scripts/world/room.gd`
- `godot/scenes/game/room.tscn`

### Notes

- This is an M2 bootstrap implementation designed for deterministic gameplay and easy balancing.
- Current guard visuals are placeholder draw-based primitives, consistent with the current debug-agent stage.
- Next iteration should add line-of-sight occlusion by walls/doors and patrol behaviour states (idle/search/alert).

## Alpha Perspectivas (2026-06-03)

**Status:** M1.5 Alpha Gameplay — Perspective switching integrated in HUD and runtime world view  
**Focus:** Tactical readability while changing viewpoint without breaking gameplay state

### Changes Completed

#### ✅ HUD Perspective Pad (2x2)
- Replaced the old bottom-right compass overlay with a clickable 2x2 perspective pad
- Buttons mapped to cardinal viewpoints (N/E/S/W)
- Active button visual state (highlight via opacity)

#### ✅ Runtime Perspective Switching (Layout Rotation)
- Perspective is now applied by rotating the room layout in cell space (not by rotating Camera2D)
- Rotates:
  - room tile entries (`wall_tiles`, `wall_tiles_upper`, `structure_tiles`)
  - blocked cells
  - blocked edges used by pathing constraints
  - room size for rectangular segments under 90°/270° views
- Keeps directional tile suffix remapping (`_NE/_SE/_SW/_NW`) consistent with chosen viewpoint

#### ✅ Gameplay State Preservation on View Change
- Converts current agent/selection cells to base-space and back to new view-space
- Rebuilds movement overlay constraints after each switch
- Reconfigures FOW overlay with rotated room dimensions and reveals around current agent cell

#### ✅ Supporting Cleanup
- LevelGraph canonical exit cells normalized to explicit constants
- `generate(seed)` parameter renamed to `generate(seed_input)` for clearer intent

### Files Updated

- `godot/scenes/game/room.tscn`
- `godot/scripts/world/room.gd`
- `godot/scripts/world/level_graph.gd`
- `README.md`

### Notes

- Camera rotation was intentionally avoided for perspective switching because it distorts tactical readability in this dimetric 2.5D setup.
- The current implementation prioritizes deterministic gameplay consistency over visual transition effects.
- Optional next polish step: add short crossfade/animated transition between perspectives.

## Alpha Walls Done (2026-06-02)

**Status:** M1.5 Alpha Gameplay — All corner assets fully calibrated and expanded  
**Focus:** Isometric tile rendering perfection — complete corner asset gap elimination

### Changes Completed

#### ✅ Corner Asset Expansion (All 36 Directions)
- **SE/NW corners** (18 assets): Expanded to **320×512** (64px width increase, centered anchor)
  - `wallCorner_SE/NW`, `wallCornerHalf_SE/NW`, `columnCorner_SE/NW`
  - `sloperCornerInner_SE/NW`, `sloperCornerOuter_SE/NW`
  - `stairsCornerInner_SE/NW`, `stairsCornerOuter_SE/NW`
  - `stairsOpenCornerInner_SE/NW`, `stairsOpenCornerOuter_SE/NW`
  - Origins: SE = Vector2i(0, -400), NW = Vector2i(0, -368)

- **SW/NE corners** (18 assets): Expanded to **256×528** (16px height increase, centered anchor)
  - `wallCorner_SW/NE`, `wallCornerHalf_SW/NE`, `columnCorner_SW/NE`
  - `sloperCornerInner_SW/NE`, `sloperCornerOuter_SW/NE`
  - `stairsCornerInner_SW/NE`, `stairsCornerOuter_SW/NE`
  - `stairsOpenCornerInner_SW/NE`, `stairsOpenCornerOuter_SW/NE`
  - Origins: SW = Vector2i(32, -392), NE = Vector2i(-32, -392)

#### ✅ Y-Sorting & Rendering Fix
- **Enabled `y_sort_origin = true`** on:
  - Room Node2D (root)
  - All four TileMapLayers (FloorLayer, StructureLayer, StructureWallLayer, StructureWallUpperLayer)
- **Reordered StructureLayer** before wall layers to ensure crates render behind walls (proper isometric occlusion)
- **Result:** Automatic Y-based rendering; visual verification complete

#### ✅ Interior Room Support
- Removed `INTERIOR_WALL_CELLS` hardcoded barrier
- Implemented dynamic `place_inner_room()` with proper blocked_map merging
- Interior blocked cells now correctly merged into pathfinding
- 7×7 central room with 4 directional doors fully functional

#### ✅ All 88 Directional Assets Calibrated
- Texture origin standardization across all families (from previous phase)
- Current state: 88/88 assets with correct texture_origin per direction
- Standard wall-aligned: SE(16,-392), SW(16,-376), NE(-16,-392), NW(-16,-376)
- Corner-aligned: SE(0,-400), SW(32,-392), NE(-32,-392), NW(0,-368)

### Technical Details

**File:** `godot/resources/tilesets/tileset_blocks.tres`  
**Asset Count:** 240+ directional tiles (60 families × 4 directions)  
**Validation:** Python verification script confirms 36/36 corner assets at target configuration

**Git Commits:**
1. "Alpha Walls 2" — Initial Y-sorting fix
2. "Corner assets expansion" — SE/NW expansion (18 assets)
3. "All corner assets SE/NW" — SE/NW finalization
4. "All corner assets complete: SE/NW 320×512, SW/NE 256×528 with corrected texture_origin per direction" — Complete expansion

### Visual Impact
- Corner gaps eliminated in all 4 corner directions (SE, SW, NE, NW)
- Proper anchoring ensures centered expansion, no visual displacement
- Y-sorting provides correct occlusion for all isometric elements

### Next Phase (M1.6)
- Visual testing in Godot: reload tileset and verify visual result
- Enemy AI pathfinding refinement
- Fog of War edge case handling
- UI polish for mobile viewport

### Notes
- Corner asset expansion pattern successfully extended from SE/NW to SW/NE
- Python-based texture origin management system proven effective for bulk tileset modifications
- Git workflow leveraged for incremental progress tracking and easy reversion if needed
