# tripo_light_compare.py — the base FULL against its reduced LIGHT (tripo_lod_base.py) on the frames the corrective keys were made on (ACTOR D106 step 1).
# For each (clip, frame, key): the figure posed on that bank frame, the key held at 1, coloured (black coat, white shirt, blue trousers) so a garment
# through the coat is SEEN; rendered from the front and the back three-quarter. One sheet: rows = (clip, frame), columns = FULL front, LIGHT front,
# FULL back, LIGHT back. Env: LC_FIG, LC_LIGHT (the light .blend), LC_OUT (PNG). Usage: blender -b --python-exit-code 1 -P tripo_light_compare.py
import os, sys, math
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

FIG = os.environ["LC_FIG"]
LIGHT = os.path.abspath(os.environ["LC_LIGHT"])
OUT = os.path.abspath(os.environ["LC_OUT"])
SHOTS = {"female": [("run", 18, "RunFix"), ("run", 12, "RunFix"), ("walk", 20, "WalkFix"), ("idle", 280, "IdleFix")],
         "male": [("run", 26, "RunFix"), ("run", 9, "RunFix"), ("run", 3, "RunFix"), ("walk", 20, "WalkFix")]}[FIG]
COL = {"Outfit_Coat": (0.03, 0.03, 0.035), "Outfit_Shirt": (0.95, 0.95, 0.95), "Outfit_Trousers": (0.15, 0.25, 0.7), "Outfit_Tie": (0.8, 0.1, 0.1),
       "Outfit_Belt": (0.9, 0.55, 0.1), "Outfit_Buckle": (0.9, 0.9, 0.2), "Outfit_Shoes": (0.1, 0.1, 0.1), "Body_Head": (0.85, 0.6, 0.5),
       "Body_Hands": (0.85, 0.6, 0.5), "Body_Hair": (0.35, 0.2, 0.1)}
TMP = os.path.dirname(OUT) + f"/cmp_{FIG}"
os.makedirs(TMP, exist_ok=True)
files = {}


def run(src, col):
    bpy.ops.wm.open_mainfile(filepath=src)
    if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    P = [b.name for b in arm.data.bones if b.name.endswith("Hips")][0][:-4]
    arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
    hip = (arm.matrix_world @ arm.data.bones[P + "Hips"].head_local).z
    show = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.split(".")[0] in COL]
    cam, co = tc.setup_renders(show, {o.name: COL[o.name.split(".")[0]] for o in show})
    bpy.context.scene.render.engine = 'BLENDER_WORKBENCH'
    bpy.context.scene.display.shading.light = 'STUDIO'; bpy.context.scene.display.shading.color_type = 'MATERIAL'
    for o in show:   # the base files keep the coat hidden from renders; workbench draws a material's viewport colour
        o.hide_render = False; o.hide_set(False); o.hide_viewport = False
        for m in o.data.materials:
            m.diffuse_color = (*COL[o.name.split(".")[0]], 1.0)
    acts = {}
    for row, (clip, frame, key) in enumerate(SHOTS):
        if clip not in acts:
            before = set(bpy.data.actions); bo = set(bpy.data.objects)
            bpy.context.view_layer.objects.active = None
            bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/ANIMATIONS/bank/{FIG}/{clip}.glb"))
            act = [a for a in bpy.data.actions if a not in before][0]
            for o in [o for o in bpy.data.objects if o not in bo]:
                bpy.data.objects.remove(o)
            fcs = [fc for la in act.layers for s in la.strips for cb in s.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
            for fc in fcs:
                if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
                    for k in fc.keyframe_points:
                        k.co.y *= hip; k.handle_left.y *= hip; k.handle_right.y *= hip
            acts[clip] = act
        ad = arm.animation_data or arm.animation_data_create(); ad.action = acts[clip]
        if len(getattr(acts[clip], "slots", [])):
            ad.action_slot = acts[clip].slots[0]
        arm.data.pose_position = 'POSE'
        for o in show:
            sk = o.data.shape_keys
            if sk:
                for kb in sk.key_blocks[1:]:
                    if kb.name in ("IdleFix", "WalkFix", "RunFix"):
                        kb.value = 1.0 if kb.name == key else 0.0
        bpy.context.scene.frame_set(frame); bpy.context.view_layer.update()
        hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head
        ctr = Vector((hp.x, hp.y, 0.5))
        for vi, az in enumerate((20, 160)):
            path = f"{TMP}/{row}_{col}_{vi}.png"
            tc.shot(cam, co, path, az, ctr, 1.15)
            files[(row, col + 2 * vi)] = path


run(os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend"), 0)
run(LIGHT, 1)
tc.sheet(len(SHOTS), 4, files, OUT)
print(f"[tripo_light_compare] {OUT}: rows {SHOTS}; columns FULL front, LIGHT front, FULL back, LIGHT back")
