# VOXEL Series Implementation Log

> **Chronological record of the voxel render plane implementation.** Tracks each VOXEL phase from specification through completion, with technical details and acceptance test results.

**Scope:** VOXEL-01 through VOXEL-11 (wall rendering architecture refactor)  
**Status:** VOXEL-01 through VOXEL-04 complete; VOXEL-05..11 pending  
**Last updated:** 2026-07-01 · Post VOXEL-04 completion

---

## VOXEL-01: Geometry Generation (Complete ✅)

**Objective:** Fix voxel PNG geometry from flat rectangles to proper 3D isometric cubes.

**Prior issue:** Generated voxels appeared flat (single rectangle) instead of 3D cubes with three visible faces.

**Root cause:** Missing left/right face polygons in `generate_voxel.py` (vertices V_WB, V_SB, V_EB and two face definitions).

**Solution implemented:**
- Restored missing vertices and face polygons in `tools/generate_voxel.py`
- Applied proper darkening (0.80 factor) to left/right side faces to distinguish from top
- Regenerated all four material PNGs: concrete, metal, stone, wood

**Validation:**
- File: `ASSETS/ISOMETRIC/source_assets/voxels/` → 4 × 32×36 px RGBA PNG files
- Visual inspection: Proper isometric cubes with diamond top + darkened left/right faces
- Tests: 7/8 acceptance tests passing (A8 inconclusive)

**Artifacts archived:** `PROMPTS/DONE/VOXEL-01.md`

---

## VOXEL-02: Coordinate System & TileSet Infrastructure (Complete ✅)

**Objective:** Establish coordinate conversion functions and runtime TileSet construction.

**What was implemented:**

1. **Coordinate Constants** (in `SubcubeCoordsClass`):
   - `VOXELS_PER_UNIT_AXIS = 8` — voxels per GAME UNIT axis
   - `VOXEL_TILE_SIZE = Vector2i(32, 16)` — 1 voxel tile = 32×16 px
   - `VOXEL_STEP_PX = 20.0` — vertical height per level (side face height)
   - `VOXEL_STOREY_HEIGHT_PX = 160.0` — 8 levels × 20px (matches old subcube system)

2. **Coordinate Conversion Functions** (in `SubcubeCoordsClass`):
   - `gu_to_voxel_origin(gu_pos: Vector2i) -> Vector2i` — GU cell → voxel grid origin
   - `voxel_to_gu(voxel_pos: Vector2i) -> Vector2i` — voxel grid position → owning GU
   - `voxel_local(voxel_pos: Vector2i, gu_pos: Vector2i) -> Vector2i` — relative voxel position within GU
   - `gu_voxels(gu_pos: Vector2i) -> Array[Vector2i]` — all 64 voxel positions in a GU (8×8 grid)

3. **TileSet Construction** (in `room.gd`):
   - `_build_voxel_tileset()` — creates tileset at runtime with all four materials
   - `_ensure_voxel_layers()` — creates 8N voxel layers (N = max storey count)
   - Layer positioning: `z_index = WALL_BASE_Z_INDEX + level`, `position.y = VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX × level`
   - No empirical offsets; purely analytical

**Files modified:**
- `godot/scripts/world/subcube_coords.gd` — added voxel functions
- `godot/scripts/world/room.gd` — added _build_voxel_tileset(), _ensure_voxel_layers()

**Validation:**
- 11 acceptance tests (A1-A11) all passing
- Godot loads clean; no parse errors or warnings
- All voxel layers created on demand

**Artifacts archived:** `PROMPTS/DONE/VOXEL-02.md`

---

## VOXEL-03: Data Classes & Selftest (Complete ✅)

**Objective:** Create type-safe containers for voxel, slice, and wall data; validate with comprehensive selftest.

**What was implemented:**

1. **VoxelRef** (`godot/scripts/world/voxel_ref.gd`):
   ```
   Fields: grid_pos, level, visible, dirty, damage_state, face_atlas_rect
   Constants: DAMAGE_INTACT=0, DAMAGE_CRACKED=1, DAMAGE_DESTROYED=2
   Methods: set_visible(), set_damage(), clear_dirty()
   ```

