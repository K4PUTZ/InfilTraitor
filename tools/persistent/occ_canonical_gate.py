#!/usr/bin/env python3
##
## occ_canonical_gate.py — the identity gate for anything that changes HOW the cutaway's occlusion set or its
## geometry is built (R3D-7, 2026-09-20).
##
## WHY CANONICAL. The first gate hashed `str(occluded)` and the vertex arrays as emitted, so it failed the moment
## a change reordered the emission (the roofs went per-GU) although the picture and the set were the same. These
## digests are ORDER-INDEPENDENT: the occluded columns with their ring and level span, sorted; and every outline
## segment and every cap vertex (with its colour), sorted. Two different sets or two different pictures cannot
## share one; two orderings of the same thing do.
##
## It boots the real game once per case (`INFILTRAITOR_SCENARIO="... occ_bench A B 41"`, the scenario step that
## alternates the agent between two cells through the real `_recompute_occlusion` path) and compares the two
## `[OCC-BENCH]` digests with the recorded ones. The same digests print on a handset: run the scenario there with
## `MAP=` and `SCENARIO=` in the device flags file (see `device_run.py`) and compare by eye or with `--device-log`.
##
## Usage:
##     python3 tools/persistent/occ_canonical_gate.py                 # all cases, exit 1 on any difference
##     python3 tools/persistent/occ_canonical_gate.py --only ROOM     # cases whose label contains ROOM
##     python3 tools/persistent/occ_canonical_gate.py --update        # print the current digests (after a change
##                                                                    # that is MEANT to alter the set or the geometry)
##
## The recorded values were taken on the code of commit `b21252d4` and reproduced after the per-GU roof
## representation (`15fbdc52`), on the desktop and on the Moto g04s. A fixture change (a map edited) changes its
## digests: re-record with --update and say so in the commit.
##
## RE-RECORDED 2026-10-04 (R3D-FINISH F2: every map's buffer grew from 1 to 5, so every raw cell moved +4 per axis and the agent
## cells below moved with it; the digests carry raw positions). Verified not to hide a change in the SET: OCCLUSION_ROOM at buffer 1
## (cells 12,12 / 13,12) and at buffer 5 (cells 16,16 / 17,16) both report 1 764 occluded columns and 25 open roof GUs; the old digest
## reproduced exactly at buffer 1 (2201133523). PLAYGROUND's digests are those of an EMPTY set (it has no roof): that case never saw
## anything, and still does not. SIGMA_01 already ran at buffer 5 and kept its digests.

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"

## (label, map id, agent cell A, agent cell B, canonical set digest, canonical cutaway geometry digest)
CASES = [
    ("ROOM (5x5 ring + roof, agent inside)", "OCCLUSION_ROOM", "16,16", "17,16", 2281665223, 2707279558),
    ("HALL (floating 15x15 roof)", "OCCLUSION_HALL", "16,16", "17,16", 165414134, 2930668353),
    ("NEST (three nested volumes)", "OCCLUSION_NEST", "8,8", "8,10", 331712424, 1614825779),
    ("GLASS", "GLASS", "20,19", "17,17", 3834045110, 1746791528),
    ("PLAYGROUND", "PLAYGROUND", "31,13", "17,9", 2691998715, 163057982),
    ("SIGMA_01 (a real level)", "SIGMA_01", "9,34", "5,32", 2010404612, 3597628886),
    ("ROOM, second pair of cells", "OCCLUSION_ROOM", "16,16", "15,15", 1501394400, 1196143088),
]


def run_case(map_id: str, a: str, b: str) -> tuple[int, int]:
    env = {"INFILTRAITOR_MAP": map_id,
           "INFILTRAITOR_SCENARIO": "framing portrait; frames 60; occ_bench %s %s 41; quit" % (a, b)}
    import os
    out = subprocess.run([GODOT, "--path", str(ROOT)], capture_output=True, text=True,
                         env={**os.environ, **env}, timeout=180).stdout
    set_digest = re.search(r"canonical set digest (\d+)", out)
    geo_digest = re.search(r"cutaway geometry digest \d+, canonical (\d+)", out)
    if not set_digest or not geo_digest:
        print("  no digest in the output (did the scenario abort?):")
        print("\n".join(l for l in out.splitlines() if "SCENARIO" in l or "ERROR" in l)[:800])
        return -1, -1
    return int(set_digest.group(1)), int(geo_digest.group(1))


def main() -> int:
    ap = argparse.ArgumentParser(description="Canonical identity gate for the occlusion set and the cutaway geometry.")
    ap.add_argument("--only", default=None, help="run the cases whose label contains this text")
    ap.add_argument("--update", action="store_true", help="print the current digests instead of comparing")
    args = ap.parse_args()
    failed = 0
    for label, map_id, a, b, want_set, want_geo in CASES:
        if args.only and args.only.lower() not in label.lower():
            continue
        got_set, got_geo = run_case(map_id, a, b)
        if args.update:
            print('    ("%s", "%s", "%s", "%s", %d, %d),' % (label, map_id, a, b, got_set, got_geo))
            continue
        ok = got_set == want_set and got_geo == want_geo
        print("%s %-42s set %s geometry %s" % ("✓" if ok else "✗", label,
              "same" if got_set == want_set else "%d != %d" % (got_set, want_set),
              "same" if got_geo == want_geo else "%d != %d" % (got_geo, want_geo)))
        failed += 0 if ok else 1
    if not args.update:
        print("[occ_canonical_gate] %s" % ("all identical" if failed == 0 else "%d case(s) differ" % failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
