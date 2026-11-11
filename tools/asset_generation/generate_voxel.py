#!/usr/bin/env python3
"""
generate_voxel.py — the decal family's placeholder art (the only live output)
=============================================================================
Writes the decal INPUT art the 3D board's decal catalogue reads: the blank
authoring template, the per-material photographic decal placeholders the
Director replaces by hand, the generic vector marks and the generic
broken-face fallback, plus `ASSETS/materials/manifest.json`. Authored files
are never overwritten.

Run from the project root:
    python3 tools/asset_generation/generate_voxel.py

2026-11-11 (HERITAGE T1): the 32x36 voxel atoms, the half voxels and their
compositing helpers were the 2D board's and are gone; the decal output was
diffed identical before and after (44 files and the manifest).
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


# ---------------------------------------------------------------------------
# Paleta de materiais — (R, G, B) base, flat-lit
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# D22 — impact-mark pseudo-materials. Glass is excluded: it has no
# DENTED/CRACKED tier by design. Real per-material photographic decal art is
# the Director's own pass, dropped into DECAL_DIR (decals/) at the filenames
# DECAL_NAME/build_decal_family() expect — zero code changes on swap.
# ---------------------------------------------------------------------------
# ASSET-LAYOUT-01 (Director, 2026-08-02) — split by what the pipeline DOES with
# a file. materials/halves/decals are INPUTS the generator never overwrites.
# composites/ (a pure, always-rebuilt derivative) is gone as of D33 Part 4c
# (2026-08-03) — every shape it used to hold composites LIVE at runtime
# instead. See the tree's README.md.
## ASSET_TREE_REFORM (2026-08-21): outputs go to one folder per material.
## These stay as names rather than paths because the destination now depends on
## WHICH material is being written — see material_dir()/half_dir() below.
MATERIALS_ROOT = Path("ASSETS/materials")


IMPACT_MATERIALS: list[str] = ["concrete", "metal", "stone", "wood"]


## D33 Part 4c (2026-08-03): generate_impact_mark() (D22) and generate_blast_mark()
## (D23) — the original placeholder top-face marks (ellipse/polygon, drawn
## directly onto a full voxel atom) — retired along with the composites/ files
## they only ever fed. Their material-agnostic, projection-correct
## replacements are generate_generic_bullet_decal()/generate_generic_blast_dent_decal()/
## etc. below (D33 Part 4a), which the Director specifically asked to REPLACE
## these with rather than reuse ("texturas genéricas (vetor)... tentando ser
## um pouco mais caprichado").

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

## ASSET_TREE_REFORM: the GENERIC family is material-agnostic (D25) and lives
## under `_generic/`. Per-material decals are authored by hand, never generated
## here, so this is the only decal directory the generator writes to.
DECAL_DIR = MATERIALS_ROOT / "_generic" / "decals"
DECAL_TEMPLATE_NAME = f"TEMPLATE_decal_{DECAL_AUTHOR_W}x{DECAL_AUTHOR_H}.png"
DECAL_NAME = "decal_%s_%s_%d.png"           # family, material, variant
DECAL_FAMILIES: tuple[str, ...] = ("bullet", "dent", "crack")
# D32.6 (Director, 2026-08-02): "metal e madeira não ficam rachados, só dented
# ou balas." Only these fracture, so only these get crack decals and composites
# — keeping the others would put art in the Director's queue for a state the
# runtime can no longer reach (MaterialResistanceTable crack_factor 0.0 for
# metal and wood). Mirrors VoxelBoard.IMPACT_CRACK_MATERIALS; the two are
# asserted equal by voxel_decal_selftest.
CRACK_MATERIALS: tuple[str, ...] = ("concrete", "stone")
DECAL_VARIANT_COUNT = 3


MANIFEST_NAME = "manifest.json"
MANIFEST_DIR = MATERIALS_ROOT

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
        # An explosion NEVER produces a bullet hole (D23, restated by the
        # Director 2026-08-02: "explosão não gera buracos de balas, somente
        # dented e cracked"). The runtime already guarantees the texture FAMILY
        # — every blast write passes from_blast=true — but at 16x20 px on screen
        # a gently perturbed polygon still READS as a round hole, which is what
        # the Director saw in the first live capture. So the shape is made
        # structurally angular rather than nearly-round:
        #   - few vertices (7), so straight facets are visible at 16 px;
        #   - large radial swing (0.20..0.46 of the canvas) instead of a small
        #     wobble around one radius;
        #   - the core is a SEPARATE angular polygon, rotated against the rim,
        #     so the silhouette and the hole never share a centre or an outline.
        # Nothing here is randomised — same deterministic _hash01 contract.
        ox = cx + DECAL_AUTHOR_W * 0.10 * (_hash01(variant, 1, salt) - 0.5)
        oy = cy + DECAL_AUTHOR_H * 0.10 * (_hash01(variant, 2, salt) - 0.5)
        steps = 7
        base_ang = 2.0 * math.pi * _hash01(variant, 3, salt) / steps
        pts = []
        for i in range(steps):
            ang = base_ang + 2.0 * math.pi * i / steps
            rad = DECAL_AUTHOR_W * (0.20 + 0.26 * _hash01(i, variant, salt))
            pts.append((ox + rad * math.cos(ang), oy + rad * math.sin(ang) * 1.25))
        draw.polygon(pts, fill=(46, 41, 37, 235))
        core = []
        for i in range(5):
            ang = base_ang + 0.4 + 2.0 * math.pi * i / 5
            rad = DECAL_AUTHOR_W * (0.09 + 0.13 * _hash01(i, variant + 3, salt))
            core.append((ox + rad * math.cos(ang), oy + rad * math.sin(ang) * 1.25))
        draw.polygon(core, fill=(18, 16, 14, 255))

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


# ---------------------------------------------------------------------------
# D33 Part 4 — generic/vector mark decals (Director, 2026-08-03)
# ---------------------------------------------------------------------------
# "No caso do fallback estar ativo, não queremos texturas sendo aplicadas em
# voxels genéricos. Queremos texturas genéricas (vetor)... substitutos
# virtuais para cada textura." A generic (flat, unbaked) voxel must never
# wear the photographic decal art above — these six mark "kinds" are its
# material-agnostic vector substitute instead. Authored FLAT on the same
# 256x256 canvas as every other decal (never in final atom/diamond space —
# that was v1's mistake: a shape drawn straight into the projected image
# ignores the real isometric shear entirely, which is why circles read as
# "too round"). The SAME real _paste_decal()/compose_decal_voxel() the
# photographic decals use projects these too, so whatever geometric
# treatment is correct for those is automatically correct here.
#
# Material-independent by design — the 0.7 ink alpha (GENERIC_MARK_INK_ALPHA)
# is what lets each material's own colour read through, instead of needing
# per-material art.
#
# No "cut" variant at the DECAL level: an early version tried encoding a true
# alpha=0 hole into the decal PNG itself for the full-voxel
# fallback-of-fallback DENTED case (no carved side, no other geometry
# conveys "material is gone"). Measured wrong — _paste_decal()/
# compose_decal_voxel() blend "source over" (Porter-Duff), where a decal
# pixel's alpha only ever ADDS coverage; alpha=0 in the decal means "this
# decal contributes nothing here", which leaves whatever the OPAQUE flat
# substrate already shows completely unchanged, never punches a hole through
# it. Confirmed by generic_mark_seam_selftest.gd sampling the real composited
# pixel: alpha stayed 1.0 with the old cut=True path. The real D32
# photographic "dent" family never attempted this — it only ever draws fully
# opaque ink onto substrates that are ALREADY carved (real geometry, real
# transparency) — so this was a novel mistake, not a repeated one. Fixed:
# the decals are solid ink only, everywhere; punch_generic_alpha_hole() below
# is the ACTUAL cut, applied to the COMPOSITE at runtime (only place a
# substrate's own alpha can honestly be reduced), invoked only for the
# fallback-of-fallback DENTED case.
GENERIC_MARK_INK_ALPHA = 178   # 0.7 * 255 (Director, 2026-08-03)
GENERIC_MARK_KINDS: tuple[str, ...] = (
    "bullet_dented", "bullet_cracked", "blast_dent", "blast_crack",
)
GENERIC_MARK_NAME = "decal_generic_%s_%d.png"   # kind, variant
GENERIC_MARK_VARIANTS = 3


def _generic_mark_canvas() -> Image.Image:
    return Image.new("RGBA", (DECAL_AUTHOR_W, DECAL_AUTHOR_H), (0, 0, 0, 0))


def generate_generic_bullet_decal(variant: int) -> Image.Image:
    """"Dented" bullet look: a crater rim plus a few short radial
    stress-cracks, hash-jittered per variant. Solid ink — see the
    module-level "cut" note above for why there is no cut here."""
    img = _generic_mark_canvas()
    draw = ImageDraw.Draw(img)
    cx, cy = DECAL_AUTHOR_W / 2.0, DECAL_AUTHOR_H / 2.0
    seed = variant * 97 + 13

    outer = DECAL_AUTHOR_W * (0.20 + 0.02 * _hash01(seed, 3, 203))
    rim_shade = 0.55 + 0.25 * _hash01(seed, 3, 203)
    draw.ellipse(
        [cx - outer, cy - outer, cx + outer, cy + outer],
        fill=(int(90 * rim_shade), int(85 * rim_shade), int(78 * rim_shade), GENERIC_MARK_INK_ALPHA),
    )
    for i in range(3):
        angle = (2.0 * math.pi / 3) * i + (_hash01(seed, i, 210) - 0.5) * 0.9
        length = outer + DECAL_AUTHOR_W * (0.05 + 0.05 * _hash01(seed, i, 220))
        ex, ey = cx + math.cos(angle) * length, cy + math.sin(angle) * length
        draw.line([(cx, cy), (ex, ey)], fill=(60, 55, 50, GENERIC_MARK_INK_ALPHA), width=3)
    return img


def generate_generic_bullet_crack_decal(variant: int) -> Image.Image:
    """"Cracked" bullet look: a small solid core, no rim, a few short hairline
    cracks. Always full-voxel, never carved, so there is no "cut" variant."""
    img = _generic_mark_canvas()
    draw = ImageDraw.Draw(img)
    cx, cy = DECAL_AUTHOR_W / 2.0, DECAL_AUTHOR_H / 2.0
    seed = variant * 97 + 13

    core = DECAL_AUTHOR_W * 0.09
    draw.ellipse([cx - core, cy - core, cx + core, cy + core],
                 fill=(70, 65, 60, GENERIC_MARK_INK_ALPHA))
    for i in range(4):
        angle = (2.0 * math.pi / 4) * i + 0.4 + (_hash01(seed, i, 230) - 0.5) * 0.7
        length = core + DECAL_AUTHOR_W * (0.04 + 0.05 * _hash01(seed, i, 240))
        ex, ey = cx + math.cos(angle) * length, cy + math.sin(angle) * length
        draw.line([(cx, cy), (ex, ey)], fill=(55, 50, 46, GENERIC_MARK_INK_ALPHA), width=2)
    return img


def _generic_jagged_ring(cx: float, cy: float, base_r: float, amplitude: float,
                         n_points: int, seed: int) -> list[tuple[float, float]]:
    pts = []
    for i in range(n_points):
        angle = (2.0 * math.pi / n_points) * i
        r = base_r + (_hash01(int(angle * 1000), i, seed) - 0.5) * 2 * amplitude
        pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    return pts


def generate_generic_blast_dent_decal(variant: int) -> Image.Image:
    """
    Blast dent: a data-driven jagged crater (hash-perturbed radius per angle,
    never hand-picked vertices) with blotch+grain shaded ink fill (same
    recipe as generate_broken_face()). Solid ink — see the module-level
    "cut" note above for why there is no cut here.
    """
    img = _generic_mark_canvas()
    cx, cy = DECAL_AUTHOR_W / 2.0, DECAL_AUTHOR_H / 2.0
    seed = variant * 131 + 7

    outline = _generic_jagged_ring(cx, cy, DECAL_AUTHOR_W * 0.30, DECAL_AUTHOR_W * 0.07, 12, seed + 1)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)

    fill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px = fill.load()
    base_tint = (46, 42, 38)
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    x0, x1 = max(0, int(min(xs))), min(img.size[0], int(max(xs)) + 1)
    y0, y1 = max(0, int(min(ys))), min(img.size[1], int(max(ys)) + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            blotch = _hash01(x // 6, y // 6, seed + 11)
            grain = _hash01(x, y, seed + 29)
            shade = 0.55 + 0.35 * blotch + 0.20 * grain
            px[x, y] = (
                min(255, int(base_tint[0] * shade)),
                min(255, int(base_tint[1] * shade)),
                min(255, int(base_tint[2] * shade)),
                GENERIC_MARK_INK_ALPHA,
            )
    img.paste(fill, (0, 0), mask)
    return img


def generate_generic_blast_crack_decal(variant: int) -> Image.Image:
    """Blast crack: branching fracture lines radiating from centre, hash-driven
    branch count/angle/fork so each variant reads distinctly. Always
    full-voxel (a crack never carves), so there is no "cut" variant."""
    img = _generic_mark_canvas()
    draw = ImageDraw.Draw(img)
    cx, cy = DECAL_AUTHOR_W / 2.0, DECAL_AUTHOR_H / 2.0
    seed = variant * 131 + 7
    n_branches = 5 + (seed % 3)
    for i in range(n_branches):
        angle = (2.0 * math.pi / n_branches) * i + _hash01(seed, i, 301) * 0.5
        length = DECAL_AUTHOR_W * (0.28 + 0.10 * _hash01(seed, i, 302))
        ex, ey = cx + math.cos(angle) * length, cy + math.sin(angle) * length
        width = 5 if i % 2 == 0 else 3
        draw.line([(cx, cy), (ex, ey)], fill=(48, 44, 40, GENERIC_MARK_INK_ALPHA), width=width)
        if _hash01(seed, i, 303) > 0.45:
            fork_t = 0.5 + _hash01(seed, i, 304) * 0.3
            fx, fy = cx + (ex - cx) * fork_t, cy + (ey - cy) * fork_t
            fork_angle = angle + (0.6 if i % 2 == 0 else -0.6)
            flen = length * 0.45
            fex = fx + math.cos(fork_angle) * flen
            fey = fy + math.sin(fork_angle) * flen
            draw.line([(fx, fy), (fex, fey)], fill=(48, 44, 40, GENERIC_MARK_INK_ALPHA), width=2)
    return img


# ---------------------------------------------------------------------------
# DESTRUCTION_MASTER_PLAN D2/D4 — floor/slab palette. Placeholder art: 8
# hand-picked tone variants of one "earth" base color, generated the same
# flat-lit way as MATERIALS above. Real art replaces these later without any
# code change — the D4 hash-selector only cares that 8 files exist at these
# names. NOT grayscale-constrained (B2 governs facade *pattern* sources, not
# these flat material atoms — concrete/wood above aren't grayscale either).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Floor-zone bake (ground_* materials, MaterialRegistry.full_color=true).
# Same shared cube shape/alpha as MATERIALS above — only the canonical
# silhouette matters here, since the baked page's real color comes from the
# photographic facade source, not this atom's fill. Colors below match
# MaterialRegistry.register_ground_defaults()'s placeholder base_color.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Output (relativo à raiz do projecto)
#
# ASSET_TREE_REFORM (2026-08-21): there is no single OUTPUT_DIR any more —
# each atom goes to its own material's folder via material_dir()/half_dir().
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Gerador principal
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    build_decal_family()


# ---------------------------------------------------------------------------
# Decal family driver (Director diagrams, 2026-08-02)
# ---------------------------------------------------------------------------

def build_decal_family() -> None:
    """
    Write the whole 2026-08-02 decal family: the Photoshop gabarito, the decal
    placeholders the Director will replace, the generic vector marks, the
    generic broken-face fallback — every one of them real decals/ INPUT art, per
    ASSET-LAYOUT-01. (The four half voxels per material went on 2026-11-11 with the
    atoms: the 3D board reads neither.)

    AUTHORED FILES ARE NEVER OVERWRITTEN. Decals are written
    only when absent — the diagram's own "IF NOT PRESENT IN THE FOLDER" — so
    re-running this after dropping real art keeps it.

    D33 Part 4c (2026-08-03): this used to also build every composite derived
    from the above (composites/ — material|half x decal, ~130 files) and end
    with `composites = 0` counting them. That whole stage is retired:
    composites/ is gone, every one of those shapes composites LIVE at runtime
    now instead (VoxelBoard's baked and generic branches).
    """
    DECAL_DIR.mkdir(parents=True, exist_ok=True)

    template_path = DECAL_DIR / DECAL_TEMPLATE_NAME
    generate_decal_template().save(template_path, "PNG")
    print(f"\n  ✓ {template_path}  (blank gabarito {DECAL_AUTHOR_W}×{DECAL_AUTHOR_H})")

    # D25 — the generic "inside of a broken voxel" surface, the cut-face fill
    # every half voxel's cut plane used to be composited with. No longer
    # loaded by the runtime (the live compositors read the flat MATERIALS
    # atom's own lateral colour instead — see _flat_material_side_color()),
    # kept here purely as authored decals/ INPUT art per ASSET-LAYOUT-01.
    generic_broken_path = DECAL_DIR / (BROKEN_FACE_TEMPLATE % "generic")
    if not generic_broken_path.exists():
        generate_broken_face().save(generic_broken_path, "PNG")
        print(f"  ✓ {generic_broken_path}  (generic broken-face fallback)")

    kept_decals = 0
    written_decals = 0
    decals: dict[tuple[str, str, int], Image.Image] = {}
    for material in IMPACT_MATERIALS:
        for family in DECAL_FAMILIES:
            if family == "crack" and material not in CRACK_MATERIALS:
                continue
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

    # D33 Part 4 — generic/vector mark decals, material-independent (see the
    # module docstring above generate_generic_bullet_decal for why these exist
    # separately from the photographic family above). "Never overwrite" the
    # same way as everything else in decals/, though nothing is expected to
    # replace these by hand — they are the permanent generic-path answer, not
    # a placeholder awaiting real art.
    kept_generic = 0
    written_generic = 0
    for kind in GENERIC_MARK_KINDS:
        for variant in range(GENERIC_MARK_VARIANTS):
            path = DECAL_DIR / (GENERIC_MARK_NAME % (kind, variant))
            if path.exists():
                kept_generic += 1
                continue
            generators = {
                "bullet_dented": generate_generic_bullet_decal,
                "bullet_cracked": generate_generic_bullet_crack_decal,
                "blast_dent": generate_generic_blast_dent_decal,
                "blast_crack": generate_generic_blast_crack_decal,
            }
            generators[kind](variant).save(path, "PNG")
            written_generic += 1
    print(f"  ✓ {written_generic} generic mark decal(s) written, "
          f"{kept_generic} kept → {DECAL_DIR}/")

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
        "floor_material": "earth",
        "families": list(DECAL_FAMILIES),
        "crack_materials": list(CRACK_MATERIALS),
    }
    manifest_path = MANIFEST_DIR / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"  ✓ {manifest_path}  (runtime variant discovery)")


if __name__ == "__main__":
    main()
