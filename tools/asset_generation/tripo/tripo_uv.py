# tripo_uv.py — CLEAN UVs for a figure's garments (ACTOR D87 T3, D89): Tripo's UVs keep one texel density but are shattered into hundreds of
# islands at random angles (measured 2026-10-31 on both official bases: shirt 434 / 799 islands, trousers 591 / 296, the head 224 / 586), fine
# for one baked texture and useless for a TILED detail or a PRINT, which need few islands, upright, at one scale.
# Per garment (a tripo_assemble output: one mesh per slot):
# (1) WELD the GLB's split vertices (glTF splits at every UV seam and hard edge), keeping Tripo's per-corner normals (they are good, D87:
#     recomputed they come out faceted) by re-applying each corner's normal after the weld;
# (2) PARTS by skin weights: each vertex's dominant bone family (torso, upper arm, forearm, thigh, shin, foot; L / R), each face the majority of
#     its corners, smoothed PART_SMOOTH times (default 8) over its neighbours; a seam between parts (the armhole, the elbow line on a sleeve, the knee on a leg);
# (3) ONE CUT per part where it shows least: a torso-like part (the torso, the tie, the belt, a foot) splits front / back at its SIDES (a face's
#     angle about the part's own vertical axis); a limb splits along its INNER line (the angle about the bone, 180 deg from the outside, +X on
#     the left side, the figure facing -Y); a shoe's sole (faces looking down) is an island of its own;
# (4) Blender's conformal unwrap on those seams, every island turned so world Z is UV up (align_rotation GEOMETRY), one scale for every island
#     (average_islands_scale), packed without rotation. The UVs replace `UVMap` (Tripo's maps are not shipped, D87 (4)).
# Head, hands and hair keep Tripo's UVs: the head gets a painted map of its own (D87 (3)), hands and hair a plain detail.
# (5) Limbs (sleeves, trouser legs) take a cylindrical map about their bone instead of the conformal one (see the code).
# Out: the same GLB with new UVs. RV_OUT: uv_front.png / uv_back.png, a numbered grid on every piece. Prints per piece: islands, the texel
# density's p90 / p10 spread.
# Env: UV_IN, UV_OUT, RV_OUT (optional). Usage: blender -b -P tripo_uv.py
import math, os, sys
from collections import Counter
import numpy as np
import bpy, bmesh
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_uv"
IN, OUT = os.environ["UV_IN"], os.environ["UV_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
GARMENTS = ("Outfit_Shirt", "Outfit_Trousers", "Outfit_Tie", "Outfit_Shoes", "Outfit_Belt", "Outfit_Buckle")
LIMB_AXIS = {"uarm": ("Arm", "ForeArm"), "farm": ("ForeArm", "Hand"), "thigh": ("UpLeg", "Leg"), "shin": ("Leg", "Foot")}

arm, P, B, meshes = tc.load(TAG, IN)
H = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in meshes)
M = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == 'MESH'}


def family(bone):
    n = bone[len(P):] if bone.startswith(P) else bone
    side = "L" if n.startswith("Left") else "R" if n.startswith("Right") else ""
    n = n[4:] if side == "L" else n[5:] if side == "R" else n
    if n == "Arm":
        return "uarm" + side
    if n.startswith("ForeArm") or n.startswith("Hand"):
        return "farm" + side
    if n == "UpLeg":
        return "thigh" + side
    if n == "Leg":
        return "shin" + side
    if n.startswith("Foot") or n.startswith("Toe"):
        return "foot" + side
    return "torso"


def bone_head(n):
    return arm.matrix_world @ arm.data.bones[P + n].head_local


def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def uv_stats(me):
    bm = bmesh.new(); bm.from_mesh(me); uv = bm.loops.layers.uv.active; r = []
    for f in bm.faces:
        p = [l[uv].uv for l in f.loops]; au = sum(abs((p[i] - p[0]).cross(p[i + 1] - p[0])) / 2 for i in range(1, len(p) - 1))
        if f.calc_area() > 1e-12 and au > 1e-12:
            r.append(math.sqrt(au / f.calc_area()))
    # islands: faces joined across an edge whose two corners carry the same UVs
    seen, isl = set(), 0
    for f in bm.faces:
        if f.index in seen:
            continue
        isl += 1; st = [f]; seen.add(f.index)
        while st:
            g = st.pop()
            for lg in g.loops:
                for lh in lg.edge.link_loops:
                    h = lh.face
                    if h.index in seen or h is g:
                        continue
                    if (lg[uv].uv - lh.link_loop_next[uv].uv).length < 1e-5 and (lg.link_loop_next[uv].uv - lh[uv].uv).length < 1e-5:
                        seen.add(h.index); st.append(h)
    r = np.array(r); bm.free()
    return isl, float(np.percentile(r, 90) / max(np.percentile(r, 10), 1e-9))


