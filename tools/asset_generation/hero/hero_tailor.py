# hero_tailor.py — our OWN costume, tailored to the agile-B body and skinned to the same 65-bone skeleton (no CC0 suit was found; see ACTOR D74).
# v2 (2026-10-20). ONE file holds BOTH styles of D70; the engine shows one: the normal style hides Outfit_Gloves, the black style hides Outfit_Coat
# (and should hide Outfit_Spats). Pieces: shirt (+collar), jacket (shoulder pads, V opening, rolled lapels, standing collar, cuffs, buttons, a longer hem,
# elbow folds), trousers (looser toward a cuff that falls over the spats), shoes, spats, gloves, the white overcoat (the same, bigger, a knee-length skirt,
# a hump that hides the pack), fedora (tapered crown with a dent, a brim that droops in front, a band), tapered tie, backpack + 2 pouches (black, D70).
# Cuts are made with PLANES (clean edges), not by skin-weight groups (which leave staircases); the body is masked under the clothes except the hands.
# Env: HERO_REPO (repo root, trailing /), HERO_UAL_GLB (UAL1_Standard.glb), BODY_FILE (default superhero_male_agile_b_lean.glb), OUT_SUFFIX (default _tailor2),
# DECIMATE (LOD ratio; 0.163 gives ~5k from the 28k master), HERO_TMP (preview folder). Usage: blender -b -P hero_tailor.py
# ⚠️ Traps found building it: (1) a copy of the body carries its Armature modifier, a second one poses the piece twice; (2) the 43 UAL tracks all start at
# frame 1, so the rig must be in REST while pieces are fitted and weighted; (3) two bisect planes with clear_inner/clear_outer erase each other's hand.
import os
import bpy, bmesh, math, os, sys
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree
SP=os.environ.get("HERO_TMP","/tmp/")
UAL=os.environ.get("HERO_UAL_GLB","")
D=os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
BODY=D+os.environ.get("BODY_FILE","superhero_male_agile_b_lean.glb"); SUF=os.environ.get("OUT_SUFFIX","_tailor2")
DEC=float(os.environ.get("DECIMATE","1.0"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BODY)
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:len(o.data.polygons))
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
arm.data.pose_position='REST'   # 43 overlapping NLA tracks pose the rig at frame 1: fit and weight everything against the REST body
full=body.copy(); full.data=body.data.copy(); full.name="BodyFull"; bpy.context.scene.collection.objects.link(full); full.parent=None
for m_ in list(full.modifiers): full.modifiers.remove(m_)
names=[g.name for g in body.vertex_groups]
def mat(name,rgb,rough=0.85):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=rough; m.diffuse_color=(*rgb,1); return m
BLACK=mat("Suit_Black",(0.03,0.03,0.036)); WHITE=mat("Coat_White",(0.86,0.86,0.84)); SHIRT=mat("Shirt_Blue",(0.16,0.32,0.62)); TIEW=mat("Tie_White",(0.88,0.88,0.9))
OLIVE=mat("Pack_Black",(0.05,0.052,0.058),0.7); SPAT=mat("Spats_White",(0.9,0.9,0.88)); GLOVE=mat("Glove_Black",(0.015,0.015,0.02)); BAND=mat("Hat_Band",(0.09,0.09,0.11))
bw=lambda a: arm.matrix_world@arm.data.bones[a].head_local
bt=lambda a: arm.matrix_world@arm.data.bones[a].tail_local
wx=abs(bw("hand_l").x); zc=bw("spine_03").z; zn=bw("neck_01").z
ys=[v.co.y for v in full.data.vertices if abs(v.co.x)<0.04 and abs(v.co.z-zc)<0.05]; front=min(ys); back=max(ys)
print("T2 wrist x",round(wx,3),"zc",round(zc,3),"zn",round(zn,3),"front/back",round(front,3),round(back,3))
def region(*pre): return lambda n: n is not None and any(n.startswith(p) for p in pre)
ARMS=("clavicle_","upperarm_","lowerarm_","hand_","index_","middle_","pinky_","ring_","thumb_")
def blank(name):
    o=body.copy(); o.data=full.data.copy(); o.name=name; bpy.context.scene.collection.objects.link(o)
    for m_ in list(o.modifiers): o.modifiers.remove(m_)
    o.parent=None
    bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table(); return o,bm
def dgroup(bm):
    dl=bm.verts.layers.deform.active
    def dg(v):
        best=None;bw_=0
        for gi,w in v[dl].items():
            if w>bw_: bw_=w;best=names[gi]
        return best
    return dg
