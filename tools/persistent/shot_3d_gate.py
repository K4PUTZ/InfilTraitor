#!/usr/bin/env python3
##
## shot_3d_gate.py — does a REAL firearm shot reach the 3D board? (R3D-7, 2026-09-21)
##
## WHY IT EXISTS. `board_probe.py gate` and `shadow` compare voxel STATE, and the packed store mirrors every
## write, so a damage source that never tells `Board3DLive` to remesh passes them all: the state is right and the
## wall on screen is untouched. That is exactly what happened to `AgentShotController` — from R3D-1c until
## 2026-09-21 a round mutated the voxels and left the 3D wall intact (no hole, no dent, no bullet decal, no
## scorch), because only `DetonationPresenter` called `Board3DLive.on_blast_commit`. No identity gate could see it.
##
## WHAT IT ASSERTS, per case (one boot each, PLAYGROUND, the shot through the real `shoot` scenario step):
##   1. THE HOOK   — the log holds `[BOARD3D] remesh shot` and `[BOARD3D] recolour shot soot`;
##   2. THE PICTURE — the wall band of the capture changes between before and after (>= MIN_CHANGED_PX);
##   3. THE CONTROL — the same shot on the 2D board (`RENDER3D=0`) changes it too. A gate that cannot see a
##      shot on the board that always worked would pass with nothing to measure.
## Earned red-before-green on the unfixed code (2026-09-21): no `remesh shot` line, 0 changed pixels in the 3D
## wall band, while the 2D control changed 5 220 px (brick). Metal is a poor case: its 2D dent is ~33 px.
##
## Usage:
##     python3 tools/persistent/shot_3d_gate.py                 # brick + concrete, pistol
##     python3 tools/persistent/shot_3d_gate.py --materials concrete,wood --weapon shotgun

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
## PLAYGROUND's wall trios: authored x of the first block; the runtime column of the middle one is +2 (buffer 1).
TRIO_X = {"concrete": 2, "metal": 7, "stone": 12, "wood": 17, "brick": 22,
          "cardboard": 26, "fabric": 30, "plywood": 34, "glass": 38}
## The wall band of a 390x844 portrait capture framed on the trio's south face, and the noise floor it was
## measured at: the wall band of an unshot 3D scene changed 0 pixels between two captures (2026-09-21).
BAND = (0, 100, 390, 520)
MIN_CHANGED_PX = 100
TAG = "[SHOT-3D-GATE]"


def wall_band_changed(before: Path, after: Path) -> int:
    from PIL import Image, ImageChops
    a = Image.open(before).convert("RGB").crop(BAND)
    b = Image.open(after).convert("RGB").crop(BAND)
    diff = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 8 else 0)
    return diff.histogram()[255]


def shoot(material: str, weapon: str, render3d: bool) -> tuple[str, int]:
    rx = TRIO_X[material] + 2
    tag = "shot3dgate_%s_%s" % ("3d" if render3d else "2d", material)
    scenario = ("framing portrait; frames 30; centre %d,3; zoom 2.2; frames 20; capture %s_before; shoot 0; "
                "centre %d,3; frames 30; capture %s_after; quit") % (rx, tag, rx, tag)
    env = {**os.environ, "INFILTRAITOR_MAP": "PLAYGROUND", "INFILTRAITOR_RNG_SEED": "1",
           "INFILTRAITOR_RENDER3D": "1" if render3d else "0", "INFILTRAITOR_SHOT_WEAPON": weapon,
           "INFILTRAITOR_SHOT_AGENT_CELL": "%d,11" % rx, "INFILTRAITOR_SHOT_GUARD_CELL": "%d,6" % rx,
           "INFILTRAITOR_SCENARIO": scenario}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--position", "4000,4000"], capture_output=True,
                         text=True, env=env, timeout=300)
    log = out.stdout + out.stderr
    before, after = CAPTURES / (tag + "_before.png"), CAPTURES / (tag + "_after.png")
    if not (before.exists() and after.exists()):
        return log, -1
    return log, wall_band_changed(before, after)


def main() -> int:
    parser = argparse.ArgumentParser(description="Does a real firearm shot reach the 3D board? (see the header)")
    parser.add_argument("--materials", default="brick,concrete")
    parser.add_argument("--weapon", default="pistol")
    args = parser.parse_args()
    try:
        import PIL  # noqa: F401
    except ImportError:
        print("%s ERROR: needs Pillow (pip install pillow)" % TAG)
        return 2
    failures = []
    for material in [m.strip() for m in args.materials.split(",") if m.strip()]:
        if material not in TRIO_X:
            print("%s ERROR: unknown material %s (one of %s)" % (TAG, material, ", ".join(TRIO_X)))
            return 2
        log3d, px3d = shoot(material, args.weapon, True)
        _, px2d = shoot(material, args.weapon, False)
        hook = "[BOARD3D] remesh shot" in log3d and "[BOARD3D] recolour shot soot" in log3d
        problems = []
        if "SCRIPT ERROR" in log3d or "scenario_shoot:" in log3d:
            problems.append("the 3D run reported a script error")
        if not hook:
            problems.append("the 3D log has no `remesh shot` + `recolour shot soot` (the shot never told the board)")
        if px3d < MIN_CHANGED_PX:
            problems.append("the 3D wall band changed %d px (< %d)" % (px3d, MIN_CHANGED_PX))
        if px2d < MIN_CHANGED_PX:
            problems.append("THE CONTROL failed: the 2D wall band changed %d px (< %d)" % (px2d, MIN_CHANGED_PX))
        print("%s %s/%s: hook %s, 3D wall band %d px, 2D control %d px -> %s"
              % (TAG, material, args.weapon, "yes" if hook else "NO", px3d, px2d, "FAIL" if problems else "ok"))
        for line in problems:
            print("%s     %s" % (TAG, line))
        if problems:
            failures.append(material)
    print("%s %s" % (TAG, "FAILED for: " + ", ".join(failures) if failures else "PASSED"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
