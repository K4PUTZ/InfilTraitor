# tripo_skirt_fix.py — the final skin weights of the DRESSED coat (ACTOR D91 / MOVEMENT MV-3, 2026-11-01). tripo_dress fits a standalone coat and gives it the
# weights of the nearest point of the generation's coat, where Tripo bound the skirt's hem to the HANDS (the pose it binds in): in a run the hem followed the arms
# and the coat flew out as one sheet (measured on the bank's `run`: 188 stretched edges per frame, the hem band 134 of 137 vertices on a forearm). This applies
# tripo_common.coat_fix (the rule tripo_coat_weights / tripo_assemble already use on the segmented coat) to the finished coat, every vertex eligible: the
# forearm / hand are stripped off the body and skirt, the skirt hangs from the hips and follows the thighs. After it the same run measures 130 and reads as a coat.
# (2) SMOOTH (2026-11-01, Director: the sleeves and the upper body still tore in a run): the weights above the skirt are diffused over the welded mesh (SMOOTH_ITERS
# passes of SMOOTH_LAM toward the neighbours' mean; the skirt under the hips keeps its deliberate rule). Measured on the male's walk / run: 53 -> 6 and 128 -> 91 stretched
# edges per frame at 3 passes, 45 at 8; at 6 the sleeves read clean from the front and the side with the arm still inside them, at 20 they start to blur.
# Env: SKIRT_IN (a dressed GLB: the Mixamo rig, the slots, Outfit_Coat), SKIRT_OUT.  Usage: blender -b -P tripo_skirt_fix.py
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
W1, st = tc.coat_fix(V, W0, B, P, H, np.ones(len(V), bool))
if st["hem"] is None:
    tc.fail(TAG, f"{GLB}: no skirt found below the hips")
SMOOTH_ITERS = int(os.environ.get("SMOOTH_ITERS", "6")); SMOOTH_LAM = float(os.environ.get("SMOOTH_LAM", "0.5"))
if SMOOTH_ITERS > 0:
    key = {}; rep = np.zeros(len(V), int)                 # a GLB splits vertices at every UV seam: weld by position, or the seam would keep two different skins
    for i, q in enumerate(np.round(V / 1e-5).astype(np.int64)):
        rep[i] = key.setdefault(tuple(q), i)
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
    todo = [r for r in np.unique(rep) if not hold[r] and nb[r]]
    for _ in range(SMOOTH_ITERS):
        M2 = M.copy()
        for r in todo:
            M2[r] = (1 - SMOOTH_LAM) * M[r] + SMOOTH_LAM * M[list(nb[r])].mean(0)
        M = M2
        M[:] = M[rep]
    W1 = [tc.top4({bones[j]: float(M[i, j]) for j in np.nonzero(M[i] > 1e-3)[0]}, P + "Hips") for i in range(len(V))]
tc.write_weights(coat, W1)
print(f"[{TAG}] {len(V)} coat verts, H {H:.3f}; hips z {st['hz']:.3f} knee z {st['kz']:.3f} hem z {st['hem']:.3f}; on the arm {st['on_arm']}; "
      f"stripped of forearm/hand {st['stripped']}; skirt re-weighted {st['skirt']}")
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {OUT}")
