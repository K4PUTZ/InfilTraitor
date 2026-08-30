#!/usr/bin/env python3
##
## glass_calibration.py — GLASS G1: the blind MUL/ADD calibration strip.
##
## GLASS_MASTER_PLAN §10 task 1 attaches an obligation to G1
## (RESUMO_SESSAO_2026-08-30_GLASS_DESIGN §6): the Director sets glass's MUL
## strength against its ADD strength — and which ADD mode (the frosted facade's
## own bright mottling, or a procedural sheen band) — and that pick has to come
## from a strip of variants built IN ONE BOOT, over PLAYGROUND's real glass, with
## THE PANEL ORDER SHUFFLED AND THE LABELS HIDDEN. A judged render in this project
## has already failed by always returning "the last one" when the instrument, not
## the render, was the thing at fault (see the blind-comparison memory).
##
## This drives room.gd's `glass_calibration` capture action, which writes one PNG
## per (add_mode, mul_strength, add_strength) combo plus one SAME-BOOT OPAQUE
## CONTROL (glass exactly as it rendered before G1). Then it:
##   · crops each panel to the glass,
##   · SHUFFLES the variant panels and relabels them A, B, C, … (the control
##     stays first and named),
##   · stitches a contact sheet with NO strength numbers on it,
##   · writes the letter→params key to a SEPARATE file you open only after you
##     have picked,
##   · copies the sheet into Screenshots/history/ under a non-`auto_` name so the
##     rotation cannot eat it.
##
## Usage:
##     python3 tools/persistent/glass_calibration.py
##     python3 tools/persistent/glass_calibration.py --mul 0.25,0.5,0.75 --add 0.1,0.3,0.5
##     python3 tools/persistent/glass_calibration.py --stitch-only   # re-stitch, re-shuffle
##
## Output:
##     Screenshots/glass_calib/panel_*.png          raw panels
##     Screenshots/glass_calib/glass_calib_sheet.png  the blind sheet
##     Screenshots/glass_calib/glass_calib_KEY.txt    letter → params (open LAST)
##     Screenshots/history/glass_transparency_calib_<date>.png   the kept copy

import argparse
import datetime
import os
import random
import shutil
import subprocess
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("[GLASS-CALIB] Pillow is required: python3 -m pip install pillow")
    sys.exit(1)

GODOT_CANDIDATES = [
    "/Applications/Godot.app/Contents/MacOS/Godot",
    "/usr/bin/godot",
    "/usr/local/bin/godot",
]

PROCESS_TIMEOUT_SECONDS = 900
OFFSCREEN_POSITION = "6000,6000"

## The capture centres the camera on the two panes at zoom 0.60; a centre crop
## keeps the panes and drops the toolbar / compass / dev panel at the frame edges.
CROP_FRACTION = 0.72

LABEL_H = 26
PAD = 8
BG = (18, 18, 20)
FG = (235, 235, 235)


def find_godot():
    for c in GODOT_CANDIDATES:
        if os.path.isfile(c):
            return c
    return None


def repo_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, check=False).stdout.strip()
    return out or os.getcwd()