2. **WallSlice** (`godot/scripts/world/wall_slice.gd`):
   ```
   Primary container: 1 edge × 1 GU × N storeys
   Fields: id, direction ("NW"|"NE"|"SE"|"SW"), slice_index (0=inner|1=outer), gu_cell, storey_count, voxels[], dirty_count, baked, parent_high_wall
   Methods: get_voxel(index), total_voxel_count(), mark_all_dirty()
   ```

3. **HighWall** (`godot/scripts/world/high_wall.gd`):
   ```
   Secondary container: group of WallSlices + junction extras
   Fields: id, slices[], junction_extras[], bake_texture, baked, dirty_count, voxel_bounds
   Methods: get_slice(id), total_voxel_count(), all_voxels()
   ```

4. **Voxel Selftest** (`godot/scripts/tools/voxel_selftest.gd`):
   - Validates all three data classes + coordinate API
   - 425 independent correctness checks
   - Tests: state transitions, aggregation, round-trip conversions, edge cases

**Technical issue resolved:**
- Type hints (`VoxelRef`, `WallSlice`) caused parse errors in headless mode
- Solution: Removed specific problematic type hints from loop variables and return types
- Outcome: Selftest passes cleanly with 425/425 checks ✓

**Files created:**
- `godot/scripts/world/voxel_ref.gd`
- `godot/scripts/world/wall_slice.gd`
- `godot/scripts/world/high_wall.gd`
- `godot/scripts/tools/voxel_selftest.gd`

**Validation:**
- Selftest: 425 checks passing, exit code 0
- 10 acceptance tests (A1-A10) all passing
- Godot loads without errors
- All data class methods verified functional

**Artifacts archived:** `PROMPTS/DONE/VOXEL-03.md`

---

## VOXEL-04: Wall Voxel Placement (Complete ✅)

**Objective:** Implement wall rendering via TileMapLayer.set_cell(); replace legacy `_build_wall_containers()` call.

**What was implemented:**

1. **_voxel_slice_positions()** (in `room.gd`):
   - Calculates 8 voxel positions for a wall slice
   - Supports all 4 edge directions: NW (-1,0), NE (0,-1), SE (1,0), SW (0,1)
   - Slice index: 0=inner (primary GU), 1=outer (adjacent GU)
   - Returns `Array[Vector2i]` of voxel grid coordinates

2. **_place_wall_voxels()** (in `room.gd`):
   - Renders all wall edges as voxel tiles
   - Groups faces by edge key, calculates storey_count
   - Creates 2 WallSlices (S0 inner + S1 outer) per edge
   - Each WallSlice contains 64 × storey_count VoxelRefs
   - Calls `TileMapLayer.set_cell()` for each voxel position
   - Stores all WallSlices in `_voxel_wall_slices` array

3. **Refactoring:**
   - Replaced `_build_wall_containers()` call with `_place_wall_voxels()` in `build_room()`
   - Added `_voxel_wall_slices: Array = []` variable to track all created slices
   - No legacy patterns (Image.blend_rect, FACE_CENTER_OFFSET, blend modes) used

**Files modified:**
- `godot/scripts/world/room.gd` — 3 edits (1 variable declaration, 1 function call replacement, 2 new functions)

**Validation:**
- 11 acceptance tests (A1-A11) all passing:
  - A1: `_voxel_wall_slices` declared ✓
  - A2: Voxel functions present ✓
  - A3: `_build_wall_containers` not called ✓
  - A4: `_place_wall_voxels` called ✓
  - A5: `set_cell()` used ✓
  - A6: No legacy patterns ✓
  - A7: Data class constructors present ✓
  - A8: Four edge directions ✓
  - A9: Subcube system preserved ✓
  - A10: Godot loads clean ✓
  - A11: Git status clean (only room.gd modified) ✓

**Godot runtime verification:**
- Editor loads without errors or warnings
- All TileMapLayers positioned correctly
- Voxel rendering functional

