#!/usr/bin/env python3
##
## build_reference_set.py — the 2D reference set (R3D-8 step 6): captured ONCE, while both boards still exist.
##
## WHY. R3D-LOOK will have to LOOK at what the 2D board drew to decide items still undecided, after the 2D that
## made them is deleted at R3D-END. These are references in CLAUDE.md's sense (the picture answers something the
## prose does not), so they are hand-named (never `auto_`, so the screenshot rotation cannot take them) and kept
## under ARCHIVE/ (Director, 2026-09-23: it is not used in production any more; the folder is git-ignored).
##
## SITUATIONS (each on the 2D board AND the 3D board, same map, same seed, same frames, fixed 60 fps):
##   blast_concrete   PLAYGROUND, grenade #2, 270 frames every 30 — the blast, the end-of-blast light, the soot
##   wood_burn        PLAYGROUND, a grenade at the wood wall, 480 frames every 60 — the fire and its soot
##   glass_blast      GLASS, two grenades — cracks, craze, rain, piles
##   shot_<mat>_SW   a pistol shot on each of the nine materials, from the south, before / after, on the wall's SW face
##   sparks_metal     the metal shot, captured 3 frames after the impact instead of 30
##
## ⚠️ THE SE FACE IS NOT CAPTURED (open item of R3D-8 step 6). Three attempts, each read from the pictures and none
## a reference: (1) a shooter in the two-cell gap east of the trio: the shot menu stayed open and nothing fired, so
## the ~50 000 px "change" was the menu; (2) the south shot under a rotated view (E), agent/guard/centre cells
## converted to view coordinates: the smoke landed on a different wall and the hole was out of frame; (3) the same
## with the shooter cells left in base coordinates: nothing fired. The scenario's `SHOT_*_CELL` and `centre` take
## view cells under a rotated view in a way that was not worked out; it needs someone who can drive a rotated shot.
##   sparks_metal     the metal shot, captured 3 frames after the impact instead of 30
##
## Usage:  python3 tools/persistent/build_reference_set.py [--only blast_concrete,shot] [--out DIR]

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
PAIRED = ROOT / "Screenshots" / "paired"
TAG = "[REFERENCE-SET]"
DEFAULT_OUT = ROOT / "ARCHIVE" / "r3d_reference_2d"
## Authored x of each trio's first block; runtime = +1 (buffer). The trio is 3 blocks wide at authored y=2 (runtime 3).
TRIO_X = {"concrete": 2, "metal": 7, "stone": 12, "wood": 17, "brick": 22,
          "cardboard": 26, "fabric": 30, "plywood": 34, "glass": 38}
MANIFEST = []


def paired(name: str, args: list[str], out: Path) -> None:
    cmd = [sys.executable, str(ROOT / "tools/persistent/build_paired_matrix.py"), "--name", name] + args
    print("%s %s" % (TAG, " ".join(cmd[2:])))
    res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=os.environ.copy())
    if res.returncode != 0:
        print(res.stdout[-600:], res.stderr[-600:])
        MANIFEST.append("| %s | FAILED (build_paired_matrix exit %d) |" % (name, res.returncode))
        return
    files = sorted(PAIRED.glob("%s_*.png" % name))
    for f in files:
        shutil.copy(f, out / ("ref_" + f.name))
    MANIFEST.append("| %s | %d file(s): the paired sheet (top row 2D, bottom row 3D) and every sampled frame |"
                    % (name, len(files)))


BASE_GU = (46, 24)  ## PLAYGROUND: inner 44x22 + a buffer of 1 on each side


def from_base(cell, persp):
    """PerspectiveMapper.cell_from_base(), for the GU grid."""
    w, h = BASE_GU
    if persp == "E":
        return (h - 1 - cell[1], cell[0])
    if persp == "W":
        return (cell[1], w - 1 - cell[0])
    return cell


## A shot is always taken from the south (the only line the map leaves free for all nine trios), so the face it hits
## is the wall's south face. Under the N view that face is the SW one; under a rotated view the SAME face is drawn as
## the SE one. Face name -> the view to take it under.
FACE_VIEW = {"SW": "N", "SE": "E"}  ## SE kept for the next attempt; see the header


