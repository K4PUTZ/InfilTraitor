#!/usr/bin/env python3
"""
generate_voxel.py — INFILTRAITOR Voxel Atom Generator
======================================================
Gera um PNG 32×36 px por material (átomo de voxel para tileset_voxels.tres).

Executar da raiz do projeto:
    python3 tools/asset_generation/generate_voxel.py

Output: ASSETS/ISOMETRIC/source_assets/voxels/voxel_{material}.png

GEOMETRY (deve coincidir com constantes voxel em VOXEL-02):
    TILE_W  = 32   VOXEL_TILE_SIZE.x
    TILE_H  = 16   VOXEL_TILE_SIZE.y
    SIDE_H  = 20   1.25 × TILE_H  →  VOXEL_STEP_PX = 20
    TOTAL_H = 36   TILE_H + SIDE_H

Face topo  (y=0..15) : diamante isométrico
    N=(16, 0)  E=(32, 8)  S=(16, 16)  W=(0, 8)
Face lateral (y=16..35): retângulo 32×20, darken 80%

Flat-lit: sem shading direcional baked — BakeSystem aplica textura em load-time.
Sem outline: voxels do mesmo material fundem numa superfície de parede contínua.
"""

from __future__ import annotations
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow não instalado. Execute: pip install Pillow")

# ---------------------------------------------------------------------------
# Geometria — deve coincidir com constantes voxel (VOXEL-02)
# ---------------------------------------------------------------------------
TILE_W  = 32
TILE_H  = 16
SIDE_H  = 20        # 1.25 × TILE_H → VOXEL_STEP_PX
TOTAL_H = TILE_H + SIDE_H   # 36

# Vértices da face topo (diamante isométrico 32×16)
V_N = (TILE_W // 2,  0)
V_E = (TILE_W,       TILE_H // 2)
V_S = (TILE_W // 2,  TILE_H)
V_W = (0,            TILE_H // 2)

# Vértices da base (profundidade do cubo)
V_WB = (0,           TILE_H + SIDE_H - TILE_H // 2)    # canto esquerdo base
V_SB = (TILE_W // 2, TILE_H + SIDE_H)                   # canto inferior base
V_EB = (TILE_W,      TILE_H + SIDE_H - TILE_H // 2)    # canto direito base

SIDE_DARKEN: float = 0.80   # faces laterais = 80% da cor base

# ---------------------------------------------------------------------------
# Paleta de materiais — (R, G, B) base, flat-lit
# ---------------------------------------------------------------------------
MATERIALS: dict[str, tuple[int, int, int]] = {
    "concrete": (175, 170, 162),
    "metal":    (138, 148, 158),
    "stone":    (155, 150, 143),
    "wood":     (178, 138,  88),
}

# ---------------------------------------------------------------------------
# DESTRUCTION_MASTER_PLAN D2/D4 — floor/slab palette. Placeholder art: 8
# hand-picked tone variants of one "earth" base color, generated the same
# flat-lit way as MATERIALS above. Real art replaces these later without any
# code change — the D4 hash-selector only cares that 8 files exist at these
# names. NOT grayscale-constrained (B2 governs facade *pattern* sources, not
# these flat material atoms — concrete/wood above aren't grayscale either).
# ---------------------------------------------------------------------------
EARTH_VARIANTS: list[tuple[int, int, int]] = [
    (139, 105,  70),
    (148, 112,  76),
    (130,  98,  64),
    (155, 118,  80),
    (124,  92,  60),
    (143, 108,  74),
    (135, 100,  66),
    (150, 114,  78),
]

# ---------------------------------------------------------------------------
# Floor-zone bake (ground_* materials, MaterialRegistry.full_color=true).
# Same shared cube shape/alpha as MATERIALS above — only the canonical
# silhouette matters here, since the baked page's real color comes from the
# photographic facade source, not this atom's fill. Colors below match
# MaterialRegistry.register_ground_defaults()'s placeholder base_color.
# ---------------------------------------------------------------------------
GROUND_MATERIALS: dict[str, tuple[int, int, int]] = {
    "ground_grass":    (107, 140,  74),
    "ground_concrete": (153, 148, 135),
    "ground_dirt":     (128,  97,  69),
    "ground_gravel":   (140, 133, 125),
    "ground_sand":     (194, 171, 130),
}

# ---------------------------------------------------------------------------
# Output (relativo à raiz do projecto)
# ---------------------------------------------------------------------------
OUTPUT_DIR = Path("ASSETS/ISOMETRIC/source_assets/voxels")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _rgba(rgb: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], alpha)


def _darken(rgb: tuple[int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        max(0, int(rgb[0] * factor)),
        max(0, int(rgb[1] * factor)),
        max(0, int(rgb[2] * factor)),
        255,
    )


# ---------------------------------------------------------------------------
# Gerador principal
# ---------------------------------------------------------------------------

def generate_voxel_atom(base_color: tuple[int, int, int]) -> Image.Image:
    """
    Retorna um Image RGBA 32×36 px com um cubo 3D isométrico:
      y=[0..15]  face topo     — diamante isométrico, cor base
      y=[16..35] faces laterais — esquerda + direita, 80% cor base
    
    Geometria (Painter's algorithm):
      Topo:      N, E, S, W (diamante)
      Esquerda:  W, S, SB, WB (face esquerda mais escura)
      Direita:   S, E, EB, SB (face direita mais clara)
    """
    img  = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Cores
    c_top   = _rgba(base_color)           # topo: cor base
    c_side  = _darken(base_color, SIDE_DARKEN)  # laterais: 80% darken

    # Painter's order (back to front): esquerda → direita → topo
    # Esquerda (NW face)
    draw.polygon([V_W, V_S, V_SB, V_WB], fill=c_side)
    
    # Direita (NE face)
    draw.polygon([V_S, V_E, V_EB, V_SB], fill=c_side)
    
    # Topo (top diamond)
    draw.polygon([V_N, V_E, V_S, V_W], fill=c_top)

    return img


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for material, base_color in MATERIALS.items():
        img  = generate_voxel_atom(base_color)
        path = OUTPUT_DIR / f"voxel_{material}.png"
        img.save(path, "PNG")
        print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")

    for index, base_color in enumerate(EARTH_VARIANTS):
        img  = generate_voxel_atom(base_color)
        path = OUTPUT_DIR / f"voxel_earth_{index}.png"
        img.save(path, "PNG")
        print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")

    for material, base_color in GROUND_MATERIALS.items():
        img  = generate_voxel_atom(base_color)
        path = OUTPUT_DIR / f"voxel_{material}.png"
        img.save(path, "PNG")
        print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")

    total = len(MATERIALS) + len(EARTH_VARIANTS) + len(GROUND_MATERIALS)
    print(f"\n✓ {total} voxel atom(s) → {OUTPUT_DIR}/")
    print("Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes voxel")


if __name__ == "__main__":
    main()
