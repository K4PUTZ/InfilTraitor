# tripo_bank_sheets.py — MOVEMENT MV-1 §3: what every clip of the animation bank looks like (Director, 2026-11-04: "catalogadas e salvas"). It poses the figure's official LIGHT Agent
# on each clip of bank/<figure>/, without coat or hat (these frames are about the motion, and the coat is being replaced), and renders 4 frames (first, 1/3, 2/3, last) from three-quarter
# and from the side. The camera follows the hips across the floor (the clips carry root motion) at a fixed height, so a jump or a fall reads. Workbench and one flat colour per piece: fast,
# and the limbs read at tile size. Frames go to temp/work/bank_frames/<figure>/<id>_<view>_<i>.png; `tripo_bank_catalog.py --sheets` stitches them (Blender's Python has no PIL).
# The bank keeps the Hips' translation divided by the source's hip height: it is multiplied back by this figure's own hip height here.
# Env: SHEET_ONLY (comma list of clip ids), SHEET_BANK (default ASSETS/ANIMATIONS/bank).
# Usage (from the repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_bank_sheets.py
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools", "persistent"))
import tripo_common as tc  # noqa: E402
from temp_dir import temp_path  # noqa: E402

TAG = "tripo_bank_sheets"
BANK = os.environ.get("SHEET_BANK", os.path.join(ROOT, "ASSETS/ANIMATIONS/bank"))
ONLY = {x for x in os.environ.get("SHEET_ONLY", "").split(",") if x}
TILE = (168, 196)
VIEWS = (35.0, 90.0)        # azimuth: 0 looks at the figure's front
ELEVATION = math.radians(12.0)
ORTHO = 1.5                 # the tile's height, in figure heights
FRAMES_PER_CLIP = 4
HIDDEN = ("Outfit_Coat", "Outfit_Hat", "Body_Hair_Hat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated", "Icosphere")
COLOUR = {"Outfit_Shirt": (1.0, 1.0, 1.0), "Outfit_Trousers": (0.12, 0.2, 0.55), "Outfit_Tie": (0.8, 0.1, 0.1), "Outfit_Belt": (0.9, 0.55, 0.1), "Outfit_Buckle": (0.9, 0.9, 0.2),
          "Outfit_Shoes": (0.08, 0.08, 0.08), "Body_Hair": (0.3, 0.17, 0.08), "Body_Head": (0.85, 0.6, 0.5), "Body_Hands": (0.85, 0.6, 0.5)}


def fcurves_of(act):
    """the action's curves, legacy or slotted (Blender 4.4+)"""
    if getattr(act, "layers", None):
        return [fc for layer in act.layers for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves]
    return list(getattr(act, "fcurves", []))


def stage(arm, P):
    """Workbench, flat colours, a floor, an orthographic camera; -> (camera data, camera object, floor, figure height, hip height)"""
    sc = bpy.context.scene
    arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
    hip_h = (arm.matrix_world @ arm.data.bones[P + "Hips"].head_local).z
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    missing = [n for n in COLOUR if n not in bpy.data.objects]
    if missing:
        tc.fail(TAG, f"the Agent lacks {missing}")
    low = min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name not in HIDDEN)
    high = max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name not in HIDDEN)
    for o in meshes:
        o.hide_render = o.name in HIDDEN
        if o.name in COLOUR:
            o.color = (*COLOUR[o.name], 1)
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.view_settings.view_transform = 'Standard'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False; sh.show_shadows = False; sh.show_cavity = False; sh.background_type = 'WORLD'
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.62, 0.64, 0.67)
    sc.render.resolution_x, sc.render.resolution_y = TILE; sc.render.resolution_percentage = 100
    fm = bpy.data.meshes.new("floor"); s = 8.0; fm.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)]); fm.update()
    floor = bpy.data.objects.new("floor", fm); sc.collection.objects.link(floor); floor.color = (0.42, 0.43, 0.45, 1); floor.location.z = low
    # the floor fills an orthographic tile, so it shows no height: a dark disc under the hips does (a jump leaves it behind)
    r = 0.22 * (high - low); dm = bpy.data.meshes.new("disc")
    dm.from_pydata([(r * math.cos(i * math.tau / 32), r * math.sin(i * math.tau / 32), 0) for i in range(32)], [], [tuple(range(32))]); dm.update()
    disc = bpy.data.objects.new("disc", dm); sc.collection.objects.link(disc); disc.color = (0.2, 0.2, 0.22, 1); disc.location.z = low + 0.002
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.clip_start = 0.01; cam.clip_end = 60; cam.ortho_scale = ORTHO * (high - low)
    co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    arm.data.pose_position = 'POSE'
    return co, disc, high - low, hip_h, low


def play(arm, path, hip_h):
    """import one bank clip, keep only its action, put the Hips' translation back in this figure's metres, and bind it; -> the action"""
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [a for a in bpy.data.actions if a not in before_a]
    if not new:
        tc.fail(TAG, f"{path} holds no animation")
    for o in [o for o in bpy.data.objects if o not in before_o]:
        bpy.data.objects.remove(o)
    act = new[0]
    for fc in fcurves_of(act):
        if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
            for kp in fc.keyframe_points:
                kp.co.y *= hip_h; kp.handle_left.y *= hip_h; kp.handle_right.y *= hip_h
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    return act


def main():
    doc = json.load(open(os.path.join(BANK, "bank.json")))
    t0 = time.time(); n = 0
    for fig in doc["figures"]:
        clips = sorted(c for c, r in doc["clips"].items() if fig in r and (not ONLY or c in ONLY))
        if not clips:
            continue
        arm, P, _B, _m = tc.load(TAG, os.path.join(ROOT, f"ASSETS/MODELS/official/AGENT_{fig.upper()}_LIGHT.glb"))
        if arm.animation_data:
            arm.animation_data.action = None
        co, disc, height, hip_h, low = stage(arm, P)
        out = temp_path("work", "bank_frames", fig); sc = bpy.context.scene
        print(f"[{TAG}] {fig}: {len(clips)} clips, figure {height:.3f} m, hips {hip_h:.3f} m")
        for ci, cid in enumerate(clips):
            act = play(arm, os.path.join(BANK, fig, cid + ".glb"), hip_h)
            f0, f1 = act.frame_range
            for fi, fr in enumerate(np.linspace(f0, f1, FRAMES_PER_CLIP)):
                sc.frame_set(int(round(fr)))
                hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head
                # the camera height is fixed, so a jump reads, until the head would leave the tile
                ctr = Vector((hp.x, hp.y, max(low + 0.55 * height, hp.z + 0.55 * height - 0.5 * ORTHO * height + 0.05 * height)))
                disc.location.x, disc.location.y = hp.x, hp.y
                for vi, az in enumerate(VIEWS):
                    a = math.radians(az)
                    d = Vector((math.cos(ELEVATION) * math.sin(a), -math.cos(ELEVATION) * math.cos(a), math.sin(ELEVATION)))
                    co.location = ctr + d * 12; co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
                    sc.render.filepath = str(out / f"{cid}_{vi}_{fi}.png")
                    bpy.ops.render.render(write_still=True)
            arm.animation_data.action = None; bpy.data.actions.remove(act); n += 1
            if ci % 25 == 24:
                bpy.data.orphans_purge(do_recursive=True)
    print(f"[{TAG}] {n} clips rendered in {time.time() - t0:.0f} s")


main()
