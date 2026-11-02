# tripo_coat_merge.py — the coat's loose pieces are MERGED into its surface, their shapes kept as a DRAWING (ACTOR D91, 2026-11-02, Director: "vamos experimentar com merge, usando a textura pra indicar os aviamentos"; a TEST,
# behind COAT_MERGE in build_agents.sh). The coat holds 9-13 islands apart from its main surface (buttons, pocket flaps, cuff tabs, belt tabs, pieces at the hips). Each OUTSIDE piece is projected onto the main surface (every
# vertex to the nearest point, carried into the surface's UV by the barycentre of the triangle it lands on) and its triangles are written to IMPRINT_OUT, a JSON of {"kind", "tris": [[[u, v] x 3]]}, which
# tripo_coat_regions paints in the piece's colour; the island's faces are then removed, nothing stands off the surface any more. A piece INSIDE the coat (a ray away from the body meets a wall of the coat within 6 % of H:
# a lining pocket) is removed without a drawing. A triangle whose corners land on far-apart UVs (it crosses a seam) is skipped and counted.
# Run on the coat as finished (after tripo_coat_back_out), before tripo_coat_regions. Env: MERGE_IN, MERGE_OUT, IMPRINT_OUT.  Usage: blender -b -P tripo_coat_merge.py
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
import tripo_common as tc

TAG = "tripo_coat_merge"
arm, P, B, meshes = tc.load(TAG, os.environ["MERGE_IN"])
coat = bpy.data.objects.get("Outfit_Coat")
if coat is None or not coat.vertex_groups:
    tc.fail(TAG, "no skinned Outfit_Coat")
H = float(max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name in ("Outfit_Hat", "Body_Head")) - min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name == "Outfit_Shoes"))
V = tc.world_verts(coat); W = tc.read_weights(coat); me = coat.data
uvl = me.uv_layers[0]
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
isl = {}
for p in me.polygons:
    isl.setdefault(find(rep[p.vertices[0]]), []).append(p.index)
main = max(isl, key=lambda k: len(isl[k]))
bh = lambda n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:])
SEGS = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
SEGS += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]
def away(q):
    best = None
    for a, b in SEGS:
        ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
        if best is None or d < best[0]:
            best = (d, (q - c) / max(d, 1e-12))
    return best[1]
tri_all = list(me.loop_triangles)
tri_main = [t for t in tri_all if find(rep[me.polygons[t.polygon_index].vertices[0]]) == main]
bvh = BVHTree.FromPolygons([tuple(q) for q in V], [tuple(t.vertices) for t in tri_main])
armw = lambda i: sum(x for n, x in W[i].items() if any(t in n for t in ("Shoulder", "Arm", "Hand")))
imprints = []; kill = []; stats = {"drawn": 0, "skipped": 0, "removed_inside": 0}
SEAM = 0.06                                                                       # UV units: a corner farther than this from the others is across a seam
for k, fl in isl.items():
    if k == main:
        continue
    vs = sorted({v for fi in fl for v in me.polygons[fi].vertices}); pts = V[vs]; c = pts.mean(0); sz = (pts.max(0) - pts.min(0)) / H * 1000; n = len(fl)
    arm_w = float(np.mean([armw(v) for v in vs]))
    kill += fl
    if bvh.ray_cast(Vector(c), Vector(away(c)), 0.06 * H)[0] is not None:        # behind a wall of the coat: a lining pocket, nothing to draw
        stats["removed_inside"] += n; print(f"[{TAG}]   inside  faces {n:3d} at x {c[0] / H:+.3f} z {c[2] / H:.3f} H, {sz[0]:.0f} x {sz[1]:.0f} x {sz[2]:.0f} mm: removed"); continue
    if n <= 2 or max(sz) < 25:
        kind = "button"
    elif arm_w > 0.6:
        kind = "cufftab"
    elif abs(c[0]) / H < 0.12 and 0.6 < c[2] / H < 0.7 and max(sz) > 60:
        kind = "hip"
    elif abs(c[0]) / H < 0.12 and 0.40 < c[2] / H < 0.56 and max(sz) > 80:
        kind = "flap"
    elif c[1] / H > 0.02 and 0.5 < c[2] / H < 0.6:
        kind = "belttab"
    else:
        kind = "other"
    uv_of = {}
    for v in vs:
        loc, nrm, fi, d = bvh.find_nearest(Vector(V[v])); t = tri_main[fi]; a, b, cc = t.vertices
        bc = np.clip(np.array(barycentric_transform(loc, Vector(V[a]), Vector(V[b]), Vector(V[cc]), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))[:]), 0, None)
        bc = bc / max(bc.sum(), 1e-9); uv = sum(w * np.array(uvl.data[l].uv[:]) for w, l in zip(bc, t.loops)); uv_of[v] = uv
    tris = []; n_skip = 0
    for fi in fl:
        us = [uv_of[v] for v in me.polygons[fi].vertices[:3]]
        if max(np.linalg.norm(us[i] - us[j]) for i in range(3) for j in range(i + 1, 3)) > SEAM:
            n_skip += 1; continue
        tris.append([[float(x) for x in u] for u in us])
    imprints.append({"kind": kind, "tris": tris}); stats["drawn"] += len(tris); stats["skipped"] += n_skip
    print(f"[{TAG}]   {kind:8s} faces {n:3d} at x {c[0] / H:+.3f} y {c[1] / H:+.3f} z {c[2] / H:.3f} H, {sz[0]:.0f} x {sz[1]:.0f} x {sz[2]:.0f} mm: {len(tris)} triangles drawn, {n_skip} across a seam")
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in kill], context='FACES'); bm.to_mesh(me); bm.free(); me.update()
json.dump(imprints, open(os.environ["IMPRINT_OUT"], "w"))
print(f"[{TAG}] {len(kill)} faces of {len(isl) - 1} loose islands removed ({stats['removed_inside']} inside the coat); {stats['drawn']} triangles imprinted, {stats['skipped']} skipped; coat now {len(me.polygons)} faces")
tc.export(os.environ["MERGE_OUT"], meshes, arm)
