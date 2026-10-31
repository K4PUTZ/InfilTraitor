# tripo_look.py — a figure in its SURFACE (ACTOR D87 T6): palette colour (or a painted map, "map", path beside the JSON) x grayscale detail per slot, read from AGENT_SURFACE.json, on the
# clean UVs of tripo_uv.py; Tripo's corner normals kept. Blender EEVEE renders (a substitution: the look, not Godot's light): front, side
# and back, a close-up of the chest and of the face, and the game camera (30 deg elevation, 45 deg azimuth, the figure ~190 px tall).
# Env: LOOK_IN (a tripo_uv output), LOOK_FIGURE (female | male), LOOK_SURFACE (default ASSETS/MODELS/official/AGENT_SURFACE.json),
#      LOOK_DETAIL (default ASSETS/MODELS/official/detail), RV_OUT. Usage: blender -b -P tripo_look.py
import json, math, os, sys
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_look"
IN, FIG, OUT = os.environ["LOOK_IN"], os.environ["LOOK_FIGURE"], os.environ["RV_OUT"].rstrip("/")
SURF_PATH = os.environ.get("LOOK_SURFACE", "ASSETS/MODELS/official/AGENT_SURFACE.json")
SURF = json.load(open(SURF_PATH))[FIG]
DET = os.environ.get("LOOK_DETAIL", "ASSETS/MODELS/official/detail")
os.makedirs(OUT, exist_ok=True)
arm, P, B, meshes = tc.load(TAG, IN)
H = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in meshes)


def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


def material(name, s):
    m = bpy.data.materials.new("surf_" + name); nt = m.node_tree; n, L = nt.nodes, nt.links
    b = n["Principled BSDF"]; b.inputs["Roughness"].default_value = s["rough"]; b.inputs["Metallic"].default_value = s.get("metal", 0.0)
    tc_ = n.new("ShaderNodeTexCoord"); mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (s["tile"], s["tile"], 1)
    tx = n.new("ShaderNodeTexImage"); tx.image = bpy.data.images.load(f"{DET}/{s['material']}.png", check_existing=True)
    tx.image.colorspace_settings.name = 'Non-Color'
    L.new(tc_.outputs["UV"], mp.inputs["Vector"]); L.new(mp.outputs["Vector"], tx.inputs["Vector"])
    mul = n.new("ShaderNodeMix"); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1.0
    sA = [x for x in mul.inputs if x.name == "A" and x.type == 'RGBA'][0]; sB = [x for x in mul.inputs if x.name == "B" and x.type == 'RGBA'][0]
    sA.default_value = lin(s["colour"]); L.new(tx.outputs["Color"], sB)
    if s.get("map"):                                     # a painted map (the head, D87 (3)) replaces the flat colour, on the piece's own UVs
        pm = n.new("ShaderNodeTexImage"); pm.image = bpy.data.images.load(os.path.join(os.path.dirname(SURF_PATH), s["map"]), check_existing=True)
        L.new(pm.outputs["Color"], sA)
    L.new([x for x in mul.outputs if x.type == 'RGBA'][0], b.inputs["Base Color"])
    bu = n.new("ShaderNodeBump"); bu.inputs["Strength"].default_value = s["bump"]; bu.inputs["Distance"].default_value = 0.002
    L.new(tx.outputs["Color"], bu.inputs["Height"]); L.new(bu.outputs["Normal"], b.inputs["Normal"])
    return m


for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    nm = o.name.split(".")[0]
    if nm not in SURF:
        o.hide_render = True; continue
    o.data.materials.clear(); o.data.materials.append(material(nm, SURF[nm]))
sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'AgX'
wd = bpy.data.worlds.new("w"); sc.world = wd; wd.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.76, 0.78, 1)
wd.node_tree.nodes["Background"].inputs[1].default_value = 0.6
for n_, en, rot in (("key", 3.5, (50, 0, -35)), ("fill", 1.0, (60, 0, 140)), ("rim", 2.5, (70, 0, 200))):
    lt = bpy.data.lights.new(n_, 'SUN'); lt.energy = en
    lo = bpy.data.objects.new(n_, lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(v) for v in rot]
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co


def shot(path, az, el, ctr, ortho, w, h):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
    cam.ortho_scale = ortho; cam.clip_start = 0.01; cam.clip_end = 50
    co.location = Vector(ctr) + d * 10; co.rotation_euler = (Vector(ctr) - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x, sc.render.resolution_y = w, h; sc.render.filepath = path; bpy.ops.render.render(write_still=True)


body = (0, 0, 0.5 * H)
for az, nm in ((0, "front"), (90, "side"), (180, "back")):
    shot(f"{OUT}/{FIG}_{nm}.png", az, 4, body, 1.08 * H, 420, 640)
shot(f"{OUT}/{FIG}_close.png", 20, 6, (0, 0, 0.72 * H), 0.34 * H, 600, 600)
hd = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith("Body_Head")]
if hd:
    zs = [(hd[0].matrix_world @ v.co).z for v in hd[0].data.vertices]
    shot(f"{OUT}/{FIG}_face.png", 15, 4, (0, 0, (max(zs) + min(zs)) / 2), 1.5 * (max(zs) - min(zs)), 600, 600)
g = H * math.cos(math.radians(30)) * 240 / 190.0
shot(f"{OUT}/{FIG}_game.png", 45, 30, body, g, 160, 240)
print(f"[{TAG}] {FIG}: renders in {OUT}")
