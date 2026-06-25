"""generate_wall.py — INFILTRAITOR wall compositor"""
from PIL import Image
import os, sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_subcube import generate_subcube, MATERIALS, TRANSPARENT

BASE_PATH  = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/master_assets/walls_composed")

OUT_W, OUT_H = 256, 512

# Wall height presets (in subcubes). 4 subcubes = 1 storey.
WALL_PRESETS = {
    "wallFace": 1,
    "wallHalf": 2,
    "wall":     4,
}

N_COLS = 4  # subcubes per tile width

def generate_wall_shape(subcube_img, height_subcubes, n_cols=N_COLS):
    canvas = Image.new("RGBA", (OUT_W, OUT_H), TRANSPARENT)

    # Painter's order: rightmost column first (further from NW camera),
    # bottom-to-top within each column.
    for u in range(n_cols - 1, -1, -1):
        for h in range(height_subcubes):
            dest_x = u * 32
            dest_y = 400 - u * 16 - h * 32  # NW wall: right cols go UP (-16)
            canvas.alpha_composite(subcube_img, dest=(dest_x, dest_y))

    return canvas

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for mat_name, flat, edge in MATERIALS:
        subcube = generate_subcube(mat_name, flat, edge)
        for preset_name, height in WALL_PRESETS.items():
            out_name = f"{preset_name}_{mat_name}.png"
            out_path = os.path.join(OUTPUT_DIR, out_name)
            generate_wall_shape(subcube, height).save(out_path, "PNG")
            print(f"  ✓ {out_name}")

    total = len(MATERIALS) * len(WALL_PRESETS)
    print(f"\n✓ {total} wall PNGs → {OUTPUT_DIR}")
