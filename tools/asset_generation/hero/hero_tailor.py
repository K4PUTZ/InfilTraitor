# hero_tailor.py — our OWN costume, face and mask for the agile-B body, skinned to the same 65-bone skeleton (no CC0 suit was found; see ACTOR D74-D77).
# v5 (2026-10-21). ONE file holds every state; the engine shows a subset:
#   normal = everything except Outfit_Gloves and the MASK kit;   black = hides Outfit_Coat and the MASK kit (shirt/tie/trim go dark);
#   mask   = black + the MASK kit (Mask_Shell, Mask_Band, Mask_Jaw, Mask_Eyes, Mask_Halo) with the hat AND Face_Hair / Face_Beard hidden: the hat's crown IS
#            the mask (D77), so the masked agent wears no hat. Face_Beard is optional in the unmasked states (the bench's `_shaved` hides it).
# Pieces: shirt, contrast trim (turned-down collar, cuffs, pocket square), a thick tie (knot, diagonal stripes, tie bar), jacket (V opening, lapels), trousers
# with a break, two parametric shoes, gloves, the overcoat (DRAPED over the body and the pack, lined, half open, wide lapels, a standing collar), an oval
# fedora (teardrop crease, front pinches, snap brim), a flat black pack with two back pockets, CC0 hair, a short boxed beard grown from the face, the MASK
# (felt crown shell with the fedora's crease, the band across the eyes with amber lenses and an additive halo, smooth jaw plates), and FACE BLEND SHAPES on
# the skin / eyes / eyebrows / beard (smile, frown, brow_up, brow_down, blink, eyes_wide, jaw_open; the decimated LOD has none by design).
# Env: HERO_REPO (repo root, trailing /), HERO_UAL_GLB (UAL1_Standard.glb), HERO_HAIR_DIR (the pack's "Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/",
# trailing /; empty = no hair), BODY_FILE (default superhero_male_agile_b_lean.glb), OUT_SUFFIX, COAT (mustard | beige | lightblue; default mustard), BEARD
# (1 | 0), DECIMATE (LOD ratio; 0.2 for the game LOD, weighted per piece by LOD_WEIGHT), HERO_TMP (preview folder), PREVIEW (full | quick | none).
# Usage: blender -b -P hero_tailor.py
# ⚠️ Traps, all paid for: (0) THE GLTF IMPORT SPLITS VERTICES ALONG UV SEAMS: offset along per-vertex normals the seams drift apart and every piece CRACKS
# (the "openings at the shoulders"); weld with remove_doubles when copying the body. (1) A copy of the body carries its Armature modifier (a second one poses
# the piece twice). (2) The 43 UAL tracks all start at frame 1: keep the rig in REST while pieces are fitted and weighted. (3) Two bisect planes with
# clear_inner/clear_outer erase each other's hand. (4) Never set colorspace_settings on a generated image after its pixels (a BLANK buffer: black textures).
# (5) Workbench shows textured materials black in a background render: the previews use EEVEE. (6) Group-dominance selection leaves the neck group out:
# those triangles become holes; include "neck_" and cut with a plane. (7) A comment on a line of `;`-joined statements eats the rest. (8) OFFSETTING THE
# MUSCLED BODY ALONG ITS NORMALS INFLATES EVERY MUSCLE (the v4 coat "looks somewhat inflated", Director): drape() instead. (9) The game's actor shaders are cull_back,
# so a single-layer piece is see-through from behind (read from the shaders, not yet seen in the engine): the open coat is lined, the collar, the tie and the
# brim have a thickness. (10) Blender 5.2's shape_key_add() makes a key at value 1.0: v4 EXPORTED every expression switched on at once (the "pouty, open"
# mouth); set each to 0. (11) drape() takes the cut rings' heights BEFORE its first offset (taken after, the neck ring tilted and the collar skipped the
# edges no longer level: two slits). (12) A cloth that starts INSIDE the pack is pushed back toward the body by the pack's inner face: over_pack() first.
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree
SP=os.environ.get("HERO_TMP","/tmp/")
UAL=os.environ.get("HERO_UAL_GLB","")
HAIRD=os.environ.get("HERO_HAIR_DIR","")
D=os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
BODY=D+os.environ.get("BODY_FILE","superhero_male_agile_b_lean.glb"); SUF=os.environ.get("OUT_SUFFIX","_tailor5")
DEC=float(os.environ.get("DECIMATE","1.0")); PREVIEW=os.environ.get("PREVIEW","full")
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

# ---------- THE FACE (D75, D77): a leaner jaw, a firmer chin, a touch of cheekbone. ONE smooth field moves the skin, the eyes, the brows and the beard
# together, so nothing slides off the face; the hair, the beard and dark brows (the pack's brows were white) do the rest ----------
def sculpt(p):
    d=Vector((0,0,0))
    if p.z<1.53 or p.y>0.09: return d
    wz=math.exp(-((p.z-1.603)/0.030)**2); wy=max(0.0,min(1.0,(0.05-p.y)/0.07))
    ax=abs(p.x); wx_=max(0.0,min(1.0,(ax-0.032)/0.028)); wx_=wx_*wx_*(3-2*wx_)
    d.x=-0.075*p.x*wz*wy*wx_                                                                                    # the Superhero's jaw angle comes in ~7% (the mouth is left alone)
    d.y=-0.0035*math.exp(-((p.x/0.026)**2+((p.z-1.582)/0.016)**2))*max(0.0,min(1.0,(-0.04-p.y)/0.03))           # a firmer chin
    s=1.0 if p.x>=0 else -1.0
    d.x+=s*0.0030*math.exp(-(((p.x-s*0.056)/0.016)**2+((p.y+0.064)/0.02)**2+((p.z-1.668)/0.014)**2))           # cheekbones
    return d
for o_ in (body,bpy.data.objects.get("Eyebrows"),bpy.data.objects.get("Eyes")):
    if o_ is not None:
        for v in o_.data.vertices: v.co+=sculpt(v.co)
full=body.copy(); full.data=body.data.copy(); full.name="BodyFull"; bpy.context.scene.collection.objects.link(full); full.parent=None
for m_ in list(full.modifiers): full.modifiers.remove(m_)
names=[g.name for g in body.vertex_groups]
_bb=bmesh.new(); _bb.from_mesh(full.data); bmesh.ops.remove_doubles(_bb,verts=_bb.verts[:],dist=0.0001); _bb.verts.ensure_lookup_table()
BODY_V=[v.co.copy() for v in _bb.verts]; BODY_F=[[v.index for v in f.verts] for f in _bb.faces]; BODYBVH=BVHTree.FromBMesh(_bb); _bb.free()
def fabric(name,base,stripe=None,weave=0.025,grain=0.010,size=256,period=8,stripe_every=32,stripe_w=2):
    X,Y=np.meshgrid(np.arange(size),np.arange(size)); img=np.zeros((size,size,3))+np.array(base)
    tw=0.5+0.5*np.sin((X+Y)*2*math.pi/period); img*= (1.0-weave+weave*tw)[...,None]
    if stripe is not None:
        m=(X%stripe_every)<stripe_w; img[m]=np.array(stripe)*(1.0-weave+weave*tw[m])[...,None]
    rng=np.random.default_rng(7); img*=(1.0+rng.normal(0,grain,(size,size,1)))
    return image(name,img)
