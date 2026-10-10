#!/usr/bin/env python3
##
## gen_segment_map.py — a SEGMENT-SHAPED synthetic map with an explicit count of each content kind (PERFORMANCE_BUDGET PB-3).
##
## WHY: PB-3 needs the marginal cost of each kind of content (props, guards, lights, glass, roofs, materials) on the unit the game
## loads: ONE segment, 18 x 36 GU (PB-1, `segment_spec`). `gen_stress_map.py` scales everything at once by density; this one takes
## the counts directly, so one kind can move while the others stay put.
##
## LAYOUT (inner W x H GU, buffer 5 from PLAYGROUND): `rooms` rooms on a grid of one column (rooms <= 3) or two (a wall line at
## x = W/2), the rows split evenly along the long axis; every wall line is broken by a two-GU door in each room's span; the walls
## are two storeys, each room's lines in one of the first `materials` wall materials. GLASS: `glass` GU of small, low panes (one
## storey, two GU per window) set INTO the horizontal wall lines in place of their blocks (PB-1: "ordinary windows, never GLASS's
## giant ones"). ROOFS: `roofs` flat concrete roofs, one per room from the first. PROPS / GUARDS / LIGHTS: a deterministic lattice
## inside the rooms, round-robin over the rooms so that a count spreads instead of filling one room; never on a wall, a door or a
## pane. Cameras / drones (PB-1) are not built in the engine yet and are not generated.
##
##     python3 tools/persistent/gen_segment_map.py --spec TYPICAL            # writes maps/SEG_TYPICAL.map.json
##     python3 tools/persistent/gen_segment_map.py --props 60 --id SEG_P60   # any kind overridden on top of --spec (default BASE)

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "maps" / "PLAYGROUND.map.json"
ENVELOPE = json.loads((ROOT / "maps" / "_spec" / "segment_envelope.json").read_text())  ## the one authority (CAPTURE_RAILS §3.3)
W, H = ENVELOPE["footprint"]
DOOR = 2
WALL_MATERIALS = ["brick", "concrete", "wood", "plywood", "stone", "metal", "cardboard", "fabric", "painted_metal"]
PROPS = ["crate_full", "crate_plywood", "wood_table", "desk", "locker", "bookshelf", "bin", "chair"]

## PB-1's `segment_spec` (PERFORMANCE_BUDGET_MASTER_PLAN §5), read from `maps/_spec/segment_envelope.json`; BASE is the floor every
## one-kind sweep starts from (a tool row, not a spec): the rooms and the materials of TYPICAL, nothing else, so a sweep row minus the
## BASE row is that kind's cost.
SPECS = {"BASE": dict(ENVELOPE["specs"]["TYPICAL"], props=0, guards=0, lights=0, glass=0, roofs=0)}
SPECS.update({name: dict(row) for name, row in ENVELOPE["specs"].items()})


