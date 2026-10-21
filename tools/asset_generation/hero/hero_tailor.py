# hero_tailor.py — our OWN costume, face and mask for the agile-B body, skinned to the same 65-bone skeleton (no CC0 suit was found; see ACTOR D74-D76).
# v4 (2026-10-21). ONE file holds every state; the engine shows a subset:
#   normal  = everything except Outfit_Gloves and the MASK kit;        black = hides Outfit_Coat + Outfit_CoatFlaps and the MASK kit (shirt/tie go dark);
#   mask    = black + the MASK kit (Mask_Face, Mask_Jaw, Mask_Eyes, Mask_Halo, Outfit_HatTilt*) and the UPRIGHT hat hidden.
# Pieces: shirt (+collar points, striped draped tie), jacket (V opening, rolled lapels, collar, buttons), trousers, two real shoes, gloves, the overcoat
# (loose, half open, standing collar, front flaps, a hump over the pack), fedora (+tipped copy for the mask), a flat black pack with two pouches, the MASK
# (a flat-shaded face plate, a jaw guard, slanted amber eye lenses and an additive halo), and FACE BLEND SHAPES on the skin / eyes / eyebrows
# (smile, frown, brow_up, brow_down, blink, eyes_wide, jaw_open; the decimated LOD has none by design).
# Env: HERO_REPO (repo root, trailing /), HERO_UAL_GLB (UAL1_Standard.glb), BODY_FILE (default superhero_male_agile_b_lean.glb), OUT_SUFFIX, COAT (mustard |
# beige | lightblue; default mustard), DECIMATE (LOD ratio; 0.2 gives ~5.9k tris with the mask kit, 0.166 ~5k without it), HERO_TMP (preview folder).
# Usage: blender -b -P hero_tailor.py
# ⚠️ Traps, all paid for: (0) THE GLTF IMPORT SPLITS VERTICES ALONG UV SEAMS: offset along per-vertex normals the seams drift apart and every piece CRACKS
# (the "openings at the shoulders"); weld with remove_doubles when copying the body. (1) A copy of the body carries its Armature modifier (a second one poses
# the piece twice). (2) The 43 UAL tracks all start at frame 1: keep the rig in REST while pieces are fitted and weighted. (3) Two bisect planes with
# clear_inner/clear_outer erase each other's hand. (4) Never set colorspace_settings on a generated image after its pixels (a BLANK buffer: black textures).
# (5) Workbench shows textured materials black in a background render: preview by colour, judge textures in the engine. (6) Group-dominance selection leaves
# the neck group out: those triangles become holes; include "neck_" and cut with a plane. (7) A comment on a line of `;`-joined statements eats the rest.
import os
import bpy, bmesh, math, os, sys
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree
SP=os.environ.get("HERO_TMP","/tmp/")
UAL=os.environ.get("HERO_UAL_GLB","")
D=os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
BODY=D+os.environ.get("BODY_FILE","superhero_male_agile_b_lean.glb"); SUF=os.environ.get("OUT_SUFFIX","_tailor4")
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
import numpy as np
def fabric(name,base,stripe=None,weave=0.025,grain=0.010,size=256,period=8,stripe_every=32,stripe_w=2):
    X,Y=np.meshgrid(np.arange(size),np.arange(size)); img=np.zeros((size,size,3))+np.array(base)
    tw=0.5+0.5*np.sin((X+Y)*2*math.pi/period); img*= (1.0-weave+weave*tw)[...,None]
    if stripe is not None:
        m=(X%stripe_every)<stripe_w; img[m]=np.array(stripe)*(1.0-weave+weave*tw[m])[...,None]
    rng=np.random.default_rng(7); img*=(1.0+rng.normal(0,grain,(size,size,1)))
    img=np.clip(img,0,1); rgba=np.concatenate([img,np.ones((size,size,1))],axis=2)
    im=bpy.data.images.new(name,size,size,alpha=True); im.pixels=rgba.flatten().tolist(); im.pack(); return im   # (never touch colorspace_settings after the pixels: it regenerates a blank buffer)
def tmat(name,image,rough=0.9):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; b=nt.nodes["Principled BSDF"]
    t=nt.nodes.new('ShaderNodeTexImage'); t.image=image; nt.links.new(t.outputs['Color'],b.inputs['Base Color']); nt.nodes.active=t
    b.inputs["Roughness"].default_value=rough
    for k in ("Specular IOR Level","Specular"):
        if k in b.inputs: b.inputs[k].default_value=0.12
    px=np.array(image.pixels[:]).reshape(-1,4); m.diffuse_color=(*[float(v) for v in px[:,:3].mean(axis=0)],1); return m
