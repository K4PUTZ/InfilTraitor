#!/usr/bin/env python3
##
## pick_gate.py — does a touch land on the cell the eye sees, from every side? (R3D-ROT, 2026-10-02)
##
## WHY IT EXISTS. Rotation is the camera's yaw, so a pick is a ray through a turned camera. The picking maths was only ever
## compared in the N view (`PICK_CHECK`), and a pick that is right from N and wrong from E would pass every other gate: no
## state differs, no pixel of a still frame says which cell a finger would select. The `pick_check` scenario step sends the
## centre of every on-screen cell through the REAL pick (`Room._screen_to_tile`, what a touch reaches) in the current view and
## prints `[PICK-CHECK] <name> view=<V> cells=<n> ok=<a> covered=<b> bad=<c> offscreen=<d>`.
##
## PER BOOT (one per map, the four views in one run):
##   1. EVERY VIEW PRINTED — N, E, S and W, each with the view the Room reports (a step that silently did not turn
##      would print N four times);
##   2. IT SEES SOMETHING — ok >= MIN_OK in every view (assert identity, not absence: a pick that returned nothing
##      for every cell would read bad=0 on a gate that only counted the wrong ones... here nothing counts as ok);
##   3. NO WRONG CELL — bad == 0. `covered` is a cell a standing prop hides on screen: the pick answers the prop's
##      cell on purpose (`Board3DLive.pick_cell()` asks the prop boxes first), counted apart, never a failure.
##
## Usage:  python3 tools/persistent/pick_gate.py [--maps DORM,GLASS,PLAYGROUND]

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[PICK-GATE]"
MIN_OK = 20
MAPS = {"DORM": "", "GLASS": "14,12;5,12", "PLAYGROUND": ""}
LINE = re.compile(r"\[PICK-CHECK\] (\w+) view=(\w) cells=(\d+) ok=(\d+) covered=(\d+) bad=(\d+) offscreen=(\d+)")


def scenario() -> str:
    steps = ["framing portrait", "zoom 0.4", "centre agent", "frames 20"]
    for view in "NESW":
        steps += ["perspective " + view, "centre agent", "frames 20", "pick_check p" + view]
    return "; ".join(steps + ["quit"])


def boot(map_id: str, grenades: str) -> tuple[dict, str]:
    env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": scenario()}
    if grenades:
        env["INFILTRAITOR_GRENADE_GUS"] = grenades
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True,
                         env=env, timeout=240)
    log = out.stdout + out.stderr
    rows = {}
    for m in LINE.finditer(log):
        rows[m.group(1)] = (m.group(2),) + tuple(int(g) for g in m.groups()[2:])
    return rows, log


def main() -> int:
    parser = argparse.ArgumentParser(description="Touch picking from N, E, S and W")
    parser.add_argument("--maps", default=",".join(MAPS))
    args = parser.parse_args()
    problems = []
    for map_id in [m.strip() for m in args.maps.split(",") if m.strip()]:
        rows, log = boot(map_id, MAPS.get(map_id, ""))
        if "SCRIPT ERROR" in log:
            problems.append("%s: a script error" % map_id)
        for view in "NESW":
            row = rows.get("p" + view)
            if row is None:
                problems.append("%s: p%s never printed" % (map_id, view))
                continue
            seen, cells, ok, covered, bad, offscreen = row
            print("%s %s p%s: view %s, %d cell(s): ok %d, covered by a prop %d, wrong %d, off screen %d"
                  % (TAG, map_id, view, seen, cells, ok, covered, bad, offscreen))
            if seen != view:
                problems.append("%s p%s: the Room reports view %s" % (map_id, view, seen))
            if ok < MIN_OK:
                problems.append("%s p%s: only %d cell(s) picked themselves (need %d)" % (map_id, view, ok, MIN_OK))
            if bad:
                problems.append("%s p%s: %d cell(s) picked a wrong cell" % (map_id, view, bad))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
