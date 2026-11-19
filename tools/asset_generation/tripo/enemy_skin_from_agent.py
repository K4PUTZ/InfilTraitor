"""Skin an unrigged Tripo enemy on the Agent's own skeleton (ENEMIES_MASTER_PLAN §12.12).

The enemies are drawn by editing the Agent's own Tripo inputs, so their bodies match his. When a generation comes without
Tripo's auto-rig, this script gives it the Agent's 65-joint Mixamo armature and copies the skin weights from the Agent's
meshes to the nearest point of the enemy's surface. The source GLB stays untouched (ACTOR D86).

    Blender -b -P enemy_skin_from_agent.py -- <enemy.glb> <agent_base.glb> <out.glb> [out.blend]
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
enemy_path, agent_path, out_glb = args[0], args[1], args[2]
out_blend = args[3] if len(args) > 3 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)


def import_new(path: str) -> list:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o not in before]


agent_objs = import_new(agent_path)
armature = next(o for o in agent_objs if o.type == "ARMATURE")
armature.data.pose_position = "REST"
agent_meshes = [o for o in agent_objs if o.type == "MESH" and o.parent == armature]
for o in agent_objs:
    if o.type == "MESH" and o.parent != armature:
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

# One skinned source surface: the Agent's pieces joined.
bpy.ops.object.select_all(action="DESELECT")
for o in agent_meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = agent_meshes[0]
bpy.ops.object.join()
source = bpy.context.view_layer.objects.active
source.name = "AgentSkinSource"

enemy = next(o for o in import_new(enemy_path) if o.type == "MESH")
enemy.name = "Enemy"
bpy.context.view_layer.update()
world = enemy.matrix_world.copy()
enemy.parent = None
enemy.matrix_world = world
bpy.ops.object.select_all(action="DESELECT")
enemy.select_set(True)
bpy.context.view_layer.objects.active = enemy
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

for vg in source.vertex_groups:
    enemy.vertex_groups.new(name=vg.name)
dt = enemy.modifiers.new("weights", "DATA_TRANSFER")
dt.object = source
dt.use_object_transform = True
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.modifier_apply(modifier=dt.name)

# Four influences per vertex, normalised (the game's skinning, ACTOR D85).
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)

bpy.data.objects.remove(source)
enemy.parent = armature
enemy.matrix_parent_inverse = armature.matrix_world.inverted()
mod = enemy.modifiers.new("Armature", "ARMATURE")
mod.object = armature
armature.data.pose_position = "POSE"

unweighted = sum(1 for v in enemy.data.vertices if not v.groups)
print(f"[enemy_skin] vertices {len(enemy.data.vertices)} unweighted {unweighted}")

if out_blend:
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_animations=False)
print("[enemy_skin] wrote", out_glb)
