# tripo_pose_lab.py — posing a Tripo Agent BY HAND in Blender, and getting the pose back into the game (MOVEMENT, 2026-11-08).
#
# The Director's flow (`tools/persistent/pose_lab.py` wraps these modes):
#   build    a .blend with the LIGHT Agent in the pose the game has TODAY (solved or his earlier file), the other bones as the idle has them, and the weapon in the
#            hand as an object he can move. He poses in Pose Mode (FK on the 65 bones; mirror, IK helpers and the pose library are all fair game) and saves.
#   extract  reads the SAVED .blend and writes ASSETS/ANIMATIONS/poses/<figure>/<id>.json, which `TripoFigure.bank_pose` plays instead of the solved pose.
#   render   a preview still of the saved .blend (EEVEE, two views).
#
# THE CONVERSION IS NOT GUESSED. Godot's local rotation of a bone is its rotation relative to the parent bone, absolute (rest included); Blender's pose bone holds a DELTA from
# its rest in its own bone frame, in Z-up armature space. glTF (and so Godot) is Y-up: (x, y, z) -> (x, z, -y), `CM` below. The Blender importer keeps each bone's frame equal to
# its glTF node's (measured on the LIGHT rig: the bone frame is the node frame to 1e-6), but this file does not rely on it: Godot dumps every bone's REST global rotation
# (`tripo_pose_dump.gd`), and `BB` = node rest ^-1 * bone rest is computed per bone and used.
#   Godot local q  ->  node global G = G_parent * q  ->  Blender bone rotation P = CM^T (G * BB) CM  ->  delta D = R^-1 * R_parent * P_parent^-1 * P     (R = the bone's rest rotation)
# and the same backwards on extract. Locations are not touched (a pose is rotations); scale is not read.
#
# THE WEAPON is an object named PROP_<id> (the model's mesh node, which carries the glb's own x100 scale: `lab_node_scale`), parented to the bone so it follows the hand. Its
# placement, relative to the bone's own frame and applied to the model's scene root, is what the pose file carries: {"bone", "pos", "quat", "scale"}.
#
# Run inside Blender:  blender -b --python tripo_pose_lab.py -- build   <figure> <pose id> <dump dir> <out .blend> [--glb LIGHT.glb] [--pistol model.glb]
#                      blender -b --python tripo_pose_lab.py -- extract <saved .blend> <out .json>
#                      blender -b --python tripo_pose_lab.py -- render  <saved .blend> <out .png>
import bpy, sys, json, math, os, struct
import numpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LIGHT_GLB = os.path.join(ROOT, "ASSETS", "MODELS", "official", "AGENT_%s_LIGHT.glb")
PROP_GLB = {"pistol": os.path.join(ROOT, "ASSETS", "props", "pistol_quaternius", "pistol.glb"),
            "grenade": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "quaternius_grenade", "Grenade.glb")}
PREFIX = "mixamorig:"                       # the Blender importer keeps Tripo's colon; Godot turns it into an underscore
HIDE = ("Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere")   # the pieces the game's DRESSED set hides (`TripoFigure.UNDRESSED_PIECES`)
EPS_CHANGED = 1e-3                          # a bone the Director moved: its local rotation differs from the base by more than this (quaternion distance)

# Blender (x, y, z) -> glTF (x, z, -y), a proper rotation.
CM = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
CMT = CM.transposed()


def to_g(m3):
    return CM @ m3 @ CMT


def to_bl(m3):
    return CMT @ m3 @ CM


def quat_xyzw(q):
    return Quaternion((q[3], q[0], q[1], q[2]))


def xyzw(q):
    return [q.x, q.y, q.z, q.w]


def qdist(a, b):
    """distance between two rotations as quaternions (q and -q are the same rotation)"""
    d1 = (a - b).magnitude
    d2 = (a + b).magnitude
    return min(d1, d2)


def fail(msg):
    print(f"[tripo_pose_lab] ERROR: {msg}")
    sys.exit(1)


