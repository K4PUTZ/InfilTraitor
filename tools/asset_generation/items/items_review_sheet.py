"""ITEMS_MASTER_PLAN §4 step 2 — a review sheet of every downloaded item model, NOT to scale: each model fitted into the same cell,
one row block per group, labelled. For the Director to keep or reject; the to-scale sheets are MOVEMENT's family lab files.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/items/items_review_sheet.py -- "$PWD" temp/items_sheet/items_review.png"""
import bpy, sys, os, math, glob
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT, OUT = argv[0], argv[1]
SRC = os.path.join(ROOT, "ASSETS/ISOMETRIC/source_assets/imported_models/items_polypizza")
COLS, CELL, GAP = 10, 1.0, 0.35

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
ink = bpy.data.materials.new("ink"); ink.use_nodes = True
ink.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)


def text(body, x, z, size, align="CENTER"):
    bpy.ops.object.text_add(location=(x, -0.5, z), rotation=(math.radians(90), 0, 0))
    t = bpy.context.object
    t.data.body, t.data.size, t.data.align_x = body, size, align
    t.data.materials.append(ink)


def box(objs):
    bpy.context.view_layer.update()
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


z = 0.0
right = 0.0
for group in sorted(os.listdir(SRC)):
    files = sorted(glob.glob(os.path.join(SRC, group, "*.glb")))
    if not files:
        continue
    text(group, -0.3, z - 0.55, 0.22, "RIGHT")
    for i, path in enumerate(files):
        r, c = divmod(i, COLS)
        cx, cz = c * (CELL + GAP) + CELL / 2, z - r * (CELL + GAP + 0.25)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        root = bpy.data.objects.new("r", None); scene.collection.objects.link(root)
        for o in new:
            if o.parent is None:
                o.parent = root
        lo, hi = box(new)
        if (hi.y - lo.y) > (hi.x - lo.x):
            root.rotation_euler = (0, 0, math.radians(90)); lo, hi = box(new)
        s = CELL / max(hi.x - lo.x, hi.z - lo.z, 1e-6)
        root.scale = (s, s, s); lo, hi = box(new)
        root.location = (cx - (lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, cz - CELL - lo.z + (CELL - (hi.z - lo.z)) / 2)
        label = os.path.basename(path)[:-4]
        name, mid = label.rsplit("-", 1)
        text(name.replace("_", " ") + "\n" + mid, cx, cz - CELL - 0.2, 0.09)
        right = max(right, cx + CELL / 2)
    rows = (len(files) + COLS - 1) // COLS
    z -= rows * (CELL + GAP + 0.25) + 0.3

left, top, bottom = -2.2, 0.3, z + 0.2
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
cam.location = ((left + right) / 2, -20, (top + bottom) / 2); cam.rotation_euler = (math.radians(90), 0, 0)
w, h = right + 0.2 - left, top - bottom
cam_data.ortho_scale = max(w, h); scene.camera = cam
scene.render.resolution_x = 3000; scene.render.resolution_y = int(3000 * h / w)
scene.render.engine = "BLENDER_EEVEE"
scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.8, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(60), 0, math.radians(-30)); sun.data.energy = 3.0
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("[items] wrote", OUT)
