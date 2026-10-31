# tripo_crack_probe.py — where does the background show THROUGH a figure? (ACTOR D87, 2026-10-31: floor pixels leaked through the Agents on the board.)
# Renders the figure from the game camera (30 deg elevation, 45 deg azimuth, orthographic, rest pose), flat and unlit, anti-aliasing OFF, on a
# magenta background, at RES px for a 1.3 m frame (the game draws the figure ~190 px tall, so RES 1024 sees a crack ~5x narrower than the game's pixel).
# A "hole" is a magenta pixel that cannot reach the image border without crossing the figure: a gap INSIDE the silhouette. Written: <OUT>_<state>.png
# (the render, holes in red) and a line per state with the hole pixel count. State "dressed" = the coat, the hat and the coated variants; "base" =
# the plain shirt / trousers / belt (no coat, no hat); "unmasked" = the coat and hat over the WHOLE shirt / trousers / belt. AUDIT_VIEWS (default 8): the azimuths are 45 + k * 360 / views.
# Env: PROBE_IN (a GLB), PROBE_OUT (a path prefix), PROBE_RES (default 1024), PROBE_HIDE (comma list of piece names to hide too: the ablation).
# Usage: blender -b -P tripo_crack_probe.py
import math, os, sys
import bpy
from mathutils import Vector

TAG = "tripo_crack_probe"
IN, OUT = os.environ["PROBE_IN"], os.environ["PROBE_OUT"]
RES = int(os.environ.get("PROBE_RES", "1024"))
EXTRA_HIDE = [n for n in os.environ.get("PROBE_HIDE", "").split(",") if n]
DRESSED_ONLY = ("Outfit_Coat", "Outfit_Hat", "Body_Hair_Hat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated")
UNDRESSED = ("Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
if arm.animation_data:
    arm.animation_data.action = None
arm.data.pose_position = 'REST'
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'SINGLE'; sc.display.shading.single_color = (1, 1, 1)
sc.display.render_aa = 'OFF'
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new("w"); w.use_nodes = False; w.color = (1, 0, 1); sc.world = w
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.3
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
ctr = Vector((0, 0, 0.5))
# the game's shader is cull_back: the back of a face is NOT drawn. Blender draws it by default, which hid every hole seen through a cut (the coat's
# opening onto a masked shirt); every piece takes a material that culls.
mat = bpy.data.materials.new("cull"); mat.use_backface_culling = True; mat.diffuse_color = (1, 1, 1, 1)
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.materials.clear(); o.data.materials.append(mat)
sc.display.shading.color_type = 'MATERIAL'
sc.display.shading.show_backface_culling = True    # the Workbench's own switch (the material flag is Eevee's)


def shoot(az_deg, path):
    az, el = math.radians(az_deg), math.radians(30)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    co.location = ctr + d * 5; co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)


MASKED = ("Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated")
# unmasked: the coat and hat over the WHOLE shirt / trousers / belt (no coat-cut variants): what the game shows if the masks go
STATES = {"dressed": UNDRESSED, "base": DRESSED_ONLY + ("Icosphere",), "unmasked": MASKED + ("Body_Hair", "Icosphere")}
for state in os.environ.get("PROBE_STATES", "dressed,base,unmasked").split(","):
    hide = STATES[state]
    for o in bpy.data.objects:
        if o.type == 'MESH':
            n = o.name.split(".")[0]
            o.hide_render = n in hide or n in EXTRA_HIDE
    views = int(os.environ.get("AUDIT_VIEWS", "8"))
    for k in range(views):
        shoot(45 + k * 360.0 / views, f"{OUT}_{state}_{k}.png")
print(f"[{TAG}] rendered {OUT}_<state>_<view>.png")