def run_capture(root, godot, modes, muls, adds, focus, zoom):
    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"
    env["INFILTRAITOR_CAPTURE_ACTION"] = "glass_calibration"
    env["INFILTRAITOR_GLASS_MODES"] = ",".join("%.2f" % m for m in modes)
    env["INFILTRAITOR_GLASS_MUL"] = ",".join("%.3f" % m for m in muls)
    env["INFILTRAITOR_GLASS_ADD"] = ",".join("%.3f" % a for a in adds)
    if focus:
        env["INFILTRAITOR_GLASS_FOCUS_CELL"] = focus
    if zoom:
        env["INFILTRAITOR_GLASS_ZOOM"] = str(zoom)

    cmd = [
        godot, "--path", root,
        "--position", OFFSCREEN_POSITION,
        "--fixed-fps", "60",
        "--disable-vsync",
    ]
    n = len(modes) * len(muls) * len(adds)
    print("[GLASS-CALIB] capturing %d variant panels + 1 control ..." % n)
    try:
        res = subprocess.run(cmd, cwd=root, env=env, capture_output=True,
                             text=True, timeout=PROCESS_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print("[GLASS-CALIB] capture exceeded %ds — killed" % PROCESS_TIMEOUT_SECONDS)
        return False
    for line in res.stdout.splitlines():
        if "GLASS-CALIB" in line or "GLASS-G1" in line or "SHADER ERROR" in line:
            print("  " + line)
    return res.returncode == 0


def read_index(calib_dir):
    """panel int -> human label from index.txt"""
    out = {}
    path = os.path.join(calib_dir, "index.txt")
    if not os.path.isfile(path):
        return out
    with open(path) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2 and parts[0].isdigit():
                out[int(parts[0])] = "  ".join(parts[1:])
    return out


def crop_thumb(path, crop_frac, box):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    cw, ch = int(w * crop_frac), int(h * crop_frac)
    left, top = (w - cw) // 2, (h - ch) // 2
    im = im.crop((left, top, left + cw, top + ch))
    im.thumbnail((box, box), Image.LANCZOS)
    return im


def build_sheet(calib_dir, out_path, key_path, cols, crop_frac, seed):
    names = sorted(f for f in os.listdir(calib_dir)
                   if f.startswith("panel_") and f.endswith(".png"))
    if not names:
        print("[GLASS-CALIB] no panels in %s" % calib_dir)
        return False
    index = read_index(calib_dir)

    control = []
    variants = []
    for n in names:
        panel = int(n[len("panel_"):-len(".png")])
        label = index.get(panel, "panel %d" % panel)
        entry = (panel, label, os.path.join(calib_dir, n))
        (control if label.startswith("CONTROL") else variants).append(entry)

    # Bigger tiles when there are fewer panels; smaller when the grid is dense.
    box = 620 if len(variants) <= 9 else (500 if len(variants) <= 16 else 400)

    rng = random.Random(seed)
    rng.shuffle(variants)

    ordered = control + variants
    blind = {}   # display index -> blind label
    key_lines = []
    for i, (panel, label, _) in enumerate(ordered):
        if label.startswith("CONTROL"):
            blind[i] = "CONTROL  (glass before G1)"
        else:
            letter = chr(ord("A") + i - len(control))
            blind[i] = letter
            key_lines.append("%s\t%s" % (letter, label))

    tiles = [(blind[i], crop_thumb(p, crop_frac, box)) for i, (_, _, p) in enumerate(ordered)]
    tw, th = tiles[0][1].size
    rows = (len(tiles) + cols - 1) // cols
    sheet_w = cols * tw + (cols + 1) * PAD
    sheet_h = rows * (th + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    draw = ImageDraw.Draw(sheet)
    for i, (blabel, im) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = PAD + c * (tw + PAD)
        y = PAD + r * (th + LABEL_H + PAD)
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + th + 6), blabel, fill=FG)
    sheet.save(out_path)
    print("[GLASS-CALIB] sheet: %s  (%d panels, %dx%d)"
          % (out_path, len(tiles), sheet_w, sheet_h))

    with open(key_path, "w") as f:
        f.write("GLASS G1 calibration — blind letter -> shader params\n")
        f.write("Open this ONLY after you have picked a letter from the sheet.\n\n")
        f.write("\n".join(sorted(key_lines)) + "\n")
    print("[GLASS-CALIB] key:   %s  (open AFTER you pick)" % key_path)
    return True


def parse_floats(s):
    return [float(x) for x in s.split(",") if x.strip()]


def main():
    ap = argparse.ArgumentParser(description="GLASS G1 blind calibration strip.")
    ap.add_argument("--modes", default="0,1",
                    help="ADD modes to include: 0 facade-derived, 1 procedural sheen")
    ap.add_argument("--mul", default="0.20,0.45,0.75", help="MUL strengths, comma-sep")
    ap.add_argument("--add", default="0.10,0.25,0.45", help="ADD strengths, comma-sep")
    ap.add_argument("--cols", type=int, default=0, help="sheet columns (0 = auto)")
    ap.add_argument("--crop-frac", type=float, default=CROP_FRACTION)
    ap.add_argument("--focus", default="", help="'x,y' GU the camera centres on")
    ap.add_argument("--zoom", type=float, default=0.0, help="capture zoom (0 = default 0.42)")
    ap.add_argument("--seed", type=int, default=None, help="shuffle seed (default: random)")
    ap.add_argument("--stitch-only", action="store_true",
                    help="re-stitch (and re-shuffle) the panels already on disk")
    args = ap.parse_args()

    root = repo_root()
    calib_dir = os.path.join(root, "Screenshots", "glass_calib")
    sheet_path = os.path.join(calib_dir, "glass_calib_sheet.png")
    key_path = os.path.join(calib_dir, "glass_calib_KEY.txt")

    if not args.stitch_only:
        godot = find_godot()
        if godot is None:
            print("[GLASS-CALIB] no Godot binary found in %s" % GODOT_CANDIDATES)
            sys.exit(1)
        modes = parse_floats(args.modes)
        muls = parse_floats(args.mul)
        adds = parse_floats(args.add)
        if not run_capture(root, godot, modes, muls, adds, args.focus, args.zoom):
            print("[GLASS-CALIB] capture failed — see output above")
            sys.exit(1)

    panels = [f for f in os.listdir(calib_dir)
              if f.startswith("panel_") and f.endswith(".png")] \
        if os.path.isdir(calib_dir) else []
    cols = args.cols or min(5, max(3, round(len(panels) ** 0.5)))

    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    if not build_sheet(calib_dir, sheet_path, key_path, cols, args.crop_frac, seed):
        sys.exit(1)

    hist_dir = os.path.join(root, "Screenshots", "history")
    os.makedirs(hist_dir, exist_ok=True)
    stamp = datetime.date.today().isoformat()
    kept = os.path.join(hist_dir, "glass_transparency_calib_%s.png" % stamp)
    shutil.copyfile(sheet_path, kept)
    print("[GLASS-CALIB] kept:  %s" % kept)
    print("[GLASS-CALIB] shuffle seed %d — pass --seed %d to reproduce this order"
          % (seed, seed))


if __name__ == "__main__":
    main()
