# tripo_chains_to_hips.py — the coat's skirt chains (D88) go (Director, 2026-11-01: "tira as molas"). With the legs' push (D94) doing the collision, the spring simulator added almost nothing
# visible and is state; a chain bone nobody animates is the Hips under another name. Every coat_skirt_* weight is given to Hips and the bones are removed (24 fewer joints per Agent).
# Runs after tripo_skirt_fix, before tripo_coat_push.  Env: CH_IN, CH_OUT.  Usage: blender -b -P tripo_chains_to_hips.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc

TAG = "tripo_chains_to_hips"
arm, P, B, meshes = tc.load(TAG, os.environ["CH_IN"])
moved = 0
for o in meshes:
    W = tc.read_weights(o); out = []
    for w in W:
        if any(n.startswith("coat_skirt_") for n in w):
            h = {n: x for n, x in w.items() if not n.startswith("coat_skirt_")}
            h[P + "Hips"] = h.get(P + "Hips", 0.0) + sum(x for n, x in w.items() if n.startswith("coat_skirt_"))
            w = tc.top4(h, P + "Hips"); moved += 1
        out.append(w)
    tc.write_weights(o, out)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
dead = [b.name for b in arm.data.edit_bones if b.name.startswith("coat_skirt_")]
for n in dead:
    arm.data.edit_bones.remove(arm.data.edit_bones[n])
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
    for g in list(o.vertex_groups):
        if g.name in dead:
            o.vertex_groups.remove(g)
print(f"[{TAG}] {moved} vertices handed to Hips, {len(dead)} chain bones removed ({len(arm.data.bones)} left)")
tc.export(os.environ["CH_OUT"], meshes, arm)
