# tripo_head_fuse.py — the female's head with the Director's skull top (2026-11-05, ACTOR D106), second way: FUSE for the skull, then paste her face back.
# tripo_head_join.py bridged the cap's border to her hole and left a groove a smoothing could not save. Here:
#   1. her head and the cap (given HF_THICK of thickness) are fused into one volume by a voxel remesh (HF_VOXEL), then decimated to HF_RATIO:
#      the skull is one smooth surface, no seam;
#   2. her ORIGINAL faces are kept wherever her head exists (all but the flat lid / slanted back, the faces lying deeper than HF_NEAR under the cap);
#   3. the fused surface keeps only what lies farther than HF_GAP from those faces, its border vertices are snapped onto her border's nearest vertex,
#      welded, the degenerate faces dissolved and the small holes left filled.
# The pasted face keeps its weights and UVs; the fused skull takes the weights of her nearest original vertex (its UVs are redone by tripo_head_map).
# Reads the Director's ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend (never saved over); writes HF_OUT (default ASSETS/MODELS/fit/HEAD_FUSED_FEMALE.blend).
# Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_head_fuse.py
import os, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

TAG = "tripo_head_fuse"
SRC = os.path.abspath("ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend")
OUT = os.path.abspath(os.environ.get("HF_OUT", "ASSETS/MODELS/fit/HEAD_FUSED_FEMALE.blend"))
THICK = float(os.environ.get("HF_THICK", "0.004"))
VOXEL = float(os.environ.get("HF_VOXEL", "0.0015"))
RATIO = float(os.environ.get("HF_RATIO", "0.05"))
NEAR = float(os.environ.get("HF_NEAR", "0.008"))
GAP = float(os.environ.get("HF_GAP", "0.0015"))
CUT_Z = float(os.environ.get("HF_CUT_Z", "0.90"))   # world height: her original face is kept only BELOW it (the fused skull is her own surface there too)
HOLE = int(os.environ.get("HF_HOLE", "12"))     # holes up to this many edges are filled

bpy.ops.wm.open_mainfile(filepath=SRC)
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
head = bpy.data.objects["Body_Head"]; cap = bpy.data.objects["Body_Head_Male"]
inv = head.matrix_world.inverted()


def sel(o):
    for x in bpy.data.objects:
        x.select_set(x is o)
    bpy.context.view_layer.objects.active = o


# 1. the fused volume, built in the head's local space on a scratch object
fuse = bpy.data.objects.new("fuse", bpy.data.meshes.new("fuse")); bpy.context.scene.collection.objects.link(fuse)
fb = bmesh.new(); fb.from_mesh(head.data)
cb = bmesh.new(); cb.from_mesh(cap.data); cb.transform(inv @ cap.matrix_world)
ctree = BVHTree.FromBMesh(cb)
tmp = bpy.data.meshes.new("cap_tmp"); cb.to_mesh(tmp); fb.from_mesh(tmp)    # (solidified below on the whole; the head is closed, so only the cap thickens)
fb.to_mesh(fuse.data); fb.free()
sel(fuse)
s = fuse.modifiers.new("s", 'SOLIDIFY'); s.thickness = THICK; s.offset = -1.0
bpy.ops.object.modifier_apply(modifier="s")
fuse.data.remesh_voxel_size = VOXEL; bpy.ops.object.voxel_remesh()
d = fuse.modifiers.new("d", 'DECIMATE'); d.ratio = RATIO
bpy.ops.object.modifier_apply(modifier="d")
fused_faces = len(fuse.data.polygons)

# 2. her original head, the lid removed
bm = bmesh.new(); bm.from_mesh(head.data)
C = sum((v.co for v in cb.verts), Vector()) / len(cb.verts); C.z -= 0.06


def under(v):
    dd = v.co - C
    hit = ctree.ray_cast(C, dd.normalized(), 1.0)
    return hit[0] is not None and (hit[0] - C).length > dd.length + 0.0005


mwh = head.matrix_world
flag = {v: (under(v) and ctree.find_nearest(v.co)[3] > NEAR) or (mwh @ v.co).z > CUT_Z for v in bm.verts}
gone = [f for f in bm.faces if any(flag[v] for v in f.verts)]
bmesh.ops.delete(bm, geom=gone, context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
cb.free(); bpy.data.meshes.remove(tmp)
smooth = all(f.smooth for f in bm.faces)
ktree = BVHTree.FromBMesh(bm)
border = [v for v in bm.verts if v.is_boundary]
kb = KDTree(len(border))
for i, v in enumerate(border):
    kb.insert(v.co, i)
kb.balance()
deform = bm.verts.layers.deform.verify()
live = [v for v in bm.verts]
kl = KDTree(len(live))
for i, v in enumerate(live):
    kl.insert(v.co, i)
kl.balance()

# 3. the fused skull: only what stands off her kept faces, pasted in and welded to her border
sb = bmesh.new(); sb.from_mesh(fuse.data)
drop = [f for f in sb.faces if ktree.find_nearest(f.calc_center_median())[3] < GAP]
bmesh.ops.delete(sb, geom=drop, context='FACES_ONLY')
bmesh.ops.delete(sb, geom=[v for v in sb.verts if not v.link_faces], context='VERTS')
vmap = {}
for v in sb.verts:
    nv = bm.verts.new(v.co)
    src = live[kl.find(v.co)[1]]
    for g, w in src[deform].items():
        nv[deform][g] = w
    vmap[v] = nv
for f in sb.faces:
    try:
        nf = bm.faces.new([vmap[v] for v in f.verts]); nf.smooth = smooth
    except ValueError:
        pass
snapped = 0
for v in sb.verts:
    if v.is_boundary:
        co, i, dist = kb.find(v.co)
        vmap[v].co = border[i].co.copy(); snapped += 1
sb.free()
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context='EDGES')
bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=HOLE)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
open_left = sum(1 for e in bm.edges if e.is_boundary)
nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
bm.to_mesh(head.data); bm.free(); head.data.update()
for p in head.data.polygons:
    p.use_smooth = smooth
bpy.data.objects.remove(fuse); bpy.data.objects.remove(cap)
print(f"[{TAG}] fused skull {fused_faces} faces; her lid faces removed {len(gone)}; border verts snapped {snapped}; "
      f"open edges left {open_left}; non-manifold edges {nonman}; head now {len(head.data.vertices)} verts, {len(head.data.polygons)} faces -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
