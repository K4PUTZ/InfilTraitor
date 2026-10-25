# hero_tailor.py — our OWN costume, face and mask for the agile-B body, skinned to the same 65-bone skeleton (no CC0 suit was found; see ACTOR D74-D79).
# v5 (2026-10-21); v5.2 (2026-10-24, D79): the overcoat is a KIT of modules (Outfit_Coat_Body / _Sleeves / _Collar / _Skirt) fitted on a tailor's dummy
# instead of the muscles, its skirt hung from the hips; AGE / MARKS weather the face. ONE file holds every state; the engine shows a subset:
#   normal = everything except Outfit_Gloves and the MASK kit;   black = hides the coat (Outfit_Coat_*, its modules) and the MASK kit (shirt/tie/trim go dark);
#   mask   = black + the MASK kit (Mask_Face, Mask_Jaw, Mask_Eyes, Mask_Halo) with the hat AND Face_Hair / Face_Beard hidden: the hat's crown IS
#            the mask (D77), so the masked agent wears no hat. Face_Beard is optional in the unmasked states (the bench's `_shaved` hides it).
# Pieces: shirt, contrast trim (turned-down collar, cuffs, pocket square), a thick tie (knot, diagonal stripes, tie bar), jacket (V opening, lapels), trousers
# with a break, two parametric shoes, gloves, the overcoat (DRAPED over the body and the pack, lined, half open, wide lapels, a standing collar), an oval
# fedora (teardrop crease, front pinches, snap brim), a flat black pack with two back pockets, CC0 hair, a short boxed beard grown from the face, the MASK
# (felt crown shell with the fedora's crease, the band across the eyes with amber lenses and an additive halo, smooth jaw plates), and FACE BLEND SHAPES on
# the skin / eyes / eyebrows / beard (smile, frown, brow_up, brow_down, blink, eyes_wide, jaw_open; the decimated LOD has none by design).
# Env: HERO_REPO (repo root, trailing /), HERO_UAL_GLB (UAL1_Standard.glb), HERO_HAIR_DIR (the pack's "Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/",
# trailing /; empty = no hair), BODY_FILE (default superhero_male_agile_b_lean.glb), OUT_SUFFIX, COAT (mustard | beige | lightblue; default mustard), BEARD
# (1 | 0), DECIMATE (LOD ratio; 0.2 for the game LOD, weighted per piece by LOD_WEIGHT), HERO_TMP (preview folder), PREVIEW (full | quick | none),
# HERO_OUT_DIR (GLB folder, trailing /; default the body's folder), HERO_HAIR_GLB (a previous master whose fitted hair is reused when the CC0 hair pack is
# not at hand), AGE (0..1) and MARKS (brow_scar, cheek_scar, broken_nose): the signs of age and of life, below; CHIN, EYEBAGS, GREY, SKIN, NOSE (the
# base nose pulled back, 0 = off), FEATURES ("name[:strength]", default hawk_nose:0.25), FEATURE_GAIN (2.4), HAIR_CUT (short | full). The quick loop that
# builds into a scratch folder and renders the face is hero_quick.sh (D81, 2026-10-25).
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
# (13) Decimate with a vertex group KEEPS the group's vertices only with invert_vertex_group=True (measured: invert off kept 1 of 41 seam vertices and
# barely decimated; on kept 41 of 41 at the ratio): that is how the LOD keeps the coat's module seams shared. (14) The CC0 packs (UAL1_Standard.glb, the
# hair) are downloads kept outside the repo: on 2026-10-25 the temporary folder holding them was wiped mid-session. Keep them somewhere permanent;
# meanwhile HERO_UAL_GLB and HERO_HAIR_GLB accept a previous master, which carries the tracks (sampled per frame) and the fitted hair: the v5.1 master
# rebuilt from the packs on 2026-10-24 is kept at ARCHIVE/hero_sources/hero_source_v51.glb (git-ignored, Godot-ignored). Never build over that file. (15) A material
# node's colour is LINEAR, a generated image's pixels are sRGB: the same "0.034" is a black in fabric() and a ~20% grey in mat(). The hat went grey for
# that (fixed with srgb()); the other mat() darks (shoes, gloves, pack, mask) still carry the slip, untouched until the Director takes them one by one.
# (16) A hat drawn to a target's proportions must still FIT THE HEAD: the v5.2 crown was 5 mm inside the nape's scalp, and the hair pressed inside the
# crown went under the skin (279 of 757 vertices): bare scalp under the brim at the back, and the "bald" patches without the hat. fit_crown() sizes the
# crown from the head, and the press never puts a hair vertex under the skin (measured after: 0).
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree
SP=os.environ.get("HERO_TMP","/tmp/")
UAL=os.environ.get("HERO_UAL_GLB","")     # the CC0 animation library; a previous hero master also works (it carries the same 43 tracks, sampled per frame)
HAIRD=os.environ.get("HERO_HAIR_DIR","")
HAIRG=os.environ.get("HERO_HAIR_GLB","")  # without the CC0 hair pack: the fitted, tinted Face_Hair of a previous hero master (already pressed under the fedora)
D=os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
BODY=D+os.environ.get("BODY_FILE","superhero_male_agile_b_lean.glb"); SUF=os.environ.get("OUT_SUFFIX","_tailor5")
DEC=float(os.environ.get("DECIMATE","1.0")); PREVIEW=os.environ.get("PREVIEW","full")
OUTD=os.environ.get("HERO_OUT_DIR",D)       # where the GLB goes (default: next to the body, the game's folder); a scratch folder keeps trial builds out of Godot's import
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BODY)
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:len(o.data.polygons))
DATA=lambda: (bpy.data.meshes,bpy.data.materials,bpy.data.images)
def snapshot(): return [set(c_) for c_ in DATA()]
def purge_orphans(before):
    """what an import left behind once its objects are gone (only what it brought: `before` is a snapshot()): a hero master used as the animation
    source brings materials named like ours (Coat_Fabric...), and ours would then be created as Coat_Fabric.001, a name the bench's cloth shader no
    longer finds"""
    for coll,old in zip(DATA(),before):
        for d_ in [d_ for d_ in coll if d_.users==0 and d_ not in old]: coll.remove(d_)
before=set(bpy.data.objects); _snap=snapshot(); bpy.ops.import_scene.gltf(filepath=UAL)
extra=[o for o in bpy.data.objects if o not in before]
ad=arm.animation_data_create()
for act in list(bpy.data.actions):
    ad.action=act; ad.action_slot=act.slots[0]
    tr=ad.nla_tracks.new(); tr.name=act.name; st=tr.strips.new(act.name,0,act); st.action_slot=act.slots[0]
ad.action=None
for o in extra: bpy.data.objects.remove(o,do_unlink=True)
purge_orphans(_snap)
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
def mat(name,rgb,rough=0.85,spec=None):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=rough; m.diffuse_color=(*rgb,1)
    for k in (("Specular IOR Level","Specular") if spec is not None else ()):
        if k in b.inputs: b.inputs[k].default_value=spec
    return m
# ---------- AGE (v5.2; Director 2026-10-24: "the agent needs to be a bit older [...] a man already punished by life", then: "but not completely
# finished: a man who still has energy and agility. Aim at a Geralt. Not all-white hair, semi-grey"). So AGE (0..1) WEATHERS him and barely DECLINES
# him: at full strength the rugged signs (forehead and frown lines, crow's feet, the nasolabial fold, a lean hollow under the cheekbones, sun-worn skin)
# are whole, the signs of decline (bags, a heavier jowl, the outer brows coming down, hollow temples, age spots) come in at DECLINE of that, and the hair
# turns salt-and-pepper all over, whiter at the temples (after the hair, below). MARKS adds life's scars (brow_scar, cheek_scar,
# broken_nose). THE DIRECTOR'S FACE (2026-10-25: "a slightly wider chin, some bags under the eyes and grey hair; a discreet scar on the brow is welcome
# (it tells the agent apart from any other character); and a little texture on the skin so it is not so perfect") is the default: CHIN, EYEBAGS, GREY
# (the hair, on its own knob now), SKIN (pores and unevenness), MARKS=brow_scar, and a light AGE for the lines. The texture is painted in 3-D: every texel of the head's UV island
# learns the rest position it is drawn at (rasterised from the mesh), and each sign is a field of that position, so nothing depends on the UV layout ----------
AGE=float(os.environ.get("AGE","0.4")); MARKS=[m for m in os.environ.get("MARKS","brow_scar").split(",") if m]
CHIN=float(os.environ.get("CHIN","1")); EYEBAGS=float(os.environ.get("EYEBAGS","0.7")); GREY=float(os.environ.get("GREY","0.5")); SKIN=float(os.environ.get("SKIN","1"))
# SIGNATURE features (Director 2026-10-25: "we are trying to be original (avoid being ordinary), so if we could shape his face to be unique, it would be
# awesome"): each is a knob in FEATURES, none on by default until the Director composes his face. Geometry: hawk_nose (an aquiline bridge, the tip a
# little down), crooked_nose (broken once, set a few millimetres off true), heavy_brow (a forward brow ridge: deep-set eyes), high_cheeks (cheekbones out,
# hollow under), square_jaw (the jaw's angles out, a flat chin), cleft_chin, smirk (the left mouth corner set higher: a permanent half-smile).
# Hair: widows_peak (the hairline dips to a point), grey_streak (one pale forelock). Eyes: steel_eyes (a pale grey-blue iris)
NOSE=float(os.environ.get("NOSE","0"))     # 0..1: how much the base nose is pulled back toward the face (a study knob, uncommitted)
FEATURES={f.split(":")[0]:(float(f.split(":")[1]) if ":" in f else 1.0) for f in os.environ.get("FEATURES","hawk_nose:0.25").split(",") if f}   # name[:strength]; the hawk nose softened (Director 2026-10-25)
FEATURE_GAIN=float(os.environ.get("FEATURE_GAIN","2.4"))   # at 1 (3-4 mm on a 16 cm head) the first catalogue's faces read nearly the same
# (Director, later the same day: "the brows match the hair, and leave more black hair: he is still halfway between youth and middle age": GREY 1 -> 0.5,
# AGE 0.5 -> 0.4, and the brows take the hair's greying)
DECLINE=0.3                 # the share of AGE that the signs of decline get (the Geralt brief: weathered, still fit)
def gauss3(p,c,sx,sy,sz): return math.exp(-0.5*(((p.x-c[0])/sx)**2+((p.y-c[1])/sy)**2+((p.z-c[2])/sz)**2))
def seg_dist2(px,pz,a,b):
    """distance in the x-z plane (the face seen from the front) from (px, pz) to the segment a-b, and the position along it (0..1)"""
    ax,az=a; bx,bz=b; dx,dz=bx-ax,bz-az; L2=dx*dx+dz*dz
    t=np.clip(((px-ax)*dx+(pz-az)*dz)/L2,0.0,1.0); return np.hypot(px-(ax+t*dx),pz-(az+t*dz)),t