def keep_groups(bm,sel):
    dg=dgroup(bm); keep=set(v.index for v in bm.verts if sel(dg(v)))
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if not all(v.index in keep for v in f.verts)],context='FACES')
    sweep(bm)
def sweep(bm):
    loose=[v for v in bm.verts if not v.link_faces]
    if loose: bmesh.ops.delete(bm,geom=loose,context='VERTS')
def plane(bm,co,no,inner=False,outer=False):
    g=bm.verts[:]+bm.edges[:]+bm.faces[:]
    bmesh.ops.bisect_plane(bm,geom=g,dist=1e-5,plane_co=Vector(co),plane_no=Vector(no),clear_inner=inner,clear_outer=outer); sweep(bm)
def displace(bm,fn):
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*(fn(v) if callable(fn) else fn)
def horizontal_boundary(bm,pred):
    out=[]
    for e in bm.edges:
        if not e.is_boundary: continue
        a,b=e.verts[0].co,e.verts[1].co
        if pred(a) and pred(b):
            L=(a-b).length
            if L>1e-6 and abs(a.z-b.z)<0.35*L: out.append(e)
    return out
def hem(bm,pred,drop,flare,steps):
    es=horizontal_boundary(bm,pred)
    for _ in range(steps):
        if not es: return
        ret=bmesh.ops.extrude_edge_only(bm,edges=es); nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
        cx=sum(v.co.x for v in nv)/len(nv); cy=sum(v.co.y for v in nv)/len(nv); f=flare**(1.0/steps)
        for v in nv: v.co.z-=drop/steps; v.co.x=cx+(v.co.x-cx)*f; v.co.y=cy+(v.co.y-cy)*f
        es=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMEdge) and g.is_boundary and abs(g.verts[0].co.z-g.verts[1].co.z)<0.35*max((g.verts[0].co-g.verts[1].co).length,1e-6)]
        bm.verts.ensure_lookup_table(); bm.normal_update()
def collar(bm,height,flare,steps=2):
    pred=lambda c: c.z>zn-0.14 and abs(c.x)<0.14
    es=horizontal_boundary(bm,pred)
    for _ in range(steps):
        if not es: return
        ret=bmesh.ops.extrude_edge_only(bm,edges=es); nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
        cx=sum(v.co.x for v in nv)/len(nv); cy=sum(v.co.y for v in nv)/len(nv); f=flare**(1.0/steps)
        for v in nv: v.co.z+=height/steps; v.co.x=cx+(v.co.x-cx)*f; v.co.y=cy+(v.co.y-cy)*f
        es=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMEdge) and g.is_boundary]
def cuffs(bm,x0,length,scale):
    for s in (1,-1):
        es=[e for e in bm.edges if e.is_boundary and all(s*v.co.x>x0-0.02 for v in e.verts)]
        if not es: continue
        ret=bmesh.ops.extrude_edge_only(bm,edges=es); nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
        cy=sum(v.co.y for v in nv)/len(nv); cz=sum(v.co.z for v in nv)/len(nv)
        for v in nv: v.co.x+=s*length; v.co.y=cy+(v.co.y-cy)*scale; v.co.z=cz+(v.co.z-cz)*scale
def smooth_boundary(bm,pred,iters=4):
    bv=set(v for e in bm.edges if e.is_boundary for v in e.verts if pred(v.co))
    for _ in range(iters):
        new={}
        for v in bv:
            nb=[e.other_vert(v) for e in v.link_edges if e.is_boundary and e.other_vert(v) in bv]
            if len(nb)==2: new[v]=(nb[0].co+nb[1].co)*0.3+v.co*0.4
        for v,p in new.items(): v.co=p
def vopen(bm,zb,ztop,halfw):
    bm.faces.ensure_lookup_table()
    bad=[f for f in bm.faces if f.calc_center_median().y<0.0 and f.calc_center_median().z>zb and abs(f.calc_center_median().x)<halfw*(f.calc_center_median().z-zb)/(ztop-zb)]
    bmesh.ops.delete(bm,geom=bad,context='FACES'); sweep(bm)
def lapels(bm,zb,width,lift):
    es=[e for e in bm.edges if e.is_boundary and all(v.co.y<0.0 and abs(v.co.x)<0.14 and v.co.z>zb-0.02 and v.co.z<zn+0.05 for v in e.verts)
        and abs(e.verts[0].co.z-e.verts[1].co.z)>0.35*(e.verts[0].co-e.verts[1].co).length]
    if not es: return
    ret=bmesh.ops.extrude_edge_only(bm,edges=es); nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
    for v in nv: v.co.x+=(1 if v.co.x>0 else -1)*width; v.co.y-=lift
