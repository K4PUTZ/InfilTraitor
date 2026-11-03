# tripo_shirt_tidy.py — relax the shirt where the T-pose STRETCHED it (ACTOR D97, 2026-11-03, Director: "conferir as emendas dos braços nas T poses ... em cima dos ombros e nas áreas das axilas, deixar a malha organizada e a camisa agradável de olhar").
# In the T the arm's bones drag the shirt's armhole: edges stretch to 2-3x their A length and the torso's side shows fins. A plain Laplacian over the shirt (`tripo_coat_fit_round.py` with ROUND_OBJ) tore it apart (2026-11-03): the mesh splits a vertex wherever a UV / normal
# seam passes, and each copy moved on its own. This script (1) WELDS the copies by their A position, so a neighbour is a place, never a copy; (2) measures, per place, the largest edge stretch T / A over its welded edges; (3) builds the mask from THAT (smoothstep TT_S0..TT_S1,
# grown TT_GROW rings with a falloff), so only what the pose really stretched is touched, and (4) runs Taubin (lambda | mu, no shrink) on the places with the mask as strength, writing the result to every copy. Neighbours that face away (normals' dot < TT_NORMAL) are ignored so one layer never pulls on the other.
# Works IN PLACE on a T file (a plain mesh whose vertices ARE the pose). Env: TT_IN (the T .blend), TT_REF (the A .blend the T was baked from: same topology), TT_OBJ (Outfit_Shirt), TT_ITERS (30), TT_S0 (1.3), TT_S1 (2.0), TT_GROW (2), TT_NORMAL (0.2).   Usage: blender -b -P tripo_shirt_tidy.py
import os
import numpy as np
import bpy

TAG = "tripo_shirt_tidy"
OBJ = os.environ.get("TT_OBJ", "Outfit_Shirt")
ITERS = int(os.environ.get("TT_ITERS", "30")); S0, S1 = float(os.environ.get("TT_S0", "1.3")), float(os.environ.get("TT_S1", "2.0"))
GROW = int(os.environ.get("TT_GROW", "2")); THR = float(os.environ.get("TT_NORMAL", "0.2"))
LAM, MU = 0.5, -0.53


def world_positions(o):
    mw = np.array(o.matrix_world)
    return np.array([v.co[:] for v in o.data.vertices]) @ mw[:3, :3].T + mw[:3, 3]


bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["TT_REF"]))
A = world_positions(bpy.data.objects[OBJ])
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["TT_IN"]))
o = bpy.data.objects[OBJ]; me = o.data
T = world_positions(o)
assert len(T) == len(A), f"{OBJ}: {len(T)} vertices in T, {len(A)} in A"
# 1. weld the copies by their A position
key = np.round(A * 1e5).astype(np.int64)
_, place = np.unique(key, axis=0, return_inverse=True); place = place.ravel(); NP = place.max() + 1
Nrm = np.array([(o.matrix_world.to_3x3() @ v.normal)[:] for v in me.vertices])
pn = np.zeros((NP, 3)); np.add.at(pn, place, Nrm); pn /= np.maximum(np.linalg.norm(pn, axis=1, keepdims=True), 1e-9)   # a place's normal: the mean of its copies'
PA = np.zeros((NP, 3)); PT = np.zeros((NP, 3)); cnt = np.zeros(NP)
np.add.at(PA, place, A); np.add.at(PT, place, T); np.add.at(cnt, place, 1); PA /= cnt[:, None]; PT /= cnt[:, None]
edges = {(min(place[a], place[b]), max(place[a], place[b])) for a, b in (e.vertices for e in me.edges) if place[a] != place[b]}
E = np.array(sorted(edges))
la = np.linalg.norm(PA[E[:, 0]] - PA[E[:, 1]], axis=1); lt = np.linalg.norm(PT[E[:, 0]] - PT[E[:, 1]], axis=1)
ratio = np.where(la > 1e-5, lt / np.maximum(la, 1e-9), 1.0)
# 2. per place: the largest stretch of its edges
stretch = np.ones(NP)
for k in (0, 1):
    np.maximum.at(stretch, E[:, k], ratio)
t = np.clip((stretch - S0) / (S1 - S0), 0, 1); m = t * t * (3 - 2 * t)
nb = [[] for _ in range(NP)]
for a, b in E:
    nb[a].append(b); nb[b].append(a)
for _ in range(GROW):                                                  # the mask grows, weaker at each ring: the relaxed zone blends into the untouched one
    g = m.copy()
    for i in range(NP):
        if nb[i]:
            g[i] = max(m[i], 0.6 * max(m[j] for j in nb[i]))
    m = g
print(f"[{TAG}] {OBJ}: {NP} places, stretch max {stretch.max():.2f}, {int((stretch > S0).sum())} stretched, mask > 0.5 on {int((m > 0.5).sum())}, > 0 on {int((m > 0).sum())}")
nbf = [[j for j in l if pn[i] @ pn[j] >= THR] for i, l in enumerate(nb)]
idx = np.nonzero(m > 0)[0]


def step(P, f):
    Q = P.copy()
    for i in idx:
        if nbf[i]:
            Q[i] = P[i] + f * m[i] * (P[nbf[i]].mean(0) - P[i])
    return Q


P = PT.copy()
for _ in range(ITERS):
    P = step(step(P, LAM), MU)
delta = (P - PT)[place]                                               # the move of a place, given to every copy of it
print(f"[{TAG}] largest move {np.linalg.norm(delta, axis=1).max() * 1000:.1f} mm over {ITERS} iterations")
newT = T + delta
mw = np.array(o.matrix_world); inv = np.linalg.inv(mw)
newco = (newT - mw[:3, 3]) @ inv[:3, :3].T
me.vertices.foreach_set("co", newco.ravel().astype(np.float32)); me.update()
bpy.ops.wm.save_mainfile()
print(f"[{TAG}] wrote {os.environ['TT_IN']}")
