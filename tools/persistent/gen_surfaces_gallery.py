#!/usr/bin/env python3
##
## gen_surfaces_gallery.py — writes `maps/SURFACES_GALLERY.map.json`, the room where R3D-SURFACES art is judged in runtime
## (no grenade, no shot: every mark is placed by the map).
##
## LAYOUT (GU, inner 44 x 24, buffer 5). Four photographic BASES side by side, one column each, hard edges between them:
## grass, dirt, gravel, sand (every ground material that declares `photo`). Down each column, one ROW per patch kind that has
## art on disk (`decal_patch_<kind>_<n>.png`): three placements, one per variant (0, 1, 2 where the art exists), the middle one
## rotated, so a kind is judged on all four bases, all its variants and a rotation at once. A kind is a row, a base is a
## column; adding art and re-running this script adds the row (a kind with no art would be a loud `push_error` at boot, so it
## is not listed). At the north end of each column stands a 2 x 2 GU, one-storey block of the column's own material: its top
## face is the ROOF role of the photographic surface (the top of a wall / roof, not the floor stack).
##
## BELOW the columns (y 15 to 22) a TRANSITION PAD, four shapes that exercise the feathered border between organic grounds
## (`GroundTransitions3D`): a checkerboard (every corner and edge at once), a diagonal staircase, a three-way junction and an island.
## Each is a grid of one-GU zones merged by row; the last rect wins, as the compiler expands them.
##
## The agent stands in the corner (1, 1), clear of every row, and there are no guards. Run:
##     python3 tools/persistent/gen_surfaces_gallery.py            # rewrite the map
##     python3 tools/persistent/gen_surfaces_gallery.py --check    # fail when the file on disk is not what this would write
## and judge it with `python3 tools/persistent/surfaces_gallery.py`.

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps" / "SURFACES_GALLERY.map.json"
DECALS = ROOT / "ASSETS" / "materials" / "_generic" / "decals"

BASES = ["grass", "dirt", "gravel", "sand"]
INNER = (44, 24)
COLUMN_W = 10
COLUMN_X0 = 2
COLUMN_Y0 = 2
COLUMN_H = 12
ROW_Y0 = 7.5
ROW_STEP = 3.0
MAX_VARIANTS = 3
## Where in a column the variants sit (offset from the column's left edge, GU on the half lattice) and how each is rotated.
SLOTS = [(1.5, 0.0), (4.5, 0.6), (7.5, 0.0)]


def kinds_with_art() -> list[str]:
    """Every kind that has `decal_patch_<kind>_0.png`, in alphabetical order."""
    kinds = sorted({p.name[len("decal_patch_"):-len("_0.png")] for p in DECALS.glob("decal_patch_*_0.png")})
    return kinds


def variants_of(kind: str) -> int:
    n = 0
    while n < MAX_VARIANTS and (DECALS / ("decal_patch_%s_%d.png" % (kind, n))).exists():
        n += 1
    return n


PAD_Y0 = 15
PAD_SHAPES = {   # name -> (x0, function (dx, dy) -> material), each 8 GU wide and 8 tall
    "checker": (2, lambda dx, dy: "grass" if (dx // 2 + dy // 2) % 2 == 0 else "dirt"),
    "stairs": (12, lambda dx, dy: "grass" if dx <= dy else "sand"),
    "junction": (22, lambda dx, dy: "grass" if dx < 4 else ("dirt" if dy < 4 else "gravel")),
    "island": (32, lambda dx, dy: "sand" if 2 <= dx <= 5 and 2 <= dy <= 5 else "gravel"),
}
PAD_W, PAD_H = 8, 8


def pad_zones() -> list[dict]:
    zones = []
    for name, (x0, fn) in PAD_SHAPES.items():
        for dy in range(PAD_H):
            run = None
            for dx in range(PAD_W + 1):
                m = fn(dx, dy) if dx < PAD_W else None
                if run is not None and m != run[1]:
                    zones.append({"comment": "pad %s row %d" % (name, dy), "gu": [x0 + run[0], PAD_Y0 + dy],
                                  "size": [dx - run[0], 1], "material": run[1]})
                    run = None
                if m is not None and run is None:
                    run = (dx, m)
    return zones


def build() -> dict:
    kinds = kinds_with_art()
    zones, blocks, decals = [], [], []
    for c, base in enumerate(BASES):
        x0 = COLUMN_X0 + c * COLUMN_W
        zones.append({"comment": "%s base, column %d" % (base, c), "gu": [x0, COLUMN_Y0],
                      "size": [COLUMN_W, COLUMN_H], "material": base})
        blocks.append({"comment": "%s roof sample" % base, "gu": [x0 + 4, COLUMN_Y0 + 1],
                       "material": base, "storeys": 1, "size": [2, 2]})
        for r, kind in enumerate(kinds):
            count = variants_of(kind)
            for s, (dx, rot) in enumerate(SLOTS):
                item = {"comment": "%s on %s, variant %d" % (kind, base, s % count),
                        "at": [x0 + dx, ROW_Y0 + r * ROW_STEP], "kind": kind, "variant": s % count}
                if rot:
                    item["rot"] = rot
                decals.append(item)
    zones += pad_zones()
    return {
        "format": "infiltraitor-map", "schema_version": 3, "id": "SURFACES_GALLERY",
        "meta": {"title": "Surfaces Gallery",
                 "description": "R3D-SURFACES art room: four photographic bases, one row per patch kind, a roof block per base. "
                                "Generated by tools/persistent/gen_surfaces_gallery.py; judged by tools/persistent/surfaces_gallery.py."},
        "sections": {
            "board": {"v": 1, "inner_size": list(INNER), "buffer": 5, "floor_tile": "floor_SE"},
            "actors": {"v": 1, "agent_start": [1, 1], "guards": []},
            "legacy_compiler": {"v": 1, "wall_height": 1, "access_points": [], "dividers": [], "lights": []},
            "blocks": {"v": 2, "items": blocks},
            "floor_zones": {"v": 2, "items": zones},
            "damage_materials": {"v": 1, "materials": list(BASES)},
            "ground_decals": {"v": 1, "items": decals},
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Write maps/SURFACES_GALLERY.map.json (see the header)")
    ap.add_argument("--check", action="store_true", help="fail when the map on disk differs from what this would write")
    args = ap.parse_args()
    text = json.dumps(build(), indent=1) + "\n"
    if args.check:
        ok = MAP_PATH.exists() and MAP_PATH.read_text() == text
        print("[GALLERY] %s" % ("map is current" if ok else "map is STALE: run gen_surfaces_gallery.py"))
        return 0 if ok else 1
    MAP_PATH.write_text(text)
    print("[GALLERY] wrote %s: %d kind(s) %s" % (MAP_PATH.relative_to(ROOT), len(kinds_with_art()), kinds_with_art()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
