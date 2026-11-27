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
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
import model_paths as mp  # where every model lives (ASSETS/MODELS layout)
import bpy, sys, json, math, os, re, struct
import numpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LIGHT_GLB = None   # mp.agent(figure, "game", ...)
PROP_GLB = {"pistol": os.path.join(ROOT, "ASSETS", "props", "pistol_quaternius", "pistol.glb"),
            "grenade": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "quaternius_grenade", "Grenade.glb"),
            "shotgun": os.path.join(ROOT, "ASSETS", "props", "shotgun", "shotgun.glb"),   # the game's model (weapons/shotgun.json), the pack's `Shotgun.glb` byte for byte
            # a long gun with a draw of its own (2026-11-24, `family_lab.py seq`): its pack source until the H3 rows copy it into ASSETS/props/<id>/
            "bullpup": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "quaternius_ultimate_guns_pack", "extracted", "Bullpup.glb"),
            # the two stockless shotguns, each with a draw of its own (2026-11-24, the Director: "abrir as duas shotguns de cano curto ... e fazer agora")
            "shotgun_sawed_off": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "quaternius_ultimate_guns_pack", "extracted",
                                              "Shotgun Sawed Off.glb"),
            # the game's model (2026-11-26): the pack's `Shotgun Short Stock.glb` with its ejection port closed by a black floor
            # (`glb_close_opening.py`; the Director: "poe o fundo preto na janela e pode instalar")
            "shotgun_short_stock": os.path.join(ROOT, "ASSETS", "props", "shotgun_short_stock", "shotgun_short_stock.glb"),
            # the pack's other PUMP shotgun, a draw of its own (2026-11-26, the Director: "Para as outras shotguns que tem a bomba, usamos o mesmo
            # mecanismo, adaptando onde for necessário"): its pack source until an H3 row copies it into ASSETS/props/<id>/
            "shotgun_zmptnh7njl": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "quaternius_ultimate_guns_pack", "extracted",
                                               "Shotgun-ZmPTnh7njL.glb"),
            # the sci-fi sniper, a grip of its own (2026-11-25, the Director: "montar a cena completa só da 17 com draw, hip e aim")
            # the three grenade launchers (2026-11-27, the Director: sizes set in FAMILY_H3_LAUNCHERS_hip_MALE.blend; no aim, the hip only, a draw of
            # their own from beside the waist): their pack sources until an H3 row copies them into ASSETS/props/<id>/
            "grenade_launcher_zkvwhvu4tv": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "items_polypizza", "launchers",
                                                        "Grenade_Launcher-ZKvWhvu4tV.glb"),
            "grenade_launcher_phmpzcngoa": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "items_polypizza", "launchers",
                                                        "Grenade_Launcher-phmPZCnGOA.glb"),
            "scifi_grenade_launcher_r10gkf9yds": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "items_polypizza",
                                                              "launchers", "Scifi_Grenade_Launcher-r10Gkf9yDs.glb"),
            "scifi_sniper_vu7qizyae0": os.path.join(ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models", "items_polypizza", "scifi",
                                                    "Scifi_Sniper-VU7QiZYae0.glb"),
            "scifi_sniper_46615jyfm7": os.path.join(ROOT, "ASSETS", "props", "scifi_sniper_46615jyfm7",   # the pack model joined into one mesh
                                                    "scifi_sniper_46615jyfm7.glb")}
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


PASSING_MARKERS = ("in-between", "release", "follow", "centre")   # the throw flows through its release and follow-through (2026-11-12); the long gun's draw through its centre (2026-11-18)
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


BORROWED = re.compile(r"^(.+Fix)_f\d+ \((?:inherited|next)\)$")
SINGLE_KEYS = ("DrawFix",)   ## one key for a whole clip, named so in the game


def game_key(name):
    """The game's name of a timeline coat key (2026-11-15): every key carries its frame (`CrouchFix_f16`); a key borrowed from the previous /
    next clip carries THAT clip's frame plus ` (inherited)` / ` (next)` (`IdleFix_f90 (inherited)`) and is that clip's own key in the game, so it
    goes out by its base name, as does a clip's single key (`DrawFix_f12` -> `DrawFix`). See coat_key_follow.py."""
    m = BORROWED.match(name)
    if m:
        return m.group(1) if m.group(1) in ("IdleFix", "RunFix", "WalkFix") else name.split(" (")[0]   ## a borrowed pose key keeps its frame (`CrouchFix_f16`)
    base = re.sub(r"_f\d+$", "", name)
    return base if base in SINGLE_KEYS else name


def _draw_key():
    """the clip's DrawFix key, whatever frame its name carries"""
    return next((k for o in bpy.data.objects if o.type == 'MESH' and o.data.shape_keys for k in o.data.shape_keys.key_blocks if game_key(k.name) == "DrawFix"), None)


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
    # the THROW keeps the fingers (Director 2026-11-12: he places them round the grenade on this timeline), and so does a LONG GUN's draw (2026-11-18: the left
    # hand's fingers round the fore-end); the pistol's draw leaves them to the clip underneath
    fingers = name.startswith("throw") or name in LONG_GUN_SEQUENCES
    coat_key = _draw_key()
    coat_obj = bpy.data.objects.get("Outfit_Coat")
    morphs = [k for k in (_animated_keys(coat_obj) if coat_obj is not None else []) if game_key(k) != "DrawFix"]
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
                        "morphs": {game_key(k): coat_obj.data.shape_keys.key_blocks[k].value for k in morphs}})
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
           "prop": prop, "markers": {n: f for f, n in sorted(markers.items())}, "morphs": [game_key(k) for k in morphs]}
    os.makedirs(os.path.dirname(seq_json), exist_ok=True)
    with open(seq_json, "w") as fh:
        json.dump(seq, fh, indent=1)
    print(f"[tripo_pose_lab] wrote {seq_json}: {len(stops)} stops {[(s['frame'], 'passing' if s['passing'] else 'rests') for s in stops]}, {len(samples)} samples, {sc.render.fps} fps")


def embed_coat_follow():
    """Put coat_key_follow.py into the open .blend as a module text, so the active coat key follows the playhead."""
    import importlib.util
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "coat_key_follow.py")
    spec = importlib.util.spec_from_file_location("coat_key_follow", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.add_to_blend()


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
    coat_key = _draw_key()
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
    embed_coat_follow()   ## the coat's per-frame keys follow the timeline (coat_key_follow.py)
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
    embed_coat_follow()   ## the coat's per-frame keys follow the timeline (coat_key_follow.py)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} overhand {part}, frames 1-{last}, clip turned {math.degrees(yaw):.1f} deg, "
          f"step {THROW_STEP}, travel {THROW_TRAVEL}, dip {THROW_DIP}")


# ---- THE LONG GUNS' DRAW (MOVEMENT §11.6 step 3, Director 2026-11-18) ------------------------------------------------------------------------------------------------
# The shotgun, the rifles and the sniper hide VERTICALLY behind the coat's RIGHT flap (the pistol behind the left one), the barrel up and the trigger down. The draw,
# from the idle: the left hand goes into the right lapel while the right hand lifts it (the pistol's draw mirrored); the left hand takes the barrel, from its middle
# to its tip, behind the flap, and pulls it out; the gun comes to the centre, in front of the tie, held by the tip, and the right hand lets the lapel go; the left
# hand turns it from vertical to horizontal, the barrel forward, while the right hand finds the grip and the trigger below: the HIP shot's stance. The AIMED shot
# (one AP more, GAMEPLAY-01) goes on from there to the shoulder.
# THE STARTING TIMELINE built here, for the Director to pose by hand: the lapel stop is the figure's pistol draw stop MIRRORED (its change from the idle, the legs
# and the hips' place kept); the pull, the centre, the hip and the aim PLACE the gun and SOLVE both arms to it (two-bone IK), each hand holding it the way the bank
# `fire` frame holds a long gun (its rotation and offset against the line between the palms, and its fingers); the trunk turns right for the hip and the aim (the
# left shoulder forward), the head back toward the front. The gun (`PROP_<gun>`) rides the LEFT hand, the one that takes it out and turns it; it shows from
# `LONG_GUN_SHOWN_FROM`. The coat gets one EMPTY key per pose, `LongDrawFix_f<frame>` (the throw's way): opening the right flap is the Director's.
# One stop between the lapel and the hip (Director, 2026-11-18: "o pull e o center são a mesma coisa"): the gun comes out and to the centre in one move.
LONG_DRAW_PLAN = ((1, "idle"), (12, "lapel"), (16, "centre"), (23, "hip"), (31, "aim"))
LONG_GUN_SHOWN_FROM = 13
LONG_GUN_FACTOR = 0.085        # the pack's native units -> the figure's: the shotgun ~1 m long. At the pistol's 0.0600 its stock stops short of the shoulder
LONG_GRIP_FRAME = 12           # the bank `fire` frame (0.5 s) whose hands hold a long gun
LONG_HOLD_AT = 0.82            # where the left hand takes the barrel for the draw, as a fraction of the length from the butt ("do meio pra ponta")
LONG_PUMP_AT = 0.2             # where along the fore-end the left hand holds at the hip and the aim, from its rear
LONG_TWIST_DEG = {"hip": -30.0, "aim": -35.0}   # the trunk's turn, about +Z (negative: the facing, -Y, turns toward the figure's right, -X)
LONG_HEAD_BACK = {"hip": 0.75, "aim": 0.85}     # how much of that turn the neck gives back, so the head keeps looking ahead
LONG_AIM_HEAD_PITCH_DEG = 15.0                  # the head down onto the stock at the aim
# THE AIM AT THE EYE (Director, 2026-11-18: "a pose do aim ainda está muito baixa. Precisa ficar na altura dos olhos"): the gun's sight line (the top of its receiver)
# runs just under the RIGHT eye, the head down on the stock and leaning right onto it (the cheek on the comb); the butt goes where that puts it, high in the shoulder.
# One aim for the shotguns, the rifles and the snipers (the hip shot is the shotguns' and the rifles', never the snipers').
LONG_AIM_HEAD_ROLL_DEG = 10.0                   # the head leaning to its right, onto the stock
LONG_AIM_EYE_ABOVE = 0.012                      # the eye this far above the sight line
LONG_EYE_FROM_NOSE = (-0.016, 0.012, 0.02)      # the right eye against the nose's tip (the head mesh's frontmost point), the figure's units at the idle
LONG_COAT_KEY = "LongDrawFix"
# THE SUPPORT HAND at the hip and the aim (Director, 2026-11-18: "A mão esquerda precisa girar, pra palma apontar pra cima, e os dedos abraçarem o cano"): the palm
# UP under the fore-end, the fingers across it toward the gun's right (turned this much toward the muzzle) and closed round it, the thumb along its left side. The
# left hand bone, measured: +Y runs to the fingers, +X to the index and thumb side, the palm faces -Z.
LONG_SUPPORT_FWD_DEG = 20.0
LONG_SUPPORT_CURL_DEG = (45.0, 80.0, 50.0)    # each finger's three joints (knuckle, middle, tip)
LONG_PALM_DEPTH = 0.008                       # from the hand's bone line to the palm's skin
LONG_GUN_SEQUENCES = ("draw_shotgun", "draw_bullpup", "draw_shotgun_sawed_off", "draw_shotgun_short_stock", "draw_shotgun_zmptnh7njl", "draw_scifi_sniper_vu7qizyae0", "draw_scifi_sniper_46615jyfm7")   # the long guns' draw timelines: their read-back keeps the fingers (`sequence`); the bullpup's
                                                         # is its own (2026-11-24, `family_lab.py seq`)


def _gun_frame_points(obj, factor, turn=None):
    """A long gun's GUN FRAME (barrel +X, its top +Z, centred on y = 0) from the model as imported, and its points in that frame at `factor`: the butt, the grip
    (the stock's wrist), the pump (`LONG_PUMP_AT` along the fore-end), the hold (`LONG_HOLD_AT` of the length, on the barrel), the muzzle. The pieces are the pack's
    materials (Wood = the stock, DarkWood = the fore-end, DarkMetal = the barrel); a model without them falls back on fractions of its length. `turn` (4x4): the
    gun frame GIVEN, the lab's explicit one (`family_lab.FAMILIES["H3"]`), instead of found: the rules below turn the bullpup barrel-backwards (2026-11-23).
    Returns (F: the import's world -> the gun frame at the factor, 4x4; {point name: Vector}; length)."""
    W0 = obj.matrix_world.copy()
    world = [W0 @ v.co for v in obj.data.vertices]

    def bounds(ps):
        return Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)])

    def members(name):
        idx = {i for i, s in enumerate(obj.material_slots) if s.material is not None and s.material.name.split(".")[0] == name}
        return sorted({v for p in obj.data.polygons if p.material_index in idx for v in p.vertices})

    A = Matrix.Identity(4)
    lo, hi = bounds(world)
    stock = members("Wood")
    if turn is not None:
        A = turn.copy()
        turned = [A @ p for p in world]
        lo, hi = bounds(turned)
    else:
        if hi.y - lo.y > hi.x - lo.x:
            A = Matrix.Rotation(math.radians(90.0), 4, "Z") @ A
        turned = [A @ p for p in world]
        lo, hi = bounds(turned)
        if stock:   # the stock is the rear
            rear_is_low = sum(turned[i].x for i in stock) / len(stock) < (lo.x + hi.x) / 2.0
        else:       # the handgun rule (`family_lab.to_gun_frame`): the low part is the rear
            low = [p for p in turned if p.z < lo.z + 0.35 * (hi.z - lo.z)]
            rear_is_low = not low or sum(p.x for p in low) / len(low) <= (lo.x + hi.x) / 2.0
        if not rear_is_low:
            A = Matrix.Rotation(math.radians(180.0), 4, "Z") @ A
            turned = [A @ p for p in world]
            lo, hi = bounds(turned)
    A = Matrix.Translation((0.0, -(lo.y + hi.y) / 2.0, 0.0)) @ A
    F = Matrix.Scale(factor, 4) @ A
    q = [F @ p for p in world]
    lo, hi = bounds(q)
    L = hi.x - lo.x

    def z_mid(ps, x, half):
        near = [p.z for p in ps if abs(p.x - x) <= half]
        return (min(near) + max(near)) / 2.0 if near else (lo.z + hi.z) / 2.0

    pts = {"butt": Vector((lo.x, 0.0, z_mid(q, lo.x, 0.02 * L))), "muzzle": Vector((hi.x, 0.0, z_mid(q, hi.x, 0.01 * L)))}
    s = [q[i] for i in stock]
    if s:
        s_lo, s_hi = min(p.x for p in s), max(p.x for p in s)
        x = s_hi - 0.08 * (s_hi - s_lo)
        pts["grip"] = Vector((x, 0.0, z_mid(s, x, 0.03 * L)))
    else:
        x = lo.x + 0.3 * L
        pts["grip"] = Vector((x, 0.0, z_mid(q, x, 0.03 * L)))
    fore = [q[i] for i in members("DarkWood")]
    if fore:
        f_lo, f_hi = min(p.x for p in fore), max(p.x for p in fore)
        x = f_lo + LONG_PUMP_AT * (f_hi - f_lo)
        pts["pump"] = Vector((x, 0.0, z_mid(fore, x, 0.03 * L)))
        near = [p.z for p in fore if abs(p.x - x) <= 0.03 * L]
        pts["pump_under"] = Vector((x, 0.0, min(near) if near else pts["pump"].z))
    else:
        x = lo.x + 0.5 * L
        pts["pump"] = Vector((x, 0.0, z_mid(q, x, 0.03 * L)))
        pts["pump_under"] = Vector((x, 0.0, min((p.z for p in q if abs(p.x - x) <= 0.03 * L), default=pts["pump"].z)))
    barrel = [q[i] for i in members("DarkMetal")] or q
    x = lo.x + LONG_HOLD_AT * L
    pts["hold"] = Vector((x, 0.0, z_mid(barrel, x, 0.02 * L)))
    top = [p.z for p in q if pts["grip"].x <= p.x <= pts["pump"].x]
    pts["sight"] = Vector((pts["grip"].x, 0.0, max(top) if top else hi.z))   # the line the eye looks along: the top of the receiver, above the grip
    return F, pts, L


