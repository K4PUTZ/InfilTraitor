# hero_tailor.py — our OWN suit, tailored to the agile-B body and skinned to the same 65-bone skeleton (no CC0 suit was found; see ACTOR D74).
# Builds: shirt, jacket (V opening, rolled lapels, longer hem), trousers (looser toward a cuff), shoes, spats, the white overcoat (open front,
# knee-length skirt, a hump over the pack), hat, tie, backpack + pouches; masks the body under the clothes; attaches the UAL's 43 actions; exports
# hero<OUT_SUFFIX>.glb. Env: HERO_REPO (repo root, trailing /), HERO_UAL_GLB, BODY_FILE (default superhero_male_agile_b_lean.glb), OUT_SUFFIX,
# DECIMATE (LOD ratio, e.g. 0.27 for ~5k), NOCOAT=1 (the black style: coat inside the pack), DEBUG=1 [DBGPOSE=<action> DBGFRAME=<n>] (coloured pieces).
# Usage: blender -b -P hero_tailor.py
# ⚠️ Two traps found building it: the copy of the body carries its Armature modifier (a second one poses the piece twice), and the 43 UAL tracks all
# start at frame 1, so the rig must be in REST while pieces are fitted and weighted (else the weights are transferred from a twisted body).
import os
import bpy, bmesh, math, os, sys
from mathutils import Vector
SP=os.environ.get("HERO_TMP","/tmp/")
UAL=os.environ.get("HERO_UAL_GLB","")
D=os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
BODY=D+os.environ.get("BODY_FILE","superhero_male_agile_b_lean.glb"); SUF=os.environ.get("OUT_SUFFIX","_tailored")
DEC=float(os.environ.get("DECIMATE","1.0"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BODY)
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:len(o.data.polygons))
# animations from the UAL, same 65 bone names
before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=UAL)
extra=[o for o in bpy.data.objects if o not in before]
ad=arm.animation_data_create()
for act in list(bpy.data.actions):
    ad.action=act; ad.action_slot=act.slots[0]
    tr=ad.nla_tracks.new(); tr.name=act.name; st=tr.strips.new(act.name,0,act); st.action_slot=act.slots[0]
ad.action=None
for o in extra: bpy.data.objects.remove(o,do_unlink=True)
ico=bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico,do_unlink=True)
# pristine copy of the body for weight transfer
arm.data.pose_position='REST'   # 43 overlapping NLA tracks pose the rig at frame 1; every fit and weight transfer below must see the REST body
full=body.copy(); full.data=body.data.copy(); full.name="BodyFull"; bpy.context.scene.collection.objects.link(full); full.parent=None
for m_ in list(full.modifiers): full.modifiers.remove(m_)
names=[g.name for g in body.vertex_groups]
def mat(name,rgb,rough=0.85):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=rough; m.diffuse_color=(*rgb,1); return m
BLACK=mat("Suit_Black",(0.025,0.025,0.03)); WHITE=mat("Coat_White",(0.86,0.86,0.84)); SHIRT=mat("Shirt_Blue",(0.16,0.32,0.62)); TIEW=mat("Tie_White",(0.88,0.88,0.9)); OLIVE=mat("Pack_Olive",(0.20,0.24,0.12)); SPAT=mat("Spats_White",(0.9,0.9,0.88))
def starts(n,pre): return n is not None and n.startswith(pre)
def region(*pre): return lambda n: n is not None and any(n.startswith(p) for p in pre)
def piece(name,sel,material,off,zfilter=None):
    o=body.copy(); o.data=full.data.copy(); o.name=name; bpy.context.scene.collection.objects.link(o)
    for m_ in list(o.modifiers): o.modifiers.remove(m_)     # the copy carries the body's Armature modifier; a second one would pose the piece twice
    o.parent=None
    bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table(); dl=bm.verts.layers.deform.active
    def dg(v):
        best=None;bw=0
        for gi,w in v[dl].items():
            if w>bw: bw=w;best=names[gi]
        return best
    keep=set(v.index for v in bm.verts if sel(dg(v)) and (zfilter is None or zfilter(v.co.z)))
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if not all(v.index in keep for v in f.verts)],context='FACES')
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*(off(v) if callable(off) else off)
    return o,bm
