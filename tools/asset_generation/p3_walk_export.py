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
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# ORDER MATTERS: p3_posture_export sets P2_MODEL for the movement milestone
# (P3_DEV_ONLY) and p2_grip_spike reads it at IMPORT time to build its .blend
# path. Importing p2 first would resolve the model before the milestone had a
# say — and it would fail silently, with plausible filenames.
import p3_posture_export as p3                                   # noqa: E402
import p2_grip_spike as p2                                       # noqa: E402

GRIP = os.environ.get("P3_GRIP", "lowered")
WEAPON = os.environ.get("P3_WEAPON", "shotgun")

## How many samples of the cycle get baked.
##
## 32, RAISED FROM 8 ON 2026-08-16 because the Director called the walk
## *"engasgado"* and that word has a number behind it: at the ratified 560 ms per
## GU, 8 phases is one frame every 70 ms — **14.3 Hz**, less than half D46's
## ratified 30 Hz authoring rate for this character's motion. 32 phases is
## 17.5 ms, **57 Hz**.
##
## 32 is chosen so the count itself can be BRACKETED without re-baking: it
## subsamples exactly to 16 (29 Hz) and 8 (14 Hz), so a comparison of frame
## counts varies only how many of the SAME poses are shown. That is the property
## the turn's in-between bracket did not have and had to re-render for.
PHASES = int(os.environ.get("P3_WALK_PHASES", "32"))

## Metres per FULL cycle (two footfalls) — see the docstring. One GU.
STRIDE_M = 1.60

## Fraction of the cycle each foot spends PLANTED. Real walking is 0.60–0.62; a
## run is under 0.50 by definition (both feet leave the ground). 0.60 also means
## the two stance phases overlap by 0.20, which is the double-support a walk must
## have and a run must not.
DUTY = 0.60
## Peak toe clearance during the swing.
SWING_LIFT_M = 0.075

## --- REFINEMENT, added 2026-08-16 after the Director called the first walk
## --- *"mecânico e engasgado"*. Choppiness is the frame count (see PHASES);
## --- these are the other half — the things a leg does that a scissor does not.
##
## THE FOOT ROLLS. A real stance is heel-strike, flat, toe-off, and the ankle is
## HIGHER at both ends because the foot is pivoting on its heel and then on its
## toe. The first version held one ankle height and one foot angle for the whole
## stance, which is a stilt, not a foot. This also pays for itself twice: the
## raised ankle at the extremes is exactly where the leg was most over-stretched,
## so the hip drop the solver needs comes down with it.
ROLL_RISE_M = 0.055
HEEL_STRIKE_PITCH = 0.42       ## toe up, at the start of stance
TOE_OFF_PITCH = -0.62          ## heel up, at the end of stance
SWING_TOE_PITCH = 0.30
## The head holds still while the body bobs under it — the single strongest cue
## that a figure is alive rather than driven. Degrees per metre of hip drop.
HEAD_STABILISE_DEG_PER_M = 46.0
## The shoulders counter-rotate against the hips. Small, because both hands are
## on a shotgun (D40's `lowered`) and the weapon would swing with them.
TORSO_TWIST_DEG = 3.5

OUT_DIR = os.path.join(p2.REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                       "imported_models", "agent", "walk")
SHEET_DIR = os.path.join(p2.REPO_ROOT, "Screenshots",
                         "p3_walk" + p2._MODEL.replace("agent_base", ""))


def log(m):
    print("[P3-WALK] %s" % m)


def fail(m):
    print("[P3-WALK][FAIL] %s" % m)
    sys.exit(1)


def foot_target(phase01, side, ankle_z):
    """Where the ANKLE must be, in the body's own frame, at this phase.

    THE POSE IS SOLVED FROM THIS, NOT TUNED AGAINST IT — the same principle D40's
    grips already use, where the arm is solved from where the weapon must be
    rather than posed until the gun looks held. The first walk was authored as
    joint angles (a sinusoidal thigh swing plus a rectified knee) and it MOONWALKED:
    measured on 2026-08-16, the planted foot moved backward from phase 0 to 0.25
    and then **forward** from 0.25 to 0.5 while its z went to zero — the foot on
    the ground sliding forward under the body. No amount of angle tuning removes
    that, because 'the planted foot moves backward' is a property of the foot's
    PATH and the angles only reach it by coincidence.

    The path itself is the definition of a walk:
      · STANCE — the foot is on the floor and does not move in the world, so
        relative to the body it slides straight backward at the body's own speed.
      · SWING  — it lifts and returns forward over an arc.
    Relative displacement over a cycle is zero by construction, which is what
    makes the cadence periodic per GU."""
    ph = (phase01 + (0.5 if side == "R" else 0.0)) % 1.0
    half = STRIDE_M * DUTY * 0.5
    if ph < DUTY:
        t = ph / DUTY
        ## STANCE. The y term stays exactly linear — the foot is on the floor and
        ## the body passes over it at constant speed, so any easing here would be
        ## the foot sliding. The z term is the ROLL: the ankle pivots up over the
        ## heel at the start and over the toe at the end, and is lowest flat in
        ## the middle. (2t-1)^2 is that curve, 1 at both ends and 0 at the centre.
        rise = ROLL_RISE_M * (2.0 * t - 1.0) ** 2
        pitch = HEEL_STRIKE_PITCH + (TOE_OFF_PITCH - HEEL_STRIKE_PITCH) * t
        return half - 2.0 * half * t, ankle_z + rise, pitch, True
    ## SWING. Eased, because a swinging leg accelerates away from the ground and
    ## decelerates into the next strike; the first version moved it at a constant
    ## rate, which is the other half of "mechanical". smoothstep is the cheapest
    ## curve with zero velocity at both ends, which is what makes the hand-off
    ## into the stance invisible.
    t = (ph - DUTY) / (1.0 - DUTY)
    e = t * t * (3.0 - 2.0 * t)
    return (-half + 2.0 * half * e,
            ankle_z + SWING_LIFT_M * math.sin(math.pi * t),
            SWING_TOE_PITCH * math.sin(math.pi * t),
            False)


