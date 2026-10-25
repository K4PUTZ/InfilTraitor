# hero_review.py — review renders of one hero GLB (EEVEE, the 2026-10-24/25 sessions' views; ACTOR D79-D82). A Blender mock, not the engine's shaders.
# Parts (RV_PARTS, comma list): figure (normal style, Idle_Loop f20, four views) · game (132x200 at the game camera, walking) · coat (the coat alone) ·
# modules (the coat's four modules coloured, then exploded) · coatrest (the coat in rest pose) · dummy (the tailor's dummy, if built with KEEP_DUMMY=1) ·
# face (rest pose: front, 3/4, profile and with the fedora; near/far planes keep the skin mesh's hands out) · collar (neck and shoulders, close) ·
# nape (the back of the head under the hat, idle and rest).
# RV_LOOK=infil|inv mocks D82's two looks by material swaps (only meaningful on a build that carries Coat_Lining / Tie_Matte, the parked WIP).
# Env: RV_GLB, RV_OUT (folder), RV_TAG (file prefix), RV_PARTS, RV_SAMPLES (48), RV_LOOK.  Usage: blender -b -P hero_review.py
import bpy, math, os
import numpy as np
from mathutils import Vector

GLB = os.environ["RV_GLB"]; OUT = os.environ["RV_OUT"].rstrip("/") + "/"; TAG = os.environ.get("RV_TAG", "x")
PARTS = os.environ.get("RV_PARTS", "figure,game,coat").split(",")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
arm = [o for o in sc.objects if o.type == 'ARMATURE'][0]
ad = arm.animation_data
for t in ad.nla_tracks:
    t.mute = True
MESHES = [o for o in sc.objects if o.type == 'MESH']
for o in MESHES:
    if o.data.shape_keys:
        for kb in o.data.shape_keys.key_blocks[1:]:
            kb.value = 0.0
COAT = [o.name for o in MESHES if o.name.startswith("Outfit_Coat")]
NORMAL_HIDE = {"Outfit_Gloves", "Mask_Face", "Mask_Jaw", "Mask_Eyes", "Mask_Halo", "Icosphere", "TailorDummy"}

sc.render.engine = 'BLENDER_EEVEE'
try:
    sc.eevee.taa_render_samples = int(os.environ.get("RV_SAMPLES", "48"))
except AttributeError:
    pass
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
w_ = bpy.data.worlds.new("w"); sc.world = w_; w_.use_nodes = True
w_.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.35, 0.38, 1)
for nm_, en, rot in (("key", 3.4, (50, 0, -35)), ("fill", 1.2, (60, 0, 140)), ("rim", 2.0, (70, 0, 200))):
    Lt = bpy.data.lights.new(nm_, 'SUN'); Lt.energy = en
    lo = bpy.data.objects.new(nm_, Lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(a) for a in rot]
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co


def pose(name, frame):
    if name is None:
        arm.data.pose_position = 'REST'; ad.action = None
    else:
        arm.data.pose_position = 'POSE'; a = bpy.data.actions[name]; ad.action = a; ad.action_slot = a.slots[0]
    sc.frame_set(frame); bpy.context.view_layer.update()


def show(names):
    for o in MESHES:
        o.hide_render = o.name not in names


def shot(path, az_deg, el_deg, ctr, ortho, res, clip=None):
    sc.render.resolution_x, sc.render.resolution_y = res
    az, el = math.radians(az_deg), math.radians(el_deg)
    b = Vector((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)))
    cam.ortho_scale = ortho; cam.clip_start = clip[0] if clip else 0.1; cam.clip_end = clip[1] if clip else 30
    co.location = ctr + b * 10.0
    co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[RV] wrote", path)


def look(name):
    """a Blender MOCK of a look (material swaps and hiding, as the engine would do it): 'infil' = the INFILTRAITOR (the coat turned black side out, no
    jacket, black shirt and trim, the tie spun to its matte face, leather trousers, gloves); 'inv' = the investigator (the coat yellow side out)"""
    global figure
    hide = set(NORMAL_HIDE)
    if name == "infil":
        hide |= {"Outfit_Jacket"}; hide.discard("Outfit_Gloves")
        blk = bpy.data.materials.new("mock_black"); blk.use_nodes = True; b = blk.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (0.0028, 0.0028, 0.0033, 1); b.inputs["Roughness"].default_value = 0.8; b.inputs["Specular IOR Level"].default_value = 0.15
        for n in ("Outfit_Shirt", "Outfit_ShirtTrim"):
            o = bpy.data.objects.get(n)
            if o: o.data.materials[0] = blk
        SWAP = {"Coat_Fabric": "Coat_Lining", "Coat_Lining": "Coat_Fabric", "Tie_Silk": "Tie_Matte", "Tie_Matte": "Tie_Silk"}   # by NAME, as the engine would
        for o in MESHES:
            for i, m in enumerate(o.data.materials):
                if m and m.name in SWAP and bpy.data.materials.get(SWAP[m.name]): o.data.materials[i] = bpy.data.materials[SWAP[m.name]]
        tr = bpy.data.objects.get("Outfit_Trousers"); lm = bpy.data.materials.get("Coat_Lining")
        if tr and lm: tr.data.materials[0] = lm
    figure = [o.name for o in MESHES if o.name not in hide]
VIEWS = [("front", 0, 8), ("three_quarter", 40, 12), ("side", 90, 8), ("back", 180, 8)]
figure = [o.name for o in MESHES if o.name not in NORMAL_HIDE]
if os.environ.get("RV_LOOK"): look(os.environ["RV_LOOK"])
if "figure" in PARTS:
    pose("Idle_Loop", 20); show(figure)
    for vn, az, el in VIEWS:
        shot(OUT + f"{TAG}_fig_{vn}.png", az, el, Vector((0, 0, 0.93)), 2.05, (640, 1000))
