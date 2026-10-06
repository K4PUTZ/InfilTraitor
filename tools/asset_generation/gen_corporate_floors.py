#!/usr/bin/env python3
##
## gen_corporate_floors.py — the three facades of the CORPORATE floor set (SURFACES_CATALOG §2.3, Chapter 1: the Agency):
## `carpet` (office carpet tiles), `parquet` (herringbone) and `tile` (square tiles with grout).
##
## A facade is 1024 x 512 GRAYSCALE at 16 texels per voxel (1 GU = 128 px, the plane is 8 x 4 GU and the shader mirrors it, so no
## border has to match), multiplied by the material's `base_color`; it serves the material's walls, roofs AND floors. These are
## generated procedurally with a fixed seed, so the (git-ignored) PNGs are reproducible from this file alone. The scales are physical:
## 1 GU is about 1.0-1.1 m (the Director's scale rule), so a 64 px carpet tile or ceramic tile is half a GU (~0.5 m) and a herringbone
## plank is 96 x 24 px (~0.75 x 0.19 m).
##
## It also writes the three material rows (`ASSETS/materials/<id>/<id>.json`, tracked) when they do not exist. Run, then reimport:
##     python3 tools/asset_generation/gen_corporate_floors.py
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
##     python3 tools/persistent/check_facade.py --all

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = Path(__file__).resolve().parents[2]
MATERIALS = ROOT / "ASSETS" / "materials"
W, H = 1024, 512


def norm(a: np.ndarray) -> np.ndarray:
    """Zero mean, unit standard deviation."""
    return (a - a.mean()) / (a.std() + 1e-9)


def save(material: str, gray: np.ndarray) -> None:
    out = MATERIALS / material / ("facade_%s.png" % material)
    out.parent.mkdir(parents=True, exist_ok=True)
    g = np.clip(np.rint(gray), 0, 255).astype(np.uint8)
    Image.fromarray(np.stack([g, g, g], axis=-1), "RGB").save(out)
    print("[CORPORATE] %s: mean %.0f std %.1f min %d max %d -> %s" % (material, g.mean(), g.std(), g.min(), g.max(), out.relative_to(ROOT)))


