"""long_gun_pose.py — a long gun's own draw timeline RE-POSED around its hold (2026-11-26, the short stock; MOVEMENT §11.6 step 2).

Three commands, each run by Blender on a timeline (`SEQ_draw_<model>_<FIG>.blend`: the gun riding the LEFT hand, the markers idle / lapel /
centre / hip / aim), each written as a NEW file, never over one (the Director's timelines are only replaced on his word):

  grip_donor  One timeline's SUPPORT-HAND grip put on another timeline of the same gun (the Director, after placing the female's left hand on
              the short stock's pump: "Tente fazer essa adaptação para as outras mãos do male, usando o mesmo shape dos ossos"). The DONOR
              holds the gun with the left hand at one place: the palm on a point of the gun, the hand turned a way against the gun, the
              fingers in a shape. The TARGET keeps its body; at each of its stops from the gun's first shown frame:
                - the gun SLIDES along its own barrel (x) by `slide` of what brings the donor's palm point under the target's palm (1 = all
                  of it: the target's left arm keeps its place), never across it, so the barrel keeps its line; `<frame>=<slide>` sets it
                  per stop (the male's aim: 0.7, so the gun goes back only 6.7 cm and the left arm reaches the rest);
                - the left hand takes the donor's turn against the gun with its palm on the donor's palm point (`family_lab._reach`, the
                  two-bone solve that keeps the elbow's plane) and the donor's finger joints (local rotations: the shape of the bones);
                - the right hand, where its palm was on the gun (within `family_lab.IN_STEP_PALM_CM`), keeps its place against the gun;
              then the gun is re-keyed at EVERY frame from the first shown one (the slide eased between stops), against the hand as solved.
              A world offset (`<frame>=<fwd>:<side>:<up>`, lab cm; fwd = -Y, side = +X = the figure's left, up = Z) moves the gun with both
              hands at a frame (it becomes a stop) and is eased to nothing at the stops round it.

  hip_probe   The hip for a list of chest turns: how far the gun can come forward with the left arm within `cap` % of its reach, and the
              arms then (the right upper arm's pitch, + = the elbow ahead of the shoulder; each arm's reach; the wrists' bend). Nothing saved.

  hip         The HIP brought forward (the Director on the female's short stock: "o braço direito no hip ... ficou muito pra tras. Veja se
              consegue deixar a pose mais natural, com os dois braços e a arma um pouco mais pra frente"). Measured there: the right upper
              arm 70 deg BACK (his family hip: 30), because the pump sits far ahead of the grip and the left hand on it was at 93 % of its
              reach: the gun could go only ~2 cm forward before the left arm was straight (the right elbow's swing and the left clavicle
              buy little). So:
                - the chest turns `turn` deg about the vertical (the LEFT shoulder forward, a shotgun's bladed stance), spread over Spine /
                  Spine1 / Spine2, the Neck turned back as much (the head keeps its look), keyed where the trunk is keyed between `start`
                  and `hip`, eased in from nothing at `start` (`family_lab._ease`);
                - the gun and the left hand move by a world offset eased the same way at every stop from `start` to `hip` (the gun rides
                  the left hand: its keys stay); `fwd` may be `auto`, the furthest forward (0.25 cm steps) with the left arm within `cap`;
                - the RIGHT hand moves with the gun where its palm holds it (the hip); before, it stays where it was put (re-solved against
                  the turned chest), except after `approach`: from its place there it comes down to its place on the grip by the hip, its
                  target blended in the BODY's frame on the same smoothstep (the female's short stock held it ahead at 21-22 and took it
                  11 cm back to the grip in the last frame; the gun swings level round the left hand there and its grip comes up from below,
                  so a target fixed to the moving grip would drag the hand down and forward and back again).
              Then `family_lab.py raise` rebuilds the raise from the new hip (with its mid-raise turn, the butt out of the coat) and
              `gun_cuts.py scan` checks what still cuts. The short stock (2026-11-26): both figures 15 deg; the female `auto` (3.75 cm) with
              `approach` 19; the male `auto` with 1.5 cm to his right (-1.5 side: the butt out of the coat's skirt), 5 cm. A FULL stock
              (the pack's shotgun 02, like the family's 01) runs through the coat's front at the hip and out of its back: `up`, `side` and
              `tilt` (deg about the gun's own local y through the left palm) take the butt out beside the coat, tucked by the forearm.

  pump_grip   The left hand put on the target model's PUMP the way a DONOR timeline holds ITS pump (another pump gun: the short stock, whose
              hold the Director posed on the female, "usando o mesmo shape dos ossos"; then "Para as outras shotguns que tem a bomba, usamos o
              mesmo mecanismo, adaptando onde for necessário", 2026-11-26), at the given stops. Each model's pump is its loose wooden piece
              furthest forward along the barrel (in its gun frame: `tripo_pose_lab._gun_frame_points`, barrel +X, top +Z). The donor's palm
              goes at the same share along the target's pump and the same offset (in figure units) from its middle across and from its
              underside; the hand turned against the barrel as the donor's, the donor's finger joints. The gun SLIDES along its barrel by
              `slide` of what brings that point under the palm (1 = the left arm keeps its place; `auto` = the least slide that keeps the left
              arm within `cap` % of its reach, the arm reaching for the rest: the aim); the right hand, where its palm held the gun, keeps its
              place on it. Then the slides named are re-baked from the stops beside them (`tripo_pose_lab._bake_slide`: a baked slide is
              derived from its two stops).
  nudge       The gun moved with the left hand (and the right one where its palm holds the gun) by a world offset at given frames (fwd = -Y,
              side = +X = the figure's left, up = Z; figure cm), each keyed there (a new stop, smoothed into the stops round it by the
              interpolation): the smallest move that takes the gun out of the figure at a frame `gun_cuts.py` flags (`offset_common.py` finds
              one offset for a run of sub-frames). The right hand, off the gun, keeps its place.
  drop        Every armature key at the given frames removed (they stop being stops): the shotgun's inherited 18 and 20 in a model's own
              timeline (the Director, 2026-11-24: "sem 18/20"), the turn to the hip spread over 16-23.

  blender -b --python long_gun_pose.py -- grip_donor <donor SEQ> <target SEQ> <out .blend> [slide 0..1] [<f>=<slide>,...|-] [<f>=<fwd>:<side>:<up>,...|-]
  blender -b --python long_gun_pose.py -- drop <SEQ .blend> <out .blend> <frames,comma>
  blender -b --python long_gun_pose.py -- nudge <SEQ .blend> <out .blend> <f>=<fwd>:<side>:<up>,...
  blender -b --python long_gun_pose.py -- pump_grip <target SEQ> <donor SEQ> <out .blend> <stops,comma> [<f>=<slide>|<f>=auto,...|-] [cap %] [<a>-<b>,... re-baked slides]
  blender -b --python long_gun_pose.py -- hip_probe <SEQ .blend> <start> <hip> <turns deg,comma> [cap %]
  blender -b --python long_gun_pose.py -- hip <SEQ .blend> <out .blend> <start> <hip> <turn deg> <fwd cm|auto> [cap %] [side cm] [up cm] [approach|-] [tilt deg]
"""
import bpy, sys, os, math, json
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tripo"))
import family_lab as FL
import tripo_pose_lab as tpl

