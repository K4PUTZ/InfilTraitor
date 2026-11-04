#!/usr/bin/env python3
##
## actor_video.py — a bank clip on an official Agent, in the game's four real facings, as a short video (ACTOR D91 / MOVEMENT MV-4, 2026-11-02). One desktop boot per facing
## (the bench's `actor_bench <model>_tint_f<k>_alone_clip_<id>`, Movie Maker at a fixed frame rate), the figure cropped out of the frame and labelled; `--combine` stacks recorded sets
## (one row each) into one mp4. Frames are kept under temp/video_sets/<name>/.
##     python3 tools/persistent/actor_video.py record --name asis --label "como esta" --model agent_light_male --clip run      # 4 facings -> temp/video_sets/asis/
##     python3 tools/persistent/actor_video.py combine --sets asis,welded --out temp/videos/run_asis_vs_welded.mp4
## NOTE: a rebuilt GLB reaches the game only after `godot --headless --path . --import` (the captures read the cached import); this script runs it first (--no-import to skip).
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/persistent"))
import capture  # noqa: E402
from temp_dir import temp_path  # noqa: E402

SETS = temp_path("video_sets")
GODOT = capture.GODOT


def record(args):
    from PIL import Image, ImageDraw, ImageFont
    if not args.no_import:
        subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--import"], capture_output=True, timeout=600)
    out = SETS / args.name
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 26)
    except OSError:
        font = ImageFont.load_default()
    n_keep = int(round(args.seconds * args.fps))
    for k in [int(x) for x in args.facings.split(",")]:
        scenario = "framing desktop; centre agent; zoom 3; frames 60; actor_bench %s_tint_f%d_alone_clip_%s 1; frames %d; quit" % (args.model, k, args.clip, args.fps * 8)
        with tempfile.TemporaryDirectory(prefix="vid_") as tmp:
            capture.run_godot("PLAYGROUND", scenario, (1920, 1080), "", extra=("--write-movie", str(Path(tmp) / "f.png"), "--fixed-fps", str(args.fps)), timeout=900)
            pngs = sorted(Path(tmp).glob("f*.png"))
            if len(pngs) < n_keep:
                sys.exit("[VIDEO] only %d frames recorded, %d wanted" % (len(pngs), n_keep))
            for i, p in enumerate(pngs[-n_keep:]):
                im = Image.open(p).convert("RGB")
                w, h = im.size
                cx, cy, half = int(w * 0.501), int(h * 0.666), int(h * 0.112)
                tile = im.crop((cx - half, cy - half, cx + half, cy + half)).resize((args.size, args.size), Image.LANCZOS)
                if args.label:
                    ImageDraw.Draw(tile).text((10, 8), args.label, fill=(255, 255, 255), font=font, stroke_width=2, stroke_fill=(0, 0, 0))
                tile.save(out / ("f%d_%03d.png" % (k, i)))
        print("[VIDEO] facing %d: %d frames" % (k, n_keep))
    print("[VIDEO] set %s -> %s" % (args.name, out.relative_to(ROOT)))


def combine(args):
    names = args.sets.split(",")
    facings = sorted({int(p.name[1]) for n in names for p in (SETS / n).glob("f*_000.png")})
    inputs, rows = [], []
    for r, n in enumerate(names):
        for k in facings:
            inputs += ["-framerate", str(args.fps), "-i", str(SETS / n / ("f%d_%%03d.png" % k))]
        rows.append("".join("[%d:v]" % (r * len(facings) + j) for j in range(len(facings))) + "hstack=inputs=%d[r%d]" % (len(facings), r))
    graph = ";".join(rows) + ";" + "".join("[r%d]" % r for r in range(len(names))) + "vstack=inputs=%d[v]" % len(names)
    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    loops = ["-stream_loop", str(args.loops - 1)] if args.loops > 1 else []
    subprocess.run(["ffmpeg", "-y", *inputs, "-filter_complex", graph, "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(out)], check=True, capture_output=True)
    if args.loops > 1:
        looped = out.with_name(out.stem + "_loop.mp4")
        subprocess.run(["ffmpeg", "-y", "-stream_loop", str(args.loops - 1), "-i", str(out), "-c", "copy", str(looped)], check=True, capture_output=True)
        shutil.move(str(looped), str(out))
    print("[VIDEO] %s" % out.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    r.add_argument("--name", required=True); r.add_argument("--label", default="")
    r.add_argument("--model", default="agent_light_male"); r.add_argument("--clip", default="run")
    r.add_argument("--facings", default="0,1,2,3"); r.add_argument("--seconds", type=float, default=2.0)
    r.add_argument("--fps", type=int, default=30); r.add_argument("--size", type=int, default=420)
    r.add_argument("--no-import", action="store_true")
    c = sub.add_parser("combine")
    c.add_argument("--sets", required=True); c.add_argument("--out", required=True)
    c.add_argument("--fps", type=int, default=30); c.add_argument("--loops", type=int, default=2)
    a = ap.parse_args()
    record(a) if a.cmd == "record" else combine(a)


if __name__ == "__main__":
    main()
