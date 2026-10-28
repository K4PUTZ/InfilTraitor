# tripo_coat_alone.py — the STANDALONE coat (ACTOR D86) on its own, before any figure wears it (Director, 2026-10-28: "colocar a tira primeiro no
# casaco original, e mais tarde vestimos os agentes"): its hem band (tripo_common.hem_band, HEM_BAND of the coat's length) painted MAGENTA,
# rendered from the front, both sides and the back; the coat is shown as generated (1 m tall, unrigged).
# Env: DRESS_COAT (the standalone GLB), RV_OUT (folder: coat_alone.png); HEM_BAND (default 0.06).
# Usage: blender -b -P tripo_coat_alone.py
import os, sys
import numpy as np
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_coat_alone"
COAT, RV_OUT = os.environ["DRESS_COAT"], os.environ["RV_OUT"].rstrip("/")
HEM_BAND = float(os.environ.get("HEM_BAND", "0.06"))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=COAT)
ms = [o for o in bpy.data.objects if o.type == 'MESH']
if not ms:
    tc.fail(TAG, f"{COAT}: no mesh")
# the HEM PIECE (Director, 2026-10-28: "seccionar a base do casaco, transformar em uma peca separada"): the coat is CUT HEM_BAND above
# the hem and what lies under the cut becomes its own mesh, Outfit_Coat_Hem
import bmesh, math
bpy.context.view_layer.objects.active = ms[0]
for o in ms:
    o.select_set(True)
if len(ms) > 1:
    bpy.ops.object.join()
coat = bpy.context.view_layer.objects.active; coat.name = "Outfit_Coat"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
V = tc.world_verts(coat); L = np.ptp(V[:, 2]); lo = V.min(0); c = V[V[:, 2] < lo[2] + 0.5 * L, :2].mean(0)
HEM_FRONT = float(os.environ.get("HEM_FRONT", "0.02"))      # a fraction of the length (tripo_common.hem_plane)
p0, nrm = tc.hem_plane(V, HEM_BAND * L, HEM_FRONT * L)
bm = bmesh.new(); bm.from_mesh(coat.data)
res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector(p0.tolist()), plane_no=Vector(nrm.tolist()))
cut = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMVert)]
bm.faces.index_update()
ids = set(f_.index for f_ in bm.faces if (np.array(f_.calc_center_median()[:]) - p0) @ nrm < 0)
bm.to_mesh(coat.data); bm.free(); coat.data.update()
for el in (*coat.data.vertices, *coat.data.edges):
    el.select = False
for p in coat.data.polygons:
    p.select = p.index in ids
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
hemo = [o for o in bpy.data.objects if o.type == 'MESH' and o is not coat][0]; hemo.name = "Outfit_Coat_Hem"
print(f"[{TAG}] {os.path.basename(COAT)}: length {L:.3f}; cut {HEM_BAND * 100:.0f} % above the hem (a plane tilted {math.degrees(math.acos(nrm[2])):.1f} deg): "
      f"{len(cut)} vertices on the cut, hem piece {len(hemo.data.polygons)} faces, coat {len(coat.data.polygons)}")


# SUPPORT pieces (Director, 2026-10-28: "as tiras de apoio na gola ou nas mangas"): the COLLAR (above a level plane COLLAR_BAND under the
# coat's top) and each CUFF (beyond a plane across the sleeve, CUFF_BAND of the length back from its tip along the sleeve's axis) cut off
# the same way, each its own mesh; the plane cuts only the faces in its region, so it never crosses the rest of the coat
COLLAR_BAND = float(os.environ.get("COLLAR_BAND", "0.08")); CUFF_BAND = float(os.environ.get("CUFF_BAND", "0.06"))


def cut_piece(o, p0, n, region, name):
    """cut `o` by the plane (p0, n) inside `region` (a test on a face centre) and separate what lies on the -n side into `name`"""
    bm = bmesh.new(); bm.from_mesh(o.data)
    rf = [f_ for f_ in bm.faces if region(np.array(f_.calc_center_median()[:]))]
    geom = list({e for f_ in rf for e in f_.edges}) + list({v for f_ in rf for v in f_.verts}) + rf
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(p0.tolist()), plane_no=Vector(n.tolist()))
    bm.faces.index_update()
    ids_ = set(f_.index for f_ in bm.faces if region(np.array(f_.calc_center_median()[:]))
               and (np.array(f_.calc_center_median()[:]) - p0) @ n < 0)
    bm.to_mesh(o.data); bm.free(); o.data.update()
    for el in (*o.data.vertices, *o.data.edges):
        el.select = False
    for p_ in o.data.polygons:
        p_.select = p_.index in ids_
    before = set(bpy.data.objects); bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
    new = [x for x in bpy.data.objects if x not in before][0]; new.name = name
    print(f"[{TAG}] {name}: {len(new.data.polygons)} faces")
    return new


V = tc.world_verts(coat); top = V[:, 2].max()
collar = cut_piece(coat, np.array([c[0], c[1], top - COLLAR_BAND * L]), np.array([0.0, 0.0, -1.0]),
                   lambda q: q[2] > top - 0.25 * L, "Outfit_Coat_Collar")
cuffs = []
for sgn, nm in ((1, "Outfit_Coat_CuffL"), (-1, "Outfit_Coat_CuffR")):
    V = tc.world_verts(coat); sl = V[(V[:, 0] - c[0]) * sgn > 0.25 * L]
    m_ = sl.mean(0); ax = np.linalg.eigh(np.cov((sl - m_).T))[1][:, -1]
    if ax[0] * sgn < 0:
        ax = -ax
    tip = sl[np.argmax((sl - m_) @ ax)]; p_c = tip - ax * CUFF_BAND * L
    cuffs.append(cut_piece(coat, p_c, -ax, lambda q, s_=sgn: (q[0] - c[0]) * s_ > 0.25 * L, nm))
ms = [coat, hemo, collar, *cuffs]; V = np.concatenate([tc.world_verts(o) for o in ms])
os.makedirs(RV_OUT, exist_ok=True)
cam, co = tc.setup_renders(ms, {"Outfit_Coat": (0.80, 0.35, 0.30), "Outfit_Coat_Hem": (1.0, 0.0, 1.0), "Outfit_Coat_Collar": (0.1, 0.8, 0.9),
                                "Outfit_Coat_CuffL": (0.95, 0.85, 0.1), "Outfit_Coat_CuffR": (0.95, 0.85, 0.1)})
ctr = Vector(((V.min(0) + V.max(0)) / 2).tolist()); files = {}
for c_, az in enumerate((0, 90, 270, 180)):
    files[(0, c_)] = f"{RV_OUT}/a_{c_}.png"; tc.shot(cam, co, files[(0, c_)], az, ctr, 1.15 * L)
tc.sheet(1, 4, files, f"{RV_OUT}/coat_alone.png"); print(f"[{TAG}] sheet {RV_OUT}/coat_alone.png")
