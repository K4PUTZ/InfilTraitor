"""CHARACTER_MASTER_PLAN Part 0 — the shotgun in the mockup's hand, at REAL
on-screen size.

WHY. The S1 comparison strip was rendered at 8x zoom, which is the right way to
find a compression artifact and the wrong way to decide whether it matters. The
Director's call: *"queria ver em tamanho real na mao do personagem em cena pra
decidir."* Correct instinct — the shotgun's real baked silhouette measures
66x33 px (Image.getbbox on the real frame), so an artifact that is obvious at 8x
may be invisible at the size the player actually sees.

WHAT REAL SIZE IS. §4.7's derivation, not a guess: a storey is
LEVELS_PER_STOREY(8) x VOXEL_STEP_PX(20) = 160 px (WALL_FLOOR_STEP_PX measures
158; the ~2 px is the seam). A person at ~70% of a storey is ~112 px tall. The
render canvas below is sized so the 1.96 m mockup lands in that neighbourhood,
which is also the first time this project has looked at a character at its
intended size rather than at agent.gd's hand-calibrated 61 px placeholder --
39% of a storey, i.e. a person about one metre tall.

THE GRIP. Posed to D40's "ready" grip, the middle of the three the weapon layer
indexes on (lowered / ready / aimed). Bone rotations only; the weapon is
parented to the hand_R socket §4.3 exports, which is the same anchor Part 4's
layer compositor will bind to. So this doubles as the first real exercise of the
socket contract, not just a picture.

HONEST SCOPE. Blender render at the game's camera convention, NOT the Godot
bake + relight path. Same declared substitution as s2_turn_render.py: this is
evidence about SIZE and SILHOUETTE READ, not about the runtime pipeline.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/s2_weapon_in_hand.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "s2_mockup", "s2_mockup_character.blend")
SHOTGUN = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                       "imported_models", "quaternius_ultimate_guns_pack",
                       "extracted", "Shotgun Short Stock.glb")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "s2_weapon")

ELEVATION_DEG = 30.0
AZIMUTH_DEG = 45.0
CAMERA_DISTANCE = 8.0
ORTHO_SCALE = 2.6

# Sized so the 1.96 m mockup lands near §4.7's ~112 px derivation. ORTHO_SCALE
# 2.6 m over RES_Y px means the figure occupies RES_Y * 1.96/2.6.
RES_REAL = (128, 168)          # figure ~127 px -- real on-screen size
ZOOMS = [1, 3, 6]              # 1x is the decision view; the rest are for inspection

# A GLB's size and forward axis are arbitrary art data -- D30 paid for that
# lesson when PERSPECTIVE_YAW_DEG was copied between objects and came out 178
# degrees wrong for E/W. So the scale is DERIVED from a real-world target
# length against the model's own measured bounding box, never guessed: this
# shotgun measures 4.471 units on its longest axis, so a hand-picked 0.55 made
# it nearly 2.5 m long, which is what the first render showed.
TARGET_WEAPON_LENGTH_M = 0.85  # a short-stock shotgun


def log(m):
    print("[S2-WEAPON] %s" % m)


def setup_camera(res):
    e, a = math.radians(ELEVATION_DEG), math.radians(AZIMUTH_DEG)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    target = Vector((0, 0, 0.98))
    cam.location = Vector((
        CAMERA_DISTANCE * math.cos(e) * math.sin(a),
        -CAMERA_DISTANCE * math.cos(e) * math.cos(a),
        CAMERA_DISTANCE * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True
    return cam


def pose_ready_grip(arm):
    """D40's middle grip. Both arms swing forward and the forearms fold in, so
    the two hands meet in front of the chest -- the two-handed hold a shotgun
    actually needs, and the reason hand_L exists as its own socket.

    Every arm bone points straight DOWN in rest, so its local Y runs head->tail
    along -Z world and a NEGATIVE local-X rotation swings the limb forward. The
    first attempt mixed in large local-Z twists and threw an arm out sideways;
    the swing is local X, and the tuck is a small local Z."""
    def rot(name, xyz):
        pb = arm.pose.bones.get(name)
        if pb is None:
            return
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = tuple(math.radians(v) for v in xyz)

    rot("upperarm_R", (-58, 0, -8))
    rot("forearm_R", (-58, 0, 0))
    rot("upperarm_L", (-64, 0, 10))
    rot("forearm_L", (-70, 0, 0))
    bpy.context.view_layer.update()


def attach_weapon(arm):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=SHOTGUN)
    new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        print("[S2-WEAPON][FAIL] shotgun import produced no mesh")
        sys.exit(1)

    # Measure the model rather than trusting any assumed scale (see the
    # TARGET_WEAPON_LENGTH_M note).
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for m in meshes:
        for c in m.bound_box:
            w = m.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
    dims = [mx[i] - mn[i] for i in range(3)]
    longest = max(dims)
    scale = TARGET_WEAPON_LENGTH_M / longest
    log("weapon measured %.3f units long -> scale %.4f for %.2f m"
        % (longest, scale, TARGET_WEAPON_LENGTH_M))

    # Reparent the imported hierarchy's TOP-LEVEL objects, which need not be the
    # meshes: a GLB brings its own root, so filtering `meshes` for "no parent"
    # matched nothing, WeaponRoot ended up childless, and the first fixed render
    # came out byte-identical to the broken one. Caught by comparing the images,
    # not by reading the log -- the log happily reported the intended scale.
    tops = [o for o in new if o.parent is None or o.parent not in new]
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    for o in tops:
        o.parent = root
    root.scale = (scale,) * 3

    # Placed BETWEEN the two hand sockets rather than pinned to one, so the hold
    # stays correct if the grip pose changes -- derived from the pose instead of
    # re-tuned against it.
    sr = bpy.data.objects.get("socket_hand_R")
    sl = bpy.data.objects.get("socket_hand_L")
    if sr is None or sl is None:
        print("[S2-WEAPON][FAIL] hand sockets missing -- regenerate the mockup")
        sys.exit(1)
    bpy.context.view_layer.update()
    pr = sr.matrix_world.translation
    pl = sl.matrix_world.translation
    root.location = (pr + pl) * 0.5
    # The model's long axis is local X; the figure faces -Y, so a -90 deg turn
    # about Z aims the barrel forward.
    root.rotation_euler = (0.0, 0.0, math.radians(-90.0))
    bpy.context.view_layer.update()
    # VERIFY the transform actually applied, rather than trusting that it did.
    bpy.context.view_layer.update()
    vmn = [1e9] * 3
    vmx = [-1e9] * 3
    for m in meshes:
        for c in m.bound_box:
            w = m.matrix_world @ Vector(c)
            for i in range(3):
                vmn[i] = min(vmn[i], w[i])
                vmx[i] = max(vmx[i], w[i])
    final_len = max(vmx[i] - vmn[i] for i in range(3))
    centre = [(vmn[i] + vmx[i]) * 0.5 for i in range(3)]
    hands_mid = (pr + pl) * 0.5
    off = max(abs(centre[i] - hands_mid[i]) for i in range(3))
    log("hands R%s L%s" % (tuple(round(v, 2) for v in pr), tuple(round(v, 2) for v in pl)))
    log("weapon AFTER transform: length %.3f m, centre %s, offset from hands %.3f m"
        % (final_len, tuple(round(v, 2) for v in centre), off))
    if abs(final_len - TARGET_WEAPON_LENGTH_M) > 0.05:
        print("[S2-WEAPON][FAIL] weapon is %.3f m, expected %.2f m -- the transform "
              "did not reach the meshes" % (final_len, TARGET_WEAPON_LENGTH_M))
        sys.exit(1)
    if off > 0.35:
        print("[S2-WEAPON][FAIL] weapon centre is %.3f m from the hands" % off)
        sys.exit(1)
    return root


def main():
    for path, what in ((BLEND, "mockup"), (SHOTGUN, "shotgun")):
        if not os.path.isfile(path):
            print("[S2-WEAPON][FAIL] %s missing: %s" % (what, path))
            sys.exit(1)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects.get("AgentRig")
    if arm is None:
        print("[S2-WEAPON][FAIL] AgentRig not found")
        sys.exit(1)

    pose_ready_grip(arm)
    attach_weapon(arm)
    os.makedirs(OUT_DIR, exist_ok=True)

    for z in ZOOMS:
        res = (RES_REAL[0] * z, RES_REAL[1] * z)
        setup_camera(res)
        out = os.path.join(OUT_DIR, "weapon_in_hand_%dx.png" % z)
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        log("wrote %s (%dx%d)" % (os.path.relpath(out, REPO_ROOT), res[0], res[1]))

    log("")
    log("Figure occupies ~%d px at 1x — §4.7 derives ~112 px for a person at 70%%"
        % int(RES_REAL[1] * 1.96 / ORTHO_SCALE))
    log("agent.gd's placeholder is 61 px, i.e. 39%% of a 158 px storey.")


if __name__ == "__main__":
    main()
