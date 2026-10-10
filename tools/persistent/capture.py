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
## THE WINDOW is OFF SCREEN (`--position 4000,4000`): nothing appears on the Director's display and no stray click can reach it, and
## the frames are the profile's exact size (engine: 1920 x 1080). The size reaches Movie Maker through a marked, temporary
## `override.cfg`; the run is told `CAPTURE_WINDOW_FIXED=1` so the profile does not resize it mid-file. Every output's size is
## checked against the profile and a mismatch is said loudly.
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
USER_CAPTURES = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/captures"
STILLS = ROOT / "Screenshots" / "takes"
VIDEOS = ROOT / "videos"


def shapes_for(profile, shape):
    p = PROFILES["profiles"][profile]
    if shape:
        return [shape]
    default = p.get("default_shape", "")
    return list(p["shapes"].keys()) if default == "both" else [default]


OVERRIDE = ROOT / "override.cfg"
OVERRIDE_MARK = "; written by tools/persistent/capture.py — deleted when the run ends"


def run_godot(map_id, scenario, window, shape, extra=(), seed=1, timeout=600, env_extra=None):
    env = dict(os.environ, **(env_extra or {}), INFILTRAITOR_MAP=map_id, INFILTRAITOR_SCENARIO=scenario, INFILTRAITOR_RNG_SEED=str(seed),
               INFILTRAITOR_CAPTURE_WINDOW_FIXED="1", INFILTRAITOR_CAPTURE_SHAPE=shape)
    ## OFF SCREEN (Director, 2026-10-10: the machine may be in use; a full-screen take could eat a stray click). Measured: a window
    ## at 4000,4000 still draws, and Movie Maker writes the exact profile size (1920 x 1080) even on a 1920 x 1080 display.
    cmd = [GODOT, "--path", str(ROOT), "--position", "4000,4000", "--resolution", "%dx%d" % tuple(window), *extra]
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


