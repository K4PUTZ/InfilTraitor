"""MOVEMENT_MASTER_PLAN §11.6 step 2 — a hold family's LAB FILE: every model of the family in the Agent's hand, in the family's aim.

Director, 2026-11-16 (§11.8 Q11): "todos os modelos da mesma família lado a lado, próximos do agente, e vamos conferir o tamanho e a
posição uma por uma, usando a mesma pose (aim)". 2026-11-17: "começar a preparar as cenas de trabalho no Blender, com o personagem em
cada tipo de empunhadura (aim) + todas as armas daquele tipo, para ajustar os tamanhos. Começando pelas pistolas".

THE FILE. `ASSETS/MODELS/fit/FAMILY_<family>_aim_<FIG>.blend`: a LINE of Agents side by side (one per model, 0.45 apart along X, all
facing -Y), every one frozen in the aim the GAME plays (the family's timeline at its `aim` marker: for H1 the Director's
`SEQ_draw_pistol_<FIG>_arm6.blend`, frame 23 = `sequences/<fig>/draw_pistol.json`'s last stop), each holding ONE model, child of
its RightHand bone. Agent 01 holds the family's certified reference as the timeline holds it (`PROP_pistol`, untouched). The others
are opened at a STARTING size (the guns pack at the certified pistol's factor 0.0600, §11.5; another source at a length relative to
the reference, the roster's number) and a STARTING grip: same orientation as the reference, the GRIP ANCHOR (the top of the grip, at
its back: where the web of the hand sits; `grip_anchor`) on the reference's. Each model's object origin is its grip anchor, so S and
R act about the hand. A label on the floor names each one. The Director sets the size and the grip of each by hand (object or Edit
Mode, both are read back: the read-back fits the SOURCE model's vertices to where they now are, a similarity transform, so any mix
of moves, turns and uniform scales is recovered; reshaping is reported) and saves.

The pose is the family's, shared by every model (§11.2): it is not edited here. The file is built ONCE and never rebuilt over his
work (`pose_lab.py family` opens it as it is).

Run inside Blender:
  blender -b --python family_lab.py -- build  <family> <figure> <out .blend>
  blender -b --python family_lab.py -- render <saved .blend> <out prefix>      -> <prefix>_line.png (the whole line, three-quarters)
                                                                                  <prefix>_tile_<nn>.png (each gun hand from the side, one scale)
"""
import bpy, bmesh, sys, os, math, json
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FIT = os.path.join(ROOT, "ASSETS", "MODELS", "fit")
IMPORTED = os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models")
PACK = os.path.join(IMPORTED, "quaternius_ultimate_guns_pack", "extracted")
PP = os.path.join(IMPORTED, "items_polypizza")
SOURCES = os.path.join(ROOT, "ASSETS", "MODELS", "sources")
PREFIX = "mixamorig:"
PACK_FACTOR = 0.0600     # the certified pistol's factor on the pack's native units (MOVEMENT §11.5): where the pack's guns OPEN
SPACING = 0.45           # between two Agents of the line, along X (the figure's units: the male stands 0.88 with the hat)
REMOVE = ("Body_Hair", "Outfit_Belt", "Outfit_Shirt", "Outfit_Trousers", "Icosphere")   # hidden in the game's dressed set (`TripoFigure.UNDRESSED_PIECES`)

