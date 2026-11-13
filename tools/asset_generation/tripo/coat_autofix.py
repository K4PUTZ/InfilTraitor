# coat_autofix.py — AUTOMATIC COAT-VS-LEG FIX for a pose timeline (MOVEMENT, 2026-11-12; Director: "localizar de maneira inteligente os vertices que atravessam a calca ...
# e afastar ligeiramente a saia"). For each ThrowFix_f<frame> (or the key named by AF_KEYS) of a SEQ_*.blend: pose the figure at that frame, find the coat vertices (BOTH
# layers) that lie inside or too close to the trousers, push them outward from the leg (the trousers' own surface normal at the nearest point: the leg's radial direction),
# smooth the push over the coat's mesh so no spike remains, iterate until the margin holds, then convert the world-space push back to the Basis space (the skin is linear in the
# rest position, so three probe evaluations give each vertex's 3x3) and write it into the shape key. A ramp keeps the waist untouched.
# Env: AF_OUT (the .blend to save), AF_JSON (the dump folder), AF_MARGIN (m, default 0.006), AF_RAMP_TOP/AF_RAMP_BOT (m around the hips' rest z), AF_SMOOTH, AF_KEYS.
import bpy, bmesh, os, json, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = os.environ.get("AF_OUT"); JS = os.environ.get("AF_JSON", ".")
MARGIN = float(os.environ.get("AF_MARGIN", "0.006")); MAXPUSH = float(os.environ.get("AF_MAXPUSH", "0.05")); SMOOTH = int(os.environ.get("AF_SMOOTH", "6"))
RAMP_TOP = float(os.environ.get("AF_RAMP_TOP", "0.04")); RAMP_BOT = float(os.environ.get("AF_RAMP_BOT", "0.10"))
KEYS = os.environ.get("AF_KEYS", "").split(",") if os.environ.get("AF_KEYS") else None
LEGS = ("Outfit_Trousers_Coated", "Outfit_Trousers")
dg = lambda: bpy.context.evaluated_depsgraph_get()
sc = bpy.context.scene
coat = bpy.data.objects["Outfit_Coat"]; sk = coat.data.shape_keys
n = len(coat.data.vertices)

def evaluated(obj):
    d = dg(); eo = obj.evaluated_get(d); m = eo.to_mesh()
    P = np.array([(eo.matrix_world @ v.co)[:] for v in m.vertices]); F = [tuple(p.vertices) for p in m.polygons]
    eo.to_mesh_clear(); return P, F

def build_bvh():
    verts, faces, off = [], [], 0
    for nme in LEGS:
        o = bpy.data.objects.get(nme)
        if o is None: continue
        P, F = evaluated(o); verts += [Vector(p) for p in P]; faces += [tuple(i + off for i in f) for f in F]; off += len(P)
    return BVHTree.FromPolygons(verts, faces)

# adjacency of the coat for the smoothing (welded by position: the glTF splits seams)
cm = coat.data
adj = [set() for _ in range(n)]
for e in cm.edges:
    a, b = e.vertices; adj[a].add(b); adj[b].add(a)
rest = np.array([v.co[:] for v in cm.vertices])
# vertices at the same position are one (seam duplicates): tie them for the smoothing
pos = {}
for i, p in enumerate(rest): pos.setdefault(tuple(np.round(p, 5)), []).append(i)
for g in pos.values():
    for i in g:
        for j in g:
            if i != j: adj[i].add(j)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
hip_rest = (arm.matrix_world @ arm.data.bones[[b.name for b in arm.data.bones if b.name.endswith("Hips")][0]].head_local).z
# rest z of the coat in world terms (the object's rest, not posed)
rest_w = np.array([(coat.matrix_world @ Vector(p))[:] for p in rest])
ramp = np.clip((rest_w[:, 2] - (hip_rest - RAMP_BOT)) / (RAMP_TOP + RAMP_BOT), 0, 1)   # 1 at the hips+TOP, 0 below hips-BOT: invert below
ramp = 1.0 - np.clip((rest_w[:, 2] - (hip_rest - RAMP_BOT)) / (RAMP_BOT + RAMP_TOP), 0, 1)
ramp = np.where(rest_w[:, 2] < hip_rest - RAMP_BOT, 1.0, ramp)   # full push from the hips down; fades up to hips+TOP
ramp = ramp ** 1.0

SAMPLES = []
for poly in cm.polygons:
    vs = list(poly.vertices)
    if len(vs) != 3: continue
    a, b, c = vs
    SAMPLES += [((a, b, c), (1, 0, 0)), ((a, b, c), (0, 1, 0)), ((a, b, c), (0, 0, 1)), ((a, b, c), (1/3, 1/3, 1/3)),
                ((a, b, c), (.5, .5, 0)), ((a, b, c), (0, .5, .5)), ((a, b, c), (.5, 0, .5))]

