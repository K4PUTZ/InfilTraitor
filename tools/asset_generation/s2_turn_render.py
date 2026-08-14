"""CHARACTER_MASTER_PLAN Part 0 / S2 — renders a 90-degree turn at several
intermediate-frame counts, so the Director can judge fluidity by eye.

THE QUESTION (D45). The agent has four facings and does not mirror. When it
changes facing, does it SNAP, or turn through intermediate angles -- and if it
turns, how many in-between frames does it take before the motion reads as fluid
rather than as a stutter? D45 makes this a test rather than a decision, for two
reasons: a rig generates in-betweens for free so authoring is not the cost
(D39), and in a turn-based game a long smooth animation reads as SLUGGISH no
matter how good it looks, which is a game-feel ceiling no metric can find.

WHY THE NUMBER MATTERS BEYOND FEEL. Each intermediate angle is a yaw that must
exist as a baked frame, and yaw multiplies the largest term in the budget
(CHARACTER_MASTER_PLAN §8: body = archetype x silhouette x pose x yaw). So this
is not a polish decision; picking 3 intermediates instead of 1 doubles the whole
body catalog. The script prints that arithmetic next to each option.

HEAD LEADS BODY. The turn is not a rigid spin. guard_enemy.gd interpolates
body_angle at TURN_SPEED := 4.0 while vision_angle turns independently at 1.35x
-- head before body -- and D41 ratifies that this authored behaviour is what
keeps a guard reading as alive once it stops being vector geometry. Testing a
rigid spin would be testing something the game does not do.

HONEST SCOPE -- read this before citing the result. These frames are rendered in
Blender at the game's exact camera convention (elevation 30, azimuth 45), NOT
baked through Godot and relit by flat_normal_relight.gdshader. That is a
deliberate substitution and it is stated rather than silent: the question here is
MOTION CADENCE, which the camera angle and frame timing decide, and S1 already
established separately that the relight path survives compression. It is not
evidence about the runtime pipeline, and nothing here should be cited as such.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/s2_turn_render.py
"""

import math
import os
import subprocess
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "s2_mockup", "s2_mockup_character.blend")
OUT_ROOT = os.path.join(REPO_ROOT, "Screenshots", "s2_turn")

# The game's fixed isometric camera. These MUST match CollectibleBakeConfig or
# the frames are not the view the game shows (D26: a mismatch here breaks the
# runtime light maths silently, and it would misrepresent the silhouette too).
ELEVATION_DEG = 30.0
AZIMUTH_DEG = 45.0
CAMERA_DISTANCE = 8.0
ORTHO_SCALE = 2.6
RES = (300, 400)

# Candidate in-between counts for ONE 90-degree facing change.
# Overridable so a stress run does not need a source edit:
#   S2_CANDIDATES=7,11,15,23 S2_DURATIONS=0.35,0.50 blender --background --python ...
CANDIDATES = [int(x) for x in os.environ.get("S2_CANDIDATES", "0,1,3,7").split(",")]

# THE DISPLAY CEILING, and it is the reason more in-betweens stop helping.
# A sprite frame cannot be shown for less than one rendered frame, so a turn of
# D seconds at F fps can display at most D*F distinct frames -- everything past
# that is RAM spent on images the player never sees. The project targets 60 FPS
# (milestones.md M7.0, systems/movement.md, lighting_runtime_pipeline.md's
# 16.67 ms budget); nothing caps it lower in project.godot or in code.
TARGET_FPS = float(os.environ.get("S2_FPS", "60"))

# How far ahead of the hips the head/chest run, as a fraction of the total turn.
# Derived from the shipped ratio: vision turns at 1.35x body, so at the midpoint
# the head is ~35% further through the turn than the body is.
HEAD_LEAD = 0.35
CHEST_LEAD = 0.15

# A 90-degree facing change, in seconds, for the GIF playback. Three speeds so
# the Director can separate "not enough frames" from "too slow", which look
# alike in a single clip.
DURATIONS = [float(x) for x in os.environ.get("S2_DURATIONS", "0.20,0.35").split(",")]


def log(m):
    print("[S2-TURN] %s" % m)


def setup_camera():
    e = math.radians(ELEVATION_DEG)
    a = math.radians(AZIMUTH_DEG)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    target = Vector((0, 0, 0.95))
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
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True


