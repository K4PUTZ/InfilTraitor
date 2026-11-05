# tripo_transition.py — the A <-> T transition on the frozen base (ACTOR D99): the hand-finished A and T have different topologies, so the T's mesh carries both.
# A piece with the same mesh in both files maps vertex by vertex. Every skinned piece keeps the T file's topology, weights and UVs. With M_v the vertex's a_to_t skin (tripo_fit_from_tpose.py), p = M_v^-1 p_T is the T vertex taken back to the A rest:
#   key TFix = p (value 1 reproduces the T exactly under the posed armature); Basis = the closest point to p on the same piece of the A file (value 0 lies on the A's surface).
# The armature is the A file's. s in [0, 1] slerps each bone from rest to its a_to_t pose and drives TFix: the frozen files are only read.
# Env: TR_A, TR_T (the base .blend files), TR_OUT (the .blend to write), TR_FRAMES (optional: an output prefix; renders TR_N stills from s=0 to 1), TR_VIEW (azimuth degrees, default 25).
# Usage: blender -b -P tripo_transition.py
import json, math, os
import numpy as np
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_transition"
A_PATH, T_PATH = os.path.abspath(os.environ["TR_A"]), os.path.abspath(os.environ["TR_T"])
OUT = os.path.abspath(os.environ["TR_OUT"])
COLOURS = {'Body_Hair': (.25, .13, .05), 'Body_Hands': (.95, .65, .5), 'Body_Head': (.95, .65, .5), 'Outfit_Belt': (.9, .75, .05), 'Outfit_Buckle': (.9, .05, .8),
           'Outfit_Shirt': (.95, .95, .95), 'Outfit_Shoes': (.08, .08, .08), 'Outfit_Tie': (.85, .05, .05), 'Outfit_Trousers': (.05, .2, .8), 'Outfit_Coat.001': (.1, .65, .25)}


def skinned(o):
    return o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)


# 1. the A file: each piece's evaluated surface, in world space
bpy.ops.wm.open_mainfile(filepath=A_PATH)
dg = bpy.context.evaluated_depsgraph_get()
surf = {}
for o in bpy.data.objects:
    if skinned(o):
        e = o.evaluated_get(dg)
        m = e.to_mesh()
        mw = o.matrix_world
        uv = m.uv_layers.active.data if m.uv_layers.active else None
        surf[o.name] = ([tuple(mw @ v.co) for v in m.vertices], [tuple(p.vertices) for p in m.polygons],
                        np.array([uv[l.index].uv[:] for l in m.loops]) if uv else None, np.array([l.vertex_index for l in m.loops]))
        e.to_mesh_clear()

# 2. the T file, with the A file's armature brought in
bpy.ops.wm.open_mainfile(filepath=T_PATH)
arm_t = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
if "a_to_t" not in arm_t:
    raise SystemExit(f"[{TAG}] {T_PATH}: the armature has no a_to_t")
a_to_t = {n: np.array(v) for n, v in json.loads(arm_t["a_to_t"]).items()}
bones = sorted(a_to_t)
Amat = np.stack([a_to_t[b] for b in bones])
col = {b: k for k, b in enumerate(bones)}
with bpy.data.libraries.load(A_PATH) as (src, dst):
    dst.objects = [n for n in src.objects if n == arm_t.name]
