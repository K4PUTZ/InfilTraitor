"""CHARACTER_MASTER_PLAN §9 #12 — the step duration, bracketed and BLIND.

THE QUESTION: how long should the agent take to cross one GU? `agent.gd` says
0.13 s, which over a 1.60 m GU is 12.3 m/s — faster than the 100 m world record.
That constant was tuned for a 44x61 px vector diamond with no legs to contradict
it, and Part 2 gave the agent legs.

--------------------------------------------------------------------------------
EVERY METHOD RULE BELOW WAS PAID FOR BY THE TURN TEST, 2026-08-15. That test ran
sighted and ordered, the Director observed *"em todos os exemplos até agora a
última opção sempre foi a melhor"*, and the observation withdrew the conclusion
rather than confirming it. What made the re-run diagnostic:

1. THE RANGE IS BRACKETED ON BOTH SIDES. 130 ms is included precisely because it
   is indefensible — it is what ships today, and a set of options that never
   renders an obviously wrong one cannot locate the ceiling. 950 ms is the other
   end: 1.7 m/s, a real walking speed, and probably sluggish for a tactical game.
   If the Director picks an END, the range still has not been bracketed and this
   has to run again wider. A single-peaked answer in the MIDDLE is what a real
   optimum looks like.

2. THE LABELS ARE BLIND AND THE ORDER IS RANDOMISED. No milliseconds, no speeds,
   no ordering by duration, and no progress bar — a bar filling at four different
   rates side by side is a duration readout in disguise. The seed is fixed so the
   run reproduces.

3. THE SLOWEST IS NOT LAST. Under a fixed seed, constrained. "The last one" and
   "the slowest one" were the same panel in every sheet this project made before
   2026-08-15, so the two explanations were not separable.

4. THE FIGURE HAS LEGS. This is the turn test's objection 3, applied before the
   fact rather than after: a rigid pivot with the feet glued *contains no
   discrete beat*, so more smoothing can only ever look better and the preference
   comes back monotonic with no interior optimum. The walk cycle is authored and
   baked BEFORE this runs, and it is distance-driven, so one asset is correct at
   every duration tested and nothing here presupposes the answer.

--------------------------------------------------------------------------------
OUTPUT. An MP4, because the quantity under judgement is TIME and a contact sheet
cannot carry it. MP4 rather than GIF for the reason §6 records: GIF stores its
delay in centiseconds, so it cannot represent 60 fps at all, and many viewers
additionally clamp short delays. The MP4 is NOT COMMITTED — `.gitignore:27` bans
`*.mp4` globally and force-adding would be a silent workaround of a deliberate
policy. What IS committed is the answer key and a still contact sheet, and the
whole chain regenerates from tracked sources.

Run:
  python3 tools/asset_generation/p3_step_bracket.py
  python3 tools/asset_generation/p3_step_bracket.py --reveal   # labelled, after
"""

import argparse
import json
import os
import random
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
FRAMES_ROOT = os.path.join(REPO_ROOT, "Screenshots", "walk")
OUT_MP4 = os.path.join(REPO_ROOT, "Screenshots", "history", "p3_step_bracket_blind.mp4")
OUT_KEY = os.path.join(REPO_ROOT, "Screenshots", "history", "p3_step_bracket_blind_KEY.json")
OUT_SHEET = os.path.join(REPO_ROOT, "Screenshots", "history", "p3_step_bracket_sheet.png")

## One GU, from VOXELS_PER_UNIT_AXIS 8 x 0.20 m.
GU_M = 1.60
GUS = 4
ZOOM = 1.6
SEED = 20260816

## The four candidates. 130 is today's value and is in the set to be rejected.
CANDIDATES_MS = [130, 320, 560, 950]

## Crop applied to every 1280x720 frame — identical for all panels, because a
## per-panel crop would change the apparent distance travelled.
CROP = (300, 90, 1160, 700)
PANEL_W = 430

BG = (24, 25, 28)
INK = (238, 239, 244)


def log(m):
    print("[P3-STEP] %s" % m)


def fail(m):
    print("[P3-STEP][FAIL] %s" % m)
    sys.exit(1)


