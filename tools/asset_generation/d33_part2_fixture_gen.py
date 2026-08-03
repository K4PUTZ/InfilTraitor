#!/usr/bin/env python3
"""
d33_part2_fixture_gen.py — D33 Part 2 equality-proof fixtures.

Not a generator the pipeline runs normally — a ONE-SHOT tool that produces
the fixed (substrate, decal, reference-output) triple the GDScript port's
selftest compares against. Uses the REAL generate_voxel.py functions
(_paste_decal / compose_decal_voxel, the actual B3-clamped compositor, and
generate_voxel_atom for a real substrate) rather than reimplementing
anything — the whole point of Part 2 is proving a GDScript port equals
THIS code, so the fixture has to come from THIS code, unmodified.

Run from repo root:
    python3 tools/asset_generation/d33_part2_fixture_gen.py

Writes to godot/scripts/tools/fixtures/d33_part2/:
    substrate.png          — a real 32x36 concrete voxel atom (generate_voxel_atom)
    decal.png              — a synthetic 256x256 deterministic RGBA pattern
                              (not one of the Director's authored decals —
                              Part 2 proves the MATH port, not specific art;
                              a procedural pattern is reproducible without
                              depending on any asset file's current state)
    reference_lateral.png  — compose_decal_voxel(substrate, decal, [_FACE_SE])
    reference_top.png      — compose_decal_voxel(substrate, decal, [_FACE_TOP])
    reference_sw.png       — compose_decal_voxel(substrate, decal, [_FACE_SW])
    reference_se_mirrored.png — compose_decal_voxel(substrate, decal, [_FACE_SE_MIRRORED])

reference_sw/reference_se_mirrored exist because a real bug (V_WB/V_EB
mistyped 28 as 26 in decal_compositor.gd) shipped in D33 Part 3a undetected:
FACE_SE and FACE_TOP don't reference V_WB or V_EB at all, so the original
two fixtures above gave zero coverage of the two targets (FACE_SW,
FACE_SE_MIRRORED) Part 3a's bullet-LEFT/bullet-RIGHT wiring actually uses.
Found while building Part 3b's fixtures, fixed, and closed here so this
class of gap can't recur.

The decal pattern is a soft-edged circle with a position-dependent color
(R=x, G=y, B=128) and genuinely partial alpha across its edge — chosen so a
premultiply/unpremultiply or supersample-weighting bug shows up as a visible,
localized channel mismatch instead of hiding in an all-or-nothing alpha mask.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image

import generate_voxel as gv

FIXTURE_DIR = Path("godot/scripts/tools/fixtures/d33_part2")


def make_decal() -> Image.Image:
    size = gv.DECAL_AUTHOR_SIZE  # 256, matches the real authoring canvas
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size / 2.0
    radius = size * 0.45
    edge = size * 0.08  # soft falloff band, so alpha is genuinely partial
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

    substrate = gv.generate_voxel_atom(gv.MATERIALS["concrete"])
    decal = make_decal()

    reference_lateral = gv.compose_decal_voxel(substrate, decal, [gv._FACE_SE])
    reference_top = gv.compose_decal_voxel(substrate, decal, [gv._FACE_TOP])
    reference_sw = gv.compose_decal_voxel(substrate, decal, [gv._FACE_SW])
    reference_se_mirrored = gv.compose_decal_voxel(substrate, decal, [gv._FACE_SE_MIRRORED])

    substrate.save(FIXTURE_DIR / "substrate.png", "PNG")
    decal.save(FIXTURE_DIR / "decal.png", "PNG")
    reference_lateral.save(FIXTURE_DIR / "reference_lateral.png", "PNG")
    reference_top.save(FIXTURE_DIR / "reference_top.png", "PNG")
    reference_sw.save(FIXTURE_DIR / "reference_sw.png", "PNG")
    reference_se_mirrored.save(FIXTURE_DIR / "reference_se_mirrored.png", "PNG")

    print(f"Wrote fixtures to {FIXTURE_DIR}/:")
    for name in ["substrate.png", "decal.png", "reference_lateral.png", "reference_top.png",
                 "reference_sw.png", "reference_se_mirrored.png"]:
        print(f"  {name}")

    print("\nTarget geometry used (must match the GDScript port exactly):")
    print(f"  _FACE_SE  = {gv._FACE_SE}")
    print(f"  _FACE_TOP = {gv._FACE_TOP}")
    print(f"  _FACE_SW  = {gv._FACE_SW}")
    print(f"  _FACE_SE_MIRRORED = {gv._FACE_SE_MIRRORED}")


if __name__ == "__main__":
    main()
