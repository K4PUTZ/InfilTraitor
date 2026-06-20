#!/usr/bin/env python3
"""
Generate simple crate placeholders (256×512 px) for INFILTRAITOR.
Works with existing tileset system (PNG_SIZE 256×512, SPRITE_OFFSET -384).
"""

from PIL import Image, ImageDraw

# Colors
COLOR_WOOD = (150, 110, 60)
COLOR_DARK = (80, 60, 40)
COLOR_EDGE = (40, 30, 20)
TRANSPARENT = (0, 0, 0, 0)


def generate_simple_crate():
    """Generate a simple crate placeholder (256×512 px)."""
    canvas = Image.new("RGBA", (256, 512), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)

    # The system expects:
    # - Total height: 512 px
    # - Diamond at bottom: rows 384–512 (128 px)
    # - Body above: rows 0–384

    # Simple cube body: fill most of the canvas with a solid color + edges
    # Draw a simple box representation of a crate

    # Main body (simplified cube)
    # Top face
    draw.rectangle([(64, 100), (192, 200)], fill=COLOR_WOOD, outline=COLOR_EDGE, width=2)

    # Left side
    draw.rectangle([(20, 200), (64, 360)], fill=COLOR_DARK, outline=COLOR_EDGE, width=2)

    # Right side
    draw.rectangle([(192, 200), (236, 360)], fill=COLOR_WOOD, outline=COLOR_EDGE, width=2)

    # Front face (main)
    draw.rectangle([(64, 200), (192, 380)], fill=COLOR_WOOD, outline=COLOR_EDGE, width=2)

    # Diamond at bottom (for alignment with cell)
    # Diamond corners (centered at x=128)
    top = (128, 384)
    right = (256, 448)
    bottom = (128, 512)
    left = (0, 448)

    draw.polygon([top, right, bottom, left], fill=COLOR_DARK, outline=COLOR_EDGE)

    # Add some edge lines for visual separation
    draw.line([(64, 240), (192, 240)], fill=COLOR_EDGE, width=1)
    draw.line([(64, 280), (192, 280)], fill=COLOR_EDGE, width=1)
    draw.line([(64, 320), (192, 320)], fill=COLOR_EDGE, width=1)

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
