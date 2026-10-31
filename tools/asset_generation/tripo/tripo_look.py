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
    b.inputs["Specular IOR Level"].default_value = s.get("spec", 0.5)   # 0.5 = Blender's default; cloth lower (the concept art is matte)
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


def hair_material(o, s):
    """HAIR (2026-10-31, against the plastic look, no extra geometry and no transparency): crown UVs (u = the angle about the head's
    vertical axis, v = the angle down from the crown), so the strand map runs from the crown to the tips; the roots darkened and the tips
    lifted along v; a highlight band in v broken by the strands; a matte surface"""
    me = o.data; mw = o.matrix_world
    P_ = [mw @ v.co for v in me.vertices]
    ctr = sum(P_, Vector()) / len(P_); ctr.z = min(p.z for p in P_) + 0.55 * (max(p.z for p in P_) - min(p.z for p in P_))
    hu = me.uv_layers.new(name="HairUV")
    for poly in me.polygons:
        uv_ = []
        for li in poly.loop_indices:
            d = P_[me.loops[li].vertex_index] - ctr
            uv_.append([math.atan2(d.x, -d.y) / (2 * math.pi), math.acos(max(-1, min(1, d.z / max(d.length, 1e-9)))) / math.pi])
        us = [q[0] for q in uv_]
        if max(us) - min(us) > 0.5:                      # a face across the back seam keeps one side
            uv_ = [[q[0] + 1 if q[0] < 0 else q[0], q[1]] for q in uv_]
        for li, q in zip(poly.loop_indices, uv_):
            hu.data[li].uv = q
    m = bpy.data.materials.new("hair"); n, L = m.node_tree.nodes, m.node_tree.links; b = n["Principled BSDF"]
    b.inputs["Roughness"].default_value = s.get("rough", 0.72); b.inputs["Specular IOR Level"].default_value = s.get("spec", 0.25)
    uvn = n.new("ShaderNodeUVMap"); uvn.uv_map = "HairUV"; sep = n.new("ShaderNodeSeparateXYZ"); L.new(uvn.outputs["UV"], sep.inputs[0])
    mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (9, 2, 1); L.new(uvn.outputs["UV"], mp.inputs["Vector"])
    st = n.new("ShaderNodeTexImage"); st.image = bpy.data.images.load(f"{DET}/hair_strands.png", check_existing=True); st.image.colorspace_settings.name = 'Non-Color'
    L.new(mp.outputs["Vector"], st.inputs["Vector"])
    root = n.new("ShaderNodeMapRange"); L.new(sep.outputs["Y"], root.inputs["Value"])      # v: 0 crown .. ~0.6 tips
    root.inputs["From Min"].default_value = 0.05; root.inputs["From Max"].default_value = 0.55
    root.inputs["To Min"].default_value = 0.45; root.inputs["To Max"].default_value = 1.15
    band = n.new("ShaderNodeMapRange"); band.interpolation_type = 'SMOOTHSTEP'; L.new(sep.outputs["Y"], band.inputs["Value"])
    band.inputs["From Min"].default_value = 0.30; band.inputs["From Max"].default_value = 0.34
    band2 = n.new("ShaderNodeMapRange"); band2.interpolation_type = 'SMOOTHSTEP'; L.new(sep.outputs["Y"], band2.inputs["Value"])
    band2.inputs["From Min"].default_value = 0.40; band2.inputs["From Max"].default_value = 0.35
    bm_ = n.new("ShaderNodeMath"); bm_.operation = 'MULTIPLY'; L.new(band.outputs[0], bm_.inputs[0]); L.new(band2.outputs[0], bm_.inputs[1])
    bs = n.new("ShaderNodeMath"); bs.operation = 'MULTIPLY'; L.new(bm_.outputs[0], bs.inputs[0]); L.new(st.outputs["Color"], bs.inputs[1])
    col = n.new("ShaderNodeRGB"); col.outputs[0].default_value = lin(s["colour"])
    m1 = n.new("ShaderNodeVectorMath"); m1.operation = 'MULTIPLY'; L.new(col.outputs[0], m1.inputs[0]); L.new(st.outputs["Color"], m1.inputs[1])
    m2 = n.new("ShaderNodeVectorMath"); m2.operation = 'SCALE'; L.new(m1.outputs[0], m2.inputs[0]); L.new(root.outputs[0], m2.inputs["Scale"])
    hl = n.new("ShaderNodeVectorMath"); hl.operation = 'SCALE'; L.new(bs.outputs[0], hl.inputs["Scale"]); hc = lin(s["colour"]); hl.inputs[0].default_value = tuple(s.get("sheen", 1.0) * (0.04 + 1.6 * c) for c in hc[:3])   # sheen 0: no band
    add = n.new("ShaderNodeVectorMath"); add.operation = 'ADD'; L.new(m2.outputs[0], add.inputs[0]); L.new(hl.outputs[0], add.inputs[1])
    L.new(add.outputs[0], b.inputs["Base Color"])
    bu = n.new("ShaderNodeBump"); bu.inputs["Strength"].default_value = 0.35; bu.inputs["Distance"].default_value = 0.002
    L.new(st.outputs["Color"], bu.inputs["Height"]); L.new(bu.outputs["Normal"], b.inputs["Normal"])
    return m


