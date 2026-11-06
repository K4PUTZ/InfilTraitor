# tripo_hat_skin.py — the hat the Director seated by hand, SKINNED to the base's head (ACTOR D106 step 2).
# Reads fit/HAT_CUT_<FIG>.blend (base + the free hat + `Body_Hair_Hat`, made by tripo_hair_brim_cut.py; never saved over). The hat keeps the world
# position it has there: its object transform (the Director's 1.07 / 1.07 / 1.03 scale) is BAKED into the mesh, then it is parented to the armature,
# given the armature modifier and weighted RIGIDLY to `mixamorig:Head` alone (every other group present and empty, as on the base's other pieces).
# The cut hair `Body_Hair_Hat` is bound to the hat: near the brim its weights go to the Head bone alone (see BAND below), so the edge turns with it.
# Checks, printed: the rest pose is unchanged (max vertex move), and with the Head bone turned the hat follows it exactly.
# Out: HS_OUT (default ASSETS/MODELS/fit/HAT_SKIN_<FIG>.blend). Env: HS_FIG (female | male), HS_OUT.
# Usage (repo root): HS_FIG=female blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_hat_skin.py
import math, os, sys
import bpy
import numpy as np
from mathutils import Matrix, Vector

TAG = "tripo_hat_skin"
FIG = os.environ.get("HS_FIG", "")
if FIG not in ("female", "male"):
    sys.exit(f"[{TAG}] HS_FIG must be female or male")
OUT = os.path.abspath(os.environ.get("HS_OUT", f"ASSETS/MODELS/fit/HAT_SKIN_{FIG.upper()}.blend"))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/fit/HAT_CUT_{FIG.upper()}.blend"))
bpy.context.view_layer.update()                       # world matrices are read below (a stale matrix_world cost a session, 2026-11-06)
arm = bpy.data.objects["Armature"]; hat = bpy.data.objects["Outfit_Hat"]; head = bpy.data.objects["Body_Head"]
if hat.parent is not None or hat.vertex_groups:
    sys.exit(f"[{TAG}] {FIG}: the hat is already skinned")
HEAD = "mixamorig:Head"
if HEAD not in arm.data.bones:
    sys.exit(f"[{TAG}] {FIG}: no bone {HEAD}")

before = np.array([(hat.matrix_world @ v.co)[:] for v in hat.data.vertices])
hat.data.transform(hat.matrix_world)                  # the object transform goes into the mesh ...
hat.matrix_world = Matrix.Identity(4)                 # ... and the object stays at the origin, like the base's pieces
bpy.context.view_layer.update()
hat.parent = arm; hat.parent_type = 'OBJECT'; hat.matrix_parent_inverse = arm.matrix_world.inverted()
mod = hat.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
for g in head.vertex_groups:                          # the base's group list, in its order
    hat.vertex_groups.new(name=g.name)
hat.vertex_groups[HEAD].add(list(range(len(hat.data.vertices))), 1.0, 'REPLACE')
bpy.context.view_layer.update()

# The cut hair is bound to the HAT (Director, 2026-11-06: with the head turned the cut edge came away from the brim): the hair keeps its own weights
# (Head, Neck, Spine ...), so under a turned head its edge lagged behind the rigid hat. Each vertex within HS_BAND (default 4 cm) under the hat's
# underside (an upward ray) blends toward 100 % Head, fully at the hat and smoothly back to its own weights at the band's end.
import bmesh
from mathutils.bvhtree import BVHTree
BAND = float(os.environ.get("HS_BAND", "0.04"))
hair = bpy.data.objects["Body_Hair_Hat"]
hb = bmesh.new(); hb.from_mesh(hat.data); hb.transform(hat.matrix_world); tree = BVHTree.FromBMesh(hb); hb.free()
zfloor = min(p[2] for p in before) - 0.3
hi = hair.vertex_groups[HEAD].index; n_full = n_part = 0
for v in hair.data.vertices:
    p = hair.matrix_world @ v.co
    hit = tree.ray_cast(Vector((p.x, p.y, zfloor)), Vector((0, 0, 1)))[0]
    # the first hit going up from the floor is the hat's lowest face above (x, y); a vertex AT or above it is under the hat's mask line
    d = (hit.z - p.z) if hit is not None else 1e9
    t = 1.0 if d <= 0 else (1.0 - min(d / BAND, 1.0)) ** 2 * (3 - 2 * (1.0 - min(d / BAND, 1.0))) if d < BAND else 0.0
    if t <= 0: continue
    w = {g.group: g.weight for g in v.groups}
    for gi in list(w):
        hair.vertex_groups[gi].add([v.index], w[gi] * (1 - t), 'REPLACE')
    hair.vertex_groups[hi].add([v.index], w.get(hi, 0.0) * (1 - t) + t, 'REPLACE')
    n_full += t >= 0.999; n_part += t < 0.999
print(f"[{TAG}] {FIG}: hair bound to the hat: {n_full} vertices fully on the Head, {n_part} blended, of {len(hair.data.vertices)}")
after = np.array([(hat.matrix_world @ v.co)[:] for v in hat.data.vertices])
print(f"[{TAG}] {FIG}: rest pose, largest vertex move {np.abs(after - before).max() * 1000:.4f} mm ({len(after)} vertices)")


def evaluated(o):
    dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg); me = ev.to_mesh()
    P = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices]); ev.to_mesh_clear(); return P


# the hat must follow the Head bone as ONE rigid piece: turn it 25 degrees about X and compare with the bone's own motion
rest_mode = arm.data.pose_position; arm.data.pose_position = 'POSE'      # the base is saved in REST: a pose test needs POSE (REST ignores the bones)
pb = arm.pose.bones[HEAD]; rest = evaluated(hat); restH = evaluated(hair)
pb.rotation_mode = 'XYZ'; pb.rotation_euler = (math.radians(25), 0, 0); bpy.context.view_layer.update()
moved = evaluated(hat)
M = arm.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted() @ arm.matrix_world.inverted()   # the bone's pose delta, in world space
expect = np.array([(M @ Vector(p))[:] for p in rest])
near = [v.index for v in hair.data.vertices if (lambda h: h is not None and h.z - (hair.matrix_world @ v.co).z < 0.01)(tree.ray_cast(Vector(((hair.matrix_world @ v.co).x, (hair.matrix_world @ v.co).y, zfloor)), Vector((0, 0, 1)))[0])]
hrest = restH; hmoved = evaluated(hair)
hexp = np.array([(M @ Vector(hrest[i]))[:] for i in near])
print(f"[{TAG}] {FIG}: the cut hair within 1 cm of the brim ({len(near)} vertices): largest gap to the hat's own motion {np.abs(hmoved[near] - hexp).max() * 1000:.3f} mm")
print(f"[{TAG}] {FIG}: Head turned 25 deg, hat vs the bone's own motion: largest gap {np.abs(moved - expect).max() * 1000:.4f} mm, hat moved up to {np.linalg.norm(moved - rest, axis=1).max() * 100:.1f} cm")
if np.linalg.norm(moved - rest, axis=1).max() < 0.01:
    sys.exit(f"[{TAG}] {FIG}: the pose test moved nothing: the check is vacuous")
pb.rotation_euler = (0, 0, 0); arm.data.pose_position = rest_mode; bpy.context.view_layer.update()

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[{TAG}] {FIG}: -> {OUT}")
