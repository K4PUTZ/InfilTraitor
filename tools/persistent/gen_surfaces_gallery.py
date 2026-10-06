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
## The agent stands in the human-floor band (the scale reference), and there are no guards. Run:
##     python3 tools/persistent/gen_surfaces_gallery.py            # rewrite the map
##     python3 tools/persistent/gen_surfaces_gallery.py --check    # fail when the file on disk is not what this would write
## and judge it with `python3 tools/persistent/surfaces_gallery.py`.

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATHS = {"SURFACES_GALLERY": ROOT / "maps" / "SURFACES_GALLERY.map.json", "SURFACES_LAB": ROOT / "maps" / "SURFACES_LAB.map.json",
             "SURFACES_SCATTER": ROOT / "maps" / "SURFACES_SCATTER.map.json"}
MAP_PATH = MAP_PATHS["SURFACES_GALLERY"]
DECALS = ROOT / "ASSETS" / "materials" / "_generic" / "decals"

BASES = ["grass", "dirt", "gravel", "sand"]
## ⚠️ A map is limited to ~46 GU per side (the cell plane that carries light and soot is 512 voxels from an origin 8 GU before the
## map, `CellPlaneStore.SOOT_TEX_SIZE`): past that a cell is `outside the 512x512 cell plane` and draws with no light or soot. So the
## art rooms are TWO maps: SURFACES_GALLERY (grounds, transitions, human and industrial floors) and SURFACES_LAB (the carpet matrix).
INNER_GALLERY = (44, 44)
INNER_LAB = (44, 32)
INNER_SCATTER = (44, 30)
## SURFACES_SCATTER (SM-2): three rooms side by side (a FOREST on grass, a YARD on gravel and dirt, an OFFICE on carpet, where `leaf_litter`
## is forbidden by the rules and must place NOTHING) and a DENSITY LADDER of one kind on grass below, 0.06 / 0.16 / 0.40 stamps per GU^2.
## A block and a wall stand in each room: no stamp may lie under them.
SCATTER_ROOMS = {   # name -> (x, y, w, h)
    "forest": (2, 2, 14, 12), "yard": (16, 2, 14, 12), "office": (30, 2, 13, 12),
}
SCATTER_LADDER = [(2, 16, 13, 12, 0.06), (15, 16, 13, 12, 0.16), (28, 16, 13, 12, 0.40)]
COLUMN_W = 10
COLUMN_X0 = 2
COLUMN_Y0 = 2
COLUMN_H = 12
ROW_Y0 = 7.5
ROW_STEP = 3.0
MAX_VARIANTS = 3
## Where in a column the variants sit (offset from the column's left edge, GU on the half lattice) and how each is rotated.
SLOTS = [(1.5, 0.0), (4.5, 0.6), (7.5, 0.0)]


RULES = json.loads((ROOT / "surfaces" / "rules.json").read_text())


def floor_tags(base: str) -> list[str]:
    return json.loads((ROOT / "ASSETS" / "materials" / base / ("%s.json" % base)).read_text()).get("tags", [])