def _support_hand(G):
    """The left hand's rotation under a long gun whose gun frame is G (3x3: the barrel, its left, its top): the palm (-Z) up into the gun, the fingers (+Y) across
    it toward its right, turned `LONG_SUPPORT_FWD_DEG` toward the muzzle; the thumb side (+X) then runs along the barrel to the muzzle."""
    a = math.radians(LONG_SUPPORT_FWD_DEG)
    y = (-G.col[1] * math.cos(a) + G.col[0] * math.sin(a)).normalized()
    z = (-G.col[2] - y * (-G.col[2]).dot(y)).normalized()
    return Matrix((y.cross(z), y, z)).transposed()


def _place_arm(P, pos, rest_head, side, R_hand, head, pole_dir):
    """`side`'s hand turned to R_hand with its head at `head`: the upper arm and the forearm turned the least so the wrist lands there (two-bone IK, the elbow
    toward `pole_dir` from the shoulder), the forearm taking most of the twist toward the hand. Armature-space rotations in P; returns the reach (1 = straight)."""
    J = pos[side + "Arm"]
    a = (rest_head[side + "ForeArm"] - rest_head[side + "Arm"]).length
    b = (rest_head[side + "Hand"] - rest_head[side + "ForeArm"]).length
    elbow, wrist = _two_bone(J, head, a, b, J + pole_dir)
    P[side + "Arm"] = _aim_bone(P[side + "Arm"], J, elbow)
    fore = _aim_bone(P[side + "ForeArm"], elbow, wrist)
    y = fore.col[1].normalized()
    hx = R_hand.col[0] - y * R_hand.col[0].dot(y)
    if hx.length > 1e-6:
        fx = fore.col[0]
        ang = math.atan2(fx.cross(hx.normalized()).dot(y), fx.dot(hx.normalized()))
        fore = (Matrix.Rotation(0.7 * ang, 3, y) @ fore).normalized()
    P[side + "ForeArm"] = fore
    P[side + "Hand"] = R_hand
    return (head - J).length / (a + b)


def _close_fingers(P, P_ref, names, children, side, curl):
    """`side`'s fingers on its (new) hand: each as it lies on the hand in P_ref (the idle), then the four long fingers closed toward the palm (-Z) about the hand's
    +X, joint by joint (`curl`, degrees); the thumb as it lies."""
    def subtree(n):
        out = [n]
        for c in children[n]:
            out += subtree(c)
        return out
    hand = side + "Hand"
    rel = P_ref[hand].transposed()
    for n in names:
        if n.startswith(hand) and n != hand:
            P[n] = (P[hand] @ (rel @ P_ref[n])).normalized()
    ax = P[hand].col[0].normalized()
    for finger in ("Index", "Middle", "Ring", "Pinky"):
        for i, ang in enumerate(curl, start=1):
            n = f"{hand}{finger}{i}"
            if n not in P:
                continue
            R = Matrix.Rotation(math.radians(-ang), 3, ax)
            for m in subtree(n):
                P[m] = (R @ P[m]).normalized()


def _bake_slide(sc, arm, gun, f0, f1, c0, c1):
    """The gun's place on the left hand keyed at every frame strictly between f0 and f1 (both already keyed), so the hand SLIDES along the gun: the point of the gun
    in the palm runs from c0 to c1 (the gun object's own coordinates) while the gun turns in the hand from its f0 rotation to its f1 one. Blender's own interpolation
    of the two places (location and rotation separately, in the bone's frame) swings the gun on an arc away from the hand (2026-11-18, frames 14-15)."""
    def hand():
        return arm.matrix_world @ arm.pose.bones[PREFIX + "LeftHand"].matrix

    def held(f):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        return hand().inverted() @ gun.matrix_world

    A0, A1 = held(f0), held(f1)
    _l0, q0, s0 = A0.decompose()
    _l1, q1, s1 = A1.decompose()
    p0, p1 = A0 @ c0, A1 @ c1
    for f in range(f0 + 1, f1):
        t = (f - f0) / float(f1 - f0)
        s = s0.lerp(s1, t)
        c = c0.lerp(c1, t)
        A = Matrix.Translation(p0.lerp(p1, t)) @ q0.slerp(q1, t).to_matrix().to_4x4() @ Matrix.Diagonal((s.x, s.y, s.z, 1.0)) @ Matrix.Translation(-c)
        sc.frame_set(f)
        bpy.context.view_layer.update()
        gun.matrix_world = hand() @ A
        bpy.context.view_layer.update()
        for path in ("location", "rotation_quaternion", "scale"):
            gun.keyframe_insert(path, frame=f)


def draw_long_new(base_blend, fire_glb, out_blend, gun_id="shotgun"):
    """THE STARTING TIMELINE OF A LONG GUN'S DRAW of one figure (see the block above), built from its pistol draw timeline (`SEQ_draw_pistol_<FIG>_arm6.blend`: the
    LIGHT Agent, the lab data, frame 1 = the game's idle, the draw stop at its `draw` marker) and the bank's `fire`. Nothing is written over the base file."""
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    markers = {m.name: m.frame for m in sc.timeline_markers}
    draw_frame = markers.get("draw", 12)

    def snap(frame):
        sc.frame_set(frame)
        bpy.context.view_layer.update()
        return ({pb.name[len(PREFIX):]: pb.matrix.to_3x3().normalized() for pb in arm.pose.bones},
                {pb.name[len(PREFIX):]: pb.head.copy() for pb in arm.pose.bones})

    P_idle, H_idle = snap(1)
    head_mesh = bpy.data.objects.get("Body_Head")
    if head_mesh is None:
        fail("no Body_Head: the aim needs the eye (the nose's tip on the head mesh)")
    ev_head = head_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev_head.to_mesh()
    nose = min((ev_head.matrix_world @ v.co for v in me.vertices), key=lambda v: v.y)
    ev_head.to_mesh_clear()
    eye_local = P_idle["Head"].transposed() @ (nose + Vector(LONG_EYE_FROM_NOSE) - H_idle["Head"])
    P_draw, H_draw = snap(draw_frame)
    hips_idle = H_idle["Hips"].copy()
    rest_head = {n: arm.data.bones[PREFIX + n].head_local.copy() for n in rig.names}
    children = {n: [c for c in rig.names if rig.parent[c] == n] for n in rig.names}

    def subtree(n):
        out = [n]
        for c in children[n]:
            out += subtree(c)
        return out

    def fk(P, hips_pos):
        pos = {}
        for n in rig.names:
            p = rig.parent[n]
            pos[n] = hips_pos.copy() if not p else pos[p] + P[p] @ rig.R[p].transposed() @ (rest_head[n] - rest_head[p])
        return pos

    def turn(P, root, R):
        for n in subtree(root):
            P[n] = (R @ P[n]).normalized()

    def palm(pos, side):
        return (pos[side + "Hand"] + pos[side + "HandMiddle1"]) * 0.5

    # THE LAPEL: the pistol's draw stop mirrored (the change from the idle of each bone's mirror, mirrored; the legs and the hips' place stay the idle's)
    Mx = Matrix.Diagonal((-1.0, 1.0, 1.0))

    def mirror_name(n):
        return "Right" + n[4:] if n.startswith("Left") else ("Left" + n[5:] if n.startswith("Right") else n)

    legs = {n for s in ("Left", "Right") for n in subtree(s + "UpLeg")}
    P_lapel = {}
    for n in rig.names:
        if n in legs:
            P_lapel[n] = P_idle[n].copy()
            continue
        m = mirror_name(n)
        change = P_draw[m] @ P_idle[m].transposed()
        P_lapel[n] = ((Mx @ change @ Mx) @ P_idle[n]).normalized()

    # THE GRIPS: each hand against the line between the palms in the bank `fire` frame (its rotation, the hand's head from the palm), and its fingers against the hand
    clip = _clip_frames(arm, fire_glb, [LONG_GRIP_FRAME])[LONG_GRIP_FRAME]
    cP = {n: v[0] for n, v in clip.items()}
    cH = {n: v[1] for n, v in clip.items()}
    c_palm = {s: (cH[s + "Hand"] + cH[s + "HandMiddle1"]) * 0.5 for s in ("Left", "Right")}
    gx = (c_palm["Left"] - c_palm["Right"]).normalized()
    gz = (Vector((0.0, 0.0, 1.0)) - gx * gx.z).normalized()
    Fc = Matrix((gx, gz.cross(gx), gz)).transposed()
    grip = {s: {"rot": Fc.transposed() @ cP[s + "Hand"], "head": Fc.transposed() @ (cH[s + "Hand"] - c_palm[s]),
                "fingers": {n: cP[s + "Hand"].transposed() @ cP[n] for n in rig.names if n.startswith(s + "Hand") and n != s + "Hand"}}
            for s in ("Left", "Right")}
    print(f"[tripo_pose_lab] the fire frame {LONG_GRIP_FRAME}: palms {(c_palm['Left'] - c_palm['Right']).length:.3f} apart, the gun's line {tuple(round(v, 2) for v in gx)}")
    def seg(a, b):
        return (rest_head[b] - rest_head[a]).length

    def hold(P, pos, side, G, point, pole_dir):
        """`side`'s hand on the gun (gun frame G, 3x3) with its palm at `point`, turned as its grip says, the fingers as the grip's (`place`)."""
        g = grip[side]
        return place(P, pos, side, (G @ g["rot"]).normalized(), point + G @ g["head"], pole_dir, g["fingers"])

    def place(P, pos, side, R_hand, head, pole_dir, fingers=None):
        """`_place_arm`, and the fingers relative to the hand when given."""
        r = _place_arm(P, pos, rest_head, side, R_hand, head, pole_dir)
        for n, rel in (fingers or {}).items():
            P[n] = (R_hand @ rel).normalized()
        return r

    palm_local = rig.R["LeftHand"].transposed() @ ((rest_head["LeftHandMiddle1"] - rest_head["LeftHand"]) * 0.5)

    def support(P, pos, G, under, pole_dir):
        """The left hand under the fore-end: the palm's skin on the gun's underside point `under`, the palm up, the fingers round it (`_support_hand`)."""
        R_hand = _support_hand(G)
        head = under - G.col[2] * LONG_PALM_DEPTH - R_hand @ palm_local
        r = _place_arm(P, pos, rest_head, "Left", R_hand, head, pole_dir)
        _close_fingers(P, P_idle, rig.names, children, "Left", LONG_SUPPORT_CURL_DEG)
        return r

    # THE GUN: imported as the game reads it (the glb's node transform on the object), its gun frame and points
    gun, node_scale = import_prop(gun_id, {})
    gun["lab_node_scale"] = node_scale
    gun["lab_bone"] = "LeftHand"
    bpy.context.view_layer.update()
    W0 = gun.matrix_world.copy()
    F, pts, length = _gun_frame_points(gun, LONG_GUN_FACTOR)
    print(f"[tripo_pose_lab] {gun_id}: {length:.3f} long at x{LONG_GUN_FACTOR} (the pack's units), points " + ", ".join(f"{k} {tuple(round(v, 3) for v in p)}" for k, p in pts.items()))
    G_hip = Matrix(((0.0, 1.0, 0.0), (-1.0, 0.0, 0.0), (0.0, 0.0, 1.0)))          # columns: the barrel forward (-Y), its left side (+X), its top up
    G_vert = Matrix.Rotation(math.radians(-90.0), 3, "X") @ G_hip                  # the barrel up, its top toward the body, its bottom (the trigger) away

    def gun_world(G, anchor, at):
        """The gun object's world matrix with the gun-frame point `anchor` at `at`, the gun frame turned to G."""
        return Matrix.Translation(at) @ G.to_4x4() @ Matrix.Translation(-anchor) @ F @ W0

    S2 = H_idle["Spine2"]
    at = {m: f for f, m in LONG_DRAW_PLAN}
    poses = {}            # frame -> (P, hips position, gun world matrix or None)
    reach = {}

    # 12 the lapel; 13 the gun appears in the left hand, upright, its hold point at the palm
    pos12 = fk(P_lapel, hips_idle)
    poses[12] = (P_lapel, hips_idle, None)
    gun13 = gun_world(G_vert, pts["hold"] + Vector((0.0, 0.0, -0.015)), palm(pos12, "Left"))

    # 27 the hip: the trunk turned right, the gun level and forward at the right hip, the right hand on the grip, the left under the fore-end
    def trunk(P, key):
        t = LONG_TWIST_DEG[key]
        for root in ("Spine", "Spine1", "Spine2"):
            turn(P, root, Matrix.Rotation(math.radians(t / 3.0), 3, "Z"))
        turn(P, "Neck", Matrix.Rotation(math.radians(-t * LONG_HEAD_BACK[key]), 3, "Z"))

    P27 = {n: m.copy() for n, m in P_idle.items()}
    trunk(P27, "hip")
    pos27 = fk(P27, hips_idle)
    grip27 = Vector((H_idle["RightUpLeg"].x - 0.02, hips_idle.y - 0.04, hips_idle.z + 0.06))
    reach["hip R"] = hold(P27, pos27, "Right", G_hip, grip27 + G_hip @ Vector((0.0, -0.012, 0.0)), Vector((-0.1, 0.12, -0.15)))
    reach["hip L"] = support(P27, pos27, G_hip, grip27 + G_hip @ (pts["pump_under"] - pts["grip"]), Vector((0.12, -0.05, -0.2)))
    poses[at["hip"]] = (P27, hips_idle, gun_world(G_hip, pts["grip"], grip27))

    # the aim: turned further, the head down on the stock and leaning right, the gun's sight line just under the right eye (`LONG_AIM_*`)
    P35 = {n: m.copy() for n, m in P_idle.items()}
    trunk(P35, "aim")
    turn(P35, "Neck", Matrix.Rotation(math.radians(LONG_AIM_HEAD_PITCH_DEG), 3, "X"))
    turn(P35, "Neck", Matrix.Rotation(math.radians(-LONG_AIM_HEAD_ROLL_DEG), 3, "Y"))
    pos35 = fk(P35, hips_idle)
    eye35 = pos35["Head"] + P35["Head"] @ eye_local
    sight35 = eye35 - Vector((0.0, 0.0, LONG_AIM_EYE_ABOVE))
    butt35 = sight35 + G_hip @ (pts["butt"] - pts["sight"])
    grip35 = sight35 + G_hip @ (pts["grip"] - pts["sight"])
    reach["aim R"] = hold(P35, pos35, "Right", G_hip, grip35 + G_hip @ Vector((0.0, -0.012, 0.0)), Vector((-0.18, 0.04, -0.06)))
    reach["aim L"] = support(P35, pos35, G_hip, sight35 + G_hip @ (pts["pump_under"] - pts["sight"]), Vector((0.06, -0.06, -0.22)))
    poses[at["aim"]] = (P35, hips_idle, gun_world(G_hip, pts["sight"], sight35))
    print(f"[tripo_pose_lab] the aim: the right eye at {tuple(round(v, 3) for v in eye35)}, the butt {tuple(round(v, 3) for v in butt35)} "
          f"(the right shoulder joint {tuple(round(v, 3) for v in pos35['RightArm'])})")

    # the centre: the gun upright in front of the tie, held by the tip EXACTLY as it came out at 13 (Director, 2026-11-18: "depois que o agente pega a arma, ela
    # deveria continuar sendo segurada pelo cano, sem mudar"): the left hand of 13 carried there, turned the same; the right hand has let the lapel go, half way
    # to the grip
    P20 = {n: m.copy() for n, m in P_lapel.items()}
    for n in subtree("RightShoulder"):
        P20[n] = Quaternion(P_lapel[n].to_quaternion()).slerp(P27[n].to_quaternion(), 0.5).to_matrix()
    pos20 = fk(P20, hips_idle)
    hold20 = Vector((S2.x, S2.y - 0.19, S2.z + 0.06))
    centre_shift = hold20 - (palm(pos12, "Left") + G_vert @ Vector((0.0, 0.0, 0.015)))
    reach["centre L"] = place(P20, pos20, "Left", P_lapel["LeftHand"], pos12["LeftHand"] + centre_shift, Vector((0.14, -0.02, -0.2)))
    poses[at["centre"]] = (P20, hips_idle, Matrix.Translation(centre_shift) @ gun13)
    print("[tripo_pose_lab] the arms reach " + ", ".join(f"{k} {v:.2f}" for k, v in reach.items()) + " of their length (1 = straight)")

    # ---- the keys: every pose SETTLED first (its bones, the hips, the gun's place against the left hand), then keyed (a key re-reads the animation over a set pose)
    arm.animation_data_clear()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_") and o is not gun]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    gun.parent = arm
    gun.parent_type = 'BONE'
    gun.parent_bone = PREFIX + "LeftHand"
    gun.rotation_mode = 'QUATERNION'

    def apply(P, hips_pos):
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            p = rig.parent[n]
            rp = rig.R[p] if p else Matrix.Identity(3)
            pp = P[p] if p else Matrix.Identity(3)
            pb.rotation_quaternion = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            pb.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips_pos
        h.matrix = m
        bpy.context.view_layer.update()

    settled = {}
    plan = {f: m for f, m in LONG_DRAW_PLAN}
    body = {1: (P_idle, hips_idle)}
    body.update({f: (P, h) for f, (P, h, _g) in poses.items()})
    gun_at = {f: g for f, (_P, _h, g) in poses.items() if g is not None}
    gun_at[13] = gun13
    for f in sorted(set(body) | {13}):
        P, h = body[f] if f in body else body[12]
        apply(P, h)
        state = {"bones": {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}, "hips": arm.pose.bones[PREFIX + "Hips"].location.copy()}
        if f in gun_at:
            gun.matrix_world = gun_at[f]
            bpy.context.view_layer.update()
            state["gun"] = (gun.location.copy(), gun.rotation_quaternion.copy(), gun.scale.copy())
        if f in poses or f == 13:
            pl = palm({pb.name[len(PREFIX):]: pb.head.copy() for pb in arm.pose.bones}, "Left")
            state["palm"] = pl
        settled[f] = state
    first_gun = settled[13]["gun"]
    for f, st in sorted(settled.items()):
        sc.frame_set(f)
        if f in body:
            for pb in arm.pose.bones:
                pb.rotation_quaternion = st["bones"][pb.name]
                pb.keyframe_insert("rotation_quaternion", frame=f)
            hb = arm.pose.bones[PREFIX + "Hips"]
            hb.location = st["hips"]
            hb.keyframe_insert("location", frame=f)
    # the gun on the left hand (Director, 2026-11-18): held by the tip of the barrel from where it comes out of the coat to the centre; in the turn the hand
    # SLIDES BACK along the barrel to the fore-end while it swings the muzzle from the zenith to the front, and the right hand takes the grip and the trigger
    # below and lifts the whole gun to the waist (the hip shot); the aim keeps the hand under the fore-end. So its place on the hand is keyed at every stop.
    for f in sorted({1, at["lapel"], LONG_GUN_SHOWN_FROM, at["centre"], at["hip"], at["aim"]}):
        loc, rot, scl = settled[f]["gun"] if "gun" in settled.get(f, {}) else first_gun
        gun.location, gun.rotation_quaternion, gun.scale = loc, rot, scl
        gun.hide_viewport = gun.hide_render = f < LONG_GUN_SHOWN_FROM
        for path in ("location", "rotation_quaternion", "scale", "hide_viewport", "hide_render"):
            gun.keyframe_insert(path, frame=f)
    FW = (F @ W0).inverted()
    _bake_slide(sc, arm, gun, at["centre"], at["hip"], FW @ pts["hold"], FW @ pts["pump_under"])
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        frames = [f for f, _m in LONG_DRAW_PLAN]
        for i, (frame, _m) in enumerate(LONG_DRAW_PLAN):
            if i == 0:
                continue
            kb = coat.shape_key_add(name=f"{LONG_COAT_KEY}_f{frame:02d}", from_mix=False)
            for f2, v in ((frames[i - 1], 0.0), (frame, 1.0)) + (((frames[i + 1], 0.0),) if i + 1 < len(frames) else ()):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        coat.active_shape_key_index = list(coat.data.shape_keys.key_blocks.keys()).index(f"{LONG_COAT_KEY}_f12")
    sc.timeline_markers.clear()
    for frame, marker in LONG_DRAW_PLAN:
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = LONG_DRAW_PLAN[0][0], LONG_DRAW_PLAN[-1][0]
    arm["lab_pose"] = "draw_" + gun_id
    arm["lab_props"] = json.dumps([gun_id])
    # how far each solved palm lands from where the gun wants it (the FK above against Blender's own evaluation)
    worst = 0.0
    for f, target in ((at["centre"], palm(pos12, "Left") + centre_shift),):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        pl = palm({pb.name[len(PREFIX):]: pb.head.copy() for pb in arm.pose.bones}, "Left")
        worst = max(worst, (pl - target).length)
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} {gun_id} draw, frames 1-{LONG_DRAW_PLAN[-1][0]}, markers {[m for _f, m in LONG_DRAW_PLAN]}; "
          f"the left palm lands {worst * 1000:.1f} mm from the barrel's hold (Blender vs the solver)")


