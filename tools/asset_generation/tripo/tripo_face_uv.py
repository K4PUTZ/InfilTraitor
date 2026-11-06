# tripo_face_uv.py — the head's PAINTABLE UV and the maps its painting starts from (CHARACTER §7a TX-2, ACTOR D108, 2026-11-06).
# Why: the painted head maps were Tripo's atlas re-packed by a smart projection on a mesh split at Tripo's seams (hundreds of islands, nothing a
# hand or a script can paint). The new UV, `FaceUV`, is a CYLINDRICAL projection about the head's vertical axis, a FUNCTION OF THE POSITION: the
# FULL and the LIGHT head (a reduction of the same surface) get the same UV from it, so ONE master map serves both (the LIGHT takes it downscaled)
# and nothing is baked twice. The face is upright and frontal in it (u = the angle round the head, the front at u = 0.5; v = the height), its
# front +-FRONT_DEG of angle taking FRONT_SHARE of the width; the seam runs down the back, under the hair.
# Overlaps (an ear over the cheek behind it, the male's eyeballs behind his lids) are settled the way a camera on the axis would: the surface
# farthest from the axis owns the texel (a depth test on the radius).
# This script (Blender) writes, for the FULL head at FU_RES: the params (FU_PARAMS, JSON: the axis, the height range, the remap; read again by
# tripo_face_apply.py), and, per texel, Tripo's colour read through Tripo's own UVs (FU_OUT/<fig>_base.png), the surface point and normal
# (`_pos.npy`, `_nrm.npy`, float16), whether the hair covers it seen from outside along the normal (`_hair.npy`, at FU_RES/4) and the valid mask.
# The painting itself is tripo_face_paint.py (plain Python), from these files.
# Env: FU_FIG (female | male), FU_IN (the base A .blend; default ASSETS/MODELS/base/AGENT_<FIG>_A.blend), FU_SRC (the raw Tripo GLB with the atlas,
# default ASSETS/MODELS/sources/tripo_<fig>_base.glb), FU_OUT (folder), FU_PARAMS (JSON out), FU_RES (2048).  Usage: blender -b -P tripo_face_uv.py
import json, math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc
import face_uv_map as fm

TAG = "tripo_face_uv"
FIG = os.environ["FU_FIG"]; F = FIG.upper()
IN = os.environ.get("FU_IN", f"ASSETS/MODELS/base/AGENT_{F}_A.blend")
SRC = os.environ.get("FU_SRC", f"ASSETS/MODELS/sources/tripo_{FIG}_base.glb")
OUT = os.environ["FU_OUT"]; PARAMS = os.environ["FU_PARAMS"]; RES = int(os.environ.get("FU_RES", "2048"))
os.makedirs(OUT, exist_ok=True)

# Tripo's atlas, as an array
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
atl = [im for im in bpy.data.images if "basecolor" in im.name.lower()]
if not atl:
    tc.fail(TAG, f"{SRC}: no base colour image")
aw, ah = atl[0].size
ATLAS = np.array(atl[0].pixels[:], np.float32).reshape(ah, aw, 4)[:, :, :3]      # rows bottom-up, sRGB-encoded values (Blender keeps the file's bytes)

bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
for a in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    a.data.pose_position = 'REST'
bpy.context.view_layer.update()
def piece(n):
    s = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.split(".")[0] == n]
    return s[0] if s else None
head, hair = piece("Body_Head"), piece("Body_Hair")
if head is None or "UVMap" not in head.data.uv_layers:
    tc.fail(TAG, f"{IN}: no Body_Head with Tripo's UVMap")
