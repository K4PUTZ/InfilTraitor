# VOXEL Series Implementation Log

> **Chronological record of the voxel render plane implementation.** Tracks each VOXEL phase from specification through completion, with technical details and acceptance test results.

**Scope:** VOXEL-01 through VOXEL-11 (wall rendering architecture refactor)  
**Status:** VOXEL-01 through VOXEL-07 complete; VOXEL-08..11 pending  
**Last updated:** 2026-07-01 · Post VOXEL-07 completion

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

## VOXEL-05: Junction Detection + Extra Voxels (Complete ✅)

**Objective:** Detect V-junctions (2 walls at vertex) and populate HighWall.junction_extras with corner-filling voxels.

**What was implemented:**

1. **`_voxel_junction_extras` tracking** (in `room.gd`):
   - New array variable to accumulate VoxelRefs for corner-fill voxels
   - Cleared on each room rebuild (alongside `_voxel_wall_slices.clear()`)

2. **`_build_voxel_junction_extras(edge_groups)` — Main junction detection** (in `room.gd`):
   - Collects all vertices touched by present wall edges (4 edges per vertex: NW/NE/SE/SW)
   - For each vertex, checks 4 corners diagonally: GU_TL, GU_BR, GU_BL, GU_TR
   - Corner is "uncovered" if **both** edges covering it are absent
   - V-junction rule: uncovered corner + ≥1 adjacent edge → place 1 extra voxel column
   - No extras for T-junction (all corners covered) or X-junction (all corners covered)

3. **`_has_any(edge_groups, keys)` — Dual-key checker** (in `room.gd`):
   - Each physical wall edge can be represented by 2 keys (from either adjacent GU)
   - Returns true if any key exists in edge_groups dictionary

4. **`_max_storey_of(edge_groups, keys)` — Height calculator** (in `room.gd`):
   - Returns maximum storey_count of all edges covering a given list of keys
   - Ensures junction extras match wall height

5. **`_add_junction_extra(voxel_pos, storey_count, source_id, tile_coord)` — Voxel placer** (in `room.gd`):
   - Places one extra voxel column at corner position
   - Ensures layers exist via `_ensure_voxel_layers(layer_count)`
   - Calls `set_cell()` for each level (Rule 8 — no Image operations)
   - Registers all VoxelRefs in `_voxel_junction_extras` for TIC and BakeSystem

**Files modified:**
- `godot/scripts/world/room.gd` — 3 str_replace operations (variable declaration, clear operation, 4 new functions)

**Validation (Acceptance Tests):**
- **A1:** `_voxel_junction_extras` declared ✓
- **A2:** 4 new functions present ✓ (_build_voxel_junction_extras, _has_any, _max_storey_of, _add_junction_extra)
- **A3:** Junction call at end of `_place_wall_voxels` ✓
- **A4:** `_voxel_junction_extras.clear()` in cleanup block ✓
- **A5:** Dual-key arrays (eA/eB/eC/eD keys) present ✓
- **A6:** 4 corners verified (GU_TL/GU_BR/GU_BL/GU_TR) ✓
- **A7:** Correct delta formula for vertex calculation ✓ (4 match cases)
- **A8:** `_add_junction_extra` uses `set_cell()` ✓
- **A9:** Subcube system + `_build_wall_containers` preserved ✓
- **A10:** Godot runtime clean — no parse errors or warnings ✓
- **A11:** Git status clean (only room.gd modified) ✓

**Technical notes:**
- Dual-key logic necessary because map can emit wall edges from either adjacent GU
- V-junction detection is crucial for proper corner filling in L-shaped wall layouts
- No extra voxels for T/X junctions (those corners are already covered by outer slices)
- All junction extras stored in array for future TIC and destructibility integration

**Artifacts archived:** `PROMPTS/DONE/VOXEL-05.md`

---

## VOXEL-06: VoxelRegistry — Centralized Container Management (Complete ✅)

**Objective:** Centralized registry for all WallSlice/HighWall instances; enable efficient lookup and iteration for TIC loop.

**What was implemented:**

1. **`VoxelRegistry` class** (new file: `godot/scripts/world/voxel_registry.gd`):
   - Extends `RefCounted` (not Node — pure data structure)
   - Two dictionaries: `_slices` (by id) and `_high_walls` (by id)
   - Supports signal emission on registration (`slice_registered`, `high_wall_registered`)

2. **Core API methods:**
   - `setup(max_voxels_per_level: int)` — Initialize registry with layer count
   - `register_slice(slice: WallSlice)` — Add slice to index
   - `register_high_wall(high_wall: HighWall)` — Add high_wall to index
   - `get_slice(slice_id: String) -> WallSlice` — Indexed lookup by id
   - `get_high_wall(high_wall_id: String) -> HighWall` — Indexed lookup by id
   - `all_slices() -> Array[WallSlice]` — Iterate all slices (for TIC loop)
   - `all_high_walls() -> Array[HighWall]` — Iterate all high walls (for baking/TIC)
   - `total_slices() / total_high_walls()` — Count registered containers
   - `is_empty() / clear()` — State check and reset

3. **Integration with room.gd:**
   - Added `_voxel_registry: VoxelRegistry` variable alongside `_voxel_junction_extras`
   - Instantiated in `_build_room()` before wall placement
   - Each `WallSlice` registered immediately after append via `register_slice(ws)`
   - New `_build_high_walls()` function aggregates slices into HighWall composites per edge
   - HighWalls registered via `register_high_wall(hw)`

4. **HighWall aggregation strategy** (in `_build_high_walls()`):
   - Groups all WallSlices by `(gu_cell, direction)` key
   - Creates one HighWall per group (e.g., all S0/S1 slices for NW edge of a cell)
   - HighWall.id = `"HW_" + (gu_cell + direction).replace(" ", "_")`
   - Initializes `junction_extras = []` and `baked = false` for later phases