def forbidden(kind: str, base: str) -> str:
    """Why `kind` may not lie on `base` (the same rule `SurfaceRules` applies in the engine), or ''."""
    rule = RULES["patches"].get(kind)
    if rule is None:
        return "no rule for %s in surfaces/rules.json" % kind
    tags = floor_tags(base)
    for t in rule.get("requires", []):
        if t not in tags:
            return "%s needs %s" % (kind, t)
    for t in rule.get("forbids", []):
        if t in tags:
            return "%s forbidden on %s" % (kind, t)
    return ""


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
## The HUMAN-FLOOR band below the transition pad (y 25 to 32): one 8-GU band per man-made floor, hard edges between them (a human <->
## human border is today's GU edge), each with a 2 x 2 GU one-storey block of its own material (the same facade on a wall, a top and a
## floor), and the agent standing in the first band as the scale reference (~1.75 m).
HUMAN = ["carpet", "parquet", "tile", "tile_beige", "tile_grey", "concrete", "stone"]
HUMAN_W = 6
## `material_tints` demo: the plain `carpet` (first human band) wears a rose in THIS map, with no variant row and no art.
TINTS = {"carpet": [0.50, 0.20, 0.36]}
HUMAN_Y0 = 25
HUMAN_H = 8
AGENT_START = [6, 29]
## The CARPET MATRIX (SURFACES_LAB, y 2 to 31): one column per pattern, one row per colour (`gen_corporate_floors.py`'s CARPET_PATTERNS x CARPET_COLOURS),
## every cell 8 GU wide and 3 tall. The plain `carpet` is not in it (it is the old fine weave).
CARPET_PATTERNS = {"plain": "blue", "stripe": "red", "basket": "navy", "diamond": "green", "check": "tan"}   # pattern -> default colour
CARPET_COLOURS = ["red", "blue", "navy", "grey", "green", "tan", "yellow", "orange", "purple", "black"]   # = gen_corporate_floors.CARPET_COLOURS
## The INDUSTRIAL band (y 35 to 42), 5 GU per material: tread plate in four colours, grating in four.
INDUSTRIAL = ["steel_plate", "steel_plate_dark", "steel_plate_rust", "steel_plate_green", "grating", "grating_dark", "grating_rust",
              "grating_yellow"]
IND_Y0 = 35
IND_H = 8
IND_W = 5
LAB_Y0 = 2   # in SURFACES_LAB
LAB_ROW_H = 3
LAB_W = 8
LAB = ["carpet_%s" % p for p in CARPET_PATTERNS]       # the columns' pattern materials (a column's capture is named after them)


def carpet_id(pattern: str, colour: str) -> str:
    return "carpet_%s" % pattern if CARPET_PATTERNS[pattern] == colour else "carpet_%s_%s" % (pattern, colour)


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


GALLERY_ROWS = ["leaf"]   # the plain single decals of 1 GU the gallery's patch rows show on every base


def single_decal_kinds() -> list[str]:
    """The kinds the gallery's patch rows show (`GALLERY_ROWS`, when their art exists). Stamps and the small singles are judged in SURFACES_SCATTER."""
    return [k for k in GALLERY_ROWS if k in kinds_with_art()]