def room_grid(w: int, h: int, rooms: int) -> list:
    """Rooms as (x0, x1, y0, y1) half-open GU spans, walls on the shared edges."""
    cols = 1 if rooms <= 3 else 2
    rows = math.ceil(rooms / cols)
    xs = [0, w] if cols == 1 else [0, w // 2, w]
    ys = [round(h * i / rows) for i in range(rows + 1)]
    out = []
    for r in range(rows):
        for c in range(cols):
            if len(out) < rooms:
                ## the last row of an odd count spans both columns
                x1 = xs[c + 1] if not (cols == 2 and r == rows - 1 and rooms % 2 == 1) else w
                out.append((xs[c], x1, ys[r], ys[r + 1]))
    return out


def build(spec: dict, map_id: str, w: int = W, h: int = H) -> dict:
    rooms = room_grid(w, h, spec["rooms"])
    base = json.loads(SRC.read_text())
    occupied, blocks, panels = set(), [], []
    walls = {}   ## (x, y) -> material, the wall GUs before doors and glass

    def mat(i):
        return WALL_MATERIALS[i % max(1, min(spec["materials"], len(WALL_MATERIALS)))]

    ## each room draws its right and bottom edges (the map's outer edge is open: the buffer ring frames it)
    horizontal = []   ## wall GUs on horizontal lines, in order, for the glass
    for i, (x0, x1, y0, y1) in enumerate(rooms):
        if x1 < w:
            mid = (y0 + y1) // 2
            for y in range(y0, y1):
                if not (mid - DOOR // 2 <= y < mid - DOOR // 2 + DOOR):
                    walls[(x1, y)] = mat(i)
        if y1 < h:
            mid = (x0 + x1) // 2
            for x in range(x0, x1):
                if not (mid - DOOR // 2 <= x < mid - DOOR // 2 + DOOR):
                    walls[(x, y1)] = mat(i)
                    horizontal.append((x, y1))

    ## glass: two-GU windows along the horizontal lines, one window per stretch of four wall GUs
    glass_left, k = spec["glass"], 0
    while glass_left > 0 and k + 1 < len(horizontal):
        a, b = horizontal[k], horizontal[k + 1]
        ## never a cell where a vertical line meets the horizontal one: its block carries the vertical wall's edges too
        crossing = any((g[0], g[1] + d) in walls for g in (a, b) for d in (-1, 1))
        if b == (a[0] + 1, a[1]) and not crossing:
            for g in (a, b)[:glass_left]:
                walls.pop(g, None)
                panels.append({"gu": [g[0], g[1]], "face": "SW", "material": "glass", "storeys": 1, "comment": "segment window"})
                occupied.add(g)
                glass_left -= 1
            k += 4
        else:
            k += 1
    for (x, y), m in sorted(walls.items()):
        blocks.append({"gu": [x, y], "material": m, "storeys": 2})
        occupied.add((x, y))

    roofs = []
    for (x0, x1, y0, y1) in rooms[:spec["roofs"]]:
        roofs.append({"gu": [x0 + 1, y0 + 1], "size": [max(1, x1 - x0 - 2), max(1, y1 - y0 - 2)], "storeys": 2,
                      "material": "concrete", "kind": "flat", "comment": "segment roof"})

    ## a lattice per room, consumed round-robin so a count spreads over the rooms
    def lattice(room, phase):
        x0, x1, y0, y1 = room
        cells = [(x, y) for y in range(y0 + 1 + phase % 2, y1 - 1, 2) for x in range(x0 + 1 + (y + phase) % 2, x1 - 1, 2)]
        return cells

    agent = (w // 2, h // 2)
    occupied.add(agent)

    def place(count, phase, pair=False):
        pools = [lattice(r, phase) for r in rooms]
        got, i, stalls = [], 0, 0
        while len(got) < count and stalls < len(pools):
            pool = pools[i % len(pools)]
            i += 1
            while pool:
                c = pool.pop(0)
                cells = [c, (c[0] + 1, c[1])] if pair else [c]
                inside = (not pair) or any(c[0] + 1 < r[1] - 1 for r in rooms if r[0] <= c[0] < r[1] and r[2] <= c[1] < r[3])
                if inside and all(cc not in occupied for cc in cells):
                    occupied.update(cells)
                    got.append(cells)
                    stalls = 0
                    break
            else:
                stalls += 1
        if len(got) < count:
            print("[SEGMENT] %s: only %d of %d placed (no free lattice cell left)" % (map_id, len(got), count), file=sys.stderr)
        return got

    props = [{"def": PROPS[n % len(PROPS)], "gu": [c[0][0], c[0][1]], "storey": 0, "vox_offset": [0, 0], "rot": (n * 90) % 360}
             for n, c in enumerate(place(spec["props"], 0))]
    guards = [[[c[0][0], c[0][1]], [c[1][0], c[1][1]]] for c in place(spec["guards"], 1, pair=True)]
    lights = []
    for n in range(spec["lights"]):
        x0, x1, y0, y1 = rooms[n % len(rooms)]
        turn = n // len(rooms)
        lights.append({"x": x0 + (x1 - x0) // (2 + turn), "y": y0 + (y1 - y0) // (2 + turn), "height_class": 4, "radius": 8,
                       "intensity": 1.0})

    out = {k: v for k, v in base.items() if k != "sections"}
    out["id"] = map_id
    desc = ("PERFORMANCE_BUDGET PB-3 segment %dx%d: %d rooms, %d materials, %d props, %d guards, %d lights, %d GU glass, %d roofs. "
            "Written by tools/persistent/gen_segment_map.py." % (w, h, len(rooms), min(spec["materials"], len(WALL_MATERIALS)),
                                                                 len(props), len(guards), len(lights), len(panels), len(roofs)))
    out["meta"] = {"title": "Segment %s" % map_id, "description": desc}
    if map_id in ("SEG_LOW", "SEG_TYPICAL", "SEG_HEAVY"):
        out["meta"]["segment"] = True   ## PB-7: the spec maps are segments, held to the budget by `segment_budget.py`
    out["description"] = desc
    sec = {k: json.loads(json.dumps(v)) for k, v in base["sections"].items()}
    sec["board"]["inner_size"] = [w, h]
    sec["actors"]["agent_start"] = list(agent)
    sec["actors"]["guards"] = guards
    sec["blocks"]["items"] = blocks
    sec["props"]["items"] = props
    sec["panels"]["items"] = panels
    sec["roofs"]["items"] = roofs
    sec["floor_zones"]["items"] = [{"gu": [0, 0], "size": [w, h], "material": "concrete"}]
    sec["legacy_compiler"]["lights"] = lights
    ## CAPTURE_RAILS CR-1: the anchors of a generated segment — one region per room (2 storeys, the blocks' height) and its centre
    ## as a POI; the first room's centre is where an event is staged. Never inherited from SRC (PLAYGROUND's anchors are elsewhere).
    sec["layout"] = {"v": 1, "objectives": [],
                     "regions": [{"id": "room_%d" % i, "box": {"min": [x0, y0, 0], "max": [x1, y1, 2]}, "tags": ["room"]}
                                 for i, (x0, x1, y0, y1) in enumerate(rooms)],
                     "poi": [{"id": "room_%d_centre" % i, "at": [(x0 + x1) / 2.0, (y0 + y1) / 2.0],
                              "tags": ["event"] if i == 0 else ["detail"]}
                             for i, (x0, x1, y0, y1) in enumerate(rooms)]}
    out["sections"] = sec
    return out


def spec_from(name: str, **over) -> dict:
    s = dict(SPECS[name])
    s.update({k: v for k, v in over.items() if v is not None})
    return s


def write(spec: dict, map_id: str) -> Path:
    path = ROOT / "maps" / (map_id + ".map.json")
    path.write_text(json.dumps(build(spec, map_id), indent=1) + "\n")
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description="Write a segment-shaped synthetic map (see the header)")
    ap.add_argument("--spec", choices=sorted(SPECS), default="BASE")
    ap.add_argument("--id", default="")
    for k in SPECS["BASE"]:
        ap.add_argument("--" + k, type=int, default=None)
    args = ap.parse_args()
    spec = spec_from(args.spec, **{k: getattr(args, k) for k in SPECS["BASE"]})
    map_id = args.id or "SEG_" + args.spec
    path = write(spec, map_id)
    print("[SEGMENT] wrote %s: %s" % (path.relative_to(ROOT), json.loads(path.read_text())["description"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
