#!/usr/bin/env python3
"""Procedural glass fracture sheet — the generator behind ART_ORDER_GLASS.md.

Produces the 1024x512 grayscale-on-black page section 1 of that order asks for.
Radial by construction, so G-D21's centred origin is EXACT rather than hoped
for, and G-D23's reach is a parameter rather than a lottery.

The vocabulary, in the order it is drawn:

  1. the radials   — STRAIGHT runs leaving the hole, kinking, never wandering.
                     Walked FIRST and their polylines KEPT, because everything
                     below is positioned against them
  2. the slivers   — the shard between two neighbouring radials, clipped to
                     those two actual cracks. The MASS that makes a sheet read
                     as broken glass instead of as a line drawing
  3. the waves     — concentric cracks CONCENTRATED around the shot, broken into
                     arcs so they never close into a ring
  4. the dirt      — incomplete stubs, misshapen flecks and specks, densest at
                     the hole and thinning as 1/r^2
  5. the centre    — the bullet's own crush RIM around a void (G-D14), or, for
                     G-D28's `armored` class, an opaque crushed-white CORE where
                     the round stopped and no voxel was removed

⚠️ ONE SHEET FAMILY PER OPENING, PLUS THE ONE CLASS THAT HAS NO OPENING.
CRACK-04 retired the `tight`/`wide` pair: each of the twelve members of
`GlassOpening.FAMILY` gets three sheets generated FROM its own polygon, and
`fracture_manifest.json` is the roster `check_decal.py` reads. `armored`
(CRACK-05) rides that roster WITHOUT being a member of the family — armoured
glass loses no voxel, so its sheet answers to no polygon.

    python3 tools/persistent/gen_fracture_sheet.py --all
    python3 tools/persistent/gen_fracture_sheet.py --only armored
"""
import argparse
import io
import math
import zlib
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 1024, 512
SS = 2                      # supersample, downsampled at the end for antialias
VOXEL = 16                  # TEX_AUTHORING_N, pinned by ART_SPECIFICATIONS.md

# ⚠️ THE HOLE IS NO LONGER A NUMBER HERE. It used to be `hole_voxels`, a DIAMETER
# in voxels, and the art's job was to put a crush rim at the matching radius. Since
# CRACK-04 the hole is an OPENING — a polygon from `GlassOpening`, twelve of them,
# none of them round — so the sheet is generated FROM that polygon: every crack
# starts on its boundary at its own angle, and the rim traces it.
#
# ⚠️ AND THE POLYGON IS NOT COPIED INTO THIS FILE. `glass_opening.gd` is the one
# authority; `--openings` runs the dumper and reads it back, so a member retuned in
# GDScript cannot leave the art describing a hole the engine no longer cuts.
#
# What is left here is DENSITY, per size class, scaled by the opening's own reach.
PRESETS = {
    "small": dict(radials=11, reach=0.34,
                  waves=9, wave_ratio=1.30, wave_span=(1, 3), wave_falloff=0.55,
                  wave_start=1.55, slivers=9, stubs=90, specks=110, twins=2),
    "large": dict(radials=15, reach=1.16,
                  waves=12, wave_ratio=1.28, wave_span=(1, 4), wave_falloff=0.70,
                  wave_start=2.30, slivers=16, stubs=170, specks=190, twins=4),

    # ── G-D28's ARMORED class ────────────────────────────────────────────────
    #
    # (Director, 2026-09-02, correcting the reading of his own reference set:
    # *"o tiro a prova de balas não é uniforme, ele tem um centro assim"*.)
    #
    # ⚠️ THE DISTINGUISHING FEATURE IS THE CENTRE, NOT THE SPREAD, and here the
    # centre is the OPPOSITE of every other member's: an OPAQUE CRUSHED-WHITE
    # CORE of pulverised glass where the others have a void. The round did not
    # pass through — *"estilhaça mas não rompe"* — so there is nothing behind to
    # see, and the sheet is the ONLY thing that can say the pane held.
    #
    # Around it: dense radial NEEDLES (many, fine, short) rather than a few long
    # runners, and a wider secondary craze field carried by the waves.
    # ⚠️ TWO CLASSES, AND THE ONLY THING THAT DIFFERS IS THE PAGE SPAN (Director,
    # 2026-09-04: *"3 versões diferentes pra cada calibre"*, on G-D14's existing
    # two-way split — `WeaponDef.blowout` < 0.5 vs >= 0.5). A rifle's mark is a
    # BIGGER version of the same composition, not a different drawing: the sheet
    # is page-relative throughout (see ARMORED_CORE), so one preset body serves
    # both and the span is the whole size decision. 10 x 5 is the Director's pick
    # off `glass_armored_span_strip_2026-09-04.png`.
    "armored_tight": dict(radials=26, reach=0.30, stroke=(1.1, 2.0), stroke_twin=(0.7, 1.3),
                    waves=7, wave_ratio=1.34, wave_span=(3, 6), wave_falloff=0.30,
                    wave_start=2.20, slivers=6, stubs=150, specks=240, twins=3,
                    field=(900, 2.2, 8.5), span=(10.0, 5.0)),
    "armored_wide": dict(radials=30, reach=0.30, stroke=(1.1, 2.0), stroke_twin=(0.7, 1.3),
                    waves=7, wave_ratio=1.34, wave_span=(3, 6), wave_falloff=0.30,
                    wave_start=2.20, slivers=6, stubs=170, specks=270, twins=3,
                    field=(1000, 2.2, 8.5), span=(16.0, 8.0)),
}

