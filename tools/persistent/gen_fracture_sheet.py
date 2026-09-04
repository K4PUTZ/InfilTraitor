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
  5. the hole      — the bullet's own crush rim, sized in VOXELS per G-D14

⚠️ There are exactly TWO sheets and there is no third (G-D14 / G-D21, and
`check_decal.py` enforces the two names). Within the rifle class the ENGINE
destroys 2-4 voxels; the art does not grow a variant for each. So all the
variation a player ever sees comes from inside these two images plus G-D21's
per-impact re-anchoring — which is why this file works as hard as it does at
breaking its own symmetry.

    python3 gen_fracture.py tight out.png [seed]
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
}

# How many voxels of PAGE per voxel of hole DIAMETER. Ratified by looking:
# `SHEET_SCALE` 1.4 on the old (20 voxel page / 3.4 voxel hole) is ~8.2, and the
# Director picked that from the 1.0 / 1.4 / 1.8 strip.
SPAN_RATIO = 8.2

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
    quad the sprite builds and the page the art was drawn on cannot disagree."""
    d = opening["r_max"] * 2.0
    return (d * SPAN_RATIO, d * SPAN_RATIO / 2.0)


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

    def hole_at(ang):
        """The opening's boundary along `ang`, in page pixels. This replaces the
        single `hole` radius: a crack starts where the glass actually ends."""
        t = (ang % (2.0 * math.pi)) / (2.0 * math.pi) * n_r
        i0 = int(t) % n_r
        i1 = (i0 + 1) % n_r
        f = t - int(t)
        return (radii[i0] * (1.0 - f) + radii[i1] * f) * px_per_voxel

    # A representative radius, for the routines that want one scalar (the speck
    # and stub falloffs). The MEAN, not the max: the max is one spike's tip and
    # would push every speck out past the whole web.
    hole = (sum(radii) / float(n_r)) * px_per_voxel

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

    for pts in paths[:len(angs)]:
        _stroke(d, pts, rng.randint(210, 255), rng.uniform(2.4, 4.0))
    for pts in paths[len(angs):]:
        _stroke(d, pts, rng.randint(150, 210), rng.uniform(1.4, 2.4))

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

    # 5. THE HOLE. The impact voxel is DESTROYED by G3 and stops rendering
    #    (order section 1.2), so what has to read is the crush RIM around it:
    #    a bright ragged lip, with the bore itself black.
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

    img = img.filter(ImageFilter.GaussianBlur(0.55 * SS))
    img = img.resize((W, H), Image.LANCZOS)
    return img.convert("RGB")          # R == G == B, invariant B2


GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
DUMPER = "godot/scripts/tools/dump_glass_openings.gd"


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

    openings = load_openings(args.project)
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
