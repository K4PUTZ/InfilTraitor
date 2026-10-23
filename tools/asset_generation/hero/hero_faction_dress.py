# hero_faction_dress.py — the D78 decision renders (ACTOR_MASTER_PLAN D78, COSMETICS_MASTER_PLAN §9): the hero v5 master (hero_tailor5.glb) dressed
# per faction as PACKAGING on the same dress, and the field officers' overcoats seen from behind (what the LED coat imitates, DESIGN §10.5).
# A Blender EEVEE mock of the look, not the engine's shaders: it proves colour, placement and readability at the game's size, not runtime cost.
# What changes per faction (the accent zones of D78, done here by material swaps): hatband, regimental tie, coat lining, pocket square, an armband
# on the left upper arm, a lapel pin, and the mark of his past (COSMETICS §9.3): FID star pin, Calm Waters access card, Bunsen Burners wallet chain
# and orange bandana, the Corporation's coiled earpiece. The coat itself stays the FID investigators' mustard (DESIGN §2.1). Officers: the same coat
# silhouette tinted to the faction (faction_palette.json "officer_coat"), bands at the yoke / cuffs / hem, a roundel on the back, no fedora.
# Inputs: faction_palette.json; textures from faction_dress_art.py (run "textures" first, into the same folder).
# Env: HERO_REPO (repo root, trailing /), FD_OUT (render + texture folder), FD_ONLY (e.g. "FID,CWS"), FD_PARTS ("agent,officer"), FD_SAMPLES (32).
# Usage: blender -b -P hero_faction_dress.py      then: python3 faction_dress_art.py sheets <FD_OUT>
# ⚠️ Traps: +x is the WEARER's left and the front faces -y (hero_tailor's convention). The coat's lining is an inward duplicate (hero_tailor's lining()),
# not stored as a separate surface, so it is found here by normal direction; a face classified wrongly shows up as a stray coloured patch.
# "Generated" texture coordinates are the UNDEFORMED mesh's box, so officer bands and the back roundel follow the posed coat. Colours are sRGB in the
# JSON and linear in the nodes (to_lin). The view transform is Standard, so a hex renders as itself (AgX would desaturate the palette under judgement).
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

REPO = os.environ.get("HERO_REPO", "")
HERE = REPO + "tools/asset_generation/hero/"
OUT = os.environ.get("FD_OUT", "/tmp/fd/")
OUT = OUT if OUT.endswith("/") else OUT + "/"
PAL = json.load(open(HERE + "faction_palette.json"))
ONLY = [s for s in os.environ.get("FD_ONLY", "").split(",") if s] or PAL["order"]
PARTS = os.environ.get("FD_PARTS", "agent,officer").split(",")
GLB = REPO + "ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/hero_tailor5.glb"


def to_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
arm = [o for o in sc.objects if o.type == 'ARMATURE'][0]
ad = arm.animation_data
for t in ad.nla_tracks:
    t.mute = True
for nm in ("Icosphere", "Outfit_Gloves", "Mask_Face", "Mask_Jaw", "Mask_Eyes", "Mask_Halo"):
    o = bpy.data.objects.get(nm)
    if o:
        o.hide_render = True
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
AINV = arm.matrix_world.inverted()