def image(name,img):
    size=img.shape[0]; img=np.clip(img,0,1); rgba=np.concatenate([img,np.ones((size,img.shape[1],1))],axis=2)
    im=bpy.data.images.new(name,img.shape[1],size,alpha=True); im.pixels=rgba.flatten().tolist(); im.pack(); return im   # (never touch colorspace_settings after the pixels: it regenerates a blank buffer)
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
BLACK=mat("Hat_Black",(0.03,0.03,0.036))               # hat felt (and the mask's crown shell: it is the same felt, D77)
COATS={"beige":(0.70,0.62,0.48),"lightblue":(0.60,0.72,0.85),"mustard":(0.80,0.64,0.24)}
COATIMGS={k:fabric("Fabric_Coat_"+k,v,weave=0.09,grain=0.03,period=6) for k,v in COATS.items()}
WHITE=tmat("Coat_Fabric",COATIMGS[os.environ.get("COAT","mustard")])
SHIRTIMG=fabric("Fabric_Shirt",(0.62,0.76,0.92),weave=0.05,grain=0.02,period=4); SHIRT=tmat("Shirt_Fabric",SHIRTIMG)
def tie_texture():
    """burgundy silk with thin diagonal gold stripes (45 degrees in METRES: the tie's own UVs are isotropic), and a flat gold patch in the top-left corner
    that the tie bar's UVs point into, so the bar is the same surface (no extra draw call)"""
    n=256; X,Y=np.meshgrid(np.arange(n),np.arange(n)); img=np.zeros((n,n,3))+np.array((0.36,0.055,0.085))
    tw=0.5+0.5*np.sin((X-Y)*2*math.pi/3.0); img*=(0.93+0.07*tw)[...,None]
    s=((X+Y)%13)<2; img[s]=np.array((0.74,0.60,0.32))*(0.93+0.07*tw[s])[...,None]
    s2=((X+Y+6)%13)==0; img[s2]=np.array((0.10,0.12,0.24))
    img[n-24:,:24]=np.array((0.86,0.72,0.42)); img[n-24:,:24]*=(0.85+0.15*(X[n-24:,:24]%3==0))[...,None]
    return image("Fabric_Tie",img)
TIEIMG=tie_texture(); TIEW=tmat("Tie_Silk",TIEIMG,0.45)
OLIVE=mat("Pack_Black",(0.05,0.052,0.058),0.7); GLOVE=mat("Glove_Leather",(0.016,0.016,0.02),0.55); BAND=mat("Hat_Band",(0.12,0.12,0.14)); SHOE=mat("Shoe_Leather",(0.022,0.022,0.026),0.4)
TRIM=mat("Shirt_Collar",(0.90,0.91,0.93),0.8)           # the contrast collar, cuffs and pocket square (a blue shirt with a white collar: the 1930s executive)
bw=lambda a: arm.matrix_world@arm.data.bones[a].head_local
bt=lambda a: arm.matrix_world@arm.data.bones[a].tail_local
wx=abs(bw("hand_l").x); zc=bw("spine_03").z; zn=bw("neck_01").z
ys=[v.co.y for v in full.data.vertices if abs(v.co.x)<0.04 and abs(v.co.z-zc)<0.05]; front=min(ys); back=max(ys)
print("T5 wrist x",round(wx,3),"zc",round(zc,3),"zn",round(zn,3),"front/back",round(front,3),round(back,3))
def region(*pre): return lambda n: n is not None and any(n.startswith(p) for p in pre)
ARMS=("clavicle_","upperarm_","lowerarm_","hand_","index_","middle_","pinky_","ring_","thumb_")
def blank(name):
    o=body.copy(); o.data=full.data.copy(); o.name=name; bpy.context.scene.collection.objects.link(o)
    for m_ in list(o.modifiers): o.modifiers.remove(m_)
    o.parent=None
    if o.data.shape_keys: o.shape_key_clear()
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
def drape(bm,gap,iters,factor=0.5,bvh=None,pin=True,outside=None,free=None):
    """CLOTH, NOT A BALLOON (Director 2026-10-21 on the v4 coat: it "looks somewhat inflated"). Offsetting the muscled body along its normals swells every muscle
    into the cloth. Here the piece is offset once, then smoothed and pushed back OUT of the body to `gap` (metres, or fn(v, face index)) many times, so it
    rests on the crests (chest, shoulder blades, deltoids, the pack) and spans the hollows (sternum, abs, spine, the slope from neck to shoulder) the way a
    real fabric does. Cut rings stay in their planes (pin), so hem / collar / cuffs still find them."""
    bvh=bvh or BODYBVH; g_=gap if callable(gap) else (lambda v,i: gap)
    pins=[]
    if pin:          # BEFORE the first offset: taken after it, the neck ring tilted with its normals and the collar skipped the edges that were no longer level
        for v in set(v for e in bm.edges if e.is_boundary for v in e.verts):
            ax=0 if abs(v.co.x)>wx-0.05 else 2; pins.append((v,ax,v.co[ax]))
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*g_(v,-1)
    for v,ax,val in pins: v.co[ax]=val
    if outside: outside(bm)
    sv=[v for v in bm.verts if free is None or free(v.co)]       # `free`: only these are smoothed (the rest just keep their gap)
    for _ in range(iters):
        bmesh.ops.smooth_vert(bm,verts=sv,factor=factor,use_axis_x=True,use_axis_y=True,use_axis_z=True)
        for v in bm.verts:
            loc,nrm,idx,dist=bvh.find_nearest(v.co)
            if loc is None: continue
            g=g_(v,idx); s=(v.co-loc).dot(nrm)
            if s<g: v.co+=nrm*(g-s)
        if outside: outside(bm)
        for v,ax,val in pins: v.co[ax]=val
    bm.normal_update()
def sstep(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a))); return t*t*(3-2*t)
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
    for (x,z) in pts:
        hit,nrm,idx,dist=bvh.ray_cast(Vector((x,-1.0,z)),Vector((0,1,0)))
        if hit is None: continue
        m=bmesh.ops.create_cone(bm,cap_ends=True,segments=10,radius1=r,radius2=r*0.9,depth=0.008)
        bmesh.ops.rotate(bm,verts=m['verts'],cent=Vector(),matrix=Matrix.Rotation(math.radians(90),3,'X'))    # the cone's axis is Z: face -Y, sit on the cloth
        bmesh.ops.translate(bm,verts=m['verts'],vec=hit+nrm*0.004)
def lining(bm,depth):
    """a second, inward-facing layer: the game draws cull_back, so the inside of an open coat (its front panels, its collar, its hem) was see-through"""
    faces=bm.faces[:]; ret=bmesh.ops.duplicate(bm,geom=faces); nf=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm,faces=nf); bm.normal_update()
    for v in set(v for f in nf for v in f.verts): v.co+=v.normal*depth
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
    else:
        for p_ in o.data.polygons: p_.use_smooth=True
    o.data.materials.clear(); o.data.materials.append(material)
    for g_ in list(o.vertex_groups): o.vertex_groups.remove(g_)
    for n_ in names: o.vertex_groups.new(name=n_)
    m=o.modifiers.new("DT",'DATA_TRANSFER'); m.object=full; m.use_vert_data=True; m.data_types_verts={'VGROUP_WEIGHTS'}
    m.vert_mapping='POLYINTERP_NEAREST'; m.layers_vgroup_select_src='ALL'; m.layers_vgroup_select_dst='NAME'
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier="DT")
    o.parent=arm; am=o.modifiers.new("Armature",'ARMATURE'); am.object=arm
    return o
def new_piece(name):
    me=bpy.data.meshes.new(name); o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o); return o
def shoulder_pad(amp):
    pts=[bw("upperarm_l"),bw("upperarm_r")]
    def f(v):
        d=min((v.co-p).length for p in pts); return amp*math.exp(-(d/0.07)**2)
    return f
def face_out(bm,vs,ref):
    """a face whose normal points along `ref` (single faces are built in any order; the game culls the back side)"""
    f=bm.faces.new(vs); f.normal_update()
    if f.normal.dot(ref)<0: f.normal_flip()
    return f
def on_surface(bvh,x,z,lift,fallback_y=None):
    hit,nrm,idx,dist=bvh.ray_cast(Vector((x,-1.0,z)),Vector((0,1,0)))
    if hit is None: return Vector((x,fallback_y if fallback_y is not None else front-0.02,z)),Vector((0,-1,0))
    if nrm.y>0: nrm=-nrm
    return hit+nrm*lift,nrm
TORSO=("spine_","pelvis","neck_","Head")+ARMS      # the neck group too (left out, its triangles became HOLES at the shoulders), and Head: at the nape it
                                                   # reaches below the neck cut, and the notch it left became two slits through the coat's collar
