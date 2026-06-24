#!/usr/bin/env python3
"""
generate_master_block.py — Generate 1-subcubo solid blocks (3 visible isometric faces).

DESIGN:
  - Canvas: 256×512px
  - Floor diamond: rows 384–512 (center, omnidirectional)
  - Top face: 4×4 grid (HCUBES=4)
  - End face (right): 1 vertical band (solid)
  - Front face: 4 vertical band (solid, 1 SUBCUBE_FACE_HEIGHT)
  - All 3 faces share COLOR_FLAT (interior), COLOR_GRID (lines), COLOR_EDGE (outline)

OUTPUT: block_NW, block_NE, block_SW, block_SE (256×512, RGBA)

PIPELINE POSITION: Follows SUB-00-C (floor); precedes SUB-00-E (map updates).
"""

from PIL import Image, ImageDraw
import os

# Spatial constants (reference from OPERATOR_CONTEXT.md)
SUBCUBES_PER_FLOOR = 4
SUBCUBE_FACE_HEIGHT = 40  # art property; visual height per subcubo
SUBCUBE_STEP_PX = 39.5    # render: 158.0/4, with 0.5px overlap

# Canvas & floor diamond (same as walls)
CANVAS_WIDTH, CANVAS_HEIGHT = 256, 512
FLOOR_TOP_ROW = 384
FLOOR_BOTTOM_ROW = 512

# Colors (consistent with walls)
COLOR_FLAT = (230, 170, 80)      # warm tan
COLOR_GRID = (200, 130, 40, 200) # grid lines, slightly transparent
COLOR_EDGE = (50, 30, 10)        # dark outline
COLOR_FRONT = (240, 100, 80)     # warm coral (front face)

# Grid divisions
HCUBES = 4  # horizontal (top face columns)
VCUBES = 1  # vertical (front face rows, i.e., 1 subcubo)

OUTPUT_DIR = "ASSETS/ISOMETRIC/source_assets/generated"


def _lerp(a, b, t):
    """Linear interpolation."""
    return a + (b - a) * t


def _draw_floor_diamond(draw, tL, tR, bR, bL, hcubes):
    """
    Fill and grid a 2D floor diamond.
    tL, tR, bR, bL = corner points (x, y).
    hcubes = number of horizontal divisions.
    """
    # Fill diamond
    draw.polygon([tL, tR, bR, bL], fill=COLOR_FLAT)
    
    # Draw outline
    draw.line([tL, tR, bR, bL, tL], fill=COLOR_EDGE, width=2)
    
    # Grid lines
    for i in range(1, hcubes):
        t = i / hcubes
        # Left edge → right edge
        left_point = (_lerp(tL[0], bL[0], t), _lerp(tL[1], bL[1], t))
        right_point = (_lerp(tR[0], bR[0], t), _lerp(tR[1], bR[1], t))
        draw.line([left_point, right_point], fill=COLOR_GRID, width=1)
        
        # Top edge → bottom edge
        top_point = (_lerp(tL[0], tR[0], t), _lerp(tL[1], tR[1], t))
        bottom_point = (_lerp(bL[0], bR[0], t), _lerp(bL[1], bR[1], t))
        draw.line([top_point, bottom_point], fill=COLOR_GRID, width=1)


def _draw_top(draw, t_tip, b_tip, l_tip, r_tip, offset):
    """
    Draw top isometric face (diamond, 4×4 grid).
    t_tip, b_tip, l_tip, r_tip = corner points.
    offset = vertical offset from canvas top.
    """
    # Draw diamond (floor)
    _draw_floor_diamond(draw, t_tip, r_tip, b_tip, l_tip, HCUBES)
    
    # Column lines (vertical divisions)
    for i in range(1, HCUBES):
        t = i / HCUBES
        left_point = (_lerp(l_tip[0], t_tip[0], t), _lerp(l_tip[1], t_tip[1], t))
        right_point = (_lerp(l_tip[0], b_tip[0], t), _lerp(l_tip[1], b_tip[1], t))
        draw.line([left_point, right_point], fill=COLOR_GRID, width=1)


