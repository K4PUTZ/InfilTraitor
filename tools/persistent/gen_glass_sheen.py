#!/usr/bin/env python3
##
## gen_glass_sheen.py — writes `ASSETS/materials/glass/glass_sheen.png`, the glass pane's look as a TEXTURE (2026-10-09, Director).
##
## The pane is drawn in ONE premultiplied-alpha pass (`glass_pane3d.gdshader`): out = behind x (1 - alpha) + reflection. This texture
## holds both, in GRAYSCALE (B2: the colour is the material's `glass_tint` uniform, so the armoured pane and the coloured screens keep
## their own tint from the same art):
##   L (luminance) = the reflection: the diagonal sheen band the two-pass pane computed with a sine (`glass_sheen_srgb()`), 0..1.
##   A (alpha)     = how much the pane covers what is behind it, as a multiplier of the shader's `glass_cover` (255 = 1.0).
## It is sampled in WORLD (screen-axis) coordinates, one tile = one period of the sheen, so the band runs across a whole pane with
## no seam at a voxel or a chunk. This is a first, generated version: an artist may replace it with the same layout (square,
## tileable in both axes, grayscale + alpha) and nothing else changes.
##
##     python3 tools/persistent/gen_glass_sheen.py            # then focus Godot (or `godot --headless --import`) to import it

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ASSETS" / "materials" / "glass" / "glass_sheen.png"
SIZE = 512
SHARPNESS = 0.74   ## the two-pass pane's `glass_sheen_sharpness`
COVER = 1.0        ## a flat cover: the dial is the shader's `glass_cover`


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> int:
    from PIL import Image
    lo = 0.30 + (0.92 - 0.30) * SHARPNESS
    img = Image.new("LA", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            ## one period along (u + v): tileable in u and in v
            s = math.sin(2.0 * math.pi * (x + y) / SIZE) * 0.5 + 0.5
            px[x, y] = (int(round(255 * smoothstep(lo, 1.0, s))), int(round(255 * COVER)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("[GLASS-SHEEN] wrote %s (%dx%d, LA)" % (OUT.relative_to(ROOT), SIZE, SIZE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
