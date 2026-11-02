# tripo_coat_weld.py — the coat's loose pieces are WELDED to its surface (ACTOR D91, 2026-11-02, Director: "mesclar com o casaco ... tampa de bolso, forro, tudo que estiver saindo da superfície"; a TEST, behind COAT_WELD
# in build_agents.sh). The coat holds 9-13 islands apart from its main surface (buttons, pocket flaps, cuff tabs, belt tabs, the pieces at the hips). Each carried the skin weights of the nearest vertex of the
# generation's own coat, where the hand rests by the pocket: they hung free in a run, dragged by the forearm (the black bits under the arm). Here each vertex of such an island takes the weights of the
# point of the MAIN surface nearest to it (the three vertices of that triangle, barycentric), as the dress already sews the lining: the piece rides the surface it sits on, offset and all. The geometry
# (the relief) is not touched. Run on the coat as finished (after tripo_coat_back_out): the weights are final.
# Env: WELD_IN, WELD_OUT.  Usage: blender -b -P tripo_coat_weld.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
import tripo_common as tc

TAG = "tripo_coat_weld"
arm, P, B, meshes = tc.load(TAG, os.environ["WELD_IN"])
coat = bpy.data.objects.get("Outfit_Coat")
if coat is None or not coat.vertex_groups:
    tc.fail(TAG, "no skinned Outfit_Coat")
V = tc.world_verts(coat); W = tc.read_weights(coat); me = coat.data
key = {}; rep = np.zeros(len(V), int)
for i, q in enumerate(np.round(V / 1e-5).astype(np.int64)):
    rep[i] = key.setdefault(tuple(q), i)
par = list(range(len(V)))
def find(a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a
for e in me.edges:
    a, b = find(rep[e.vertices[0]]), find(rep[e.vertices[1]])
    if a != b:
        par[a] = b
size = {}
for p in me.polygons:
    r = find(rep[p.vertices[0]]); size[r] = size.get(r, 0) + 1
main = max(size, key=size.get)
tris = [tuple(t.vertices) for t in me.loop_triangles if find(rep[me.polygons[t.polygon_index].vertices[0]]) == main]
bvh = BVHTree.FromPolygons([tuple(q) for q in V], tris)
armw = lambda w: sum(x for n, x in w.items() if any(t in n for t in ("Shoulder", "Arm", "Hand")))
loose = [i for i in range(len(V)) if find(rep[i]) != main]
arm_before = np.mean([armw(W[i]) for i in loose]) if loose else 0.0
moved = 0
for i in loose:
    loc, nrm, fi, d = bvh.find_nearest(Vector(V[i]))
    a, b, c = tris[fi]
    bc = np.clip(np.array(barycentric_transform(loc, Vector(V[a]), Vector(V[b]), Vector(V[c]), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))[:]), 0, None)
    bc = bc / max(bc.sum(), 1e-9); mix = {}
    for k, vi in zip(bc, (a, b, c)):
        for n, x in W[vi].items():
            mix[n] = mix.get(n, 0.0) + float(k) * x
    W[i] = tc.top4(mix, P + "Hips"); moved += 1
tc.write_weights(coat, W)
arm_after = np.mean([armw(W[i]) for i in loose]) if loose else 0.0
print(f"[{TAG}] {len(size) - 1} loose islands, {moved} vertices re-bound to the main surface; mean arm weight of those vertices {arm_before:.3f} -> {arm_after:.3f}")
tc.export(os.environ["WELD_OUT"], meshes, arm)
