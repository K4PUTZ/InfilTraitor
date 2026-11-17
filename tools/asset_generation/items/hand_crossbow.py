"""ITEMS_MASTER_PLAN §2.2 / §3 — the HAND CROSSBOW (the canon's dart launcher, hold H1), cut down by script from the CC0 crossbow.

The source is CreativeTrio's "Crossbow" (CC0, `items_polypizza/crossbow/Crossbow-kHb0kA11oD.glb`, original untouched): a rifle-style
compound crossbow with a pistol grip, a butt stock, a scope, a fore-grip and a foot stirrup. It is a triangle soup (every face loose);
welded, it falls into 19 parts, each recognised here by its box (`PARTS`, the counts asserted, so a changed source fails loudly):

  KEPT     grip body (grip, trigger guard, lower receiver) · trigger · barrel (the rail the bolt rides) · riser · 4 limbs · 2 cams · string
  REMOVED  butt stock · scope · its turret · its two rings · its top rail · fore-grip · foot stirrup

What is kept is pulled together by one SPACE WARP (`warp`, the original's frame: forward +Y, up +Z): the barrel in front of the grip
is shortened (x `K_BARREL`), everything from the riser forward is shrunk (x `S_FRONT`), and the prod's width beyond the barrel
(`X_CORE`) is narrowed by the same `S_FRONT`, so the limbs, the cams, the string and the cable between the cams move together and stay
joined (the string is straight between its ends; the cams stay round because their two axes shrink by nearly one factor).
The DART is CreativeTrio's "Arrow" (CC0, same folder): its shaft shortened (x `K_SHAFT`), the nock on the string's latch, the shaft on
the barrel's top.

Colour = OUR materials (`ACTOR` D66): the palette texture is dropped and each face gets a ZONE (one material per zone in the GLB, the
contract of `tripo_zones.py`); the zone -> material mapping moves into the item's row when it gets one. Preview colours: `ZONES`.
Output (the convention of the guns pack once its node transform is applied: barrel along +X, up +Y in glTF, the original's own units;
the size in the hand is set by the Director in the H1 lab file, MOVEMENT §11.6 step 2):
  ASSETS/MODELS/sources/hand_crossbow/hand_crossbow.glb   the crossbow with the dart loaded (its own zones: hidden after the shot)
  ASSETS/MODELS/sources/hand_crossbow/crossbow_dart.glb   the dart alone (in flight, stuck, on the floor)
  ASSETS/MODELS/sources/hand_crossbow/_preview.png        the original and the hand crossbow, side + top + three-quarters, to scale
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/items/hand_crossbow.py
"""
import bpy, bmesh, os, math, json
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "items_polypizza", "crossbow")
CROSSBOW = os.path.join(SRC, "Crossbow-kHb0kA11oD.glb")
ARROW = os.path.join(SRC, "Arrow-dZVjrxZdaB.glb")
OUT = os.path.join(ROOT, "ASSETS", "MODELS", "sources", "hand_crossbow")

# The warp (original frame, units of the original: it is 1.876 long, the grip 0.28 tall).
Y_GRIP_FRONT = -0.086   # the grip body's front: nothing behind it moves
Y_RISER = 0.605         # the riser's back: from here forward the whole front shrinks
K_BARREL = 0.60         # the barrel between the two, shortened to 60 %
S_FRONT = 0.65          # the riser, the limbs and the cams, at 65 %
X_CORE = 0.045          # half the barrel's width: what lies beyond it (the prod, the string) is narrowed by S_FRONT
K_SHAFT = 0.315         # the dart's bare shaft, at this fraction of the arrow's
POINT_LEN = 0.06        # the arrow's front kept whole (its point)

# Zone -> the material it takes (registry id, or registry id @ paint): the preview's colours and the item row's future mapping.
ZONES = {"Body": "rubber", "Limbs": "steel_dark", "Cams": "steel_dark", "String": "fabric", "Trigger": "metal",
         "DartShaft": "metal", "DartTail": "plastic@signal_red", "DartNock": "plastic"}
PAINTS = {"signal_red": (0.62, 0.12, 0.10)}   # `PaintPalette.PAINTS`, copied for the preview only


def part_class(lo, hi):
    """Which part of the CreativeTrio crossbow a welded part is, from its box (original frame). None = not recognised (fails)."""
    size = hi - lo
    if hi.y < -0.44:
        return "stock"
    if lo.y > 0.77:
        return "stirrup"
    if lo.z > 0.15:
        return "turret"
    if lo.z > 0.1 and size.y > 0.3:
        return "scope"
    if lo.z > 0.085 and size.y < 0.03:
        return "ring"
    if lo.z > 0.025 and size.y > 0.3:
        return "rail"
    if hi.z < -0.03 and lo.y > 0.05:
        return "foregrip"
    if lo.z < -0.25:
        return "grip"
    if size.y < 0.03 and hi.z < -0.07:
        return "trigger"
    if size.x > 1.0:
        return "string"
    if size.y > 1.0:
        return "barrel"
    if lo.y > 0.6 and size.x > 0.4:
        return "riser"
    if size.x < 0.13 and size.y < 0.13 and abs(lo.x) > 0.4:
        return "cam"
    if size.x > 0.3 and size.y > 0.4:
        return "limb"
    return None


