# tripo_hair_brim_cut.py — the hair under a hat the Director seated by hand (ACTOR D106 step 2, 2026-11-05: "precisamos só cortar o cabelo acima da linha da aba").
# Reads HAT_FIT_<FIG>.blend (never saved over), fits the BRIM's plane (least squares through the hat's outermost ring: the vertices farthest from the
# crown's vertical axis, HB_RIM of them), and writes `Body_Hair_Hat`: a copy of `Body_Hair` SECTIONED by that plane lowered HB_DROP (default 4 mm),
# every crossing face split along it and what lies above removed. `Body_Hair` stays whole (the hat-off state).
# Out: HB_OUT (default ASSETS/MODELS/fit/HAT_CUT_<FIG>.blend). Env: HB_FIG, HB_RIM (fraction, default 0.12), HB_DROP (metres).
import os, sys
import bpy, bmesh
import numpy as np
FIG = os.environ["HB_FIG"]
OUT = os.path.abspath(os.environ.get("HB_OUT", f"ASSETS/MODELS/fit/HAT_CUT_{FIG.upper()}.blend"))
RIM = float(os.environ.get("HB_RIM", "0.12"))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/fit/HAT_FIT_{FIG.upper()}.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
hat = bpy.data.objects["Outfit_Hat"]; hair = bpy.data.objects["Body_Hair"]
H = np.array([(hat.matrix_world @ v.co)[:] for v in hat.data.vertices])
ctr = H[:, :2].mean(0); r = np.linalg.norm(H[:, :2] - ctr, axis=1)
rim = H[r >= np.quantile(r, 1 - RIM)]
A = np.c_[rim[:, 0], rim[:, 1], np.ones(len(rim))]
a, b, c = np.linalg.lstsq(A, rim[:, 2], rcond=None)[0]
print(f"[tripo_hair_brim_cut] brim plane z = {a:.3f} x + {b:.3f} y + {c:.4f} from {len(rim)} rim vertices (tilt {np.degrees(np.arctan(np.hypot(a, b))):.1f} deg)")
cut = hair.copy(); cut.data = hair.data.copy(); cut.name = "Body_Hair_Hat"; hair.users_collection[0].objects.link(cut)
mw = cut.matrix_world
bm = bmesh.new(); bm.from_mesh(cut.data)
# A SECTION, not a face cull (Director, 2026-11-05: "bem rente à aba, sem deletar mechas inteiras, mas sim uma secção horizontal, com o mesmo formato
# das abas"): the hair is bisected by the brim's plane lowered by HB_DROP (the plane runs through the rim's middle; the underside is a few mm lower),
# every face crossing it split along it, and what lies above removed.
DROP = float(os.environ.get("HB_DROP", "0.004"))
n = np.array([-a, -b, 1.0]); n /= np.linalg.norm(n)
p0 = np.array([ctr[0], ctr[1], a * ctr[0] + b * ctr[1] + c - DROP])
inv = mw.inverted()
from mathutils import Vector
lp0 = inv @ Vector(p0); ln = (inv.to_3x3().transposed().inverted() @ Vector(n)).normalized()
n0 = len(bm.faces)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=lp0, plane_no=ln, clear_outer=True)
dead = [None] * (n0 - len(bm.faces))
bm.to_mesh(cut.data); bm.free()
hair.hide_set(True); hair.hide_render = True
print(f"[tripo_hair_brim_cut] {FIG}: the hair sectioned {DROP*1000:.0f} mm under the brim plane: {n0} faces -> {len(cut.data.polygons)} -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
