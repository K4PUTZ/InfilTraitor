#!/usr/bin/env python3
##
## stress_scenario.py — the COMBINED STRESS SCENARIO (roadmap step A1, 2026-10-07; map: `maps/STRESS.map.json`).
##
## WHAT STACKS: the dense map (24 guards, 60 props, 14 lights, 8 materials, a glass hall under a glass roof), a first grenade into the
## brick/concrete rooms, a SECOND grenade into the glass hall thrown while the first blast's consequence is still playing
## (`--gap-frames`, default 150: after the action lock lifts, before the smoke has cleared), then a shot, all through the real entry
## points (`ScenarioRunner`). `--mode sequential` waits the first blast out (the control: the same events, not stacked).
##
## USAGE
##     python3 tools/persistent/stress_scenario.py                  # run on the desktop, print the summary
##     python3 tools/persistent/stress_scenario.py --print          # only print the dev_flags.cfg a handset takes (Moto / Galaxy)
##     python3 tools/persistent/stress_scenario.py --mode sequential --density low
## The summary reads the engine's own log lines (`[E-FRAME]`, `[E-PRESENT]`, `ERROR`); it never judges a number against a budget:
## budgets are read by the person, on the handset (step B).
##
## ⚠️ The second blast's worst frame (~500 ms desktop) is the fuse-end frame (ctx rebuild + `delta.commit()` + prop debris fall + persist),
## not the plan: `INFILTRAITOR_THROW_PROFILE=1` prints it (technical_debt.md, "Stress scenario findings" 2).
## ⚠️ `ScenarioRunner` `wait` is SECONDS, `frames` is frames. ⚠️ Two blasts in flight share ONE `_active_presenters` (a list, fixed 2026-10-07): each blast lands its own light, checked below.

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
GRENADES = "20,21;36,24"
FIRST_TARGET = "12,20"
SECOND_TARGET = "36,23"


def scenario(mode: str, gap_frames: int) -> str:
    between = "frames %d" % gap_frames if mode == "overlap" else "wait 9"
    return ("framing portrait; centre agent; zoom 0.5; wait 12; mark idle; throw 0 %s; %s; mark second; throw 1 %s; frames 6; "
            "shoot 0; wait 25; mark after; quit") % (FIRST_TARGET, between, SECOND_TARGET)


def flags(args) -> dict:
    f = {"MAP": "STRESS", "GRENADE_GUS": GRENADES, "RNG_SEED": "1", "EVENT_FRAMES": "1", "FRAME_PROBE": "1",
         "SCENARIO": scenario(args.mode, args.gap_frames)}
    if args.density:
        f["COSMETIC_DENSITY"] = args.density
    return f


def summarize(text: str) -> int:
    keep = ("hit-stop", "commit frame", "detonation —", "WAVES end", "smoke cleared", "light landed", "P-COOK")
    errors = [l for l in text.splitlines() if l.startswith(("ERROR", "SCRIPT ERROR")) and "resources still in use" not in l]
    for l in text.splitlines():
        if any(k in l for k in keep) and "E-FRAME]   f" not in l or "BEAT 0 " in l:
            print(l[:200])
    leaked = "resources still in use" in text
    ## the A1 finding-1 regression: every blast must land its own light (one presenter each) and nothing may leak at exit
    landed = text.count("[CONSEQUENCE] light landed")
    if landed != 2:
        print("[STRESS] FAIL: %d 'light landed' line(s) for 2 blasts" % landed)
        errors.append("light landed x%d" % landed)
    if leaked:
        errors.append("exit leak")
    print("[STRESS] %d ERROR line(s)%s%s" % (len(errors), "" if not errors else ": " + errors[0][:160],
                                              "; exit leak: resources still in use" if leaked else ""))
    return 1 if errors else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="the combined stress scenario (see the header)")
    ap.add_argument("--mode", choices=["overlap", "sequential"], default="overlap")
    ap.add_argument("--gap-frames", type=int, default=150)
    ap.add_argument("--density", choices=["low", "mid", "high"], default="")
    ap.add_argument("--print", action="store_true", help="print the dev_flags.cfg for a handset and stop")
    ap.add_argument("--timeout", type=int, default=300)
    args = ap.parse_args()
    f = flags(args)
    if args.print:
        print("# STRESS — push to /sdcard/Android/data/<package>/files/dev_flags.cfg")
        for k, v in f.items():
            print("%s=%s" % (k, v))
        return 0
    env = dict(os.environ, **{"INFILTRAITOR_" + k: v for k, v in f.items()})
    try:
        r = subprocess.run([GODOT, "--path", str(ROOT)], env=env, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print("[STRESS] TIMEOUT after %d s" % args.timeout)
        return 1
    return summarize(r.stdout + r.stderr)


if __name__ == "__main__":
    sys.exit(main())
