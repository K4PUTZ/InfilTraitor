# tripo_pose_grip.py — lays the two-handed pistol grip onto a pose-lab .blend (MOVEMENT, 2026-11-08; Director's references: cup and grip, arms extended, sights on the line of the eyes).
#
# The PISTOL is placed first (level, the rear sight at the height of the eyes, on the head's mid-plane) and the hands are derived from it:
#   right   the palm on the grip's right flank, thumb side up, the index on the trigger, the other three wrapped round the front strap, the thumb along the left flank;
#   left    the cup: palm up under the butt, its fingers crossing to the right and curling up over the right hand's, its thumb forward along the left flank.
# Arms: a two-bone IK that carries each bone's twist over from the pose already in the file (the hinge rule of `TripoPoseKit.solve_arm`), nearly straight.
# Working in armature space on the pose bones, so the result is an ordinary pose: the Director refines it by hand and `pose_lab.py save` reads it like any other.
#
# Run inside Blender:  blender -b --python tripo_pose_grip.py -- <in .blend> <out .blend> --idle <figure>_idle.json [--step] [--coat <map.png>] [--render <out prefix>]
import bpy, json, math, sys
from mathutils import Matrix, Quaternion, Vector

PREFIX = "mixamorig:"
CMT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))     # glTF (x, y, z) -> Blender (x, -z, y)
FORWARD = Vector((0.0, -1.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))
LEFT = Vector((1.0, 0.0, 0.0))          # the figure's left

# --- the pistol's own points, mesh-local (+X barrel, +Y down, +Z the figure's left once aimed) ---------------------------------------------------------
GUN_REAR_SIGHT = Vector((-0.0030, -0.0074, 0.0))
GUN_GRIP = Vector((-0.0008, 0.0008, 0.0))
GUN_TRIGGER = Vector((0.0032, -0.0014, 0.0))
GUN_FLANK = 0.0015

# --- the pose, in the figure's 1 m units --------------------------------------------------------------------------------------------------------------
EYE_FROM_HEAD_TOP = 0.0515              # the eyes, below the top of the head mesh
GUN_LEVEL_DOWN_DEG = 0.0                # the barrel's fall from level
ARM_STRAIGHT = 0.992                    # of the arm's full length (1.0 locks the elbow)
RIGHT_HAND_PITCH_DEG = -12.0            # the fingers' fall from the barrel
RIGHT_WRIST_BACK = 0.040                # the right wrist behind the grip's centre
RIGHT_WRIST_OUT = 0.016                 # and out from the mid-plane (the palm's thickness + the flank)
RIGHT_WRIST_UP = 0.006
LEFT_FINGERS = Vector((-0.78, -0.56, 0.16)).normalized()      # where the left hand's fingers point
LEFT_PALM = Vector((-0.12, 0.05, 1.0)).normalized()           # where its palm faces
LEFT_PALM_BELOW = 0.010                 # the palm's centre below the butt
LEFT_PALM_REACH = 0.046                 # wrist to the palm's centre, along the fingers
LEFT_PALM_SHIFT = Vector((0.000, 0.002, 0.0))

# The stance (Director, 2026-11-08): the idle sways, so the aim replaces the WHOLE body with a still base. The left foot stays, the right goes half a step back, turned out almost 90 degrees.
STEP_BACK = 0.115                       # the right foot, back
STEP_OUT = 0.012                        # and out
STEP_YAW_DEG = -74.0                    # its toes turned toward the figure's right
STEP_LIFT = 0.035                       # its height at the middle of the step (the draw stop)
HIPS_BACK = 0.040
HIPS_DOWN = 0.016
HIPS_OUT = 0.006
HIPS_YAW_DEG = -22.0                    # the pelvis follows the back foot
CHEST_YAW_BACK_DEG = 16.0               # the spine turns most of it back toward the target (over Spine, Spine1, Spine2)
LEAN_DEG = 8.0                          # the spine's lean into the gun (same three bones)
HEAD_BACK_DEG = (2.0, 3.0)              # Neck, Head: the lean taken back partly, so the head tips toward the sights but the eyes stay level
HEAD_YAW_BACK_DEG = 6.0                 # the head finishes facing the target
LEG_STRAIGHT = 0.997

# Curl (degrees, about each joint's hinge, toward the palm) of the fingers that only wrap.
CURLS = {
    "Right": {"Middle": (88, 96, 58), "Ring": (92, 98, 58), "Pinky": (96, 94, 54)},
    "Left": {"Index": (58, 72, 44), "Middle": (60, 76, 46), "Ring": (62, 78, 46), "Pinky": (64, 76, 44)},
}


def after_dashes():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(args, name):
    return args[args.index(name) + 1] if name in args else None