# ---- THE RUN'S START (MOVEMENT, 2026-11-14) ----------------------------------------------------------------------------------------------------------------------------
# The passage idle -> run, one timeline per figure (`SEQ_run_start_<FIG>.blend`). The Director's rules (2026-11-14, on the first draft, which slid the support foot
# back and through the floor while the body stood still):
#   - the support (LEFT) foot stays PLANTED where the idle has it, and the body projects forward over it;
#   - the passage does not come back to a run pose standing on the idle's spot: it ends one step AHEAD, on the bank run's next footfall (the right foot's
#     contact, RUN_START_TO), and the game carries on with the run from that frame to the end of its cycle, then its frame 0 (no jump cut).
# THE SCAFFOLD. The bank `run` is turned to the figure's forward and ANCHORED so its left ball, flat at mid-stance (RUN_START_STANCE), sits on the idle's left
# ball. The passage plays that anchored run from the frame whose hips stand over the left ball as the idle's do (computed) to RUN_START_TO with a constant
# acceleration from rest: the hips' travel goes as t^2 and ends at the run's own speed, so the handoff has no jolt either. The body (pelvis, spine, arms,
# head) is the idle blended into that run; the fingers keep the idle. The LEGS are IK, so whatever the Director does to the body, a planted foot stays put:
# per foot a small reverse foot of three empties, IK_<L|R>_toe at the ball (the toes: flat on the floor while it stands), its child IK_<L|R>_foot (rotate it
# to lift the heel about the ball), its child IK_<L|R>_ankle (the point the shin reaches: an IK constraint on <side>Leg, chain 2; the foot and the toes copy
# the empties' rotations). The left foot is pinned until it rolls off its toes where the run does; the right one rolls up, leaves the idle's spot and swings
# forward into the run's own swing. The forward travel is the ARMATURE OBJECT's location (root motion, keyed every frame: the game moves the actor by it);
# the pose on the bones is in place.
RUN_START_TO = 14                 # the bank run's frame of the right foot's contact: the passage's last frame, where the run takes over in play
RUN_START_STANCE = 9              # the bank run's frame with the left foot flat at mid-stance: the anchor
RUN_START_BODY = ((0.0, "idle"), (0.23, "lean"), (0.46, "drive"), (0.69, "push"), (1.0, "run"))   # the body's keys, as fractions of the passage, and their markers
RUN_START_R_EVENTS = (0.08, 0.3, 0.38, 0.6)   # the right foot: heel starts up, heel up (ball still down), toes leave the floor, joins the run's swing
RUN_START_R_HEEL_DEG = 35.0       # how far the right heel is up when its toes leave the floor
RUN_START_LIFT = 0.02             # the right ball's first lift off the floor (figure metres)
IK_NAME = "IK_%s_%s"              # (L|R, toe|foot|ankle)
# THE ENDS CARRY THE GAME'S POSE (Director, 2026-11-14: "os frames das pontas, no início e no final, venham com a informação completa da pose final no game, mesmo
# que seja só como referência"): the first frame has the coat key of the clip it leaves on, the last that of the clip it hands over to, fading across the passage.
RUN_START_ENDS = ("IdleFix", "RunFix")
# THE WALK'S START (2026-11-14, Director: "as transições da caminhada, usando os mesmos mecanismos"): the same builder over the bank `walk`. One walk cycle is
# exactly one GU (0.82 figure-m, two steps), so every walk reaches the cell's centre in the same phase: one start and one stop per figure. The walk's frame 0
# has the left foot flat and the right in its swing, so the start keeps the LEFT planted and the right steps first, as the run's does.
START_GAITS = {
    "run": {"to": RUN_START_TO, "stance": RUN_START_STANCE, "body": RUN_START_BODY, "r_events": RUN_START_R_EVENTS, "heel_deg": RUN_START_R_HEEL_DEG,
            "lift": RUN_START_LIFT, "ends": RUN_START_ENDS, "key": "StartFix", "pose": "run_start", "search_lo": 2.0, "heel_rise": 0.01},
    "walk": {"to": 9, "stance": 3, "body": ((0.0, "idle"), (0.33, "lean"), (0.66, "step"), (1.0, "walk")), "r_events": (0.1, 0.3, 0.4, 0.6),
             "heel_deg": 25.0, "lift": 0.015, "ends": ("IdleFix", "WalkFix"), "key": "WStartFix", "pose": "walk_start", "search_lo": 0.0,
             "heel_rise": 0.002},   # the walk's heel rises slowly: the support heel follows it from its first millimetres or the leg falls short
    # RISING FROM THE CROUCH INTO THE RUN (2026-11-15): the same builder, the rest pose being the crouch's LAST frame (kneeling on the right knee, the left foot flat
    # ahead): the left foot is the support, the right knee comes off the floor and swings through into the run's contact. Its two coat ends are borrowed keys.
    "crouch_run": {"to": RUN_START_TO, "stance": RUN_START_STANCE, "body": ((0.0, "crouch"), (0.23, "rise"), (0.46, "drive"), (0.69, "push"), (1.0, "run")),
                   "r_events": (0.1, 0.3, 0.42, 0.62), "heel_deg": 0.0, "lift": 0.03, "ends": ("CrouchFix_f16 (inherited)", "RunFix_f14 (next)"), "key": "RiseFix",
                   "pose": "crouch_run", "search_lo": 2.0, "heel_rise": 0.01, "min_frames": 16, "borrow": "RunFix"},
    # the same into the WALK (2026-11-15): the walk's anchors (stance 3, contact 9), the walk start's own `WalkFix` borrowed
    "crouch_walk": {"to": 9, "stance": 3, "body": ((0.0, "crouch"), (0.33, "rise"), (0.66, "step"), (1.0, "walk")), "r_events": (0.1, 0.3, 0.42, 0.62),
                    "heel_deg": 0.0, "lift": 0.02, "ends": ("CrouchFix_f16 (inherited)", "WalkFix_f09 (next)"), "key": "WRiseFix", "pose": "crouch_walk",
                    "search_lo": 0.0, "heel_rise": 0.002, "min_frames": 16, "borrow": "WalkFix"},
}


def _quat_near(q, ref):
    """`q` or `-q`, whichever is on `ref`'s side: keyed quaternions are interpolated by component, so a sign flip between two keys spins the bone."""
    return q if ref is None or q.dot(ref) >= 0.0 else -q