def _draw_end(draw, t_tip, b_tip, offset, vcubes):
    """
    Draw right isometric face (end/side face, 1 vertical subcubo).
    t_tip, b_tip = top and bottom points of diamond right edge.
    offset = vertical offset from canvas top.
    vcubes = number of vertical subdivisions (1 for 1-subcubo block).
    """
    # Right face at 1-subcubo height
    face_height = SUBCUBE_FACE_HEIGHT
    
    # Right edge of diamond is vertical; extend up by face_height
    x_right = b_tip[0]
    y_diamond = b_tip[1]
    y_top = y_diamond - face_height
    
    # Right face is a parallelogram (isometric)
    top_left = (x_right, y_top)
    top_right = (x_right + 64, y_top - 32)
    bottom_right = (x_right + 64, y_diamond - 32)
    bottom_left = (x_right, y_diamond)
    
    # Fill
    draw.polygon([top_left, top_right, bottom_right, bottom_left], fill=COLOR_FRONT)
    
    # Outline
    draw.line([top_left, top_right, bottom_right, bottom_left, top_left], 
              fill=COLOR_EDGE, width=2)


def _draw_front(draw, t_left, t_right, b_right, b_left):
    """
    Draw front isometric face (vertical face, VCUBES rows).
    t_left, t_right, b_right, b_left = corners of front face.
    """
    # Fill front face
    draw.polygon([t_left, t_right, b_right, b_left], fill=COLOR_FRONT)
    
    # Draw outline
    draw.line([t_left, t_right, b_right, b_left, t_left], fill=COLOR_EDGE, width=2)
    
    # Horizontal grid lines (row divisions)
    for i in range(1, VCUBES):
        t = i / VCUBES
        left_point = (_lerp(t_left[0], b_left[0], t), _lerp(t_left[1], b_left[1], t))
        right_point = (_lerp(t_right[0], b_right[0], t), _lerp(t_right[1], b_right[1], t))
        draw.line([left_point, right_point], fill=COLOR_GRID, width=1)


def generate(tile_name=None):
    """
    Generate 4 omnidirectional block tiles.
    Each is 256×512 with floor diamond + 3 visible faces.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for direction in ["NW", "NE", "SW", "SE"]:
        # Create canvas
        img = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)
        
        # Isometric cube positioning
        # Diamond (floor) center
        d_center_x = 128
        d_top_y = 384
        
        # Diamond corners (2.5D isometric, 128px wide, 64px tall)
        d_left = (d_center_x - 64, d_top_y + 32)     # Left point
        d_top = (d_center_x, d_top_y)                # Top point
        d_right = (d_center_x + 64, d_top_y + 32)    # Right point
        d_bottom = (d_center_x, d_top_y + 64)        # Bottom point
        
        # Draw floor diamond (base)
        _draw_floor_diamond(draw, d_top, d_right, d_bottom, d_left, HCUBES)
        
        # Draw 3 faces extending upward
        # Face height = SUBCUBE_FACE_HEIGHT = 40px
        
        # Front-left face (left vertical face)
        fl_top_left = (d_left[0], d_left[1] - SUBCUBE_FACE_HEIGHT)
        fl_top_right = (d_top[0], d_top[1] - SUBCUBE_FACE_HEIGHT)
        fl_bottom_right = d_top
        fl_bottom_left = d_left
        _draw_front(draw, fl_top_left, fl_top_right, fl_bottom_right, fl_bottom_left)
        
        # Front-right face (right vertical face)
        fr_top_left = (d_top[0], d_top[1] - SUBCUBE_FACE_HEIGHT)
        fr_top_right = (d_right[0], d_right[1] - SUBCUBE_FACE_HEIGHT)
        fr_bottom_right = d_right
        fr_bottom_left = d_top
        _draw_front(draw, fr_top_left, fr_top_right, fr_bottom_right, fr_bottom_left)
        
        # Top face (copy of diamond logic, but higher)
        top_left = (d_left[0], d_left[1] - SUBCUBE_FACE_HEIGHT)
        top_right = (d_top[0], d_top[1] - SUBCUBE_FACE_HEIGHT)
        top_bottom_right = (d_right[0], d_right[1] - SUBCUBE_FACE_HEIGHT)
        top_bottom_left = (d_bottom[0], d_bottom[1] - SUBCUBE_FACE_HEIGHT)
        _draw_top(draw, top_left, top_bottom_left, top_left, top_right, d_top_y)
        
        # Save
        output_path = os.path.join(OUTPUT_DIR, f"block_{direction}.png")
        img.save(output_path)
        print(f"  ✓ block_{direction}.png")
    
    print(f"\n✓ Done — 4 block PNGs written to {OUTPUT_DIR}/")
    print(f"  Next: rebuild tileset with build_tileset.gd")


if __name__ == "__main__":
    print(f"block (256×512, omnidirectional, 1 subcubo):")
    generate()
