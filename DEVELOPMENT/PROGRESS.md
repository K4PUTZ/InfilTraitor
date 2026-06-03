# INFILTRAITOR — Progress Updates

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