# ── THE ARMORED "OPENING", WHICH IS NOT ONE ─────────────────────────────────
#
# ⚠️ IT IS A CORE OUTLINE, NOT A HOLE, AND THAT IS THE ONLY DIFFERENCE THE REST
# OF THIS FILE NEEDS. Every routine below already asks `hole_at(ang)` for "where
# does the glass begin" — the needles start on it, the rim traces it, the feather
# ramps from it. For `armored` the same curve is where the PULVERISED glass ends
# and the cracked-but-whole pane begins, so the machinery is reused verbatim and
# exactly two things change: the void is FILLED instead of cut, and the centre
# feather is off (it exists to ramp ink IN from a void's edge, and this centre is
# the brightest part of the page).
#
# ⚠️ RADII ARE A FRACTION OF THE PAGE'S HALF-WIDTH, NOT VOXELS, AND THE SPAN
# STRIP IS WHY.
#
# Every other member's geometry is anchored in VOXELS because it is generated
# from a real OPENING: a hole is a fixed number of voxels across whatever page it
# is drawn on, so the page may be resized around it. `armored` has no hole, so
# nothing anchors it — and the Director sized it by looking at the WHOLE
# composition scaled up and down (`glass_armored_span_strip_2026-09-04.png`,
# where only the quad moved and the art did not change).
#
# Leaving the radii in voxels would therefore have re-proportioned the sheet at
# the span he picked: at 24 the core is 2.5% of the page, at 10 it would have
# been 6.0% — a core 2.4x larger relative to its own needles than the frame that
# was approved. Page-relative, the composition is identical at every span and the
# span is purely how big the mark is on the pane.
#
# Ragged rather than round: a crush zone is not a circle, and a circle is what
# would read as a painted dot.
ARMORED_CORE = [0.0517, 0.0458, 0.0567, 0.0483, 0.0417, 0.0533, 0.0475, 0.0592,
                0.0450, 0.0500, 0.0550, 0.0433, 0.0525, 0.0467, 0.0575, 0.0492]

# How far into the core the SOLID white heart reaches, as a fraction of the local
# core radius. Above it the facets take over and fade. 1.0 would be a painted
# disc, 0.0 a ring with a hole in it.
ARMORED_HEART = 0.42

# The heart's LUMINANCE, and it is deliberately not 255 (Director, 2026-09-04:
# *"tira um pouco a opacidade do centro, queremos ver um restinho do fundo"*).
#
# ⚠️ IT IS TUNED HERE AND NOT IN THE SHADER. `crack_opacity` is 0.80 for EVERY
# crack in the game — a ratified dial (*"da pra ver um pouco do cenário atrás da
# rachadura"*) — so lowering it for the armoured core would quietly re-open a
# decision that was made once for the whole track. The sheet's own ink is the
# per-class knob: luma IS the alpha, so 205 lands the core at 205/255 x 0.80 =
# 64% opaque and leaves a third of the pane showing through.
#
# The facets on top still reach 255 in places, which is what keeps the core
# reading as CRUSHED rather than as a flat translucent dot.
ARMORED_HEART_LUMA = 205

# How many voxels of PAGE per voxel of hole DIAMETER. Ratified by looking:
# `SHEET_SCALE` 1.4 on the old (20 voxel page / 3.4 voxel hole) is ~8.2, and the
# Director picked that from the 1.0 / 1.4 / 1.8 strip.
SPAN_RATIO = 8.2

