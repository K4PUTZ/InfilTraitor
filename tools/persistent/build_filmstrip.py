#!/usr/bin/env python3
##
## build_filmstrip.py — P-FILM: every frame of one detonation, on one sheet.
##
## Director, 2026-08-09: "queria ver se a gente consegue fazer um filmstrip com
## todos os frames da explosão pra analisar a sequência com mais calma."
##
## Drives room.gd's `detonation_filmstrip` capture action, then stitches the
## numbered frames it wrote into a labelled contact sheet.
##
## TWO THINGS THIS GETS RIGHT THAT THE OBVIOUS VERSION DOES NOT, both learned
## the hard way earlier the same session:
##
##  1. ONE detonation, not one boot per frame. `Room.spawn_blast_burst()` places
##     its embers with `randf_range()`, so a strip stitched from separate runs
##     shows the fire jumping between tiles. Every frame comes from one blast.
##
##  2. `--fixed-fps 60` is MANDATORY, not a nicety. Grabbing the viewport every
##     frame is a GPU→CPU readback that drags real frame time to a crawl. The
##     destruction front and the strobe are frame-driven and survive that
##     untouched — but the fire and smoke advance on DELTA, so at the capture's
##     real speed they would age several times too fast per frame and the strip
##     would misrepresent the exact effect being judged. `--fixed-fps` pins
##     every delta to 1/60 s.
##
## THE SHOT MODE (W-TUNE-01, 2026-08-20) does the same job for a FIREARM, and
## the two rules above survive intact for a different reason each: one shot per
## boot because the pellet salt is keyed on `room._world_revision` and a second
## shot rolls a different cone; `--fixed-fps 60` because the smoke and the soot
## fade age on delta while the tile swap is frame-driven, exactly as for a blast.
##
## Note what a shot-mode sheet CANNOT show: the tracer never reaches the wall
## (TRACER_FLIGHT_FRAMES — it is gone before the impact frame, deliberately), so
## a sheet focused on the wall shows the damage and the smoke and no projectile.
## `--focus` picks which of the two is the subject.
##
## Usage:
##     python3 tools/persistent/build_filmstrip.py
##     python3 tools/persistent/build_filmstrip.py --frames 30 --grenade 2 --cols 5
##     python3 tools/persistent/build_filmstrip.py --no-crop     # full frames
##     python3 tools/persistent/build_filmstrip.py --shot shotgun --guard 0 --focus 5,4
##
## Output: Screenshots/filmstrip/filmstrip.png (plus the raw frames beside it).
## `Screenshots/` is gitignored apart from `history/`, so a strip worth keeping
## as evidence has to be copied there by hand, under a non-`auto_` name.

import argparse
import os
import shutil
import subprocess
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("[P-FILM] Pillow is required: python3 -m pip install pillow")
    sys.exit(1)

GODOT_CANDIDATES = [
    "/Applications/Godot.app/Contents/MacOS/Godot",
    "/usr/bin/godot",
    "/usr/local/bin/godot",
]

# Generous: a filmstrip run boots the map, bakes, and then does a full GPU
# readback per frame. Not the expected exit path — the scene quits itself.
PROCESS_TIMEOUT_SECONDS = 300
OFFSCREEN_POSITION = "4000,4000"

# The capture action centres the camera on the grenade, so the blast is at
# screen centre and a centre crop is safe. Cropping is what makes the sheet
# actually readable — a full 1280x720 frame scaled to a tile is mostly floor.
CROP_FRACTION = 0.55

LABEL_H = 22
PAD = 6
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


