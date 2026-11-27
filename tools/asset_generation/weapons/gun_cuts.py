"""gun_cuts.py — where a held gun CUTS the figure along a draw timeline (2026-11-26, the Director: "evitar que as armas entrem no casaco
durante as movimentações"; MOVEMENT §11.6 step 2).

THE RULE. A cut is a figure triangle crossing a gun triangle, sorted by the bone its vertices follow most: a BODY triangle (anything but a
forearm or a hand: the coat's panels, the shirt, the upper sleeve, the head, the hat) always counts; a SLEEVE triangle (a forearm's or a
hand's) counts when its centre is more than `cuff` cm from that side's wrist (the cuff round a hand holding the gun is not a cut); the hands'
own mesh is left out (they hold the gun; `hand_in_gun`-style checks measure their skin). The rule it replaces counted only pairs more than
12 cm from both wrists, and so missed every cut near the hands: the butt in the coat's skirt at the hip, the raise through the coat's front.

  scan   Per sample, what is cut, as BLENDER plays the timeline (sub-frames) and as the GAME plays it (`ActorAimPose3D` + `ActorMesh3D`): the
         path's weight runs linearly in time (the draw to the hip, then on to the aim); the body is the stops slerped at the weight EASED by a
         smoothstep between two resting stops (passing stops passed linearly in it); the gun's place in its hand and the coat's morphs are
         read at the LINEAR weight (`AimSequence.at(_aim_t)`), or at the eased one in `gamefix` (`AIM_GUN_EASED=1`, the gun's phase A/B).
         `bones` names the bone each cut triangle follows. Nothing saved.
  still  Stills at given (sub-)frames from given views, the gun painted orange and each cut triangle red, aimed at the chest. Writes
         <prefix>_<frame>_<n>.png. Nothing saved to the .blend. The camera is tripo_pose_lab._aim_camera's (az 0 = in front of the figure,
         +90 = its left, -90 = its right).

  blender -b --python gun_cuts.py -- scan <SEQ .blend> <first> <last> [steps a frame, 4] [cuff cm, 6] [blender|game|gamefix|both] [bones]
  blender -b --python gun_cuts.py -- still <SEQ .blend> <out prefix> <frames,comma> <az:el,...> <size px> [dist m] [cuff cm]
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

P = "mixamorig:"
PASSING_MARKERS = ("in-between", "release", "follow", "centre")   # tripo_pose_lab.PASSING_MARKERS: the stops the arms flow through


def fail(msg):
    print(f"[gun_cuts] ERROR: {msg}")
    sys.exit(1)


def _open(path):
    bpy.ops.wm.open_mainfile(filepath=path)
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    gun = next((o for o in bpy.data.objects if o.name.startswith("PROP_") and o.type == "MESH"), None)
    if arm is None or gun is None:
        fail(f"{os.path.basename(path)}: no armature or no PROP_ mesh")
    if arm.mode != "OBJECT":
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="OBJECT")
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o is not gun and not o.hide_get() and not o.hide_render and o.name != "Body_Hands"]
    return bpy.context.scene, arm, gun, meshes


def _classes(meshes):
    """Per mesh, per polygon: "Left" / "Right" when a vertex of it follows that side's forearm or hand most, else "body"; and the bone most
    of its vertices follow (for the `bones` report)."""
    klass, dombone = {}, {}
    for o in meshes:
        names = {g.index: g.name for g in o.vertex_groups}
        dom = [names.get(max(v.groups, key=lambda x: x.weight).group, "") if v.groups else "" for v in o.data.vertices]
        cl, db = [], []
        for p in o.data.polygons:
            c = "body"
            cnt = {}
            for i in p.vertices:
                for side in ("Left", "Right"):
                    if dom[i].startswith(P + side + "ForeArm") or dom[i].startswith(P + side + "Hand"):
                        c = side
                cnt[dom[i]] = cnt.get(dom[i], 0) + 1
            cl.append(c)
            db.append(max(cnt, key=cnt.get).replace(P, "") if cnt else "")
        klass[o.name], dombone[o.name] = cl, db
    return klass, dombone


def _tris(ob):
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    vs = [ob.matrix_world @ v.co for v in me.vertices]
    ps = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return vs, ps


def cut_polys(arm, gun, meshes, klass, cuff):
    """{mesh name: set of polygon indices the gun cuts} for the pose the scene is in now (empty when the gun is hidden)."""
    if gun.hide_viewport:
        return {}
    gv, gp = _tris(gun)
    g = BVHTree.FromPolygons(gv, gp)
    wr = {s: arm.matrix_world @ arm.pose.bones[P + s + "Hand"].head for s in ("Left", "Right")}
    out = {}
    for o in meshes:
        vs, ps = _tris(o)
        if len(ps) != len(klass[o.name]):
            continue
        cut = set()
        for _gi, oi in g.overlap(BVHTree.FromPolygons(vs, ps)):
            c = klass[o.name][oi]
            if c != "body" and (sum((vs[i] for i in ps[oi]), Vector()) / len(ps[oi]) - wr[c]).length <= cuff:
                continue
            cut.add(oi)
        if cut:
            out[o.name] = cut
    return out


def _report(cut, klass, dombone, bones):
    out = {}
    for name, polys in cut.items():
        for oi in polys:
            c = klass[name][oi]
            key = name.replace("Outfit_", "") + ("" if c == "body" else f"/{c[0]}sleeve") + ("@" + dombone[name][oi] if bones else "")
            out[key] = out.get(key, 0) + 1
    return out


def scan(path, A, B, steps=4, cuff=0.06, mode="both", bones=False):
    sc, arm, gun, meshes = _open(path)
    klass, dombone = _classes(meshes)
    pb = arm.pose.bones
    keyed = sorted({round(k.co[0]) for l in arm.animation_data.action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves
                    for k in fc.keyframe_points})
    first, last = sc.frame_start, sc.frame_end
    markers = {m.frame: m.name for m in sc.timeline_markers}
    stops = [f for f in keyed if f != first and first <= f <= last]
    passing = [f != last and (f not in markers or markers[f] in PASSING_MARKERS) for f in stops]
    wt = lambda f: (f - first) / float(last - first)
    coat = bpy.data.objects.get("Outfit_Coat")
    kbs = list(coat.data.shape_keys.key_blocks) if coat is not None and coat.data.shape_keys else []
    rots, hips, inhand, vis, morph = {}, {}, {}, {}, {}
    shown = None
    for f in range(first, last + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        if f in stops:
            rots[f] = {b.name: b.rotation_quaternion.copy() for b in pb}
            hips[f] = pb[P + "Hips"].location.copy()
        vis[f] = not gun.hide_viewport
        inhand[f] = pb[gun.parent_bone].matrix.inverted() @ (arm.matrix_world.inverted() @ gun.matrix_world) if vis[f] else None
        if vis[f] and shown is None:
            shown = inhand[f]
        morph[f] = [k.value for k in kbs]
    for f in inhand:
        if inhand[f] is None:            # a hidden object is not re-evaluated: the read-back uses the first shown placement there too
            inhand[f] = shown
    print(f"[gun_cuts] {os.path.basename(path)}: stops {[(f, 'P' if p else 'R') for f, p in zip(stops, passing)]}; {steps} samples a frame; "
          f"cuff {cuff * 100:.0f} cm")

    def smoothstep(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3.0 - 2.0 * x)

    def game_pose(p):
        """The stop pair, the slerp share and the eased weight `ActorAimPose3D.apply_to` uses at linear weight p (None before the first stop)."""
        sw = [wt(f) for f in stops]
        end = 0
        while end < len(stops) - 1 and (p > sw[end] or passing[end]):
            end += 1
        begin = end - 1
        while begin >= 0 and passing[begin]:
            begin -= 1
        span_from = 0.0 if begin < 0 else sw[begin]
        eased = span_from + (sw[end] - span_from) * smoothstep((p - span_from) / (sw[end] - span_from))
        stop = begin + 1
        while stop < end and eased > sw[stop]:
            stop += 1
        if stop == 0:
            return None
        t = max(0.0, min(1.0, (eased - sw[stop - 1]) / (sw[stop] - sw[stop - 1])))
        return stops[stop - 1], stops[stop], t, eased

    def blend_m(M0, M1, t):
        l0, q0, s0 = M0.decompose()
        l1, q1, s1 = M1.decompose()
        s_ = s0.lerp(s1, t)
        return Matrix.Translation(l0.lerp(l1, t)) @ q0.slerp(q1, t).to_matrix().to_4x4() @ Matrix.Diagonal((s_.x, s_.y, s_.z, 1.0))

    if mode in ("blender", "both"):
        bad = 0
        for f in range(A, B + 1):
            for k in range(steps if f < B else 1):
                sc.frame_set(f, subframe=k / float(steps))
                bpy.context.view_layer.update()
                c = _report(cut_polys(arm, gun, meshes, klass, cuff), klass, dombone, bones)
                if c:
                    bad += 1
                    print(f"[gun_cuts] blender {f + k / float(steps):6.2f}: {c}")
        print(f"[gun_cuts] blender: {bad} cutting samples of {(B - A) * steps + 1}")
    for fix in ([False] if mode == "game" else [True] if mode == "gamefix" else [False, True] if mode == "both" else []):
        bad, n = 0, (B - A) * steps
        label = "gamefix" if fix else "game"
        for i in range(n + 1):
            p = wt(A) + (wt(B) - wt(A)) * i / float(n)
            gp = game_pose(p)
            if gp is None:
                continue
            f0, f1, t, eased = gp
            Fl = first + (eased if fix else p) * (last - first)
            fi = min(int(math.floor(Fl)), last)
            fj = min(fi + 1, last)
            u = Fl - fi
            sc.frame_set(fi)
            bpy.context.view_layer.update()
            for b in pb:
                q0, q1 = rots[f0][b.name], rots[f1][b.name]
                if q0.dot(q1) < 0.0:
                    q1 = -q1
                b.rotation_quaternion = q0.slerp(q1, t)
            pb[P + "Hips"].location = hips[f0].lerp(hips[f1], t)
            for kb, v0, v1 in zip(kbs, morph[fi], morph[fj]):
                kb.value = v0 + (v1 - v0) * u
            bpy.context.view_layer.update()
            gun.hide_viewport = not vis[fi]
            if vis[fi]:
                gun.matrix_world = arm.matrix_world @ pb[gun.parent_bone].matrix @ blend_m(inhand[fi], inhand[fj], u)
                bpy.context.view_layer.update()
            c = _report(cut_polys(arm, gun, meshes, klass, cuff), klass, dombone, bones)
            if c:
                bad += 1
                print(f"[gun_cuts] {label:7s} {Fl:6.2f} (body at {first + eased * (last - first):6.2f}, {f0}->{f1} {t:.2f}): {c}")
        print(f"[gun_cuts] {label}: {bad} cutting samples of {n + 1}")


def still(path, out, frames, views, size, dist=1.4, cuff=0.06):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tripo"))
    import tripo_pose_lab as T
    sc, arm, gun, meshes = _open(path)
    klass, _db = _classes(meshes)

    def flat(name, rgb, glow):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes.get("Principled BSDF")
        p.inputs["Base Color"].default_value = (*rgb, 1.0)
        p.inputs["Emission Color"].default_value = (*rgb, 1.0)
        p.inputs["Emission Strength"].default_value = glow
        p.inputs["Roughness"].default_value = 0.6
        return m

    orange, red = flat("cut_gun", (1.0, 0.33, 0.0), 0.35), flat("cut_red", (1.0, 0.0, 0.0), 1.5)
    for slot in gun.material_slots:
        slot.material = orange
    if not gun.material_slots:
        gun.data.materials.append(orange)
    red_slot, base_idx = {}, {}
    for o in meshes:
        o.data.materials.append(red)
        red_slot[o.name] = len(o.data.materials) - 1
        base_idx[o.name] = [p.material_index for p in o.data.polygons]
    cam = T._render_scene(sc, size)
    cam.data.lens = 85.0
    for fr in frames:
        f = int(fr)
        sc.frame_set(f, subframe=fr - f)
        bpy.context.view_layer.update()
        cut = cut_polys(arm, gun, meshes, klass, cuff)
        for name, polys in cut.items():
            o = bpy.data.objects[name]
            for oi in polys:
                o.data.polygons[oi].material_index = red_slot[name]
            o.data.update()
        bpy.context.view_layer.update()
        target = arm.matrix_world @ arm.pose.bones[P + "Spine1"].head
        for n, (az, el) in enumerate(views):
            T._aim_camera(cam, target, az, el, dist)
            sc.render.filepath = f"{out}_{fr:05.2f}_{n}.png"
            bpy.ops.render.render(write_still=True)
        for name in cut:
            o = bpy.data.objects[name]
            for p, i in zip(o.data.polygons, base_idx[name]):
                p.material_index = i
            o.data.update()
        print(f"[gun_cuts] still {fr}: painted {({k: len(v) for k, v in cut.items()}) or 'nothing'}")


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not a:
        fail("usage: -- scan <SEQ> <first> <last> [steps] [cuff cm] [blender|game|gamefix|both] [bones] | still <SEQ> <prefix> <frames> <az:el,...> <px> [dist] [cuff cm]")
    if a[0] == "scan":
        scan(a[1], int(a[2]), int(a[3]), int(a[4]) if len(a) > 4 else 4, (float(a[5]) if len(a) > 5 else 6.0) / 100.0,
             a[6] if len(a) > 6 else "both", len(a) > 7 and a[7] == "bones")
    elif a[0] == "still":
        still(a[1], a[2], [float(x) for x in a[3].split(",")], [tuple(float(v) for v in x.split(":")) for x in a[4].split(",")], int(a[5]),
              float(a[6]) if len(a) > 6 else 1.4, (float(a[7]) if len(a) > 7 else 6.0) / 100.0)
    else:
        fail(f"unknown command {a[0]}")


if __name__ == "__main__":
    main()