# A family: the timeline whose `aim` marker is the game's aim, the prop the timeline holds (the certified reference) and the models.
# A model: (label, source glb, start, kind). start = "pack" (PACK_FACTOR) or a float: its length as a fraction of the reference's.
# kind = "held" (in the hand at the grip anchor) or "muzzle" (an attachment: a copy of the reference with the model on its muzzle).
FAMILIES = {
    "H1": {
        "timeline": "draw_pistol", "marker": "aim", "reference": "pistol", "reference_label": "Pistol-52kQzphmeF (certified)",
        "reference_glb": "ASSETS/props/pistol_quaternius/pistol.glb",
        "muzzle": (0.1266, 0.0349, 0.0),    # the reference's `model.muzzle` (weapons/pistol.json), glTF space of its model
        "models": [
            ("Pistol", os.path.join(PACK, "Pistol.glb"), "pack", "held"),
            ("Pistol-J3i9KDQ3kt", os.path.join(PACK, "Pistol-J3i9KDQ3kt.glb"), "pack", "held"),
            ("Pistol-Z7aOjJu583", os.path.join(PACK, "Pistol-Z7aOjJu583.glb"), "pack", "held"),
            ("Revolver", os.path.join(PACK, "Revolver.glb"), "pack", "held"),
            ("Revolver-9C26wSpMS0", os.path.join(PACK, "Revolver-9C26wSpMS0.glb"), "pack", "held"),
            ("Revolver-XrnLUz6kQj", os.path.join(PACK, "Revolver-XrnLUz6kQj.glb"), "pack", "held"),
            ("Taser (Tripo)", os.path.join(SOURCES, "tripo_props1_zoned", "taser.glb"), 0.75, "held"),            # 15 cm vs ~20
            ("Hand crossbow", os.path.join(SOURCES, "hand_crossbow", "hand_crossbow.glb"), 1.35, "held"),         # hand_crossbow.py
            ("Flare gun", os.path.join(PP, "flare", "Flare_Gun-44H9OBUqTC.glb"), 1.0, "held"),
            ("Scifi_Pistol-TuHM3CURcC", os.path.join(PP, "scifi", "Scifi_Pistol-TuHM3CURcC.glb"), 1.0, "held"),
            ("Scifi_Pistol-U0Q1BrKL1y", os.path.join(PP, "scifi", "Scifi_Pistol-U0Q1BrKL1y.glb"), 1.0, "held"),
            ("Scifi_Pistol-uw4B33Mm0d", os.path.join(PP, "scifi", "Scifi_Pistol-uw4B33Mm0d.glb"), 1.0, "held"),
            ("Ray gun", os.path.join(PP, "scifi", "Ray_Gun-DIcib0mihf.glb"), 1.0, "held"),
            ("Grapple launcher (Tripo)", os.path.join(SOURCES, "tripo_props3_zoned", "grapple_launcher.glb"), 1.2, "held"),  # ITEMS Q3 open
            ("Suppressor-QWfBIqy0VW", os.path.join(PP, "suppressors", "Suppressor-QWfBIqy0VW.glb"), 0.6, "muzzle"),
            ("Suppressor-VLiLj3j1tS", os.path.join(PP, "suppressors", "Suppressor-VLiLj3j1tS.glb"), 0.6, "muzzle"),
        ],
    },
}

CM = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).to_4x4()    # Blender (x, y, z) -> glTF (x, z, -y)


def fail(msg):
    print(f"[family_lab] ERROR: {msg}")
    sys.exit(1)


def args_after_dashes():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


# ---- the models ------------------------------------------------------------------------------------------------------------------------------
def import_model(path, name):
    """The model as ONE mesh object, every node transform applied to its vertices, at the origin, its materials as authored."""
    if not os.path.exists(path):
        fail(f"{os.path.relpath(path, ROOT)} does not exist")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        fail(f"{os.path.relpath(path, ROOT)}: no mesh")
    others = [o.name for o in new if o.type != "MESH"]
    for o in meshes:
        o.data = o.data.copy() if o.data.users > 1 else o.data
        o.data.transform(o.matrix_world)
        if "custom_normal" in o.data.attributes:
            o.data.attributes.remove(o.data.attributes["custom_normal"])
    if len(meshes) > 1:
        ctx = {"active_object": meshes[0], "selected_editable_objects": meshes}
        with bpy.context.temp_override(**ctx):
            bpy.ops.object.join()
    ob = meshes[0]
    for n in others:   # the empties of the glTF hierarchy (the joined meshes are gone already)
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    ob.name = name
    return ob


def verts(ob):
    return [v.co.copy() for v in ob.data.vertices]


def box(points):
    return (Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)]))


def grip_anchor(points):
    """(anchor, grip height) of a handgun-shaped model in the gun frame (barrel +X, up +Z): the top of the grip at its back. Slices from
    the bottom up: the first whose vertices span over 70 % of the length is the body's underside (the slide, the frame, the receiver);
    the grip's back is the rearmost vertex in the band just under it."""
    lo, hi = box(points)
    L, h = hi.x - lo.x, hi.z - lo.z
    n = 48
    z_top = None
    for i in range(n):
        a, b = lo.z + h * i / n, lo.z + h * (i + 1) / n
        xs = [p.x for p in points if a <= p.z < b]
        if xs and max(xs) - min(xs) > 0.7 * L:
            z_top = a
            break
    if z_top is None or z_top <= lo.z + 0.05 * h:
        return Vector((lo.x, 0.0, hi.z)), 0.0          # no grip found under a body: the rear-top corner
    band = [p for p in points if z_top - 0.2 * h <= p.z <= z_top + 1e-6]
    return Vector((min(p.x for p in band), 0.0, z_top)), z_top - lo.z


