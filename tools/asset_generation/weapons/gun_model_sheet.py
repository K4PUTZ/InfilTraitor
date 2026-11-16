"""MOVEMENT_MASTER_PLAN §11.6 step 1 — the model sheet: the Quaternius guns pack + the grenade beside the male LIGHT Agent
(dressed as the game draws him, grey clay), side view, orthographic, to scale. For the Director to pick one model per weapon.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/weapons/gun_model_sheet.py -- "$PWD" temp/model_sheet/guns_to_scale.png
Guns at the certified pistol's factor (x0.0600 on the pack's native units = where the lab opens them), the grenade at its
certified 0.065 GU (`bombs/frag_grenade.json`). Units: the GLB's; a length in GU = units x TripoFigure.WORLD_SCALE, the same
conversion `WeaponDef.world_scale()` uses, so the sheet's numbers are the game's."""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT, OUT = argv[0], argv[1]
PACK = os.path.join(ROOT, "ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted")
GRENADE = os.path.join(ROOT, "ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb")
AGENT = os.path.join(ROOT, "ASSETS/MODELS/official/AGENT_MALE_LIGHT.glb")
FACTOR = 0.0600
WORLD_SCALE = 1.225
GRENADE_H = 0.065 / WORLD_SCALE

ROWS = [
    ("Pistols / revolvers", ["Pistol-52kQzphmeF", "Pistol", "Pistol-J3i9KDQ3kt", "Pistol-Z7aOjJu583",
                             "Revolver", "Revolver-9C26wSpMS0", "Revolver-XrnLUz6kQj"]),
    ("Submachine guns / short shotguns", ["Submachine Gun", "Submachine Gun-nsP3JukU73", "Shotgun Sawed Off", "Shotgun Short Stock"]),
    ("Shotguns", ["Shotgun", "Shotgun-ZmPTnh7njL"]),
    ("Assault rifles / bullpup", ["Assault Rifle", "Assault Rifle-Bgvuu4CUMV", "Assault Rifle-fpLucho45C", "Bullpup"]),
    ("Sniper rifles", ["Sniper Rifle", "Sniper Rifle-ASOMZIErq3", "Sniper Rifle-TKaBjAEofL", "Sniper Rifle-i65hEldsw6"]),
    ("Attachments + grenade", ["Scope", "Bipod", "Tripod", "Bayonet", "@grenade"]),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def import_group(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    return root, new


def world_box(objs):
    """The box of the EVALUATED meshes (a skinned figure's bound_box is its unposed data, not what is drawn)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def label(text, x, z, size):
    bpy.ops.object.text_add(location=(x, -0.2, z), rotation=(math.radians(90), 0, 0))
    t = bpy.context.object
    t.data.body = text
    t.data.size = size
    t.data.align_x = "CENTER"
    mat = bpy.data.materials.get("ink") or bpy.data.materials.new("ink")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    t.data.materials.append(mat)
    return t


# The figure, feet at z=0, at x=0.
agent, agent_objs = import_group(AGENT, "agent")
HIDDEN = ("Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere")   # TripoFigure.UNDRESSED_PIECES: what the game hides
for o in list(agent_objs):
    if o.animation_data:
        o.animation_data_clear()
    if o.name in HIDDEN:
        agent_objs.remove(o)
        bpy.data.objects.remove(o)
clay = bpy.data.materials.new("clay"); clay.use_nodes = True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.57, 1)
for o in agent_objs:
    if o.type == "MESH":
        o.data.materials.clear(); o.data.materials.append(clay)
        if o.data.shape_keys:   # the coat's corrective keys stay at rest
            for kb in o.data.shape_keys.key_blocks:
                kb.value = 0.0
lo, hi = world_box(agent_objs)
agent.location = (-(lo.x + hi.x) / 2, 0, -lo.z)
lo, hi = world_box(agent_objs)
fig_h = hi.z - lo.z
print("[sheet] figure height %.3f units (%.3f GU)" % (fig_h, fig_h * WORLD_SCALE))

ROW_H = 0.30
x0 = hi.x + 0.95
z = fig_h - 0.12
label("Agent %.2f GU (hat incl.)" % (fig_h * WORLD_SCALE), 0.0, -0.10, 0.035)
widest = 0.0
for title, names in ROWS:
    t = label(title, x0 - 0.06, z - 0.13, 0.035); t.data.align_x = "RIGHT"
    x = x0
    for name in names:
        if name == "@grenade":
            root, objs = import_group(GRENADE, "grenade")
            lo, hi = world_box(objs)
            s = GRENADE_H / (hi.z - lo.z)
            caption = "Grenade (certified)"
        else:
            root, objs = import_group(os.path.join(PACK, name + ".glb"), name)
            s = FACTOR
            caption = name
        root.scale = (s, s, s)
        lo, hi = world_box(objs)
        if (hi.y - lo.y) > (hi.x - lo.x):   # barrel along Y: turn it to X
            root.rotation_euler = (0, 0, math.radians(90))
            lo, hi = world_box(objs)
        length = max(hi.x - lo.x, hi.z - lo.z)
        root.location.x += x - lo.x
        root.location.z += (z - 0.16) - lo.z + (0.0 if name == "@grenade" else 0.0)
        root.location.y += -(lo.y + hi.y) / 2
        lo, hi = world_box(objs)
        w = hi.x - lo.x
        label("%s\n%.3f GU" % (caption, length * WORLD_SCALE), x + w / 2, z - 0.215, 0.022)
        x += max(w, 0.22) + 0.07
    widest = max(widest, x)
    z -= ROW_H

# Camera: orthographic, front (from -Y), framing everything.
left, right = -0.45, widest + 0.05
bottom, top = min(z + ROW_H - 0.27, -0.14), fig_h + 0.05
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
cam.location = ((left + right) / 2, -5, (bottom + top) / 2)
cam.rotation_euler = (math.radians(90), 0, 0)
width, height = right - left, top - bottom
cam_data.ortho_scale = max(width, height)
scene.camera = cam
scene.render.resolution_x = 2600
scene.render.resolution_y = int(2600 * height / width)
scene.render.engine = "BLENDER_EEVEE"
scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.8, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(60), 0, math.radians(-30)); sun.data.energy = 3.0
scene.view_settings.view_transform = "Standard"
scene.render.film_transparent = False
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("[sheet] wrote", OUT)
