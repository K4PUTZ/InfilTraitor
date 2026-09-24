#!/usr/bin/env python3
##
## mirror_gate.py — does the 3D board draw the glass cracks and the floor piles the game holds? (R3D-8 step 2)
##
## WHY IT EXISTS. `GlassCrackMirror3D` and `FloorPile3D` are twins of things the (hidden) 2D renderer creates: a state
## identity gate (`board_probe.py gate`) cannot see a crack that never got a quad or a pile that never got a mesh.
## The `mirror_check` scenario step prints `[MIRROR-CHECK] <label> cracks records=R twins=T piles base=B sprites=S drawn=D`.
##
## PER BOOT (GLASS, two grenades, run twice):
##   1. THE CONTROL — before any grenade every count is 0 (a gate that read a non-zero baseline would measure the map);
##   2. IT SEES SOMETHING — after each grenade records > 0 and piles > 0 (assert identity, not absence);
##   3. THE MIRROR — twins == records, and drawn == sprites == base;
##   4. DETERMINISM — the two boots print identical check lines.
## Earned red-before-green 2026-09-23 (see the R3D-8 commit).
##
## Usage:  python3 tools/persistent/mirror_gate.py

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[MIRROR-GATE]"
SCENARIO = ("mirror_check m0; detonate 0; frames 300; mirror_check m1; detonate 1; frames 300; "
            "mirror_check m2; quit")
LINE = re.compile(r"\[MIRROR-CHECK\] (\w+) cracks records=(-?\d+) twins=(-?\d+) piles base=(-?\d+) "
                  r"sprites=(-?\d+) drawn=(-?\d+)")


def boot() -> tuple[dict, str]:
    env = {**os.environ, "INFILTRAITOR_MAP": "GLASS", "INFILTRAITOR_RNG_SEED": "1",
           "INFILTRAITOR_GRENADE_GUS": "14,12;5,12", "INFILTRAITOR_SCENARIO": SCENARIO}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True,
                         text=True, env=env, timeout=300)
    log = out.stdout + out.stderr
    checks = {}
    for m in LINE.finditer(log):
        checks[m.group(1)] = tuple(int(g) for g in m.groups()[1:])
    return checks, log


def main() -> int:
    runs = []
    problems = []
    for k in (1, 2):
        checks, log = boot()
        runs.append(checks)
        if "SCRIPT ERROR" in log:
            problems.append("run %d reported a script error" % k)
        for label in ("m0", "m1", "m2"):
            if label not in checks:
                problems.append("run %d never printed %s" % (k, label))
        if any(label not in checks for label in ("m0", "m1", "m2")):
            continue
        print("%s run %d: %s" % (TAG, k, "; ".join("%s %s" % (l, checks[l]) for l in ("m0", "m1", "m2"))))
        if any(v != 0 for v in checks["m0"]):
            problems.append("run %d: the baseline is not empty %s" % (k, checks["m0"]))
        for label in ("m1", "m2"):
            records, twins, base, sprites, drawn = checks[label]
            if records <= 0 or base <= 0:
                problems.append("run %d %s: nothing to mirror (records %d, piles %d)" % (k, label, records, base))
            if twins != records:
                problems.append("run %d %s: %d crack twin(s) for %d record(s)" % (k, label, twins, records))
            if not (drawn == sprites == base):
                problems.append("run %d %s: piles base %d, sprites %d, drawn in 3D %d" % (k, label, base, sprites, drawn))
    if len(runs) == 2 and runs[0] != runs[1]:
        problems.append("the two boots differ: %s vs %s" % (runs[0], runs[1]))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
