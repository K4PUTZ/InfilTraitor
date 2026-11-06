# tripo_lod_base.py — the GAME version of the D99 base (ACTOR D106 step 1, 2026-11-05): every piece of AGENT_<FIG>_A.blend reduced to tripo_lod.py's
# budget, its skin kept (D101 / D104 live in the weights), and the coat's corrective keys (D103) carried onto the reduced mesh.
# Per piece: the shape keys applied at their current values (the coat's `Fit` at 1, the correctives at 0: the look the base shows), welded
# (LOD_WELD) and collapse-decimated to BUDGET, weights re-cut to 4 influences. Per corrective key: each reduced vertex takes the key's displacement
# at its closest point on the FULL surface (barycentric over the FULL triangle it lands on), so the key does on the light mesh what it does on the full.
# Printed per key: the largest displacement on the full and on the light mesh, and the light mesh's worst transfer error, measured back on the
# FULL vertices (each full vertex's displacement against the light surface's displacement at the same closest point).
# The .blend is opened and never saved over. Out: LB_OUT (GLB) and LB_BLEND (the same as a .blend, to look at).
# Env: LB_FIG (female | male), LB_OUT, LB_BLEND, LOD_WELD (default 0.0003), LOD_SCALE (default 1.0).
# Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_lod_base.py
import os, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_lod_base"
FIG = os.environ.get("LB_FIG", "")
if FIG not in ("female", "male"):
    sys.exit(f"[{TAG}] LB_FIG must be female or male")
OUT = os.path.abspath(os.environ.get("LB_OUT", f"temp/work/light_base/{FIG}_light_base.glb"))
BLEND = os.path.abspath(os.environ.get("LB_BLEND", OUT[:-4] + ".blend"))
WELD_DIST = float(os.environ.get("LOD_WELD", "0.0003"))
SCALE = float(os.environ.get("LOD_SCALE", "1.0"))
BUDGET = {"Body_Head": 750, "Body_Hands": 450, "Body_Hair": 600, "Outfit_Coat": 1000, "Outfit_Shirt": 700, "Outfit_Trousers": 600,
          "Outfit_Shoes": 400, "Outfit_Tie": 150, "Outfit_Belt": 250, "Outfit_Buckle": 100}
SKIP = {"Icosphere"}

bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
arm = arms[0]
P = [b.name for b in arm.data.bones if b.name.endswith("Hips")][0][:-4]
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name not in SKIP]
for o in arms + meshes:
    o.hide_set(False); o.hide_viewport = False


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def co(me):
    a = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", a); return a.reshape(-1, 3)


def tri_bvh(V, me):
    me.calc_loop_triangles()
    T = [tuple(t.vertices) for t in me.loop_triangles]
    return BVHTree.FromPolygons([Vector(v) for v in V], T), T


def sample(bvh, T, V, D, pts):
    """the displacement field D (per vertex of V) at the closest surface point of each of `pts`"""
    out = np.zeros((len(pts), 3))
    for i, p in enumerate(pts):
        hit, _, fi, _ = bvh.find_nearest(Vector(p))
        a, b, c = T[fi]
        w = barycentric_transform(hit, Vector(V[a]), Vector(V[b]), Vector(V[c]), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        out[i] = w.x * D[a] + w.y * D[b] + w.z * D[c]
    return out


total = 0
for o in meshes:
    name = o.name.split(".")[0]
    me = o.data
    keys = {}
    if me.shape_keys:
        kb = me.shape_keys.key_blocks
        basis = co(me) * 0
        a = np.empty(len(me.vertices) * 3)
        kb[0].data.foreach_get("co", a); basis = a.reshape(-1, 3).copy()
        mix = basis.copy()
        for k in kb[1:]:
            k.data.foreach_get("co", a)
            d = a.reshape(-1, 3) - basis
            if k.value != 0.0:
                mix += k.value * d
            else:
                keys[k.name] = d.copy()
        full_V, full_me = mix, me.copy()
        full_me.shape_keys and None
    n0 = tris(o)
    bpy.context.view_layer.objects.active = o
    for ob in bpy.data.objects:
        ob.select_set(ob is o)
    if me.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    full_bvh, full_T = (tri_bvh(full_V, o.data) if keys else (None, None))
    target = int(BUDGET.get(name, n0) * SCALE)
    if name in BUDGET and n0 > target:
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD_DIST); bm.to_mesh(o.data); bm.free()
        d = o.modifiers.new("lod", 'DECIMATE'); d.decimate_type = 'COLLAPSE'; d.ratio = target / tris(o); d.use_collapse_triangulate = True
        while o.modifiers[0].name != d.name:
            bpy.ops.object.modifier_move_up(modifier=d.name)
        bpy.ops.object.modifier_apply(modifier=d.name)
        tc.write_weights(o, [tc.top4(w, P + "Hips") for w in tc.read_weights(o)])
    n1 = tris(o); total += n1
    line = f"[{TAG}] {name}: {n0} -> {n1} tris (budget {target})"
    if keys:
        L = co(o.data)
        o.shape_key_add(name="Basis", from_mix=False)
        light_bvh, light_T = tri_bvh(L, o.data)
        for kname, D in keys.items():
            DL = sample(full_bvh, full_T, full_V, D, L)
            sk = o.shape_key_add(name=kname, from_mix=False); sk.value = 0.0
            sk.data.foreach_set("co", (L + DL).ravel())
            back = sample(light_bvh, light_T, L, DL, full_V)
            moved = np.linalg.norm(D, axis=1) > 1e-5
            err = np.linalg.norm(back - D, axis=1)[moved] if moved.any() else np.zeros(1)
            line += (f"\n[{TAG}]   key {kname}: full max {np.linalg.norm(D, axis=1).max()*100:.2f} cm, light max {np.linalg.norm(DL, axis=1).max()*100:.2f} cm, "
                     f"transfer error on the {int(moved.sum())} moved full vertices: median {np.median(err)*100:.2f} cm, worst {err.max()*100:.2f} cm")
    print(line)
print(f"[{TAG}] TOTAL {total} tris (the figure as the base dresses it, no hat yet)")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
tc.export(OUT, meshes, arm)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print(f"[{TAG}] wrote {OUT} and {BLEND}")