def run_start_new(base_blend, clip_glb, out_blend, gait="run", run_blend=None):
    """THE STARTING TIMELINE OF THE RUN of one figure (see the block's header): the idle at frame 1 of `base_blend` (the draw timeline, its idle re-based to 90)
    into the bank's `run`, ending on its frame G["to"] one step ahead, the left foot planted, the legs on IK. Nothing is written over the base. `gait`: a START_GAITS row (the walk's start is the same passage into the bank `walk`)."""
    G = START_GAITS[gait]
    from_crouch = gait.startswith("crouch_")
    borrowed = None
    if from_crouch:   # the run's coat key, taken from the run's own start timeline: its basis must be the crouch's
        bpy.ops.wm.open_mainfile(filepath=run_blend)
        c0 = bpy.data.objects[COAT_OBJECT]
        kb0 = c0.data.shape_keys.key_blocks
        rk = next(k for k in kb0 if k.name.startswith(G["borrow"]))
        borrowed = ([v.co.copy() for v in rk.data], [v.co.copy() for v in kb0[0].data])
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    sc.frame_set(sc.frame_end if from_crouch else 1)
    bpy.context.view_layer.update()
    idle = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    idle_q = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    hips_idle = idle["Hips"][1]
    if from_crouch:   # the crouch's legs are IK: the pose above is the evaluated one, the constraints go (this builder makes its own)
        for pb in arm.pose.bones:
            for c in list(pb.constraints):
                pb.constraints.remove(c)
        arm.location = Vector()
    arm.animation_data_clear()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_") or o.name.startswith("IK_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    if from_crouch:
        coat0 = bpy.data.objects[COAT_OBJECT]
        blocks0 = coat0.data.shape_keys.key_blocks
        if any((a - b).length > 1e-5 for a, b in zip(borrowed[1], [v.co for v in blocks0[0].data])):
            sys.exit("[tripo_pose_lab] the crouch's coat Basis differs from the start's: %s cannot be carried over" % G["borrow"])
        for k in blocks0:   # the crouch's own key, locked, is the passage's first end
            if k.name == "CrouchFix_f16":
                k.name = "CrouchFix_f16 (inherited)"
        for k in [k for k in blocks0 if k.name != "Basis" and not k.name.startswith("CrouchFix_f16")]:
            coat0.shape_key_remove(k)
        rf = coat0.shape_key_add(name=G["ends"][1], from_mix=False)
        for v, co in zip(rf.data, borrowed[0]):
            v.co = co
    clip = _clip_frames(arm, clip_glb, list(range(0, G["to"] + 3)))
    up = Vector((0.0, 0.0, 1.0))
    fwd = sum(((idle[s + "ToeBase"][1] - idle[s + "Foot"][1]) for s in ("Left", "Right")), Vector())
    fwd.z = 0.0
    fwd.normalize()
    drift = clip[G["to"] + 2]["Hips"][1] - clip[0]["Hips"][1]
    drift.z = 0.0
    yaw = math.atan2(fwd.y, fwd.x) - math.atan2(drift.y, drift.x)
    Rz = Matrix.Rotation(yaw, 3, 'Z')
    c0 = clip[0]["Hips"][1]

    def turned(f, n):
        """the run at (fractional) frame f, turned to the figure's forward: (armature-space rotation, head)"""
        a = min(int(math.floor(f)), G["to"] + 1)
        u = f - a
        Pa, ha = clip[a][n]
        Pb, hb = clip[a + 1][n]
        qa, qb = Pa.to_quaternion(), Pb.to_quaternion()
        q = qa.slerp(_quat_near(qb, qa), u)
        return (Rz @ q.to_matrix()).normalized(), c0 + Rz @ (ha.lerp(hb, u) - c0)

    A = idle["LeftToeBase"][1] - turned(G["stance"], "LeftToeBase")[1]
    A.z = 0.0

    def run(f, n):
        P, h = turned(f, n)
        return P, h + A

    def along(v):
        return v.dot(fwd)

    # where the passage starts in the run: the frame whose hips stand over the left ball as the idle's do
    want = along(hips_idle - idle["LeftToeBase"][1])
    ball = run(G["stance"], "LeftToeBase")[1]
    lo, hi = G["search_lo"], float(G["stance"])
    for _i in range(40):
        mid = 0.5 * (lo + hi)
        if along(run(mid, "Hips")[1] - ball) < want:
            lo = mid
        else:
            hi = mid
    f0 = 0.5 * (lo + hi)
    travel_run = along(run(G["to"], "Hips")[1] - run(f0, "Hips")[1])
    v_end = along(run(G["to"] + 1, "Hips")[1] - run(G["to"] - 1, "Hips")[1]) * 0.5
    T = max(G.get("min_frames", 8), int(round(2.0 * travel_run / v_end)))    # from rest to the run's speed at a constant acceleration

    def warp(t):
        return f0 + (G["to"] - f0) * (t / T) ** 2

    def unwarp(f):
        return T * math.sqrt(max(0.0, (f - f0) / (G["to"] - f0)))

    def blend(t):
        return 1.0 - (1.0 - t / T) ** 2

    corr = along(hips_idle) - along(run(f0, "Hips")[1])

    def hips_at(t):
        f, w = warp(t), blend(t)
        h_run = run(f, "Hips")[1]
        h = hips_idle.lerp(h_run, w)
        return h + fwd * ((along(h_run) + corr * (1.0 - w)) - along(h))   # forward: the run's own pace (from the idle's spot); sideways and height: blended

    def travel(t):
        return fwd * (along(hips_at(t)) - along(hips_idle))

    # ---- the feet: (t, toe location, toe rotation, foot rotation), world = armature space at rest of the object (it only translates)
    def lifted(R, deg, ball_at, v):
        """`R` rolled about the ball by `deg` so the heel goes UP"""
        lat = up.cross(fwd).normalized()
        for sgn in (1.0, -1.0):
            Rr = Matrix.Rotation(math.radians(deg) * sgn, 3, lat) @ R
            if (Rr @ v).z > (R @ v).z:
                return Rr
        return R

    feet = {}
    offs = {}
    for side in ("Left", "Right"):
        s = side[0]
        R_foot, R_toe, b = idle[side + "Foot"][0], idle[side + "ToeBase"][0], idle[side + "ToeBase"][1]
        offs[s] = R_foot.transposed() @ (idle[side + "Foot"][1] - b)      # the ankle from the ball, in the foot's frame (a rigid foot)
        keys = [(0, b, R_toe, R_foot)]
        if side == "Left":
            # the run's own stance: the heel starts up after mid-stance, the ball leaves the floor a little later
            ank0 = run(G["stance"], "LeftFoot")[1].z
            bal0 = run(G["stance"], "LeftToeBase")[1].z
            f_heel = next(f for f in range(G["stance"], G["to"]) if run(f + 1, "LeftFoot")[1].z > ank0 + G["heel_rise"])
            f_ball = next(f for f in range(G["stance"], G["to"]) if run(f + 1, "LeftToeBase")[1].z > bal0 + 0.015)
            t_heel, t_ball = int(round(unwarp(f_heel))), int(round(unwarp(f_ball)))
            keys.append((t_heel, b, R_toe, R_foot))
            keys.append((t_ball, b, R_toe, run(warp(t_ball), "LeftFoot")[0]))
            for t in range(t_ball + 1, T + 1):
                f = warp(t)
                keys.append((t, run(f, "LeftToeBase")[1], run(f, "LeftToeBase")[0], run(f, "LeftFoot")[0]))
            feet[s] = (keys, {"heel": t_heel, "ball": t_ball})
        else:
            t1, t2, t3, t4 = [max(1, int(round(x * T))) for x in G["r_events"]]
            keys.append((t1, b, R_toe, R_foot))
            keys.append((t2, b, R_toe, R_foot if from_crouch else lifted(R_foot, G["heel_deg"] * 0.75, b, offs[s])))   # the kneeling heel is already up
            Rf = R_foot if from_crouch else lifted(R_foot, G["heel_deg"], b, offs[s])
            keys.append((t3, b + up * G["lift"] + fwd * G["lift"], Rf @ R_foot.transposed() @ R_toe, Rf))
            for t in range(t4, T + 1):
                f = warp(t)
                keys.append((t, run(f, "RightToeBase")[1], run(f, "RightToeBase")[0], run(f, "RightFoot")[0]))
            feet[s] = (keys, {"heel": t1, "toe_off": t3, "swing": t4})

    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    # the root motion: the armature object, every frame
    for t in range(0, T + 1):
        arm.location = travel(t)
        arm.keyframe_insert("location", frame=t + 1)
    # the reverse feet
    empties = {}
    for s in ("L", "R"):
        toe = bpy.data.objects.new(IK_NAME % (s, "toe"), None)
        foot = bpy.data.objects.new(IK_NAME % (s, "foot"), None)
        ankle = bpy.data.objects.new(IK_NAME % (s, "ankle"), None)
        for o, kind, size in ((toe, 'CIRCLE', 0.05), (foot, 'ARROWS', 0.04), (ankle, 'SPHERE', 0.015)):
            sc.collection.objects.link(o)
            o.empty_display_type = kind
            o.empty_display_size = size
            o.rotation_mode = 'QUATERNION'
            o.show_in_front = True
        foot.parent = toe
        ankle.parent = foot
        ankle.location = offs[s]
        empties[s] = (toe, foot, ankle)
        last_t, last_f = None, None
        for t, loc, Rt, Rf in feet[s][0]:
            qt = _quat_near(Rt.to_quaternion(), last_t)
            qf = _quat_near((Rt.transposed() @ Rf).to_quaternion(), last_f)
            last_t, last_f = qt, qf
            toe.location = loc
            toe.rotation_quaternion = qt
            foot.rotation_quaternion = qf
            toe.keyframe_insert("location", frame=t + 1)
            toe.keyframe_insert("rotation_quaternion", frame=t + 1)
            foot.keyframe_insert("rotation_quaternion", frame=t + 1)
    # the body's keys: the blended pose, the legs solved to where the empties put the ankles (the FK the IK starts from), the feet as the empties turn them
    off_hip = {s: rig.R["Hips"].transposed() @ (arm.data.bones[PREFIX + s + "UpLeg"].head_local - arm.data.bones[PREFIX + "Hips"].head_local) for s in ("Left", "Right")}
    thigh = {s: (idle[s + "Leg"][1] - idle[s + "UpLeg"][1]).length for s in ("Left", "Right")}
    shin = {s: (idle[s + "Foot"][1] - idle[s + "Leg"][1]).length for s in ("Left", "Right")}
    last_q = {}
    body_frames = []
    for frac, _marker in G["body"]:
        t = int(round(frac * T))
        body_frames.append(t + 1)
        sc.frame_set(t + 1)
        bpy.context.view_layer.update()
        f, w = warp(t), blend(t)
        P = {}
        for n in rig.names:
            qi = idle[n][0].to_quaternion()
            P[n] = qi.slerp(_quat_near(run(f, n)[0].to_quaternion(), qi), w).to_matrix()
        hips_arm = hips_at(t) - travel(t)
        for side in ("Left", "Right"):
            toe, foot, ankle = empties[side[0]]
            target = ankle.matrix_world.translation - travel(t)
            hip_j = hips_arm + P["Hips"] @ off_hip[side]
            knee, end = _two_bone(hip_j, target, thigh[side], shin[side], hip_j + fwd * 1.0 - up * 0.3)
            P[side + "UpLeg"] = _aim_bone(P[side + "UpLeg"], hip_j, knee)
            P[side + "Leg"] = _aim_bone(P[side + "Leg"], knee, end)
            P[side + "Foot"] = foot.matrix_world.to_3x3().normalized()
            P[side + "ToeBase"] = toe.matrix_world.to_3x3().normalized()
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            if is_finger(n):
                q = idle_q[pb.name].copy()
            else:
                p = rig.parent[n]
                rp = rig.R[p] if p else Matrix.Identity(3)
                pp = P[p] if p else Matrix.Identity(3)
                q = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            q = _quat_near(q, last_q.get(n))
            last_q[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t + 1)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips_arm
        h.matrix = m
        h.keyframe_insert("location", frame=t + 1)
    # the IK and the feet's rotations, last (the keys above are the FK the solver starts from)
    for side in ("Left", "Right"):
        toe, foot, ankle = empties[side[0]]
        ik = arm.pose.bones[PREFIX + side + "Leg"].constraints.new('IK')
        ik.name = "IK foot"
        ik.target = ankle
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        ik.iterations = 500
        for bone, src in ((side + "Foot", foot), (side + "ToeBase", toe)):
            c = arm.pose.bones[PREFIX + bone].constraints.new('COPY_ROTATION')
            c.name = "IK foot rotation"
            c.target = src
            c.target_space = 'WORLD'
            c.owner_space = 'WORLD'
            c.mix_mode = 'REPLACE'
    sc.timeline_markers.clear()
    for (frac, marker), frame in zip(G["body"], body_frames):
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = 1, T + 1
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        for i, frame in enumerate(body_frames):
            if i == 0:
                continue
            kb = coat.shape_key_add(name=f"{G['key']}_f{frame:02d}", from_mix=False)
            nxt = body_frames[i + 1] if i + 1 < len(body_frames) else None
            for f2, v in ((body_frames[i - 1], 0.0), (frame, 1.0)) + (((nxt, 0.0),) if nxt else ()):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        blocks = coat.data.shape_keys.key_blocks
        for name, (v_first, v_last) in zip(G["ends"], ((1.0, 0.0), (0.0, 1.0))):
            if name not in blocks:
                print(f"[tripo_pose_lab] WARNING: the coat has no {name}: the passage's end is not the game's pose")
                continue
            for frame, v in ((body_frames[0], v_first), (body_frames[-1], v_last)):
                blocks[name].value = v
                blocks[name].keyframe_insert("value", frame=frame)
        coat.active_shape_key_index = list(blocks.keys()).index(next(k.name for k in blocks if k.name.startswith(G["key"])))
    arm["lab_pose"] = G["pose"]
    arm["lab_props"] = json.dumps([])
    arm["lab_run_start"] = json.dumps({"clip": os.path.basename(clip_glb), "from_frame": f0, "to_frame": G["to"], "frames": T, "travel": travel_run,
                                       "speed_end": v_end, "left": feet["L"][1], "right": feet["R"][1]})
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} {gait} start, frames 1-{T + 1}: the run from frame {f0:.2f} to {G['to']} "
          f"(clip turned {math.degrees(yaw):.1f} deg), travel {travel_run:.3f} m, end speed {v_end:.4f} m/frame; left foot {feet['L'][1]}, right foot {feet['R'][1]}")


# THE RUN'S STOP (MOVEMENT 2026-11-14, Director: "a chegada do RUN pro idle ... uma chegada com cada pé, pra usar conforme o destino"; option A: a FIXED length,
# the game times the last stretch so the contact always falls the same distance before the cell's centre). Two timelines per figure, one per foot:
#   - it opens on the bank run's CONTACT of that foot (RUN_STOP_CONTACT) at the run's speed and brakes at a constant deceleration to rest in RUN_STOP_FRAMES;
#   - a runner cannot stop over the foot that strikes (the hips are ~0.2 figure-m behind it and moving at full speed), so the stop is TWO steps: that foot
#     plants and brakes, the other swings through and lands one step ahead (the second brake), then the first lifts and closes beside it;
#   - the hips go forward at a constant deceleration (v t - v t^2 / 2T, the run's own speed at the contact), sideways and in height from the run to the idle;
#   - the last frame is the idle (frame 90 with the 6 deg arm opening, from `base_blend`'s frame 1) standing where the hips came to rest.
# The ends carry the game's pose: RunFix 1 -> 0, IdleFix 0 -> 1 (RUN_START_ENDS reversed).
RUN_STOP_CONTACT = {"Right": 14, "Left": 21}   # the bank run's frames where each foot strikes (its flat stance follows for 2-3 frames)
RUN_STOP_FRAMES = 12                            # contact -> rest (0.5 s at 24 fps); the run's phase advances half that, braking
RUN_STOP_BODY = ((0.0, "run"), (0.33, "brake"), (0.66, "settle"), (1.0, "idle"))
RUN_STOP_SWING = (0.2, 0.42)                    # the other foot: follows the run's swing until, is down on its place at (fractions of the stop)
RUN_STOP_CLOSE = (0.2, 0.36, 0.6, 0.88)         # the striking foot: heel starts up, toes leave the floor, in the air half way, down beside the other (fractions)
RUN_STOP_LIFT = 0.06                            # the closing foot's height over the floor three quarters of the way (figure metres)


