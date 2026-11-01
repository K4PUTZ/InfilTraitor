# tripo_coat_push.py — bakes what the legs' push needs onto the finished Agent's coat (ACTOR D94, 2026-11-01; the idea and the numbers are in `coat_push.py`): per vertex the
# outward direction, the mask and the push the rest pose already gives, and the capsule radii as the coat's `coat_push` property. Runs LAST, after tripo_skirt_fix: it
# reads the coat as finished and changes no weight and no position.
# Env: COAT_IN (a finished Agent GLB: the Mixamo rig, Outfit_Coat), COAT_OUT.  Usage: blender -b -P tripo_coat_push.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc
import coat_push as cp

TAG = "tripo_coat_push"
GLB, OUT = os.environ["COAT_IN"], os.environ["COAT_OUT"]
arm, P, B, meshes = tc.load(TAG, GLB)
coat = bpy.data.objects.get("Outfit_Coat")
if coat is None or not coat.vertex_groups:
    tc.fail(TAG, f"{GLB}: no skinned Outfit_Coat")
head_top = max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name in ("Outfit_Hat", "Body_Head"))
H = float(head_top - min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name == "Outfit_Shoes"))   # the figure's height, hat included
s, rest, mask = cp.bake(coat, arm, P, H, float(B["Hips"][2]))
print(f"[{TAG}] {len(rest)} coat vertices: {int((mask > 0.5).sum())} pushed, {int((rest > 0.002).sum())} already inside a capsule at rest (max {rest.max() * 1000:.1f} mm, taken off); "
      f"H {H:.3f}, capsules thigh {s['r_thigh']:.3f} shin {s['r_shin']:.3f} foot {s['r_foot']:.3f} + {s['delta']:.3f}")
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {OUT}")
