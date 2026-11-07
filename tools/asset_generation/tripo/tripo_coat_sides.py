# tripo_coat_sides.py — which wall of the coat each texel is, so a face seen from its BACK shows the other wall's colour (2026-11-07).
# The coat is two walls 1.5-6 mm apart (22 mm at most on the female); the outer one is cut into panels (the back vent, the side seams, the pockets) bound to different
# legs while the lining runs on across the cuts, so in a pose a cut opens and the lining comes out through it: wedges of the lining's colour on the outside of the skirt
# (seen with the lining painted magenta: Blender's idle with no D94 push, and the game). Re-weighting the lining to its outer wall did not help (one lining vertex sits
# under two panels), and repainting the faces a pose reveals turned yellow the back lining seen through the open front, which is the same face. What differs is the SIDE
# the eye meets: through the open front, the lining's own side; from outside the coat, its back. So the map's ALPHA says the wall (1 the outer, 0 the lining) and the coat's
# shader draws a back-facing fragment in the other wall's colour; the two colours (the medians of each wall's texels) travel as the coat's `coat_sides` extras.
# Lining: a face whose normal looks at the body with the coat's outer wall within GAP outside it (tripo_coat_regions.py's rule, on the LIGHT).
# Env: CS_IN (the LIGHT Agent GLB), CS_MAP (the coat map PNG), CS_OUT (PNG, with the alpha), CS_JSON (the colours), CS_GAP (0.04 m).  Usage: blender -b -P tripo_coat_sides.py
import json, os
import numpy as np
import bpy
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_coat_sides"
GAP = float(os.environ.get("CS_GAP", "0.04"))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.environ["CS_IN"]))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
coat = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.split(".")[0] == "Outfit_Coat"][0]
P = [b.name for b in arm.data.bones if b.name.endswith("Hips")][0][:-4]
Mw = coat.matrix_world; R3 = Mw.to_3x3()
arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
cm = coat.data; RV = [Mw @ v.co for v in cm.vertices]
bvh = BVHTree.FromPolygons(RV, [tuple(p.vertices) for p in cm.polygons])
bone = lambda n: arm.matrix_world @ arm.data.bones[P + n].head_local
rh = bone("Hips")
SEGS = [(bone(a), bone(c)) for a, c in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
SEGS += [(bone(sd + a), bone(sd + c)) for sd in ("Left", "Right") for a, c in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]


def away(q):
    if q.z < rh.z:                                                       # the skirt: horizontal from the vertical through the hips
        return Vector((q.x - rh.x, q.y - rh.y, 0.0)).normalized()
    best = None
    for a, c in SEGS:
        ac = c - a; t = max(0.0, min(1.0, (q - a).dot(ac) / ac.dot(ac))); p = a + ac * t; d = (q - p).length
        if best is None or d < best[0]:
            best = (d, (q - p).normalized())
    return best[1]


lining = set()
for p in cm.polygons:
    c = sum((RV[k] for k in p.vertices), Vector()) / len(p.vertices); n = (R3 @ p.normal).normalized(); d = away(c)
    if n.dot(d) >= -0.2:
        continue
    loc, nn, fi, dist = bvh.ray_cast(c + d * 1e-4, d, GAP)
    if fi is not None and (R3 @ cm.polygons[fi].normal).normalized().dot(d) > 0.2:
        lining.add(p.index)
print(f"[{TAG}] {len(lining)} of {len(cm.polygons)} coat faces are lining (an outer wall within {GAP * 1000:.0f} mm)")

img = bpy.data.images.load(os.path.abspath(os.environ["CS_MAP"])); w, h = img.size
PX = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
wall = np.full((h, w), -1, np.int8)                                      # -1 no face, 0 lining, 1 outer
uvl = cm.uv_layers.active.data
for p in cm.polygons:
    li = list(p.loop_indices); q = np.array([uvl[k].uv[:] for k in li]) * [w, h] - 0.5
    for k in range(1, len(li) - 1):
        t = q[[0, k, k + 1]]
        x0, y0 = np.maximum(np.floor(t.min(0)).astype(int), 0); x1, y1 = np.minimum(np.ceil(t.max(0)).astype(int), [w - 1, h - 1])
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]; (ax, ay), (bx, by), (cx, cy) = t
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        a = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den; b = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        m = (a >= -0.02) & (b >= -0.02) & (1 - a - b >= -0.02)
        wall[ys[m], xs[m]] = 0 if p.index in lining else 1
covered = wall >= 0                                                       # the colours come from texels a face covers, never the bleed
for _ in range(8):                                                       # bleed past the islands, as the map's colour does (filtering, mipmaps)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        s = np.roll(np.roll(wall, dy, 0), dx, 1); take = (wall < 0) & (s >= 0); wall[take] = s[take]
wall[wall < 0] = 1
PX[:, :, 3] = wall.astype(np.float32)
lin = np.median(PX[covered & (wall == 0)][:, :3], 0); out = np.median(PX[covered & (wall == 1)][:, :3], 0)
tc.write_png(os.environ["CS_OUT"], (np.clip(PX[::-1], 0, 1) * 255 + 0.5).astype(np.uint8))   # Blender's rows run bottom-up
hexc = lambda c: "#%02X%02X%02X" % tuple(int(round(float(x) * 255)) for x in c)
json.dump({"version": 1, "outer": hexc(out), "lining": hexc(lin)}, open(os.environ["CS_JSON"], "w"))
print(f"[{TAG}] lining texels {(wall == 0).mean() * 100:.1f} %; outer {hexc(out)}, lining {hexc(lin)}; wrote {os.environ['CS_OUT']} and {os.environ['CS_JSON']}")
