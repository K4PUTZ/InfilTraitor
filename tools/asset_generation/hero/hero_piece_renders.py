# hero_piece_renders.py — one EEVEE render set per piece of the hero v5.1 master (hero_tailor5.glb): every other mesh hidden, the rig in Idle_Loop frame 20 (as worn,
# a "ghost mannequin"; the head pieces in REST, upright, the way hero_tailor framed its face shots), four views at one scale per piece, framed from the posed vertices. Writes <OUT>/<piece>_<view>.png and pieces.json.
# Env: HERO_REPO (repo root, trailing /), PR_GLB (default hero_tailor5.glb), PR_OUT (folder), PR_ONLY (comma list of piece keys), PR_SAMPLES (64),
# PR_LIGHT_HAT (felt in light grey, to compare the form with a white reference). Usage: blender -b -P hero_piece_renders.py, then hero_piece_sheets.py.
import bpy, json, math, os
import numpy as np
from mathutils import Vector

GLB = os.environ.get("PR_GLB", os.environ.get("HERO_REPO", "") + "ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/hero_tailor5.glb")
OUT = os.environ.get("PR_OUT", "/tmp/pr/").rstrip("/") + "/"
os.makedirs(OUT, exist_ok=True)
ONLY = [s for s in os.environ.get("PR_ONLY", "").split(",") if s]

# key, label, meshes, views (name, azimuth, elevation[, "rest"|"idle"]), vertex filter (posed world points -> mask) that frames the piece; the
# camera's near / far planes hug the filtered points' depth, so the parts outside the filter (the skin's hands, the other glove) drop out
BODY_VIEWS = [("front", 0, 8), ("three_quarter", 40, 12), ("side", 90, 8), ("back", 180, 8)]
PIECES = [
    ("face", "FACE  (skin, eyes, brows, hair; the skin mesh also holds the hands, so the tris count them)", ["SuperHero_Male", "Eyes", "Eyebrows", "Face_Hair"], [("front", 0, 4), ("three_quarter", 35, 6), ("profile", 90, 4), ("game_camera", 45, 30)], lambda P: P[:, 2] > 1.50),
    ("hat", "FEDORA", ["Outfit_HatCrown", "Outfit_HatBrim", "Outfit_HatBand"], [("front", 0, 10), ("three_quarter", -40, 18), ("side", 90, 8), ("back_left", 140, 18)], None),
    ("hatfelt", "FEDORA felt", ["Outfit_HatCrown", "Outfit_HatBrim"], [("front", 0, 10), ("three_quarter", -40, 18), ("side", 90, 8), ("back_left", 140, 18)], None),
    ("hatband", "FEDORA band", ["Outfit_HatBand"], [("front", 0, 10), ("three_quarter", -40, 18), ("side", 90, 8), ("back_left", 140, 18)], None),
    ("mask", "MASK", ["Mask_Face", "Mask_Jaw", "Mask_Eyes"], [("front", 0, 4), ("three_quarter", 35, 6), ("profile", 90, 4), ("back", 180, 4)], None),
    ("shirt", "SHIRT", ["Outfit_Shirt"], BODY_VIEWS, None),
    ("shirt_trim", "SHIRT TRIM (collar, cuffs, pocket square)", ["Outfit_ShirtTrim"], BODY_VIEWS, None),
    ("tie", "TIE", ["Outfit_Tie"], BODY_VIEWS, None),
    ("jacket", "JACKET", ["Outfit_Jacket"], BODY_VIEWS, None),
    ("trousers", "TROUSERS", ["Outfit_Trousers"], BODY_VIEWS, None),
    ("shoes", "SHOE (the right one; the left mirrors it)", ["Outfit_ShoeR"], [("outer_side", -90, 6), ("three_quarter", -40, 20), ("front", 0, 8), ("top", -20, 75)], None),
    ("coat", "OVERCOAT", ["Outfit_Coat_Body", "Outfit_Coat_Sleeves", "Outfit_Coat_Collar", "Outfit_Coat_Skirt"], BODY_VIEWS, None),   # v5.2: a kit of modules (D79)
    ("gloves", "GLOVE (black style; the right one)", ["Outfit_Gloves"],
     [("worn_front", 0, 8, "idle"), ("worn_outer", -90, 8, "idle"), ("open_back_of_hand", 0, 80, "rest"), ("open_palm", 0, -80, "rest")], lambda P: P[:, 0] < 0),
    ("pack", "PACK", ["Pack_Main", "Pack_PouchL", "Pack_PouchR"], [("back", 180, 8), ("three_quarter_back", 140, 12), ("side", 90, 8), ("front", 0, 8)], None),
]

