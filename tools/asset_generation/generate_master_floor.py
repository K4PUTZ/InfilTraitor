#!/usr/bin/env python3
"""
Generate the floor_layer placeholder tiles for INFILTRAITOR.

Produces: floor_NW / floor_NE / floor_SW / floor_SE

── WHY THIS IS A FLAT PLACEHOLDER, NOT PAINTED ART ───────────────────────────
DESTRUCTION_MASTER_PLAN.md Part 4 ("Legacy floor assets retired"): floor_layer
(room.gd $FloorLayer, z_index=-9) is confirmed always fully covered by the
level -1 voxel earth layer (z_index=0) painted in the same synchronous
build_from_layout() call — this sprite is provably never seen by the player,
under any destruction state (max excavation depth is 1 voxel; digging can
never reveal a void, per D13). Do not restore detailed art here: it would be
wasted render/generation cost for pixels nobody sees.

What still matters: floor_layer's TileMapLayer occupancy (one valid tile per
cell) is load-bearing for ~30 files that call floor_layer.map_to_local() /
.get_cell_source_id() for coordinate math and floor-presence checks (e.g.
selection_controller.gd). So a tile must still be registered here — it just
doesn't need to look like anything.

── CANVAS ─────────────────────────────────────────────────────────────────
Canvas: 256×512, floor diamond occupies rows 384–512 (isometric floor plane).
Same dimensions as before on purpose: build_tileset.gd derives the TileSet
region and texture_origin from the PNG's actual size, so keeping 256×512
means zero downstream changes to build_tileset.gd/tile_registry.gd.

  Floor vertices (canonical):
    bN = (128, 384)   bE = (256, 448)   bS = (128, 512)   bW = (0, 448)

All four directional variants share identical geometry (omnidirectional).
"""

from PIL import Image, ImageDraw
import os

# ── Canvas ───────────────────────────────────────────────────────────────────
PNG_W, PNG_H  = 256, 512

# ── Colors ───────────────────────────────────────────────────────────────────
COLOR_FLAT = (220, 132, 46)   # flat placeholder fill — never actually visible
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


def _draw_floor_diamond(draw, tL, tR, bR, bL):
    """Flat-fill the floor diamond. No outline/grid — never rendered on screen."""
    draw.polygon([tL, tR, bR, bL], fill=COLOR_FLAT)


def generate():
    """Generate 4 identical floor placeholder PNGs (omnidirectional)."""
    for direction in ["NW", "NE", "SW", "SE"]:
        canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
        draw = ImageDraw.Draw(canvas)

        # All directions use the same diamond geometry
        _draw_floor_diamond(draw, bN, bE, bS, bW)

        path = os.path.join(OUTPUT_DIR, f"floor_{direction}.png")
        canvas.save(path, "PNG")
        print(f"  ✓ floor_{direction}.png")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("floor placeholder (256×512, flat fill, never visible):")
    generate()

    print("\n✓ Done — 4 floor PNGs written to source_assets/generated/")
    print("  Next: rebuild tileset with build_tileset.gd")
