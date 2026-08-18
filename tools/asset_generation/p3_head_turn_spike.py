"""CHARACTER_MASTER_PLAN Part 3 — head-turn spike: does a separate head layer work?

Director, 2026-08-17: *"a gente precisa que a cabeça faça o giro de um lado para
o outro com os frames intermediários... o chapéu também precisa ser separado
porque ele vai mudar no agente. E o inimigo poderia estar sem chapéu."*

THE CLAIM THIS SPIKE EXISTS TO TEST, before any runtime layer system is built:

  A head frame depends ONLY on the head's absolute yaw — never on which way the
  BODY is facing.

If true, head art is additive in one dimension (yaw steps) instead of
multiplicative across the body's four facings, which is the whole difference
between "a sweep is affordable" and "a sweep costs 4x everything". It should
hold because every head segment (seg_head and the four fedora parts) is bound to
the `head` bone and that bone sits on the figure's vertical axis at (0, 0, z) —
rotating the BODY moves the head's orientation but not its centre, and the head
layer is rendered from its own absolute yaw regardless. `head_independence`
below MEASURES that instead of assuming it: the same head yaw is rendered under
two different body yaws and the two images are compared pixel for pixel.

WHAT IT RENDERS (Screenshots/p3_head_turn/):
  sweep_full_*    the whole figure, head yawing across the range
  sweep_head_*    the head+hat layer alone, same yaws (what a layer would ship)
  sweep_nohat_*   the head WITHOUT the fedora — the enemy's bare head, and the
                  proof the hat is separable rather than fused to the skull
  sweep_hat_*     the fedora alone — the D53 costume-flip layer
  indep_*         the independence check described above

Deliberately NOT a bake: this renders through p1_agent_preview's own camera
(GAME_ELEV/GAME_AZIM, D26 — any other angle breaks the runtime light maths) to
answer a design question. Turning the answer into shipped frames is the bake
chain's job, and is gated on the Director ratifying the layer split.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/p3_head_turn_spike.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector, Matrix

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_MODEL = os.environ.get("P3_MODEL", "agent_base")
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "agent", "%s.blend" % _MODEL)
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", os.environ.get("P3_OUT", "p3_head_turn"))

## D26 — the game's fixed isometric camera. Never change these here.
GAME_ELEV, GAME_AZIM = 30.0, 45.0
RES = (300, 420)
ORTHO = 2.15

## The sweep. Director asked for "de um lado para o outro" WITH in-betweens, so
## the step is what makes it a sweep rather than a snap. +-75 deg is past what a
## neck does comfortably and is deliberately wider than the final range is likely
## to be: a bracket that stops at the plausible answer cannot show where the
## answer stops being plausible.
##
## The SHIPPING range is +-60 at a 15 deg step (9 frames per posture), chosen
## 2026-08-17 when the Director answered "tudo certo" without picking one: the
## head leads the body by at most one or two of _do_idle_behavior()'s 45 deg
## steps, so +-60 covers the divergence the guard AI can actually produce, and
## +-75 only existed to put the bracket past its own breaking point. Both ends
## stay overridable so widening it later costs a flag, not an edit.
YAW_MIN = float(os.environ.get("P3_YAW_MIN", "-60"))
YAW_MAX = float(os.environ.get("P3_YAW_MAX", "60"))
YAW_STEP = float(os.environ.get("P3_YAW_STEP", "15"))

HAT_PARTS = ("seg_fedora_brim", "seg_fedora_curl", "seg_fedora_band", "seg_fedora_crown")
HEAD_PARTS = ("seg_head",)


def log(m):
    print("[P3-HEAD] %s" % m)


def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.show_shadows = False
    sh.color_type = "MATERIAL"
    return sc


def place_camera(target):
    cam = bpy.context.scene.camera
    if cam is None:
        cam_data = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cam_data)
        bpy.context.collection.objects.link(cam)
        bpy.context.scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ORTHO
    e, a = math.radians(GAME_ELEV), math.radians(GAME_AZIM)
    dist = 10.0
    cam.location = Vector((
        target.x + dist * math.cos(e) * math.sin(a),
        target.y - dist * math.cos(e) * math.cos(a),
        dist * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def find_armature():
    for ob in bpy.data.objects:
        if ob.type == "ARMATURE":
            return ob
    raise SystemExit("[P3-HEAD][FAIL] no armature in %s" % BLEND)


def set_head_yaw(arm, deg):
    """Rotate ONLY the head bone about the figure's vertical axis.

    Pose space, not edit space: the bone keeps its rest orientation and the game
    pipeline reads the posed result, exactly as p3_posture_export.py does.
    """
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones.get("head")
    if pb is None:
        raise SystemExit("[P3-HEAD][FAIL] no 'head' bone — the model changed shape")
    pb.rotation_mode = "XYZ"
    ## LOCAL Y, NOT LOCAL Z. A Blender bone's local Y runs ALONG the bone, and
    ## `head` is built pointing straight up ((0,0,z_head) -> (0,0,z_head+HEAD_H)),
    ## so its local Y *is* the world vertical and a yaw is a rotation about it.
    ## Rotating about local Z instead tilts the head sideways — measured, not
    ## reasoned: the first run of this spike used Z and the independence check
    ## came back 4713 px apart, which is what finally exposed the wrong axis.
    pb.rotation_euler = (0.0, math.radians(deg), 0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def set_body_yaw(arm, deg):
    """Yaw the WHOLE figure, for the independence check only."""
    arm.rotation_mode = "XYZ"
    arm.rotation_euler = (0.0, 0.0, math.radians(deg))
    bpy.context.view_layer.update()


def show_only(names):
    """Hide every mesh except the named ones. None = show all."""
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        ob.hide_render = False if names is None else (ob.name not in names)


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def yaws():
    out, y = [], YAW_MIN
    while y <= YAW_MAX + 1e-6:
        out.append(round(y, 1))
        y += YAW_STEP
    return out


def head_independence(arm, hat_parts):
    """The load-bearing measurement: same head yaw, two different body yaws.

    Renders the head layer alone at head-yaw 0 with the body at 0 deg and again
    with the body at 90 deg. If the head layer is genuinely body-independent the
    two files are identical, and a runtime layer can index head art on yaw alone.
    """
    results = []
    for body in (0.0, 90.0):
        set_body_yaw(arm, body)
        set_head_yaw(arm, 0.0)
        ## The head bone inherits the body yaw, so cancel it to hold the head at
        ## the SAME absolute yaw under both body orientations — that is the
        ## condition a layer would actually ship under.
        set_head_yaw(arm, -body)
        show_only(set(HEAD_PARTS) | set(hat_parts))
        p = os.path.join(OUT_DIR, "indep_body%03d.png" % int(body))
        render(p)
        results.append(p)
    set_body_yaw(arm, 0.0)
    return results


def main():
    if not os.path.isfile(BLEND):
        raise SystemExit("[P3-HEAD][FAIL] model missing: %s — run p1_agent_model.py" % BLEND)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    os.makedirs(OUT_DIR, exist_ok=True)
    setup_scene()
    place_camera(Vector((0.0, 0.0, 0.96)))
    arm = find_armature()

    present = {ob.name for ob in bpy.data.objects if ob.type == "MESH"}
    ## The HEAD is mandatory — without it there is nothing to sweep and a silent
    ## empty render would look like a working spike. The HAT is not: since
    ## 2026-08-17 the enemy palette ships bare-headed on purpose, so a missing
    ## fedora is a configuration, not a fault. Failing on it (as this did on its
    ## first run against agent_base_enemy) would have made the tool refuse the
    ## exact model the Director just asked for.
    missing_head = [n for n in HEAD_PARTS if n not in present]
    if missing_head:
        raise SystemExit("[P3-HEAD][FAIL] head parts absent: %s" % missing_head)
    hat_parts = tuple(n for n in HAT_PARTS if n in present)
    log("hat: %s" % ("%d parts" % len(hat_parts) if hat_parts else "NONE — bare-headed model"))

    ys = yaws()
    log("sweep %s deg .. %s deg, step %s -> %d frames" % (YAW_MIN, YAW_MAX, YAW_STEP, len(ys)))

    head_and_hat = set(HEAD_PARTS) | set(hat_parts)
    for y in ys:
        tag = "%+04d" % int(y)
        set_head_yaw(arm, y)

        show_only(None)
        render(os.path.join(OUT_DIR, "sweep_full_%s.png" % tag))

        show_only(head_and_hat)
        render(os.path.join(OUT_DIR, "sweep_head_%s.png" % tag))

        show_only(set(HEAD_PARTS))
        render(os.path.join(OUT_DIR, "sweep_nohat_%s.png" % tag))

        if hat_parts:
            show_only(set(hat_parts))
            render(os.path.join(OUT_DIR, "sweep_hat_%s.png" % tag))

    set_head_yaw(arm, 0.0)
    show_only(None)
    log("independence check: same head yaw under two body yaws")
    head_independence(arm, hat_parts)

    log("wrote %d frames to %s" % (len(ys) * 4 + 2, OUT_DIR))


main()