arm = dst.objects[0]
arm.name = "Armature_A"
bpy.context.scene.collection.objects.link(arm)
arm.animation_data_clear()
arm.data.pose_position = 'POSE'
report = []
for o in [x for x in bpy.data.objects if skinned(x)]:
    if o.name not in surf:
        raise SystemExit(f"[{TAG}] {o.name}: not in the A file")
    me = o.data
    if me.shape_keys:
        raise SystemExit(f"[{TAG}] {o.name}: a T piece is baked and carries no shape key")
    names = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(me.vertices), len(bones)))
    for v in me.vertices:
        for g in v.groups:
            k = col.get(names[g.group])
            if k is not None:
                w[v.index, k] = g.weight
    tot = w.sum(1)
    M = np.einsum('nb,bij->nij', w / np.maximum(tot, 1e-12)[:, None], Amat)
    M[tot <= 1e-12] = np.eye(4)
    mw = np.array(o.matrix_world)
    pw = np.array([v.co[:] for v in me.vertices]) @ mw[:3, :3].T + mw[:3, 3]
    back = np.einsum('nij,nj->ni', np.linalg.inv(M), np.c_[pw, np.ones(len(pw))])[:, :3]
    verts, faces, a_uv, a_lv = surf[o.name]
    bvh = BVHTree.FromPolygons(verts, faces)
    # the same mesh in both files (a hand, a shoe): the A's own vertex, since a closest point would collapse the shape onto the wrong side of a finger
    same = faces == [tuple(p.vertices) for p in me.polygons]
    uv_hits = 0
    if same:
        near = np.array(verts)
    elif a_uv is None or not me.uv_layers.active:
        raise SystemExit(f"[{TAG}] {o.name}: the meshes differ and a file has no UVs to match them by")
    else:
        # the welds differ but the UVs survived them: a T vertex is the A vertex with its UV (mirrored islands: the nearest of the candidates); the closest point is the fallback
        grid = {}
        for k, q in zip(a_lv, np.round(a_uv / 2e-5).astype(int)):
            grid.setdefault((int(q[0]), int(q[1])), []).append(int(k))
        vp = np.array(verts)
        t_uv = me.uv_layers.active.data
        cand = [[] for _ in me.vertices]
        for l in me.loops:
            qu, qv = round(t_uv[l.index].uv[0] / 2e-5), round(t_uv[l.index].uv[1] / 2e-5)
            for du in (-1, 0, 1):
                for dv in (-1, 0, 1):
                    cand[l.vertex_index] += grid.get((qu + du, qv + dv), [])
        near = np.zeros_like(back)
        for i, c in enumerate(cand):
            if c:
                c = vp[c]
                near[i] = c[np.argmin(np.linalg.norm(c - back[i], axis=1))]
                uv_hits += 1
            else:
                near[i] = bvh.find_nearest(Vector(back[i]))[0][:]
    d = np.linalg.norm(near - back, axis=1) * 100
    # how much of the A's surface the mapped T covers: a large number is a hole or a fold of the morph
    cover = BVHTree.FromPolygons([tuple(p) for p in near], [tuple(p.vertices) for p in me.polygons])
    c = np.array([(cover.find_nearest(Vector(v))[3] or 0) for v in verts]) * 100
    print(f"[{TAG}] {o.name} uv matches {uv_hits}/{len(pw)}")
    report.append((o.name, len(verts), len(pw), np.median(d), d.max(), np.percentile(c, 99), c.max()))
    inv = np.linalg.inv(mw)
    loc = lambda P: P @ inv[:3, :3].T + inv[:3, 3]
    o.shape_key_add(name="Basis", from_mix=False)
    tfix = o.shape_key_add(name="TFix", from_mix=False)
    bk = me.shape_keys.key_blocks["Basis"]
    nl, bl = loc(near), loc(back)
    bk.data.foreach_set("co", nl.ravel())
    tfix.data.foreach_set("co", bl.ravel())
    me.vertices.foreach_set("co", nl.ravel())
    tfix.value = 0.0
    me.update()
    for m in o.modifiers:
        if m.type == 'ARMATURE':
            m.object = arm
    if o.parent == arm_t:
        o.parent = arm
print(f"[{TAG}] piece: A verts, T verts, T->A cm median/max, A not covered cm p99/max")
for r in report:
    print(f"[{TAG}] {r[0]:16s} {r[1]:5d} {r[2]:5d}  {r[3]:6.2f} {r[4]:6.2f}  {r[5]:6.2f} {r[6]:6.2f}")
bpy.data.objects.remove(arm_t)

# 3. the pose: per bone, the local basis of the T, slerped by s
ROT = {}
for pb in arm.pose.bones:
    if pb.name not in a_to_t:
        continue
    pm = Matrix(a_to_t[pb.name].tolist()) @ pb.bone.matrix_local
    if pb.parent and pb.parent.name in a_to_t:
        parent_pm = Matrix(a_to_t[pb.parent.name].tolist()) @ pb.parent.bone.matrix_local
        basis = (pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local).inverted() @ parent_pm.inverted() @ pm
    else:
        basis = pb.bone.matrix_local.inverted() @ pm
    loc, q, _ = basis.decompose()
    ROT[pb.name] = (loc, q)
    pb.rotation_mode = 'QUATERNION'


def set_s(s):
    for pb in arm.pose.bones:
        if pb.name in ROT:
            loc, q = ROT[pb.name]
            pb.rotation_quaternion = Quaternion().slerp(q, s)
            pb.location = loc * s
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.key_blocks["TFix"].value = s
    bpy.context.view_layer.update()


set_s(0.0)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[{TAG}] wrote {OUT}")

prefix = os.environ.get("TR_FRAMES", "")
if prefix:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'OBJECT'
    sc.render.resolution_x, sc.render.resolution_y = 900, 900
    sc.render.image_settings.file_format = 'PNG'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in COLOURS
            if o.name in COLOURS:
                o.color = (*COLOURS[o.name], 1)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 1.08
    az = math.radians(float(os.environ.get("TR_VIEW", "25")))
    d = Vector((math.sin(az), -math.cos(az), 0))
    cam.location = Vector((0, 0, .5)) + d * 5
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    n = int(os.environ.get("TR_N", "25"))
    for i in range(n):
        t = i / (n - 1)
        set_s(t * t * (3 - 2 * t))
        sc.render.filepath = f"{prefix}{i:03d}.png"
        bpy.ops.render.render(write_still=True)