def run_stop_new(base_blend, clip_glb, out_blend, side):
    """THE RUN -> IDLE STOP of one figure on `side`'s foot (Left | Right; see the block's header). Nothing is written over the base."""
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    sc.frame_set(1)
    bpy.context.view_layer.update()
    idle = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    idle_q = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    hips_idle = idle["Hips"][1]
    arm.animation_data_clear()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_") or o.name.startswith("IK_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    other = "Left" if side == "Right" else "Right"
    fc = RUN_STOP_CONTACT[side]
    T = RUN_STOP_FRAMES
    clip = _clip_frames(arm, clip_glb, list(range(0, 31)))
    up = Vector((0.0, 0.0, 1.0))
    fwd = sum(((idle[s + "ToeBase"][1] - idle[s + "Foot"][1]) for s in ("Left", "Right")), Vector())
    fwd.z = 0.0
    fwd.normalize()
    drift = clip[30]["Hips"][1] - clip[0]["Hips"][1]
    drift.z = 0.0
    yaw = math.atan2(fwd.y, fwd.x) - math.atan2(drift.y, drift.x)
    Rz = Matrix.Rotation(yaw, 3, 'Z')
    c0 = clip[0]["Hips"][1]

    def turned(f, n):
        a = min(int(math.floor(f)), 29)
        u = f - a
        Pa, ha = clip[a][n]
        Pb, hb = clip[a + 1][n]
        qa, qb = Pa.to_quaternion(), Pb.to_quaternion()
        q = qa.slerp(_quat_near(qb, qa), u)
        return (Rz @ q.to_matrix()).normalized(), c0 + Rz @ (ha.lerp(hb, u) - c0)

    # the planted foot's flat stance: the first frame after the contact whose ball is down
    ball_z = min(turned(f, side + "ToeBase")[1].z for f in range(fc, fc + 5))
    fs = next(f for f in range(fc, fc + 5) if turned(f, side + "ToeBase")[1].z < ball_z + 0.004)
    A = idle[side + "ToeBase"][1] - turned(fs, side + "ToeBase")[1]
    A.z = 0.0

    def run(f, n):
        P, h = turned(f, n)
        return P, h + A

    def along(v):
        return v.dot(fwd)

    def warp(t):                       # the run's phase, braking from 1 frame per frame to rest
        return fc + t - t * t / (2.0 * T)

    def unwarp(f):
        return T * (1.0 - math.sqrt(max(0.0, 1.0 - 2.0 * (f - fc) / T)))

    def blend(t):                      # run -> idle, flat at both ends (no jolt at the contact, none at rest)
        x = t / T
        return x * x * (3.0 - 2.0 * x)

    h0 = run(fc, "Hips")[1]
    v0 = along(run(fc + 1, "Hips")[1] - run(fc - 1, "Hips")[1]) * 0.5
    D = v0 * T / 2.0
    shift = h0 + fwd * D - hips_idle                     # the idle, moved to where the hips come to rest
    shift.z = 0.0
    I = {n: (R, h + shift) for n, (R, h) in idle.items()}

    def hips_at(t):
        f, w = warp(t), blend(t)
        h = run(f, "Hips")[1].lerp(I["Hips"][1], w)
        return h + fwd * ((along(h0) + v0 * (t - t * t / (2.0 * T))) - along(h))

    def travel(t):
        return fwd * (along(hips_at(t)) - along(hips_at(0)))

    feet = {}
    offs = {}
    for sd in ("Left", "Right"):
        offs[sd[0]] = idle[sd + "Foot"][0].transposed() @ (idle[sd + "Foot"][1] - idle[sd + "ToeBase"][1])
    # the striking foot: the run's own until its flat stance, pinned while the other steps through, then it rolls up and closes beside it
    def lifted(R, deg, v):
        lat = up.cross(fwd).normalized()
        for sgn in (1.0, -1.0):
            Rr = Matrix.Rotation(math.radians(deg) * sgn, 3, lat) @ R
            if (Rr @ v).z > (R @ v).z:
                return Rr
        return R

    t_flat = int(math.ceil(unwarp(fs)))
    k_heel, k_off, k_air, k_down = [int(round(x * T)) for x in RUN_STOP_CLOSE]
    k_heel = max(k_heel, t_flat)            # a foot that flattens late (the female's) rolls up after it is flat, never before
    k_off = max(k_off, k_heel + 1)
    keys = [(t, run(warp(t), side + "ToeBase")[1], run(warp(t), side + "ToeBase")[0], run(warp(t), side + "Foot")[0]) for t in range(0, t_flat)]
    b = run(fs, side + "ToeBase")[1]
    Rt_b, Rf_b = run(fs, side + "ToeBase")[0], run(fs, side + "Foot")[0]
    keys.append((t_flat, b, Rt_b, Rf_b))
    keys.append((k_heel, b, Rt_b, Rf_b))
    Rf_up = lifted(Rf_b, 45.0, offs[side[0]])
    keys.append((k_off, b + up * 0.01, Rt_b, Rf_up))   # the toes stay flat on the floor as the heel rolls up over them
    end_s = I[side + "ToeBase"][1]
    keys.append((k_air, b.lerp(end_s, 0.75) + up * RUN_STOP_LIFT, I[side + "ToeBase"][0], I[side + "Foot"][0]))
    keys.append((k_down, end_s, I[side + "ToeBase"][0], I[side + "Foot"][0]))
    keys.append((T, end_s, I[side + "ToeBase"][0], I[side + "Foot"][0]))
    feet[side[0]] = (keys, {"flat": t_flat, "heel": k_heel, "toe_off": k_off, "down": k_down})
    # the other foot: the run's swing, then down one step ahead on its idle place, where it stays
    t_sw, t_land = [int(round(x * T)) for x in RUN_STOP_SWING]
    keys = [(t, run(warp(t), other + "ToeBase")[1], run(warp(t), other + "ToeBase")[0], run(warp(t), other + "Foot")[0]) for t in range(0, t_sw + 1)]
    target = I[other + "ToeBase"][1]
    keys.append((t_land, target, I[other + "ToeBase"][0], I[other + "Foot"][0]))
    keys.append((T, target, I[other + "ToeBase"][0], I[other + "Foot"][0]))
    feet[other[0]] = (keys, {"swing_until": t_sw, "down": t_land})

    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for t in range(0, T + 1):
        arm.location = travel(t)
        arm.keyframe_insert("location", frame=t + 1)
    empties = {}
    for s in ("L", "R"):
        toe = bpy.data.objects.new(IK_NAME % (s, "toe"), None)
        foot = bpy.data.objects.new(IK_NAME % (s, "foot"), None)
        ankle = bpy.data.objects.new(IK_NAME % (s, "ankle"), None)
        for o, kind, size in ((toe, 'CIRCLE', 0.05), (foot, 'ARROWS', 0.04), (ankle, 'SPHERE', 0.015)):
            sc.collection.objects.link(o)
            o.empty_display_type = kind
            o.empty_display_size = size
            o.rotation_mode = 'QUATERNION'
            o.show_in_front = True
        foot.parent = toe
        ankle.parent = foot
        ankle.location = offs[s]
        empties[s] = (toe, foot, ankle)
        last_t, last_f = None, None
        for t, loc, Rt, Rf in feet[s][0]:
            qt = _quat_near(Rt.to_quaternion(), last_t)
            qf = _quat_near((Rt.transposed() @ Rf).to_quaternion(), last_f)
            last_t, last_f = qt, qf
            toe.location = loc
            toe.rotation_quaternion = qt
            foot.rotation_quaternion = qf
            toe.keyframe_insert("location", frame=t + 1)
            toe.keyframe_insert("rotation_quaternion", frame=t + 1)
            foot.keyframe_insert("rotation_quaternion", frame=t + 1)
    off_hip = {s: rig.R["Hips"].transposed() @ (arm.data.bones[PREFIX + s + "UpLeg"].head_local - arm.data.bones[PREFIX + "Hips"].head_local) for s in ("Left", "Right")}
    thigh = {s: (idle[s + "Leg"][1] - idle[s + "UpLeg"][1]).length for s in ("Left", "Right")}
    shin = {s: (idle[s + "Foot"][1] - idle[s + "Leg"][1]).length for s in ("Left", "Right")}
    last_q = {}
    body_frames = []
    for frac, _marker in RUN_STOP_BODY:
        t = int(round(frac * T))
        body_frames.append(t + 1)
        sc.frame_set(t + 1)
        bpy.context.view_layer.update()
        f, w = warp(t), blend(t)
        P = {}
        for n in rig.names:
            qr = run(f, n)[0].to_quaternion()
            P[n] = qr.slerp(_quat_near(I[n][0].to_quaternion(), qr), w).to_matrix()
        hips_arm = hips_at(t) - travel(t)
        for sd in ("Left", "Right"):
            toe, foot, ankle = empties[sd[0]]
            tgt = ankle.matrix_world.translation - travel(t)
            hip_j = hips_arm + P["Hips"] @ off_hip[sd]
            knee, end = _two_bone(hip_j, tgt, thigh[sd], shin[sd], hip_j + fwd * 1.0 - up * 0.3)
            P[sd + "UpLeg"] = _aim_bone(P[sd + "UpLeg"], hip_j, knee)
            P[sd + "Leg"] = _aim_bone(P[sd + "Leg"], knee, end)
            P[sd + "Foot"] = foot.matrix_world.to_3x3().normalized()
            P[sd + "ToeBase"] = toe.matrix_world.to_3x3().normalized()
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            if is_finger(n):
                q = idle_q[pb.name].copy()
            else:
                p = rig.parent[n]
                rp = rig.R[p] if p else Matrix.Identity(3)
                pp = P[p] if p else Matrix.Identity(3)
                q = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            if t == T:
                q = idle_q[pb.name].copy()            # the last frame IS the idle, exactly
            q = _quat_near(q, last_q.get(n))
            last_q[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t + 1)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips_arm
        h.matrix = m
        h.keyframe_insert("location", frame=t + 1)
    for sd in ("Left", "Right"):
        toe, foot, ankle = empties[sd[0]]
        ik = arm.pose.bones[PREFIX + sd + "Leg"].constraints.new('IK')
        ik.name = "IK foot"
        ik.target = ankle
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        ik.iterations = 500
        for bone, src in ((sd + "Foot", foot), (sd + "ToeBase", toe)):
            c = arm.pose.bones[PREFIX + bone].constraints.new('COPY_ROTATION')
            c.name = "IK foot rotation"
            c.target = src
            c.target_space = 'WORLD'
            c.owner_space = 'WORLD'
            c.mix_mode = 'REPLACE'
    sc.timeline_markers.clear()
    for (frac, marker), frame in zip(RUN_STOP_BODY, body_frames):
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = 1, T + 1
    tag = "StopL" if side == "Left" else "StopR"
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        inner = body_frames[1:-1]
        for i, frame in enumerate(inner):
            kb = coat.shape_key_add(name=f"{tag}Fix_f{frame:02d}", from_mix=False)
            prev = body_frames[i]
            nxt = body_frames[i + 2]
            for f2, v in ((prev, 0.0), (frame, 1.0), (nxt, 0.0)):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        blocks = coat.data.shape_keys.key_blocks
        for name, (v_first, v_last) in (("RunFix", (1.0, 0.0)), ("IdleFix", (0.0, 1.0))):
            if name not in blocks:
                print(f"[tripo_pose_lab] WARNING: the coat has no {name}: the stop's end is not the game's pose")
                continue
            for frame, v in ((body_frames[0], v_first), (body_frames[-1], v_last)):
                blocks[name].value = v
                blocks[name].keyframe_insert("value", frame=frame)
        coat.active_shape_key_index = list(blocks.keys()).index(f"{tag}Fix_f{inner[0]:02d}")
    stop = D
    arm["lab_pose"] = "run_stop_" + side[0].lower()
    arm["lab_props"] = json.dumps([])
    arm["lab_run_start"] = json.dumps({"clip": os.path.basename(clip_glb), "from_frame": fc, "to_frame": fc, "frames": T, "travel": stop, "side": side,
                                       "planted": {"flat": feet[side[0]][1]["flat"]}, "pinned_until": k_heel + 1,
                                       "strike": feet[side[0]][1], "step": feet[other[0]][1]})
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} stop on the {side.lower()} foot, frames 1-{T + 1}: the run from its contact "
          f"{fc} (flat at {fs}) braking to rest, travel {stop:.3f} m at {v0:.4f} m/frame (clip turned {math.degrees(yaw):.1f} deg); {side.lower()} {feet[side[0]][1]}, {other.lower()} {feet[other[0]][1]}")


# THE WALK'S STOP (2026-11-14, Director: one per figure, "último passo"): a walker is slow enough to stop over the foot that strikes (at the left heel's contact
# the hips are ~0.15 figure-m behind it at ~0.03 m/frame), so it is ONE step: the left foot plants where the idle has it and stays, the hips brake at a constant
# deceleration onto the idle's, the right rolls off and closes beside it. Its length follows from the walk (T = 2 D / v). Ends: WalkFix 1 -> 0, IdleFix 0 -> 1.
WALK_CYCLE = 28                                # the bank walk's frames per cycle (one GU)
WALK_STOP_CONTACT = {"Left": 22}               # the bank walk's frame of the left heel's contact before the cycle's end (the cell's centre)
WALK_STOP_BODY = ((0.0, "walk"), (0.5, "brake"), (1.0, "idle"))
WALK_STOP_SWING = (0.3, 0.85)                  # the closing foot: follows the walk's roll and swing until, is down beside the other at (fractions)
WALK_STOP_LIFT = 0.04                          # its height over the floor half way (figure metres)


