# coat_push_check.py — what the legs' push does to a finished Agent's coat, in Blender, with the same numpy maths the vertex shader is ported from (`coat_push.py`; ACTOR D88 / D94).
# For each clip frame it moves the coat's vertices as the shader would and measures them against the leg capsules: how many of the skirt's vertices are INSIDE a leg (by more than 2 mm)
# before the push and after it, and how deep; with an output prefix it also renders the original coat and the pushed one from the given azimuths (the game camera's elevation, 30 degrees)
# in flat colours (black coat, blue trousers, white shirt), 6 frames across the clip, so a leg through the cloth shows as blue where it should not be. Nothing is written to the model.
# Args: <figure male|female> <clip id in ASSETS/ANIMATIONS/bank/<figure>/ (or male's, as the engine does) | rest> [<output prefix> <azimuths, e.g. 45,225>].  Env: GLB (default the figure's LIGHT Agent).
# Usage: blender -b -P coat_push_check.py -- male walk /tmp/walk 45,225
import os, sys, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc
import coat_push as cp
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
a = sys.argv[sys.argv.index("--") + 1:]
fig, clip = a[0], a[1]
prefix = a[2] if len(a) > 2 else ""
azs = [float(x) for x in a[3].split(",")] if len(a) > 3 else []
arm, P, B, meshes = tc.load("coat_push_check", os.environ.get("GLB", os.path.join(ROOT, "ASSETS/MODELS/official/AGENT_%s_LIGHT.glb" % fig.upper())))
coat = bpy.data.objects["Outfit_Coat"]
H = float(max(tc.world_verts(bpy.data.objects[n])[:, 2].max() for n in ("Outfit_Hat", "Body_Head")) - tc.world_verts(bpy.data.objects["Outfit_Shoes"])[:, 2].min())
s = cp.spec(H)
V0 = tc.world_verts(coat); W0 = tc.read_weights(coat)
arm_w = np.array([sum(x for n, x in w.items() if any(k in n for k in ("Arm", "Hand", "Shoulder"))) for w in W0])
hips = B["Hips"]
d_rest, mask = cp.rest_field(V0, arm_w, hips, float(hips[2]), H)
rest_hips = np.array(arm.matrix_world @ arm.data.bones[P + "Hips"].matrix_local)
head = lambda n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:])
rest_push = np.maximum(cp.push_distance(V0, d_rest, cp.capsules(head, s), s), 0.0) * mask
on = mask > 0.5


def evaluated(o, dg):
    e = o.evaluated_get(dg); m = e.to_mesh(); p = np.array([(o.matrix_world @ v.co)[:] for v in m.vertices]); e.to_mesh_clear(); return p


def now(dg):
    p = evaluated(coat, dg)
    joint = lambda n: np.array((arm.matrix_world @ arm.pose.bones[P + n].head)[:])
    caps = cp.capsules(joint, s)
    turn = np.array(arm.matrix_world @ arm.pose.bones[P + "Hips"].matrix) @ np.linalg.inv(rest_hips)
    d = d_rest @ turn[:3, :3].T
    q, D = cp.push(p, d, mask, caps, s, rest_push)
    return p, q, caps


def inside(p, caps):
    """depth (m) each point is inside the deepest capsule, 0 when outside all (the capsule's own radius, without the cloth's offset)"""
    deep = np.zeros(len(p))
    for (A, Bp, r) in caps:
        ab = Bp - A; u = np.clip(((p - A) @ ab) / (ab @ ab), 0, 1)
        deep = np.maximum(deep, r - np.linalg.norm(p - (A + u[:, None] * ab), axis=1))
    return deep


rest_in = inside(V0, cp.capsules(head, s))                                 # the coat touches the trousers at a few places at rest: that is its own shape, not a poke
if prefix and azs:
    me = bpy.data.meshes.new("CoatPushed"); me.from_pydata([tuple(v) for v in V0], [], [tuple(p.vertices) for p in coat.data.polygons]); me.update()
    po = bpy.data.objects.new("CoatPushed", me); bpy.context.scene.collection.objects.link(po)
hide = ("Icosphere", "Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair")
for o in bpy.data.objects:
    if o.name in hide:
        o.hide_render = True
