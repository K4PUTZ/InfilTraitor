# tripo_hair_brim_cut.py — the hair under a hat the Director seated by hand (ACTOR D106 step 2, 2026-11-05: "precisamos só cortar o cabelo acima da linha da aba").
# Reads the base AGENT_<FIG>_A.blend and the hat of HAT_FIT_<FIG>.blend (neither saved over) and writes `Body_Hair_Hat`: a copy of `Body_Hair` SECTIONED by a
# surface that follows the hat's underside around the head (below: the lowest hat face above the vertices near the head, per angle sector), every
# crossing face split along it and what lies above removed, so the hair meets the brim. `Body_Hair` stays whole (the hat-off state). The brim PLANE
# (least squares through the hat's outermost ring: the vertices farthest from the crown's vertical axis, HB_RIM of them) is only printed, as a reference.
# Out: HB_OUT (default ASSETS/MODELS/fit/HAT_CUT_<FIG>.blend). Env: HB_FIG, HB_RIM (fraction, default 0.12), HB_BINS, HB_INNER, HB_DROP (metres, default 0).
import os, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
FIG = os.environ["HB_FIG"]
OUT = os.path.abspath(os.environ.get("HB_OUT", f"ASSETS/MODELS/fit/HAT_CUT_{FIG.upper()}.blend"))
RIM = float(os.environ.get("HB_RIM", "0.12"))
# the BASE (its head is the current one: the female's skull was rebuilt 2026-11-06), the hat appended from the Director's seated file
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(os.path.abspath(f"ASSETS/MODELS/fit/HAT_FIT_{FIG.upper()}.blend"), link=False) as (fr, to):
    to.objects = ["Outfit_Hat"]
hat = to.objects[0]; bpy.context.scene.collection.objects.link(hat); hair = bpy.data.objects["Body_Hair"]
# An appended object keeps a STALE matrix_world until the scene updates. The Director's hat carries a scale of (1.07, 1.07, 1.03) that the stale matrix
# left out: the hat was read 2.5 cm lower and 7 % narrower than where it sits, and the cut ran that far under the brim (bare temples, 2026-11-06).
bpy.context.view_layer.update()
H = np.array([(hat.matrix_world @ v.co)[:] for v in hat.data.vertices])
ctr = H[:, :2].mean(0); r = np.linalg.norm(H[:, :2] - ctr, axis=1)
rim = H[r >= np.quantile(r, 1 - RIM)]
A = np.c_[rim[:, 0], rim[:, 1], np.ones(len(rim))]
a, b, c = np.linalg.lstsq(A, rim[:, 2], rcond=None)[0]
print(f"[tripo_hair_brim_cut] (reference) brim plane z = {a:.3f} x + {b:.3f} y + {c:.4f} from {len(rim)} rim vertices (tilt {np.degrees(np.arctan(np.hypot(a, b))):.1f} deg)")
cut = hair.copy(); cut.data = hair.data.copy(); cut.name = "Body_Hair_Hat"; hair.users_collection[0].objects.link(cut)
mw = cut.matrix_world; inv = mw.inverted()
# The cut FOLLOWS THE HAT'S OPENING, not a plane (2026-11-06: a plane through the rim left the scalp bare under a curled brim): around the crown's
# vertical axis, in HB_BINS angle sectors, the cut height is the LOWEST hat SURFACE under the vertices near the head (radius under the HB_INNER
# quantile: the band / the brim's root, never its curled edge), smoothed over the neighbouring sectors and lowered by HB_DROP (default 0). Every hair
# edge crossing that surface is split exactly on it, the crossing faces split along the new vertices, and what lies above is removed.
# The surface is MEASURED, not read off the vertices: an upward ray from under the hat at each vertex's xy finds the hat's lowest face there. The root
# ring of Tripo's low-poly hat leaves some sectors with no vertex on it, and the lowest vertex of such a sector is a crown-wall one up to 2 cm above
# the brim: the male's locks then stood out of the crown all round the band (2026-11-06). A ray never answers higher than its own vertex.
BINS = int(os.environ.get("HB_BINS", "48"))
INNER = float(os.environ.get("HB_INNER", "0.55"))
DROP = float(os.environ.get("HB_DROP", "0.0"))
ang = np.arctan2(H[:, 1] - ctr[1], H[:, 0] - ctr[0])
near = r <= np.quantile(r, INNER)
hat_bm = bmesh.new(); hat_bm.from_mesh(hat.data); hat_bm.transform(hat.matrix_world)
hat_tree = BVHTree.FromBMesh(hat_bm); hat_bm.free()
z_under = H[:, 2].min() - 0.05


def hat_under(p):
    """the height of the hat's lowest face above (x, y): the first hit of an upward ray from under the hat; the vertex's own z if the ray finds nothing"""
    hit = hat_tree.ray_cast(Vector((p[0], p[1], z_under)), Vector((0.0, 0.0, 1.0)))[0]
    return hit.z if hit is not None else p[2]


zh = np.array([hat_under(p) if nr else p[2] for p, nr in zip(H, near)])
zc = np.full(BINS, np.nan)
for k in range(BINS):
    m = near & (((ang + np.pi) / (2 * np.pi) * BINS).astype(int) % BINS == k)
    if m.any():
        zc[k] = zh[m].min()
ok = ~np.isnan(zc); idx = np.arange(BINS)
zc = np.interp(idx, idx[ok], zc[ok], period=BINS)
zc = (np.roll(zc, 1) + zc + np.roll(zc, -1)) / 3.0 - DROP
print(f"[tripo_hair_brim_cut] the hat's opening: {BINS} sectors, cut height {zc.min():.4f} to {zc.max():.4f} m (drop {DROP*1000:.0f} mm)")


def f(co):
    p = mw @ co
    t = (np.arctan2(p.y - ctr[1], p.x - ctr[0]) + np.pi) / (2 * np.pi) * BINS - 0.5
    k0 = int(np.floor(t)) % BINS; w = t - np.floor(t)
    return p.z - (zc[k0] * (1 - w) + zc[(k0 + 1) % BINS] * w)


bm = bmesh.new(); bm.from_mesh(cut.data)
n0 = len(bm.faces)
fv = {v: f(v.co) for v in bm.verts}
new_verts = []
for e in list(bm.edges):
    a0, b0 = fv[e.verts[0]], fv[e.verts[1]]
    if (a0 > 0) != (b0 > 0) and abs(a0 - b0) > 1e-9:
        t = a0 / (a0 - b0)
        v0 = e.verts[0]
        ne, nv = bmesh.utils.edge_split(e, v0, t)
        fv[nv] = 0.0; new_verts.append(nv)
nvs = set(new_verts)
for face in list(bm.faces):
    on = [v for v in face.verts if v in nvs]
    if len(on) == 2:
        bmesh.ops.connect_verts(bm, verts=on)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if fv.get(v, f(v.co)) > 1e-7], context='VERTS')
bm.to_mesh(cut.data); bm.free()
hair.hide_set(True); hair.hide_render = True
print(f"[tripo_hair_brim_cut] {FIG}: the hair cut along the hat's opening: {n0} faces -> {len(cut.data.polygons)} ({len(new_verts)} section vertices) -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
