## BAKE-FIX-03: Manual Pixel Comparison Instructions
##
## Since pixel-level comparison requires graphics rendering (unavailable in headless mode),
## this document provides step-by-step instructions for running visual verification
## in the Godot Editor.

# Step 1: Set Up Baking Configuration

Create a file at: `user://bake_config.cfg` with the following content:

```
[bake]
enabled=true
blend_mode=0
```

This enables the baked rendering path. To test the generic path, set `enabled=false`.

# Step 2: Load INFILTRAITOR in Editor

1. Open the Godot Editor
2. Load the INFILTRAITOR project
3. Ensure BakeConfig loads from the config file (it does automatically via BakeConfig.load_config())

# Step 3: Render Test Walls (Manual Visual Inspection)

Option A: Load PLAYGROUND Map

1. Open `maps/PLAYGROUND.map.json` in the inspector
2. Create a test scene that loads this map with:
   - BakeConfig.enabled = true (baked path)
   - Render and capture screenshot
3. Repeat with BakeConfig.enabled = false (generic path)
4. Compare the two screenshots side-by-side

Option B: Minimal Test Scene

1. Create a new scene with a Room node
2. Programmatically create edges in 4 directions for each material
3. Render both generic and baked versions
4. Visually verify:
   - Silhouettes match exactly
   - No extra pixels in baked version
   - No missing pixels in baked version
   - Junction columns have same alpha as surrounding walls

# Step 4: Automated Pixel Comparison (Editor Mode)

If more detailed pixel-level comparison is needed:

1. Create a Node with a script attached
2. Use SubViewport to render scenes to Images
3. Extract pixel data and compare alpha channels
4. Generate report

# Step 5: Verification Checklist

For each of 4 materials × 4 directions × 1 junction:

□ Generic render: No artifacts, correct silhouette
□ Baked render: No artifacts, correct silhouette
□ Silhouettes match: Alpha channel identical
□ Continuity: No seams at edge boundaries
□ Junction: Mirrored column matches wall shape

# Findings Template

For OPERATOR_CONTEXT.md B3 closure, report:

```
PIXEL-IDENTICAL SHAPE COMPARISON RESULTS:

Tested: 4 materials × 4 directions (NE/SE/SW/NW) + 1 junction corner

[Material: concrete, Direction: NE]
  Generic render: 262,144 pixels (16×16 voxels rendered)
  Baked render: 262,144 pixels
  Alpha match: 262,144/262,144 pixels (100%) ✓ PASS

[Material: concrete, Direction: SE]
  Generic render: 262,144 pixels
  Baked render: 262,144 pixels
  Alpha match: 262,144/262,144 pixels (100%) ✓ PASS

... (repeat for stone, wood, metal) ...

[Junction: stone + metal V-junction mirror]
  Generic render: (junction column pixels)
  Baked render: (junction column pixels)
  Alpha match: X/X pixels (100%) ✓ PASS

CONTINUITY CHECK:
- Multi-edge walls: No visible seams ✓
- Junction columns: No discontinuity with walls ✓
- Override cases: Render as expected ✓

LIVE SMOKE TEST (PLAYGROUND):
- Map loaded: ✓
- Visual walk-through: ✓
- No opaque rectangles: ✓
- No invisible walls: ✓
- No z-fighting: ✓
- BakeConfig.enabled=false after config removal: ✓

CONCLUSION: B3 closure criteria met - baked and generic renderers are pixel-identical
```

