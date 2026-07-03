# SLICE-02 Stage B — Legacy Purge Specification

**Date:** 2026-07-02  
**Status:** Ready for prompt generation (SLICE-02-purge.md)  
**Scope:** Complete removal of the voxel/subcube legacy rendering system, post-Stage A parity verification and alignment calibration (SLICE-02-fix3).

---

## OVERVIEW

Stage B removes the complete legacy voxel/subcube rendering stack that has been fully
superseded by the `geometry/` module (SLICE-01) wired into `room.gd` (SLICE-02 Stage A).
The old system is confirmed dead code:

- No calls from any live code path (all paths branch-exclusive as of SLICE-02-fix1).
- All data structures ported to the new module (GeometryCoords replaces SubcubeCoords, etc.).
- All rendering functions reimplemented in VoxelRenderer.
- The Stage A parity gate (A-T4) validated the new system in isolation, bug-for-bug
  identical to the legacy baseline (now with the alignment calibration SLICE-02-fix3).

This is a pure deletion pass — no logic changes, no new functionality. The new system is
already the ONLY active path.

---

## FILES TO DELETE (9 total)

### Category: Legacy rendering pipeline classes

**File:** `godot/scripts/world/wall_container.gd`
- **Class:** WallContainerClass (unused Sprite2D-based wall rendering)
- **Status:** Code confirmed DEAD — referenced only in:
  - Its own definition
  - One archival comment in `_place_wall_voxels()` ("Substitui _build_wall_containers() (arquivada — NÃO apagar)")
  - `room.gd` line 9: `const WallContainerClass = preload(...)`
- **No other references exist in the codebase.**

**File:** `godot/scripts/world/subcube_coords.gd`
- **Class:** SubcubeCoords (coordinate math, replaced by GeometryCoords)
- **Status:** Code confirmed DEAD — all its functions have equivalents in `geometry_coords.gd`:
  - `unit_to_subcube_origin()` → `GeometryCoords.gu_to_voxel_origin()`
  - `subcube_to_unit()` → `GeometryCoords.voxel_to_gu()`
  - `subcube_local()` → `GeometryCoords.voxel_local()`
  - `subcube_at()` → internal use only, replaced
  - `unit_subcubes()` → `GeometryCoords.gu_voxels()`
- **References:** `room.gd` line 7 + uses in dead functions only.

**File:** `godot/scripts/world/maps/subcube_geometry.gd`
- **Class:** SubcubeGeometryClass (legacy compilation layer)
- **Status:** Code confirmed DEAD — was the old path to extract edges and solid blocks
  from `layout.wall_levels`. Replaced by `EdgeExtractor.extract()` + `render_block()`
  pattern.
- **References:** `room.gd` line 6 + uses in dead code path only (the `elif` branch).

**File:** `godot/scripts/world/maps/map_compiler.gd`
- **Status:** Code confirmed DEAD — legacy compiler path. The new system uses the same
  `MapCatalogClass.get_spec()` directly, never calls this.
- **Note:** Check if this is actually dead or if `_build_room()` still uses it for something
  else. If it's used outside the voxel path, keep it. **grep confirms:** only called in the
  dead `_build_room()` branch. DELETE.

**File:** `godot/scripts/world/voxel_registry.gd`
- **Classes:** VoxelRef, WallSlice, HighWallGroup (data structures for the legacy dirty
  tracking system)
- **Status:** Code confirmed DEAD — replaced by `EdgeRegistry` + `Slice` + `HighWallGroup`
  (which moved to `geometry/high_wall.gd`).
- **References:** `room.gd` only (dead code).

### Category: Legacy selftests (safe to delete; new selftests exist)

**File:** `godot/scripts/tools/voxel_selftest.gd`
- **Status:** Tests the legacy `VoxelRef`/voxel_registry system. Dead.
- **Replacement:** `geometry_selftest.gd` (the new module has its own battery).

**File:** `godot/scripts/tools/subcube_geometry_selftest.gd`
- **Status:** Tests `SubcubeGeometryClass`. Dead.
- **Replacement:** None needed; map compilation is not tested in isolation (tested
  end-to-end via gameplay).

