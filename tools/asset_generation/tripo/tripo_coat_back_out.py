# tripo_coat_back_out.py — the coat's back stands OUT_MM further from the body (Director, 2026-11-01: "puxar o casaco mais pra fora poucos mm"). The shirt's collar / yoke and the coat's back
# move a little differently in a run and the shirt showed through; tucking the shirt (tripo_back_trim) was not enough. Every coat vertex behind the body's centre (y > BACK_Y) and within NEAR_MM of the
# shirt / tie / belt moves along its (welded, averaged) normal by OUT_MM, fading to nothing over FADE_MM further from them.  The skirt's back below the hips moves SKIRT_MM (7) whatever lies behind it (the calf crossed it). Env: BO_IN, BO_OUT, OUT_MM (4), NEAR_MM (25), SKIRT_MM (7), BACK_Y (0).
# Runs before tripo_coat_push (the push data reads the coat's final positions).  Usage: blender -b -P tripo_coat_back_out.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc
from mathutils import Vector
from mathutils.kdtree import KDTree

TAG = "tripo_coat_back_out"
arm, P, B, meshes = tc.load(TAG, os.environ["BO_IN"])
coat = bpy.data.objects["Outfit_Coat"]
OUT = float(os.environ.get("OUT_MM", "4")) / 1000.0; NEAR = float(os.environ.get("NEAR_MM", "25")) / 1000.0; Y0 = float(os.environ.get("BACK_Y", "0")); SKIRT = float(os.environ.get("SKIRT_MM", "7")) / 1000.0; hz = float(B["Hips"][2])
pts = np.concatenate([tc.world_verts(bpy.data.objects[n]) for n in ("Outfit_Shirt_Coated", "Outfit_Tie", "Outfit_Belt_Coated") if n in bpy.data.objects])
kd = KDTree(len(pts))
for i, q in enumerate(pts):
    kd.insert(q, i)
kd.balance()
V = tc.world_verts(coat); me = coat.data
me.calc_normals() if hasattr(me, "calc_normals") else None
N = np.array([(coat.matrix_world.to_3x3() @ v.normal)[:] for v in me.vertices])
key = {}; acc = {}
for i, q in enumerate(np.round(V / 1e-4).astype(np.int64)):
    k = tuple(q); key[i] = k; acc[k] = acc.get(k, 0) + N[i]
inv = coat.matrix_world.inverted(); n = 0
for i, v in enumerate(me.vertices):
    if V[i][1] <= Y0:
        continue
    d = kd.find(Vector(V[i]))[2]
    if V[i][2] < hz:                                    # the skirt's back (Director: the calf crossed it): SKIRT_MM further out, whatever lies behind it
        d, amount = 0.0, SKIRT
    elif d > NEAR:
        continue
    else:
        amount = OUT
    nn = acc[key[i]]; ln = np.linalg.norm(nn)
    if ln < 1e-6:
        continue
    f = float(np.clip(1.0 - (d / NEAR) ** 2, 0.0, 1.0)) if d > NEAR * 0.5 else 1.0     # full within half of NEAR, easing out to NEAR
    v.co = inv @ Vector(V[i] + nn / ln * amount * f); n += 1
print(f"[{TAG}] {n} coat back vertices moved out up to {OUT * 1000:.0f} mm")
tc.export(os.environ["BO_OUT"], meshes, arm)
