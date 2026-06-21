#!/usr/bin/env python3
"""
Generate FLAT-LIT master wall face assets for INFILTRAITOR.

Produces:
  wall_NW / wall_SW / wall_NE / wall_SE
  wallHalf_NW / wallHalf_SW / wallHalf_NE / wallHalf_SE

── CANVAS & DIAMOND ──────────────────────────────────────────────────────────
Canvas: 256×512. Floor diamond occupies rows 384–512 (matches SPRITE_OFFSET).

  Floor vertices:
    bN = (128, 384)   bE = (256, 448)   bS = (128, 512)   bW = (0, 448)

  Top vertices (floor vertex lifted by WALL_HEIGHT = 160 px):
    tN = (128, 224)   tE = (256, 288)   tS = (128, 352)   tW = (0, 288)

  Half-wall top vertices (HALF_HEIGHT = 80 px):
    tN = (128, 304)   tE = (256, 368)   tS = (128, 432)   tW = (0, 368)

── FACE GEOMETRY ─────────────────────────────────────────────────────────────
Each wall tile is ONE parallelogram face placed on one edge of the tile
diamond. Parallelogram corners are given as (tL, tR, bR, bL):

  NW: (tN, tE, bE, bN)  — upper-right, slope +0.5  x∈[128,256]  y∈[224,448]
  SW: (tW, tN, bN, bW)  — upper-left,  slope −0.5  x∈[0,128]    y∈[224,448]
  NE: (tS, tE, bE, bS)  — lower-right, slope −0.5  x∈[128,256]  y∈[352,512]
  SE: (tW, tS, bS, bW)  — lower-left,  slope +0.5  x∈[0,128]    y∈[288,512]

  NE and SE faces reach bS=(128,512), the bottom of the canvas. This is
  intentional — they straddle the lower portion of the tile.

── GRID SUBDIVISIONS ─────────────────────────────────────────────────────────
Horizontal bands (parallel to the floor edge, structural — not baked light):
  Full wall:  5 bands × 32 px = WALL_HEIGHT  → 4 dividing lines
  Half wall:  2 bands (coarser for shorter face)

Vertical columns (true vertical lines):
  4 columns × 32 px = 128 px tile half-width → 3 dividing lines

── EDGE-STRADDLING NOTE ──────────────────────────────────────────────────────
The texture_origin offsets in build_tileset.gd (EDGE_VISUAL_OFFSETS) shift
each sprite to straddle the tile boundary. These PNGs place the face at the
standard diamond edge; texture_origin does the rest — do not bake any nudge
here.
"""

from PIL import Image, ImageDraw
import os

# ── Canvas / grid ────────────────────────────────────────────────────────────
PNG_W, PNG_H  = 256, 512
WALL_HEIGHT   = 160          # 5 subcubes × 32 px
HALF_HEIGHT   =  80          # 2.5 subcubes (wallHalf)
HCUBES        =   4          # horizontal columns  (128 px / 32 px)
VCUBES_FULL   =   5          # vertical bands, full wall (160 px / 32 px)
VCUBES_HALF   =   2          # vertical bands, half wall

# ── Colors ───────────────────────────────────────────────────────────────────
COLOR_FLAT = (220, 132, 46)   # flat base — no baked directional light
COLOR_EDGE = ( 92,  50, 16)   # structural silhouette / outline
COLOR_GRID = (120,  66, 22)   # subcube subdivision lines
TRANSPARENT = (0, 0, 0, 0)

OUTPUT_DIR = os.path.join(
    "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR",
    "ASSETS/ISOMETRIC/master_assets/walls",
)

# ── Floor diamond vertices (constant) ────────────────────────────────────────
bN = (128, 384)
bE = (256, 448)
bS = (128, 512)   # canvas bottom edge — NE/SE faces reach here
bW = (  0, 448)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _top(v, h):
    """Lift floor vertex v by h pixels."""
    return (v[0], v[1] - h)


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _draw_face(draw, tL, tR, bR, bL, vcubes):
    """
    Draw one flat wall parallelogram.

    tL / tR / bR / bL are the four corners:
      tL = top-left    tR = top-right
      bL = bot-left    bR = bot-right
    (left = smaller x; within a column tL and bL share the same x)

    Grid line logic:
      Horizontal bands: lerp(tL→bL, t) → lerp(tR→bR, t)
        → lines parallel to the floor edge (slope ±0.5)
      Vertical columns: lerp(tL→tR, t) → lerp(bL→bR, t)
        → truly vertical (same x on both endpoints)
    """
    draw.polygon([tL, tR, bR, bL], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Horizontal bands (parallel to floor edge)
    for i in range(1, vcubes):
        t = i / vcubes
        draw.line([_lerp(tL, bL, t), _lerp(tR, bR, t)], fill=COLOR_GRID, width=1)

    # Vertical columns
    for i in range(1, HCUBES):
        t = i / HCUBES
        draw.line([_lerp(tL, tR, t), _lerp(bL, bR, t)], fill=COLOR_GRID, width=1)

    # Re-stroke prominent silhouette edges
    draw.line([tL, tR], fill=COLOR_EDGE, width=2)   # wall top
    draw.line([tL, bL], fill=COLOR_EDGE, width=2)   # left silhouette
    draw.line([tR, bR], fill=COLOR_EDGE, width=2)   # right silhouette


# ── Face definitions ──────────────────────────────────────────────────────────
#
# Keys: direction string → lambda(tN, tE, tS, tW) → (tL, tR, bR, bL)
# Bottom vertices (bN, bE, bS, bW) are constant for all wall heights.
#
FACE_DEF = {
    #           tL    tR    bR    bL
    "NW": lambda tN, tE, tS, tW: (tN, tE, bE, bN),
    "SW": lambda tN, tE, tS, tW: (tW, tN, bN, bW),
    "NE": lambda tN, tE, tS, tW: (tS, tE, bE, bS),
    "SE": lambda tN, tE, tS, tW: (tW, tS, bS, bW),
}


def generate(base_name, wall_h, vcubes):
    tN = _top(bN, wall_h)
    tE = _top(bE, wall_h)
    tS = _top(bS, wall_h)
    tW = _top(bW, wall_h)

    for direction, face_fn in FACE_DEF.items():
        tL, tR, bR, bL = face_fn(tN, tE, tS, tW)
        canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
        draw   = ImageDraw.Draw(canvas)
        _draw_face(draw, tL, tR, bR, bL, vcubes)
        path = os.path.join(OUTPUT_DIR, f"{base_name}_{direction}.png")
        canvas.save(path, "PNG")
        print(f"  ✓ {base_name}_{direction}.png")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("wall (160 px, 5 bands):")
    generate("wall", WALL_HEIGHT, VCUBES_FULL)

    print("wallHalf (80 px, 2 bands):")
    generate("wallHalf", HALF_HEIGHT, VCUBES_HALF)

    print("\n✓ Done — 8 master wall PNGs written to master_assets/walls/")
    print("  Next: run build_tileset.gd to rebuild tileset_blocks.tres")