PARTS = {"stock": 1, "stirrup": 1, "turret": 1, "scope": 1, "ring": 2, "rail": 1, "foregrip": 1,       # removed
         "grip": 1, "trigger": 1, "string": 1, "barrel": 1, "riser": 1, "cam": 2, "limb": 4}           # kept
REMOVED = ("stock", "stirrup", "turret", "scope", "ring", "rail", "foregrip")
ZONE_OF = {"grip": "Body", "barrel": "Body", "riser": "Body", "trigger": "Trigger", "limb": "Limbs", "cam": "Cams", "string": "String"}


def fail(msg):
    raise SystemExit("[hand_crossbow] FAILED: " + msg)


def colour_of(spec):
    mat, _, paint = spec.partition("@")
    if paint:
        return PAINTS[paint]
    row = json.load(open(os.path.join(ROOT, "ASSETS", "materials", mat, mat + ".json")))
    return tuple(row["base_color"])


def import_baked(path, name):
    """The model's one mesh, its node transform applied to the vertices, welded (the source is a soup of loose faces), flat-shaded."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if len(meshes) != 1:
        fail(f"{os.path.basename(path)}: expected one mesh, found {len(meshes)}")
    ob = meshes[0]
    me = ob.data
    me.transform(ob.matrix_world)
    for o in new:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    ob.name = name
    if "custom_normal" in me.attributes:   # the soup's split normals: the faces are drawn flat instead (the same look)
        me.attributes.remove(me.attributes["custom_normal"])
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    return ob


def parts_of(bm):
    """Welded loose parts: a list of face lists, each with its box."""
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            x = stack.pop(); comp.append(x)
            for e in x.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); stack.append(g)
        vs = {v for g in comp for v in g.verts}
        lo = Vector([min(v.co[i] for v in vs) for i in range(3)]); hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
        out.append((comp, lo, hi))
    return out


def warp(co):
    """The space warp (original frame): the barrel shortened, the front shrunk, the prod narrowed; z untouched."""
    x, y, z = co
    if y > Y_GRIP_FRONT:
        if y <= Y_RISER:
            y = Y_GRIP_FRONT + (y - Y_GRIP_FRONT) * K_BARREL
        else:
            y = Y_GRIP_FRONT + (Y_RISER - Y_GRIP_FRONT) * K_BARREL + (y - Y_RISER) * S_FRONT
    ax = abs(x)
    if ax > X_CORE:
        x = math.copysign(X_CORE + (ax - X_CORE) * S_FRONT, x)
    return Vector((x, y, z))


def material(zone):
    m = bpy.data.materials.get(zone) or bpy.data.materials.new(zone)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour_of(ZONES[zone]), 1)
    bsdf.inputs["Roughness"].default_value = 0.7
    return m


def set_zones(ob, zone_of_face):
    me = ob.data
    names = sorted(set(zone_of_face.values()), key=list(ZONES).index)
    me.materials.clear()
    for z in names:
        me.materials.append(material(z))
    for f in me.polygons:
        f.material_index = names.index(zone_of_face[f.index])
    if me.uv_layers:
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])


def build_crossbow():
    ob = import_baked(CROSSBOW, "hand_crossbow")
    bm = bmesh.new(); bm.from_mesh(ob.data)
    parts = parts_of(bm)
    count = {}
    cls_of = []
    for comp, lo, hi in parts:
        c = part_class(lo, hi)
        if c is None:
            fail(f"a part not recognised: box {tuple(round(v, 3) for v in lo)} .. {tuple(round(v, 3) for v in hi)}")
        count[c] = count.get(c, 0) + 1
        cls_of.append(c)
    if count != PARTS:
        fail(f"the source's parts changed: found {count}, expected {PARTS}")
    zone = {}
    dead = []
    for (comp, lo, hi), c in zip(parts, cls_of):
        if c in REMOVED:
            dead.extend(comp)
        else:
            for f in comp:
                zone[f] = ZONE_OF[c]
    latch = min((v.co.copy() for (comp, lo, hi), c in zip(parts, cls_of) if c == "string" for f in comp for v in f.verts), key=lambda p: p.y)
    barrel_top = max(v.co.z for (comp, lo, hi), c in zip(parts, cls_of) if c == "barrel" for f in comp for v in f.verts if abs(v.co.x) < 0.012)
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    for v in bm.verts:
        v.co = warp(v.co)
    bm.faces.ensure_lookup_table()
    zone_by_index = {f.index: zone[f] for f in bm.faces}
    bm.to_mesh(ob.data); bm.free()
    set_zones(ob, zone_by_index)
    print("[hand_crossbow] parts kept: %s; removed: %s" % (", ".join(sorted(c for c in count if c not in REMOVED)), ", ".join(REMOVED)))
    return ob, warp(latch), barrel_top


def build_dart(latch, barrel_top):
    """The arrow (original frame: nock at -Y, point at +Y), its shaft shortened, the nock on the latch, the shaft resting on the barrel."""
    ob = import_baked(ARROW, "crossbow_dart")
    me = ob.data
    ys = [v.co.y for v in me.vertices]
    y_nock, y_tip = min(ys), max(ys)
    nock = [v.co for v in me.vertices if v.co.y < y_nock + 0.03]
    ax, az = (min(c.x for c in nock) + max(c.x for c in nock)) / 2.0, (min(c.z for c in nock) + max(c.z for c in nock)) / 2.0
    # the stations along the arrow, read off its vertices: the fletching (whatever stands off the axis) ends where the bare shaft
    # begins; the point keeps its own length (the front POINT_LEN), only the bare shaft between them is shortened
    vanes = [v.co.y for v in me.vertices if math.hypot(v.co.x - ax, v.co.z - az) > 0.012]
    y_vane_front = max(vanes)
    y_point = y_tip - POINT_LEN
    def along(y):
        if y <= y_vane_front:
            return y
        if y <= y_point:
            return y_vane_front + (y - y_vane_front) * K_SHAFT
        return y_vane_front + (y_point - y_vane_front) * K_SHAFT + (y - y_point)
    z_mid = az
    radius = max(math.hypot(c.x - ax, c.z - az) for c in nock)   # the bare shaft has vertices only at its two ends: the nock is as thick
    for v in me.vertices:
        v.co.y = along(v.co.y)
    shift = Vector((latch.x - ax, latch.y - y_nock, barrel_top + radius - z_mid))
    for v in me.vertices:
        v.co += shift
    zone = {}
    for f in me.polygons:
        c = f.center
        if c.y < latch.y + (nock_len := max(cc.y for cc in nock) - y_nock + 0.02) and math.hypot(c.x - latch.x, c.z - (barrel_top + radius)) < 0.012:
            zone[f.index] = "DartNock"
        elif math.hypot(c.x - latch.x, c.z - (barrel_top + radius)) > radius * 1.6:
            zone[f.index] = "DartTail"
        else:
            zone[f.index] = "DartShaft"
    set_zones(ob, zone)
    length = max(v.co.y for v in me.vertices) - min(v.co.y for v in me.vertices)
    print("[hand_crossbow] dart: %.3f long (the arrow %.3f), shaft radius %.4f, nock at the latch y %.3f" % (length, y_tip - y_nock, radius, latch.y))
    return ob


def to_gun_frame(ob):
    """Original frame (forward +Y, up +Z) -> the guns pack's (forward +X in Blender = +X in glTF, up +Z = +Y in glTF)."""
    ob.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z"))


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True)