def realtime(args, shape, suffix, window, frames_dir: Path, movie_log: str):
    """CR-6: the same take at real speed (no Movie Maker) records each take frame's duration; the Movie Maker frames are then shown
    for those durations, the ms stamped, so the real-time feel (and a stall) is visible from an off-screen run."""
    import re
    from PIL import Image, ImageDraw
    m = re.search(r"\[TAKE\] %s: start at drawn frame (\d+)" % re.escape(args.take), movie_log)
    if not m:
        sys.exit("[CAPTURE] realtime: the movie run did not print its take start")
    offset = int(m.group(1))
    run_godot(args.map, "take %s; quit" % args.take, window, shape, seed=args.seed, timeout=1800, env_extra={"INFILTRAITOR_CAPTURE_TIMING": "1",
              ## uncapped: the 30 fps default cap would make every frame >= 33 ms and hide the cost (PERFORMANCE_BUDGET: measure uncapped)
              "INFILTRAITOR_MAX_FPS": "0"})
    csv = USER_CAPTURES / ("%s_timing.csv" % args.take.replace(":", "_"))
    if not csv.exists():
        csv = USER_CAPTURES / ("%s_timing.csv" % args.take)
    rows = [l.split(",") for l in csv.read_text().splitlines()[1:]]
    ms = [float(r[1]) for r in rows]
    pngs = sorted(frames_dir.glob("f*.png"))
    out_dir = frames_dir / "rt"
    out_dir.mkdir()
    lines = []
    slow = 0
    for i, t in enumerate(ms):
        k = offset + i
        if k >= len(pngs):
            break
        im = Image.open(pngs[k]).convert("RGB")
        d = ImageDraw.Draw(im)
        bad = t > 33.4
        slow += bad
        d.rectangle([0, 0, 330, 44], fill=(160, 0, 0) if bad else (0, 0, 0))
        d.text((10, 8), "take frame %4d   %6.1f ms" % (i + 1, t), fill=(255, 255, 255), font_size=24)
        f = out_dir / ("r%05d.png" % i)
        im.save(f)
        lines.append("file '%s'\nduration %.4f" % (f, t / 1000.0))
    (out_dir / "list.txt").write_text("\n".join(lines) + "\n")
    out = VIDEOS / ("%s_%s%s_realtime.mp4" % (args.map, args.take.replace(":", "_"), suffix))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(out_dir / "list.txt"),
                    "-vsync", "vfr", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", str(out)], check=True)
    shutil.copy(csv, VIDEOS / ("%s_%s_timing.csv" % (args.map, args.take.replace(":", "_"))))
    print("[CAPTURE] realtime %s: %d frames, %.1f s real, worst %.1f ms, %d frame(s) over 33.3 ms"
          % (out.relative_to(ROOT), len(ms), sum(ms) / 1000.0, max(ms), slow))


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
    ap.add_argument("--realtime", action="store_true", help="--take: also run it at real speed and build <take>_realtime.mp4, each "
                    "frame held for its measured duration with the ms stamped (CR-6: a stall shows as a freeze)")
    ap.add_argument("--keep-frames", default="", help="--take: copy the raw PNG frames into this folder (determinism checks)")
    args = ap.parse_args()
    if args.profile not in PROFILES["profiles"]:
        sys.exit("[CAPTURE] unknown profile %s" % args.profile)
    STILLS.mkdir(parents=True, exist_ok=True)
    VIDEOS.mkdir(exist_ok=True)
    for shape in shapes_for(args.profile, args.shape):
        sh = PROFILES["profiles"][args.profile]["shapes"][shape]
        window = sh["window"]
        suffix = "_" + shape if len(shapes_for(args.profile, args.shape)) > 1 else ""
        if args.still:
            ## A still is the last frame of a short Movie Maker run (the off-screen window itself is clamped by the OS; the movie is not).
            target = args.still if args.still.startswith("@") or args.still in ("map",) else "@" + args.still
            for v in (["N", "E", "S", "W"] if args.view == "all" else [args.view]):
                with tempfile.TemporaryDirectory(prefix="still_") as tmp:
                    run_godot(args.map, "profile %s %s; wait 1; frame %s %s %s; frame_check still; frames 4; quit"
                              % (args.profile, shape, args.mode, target, v), window, shape,
                              extra=("--write-movie", str(Path(tmp) / "f.png"), "--fixed-fps", "60"), seed=args.seed)
                    pngs = sorted(Path(tmp).glob("f*.png"))
                    if not pngs:
                        sys.exit("[CAPTURE] Movie Maker wrote no frame")
                    dst = STILLS / ("%s_%s%s%s.png" % (args.map, args.still.replace(":", "_").lstrip("@"),
                                                      "_" + v if args.view == "all" else "", suffix))
                    shutil.copy(pngs[-1], dst)
                from PIL import Image
                got = list(Image.open(dst).size)
                if got != list(window):
                    print("[CAPTURE] WARNING still is %dx%d, the profile asks %dx%d" % (got[0], got[1], window[0], window[1]))
                if args.hud_grid:
                    hud_grid(dst)
                print("[CAPTURE] still %s (%dx%d)" % (dst.relative_to(ROOT), got[0], got[1]))
        else:
            with tempfile.TemporaryDirectory(prefix="take_") as tmp:
                frames = Path(tmp) / "f.png"
                movie_log = run_godot(args.map, "take %s; quit" % args.take, window, shape,
                                      extra=("--write-movie", str(frames), "--fixed-fps", "60"), seed=args.seed, timeout=1800)
                pngs = sorted(Path(tmp).glob("f*.png"))
                if not pngs:
                    sys.exit("[CAPTURE] Movie Maker wrote no frame")
                from PIL import Image
                size = Image.open(pngs[0]).size
                print("[CAPTURE] %d frame(s) of %dx%d" % (len(pngs), size[0], size[1]))
                if list(size) != list(window):
                    print("[CAPTURE] WARNING frames are %dx%d, the profile asks %dx%d" % (size[0], size[1], window[0], window[1]))
                if args.keep_frames:
                    keep = Path(args.keep_frames)
                    keep.mkdir(parents=True, exist_ok=True)
                    for f in pngs:
                        shutil.copy(f, keep / f.name)
                out = VIDEOS / ("%s_%s%s.mp4" % (args.map, args.take.replace(":", "_"), suffix))
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "60", "-i", str(Path(tmp) / "f%08d.png"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(out)], check=True)
                print("[CAPTURE] video %s" % out.relative_to(ROOT))
                if args.realtime:
                    realtime(args, shape, suffix, window, Path(tmp), movie_log)
                if args.sheet:
                    contact_sheet(Path(tmp), args.sheet, STILLS / ("%s_%s%s_sheet.png" % (args.map, args.take.replace(":", "_"), suffix)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
