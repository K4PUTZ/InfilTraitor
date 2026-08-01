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
Face lateral (y=16..35): SW darken 70%, SE darken 88% (FACE-READ-01:
    três tons distintos, nunca dois — ver SIDE_DARKEN_LEFT/RIGHT)

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

# FACE-READ-01 (Director, 2026-07-31): the three visible faces of a voxel must
# NEVER share a value. Until now both side faces used one SIDE_DARKEN (0.80),
# so a voxel had only TWO tones (top 1.00 / both sides 0.80) and runs of voxels
# fused into flat blobs — *"não dá pra saber exatamente como as superfícies em
# 3D estão posicionadas."* The docstring in generate_voxel_atom() had specified
# "face esquerda mais escura / face direita mais clara" since the file was
# written; only the constant was missing, so the two polygons were filled from
# the same variable. Three distinct tones now, which is what makes each
# dimension explicit.
SIDE_DARKEN_LEFT: float = 0.70    # SW-facing (screen-left), the darkest plane
SIDE_DARKEN_RIGHT: float = 0.88   # SE-facing (screen-right), catches more light

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
# D23 (Director, 2026-07-30) — blast impact marks. "A granada produzindo
# buracos de bala não faz sentido [...] estados intermediários do material em
# explosões, mas não com furos redondos." Deliberately NOT drawn with
# draw.ellipse: a jagged fixed polygon for the sunken/dented look (an
# off-centre alpha-cut "missing chunk", not a clean circular hole) and
# branching crack LINES (not a filled blob) for the flat/cracked look — reads
# as chipped/fractured rather than punctured, at a glance, from across the
# room, which is the whole point. Points are hand-picked and deterministic,
# not randomised — same reproducibility contract every generator in this
# file already has.
#
# Sized to nearly fill the top-face diamond (2026-07-31, Director: the
# apply_container_damage() ring scatter — D22, unchanged here — picks many
# separate, non-adjacent voxels per blast, so small marks read as an isolated
# pinprick scatter ("buracos de bala") regardless of their individual shape.
# Widening each mark toward the diamond's own N/E/S/W edges means picks that
# land on neighbouring voxels visually touch/merge into one blotch instead of
# staying legible as separate dots — a texture-only fix, the scatter itself
# (D22, shared with every RADIAL caller) is untouched.
# ---------------------------------------------------------------------------
_BLAST_DENT_OUTLINE = [(16, 1), (24, 5), (29, 8), (24, 12), (16, 14), (8, 12), (3, 8), (6, 5)]
_BLAST_DENT_CHIP = [(17, 3), (23, 6), (21, 11), (13, 9)]
_BLAST_CRACK_LINES = [
    [(16, 8), (9, 2)],
    [(16, 8), (23, 3)],
    [(16, 8), (28, 9)],
    [(16, 8), (22, 13)],
    [(16, 8), (14, 15)],
    [(9, 2), (4, 7)],
    [(23, 3), (27, 6)],
]


def generate_blast_mark(base_img: "Image.Image", dented: bool) -> "Image.Image":
    """
    Overlay a placeholder BLAST-damage mark (chipped/cracked, never a round
    puncture) onto a copy of an existing voxel atom's top face.

    dented=True:  a jagged polygon with a smaller, OFF-CENTRE true alpha-cut
                  "missing chunk" — an uneven chip, not a centred bullet hole.
    dented=False: a handful of branching crack LINES radiating from a rough
                  centre — a fracture, not a filled dot.
    """
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    if dented:
        draw.polygon(_BLAST_DENT_OUTLINE, fill=(24, 20, 17, 255))
        draw.polygon(_BLAST_DENT_CHIP, fill=(0, 0, 0, 0))
    else:
        for seg in _BLAST_CRACK_LINES:
            draw.line(seg, fill=(35, 30, 27, 230), width=2)
    return img