def to_gun_frame(ob):
    """Turns the model's mesh to the gun frame (barrel along +X, up +Z, centred on y = 0): the long horizontal axis to X, then the
    grip (the low part) to the rear. Returns the turn applied (about Z), in degrees."""
    pts = verts(ob)
    lo, hi = box(pts)
    turn = 0.0
    if hi.y - lo.y > hi.x - lo.x:
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
        turn += 90.0
        pts = verts(ob)
        lo, hi = box(pts)
    low = [p for p in pts if p.z < lo.z + 0.35 * (hi.z - lo.z)]
    if low and sum(p.x for p in low) / len(low) > (lo.x + hi.x) / 2.0:
        ob.data.transform(Matrix.Rotation(math.radians(180), 4, "Z"))
        turn += 180.0
        pts = verts(ob)
        lo, hi = box(pts)
    ob.data.transform(Matrix.Translation((0.0, -(lo.y + hi.y) / 2.0, 0.0)))
    return turn


# ---- the figure ------------------------------------------------------------------------------------------------------------------------------
def freeze(scene, frame):
    """The timeline's state at `frame` made static: the pose, the coat's keys, the reference prop's place and visibility; the actions,
    the markers and the frame range go."""
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    held = []
    for ob in bpy.data.objects:
        if ob.animation_data and ob.animation_data.action:
            if ob.type == "ARMATURE":
                state = [(pb, pb.rotation_mode, pb.rotation_quaternion.copy(), pb.rotation_euler.copy(), pb.location.copy(), pb.scale.copy()) for pb in ob.pose.bones]
                held.append(("arm", ob, state))
            else:
                held.append(("obj", ob, (ob.matrix_world.copy(), ob.hide_viewport, ob.hide_render)))
        if ob.type == "MESH" and ob.data.shape_keys and ob.data.shape_keys.animation_data:
            held.append(("keys", ob, [(kb, kb.value) for kb in ob.data.shape_keys.key_blocks]))
    for kind, ob, state in held:
        if kind == "keys":
            ob.data.shape_keys.animation_data_clear()
            for kb, v in state:
                kb.value = v
        else:
            ob.animation_data_clear()
            if kind == "arm":
                for pb, mode, q, e, loc, s in state:
                    pb.rotation_mode = mode
                    pb.rotation_quaternion = q
                    pb.rotation_euler = e
                    pb.location = loc
                    pb.scale = s
            else:
                mw, hv, hr = state
                ob.matrix_world = mw
                ob.hide_viewport = False
                ob.hide_render = False
    scene.timeline_markers.clear()
    scene.frame_start = scene.frame_end = scene.frame_current = 1
    bpy.context.view_layer.update()


def clone_figure(arm, meshes, offset, coll):
    a2 = arm.copy()
    coll.objects.link(a2)
    a2.matrix_world = Matrix.Translation(offset) @ arm.matrix_world
    for k in list(a2.keys()):
        if k.startswith("lab_"):
            del a2[k]
    for m in meshes:
        m2 = m.copy()
        coll.objects.link(m2)
        m2.parent = a2
        m2.matrix_parent_inverse = m.matrix_parent_inverse.copy()
        for mod in m2.modifiers:
            if mod.type == "ARMATURE":
                mod.object = a2
    return a2


def label(text, loc, coll, size=0.028):
    cu = bpy.data.curves.new("label", "FONT")
    cu.body = text
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("LABEL " + text.split("\n")[0], cu)
    coll.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (math.radians(70), 0, 0)    # standing up toward the front (-Y), tilted back: readable from the front and from above
    mat = bpy.data.materials.get("lab_ink") or bpy.data.materials.new("lab_ink")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    cu.materials.append(mat)
    ob.hide_select = True
    return ob


