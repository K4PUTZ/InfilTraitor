# tripo_coat_counterfactual.py — what would remove the coat's leaks without a hand edit? Each row swaps the coat's skin in memory (or adds the D94 push, computed with coat_push.py, the shader's numpy reference) and counts again, on the base file with its corrective keys at 0. Read-only: it never saves the .blend. (Director, 2026-11-05: the study of where the hand edits go and how to avoid them in the next clips.)
# EXPOSED has tripo_coat_study.py's meaning: a vertex of the shirt, belt or trousers covered by the coat at rest whose ray along its normal meets no coat on that frame. LINING OUT: a vertex of the coat's inner wall with no coat outside it on that frame. CALM: how far the coat lands from today's on the idle frames, in cm.
# Env: CF_A (the A .blend), CF_FIG (female | male), CF_CLIPS (idle,walk,run), CF_SAMPLES (15), CF_ROWS (comma list, default all), CF_REACH (metres, 0.08).
# Usage (from the repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_coat_counterfactual.py
import heapq
import math
import os
import re
import sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coat_push as cp

TAG = "cf"
FIG = os.environ["CF_FIG"]
CLIPS = os.environ.get("CF_CLIPS", "idle,walk,run").split(",")
SAMPLES = int(os.environ.get("CF_SAMPLES", "15"))
REACH = float(os.environ.get("CF_REACH", "0.08"))
PFX = "mixamorig:"
UNDER = ("Outfit_Shirt", "Outfit_Belt", "Outfit_Trousers")
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["CF_A"]))
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
coat = next(o for o in bpy.data.objects if o.type == 'MESH' and "Coat" in o.name)
bones = [b.name for b in arm.pose.bones]
col = {b: k for k, b in enumerate(bones)}
aw = np.array(arm.matrix_world)
awi = np.linalg.inv(aw)
head = lambda n: np.array((arm.matrix_world @ arm.data.bones[PFX + n].head_local)[:])
hip_h = head("Hips")[2]
cx, cy = head("Hips")[:2]
Z_NECK, Z_S1, Z_S, Z_HIP = head("Neck")[2], head("Spine1")[2], head("Spine")[2], head("Hips")[2]


