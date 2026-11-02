# tripo_back_trim.py — the shirt's back never shows under the coat, but its collar / yoke lies within millimetres of the coat's back and flecks through it when the torso leans in a run
# (Director, 2026-11-01: small white holes on the coat's back). Every face of the coated shirt / tie / belt with a vertex behind the body's centre (y > BACK_Y) and within
# BACK_MM of the coat (rest pose) is removed. Env: BT_IN, BT_OUT, BACK_MM (12), BACK_Y (0.03: the collar's sides, y 0.02, stay).  Usage: blender -b -P tripo_back_trim.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import tripo_common as tc
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_back_trim"
arm, P, B, meshes = tc.load(TAG, os.environ["BT_IN"])
coat = bpy.data.objects["Outfit_Coat"]
tree = BVHTree.FromPolygons([tuple(v) for v in tc.world_verts(coat)], [tuple(p.vertices) for p in coat.data.polygons])
MM = float(os.environ.get("BACK_MM", "12")) / 1000.0; Y0 = float(os.environ.get("BACK_Y", "0.03"))
for nm in ("Outfit_Shirt_Coated", "Outfit_Tie", "Outfit_Belt_Coated"):
    o = bpy.data.objects.get(nm)
    if o is None:
        continue
    V = tc.world_verts(o)
    near = np.array([q[1] > Y0 and tree.find_nearest(Vector(q))[3] < MM for q in V])
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if any(near[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context='FACES'); bm.to_mesh(o.data); bm.free()
    print(f"[{TAG}] {nm}: {len(kill)} back faces removed")
tc.export(os.environ["BT_OUT"], meshes, arm)
