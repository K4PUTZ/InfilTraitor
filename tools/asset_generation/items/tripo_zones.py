"""ITEMS_MASTER_PLAN §7.12 — give a split Tripo object its MATERIAL ZONES (Director, 2026-11-16: the colours are OURS, `ACTOR` D66).

A Tripo Smart Mesh comes with no material: this names each face's zone so the game's row maps zone -> registry material
(`"surface_materials": {"Body": "rubber", ...}`), exactly as the downloaded models' authored surfaces are mapped. A zone is chosen
per LOOSE PART (ranked by face count, largest first: the rank is stable for one file), and where one part holds two zones, by a
geometric rule on the face centre (the taser's cartridge is the front 30 % of its body; the cloner's screen is the face recessed into
its front). The zones and the material each would take are the prompt's colours (§7.1); the material column here only drives the
preview render, the game's mapping lives in the item's row.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/items/tripo_zones.py -- <split_dir> <out_dir>
Writes <out_dir>/<name>.glb (one material per zone) and <out_dir>/_preview.png (each object in our materials' colours)."""
import bpy, bmesh, sys, os, math, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
os.makedirs(OUT, exist_ok=True)

# The preview's paints: `PaintPalette.PAINTS` (godot/scripts/systems/paint_palette.gd), copied for the render only.
PAINTS = {"olive_drab": (0.30, 0.34, 0.17), "signal_red": (0.62, 0.12, 0.10), "safety_yellow": (0.85, 0.68, 0.10)}


def rule_front_fraction(axis, frac):
    """Faces whose centre lies in the first `frac` of the part's extent along -axis (x / y / z)."""
    def test(c, lo, hi):
        i = "xyz".index(axis)
        return c[i] < lo[i] + frac * (hi[i] - lo[i])
    return test


def rule_recessed(axis, depth):
    """Faces facing along `axis` whose centre sits deeper than `depth` inside the part's outer faces on that axis (a screen in a bezel)."""
    def test(c, lo, hi, n=None):
        i = "xyz".index(axis)
        return abs(n[i]) > 0.7 and lo[i] + depth < c[i] < hi[i] - depth
    return test


# object -> {"parts": {rank: zone}, "default": zone, "split": (rank, zone, rule), "zones": {zone: material spec}}
SPEC = {
    "taser": {"default": "Body", "parts": {1: "Muzzle", 5: "Contacts", 6: "Contacts", 10: "Contacts"},
              "split": (0, "Cartridge", rule_front_fraction("x", 0.30)),
              "zones": {"Body": "rubber", "Cartridge": "plastic@safety_yellow", "Muzzle": "rubber", "Contacts": "metal"}},
    "detonator": {"default": "Body", "parts": {1: "Handle", 3: "Button", 5: "ButtonBase", 6: "Handle", 7: "Handle"},
                  "zones": {"Body": "painted_metal@olive_drab", "Handle": "rubber", "Button": "plastic@signal_red", "ButtonBase": "rubber"}},
    "spray_can": {"default": "Can", "parts": {1: "Cap", 2: "Nozzle", 3: "Nozzle", 4: "Nozzle"},
                  "zones": {"Can": "metal", "Cap": "plastic", "Nozzle": "plastic"}},
    "phone_cloner": {"default": "Body", "parts": {1: "Cable", 2: "Cable", 3: "Cable", 4: "Buttons", 5: "Buttons", 8: "Plug", 9: "PlugTip"},
                     "split": (0, "Screen", rule_recessed("y", 0.003)),
                     "zones": {"Body": "rubber", "Screen": "steel_dark", "Buttons": "plastic", "Cable": "rubber", "Plug": "rubber", "PlugTip": "metal"}},
}


def colour_of(spec):
    mat, _, paint = spec.partition("@")
    if paint:
        return PAINTS[paint]
    row = json.load(open(os.path.join(ROOT, "ASSETS", "materials", mat, mat + ".json")))
    return tuple(row["base_color"])


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
row_i = 0
for name, spec in SPEC.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    ob = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
    ob.name = name
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    part_of, parts = {}, []
    for f in bm.faces:
        if f.index in part_of:
            continue
        stack, comp = [f], []
        part_of[f.index] = len(parts)
        while stack:
            x = stack.pop(); comp.append(x.index)
            for e in x.edges:
                for g in e.link_faces:
                    if g.index not in part_of:
                        part_of[g.index] = len(parts); stack.append(g)
        parts.append(comp)
    order = sorted(range(len(parts)), key=lambda k: -len(parts[k]))
    rank = {k: r for r, k in enumerate(order)}
    zone_names = list(spec["zones"].keys())
    me.materials.clear()
    for z in zone_names:
        m = bpy.data.materials.new(z); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour_of(spec["zones"][z]), 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
        me.materials.append(m)
    split = spec.get("split")
    box = {}
    if split:
        vs = [v.co for fi in parts[order[split[0]]] for v in bm.faces[fi].verts]
        box = (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
               Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))
    counts = {}
    for f in me.polygons:
        r = rank[part_of[f.index]]
        zone = spec["parts"].get(r, spec["default"])
        if split and r == split[0]:
            rule = split[2]
            try:
                hit = rule(f.center, box[0], box[1], f.normal)
            except TypeError:
                hit = rule(f.center, box[0], box[1])
            if hit:
                zone = split[1]
        f.material_index = zone_names.index(zone)
        counts[zone] = counts.get(zone, 0) + 1
    print("[tripo_zones] %-14s %s" % (name, ", ".join("%s %d" % (z, counts.get(z, 0)) for z in zone_names)))
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_format="GLB")
    # Preview: front and three-quarters.
    s = 0.8 / max(ob.dimensions)
    ob.scale = (s, s, s); ob.location = (0, 0, -row_i * 1.2)
    cp = ob.copy(); scene.collection.objects.link(cp)
    cp.rotation_euler = (math.radians(-20), 0, math.radians(35)); cp.location = (1.2, 0, -row_i * 1.2)
    row_i += 1

cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("c", cam_d); scene.collection.objects.link(cam)
cam.location = (0.6, -10, -row_i * 1.2 / 2 + 0.6); cam.rotation_euler = (math.radians(90), 0, 0)
cam_d.ortho_scale = row_i * 1.2; scene.camera = cam
scene.render.resolution_x = 600; scene.render.resolution_y = int(600 * row_i / 2.0)
scene.render.engine = "BLENDER_EEVEE"
scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.57, 1)
sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN")); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(55), 0, math.radians(-35)); sun.data.energy = 3
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "_preview.png")
bpy.ops.render.render(write_still=True)
