"""The game version of a skinned enemy (ENEMIES_MASTER_PLAN §12.13): decimated to ~5 k triangles, coloured by REGION.

A generation without its own textures (the first guard, 2026-11-19) takes one palette colour per body region, each region a
material of its own (`ActorMesh3D._apply_board_light` reads a material's albedo). The region of a face is the bone that weighs
most on it: torso and arms = shirt, hips and legs = trousers, feet = shoes, hands = hands (skin's colour); Tripo's head piece
is skin (its top and back = hair), whole, down to the neck's base inside the collar.

    Blender -b -P enemy_light.py -- <rigged.glb> <out.glb> <palette.json> [target_tris]

palette.json: {"skin": "#8d5a3b", "hair": "#161616", "shirt": "#3b6ea8", "trousers": "#1e2a4a", "shoes": "#141414"}
"""
import json
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, out, palette_path = args[0], args[1], args[2]
target = int(args[3]) if len(args) > 3 else 5000
palette = json.load(open(palette_path))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
armature.data.pose_position = "REST"

# The HEAD PIECE (2026-11-20, the Director): Tripo models the head and neck as a loose piece of their own, the eyes as two more
# inside it. It is the head, whole, down to the neck's base inside the collar: its faces are skin or hair and nothing else, the
# body's never are (the hands take `hands`), so a head and a body are told apart by material and their maps swap apart. Marked
# as a vertex group before the decimation, which collapses edges within a piece and never joins two.
def _head_piece() -> list:
    import bmesh as _bm
    b = _bm.new()
    b.from_mesh(mesh.data)
    b.verts.ensure_lookup_table()
    comp = [-1] * len(b.verts)
    pieces = []
    for v0 in b.verts:
        if comp[v0.index] >= 0:
            continue
        stack, members = [v0], []
        comp[v0.index] = len(pieces)
        while stack:
            a = stack.pop()
            members.append(a.index)
            for e in a.link_edges:
                o = e.other_vert(a)
                if comp[o.index] < 0:
                    comp[o.index] = len(pieces)
                    stack.append(o)
        pieces.append(members)
    co = [mesh.matrix_world @ v.co for v in b.verts]
    head = max(pieces, key=lambda m: max(co[i].z for i in m))
    lo = [min(co[i][k] for i in head) for k in range(3)]
    hi = [max(co[i][k] for i in head) for k in range(3)]
    inside = [m for m in pieces if m is not head and all(lo[k] <= co[i][k] <= hi[k] for i in m for k in range(3))
              and min(co[i].z for i in m) > (lo[2] + hi[2]) / 2.0]   # the eyes: wholly within the head's upper half
    b.free()
    return head + [i for m in inside for i in m]


_hp = _head_piece()
_hg = mesh.vertex_groups.new(name="_head_piece")
_hg.add(_hp, 1.0, "REPLACE")
print(f"[enemy_light] head piece: {len(_hp)} vertices")

tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
bpy.context.view_layer.objects.active = mesh
dec = mesh.modifiers.new("light", "DECIMATE")
dec.ratio = min(1.0, target / float(tris))
mesh.modifiers.move(mesh.modifiers.find("light"), 0)
bpy.ops.object.modifier_apply(modifier="light")


def region(bone: str) -> str:
    b = bone.split(":")[-1]
    if b.startswith(("Head", "Neck")):
        return "head"
    if "Foot" in b or "Toe" in b:
        return "shoes"
    if b.startswith(("Hips", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg")):
        return "trousers"
    if "Hand" in b:
        return "skin"
    return "shirt"


names = {vg.index: vg.name for vg in mesh.vertex_groups}
mats = {}
for key in ("skin", "hair", "shirt", "trousers", "shoes", "hands"):
    m = bpy.data.materials.new("Enemy_" + key)
    h = palette["skin" if key == "hands" else key].lstrip("#")
    m.diffuse_color = (*(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)), 1.0)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = m.diffuse_color
    mesh.data.materials.append(m)
    mats[key] = len(mesh.data.materials) - 1
mesh.data.materials[:]  # keep order
top = max(v.co.z for v in mesh.data.vertices)
_hgi = mesh.vertex_groups["_head_piece"].index
for p in mesh.data.polygons:
    weight: dict = {}
    in_head = 0.0
    for vi in p.vertices:
        for g in mesh.data.vertices[vi].groups:
            if g.group == _hgi:
                in_head += g.weight
                continue
            weight[names[g.group]] = weight.get(names[g.group], 0.0) + g.weight
    if in_head / len(p.vertices) > 0.5:
        c = p.center
        # hair: the crown, and the back of the head above the ears (the figure faces -Y in Blender); the neck below is skin
        r = "hair" if (c.z > top - 0.035 or (c.z > top - 0.09 and p.normal.y > 0.4)) else "skin"
    else:
        r = region(max(weight, key=weight.get)) if weight else "shirt"
        r = {"head": "shirt", "skin": "hands"}.get(r, r)   # what the neck bone weighs on outside the head piece is the collar
    p.material_index = mats[r]
for i in range(len(mesh.data.materials) - 1, -1, -1):
    if mesh.data.materials[i].name.startswith("Enemy_"):
        continue
    mesh.data.materials.pop(index=i)
    for p in mesh.data.polygons:
        if p.material_index > i:
            p.material_index -= 1

mesh.vertex_groups.remove(mesh.vertex_groups["_head_piece"])   # the reference went stale with the decimation
armature.data.pose_position = "POSE"
# One keyed rest frame: Godot gives a GLB an AnimationPlayer only when it carries a clip, and ActorMesh3D needs that player.
armature.animation_data_create()
armature.animation_data.action = bpy.data.actions.new("rest")
for pb in armature.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.location = (0.0, 0.0, 0.0)
    pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    pb.scale = (1.0, 1.0, 1.0)
    for path in ("location", "rotation_quaternion", "scale"):
        pb.keyframe_insert(data_path=path, frame=1)
print(f"[enemy_light] {tris} -> {sum(len(p.vertices) - 2 for p in mesh.data.polygons)} triangles")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True)
