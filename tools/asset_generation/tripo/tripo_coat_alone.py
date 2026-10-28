# tripo_coat_alone.py — the STANDALONE coat (ACTOR D86) on its own, before any figure wears it (Director, 2026-10-28: "colocar a tira primeiro no
# casaco original, e mais tarde vestimos os agentes"): its hem band (tripo_common.hem_band, HEM_BAND of the coat's length) painted MAGENTA,
# rendered from the front, both sides and the back; the coat is shown as generated (1 m tall, unrigged).
# Env: DRESS_COAT (the standalone GLB), RV_OUT (folder: coat_alone.png); HEM_BAND (default 0.06).
# Usage: blender -b -P tripo_coat_alone.py
import os, sys
import numpy as np
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_coat_alone"
COAT, RV_OUT = os.environ["DRESS_COAT"], os.environ["RV_OUT"].rstrip("/")
HEM_BAND = float(os.environ.get("HEM_BAND", "0.06"))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=COAT)
ms = [o for o in bpy.data.objects if o.type == 'MESH']
if not ms:
    tc.fail(TAG, f"{COAT}: no mesh")
V = np.concatenate([tc.world_verts(o) for o in ms]); L = np.ptp(V[:, 2])
W = tc.hem_band(V, HEM_BAND * L)
print(f"[{TAG}] {os.path.basename(COAT)}: {len(V)} vertices, length {L:.3f}; hem band {HEM_BAND * 100:.0f} % of it: {int((W > 0).sum())} vertices")
os.makedirs(RV_OUT, exist_ok=True)
cam, co = tc.setup_renders(ms, {o.name: (0.80, 0.35, 0.30) for o in ms})
off = 0
for o in ms:
    m = bpy.data.materials.new("rv_band"); m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1.0, 0.0, 1.0, 1)
    o.data.materials.append(m); bi = len(o.data.materials) - 1
    for p in o.data.polygons:
        if all(W[off + v] > 0 for v in p.vertices):
            p.material_index = bi
    off += len(o.data.vertices)
ctr = Vector(((V.min(0) + V.max(0)) / 2).tolist()); files = {}
for c_, az in enumerate((0, 90, 270, 180)):
    files[(0, c_)] = f"{RV_OUT}/a_{c_}.png"; tc.shot(cam, co, files[(0, c_)], az, ctr, 1.15 * L)
tc.sheet(1, 4, files, f"{RV_OUT}/coat_alone.png"); print(f"[{TAG}] sheet {RV_OUT}/coat_alone.png")