pieces=[]
BVH={}
def last_shoe(name,side):
    """a PARAMETRIC last (v5): an oval sole ending in a rounded point, a welt, a toe spring, an instep rising to the ankle (the trouser's break covers it).
    The convex hull of the foot (v3/v4) read as crumpled leather; smoothed, it read as a slipper"""
    src=bmesh.new(); src.from_mesh(full.data); dg=dgroup(src)
    pts=[v.co.copy() for v in src.verts if (dg(v) or "").startswith(("foot_","ball_")) and v.co.z<0.125 and side*v.co.x>0]; src.free()
    cx=sum(p.x for p in pts)/len(pts); yh=max(p.y for p in pts)+0.010; yt=min(p.y for p in pts)-0.028; L=yh-yt
    bm=bmesh.new(); N=18; M=11; rings=[]
    for i in range(N+1):
        u=i/N; y=yh-L*u
        w=(0.032+0.017*math.sin(min(1.0,u/0.70)*math.pi*0.5)) if u<0.70 else 0.039*(1.0-((u-0.70)/0.30)**1.7)+0.010   # heel, ball, a rounded point
        h=0.094 if u<0.28 else 0.094-(0.094-0.036)*((u-0.28)/0.72)**0.85                                               # ankle to toe
        lift=0.009*max(0.0,(u-0.78)/0.22)**2                                                                         # toe spring
        r=[Vector((cx-w*1.06,y,lift)),Vector((cx-w*1.06,y,0.013+lift))]
        for k in range(M):
            ph=math.pi*(1.0-k/(M-1)); r.append(Vector((cx+w*math.cos(ph),y,0.013+lift+(h-0.013)*math.sin(ph)**0.55)))
        r+=[Vector((cx+w*1.06,y,0.013+lift)),Vector((cx+w*1.06,y,lift))]
        rings.append([bm.verts.new(p) for p in r])
    K=len(rings[0])
    for i in range(N):
        cen=sum((v.co for v in rings[i]),Vector())/K
        for k in range(K):
            k2=(k+1)%K; face_out(bm,[rings[i][k],rings[i][k2],rings[i+1][k2],rings[i+1][k]],(rings[i][k].co+rings[i][k2].co)/2-cen)
    for ring,d in ((rings[0],Vector((0,1,0))),(rings[-1],Vector((0,-1,0)))): face_out(bm,ring,d)
    return new_piece(name),bm
# ---- the pack first: the coat drapes OVER it (D70: under the coat it is only a bump) ----
# the pockets sit on the pack's BACK face (v4 hung them on its sides, 4 cm past the torso: they came through the coat whenever the arms moved)
PACK=[("Pack_Main",(0.25,0.065,0.29),(0,back+0.034,zc-0.02)),("Pack_PouchL",(0.080,0.026,0.10),(0.066,back+0.0785,zc-0.06)),("Pack_PouchR",(0.080,0.026,0.10),(-0.066,back+0.0785,zc-0.06))]
def bevelbox(size,c):
    def f(bm):
        bmesh.ops.create_cube(bm,size=1.0)
        for v in bm.verts: v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))+Vector(c)
        bmesh.ops.bevel(bm,geom=bm.edges[:],offset=0.010,segments=2,affect='EDGES')
    return f
_pv=list(BODY_V); _pf=list(BODY_F)
for _n,_s,_c in PACK:
    _b=bmesh.new(); bevelbox(_s,_c)(_b); _o=len(_pv); _pv+=[v.co.copy() for v in _b.verts]; _b.verts.index_update(); _pf+=[[_o+v.index for v in f.verts] for f in _b.faces]; _b.free()
NBODYF=len(BODY_F); BODYPACKBVH=BVHTree.FromPolygons(_pv,_pf)
# ---- shirt: draped close (no abs through it), only the torso: the jacket hides the rest ----
o,bm=blank("Outfit_Shirt"); keep_groups(bm,region("spine_","pelvis","clavicle_","neck_","Head")); plane(bm,(0,0,1.02),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
drape(bm,0.006,10)
NECK=[v.co.copy() for e in bm.edges if e.is_boundary for v in e.verts if abs(v.co.z-(zn+0.015))<0.004 and abs(v.co.x)<0.12]
BVH["shirt"]=BVHTree.FromBMesh(bm)
pieces.append(finish(o,bm,SHIRT,uv=0.10))
# ---- jacket: pinstriped wool, draped, a structured shoulder ----
o,bm=blank("Outfit_Jacket"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
plane(bm,(wx-0.012,0,0),(1,0,0),outer=True); plane(bm,(-(wx-0.012),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.007)
drape(bm,lambda v,i: 0.015+sh(v),24)
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0045)
vopen(bm,zc-0.17,zn+0.02,0.060); smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.13 and c.z>zc-0.25)
lapels(bm,zc-0.17,0.056,0.007)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.40,0.175,1.06,3)
collar(bm,0.032,1.12,2); cuffs(bm,wx-0.012,0.018,1.05)
noisy(bm,0.0020); buttons(bm,[(0.0,zc-0.20),(0.0,zc-0.30)],0.011); BVH["jacket"]=BVHTree.FromBMesh(bm)
JAC=(o,bm)
# ---- trousers: pinstriped, draped (no knee or calf muscle), falling over the shoes ----
o,bm=blank("Outfit_Trousers"); keep_groups(bm,region("pelvis","thigh_","calf_"))
plane(bm,(0,0,1.0),(0,0,1),outer=True); plane(bm,(0,0,0.105),(0,0,1),inner=True)      # above the instep: cut through the foot, the hem came out ragged
def loose(v,i): t=max(0.0,min(1.0,(1.0-v.co.z)/0.90)); return 0.012+0.016*t
drape(bm,loose,12); folds(bm,[("calf_l",None),("calf_r",None)],0.0045,0.09,70.0)
hem(bm,lambda c: c.z<0.12,0.062,1.12,2); noisy(bm,0.0015)                            # the break: the hem falls over the shoe
pieces.append(finish(o,bm,SUIT,uv=0.22))
# ---- shoes: a real last, a pointed toe, a flat sole (no spats) ----
for nm,sd in (("Outfit_ShoeL",1),("Outfit_ShoeR",-1)):
    o,bm=last_shoe(nm,sd); pieces.append(finish(o,bm,SHOE))
# ---- gloves ----
o,bm=blank("Outfit_Gloves"); keep_groups(bm,region("hand_","index_","middle_","pinky_","ring_","thumb_"))
plane(bm,(wx-0.015,0,0),(1,0,0)); plane(bm,(-(wx-0.015),0,0),(-1,0,0))       # split only: the two cuts would erase each other's hand
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)<wx-0.0149],context='FACES'); sweep(bm)
displace(bm,0.0045); cuffs(bm,wx-0.015,-0.035,1.12)
pieces.append(finish(o,bm,GLOVE))
# ---- the overcoat: DRAPED (never inflated) over the suit and the pack, hanging half open like Dick Tracy's, lined so its inside is never see-through ----
o,bm=blank("Outfit_Coat"); keep_groups(bm,region(*TORSO))
plane(bm,(0,0,1.03),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
plane(bm,(wx+0.02,0,0),(1,0,0),outer=True); plane(bm,(-(wx+0.02),0,0),(-1,0,0),outer=True)
sh=shoulder_pad(0.008)
def over_pack(bm_):
    """the cloth starts INSIDE the pack (the body is closer than its depth) and the pack's inner face pushed it back toward the body: lift anything
    within a box's outline (plus a rounded margin) out behind it first"""
    for v in bm_.verts:
        for _n,(sx,sy,sz),(cx_,cy_,cz_) in PACK:
            dx=max(0.0,abs(v.co.x-cx_)-sx/2); dz=max(0.0,abs(v.co.z-cz_)-sz/2)
            m=0.06
            if v.co.y>cy_-sy/2-0.03 and dx<m and dz<m:
                yb=cy_+sy/2+0.013-0.02*(max(dx,dz)/m)**2                  # 13 mm behind the pack, easing back toward the body past its edges
                if v.co.y<yb: v.co.y=yb
def coat_gap(v,i):
    if i>=NBODYF: return 0.012
    arm_=sstep(0.20,0.30,abs(v.co.x))                              # the sleeves sit closer than the body of the coat
    return 0.030-0.006*arm_+sh(v)
drape(bm,coat_gap,40,bvh=BODYPACKBVH,outside=over_pack)      # the body face indices come first; past them, the pack's
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0040)
def coat_w(z): return 0.045 if z>=zn+0.03 else 0.045+0.085*min(1.0,(zn+0.03-z)/(zn+0.03-1.03))
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().y<0.0 and abs(f.calc_center_median().x)<coat_w(f.calc_center_median().z)],context='FACES'); sweep(bm)
smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.18 and c.z>zc-0.60,iters=5)
lapels(bm,zc-0.25,0.074,0.012)
hem(bm,lambda c: 0.98<c.z<1.07 and abs(c.x)<0.50,0.58,1.10,5)
collar(bm,0.064,1.20,3); cuffs(bm,wx+0.02,0.02,1.04)
noisy(bm,0.0030); buttons(bm,[(coat_w(z)+0.030,z) for z in (zc-0.02,zc-0.12,zc-0.22)],0.013)
COATBVH=BVHTree.FromBMesh(bm); BVH["coat"]=COATBVH
lining(bm,0.0025)
pushed=0
for v in JAC[1].verts:      # wherever the jacket would show THROUGH the coat (shoulders, arms, back), sink it under; the open front and the collar stay
    c=v.co
    if (c.y<0.0 and abs(c.x)<0.17 and c.z>zc-0.5) or c.z>zn-0.04: continue
    loc,nrm,idx,dist=COATBVH.find_nearest(c)
    if loc is None: continue
    out=(c-loc).dot(nrm)
    if out>-0.012:
        v.co-=v.normal*(max(out,0.0)+0.016); pushed+=1
