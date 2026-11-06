# tripo_hair_hat_mask.py — the hair under a hat the Director seated (ACTOR D106 step 2), cut WITH THE HAT ITSELF as the mask
# (Director, 2026-11-06: "Não é mais fácil usar o próprio chapéu como máscara?"; replaces tripo_hair_brim_cut.py's planes and height fields).
# The hat is copied, and `Body_Hair_Hat` = `Body_Hair` minus every part the hat lies under (an inside test and an exact
# edge split; Blender's boolean mangles the open locks). What lies inside the hat goes, every lock under the brim stays up to it, so the hair meets the brim. `Body_Hair` stays whole.
# Reads the base AGENT_<FIG>_A.blend + the hat of fit/HAT_FIT_<FIG>.blend (neither saved over); writes HM_OUT (default fit/HAT_CUT_<FIG>.blend).
# Env: HM_FIG (female | male), HM_HOLE (edges of the largest hole to fill, default 400), HM_GROW (the solid inflated along its normals, default 0).
# Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_hair_hat_mask.py
import os, sys
import bpy, bmesh

TAG = "tripo_hair_hat_mask"
FIG = os.environ.get("HM_FIG", "")
if FIG not in ("female", "male"):
    sys.exit(f"[{TAG}] HM_FIG must be female or male")
OUT = os.path.abspath(os.environ.get("HM_OUT", f"ASSETS/MODELS/fit/HAT_CUT_{FIG.upper()}.blend"))
HOLE = int(os.environ.get("HM_HOLE", "400"))
GROW = float(os.environ.get("HM_GROW", "0.0"))

bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(os.path.abspath(f"ASSETS/MODELS/fit/HAT_FIT_{FIG.upper()}.blend"), link=False) as (fr, to):
    to.objects = ["Outfit_Hat"]
hat = to.objects[0]; bpy.context.scene.collection.objects.link(hat)
hair = bpy.data.objects["Body_Hair"]

# the solid: the hat in world space, its opening closed
solid = bpy.data.objects.new("HatSolid", bpy.data.meshes.new("HatSolid")); bpy.context.scene.collection.objects.link(solid)
sb = bmesh.new(); sb.from_mesh(hat.data); sb.transform(hat.matrix_world)
bmesh.ops.remove_doubles(sb, verts=sb.verts, dist=1e-5)
open0 = sum(1 for e in sb.edges if e.is_boundary)
# Tripo's hat is CLOSED: a lid spans its opening under the crown (at the opening's height, 1-2 cm under the band at the temples), which would
# mask the hair under the brim. The lid = the downward faces lying inside the opening (radius from the crown's axis under HM_LID_R of the hat's
# radius span) in the lower half of the crown; it is removed from the MASK only (the hat itself is untouched).
import numpy as np
P = np.array([v.co[:] for v in sb.verts]); cx, cy = P[:, 0].mean(), P[:, 1].mean()
R = np.hypot(P[:, 0] - cx, P[:, 1] - cy)
LID_R = float(os.environ.get("HM_LID_R", "0.42"))
r_lid = R.min() + LID_R * (R.max() - R.min())
z_mid = P[:, 2].min() + 0.5 * (P[:, 2].max() - P[:, 2].min())
lid = [f for f in sb.faces if f.normal.z < -0.3 and f.calc_center_median().z < z_mid
       and np.hypot(f.calc_center_median().x - cx, f.calc_center_median().y - cy) < r_lid]
bmesh.ops.delete(sb, geom=lid, context='FACES_ONLY')
print(f"[{TAG}] the hat's lid under the crown: {len(lid)} faces removed from the mask (radius under {r_lid*1000:.0f} mm)")
bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
if GROW:
    for v in sb.verts:
        v.co += v.normal * GROW
open1 = 0
sb.to_mesh(solid.data); sb.free()

cut = hair.copy(); cut.data = hair.data.copy(); cut.name = "Body_Hair_Hat"; hair.users_collection[0].objects.link(cut)
# Masked = inside the hat OR over it (the hat straight below the point: locks poking out of the crown). The mask applied by hand (Blender's boolean keeps arbitrary pieces of an OPEN mesh like these locks): a hair vertex is INSIDE the hat when a ray
# from it crosses the closed solid an odd number of times; the hair is triangulated, every edge from inside to outside is split exactly where it
# meets the hat's surface (a ray along the edge), the crossed triangles are split along those points, and the inside vertices are removed.
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sm = bmesh.new(); sm.from_mesh(solid.data); st = BVHTree.FromBMesh(sm)
mw = cut.matrix_world; inv = mw.inverted()
DIRS = (Vector((0.31, 0.77, 0.56)).normalized(), Vector((-0.62, 0.21, -0.75)).normalized(), Vector((0.83, -0.49, 0.27)).normalized())


def inside(p):
    # masked = the hat lies straight BELOW the point: the locks poking out of the crown and those inside the felt. The hat stays OPEN (a cap
    # closing its tilted opening hung 1-2 cm under the band at the temples and took the hair under the brim, 2026-11-06), so every lock under the
    # brim and inside the crown's hollow is kept: the first meets the brim, the second is hidden by the hat.
    return st.ray_cast(p, Vector((0, 0, -1)), 0.3)[0] is not None


bm = bmesh.new(); bm.from_mesh(cut.data)
n0 = len(bm.faces)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
ins = {v: inside(mw @ v.co) for v in bm.verts}
split = []
for e in list(bm.edges):
    a, b = e.verts
    if ins[a] != ins[b]:
        pa, pb = mw @ a.co, mw @ b.co
        d = pb - pa; L = d.length
        h = st.ray_cast(pa, d.normalized(), L)
        t = 0.5 if h[0] is None else (h[0] - pa).length / L
        ne, nv = bmesh.utils.edge_split(e, a, t)
        ins[nv] = False; split.append(nv)
sv = set(split)
for fc in list(bm.faces):
    on = [v for v in fc.verts if v in sv]
    if len(on) == 2:
        bmesh.ops.connect_verts(bm, verts=on)
gone = [v for v in bm.verts if ins.get(v, False)]
bmesh.ops.delete(bm, geom=gone, context='VERTS')
bm.to_mesh(cut.data); bm.free(); sm.free()
bpy.data.objects.remove(solid)
hair.hide_set(True); hair.hide_render = True
print(f"[{TAG}] {FIG}: hat solid open edges {open0} -> {open1}; hair {n0} faces -> {len(cut.data.polygons)} ({len(gone)} vertices inside the hat, {len(split)} on its surface) -> {OUT}")
if open1:
    print(f"[{TAG}] WARNING: the hat solid is not closed ({open1} open edges); raise HM_HOLE")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
