#!/usr/bin/env python3
"""gen_dorm_vox.py — the first voxel props (PROP_PIPELINE_PLAN PP4): ordinary dormitory furniture as MagicaVoxel `.vox` files.

Hand-built from boxes, so they are OURS (no licence question) and reproducible: run it and `ASSETS/props/vox/*.vox` is rewritten
byte for byte. Each object fits ONE game unit of footprint (8 x 8 board voxels) and at most one storey of height (8 levels). Axes are
MagicaVoxel's: x, y horizontal, z UP. Colour indices are mapped to registry materials by each prop's JSON (`vox_materials`).

Usage:  python3 tools/asset_generation/gen_dorm_vox.py [--out ASSETS/props/vox]
"""
import argparse
import os
import struct


class Model:
    def __init__(self, w, d, h):
        self.size = (w, d, h)
        self.cells = {}

    def set(self, x, y, z, idx):
        w, d, h = self.size
        if 0 <= x < w and 0 <= y < d and 0 <= z < h:
            self.cells[(x, y, z)] = idx

    def box(self, x0, y0, z0, x1, y1, z1, idx):
        """Inclusive corners."""
        for z in range(z0, z1 + 1):
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    self.set(x, y, z, idx)


# A palette of plain colours; the index is what the prop's `vox_materials` maps, the colour only matters for the nearest-colour fallback.
PALETTE = {
    1: (168, 120, 79), 2: (90, 102, 120), 3: (225, 217, 191), 4: (72, 100, 150), 5: (130, 92, 60),
    6: (56, 59, 64), 7: (200, 60, 50), 8: (60, 120, 70), 9: (230, 230, 235),
}


def chunk(cid, content, children=b""):
    return cid.encode() + struct.pack("<II", len(content), len(children)) + content + children


def write_vox(model, path):
    w, d, h = model.size
    size = chunk("SIZE", struct.pack("<iii", w, d, h))
    cells = sorted(model.cells.items(), key=lambda kv: (kv[0][2], kv[0][1], kv[0][0]))
    xyzi = chunk("XYZI", struct.pack("<I", len(cells)) + b"".join(struct.pack("<BBBB", x, y, z, i) for (x, y, z), i in cells))
    rgba = b"".join(bytes(PALETTE.get(i + 1, (255, 255, 255))) + b"\xff" for i in range(256))
    children = size + xyzi + chunk("RGBA", rgba)
    data = b"VOX " + struct.pack("<I", 150) + chunk("MAIN", b"", children)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data)
    return len(cells)


# SCALE CANON (ACTOR D61: "a 1.60 m GU"): 1 GU = 1.6 m, so 1 voxel = 0.2 m and a storey (8 levels) = 1.6 m. The objects below are real
# sizes rounded to whole voxels, in voxels (x, y, z-up) -> metres: a small thing is never less than 2 voxels (0.4 m) so it still reads.

def bed():
    """0.9 x 1.6 x 1.0 m: a single bed shortened to the GU (1.9 m would need 9.5 voxels)."""
    m = Model(8, 5, 5)
    for x in (0, 7):                       # legs
        for y in (0, 4):
            m.box(x, y, 0, x, y, 1, 1)
    m.box(0, 0, 2, 7, 4, 2, 2)             # mattress (0.2 m)
    m.box(3, 0, 3, 7, 4, 3, 4)             # blanket on the foot half
    m.box(0, 0, 2, 0, 4, 4, 1)             # headboard (wood)
    m.box(1, 1, 3, 2, 3, 3, 3)             # pillow
    return m


def nightstand():
    """0.6 x 0.6 x 0.6 m (real ~0.45 x 0.4 x 0.55: 2 voxels would be a stump)."""
    m = Model(3, 3, 3)
    m.box(0, 0, 0, 2, 2, 2, 1)
    m.box(0, 0, 1, 2, 0, 1, 5)             # drawer front
    m.set(1, 0, 1, 6)                      # handle
    return m


def locker():
    """0.6 x 0.6 x 1.6 m (real 0.4 x 0.5 x 1.8: the storey is 1.6 m)."""
    m = Model(3, 3, 8)
    m.box(0, 0, 0, 2, 2, 7, 1)
    m.box(0, 0, 1, 2, 0, 6, 2)             # door
    m.set(1, 0, 6, 6)                      # vent
    m.set(1, 0, 7, 6)
    m.set(2, 0, 4, 6)                      # handle
    return m


def bookshelf():
    """0.8 x 0.4 x 1.6 m."""
    m = Model(4, 2, 8)
    m.box(0, 0, 0, 3, 1, 7, 1)
    m.box(1, 0, 1, 2, 0, 6, 0)             # open front (leave the back)
    for z in (3, 6):                       # shelves
        m.box(1, 0, z, 2, 0, z, 1)
    m.set(1, 0, 1, 7)
    m.set(2, 0, 1, 3)
    m.set(1, 0, 2, 7)
    m.set(2, 0, 2, 3)
    m.set(1, 0, 4, 4)
    m.set(2, 0, 4, 7)
    m.set(1, 0, 5, 4)
    m.set(2, 0, 5, 3)
    return m


def desk():
    """1.2 x 0.6 x 0.8 m."""
    m = Model(6, 3, 4)
    m.box(0, 0, 3, 5, 2, 3, 1)             # top
    m.box(0, 0, 0, 0, 2, 2, 5)             # left panel
    m.box(5, 0, 0, 5, 2, 2, 5)             # right panel
    m.box(1, 2, 0, 4, 2, 2, 5)             # back
    m.box(3, 0, 1, 4, 0, 2, 1)             # drawer
    return m


def chair():
    """0.6 x 0.6 x 0.8 m (seat at 0.4)."""
    m = Model(3, 3, 4)
    for x in (0, 2):
        for y in (0, 2):
            m.box(x, y, 0, x, y, 1, 1)     # legs
    m.box(0, 0, 2, 2, 2, 2, 5)             # seat
    m.box(0, 2, 3, 2, 2, 3, 5)             # back
    return m


def bin_():
    """0.6 x 0.6 x 0.4 m wastebasket, open top."""
    m = Model(3, 3, 2)
    m.box(0, 0, 0, 2, 2, 1, 9)
    m.cells.pop((1, 1, 1), None)
    return m


OBJECTS = {"bed_single": bed, "nightstand": nightstand, "locker": locker, "bookshelf": bookshelf,
           "desk": desk, "chair": chair, "bin": bin_}

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ASSETS/props/vox")
    args = ap.parse_args()
    for name, build in OBJECTS.items():
        n = write_vox(build(), os.path.join(args.out, name + ".vox"))
        print("%-12s %3d voxels -> %s.vox" % (name, n, os.path.join(args.out, name)))
