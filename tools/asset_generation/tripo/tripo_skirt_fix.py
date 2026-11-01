# tripo_skirt_fix.py — the final skin weights of the DRESSED coat (ACTOR D91 / MOVEMENT MV-3, 2026-11-01). tripo_dress fits a standalone coat and gives it the
# weights of the nearest point of the generation's coat, where Tripo bound the skirt's hem to the HANDS (the pose it binds in): in a run the hem followed the arms
# and the coat flew out as one sheet (measured on the bank's `run`: 188 stretched edges per frame, the hem band 134 of 137 vertices on a forearm). This applies
# tripo_common.coat_fix (the rule tripo_coat_weights / tripo_assemble already use on the segmented coat) to the finished coat, every vertex eligible: the
# forearm / hand are stripped off the body and skirt, the skirt hangs from the hips and follows the thighs. After it the same run measures 130 and reads as a coat.
# (2) SMOOTH (2026-11-01, Director: the sleeves and the upper body still tore in a run): the weights above the skirt are diffused over the welded mesh (SMOOTH_ITERS
# passes of SMOOTH_LAM toward the neighbours' mean; the skirt under the hips keeps its deliberate rule). Measured on the male's walk / run: 53 -> 6 and 128 -> 91 stretched
# edges per frame at 3 passes, 45 at 8; at 6 the sleeves read clean from the front and the side with the arm still inside them, at 20 they start to blur.
# Runs LAST, on the finished GLB (after tripo_lod, uv, head map): on the full-resolution coat before the reduction the same rules measured 63 on the run, on the light
# coat itself 26 (the reduction does not keep a skin cut for the dense mesh). SMOOTH_ITERS scales with the mesh: 6 for the light, ~10 for the full.
# Env: SKIRT_IN (a finished Agent GLB: the Mixamo rig, the slots, Outfit_Coat), SKIRT_OUT, SKIRT_ARM_R, SMOOTH_ITERS, SMOOTH_LAM.  Usage: blender -b -P tripo_skirt_fix.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc

TAG = "tripo_skirt_fix"
GLB, OUT = os.environ["SKIRT_IN"], os.environ["SKIRT_OUT"]

arm, P, B, meshes = tc.load(TAG, GLB)
coat = bpy.data.objects.get("Outfit_Coat")
if coat is None or not coat.vertex_groups:
    tc.fail(TAG, f"{GLB}: no skinned Outfit_Coat")
V = tc.world_verts(coat); W0 = tc.read_weights(coat)
head_top = max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name in ("Outfit_Hat", "Body_Head"))
H = float(head_top - min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name == "Outfit_Shoes"))   # the figure's height, hat included
tc.ARM_R = float(os.environ.get("SKIRT_ARM_R", "0.045"))   # the sleeve radius (fractions of H): 0.055 left the coat's flank on the arm, 0.045 measured best (walk 3, run 26 stretched edges)
W1, st = tc.coat_fix(V, W0, B, P, H, np.ones(len(V), bool))
if st["hem"] is None:
    tc.fail(TAG, f"{GLB}: no skirt found below the hips")
SMOOTH_ITERS = int(os.environ.get("SMOOTH_ITERS", "6")); SMOOTH_LAM = float(os.environ.get("SMOOTH_LAM", "0.5"))
if SMOOTH_ITERS > 0:
    key = {}; rep = np.zeros(len(V), int)                 # a GLB splits vertices at every UV seam: weld by position, or the seam would keep two different skins
    for i, q in enumerate(np.round(V / 1e-5).astype(np.int64)):
        rep[i] = key.setdefault(tuple(q), i)
    # a neighbour of the other class (sleeve / torso) counts SMOOTH_CROSS. 1.0 (unrestricted) tears least (walk 0, run 26); a hard split kept the shirt in (14 px at the game
    # camera on the walk) but left the armhole torn (run 139), and the middle values trade one for the other, so the shirt's lateral faces are removed instead (3 below)
    sleeve = np.array([sum(x for n, x in w.items() if "Arm" in n or "Hand" in n or "Shoulder" in n) > 0.5 for w in W1])
    nb = [set() for _ in V]
    for e in coat.data.edges:
        a, b = rep[e.vertices[0]], rep[e.vertices[1]]
        if a != b:
            nb[a].add(b); nb[b].add(a)
    bones = sorted({n for w in W1 for n in w}); col = {n: j for j, n in enumerate(bones)}
    M = np.zeros((len(V), len(bones)))
    for i, w in enumerate(W1):
        for n, x in w.items():
            M[i, col[n]] = x
    hold = V[:, 2] < st["hz"] - 0.04 * H                   # the skirt keeps its own rule
    CROSS = float(os.environ.get("SMOOTH_CROSS", "1.0"))        # a neighbour of the other class (sleeve / torso) counts this much
    todo = [r for r in np.unique(rep) if not hold[r] and nb[r]]
    nbl = {r: (np.array(sorted(nb[r])), np.array([1.0 if sleeve[q] == sleeve[r] else CROSS for q in sorted(nb[r])])) for r in todo}
    for _ in range(SMOOTH_ITERS):
        M2 = M.copy()
        for r in todo:
            q, wq = nbl[r]; M2[r] = (1 - SMOOTH_LAM) * M[r] + SMOOTH_LAM * (M[q] * wq[:, None]).sum(0) / wq.sum()
        M = M2
        M[:] = M[rep]
    W1 = [tc.top4({bones[j]: float(M[i, j]) for j in np.nonzero(M[i] > 1e-3)[0]}, P + "Hips") for i in range(len(V))]
tc.write_weights(coat, W1)
print(f"[{TAG}] {len(V)} coat verts, H {H:.3f}; hips z {st['hz']:.3f} knee z {st['kz']:.3f} hem z {st['hem']:.3f}; on the arm {st['on_arm']}; "
      f"stripped of forearm/hand {st['stripped']}; skirt re-weighted {st['skirt']}")
# (3) LATERAL FACES (2026-11-01): the coat covers the flanks in every pose, so the shirt and the belt keep only what the front opening shows; the faces of the dressed
# shirt / belt on the sides of the torso (mean |x| between SIDE_X and SIDE_MAX, from the hips to a hand above the armpit) are never seen and were the ones that showed through
# the coat's armhole when the arm swung (measured: a white patch, 112 px at the game camera on the walk). The sleeves' own faces (|x| past SIDE_MAX) stay.
import bmesh
SIDE_X = float(os.environ.get("SIDE_X", "0.055")); SIDE_MAX = float(os.environ.get("SIDE_MAX", "0.125")); SIDE_UP = float(os.environ.get("SIDE_UP", "0.05"))
z_lo, z_hi = B["Hips"][2] - 0.03 * H, min(B["LeftArm"][2], B["RightArm"][2]) + SIDE_UP * H
if SIDE_X > 0:
    for nm in ("Outfit_Shirt_Coated", "Outfit_Belt_Coated"):
        o = bpy.data.objects.get(nm)
        if o is None:
            continue
        pts = tc.world_verts(o); bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if SIDE_X <= np.mean([abs(pts[v.index][0]) for v in f.verts]) <= SIDE_MAX and all(z_lo <= pts[v.index][2] <= z_hi for v in f.verts)]
        bmesh.ops.delete(bm, geom=kill, context='FACES'); bm.to_mesh(o.data); bm.free()
        print(f"[{TAG}] {nm}: {len(kill)} lateral faces removed")
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {OUT}")