def mat(name, col, rough=0.6, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = to_lin(col) if isinstance(col, str) else col
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def set_col(m, col):
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = to_lin(col)


def tex_mat(name, path, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path)
    nt.links.new(t.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = rough
    return m, t


def world_bvh(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    ev.to_mesh_clear()
    return tree, bm


def skinned(name, bm, bone, material):
    """a new mesh from world-space bmesh, parented to the armature and bound rigidly to one bone"""
    bm.transform(AINV)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    sc.collection.objects.link(o)
    o.parent = arm
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
    md = o.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    me.materials.append(material)
    return o


# ---------------- surfaces that already exist: hatband, tie, pocket square, coat lining ----------------
HATBAND = bpy.data.materials["Hat_Band"]
TIE = bpy.data.materials["Tie_Silk"]
TIE_TEX = [n for n in TIE.node_tree.nodes if n.type == 'TEX_IMAGE'][0]
STOCK_TIE = TIE_TEX.image
trim = bpy.data.objects["Outfit_ShirtTrim"]
POCKET = mat("FD_Pocket", "#F2F2F2", 0.8)
trim.data.materials.append(POCKET)
pi = len(trim.data.materials) - 1
pocket_faces = [p for p in trim.data.polygons if 0.09 < p.center.x < 0.14 and p.center.y < -0.03]
for p in pocket_faces:
    p.material_index = pi
print("[FD] pocket faces", len(pocket_faces))

coat = bpy.data.objects["Outfit_Coat"]
CM = coat.data
COAT_STOCK = CM.materials[0]
LINING = mat("FD_Lining", "#2E6FD8", 0.7)
CM.materials.append(LINING)
li = len(CM.materials) - 1
nl = 0
for p in CM.polygons:
    c, n = p.center, p.normal
    if abs(c.x) < 0.30:
        r = Vector((c.x, c.y - 0.04, 0.0))
        nn = Vector((n.x, n.y, 0.0))
    else:
        r = Vector((0.0, c.y - 0.069, c.z - 1.456))
        nn = Vector((0.0, n.y, n.z))
    if r.length > 1e-4 and nn.length > 0.2 and nn.normalized().dot(r.normalized()) < -0.25:
        p.material_index = li
        nl += 1
print("[FD] coat faces", len(CM.polygons), "lining", nl)

# the coat's bounding box in its own (rest) space, for the officer shader's Generated coordinates
xs = [v.co.x for v in CM.vertices]; ys = [v.co.y for v in CM.vertices]; zs = [v.co.z for v in CM.vertices]
BB = (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))
print("[FD] coat bbox", [round(v, 3) for v in BB])

# ---------------- new pieces ----------------
coat_tree, coat_bm = world_bvh(coat)


def on_coat(x, z, depth=0.003):
    hit, nrm, _, _ = coat_tree.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)))
    if hit is None or hit.y > 0.0:
        print(f"[FD] WARNING no front coat hit at x={x} z={z}")
        return Vector((x, -0.13, z)), Vector((0, -1, 0))
    if nrm.y > 0:
        nrm = -nrm
    return hit + nrm * depth, nrm


def frame(n):
    """an orthonormal basis whose +z is n (the surface normal) and +y points up the body"""
    zt = n.normalized()
    up = Vector((0, 0, 1))
    xt = up.cross(zt).normalized()
    yt = zt.cross(xt).normalized()
    return xt, yt, zt


# armband: a ring around the left upper arm over the sleeve, UV'd so the emblem stands upright with the arm hanging
hb, tb = arm.data.bones["upperarm_l"].head_local, arm.data.bones["upperarm_l"].tail_local
P0 = arm.matrix_world @ (hb + (tb - hb) * 0.47)
ax = Vector((P0.x, 0, 0))
cy, cz = P0.y, P0.z
rads = sorted(r for r in (math.hypot(v.co.y - cy, v.co.z - cz) for v in coat_bm.verts if abs(v.co.x - P0.x) < 0.02) if r < 0.085)   # the sleeve only, not the torso panels that reach this x
R = rads[int(len(rads) * 0.92)] + 0.003 if rads else 0.06
print("[FD] armband centre", tuple(round(v, 3) for v in P0), "radius", round(R, 3))
bm = bmesh.new()
uvl = bm.loops.layers.uv.new()
N = 40
W = 0.075
ring = []
for i in range(N + 1):
    a = 2 * math.pi * i / N
    ring.append([bm.verts.new((P0.x - W / 2 + W * j, cy + R * math.cos(a), cz + R * math.sin(a))) for j in (0, 1)])
for i in range(N):
    f = bm.faces.new((ring[i][0], ring[i + 1][0], ring[i + 1][1], ring[i][1]))
    for l, (ii, jj) in zip(f.loops, ((i, 0), (i + 1, 0), (i + 1, 1), (i, 1))):
        l[uvl].uv = (1.0 - ii / N, 1.0 - jj)          # u mirrored, v = 1 at the shoulder: upright and readable from outside the hanging arm
