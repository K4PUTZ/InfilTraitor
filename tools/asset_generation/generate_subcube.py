"""generate_subcube.py — INFILTRAITOR 1/4-tile atomic subcube generator"""
from PIL import Image, ImageDraw
import os

BASE_PATH  = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/master_assets/subcubes")

PNG_W, PNG_H = 64, 64
TRANSPARENT  = (0, 0, 0, 0)

MATERIALS = [
    ("concrete", (195, 185, 170), (70,  62,  54)),
    ("stone",    (152, 148, 142), (55,  52,  48)),
    ("wood",     (175, 125,  72), (85,  50,  22)),
    ("metal",    (158, 164, 172), (58,  62,  68)),
]

def generate_subcube(material_name, color_flat, color_edge):
    canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
    draw   = ImageDraw.Draw(canvas)

    # Floor diamond (NOT drawn — stays transparent for stacking)
    bN = (32, 32); bE = (64, 48); bS = (32, 64); bW = (0, 48)

    # Top face (lifted by 32px)
    tN = (32, 0); tE = (64, 16); tS = (32, 32); tW = (0, 16)

    # Draw faces in painter's order
    draw.polygon([tW, tS, bS, bW], fill=color_flat, outline=color_edge, width=1)  # left
    draw.polygon([tS, tE, bE, bS], fill=color_flat, outline=color_edge, width=1)  # right
    draw.polygon([tN, tE, tS, tW], fill=color_flat, outline=color_edge, width=1)  # top

    # Re-stroke silhouette
    draw.line([tS, bS], fill=color_edge, width=2)
    draw.line([tW, tS], fill=color_edge, width=2)
    draw.line([tS, tE], fill=color_edge, width=2)

    return canvas

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for name, flat, edge in MATERIALS:
        path = os.path.join(OUTPUT_DIR, f"subcube_{name}.png")
        generate_subcube(name, flat, edge).save(path, "PNG")
        print(f"  ✓ subcube_{name}.png")
    print(f"\n✓ {len(MATERIALS)} subcube atoms → {OUTPUT_DIR}")
