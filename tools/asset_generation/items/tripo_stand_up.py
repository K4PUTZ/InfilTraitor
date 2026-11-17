"""ITEMS_MASTER_PLAN §7.12 — stand a LAID-DOWN Tripo object up (pages 7-9 and the drone were generated lying on their side):
rotate it by the given degrees about X, put its base back on Z = 0, centred, and overwrite the GLB. Which sign: the side that faced
the camera in the laid page's front view is the object's top; -90 brings -Y up.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/items/tripo_stand_up.py -- <object.glb> <degrees>"""
import bpy, sys, math
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
path, deg = a[0], float(a[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
ob.data.transform(Matrix.Rotation(math.radians(deg), 4, "X"))
vs = [v.co for v in ob.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))); hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in ob.data.vertices: v.co -= shift
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB")
print("[stand] size", tuple(round(x, 3) for x in (hi - lo)))