P = FL.PREFIX
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")
TRUNK = ("Spine", "Spine1", "Spine2")
ARMS = [s + b for s in ("Left", "Right") for b in ("Arm", "ForeArm", "Hand")]


def fail(msg):
    print(f"[long_gun_pose] ERROR: {msg}")
    sys.exit(1)


def _open(path):
    bpy.ops.wm.open_mainfile(filepath=path)
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    gun = next((o for o in bpy.data.objects if o.name.startswith("PROP_") and o.type == "MESH"), None)
    if arm is None or gun is None or gun.parent is not arm or gun.parent_bone != P + "LeftHand":
        fail(f"{os.path.basename(path)}: no PROP_ riding the armature's LeftHand")
    if arm.mode != "OBJECT":
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="OBJECT")
    return bpy.context.scene, arm, gun


def _save(sc, arm, out):
    sc.frame_set(sc.frame_start)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    print(f"[long_gun_pose] wrote {out}")


def _keyed(arm):
    return sorted({round(k.co[0]) for fc in FL._curves(arm.animation_data) for k in fc.keyframe_points})


def _keyed_bones(arm, f):
    out = set()
    for fc in FL._curves(arm.animation_data):
        if fc.data_path.startswith('pose.bones["') and any(round(k.co[0]) == f for k in fc.keyframe_points):
            out.add(fc.data_path.split('"')[1].replace(P, ""))
    return out


def _palm_a(arm, side):
    """The palm's centre in ARMATURE space (family_lab._palm is world space)."""
    pb = arm.pose.bones
    return (pb[P + side + "Hand"].head + pb[P + side + "HandMiddle1"].head) * 0.5


def _gun_a(arm, gun):
    return arm.matrix_world.inverted() @ gun.matrix_world


def _key_arms(arm, names, before, f):
    """Key each bone's rotation at `f`, kept on the same side of the quaternion sphere as `before` (no flip between keys)."""
    for n in names:
        b = arm.pose.bones[n if n.startswith(P) else P + n]
        if b.rotation_quaternion.dot(before[n]) < 0.0:
            b.rotation_quaternion = -b.rotation_quaternion
        b.keyframe_insert("rotation_quaternion", frame=f)