def ease(t: float) -> float:
    """Smoothstep. A real turn accelerates and settles; a linear sweep would make
    every option read worse than it is, and would flatter high frame counts
    unfairly by hiding the lack of an arrival beat."""
    return t * t * (3.0 - 2.0 * t)


def render_turn(arm, intermediates: int, out_dir: str) -> int:
    os.makedirs(out_dir, exist_ok=True)
    steps = intermediates + 2  # start facing + in-betweens + end facing
    total = math.radians(90.0)
    chest = arm.pose.bones.get("chest")
    head = arm.pose.bones.get("head")

    for i in range(steps):
        t = ease(i / float(steps - 1))
        arm.rotation_euler = (0.0, 0.0, total * t)
        # Head and chest run ahead, clamped so they never overshoot the target.
        lead_h = min(1.0, t + HEAD_LEAD * math.sin(math.pi * t))
        lead_c = min(1.0, t + CHEST_LEAD * math.sin(math.pi * t))
        if head:
            head.rotation_mode = "XYZ"
            head.rotation_euler = (0.0, 0.0, total * (lead_h - t))
        if chest:
            chest.rotation_mode = "XYZ"
            chest.rotation_euler = (0.0, 0.0, total * (lead_c - t))
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(out_dir, "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
    log("%d in-between(s) -> %d frames in %s" % (intermediates, steps, out_dir))
    return steps


def make_gif(src_dir: str, frames: int, duration_s: float, out_path: str) -> None:
    """Holds the first and last frame so the turn reads as a discrete game
    action with a start and an arrival, which is how it will actually be seen —
    a bare loop of the sweep makes every option look smoother than it is."""
    per_frame_ms = max(10, int(round(duration_s * 1000.0 / max(1, frames - 1))))
    hold_ms = 450
    listing = os.path.join(src_dir, "concat.txt")
    order = list(range(frames)) + [frames - 1]
    with open(listing, "w") as fh:
        for idx, f in enumerate(order):
            d = hold_ms if (idx == 0 or idx == len(order) - 1) else per_frame_ms
            fh.write("file '%s'\nduration %.3f\n" % (
                os.path.join(src_dir, "f%02d.png" % f), d / 1000.0))
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0",
        "-i", listing,
        "-vf", "scale=iw*2:ih*2:flags=neighbor,split[a][b];"
               "[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse",
        "-loop", "0", out_path,
    ]
    subprocess.run(cmd, check=True)


def main():
    if not os.path.isfile(BLEND):
        print("[S2-TURN][FAIL] mockup missing: %s" % BLEND)
        print("Run tools/asset_generation/s2_mockup_character.py first.")
        sys.exit(1)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    setup_camera()
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        print("[S2-TURN][FAIL] AgentRig not found in the mockup")
        sys.exit(1)

    os.makedirs(OUT_ROOT, exist_ok=True)
    made = []
    for n in CANDIDATES:
        d = os.path.join(OUT_ROOT, "turn_%d_inbetween" % n)
        frames = render_turn(arm, n, d)
        for dur in DURATIONS:
            gif = os.path.join(OUT_ROOT, "turn_%dinb_%dms.gif" % (n, int(dur * 1000)))
            make_gif(d, frames, dur, gif)
            made.append(gif)

    log("")
    log("=== WHAT EACH OPTION COSTS ===")
    log("Every in-between is a yaw that must exist as a baked frame, and yaw")
    log("multiplies the body term (CHARACTER_MASTER_PLAN §8).")
    log("Body sets at 2 archetypes x 3 silhouette classes x 8 poses:")
    for n in CANDIDATES:
        yaws = 4 + 4 * n
        log("  %d in-between(s) -> %2d distinct yaws -> %4d body sets"
            % (n, yaws, 2 * 3 * 8 * yaws))
    log("")
    log("=== DISPLAY CEILING AT %.0f FPS ===" % TARGET_FPS)
    log("A sprite frame cannot show for less than one rendered frame.")
    for dur in DURATIONS:
        cap = int(dur * TARGET_FPS)
        log("  a %.0f ms turn can display at most %d frames -> %d in-betweens"
            % (dur * 1000, cap, max(0, cap - 2)))
    for n in CANDIDATES:
        frames = n + 2
        need = frames / TARGET_FPS
        log("  %2d in-between(s) = %2d frames -> needs >= %.0f ms to show them all"
            % (n, frames, need * 1000))
    log("")
    for g in made:
        log("wrote %s" % os.path.relpath(g, REPO_ROOT))


if __name__ == "__main__":
    main()