class Rig:
    """the armature, the rest data Godot dumped and the per-bone frame correction `BB`"""

    def __init__(self, arm, rest):
        self.arm = arm
        self.names = []                      # parents first
        self.parent = {}                     # short name -> parent short name or ""
        self.rest_g = {}                     # short name -> Matrix 3x3: the node's REST global rotation, glTF space (Godot)
        self.rest_o = {}                     # short name -> Vector: its REST origin, glTF space
        rows = {r["name"]: r for r in rest["bones"]}
        todo = list(rows)
        while todo:
            n = todo.pop(0)
            p = rows[n]["parent"]
            if p and p not in self.names:
                todo.append(n)
                continue
            self.names.append(n)
            self.parent[n] = p
            self.rest_g[n] = quat_xyzw(rows[n]["rest_quat"]).to_matrix()
            self.rest_o[n] = Vector(rows[n]["rest_origin"])
        self.R = {}                          # Blender bone REST rotation, armature space
        self.BB = {}
        worst_o = 0.0
        worst_bb = 0.0
        for n in self.names:
            b = arm.data.bones.get(PREFIX + n)
            if b is None:
                fail(f"the armature has no bone {PREFIX + n}")
            self.R[n] = b.matrix_local.to_3x3().normalized()
            self.BB[n] = self.rest_g[n].transposed() @ to_g(self.R[n])
            worst_o = max(worst_o, (CM @ b.matrix_local.translation - self.rest_o[n]).length)
            worst_bb = max(worst_bb, max(abs(self.BB[n][i][j] - (1.0 if i == j else 0.0)) for i in range(3) for j in range(3)))
        if worst_o > 1e-4:
            fail(f"the armature's bones are not where Godot's are (worst {worst_o:.6f}): another rig, or a transformed armature object")
        print(f"[tripo_pose_lab] rest data: {len(self.names)} bones, origins agree to {worst_o:.2e}, bone frame vs node frame differ by {worst_bb:.2e}")

    # ---- Godot local rotations -> pose bones ---------------------------------------------------------------------------------------------
    def apply(self, local):
        """`local`: short name -> mathutils Quaternion (Godot local rotation). Every bone not in it is left at rest."""
        P = {}
        G = {}
        for n in self.names:
            p = self.parent[n]
            gp = G[p] if p else Matrix.Identity(3)
            q = local.get(n)
            g = gp @ q.to_matrix() if q is not None else gp @ self.rest_local(n)
            G[n] = g
            P[n] = to_bl(g @ self.BB[n])
            rp = self.R[p] if p else Matrix.Identity(3)
            pp = P[p] if p else Matrix.Identity(3)
            delta = self.R[n].transposed() @ rp @ pp.transposed() @ P[n]
            pb = self.arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = delta.to_quaternion()
            pb.location = (0.0, 0.0, 0.0)
            pb.scale = (1.0, 1.0, 1.0)
        return G

    def rest_local(self, n):
        p = self.parent[n]
        return (self.rest_g[p].transposed() if p else Matrix.Identity(3)) @ self.rest_g[n]

    # ---- pose bones -> Godot local rotations ---------------------------------------------------------------------------------------------
    def read(self):
        """-> (short name -> Godot local Quaternion, short name -> node global rotation glTF Matrix 3x3), from the pose bones' rotations"""
        P = {}
        G = {}
        local = {}
        for n in self.names:
            p = self.parent[n]
            pb = self.arm.pose.bones[PREFIX + n]
            delta = pb.matrix_basis.to_3x3().normalized()
            rp = self.R[p] if p else Matrix.Identity(3)
            pp = P[p] if p else Matrix.Identity(3)
            P[n] = pp @ rp.transposed() @ self.R[n] @ delta
            G[n] = to_g(P[n]) @ self.BB[n].transposed()
            gp = G[p] if p else Matrix.Identity(3)
            local[n] = (gp.transposed() @ G[n]).to_quaternion()
        return local, G

    def node_global(self, n, G):
        """the bone's node pose transform in glTF space (4x4): its pose rotation, its head's pose position"""
        pb = self.arm.pose.bones[PREFIX + n]
        t = CM @ (self.arm.matrix_world @ pb.head)
        m = G[n].to_4x4()
        m.translation = t
        return m


def args_after_dashes():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def read_json(path):
    with open(path) as f:
        return json.load(f)


def find_arm():
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    if len(arms) != 1:
        fail(f"expected one armature, found {len(arms)}")
    return arms[0]


def load_rig_from_blend():
    arm = find_arm()
    if "lab_rest" not in arm:
        fail("this .blend was not made by pose_lab (no lab_rest on the armature)")
    return arm, Rig(arm, json.loads(arm["lab_rest"]))


# ------------------------------------------------------------------------------------------------------------------------------------------------
def prop_node_matrix(prop):
    """the model's mesh node transform in glTF space, read from the .glb. Its ROTATION counts as much as its scale: the pistol's node is turned -90 degrees about X, and a
    placement that ignored it came out a quarter turn off in the game, which instances the whole scene, while Blender looked right (2026-11-09)."""
    with open(PROP_GLB[prop], "rb") as f:
        f.read(12)
        size = struct.unpack("<I", f.read(4))[0]
        f.read(4)
        gltf = json.loads(f.read(size))
    nodes = [n for n in gltf["nodes"] if "mesh" in n]
    if len(nodes) != 1:
        fail(f"the {prop} model should have one mesh node, found {len(nodes)}")
    n = nodes[0]
    r = n.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = n.get("scale", [1.0, 1.0, 1.0])
    return Matrix.Translation(n.get("translation", [0.0, 0.0, 0.0])) @ quat_xyzw(r).to_matrix().to_4x4() @ Matrix.Diagonal((s[0], s[1], s[2], 1.0))


def prop_world_g(rig, G, bone, placement, node_m):
    """the prop mesh node's world transform in glTF space: bone node * placement (the model's scene root) * the mesh node's own transform"""
    node = rig.node_global(bone, G)
    pos = Vector(placement["pos"])
    q = quat_xyzw(placement["quat"])
    s = float(placement["scale"])
    local = Matrix.Translation(pos) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((s, s, s, 1.0))
    return node @ local @ node_m


def cm4():
    m = CM.to_4x4()
    return m


def g_to_blender_world(m):
    return cm4().inverted() @ m @ cm4()


def blender_world_to_g(m):
    return cm4() @ m @ cm4().inverted()


def import_prop(prop, node_scale_out):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=PROP_GLB[prop])
    new = [bpy.data.objects[k] for k in bpy.data.objects.keys() if k not in before]
    meshes = [o for o in new if o.type == 'MESH']
    if len(meshes) != 1:
        fail(f"the {prop} model should be one mesh object, found {len(meshes)}")
    mesh = meshes[0]
    node_scale = mesh.scale[0]
    for o in new:
        if o is not mesh and o.type == 'EMPTY':
            bpy.data.objects.remove(o)
    mesh.parent = None
    mesh.name = "PROP_" + prop
    node_scale_out["scale"] = node_scale
    return mesh, node_scale