def grip_donor(donor, target, out, slide_all=1.0, slide_at=None, offset_at=None):
    slide_at, offset_at = slide_at or {}, offset_at or {}
    if os.path.exists(out) or os.path.realpath(out) in (os.path.realpath(donor), os.path.realpath(target)):
        fail(f"{out} exists or is an input: a timeline is never written over")
    # the donor: its grip, per frame from the gun's first shown frame
    sc, arm, gun = _open(donor)
    first_shown = None
    for f in range(sc.frame_start, sc.frame_end + 1):
        sc.frame_set(f)
        if not gun.hide_viewport:
            first_shown = f
            break
    if first_shown is None:
        fail(f"{os.path.basename(donor)}: the gun is never shown")
    fingers = [b.name for b in arm.pose.bones if b.name.startswith(P + "LeftHand") and any(x in b.name for x in FINGERS)]
    grip = {}
    for f in range(first_shown, sc.frame_end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        G = _gun_a(arm, gun)
        grip[f] = {"palm": G.inverted() @ _palm_a(arm, "Left"),                                  # the palm point in the gun's own frame
                   "turn": G.to_quaternion().inverted() @ arm.pose.bones[P + "LeftHand"].matrix.to_quaternion(),   # the hand against the gun
                   "fingers": {n: arm.pose.bones[n].rotation_quaternion.copy() for n in fingers}}
    sc.frame_set(sc.frame_end)
    bpy.context.view_layer.update()
    d_scale = gun.matrix_world.to_scale()[0]
    print(f"[long_gun_pose] grip_donor: donor {os.path.basename(donor)}, the gun shown from {first_shown}")

    # the target as it is
    sc, arm, gun = _open(target)
    sc.frame_set(sc.frame_end)
    bpy.context.view_layer.update()
    if abs(gun.matrix_world.to_scale()[0] - d_scale) > 1e-4 * d_scale:
        print(f"[long_gun_pose] WARNING: the gun's world scale differs at the last frame: donor {d_scale:.6f}, target {gun.matrix_world.to_scale()[0]:.6f}")
    keyed = _keyed(arm)
    frames = list(range(first_shown, sc.frame_end + 1))
    stops = sorted({f for f in keyed if f >= first_shown} | set(offset_at))
    old = {}
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        G = _gun_a(arm, gun)
        old[f] = {"G": G.copy(), "palmL": G.inverted() @ _palm_a(arm, "Left"), "RH": arm.pose.bones[P + "RightHand"].matrix.copy(),
                  "R_on": FL._bvh_world(gun).find_nearest(FL._palm(arm, "Right"))[3] * 100.0,
                  "palm_in_hand": arm.pose.bones[P + "LeftHand"].matrix.inverted() @ _palm_a(arm, "Left")}
    s_cm = gun.matrix_world.to_scale()[0] * 100.0
    print(f"[long_gun_pose] grip_donor: target {os.path.basename(target)}, stops {stops}")
    # the slide at each stop (gun-frame units along x), eased between stops for the frames in between
    slide = {f: slide_at.get(f, slide_all) * (old[f]["palmL"].x - grip[f]["palm"].x) for f in stops}
    for f in frames:
        if f in slide:
            continue
        lo = max((s for s in stops if s < f), default=None)
        hi = min((s for s in stops if s > f), default=None)
        if lo is None or hi is None:
            slide[f] = slide[lo if lo is not None else hi]
        else:
            t = FL._ease((f - lo) / float(hi - lo))
            slide[f] = slide[lo] * (1.0 - t) + slide[hi] * t
    new_G = {f: old[f]["G"] @ Matrix.Translation((slide[f], 0.0, 0.0)) for f in frames}
    # the world offsets: given at their frames, nothing at the other stops, eased in between; put in armature space
    zero = Vector((0.0, 0.0, 0.0))
    off = {}
    for f in frames:
        if f in stops:
            off[f] = offset_at.get(f, zero)
            continue
        lo = max((s for s in stops if s < f), default=None)
        hi = min((s for s in stops if s > f), default=None)
        vlo = offset_at.get(lo, zero) if lo is not None else zero
        vhi = offset_at.get(hi, zero) if hi is not None else zero
        t = FL._ease((f - lo) / float(hi - lo)) if lo is not None and hi is not None else 0.0
        off[f] = vlo.lerp(vhi, t)
    to_arm = arm.matrix_world.to_3x3().inverted()
    for f in frames:
        fwd, side, up = off[f]
        new_G[f] = Matrix.Translation(to_arm @ (Vector((side, -fwd, up)) / 100.0)) @ new_G[f]

    pb = arm.pose.bones
    prevq = {}
    for f in stops:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        G = new_G[f]
        turn = G.to_quaternion() @ grip[f]["turn"]
        X = (G @ grip[f]["palm"]) - (turn.to_matrix() @ old[f]["palm_in_hand"])
        miss_l, share_l = FL._reach(arm, "Left", Matrix.Translation(X) @ turn.to_matrix().to_4x4())
        for n, q in grip[f]["fingers"].items():
            pb[n].rotation_quaternion = q
        bpy.context.view_layer.update()
        msg = (f"[long_gun_pose] {f}{' (new stop)' if f not in keyed else ''}: slide {slide[f] * s_cm:+.2f} cm, offset "
               f"{tuple(round(x, 2) for x in off[f])}; left wrist missed by {miss_l:.2f} cm at {share_l * 100:.0f} % of the arm")
        keys = [P + "LeftArm", P + "LeftForeArm", P + "LeftHand"] + list(grip[f]["fingers"])
        if old[f]["R_on"] <= FL.IN_STEP_PALM_CM:
            miss_r, share_r = FL._reach(arm, "Right", G @ (old[f]["G"].inverted() @ old[f]["RH"]))
            keys += [P + "RightArm", P + "RightForeArm", P + "RightHand"]
            msg += f"; right hand kept on the gun (wrist missed by {miss_r:.2f} cm at {share_r * 100:.0f} %)"
        for n in keys:
            q = pb[n].rotation_quaternion
            if n in prevq and q.dot(prevq[n]) < 0.0:
                pb[n].rotation_quaternion = -q
            prevq[n] = pb[n].rotation_quaternion.copy()
            pb[n].keyframe_insert("rotation_quaternion", frame=f)
        print(msg)

    gprev = None
    for f in frames:            # the gun at every frame from the first shown, at its new place against the hand as now solved
        sc.frame_set(f)
        bpy.context.view_layer.update()
        gun.matrix_world = arm.matrix_world @ new_G[f]
        bpy.context.view_layer.update()
        if gprev is not None and gun.rotation_quaternion.dot(gprev) < 0.0:
            gun.rotation_quaternion = -gun.rotation_quaternion
        gprev = gun.rotation_quaternion.copy()
        for path in ("location", "rotation_quaternion", "scale"):
            gun.keyframe_insert(path, frame=f)
    worst = 0.0
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        worst = max(worst, (_gun_a(arm, gun).translation - new_G[f].translation).length * arm.matrix_world.to_scale().x * 100.0)
    print(f"[long_gun_pose] the gun re-keyed at {frames[0]}..{frames[-1]}; off its intended place by at most {worst:.3f} cm")
    arm["lab_grip_donor"] = json.dumps({"donor": os.path.basename(donor), "slide": slide_all, "slide_at": slide_at,
                                        "offset_at": {k: list(v) for k, v in offset_at.items()}})
    _save(sc, arm, out)


def _gun_turn(prop):
    """The lab's gun frame of `prop` (family_lab's H3 model row whose source is the read-back's model file)."""
    src = os.path.normpath(tpl.PROP_GLB[prop])
    ref = FL.FAMILIES["H3"]
    if os.path.normpath(os.path.join(FL.ROOT, ref["reference_glb"])) == src:
        return FL.gun_frame_matrix([["Z", 0.0]])
    for m in ref["models"]:
        if os.path.normpath(m[1]) == src:
            return FL.gun_frame_matrix(m[3])
    fail(f"{prop}: no H3 model of family_lab with the source {src}")


def _pump_box(prop, part="pump"):
    """`prop`'s PUMP in its gun frame: (M: the model's own coordinates -> the gun frame at factor 1, the pump's lowest corner, its highest).

    part="foregrip" (2026-11-27, the grenade launcher 20, the Director: "tem o mesmo cabo de apoio vertical pra mão esquerda que usamos em
    outras armas"): the VERTICAL FORE-GRIP instead, the loose piece furthest forward along the barrel that is taller than it is long and
    hangs below the hold point; the palm's height is kept from its TOP, under the barrel, since the grips differ in length (the bullpup's at x 1.90-2.17, 0.67 high; the launcher's at 0.31-0.40, 0.25 high)."""
    import bmesh
    probe, _ns = tpl.import_prop(prop, {})
    W0 = probe.matrix_world.copy()
    F, _pts, _L = tpl._gun_frame_points(probe, 1.0, turn=_gun_turn(prop))
    M = F @ W0
    bm = bmesh.new()
    bm.from_mesh(probe.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)       # the glTF import splits vertices per face
    bm.verts.ensure_lookup_table()
    wood = {i for i, sl in enumerate(probe.material_slots) if sl.material is not None and "Wood" in sl.material.name}
    seen, parts = set(), []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        stack, comp = [v0], []
        seen.add(v0.index)
        while stack:
            v = stack.pop()
            comp.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        is_wood = any(f.material_index in wood for v in comp for f in v.link_faces)
        pts = [M @ v.co for v in comp]
        parts.append((is_wood, Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])))
    bm.free()
    bpy.data.objects.remove(probe)
    if part == "foregrip":
        tall = [(lo, hi) for _w, lo, hi in parts if (hi.z - lo.z) > 1.5 * (hi.x - lo.x) and lo.z < _pts["hold"].z]
        if not tall:
            fail(f"{prop}: no vertical fore-grip below the hold")
        return (M,) + max(tall, key=lambda b: b[0].x)
    woods = [(lo, hi) for w, lo, hi in parts if w]
    if not woods:
        fail(f"{prop}: no wooden piece (no pump) on the model")
    lo, hi = max(woods, key=lambda b: b[0].x)                        # the wooden piece furthest forward: the pump (the stock is behind)
    return M, lo, hi


