#!/usr/bin/env python3
"""
d33_part3c_fixture_gen.py — D33 Part 3c (floor-sunk DENTED) equality-proof
fixtures. Same discipline as Parts 2/3b: real, unmodified generate_voxel.py
functions, not a reimplementation.

Run from repo root:
    python3 tools/asset_generation/d33_part3c_fixture_gen.py

Writes to godot/scripts/tools/fixtures/d33_part3c/:
    atom.png             — generate_voxel_atom(concrete) — the "kept" substrate
    half_top.png          — generate_half_voxel(concrete, "top")
    decal.png             — same synthetic soft-edged decal as Parts 2/3b
    composited_top.png    — compose_decal_voxel(half_top, decal, [_FACE_SUNK_TOP])
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image

import generate_voxel as gv

FIXTURE_DIR = Path("godot/scripts/tools/fixtures/d33_part3c")


def make_decal() -> Image.Image:
    size = gv.DECAL_AUTHOR_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size / 2.0
    radius = size * 0.45
    edge = size * 0.08
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist >= radius + edge:
                alpha = 0
            elif dist <= radius - edge:
                alpha = 255
            else:
                t = (radius + edge - dist) / (2.0 * edge)
                alpha = max(0, min(255, int(round(t * 255))))
            if alpha > 0:
                px[x, y] = (x % 256, y % 256, 128, alpha)
    return img


def main() -> None:
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)

    concrete = gv.MATERIALS["concrete"]
    atom = gv.generate_voxel_atom(concrete)
    half_top = gv.generate_half_voxel(concrete, "top")
    decal = make_decal()

    composited_top = gv.compose_decal_voxel(half_top, decal, [gv._FACE_SUNK_TOP])

    atom.save(FIXTURE_DIR / "atom.png", "PNG")
    half_top.save(FIXTURE_DIR / "half_top.png", "PNG")
    decal.save(FIXTURE_DIR / "decal.png", "PNG")
    composited_top.save(FIXTURE_DIR / "composited_top.png", "PNG")

    print(f"Wrote fixtures to {FIXTURE_DIR}/:")
    for name in ["atom.png", "half_top.png", "decal.png", "composited_top.png"]:
        print(f"  {name}")

    d = gv.DENTED_CUT_DEPTH
    print("\nGeometry used (must match the GDScript port exactly):")
    print(f"  DENTED_CUT_DEPTH = {d}")
    print(f"  _FACE_SUNK_TOP   = {gv._FACE_SUNK_TOP}")
    print(f"  top-tone fill (base_color) = {gv._rgba(concrete)}")


if __name__ == "__main__":
    main()