NASOLABIAL=((0.023,1.650),(0.040,1.610)); MARIONETTE=((0.029,1.618),(0.034,1.597))
def age_delta(p,a,eyebrows=False):
    """the large forms of age, in metres (the head is ~16 cm wide); only the front of the head above the neck"""
    d=Vector((0,0,0))
    if p.z<1.55 or p.y>0.0: return d
    s=1.0 if p.x>=0 else -1.0; ax=abs(p.x)
    if not eyebrows:
        d.x+=s*0.0030*CHIN*gauss3(p,(s*0.020,-0.080,1.590),0.012,0.03,0.012)          # a slightly wider chin (3 mm a side)
        if NOSE>0.0 and p.y<-0.088:          # a SMALLER nose (Director 2026-10-25: "this nose is too big, let's soften it"; the base head's own nose is the size)
            m_=math.exp(-(p.x/0.018)**2)*math.exp(-((p.z-1.666)/0.020)**2)
            d.y+=NOSE*m_*(-0.088-p.y)                                                    # less projection: the tip comes back toward the face
            d.x-=NOSE*0.25*p.x*m_                                                        # a little narrower
            d.z+=NOSE*0.0025*math.exp(-(p.x/0.012)**2)*math.exp(-((p.z-1.655)/0.008)**2) # and shorter (the tip lifts)
        d.y-=0.0013*EYEBAGS*gauss3(p,(s*0.034,-0.079,1.680),0.013,0.010,0.0045)          # the Director's bags under the eyes
        d.y+=0.0007*EYEBAGS*gauss3(p,(s*0.034,-0.077,1.671),0.014,0.010,0.0035)
        d.y-=0.0018*a*DECLINE*gauss3(p,(s*0.034,-0.079,1.680),0.013,0.010,0.0045)      # the bags under the eyes
        d.y+=0.0010*a*DECLINE*gauss3(p,(s*0.034,-0.077,1.671),0.014,0.010,0.0035)      # and the hollow under them
        dd,t=seg_dist2(ax,p.z,*NASOLABIAL); fade=math.sin(math.pi*float(t))**0.5
        d.y-=0.0016*a*fade*math.exp(-((float(dd)-0.005)/0.004)**2)*(1.0 if ax>0.023+0.425*(1.650-p.z) else 0.0)   # the cheek rolls over the fold
        d.y+=0.0008*a*fade*math.exp(-(float(dd)/0.002)**2)                              # the fold itself
        d.y+=0.0018*a*gauss3(p,(s*0.050,-0.060,1.636),0.012,0.02,0.012)                # lean under the cheekbones (rugged, not gaunt)
        d.z-=0.0015*a*DECLINE*gauss3(p,(s*0.040,-0.070,1.592),0.012,0.02,0.010)        # a heavier jowl
        d.x+=s*0.0008*a*DECLINE*gauss3(p,(s*0.040,-0.070,1.592),0.012,0.02,0.010)
        d.x-=s*0.0012*a*DECLINE*gauss3(p,(s*0.064,-0.040,1.725),0.010,0.02,0.014)      # hollow temples
    d.z-=0.0020*a*DECLINE*gauss3(p,(s*0.050,-0.070,1.718),0.012,0.03,0.010)            # the outer brows come down: a tired look
    F=FEATURES; fd=Vector((0,0,0)); w=lambda n: F.get(n,0.0)      # each feature at its own strength (FEATURES="hawk_nose:0.5,...")
    if w("hawk_nose") and not eyebrows:
        fd.y-=w("hawk_nose")*0.0034*gauss3(p,(0.0,-0.100,1.673),0.0075,0.03,0.0085)       # the hump of the bridge
        fd.z-=w("hawk_nose")*0.0020*gauss3(p,(0.0,-0.110,1.655),0.0085,0.03,0.0060)       # the tip turns down
        fd.x-=w("hawk_nose")*s*0.0012*gauss3(p,(s*0.011,-0.100,1.662),0.0060,0.03,0.0100) # a narrower nose
    if w("crooked_nose") and not eyebrows:
        w_=w("crooked_nose")*gauss3(p,(0.0,-0.100,1.662),0.0110,0.03,0.0130)*min(1.0,max(0.0,(1.690-p.z)/0.018))     # (sstep is defined further down)
        fd.x+=0.0032*w_; fd.y-=w("crooked_nose")*0.0015*gauss3(p,(0.0,-0.100,1.676),0.0060,0.03,0.0050)   # set off true below a knock on the bridge
    if w("heavy_brow"):
        fd.y-=w("heavy_brow")*0.0028*gauss3(p,(s*0.030,-0.088,1.722),0.020,0.03,0.0075)   # the ridge comes forward: the eyes sit deep under it
        fd.z-=w("heavy_brow")*0.0012*gauss3(p,(s*0.030,-0.088,1.718),0.020,0.03,0.0060)
    if w("high_cheeks") and not eyebrows:
        fd.x+=w("high_cheeks")*s*0.0026*gauss3(p,(s*0.058,-0.060,1.668),0.012,0.03,0.010); fd.y-=w("high_cheeks")*0.0012*gauss3(p,(s*0.052,-0.065,1.668),0.012,0.03,0.010)
        fd.y+=w("high_cheeks")*0.0026*gauss3(p,(s*0.047,-0.062,1.633),0.012,0.03,0.012)
    if w("square_jaw") and not eyebrows:
        fd.x+=w("square_jaw")*s*0.0042*gauss3(p,(s*0.062,-0.020,1.600),0.016,0.04,0.016)  # the jaw's angles out
        fd.z-=w("square_jaw")*0.0015*gauss3(p,(0.0,-0.080,1.578),0.022,0.03,0.008)         # a flatter, squarer chin
    if w("cleft_chin") and not eyebrows:
        fd.y+=w("cleft_chin")*0.0013*math.exp(-(p.x/0.0030)**2)*gauss3(p,(0.0,-0.085,1.586),1.0,0.03,0.0080)
    if w("smirk") and not eyebrows:
        fd.z+=w("smirk")*0.0017*gauss3(p,(0.027,-0.080,1.622),0.0075,0.03,0.0060); fd.y+=w("smirk")*0.0006*gauss3(p,(0.027,-0.080,1.622),0.0075,0.03,0.0060)
    d+=fd*FEATURE_GAIN
    if "broken_nose" in MARKS:
        d.y-=0.0018*gauss3(p,(0.0,-0.100,1.677),0.006,0.02,0.006)                       # a bump on the bridge
        if p.z<1.672 and ax<0.022 and p.y<-0.085: d.x+=0.0015*min(1.0,(1.672-p.z)/0.017)   # and the tip a little off true
    if "cheek_scar" in MARKS and p.x<0:
        dd,t=seg_dist2(p.x,p.z,(-0.045,1.660),(-0.060,1.632)); d.y+=0.0006*math.exp(-(float(dd)/0.0015)**2)
    return d
FACE_ON=AGE>0.0 or bool(MARKS) or CHIN>0.0 or EYEBAGS>0.0 or SKIN>0.0 or bool(FEATURES)
if FACE_ON:
    for o_,eb in ((body,False),(bpy.data.objects.get("Eyebrows"),True)):
        if o_ is not None:
            for v in o_.data.vertices: v.co+=age_delta(v.co,AGE,eb)
    if "brow_scar" in MARKS and bpy.data.objects.get("Eyebrows"):        # a gap through the left brow (the wearer's left is +x)
        _eb=bmesh.new(); _eb.from_mesh(bpy.data.objects["Eyebrows"].data)
        bmesh.ops.delete(_eb,geom=[f for f in _eb.faces if abs(f.calc_center_median().x-0.033)<0.0028],context='FACES')
        _eb.to_mesh(bpy.data.objects["Eyebrows"].data); _eb.free()
