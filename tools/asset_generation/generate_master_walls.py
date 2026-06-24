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
Each wall tile is a 3D slab with three visible faces from the isometric camera:
  • Front face  — the main vertical parallelogram on the tile edge
  • Top face    — thin parallelogram on top of the slab (shows depth from above)
  • End face    — one visible end of the slab (camera-facing side)

Front faces (tL, tR, bR, bL):
  NW: (tN, tE, bE, bN)  — upper-right, slope +0.5  x∈[128,256]
  SW: (tW, tN, bN, bW)  — upper-left,  slope −0.5  x∈[0,128]
  NE: (tS, tE, bE, bS)  — lower-right, slope −0.5  x∈[128,256]
  SE: (tW, tS, bS, bW)  — lower-left,  slope +0.5  x∈[0,128]

── WALL DEPTH / THICKNESS ────────────────────────────────────────────────────
Walls straddle tile boundaries — half the slab depth sits in each neighbouring
tile. Measured from the provisory Kenney assets: depth = 32 px screen-x = 1/4
tile step perpendicular to the face (verified all 4 directions).

Depth offsets (shift from front face to back face):
  NW: (-32, +16)  — perpendicular to NE edge, going NW into tile
  SW: (+32, +16)  — perpendicular to NW edge, going SE into tile
  NE: (-32, -16)  — perpendicular to SE edge, going NW into tile
  SE: (+32, -16)  — perpendicular to SW edge, going NE into tile

The top face uses these offsets to show the slab thickness from above.
The end face shows the camera-visible end of the slab.

── GRID SUBDIVISIONS ─────────────────────────────────────────────────────────
Horizontal bands (parallel to floor edge, structural — not baked light):
  Full wall: VCUBES_FULL=4 bands × 40 px
  Half wall: VCUBES_HALF=2 bands × 40 px

Vertical columns: HCUBES=4 columns × 32 px

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
WALL_HEIGHT   = 160          # 4 subcubes × 40 px
HALF_HEIGHT   =  80          # 2 subcubes (wallHalf)
HCUBES        =   4          # horizontal columns (128 px / 32 px)
VCUBES_FULL   =   4          # vertical bands, full wall
VCUBES_HALF   =   2          # vertical bands, half wall

# ── Colors ───────────────────────────────────────────────────────────────────
COLOR_FLAT = (220, 132, 46)   # flat base — no baked directional light
COLOR_EDGE = ( 92,  50, 16)   # structural silhouette / outline
COLOR_GRID = (120,  66, 22)   # subcube subdivision lines
TRANSPARENT = (0, 0, 0, 0)

OUTPUT_DIR = os.path.join(
    "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR",
    "ASSETS/ISOMETRIC/source_assets/generated",
)

# ── Floor diamond vertices (constant) ────────────────────────────────────────
bN = (128, 384)
bE = (256, 448)
bS = (128, 512)   # canvas bottom edge — NE/SE faces reach here
bW = (  0, 448)

# ── Depth offset per direction ────────────────────────────────────────────────
# 1/4 tile step perpendicular to the face, going toward tile interior.
# Measured from provisory assets: 32 px screen-x in all 4 directions.
DEPTH = {
    "NW": (-32, +16),
    "SW": (+32, +16),
    "NE": (-32, -16),
    "SE": (+32, -16),
}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _add(v, offset):
    return (v[0] + offset[0], v[1] + offset[1])

def _top(v, h):
    return (v[0], v[1] - h)

