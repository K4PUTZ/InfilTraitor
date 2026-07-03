"""generate_subcube.py — INFILTRAITOR subcube atom generator  v2
=================================================================
CHANGES vs v1
  Canvas:      64 × 72  px  (era 64 × 64)
  Face height: 40 px         (era 32 px)
  Step:        SUBCUBE_STEP_PX = 40.0  (era 39.5) → seamless vertical
  texture_origin Godot: Vector2i(0, -40)  (era -32)
  4 × 40 px = 160 px/storey  ≈  WALL_FLOOR_STEP_PX 158 px  (diff 2 px)

GEOMETRY
  Floor diamond — transparente, ancora o tile no TileMap:
    bN=(32,40)  bE=(64,56)  bS=(32,72)  bW=( 0,56)

  Top face — inalterada em relação à v1:
    tN=(32, 0)  tE=(64,16)  tS=(32,32)  tW=( 0,16)

  Faces laterais — altura 40 px  (tW.y=16 → bW.y=56):
    Left : tW → tS → bS → bW
    Right: tS → tE → bE → bS

SHADING FLAT-LIT (placeholder; FaceLightingController fará overlay runtime)
  Top:   100 %  (face mais iluminada — luz de cima)
  Left:  82 %   (face NW — luz ambiente lateral)
  Right: 68 %   (face NE — shadow side)

TILE MAP (Godot)
  tile_size       = Vector2i(64, 32)   ← inalterado
  texture_origin  = Vector2i( 0, -40) ← era -32
  SUBCUBE_STEP_PX = 40.0              ← era 39.5
"""
from PIL import Image, ImageDraw
import os

BASE_PATH  = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/source_assets/subcubes")

PNG_W, PNG_H = 64, 72
TRANSPARENT  = (0, 0, 0, 0)

MATERIALS = [
    ("concrete", (195, 185, 170), (70,  62,  54)),
    ("stone",    (152, 148, 142), (55,  52,  48)),
    ("wood",     (175, 125,  72), (85,  50,  22)),
    ("metal",    (158, 164, 172), (58,  62,  68)),
]

# ── vértices ──────────────────────────────────────────────────────────────────
bN = (32, 40);  bE = (64, 56);  bS = (32, 72);  bW = ( 0, 56)  # floor diamond
tN = (32,  0);  tE = (64, 16);  tS = (32, 32);  tW = ( 0, 16)  # top face


def _darken(rgb: tuple, factor: float) -> tuple:
    return tuple(max(0, int(c * factor)) for c in rgb)


def generate_subcube(color_flat: tuple, color_edge: tuple) -> Image.Image:
    canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
    draw   = ImageDraw.Draw(canvas)

    c_top   = color_flat
    c_left  = _darken(color_flat, 0.82)
    c_right = _darken(color_flat, 0.68)

    # Painter's order: left → right → top (back to front)
    draw.polygon([tW, tS, bS, bW], fill=c_left,  outline=color_edge, width=1)
    draw.polygon([tS, tE, bE, bS], fill=c_right, outline=color_edge, width=1)
    draw.polygon([tN, tE, tS, tW], fill=c_top,   outline=color_edge, width=1)

    # Bold silhouette — cristas do cubo
    draw.line([tW, tS], fill=color_edge, width=2)   # crista topo-esquerda
    draw.line([tS, tE], fill=color_edge, width=2)   # crista topo-direita
    draw.line([tS, bS], fill=color_edge, width=2)   # aresta vertical central

    return canvas


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for mat, flat, edge in MATERIALS:
        fname = f"subcube_{mat}.png"
        generate_subcube(flat, edge).save(os.path.join(OUTPUT_DIR, fname), "PNG")
        print(f"  ✓ {fname}  (64×72)")
    print(f"\n✓ {len(MATERIALS)} subcube atoms → {OUTPUT_DIR}")
    print("Próximo: importar no Godot (abrir editor ou --import),")
    print("         ajustar SUBCUBE_STEP_PX=40 e texture_origin=(0,-40) em room.gd.")