def finish(o,bm,material):
    bm.normal_update(); bm.to_mesh(o.data); bm.free()
    o.data.materials.clear(); o.data.materials.append(material)
    # weights from the pristine body: nearest surface, interpolated
    m=o.modifiers.new("DT",'DATA_TRANSFER'); m.object=full; m.use_vert_data=True; m.data_types_verts={'VGROUP_WEIGHTS'}
    m.vert_mapping='POLYINTERP_NEAREST'; m.layers_vgroup_select_src='ALL'; m.layers_vgroup_select_dst='NAME'
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier="DT")
    o.parent=arm; am=o.modifiers.new("Armature",'ARMATURE'); am.object=arm
    return o
def boundary(bm,pred):
    return [e for e in bm.edges if e.is_boundary and all(pred(v.co) for v in e.verts)]
def horizontal_boundary(bm,pred):
    out=[]
    for e in bm.edges:
        if not e.is_boundary: continue
        a,b=e.verts[0].co,e.verts[1].co
        if not (pred(a) and pred(b)): continue
        L=(a-b).length
        if L>1e-6 and abs(a.z-b.z)<0.35*L: out.append(e)      # a hem runs sideways; the slit and the lapel run up and down
    return out
def hem(bm,pred,drop,flare,steps):
    es=horizontal_boundary(bm,pred)
    for _ in range(steps):
        if not es: return
        ret=bmesh.ops.extrude_edge_only(bm,edges=es)
        nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
        cx=sum(v.co.x for v in nv)/len(nv); cy=sum(v.co.y for v in nv)/len(nv); f=flare**(1.0/steps)
        for v in nv:
            v.co.z-=drop/steps; v.co.x=cx+(v.co.x-cx)*f; v.co.y=cy+(v.co.y-cy)*f
        es=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMEdge) and g.is_boundary and abs(g.verts[0].co.z-g.verts[1].co.z)<0.35*max((g.verts[0].co-g.verts[1].co).length,1e-6)]
        bm.verts.ensure_lookup_table(); bm.normal_update()
def cut_front(bm,vfun):
    bm.faces.ensure_lookup_table()
    bad=[f for f in bm.faces if f.calc_center_median().y<0.0 and vfun(f.calc_center_median())]
    bmesh.ops.delete(bm,geom=bad,context='FACES')
bw=lambda a: arm.matrix_world@arm.data.bones[a].head_local
zc=bw("spine_03").z; zn=bw("neck_01").z
ys=[v.co.y for v in full.data.vertices if abs(v.co.x)<0.04 and abs(v.co.z-zc)<0.05]; front=min(ys); back=max(ys)
print("TAILOR zc",round(zc,3),"neck z",round(zn,3),"chest y",round(front,3),round(back,3))
pieces=[]
# ---- shirt (torso only, under the jacket) ----
o,bm=piece("Outfit_Shirt",region("spine_","pelvis"),SHIRT,0.007,zfilter=lambda z:z>0.98)
pieces.append(finish(o,bm,SHIRT))
# ---- suit jacket: torso + arms, longer hem, V opening with rolled lapels ----
o,bm=piece("Outfit_Jacket",region("spine_","clavicle_","upperarm_","lowerarm_"),BLACK,0.020)
def vopen(c): 
    zb=zc-0.16; return c.z>zb and abs(c.x)<0.075*(c.z-zb)/(zn+0.02-zb)
cut_front(bm,vopen)
hem(bm,lambda c: 0.85<c.z<1.18 and abs(c.x)<0.35,0.17,1.05,2)
for e in [e for e in bm.edges if e.is_boundary and e.verts[0].co.z>zc-0.2 and abs(e.verts[0].co.x)<0.12 and e.verts[0].co.y<0]:
    for v in e.verts: v.co.y-=0.012; v.co.x+=0.012*(1 if v.co.x>0 else -1)   # the lapel's rolled edge
