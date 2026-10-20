# hero_remodel.py — Remodel the lean male body into the agile silhouettes (variants a, b) KEEPING the rig and skin weights, so every animation still applies. Usage: blender -b -P hero_remodel.py -- a|b|orig
# Dev tool, 2026-10-20 (CHARACTER_MASTER_PLAN viability work). Needs: HERO_REPO (repo root with trailing /), HERO_UBC_DIR (the unzipped
# Quaternius Universal Base Characters [Standard] "Godot - UE" folder, trailing /), HERO_UAL_GLB (UAL1_Standard.glb). Both packs are CC0;
# see ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/ATTRIBUTION.txt. Output lands in that folder (git-ignored).
import os
import bpy, bmesh, sys, math
from mathutils import Vector
D=""+os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
OUT=""+os.environ.get("HERO_TMP","/tmp/")+""
V=sys.argv[sys.argv.index("--")+1]   # a | b | orig
P={ "orig":dict(arm=(1,1),thigh=1,calf=1,tx=1,ty=1,neck=1,sh=0.0,hip=0.0),
    "a":dict(arm=(0.82,0.86),thigh=0.84,calf=0.88,tx=0.84,ty=0.90,neck=0.88,sh=0.025,hip=0.012),
    "b":dict(arm=(0.72,0.80),thigh=0.76,calf=0.82,tx=0.76,ty=0.84,neck=0.82,sh=0.045,hip=0.020)}[V]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=D+"superhero_male_lean.glb")
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:len(o.data.polygons))
M=body.matrix_world; Mi=M.inverted(); AW=arm.matrix_world
names=[g.name for g in body.vertex_groups]
CH_ARM=("clavicle_","upperarm_","lowerarm_","hand_","index_","middle_","pinky_","ring_","thumb_")
CH_LEG=("thigh_","calf_","foot_","ball_")
def side(n): return 1 if n.endswith("_l") else -1 if n.endswith("_r") else 0
# 1) shift chains inward: bones (edit mode) and vertices (by chain weight). The clavicle only shortens at its shoulder end.
ORIG={bn.name:(AW@bn.head_local,AW@bn.tail_local) for bn in arm.data.bones}
if P["sh"] or P["hip"]:
    bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        n=eb.name; s=side(n)
        if not s: continue
        if n.startswith("clavicle_"):
            eb.tail.x-=s*P["sh"]
        elif n.startswith(CH_ARM):
            eb.head.x-=s*P["sh"]; eb.tail.x-=s*P["sh"]
        elif n.startswith(CH_LEG):
            eb.head.x-=s*P["hip"]; eb.tail.x-=s*P["hip"]
    bpy.ops.object.mode_set(mode='OBJECT')
    me=body.data
    for v in me.vertices:
        w=(M@v.co); dx=0.0; sgn=0
        for g in v.groups:
            n=names[g.group]; s=side(n)
            if not s: continue
            if n.startswith("clavicle_"):
                a0,b0=ORIG[n]; ab=b0-a0; t=max(0.0,min(1.0,(w-a0).dot(ab)/max(ab.length_squared,1e-9)))
                dx+=g.weight*P["sh"]*t; sgn=s
            elif n.startswith(CH_ARM): dx+=g.weight*P["sh"]; sgn=s
            elif n.startswith(CH_LEG): dx+=g.weight*P["hip"]; sgn=s
        w.x-=sgn*dx; v.co=Mi@w
# 2) radial thinning about each bone's (shifted) axis
B={b.name:(AW@b.head_local,AW@b.tail_local) for b in arm.data.bones}
def closest(p,a,b):
    ab=b-a; t=max(0.0,min(1.0,(p-a).dot(ab)/max(ab.length_squared,1e-9))); return a+ab*t
fac={}
for n in B:
    if n.startswith("upperarm_"): fac[n]=("r",P["arm"][0])
    elif n.startswith("lowerarm_"): fac[n]=("r",P["arm"][1])
    elif n.startswith("thigh_"): fac[n]=("r",P["thigh"])
    elif n.startswith("calf_"): fac[n]=("r",P["calf"])
    elif n.startswith(("spine_","pelvis")): fac[n]=("t",(P["tx"],P["ty"]))
    elif n.startswith("neck_"): fac[n]=("r",P["neck"])
me=body.data
for v in me.vertices:
    p=M@v.co; delta=Vector((0,0,0))
    for g in v.groups:
        n=names[g.group]
        if n not in fac: continue
        a,b=B[n]; c=closest(p,a,b); r=p-c; kind,f=fac[n]
        if kind=="r": delta+=g.weight*r*(f-1.0)
        else: delta+=g.weight*Vector((r.x*(f[0]-1.0),r.y*(f[1]-1.0),0.0))
    v.co=Mi@(p+delta)
me.update()
bpy.ops.export_scene.gltf(filepath=D+f"superhero_male_agile_{V}_lean.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=False) if V!="orig" else None
# renders: front (from -Y) and side (from +X), orthographic
sc=bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29)
sc.render.resolution_x=500; sc.render.resolution_y=640
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.3
co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
for nm,loc in (("front",Vector((0,-10,0.92))),("side",Vector((10,0,0.92)))):
    co.location=loc; co.rotation_euler=(Vector((0,0,0.92))-loc).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=OUT+f"rm_{V}_{nm}.png"; bpy.ops.render.render(write_still=True)
print("OK",V)
