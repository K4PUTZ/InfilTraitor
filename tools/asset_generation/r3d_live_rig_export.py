"""R3D-SPIKE-3D S2 — the agent as ONE skinned mesh with the real walk as an animation.

The bake pipeline poses the rig once per phase and exports a STATIC mesh per phase
(`p2_grip_spike.export_posed`, skins off). This does the same posing — the very
`make_walk_posture()` phases and the same arm IK against the shotgun grip — but
writes each phase as a KEYFRAME on the armature, joins the 62 body meshes into one
(they are all bound by an Armature modifier with vertex groups, so the join keeps
the skin) and exports a single rigged GLB with a looping `walk` action.

A SPIKE ASSET: the weapon mesh is left out (the hands hold the grip in the air), and
nothing in the game reads this file except `Spike3D` behind `ACTOR_MESH`.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/r3d_live_rig_export.py
"""

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p3_posture_export as p3                                   # noqa: E402  (order matters, see p3_walk_export)
import p2_grip_spike as p2                                       # noqa: E402
import p3_walk_export as walk                                    # noqa: E402

KEY = ("shotgun", "lowered")
OUT = os.path.join(p2.REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets", "imported_models",
                   "agent", "agent_live_walk.glb")
## One phase per animation frame at 30 fps: 32 phases over 0.56 s (D61) would be
## ~57 fps, so the ACTION is authored at 32 frames and Godot scales its speed.
FPS = 30


def pose_phase(arm, facing, phase01, name):
    """export_posed's pose half, without the weapon or the export."""
    g = p2.grip_for(KEY, facing)
    arm.rotation_euler = (0.0, 0.0, 0.0)
    p2.reset_pose(arm)
    posture = walk.make_walk_posture(name, phase01)
    xform = posture["apply"](arm)
    aim = (xform.to_3x3() @ Vector(g["aim"]).normalized()).normalized()
    grip_world = xform @ Vector(g["grip"])
    socket_off = arm.data.bones["hand_R"].length * 0.5
    spec = p2.WEAPONS[KEY[0]]
    p2.two_bone_ik(arm, "R", grip_world - aim * socket_off, g["pole_r"], aim)
    if spec["two_handed"]:
        # the fore-grip offset needs the weapon; without its mesh, the left hand
        # reaches the same line a hand-length further along the aim
        p2.two_bone_ik(arm, "L", grip_world + aim * 0.35 - aim * socket_off, g["pole_l"], aim)
    bpy.context.view_layer.update()


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        if pb.rotation_mode == "QUATERNION":
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        else:
            pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def main():
    p3._open_rig()
    p2.setup_render()
    facing = p2.measure_facings()[p2.YAWS[0]]
    arm = p3._open_rig()
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm.animation_data_create()
    action = bpy.data.actions.new("walk")
    arm.animation_data.action = action
    phases = walk.PHASES
    for i in range(phases):
        pose_phase(arm, facing, float(i) / float(phases), "phase%02d" % i)
        key_all(arm, i)
    # close the loop: frame N is phase 0 again
    pose_phase(arm, facing, 0.0, "phase_loop")
    key_all(arm, phases)
    scene.frame_start = 0
    scene.frame_end = phases
    print("[LIVE-RIG] keyed %d phases into action 'walk'" % phases)

    p2.materialise_for_export()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"
              and any(m.type == "ARMATURE" for m in o.modifiers)]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "agent_body"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("[LIVE-RIG] joined %d meshes -> 1 (%d tris, %d material slots)"
          % (len(meshes), tris, len(body.material_slots)))

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_skins=True, export_animations=True,
                              export_apply=False, export_yup=True,
                              export_animation_mode="ACTIONS")
    print("[LIVE-RIG] wrote %s (%d KB)" % (os.path.relpath(OUT, p2.REPO_ROOT), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