def walk_stop_new(base_blend, clip_glb, out_blend, side="Left"):
    """THE WALK -> IDLE STOP of one figure (see WALK_STOP_CONTACT): one step, its foot plants where the idle has it and stays, the other closes beside it."""
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    sc.frame_set(1)
    bpy.context.view_layer.update()
    idle = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    idle_q = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    hips_idle = idle["Hips"][1]
    arm.animation_data_clear()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_") or o.name.startswith("IK_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    other = "Left" if side == "Right" else "Right"
    fc = WALK_STOP_CONTACT[side]
    clip = _clip_frames(arm, clip_glb, list(range(0, WALK_CYCLE + 1)))
    up = Vector((0.0, 0.0, 1.0))
    fwd = sum(((idle[s + "ToeBase"][1] - idle[s + "Foot"][1]) for s in ("Left", "Right")), Vector())
    fwd.z = 0.0
    fwd.normalize()
    drift = clip[WALK_CYCLE]["Hips"][1] - clip[0]["Hips"][1]
    drift.z = 0.0
    yaw = math.atan2(fwd.y, fwd.x) - math.atan2(drift.y, drift.x)
    Rz = Matrix.Rotation(yaw, 3, 'Z')
    c0 = clip[0]["Hips"][1]

    def turned(f, n):
        a = min(int(math.floor(f)), WALK_CYCLE - 1)
        u = f - a
        Pa, ha = clip[a][n]
        Pb, hb = clip[a + 1][n]
        qa, qb = Pa.to_quaternion(), Pb.to_quaternion()
        q = qa.slerp(_quat_near(qb, qa), u)
        return (Rz @ q.to_matrix()).normalized(), c0 + Rz @ (ha.lerp(hb, u) - c0)

    # the planted foot's flat stance: the first frame after the contact whose ball is down
    ball_z = min(turned(f, side + "ToeBase")[1].z for f in range(fc, fc + 5))
    fs = next(f for f in range(fc, fc + 5) if turned(f, side + "ToeBase")[1].z < ball_z + 0.004)
    A = idle[side + "ToeBase"][1] - turned(fs, side + "ToeBase")[1]
    A.z = 0.0

    def run(f, n):
        P, h = turned(f, n)
        return P, h + A

    def along(v):
        return v.dot(fwd)

    # the planted foot IS the idle's, so the hips come to rest where the idle has them: the stop's length and its frames follow from the walk's speed
    h0 = run(fc, "Hips")[1]
    v0 = along(run(fc + 1, "Hips")[1] - run(fc - 1, "Hips")[1]) * 0.5
    D = along(hips_idle - h0)
    if D <= 0.0 or v0 <= 0.0:
        fail(f"the walk's hips at its contact {fc} are already past the idle's ({D:.3f} m): no stop to brake")
    T = max(6, int(round(2.0 * D / v0)))
    v0 = 2.0 * D / T                                      # the braking that ends exactly on the idle's hips in T frames
    I = dict(idle)

    def warp(t):                       # the run's phase, braking from 1 frame per frame to rest
        return fc + t - t * t / (2.0 * T)

    def unwarp(f):
        return T * (1.0 - math.sqrt(max(0.0, 1.0 - 2.0 * (f - fc) / T)))

    def blend(t):                      # run -> idle, flat at both ends (no jolt at the contact, none at rest)
        x = t / T
        return x * x * (3.0 - 2.0 * x)


    def hips_at(t):
        f, w = warp(t), blend(t)
        h = run(f, "Hips")[1].lerp(I["Hips"][1], w)
        return h + fwd * ((along(h0) + v0 * (t - t * t / (2.0 * T))) - along(h))

    def travel(t):
        return fwd * (along(hips_at(t)) - along(hips_at(0)))

    feet = {}
    offs = {}
    for sd in ("Left", "Right"):
        offs[sd[0]] = idle[sd + "Foot"][0].transposed() @ (idle[sd + "Foot"][1] - idle[sd + "ToeBase"][1])
    # the striking foot: the run's own until its flat stance, pinned while the other steps through, then it rolls up and closes beside it
    def lifted(R, deg, v):
        lat = up.cross(fwd).normalized()
        for sgn in (1.0, -1.0):
            Rr = Matrix.Rotation(math.radians(deg) * sgn, 3, lat) @ R
            if (Rr @ v).z > (R @ v).z:
                return Rr
        return R

    t_flat = min(int(math.ceil(unwarp(fs))), T - 1)
    keys = [(t, run(warp(t), side + "ToeBase")[1], run(warp(t), side + "ToeBase")[0], run(warp(t), side + "Foot")[0]) for t in range(0, t_flat)]
    keys.append((t_flat, I[side + "ToeBase"][1], I[side + "ToeBase"][0], I[side + "Foot"][0]))
    keys.append((T, I[side + "ToeBase"][1], I[side + "ToeBase"][0], I[side + "Foot"][0]))
    feet[side[0]] = (keys, {"flat": t_flat})
    k_heel = T
    # the other foot: the walk's own roll off the floor and swing, then down beside the planted one on its idle place
    t_sw, t_land = [int(round(x * T)) for x in WALK_STOP_SWING]
    keys = [(t, run(warp(t), other + "ToeBase")[1], run(warp(t), other + "ToeBase")[0], run(warp(t), other + "Foot")[0]) for t in range(0, t_sw + 1)]
    target = I[other + "ToeBase"][1]
    k_mid = int(round(0.5 * (t_sw + t_land)))
    if t_sw < k_mid < t_land:
        keys.append((k_mid, keys[-1][1].lerp(target, 0.6) + up * WALK_STOP_LIFT, I[other + "ToeBase"][0], I[other + "Foot"][0]))
    keys.append((t_land, target, I[other + "ToeBase"][0], I[other + "Foot"][0]))
    keys.append((T, target, I[other + "ToeBase"][0], I[other + "Foot"][0]))
    feet[other[0]] = (keys, {"swing_until": t_sw, "down": t_land})

    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for t in range(0, T + 1):
        arm.location = travel(t)
        arm.keyframe_insert("location", frame=t + 1)
    empties = {}
    for s in ("L", "R"):
        toe = bpy.data.objects.new(IK_NAME % (s, "toe"), None)
        foot = bpy.data.objects.new(IK_NAME % (s, "foot"), None)
        ankle = bpy.data.objects.new(IK_NAME % (s, "ankle"), None)
        for o, kind, size in ((toe, 'CIRCLE', 0.05), (foot, 'ARROWS', 0.04), (ankle, 'SPHERE', 0.015)):
            sc.collection.objects.link(o)
            o.empty_display_type = kind
            o.empty_display_size = size
            o.rotation_mode = 'QUATERNION'
            o.show_in_front = True
        foot.parent = toe
        ankle.parent = foot
        ankle.location = offs[s]
        empties[s] = (toe, foot, ankle)
        last_t, last_f = None, None
        for t, loc, Rt, Rf in feet[s][0]:
            qt = _quat_near(Rt.to_quaternion(), last_t)
            qf = _quat_near((Rt.transposed() @ Rf).to_quaternion(), last_f)
            last_t, last_f = qt, qf
            toe.location = loc
            toe.rotation_quaternion = qt
            foot.rotation_quaternion = qf
            toe.keyframe_insert("location", frame=t + 1)
            toe.keyframe_insert("rotation_quaternion", frame=t + 1)
            foot.keyframe_insert("rotation_quaternion", frame=t + 1)
    off_hip = {s: rig.R["Hips"].transposed() @ (arm.data.bones[PREFIX + s + "UpLeg"].head_local - arm.data.bones[PREFIX + "Hips"].head_local) for s in ("Left", "Right")}
    thigh = {s: (idle[s + "Leg"][1] - idle[s + "UpLeg"][1]).length for s in ("Left", "Right")}
    shin = {s: (idle[s + "Foot"][1] - idle[s + "Leg"][1]).length for s in ("Left", "Right")}
    last_q = {}
    body_frames = []
    for frac, _marker in WALK_STOP_BODY:
        t = int(round(frac * T))
        body_frames.append(t + 1)
        sc.frame_set(t + 1)
        bpy.context.view_layer.update()
        f, w = warp(t), blend(t)
        P = {}
        for n in rig.names:
            qr = run(f, n)[0].to_quaternion()
            P[n] = qr.slerp(_quat_near(I[n][0].to_quaternion(), qr), w).to_matrix()
        hips_arm = hips_at(t) - travel(t)
        for sd in ("Left", "Right"):
            toe, foot, ankle = empties[sd[0]]
            tgt = ankle.matrix_world.translation - travel(t)
            hip_j = hips_arm + P["Hips"] @ off_hip[sd]
            knee, end = _two_bone(hip_j, tgt, thigh[sd], shin[sd], hip_j + fwd * 1.0 - up * 0.3)
            P[sd + "UpLeg"] = _aim_bone(P[sd + "UpLeg"], hip_j, knee)
            P[sd + "Leg"] = _aim_bone(P[sd + "Leg"], knee, end)
            P[sd + "Foot"] = foot.matrix_world.to_3x3().normalized()
            P[sd + "ToeBase"] = toe.matrix_world.to_3x3().normalized()
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            if is_finger(n):
                q = idle_q[pb.name].copy()
            else:
                p = rig.parent[n]
                rp = rig.R[p] if p else Matrix.Identity(3)
                pp = P[p] if p else Matrix.Identity(3)
                q = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            if t == T:
                q = idle_q[pb.name].copy()            # the last frame IS the idle, exactly
            q = _quat_near(q, last_q.get(n))
            last_q[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t + 1)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips_arm
        h.matrix = m
        h.keyframe_insert("location", frame=t + 1)
    for sd in ("Left", "Right"):
        toe, foot, ankle = empties[sd[0]]
        ik = arm.pose.bones[PREFIX + sd + "Leg"].constraints.new('IK')
        ik.name = "IK foot"
        ik.target = ankle
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        ik.iterations = 500
        for bone, src in ((sd + "Foot", foot), (sd + "ToeBase", toe)):
            c = arm.pose.bones[PREFIX + bone].constraints.new('COPY_ROTATION')
            c.name = "IK foot rotation"
            c.target = src
            c.target_space = 'WORLD'
            c.owner_space = 'WORLD'
            c.mix_mode = 'REPLACE'
    sc.timeline_markers.clear()
    for (frac, marker), frame in zip(WALK_STOP_BODY, body_frames):
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = 1, T + 1
    tag = "WStop"
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        inner = body_frames[1:-1]
        for i, frame in enumerate(inner):
            kb = coat.shape_key_add(name=f"{tag}Fix_f{frame:02d}", from_mix=False)
            prev = body_frames[i]
            nxt = body_frames[i + 2]
            for f2, v in ((prev, 0.0), (frame, 1.0), (nxt, 0.0)):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        blocks = coat.data.shape_keys.key_blocks
        for name, (v_first, v_last) in (("WalkFix", (1.0, 0.0)), ("IdleFix", (0.0, 1.0))):
            if name not in blocks:
                print(f"[tripo_pose_lab] WARNING: the coat has no {name}: the stop's end is not the game's pose")
                continue
            for frame, v in ((body_frames[0], v_first), (body_frames[-1], v_last)):
                blocks[name].value = v
                blocks[name].keyframe_insert("value", frame=frame)
        coat.active_shape_key_index = list(blocks.keys()).index(f"{tag}Fix_f{inner[0]:02d}")
    stop = D
    arm["lab_pose"] = "walk_stop"
    arm["lab_props"] = json.dumps([])
    arm["lab_run_start"] = json.dumps({"clip": os.path.basename(clip_glb), "from_frame": fc, "to_frame": fc, "frames": T, "travel": stop, "side": side,
                                       "planted": {"flat": feet[side[0]][1]["flat"]}, "pinned_until": T + 1,
                                       "strike": feet[side[0]][1], "step": feet[other[0]][1]})
    sc.frame_set(1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} walk stop on the {side.lower()} foot, frames 1-{T + 1}: the walk from its contact "
          f"{fc} (flat at {fs}) braking to rest, travel {stop:.3f} m at {v0:.4f} m/frame (clip turned {math.degrees(yaw):.1f} deg); {side.lower()} {feet[side[0]][1]}, {other.lower()} {feet[other[0]][1]}")


# THE CROUCH (MOVEMENT 2026-11-14, Director: "a pose crouch, partindo do idle"; DESIGN §8.2's crouch): a KNEEL, the right knee on the floor, the left foot
# planted ahead, the trunk leaning over it, the left forearm meant to rest on the left knee (its arms are a starting point for the Director's hands). One
# timeline per figure, `SEQ_crouch_<FIG>.blend`: frame 1 the idle (the base's frame 1), then the left foot steps forward while the body goes down, the right
# heel rolls up over its toes and the right knee lands, and the last frame is the held crouch. The legs are IK on the same reverse feet as the run's passages.
# The kneel is placed, not taken from a clip: the right knee touches the floor KNEE_FWD ahead of the idle's right ball, the right thigh tilted back from
# it carries the hips, the left ankle stands FOOT_AHEAD ahead of the left hip joint; the right foot's heel is up RIGHT_HEEL_DEG over its toes, which bend flat.
CROUCH_FRAMES = 20
CROUCH_BODY = ((0.0, "idle"), (0.4, "step"), (0.75, "knee"), (1.0, "crouch"))
CROUCH_KNEE_FWD = 0.06           # the right knee's place AHEAD of the idle's right ball (figure metres; Director 2026-11-14: a compact kneel, the feet close)
CROUCH_KNEE_Z = 0.035            # the knee's centre over the floor (the trousers' thickness)
CROUCH_FOOT_AHEAD = 0.13         # the left ankle ahead of the left hip joint (the left knee folds high)
CROUCH_THIGH_DEG = 35.0          # the right thigh's tilt from vertical, the knee ahead of the hip: the body sits back toward the right heel
CROUCH_RIGHT_HEEL_DEG = 70.0     # the kneeling foot: the heel this far up over the toes
CROUCH_LEFT_STEP = (0.05, 0.25, 0.4)   # the left foot: leaves the floor, in the air half way, down on its place (fractions)
CROUCH_RIGHT = (0.15, 0.75)      # the right foot: heel starts up, at its kneeling place (fractions)
CROUCH_LEAN_DEG = 22.0           # the trunk's lean forward at the crouch (on the Spine), given back by the neck so the head looks ahead
CROUCH_ENDS = ("IdleFix", "CrouchFix")
# THE CONE VARIANT (Director 2026-11-15, `crouch_new ... cone`): a key right after the idle opens the coat's skirt outward all round into a wide cone (the back
# lifted too, clear of the kneeling leg) and raises both arms a little, the shoulders turned; then every key keeps the skirt off the legs, hanging to each
# side of the waist. A DRAFT the Director finishes by hand: the coat keys are made here by measurement, not sculpted.
CROUCH_CONE_BODY = ((0.0, "idle"), (0.15, "open"), (0.4, "step"), (0.75, "knee"), (1.0, "crouch"))
CROUCH_CONE_SHARE = {"open": 1.0, "step": 0.8, "knee": 0.55, "crouch": 0.35}   # how much of the cone and of the raised arms each key keeps
CROUCH_CONE_OUT = 0.11           # the hem's outward push at the full cone (figure metres), less toward the waist
CROUCH_CONE_UP = 0.03            # the hem lifted all round
CROUCH_CONE_BACK_UP = 0.07       # the back of the hem lifted further
CROUCH_ARM_OUT_DEG = 18.0        # the arms away from the body (about the front axis)
CROUCH_SHOULDER_DEG = 7.0        # the shoulders turned up with them
CROUCH_LEG_CLEAR = {"thigh": 0.085, "shin": 0.065}   # the skirt kept this far from each leg's bone line (the leg's own radius + a gap)
CROUCH_FLOOR_CLEAR = 0.015
CROUCH_LEFT_THIGH_CLEAR = 0.13   # the raised left thigh gets a wider gap, at full width up to the waist (Director 2026-11-15: it showed through the front flap)
CROUCH_SMOOTH_R = 0.06          # the radius the skirt's offsets are smoothed over, in the rest coat (figure metres)


def _is_below(rig, n, root):
    p = rig.parent[n]
    while p:
        if p == root:
            return True
        p = rig.parent[p]
    return False


def _coat_world(coat):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = coat.evaluated_get(dg)
    M = ev.matrix_world
    return [M @ v.co for v in ev.data.vertices]


def _seg_push(p, a, b, r):
    ab = b - a
    t = min(max((p - a).dot(ab) / max(ab.length_squared, 1e-12), 0.0), 1.0)
    c = a + ab * t
    d = p - c
    if d.length >= r:
        return p
    if d.length < 1e-6:
        d = Vector((0.0, 0.0, 1.0))
    return c + d.normalized() * r


def _crouch_cone_keys(arm, coat, rows, fwd, first_frame):
    """The cone variant's coat keys, by measurement: at each key's frame, the coat as the timeline poses it WITHOUT that key, the skirt pushed into the
    cone (its share), then out of every leg's capsule and above the floor; the world offsets brought back to the key's rest space through each vertex's
    measured response (three probe evaluations, so whatever deforms the coat is honoured), smoothed over the mesh."""
    sc = bpy.context.scene
    blocks = coat.data.shape_keys.key_blocks
    basis = [v.co.copy() for v in blocks[0].data]
    nv = len(basis)
    arm_groups = {g.index for g in coat.vertex_groups if any(k in g.name for k in ("Arm", "Hand", "Shoulder"))}
    sleeve = [sum(g.weight for g in v.groups if g.group in arm_groups) for v in coat.data.vertices]
    sc.frame_set(first_frame)
    bpy.context.view_layer.update()
    rest_w = _coat_world(coat)
    z_belt = (arm.matrix_world @ arm.pose.bones[PREFIX + "Hips"].head).z
    z_hem = min(p.z for p in rest_w)
    skirt = [0.0 if sleeve[i] > 0.2 else min(max((z_belt - rest_w[i].z) / max(z_belt - z_hem, 1e-6), 0.0), 1.0) for i in range(nv)]
    from mathutils.kdtree import KDTree
    tree = KDTree(nv)
    for i, p in enumerate(rest_w):
        tree.insert(p, i)
    tree.balance()
    near = []                            # each skirt vertex's neighbours in the rest coat, Gaussian weights summing to 1
    for i, p in enumerate(rest_w):
        if skirt[i] <= 0.0:
            near.append([])
            continue
        found = tree.find_range(p, CROUCH_SMOOTH_R)
        ws = [(j, math.exp(-(d / (0.5 * CROUCH_SMOOTH_R)) ** 2)) for _co, j, d in found]
        tot = sum(w for _j, w in ws)
        near.append([(j, w / tot) for j, w in ws])
    up = Vector((0.0, 0.0, 1.0))
    for frame, name, share in rows:
        kb = blocks[name]
        for v, b0 in zip(kb.data, basis):
            v.co = b0
        kb.mute = True
        sc.frame_set(frame)
        bpy.context.view_layer.update()
        P0 = _coat_world(coat)
        kb.mute = False
        Mw = arm.matrix_world
        hips = Mw @ arm.pose.bones[PREFIX + "Hips"].head
        segs = []
        for side in ("Left", "Right"):
            up_leg, leg, foot = (Mw @ arm.pose.bones[PREFIX + side + b].head for b in ("UpLeg", "Leg", "Foot"))
            segs += [(up_leg, leg, CROUCH_LEFT_THIGH_CLEAR if side == "Left" else CROUCH_LEG_CLEAR["thigh"]), (leg, foot, CROUCH_LEG_CLEAR["shin"])]
        want = []
        for i, p in enumerate(P0):
            s = skirt[i]
            if s <= 0.0:
                want.append(p.copy())
                continue
            radial = Vector((p.x - hips.x, p.y - hips.y, 0.0))
            radial = radial.normalized() if radial.length > 1e-6 else fwd.copy()
            back = max(0.0, -radial.dot(fwd))
            q = p + (radial * CROUCH_CONE_OUT * s ** 1.3 + up * (CROUCH_CONE_UP + CROUCH_CONE_BACK_UP * back) * s * s) * share
            for _it in range(3):
                for a, b, r in segs:
                    q = _seg_push(q, a, b, (r if r == CROUCH_LEFT_THIGH_CLEAR else r * min(1.0, 0.4 + s)))
            q.z = max(q.z, CROUCH_FLOOR_CLEAR)
            want.append(q)
        dw = [w - p for w, p in zip(want, P0)]
        for _round in range(4):          # smoothed in SPACE (the coat's layers, outer and lining, share no edges: an edge smoothing tore them apart), then
            dw = [sum((dw[j] * wt for j, wt in near[i]), Vector()) if near[i] else dw[i] for i in range(nv)]   # what it let back into a leg comes out
            for i, p in enumerate(P0):
                if skirt[i] > 0.0:
                    q = p + dw[i]
                    for a, b, r in segs:
                        q = _seg_push(q, a, b, (r if r == CROUCH_LEFT_THIGH_CLEAR else r * min(1.0, 0.4 + skirt[i])))
                    q.z = max(q.z, CROUCH_FLOOR_CLEAR)
                    dw[i] = q - p
        dw = [sum((dw[j] * wt for j, wt in near[i]), Vector()) if near[i] else dw[i] for i in range(nv)]
        J = []                           # each vertex's world response to a unit rest offset, per axis
        for axis in range(3):
            e = Vector((0.0, 0.0, 0.0))
            e[axis] = 0.01
            for v, b0 in zip(kb.data, basis):
                v.co = b0 + e
            bpy.context.view_layer.update()
            P1 = _coat_world(coat)
            J.append([(p1 - p0) / 0.01 for p1, p0 in zip(P1, P0)])
        moved = 0
        for i in range(nv):
            if dw[i].length < 1e-5:
                kb.data[i].co = basis[i]
                continue
            M = Matrix((J[0][i], J[1][i], J[2][i])).transposed()
            try:
                kb.data[i].co = basis[i] + M.inverted() @ dw[i]
                moved += 1
            except ValueError:
                kb.data[i].co = basis[i]
        bpy.context.view_layer.update()
        print(f"[tripo_pose_lab] cone key {name} at frame {frame} (share {share}): {moved} vertices moved, largest {max(d.length for d in dw):.3f} m")


