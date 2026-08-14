"""CHARACTER_MASTER_PLAN Part 0 / S2 — bracketing the sluggish end, blind.

WHY THIS EXISTS. The Director, 2026-08-15, after judging every S2 comparison so
far: "Em todos os exemplos ate agora a ultima opcao sempre foi a melhor." That is
the single most useful thing anyone has said about this test, and it invalidates
the conclusion rather than confirming it -- for two independent reasons.

1. THE RANGE WAS NEVER BRACKETED. If the last option always wins, the preference
   is monotonic across everything tested, which means the test never contained
   the answer. D45's entire premise is that a turn-based game has a ceiling
   where smooth becomes SLUGGISH. A test that never renders a sluggish option
   cannot find that ceiling; it can only report "more was better again". So this
   script deliberately runs PAST where it should break: 47 in-betweens at 30 Hz
   is a 1633 ms turn for one 90-degree facing change.

2. POSITION AND LABEL BIAS ARE UNCONTROLLED. Every previous sheet ordered the
   panels by increasing frame count, left to right, with the count printed on
   each. "The last one" and "the most frames" were the same panel every time, so
   the two explanations are indistinguishable in the data collected. Here the
   order is RANDOMISED and the labels are BLIND (A/B/C/D, no counts, no
   milliseconds, no progress bar -- see Track.blind). The randomisation is
   additionally constrained so the slowest option is NOT last, which is what
   makes the two explanations separable: picking the rightmost panel now means
   something different from picking the slowest one.

WHAT IS HELD CONSTANT. Every panel runs at 30 Hz (hold 2), the rate the Director
picked, so this varies ONE thing: how many in-betweens, and therefore how long
the turn takes. Mixing both knobs again would reproduce the same confound in a
new costume.

THE CONFOUND THIS DOES *NOT* CONTROL, stated because it may be the real story.
s2_turn_render.py rotates the whole armature object plus the head and chest
bones; the thigh/shin/foot bones the rig has are never posed. So the turn is a
rigid pivot with the feet glued, sliding on the floor. A slide has no discrete
beat to be sharp about, so more in-betweens can only ever make it smoother --
which is exactly the monotonic result observed. A turn with a real foot replant
has an event in it, and that is where "too many frames" would start to read as
floaty rather than as fluid. Bracketing the duration and fixing the footwork are
two separate experiments and this is only the first.

HONEST SCOPE. Inherited from s2_turn_render.py: Blender at the game camera
(elevation 30, azimuth 45), NOT baked through Godot and relit. Cadence only.

Run (plain system python3 -- no Blender, no Godot):
  python3 tools/asset_generation/s2_turn_bracket_blind.py

The answer key is written next to the video and is meant to be read AFTER the
judgement, not before.
"""

import json
import os
import random

from s2_turn_rate_compare import (OUT_DIR, REPO_ROOT, Track, build_video,
                                  load_sequence, log)

# All at 30 Hz -- the rate the Director chose -- so only the frame count varies.
HOLD = 2
CANDIDATES = [15, 23, 31, 47]

# Fixed so the run reproduces, and so the key below is a fact rather than a
# rerun-dependent guess.
SEED = 20260815


def main():
    tracks = []
    for n in CANDIDATES:
        seq = load_sequence(n)
        tracks.append((n, Track(seq, HOLD, "", "", blind=True)))

    # Randomise, but reject any order that leaves the slowest option last --
    # that is the one arrangement in which "picked the last panel" and "picked
    # the slowest panel" stay indistinguishable, which is the whole point.
    rng = random.Random(SEED)
    slowest = max(tracks, key=lambda t: t[1].duration_ms)
    order = tracks[:]
    for _ in range(200):
        rng.shuffle(order)
        if order[-1] is not slowest:
            break
    else:
        raise RuntimeError("could not place the slowest option away from last")

    labels = "ABCD"
    for i, (_, tr) in enumerate(order):
        tr.title = labels[i]

    key = {labels[i]: {"in_betweens": n,
                       "frames": tr.count,
                       "duration_ms": round(tr.duration_ms)}
           for i, (n, tr) in enumerate(order)}

    build_video(
        [tr for _, tr in order],
        "s2_turn_bracket_blind.mp4",
        "Same turn, same 30 Hz rate. Only the number of in-betweens differs, "
        "and which panel is which is randomised. Judge by eye, then read the "
        "key — one of these is deliberately far past where it should feel good.",
        scale=0.72,
    )

    key_path = os.path.join(OUT_DIR, "s2_turn_bracket_blind_KEY.json")
    with open(key_path, "w") as fh:
        json.dump({"seed": SEED, "hold": HOLD, "rate_hz": 30, "panels": key},
                  fh, indent=2)

    log("")
    log("=== ANSWER KEY (read AFTER judging) -> %s ==="
        % os.path.relpath(key_path, REPO_ROOT))
    for lab in labels:
        v = key[lab]
        log("  %s = %2d in-betweens, %2d frames, %4d ms"
            % (lab, v["in_betweens"], v["frames"], v["duration_ms"]))
    log("")
    log("=== WHAT THE SLOWEST WOULD COST (CHARACTER_MASTER_PLAN §8) ===")
    for n in CANDIDATES:
        yaws = 4 + 4 * n
        log("  %2d in-betweens -> %3d yaws -> %5d body sets"
            % (n, yaws, 2 * 3 * 8 * yaws))


if __name__ == "__main__":
    main()