def run_capture(root, godot, frames, grenade):
    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"
    env["INFILTRAITOR_CAPTURE_ACTION"] = "detonation_filmstrip"
    env["INFILTRAITOR_FILMSTRIP_FRAMES"] = str(frames)
    env["INFILTRAITOR_CAPTURE_DETONATE_INDEX"] = str(grenade)

    cmd = [
        godot,
        "--path", root,
        "--position", OFFSCREEN_POSITION,
        "--fixed-fps", "60",       # see the header — this is load-bearing
        "--disable-vsync",
    ]
    print("[P-FILM] capturing %d frames (grenade %d), --fixed-fps 60 ..." % (frames, grenade))
    try:
        res = subprocess.run(cmd, cwd=root, env=env, capture_output=True,
                             text=True, timeout=PROCESS_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print("[P-FILM] capture exceeded %ds — killed" % PROCESS_TIMEOUT_SECONDS)
        return None
    combined = res.stdout + res.stderr
    for line in combined.splitlines():
        if line.startswith("[P-FILM]") or line.startswith("[E-WAVE]"):
            print("   " + line.strip())
    return combined


def run_shot_capture(root, godot, frames, weapon, guard, focus, zoom):
    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"
    env["INFILTRAITOR_CAPTURE_ACTION"] = "shot_filmstrip"
    env["INFILTRAITOR_SHOT_FILM_SAVE"] = "1"
    env["INFILTRAITOR_SHOT_FILM_FRAMES"] = str(frames)
    env["INFILTRAITOR_SHOT_WEAPON"] = weapon
    env["INFILTRAITOR_SHOT_GUARD_INDEX"] = str(guard)
    env["INFILTRAITOR_SHOT_ZOOM"] = str(zoom)
    if focus:
        env["INFILTRAITOR_SHOT_FILM_FOCUS"] = focus

    cmd = [
        godot,
        "--path", root,
        "--position", OFFSCREEN_POSITION,
        "--fixed-fps", "60",       # see the header — this is load-bearing
        "--disable-vsync",
    ]
    print("[P-FILM] capturing %d frames (%s, guard %d) ..." % (frames, weapon, guard))
    try:
        res = subprocess.run(cmd, cwd=root, env=env, capture_output=True,
                             text=True, timeout=PROCESS_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print("[P-FILM] capture exceeded %ds — killed" % PROCESS_TIMEOUT_SECONDS)
        return None
    combined = res.stdout + res.stderr
    for line in combined.splitlines():
        if line.startswith("[AGENT-SHOT-TIER]") or line.startswith("[AGENT-SHOT]"):
            print("   " + line.strip()[:150])
    return combined


def build_sheet(frame_dir, out_path, cols, crop, prefix="frame_"):
    names = sorted(f for f in os.listdir(frame_dir)
                   if f.startswith(prefix) and f.endswith(".png"))
    if not names:
        print("[P-FILM] no frames found in %s" % frame_dir)
        return False

    tiles = []
    for n in names:
        im = Image.open(os.path.join(frame_dir, n)).convert("RGB")
        if crop:
            w, h = im.size
            cw, ch = int(w * CROP_FRACTION), int(h * CROP_FRACTION)
            left, top = (w - cw) // 2, (h - ch) // 2
            im = im.crop((left, top, left + cw, top + ch))
        im.thumbnail((360, 360), Image.LANCZOS)
        tiles.append((n, im))

    tw, th = tiles[0][1].size
    rows = (len(tiles) + cols - 1) // cols
    sheet_w = cols * tw + (cols + 1) * PAD
    sheet_h = rows * (th + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    draw = ImageDraw.Draw(sheet)

    for i, (name, im) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = PAD + c * (tw + PAD)
        y = PAD + r * (th + LABEL_H + PAD)
        sheet.paste(im, (x, y))
        idx = name[len(prefix):-len(".png")].lstrip("0") or "0"
        draw.text((x + 3, y + th + 4), "frame %s" % idx, fill=FG)

    sheet.save(out_path)
    print("[P-FILM] sheet: %s  (%d frames, %dx%d)" %
          (out_path, len(tiles), sheet_w, sheet_h))
    return True


def main():
    ap = argparse.ArgumentParser(description="Filmstrip of one detonation.")
    ap.add_argument("--frames", type=int, default=24)
    ap.add_argument("--grenade", type=int, default=2,
                    help="test-zone grenade index (0 concrete, 1 metal, 2 stone, 3 wood)")
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--no-crop", action="store_true",
                    help="keep whole frames instead of a centre crop on the blast")
    ap.add_argument("--stitch-only", action="store_true",
                    help="re-stitch the frames already on disk, no capture")
    ap.add_argument("--shot", metavar="WEAPON",
                    help="firearm mode: one shot with this weapon id "
                         "(shotgun, assault_rifle, pistol, ...) instead of a grenade")
    ap.add_argument("--guard", type=int, default=0,
                    help="shot mode: target guard index "
                         "(PLAYGROUND: 0 concrete, 1 metal, 2 stone, 3 wood)")
    ap.add_argument("--focus", default="",
                    help="shot mode: 'x,y' GU the camera centres on "
                         "(default: midway between shooter and target)")
    ap.add_argument("--zoom", type=float, default=0.5,
                    help="shot mode: capture zoom")
    args = ap.parse_args()

    root = repo_root()
    if args.shot:
        frame_dir = os.path.join(root, "Screenshots", "filmstrip_shot")
        out_path = os.path.join(frame_dir, "filmstrip_%s.png" % args.shot)
        prefix = "shot_"
    else:
        frame_dir = os.path.join(root, "Screenshots", "filmstrip")
        out_path = os.path.join(frame_dir, "filmstrip.png")
        prefix = "frame_"

    if not args.stitch_only:
        godot = find_godot()
        if godot is None:
            print("[P-FILM] Godot binary not found")
            return 1
        if args.shot:
            ok = run_shot_capture(root, godot, args.frames, args.shot,
                                  args.guard, args.focus, args.zoom)
        else:
            ok = run_capture(root, godot, args.frames, args.grenade)
        if ok is None:
            return 1

    if not os.path.isdir(frame_dir):
        print("[P-FILM] %s does not exist — did the capture run?" % frame_dir)
        return 1
    return 0 if build_sheet(frame_dir, out_path, args.cols,
                            not args.no_crop, prefix) else 1


if __name__ == "__main__":
    sys.exit(main())
