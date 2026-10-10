#!/usr/bin/env python3
##
## capture.py — CAPTURE_RAILS_MASTER_PLAN §8: one command for a framed still or a frame-by-frame video of a map.
##
## WHY. Captures used to be framed by a GU typed by hand on a portrait screen (2026-10-10: the camera flew to dev grenade 0 in
## another corner of GLASS). Here the map's own anchors frame the shot (`layout` section), the profile sets the window and the HUD
## (`capture/profiles.json`), and a TAKE (the map's `capture` section, or the defaults overview / region:<id> / poi:<id>) moves
## the camera along a rail while the event fires on the same anchors.
##
## VIDEO IS FRAME BY FRAME: Godot's Movie Maker (`--write-movie`) renders every frame at a fixed delta (60 fps) whatever the real
## frame time, so particles, smoke and fades age exactly as in play and two runs of a seeded take are the same film. It cannot show
## a stall: that is the real-time check (CR-6) and the handset (`device_record.py`).
##
## THE WINDOW. A profile asks for a size (engine: 1920 x 1080); a window cannot be larger than the screen's usable area, so the
## largest window of the same aspect that fits is used and SAID (never a silently smaller file). The Godot run is told
## `CAPTURE_WINDOW_FIXED=1` so the profile does not resize it mid-file.
##
##     python3 tools/persistent/capture.py --map GLASS --take glass_blast                 # videos/GLASS_glass_blast.mp4
##     python3 tools/persistent/capture.py --map GLASS --take glass_blast --sheet 30      # + a contact sheet, one frame in 30
##     python3 tools/persistent/capture.py --map GLASS --take overview
##     python3 tools/persistent/capture.py --map GLASS --still big_pane --mode detail --view all
##     python3 tools/persistent/capture.py --map GLASS --still glass_wing --profile ui --hud-grid   # portrait AND landscape
##
## Outputs (git-ignored): videos/<MAP>_<take>[_<shape>].mp4, Screenshots/takes/<MAP>_<name>[_<view>][_<shape>].png.
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
PROFILES = json.loads((ROOT / "capture" / "profiles.json").read_text())
TITLE_BAR_PX = 28
USER_CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
STILLS = ROOT / "Screenshots" / "takes"
VIDEOS = ROOT / "videos"


def usable_screen():
    """The main screen's usable area (menu bar and Dock excluded), via AppKit; None if it cannot be read."""
    try:
        out = subprocess.run(["osascript", "-l", "JavaScript", "-e",
                              'ObjC.import("AppKit"); var f=$.NSScreen.mainScreen.visibleFrame; f.size.width+"x"+f.size.height'],
                             capture_output=True, text=True, timeout=10).stdout.strip()
        w, h = out.split("x")
        return int(float(w)), int(float(h))
    except Exception:  # noqa: BLE001 — a reading, with a stated fallback
        return None


def fit_window(want):
    usable = usable_screen()
    if usable is None:
        print("[CAPTURE] could not read the screen size; asking for %dx%d as is" % tuple(want))
        return want
    uw, uh = usable[0], usable[1] - TITLE_BAR_PX
    if want[0] <= uw and want[1] <= uh:
        return want
    k = min(uw / want[0], uh / want[1])
    got = [int(want[0] * k) // 8 * 8, int(want[1] * k) // 8 * 8]
    print("[CAPTURE] WARNING the profile wants %dx%d; the screen's usable area is %dx%d: using %dx%d (same aspect)"
          % (want[0], want[1], uw, uh, got[0], got[1]))
    return got


def shapes_for(profile, shape):
    p = PROFILES["profiles"][profile]
    if shape:
        return [shape]
    default = p.get("default_shape", "")
    return list(p["shapes"].keys()) if default == "both" else [default]


OVERRIDE = ROOT / "override.cfg"
OVERRIDE_MARK = "; written by tools/persistent/capture.py — deleted when the run ends"


def run_godot(map_id, scenario, window, shape, extra=(), seed=1, timeout=600):
    env = dict(os.environ, INFILTRAITOR_MAP=map_id, INFILTRAITOR_SCENARIO=scenario, INFILTRAITOR_RNG_SEED=str(seed),
               INFILTRAITOR_CAPTURE_WINDOW_FIXED="1", INFILTRAITOR_CAPTURE_SHAPE=shape)
    cmd = [GODOT, "--path", str(ROOT), "--resolution", "%dx%d" % tuple(window), *extra]
    ## Movie Maker records at the project's base window size (390 x 844), whatever `--resolution` says (measured 2026-10-10:
    ## "recording movie in 390×844"). Godot reads `override.cfg` at startup, so the size is given there for this run only.
    if OVERRIDE.exists() and OVERRIDE_MARK not in OVERRIDE.read_text():
        sys.exit("[CAPTURE] %s exists and is not ours: refusing to overwrite it" % OVERRIDE)
    OVERRIDE.write_text("%s\n[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\n" % (OVERRIDE_MARK, window[0], window[1]))
    try:
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout)
    finally:
        OVERRIDE.unlink(missing_ok=True)
    log = proc.stdout + proc.stderr
    for line in log.splitlines():
        if any(t in line for t in ("[TAKE]", "[RAIL]", "[CAPTURE]", "[FRAME-CHECK]", "[GLASS-COLLAPSE]", "ABORT", "SCRIPT ERROR")):
            print("  " + line.strip())
    if proc.returncode != 0 or "ABORT" in log or "SCRIPT ERROR" in log:
        sys.exit("[CAPTURE] the Godot run failed (exit %d); see the lines above" % proc.returncode)
    return log


