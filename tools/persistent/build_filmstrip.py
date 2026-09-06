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
PROCESS_TIMEOUT_SECONDS = 900
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
        # CELL-PROBE and NO-BURN pass through too: a capture run whose probe
        # output is filtered away is a capture that has to be run twice.
        if (line.startswith("[P-FILM]") or line.startswith("[E-WAVE]")
                or line.startswith("[CELL-PROBE]") or line.startswith("[NO-BURN]")):
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


GLASS_RAIN_PRESETS = ["snappy", "default", "floaty", "heavy", "raked"]


def run_glass_rain_capture(root, godot, preset, impulse):
    """G4-4 — one timing preset of the shard rain, on the GLASS map, as MP4.

    Drives room.gd's `glass_rain_timings` capture. The pane is shattered for
    real (real G-D41/G-D42 scatter), the pile decal is laid, then the rain
    plays at ONE preset over a clean diagnostic backdrop — no grenade smoke,
    so the subject is the fall. `--fixed-fps 60` for the same reason every
    other filmstrip needs it: the shards age in FRAMES, so playback at 60 is
    the designed speed.
    """
    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"
    env["INFILTRAITOR_MAP"] = "GLASS"
    env["INFILTRAITOR_CAPTURE_ACTION"] = "glass_rain_timings"
    env["INFILTRAITOR_RAIN_TIMING"] = preset
    env["INFILTRAITOR_RAIN_IMPULSE"] = str(impulse)
    env["INFILTRAITOR_FREEZE_GUARD_TURN"] = "1"
    cmd = [godot, "--path", root, "--position", OFFSCREEN_POSITION,
           "--fixed-fps", "60", "--disable-vsync"]
    print("[P-FILM] glass rain: preset=%s impulse=%s, --fixed-fps 60 ..." % (preset, impulse))
    try:
        res = subprocess.run(cmd, cwd=root, env=env, capture_output=True,
                             text=True, timeout=PROCESS_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print("[P-FILM] capture exceeded %ds — killed" % PROCESS_TIMEOUT_SECONDS)
        return None
    combined = res.stdout + res.stderr
    for line in combined.splitlines():
        if line.startswith("[GLASS-RAIN-T]") or line.startswith("[GLASS-FALL]") \
                or line.startswith("[GLASS-REMNANT]"):
            print("   " + line.strip())
    return combined


def build_video(frame_dir, out_path, fps, prefix="frame_"):
    """P-VID (Director, 2026-08-26): *"o ideal na verdade era a gente trabalhar
    com video pra poder analisar esse flow."*

    A sheet can only hold so many tiles, so it covers the first fraction of a
    second and the Director's report is about what happens LATER — the fire, not
    the blast. Frames are already captured one per drawn frame; this just encodes
    them instead of tiling them.

    ⚠️ WHAT THIS VIDEO IS AND IS NOT. The capture runs under `--fixed-fps 60`
    (mandatory — see the header), so every frame is exactly 1/60 s of SIMULATED
    time and encoding at 60 fps plays the event back at its DESIGNED speed. That
    is the right instrument for judging flow and timing, and it is the WRONG one
    for judging lag: the real build does not hit 60 fps during a fire, and the
    per-frame GPU readback this capture performs would dominate the wall clock
    anyway. Read the lag off `INFILTRAITOR_BURN_PROFILE=1`, never off this file.

    `--fps` below the capture rate is slow motion, not a slower game.
    """
    names = sorted(f for f in os.listdir(frame_dir)
                   if f.startswith(prefix) and f.endswith(".png"))
    if not names:
        print("[P-VID] no frames found in %s" % frame_dir)
        return False
    ff = shutil.which("ffmpeg")
    if ff is None:
        print("[P-VID] ffmpeg not found on PATH — cannot encode")
        return False
    # A glob pattern rather than %03d: the capture's numbering starts at 0 and
    # ffmpeg's sequence reader is fussy about that, while glob never is.
    cmd = [ff, "-y", "-framerate", str(fps),
           "-pattern_type", "glob", "-i", os.path.join(frame_dir, prefix + "*.png"),
           # yuv420p + even dimensions, so the file plays in QuickTime and in a
           # browser rather than only in ffplay.
           "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
           "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
           out_path]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        print("[P-VID] ffmpeg failed:\n" + res.stderr[-1500:])
        return False
    secs = len(names) / float(fps)
    print("[P-VID] video: %s  (%d frames @ %d fps = %.2fs)"
          % (out_path, len(names), fps, secs))
    return True


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
    ap.add_argument("--video", action="store_true",
                    help="encode the frames to mp4 instead of tiling a sheet (P-VID)")
    ap.add_argument("--fps", type=int, default=60,
                    help="playback rate of --video. The capture is always 60 "
                         "simulated fps, so a lower value here is SLOW MOTION")
    ap.add_argument("--zoom", type=float, default=0.5,
                    help="shot mode: capture zoom")
    ap.add_argument("--glass-rain", metavar="PRESET",
                    help="G4-4 rain-timing mode: one MP4 per preset "
                         "(%s), or 'all' for every one" % "/".join(GLASS_RAIN_PRESETS))
    ap.add_argument("--rain-impulse", type=float, default=0.6,
                    help="glass-rain mode: shockwave bias 0.0 (symmetric) .. 1.0")
    args = ap.parse_args()

    if args.glass_rain:
        root = repo_root()
        godot = find_godot()
        if godot is None:
            print("[P-FILM] Godot binary not found")
            return 1
        presets = GLASS_RAIN_PRESETS if args.glass_rain == "all" else [args.glass_rain]
        bad = [p for p in presets if p not in GLASS_RAIN_PRESETS]
        if bad:
            print("[P-FILM] unknown preset(s): %s — pick from %s"
                  % (", ".join(bad), ", ".join(GLASS_RAIN_PRESETS)))
            return 1
        frame_dir = os.path.join(root, "Screenshots", "filmstrip_rain")
        fail = 0
        for p in presets:
            if not args.stitch_only:
                if run_glass_rain_capture(root, godot, p, args.rain_impulse) is None:
                    fail += 1
                    continue
            if not os.path.isdir(frame_dir):
                print("[P-FILM] %s does not exist — did the capture run?" % frame_dir)
                fail += 1
                continue
            vid = os.path.join(frame_dir, "rain_%s.mp4" % p)
            if not build_video(frame_dir, vid, args.fps, "frame_"):
                fail += 1
        return 1 if fail else 0

    # A sheet is limited by how many tiles stay readable; a video is not, and the
    # event the Director wants to see is ~2.5 s of fire rather than the blast's
    # opening. So video mode covers the whole event unless asked otherwise.
    if args.video and "--frames" not in sys.argv:
        args.frames = 180          # 3.0 s at the capture's fixed 60 fps

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
    if args.video:
        vid = os.path.join(frame_dir, os.path.splitext(
            os.path.basename(out_path))[0] + ".mp4")
        return 0 if build_video(frame_dir, vid, args.fps, prefix) else 1
    return 0 if build_sheet(frame_dir, out_path, args.cols,
                            not args.no_crop, prefix) else 1


if __name__ == "__main__":
    sys.exit(main())
