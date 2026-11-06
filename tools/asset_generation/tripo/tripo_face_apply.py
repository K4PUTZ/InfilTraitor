# tripo_face_apply.py — a head WEARS its master (CHARACTER §7a TX-4, ACTOR D108, 2026-11-06): Body_Head of an Agent GLB gets FaceUV (face_uv_map,
# with the params tripo_face_uv.py took on the FULL head of the same figure) as its UVMap and the master map, downscaled to FA_RES, as its only
# image. The LIGHT is a reduction of the FULL surface, so the projection lands its texels where the master was painted: nothing is re-baked or
# painted on the LIGHT, and a retouch of the master reaches every head of the figure at the next run.
# Env: FA_IN (Agent GLB), FA_OUT (GLB), FA_PARAMS (the figure's FaceUV params JSON), FA_MASTER (the painted master PNG), FA_MAP_OUT (the PNG the
# head carries: the master at FA_RES), FA_RES (512).  Usage: blender -b -P tripo_face_apply.py
import json, os, sys
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc
import face_uv_map as fm

TAG = "tripo_face_apply"
prm = json.load(open(os.environ["FA_PARAMS"]))
RES = int(os.environ.get("FA_RES", "512")); MAP = os.environ["FA_MAP_OUT"]
arm, P, B, meshes = tc.load(TAG, os.environ["FA_IN"])
heads = [o for o in meshes if o.name.split(".")[0] == "Body_Head"]
if not heads:
    tc.fail(TAG, f"{os.environ['FA_IN']}: no Body_Head")
# the master at the head's resolution (Blender's own scaler: no PIL here)
src = bpy.data.images.load(os.path.abspath(os.environ["FA_MASTER"]))
if src.size[0] != RES:
    src.scale(RES, RES)
src.filepath_raw = os.path.abspath(MAP); src.file_format = 'PNG'; src.save()
for head in heads:
    me = head.data; M = head.matrix_world
    Vw = np.array([(M @ v.co)[:] for v in me.vertices])
    for nm in [u.name for u in me.uv_layers]:
        me.uv_layers.remove(me.uv_layers[nm])
    uvl = me.uv_layers.new(name="UVMap").data
    for poly in me.polygons:
        U = fm.uv(Vw[list(poly.vertices)], prm)
        if U[:, 0].max() - U[:, 0].min() > 0.5:                          # across the back seam: keep the polygon's corners together
            U[:, 0] = np.where(U[:, 0] < 0.5, U[:, 0] + 1.0, U[:, 0])
        for k, li in enumerate(poly.loop_indices):
            uvl[li].uv = U[k]
    me.materials.clear(); me.materials.append(tc.textured_material("Body_Head_tex", MAP))
    print(f"[{TAG}] {head.name}: FaceUV on {len(me.polygons)} faces, map {MAP} ({RES} px)")
tc.export(os.environ["FA_OUT"], meshes, arm)
print(f"[{TAG}] wrote {os.environ['FA_OUT']}")
