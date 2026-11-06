# tripo_light_bake_frame.py — one frame of a bank clip of the LIGHT baked into a FIX FILE for hand editing (ACTOR D107, 2026-11-06).
# Reads a LIGHT .blend (the LOD's output, kept in ASSETS/MODELS/fit/LIGHT_<FIG>.blend; or the same file after earlier keys, so a new edit stacks on them),
# poses it on BK_FRAME of the bank's BK_CLIP with the corrective key BK_KEY held at 1, and writes the dressed set as plain posed meshes (modifiers applied,
# vertex order kept, centred on the hips, flat colours: coat black, shirt white, trousers blue) in the layout tripo_pose_fix_back.py reads. Edit vertices only
# (never add or delete one); then: PF_A=<the same LIGHT .blend> PF_FIX=<this out> PF_KEY=<BK_KEY> PF_FIG=<fig> tripo_pose_fix_back.py.
# Env: BK_FIG (female | male), BK_CLIP, BK_FRAME, BK_KEY (IdleFix | WalkFix | RunFix), BK_IN, BK_OUT.
# Usage (repo root): BK_FIG=female BK_CLIP=walk BK_FRAME=48 BK_KEY=WalkFix BK_IN=... BK_OUT=... blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_light_bake_frame.py
import os, sys
import bpy
import numpy as np

TAG = "tripo_light_bake_frame"
FIG, CLIP, KEY = os.environ.get("BK_FIG", ""), os.environ.get("BK_CLIP", ""), os.environ.get("BK_KEY", "")
if FIG not in ("female", "male") or not CLIP or KEY not in ("IdleFix", "WalkFix", "RunFix") or "BK_FRAME" not in os.environ or "BK_OUT" not in os.environ:
    sys.exit(f"[{TAG}] needs BK_FIG (female|male), BK_CLIP, BK_FRAME, BK_KEY (IdleFix|WalkFix|RunFix), BK_OUT")
FRAME = int(os.environ["BK_FRAME"])
SRC = os.path.abspath(os.environ.get("BK_IN", f"ASSETS/MODELS/fit/LIGHT_{FIG.upper()}.blend"))
OUT = os.path.abspath(os.environ["BK_OUT"])
SHOW = {"Outfit_Coat": (0.03, 0.03, 0.03), "Outfit_Shirt_Coated": (1, 1, 1), "Outfit_Trousers_Coated": (0.1, 0.2, 0.9), "Outfit_Belt_Coated": (1, 0.8, 0.1),
        "Outfit_Buckle": (1, 0.5, 0), "Outfit_Tie": (0.9, 0.05, 0.05), "Body_Head": (0.9, 0.7, 0.55), "Body_Hands": (0.9, 0.7, 0.55), "Outfit_Hat": (0.15, 0.15, 0.17),
        "Body_Hair_Hat": (0.5, 0.33, 0.15), "Outfit_Shoes": (0.1, 0.1, 0.1)}      # the DRESSED set (TripoFigure hides the whole shirt / trousers / belt and the plain hair)
HIPS = "mixamorig:Hips"

bpy.ops.wm.open_mainfile(filepath=SRC)
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
if arm.animation_data:
    arm.animation_data_clear()
arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
hip = (arm.matrix_world @ arm.data.bones[HIPS].head_local).z
before_a, before_o = set(bpy.data.actions), set(bpy.data.objects)
bpy.context.view_layer.objects.active = None
bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/ANIMATIONS/bank/{FIG}/{CLIP}.glb"))
act = [a for a in bpy.data.actions if a not in before_a][0]
for o in [o for o in bpy.data.objects if o not in before_o]:
    bpy.data.objects.remove(o)
for fc in ([fc for la in act.layers for s in la.strips for cb in s.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)):
    if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
        for k in fc.keyframe_points:
            k.co.y *= hip; k.handle_left.y *= hip; k.handle_right.y *= hip
ad = arm.animation_data or arm.animation_data_create(); ad.action = act
if len(getattr(act, "slots", [])):
    ad.action_slot = act.slots[0]
arm.data.pose_position = 'POSE'
for o in bpy.data.objects:
    if o.type == 'MESH' and o.data.shape_keys:
        for k in o.data.shape_keys.key_blocks[1:]:
            if k.name in ("IdleFix", "WalkFix", "RunFix"):
                k.value = 1.0 if k.name == KEY else 0.0
bpy.context.scene.frame_set(FRAME); bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
hp = arm.matrix_world @ arm.pose.bones[HIPS].head
off = (-hp.x, -hp.y, 0.0)
made = []
for o in list(bpy.data.objects):
    if o.type != 'MESH' or o.name not in SHOW:
        continue
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    new = bpy.data.objects.new(o.name + "_fix", me); bpy.context.scene.collection.objects.link(new)
    new.matrix_world = o.matrix_world; new.location = off
    m = bpy.data.materials.new(o.name); m.diffuse_color = (*SHOW[o.name], 1.0); me.materials.append(m)
    made.append((o.name, new))
missing = [n for n in SHOW if n not in {n for n, _ in made}]
if missing:
    sys.exit(f"[{TAG}] {SRC}: no piece named {missing}")
for o in [o for o in bpy.data.objects if o.type in ('MESH', 'ARMATURE') and not o.name.endswith("_fix")]:
    bpy.data.objects.remove(o)
for n, new in made:
    new.name = new.data.name = n
sc = bpy.context.scene
sc["run_fix"] = f"{CLIP} frame {FRAME}, hips offset {off}"; sc["run_fix_frame"] = FRAME; sc["run_fix_clip"] = CLIP
sc["run_fix_off"] = [float(off[0]), float(off[1]), 0.0]     # the SAME as the objects' location: tripo_pose_fix_back subtracts it (a flipped sign moved every vertex 82 cm, 2026-11-06)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[{TAG}] {CLIP} frame {FRAME}, {KEY} at 1: {len(made)} pieces -> {OUT}")
