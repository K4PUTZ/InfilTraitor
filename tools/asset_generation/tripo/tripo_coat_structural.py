# tripo_coat_structural.py — the coat study's three candidates written into a COPY of an A file (Director, 2026-11-05: "Sim, numa cópia"; numbers in ACTOR_MASTER_PLAN's top block). It refuses to write over an existing file, and CS_OUT must differ from CS_A.
# (1) Skin: the coat's torso (between the hips and the neck, sleeves apart) takes the skin of the nearest shirt / belt / trousers vertex within 8 cm, unsmoothed, at most 4 influences. (2) Clearance: shape key `UnderCoat`, left at 1, on the shirt (CS_TUCK_SHIRT mm, 20) and the trousers (CS_TUCK_LEGS mm, 8): what the coat covers at rest steps back along its normal, 0 at the edge of the covered area, full 3 cm inside it, the trousers also fading out over the 6 cm above the hem. (3) Lining: the coat's inner wall steps in toward the body axis (CS_LINING mm, 8), collar apart, 0 where it meets the outer wall, full 2 cm from there, in every shape key alike so a corrective's delta is kept.
# The corrective keys stay in the file at value 0. Env: CS_A, CS_OUT. Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_coat_structural.py
import heapq
import math
import os
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

TAG = "tripo_coat_structural"
SRC, OUT = os.path.abspath(os.environ["CS_A"]), os.path.abspath(os.environ["CS_OUT"])
if SRC == OUT or os.path.exists(OUT):
    raise SystemExit(f"[{TAG}] will not write over {OUT}")
TUCK_SHIRT = float(os.environ.get("CS_TUCK_SHIRT", "20")) / 1000.0
TUCK_LEGS = float(os.environ.get("CS_TUCK_LEGS", "8")) / 1000.0
LINING = float(os.environ.get("CS_LINING", "8")) / 1000.0
PFX = "mixamorig:"
bpy.ops.wm.open_mainfile(filepath=SRC)
if bpy.context.mode != 'OBJECT':                         # the male's file is saved in Edit Mode, on the buckle
    bpy.ops.object.mode_set(mode='OBJECT')
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
coat = next(o for o in bpy.data.objects if o.type == 'MESH' and "Coat" in o.name)
bones = [b.name for b in arm.pose.bones]
col = {b: k for k, b in enumerate(bones)}
head = lambda n: np.array((arm.matrix_world @ arm.data.bones[PFX + n].head_local)[:])
cx, cy = head("Hips")[:2]
Z_NECK, Z_HIP = head("Neck")[2], head("Hips")[2]


def world(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    r = np.array([(o.matrix_world @ v.co)[:] for v in m.vertices])
    e.to_mesh_clear()
    return r


def weights(o):
    names = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(o.data.vertices), len(bones)))
    for v in o.data.vertices:
        for g in v.groups:
            k = col.get(names[g.group])
            if k is not None:
                w[v.index, k] = g.weight
    return w / np.maximum(w.sum(1, keepdims=True), 1e-12)


def tris(o):
    o.data.calc_loop_triangles()
    return np.array([t.vertices[:] for t in o.data.loop_triangles], dtype=np.int64)