def folds(bm,joints,amp,span=0.085,freq=85.0):
    for hname,tname in joints:
        a=bw(hname); b=bt(hname); ax=(b-a).normalized()
        for v in bm.verts:
            s=(v.co-a).dot(ax); r=(v.co-(a+ax*s)).length
            if abs(s)<span and r<0.16: v.co+=v.normal*(amp*math.sin(s*freq)*(1.0-abs(s)/span))
def noisy(bm,amp,scale=9.0):
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*(noise.noise(v.co*scale)*amp)
def buttons(bm,xs,zs,r,mat_back=True):
    bvh=BVHTree.FromBMesh(bm)
    for x in xs:
        for z in zs:
            hit,nrm,idx,dist=bvh.ray_cast(Vector((x,-1.0,z)),Vector((0,1,0)))
            if hit is None: continue
            m=bmesh.ops.create_cone(bm,cap_ends=True,segments=10,radius1=r,radius2=r*0.9,depth=0.008)
            # cone axis is Z; turn it to face -Y and put it on the cloth
            bmesh.ops.rotate(bm,verts=m['verts'],cent=Vector(),matrix=__import__('mathutils').Matrix.Rotation(math.radians(90),3,'X'))
            bmesh.ops.translate(bm,verts=m['verts'],vec=hit+nrm*0.004)
def finish(o,bm,material):
    sweep(bm); bm.normal_update(); bm.to_mesh(o.data); bm.free()
    o.data.materials.clear(); o.data.materials.append(material)
    m=o.modifiers.new("DT",'DATA_TRANSFER'); m.object=full; m.use_vert_data=True; m.data_types_verts={'VGROUP_WEIGHTS'}
    m.vert_mapping='POLYINTERP_NEAREST'; m.layers_vgroup_select_src='ALL'; m.layers_vgroup_select_dst='NAME'
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier="DT")
    o.parent=arm; am=o.modifiers.new("Armature",'ARMATURE'); am.object=arm
    return o
def shoulder_pad(amp):
    pts=[bw("upperarm_l"),bw("upperarm_r")]
    def f(v):
        d=min((v.co-p).length for p in pts); return amp*math.exp(-(d/0.07)**2)
    return f
TORSO=("spine_","pelvis")+ARMS
pieces=[]
# ---- shirt ----
o,bm=blank("Outfit_Shirt"); keep_groups(bm,region("spine_","pelvis","clavicle_")); plane(bm,(0,0,1.02),(0,0,1),inner=True)
displace(bm,0.007); collar(bm,0.03,1.06,1)
pieces.append(finish(o,bm,SHIRT))
# ---- jacket ----
o,bm=blank("Outfit_Jacket"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True)
plane(bm,(wx-0.012,0,0),(1,0,0),outer=True); plane(bm,(-(wx-0.012),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.016)
displace(bm,lambda v: 0.030+sh(v)+(0.004 if abs(v.co.x)>0.2 else 0.0))
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0045)
vopen(bm,zc-0.17,zn+0.02,0.060); smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.13 and c.z>zc-0.25)
lapels(bm,zc-0.17,0.048,0.006)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.40,0.175,1.07,3)
collar(bm,0.038,1.10,2); cuffs(bm,wx-0.012,0.018,1.05)
noisy(bm,0.0025); buttons(bm,[0.0],[zc-0.20,zc-0.30],0.011)
pieces.append(finish(o,bm,BLACK))
# ---- trousers (hem over the spats) ----
o,bm=blank("Outfit_Trousers"); keep_groups(bm,region("pelvis","thigh_","calf_","foot_","ball_"))
plane(bm,(0,0,1.0),(0,0,1),outer=True); plane(bm,(0,0,0.19),(0,0,1),inner=True)
def loose(v): t=max(0.0,min(1.0,(1.0-v.co.z)/0.82)); return 0.011+0.017*t
displace(bm,loose); folds(bm,[("calf_l",None),("calf_r",None)],0.005,0.09,70.0)
hem(bm,lambda c: c.z<0.24,0.012,1.045,1); noisy(bm,0.002)
pieces.append(finish(o,bm,BLACK))
# ---- shoes and spats ----
o,bm=blank("Outfit_Shoes"); keep_groups(bm,region("foot_","ball_","calf_")); plane(bm,(0,0,0.105),(0,0,1),outer=True)
displace(bm,0.011); pieces.append(finish(o,bm,BLACK))
o,bm=blank("Outfit_Spats"); keep_groups(bm,region("foot_","ball_","calf_")); plane(bm,(0,0,0.215),(0,0,1),outer=True); plane(bm,(0,0,0.05),(0,0,1),inner=True)
displace(bm,0.0155); pieces.append(finish(o,bm,SPAT))
# ---- gloves (the black style) ----
o,bm=blank("Outfit_Gloves"); keep_groups(bm,region("hand_","index_","middle_","pinky_","ring_","thumb_"))
plane(bm,(wx-0.015,0,0),(1,0,0)); plane(bm,(-(wx-0.015),0,0),(-1,0,0))       # split only: the two cuts would erase each other's hand
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)<wx-0.0149],context='FACES'); sweep(bm)
displace(bm,0.0045); cuffs(bm,wx-0.015,-0.035,1.12)
pieces.append(finish(o,bm,GLOVE))
# ---- the white overcoat ----
o,bm=blank("Outfit_Coat"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True)
plane(bm,(wx+0.02,0,0),(1,0,0),outer=True); plane(bm,(-(wx+0.02),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.024)
displace(bm,lambda v: 0.046+sh(v)+(0.006 if abs(v.co.x)>0.2 else 0.0))
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0065)
vopen(bm,zc-0.30,zn+0.03,0.068)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().y<0.0 and f.calc_center_median().z<=zc-0.30 and abs(f.calc_center_median().x)<0.012],context='FACES'); sweep(bm)
smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.14 and c.z>zc-0.45)
lapels(bm,zc-0.30,0.058,0.008)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.45,0.58,1.17,5)
for v in bm.verts:   # the hump: the pack lives under the coat
    if v.co.y>0.0 and abs(v.co.x)<0.27:
        tz=max(0.0,min(1.0,(0.33-abs(v.co.z-(zc-0.03)))/0.13)); tx=max(0.0,min(1.0,(0.27-abs(v.co.x))/0.10)); v.co.y+=0.155*tz*tx*tz*tx*(3-2*tz*tx)
