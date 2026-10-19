#!/usr/bin/env python3
"""gen_liquids_lab_vox.py — the LIQUIDS_LAB objects as MagicaVoxel `.vox` files (M6 F5, the per-liquid rules bench, 2026-10-18).

`box_cardboard_pit` (8 x 8 x 8): a cardboard box standing on the bed of a pit dug 4 voxels (placed at storey -1 = levels 72-79, the box filling
levels 76-79, x and y 2-5), for the toxic liquid that dissolves paper, cardboard and cloth: its lower half stands in the liquid.
The acid's pit takes the PIPE_LAB grates (`grate_n_<ix>`, gen_pipe_vox.py) for the metal it dissolves.

Same conventions as `gen_dorm_vox.py` (1 voxel = 0.2 m, 8 voxels = 1 GU = a storey; x, y horizontal, z UP; the colour index is mapped to a
registry material by the prop's JSON `vox_materials`). Reproducible byte for byte.

Usage:  python3 tools/asset_generation/gen_liquids_lab_vox.py [--out ASSETS/props/vox]
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_dorm_vox import Model, write_vox  # noqa: E402

CARDBOARD = 1


def box_cardboard_pit() -> Model:
    m = Model(8, 8, 8)
    m.box(2, 2, 4, 5, 5, 7, CARDBOARD)
    return m


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ASSETS/props/vox")
    out = ap.parse_args().out
    for name, model in {"box_cardboard_pit": box_cardboard_pit()}.items():
        print("%s: %d voxels" % (name, write_vox(model, os.path.join(out, name + ".vox"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
