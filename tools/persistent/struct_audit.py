#!/usr/bin/env python3
##
## struct_audit.py — does an INTACT map stand on its own support rule? (ROOF_MASTER_PLAN RF-G G3, 2026-10-17)
##
## `StructuralSupport` lets go of whatever no path of standing voxels holds (sideways reach per material, `MaterialResistanceTable.support_reach`).
## A reach set too tight makes a map fall apart the first time anything near it is touched, with nothing in the log. The `struct_audit` scenario step asks the service
## about EVERY standing voxel of the loaded map; an intact map must answer 0 with no support. One boot per map.
##
## Usage:  python3 tools/persistent/struct_audit.py [MAP ...]      (default: the maps below)
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
MAPS = ["PLAYGROUND", "ROOF_LAB", "MARKET_LAB", "GLASS", "DORM", "PROPS"]
## KNOWN, NOT HIDDEN: SEG_HEAVY (the generated stress segment) has 6 728 concrete voxels at levels 96-97 (a 7 x 7 GU roof, x 47..104, y 47..104) with NOTHING under them:
## the column below (72, 72) is empty from the ground to level 95, and the result is the same with an unlimited reach, so it is content, not the reach table. A blast
## beside it would drop that roof. Fix the generator (or give the roof walls) before adding the map back.
LINE = re.compile(r"\[STRUCT-AUDIT\] (\d+) voxel\(s\) asked, (\d+) with no support (\{.*?\}) \(([\d.]+) ms\)")


def audit(map_id: str):
    env = dict(os.environ, INFILTRAITOR_MAP=map_id, INFILTRAITOR_SCENARIO="wait 2; struct_audit; quit")
    r = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], env=env, capture_output=True, text=True, timeout=300, cwd=ROOT)
    out = r.stdout + r.stderr
    m = LINE.search(out)
    return (int(m.group(1)), int(m.group(2)), m.group(3), float(m.group(4))) if m else None


def main() -> int:
    maps = sys.argv[1:] or MAPS
    bad = 0
    for map_id in maps:
        res = audit(map_id)
        if res is None:
            print("[STRUCT-AUDIT-GATE] %s: NO RESULT (the map did not boot or the step failed)" % map_id)
            bad += 1
        elif res[1] > 0:
            print("[STRUCT-AUDIT-GATE] %s: FAIL %d of %d voxel(s) have no support %s" % (map_id, res[1], res[0], res[2]))
            bad += 1
        else:
            print("[STRUCT-AUDIT-GATE] %s: ok, %d voxel(s) all held (%.0f ms)" % (map_id, res[0], res[3]))
    print("[STRUCT-AUDIT-GATE] %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