def build(family, figure, out_blend):
    if family not in FAMILIES:
        fail(f"unknown family {family} (have {', '.join(FAMILIES)})")
    if os.path.exists(out_blend):
        fail(f"{os.path.relpath(out_blend, ROOT)} exists: it holds the Director's work and is never rebuilt")
    fam = FAMILIES[family]
    timeline = os.path.join(FIT, f"SEQ_{fam['timeline']}_{figure.upper()}_arm6.blend")
    bpy.ops.wm.open_mainfile(filepath=timeline)
    scene = bpy.context.scene
    markers = {m.name: m.frame for m in scene.timeline_markers}
    if fam["marker"] not in markers:
        fail(f"{os.path.basename(timeline)} has no marker '{fam['marker']}' (has {markers})")
    frame = markers[fam["marker"]]
    freeze(scene, frame)
    for n in REMOVE:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        fail(f"{os.path.basename(timeline)}: expected one armature, found {len(arms)}")
    arm = arms[0]
    ref = bpy.data.objects.get("PROP_" + fam["reference"])
    if ref is None or ref.parent is not arm or ref.parent_bone != PREFIX + "RightHand":
        fail(f"{os.path.basename(timeline)}: no PROP_{fam['reference']} on the RightHand")
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent is arm and o is not ref]
    for o in bpy.data.objects:
        o.select_set(False)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    # Agent 01: the timeline's own figure and the certified reference, in a collection of its own.
    root = scene.collection
    c0 = bpy.data.collections.new(f"01 {fam['reference_label']}")
    root.children.link(c0)
    for o in [arm, ref] + body:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        c0.objects.link(o)
    ref.name = f"GUN_01 {fam['reference_label']}"
    ref["lab_role"] = "reference"
    ref["lab_source"] = fam["reference_glb"]
    ref_pts = verts(ref)
    ref_lo, ref_hi = box(ref_pts)
    ref_len = ref_hi.x - ref_lo.x
    ref_anchor, ref_grip_h = grip_anchor(ref_pts)
    ref_world = ref.matrix_world.copy()
    print(f"[family_lab] {figure} {family}: the aim is {os.path.basename(timeline)} frame {frame}; reference {ref_len:.4f} long, grip anchor "
          f"{tuple(round(v, 4) for v in ref_anchor)}, grip {ref_grip_h:.4f} tall")
    label(f"01\n{fam['reference_label']}", Vector((0.0, -0.42, 0.012)), c0)
    arm["lab_family"] = family
    arm["lab_figure"] = figure
    arm["lab_aim"] = f"{os.path.basename(timeline)}@{frame}"

    rows = []
    for i, (name, path, start, kind) in enumerate(fam["models"], start=2):
        offset = Vector(((i - 1) * SPACING, 0.0, 0.0))
        coll = bpy.data.collections.new(f"{i:02d} {name}")
        root.children.link(coll)
        a2 = clone_figure(arm, body, offset, coll)
        bpy.context.view_layer.update()
        gun = import_model(path, f"GUN_{i:02d} {name}")
        for c in list(gun.users_collection):
            c.objects.unlink(gun)
        coll.objects.link(gun)
        turn = to_gun_frame(gun)
        pts = verts(gun)
        lo, hi = box(pts)
        length = hi.x - lo.x
        factor = PACK_FACTOR if start == "pack" else float(start) * ref_len / length
        gun.data.transform(Matrix.Scale(factor, 4))
        pts = verts(gun)
        if kind == "held":
            anchor, grip_h = grip_anchor(pts)
            gun.data.transform(Matrix.Translation(-anchor))
            local = Matrix.Translation(ref_anchor)
            holder_bone = PREFIX + "RightHand"
            parent = a2
        else:   # an attachment: a copy of the reference in this Agent's hand, the model's rear end on its muzzle, the model its child
            pistol = ref.copy()
            pistol.name = f"GUN_{i:02d} {fam['reference_label'].split(' ')[0]} (carrier)"
            pistol["lab_role"] = "carrier"
            coll.objects.link(pistol)
            pistol.parent = a2
            pistol.parent_type = "BONE"
            pistol.parent_bone = PREFIX + "RightHand"
            bpy.context.view_layer.update()
            pistol.matrix_world = Matrix.Translation(offset) @ ref_world
            bpy.context.view_layer.update()
            lo, hi = box(pts)
            rear = Vector((lo.x, (lo.y + hi.y) / 2.0, (lo.z + hi.z) / 2.0))
            gun.data.transform(Matrix.Translation(-rear))
            mz = fam["muzzle"]
            local = Matrix.Translation((mz[0], -mz[2], mz[1]))      # glTF -> Blender
            anchor, grip_h = rear, 0.0
            parent = pistol
            holder_bone = None
        gun.parent = parent
        if holder_bone:
            gun.parent_type = "BONE"
            gun.parent_bone = holder_bone
        bpy.context.view_layer.update()
        carrier_world = (Matrix.Translation(offset) @ ref_world) if kind == "held" else parent.matrix_world
        gun.matrix_world = carrier_world @ local
        gun["lab_role"] = kind
        gun["lab_source"] = os.path.relpath(path, ROOT)
        gun["lab_start_factor"] = factor
        gun["lab_turn_deg"] = turn
        gun["lab_anchor"] = list(anchor / factor)          # in the source's units, after the turn: where the origin sits
        tris = sum(len(p.vertices) - 2 for p in gun.data.polygons)
        label(f"{i:02d}\n{name}", offset + Vector((0.0, -0.42, 0.012)), coll)
        print(f"[family_lab]   {i:02d} {name:28s} {kind:6s} start x{factor:.4f} ({'pack' if start == 'pack' else f'{float(start):.2f} x the reference'}), "
              f"{length * factor / ref_len:.2f} x the reference's length, turned {turn:.0f}, grip {grip_h:.4f} tall, {tris} tris")
        rows.append(name)

    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = None
    scene["lab_family"] = family
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[family_lab] wrote {os.path.relpath(out_blend, ROOT)}: {len(rows) + 1} Agents, one model each")


