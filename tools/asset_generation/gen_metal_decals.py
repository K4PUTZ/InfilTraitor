#!/usr/bin/env python3
##
## gen_metal_decals.py — R3D-LOOK L1, option A (PROMPTS/PROPOSAL_METAL_WOOD_DAMAGE_VARIANTS.md): the six metal decals, each variant a
## different EVENT rather than a rotated copy.
##
##   bullet 0  clean puncture: a dark hole inside a ring of bent petals (the plate's torn lips), a soot halo
##   bullet 1  graze / ricochet: an elongated gouge with a bright scraped streak and fine parallel scratches
##   bullet 2  puncture with the paint flaked off around it: bare bright steel with a rusty-orange edge
##   dent   0  buckle: a shallow dish with a lit upper lip and a shaded lower one, and a crease
##   dent   1  crumple: a fan of folded ridges, light and dark in turn
##   dent   2  blast bloom: a dish inside a soot ring that shades to heat tint (straw, then blue)
##
## The colour and grain of the metal come from a CC0 photo crop (Metal053C, docs/PHOTO_SOURCES.md, the same `photo_fill()` as the stone
## decals) mixed toward bare steel; the shapes, the alpha and the shading are procedural. The canvas-border alpha is checked
## (gen_brick_decals.edge_report). Deterministic; OVERWRITES. Usage: python3 tools/asset_generation/gen_metal_decals.py [--out DIR]
## Then: python3 tools/persistent/check_decal.py --material metal   and reimport.

import argparse
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_brick_decals as g  # noqa: E402

N, SS = g.N, g.SS
STEEL = np.array([188.0, 194.0, 202.0])
BARE = np.array([226.0, 230.0, 236.0])
RUST = np.array([176.0, 92.0, 48.0])


def mask_from(draw_fn) -> np.ndarray:
    img = Image.new("L", (N * SS, N * SS), 0)
    draw_fn(ImageDraw.Draw(img))
    return np.asarray(img.resize((N, N), Image.LANCZOS), dtype=float) / 255.0


def blur(a: np.ndarray, r: float) -> np.ndarray:
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), dtype=float) / 255.0


def mix(base: np.ndarray, colour, amount: np.ndarray) -> np.ndarray:
    return base * (1.0 - amount[..., None]) + np.asarray(colour, dtype=float) * amount[..., None]


def metal_body(rng: np.random.Generator, seed: int, steel_share: float = 0.6) -> np.ndarray:
    """The photo's colour and grain, pulled toward bare steel."""
    photo = g.photo_fill(rng, "bullet", seed)
    if photo is None:
        photo = STEEL + (rng.random((N, N, 3)) - 0.5) * 30.0
    grain = (g.fbm(rng, N, 5, 6) - 0.5)[..., None] * 40.0
    return np.clip(photo * (1.0 - steel_share) + STEEL * steel_share + grain, 0, 255)


def hole(rng: np.random.Generator, cx: float, cy: float, r: float, rough: float = 0.25) -> np.ndarray:
    ys, xs = np.mgrid[0:N, 0:N]
    d = np.hypot((xs - cx) / N, (ys - cy) / N)
    ang = np.arctan2(ys - cy, xs - cx)
    wob = 1.0 + rough * (g.fbm(rng, N, 4, 4) - 0.5) * 2.0 + 0.08 * np.sin(ang * 5 + 1.0)
    return r * wob - d