def evaluated(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    mw = o.matrix_world
    r = np.array([(mw @ v.co)[:] for v in m.vertices])
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


class Piece:
    def __init__(self, o):
        self.o = o
        self.rest = evaluated(o)
        self.W = weights(o)
        o.data.calc_loop_triangles()
        self.tris = np.array([t.vertices[:] for t in o.data.loop_triangles], dtype=np.int64)


def skin(W, rest, S):
    M = np.einsum('nb,bij->nij', W, S)
    M[W.sum(1) <= 1e-9] = np.eye(4)
    return np.einsum('nij,nj->ni', M, np.c_[rest, np.ones(len(rest))])[:, :3], M


def normals(p, tris):
    fn = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def group(p, sleeve=False):
    x, y, z = p
    if sleeve:
        return "sleeve"
    if z > Z_NECK - 0.01:
        return "collar"
    ang = abs(math.degrees(math.atan2(x - cx, -(y - cy))))
    side = "front" if ang < 50 else ("back" if ang > 130 else "side")
    if z > Z_S1:
        return "chest_" + side
    if z > Z_HIP:
        return "waist_" + side
    return ("skirt_hi_" if z > HEM_MID else "skirt_lo_") + side


def bvh_of(p, tris):
    return BVHTree.FromPolygons([tuple(q) for q in p], [tuple(t) for t in tris.tolist()], all_triangles=True)


def any_wall(bvh, q, n, reach=0.25):
    return bvh.ray_cast(Vector(q) + Vector(n) * 1e-4, Vector(n), reach)[0] is not None


def play(clip):
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.context.view_layer.objects.active = None       # the male's file was saved with the buckle in Edit Mode: with it active, the importer's 42-vertex bone sphere lands inside that mesh (measured, 88 -> 130 vertices)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/ANIMATIONS/bank/{FIG}/{clip}.glb"))
    act = [a for a in bpy.data.actions if a not in before_a][0]
    for o in [o for o in bpy.data.objects if o not in before_o]:
        bpy.data.objects.remove(o)
    curves = [fc for la in act.layers for s in la.strips for cb in s.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
    for fc in curves:
        if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
            for k in fc.keyframe_points:
                k.co.y *= hip_h; k.handle_left.y *= hip_h; k.handle_right.y *= hip_h
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    arm.data.pose_position = 'POSE'
    return act


C = Piece(coat)
Us = {n: Piece(bpy.data.objects[n]) for n in UNDER}
HEM_MID = 0.5 * (float(C.rest[:, 2].min()) + Z_HIP)
arm_w = sum(C.W[:, col[b]] for b in bones if any(t in b for t in ("Shoulder", "Arm", "Hand")))
sleeve = arm_w > 0.5
bands = np.array([group(p, s) for p, s in zip(C.rest, sleeve)])
torso = np.char.startswith(bands, "chest") | np.char.startswith(bands, "waist")
edges = sorted({tuple(sorted(e.vertices)) for e in coat.data.edges})
E = np.array(edges)
L0 = np.linalg.norm(C.rest[E[:, 0]] - C.rest[E[:, 1]], axis=1)
nbr = [[] for _ in C.rest]
inc_e = [[] for _ in C.rest]
for k, (a, b) in enumerate(edges):
    nbr[a].append(b); nbr[b].append(a)
    inc_e[a].append(k); inc_e[b].append(k)
te = {}
for t, (a, b, c) in enumerate(C.tris.tolist()):
    for u, v in ((a, b), (b, c), (c, a)):
        te.setdefault((min(u, v), max(u, v)), []).append(t)
H_T = np.array([v for v in te.values() if len(v) == 2])
H_E = np.array([k for k, v in te.items() if len(v) == 2])
inc_h = [[] for _ in C.rest]
for k, (a, b) in enumerate(H_E.tolist()):
    inc_h[a].append(k); inc_h[b].append(k)


def dihedral(p):
    n = np.cross(p[C.tris[:, 1]] - p[C.tris[:, 0]], p[C.tris[:, 2]] - p[C.tris[:, 0]])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    return np.degrees(np.arccos(np.clip((n[H_T[:, 0]] * n[H_T[:, 1]]).sum(1), -1, 1)))


D0 = dihedral(C.rest)
bvh0 = bvh_of(C.rest, C.tris)
radial = np.c_[C.rest[:, :2] - np.array((cx, cy)), np.zeros(len(C.rest))]
radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
# the lining: a triangle that looks at the body with a wall of the coat right outside it (tripo_coat_regions.py's rule); a vertex is the lining's if only such triangles use it
t_c = C.rest[C.tris].mean(1)
t_n = np.cross(C.rest[C.tris[:, 1]] - C.rest[C.tris[:, 0]], C.rest[C.tris[:, 2]] - C.rest[C.tris[:, 0]])
t_n /= np.maximum(np.linalg.norm(t_n, axis=1, keepdims=True), 1e-12)
t_a = np.c_[t_c[:, :2] - np.array((cx, cy)), np.zeros(len(t_c))]
t_a /= np.maximum(np.linalg.norm(t_a, axis=1, keepdims=True), 1e-9)
t_sleeve = sleeve[C.tris].all(1)
lining_tri = np.zeros(len(C.tris), bool)
for t in np.nonzero(((t_n * t_a).sum(1) < -0.2) & ~t_sleeve)[0]:
    hit = bvh0.ray_cast(Vector(t_c[t] + t_a[t] * 1e-4), Vector(t_a[t]), 0.03)
    lining_tri[t] = hit[0] is not None and not t_sleeve[hit[2]]
inner = np.zeros(len(C.rest), bool)
inner[np.unique(C.tris[lining_tri])] = True
inner[np.unique(C.tris[~lining_tri])] = False
# the wall right outside each lining vertex
outer_of = np.arange(len(C.rest))
for i in np.nonzero(inner)[0]:
    hit = bvh0.ray_cast(Vector(C.rest[i] + radial[i] * 1e-3), Vector(radial[i]), 0.06)
    if hit[0] is not None:
        tri = C.tris[hit[2]]
        tri = tri[~inner[tri]]
        if len(tri):
            outer_of[i] = tri[np.linalg.norm(C.rest[tri] - np.array(hit[0][:]), axis=1).argmin()]
print(f"[{TAG}] lining: {int(lining_tri.sum())} of {len(C.tris)} triangles, {int(inner.sum())} vertices only on it, {int((outer_of != np.arange(len(C.rest))).sum())} of those with a wall found outside")
under_p = np.vstack([Us[n].rest for n in UNDER])
under_W = np.vstack([Us[n].W for n in UNDER])
kd = KDTree(len(under_p))
for i, p in enumerate(under_p):
    kd.insert(p, i)
kd.balance()
found = [kd.find(p) for p in C.rest]
near = np.array([f[1] for f in found])
gap0 = np.array([f[2] for f in found])
# diagnostics: does the coat follow what lies under it, and how many influences does it carry?
L1 = np.abs(C.W - under_W[near]).sum(1)
reach_x = abs(head("LeftArm")[0] - cx) + 0.005
print(f"[{TAG}] {FIG}: hips z {Z_HIP:.3f}, D101's waist cut z {Z_S - 0.02:.3f}, D101's x limit {reach_x:.3f}")
print(f"[{TAG}] band: n, skin difference to what lies under it (L1, 0 = same, 2 = none shared) median, % outside D101's x limit, % below its waist cut, influences mean / max, % over 4")
inf = (C.W > 1e-3).sum(1)
for b in sorted(set(bands)):
    m = bands == b
    print(f"[{TAG}]   {b:16s} {m.sum():5d} {np.median(L1[m]):5.2f} {np.mean(np.abs(C.rest[m, 0] - cx) > reach_x) * 100:5.0f} {np.mean(C.rest[m, 2] < Z_S - 0.02) * 100:5.0f} | {inf[m].mean():4.1f} {inf[m].max():3d} {np.mean(inf[m] > 4) * 100:4.0f}")


def top4(W):
    X = np.zeros_like(W)
    for i in range(len(W)):
        k = np.argsort(W[i])[-4:]
        X[i, k] = W[i, k]
    return X / np.maximum(X.sum(1, keepdims=True), 1e-12)


def smooth(W, chosen, passes):
    idx = np.nonzero(chosen)[0]
    for _ in range(passes):
        X = W.copy()
        for i in idx:
            if nbr[i]:
                X[i] = 0.5 * W[i] + 0.5 * W[nbr[i]].mean(0)
        W = X
    return W


def matched(passes):
    """the coat's torso takes the skin of what lies under it, everywhere D101's limits had left out"""
    chosen = torso & (gap0 <= REACH)
    W = C.W.copy()
    W[chosen] = under_W[near][chosen]
    return top4(smooth(W, chosen, passes)), int(chosen.sum())


def lining_follows(W):
    """the lining takes the skin of the wall right outside it, so the two walls move as one"""
    X = W.copy()
    X[inner] = W[outer_of[inner]]
    return X


def d101_clean():
    """what tripo_coat_torso_weights.py meant, its limits kept: its removal loop leaves the old groups in place (a stale iterator), so the file holds the old weights and the new ones mixed"""
    shirt = Us["Outfit_Shirt"]
    tree = KDTree(len(shirt.rest))
    for i, p in enumerate(shirt.rest):
        tree.insert(p, i)
    tree.balance()
    x_limit = abs(head("LeftArm")[0] - cx) + 0.005
    W = C.W.copy()
    chosen = np.zeros(len(C.rest), bool)
    for i, p in enumerate(C.rest):
        if p[2] < Z_S - 0.02 or abs(p[0] - cx) > x_limit:
            continue
        _, j, dist = tree.find(p)
        if dist <= 0.05:
            W[i] = shirt.W[j]
            chosen[i] = True
    W = smooth(W, chosen, 2)
    W[chosen] = top4(W[chosen])
    return W


ROWS = {
    "today": (C.W, False),
    "today_4inf": (top4(C.W), False),
    "d101_clean": (d101_clean(), False),
    "lining": (lining_follows(C.W), False),
    "match_s0_lining": (lining_follows(matched(0)[0]), False),
    "match_s0_lining+push": (lining_follows(matched(0)[0]), True),
    "today+tuck12": (C.W, False),
    "match_s0+tuck12": (matched(0)[0], False),
    "match_s0+tuck20": (matched(0)[0], False),
    "match_s0+tuck12+push": (matched(0)[0], True),
    "match_s0+tuck20t8": (matched(0)[0], False),
    "match_s0+tuck20t8+lin8": (matched(0)[0], False),
    "match_s0+tuck20t8+lin8+push": (matched(0)[0], True),
    "smooth6": (top4(smooth(C.W, torso, 6)), False),
    "match_s0": (matched(0)[0], False),
    "match_s2": (matched(2)[0], False),
    "match_s6": (matched(6)[0], False),
    "today+push": (C.W, True),
    "match_s2+push": (matched(2)[0], True),
}
want = os.environ.get("CF_ROWS", "")
if want:
    ROWS = {k: v for k, v in ROWS.items() if k in want.split(",")}
print(f"[{TAG}] the match covers {matched(0)[1]} torso vertices")
# the clips: the pose matrices and what lies under the coat, kept once
cache = {}
for clip in CLIPS:
    act = play(clip)
    a0, a1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = sorted({int(round(x)) for x in np.linspace(a0, a1, SAMPLES)})
    rows = []
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        S = np.stack([aw @ np.array(arm.pose.bones[b].matrix @ arm.data.bones[b].matrix_local.inverted()) @ awi for b in bones])
        J = {b.replace(PFX, ""): np.array((arm.matrix_world @ arm.pose.bones[b].head)[:]) for b in bones if any(t in b for t in cp.NAMES)}
        qs = {}
        for n in UNDER:
            q, _ = skin(Us[n].W, Us[n].rest, S)
            qs[n] = (q, normals(q, Us[n].tris))
        rows.append((f, S, J, qs))
    cache[clip] = rows
    arm.animation_data.action = None
    bpy.data.actions.remove(act)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
covered, ugroup = {}, {}
for n in UNDER:
    P = Us[n]
    nn = normals(P.rest, P.tris)
    covered[n] = np.nonzero([any_wall(bvh0, q, d, 0.12) for q, d in zip(P.rest, nn)])[0]
    ugroup[n] = np.array([group(q) for q in P.rest])
H = 1.0
s = cp.spec(H)
d_push, mask_push = cp.rest_field(C.rest, arm_w, head("Hips"), Z_HIP, H)
rest_caps = cp.capsules(head, s)
rest_push = np.maximum(cp.push_distance(C.rest, d_push, rest_caps, s), 0.0) * mask_push
if os.environ.get("CF_AUC"):
    # inside the torso alone (the skirt was moved almost whole, so it says nothing): do the Director's hand edits sit where a metric is high? 0.5 = no relation, 1 = perfectly so, 0 = perfectly the opposite
    def auc(values, flag):
        order = values.argsort().argsort() + 1.0
        n1, n0 = flag.sum(), (~flag).sum()
        return float((order[flag].sum() - n1 * (n1 + 1) / 2) / max(n1 * n0, 1))

    rough = np.array([np.mean([np.abs(C.W[i] - C.W[j]).sum() / max(np.linalg.norm(C.rest[i] - C.rest[j]) * 100, 1e-3) for j in ns]) if ns else 0.0 for i, ns in enumerate(nbr)])
    ks = coat.data.shape_keys.key_blocks
    base = np.array([d.co[:] for d in (ks["Fit"] if "Fit" in ks else ks["Basis"]).data])
    for name, clip in (("WalkFix", "walk"), ("IdleFix", "idle"), ("RunFix", "run")):
        if name not in ks or clip not in cache:
            continue
        moved = np.linalg.norm((np.array([d.co[:] for d in ks[name].data]) - base) @ np.array(coat.matrix_world)[:3, :3].T, axis=1) > 2e-3
        stretch, bend, slip = np.zeros(len(E)), np.zeros(len(H_E)), np.zeros(len(C.rest))
        for f, S, J, qs in cache[clip]:
            p, M = skin(C.W, C.rest, S)
            L = np.linalg.norm(p[E[:, 0]] - p[E[:, 1]], axis=1)
            stretch = np.maximum(stretch, np.abs(L / np.maximum(L0, 1e-9) - 1))
            bend = np.maximum(bend, np.abs(dihedral(p) - D0))
            Mu = np.einsum('nb,bij->nij', under_W[near], S)
            slip = np.maximum(slip, np.linalg.norm(np.einsum('nij,nj->ni', M - Mu, np.c_[C.rest, np.ones(len(C.rest))])[:, :3], axis=1))
        sv = np.array([stretch[i].mean() if i else 0.0 for i in inc_e])
        bv = np.array([bend[i].mean() if i else 0.0 for i in inc_h])
        t = torso
        print(f"[{TAG}] AUC {name} in the torso, over 2 mm: {int(moved[t].sum())} of {int(t.sum())}: slip {auc(slip[t], moved[t]):.2f}, stretch {auc(sv[t], moved[t]):.2f}, bend {auc(bv[t], moved[t]):.2f}, rough {auc(rough[t], moved[t]):.2f}, tight {auc(-gap0[t], moved[t]):.2f}, skin difference {auc(L1[t], moved[t]):.2f}, lining {auc(inner[t].astype(float) + 1e-6 * np.arange(int(t.sum())), moved[t]):.2f}", flush=True)
    sys.stdout.flush()
    os._exit(0)
RENDER = os.environ.get("CF_RENDER", "")
if RENDER:
    # the pictures that settle what the rays only suggest: flat colours, the study's four views (the same camera as the walk's first count), the lining in a colour of its own; `keys` is today's skin with the clip's corrective key on, the hand-made reference
    COL = {'Body_Hair': (.25, .13, .05), 'Body_Hands': (.95, .65, .5), 'Body_Head': (.95, .65, .5), 'Outfit_Belt': (.9, .75, .05), 'Outfit_Buckle': (.9, .05, .8), 'Outfit_Shirt': (.95, .95, .95), 'Outfit_Shoes': (.08, .08, .08), 'Outfit_Tie': (.85, .05, .05), 'Outfit_Trousers': (.05, .2, .8)}
    GREEN, CYAN = (.1, .65, .25), (.05, .85, .85)
    KEY_OF = {"idle": "IdleFix", "walk": "WalkFix", "run": "RunFix"}
    rest_k = {}
    ks = coat.data.shape_keys.key_blocks if coat.data.shape_keys else {}
    for clip in CLIPS:
        if KEY_OF.get(clip) in ks:
            ks[KEY_OF[clip]].value = 1.0
            bpy.context.view_layer.update()
            rest_k[clip] = evaluated(coat)
            ks[KEY_OF[clip]].value = 0.0
    if rest_k:
        ROWS["keys"] = (C.W, False)
    others = {n: Piece(bpy.data.objects[n]) for n in COL if n not in UNDER and n in bpy.data.objects}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = True
            o.hide_viewport = True

    def tuck_field(n):
        """what lies under the coat steps back from it: along the inverse normal, 0 where the coat does not cover it, full 3 cm inside the covered area; the trousers also fade out toward the hem, since the legs show below it"""
        P = Us[n]
        nn = normals(P.rest, P.tris)
        cov = np.zeros(len(P.rest), bool)
        cov[covered[n]] = True
        links = [[] for _ in P.rest]
        for e in P.o.data.edges:
            a, b = e.vertices
            length = float(np.linalg.norm(P.rest[a] - P.rest[b]))
            links[a].append((b, length)); links[b].append((a, length))
        dist = np.full(len(P.rest), np.inf)
        heap = [(0.0, int(i)) for i in np.nonzero(~cov)[0]]
        dist[~cov] = 0.0
        heapq.heapify(heap)
        while heap:
            d0, i = heapq.heappop(heap)
            if d0 > dist[i]:
                continue
            for j, length in links[i]:
                if d0 + length < dist[j]:
                    dist[j] = d0 + length
                    heapq.heappush(heap, (dist[j], j))
        fade = cp.sstep(0.0, 0.03, np.where(np.isfinite(dist), dist, 0.03))
        if n == "Outfit_Trousers":
            hem = float(C.rest[:, 2].min())
            fade = fade * cp.sstep(hem, hem + 0.06, P.rest[:, 2])
        away = np.c_[P.rest[:, :2] - np.array((cx, cy)), np.zeros(len(P.rest))]
        print(f"[{TAG}] tuck {n}: {int((fade > 0.5).sum())} of {len(P.rest)} vertices past half; covered with a normal against the body axis (above the hips): {int((((nn * away).sum(1) < 0) & cov & (P.rest[:, 2] > Z_HIP)).sum())}", flush=True)
        return -nn * fade[:, None]

    tuck_d = {n: tuck_field(n) for n in UNDER}
    # the coat's inner wall steps in toward the body (a row with +linN, in mm), 0 where it meets the outer wall and full 2 cm from there: the outside of the coat does not move
    lin_links = [[] for _ in C.rest]
    for a, b in edges:
        length = float(np.linalg.norm(C.rest[a] - C.rest[b]))
        lin_links[a].append((b, length)); lin_links[b].append((a, length))
    lin_on = inner & (bands != "collar")
    lin_dist = np.full(len(C.rest), np.inf)
    lin_dist[~lin_on] = 0.0
    lin_heap = [(0.0, int(i)) for i in np.nonzero(~lin_on)[0]]
    heapq.heapify(lin_heap)
    while lin_heap:
        d0, i = heapq.heappop(lin_heap)
        if d0 > lin_dist[i]:
            continue
        for j, length in lin_links[i]:
            if d0 + length < lin_dist[j]:
                lin_dist[j] = d0 + length
                heapq.heappush(lin_heap, (lin_dist[j], j))
    lin_d = -radial * cp.sstep(0.0, 0.02, np.where(np.isfinite(lin_dist), lin_dist, 0.02))[:, None]

    def temp(name, rest, tris, colour):
        me = bpy.data.meshes.new("cf_" + name)
        me.from_pydata(rest.tolist(), [], tris.tolist())
        me.update()
        ob = bpy.data.objects.new("cf_" + name, me)
        sc.collection.objects.link(ob)
        ob.color = (*colour, 1)
        return me

    def put(me, p):
        me.vertices.foreach_set("co", p.ravel())
        me.update()

    bodies = {n: temp(n, P.rest, P.tris, COL[n]) for n, P in {**Us, **others}.items()}
    outer_me = temp("coat", C.rest, C.tris[~lining_tri], GREEN)
    lining_me = temp("lining", C.rest, C.tris[lining_tri], CYAN)
    cam = bpy.data.objects.new("cf_cam", bpy.data.cameras.new("cf_cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 1.15
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'FLAT'
    sc.display.shading.color_type = 'OBJECT'
    sc.display.render_aa = 'OFF'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.resolution_x = sc.render.resolution_y = 400
    sc.render.image_settings.file_format = 'PNG'
    hip_rest = np.r_[head("Hips"), 1.0]
    # CF_LOOK="walk:20,run:10": those frames only, smooth shaded and lit, closer, the coat a neutral grey: the picture to judge the "liquid" surface by, not to count
    LOOK = {}
    for item in filter(None, os.environ.get("CF_LOOK", "").split(",")):
        name, frame = item.split(":")
        LOOK.setdefault(name, set()).add(int(frame))
    cam_z = 0.5
    if LOOK:
        cam_z = 0.62
        cam.data.ortho_scale = 0.78
        sc.display.shading.light = 'STUDIO'
        sc.render.resolution_x = sc.render.resolution_y = 640
        for me in (*bodies.values(), outer_me, lining_me):
            me.shade_smooth()
        for me in (outer_me, lining_me):
            bpy.data.objects["cf_coat" if me is outer_me else "cf_lining"].color = (.34, .36, .41, 1)

    def shoot(path, h):
        for k, yaw in enumerate((35, 125, 215, 305)):
            d = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw)), .15)).normalized()
            cam.location = Vector((h[0], h[1], cam_z)) + d * 5
            cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
            bpy.context.view_layer.update()
            sc.render.filepath = f"{path}_v{k}.png"
            bpy.ops.render.render(write_still=True)

    # the rest pose, to judge the lining's classification by eye
    S_id = np.stack([np.eye(4)] * len(bones))
    for n, P in {**Us, **others}.items():
        put(bodies[n], P.rest)
    put(outer_me, C.rest)
    put(lining_me, C.rest)
    bpy.context.view_layer.update()
    for o in sc.objects:
        if o.type == 'MESH' and not o.hide_render:
            print(f"[{TAG}] drawn {o.name}: {len(o.data.vertices)} vertices, size {[round(x, 3) for x in o.dimensions]}, at {[round(x, 3) for x in o.location]}", flush=True)
    shoot(f"{os.path.abspath(RENDER)}/{FIG}/rest", head("Hips"))
    for row, (W, pushed) in ROWS.items():
        for clip in CLIPS:
            if row == "keys" and clip not in rest_k:
                continue
            base = rest_k[clip] if row == "keys" else C.rest
            found_tuck = re.search(r"tuck(\d+)(?:t(\d+))?", row)
            tuck = float(found_tuck.group(1)) / 1000.0 if found_tuck else 0.0
            tuck_legs = float(found_tuck.group(2)) / 1000.0 if found_tuck and found_tuck.group(2) else tuck
            found_lin = re.search(r"lin(\d+)", row)
            if found_lin:
                base = base + lin_d * float(found_lin.group(1)) / 1000.0
            for f, S, J, qs in cache[clip]:
                if LOOK and f not in LOOK.get(clip, ()):
                    continue
                for n in UNDER:
                    amount = tuck_legs if n == "Outfit_Trousers" else tuck
                    put(bodies[n], skin(Us[n].W, Us[n].rest + tuck_d[n] * amount, S)[0] if amount else qs[n][0])
                for n, P in others.items():
                    put(bodies[n], skin(P.W, P.rest, S)[0])
                p, _ = skin(W, base, S)
                if pushed:
                    p, _ = cp.push(p, d_push, mask_push, cp.capsules(lambda n: J[n], s), s, rest_push)
                put(outer_me, p)
                put(lining_me, p)
                shoot(f"{os.path.abspath(RENDER)}/{FIG}/{row}/{clip}_f{f:03d}", (S[col[PFX + 'Hips']] @ hip_rest)[:3])
        print(f"[{TAG}] rendered {row}", flush=True)
    sys.stdout.flush()
    os._exit(0)
