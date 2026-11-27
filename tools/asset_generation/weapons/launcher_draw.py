"""launcher_draw.py — a grenade launcher's DRAW from beside the waist (2026-11-27; MOVEMENT §11.6, the H3 launchers).

The Director: "Grenade launchers não cabem na lapela, então o draw vai ser diferente: a mão esquerda afasta levemente a parte de baixo da
saia esquerda para fora, proximo da coxa, abrindo um espaço ao lado da cintura. A mão direita mergulha para baixo e pra esquerda, até chegar
próxima ao bolso esquerdo da frente. A arma se manifesta nessa posição, apontada pra baixo e a mão direita segurando no cabo/gatilho levanta e
apruma o launcher até a posição do hip, enquanto a mão esquerda soltou a saia e segue pra apoiar a parte da frente no hip. Pra guardar volta
ao contrário." No aimed stage: the timeline ENDS at the hip (the game reads only the `hip` marker, `AimSequence.marker_weight`).

INPUT: a launcher timeline whose `hip` stop is the hold (`HIP_cand_<nn>.blend`: `family_lab.py seq` on the shotgun timeline, then
`long_gun_pose.py hip` and, for a vertical fore-grip, `pump_grip ... foregrip`). Everything between the idle (frame 1) and the hip is
REBUILT, everything after the hip dropped (no aim):

  stop    what (frame)
  idle    1, as it was
  skirt   the left hand at the lower edge of the coat's left skirt, beside the thigh; the right hand starts to cross
  open    the left hand has pushed the skirt OUT (a gap beside the waist); the right hand has dived down and left, by the left front pocket
  appear  the launcher shows there, in the right hand on its grip, pointing DOWN (the gun is hidden before)
  lift    the right hand raises and turns it; the left hand has let the skirt go and comes forward
  join    the gun nearly level, the left hand just under its front
  hip     the hold, as it was

Each stop: the trunk at an eased share of the way from the idle to the hip (with a lean down and left while the right hand reaches the
pocket); the arms solved to targets (`family_lab._reach`, the elbow's plane kept); the right hand's fingers the hip's from `appear`.
Targets are in the FIGURE's frame measured from its own bones (the hip joint, the hip height H), so the same numbers serve both figures.
The gun RIDES THE RIGHTHAND bone (as the pistol: the left hand opens the coat), at its hip grip from `appear` on, so it never swims.
Coat: the inherited lapel-draw keys (`DrawFix_*`, `LongDrawFix_*`) go, an EMPTY `LauncherDrawFix_f<NN>` is made at each stop for the
Director to sculpt the skirt (`docs/pipelines/timeline_coat_keys.md`).

  blender -b --python launcher_draw.py -- build <HIP timeline .blend> <out .blend> [stops: skirt,open,appear,lift,join frames; 5,9,11,15,19]
"""
import bpy, sys, os, math, json
from mathutils import Matrix, Vector, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import family_lab as FL
import long_gun_pose as LGP

P = FL.PREFIX
FINGERS = LGP.FINGERS
TRUNK = ("Spine", "Spine1", "Spine2")

# Targets in units of the hip height H, in the figure's frame: fwd (the way it faces), left, up; from the LEFT hip joint (LeftUpLeg's head).
# The Director's sketch (2026-11-27, after the first candidate: "os braços ficaram todos tortos ... a ideia é mais simples"): the LEFT hand
# takes the coat's FRONT edge at the thigh and draws it out to the side, opening the front; the RIGHT hand crosses to the FRONT of the left
# thigh, where the coat was, and the gun starts there pointing down, in the room there is, as if drawn from under the coat. Both hands keep
# the idle's turn (the first candidate's turned wrists bent the arms); the targets sit high on the thigh, since the Agent's arms are short
# (measured: the front of the thigh 0.10 H below the hip joint is 109-115 % of the right arm); the gun is turned about its own barrel so the right hand needs the
# least turn from its idle.
SKIRT_AT = (0.11, 0.07, -0.06)     # the left hand at the coat's front edge, over the left thigh
OPEN_AT = (0.07, 0.19, -0.05)      # the edge drawn out to the side
POCKET_AT = (0.15, 0.02, -0.02)    # the right hand's palm in front of the left thigh
LEAN_DEG = (6.0, 0.0)              # a slight bow while the right hand reaches (no side lean: the first candidate's 6 deg went with the twisted arms)
ARC_FWD, ARC_UP = 0.80, 0.30      # the lift's curve: its control point ahead of and above the middle of pocket -> hip (units of H)
REACH_CAP = 0.95                   # a hand target is taken no further than this share of the arm
LEVEL_EARLY = 1.0                  # the turn to level against the carry (t ** this; 1.0 measured best, 2026-11-27: 0-17 cut triangles a frame from 13 to 21)
TRUNK_SHARE = {"skirt": 0.0, "open": 0.05, "appear": 0.1, "lift": 0.5, "join": 0.85}


