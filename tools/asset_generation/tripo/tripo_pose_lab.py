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
PROP_GLB = {"pistol": os.path.join(ROOT, "ASSETS", "props", "pistol_quaternius", "pistol.glb")}
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
    elif mode == "render":
        render(a[1], a[2])
    else:
        fail(f"unknown mode {mode}")


if __name__ == "__main__":
    main()
