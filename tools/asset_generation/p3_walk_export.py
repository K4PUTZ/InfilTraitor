"""CHARACTER_MASTER_PLAN Part 3 — the walk cycle, exported for the Godot bake.

WHY THIS COMES BEFORE THE STEP-DURATION BRACKET, which is the opposite of the
order it was planned in. §9 #12 asks how long a GU step should last, and the
obvious way to answer it is to render the agent crossing a tile at several
durations and let the Director judge. That test cannot work on the figure as it
stands, and the reason is already written down in this plan: the turn bracket's
objection 3, where `s2_turn_render.py` rotated a figure whose feet never moved
and the Director's preference came back MONOTONIC, because *a slide contains no
discrete beat*. A sliding walk has the same defect for the same reason. The
duration and the leg cadence are one question, so the legs have to exist first.

DISTANCE-DRIVEN, WHICH IS WHAT MAKES THAT SAFE. The swing is a function of how
far the agent has travelled, never of how long he has been travelling, so this
one asset is correct at EVERY duration the bracket will test. Nothing here
presupposes the answer the bracket is about to produce.

ONE CYCLE PER GU, AND THAT IS DERIVED RATHER THAN CHOSEN. A full walk cycle is
two footfalls. A ~1.9 m figure's footfall is ~0.80 m, so a cycle covers ~1.60 m —
and a GU is 1.60 m exactly (VOXELS_PER_UNIT_AXIS 8 x 0.20 m). So the cycle length
falls out of the grid rather than being tuned onto it, and the phase is periodic
per tile: the foot plants on the boundary, every tile, forever.

That number is also a correction. `s2_corner_render.py` set `STRIDE_M = 0.80`
while its own comment describes stride as distance per FULL cycle, so it took
four footfalls per GU against a real figure's two. The Director caught it by
counting feet, which is why the corner result is recorded PROVISIONAL. This file
does not inherit the value.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/p3_walk_export.py
"""

import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p2_grip_spike as p2                                       # noqa: E402
import p3_posture_export as p3                                   # noqa: E402

GRIP = os.environ.get("P3_GRIP", "lowered")
WEAPON = os.environ.get("P3_WEAPON", "shotgun")

## How many samples of the cycle get baked. NOT a ratified number: it is the
## walk's counterpart of D46's in-between count, and it deserves its own blind
## bracket once the duration is settled. Eight is the classic walk-cycle count
## and reads at the size this figure ships at; it is a starting point that the
## same machinery can re-run at any other value.
PHASES = int(os.environ.get("P3_WALK_PHASES", "8"))

## Metres per FULL cycle (two footfalls) — see the docstring. One GU.
STRIDE_M = 1.60

## Peak joint angles at the extremes of the swing. The thigh leads, the knee
## rectifies (it only bends one way), the arms counter-swing.
THIGH_DEG = 26.0
SHIN_DEG = 34.0
ARM_DEG = 18.0
## The body rises on the passing leg and drops at the double-contact. Twice per
## cycle, which is what makes a walk bob rather than glide.
BOB_DEG = 3.0

OUT_DIR = os.path.join(p2.REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                       "imported_models", "agent", "walk")
SHEET_DIR = os.path.join(p2.REPO_ROOT, "Screenshots",
                         "p3_walk" + p2._MODEL.replace("agent_base", ""))


def log(m):
    print("[P3-WALK] %s" % m)


def fail(m):
    print("[P3-WALK][FAIL] %s" % m)
    sys.exit(1)


def walk_bones(phase01):
    """The pose at `phase01` of one full cycle, as a bone -> euler dict.

    The two legs are half a cycle apart, which is the definition of a walk (a
    run differs by having a flight phase, and this figure never runs).

    THE KNEE IS DRIVEN BY THE THIGH'S VELOCITY, NOT ITS POSITION, and getting
    that wrong is what the first version of this function did. Rectifying the
    POSITION term (`max(0, -sin)`) leaves BOTH knees straight whenever the legs
    pass through vertical — so phase 0 and phase 4 of 8 came out as byte-identical
    frames and the cycle silently collapsed into two identical half-cycles. That
    is the four-footfalls-per-GU defect `s2_corner_render.py` was caught with,
    arrived at from the other direction.

    `cos` is the derivative of `sin`, so `max(0, cos)` is "this leg is the one
    swinging FORWARD" — which is exactly the leg whose knee bends to clear the
    ground. At the passing pose one knee is fully bent and the other is straight
    and planted, and the two halves of the cycle become mirror images instead of
    copies."""
    out = {}
    for side, offset in (("L", 0.0), ("R", 0.5)):
        a = 2.0 * math.pi * (phase01 + offset)
        swing = math.sin(a)
        lift = max(0.0, math.cos(a))
        thigh = -THIGH_DEG * swing
        shin = SHIN_DEG * lift
        out["thigh_%s" % side] = (thigh, 0.0, 0.0)
        out["shin_%s" % side] = (shin, 0.0, 0.0)
        ## The ankle partly cancels the leg's own pitch, which keeps the sole
        ## near the floor through the plant and lifts the toe through the swing.
        ## Partial rather than total: a foot held perfectly level all cycle reads
        ## as a mannequin being slid, not as a step.
        out["foot_%s" % side] = (-(thigh + shin) * 0.6, 0.0, 0.0)
        ## Arms counter-swing: the LEFT arm goes with the RIGHT leg.
        out["upperarm_%s" % side] = (-ARM_DEG * swing, 0.0, 0.0)
    ## Twice per cycle — see BOB_DEG.
    out["spine"] = (BOB_DEG * math.cos(4.0 * math.pi * phase01), 0.0, 0.0)
    return out


