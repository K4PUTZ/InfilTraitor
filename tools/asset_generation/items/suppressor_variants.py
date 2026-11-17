"""Suppressor VARIANTS by script (Director, 2026-11-17: "algumas variações da malha pra criar outros silenciadores. Tipo quadrado
ou mesmo triangular, mais longo, mais curto"). Each one becomes a muzzle attachment of its own (`attachments/<id>.json`), with its
own attributes later (GAMEPLAY-01: how much it silences, the damage and accuracy it takes).

THE FRAME is the lab's suppressor A (`Suppressor-QWfBIqy0VW`, read off the Director's H1 file): the bore along glTF -Z, the rear
face at the origin, ~2 cm in radius. So every variant takes suppressor A's `mount` unchanged and only its own `muzzle` (its front,
[0, 0, -length]). A variant: a prism of `sides` (3 triangle, 4 square, 6 hex, 16 round) of `length`, a band at each end (Grey),
the bore's dark disk inset in the front face (Lighter), the tube itself (Black): the same material names as the lab's suppressors,
so the same `surface_materials`.

  blender -b --python tools/asset_generation/items/suppressor_variants.py -- <out dir> [<preview png>]
      -> <out dir>/suppressor_<id>/suppressor_<id>.glb, attachments/suppressor_<id>.json (suppressor A's mount), and a preview:
         every variant on the certified pistol's muzzle. Run after `family_rows.py --attachments` (it reads suppressor A's row).
"""
import bpy, bmesh, sys, os, math
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# id: (sides, length m, radius m, turn about the bore so a flat side is down, deg)
VARIANTS = {
    "round_short": (16, 0.100, 0.0200, 0.0),
    "round_long": (16, 0.200, 0.0200, 0.0),
    "square": (4, 0.150, 0.0215, 45.0),
    "square_long": (4, 0.200, 0.0215, 45.0),
    "triangle": (3, 0.150, 0.0260, 90.0),
    "hex": (6, 0.140, 0.0210, 0.0),
}
BAND = 0.012          # length of each end band
BAND_GROW = 1.07      # its radius over the tube's
BORE_R = 0.0065       # the dark disk in the front face
MATS = {"tube": ("M_PCL_Flat_Black", (0.03, 0.03, 0.035)), "band": ("M_PCL_Flat_Grey_Dark", (0.12, 0.12, 0.13)),
        "bore": ("M_PCL_Flat_Black_Lighter", (0.01, 0.01, 0.01))}


def material(key):
    name, rgb = MATS[key]
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    return m


def ring(bm, sides, r, y, turn):
    return [bm.verts.new((r * math.cos(math.radians(turn + 360.0 * k / sides)), y, r * math.sin(math.radians(turn + 360.0 * k / sides))))
            for k in range(sides)]


def prism(bm, sides, r, y0, y1, turn, mat_index, cap0=True, cap1=True):
    """A closed prism along Blender +Y (= glTF -Z) from y0 to y1."""
    a, b = ring(bm, sides, r, y0, turn), ring(bm, sides, r, y1, turn)
    for k in range(sides):
        f = bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
        f.material_index = mat_index
    if cap0:
        bm.faces.new(list(reversed(a))).material_index = mat_index
    if cap1:
        bm.faces.new(b).material_index = mat_index


def build(vid, sides, length, r, turn):
    me = bpy.data.meshes.new("suppressor_" + vid)
    for k in ("tube", "band", "bore"):
        me.materials.append(material(k))
    bm = bmesh.new()
    prism(bm, sides, r, BAND, length - BAND, turn, 0)
    prism(bm, sides, r * BAND_GROW, 0.0, BAND, turn, 1)
    prism(bm, sides, r * BAND_GROW, length - BAND, length, turn, 1)
    prism(bm, 12, BORE_R, length - 0.002, length + 0.0004, 0.0, 2)    # the bore's disk, just proud of the front face
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("suppressor_" + vid, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def export(ob, path):
    for o in bpy.data.objects:
        o.select_set(o is ob)
    bpy.context.view_layer.objects.active = ob
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True)