def mat(name,rgb,rough=0.85):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=rough; m.diffuse_color=(*rgb,1); return m
SUITIMG=fabric("Fabric_Pinstripe",(0.034,0.034,0.040),stripe=(0.15,0.15,0.17),weave=0.20,grain=0.03)
SUIT=tmat("Suit_Black",SUITIMG)                         # a black wool suit with a faint pinstripe and a twill weave: not latex
BLACK=mat("Hat_Black",(0.03,0.03,0.036))               # hat felt
COATS={"beige":(0.70,0.62,0.48),"lightblue":(0.60,0.72,0.85),"mustard":(0.80,0.64,0.24)}
COATIMGS={k:fabric("Fabric_Coat_"+k,v,weave=0.09,grain=0.03,period=6) for k,v in COATS.items()}
WHITE=tmat("Coat_Fabric",COATIMGS[os.environ.get("COAT","mustard")])
SHIRTIMG=fabric("Fabric_Shirt",(0.62,0.76,0.92),weave=0.05,grain=0.02,period=4); SHIRT=tmat("Shirt_Fabric",SHIRTIMG)
TIEIMG=fabric("Fabric_Tie",(0.55,0.08,0.10),stripe=(0.80,0.78,0.72),weave=0.10,grain=0.02,stripe_every=24,stripe_w=6); TIEW=tmat("Tie_Silk",TIEIMG,0.5)
OLIVE=mat("Pack_Black",(0.05,0.052,0.058),0.7); GLOVE=mat("Glove_Leather",(0.016,0.016,0.02),0.55); BAND=mat("Hat_Band",(0.12,0.12,0.14)); SHOE=mat("Shoe_Leather",(0.022,0.022,0.026),0.4)
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
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=0.0001)   # the glTF import SPLITS vertices along UV seams; offset along per-vertex normals they drift apart and the cloth CRACKS
    bm.verts.ensure_lookup_table(); return o,bm
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
    pred=lambda c: c.z>zn-0.14 and abs(c.x)<0.14 and c.y>-0.02
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
def buttons(bm,pts,r):
    bvh=BVHTree.FromBMesh(bm)
    if True:
        for (x,z) in pts:
            hit,nrm,idx,dist=bvh.ray_cast(Vector((x,-1.0,z)),Vector((0,1,0)))
            if hit is None: continue
            m=bmesh.ops.create_cone(bm,cap_ends=True,segments=10,radius1=r,radius2=r*0.9,depth=0.008)
            # cone axis is Z; turn it to face -Y and put it on the cloth
            bmesh.ops.rotate(bm,verts=m['verts'],cent=Vector(),matrix=__import__('mathutils').Matrix.Rotation(math.radians(90),3,'X'))
            bmesh.ops.translate(bm,verts=m['verts'],vec=hit+nrm*0.004)
def box_uv(bm,tile):
    uvl=bm.loops.layers.uv.verify(); bm.normal_update()
    for f in bm.faces:
        n=f.normal; ax=max(range(3),key=lambda i:abs(n[i]))
        for l in f.loops:
            p=l.vert.co
            u,v=((p.y,p.z) if ax==0 else (p.x,p.z) if ax==1 else (p.x,p.y))
            l[uvl].uv=(u/tile,v/tile)