def mesh_edit(obj, prop):
    """What was done to the prop's VERTICES in Edit Mode, as a 4x4 in the object's own frame (his vertices = M @ the model's); the identity when nothing was. Moving, turning or scaling the
    mesh inside its object leaves the object's matrix alone, so the placement read from that matrix alone puts the ORIGINAL model in the game, off by exactly that edit (2026-11-09: a
    43 degree turn in Edit Mode). Measured against the model itself, vertex for vertex: a uniform scale, a rotation and a translation."""
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=PROP_GLB[prop])
    new = [bpy.data.objects[k] for k in bpy.data.objects.keys() if k not in before]
    source = [o for o in new if o.type == 'MESH']
    his = numpy.array([v.co[:] for v in obj.data.vertices])
    model = numpy.array([v.co[:] for v in source[0].data.vertices]) if len(source) == 1 else numpy.zeros((0, 3))
    for o in new:
        bpy.data.objects.remove(o)
    if len(his) != len(model):
        print(f"[tripo_pose_lab] WARNING: the {prop} mesh has {len(his)} vertices and the model {len(model)}: an edit of its shape cannot reach the game, the placement ignores it")
        return Matrix.Identity(4)
    ch, cm = his.mean(axis=0), model.mean(axis=0)
    a, b = his - ch, model - cm
    u, s, vt = numpy.linalg.svd(b.T @ a)
    d = numpy.diag([1.0, 1.0, numpy.sign(numpy.linalg.det(vt.T @ u.T))])
    r = vt.T @ d @ u.T
    k = float(numpy.trace(numpy.diag(s) @ d) / (b ** 2).sum())
    t = ch - k * (r @ cm)
    worst = float(numpy.linalg.norm(his - (k * (r @ model.T).T + t), axis=1).max())
    size = float(numpy.linalg.norm(model.max(axis=0) - model.min(axis=0)))
    if worst > 1e-4 * size:
        print(f"[tripo_pose_lab] WARNING: the {prop} mesh was reshaped, not only moved (worst vertex {worst:.6f}): the game keeps the model's shape, the placement takes the closest fit")
    m = Matrix(r.tolist()).to_4x4()
    for i in range(3):
        for j in range(3):
            m[i][j] *= k
        m[i][3] = float(t[i])
    if float(numpy.abs(numpy.array(m) - numpy.eye(4)).max()) > 1e-5:
        angle = math.degrees(Matrix(r.tolist()).to_quaternion().angle)
        print(f"[tripo_pose_lab] {prop}: the mesh was edited inside its object (turned {angle:.2f} degrees, scaled x{k:.4f}, moved {float(numpy.linalg.norm(t - (ch - cm))):.5f}): carried into the placement")
    return m


def plain_colours():
    """The coat carries its push data in COLOR_0 (`ACTOR` D94) and Blender draws it as red / black / green paint. The game does not (a shader reads it), so the lab cuts the link: the
    materials show their own colour. Only the lab's view changes; the mesh data is untouched."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in list(mat.node_tree.nodes):
            if node.type in ('VERTEX_COLOR', 'ATTRIBUTE'):
                for out in node.outputs:
                    for link in list(out.links):
                        mat.node_tree.links.remove(link)


def build(figure, pose_id, dump_dir, out_blend, glb, prop_models):
    rest = read_json(os.path.join(dump_dir, f"{figure}_rest.json"))
    idle = read_json(os.path.join(dump_dir, f"{figure}_idle.json"))
    start = read_json(os.path.join(dump_dir, f"{figure}_{pose_id}_start.json"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = find_arm()
    if arm.animation_data:
        arm.animation_data_clear()
    for o in bpy.data.objects:
        if o.name in HIDE:
            o.hide_viewport = True
            o.hide_render = True
    plain_colours()
    rig = Rig(arm, rest)
    base = {n: quat_xyzw(q) for n, q in idle["bones"].items()}
    local = dict(base)
    for n, q in start["bones"].items():
        local[n] = quat_xyzw(q)
    G = rig.apply(local)
    hips = start.get("hips_pos", idle.get("hips_pos"))
    if hips is not None:                     # where the game holds the Hips; the prop is placed below from the bones, so it follows
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = CMT @ Vector(hips)
        h.matrix = m
    bpy.context.view_layer.update()
    arm["lab_figure"] = figure
    arm["lab_pose"] = pose_id
    arm["lab_rest"] = json.dumps(rest)
    arm["lab_base"] = json.dumps(idle["bones"])
    arm["lab_bones"] = json.dumps(sorted(start["bones"]))
    arm["lab_source"] = start.get("source", "?")
    arm["lab_props"] = json.dumps(sorted(start.get("props", {})))
    for prop, placement in start.get("props", {}).items():
        holder = {}
        obj, node_scale = import_prop(prop, holder)
        obj["lab_node_scale"] = node_scale
        obj["lab_bone"] = placement["bone"]
        world = g_to_blender_world(prop_world_g(rig, G, placement["bone"], placement, prop_node_matrix(prop)))
        bpy.context.view_layer.update()
        obj.parent = arm
        obj.parent_type = 'BONE'
        obj.parent_bone = PREFIX + placement["bone"]
        bpy.context.view_layer.update()
        obj.matrix_world = arm.matrix_world @ world
        print(f"[tripo_pose_lab] {prop}: node scale {node_scale}, placed on {placement['bone']}")
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend} ({figure} {pose_id}, from the {arm['lab_source']} pose)")


def extract(blend, out_json):
    bpy.ops.wm.open_mainfile(filepath=blend)
    arm, rig = load_rig_from_blend()
    bpy.context.view_layer.update()
    local, G = rig.read()
    base = {n: quat_xyzw(q) for n, q in json.loads(arm["lab_base"]).items()}
    named = set(json.loads(arm["lab_bones"]))
    for pb in arm.pose.bones:                # a joint is a rotation: the game plays rotations only (and the Hips' place), so a bone moved with G would land elsewhere there
        if pb.name != PREFIX + "Hips" and pb.location.length > 1e-4:
            print(f"[tripo_pose_lab] WARNING: {pb.name} was MOVED ({pb.location.length:.3f}) and the game ignores that: its joint will close there. Alt+G clears it; rotate instead")
    bones = {}
    for n in rig.names:
        moved = qdist(local[n], base[n]) > EPS_CHANGED
        if n in named or moved:
            bones[n] = xyzw(local[n])
    props = {}
    for prop in json.loads(arm["lab_props"]):
        obj = bpy.data.objects.get("PROP_" + prop)
        if obj is None:
            print(f"[tripo_pose_lab] WARNING: the prop {prop} is gone from the .blend: the pose keeps the default placement")
            continue
        bone = obj["lab_bone"]
        world_g = blender_world_to_g(arm.matrix_world.inverted() @ obj.matrix_world @ mesh_edit(obj, prop))
        local_m = rig.node_global(bone, G).inverted() @ world_g @ prop_node_matrix(prop).inverted()
        loc, rot, scl = local_m.decompose()
        if max(abs(scl[0] - scl[1]), abs(scl[1] - scl[2])) > 1e-3 * scl[0]:
            print(f"[tripo_pose_lab] WARNING: the {prop} was scaled unevenly ({tuple(scl)}): the pose file keeps one scale, the mean")
        props[prop] = {"bone": bone, "pos": [loc.x, loc.y, loc.z], "quat": xyzw(rot), "scale": (scl[0] + scl[1] + scl[2]) / 3.0}
    out = {"format": "infiltraitor-pose", "v": 1, "figure": arm["lab_figure"], "id": arm["lab_pose"], "bones": bones, "props": props}
    if arm.get("lab_whole_body"):            # a stance: the Hips' place is part of the pose
        out["hips_pos"] = list(CM @ arm.pose.bones[PREFIX + "Hips"].matrix.translation)
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(out, f, indent=1)
    moved = [n for n in bones if n not in named]
    print(f"[tripo_pose_lab] wrote {out_json}: {len(bones)} bones ({len(moved)} added by the Director: {moved}), props {sorted(props)}")


PASSING_MARKERS = ("in-between", "release", "follow")   # the throw flows through its release and follow-through (2026-11-12)
FINGER_NAMES = ("Index", "Middle", "Pinky", "Ring", "Thumb")


def is_finger(bone):
    """A finger joint (LeftHandIndex1 ...): a sequence stops at the palm, the fingers keep whatever the clip underneath plays (Director 2026-11-11: he finishes them by hand)."""
    return "Hand" in bone and any(f in bone for f in FINGER_NAMES)


def _gun_placement(arm, rig, G, gun, prop="pistol"):
    """The prop's placement against its bone for the frame the scene is on: the same maths `extract` uses."""
    bone = gun["lab_bone"]
    world_g = blender_world_to_g(arm.matrix_world.inverted() @ gun.matrix_world @ mesh_edit(gun, prop))
    local_m = rig.node_global(bone, G).inverted() @ world_g @ prop_node_matrix(prop).inverted()
    loc, rot, scl = local_m.decompose()
    return {"bone": bone, "pos": [loc.x, loc.y, loc.z], "quat": xyzw(rot), "scale": (scl[0] + scl[1] + scl[2]) / 3.0}


