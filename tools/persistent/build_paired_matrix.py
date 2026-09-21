#!/usr/bin/env python3
##
## build_paired_matrix.py — RENDER3D look-parity grading sheets: the SAME blast
## captured on the 2D board and on the 3D board, sampled at the same frames, laid
## out as two rows (top = 2D, bottom = 3D) so the Director can grade each moment.
##
## Drives build_filmstrip.py once per board (INFILTRAITOR_RENDER3D=0 / 1 — NOT the
## bare name `RENDER3D`, which the game never reads). One boot per board, fixed 60
## fps, same grenade index: both sides are the same blast on the same map.
##
## Usage:
##     python3 tools/persistent/build_paired_matrix.py
##     python3 tools/persistent/build_paired_matrix.py --grenade 2 --frames 270 --step 30
##
## Output: Screenshots/paired/blast_g<N>_paired.png (gitignored with the rest of
## Screenshots/ apart from history/).

import argparse
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FILM_DIR = os.path.join(ROOT, "Screenshots", "filmstrip")
OUT_DIR = os.path.join(ROOT, "Screenshots", "paired")


def capture(render3d, grenade, frames):
    env = {**os.environ, "INFILTRAITOR_RENDER3D": "1" if render3d else "0"}
    cmd = [sys.executable, os.path.join(ROOT, "tools", "persistent", "build_filmstrip.py"),
           "--frames", str(frames), "--grenade", str(grenade)]
    res = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout[-800:], res.stderr[-800:])
        sys.exit("[PAIRED] filmstrip failed for render3d=%s" % render3d)
    raw = {}
    for i in range(frames):
        p = os.path.join(FILM_DIR, "frame_%03d.png" % i)
        if os.path.exists(p):
            raw[i] = p
    return raw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grenade", type=int, default=2)
    ap.add_argument("--frames", type=int, default=270)
    ap.add_argument("--step", type=int, default=30)
    ap.add_argument("--no-crop", action="store_true")
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    picks = list(range(0, args.frames, args.step))
    rows = {}
    for label, r3d in (("2D", False), ("3D", True)):
        raw = capture(r3d, args.grenade, args.frames)
        keep = {}
        for i in picks:
            if i not in raw:
                continue
            dst = os.path.join(OUT_DIR, "g%d_%s_f%03d.png" % (args.grenade, label, i))
            shutil.copy(raw[i], dst)
            keep[i] = dst
        rows[label] = keep
        print("[PAIRED] %s: %d/%d frames" % (label, len(keep), len(picks)))

    first = Image.open(next(iter(rows["2D"].values())))
    w, h = first.size
    if not args.no_crop:
        box = (w // 5, h // 5, w * 4 // 5, h * 4 // 5)
        w, h = box[2] - box[0], box[3] - box[1]
    else:
        box = (0, 0, w, h)
    lab = 22
    sheet = Image.new("RGB", (w * len(picks), (h + lab) * 2), (16, 16, 20))
    d = ImageDraw.Draw(sheet)
    for ri, label in enumerate(("2D", "3D")):
        for ci, i in enumerate(picks):
            p = rows[label].get(i)
            if p is None:
                continue
            sheet.paste(Image.open(p).convert("RGB").crop(box), (ci * w, ri * (h + lab) + lab))
            d.text((ci * w + 4, ri * (h + lab) + 5), "%s  frame %d" % (label, i), fill=(230, 230, 230))
    out = os.path.join(OUT_DIR, "blast_g%d_paired.png" % args.grenade)
    sheet.save(out)
    print("[PAIRED] sheet: %s  (%dx%d)" % (out, sheet.width, sheet.height))


if __name__ == "__main__":
    main()