def pump_grip(target, donor, out, stops, ks=None, cap=97.0, rebake=(), part="pump"):
    ks = ks or {}
    if os.path.exists(out) or os.path.realpath(out) in (os.path.realpath(target), os.path.realpath(donor)):
        fail(f"{out} exists or is an input: a timeline is never written over")
    # the donor's hold on its pump, per stop: the share along it, the offsets in figure units, the hand's turn against the barrel, the fingers
    sc, arm, gun = _open(donor)
    dprop = json.loads(arm["lab_props"])[0]
    Md, lo_d, hi_d = _pump_box(dprop, part)
    dframe = {}                                                        # a stop "23:31": the target's 23 takes the donor's hold at 31
    for i, f in enumerate(stops):
        if isinstance(f, str) and ":" in f:
            t_, d_ = (int(x) for x in f.split(":"))
            stops[i], dframe[t_] = t_, d_
        else:
            stops[i] = dframe.setdefault(int(f), int(f))
    fingers = [b.name for b in arm.pose.bones if b.name.startswith(P + "LeftHand") and any(x in b.name for x in FINGERS)]
    grip = {}
    for f in stops:
        sc.frame_set(dframe[f])
        bpy.context.view_layer.update()
        GF = _gun_a(arm, gun) @ Md.inverted()                          # the donor's gun frame in armature space
        k_d = GF.to_scale().x
        q = GF.inverted() @ _palm_a(arm, "Left")
        grip[f] = {"u": (q.x - lo_d.x) / (hi_d.x - lo_d.x), "dy": (q.y - (lo_d.y + hi_d.y) / 2.0) * k_d, "dz": (q.z - (hi_d.z if part == "foregrip" else lo_d.z)) * k_d,
                   "turn": GF.to_quaternion().inverted() @ arm.pose.bones[P + "LeftHand"].matrix.to_quaternion(),
                   "fingers": {n: arm.pose.bones[n].rotation_quaternion.copy() for n in fingers}}
        print(f"[long_gun_pose] pump_grip: donor {os.path.basename(donor)} ({dprop}) {f}: the palm {grip[f]['u'] * 100:.0f} % along its pump "
              f"({(hi_d.x - lo_d.x) * k_d * 100:.1f} long, {(hi_d.z - lo_d.z) * k_d * 100:.1f} high), {grip[f]['dz'] * 100:+.2f} from its {'top' if part == 'foregrip' else 'underside'}, "
              f"{grip[f]['dy'] * 100:+.2f} across")
    # the target
    sc, arm, gun = _open(target)
    tprop = json.loads(arm["lab_props"])[0]
    Mt, lo_t, hi_t = _pump_box(tprop, part)
    keyed = _keyed(arm)
    missing = [f for f in stops if f not in keyed]
    if missing:
        fail(f"{os.path.basename(target)}: not keyed at {missing}")
    pb = arm.pose.bones
    names = [P + n for n in ARMS] + fingers
    gprev = None
    for f in stops:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        G = _gun_a(arm, gun)
        GF = G @ Mt.inverted()
        k_t = GF.to_scale().x
        q_t = Vector((lo_t.x + grip[f]["u"] * (hi_t.x - lo_t.x), (lo_t.y + hi_t.y) / 2.0 + grip[f]["dy"] / k_t, (hi_t.z if part == "foregrip" else lo_t.z) + grip[f]["dz"] / k_t))
        need = (GF.inverted() @ _palm_a(arm, "Left")).x - q_t.x         # gun-frame units along the barrel
        rh_rel = G.inverted() @ pb[P + "RightHand"].matrix
        r_on = FL._bvh_world(gun).find_nearest(FL._palm(arm, "Right"))[3] * 100.0
        palm_in_hand = pb[P + "LeftHand"].matrix.inverted() @ _palm_a(arm, "Left")
        base = {n: pb[n].rotation_quaternion.copy() for n in names}

        def place(k):
            for n, q in base.items():
                pb[n].rotation_quaternion = q
            bpy.context.view_layer.update()
            nGF = GF @ Matrix.Translation((k * need, 0.0, 0.0))
            turn = nGF.to_quaternion() @ grip[f]["turn"]
            X = (nGF @ q_t) - (turn.to_matrix() @ palm_in_hand)
            miss, share = FL._reach(arm, "Left", Matrix.Translation(X) @ turn.to_matrix().to_4x4())
            return nGF @ Mt, miss, share

        k = ks.get(f, 1.0)
        if k == "auto":
            k = 1.0
            for i in range(0, 21):
                _G, miss, share = place(i * 0.05)
                if miss < 0.05 and share * 100.0 <= cap:
                    k = i * 0.05
                    break
        nG, miss, share = place(k)
        for n, q in grip[f]["fingers"].items():
            pb[n].rotation_quaternion = q
        bpy.context.view_layer.update()
        msg = (f"[long_gun_pose] pump_grip {f}: the gun slides {k * need * k_t * 100:+.2f} along its barrel (slide {k:.2f} of {need * k_t * 100:+.2f}); "
               f"left wrist missed by {miss:.2f} cm at {share * 100:.0f} % of the arm")
        if r_on <= FL.IN_STEP_PALM_CM:
            miss_r, share_r = FL._reach(arm, "Right", nG @ rh_rel)
            msg += f"; right hand kept on the gun ({miss_r:.2f} cm, {share_r * 100:.0f} %)"
        _key_arms(arm, names, base, f)
        bpy.context.view_layer.update()
        gun.matrix_world = arm.matrix_world @ nG
        bpy.context.view_layer.update()
        if gprev is not None and gun.rotation_quaternion.dot(gprev) < 0.0:
            gun.rotation_quaternion = -gun.rotation_quaternion
        gprev = gun.rotation_quaternion.copy()
        for path in ("location", "rotation_quaternion", "scale"):
            gun.keyframe_insert(path, frame=f)
        bpy.context.view_layer.update()
        print(msg + f"; the palm {FL._bvh_world(gun).find_nearest(FL._palm(arm, 'Left'))[3] * 100:.2f} cm from the gun")
    for a_, b_ in rebake:
        c = []
        for f in (a_, b_):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            c.append(gun.matrix_world.inverted() @ FL._palm(arm, "Left"))
        tpl._bake_slide(sc, arm, gun, a_, b_, c[0], c[1])
        print(f"[long_gun_pose] pump_grip: the slide {a_}-{b_} re-baked: the hand runs {(c[1] - c[0]).length * gun.matrix_world.to_scale().x * 1000:.0f} mm along it")
    arm["lab_pump_grip"] = json.dumps({"donor": os.path.basename(donor), "stops": stops, "donor_frames": {str(k): v for k, v in dframe.items()},
                                       "part": part, "slide": {str(k): v for k, v in ks.items()}, "cap": cap})
    _save(sc, arm, out)


