# tripo_coat_torso_weights.py — the coat's torso takes the shirt's skin (ACTOR D101; Director, 2026-11-04: "Pode aplicar"): the coat followed other bones than the shirt, so the shirt came through the chest as soon as the spine moved.
# In the A file, every coat vertex above the waist and inside the shoulder joints takes the bone weights of the nearest shirt vertex (at most CW_REACH away), then CW_SMOOTH passes level the steps between neighbours, at most 4 influences, normalised.
# A group that names no bone (`Rigid`) is left alone; the sleeves and the skirt keep their weights. The T file's coat takes the same weights through its UVs, since its welds differ. No position changes.
# Env: CW_A, CW_T (input .blend), CW_OUT_A, CW_OUT_T (output .blend), CW_REACH (metres, 0.05), CW_SMOOTH (2).
# Usage: blender -b --python-exit-code 1 -P tripo_coat_torso_weights.py
import os
import numpy as np
import bpy
from mathutils.kdtree import KDTree

TAG = "tripo_coat_torso_weights"
REACH = float(os.environ.get("CW_REACH", "0.05"))
SMOOTH = int(os.environ.get("CW_SMOOTH", "2"))
PFX = "mixamorig:"


def coat_of():
    return next(o for o in bpy.data.objects if o.type == 'MESH' and "Coat" in o.name)


def world(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    mw = o.matrix_world
    r = [(mw @ v.co).copy() for v in m.vertices]
    e.to_mesh_clear()
    return r


def read_uv(me):
    uv = me.uv_layers.active.data
    return [(round(uv[l.index].uv[0] / 2e-5), round(uv[l.index].uv[1] / 2e-5), l.vertex_index) for l in me.loops]


def write(coat, new):
    """new: {vertex: {bone group: weight}}; the bone groups of those vertices are replaced"""
    groups = {g.name: g for g in coat.vertex_groups}
    for i, w in new.items():
        for e in list(coat.data.vertices[i].groups):
            if coat.vertex_groups[e.group].name.startswith(PFX):
                coat.vertex_groups[e.group].remove([i])
        for n, x in w.items():
            g = groups.get(n)
            if g is None:
                g = groups[n] = coat.vertex_groups.new(name=n)
            g.add([i], x, 'REPLACE')


# the A file
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["CW_A"]))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
if arm.data.pose_position != 'REST':
    raise SystemExit(f"[{TAG}] the A file must be saved in REST")
coat, shirt = coat_of(), bpy.data.objects["Outfit_Shirt"]
pc, ps = world(coat), world(shirt)
kd = KDTree(len(ps))
for i, p in enumerate(ps):
    kd.insert(p, i)
kd.balance()
head = lambda n: arm.data.bones[PFX + n].head_local
waist, cx, reach_x = head("Spine").z - 0.02, head("Hips").x, abs(head("LeftArm").x - head("Hips").x) + 0.005
sg = {g.index: g.name for g in shirt.vertex_groups}
cg = {g.index: g.name for g in coat.vertex_groups}
names = sorted({n for n in sg.values() if n.startswith(PFX)} | {n for n in cg.values() if n.startswith(PFX)})
col = {n: k for k, n in enumerate(names)}
W = np.zeros((len(pc), len(names)))
for v in coat.data.vertices:
    for e in v.groups:
        if cg[e.group] in col:
            W[v.index, col[cg[e.group]]] = e.weight
W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
chosen = []
for i, p in enumerate(pc):
    if p.z < waist or abs(p.x - cx) > reach_x:
        continue
    _, j, dist = kd.find(p)
    if dist > REACH:
        continue
    W[i] = 0
    for e in shirt.data.vertices[j].groups:
        if sg[e.group] in col:
            W[i, col[sg[e.group]]] = e.weight
    chosen.append(i)
W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
nbr = [[] for _ in pc]
for e in coat.data.edges:
    a, b = e.vertices
    nbr[a].append(b)
    nbr[b].append(a)
for _ in range(SMOOTH):
    X = W.copy()
    for i in chosen:
        if nbr[i]:
            X[i] = 0.5 * W[i] + 0.5 * W[nbr[i]].mean(0)
    W = X
new = {}
for i in chosen:
    top = np.argsort(W[i])[-4:]
    tot = W[i, top].sum()
    new[i] = {names[k]: float(W[i, k] / tot) for k in top if W[i, k] > 1e-4}
write(coat, new)
final = {i: new.get(i) for i in range(len(pc))}
for i, v in enumerate(coat.data.vertices):
    if final[i] is None:
        final[i] = {cg[e.group]: e.weight for e in v.groups if cg.get(e.group, "").startswith(PFX)}
a_uv = {}
for u, v, k in read_uv(coat.data):
    a_uv.setdefault((u, v), k)
print(f"[{TAG}] A: {len(chosen)}/{len(pc)} coat vertices changed")
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.environ["CW_OUT_A"]))

# the T file: same weights, through the UVs
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["CW_T"]))
coat = coat_of()
chosen_set, new, seen = set(chosen), {}, set()
for u, v, k in read_uv(coat.data):
    for du in (-1, 0, 1):
        for dv in (-1, 0, 1):
            a = a_uv.get((u + du, v + dv))
            if a is not None and k not in new:
                seen.add(k)
                if a in chosen_set:
                    new[k] = final[a]
if len(seen) != len(coat.data.vertices):
    raise SystemExit(f"[{TAG}] T: only {len(seen)}/{len(coat.data.vertices)} coat vertices matched by UV")
write(coat, new)
print(f"[{TAG}] T: {len(new)}/{len(coat.data.vertices)} coat vertices changed")
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.environ["CW_OUT_T"]))