def _animated_keys(obj):
    """the shape keys of `obj` whose value is animated (the timeline drives them), by name"""
    sk = obj.data.shape_keys if obj.type == 'MESH' else None
    if sk is None or sk.animation_data is None or sk.animation_data.action is None:
        return []
    act = sk.animation_data.action
    curves = [fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
    return sorted({fc.data_path.split('"')[1] for fc in curves if fc.data_path.startswith("key_blocks[")})


def sequence(blend, name, seq_json, poses_dir):
    """THE DIRECTOR'S TIMELINE (2026-11-10): a .blend whose armature action is keyed along a timeline (`SEQ_<name>_<FIG>.blend`: idle, draw, ..., aim) read back as
    a sequence for `ActorMesh3D`. Every frame the ARMATURE has a key on is a STOP (a pose file `seq_<name>_f<frame>.json`, the same format `extract` writes), placed on the
    path at weight (frame - first) / (last - first); the first frame is the pose the player wrote (no stop). A stop rests unless it is unmarked or its timeline marker is in
    `PASSING_MARKERS` (the arms flow through it, `ActorAimPose3D`'s passing stop); the last always rests. The pistol's placement and visibility and the coat's `DrawFix`
    are sampled at EVERY frame (their own keys, whatever frames those fall on) and played linearly between samples."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    base = {n: quat_xyzw(q) for n, q in json.loads(arm["lab_base"]).items()}
    named = set(json.loads(arm["lab_bones"]))
    prop = (json.loads(arm.get("lab_props", "[]")) or ["pistol"])[0]
    gun = bpy.data.objects["PROP_" + prop]
    # the THROW keeps the fingers (Director 2026-11-12: he places them round the grenade on this timeline); the draw leaves them to the clip underneath
    fingers = name.startswith("throw")
    coat_key = next((o.data.shape_keys.key_blocks["DrawFix"] for o in bpy.data.objects if o.type == 'MESH' and o.data.shape_keys and "DrawFix" in o.data.shape_keys.key_blocks), None)
    coat_obj = bpy.data.objects.get("Outfit_Coat")
    morphs = [k for k in (_animated_keys(coat_obj) if coat_obj is not None else []) if k != "DrawFix"]
    if coat_key is None:
        print("[tripo_pose_lab] no 'DrawFix' morph in this .blend: the coat stays closed through the sequence")
    action = arm.animation_data.action
    keyed = sorted({round(k.co[0]) for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves for k in fc.keyframe_points})
    first, last = sc.frame_start, sc.frame_end
    markers = {m.frame: m.name for m in sc.timeline_markers}
    figure = arm["lab_figure"]
    os.makedirs(poses_dir, exist_ok=True)
    stops, samples = [], []
    for f in range(first, last + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        local, G = rig.read()
        samples.append({"frame": f, "coat": coat_key.value if coat_key is not None else 0.0, "visible": not gun.hide_viewport, "gun": _gun_placement(arm, rig, G, gun, prop),
                        "morphs": {k: coat_obj.data.shape_keys.key_blocks[k].value for k in morphs}})
        if f not in keyed or f == first:
            continue
        pose_id = f"seq_{name}_f{f}"
        bones = {n: xyzw(local[n]) for n in rig.names if (n in named or qdist(local[n], base[n]) > EPS_CHANGED or fingers) and (fingers or not is_finger(n))}
        out = {"format": "infiltraitor-pose", "v": 1, "figure": figure, "id": pose_id, "bones": bones,
               "props": {prop: samples[-1]["gun"]}, "hips_pos": list(CM @ arm.pose.bones[PREFIX + "Hips"].matrix.translation)}
        with open(os.path.join(poses_dir, pose_id + ".json"), "w") as fh:
            json.dump(out, fh, indent=1)
        passing = f != last and (f not in markers or markers[f] in PASSING_MARKERS)
        stops.append({"id": pose_id, "frame": f, "weight": (f - first) / float(last - first), "passing": passing})
    shown = next((x["gun"] for x in samples if x["visible"]), None)
    for x in samples:    # a hidden object is not re-evaluated by Blender: its sampled placement is stale, and the game reads it between a hidden frame and the next one
        if not x["visible"] and shown is not None:
            x["gun"] = shown
    seq = {"format": "infiltraitor-sequence", "v": 1, "figure": figure, "name": name, "fps": sc.render.fps, "first": first, "last": last, "stops": stops, "samples": samples,
           "prop": prop, "markers": {n: f for f, n in sorted(markers.items())}, "morphs": morphs}
    os.makedirs(os.path.dirname(seq_json), exist_ok=True)
    with open(seq_json, "w") as fh:
        json.dump(seq, fh, indent=1)
    print(f"[tripo_pose_lab] wrote {seq_json}: {len(stops)} stops {[(s['frame'], 'passing' if s['passing'] else 'rests') for s in stops]}, {len(samples)} samples, {sc.render.fps} fps")


def sequence_new(pose_blend, idle_json, draw_json, aim_json, out_blend, mid_at):
    """THE STARTING TIMELINE of a figure that has none (2026-11-10): the male's `SEQ_*` was the Director's to edit, and the female's starts as a plain version of it, to be edited the
    same way. Built from the figure's `POSE_<draw>` .blend (the LIGHT Agent, the pistol, the lab data), saved under another name: frames 1-23, markers idle 1 / draw 12 / in-between 17 /
    aim 23; the idle pose at 1, his draw pose (`poses/<figure>/draw_pistol.json`) at 12, the in-between `mid_at` of the way to his aim pose at 17 (no foot lift: that is his to pose),
    the aim at 23. `PROP_pistol` is hidden through 12 and in the hand from 13 (the draw's placement, then the blend, then the aim's); `DrawFix` is keyed when the coat has the morph."""
    bpy.ops.wm.open_mainfile(filepath=pose_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    idle, draw, aim = read_json(idle_json), read_json(draw_json), read_json(aim_json)
    base = {n: quat_xyzw(q) for n, q in idle["bones"].items()}

    def local_of(pose):
        out = dict(base)
        for n, q in pose["bones"].items():
            out[n] = quat_xyzw(q)
        return out

    L_idle, L_draw, L_aim = dict(base), local_of(draw), local_of(aim)
    L_mid = {n: L_draw[n].slerp(L_aim[n], mid_at) for n in L_draw}
    hips = {"idle": Vector(idle["hips_pos"]), "draw": Vector(draw["hips_pos"]), "aim": Vector(aim["hips_pos"])}
    hips["mid"] = hips["draw"].lerp(hips["aim"], mid_at)
    pl_draw, pl_aim = draw["props"]["pistol"], aim["props"]["pistol"]
    pl_mid = {"bone": pl_draw["bone"], "pos": list(Vector(pl_draw["pos"]).lerp(Vector(pl_aim["pos"]), mid_at)), "scale": pl_draw["scale"] + (pl_aim["scale"] - pl_draw["scale"]) * mid_at,
              "quat": xyzw(quat_xyzw(pl_draw["quat"]).slerp(quat_xyzw(pl_aim["quat"]), mid_at))}
    gun = bpy.data.objects["PROP_pistol"]
    gun.rotation_mode = 'QUATERNION'
    coat_key = next((o.data.shape_keys.key_blocks["DrawFix"] for o in bpy.data.objects if o.type == 'MESH' and o.data.shape_keys and "DrawFix" in o.data.shape_keys.key_blocks), None)
    node_m = prop_node_matrix("pistol")
    if arm.animation_data:
        arm.animation_data_clear()
    gun.animation_data_clear()
    bpy.ops.object.mode_set(mode='OBJECT')

    def settle(local, hips_pos, placement, visible):
        """The body and the gun as the pose has them, read off BEFORE any key exists (a key on the armature makes every later update re-read the animation over what was just set)."""
        G = rig.apply(local)
        bpy.context.view_layer.update()   # the Hips' matrix is read next: stale it would carry the PREVIOUS pose's rotation into this one
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = CMT @ hips_pos
        h.matrix = m
        bpy.context.view_layer.update()
        gun.matrix_world = arm.matrix_world @ g_to_blender_world(prop_world_g(rig, G, placement["bone"], placement, node_m))
        bpy.context.view_layer.update()
        return {"bones": {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}, "hips": h.location.copy(),
                "gun": (gun.location.copy(), gun.rotation_quaternion.copy(), gun.scale.copy()), "visible": visible}

    plan = [(1, L_idle, hips["idle"], pl_draw, False), (12, L_draw, hips["draw"], pl_draw, False), (13, L_draw, hips["draw"], pl_draw, True),
            (17, L_mid, hips["mid"], pl_mid, True), (23, L_aim, hips["aim"], pl_aim, True)]
    body_frames = {1, 12, 17, 23}
    settled = [(frame, settle(local, hips_pos, placement, visible)) for frame, local, hips_pos, placement, visible in plan]
    for frame, st in settled:
        if frame in body_frames:
            for pb in arm.pose.bones:
                pb.rotation_mode = 'QUATERNION'
                pb.rotation_quaternion = st["bones"][pb.name]
                pb.keyframe_insert("rotation_quaternion", frame=frame)
            hips_bone = arm.pose.bones[PREFIX + "Hips"]
            hips_bone.location = st["hips"]
            hips_bone.keyframe_insert("location", frame=frame)
        gun.location, gun.rotation_quaternion, gun.scale = st["gun"]
        gun.hide_viewport = gun.hide_render = not st["visible"]
        for path in ("location", "rotation_quaternion", "scale", "hide_viewport", "hide_render"):
            gun.keyframe_insert(path, frame=frame)
    if coat_key is not None:
        for frame, value in ((1, 0.0), (12, 1.0), (17, 0.05), (18, 0.0), (23, 0.0)):
            coat_key.value = value
            coat_key.keyframe_insert("value", frame=frame)
    else:
        print("[tripo_pose_lab] no 'DrawFix' morph in this figure's coat: the coat is not keyed (its lapel is still to be made)")
    sc.frame_start, sc.frame_end = 1, 23
    for name, frame in (("idle", 1), ("draw", 12), ("in-between", 17), ("aim", 23)):
        sc.timeline_markers.new(name, frame=frame)
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} draw on one timeline (frames 1-23, in-between {mid_at} of the way)")


# ---- THE THROW (MOVEMENT, 2026-11-12; PROMPTS/THROW_STUDY_2026-11-12.md) ------------------------------------------------------------------------------------------------
# The starting timeline of the standing OVERHAND throw, cut from the bank's `pitch_baseball` (the only throwing arm we hold) and remade where the study says: no knee lift,
# no held lunge, a short lead step, a shallow dip. The arms, spine and head are the clip's (turned so the release goes along the figure's forward); the LEGS are solved
# (two-bone IK) to feet that step a fraction of the pitcher's stride; the fingers keep the idle's curl (never keyed: the Director, 2026-11-12). The Director refines it by hand.
LEG_BONES = ("UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")
# ONE timeline (Director, 2026-11-12: split in two, then back to one so the coat is fixed once): idle -> cocked (held in play while the Agent turns in place to the
# aimed cell; the cancel plays this stretch backwards) -> in-between -> release -> follow -> idle. (timeline frame, clip frame or None for the idle, marker); the
# grenade's last shown frame.
THROW_PARTS = {
    "overhand": (((1, None, "idle"), (9, 39, "cocked"), (12, 42, "in-between"), (15, 44, "release"), (18, 48, "follow"), (26, None, "idle")), 15),
}
# THE COAT'S KEYS (Director, 2026-11-12: "não dá pra criar keyframes no casaco também, na mesma timeline?"): one shape key per pose, `ThrowFix_f<frame>`, created
# empty (a copy of the Basis) and keyed 1 on its own frame, 0 on the poses around it. Fixing the coat at a pose = select that pose's key, edit; nothing to key by hand.
COAT_OBJECT = "Outfit_Coat"
THROW_STEP = 0.6       # the pitcher's stance (feet against the hips, at the follow-through), narrowed to this
FOLLOW_FRAME = 48      # the clip frame whose stance the feet keep
RELEASE_FRAME = 44     # the clip frame of the release (the hand's top speed)
THROW_TRAVEL = 0.5     # of the hips' forward travel
THROW_DIP = 0.35       # of the hips' drop
GRENADE_SIZE = 0.055   # the model's largest side, in figure heights (a real grenade on a 1.8 m man)


def _clip_frames(arm, clip_glb, frames):
    """{clip frame: {short name: (armature-space rotation 3x3, head position)}} for the frames asked, with the Hips' translation in this figure's metres (the bank keeps it
    divided by the source's hip height, as `tripo_bank_sheets.play` undoes)."""
    hip_h = (arm.matrix_world @ arm.data.bones[PREFIX + "Hips"].head_local).z
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=clip_glb)
    act = [a for a in bpy.data.actions if a not in before_a][0]
    for o in [o for o in bpy.data.objects if o not in before_o]:
        bpy.data.objects.remove(o)
    curves = [fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
    for fc in curves:
        if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
            for kp in fc.keyframe_points:
                kp.co.y *= hip_h; kp.handle_left.y *= hip_h; kp.handle_right.y *= hip_h
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    out = {}
    for f in frames:
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        out[f] = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    ad.action = None
    bpy.data.actions.remove(act)
    return out


def _two_bone(hip, target, a, b, pole):
    """The knee of a two-bone chain from `hip` reaching `target` (thigh `a`, shin `b`), bent toward `pole`."""
    d_vec = target - hip
    d = min(d_vec.length, (a + b) * 0.999)
    u = d_vec.normalized()
    x = (a * a - b * b + d * d) / (2.0 * d)
    h = math.sqrt(max(a * a - x * x, 0.0))
    side = (pole - hip) - u * (pole - hip).dot(u)
    side = side.normalized() if side.length > 1e-6 else Vector((0, -1, 0))
    return hip + u * x + side * h, hip + u * d


def _aim_bone(P_clip, head, tail):
    """`P_clip` turned the least so the bone's axis (Blender: local +Y) runs head -> tail."""
    axis = (P_clip @ Vector((0, 1, 0))).normalized()
    return (axis.rotation_difference((tail - head).normalized()).to_matrix() @ P_clip).normalized()


def throw_new(base_blend, clip_glb, out_blend, part):
    """THE STARTING TIMELINE OF THE OVERHAND THROW of one figure, built from its draw timeline (`SEQ_draw_pistol_<FIG>.blend`: the LIGHT Agent, the lab data, frame 1 = the
    game's idle with its Hips) and the bank's `pitch_baseball`. Frames 1-26 at the base's fps, markers per `THROW_PLAN` (the in-between is a passing stop), the grenade
    (`PROP_grenade`) on the right hand until the release frame. The draw's pistol, coat keys and armature keys are dropped; nothing is written over the base file."""
    THROW_PLAN, shown_until = THROW_PARTS[part]
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    sc.frame_set(1)
    bpy.context.view_layer.update()
    idle = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    idle_q = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    hips_idle = idle["Hips"][1]
    arm.animation_data_clear()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    clip_frames = sorted({c for plan, _s in THROW_PARTS.values() for _f, c, _m in plan if c is not None} | {0, FOLLOW_FRAME, RELEASE_FRAME})
    clip = _clip_frames(arm, clip_glb, clip_frames)
    # turn the clip so the release runs along the figure's forward (the idle's heel -> toe, both feet)
    fwd = sum(((idle[s + "ToeBase"][1] - idle[s + "Foot"][1]) for s in ("Left", "Right")), Vector())
    fwd.z = 0.0
    fwd.normalize()
    # the throw's direction = from the hips to the hand at the release (Director 2026-11-12: the hand's VELOCITY there runs ~40 deg across the body, so a throw
    # turned by it left the grenade going 45 deg off the figure's facing)
    rel = clip[RELEASE_FRAME]["RightHand"][1] - clip[RELEASE_FRAME]["Hips"][1]
    rel.z = 0.0
    yaw = math.atan2(fwd.y, fwd.x) - math.atan2(rel.y, rel.x)
    Rz = Matrix.Rotation(yaw, 3, 'Z')
    c0 = clip[0]["Hips"][1]
    def turned(f, n):
        P, head = clip[f][n]
        return (Rz @ P).normalized(), c0 + Rz @ (head - c0)
    thigh = {s: (idle[s + "Leg"][1] - idle[s + "UpLeg"][1]).length for s in ("Left", "Right")}
    shin = {s: (idle[s + "Foot"][1] - idle[s + "Leg"][1]).length for s in ("Left", "Right")}
    plant = {}
    hips_f = turned(FOLLOW_FRAME, "Hips")[1]
    df = hips_f - turned(0, "Hips")[1]
    hips_follow = hips_idle + Vector((df.x * THROW_TRAVEL, df.y * THROW_TRAVEL, df.z * THROW_DIP))
    for s in ("Left", "Right"):
        rel = turned(FOLLOW_FRAME, s + "Foot")[1] - hips_f
        plant[s] = Vector((hips_follow.x + rel.x * THROW_STEP, hips_follow.y + rel.y * THROW_STEP, idle[s + "Foot"][1].z))
    poses = {}
    for frame, cf, _marker in THROW_PLAN:
        if cf is None:
            continue
        P = {}
        for n in rig.names:
            P[n] = turned(cf, n)[0]
        hips_c = turned(cf, "Hips")[1]
        hips0 = turned(0, "Hips")[1]
        d = hips_c - hips0
        hips = hips_idle + Vector((d.x * THROW_TRAVEL, d.y * THROW_TRAVEL, d.z * THROW_DIP))
        # the legs: the feet are PLANTED for the whole throw where the clip's follow-through has them against its hips (side-on, the pitcher's stance), the
        # stance narrowed to THROW_STEP and hung under OUR hips; the step itself is the idle -> cocked interpolation. The knees are solved to them, bent the clip's way.
        for s in ("Left", "Right"):
            off = rig.R["Hips"].transposed() @ (arm.data.bones[PREFIX + s + "UpLeg"].head_local - arm.data.bones[PREFIX + "Hips"].head_local)
            hip_j = hips + P["Hips"] @ off
            target = plant[s]
            knee_c = turned(cf, s + "Leg")[1]
            pole = hip_j + (knee_c - turned(cf, s + "UpLeg")[1]) * 2.0
            knee, foot = _two_bone(hip_j, target, thigh[s], shin[s], pole)
            P[s + "UpLeg"] = _aim_bone(P[s + "UpLeg"], hip_j, knee)
            P[s + "Leg"] = _aim_bone(P[s + "Leg"], knee, foot)
            for n in (s + "Foot", s + "ToeBase", s + "Toe_End"):
                if n in P:
                    P[n] = turned(FOLLOW_FRAME, n)[0]
        poses[frame] = (P, hips)
    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    def key(frame, P, hips):
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            if P is None or is_finger(n):
                pb.rotation_quaternion = idle_q[pb.name]
            else:
                p = rig.parent[n]
                rp = rig.R[p] if p else Matrix.Identity(3)
                pp = P[p] if p else Matrix.Identity(3)
                pb.rotation_quaternion = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips
        h.matrix = m
        h.keyframe_insert("location", frame=frame)

    for frame, cf, _marker in THROW_PLAN:
        sc.frame_set(frame)
        if cf is None:
            key(frame, None, hips_idle)
        else:
            key(frame, *poses[frame])
    sc.timeline_markers.clear()          # the base's own markers (the draw's) do not belong to the throw
    for frame, _cf, marker in THROW_PLAN:
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = THROW_PLAN[0][0], THROW_PLAN[-1][0]
    # the grenade in the right palm, shown until the release
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=PROP_GLB["grenade"])
    new = [o for o in bpy.data.objects if o not in before]
    gren = next(o for o in new if o.type == 'MESH')
    mw = gren.matrix_world.copy()
    gren.parent = None
    gren.matrix_world = mw
    for o in new:
        if o is not gren:
            bpy.data.objects.remove(o)
    gren.name = "PROP_grenade"
    gren["lab_node_scale"] = gren.scale[0]
    gren["lab_bone"] = "RightHand"
    height = max(v[1].z for v in idle.values()) - min(v[1].z for v in idle.values())
    gren.scale = gren.scale * (GRENADE_SIZE * height / max(gren.dimensions))
    sc.frame_set(1)
    bpy.context.view_layer.update()
    hand = arm.pose.bones[PREFIX + "RightHand"]
    palm = (arm.pose.bones[PREFIX + "RightHandMiddle1"].head + hand.head) * 0.5
    gren.parent = arm
    gren.parent_type = 'BONE'
    gren.parent_bone = PREFIX + "RightHand"
    bpy.context.view_layer.update()
    gm = gren.matrix_world.copy()
    gm.translation = arm.matrix_world @ palm
    gren.matrix_world = gm
    last = THROW_PLAN[-1][0]
    keys = [(1, True), (shown_until, True)] + ([(shown_until + 1, False), (last, False)] if shown_until < last else [])
    for frame, shown in keys:
        gren.hide_viewport = gren.hide_render = not shown
        gren.keyframe_insert("hide_viewport", frame=frame)
        gren.keyframe_insert("hide_render", frame=frame)
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        frames = [f for f, _c, _m in THROW_PLAN]
        for i, (frame, cf, _marker) in enumerate(THROW_PLAN):
            if cf is None:
                continue
            kb = coat.shape_key_add(name=f"ThrowFix_f{frame:02d}", from_mix=False)
            for f2, v in ((frames[i - 1], 0.0), (frame, 1.0), (frames[i + 1], 0.0)):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        # the first pose's key is the ACTIVE one, so an Edit Mode edit lands in a throw key (2026-11-12: the male's first edit went into the draw's DrawFix,
        # left active by the base file, where this timeline never shows it)
        coat.active_shape_key_index = list(coat.data.shape_keys.key_blocks.keys()).index(next(k.name for k in coat.data.shape_keys.key_blocks if k.name.startswith("ThrowFix")))
    arm["lab_pose"] = "throw_" + part
    arm["lab_props"] = json.dumps(["grenade"])
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} overhand {part}, frames 1-{last}, clip turned {math.degrees(yaw):.1f} deg, "
          f"step {THROW_STEP}, travel {THROW_TRAVEL}, dip {THROW_DIP}")