def hud_grid(png: Path):
    """Draws the 3 x 3 HUD regions (R11) over a capture."""
    from PIL import Image, ImageDraw
    im = Image.open(png).convert("RGB")
    d = ImageDraw.Draw(im)
    w, h = im.size
    for i in (1, 2):
        d.line([(w * i // 3, 0), (w * i // 3, h)], fill=(255, 0, 255), width=2)
        d.line([(0, h * i // 3), (w, h * i // 3)], fill=(255, 0, 255), width=2)
    im.save(png)


def contact_sheet(frames_dir: Path, every: int, out: Path):
    from PIL import Image
    files = sorted(frames_dir.glob("*.png"))[::every]
    if not files:
        return
    thumbs = [Image.open(f).convert("RGB") for f in files]
    tw = 320
    th = int(thumbs[0].height * tw / thumbs[0].width)
    cols = 6
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * th), (20, 20, 20))
    for i, t in enumerate(thumbs):
        sheet.paste(t.resize((tw, th)), ((i % cols) * tw, (i // cols) * th))
    sheet.save(out)
    print("[CAPTURE] sheet %s (%d frames, one in %d)" % (out.relative_to(ROOT), len(thumbs), every))


def main() -> int:
    ap = argparse.ArgumentParser(description="Framed stills and frame-by-frame takes of a map (see the header)")
    ap.add_argument("--map", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--take", help="a take id: authored in the map's capture section, or overview / region:<id> / poi:<id>")
    g.add_argument("--still", help="an anchor to frame (a POI, a region, map)")
    ap.add_argument("--mode", default="wide", choices=["wide", "detail"], help="--still framing")
    ap.add_argument("--view", default="N", choices=["N", "E", "S", "W", "all"], help="--still view")
    ap.add_argument("--profile", default=PROFILES.get("default", "engine"))
    ap.add_argument("--shape", default="", help="portrait / landscape (default: the profile's)")
    ap.add_argument("--sheet", type=int, default=0, help="--take: a contact sheet of one frame in N")
    ap.add_argument("--hud-grid", action="store_true", help="draw the 3x3 HUD regions over the stills")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--keep-frames", default="", help="--take: copy the raw PNG frames into this folder (determinism checks)")
    args = ap.parse_args()
    if args.profile not in PROFILES["profiles"]:
        sys.exit("[CAPTURE] unknown profile %s" % args.profile)
    STILLS.mkdir(parents=True, exist_ok=True)
    VIDEOS.mkdir(exist_ok=True)
    for shape in shapes_for(args.profile, args.shape):
        sh = PROFILES["profiles"][args.profile]["shapes"][shape]
        window = fit_window(sh["window"])
        suffix = "_" + shape if len(shapes_for(args.profile, args.shape)) > 1 else ""
        if args.still:
            name = "%s_%s%s" % (args.map, args.still.replace(":", "_"), suffix)
            target = args.still if args.still.startswith("@") or args.still in ("map",) else "@" + args.still
            run_godot(args.map, "profile %s %s; wait 1; still %s %s %s %s; quit" % (args.profile, shape, name, args.mode, target,
                      args.view), window, shape, seed=args.seed)
            views = ["N", "E", "S", "W"] if args.view == "all" else [None]
            for v in views:
                src = USER_CAPTURES / ("%s%s.png" % (name, "_" + v if v else ""))
                dst = STILLS / src.name
                shutil.copy(src, dst)
                if args.hud_grid:
                    hud_grid(dst)
                print("[CAPTURE] still %s" % dst.relative_to(ROOT))
        else:
            with tempfile.TemporaryDirectory(prefix="take_") as tmp:
                frames = Path(tmp) / "f.png"
                run_godot(args.map, "take %s; quit" % args.take, window, shape,
                          extra=("--write-movie", str(frames), "--fixed-fps", "60"), seed=args.seed, timeout=1800)
                pngs = sorted(Path(tmp).glob("f*.png"))
                if not pngs:
                    sys.exit("[CAPTURE] Movie Maker wrote no frame")
                from PIL import Image
                size = Image.open(pngs[0]).size
                print("[CAPTURE] %d frame(s) of %dx%d" % (len(pngs), size[0], size[1]))
                if args.keep_frames:
                    keep = Path(args.keep_frames)
                    keep.mkdir(parents=True, exist_ok=True)
                    for f in pngs:
                        shutil.copy(f, keep / f.name)
                out = VIDEOS / ("%s_%s%s.mp4" % (args.map, args.take.replace(":", "_"), suffix))
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-i", str(Path(tmp) / "f%08d.png"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(out)], check=True)
                print("[CAPTURE] video %s" % out.relative_to(ROOT))
                if args.sheet:
                    contact_sheet(Path(tmp), args.sheet, STILLS / ("%s_%s%s_sheet.png" % (args.map, args.take.replace(":", "_"), suffix)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