# How far past the void's edge the ink ramps in, as a fraction of the LOCAL hole
# radius. 0 restores the hard bright ring the sheets opened with before.
CENTRE_FEATHER = 0.45

# Variants per opening (Director, 2026-09-04: *"3 decals pra cada tipo de buraco"*).
VARIANTS = 3

# A crack runs STRAIGHT and changes direction only where it forks or kinks.
# The wandering line of the first draft read as a root or a lightning bolt,
# which is the single thing glass does not do.
KINK = 0.13                 # radians, at a kink and nowhere else
SEG_MIN, SEG_MAX = 0.14, 0.30   # kink spacing, as a fraction of the run


def _walk(rng, x, y, ang, length):
    """The path of one crack, as (point, t) pairs. Geometry only — no drawing,
    because the slivers need these points before anything is painted."""
    pts = [((x, y), 0.0)]
    travelled = 0.0
    while travelled < length:
        seg = min(length * rng.uniform(SEG_MIN, SEG_MAX), length - travelled)
        x, y = x + math.cos(ang) * seg, y + math.sin(ang) * seg
        travelled += seg
        pts.append(((x, y), travelled / length))
        ang += rng.uniform(-KINK, KINK)
    return pts, ang


def _stroke(draw, pts, bright, wdt0):
    """Paint a walked path. Width and luminance both taper: a crack is widest
    and brightest where the energy entered it, and dies to a hairline."""
    for (a, t), (b, _) in zip(pts, pts[1:]):
        draw.line([a, b], fill=int(bright * (1.0 - 0.62 * t)),
                  width=max(1, int(round(wdt0 * (1.0 - 0.8 * t) * SS))))


def _at(pts, frac):
    """The point a fraction of the way along a walked path."""
    for (p, t) in pts:
        if t >= frac:
            return p
    return pts[-1][0]


def _falloff_radius(rng, hole, limit):
    """A radius whose density falls as 1/r^2 — the debris crowds the impact.
    Rejection sampling rather than an inverse-CDF, which is not worth deriving
    for two hundred flecks."""
    for _ in range(40):
        r = rng.uniform(hole, limit)
        if rng.random() < 1.0 / (1.0 + (r / (hole * 3.0)) ** 2):
            return r
    return rng.uniform(hole, limit * 0.4)


def span_voxels(opening):
    """The page's span in voxels for this opening — width, height (the page is 2:1).

    Returned rather than assumed by the engine: the manifest carries it, so the
    quad the sprite builds and the page the art was drawn on cannot disagree.

    ⚠️ `armored` OVERRIDES IT, and has to. Every other member's page is sized from
    its HOLE, because the hole is what the web is a consequence of. Armoured glass
    has no hole and its core is barely a voxel across, so `SPAN_RATIO` would draw
    the whole class at a tenth of the size — a crush mark the eye would never find
    on a pane. Its span is stated instead, near the retired `tight` page's 20 x 10
    and a little wider for the secondary craze field the class is defined by."""
    p = PRESETS[opening["size"]]
    if "span" in p:
        return p["span"]
    d = opening["r_max"] * 2.0
    return (d * SPAN_RATIO, d * SPAN_RATIO / 2.0)


def _draw_craze_field(d, rng, cx, cy, hole, count, r_lo, r_hi):
    """G-D28's *"wider secondary craze field"*, as its own population.

    ⚠️ IT IS NOT MORE WAVES, AND THE FIRST VERSION PROVED WHY. Reusing the wave
    generator at a bigger radius drew a handful of long zigzag polylines out in
    the dark — the *mandala* trap's opposite number, reading as scattered
    lightning rather than as a field. A craze field is MANY SHORT cracks, mostly
    TANGENTIAL to the impact (that is what distinguishes it from the radial
    needles), thinning outward, none of them bright."""
    for _ in range(count):
        ## Area-uniform between the two radii, then thinned by 1/r so the band
        ## still fades rather than ending on a hard circle.
        r = math.sqrt(rng.uniform(r_lo ** 2, r_hi ** 2)) * hole
        if rng.random() > r_lo * hole / r:
            continue
        a = rng.uniform(0, 2.0 * math.pi)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        ## Tangential, give or take: a + pi/2 with a wide jitter.
        ang = a + math.pi * 0.5 + rng.uniform(-0.7, 0.7)
        ln = rng.uniform(0.35, 1.1) * hole
        pts, _ = _walk(rng, x, y, ang, ln)
        _stroke(d, pts, rng.randint(70, 150), rng.uniform(0.7, 1.3))