print("T5 jacket verts pushed under the coat",pushed)
pieces.append(finish(*JAC,SUIT,uv=0.22))
pieces.append(finish(o,bm,WHITE,uv=0.22))
def pack_weight(p):
    r=min(max(max(0.0,abs(p.x-c_[0])-s_[0]/2),max(0.0,abs(p.z-c_[2])-s_[2]/2)) for n_,s_,c_ in PACK)
    return sstep(0.045,0.0,r)*sstep(back-0.01,back+0.02,p.y)
def lean_on(o,group,wfn):
    """re-weight toward one bone: the coat's hump must move WITH the pack (spine_03), not with the shoulder blades under it (the pack's corners
    came through the coat as soon as the rig left its rest pose)"""
    vg=o.vertex_groups[group]; n=0
    for v in o.data.vertices:
        w=wfn(v.co)
        if w<=0.0: continue
        for g in v.groups: g.weight*=(1.0-w)
        vg.add([v.index],w,'ADD'); n+=1
    return n
print("T5 coat verts leaning on the pack",lean_on(pieces[-1],"spine_03",pack_weight))
# ---- the shirt's contrast trim: a turned-down collar, two cuffs, a pocket square (ONE piece, one surface) ----
def shirt_collar(bm):
    """a band standing on the shirt's neckline and a leaf folded over it, lower at the front, spreading into two points that frame the knot; both have a
    thickness (cull_back). The ellipse comes from the shirt's own neck ring."""
    cx=sum(p.x for p in NECK)/len(NECK); cy=(max(p.y for p in NECK)+min(p.y for p in NECK))/2; z0=sum(p.z for p in NECK)/len(NECK)
    rx=max(abs(p.x-cx) for p in NECK)+0.003; ry=(max(p.y for p in NECK)-min(p.y for p in NECK))/2+0.003
    def E(th,dr,z,sc=1.0): return Vector((cx+math.sin(th)*(rx*sc+dr),cy+math.cos(th)*(ry*sc+dr),z))      # th=0 at the back, +-pi at the front (-y)
    def hb(th): f=abs(th)/math.pi; return 0.034-0.010*f*f                                                  # the band: 3.4 cm at the back, 2.4 at the front
    N=40; T=0.0025
    ths=[-math.pi+2*math.pi*j/N for j in range(N)]
    rows=[[E(t,0,z0-0.008) for t in ths],[E(t,0,z0+hb(t),0.965) for t in ths]]
    outer=[[bm.verts.new(p) for p in r] for r in rows]; inner=[[bm.verts.new(p+(p-Vector((cx,cy,p.z))).normalized()*-T) for p in r] for r in rows]
    for j in range(N):
        k=(j+1)%N; rad=Vector((math.sin(ths[j]),math.cos(ths[j]),0))
        face_out(bm,[outer[0][j],outer[0][k],outer[1][k],outer[1][j]],rad); face_out(bm,[inner[0][j],inner[0][k],inner[1][k],inner[1][j]],-rad)
        face_out(bm,[outer[1][j],outer[1][k],inner[1][k],inner[1][j]],Vector((0,0,1)))
    GAP=0.30; M=34; S=BVH["shirt"]       # the gap between the leaves' front edges, where the knot shows
    def P(th): a=abs(th); return max(0.0,min(1.0,(a-0.55*math.pi)/(math.pi-GAP-0.55*math.pi)))**1.5     # how much of a "point" this column is
    grid=[]
    for j in range(M+1):
        th=-(math.pi-GAP)+2*(math.pi-GAP)*j/M; p=P(th); L=hb(th)+0.004+0.036*p; col=[]
        for t in (0.0,0.5,1.0):
            tb=th-math.copysign(0.42*p*t,th); z=z0+hb(th)+0.003-L*t
            q=E(tb,0.003+(0.006+0.026*p)*t,z,0.965+0.035*t)
            loc,nrm,i_,d_=S.find_nearest(q)
            if loc is not None and (q-loc).dot(nrm)<0.004: q=loc+nrm*0.004            # the points lie ON the shirt, never inside it
            col.append(q)
        grid.append(col)
    O=[[bm.verts.new(q) for q in col] for col in grid]
    I=[[bm.verts.new(q+(Vector((cx,cy,q.z))-q).normalized()*T) for q in col] for col in grid]
    for j in range(M):
        th=-(math.pi-GAP)+2*(math.pi-GAP)*(j+0.5)/M; rad=Vector((math.sin(th),math.cos(th),0.4)).normalized()
        for r in range(2):
            face_out(bm,[O[j][r],O[j+1][r],O[j+1][r+1],O[j][r+1]],rad); face_out(bm,[I[j][r],I[j+1][r],I[j+1][r+1],I[j][r+1]],-rad)
        face_out(bm,[O[j][2],O[j+1][2],I[j+1][2],I[j][2]],Vector((0,0,-1)))
    for j,s in ((0,-1),(M,1)):    # the two front edges of the leaf face the knot
        for r in range(2): face_out(bm,[O[j][r],O[j][r+1],I[j][r+1],I[j][r]],Vector((-s,0,0)))
    return Vector((cx,cy-ry,z0+hb(math.pi)))     # the front of the band's top: where the knot sits
def shirt_cuffs(bm):
    src=bmesh.new(); src.from_mesh(full.data)
    for s in (1,-1):
        a=bw("lowerarm_l" if s>0 else "lowerarm_r"); b=bw("hand_l" if s>0 else "hand_r"); ax=(b-a).normalized()
        rr=[((v.co-a)-ax*(v.co-a).dot(ax)).length for v in src.verts if abs(v.co.x-s*(wx-0.012))<0.012 and (v.co-a).dot(ax)>0]
        R=(max(rr) if rr else 0.04)+0.006; ring=[]
        for x0 in (wx-0.024,wx+0.014):
            c=a+ax*((s*x0-a.x)/ax.x); u=ax.cross(Vector((0,0,1))).normalized(); w=ax.cross(u).normalized()
            ring.append([c+(u*math.cos(2*math.pi*k/14)+w*math.sin(2*math.pi*k/14))*R*(1.0 if x0<wx else 1.03) for k in range(14)])
        O=[[bm.verts.new(p) for p in r] for r in ring]; I=[[bm.verts.new(c_+(p-c_)*(1-0.004/R)) for p in r] for r,c_ in zip(ring,[a+ax*((s*x0-a.x)/ax.x) for x0 in (wx-0.024,wx+0.014)])]
        for k in range(14):
            k2=(k+1)%14; cc=a+ax*((s*wx-a.x)/ax.x); rad=(ring[0][k]+ring[1][k])/2-cc
            face_out(bm,[O[0][k],O[0][k2],O[1][k2],O[1][k]],rad); face_out(bm,[I[0][k],I[0][k2],I[1][k2],I[1][k]],-rad)
            face_out(bm,[O[1][k],O[1][k2],I[1][k2],I[1][k]],ax*s)
    src.free()
def pocket_square(bm):
    """two white points peeking out of the left breast pocket (the wearer's left is +x; seen in the black style, the coat covers it)"""
    J=BVH["jacket"]; zp=zc+0.075; pts=[(0.097,zp-0.006),(0.104,zp+0.013),(0.114,zp+0.004),(0.124,zp+0.017),(0.134,zp-0.006)]
    V=[bm.verts.new(on_surface(J,x,z,0.0035)[0]) for x,z in pts]
    face_out(bm,[V[0],V[2],V[1]],Vector((0,-1,0))); face_out(bm,[V[2],V[4],V[3]],Vector((0,-1,0))); face_out(bm,[V[0],V[4],V[2]],Vector((0,-1,0)))
