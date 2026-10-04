#!/usr/bin/env python3
##
## canvas_gate.py — does any overlay paint the 2D canvas instead of the 3D board? (RETIRE-2D, 2026-10-03)
##
## WHY IT EXISTS. Every ground / world overlay is a `Node2D` whose `_draw()` is mirrored onto the 3D board by a `GroundCanvas3D` /
## `WorldCanvas3D` (its `_ground` / `_world`). An overlay with no such target while visible falls back to painting the 2D canvas:
## over the board, with no depth test, outside every other gate's sight (the pixel gate compares what it captures, and the boot
## state looked right). It was real: until 2026-10-03 the tracer, the trail, the noise overlay, the ceiling lamps, the occlusion
## overlay and the F3 voxel ruler were built AFTER `load_map()` attached the others, and stayed on the canvas until the first F2.
## The `canvas_check` scenario step prints `[CANVAS-CHECK] <name> examined=N shown=S canvas=M <names>`.
##
## ONE BOOT (PLAYGROUND), the states that show different overlays: idle, the grenade AIM preview, the throw in flight, landed, the
## blast, after it, and the dev / light / heat / numbers / ruler view modes. Requires:
##   1. EVERY STATE PRINTED, `examined` >= MIN_EXAMINED (a check that looked at nothing proves nothing);
##   2. NOTHING ON THE CANVAS — canvas == 0 in every state;
##   3. THE STATES ARE REAL — more overlays are shown while AIMING than at idle, and in the ruler mode than at idle (a state that
##      showed nothing new would pass 2 trivially).
##
## Usage:  python3 tools/persistent/canvas_gate.py

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[CANVAS-GATE]"
MIN_EXAMINED = 20
STATES = ["idle", "aim", "flight", "landed", "blast", "after", "dev", "light", "heat", "numbers", "ruler"]
LINE = re.compile(r"\[CANVAS-CHECK\] (\w+) examined=(\d+) shown=(\d+) canvas=(\d+) ?(.*)")
SCENARIO = ("framing landscape; frames 60; centre agent; zoom 1.2; frames 30; canvas_check idle; aim 27,12; frames 15; canvas_check aim; "
            "throw 0 27,12; frames 20; canvas_check flight; frames 70; canvas_check landed; frames 150; canvas_check blast; "
            "frames 200; canvas_check after; view_mode DEV; frames 10; canvas_check dev; view_mode LIGHT; frames 10; canvas_check light; "
            "view_mode HEAT; frames 10; canvas_check heat; view_mode NUMBERS; frames 10; canvas_check numbers; "
            "view_mode RULER; frames 10; canvas_check ruler; quit")


def main() -> int:
    env = {**os.environ, "INFILTRAITOR_MAP": "PLAYGROUND", "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": SCENARIO,
           "INFILTRAITOR_SEED_GRENADES": "1", "INFILTRAITOR_GRENADE_GUS": "24,10;27,9"}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--fixed-fps", "60", "--position", "4000,4000"], capture_output=True,
                         text=True, env=env, timeout=180)
    log = out.stdout + out.stderr
    problems = []
    if "SCRIPT ERROR" in log:
        problems.append("a script error")
    rows = {}
    for m in LINE.finditer(log):
        rows[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5).strip())
    for state in STATES:
        if state not in rows:
            problems.append("%s never printed" % state)
            continue
        examined, shown, canvas, names = rows[state]
        print("%s %-8s examined %d, shown %d, on the canvas %d %s" % (TAG, state, examined, shown, canvas, names))
        if examined < MIN_EXAMINED:
            problems.append("%s: only %d overlay(s) examined (need %d)" % (state, examined, MIN_EXAMINED))
        if canvas:
            problems.append("%s: %d overlay(s) paint the 2D canvas: %s" % (state, canvas, names))
    if all(s in rows for s in ("idle", "aim", "ruler")):
        if rows["aim"][1] <= rows["idle"][1]:
            problems.append("aiming shows no more overlays than idle (%d vs %d): the state did not happen" % (rows["aim"][1], rows["idle"][1]))
        if rows["ruler"][1] <= rows["idle"][1]:
            problems.append("the ruler mode shows no more overlays than idle (%d vs %d)" % (rows["ruler"][1], rows["idle"][1]))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