class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.bones = arm.pose.bones

    def b(self, name):
        return self.bones[PREFIX + name]

    def refresh(self):
        bpy.context.view_layer.update()

    def turn(self, pb, delta):
        """rotates a pose bone about its own head, by `delta` (armature space)"""
        m = pb.matrix.copy()
        head = m.translation.copy()
        r = delta @ m.to_3x3().normalized()
        new = r.to_4x4()
        new.translation = head
        pb.matrix = new
        self.refresh()

    def set_rot(self, pb, r3):
        new = r3.to_4x4()
        new.translation = pb.matrix.translation.copy()
        pb.matrix = new
        self.refresh()


def frame(a, b):
    a = a.normalized()
    b = (b - a * b.dot(a)).normalized()
    return Matrix((a, b, a.cross(b))).transposed()


def triad(a0, n0, a1, n1):
    return frame(a1, n1) @ frame(a0, n0).transposed()


def solve_arm(p, side, wrist, hand, pole):
    arm, fore, hnd = p.b(side + "Arm"), p.b(side + "ForeArm"), p.b(side + "Hand")
    s = arm.matrix.translation.copy()
    e0 = fore.matrix.translation.copy()
    w0 = hnd.matrix.translation.copy()
    l1, l2 = (e0 - s).length, (w0 - e0).length
    to = wrist - s
    limit = (l1 + l2) * ARM_STRAIGHT
    reach = min(to.length, limit)
    if to.length > limit + 0.002:
        print(f"[tripo_pose_grip] {side}: the wrist is {to.length:.3f} away, the arm gives {limit:.3f}: it stops short")
    d = to.normalized()
    w = s + d * reach
    ca = max(-1.0, min(1.0, (l1 * l1 + reach * reach - l2 * l2) / (2 * l1 * reach)))
    side_dir = (pole - d * pole.dot(d)).normalized()
    e = s + (d * ca + side_dir * math.sqrt(1 - ca * ca)) * l1
    n1 = (e - s).cross(w - e).normalized()
    n0 = (e0 - s).cross(w0 - e0).normalized()
    p.turn(arm, triad(e0 - s, n0, e - s, n1))
    e2, w2 = fore.matrix.translation.copy(), hnd.matrix.translation.copy()
    n2 = (e2 - s).cross(w2 - e2).normalized()
    p.turn(fore, triad(w2 - e2, n2, w - e, n1))
    p.set_rot(hnd, hand)
    return (hnd.matrix.translation - wrist).length


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, 'Z')


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, 'X')


def solve_leg(p, side, ankle, foot_rot, pole):
    up, low, foot = p.b(side + "UpLeg"), p.b(side + "Leg"), p.b(side + "Foot")
    s = up.matrix.translation.copy()
    k0, a0 = low.matrix.translation.copy(), foot.matrix.translation.copy()
    l1, l2 = (k0 - s).length, (a0 - k0).length
    to = ankle - s
    limit = (l1 + l2) * LEG_STRAIGHT
    reach = min(to.length, limit)
    if to.length > limit + 0.001:
        print(f"[tripo_pose_grip] {side} leg: the ankle is {to.length:.3f} away, the leg gives {limit:.3f}")
    d = to.normalized()
    a = s + d * reach
    ca = max(-1.0, min(1.0, (l1 * l1 + reach * reach - l2 * l2) / (2 * l1 * reach)))
    side_dir = (pole - d * pole.dot(d)).normalized()
    k = s + (d * ca + side_dir * math.sqrt(1 - ca * ca)) * l1
    n1 = (k - s).cross(a - k).normalized()
    n0 = (k0 - s).cross(a0 - k0).normalized()
    p.turn(up, triad(k0 - s, n0, k - s, n1))
    k2, a2 = low.matrix.translation.copy(), foot.matrix.translation.copy()
    n2 = (k2 - s).cross(a2 - k2).normalized()
    p.turn(low, triad(a2 - k2, n2, a - k, n1))
    p.set_rot(foot, foot_rot)
    return (foot.matrix.translation - ankle).length