def _draw_crushed_core(d, rng, cx, cy, hole_at):
    """G-D28's opaque core: pulverised glass, brightest at the middle, ragged at
    the edge, never a void and never a clean disc.

    Three layers, and each answers a way the first attempts read wrong:
      1. the HEART — a filled irregular polygon at full white, so the middle is
         actually opaque rather than a dense speckle that greys out at distance;
      2. the FACETS — several hundred tiny bright polygons between the heart and
         the core edge, thinning and dimming outward, which is what makes it read
         as crushed rather than painted;
      3. the LIP — short bright strokes crossing the boundary, so the core is
         continuous with the needles instead of sitting on top of them."""
    n = 360
    ang = [2.0 * math.pi * i / n for i in range(n)]

    ## 1. The heart.
    d.polygon([(cx + math.cos(a) * hole_at(a) * ARMORED_HEART * rng.uniform(0.88, 1.12),
                cy + math.sin(a) * hole_at(a) * ARMORED_HEART * rng.uniform(0.88, 1.12))
               for a in ang[::12]], fill=ARMORED_HEART_LUMA)

    ## 2. The facets. Area-uniform in r so they do not pile up at the centre —
    ## the DENSITY gradient comes from the brightness ramp, not from crowding,
    ## because a crowded centre is already solid.
    for _ in range(520):
        a = rng.uniform(0, 2.0 * math.pi)
        h = hole_at(a)
        r = h * math.sqrt(rng.uniform(ARMORED_HEART ** 2, 1.0))
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        t = (r / h - ARMORED_HEART) / max(1.0 - ARMORED_HEART, 0.001)
        s = rng.uniform(0.02, 0.09) * h
        d.polygon([(x + math.cos(b) * s * rng.uniform(0.4, 1.7),
                    y + math.sin(b) * s * rng.uniform(0.4, 1.7))
                   for b in (0.0, 1.9, 3.6, 5.0)],
                  fill=int(ARMORED_HEART_LUMA * 1.24 * (1.0 - 0.55 * t)
                            * rng.uniform(0.75, 1.0)))

    ## 3. The lip — outward strokes straddling the boundary.
    for _ in range(220):
        a = rng.uniform(0, 2.0 * math.pi)
        h = hole_at(a)
        r0 = h * rng.uniform(0.80, 1.00)
        r1 = h * rng.uniform(1.02, 1.45)
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                (cx + math.cos(a) * r1, cy + math.sin(a) * r1)],
               fill=rng.randint(150, 235), width=max(1, int(1.2 * SS)))
    ## A few longer spall cracks leaving the core, so it is not a self-contained
    ## blob: the pane is cracked, the core is only where it was pulverised.
    for _ in range(14):
        a = rng.uniform(0, 2.0 * math.pi)
        h = hole_at(a)
        pts, _ = _walk(rng, cx + math.cos(a) * h, cy + math.sin(a) * h, a,
                       h * rng.uniform(2.6, 7.0))
        _stroke(d, pts, rng.randint(170, 230), rng.uniform(1.0, 1.8))