for name in GARMENTS:
    o = M.get(name)
    if o is None:
        print(f"[{TAG}] {name}: not in the file, skipped"); continue
    me = o.data
    before = uv_stats(me) if me.uv_layers else (0, 0.0)
    # (1) the corners' normals, keyed by position and face centre, to survive the weld
    me.calc_loop_triangles() if hasattr(me, "calc_loop_triangles") else None
    key = lambda p, c: (round(p.x, 5), round(p.y, 5), round(p.z, 5), round(c.x, 4), round(c.y, 4), round(c.z, 4))
    cn = {}
    for poly in me.polygons:
        c = poly.center
        for li in poly.loop_indices:
            cn[key(me.vertices[me.loops[li].vertex_index].co, c)] = Vector(me.corner_normals[li].vector) if hasattr(me, "corner_normals") else Vector(me.loops[li].normal)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5 * H)
    dl = bm.verts.layers.deform.active; names = {i: g.name for i, g in enumerate(o.vertex_groups)}
    vfam = {}
    for v in bm.verts:
        w = Counter()
        if dl is not None:
            for gi, wt in v[dl].items():
                w[family(names[gi])] += wt
        vfam[v.index] = w.most_common(1)[0][0] if w else "torso"
    bm.faces.ensure_lookup_table()
    part = {f.index: Counter(vfam[v.index] for v in f.verts).most_common(1)[0][0] for f in bm.faces}
    for _ in range(int(os.environ.get("PART_SMOOTH", "8"))):   # smooth the part map over the faces' neighbours (a zigzag seam otherwise)
        nxt = {}
        for f in bm.faces:
            c = Counter(part[g.index] for e in f.edges for g in e.link_faces); nxt[f.index] = c.most_common(1)[0][0]
        part = nxt
    if name in ("Outfit_Tie", "Outfit_Belt", "Outfit_Buckle"):
        part = {i: "torso" for i in part}                 # one piece about one axis
    # (3) each face's angle: about the part's vertical axis (torso-like) or about its bone (limbs)
    cen = {}
    for f in bm.faces:
        cen.setdefault(part[f.index], []).append(f.calc_center_median())
    axis_c = {p: sum(v, Vector()) / len(v) for p, v in cen.items()}
    ang, limb = {}, {}
    for f in bm.faces:
        p = part[f.index]; c = f.calc_center_median(); kind = p.rstrip("LR")
        if kind in LIMB_AXIS:
            side = p[-1]; a0, a1 = LIMB_AXIS[kind]
            h0 = bone_head(("Left" if side == "L" else "Right") + a0); h1 = bone_head(("Left" if side == "L" else "Right") + a1)
            ax = (h1 - h0).normalized(); d = c - h0; d -= ax * d.dot(ax)
            out = Vector((1 if side == "L" else -1, 0, 0)); out -= ax * out.dot(ax); out.normalize(); up = ax.cross(out)
            ang[f.index] = ("limb", math.atan2(d.dot(up), d.dot(out))); limb[f.index] = (p, h0, ax, out, up)
        else:
            d = c - axis_c[p]
            ang[f.index] = ("torso", math.atan2(d.x, -d.y))     # 0 = the front
    n_seam = 0
    for e in bm.edges:
        lf = e.link_faces
        if len(lf) != 2:
            continue
        f, g = lf
        cut = part[f.index] != part[g.index]
        if not cut:
            kind, a = ang[f.index]; b = ang[g.index][1]
            if kind == "torso":
                cut = (abs(a) < math.pi / 2) != (abs(b) < math.pi / 2)        # front / back meet at the sides
            else:
                cut = abs(a) > math.pi / 2 and abs(b) > math.pi / 2 and a * b < 0   # crossing the inner line (+-180)
            if not cut and name == "Outfit_Shoes":
                cut = (f.normal.z < -0.6) != (g.normal.z < -0.6)               # the sole
        e.seam = cut; n_seam += cut
    bm.to_mesh(me); bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    # Tripo's corner normals back on
    nl = []
    for poly in me.polygons:
        c = poly.center
        for li in poly.loop_indices:
            nl.append(cn.get(key(me.vertices[me.loops[li].vertex_index].co, c), Vector(poly.normal)))
    me.normals_split_custom_set(nl)
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    # (4) unwrap on the seams, upright, one scale, packed
    for x in bpy.data.objects:
        x.select_set(x is o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.unwrap(method='CONFORMAL', margin=0.003)
    bpy.ops.uv.align_rotation(method='GEOMETRY', axis='Z')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=False, margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    # (5) a limb is a TUBE: the conformal unwrap wrinkles it (the female's sleeves: density 0.12x to 1.9x of the median, 2026-10-31), so its
    # faces take a CYLINDRICAL map instead: u = the angle about the bone x the part's mean radius, v = the distance along the bone (world
    # units, so every tube keeps the scale of its surface); each corner's angle unwrapped about its face's own, so the inner-line cut stays a
    # clean edge. Then one scale for every island again and a new pack.
    if limb:
        mw = o.matrix_world; bm = bmesh.new(); bm.from_mesh(me); uv = bm.loops.layers.uv.active; bm.faces.ensure_lookup_table()
        rad = {}
        for fi, (p, h0, ax, out, up) in limb.items():
            for v in bm.faces[fi].verts:
                d = mw @ v.co - h0; rad.setdefault(p, []).append((d - ax * d.dot(ax)).length)
        rad = {p: sum(r) / len(r) for p, r in rad.items()}
        for fi, (p, h0, ax, out, up) in limb.items():
            f = bm.faces[fi]; ac = ang[fi][1]
            for l in f.loops:
                d = mw @ l.vert.co - h0; t = d.dot(ax); r = d - ax * t
                a = ac + wrap(math.atan2(r.dot(up), r.dot(out)) - ac)
                l[uv].uv = (a * rad[p], -t)
        # a print must not read mirrored: where a part's UV winding runs against its faces' (signed UV area < 0), its u is flipped
        area = {}
        for fi, (p, *_r) in limb.items():
            q = [l[uv].uv for l in bm.faces[fi].loops]
            area[p] = area.get(p, 0.0) + sum((q[i] - q[0]).cross(q[i + 1] - q[0]) for i in range(1, len(q) - 1))
        for fi, (p, *_r) in limb.items():
            if area[p] < 0:
                for l in bm.faces[fi].loops:
                    l[uv].uv = (-l[uv].uv.x, l[uv].uv.y)
        bm.to_mesh(me); bm.free()
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.select_all(action='SELECT')
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=False, margin=0.004)
        bpy.ops.object.mode_set(mode='OBJECT')
    after = uv_stats(me)
    print(f"[{TAG}] {name}: {n_seam} seam edges; islands {before[0]} -> {after[0]}, density spread {before[1]:.2f}x -> {after[1]:.2f}x")

