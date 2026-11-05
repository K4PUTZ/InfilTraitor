# tripo_pose_fix_back.py — an edit made on a posed frame goes back to the rest mesh, so it holds on every frame of every clip (Director, 2026-11-04: "Se eu editar uma pose do meio da animação ... você consegue extrapolar os outros frames?").
# The fix file holds the figure baked on one frame of a bank clip, centred on the hips (scene props run_fix_clip, run_fix_frame, run_fix_off), vertex order kept. With M_v the vertex's linear blend skin on that frame, p_rest = M_v^-1 p_edited
# (the same inverse as tripo_fit_from_tpose.py). Only vertices that moved more than PF_EPS in the fix file change; a piece with the `Fit` key takes it in Basis and Fit alike. It then re-evaluates the frame and prints the error against the edit.
# PF_KEY=<name>: the edit is not written into the rest but into a corrective shape key of that name, left at value 0 (Director: "esse ajuste só pode valer pra pose extrema. Na pose calma tem que ficar igual").
# Env: PF_A (the A .blend), PF_BASE (the same A the fix was baked from, default PF_A), PF_FIX, PF_OUT, PF_EPS (default 1e-5 m), PF_FIG (female | male).
# Usage (from the repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_pose_fix_back.py
import os
import numpy as np
import bpy
from mathutils import Vector

TAG = "tripo_pose_fix_back"
EPS = float(os.environ.get("PF_EPS", "1e-5"))
KEY = os.environ.get("PF_KEY", "")
PFX = "mixamorig:"

# the edit
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["PF_FIX"]))
sc = bpy.context.scene
clip, frame, off = sc["run_fix_clip"], int(sc["run_fix_frame"]), np.array(sc["run_fix_off"])
edited = {o.name: np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices]) - off for o in bpy.data.objects if o.type == 'MESH'}


def posed(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    mw = o.matrix_world
    r = np.array([(mw @ v.co)[:] for v in m.vertices])
    e.to_mesh_clear()
    return r


def play(arm, hip):
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/ANIMATIONS/bank/{os.environ['PF_FIG']}/{clip}.glb"))
    act = [a for a in bpy.data.actions if a not in before_a][0]
    for o in [o for o in bpy.data.objects if o not in before_o]:
        bpy.data.objects.remove(o)
    curves = [fc for la in act.layers for s in la.strips for cb in s.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
    for fc in curves:
        if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
            for k in fc.keyframe_points:
                k.co.y *= hip; k.handle_left.y *= hip; k.handle_right.y *= hip
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    arm.data.pose_position = 'POSE'
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return act


# the A file
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["PF_A"]))
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
hip = (arm.matrix_world @ arm.data.bones[PFX + "Hips"].head_local).z
act = play(arm, hip)
bones = [b.name for b in arm.pose.bones]
col = {b: k for k, b in enumerate(bones)}
aw = np.array(arm.matrix_world)
S = np.stack([aw @ np.array(arm.pose.bones[b].matrix @ arm.data.bones[b].matrix_local.inverted()) @ np.linalg.inv(aw) for b in bones])
targets = {}
for o in bpy.data.objects:
    if o.type != 'MESH' or o.name not in edited:
        continue
    if KEY and o.data.shape_keys and KEY in o.data.shape_keys.key_blocks:
        o.data.shape_keys.key_blocks[KEY].value = 1.0          # a second edit was made with the key on: it stacks on it
        bpy.context.view_layer.update()
    now = posed(o)
    if len(now) != len(edited[o.name]):
        raise SystemExit(f"[{TAG}] {o.name}: {len(edited[o.name])} vertices in the fix, {len(now)} in the A: the order is gone")
    moved = np.linalg.norm(edited[o.name] - now, axis=1) > EPS
    print(f"[{TAG}] {o.name}: {int(moved.sum())}/{len(now)} moved, largest {np.linalg.norm(edited[o.name] - now, axis=1).max() * 100:.2f} cm")
    if not moved.any():
        continue
    names = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(now), len(bones)))
    for v in o.data.vertices:
        for g in v.groups:
            k = col.get(names[g.group])
            if k is not None:
                w[v.index, k] = g.weight
    M = np.einsum('nb,bij->nij', w / np.maximum(w.sum(1), 1e-12)[:, None], S)
    M[w.sum(1) <= 1e-12] = np.eye(4)
    rest = np.einsum('nij,nj->ni', np.linalg.inv(M), np.c_[edited[o.name], np.ones(len(now))])[:, :3]
    inv = np.linalg.inv(np.array(o.matrix_world))
    local = rest @ inv[:3, :3].T + inv[:3, 3]
    idx = np.nonzero(moved)[0]
    keys = o.data.shape_keys.key_blocks if o.data.shape_keys else None
    if KEY:
        # a corrective: at value 0 the piece is untouched, bit for bit, in every pose; the game drives the value per clip
        if keys is None:
            o.shape_key_add(name="Basis", from_mix=False)
            keys = o.data.shape_keys.key_blocks
        base = keys["Fit"] if "Fit" in keys else keys["Basis"]
        fresh = keys.get(KEY) is None
        kb = keys.get(KEY) or o.shape_key_add(name=KEY, from_mix=False)
        kb.relative_key = base
        for i in range(len(now)):
            if moved[i]:
                kb.data[i].co = local[i]
            elif fresh:
                kb.data[i].co = base.data[i].co
        kb.value = 1.0
        o.data.update()
        targets[o.name] = idx
        continue
    for i in idx:
        i = int(i)
        if keys:
            for k in ("Basis", "Fit"):
                keys[k].data[i].co = local[i]
        o.data.vertices[i].co = local[i]
    o.data.update()
    targets[o.name] = idx
bpy.context.view_layer.update()
for name, idx in targets.items():
    err = np.linalg.norm(posed(bpy.data.objects[name])[idx] - edited[name][idx], axis=1) * 100
    print(f"[{TAG}] {name}: on frame {frame}, the result against the edit: max {err.max():.4f} cm")
if KEY:
    for name in targets:
        bpy.data.objects[name].data.shape_keys.key_blocks[KEY].value = 0.0
arm.animation_data.action = None
bpy.data.actions.remove(act)
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
arm.data.pose_position = 'REST'
out = os.path.abspath(os.environ["PF_OUT"])
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=out)
print(f"[{TAG}] wrote {out}")
