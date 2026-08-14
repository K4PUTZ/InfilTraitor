"""CHARACTER_MASTER_PLAN Part 0 / S2 — the turn's RATE, side by side.

THE QUESTION THIS CLOSES. S2's first pass answered "how many in-betweens"
(Director, 2026-08-14: "faz muita diferenca cada um", 7+ clearly best). What it
did NOT answer is the other half, and the two are linked: how LONG the turn
lasts. CHARACTER_MASTER_PLAN §6 correction 2 states the link exactly -- a sprite
frame cannot be shown for less than one rendered frame, so a turn of D seconds
at F fps displays at most D*F frames. Pick a frame count and you have picked a
minimum duration; pick a duration and you have capped the useful frame count.
This is the last thing blocking a frame budget (RESUMO_SESSAO 2026-08-14 §9 #1).

WHAT "30 Hz" MEANS HERE, AND WHAT IT DOES NOT. It is NOT a slow device. The
animation is time-driven (floating_collectible.gd:331), so a phone delivering 30
fps keeps the duration and DROPS frames -- graceful, and the exact bug D26/v1.5
already paid for once. The 30 Hz panel is a deliberate AUTHORING choice: hold
each sprite frame for two rendered frames, spending the same 17 images over
twice the wall-clock time. Same asset, same RAM, different feel. Labelling it as
a device condition would make the Director judge the wrong thing.

WHY MP4 AND NOT GIF -- this is a fidelity decision, not a format preference. GIF
stores its delay in centiseconds, so 16.67 ms rounds to 2 cs = 20 ms and a "60
Hz" GIF actually plays at 50 Hz, a 17% error on the exact quantity under
judgement; many viewers additionally clamp sub-2 cs delays to 10 cs. The whole
question here is cadence, so the container must not quantise it. Encoding at a
fixed 60 fps and holding each source frame an INTEGER number of output frames is
exact by construction: 60 Hz holds 1, 30 Hz holds 2.

HONEST SCOPE -- inherited from s2_turn_render.py and restated so it is not lost
by being one file away. These frames are rendered in Blender at the game's
camera convention (elevation 30, azimuth 45), NOT baked through Godot and relit
by flat_normal_relight.gdshader. The question is MOTION CADENCE, which camera
angle and frame timing decide. Nothing here is evidence about the runtime
pipeline and must not be cited as such.

INPUT. Reuses the frame sequences s2_turn_render.py already wrote to
Screenshots/s2_turn/turn_N_inbetween/. Nothing is re-rendered and nothing is
re-eased here -- the head-lead authoring lives in that script and stays there,
because two copies of "how the turn is authored" drift the first time one is
tuned. Regenerate the inputs with:

  S2_CANDIDATES=7,11,15,23 /Applications/Blender.app/Contents/MacOS/Blender \
    --background --python tools/asset_generation/s2_turn_render.py

Run (plain system python3 -- no Blender, no Godot):
  python3 tools/asset_generation/s2_turn_rate_compare.py
"""

import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_ROOT = os.path.join(REPO_ROOT, "Screenshots", "s2_turn")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "history")
WORK_DIR = os.path.join(REPO_ROOT, "Screenshots", "s2_turn", "_rate_compare_work")

# The encode rate. Every hold below is an integer count of THESE frames, which
# is what makes the timing exact rather than approximately right.
OUT_FPS = 60
FRAME_MS = 1000.0 / OUT_FPS

# Establish the start pose before the turn, and let the arrival land after it.
# Without both, a bare loop of the sweep makes every option look smoother than
# it is -- the same reason s2_turn_render.py holds its first and last frame.
PRE_HOLD_FRAMES = 30    # 500 ms
POST_HOLD_FRAMES = 45   # 750 ms

BG = (58, 58, 62)
PANEL_BG = (72, 72, 78)
INK = (238, 238, 242)
INK_DIM = (168, 168, 176)
ACCENT = (255, 196, 78)
ARRIVED = (120, 220, 140)

PAD = 18
HEADER_H = 62
FOOTER_H = 52
GAP = 14

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def log(m):
    print("[S2-RATE] %s" % m)


def fail(m):
    print("[S2-RATE][FAIL] %s" % m)
    sys.exit(1)


