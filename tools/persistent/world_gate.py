#!/usr/bin/env python3
##
## world_gate.py — do the overlays that draw in the AIR stand on maths that survives a turn? (R3D-ROT, 2026-10-02)
##
## WHY IT EXISTS. The tracer, the throw arc, the aim dome, the shrapnel star and the ceiling lamps draw through
## `WorldCanvas3D`. They were only ever seen in captures. Two things they all rest on can be measured without driving a shot:
##   1. `lift()` puts a 2D point at a world point through the BASE lattice basis, so it is world state: the same in every view;
##   2. `screen_axes()` is the pixels one grid step moves by in the LIVE view; an overlay that derives a direction from the
##      grid (the dome's tilt, the star's rays) uses it, so it must be what the camera really does to a grid step.
## The `world_check` scenario step prints both per view. (What each overlay does with them is still judged on a capture.)
##
## PER BOOT (PLAYGROUND, N, E, S, W in one run):
##   1. THE LIFT — the digest of the five lifted points is identical in the four views;
##   2. THE AXES — cos(screen_axes, camera step) > 0.9999 for x and y in every view, and the zoom (viewport px per canvas px)
##      is the same for both axes and for every view;
##   3. IT SEES A TURN — the four views' x axes are pairwise different (a gate whose camera never turned would read
##      "consistent" four times).
##
## Usage:  python3 tools/persistent/world_gate.py

import math
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[WORLD-GATE]"
LINE = re.compile(r"\[WORLD-CHECK\] (\w+) view=(\w) lift=(-?\d+) ax=(-?[\d.]+),(-?[\d.]+) ay=(-?[\d.]+),(-?[\d.]+) "
                  r"cos_x=(-?[\d.]+) cos_y=(-?[\d.]+) zoom_x=([\d.]+) zoom_y=([\d.]+)")


def scenario() -> str:
    steps = ["framing portrait", "zoom 0.5", "centre agent", "frames 30"]
    for v in "NESW":
        steps += ["perspective " + v, "frames 20", "world_check w" + v]
    return "; ".join(steps + ["quit"])


def main() -> int:
    env = {**os.environ, "INFILTRAITOR_MAP": "PLAYGROUND", "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": scenario()}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True, env=env,
                         timeout=240)
    log = out.stdout + out.stderr
    problems = []
    if "SCRIPT ERROR" in log:
        problems.append("a script error")
    rows = {}
    for m in LINE.finditer(log):
        g = m.groups()
        rows[g[0]] = {"view": g[1], "lift": int(g[2]), "ax": (float(g[3]), float(g[4])), "cos_x": float(g[7]),
                      "cos_y": float(g[8]), "zoom_x": float(g[9]), "zoom_y": float(g[10])}
    for v in "NESW":
        if "w" + v not in rows:
            problems.append("w%s never printed" % v)
    if problems:
        for p in problems:
            print("%s   %s" % (TAG, p))
        print("%s FAIL" % TAG)
        return 1
    for v in "NESW":
        r = rows["w" + v]
        print("%s view %s (%s): lift %d, axis x %s, cos %.5f / %.5f, zoom %.4f / %.4f"
              % (TAG, v, r["view"], r["lift"], r["ax"], r["cos_x"], r["cos_y"], r["zoom_x"], r["zoom_y"]))
        if r["view"] != v:
            problems.append("w%s: the Room reports view %s" % (v, r["view"]))
        if r["cos_x"] < 0.9999 or r["cos_y"] < 0.9999:
            problems.append("w%s: screen_axes is not what the camera does (cos %.5f / %.5f)" % (v, r["cos_x"], r["cos_y"]))
        if abs(r["zoom_x"] - r["zoom_y"]) > 0.01 * r["zoom_x"]:
            problems.append("w%s: the axes disagree on scale (%.4f vs %.4f)" % (v, r["zoom_x"], r["zoom_y"]))
    if len({rows["w" + v]["lift"] for v in "NESW"}) != 1:
        problems.append("lift() moved with the view: %s" % [rows["w" + v]["lift"] for v in "NESW"])
    zooms = [rows["w" + v]["zoom_x"] for v in "NESW"]
    if max(zooms) - min(zooms) > 0.01 * max(zooms):
        problems.append("the zoom changed between views: %s" % zooms)
    axes = [rows["w" + v]["ax"] for v in "NESW"]
    for i in range(4):
        for j in range(i + 1, 4):
            a, b = math.atan2(axes[i][1], axes[i][0]), math.atan2(axes[j][1], axes[j][0])
            delta = abs((a - b + math.pi) % (2 * math.pi) - math.pi)
            if delta < math.radians(10):
                problems.append("the x axes of views %s and %s are the same: the camera did not turn" % ("NESW"[i], "NESW"[j]))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