bm.normal_update()
for f in bm.faces:
    c = f.calc_center_median()
    if f.normal.dot(Vector((0, c.y - cy, c.z - cz))) < 0:
        f.normal_flip()
ARMBAND, ARM_TEX = tex_mat("FD_Armband", OUT + "arm_FID.png", 0.6)
ARMOBJ = skinned("FD_Armband", bm, "upperarm_l", ARMBAND)

# lapel pins: a star (FID) and a round enamel pin (the others), on the left lapel
pin_p, pin_n = on_coat(0.135, 1.42)
xt, yt, zt = frame(pin_n)
PIN_METAL = mat("FD_PinMetal", "#C9CED6", 0.35, 0.45)     # half metallic: a full metal renders black in EEVEE against this plain world
PIN_ENAMEL = mat("FD_PinEnamel", "#2E6FD8", 0.35)
bm = bmesh.new()
pts = []
for k in range(10):
    r = 0.016 if k % 2 == 0 else 0.0068
    a = k * math.pi / 5
    pts.append(pin_p + xt * (r * math.sin(a)) + yt * (r * math.cos(a)))
top = [bm.verts.new(p + zt * 0.002) for p in pts]
bot = [bm.verts.new(p) for p in pts]
bm.faces.new(top)
for i in range(10):
    bm.faces.new((bot[i], bot[(i + 1) % 10], top[(i + 1) % 10], top[i]))
STAR = skinned("FD_StarPin", bm, "spine_03", PIN_METAL)
bm = bmesh.new()
for r, h, m in ((0.0105, 0.0022, 0), (0.0082, 0.0030, 1)):
    ring_v = [bm.verts.new(pin_p + xt * (r * math.cos(2 * math.pi * k / 24)) + yt * (r * math.sin(2 * math.pi * k / 24)) + zt * h) for k in range(24)]
    f = bm.faces.new(ring_v)
    f.material_index = m
ROUND = skinned("FD_RoundPin", bm, "spine_03", PIN_METAL)
ROUND.data.materials.append(PIN_ENAMEL)

# Calm Waters: an access card on a reel, clipped to the left breast under the pin
card_p, card_n = on_coat(0.125, 1.30, 0.004)
xt, yt, zt = frame(card_n)
CARD = mat("FD_Card", "#F2F2F2", 0.4)
CARD_STRIPE = mat("FD_CardStripe", "#B3121E", 0.4)
bm = bmesh.new()
for (w, h0, h1, mi) in ((0.026, -0.085, 0.0, 0), (0.026, -0.018, 0.0, 1)):
    q = [bm.verts.new(card_p + xt * x + yt * y + zt * (0.0015 if mi else 0.001)) for x, y in ((-w, h0), (w, h0), (w, h1), (-w, h1))]
    bm.faces.new(q).material_index = mi
CARDOBJ = skinned("FD_Card", bm, "spine_03", CARD)
CARDOBJ.data.materials.append(CARD_STRIPE)

# Bunsen Burners: a wallet chain from the belt at the front-left hip, sagging to the side
CHAIN_M = mat("FD_Chain", "#9A968E", 0.35, 0.45)
cu = bpy.data.curves.new("FD_ChainCurve", 'CURVE')
cu.dimensions = '3D'
cu.bevel_depth = 0.0035
cu.bevel_resolution = 2
sp = cu.splines.new('BEZIER')
sp.bezier_points.add(2)
for bp, co in zip(sp.bezier_points, ((0.075, -0.112, 0.985), (0.125, -0.105, 0.885), (0.168, -0.045, 0.955))):
    bp.co = co
    bp.handle_left_type = bp.handle_right_type = 'AUTO'
co_ = bpy.data.objects.new("FD_ChainTmp", cu)
sc.collection.objects.link(co_)
dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(co_.evaluated_get(dg))
bpy.data.objects.remove(co_)
bm = bmesh.new()
bm.from_mesh(me)
CHAIN = skinned("FD_Chain", bm, "pelvis", CHAIN_M)