def main():
    if not os.path.isfile(p2.BLEND):
        fail("model missing: %s — run p1_agent_model.py first" % p2.BLEND)
    key = (WEAPON, GRIP)
    if key not in p2.GRIPS:
        fail("P3_WEAPON/P3_GRIP = %s:%s is not one of %s"
             % (WEAPON, GRIP, ["%s:%s" % k for k in p2.ORDER]))

    p3._open_rig()
    p2.setup_render()
    facing = p2.measure_facings()
    export_facing = facing[p2.YAWS[0]]

    os.makedirs(OUT_DIR, exist_ok=True)
    written = []
    for i in range(PHASES):
        phase01 = float(i) / float(PHASES)
        log("=" * 70)
        log("phase %d/%d (%.3f of the cycle, %.3f m along the stride)"
            % (i + 1, PHASES, phase01, phase01 * STRIDE_M))
        arm = p3._open_rig()
        ## The ARMS are solved by p2's IK against the grip, exactly as the
        ## postures are; only the LEGS and the spine come from walk_bones. The
        ## arm counter-swing above therefore applies to the shoulder chain the
        ## solver then overwrites for the weapon hand — which is correct, and is
        ## why the one-handed idle arm is not used here.
        posture = p3.make_posture(
            "phase%02d" % i,
            bones=walk_bones(phase01),
            ## A walking figure is a standing figure: same band, and any phase
            ## that leaves it means a leg is bending the wrong way.
            band_vox=(9.2, 10.2),
            span_x_max_m=1.1,
        )
        out = p2.export_posed(arm, key, export_facing, posture=posture)
        ## export_posed writes beside the .blend; move it into the walk folder so
        ## one manifest describes one sequence.
        dest = os.path.join(OUT_DIR, "walk_%02d.glb" % i)
        os.replace(out, dest)
        written.append(dict(index=i, phase=phase01, glb=dest))

    log("=" * 70)
    os.makedirs(SHEET_DIR, exist_ok=True)
    heights = p3._render_previews(
        [("phase%02d" % w["index"], w["glb"]) for w in written], facing,
        out_dir=SHEET_DIR)

    manifest = dict(
        phases=PHASES,
        stride_m=STRIDE_M,
        grip="%s/%s" % (WEAPON, GRIP),
        frame=list(p3.PREVIEW_FRAME),
        px_per_screen_m=p2.PX_PER_SCREEN_M,
        voxel_m=p3.VOXEL_M,
        facings={str(k): v for k, v in facing.items()},
        postures=[dict(
            name="phase%02d" % w["index"],
            phase=round(w["phase"], 5),
            glb=os.path.relpath(w["glb"], p2.REPO_ROOT).replace(os.sep, "/"),
            out_dir="res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
                    "agent_walk%s/phase%02d/"
                    % (p2._MODEL.replace("agent_base", ""), w["index"]),
            height_m=round(heights["phase%02d" % w["index"]], 4),
            voxels=round(heights["phase%02d" % w["index"]] / p3.VOXEL_M, 2),
        ) for w in written],
    )
    os.makedirs(SHEET_DIR, exist_ok=True)
    with open(os.path.join(SHEET_DIR, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)

    lo = min(p["voxels"] for p in manifest["postures"])
    hi = max(p["voxels"] for p in manifest["postures"])
    log("%d phases exported; height varies %.2f to %.2f voxels (%.1f px of bob "
        "at ship scale) — that spread IS the walk's bob, not drift"
        % (PHASES, lo, hi, (hi - lo) * 20.0))
    log("manifest: %s" % os.path.relpath(
        os.path.join(SHEET_DIR, "manifest.json"), p2.REPO_ROOT))


if __name__ == "__main__":
    main()
