"""R3D-ACTORS (ACTOR D64) — the production rig export: a figure as ONE skinned mesh, with every motion the game plays as
a keyed ACTION, and its weapons and the grenade riding the hand bones.

Born as R3D-SPIKE-3D S2 (the walk alone); promoted at R3D-ACTORS step 1; step 2 (2026-10-01) keys the rest.

WHERE THE POSES COME FROM. Nothing is re-authored here: every pose is the one the frame bake already ships, built by the
same functions — `p3_posture_export.POSTURES` (standing / crouch / prone), `p2_grip_spike.GRIPS` (lowered / aimed per
weapon), `p3_walk_export.make_walk_posture()` (the 32-phase walk, D61) and `p3_throw_export`'s sampled left-arm phases
(raise, release; the cancel is the raise played backwards at runtime). The difference is only what is written: the bake
applies each pose to a static mesh, this KEYS it on the armature, one action per motion:

    <posture>_<weapon>_<grip>   static, two identical keys    e.g. standing_shotgun_lowered, prone_pistol_aimed
    walk_<weapon>               32 phases + the loop key       standing, lowered grip (AgentSprite walks standing only)
    throw_raise_<weapon>        RAISE_PHASES                   standing (p3_throw_export ships standing only)
    throw_release_<weapon>      RELEASE_PHASES

THE WEAPONS ARE BONE CHILDREN, NOT BAKED INTO A POSE. Each weapon is placed at its grip in a REFERENCE pose (standing,
lowered) exactly the way `p2.place_weapon()` places it for the bake, then parented to `hand_R`; the grenade is seated in
the cocked hand and parented to `hand_L`. glTF carries a node under a joint, and Godot imports it as a
`BoneAttachment3D`, so the runtime only shows the held one. Every other action then moves the weapon with the hand; how
far that lands from where `place_weapon()` would have put it is MEASURED per action and printed (the gate: 3 cm,
15 degrees), because a fixed hand offset is an approximation of the bake's per-pose placement, not a copy of it.

THE SCALE is the bake's (`p2.scale_to_target_height()`: the agent ships 2.00 m with the hat, D34's one body scale for
every variant), applied to the armature object after keying, so the keys stay in Part 1's metres.

The output sits under the git-ignored `source_assets/`, so a fresh clone has to run this once per model. The game reads
it through `ActorMesh3D` (`godot/scripts/geometry/actor_mesh3d.gd`).

Run (the agent, then the guard's model):
  /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/r3d_live_rig_export.py
  P2_MODEL=agent_base_enemy_white P2_EXPECTED_HEIGHT_M=1.920 /Applications/Blender.app/Contents/MacOS/Blender \\
    --background --python tools/asset_generation/r3d_live_rig_export.py
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
## The NORMAL model unless told otherwise: p3_posture_export defaults to the yellow-joint DEV model (the movement
## milestone's rule), and `AgentSprite.DEV_ONLY_MILESTONE` is false, so the game shows the normal one. Must be set before
## p3 is imported: it reads the variable at import time.
os.environ.setdefault("P3_DEV_ONLY", "0")
import p3_posture_export as p3                                   # noqa: E402  (order matters, see p3_walk_export)
import p2_grip_spike as p2                                       # noqa: E402
import p3_walk_export as walk                                    # noqa: E402
import p3_throw_export as throw                                  # noqa: E402

WEAPONS = ("shotgun", "pistol")
GRIPS = ("lowered", "aimed")
POSTURES = ("standing", "crouch", "prone")
REFERENCE_GRIP = "lowered"
## One phase per animation frame at 30 fps. The runtime seeks by FRACTION of an action, so the rate only sets how the
## action reads in Blender; D61's 0.56 s per GU is the runtime's (`ActorMesh3D.WALK_SPEED`).
FPS = 30
## The hand-offset gate (see the module note).
MAX_GRIP_DRIFT_M = 0.03
MAX_AIM_DRIFT_DEG = 15.0
## Roll about the barrel: `place_weapon()` keeps the weapon's +Z as upright as the aim allows; a hand-carried weapon rolls
## with the wrist.
MAX_ROLL_DEG = 25.0

FAMILY = p2._MODEL.replace("agent_base", "")
OUT = os.path.join(p2.REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models",
                   "agent", "agent_live%s.glb" % FAMILY)


def log(m):
    print("[LIVE-RIG] %s" % m)


def fail(m):
    print("[LIVE-RIG][FAIL] %s" % m)
    sys.exit(1)


def base_grip(weapon, grip):
    """The grip's BASE pose. `by_facing` overrides existed to keep a pistol visible from one fixed bake camera; a live
    mesh is seen from every yaw, so it takes the base pose every facing shares."""
    g = dict(p2.GRIPS[(weapon, grip)])
    g.pop("by_facing", None)
    return g


## weapon -> its bone-parented root, filled once the weapons are seated; `pose()` levels the held one.
SEATED = {}


def up_for(aim):
    """`p2.place_weapon()`'s up: the weapon's +Z as upright as the aim allows."""
    world_up = Vector((0.0, 0.0, 1.0))
    if abs(aim.dot(world_up)) > 0.999:
        world_up = Vector((0.0, 1.0, 0.0))
    right = aim.cross(world_up).normalized()
    return right.cross(aim).normalized()


def level_weapon(arm, root, aim):
    """Twist `hand_R` about the barrel until the carried weapon's +Z is `place_weapon()`'s up again.

    The IK fixes where the hand is and which way it points, not its roll, and the roll is what a bone-carried weapon
    inherits: measured before this existed, the prone shotgun came out rolled 128-146 degrees (upside down) and every
    aimed grip 56-69. The rotation axis is the aim line through the hand's head, and the grip point and the forend both
    lie on that line, so neither hand moves off the weapon."""
    bpy.context.view_layer.update()
    muzzle = (root.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))).normalized()
    up = (root.matrix_world.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
    up_flat = (up - muzzle * up.dot(muzzle)).normalized()
    want = up_for(muzzle)
    angle = up_flat.angle(want)
    if angle < 1e-4:
        return
    if muzzle.dot(up_flat.cross(want)) < 0.0:
        angle = -angle
    pb = arm.pose.bones["hand_R"]
    head = pb.head.copy()
    turn = Matrix.Translation(head) @ Matrix.Rotation(angle, 4, muzzle) @ Matrix.Translation(-head)
    pb.matrix = turn @ pb.matrix
    bpy.context.view_layer.update()


def pose(arm, weapon, grip, fore_m, posture=None, walk_phase=None, left_arm=None):
    """`p2.export_posed()`'s pose half, without the weapon import, the scale or the export. Returns where the right hand's
    grip point and the muzzle direction were asked to be, so the bone-parented weapon can be measured against them."""
    spec = p2.WEAPONS[weapon]
    g = base_grip(weapon, grip)
    aim = Vector(g["aim"]).normalized()
    grip_world = Vector(g["grip"])
    arm.rotation_euler = (0.0, 0.0, 0.0)
    p2.reset_pose(arm)
    shape = None
    if walk_phase is not None:
        shape = walk.make_walk_posture("walk_%.3f" % walk_phase, walk_phase)
    elif posture is not None:
        shape = p3.POSTURES[posture]
    if shape is not None:
        xform = shape["apply"](arm)
        if shape.get("grip") is None:
            grip_world = xform @ grip_world
            aim = (xform.to_3x3() @ aim).normalized()
        else:
            grip_world = Vector(shape["grip"])
            aim = Vector(shape["aim"]).normalized()
    socket_off = arm.data.bones["hand_R"].length * 0.5
    err_r, _, _ = p2.two_bone_ik(arm, "R", grip_world - aim * socket_off, g["pole_r"], aim)
    err_l = 0.0
    if spec["two_handed"] and left_arm is None:
        err_l, _, _ = p2.two_bone_ik(arm, "L", grip_world + aim * fore_m - aim * socket_off, g["pole_l"], aim)
    else:
        pose_l = left_arm if left_arm is not None else p2.IDLE_L
        for part in ("upperarm", "forearm", "hand"):
            p2.aim_bone(arm, "%s_L" % part, pose_l[part])
    if err_r > 0.02 or err_l > 0.02:
        fail("the pose did not reach its grip (R %.4f L %.4f)" % (err_r, err_l))
    bpy.context.view_layer.update()
    if weapon in SEATED:
        level_weapon(arm, SEATED[weapon], aim)
    return grip_world, aim


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        if pb.rotation_mode == "QUATERNION":
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        else:
            pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def bone_parent(obj, arm, bone):
    """Parent `obj` to a pose bone and keep it exactly where it is."""
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world
    bpy.context.view_layer.update()


class Recorder:
    """Owns the action being keyed and the drift measurements of every action."""

    def __init__(self, arm, weapons):
        self.arm = arm
        self.weapons = weapons
        self.action = None
        self.worst = {}
        self.names = []

    def begin(self, name):
        self.action = bpy.data.actions.new(name)
        self.action.use_fake_user = True
        self.arm.animation_data.action = self.action
        self.names.append(name)

    def key(self, frame, weapon, grip_world, aim):
        key_all(self.arm, frame)
        root, grip_local = self.weapons[weapon]
        landed = root.matrix_world @ grip_local
        drift = (landed - grip_world).length
        muzzle = (root.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))).normalized()
        angle = math.degrees(muzzle.angle(aim))
        want_up = up_for(aim)
        up = (root.matrix_world.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
        up_flat = (up - muzzle * up.dot(muzzle)).normalized()
        roll = math.degrees(up_flat.angle(want_up))
        name = self.action.name
        old = self.worst.get(name, (0.0, 0.0, 0.0))
        self.worst[name] = (max(old[0], drift), max(old[1], angle), max(old[2], roll))

    def end(self, last_frame):
        ## The exporter writes every action through the NLA: a stashed track per action, none left active.
        track = self.arm.animation_data.nla_tracks.new()
        track.name = self.action.name
        track.strips.new(self.action.name, 0, self.action)
        track.mute = True
        self.arm.animation_data.action = None
        log("action %-28s frames 0..%d" % (self.action.name, last_frame))


def main():
    if not os.path.isfile(p2.BLEND):
        fail("model missing: %s" % p2.BLEND)
    arm = p3._open_rig()
    bpy.context.scene.render.fps = FPS
    arm.animation_data_create()

    ## The weapons, each seated at its grip in the reference pose and handed to hand_R.
    weapons = {}
    fores = {}
    for weapon in WEAPONS:
        root, grip_local, fore_m, wscale, _created = p2.import_weapon(p2.WEAPONS[weapon])
        root.name = "Weapon_%s" % weapon
        fores[weapon] = fore_m
        grip_world, aim = pose(arm, weapon, REFERENCE_GRIP, fore_m, posture=None)
        root.parent = arm
        root.matrix_parent_inverse = Matrix.Identity(4)
        p2.place_weapon(root, grip_local, wscale, grip_world, aim)
        bone_parent(root, arm, "hand_R")
        weapons[weapon] = (root, grip_local)
        SEATED[weapon] = root
    ## The grenade, in the cocked hand (the raise's last pose) and handed to hand_L.
    grenade, _created = p2.import_grenade()
    grenade.name = "Grenade"
    pose(arm, WEAPONS[0], REFERENCE_GRIP, fores[WEAPONS[0]], left_arm=throw.KEYS_RAISE[-1][0])
    p2.seat_in_hand(grenade, arm)
    bone_parent(grenade, arm, "hand_L")

    rec = Recorder(arm, weapons)
    for weapon in WEAPONS:
        for posture in POSTURES:
            for grip in GRIPS:
                rec.begin("%s_%s_%s" % (posture, weapon, grip))
                shape = None if posture == "standing" else posture
                grip_world, aim = pose(arm, weapon, grip, fores[weapon], posture=shape)
                rec.key(0, weapon, grip_world, aim)
                rec.key(1, weapon, grip_world, aim)
                rec.end(1)
        rec.begin("walk_%s" % weapon)
        for i in range(walk.PHASES + 1):
            phase01 = float(i % walk.PHASES) / float(walk.PHASES)
            grip_world, aim = pose(arm, weapon, REFERENCE_GRIP, fores[weapon], walk_phase=phase01)
            rec.key(i, weapon, grip_world, aim)
        rec.end(walk.PHASES)
        for seq, keys, count, hold in (("raise", throw.KEYS_RAISE, throw.RAISE_PHASES, True),
                                       ("release", throw.KEYS_RELEASE, throw.RELEASE_PHASES, False)):
            rec.begin("throw_%s_%s" % (seq, weapon))
            phases = throw.phase_list(keys, count, hold_last=hold)
            for i, left in enumerate(phases):
                grip_world, aim = pose(arm, weapon, REFERENCE_GRIP, fores[weapon], left_arm=left)
                rec.key(i, weapon, grip_world, aim)
            rec.end(len(phases) - 1)

    log("=" * 70)
    log("the weapon on the hand bone against the bake's own placement, worst per action:")
    bad = []
    for name in rec.names:
        drift, angle, roll = rec.worst[name]
        ok = drift <= MAX_GRIP_DRIFT_M and angle <= MAX_AIM_DRIFT_DEG and roll <= MAX_ROLL_DEG
        flag = "" if ok else "   <-- over the gate"
        log("  %-28s grip %.3f m  aim %5.1f deg  roll %5.1f deg%s" % (name, drift, angle, roll, flag))
        if flag:
            bad.append(name)
    if bad:
        fail("%d action(s) hold the weapon too far from the bake's placement: %s" % (len(bad), ", ".join(bad)))

    ## Rest pose for the export, then the bake's ship scale on the armature object.
    p2.reset_pose(arm)
    p2.materialise_for_export()
    p2.scale_to_target_height(arm)

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "agent_body"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    log("joined %d meshes -> 1 (%d tris, %d material slots)" % (len(meshes), tris, len(body.material_slots)))

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    for root in [w[0] for w in weapons.values()] + [grenade]:
        root.select_set(True)
        for child in root.children_recursive:
            child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_skins=True, export_animations=True,
                              export_apply=False, export_yup=True,
                              export_animation_mode="ACTIONS")
    log("wrote %s (%d KB, %d actions)" % (os.path.relpath(OUT, p2.REPO_ROOT), os.path.getsize(OUT) // 1024,
                                          len(rec.names)))


if __name__ == "__main__":
    main()