def generate(opening, seed=7):
    p = PRESETS[opening["size"]]
    img = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    cx, cy = W * SS / 2.0, H * SS / 2.0

    # Voxels -> page pixels. The page spans `span_x` voxels across its full width.
    span_x, _span_y = span_voxels(opening)
    px_per_voxel = (W * SS) / span_x
    radii = opening["radii"]
    n_r = len(radii)
    ## ⚠️ WHAT ONE UNIT OF `radii` MEANS DEPENDS ON THE CLASS, and it is stated
    ## here rather than left to the caller. An OPENING's radii are VOXELS — the
    ## polygon the engine cuts, which is a fixed size on the pane however the page
    ## is scaled. `armored`'s are a fraction of the page's HALF-WIDTH, because it
    ## has no opening to be anchored to and its size is the span alone
    ## (ARMORED_CORE's own note carries the measurement).
    radius_unit = (W * SS) / 2.0 if opening.get("solid_core", False) else px_per_voxel

    def hole_at(ang):
        """The opening's boundary along `ang`, in page pixels. This replaces the
        single `hole` radius: a crack starts where the glass actually ends.

        ⚠️ THE ANGLE IS NEGATED, AND THAT IS A FIXED BUG, NOT A CONVENTION CHOICE.
        This file draws in IMAGE space, where y grows DOWN; `radii` was sampled in
        the pane's (run, level) space, where y grows UP. `glass_crack.gdshader`
        confirms which way the sheet is read: `off.y = (0.5 - UV.y) * span.y`, so
        image row 0 is level UP. Looking the radius up at `+ang` therefore drew
        every opening MIRRORED VERTICALLY.
        ⚠️ AND IT WAS INVISIBLE ON TWO THIRDS OF THE FAMILY: every regular star at
        phase 0 is symmetric about the horizontal axis, so the mirror is the
        identity on it. It showed only on the asymmetric members — which is
        exactly the set the Director circled (`chunk_bite`, `crescent_wide`,
        `star_ragged_wide`, `star_wild`) while asking whether there was a flip."""
        t = ((-ang) % (2.0 * math.pi)) / (2.0 * math.pi) * n_r
        i0 = int(t) % n_r
        i1 = (i0 + 1) % n_r
        f = t - int(t)
        return (radii[i0] * (1.0 - f) + radii[i1] * f) * radius_unit

    # A representative radius, for the routines that want one scalar (the speck
    # and stub falloffs). The MEAN, not the max: the max is one spike's tip and
    # would push every speck out past the whole web.
    hole = (sum(radii) / float(n_r)) * radius_unit

    # The radial run reaches a page CORNER at 1.0, so reach > 1 clips at the
    # edges instead of stopping short of them.
    full = math.hypot(W * SS / 2.0, H * SS / 2.0)
    length = full * p["reach"]

    # THE ANGLES, and the first source of variation. Not "uniform plus jitter":
    # that still reads as a wheel because every gap is the same size. Gaps are
    # drawn from a spread and then NORMALISED to close the circle, so a sheet
    # gets crowded sectors beside empty ones — which is what a real impact does.
    gaps = [rng.uniform(0.45, 1.55) for _ in range(p["radials"])]
    scale = 2.0 * math.pi / sum(gaps)
    angs, acc = [], rng.uniform(0, 2.0 * math.pi)
    for g in gaps:
        angs.append(acc)
        acc += g * scale
    angs.sort()

    # 1. THE RADIALS, walked first and KEPT. Length, width and brightness all
    #    vary per crack: a pane that threw every crack the same distance at the
    #    same weight reads as a wheel, not as a break.
    paths = []
    for a in angs:
        h_a = hole_at(a)
        pts, _ = _walk(rng, cx + math.cos(a) * h_a, cy + math.sin(a) * h_a, a,
                       length * rng.uniform(0.35, 1.0))
        paths.append(pts)

    # A TWIN is a second crack running a hair off a radial. The glass between
    # the two is a long thin sliver, and it is the single most "glass" mark in
    # the reference art — the reason a real break reads as pieces, not lines.
    for _ in range(p["twins"]):
        i = rng.randrange(len(angs))
        a = angs[i] + rng.uniform(-0.09, 0.09)
        # ⚠️ CAPPED, and the cap is the whole point. Un-capped, a twin beside a
        # `wide` radial spans a run three times longer than a `tight` one and
        # the sliver between them opens into a huge grey WEDGE — the v4 slab
        # defect coming back through a different door. A twin is a SHORT mark.
        twin_len = length * rng.uniform(0.16, 0.34)
        h_t = hole_at(a) * rng.uniform(1.0, 1.6)
        pts, _ = _walk(rng, cx + math.cos(a) * h_t,
                       cy + math.sin(a) * h_t, a, twin_len)
        base = [q for (q, t) in paths[i] if t <= twin_len / length]
        n = min(len(pts), len(base))
        if n >= 3:
            d.polygon(base[:n] + [q for (q, _) in reversed(pts[:n])],
                      fill=rng.randint(14, 34))
        paths.append(pts)

    # 2. THE SLIVERS, CLIPPED TO THE TWO RADIALS THAT BOUND THEM.
    #
    #    ⚠️ v4 and v5 drew a free polygon in the same SECTOR instead, and at
    #    true size it read as a flat grey slab pasted onto the page — in v4 the
    #    slabs even dragged the ink centroid to (+1.6, +1.8) voxels, the gate
    #    telling the same story in a number. Built from the real crack paths a
    #    shard cannot float, its outline is already irregular for free, and its
    #    shape varies with whatever the two cracks happened to do.
    for _ in range(p["slivers"]):
        i = rng.randrange(len(angs))
        a_pts, b_pts = paths[i], paths[(i + 1) % len(angs)]
        f0 = rng.uniform(0.05, 0.55)
        f1 = f0 + rng.uniform(0.10, 0.30)
        poly = [q for (q, t) in a_pts if f0 <= t <= f1]
        poly += [q for (q, t) in reversed(b_pts) if f0 <= t <= f1]
        if len(poly) >= 3:
            # Barely brighter than the field: a shard reads through its lit
            # EDGE, never through its fill.
            d.polygon(poly, fill=rng.randint(10, 30), outline=rng.randint(140, 225))

    ## The stroke width is a class property: `armored`'s vocabulary is dense
    ## NEEDLES, and 26 radials at a bullet hole's 2.4–4.0 px would close into a
    ## solid star instead of reading as separate cracks.
    ## ⚠️ THE TWIN WIDTH IS ITS OWN KEY, NOT A FRACTION OF THE RADIAL'S. Deriving
    ## it (`w0 * 0.58`) reproduced the shipped 1.4 only to three decimals, and this
    ## generator's whole claim is that re-running it reproduces the art — 36 sheets
    ## would have come back byte-different for a rounding error in a default.
    w0, w1 = p.get("stroke", (2.4, 4.0))
    t0, t1 = p.get("stroke_twin", (1.4, 2.4))
    for pts in paths[:len(angs)]:
        _stroke(d, pts, rng.randint(210, 255), rng.uniform(w0, w1))
    for pts in paths[len(angs):]:
        _stroke(d, pts, rng.randint(150, 210), rng.uniform(t0, t1))

    # 3. THE WAVES. Spaced GEOMETRICALLY so they crowd the shot and thin
    #    outward — that density gradient is what reads as "a round went through
    #    HERE".
    #
    #    ⚠️ THE TRAP THIS AVOIDS, found by looking at v2 at true size: a wave
    #    drawn across EVERY sector at ONE radius closes into a regular polygon,
    #    and a stack of them reads as a mandala. So a wave is an ARC of a few
    #    adjacent sectors starting at a random one, its radius DRIFTS as it
    #    goes, and the outer ones mostly do not happen at all.
    r = hole * p["wave_start"]
    for k in range(p["waves"]):
        t = k / float(max(1, p["waves"] - 1))
        if rng.random() < p["wave_falloff"] * t:
            r *= p["wave_ratio"]
            continue                     # an outer wave that simply is not there
        for _ in range(rng.randint(1, 3) if t < 0.45 else 1):
            i0 = rng.randrange(len(angs))
            # An OUTER wave spans one sector only. Left long, its chords chain
            # into a big regular polygon out at the rim — the mandala of v2
            # returning at the other end of the radius.
            span = 1 if t > 0.5 else rng.randint(*p["wave_span"])
            rr = r * rng.uniform(0.90, 1.10)
            pts = []
            for j in range(span + 1):
                idx = i0 + j
                a = angs[idx % len(angs)] + 2.0 * math.pi * (idx // len(angs))
                rr *= rng.uniform(0.93, 1.07)          # the radius drifts
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
                if j < span:                            # bow the mid-point out
                    a1 = angs[(idx + 1) % len(angs)] + 2.0 * math.pi * ((idx + 1) // len(angs))
                    am = (a + a1) / 2.0
                    rm = rr * rng.uniform(1.03, 1.15)
                    pts.append((cx + math.cos(am) * rm, cy + math.sin(am) * rm))
            d.line(pts, fill=int(255 * (1.0 - 0.42 * t)),
                   width=max(1, int(round((2.8 - 1.6 * t) * SS))))
        r *= p["wave_ratio"]

    # 4. THE DIRT. Everything that is not a clean crack: stubs that start and
    #    end in the middle of nothing, and misshapen flecks. Both crowd the hole
    #    and thin as 1/r^2, the same gradient the waves carry — so they
    #    reinforce each other instead of arguing.
    for _ in range(p["stubs"]):
        rr = _falloff_radius(rng, hole * 1.2, length)
        a = rng.uniform(0, 2.0 * math.pi)
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        ang = a + rng.uniform(-0.5, 0.5)               # roughly radial, not exactly
        ln = rng.uniform(6, 34) * SS * (1.0 if rng.random() < 0.8 else 2.2)
        d.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)],
               fill=rng.randint(90, 235), width=max(1, int(rng.uniform(0.8, 2.0) * SS)))
    for _ in range(p["specks"]):
        rr = _falloff_radius(rng, hole * 1.1, length * 0.8)
        a = rng.uniform(0, 2.0 * math.pi)
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        s = rng.uniform(0.7, 2.6) * SS
        # Misshapen, never a dot: three points at unequal radii.
        d.polygon([(x + math.cos(b) * s * rng.uniform(0.4, 1.6),
                    y + math.sin(b) * s * rng.uniform(0.4, 1.6))
                   for b in (0.0, 2.1, 4.2)], fill=rng.randint(110, 255))

    # 5. THE CENTRE. Two classes, and G-D28 says the centre is what separates
    #    them: a bullet class has a VOID with a crush rim around it, `armored`
    #    has an opaque crushed CORE and no void at all.
    if opening.get("solid_core", False):
        f = p.get("field", (0, 2.0, 6.0))
        _draw_craze_field(d, rng, cx, cy, hole, f[0], f[1], f[2])
        _draw_crushed_core(d, rng, cx, cy, hole_at)
        img = img.filter(ImageFilter.GaussianBlur(0.55 * SS))
        img = img.resize((W, H), Image.LANCZOS)
        return img.convert("RGB")

    # The impact voxel is DESTROYED by G3 and stops rendering (order section
    # 1.2), so what has to read is the crush RIM around it: a bright ragged lip,
    # with the bore itself black.
    for _ in range(int(150 * opening["r_max"] * 2.0)):
        a = rng.uniform(0, 2 * math.pi)
        h_s = hole_at(a)
        r0 = h_s * rng.uniform(0.95, 1.12)
        r1 = r0 + h_s * rng.uniform(0.15, 0.75)
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                (cx + math.cos(a) * r1, cy + math.sin(a) * r1)],
               fill=rng.randint(190, 255), width=max(1, int(1.4 * SS)))
    # ⚠️ THE RIM IS THE OPENING'S OWN OUTLINE, NOT A CIRCLE. Drawing an ellipse
    # here was right while the hole was round; against a star or a chunk it left a
    # bright ring floating across the void with the glass nowhere near it.
    ring = [(cx + math.cos(2.0 * math.pi * i / 360.0) * hole_at(2.0 * math.pi * i / 360.0) * 1.08,
             cy + math.sin(2.0 * math.pi * i / 360.0) * hole_at(2.0 * math.pi * i / 360.0) * 1.08)
            for i in range(360)]
    d.line(ring + [ring[0]], fill=255, width=max(1, int(2.2 * SS)))
    # ...and the void itself, so no ink survives where the engine will cut anyway.
    d.polygon([(cx + math.cos(2.0 * math.pi * i / 360.0) * hole_at(2.0 * math.pi * i / 360.0),
                cy + math.sin(2.0 * math.pi * i / 360.0) * hole_at(2.0 * math.pi * i / 360.0))
               for i in range(360)], fill=0)

    # ── THE CENTRE FEATHER (Director, 2026-09-04: *"da um pouco de father no
    # centro dos decals, pra eles começarem mais suaves"*) ─────────────────────
    #
    # The ink used to start at full weight on the void's edge, so every sheet
    # opened with a hard bright ring. This ramps it in over a band just outside
    # the boundary — smoothstep, in units of the LOCAL hole radius, so a spike's
    # flank feathers over the same fraction as a valley rather than the same
    # number of pixels.
    if CENTRE_FEATHER > 0.0:
        px_img = img.load()
        reach = int(math.ceil(max(radii) * px_per_voxel * (1.0 + CENTRE_FEATHER))) + 2
        x0 = max(0, int(cx) - reach)
        x1 = min(W * SS, int(cx) + reach)
        y0 = max(0, int(cy) - reach)
        y1 = min(H * SS, int(cy) + reach)
        for y in range(y0, y1):
            dy = float(y) - cy
            for x in range(x0, x1):
                v = px_img[x, y]
                if v == 0:
                    continue
                dx = float(x) - cx
                r = math.hypot(dx, dy)
                if r < 0.0001:
                    continue
                h_r = hole_at(math.atan2(dy, dx))
                if h_r <= 0.0 or r >= h_r * (1.0 + CENTRE_FEATHER):
                    continue
                t = (r / h_r - 1.0) / CENTRE_FEATHER
                t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
                px_img[x, y] = int(v * (t * t * (3.0 - 2.0 * t)))

    img = img.filter(ImageFilter.GaussianBlur(0.55 * SS))
    img = img.resize((W, H), Image.LANCZOS)
    return img.convert("RGB")          # R == G == B, invariant B2


GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
DUMPER = "godot/scripts/tools/dump_glass_openings.gd"


def armored_openings():
    """G-D28's `armored` class, in the shape this generator draws from.

    Two of them since the Director's *"3 versões diferentes pra cada calibre"* —
    `armored_tight` and `armored_wide`, on G-D14's existing blowout split. They
    share every parameter but the page SPAN, which is the whole size decision
    because the composition is page-relative (see ARMORED_CORE).

    ⚠️ IT IS DELIBERATELY NOT A MEMBER OF `GlassOpening.FAMILY`, and the reason is
    the whole ruling: an OPENING is a hole — a polygon the engine erases voxels
    inside of — and armoured glass has none. Putting it in the family would make
    it pickable by `GlassOpening.pick()` and cuttable by `refresh_glass_rims()`,
    which is precisely the pane that must never lose a voxel (G-D15).

    So it rides here as a SHEET id only. It reaches the runtime the same way every
    other sheet does — a row in `fracture_manifest.json`, keyed by name — and
    `GlassCrack.sheet_id_for()` is what selects it, off the pane's MATERIAL rather
    than off the weapon."""
    return [{"id": name, "size": name, "solid_core": True,
             "radii": ARMORED_CORE, "r_max": max(ARMORED_CORE)}
            for name in ("armored_tight", "armored_wide")]


