# hero_dress.py — Attach the Universal Animation Library's 43 actions to a body and dress it with PLACEHOLDER pieces (jacket, trousers, shoes, hat, tie, backpack + pouches) skinned to the same skeleton. Usage: [BODY_FILE=<lean glb> OUT_SUFFIX=<s> CAM_AZ=<deg>] blender -b -P hero_dress.py -- naked|split|joined
# Dev tool, 2026-10-20 (CHARACTER_MASTER_PLAN viability work). Needs: HERO_REPO (repo root with trailing /), HERO_UBC_DIR (the unzipped
# Quaternius Universal Base Characters [Standard] "Godot - UE" folder, trailing /), HERO_UAL_GLB (UAL1_Standard.glb). Both packs are CC0;
# see ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/ATTRIBUTION.txt. Output lands in that folder (git-ignored).
import os
import bpy, bmesh, mathutils, sys, math
from mathutils import Vector
UAL=""+os.environ.get("HERO_UAL_GLB","")+""
D=""+os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
import os
BODY=D+os.environ.get("BODY_FILE","superhero_male_lean.glb")
SUF=os.environ.get("OUT_SUFFIX","")
VARIANT=sys.argv[sys.argv.index("--")+1]   # naked | split | joined
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BODY)
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:len(o.data.polygons))
print("body mesh",body.name,len(body.data.polygons),"polys; others",[o.name for o in bpy.context.scene.objects if o.type=='MESH' and o is not body])
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=UAL)
extra=[o for o in bpy.data.objects if o not in before]
# ---- animations onto the body's armature (same 65 bone names) ----
ad=arm.animation_data_create()
for act in list(bpy.data.actions):
    ad.action=act
    ad.action_slot=act.slots[0]
    tr=ad.nla_tracks.new(); tr.name=act.name
    st=tr.strips.new(act.name,0,act); st.action_slot=act.slots[0]
ad.action=None
for o in extra: bpy.data.objects.remove(o,do_unlink=True)
print("NLA tracks",len(ad.nla_tracks))
# ---- region helpers ----
names=[g.name for g in body.vertex_groups]
def dom(v):
    best=None;bw=0
    for g in v.groups:
        if g.weight>bw: bw=g.weight;best=names[g.group]
    return best
def region(prefixes):
    return lambda n: n is not None and any(n==p or n.startswith(p) for p in prefixes)
JACKET=region(("spine_","clavicle_","upperarm_","lowerarm_"))
TROUS=region(("pelvis","thigh_","calf_"))
SHOES=region(("foot_","ball_"))
ARMOBJ=arm
def mat(name,rgb):
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=0.8
    m.diffuse_color=(*rgb,1); return m
BLACK=mat("Outfit_Black",(0.025,0.025,0.03)); WHITE=mat("Outfit_White",(0.85,0.85,0.88)); OLIVE=mat("Pack_Olive",(0.20,0.24,0.12))
def skin_to_arm(o):
    o.parent=arm
    mod=o.modifiers.new("Armature",'ARMATURE'); mod.object=arm
def shell(name,sel,inflate,material):
    o=body.copy(); o.data=body.data.copy(); o.name=name
    bpy.context.scene.collection.objects.link(o)
    bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    dl=bm.verts.layers.deform.active
    def dg(v):
        best=None;bw=0
        for gi,w in v[dl].items():
            if w>bw: bw=w;best=names[gi]
        return best
    keep=set(v.index for v in bm.verts if sel(dg(v)))
    bad=[f for f in bm.faces if not all(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm,geom=bad,context='FACES')
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*inflate
    bm.to_mesh(o.data); bm.free()
    o.data.materials.clear(); o.data.materials.append(material)
    return o
def mask_body(sels):
    bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); dl=bm.verts.layers.deform.active
    def dg(v):
        best=None;bw=0
        for gi,w in v[dl].items():
            if w>bw: bw=w;best=names[gi]
        return best
    cover=set(v.index for v in bm.verts if any(s(dg(v)) for s in sels))
    gone=[f for f in bm.faces if all(v.index in cover for v in f.verts)]
    bmesh.ops.delete(bm,geom=gone,context='FACES'); bm.to_mesh(body.data); bm.free()
    return len(gone)
def box(name,size,center,group,material):
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1.0)
    for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))+Vector(center)
    me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE')
    me.materials.append(material); skin_to_arm(o); return o