# a DRESSED figure (tripo_dress): the masked variants stand in for their pieces, which hide; the hat hides unless LOOK_HAT=1
BASE_OF = {"Body_Hair_Hat": "Body_Hair", "Outfit_Shirt_Coated": "Outfit_Shirt", "Outfit_Trousers_Coated": "Outfit_Trousers", "Outfit_Belt_Coated": "Outfit_Belt"}
_names = {o.name.split(".")[0] for o in bpy.data.objects if o.type == 'MESH'}
HAT = os.environ.get("LOOK_HAT", "0") == "1"
COAT = os.environ.get("LOOK_COAT", "1") == "1"           # 0: the basic dress (the coat and its masked variants hidden)
FLAT = os.environ.get("LOOK_FLAT", "1") == "1"          # faceted shading (the default since 2026-10-31; 0 = smooth), the concept art's low-poly look (not the head nor the hands)
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    nm = o.name.split(".")[0]
    hide = COAT and nm in ("Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt") and nm + "_Coated" in _names
    hide |= not COAT and (nm == "Outfit_Coat" or nm.endswith("_Coated"))      # the coat's masked variants show instead
    hide |= (nm in ("Outfit_Hat", "Body_Hair_Hat")) != HAT and nm in ("Outfit_Hat", "Body_Hair_Hat")
    hide |= nm == "Body_Hair" and HAT and "Body_Hair_Hat" in _names
    if hide:
        o.hide_render = True; continue
    nm = BASE_OF.get(nm, nm)
    if FLAT and nm not in ("Body_Head", "Body_Hands"):
        if o.data.has_custom_normals if hasattr(o.data, "has_custom_normals") else False:
            o.data.normals_split_custom_set([(0, 0, 0)] * len(o.data.loops))
        for p_ in o.data.polygons:
            p_.use_smooth = False
    if nm == "Body_Hair" and SURF.get(nm, {}).get("material") == "hair_strands":
        o.data.materials.clear(); o.data.materials.append(hair_material(o, SURF[nm])); continue
    if nm not in SURF:
        o.hide_render = True; continue
    o.data.materials.clear(); o.data.materials.append(material(nm, SURF[nm]))
# LOOK_HAIR_PITCH (degrees, a TEST, 2026-10-31: "rotacionar só o cabelo dela 6 graus forward [...] uma franja sobre os olhos"): the hair
# turned about the Head bone's head, front down
_pitch = float(os.environ.get("LOOK_HAIR_PITCH", "0"))
_off = [float(x) for x in os.environ.get("LOOK_HAIR_OFFSET", "0,0").split(",")]   # mm up, mm back, at a 1.70 m figure (the file is 1 m tall)
if _pitch or any(_off):
    from mathutils import Matrix
    piv = arm.matrix_world @ arm.data.bones[P + "Head"].head_local
    R = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(_pitch), 4, 'X') @ Matrix.Translation(-piv)
    R = Matrix.Translation(Vector((0, _off[1], _off[0])) * (H / 1700.0)) @ R
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.split(".")[0] in ("Body_Hair", "Body_Hair_Hat"):
            mw_ = o.matrix_world; inv_ = mw_.inverted()
            for v in o.data.vertices:
                v.co = inv_ @ (R @ (mw_ @ v.co))
            o.data.update()
_hdrop = float(os.environ.get("LOOK_HAT_DROP", "0"))      # mm down at a 1.70 m figure (a TEST, 2026-10-31)
if _hdrop:
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.split(".")[0] == "Outfit_Hat":
            o.location.z -= _hdrop * H / 1700.0
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
    if os.environ.get("LOOK_HEAD4", "0") == "1":          # the head from its four sides
        for az in (0, 90, 180, 270):
            shot(f"{OUT}/{FIG}_head_{az}.png", az, 4, (0, 0, (max(zs) + min(zs)) / 2 + 0.1 * (max(zs) - min(zs))), 1.9 * (max(zs) - min(zs)), 500, 500)
g = H * math.cos(math.radians(30)) * 240 / 190.0
shot(f"{OUT}/{FIG}_game.png", 45, 30, body, g, 160, 240)
print(f"[{TAG}] {FIG}: renders in {OUT}")