def capture(step_ms):
    """One walk, at one duration, through the game's own movement code."""
    name = "walk_%04dms" % step_ms
    env = dict(os.environ)
    env.update({
        "INFILTRAITOR_AUTO_SCREENSHOT": "1",
        "INFILTRAITOR_CAPTURE_ACTION": "walk_filmstrip",
        "INFILTRAITOR_CAPTURE_VISION": "dev",     ## defaults ON; this turns it OFF
        "INFILTRAITOR_CAPTURE_ZOOM": str(ZOOM),
        "INFILTRAITOR_WALK_STEP_MS": str(step_ms),
        "INFILTRAITOR_WALK_GUS": str(GUS),
        "INFILTRAITOR_WALK_OUT": name,
    })
    ## --fixed-fps 60 is mandatory, not tidiness — see room.gd's own note. The
    ## step tween advances on delta, and the per-frame viewport readback drags
    ## real frame time to a crawl, so without the pin every panel would play at
    ## the CAPTURE's speed rather than at its own. That is the exact quantity
    ## under judgement.
    cmd = [GODOT, "--path", REPO_ROOT, "--position", "4000,4000", "--fixed-fps", "60"]
    log("capturing %s (%.2f m/s)" % (name, GU_M / (step_ms / 1000.0)))
    res = subprocess.run(cmd, cwd=REPO_ROOT, env=env, capture_output=True,
                         text=True, timeout=600)
    frames_dir = os.path.join(FRAMES_ROOT, name)
    frames = sorted(f for f in os.listdir(frames_dir)) if os.path.isdir(frames_dir) else []
    frames = [f for f in frames if f.startswith("frame_")]
    if not frames:
        print(res.stdout[-2000:])
        fail("%s produced no frames" % name)
    log("  %d frames" % len(frames))
    return frames_dir, frames