pieces.append(finish(o,bm,BLACK))
# ---- trousers: looser toward the ankle, with a cuff ----
def loose(v): 
    t=max(0.0,min(1.0,(1.0-v.co.z)/0.95)); return 0.008+0.018*t
o,bm=piece("Outfit_Trousers",region("pelvis","thigh_","calf_"),BLACK,loose)
hem(bm,lambda c: c.z<0.16,0.035,1.06,1)
pieces.append(finish(o,bm,BLACK))
# ---- shoes and spats (polainas) ----
o,bm=piece("Outfit_Shoes",region("foot_","ball_"),BLACK,0.010,zfilter=lambda z:z<0.11)
pieces.append(finish(o,bm,BLACK))
o,bm=piece("Outfit_Spats",region("foot_","calf_"),SPAT,0.015,zfilter=lambda z:0.045<z<0.20)
pieces.append(finish(o,bm,SPAT))
# ---- the white overcoat: long skirt to the knee, open front, a hump over the pack ----
o,bm=piece("Outfit_Coat",region("spine_","clavicle_","upperarm_","lowerarm_"),WHITE,0.045)
def coatopen(c):
    zb=zc-0.30; return (c.z>zb and abs(c.x)<0.075*(c.z-zb)/(zn+0.03-zb)) or (c.z<=zb and abs(c.x)<0.012)
cut_front(bm,coatopen)
hem(bm,lambda c: 0.85<c.z<1.18 and abs(c.x)<0.40,0.56,1.16,4)
for v in bm.verts:   # the hump: the pack lives under the coat
    if v.co.y>0.0 and abs(v.co.x)<0.26:
        t=max(0.0,1.0-abs(v.co.z-(zc-0.03))/0.30)*max(0.0,1.0-abs(v.co.x)/0.26); v.co.y+=0.13*t
pieces.append(finish(o,bm,WHITE))
# ---- hat, tie, pack (carried over from the placeholder) ----
def prim(name,bmfun,group,material):
    bm=bmesh.new(); bmfun(bm); me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE'); me.materials.append(material)
    o.parent=arm; m=o.modifiers.new("Armature",'ARMATURE'); m.object=arm; return o
def boxf(size,c):
    def f(bm):
        bmesh.ops.create_cube(bm,size=1.0)
        for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))+Vector(c)
    return f
def cylf(r,h,c,n=20):
    def f(bm):
        bmesh.ops.create_cone(bm,cap_ends=True,segments=n,radius1=r,radius2=r,depth=h)
        for v in bm.verts: v.co+=Vector(c)
    return f
hb=bw("Head"); top=1.80
pieces.append(prim("Outfit_HatCrown",cylf(0.098,0.125,(hb.x,hb.y-0.005,top-0.045+0.035)),"Head",BLACK))
pieces.append(prim("Outfit_HatBrim",cylf(0.155,0.010,(hb.x,hb.y-0.005,top-0.092+0.035)),"Head",BLACK))
pieces.append(prim("Outfit_Tie",boxf((0.035,0.012,0.22),(0,front-0.027,zc-0.07)),"spine_03",TIEW))
pieces.append(prim("Pack_Main",boxf((0.30,0.13,0.36),(0,back+0.075,zc-0.02)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchL",boxf((0.07,0.09,0.14),(0.19,back+0.075,zc-0.10)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchR",boxf((0.07,0.09,0.14),(-0.19,back+0.075,zc-0.10)),"spine_03",OLIVE))
# ---- mask the body under the clothes, drop the helper copy ----
bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); dl=bm.verts.layers.deform.active
def dgb(v):
    best=None;bw_=0
    for gi,w in v[dl].items():
        if w>bw_: bw_=w;best=names[gi]
    return best