def stance(p, t, idle_hips):
    """the whole body at `t` of the way into the stance (1 the aim, 0.5 the middle of the step)"""
    hips = p.b("Hips")
    m = hips.matrix.copy()
    m.translation = idle_hips
    hips.matrix = m
    p.refresh()
    feet = {s: (p.b(s + "Foot").matrix.translation.copy(), p.b(s + "Foot").matrix.to_3x3().normalized()) for s in ("Left", "Right")}
    m = hips.matrix.copy()
    m.translation = idle_hips + Vector((-HIPS_OUT, HIPS_BACK, -HIPS_DOWN)) * t
    hips.matrix = m
    p.refresh()
    p.turn(hips, rz(HIPS_YAW_DEG * t))
    for n in ("Spine", "Spine1", "Spine2"):
        p.turn(p.b(n), rz(CHEST_YAW_BACK_DEG * t / 3.0) @ rx(LEAN_DEG * t / 3.0))
    p.turn(p.b("Neck"), rx(-HEAD_BACK_DEG[0] * t))
    p.turn(p.b("Head"), rz(HEAD_YAW_BACK_DEG * t) @ rx(-HEAD_BACK_DEG[1] * t))
    left = solve_leg(p, "Left", feet["Left"][0], feet["Left"][1], Vector((0.15, -1.0, 0.0)))
    lift = STEP_LIFT * math.sin(math.pi * t) if t < 1.0 else 0.0
    ankle = feet["Right"][0] + Vector((-STEP_OUT * t, STEP_BACK * t, lift))
    right = solve_leg(p, "Right", ankle, rz(STEP_YAW_DEG * t) @ feet["Right"][1], Vector((-0.75, -0.65, 0.0)))
    print(f"[tripo_pose_grip] stance at {t}: ankle misses left {left:.4f}, right {right:.4f}")


def curl(p, side, finger, angles, palm_dir):
    for i, deg in enumerate(angles):
        pb = p.b(f"{side}Hand{finger}{i + 1}")
        if i == 0:
            sign = 1.0 if pb.z_axis.dot(palm_dir) > 0 else -1.0
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), math.radians(deg) * sign)
    p.refresh()


def reach_tip(p, chain, tip, target, turns=10):
    """cyclic coordinate descent, shortest arcs: the tip of a finger onto a point"""
    bones = [p.b(n) for n in chain]
    end = p.b(tip)
    for _ in range(turns):
        for pb in reversed(bones):
            h = pb.matrix.translation
            a = end.matrix.translation - h
            b = target - h
            if a.length < 1e-6 or b.length < 1e-6:
                continue
            p.turn(pb, a.rotation_difference(b).to_matrix())
    return (end.matrix.translation - target).length


def swap_coat(path, figure):
    name = f"{figure}_coat_light"
    img = bpy.data.images.get(name)
    if img is None:
        print(f"[tripo_pose_grip] ERROR: no image {name}")
        sys.exit(1)
    new = bpy.data.images.load(path)
    if tuple(new.size) != tuple(img.size):
        print(f"[tripo_pose_grip] ERROR: sizes differ {tuple(new.size)} vs {tuple(img.size)}")
        sys.exit(1)
    img.pixels.foreach_set(list(new.pixels))
    img.update()
    img.pack()
    bpy.data.images.remove(new)
    print(f"[tripo_pose_grip] coat map replaced from {path}")


def begin():
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object.mode != 'POSE':
        bpy.ops.object.mode_set(mode='POSE')
    p = Poser(arm)
    p.refresh()
    return arm, p


