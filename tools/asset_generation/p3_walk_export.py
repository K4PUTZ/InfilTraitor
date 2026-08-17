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

## Fraction of the cycle each foot spends PLANTED. Real walking is 0.60–0.62; a
## run is under 0.50 by definition (both feet leave the ground). 0.60 also means
## the two stance phases overlap by 0.20, which is the double-support a walk must
## have and a run must not.
DUTY = 0.60
## Peak toe clearance during the swing.
SWING_LIFT_M = 0.075
## The arms counter-swing. Degrees, and the only part of this file still authored
## as an angle — the arms are overwritten by the weapon IK anyway (D40).
ARM_DEG = 18.0

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
        return half - 2.0 * half * t, ankle_z
    t = (ph - DUTY) / (1.0 - DUTY)
    return -half + 2.0 * half * t, ankle_z + SWING_LIFT_M * math.sin(math.pi * t)


def arm_bones(phase01):
    """The counter-swing. The LEFT arm goes with the RIGHT leg."""
    out = {}
    for side, offset in (("L", 0.0), ("R", 0.5)):
        swing = math.sin(2.0 * math.pi * (phase01 + offset))
        out["upperarm_%s" % side] = (-ARM_DEG * swing, 0.0, 0.0)
    return out


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

        for bone_name, xyz in arm_bones(phase01).items():
            p3._set_euler(rig, bone_name, xyz)
        bpy.context.view_layer.update()

        ## Read off the rig, never from module constants — a re-proportioned
        ## model must re-solve rather than silently drift.
        ankle_z = rig.data.bones["foot_L"].head_local.z
        reach = rig.data.bones["thigh_L"].length + rig.data.bones["shin_L"].length
        hip_x = {s: rig.data.bones["thigh_%s" % s].head_local.x for s in ("L", "R")}

        targets = []
        for side in ("L", "R"):
            y, z = foot_target(phase01, side, ankle_z)
            targets.append(Vector((hip_x[side], y, z)))

        drop = solve_hip_drop(rig, targets, reach)
        p3._place_root(rig, rest_root, Matrix.Translation(Vector((0.0, 0.0, -drop))))

        worst_err = 0.0
        for side, target in zip(("L", "R"), targets):
            _, z = foot_target(phase01, side, ankle_z)
            planted = z <= ankle_z + 1e-6
            ## Knees bend FORWARD, so the pole is forward. The foot points along
            ## the travel direction, toe slightly down when planted and up
            ## through the swing — which is what a heel strike looks like.
            foot_dir = (0.0, 1.0, -0.18) if planted else (0.0, 1.0, 0.30)
            err, _clamped, _k = p2.two_bone_ik(
                rig, side, target, (0.0, 1.0, -0.25), foot_dir,
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
    rig = p3._open_rig()
    log("=" * 70)
    log("moonwalk gate — the planted foot's travel, per phase")
    samples = []
    for i in range(PHASES):
        phase01 = float(i) / float(PHASES)
        rig = p3._open_rig()
        make_walk_posture("check%02d" % i, phase01)["apply"](rig)
        bpy.context.view_layer.update()
        feet = {}
        for side in ("L", "R"):
            pb = rig.pose.bones["foot_%s" % side]
            feet[side] = pb.matrix @ Vector((0.0, pb.length, 0.0))   ## the toe
        planted = "L" if feet["L"].z < feet["R"].z else "R"
        samples.append((i, planted, feet[planted].y, feet[planted].z))

    worst = 0.0
    for k in range(len(samples)):
        i, side, y, z = samples[k]
        j, side_n, y_n, _z = samples[(k + 1) % len(samples)]
        moved = "" if side_n != side else "%+.4f" % (y_n - y)
        if side_n == side and y_n - y > 1e-4:
            worst = max(worst, y_n - y)
        log("  phase %d: planted %s at y=%+.3f z=%+.3f  -> next %s" % (
            i, side, y, z, moved if moved else "(swaps to %s)" % side_n))
    if worst > 0.005:
        fail("the planted foot moves FORWARD by up to %.4f m — the figure is "
             "moonwalking. The foot path or the solve lost the stance "
             "constraint." % worst)
    log("  PASS — the planted foot never advances (worst %+.5f m)" % worst)


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
