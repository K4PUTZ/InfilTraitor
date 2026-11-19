"""The game version of a skinned enemy (ENEMIES_MASTER_PLAN §12.13): decimated to ~5 k triangles, coloured by REGION.

A generation without its own textures (the first guard, 2026-11-19) takes one palette colour per body region, each region a
material of its own (`ActorMesh3D._apply_board_light` reads a material's albedo). The region of a face is the bone that weighs
most on it: head = skin (its top and back = hair), torso and arms = shirt, hips and legs = trousers, feet = shoes.

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
for key in ("skin", "hair", "shirt", "trousers", "shoes"):
    m = bpy.data.materials.new("Enemy_" + key)
    h = palette[key].lstrip("#")
    m.diffuse_color = (*(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)), 1.0)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = m.diffuse_color
    mesh.data.materials.append(m)
    mats[key] = len(mesh.data.materials) - 1
mesh.data.materials[:]  # keep order
top = max(v.co.z for v in mesh.data.vertices)
COLLAR_R = 0.052   # metres on the 1 m figure: farther from the neck's axis than this is collar, not skin
_neck = armature.data.bones.get("mixamorig:Neck")
_n0 = armature.matrix_world @ _neck.head_local
_n1 = armature.matrix_world @ _neck.tail_local
chin = _n1.z


DEBUG = False
_dbg: list = []


def _radial(c) -> float:
    axis = (_n1 - _n0).normalized()
    d = c - _n0
    return (d - axis * d.dot(axis)).length
for p in mesh.data.polygons:
    weight: dict = {}
    for vi in p.vertices:
        for g in mesh.data.vertices[vi].groups:
            weight[names[g.group]] = weight.get(names[g.group], 0.0) + g.weight
    r = region(max(weight, key=weight.get)) if weight else "shirt"
    if r == "head":
        c = p.center
        # hair: the crown, and the back of the head above the ears (the figure faces -Y in Blender)
        if c.z < top - 0.15 or (c.z < chin and (_radial(c) > COLLAR_R or p.normal.y > 0.1)):
            r = "shirt"   # the collar weighs on the neck: it stands out from the neck, and it closes the back (the front stays open)
        else:
            r = "hair" if (c.z > top - 0.035 or (c.z > top - 0.09 and p.normal.y > 0.4)) else "skin"
    p.material_index = mats[r]
    if DEBUG and region(max(weight, key=weight.get) if weight else "x")=="head": _dbg.append((round(p.center.z,3), round(_radial(p.center),3), r))
for i in range(len(mesh.data.materials) - 1, -1, -1):
    if mesh.data.materials[i].name.startswith("Enemy_"):
        continue
    mesh.data.materials.pop(index=i)
    for p in mesh.data.polygons:
        if p.material_index > i:
            p.material_index -= 1

if DEBUG:
    import collections
    print("[dbg] top", round(top,3), "chin", round(chin,3), "n0", tuple(round(x,3) for x in _n0))
    for z0 in [x/100 for x in range(80,100)]:
        rows=[d for d in _dbg if z0<=d[0]<z0+0.01]
        if rows: print("[dbg]", z0, len(rows), collections.Counter(r for _,_,r in rows), round(min(d[1] for d in rows),3), round(max(d[1] for d in rows),3))
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