# THE CROUCHED DRAW (Director, 2026-11-15): "pegar a pose crouched final e fazer o draw da pistola + aim agachado, movimentando só ombros e
# braços, usando os mesmos parâmetros do draw em pé". Everything but the shoulders, arms and hands holds the crouch's LAST frame (as seen,
# its legs' IK baked into plain rotations); the arms keep the standing draw's keys from frame 2 on, frame 1 being the crouch's arms.
DRAW_CROUCH_ARM = ("Shoulder", "Arm", "Hand")   ## LeftShoulder, LeftArm, LeftForeArm, LeftHand and its fingers


def draw_crouch_new(draw_blend, crouch_blend, out_blend):
    """the crouched draw + aim timeline from the figure's standing draw (`SEQ_draw_pistol_<FIG>_arm6`) and its crouch (`SEQ_crouch_<FIG>_fast`)"""
    bpy.ops.wm.open_mainfile(filepath=crouch_blend)
    sc = bpy.context.scene
    sc.frame_set(sc.frame_end)
    bpy.context.view_layer.update()
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    pose = {}
    for pb in arm.pose.bones:   # the evaluated pose (IK included) back in each bone's local space
        m = arm.convert_space(pose_bone=pb, matrix=pb.matrix, from_space='POSE', to_space='LOCAL')
        pose[pb.name] = (m.to_translation(), m.to_quaternion())
    coat = bpy.data.objects[COAT_OBJECT]
    end_key = next(k for k in coat.data.shape_keys.key_blocks if k.name.startswith("CrouchFix_f") and int(k.name[11:13]) == sc.frame_end)
    key_name = end_key.name
    key_co = [v.co.copy() for v in end_key.data]
    basis_co = [v.co.copy() for v in coat.data.shape_keys.key_blocks[0].data]

    bpy.ops.wm.open_mainfile(filepath=draw_blend)
    sc = bpy.context.scene
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    act = arm.animation_data.action
    bags = [cb for l in act.layers for st in l.strips for cb in st.channelbags]
    is_arm = lambda name: any(t in name for t in DRAW_CROUCH_ARM)
    for cb in bags:
        for fc in list(cb.fcurves):
            if not fc.data_path.startswith("pose.bones["):
                continue
            bone = fc.data_path.split('"')[1]
            if bone not in pose:
                continue
            loc, q = pose[bone]
            if fc.data_path.endswith("rotation_quaternion"):
                value = q[fc.array_index]
            elif fc.data_path.endswith("location"):
                value = loc[fc.array_index]
            else:
                continue
            if is_arm(bone):   # frame 1 = the crouch's arms; the draw's own keys from frame 2 on
                for kp in fc.keyframe_points:
                    if int(round(kp.co[0])) == sc.frame_start:
                        kp.co[1] = value
                        kp.handle_left[1] = kp.handle_right[1] = value
            else:              # held: the crouch's last frame all along
                while len(fc.keyframe_points) > 1:
                    fc.keyframe_points.remove(fc.keyframe_points[-1])
                fc.keyframe_points[0].co = (sc.frame_start, value)
                fc.keyframe_points[0].handle_left = fc.keyframe_points[0].handle_right = (sc.frame_start, value)
            fc.update()
    for pb in arm.pose.bones:   # every held bone keyed, even one the draw never keyed (the Hips' drop, the legs)
        if not is_arm(pb.name) and pb.name in pose:
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("location", frame=sc.frame_start)
            pb.keyframe_insert("rotation_quaternion", frame=sc.frame_start)
    for pb in arm.pose.bones:   # quaternion signs: an arm's frame-1 key on the same side as its next key
        qs = [cb.fcurves.find(f'pose.bones["{pb.name}"].rotation_quaternion', index=i) for cb in bags for i in range(4)]
        qs = [f for f in qs if f is not None]
        if len(qs) == 4 and is_arm(pb.name) and len(qs[0].keyframe_points) > 1:
            a = [f.keyframe_points[0].co[1] for f in qs]
            b = [f.keyframe_points[1].co[1] for f in qs]
            if sum(x * y for x, y in zip(a, b)) < 0:
                for f in qs:
                    k = f.keyframe_points[0]
                    k.co[1] = -k.co[1]
                    k.handle_left[1] = k.handle_right[1] = k.co[1]
                    f.update()
    coat = bpy.data.objects[COAT_OBJECT]
    blocks = coat.data.shape_keys.key_blocks
    if any((a - b).length > 1e-5 for a, b in zip(basis_co, [v.co for v in blocks[0].data])):
        sys.exit("[tripo_pose_lab] the crouch's coat Basis differs from the draw's: the crouch key cannot be carried over")
    held = coat.shape_key_add(name=f"{key_name} (inherited)", from_mix=False)
    for v, co in zip(held.data, key_co):
        v.co = co
    held.value = 1.0
    held.keyframe_insert("value", frame=sc.frame_start)
    arm["lab_pose"] = "draw_crouch_pistol"
    sc.frame_set(sc.frame_start)
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the crouch's last frame held, the arms from the standing draw, {held.name} held at 1")