def font(size, bold=False):
    for path in FONT_CANDIDATES:
        if os.path.isfile(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def fit_font(text, max_w, start=22, floor=12):
    """Largest size at which `text` fits `max_w`. Panels are sized by the render
    scale, not by their labels, so a fixed size clips the moment a panel narrows
    -- video B's titles lost their millisecond figures at scale 0.72, which is
    the one number the panel exists to state."""
    for size in range(start, floor - 1, -1):
        f = font(size)
        if f.getlength(text) <= max_w:
            return f
    return font(floor)


def wrap(text, fnt, max_w):
    """Word-wrap to a pixel width. The canvas is sized by the panels, so a
    caption long enough to say something honest overflows it -- the first run
    silently clipped '...an integer number of' mid-sentence at the right edge."""
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if fnt.getlength(trial) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def load_sequence(inbetweens):
    """Load one rendered turn. Loud-fail on a missing or short sequence rather
    than silently comparing against whatever happens to be on disk."""
    d = os.path.join(SRC_ROOT, "turn_%d_inbetween" % inbetweens)
    if not os.path.isdir(d):
        fail("missing frame sequence: %s\n"
             "Regenerate it with s2_turn_render.py (see this file's header)." % d)
    expected = inbetweens + 2
    frames = []
    for i in range(expected):
        p = os.path.join(d, "f%02d.png" % i)
        if not os.path.isfile(p):
            fail("%s has %d/%d frames -- missing %s"
                 % (d, len(frames), expected, os.path.basename(p)))
        frames.append(Image.open(p).convert("RGBA"))
    log("loaded %2d in-between(s) -> %2d frames from %s"
        % (inbetweens, expected, os.path.relpath(d, REPO_ROOT)))
    return frames


class Track:
    """One panel: a frame sequence, and how many rendered frames each of its
    images is held for. `hold` is the whole knob -- 1 = 60 Hz, 2 = 30 Hz.

    DURATION COUNTS FRAMES, NOT GAPS, and the distinction is load-bearing. Every
    one of the N images must occupy at least one rendered frame to be seen at
    all, so the turn costs N*hold frame slots -- not (N-1). Measuring the gaps
    instead would treat the arrival frame as instantaneous and understate the
    requirement by one frame, which is exactly the quantity the display ceiling
    is about. This matches CHARACTER_MASTER_PLAN §6's table (9 frames -> 150 ms,
    17 -> 283 ms, 25 -> 417 ms).

    Every label is DERIVED from these numbers, never passed in. The first run of
    this script hardcoded "283 ms" in a title beside a readout that computed
    267 ms from the gap convention -- two numbers for one quantity in one image,
    which is how evidence discredits itself."""

    def __init__(self, frames, hold, hz_label, subtitle, blind=False):
        self.frames = frames
        self.hold = hold
        self.blind = blind
        self.subtitle = "" if blind else subtitle
        self.count = len(frames)
        self.duration_ms = self.count * hold * FRAME_MS
        self.finish_frame = self.count * hold
        # A blind panel prints its label and nothing else. Every number is a
        # tell -- a millisecond figure or a frame count lets "more must be
        # better" answer the question instead of the eye.
        self.title = hz_label if blind \
            else "%s  —  %d ms" % (hz_label, round(self.duration_ms))

    def index_at(self, k):
        return min(k // self.hold, self.count - 1)

    def elapsed_ms_at(self, k):
        return min(k, self.finish_frame) * FRAME_MS


def draw_panel(track, k, scale):
    """Render one panel at output frame k (k counted from the turn's start)."""
    src = track.frames[track.index_at(k)]
    w, h = src.size
    if scale != 1.0:
        w, h = int(w * scale), int(h * scale)
        src = src.resize((w, h), Image.LANCZOS)

    panel = Image.new("RGBA", (w + PAD * 2, HEADER_H + h + FOOTER_H), PANEL_BG)
    panel.alpha_composite(src, (PAD, HEADER_H))
    d = ImageDraw.Draw(panel)

    d.text((PAD, 12), track.title, font=fit_font(track.title, w), fill=INK)
    d.text((PAD, 38), track.subtitle,
           font=fit_font(track.subtitle, w, start=14, floor=10), fill=INK_DIM)

    done = k >= track.finish_frame
    bar_y = HEADER_H + h + 16

    if track.blind:
        # The arrival beat still has to be readable -- it is half of what makes
        # a cadence feel settled or sluggish -- but it is shown as a state, not
        # as a number, and without a progress bar (a bar filling at different
        # rates side by side is a duration readout in disguise).
        d.ellipse([PAD, bar_y + 6, PAD + 12, bar_y + 18],
                  fill=ARRIVED if done else ACCENT)
        d.text((PAD + 20, bar_y + 4), "arrived" if done else "turning",
               font=font(15), fill=ARRIVED if done else ACCENT)
        return panel

    # Progress bar + live elapsed readout. The arrival beat is the thing being
    # judged, so it gets its own colour rather than being inferred from the bar.
    bar_w = w
    d.rectangle([PAD, bar_y, PAD + bar_w, bar_y + 6], fill=(48, 48, 52))
    prog = min(1.0, k / float(max(1, track.finish_frame)))
    if prog > 0:
        d.rectangle([PAD, bar_y, PAD + int(bar_w * prog), bar_y + 6],
                    fill=ARRIVED if done else ACCENT)
    label = "ARRIVED  %d ms" % round(track.duration_ms) if done \
        else "turning  %d ms" % round(track.elapsed_ms_at(k))
    counter = "frame %d/%d" % (track.index_at(k) + 1, track.count)
    fl = font(15)
    d.text((PAD, bar_y + 14), label, font=fl, fill=ARRIVED if done else ACCENT)
    # Right-align the counter off its MEASURED width, and drop it entirely
    # rather than let it collide -- "150 msframe 9/9" is worse than no counter.
    cw = fl.getlength(counter)
    if fl.getlength(label) + 14 + cw <= bar_w:
        d.text((PAD + bar_w - cw, bar_y + 14), counter, font=fl, fill=INK_DIM)
    return panel


def build_video(tracks, out_name, caption, scale=1.0):
    """Composite every panel per output frame and encode at exactly OUT_FPS.

    All tracks start together and the loop restarts only after the SLOWEST has
    finished and held -- so a faster option is visibly seen waiting, which is
    what its snappiness actually buys and what a per-clip comparison hides."""
    if os.path.isdir(WORK_DIR):
        shutil.rmtree(WORK_DIR)
    os.makedirs(WORK_DIR)

    turn_frames = max(t.finish_frame for t in tracks) + 1
    total = PRE_HOLD_FRAMES + turn_frames + POST_HOLD_FRAMES

    probe = [draw_panel(t, 0, scale) for t in tracks]
    pw, ph = probe[0].size
    canvas_w = PAD + len(tracks) * (pw + GAP) - GAP + PAD
    cap_font = font(15)
    cap_lines = wrap(caption, cap_font, canvas_w - PAD * 2)
    canvas_h = PAD + ph + 14 + len(cap_lines) * 20 + PAD

    for out_i in range(total):
        k = max(0, min(out_i - PRE_HOLD_FRAMES, turn_frames - 1))
        canvas = Image.new("RGBA", (canvas_w, canvas_h), BG)
        for j, t in enumerate(tracks):
            canvas.alpha_composite(draw_panel(t, k, scale),
                                   (PAD + j * (pw + GAP), PAD))
        d = ImageDraw.Draw(canvas)
        for li, line in enumerate(cap_lines):
            d.text((PAD, PAD + ph + 14 + li * 20), line, font=cap_font, fill=INK_DIM)
        canvas.convert("RGB").save(os.path.join(WORK_DIR, "o%04d.png" % out_i))

    out_path = os.path.join(OUT_DIR, out_name)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-framerate", str(OUT_FPS),
        "-i", os.path.join(WORK_DIR, "o%04d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-r", str(OUT_FPS),
        # -crf 16: the judgement is about motion, and macroblocking on a moving
        # low-contrast silhouette would be read as the animation's fault.
        "-crf", "16",
        "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
        out_path,
    ]
    subprocess.run(cmd, check=True)
    shutil.rmtree(WORK_DIR)

    dur = total / float(OUT_FPS)
    log("wrote %s  (%d frames @ %d fps = %.2fs loop, %dx%d)"
        % (os.path.relpath(out_path, REPO_ROOT), total, OUT_FPS, dur,
           canvas_w, canvas_h))
    return out_path


def build_contact_sheet(frames, out_name):
    """The durable record. An MP4 answers the question; a strip is what a future
    session can still read after the answer is a sentence in a plan."""
    w, h = frames[0].size
    scale = 0.55
    tw, th = int(w * scale), int(h * scale)
    n = len(frames)
    sheet_h = 78 + th + 66
    sheet = Image.new("RGBA", (PAD + n * (tw + 4) - 4 + PAD, sheet_h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 14), "S2 — the 90° turn, 15 in-betweens (17 frames)",
           font=font(24), fill=INK)
    d.text((PAD, 44),
           "Same 17 images either way. The only knob is how long each is held.",
           font=font(15), fill=INK_DIM)

    for i, f in enumerate(frames):
        sheet.alpha_composite(f.resize((tw, th), Image.LANCZOS),
                              (PAD + i * (tw + 4), 78))

    # Two rulers under the strip: where each frame lands in wall-clock time.
    for row, (hold, hz, col) in enumerate([(1, 60, ACCENT), (2, 30, ARRIVED)]):
        y = 78 + th + 8 + row * 28
        total_ms = n * hold * FRAME_MS
        d.text((PAD, y), "%d Hz — hold %d — %d ms total" % (hz, hold, round(total_ms)),
               font=font(15), fill=col)
        d.line([PAD + 260, y + 9, PAD + n * (tw + 4) - 4, y + 9], fill=col, width=2)
    return sheet.convert("RGB").save(os.path.join(OUT_DIR, out_name)) or \
        os.path.join(OUT_DIR, out_name)


def main():
    if shutil.which("ffmpeg") is None:
        fail("ffmpeg not found on PATH")
    os.makedirs(OUT_DIR, exist_ok=True)

    seq15 = load_sequence(15)

    # --- A. The requested comparison: one asset, two rates. ---
    a = build_video(
        [
            Track(seq15, 1, "60 Hz", "1 sprite frame per rendered frame"),
            Track(seq15, 2, "30 Hz", "each sprite frame held 2 rendered frames"),
        ],
        "s2_turn_rate_60hz_vs_30hz.mp4",
        "Identical 17-frame asset, identical RAM. Encoded at a true 60 fps — "
        "each hold is an integer number of rendered frames, so the timing is exact.",
    )

    # --- B. The other axis, at the display ceiling. ---
    # On this line every sprite frame is held exactly one rendered frame, so
    # frame count and duration are the SAME knob and each option is the most
    # smoothness its duration can physically show. Anything past it is RAM
    # spent on images the player never sees.
    tracks_b = []
    for n in (7, 11, 15, 23):
        seq = load_sequence(n)
        tracks_b.append(Track(seq, 1, "%d in-betweens" % n,
                              "%d frames, 1 rendered frame each" % (n + 2)))
    b = build_video(
        tracks_b,
        "s2_turn_ceiling_60hz.mp4",
        "All four at the display ceiling: 1 sprite frame per rendered frame. "
        "Here frame count and duration are the same knob — pick the cadence, "
        "the frame count follows.",
        scale=0.72,
    )

    sheet = build_contact_sheet(seq15, "s2_turn_rate_contact_sheet.png")

    log("")
    log("=== THE TWO KNOBS, AND WHY THEY ARE ONE ===")
    log("A sprite frame cannot show for less than one rendered frame (16.67 ms).")
    for n in (7, 11, 15, 23):
        frames = n + 2
        log("  %2d in-betweens = %2d frames -> >= %3d ms at 60 Hz, %3d ms at 30 Hz"
            % (n, frames, round(frames * FRAME_MS), round(frames * 2 * FRAME_MS)))
    log("")
    log("=== WHAT EACH COSTS (CHARACTER_MASTER_PLAN §8) ===")
    log("body = archetype(2) x silhouette(3) x pose(8) x yaw")
    for n in (7, 11, 15, 23):
        yaws = 4 + 4 * n
        log("  %2d in-betweens -> %3d distinct yaws -> %5d body sets"
            % (n, yaws, 2 * 3 * 8 * yaws))
    log("")
    for p in (a, b, sheet):
        log("evidence: %s" % os.path.relpath(p, REPO_ROOT))


if __name__ == "__main__":
    main()