def load_openings(project_root):
    """Ask `glass_opening.gd` for the family. See the note on PRESETS: this is the
    reason the polygons are not duplicated here."""
    import json
    import subprocess
    r = subprocess.run([GODOT, "--headless", "--path", project_root, "--script", DUMPER],
                       capture_output=True, text=True)
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith("{") and '"openings"' in line:
            return json.load(io.StringIO(line))["openings"]
    raise SystemExit("could not read the opening family from Godot:\n" + r.stdout + r.stderr)


if __name__ == "__main__":
    import io
    import json
    import os

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--all", action="store_true",
                    help="generate every opening x variant, plus the manifest")
    ap.add_argument("--out-dir", default="ASSETS/materials/glass",
                    help="where the sheets and the manifest are written")
    ap.add_argument("--project", default=".", help="Godot project root")
    ap.add_argument("--only", default="", help="one opening id, for a quick look")
    args = ap.parse_args()

    if not args.all and not args.only:
        ap.error("nothing to do — pass --all, or --only <opening>")

    openings = load_openings(args.project) + armored_openings()
    if args.only:
        openings = [o for o in openings if o["id"] == args.only]
        if not openings:
            raise SystemExit("no such opening: %s" % args.only)

    os.makedirs(args.out_dir, exist_ok=True)
    manifest = {}
    for o in openings:
        sx, sy = span_voxels(o)
        entries = []
        for v in range(VARIANTS):
            name = "fracture_glass_%s_%d.png" % (o["id"], v)
            # ⚠️ THE SEED IS DERIVED FROM THE ID, not from a counter: re-running
            # this for one opening must reproduce that opening's sheets and touch
            # no other, and a global counter would reshuffle every file after it.
            #
            # ⚠️ AND IT IS CRC32, NOT `hash()`. Python randomises string hashing
            # per PROCESS unless PYTHONHASHSEED is pinned, so the first version of
            # this line produced DIFFERENT ART ON EVERY RUN — caught by asking the
            # same expression twice in two interpreters (21240, then 67843). An
            # asset generator that cannot reproduce its own output is the B4
            # determinism failure this project bans, arriving through the standard
            # library's front door.
            seed = (zlib.crc32(o["id"].encode()) % 100000) * 10 + v
            generate(o, seed).save(os.path.join(args.out_dir, name))
            entries.append(name)
            print("wrote %s (seed %d, span %.1f x %.1f voxels)" % (name, seed, sx, sy))
        manifest[o["id"]] = {"span": [round(sx, 3), round(sy, 3)], "sheets": entries}

    if args.all:
        mpath = os.path.join(args.out_dir, "fracture_manifest.json")
        with open(mpath, "w") as f:
            json.dump({"variants": VARIANTS, "openings": manifest}, f, indent=1, sort_keys=True)
        print("wrote %s (%d openings x %d variants)" % (mpath, len(manifest), VARIANTS))