ZONES = [("Outfit_Shirt", "chest"), ("Outfit_Shirt", "waist"), ("Outfit_Belt", "waist"), ("Outfit_Trousers", "waist"), ("Outfit_Trousers", "skirt_hi"), ("Outfit_Trousers", "skirt_lo")]
LABEL = ["shirt chest", "shirt waist", "belt", "trou waist", "trou skirt_hi", "trou skirt_lo"]
print(f"[{TAG}] per row and clip: mean % exposed over the frames for {LABEL}; torso stretch % med/p95; torso bend deg med/p95; torso slip mm med/p95; lining out %; calm cm p95/max")
base_idle = {}
for row, (W, pushed) in ROWS.items():
    for clip in CLIPS:
        exposed = {z: 0.0 for z in ZONES}
        stretch, bend, slip = np.zeros(len(E)), np.zeros(len(H_E)), np.zeros(len(C.rest))
        lining, calm = 0.0, []
        for fi, (f, S, J, qs) in enumerate(cache[clip]):
            p, M = skin(W, C.rest, S)
            if pushed:
                p, _ = cp.push(p, d_push, mask_push, cp.capsules(lambda n: J[n], s), s, rest_push)
            if clip == "idle":
                if row == "today":
                    base_idle[fi] = p.copy()
                elif fi in base_idle:
                    calm.append(np.linalg.norm(p - base_idle[fi], axis=1) * 100)
            L = np.linalg.norm(p[E[:, 0]] - p[E[:, 1]], axis=1)
            stretch = np.maximum(stretch, np.abs(L / np.maximum(L0, 1e-9) - 1))
            bend = np.maximum(bend, np.abs(dihedral(p) - D0))
            Mu = np.einsum('nb,bij->nij', under_W[near], S)
            slip = np.maximum(slip, np.linalg.norm(np.einsum('nij,nj->ni', M - Mu, np.c_[C.rest, np.ones(len(C.rest))])[:, :3], axis=1))
            bvh = bvh_of(p, C.tris)
            for z in ZONES:
                n, g = z
                idx = covered[n][np.char.startswith(ugroup[n][covered[n]], g)]
                if len(idx):
                    q, nn = qs[n]
                    exposed[z] += sum(not any_wall(bvh, q[i], nn[i]) for i in idx) / len(idx)
            dirs = np.einsum('nij,nj->ni', M[:, :3, :3], radial)
            idx = np.nonzero(inner & torso)[0]
            lining += sum(not any_wall(bvh, p[i] + dirs[i] * 0.002, dirs[i] / max(np.linalg.norm(dirs[i]), 1e-9), 0.05) for i in idx) / max(len(idx), 1)
        n_f = len(cache[clip])
        sv = np.array([stretch[i].mean() if i else 0.0 for i in inc_e]) * 100
        bv = np.array([bend[i].mean() if i else 0.0 for i in inc_h])
        e = " ".join(f"{exposed[z] / n_f * 100:5.1f}" for z in ZONES)
        cm = f"{np.percentile(np.concatenate(calm), 95):.2f}/{np.concatenate(calm).max():.2f}" if calm else "-"
        print(f"[{TAG}] {row:14s} {clip:5s} | {e} | {np.median(sv[torso]):5.1f} {np.percentile(sv[torso], 95):6.1f} | {np.median(bv[torso]):5.1f} {np.percentile(bv[torso], 95):5.1f} | {np.median(slip[torso]) * 1000:5.1f} {np.percentile(slip[torso], 95) * 1000:5.1f} | {lining / n_f * 100:5.1f} | {cm}", flush=True)
