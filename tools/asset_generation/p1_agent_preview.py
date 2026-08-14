"""CHARACTER_MASTER_PLAN Part 1 — preview sheet for the T-pose base model.

FOUR ORTHOGRAPHIC VIEWS plus the game's own camera, and then the same figure at
the size it actually ships. That last panel is not decoration: S1 already paid
for the lesson once, on 2026-08-14, when six compression variants looked
obviously different in an 8x strip and were indistinguishable at the shotgun's
real 66x33 px. A model judged only at poster size is judged in a view the player
never sees. §4.7 fixes that size exactly -- 9.8 voxels at VOXEL_STEP_PX 20 is a
196 px standing figure.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python tools/asset_generation/p1_agent_preview.py
"""

import math
import os
import sys

import bpy
from mathutils import Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(REPO_ROOT, "ASSETS", "ISOMETRIC", "source_assets",
                     "imported_models", "agent", "agent_base.blend")
OUT_DIR = os.path.join(REPO_ROOT, "Screenshots", "p1_preview")

# The game's fixed isometric camera (CollectibleBakeConfig). D26: a bake at any
# other angle breaks the runtime light maths silently.
GAME_ELEV, GAME_AZIM = 30.0, 45.0

BIG = (420, 620)
ORTHO_BIG = 2.15      # side/game: fits the 1.91 m height
ORTHO_WIDE = 3.10     # front/back: must fit the 1.76 m T-pose span
# §4.7: standing is 9.8 voxels and VOXEL_STEP_PX is 20 -> 196 px, on the nose.
SHIP_PX = 196


def log(m):
    print("[P1-PREVIEW] %s" % m)


def setup_scene(res, ortho):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.show_shadows = False
    # MATERIAL, not SINGLE: the suit/shirt/skin/hat/band split is most of the
    # art decision here and a monochrome render would hide it.
    sh.color_type = "MATERIAL"
    return sc


def place_camera(elev_deg, azim_deg, ortho, target, dist=10.0):
    cam = bpy.context.scene.camera
    if cam is None:
        cam_data = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cam_data)
        bpy.context.collection.objects.link(cam)
        bpy.context.scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    e, a = math.radians(elev_deg), math.radians(azim_deg)
    cam.location = Vector((
        target.x + dist * math.cos(e) * math.sin(a),
        target.y - dist * math.cos(e) * math.cos(a),
        dist * math.sin(e) + target.z,
    ))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    if not os.path.isfile(BLEND):
        print("[P1-PREVIEW][FAIL] model missing: %s\n"
              "Run tools/asset_generation/p1_agent_model.py first." % BLEND)
        sys.exit(1)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    os.makedirs(OUT_DIR, exist_ok=True)
    target = Vector((0.0, 0.0, 0.96))

    setup_scene(BIG, ORTHO_BIG)
    views = [
        ("front", 0.0, 180.0, ORTHO_WIDE),
        ("side", 0.0, 90.0, ORTHO_BIG),
        ("back", 0.0, 0.0, ORTHO_WIDE),
        ("game", GAME_ELEV, GAME_AZIM, ORTHO_BIG),
    ]
    for name, elev, azim, ortho in views:
        setup_scene(BIG, ortho)
        place_camera(elev, azim, ortho, target)
        render(os.path.join(OUT_DIR, "view_%s.png" % name))
        log("rendered %s at ortho %.2f" % (name, ortho))

    # Ship size. The figure is 1.913 m in a frame whose height must map 9.8
    # voxels to 196 px; rendering the same ortho window at the ship resolution
    # is what makes this a true 1:1 rather than a downscale of a poster.
    ship_res = (int(SHIP_PX * BIG[0] / float(BIG[1])), SHIP_PX)
    setup_scene(ship_res, ORTHO_BIG)
    for name, elev, azim in (("game", GAME_ELEV, GAME_AZIM),
                             ("front", 0.0, 180.0)):
        place_camera(elev, azim, ORTHO_BIG, target)
        render(os.path.join(OUT_DIR, "ship_%s.png" % name))
        log("rendered ship-size %s at %dx%d" % (name, ship_res[0], ship_res[1]))

    log("DONE -> %s" % os.path.relpath(OUT_DIR, REPO_ROOT))


if __name__ == "__main__":
    main()