def crouch_new(base_blend, out_blend, cone=False):
    """THE IDLE -> CROUCH TIMELINE of one figure (see the block's header). Nothing is written over the base. `cone`: the cone variant (CROUCH_CONE_*)."""
    body_rows = CROUCH_CONE_BODY if cone else CROUCH_BODY
    bpy.ops.wm.open_mainfile(filepath=base_blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    sc.frame_set(1)
    bpy.context.view_layer.update()
    idle = {pb.name[len(PREFIX):]: (pb.matrix.to_3x3().normalized(), pb.head.copy()) for pb in arm.pose.bones}
    idle_q = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    arm.animation_data_clear()
    arm.location = Vector()
    for o in [o for o in bpy.data.objects if o.name.startswith("PROP_") or o.name.startswith("IK_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            o.data.shape_keys.animation_data_clear()
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    T = CROUCH_FRAMES
    up = Vector((0.0, 0.0, 1.0))
    fwd = sum(((idle[s + "ToeBase"][1] - idle[s + "Foot"][1]) for s in ("Left", "Right")), Vector())
    fwd.z = 0.0
    fwd.normalize()
    lat = up.cross(fwd).normalized()
    hips_idle = idle["Hips"][1]
    off_hip = {s: rig.R["Hips"].transposed() @ (arm.data.bones[PREFIX + s + "UpLeg"].head_local - arm.data.bones[PREFIX + "Hips"].head_local) for s in ("Left", "Right")}
    thigh = {s: (idle[s + "Leg"][1] - idle[s + "UpLeg"][1]).length for s in ("Left", "Right")}
    shin = {s: (idle[s + "Foot"][1] - idle[s + "Leg"][1]).length for s in ("Left", "Right")}
    offs = {s[0]: idle[s + "Foot"][0].transposed() @ (idle[s + "Foot"][1] - idle[s + "ToeBase"][1]) for s in ("Left", "Right")}

    def lifted(R, deg, v):
        for sgn in (1.0, -1.0):
            Rr = Matrix.Rotation(math.radians(deg) * sgn, 3, lat) @ R
            if (Rr @ v).z > (R @ v).z:
                return Rr
        return R

    # the kneel: the right knee K, the hips over it, the kneeling foot found so the solved knee lands on K
    P_hips = idle["Hips"][0]
    bR = idle["RightToeBase"][1]
    K = bR + fwd * CROUCH_KNEE_FWD
    K.z = CROUCH_KNEE_Z
    a = math.radians(CROUCH_THIGH_DEG)
    hipR = K + (up * math.cos(a) - fwd * math.sin(a)) * thigh["Right"] * 0.985
    hips_end = hipR - P_hips @ off_hip["Right"]
    Rf_R = lifted(idle["RightFoot"][0], CROUCH_RIGHT_HEEL_DEG, offs["R"])
    Rt_R = idle["RightToeBase"][0]
    # the shin runs from the knee back down to the ankle, whose height the tilted foot sets (the toes flat on the floor)
    ank_z = idle["RightToeBase"][1].z + (Rf_R @ offs["R"]).z
    dz = ank_z - K.z
    ankR = K - fwd * math.sqrt(max(shin["Right"] ** 2 - dz * dz, 0.0)) + up * dz
    bR_end = ankR - Rf_R @ offs["R"]
    hipL = hips_end + P_hips @ off_hip["Left"]
    ankL = hipL + fwd * CROUCH_FOOT_AHEAD
    ankL.z = idle["LeftFoot"][1].z
    bL_end = ankL - idle["LeftFoot"][0] @ offs["L"]
    bL_end.z = idle["LeftToeBase"][1].z

    def ease(x):
        x = min(max(x, 0.0), 1.0)
        return x * x * (3.0 - 2.0 * x)

    def hips_at(t):                    # down by the time the knee lands (CROUCH_RIGHT's second event), held after
        return hips_idle.lerp(hips_end, ease(t / (CROUCH_RIGHT[1] * T)))

    feet = {}
    bL = idle["LeftToeBase"][1]
    l0, l1, l2 = [max(1, int(round(x * T))) for x in CROUCH_LEFT_STEP]
    feet["L"] = [(0, bL, idle["LeftToeBase"][0], idle["LeftFoot"][0]), (l0, bL, idle["LeftToeBase"][0], idle["LeftFoot"][0]),
                 (l1, bL.lerp(bL_end, 0.6) + up * 0.04, idle["LeftToeBase"][0], idle["LeftFoot"][0]),
                 (l2, bL_end, idle["LeftToeBase"][0], idle["LeftFoot"][0]), (T, bL_end, idle["LeftToeBase"][0], idle["LeftFoot"][0])]
    r0, r1 = [max(1, int(round(x * T))) for x in CROUCH_RIGHT]
    feet["R"] = [(0, bR, Rt_R, idle["RightFoot"][0]), (r0, bR, Rt_R, idle["RightFoot"][0]),
                 (int(round(0.5 * (r0 + r1))), bR.lerp(bR_end, 0.5), Rt_R, lifted(idle["RightFoot"][0], CROUCH_RIGHT_HEEL_DEG * 0.6, offs["R"])),
                 (r1, bR_end, Rt_R, Rf_R), (T, bR_end, Rt_R, Rf_R)]

    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    empties = {}
    for s in ("L", "R"):
        toe = bpy.data.objects.new(IK_NAME % (s, "toe"), None)
        foot = bpy.data.objects.new(IK_NAME % (s, "foot"), None)
        ankle = bpy.data.objects.new(IK_NAME % (s, "ankle"), None)
        for o, kind, size in ((toe, 'CIRCLE', 0.05), (foot, 'ARROWS', 0.04), (ankle, 'SPHERE', 0.015)):
            sc.collection.objects.link(o)
            o.empty_display_type = kind
            o.empty_display_size = size
            o.rotation_mode = 'QUATERNION'
            o.show_in_front = True
        foot.parent = toe
        ankle.parent = foot
        ankle.location = offs[s]
        empties[s] = (toe, foot, ankle)
        last_t, last_f = None, None
        for t, loc, Rt, Rf in feet[s]:
            qt = _quat_near(Rt.to_quaternion(), last_t)
            qf = _quat_near((Rt.transposed() @ Rf).to_quaternion(), last_f)
            last_t, last_f = qt, qf
            toe.location = loc
            toe.rotation_quaternion = qt
            foot.rotation_quaternion = qf
            toe.keyframe_insert("location", frame=t + 1)
            toe.keyframe_insert("rotation_quaternion", frame=t + 1)
            foot.keyframe_insert("rotation_quaternion", frame=t + 1)
    last_q = {}
    body_frames = []
    for frac, marker in body_rows:
        t = int(round(frac * T))
        body_frames.append(t + 1)
        sc.frame_set(t + 1)
        bpy.context.view_layer.update()
        w = ease(t / T)
        P = {n: idle[n][0].copy() for n in rig.names}
        lean = Matrix.Rotation(math.radians(CROUCH_LEAN_DEG) * w, 3, lat)
        if (lean @ Vector((0.0, 0.0, 1.0))).dot(fwd) < 0.0:
            lean = Matrix.Rotation(-math.radians(CROUCH_LEAN_DEG) * w, 3, lat)
        for n in rig.names:     # everything above the Spine leans with it; the neck and head give it back
            if n in ("Hips",) or n.startswith("Left") and ("Leg" in n or "Foot" in n or "Toe" in n) or n.startswith("Right") and ("Leg" in n or "Foot" in n or "Toe" in n):
                continue
            if n in ("Neck", "Head") or n.startswith("HeadTop"):
                continue
            P[n] = (lean @ P[n]).normalized()
        share = CROUCH_CONE_SHARE.get(marker, 0.0) if cone else 0.0
        if share > 0.0:          # the arms away from the body, the shoulders turned up with them (each subtree turned about its own joint)
            axis = lean @ fwd
            for side in ("Left", "Right"):
                out = (idle[side + "Arm"][1] - hips_idle).dot(lat)
                d = idle[side + "Hand"][1] - idle[side + "Arm"][1]
                sgn = 1.0
                for g in (1.0, -1.0):
                    if (Matrix.Rotation(math.radians(10.0) * g, 3, axis) @ d).dot(lat) * out > d.dot(lat) * out:
                        sgn = g
                for root, deg in ((side + "Shoulder", CROUCH_SHOULDER_DEG), (side + "Arm", CROUCH_ARM_OUT_DEG)):
                    Rz = Matrix.Rotation(math.radians(deg) * share * sgn, 3, axis)
                    for n in rig.names:
                        if n == root or _is_below(rig, n, root):
                            P[n] = (Rz @ P[n]).normalized()
        hips_arm = hips_at(t)
        for side in ("Left", "Right"):
            toe, foot, ankle = empties[side[0]]
            target = ankle.matrix_world.translation
            hip_j = hips_arm + P["Hips"] @ off_hip[side]
            knee, end = _two_bone(hip_j, target, thigh[side], shin[side], hip_j + fwd * 1.0 + up * 0.2)
            P[side + "UpLeg"] = _aim_bone(P[side + "UpLeg"], hip_j, knee)
            P[side + "Leg"] = _aim_bone(P[side + "Leg"], knee, end)
            P[side + "Foot"] = foot.matrix_world.to_3x3().normalized()
            P[side + "ToeBase"] = toe.matrix_world.to_3x3().normalized()
        for n in rig.names:
            pb = arm.pose.bones[PREFIX + n]
            pb.rotation_mode = 'QUATERNION'
            if is_finger(n) or t == 0:
                q = idle_q[pb.name].copy()
            else:
                p = rig.parent[n]
                rp = rig.R[p] if p else Matrix.Identity(3)
                pp = P[p] if p else Matrix.Identity(3)
                q = (rig.R[n].transposed() @ rp @ pp.transposed() @ P[n]).to_quaternion()
            q = _quat_near(q, last_q.get(n))
            last_q[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t + 1)
        bpy.context.view_layer.update()
        h = arm.pose.bones[PREFIX + "Hips"]
        m = h.matrix.copy()
        m.translation = hips_arm
        h.matrix = m
        h.keyframe_insert("location", frame=t + 1)
    for side in ("Left", "Right"):
        toe, foot, ankle = empties[side[0]]
        ik = arm.pose.bones[PREFIX + side + "Leg"].constraints.new('IK')
        ik.name = "IK foot"
        ik.target = ankle
        ik.chain_count = 2
        ik.use_tail = True
        ik.use_stretch = False
        ik.iterations = 500
        for bone, src in ((side + "Foot", foot), (side + "ToeBase", toe)):
            c = arm.pose.bones[PREFIX + bone].constraints.new('COPY_ROTATION')
            c.name = "IK foot rotation"
            c.target = src
            c.target_space = 'WORLD'
            c.owner_space = 'WORLD'
            c.mix_mode = 'REPLACE'
    sc.timeline_markers.clear()
    for (frac, marker), frame in zip(body_rows, body_frames):
        sc.timeline_markers.new(marker, frame=frame)
    sc.frame_start, sc.frame_end = 1, T + 1
    coat = bpy.data.objects.get(COAT_OBJECT)
    if coat is None or coat.data.shape_keys is None:
        print(f"[tripo_pose_lab] WARNING: no {COAT_OBJECT} with shape keys: the coat gets no per-pose keys")
    else:
        inner = body_frames[1:-1]
        for i, frame in enumerate(inner):
            kb = coat.shape_key_add(name=f"CrouchFix_f{frame:02d}", from_mix=False)
            for f2, v in ((body_frames[i], 0.0), (frame, 1.0), (body_frames[i + 2], 0.0)):
                kb.value = v
                kb.keyframe_insert("value", frame=f2)
        blocks = coat.data.shape_keys.key_blocks
        if CROUCH_ENDS[1] not in blocks:
            coat.shape_key_add(name=CROUCH_ENDS[1], from_mix=False)     # the held crouch's own key (the game holds it while crouched), empty to start
        for name, (v_first, v_last) in zip(CROUCH_ENDS, ((1.0, 0.0), (0.0, 1.0))):
            if name not in blocks:
                print(f"[tripo_pose_lab] WARNING: the coat has no {name}")
                continue
            for frame, v in ((body_frames[0], v_first), (body_frames[-1], v_last)):
                blocks[name].value = v
                blocks[name].keyframe_insert("value", frame=frame)
        coat.active_shape_key_index = list(blocks.keys()).index(CROUCH_ENDS[1])
        if cone:
            names = [f"CrouchFix_f{f:02d}" for f in inner] + [CROUCH_ENDS[1]]
            shares = [CROUCH_CONE_SHARE[m] for _f, m in body_rows[1:]]
            _crouch_cone_keys(arm, coat, list(zip(body_frames[1:], names, shares)), fwd, body_frames[0])
    arm["lab_pose"] = "crouch"
    arm["lab_props"] = json.dumps([])
    arm["lab_run_start"] = json.dumps({"frames": T, "to_frame": T, "side": "Right", "planted": {"flat": r1}, "pinned_until": T + 1,
                                       "knee": list(K), "left_ball": list(bL_end), "right_ball": list(bR_end)})
    sc.frame_set(T + 1)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.data.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    embed_coat_follow()
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: the {arm['lab_figure']} crouch, frames 1-{T + 1}: hips down {hips_idle.z - hips_end.z:.3f} m to z {hips_end.z:.3f}, "
          f"right knee at ({K.x:+.3f} {K.y:+.3f} {K.z:.3f}), left ball ahead {(bL_end - bL).dot(fwd):.3f} m, right ball back {(bR - bR_end).dot(fwd):.3f} m")


def clip_out(blend, out_json, keys_dir):
    """A FOOTED timeline (the run's start) read back as a CLIP for the game: every frame, the pose as Blender EVALUATES it (the IK legs and the copied foot
    rotations included, which `sequence`'s stops would lose), each bone's Godot local rotation, the Hips in place (armature space), the forward travel (the
    armature object's location, glTF space), the coat's animated keys' values; and each coat key the timeline animates, as glb_add_morph.py's JSON in `keys_dir`."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    sc = bpy.context.scene
    arm, rig = load_rig_from_blend()
    info = json.loads(arm.get("lab_run_start", "{}"))
    coat = bpy.data.objects.get(COAT_OBJECT)
    morphs = _animated_keys(coat) if coat is not None else []
    frames = []
    for f in range(sc.frame_start, sc.frame_end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        P, G, local = {}, {}, {}
        for n in rig.names:
            P[n] = arm.pose.bones[PREFIX + n].matrix.to_3x3().normalized()
            G[n] = to_g(P[n]) @ rig.BB[n].transposed()
            p = rig.parent[n]
            local[n] = ((G[p].transposed() if p else Matrix.Identity(3)) @ G[n]).to_quaternion()
        frames.append({"frame": f, "bones": {n: xyzw(local[n]) for n in rig.names}, "hips_pos": list(CM @ arm.pose.bones[PREFIX + "Hips"].matrix.translation),
                       "travel": list(CM @ arm.location), "morphs": {game_key(k): coat.data.shape_keys.key_blocks[k].value for k in morphs}})
    out = {"format": "infiltraitor-clip", "v": 1, "figure": arm["lab_figure"], "name": arm.get("lab_pose", ""), "fps": sc.render.fps,
           "run_frame": info.get("to_frame"), "frames": frames, "morphs": [game_key(k) for k in morphs]}
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w") as fh:
        json.dump(out, fh, indent=1)
    os.makedirs(keys_dir, exist_ok=True)
    basis = [list(v.co) for v in coat.data.shape_keys.key_blocks[0].data] if coat is not None else []
    for k in morphs:
        with open(os.path.join(keys_dir, game_key(k) + ".json"), "w") as fh:
            json.dump({"name": game_key(k), "basis": basis, "key": [list(v.co) for v in coat.data.shape_keys.key_blocks[k].data]}, fh)
    print(f"[tripo_pose_lab] wrote {out_json}: {len(frames)} frames at {sc.render.fps} fps, morphs {morphs}, travel {frames[-1]['travel']}")


def run_start_check(blend):
    """The feet of a run-start timeline, frame by frame, as Blender evaluates them (IK included): how far the planted left ball moves, how far each shin
    falls short of its target, and the lowest point of each foot (nothing may go under the floor)."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    sc = bpy.context.scene
    arm = find_arm()
    info = json.loads(arm.get("lab_run_start", "{}"))
    pinned_side = info.get("side", "Left")      # a stop names its planted foot, pinned from its flat stance to the end; the start pins the left until it rolls off
    if "side" in info:
        pinned_from, pinned_until = info["planted"]["flat"] + 1, info.get("pinned_until", sc.frame_end)
    else:
        pinned_from, pinned_until = 1, info.get("left", {}).get("ball", 0) + 1
    ball0 = None
    worst_slide = worst_reach = 0.0
    lowest = 1e9
    for f in range(sc.frame_start, sc.frame_end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        M = arm.matrix_world
        row = [f"f{f:02d}"]
        for side in ("Left", "Right"):
            s = side[0]
            ball = M @ arm.pose.bones[PREFIX + side + "ToeBase"].head
            tip = M @ arm.pose.bones[PREFIX + side + "ToeBase"].tail
            ankle = M @ arm.pose.bones[PREFIX + side + "Leg"].tail
            target = bpy.data.objects[IK_NAME % (s, "ankle")].matrix_world.translation
            reach = (ankle - target).length
            worst_reach = max(worst_reach, reach)
            lowest = min(lowest, ball.z, tip.z, ankle.z)
            row.append(f"{s}: ball ({ball.x:+.3f} {ball.y:+.3f} {ball.z:.3f}) tip z {tip.z:.3f} ankle z {ankle.z:.3f} reach {reach * 1000:.1f} mm")
            if side == pinned_side and pinned_from <= f <= pinned_until:
                ball0 = ball0 or ball.copy()
                worst_slide = max(worst_slide, (ball - ball0).length)
        hips = M @ arm.pose.bones[PREFIX + "Hips"].head
        row.append(f"hips y {hips.y:+.3f} z {hips.z:.3f}")
        print("[tripo_pose_lab] " + " | ".join(row))
    print(f"[tripo_pose_lab] CHECK {pinned_side.lower()} ball pinned frames {pinned_from}-{pinned_until}: moved at most {worst_slide * 1000:.1f} mm; shins short of their targets by at most "
          f"{worst_reach * 1000:.1f} mm; lowest foot point z {lowest:.4f} (the idle's balls stand at about 0.023)")


def rebase_idle(blend, idle_json, out_blend, frames):
    """THE IDLE REFERENCE OF A TIMELINE (MOVEMENT 2026-11-12: frame 145 of the idle is the one whose coat lies farthest from the legs): the body keys of a timeline that ARE the idle
    (`frames`, e.g. 1 for the draw) are put to the idle pose of `idle_json` (`tripo_pose_dump --idle-frame=N`), every bone and the Hips' place; the other keys are the Director's and
    stay. Written to ANOTHER file (his .blend is never overwritten), and `lab_base` (what the unkeyed bones show) follows. Key VALUES are replaced on the existing f-curves, so
    the timing, the handles' types and the coat / prop keys are not touched."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    arm, rig = load_rig_from_blend()
    idle = read_json(idle_json)
    base = {n: quat_xyzw(q) for n, q in idle["bones"].items()}
    ad = arm.animation_data
    action, slot = (ad.action, getattr(ad, "action_slot", None)) if ad else (None, None)
    if action is None:
        fail(f"{blend} has no armature action to rebase")
    ad.action = None                      # no animation re-reads over what is set next
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object.mode != 'POSE':
        bpy.ops.object.mode_set(mode='POSE')
    rig.apply(base)
    bpy.context.view_layer.update()
    h = arm.pose.bones[PREFIX + "Hips"]
    m = h.matrix.copy()
    m.translation = CMT @ Vector(idle["hips_pos"])
    h.matrix = m
    bpy.context.view_layer.update()
    rot = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    hips_loc = h.location.copy()
    ad.action = action
    if slot is not None:
        ad.action_slot = slot
    curves = [fc for l in action.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves] if getattr(action, "layers", None) else list(action.fcurves)
    changed = 0
    for fc in curves:
        dp = fc.data_path
        if dp.startswith('pose.bones["') and dp.endswith('"].rotation_quaternion'):
            value = rot[dp[len('pose.bones["'):-len('"].rotation_quaternion')]][fc.array_index]
        elif dp == f'pose.bones["{PREFIX}Hips"].location':
            value = hips_loc[fc.array_index]
        else:
            continue
        for frame in frames:
            if any(abs(k.co[0] - frame) < 1e-3 for k in fc.keyframe_points):
                fc.keyframe_points.insert(frame, value, options={'REPLACE'})
                changed += 1
        fc.update()
    arm["lab_base"] = json.dumps(idle["bones"])
    arm["lab_idle_frame"] = idle_json
    bpy.context.scene.frame_set(frames[0])
    embed_coat_follow()   ## the coat's per-frame keys follow the timeline (coat_key_follow.py)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print(f"[tripo_pose_lab] wrote {out_blend}: {changed} key values of frames {frames} are the idle of {os.path.basename(idle_json)}")


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


def _render_scene(scn, size):
    """EEVEE, a grey world, one sun, one camera (returned)"""
    scn.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items.keys() else 'BLENDER_EEVEE_NEXT'
    scn.render.resolution_x, scn.render.resolution_y = size, size
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
    return cam


def _aim_camera(cam, target, az, el, dist):
    a = math.radians(az)
    e = math.radians(el)
    cam.location = target + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()


def render(blend, out_png, frame=None):
    bpy.ops.wm.open_mainfile(filepath=blend)
    scn = bpy.context.scene
    if frame is not None:
        scn.frame_set(frame)
    cam = _render_scene(scn, 900)
    cam.data.lens = 85
    target = Vector((0.0, -0.12, 0.5))
    base, ext = os.path.splitext(out_png)
    for name, az, el, dist in (("front34", 35.0, 12.0, 3.0), ("side", 90.0, 8.0, 3.0)):
        _aim_camera(cam, target, az, el, dist)
        scn.render.filepath = f"{base}_{name}{ext}"
        bpy.ops.render.render(write_still=True)
        print(f"[tripo_pose_lab] rendered {scn.render.filepath}")


def render_frames(blend, out_prefix, frames):
    """Chosen frames of a timeline from the front three-quarters and the side, one open of the file: <out_prefix>_f<frame>_<view>.png."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    scn = bpy.context.scene
    cam = _render_scene(scn, 700)
    cam.data.lens = 85
    target = Vector((0.0, -0.1, 0.56))
    for f in frames:
        scn.frame_set(f)
        for name, az, el, dist in (("front34", 35.0, 12.0, 2.3), ("side", 90.0, 8.0, 2.3)):
            _aim_camera(cam, target, az, el, dist)
            scn.render.filepath = f"{out_prefix}_f{f:02d}_{name}.png"
            bpy.ops.render.render(write_still=True)
    print(f"[tripo_pose_lab] rendered frames {frames} -> {out_prefix}_f*_<view>.png")


def strip(blend, out_prefix, view):
    """Every frame of a timeline's range from ONE still camera (side or front 3/4), aimed at the middle of the hips' path: a planted foot must not move on
    screen. Writes <out_prefix>_f<frame>.png; `pose_lab.py strip` lays them out."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    scn = bpy.context.scene
    arm = find_arm()
    frames = list(range(scn.frame_start, scn.frame_end + 1))
    pts = []
    for f in frames:
        scn.frame_set(f)
        bpy.context.view_layer.update()
        pts.append(arm.matrix_world @ arm.pose.bones[PREFIX + "Hips"].head)
    mid = sum(pts, Vector()) / len(pts)
    cam = _render_scene(scn, 640)
    cam.data.lens = 70
    az, el = {"side": (90.0, 6.0), "front34": (35.0, 10.0)}[view]
    _aim_camera(cam, Vector((mid.x, mid.y, 0.48)), az, el, 3.0)
    for f in frames:
        scn.frame_set(f)
        scn.render.filepath = f"{out_prefix}_f{f:02d}.png"
        bpy.ops.render.render(write_still=True)
    print(f"[tripo_pose_lab] strip: {len(frames)} frames {frames[0]}-{frames[-1]} ({view}) -> {out_prefix}_f*.png")


def main():
    a = args_after_dashes()
    if not a:
        fail("usage: -- build|extract|render ...")
    mode = a[0]
    if mode == "build":
        figure, pose_id, dump_dir, out = a[1:5]
        glb = os.path.join(ROOT, mp.agent(figure, "game", "AGENT_%s_LIGHT.glb" % figure.upper()))
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
    elif mode == "draw_long_new":
        draw_long_new(a[1], a[2], a[3], a[4] if len(a) > 4 else "shotgun")
    elif mode == "render_frames":
        render_frames(a[1], a[2], [int(x) for x in a[3].split(",")])
    elif mode == "run_start_new":
        run_start_new(a[1], a[2], a[3], a[4] if len(a) > 4 else "run", a[5] if len(a) > 5 else None)
    elif mode == "draw_crouch_new":
        draw_crouch_new(a[1], a[2], a[3])
    elif mode == "crouch_new":
        crouch_new(a[1], a[2], len(a) > 3 and a[3] == "cone")
    elif mode == "walk_stop_new":
        walk_stop_new(a[1], a[2], a[3])
    elif mode == "run_stop_new":
        run_stop_new(a[1], a[2], a[3], a[4])
    elif mode == "rebase_idle":
        rebase_idle(a[1], a[2], a[3], [int(x) for x in a[4].split(",")])
    elif mode == "embed_follow":
        bpy.ops.wm.open_mainfile(filepath=a[1])
        embed_coat_follow()
        bpy.ops.wm.save_as_mainfile(filepath=a[2])
    elif mode == "sequence":
        sequence(a[1], a[2], a[3], a[4])
    elif mode == "render":
        render(a[1], a[2], int(a[3]) if len(a) > 3 else None)
    elif mode == "strip":
        strip(a[1], a[2], a[3] if len(a) > 3 else "side")
    elif mode == "clip_out":
        clip_out(a[1], a[2], a[3])
    elif mode == "run_start_check":
        run_start_check(a[1])
    else:
        fail(f"unknown mode {mode}")


if __name__ == "__main__":
    main()