def solve_hip_drop(arm, targets, reach, cap=0.16):
    """The LEAST hip drop that brings both ankle targets inside the leg's reach.

    Same shape as `p2_grip_spike.shoulder_assist`, and for the same reason: a
    reach problem is solved by moving the ROOT of the chain by the minimum that
    makes the target reachable, never by shortening the target until it fits.
    The arm's version rotates the shoulder; the leg's drops the hips, which moves
    both legs at once and so cannot live inside one side's solve.

    THIS IS ALSO THE BOB. A walk's vertical oscillation is not decoration added
    on top — it is the consequence of a leg of fixed length having to reach a
    foot placed further away than it is long. Authoring it as a separate sine
    (the first version used a 3-degree spine wiggle) produces a bob that has
    nothing to do with the stride and therefore fights it."""
    hips = [arm.pose.bones["thigh_%s" % s].matrix.to_translation() for s in ("L", "R")]
    limit = reach * 0.985

    def worst(drop):
        out = 0.0
        for hip, target in zip(hips, targets):
            need = (Vector(target) - (hip - Vector((0.0, 0.0, drop)))).length
            out = max(out, need)
        return out

    if worst(0.0) <= limit:
        return 0.0
    lo, hi = 0.0, cap
    if worst(hi) > limit:
        return hi          ## the IK gate downstream decides whether that sufficed
    for _ in range(24):
        mid = (lo + hi) * 0.5
        if worst(mid) > limit:
            lo = mid
        else:
            hi = mid
    return hi


def make_walk_posture(name, phase01):
    """One phase, as the `posture` dict p2_grip_spike.export_posed consumes."""

    def apply(rig):
        bpy.context.view_layer.update()
        rest_root = rig.pose.bones["root"].matrix.copy()
        chest_before = rig.pose.bones["chest"].matrix.copy()

        ## Read off the rig, never from module constants — a re-proportioned
        ## model must re-solve rather than silently drift.
        ankle_z = rig.data.bones["foot_L"].head_local.z
        reach = rig.data.bones["thigh_L"].length + rig.data.bones["shin_L"].length
        hip_x = {s: rig.data.bones["thigh_%s" % s].head_local.x for s in ("L", "R")}

        legs = {}
        targets = []
        for side in ("L", "R"):
            y, z, pitch, planted = foot_target(phase01, side, ankle_z)
            legs[side] = (pitch, planted)
            targets.append(Vector((hip_x[side], y, z)))

        drop = solve_hip_drop(rig, targets, reach)

        ## The torso counter-rotates against the stride, and the head cancels the
        ## bob. Both are applied BEFORE the leg IK because the legs hang off the
        ## hips: posing the spine afterwards would move the feet off the targets
        ## the solver just hit.
        stride_swing = math.sin(2.0 * math.pi * phase01)
        p3._set_euler(rig, "chest", (0.0, 0.0, TORSO_TWIST_DEG * stride_swing))
        p3._set_euler(rig, "neck", (-HEAD_STABILISE_DEG_PER_M * drop * 0.5, 0.0, 0.0))
        p3._set_euler(rig, "head", (-HEAD_STABILISE_DEG_PER_M * drop * 0.5, 0.0, 0.0))
        bpy.context.view_layer.update()

        p3._place_root(rig, rest_root, Matrix.Translation(Vector((0.0, 0.0, -drop))))

        worst_err = 0.0
        for side, target in zip(("L", "R"), targets):
            pitch, _planted = legs[side]
            ## Knees bend FORWARD, so the pole is forward. The foot's own pitch
            ## comes from the roll curve rather than from a planted/swing flag —
            ## that flag was the stilt.
            err, _clamped, _k = p2.two_bone_ik(
                rig, side, target, (0.0, 1.0, -0.25), (0.0, 1.0, pitch),
                chain=p2.LEG_CHAIN, assist=False)
            worst_err = max(worst_err, err)

        if worst_err > 0.02:
            fail("%s: the leg could not reach its foot target (%.4f m off) even "
                 "after a %.3f m hip drop. STRIDE_M %.2f over DUTY %.2f asks for "
                 "%.3f m of foot excursion against a %.3f m leg — the stride is "
                 "longer than this rig can walk."
                 % (name, worst_err, drop, STRIDE_M, DUTY,
                    STRIDE_M * DUTY, reach))

        lo, hi, _part = p3._deformed_bounds(rig)
        p3._place_root(rig, rest_root,
                       Matrix.Translation(Vector((0.0, 0.0, -drop - lo.z))))
        lo2, hi2, _p2part = p3._deformed_bounds(rig)
        if abs(lo2.z) > 1e-3:
            fail("%s: re-grounding left the figure at z=%.4f" % (name, lo2.z))

        log("%s: hip drop %.3f m, worst IK error %.4f m, height %.3f m"
            % (name, drop, worst_err, hi2.z - lo2.z))
        bpy.context.view_layer.update()
        return rig.pose.bones["chest"].matrix.copy() @ chest_before.inverted()

    return dict(
        name=name,
        apply=apply,
        grip=None,
        aim=None,
        ## Wide, because the bob is now DERIVED from the stride rather than
        ## authored — pinning it to a narrow band would be pinning the
        ## consequence instead of the cause. The measured spread is reported.
        band_m=(1.70, 2.10),
        span_x_max_m=1.1,
    )


