# Subcube Wall Straddle System

**Phase:** SUB-01 (Subcube Render Plane)  
**Status:** In Calibration  
**Last Updated:** 2026-06-27

## Overview

The subcube wall straddle system renders directional wall faces at the boundaries between isometric tiles, making wall geometry **divide the tile edge 50/50** with their neighbors. This creates the visual illusion that walls "straddle" the boundary, improving tile-edge realism without requiring finer grid divisions.

## Architecture

### Grid Foundation

- **Tile size on-screen:** 256×128 px (diamond with 128px width, 64px height per half)
- **Subcube render plane:** Separate layer stack from gameplay plane
- **Vertical step:** 40px per subcube row (4 rows per storey)
- **Base origin:** All subcube tiles start at `Vector2i(0, -40)`

### Directional Variants

Four cardinal wall directions, each with independent texture offset:

| Direction | Delta | Offset (v3) | Purpose |
|-----------|-------|------------|---------|
| **NW** | (0, -1) | (12, -6) | Wall facing north-west edge |
| **NE** | (1, 0) | (12, 6) | Wall facing north-east edge |
| **SE** | (0, 1) | (-12, 6) | Wall facing south-east edge |
| **SW** | (-1, 0) | (-12, -6) | Wall facing south-west edge |

Each offset pushes the wall sprite away from the tile center toward the corresponding edge, placing it at the boundary between this tile and its neighbor.

## Implementation Details

### File: `godot/scripts/world/room.gd`

#### 1. **Constants (Lines 83–92)**

```gdscript
const SUBCUBE_BASE_ORIGIN := Vector2i(0, -40)

const SUBCUBE_FACE_OFFSETS: Dictionary = {
    "NW": Vector2i( 12, -6),
    "NE": Vector2i( 12,  6),
    "SE": Vector2i(-12,  6),
    "SW": Vector2i(-12, -6),
}
```

- `SUBCUBE_BASE_ORIGIN`: Universal anchor point for all subcube tiles in the tileset
- `SUBCUBE_FACE_OFFSETS`: Per-direction texture offset relative to base origin
  - **Positive values** push toward tile edges (N, E quadrants)
  - **Negative values** push toward tile edges (S, W quadrants)
  - **Magnitude 12/6:** Calibrated via visual feedback to reach tile edges (≈75% of half-step distance)

#### 2. **Tileset Construction (Lines 1515–1567)**

Function: `_build_subcube_tileset()`

```gdscript
func _build_subcube_tileset() -> void:
    # Per material: 1 base tile + 4 directional variants
    for material in ["concrete", "metal", "stone", "wood"]:
        # Register base tile (no offset)
        td_base.texture_origin = SUBCUBE_BASE_ORIGIN
        
        # Register 4 directional variants
        for dir in ["NW", "NE", "SE", "SW"]:
            td_dir.texture_origin = SUBCUBE_BASE_ORIGIN + SUBCUBE_FACE_OFFSETS[dir]
            #                        └─ (0, -40)     + (12, -6)  = (12, -46) for NW
```

Creates 20 tileset sources total:
- **4 materials** × **(1 base + 4 variants)** = 5 sources per material

Each variant tile gets a unique `texture_origin` that offsets its sprite texture in the tileset region.

#### 3. **Edge Delta → Direction Mapping (Lines 1634–1642)**

Function: `_edge_delta_to_dir(delta: Vector2i) -> String`

```gdscript
func _edge_delta_to_dir(delta: Vector2i) -> String:
    match delta:
        Vector2i( 0, -1): return "NW"   # wall on north edge
        Vector2i( 1,  0): return "NE"   # wall on east edge
        Vector2i( 0,  1): return "SE"   # wall on south edge
        Vector2i(-1,  0): return "SW"   # wall on west edge
    return ""
```

Converts the edge direction (delta between center and adjacent tile) into direction string for lookup.

#### 4. **Runtime Variant Selection (Lines 1645–1684)**

Function: `_paint_subcube_descriptor(cell, face_descriptor, edge_delta)`

```gdscript
# Line 1663: Convert edge to direction
var dir: String = _edge_delta_to_dir(edge_delta)  # → "NW" | "NE" | "SE" | "SW"

# Line 1665: Build tile name
var tile_name := "subcube_%s_%s" % [material, dir]  # → "subcube_concrete_NW"

# Line 1667: Lookup directional variant
var dir_id: int = _subcube_tile_ids.get(tile_name, -1)

# Line 1668: Select directional variant instead of base
if dir_id >= 0:
    active_source_id = dir_id  # Use this tile with its offset
```

When a wall face is detected (via `edge_delta`), the system:
1. Determines the direction the wall faces
2. Constructs the directional variant name
3. Looks up the pre-registered tileset source ID
4. Selects that variant (which has its own offset applied)

## Calibration History

### Iteration 1: (16, -8) — **FAILED**
- **Issue:** Copied from `EDGE_VISUAL_OFFSETS` (nudges for pre-positioned sprites)
- **Result:** Walls positioned *inside* the tile, not at edge
- **Reason:** `EDGE_VISUAL_OFFSETS` nudges sprites that were already positioned near edges; subcube tiles are centered

### Iteration 2: (8, -4) — **INSUFFICIENT**
- **Rationale:** Inverted signs, applied bisection strategy (half the failed value)
- **Result:** Walls closer to edge but still ~4px short of actual boundary
- **Reason:** Underestimated distance to edge from center
- **Feedback:** Visual comparison showed walls needed to push further outward

### Iteration 3: (12, -6) — **CALIBRATED**
- **Rationale:** Increased magnitude while maintaining direction (75% of half-step)
- **Result:** Walls positioned at tile edge, straddling boundary
- **Validation:** Visual feedback confirmed walls now divide edge 50/50 with neighbors
- **Current:** This is the active configuration

## Testing & Validation

To verify the straddle effect:

1. **Inspect offset values** in CODEMAP.md or `room.gd` lines 87–92
2. **Visual in-game test:**
   - Build a room with adjacent subcube walls (different materials)
   - Observe whether wall sprites touch at tile edges
   - Check that each wall appears to occupy exactly half the boundary
3. **Per-direction tuning** (if needed):
   - Edit `SUBCUBE_FACE_OFFSETS` for individual directions
   - Changes apply only to that direction; others unaffected
   - Recompile tileset and reload scene

## Future Work

- **Per-material tuning:** If art requires material-specific straddling
- **Multi-tile wall silhouettes:** Currently single-tile; future may span multiple cells
- **Wall-edge floor shadows:** Geometric shadows cast by wall edges (future layer)
- **Corner fill:** Diagonal corners connecting four wall faces (WALL-EDGE-02)

## Related Code

- `SubcubeGeometry._EDGE_BY_SUFFIX`: Maps direction suffix to edge delta
- `SubcubeGeometry._CORNER_EDGES`: Maps corner names to the two edges they connect
- `_build_subcube_tileset()`: Owns tileset construction
- `_paint_subcube_descriptor()`: Owns runtime variant selection
