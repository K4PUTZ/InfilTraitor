#!/usr/bin/env python3
##
## gen_stress_map.py — writes `maps/STRESS.map.json`, the room of the COMBINED STRESS SCENARIO (roadmap step A1, 2026-10-07).
##
## WHY: every budget so far was measured on PLAYGROUND, a sparse test zone (9 guards, 1 prop). The Director ratified a scenario
## where the engine's costs STACK: dense content, many guards, glass, props that break, and events that overlap. This map is the
## content half; `tools/persistent/stress_scenario.py` is the event half (two grenades thrown 12 frames apart, a shot, the
## lot) and prints the SCENARIO line a desktop run or a `dev_flags.cfg` takes.
##
## LAYOUT (GU, inner 44 x 40, buffer 5, a full map is inside the ~46 GU cell-plane limit): a 3 x 3 grid of rooms, walls on the lines
## x = 14 and 29, y = 13 and 26, each wall line broken by a two-GU door; every room is built of its OWN material (brick, concrete,
## wood, plywood, cardboard, stone, fabric, metal) and the centre-east room is a GLASS hall: a row of panes plus a glass roof,
## so the second grenade has the largest glass surface the game ships beside it. 26 guards (2-cell routes inside the rooms), 60
## props (crates, tables, lockers, shelves), 14 lights. The agent starts in the centre.
##
##     python3 tools/persistent/gen_stress_map.py            # rewrite the map
##     python3 tools/persistent/gen_stress_map.py --check    # fail when the file on disk is not what this would write

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps" / "STRESS.map.json"
SRC = ROOT / "maps" / "PLAYGROUND.map.json"
W, H = 44, 40
WALL_X = (14, 29)
WALL_Y = (13, 26)
DOOR = 2   ## GU wide, centred on each room's span
MATERIALS = ["brick", "concrete", "wood", "plywood", "cardboard", "stone", "fabric", "metal"]
PROPS = ["crate_full", "crate_plywood", "wood_table", "desk", "locker", "bookshelf", "bin", "chair"]


def spans(walls, size):
    edges = [0, *walls, size]
    return [(edges[i], edges[i + 1]) for i in range(len(edges) - 1)]


