#!/usr/bin/env python3
##
## surfaces_gallery.py — boots `SURFACES_GALLERY` in a real window and brings back what the art looks like in runtime:
## one overview, one close-up per base column (each shows every patch row on that base, its three variants and the roof block),
## and the overview again from the E side (the decals must follow the camera yaw, rotation is camera-only). It stitches a
## contact sheet to `Screenshots/surfaces/gallery_sheet.png`. No grenade, no shot: every mark is placed by the map
## (`tools/persistent/gen_surfaces_gallery.py`, which this script re-runs first).
##
## It also fails on what a gallery can prove at runtime: a SCRIPT ERROR, a `[GroundDecals3D]` error (a kind without art), a
## capture that was not written, or a capture that is a flat colour (a board that did not draw).
##
##     python3 tools/persistent/surfaces_gallery.py [--zoom 0.7] [--tag name]

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "persistent"))
import gen_surfaces_gallery as gen  # noqa: E402

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
OUT = ROOT / "Screenshots" / "surfaces"
BUFFER = 5
TAG = "[GALLERY]"


def scenario(tag: str, zoom: float) -> tuple[str, list[str]]:
    steps = ["framing desktop", "frames 40"]
    names = []
    mid_x = gen.COLUMN_X0 + gen.COLUMN_W * len(gen.BASES) / 2.0
    mid_y = gen.COLUMN_Y0 + gen.COLUMN_H / 2.0
    steps += ["centre %d,%d" % (mid_x + BUFFER, mid_y + BUFFER), "zoom 0.12", "frames 30", "capture %s_overview" % tag]
    names.append("overview")
    rows_y = gen.ROW_Y0 + (max(len(gen.kinds_with_art()), 1) - 1) * gen.ROW_STEP / 2.0
    for c, base in enumerate(gen.BASES):
        cx = gen.COLUMN_X0 + c * gen.COLUMN_W + gen.COLUMN_W / 2.0
        steps += ["centre %d,%d" % (cx + BUFFER, rows_y + BUFFER), "zoom %.2f" % zoom, "frames 30", "capture %s_%s" % (tag, base)]
        names.append(base)
    for name, (x0, _fn) in gen.PAD_SHAPES.items():
        steps += ["centre %d,%d" % (x0 + gen.PAD_W / 2.0 + BUFFER, gen.PAD_Y0 + gen.PAD_H / 2.0 + BUFFER), "zoom %.2f" % (zoom * 0.8),
                  "frames 30", "capture %s_pad_%s" % (tag, name)]
        names.append("pad_" + name)
    hy = gen.HUMAN_Y0 + gen.HUMAN_H / 2.0
    steps += ["centre %d,%d" % (gen.COLUMN_X0 + 20 + BUFFER, hy + BUFFER), "zoom 0.3", "frames 30", "capture %s_human_wide" % tag]
    names.append("human_wide")
    for i, mat in enumerate(gen.HUMAN):
        steps += ["centre %d,%d" % (gen.COLUMN_X0 + i * 8 + 4 + BUFFER, hy + BUFFER), "zoom %.2f" % zoom, "frames 30", "capture %s_human_%s" % (tag, mat)]
        names.append("human_" + mat)
    ly = gen.LAB_Y0 + len(gen.CARPET_COLOURS) * gen.LAB_ROW_H / 2.0
    for i, mat in enumerate(gen.LAB):
        steps += ["centre %d,%d" % (gen.COLUMN_X0 + i * gen.LAB_W + gen.LAB_W / 2.0 + BUFFER, ly + BUFFER), "zoom 0.26",
                  "frames 30", "capture %s_lab_%s" % (tag, mat)]
        names.append("lab_" + mat)
    steps += ["centre agent", "zoom 1.6", "frames 30", "capture %s_agent_scale" % tag]
    names.append("agent_scale")
    steps += ["centre %d,%d" % (mid_x + BUFFER, mid_y + BUFFER), "zoom 0.12", "perspective E", "frames 40", "capture %s_overview_E" % tag]
    names.append("overview_E")
    steps.append("quit")
    return "; ".join(steps), names


def main() -> int:
    ap = argparse.ArgumentParser(description="Boot SURFACES_GALLERY and bring back a contact sheet (see the header)")
    ap.add_argument("--zoom", type=float, default=0.7, help="close-up zoom per base column")
    ap.add_argument("--tag", default="gallery")
    args = ap.parse_args()
    try:
        from PIL import Image
    except ImportError:
        print("%s ERROR: needs Pillow (pip install pillow)" % TAG)
        return 2
    gen.MAP_PATH.write_text(__import__("json").dumps(gen.build(), indent=1) + "\n")
    scen, names = scenario(args.tag, args.zoom)
    for n in names:
        (CAPTURES / ("%s_%s.png" % (args.tag, n))).unlink(missing_ok=True)
    env = {**os.environ, "INFILTRAITOR_MAP": "SURFACES_GALLERY", "INFILTRAITOR_RNG_SEED": "1", "INFILTRAITOR_SCENARIO": scen}
    out = subprocess.run([GODOT, "--path", str(ROOT), "--fixed-fps", "60", "--position", "4000,4000"],
                         capture_output=True, text=True, env=env, timeout=240)
    log = out.stdout + out.stderr
    problems = []
    if "SCRIPT ERROR" in log:
        problems.append("a SCRIPT ERROR in the log")
    for line in log.splitlines():
        if "[GroundDecals3D]" in line and "ERROR" in line.upper():
            problems.append(line.strip())
    OUT.mkdir(parents=True, exist_ok=True)
    images = []
    for n in names:
        p = CAPTURES / ("%s_%s.png" % (args.tag, n))
        if not p.exists():
            problems.append("capture %s was not written" % n)
            continue
        im = Image.open(p).convert("RGB")
        if len(im.resize((64, 36)).getcolors(64 * 36)) < 40:
            problems.append("capture %s is (nearly) a flat colour: the board did not draw" % n)
        im.save(OUT / ("%s_%s.png" % (args.tag, n)))
        images.append(im)
    if images:
        w, h = images[0].size
        cols = 3
        rows = (len(images) + cols - 1) // cols
        sheet = Image.new("RGB", (w * cols, h * rows))
        for i, im in enumerate(images):
            sheet.paste(im, ((i % cols) * w, (i // cols) * h))
        sheet.save(OUT / ("%s_sheet.png" % args.tag))
        print("%s sheet: %s (%d capture(s): %s)" % (TAG, (OUT / ("%s_sheet.png" % args.tag)).relative_to(ROOT), len(images), ", ".join(names)))
    for p in problems:
        print("%s PROBLEM: %s" % (TAG, p))
    print("%s %s" % (TAG, "PASSED" if not problems else "FAILED"))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
