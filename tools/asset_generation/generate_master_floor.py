#!/usr/bin/env python3
"""
Generate FLAT-LIT floor tile assets for INFILTRAITOR.

Produces: floor_NW / floor_NE / floor_SW / floor_SE

── CANVAS & DIAMOND ──────────────────────────────────────────────────────────
Canvas: 256×512. Floor diamond occupies rows 384–512 (isometric floor plane).

  Floor vertices (canonical):
    bN = (128, 384)   bE = (256, 448)   bS = (128, 512)   bW = (0, 448)

The floor tile is just the 2D diamond with no 3D block height above.
All four directional variants have identical art (omnidirectional geometry).

── GRID SUBDIVISIONS ─────────────────────────────────────────────────────────
Vertical columns: HCUBES=4 columns × 32 px — subdivides the diamond left-right
Horizontal rows:  HCUBES=4 rows × 32 px — subdivides the diamond top-bottom
Combined: 4×4 grid of cells within the diamond.

── EDGE-STRADDLING NOTE ──────────────────────────────────────────────────────
Floor tiles sit entirely within a cell (no straddling). The texture_origin
offset from build_tileset.gd applies the standard SPRITE_OFFSET (shifts up by
384px) to align the bottom 128px of the canvas with the cell's floor diamond.
No direction-specific offset needed for floor (omnidirectional).
"""

from PIL import Image, ImageDraw
import os

# ── Canvas / grid ────────────────────────────────────────────────────────────
PNG_W, PNG_H  = 256, 512
HCUBES        = 4  # horizontal/vertical subdivisions within the diamond

# ── Colors ───────────────────────────────────────────────────────────────────
COLOR_FLAT = (220, 132, 46)   # flat base — no baked directional light
COLOR_EDGE = ( 92,  50, 16)   # silhouette / outline
COLOR_GRID = (120,  66, 22)   # subdivision lines
TRANSPARENT = (0, 0, 0, 0)

OUTPUT_DIR = os.path.join(
    "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR",
    "ASSETS/ISOMETRIC/source_assets/generated",
)

# ── Floor diamond vertices (constant) ────────────────────────────────────────
bN = (128, 384)
bE = (256, 448)
bS = (128, 512)   # canvas bottom edge
bW = (  0, 448)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _lerp(a, b, t):
    """Linear interpolation between two 2D points."""
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _draw_floor_diamond(draw, tL, tR, bR, bL, hcubes):
    """Draw the isometric floor diamond with grid subdivisions."""
    # Fill the diamond
    draw.polygon([tL, tR, bR, bL], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Horizontal bands (parallel to NE-SW edge, top to bottom)
    for i in range(1, hcubes):
        t = i / hcubes
        draw.line([_lerp(tL, bL, t), _lerp(tR, bR, t)], fill=COLOR_GRID, width=1)

    # Vertical bands (parallel to NW-SE edge, left to right)
    for i in range(1, hcubes):
        t = i / hcubes
        draw.line([_lerp(tL, tR, t), _lerp(bL, bR, t)], fill=COLOR_GRID, width=1)

    # Silhouette re-stroke (on top of grid lines)
    draw.line([tL, tR], fill=COLOR_EDGE, width=2)   # top edge
    draw.line([tL, bL], fill=COLOR_EDGE, width=1)   # left edge
    draw.line([tR, bR], fill=COLOR_EDGE, width=1)   # right edge
    draw.line([bL, bR], fill=COLOR_EDGE, width=2)   # bottom edge


def generate():
    """Generate 4 identical floor tile PNGs (omnidirectional)."""
    for direction in ["NW", "NE", "SW", "SE"]:
        canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
        draw = ImageDraw.Draw(canvas)

        # All directions use the same diamond geometry
        _draw_floor_diamond(draw, bN, bE, bS, bW, HCUBES)

        path = os.path.join(OUTPUT_DIR, f"floor_{direction}.png")
        canvas.save(path, "PNG")
        print(f"  ✓ floor_{direction}.png")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("floor (256×512, omnidirectional, 4×4 grid):")
    generate()

    print("\n✓ Done — 4 floor PNGs written to source_assets/generated/")
    print("  Next: rebuild tileset with build_tileset.gd")