def nudge(src, out, offsets):
    if os.path.exists(out) or os.path.realpath(out) == os.path.realpath(src):
        fail(f"{out} exists or is the input: a timeline is never written over")
    sc, arm, gun = _open(src)
    pb = arm.pose.bones
    to_arm = arm.matrix_world.to_3x3().inverted()
    for f, (fw, sd, up) in sorted(offsets.items()):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        T = Matrix.Translation(to_arm @ (Vector((sd, -fw, up)) / 100.0))
        before = {n: pb[P + n].rotation_quaternion.copy() for n in ARMS}
        LH, RH = pb[P + "LeftHand"].matrix.copy(), pb[P + "RightHand"].matrix.copy()
        r_on = FL._bvh_world(gun).find_nearest(FL._palm(arm, "Right"))[3] * 100.0
        mL, rL = FL._reach(arm, "Left", T @ LH)
        mR, rR = FL._reach(arm, "Right", (T @ RH) if r_on <= FL.IN_STEP_PALM_CM else RH)
        _key_arms(arm, ARMS, before, f)
        print(f"[long_gun_pose] nudge {f}: the gun moved fwd {fw} side {sd} up {up} cm with the left hand ({rL * 100:.0f} % of the arm, missed by "
              f"{mL:.2f} cm); the right hand {'with it' if r_on <= FL.IN_STEP_PALM_CM else 'kept'} ({mR:.2f} cm)")
    arm["lab_nudges"] = json.dumps({str(k): list(v) for k, v in offsets.items()})
    _save(sc, arm, out)


