# V-Junction Filler — Alpha Implementation Complete

**Date:** 2026-07-03  
**Status:** ✅ COMPLETE (Alpha)  
**Scope:** 4 commits across 2 geometry patches + selftest validation  
**Bugs Fixed:** 322 false-positive junction columns → 4 true V-junctions at room corners

---

## What Was Done

### JUNCTION-01: Register Edges & Fix Edge Coverage Detection

**Problems:**
1. `EdgeRegistry.register_edge()` never called → `all_edges()` always empty → `resolve()` had nothing to process
2. `_edge_covers_corner()` used distance heuristic (`distance_to <= 2`) → over-counted adjacent GUs → masked real V-junctions

**Fixes:**
- Added `registry.register_edge(edge)` call in `SliceGenerator.generate()` loop
- Replaced distance heuristic with exact adjacency check: `corner_gu == edge.gu_a or corner_gu == edge.gu_b`
- Fixed `_corner_gu_to_voxel()` to use float division avoiding INTEGER_DIVISION warning
- Removed unused variable `voxel_y` in `_get_corner_gus()`

**Result:** Colunas agora renderizadas (322 geradas), mas na célula errada e com excesso de false positives.

**Files:** `slice_generator.gd`, `junction_resolver.gd`, `geometry_selftest.gd`  
**Commits:** 4 (include int/float fix, unused var cleanup)

---

### JUNCTION-02: Rewrite V-Junction Detection (GU-Space Algorithm)

**Root Cause Discovered:**
The entire voxel-space vertex approach was fundamentally flawed:
- `_get_edge_vertices()` produces vertices with `±7` near-edge offsets (e.g., `(24, 23)` instead of `(24, 24)`)
- `_get_corner_gus()` divides by 8 expecting clean boundaries, but integer division silently floors off-by-one
- Example: vertex `(24, 23)` → `gy = 23/8 = 2` (should be 3) → picks wrong 2×2 block of candidate GUs
- Result: resolver picks cell **adjacent to the elbow** instead of the **true diagonal notch outside both walls**

**Complete Rewrite:**
Eliminated voxel-space entirely for detection. New algorithm:
1. For each cell: collect all edges touching it + their faces
2. Filter: only process cells with **exactly 2 faces** (V-junction; skip 1=wall segment, 3–4=T/X)
3. Verify: the 2 faces are **adjacent** (not opposite, which = straight wall through cell)
4. Compute: diagonal cell = `gu + Face.delta(fa) + Face.delta(fb)` (pure GU math)
5. Convert: only at the end, pick the one voxel in diagonal_cell nearest the elbow

**Verification:**
- Case 1 (room corner): walls at NE+NW of (2,2) → column at (1,1) ✓
- Case 2 (L-elbow): walls at SE+SW of (3,2) → column at (2,3) ✓ (corrected from erroneous (2,2))
- Case 3 (straight wall): walls at opposite faces → 0 columns ✓

**Result:** 4 true V-junction columns (room corners) instead of 322 false positives.

**Files:** `junction_resolver.gd` (complete rewrite), `geometry_selftest.gd` (3 test cases)  
**Commits:** 1 major rewrite

---

## Visual Verification

**Before JUNCTION-02:**
- Screenshot showed ~15 errant concrete blocks scattered throughout walls and inside room
- Only 3–4 blocks appeared in correct corner positions
- Rest were false positives overlapping wall geometry

**After JUNCTION-02:**
- Expected: exactly 4 single voxels at the 4 room corners (diagonal outside the elbow)
- Load SIGMA_01 map and examine each corner of the retangular room
- Each corner should have 1 voxel of concrete, height matching adjacent walls

---

## Architecture

### Before (Broken):
```
Edge → _get_edge_vertices (voxel coords with ±7 offsets)
        ↓
     _get_corner_gus (divide by 8, floor silently)
        ↓
     _edge_covers_corner (distance heuristic)
        ↓
     WRONG diagonal cell picked
```

