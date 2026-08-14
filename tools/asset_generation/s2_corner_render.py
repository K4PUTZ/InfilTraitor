"""CHARACTER_MASTER_PLAN Part 0 / S2 — the CORNER: how facing changes during movement.

THE DIRECTOR'S QUESTION, 2026-08-15. The 833 ms turn settled by the blind bracket
is for DELIBERATE turns -- target selection in aim mode, where the turn IS the
feedback for the player's input. Ordinary movement is different: "ele vai
simplesmente se mover da GU A para a GU B, entrar e sair do cover". So: "fica a
duvida se precisa ter uma transicao e depois comecar o movimento, ou se o giro ja
acontece com inercia pra frente, em movimentos unicos."

Four mechanisms, and they are genuinely different things rather than three
flavours of one. Two are the Director's, two are added because leaving them out
would have pre-narrowed the choice:

  TURN_THEN_MOVE  stop at the corner, turn in place, then step. Costs the full
                  turn on top of the path, every direction change.
  INERTIAL        the rotation is spread across the outgoing step -- one motion,
                  no added time. The Director's second option.
  ANTICIPATED     the rotation runs in the TAIL of the incoming step, so the
                  agent arrives at the corner already facing the new direction.
                  Also free, and it reads as anticipation rather than as a
                  correction.
  SNAP            no turn frames at all; facing flips at the GU boundary while
                  the eye is tracking translation. The free option, and the one
                  that decides whether movement needs the 92 transition yaws --
                  if it survives, §9 #10 collapses to the 744-body-set row.

WHY STEP DURATION IS PART OF THE QUESTION AND NOT A BACKDROP. VOXELS_PER_UNIT_AXIS
is 8 and one voxel is 0.20 m, so ONE GU IS 1.60 m. agent.gd's STEP_DURATION is
0.13 s, which is 12.3 m/s -- faster than the 100 m world record. That number was
tuned for a legless vector diamond and it cannot carry a walk cycle. Whether a
rotation "fits inside the step" is entirely a question of how long the step is,
so the speed sheet below is rendered first and the corner sheet is rendered at a
duration that can actually show a difference.

Also measured, and relevant to "movimentos unicos": agent.gd::_step_next() builds
a fresh EASE_IN_OUT tween PER TILE, so a five-tile path today is five separate
accelerate-decelerate cycles rather than one walk. With a diamond that reads
fine; with legs it will read as hopping.

METHOD. The corner sheet is BLIND and RANDOMISED, per the lesson the turn test
paid for: labels only, no names, no numbers, order seeded so the free option is
not in the position a bias would favour. See s2_turn_bracket_blind.py.

HONEST SCOPE. Blender at the game camera (elevation 30, azimuth 45), NOT baked
through Godot and relit. Cadence and timing only. The leg swing is a simple
distance-driven thigh/arm counter-swing -- enough that the motion reads as
walking rather than sliding, and deliberately NOT a real walk cycle, which is
Part 3's deliverable.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/s2_corner_render.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "s2_mockup", "s2_mockup_character.blend")
OUT_ROOT = os.path.join(REPO_ROOT, "Screenshots", "s2_corner")

ELEVATION_DEG = 30.0
AZIMUTH_DEG = 45.0
CAMERA_DISTANCE = 12.0
# Framed to the L-path plus the figure's height, not to a round number: at 6.2
# the agent rendered 58x115 px inside a 340x400 frame and the swinging foot read
# as a detached piece. The judgement is about limb timing, so the limbs have to
# be resolvable.
ORTHO_SCALE = 4.6
RES = (360, 420)

# One GAME UNIT, in metres. VOXELS_PER_UNIT_AXIS(8) x 0.20 m -- see §4.7.
GU_M = 1.60

# Output rate. Every duration below is quantised to whole frames at this rate,
# so nothing is claimed that the display cannot actually show.
FPS = 60.0

# The deliberate in-place turn, settled 2026-08-15 by blind judgement.
TURN_MS = 833.0

# Stride length. Two footfalls per GU at 1.60 m reads as walking rather than
# skating; the swing is driven by DISTANCE, not by time, so it stays correct at
# every step duration compared below instead of speeding up into a blur.
STRIDE_M = 0.80
THIGH_SWING_DEG = 26.0
ARM_SWING_DEG = 18.0


def log(m):
    print("[S2-CORNER] %s" % m)


def ease(t):
    return t * t * (3.0 - 2.0 * t)


def setup_camera(target):
    e = math.radians(ELEVATION_DEG)
    a = math.radians(AZIMUTH_DEG)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = Vector((
        target.x + CAMERA_DISTANCE * math.cos(e) * math.sin(a),
        target.y - CAMERA_DISTANCE * math.cos(e) * math.cos(a),
        CAMERA_DISTANCE * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True


def add_gu_tiles(centres):
    """Lay the three GAME UNITs the path crosses on the floor. Without them the
    corner is a figure rotating against nothing and 'where it turns relative to
    the GU boundary' -- which is the entire question -- is not readable. Inset
    slightly so the boundaries show as gaps rather than needing outlines, which
    Workbench would not draw."""
    inset = 0.06
    for i, c in enumerate(centres):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(c.x, c.y, 0.002))
        tile = bpy.context.object
        tile.name = "gu_tile_%d" % i
        tile.scale = ((GU_M - inset), (GU_M - inset), 1.0)
        mat = bpy.data.materials.new("gu_mat_%d" % i)
        mat.use_nodes = False
        # Alternating shade: the checker is what makes a GU boundary crossing
        # visible at all in a flat unlit render.
        v = 0.46 if i % 2 == 0 else 0.34
        mat.diffuse_color = (v, v, v * 1.06, 1.0)
        tile.data.materials.append(mat)


def pose_walk(arm, distance_m):
    """Distance-driven leg and arm swing. Driving it by distance rather than by
    time is what keeps the same gait legible across every step duration in the
    speed sheet -- a time-driven swing would simply blur at 130 ms and the sheet
    would be comparing two different animations instead of two speeds."""
    phase = 2.0 * math.pi * (distance_m / STRIDE_M)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        thigh = arm.pose.bones.get("thigh_%s" % side)
        if thigh:
            thigh.rotation_mode = "XYZ"
            thigh.rotation_euler = (
                math.radians(THIGH_SWING_DEG) * sign * math.sin(phase), 0.0, 0.0)
        shin = arm.pose.bones.get("shin_%s" % side)
        if shin:
            shin.rotation_mode = "XYZ"
            # Knee only ever bends one way. Rectifying the swing is what stops
            # the shin hyperextending backwards through the thigh.
            bend = max(0.0, -sign * math.sin(phase))
            shin.rotation_euler = (math.radians(34.0) * bend, 0.0, 0.0)
        upper = arm.pose.bones.get("upperarm_%s" % side)
        if upper:
            upper.rotation_mode = "XYZ"
            upper.rotation_euler = (
                math.radians(ARM_SWING_DEG) * -sign * math.sin(phase), 0.0, 0.0)


def render_sequence(arm, samples, out_dir):
    """`samples` is a list of (position Vector, yaw_deg, distance_travelled_m)."""
    os.makedirs(out_dir, exist_ok=True)
    for i, (pos, yaw, dist) in enumerate(samples):
        arm.location = pos
        arm.rotation_euler = (0.0, 0.0, math.radians(yaw))
        pose_walk(arm, dist)
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(out_dir, "f%03d.png" % i)
        bpy.ops.render.render(write_still=True)
    log("%3d frames -> %s" % (len(samples), os.path.relpath(out_dir, REPO_ROOT)))
    return len(samples)


# --- The path: GU A -> GU B -> GU C, a single 90-degree corner. ------------
# Leg 1 runs along +Y (facing +Y, yaw 0). Leg 2 runs along +X (facing +X,
# yaw -90): rotating +90 about Z carries +X to +Y, so the reverse is -90.
A = Vector((0.0, 0.0, 0.0))
B = Vector((0.0, GU_M, 0.0))
C = Vector((GU_M, GU_M, 0.0))
YAW_1 = 0.0
YAW_2 = -90.0


def build_corner(step_ms, treatment):
    """Return (samples, label). All four share the same path and the same step
    duration; only WHEN the yaw changes differs."""
    step_n = max(2, int(round(step_ms / 1000.0 * FPS)))
    turn_n = max(2, int(round(TURN_MS / 1000.0 * FPS)))
    samples = []
    dist = 0.0

    def leg(p0, p1, n, yaw_fn):
        nonlocal dist
        seg = (p1 - p0).length
        for i in range(n):
            t = ease(i / float(n - 1))
            samples.append((p0 + (p1 - p0) * t, yaw_fn(t), dist + seg * t))
        dist += seg

    if treatment == "TURN_THEN_MOVE":
        leg(A, B, step_n, lambda t: YAW_1)
        # Stationary turn at the corner: distance does not advance, so the legs
        # correctly stop swinging.
        for i in range(turn_n):
            t = ease(i / float(turn_n - 1))
            samples.append((B.copy(), YAW_1 + (YAW_2 - YAW_1) * t, dist))
        leg(B, C, step_n, lambda t: YAW_2)

    elif treatment == "INERTIAL":
        leg(A, B, step_n, lambda t: YAW_1)
        leg(B, C, step_n, lambda t: YAW_1 + (YAW_2 - YAW_1) * ease(t))

    elif treatment == "ANTICIPATED":
        # Rotation runs in the last 50% of the incoming step and completes on
        # arrival, so the agent turns into the corner rather than at it.
        leg(A, B, step_n,
            lambda t: YAW_1 + (YAW_2 - YAW_1) * ease(max(0.0, (t - 0.5) / 0.5)))
        leg(B, C, step_n, lambda t: YAW_2)

    elif treatment == "SNAP":
        leg(A, B, step_n, lambda t: YAW_1)
        leg(B, C, step_n, lambda t: YAW_2)

    else:
        raise ValueError("unknown treatment: %s" % treatment)

    return samples


def main():
    if not os.path.isfile(BLEND):
        print("[S2-CORNER][FAIL] mockup missing: %s\n"
              "Run tools/asset_generation/s2_mockup_character.py first." % BLEND)
        sys.exit(1)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    add_gu_tiles([A, B, C])
    setup_camera(Vector((0.50, 1.30, 0.78)))
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        print("[S2-CORNER][FAIL] AgentRig not found in the mockup")
        sys.exit(1)
    arm.rotation_mode = "XYZ"

    os.makedirs(OUT_ROOT, exist_ok=True)

    # --- Sheet 1: the step-duration finding. One straight GU, three speeds. ---
    for step_ms in (130, 500, 900):
        n = max(2, int(round(step_ms / 1000.0 * FPS)))
        samples = []
        for i in range(n):
            t = ease(i / float(n - 1))
            samples.append((A + (B - A) * t, YAW_1, (B - A).length * t))
        render_sequence(arm, samples,
                        os.path.join(OUT_ROOT, "speed_%dms" % step_ms))
        log("  %d ms per GU -> %.1f m/s (%d frames at %d fps)"
            % (step_ms, GU_M / (step_ms / 1000.0), n, FPS))

    # --- Sheet 2: the four corner treatments, at a step that can show them. ---
    CORNER_STEP_MS = 500
    for treatment in ("TURN_THEN_MOVE", "INERTIAL", "ANTICIPATED", "SNAP"):
        samples = build_corner(CORNER_STEP_MS, treatment)
        render_sequence(arm, samples,
                        os.path.join(OUT_ROOT, "corner_%s" % treatment))
        log("  %-15s %3d frames = %4d ms total"
            % (treatment, len(samples), round(len(samples) / FPS * 1000)))

    log("")
    log("ONE GU = %.2f m (VOXELS_PER_UNIT_AXIS 8 x 0.20 m)" % GU_M)
    log("agent.gd STEP_DURATION = 0.13 s -> %.1f m/s" % (GU_M / 0.13))
    log("Corner sheet rendered at %d ms/GU -> %.1f m/s"
        % (CORNER_STEP_MS, GU_M / (CORNER_STEP_MS / 1000.0)))


if __name__ == "__main__":
    main()