def bullet_puncture(seed: int) -> Image.Image:
    seed += g.SEED_OFFSET
    rng = np.random.default_rng(seed)
    r = random.Random(seed)
    c = N / 2.0
    body = metal_body(rng, seed)
    petals = r.randint(6, 8)
    r0, r1 = 0.075 * N, 0.20 * N
    base_a = r.uniform(0, math.tau)

    cs = c * SS

    def petal_poly(k: int) -> list:
        a = base_a + k * math.tau / petals + r.uniform(-0.12, 0.12)
        w = math.tau / petals * 0.46
        tip = r1 * r.uniform(0.75, 1.15)
        bend = r.uniform(-0.25, 0.25)
        return [(cs + math.cos(a - w) * r0 * SS, cs + math.sin(a - w) * r0 * SS), (cs + math.cos(a + w) * r0 * SS, cs + math.sin(a + w) * r0 * SS),
                (cs + math.cos(a + bend) * tip * SS, cs + math.sin(a + bend) * tip * SS)]

    polys = [petal_poly(k) for k in range(petals)]
    petal_m = mask_from(lambda d: [d.polygon(poly, fill=255) for poly in polys])
    lit_m = mask_from(lambda d: [d.polygon([poly[0], poly[2], ((poly[0][0] + poly[1][0]) / 2, (poly[0][1] + poly[1][1]) / 2)], fill=255) for poly in polys])
    hole_f = hole(rng, c, c, 0.075, 0.22)
    hole_a = g.feather(hole_f, 0.012)
    ring = g.feather(hole(rng, c, c, 0.115, 0.3), 0.02)
    halo = g.feather(hole(rng, c, c, 0.27, 0.35), 0.12)
    rgb = body
    rgb = mix(rgb, g.RIM, np.clip(ring - hole_a, 0, 1) * 0.55)
    rgb = mix(rgb, BARE, lit_m * 0.7)
    rgb = mix(rgb, g.DARK, hole_a)
    alpha = np.maximum.reduce([petal_m * 0.96, halo * 0.30, ring * 0.7, hole_a])
    return g.compose(rgb, alpha)


def bullet_graze(seed: int) -> Image.Image:
    seed += g.SEED_OFFSET
    rng = np.random.default_rng(seed)
    r = random.Random(seed)
    c = N / 2.0
    ang = r.uniform(-0.5, 0.5)
    body = metal_body(rng, seed, 0.7)
    ca, sa = math.cos(ang), math.sin(ang)
    ys, xs = np.mgrid[0:N, 0:N]
    u = ((xs - c) * ca + (ys - c) * sa) / N
    v = (-(xs - c) * sa + (ys - c) * ca) / N
    wob = (g.fbm(rng, N, 5, 4) - 0.5) * 0.06
    gouge = 1.0 - np.sqrt((u / 0.40) ** 2 + ((v + wob) / (0.10 * (1.0 - 0.45 * np.clip((u + 0.34) / 0.68, 0, 1)))) ** 2)
    gouge_a = g.feather(gouge * 0.10, 0.02)
    streak = np.exp(-((v + wob * 0.5) / 0.012) ** 2) * (np.abs(u) < 0.42)
    scr = np.zeros((N, N))
    for k in range(7):
        off = r.uniform(-0.07, 0.07)
        ln = r.uniform(0.18, 0.36)
        scr += np.exp(-((v - off) / 0.0045) ** 2) * ((u > -ln * 0.5) & (u < ln)) * r.uniform(0.4, 0.9)
    pit = g.feather(hole(rng, c - ca * 0.28 * N, c - sa * 0.28 * N, 0.045, 0.3), 0.012)
    rgb = mix(body, g.RIM, g.feather(gouge * 0.10, 0.05) * 0.5)
    rgb = mix(rgb, BARE, np.clip(streak * 0.9 + scr * 0.6, 0, 1))
    rgb = mix(rgb, g.DARK, pit)
    alpha = np.maximum.reduce([gouge_a * 0.92, np.clip(streak, 0, 1) * 0.9, np.clip(scr, 0, 1) * 0.7, pit, blur(gouge_a, 6) * 0.25])
    return g.compose(rgb, alpha)


def bullet_flaked(seed: int) -> Image.Image:
    seed += g.SEED_OFFSET
    rng = np.random.default_rng(seed)
    c = N / 2.0
    body = metal_body(rng, seed, 0.2)
    flake = hole(rng, c, c, 0.25, 0.5)
    flake_a = g.feather(flake, 0.03)
    edge = np.clip(g.feather(flake, 0.03) - g.feather(hole(rng, c, c, 0.20, 0.5), 0.05), 0, 1)
    bare = g.feather(hole(rng, c, c, 0.20, 0.5), 0.05)
    hole_f = hole(rng, c, c, 0.07, 0.2)
    hole_a = g.feather(hole_f, 0.012)
    ring = g.feather(hole(rng, c, c, 0.11, 0.3), 0.02)
    rgb = mix(body, RUST, edge * 0.8)
    rgb = mix(rgb, BARE, bare * 0.85)
    rgb = mix(rgb, g.RIM, np.clip(ring - hole_a, 0, 1) * 0.6)
    rgb = mix(rgb, g.DARK, hole_a)
    alpha = np.maximum.reduce([flake_a * 0.92, hole_a, blur(flake_a, 7) * 0.3])
    return g.compose(rgb, alpha)