def finish(o,bm,material,uv=None,facet=None):
    sweep(bm); bm.normal_update()
    if uv: box_uv(bm,uv)
    bm.to_mesh(o.data); bm.free()
    if facet:      # hard-surface: collapse to few planes and shade them flat
        dm=o.modifiers.new('Dec','DECIMATE'); dm.ratio=facet; bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier='Dec')
        for p_ in o.data.polygons: p_.use_smooth=False
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
TORSO=("spine_","pelvis","neck_")+ARMS      # the neck group too: left out, its triangles became HOLES at the shoulders
pieces=[]
BVH={}
def hull_shoe(name,side):
    """a real shoe: the convex hull of the foot (so the toes disappear into one smooth last), a pointed toe, a flat sole"""
    o,_=blank(name); _.free()
    src=bmesh.new(); src.from_mesh(full.data); src.verts.ensure_lookup_table(); dg=dgroup(src)
    pts=[v.co.copy() for v in src.verts if (dg(v) or "").startswith(("foot_","ball_")) and v.co.z<0.125 and side*v.co.x>0]
    src.free()
    bm=bmesh.new()
    for p in pts: bm.verts.new(p)
    ret=bmesh.ops.convex_hull(bm,input=bm.verts[:],use_existing_faces=False)
    junk=[g for g in set(ret['geom_unused'])|set(ret['geom_interior']) if isinstance(g,bmesh.types.BMVert)]
    if junk: bmesh.ops.delete(bm,geom=junk,context='VERTS')
    sweep(bm)
    cx=sum(v.co.x for v in bm.verts)/len(bm.verts); ymin=min(v.co.y for v in bm.verts); ymax=max(v.co.y for v in bm.verts)
    bm.normal_update()
    for v in bm.verts:
        v.co+=v.normal*0.011
        t=max(0.0,(ymin+0.10-v.co.y)/0.10)               # the front tenth of the foot: a longer, narrower toe
        v.co.y-=0.022*t; v.co.x=cx+(v.co.x-cx)*(1.0-0.16*t)
        if v.co.z<0.016: v.co.z=0.0                      # a flat sole on the ground
        if v.co.z>0.04: v.co.y+= -0.004*(v.co.z-0.04)*8  # a slight forward lean of the vamp
    bmesh.ops.subdivide_edges(bm,edges=bm.edges[:],cuts=1,smooth=0.7,use_grid_fill=False); bm.normal_update()
    return o,bm
TORSO=("spine_","pelvis","neck_")+ARMS      # the neck group too: left out, its triangles became HOLES at the shoulders
# ---- shirt: a body, plus a spread collar whose points lie on the jacket ----
o,bm=blank("Outfit_Shirt"); keep_groups(bm,region("spine_","pelvis","clavicle_","neck_")); plane(bm,(0,0,1.02),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
displace(bm,0.007); collar(bm,0.032,1.06,1); BVH["shirt"]=BVHTree.FromBMesh(bm)
pieces.append(finish(o,bm,SHIRT,uv=0.10))
# ---- jacket: a little looser, pinstriped wool ----
o,bm=blank("Outfit_Jacket"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
plane(bm,(wx-0.012,0,0),(1,0,0),outer=True); plane(bm,(-(wx-0.012),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.008)
displace(bm,lambda v: 0.037+sh(v)+(0.006 if abs(v.co.x)>0.2 else 0.0)+(max(0.0,zc-v.co.z)*0.05 if abs(v.co.x)<0.25 else 0.0))
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0050)
vopen(bm,zc-0.17,zn+0.02,0.060); smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.13 and c.z>zc-0.25)
lapels(bm,zc-0.17,0.058,0.008)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.40,0.175,1.08,3)
collar(bm,0.050,1.16,2); cuffs(bm,wx-0.012,0.018,1.05)
noisy(bm,0.0025); buttons(bm,[(0.0,zc-0.20),(0.0,zc-0.30)],0.011); BVH["jacket"]=BVHTree.FromBMesh(bm)
JAC=(o,bm)
# ---- trousers: pinstriped, falling over the shoes ----
o,bm=blank("Outfit_Trousers"); keep_groups(bm,region("pelvis","thigh_","calf_","foot_","ball_"))
plane(bm,(0,0,1.0),(0,0,1),outer=True); plane(bm,(0,0,0.075),(0,0,1),inner=True)
def loose(v): t=max(0.0,min(1.0,(1.0-v.co.z)/0.90)); return 0.014+0.020*t
displace(bm,loose); folds(bm,[("calf_l",None),("calf_r",None)],0.0055,0.09,70.0)
hem(bm,lambda c: c.z<0.12,0.012,1.04,1); noisy(bm,0.002)
pieces.append(finish(o,bm,SUIT,uv=0.22))
# ---- shoes: a real last, a pointed toe, a flat sole (no spats) ----
for nm,sd in (("Outfit_ShoeL",1),("Outfit_ShoeR",-1)):
    o,bm=hull_shoe(nm,sd); pieces.append(finish(o,bm,SHOE))
