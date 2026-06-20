#!/usr/bin/env python3
"""
Generate simple crate placeholders (256×512 px) for INFILTRAITOR.
Works with existing tileset system (PNG_SIZE 256×512, SPRITE_OFFSET -384).
Uses isometric diamond geometry matching the grid.
"""

from PIL import Image, ImageDraw

# Colors
COLOR_WOOD_TOP = (180, 140, 80)       # top face (lit)
COLOR_WOOD_LEFT = (140, 105, 60)      # left face
COLOR_WOOD_RIGHT = (160, 120, 70)     # right face
COLOR_DARK = (80, 60, 40)             # dark/shadow areas
COLOR_EDGE = (40, 30, 20)             # edge lines
TRANSPARENT = (0, 0, 0, 0)


def generate_simple_crate():
    """Generate isometric crate placeholder (256×512 px) with diamond geometry."""
    canvas = Image.new("RGBA", (256, 512), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)

    # The system expects:
    # - Total height: 512 px
    # - Diamond at bottom: rows 384–512 (128 px) for alignment
    # - Body above: rows 0–384

    # Isometric diamond parameters
    # Center at x=128, diamond extends ±128 in width, ±64 in height per level
    cx = 128

    # Build the crate with stacked diamonds (isometric perspective)
    # Level 1 (top of body): rows 64–192
    top1_top = (cx, 64)
    top1_right = (cx + 128, 128)
    top1_bottom = (cx, 192)
    top1_left = (cx - 128, 128)

    # Draw top face (light)
    draw.polygon([top1_top, top1_right, top1_bottom, top1_left],
                 fill=COLOR_WOOD_TOP, outline=COLOR_EDGE, width=1)

    # Level 2 (middle): rows 192–320
    mid_top = (cx, 192)
    mid_right = (cx + 128, 256)
    mid_bottom = (cx, 320)
    mid_left = (cx - 128, 256)

    # Left face of middle section
    draw.polygon([top1_left, top1_bottom, mid_bottom, mid_left],
                 fill=COLOR_WOOD_LEFT, outline=COLOR_EDGE, width=1)

    # Right face of middle section
    draw.polygon([top1_right, top1_bottom, mid_bottom, mid_right],
                 fill=COLOR_WOOD_RIGHT, outline=COLOR_EDGE, width=1)

    # Level 3 (bottom body): rows 320–384
    bot_top = (cx, 320)
    bot_right = (cx + 128, 352)
    bot_bottom = (cx, 384)
    bot_left = (cx - 128, 352)

    # Continue left and right faces
    draw.polygon([mid_left, mid_bottom, bot_bottom, bot_left],
                 fill=COLOR_WOOD_LEFT, outline=COLOR_EDGE, width=1)
    draw.polygon([mid_right, mid_bottom, bot_bottom, bot_right],
                 fill=COLOR_WOOD_RIGHT, outline=COLOR_EDGE, width=1)

    # Diamond at bottom (for alignment with cell) - rows 384–512
    diamond_top = (cx, 384)
    diamond_right = (256, 448)
    diamond_bottom = (cx, 512)
    diamond_left = (0, 448)

    # Bottom diamond connects body to floor
    draw.polygon([diamond_top, diamond_right, diamond_bottom, diamond_left],
                 fill=COLOR_DARK, outline=COLOR_EDGE, width=1)

    # Add subtle horizontal lines to show crate planks
    for y in [96, 128, 160, 192, 224, 256, 288, 320, 352]:
        # Draw line across the body at this height (approximately)
        # This is a visual separation, not geometrically precise
        if y < 384:
            draw.line([(cx - 64, y), (cx + 64, y)], fill=COLOR_EDGE, width=1)

    return canvas


def generate_rotated_variants():
    """Generate 4 rotations of the crate."""
    base = generate_simple_crate()

    output_dir = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/ASSETS/ISOMETRIC/blocks-prototype/Isometric"

    rotations = {
        "NE": 0,
        "SE": 1,
        "SW": 2,
        "NW": 3,
    }

    for direction, num_rotations in rotations.items():
        rotated = base.rotate(90 * num_rotations, expand=False)
        output_path = f"{output_dir}/crate_{direction}.png"
        rotated.save(output_path, "PNG")
        print(f"✓ {output_path}")


if __name__ == "__main__":
    generate_rotated_variants()
    print("\n✓ Simple crate placeholders created (256×512 px)")