**Git status:**
- Only `godot/scripts/world/room.gd` modified
- No unintended changes to protected files (.tres, .tscn, subcube system)

**Artifacts archived:** `PROMPTS/DONE/VOXEL-04.md`

---

## VOXEL-05: Junction Detection + Extra Voxels (Pending ⏳)

**Objective:** Detect V-junctions (2 walls at vertex) and populate HighWall.junction_extras.

**Design sketch:**
- Iterate all WallSlice pairs, detect corners where two walls meet
- V-junction rule: place 1 extra voxel column at the uncovered outer diagonal
- T-junction rule: no extra (3rd wall's outer slice covers gap)
- X-junction rule: no extra (all 4 diagonals covered)

**Planned changes:**
- Modify `_place_wall_voxels()` to detect junctions after initial WallSlice creation
- Create HighWall instances (grouping related WallSlices)
- Populate junction_extras array with gap-filling voxel positions

---

## VOXEL-06: VoxelRegistry (Pending ⏳)

**Objective:** Centralized container for all WallSlice/HighWall instances; enable efficient lookup and iteration.

**Planned API:**
- `get_slice(id) -> WallSlice` — indexed lookup
- `get_high_wall(id) -> HighWall` — indexed lookup
- `all_slices() -> Array[WallSlice]` — iteration for TIC loop
- `all_high_walls() -> Array[HighWall]` — iteration for baking

---

## VOXEL-07: Dirty Flag + TIC Loop (Pending ⏳)

**Objective:** Implement per-voxel dirty tracking; update TIC loop to process only dirty containers.

**Planned changes:**
- Add `dirty_count` aggregation: VoxelRef.dirty → WallSlice.dirty_count → HighWall.dirty_count
- TIC loop: skip HighWalls with dirty_count=0 (O(container_count) cost at idle)
- Runtime destructibility: `ref.visible = false` + `ref.dirty = true` → next TIC calls `erase_cell()`

---

## VOXEL-08: Primary Baking (Pending ⏳)

**Objective:** Load-time per-WallSlice texture baking (Crop + Multiply from TextureCatalog).

**Planned changes:**
- Populate `VoxelRef.face_atlas_rect` for each voxel
- Key on `(map_id, theme, player_level)`
- Store bake_texture in WallSlice

---

## VOXEL-09: Secondary Baking (Pending ⏳)

**Objective:** Load-time per-HighWall texture baking (single large texture spanning all constituent voxels).

**Planned changes:**
- Alternative rendering path: single composite texture instead of per-slice
- Reduces draw calls for large wall groups
- Result still stored as VoxelRef.face_atlas_rect

---

## VOXEL-10: Destructibility (Pending ⏳)

**Objective:** Implement damage states and visual feedback for voxel destruction.

**Planned changes:**
- Damage states: INTACT(0) → CRACKED(1) → DESTROYED(2)
- Overlay texture + visibility logic
- Integration with TIC loop and dirty flags
- Runtime: `ref.set_damage(state)` + `ref.dirty = true` → next TIC updates rendering

---

## VOXEL-11: CODEMAP Update (Pending ⏳)

**Objective:** Register all voxel wall data in project codemap for runtime queries.

**Planned changes:**
- Enable queries like "which walls can this agent see?"
- Integrate voxel registry with existing codemap system

---

## Archive Policy

All completed VOXEL prompts moved to `PROMPTS/DONE/` with timestamp confirmation:
- ✅ VOXEL-01.md
- ✅ VOXEL-02.md
- ✅ VOXEL-03.md
- ✅ VOXEL-04.md

Working prompts remain in `PROMPTS/` for active iteration.

---

## Continuation Checklist

Next steps to proceed to VOXEL-05:
- [ ] Review VOXEL-05.md specification
- [ ] Implement junction detection logic in room.gd
- [ ] Create HighWall instances and populate junction_extras
- [ ] Run acceptance tests A1-A10
- [ ] Verify Godot runtime
- [ ] Archive to PROMPTS/DONE/