# the Corporation: a coiled earpiece from the right ear (-x) down into the collar
EAR_M = mat("FD_Earpiece", "#D9D2C3", 0.35)
cu = bpy.data.curves.new("FD_EarCurve", 'CURVE')
cu.dimensions = '3D'
cu.bevel_depth = 0.0011
sp = cu.splines.new('POLY')
A, B = Vector((-0.086, 0.004, 1.690)), Vector((-0.070, 0.050, 1.545))
axis = (B - A).normalized()
u1 = axis.cross(Vector((1, 0, 0))).normalized()
u2 = axis.cross(u1).normalized()
pts = []
steps = 220
for k in range(steps + 1):
    t = k / steps
    a = t * 2 * math.pi * 16
    rr = 0.0035 if 0.12 < t < 0.95 else 0.0008
    pts.append(A + (B - A) * t + u1 * (rr * math.cos(a)) + u2 * (rr * math.sin(a)))
sp.points.add(len(pts) - 1)
for p, co in zip(sp.points, pts):
    p.co = (co.x, co.y, co.z, 1.0)
co_ = bpy.data.objects.new("FD_EarTmp", cu)
sc.collection.objects.link(co_)
dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(co_.evaluated_get(dg))
bpy.data.objects.remove(co_)
bm = bmesh.new()
bm.from_mesh(me)
EAR = skinned("FD_Earpiece", bm, "Head", EAR_M)
coat_bm.free()

SIGNATURE = {"FID": [STAR], "CWS": [ROUND, CARDOBJ], "BBM": [ROUND, CHAIN], "CORP": [ROUND, EAR]}
ACCESSORIES = [ARMOBJ, STAR, ROUND, CARDOBJ, CHAIN, EAR]


