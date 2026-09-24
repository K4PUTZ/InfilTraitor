#!/usr/bin/env python3
##
## pixel_gate.py — the 3D pixel gate (R3D-8 step 3): does the SAME code draw the SAME pixels twice?
##
## A pixel-diff gate has to be EARNED before it means anything (CLAUDE.md, 2026-08-09: two identical runs differed by
## 36 733 px at a 45-frame settle, 0 at 400). This is the earning: it boots the real game per case, twice, at
## `--fixed-fps 60` with a long settle after every event, captures the same frames and requires 0 differing pixels
## between the two boots. `--against DIR` (used by a later stage) compares against a stored set instead.
##
## CASES (one boot each, 3D board):
##   PLAYGROUND  load, grenade #0, a pistol shot on the brick wall
##   GLASS       load, grenade #0, grenade #1 (panes, cracks, piles)
## THE CONTROL: within one boot, load and the post-event captures MUST differ (a gate that cannot see the event
## would pass forever). Every boot uses RNG seed 1.
##
## ⚠️ THE GATE FAILS ON PIXELS ABOVE NOISE (8/255 per channel), NOT ON STRICT ZERO (2026-09-24). GLASS g0/g1 read 136 and
## 63 px strict in some boots and 0 in others, with 0 px above 8/255 in every case: a low-amplitude jitter between two
## boots of the same code (its source was not found). The strict count is still printed. It also means an old-vs-new
## comparison of GLASS cannot claim better than "<= 8/255" — the pile comparison of R3D-9 step 3 (158 px, <= 3/255)
## is inside this noise.
##
## ⚠️ THE LONE FAILS OF 2026-09-24 WERE THE CELL CURSOR. A run read FAIL with GLASS g0/g1 ~100 px apart and did not
## repeat; when it recurred (296 px in g0) the differing pixels were ALL one colour, the cursor outline's (229, 25, 114),
## drawn in one boot and not the other because the real mouse sits over the window. Now masked by that exact colour.
##
## Usage:   python3 tools/persistent/pixel_gate.py [--cases PLAYGROUND,GLASS] [--settle 400] [--keep DIR]

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
TAG = "[PIXEL-GATE]"
NOISE = 8  ## per-channel step below which two pixels count as equal (0 = strict; reported both ways)
BRICK_RX = 22 + 2
## PLAYGROUND's first two boots differed by 28 906 px in ONE region only: the agent's movement-range overlay
## (orange AP zone under its feet, y >= 727), drawn in one boot and not the other. Its zone follows `_hovered_cell`,
## which the game takes from the REAL mouse, so the harness inherits an input the scenario does not script. That
## band is masked here, both boots, and nothing else is: the wall, the floor and every effect the gate exists for
## are outside it. (GLASS frames its camera elsewhere and reads 0 px over the whole frame.)
MASK = {"PLAYGROUND": (0, 720, 390, 844)}
## The second real-mouse artefact (GLASS g0, 2026-09-24: 296 px, ONE colour): the cell cursor's outline, drawn where the
## harness' real pointer happens to sit. It is exactly (229, 25, 114); a pixel of exactly that colour in either image
## is excluded from the comparison. Nothing else is.
CURSOR_RGB = (229, 25, 114)


def case_env(case: str, settle: int, tag: str):
    if case == "PLAYGROUND":
        scenario = ("framing portrait; frames 60; centre %d,3; zoom 2.2; frames %d; capture %s_load; detonate 0; "
                    "frames %d; capture %s_g0; shoot 0; centre %d,3; frames %d; capture %s_shot; quit"
                    % (BRICK_RX, settle, tag, settle, tag, BRICK_RX, settle, tag))
        env = {"INFILTRAITOR_SHOT_WEAPON": "pistol", "INFILTRAITOR_SHOT_AGENT_CELL": "%d,11" % BRICK_RX,
               "INFILTRAITOR_SHOT_GUARD_CELL": "%d,6" % BRICK_RX}
        return scenario, env, ["load", "g0", "shot"]
    scenario = ("framing portrait; frames %d; capture %s_load; detonate 0; frames %d; capture %s_g0; detonate 1; "
                "frames %d; capture %s_g1; quit" % (settle, tag, settle, tag, settle, tag))
    return scenario, {"INFILTRAITOR_GRENADE_GUS": "14,12;5,12"}, ["load", "g0", "g1"]


