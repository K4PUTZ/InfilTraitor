#!/usr/bin/env python3
##
## smoke_boot.py — does the game BOOT and ROTATE, on a few maps? (2026-09-25)
##
## The cheapest check that catches what the linter cannot: an untyped call to a deleted method, a scene that lost a node, a
## null `@onready`, a load path that raises. It boots each map once, waits a few frames, rotates E then N (which rebuilds the
## whole board twice), and fails on a non-zero exit, a `SCRIPT ERROR`, or an `ERROR:` line. There is deliberately NO grenade
## and NO shot here: the identity gates (`verify.py full`) own those, and they are run on request, not on every change.
##
## ~15 s per map. It does not need the machine to itself (no frame-timing dependence), so an open editor does not matter.
##
## Usage:  python3 tools/persistent/smoke_boot.py [--maps PLAYGROUND,GLASS,SIGMA_01]

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SCENARIO = "framing portrait; frames 90; perspective E; frames 30; perspective N; frames 30; quit"
## Not errors of ours: the actor frame cache warns about loading baked PNGs as images on every boot (a warning, never an ERROR).
IGNORE = ("Loaded resource as image file",)


def boot(map_id: str):
    env = {**os.environ, "INFILTRAITOR_MAP": map_id, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": SCENARIO}
    proc = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True, text=True,
                          env=env, timeout=180)
    log = proc.stdout + proc.stderr
    bad = [l.strip() for l in log.splitlines()
           if ("SCRIPT ERROR" in l or l.lstrip().startswith("ERROR:")) and not any(i in l for i in IGNORE)]
    return proc.returncode, bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--maps", default="PLAYGROUND,GLASS")
    args = ap.parse_args()
    failed = False
    for map_id in [m.strip() for m in args.maps.split(",") if m.strip()]:
        try:
            rc, bad = boot(map_id)
        except subprocess.TimeoutExpired:
            print("[SMOKE] %s: TIMEOUT (180 s) — the boot hung" % map_id)
            failed = True
            continue
        ok = rc == 0 and not bad
        print("[SMOKE] %s: %s" % (map_id, "ok" if ok else "FAIL (exit %s, %d error line(s))" % (rc, len(bad))))
        for l in bad[:6]:
            print("[SMOKE]   %s" % l[:200])
        failed = failed or not ok
    print("[SMOKE] %s" % ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
