"""CHARACTER_MASTER_PLAN Part 3 — how fine does the head sweep need to be?

The layer system indexes head art by ABSOLUTE YAW, and the number of yaws is the
one free parameter in it. `AgentSprite` counts what is on disk, so the answer is a
bake flag (`P3_LAYER_YAWS`) and not a code change — which makes this a question to
LOOK at rather than to argue.

WHAT IT SIMULATES, and it is the game's own motion rather than an even sweep. The
guard's head is driven by `vision_angle`, which approaches its target through
`lerp_angle(current, target, clampf(TURN_SPEED * 1.35 * delta, 0, 1))` — an
exponential approach, fast at the start and slow at the end. An evenly-spaced
sweep would flatter the coarse bracket exactly where the real motion is quickest,
which is where stepping shows. Frames are emitted at 50 fps against the game's 60;
the approach has the same rate constant either way, so the trajectory in WALL TIME
is the same and only the sampling differs.

THE PANELS ARE BLIND. Column order is shuffled and the key is written to a
separate file, because a bracket whose panels are labelled coarse-to-fine is a
bracket that answers itself — the lesson of the turn-rate bracket
(CHARACTER_MASTER_PLAN, 2026-08-15), where every judgement came back "the last
one" until the labels came off.

It composites with the runtime's own three terms (-anchor + crop origin + socket
delta, AgentSprite._apply_layers). That is a SECOND implementation and is
deliberately not the arbiter of whether the layers register — `_verify_layers` in
the bake is, in-engine, against a bake of the whole figure. This one exists to
judge MOTION, which no pixel count can answer.

Run (after baking the bracket variants):
  python3 tools/asset_generation/p3_head_sweep_sheet.py \\
      --dirs x24:agent_head,agent_hat x36:x36_agent_head,x36_agent_hat
"""

import argparse
import json
import os
import random

from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BAKES = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets", "actor_bakes")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "p3_head_sweep")

## guard_enemy.gd: TURN_SPEED 4.0, and the head tracks 1.35x faster than the body.
TURN_SPEED = 4.0
HEAD_RATE = TURN_SPEED * 1.35
DT = 1.0 / 50.0
## AgentSprite.HEAD_YAW_LIMIT_DEG — the head cannot leave this band, so the
## bracket must not either or it would compare motion the game never shows.
LIMIT = 60.0
## Look right, hold, look left, hold, centre. Seconds per leg.
LEGS = [(LIMIT, 1.2), (LIMIT, 0.4), (-LIMIT, 1.6), (-LIMIT, 0.4), (0.0, 1.2)]
SCALE = 2


def simulate():
    """The head's yaw over time, as the guard's own lerp produces it."""
    yaw, out = 0.0, []
    for target, seconds in LEGS:
        for _ in range(int(seconds / DT)):
            yaw += (target - yaw) * min(HEAD_RATE * DT, 1.0)
            out.append(yaw)
    return out


def load_layer(path):
    man = json.load(open(os.path.join(path, "layer.json")))
    frames = []
    for f in man["frames"]:
        tag = int(round(f["yaw"] % 360.0))
        frames.append(dict(
            img=Image.open(os.path.join(path, "yaw_%03d_color.png" % tag)).convert("RGBA"),
            origin=tuple(f["origin_px"]),
            yaw=f["yaw"]))
    return frames, 360.0 / float(len(frames))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", nargs="+", required=True,
                    help="label:headdir[,hatdir] — directories under actor_bakes/, "
                         "each holding <posture>/")
    ap.add_argument("--body", default="agent_frames")
    ap.add_argument("--posture", default="standing")
    ap.add_argument("--facing", default="N")
    args = ap.parse_args()

    body_dir = os.path.join(BAKES, args.body, args.posture)
    anchor = json.load(open(os.path.join(body_dir, "anchor.json")))
    if not anchor.get("headless"):
        raise SystemExit("[P3-SWEEP][FAIL] %s still carries a baked head — there is "
                         "nothing for a layer to sit on" % body_dir)
    body = Image.open(os.path.join(body_dir, "frame_%s_color.png" % args.facing)).convert("RGBA")
    ax, ay = anchor["anchor_px"]
    ## The body's socket for this facing and the layer's own base socket cancel
    ## whenever a layer was baked from the posture it is drawn on — which is the
    ## case here. Kept explicit so the arithmetic matches the runtime's, rather
    ## than matching it only by coincidence.
    body_socket = anchor["head_socket_px"][args.facing]

    brackets = []
    for spec in args.dirs:
        label, dirs = spec.split(":", 1)
        layers = []
        for d in dirs.split(","):
            frames, step = load_layer(os.path.join(BAKES, d, args.posture))
            base = json.load(open(os.path.join(BAKES, d, args.posture, "layer.json")))
            layers.append((frames, step, base["base_socket_px"][args.facing]))
        brackets.append((label, layers))

    order = list(range(len(brackets)))
    random.shuffle(order)

    yaws = simulate()
    W, H = body.size
    pad = 12
    cell = (W, H)
    sheet_frames = []
    for yaw in yaws:
        row = Image.new("RGBA", (len(brackets) * (cell[0] + pad) - pad, cell[1]),
                        (12, 12, 14, 255))
        for column, index in enumerate(order):
            _, layers = brackets[index]
            panel = Image.new("RGBA", cell, (0, 0, 0, 0))
            panel.alpha_composite(body, (0, 0))
            for frames, step, base_socket in layers:
                i = int(round((yaw % 360.0) / step)) % len(frames)
                f = frames[i]
                dx = f["origin"][0] + (body_socket[0] - base_socket[0])
                dy = f["origin"][1] + (body_socket[1] - base_socket[1])
                panel.alpha_composite(f["img"], (int(round(dx)), int(round(dy))))
            row.alpha_composite(panel, (column * (cell[0] + pad), 0))
        sheet_frames.append(row.convert("RGB").resize(
            (row.width * SCALE, row.height * SCALE), Image.NEAREST))

    os.makedirs(OUT_DIR, exist_ok=True)
    gif = os.path.join(OUT_DIR, "head_sweep_blind.gif")
    sheet_frames[0].save(gif, save_all=True, append_images=sheet_frames[1:],
                         duration=int(DT * 1000), loop=0, optimize=False)
    key_path = os.path.join(OUT_DIR, "head_sweep_key.txt")
    with open(key_path, "w") as fh:
        for column, index in enumerate(order):
            label, layers = brackets[index]
            fh.write("column %d (left to right) = %s, %d yaws, %.1f deg step\n"
                     % (column + 1, label, len(layers[0][0]), layers[0][1]))
    print("[P3-SWEEP] %d frames, %d columns -> %s"
          % (len(sheet_frames), len(brackets), os.path.relpath(gif, REPO_ROOT)))
    print("[P3-SWEEP] key (do not read before judging): %s"
          % os.path.relpath(key_path, REPO_ROOT))


main()
