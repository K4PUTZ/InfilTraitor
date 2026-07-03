# ENHANCE-04b — Completion Report

**Date:** 2026-07-03  
**Status:** ✅ COMPLETE  
**Scope:** 4 files, 1 session  
**Bug Fixed:** Guard patrol routes and directional light angles now rotate with perspective changes

---

## What Was Done

### The Problem

`PerspectiveMapper` was supposed to be the single source of truth for all perspective mathematics (Task 04), but only absorbed 2 of 6 planned functions. The other 4 were duplicated across `room.gd` (dead code) and `room_builder.gd` (incomplete live copy). The incomplete copy in `room_builder.gd` was missing:
- Enemy patrol route rotation (only rotated `start_cell`, not the `route` array)
- Directional light angle rotation (never existed in that file)

**In-game symptom:** When rotating perspective (N→E→S→W), guard patrols stayed locked to North orientation, and light cones didn't reorient with the room.

### The Solution

**Consolidate all 4 missing functions into `PerspectiveMapper`** as a single static source, then have `room_builder.gd` and `room.gd` delegate to it.

#### 1. `perspective_mapper.gd` — Added 4 static functions

```gdscript
static func perspective_angle_delta_deg(direction: String) -> float
static func rotated_size(base_size: Vector2i, direction: String) -> Vector2i
static func cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i
static func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary
```

The `layout_with_perspective()` function now:
- Rotates every cell field (agent_start, floor, walls, structures, blocks, edges)
- Rotates enemy patrol routes cell-by-cell (bug fix #1)
- Rotates light source positions AND their direction angles (bug fix #2)

#### 2. `room_builder.gd` — Replaced with delegation

```gdscript
func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
    return PerspectiveMapperClass.layout_with_perspective(layout, direction)
```

Deleted local copies of `_rotated_size()` and `_cell_from_base()` (verified: 0 remaining callers).

#### 3. `room.gd` — Removed dead code

- Deleted 108-line dead-code block containing `_layout_with_perspective()`, `_perspective_angle_delta_deg()`, `_rotated_size()`, `_cell_from_base()`
- Updated 2 live callers in `_set_perspective()` to use `PerspectiveMapperClass.cell_from_base()` with explicit `base_size`
- Kept thin wrappers `_cell_to_base()` and `_remap_tile_name_for_perspective()` (already correct)

#### 4. `slice_geometry_selftest.gd` — New test group

Added 22 validation checks before the Negative Tests section:
- **20 round-trip checks:** For each direction (N/E/S/W) and 5 test cells, verify `cell_from_base` → `cell_to_base` round-trips correctly
- **2 parity checks:**
  - Enemy route actually rotates (was stuck at base orientation)
  - Light angle actually rotates (was stuck at 0°)

Console output:
```
[ENHANCE-04b] Perspective round-trip + rotation parity
  ✓ enemy route rotates: [(4, 1), (1, 1)]
  ✓ light angle rotates: 90.0 deg
```

---

## Verification

### Automated

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Parse OK | ✅ | Selftest headless: "SLICE-00 SELFTEST: PASS (45 checagens)" |
| No duplication | ✅ | `grep` → 0 matches for old signatures in room.gd + room_builder.gd |
| Delegation confirmed | ✅ | room_builder.gd:165: `return PerspectiveMapperClass.layout_with_perspective(layout, direction)` |
| 22 selftest checks pass | ✅ | "[ENHANCE-04b] Perspective checks: 22 passed" |
| Enemy route rotates | ✅ | Round-trip validates; parity check confirms rotation |
| Light angle rotates | ✅ | Parity check: 0° → 90° under direction E |
| 4 files only | ✅ | git diff --name-only (no scope creep) |

### Manual Smoke Test

Next step (post-implementation):
- Load SIGMA_01 in Godot editor
- Rotate perspective N→E→S→W→N
- Verify:
  - At least 1 guard with multi-cell route follows the rotated path (doesn't cross walls)
  - At least 1 directional light cone points in direction matching rotated room in each perspective

---

## Files Changed

```
godot/scripts/world/utilities/perspective_mapper.gd
  +124 lines (4 new static functions)

godot/scripts/world/builders/room_builder.gd
  -64 lines (layout_with_perspective() → 1-line delegation; delete _rotated_size + _cell_from_base)

godot/scripts/world/room.gd
  -108 lines (delete dead code block: _layout_with_perspective + 3 helpers)
  +2 lines (update 2 callers to PerspectiveMapperClass.cell_from_base with explicit base_size)

godot/scripts/tools/slice_geometry_selftest.gd
  +37 lines (new ENHANCE-04b test group)
  +1 line (update summary counter: - 4 - 22)
```

---

## Impact

**Bugs Fixed:**
1. ✅ Guard patrol routes now follow perspective rotation (no longer stuck at North)
2. ✅ Directional light angles now rotate with perspective (no longer stuck at 0°)

**Code Quality:**
- Single source of truth: `PerspectiveMapper` is now the only place that implements perspective rotation math
- Eliminated duplicated code: 3 copies → 1 canonical implementation
- Fully testable: 22 checks validate round-trip correctness and rotation parity

**Architectural:**
- Follows inviolable rule: Module independence — rotation logic isolated in utility, clients are thin
- Unblocks Baking System (TEX-CATALOG-01 → MAT-01 → VOXEL-08) without inheriting this bug in baked assets

---

## Next Steps

The Baking System can now proceed. With perspective rotation consolidated and tested in `PerspectiveMapper`, any assets baked will have correct rotation logic baked in.

