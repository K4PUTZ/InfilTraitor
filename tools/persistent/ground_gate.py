#!/usr/bin/env python3
##
## ground_gate.py — gameplay reads the ground from `GroundGrid`, not from a TileMapLayer (R3D-11).
##
## Boots the real game per map with the scenario
##     ground_check n; perspective E; ground_check e; perspective S; ground_check s; perspective W; ground_check w
## once on the 3D board (the floor layer is never written) and once on the 2D board (`RENDER3D=0`: the layer still holds the
## floor tiles, so the in-process tile-vs-grid comparison means something), and requires for every map and view:
##   1. IN-PROCESS, on the boot that still fills the layer: walk_mismatch 0 and point_mismatch 0 — over every cell of the map and
##      a 3-cell margin, "the layer holds a tile here" equals "the cell is inside the room's rectangle", and `map_to_local`
##      agrees with `GroundGrid.map_to_local`; on the NEW boot the layer holds NO tile (`tiles 0`): nothing writes it;
##   2. THE DIGESTS: walkability, selectable cells, the movement flood (cell -> cost), a path to every 7th reachable cell,
##      and the visible/total cell counts are identical between the two boots;
##   3. THE CONTROL: the four views are not the same picture (a rotated PLAYGROUND has a different size / reach), so a gate that
##      read one cached answer would fail here.
##
## Usage:  python3 tools/persistent/ground_gate.py [--maps PLAYGROUND,GLASS,SIGMA_01,PLAYGROUND_2]

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[GROUND-GATE]"
SCENARIO = ("framing portrait; frames 90; ground_check n; perspective E; frames 30; ground_check e; perspective S; "
            "frames 30; ground_check s; perspective W; frames 30; ground_check w; quit")
LINE = re.compile(r"\[GROUND-CHECK\] (\w) size \((\d+), (\d+)\) tiles (\d+) \| walk_mismatch (\d+) point_mismatch (\d+) "
                  r"floor_pos (.*?) floor_scale (.*?) \| (walk .*)$")


def boot(map_id: str, tiles: bool):  ## tiles=True: the 2D board, whose floor layer holds tiles
    env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": SCENARIO,
           "INFILTRAITOR_RENDER3D": "0" if tiles else "1"}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True,
                         env=env, timeout=400)
    log = out.stdout + out.stderr
    rows = {}
    for line in log.splitlines():
        m = LINE.search(line)
        if m:
            rows[m.group(1)] = m.groups()
    return rows, ("SCRIPT ERROR" in log)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--maps", default="PLAYGROUND,GLASS,SIGMA_01,PLAYGROUND_2")
    args = ap.parse_args()
    problems = []
    for map_id in [m.strip() for m in args.maps.split(",") if m.strip()]:
        new, err_new = boot(map_id, False)
        old, err_old = boot(map_id, True)
        if err_new or err_old:
            problems.append("%s: a boot reported a script error" % map_id)
        if sorted(new) != ["e", "n", "s", "w"] or sorted(old) != ["e", "n", "s", "w"]:
            problems.append("%s: missing views (new %s, old %s)" % (map_id, sorted(new), sorted(old)))
            continue
        for view in "nesw":
            n, o = new[view], old[view]
            print("%s %s %s: %sx%s, new boot %s tile(s); tile boot %s tiles, walk_mismatch %s, point_mismatch %s; digests %s" % (
                TAG, map_id, view, n[1], n[2], n[3], o[3], o[4], o[5], "IDENTICAL" if n[8] == o[8] else "DIFFERENT"))
            if int(o[4]) or int(o[5]):
                problems.append("%s %s: %s walkability / %s point mismatch(es) in-process" % (map_id, view, o[4], o[5]))
            if n[8] != o[8]:
                problems.append("%s %s: digests differ\n     new %s\n     old %s" % (map_id, view, n[8], o[8]))
            if o[3] == "0":
                problems.append("%s %s: the tile boot holds no tiles (nothing to compare)" % (map_id, view))
            if n[3] != "0":
                problems.append("%s %s: the new boot still holds %s floor tile(s) — something still writes the layer" % (map_id, view, n[3]))
        if len({new[v][8] for v in "nesw"}) == 1:
            problems.append("%s: all four views gave one digest — the control failed" % map_id)
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