def box(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


def preview(xbow, dart, path):
    """The original (top row) and the hand crossbow (bottom row), each side | top | three-quarters, one scale."""
    scene = bpy.context.scene
    orig = import_baked(CROSSBOW, "original")
    orig.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z"))
    oc = colour_of("rubber")
    for o in (orig,):
        o.data.materials.clear()
        m = bpy.data.materials.new("orig"); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*oc, 1)
        o.data.materials.append(m)
    rows = [[orig], [xbow, dart]]
    gap = 2.2
    for r, objs in enumerate(rows):
        for c in range(3):
            for o in objs:
                cp = o if c == 0 else o.copy()
                if c:
                    scene.collection.objects.link(cp)
                cp.rotation_mode = "XYZ"
                if c == 1:
                    cp.rotation_euler = (math.radians(90), 0, 0)          # seen from above: the prod's span faces the camera
                elif c == 2:
                    cp.rotation_euler = (math.radians(55), 0, math.radians(-30))
                cp.location = (c * gap, 0, -r * 1.25)
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = 3 * gap
    cam = bpy.data.objects.new("cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
    cam.location = (gap, -10, -0.62); cam.rotation_euler = (math.radians(90), 0, 0)
    scene.render.resolution_x = 2100; scene.render.resolution_y = 1150
    scene.render.engine = "BLENDER_EEVEE"
    scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.62, 0.64, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35)); sun.data.energy = 3.0
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    xbow, latch, barrel_top = build_crossbow()
    dart = build_dart(latch, barrel_top)
    for o in (xbow, dart):
        to_gun_frame(o)
    lo, hi = box([xbow, dart])
    tris = sum(len(p.vertices) - 2 for o in (xbow, dart) for p in o.data.polygons)
    print("[hand_crossbow] hand crossbow + dart: %.3f long x %.3f wide x %.3f tall (the original's units), %d triangles" % (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, tris))
    export([xbow, dart], os.path.join(OUT, "hand_crossbow.glb"))
    export([dart], os.path.join(OUT, "crossbow_dart.glb"))
    print("[hand_crossbow] wrote", os.path.relpath(os.path.join(OUT, "hand_crossbow.glb"), ROOT), "and crossbow_dart.glb")
    preview(xbow, dart, os.path.join(OUT, "_preview.png"))
    print("[hand_crossbow] wrote", os.path.relpath(os.path.join(OUT, "_preview.png"), ROOT))


main()
