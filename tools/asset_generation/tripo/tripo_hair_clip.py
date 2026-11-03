# tripo_hair_clip.py — keep the hair OUT of the coat (ACTOR D97, 2026-11-03, Director: "é o cabelo vazando pela gola"; the lowest locks at the nape dip into the collar and their tips show on its inner side).
# A hair vertex is INSIDE the coat if most of 8 rays from it cross the coat's surface an odd number of times (the coat is a thin double wall, open at the front and the hem: the vote tolerates that). HC_MODE=cut (default): every hair face with a vertex inside is DELETED, then every island of
# fewer than HC_ISLAND faces that this leaves floating (the tips that had pierced through) goes too: the locks end at the collar. HC_MODE=push moved the inside vertices out to the coat's outer wall instead; measured 2026-11-03 it crumples the locks into a debris of flakes on the collar, so it is NOT the default.
# The coat is never touched. Works on any `.blend` holding `Body_Hair` and `Outfit_Coat*` in the pose to fix (a T file's head is the A's: hair does not move between them).
# Env: HC_IN (.blend), HC_OUT (.blend, default HC_IN), HC_MODE (cut|push), HC_ISLAND (40), HC_AXIS / HC_GAP (push only), HC_ZONE ("0.80,0.95,0.2": z0, z1, |x| max).   Usage: blender -b -P tripo_hair_clip.py
import os
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_hair_clip"
IN = os.path.abspath(os.environ["HC_IN"]); OUT = os.path.abspath(os.environ.get("HC_OUT", IN))
AX = [float(v) for v in os.environ.get("HC_AXIS", "0.0,0.005").split(",")]; GAP = float(os.environ.get("HC_GAP", "0.0015")); PASSES = int(os.environ.get("HC_PASSES", "2"))
Z0, Z1, XM = [float(v) for v in os.environ.get("HC_ZONE", "0.80,0.95,0.2").split(",")]
bpy.ops.wm.open_mainfile(filepath=IN)
dg = bpy.context.evaluated_depsgraph_get()
coat = [o for o in bpy.data.objects if o.name.startswith("Outfit_Coat") and o.type == 'MESH' and not o.hide_viewport][0]
hair = bpy.data.objects["Body_Hair"]
cme = coat.evaluated_get(dg).to_mesh(); cme.calc_loop_triangles()
cv = [coat.matrix_world @ v.co for v in cme.vertices]
bvh = BVHTree.FromPolygons([v[:] for v in cv], [list(t.vertices) for t in cme.loop_triangles])
hme = hair.data                                                    # the rest mesh the armature deforms: the T file bakes the pose into it, so its coordinates are the pose
assert not hair.modifiers or True
mw = hair.matrix_world; mwi = mw.inverted()
DIRS = [Vector(d).normalized() for d in ((0, 0, 1), (0, 0, -1), (0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0), (0.3, 0.5, 0.8), (-0.4, -0.6, 0.7))]


def crossings(p, d):
    n = 0; o = p + d * 1e-5
    while n < 40:
        h = bvh.ray_cast(o, d)
        if h[0] is None:
            return n
        n += 1; o = h[0] + d * 1e-5
    return n


def inside_set():
    out = []
    for i, v in enumerate(hme.vertices):
        p = mw @ v.co
        if not (Z0 < p.z < Z1 and abs(p.x) < XM):
            continue
        if sum(1 for d in DIRS if crossings(p, d) % 2 == 1) >= 5:
            out.append(i)
    return out


MODE = os.environ.get("HC_MODE", "cut"); ISLAND = int(os.environ.get("HC_ISLAND", "40"))
first = inside_set()
print(f"[{TAG}] hair vertices inside the coat before: {len(first)}")
moved_max = 0.0
if MODE == "cut":
    import bmesh
    bm = bmesh.new(); bm.from_mesh(hme); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    ins = set(first)
    kill = [f for f in bm.faces if any(v.index in ins for v in f.verts)]
    nfaces = len(bm.faces)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.faces.ensure_lookup_table()
    seen_f = set(); small = []
    for f0 in bm.faces:
        if f0.index in seen_f:
            continue
        comp = []; st = [f0]; seen_f.add(f0.index)
        while st:
            f = st.pop(); comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen_f:
                        seen_f.add(g.index); st.append(g)
        if len(comp) < ISLAND:
            small += comp
    # islands are linked by edges; tips pierced through share no edge with the lock they belong to once its inside faces are gone
    bmesh.ops.delete(bm, geom=small, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    print(f"[{TAG}] cut: {len(kill)} faces with a vertex inside, {len(small)} floating faces; hair {nfaces} -> {len(bm.faces)} faces")
    bm.to_mesh(hme); bm.free(); hme.update()
    PASSES = 0
for k in range(PASSES):
    ins = first if k == 0 else inside_set()
    if not ins:
        break
    for i in ins:
        p = mw @ hme.vertices[i].co
        d = Vector((p.x - AX[0], p.y - AX[1], 0.0))
        d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
        o = p; last = None
        for _ in range(8):                                         # walk out through every layer of the wall along d
            h = bvh.ray_cast(o + d * 1e-5, d)
            if h[0] is None:
                break
            last = h[0]; o = h[0]
        if last is None:
            continue
        q = last + d * GAP
        moved_max = max(moved_max, (q - p).length)
        hme.vertices[i].co = mwi @ q
    hme.update()
after = inside_set()
print(f"[{TAG}] after {PASSES} pass(es): {len(after)} inside; largest move {moved_max * 1000:.1f} mm")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[{TAG}] wrote {OUT}")