# ---------------------------------------------------------------------------
# D25 (Director diagram, 2026-07-31) — DENTED voxels are HALF VOXELS, not a
# mark stamped on an intact face. "O voxel fica com metade em alpha e
# acrescenta uma face pre-baked pra cada material."
#
# Four variants, named by WHICH SIDE THE BLAST ATE (the physical property),
# which maps onto the diagram's role names in the ordinary case:
#   _dented_bottom — blast from BELOW  → ceiling voxel: keep the top, carve the
#                    underside with a jagged edge. "Para os voxels do teto é só
#                    esconder a metade de baixo do voxel" — so this variant is
#                    the ONLY one with no broken-face texture at all: an
#                    isometric camera never sees a ceiling's underside.
#   _dented_top    — blast from ABOVE  → floor voxel: the whole top sinks, the
#                    new upper surface is the broken face (a depression).
#   _dented_left   — blast from the SW (screen-left): the SW half is cut away
#                    along a plane parallel to the SE face, exposing the broken
#                    face; the SE half-top and the full SE face survive.
#   _dented_right  — the horizontal mirror of _dented_left ("flip horizontal"),
#                    for a blast arriving from the SE (screen-right).
#
# The broken face is DELIBERATELY a separate, swappable asset rather than a
# tinted copy of the material: *"a face quebrada não precisa ser igual ao
# restante do material, por isso essas faces vão servir pra muitas variações.
# Paredes de concreto com várias cores diferentes não vão ter o mesmo voxel
# quebrado por dentro."* So one generic grey fracture serves every material
# until real art lands, and a per-material override is a pure file drop —
# see BROKEN_FACE_TEMPLATE below.
# ---------------------------------------------------------------------------
DENTED_CUT_DEPTH = SIDE_H // 2      # how far the sunken/carved plane travels

# Top-face diamond, and the two side faces the isometric atom actually shows.
_TOP_DIAMOND = [V_N, V_E, V_S, V_W]
_LEFT_FACE   = [V_W, V_S, V_SB, V_WB]    # SW-facing
_RIGHT_FACE  = [V_S, V_E, V_EB, V_SB]    # SE-facing

