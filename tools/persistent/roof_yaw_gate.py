#!/usr/bin/env python3
##
## roof_yaw_gate.py — does a roof open and close the same from every side? (R3D-ROT, 2026-10-02)
##
## WHY IT EXISTS. A roof opens by slab adjacency (`roofs` map section, stored per GU), so which GUs are open is world state and
## must not depend on the camera's yaw; and the picture must show it from every side. `occ_canonical_gate.py` only ever
## looked from N. This boots OCCLUSION_ROOM (a 5x5 ring with a roof) and HALL (a floating roof), turns the camera N, E, S, W
## and in each view puts the agent through the real occlusion path (`occ_bench`) once INSIDE and once OUTSIDE.
##
## PER BOOT:
##   1. THE DATA — the canonical roof digest (`[OCC-BENCH] canonical roof digest <d>, <n> roof GU(s) open`) is the same in
##      the four INSIDE runs, and the same in the four OUTSIDE runs;
##   2. IT SEES SOMETHING — inside opens > 0 GUs, outside opens 0, and the two digests differ (a gate whose roof never opened
##      would read "identical in every view" and pass);
##   3. THE PICTURE — in every view the inside and outside captures differ by more than MIN_PIXELS (the roof is drawn
##      shut outside and gone inside; the agent alone is a few hundred pixels).
##
## Usage:  python3 tools/persistent/roof_yaw_gate.py

import glob
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TAG = "[ROOF-YAW-GATE]"
MIN_PIXELS = 3000
## (map, a cell inside the roof, a cell far outside it, where the camera looks)
## Raw cells, buffer 5 (R3D-FINISH F2, 2026-10-04): the cells the gate was written with at buffer 1 are +4 on each axis.
CASES = [("OCCLUSION_ROOM", "16,16", "6,6", "16,16"), ("OCCLUSION_HALL", "16,16", "6,6", "16,16")]
LINE = re.compile(r"\[OCC-BENCH\] canonical roof digest (\d+), (\d+) roof GU\(s\) open")
CAPTURES = os.path.expanduser("~/Library/Application Support/Godot/app_userdata")


def scenario(inside: str, outside: str, look: str) -> str:
    steps = ["framing portrait", "zoom 0.5", "frames 40"]
    for v in "NESW":
        steps += ["perspective " + v]
        steps += ["occ_bench %s %s 1" % (inside, inside), "centre " + look, "frames 15", "capture ri_" + v]
        steps += ["occ_bench %s %s 1" % (outside, outside), "centre " + look, "frames 15", "capture ro_" + v]
    return "; ".join(steps + ["quit"])


def differing(a: Path, b: Path) -> int:
    diff = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB")).convert("L")
    return sum(1 for v in diff.getdata() if v > 8)


def main() -> int:
    problems = []
    for map_id, inside, outside, look in CASES:
        for old in glob.glob(CAPTURES + "/*/captures/r[io]_*.png"):
            os.remove(old)
        env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1",
               "INFILTRAITOR_SCENARIO": scenario(inside, outside, look)}
        out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True,
                             env=env, timeout=300)
        log = out.stdout + out.stderr
        if "SCRIPT ERROR" in log:
            problems.append("%s: a script error" % map_id)
        rows = [(int(m.group(1)), int(m.group(2))) for m in LINE.finditer(log)]
        if len(rows) != 8:
            problems.append("%s: %d roof digest line(s), wanted 8" % (map_id, len(rows)))
            continue
        ins, outs = rows[0::2], rows[1::2]
        print("%s %s inside %s | outside %s" % (TAG, map_id, ins, outs))
        if len(set(ins)) != 1:
            problems.append("%s: the roof opens differently from different sides (inside %s)" % (map_id, ins))
        if len(set(outs)) != 1:
            problems.append("%s: the roof is not shut the same from every side (outside %s)" % (map_id, outs))
        if ins[0][1] <= 0 or outs[0][1] != 0 or ins[0][0] == outs[0][0]:
            problems.append("%s: the control failed: inside %s, outside %s" % (map_id, ins[0], outs[0]))
        tmp = Path("/tmp/roof_yaw_gate") / map_id
        tmp.mkdir(parents=True, exist_ok=True)
        for v in "NESW":
            files = {}
            for kind in ("ri", "ro"):
                found = glob.glob(CAPTURES + "/*/captures/%s_%s.png" % (kind, v))
                if found:
                    shutil.copy(found[0], tmp / ("%s_%s.png" % (kind, v)))
                    files[kind] = tmp / ("%s_%s.png" % (kind, v))
            if len(files) != 2:
                problems.append("%s view %s: a capture is missing" % (map_id, v))
                continue
            n = differing(files["ri"], files["ro"])
            print("%s %s view %s: inside vs outside differ in %d px" % (TAG, map_id, v, n))
            if n < MIN_PIXELS:
                problems.append("%s view %s: inside and outside look the same (%d px)" % (map_id, v, n))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
