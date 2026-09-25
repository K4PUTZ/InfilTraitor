#!/usr/bin/env python3
##
## ground_gate.py — gameplay reads the ground from `GroundGrid`, not from a TileMapLayer (R3D-11), and it keeps reading the
## same ground (R3D-END).
##
## Boots the real game per map with the scenario
##     ground_check n; perspective E; ground_check e; perspective S; ground_check s; perspective W; ground_check w
## and requires for every map and view:
##   1. THE DIGESTS: walkability, selectable cells, the movement flood (cell -> cost), a path to every 7th reachable cell,
##      and the visible/total cell counts equal the RECORDED ones below;
##   2. THE CONTROL: the four views are not the same picture (a rotated PLAYGROUND has a different size / reach), so a gate that
##      read one cached answer would fail here.
##
## WHERE THE RECORDED DIGESTS COME FROM. Until R3D-END this gate booted each map twice, on the 3D board and on the 2D board
## (`RENDER3D=0`, whose floor layer still held tiles), checked in-process that the tile layer and `GroundGrid` agreed cell by
## cell (walk_mismatch 0, point_mismatch 0) and required the two boots' digests to be identical. The last such run (R3D-END
## step END-0, 2026-09-24, on `34881f81`, the last commit with the 2D board) read IDENTICAL for all 16 map/views, with 0
## mismatches in-process; those 3D digests are the ones recorded here. A map edited on purpose changes its digests:
## re-record with `--update` and say so in the commit.
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

RECORDED = {
    "GLASS": {
        "n": "walk 0b053874f39bf4fb6315611e57db33b8 select f3e7d9e337f02f0849cb67e02fa7a36b reach 69 fbf0374674e10b0a7e45b99a253e8ba9 paths 10 49448391fb6e8830df78e9a4e48a11f5 | view 86/560",
        "e": "walk 52771707181bfb57b5c947d8610bb9ae select a7deac3c1716b01d8122d05f0c7671bc reach 69 1e6fef5fcc1051c12de27dd17d8bcb68 paths 10 4a087f8d90398f5f7d930f1eab570934 | view 86/560",
        "s": "walk 0b053874f39bf4fb6315611e57db33b8 select d2a335e5536e5aca27ac7c4e9544dc34 reach 69 037faccdedfb3b6cfb70623fda6bfd04 paths 10 f7d86accd517564b6805c613921d72c9 | view 86/560",
        "w": "walk 52771707181bfb57b5c947d8610bb9ae select 890027f9c6fc360203431937aed86f21 reach 69 9528b23688504728cc96fef2f926df44 paths 10 345dfb51f9d4a589c4090d969276e013 | view 86/560",
    },
    "PLAYGROUND": {
        "n": "walk 1eb876a5bfdb495f1746d1b26669adff select 7ec97830f25467d3a451aada33bec827 reach 84 c46d752e7503cf4353a283949f73bd41 paths 12 e97045cdba41cfa2d4120d19163b9094 | view 95/1104",
        "e": "walk 8afc09d0eb8ae3b022c3daf7ae9fc2de select 221ef398229ba6569c0f921d6ba40493 reach 84 cbd5d0041297124d1ad26efb6f577456 paths 12 645bf6881523bc6895545325448974ab | view 95/1104",
        "s": "walk 1eb876a5bfdb495f1746d1b26669adff select 4dabec09501f921eb233a890412e6c47 reach 84 f1ac8ed6ef9488baac12e6d2bd96a04a paths 12 e9a5f508d4e60578d5b10afc8da8535f | view 95/1104",
        "w": "walk 8afc09d0eb8ae3b022c3daf7ae9fc2de select 6ec5bb86aa8ae5a9417e1294b808a359 reach 84 e54ef8ce99bb806a50f52810d42f20ad paths 12 6375f2b038af938d1ca641bf5dcf6cfd | view 95/1104",
    },
    "PLAYGROUND_2": {
        "n": "walk 793d35a7f40b1ab2704ed41036ddcc47 select 7dbae2d082261d7cdb9d7c9cd3665956 reach 71 7c5f83bb9db12c411836dbd8a246eff7 paths 11 22201d4163da25a05e1b3c3e923e8cf5 | view 70/800",
        "e": "walk d2f20c1e07fe1dfb38e08cecd7b30704 select f7fd6af000108ede547e7670645895c3 reach 71 b317137e3839daf1b82238830ff14fc8 paths 11 e0aa2d47507d10c8db8c276b1dd4d3e6 | view 76/800",
        "s": "walk 793d35a7f40b1ab2704ed41036ddcc47 select 024e7b26519f8e50b032f597398e47b0 reach 71 482687fe412ece91aaa43f964628e768 paths 11 f79c8ff9726d7a47a2c99b3e3dd479de | view 70/800",
        "w": "walk d2f20c1e07fe1dfb38e08cecd7b30704 select 9cfac70275934ff1195ea52ddbe0042d reach 71 8c2a49d58c6da4f041c029fe9685325e paths 11 903b4789874e1aebb7cc89302da222be | view 76/800",
    },
    "SIGMA_01": {
        "n": "walk fc8bb081d1af2f96fbc3d1c8c242fe3f select fbfa1b2c35d05c72f391613c48079784 reach 57 dd9bad12e38fe64b0ac4560d96b0d2eb paths 9 98caa4b463464191660302fef80fa3a7 | view 91/1288",
        "e": "walk d95abff3398f78ba001d55e696de320f select 2a1a4d30afe552f951e872393f00b581 reach 57 73ba8ed70f9da1869cae292492680f92 paths 9 14a0a72d81c0a65a83f2b7ca2576e46b | view 91/1288",
        "s": "walk fc8bb081d1af2f96fbc3d1c8c242fe3f select 6a2ebaa8b8491d8e544db40ede597c55 reach 57 93707837b47154bc03ac86699565dd40 paths 9 613c64f06083ccec4c3d0624df50be0b | view 91/1288",
        "w": "walk d95abff3398f78ba001d55e696de320f select 1a746d70bc99bfb7c111578c2d7dbd2b reach 57 5e2b822cc80409b742fbf66d8ab7c58a paths 9 1a2708e6e08e8c970b6b4825dd6e904b | view 91/1288",
    },
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
    for map_id in [m.strip() for m in args.maps.split(",") if m.strip()]:
        rows, err = boot(map_id)
        if err:
            problems.append("%s: the boot reported a script error" % map_id)
        if sorted(rows) != ["e", "n", "s", "w"]:
            problems.append("%s: missing views (%s)" % (map_id, sorted(rows)))
            continue
        if args.update:
            print('    "%s": {' % map_id)
            for view in "nesw":
                print('        "%s": "%s",' % (view, rows[view][3]))
            print("    },")
            continue
        for view in "nesw":
            row = rows[view]
            ref = RECORDED.get(map_id, {}).get(view)
            same = ref == row[3]
            print("%s %s %s: %sx%s; digests %s" % (TAG, map_id, view, row[1], row[2],
                  "IDENTICAL" if same else ("NOT RECORDED" if ref is None else "DIFFERENT")))
            if not same:
                problems.append("%s %s: the digests differ from the recorded ones\n     now      %s\n     recorded %s"
                                % (map_id, view, row[3], ref))
        if len({rows[v][3] for v in "nesw"}) == 1:
            problems.append("%s: all four views gave one digest — the control failed" % map_id)
    for p in problems:
        print("%s   %s" % (TAG, p))
    if not args.update:
        print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