def build(map_id: str = "SURFACES_GALLERY") -> dict:
    if map_id == "SURFACES_LAB":
        return build_lab()
    if map_id == "SURFACES_SCATTER":
        return build_scatter()
    kinds = single_decal_kinds()
    zones, blocks, decals = [], [], []
    for c, base in enumerate(BASES):
        x0 = COLUMN_X0 + c * COLUMN_W
        zones.append({"comment": "%s base, column %d" % (base, c), "gu": [x0, COLUMN_Y0],
                      "size": [COLUMN_W, COLUMN_H], "material": base})
        blocks.append({"comment": "%s roof sample" % base, "gu": [x0 + 4, COLUMN_Y0 + 1],
                       "material": base, "storeys": 1, "size": [2, 2]})
        for r, kind in enumerate(kinds):
            count = variants_of(kind)
            if forbidden(kind, base):
                continue   # the rule says no (e.g. no leaf in the desert): the cell stays bare, which is what the gallery should show
            for s, (dx, rot) in enumerate(SLOTS):
                item = {"comment": "%s on %s, variant %d" % (kind, base, s % count),
                        "at": [x0 + dx, ROW_Y0 + r * ROW_STEP], "kind": kind, "variant": s % count}
                if rot:
                    item["rot"] = rot
                decals.append(item)
    zones += pad_zones()
    for i, mat in enumerate(INDUSTRIAL):
        zones.append({"comment": "industrial %s" % mat, "gu": [COLUMN_X0 + i * IND_W, IND_Y0], "size": [IND_W, IND_H], "material": mat})
    for i, mat in enumerate(HUMAN):
        x0 = COLUMN_X0 + i * HUMAN_W
        zones.append({"comment": "human floor %s" % mat, "gu": [x0, HUMAN_Y0], "size": [HUMAN_W, HUMAN_H], "material": mat})
        blocks.append({"comment": "%s block" % mat, "gu": [x0 + 3, HUMAN_Y0 + 2], "material": mat, "storeys": 1, "size": [2, 2]})
    return {
        "format": "infiltraitor-map", "schema_version": 3, "id": "SURFACES_GALLERY",
        "meta": {"title": "Surfaces Gallery",
                 "description": "R3D-SURFACES art room: four photographic bases, one row per patch kind, a roof block per base. "
                                "Generated by tools/persistent/gen_surfaces_gallery.py; judged by tools/persistent/surfaces_gallery.py."},
        "sections": {
            "board": {"v": 1, "inner_size": list(INNER_GALLERY), "buffer": 5, "floor_tile": "floor_SE"},
            "actors": {"v": 1, "agent_start": AGENT_START, "guards": []},
            "legacy_compiler": {"v": 1, "wall_height": 1, "access_points": [], "dividers": [], "lights": []},
            "blocks": {"v": 2, "items": blocks},
            "floor_zones": {"v": 2, "items": zones},
            "damage_materials": {"v": 1, "materials": list(BASES) + HUMAN + INDUSTRIAL},
            "ground_decals": {"v": 1, "items": decals},
            "material_tints": {"v": 1, "tints": TINTS},
        },
    }


def build_scatter() -> dict:
    fx, fy, fw, fh = SCATTER_ROOMS["forest"]
    yx, yy, yw, yh = SCATTER_ROOMS["yard"]
    ox, oy, ow, oh = SCATTER_ROOMS["office"]
    zones = [
        {"comment": "forest floor", "gu": [fx, fy], "size": [fw, fh], "material": "grass"},
        {"comment": "forest dirt strip", "gu": [fx, fy + fh - 3], "size": [fw, 3], "material": "dirt"},
        {"comment": "yard gravel", "gu": [yx, yy], "size": [yw, yh], "material": "gravel"},
        {"comment": "yard dirt", "gu": [yx + 8, yy], "size": [6, 6], "material": "dirt"},
        {"comment": "office carpet", "gu": [ox, oy], "size": [ow, oh], "material": "carpet_stripe"},
        {"comment": "ladder grass", "gu": [2, 16], "size": [39, 12], "material": "grass"},
    ]
    blocks = [
        {"comment": "forest block", "gu": [fx + 6, fy + 3], "material": "grass", "storeys": 1, "size": [2, 2]},
        {"comment": "forest wall", "gu": [fx + 2, fy + 8], "material": "concrete", "storeys": 1, "size": [6, 1]},
        {"comment": "yard block", "gu": [yx + 4, yy + 4], "material": "concrete", "storeys": 1, "size": [2, 2]},
        {"comment": "office block", "gu": [ox + 5, oy + 4], "material": "concrete", "storeys": 1, "size": [2, 2]},
    ]
    # Each room mixes a few cluster STAMPS with many small SINGLES in one weighted item (`kinds`): the singles break up the stamps' repetition.
    scatter = []
    seed = 0
    for zone, kinds, density in [
            ((fx, fy, fw, fh), [["leaf_litter", 1], ["leaf_single", 6], ["twig", 1]], 1.1),
            ((fx, fy, fw, fh), [["dirt", 1], ["dirt_spot", 3]], 0.2),
            ((fx, fy, fw, fh), [["pebbles", 1], ["pebble", 6]], 0.35),
            ((yx, yy, yw, yh), [["pebbles", 1], ["pebble", 8]], 0.9),
            ((yx, yy, yw, yh), [["dirt", 1], ["dirt_spot", 3]], 0.3),
            ((yx, yy, yw, yh), [["oil", 1], ["oil_drop", 3]], 0.12),
            ((ox, oy, ow, oh), [["leaf_litter", 1], ["leaf_single", 6]], 1.0),     # forbidden on carpet: places NOTHING
            ((ox, oy, ow, oh), [["dirt", 1], ["dirt_spot", 4]], 0.25)]:
        seed += 1
        scatter.append({"zone": list(zone), "kinds": kinds, "seed": seed, "density": density})
    for (x, y, w, h, density) in SCATTER_LADDER:
        seed += 1
        scatter.append({"zone": [x, y, w, h], "kind": "leaf_litter", "seed": seed, "density": density})
    return {
        "format": "infiltraitor-map", "schema_version": 3, "id": "SURFACES_SCATTER",
        "meta": {"title": "Surfaces Scatter",
                 "description": "R3D-SURFACES SM-2: cluster stamps scattered by zone (forest, yard, office) and a density ladder. Generated by tools/persistent/gen_surfaces_gallery.py."},
        "sections": {
            "board": {"v": 1, "inner_size": list(INNER_SCATTER), "buffer": 5, "floor_tile": "floor_SE"},
            "actors": {"v": 1, "agent_start": [1, 1], "guards": []},
            "legacy_compiler": {"v": 1, "wall_height": 1, "access_points": [], "dividers": [], "lights": []},
            "blocks": {"v": 2, "items": blocks},
            "floor_zones": {"v": 2, "items": zones},
            "damage_materials": {"v": 1, "materials": []},
            "ground_decals": {"v": 1, "items": []},
            "ground_scatter": {"v": 1, "items": scatter},
        },
    }