collar(bm,0.055,1.12,2); cuffs(bm,wx+0.02,0.02,1.04)
noisy(bm,0.0035); buttons(bm,[0.034],[zc+0.0,zc-0.10,zc-0.20,zc-0.32],0.013)
pieces.append(finish(o,bm,WHITE))
# ---- hat (fedora: tapered crown with a dent, a brim that droops in front), band, tie, pack ----
def prim(name,build,group,material):
    bm=bmesh.new(); build(bm); me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE'); me.materials.append(material)
    o.parent=arm; m=o.modifiers.new("Armature",'ARMATURE'); m.object=arm; return o
hb=bw("Head"); hx,hy,top=hb.x,hb.y-0.005,1.80
def crown(bm):
    m=bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=True,segments=24,radius1=0.099,radius2=0.088,depth=0.118)
    for v in m['verts']: v.co+=Vector((hx,hy,top-0.045+0.034))
    ct=max(m['verts'],key=lambda v:v.co.z-(abs(v.co.x-hx)+abs(v.co.y-hy))*10); ct.co.z-=0.022      # the dent
    for v in m['verts']:      # pinch the front (-Y) of the crown, the fedora's crease
        if v.co.z>top-0.045+0.034 and v.co.y<hy-0.02: v.co.x=hx+(v.co.x-hx)*0.88
def brim(bm):
    seg=36; ri,ro,th=0.096,0.158,0.005; zb=top-0.092+0.035
    def zz(t,r):
        d=math.sin(t)                       # t=0 at the front (-Y after the rotation below)
        return zb+(-0.022*max(0.0,math.cos(t-math.pi))*0.0)+0.016*abs(math.sin(t))*((r-ri)/(ro-ri))-0.020*max(0.0,math.cos(t))*((r-ri)/(ro-ri))
    top_in=[];top_out=[];bot_in=[];bot_out=[]
    for i in range(seg):
        t=2*math.pi*i/seg; cx,cy=math.sin(t),-math.cos(t)
        top_in.append(bm.verts.new(Vector((hx+cx*ri,hy+cy*ri,zz(t,ri)+th)))); top_out.append(bm.verts.new(Vector((hx+cx*ro,hy+cy*ro,zz(t,ro)+th))))
        bot_in.append(bm.verts.new(Vector((hx+cx*ri,hy+cy*ri,zz(t,ri)))));     bot_out.append(bm.verts.new(Vector((hx+cx*ro,hy+cy*ro,zz(t,ro)))))
    for i in range(seg):
        j=(i+1)%seg
        bm.faces.new([top_in[i],top_out[i],top_out[j],top_in[j]]); bm.faces.new([bot_in[j],bot_out[j],bot_out[i],bot_in[i]])
        bm.faces.new([top_out[i],bot_out[i],bot_out[j],top_out[j]])
