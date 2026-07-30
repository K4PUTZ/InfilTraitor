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
    # D22 (Director, 2026-07-30) — 5th wall material, DESTROYED-only (no
    # DENTED/CRACKED tier, see MaterialResistanceTable). Pale cyan placeholder;
    # real glass art is the Director's own future pass, not this generator's.
    "glass":    (188, 210, 214),
}

# ---------------------------------------------------------------------------
# D22 — impact-mark pseudo-materials (placeholder "vector" marks). Real
# per-material photographic bakes are the Director's own pass, dropped into
# IMPACT_OUTPUT_DIR at these exact filenames — zero code changes on swap.
# Glass is excluded: it has no DENTED/CRACKED tier by design.
# ---------------------------------------------------------------------------
IMPACT_OUTPUT_DIR = Path("ASSETS/ISOMETRIC/source_assets/voxels/impact_marks")
IMPACT_MATERIALS: list[str] = ["concrete", "metal", "stone", "wood"]

# Top-face diamond center (TILE_W/2, TILE_H/2) = (16, 8); radii kept small
# enough to stay inside the diamond's taper near its N/S points rather than
# bleeding into the transparent corners outside the cube silhouette.
_MARK_CENTER = (TILE_W // 2, TILE_H // 2)
_DENT_OUTER_RADIUS = 5
_DENT_CORE_RADIUS = 2
_CRACK_RADIUS = 4


def generate_impact_mark(base_img: "Image.Image", dented: bool) -> "Image.Image":
    """
    Overlay a placeholder bullet-impact mark onto a copy of an existing voxel
    atom's top face.

    dented=True:  a dark rim around a TRUE alpha-cut core — the "meio voxel"
                  sunken look (Director, 2026-07-30): "um voxel inteiro com a
                  geometria modificada pra ter metade em alpha", so whatever
                  renders behind this tile shows through the core, selling
                  depth without any sub-tile geometry (Rule 8 stays satisfied
                  — still one flat PNG through set_cell()).
    dented=False: a smaller, opaque dark mark — a flat surface graze, no
                  sinking, no alpha.
    """
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    cx, cy = _MARK_CENTER
    if dented:
        draw.ellipse(
            [cx - _DENT_OUTER_RADIUS, cy - _DENT_OUTER_RADIUS,
             cx + _DENT_OUTER_RADIUS, cy + _DENT_OUTER_RADIUS],
            fill=(22, 19, 17, 255),
        )
        draw.ellipse(
            [cx - _DENT_CORE_RADIUS, cy - _DENT_CORE_RADIUS,
             cx + _DENT_CORE_RADIUS, cy + _DENT_CORE_RADIUS],
            fill=(0, 0, 0, 0),
        )
    else:
        draw.ellipse(
            [cx - _CRACK_RADIUS, cy - _CRACK_RADIUS,
             cx + _CRACK_RADIUS, cy + _CRACK_RADIUS],
            fill=(38, 33, 30, 235),
        )
    return img

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

    # D22 — impact-mark placeholders (dented/cracked), one pair per non-glass
    # wall material, built from each material's own base atom above.
    IMPACT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    impact_count = 0
    for material in IMPACT_MATERIALS:
        base_img = generate_voxel_atom(MATERIALS[material])
        for suffix, dented in (("dented", True), ("cracked", False)):
            img  = generate_impact_mark(base_img, dented)
            path = IMPACT_OUTPUT_DIR / f"voxel_{material}_{suffix}.png"
            img.save(path, "PNG")
            print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")
            impact_count += 1
    print(f"\n✓ {impact_count} impact-mark placeholder(s) → {IMPACT_OUTPUT_DIR}/")
    print("Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes voxel")


if __name__ == "__main__":
    main()