def build_lab() -> dict:
    """The carpet matrix: one column per pattern, one row per colour, nothing else (the agent stands in the corner)."""
    zones = []
    for i, pattern in enumerate(CARPET_PATTERNS):
        for j, colour in enumerate(CARPET_COLOURS):
            zones.append({"comment": "carpet %s %s" % (pattern, colour), "gu": [COLUMN_X0 + i * LAB_W, LAB_Y0 + j * LAB_ROW_H],
                          "size": [LAB_W, LAB_ROW_H], "material": carpet_id(pattern, colour)})
    return {
        "format": "infiltraitor-map", "schema_version": 3, "id": "SURFACES_LAB",
        "meta": {"title": "Surfaces Lab",
                 "description": "R3D-SURFACES carpet matrix: five patterns x ten colours. Generated by tools/persistent/gen_surfaces_gallery.py."},
        "sections": {
            "board": {"v": 1, "inner_size": list(INNER_LAB), "buffer": 5, "floor_tile": "floor_SE"},
            "actors": {"v": 1, "agent_start": [1, 1], "guards": []},
            "legacy_compiler": {"v": 1, "wall_height": 1, "access_points": [], "dividers": [], "lights": []},
            "blocks": {"v": 2, "items": []},
            "floor_zones": {"v": 2, "items": zones},
            "damage_materials": {"v": 1, "materials": []},
            "ground_decals": {"v": 1, "items": []},
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Write maps/SURFACES_GALLERY.map.json (see the header)")
    ap.add_argument("--check", action="store_true", help="fail when the map on disk differs from what this would write")
    args = ap.parse_args()
    status = 0
    for map_id, path in MAP_PATHS.items():
        text = json.dumps(build(map_id), indent=1) + "\n"
        if args.check:
            ok = path.exists() and path.read_text() == text
            print("[GALLERY] %s %s" % (map_id, "is current" if ok else "is STALE: run gen_surfaces_gallery.py"))
            status |= 0 if ok else 1
        else:
            path.write_text(text)
            print("[GALLERY] wrote %s (%d kind(s) %s)" % (path.relative_to(ROOT), len(kinds_with_art()), kinds_with_art()))
    return status


if __name__ == "__main__":
    sys.exit(main())