def boot(case: str, settle: int, tag: str):
    scenario, extra, labels = case_env(case, settle, tag)
    env = {**os.environ, "INFILTRAITOR_MAP": case, "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_RENDER3D": "1",
           "INFILTRAITOR_SCENARIO": scenario, **extra}
    for label in labels:
        (CAPTURES / ("%s_%s.png" % (tag, label))).unlink(missing_ok=True)
    out = subprocess.run([GODOT, "--path", str(ROOT), "--fixed-fps", "60", "--position", "4000,4000"],
                         capture_output=True, text=True, env=env, timeout=600)
    log = out.stdout + out.stderr
    files = {label: CAPTURES / ("%s_%s.png" % (tag, label)) for label in labels}
    return files, ("SCRIPT ERROR" in log), log


def differing(a: Path, b: Path, tol: int, mask=None) -> int:
    from PIL import Image, ImageChops, ImageDraw
    x, y = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if mask is not None:
        for im in (x, y):
            ImageDraw.Draw(im).rectangle(mask, fill=(0, 0, 0))
    xp, yp = x.load(), y.load()
    for j in range(x.size[1]):
        for i in range(x.size[0]):
            if xp[i, j] == CURSOR_RGB or yp[i, j] == CURSOR_RGB:
                xp[i, j] = yp[i, j] = (0, 0, 0)
    if x.size != y.size:
        return x.size[0] * x.size[1]
    d = ImageChops.difference(x, y).convert("L").point(lambda v: 255 if v > tol else 0)
    return d.histogram()[255]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", default="PLAYGROUND,GLASS")
    ap.add_argument("--settle", type=int, default=400)
    ap.add_argument("--keep", default="", help="copy the captures of run 1 here")
    args = ap.parse_args()
    problems = []
    for case in [c.strip() for c in args.cases.split(",") if c.strip()]:
        runs = []
        for k in (1, 2):
            tag = "pixgate_%s_r%d" % (case, k)
            files, script_error, log = boot(case, args.settle, tag)
            missing = [l for l, f in files.items() if not f.exists()]
            if script_error:
                problems.append("%s run %d: script error" % (case, k))
            if missing:
                problems.append("%s run %d: no capture for %s" % (case, k, ", ".join(missing)))
            runs.append(files)
        if any(not f.exists() for r in runs for f in r.values()):
            continue
        for label in runs[0]:
            strict = differing(runs[0][label], runs[1][label], 0, MASK.get(case))
            loose = differing(runs[0][label], runs[1][label], NOISE, MASK.get(case))
            print("%s %s %s: run 1 vs run 2 — %d px strict, %d px above noise %d" % (TAG, case, label, strict, loose, NOISE))
            if loose != 0:
                problems.append("%s %s: %d px differ by more than %d/255 between two boots of the same code"
                                % (case, label, loose, NOISE))
        for label in list(runs[0])[1:]:
            ctl = differing(runs[0]["load"], runs[0][label], NOISE)
            print("%s %s control: load vs %s — %d px" % (TAG, case, label, ctl))
            if ctl < 100:
                problems.append("%s control: %s differs from load by only %d px (the gate cannot see the event)" % (case, label, ctl))
        if args.keep:
            Path(args.keep).mkdir(parents=True, exist_ok=True)
            for label, f in runs[0].items():
                shutil.copy(f, Path(args.keep) / ("%s_%s.png" % (case, label)))
    for p in problems:
        print("%s   %s" % (TAG, p))
    print("%s %s" % (TAG, "FAIL" if problems else "PASS"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