def drop(src, out, frames):
    if os.path.exists(out) or os.path.realpath(out) == os.path.realpath(src):
        fail(f"{out} exists or is the input: a timeline is never written over")
    sc, arm, gun = _open(src)
    gone = 0
    for fc in FL._curves(arm.animation_data):
        while True:
            i = next((i for i, k in enumerate(fc.keyframe_points) if round(k.co[0]) in frames), None)
            if i is None:
                break
            fc.keyframe_points.remove(fc.keyframe_points[i])
            gone += 1
        fc.update()
    print(f"[long_gun_pose] drop: {gone} armature keys removed at {frames}; stops now {[f for f in _keyed(arm) if f != sc.frame_start]}")
    arm["lab_dropped"] = json.dumps(sorted(set(json.loads(arm.get("lab_dropped", "[]"))) | set(frames)))
    _save(sc, arm, out)


class _Hip:
    """The hip's working set on an open timeline: the chest's turn, the offsets, the two arms' solve and what they measure."""

    def __init__(self, arm, gun, cap, side_cm, up_cm):
        self.arm, self.gun, self.cap, self.side_cm, self.up_cm = arm, gun, cap, side_cm, up_cm
        self.pb = arm.pose.bones
        self.W = arm.matrix_world
        self.UP = (self.W.to_3x3().inverted() @ Vector((0.0, 0.0, 1.0))).normalized()     # the world's vertical in armature space

    def turn(self, bone, ang):
        """`bone` turned by `ang` rad about the world vertical through its head (its children follow)."""
        M = bone.matrix.copy()
        h = M.translation.copy()
        bone.matrix = Matrix.Translation(h) @ Matrix.Rotation(ang, 4, self.UP) @ Matrix.Translation(-h) @ M
        bpy.context.view_layer.update()

    def twist_chest(self, deg):
        for n in TRUNK:
            self.turn(self.pb[P + n], math.radians(-deg / 3.0))      # negative about +Z: clockwise from above, the left shoulder comes forward
        self.turn(self.pb[P + "Neck"], math.radians(deg))

    def offset(self, fw, sd, up):
        return Matrix.Translation(self.W.to_3x3().inverted() @ (Vector((sd, -fw, up)) / 100.0))

    def pitch(self, side):
        S, E = (self.W @ self.pb[P + side + n].head for n in ("Arm", "ForeArm"))
        e = E - S
        return math.degrees(math.atan2(-e.y, -e.z))

    def wrist_bend(self, side):
        q = self.pb[P + side + "ForeArm"].matrix.to_quaternion().inverted() @ self.pb[P + side + "Hand"].matrix.to_quaternion()
        ang = math.degrees(q.angle)
        return min(ang, 360.0 - ang)

    def solve(self, LH, RH):
        mL, rL = FL._reach(self.arm, "Left", LH)
        mR, rR = FL._reach(self.arm, "Right", RH)
        return mL, rL, mR, rR

    def furthest(self, LH, RH, base):
        """The furthest forward offset (0.25 cm steps) with the left arm within `cap` % of its reach; the pose restored before each try."""
        best = 0.0
        for i in range(0, 61):
            fw = i * 0.25
            for n, q in base.items():
                self.pb[P + n].rotation_quaternion = q
            bpy.context.view_layer.update()
            T = self.offset(fw, self.side_cm, self.up_cm)
            _mL, rL, _mR, _rR = self.solve(T @ LH, T @ RH)
            if rL * 100.0 > self.cap:
                break
            best = fw
        return best


