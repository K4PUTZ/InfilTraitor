#!/usr/bin/env python3
##
## material_videos.py — one short video of a SHOT and one of an EXPLOSION on every PLAYGROUND material (2026-10-17, the Director's review of the soft materials).
##
## Each material has a wall (a block trio, a quitanda for cardboard and fabric, a glass box) at map y=2, a rail framing it, and the takes `shot_<m>` /
## `blast_<m>` in the map's `capture` section. A shot needs the agent and the guard put in front of the wall (the scenario step `shoot 0` reads the dev flags
## SHOT_AGENT_CELL / SHOT_GUARD_CELL); this script sets them from the wall's centre x (buffered coordinates: map x + 5, agent y 11, guard y 9 = map y 6 / 4) and
## runs `capture.py` once per take. The videos are `videos/PLAYGROUND_<take>.mp4` (git-ignored).
##
##     python3 tools/persistent/material_videos.py                     # every material, shot and blast
##     python3 tools/persistent/material_videos.py --only fabric,glass --events shot
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRE_X = {"concrete": 3, "metal": 8, "stone": 13, "wood": 18, "brick": 23, "cardboard": 27, "fabric": 31, "plywood": 35, "glass": 39}
BUFFER = 5


def main() -> int:
    ap = argparse.ArgumentParser(description="a shot and an explosion video per PLAYGROUND material")
    ap.add_argument("--only", default="", help="comma list of materials (default: all)")
    ap.add_argument("--events", default="shot,blast", help="shot, blast or both")
    ap.add_argument("--map", default="PLAYGROUND")
    args = ap.parse_args()
    materials = [m for m in CENTRE_X if not args.only or m in args.only.split(",")]
    failed = []
    for material in materials:
        for event in args.events.split(","):
            take = "%s_%s" % (event, material)
            env = dict(os.environ)
            if event == "shot":
                x = CENTRE_X[material] + BUFFER
                env["INFILTRAITOR_SHOT_AGENT_CELL"] = "%d,11" % x
                env["INFILTRAITOR_SHOT_GUARD_CELL"] = "%d,9" % x
            print("[MATERIAL-VIDEOS] %s ..." % take, flush=True)
            r = subprocess.run([sys.executable, str(ROOT / "tools/persistent/capture.py"), "--map", args.map, "--take", take],
                               env=env, capture_output=True, text=True)
            video = ROOT / "videos" / ("%s_%s.mp4" % (args.map, take))
            ok = r.returncode == 0 and video.exists()
            print("[MATERIAL-VIDEOS] %s %s" % (take, "-> %s" % video if ok else "FAILED\n%s" % (r.stdout + r.stderr)[-600:]), flush=True)
            if not ok:
                failed.append(take)
    print("[MATERIAL-VIDEOS] done, %d failed %s" % (len(failed), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