def fail(msg):
    print(f"[launcher_draw] ERROR: {msg}")
    sys.exit(1)


def _frame(arm):
    """The figure's frame in WORLD space: (fwd, left, up) unit vectors, the left hip joint, the hip height H."""
    pb = arm.pose.bones
    mw = arm.matrix_world
    hips = mw @ pb[P + "Hips"].head
    lhip, rhip = mw @ pb[P + "LeftUpLeg"].head, mw @ pb[P + "RightUpLeg"].head
    up = Vector((0.0, 0.0, 1.0))
    left = (lhip - rhip)
    left.z = 0.0
    left.normalize()
    fwd = up.cross(left).normalized() * -1.0         # left x up = back, so fwd = up x left reversed... checked below against the toes
    toe = mw @ pb[P + "LeftToeBase"].head if (P + "LeftToeBase") in pb else None
    if toe is not None and (toe - lhip).dot(fwd) < 0.0:
        fwd = -fwd
    floor = min((mw @ pb[P + s + "Foot"].head).z for s in ("Left", "Right"))
    return fwd, left, up, lhip, hips.z - floor


def _at(fr, off):
    fwd, left, up, lhip, H = fr
    return lhip + fwd * (off[0] * H) + left * (off[1] * H) + up * (off[2] * H)


def _drop(fc, pred):
    """Remove the keyframes whose frame `pred` accepts (by index, last first: a removed point invalidates the others' references)."""
    for i in range(len(fc.keyframe_points) - 1, -1, -1):
        if pred(round(fc.keyframe_points[i].co[0])):
            fc.keyframe_points.remove(fc.keyframe_points[i])


def _slerp_pose(arm, a, b, t, names):
    for n in names:
        qa, qb = a[n], b[n]
        if qa.dot(qb) < 0.0:
            qb = -qb
        arm.pose.bones[n].rotation_quaternion = qa.slerp(qb, t)