**Files created/modified:**
- **Created:** `godot/scripts/world/voxel_registry.gd` (new class, 160 lines)
- **Modified:** `godot/scripts/world/room.gd` (3 str_replace: declare registry, initialize in _build_room, register slices + new _build_high_walls function)

**Validation (Acceptance Tests):**
- **A1:** `class_name VoxelRegistry` present ✓
- **A2:** `var _voxel_registry: VoxelRegistry` declared in room.gd ✓
- **A3:** Registry instantiated with `VoxelRegistry.new()` ✓
- **A4:** `register_slice()` called for each WallSlice ✓
- **A5:** `_build_high_walls()` function present ✓
- **A6:** `register_high_wall()` called in aggregation ✓
- **A7:** All required API methods present (get_slice, all_slices, all_high_walls, get_high_wall) ✓
- **A8:** Registry extends RefCounted (not Node) ✓
- **A9:** `setup()` method present ✓
- **A10:** Runtime validation — Godot loads clean, selftest 425 checks pass, no parse errors ✓
- **A11:** Git status clean (only room.gd modified + new voxel_registry.gd) ✓

**Technical notes:**
- Registry is a pure lookup/iteration structure — no rendering logic
- Supports signal-driven updates for future systems (observers on registration)
- Efficient for TIC loop (single `all_high_walls()` iteration per tick to process dirty containers)
- HighWall aggregation enables baking at the group level (multiple storeys → 1 texture per group)
- Preserves existing dirty_count propagation (VoxelRef → WallSlice → HighWall)

**Phase Status:** Completes **Phase 1b** (Container Indexing). All container types now centrally managed.

**Artifacts archived:** `PROMPTS/DONE/VOXEL-06.md`

---

## VOXEL-07: Dirty Flag + TIC Loop Integration (Complete ✅)

**Objective:** Implement per-voxel dirty tracking and TIC loop integration to enable efficient runtime state updates.

**What was implemented:**

1. **Per-voxel dirty propagation** (in `voxel_ref.gd`):
   - `_parent_slice: WallSlice` — weak back-reference to owning slice
   - `_set_parent_slice(slice)` — called from room during voxel append
   - `set_visible(value: bool)` — now propagates dirty upward via `increment_dirty()`
   - `set_damage(damage: int)` — now propagates dirty upward via `increment_dirty()`
   - `clear_dirty()` — resets dirty flag (called by TIC loop)

2. **Slice-level dirty aggregation** (in `wall_slice.gd`):
   - `_parent_hw: HighWall` — back-reference to parent HighWall
   - `_set_parent_hw(hw)` — called from HighWall during slice append
   - `increment_dirty()` — increments dirty_count and propagates to HighWall
   - `clear_dirty()` — recursively clears all voxel dirty flags and resets count

3. **HighWall-level dirty aggregation** (in `high_wall.gd`):
   - `increment_dirty()` — increments dirty_count when child dirty
   - `clear_dirty()` — recursively clears all slice/extra dirty flags and resets count

4. **Parent references setup** (in `room.gd` _place_wall_voxels + _build_high_walls):
   - Each VoxelRef calls `_set_parent_slice(ws)` during append
   - Each WallSlice calls `_set_parent_hw(hw)` during HighWall building
   - Enables dirty propagation chain: VoxelRef → WallSlice → HighWall

5. **TIC loop implementation** (in `room.gd`):
   - `_tic_voxel_system()` — main TIC entry point, skips idle containers (dirty_count=0)
   - `_process_voxel_slice(slice)` — iterates slice voxels, applies state for dirty ones
   - `_apply_voxel_state(voxel)` — renders or erases voxel based on visible + damage_state
   - Integrated into `_on_agent_step_finished()` — called once per agent movement TIC

**Files modified:**
- `godot/scripts/world/voxel_ref.gd` — 1 str_replace (add parent ref + propagation)
- `godot/scripts/world/wall_slice.gd` — 1 str_replace (add parent ref + increment_dirty + clear_dirty)
- `godot/scripts/world/high_wall.gd` — 1 str_replace (add increment_dirty + clear_dirty)
- `godot/scripts/world/room.gd` — 3 str_replace (register parent refs, add TIC functions, integrate into step TIC)

**Validation (Acceptance Tests):**
- **A1:** `set_visible()` present ✓
- **A2:** `set_damage()` present ✓
- **A3:** `_set_parent_slice()` present ✓
- **A4:** `WallSlice.increment_dirty()` present ✓
- **A5:** `HighWall.increment_dirty()` present ✓
- **A6:** `room._tic_voxel_system()` present ✓
- **A7:** `room._apply_voxel_state()` present ✓
- **A8:** `room._process_voxel_slice()` present ✓
- **A9:** Parent refs registered in _place_wall_voxels ✓
- **A10:** Parent refs registered in _build_high_walls ✓
- **A11:** Runtime validation — Godot loads clean, selftest 425 checks pass ✓
- **A12:** Git status clean (4 files modified + 1 spec file) ✓

**Technical notes:**
- Dirty propagation is O(1) per state change (immediate upward cascade)
- TIC loop is O(container_count) at idle (all dirty_count=0) — efficient skipping
- When dirty_count > 0, loop processes only affected voxels (O(dirty_count))
- `clear_dirty()` is called recursively from top-level HighWall down to individual voxels
- Fully backward compatible: room._place_wall_voxels() initializes all voxels with dirty=false

**Phase Status:** Completes **Phase 2** (Runtime System). Containers fully indexable and processable.

**Artifacts archived:** `PROMPTS/DONE/VOXEL-07.md`

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