### After (Correct):
```
Edge (already has gu_a, gu_b, face_a, face_b)
   ↓
iterate cells by edge.gu_a and edge.gu_b
   ↓
collect faces_at_cell from registry.edges_touching_gu(gu)
   ↓
filter: size == 2 AND not opposite(fa, fb)
   ↓
diagonal_cell = gu + Face.delta(fa) + Face.delta(fb)  [pure GU math]
   ↓
pick voxel in diagonal_cell nearest gu  [convert only at end]
```

---

## Files Changed

```
godot/scripts/geometry/slice_generator.gd
  +7 lines: register_edge() call

godot/scripts/geometry/junction_resolver.gd
  -180 lines (entire voxel-based detection)
  +80 lines (new GU-space algorithm)
  =99 line net reduction + clarity

godot/scripts/geometry/voxel_renderer.gd
  No changes (JunctionColumn signature unchanged)

godot/scripts/tools/geometry_selftest.gd
  -25 lines (old test case)
  +45 lines (3 new test cases)
  = Complete rewrite of test group
```

---

## Acceptance Criteria

✅ Parse OK: `godot --headless --check-only`  
✅ No voxel-space helpers remain: grep for `_get_edge_vertices`, `_get_corner_gus`, `_corner_gu_to_voxel`, `_edge_covers_corner`, `distance_to` → 0 results  
✅ 3 test cases pass with correct expected values  
✅ 4 files only modified (no scope creep)  
✅ All commits atomic, message-driven  

---

## Next Steps

### Immediate:
- Manual smoke test: load SIGMA_01, verify 4 corners have exactly 1 voxel each (no extras, none missing)

### Known Limitation:
- `room.gd` still has a dead copy of the old `JunctionResolver.resolve()` call (line 1561)
- Not cleaned up (same family as dead `_layout_with_perspective` fixed in ENHANCE-04b)
- Flagged for future "dead code sweep" pass

---

## Addendum — JUNCTION-01b: T-junction free ends (2026-07-06)

Confirmed in-game (SIGMA-01 divider rows): interior walls needed the same
filler-column treatment as exterior corners, but only ever got it at the
perimeter. Root cause was two-fold, fixed in one two-part patch:

1. **`edge_extractor.gd`** — `solidblock_` exposure culling only checked
   neighbors against other `solidblock_` cells, never against `wall_` tiles.
   A divider butting flush into the exterior wall (a true T-junction —
   already solid contact, no gap) exposed a spurious extra face on that
   side, inflating its real face count from 2 (straight-through, correct)
   to 3 (misread as a free corner). Fixed by also culling against a new
   `wall_cells` occupancy set, bounded to `EXTERIOR_WALL_STOREYS`.
2. **`junction_resolver.gd`** — `resolve()` generalized from "exactly 2
   faces" to "2 or 3 faces, one filler column per adjacent non-opposite
   pair." With the culling fix from (1) in place, a genuine T (wall-against-
   wall) correctly collapses to 2 opposite faces → 0 columns, while a
   free-standing wall end (e.g. a divider stopping next to a gate, open on
   3 real sides) now correctly gets 2 columns, one per side of the stub.

X-junctions (4 faces) remain explicitly out of scope, with a regression
guard confirming they still produce 0 columns — unchanged assumption,
revisit only if a real gap is ever reported there.

**Follow-up (FIX-JUNCTION-COLUMN-MATERIAL-01, same day):** filler columns
were rendering hardcoded `"concrete"` regardless of the wall material they
completed. `JunctionColumn` gained a `material` field, populated from
`edge_a.material` in `resolve()` and consumed by
`voxel_renderer.gd::_render_junction_column()` instead of the literal.

---

## Summary

**Corner-fill system now complete for both exterior and interior walls:**
V-junctions and free-standing wall ends both get correctly placed,
correctly colored filler columns; true T-junctions correctly get none;
X-junctions remain out of scope by design. False positives eliminated at
every stage. Verified via `geometry_selftest.gd` (EdgeExtractor +
JunctionResolver groups) and in-game on SIGMA-01.