cover=region("spine_","clavicle_","upperarm_","lowerarm_","pelvis","thigh_","calf_","foot_","ball_")
cov=set(v.index for v in bm.verts if cover(dgb(v)))
gone=[f for f in bm.faces if all(v.index in cov for v in f.verts)]
bmesh.ops.delete(bm,geom=gone,context='FACES'); bm.to_mesh(body.data); bm.free(); print("TAILOR body faces masked",len(gone))
bpy.data.objects.remove(full,do_unlink=True)
if DEC<1.0:
    for o in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.polygons)>150]:
        bpy.context.view_layer.objects.active=o; m=o.modifiers.new("Decimate",'DECIMATE'); m.ratio=DEC; bpy.ops.object.modifier_apply(modifier="Decimate")
if os.environ.get("DEBUG")=="1":
    pal={"Outfit_Shirt":(0.1,0.4,1,1),"Outfit_Jacket":(1,0.1,0.1,1),"Outfit_Trousers":(0.1,0.9,0.1,1),"Outfit_Shoes":(0.9,0.9,0.1,1),"Outfit_Spats":(1,0.5,0,1),"Outfit_Coat":(0.7,0.2,0.9,1)}
    for n,c in pal.items():
        o_=bpy.data.objects.get(n)
        if o_: o_.data.materials[0].diffuse_color=c
    pose=os.environ.get("DBGPOSE")
    if pose:
        arm.data.pose_position='POSE'
        a_=bpy.data.actions[pose]; ad.action=a_; ad.action_slot=a_.slots[0]; bpy.context.scene.frame_set(int(os.environ.get("DBGFRAME","20")))
    else:
        arm.data.pose_position='REST'; ad.action=None
    sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='MATERIAL'
    sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29); sc.render.resolution_x=520; sc.render.resolution_y=640
    cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.4; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
    for k,(az,el) in enumerate([(0,0),(90,0),(30,25)]):
        a_=math.radians(az); e_=math.radians(el); ctr=Vector((0,0,0.9)); d=10
        co.location=ctr+Vector((d*math.cos(e_)*math.sin(a_),-d*math.cos(e_)*math.cos(a_),d*math.sin(e_))); co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=SP+f"dbg{os.environ.get('DBGPOSE','')}_{k}.png"; bpy.ops.render.render(write_still=True)
    print("OK debug"); sys.exit(0)
arm.data.pose_position='POSE'
tot=0
for o in bpy.context.scene.objects:
    if o.type=='MESH': n=sum(len(p.vertices)-2 for p in o.data.polygons); tot+=n; print("TAILOR piece",o.name,n)
print("TAILOR TOTAL tris",tot)
hide_coat=os.environ.get("NOCOAT")=="1"
if hide_coat:
    c=bpy.data.objects["Outfit_Coat"]; bpy.data.objects.remove(c,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=D+f"hero{SUF}.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
# ---- preview: T-pose-free walk frame + crouch, front and back ----
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='MATERIAL'
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29); sc.render.resolution_x=420; sc.render.resolution_y=640
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.3; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
sets=[("REST",None,"front",1),("REST",None,"side",1),("Idle_Loop",None,"front",20),("Walk_Formal_Loop",None,"front",12)]
prev=[]
for k,(an,_,view,fr) in enumerate(sets):
    if an=="REST":
        ad.action=None; sc.frame_set(1)
    else:
        a=bpy.data.actions[an]; ad.action=a; ad.action_slot=a.slots[0]; sc.frame_set(fr)
    az=math.radians({'front':30,'back':210,'side':90}[view]); el=math.radians(18); ctr=Vector((0,0,0.9)); d=10
    co.location=ctr+Vector((d*math.cos(el)*math.sin(az),-d*math.cos(el)*math.cos(az),d*math.sin(el))); co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=SP+f"tl{SUF}_{k}.png"; bpy.ops.render.render(write_still=True)
print("OK tailor")
