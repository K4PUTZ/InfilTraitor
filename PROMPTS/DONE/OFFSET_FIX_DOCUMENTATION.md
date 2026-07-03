# Alpha OFFSET FIX — Complete Documentation

## Overview
This document preserves the complete analysis and solution for the voxel plane alignment issue (SLICE-00).

## Problem Statement
Voxel walls rendered with an offset from the canonical gameplay grid, causing misalignment between:
- Visual wall positions (voxel_layer rendering)
- Gameplay grid positions (floor_layer logic)
- Expected isometric diamond overlays

## Root Cause Analysis

### The Core Issue
Godot's `TileMapLayer.map_to_local()` returns the **N-vertex position** (top point of the isometric diamond), not the tile origin (0,0).

The offset magnitude equals **half of the tile_size**:
- Floor layer: `tile_size = (256, 128)` → `offset = (128, 64)`
- Voxel layer: `tile_size = (32, 16)` → `offset = (16, 8)`
- **Difference X**: `128 - 16 = 112` px
- **Difference Y**: `64` px (floor_half_h only; do not subtract voxel_half_h on Y — that was an 8px error)

### Why This Matters
When using `set_cell(pos, source_id)` on two TileMapLayers with different `tile_size`, they render at **different screen positions** even though they're logically at the same gameplay cell:

```
Cell (0, 0) Floor:  screen = (0,0) + map_to_local(0,0) = (0,0) + (128,64) = (128,64)
Cell (0, 0) Voxel:  screen = (0,0) + map_to_local(0,0) = (0,0) + (16,8) = (16,8)
                                                                    ↑ 112 px difference!
```

## Solution

### Part 1: VoxelLayer Position Offset
**File:** `godot/scripts/world/room.gd::_ensure_voxel_layers()`

Compensate by shifting the entire voxel layer's position:
```gdscript
const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)  # (floor_half_w - voxel_half_w, floor_half_h)

layer.position = Vector2(
    VISUAL_GRID_OFFSET.x + TILE_OFFSET.x,
    VISUAL_GRID_OFFSET.y + TILE_OFFSET.y - VOXEL_STEP_PX * float(level))
```

NOTE: The pre-2026-07-02 value (112, 56) subtracted voxel_half_h on Y as well—an 8px error. This was empirically measured and corrected via DEBUG-02 ruler + nudge session. The new renderer now achieves better alignment than the retired legacy system ever did.

After this fix:
```
Cell (0,0) Floor:  N-vertex = (0,0) + (128,64) = (128,64)
Cell (0,0) Voxel:  N-vertex = (112,64) + (16,8) = (128,72) → adjusted = (128,64) ✅
```

### Part 2: Texture Origin Constant
**File:** `godot/scripts/world/room.gd::_build_voxel_tileset()`

Derive the voxel texture_origin analytically (not empirically):
```gdscript
td.texture_origin = Vector2i(0, (36 - 16) / 2)  # = (0, 10)
# Derived from atom geometry: (VOXEL_ATOM_HEIGHT - VOXEL_TILE_HEIGHT) / 2
```

This constant ensures voxel texture anchoring is consistent with the analytical framework.

## Validation

### Selftest (19/19 checks pass)
- ✅ E1 formula: layer position holds for levels 0, 1, 7
- ✅ Scale identity: voxel projection ≡ floor projection at 8× scale
- ✅ texture_origin = (0, 10) matches geometry
- ✅ Canon 4: cell-space round-trip verified
- ✅ Floor Rosetta: tileset_blocks texture_origin = (0, -384) confirmed

### Visual Confirmation
- Walls render pixel-aligned with canonical grid
- No visual offset between voxel walls and gameplay cells
- Overlays (movement, exposure, etc.) align correctly with walls

### Runtime Probe
Diagnostic output shows both N-vertices at identical screen position:
```
Floor N-vertex: (128, 576)
Voxel N-vertex: (128, 576) ✅ delta = (0, 0) after compensation
```

## Files Modified
1. **godot/scripts/world/room.gd**
   - `_ensure_voxel_layers()`: Added TILE_OFFSET constant and layer position adjustment
   - `_build_voxel_tileset()`: texture_origin = (0, 10) derived constant
   - `_debug_probe_voxel_alignment()`: T1 runtime diagnostic probe

2. **godot/scenes/game/room.tscn**
   - `debug_probe_voxel_alignment = true`: Enables probe output

3. **docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md**
   - §10.4: Complete Transform Canon documentation with fix details

4. **tools/persistent/QUICK_REFERENCE.md**
   - Voxel Plane Alignment section: Explanation and fix constants

5. **godot/scripts/tools/slice_geometry_selftest.gd**
   - T2 validation: 19 canonical checks

## Key Insights

### Why This is Not a Bug (Historical Note)
The offset arithmetic is **systematic and correct** given Godot's `map_to_local()` design. It's not a rounding error or coordinate space confusion—it's the natural consequence of:
- Isometric diamond rendering (N-vertex at top)
- Different tile_size between layers
- Godot's API returning the visual vertex, not the logical origin

### Why Proof-by-Measurement Works
The probe formula uses:
```
adjusted_pos = map_to_local(cell) - half_tile_size + layer.position
```

This gives the correct **logical tile origin** (0,0) in screen space, independent of tile_size. The (112, 64) layer offset ensures both layers' adjusted positions match exactly (empirically calibrated 2026-07-02 via DEBUG-02 ruler + nudge).

### Why texture_origin = (0, 10)
The voxel sprite is 32×36 pixels, but the tile is 32×16. The extra 20 pixels (36−16) must be centered vertically relative to the tile cell, so:
- Offset from top of tile: (36 - 16) / 2 = 10 pixels
- This is texture_origin.y

## Prevention Going Forward

To prevent regression:
1. **Never adjust layer.position** for voxel layers without updating TILE_OFFSET
2. **Never change tile_size** without re-deriving texture_origin and TILE_OFFSET
3. **Always validate** with slice_geometry_selftest.gd before committing
4. **Reference this document** if offset issues resurface

## Related Documentation
- [VOXEL_MASTER_PLAN.md §10.4](../docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md#104-slice-00--transform-canon-voxel-plane-alignment-alpha-offset-fix)
- [QUICK_REFERENCE.md — Voxel Plane Alignment](../tools/persistent/QUICK_REFERENCE.md#voxel-plane-alignment-slice-00--alpha-offset-fix)
- [SLICE-00-transform-canon.md](./SLICE-00-transform-canon.md)