def build_panels(captures, order, labels, reveal):
    """One PNG sequence with the four panels side by side.

    Each panel LOOPS its own clip, so a slow panel is not padded with a frozen
    figure while a fast one replays — every panel is always in motion, and the
    only thing that differs between them is how fast."""
    counts = [len(captures[ms][1]) for ms in order]
    total = max(counts) * 2
    tmp = os.path.join(REPO_ROOT, "Screenshots", "walk", "_bracket")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)

    cw = CROP[2] - CROP[0]
    ch = CROP[3] - CROP[1]
    ## h264 refuses odd dimensions ("height not divisible by 2"), so the panel
    ## and the header are both forced even rather than padded afterwards — a pad
    ## filter would letterbox the panels and change what the eye compares.
    ph = int(round(ch * PANEL_W / cw)) // 2 * 2
    head = 34
    sheet_w = PANEL_W * len(order)

    for i in range(total):
        canvas = Image.new("RGB", (sheet_w, ph + head), BG)
        d = ImageDraw.Draw(canvas)
        for p, ms in enumerate(order):
            frames_dir, frames = captures[ms]
            f = frames[i % len(frames)]
            im = Image.open(os.path.join(frames_dir, f)).convert("RGB")
            im = im.crop(CROP).resize((PANEL_W, ph), Image.LANCZOS)
            canvas.paste(im, (p * PANEL_W, head))
            text = labels[p] if not reveal else "%s  %d ms  %.1f m/s" % (
                labels[p], ms, GU_M / (ms / 1000.0))
            d.text((p * PANEL_W + PANEL_W // 2 - 4, 11), text, fill=INK)
            if p:
                d.line([(p * PANEL_W, head), (p * PANEL_W, ph + head)], fill=(70, 72, 80))
        canvas.save(os.path.join(tmp, "f_%04d.png" % i))
    log("composited %d panel frames (%dx%d)" % (total, sheet_w, ph + head))
    return tmp, total


def build_still(captures, order, labels, reveal, fraction):
    """The panels at the same fraction of each panel's OWN walk."""
    cw = CROP[2] - CROP[0]
    ch = CROP[3] - CROP[1]
    ph = int(round(ch * PANEL_W / cw)) // 2 * 2
    head = 34
    canvas = Image.new("RGB", (PANEL_W * len(order), ph + head), BG)
    d = ImageDraw.Draw(canvas)
    d.text((10, 11), "step duration bracket — every panel at %d%% of its own "
                     "%d-GU walk" % (int(fraction * 100), GUS), fill=(150, 152, 160))
    for p, ms in enumerate(order):
        frames_dir, frames = captures[ms]
        f = frames[min(len(frames) - 1, int(len(frames) * fraction))]
        im = Image.open(os.path.join(frames_dir, f)).convert("RGB")
        canvas.paste(im.crop(CROP).resize((PANEL_W, ph), Image.LANCZOS), (p * PANEL_W, head))
        text = labels[p] if not reveal else "%s  %d ms  %.1f m/s" % (
            labels[p], ms, GU_M / (ms / 1000.0))
        d.text((p * PANEL_W + PANEL_W // 2 - 4, 11), text, fill=INK)
        if p:
            d.line([(p * PANEL_W, head), (p * PANEL_W, ph + head)], fill=(70, 72, 80))
    out = OUT_SHEET if not reveal else OUT_SHEET.replace("_sheet", "_sheet_revealed")
    canvas.save(out)
    log("wrote %s" % os.path.relpath(out, REPO_ROOT))


def encode(tmp, out_path):
    if shutil.which("ffmpeg") is None:
        fail("ffmpeg not found — needed to encode the panels at an EXACT 60 fps")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    cmd = ["ffmpeg", "-y", "-framerate", "60", "-i", os.path.join(tmp, "f_%04d.png"),
           "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", out_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr[-1500:])
        fail("ffmpeg failed")
    log("wrote %s" % os.path.relpath(out_path, REPO_ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reveal", action="store_true",
                    help="label the panels with their real durations (AFTER the judgement)")
    ap.add_argument("--no-capture", action="store_true",
                    help="reuse the frames already on disk")
    args = ap.parse_args()

    captures = {}
    for ms in CANDIDATES_MS:
        name = "walk_%04dms" % ms
        d = os.path.join(FRAMES_ROOT, name)
        if args.no_capture and os.path.isdir(d):
            frames = sorted(f for f in os.listdir(d) if f.startswith("frame_"))
            captures[ms] = (d, frames)
            log("reusing %s (%d frames)" % (name, len(frames)))
        else:
            captures[ms] = capture(ms)

    ## Rule 3: randomise, then reject any order whose LAST panel is the slowest.
    rng = random.Random(SEED)
    order = list(CANDIDATES_MS)
    slowest = max(CANDIDATES_MS)
    for _ in range(200):
        rng.shuffle(order)
        if order[-1] != slowest:
            break
    else:
        fail("could not place the slowest panel away from last")
    labels = ["A", "B", "C", "D"][:len(order)]
    log("blind order: %s" % " ".join(
        "%s=%dms" % (l, ms) for l, ms in zip(labels, order)))

    tmp, total = build_panels(captures, order, labels, args.reveal)
    out = OUT_MP4 if not args.reveal else OUT_MP4.replace("_blind", "_revealed")
    encode(tmp, out)

    ## A still, so the comparison survives in the repo even though the MP4 cannot
    ## be committed. It carries WHAT was compared, never the answer.
    ##
    ## Sampled at the same FRACTION of each panel's own walk, not at one shared
    ## frame index. A shared index catches four clips at unrelated points of
    ## their loops — the first version put two panels at their start tile and one
    ## almost off the far edge, which reads as four different camera setups. It
    ## was not (measured: frame 0 of each run differs from the others by ~9 000
    ## px, the agent's own silhouette, on a 921 600 px frame), but a still that
    ## invites that reading is a bad record.
    build_still(captures, order, labels, args.reveal, 0.5)

    with open(OUT_KEY, "w") as fh:
        json.dump({
            "question": "CHARACTER_MASTER_PLAN §9 #12 — seconds per GU",
            "gu_m": GU_M,
            "gus_walked": GUS,
            "seed": SEED,
            "shipping_value_ms": 130,
            "panels": [{"label": l, "step_ms": ms,
                        "speed_m_s": round(GU_M / (ms / 1000.0), 2)}
                       for l, ms in zip(labels, order)],
            "method": ("blind labels, randomised under a fixed seed with the "
                       "slowest not last, judged on a figure with an authored "
                       "distance-driven walk cycle"),
        }, fh, indent=2)
    log("wrote %s" % os.path.relpath(OUT_KEY, REPO_ROOT))


if __name__ == "__main__":
    main()
