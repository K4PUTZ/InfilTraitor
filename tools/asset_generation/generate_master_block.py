#!/usr/bin/env python3
"""
generate_master_block.py — Generate 1-subcubo solid blocks (3 visible isometric faces).

DESIGN:
  - Canvas: 256×512px
  - Floor diamond: rows 384–512 (center, omnidirectional)
  - Solid block: 1 subcubo height (40px visual)
  - 3 visible faces: two vertical fronts (left + right) + one thin top (depth)
  
The block is drawn as a full 3D cube in isometric view:
  • Left-front face (NW-SW edge): vertical parallelogram
  • Right-front face (NE-SE edge): vertical parallelogram
  • Top face: thin parallelogram showing cube depth

Each direction (NW/NE/SW/SE) is OMNIDIRECTIONAL (same asset, rotated at runtime
or used in all 4 orientations with the same visual).

OUTPUT: block_NW, block_NE, block_SW, block_SE (256×512, RGBA)

PIPELINE POSITION: Follows SUB-00-C (floor); precedes SUB-00-E (map updates).
"""

from PIL import Image, ImageDraw
import os

# Spatial constants
SUBCUBE_FACE_HEIGHT = 40  # 1 subcubo visual height
BLOCK_DEPTH_OFFSET = (32, 16)  # depth offset for top face (isometric perspective)

# Canvas & floor diamond
CANVAS_WIDTH, CANVAS_HEIGHT = 256, 512

# Colors
COLOR_FLAT = (230, 170, 80)      # warm tan (left + top faces)
COLOR_SIDE = (240, 100, 80)      # warm coral (right face, distinct shading)
COLOR_GRID = (200, 130, 40, 200) # grid lines
COLOR_EDGE = (50, 30, 10)        # dark outline

# Grid divisions
HCUBES = 4  # horizontal columns (top face)
VCUBES = 1  # vertical bands (1 subcubo = 1 band)

OUTPUT_DIR = "ASSETS/ISOMETRIC/source_assets/generated"


def _lerp(a, b, t):
    """Linear interpolation between two points."""
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _add(p, offset):
    """Add offset to point."""
    return (p[0] + offset[0], p[1] + offset[1])


def _draw_face_vertical(draw, tL, tR, bR, bL, hcubes, color):
    """
    Draw a vertical isometric face with grid.
    tL, tR, bR, bL = corners of the parallelogram (top-left, top-right, bottom-right, bottom-left).
    hcubes = number of horizontal column divisions.
    color = fill color.
    """
    # Fill face
    draw.polygon([tL, tR, bR, bL], fill=color)
    
    # Vertical columns (left-right divisions)
    for i in range(1, hcubes):
        t = i / hcubes
        draw.line([_lerp(tL, bL, t), _lerp(tR, bR, t)], fill=COLOR_GRID, width=1)
    
    # Silhouette edges (drawn last for clarity)
    draw.line([tL, tR], fill=COLOR_EDGE, width=2)  # top edge
    draw.line([tL, bL], fill=COLOR_EDGE, width=2)  # left edge
    draw.line([tR, bR], fill=COLOR_EDGE, width=2)  # right edge
    draw.line([bL, bR], fill=COLOR_EDGE, width=2)  # bottom edge


def _draw_face_top(draw, tL, tR, offset, hcubes):
    """
    Draw thin top face showing cube depth.
    tL, tR = front edge (top of the vertical faces).
    offset = (dx, dy) offset for the back edge (depth in isometric perspective).
    hcubes = horizontal column divisions.
    """
    tL_back = _add(tL, offset)
    tR_back = _add(tR, offset)
    
    # Fill top face
    draw.polygon([tL, tR, tR_back, tL_back], fill=COLOR_FLAT)
    
    # Column lines
    for i in range(1, hcubes):
        t = i / hcubes
        draw.line([_lerp(tL, tR, t), _lerp(tL_back, tR_back, t)], fill=COLOR_GRID, width=1)
    
    # Silhouette edges
    draw.line([tL, tR], fill=COLOR_EDGE, width=2)          # front edge
    draw.line([tL_back, tR_back], fill=COLOR_EDGE, width=2)  # back edge
    draw.line([tL, tL_back], fill=COLOR_EDGE, width=1)     # left depth
    draw.line([tR, tR_back], fill=COLOR_EDGE, width=1)     # right depth