# ---------------- the officers' coat material: the coat's weave tinted, bands, the back roundel ----------------
def officer_material():
    m = bpy.data.materials.new("FD_OfficerCoat")
    m.use_nodes = True
    nt = m.node_tree
    N_, L = nt.nodes, nt.links
    bsdf = N_["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.75
    weave = N_.new("ShaderNodeTexImage")
    weave.image = [n for n in COAT_STOCK.node_tree.nodes if n.type == 'TEX_IMAGE'][0].image
    px = list(weave.image.pixels)
    lum = sum(0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2] for i in range(0, len(px), 4)) / (len(px) / 4)
    bw = N_.new("ShaderNodeRGBToBW"); L.new(weave.outputs["Color"], bw.inputs[0])
    nrm = N_.new("ShaderNodeMath"); nrm.operation = 'MULTIPLY'; nrm.inputs[1].default_value = 1.0 / max(lum, 1e-3); L.new(bw.outputs[0], nrm.inputs[0])
    base = N_.new("ShaderNodeRGB"); base.name = "base"
    tint = N_.new("ShaderNodeMix"); tint.data_type = 'RGBA'; tint.blend_type = 'MULTIPLY'; tint.inputs[0].default_value = 1.0
    L.new(base.outputs[0], tint.inputs[6]); L.new(nrm.outputs[0], tint.inputs[7])
    use_stock = N_.new("ShaderNodeMix"); use_stock.data_type = 'RGBA'; use_stock.name = "use_stock"
    L.new(tint.outputs[2], use_stock.inputs[6]); L.new(weave.outputs["Color"], use_stock.inputs[7])
    tc = N_.new("ShaderNodeTexCoord"); sep = N_.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Generated"], sep.inputs[0])
    x0, x1, y0, y1, z0, z1 = BB

    def metres(axis_out, lo, hi):
        m_ = N_.new("ShaderNodeMapRange"); m_.inputs[3].default_value = lo; m_.inputs[4].default_value = hi; m_.clamp = False
        L.new(sep.outputs[axis_out], m_.inputs[0]); return m_.outputs[0]

    X, Y, Z = metres(0, x0, x1), metres(1, y0, y1), metres(2, z0, z1)

    def cmp(src, op, val):
        n_ = N_.new("ShaderNodeMath"); n_.operation = op; L.new(src, n_.inputs[0]); n_.inputs[1].default_value = val; return n_.outputs[0]

    def mul(a, b):
        n_ = N_.new("ShaderNodeMath"); n_.operation = 'MULTIPLY'; L.new(a, n_.inputs[0]); L.new(b, n_.inputs[1]); return n_.outputs[0]

    def add(a, b):
        n_ = N_.new("ShaderNodeMath"); n_.operation = 'ADD'; n_.use_clamp = True; L.new(a, n_.inputs[0]); L.new(b, n_.inputs[1]); return n_.outputs[0]

    absx = N_.new("ShaderNodeMath"); absx.operation = 'ABSOLUTE'; L.new(X, absx.inputs[0])
    yoke = mul(mul(cmp(Z, 'GREATER_THAN', 1.375), cmp(Z, 'LESS_THAN', 1.425)), cmp(absx.outputs[0], 'LESS_THAN', 0.26))
    cuff = cmp(absx.outputs[0], 'GREATER_THAN', 0.60)
    band_mask = add(yoke, cuff)
    hem_mask = cmp(Z, 'LESS_THAN', z0 + 0.06)
    band = N_.new("ShaderNodeRGB"); band.name = "band"
    hem = N_.new("ShaderNodeRGB"); hem.name = "hem"
    m1 = N_.new("ShaderNodeMix"); m1.data_type = 'RGBA'; L.new(band_mask, m1.inputs[0]); L.new(use_stock.outputs[2], m1.inputs[6]); L.new(band.outputs[0], m1.inputs[7])
    m2 = N_.new("ShaderNodeMix"); m2.data_type = 'RGBA'; L.new(hem_mask, m2.inputs[0]); L.new(m1.outputs[2], m2.inputs[6]); L.new(hem.outputs[0], m2.inputs[7])
    # the back roundel: projected from behind (u runs toward the wearer's right = the viewer's right from behind), only on the back of the coat
    S, ZC = 0.27, 1.27
    nx = N_.new("ShaderNodeMath"); nx.operation = 'MULTIPLY'; L.new(X, nx.inputs[0]); nx.inputs[1].default_value = -1.0 / S
    u = cmp(nx.outputs[0], 'ADD', 0.5)
    zz = cmp(Z, 'SUBTRACT', ZC)
    v = cmp(cmp(zz, 'MULTIPLY', 1.0 / S), 'ADD', 0.5)
    comb = N_.new("ShaderNodeCombineXYZ"); L.new(u, comb.inputs[0]); L.new(v, comb.inputs[1])
    rnd = N_.new("ShaderNodeTexImage"); rnd.name = "roundel"; rnd.extension = 'CLIP'
    rnd.image = bpy.data.images.load(OUT + "back_FID.png")
    L.new(comb.outputs[0], rnd.inputs[0])
    back = mul(rnd.outputs["Alpha"], cmp(Y, 'GREATER_THAN', 0.12))
    m3 = N_.new("ShaderNodeMix"); m3.data_type = 'RGBA'; L.new(back, m3.inputs[0]); L.new(m2.outputs[2], m3.inputs[6]); L.new(rnd.outputs["Color"], m3.inputs[7])
    L.new(m3.outputs[2], bsdf.inputs["Base Color"])
    return m


OFFICER = officer_material()


def set_officer(f):
    o = f["officer_coat"]
    nt = OFFICER.node_tree.nodes
    stock = o["base"] == "mustard"
    nt["use_stock"].inputs[0].default_value = 1.0 if stock else 0.0
    nt["base"].outputs[0].default_value = to_lin("#808080" if stock else o["base"])
    nt["band"].outputs[0].default_value = to_lin(o["band"])
    nt["hem"].outputs[0].default_value = to_lin(o["hem"])
    nt["roundel"].image = bpy.data.images.load(OUT + f"back_{fk}.png", check_existing=True)


# ---------------- scene, camera, renders ----------------
arm.data.pose_position = 'POSE'
ad.action = bpy.data.actions["Idle_Loop"]
ad.action_slot = ad.action.slots[0]
sc.frame_set(20)
sc.render.engine = 'BLENDER_EEVEE'
try:
    sc.eevee.taa_render_samples = int(os.environ.get("FD_SAMPLES", "32"))
