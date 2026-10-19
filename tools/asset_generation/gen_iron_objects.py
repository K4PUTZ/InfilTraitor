#!/usr/bin/env python3
##
## gen_iron_objects.py — the facade of IRON OBJECTS (bars, gratings, pipe plugs): the first SECONDARY material (Director, 2026-10-18:
## "materiais primarios -> objetos secundarios herdam os mesmos stats, mas tem uma textura particular"; MATERIALS_MASTER_PLAN §2b).
##
## `iron_bar` INHERITS `steel_dark` (every balance number, the family, the tags: a grenade, a shot, fire and support treat it as steel_dark) and
## owns its texture: forged iron, a slow mottle, hammer dents, pitting and rust flecks. ISOTROPIC on purpose: the facade is sampled in world space
## and MIRRORED (D34), so any directional streak becomes rings; and the surface is read at 16 px per voxel, so nothing finer than ~4 px survives.
## The colour is a target ALBEDO over the facade's mean (as the carpets and the industrial floors), lighter than steel_dark's flat 0.22 so the
## bars read under a warm fire light.
##
##     python3 tools/asset_generation/gen_iron_objects.py
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
##     python3 tools/persistent/check_facade.py ASSETS/materials/iron_bar/facade_iron_bar.png

import json
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_corporate_floors import H, MATERIALS, W, norm, save  # noqa: E402

PRIMARY = "steel_dark"
TARGET_ALBEDO = (0.36, 0.35, 0.36)


def _wrap_blur(a: np.ndarray, sigma: float) -> np.ndarray:
    return gaussian_filter(a, sigma, mode="wrap")


def iron(rng: np.random.Generator) -> np.ndarray:
    """Forged iron: a mottle of two scales, hammer dents (soft dark dishes with a light rim), pits and rust flecks."""
    img = np.full((H, W), 150.0)
    img += 14.0 * norm(_wrap_blur(rng.normal(size=(H, W)), 40))     # slow tone drift across a bar
    img += 9.0 * norm(_wrap_blur(rng.normal(size=(H, W)), 6))      # mottle at about half a voxel
    img += 5.0 * norm(_wrap_blur(rng.normal(size=(H, W)), 1.2))    # grain
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    dents = np.zeros((H, W))
    for _ in range(420):
        cx, cy, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(5.0, 11.0)
        dx = (xx - cx + W / 2) % W - W / 2
        dy = (yy - cy + H / 2) % H - H / 2
        d = np.sqrt(dx * dx + dy * dy) / r
        dents += np.where(d < 1.0, -(1.0 - d * d), 0.0) + np.where((d >= 1.0) & (d < 1.25), 0.35, 0.0)
    img += 16.0 * _wrap_blur(dents, 1.0)
    pits = (rng.random((H, W)) < 0.004).astype(float)
    img -= 55.0 * _wrap_blur(pits, 0.8) * 4.0
    rust = _wrap_blur((rng.random((H, W)) < 0.0015).astype(float), 3.0)
    img -= 38.0 * np.clip(rust / (rust.max() + 1e-9) * 2.0, 0.0, 1.0)
    return img


def main() -> int:
    img = iron(np.random.default_rng(4100))
    save("iron_bar", img)
    mean = float(np.clip(np.rint(img), 0, 255).mean())
    base = [round(min(1.0, t / (mean / 255.0)), 3) for t in TARGET_ALBEDO]
    row = {"id": "iron_bar", "inherits": PRIMARY, "family": "metal", "base_color": base, "pattern_algorithm": "flat",
           "has_facade": True, "facade_mean": round(mean, 1)}
    path = MATERIALS / "iron_bar" / "iron_bar.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(row, indent=2) + "\n")
    print("[IRON] iron_bar: inherits %s, mean %.1f, base_color %s -> %s" % (PRIMARY, mean, base, path.relative_to(MATERIALS.parent.parent)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
