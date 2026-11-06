# tripo_hair_brim_cut.py — the hair under a hat the Director seated by hand (ACTOR D106 step 2, 2026-11-05: "precisamos só cortar o cabelo acima da linha da aba").
# Reads HAT_FIT_<FIG>.blend (never saved over), fits the BRIM's plane (least squares through the hat's outermost ring: the vertices farthest from the
# crown's vertical axis, HB_RIM of them), and writes `Body_Hair_Hat`: a copy of `Body_Hair` without every face lying wholly above that plane
# (HB_MARGIN metres below it count as above, so no lock shows through the brim's edge). `Body_Hair` stays whole (the hat-off state).
# Out: HB_OUT (default ASSETS/MODELS/fit/HAT_CUT_<FIG>.blend). Env: HB_FIG, HB_RIM (fraction, default 0.12), HB_MARGIN (default 0.0).
import os, sys
import bpy, bmesh
import numpy as np
FIG = os.environ["HB_FIG"]
OUT = os.path.abspath(os.environ.get("HB_OUT", f"ASSETS/MODELS/fit/HAT_CUT_{FIG.upper()}.blend"))
RIM = float(os.environ.get("HB_RIM", "0.12")); MARGIN = float(os.environ.get("HB_MARGIN", "0.0"))
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
def above(v):
    p = mw @ v.co
    return p.z > a * p.x + b * p.y + c - MARGIN
dead = [f for f in bm.faces if all(above(v) for v in f.verts)]
n0 = len(bm.faces)
bmesh.ops.delete(bm, geom=dead, context='FACES')
bm.to_mesh(cut.data); bm.free()
hair.hide_set(True); hair.hide_render = True
print(f"[tripo_hair_brim_cut] {FIG}: {len(dead)} of {n0} hair faces above the brim removed -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
