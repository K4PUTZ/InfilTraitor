#!/usr/bin/env python3
"""Procedural floor-shard decal — the `shard` family ART_ORDER_GLASS.md §2 asks
for, and the only ordinary decal family glass claims.

`shard` is NOT a damage mark on a wall. It is G-D16b's fallen glass lying on the
FLOOR, riding `_floor_sunk_decal_plan` like earth's dent, and its intensity is
how many shards reached that cell (`glass_fall.gd:119`). Glass never takes
`dent` (G-D3 amended D22 — glass fractures, it does not deform, and
`dent_factor` is pinned at 0.0 to say so) and never takes `bullet`/`crack`
either, because G-D21 folded the per-voxel mark into the fracture SHEET.

Unlike the sheet, this class DOES want alpha, and §5's luma-to-alpha recipe is
the right one here: build on black, take alpha = luminance, set RGB to the
shards' own near-white. A shard is therefore mostly TRANSPARENT with bright
edges — which is both what the recipe produces and what broken glass looks like.

    python3 gen_shard_decal.py 0 out.png [seed]
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

N = 256                     # ART_SPECIFICATIONS.md §7 — square, always
SS = 2
VARIANTS = 3                # what the runtime hashes into: not two, not four

# Three siblings, not three densities: the runtime picks between them at random,
# so one conspicuously heavier variant would read as a repeating stamp.
#
# ⚠️ THE SIZES ARE SET BY THE 1:16 READ, NOT BY HOW THE PAGE LOOKS. A decal is
# authored at 256 and lands on ONE voxel face — 16 x 20 px. The first pass used
# shards up to 200 authored px, which is 12 screen px: they read as sheets of
# glass at 256 and dissolved into an undifferentiated grey smudge at true size.
# A shard has to survive the reduction as a GLINT, so its long axis is held to
# roughly 30-70 authored px (2-4 screen px) and there are three times as many.
PRESETS = (
    dict(shards=78, dust=190, scale=(0.018, 0.050), heroes=7),
    dict(shards=88, dust=210, scale=(0.015, 0.044), heroes=6),
    dict(shards=70, dust=175, scale=(0.020, 0.058), heroes=8),
)


def _sliver(rng, cx, cy, size, ang):
    """One shard: 3-5 points, ACUTE and irregular. Glass does not break into
    pebbles — every piece has at least one sharp corner and one long edge, and
    that is the whole read at 1:16."""
    n = rng.choice((3, 3, 4, 5))
    # Angles bunched rather than spread, so the polygon comes out as a splinter
    # instead of a rounded blob.
    offs = sorted(rng.uniform(0.0, 2.0 * math.pi) for _ in range(n))
    stretch = rng.uniform(1.5, 3.2)             # the long axis
    pts = []
    for a in offs:
        r = size * rng.uniform(0.35, 1.0)
        x = math.cos(a) * r * stretch
        y = math.sin(a) * r
        pts.append((cx + x * math.cos(ang) - y * math.sin(ang),
                    cy + x * math.sin(ang) + y * math.cos(ang)))
    return pts


def generate(variant, seed=11):
    p = PRESETS[variant % VARIANTS]
    img = Image.new("L", (N * SS, N * SS), 0)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed * 31 + variant)

    # A pile is not uniform: shards land in a loose drift, so the scatter gets a
    # soft centre of mass rather than covering the tile evenly.
    dx, dy = rng.uniform(0.35, 0.65), rng.uniform(0.35, 0.65)

    for _ in range(p["shards"]):
        cx = (dx + rng.gauss(0.0, 0.26)) * N * SS
        cy = (dy + rng.gauss(0.0, 0.26)) * N * SS
        size = rng.uniform(*p["scale"]) * N * SS
        pts = _sliver(rng, cx, cy, size, rng.uniform(0.0, 2.0 * math.pi))
        # The FACET is dim and the EDGES are bright: a shard is transparent
        # except where a broken face catches light. Fill first, outline over it.
        d.polygon(pts, fill=rng.randint(8, 28))
        for a, b in zip(pts, pts[1:] + pts[:1]):
            d.line([a, b], fill=rng.randint(150, 255),
                   width=max(1, int(rng.uniform(0.9, 1.8) * SS)))
        # One interior crease on the bigger pieces — a facet edge, not a crack.
        if size > 0.12 * N * SS and len(pts) >= 4:
            d.line([pts[0], pts[2]], fill=rng.randint(90, 170), width=SS)

    # THE HEROES. A field of uniformly small shards averages, at 1:16, into flat
    # grey noise — every piece is below the resolution and none of them survives
    # as itself. So a handful are deliberately larger and drawn at full weight:
    # they are the pieces that still produce a distinct bright PIXEL after the
    # reduction, and they are what says "glass" rather than "dirt".
    for _ in range(p["heroes"]):
        cx = (dx + rng.gauss(0.0, 0.22)) * N * SS
        cy = (dy + rng.gauss(0.0, 0.22)) * N * SS
        size = rng.uniform(0.055, 0.095) * N * SS
        pts = _sliver(rng, cx, cy, size, rng.uniform(0.0, 2.0 * math.pi))
        d.polygon(pts, fill=rng.randint(40, 78))
        for a, b in zip(pts, pts[1:] + pts[:1]):
            d.line([a, b], fill=255, width=max(1, int(rng.uniform(1.8, 3.0) * SS)))

    # Dust: the grains too small to be a shape, densest where the pile is.
    for _ in range(p["dust"]):
        x = (dx + rng.gauss(0.0, 0.30)) * N * SS
        y = (dy + rng.gauss(0.0, 0.30)) * N * SS
        s = rng.uniform(0.6, 2.0) * SS
        d.polygon([(x + math.cos(b) * s * rng.uniform(0.4, 1.7),
                    y + math.sin(b) * s * rng.uniform(0.4, 1.7))
                   for b in (0.0, 2.1, 4.2)], fill=rng.randint(120, 255))

    img = img.filter(ImageFilter.GaussianBlur(0.4 * SS)).resize((N, N), Image.LANCZOS)

    # §5's luma-to-alpha, and the step that makes this class the OPPOSITE of the
    # fracture sheet: there alpha is destroyed by the facade path and must not be
    # relied on, here the alpha IS the decal.
    out = Image.new("RGBA", (N, N), (238, 244, 246, 0))
    out.putalpha(img)
    return out


if __name__ == "__main__":
    v, out = int(sys.argv[1]), sys.argv[2]
    s = int(sys.argv[3]) if len(sys.argv) > 3 else 11
    generate(v, s).save(out)
    print("wrote %s (variant %d, seed %d)" % (out, v, s))