def reset_fingers(blend, side):
    """Puts the finger joints of one hand (`side` Left|Right) of a timeline .blend back to the GAME's idle fingers (`lab_base`) on every key they have (2026-11-11, the Director's request:
    he finishes the fingers by hand, starting from what the game plays under a sequence). Only the existing keys' values change, never their frames; the file is saved in place."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    arm, rig = load_rig_from_blend()
    base = {n: quat_xyzw(q) for n, q in json.loads(arm["lab_base"]).items()}
    fingers = [n for n in rig.names if n.startswith(side) and is_finger(n)]
    bpy.ops.object.mode_set(mode='OBJECT')
    sc = bpy.context.scene
    keyed_frames = sorted({round(k.co[0]) for l in arm.animation_data.action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves for k in fc.keyframe_points})
    sc.frame_set(keyed_frames[0])
    rig.apply({n: base[n] for n in rig.names})        # the idle in Blender's own terms: a finger's delta depends on its own local rotation only
    bpy.context.view_layer.update()
    idle = {PREFIX + n: arm.pose.bones[PREFIX + n].rotation_quaternion.copy() for n in fingers}
    changed = 0
    for l in arm.animation_data.action.layers:
        for strip in l.strips:
            for cb in strip.channelbags:
                for fc in cb.fcurves:
                    if not fc.data_path.endswith("rotation_quaternion") or '"' not in fc.data_path:
                        continue
                    bone = fc.data_path.split('"')[1]
                    if bone not in idle:
                        continue
                    for k in fc.keyframe_points:
                        d = idle[bone][fc.array_index] - k.co[1]
                        k.co[1] += d
                        k.handle_left[1] += d
                        k.handle_right[1] += d
                        changed += 1
                    fc.update()
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.wm.save_mainfile()
    print(f"[tripo_pose_lab] {blend}: {len(fingers)} {side} finger joints back to the game's idle ({changed} key values)")


def refresh_prop(blend, prop):
    """Gives a timeline .blend the prop's CURRENT model (2026-11-11): a .blend built before the model was baked to its held size (the female's, made 2026-11-08) keeps the old mesh, so
    the pistol looks a sixth of the size and `mesh_edit` folds that into a 0.167 scale the game then plays. The object, its keys and its parenting stay; only the mesh data is swapped."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    obj = bpy.data.objects["PROP_" + prop]
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=PROP_GLB[prop])
    new = [bpy.data.objects[k] for k in bpy.data.objects.keys() if k not in before]
    source = [o for o in new if o.type == 'MESH']
    if len(source) != 1:
        fail(f"the {prop} model should be one mesh object, found {len(source)}")
    old = obj.data
    obj.data = source[0].data
    obj["lab_node_scale"] = source[0].scale[0]
    for o in new:
        bpy.data.objects.remove(o)
    if old.users == 0:
        bpy.data.meshes.remove(old)
    print(f"[tripo_pose_lab] {prop}: mesh swapped for the model's current one, object now {tuple(round(x, 4) for x in obj.dimensions)}")
    bpy.ops.wm.save_mainfile()