def cyl(name,r,h,center,group,material,verts=20):
    bm=bmesh.new(); bmesh.ops.create_cone(bm,cap_ends=True,segments=verts,radius1=r,radius2=r,depth=h)
    for v in bm.verts: v.co+=Vector(center)
    me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE')
    me.materials.append(material); skin_to_arm(o); return o
wb=lambda n: arm.matrix_world@arm.data.bones[n].head_local
pieces=[]
if VARIANT!="naked":
    pieces.append(shell("Outfit_Jacket",JACKET,0.012,BLACK))
    pieces.append(shell("Outfit_Trousers",TROUS,0.008,BLACK))
    pieces.append(shell("Outfit_Shoes",SHOES,0.010,BLACK))
    n_masked=mask_body([JACKET,TROUS,SHOES]); print("body faces masked",n_masked)
    for p in pieces: p.parent=arm; 
    # measurements from the body
    head_top=max((body.matrix_world@v.co).z for v in body.data.vertices if dom(v)=="Head") if False else 1.80
    zc=wb("spine_03").z; hb=wb("Head")
    ys=[v.co.y for v in body.data.vertices if abs(v.co.x)<0.04 and abs(v.co.z-zc)<0.05]
    front=min(ys) if ys else -0.10; back=max(ys) if ys else 0.10
    print("chest front/back y",front,back,"spine_03 z",zc,"head",tuple(hb))
    pieces.append(box("Outfit_Tie",(0.035,0.012,0.22),(0,front-0.021,zc-0.07),"spine_03",WHITE))
    pieces.append(cyl("Outfit_HatCrown",0.098,0.125,(hb.x,hb.y-0.005,1.80-0.045+0.035),"Head",BLACK))
    pieces.append(cyl("Outfit_HatBrim",0.155,0.010,(hb.x,hb.y-0.005,1.80-0.092+0.035),"Head",BLACK))
    pieces.append(box("Pack_Main",(0.30,0.13,0.36),(0,back+0.075,zc-0.02),"spine_03",OLIVE))
    pieces.append(box("Pack_PouchL",(0.07,0.09,0.14),(0.19,back+0.075,zc-0.10),"spine_03",OLIVE))
    pieces.append(box("Pack_PouchR",(0.07,0.09,0.14),(-0.19,back+0.075,zc-0.10),"spine_03",OLIVE))
    for p in pieces:
        if not any(m.type=='ARMATURE' for m in p.modifiers): skin_to_arm(p)
    if VARIANT=="joined":
        # one mesh per material: black cloth (jacket+trousers+shoes+hat) and olive pack, white tie alone
        def join(objs):
            bpy.ops.object.select_all(action='DESELECT')
            for o in objs: o.select_set(True)
            bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join()
        byn={p.name:p for p in pieces}
        join([byn[n] for n in ("Outfit_Jacket","Outfit_Trousers","Outfit_Shoes","Outfit_HatCrown","Outfit_HatBrim")])
        join([byn[n] for n in ("Pack_Main","Pack_PouchL","Pack_PouchR")])
ico=bpy.data.objects.get("Icosphere")
if ico is not None:
    print("ICO loc",tuple(round(v,3) for v in ico.location),"parent",ico.parent.name if ico.parent else None,"dims",tuple(round(v,3) for v in ico.dimensions))
    bpy.data.objects.remove(ico,do_unlink=True)
# stats
tot=0
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        n=sum(len(p.vertices)-2 for p in o.data.polygons); tot+=n
        print("PIECE",o.name,n,"tris",[m.name for m in o.data.materials])
print("TOTAL tris",tot,"meshes",sum(1 for o in bpy.context.scene.objects if o.type=='MESH'))
bpy.ops.export_scene.gltf(filepath=D+f"hero_{VARIANT}{SUF}.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
# preview
sc=bpy.context.scene; sc.frame_set(12)
sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.4
co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
ctr=Vector((0,0,0.95)); el=math.radians(30); az=math.radians(float(os.environ.get('CAM_AZ','45')))   # camera on the character's FRONT (-Y) side, rotated 45
d=10; co.location=ctr+Vector((d*math.cos(el)*math.sin(az),-d*math.cos(el)*math.cos(az),d*math.sin(el)))
co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
sc.render.resolution_x=500; sc.render.resolution_y=800
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29)
sc.render.filepath=os.environ.get("HERO_TMP","/tmp/")+f"prev_{VARIANT}{SUF}.png"
bpy.ops.render.render(write_still=True); print("OK",VARIANT)