def band(bm):
    m=bmesh.ops.create_cone(bm,cap_ends=False,segments=24,radius1=0.1003,radius2=0.0925,depth=0.022)
    for v in m['verts']: v.co+=Vector((hx,hy,top-0.045+0.034-0.034))
def tie(bm):
    zt=zc+0.03; y=front-0.0145
    knot=[(-0.020,zt+0.014),(0.020,zt+0.014),(0.015,zt-0.016),(-0.015,zt-0.016)]
    blade=[(-0.015,zt-0.014),(0.015,zt-0.014),(0.034,zt-0.205),(0.0,zt-0.240),(-0.034,zt-0.205)]
    for poly,th in ((knot,0.014),(blade,0.008)):
        f=[bm.verts.new(Vector((x,y,z))) for x,z in poly]; b=[bm.verts.new(Vector((x,y+th,z))) for x,z in poly]
        bm.faces.new(f[::-1]); bm.faces.new(b)
        for i in range(len(poly)):
            j=(i+1)%len(poly); bm.faces.new([f[i],f[j],b[j],b[i]])
def bevelbox(size,c):
    def f(bm):
        bmesh.ops.create_cube(bm,size=1.0)
        for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))+Vector(c)
        bmesh.ops.bevel(bm,geom=bm.edges[:],offset=0.012,segments=2,affect='EDGES')
    return f
pieces.append(prim("Outfit_HatCrown",crown,"Head",BLACK)); pieces.append(prim("Outfit_HatBrim",brim,"Head",BLACK)); pieces.append(prim("Outfit_HatBand",band,"Head",BAND))
pieces.append(prim("Outfit_Tie",tie,"spine_03",TIEW))
pieces.append(prim("Pack_Main",bevelbox((0.30,0.13,0.36),(0,back+0.075,zc-0.02)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchL",bevelbox((0.07,0.09,0.14),(0.17,back+0.075,zc-0.06)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchR",bevelbox((0.07,0.09,0.14),(-0.17,back+0.075,zc-0.06)),"spine_03",OLIVE))
# ---- mask the body under the clothes (not the hands: the gloves are a style that comes and goes) ----
bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); dgb=dgroup(bm)
cover=region("spine_","clavicle_","upperarm_","lowerarm_","pelvis","thigh_","calf_","foot_","ball_")
cov=set(v.index for v in bm.verts if cover(dgb(v)))
gone=[f for f in bm.faces if all(v.index in cov for v in f.verts)]
bmesh.ops.delete(bm,geom=gone,context='FACES'); sweep(bm); bm.to_mesh(body.data); bm.free(); print("T2 body faces masked",len(gone))
bpy.data.objects.remove(full,do_unlink=True)
if DEC<1.0:
    for o in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.polygons)>150]:
        bpy.context.view_layer.objects.active=o; m=o.modifiers.new("Decimate",'DECIMATE'); m.ratio=DEC; bpy.ops.object.modifier_apply(modifier="Decimate")
arm.data.pose_position='POSE'
tot=0
for o in bpy.context.scene.objects:
    if o.type=='MESH': n=sum(len(p.vertices)-2 for p in o.data.polygons); tot+=n; print("T2 piece",o.name,n)
print("T2 TOTAL tris",tot,"meshes",sum(1 for o in bpy.context.scene.objects if o.type=='MESH'))
bpy.ops.export_scene.gltf(filepath=D+f"hero{SUF}.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='MATERIAL'
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29); sc.render.resolution_x=420; sc.render.resolution_y=640
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.3; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
def shot(an,fr,az_deg,path,el_deg=18):
    if an is None: ad.action=None; arm.data.pose_position='REST'
    else:
        arm.data.pose_position='POSE'; a=bpy.data.actions[an]; ad.action=a; ad.action_slot=a.slots[0]; sc.frame_set(fr)
    az=math.radians(az_deg); el=math.radians(el_deg); ctr=Vector((0,0,0.9)); d=10
    co.location=ctr+Vector((d*math.cos(el)*math.sin(az),-d*math.cos(el)*math.cos(az),d*math.sin(el))); co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)
views=[(None,1,0),("Idle_Loop",20,30),("Walk_Formal_Loop",12,35),("Crouch_Idle_Loop",6,35)]
for style,hide in (("normal",["Outfit_Gloves"]),("black",["Outfit_Coat"])):
    for n in hide: bpy.data.objects[n].hide_render=True
    for k,(an,fr,az) in enumerate(views): shot(an,fr,az,SP+f"t2_{style}_{k}.png")
    for n in hide: bpy.data.objects[n].hide_render=False
print("OK t2")
