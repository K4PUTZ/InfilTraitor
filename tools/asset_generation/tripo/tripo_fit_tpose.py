# tripo_fit_tpose.py — the figure AND the coat in a T-POSE, as a WORKING state for the hand fit (ACTOR D96, 2026-11-02, Director: "pegar o modelo e o casaco e mudar pra T-pose, de forma que a gente possa arrumar a axila com mais facilidade").
# Reads a `COAT_FIT_<FIG>.blend` (the figure in the rig's rest pose, A-like, the coat with its Basis / Fit keys) and writes `COAT_FIT_<FIG>_T.blend`: each Arm bone turned about its shoulder until the Arm -> ForeArm line lies along +/-x
# (the rest of each arm follows rigidly), every skinned mesh BAKED in that pose (the evaluated mesh, same vertices, same weights, the coat with its Fit key included), and the pose applied as the armature's REST: the T file is a plain figure in T, whose
# weights and skeleton are the original's. NOTHING GOES TO THE GAME FROM A T FILE: the game's rest pose stays the original (the bank's clips are rotations relative to it); `tripo_fit_from_tpose.py` brings an edited T coat back to the original rest by the EXACT
# inverse of each vertex's blended bone matrix, and the file keeps the matrices (the armature's custom property `a_to_t`, per bone, the T pose in the A rest's armature space) for that.
# Env: TP_IN (the A .blend), TP_OUT (the T .blend), TP_RENDER (optional prefix: front and side renders).   Usage: blender -b -P tripo_fit_tpose.py
import json, math, os
import numpy as np
import bpy
from mathutils import Matrix, Vector

TAG = "tripo_fit_tpose"
IN, OUT = os.environ["TP_IN"], os.environ["TP_OUT"]
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
arm.data.pose_position = 'POSE'
bpy.context.view_layer.objects.active = arm
for o in bpy.data.objects:
    o.select_set(False)
arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
for pb_ in arm.pose.bones:                                                 # EVERY bone to its rest (the select-all clear skips hidden bones: the male's file held a leftover pose, measured 2026-11-02)
    pb_.rotation_mode = 'QUATERNION'; pb_.rotation_quaternion = (1, 0, 0, 0); pb_.location = (0, 0, 0); pb_.scale = (1, 1, 1)
bpy.context.view_layer.update()
mwa = arm.matrix_world
rest = {b.name: Matrix(b.matrix_local) for b in arm.data.bones}          # the A rest, in armature space
for side, sx in (("Left", 1.0), ("Right", -1.0)):
    a = arm.data.bones[f"mixamorig:{side}Arm"]; f = arm.data.bones[f"mixamorig:{side}ForeArm"]
    d = (f.head_local - a.head_local).normalized()
    # the arm's direction in the armature's space; only its HORIZONTAL-plane tilt is wanted, the world's +x is the target
    target = (mwa.to_3x3().inverted() @ Vector((sx * 1.0, 0.0, 0.0))).normalized()   # the figure faces -y: its left arm runs to +x in the WORLD; the bones are in the armature's own space (the male's armature is not the identity)
    q = d.rotation_difference(target)
    h = a.head_local
    M = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h)
    pb = arm.pose.bones[f"mixamorig:{side}Arm"]
    pb.matrix = M @ rest[a.name]
    bpy.context.view_layer.update()
    print(f"[{TAG}] {side} arm turned {math.degrees(q.angle):.1f} deg about the shoulder onto {'+' if sx > 0 else '-'}x")
bpy.ops.object.mode_set(mode='OBJECT')
dg = bpy.context.evaluated_depsgraph_get()
posed = {b.name: Matrix(arm.pose.bones[b.name].matrix) for b in arm.data.bones}   # the T pose, per bone, in armature space
a_to_t = {n: [list(r) for r in (posed[n] @ rest[n].inverted())] for n in rest}  # what takes a point of the A rest to the T pose, per bone
# bake every skinned mesh in the pose (shape keys included): same topology, same vertex groups
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    if not any(m.type == 'ARMATURE' for m in o.modifiers):
        continue
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    assert len(me.vertices) == len(o.data.vertices), o.name
    me.name = o.data.name
    old = o.data
    o.shape_key_clear() if o.data.shape_keys else None
    o.data = me
    bpy.data.meshes.remove(old)
    for m in o.modifiers:
        if m.type == 'ARMATURE':
            m.object = arm
# the pose becomes the rest
bpy.context.view_layer.objects.active = arm
for o in bpy.data.objects:
    o.select_set(False)
arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.select_all(action='SELECT'); bpy.ops.pose.armature_apply(); bpy.ops.object.mode_set(mode='OBJECT')
arm["a_to_t"] = json.dumps(a_to_t)
arm["a_rest"] = json.dumps({n: [list(r) for r in m] for n, m in rest.items()})
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
pre = os.environ.get("TP_RENDER", "")
if pre:
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
    sc.render.resolution_x, sc.render.resolution_y = 900, 900; sc.view_settings.view_transform = 'Standard'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (0.9, 0.4, 0.05, 1) if o.name.startswith("Outfit_Coat") else (0.55, 0.6, 0.7, 1); o.hide_render = o.name in ("Icosphere",)
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.5; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector((0, 0, 0.62))
    for tag, az in (("front", 0), ("back", 180), ("three", 35)):
        a_ = math.radians(az); d = Vector((math.sin(a_), -math.cos(a_), 0.1)).normalized()
        co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{pre}_{tag}.png"; bpy.ops.render.render(write_still=True)
print(f"[{TAG}] wrote {OUT}")
