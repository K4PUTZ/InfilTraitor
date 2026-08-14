"""CHARACTER_MASTER_PLAN §4.7 / §9 #3 — the character's height against a real
8-voxel SLICE, in the three postures, at the scale the Director specified.

THE SPEC (Director, 2026-08-14), which is what finally makes §4.7 derivable:
  standing  slightly TALLER than a slice, so hunching puts him in full cover
            behind the 8 voxels
  crouched  ~2/3 of a slice -- "5 or 6 voxels"
  prone     2 to 3 voxels of cover

THE DERIVATION THAT FALLS OUT. If the 1.80 m figure stands at ~9 voxels, then
one voxel is 0.20 m and a slice (8 voxels, LEVELS_PER_STOREY) is 1.60 m. Every
other number follows without a second guess:

  1 voxel   = 0.20 m = VOXEL_STEP_PX(20) px
  slice     = 8 voxels = 1.60 m = 160 px   (WALL_FLOOR_STEP_PX measures 158)
  standing  = 9 voxels = 1.80 m = 180 px
  crouched  = 5.5 voxels = 1.10 m = 110 px
  prone     = 2.5 voxels = 0.50 m = 50 px

WHAT THIS COSTS, STATED PLAINLY: a 1.60 m storey is short for architecture --
real ones run 2.5-3 m. That is a deliberate trade, and it is the project's own
first tie-breaker doing its job (design_philosophy.md: "Readability always
trumps realism"). It also means the character is TALLER than a wall storey,
which is the opposite of what §4.7's earlier 112 px sketch assumed, and that
sketch is superseded by this.

Cover is physical HERE and probabilistic in the rules -- XCOM's model, the
Director's own reference: standing behind cover does not mean you cannot be hit
(DESIGN_MASTER_PLAN §8.2 gives each cover state a hit multiplier, not immunity).
This render answers where the silhouette sits, never whether a shot lands.

HONEST SCOPE. Blender at the game camera, not the Godot scene with real lights.
The Director asked for the in-scene view; that needs the mockup baked to sprites
and placed in PLAYGROUND, which is Part 2. This answers PROPORTION now.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/s2_posture_scale.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "s2_mockup", "s2_mockup_character.blend")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "s2_posture")

VOXEL_M = 0.20                 # derived above, not chosen
SLICE_VOXELS = 8               # LEVELS_PER_STOREY
SLICE_M = VOXEL_M * SLICE_VOXELS

ELEVATION_DEG = 30.0
AZIMUTH_DEG = 45.0
CAMERA_DISTANCE = 10.0
ORTHO_SCALE = 3.4
RES = (420, 300)


def log(m):
    print("[S2-POSTURE] %s" % m)


def rot(arm, name, xyz):
    pb = arm.pose.bones.get(name)
    if pb is None:
        return
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = tuple(math.radians(v) for v in xyz)


def clear_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
    arm.location = (0.0, 0.0, 0.0)
    arm.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()


def pose_standing(arm):
    clear_pose(arm)


def pose_crouched(arm):
    """Knees and hips fold; the torso stays upright enough to read as a
    deliberate crouch rather than a stumble. Height is verified after, not
    assumed -- the angles are a means, the measured height is the spec."""
    clear_pose(arm)
    for side in ("L", "R"):
        rot(arm, "thigh_%s" % side, (-104, 0, 0))
        rot(arm, "shin_%s" % side, (118, 0, 0))
        rot(arm, "foot_%s" % side, (-14, 0, 0))
    rot(arm, "hips", (26, 0, 0))
    rot(arm, "spine", (-14, 0, 0))
    rot(arm, "chest", (-10, 0, 0))
    rot(arm, "neck", (12, 0, 0))
    for side in ("L", "R"):
        rot(arm, "upperarm_%s" % side, (-42, 0, 0))
        rot(arm, "forearm_%s" % side, (-62, 0, 0))
    arm.location = (0.0, 0.0, -0.86)
    bpy.context.view_layer.update()


def pose_prone(arm):
    """Rotated flat onto the ground plane. A prone figure is a body-length
    footprint, so its COVER height is what matters, not its length."""
    clear_pose(arm)
    arm.rotation_euler = (math.radians(-92.0), 0.0, 0.0)
    arm.location = (0.0, 0.42, 0.11)
    # Arms tucked ALONG the body, not raised — a raised elbow is what pushed the
    # first attempt to 4.0 voxels when the spec asks for 2 to 3.
    for side in ("L", "R"):
        rot(arm, "upperarm_%s" % side, (-16, 0, 0))
        rot(arm, "forearm_%s" % side, (-30, 0, 0))
    rot(arm, "neck", (-30, 0, 0))
    rot(arm, "head", (-22, 0, 0))
    bpy.context.view_layer.update()


def measure_height(arm) -> float:
    dg = bpy.context.evaluated_depsgraph_get()
    hi = -1e9
    lo = 1e9
    for ob in bpy.data.objects:
        if ob.type != "MESH" or not ob.name.startswith("seg_"):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            hi = max(hi, w.z)
            lo = min(lo, w.z)
        ev.to_mesh_clear()
    return hi - max(0.0, lo)


def build_wall():
    """One SLICE: 8 voxels tall. The thing the whole spec is measured against."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.75, 0.0, SLICE_M / 2))
    w = bpy.context.active_object
    w.name = "slice_wall"
    w.scale = (0.35, 1.6, SLICE_M)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # Voxel banding, so the 8 units are countable in the render instead of
    # being a claim in a caption.
    for i in range(1, SLICE_VOXELS):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.75, 0.0, i * VOXEL_M))
        b = bpy.context.active_object
        b.name = "slice_band_%d" % i
        b.scale = (0.36, 1.62, 0.006)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def setup_camera():
    e, a = math.radians(ELEVATION_DEG), math.radians(AZIMUTH_DEG)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    target = Vector((-0.2, 0, 0.85))
    cam.location = Vector((
        CAMERA_DISTANCE * math.cos(e) * math.sin(a),
        -CAMERA_DISTANCE * math.cos(e) * math.cos(a),
        CAMERA_DISTANCE * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = False
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True


def main():
    if not os.path.isfile(BLEND):
        print("[S2-POSTURE][FAIL] mockup missing — run s2_mockup_character.py first")
        sys.exit(1)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        print("[S2-POSTURE][FAIL] AgentRig not found")
        sys.exit(1)

    build_wall()
    setup_camera()
    os.makedirs(OUT_DIR, exist_ok=True)

    log("1 voxel = %.2f m | slice = %d voxels = %.2f m" % (VOXEL_M, SLICE_VOXELS, SLICE_M))
    # Standing includes the fedora on purpose: a hat sticking above the wall is
    # visible, so it is cover-relevant, not decoration.
    targets = {"standing": (8.5, 10.0), "crouched": (5.0, 6.2), "prone": (2.0, 3.2)}
    for name, fn in (("standing", pose_standing), ("crouched", pose_crouched),
                     ("prone", pose_prone)):
        fn(arm)
        h = measure_height(arm)
        vox = h / VOXEL_M
        lo, hi = targets[name]
        ok = "OK" if lo <= vox <= hi else "OUT OF SPEC (target %.1f-%.1f)" % (lo, hi)
        log("%-9s %.2f m = %.1f voxels = %d px   %s"
            % (name, h, vox, int(round(vox * 20)), ok))
        out = os.path.join(OUT_DIR, "posture_%s.png" % name)
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)

    log("")
    log("Cover is physical here and probabilistic in the rules (XCOM's model,")
    log("DESIGN_MASTER_PLAN §8.2) — behind the slice is not immunity.")


if __name__ == "__main__":
    main()
