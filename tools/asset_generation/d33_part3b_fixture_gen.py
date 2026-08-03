#!/usr/bin/env python3
"""
d33_part3b_fixture_gen.py — D33 Part 3b equality-proof fixtures.

Same discipline as d33_part2_fixture_gen.py: a one-shot tool using the REAL
generate_voxel.py functions (generate_half_voxel, compose_decal_voxel)
unmodified, so the GDScript port's selftest has real ground truth to compare
against rather than a hand-derived approximation.

Part 3b's new piece beyond Part 2 is the MASK-PASTE primitive
(Image.paste(src, (0,0), _polygon_mask(poly)) has no direct Godot Image
equivalent — Part 2's DecalCompositor only ports the projected/sheared
paste, not a straight same-coordinate polygon mask), so this fixture set
covers generate_half_voxel()'s LEFT and RIGHT wall substrates, both bare
(mask construction only) and with a real bullet decal composited onto the
exposed cut face — the full real pipeline, same shape as Part 2.

Run from repo root:
    python3 tools/asset_generation/d33_part3b_fixture_gen.py

Writes to godot/scripts/tools/fixtures/d33_part3b/:
    atom.png                  — generate_voxel_atom(concrete) — the flat "kept"
                                 substrate generate_half_voxel() reads its kept
                                 face/top from; exported so the GDScript side
                                 has the EXACT same input, not a re-derived one
    half_left.png            — generate_half_voxel(concrete, "left")
    half_right.png            — generate_half_voxel(concrete, "right")
    decal.png                 — same synthetic soft-edged decal as Part 2
                                 (reproducible, not dependent on authored art)
    composited_left.png       — compose_decal_voxel(half_left, decal, [_FACE_CUT_LEFT])
    composited_right.png      — compose_decal_voxel(half_right, decal, [_FACE_CUT_RIGHT])
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image

import generate_voxel as gv

FIXTURE_DIR = Path("godot/scripts/tools/fixtures/d33_part3b")


def make_decal() -> Image.Image:
    """Identical construction to d33_part2_fixture_gen.py's make_decal() —
    kept as a literal copy rather than an import so this fixture set stays
    self-contained and doesn't silently start depending on Part 2's script."""
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
    half_left = gv.generate_half_voxel(concrete, "left")
    half_right = gv.generate_half_voxel(concrete, "right")
    decal = make_decal()

    composited_left = gv.compose_decal_voxel(half_left, decal, [gv._FACE_CUT_LEFT])
    composited_right = gv.compose_decal_voxel(half_right, decal, [gv._FACE_CUT_RIGHT])

    atom.save(FIXTURE_DIR / "atom.png", "PNG")
    half_left.save(FIXTURE_DIR / "half_left.png", "PNG")
    half_right.save(FIXTURE_DIR / "half_right.png", "PNG")
    decal.save(FIXTURE_DIR / "decal.png", "PNG")
    composited_left.save(FIXTURE_DIR / "composited_left.png", "PNG")
    composited_right.save(FIXTURE_DIR / "composited_right.png", "PNG")

    print(f"Wrote fixtures to {FIXTURE_DIR}/:")
    for name in ["atom.png", "half_left.png", "half_right.png", "decal.png",
                 "composited_left.png", "composited_right.png"]:
        print(f"  {name}")

    print("\nGeometry used (must match the GDScript port exactly):")
    print(f"  _CUT_PLANE       = {gv._CUT_PLANE}")
    print(f"  _KEPT_RIGHT_FACE = {gv._KEPT_RIGHT_FACE}")
    print(f"  _KEPT_TOP_HALF   = {gv._KEPT_TOP_HALF}")
    print(f"  _FACE_CUT_LEFT   = {gv._FACE_CUT_LEFT}")
    print(f"  _FACE_CUT_RIGHT  = {gv._FACE_CUT_RIGHT}")
    print(f"  SIDE_DARKEN x concrete = {gv._darken(concrete, gv.SIDE_DARKEN)}")


if __name__ == "__main__":
    main()
