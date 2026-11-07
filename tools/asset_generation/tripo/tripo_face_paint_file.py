# tripo_face_paint_file.py — the Blender file where the Director paints a face BY HAND (CHARACTER §7a, 2026-11-07).
# The installed LIGHT Agent at rest (the game's mesh: what is painted there is where the game shows it), the hat, the hat's hair and the coat hidden,
# and the head wearing the MASTER on disk (`painted/<fig>_face_master.png`, 2048, FaceUV), linked by path, not packed: Image > Save in Blender
# writes the master itself. Afterwards: the master downscaled to 512 (`painted/<fig>_head_light.png`) goes into the Agent with
# glb_swap_image.py (never a Blender round trip of a finished Agent: CHARACTER §7a). FaceUV is a cylindrical projection interpolated per vertex,
# so a stroke on the LIGHT lands where the LIGHT shows it; the FULL head (more vertices) may read it a little off.
# A master painted by hand must never be regenerated: face_paint.json carries `"hand": true` for that figure and tripo_face_paint.py refuses
# to write over it (FP_FORCE=1 to override, which loses the hand paint).
# Env: FPF_FIG (female | male), FPF_OUT (default ASSETS/MODELS/fit/FACE_PAINT_<FIG>.blend).  Usage (repo root): blender -b -P tripo_face_paint_file.py
import os
import bpy

FIG = os.environ["FPF_FIG"]; F = FIG.upper(); ROOT = os.getcwd()
GLB = os.path.join(ROOT, f"ASSETS/MODELS/official/AGENT_{F}_LIGHT.glb")
MASTER = os.path.join(ROOT, f"ASSETS/MODELS/official/painted/{FIG}_face_master.png")
OUT = os.path.abspath(os.environ.get("FPF_OUT", f"ASSETS/MODELS/fit/FACE_PAINT_{F}.blend"))
for p in (GLB, MASTER):
    if not os.path.exists(p):
        raise SystemExit(f"[tripo_face_paint_file] missing {p}")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
for a in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    if a.animation_data:
        a.animation_data_clear()
    a.data.pose_position = 'REST'
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name.split(".")[0] in ("Outfit_Hat", "Body_Hair_Hat", "Outfit_Coat"):
        o.hide_set(True); o.hide_render = True
img = bpy.data.images.load(MASTER); img.name = f"{FIG}_face_master"
heads = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.split(".")[0] == "Body_Head"]
if not heads:
    raise SystemExit(f"[tripo_face_paint_file] {GLB}: no Body_Head")
head = heads[0]; n_tex = 0
for m in head.data.materials:
    for n in m.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            n.image = img; m.node_tree.nodes.active = n; n_tex += 1
if n_tex != 1:
    raise SystemExit(f"[tripo_face_paint_file] Body_Head has {n_tex} image nodes, expected 1")
for o in bpy.context.view_layer.objects:
    o.select_set(False)
head.select_set(True); bpy.context.view_layer.objects.active = head
for scr in bpy.data.screens:                                               # the 3D views open in Material Preview: the paint shows at once
    for area in scr.areas:
        if area.type == 'VIEW_3D':
            area.spaces[0].shading.type = 'MATERIAL'
for unused in [i for i in bpy.data.images if i is not img and i.users == 0]:
    bpy.data.images.remove(unused)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[tripo_face_paint_file] {FIG}: {OUT}, the head wearing {bpy.path.abspath(img.filepath)} ({img.size[0]} px)")