TRIMBM=bmesh.new(); KNOT=shirt_collar(TRIMBM); shirt_cuffs(TRIMBM); pocket_square(TRIMBM)
pieces.append(finish(new_piece("Outfit_ShirtTrim"),TRIMBM,TRIM))
for v in pieces[-1].data.vertices:   # a cuff follows the FOREARM: weighted to the hand it swung out through the sleeve whenever the wrist bent
    if abs(v.co.x)>wx-0.04:
        for g in v.groups: g.weight=0.0
        pieces[-1].vertex_groups["lowerarm_l" if v.co.x>0 else "lowerarm_r"].add([v.index],1.0,'REPLACE')
# ---- the tie: a knot in the collar's gap, a blade with a thickness, diagonal stripes, a pointed tip at the belt and a tie bar ----
def tie(bm):
    """the tie's own UVs are isotropic (1 unit = 0.5 m both ways) so the stripes stay at 45 degrees; the bar's UVs point into the texture's gold patch"""
    uvl=bm.loops.layers.uv.verify(); S=BVH["shirt"]; Su=0.5
    zk=KNOT.z+0.001; zkb=zk-0.040; za=zkb+0.006; ztip=1.045; tl=0.034; ze=ztip+tl; R=16
    def uv_of(p,u0=0.30,v0=0.04,z0=za): return (u0+p.x/Su,v0+(z0-p.z)/Su)
    def put(f,uvf):
        for l in f.loops: l[uvl].uv=uvf(l.vert.co)
    # the knot: a frustum of two flattened ellipses, its back sunk into the band, a cap on top
    kc=Vector((0,KNOT.y-0.009,0)); loops=[]             # IN FRONT of the leaves' inner edges, as on a real collar
    for z,a,d in ((zk,0.022,0.011),(zk-0.020,0.018,0.011),(zkb,0.010,0.006)):
        y0,_=on_surface(S,0.0,z,0.0,KNOT.y); yy=min(kc.y,y0.y)
        loops.append([bm.verts.new(Vector((a*math.sin(2*math.pi*k/12),yy-d*(1+math.cos(2*math.pi*k/12))*0.9,z))) for k in range(12)])
    for r in range(2):
        for k in range(12):
            k2=(k+1)%12; a_=2*math.pi*(k+0.5)/12
            f=face_out(bm,[loops[r][k],loops[r][k2],loops[r+1][k2],loops[r+1][k]],Vector((math.sin(a_),-math.cos(a_),0)))
            put(f,lambda p: uv_of(p,0.62,0.30,zk))
    f=face_out(bm,loops[0],Vector((0,0,1))); put(f,lambda p: uv_of(p,0.62,0.30,zk))
    # the blade: front and back layers conformed to the shirt, side walls, a V tip
    cols=(-1.0,-0.5,0.0,0.5,1.0)
    def hw(t): return 0.017+0.023*math.sin(min(1.0,t*1.05)*math.pi*0.5)
    F=[];B=[]
    for i in range(R+2):
        t=min(1.0,i/R); rowF=[];rowB=[]
        for u in cols:
            z=(za-(za-ze)*t) if i<=R else ze-tl*(1.0-abs(u))
            x=u*hw(t); p,n=on_surface(S,x,z,0.0)
            rowF.append(bm.verts.new(p+n*(0.0055+0.0018*(1-u*u)))); rowB.append(bm.verts.new(p+n*0.0016))
        F.append(rowF); B.append(rowB)
    for i in range(R+1):
        for c in range(4):
            f=face_out(bm,[F[i][c],F[i][c+1],F[i+1][c+1],F[i+1][c]],Vector((0,-1,0))); put(f,uv_of)
            f=face_out(bm,[B[i][c],B[i][c+1],B[i+1][c+1],B[i+1][c]],Vector((0,1,0))); put(f,uv_of)
        for c,sd in ((0,-1),(4,1)):
            f=face_out(bm,[F[i][c],F[i+1][c],B[i+1][c],B[i][c]],Vector((sd,0,0))); put(f,uv_of)
    # the tie bar, two-thirds of the way across, at mid chest
    zb=zc+0.035; t=(za-zb)/(za-ze); w=hw(t)*0.78; p,n=on_surface(S,0.0,zb,0.0070); bar=[]
    for dx in (-w,w):
        for dz in (-0.003,0.003):
            for dy in (0.0,-0.003): bar.append(bm.verts.new(Vector((dx,p.y+dy-0.0005,zb+dz))))
    for q,ref in (((0,2,6,4),(0,1,0)),((1,3,7,5),(0,-1,0)),((0,1,5,4),(0,0,-1)),((2,3,7,6),(0,0,1)),((0,1,3,2),(-1,0,0)),((4,5,7,6),(1,0,0))):
        f=face_out(bm,[bar[k] for k in q],Vector(ref)); put(f,lambda p: (0.04,0.97))
TIEBM=bmesh.new(); tie(TIEBM)
pieces.append(finish(new_piece("Outfit_Tie"),TIEBM,TIEW))
# ---- hat, coat front flaps, the pack ----
def prim(name,build,group,material,smooth=False):
    bm=bmesh.new(); build(bm)
    for f in bm.faces: f.smooth=smooth
    me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    vg=o.vertex_groups.new(name=group); vg.add(list(range(len(me.vertices))),1.0,'REPLACE'); me.materials.append(material)
    o.parent=arm; m=o.modifiers.new("Armature",'ARMATURE'); m.object=arm; return o
# THE FEDORA, rebuilt (v5): OVAL like the head under it (the v4 round crown let the forehead poke through its front: the pale patch on the band), a tapered
# crown with the teardrop crease and two front pinches (what reads as a fedora from the game's camera, 30 degrees above), a rounded top edge, a snap brim
hx,hy=0.0,-0.003; HZ0,HH,HRX,HRY=1.728,0.110,0.095,0.105     # centre, crown base, crown height, base radii (the head is 15.6 x 17.4 cm at 1.73 m)
def crown_pt(th,t,grow=1.0):
    tap=1.0-0.20*t; pin=1.0-0.17*max(0.0,(t-0.30)/0.70)*(math.exp(-((th-0.62)/0.30)**2)+math.exp(-((th+0.62)/0.30)**2))
    k=tap*pin*grow; return Vector((hx+math.sin(th)*HRX*k,hy-math.cos(th)*HRY*k,HZ0+HH*t))
def crown(bm):
    N=40; ths=[2*math.pi*i/N for i in range(N)]
    rings=[[crown_pt(th,t) for th in ths] for t in (0.0,0.3,0.6,0.86,0.96)]
    rings.append([Vector((p.x*0.955+hx*0.045,hy+(p.y-hy)*0.955,HZ0+HH)) for p in rings[-1]])
    for rho in (0.8,0.55,0.3):          # the top: a soft dome with the crease running front to back, deepest in the middle
        rings.append([Vector((hx+(p.x-hx)*rho,hy+(p.y-hy)*rho,HZ0+HH+0.004*(1-rho*rho)-0.026*math.exp(-((p.x-hx)*rho/0.022)**2)*(1-rho**4))) for p in rings[5]])
    V=[[bm.verts.new(p) for p in r] for r in rings]; c=bm.verts.new(Vector((hx,hy,HZ0+HH+0.004-0.026)))
    for a in range(len(V)-1):
        for i in range(N): face_out(bm,[V[a][i],V[a][(i+1)%N],V[a+1][(i+1)%N],V[a+1][i]],(V[a][i].co+V[a+1][i].co)/2-Vector((hx,hy,HZ0+0.03)))
    for i in range(N): face_out(bm,[V[-1][i],V[-1][(i+1)%N],c],Vector((0,0,1)))