def texel_positions(o,W,H,keep):
    """for each texel of the image o's render UV map draws, the rest position on the mesh (NaN where nothing is drawn), from the faces keep() accepts;
    grown 3 texels past each island so the seams sample a position too"""
    me=o.data; uv=me.uv_layers[[l.name for l in me.uv_layers if l.active_render][0]].data; co=[v.co for v in me.vertices]
    P=np.full((H,W,3),np.nan)
    for poly in me.polygons:
        if not keep(poly.center): continue
        L=list(poly.loop_indices)
        for k in range(1,len(L)-1):
            tri=(L[0],L[k],L[k+1]); U=np.array([[uv[l].uv[0]*W,uv[l].uv[1]*H] for l in tri]); X=np.array([co[me.loops[l].vertex_index][:] for l in tri])
            x0,y0=np.floor(U.min(0)).astype(int); x1,y1=np.ceil(U.max(0)).astype(int)
            gx,gy=np.meshgrid(np.arange(max(x0,0),min(x1,W-1)+1)+0.5,np.arange(max(y0,0),min(y1,H-1)+1)+0.5)
            den=(U[1,1]-U[2,1])*(U[0,0]-U[2,0])+(U[2,0]-U[1,0])*(U[0,1]-U[2,1])
            if abs(den)<1e-12: continue
            w0=((U[1,1]-U[2,1])*(gx-U[2,0])+(U[2,0]-U[1,0])*(gy-U[2,1]))/den; w1=((U[2,1]-U[0,1])*(gx-U[2,0])+(U[0,0]-U[2,0])*(gy-U[2,1]))/den; w2=1-w0-w1
            m=(w0>=-1e-4)&(w1>=-1e-4)&(w2>=-1e-4)
            if not m.any(): continue
            iy=(gy[m]-0.5).astype(int); ix=(gx[m]-0.5).astype(int)
            P[iy,ix]=w0[m][:,None]*X[0]+w1[m][:,None]*X[1]+w2[m][:,None]*X[2]
    for _ in range(3):
        bad=np.isnan(P[...,0]); src=None
        for sh in ((0,1),(0,-1),(1,0),(-1,0)):
            R=np.roll(P,sh,axis=(0,1)); fill=bad&~np.isnan(R[...,0]); P[fill]=R[fill]
    return P
def line_mask(P,pts,w,axes=(0,2)):
    """a soft line along the polyline pts (in the plane of two axes), w its half-width, faded toward the polyline's two ENDS (a fade per segment
    dashed every joint: the bag's crease came out as stitches)"""
    a0,a1=axes; px,pz=P[...,a0],P[...,a1]; best=np.full(px.shape,np.inf); along=np.zeros(px.shape)
    lens=[math.hypot(b[0]-a[0],b[1]-a[1]) for a,b in zip(pts[:-1],pts[1:])]; tot=sum(lens); acc=0.0
    for (a,b),L in zip(zip(pts[:-1],pts[1:]),lens):
        dd,t=seg_dist2(px,pz,a,b); upd=dd<best; best=np.where(upd,dd,best); along=np.where(upd,(acc+t*L)/tot,along); acc+=L
    return np.exp(-(best/w)**2)*np.clip(np.sin(np.pi*along)*1.6,0.0,1.0)
def age_skin(o):
    """paint the signs of age and the scars onto a COPY of the skin texture (the original stays the CC0 file's)"""
    nt=o.data.materials[0].node_tree; tex=[n for n in nt.nodes if n.type=='TEX_IMAGE'][0]; src=tex.image; W,H=src.size
    px=np.empty(W*H*4,dtype=np.float32); src.pixels.foreach_get(px); img=px.reshape(H,W,4)[...,:3].astype(np.float64)
    P=texel_positions(o,W,H,lambda c: c.z>1.50); ok=~np.isnan(P[...,0]); Q=np.where(ok[...,None],P,0.0)
    X,Y,Z=Q[...,0],Q[...,1],Q[...,2]; AX=np.abs(X); front=(Y<-0.03)&ok; face=(Y<-0.02)&ok      # (x, z) alone would print on the back of the head too
    dark=np.zeros((H,W)); a=AGE; rng=np.random.default_rng(23)
    if a>0.0:
        for k,z0 in enumerate((1.746,1.758,1.770)):                                       # forehead lines, wavy, longer in the middle one
            zz=Z-0.0015*np.sin(X*95.0+k*1.7); half=0.040+0.008*(k==1)
            dark+=0.24*a*np.exp(-((zz-z0)/0.0013)**2)*np.clip((half-AX)/0.012,0,1)*front
            dark-=0.07*a*np.exp(-((zz-z0+0.0028)/0.0016)**2)*np.clip((half-AX)/0.012,0,1)*front   # the ridge under each crease catches the light
        for s in (1,-1):
            dark+=0.20*a*line_mask(P,[(s*0.0055,1.712),(s*0.0062,1.733)],0.0011)*front   # the frown's "11"
            for ang in (-28,-6,16):                                                         # crow's feet, fanning back from the outer corner
                r=math.radians(ang); o_=(s*0.051,1.700); e_=(s*(0.051+0.015*math.cos(r)),1.700+0.015*math.sin(r))
                dark+=0.24*a*line_mask(P,[o_,e_],0.0011)*face
            arc=[(s*(0.020+0.032*t),1.674+0.006*((t-0.5)/0.5)**2) for t in np.linspace(0,1,9)]
            dark+=0.20*a*(0.4+0.6*DECLINE)*line_mask(P,arc,0.0014)*front                    # the crease under the eye
            dark+=0.12*a*DECLINE*np.exp(-(((AX-0.034)/0.014)**2+((Z-1.681)/0.004)**2))*front   # a darker crescent under the eye
            dark+=0.26*a*line_mask(P,[(s*NASOLABIAL[0][0],NASOLABIAL[0][1]),(s*0.031,1.630),(s*NASOLABIAL[1][0],NASOLABIAL[1][1])],0.0016)*front
            dark+=0.16*a*DECLINE*line_mask(P,[(s*MARIONETTE[0][0],MARIONETTE[0][1]),(s*MARIONETTE[1][0],MARIONETTE[1][1])],0.0013)*front
        tint=np.array((0.80,1.00,1.15))                                                     # lines go warm (less blue, less green than red)
        img*=np.clip(1.0-dark[...,None]*tint,0.0,1.2)
        nz=np.zeros((H,W))                                                                  # weathering: low blotches, red nose / cheeks, less saturation, spots
        for f_,amp in ((60.0,0.5),(140.0,0.3),(320.0,0.2)):
            ph=rng.uniform(0,6.3,3); nz+=amp*np.sin(X*f_+ph[0])*np.sin(Z*f_*1.1+ph[1])*np.sin(Y*f_*0.9+ph[2])
        img*=(1.0+0.07*a*nz)[...,None]*ok[...,None]+(~ok)[...,None]
        red=np.exp(-((X/0.012)**2+((Z-1.660)/0.012)**2))+0.6*np.exp(-(((AX-0.045)/0.015)**2+((Z-1.650)/0.012)**2))
        img*=1.0+(0.10*a*red*front)[...,None]*np.array((0.6,-0.25,-0.35))
        lum=img.mean(axis=2,keepdims=True); img=np.where(ok[...,None],lum+(img-lum)*(1.0-0.12*a*DECLINE),img)
        for _ in range(9):
            c_=(rng.choice((-1,1))*rng.uniform(0.03,0.065),rng.uniform(1.70,1.78)); r_=rng.uniform(0.0012,0.0022)
            img*=1.0-(0.14*a*DECLINE*np.exp(-(((X-c_[0])**2+(Z-c_[1])**2)/r_**2))*face)[...,None]*np.array((0.7,0.9,1.0))
    if EYEBAGS>0.0:          # OLHEIRAS: a brown-violet shadow under each eye and the soft crease that closes it
        circ=np.zeros((H,W))
        for s in (1,-1):
            circ+=0.20*EYEBAGS*np.exp(-(((X-s*0.034)/0.015)**2+((Z-1.6805)/0.0042)**2))*front
            arc=[(s*(0.021+0.030*t),1.6745+0.005*((t-0.5)/0.5)**2) for t in np.linspace(0,1,9)]
            circ+=0.16*EYEBAGS*line_mask(P,arc,0.0013)*front
        img*=np.clip(1.0-circ[...,None]*np.array((0.85,1.10,0.80)),0.0,1.0)
    if SKIN>0.0:             # TEXTURE: pores (per-texel grain, softened over a texel) and a mottling of tone, so the skin is not a plastic gradient
        g_=rng.normal(0.0,1.0,(H,W)); g_=(g_+np.roll(g_,1,0)+np.roll(g_,-1,0)+np.roll(g_,1,1)+np.roll(g_,-1,1))/5.0
        mot=np.zeros((H,W))
        for f_,amp in ((90.0,0.6),(210.0,0.4)):
            ph=rng.uniform(0,6.3,3); mot+=amp*np.sin(X*f_+ph[0])*np.sin(Z*f_*1.13+ph[1])*np.sin(Y*f_*0.87+ph[2])
        img*=(1.0+(SKIN*(0.028*g_+0.035*mot)*ok)[...,None]*np.array((1.0,1.05,1.1)))     # (a 7.5% grain read as a sponge)
    if "cleft_chin" in FEATURES:
        img*=(1.0-(0.14*np.exp(-(X/0.0018)**2)*np.exp(-((Z-1.586)/0.007)**2)*front))[...,None]
    pale=np.zeros((H,W))
    if "brow_scar" in MARKS: pale+=line_mask(P,[(0.031,1.737),(0.034,1.716),(0.037,1.703)],0.0008)*front
    if "cheek_scar" in MARKS: pale+=line_mask(P,[(-0.045,1.660),(-0.053,1.646),(-0.060,1.632)],0.0010)*front
    img=img*(1-0.45*pale[...,None])+0.45*pale[...,None]*np.array((0.92,0.66,0.62))           # scars heal pale and a little pink
    out=image("T_Hero_Skin",np.clip(img,0,1)); tex.image=out
    print("T5 age",AGE,"marks",MARKS,"chin",CHIN,"eyebags",EYEBAGS,"skin",SKIN,"head texels",int(ok.sum()),"darkened",int((dark>0.02).sum()))
