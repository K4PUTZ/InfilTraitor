# tripo_skirt_fix.py — the final skin weights of the DRESSED coat (ACTOR D91 / MOVEMENT MV-3, 2026-11-01). tripo_dress fits a standalone coat and gives it the
# weights of the nearest point of the generation's coat, where Tripo bound the skirt's hem to the HANDS (the pose it binds in): in a run the hem followed the arms
# and the coat flew out as one sheet (measured on the bank's `run`: 188 stretched edges per frame, the hem band 134 of 137 vertices on a forearm). This applies
# tripo_common.coat_fix (the rule tripo_coat_weights / tripo_assemble already use on the segmented coat) to the finished coat, every vertex eligible: the
# forearm / hand are stripped off the body and skirt, the skirt hangs from the hips and follows the thighs. After it the same run measures 130 and reads as a coat.
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
tc.write_weights(coat, W1)
print(f"[{TAG}] {len(V)} coat verts, H {H:.3f}; hips z {st['hz']:.3f} knee z {st['kz']:.3f} hem z {st['hem']:.3f}; on the arm {st['on_arm']}; "
      f"stripped of forearm/hand {st['stripped']}; skirt re-weighted {st['skirt']}")
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {OUT}")