def build() -> dict:
    base = json.loads(SRC.read_text())
    s = base["sections"]
    xs, ys = spans(WALL_X, W), spans(WALL_Y, H)
    occupied = set()
    blocks, panels = [], []

    def door_ok(v, lo, hi):
        mid = (lo + hi) // 2
        return mid - DOOR // 2 <= v < mid - DOOR // 2 + DOOR

    ## the wall lines, broken by a door in each room's span
    for wx in WALL_X:
        for (lo, hi) in ys:
            for y in range(lo, hi):
                if door_ok(y, lo, hi):
                    continue
                blocks.append({"gu": [wx, y], "material": MATERIALS[(wx + y) // 5 % len(MATERIALS)], "storeys": 2})
                occupied.add((wx, y))
    for wy in WALL_Y:
        for (lo, hi) in xs:
            for x in range(lo, hi):
                if door_ok(x, lo, hi):
                    continue
                blocks.append({"gu": [x, wy], "material": MATERIALS[(wy + x) // 5 % len(MATERIALS)], "storeys": 2})
                occupied.add((x, wy))
    ## the glass hall, centre-east room: a row of panes across it and a glass roof
    ## (a pane is at most 8 GU wide, `GlassPaneGrouper` G-D23: two rows of eight, offset, instead of one long one)
    gx0 = WALL_X[1] + 2
    for gy in (WALL_Y[0] + 4, WALL_Y[0] + 8):
        for x in range(gx0, gx0 + 8):
            panels.append({"gu": [x, gy], "face": "SW", "material": "glass", "storeys": 2, "comment": "the glass hall"})
            occupied.add((x, gy))
    roofs = [{"gu": [WALL_X[1] + 1, WALL_Y[0] + 1], "size": [W - WALL_X[1] - 2, WALL_Y[1] - WALL_Y[0] - 2], "storeys": 2,
              "material": "glass", "kind": "flat", "comment": "the glass hall's roof"}]

    ## props and guards on a deterministic lattice inside each room, never on a wall, a door row or a pane
    props, guards = [], []
    n = 0
    for ri, (y0, y1) in enumerate(ys):
        for ci, (x0, x1) in enumerate(xs):
            for k in range(7):
                x = x0 + 2 + (k * 3 + ri) % max(x1 - x0 - 4, 1)
                y = y0 + 2 + (k * 5 + ci * 2) % max(y1 - y0 - 4, 1)
                if (x, y) in occupied or n >= 60:
                    continue
                occupied.add((x, y))
                props.append({"def": PROPS[n % len(PROPS)], "gu": [x, y], "storey": 0, "vox_offset": [0, 0], "rot": (n * 90) % 360})
                n += 1
    g = 0
    for ri, (y0, y1) in enumerate(ys):
        for ci, (x0, x1) in enumerate(xs):
            for k in range(3):
                x = x0 + 3 + k * 4
                y = y0 + 3 + (k * 3 + ci) % max(y1 - y0 - 6, 1)
                if x + 1 >= x1 - 1 or (x, y) in occupied or (x + 1, y) in occupied or g >= 26:
                    continue
                occupied.update({(x, y), (x + 1, y)})
                guards.append([[x, y], [x + 1, y]])
                g += 1
    lights = [{"x": x0 + 6, "y": y0 + 6, "height_class": 4, "radius": 9, "intensity": 1.0}
              for (y0, _) in ys for (x0, _) in xs][:9]
    lights += [{"x": 22, "y": 13, "height_class": 3, "radius": 8, "intensity": 0.9},
               {"x": 22, "y": 26, "height_class": 3, "radius": 8, "intensity": 0.9},
               {"x": 14, "y": 20, "height_class": 3, "radius": 8, "intensity": 0.9},
               {"x": 36, "y": 20, "height_class": 3, "radius": 10, "intensity": 1.2},
               {"x": 36, "y": 30, "height_class": 3, "radius": 8, "intensity": 0.9}]

    out = {k: v for k, v in base.items() if k != "sections"}
    out["id"] = "STRESS"
    out["meta"] = {"title": "Combined Stress Scenario", "description":
        "Roadmap A1 (2026-10-07). A 3x3 grid of eight-material rooms with a glass hall (centre-east), %d guards, %d props, %d lights. "
        "Written by tools/persistent/gen_stress_map.py; played by tools/persistent/stress_scenario.py." % (len(guards), len(props), len(lights))}
    out["description"] = out["meta"]["description"]
    sec = {k: json.loads(json.dumps(v)) for k, v in s.items()}
    sec["board"]["inner_size"] = [W, H]
    sec["actors"]["agent_start"] = [22, 20]
    sec["actors"]["guards"] = guards
    sec["blocks"]["items"] = blocks
    sec["props"]["items"] = props
    sec["panels"]["items"] = panels
    sec["roofs"]["items"] = roofs
    sec["floor_zones"]["items"] = [{"gu": [0, 0], "size": [W, H], "material": "concrete"}]
    sec["legacy_compiler"]["lights"] = lights
    out["sections"] = sec
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Write maps/STRESS.map.json (see the header)")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    text = json.dumps(build(), indent=1) + "\n"
    if args.check:
        ok = MAP_PATH.exists() and MAP_PATH.read_text() == text
        print("[STRESS] map is %s" % ("current" if ok else "STALE: run gen_stress_map.py"))
        return 0 if ok else 1
    MAP_PATH.write_text(text)
    d = json.loads(text)["sections"]
    print("[STRESS] wrote %s: %d blocks, %d panes, %d props, %d guards, %d lights" % (
        MAP_PATH.relative_to(ROOT), len(d["blocks"]["items"]), len(d["panels"]["items"]), len(d["props"]["items"]),
        len(d["actors"]["guards"]), len(d["legacy_compiler"]["lights"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