def preview(objs, png):
    """Every variant on a copy of the certified pistol's muzzle, side by side, one scale (suppressor A's mount)."""
    import json
    pistol = os.path.join(ROOT, "ASSETS", "props", "pistol_quaternius", "pistol.glb")
    row = json.load(open(os.path.join(ROOT, "attachments", "suppressor_a.json")))
    mt = row["model"]["mount"]
    mz = json.load(open(os.path.join(ROOT, "weapons", "pistol.json")))["model"]["muzzle"]
    from mathutils import Quaternion
    CM = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).to_4x4()      # Blender -> glTF
    q = mt["quat"]
    g = Matrix.Translation(Vector(mz)) @ Matrix.Translation(Vector(mt["pos"])) @ Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4() @ Matrix.Scale(mt["scale"], 4)
    mount_b = CM.inverted() @ g @ CM
    scene = bpy.context.scene
    for i, ob in enumerate(objs):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=pistol)
        new = [o for o in bpy.data.objects if o not in before]
        root = [o for o in new if o.parent is None][0]
        off = Matrix.Translation((0.0, 0.0, -0.09 * i))
        root.matrix_world = off @ root.matrix_world
        ob.matrix_world = off @ mount_b
        cu = bpy.data.curves.new("t", "FONT"); cu.body = ob.name.replace("suppressor_", ""); cu.size = 0.018
        t = bpy.data.objects.new("t", cu); scene.collection.objects.link(t)
        t.location = (-0.12, 0.0, -0.09 * i + 0.01); t.rotation_euler = (math.radians(90), 0, 0)
        ink = bpy.data.materials.get("ink") or bpy.data.materials.new("ink"); ink.use_nodes = True
        ink.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1); cu.materials.append(ink)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1100
    w = bpy.data.worlds.new("w"); scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.84, 1)
    s = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN")); scene.collection.objects.link(s)
    s.rotation_euler = (math.radians(60), 0, math.radians(-20)); s.data.energy = 3.5
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); scene.collection.objects.link(cam); scene.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 0.72
    centre = Vector((0.12, 0.0, -0.09 * (len(objs) - 1) / 2.0))
    cam.location = centre + Vector((0.5, -1.2, 0.9))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = png
    bpy.ops.render.render(write_still=True)


def write_row(vid, length):
    """`attachments/suppressor_<vid>.json`: suppressor A's fit and mount (the same frame), its own front as the muzzle. Its
    attributes are GAMEPLAY-01's (Director, 2026-11-17: each silences more or less, takes more or less damage, hurts accuracy)."""
    import json, datetime
    a = json.load(open(os.path.join(ROOT, "attachments", "suppressor_a.json")))
    aid = "suppressor_" + vid
    row = {"id": aid, "kind": "muzzle", "fits": a["fits"], "gameplay": {"stealth": "suppressed"},
           "model": {"path": f"res://ASSETS/props/{aid}/{aid}.glb", "surface_materials": a["model"]["surface_materials"],
                     "mount": a["model"]["mount"], "muzzle": [0.0, 0.0, round(-length, 4)],
                     "size_certified": datetime.date.today().isoformat()}}
    with open(os.path.join(ROOT, "attachments", aid + ".json"), "w") as f:
        json.dump(row, f, indent=2)
        f.write("\n")


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    out = a[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    for vid, (sides, length, r, turn) in VARIANTS.items():
        ob = build(vid, sides, length, r, turn)
        path = os.path.join(out, "suppressor_" + vid, "suppressor_" + vid + ".glb")
        export(ob, path)
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        print(f"[suppressor_variants] suppressor_{vid}: {sides} sides, {length * 100:.0f} cm, radius {r * 100:.2f} cm, {tris} tris -> {os.path.relpath(path, ROOT)}")
        objs.append(ob)
        write_row(vid, length)
    if len(a) > 1:
        preview(objs, a[1])


if __name__ == "__main__":
    main()