def dent_dish(seed: int, kind: str) -> Image.Image:
    seed += g.SEED_OFFSET
    rng = np.random.default_rng(seed)
    r = random.Random(seed)
    c = N / 2.0
    body = metal_body(rng, seed, 0.75)
    ys, xs = np.mgrid[0:N, 0:N]
    ang = r.uniform(0, math.tau)
    ca, sa = math.cos(ang), math.sin(ang)
    u = ((xs - c) * ca + (ys - c) * sa) / N
    v = (-(xs - c) * sa + (ys - c) * ca) / N
    if kind == "buckle":
        shape = hole(rng, c, c, 0.30, 0.18) * (1.0 + 0.0 * u)
        area = g.feather(shape, 0.07)
        ## light on the upper-left lip, shade on the lower-right: the dish reads as concave
        lit = np.clip(-(u + v) / 0.3, 0, 1) * np.clip(1.0 - np.abs(shape) / 0.09, 0, 1)
        shade = np.clip((u + v) / 0.3, 0, 1) * np.clip(1.0 - np.abs(shape) / 0.09, 0, 1)
        crease = np.zeros((N, N))
        rgb = mix(body, g.RIM, shade * 0.7 + np.clip(crease, 0, 1) * 0.5)
        rgb = mix(rgb, BARE, lit * 0.85)
        alpha = area * 0.74 * np.clip(0.9 + 0.1 * g.fbm(rng, N, 3, 4), 0, 1)
    elif kind == "crumple":
        shape = hole(rng, c, c, 0.30, 0.3)
        area = g.feather(shape, 0.07)
        wave = np.sin((v + 0.06 * np.sin(u * 8)) * 2 * math.pi / 0.11 + (u * 3))
        light = np.clip(wave, 0, 1) ** 2
        dark = np.clip(-wave, 0, 1) ** 2
        rgb = mix(body, g.RIM, dark * 0.75)
        rgb = mix(rgb, BARE, light * 0.8)
        alpha = area * 0.8
    else:  ## bloom
        shape = hole(rng, c, c, 0.30, 0.14)
        area = g.feather(shape, 0.08)
        ys2, xs2 = np.mgrid[0:N, 0:N]
        d = np.hypot((xs2 - c) / N, (ys2 - c) / N)
        rr = d / 0.30
        soot = np.clip(1.0 - np.abs(rr - 0.62) / 0.28, 0, 1)
        heat = np.clip(1.0 - np.abs(rr - 0.9) / 0.22, 0, 1)
        dish = np.clip(1.0 - rr, 0, 1)
        straw = np.array([196.0, 160.0, 86.0])
        blue = np.array([88.0, 100.0, 160.0])
        rgb = mix(body, blue, heat * 0.55)
        rgb = mix(rgb, straw, np.clip(heat * 0.5 * (rr < 0.95), 0, 1))
        rgb = mix(rgb, np.array([30.0, 26.0, 24.0]), soot * 0.85)
        rgb = mix(rgb, BARE, np.clip(np.clip(-(u + v) / 0.25, 0, 1) * dish * 0.5, 0, 1))
        alpha = area * 0.82
    return g.compose(rgb, alpha)


SPECS = {
    "bullet": [lambda: bullet_puncture(11), lambda: bullet_graze(12), lambda: bullet_flaked(13)],
    "dent": [lambda: dent_dish(31, "buckle"), lambda: dent_dish(32, "crumple"), lambda: dent_dish(33, "bloom")],
}


def main() -> int:
    parser = argparse.ArgumentParser(description="R3D-LOOK L1: write the six metal damage decals (see the header)")
    parser.add_argument("--out", default=str(g.ROOT / "ASSETS/materials/metal/decals"))
    args = parser.parse_args()
    g.use("metal")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for family, makers in SPECS.items():
        for variant, make in enumerate(makers):
            img = make()
            a = np.asarray(img)[..., 3]
            path = out / ("decal_%s_metal_%d.png" % (family, variant))
            img.save(path, "PNG")
            print("%s  coverage %.0f %%  peak alpha %d" % (path.name, float((a > 13).mean()) * 100.0, int(a.max())))
            g.edge_report(path.name, a.astype(float) / 255.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
