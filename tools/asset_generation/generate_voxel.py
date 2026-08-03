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
Face lateral (y=16..35): retângulo 32×20, darken 80% (a diferenciação
    SW/SE é aplicada em runtime por voxel_face_shading.gdshader)

Flat-lit: sem shading direcional baked — BakeSystem aplica textura em load-time.
Sem outline: voxels do mesmo material fundem numa superfície de parede contínua.
"""

from __future__ import annotations
import json
import math
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
# NEVER share a value. Differentiating them HERE was tried first and measured to
# reach only 0.25% of a real capture — the atom art feeds exclusively the voxels
# that bypass the baked lookup, while every photographically baked wall takes
# its pixels from a facade page. So the differentiation moved to
# godot/shaders/voxel_face_shading.gdshader, which covers both paths, and this
# stays a SINGLE flat side tone on purpose: the shader darkens the SW face
# relative to it, and two sources of face shading would compound into a
# double-darkened voxel.
SIDE_DARKEN: float = 0.80   # ambas as laterais; a diferenciação SW/SE é do shader

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


# ===========================================================================
# DECAL PIPELINE (Director diagrams, 2026-08-02) — "meio voxel + decal por cima"
# ===========================================================================
#
# The Director authors FLAT, UNPROJECTED, SQUARE decals; this file projects them
# onto the faces of a voxel (or of a half voxel) and writes the composites.
#
# SQUARE IS CANON, not a preference. ASSETS/ART_SPECIFICATIONS.md §1 pins the
# authoring density at TEX_AUTHORING_N = 16 flat texels per voxel and states the
# rule outright: "never pre-stretch to compensate for projection — the
# compositor owns all projection math." A voxel's wall face is therefore a
# 16 x 16 SQUARE patch of flat art, and the shipped bake_compositor.gd applies
# exactly the two operations this file applies (_get_plane_source: "facade
# scaled x20/16 vertically", then a +-x/2 shear). Authoring at 16 x 20 would
# bake the projection into the art — the one thing §1 forbids — and would also
# hand the Director a pre-squashed circle to draw, which is precisely what he
# asked not to have to do.
#
# One square decal therefore serves both destinations correctly:
#
#   lateral face / cut plane : mapped onto 16 x 20  -> gains the canon x20/16
#   top diamond              : mapped onto 16 x 16  -> 1:1, no stretch at all
#
# That asymmetry is real geometry, not a compromise: a top face IS square in
# flat space, which is why roof planes are laid "flat 1:1, NO x20/16" in the
# compositor too.
#
# RESOLUTION, as opposed to aspect, is an open question flagged to the Director:
# canon density puts one decal at 16 x 16 texels, which is below the mark's own
# ~16 x 28 px screen footprint. DECAL_AUTHOR_SIZE is an exact integer multiple
# of the pinned density, so it can be collapsed back to 16 x 16 at any time
# without disturbing any alignment the density rule exists to protect.
#
# Three variants per family, fixed (Director, 2026-08-02). Selection at runtime
# is a hash of the voxel's BASE coordinates, so a mark keeps its variant across
# rotation and repaint without persisting anything new.
# ---------------------------------------------------------------------------

TEX_AUTHORING_N = 16         # mirrors GeometryCoords.TEX_AUTHORING_N (pinned)
DECAL_AUTHOR_MULTIPLE = 16   # authoring canvas = this x the canon density
DECAL_AUTHOR_SIZE = TEX_AUTHORING_N * DECAL_AUTHOR_MULTIPLE   # 256, square
DECAL_AUTHOR_W = DECAL_AUTHOR_SIZE
DECAL_AUTHOR_H = DECAL_AUTHOR_SIZE

DECAL_DIR = IMPACT_OUTPUT_DIR / "decals"
DECAL_TEMPLATE_NAME = f"TEMPLATE_decal_{DECAL_AUTHOR_W}x{DECAL_AUTHOR_H}.png"
DECAL_NAME = "decal_%s_%s_%d.png"           # family, material, variant
DECAL_FAMILIES: tuple[str, ...] = ("bullet", "dent", "crack")
DECAL_VARIANT_COUNT = 3

HALF_NAME = "voxel_%s_half_%s.png"          # material, side
HALF_SIDES: tuple[str, ...] = ("left", "right", "top", "bottom")

MANIFEST_NAME = "manifest.json"

# Decal targets as (origin, u_end, v_end, native): u runs along the face's own
# horizontal edge, v straight down it, and `native` is that face's size in FLAT
# texels at canon density. Verified corner-by-corner against the atom geometry
# above — e.g. SE reaches V_EB at (u,v) = (1,1).
#
# `native` is what turns one SQUARE authored decal into the right thing on each
# surface: (16, 20) on a lateral face applies the compositor's canon x20/16
# vertical stretch, (16, 16) on a top face applies none. It is also the exact
# sampling resolution _paste_decal() reduces the source to before supersampling.
_LATERAL_NATIVE = (TEX_AUTHORING_N, TEX_AUTHORING_N * SIDE_H // TILE_H)   # (16, 20)
_TOP_NATIVE = (TEX_AUTHORING_N, TEX_AUTHORING_N)                          # (16, 16)

_FACE_SE = (V_S, V_E, V_SB, _LATERAL_NATIVE)
_FACE_SW = (V_W, V_S, V_WB, _LATERAL_NATIVE)
# The top diamond is the image of a UNIT SQUARE under (u along N->E, v along
# N->W): N + u*(E-N) + v*(W-N) lands on S at (1,1). So one paste covers it with
# no rotation step and no separate "diamond" code path.
_FACE_TOP = (V_N, V_E, V_W, _TOP_NATIVE)
# The exposed cut plane of a LEFT-carved half voxel (the SW half is gone). It is
# a vertical face parallel to the SW one, so it takes the lateral native size.
_FACE_CUT_LEFT = (
    _CUT_NW_MID,
    _CUT_ES_MID,
    (_CUT_NW_MID[0], _CUT_NW_MID[1] + SIDE_H),
    _LATERAL_NATIVE,
)
# The sunken top surface of a TOP-carved (floor) half voxel — horizontal, so it
# takes the top native size and no vertical stretch.
_FACE_SUNK_TOP = (
    (V_N[0], V_N[1] + DENTED_CUT_DEPTH),
    (V_E[0], V_E[1] + DENTED_CUT_DEPTH),
    (V_W[0], V_W[1] + DENTED_CUT_DEPTH),
    _TOP_NATIVE,
)

## Samples per axis, per destination pixel. The target is only ~16x28 px, so at
## one sample the sheared edge aliases into a staircase and the mark reads as
## jagged rather than soft. The decal is pre-resized to exactly
## _DECAL_SUPERSAMPLE x the native face first, which makes the 4x4 grid an
## exact box filter over the source footprint instead of an undersample of it.
_DECAL_SUPERSAMPLE = 4


def _paste_decal(dst: "Image.Image", decal: "Image.Image",
                 target: tuple) -> None:
    """
    Alpha-composite `decal` onto `dst`, mapping the decal's whole rectangular
    canvas onto the parallelogram `target` = (origin, u_end, v_end).

    INVERSE-mapped: every DESTINATION pixel asks which source texel it came
    from. A forward scatter would leave holes at an oblique shear; this cannot.
    The 0 <= s,t < 1 test is also the clip, so the decal can never bleed past
    the face polygon and no separate mask is needed.
    """
    origin, u_end, v_end, native = target
    ux = float(u_end[0] - origin[0])
    uy = float(u_end[1] - origin[1])
    vx = float(v_end[0] - origin[0])
    vy = float(v_end[1] - origin[1])
    det = ux * vy - uy * vx
    if det == 0.0:
        raise ValueError("degenerate decal parallelogram: %r" % (target,))

    # Reduce to exactly the face's native texel grid x the supersample factor.
    # A SQUARE source landing on a (16, 20) face is where the compositor's canon
    # x20/16 vertical stretch is applied — here, once, never in the art.
    work = decal.resize(
        (native[0] * _DECAL_SUPERSAMPLE, native[1] * _DECAL_SUPERSAMPLE),
        Image.LANCZOS,
    )
    src = work.load()
    src_w, src_h = work.size
    out = dst.load()

    corners_x = [origin[0], u_end[0], v_end[0], origin[0] + ux + vx]
    corners_y = [origin[1], u_end[1], v_end[1], origin[1] + uy + vy]
    x0 = max(0, int(min(corners_x)) - 1)
    x1 = min(dst.size[0], int(max(corners_x)) + 2)
    y0 = max(0, int(min(corners_y)) - 1)
    y1 = min(dst.size[1], int(max(corners_y)) + 2)

    step = 1.0 / _DECAL_SUPERSAMPLE
    sample_weight = 1.0 / float(_DECAL_SUPERSAMPLE * _DECAL_SUPERSAMPLE)

    for py in range(y0, y1):
        for px_x in range(x0, x1):
            acc_r = acc_g = acc_b = acc_a = 0.0
            for sy in range(_DECAL_SUPERSAMPLE):
                for sx in range(_DECAL_SUPERSAMPLE):
                    dx = px_x + (sx + 0.5) * step - origin[0]
                    dy = py + (sy + 0.5) * step - origin[1]
                    s = (dx * vy - dy * vx) / det
                    t = (ux * dy - uy * dx) / det
                    if not (0.0 <= s < 1.0 and 0.0 <= t < 1.0):
                        continue
                    r, g, b, a = src[
                        min(src_w - 1, int(s * src_w)),
                        min(src_h - 1, int(t * src_h)),
                    ]
                    alpha = a / 255.0
                    acc_r += r * alpha
                    acc_g += g * alpha
                    acc_b += b * alpha
                    acc_a += alpha
            if acc_a <= 0.0:
                continue
            # Averaged premultiplied -> straight alpha, then source-over.
            s_r, s_g, s_b = acc_r / acc_a, acc_g / acc_a, acc_b / acc_a
            s_a = acc_a * sample_weight
            b_r, b_g, b_b, b_a8 = out[px_x, py]
            b_a = b_a8 / 255.0
            n_a = s_a + b_a * (1.0 - s_a)
            if n_a <= 0.0:
                continue
            inv = b_a * (1.0 - s_a)
            out[px_x, py] = (
                int(round((s_r * s_a + b_r * inv) / n_a)),
                int(round((s_g * s_a + b_g * inv) / n_a)),
                int(round((s_b * s_a + b_b * inv) / n_a)),
                int(round(n_a * 255.0)),
            )


def generate_decal_template() -> Image.Image:
    """
    The blank Photoshop gabarito: exact authoring canvas, fully transparent,
    with a 1 px magenta frame so the paintable bounds are visible. The frame is
    NOT part of any shipped decal — this file is a template only, never read by
    the compositor.
    """
    img = Image.new("RGBA", (DECAL_AUTHOR_W, DECAL_AUTHOR_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle(
        [0, 0, DECAL_AUTHOR_W - 1, DECAL_AUTHOR_H - 1],
        outline=(255, 0, 255, 160),
    )
    cx, cy = DECAL_AUTHOR_W // 2, DECAL_AUTHOR_H // 2
    draw.line([(cx, 0), (cx, DECAL_AUTHOR_H)], fill=(255, 0, 255, 60))
    draw.line([(0, cy), (DECAL_AUTHOR_W, cy)], fill=(255, 0, 255, 60))
    return img


def generate_decal_placeholder(family: str, variant: int) -> Image.Image:
    """
    Stand-in art at the real authoring size, one per (family, variant). Each
    family is drawn to be unmistakable at a glance IN THE COMPOSITES, which is
    what makes them useful: a wrong shear, a mirrored face or a decal on the
    wrong surface is visible immediately instead of hiding inside plausible
    noise.

    bullet — round core, soft rim (the shape the Director's own metal sample has)
    dent   — irregular chipped polygon, off-centre
    crack  — branching fracture lines radiating from a rough centre

    Deterministic (FNV-1a via _hash01, never `random`), and NEVER overwritten
    once the Director drops real art at the same filename.
    """
    img = Image.new("RGBA", (DECAL_AUTHOR_W, DECAL_AUTHOR_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = DECAL_AUTHOR_W / 2.0, DECAL_AUTHOR_H / 2.0
    salt = 1000 + variant

    if family == "bullet":
        # Soft rim first (concentric rings, fading out), then the dark core.
        outer = DECAL_AUTHOR_W * (0.40 + 0.05 * _hash01(variant, 0, salt))
        core = outer * 0.42
        rings = 18
        for i in range(rings, 0, -1):
            r = core + (outer - core) * (i / float(rings))
            a = int(200 * (1.0 - i / float(rings)) ** 1.6)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(58, 52, 48, a))
        draw.ellipse([cx - core, cy - core, cx + core, cy + core],
                     fill=(16, 14, 13, 255))

    elif family == "dent":
        # Irregular chip: a radially perturbed polygon, pushed off-centre so it
        # never reads as a bullet's concentric hole.
        ox = cx + DECAL_AUTHOR_W * 0.06 * (_hash01(variant, 1, salt) - 0.5)
        oy = cy + DECAL_AUTHOR_H * 0.06 * (_hash01(variant, 2, salt) - 0.5)
        pts = []
        steps = 13
        for i in range(steps):
            ang = 2.0 * math.pi * i / steps
            rad = DECAL_AUTHOR_W * (0.30 + 0.16 * _hash01(i, variant, salt))
            pts.append((ox + rad * math.cos(ang), oy + rad * math.sin(ang) * 1.25))
        draw.polygon(pts, fill=(46, 41, 37, 235))
        inner = [(ox + (x - ox) * 0.52, oy + (y - oy) * 0.52) for (x, y) in pts]
        draw.polygon(inner, fill=(18, 16, 14, 255))

    elif family == "crack":
        # Branching fracture. Every voxel that carries this is CRACKED, which
        # the Director defined as "quase virou dented, mas ainda está se
        # segurando" — so the lines reach the canvas edges rather than sitting
        # as an isolated blot in the middle of an otherwise pristine face.
        trunks = 6
        for i in range(trunks):
            ang = 2.0 * math.pi * (i + 0.35 * _hash01(i, variant, salt)) / trunks
            length = DECAL_AUTHOR_W * (0.42 + 0.22 * _hash01(i, variant + 7, salt))
            ex = cx + length * math.cos(ang)
            ey = cy + length * math.sin(ang) * 1.25
            draw.line([(cx, cy), (ex, ey)], fill=(38, 34, 31, 240), width=7)
            # one branch off each trunk, two thirds of the way out
            bx = cx + (ex - cx) * 0.66
            by = cy + (ey - cy) * 0.66
            bang = ang + (0.7 if _hash01(i, variant + 13, salt) > 0.5 else -0.7)
            blen = length * 0.45
            draw.line(
                [(bx, by), (bx + blen * math.cos(bang), by + blen * math.sin(bang) * 1.25)],
                fill=(38, 34, 31, 210), width=4)
    else:
        raise ValueError(f"unknown decal family: {family!r}")

    return img


def _mirror_point(p: tuple[int, int]) -> tuple[int, int]:
    """
    Mirror a GEOMETRY point across the voxel's vertical axis.

    Uses TILE_W - x, not (TILE_W - 1) - x, because these are polygon vertices in
    a 0..TILE_W coordinate space (V_E sits at x == 32), not pixel indices. This
    is exactly where Image.FLIP_LEFT_RIGHT goes wrong for this atom: the pixel
    flip maps x -> 31 - x, which shifts the whole silhouette one pixel and makes
    a mirrored FLAT voxel seam against its unmirrored neighbours in a continuous
    wall. Measured: 30 alpha pixels differ between voxel_concrete.png and its
    own pixel-mirror. Mirroring the polygons instead keeps every composite on
    the one canonical silhouette.
    """
    return (TILE_W - p[0], p[1])


def _mirror_poly(poly: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return [_mirror_point(p) for p in poly]


def _mirror_target(target: tuple) -> tuple:
    """
    Mirror a decal target. Order is preserved, so `u` ends up running right to
    left — which is what makes the pasted decal itself mirror, i.e. the
    Director's "flip horizontal" applied to the art rather than to the file.
    """
    return (_mirror_point(target[0]), _mirror_point(target[1]),
            _mirror_point(target[2]), target[3])


_FACE_SE_MIRRORED = _mirror_target(_FACE_SW)
_FACE_CUT_RIGHT = _mirror_target(_FACE_CUT_LEFT)


def generate_half_voxel(base_color: tuple[int, int, int], side: str) -> Image.Image:
    """
    One half voxel of a material, textureless — the Director's "meio voxel
    gerado a partir do voxel inteiro", and the shared substrate for BOTH the
    bullet and the blast dented tiers ("podem ser os mesmos das bullets
    inclusive").

    The newly exposed surface is filled with the material's OWN flat tone, not
    with broken_face_generic: under the 2026-08-02 model the fracture look comes
    from the decal pasted on top, per material, not from a shared grey texture.
    Side tone for the vertical cut plane, base tone for a floor's sunken top —
    the surface's orientation, exactly as the atom itself shades them.

    "bottom" (ceiling) is silhouette ONLY, confirmed by the Director: an
    isometric camera never sees a voxel's underside, so there is no exposed
    surface for a decal to land on. It is the one side delegated to
    generate_dented_voxel(), which builds it directly (no mirror step involved).
    """
    base_img = generate_voxel_atom(base_color)
    if side == "bottom":
        return generate_dented_voxel(base_img, base_img, "bottom")

    img = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))

    if side == "top":
        # Floor: the top surface sinks, leaving only a band of each side face
        # below it, and the sunken surface is where the decal will land.
        d = DENTED_CUT_DEPTH
        sunk = [(x, y + d) for (x, y) in _TOP_DIAMOND]
        sunk_w, sunk_s, sunk_e = sunk[3], sunk[2], sunk[1]
        img.paste(base_img, (0, 0), _polygon_mask([sunk_w, sunk_s, V_SB, V_WB]))
        img.paste(base_img, (0, 0), _polygon_mask([sunk_s, sunk_e, V_EB, V_SB]))
        fill = Image.new("RGBA", (TILE_W, TOTAL_H), _rgba(base_color))
        img.paste(fill, (0, 0), _polygon_mask(sunk))
        return img

    # Wall: cut parallel to the face that took the hit, keep the far half.
    # "right" is built from MIRRORED POLYGONS, never from a pixel flip — see
    # _mirror_point() for the measurement behind that.
    cut_plane, kept_face, kept_top = _CUT_PLANE, _KEPT_RIGHT_FACE, _KEPT_TOP_HALF
    if side == "right":
        cut_plane = _mirror_poly(_CUT_PLANE)
        kept_face = _mirror_poly(_KEPT_RIGHT_FACE)
        kept_top = _mirror_poly(_KEPT_TOP_HALF)
    elif side != "left":
        raise ValueError(f"unknown half voxel side: {side!r}")

    fill = Image.new("RGBA", (TILE_W, TOTAL_H), _darken(base_color, SIDE_DARKEN))
    img.paste(fill, (0, 0), _polygon_mask(cut_plane))
    img.paste(base_img, (0, 0), _polygon_mask(kept_face))
    img.paste(base_img, (0, 0), _polygon_mask(kept_top))
    return img


def compose_decal_voxel(substrate: "Image.Image", decal: "Image.Image",
                        targets: list[tuple]) -> Image.Image:
    """
    Paste one decal onto every listed face of a copy of `substrate`, then clamp
    the result to the substrate's own alpha.

    THE CLAMP IS INVARIANT B3, not tidiness: "silhouette alpha always comes from
    the canonical voxel texture; art never carries silhouettes." Without it a
    decal reaching its own canvas corners lands on the face's corner pixels,
    where 4x4 supersampling spreads partial coverage one pixel past the
    substrate — measured, not hypothesised: blast_dented_top grew its silhouette
    and leaked 2 px outside the sunken diamond before this existed. In a tilemap
    that reads as a halo sticking out of the voxel.

    A decal may therefore be clipped at a face's extreme corners. That is the
    correct trade: the silhouette is canon and the decal is not.
    """
    img = substrate.copy()
    for target in targets:
        _paste_decal(img, decal, target)

    sub_px = substrate.load()
    out_px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if sub_px[x, y][3] == 0 and out_px[x, y][3] != 0:
                out_px[x, y] = (0, 0, 0, 0)
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
      y=[16..35] faces laterais — tom único 80% (shader diferencia SW/SE)
    
    Geometria (Painter's algorithm):
      Topo:      N, E, S, W (diamante)
      Esquerda:  W, S, SB, WB (face esquerda mais escura)
      Direita:   S, E, EB, SB (face direita mais clara)
    """
    img  = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Cores — três tons distintos, nunca dois (FACE-READ-01)
    c_top   = _rgba(base_color)                  # topo: cor base
    c_side  = _darken(base_color, SIDE_DARKEN)   # laterais: tom único (ver acima)

    # Painter's order (back to front): esquerda → direita → topo
    # Esquerda (SW face)
    draw.polygon([V_W, V_S, V_SB, V_WB], fill=c_side)

    # Direita (SE face)
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

    # FLOOR-DENT-01 (2026-08-01) — the floor's own carved variant. Plain-earth
    # floors are the one ground type that dents today (MaterialResistanceTable's
    # "earth" row; zoned ground_* materials stay dent-free until they get their
    # own asset + table entry). A floor is only ever eaten from ABOVE, so earth
    # gets exactly the _top carve — the same reasoning that gives ceilings only
    # _bottom. Base colour is EARTH_VARIANTS[0]: the carved voxel reads as
    # generic earth (the broken face dominates the read), not as one specific
    # of the 8 floor variants.
    earth_base = generate_voxel_atom(EARTH_VARIANTS[0])
    earth_override = IMPACT_OUTPUT_DIR / (BROKEN_FACE_TEMPLATE % "earth")
    earth_broken = Image.open(earth_override).convert("RGBA") if earth_override.exists() else generic_broken
    img = generate_dented_voxel(earth_base, earth_broken, "top")
    path = IMPACT_OUTPUT_DIR / "voxel_earth_blast_dented_top.png"
    img.save(path, "PNG")
    print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")
    dented_count += 1
    print(f"\n✓ {dented_count} dented half-voxel(s) → {IMPACT_OUTPUT_DIR}/")

    build_decal_family()

    print("Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes voxel")


# ---------------------------------------------------------------------------
# Decal family driver (Director diagrams, 2026-08-02)
# ---------------------------------------------------------------------------

def build_decal_family() -> None:
    """
    Write the whole 2026-08-02 decal family: the Photoshop gabarito, the decal
    placeholders the Director will replace, the four half voxels per material,
    and every composite derived from them.

    AUTHORED FILES ARE NEVER OVERWRITTEN. Decals and half voxels are written
    only when absent — the diagram's own "IF NOT PRESENT IN THE FOLDER" — so
    re-running this after dropping real art rebuilds the composites around that
    art instead of clobbering it. Composites are pure derivatives and are always
    rewritten.
    """
    DECAL_DIR.mkdir(parents=True, exist_ok=True)

    template_path = DECAL_DIR / DECAL_TEMPLATE_NAME
    generate_decal_template().save(template_path, "PNG")
    print(f"\n  ✓ {template_path}  (blank gabarito {DECAL_AUTHOR_W}×{DECAL_AUTHOR_H})")

    kept_decals = 0
    written_decals = 0
    decals: dict[tuple[str, str, int], Image.Image] = {}
    for material in IMPACT_MATERIALS:
        for family in DECAL_FAMILIES:
            for variant in range(DECAL_VARIANT_COUNT):
                path = DECAL_DIR / (DECAL_NAME % (family, material, variant))
                if path.exists():
                    decals[(material, family, variant)] = Image.open(path).convert("RGBA")
                    kept_decals += 1
                    continue
                img = generate_decal_placeholder(family, variant)
                img.save(path, "PNG")
                decals[(material, family, variant)] = img
                written_decals += 1
    print(f"  ✓ {written_decals} decal placeholder(s) written, "
          f"{kept_decals} authored decal(s) kept → {DECAL_DIR}/")

    halves: dict[tuple[str, str], Image.Image] = {}
    kept_halves = 0
    written_halves = 0
    for material in IMPACT_MATERIALS:
        for side in HALF_SIDES:
            path = IMPACT_OUTPUT_DIR / (HALF_NAME % (material, side))
            if path.exists():
                halves[(material, side)] = Image.open(path).convert("RGBA")
                kept_halves += 1
                continue
            img = generate_half_voxel(MATERIALS[material], side)
            img.save(path, "PNG")
            halves[(material, side)] = img
            written_halves += 1
    print(f"  ✓ {written_halves} half voxel(s) written, "
          f"{kept_halves} authored half voxel(s) kept → {IMPACT_OUTPUT_DIR}/")

    composites = 0
    for material in IMPACT_MATERIALS:
        atom = generate_voxel_atom(MATERIALS[material])

        for variant in range(DECAL_VARIANT_COUNT):
            bullet = decals[(material, "bullet", variant)]
            dent = decals[(material, "dent", variant)]
            crack = decals[(material, "crack", variant)]

            # --- BULLET, CRACKED: full voxel, mark on the struck lateral face.
            # LEFT means the SW face took it (shooter to screen-left), matching
            # BlastCalculator.carved_side_for()'s own screen-space convention.
            composites += _save_pair(
                compose_decal_voxel(atom, bullet, [_FACE_SW]),
                compose_decal_voxel(atom, bullet, [_FACE_SE_MIRRORED]),
                material, "bullet_cracked", variant)

            # --- BULLET, DENTED: half voxel, same mark on the exposed cut plane
            # ("aplicar a perspectiva da bala um pouco mais pra dentro" — the cut
            # plane IS half a voxel deeper, so no extra offset is needed).
            composites += _save_pair(
                compose_decal_voxel(halves[(material, "left")], bullet, [_FACE_CUT_LEFT]),
                compose_decal_voxel(halves[(material, "right")], bullet, [_FACE_CUT_RIGHT]),
                material, "bullet_dented", variant)

            # --- BLAST, DENTED (wall): same substrate, blast's own decal.
            composites += _save_pair(
                compose_decal_voxel(halves[(material, "left")], dent, [_FACE_CUT_LEFT]),
                compose_decal_voxel(halves[(material, "right")], dent, [_FACE_CUT_RIGHT]),
                material, "blast_dented", variant)

            # --- BLAST, DENTED (floor): the sunken top surface takes the decal.
            floor = compose_decal_voxel(
                halves[(material, "top")], dent, [_FACE_SUNK_TOP])
            floor.save(IMPACT_OUTPUT_DIR /
                       f"voxel_{material}_blast_dented_top_{variant}.png", "PNG")
            composites += 1

            # --- BLAST, CRACKED: the FULL voxel, all three visible faces.
            # Director: "cracked aparece no voxel inteiro, nas 3 faces. Não
            # existe voxel rachado só em uma face" — a voxel that nearly became
            # DENTED and is barely holding together cannot read pristine on one
            # side and shattered on the other. Same variant on all three, so the
            # voxel reads as ONE event rather than three unrelated fractures.
            cracked = compose_decal_voxel(
                atom, crack, [_FACE_TOP, _FACE_SW, _FACE_SE])
            cracked.save(IMPACT_OUTPUT_DIR /
                         f"voxel_{material}_blast_cracked_all_{variant}.png", "PNG")
            composites += 1

        # --- BLAST, DENTED (ceiling): silhouette only, no variants. Confirmed by
        # the Director against the explosion diagram — an isometric camera never
        # sees a voxel's underside, so there is no exposed surface to decal and
        # nothing for a variant to vary.
        halves[(material, "bottom")].save(
            IMPACT_OUTPUT_DIR / f"voxel_{material}_blast_dented_bottom.png", "PNG")
        composites += 1

    print(f"  ✓ {composites} composite(s) → {IMPACT_OUTPUT_DIR}/")

    manifest = {
        "generated_by": "tools/asset_generation/generate_voxel.py",
        "decal_canvas": {
            "author_width": DECAL_AUTHOR_W,
            "author_height": DECAL_AUTHOR_H,
            "square": True,
            "canon_density_texels_per_voxel": TEX_AUTHORING_N,
            "lateral_native": list(_LATERAL_NATIVE),
            "top_native": list(_TOP_NATIVE),
        },
        "variant_count": DECAL_VARIANT_COUNT,
        "materials": list(IMPACT_MATERIALS),
        "families": list(DECAL_FAMILIES),
        "composites": {
            "bullet_cracked": {"sides": ["left", "right"], "variants": True},
            "bullet_dented": {"sides": ["left", "right"], "variants": True},
            "blast_dented": {"sides": ["left", "right", "top"], "variants": True},
            "blast_dented_bottom": {"sides": ["bottom"], "variants": False},
            "blast_cracked_all": {"sides": ["all"], "variants": True},
        },
    }
    manifest_path = IMPACT_OUTPUT_DIR / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"  ✓ {manifest_path}  (runtime variant discovery)")


def _save_pair(left: "Image.Image", right: "Image.Image", material: str,
               kind: str, variant: int) -> int:
    """Write a left/right composite pair; returns how many files were written."""
    left.save(IMPACT_OUTPUT_DIR /
              f"voxel_{material}_{kind}_left_{variant}.png", "PNG")
    right.save(IMPACT_OUTPUT_DIR /
               f"voxel_{material}_{kind}_right_{variant}.png", "PNG")
    return 2


if __name__ == "__main__":
    main()