def brim(bm,front=0.060,side=0.050):
    N=40; th_=0.005
    def ring(th,k):
        p=crown_pt(th,0.0,0.985); d=Vector((math.sin(th),-math.cos(th),0))
        w=side+(front-side)*abs(math.cos(th)); z=HZ0+0.004+(0.014*abs(math.sin(th))-0.024*max(0.0,math.cos(th))+0.012*max(0.0,-math.cos(th)))*k*k
        return Vector((p.x+d.x*w*k,p.y+d.y*w*k,z))
    ths=[2*math.pi*i/N for i in range(N)]
    ti=[bm.verts.new(ring(t,0.0)+Vector((0,0,th_))) for t in ths]; tm=[bm.verts.new(ring(t,0.55)+Vector((0,0,th_))) for t in ths]; to=[bm.verts.new(ring(t,1.0)+Vector((0,0,th_))) for t in ths]
    bi=[bm.verts.new(ring(t,0.0)) for t in ths]; bmid=[bm.verts.new(ring(t,0.55)) for t in ths]; bo=[bm.verts.new(ring(t,1.0)) for t in ths]
    for i in range(N):
        j=(i+1)%N
        for A,B in ((ti,tm),(tm,to)): face_out(bm,[A[i],A[j],B[j],B[i]],Vector((0,0,1)))
        for A,B in ((bi,bmid),(bmid,bo)): face_out(bm,[A[i],A[j],B[j],B[i]],Vector((0,0,-1)))
        face_out(bm,[to[i],to[j],bo[j],bo[i]],Vector((math.sin(ths[i]),-math.cos(ths[i]),0)))
def band(bm):
    N=40; ths=[2*math.pi*i/N for i in range(N)]
    lo=[bm.verts.new(crown_pt(t,0.0,1.022)+Vector((0,0,0.003))) for t in ths]; hi=[bm.verts.new(crown_pt(t,0.21,1.022)) for t in ths]
    for i in range(N): face_out(bm,[lo[i],lo[(i+1)%N],hi[(i+1)%N],hi[i]],Vector((math.sin(ths[i]),-math.cos(ths[i]),0)))
pieces.append(prim("Outfit_HatCrown",crown,"Head",BLACK,True)); pieces.append(prim("Outfit_HatBrim",brim,"Head",BLACK,True)); pieces.append(prim("Outfit_HatBand",band,"Head",BAND,True))
for _n,_s,_c in PACK: pieces.append(prim(_n,bevelbox(_s,_c),"spine_03",OLIVE))
HATUP=["Outfit_HatCrown","Outfit_HatBrim","Outfit_HatBand"]

# ---------- HAIR (CC0, Quaternius Universal Base Characters, "Rigged to Head Bone"; a solid sculpted mesh: no alpha, no discard), dark brown, pressed under
# the fedora; and a SHORT BOXED BEARD grown from the skin itself (Director 2026-10-21: "discreet but reasonably handsome, and maybe [...] a beard"). The pack's
# own Hair_Beard was tried first: a full, ragged beard that hid the tie's knot and read unkempt even trimmed to half; a shell of the face's own faces, cut
# along a smooth outline (the cheek line, the lips left clear), reads groomed and costs a few hundred triangles ----------
HAIRMAT=None
def tinted(img,rgb,name,size=512):
    w,h=img.size; px=np.empty(w*h*4,dtype=np.float32); img.pixels.foreach_get(px); px=px.reshape(h,w,4)[...,:3]
    f=w//size; px=px.reshape(size,f,size,f,3).mean(axis=(1,3)); px=px/max(1e-3,float(px.mean()))*np.array(rgb)
    return image(name,px)
def cc0_piece(fname,new_name):
    global HAIRMAT
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=HAIRD+fname+".gltf"); new=list(set(bpy.data.objects)-before)
    for o_ in new:
        if o_.type=='ARMATURE': o_.data.pose_position='REST'
    me_o=[o_ for o_ in new if o_.type=='MESH' and o_.name.startswith(("Hair","Eyebrows"))][0]
    mw=me_o.matrix_world.copy(); me_o.parent=None
    for m_ in list(me_o.modifiers): me_o.modifiers.remove(m_)
    me_o.data.transform(mw); me_o.matrix_world=Matrix.Identity(4)
    for o_ in new:
        if o_ is not me_o: bpy.data.objects.remove(o_,do_unlink=True)
    if HAIRMAT is None:
        src=[n for n in me_o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and "BaseColor" in n.image.name][0].image
        HAIRMAT=tmat("Hair_DarkBrown",tinted(src,(0.20,0.135,0.095),"Hair_DarkBrown"),0.7)
    me_o.data.materials.clear(); me_o.data.materials.append(HAIRMAT); me_o.name=new_name
    for g_ in list(me_o.vertex_groups): me_o.vertex_groups.remove(g_)
    for p_ in me_o.data.polygons: p_.use_smooth=True
    return me_o
def skin_to_head(o):
    vg=o.vertex_groups.new(name="Head"); vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    o.parent=arm; am=o.modifiers.new("Armature",'ARMATURE'); am.object=arm; return o
HAT_Z0=HZ0
if HAIRD:
    hair=cc0_piece("Hair_SimpleParted","Face_Hair")
    for v in hair.data.vertices:     # the fedora sits ON the hair: what would show through the crown is pressed inside it (the hair stays whole for a hatless look)
        p=v.co
        if p.z>1.75: p.z=1.75+(p.z-1.75)*0.75
        if p.z>HAT_Z0-0.035:         # inside the oval crown, 7 mm clear of its wall (the front pinches included)
            k=max(0.0,min(1.0,(p.z-(HAT_Z0-0.035))/0.035)); t=max(0.0,min(1.0,(p.z-HZ0)/HH))
            th=math.atan2(p.x-hx,-(p.y-hy)); w=crown_pt(th,t)-Vector((hx,hy,0)); R=Vector((w.x,w.y,0)).length-0.007
            d=Vector((p.x-hx,p.y-hy,0)); r=d.length
            if r>R: p.x,p.y=hx+(d.x/r)*(r+(R-r)*k),hy+(d.y/r)*(r+(R-r)*k)
    pieces.append(skin_to_head(hair))
    brows=bpy.data.objects.get("Eyebrows")
    if brows: brows.data.materials.clear(); brows.data.materials.append(HAIRMAT)   # the pack's brows were drawn white-grey

def ramp(d,w=0.012): return max(0.0,min(1.0,0.5+d/w))          # LINEAR across the outline, 0.5 exactly on it: the contour snap needs that
def beard_mask(p):
    """a short BOXED beard: jaw, chin and a moustache joined at the corners; a clean cheek line from the sideburn (at the ear) to the mouth corner; the
    lips clear; ending under the jaw and behind its angle. min() = intersection, max() = union: both keep every outline exact"""
    if p.y>0.07 or p.z<1.52 or p.z>1.72: return 0.0
    ax=abs(p.x); t=max(0.0,min(1.0,(0.080-ax)/(0.080-0.036))); zline=1.676+(1.634-1.676)*(t**0.8)
    cheek=ramp(zline-p.z)
    must=min(ramp(0.036-ax,0.008),ramp(1.6475-p.z,0.006),ramp(p.z-1.629,0.006),ramp(-0.06-p.y,0.02))     # the moustache, up to the nose
    lips=ramp(math.sqrt((p.x/0.0290)**2+((p.z-1.6215)/0.0100)**2)-1.12,0.35)                            # the lips stay clear
    return min(max(cheek,must),lips,ramp(p.z-1.556,0.010),ramp(0.030-p.y,0.016))
def stubble_texture():
    n=256; rng=np.random.default_rng(11); base=np.array((0.21,0.145,0.10)); img=np.zeros((n,n,3))+base
    streak=rng.normal(0,1,(n,n)); streak=(streak+np.roll(streak,1,0)+np.roll(streak,2,0)+np.roll(streak,1,1)*0.5)/3.5   # short vertical hairs
    img*=(1.0+0.22*streak)[...,None]; img*=(1.0+rng.normal(0,0.05,(n,n,1)))
    return image("Fabric_Beard",img)
if os.environ.get("BEARD","1")!="0":
    o,bm=blank("Face_Beard"); keep_groups(bm,region("Head","neck_"))
    mk={v:beard_mask(v.co) for v in bm.verts}
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if max(mk[v] for v in f.verts)<0.02],context='FACES'); sweep(bm)
    bmesh.ops.subdivide_edges(bm,edges=bm.edges[:],cuts=1,use_grid_fill=True)                     # the face is coarse: halve it for a smooth outline
    mk={v:beard_mask(v.co) for v in bm.verts}
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if max(mk[v] for v in f.verts)<0.5],context='FACES'); sweep(bm)
    snap={}
    for v in bm.verts:              # every vertex left outside the outline slides along its edges onto the 0.5 contour: a smooth edge, not a staircase
        if mk[v]>=0.5: continue
        pts=[v.co+(e.other_vert(v).co-v.co)*((0.5-mk[v])/max(1e-6,mk[e.other_vert(v)]-mk[v])) for e in v.link_edges if mk[e.other_vert(v)]>=0.5]
        if pts: snap[v]=sum(pts,Vector())/len(pts)
    for v,q in snap.items(): v.co=q; mk[v]=0.5
    bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=0.0008); mk={v:max(0.5,beard_mask(v.co)) for v in bm.verts}
    bm.normal_update()
    for v in bm.verts: v.co+=v.normal*(0.0010+0.0020*sstep(0.5,0.9,mk[v])+0.0004*noise.noise(v.co*260.0))
    BEARD=tmat("Beard_Hair",stubble_texture(),0.85)
    pieces.append(finish(o,bm,BEARD,uv=0.05))