**File:** `godot/scripts/tools/coord_selftest.gd`
- **Status:** Tests `SubcubeCoords`. Dead.
- **Replacement:** `geometry_selftest.gd` includes equivalent coordinate math tests via
  `GeometryCoords`.

**File:** `godot/scripts/tools/slice_02_integration_selftest.gd`
- **Status:** Parity test for SLICE-02 Stage A. Was used to validate the wiring before
  A-T4; now that Stage A is verified and Stage B is happening, this test becomes
  obsolete (the integration it tested is permanent now).
- **Decision:** DELETE. If you want to preserve it for regression testing after Stage B,
  comment it out + date it instead of deleting — but do not leave it runnable and
  untouched, as it will accumulate bitrot.

---

## DELETIONS IN `godot/scripts/world/room.gd`

### A) Member Variables to Delete (5 total)

```gdscript
Line 125:  var _voxel_layers: Array = []
Line 134:  var _wall_containers: Array = []
Line 105:  var _subcube_tileset: TileSet = null
Line 106:  var _subcube_layers: Array = []
Line 125:  var _voxel_registry: RefCounted = null
```

**Confirmation these are dead:**
- `_voxel_layers`: only populated by `_ensure_voxel_layers()` (dead function), never
  read elsewhere except the probe (which was re-pointed to `_voxel_renderer` in
  SLICE-02-diag).
- `_wall_containers`: only populated in `_build_wall_containers()` (dead function), never
  read.
- `_subcube_tileset`: only populated in `_build_subcube_tileset()` (dead function),
  checked in the dead `elif` branch of `_build_room()`.
- `_subcube_layers`: only populated in `_ensure_subcube_layers()` (dead function), not
  referenced anywhere else.
- `_voxel_registry`: only populated in dead branch, used in dead `_build_high_walls()` and
  the dead `elif` of `_tic_voxel_system()`.

### B) Constants to Delete (3 total)

```gdscript
Line 92:   const SUBCUBE_STEP_PX: float = 40.0
Line 95:   const SUBCUBE_BASE_ORIGIN := Vector2i(0, -40)
Line 100:  const SUBCUBE_FACE_OFFSETS: Dictionary = { "NW": ..., "NE": ..., "SE": ..., "SW": ... }
```

**Confirmation these are dead:**
- `SUBCUBE_STEP_PX`: only used in `_ensure_subcube_layers()` (dead).
- `SUBCUBE_BASE_ORIGIN`: only used in `_build_subcube_tileset()` (dead).
- `SUBCUBE_FACE_OFFSETS`: only used in `_build_subcube_tileset()` (dead).

**grep result (confirm no other references):**
```bash
grep -n "SUBCUBE_STEP_PX\|SUBCUBE_BASE_ORIGIN\|SUBCUBE_FACE_OFFSETS" godot/scripts/world/room.gd
# Should return ONLY the definition lines and the dead function bodies.
```

### C) Preload Constants to Delete (3 total)

```gdscript
Line 6:  const SubcubeGeometryClass = preload("res://godot/scripts/world/maps/subcube_geometry.gd")
Line 7:  const SubcubeCoordsClass = preload("res://godot/scripts/world/subcube_coords.gd")
Line 9:  const WallContainerClass = preload("res://godot/scripts/world/wall_container.gd")
```

**Confirmation these are dead:**
- `SubcubeGeometryClass`: used only in the dead `elif` branch of `_build_room()`.
- `SubcubeCoordsClass`: used in dead functions (`_render_subcube_geometry()`,
  `_place_wall_voxels()`, `_build_voxel_junction_extras()`, `_add_junction_extra()`,
  `_paint_subcube_descriptor()`).
- `WallContainerClass`: used only in the dead `_build_wall_containers()` function.

### D) Functions to Delete (11 total, ~650 lines)