# ---- gloves ----
o,bm=blank("Outfit_Gloves"); keep_groups(bm,region("hand_","index_","middle_","pinky_","ring_","thumb_"))
plane(bm,(wx-0.015,0,0),(1,0,0)); plane(bm,(-(wx-0.015),0,0),(-1,0,0))       # split only: the two cuts would erase each other's hand
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)<wx-0.0149],context='FACES'); sweep(bm)
displace(bm,0.0045); cuffs(bm,wx-0.015,-0.035,1.12)
pieces.append(finish(o,bm,GLOVE))
# ---- the overcoat: loose, hanging half open like Dick Tracy's, the black suit showing inside ----
o,bm=blank("Outfit_Coat"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
plane(bm,(wx+0.02,0,0),(1,0,0),outer=True); plane(bm,(-(wx+0.02),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.046)
displace(bm,lambda v: (0.068 if abs(v.co.x)<0.20 else 0.058)+sh(v)+(max(0.0,zc-v.co.z)*0.12 if abs(v.co.x)<0.25 else 0.0))
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0045)
bmesh.ops.smooth_vert(bm,verts=bm.verts[:],factor=0.55,use_axis_x=True,use_axis_y=True,use_axis_z=True)
bmesh.ops.smooth_vert(bm,verts=bm.verts[:],factor=0.55,use_axis_x=True,use_axis_y=True,use_axis_z=True)
bmesh.ops.smooth_vert(bm,verts=bm.verts[:],factor=0.45,use_axis_x=True,use_axis_y=True,use_axis_z=True)
displace(bm,0.024)       # smoothing shrinks the cloth onto the muscles: give the room back so the jacket never shows through
def coat_w(z): return 0.045 if z>=zn+0.03 else 0.045+0.085*min(1.0,(zn+0.03-z)/(zn+0.03-1.03))
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().y<0.0 and abs(f.calc_center_median().x)<coat_w(f.calc_center_median().z)],context='FACES'); sweep(bm)
smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.18 and c.z>zc-0.60,iters=5)
lapels(bm,zc-0.25,0.080,0.014)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.50,0.58,1.22,5)
for v in bm.verts:   # a modest hump: the pack lies flat against the back
    if v.co.y>0.0 and abs(v.co.x)<0.22:
        tz=max(0.0,min(1.0,(0.27-abs(v.co.z-(zc-0.03)))/0.12)); tx=max(0.0,min(1.0,(0.22-abs(v.co.x))/0.08)); v.co.y+=0.045*tz*tx*(3-2*tz*tx)
collar(bm,0.088,1.30,3); cuffs(bm,wx+0.02,0.02,1.05)
noisy(bm,0.0035); buttons(bm,[(coat_w(z)+0.030,z) for z in (zc-0.02,zc-0.12,zc-0.22)],0.013)
COATBVH=BVHTree.FromBMesh(bm); BVH["coat"]=COATBVH
pushed=0
for v in JAC[1].verts:      # wherever the jacket would show THROUGH the coat (shoulders, arms, back), sink it under; the open front and the collar stay
    c=v.co
    if (c.y<0.0 and abs(c.x)<0.17 and c.z>zc-0.5) or c.z>zn-0.04: continue
    loc,nrm,idx,dist=COATBVH.find_nearest(c)
    if loc is None: continue
    out=(c-loc).dot(nrm)
    if out>-0.012:
        v.co-=v.normal*(max(out,0.0)+0.016); pushed+=1
print("T2 jacket verts pushed under the coat",pushed)
pieces.append(finish(*JAC,SUIT,uv=0.22))
pieces.append(finish(o,bm,WHITE,uv=0.22))
# ---- hat, band, tie (hugging the shirt), collar points, flat pack ----
def prim(name,build,group,material):
    bm=bmesh.new(); build(bm); me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE'); me.materials.append(material)
    o.parent=arm; m=o.modifiers.new("Armature",'ARMATURE'); m.object=arm; return o
hb=bw("Head"); hx,hy,top=hb.x,hb.y-0.005,1.80
def crown(bm):
    m=bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=True,segments=24,radius1=0.099,radius2=0.088,depth=0.118)
    for v in m['verts']: v.co+=Vector((hx,hy,top-0.045+0.034))
    ct=max(m['verts'],key=lambda v:v.co.z-(abs(v.co.x-hx)+abs(v.co.y-hy))*10); ct.co.z-=0.022
    for v in m['verts']:
        if v.co.z>top-0.045+0.034 and v.co.y<hy-0.02: v.co.x=hx+(v.co.x-hx)*0.88
