# INFILTRAITOR — Progress Updates

## Alpha Enemies Deploy (2026-06-03)

**Status:** M2 bootstrap complete — Enemy system integrated into tactical loop and deployment state locked
**Focus:** First playable guard patrol + detection + enemy turn phase

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
