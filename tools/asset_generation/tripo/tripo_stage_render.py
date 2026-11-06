# tripo_stage_render.py — the SAME idle frames of one figure at a stage of the LIGHT chain, one fixed colour per piece (coat black, shirt white, trousers blue,
# belt yellow, tie red, skin, hat, hair), front view of the torso, so a leak (a white or blue sliver through the black coat) can be traced to the stage that made it
# (ACTOR D106, 2026-11-06: base -> coated cut at full resolution -> after tripo_lod_base -> final: the leaks of the female's LIGHT first showed at the LOD).
# The corrective key IdleFix is set to 1 and the others to 0; the clip is the bank's idle (frames 250..345 pass the Director's edited frame 280).
# Env: RV_IN (a .blend or a .glb), RV_MODE (base | full | coated: which set of shirt / trousers / belt shows), RV_FIG (female | male), RV_FRAMES (comma list), RV_OUT, RV_TAG.
# Usage (repo root): RV_IN=... RV_MODE=coated RV_FIG=female RV_FRAMES=250,290,330 RV_OUT=temp/renders RV_TAG=x blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_stage_render.py
import math, os
import bpy
from mathutils import Vector
SRC=os.environ["RV_IN"]; MODE=os.environ["RV_MODE"]; FIG=os.environ["RV_FIG"]; OUT=os.environ["RV_OUT"]; TAG=os.environ["RV_TAG"]
FR=[float(x) for x in os.environ["RV_FRAMES"].split(",")]; os.makedirs(OUT,exist_ok=True)
if SRC.endswith(".glb"):
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
else:
    bpy.ops.wm.open_mainfile(filepath=SRC)
sc=bpy.context.scene; arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
if arm.animation_data: arm.animation_data_clear()
coat=[o for o in bpy.data.objects if o.name in ("Outfit_Coat","Outfit_Coat.001")][0]
FULL=("Outfit_Shirt","Outfit_Trousers","Outfit_Belt"); COATED=("Outfit_Shirt_Coated","Outfit_Trousers_Coated","Outfit_Belt_Coated")
for o in bpy.data.objects:
    if o.type=='MESH':
        n=o.name
        hide = n in ("Icosphere","Body_Hair") or (MODE=="full" and n in COATED) or (MODE=="coated" and n in FULL) or (MODE=="coated_only_dummy" and False)
        if n.startswith("Outfit_Hat") or n.startswith("Body_Hair_Hat"): hide = hide or MODE=="base"
        if MODE=="base" and n in COATED: hide=True
        o.hide_render=hide; o.hide_set(hide)
coat.hide_render=False; coat.hide_set(False)
for k in coat.data.shape_keys.key_blocks:
    k.value = 1.0 if k.name=="IdleFix" else 0.0
P=[b.name for b in arm.data.bones if b.name.endswith("Hips")][0][:-4]
arm.data.pose_position='REST'; bpy.context.view_layer.update(); hip_h=(arm.matrix_world@arm.data.bones[P+"Hips"].head_local).z; arm.data.pose_position='POSE'
def fcs(act):
    if getattr(act,"layers",None): return [fc for l in act.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
    return list(getattr(act,"fcurves",[]))
bo,ba=set(bpy.data.objects),set(bpy.data.actions); bpy.ops.import_scene.gltf(filepath=f"ASSETS/ANIMATIONS/bank/{FIG}/idle.glb")
act=[a for a in bpy.data.actions if a not in ba][0]
for o in [o for o in bpy.data.objects if o not in bo]: bpy.data.objects.remove(o)
for fc in fcs(act):
    if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
        for kp in fc.keyframe_points: kp.co.y*=hip_h; kp.handle_left.y*=hip_h; kp.handle_right.y*=hip_h
ad=arm.animation_data or arm.animation_data_create(); ad.action=act
if len(getattr(act,"slots",[])): ad.action_slot=act.slots[0]
COL={"Outfit_Coat":(0.03,0.03,0.03),"Outfit_Shirt":(1,1,1),"Outfit_Shirt_Coated":(1,1,1),"Outfit_Trousers":(0.1,0.2,0.9),"Outfit_Trousers_Coated":(0.1,0.2,0.9),"Outfit_Belt":(1,0.8,0.1),"Outfit_Belt_Coated":(1,0.8,0.1),"Outfit_Buckle":(1,0.5,0),"Outfit_Tie":(0.9,0.05,0.05),"Body_Head":(0.9,0.7,0.55),"Body_Hands":(0.9,0.7,0.55),"Outfit_Hat":(0.15,0.15,0.17),"Body_Hair_Hat":(0.5,0.33,0.15),"Outfit_Shoes":(0.1,0.1,0.1)}
for o in bpy.data.objects:
    if o.type=='MESH' and not o.hide_render:
        c=COL.get(o.name.replace("Outfit_Coat.001","Outfit_Coat"),(0.5,0.5,0.5)); m=bpy.data.materials.new("c"); b=m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value=(*c,1); b.inputs["Roughness"].default_value=0.7
        o.data.materials.clear(); o.data.materials.append(m)
sc.render.engine='BLENDER_EEVEE'; sc.view_settings.view_transform='Standard'
wd=bpy.data.worlds.new("w"); sc.world=wd; wd.node_tree.nodes["Background"].inputs[0].default_value=(0.2,0.2,0.22,1)
for nm,en,rot in (("key",3.4,(50,0,-35)),("fill",1.2,(60,0,140)),("rim",2.0,(70,0,200))):
    lt=bpy.data.lights.new(nm,'SUN'); lt.energy=en; lo=bpy.data.objects.new(nm,lt); sc.collection.objects.link(lo); lo.rotation_euler=[math.radians(x) for x in rot]
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.clip_end=80; cam.ortho_scale=0.5; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
sc.render.resolution_x=sc.render.resolution_y=520
for fi,fr in enumerate(FR):
    sc.frame_set(int(round(fr))); bpy.context.view_layer.update()
    hp=arm.matrix_world@arm.pose.bones[P+"Hips"].head; ctr=Vector((hp.x,hp.y,0.66))
    d=Vector((0,-math.cos(math.radians(8)),math.sin(math.radians(8)))); co.location=ctr+d*10; co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{OUT}/{TAG}_{fi}.png"; bpy.ops.render.render(write_still=True)
print("[render_stage] done",TAG)