if FACE_ON: age_skin(body)
def steel_eyes(o):
    """a pale grey-blue iris on a copy of the eye texture: every texel learns its point on the eyeball, the iris is what faces forward (the pupil stays)"""
    nt=o.data.materials[0].node_tree; tex=[n for n in nt.nodes if n.type=='TEX_IMAGE'][0]; src=tex.image; W,H=src.size
    px=np.empty(W*H*4,dtype=np.float32); src.pixels.foreach_get(px); img=px.reshape(H,W,4)[...,:3].astype(np.float64)
    P=texel_positions(o,W,H,lambda c: True); ok=~np.isnan(P[...,0]); Q=np.where(ok[...,None],P,0.0)
    cen=np.where((Q[...,0]>0)[...,None],np.array((0.0338,-0.0696,1.6985)),np.array((-0.0338,-0.0696,1.6985))); v=Q-cen
    cosf=-v[...,1]/np.maximum(np.linalg.norm(v,axis=2),1e-6); ang=np.degrees(np.arccos(np.clip(cosf,-1,1)))
    iris=ok&(ang<34)&(ang>11); lum=img.mean(axis=2,keepdims=True)
    tgt=np.clip(lum/max(1e-3,float(lum[iris].mean())),0.4,1.8)*np.array((0.50,0.54,0.56))
    k_=np.clip((34-ang)/4.0,0,1)[...,None]*iris[...,None]; img=img*(1-k_)+tgt*k_
    tex.image=image("T_Hero_Eyes",np.clip(img,0,1)); print("T5 steel eyes: iris texels",int(iris.sum()))