def carpet(rng: np.random.Generator) -> np.ndarray:
    """Office carpet tiles, 64 px (~0.5 m) squares: a fine weave, a slow mottle, a faint seam and a per-tile tone and pile direction."""
    weave = gaussian_filter(rng.normal(size=(H, W)), 0.7)
    weave_t = gaussian_filter(rng.normal(size=(W, H)), 0.7).T      # a second weave: half the tiles lie the other way
    tufts = ((np.arange(W)[None, :] // 2 + np.arange(H)[:, None] // 2) % 2).astype(float)
    mottle = norm(gaussian_filter(rng.normal(size=(H, W)), 22))
    img = np.full((H, W), 148.0)
    img += 7.0 * norm(weave) + 3.0 * (tufts - 0.5) + 6.0 * mottle
    ts = 64
    for ty in range(H // ts):
        for tx in range(W // ts):
            sl = (slice(ty * ts, (ty + 1) * ts), slice(tx * ts, (tx + 1) * ts))
            img[sl] += rng.normal(0.0, 3.5)
            if rng.random() < 0.5:
                img[sl] += 7.0 * (norm(weave_t)[sl] - norm(weave)[sl])
    seam = np.zeros((H, W))
    seam[:, ::ts] = 1.0
    seam[:, 1::ts] = 0.6
    seam[::ts, :] = np.maximum(seam[::ts, :], 1.0)
    seam[1::ts, :] = np.maximum(seam[1::ts, :], 0.6)
    img -= 15.0 * seam
    return img


def tile(rng: np.random.Generator) -> np.ndarray:
    """Square ceramic tiles, 64 px (~0.5 m) with a 5 px grout line, a small bevel and a gentle tone drift per tile."""
    ts, grout = 64, 5
    img = np.full((H, W), 205.0)
    img += 2.2 * norm(gaussian_filter(rng.normal(size=(H, W)), 1.3))
    img += 5.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 40))
    yy, xx = np.mgrid[0:H, 0:W]
    ty, tx = yy % ts, xx % ts
    in_grout = (ty < grout) | (tx < grout)
    for j in range(H // ts):
        for i in range(W // ts):
            img[j * ts:(j + 1) * ts, i * ts:(i + 1) * ts] += rng.normal(0.0, 4.0)
    bevel = np.zeros((H, W))
    bevel[(ty == grout) | (ty == grout + 1) & False] = 0.0
    bevel[(ty == grout) & ~in_grout] += 1.0            # the top and left rim catches light
    bevel[(tx == grout) & ~in_grout] += 1.0
    bevel[(ty == ts - 1) & ~in_grout] -= 1.0           # the bottom and right rim falls away
    bevel[(tx == ts - 1) & ~in_grout] -= 1.0
    img += 11.0 * bevel
    grout_tone = 112.0 + 7.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 0.9))
    return np.where(in_grout, grout_tone, img)


def parquet(rng: np.random.Generator) -> np.ndarray:
    """Herringbone: planks 96 x 24 px (4:1), laid at right angles. Two staircases of planks, a horizontal one and a vertical one,
    interleave; the lattice (-4, 4) plank-widths repeats it with no gap and no overlap (checked by brute force before this was written).
    Each plank has its own tone, a grain running along its length and a dark gap at its edge."""
    b, n = 24, 4
    L = b * n
    plank_tone = np.zeros((H, W))
    edge = np.zeros((H, W))
    horizontal = np.zeros((H, W), bool)
    covered = np.zeros((H, W), bool)
    t1 = (-n, n)

    def put(x0: int, y0: int, w: int, h: int, tone: float, is_h: bool) -> None:
        xs0, xs1 = max(x0, 0), min(x0 + w, W)
        ys0, ys1 = max(y0, 0), min(y0 + h, H)
        if xs0 >= xs1 or ys0 >= ys1:
            return
        sl = (slice(ys0, ys1), slice(xs0, xs1))
        plank_tone[sl] = tone
        horizontal[sl] = is_h
        covered[sl] = True
        e = np.zeros((ys1 - ys0, xs1 - xs0))
        e[:2, :] = 1.0
        e[-2:, :] = 1.0
        e[:, :2] = 1.0
        e[:, -2:] = 1.0
        # only the edges that are real plank edges (not the canvas border) count
        if y0 < 0:
            e[:2, :] = 0.0
        if x0 < 0:
            e[:, :2] = 0.0
        edge[sl] = e

    for m in range(-14, 15):
        for k in range(-60, 61):
            ox, oy = k + m * t1[0], k + m * t1[1]
            tone = float(rng.choice([-16, -9, -3, 4, 10, 17]))
            put(ox * b, oy * b, L, b, tone, True)
            tone = float(rng.choice([-16, -9, -3, 4, 10, 17]))
            put((ox + n) * b, (oy - n + 1) * b, b, L, tone, False)
    grain_h = norm(gaussian_filter(rng.normal(size=(H, W)), (1.3, 22)))     # streaks along x
    grain_v = norm(gaussian_filter(rng.normal(size=(H, W)), (22, 1.3)))     # streaks along y
    fine = norm(gaussian_filter(rng.normal(size=(H, W)), 0.8))
    img = 150.0 + plank_tone + 8.0 * np.where(horizontal, grain_h, grain_v) + 3.0 * fine
    img -= 48.0 * edge
    if not covered.all():
        print("[CORPORATE] parquet: %d uncovered pixel(s)" % int((~covered).sum()))
        img[~covered] = 90.0
    return img


# ── carpet LAB (2026-10-06): patterns at the scale that reads in play (a voxel is ~12 px on screen at zoom 1, so a feature has to be
# 16 px or more; the 7 px weave of `carpet` vanishes). Each has its own facade and colour; the Director keeps what he likes. ──

def _weave(rng: np.random.Generator, amp: float = 5.0) -> np.ndarray:
    return amp * norm(gaussian_filter(rng.normal(size=(H, W)), 0.8))


def carpet_plain(rng):
    """Plain loop pile: a bolder mottle and a clear tone step between the 64 px tiles."""
    img = 150.0 + _weave(rng) + 9.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 20))
    for ty in range(H // 64):
        for tx in range(W // 64):
            img[ty * 64:(ty + 1) * 64, tx * 64:(tx + 1) * 64] += rng.choice([-11.0, -4.0, 4.0, 11.0])
    return _seams(img)


def _seams(img: np.ndarray, depth: float = 22.0) -> np.ndarray:
    seam = np.zeros((H, W))
    seam[:, ::64] = 1.0
    seam[::64, :] = 1.0
    seam[:, 1::64] = np.maximum(seam[:, 1::64], 0.5)
    seam[1::64, :] = np.maximum(seam[1::64, :], 0.5)
    return img - depth * seam


def carpet_stripe(rng):
    """Ribs 16 px (one voxel) wide, every 64 px tile turned a quarter from its neighbour (the 'monolithic' carpet-tile look)."""
    yy, xx = np.mgrid[0:H, 0:W]
    img = np.full((H, W), 150.0) + _weave(rng, 4.0)
    for ty in range(H // 64):
        for tx in range(W // 64):
            sl = (slice(ty * 64, (ty + 1) * 64), slice(tx * 64, (tx + 1) * 64))
            across = (xx[sl] if (tx + ty) % 2 == 0 else yy[sl])
            img[sl] += np.where((across // 16) % 2 == 0, 16.0, -16.0) + rng.normal(0.0, 3.0)
    return _seams(img)


def carpet_basket(rng):
    """Basket weave: 32 px blocks of 8 px ribs, alternating direction — fine at a distance, a texture up close."""
    yy, xx = np.mgrid[0:H, 0:W]
    block = ((xx // 32) + (yy // 32)) % 2 == 0
    ribs = np.where(block, (xx // 8) % 2, (yy // 8) % 2).astype(float) - 0.5
    img = 150.0 + 20.0 * ribs + 10.0 * (block.astype(float) - 0.5) + _weave(rng, 4.0) + 6.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 18))
    return _seams(img, 14.0)


def carpet_diamond(rng):
    """A jacquard lattice: lighter diamonds, 64 px across, on a darker field — the corporate lobby look."""
    yy, xx = np.mgrid[0:H, 0:W]
    dx = np.abs((xx % 64) - 32).astype(float)
    dy = np.abs((yy % 64) - 32).astype(float)
    d = dx + dy
    motif = np.clip((26.0 - d) / 6.0, 0.0, 1.0)                    # the big diamond
    small = np.clip((8.0 - np.abs(((xx + 32) % 64) - 32) - np.abs(((yy + 32) % 64) - 32)) / 3.0, 0.0, 1.0)  # a dot where four meet
    img = 138.0 + 26.0 * motif + 14.0 * small + _weave(rng, 4.5) + 5.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 16))
    return img


def carpet_check(rng):
    """Two-tone checker of 32 px squares inside 64 px tiles: a calm geometric field."""
    yy, xx = np.mgrid[0:H, 0:W]
    chk = (((xx // 32) + (yy // 32)) % 2).astype(float) - 0.5
    img = 150.0 + 24.0 * chk + _weave(rng, 4.5) + 5.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 20))
    return _seams(img, 12.0)


# The patterns (each owns ONE facade) and the colours they come in. A colour is a target ALBEDO (what the floor should read as); the
# row's `base_color` is that divided by the facade's mean, so every pattern in every colour lands on the same brightness. A pattern's
# own material (`carpet_stripe`) wears its default colour; the others are `carpet_<pattern>_<colour>`, a JSON row with `facade_from`
# and no PNG of its own.
CARPET_PATTERNS = {            # id -> (facade function, default colour)
    "carpet_plain": (carpet_plain, "blue"),
    "carpet_stripe": (carpet_stripe, "red"),
    "carpet_basket": (carpet_basket, "navy"),
    "carpet_diamond": (carpet_diamond, "green"),
    "carpet_check": (carpet_check, "tan"),
}
CARPET_COLOURS = {
    "red": (0.42, 0.11, 0.13),     # burgundy
    "blue": (0.30, 0.36, 0.46),    # slate blue
    "navy": (0.18, 0.22, 0.36),
    "grey": (0.40, 0.40, 0.42),
    "green": (0.15, 0.30, 0.22),   # forest
    "tan": (0.52, 0.44, 0.31),
}


def write_carpet_row(material: str, mean: float, target: tuple, facade_from: str = "") -> None:
    path = MATERIALS / material / ("%s.json" % material)
    base = [round(min(1.0, t / (mean / 255.0)), 2) for t in target]
    row = {"id": material, **ROWS["carpet"], "base_color": base, "pattern_algorithm": "flat", "has_facade": True}
    order = ["id", "family", "tags", "destroy_factor", "dent_factor", "crack_factor", "flammability", "base_color",
             "pattern_algorithm", "has_facade", "burn_consumption", "smoke_chance"]
    out = {k: row[k] for k in order}
    if facade_from:
        out["facade_from"] = facade_from
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(out, indent=2) + "\n")


ROWS = {
    "carpet": {"family": "fabric", "tags": ["fabric", "indoor"], "destroy_factor": 0.95, "dent_factor": 0.0, "crack_factor": 0.0,
               "flammability": 0.6, "base_color": [0.46, 0.52, 0.62], "burn_consumption": 1.0, "smoke_chance": 0.1},
    "parquet": {"family": "wood", "tags": ["wood", "indoor"], "destroy_factor": 0.75, "dent_factor": 0.2, "crack_factor": 0.0,
                "flammability": 1.4, "base_color": [0.80, 0.58, 0.38], "burn_consumption": 0.2, "smoke_chance": 0.3},
    "tile": {"family": "ceramic", "tags": ["tile", "indoor"], "destroy_factor": 0.9, "dent_factor": 0.0, "crack_factor": 0.0,
             "flammability": 0.0, "base_color": [0.93, 0.92, 0.88], "burn_consumption": 0.0, "smoke_chance": 0.05},
}


def write_row(material: str) -> None:
    path = MATERIALS / material / ("%s.json" % material)
    if path.exists():
        print("[CORPORATE] %s row exists, kept" % path.relative_to(ROOT))
        return
    row = {"id": material, **ROWS[material], "pattern_algorithm": "flat", "has_facade": True}
    # key order of the existing rows
    order = ["id", "family", "tags", "destroy_factor", "dent_factor", "crack_factor", "flammability", "base_color",
             "pattern_algorithm", "has_facade", "burn_consumption", "smoke_chance"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({k: row[k] for k in order}, indent=2) + "\n")
    print("[CORPORATE] wrote %s" % path.relative_to(ROOT))


def main() -> int:
    for seed, (name, fn) in enumerate([("carpet", carpet), ("tile", tile), ("parquet", parquet)]):
        save(name, fn(np.random.default_rng(1000 + seed)))
        write_row(name)
    for seed, (name, (fn, default_colour)) in enumerate(CARPET_PATTERNS.items()):
        img = fn(np.random.default_rng(2000 + seed))
        save(name, img)
        mean = float(np.clip(img, 0, 255).mean())
        for colour, target in CARPET_COLOURS.items():
            if colour == default_colour:
                write_carpet_row(name, mean, target)
            else:
                write_carpet_row("%s_%s" % (name, colour), mean, target, facade_from=name)
        print("[CORPORATE] %s: facade mean %.0f, default colour %s, %d colour variant(s)" % (name, mean, default_colour, len(CARPET_COLOURS) - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
