#!/usr/bin/env python3
"""
Generate FLAT-LIT master corner wall assets for INFILTRAITOR.

Produces:
  wallCorner_NE / wallCorner_NW / wallCorner_SE / wallCorner_SW
  wallCornerHalf_NE / wallCornerHalf_NW / wallCornerHalf_SE / wallCornerHalf_SW

── CANVAS DIMENSIONS ─────────────────────────────────────────────────────────
Corners need asymmetrically expanded canvases to fill the gap created by
edge-straddling wall faces. Two wall faces are shifted outward by texture_origin
offsets (±16px, ±8px); the corner bridges this gap.

  NW / SE corners → 320×512 (expand RIGHT: [0, 320] instead of [0, 256])
  NE / SW corners → 256×528 (expand DOWN: [0, 528] instead of [0, 512])

── CORNER GEOMETRY ───────────────────────────────────────────────────────────
Each corner is an INNER CORNER where two wall faces meet at the grid vertex.
The corner point and the two meeting faces are:

  NE (at tE):
    • NW wall front face (upper-right quadrant)
    • NE wall front face (lower-right quadrant)
    • Both face toward camera (orthogonal meeting)

  NW (at tN):
    • NW wall front face (upper-right quadrant)
    • SW wall front face (upper-left quadrant)
    • NW faces away, SW faces away (parallel-facing, connected by top)

  SE (at bS):
    • SE wall front face (lower-left quadrant)
    • NE wall front face (lower-right quadrant)
    • Both face toward camera (orthogonal meeting)

  SW (at tW):
    • SW wall front face (upper-left quadrant)
    • SE wall front face (lower-left quadrant)
    • SW faces away, SE faces toward (orthogonal meeting)

The floor diamond is SHARED between both wall faces at their meeting point.
"""

from PIL import Image, ImageDraw
import os

# ── Canvas dimensions ────────────────────────────────────────────────────────
WALL_HEIGHT   = 160          # 5 subcubes × 32 px
HALF_HEIGHT   =  80          # 2.5 subcubes (wallCornerHalf)
HCUBES        =   4          # horizontal columns (128 px / 32 px)
VCUBES_FULL   =   5          # vertical bands, full wall
VCUBES_HALF   =   2          # vertical bands, half wall

# ── Corner-specific canvas dimensions ────────────────────────────────────────
# NW/SE: wider (right expansion); NE/SW: taller (bottom expansion)
CANVAS_BASE   = (256, 512)
CANVAS_NW_SE  = (320, 512)   # expand RIGHT
CANVAS_NE_SW  = (256, 528)   # expand DOWN

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
bS = (128, 512)
bW = (  0, 448)

# ── Depth offset per direction (same as walls) ────────────────────────────────
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
    draw.line([tL, tR],         fill=COLOR_EDGE, width=2)   # front top edge
    draw.line([tL, tL_back],    fill=COLOR_EDGE, width=1)
    draw.line([tR, tR_back],    fill=COLOR_EDGE, width=1)
    draw.line([tL_back, tR_back], fill=COLOR_EDGE, width=1)


def _draw_end(draw, t_tip, b_tip, offset):
    """Camera-visible end face of the slab (one narrow parallelogram)."""
    t_back = _add(t_tip, offset)
    b_back = _add(b_tip, offset)
    draw.polygon([t_tip, t_back, b_back, b_tip], fill=COLOR_FLAT, outline=COLOR_EDGE)


# ── Corner specification: which two directions meet and their canvas size ────