REST_PIECES = ("face", "hat", "mask", "shoes")     # in Idle_Loop the head pitches down and turns and the feet turn out: a product view wants them straight

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
            kb.value = 0.0     # every expression off (Blender 5.2 makes keys at 1.0; the trap the v4 export fell into)
if os.environ.get("PR_LIGHT_HAT"):        # the felt in light grey, so the form reads beside the white reference photo (the hat itself is black)
    for m in bpy.data.materials:
        if m.name.startswith("Hat_Black") and m.use_nodes:
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.53, 0.50, 1)
arm.data.pose_position = 'POSE'
ad.action = bpy.data.actions["Idle_Loop"]
ad.action_slot = ad.action.slots[0]
sc.frame_set(20)

sc.render.engine = 'BLENDER_EEVEE'
try:
    sc.eevee.taa_render_samples = int(os.environ.get("PR_SAMPLES", "64"))
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


def posed_verts(names, filt):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for n in names:
        o = bpy.data.objects[n]
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = np.array(o.matrix_world)
        co_ = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", co_)
        co_ = co_.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
        pts.append(co_)
        ev.to_mesh_clear()
    p = np.concatenate(pts)
    return p if filt is None else p[filt(p)]


def basis(az_deg, el_deg):
    az, el = math.radians(az_deg), math.radians(el_deg)
    back = np.array([math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)])   # from the target toward the camera
    right = np.cross(np.array([0, 0, 1.0]), back); right /= np.linalg.norm(right)
    if right @ np.array([math.cos(az), math.sin(az), 0]) < 0: right = -right
    up = np.cross(back, right)
    return back, right, up



report = {}
for key, label, names, views, filt in PIECES:
    if ONLY and key not in ONLY:
        continue
    for o in MESHES:
        o.hide_render = o.name not in names
    default_pose = "rest" if key in REST_PIECES else "idle"
    views = [v if len(v) == 4 else (*v, default_pose) for v in views]
    cache = {}

    def at(pose):
        arm.data.pose_position = 'REST' if pose == "rest" else 'POSE'
        sc.frame_set(20)
        bpy.context.view_layer.update()
        if pose not in cache:
            cache[pose] = posed_verts(names, filt)
        return cache[pose]

    ext = []
    for vn, az, el, pose in views:
        P = at(pose)
        b, r, u = basis(az, el)
        pr, pu = P @ r, P @ u
        ext.append((pr.min(), pr.max(), pu.min(), pu.max()))
    wmax = max(e[1] - e[0] for e in ext); hmax = max(e[3] - e[2] for e in ext)
    H = 900; W = int(round(max(500, min(1300, H * wmax / hmax))))
    ortho = max(hmax * max(W, H) / H, wmax * max(W, H) / W) * 1.10
    cam.ortho_scale = ortho
    sc.render.resolution_x, sc.render.resolution_y = W, H
    files = []
    for (vn, az, el, pose), e in zip(views, ext):
        P = at(pose)
        b, r, u = basis(az, el)
        ctr = P.mean(axis=0)
        ctr = ctr - r * (ctr @ r) - u * (ctr @ u) + r * ((e[0] + e[1]) / 2.0) + u * ((e[2] + e[3]) / 2.0)
        depth = 10.0 + ctr @ b - P @ b
        cam.clip_start = max(0.05, float(depth.min()) - 0.03); cam.clip_end = float(depth.max()) + 0.03
        loc = Vector(ctr + b * 10.0)
        co.location = loc
        co.rotation_euler = (Vector(ctr) - loc).to_track_quat('-Z', 'Y').to_euler()
        path = OUT + f"{key}_{vn}.png"
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        files.append([vn, path])
    tris = sum(sum(len(p.vertices) - 2 for p in bpy.data.objects[n].data.polygons) for n in names)
    P = at(default_pose)
    poses = sorted({v[3] for v in views})
    report[key] = {"label": label, "pose": " + ".join("rest" if q == "rest" else "Idle_Loop f20" for q in poses), "meshes": names, "tris": tris,
                   "height_cm": round(float(P[:, 2].max() - P[:, 2].min()) * 100), "views": files,
                   "materials": sorted({m.name for n in names for m in bpy.data.objects[n].data.materials if m})}
    print("[PR]", key, tris, "tris", report[key]["height_cm"], "cm", W, "x", H)
json.dump(report, open(OUT + "pieces.json" if not ONLY else OUT + "pieces_" + "_".join(ONLY) + ".json", "w"), indent=1)
print("[PR] done")
