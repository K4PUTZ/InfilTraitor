# tripo_fit_from_tpose.py — the way BACK from `tripo_fit_tpose.py` (ACTOR D96, 2026-11-03, Director: "vamos fazer o script ... pro A pose, em vez de arriscar ajustar e depois ficar errado mesmo assim").
# The T file (`COAT_FIT_<FIG>_T.blend`) is a working state: every skinned mesh was BAKED in the T pose with the T file's own weights, and the armature kept, per bone, the matrix that takes a point of the A rest to the T pose (`a_to_t`).
# A vertex of the T file sits at p_T = M_v p_A, M_v = sum_i (w_i A_i) / sum_i w_i over the vertex's bone groups (the armature modifier's linear blend skinning, normalised the way Blender does it). The way back is therefore
# EXACT per vertex: p_A = M_v^-1 p_T. An unedited T file returns the A file's own positions (`FT_CHECK=1` proves it, to float noise); an edit made in T comes back as the same edit expressed in the A rest.
# What is written: a COPY of the A file (`FT_OUT`) where every vertex that moved more than FT_EPS (1e-5 m) from the A file's evaluated rest takes its new position; the rest keep their exact A coordinates. A mesh with a shape key (the coat's `Fit`)
# gets the result in the `Fit` key (the key is what the A file evaluates), any other mesh in its coordinates. The A file's weights, skeleton and topology are untouched: the game's rest pose stays the original.
# Env: FT_T (the edited T .blend), FT_A (the A .blend it came from), FT_OUT (the .blend to write; unset with FT_CHECK=1), FT_CHECK (1: print the per-mesh max difference only, write nothing), FT_EPS.
# Usage: blender -b -P tripo_fit_from_tpose.py
import json, os
import numpy as np
import bpy

TAG = "tripo_fit_from_tpose"
T_PATH, A_PATH = os.path.abspath(os.environ["FT_T"]), os.path.abspath(os.environ["FT_A"])
OUT = os.environ.get("FT_OUT", "")
CHECK = os.environ.get("FT_CHECK", "0") == "1"
EPS = float(os.environ.get("FT_EPS", "1e-5"))
if not CHECK and not OUT:
    raise SystemExit(f"[{TAG}] FT_OUT is required unless FT_CHECK=1")


def skinned(o):
    return o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)


def weights(o, bones):
    """(n, nbones) weight matrix over the bone groups only (a group that names no bone, like the coat's `Rigid`, takes no part)."""
    names = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(o.data.vertices), len(bones)))
    col = {b: k for k, b in enumerate(bones)}
    for v in o.data.vertices:
        for g in v.groups:
            k = col.get(names[g.group])
            if k is not None:
                w[v.index, k] = g.weight
    return w


def world_positions(o, use_fit=True):
    me = o.data
    if use_fit and me.shape_keys and "Fit" in me.shape_keys.key_blocks:
        co = np.array([k.co[:] for k in me.shape_keys.key_blocks["Fit"].data])
    else:
        co = np.array([v.co[:] for v in me.vertices])
    mw = np.array(o.matrix_world)
    return co @ mw[:3, :3].T + mw[:3, 3], mw


# 1. the T file: the matrices, the baked positions, the weights
bpy.ops.wm.open_mainfile(filepath=T_PATH)
arm_t = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
a_to_t = {n: np.array(m) for n, m in json.loads(arm_t["a_to_t"]).items()}
bones = sorted(a_to_t)
Amat = np.stack([a_to_t[b] for b in bones])                       # (nb, 4, 4), in the armature's space
aw = np.array(arm_t.matrix_world)
aw_inv = np.linalg.inv(aw)
back = {}                                                         # object name -> world positions in the A rest
for o in bpy.data.objects:
    if not skinned(o):
        continue
    w = weights(o, bones)
    tot = w.sum(1)
    pw, _ = world_positions(o, use_fit=False)                     # the T file's mesh is baked: no shape key survives, its coordinates are the pose
    parm = (np.c_[pw, np.ones(len(pw))] @ aw_inv.T)               # armature space, homogeneous
    M = np.einsum('nb,bij->nij', w / np.maximum(tot, 1e-12)[:, None], Amat)
    still = tot <= 1e-12                                          # an unweighted vertex is not skinned at all
    M[still] = np.eye(4)
    pa = np.einsum('nij,nj->ni', np.linalg.inv(M), parm)
    back[o.name] = (pa @ aw.T)[:, :3]

# 2. the A file: compare, then write
bpy.ops.wm.open_mainfile(filepath=A_PATH)
report = []
for o in bpy.data.objects:
    if not skinned(o) or o.name not in back:
        continue
    a_ref, mw = world_positions(o)
    new = back[o.name]
    if len(new) != len(a_ref):
        raise SystemExit(f"[{TAG}] {o.name}: {len(new)} vertices in T, {len(a_ref)} in A")
    d = np.linalg.norm(new - a_ref, axis=1)
    report.append((o.name, float(d.max()), int((d > EPS).sum()), len(d)))
    if CHECK:
        continue
    moved = d > EPS
    if not moved.any():
        continue
    out_w = np.where(moved[:, None], new, a_ref)
    out_o = (out_w - mw[:3, 3]) @ np.linalg.inv(mw[:3, :3]).T
    me = o.data
    if me.shape_keys and "Fit" in me.shape_keys.key_blocks:
        for i in np.nonzero(moved)[0]:
            me.shape_keys.key_blocks["Fit"].data[int(i)].co = out_o[i]
    else:
        for i in np.nonzero(moved)[0]:
            me.vertices[int(i)].co = out_o[i]
    me.update()
for name, dmax, nmoved, n in report:
    print(f"[{TAG}] {name:18s} max |T-way-back - A| = {dmax:.3e} m, {nmoved}/{n} vertices beyond {EPS:g}")
if not CHECK:
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
    print(f"[{TAG}] wrote {OUT}")