def hip_probe(src, hip, turns, cap=97.0):
    sc, arm, gun = _open(src)
    h = _Hip(arm, gun, cap, 0.0, 0.0)
    sc.frame_set(hip)
    bpy.context.view_layer.update()
    names = list(TRUNK) + ["Neck"] + ARMS
    base = {n: h.pb[P + n].rotation_quaternion.copy() for n in names}
    LH, RH = h.pb[P + "LeftHand"].matrix.copy(), h.pb[P + "RightHand"].matrix.copy()
    print(f"[long_gun_pose] {os.path.basename(src)} {hip}: as saved, right pitch {h.pitch('Right'):+.1f}, wrist bends L {h.wrist_bend('Left'):.0f} "
          f"R {h.wrist_bend('Right'):.0f}")
    for tw in turns:
        for n, q in base.items():
            h.pb[P + n].rotation_quaternion = q
        bpy.context.view_layer.update()
        h.twist_chest(tw)
        arms_now = {n: h.pb[P + n].rotation_quaternion.copy() for n in ARMS}
        fw = h.furthest(LH, RH, arms_now)
        for n, q in arms_now.items():
            h.pb[P + n].rotation_quaternion = q
        bpy.context.view_layer.update()
        T = h.offset(fw, 0.0, 0.0)
        mL, rL, mR, rR = h.solve(T @ LH, T @ RH)
        print(f"[long_gun_pose] turn {tw:4.1f}: fwd {fw:4.2f} -> right pitch {h.pitch('Right'):+6.1f} reach {rR * 100:3.0f}% bend "
              f"{h.wrist_bend('Right'):3.0f} | left pitch {h.pitch('Left'):+6.1f} reach {rL * 100:3.0f}% bend {h.wrist_bend('Left'):3.0f} | "
              f"misses {mL:.2f} {mR:.2f}")