def generate(tile_name=None):
    """
    Generate 4 omnidirectional block tiles.
    Each is 256×512 with a 1-subcubo solid cube rendered in isometric view.
    
    Block structure (from top view):
      • Base: diamond-shaped floor (yellow/tan)
      • Left face: vertical parallelogram facing NW-SW (tan)
      • Right face: vertical parallelogram facing NE-SE (coral)
      • Top: thin depth indicator
    
    Order of drawing: base first (behind), then left face, then right face, then top.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for direction in ["NW", "NE", "SW", "SE"]:
        # Create canvas
        img = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)
        
        # ── CUBE VERTICES ────────────────────────────────────────────────────────
        
        # Base diamond floor (y: 384-448, 64px tall)
        d_cx, d_y = 128, 384
        n_base = (d_cx, d_y)              # North (top) — (128, 384)
        e_base = (d_cx + 64, d_y + 32)    # East (right) — (192, 416)
        s_base = (d_cx, d_y + 64)         # South (bottom) — (128, 448)
        w_base = (d_cx - 64, d_y + 32)    # West (left) — (64, 416)
        
        # Top of cube (40px above base)
        h = SUBCUBE_FACE_HEIGHT
        n_top = (n_base[0], n_base[1] - h)  # (128, 344)
        e_top = (e_base[0], e_base[1] - h)  # (192, 376)
        w_top = (w_base[0], w_base[1] - h)  # (64, 376)
        
        # ── DRAW BLOCK ───────────────────────────────────────────────────────────
        # Order: base → left face → right face → top (for proper occlusion)
        
        # 1. BASE DIAMOND (floor, visible as the "foundation")
        #    This is the bottom of the cube
        base_face = [n_base, e_base, s_base, w_base]
        draw.polygon(base_face, fill=(200, 150, 60))  # darker tan for base
        
        # 2. LEFT FACE (NW-SW direction)
        #    Quad from north-base up to north-top, across to west-top, down to west-base
        left_face = [n_base, n_top, w_top, w_base]
        draw.polygon(left_face, fill=COLOR_FLAT)
        
        # Grid on left face (vertical columns)
        for i in range(1, HCUBES):
            t = i / HCUBES
            p_top = _lerp(n_top, w_top, t)
            p_base = _lerp(n_base, w_base, t)
            draw.line([p_top, p_base], fill=COLOR_GRID, width=1)
        
        # 3. RIGHT FACE (NE-SE direction)
        #    Quad from north-base up to north-top, across to east-top, down to east-base
        right_face = [n_base, n_top, e_top, e_base]
        draw.polygon(right_face, fill=COLOR_SIDE)
        
        # Grid on right face (vertical columns)
        for i in range(1, HCUBES):
            t = i / HCUBES
            p_top = _lerp(n_top, e_top, t)
            p_base = _lerp(n_base, e_base, t)
            draw.line([p_top, p_base], fill=COLOR_GRID, width=1)
        
        # 4. TOP FACE (thin depth indicator)
        #    Thin parallelogram showing the block extends back
        n_top_back = _add(n_top, BLOCK_DEPTH_OFFSET)
        e_top_back = _add(e_top, BLOCK_DEPTH_OFFSET)
        
        top_face = [n_top, e_top, e_top_back, n_top_back]
        draw.polygon(top_face, fill=COLOR_FLAT)
        
        # Grid on top face
        for i in range(1, HCUBES):
            t = i / HCUBES
            p_front = _lerp(n_top, e_top, t)
            p_back = _lerp(n_top_back, e_top_back, t)
            draw.line([p_front, p_back], fill=COLOR_GRID, width=1)
        
        # ── EDGE OUTLINES (drawn last for clarity) ─────────────────────────────────
        
        # Base edges
        draw.line([n_base, e_base], fill=COLOR_EDGE, width=2)
        draw.line([e_base, s_base], fill=COLOR_EDGE, width=2)
        draw.line([s_base, w_base], fill=COLOR_EDGE, width=2)
        draw.line([w_base, n_base], fill=COLOR_EDGE, width=2)
        
        # Vertical edges (left face)
        draw.line([n_base, n_top], fill=COLOR_EDGE, width=2)
        draw.line([w_base, w_top], fill=COLOR_EDGE, width=2)
        draw.line([n_top, w_top], fill=COLOR_EDGE, width=2)
        
        # Vertical edges (right face)
        draw.line([e_base, e_top], fill=COLOR_EDGE, width=2)
        draw.line([n_top, e_top], fill=COLOR_EDGE, width=2)
        
        # Top back edges
        draw.line([n_top, n_top_back], fill=COLOR_EDGE, width=1)
        draw.line([e_top, e_top_back], fill=COLOR_EDGE, width=1)
        draw.line([n_top_back, e_top_back], fill=COLOR_EDGE, width=1)
        
        # Save
        output_path = os.path.join(OUTPUT_DIR, f"block_{direction}.png")
        img.save(output_path)
        print(f"  ✓ block_{direction}.png")
    
    print(f"\n✓ Done — 4 block PNGs written to {OUTPUT_DIR}/")
    print(f"  Next: rebuild tileset with build_tileset.gd")


if __name__ == "__main__":
    print(f"block (256×512, omnidirectional, 1 subcubo):")
    generate()
