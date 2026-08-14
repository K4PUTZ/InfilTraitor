"""CHARACTER_MASTER_PLAN Part 0 / S2 — composites the corner sheets.

Two deliverables, and they are deliberately different KINDS of thing.

SHEET 1 -- the step-duration finding. Labelled, not blind, because it is a
measurement rather than a matter of taste: one GU is 1.60 m
(VOXELS_PER_UNIT_AXIS 8 x 0.20 m), so agent.gd's STEP_DURATION of 0.13 s is
12.3 m/s -- faster than the 100 m world record. That constant was tuned for a
legless vector diamond. Nothing is being asked here; the sheet exists so the
number is seen rather than argued.

SHEET 2 -- the Director's actual question, BLIND and RANDOMISED. Four mechanisms
for how facing changes during ordinary movement. Blind because the turn test
already paid for that lesson once: labels only, no names, no durations, no
progress bar, and the order seeded so the option with the MOST animation is not
last -- "the last one" and "the most one" landing on the same panel is precisely
the confound being controlled.

Run (plain system python3 -- no Blender, no Godot):
  python3 tools/asset_generation/s2_corner_compare.py
"""

import glob
import json
import os
import random

from PIL import Image

from s2_turn_rate_compare import (OUT_DIR, REPO_ROOT, Track, build_video, fail,
                                  log)

SRC_ROOT = os.path.join(REPO_ROOT, "Screenshots", "s2_corner")
SEED = 20260815

TREATMENTS = ["TURN_THEN_MOVE", "INERTIAL", "ANTICIPATED", "SNAP"]

BLURB = {
    "TURN_THEN_MOVE": "stop at the corner, turn in place (833 ms), then step",
    "INERTIAL": "rotation spread across the outgoing step — one motion, no added time",
    "ANTICIPATED": "rotation runs in the tail of the incoming step; arrives already facing",
    "SNAP": "no turn frames at all; facing flips at the GU boundary",
}


def load_dir(name):
    d = os.path.join(SRC_ROOT, name)
    paths = sorted(glob.glob(os.path.join(d, "f*.png")))
    if not paths:
        fail("no frames in %s\nRun s2_corner_render.py first." % d)
    log("loaded %3d frames from %s" % (len(paths), os.path.relpath(d, REPO_ROOT)))
    return [Image.open(p).convert("RGBA") for p in paths]


def main():
    # --- Sheet 1: the speed finding. -------------------------------------
    speeds = []
    for ms in (130, 500, 900):
        seq = load_dir("speed_%dms" % ms)
        speeds.append(Track(seq, 1, "%d ms per GU" % ms,
                            "%.1f m/s over 1.60 m" % (1.60 / (ms / 1000.0)),
                            verb="moving"))
    build_video(
        speeds,
        "s2_step_duration.mp4",
        "One GU is 1.60 m (VOXELS_PER_UNIT_AXIS 8 × 0.20 m). agent.gd's "
        "STEP_DURATION is 0.13 s — the left panel — which is 12.3 m/s, faster "
        "than the 100 m world record. It was tuned for a legless vector diamond.",
        scale=0.85,
    )

    # --- Sheet 2: the corner question, blind. ----------------------------
    tracks = []
    for name in TREATMENTS:
        seq = load_dir("corner_%s" % name)
        tracks.append((name, Track(seq, 1, "", "", blind=True, verb="moving")))

    rng = random.Random(SEED)
    most = max(tracks, key=lambda t: t[1].count)   # TURN_THEN_MOVE
    order = tracks[:]
    for _ in range(200):
        rng.shuffle(order)
        if order[-1] is not most:
            break
    else:
        raise RuntimeError("could not place the longest option away from last")

    labels = "ABCD"
    for i, (_, tr) in enumerate(order):
        tr.title = labels[i]

    key = {labels[i]: {"treatment": name,
                       "frames": tr.count,
                       "total_ms": round(tr.duration_ms),
                       "what": BLURB[name]}
           for i, (name, tr) in enumerate(order)}

    build_video(
        [tr for _, tr in order],
        "s2_corner_blind.mp4",
        "Same L-shaped path (GU A → B → C, one 90° corner), same 500 ms step. "
        "Only WHEN the facing changes differs. Which panel is which is "
        "randomised — judge by eye, then read the key.",
        scale=0.72,
    )

    key_path = os.path.join(OUT_DIR, "s2_corner_blind_KEY.json")
    with open(key_path, "w") as fh:
        json.dump({"seed": SEED, "step_ms": 500, "gu_metres": 1.60,
                   "panels": key}, fh, indent=2)

    log("")
    log("=== ANSWER KEY (read AFTER judging) -> %s ==="
        % os.path.relpath(key_path, REPO_ROOT))
    for lab in labels:
        v = key[lab]
        log("  %s = %-15s %4d ms — %s"
            % (lab, v["treatment"], v["total_ms"], v["what"]))
    log("")
    log("=== WHAT EACH COSTS PER DIRECTION CHANGE ===")
    base = min(v["total_ms"] for v in key.values())
    for lab in labels:
        v = key[lab]
        log("  %-15s %4d ms  (+%d ms over the cheapest)"
            % (v["treatment"], v["total_ms"], v["total_ms"] - base))
    log("")
    log("If SNAP survives, movement needs no transition yaws at all and §9 #10")
    log("collapses to its 744-body-set row: only aim mode pays for the other 92.")


if __name__ == "__main__":
    main()
