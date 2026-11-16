"""ITEMS_MASTER_PLAN §7 — split a Tripo page (several objects generated as ONE mesh from a stacked front + side page) into one GLB
per object, and render each for review.

A page's objects are stacked top to bottom, so the mesh's loose parts fall in height BANDS separated by empty gaps: parts are grouped by
overlapping height spans, top to bottom, and each band becomes an object named by --names (in the page's order). Each object is moved
so its base centre sits at the origin; its size is left as generated (the page normalises the stack, and the size in the hand is set
by hand anyway, rule 4).
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/items/tripo_split.py -- <page.glb> <out_dir> <name1,name2,...>
Writes <out_dir>/<name>.glb and <out_dir>/_review.png (each object from the front, the side, and three-quarters)."""
import bpy, bmesh, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, NAMES = argv[0], argv[1], argv[2].split(",")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
if len(meshes) != 1:
    raise SystemExit("[tripo_split] expected one mesh, found %d" % len(meshes))
src = meshes[0]
bpy.context.view_layer.objects.active = src
src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Loose parts and their height spans.
bm = bmesh.new(); bm.from_mesh(src.data); bm.verts.ensure_lookup_table()
seen, parts = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    stack, comp = [v], []
    seen.add(v.index)
    while stack:
        x = stack.pop(); comp.append(x.index)
        for e in x.link_edges:
            y = e.other_vert(x)
            if y.index not in seen:
                seen.add(y.index); stack.append(y)
    zs = [bm.verts[i].co.z for i in comp]
    parts.append([min(zs), max(zs), set(comp)])
parts.sort(key=lambda p: -p[1])
bands = []
for p in parts:
    if bands and p[1] >= bands[-1][0]:      # overlaps the band above: same object
        bands[-1][0] = min(bands[-1][0], p[0]); bands[-1][2] |= p[2]
    else:
        bands.append(p[:])
if len(bands) != len(NAMES):
    raise SystemExit("[tripo_split] %d height bands, %d names: %s" % (len(bands), len(NAMES), [(round(b[0], 3), round(b[1], 3)) for b in bands]))

objs = []
for name, (z0, z1, verts) in zip(NAMES, bands):
    bm2 = bm.copy(); bm2.verts.ensure_lookup_table()
    bmesh.ops.delete(bm2, geom=[v for v in bm2.verts if v.index not in verts], context="VERTS")
    me = bpy.data.meshes.new(name); bm2.to_mesh(me); bm2.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ws = [v.co for v in me.vertices]
    lo = Vector((min(w.x for w in ws), min(w.y for w in ws), min(w.z for w in ws)))
    hi = Vector((max(w.x for w in ws), max(w.y for w in ws), max(w.z for w in ws)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in me.vertices:
        v.co -= shift
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    size = hi - lo
    print("[tripo_split] %-18s %5d tris  size %.3f x %.3f x %.3f" % (name, tris, size.x, size.y, size.z))
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_format="GLB")
    objs.append((ob, size))
src.hide_render = True; bm.free()

# Review: one row per object, three views (front, side, three-quarters), each object fitted to its cell.
scene = bpy.context.scene
clay = bpy.data.materials.new("clay"); clay.use_nodes = True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.6, 0.6, 0.62, 1)
CELL = 1.0
for r, (ob, size) in enumerate(objs):
    ob.data.materials.append(clay)
    ob.hide_render = True
    s = 0.8 * CELL / max(size.x, size.y, size.z)
    for c, rot in enumerate((0.0, 90.0, 35.0)):
        cp = ob.copy(); cp.data = ob.data; scene.collection.objects.link(cp)
        cp.hide_render = False
        cp.scale = (s, s, s)
        cp.rotation_euler = (0, 0, math.radians(rot)) if c < 2 else (math.radians(-20), 0, math.radians(rot))
        cp.location = (c * CELL * 1.2, 0, -r * CELL * 1.2 - 0.4 * CELL)
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_d); scene.collection.objects.link(cam)
w, h = 3 * CELL * 1.2, len(objs) * CELL * 1.2
cam.location = (w / 2 - 0.6 * CELL, -10, -h / 2 + 0.2 * CELL); cam.rotation_euler = (math.radians(90), 0, 0)
cam_d.ortho_scale = max(w, h) * 1.02; scene.camera = cam
scene.render.resolution_x = 900; scene.render.resolution_y = int(900 * h / w)
scene.render.engine = "BLENDER_EEVEE"
scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.2, 0.22, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(55), 0, math.radians(-35)); sun.data.energy = 3.5
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "_review.png")
bpy.ops.render.render(write_still=True)
print("[tripo_split] review", scene.render.filepath)
