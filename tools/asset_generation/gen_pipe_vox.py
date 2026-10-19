#!/usr/bin/env python3
"""gen_pipe_vox.py — the PIPE_LAB objects as MagicaVoxel `.vox` files: a big half-buried drain pipe with a grated mouth, and the two curbs
of a concrete channel.

Same conventions as `gen_dorm_vox.py` (1 voxel = 0.2 m, 8 voxels = 1 GU = a storey; x, y horizontal, z UP; the colour index is mapped to a
registry material by the prop's JSON `vox_materials`). Reproducible byte for byte.

A voxel prop is ONE GU of footprint and `rot` is not applied to it (PROP_PIPELINE_PLAN, PP4 limits), so a 2 x 2 GU pipe is FOUR one-GU
pieces and each pipe is authored already facing its way (map x = vox x, map y = vox y).

PIPE (16 x 16 x 8 voxels): a circle of outer radius 8 centred on the FLOOR plane, so only its upper half stands ("semi-buried"); the shell is
2 voxels thick, the bore radius 6. Along its length u: u = 15 is the MOUTH (open to the room), u = 0 the back, against the wall (closed by a
plug). Grating bars every 2 voxels close the bore 1 voxel behind the mouth, so nothing passes. `pipe_n_<ix><iy>` stands on the north wall
(mouth faces +y), `pipe_s_<ix><iy>` on the south wall (mouth faces -y); ix across (map x), iy from the wall side (north) / the mouth side (south).
CURBS (8 x 8 x 4: 2026-10-18, they were 2 high; the water now stands 3 voxels at most and the extra voxel is the MARGIN the surface's waves need, so it meets the rail's inner face instead of hanging at its lip): `curb_lo` has its rail at vox x 0-1, `curb_hi` at x 6-7: placed side by side they bound a 2 GU channel along y.

RAISED PIPE (8 x 8 x 16 a GU piece, 2026-10-18, the waterfall bench): `pipe_n_hi_<ix><iy>` is the north pipe with its axis 8 voxels over the floor, standing whole on it; its bore's bottom is 2 voxels up, so the water leaving its mouth FALLS into the channel dug below.

GRATES (8 x 8 x 8, 2026-10-18): the part of the grating that stands BELOW the floor, in the dug channel (placed at storey -1 = levels 72-79, the bars filling levels 76-79 from the bed up to the floor top), so the bars run from the bed to the top of the bore. `grate_n_<ix>` / `grate_s_<ix>`: bars on every even voxel across, in the row the pipe's own bars stand on (north: GU row 6 of the pipe's last GU, south: row 1 of the first).

Usage:  python3 tools/asset_generation/gen_pipe_vox.py [--out ASSETS/props/vox]
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_dorm_vox import Model, write_vox  # noqa: E402

SHELL, BARS, PLUG = 1, 2, 3
CURB_HEIGHT = 4     ## voxels; the plane's brim (`fluid.rim` in the map) is one less


def pipe_cell(v: int, u: int, z: int):
    """The colour index of the whole pipe at across v, along u (0 back .. 15 mouth), height z; None = empty."""
    r = math.hypot(v - 7.5, z + 0.5)        # distance from the pipe's axis, which lies in the floor plane
    if r > 8.0:
        return None
    if r >= 6.0:
        return SHELL
    if u <= 1:
        return PLUG                         # the back of the bore
    if u == 14 and v % 2 == 0:
        return BARS                         # grating, 1 voxel behind the mouth
    return None


def pipe_piece(ix: int, iy: int, south: bool) -> Model:
    m = Model(8, 8, 8)
    for x in range(8):
        for y in range(8):
            gy = 8 * iy + y
            u = 15 - gy if south else gy
            for z in range(8):
                idx = pipe_cell(8 * ix + x, u, z)
                if idx:
                    m.set(x, y, z, idx)
    return m


RAISE = 8          ## the RAISED pipe's axis is this many voxels over the floor: the whole pipe stands on the floor (16 high), its bore 2 voxels up


def pipe_piece_raised(ix: int, iy: int, south: bool) -> Model:
    """The raised pipe (2026-10-18, the waterfall bench): the same circle as `pipe_piece`, its axis RAISE voxels over the floor, so the pipe stands
    whole on the floor (8 x 8 x 16, two storeys) and its bore's bottom is 2 voxels up: water leaving its mouth falls into a channel dug below."""
    m = Model(8, 8, 16)
    for x in range(8):
        for y in range(8):
            gy = 8 * iy + y
            u = 15 - gy if south else gy
            for z in range(16):
                idx = pipe_cell(8 * ix + x, u, z - RAISE)
                if idx:
                    m.set(x, y, z, idx)
    return m


def curb(hi: bool) -> Model:
    m = Model(8, 8, CURB_HEIGHT)
    m.box(6 if hi else 0, 0, 0, 7 if hi else 1, 7, CURB_HEIGHT - 1, 1)
    return m


def grate(south: bool, ix: int) -> Model:
    m = Model(8, 8, 8)
    row = 1 if south else 6
    for x in range(8):
        if (8 * ix + x) % 2 == 0:
            for z in range(4, 8):
                m.set(x, row, z, BARS)
    return m


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ASSETS/props/vox")
    out = ap.parse_args().out
    models = {"curb_lo": curb(False), "curb_hi": curb(True)}
    for side, south in (("n", False), ("s", True)):
        for ix in range(2):
            for iy in range(2):
                models["pipe_%s_%d%d" % (side, ix, iy)] = pipe_piece(ix, iy, south)
    for side, south in (("n", False), ("s", True)):
        for ix in range(2):
            models["grate_%s_%d" % (side, ix)] = grate(south, ix)
    for ix in range(2):
        for iy in range(2):
            models["pipe_n_hi_%d%d" % (ix, iy)] = pipe_piece_raised(ix, iy, False)
    for name, model in models.items():
        print("%s: %d voxels" % (name, write_vox(model, os.path.join(out, name + ".vox"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
