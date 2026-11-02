# tripo_back_trim.py — the shirt's back never shows under the coat, but its collar / yoke lies within millimetres INSIDE the coat's back and flecks through it when the torso leans in a run
# (Director, 2026-11-01: small white holes on the coat's back). Deleting those faces also cut the collar's wings and left a notch beside the neck (the Director saw it from the front), so the
# vertices are TUCKED instead: every coated shirt / tie / belt vertex behind the body's centre (y > BACK_Y) that lies inside the coat or less than 4 mm outside it (rest pose) and nearer than TUCK_MM to it is moved along
# the coat's normal to TUCK_MM inside it. Vertices farther outside (the collar's wings) are untouched.  Env: BT_IN, BT_OUT, TUCK_MM (12), BACK_Y (0).
# Usage: blender -b -P tripo_back_trim.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_back_trim"
arm, P, B, meshes = tc.load(TAG, os.environ["BT_IN"])
coat = bpy.data.objects["Outfit_Coat"]
tree = BVHTree.FromPolygons([tuple(v) for v in tc.world_verts(coat)], [tuple(p.vertices) for p in coat.data.polygons])
MM = float(os.environ.get("TUCK_MM", "12")) / 1000.0; Y0 = float(os.environ.get("BACK_Y", "0"))
for nm in ("Outfit_Shirt_Coated", "Outfit_Tie", "Outfit_Belt_Coated"):
    o = bpy.data.objects.get(nm)
    if o is None:
        continue
    inv = o.matrix_world.inverted(); n = 0
    for v in o.data.vertices:
        q = o.matrix_world @ v.co
        if q.y <= Y0:
            continue
        loc, nor, _i, d = tree.find_nearest(q)
        if loc is not None and d < MM and (q - loc).dot(nor) < 0.004:
            v.co = inv @ (loc - nor * MM); n += 1
    print(f"[{TAG}] {nm}: {n} back vertices tucked {MM * 1000:.0f} mm inside the coat")
tc.export(os.environ["BT_OUT"], meshes, arm)