def normals(p, t):
    fn = np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, t[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def distance_from(sources, p, edges):
    links = [[] for _ in p]
    for a, b in edges:
        d = float(np.linalg.norm(p[a] - p[b]))
        links[a].append((b, d)); links[b].append((a, d))
    dist = np.full(len(p), np.inf)
    dist[sources] = 0.0
    heap = [(0.0, int(i)) for i in np.nonzero(sources)[0]]
    heapq.heapify(heap)
    while heap:
        d0, i = heapq.heappop(heap)
        if d0 > dist[i]:
            continue
        for j, d in links[i]:
            if d0 + d < dist[j]:
                dist[j] = d0 + d
                heapq.heappush(heap, (dist[j], j))
    return dist


P = world(coat)
T = tris(coat)
W = weights(coat)
sleeve = sum(W[:, col[b]] for b in bones if any(t in b for t in ("Shoulder", "Arm", "Hand"))) > 0.5
bvh = BVHTree.FromPolygons([tuple(q) for q in P], [tuple(t) for t in T.tolist()], all_triangles=True)
# (1) the skin
UNDER = ("Outfit_Shirt", "Outfit_Belt", "Outfit_Trousers")
up = np.vstack([world(bpy.data.objects[n]) for n in UNDER])
uw = np.vstack([weights(bpy.data.objects[n]) for n in UNDER])
kd = KDTree(len(up))
for i, q in enumerate(up):
    kd.insert(q, i)
kd.balance()
torso = ~sleeve & (P[:, 2] > Z_HIP) & (P[:, 2] <= Z_NECK - 0.01)
groups = {g.name: g for g in coat.vertex_groups}
changed = 0
for i in np.nonzero(torso)[0]:
    _, j, dist = kd.find(P[i])
    if dist > 0.08:
        continue
    top = np.argsort(uw[j])[-4:]
    total = uw[j, top].sum()
    for name, g in groups.items():
        if name.startswith(PFX):
            g.remove([int(i)])
    for k in top:
        if uw[j, k] > 1e-4:
            name = bones[k]
            g = groups.get(name) or coat.vertex_groups.new(name=name)
            groups[name] = g
            g.add([int(i)], float(uw[j, k] / total), 'REPLACE')
    changed += 1
print(f"[{TAG}] skin: {changed} torso vertices")
# (2) the clearance
hem = float(P[:, 2].min())
for name, amount in (("Outfit_Shirt", TUCK_SHIRT), ("Outfit_Trousers", TUCK_LEGS)):
    o = bpy.data.objects[name]
    q = world(o)
    nn = normals(q, tris(o))
    covered = np.array([bvh.ray_cast(Vector(a) + Vector(b) * 1e-4, Vector(b), 0.12)[0] is not None for a, b in zip(q, nn)])
    dist = distance_from(~covered, q, [tuple(e.vertices) for e in o.data.edges])
    fade = sstep(0.0, 0.03, np.where(np.isfinite(dist), dist, 0.03))
    if name == "Outfit_Trousers":
        fade = fade * sstep(hem, hem + 0.06, q[:, 2])
    if o.data.shape_keys is None:
        o.shape_key_add(name="Basis", from_mix=False)
    key = o.shape_key_add(name="UnderCoat", from_mix=False)
    inv = np.array(o.matrix_world.inverted())
    out = (q - nn * fade[:, None] * amount) @ inv[:3, :3].T + inv[:3, 3]
    key.data.foreach_set("co", out.ravel())
    key.value = 1.0
    print(f"[{TAG}] clearance {name}: {int((fade > 0.5).sum())} of {len(q)} vertices past half, {amount * 1000:.0f} mm")
# (3) the lining
t_c = P[T].mean(1)
t_n = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
t_n /= np.maximum(np.linalg.norm(t_n, axis=1, keepdims=True), 1e-12)
t_a = np.c_[t_c[:, :2] - np.array((cx, cy)), np.zeros(len(t_c))]
t_a /= np.maximum(np.linalg.norm(t_a, axis=1, keepdims=True), 1e-9)
t_sleeve = sleeve[T].all(1)
lining = np.zeros(len(T), bool)
for t in np.nonzero(((t_n * t_a).sum(1) < -0.2) & ~t_sleeve)[0]:
    hit = bvh.ray_cast(Vector(t_c[t] + t_a[t] * 1e-4), Vector(t_a[t]), 0.03)
    lining[t] = hit[0] is not None and not t_sleeve[hit[2]]
inner = np.zeros(len(P), bool)
inner[np.unique(T[lining])] = True
inner[np.unique(T[~lining])] = False
inner &= P[:, 2] <= Z_NECK - 0.01
radial = np.c_[P[:, :2] - np.array((cx, cy)), np.zeros(len(P))]
radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
dist = distance_from(~inner, P, [tuple(e.vertices) for e in coat.data.edges])
move = -radial * sstep(0.0, 0.02, np.where(np.isfinite(dist), dist, 0.02))[:, None] * LINING
local = move @ np.array(coat.matrix_world.inverted())[:3, :3].T
for kb in coat.data.shape_keys.key_blocks:
    for i in np.nonzero(inner)[0]:
        kb.data[int(i)].co = Vector(kb.data[int(i)].co) + Vector(local[i])
for i in np.nonzero(inner)[0]:
    coat.data.vertices[int(i)].co = Vector(coat.data.vertices[int(i)].co) + Vector(local[i])
coat.data.update()
print(f"[{TAG}] lining: {int(inner.sum())} vertices, {LINING * 1000:.0f} mm")
bpy.context.view_layer.update()
after = world(coat)
print(f"[{TAG}] rest pose: outer wall moved {np.linalg.norm(after[~inner] - P[~inner], axis=1).max() * 100:.6f} cm, lining up to {np.linalg.norm(after[inner] - P[inner], axis=1).max() * 100:.3f} cm")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=True)
print(f"[{TAG}] wrote {OUT}")