def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _draw_front(draw, tL, tR, bR, bL, vcubes):
    """Main vertical face with grid lines."""
    draw.polygon([tL, tR, bR, bL], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Horizontal bands (parallel to floor edge)
    for i in range(1, vcubes):
        t = i / vcubes
        draw.line([_lerp(tL, bL, t), _lerp(tR, bR, t)], fill=COLOR_GRID, width=1)

    # Vertical columns
    for i in range(1, HCUBES):
        t = i / HCUBES
        draw.line([_lerp(tL, tR, t), _lerp(bL, bR, t)], fill=COLOR_GRID, width=1)

    # Silhouette re-stroke
    draw.line([tL, tR], fill=COLOR_EDGE, width=2)   # wall top edge
    draw.line([tL, bL], fill=COLOR_EDGE, width=2)   # left silhouette
    draw.line([tR, bR], fill=COLOR_EDGE, width=2)   # right silhouette


def _draw_top(draw, tL, tR, offset):
    """Thin top face showing slab thickness from above."""
    tL_back = _add(tL, offset)
    tR_back = _add(tR, offset)
    draw.polygon([tL, tR, tR_back, tL_back], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Column lines matching the front face (HCUBES subdivisions)
    for i in range(1, HCUBES):
        t = i / HCUBES
        draw.line([_lerp(tL, tR, t), _lerp(tL_back, tR_back, t)],
                  fill=COLOR_GRID, width=1)

    # Silhouette re-stroke (on top of grid lines)
    draw.line([tL, tR],           fill=COLOR_EDGE, width=2)   # front top edge
    draw.line([tL, tL_back],      fill=COLOR_EDGE, width=1)
    draw.line([tR, tR_back],      fill=COLOR_EDGE, width=1)
    draw.line([tL_back, tR_back], fill=COLOR_EDGE, width=1)


def _draw_end(draw, t_tip, b_tip, offset, vcubes):
    """Camera-visible end face of the slab (one narrow parallelogram)."""
    t_back = _add(t_tip, offset)
    b_back = _add(b_tip, offset)
    draw.polygon([t_tip, t_back, b_back, b_tip], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Horizontal bands matching the front face (vcubes subdivisions)
    # No vertical columns — 32px depth is too narrow for readable subdivisions
    for i in range(1, vcubes):
        t = i / vcubes
        draw.line([_lerp(t_tip, b_tip, t), _lerp(t_back, b_back, t)],
                  fill=COLOR_GRID, width=1)

    # Silhouette re-stroke
    draw.line([t_tip, t_back],  fill=COLOR_EDGE, width=1)   # top edge
    draw.line([b_tip, b_back],  fill=COLOR_EDGE, width=1)   # bottom edge
    draw.line([t_tip, b_tip],   fill=COLOR_EDGE, width=1)   # front edge
    draw.line([t_back, b_back], fill=COLOR_EDGE, width=1)   # back edge


# ── Face definitions ──────────────────────────────────────────────────────────
#
# Each entry: (tL, tR, bR, bL) for front face, end_tip=(t_tip, b_tip) for the
# camera-visible end (right end for NW/NE, left end for SW/SE).
#
def _faces(tN, tE, tS, tW):
    # End face tip = the canvas-interior corner of the front face, NOT the outer
    # corner at x=0 or x=256 (which gets clipped or covered by the front face).
    # NW/SW share the bN/tN center vertex (x=128); NE/SE share bS/tS (x=128).
    # Depth offset moves these inward to x=96 or x=160, both fully within canvas.
    return {
        "NW": dict(front=(tN, tE, bE, bN), end=(tE, bE)),  # end at tE (right — clears front x-range)
        "SW": dict(front=(tW, tN, bN, bW), end=(tW, bW)),  # end at tW (left — clears front x-range)
        "NE": dict(front=(tS, tE, bE, bS), end=(tS, bS)),  # end at tS (left of front)
        "SE": dict(front=(tW, tS, bS, bW), end=(tS, bS)),  # end at tS (right of front)
    }


def generate(base_name, wall_h, vcubes):
    tN = _top(bN, wall_h)
    tE = _top(bE, wall_h)
    tS = _top(bS, wall_h)
    tW = _top(bW, wall_h)

    faces = _faces(tN, tE, tS, tW)

    for direction, spec in faces.items():
        tL, tR, bR, bL = spec["front"]
        t_tip, b_tip   = spec["end"]
        offset         = DEPTH[direction]

        canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
        draw   = ImageDraw.Draw(canvas)

        if direction in ("NW", "SW"):
            # The original edge faces AWAY from the camera for NW/SW.
            # The camera-facing surface is the offset (back) face.
            # Top and end faces connect offset face back to the original edge,
            # so the depth for those is the negative offset.
            off_tL = _add(tL, offset)
            off_tR = _add(tR, offset)
            off_bR = _add(bR, offset)
            off_bL = _add(bL, offset)
            neg    = (-offset[0], -offset[1])
            _draw_end(draw, _add(t_tip, offset), _add(b_tip, offset), neg, vcubes)
            _draw_top(draw, off_tL, off_tR, neg)
            _draw_front(draw, off_tL, off_tR, off_bR, off_bL, vcubes)
        else:
            # NE/SE: original edge faces the camera directly.
            _draw_end(draw, t_tip, b_tip, offset, vcubes)
            _draw_top(draw, tL, tR, offset)
            _draw_front(draw, tL, tR, bR, bL, vcubes)

        path = os.path.join(OUTPUT_DIR, f"{base_name}_{direction}.png")
        canvas.save(path, "PNG")
        print(f"  ✓ {base_name}_{direction}.png")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("wall (160 px, 4 bands):")
    generate("wall", WALL_HEIGHT, VCUBES_FULL)

    print("wallHalf (80 px, 2 bands):")
    generate("wallHalf", HALF_HEIGHT, VCUBES_HALF)

    print("wallFace (40 px, 1 band — atomic subcube):")
    generate("wallFace", 40, 1)

    print("\n✓ Done — 12 master wall PNGs written to source_assets/generated/")
    print("  Note: tileset rebuild happens in SUB-00-B after folder reorganization.")