def probe_matrices():
    """L[v] (3x3): deformed world position's response to a Basis-space offset of vertex v, at the current frame (the skin is linear)."""
    tmp = coat.shape_key_add(name="_probe", from_mix=False)
    base = np.array([(coat.evaluated_get(dg()).matrix_world @ Vector(p))[:] for p in [(0, 0, 0)]])
    def ev():
        eo = coat.evaluated_get(dg()); m = eo.to_mesh(); P = np.array([(eo.matrix_world @ v.co)[:] for v in m.vertices]); eo.to_mesh_clear(); return P
    tmp.value = 0.0; sc.frame_set(sc.frame_current); P0 = ev()
    eps = 0.002; L = np.zeros((n, 3, 3))
    for k in range(3):
        for i, v in enumerate(tmp.data): v.co = Vector(rest[i])
        for i, v in enumerate(tmp.data):
            c = Vector(rest[i]); c[k] += eps; v.co = c
        tmp.value = 1.0; bpy.context.view_layer.update(); P1 = ev()
        L[:, :, k] = (P1 - P0) / eps
    coat.shape_key_remove(tmp)
    return L, P0

def run_frame(frame, key):
    sc.frame_set(frame); bpy.context.view_layer.update()
    kb = sk.key_blocks[key]
    # evaluate with the target key zero, everything else as animated
    old = kb.value; kb.mute = True
    bpy.context.view_layer.update()
    L, P0 = probe_matrices()
    tree = build_bvh()
    D = np.zeros((n, 3))
    stats = []
    for it in range(int(os.environ.get("AF_ITERS","24"))):
        P = P0 + D; need = np.zeros((n, 3))
        inside = 0
        for (tri, w) in SAMPLES:           # the coat's vertices AND points across its faces: a big triangle can cut the leg with all three corners outside
            r = float(sum(wi * ramp[v] for wi, v in zip(w, tri)))
            if r <= 0: continue
            q = Vector(sum(wi * P[v] for wi, v in zip(w, tri))); loc, nor, idx, dist = tree.find_nearest(q)
            if loc is None: continue
            s = (q - loc).dot(nor); sd = dist if s >= 0 else -dist
            if s < 0: inside += 1
            if sd < MARGIN:
                push = np.array(nor[:]) * (MARGIN - sd) * r
                for wi, v in zip(w, tri):
                    if wi > 0.01 and np.linalg.norm(push) > np.linalg.norm(need[v]): need[v] = push
        stats.append((inside, int((np.linalg.norm(need, axis=1) > 1e-6).sum())))
        if stats[-1][1] == 0: break
        # a vertex pushed is never pulled back; smooth the NEED field over the mesh so neighbours follow
        step = need.copy()
        for _ in range(SMOOTH):
            nxt = step.copy()
            for i in range(n):
                if adj[i]:
                    avg = np.mean([step[j] for j in adj[i]], axis=0)
                    nxt[i] = np.maximum.reduce([step[i] * 0 + step[i], avg * 0.9 * ramp[i]], axis=0) if False else (step[i] if np.linalg.norm(step[i]) >= np.linalg.norm(avg) * 0.9 * ramp[i] else avg * 0.9 * ramp[i])
            step = nxt
        D += step
        nrm = np.linalg.norm(D, axis=1, keepdims=True); D = np.where(nrm > MAXPUSH, D * MAXPUSH / np.maximum(nrm, 1e-9), D)   # a deep vertex is not chased through the whole leg
    kb.mute = False; kb.value = old
    print(f"[coat_autofix] frame {frame} {key}: (inside, needing) per iteration {stats}; max push {np.linalg.norm(D,axis=1).max()*100:.1f} cm, {int((np.linalg.norm(D,axis=1)>1e-4).sum())} vertices moved")
    # world push -> Basis offset: solve L d_local = D per vertex
    loc_d = np.zeros((n, 3))
    for i in range(n):
        if np.linalg.norm(D[i]) > 1e-9:
            loc_d[i] = np.linalg.solve(L[i], D[i])
    return loc_d

for name in [k.name for k in sk.key_blocks if k.name.startswith("ThrowFix")] if KEYS is None else KEYS:
    frame = int(name.split("_f")[1])
    d = run_frame(frame, name)
    for i, v in enumerate(sk.key_blocks[name].data):
        v.co = Vector(rest[i] + d[i])
    json.dump({"name": name, "basis": rest.tolist(), "key": (rest + d).tolist()}, open(os.path.join(JS, name + ".json"), "w"))
if OUT:
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("[coat_autofix] wrote", OUT)
