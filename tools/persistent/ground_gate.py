#!/usr/bin/env python3
##
## ground_gate.py — gameplay reads the ground from `GroundGrid`, and ONE ground serves every view (R3D-ROT, 2026-10-02).
##
## Boots the real game per map with the scenario
##     ground_check n; perspective E; ground_check e; perspective S; ground_check s; perspective W; ground_check w
## and requires for every map:
##   1. THE DIGEST: walkability, selectable cells, the movement flood (cell -> cost), a path to every 7th reachable cell,
##      and the visible/total cell counts equal the RECORDED one (the N digest of the R3D-END gate, unchanged);
##   2. ONE WORLD: the digest in E, S and W equals the one in N. Before R3D-ROT a turn re-laid the map out and the four
##      views were four different grids (the gate used to record all four and demand they differ); the camera now turns
##      over a single world, so a view that moves a single cell is a regression;
##   3. THE CONTROL: two different maps do not share a digest (a gate that read one cached answer would fail here).
##
## HISTORY. Until R3D-END this gate also checked in-process that the 2D tile layer and `GroundGrid` agreed cell by cell and
## that two boots (3D / 2D) gave identical digests; the last such run (END-0, 2026-09-24, `34881f81`) read IDENTICAL for all
## 16 map/views and its N digests are the ones recorded here. A map edited on purpose changes its digest: re-record with
## `--update` and say so in the commit.
##
## Usage:  python3 tools/persistent/ground_gate.py [--maps PLAYGROUND,GLASS,SIGMA_01,PLAYGROUND_2] [--update]

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
LINE = re.compile(r"\[GROUND-CHECK\] (\w) size \((\d+), (\d+)\) \| (walk .*)$")

RECORDED = {  # map -> the one digest every view must give (the N digest of the R3D-END gate). PLAYGROUND, GLASS and PLAYGROUND_2 re-recorded 2026-10-04 at buffer 5 (R3D-FINISH F2); their reach / paths counts are unchanged, SIGMA_01 (already buffer 5) kept its digest
    "GLASS": "walk b6b5363ee219535d785b33571b6ff7f9 select 831481e658f20c479cda46c23d2b24a7 reach 69 c8d6d5233848362e0e59b32c1c918ff9 paths 10 a2b2472e536cd8b5945ea31364445423 | view 95/1008",
    "PLAYGROUND": "walk 3b86473901f3bd5a7891fab2f3f0bf09 select be20cc67a4d78fc3147c871fe5eef74b reach 84 36cb5a0ccee9dc448e7b1464ef70970c paths 12 64a8ce123ed447561bfb17cdaff845fe | view 95/1728",
    "PLAYGROUND_2": "walk a2620f80fce4bd1af02f09b9c4fb3259 select 6ea5cedd888b0737fd5cbc4d1f2b0da7 reach 71 e4aa0b80d1ed3e3a01a7ff227aa4d55e paths 11 e523665e541d6335efc84fe55505c02c | view 95/1392",
    "SIGMA_01": "walk fc8bb081d1af2f96fbc3d1c8c242fe3f select fbfa1b2c35d05c72f391613c48079784 reach 57 dd9bad12e38fe64b0ac4560d96b0d2eb paths 9 98caa4b463464191660302fef80fa3a7 | view 91/1288",
}


def boot(map_id: str):
    env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": SCENARIO}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True,
                         env=env, timeout=200)
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
    ap.add_argument("--update", action="store_true", help="print the current digests instead of comparing")
    args = ap.parse_args()
    problems = []
    digests = {}
    for map_id in [m.strip() for m in args.maps.split(",") if m.strip()]:
        rows, err = boot(map_id)
        if err:
            problems.append("%s: the boot reported a script error" % map_id)
        if sorted(rows) != ["e", "n", "s", "w"]:
            problems.append("%s: missing views (%s)" % (map_id, sorted(rows)))
            continue
        if args.update:
            print('    "%s": "%s",' % (map_id, rows["n"][3]))
            continue
        ref = RECORDED.get(map_id)
        digests[map_id] = rows["n"][3]
        for view in "nesw":
            row = rows[view]
            print("%s %s %s: %sx%s; digest %s" % (TAG, map_id, view, row[1], row[2],
                  "IDENTICAL" if row[3] == ref else ("NOT RECORDED" if ref is None else "DIFFERENT")))
            if ref is None:
                problems.append("%s: no recorded digest (run --update)" % map_id)
                break
            if row[3] != ref:
                problems.append("%s %s: the digest differs from the recorded one\n     now      %s\n     recorded %s"
                                % (map_id, view, row[3], ref))
    if len(digests) > 1 and len(set(digests.values())) == 1:
        problems.append("every map gave one digest — the control failed")
    for p in problems:
        print("%s   %s" % (TAG, p))
    if not args.update:
        print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