show = [o for o in bpy.data.objects if o.type == 'MESH' and o.name not in hide]
col = {"Outfit_Coat": (0.03, 0.03, 0.03), "CoatPushed": (0.03, 0.03, 0.03), "Outfit_Shirt_Coated": (1, 1, 1), "Outfit_Tie": (0.9, 0.05, 0.05), "Outfit_Trousers_Coated": (0.1, 0.2, 0.9),
       "Outfit_Belt_Coated": (1, 0.9, 0.1), "Outfit_Buckle": (1, 0.5, 0.0), "Outfit_Shoes": (0.1, 0.1, 0.1), "Outfit_Hat": (0.15, 0.15, 0.15),
       "Body_Hands": (0.9, 0.6, 0.5), "Body_Head": (0.9, 0.6, 0.5), "Body_Hair_Hat": (0.4, 0.2, 0.1)}
cam, co = tc.setup_renders(show, {o.name: col.get(o.name, (0.5, 0.5, 0.5)) for o in show})
sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = 480, 600
if clip != "rest":
    bank = os.path.join(ROOT, "ASSETS/ANIMATIONS/bank/%s/%s.glb" % (fig, clip))
    if not os.path.exists(bank):
        bank = os.path.join(ROOT, "ASSETS/ANIMATIONS/bank/male/%s.glb" % clip)          # the engine plays the other figure's clip when a figure has none of its own
    before = set(bpy.data.actions); bpy.ops.import_scene.gltf(filepath=bank)
    new = [x for x in bpy.data.actions if x not in before][0]
    for o in list(bpy.data.objects):
        if o.type == 'ARMATURE' and o is not arm:
            for c in list(o.children):
                bpy.data.objects.remove(c)
            bpy.data.objects.remove(o)
    arm.data.pose_position = 'POSE'; arm.animation_data_create(); arm.animation_data.action = new; arm.animation_data.action_slot = new.slots[0]
    f0, f1 = int(new.frame_range[0]), int(new.frame_range[1])
else:
    arm.data.pose_position = 'POSE'; f0, f1 = 1, 2
frames = list(range(f0, f1 + 1, 2)) if clip != "rest" else [f0]
shots = {min(frames, key=lambda f: abs(f - t)) for t in np.linspace(f0, f1, 6, endpoint=False)}
shot_frames = sorted(shots)
n_before, n_after, worst_before, worst_after, moved = [], [], [], [], []
for f in frames:
    sc.frame_set(f); bpy.context.view_layer.update(); dg = bpy.context.evaluated_depsgraph_get()
    p, q, caps = now(dg)
    ib, ia = np.maximum(inside(p, caps) - rest_in, 0.0)[on], np.maximum(inside(q, caps) - rest_in, 0.0)[on]     # deeper than the coat already sits at rest
    n_before.append(int((ib > 0.002).sum())); n_after.append(int((ia > 0.002).sum()))
    worst_before.append(float(ib.max())); worst_after.append(float(ia.max())); moved.append(float(np.linalg.norm(q - p, axis=1).max()))
    if prefix and azs and f in shot_frames:
        me.vertices.foreach_set("co", q.ravel().astype(np.float32)); me.update()
        hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head; ctr = Vector((hp.x, hp.y, 0.62 * H))
        for az in azs:
            a_, e_ = math.radians(az), math.radians(30)
            d_ = Vector((math.cos(e_) * math.sin(a_), -math.cos(e_) * math.cos(a_), math.sin(e_)))
            cam.ortho_scale = 1.0; co.location = ctr + d_ * 10; co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
            for mode in ("orig", "push"):
                coat.hide_render = (mode == "push"); po.hide_render = (mode == "orig")
                sc.render.filepath = "%s_%s_az%d_f%d.png" % (prefix, mode, int(az), shot_frames.index(f)); bpy.ops.render.render(write_still=True)
print(f"[coat_push_check] {fig} {clip}: {len(frames)} frames, {int(on.sum())} skirt vertices pushed; deeper into a leg than at rest by > 2 mm per frame: before the push mean {np.mean(n_before):.1f} "
      f"(worst frame {max(n_before)}, deepest {max(worst_before) * 1000:.0f} mm), after {np.mean(n_after):.1f} (worst frame {max(n_after)}, deepest {max(worst_after) * 1000:.0f} mm); "
      f"the farthest a vertex moves {max(moved) * 100:.0f} cm")
