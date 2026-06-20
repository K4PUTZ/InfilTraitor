#!/usr/bin/env python3
"""
Generate simple isometric crate placeholders (256x512 px) for INFILTRAITOR.

These are temporary placeholders that define the *correct shape and dimensions*
so they can guide the final artwork. Each crate is a single isometric cube whose
floor footprint matches the 256x128 grid diamond.

Geometry (must not drift):
  - PNG is 256x512. The floor footprint diamond occupies rows 384-512 and is
    aligned to the cell by the tileset's SPRITE_OFFSET (0, -384).
  - The cube's vertical faces are CUBE_HEIGHT (128 px) tall, so each of the
    2x2x2 subcubes is a true iso cube. This MUST match room.gd
    CRATE_STACK_STEP_PX (128.0): a stacked crate seats its sprite CUBE_HEIGHT px
    higher, so the cube body height has to equal the stack step for the stack to
    read as a seamless tower.
  - A symmetric cube looks identical under all 4 perspective rotations, so the
    same image is written for NE/SE/SW/NW. NEVER rotate the iso sprite in screen
    space (rotate(90)) -- that shears the diamond and breaks the perspective.
"""

from PIL import Image, ImageDraw

# Canvas / grid geometry -----------------------------------------------------
PNG_W, PNG_H = 256, 512
CX = 128                  # horizontal centre of the diamond
TILE_HW, TILE_HH = 128, 64  # diamond half-width / half-height (256x128 cell)
FLOOR_CENTER_Y = 448      # y of the footprint-diamond centre (rows 384-512)
CUBE_HEIGHT = 128         # vertical face height; each 2x2x2 subcube is then a true
                          # iso cube (128x64 footprint, 64px face). Must equal room.gd
                          # CRATE_STACK_STEP_PX so stacks seat seamlessly.
SUBCUBES = 2              # 2x2x2 sub-cube arrangement -> one subdivision line per face axis

# Colours (orange placeholder block, matching the project palette) -----------
COLOR_TOP = (238, 150, 56)     # top face (lit)
COLOR_LEFT = (176, 100, 30)    # left/SW face (shadowed)
COLOR_RIGHT = (210, 126, 42)   # right/SE face (mid)
COLOR_EDGE = (92, 50, 16)      # silhouette / corner edges
COLOR_GRID = (120, 66, 22)     # faint plank subdivisions
TRANSPARENT = (0, 0, 0, 0)


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _grid_lines(draw, a, b, c, d, color, divisions=SUBCUBES):
    """Draw subdivision lines across the quad a-b-c-d (a-b and d-c are the rails)."""
    for i in range(1, divisions):
        t = i / divisions
        # lines parallel to edge b-c
        draw.line([_lerp(a, b, t), _lerp(d, c, t)], fill=color, width=1)
        # lines parallel to edge a-d
        draw.line([_lerp(a, d, t), _lerp(b, c, t)], fill=color, width=1)


def generate_simple_crate():
    """Generate one isometric crate cube (256x512 px)."""
    canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)

    # Footprint diamond corners (on the floor) ------------------------------
    bN = (CX, FLOOR_CENTER_Y - TILE_HH)   # (128, 384)
    bE = (CX + TILE_HW, FLOOR_CENTER_Y)   # (256, 448)
    bS = (CX, FLOOR_CENTER_Y + TILE_HH)   # (128, 512)
    bW = (CX - TILE_HW, FLOOR_CENTER_Y)   # (0,   448)

    # Top diamond corners (lifted by the cube height) -----------------------
    lift = CUBE_HEIGHT
    tN = (bN[0], bN[1] - lift)            # (128, 288)
    tE = (bE[0], bE[1] - lift)            # (256, 352)
    tS = (bS[0], bS[1] - lift)            # (128, 416)
    tW = (bW[0], bW[1] - lift)            # (0,   352)

    # Left face (W-S side, shadowed) ----------------------------------------
    draw.polygon([tW, tS, bS, bW], fill=COLOR_LEFT, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tW, tS, bS, bW, COLOR_GRID)

    # Right face (S-E side, mid) --------------------------------------------
    draw.polygon([tS, tE, bE, bS], fill=COLOR_RIGHT, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tS, tE, bE, bS, COLOR_GRID)

    # Top face (lit) -- drawn last so it sits above the side faces ----------
    draw.polygon([tN, tE, tS, tW], fill=COLOR_TOP, outline=COLOR_EDGE, width=1)
    _grid_lines(draw, tN, tE, tS, tW, COLOR_GRID)

    # Re-stroke the three silhouette edges meeting at the front corner so the
    # cube reads crisply over the grid lines.
    draw.line([tS, bS], fill=COLOR_EDGE, width=2)   # front vertical
    draw.line([tW, tS], fill=COLOR_EDGE, width=2)   # top-left edge
    draw.line([tS, tE], fill=COLOR_EDGE, width=2)   # top-right edge

    return canvas


def generate_rotated_variants():
    """Write the cube to all 4 perspective slots (identical -- no rotation)."""
    base = generate_simple_crate()

    output_dir = (
        "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
        "/ASSETS/ISOMETRIC/blocks-prototype/Isometric"
    )

    for direction in ("NE", "SE", "SW", "NW"):
        output_path = f"{output_dir}/crate_{direction}.png"
        base.save(output_path, "PNG")
        print(f"✓ {output_path}")


if __name__ == "__main__":
    generate_rotated_variants()
    print("\n✓ Isometric crate placeholders created (256x512 px)")
