# tripo_coat_transfer.py — the LIGHT coat's map is DERIVED from the FULL coat's master (CHARACTER §7a TX-6, ACTOR D108, 2026-11-06).
# The coat cannot share one projection the way the head does (an open garment with a lining, lapels, sleeves: the FULL and the LIGHT carry UVs
# of their own), so each texel of the LIGHT coat's UV is placed on the LIGHT surface (its rest shape, the Basis) and read where a ray from 6 mm off it, back
# along its face's normal, meets the FULL (so the lining finds the lining, the outer wall the outer wall: the two lie ~8 mm apart; the nearest point is the fallback)
# coat through the FULL's UV. Nobody paints the LIGHT map: retouch the master (tripo_coat_regions on the FULL, or by hand) and re-run this.
# Env: CT_LIGHT (the LIGHT Agent GLB), CT_FULL (a GLB with the FULL coat at the same rest: AGENT_<FIG>_BASE_A.glb), CT_MASTER (the FULL coat's
# PNG), CT_OUT (PNG), CT_RES (1024).  Usage: blender -b -P tripo_coat_transfer.py
import os, sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_coat_transfer"
RES = int(os.environ.get("CT_RES", "1024"))


def coat_of(glb):
    arm, P, B, meshes = tc.load(TAG, glb)
    c = next((o for o in meshes if o.name.split(".")[0] == "Outfit_Coat"), None)
    if c is None or not c.data.uv_layers:
        tc.fail(TAG, f"{glb}: no Outfit_Coat with UVs")
    me = c.data; M = c.matrix_world
    V = np.array([(M @ v.co)[:] for v in me.vertices])                   # the Basis (shape keys at 0)
    uvl = me.uv_layers[0].data
    tris, uvs = [], []
    for p in me.polygons:
        li = list(p.loop_indices); vi = list(p.vertices)
        for k in range(1, len(vi) - 1):
            tris.append((vi[0], vi[k], vi[k + 1])); uvs.append([uvl[li[0]].uv[:], uvl[li[k]].uv[:], uvl[li[k + 1]].uv[:]])
    return V, np.array(tris), np.array(uvs)


Vf, Tf, Uf = coat_of(os.environ["CT_FULL"])
bvh = BVHTree.FromPolygons([tuple(v) for v in Vf], [tuple(t) for t in Tf])
src = bpy.data.images.load(os.path.abspath(os.environ["CT_MASTER"])); sw, sh = src.size
MASTER = np.array(src.pixels[:], np.float32).reshape(sh, sw, 4)[:, :, :3]       # rows bottom-up
Vl, Tl, Ul = coat_of(os.environ["CT_LIGHT"])
out = np.zeros((RES, RES, 3), np.float32); done = np.zeros((RES, RES), bool)
n_hit = 0
for t in range(len(Tl)):
    P = Vl[Tl[t]]; q = Ul[t] * RES - 0.5
    nrm = np.cross(P[1] - P[0], P[2] - P[0]); ln = np.linalg.norm(nrm)
    if ln < 1e-12:
        continue
    nrm /= ln
    x0, y0 = np.maximum(np.floor(q.min(0)).astype(int), 0); x1, y1 = np.minimum(np.ceil(q.max(0)).astype(int), RES - 1)
    if x1 < x0 or y1 < y0:
        continue
    ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    (ax, ay), (bx, by), (cx, cy) = q
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-12:
        continue
    w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den; w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den; w2 = 1 - w0 - w1
    ins = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02) & ~done[ys, xs]
    for yy, xx, a, b, c in zip(ys[ins], xs[ins], w0[ins], w1[ins], w2[ins]):
        p3 = a * P[0] + b * P[1] + c * P[2]
        # a ray from 6 mm off the face, back along its normal: from outside an outer face meets the outer wall first, from the body's
        # side a lining face meets the lining first (the nearest point alone picked the other wall in spots: black flecks on the yellow coat)
        hit = bvh.ray_cast(Vector(p3 + nrm * 0.006), Vector(-nrm), 0.014)
        if hit[0] is None:
            hit = bvh.find_nearest(Vector(p3 + nrm * 0.002))
        if hit[0] is None:
            continue
        fi = hit[2]; A, Bv, C = Vf[Tf[fi]]
        # barycentrics of the hit on the FULL triangle
        v0, v1, v2 = Bv - A, C - A, np.array(hit[0][:]) - A
        d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
        dd = d00 * d11 - d01 * d01
        if abs(dd) < 1e-18:
            continue
        bb = (d11 * d20 - d01 * d21) / dd; cc = (d00 * d21 - d01 * d20) / dd; aa = 1 - bb - cc
        u, v = aa * Uf[fi][0] + bb * Uf[fi][1] + cc * Uf[fi][2]
        out[yy, xx] = MASTER[int(np.clip(v % 1.0 * sh, 0, sh - 1)), int(np.clip(u % 1.0 * sw, 0, sw - 1))]
        done[yy, xx] = True; n_hit += 1
for _ in range(8):                                                       # bleed past the islands (filtering, mipmaps)
    grown = done.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh_ = np.roll(np.roll(done, dy, 0), dx, 1); s_ = np.roll(np.roll(out, dy, 0), dx, 1)
        take = sh_ & ~grown; out[take] = s_[take]; grown |= take
    done = grown
tc.write_png(os.environ["CT_OUT"], (np.clip(out[::-1], 0, 1) * 255 + 0.5).astype(np.uint8))
print(f"[{TAG}] {n_hit} texels read from the FULL coat; wrote {os.environ['CT_OUT']} ({RES} px)")