def pose_it(arm, p):
    head = bpy.data.objects["Body_Head"]
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = head.evaluated_get(dg).to_mesh()
    pts = [head.matrix_world @ v.co for v in mesh.vertices]
    head_top = max(q.z for q in pts)
    mid_x = (min(q.x for q in pts) + max(q.x for q in pts)) * 0.5
    head.evaluated_get(dg).to_mesh_clear()
    eye_z = head_top - EYE_FROM_HEAD_TOP

    # The pistol: level, its rear sight on the eye line; how far ahead is what the arm's length leaves.
    gun_obj = bpy.data.objects["PROP_pistol"]
    s = gun_obj.matrix_world.to_3x3().col[0].length
    fall = math.radians(GUN_LEVEL_DOWN_DEG)
    gx = (FORWARD * math.cos(fall) - UP * math.sin(fall)).normalized()
    gy = (-UP - gx * (-UP).dot(gx)).normalized()
    gz = gx.cross(gy)
    g3 = Matrix((gx, gy, gz)).transposed()
    right_shoulder = p.b("RightArm").matrix.translation.copy()
    l = (p.b("RightForeArm").matrix.translation - right_shoulder).length + (p.b("RightHand").matrix.translation - p.b("RightForeArm").matrix.translation).length
    reach = l * ARM_STRAIGHT
    sight_to_grip = g3 @ ((GUN_GRIP - GUN_REAR_SIGHT) * s)
    wrist_from_grip = FORWARD * -RIGHT_WRIST_BACK - LEFT * RIGHT_WRIST_OUT + UP * RIGHT_WRIST_UP
    sight0 = Vector((mid_x, 0.0, eye_z))
    w = sight0 + sight_to_grip + wrist_from_grip
    dx, dz = w.x - right_shoulder.x, w.z - right_shoulder.z
    w.y = right_shoulder.y - math.sqrt(max(1e-6, reach * reach - dx * dx - dz * dz))
    grip = w - wrist_from_grip
    sight = grip - sight_to_grip
    origin = sight - g3 @ (GUN_REAR_SIGHT * s)

    def on_gun(point):
        return origin + g3 @ (point * s)

    # The right hand.
    pitch = math.radians(RIGHT_HAND_PITCH_DEG)
    r_y = (FORWARD * math.cos(pitch) + UP * math.sin(pitch)).normalized()
    r_z = LEFT.copy()
    r_x = r_y.cross(r_z).normalized()
    r_hand = Matrix((r_x, r_y, r_x.cross(r_y))).transposed()
    miss_r = solve_arm(p, "Right", w, r_hand, Vector((-0.45, 0.1, -1.0)))

    # The left hand: palm under the butt.
    l_y = LEFT_FINGERS
    l_palm = (LEFT_PALM - l_y * LEFT_PALM.dot(l_y)).normalized()
    l_z = -l_palm                          # the left hand's +Z is its BACK
    l_x = l_y.cross(l_z).normalized()
    l_hand = Matrix((l_x, l_y, l_x.cross(l_y))).transposed()
    butt = on_gun(Vector((GUN_GRIP.x, 0.0041, 0.0)))
    palm = butt - UP * LEFT_PALM_BELOW + LEFT_PALM_SHIFT
    l_wrist = palm - l_y * LEFT_PALM_REACH
    miss_l = solve_arm(p, "Left", l_wrist, l_hand, Vector((0.55, 0.1, -1.0)))

    # The fingers.
    for side, fingers in CURLS.items():
        pd = r_z if side == "Right" else l_palm
        for finger, angles in fingers.items():
            curl(p, side, finger, angles, pd)
    flank = GUN_FLANK * s
    curl(p, "Right", "Index", (10, 28, 24), r_z)
    miss_i = reach_tip(p, ["RightHandIndex1", "RightHandIndex2", "RightHandIndex3"], "RightHandIndex4", on_gun(GUN_TRIGGER))
    thumb_r = on_gun(Vector((0.0040, -0.0016, 0.0))) + LEFT * (flank + 0.004)
    miss_t = reach_tip(p, ["RightHandThumb1", "RightHandThumb2", "RightHandThumb3"], "RightHandThumb4", thumb_r)
    thumb_l = on_gun(Vector((0.0024, 0.0006, 0.0))) + LEFT * (flank + 0.010)
    miss_tl = reach_tip(p, ["LeftHandThumb1", "LeftHandThumb2", "LeftHandThumb3"], "LeftHandThumb4", thumb_l)

    gun = (g3 @ Matrix.Diagonal((s, s, s))).to_4x4()
    gun.translation = origin
    gun_obj.matrix_world = arm.matrix_world @ gun
    p.refresh()
    print(f"[tripo_pose_grip] eye height {eye_z:.4f}, rear sight at {sight.to_tuple(4)}; misses: right wrist {miss_r:.4f}, left wrist {miss_l:.4f}, trigger {miss_i:.4f}, right thumb {miss_t:.4f}, left thumb {miss_tl:.4f}")
    return arm, grip


def render(prefix, grip):
    scn = bpy.context.scene
    scn.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items.keys() else 'BLENDER_EEVEE_NEXT'
    scn.render.resolution_x, scn.render.resolution_y = 760, 760
    world = scn.world or bpy.data.worlds.new("w")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.56, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(-40))
    scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 85
    cam.data.clip_start = 0.01
    scn.collection.objects.link(cam)
    scn.camera = cam
    centre = Vector((0.0, -0.06, 0.5))
    shots = [("hands_right", grip, 90.0 + 180.0, 6.0, 0.42), ("hands_left", grip, 90.0, 6.0, 0.42), ("hands_below", grip, 25.0, -38.0, 0.42),
             ("body_side", centre, 270.0, 6.0, 3.2), ("body_front", centre, 20.0, 8.0, 3.2), ("feet_top", Vector((0.0, 0.05, 0.03)), 0.0, 88.0, 1.1)]
    for name, target, az, el, dist in shots:
        a, e = math.radians(az), math.radians(el)
        cam.location = target + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        scn.render.filepath = f"{prefix}_{name}.png"
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


def main():
    a = after_dashes()
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm, p = begin()
    figure = arm["lab_figure"]
    idle = json.load(open(opt(a, "--idle")))
    idle_hips = CMT @ Vector(idle["hips_pos"])
    stance(p, 0.5 if "--step" in a else 1.0, idle_hips)
    arm["lab_whole_body"] = True
    arm["lab_bones"] = json.dumps(sorted(b.name[len(PREFIX):] for b in arm.data.bones))
    grip = p.b("RightHand").matrix.translation.copy() if "--step" in a else pose_it(arm, p)[1]
    if opt(a, "--coat"):
        swap_coat(opt(a, "--coat"), arm["lab_figure"])
    bpy.ops.wm.save_as_mainfile(filepath=a[1])
    if opt(a, "--render"):
        render(opt(a, "--render"), grip)
    print(f"[tripo_pose_grip] wrote {a[1]}")


main()
