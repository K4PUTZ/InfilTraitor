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


def bed():
    m = Model(8, 6, 6)
    for x in (0, 7):                       # legs
        for y in (0, 5):
            m.box(x, y, 0, x, y, 1, 1)
    m.box(0, 0, 2, 7, 5, 3, 2)             # mattress (upholstery)
    m.box(4, 0, 3, 7, 5, 3, 4)             # blanket on the foot half
    m.box(0, 0, 2, 0, 5, 5, 1)             # headboard (wood)
    m.box(1, 1, 4, 2, 4, 4, 3)             # pillow
    return m


def nightstand():
    m = Model(4, 4, 4)
    m.box(0, 0, 0, 3, 3, 3, 1)
    m.box(0, 0, 1, 3, 0, 2, 5)             # drawer front
    m.set(1, 0, 2, 6)
    m.set(2, 0, 2, 6)                      # handle
    return m


def locker():
    m = Model(4, 4, 8)
    m.box(0, 0, 0, 3, 3, 7, 1)
    m.box(1, 0, 1, 2, 0, 6, 2)             # door
    for z in (6, 7):
        m.set(1, 0, z, 6)
        m.set(2, 0, z, 6)                  # vents
    m.set(2, 0, 4, 6)                      # handle
    return m


def bookshelf():
    m = Model(8, 3, 8)
    m.box(0, 0, 0, 7, 2, 7, 1)
    m.box(1, 0, 1, 6, 1, 6, 0)             # open front (carve the inside, leave the back panel)
    for z in (3, 6):                       # shelves
        m.box(1, 0, z, 6, 1, z, 1)
    books = [(1, 7), (2, 3), (3, 4), (4, 7), (5, 4), (6, 3)]
    for x, colour in books:                # lower shelf row z 1..2, middle row z 4..5
        m.box(x, 0, 1, x, 1, 2, colour)
    for x, colour in [(1, 4), (2, 3), (4, 3), (5, 7), (6, 4)]:
        m.box(x, 0, 4, x, 1, 5, colour)
    return m


def desk():
    m = Model(8, 5, 5)
    m.box(0, 0, 4, 7, 4, 4, 1)             # top
    m.box(0, 0, 0, 0, 4, 3, 5)             # left panel
    m.box(7, 0, 0, 7, 4, 3, 5)             # right panel
    m.box(1, 4, 0, 6, 4, 3, 5)             # back
    m.box(5, 0, 2, 6, 0, 3, 1)             # drawer
    return m


def chair():
    m = Model(4, 4, 6)
    for x in (0, 3):
        for y in (0, 3):
            m.box(x, y, 0, x, y, 2, 1)     # legs
    m.box(0, 0, 3, 3, 3, 3, 5)             # seat
    m.box(0, 0, 4, 3, 0, 5, 5)             # back
    return m


def bin_():
    m = Model(4, 4, 4)
    m.box(0, 0, 0, 3, 3, 3, 9)
    m.box(1, 1, 3, 2, 2, 3, 0)             # open top (empty)
    m.box(1, 1, 3, 2, 2, 3, 0)
    for (x, y, z) in [(1, 1, 3), (2, 1, 3), (1, 2, 3), (2, 2, 3)]:
        m.cells.pop((x, y, z), None)
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