dg = bpy.context.evaluated_depsgraph_get()
me = head.evaluated_get(dg).to_mesh(); me.calc_loop_triangles()
M = head.matrix_world
V = np.array([(M @ v.co)[:] for v in me.vertices])
prm = fm.params_from_head(V)
json.dump(prm, open(PARAMS, "w"), indent=1)
print(f"[{TAG}] params {prm}")
tri_v = np.array([lt.vertices[:] for lt in me.loop_triangles])
tri_l = np.array([lt.loops[:] for lt in me.loop_triangles])
uvl = me.uv_layers["UVMap"].data
TUV = np.array([uvl[i].uv[:] for i in range(len(me.loops))])                      # Tripo's UV per loop
P = V[tri_v]                                                                         # (T, 3, 3)
UV = fm.tri_uv(P, prm)                                                               # (T, 3, 2) FaceUV, seam-fixed per triangle
R = fm.radius(P, prm)                                                                # (T, 3)
N = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]); N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
# rasterise: per texel the triangle and its barycentrics, the farthest surface from the axis winning
depth = np.full((RES, RES), -1.0, np.float32); tid = np.full((RES, RES), -1, np.int32); bary = np.zeros((RES, RES, 3), np.float32)
for t in range(len(P)):
    q = UV[t] * RES - 0.5                                                            # texel centres at integer coordinates
    x0, y0 = np.floor(q.min(0)).astype(int); x1, y1 = np.ceil(q.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, RES - 1), min(y1, RES - 1)
    if x1 < x0 or y1 < y0:
        continue
    ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    (ax, ay), (bx, by), (cx, cy) = q
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-12:
        continue
    w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    w2 = 1 - w0 - w1
    ins = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
    if not ins.any():
        continue
    r = w0 * R[t, 0] + w1 * R[t, 1] + w2 * R[t, 2]
    yy, xx = ys[ins], xs[ins]; rr = r[ins]
    win = rr > depth[yy, xx]
    yy, xx = yy[win], xx[win]
    depth[yy, xx] = rr[win]; tid[yy, xx] = t
    bary[yy, xx] = np.stack([w0[ins][win], w1[ins][win], w2[ins][win]], -1)
valid = tid >= 0
ti = np.where(valid, tid, 0)
pos = np.einsum("hwk,hwkc->hwc", bary, P[ti])
nrm = N[ti]
tuv = np.einsum("hwk,hwkc->hwc", bary, TUV[tri_l[ti]])
ax_ = np.clip((tuv[..., 0] % 1.0) * aw, 0, aw - 1).astype(int); ay_ = np.clip((tuv[..., 1] % 1.0) * ah, 0, ah - 1).astype(int)
base = ATLAS[ay_, ax_]                                                               # nearest: the atlas has 2x the texels of the master on the face
base[~valid] = 0
# the hair seen from outside: a ray from the surface point along the normal, at RES/4
hb = None
if hair is not None:
    hm = hair.evaluated_get(dg).to_mesh(); HM = hair.matrix_world
    hb = BVHTree.FromPolygons([(HM @ v.co)[:] for v in hm.vertices], [tuple(p.vertices) for p in hm.polygons])
    hair.evaluated_get(dg).to_mesh_clear()
S = RES // 4
cov = np.zeros((S, S), np.float32)
if hb is not None:
    for y in range(S):
        for x in range(S):
            yy, xx = y * 4 + 2, x * 4 + 2
            if not valid[yy, xx]:
                continue
            o = Vector(pos[yy, xx]); d = Vector(nrm[yy, xx])
            hit = hb.ray_cast(o + d * 1e-4, d, 0.05)
            cov[y, x] = 1.0 if hit[0] is not None else 0.0
# rows top-down for the files (image convention): Blender's v runs bottom-up
flip = lambda a: a[::-1].copy()
tc.write_png(f"{OUT}/{FIG}_base.png", (np.clip(flip(base), 0, 1) * 255 + 0.5).astype(np.uint8))
np.save(f"{OUT}/{FIG}_pos.npy", flip(pos).astype(np.float16)); np.save(f"{OUT}/{FIG}_nrm.npy", flip(nrm).astype(np.float16))
np.save(f"{OUT}/{FIG}_valid.npy", flip(valid)); np.save(f"{OUT}/{FIG}_hair.npy", flip(cov))
print(f"[{TAG}] {FIG}: {int(valid.sum())} texels of {RES * RES} on the head ({100.0 * valid.mean():.1f} %), hair covers {100.0 * cov[flip(valid)[2::4, 2::4]].mean():.1f} %; wrote {OUT}")
