"""CHARACTER_MASTER_PLAN Part 3 — the three postures, exported for the Godot bake.

WHY THIS EXISTS, and it is a consequence rather than a new ambition: Part 2 §10
closes when `agent.gd::_draw()`'s vector placeholder is GONE. That placeholder
draws THREE shapes, one per `Posture` — standing, crouching, prone. Replacing it
with a single standing sprite would not be a swap, it would be a regression: the
agent would stand up while lying down. So the minimum viable swap needs three
posed sources, not one.

WHAT IT DELIBERATELY IS NOT: an animation. These are three static poses. The
walk cycle is a separate deliverable and is gated on the step duration (§9 #12),
which is a Director call this script does not touch.

THE GRIP IS `lowered`, NOT the `ready` the mockup was judged at. D40: the weapon
layer indexes on the GRIP, and *"idle, walk and turn are all lowered"*. The
mockup used `ready` because the grip spike was about whether a held weapon reads
at all; a figure walking around a level with a shotgun at the shoulder is a
different claim. One env var away (P3_GRIP=ready) if the Director prefers it.

--------------------------------------------------------------------------------
THREE THINGS THIS DERIVES RATHER THAN ASSERTS, each because the assertion would
have been wrong:

1. THE FIGURE IS RE-GROUNDED AFTER POSING, BY MEASUREMENT. `s2_posture_scale.py`
   sank the whole armature with a hardcoded `arm.location = (0, 0, -0.86)`, which
   is fine for a height comparison and fatal here: `agent_frame_bake_spike.gd`
   REFUSES a model whose lowest point is not on its own origin (its Y-only
   recentring assumes it), at a 0.03 m tolerance. So the posture is applied
   first, the mesh's real floor is measured through the depsgraph, and the ROOT
   BONE is translated by exactly that. Nothing is tuned; the correction is read.

2. THE ARM POSE IS CARRIED BY THE TORSO'S OWN TRANSFORM, not re-authored. The
   crouch grip is the standing grip mapped through `chest_after @
   chest_before⁻¹`, so the arms keep the relationship to the body that the
   Director judged on the grip matrix. Re-typing grip coordinates per posture
   would have been three independent guesses drifting from one ratified pose.

3. PRONE OVERRIDES THAT TRANSFORM, AND THE OVERRIDE IS EARNED. Carried through a
   -92 degree pitch, the standing `lowered` aim (0.30, 0.87, -0.39) maps to
   approximately (0.30, -0.42, -0.86): the muzzle points DOWN INTO THE FLOOR and
   backwards. That is a measured number this script prints, not an impression, and
   it is why prone declares its own grip in the prone frame. Same contract as
   p2_grip_spike.py's `by_facing`: an override exists where a derivation is
   provably wrong, and nowhere else.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/p3_posture_export.py
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p2_grip_spike as p2                                       # noqa: E402

GRIP = os.environ.get("P3_GRIP", "lowered")
WEAPON = os.environ.get("P3_WEAPON", "shotgun")

# The model variant reaches the directory name. It did not at first, and the
# DEV VISION run silently overwrote the normal run's frames AND its manifest —
# the same class of collision p2_grip_spike.py's export path had already been
# bitten by, where two exports of different models landed on one filename.
SHEET_DIR = os.path.join(p2.REPO_ROOT, "Screenshots",
                         "p3_postures" + p2._MODEL.replace("agent_base", ""))

# §4.7, as the Director stated it: standing slightly taller than a slice,
# crouched *"5 or 6 voxels"*, prone 2-3 voxels of cover. Voxels, because that is
# the unit the spec is written in; metres are derived at 0.20 m per voxel.
VOXEL_M = 0.20


def log(m):
    print("[P3-POSTURE] %s" % m)


def fail(m):
    print("[P3-POSTURE][FAIL] %s" % m)
    sys.exit(1)


def _set_euler(arm, name, xyz_deg):
    pb = arm.pose.bones.get(name)
    if pb is None:
        fail("bone %s missing from the rig" % name)
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = tuple(math.radians(v) for v in xyz_deg)


def _deformed_bounds(arm):
    """The evaluated mesh's world bounds. Evaluated, because the segments are
    skinned (vertex group + Armature modifier, p1_agent_model.py) and the rest
    geometry says nothing about where a posed limb actually is."""
    deps = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    floor_part = ""
    found = False
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.parent != arm:
            continue
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            if w.z < lo.z:
                floor_part = ob.name
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
            found = True
        ev.to_mesh_clear()
    if not found:
        fail("no skinned mesh found under the rig — cannot measure the posture")
    return lo, hi, floor_part


def _place_root(arm, rest_root, mat):
    """Set the whole figure's transform to `mat`, applied about the armature
    origin. Writing the ROOT BONE rather than the armature object is what keeps
    armature space equal to world space, which every grip target in
    p2_grip_spike.py is written in and which main() there checks for."""
    arm.pose.bones["root"].matrix = mat @ rest_root
    bpy.context.view_layer.update()


# The ship-size scale p2's export applies AFTER the pose. Every height measured
# in here is pre-scale, so the band has to be divided by it to be comparable.
SHIP_SCALE = p2.EXPORT_HEIGHT_M / 1.898


def _gate_anatomy(name, arm, lying):
    """Invariants a posed HUMAN must satisfy, checked on the solved pose.

    They exist because the first prone failed both and nothing caught it: the
    height band passed (2.87 voxels, comfortably inside 2.0–3.2) and the export
    gates passed, because a figure lying face-down and a figure face-planting
    with its feet in the air are the same HEIGHT. A band cannot see orientation.
    Measured, not judged — the numbers are printed either way."""
    def z_of(bone_name):
        return arm.pose.bones[bone_name].matrix.to_translation().z
    head = arm.pose.bones["head"]
    crown = (head.matrix @ Vector((0.0, head.length, 0.0))).z
    hips = z_of("hips")
    feet = [z_of("foot_L"), z_of("foot_R")]
    log("%s: crown %+.3f, hips %+.3f, feet %+.3f/%+.3f"
        % (name, crown, hips, feet[0], feet[1]))

    ## True of every posture: the head is the top of a person.
    if crown <= hips:
        fail("%s: the head crown (%.3f) is at or BELOW the hips (%.3f) — the "
             "figure is upside down or face-planting" % (name, crown, hips))
    ## True of every posture: you stand, crouch and lie ON your feet, so no foot
    ## may float above the hips.
    if max(feet) > hips + 0.02:
        fail("%s: a foot (%.3f) is above the hips (%.3f) — the legs are pointing "
             "the wrong way" % (name, max(feet), hips))
    ## Lying down specifically: the body is FLAT, so the feet sit at the hips'
    ## height rather than below them.
    if lying and abs(max(feet) - hips) > 0.06:
        fail("%s: lying down, but the feet (%.3f) are %.3f m off the hips "
             "(%.3f) — the body is piked, not flat"
             % (name, max(feet), abs(max(feet) - hips), hips))


def make_posture(name, bones, pitch_deg=0.0, centre_xy=False, solve_depth=False,
                 lying=False,
                 grip=None, aim=None, band_vox=(0.0, 99.0), span_x_max_m=1.4):
    """Build the `posture` dict p2_grip_spike.export_posed consumes.

    `bones` is the FULLY-FOLDED reference. With `solve_depth`, every angle in it
    is scaled by one shared factor and that factor is binary-searched until the
    measured height lands in `band_vox`. That is the opposite of tuning angles
    until the height looks right: §4.7 specifies the HEIGHT, so the height is the
    input and the angles are what gets solved. It also means a re-proportioned
    model re-solves instead of silently drifting out of spec."""
    band_m = (band_vox[0] * VOXEL_M, band_vox[1] * VOXEL_M)

    def apply(arm):
        bpy.context.view_layer.update()
        rest_root = arm.pose.bones["root"].matrix.copy()
        chest_before = arm.pose.bones["chest"].matrix.copy()
        body = Matrix.Rotation(math.radians(pitch_deg), 4, "X")

        def pose_at(k):
            """Fold to `k` of the reference, re-ground, and return the height."""
            for bone_name, xyz in bones.items():
                _set_euler(arm, bone_name, tuple(v * k for v in xyz))
            bpy.context.view_layer.update()
            _place_root(arm, rest_root, body)
            lo, hi, part = _deformed_bounds(arm)
            fix = Vector((0.0, 0.0, -lo.z))
            if centre_xy:
                # A prone figure is longer than its tile, so anchoring it on its
                # feet would hang the whole body off one side of the GU. Its own
                # bounding centre is the honest anchor, and it is also what keeps
                # the four yaw frames rotation-invariant around one anchor pixel.
                fix.x = -(lo.x + hi.x) * 0.5
                fix.y = -(lo.y + hi.y) * 0.5
            _place_root(arm, rest_root, Matrix.Translation(fix) @ body)
            lo2, hi2, part2 = _deformed_bounds(arm)
            if abs(lo2.z) > 1e-3:
                fail("%s: re-grounding left the figure at z=%.4f. Measured floor "
                     "%.4f on %s, corrected by %.4f, now floored on %s — if "
                     "those two parts differ the shift was not rigid"
                     % (name, lo2.z, lo.z, part, fix.z, part2))
            return hi2.z - lo2.z, fix, (hi2.x - lo2.x, hi2.y - lo2.y)

            # The middle of the band, which is only defensible because of a
            # measurement that WITHDREW the alternative. The first version of
            # this targeted the shallowest fold the spec allowed, on the argument
            # that reaching 5.6 voxels forced a torso fold that read as a crawl
            # rather than a crouch — and the first rendered sheet showed exactly
            # that. The cause was the reference pose, not the spec: it scaled the
            # spine, chest and neck by the same factor as the knees. Probed on
            # 2026-08-16 with the legs alone and the torso UPRIGHT, this rig
            # reaches 6.17 voxels at thigh -130 and 5.62 at thigh -150, so the
            # whole band is available without folding the torso at all. The
            # readability objection was an artifact of my own pose and does not
            # survive; the band's centre is what §4.7 actually asks for.
        if solve_depth:
            want = (band_m[0] + band_m[1]) * 0.5 / SHIP_SCALE
            h0, _, _ = pose_at(0.0)
            h1, _, _ = pose_at(1.0)
            if h1 > want:
                fail("%s: fully folded the figure still measures %.3f m "
                     "(%.2f voxels shipped), above the %.2f voxel target — the "
                     "reference pose is not deep enough to reach the spec"
                     % (name, h1, h1 * SHIP_SCALE / VOXEL_M,
                        want * SHIP_SCALE / VOXEL_M))
            lo_k, hi_k = 0.0, 1.0
            for _ in range(18):
                mid = (lo_k + hi_k) * 0.5
                h, _, _ = pose_at(mid)
                if h > want:
                    lo_k = mid
                else:
                    hi_k = mid
            k = hi_k
            log("%s: solved fold factor %.4f (unfolded %.3f m, fully folded "
                "%.3f m, target %.3f m pre-scale)" % (name, k, h0, h1, want))
        else:
            k = 1.0

        height, fix, foot = pose_at(k)
        _gate_anatomy(name, arm, lying)
        log("%s: posed height %.3f m -> ships %.3f m (%.2f voxels); "
            "footprint %.2f x %.2f m (arms still in T here — the grip is solved "
            "after this); ground correction %s"
            % (name, height, height * SHIP_SCALE,
               height * SHIP_SCALE / VOXEL_M, foot[0], foot[1],
               tuple(round(v, 3) for v in fix)))

        bpy.context.view_layer.update()
        chest_after = arm.pose.bones["chest"].matrix.copy()
        return chest_after @ chest_before.inverted()

    return dict(
        name=name,
        apply=apply,
        grip=grip,
        aim=aim,
        band_m=band_m,
        span_x_max_m=span_x_max_m,
    )


# --- The three postures. Angles are a MEANS; the measured height is the spec. --
#
# Sign conventions were read off p1_agent_model.py's armature rather than carried
# over from s2_posture_scale.py, which poses a different rig: `thigh` runs from
# the hip DOWN to the knee, `shin` from the knee down to the ankle, and `foot`
# from the ankle forward along +Y. So a positive X rotation on `thigh` swings the
# knee backwards, and the crouch below is the sign pair that folds it forwards.
POSTURES = {
    "standing": None,          # the unposed figure — p2's existing path, verbatim
    # The reference below is deliberately DEEPER than the spec — it is the k=1
    # end of the search, not the pose that ships. The solver picks k.
    #
    # THE HEIGHT COMES FROM THE KNEES; THE TORSO STAYS UP. Probed 2026-08-16:
    # the legs alone take this rig to 6.17 voxels at thigh -130 and 5.62 at
    # -150, so the whole 5.0-6.2 band is reachable with the spine, chest and
    # neck untouched. The small lean that remains is posture, not height — at a
    # deep squat, adding lean actually makes the figure TALLER (1.006 m upright
    # vs 1.074 m at a 35 degree lean, because the head arcs forward and up), so
    # it cannot be used as a depth control and is not one here.
    "crouch": make_posture(
        "crouch",
        bones={
            "thigh_L": (-158, 0, 0), "thigh_R": (-158, 0, 0),
            "shin_L": (182, 0, 0), "shin_R": (182, 0, 0),
            "foot_L": (-34, 0, 0), "foot_R": (-34, 0, 0),
            "hips": (20, 0, 0),
            "spine": (-9, 0, 0),
            "chest": (-7, 0, 0),
            "neck": (14, 0, 0),
        },
        solve_depth=True,
        band_vox=(5.0, 6.2),
        span_x_max_m=1.1,
    ),
    # ⚠️ REBUILT 2026-08-16 after the Director called it *"esquisito"*. The first
    # version was upside down in the two ways that matter, and MEASURED rather
    # than argued: at pitch -92 with those leg angles the head crown sat at
    # z=+0.102 while the hips were at +0.333 and the FEET at +0.404 — the feet
    # were the highest part of the figure and the head the lowest. On screen that
    # read as someone face-planting, not as someone lying prone.
    #
    # Every angle below was picked off a measured comparison, not adjusted by
    # eye: an exact -90 pitch puts the body axis truly horizontal, so the legs
    # need NO rotation at all to lie flat (feet and hips both land at +0.178),
    # and a POSITIVE neck/head lifts the face (head crown +0.392) where the
    # negative one buried it (+0.101). The invariants are gated below so this
    # cannot silently invert again.
    "prone": make_posture(
        "prone",
        bones={
            "neck": (30, 0, 0),
            "head": (22, 0, 0),
        },
        pitch_deg=-90.0,
        centre_xy=True,
        lying=True,
        # See note 3. The carried aim points into the floor; this one runs along
        # the body, muzzle forward and barely above the ground, which is what a
        # prone figure with a long gun actually looks like.
        grip=(-0.20, 0.10, 0.30), aim=(0.10, 0.99, 0.06),
        band_vox=(2.0, 3.2),
        span_x_max_m=1.3,
    ),
}
ORDER = ["standing", "crouch", "prone"]


# Wider than p2's 232x256 for one measured reason: the prone figure's own
# footprint is 1.85 m, which draws 214 px, and a cropped posture is exactly what
# this preview exists to catch. The SCALE is untouched — px per screen-metre is
# p2's, pinned by the game's VOXEL_STEP_PX.
PREVIEW_FRAME = (288, 288)


def _setup_preview_camera():
    """p2's camera, at p2's scale, on a wider canvas — and IDENTICAL for all
    three postures. A per-posture framing would make the sheet lie about the one
    thing it is for: how tall each posture is against the others."""
    cam = p2.setup_render()
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = PREVIEW_FRAME
    cam.data.ortho_scale = max(PREVIEW_FRAME) / p2.PX_PER_SCREEN_M
    return cam


def _render_previews(written, facing, out_dir=None):
    """Render each EXPORTED GLB, not the scene that produced it.

    `out_dir` is a parameter and not this module's SHEET_DIR because
    p3_walk_export.py calls this too, and reading the global put the walk's eight
    phase renders into the postures' folder — the third time in one session that
    two producers shared one output path. A caller that writes somewhere else
    says so.

    The distinction is the point: `export_apply` silently doing nothing, or the
    palette failing to survive the exporter (the bug that cost the mockup session
    a whole bake — p2's materialise_for_export), are both invisible to a render
    of the live scene and both obvious here."""
    dest = out_dir if out_dir is not None else SHEET_DIR
    os.makedirs(dest, exist_ok=True)
    heights = {}
    for name, path in written:
        bpy.ops.wm.read_homefile(use_empty=True)
        _setup_preview_camera()
        before = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=path)
        new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
        pivot = bpy.data.objects.new("pivot", None)
        bpy.context.collection.objects.link(pivot)
        for ob in [o for o in new if o.parent is None]:
            ob.parent = pivot
            ob.matrix_parent_inverse = Matrix.Identity(4)

        # Measured off the SHIPPED file and carried in the manifest, so that
        # nothing downstream has to transcribe it. That is not hypothetical
        # tidiness: on 2026-08-16 the crouch's height was retyped into the bake
        # command from an earlier run and the Godot bake rejected the model at
        # 1.120 m against a stated 1.220 — the gate did its job, and the gate
        # only existed because the number had been written down twice.
        pts = [o.matrix_world @ v.co for o in new if o.type == "MESH"
               for v in o.data.vertices]
        heights[name] = max(p.z for p in pts) - min(p.z for p in pts)

        for yaw in p2.YAWS:
            pivot.rotation_euler = (0.0, 0.0, math.radians(yaw))
            bpy.context.view_layer.update()
            bpy.context.scene.render.filepath = os.path.join(
                dest, "%s_%s.png" % (name, facing[yaw]))
            bpy.ops.render.render(write_still=True)
        log("%s: rendered %d facings from the exported GLB, which measures "
            "%.3f m (%.2f voxels)"
            % (name, len(p2.YAWS), heights[name], heights[name] / VOXEL_M))
    return heights


def _open_rig():
    """Reopen the .blend and return a rig verified to be at identity.

    ONE FRESH SCENE PER POSTURE, and this is a correctness requirement rather
    than hygiene. `p2_grip_spike.export_posed` had only ever run ONCE per Blender
    session (its P2_EXPORT_GLB branch returns immediately), so it leaves the
    scene dirty in two ways that only bite the second call:

    1. `scale_to_target_height` sets `arm.scale` to 1.0537 and nothing resets it,
       so on the next posture ARMATURE SPACE IS NO LONGER WORLD SPACE. Measured:
       the crouch's ground correction of -0.4063 m moved the figure -0.4281 m and
       left it 0.0218 m under the floor — exactly 0.4063 x 0.0537. Every grip
       target in p2 is written in armature space and its main() checks the rig is
       at identity ONCE, before any export, so nothing downstream would have
       caught this.
    2. `export_posed` re-imports the GLB it just wrote to verify it, and never
       removes it. The next export starts with `select_all`, so posture N's file
       would have contained postures 1..N-1 as loose geometry.

    Reopening is the fix that cannot rot: it makes each export byte-equivalent to
    a fresh single-posture run rather than depending on a cleanup list staying in
    sync with what p2 happens to create."""
    bpy.ops.wm.open_mainfile(filepath=p2.BLEND)
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        fail("AgentRig not found in %s" % p2.BLEND)
    drift = max(abs(arm.matrix_world[r][c] - (1.0 if r == c else 0.0))
                for r in range(4) for c in range(4))
    if drift > 1e-5:
        fail("AgentRig is not at identity (max element drift %.5f) — armature "
             "space would not equal world space and every grip target would be "
             "silently offset" % drift)
    return arm


def main():
    if not os.path.isfile(p2.BLEND):
        fail("model missing: %s — run p1_agent_model.py first" % p2.BLEND)

    key = (WEAPON, GRIP)
    if key not in p2.GRIPS:
        fail("P3_WEAPON/P3_GRIP = %s:%s is not one of %s"
             % (WEAPON, GRIP, ["%s:%s" % k for k in p2.ORDER]))

    # Measured once, on its own scene: which compass direction each yaw draws is
    # a property of the CAMERA convention, not of the posture.
    _open_rig()
    p2.setup_render()
    os.makedirs(SHEET_DIR, exist_ok=True)
    facing = p2.measure_facings()

    # The facing whose arm pose the export uses. p2's per-facing overrides exist
    # for the PISTOL's NE occlusion; the shotgun has none, so every facing shares
    # one pose and this picks the first grid-axis facing for determinism.
    export_facing = facing[p2.YAWS[0]]

    written = []
    for name in ORDER:
        log("=" * 70)
        log("posture: %s" % name)
        arm = _open_rig()
        out = p2.export_posed(arm, key, export_facing, posture=POSTURES[name])
        written.append((name, out))

    log("=" * 70)
    heights = _render_previews(written, facing)

    with open(os.path.join(SHEET_DIR, "manifest.json"), "w") as fh:
        json.dump(dict(
            frame=list(PREVIEW_FRAME),
            px_per_screen_m=p2.PX_PER_SCREEN_M,
            voxel_m=VOXEL_M,
            grip="%s/%s" % (WEAPON, GRIP),
            facings={str(k): v for k, v in facing.items()},
            postures=[dict(name=n,
                           glb=os.path.relpath(p, p2.REPO_ROOT).replace(os.sep, "/"),
                           ## So `AGENT_BAKE_MANIFEST` bakes all three in ONE
                           ## windowed boot, the same contract p3_walk_export.py
                           ## writes. The dev-joint variant goes to its own root
                           ## because AgentSprite loads it as a separate set.
                           out_dir="res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
                                   "agent_frames%s/%s/"
                                   % ("_dev" if p2._MODEL != "agent_base" else "", n),
                           height_m=round(heights[n], 4),
                           voxels=round(heights[n] / VOXEL_M, 2))
                      for n, p in written],
        ), fh, indent=2)

    log("=" * 70)
    log("next: python3 tools/asset_generation/p3_posture_sheet.py, then the bakes "
        "below — the heights are the MEASURED ones, so copy the lines rather than "
        "the numbers:")
    for name, out in written:
        log("  AGENT_BAKE_MODEL=res://%s \\"
            % os.path.relpath(out, p2.REPO_ROOT).replace(os.sep, "/"))
        log("  AGENT_BAKE_OUT=res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
            "agent_frames/%s/ \\" % name)
        log("  AGENT_BAKE_HEIGHT_M=%.3f" % heights[name])


if __name__ == "__main__":
    main()