def verify_no_moonwalk():
    """THE GATE THIS FILE EXISTS FOR: the planted foot must move BACKWARD.

    Measured on the SOLVED pose, never on the authored intent — the foot path
    declares the property, the IK plus the hip drop plus the re-grounding are
    three chances to lose it, and only the result counts.

    It is not hypothetical. The first walk was authored as joint angles and the
    Director saw it immediately: the planted foot moved backward from phase 0 to
    0.25 and then FORWARD from 0.25 to 0.5, its z falling to the floor the whole
    time. That is a foot on the ground sliding forward under the body, and this
    check reports it as a number instead of as an impression."""
    log("=" * 70)
    log("moonwalk gate — the stance foot's CONTACT POINT, per phase")
    samples = []
    for i in range(PHASES):
        phase01 = float(i) / float(PHASES)
        rig = p3._open_rig()
        make_walk_posture("check%02d" % i, phase01)["apply"](rig)
        bpy.context.view_layer.update()
        row = {}
        for side in ("L", "R"):
            ## WHICH FOOT IS PLANTED COMES FROM THE PATH, NOT FROM z. The first
            ## version of this gate picked the LOWER foot, which is right for a
            ## flat foot and wrong the moment the foot rolls: at heel strike the
            ## TOE is the highest part of the planted foot, so the gate started
            ## reporting the swinging leg as planted and failed on its rise.
            _y, _z, _pitch, planted = foot_target(phase01, side, 0.0)
            pb = rig.pose.bones["foot_%s" % side]
            heel = pb.matrix.to_translation()
            toe = pb.matrix @ Vector((0.0, pb.length, 0.0))
            ## The CONTACT is whichever end is on the floor — heel early in the
            ## stance, toe late. That is the point that must not slide.
            contact = heel if heel.z <= toe.z else toe
            row[side] = (planted, contact, "heel" if heel.z <= toe.z else "toe")
        samples.append(row)

    worst = 0.0
    worst_at = ""
    for i in range(PHASES):
        nxt = (i + 1) % PHASES
        for side in ("L", "R"):
            planted, contact, part = samples[i][side]
            planted_n, contact_n, part_n = samples[nxt][side]
            if not (planted and planted_n and part == part_n):
                continue          ## swinging, or the foot rolled onto its toe
            moved = contact_n.y - contact.y
            if moved > worst:
                worst, worst_at = moved, "%s at phase %d->%d on its %s" % (
                    side, i, nxt, part)
    ## EARNED, not picked. With a rolling foot the contact transfers from heel to
    ## toe partway through the stance, and the two are 0.14 m apart on this rig;
    ## only motion of ONE contact point is compared, and the measured worst is
    ## reported below. A flat 5 mm allows for the solver's own round-off and
    ## nothing more — the defect this gate was written for measured +23 mm.
    if worst > 0.005:
        fail("the stance foot's contact point moves FORWARD by %.4f m (%s) — "
             "the figure is moonwalking." % (worst, worst_at))
    log("  PASS — no stance contact advances (worst %+.5f m%s)"
        % (worst, ", " + worst_at if worst_at else ""))


def main():
    if not os.path.isfile(p2.BLEND):
        fail("model missing: %s — run p1_agent_model.py first" % p2.BLEND)
    verify_no_moonwalk()
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
        posture = make_walk_posture("phase%02d" % i, phase01)
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
            ## `_dev`, matching p3_posture_export.py's `agent_frames_dev` rather
            ## than echoing the model's own `_devjoints` suffix — AgentSprite
            ## looks up ONE dev root per asset family, and two spellings of the
            ## same idea is how a lookup quietly misses.
            out_dir="res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
                    "agent_walk%s/phase%02d/"
                    % ("_dev" if p2._MODEL != "agent_base" else "", w["index"]),
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