# The vertical cut plane runs PARALLEL TO THE SW FACE (the one that faced the
# blast) through the voxel centre, so the whole SW face goes and the SE face is
# only halved — exactly the diagram's "ALPHA LEFT FACE" + "HALF RIGHT FACE" +
# "HALF TOP FACE". Cutting parallel to the SE face instead would preserve the
# SE face whole and halve the SW one, i.e. the mirror of what the blast
# physically does; that was the first attempt here and it read wrong.
# The plane meets the top diamond at the midpoints of the N–W and E–S edges.
_CUT_NW_MID = ((V_N[0] + V_W[0]) // 2, (V_N[1] + V_W[1]) // 2)   # (8, 4)
_CUT_ES_MID = ((V_E[0] + V_S[0]) // 2, (V_E[1] + V_S[1]) // 2)   # (24, 12)

# Everything on the far (NE) side of that cut survives.
_KEPT_TOP_HALF = [_CUT_NW_MID, V_N, V_E, _CUT_ES_MID]
# ...the cut itself, extruded straight down the full cube height, is the newly
# exposed interior surface the broken face gets painted onto...
_CUT_PLANE = [
    _CUT_NW_MID,
    _CUT_ES_MID,
    (_CUT_ES_MID[0], _CUT_ES_MID[1] + SIDE_H),
    (_CUT_NW_MID[0], _CUT_NW_MID[1] + SIDE_H),
]
# ...and only the NE half of the SE face is left standing beside it.
_KEPT_RIGHT_FACE = [
    _CUT_ES_MID,
    V_E,
    V_EB,
    (_CUT_ES_MID[0], _CUT_ES_MID[1] + SIDE_H),
]

BROKEN_FACE_TEMPLATE = "broken_face_%s.png"   # %s = material, or "generic"


def _hash01(x: int, y: int, salt: int = 0) -> float:
    """
    Deterministic per-pixel value in [0, 1). FNV-1a over the coordinate triple,
    matching the project's B4 hash discipline — same inputs, same texture,
    forever. Never `random`: a regenerated asset must be byte-identical.
    """
    h = 2166136261
    for component in (x, y, salt):
        for byte in component.to_bytes(4, "little", signed=True):
            h ^= byte
            h = (h * 16777619) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


def generate_broken_face(tint: tuple[int, int, int] = (150, 145, 138)) -> Image.Image:
    """
    The generic pre-baked "inside of a broken voxel" surface — rough, granular,
    fissured, deliberately NOT the parent material's colour (see the block
    comment above). Full 32×36 rect; callers mask it to whichever polygon the
    variant exposes.

    Placeholder art by construction: the Director supplies the real
    per-material bakes later, dropped in at BROKEN_FACE_TEMPLATE's filenames
    with zero code changes.
    """
    img = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))
    px = img.load()
    for y in range(TOTAL_H):
        for x in range(TILE_W):
            # Coarse blotches (chipped aggregate) over fine per-pixel grain.
            blotch = _hash01(x // 3, y // 3, 11)
            grain = _hash01(x, y, 29)
            shade = 0.62 + 0.30 * blotch + 0.16 * grain
            px[x, y] = (
                min(255, int(tint[0] * shade)),
                min(255, int(tint[1] * shade)),
                min(255, int(tint[2] * shade)),
                255,
            )

    # A few dark fissures so the surface reads as fractured, not just noisy.
    draw = ImageDraw.Draw(img)
    for i in range(4):
        sx = int(_hash01(i, 0, 71) * TILE_W)
        sy = int(_hash01(i, 1, 73) * TOTAL_H)
        ex = int(_hash01(i, 2, 79) * TILE_W)
        ey = int(_hash01(i, 3, 83) * TOTAL_H)
        draw.line([(sx, sy), (ex, ey)], fill=(52, 48, 45, 255), width=1)
    return img


def _polygon_mask(polygon: list[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", (TILE_W, TOTAL_H), 0)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    return mask


def _jagged_profile(y_at_x: list[int], amplitude: int, salt: int) -> list[int]:
    """Per-column cut height with a deterministic saw, so a carved edge reads
    as broken rather than sliced."""
    return [
        y_at_x[x] + int(_hash01(x // 2, 0, salt) * (amplitude + 1)) - amplitude // 2
        for x in range(TILE_W)
    ]


def generate_dented_voxel(base_img: "Image.Image", broken_img: "Image.Image",
                          variant: str) -> "Image.Image":
    """
    One carved half-voxel. `variant` is the side the blast ate:
    "bottom" | "top" | "left" | "right".
    """
    if variant == "right":
        # "flip horizontal" (Director's own label) — the mirror is exact, so
        # the two wall variants can never drift apart.
        return generate_dented_voxel(base_img, broken_img, "left").transpose(
            Image.FLIP_LEFT_RIGHT)

    img = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))

    if variant == "left":
        # The exposed cut plane and the surviving half of the SE face don't
        # overlap in screen space (the cut lands exactly on the E–S midpoint),
        # so no painter's-order question arises between them.
        img.paste(broken_img, (0, 0), _polygon_mask(_CUT_PLANE))
        img.paste(base_img, (0, 0), _polygon_mask(_KEPT_RIGHT_FACE))
        img.paste(base_img, (0, 0), _polygon_mask(_KEPT_TOP_HALF))
        return img

    if variant == "top":
        # The top surface sinks by DENTED_CUT_DEPTH; what's left of the side
        # faces is only the band below the new surface, and the new surface
        # itself is broken material.
        d = DENTED_CUT_DEPTH
        sunk_top = [(x, y + d) for (x, y) in _TOP_DIAMOND]
        sunk_w, sunk_s, sunk_e = (V_W[0], V_W[1] + d), (V_S[0], V_S[1] + d), (V_E[0], V_E[1] + d)
        img.paste(base_img, (0, 0), _polygon_mask([sunk_w, sunk_s, V_SB, V_WB]))
        img.paste(base_img, (0, 0), _polygon_mask([sunk_s, sunk_e, V_EB, V_SB]))
        img.paste(broken_img, (0, 0), _polygon_mask(sunk_top))
        return img

    if variant == "bottom":
        # Ceiling: keep the top, bite the underside off along a jagged line.
        # No broken face — the camera never sees a ceiling's underside.
        img.paste(base_img, (0, 0))
        d = DENTED_CUT_DEPTH
        # Bottom silhouette WB → SB → EB, raised by d, then roughened.
        base_profile: list[int] = []
        for x in range(TILE_W):
            if x <= V_SB[0]:
                y = V_WB[1] + (V_SB[1] - V_WB[1]) * x // max(1, V_SB[0])
            else:
                y = V_SB[1] + (V_EB[1] - V_SB[1]) * (x - V_SB[0]) // max(1, TILE_W - V_SB[0])
            base_profile.append(y - d)
        profile = _jagged_profile(base_profile, amplitude=4, salt=97)
        px = img.load()
        for x in range(TILE_W):
            for y in range(max(0, profile[x]), TOTAL_H):
                px[x, y] = (0, 0, 0, 0)
        return img

    raise ValueError(f"unknown dented variant: {variant!r}")


DENTED_VARIANTS: list[str] = ["top", "bottom", "left", "right"]


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
      y=[16..35] faces laterais — SW 70% (escura) + SE 88% (clara)
    
    Geometria (Painter's algorithm):
      Topo:      N, E, S, W (diamante)
      Esquerda:  W, S, SB, WB (face esquerda mais escura)
      Direita:   S, E, EB, SB (face direita mais clara)
    """
    img  = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Cores — três tons distintos, nunca dois (FACE-READ-01)
    c_top    = _rgba(base_color)                        # topo: cor base
    c_left   = _darken(base_color, SIDE_DARKEN_LEFT)    # SW: mais escura
    c_right  = _darken(base_color, SIDE_DARKEN_RIGHT)   # SE: mais clara

    # Painter's order (back to front): esquerda → direita → topo
    # Esquerda (SW face)
    draw.polygon([V_W, V_S, V_SB, V_WB], fill=c_left)

    # Direita (SE face)
    draw.polygon([V_S, V_E, V_EB, V_SB], fill=c_right)
    
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

    # D32 — blast-mark placeholders (dented/cracked), same materials, own
    # texture family (chip/crack, never a round puncture).
    blast_count = 0
    for material in IMPACT_MATERIALS:
        base_img = generate_voxel_atom(MATERIALS[material])
        for suffix, dented in (("dented", True), ("cracked", False)):
            img  = generate_blast_mark(base_img, dented)
            path = IMPACT_OUTPUT_DIR / f"voxel_{material}_blast_{suffix}.png"
            img.save(path, "PNG")
            print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")
            blast_count += 1
    print(f"\n✓ {blast_count} blast-mark placeholder(s) → {IMPACT_OUTPUT_DIR}/")

    # D25 — DENTED half-voxels with a pre-baked broken face, 4 carved sides per
    # material. The generic broken face is written out as its own asset (not
    # only baked into the composites) so the Director can see exactly what the
    # real per-material art has to replace.
    generic_broken = generate_broken_face()
    generic_path = IMPACT_OUTPUT_DIR / (BROKEN_FACE_TEMPLATE % "generic")
    generic_broken.save(generic_path, "PNG")
    print(f"  ✓ {generic_path}  (generic broken-face fallback)")

    dented_count = 0
    for material in IMPACT_MATERIALS:
        base_img = generate_voxel_atom(MATERIALS[material])
        # Per-material override if the Director has dropped real art in;
        # otherwise every material shares the generic fracture, which is the
        # whole point of decoupling it from the material colour.
        override = IMPACT_OUTPUT_DIR / (BROKEN_FACE_TEMPLATE % material)
        broken_img = Image.open(override).convert("RGBA") if override.exists() else generic_broken
        for variant in DENTED_VARIANTS:
            img = generate_dented_voxel(base_img, broken_img, variant)
            path = IMPACT_OUTPUT_DIR / f"voxel_{material}_blast_dented_{variant}.png"
            img.save(path, "PNG")
            print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")
            dented_count += 1
    print(f"\n✓ {dented_count} dented half-voxel(s) → {IMPACT_OUTPUT_DIR}/")
    print("Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes voxel")


if __name__ == "__main__":
    main()