def brim(bm,ro=0.158):
    seg=36; ri,th=0.096,0.005; zb=top-0.092+0.035
    def zz(t,r):
        k=(r-ri)/(ro-ri); return zb+0.016*abs(math.sin(t))*k-0.020*max(0.0,math.cos(t))*k
    ti=[];to=[];bi=[];bo=[]
    for i in range(seg):
        t=2*math.pi*i/seg; cx,cy=math.sin(t),-math.cos(t)
        ti.append(bm.verts.new(Vector((hx+cx*ri,hy+cy*ri,zz(t,ri)+th)))); to.append(bm.verts.new(Vector((hx+cx*ro,hy+cy*ro,zz(t,ro)+th))))
        bi.append(bm.verts.new(Vector((hx+cx*ri,hy+cy*ri,zz(t,ri))))); bo.append(bm.verts.new(Vector((hx+cx*ro,hy+cy*ro,zz(t,ro)))))
    for i in range(seg):
        j=(i+1)%seg
        bm.faces.new([ti[i],to[i],to[j],ti[j]]); bm.faces.new([bi[j],bo[j],bo[i],bi[i]]); bm.faces.new([to[i],bo[i],bo[j],to[j]])
def band(bm):
    m=bmesh.ops.create_cone(bm,cap_ends=False,segments=24,radius1=0.1003,radius2=0.0925,depth=0.022)
    for v in m['verts']: v.co+=Vector((hx,hy,top-0.045))
def conform(bm,bvh,pts,lift,uvs=None):
    out=[]
    for (x,z) in pts:
        hit,nrm,idx,dist=bvh.ray_cast(Vector((x,-1.0,z)),Vector((0,1,0)))
        out.append(bm.verts.new((hit+nrm*lift) if hit is not None else Vector((x,front-0.02,z))))
    return out
def tie(bm):
    zt=zc+0.045; segs=12
    rows=[]
    for i in range(segs+1):
        t=i/segs; z=zt-0.03-0.225*t
        w=0.016+0.020*math.sin(min(1.0,t*1.15)*math.pi*0.5) if t<0.9 else 0.036*(1.0-(t-0.9)/0.1*0.95)
        rows.append(conform(bm,BVH["shirt"],[(-w,z),(w,z)],0.0105))
    for i in range(segs): bm.faces.new([rows[i][0],rows[i][1],rows[i+1][1],rows[i+1][0]])
    knot=[conform(bm,BVH["shirt"],[(-0.021+0.042*a/3,zt+0.016-0.05*b/3) for a in range(4)],0.0105+0.0075*math.sin(math.pi*(b/3.0))) for b in range(4)]
    for b in range(3):
        for a in range(3): bm.faces.new([knot[b][a],knot[b][a+1],knot[b+1][a+1],knot[b+1][a]])
def collar_points(bm):
    for s in (1,-1):
        P=conform(bm,BVH["jacket"],[(s*0.026,zn-0.004),(s*0.088,zn-0.050),(s*0.018,zn-0.110)],0.006)
        bm.faces.new(P if s>0 else P[::-1])
def coat_flaps(bm):
    for s in (1,-1):
        P=conform(bm,BVH["coat"],[(s*0.034,zn+0.012),(s*0.118,zn-0.012),(s*0.130,zn-0.130),(s*0.050,zn-0.100)],0.012)
        P[1].co.x+=s*0.012; P[1].co.z+=0.012; P[1].co.y-=0.020; P[2].co.x+=s*0.014; P[2].co.y-=0.016   # the outer corners lift off the coat
        bm.faces.new(P if s>0 else P[::-1])
def bevelbox(size,c):
    def f(bm):
        bmesh.ops.create_cube(bm,size=1.0)
        for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))+Vector(c)
        bmesh.ops.bevel(bm,geom=bm.edges[:],offset=0.010,segments=2,affect='EDGES')
    return f
