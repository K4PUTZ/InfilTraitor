# tripo_head_join.py — the Director's skull top (2026-11-05) joined into the female's head as ONE mesh (ACTOR D106).
# In ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend he cut the male's head down to a cap and seated it over her flat skull (`Body_Head_Male`, a free mesh
# with one open border lying 0-6 mm off her surface). Here: her faces wholly under the cap go, the hole's border is bridged to the cap's border,
# the cap takes her shading and, per vertex, the weights of her nearest head vertex (so it follows the head bone exactly as the skull did).
# The UVs of the cap are the male's; the head's texture map is redone later by tripo_head_map. Printed: faces removed, bridge result, open edges left.
# Reads the Director's file (never saved over); writes HJ_OUT (default ASSETS/MODELS/fit/HEAD_JOINED_FEMALE.blend), the base with the joined head.
# Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_head_join.py
import os, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

TAG = "tripo_head_join"
SRC = os.path.abspath("ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend")
OUT = os.path.abspath(os.environ.get("HJ_OUT", "ASSETS/MODELS/fit/HEAD_JOINED_FEMALE.blend"))
EPS = 0.0005
NEAR = float(os.environ.get("HJ_NEAR", "0.008"))   # closer than this to the other surface = the original head is already there

bpy.ops.wm.open_mainfile(filepath=SRC)
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
head = bpy.data.objects["Body_Head"]; cap = bpy.data.objects["Body_Head_Male"]
inv = head.matrix_world.inverted()

# the cap in the head's local space, its BVH for the "under the cap" test
cb = bmesh.new(); cb.from_mesh(cap.data); cb.transform(inv @ cap.matrix_world)
ctree = BVHTree.FromBMesh(cb)
bm = bmesh.new(); bm.from_mesh(head.data)
src_verts = list(bm.verts)
C = sum((v.co for v in cb.verts), Vector()) / len(cb.verts); C.z -= 0.06   # inside the skull, under the cap


def under(v):
    d = v.co - C
    hit = ctree.ray_cast(C, d.normalized(), 1.0)
    return hit[0] is not None and (hit[0] - C).length > d.length + EPS


# the original head wins wherever it exists: only her faces lying deep under the cap (the flat lid, the slanted back) go,
# and only the cap faces standing off her ORIGINAL surface are kept (the cap over her forehead, temples and cheeks goes)
htree = BVHTree.FromBMesh(bm)
flag = {v: under(v) and ctree.find_nearest(v.co)[3] > NEAR for v in bm.verts}
gone = [f for f in bm.faces if all(flag[v] for v in f.verts)]
far = {v: htree.find_nearest(v.co)[3] > NEAR for v in cb.verts}
cap_drop = [f for f in cb.faces if not any(far[v] for v in f.verts)]
bmesh.ops.delete(cb, geom=cap_drop, context='FACES_ONLY')
bmesh.ops.delete(cb, geom=[v for v in cb.verts if not v.link_faces], context='VERTS')
bmesh.ops.delete(bm, geom=gone, context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
smooth = all(f.smooth for f in bm.faces)

# weights from her nearest remaining vertex
deform = bm.verts.layers.deform.verify()
kd = KDTree(len(bm.verts)); live = list(bm.verts)
for i, v in enumerate(live):
    kd.insert(v.co, i)
kd.balance()
uv_h = bm.loops.layers.uv.active
uv_c = cb.loops.layers.uv.active
vmap = {}
for v in cb.verts:
    nv = bm.verts.new(v.co)
    _, i, _ = kd.find(v.co)
    nv[deform].clear()
    for g, w in live[i][deform].items():
        nv[deform][g] = w
    vmap[v] = nv
bm.verts.ensure_lookup_table()
new_faces = []
for f in cb.faces:
    nf = bm.faces.new([vmap[v] for v in f.verts]); nf.smooth = smooth; new_faces.append(nf)
    if uv_h is not None and uv_c is not None:
        for l, lc in zip(nf.loops, f.loops):
            l[uv_h].uv = lc[uv_c].uv
cb.free()

border = [e for e in bm.edges if e.is_boundary]
res = bmesh.ops.bridge_loops(bm, edges=border)
for f in res["faces"]:
    f.smooth = smooth
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
open_left = sum(1 for e in bm.edges if e.is_boundary)
bm.to_mesh(head.data); bm.free(); head.data.update()
bpy.data.objects.remove(cap)
print(f"[{TAG}] her faces under the cap removed: {len(gone)}; cap faces over her own head dropped: {len(cap_drop)}; cap faces added: {len(new_faces)}; bridge faces: {len(res['faces'])}; "
      f"open edges left: {open_left}; head now {len(head.data.vertices)} verts, {len(head.data.polygons)} faces -> {OUT}")
if open_left:
    sys.exit(f"[{TAG}] the head is not closed")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