# ================= THE MASK (D71, rebuilt as D77, Director 2026-10-21: "the mask is the top of the hat, which comes down in front and lights the eyes [...]
# in stealth mode he no longer has the hat"). The crown slides forward and down over the face: a felt shell with the fedora's crease and front pinches on top;
# the hat's BAND lands across the eyes and carries the amber lenses; the brim rolls into the band; the jaw plates rise from the collar (D71). =================
MASKBLACK=mat("Mask_Black",(0.028,0.029,0.034),0.55)
EYEGLOW=mat("Mask_EyeGlow",(1.0,0.62,0.12),0.4); _b=EYEGLOW.node_tree.nodes["Principled BSDF"]
for k_,v_ in (("Emission Color",(1.0,0.55,0.08,1.0)),("Emission Strength",6.0)):
    if k_ in _b.inputs: _b.inputs[k_].default_value=v_
HALO=mat("Mask_EyeHalo",(1.0,0.55,0.10),0.4)
EYE_Z=1.698
o,bm=blank("Mask_Shell"); keep_groups(bm,region("Head","neck_","spine_","clavicle_"))
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)>0.085 and f.calc_center_median().z<1.60],context='FACES'); sweep(bm)   # the neck, not the shoulders
def shell_floor(y): return 1.625+(1.532-1.625)*sstep(-0.05,0.035,y)              # under the nose at the front, deep into the jacket's collar at the nape (no skin)
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().z<shell_floor(f.calc_center_median().y)],context='FACES'); sweep(bm)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=40)  # the eye openings (and the lips): a shell has no holes
def shell_gap(v,i):
    if v.co.y>0.0 and v.co.z<1.66: return 0.020-0.012*sstep(1.66,1.60,v.co.z)    # the nape: hugged (bridged to the back it read as a HOOD, which D70 rules out)
    return 0.020 if (v.co.z>1.70 or v.co.y>-0.02) else 0.016                     # the felt has volume: a crown, not a balaclava
drape(bm,shell_gap,30,free=lambda c: c.z>1.645 or c.y<-0.02)
front_=set()
for v in bm.verts:   # the face side is one smooth visor (the crown pulled down has no nose in it)
    p=v.co; w=sstep(0.080,0.055,abs(p.x))*sstep(1.606,1.622,p.z)*sstep(1.752,1.730,p.z)*sstep(-0.02,-0.05,p.y)
    yv=-0.129+9.0*p.x*p.x+5.5*(p.z-1.668)**2
    if w>0.0 and yv<p.y: p.y+=(yv-p.y)*w; front_.add(v)
for _ in range(3): bmesh.ops.smooth_vert(bm,verts=list(front_),factor=0.5,use_axis_x=True,use_axis_y=True,use_axis_z=True)
for v in bm.verts:
    p=v.co; topk=sstep(1.765,1.800,p.z); along=sstep(0.105,0.07,abs(p.y-0.0))
    if p.z>1.78: p.z=1.78+(p.z-1.78)*0.75                                      # a flatter top with a rounded edge: the crown's, not the skull's
    p.z+=0.026*topk                                                             # (raised enough that the crease never reaches the skull: 0.55 and +16 mm let the scalp through)
    p.z-=0.017*topk*along*math.exp(-(p.x/0.020)**2)                             # the crown's centre crease, front to back (the fedora's, D77)
    s=1.0 if p.x>=0 else -1.0
    p.x-=s*0.013*math.exp(-(((p.x-s*0.038)/0.017)**2+((p.y+0.060)/0.026)**2+((p.z-1.79)/0.024)**2))     # the two front pinches
SHELLBVH=BVHTree.FromBMesh(bm)
pieces.append(finish(o,bm,BLACK))
def mask_band(bm):   # the hat's band, slid down with the crown: across the eyes, carrying the lenses
    N=48; rows=[]
    for z in (EYE_Z-0.0120,EYE_Z+0.0110):
        ring=[]
        for j in range(N):
            a=2*math.pi*j/N; d=Vector((math.sin(a),-math.cos(a),0)); hit,nrm,i_,d_=SHELLBVH.ray_cast(Vector((0,0.012,z)),d)
            if hit is None: hit,nrm=Vector((0,0.012,z))+d*0.1,d
            if nrm.dot(d)<0: nrm=-nrm
            ring.append((hit,nrm,d))
        rows.append(ring)
    Bi=[bm.verts.new(h+n*0.0004) for h,n,d in rows[0]]; Bo=[bm.verts.new(h+n*0.0030) for h,n,d in rows[0]]
    To=[bm.verts.new(h+n*0.0030) for h,n,d in rows[1]]; Ti=[bm.verts.new(h+n*0.0004) for h,n,d in rows[1]]
    for j in range(N):
        k=(j+1)%N; d=rows[0][j][2]
        face_out(bm,[Bi[j],Bi[k],Bo[k],Bo[j]],Vector((0,0,-1))); face_out(bm,[Bo[j],Bo[k],To[k],To[j]],d); face_out(bm,[To[j],To[k],Ti[k],Ti[j]],Vector((0,0,1)))
BANDBM=bmesh.new(); mask_band(BANDBM); BANDBVH=BVHTree.FromBMesh(BANDBM); pieces.append(finish(new_piece("Mask_Band"),BANDBM,BAND))
o,bm=blank("Mask_Jaw"); keep_groups(bm,region("Head","neck_"))
plane(bm,(0,0,1.636),(0,0,1),outer=True); plane(bm,(0,0,1.511),(0,0,1),inner=True); plane(bm,(0,0.045,0),(0,1,0),outer=True)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=40)
drape(bm,0.024,20); pieces.append(finish(o,bm,MASKBLACK))                      # smooth plates (the v4 facets read as crumpled paper)
def eye_lenses(bm):       # slanted amber slits IN the band, narrowest at the nose; 8 segments, each on the band (one flat quad sank into its curve)
    for s_ in (1,-1):
        lo=[];hi=[]
        for k in range(9):
            t=k/8.0; x=0.011+0.046*t; zc_=1.6950+0.0072*t; hh=0.0028+0.0012*math.sin(t*math.pi)
            lo.append(bm.verts.new(on_surface(BANDBVH,s_*x,zc_-hh,0.0010)[0])); hi.append(bm.verts.new(on_surface(BANDBVH,s_*x,zc_+hh,0.0010)[0]))
        for k in range(8): face_out(bm,[lo[k],lo[k+1],hi[k+1],hi[k]],Vector((0,-1,0)))
def eye_halos(bm):        # a soft additive glow around each lens (the engine draws it; UVs run 0..1)
    uvl=bm.loops.layers.uv.verify()
    for s_ in (1,-1):
        c=(s_*0.034,1.6985); hw_,hh=0.060,0.030
        P=[on_surface(SHELLBVH,x,z,0.011)[0] for x,z in ((c[0]-hw_,c[1]-hh),(c[0]+hw_,c[1]-hh),(c[0]+hw_,c[1]+hh),(c[0]-hw_,c[1]+hh))]
        f=face_out(bm,[bm.verts.new(p) for p in P],Vector((0,-1,0)))
        for l_ in f.loops: l_[uvl].uv=(0.5+(l_.vert.co.x-c[0])/(2*hw_),0.5+(l_.vert.co.z-c[1])/(2*hh))