if "steel_eyes" in FEATURES and bpy.data.objects.get("Eyes"): steel_eyes(bpy.data.objects["Eyes"])
SUITIMG=fabric("Fabric_Pinstripe",(0.034,0.034,0.040),stripe=(0.15,0.15,0.17),weave=0.20,grain=0.03)
SUIT=tmat("Suit_Black",SUITIMG)                         # a black wool suit with a faint pinstripe and a twill weave: not latex
def srgb(*c): return tuple(x/12.92 if x<=0.04045 else ((x+0.055)/1.055)**2.4 for x in c)   # a node's colour is LINEAR, an image's pixels are sRGB
BLACK=mat("Hat_Black",srgb(0.036,0.036,0.042),0.9,0.12)  # hat felt: the suit's black and its low sheen. Director 2026-10-25: "the hat is grey, we want it black
                         # like the suit". The suit's 0.034 is an sRGB PIXEL (linear ~0.003), the felt's 0.034 was a LINEAR node value (an sRGB ~0.20 grey,
                         # ~13x the suit's albedo); Blender's default specular 0.5 added a sky sheen on top. Measured in renders: felt luma 66 vs suit 20
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
OLIVE=mat("Pack_Black",(0.05,0.052,0.058),0.7); GLOVE=mat("Glove_Leather",(0.016,0.016,0.02),0.55); BAND=mat("Hat_Band",srgb(0.024,0.024,0.028),0.55,0.25); SHOE=mat("Shoe_Leather",(0.022,0.022,0.026),0.4)
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
def lapels(bm,zb,width,lift,taper=0.0,peak=0.0):
    """taper (m): the lapel grows from nothing at the break point zb to its full width that far above it (0 = a constant width); peak (m): a PEAK
    lapel, its top corner rising that far and leaning out toward the shoulder (0 = the plain top)"""
    es=[e for e in bm.edges if e.is_boundary and all(v.co.y<0.0 and abs(v.co.x)<0.14 and v.co.z>zb-0.02 and v.co.z<zn+0.05 for v in e.verts)
        and abs(e.verts[0].co.z-e.verts[1].co.z)>0.35*(e.verts[0].co-e.verts[1].co).length]
    if not es: return
    ret=bmesh.ops.extrude_edge_only(bm,edges=es); nv=[g for g in ret['geom'] if isinstance(g,bmesh.types.BMVert)]
    ztop=max(v.co.z for v in nv)
    for v in nv:
        k=sstep(zb,zb+taper,v.co.z) if taper>0.0 else 1.0; s_=1 if v.co.x>0 else -1
        v.co.x+=s_*width*k; v.co.y-=lift*k
        if peak>0.0:
            q=sstep(ztop-0.045,ztop,v.co.z); v.co.z+=peak*q; v.co.x+=s_*0.4*peak*q
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
def finish(o,bm,material,uv=None,facet=None,extra=()):
    sweep(bm); bm.normal_update()
    if uv: box_uv(bm,uv)
    bm.to_mesh(o.data); bm.free()
    if facet:      # hard-surface: collapse to few planes and shade them flat
        dm=o.modifiers.new('Dec','DECIMATE'); dm.ratio=facet; bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier='Dec')
        for p_ in o.data.polygons: p_.use_smooth=False
    else:
        for p_ in o.data.polygons: p_.use_smooth=True
    idx=[p_.material_index for p_ in o.data.polygons]          # materials.clear() resets every face's material_index to 0 (the extra slots stood empty)
    o.data.materials.clear(); o.data.materials.append(material)
    for m_ in extra: o.data.materials.append(m_)             # slots 1.. for faces whose material_index the builder set
    if extra: o.data.polygons.foreach_set("material_index",idx)
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
# ---- THE TAILOR'S DUMMY (v5.2) the coat is fitted on. Director 2026-10-24 on the v5.1 coat: "it has a whole muscular shape and no malleability to
# adapt to the agent's body". It was the body pushed out, so every muscle stayed in it. The dummy is the body as a tailor sees it: per slice, the convex
# hull of the torso (the pack included) and of each arm; the torso hangs from its widest slice down (a curtain off the chest, the blades and the pack),
# each sleeve from the shoulder down to the cuff; fused into ONE surface (voxel remesh) and smoothed. The coat drapes on that, so no muscle reaches it ----
def hull2(P):
    P=sorted(set(P))
    if len(P)<3: return P
    cr=lambda o,a,b: (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lo=[];hi=[]
    for p in P:
        while len(lo)>=2 and cr(lo[-2],lo[-1],p)<=0: lo.pop()
        lo.append(p)
    for p in reversed(P):
        while len(hi)>=2 and cr(hi[-2],hi[-1],p)<=0: hi.pop()
        hi.append(p)
    return lo[:-1]+hi[:-1]
def ray_out(H,c,a):
    """distance from c (inside the hull H) to its edge along angle a"""
    dx,dy=math.cos(a),math.sin(a); best=0.0
    for i in range(len(H)):
        p,q=H[i],H[(i+1)%len(H)]; ex,ey=q[0]-p[0],q[1]-p[1]; den=dx*ey-dy*ex
        if abs(den)<1e-12: continue
        t=((p[0]-c[0])*ey-(p[1]-c[1])*ex)/den; s=((p[0]-c[0])*dy-(p[1]-c[1])*dx)/den
        if t>0 and -1e-6<=s<=1+1e-6: best=max(best,t)
    return best
def curtain(R,step,taper):
    """rows in hanging order: each may come in by at most taper*step from the row above it, so the cloth falls from the widest row, never follows a waist"""
    for k in range(1,len(R)): R[k]=np.maximum(R[k],R[k-1]-taper*step)
    return R
def soften(R,passes=2):
    for _ in range(passes):
        R=(np.roll(R,1,1)+2*R+np.roll(R,-1,1))/4.0                                       # around
        R[1:-1]=(R[:-2]+2*R[1:-1]+R[2:])/4.0                                               # along
    return R
def loft(bm,rings):
    V=[[bm.verts.new(p) for p in r] for r in rings]; n=len(rings[0])
    for a in range(len(V)-1):
        for i in range(n): bm.faces.new([V[a][i],V[a][(i+1)%n],V[a+1][(i+1)%n],V[a+1][i]])
    bm.faces.new(V[0]); bm.faces.new(V[-1][::-1])
def tailor_dummy(voxel=0.007):
    src=bmesh.new(); src.from_mesh(full.data); dg=dgroup(src)
    TOR=[v.co.copy() for v in src.verts if (dg(v) or "").startswith(("spine_","pelvis","neck_","clavicle_")) or ((dg(v) or "").startswith("thigh_") and v.co.z>0.95)]
    for _n,(sx,sy,sz),(cx_,cy_,cz_) in PACK:      # the pack's outline, 13 mm proud of it (what over_pack() used to lift the cloth to)
        for ix in (-1,1):
            for iy in (-1,1):
                for iz in (-1,1): TOR.append(Vector((cx_+ix*sx/2,cy_+iy*(sy/2+(0.013 if iy>0 else 0)),cz_+iz*sz/2)))
    bm=bmesh.new(); NA=72; ANG=[2*math.pi*k/NA for k in range(NA)]
    # the torso: rows from the top of the shoulders down, a fixed axis
    yc0=(front+back)/2; dz=0.012; zs=np.arange(zn+0.035,0.955,-dz); R=np.zeros((len(zs),NA))
    for j,z in enumerate(zs):
        H=hull2([(p.x,p.y) for p in TOR if abs(p.z-z)<dz*0.75])
        R[j]=[ray_out(H,(0.0,yc0),a) if len(H)>=3 else 0.0 for a in ANG]
    R=soften(curtain(R,dz,0.10),2)
    loft(bm,[[Vector((R[j,k]*math.cos(a),yc0+R[j,k]*math.sin(a),z)) for k,a in enumerate(ANG)] for j,z in enumerate(zs)])
    # the sleeves: rows along each arm from inside the shoulder to past the wrist, round the bone line (T-pose: the arms are near level)
    for s,sfx in ((1,"l"),(-1,"r")):
        A=bw("upperarm_"+sfx); Wr=bw("hand_"+sfx); u=(Wr-A).normalized(); L=(Wr-A).length
        e1=u.cross(Vector((0,0,1))).normalized(); e2=e1.cross(u).normalized()
        ARM=[v.co.copy() for v in src.verts if (dg(v) or "").startswith(("upperarm_","lowerarm_","hand_")) and s*v.co.x>0]
        ts=np.arange(-0.05,L+0.035,0.015); Rs=np.zeros((len(ts),NA))
        for j,t in enumerate(ts):
            H=hull2([((p-A).dot(e1),(p-A).dot(e2)) for p in ARM if abs((p-A).dot(u)-t)<0.011])
            Rs[j]=[ray_out(H,(0.0,0.0),a) if len(H)>=3 else 0.0 for a in ANG]
        Rs=soften(curtain(Rs,0.015,0.12),3)
        rnd=np.clip(ts/L,0.0,1.0)[:,None]*0.35+0.25                 # a sleeve is a TUBE: rounder than the flat wrist under it (an oval one let the round
        Rs=Rs+rnd*(Rs.max(axis=1,keepdims=True)-Rs)                 # shirt cuff through), most of all at the cuff
        loft(bm,[[A+u*float(t)+(e1*math.cos(a)+e2*math.sin(a))*Rs[j,k] for k,a in enumerate(ANG)] for j,t in enumerate(ts)])
    src.free()
    me=bpy.data.meshes.new("TailorDummy"); bm.to_mesh(me); bm.free(); o=bpy.data.objects.new("TailorDummy",me); bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o
    rm=o.modifiers.new("R",'REMESH'); rm.mode='VOXEL'; rm.voxel_size=voxel; bpy.ops.object.modifier_apply(modifier="R")
    sm=o.modifiers.new("S",'SMOOTH'); sm.factor=0.6; sm.iterations=6; bpy.ops.object.modifier_apply(modifier="S")
    b2=bmesh.new(); b2.from_mesh(o.data); tree=BVHTree.FromBMesh(b2); b2.free()
    if os.environ.get("KEEP_DUMMY","0")=="0": bpy.data.objects.remove(o,do_unlink=True)
    return tree
DUMMYBVH=tailor_dummy()
# ---- the overcoat: DRAPED on the tailor's dummy (above) over the suit and the pack, hanging half open like Dick Tracy's, lined so its inside is never see-through ----
# THE COAT IS A KIT OF MODULES (Director 2026-10-24: "the coat is the most important garment [...] it defines the factions and it is also the LED coat
# [...] it needs more than one piece instead of one model"). Every face carries its module in the int layer "mod"; the coat is built, weighted and (for the
# LOD) decimated WHOLE, so its seams are shared vertices, and split into one mesh per module just before the export (split_coat()). The seams are
# the waist (z = COAT_WAIST, the body above, the skirt below), the armholes (x = +-COAT_ARMHOLE) and the neckline / front edges (the collar and lapels).
COAT_MODULES=("Body","Sleeves","Collar","Skirt"); COAT_WAIST=1.03; COAT_ARMHOLE=abs(bw("upperarm_l").x)+0.02
def tagged(bm_,layer,mod,fn,*args,**kw):
    """run a builder and give every face it adds the module `mod`"""
    before=set(bm_.faces); fn(bm_,*args,**kw)
    for f in bm_.faces:
        if f not in before: f[layer]=mod
o,bm=blank("Outfit_Coat"); keep_groups(bm,region(*TORSO)); MODL=bm.faces.layers.int.new("mod")
plane(bm,(0,0,COAT_WAIST),(0,0,1),inner=True); plane(bm,(0,0,zn+0.015),(0,0,1),outer=True)
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
    arm_=sstep(0.20,0.30,abs(v.co.x))                              # off the DUMMY, which already holds the ease: the suit under it, a sleeve a little closer
    return 0.024-0.008*arm_+sh(v)
drape(bm,coat_gap,40,bvh=DUMMYBVH,outside=over_pack)
for s_ in (1,-1): plane(bm,(s_*COAT_ARMHOLE,0,0),(s_,0,0))          # the armhole seams: cut only, then everything past them is the sleeves
for f in bm.faces:
    if abs(f.calc_center_median().x)>COAT_ARMHOLE: f[MODL]=1
folds(bm,[("lowerarm_l",None),("lowerarm_r",None)],0.0050)
def coat_w(z): return 0.045 if z>=zn+0.03 else 0.045+0.085*min(1.0,(zn+0.03-z)/(zn+0.03-COAT_WAIST))
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().y<0.0 and abs(f.calc_center_median().x)<coat_w(f.calc_center_median().z)],context='FACES'); sweep(bm)
smooth_boundary(bm,lambda c: c.y<0.0 and abs(c.x)<0.18 and c.z>zc-0.60,iters=5)
COAT_BREAK=zc-0.03            # the lapels roll from the top button up (v5.1 ran them down to the waist: two loose boards hanging the coat's length)
tagged(bm,MODL,2,lapels,COAT_BREAK,0.080,0.012,taper=0.10,peak=0.026)   # Dick Tracy's: wide PEAK lapels (bamfstyle, 2021)
def coat_skirt(bm_,length=0.58,flare=0.16,rows=8,n_folds=8,amp=0.015):
    """the SKIRT module, hung from the waist seam: the body's boundary ring at COAT_WAIST (an open C: the coat is open in front), doubled in density, ordered
    from one front edge round the back to the other; each row below it is that ring flared out from the torso's axis, in soft folds that deepen toward the
    hem and are not evenly spaced. Built row by row (v5.1 extruded the ring five times and subdivided: a coarse board, a ladder of flipped faces)"""
    ring=lambda: [e for e in bm_.edges if e.is_boundary and all(abs(v.co.z-COAT_WAIST)<0.004 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm_,edges=ring(),cuts=1)
    adj={}
    for e in ring():
        a_,b_=e.verts; adj.setdefault(a_,[]).append(b_); adj.setdefault(b_,[]).append(a_)
    ends=[v for v,n in adj.items() if len(n)==1]
    chain=[min(ends,key=lambda v: v.co.x)]
    while True:
        nxt=[w for w in adj[chain[-1]] if w not in chain[-2:]]
        if not nxt: break
        chain.append(nxt[0])
    yc0=(front+back)/2; prev=chain; cen=Vector((0.0,yc0,0.0))
    for r in range(1,rows+1):
        t=r/rows; z=COAT_WAIST-length*t; row=[]
        for v in chain:
            d=Vector((v.co.x,v.co.y-yc0,0.0)); R=d.length; th=math.atan2(d.y,d.x); d.normalize()
            Rn=R*(1.0+flare*t**1.3)+amp*t**1.2*math.sin(n_folds*th+0.9*math.sin(3*th+1.3))
            row.append(bm_.verts.new(Vector((d.x*Rn,yc0+d.y*Rn,z))))
        for i in range(len(chain)-1):
            mid=(prev[i].co+prev[i+1].co)/2; face_out(bm_,[prev[i],prev[i+1],row[i+1],row[i]],Vector((mid.x,mid.y-yc0,0.0)))
        prev=row
    print("T5 coat skirt ring",len(chain),"verts x",rows,"rows")
tagged(bm,MODL,3,coat_skirt)
def turn_collar(bm_,stand=0.034,fall=0.052,drop=0.040):
    """a TURNED-DOWN collar (Director 2026-10-25: the standing one "looks odd"; a trench's or Dick Tracy's collar lies down): a STAND rising from the
    neckline and hugging the neck, folded at its top into a FALL that lies down and out over the stand and the shoulders, its two ends dipping into
    collar points over the lapels' peaks. The fall is SNAPPED onto the coat it lies on (4-6 mm off it, both ways: only pushed out, its back stood off
    the sloping shoulders like a hood); the stand is lower at the front than at the nape, as a real one is"""
    zc_=zn+0.015; ring=[e for e in bm_.edges if e.is_boundary and all(abs(v.co.z-zc_)<0.004 for v in e.verts)]
    adj={}
    for e in ring:
        a_,b_=e.verts; adj.setdefault(a_,[]).append(b_); adj.setdefault(b_,[]).append(a_)
    ends=[v for v,n in adj.items() if len(n)==1]
    if len(ends)!=2: print("T5 WARNING turn_collar: the neckline is not one open chain",len(ends)); return
    chain=[min(ends,key=lambda v: v.co.x)]
    while True:
        nxt=[w for w in adj[chain[-1]] if w not in chain[-2:]]
        if not nxt: break
        chain.append(nxt[0])
    cyc=sum(v.co.y for v in chain)/len(chain); tree=BVHTree.FromBMesh(bm_); n=len(chain)
    def off(q,gap=0.004):
        loc,nrm,_i,_d=tree.find_nearest(q)
        return q if loc is None else loc+nrm*gap
    rows=[[v for v in chain]]; dirs=[]
    for i,v in enumerate(chain):
        d=Vector((v.co.x,v.co.y-cyc,0.0)).normalized(); dirs.append(d)
    R1=[bm_.verts.new(v.co+Vector((0,0,stand*(0.62+0.38*sstep(-0.6,0.6,dirs[i].y))))-dirs[i]*0.006) for i,v in enumerate(chain)]   # the stand leans in to the neck, lower in front
    RF=[bm_.verts.new(R1[i].co+Vector((0,0,0.004))+dirs[i]*0.008) for i in range(n)]                             # the fold, rounded
    RM=[]; R2=[]
    for i in range(n):
        e_=max(0.0,1.0-min(i,n-1-i)/4.0)                                                                          # the collar points at both ends
        RM.append(bm_.verts.new(off(RF[i].co+dirs[i]*fall*0.45-Vector((0,0,drop*0.35)),0.009)))
        R2.append(bm_.verts.new(off(RF[i].co+dirs[i]*fall+Vector((0,-0.010*e_,0))-Vector((0,0,drop+0.020*e_)),0.005)))
    rows+=[R1,RF,RM,R2]
    for r in range(len(rows)-1):
        for i in range(n-1):
            mid=(rows[r][i].co+rows[r][i+1].co)/2; ref=Vector((mid.x,mid.y-cyc,0.0))+(Vector((0,0,0.6)) if r>=1 else Vector())
            face_out(bm_,[rows[r][i],rows[r][i+1],rows[r+1][i+1],rows[r+1][i]],ref)
tagged(bm,MODL,2,turn_collar); tagged(bm,MODL,1,cuffs,wx+0.02,0.02,1.04)
noisy(bm,0.0030); buttons(bm,[(coat_w(z)+0.030,z) for z in (zc-0.02,zc-0.12,zc-0.22)],0.013)
COATBVH=BVHTree.FromBMesh(bm); BVH["coat"]=COATBVH
lining(bm,0.0025)
print("T5 coat faces per module",{nm:sum(1 for f in bm.faces if f[MODL]==k) for k,nm in enumerate(COAT_MODULES)})
pushed=0
for v in JAC[1].verts:      # wherever the jacket would show THROUGH the coat, sink it under: look back in from 8 cm out along its normal; a coat face met
    c=v.co; n=v.normal      # less than 15 mm out (or behind the vertex) covers it. Where the ray meets no coat (the open front) the jacket stays
    hit,nrm,idx,dist=COATBVH.ray_cast(c+n*0.08,-n,0.16)
    if hit is None or dist<0.08-0.015: continue
    v.co=hit-n*0.018; pushed+=1
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
def hang_weights(o,follow=0.45):
    """a coat's skirt HANGS from the hips: the nearest-body weights glued it to the thighs, so it parted like trousers whenever the legs moved. Below the
    waist the weights ease (over 15 cm) to the pelvis plus a share of each thigh that grows toward the hem (`follow` at the hem): it swings with a stride"""
    gi={g.name:g.index for g in o.vertex_groups}; n=0
    for v in o.data.vertices:
        a=sstep(0.0,0.15,COAT_WAIST-v.co.z)
        if a<=0.0: continue
        k=follow*min(1.0,(COAT_WAIST-v.co.z)/0.58); kl=k*sstep(-0.06,0.06,v.co.x)
        target={"pelvis":1.0-k,"thigh_l":kl,"thigh_r":k-kl}
        old_={o.vertex_groups[g.group].name:g.weight for g in v.groups}
        for name in set(old_)|set(target):
            w=(1.0-a)*old_.get(name,0.0)+a*target.get(name,0.0)
            if name in gi: o.vertex_groups[name].add([v.index],w,'REPLACE')
        n+=1
    return n
print("T5 coat skirt verts re-weighted to hang",hang_weights(pieces[-1]))
def forearm_cuffs(o):
    """the coat's sleeve end follows the FOREARM, as the shirt's cuffs do (weighted to the hand, it swung away from them and the white cuffs came through)"""
    n=0
    for v in o.data.vertices:
        if abs(v.co.x)<=wx-0.04: continue
        for g in v.groups: g.weight=0.0
        o.vertex_groups["lowerarm_l" if v.co.x>0 else "lowerarm_r"].add([v.index],1.0,'REPLACE'); n+=1
    return n
print("T5 coat cuff verts on the forearm",forearm_cuffs(pieces[-1]))
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
# crown with the teardrop crease and two front pinches (what reads as a fedora from the game's camera, 30 degrees above), a rounded top edge, a snap brim.
# v5.2 (Director 2026-10-25: "leave it exactly like Michael Jackson's (Moonwalker), but black"): the proportions of the "Smooth Criminal" fedora as
# photographed for its 2025 auction (Propstore lot 211; 33 x 31 x 12 cm overall): the crown narrows more toward the top (to ~0.70 of its base) and its
# front pinches are deeper, the crease is a teardrop (wider at the back), the BAND is wide (~40% of the crown's height, ours was 21%) with a flat bow on
# the wearer's left, the brim is ~6 cm all round, flat by the crown, dipping at the front and turned up at the back. Ours stays black, as asked.
hx,hy=0.0,-0.003; HZ0,HH,HRX,HRY=1.728,0.114,0.095,0.105     # centre, crown base, crown height, base radii (the head is 15.6 x 17.4 cm at 1.73 m)
BAND_T=0.40; BOW_TH=1.95                                       # the band's top (fraction of the crown's height); the bow's angle (0 = front, + = his left)
def crown_pt(th,t,grow=1.0):
    tap=1.0-0.30*t; pin=1.0-0.24*max(0.0,(t-0.30)/0.70)*(math.exp(-((th-0.62)/0.32)**2)+math.exp(-((th+0.62)/0.32)**2))
    k=tap*pin*grow; return Vector((hx+math.sin(th)*HRX*k,hy-math.cos(th)*HRY*k,HZ0+HH*t))
def fit_crown(seat=0.008,above=0.004):
    """size the crown ON THE HEAD under it (Director 2026-10-25, the defect at the back of the hat: the nape's scalp stood 5 mm past the crown's back
    wall at the band, and the hair pressed inside the crown went under the skin, a band of bare scalp under the brim). The crown is moved to the
    head's own front-to-back centre at the seat, then grown uniformly until the scalp is `seat` inside its wall at the band and `above` inside it
    higher up (room for the hair, pressed thin), the front pinches included. The design proportions stay; only the size follows the head"""
    global hy,HRX,HRY
    o_=Vector((hx,0.0,HZ0+0.012)); fb=[BODYBVH.ray_cast(o_,Vector((0,s_,0)),0.3)[0] for s_ in (1,-1)]
    if all(h_ is not None for h_ in fb): hy=(fb[0].y+fb[1].y)/2
    s_=1.0
    for t in (0.0,0.05,0.12,0.25,0.4,0.55,0.7,0.85,0.95):
        z=HZ0+HH*t; c0=Vector((hx,hy,z)); clr=seat if t<0.15 else above
        for k_ in range(48):
            th=2*math.pi*k_/48; w=crown_pt(th,t)-c0; w.z=0.0; R=w.length
            hit=BODYBVH.ray_cast(c0,w/R,0.3)[0]
            if hit is not None: s_=max(s_,((hit-c0).length+clr)/R)
    HRX*=s_; HRY*=s_
    print("T5 crown fitted to the head: centre y %.4f, base radii %.4f x %.4f (x%.3f)"%(hy,HRX,HRY,s_))
fit_crown()
def crown(bm):
    N=40; ths=[2*math.pi*i/N for i in range(N)]
    rings=[[crown_pt(th,t) for th in ths] for t in (0.0,0.3,0.6,0.86,0.96)]
    rings.append([Vector((p.x*0.955+hx*0.045,hy+(p.y-hy)*0.955,HZ0+HH)) for p in rings[-1]])
    def crease(x,y):             # the teardrop: narrow at the front pinch, wide and deepest toward the back
        w=0.015+0.011*sstep(-0.06,0.07,y-hy); return 0.028*math.exp(-((x-hx)/w)**2)
    for rho in (0.8,0.55,0.3):          # the top: a soft dome with the crease running front to back, deepest in the middle
        rings.append([Vector((hx+(p.x-hx)*rho,hy+(p.y-hy)*rho,HZ0+HH+0.004*(1-rho*rho)-crease(hx+(p.x-hx)*rho,hy+(p.y-hy)*rho)*(1-rho**4))) for p in rings[5]])
    V=[[bm.verts.new(p) for p in r] for r in rings]; c=bm.verts.new(Vector((hx,hy,HZ0+HH+0.004-crease(hx,hy))))
    for a in range(len(V)-1):
        for i in range(N): face_out(bm,[V[a][i],V[a][(i+1)%N],V[a+1][(i+1)%N],V[a+1][i]],(V[a][i].co+V[a+1][i].co)/2-Vector((hx,hy,HZ0+0.03)))
    for i in range(N): face_out(bm,[V[-1][i],V[-1][(i+1)%N],c],Vector((0,0,1)))
def brim(bm,front=0.064,side=0.060):
    N=40; th_=0.005
    def ring(th,k):
        p=crown_pt(th,0.0,0.985); d=Vector((math.sin(th),-math.cos(th),0))
        w=side+(front-side)*abs(math.cos(th)); z=HZ0+0.004+(0.008*abs(math.sin(th))-0.016*max(0.0,math.cos(th))+0.017*max(0.0,-math.cos(th)))*k*k
        return Vector((p.x+d.x*w*k,p.y+d.y*w*k,z))
    ths=[2*math.pi*i/N for i in range(N)]
    ti=[bm.verts.new(ring(t,0.0)+Vector((0,0,th_))) for t in ths]; tm=[bm.verts.new(ring(t,0.55)+Vector((0,0,th_))) for t in ths]; to=[bm.verts.new(ring(t,1.0)+Vector((0,0,th_))) for t in ths]
    bi=[bm.verts.new(ring(t,0.0)) for t in ths]; bmid=[bm.verts.new(ring(t,0.55)) for t in ths]; bo=[bm.verts.new(ring(t,1.0)) for t in ths]
    for i in range(N):
        j=(i+1)%N
        for A,B in ((ti,tm),(tm,to)): face_out(bm,[A[i],A[j],B[j],B[i]],Vector((0,0,1)))
        for A,B in ((bi,bmid),(bmid,bo)): face_out(bm,[A[i],A[j],B[j],B[i]],Vector((0,0,-1)))
        face_out(bm,[to[i],to[j],bo[j],bo[i]],Vector((math.sin(ths[i]),-math.cos(ths[i]),0)))
def band_box(bm,th,t,half_u,half_v,lift,depth):
    """a flat block lying on the band at (th, t): half_u along the band, half_v up it, from `lift` to `lift + depth` off the crown"""
    e=0.02; c=crown_pt(th,t,1.022); u=(crown_pt(th+e,t,1.022)-crown_pt(th-e,t,1.022)).normalized(); v=(crown_pt(th,t+e,1.022)-crown_pt(th,t-e,1.022)).normalized()
    n=u.cross(v).normalized()
    if n.dot(Vector((math.sin(th),-math.cos(th),0)))<0: n=-n
    P=[bm.verts.new(c+u*a*half_u+v*b*half_v+n*(lift+depth*d)) for d in (0,1) for b in (-1,1) for a in (-1,1)]
    for q,ref in (((4,5,7,6),n),((0,1,3,2),-n),((0,1,5,4),-v),((2,3,7,6),v),((0,2,6,4),-u),((1,3,7,5),u)): face_out(bm,[P[k] for k in q],ref)
def band(bm):
    N=40; ths=[2*math.pi*i/N for i in range(N)]
    lo=[bm.verts.new(crown_pt(t,0.0,1.022)+Vector((0,0,0.003))) for t in ths]; hi=[bm.verts.new(crown_pt(t,BAND_T,1.022)) for t in ths]
    for i in range(N): face_out(bm,[lo[i],lo[(i+1)%N],hi[(i+1)%N],hi[i]],Vector((math.sin(ths[i]),-math.cos(ths[i]),0)))
    tm=BAND_T*0.5; ang=0.019/math.hypot(HRX,HRY)*math.sqrt(2)                       # the flat bow: two folded loops either side of a knot
    for side_ in (-1,1): band_box(bm,BOW_TH+side_*ang,tm,0.017,HH*BAND_T*0.40,0.0005,0.0035)
    band_box(bm,BOW_TH,tm,0.0065,HH*BAND_T*0.46,0.0030,0.0035)
pieces.append(prim("Outfit_HatCrown",crown,"Head",BLACK,True)); pieces.append(prim("Outfit_HatBrim",brim,"Head",BLACK,True)); pieces.append(prim("Outfit_HatBand",band,"Head",BAND,True))
# the band: a black grosgrain, a touch glossier than the felt so it still reads as a ribbon (the v5 band was a light grey); a faction packages it (D78)
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
def hair_from_master(path):
    """the Face_Hair of a previous master, unskinned (skin_to_head() skins it again); its material becomes HAIRMAT, so the brows match it"""
    global HAIRMAT
    before=set(bpy.data.objects); snap=snapshot(); bpy.ops.import_scene.gltf(filepath=path); new=list(set(bpy.data.objects)-before)
    h=[o_ for o_ in new if o_.type=='MESH' and o_.name.startswith("Face_Hair")][0]
    mw=h.matrix_world.copy(); h.parent=None
    for m_ in list(h.modifiers): h.modifiers.remove(m_)
    h.data.transform(mw); h.matrix_world=Matrix.Identity(4)
    for g_ in list(h.vertex_groups): h.vertex_groups.remove(g_)
    for o_ in new:
        if o_ is not h: bpy.data.objects.remove(o_,do_unlink=True)
    purge_orphans(snap); h.name="Face_Hair"; HAIRMAT=h.data.materials[0]
    if "Hair_DarkBrown" not in bpy.data.materials: HAIRMAT.name="Hair_DarkBrown"
    return h
if HAIRD or HAIRG:
    hair=cc0_piece("Hair_SimpleParted","Face_Hair") if HAIRD else hair_from_master(HAIRG)
    under=0
    for v in hair.data.vertices:     # the fedora sits ON the hair: what would show through the crown is pressed inside it (the hair stays whole for a hatless look)
        p=v.co
        if HAIRD and p.z>1.75: p.z=1.75+(p.z-1.75)*0.75     # (a master's hair was flattened already)
        if "widows_peak" in FEATURES and p.y<-0.035:            # the hairline dips to a point over the middle of the brow
            p.z-=0.011*math.exp(-(p.x/0.011)**2)*max(0.0,min(1.0,(1.80-p.z)/0.05))*max(0.0,min(1.0,(-0.035-p.y)/0.03))
        if p.z>HAT_Z0-0.035:         # inside the oval crown, 7 mm clear of its wall (the front pinches included)
            k=max(0.0,min(1.0,(p.z-(HAT_Z0-0.035))/0.035)); t=max(0.0,min(1.0,(p.z-HZ0)/HH))
            th=math.atan2(p.x-hx,-(p.y-hy)); w=crown_pt(th,t)-Vector((hx,hy,0)); R=Vector((w.x,w.y,0)).length-0.007
            d=Vector((p.x-hx,p.y-hy,0)); r=d.length
            if r>R: p.x,p.y=hx+(d.x/r)*(r+(R-r)*k),hy+(d.y/r)*(r+(R-r)*k)
        loc,nrm,_i,_d=BODYBVH.find_nearest(p)      # NEVER under the skin (v5 pressed 279 of 757 hair vertices into the scalp: the bare patches at the nape and
        if loc is not None and (p-loc).dot(nrm)<0.002: v.co=loc+nrm*0.002; under+=1     # on top, under the hat and without it); fit_crown() left the room
    print("T5 hair vertices lifted out of the scalp",under,"of",len(hair.data.vertices))
    if os.environ.get("HAIR_CUT","short")=="short":      # SHORT (Director 2026-10-25: "a spy would not leave a liability", nothing to grab): the hair lies
        for v in hair.data.vertices:                      # close to the scalp, a little longer on top, clipped at the sides and the nape
            loc,nrm,_i,_d=BODYBVH.find_nearest(v.co)
            if loc is None: continue
            top=sstep(1.74,1.79,v.co.z)*sstep(0.06,0.00,v.co.y)
            v.co=loc+nrm*max(0.0012,min((v.co-loc).dot(nrm),0.0025+0.0030*top))
        hb=bmesh.new(); hb.from_mesh(hair.data)               # the nape and the sides clipped high: the hairline at the back above the collar, none below the ear
        cut=[f for f in hb.faces if (f.calc_center_median().z<1.690 and f.calc_center_median().y>0.035) or (f.calc_center_median().z<1.675 and abs(f.calc_center_median().x)>0.060)]
        bmesh.ops.delete(hb,geom=cut,context='FACES'); sweep(hb)
        smooth_boundary(hb,lambda c: c.z<1.705,iters=8)              # a clean hairline, not the sawtooth of the deleted faces
        hb.to_mesh(hair.data); hb.free(); print("T5 short cut: hair faces clipped",len(cut))
    if GREY>0.0 or "grey_streak" in FEATURES:         # SALT-AND-PEPPER all over, whiter at the temples and over the ears (Director: "semi-grisalho", never all white); the hair's
                         # OWN copy (the brows share HAIRMAT). The lighter strands of the texture go grey first: that is the salt, with no noise
        nt_=HAIRMAT.node_tree; src_=[n for n in nt_.nodes if n.type=='TEX_IMAGE'][0].image; W_,H_=src_.size
        px_=np.empty(W_*H_*4,dtype=np.float32); src_.pixels.foreach_get(px_); himg=px_.reshape(H_,W_,4)[...,:3].astype(np.float64)
        HP=texel_positions(hair,W_,H_,lambda c: True); hok=~np.isnan(HP[...,0]); HQ=np.where(hok[...,None],HP,0.0)
        g=np.clip((np.abs(HQ[...,0])-0.048)/0.022,0,1)*np.clip((1.775-HQ[...,2])/0.035,0,1)
        lum=himg.mean(axis=2,keepdims=True)/0.15
        strand=np.clip((lum[...,0]-0.7)/0.6,0,1)                           # the texture's own light strands (a per-texel random salt read as a sponge)
        g=np.clip(GREY*(0.30+0.45*strand+0.45*g),0,0.9)*hok
        if "grey_streak" in FEATURES:                            # one pale forelock, off the parting on his left, from the hairline back
            st=np.exp(-((HQ[...,0]-0.024)/0.010)**2)*np.clip((-0.012-HQ[...,1])/0.035,0,1)*(HQ[...,2]>1.72)   # (front only: to the crown it read as a stripe)
            g=np.maximum(g,0.88*st)*hok
        himg=himg*(1-g[...,None])+g[...,None]*np.clip(lum,0.6,1.4)*np.array((0.46,0.45,0.43))
        HAIRMAT_AGED=tmat("Hair_Aged",image("Hair_Aged",np.clip(himg,0,1)),0.7); hair.data.materials.clear(); hair.data.materials.append(HAIRMAT_AGED)
        gm=float(g[hok].mean()); bimg=px_.reshape(H_,W_,4)[...,:3].astype(np.float64)                # the BROWS match the hair: their own copy, greyed by the
        blum=bimg.mean(axis=2,keepdims=True)/0.15                                                      # hair's mean (their UVs are not the hair's: no per-texel mask)
        bimg=bimg*(1-gm)+gm*np.clip(blum,0.6,1.4)*np.array((0.46,0.45,0.43))
        BROWMAT=tmat("Brow_Aged",image("Brow_Aged",np.clip(bimg,0,1)),0.7)
        print("T5 hair greyed texels",int((g>0.05).sum()),"of",int(hok.sum()))
    pieces.append(skin_to_head(hair))
    brows=bpy.data.objects.get("Eyebrows")
    if brows: brows.data.materials.clear(); brows.data.materials.append(BROWMAT if GREY>0.0 else HAIRMAT)   # the pack's brows were drawn white-grey

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
if os.environ.get("BEARD","0")!="0":      # Director 2026-10-21: no beard for now (BEARD=1 grows it)
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
o,bm=blank("Mask_Face"); keep_groups(bm,region("Head","neck_","spine_","clavicle_"))   # D77 revised: the v4 HARD-SURFACE look (the Director preferred it). The game
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)>0.085 and f.calc_center_median().z<1.60],context='FACES'); sweep(bm)
def shell_floor(y): return 1.592+(1.535-1.592)*sstep(-0.05,0.035,y)             # swaps the hat's look as it is pulled down, so the mask need not be shaped like it
bm.faces.ensure_lookup_table(); bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().z<shell_floor(f.calc_center_median().y)],context='FACES'); sweep(bm)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=40)
displace(bm,lambda v: 0.016 if v.co.y<0.0 or v.co.z>1.64 else 0.008)            # the whole head now (no hat on top), hugging the nape (no hood)
SHELLBVH=BVHTree.FromBMesh(bm); BANDBVH=SHELLBVH
pieces.append(finish(o,bm,MASKBLACK,facet=0.12))
o,bm=blank("Mask_Jaw"); keep_groups(bm,region("Head","neck_"))
plane(bm,(0,0,1.632),(0,0,1),outer=True); plane(bm,(0,0,1.511),(0,0,1),inner=True); plane(bm,(0,0.045,0),(0,1,0),outer=True)
displace(bm,0.021); pieces.append(finish(o,bm,MASKBLACK,facet=0.10))
def eye_lenses(bm):       # slanted amber slits IN the band, narrowest at the nose; 8 segments, each on the band (one flat quad sank into its curve)
    for s_ in (1,-1):
        lo=[];hi=[]
        for k in range(9):
            t=k/8.0; x=0.011+0.046*t; zc_=1.6950+0.0072*t; hh=0.0028+0.0012*math.sin(t*math.pi)
            lo.append(bm.verts.new(on_surface(BANDBVH,s_*x,zc_-hh,0.0045)[0])); hi.append(bm.verts.new(on_surface(BANDBVH,s_*x,zc_+hh,0.0045)[0]))
        for k in range(8): face_out(bm,[lo[k],lo[k+1],hi[k+1],hi[k]],Vector((0,-1,0)))
