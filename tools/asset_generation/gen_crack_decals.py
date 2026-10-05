#!/usr/bin/env python3
##
## gen_crack_decals.py — R3D-LOOK L1: the concrete and stone `crack` decals, redrawn to read on a LIGHT wall.
##
## WHY. Measured 2026-10-05 (decal composited over the wall's mean colour, mean relative luminance change over the voxel):
## concrete crack 1.6-2.1 %, stone crack 2.4-3.6 %, against 10-13 % for concrete's bullet marks. Thin, faint photographic
## fractures vanish in the facade texture. The new art keeps the same family and the same course-following wander as
## `gen_brick_decals.crack()` (it is imported, the shape logic is one), with a palette for a light wall: a dark line, a pale
## chipped lip, and a soft SHADOW haze that widens the readable mark.
##
## Writes decal_crack_{concrete,stone}_{0,1,2}.png (256x256 RGBA, ART_SPECIFICATIONS §7). Deterministic; OVERWRITES.
## Usage:  python3 tools/asset_generation/gen_crack_decals.py [--out-root DIR]
## Then:   python3 tools/persistent/check_decal.py --material concrete  (and stone), and reimport the project.

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_brick_decals import crack  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PALETTES = {
    "concrete": {"dark": (26, 26, 28), "lip": (228, 228, 224), "haze": (84, 84, 86)},
    "stone": {"dark": (22, 23, 28), "lip": (222, 224, 230), "haze": (78, 80, 88)},
}
## (seed, branches, haze strength) per variant; the seeds differ per material so the two never share a pattern.
VARIANTS = {
    "concrete": [(41, 5, 0.42), (42, 4, 0.46), (43, 6, 0.40)],
    "stone": [(51, 4, 0.44), (52, 6, 0.40), (53, 5, 0.46)],
}


def main() -> int:
    parser = argparse.ArgumentParser(description="R3D-LOOK L1: write the concrete and stone crack decals (see the header)")
    parser.add_argument("--out-root", default=str(ROOT / "ASSETS/materials"))
    args = parser.parse_args()
    for material, variants in VARIANTS.items():
        out = Path(args.out_root) / material / "decals"
        out.mkdir(parents=True, exist_ok=True)
        for n, (seed, branches, spread) in enumerate(variants):
            img = crack(seed, branches, spread, PALETTES[material])
            a = np.asarray(img)[..., 3]
            path = out / ("decal_crack_%s_%d.png" % (material, n))
            img.save(path, "PNG")
            print("%s  coverage %.0f %%  peak alpha %d" % (path.name, float((a > 13).mean()) * 100.0, int(a.max())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