pieces.append(prim("Outfit_HatCrown",crown,"Head",BLACK)); pieces.append(prim("Outfit_HatBrim",brim,"Head",BLACK)); pieces.append(prim("Outfit_HatBand",band,"Head",BAND))
pieces.append(prim("Outfit_Tie",tie,"spine_03",TIEW))
SHIRTCOLLAR=mat("Shirt_Collar",(0.88,0.90,0.94),0.8)
pieces.append(prim("Outfit_CollarPoints",collar_points,"spine_03",SHIRTCOLLAR))
pieces.append(prim("Outfit_CoatFlaps",coat_flaps,"spine_03",WHITE))
pieces.append(prim("Pack_Main",bevelbox((0.25,0.065,0.29),(0,back+0.040,zc-0.02)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchL",bevelbox((0.055,0.05,0.11),(0.150,back+0.040,zc-0.04)),"spine_03",OLIVE))
pieces.append(prim("Pack_PouchR",bevelbox((0.055,0.05,0.11),(-0.150,back+0.040,zc-0.04)),"spine_03",OLIVE))

# ================= THE MASK (D71): a face plate, a jaw guard that rises from the collar, amber eye lenses with a halo, and the hat tipped forward =================
MASKBLACK=mat("Mask_Black",(0.028,0.029,0.034),0.55)
EYEGLOW=mat("Mask_EyeGlow",(1.0,0.62,0.12),0.4); _b=EYEGLOW.node_tree.nodes["Principled BSDF"]
for k_,v_ in (("Emission Color",(1.0,0.55,0.08,1.0)),("Emission Strength",6.0)):
    if k_ in _b.inputs: _b.inputs[k_].default_value=v_
HALO=mat("Mask_EyeHalo",(1.0,0.55,0.10),0.4)
o,bm=blank("Mask_Face"); keep_groups(bm,region("Head"))
plane(bm,(0,0.050,0),(0,1,0),outer=True); plane(bm,(0,0,1.742),(0,0,1),outer=True); plane(bm,(0,0,1.592),(0,0,1),inner=True)
displace(bm,0.016)
mface=finish(o,bm,MASKBLACK,facet=0.12); pieces.append(mface)
bmf=bmesh.new(); bmf.from_mesh(mface.data); BVH["maskface"]=BVHTree.FromBMesh(bmf)
o,bm=blank("Mask_Jaw"); keep_groups(bm,region("Head","neck_"))
plane(bm,(0,0,1.632),(0,0,1),outer=True); plane(bm,(0,0,1.511),(0,0,1),inner=True); plane(bm,(0,0.045,0),(0,1,0),outer=True)
displace(bm,0.021); pieces.append(finish(o,bm,MASKBLACK,facet=0.10))
def eye_lenses(bm):       # slanted amber lenses, narrowest at the nose, like the reference's visor slits
    for s_ in (1,-1):
        P=conform(bm,BVH["maskface"],[(s_*0.012,1.688),(s_*0.014,1.699),(s_*0.058,1.715),(s_*0.056,1.704)],0.007)
        bm.faces.new(P if s_>0 else P[::-1])
def eye_halos(bm):        # a soft additive glow around each lens (the engine draws it; UVs run 0..1)
    uvl=bm.loops.layers.uv.verify()
    for s_ in (1,-1):
        c=(s_*0.036,1.704); hw,hh=0.066,0.036
        P=conform(bm,BVH["maskface"],[(c[0]-hw,c[1]-hh),(c[0]+hw,c[1]-hh),(c[0]+hw,c[1]+hh),(c[0]-hw,c[1]+hh)],0.011)
        f=bm.faces.new(P if s_>0 else P[::-1])
        for l_ in f.loops: l_[uvl].uv=(0.5+(l_.vert.co.x-c[0])/(2*hw),0.5+(l_.vert.co.z-c[1])/(2*hh))
pieces.append(prim("Mask_Eyes",eye_lenses,"Head",EYEGLOW)); pieces.append(prim("Mask_Halo",eye_halos,"Head",HALO))
def tipped(fn,deg=8.0,up=0.028):  # the same hat, pitched forward about a hinge at the nape (the animation will use a bone there)
    def g(bm):
        fn(bm); piv=Vector((hx,hy+0.085,1.745)); th=math.radians(deg)
        for v in bm.verts:
            p=v.co-piv; v.co=piv+Vector((p.x,p.y*math.cos(th)-p.z*math.sin(th)-0.020,p.y*math.sin(th)+p.z*math.cos(th)+up))     # up first, then forward: the brim must shade the forehead, not the lenses
    return g
# in the mask the brim is a short visor: a long one hides the lenses from the iso camera (30 deg above)
pieces.append(prim("Outfit_HatTiltCrown",tipped(crown,deg=6.0,up=0.036),"Head",BLACK))
pieces.append(prim("Outfit_HatTiltBrim",tipped(lambda bm: brim(bm,0.118),deg=6.0,up=0.036),"Head",BLACK))
pieces.append(prim("Outfit_HatTiltBand",tipped(band,deg=6.0,up=0.036),"Head",BAND))
MASKSET=["Mask_Face","Mask_Jaw","Mask_Eyes","Mask_Halo","Outfit_HatTiltCrown","Outfit_HatTiltBrim","Outfit_HatTiltBand"]; HATUP=["Outfit_HatCrown","Outfit_HatBrim","Outfit_HatBand"]
# ---- mask the body under the clothes (not the hands: the gloves are a style that comes and goes) ----
bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); dgb=dgroup(bm)
cover=region("spine_","clavicle_","upperarm_","lowerarm_","pelvis","thigh_","calf_","foot_","ball_")
cov=set(v.index for v in bm.verts if cover(dgb(v)))
gone=[f for f in bm.faces if all(v.index in cov for v in f.verts)]
bmesh.ops.delete(bm,geom=gone,context='FACES'); sweep(bm); bm.to_mesh(body.data); bm.free(); print("T2 body faces masked",len(gone))

# ---------- FACE: blend shapes for basic expressions (the free body has no face rig at all) ----------
def gauss(p,c,sx,sy=None,sz=None):
    sy=sy or sx; sz=sz or sx
    return math.exp(-(((p.x-c[0])/sx)**2+((p.y-c[1])/sy)**2+((p.z-c[2])/sz)**2)*0.5)
EYE_Z=1.698; BROW_Z=1.725; MOUTH_Z=1.624; CORNER=(0.026,-0.098,1.622)
def face_delta(name,p):
    d=Vector((0,0,0)); s_=1.0 if p.x>=0 else -1.0
    if not (-0.11<p.x<0.11 and 1.56<p.z<1.82 and p.y<0.02): return d
    if name=="smile":
        c=(s_*CORNER[0],CORNER[1],CORNER[2]); d+=Vector((s_*0.006,-0.002,0.010))*gauss(p,c,0.018)
        d+=Vector((0,-0.004,0.007))*gauss(p,(s_*0.048,-0.09,1.652),0.026)
        d+=Vector((0,0,0.003))*gauss(p,(s_*0.04,-0.07,1.688),0.02)          # cheeks lift into the lower lids
    elif name=="frown":
        c=(s_*CORNER[0],CORNER[1],CORNER[2]); d+=Vector((-s_*0.002,0.002,-0.009))*gauss(p,c,0.018)
        d+=Vector((0,0,0.004))*gauss(p,(s_*0.016,-0.095,BROW_Z),0.013)
        d+=Vector((0,0.001,-0.003))*gauss(p,(0,-0.1,1.608),0.014)
    elif name=="brow_up":
        d+=Vector((0,-0.001,0.012))*gauss(p,(s_*0.034,-0.09,BROW_Z+0.002),0.03,0.02,0.018)
    elif name=="brow_down":
        d+=Vector((0,-0.004,-0.011))*gauss(p,(s_*0.016,-0.092,BROW_Z),0.016,0.02,0.014)
        d+=Vector((0,0,0.004))*gauss(p,(s_*0.058,-0.082,BROW_Z+0.004),0.014)
    elif name=="blink":
        dx=p.x-s_*0.034; dz=p.z-EYE_Z; r=math.hypot(dx,dz)*1.0
        if p.y<-0.03 and r<0.034:
            g=1.0-r/0.034
            if p.z>=EYE_Z-0.002: d.z=-(p.z-(EYE_Z-0.004))*0.82*g
            else: d.z=(EYE_Z-0.004-p.z)*0.35*g
    elif name=="eyes_wide":
        d+=Vector((0,0,0.007))*gauss(p,(s_*0.034,-0.088,EYE_Z+0.012),0.02,0.02,0.012)
        d+=Vector((0,0,0.005))*gauss(p,(s_*0.034,-0.09,BROW_Z),0.03,0.02,0.016)
    elif name=="jaw_open":
        w=max(0.0,min(1.0,(1.640-p.z)/0.030))
        if w>0.0 and p.y<0.045:
            th=math.radians(17.0)*w; hy,hz=0.005,1.668
            ry,rz=p.y-hy,p.z-hz
            d=Vector((0,ry*math.cos(th)-rz*math.sin(th)-ry,ry*math.sin(th)+rz*math.cos(th)-rz))
    return d
FACE_KEYS=("smile","frown","brow_up","brow_down","blink","eyes_wide","jaw_open")
def add_face_keys(obj):
    if obj.data.shape_keys is None: obj.shape_key_add(name="Basis",from_mix=False)
    for kn in FACE_KEYS:
        sk=obj.shape_key_add(name=kn,from_mix=False)
        for i,v in enumerate(obj.data.vertices): sk.data[i].co=v.co+face_delta(kn,v.co)
if DEC>=1.0:       # a decimated LOD cannot carry shape keys, and the game LOD never needs a face (the mask covers it)
    for o_ in (body,bpy.data.objects.get("Eyebrows"),bpy.data.objects.get("Eyes")):
        if o_ is not None: add_face_keys(o_)
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
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sh=sc.display.shading; sh.light='STUDIO'; sh.color_type='MATERIAL'; sh.show_specular_highlight=False
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.25,0.26,0.29); sc.render.resolution_x=420; sc.render.resolution_y=640
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=2.3; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
CTR=Vector((0,0,0.9)); ORTHO=2.3
def shot(an,fr,az_deg,path,el_deg=18):
    if an is None: ad.action=None; arm.data.pose_position='REST'
    else:
        arm.data.pose_position='POSE'; a=bpy.data.actions[an]; ad.action=a; ad.action_slot=a.slots[0]; sc.frame_set(fr)
    az=math.radians(az_deg); el=math.radians(el_deg); ctr=CTR; d=10; cam.ortho_scale=ORTHO
    co.location=ctr+Vector((d*math.cos(el)*math.sin(az),-d*math.cos(el)*math.cos(az),d*math.sin(el))); co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)