def eye_halos(bm):        # a soft additive glow around each lens (the engine draws it; UVs run 0..1)
    uvl=bm.loops.layers.uv.verify()
    for s_ in (1,-1):
        c=(s_*0.034,1.6985); hw_,hh=0.060,0.030
        P=[on_surface(SHELLBVH,x,z,0.011)[0] for x,z in ((c[0]-hw_,c[1]-hh),(c[0]+hw_,c[1]-hh),(c[0]+hw_,c[1]+hh),(c[0]-hw_,c[1]+hh))]
        f=face_out(bm,[bm.verts.new(p) for p in P],Vector((0,-1,0)))
        for l_ in f.loops: l_[uvl].uv=(0.5+(l_.vert.co.x-c[0])/(2*hw_),0.5+(l_.vert.co.z-c[1])/(2*hh))
pieces.append(prim("Mask_Eyes",eye_lenses,"Head",EYEGLOW)); pieces.append(prim("Mask_Halo",eye_halos,"Head",HALO))
MASKSET=["Mask_Face","Mask_Jaw","Mask_Eyes","Mask_Halo"]; FACEHAIR=["Face_Hair","Face_Beard"]
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
def coat_seam_group(o):
    """the vertices where two modules meet: the LOD keeps them (Decimate with this group inverted leaves every one in place), so the split modules
    still share their seams exactly"""
    me=o.data; mod=[a.value for a in me.attributes["mod"].data]; owner={}
    for p in me.polygons:
        for vi in p.vertices: owner.setdefault(vi,set()).add(mod[p.index])
    vg=o.vertex_groups.new(name="coat_seam"); vg.add([vi for vi,s in owner.items() if len(s)>1],1.0,'REPLACE'); return vg