if "game" in PARTS:
    pose("Walk_Formal_Loop", 12); show(figure)
    for k, az in enumerate((45, 225)):
        shot(OUT + f"{TAG}_game_{k}.png", az, 30, Vector((0, 0, 0.9)), 2.1, (132, 200))
if "coat" in PARTS:
    pose("Idle_Loop", 20); show(COAT)
    for vn, az, el in VIEWS:
        shot(OUT + f"{TAG}_coat_{vn}.png", az, el, Vector((0, 0.03, 1.0)), 1.45, (640, 1000))
FACE = ["SuperHero_Male", "Eyes", "Eyebrows", "Face_Hair", "Face_Beard"]
HAT = ["Outfit_HatCrown", "Outfit_HatBrim", "Outfit_HatBand"]
if "face" in PARTS:          # REST: upright; the near / far planes keep the T-posed hands (the skin mesh holds them) out of the frame
    pose(None, 1); fc = Vector((0, -0.02, 1.685)); clip = (9.84, 10.16)
    show(FACE)
    for vn, az, el in (("front", 0, 3), ("three_quarter", 35, 5), ("profile", 90, 3)):
        shot(OUT + f"{TAG}_face_{vn}.png", az, el, fc, 0.30, (800, 900), clip)
    show(FACE + HAT)
    shot(OUT + f"{TAG}_face_hat.png", 30, 8, Vector((0, -0.02, 1.66)), 0.42, (800, 900), (9.7, 10.3))
if "collar" in PARTS:        # the neck and shoulders, close
    pose("Idle_Loop", 20); show(figure)
    for vn, az, el in (("front", 0, 10), ("three_quarter", 40, 14), ("side", 90, 10), ("back", 180, 14)):
        shot(OUT + f"{TAG}_collar_{vn}.png", az, el, Vector((0, 0.02, 1.47)), 0.72, (800, 760))
if "nape" in PARTS:          # the back of the head under the hat, close (idle and rest)
    show(figure)
    for pz, fr in (("Idle_Loop", 20), (None, 1)):
        pose(pz, fr); tg = "idle" if pz else "rest"
        for vn, az, el in (("side", 90, 6), ("back3q", 140, 10), ("back", 180, 8), ("under", 160, -12)):
            shot(OUT + f"{TAG}_nape_{tg}_{vn}.png", az, el, Vector((0, 0.03, 1.66)), 0.36, (800, 800), (9.6, 10.4))
if "coatrest" in PARTS:
    pose(None, 1); show(COAT)
    for vn, az, el in VIEWS:
        shot(OUT + f"{TAG}_coatrest_{vn}.png", az, el, Vector((0, 0.03, 1.05)), 1.7, (800, 1000))
if "dummy" in PARTS and bpy.data.objects.get("TailorDummy"):
    pose(None, 1); show(["TailorDummy"])
    for vn, az, el in VIEWS:
        shot(OUT + f"{TAG}_dummy_{vn}.png", az, el, Vector((0, 0.03, 1.25)), 1.6, (900, 700))
if "modules" in PARTS and len(COAT) > 1:
    COLS = {"Body": (0.80, 0.64, 0.24), "Sleeves": (0.30, 0.55, 0.85), "Collar": (0.85, 0.30, 0.30), "Skirt": (0.35, 0.70, 0.40)}
    for nm in COAT:
        m = bpy.data.materials.new("mod_" + nm); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*COLS.get(nm.split("_")[-1], (0.7, 0.7, 0.7)), 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        bpy.data.objects[nm].data.materials[0] = m
    pose("Idle_Loop", 20); show(COAT)
    for vn, az, el in VIEWS[:2] + VIEWS[3:]:
        shot(OUT + f"{TAG}_mods_{vn}.png", az, el, Vector((0, 0.03, 1.0)), 1.45, (640, 1000))
    OFF = {"Sleeves": None, "Collar": Vector((0, -0.02, 0.16)), "Skirt": Vector((0, 0, -0.18)), "Body": Vector((0, 0, 0))}
    for nm in COAT:
        k = nm.split("_")[-1]
        if OFF.get(k) is not None: bpy.data.objects[nm].location += OFF[k]
    # the sleeves come apart as two halves: duplicate the object, keep one side in each
    import bmesh
    sl = bpy.data.objects.get("Outfit_Coat_Sleeves")
    if sl:
        for s_ in (1, -1):
            c = sl.copy(); c.data = sl.data.copy(); sc.collection.objects.link(c); c.name = f"Outfit_Coat_SleeveSide{s_}"
            b = bmesh.new(); b.from_mesh(c.data)
            bmesh.ops.delete(b, geom=[f for f in b.faces if f.calc_center_median().x * s_ < 0], context='FACES'); b.to_mesh(c.data); b.free()
            c.location += Vector((0.16 * s_, 0, 0.0)); MESHES.append(c)
        COAT2 = [n for n in COAT if n != "Outfit_Coat_Sleeves"] + ["Outfit_Coat_SleeveSide1", "Outfit_Coat_SleeveSide-1"]
        show(COAT2)
    shot(OUT + f"{TAG}_mods_exploded_front.png", 0, 8, Vector((0, 0.03, 1.0)), 1.9, (1100, 1000))
    shot(OUT + f"{TAG}_mods_exploded_back.png", 180, 8, Vector((0, 0.03, 1.0)), 1.9, (1100, 1000))
print("[RV] done")
