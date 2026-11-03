# tripo_hidden_delete_test.py — does deleting the SAFE hidden faces change a single pixel? (ACTOR D97, 2026-11-03.) Companion of `tripo_hidden_study.py`: renders the worn figure (coat off, every current piece) in flat Workbench from the board's four facings x pitches
# 30 / 45, over the A, the T and frames of every clip in the file, once untouched (HS_DELETE=0) and once with the SAFE faces of the kept pieces deleted (HS_DELETE=1, hidden_safe_<mesh>.json from the study). The two runs are compared pixel by pixel outside (a gate has to be
# EARNED: two untouched runs must differ by 0). HS_DILATE (n rings of faces next to a seen one are kept). Env: GLB, HS_STUDY (the study's out dir), HS_OUT, HS_DELETE (0/1), HS_MESHES ("Outfit_Shirt,Outfit_Trousers").   Usage: blender -b -P tripo_hidden_delete_test.py
import json, math, os
import bpy, bmesh
from mathutils import Matrix, Quaternion, Vector
OUT = os.environ["HS_OUT"]; os.makedirs(OUT, exist_ok=True)
DELETE = os.environ.get("HS_DELETE", "0") == "1"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.environ["GLB"]))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
CLIPS = {a.name: tuple(a.frame_range) for a in bpy.data.actions}
meshes = {o.name: o for o in bpy.data.objects if o.type == 'MESH' and o.name != "Icosphere"}
WORN = ["Body_Hair", "Body_Hands", "Body_Head", "Outfit_Belt", "Outfit_Buckle", "Outfit_Shirt", "Outfit_Shoes", "Outfit_Tie", "Outfit_Trousers"]
for n, o in meshes.items():
    o.hide_render = n not in WORN
if DELETE:
    removed = 0
    for n in os.environ.get("HS_MESHES", "Outfit_Shirt,Outfit_Trousers").split(","):
        idx = set(json.load(open(os.path.join(os.environ["HS_STUDY"], f"hidden_safe_{n}.json"))))
        bm = bmesh.new(); bm.from_mesh(meshes[n].data); bm.faces.ensure_lookup_table()
        for _ in range(int(os.environ.get("HS_DILATE", "0"))):       # a hidden face that touches a seen one may be seen in a sliver (surfaces that cross): it stays
            keep = {f.index for f in bm.faces if f.index not in idx and False}
            seen_v = {v.index for f in bm.faces if f.index not in idx for v in f.verts}
            idx = {i for i in idx if not any(v.index in seen_v for v in bm.faces[i].verts)}
        bmesh.ops.delete(bm, geom=[bm.faces[i] for i in idx], context='FACES_ONLY')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        removed += len(idx); bm.to_mesh(meshes[n].data); bm.free()
    print(f"deleted {removed} faces")
fig = "FEMALE" if "FEMALE" in os.path.basename(os.environ["GLB"]).upper() else "MALE"
SHARE = 0.5 if fig == "FEMALE" else 0.25
arm.data.pose_position = 'POSE'
bpy.context.view_layer.objects.active = arm
arm.animation_data_clear()
bpy.ops.object.mode_set(mode='POSE')
rest = {b.name: Matrix(b.matrix_local) for b in arm.data.bones}
def pose(t):
    """The arms raised toward the T by t (0 = the A rest): the same turn `tripo_fit_tpose.py` makes, a share on the collarbone, the rest on the arm."""
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    if t <= 0:
        return
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        a = arm.data.bones[f"mixamorig:{side}Arm"]; f = arm.data.bones[f"mixamorig:{side}ForeArm"]; sb = arm.data.bones[f"mixamorig:{side}Shoulder"]
        d = (f.head_local - a.head_local).normalized(); q = d.rotation_difference(Vector((sx, 0, 0)))
        qs = Quaternion().slerp(q, SHARE * t); hs = sb.head_local
        pbs = arm.pose.bones[f"mixamorig:{side}Shoulder"]
        pbs.matrix = (Matrix.Translation(hs) @ qs.to_matrix().to_4x4() @ Matrix.Translation(-hs)) @ rest[sb.name]
        bpy.context.view_layer.update()
        pb = arm.pose.bones[f"mixamorig:{side}Arm"]; pf = arm.pose.bones[f"mixamorig:{side}ForeArm"]
        d2 = (pf.head - pb.head).normalized(); q2 = Quaternion().slerp(d2.rotation_difference(Vector((sx, 0, 0))), t); h2 = pb.head.copy()
        pb.matrix = (Matrix.Translation(h2) @ q2.to_matrix().to_4x4() @ Matrix.Translation(-h2)) @ pb.matrix
        bpy.context.view_layer.update()



bpy.ops.object.mode_set(mode='OBJECT')
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
sc.render.resolution_x, sc.render.resolution_y = 600, 800; sc.view_settings.view_transform = 'Standard'; sc.render.film_transparent = False
for o in meshes.values():
    o.color = (0.55, 0.6, 0.7, 1)
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.5; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
c = Vector((0, 0, 0.62))
POSES = [("A", None, 0.0), ("T", None, 1.0)]
for cname, (f0, f1) in CLIPS.items():
    for k in range(3):
        POSES.append((f"{cname}{k}", cname, f0 + (f1 - f0) * k / 2.0))
n = 0
for pname, clip, t in POSES:
    if clip is None:
        arm.animation_data_clear(); bpy.ops.object.mode_set(mode='POSE'); pose(t); bpy.ops.object.mode_set(mode='OBJECT')
    else:
        arm.animation_data_create(); arm.animation_data.action = bpy.data.actions[clip]; sc.frame_set(int(round(t))); bpy.context.view_layer.update()
    for yaw in (0, 90, 180, 270):
        for pit in (30, 45):
            y, p = math.radians(yaw), math.radians(pit)
            d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))).normalized()
            co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(OUT, f"{pname}_{yaw}_{pit}.png"); bpy.ops.render.render(write_still=True); n += 1
print(f"rendered {n}")