def hip(src, out, start, hip_f, twist, fwd_arg, cap=97.0, side_cm=0.0, up_cm=0.0, approach=None, tilt=0.0):
    if os.path.exists(out) or os.path.realpath(out) == os.path.realpath(src):
        fail(f"{out} exists or is the input: a timeline is never written over")
    sc, arm, gun = _open(src)
    h = _Hip(arm, gun, cap, side_cm, up_cm)
    pb = h.pb
    stops = [f for f in _keyed(arm) if start < f <= hip_f]
    trunk_at = [f for f in stops if set(TRUNK) <= _keyed_bones(arm, f)]
    if hip_f not in trunk_at:
        fail(f"the trunk is not keyed at the hip {hip_f}")
    if approach is not None and approach not in stops:
        fail(f"the approach {approach} is not a stop between {start} and {hip_f}: {stops}")
    ease = lambda f: FL._ease((f - start) / float(hip_f - start))
    orig = {}
    for f in stops:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        orig[f] = (pb[P + "LeftHand"].matrix.copy(), pb[P + "RightHand"].matrix.copy(),
                   FL._bvh_world(gun).find_nearest(FL._palm(arm, "Right"))[3] * 100.0,
                   _palm_a(arm, "Left"), (h.W.to_3x3().inverted() @ (gun.matrix_world.to_3x3().normalized() @ Vector((0.0, 1.0, 0.0)))).normalized())

    def tilted(f, deg):
        """The gun turned by `deg` about its own local y through the left palm, as a move of the hands (armature space)."""
        if not deg:
            return Matrix.Identity(4)
        p = orig[f][3]
        return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, orig[f][4]) @ Matrix.Translation(-p)

    sc.frame_set(hip_f)
    bpy.context.view_layer.update()
    if fwd_arg == "auto":
        h.twist_chest(twist)
        fwd = h.furthest(orig[hip_f][0], orig[hip_f][1], {n: pb[P + n].rotation_quaternion.copy() for n in ARMS})
        sc.frame_set(hip_f)              # a frame set re-reads the keys: the trial pose is gone
        bpy.context.view_layer.update()
    else:
        fwd = float(fwd_arg)
    print(f"[long_gun_pose] hip {os.path.basename(src)}: stops {stops}, trunk keyed at {trunk_at}; chest turned {twist} deg, the gun moved fwd {fwd} "
          f"side {side_cm} up {up_cm} cm{f', tilted {tilt} deg' if tilt else ''} at {hip_f}")
    # 1) the chest turned where the trunk is keyed (the arms are solved after: they read the trunk as interpolated)
    for f in trunk_at:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        before = {n: pb[P + n].rotation_quaternion.copy() for n in list(TRUNK) + ["Neck"]}
        h.twist_chest(twist * ease(f))
        _key_arms(arm, list(before), before, f)
    # 2) the gun and the left hand moved, the right hand kept / brought down onto the grip, each arm solved, at every stop
    T_hip = h.offset(fwd, side_cm, up_cm) @ tilted(hip_f, tilt)
    for f in stops:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        w = ease(f)
        T = h.offset(fwd * w, side_cm * w, up_cm * w) @ tilted(f, tilt * w)
        before = {n: pb[P + n].rotation_quaternion.copy() for n in ARMS}
        mL, rL = FL._reach(arm, "Left", T @ orig[f][0])
        bpy.context.view_layer.update()
        if f == hip_f or orig[f][2] <= FL.IN_STEP_PALM_CM:
            RH, how = T @ orig[f][1], "with the gun"
        elif approach is not None and f > approach:
            s_ = FL._ease((f - approach) / float(hip_f - approach))
            RH, how = FL._blend_matrix(orig[approach][1], T_hip @ orig[hip_f][1], s_), f"toward the grip's place {s_ * 100:.0f} %"
        else:
            RH, how = orig[f][1], "kept"
        mR, rR = FL._reach(arm, "Right", RH)
        _key_arms(arm, ARMS, before, f)
        bpy.context.view_layer.update()
        r_on = FL._bvh_world(gun).find_nearest(FL._palm(arm, "Right"))[3] * 100.0
        print(f"[long_gun_pose] {f} ({w * 100:3.0f} %): right pitch {h.pitch('Right'):+6.1f} reach {rR * 100:3.0f}% bend {h.wrist_bend('Right'):3.0f} | "
              f"left reach {rL * 100:3.0f}% bend {h.wrist_bend('Left'):3.0f} | wrists miss {mL:.2f} {mR:.2f} | right hand {how}, palm to the gun "
              f"{orig[f][2]:.1f} -> {r_on:.1f} cm")
    arm["lab_hip_natural"] = json.dumps({"from": os.path.basename(src), "start": start, "hip": hip_f, "twist_deg": twist, "fwd_cm": fwd,
                                         "side_cm": side_cm, "up_cm": up_cm, "approach": approach, "tilt_deg": tilt})
    _save(sc, arm, out)


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not a:
        fail("usage: -- grip_donor <donor> <target> <out> [...] | hip_probe <SEQ> <start> <hip> <turns> [cap] | hip <SEQ> <out> <start> <hip> <turn> <fwd|auto> [...]")
    if a[0] == "grip_donor":
        slide_at = {int(k): float(v) for k, v in (x.split("=") for x in a[5].split(","))} if len(a) > 5 and a[5] != "-" else {}
        offset_at = {int(k): Vector([float(c) for c in v.split(":")]) for k, v in (x.split("=") for x in a[6].split(","))} \
            if len(a) > 6 and a[6] != "-" else {}
        grip_donor(a[1], a[2], a[3], float(a[4]) if len(a) > 4 else 1.0, slide_at, offset_at)
    elif a[0] == "pump_grip":
        ks = {int(k): (v if v == "auto" else float(v)) for k, v in (x.split("=") for x in a[5].split(","))} if len(a) > 5 and a[5] != "-" else {}
        rebake = [tuple(int(v) for v in x.split("-")) for x in a[7].split(",")] if len(a) > 7 and a[7] != "-" else []
        pump_grip(a[1], a[2], a[3], a[4].split(","), ks, float(a[6]) if len(a) > 6 else 97.0, rebake,
                  a[8] if len(a) > 8 else "pump")
    elif a[0] == "nudge":
        nudge(a[1], a[2], {int(k): tuple(float(c) for c in v.split(":")) for k, v in (x.split("=") for x in a[3].split(","))})
    elif a[0] == "drop":
        drop(a[1], a[2], [int(x) for x in a[3].split(",")])
    elif a[0] == "hip_probe":
        hip_probe(a[1], int(a[3]), [float(x) for x in a[4].split(",")], float(a[5]) if len(a) > 5 else 97.0)
    elif a[0] == "hip":
        hip(a[1], a[2], int(a[3]), int(a[4]), float(a[5]), a[6], float(a[7]) if len(a) > 7 else 97.0, float(a[8]) if len(a) > 8 else 0.0,
            float(a[9]) if len(a) > 9 else 0.0, int(a[10]) if len(a) > 10 and a[10] != "-" else None, float(a[11]) if len(a) > 11 else 0.0)
    else:
        fail(f"unknown command {a[0]}")


if __name__ == "__main__":
    main()
