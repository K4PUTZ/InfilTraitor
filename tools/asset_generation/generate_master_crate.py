#!/usr/bin/env python3
"""
Generate the FLAT-LIT master crate asset (256x512 px) for INFILTRAITOR.

Master assets are the source-of-truth artwork the game feeds from. They are:
  - FLAT-LIT: no baked shadows or lit faces. Every face shares one neutral
    base colour. The room paints each face darker/lighter at runtime from the
    light projection (face-projection algorithm — built later), so baking light
    here would double up.
  - DIRECTION-AGNOSTIC: one PNG per object, no _NE/_NW/_SE/_SW variants. A
    symmetric iso cube looks identical under all 4 perspective rotations, and
    runtime lighting removes the last reason to pre-render directions. The
    tileset builder feeds this single PNG into all 4 directional slots.

When a master asset is absent, the builder falls back to the provisory
(shaded) placeholders in blocks-prototype/ (tools/generate_crate_simple.py).

Geometry (must match generate_crate_simple.py / the tileset SPRITE_OFFSET):
  - PNG is 256x512. Floor footprint diamond occupies rows 384-512.
  - Vertical faces are CUBE_HEIGHT (128 px) tall -> 4x4x4 true iso subcubes.
"""

from PIL import Image, ImageDraw

# Canvas / grid geometry -----------------------------------------------------
PNG_W, PNG_H = 256, 512
CX = 128                  # horizontal centre of the diamond
TILE_HW, TILE_HH = 128, 64  # diamond half-width / half-height (256x128 cell)
FLOOR_CENTER_Y = 448      # y of the footprint-diamond centre (rows 384-512)
CUBE_HEIGHT = 128         # vertical face height; each 4x4x4 subcube is a true
                          # iso cube. Must equal room.gd CRATE_STACK_STEP_PX.
SUBCUBES = 4              # 4x4x4 sub-cube arrangement -> three lines per face axis

# Colours --------------------------------------------------------------------
# Flat light: ONE base colour for all three visible faces. No top/left/right
# shading -- the room derives that at runtime.
COLOR_FLAT = (220, 132, 46)    # neutral lit orange (same on every face)
COLOR_EDGE = (92, 50, 16)      # silhouette / corner edges (structure, not light)
COLOR_GRID = (120, 66, 22)     # faint subcube subdivisions (structure, not light)
TRANSPARENT = (0, 0, 0, 0)

# Object name -> generator. One flat PNG per object, no direction suffix.
OUTPUT_DIR = (
    "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
    "/ASSETS/ISOMETRIC/master_assets/blocks"
)


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _grid_lines(draw, a, b, c, d, color, divisions=SUBCUBES):
    """Draw subdivision lines across the quad a-b-c-d (a-b and d-c are the rails)."""
    for i in range(1, divisions):
        t = i / divisions
        draw.line([_lerp(a, b, t), _lerp(d, c, t)], fill=color, width=1)
        draw.line([_lerp(a, d, t), _lerp(b, c, t)], fill=color, width=1)


def generate_master_crate():
    """Generate one flat-lit isometric crate cube (256x512 px)."""
    canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)

    # Footprint diamond corners (on the floor) ------------------------------
    bN = (CX, FLOOR_CENTER_Y - TILE_HH)
    bE = (CX + TILE_HW, FLOOR_CENTER_Y)
    bS = (CX, FLOOR_CENTER_Y + TILE_HH)
    bW = (CX - TILE_HW, FLOOR_CENTER_Y)

    # Top diamond corners (lifted by the cube height) -----------------------
    lift = CUBE_HEIGHT
    tN = (bN[0], bN[1] - lift)
    tE = (bE[0], bE[1] - lift)
    tS = (bS[0], bS[1] - lift)
    tW = (bW[0], bW[1] - lift)

    # All faces share COLOR_FLAT -- no baked light.
    draw.polygon([tW, tS, bS, bW], fill=COLOR_FLAT, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tW, tS, bS, bW, COLOR_GRID)

    draw.polygon([tS, tE, bE, bS], fill=COLOR_FLAT, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tS, tE, bE, bS, COLOR_GRID)

    draw.polygon([tN, tE, tS, tW], fill=COLOR_FLAT, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tN, tE, tS, tW, COLOR_GRID)

    # Re-stroke the silhouette edges meeting at the front corner.
    draw.line([tS, bS], fill=COLOR_EDGE, width=2)   # front vertical
    draw.line([tW, tS], fill=COLOR_EDGE, width=2)   # top-left edge
    draw.line([tS, tE], fill=COLOR_EDGE, width=2)   # top-right edge

    return canvas


if __name__ == "__main__":
    out_path = f"{OUTPUT_DIR}/crate.png"
    generate_master_crate().save(out_path, "PNG")
    print(f"✓ {out_path}")
    print("\n✓ Flat-lit master crate created (256x512 px)")