if DEC<1.0:
    for o in [o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.polygons)>150]:
        bpy.context.view_layer.objects.active=o; m=o.modifiers.new("Decimate",'DECIMATE'); m.ratio=DEC*LOD_WEIGHT.get(o.name,1.0)
        if o.name=="Outfit_Coat": m.vertex_group=coat_seam_group(o).name; m.invert_vertex_group=True
        bpy.ops.object.modifier_apply(modifier="Decimate")
def split_coat(o):
    """one mesh per module (Outfit_Coat_<Module>), each keeping the whole coat's weights and its shading at the seams (the corner normals are frozen
    as custom normals first, or every seam would show as a crease)"""
    me=o.data; me.normals_split_custom_set([tuple(cn.vector) for cn in me.corner_normals]); out=[]
    for k,nm in enumerate(COAT_MODULES):
        c=o.copy(); c.data=me.copy(); c.name="Outfit_Coat_"+nm; c.data.name=c.name; bpy.context.scene.collection.objects.link(c)
        if "coat_seam" in c.vertex_groups: c.vertex_groups.remove(c.vertex_groups["coat_seam"])
        b=bmesh.new(); b.from_mesh(c.data); L=b.faces.layers.int["mod"]
        bmesh.ops.delete(b,geom=[f for f in b.faces if f[L]!=k],context='FACES'); sweep(b); b.to_mesh(c.data); b.free()
        c.data.attributes.remove(c.data.attributes["mod"]); out.append(c.name)
        f0=len(c.data.polygons)
        if c.data.validate(clean_customdata=False): print("T5 coat module",c.name,"cleaned: faces",f0,"->",len(c.data.polygons))   # the LOD's collapse can fold the lining onto the cloth (duplicate faces)
    bpy.data.objects.remove(o,do_unlink=True); return out
COATSET=split_coat(bpy.data.objects["Outfit_Coat"])
arm.data.pose_position='POSE'
tot=0
for o in bpy.context.scene.objects:
    if o.type=='MESH': n=sum(len(p.vertices)-2 for p in o.data.polygons); tot+=n; print("T5 piece",o.name,n)
print("T5 TOTAL tris",tot,"meshes",sum(1 for o in bpy.context.scene.objects if o.type=='MESH'))
TRIS={o.name:sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'}
for st_,hid in (("normal",["Outfit_Gloves"]+MASKSET),("black",COATSET+MASKSET),("mask",COATSET+HATUP+FACEHAIR)):
    print("T5 visible tris",st_,sum(n for k,n in TRIS.items() if k not in hid),"(shaved",sum(n for k,n in TRIS.items() if k not in hid+["Face_Beard"]),")")
bpy.ops.export_scene.gltf(filepath=OUTD+f"hero{SUF}.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)

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
        hide={"normal":["Outfit_Gloves"]+MASKSET,"black":COATSET+MASKSET,"mask":COATSET+["Mask_Halo"]+HATUP+FACEHAIR}[name]
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
