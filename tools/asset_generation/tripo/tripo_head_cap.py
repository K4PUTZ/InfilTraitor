# tripo_head_cap.py — the female's skull REBUILT under her hair (2026-11-05). Tripo modelled her head only as far as the hair hides it: the top is a flat
# lid at z 0.935 on the 1 m figure and the back a slanted plane down to the nape (the original part is the same), which a hat-cut hair would show.
# (A first try carried the male's crown onto the lid: a narrow dome, the back still cut. Director: "Yes, rebuild it".)
# The skull takes the shape of her own hair: from a centre in the head, every head vertex whose ray outward meets the hair is pushed out to HC_GAP
# (default 20 mm) under the hair's OUTER surface, never pulled in; where it already lies closer nothing moves, so the face, the ears and the hairline stay.
# The faces that move most are subdivided first (HC_CUTS) so the new skull is round, and the moved region is smoothed (HC_SMOOTH passes). The weights
# interpolate with the subdivision; the UVs are redone later by tripo_head_map. Printed: how many vertices moved, by how much, the clearance left.
# Reads ASSETS/MODELS/base/AGENT_FEMALE_A.blend (never saved over); writes HC_OUT (default ASSETS/MODELS/fit/HEAD_CAP_FEMALE.blend).
# Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_head_cap.py
import os
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_head_cap"
OUT = os.path.abspath(os.environ.get("HC_OUT", "ASSETS/MODELS/fit/HEAD_CAP_FEMALE.blend"))
GAP = float(os.environ.get("HC_GAP", "0.020"))   # under the hair's OUTER surface (the male's hair stands 2.1 cm over his skull)
CUTS = int(os.environ.get("HC_CUTS", "2"))
SMOOTH = int(os.environ.get("HC_SMOOTH", "4"))
DEEP = 0.005      # a head vertex more than this under its target is part of the cut skull

bpy.ops.wm.open_mainfile(filepath=os.path.abspath("ASSETS/MODELS/base/AGENT_FEMALE_A.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
head = bpy.data.objects["Body_Head"]; hair = bpy.data.objects["Body_Hair"]
mw = head.matrix_world; inv = mw.inverted()
V0 = np.array([(mw @ v.co)[:] for v in head.data.vertices])
hair.data.calc_loop_triangles()
hb = BVHTree.FromPolygons([hair.matrix_world @ v.co for v in hair.data.vertices], [tuple(t.vertices) for t in hair.data.loop_triangles])
# the centre: over the ears, between the face and the back of the hair
C = Vector((V0[:, 0].mean(), V0[:, 1].mean(), V0[:, 2].min() + 0.65 * (V0[:, 2].max() - V0[:, 2].min())))


def target(p):
    """the radius from C the skull should reach along p's direction (the hair's inner surface less GAP), or None where no hair lies outward"""
    d = (p - C)
    if d.length < 1e-6:
        return None
    d.normalize()
    far = C + d * 0.3                       # her hair's locks run INSIDE the head (a ray out from C meets one 1-3 cm away): read its OUTER surface, inward
    hit = hb.ray_cast(far, -d, 0.3)
    return None if hit[0] is None else (hit[0] - C).length - GAP


bm = bmesh.new(); bm.from_mesh(head.data)
def deep(v):
    p = mw @ v.co; t = target(p)
    return t is not None and t - (p - C).length > DEEP
deep_faces = [f for f in bm.faces if any(deep(v) for v in f.verts)]
edges = list({e for f in deep_faces for e in f.edges})
if CUTS > 0 and edges:
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=CUTS, use_grid_fill=True)
moved = []; push = []
for v in bm.verts:
    p = mw @ v.co; t = target(p)
    r = (p - C).length
    if t is not None and t > r:
        v.co = inv @ (C + (p - C).normalized() * t); moved.append(v); push.append(t - r)
for _ in range(SMOOTH):
    new = {}
    for v in moved:
        nb = [e.other_vert(v) for e in v.link_edges]
        if nb:
            avg = sum((n.co for n in nb), Vector()) / len(nb)
            new[v] = v.co.lerp(avg, 0.5)
    for v, c in new.items():
        p = mw @ c; t = target(p)
        v.co = c if t is None else inv @ (C + (p - C).normalized() * min((p - C).length, t))
bm.to_mesh(head.data); bm.free()
head.data.update()
gaps = []
for v in head.data.vertices:
    p = mw @ v.co; t = target(p)
    if t is not None:
        gaps.append(t + GAP - (p - C).length)
gaps = np.array(gaps)
print(f"[{TAG}] {len(V0)} -> {len(head.data.vertices)} vertices; {len(moved)} pushed out (median {np.median(push)*100:.1f} cm, max {max(push)*100:.1f} cm)")
print(f"[{TAG}] under the hair: clearance min {gaps.min()*1000:.1f} mm, median {np.median(gaps)*1000:.1f} mm; top {max((mw @ v.co).z for v in head.data.vertices):.4f} (was {V0[:, 2].max():.4f}) -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