except AttributeError:
    pass
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
w_ = bpy.data.worlds.new("w"); sc.world = w_; w_.use_nodes = True
w_.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.31, 0.34, 1)
for nm_, en, rot in (("key", 3.2, (50, 0, -35)), ("fill", 1.0, (60, 0, 140)), ("rim", 1.6, (70, 0, 200))):
    Lt = bpy.data.lights.new(nm_, 'SUN'); Lt.energy = en
    lo = bpy.data.objects.new(nm_, Lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(a) for a in rot]
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co


def shot(path, az_deg, el_deg, ortho, ctr, res):
    sc.render.resolution_x, sc.render.resolution_y = res
    az, el, d = math.radians(az_deg), math.radians(el_deg), 10
    cam.ortho_scale = ortho
    co.location = ctr + Vector((d * math.cos(el) * math.sin(az), -d * math.cos(el) * math.cos(az), d * math.sin(el)))
    co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[FD] wrote", path)


HAT = [bpy.data.objects[n] for n in ("Outfit_HatCrown", "Outfit_HatBrim", "Outfit_HatBand")]
HAIR = bpy.data.objects.get("Face_Hair")     # pressed flat under the fedora: the hatless officers go without it
for fk in ONLY:
    f = PAL["factions"][fk]
    set_col(HATBAND, f["hatband"])
    set_col(LINING, f["lining"])
    set_col(POCKET, f["pocket"])
    set_col(PIN_METAL, f["metal"])
    set_col(PIN_ENAMEL, f["hatband"])
    TIE_TEX.image = bpy.data.images.load(OUT + f"tie_{fk}.png", check_existing=True)
    ARM_TEX.image = bpy.data.images.load(OUT + f"arm_{fk}.png", check_existing=True)
    if "agent" in PARTS:
        CM.materials[0] = COAT_STOCK
        for o in HAT + ([HAIR] if HAIR else []):
            o.hide_render = False
        for o in ACCESSORIES:
            o.hide_render = not (o is ARMOBJ or o in SIGNATURE[fk])
        shot(OUT + f"agent_{fk}_portrait.png", 30, 8, 2.45, Vector((0, 0, 1.02)), (600, 860))   # ~140 px clear above the hat for the banner's two lines
        shot(OUT + f"agent_{fk}_detail.png", 28, 6, 0.78, Vector((0.05, -0.04, 1.40)), (600, 600))
        shot(OUT + f"agent_{fk}_game.png", 45, 30, 2.1, Vector((0, 0, 0.9)), (132, 200))
    if "officer" in PARTS:
        set_officer(f)
        CM.materials[0] = OFFICER
        set_col(LINING, f["officer_coat"]["band"])
        for o in HAT + ([HAIR] if HAIR else []):
            o.hide_render = True
        for o in ACCESSORIES:
            o.hide_render = True
        shot(OUT + f"officer_{fk}_back.png", 205, 8, 2.15, Vector((0, 0, 0.92)), (600, 860))
        shot(OUT + f"officer_{fk}_game.png", 225, 30, 2.1, Vector((0, 0, 0.9)), (132, 200))
    if "uniform" in PARTS:      # the Agent in that faction's officer coat (DESIGN §2.2: the uniform he wears; his fedora stays, the armband follows the coat)
        set_officer(f)
        CM.materials[0] = OFFICER
        set_col(LINING, f["officer_coat"]["band"])
        for o in HAT + ([HAIR] if HAIR else []):
            o.hide_render = False
        for o in ACCESSORIES:
            o.hide_render = o is not ARMOBJ
        shot(OUT + f"uniform_{fk}_portrait.png", 30, 8, 2.15, Vector((0, 0, 0.92)), (600, 860))
        shot(OUT + f"uniform_{fk}_back.png", 205, 8, 2.15, Vector((0, 0, 0.92)), (600, 860))
        shot(OUT + f"uniform_{fk}_game.png", 45, 30, 2.1, Vector((0, 0, 0.9)), (132, 200))
print("[FD] done", ONLY, PARTS)