def set_coat(key):
    t=[n for n in WHITE.node_tree.nodes if n.type=='TEX_IMAGE'][0]; t.image=COATIMGS[key]; WHITE.diffuse_color=(*COATS[key],1)
views=[(None,1,0),("Idle_Loop",20,30),("Walk_Formal_Loop",12,35),("Crouch_Idle_Loop",6,35)]
for style,hide in (("normal",["Outfit_Gloves"]+MASKSET),("black",["Outfit_Coat","Outfit_CoatFlaps"]+MASKSET),("mask",["Outfit_Coat","Outfit_CoatFlaps","Mask_Halo"]+HATUP)):
    for n in hide: bpy.data.objects[n].hide_render=True
    keep=(tuple(SHIRT.diffuse_color),tuple(TIEW.diffuse_color),tuple(SHIRTCOLLAR.diffuse_color))
    if style in ('black','mask'): SHIRT.diffuse_color=(0.03,0.03,0.04,1); TIEW.diffuse_color=(0.04,0.04,0.05,1); SHIRTCOLLAR.diffuse_color=(0.05,0.05,0.06,1)
    for k,(an,fr,az) in enumerate(views): shot(an,fr,az,SP+f"t3_{style}_{k}.png")
    if style=="mask":
        CTR=Vector((0,-0.04,1.64)); ORTHO=0.62
        for k2,az2 in enumerate((0,28,-28)): shot("Idle_Loop",20,az2,SP+f"mask_close_{k2}.png",el_deg=6)
        CTR=Vector((0,0,0.9)); ORTHO=2.3
    SHIRT.diffuse_color,TIEW.diffuse_color,SHIRTCOLLAR.diffuse_color=keep
    for n in hide: bpy.data.objects[n].hide_render=False