if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    img = bpy.data.images.new("grid", 1024, 1024); img.generated_type = 'COLOR_GRID'
    for o in meshes:
        m = bpy.data.materials.new("g"); n = m.node_tree.nodes; t = n.new("ShaderNodeTexImage"); t.image = img
        m.node_tree.links.new(t.outputs[0], n["Principled BSDF"].inputs["Base Color"]); o.data.materials.clear(); o.data.materials.append(m)
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("w"); sc.world = w; w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.5, 1)
    lt = bpy.data.lights.new("k", 'SUN'); lt.energy = 2; lo = bpy.data.objects.new("k", lt); sc.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(40), 0, math.radians(20))
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.startswith("Icosphere"):
            o.hide_render = True
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = 500, 700
    for az, nm in ((0, "front"), (180, "back")):
        for z, scale, sfx in ((0.5, 1.1, ""), (0.72, 0.5, "_up")):
            co.location = Vector((0, -10 if az == 0 else 10, z * H)); co.rotation_euler = (math.radians(90), 0, 0 if az == 0 else math.pi)
            cam.ortho_scale = scale * H; sc.render.filepath = f"{RV_OUT}/uv_{nm}{sfx}.png"; bpy.ops.render.render(write_still=True)
    # the materials were for the review only
    for o in meshes:
        o.data.materials.clear()
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {OUT}")
