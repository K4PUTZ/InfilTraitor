# tripo_hidden_apply.py — delete the SAFE hidden faces of the kept pieces (shirt, trousers) from a figure's .blend (ACTOR D97, 2026-11-03, Director: "vamos descartar o que realmente não for útil, e depois conferir se não quebrou nada").
# The faces come from `tripo_hidden_study.py` (hidden_safe_<mesh>.json, polygon indices; the study runs on AGENT_<FIG>.glb, whose shirt / trousers have the same faces in the same order as the fit files': trousers identical, shirt within 5 mm, measured). A hidden face that touches
# a seen one stays (HS_DILATE rings, default 1): surfaces that cross show slivers, and without the ring the pixel test found 13 885 / 7 200 differing pixels; with it 5 / 0 (`tripo_hidden_delete_test.py`). Vertices left with no face go too; vertex groups and everything else are untouched.
# Env: HA_IN (.blend), HA_OUT (.blend), HS_STUDY (the study's out dir), HS_MESHES ("Outfit_Shirt,Outfit_Trousers"), HS_DILATE (1).   Usage: blender -b -P tripo_hidden_apply.py
import json, os
import bpy, bmesh

TAG = "tripo_hidden_apply"
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["HA_IN"]))
total = 0
for n in os.environ.get("HS_MESHES", "Outfit_Shirt,Outfit_Trousers").split(","):
    me = bpy.data.objects[n].data
    idx = set(json.load(open(os.path.join(os.environ["HS_STUDY"], f"hidden_safe_{n}.json"))))
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    if len(bm.faces) != len(me.polygons):
        raise SystemExit(f"[{TAG}] {n}: face count mismatch")
    for _ in range(int(os.environ.get("HS_DILATE", "1"))):
        seen_v = {v.index for f in bm.faces if f.index not in idx for v in f.verts}
        idx = {i for i in idx if not any(v.index in seen_v for v in bm.faces[i].verts)}
    before = (len(bm.faces), len(bm.verts))
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in idx], context='FACES_ONLY')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(me); bm.free(); me.update()
    total += len(idx)
    print(f"[{TAG}] {n}: {before[0]} -> {before[0] - len(idx)} faces ({len(idx)} deleted), {before[1]} -> {len(me.vertices)} vertices")
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.environ["HA_OUT"]))
print(f"[{TAG}] wrote {os.environ['HA_OUT']} ({total} faces deleted)")
