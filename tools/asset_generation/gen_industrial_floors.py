#!/usr/bin/env python3
##
## gen_industrial_floors.py — the facades of the INDUSTRIAL floor set (SURFACES_CATALOG §2.4, Chapter 2: the Militia):
## `steel_plate` (diamond tread plate) and `grating` (open floor grating).
## (Hazard stripes were tried as a floor and removed: the shader MIRRORS the facade, so a 45 degree stripe becomes concentric rings. They are a
## MARKING patch, a strip along an edge: SURFACES_CATALOG §3.)
##
## Same rules as `gen_corporate_floors.py` (1024 x 512 grayscale, 16 px per voxel, mirrored, seeded, git-ignored PNGs reproducible from
## this file; a feature has to be 16 px or more to survive in play). Colour variants are JSON rows with `facade_from`, no PNG.
##
## GRATING is COSMETIC (Director 2026-10-06: the game is one storey, nobody is below or above, nothing passes through it, a shot
## never hits the floor). Its holes are dark here (looking down into a void). Showing something BELOW (water, lava, steam) needs the
## holes to be see-through and an underlay: not built, see SURFACES_CATALOG §5.
##
##     python3 tools/asset_generation/gen_industrial_floors.py
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import

import json
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_corporate_floors import H, MATERIALS, W, norm, save  # noqa: E402


def steel_plate(rng: np.random.Generator) -> np.ndarray:
    """Diamond tread plate: four raised lugs per 64 px cell, alternately turned +45 / -45 degrees, lit from the top left; plates of
    128 px (about 1 GU) with a seam; scratches and a slow wear mottle."""
    yy, xx = np.mgrid[0:H, 0:W].astype(float)

    def lugs(shift: float) -> np.ndarray:
        h = np.zeros((H, W))
        for (cx, cy, ang) in ((16, 16, 45.0), (48, 16, -45.0), (16, 48, -45.0), (48, 48, 45.0)):
            a = np.deg2rad(ang)
            dx = ((xx - shift) % 64) - cx
            dy = ((yy - shift) % 64) - cy
            dx = (dx + 32) % 64 - 32
            dy = (dy + 32) % 64 - 32
            u = dx * np.cos(a) + dy * np.sin(a)
            v = -dx * np.sin(a) + dy * np.cos(a)
            h = np.maximum(h, np.sqrt(np.clip(1.0 - (u / 14.0) ** 2 - (v / 4.5) ** 2, 0.0, 1.0)))
        return h
    img = 146.0 + 44.0 * lugs(0.0) - 30.0 * lugs(-2.5)         # the lug, and its shadow falling to the lower right
    img += 4.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 0.8))
    img += 7.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 30))
    scratches = np.zeros((H, W))
    for _ in range(260):
        x0, y0 = rng.integers(0, W), rng.integers(0, H)
        ln, ang = rng.integers(10, 60), rng.uniform(0, np.pi)
        for t in range(ln):
            x, y = int(x0 + t * np.cos(ang)) % W, int(y0 + t * np.sin(ang)) % H
            scratches[y, x] = rng.choice([-1.0, 1.0])
    img += 9.0 * gaussian_filter(scratches, 0.5) * 3.0
    seam = np.zeros((H, W))
    seam[::128, :] = 1.0
    seam[:, ::128] = 1.0
    seam[1::128, :] = 0.6
    seam[:, 1::128] = 0.6
    return img - 55.0 * seam


def grating(rng: np.random.Generator) -> np.ndarray:
    """Open floor grating: load bars 10 px wide every 32 px with a bevelled top, thinner cross bars, DARK holes between (the void
    below); a 6 px solid frame every 128 px that makes the panels."""
    yy, xx = np.mgrid[0:H, 0:W]
    px, py = xx % 32, yy % 32
    bar = (px < 10)                                    # load bars, along y
    cross = (py < 6) & ~bar                            # cross bars, lower and thinner
    d = np.minimum(np.abs(px - 5.0), 5.0)              # distance from the load bar's centre line
    bevel = 1.0 - (d / 5.0) ** 2
    img = np.full((H, W), 26.0)                        # the void
    img = np.where(cross, 138.0 + 14.0 * (1.0 - np.abs(py - 3.0) / 3.0), img)
    img = np.where(bar, 168.0 + 30.0 * bevel, img)
    fx, fy = xx % 128, yy % 128
    frame = (fx < 6) | (fy < 6)
    img = np.where(frame, 150.0 + 12.0 * ((fx < 3) | (fy < 3)), img)
    img += np.where(img > 60, 4.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 0.8)), 0.0)
    img += np.where(img > 60, 7.0 * norm(gaussian_filter(rng.normal(size=(H, W)), 24)), 0.0)
    return img


METAL = json.loads((MATERIALS / "metal" / "metal.json").read_text())

PATTERNS = {   # id -> (facade function, default colour, row overrides)
    "steel_plate": (steel_plate, "steel", {}),
    "grating": (grating, "steel", {"destroy_factor": 0.7, "dent_factor": 0.0}),    # a grenade may take a grating out (cosmetic hole)
}
COLOURS = {   # a target ALBEDO per colour, as the carpets
    "steel": (0.36, 0.38, 0.40),
    "dark": (0.14, 0.15, 0.17),
    "rust": (0.40, 0.21, 0.11),
    "green": (0.15, 0.30, 0.20),
    "yellow": (0.62, 0.50, 0.08),
}
VARIANTS = {   # pattern -> the colours it comes in besides its default
    "steel_plate": ["dark", "rust", "green"],
    "grating": ["dark", "rust", "yellow"],
}


def write_row(material: str, mean: float, colour: str, overrides: dict, facade_from: str = "") -> None:
    base = [round(min(1.0, t / (mean / 255.0)), 2) for t in COLOURS[colour]]
    row = {"id": material, "family": "metal", "tags": ["metal", "industrial"], "destroy_factor": METAL["destroy_factor"],
           "dent_factor": METAL["dent_factor"], "crack_factor": METAL["crack_factor"], "flammability": 0.0, "base_color": base,
           "pattern_algorithm": "flat", "has_facade": True, "smoke_chance": METAL["smoke_chance"]}
    row.update(overrides)
    if facade_from:
        row["facade_from"] = facade_from
    path = MATERIALS / material / ("%s.json" % material)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(row, indent=2) + "\n")


def main() -> int:
    for seed, (name, (fn, default, overrides)) in enumerate(PATTERNS.items()):
        img = fn(np.random.default_rng(3000 + seed))
        save(name, img)
        mean = float(np.clip(img, 0, 255).mean())
        write_row(name, mean, default, overrides)
        for colour in VARIANTS[name]:
            write_row("%s_%s" % (name, colour), mean, colour, overrides, facade_from=name)
        print("[INDUSTRIAL] %s: default %s + %s" % (name, default, VARIANTS[name]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