def shot(material: str, face: str, render3d: bool, settle: int, tag: str):
    persp = FACE_VIEW[face]
    x0 = TRIO_X[material] + 1  # runtime first block
    base_cx = x0 + 1
    cx, cy = from_base((base_cx, 3), persp)
    agent = from_base((base_cx, 11), persp)
    guard = from_base((base_cx, 6), persp)
    rotate = "perspective %s; frames 30; " % persp if persp != "N" else ""
    scenario = ("framing portrait; %sframes 30; centre %d,%d; zoom %s; frames 20; capture %s_before; shoot 0; "
                "centre %d,%d; frames 30; capture %s_after; quit" % (rotate, cx, cy, "2.2" if persp == "N" else "0.9", tag, cx, cy, tag))
    env = {**os.environ, "INFILTRAITOR_MAP": "PLAYGROUND", "INFILTRAITOR_RNG_SEED": "1",
           "INFILTRAITOR_RENDER3D": "1" if render3d else "0", "INFILTRAITOR_SHOT_WEAPON": "pistol",
           "INFILTRAITOR_SHOT_AGENT_CELL": "%d,%d" % agent, "INFILTRAITOR_SHOT_GUARD_CELL": "%d,%d" % guard,
           "INFILTRAITOR_SHOT_SETTLE_FRAMES": str(settle), "INFILTRAITOR_SCENARIO": scenario}
    for suffix in ("before", "after"):
        (CAPTURES / ("%s_%s.png" % (tag, suffix))).unlink(missing_ok=True)
    subprocess.run([GODOT, "--path", str(ROOT), "--fixed-fps", "60", "--position", "4000,4000"],
                   capture_output=True, text=True, env=env, timeout=300)
    return [CAPTURES / ("%s_%s.png" % (tag, s)) for s in ("before", "after")]


def shots(out: Path, only_metal_sparks: bool = False) -> None:
    MANIFEST.append("| shot_<material>_SE | NOT CAPTURED — three attempts failed, see the header of build_reference_set.py |")
    for material in TRIO_X:
        for face in ("SW",):
            got = []
            for board, r3d in (("2D", False), ("3D", True)):
                tag = "refshot_%s_%s_%s" % (material, face, board)
                files = shot(material, face, r3d, 30, tag)
                for f, suffix in zip(files, ("before", "after")):
                    if f.exists():
                        dst = out / ("ref_shot_%s_%s_%s_%s.png" % (material, face, board, suffix))
                        shutil.copy(f, dst)
                        got.append(dst.name)
            MANIFEST.append("| shot_%s_%s | %d file(s): pistol, before/after, 2D and 3D |" % (material, face, len(got)))
    for board, r3d in (("2D", False), ("3D", True)):
        tag = "refsparks_metal_%s" % board
        files = shot("metal", "SW", r3d, 3, tag)
        got = 0
        for f, suffix in zip(files, ("before", "after")):
            if f.exists():
                shutil.copy(f, out / ("ref_sparks_metal_%s_%s.png" % (board, suffix)))
                got += 1
        MANIFEST.append("| sparks_metal_%s | %d file(s): the shot captured 3 frames after the impact |" % (board, got))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--only", default="", help="comma list of: blast_concrete, wood_burn, glass_blast, shot")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    want = lambda k: not only or k in only  # noqa: E731
    if want("blast_concrete"):
        paired("blast_concrete", ["--map", "PLAYGROUND", "--grenade", "2", "--frames", "270", "--step", "30"], out)
    if want("wood_burn"):
        wx = TRIO_X["wood"] + 3
        os.environ["INFILTRAITOR_GRENADE_GUS"] = "%d,5" % wx
        paired("wood_burn", ["--map", "PLAYGROUND", "--grenade", "0", "--frames", "480", "--step", "60"], out)
        os.environ.pop("INFILTRAITOR_GRENADE_GUS", None)
    if want("glass_blast"):
        os.environ["INFILTRAITOR_GRENADE_GUS"] = "14,12;5,12"
        paired("glass_blast", ["--map", "GLASS", "--grenade", "0", "--frames", "300", "--step", "30"], out)
        os.environ.pop("INFILTRAITOR_GRENADE_GUS", None)
    if want("shot"):
        shots(out)
    (out / "MANIFEST.md").write_text(
        "# 2D reference set (R3D-8 step 6)\n\nCaptured 2026-09-23 on the code of the R3D-8 commits, both boards, "
        "`--fixed-fps 60`, RNG seed 1. Regenerate with `python3 tools/persistent/build_reference_set.py`.\n\n"
        "| situation | contents |\n|---|---|\n" + "\n".join(MANIFEST) + "\n", encoding="utf-8")
    print("%s %d situation(s) -> %s" % (TAG, len(MANIFEST), out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