| Function | Lines | Used By | Status |
|----------|-------|---------|--------|
| `_build_voxel_tileset()` | ~60 | `_ready()` (dead branch) | DEAD |
| `_ensure_voxel_layers()` | ~25 | `_ensure_voxel_layers()` calls itself recursively (dead path) | DEAD |
| `_ensure_subcube_layers()` | ~20 | `_render_subcube_geometry()` (dead function) | DEAD |
| `_render_subcube_geometry()` | ~25 | `_build_room()` (dead elif branch) | DEAD |
| `_place_wall_voxels()` | ~75 | `_build_room()` (dead elif branch) | DEAD |
| `_build_wall_containers()` | ~120 | Never called (code says it's archived) | DEAD |
| `_paint_subcube_descriptor()` | ~40 | `_render_subcube_geometry()` (dead) | DEAD |
| `_build_high_walls()` | ~25 | `_tic_voxel_system()` (dead elif branch) | DEAD |
| `_build_voxel_junction_extras()` | ~140 | `_build_room()` (dead elif branch) | DEAD |
| `_voxel_slice_positions()` | ~80 | `_build_voxel_junction_extras()` (dead) | DEAD |
| `_has_any()` | 5 | `_max_storey_of()`, `_build_voxel_junction_extras()` (all dead) | DEAD |
| `_max_storey_of()` | 5 | `_build_voxel_junction_extras()` (dead) | DEAD |
| `_add_junction_extra()` | ~15 | `_build_voxel_junction_extras()` (dead) | DEAD |

**Deletion order (bottom-up to avoid forward reference issues):**
1. `_add_junction_extra()` (line ~2180)
2. `_max_storey_of()` (line ~2171)
3. `_has_any()` (line ~2163)
4. `_voxel_slice_positions()` (line ~1769)
5. `_build_voxel_junction_extras()` (line ~2021)
6. `_paint_subcube_descriptor()` (line ~2356)
7. `_build_wall_containers()` (line ~2192)
8. `_build_high_walls()` (line ~1992)
9. `_place_wall_voxels()` (line ~1854)
10. `_render_subcube_geometry()` (line ~1742)
11. `_ensure_subcube_layers()` (line ~1650)
12. `_build_voxel_tileset()` (line ~1670)
13. `_ensure_voxel_layers()` (line ~1715)

### E) Control Flow Branches to Delete

**Location 1: `_build_room()` function (around line 2420)**

Current structure (post SLICE-02-fix1):
```gdscript
if not extraction.get("edges", []).is_empty():
    # [NEW SYSTEM — stays, this runs always on any map]
    _edge_registry = EdgeRegistry.new()
    SliceGenerator.generate(extraction["edges"], _edge_registry)
    _junction_columns = JunctionResolver.resolve(_edge_registry)
    _voxel_renderer.clear()
    _voxel_renderer.render(_edge_registry, _junction_columns)
    _render_solid_blocks(extraction.get("solid_blocks", []))
    structure_wall_layer.visible = false
    for layer in _wall_upper_layers:
        layer.visible = false

elif not subcube_geometry.is_empty() and _subcube_tileset != null:
    # [LEGACY SYSTEM — DELETE THIS ENTIRE BRANCH]
    var max_floors: int = maxi(1, int(layout.get("max_floors", 1)))
    if _voxel_registry == null:
        _voxel_registry = VoxelRegistryClass.new()
        _voxel_registry.setup(max_floors * SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS)
    _render_subcube_geometry(subcube_geometry, max_floors)
    _place_wall_voxels(subcube_geometry)
    structure_wall_layer.visible = false
    for layer in _wall_upper_layers:
        layer.visible = false

else:
    # [OLDEST FALLBACK — DELETE THIS ENTIRE BRANCH]
    var wall_levels: Array = layout.get("wall_levels", [layout.get("wall_tiles", [])])
    _ensure_wall_upper_layers(maxi(0, wall_levels.size() - 1))
    for layer in _wall_upper_layers:
        layer.clear()
        layer.visible = true
    structure_wall_layer.visible = true
    # ... more logic ...
```

**Action:** Delete the entire `elif` and `else` branches (keep only the `if`). Result:

```gdscript
if not extraction.get("edges", []).is_empty():
    # [NEW SYSTEM — only path left]
    _edge_registry = EdgeRegistry.new()
    SliceGenerator.generate(extraction["edges"], _edge_registry)
    _junction_columns = JunctionResolver.resolve(_edge_registry)
    _voxel_renderer.clear()
    _voxel_renderer.render(_edge_registry, _junction_columns)
    _render_solid_blocks(extraction.get("solid_blocks", []))
    structure_wall_layer.visible = false
    for layer in _wall_upper_layers:
        layer.visible = false
```

**Location 2: `_tic_voxel_system()` function (around line 2110)**

Current structure (post SLICE-02-fix1):
```gdscript
func _tic_voxel_system() -> void:
    if _voxel_renderer != null and _edge_registry != null:
        _voxel_renderer.process_dirty(_edge_registry)
        return
    
    ## [LEGACY PATH — DELETE EVERYTHING BELOW THE RETURN]
    if _voxel_registry == null:
        return

    for hw in _voxel_registry.all_high_walls():
        if hw.dirty_count == 0:
            continue
        
        for slice in hw.slices:
            if slice.dirty_count == 0:
                continue
            _process_voxel_slice(slice)
        
        hw.dirty_count = 0
```

**Action:** Delete everything after the first `return`. Result:

```gdscript
func _tic_voxel_system() -> void:
    if _voxel_renderer != null and _edge_registry != null:
        _voxel_renderer.process_dirty(_edge_registry)
        return
```

---

## CONSTANTS TO KEEP (2 total)

These constants are still used by live code and MUST NOT be deleted:

```gdscript
Line 81:  const WALL_BASE_Z_INDEX := 10
Line 110: const VOXEL_STEP_PX: float = 20.0
```

**Why they stay:**
- `WALL_BASE_Z_INDEX`: passed to `_voxel_renderer.setup()`, used by HUD layers, gameplay
  overlays. **grep confirms:** 15+ references outside dead code.
- `VOXEL_STEP_PX`: referenced in `SliceGenerator.generate()` (live) and comment in
  `GeometryCoords`. **grep confirms:** 10+ references in live code + geometry module.

---

## VERIFICATION CHECKLIST

### Pre-deletion checklist

- [ ] Run grep for every deleted constant/function/class to confirm ZERO references
      outside the dead code being removed.
- [ ] Diff the `.gd` files against the `room.gd` changes to confirm only deletions, no
      logic modifications in surviving functions.
- [ ] Compile the project after each major deletion batch (after deleting files, after
      deleting functions, after deleting control-flow branches) — zero errors expected.

### Post-deletion verification

- [ ] Room scene launches without errors (F5 on `room.tscn`).
- [ ] Both PLAYGROUND and SIGMA_01 load via F2 map loader.
- [ ] Wall heights 1 and 3 render identically to pre-Stage-B.
- [ ] Voxel ruler (F3) still shows zero residual offset (proof: the new system was the
      entire render pipeline all along).
- [ ] No new warnings in PROBLEMS tab.
- [ ] `git diff` contains ONLY deletions; no line changes to surviving functions.

---

## SAFETY NOTES

1. **No logic changes to surviving functions.** The only changes to `room.gd` are:
   - Deletion of dead functions.
   - Deletion of dead variables/constants.
   - Simplification of control flow (remove `elif`/`else` branches).
   - NO changes to:
     - `load_map()`, `_ready()`, `_build_room()` (surviving `if` block only).
     - `_tic_voxel_system()` (surviving `if` block only).
     - Any gameplay, AI, vision, or UI system.

2. **Commit atomically.** This is a single, cohesive deletion. Do not split it across
   multiple commits unless you need intermediate breakpoints for testing.

3. **Reverting is simple.** If anything breaks, `git revert` the entire commit. The old
   code is preserved in git history.

---

## ACCEPTANCE CRITERIA (for the SLICE-02-purge prompt)

- **BA1:** All 9 files deleted from disk; `git status` shows them as deleted.
- **BA2:** `room.gd`: all 11 functions, 5 members, 3 constants, 3 preloads deleted.
- **BA3:** `_build_room()` and `_tic_voxel_system()` now contain ONLY the new system's `if`
  block (no `elif`/`else`).
- **BA4:** grep on `SUBCUBE_*`, `_voxel_layers`, `_wall_containers`, `_voxel_registry`,
  `SubcubeCoordsClass`, `WallContainerClass` → ZERO matches in godot/scripts/ (except
  file deletion history).
- **BA5:** Project compiles with zero errors and zero new warnings.
- **BA6:** Smoke test (PLAYGROUND, SIGMA_01, heights 1 and 3) passes; visual output
  identical to pre-Stage-B.
- **BA7:** `git diff --stat` shows only deletions and line reductions; no new code
  introduced except the simplified branch structure.