for key in COATS:       # the coat colour test: the same pose, three coats
    set_coat(key); bpy.data.objects["Outfit_Gloves"].hide_render=True
    shot("Idle_Loop",20,30,SP+f"t3c_{key}_0.png"); shot("Walk_Formal_Loop",12,35,SP+f"t3c_{key}_1.png")
CTR=Vector((0,-0.03,1.52)); ORTHO=0.85
for k,az in enumerate((0,35,-35)):
    bpy.data.objects["Outfit_Gloves"].hide_render=True
    shot("Walk_Formal_Loop",12,az,SP+f"t4_close_{k}.png",el_deg=22)
if DEC>=1.0:
    arm.data.pose_position='REST'; ad.action=None
    for n_ in [o_.name for o_ in bpy.context.scene.objects if o_.type=='MESH' and o_.name.startswith(("Outfit_Hat","Mask_","Outfit_Tie","Outfit_Coat","Outfit_Jacket","Outfit_Shirt","Outfit_Collar","Pack_"))]: bpy.data.objects[n_].hide_render=True
    CTR=Vector((0,-0.04,1.69)); ORTHO=0.34
    for k,ex in enumerate(("neutral",)+FACE_KEYS):
        for o_ in (body,bpy.data.objects["Eyebrows"],bpy.data.objects["Eyes"]):
            for kb in o_.data.shape_keys.key_blocks: kb.value=1.0 if kb.name==ex else 0.0
        shot(None,1,0,SP+f"face_{k}.png",el_deg=0)
    for o_ in (body,bpy.data.objects["Eyebrows"],bpy.data.objects["Eyes"]):
        for kb in o_.data.shape_keys.key_blocks: kb.value=0.0
print("OK t3")