# ---- the render ------------------------------------------------------------------------------------------------------------------------------
def _setup_render(scene, w, h):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = w, h
    world = bpy.data.worlds.new("lab_w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.78, 0.80, 1)
    for rot, en in (((50, 0, -30), 3.0), ((-40, 0, 150), 1.0)):
        s = bpy.data.objects.new("lab_sun", bpy.data.lights.new("lab_sun", "SUN"))
        scene.collection.objects.link(s)
        s.rotation_euler = tuple(math.radians(a) for a in rot)
        s.data.energy = en
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("lab_cam", bpy.data.cameras.new("lab_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def render(blend, prefix):
    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    guns = sorted([o for o in bpy.data.objects if o.name.startswith("GUN_") and o.get("lab_role") != "carrier"], key=lambda o: o.name)
    cam = _setup_render(scene, 2400, 1000)
    # the whole line, from the front three-quarters, above the hands
    xs = [o.matrix_world.translation.x for o in guns]
    mid = Vector(((min(xs) + max(xs)) / 2.0, -0.1, 0.62))
    cam.data.lens = 28
    cam.location = mid + Vector((-1.0, -6.6, 1.4))
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = prefix + "_line.png"
    bpy.ops.render.render(write_still=True)
    print(f"[family_lab] rendered {scene.render.filepath}")
    # each gun hand from the Agent's right side (-X), orthographic, one scale for all: a tile per model
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.42
    scene.render.resolution_x, scene.render.resolution_y = 520, 420
    tiles = []
    for o in guns:
        mine = set(o.users_collection[0].objects)
        for x in bpy.data.objects:            # only this Agent and its model: the side camera looks down the whole line
            if x.type in ("MESH", "FONT", "ARMATURE"):
                x.hide_render = x not in mine
        p = o.matrix_world.translation.copy()
        target = Vector((p.x, p.y - 0.06, p.z))
        cam.location = target + Vector((-2.0, 0.0, 0.0))
        cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
        path = f"{prefix}_tile_{o.name[4:6]}.png"
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append((path, o.name[4:]))
    with open(prefix + "_tiles.json", "w") as f:
        json.dump(tiles, f)
    print(f"[family_lab] rendered {len(tiles)} hand tiles ({prefix}_tiles.json lists them)")


def main():
    a = args_after_dashes()
    if not a:
        fail("usage: -- build <family> <figure> <out .blend> | render <blend> <out prefix>")
    if a[0] == "build":
        build(a[1], a[2], a[3])
    elif a[0] == "render":
        render(a[1], a[2])
    else:
        fail(f"unknown mode {a[0]}")


if __name__ == "__main__":
    main()