def _corner_specs(tN, tE, tS, tW):
    """Corner specifications: (dir1, dir2, canvas_size, dir1_faces, dir2_faces)"""
    return {
        # NE corner: tE vertex (upper-right)
        # NW wall (upper-right quadrant) + NE wall (lower-right quadrant)
        # Canvas 256×528 (tall)
        "NE": {
            "canvas": CANVAS_NE_SW,
            "walls": [
                {
                    "dir": "NW",
                    "front": (tN, tE, bE, bN),
                    "end": (tE, bE),
                    "offset": DEPTH["NW"],
                },
                {
                    "dir": "NE",
                    "front": (tS, tE, bE, bS),
                    "end": (tS, bS),
                    "offset": DEPTH["NE"],
                },
            ]
        },
        # NW corner: tN vertex (top-center)
        # NW wall (upper-right) + SW wall (upper-left)
        # Canvas 320×512 (wide)
        "NW": {
            "canvas": CANVAS_NW_SE,
            "walls": [
                {
                    "dir": "NW",
                    "front": (tN, tE, bE, bN),
                    "end": (tE, bE),
                    "offset": DEPTH["NW"],
                },
                {
                    "dir": "SW",
                    "front": (tW, tN, bN, bW),
                    "end": (tW, bW),
                    "offset": DEPTH["SW"],
                },
            ]
        },
        # SE corner: bS vertex (bottom-center)
        # SE wall (lower-left) + NE wall (lower-right)
        # Canvas 320×512 (wide)
        "SE": {
            "canvas": CANVAS_NW_SE,
            "walls": [
                {
                    "dir": "SE",
                    "front": (tW, tS, bS, bW),
                    "end": (tS, bS),
                    "offset": DEPTH["SE"],
                },
                {
                    "dir": "NE",
                    "front": (tS, tE, bE, bS),
                    "end": (tS, bS),
                    "offset": DEPTH["NE"],
                },
            ]
        },
        # SW corner: tW vertex (left-center)
        # SW wall (upper-left) + SE wall (lower-left)
        # Canvas 256×528 (tall)
        "SW": {
            "canvas": CANVAS_NE_SW,
            "walls": [
                {
                    "dir": "SW",
                    "front": (tW, tN, bN, bW),
                    "end": (tW, bW),
                    "offset": DEPTH["SW"],
                },
                {
                    "dir": "SE",
                    "front": (tW, tS, bS, bW),
                    "end": (tS, bS),
                    "offset": DEPTH["SE"],
                },
            ]
        },
    }


def generate(base_name, wall_h, vcubes):
    tN = _top(bN, wall_h)
    tE = _top(bE, wall_h)
    tS = _top(bS, wall_h)
    tW = _top(bW, wall_h)

    specs = _corner_specs(tN, tE, tS, tW)

    for corner_dir, spec in specs.items():
        canvas_size = spec["canvas"]
        walls = spec["walls"]

        canvas = Image.new("RGBA", canvas_size, TRANSPARENT)
        draw = ImageDraw.Draw(canvas)

        # Draw both walls for this corner
        for wall_info in walls:
            direction = wall_info["dir"]
            tL, tR, bR, bL = wall_info["front"]
            t_tip, b_tip = wall_info["end"]
            offset = wall_info["offset"]

            if direction in ("NW", "SW"):
                # The original edge faces AWAY from the camera.
                # Camera-facing surface is the offset (back) face.
                off_tL = _add(tL, offset)
                off_tR = _add(tR, offset)
                off_bR = _add(bR, offset)
                off_bL = _add(bL, offset)
                neg = (-offset[0], -offset[1])
                _draw_end(draw, _add(t_tip, offset), _add(b_tip, offset), neg)
                _draw_top(draw, off_tL, off_tR, neg)
                _draw_front(draw, off_tL, off_tR, off_bR, off_bL, vcubes)
            else:
                # NE/SE: original edge faces the camera directly.
                _draw_end(draw, t_tip, b_tip, offset)
                _draw_top(draw, tL, tR, offset)
                _draw_front(draw, tL, tR, bR, bL, vcubes)

        path = os.path.join(OUTPUT_DIR, f"{base_name}_{corner_dir}.png")
        canvas.save(path, "PNG")
        print(f"  ✓ {base_name}_{corner_dir}.png ({canvas_size[0]}×{canvas_size[1]})")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("wallCorner (160 px, 5 bands):")
    generate("wallCorner", WALL_HEIGHT, VCUBES_FULL)

    print("wallCornerHalf (80 px, 2 bands):")
    generate("wallCornerHalf", HALF_HEIGHT, VCUBES_HALF)

    print("\n✓ Done — 8 master corner wall PNGs written to master_assets/walls/")
    print("  Next: run build_tileset.gd to rebuild tileset_blocks.tres")