def render(blend, out_png):
    bpy.ops.wm.open_mainfile(filepath=blend)
    scn = bpy.context.scene
    scn.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items.keys() else 'BLENDER_EEVEE_NEXT'
    scn.render.resolution_x, scn.render.resolution_y = 900, 900
    world = bpy.data.worlds.new("w") if not scn.world else scn.world
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.45, 0.5, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 85
    scn.collection.objects.link(cam)
    scn.camera = cam
    target = Vector((0.0, -0.12, 0.5))
    views = [("front34", 35.0, 12.0, 3.0), ("side", 90.0, 8.0, 3.0)]
    base, ext = os.path.splitext(out_png)
    for name, az, el, dist in views:
        a = math.radians(az)
        e = math.radians(el)
        cam.location = target + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
        direction = target - cam.location
        cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
        scn.render.filepath = f"{base}_{name}{ext}"
        bpy.ops.render.render(write_still=True)
        print(f"[tripo_pose_lab] rendered {scn.render.filepath}")


def main():
    a = args_after_dashes()
    if not a:
        fail("usage: -- build|extract|render ...")
    mode = a[0]
    if mode == "build":
        figure, pose_id, dump_dir, out = a[1:5]
        glb = LIGHT_GLB % figure.upper()
        build(figure, pose_id, dump_dir, out, glb, PROP_GLB)
    elif mode == "extract":
        extract(a[1], a[2])
    elif mode == "refresh_prop":
        refresh_prop(a[1], a[2])
    elif mode == "reset_fingers":
        reset_fingers(a[1], a[2])
    elif mode == "sequence_new":
        sequence_new(a[1], a[2], a[3], a[4], a[5], float(a[6]))
    elif mode == "throw_new":
        throw_new(a[1], a[2], a[3], a[4])
    elif mode == "sequence":
        sequence(a[1], a[2], a[3], a[4])
    elif mode == "render":
        render(a[1], a[2])
    else:
        fail(f"unknown mode {mode}")


if __name__ == "__main__":
    main()