pieces.append(prim("Mask_Eyes",eye_lenses,"Head",EYEGLOW)); pieces.append(prim("Mask_Halo",eye_halos,"Head",HALO))
MASKSET=["Mask_Shell","Mask_Band","Mask_Jaw","Mask_Eyes","Mask_Halo"]; FACEHAIR=["Face_Hair","Face_Beard"]
# ---- mask the body under the clothes (not the hands: the gloves are a style that comes and goes) ----
bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); dgb=dgroup(bm)
cover=region("spine_","clavicle_","upperarm_","lowerarm_","pelvis","thigh_","calf_","foot_","ball_")
cov=set(v.index for v in bm.verts if cover(dgb(v)))
gone=[f for f in bm.faces if all(v.index in cov for v in f.verts)]
bmesh.ops.delete(bm,geom=gone,context='FACES'); sweep(bm); bm.to_mesh(body.data); bm.free(); print("T5 body faces masked",len(gone))

# ---------- FACE: blend shapes for basic expressions (the free body has no face rig at all) ----------
def gauss(p,c,sx,sy=None,sz=None):
    sy=sy or sx; sz=sz or sx
    return math.exp(-(((p.x-c[0])/sx)**2+((p.y-c[1])/sy)**2+((p.z-c[2])/sz)**2)*0.5)
BROW_Z=1.725; MOUTH_Z=1.624; CORNER=(0.026,-0.098,1.622)
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
            th=math.radians(17.0)*w; hy_,hz=0.005,1.668
            ry,rz=p.y-hy_,p.z-hz
            d=Vector((0,ry*math.cos(th)-rz*math.sin(th)-ry,ry*math.sin(th)+rz*math.cos(th)-rz))
    return d
FACE_KEYS=("smile","frown","brow_up","brow_down","blink","eyes_wide","jaw_open")
def add_face_keys(obj):
    if obj.data.shape_keys is None: obj.shape_key_add(name="Basis",from_mix=False)
    for kn in FACE_KEYS:
        sk=obj.shape_key_add(name=kn,from_mix=False)
        for i,v in enumerate(obj.data.vertices): sk.data[i].co=v.co+face_delta(kn,v.co)
        sk.value=0.0      # Blender 5.2 creates a key at 1.0: v4 EXPORTED every expression switched on at once (smile + frown + blink + jaw_open...)
FACEOBJS=[o_ for o_ in (body,bpy.data.objects.get("Eyebrows"),bpy.data.objects.get("Eyes"),bpy.data.objects.get("Face_Beard")) if o_ is not None]
if DEC>=1.0:       # a decimated LOD cannot carry shape keys, and the game LOD never needs a face (the mask covers it)
    for o_ in FACEOBJS: add_face_keys(o_)
bpy.data.objects.remove(full,do_unlink=True)
# per-piece LOD weights (x DECIMATE): at play zoom the face is ~10 px under a brim, so the beard, the hair and the head go further; the coat is lined (two
# layers), so it can lose more. DECIMATE=0.2 gives ~5.4k visible triangles in the normal style, ~4.9k black, ~5.2k masked (D73's ~5k)
LOD_WEIGHT={"Face_Beard":0.4,"Face_Hair":0.75,"Outfit_Coat":0.8,"SuperHero_Male":0.8}
if DEC<1.0:
    for o in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.polygons)>150]:
        bpy.context.view_layer.objects.active=o; m=o.modifiers.new("Decimate",'DECIMATE'); m.ratio=DEC*LOD_WEIGHT.get(o.name,1.0); bpy.ops.object.modifier_apply(modifier="Decimate")
arm.data.pose_position='POSE'
tot=0
for o in bpy.context.scene.objects:
    if o.type=='MESH': n=sum(len(p.vertices)-2 for p in o.data.polygons); tot+=n; print("T5 piece",o.name,n)
print("T5 TOTAL tris",tot,"meshes",sum(1 for o in bpy.context.scene.objects if o.type=='MESH'))
TRIS={o.name:sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'}
for st_,hid in (("normal",["Outfit_Gloves"]+MASKSET),("black",["Outfit_Coat"]+MASKSET),("mask",["Outfit_Coat"]+HATUP+FACEHAIR)):
    print("T5 visible tris",st_,sum(n for k,n in TRIS.items() if k not in hid),"(shaved",sum(n for k,n in TRIS.items() if k not in hid+["Face_Beard"]),")")
bpy.ops.export_scene.gltf(filepath=D+f"hero{SUF}.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)

# ---------- previews (EEVEE: textures show; the game's own look is the board shader's) ----------
if PREVIEW!="none":
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.render.resolution_x=420; sc.render.resolution_y=640
    w_=bpy.data.worlds.new("w"); sc.world=w_; w_.use_nodes=True; w_.node_tree.nodes["Background"].inputs[0].default_value=(0.30,0.31,0.34,1)
    for nm_,en,rot in (("key",3.2,(50,0,-35)),("fill",1.0,(60,0,140))):
        L=bpy.data.lights.new(nm_,'SUN'); L.energy=en; lo=bpy.data.objects.new(nm_,L); sc.collection.objects.link(lo); lo.rotation_euler=[math.radians(a) for a in rot]
    cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
    def shot(an,fr,az_deg,path,ctr=Vector((0,0,0.9)),ortho=2.3,el_deg=18):
        if an is None: ad.action=None; arm.data.pose_position='REST'
        else:
            arm.data.pose_position='POSE'; a=bpy.data.actions[an]; ad.action=a; ad.action_slot=a.slots[0]; sc.frame_set(fr)
        az=math.radians(az_deg); el=math.radians(el_deg); d=10; cam.ortho_scale=ortho
        co.location=ctr+Vector((d*math.cos(el)*math.sin(az),-d*math.cos(el)*math.cos(az),d*math.sin(el))); co.rotation_euler=(ctr-co.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=path; bpy.ops.render.render(write_still=True)
    DARK=fabric("Fabric_Dark",(0.035,0.035,0.042),weave=0.10,grain=0.02)
    def tex_node(m): return [n for n in m.node_tree.nodes if n.type=='TEX_IMAGE'][0]
    def style(name):
        hide={"normal":["Outfit_Gloves"]+MASKSET,"black":["Outfit_Coat"]+MASKSET,"mask":["Outfit_Coat","Mask_Halo"]+HATUP+FACEHAIR}[name]
        for o_ in bpy.context.scene.objects:
            if o_.type=='MESH': o_.hide_render=o_.name in hide
        dark=name!="normal"
        tex_node(SHIRT).image=DARK if dark else SHIRTIMG; tex_node(TIEW).image=DARK if dark else TIEIMG
        TRIM.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.04,0.04,0.05,1) if dark else (0.90,0.91,0.93,1)
    views=[(None,1,0),("Idle_Loop",20,30),("Walk_Formal_Loop",12,35),("Idle_Loop",20,180),("Idle_Loop",20,45),("Idle_Loop",20,95)]
    for st_ in ("normal","black","mask"):
        style(st_)
        for k,(an,fr,az) in enumerate(views if PREVIEW=="full" else views[1:2]):
            shot(an,fr,az,SP+f"t5_{st_}_{k}.png",el_deg=30 if k==4 else 18)
        sc.render.resolution_x,sc.render.resolution_y=132,200      # the game's size: the figure is ~190 px tall at play zoom (D73)
        shot("Walk_Formal_Loop",12,45,SP+f"t5_{st_}_game.png",ortho=2.1,el_deg=30)
        sc.render.resolution_x,sc.render.resolution_y=420,640
        if st_=="mask":
            for k2,(az2,el2) in enumerate(((0,6),(30,6),(45,30))): shot("Idle_Loop",20,az2,SP+f"t5_mask_close_{k2}.png",ctr=Vector((0,-0.04,1.66)),ortho=0.62,el_deg=el2)
        else:
            for k2,az2 in enumerate((0,30)): shot(None,1,az2,SP+f"t5_{st_}_chest_{k2}.png",ctr=Vector((0,-0.05,1.45)),ortho=0.62,el_deg=8)
    style("normal")
    for k2,az2 in enumerate((0,30)): shot(None,1,az2,SP+f"t5_face_{k2}.png",ctr=Vector((0,-0.03,1.69)),ortho=0.40,el_deg=4)
    if bpy.data.objects.get("Face_Beard"):
        bpy.data.objects["Face_Beard"].hide_render=True
        for k2,az2 in enumerate((0,30)): shot(None,1,az2,SP+f"t5_face_shaved_{k2}.png",ctr=Vector((0,-0.03,1.69)),ortho=0.40,el_deg=4)
        bpy.data.objects["Face_Beard"].hide_render=False
print("OK t5")