def build(src, out, stops=(5, 9, 11, 15, 19)):
    if os.path.exists(out) or os.path.realpath(out) == os.path.realpath(src):
        fail(f"{out} exists or is the input: a timeline is never written over")
    sc, arm, gun = LGP._open(src)
    markers = {m.name: m.frame for m in sc.timeline_markers}
    if "hip" not in markers or "idle" not in markers:
        fail("the timeline needs its idle and hip markers")
    f_idle, f_hip = markers["idle"], markers["hip"]
    names_st = ("skirt", "open", "appear", "lift", "join")
    S = dict(zip(names_st, stops))
    if not (f_idle < S["skirt"] < S["open"] < S["appear"] < S["lift"] < S["join"] < f_hip):
        fail(f"stops {S} must lie in order between the idle {f_idle} and the hip {f_hip}")
    pb = arm.pose.bones
    names = [b.name for b in pb]
    mw = arm.matrix_world
    to_a = mw.inverted()

    def pose_at(f):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        return {n: pb[n].rotation_quaternion.copy() for n in names}, pb[P + "Hips"].location.copy()

    idle, hips_idle = pose_at(f_idle)
    hip, hips_hip = pose_at(f_hip)
    G_hip = gun.matrix_world.copy()
    RH_hip = mw @ pb[P + "RightHand"].matrix
    LH_hip = mw @ pb[P + "LeftHand"].matrix
    grip_r = RH_hip.inverted() @ G_hip                     # the gun in the right hand at the hip: kept from `appear` on
    left_on = G_hip.inverted() @ LH_hip                    # the left hand against the gun at the hip
    sc.frame_set(f_idle)
    bpy.context.view_layer.update()
    fr = _frame(arm)
    fwd, left, up, lhip, H = fr
    print(f"[launcher_draw] {os.path.basename(src)}: idle {f_idle}, hip {f_hip}, H {H:.3f}; stops {S}")

    # drop every key after the idle (the scaffold's lapel draw, the aim) except the hip's; the hip becomes the end
    ad = arm.animation_data
    for fc in FL._curves(ad):
        _drop(fc, lambda f: f_idle < f != f_hip)
    for fc in FL._curves(gun.animation_data):
        _drop(fc, lambda f: f > f_hip)
    for m in [m for m in sc.timeline_markers if m.name not in ("idle", "hip")]:
        sc.timeline_markers.remove(m)
    sc.frame_end = f_hip

    fingers_r = [n for n in names if n.startswith(P + "RightHand") and any(x in n for x in FINGERS)]
    arms_b = [P + n for n in LGP.ARMS]
    trunk_b = [P + n for n in TRUNK]

    # the gun's world place at appear / lift / join: pointing DOWN by the pocket, eased up to the hip's along an arc
    sc.frame_set(f_hip)
    bpy.context.view_layer.update()
    q_hip = G_hip.to_quaternion()
    scale_g = G_hip.to_scale()
    # the model's barrel axis in its own coordinates is not +X: measure it from the hip, where the barrel lies along the figure's fwd
    gx = G_hip.to_3x3().normalized()
    axes = [gx @ Vector(v) for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1))]
    barrel_local = [Vector(v) for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1))][max(range(6), key=lambda i: axes[i].dot(fwd))]
    barrel_w = gx @ barrel_local
    down_dir = (-up + fwd * 0.25).normalized()                     # barrel down, a little forward
    q_down0 = barrel_w.rotation_difference(down_dir) @ q_hip
    sc.frame_set(f_idle)
    bpy.context.view_layer.update()
    rh_idle_q = (mw @ pb[P + "RightHand"].matrix).to_quaternion()
    lh_idle_q = (mw @ pb[P + "LeftHand"].matrix).to_quaternion()
    q_grip = grip_r.to_quaternion()
    yaw = min(range(0, 360, 5), key=lambda d: ((Quaternion(down_dir, math.radians(d)) @ q_down0) @ q_grip.inverted()).rotation_difference(rh_idle_q).angle)
    q_down = Quaternion(down_dir, math.radians(yaw)) @ q_down0
    print(f"[launcher_draw] the gun turned {yaw} deg about its barrel at `appear`: the right hand "
          f"{math.degrees((q_down @ q_grip.inverted()).rotation_difference(rh_idle_q).angle):.0f} deg from its idle turn")
    sc.frame_set(f_hip)
    bpy.context.view_layer.update()
    palm_r_in_hand = pb[P + "RightHand"].matrix.inverted() @ ((pb[P + "RightHand"].head + pb[P + "RightHandMiddle1"].head) * 0.5)
    pocket = _at(fr, POCKET_AT)
    R_down = q_down.to_matrix().to_4x4()
    # the gun placed so the right PALM lands on the pocket point (a gun at the origin first, then moved by what is left)
    Gtmp = R_down @ Matrix.Diagonal(scale_g.to_4d())
    palm_tmp = (Gtmp @ grip_r.inverted()) @ palm_r_in_hand
    G_app = Matrix.Translation(pocket - palm_tmp) @ Gtmp

    def gun_at(t):
        """The gun between appear (0) and the hip (1). Measured on the first candidate: a straight path from the left side to the right
        hip runs the gun through the coat, the belt and the trousers. So it goes along a quadratic curve whose control point is AHEAD of
        both ends (`ARC_FWD`, `ARC_UP`): first forward, away from the body, then across to the hip; and it levels out early (the turn
        runs on t ** `LEVEL_EARLY`), so the barrel is not still pointing down while it crosses the legs."""
        e = FL._ease(t)
        q = q_down.slerp(q_hip if q_down.dot(q_hip) >= 0 else -q_hip, FL._ease(t ** LEVEL_EARLY))
        p0, p1 = G_app.to_translation(), G_hip.to_translation()
        c = (p0 + p1) * 0.5 + fwd * (ARC_FWD * H) + up * (ARC_UP * H)
        p = p0 * (1 - e) ** 2 + c * (2 * e * (1 - e)) + p1 * e ** 2
        return Matrix.Translation(p) @ q.to_matrix().to_4x4() @ Matrix.Diagonal(scale_g.to_4d())

    t_of = {"appear": 0.0, "lift": (S["lift"] - S["appear"]) / (f_hip - S["appear"]), "join": (S["join"] - S["appear"]) / (f_hip - S["appear"])}

    def key_pose(f, base_t, lean, lh_w, rh_w, fingers_from_hip):
        sc.frame_set(f)
        _slerp_pose(arm, idle, hip, base_t, names)
        pb[P + "Hips"].location = hips_idle.lerp(hips_hip, base_t)
        if lean:
            fw, sd = lean
            axis_side = (to_a.to_3x3() @ fwd).normalized()      # a lean to the left turns about the forward axis
            axis_fwd = (to_a.to_3x3() @ left).normalized()      # a bow forward turns about the left axis
            for n in trunk_b:
                b = pb[n]
                rot = Quaternion(axis_fwd, math.radians(fw / 3.0)) @ Quaternion(axis_side, math.radians(-sd / 3.0))
                M = b.matrix.copy()
                b.matrix = Matrix.Translation(M.to_translation()) @ (rot.to_matrix().to_4x4() @ M.to_3x3().to_4x4())
                bpy.context.view_layer.update()
        bpy.context.view_layer.update()
        miss = {}
        for side, W in (("Left", lh_w), ("Right", rh_w)):
            if W is not None:
                m, share = FL._reach(arm, side, to_a @ W)
                miss[side] = f"{m:.2f} cm at {share * 100:.0f} %"
        if fingers_from_hip:
            for n in fingers_r:
                pb[n].rotation_quaternion = hip[n]
        bpy.context.view_layer.update()
        for b in pb:
            prev = idle[b.name]
            if b.rotation_quaternion.dot(prev) < 0.0:
                b.rotation_quaternion = -b.rotation_quaternion
            b.keyframe_insert("rotation_quaternion", frame=f)
        pb[P + "Hips"].keyframe_insert("location", frame=f)
        print(f"[launcher_draw] {f}: trunk {base_t:.2f}, lean {lean or '-'}; {miss}")

    def hand_at(point, palm_side, turn_q):
        """A hand bone matrix (world) whose palm centre lands on `point`, turned `turn_q` (world)."""
        hb = pb[P + palm_side + "Hand"]
        pin = hb.matrix.inverted() @ ((hb.head + pb[P + palm_side + "HandMiddle1"].head) * 0.5)
        R_a = mw.to_quaternion().inverted() @ turn_q                     # the turn in armature space
        t_a = (to_a @ point) - (R_a.to_matrix() @ pin)
        return mw @ (Matrix.Translation(t_a) @ R_a.to_matrix().to_4x4())

    q_skirt = lh_idle_q
    sc.frame_set(f_idle)
    bpy.context.view_layer.update()
    rh_idle = mw @ pb[P + "RightHand"].matrix
    rh_cross = Matrix.Translation(rh_idle.to_translation().lerp(pocket, 0.35)) @ rh_idle.to_quaternion().to_matrix().to_4x4()

    key_pose(S["skirt"], TRUNK_SHARE["skirt"], None, hand_at(_at(fr, SKIRT_AT), "Left", q_skirt), rh_cross, False)
    RH_app = G_app @ grip_r.inverted()
    key_pose(S["open"], TRUNK_SHARE["open"], LEAN_DEG, hand_at(_at(fr, OPEN_AT), "Left", q_skirt),
             Matrix.Translation(RH_app.to_translation() + up * 0.03 * H) @ RH_app.to_quaternion().to_matrix().to_4x4(), True)
    key_pose(S["appear"], TRUNK_SHARE["appear"], LEAN_DEG, hand_at(_at(fr, OPEN_AT), "Left", q_skirt), RH_app, True)
    G_l, G_j = gun_at(t_of["lift"]), gun_at(t_of["join"])
    LH_join = G_j @ left_on
    LH_join = Matrix.Translation(LH_join.to_translation() - up * 0.05 * H) @ LH_join.to_quaternion().to_matrix().to_4x4()
    lh_lift_p = _at(fr, OPEN_AT).lerp(LH_join.to_translation(), 0.45) - left * 0.03 * H
    key_pose(S["lift"], TRUNK_SHARE["lift"], None,
             Matrix.Translation(lh_lift_p) @ q_skirt.slerp(LH_join.to_quaternion(), 0.5).to_matrix().to_4x4(), G_l @ grip_r.inverted(), True)
    # the left hand at `join`: toward its place under the gun's front as far as the arm reaches (`REACH_CAP`); it settles on the gun at the hip
    sc.frame_set(S["join"])
    _slerp_pose(arm, idle, hip, TRUNK_SHARE["join"], names)
    bpy.context.view_layer.update()
    sh = mw @ pb[P + "LeftArm"].head
    L_arm = (pb[P + "LeftArm"].bone.length + pb[P + "LeftForeArm"].bone.length) * mw.to_scale().x
    w = 1.0
    while w > 0.0 and (lh_lift_p.lerp(LH_join.to_translation(), w) - sh).length > REACH_CAP * L_arm:
        w -= 0.05
    LH_j = Matrix.Translation(lh_lift_p.lerp(LH_join.to_translation(), max(w, 0.0))) @ \
        q_skirt.slerp(LH_join.to_quaternion(), 0.5 + 0.5 * max(w, 0.0)).to_matrix().to_4x4()
    print(f"[launcher_draw] {S['join']}: the left hand {max(w, 0.0) * 100:.0f} % of the way to the gun's front (arm capped at {REACH_CAP * 100:.0f} %)")
    key_pose(S["join"], TRUNK_SHARE["join"], None, LH_j, G_j @ grip_r.inverted(), True)

    # the gun: hidden to `appear`, then keyed at every frame where the right hand holds it
    for path in ("hide_viewport", "hide_render"):
        if gun.animation_data and gun.animation_data.action:
            for fc in [fc for fc in FL._curves(gun.animation_data) if fc.data_path == path]:
                _drop(fc, lambda f: True)
    for fc in FL._curves(gun.animation_data):
        _drop(fc, lambda f: f_idle <= f < f_hip)
    gun.hide_viewport = gun.hide_render = True
    for path in ("hide_viewport", "hide_render"):
        gun.keyframe_insert(path, frame=f_idle)
        gun.keyframe_insert(path, frame=S["appear"] - 1)
    # the RIGHT hand carries the gun (Director 2026-11-27: "assim como nas pistolas, é a mão esquerda que levanta o casaco"): the prop rides
    # the RightHand bone at its hip grip, one constant placement from `appear` on; the left hand only helps (the lapel draws' long guns keep
    # the LeftHand). The read-back takes the bone from `lab_bone`, as for the pistol.
    sc.frame_set(f_hip)
    bpy.context.view_layer.update()
    for fc in [fc for fc in FL._curves(gun.animation_data) if fc.data_path in ("location", "rotation_quaternion", "rotation_euler", "scale")]:
        _drop(fc, lambda f: True)
    gun.parent_bone = P + "RightHand"
    gun.matrix_parent_inverse = Matrix.Identity(4)
    gun["lab_bone"] = "RightHand"
    bpy.context.view_layer.update()
    gun.matrix_world = G_hip
    bpy.context.view_layer.update()
    for f in (S["appear"], f_hip):
        gun.hide_viewport = gun.hide_render = False
        for path in ("location", "rotation_quaternion", "scale", "hide_viewport", "hide_render"):
            gun.keyframe_insert(path, frame=f)
    for fc in FL._curves(gun.animation_data):
        if fc.data_path in ("hide_viewport", "hide_render"):
            for k in fc.keyframe_points:
                k.interpolation = "CONSTANT"

    # the coat: the lapel draw's keys go, an empty key per stop
    coat = bpy.data.objects.get("Outfit_Coat")
    if coat is not None and coat.data.shape_keys:
        kb = coat.data.shape_keys.key_blocks
        for k in [k for k in kb if k.name.startswith("DrawFix") or k.name.startswith("LongDrawFix")]:
            coat.shape_key_remove(k)
        frames = [S[n] for n in names_st] + [f_hip]
        for i, f in enumerate(frames):
            k = coat.shape_key_add(name=f"LauncherDrawFix_f{f:02d}", from_mix=False)
            for ff, v in ((frames[i - 1] if i else f_idle, 0.0), (f, 1.0), (frames[i + 1] if i + 1 < len(frames) else None, 0.0)):
                if ff is not None:
                    k.value = v
                    k.keyframe_insert("value", frame=ff)
    for n in names_st:
        sc.timeline_markers.new(n, frame=S[n])
    arm["lab_launcher_draw"] = json.dumps({"src": os.path.basename(src), "stops": S, "skirt": SKIRT_AT, "open": OPEN_AT, "pocket": POCKET_AT,
                                           "lean": LEAN_DEG, "trunk": TRUNK_SHARE})
    LGP._save(sc, arm, out)


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(a) >= 3 and a[0] == "build":
        build(a[1], a[2], tuple(int(x) for x in a[3].split(",")) if len(a) > 3 else (5, 9, 11, 15, 19))
    else:
        fail("usage: -- build <HIP timeline .blend> <out .blend> [skirt,open,appear,lift,join]")


if __name__ == "__main__":
    main()
