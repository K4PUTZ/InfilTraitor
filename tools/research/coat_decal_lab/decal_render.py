# decal_render.py — a faction emblem on the coat's back, rendered on one DRESSED figure (ACTOR D90).
# THE METHOD: the emblem is projected from behind onto the coat AT REST and stored per corner in a UV map of its own (DecalUV): a square
# centred on the spine at shoulder-blade height (Spine2 plus 15 % of the way to the Neck), its side 0.6 of the coat's back width at that
# height. A per-vertex mask (DecalMask) keeps it on the outer back only: 0 where a ray from the vertex out of the back meets the coat again
# (the lining, the front panels), faded as the surface turns away from the back. The shader lays the emblem over the palette colour by its
# alpha x the mask, nothing outside the square (CLIP). It reads none of the coat's own UVs and rides the skin like any vertex.
# For comparison, the same emblem BAKED into the coat's own texture (UVMap, 1024 x 1024, Cycles EMIT bake): its edges step, because the
# coat's automatic UVs give the emblem few texels.
# Renders (Blender EEVEE, a substitution: it proves form and sharpness, not Godot): <tag>_back_<emblem>.png (whole figure from behind, rest),
# <tag>_close_decal.png / <tag>_close_baked.png (the back up close), <tag>_game_rest_<az>.png (the game camera, 30 deg elevation, 45 deg off
# the back, the figure ~190 px tall), <tag>_run_NN.png / <tag>_game_run_NN.png (24 frames of the clip, rotations only: the Hips' translation
# is muted, the figure runs in place). STILLS_ONLY=1: per emblem, <tag>_back_, <tag>_close_<emblem>.png and <tag>_game_<emblem>.png, then
# stop. ONLY_MOTION=1: the clip's frames alone.
# The dressed figure: tools/asset_generation/tripo/ tripo_assemble.py on the base and on the coat generation, then tripo_dress.py with
# DRESS_COAT=ASSETS/MODELS/official/COAT_BASE.glb (dress_both.sh). Clip: a bank GLB (ASSETS/ANIMATIONS/bank/<figure>/<id>.glb).
# Usage: blender -b -P decal_render.py -- <dressed.glb> <emblem_dir> <out_dir> <tag> <bank_clip.glb>
import math
import os
import sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

GLB, EMB, OUT, TAG, CLIP = sys.argv[sys.argv.index("--") + 1:]
STILLS_ONLY = os.environ.get("STILLS_ONLY", "0") == "1"
ONLY_MOTION = os.environ.get("ONLY_MOTION", "0") == "1"
P = "mixamorig:"
COAT = "CCA33D"                                          # the FID investigators' mustard (COSMETICS §9.4)
EMBS = ("fid", "cws", "bbm", "corp")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
if arm.animation_data:
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    arm.animation_data.action = None
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
M = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == 'MESH'}
HIDE = ("Body_Hair", "Outfit_Shirt", "Outfit_Trousers", "Icosphere")   # the dressed state shows their masked variants
show = [o for n, o in M.items() if n not in HIDE]
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.hide_render = o not in show
H = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in show)


def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


def plain(name, hexc, rough=0.6):
    m = bpy.data.materials.new(name); b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hexc); b.inputs["Roughness"].default_value = rough
    return m


COLS = {"Outfit_Hat": "2A2A2D", "Outfit_Shirt_Coated": "E8E6E0", "Outfit_Tie": "6E1A26", "Outfit_Belt": "2B1E16", "Outfit_Buckle": "B8B8B8",
        "Outfit_Trousers_Coated": "3A3C42", "Outfit_Shoes": "2B1E16", "Body_Head": "D9A88A", "Body_Hands": "D9A88A", "Body_Hair_Hat": "2A2320"}
for n, o in M.items():
    if o in show and n != "Outfit_Coat":
        o.data.materials.clear(); o.data.materials.append(plain("m_" + n, COLS.get(n, "808080")))

# ---- the projection, at REST, onto the coat's outer back (the front is -Y, so the back faces +Y) ----
coat = M["Outfit_Coat"]; me = coat.data
mw = coat.matrix_world; nm = mw.to_3x3().inverted().transposed()
V = np.array([(mw @ v.co)[:] for v in me.vertices]); N = np.array([(nm @ v.normal).normalized()[:] for v in me.vertices])


def bone(n):
    return np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:])


sp2, neck = bone("Spine2"), bone("Neck")
zc = sp2[2] + 0.15 * (neck[2] - sp2[2]); xc = sp2[0]
band = (np.abs(V[:, 2] - zc) < 0.02 * H) & (V[:, 1] > sp2[1])
back_w = V[band, 0].max() - V[band, 0].min()
SIZE = 0.6 * back_w
bvh = BVHTree.FromPolygons([tuple(x) for x in V], [tuple(p.vertices) for p in me.polygons])
BACK = Vector((0, 1, 0)); eps = 0.002 * H
vis = np.array([0.0 if bvh.ray_cast(Vector(q) + BACK * eps, BACK, 0.3 * H)[0] is not None else 1.0 for q in V])
facing = N @ np.array([0.0, 1.0, 0.0])
mask = vis * np.clip((facing - 0.1) / 0.3, 0, 1)
# seen from behind the viewer's right is -X, so u runs along -X and the emblem is not mirrored
uv_v = np.stack([-(V[:, 0] - xc) / SIZE + 0.5, (V[:, 2] - zc) / SIZE + 0.5], 1)
uvl = me.uv_layers.new(name="DecalUV")
loops = np.array([l.vertex_index for l in me.loops])
uvl.data.foreach_set("uv", uv_v[loops].ravel())
me.attributes.new("DecalMask", 'FLOAT', 'POINT').data.foreach_set("value", mask)
inside = (uv_v[:, 0] > 0) & (uv_v[:, 0] < 1) & (uv_v[:, 1] > 0) & (uv_v[:, 1] < 1)
print(f"[decal] {TAG}: H {H:.3f}, back width {back_w:.3f} ({back_w / H:.2f} H), emblem {SIZE:.3f} ({SIZE / H:.2f} H); "
      f"{int(inside.sum())} coat vertices under the square, {int((inside & (mask > 0.99)).sum())} fully painted, "
      f"{int((inside & (vis == 0)).sum())} on inner walls or the front, skipped")


def coat_material(mode, emb_path=None, baked=None):
    """plain: the palette colour; decal: the emblem over it through DecalUV x DecalMask; emit: the same as emission (for the bake);
    baked: the baked image through the coat's own UVMap"""
    m = bpy.data.materials.new("coat_" + mode); nodes, links = m.node_tree.nodes, m.node_tree.links
    b = nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.55
    if mode == "plain":
        b.inputs["Base Color"].default_value = lin(COAT); return m
    if mode == "baked":
        uvn = nodes.new("ShaderNodeUVMap"); uvn.uv_map = "UVMap"
        tx = nodes.new("ShaderNodeTexImage"); tx.image = baked; tx.interpolation = 'Linear'
        links.new(uvn.outputs["UV"], tx.inputs["Vector"]); links.new(tx.outputs["Color"], b.inputs["Base Color"]); return m
    uvn = nodes.new("ShaderNodeUVMap"); uvn.uv_map = "DecalUV"
    tx = nodes.new("ShaderNodeTexImage"); tx.image = bpy.data.images.load(emb_path, check_existing=True)
    tx.extension = 'CLIP'; tx.interpolation = 'Linear'
    atn = nodes.new("ShaderNodeAttribute"); atn.attribute_name = "DecalMask"
    mul = nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'
    mix = nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    sA = [s for s in mix.inputs if s.name == "A" and s.type == 'RGBA'][0]; sB = [s for s in mix.inputs if s.name == "B" and s.type == 'RGBA'][0]
    out = [s for s in mix.outputs if s.type == 'RGBA'][0]
    sA.default_value = lin(COAT)
    links.new(uvn.outputs["UV"], tx.inputs["Vector"]); links.new(tx.outputs["Alpha"], mul.inputs[0]); links.new(atn.outputs["Fac"], mul.inputs[1])
    links.new(mul.outputs[0], mix.inputs[0]); links.new(tx.outputs["Color"], sB); links.new(out, b.inputs["Base Color"])
    if mode == "emit":
        em = nodes.new("ShaderNodeEmission"); links.new(out, em.inputs["Color"]); links.new(em.outputs[0], nodes["Material Output"].inputs["Surface"])
    return m


def set_coat(m):
    me.materials.clear(); me.materials.append(m)


# ---- scene ----
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'; sc.view_settings.view_transform = 'Standard'; sc.render.film_transparent = False
wd = bpy.data.worlds.new("w"); sc.world = wd; wd.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.31, 0.34, 1)
for n_, en, rot in (("key", 3.2, (50, 0, 145)), ("fill", 1.1, (60, 0, -40)), ("rim", 1.6, (70, 0, 20))):
    lt = bpy.data.lights.new(n_, 'SUN'); lt.energy = en
    lo = bpy.data.objects.new(n_, lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(x) for x in rot]
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co


def shot(path, az, el, ctr, ortho, w, h):
    """an orthographic still; az 0 looks at the front, 180 at the back"""
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))
    cam.ortho_scale = ortho; cam.clip_start = 0.01; cam.clip_end = 50
    co.location = Vector(ctr) + d * 10; co.rotation_euler = (Vector(ctr) - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x, sc.render.resolution_y = w, h; sc.render.filepath = path; bpy.ops.render.render(write_still=True)


def emb(k):
    return f"{EMB}/emb_{k}.png"


def bake_compare():
    img = bpy.data.images.new("bake", 1024, 1024); img.colorspace_settings.name = 'sRGB'
    mE = coat_material("emit", emb("fid")); tn = mE.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = img; mE.node_tree.nodes.active = tn
    set_coat(mE)
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 4; sc.cycles.device = 'CPU'
    for o in bpy.data.objects:
        o.select_set(o is coat)
    bpy.context.view_layer.objects.active = coat
    bpy.ops.object.bake(type='EMIT', margin=8)
    img.filepath_raw = f"{OUT}/{TAG}_coat_bake1024.png"; img.file_format = 'PNG'; img.save()
    sc.render.engine = 'BLENDER_EEVEE'
    set_coat(coat_material("baked", baked=img)); shot(f"{OUT}/{TAG}_close_baked.png", 180, 8, back_c, 0.42 * H, 600, 600)


body_c = (0, 0, 0.5 * H); back_c = (xc, 0, zc)
GW, GH = 160, 240
g_ortho = H * math.cos(math.radians(30)) * GH / 190.0    # the figure ~190 px tall on screen, as in play
if not ONLY_MOTION:
    for k in EMBS:
        set_coat(coat_material("decal", emb(k))); shot(f"{OUT}/{TAG}_back_{k}.png", 180, 8, body_c, 1.15 * H, 360, 504)
        if STILLS_ONLY:
            shot(f"{OUT}/{TAG}_close_{k}.png", 180, 8, back_c, 0.42 * H, 600, 600)
            shot(f"{OUT}/{TAG}_game_{k}.png", 135, 30, body_c, g_ortho, GW, GH)
    if STILLS_ONLY:
        print(f"[decal] {TAG}: stills done"); sys.exit(0)
    set_coat(coat_material("decal", emb("fid"))); shot(f"{OUT}/{TAG}_close_decal.png", 180, 8, back_c, 0.42 * H, 600, 600)
    bake_compare()
    set_coat(coat_material("decal", emb("fid")))
    for az in (135, 225):
        shot(f"{OUT}/{TAG}_game_rest_{az}.png", az, 30, body_c, g_ortho, GW, GH)

# ---- the clip: rotations only (the bank's Hips translation is normalised by hip height and is muted here) ----
set_coat(coat_material("decal", emb("fid")))
before = set(bpy.data.objects); acts0 = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=CLIP)
act = [a for a in bpy.data.actions if a not in acts0][0]
for o in [o for o in bpy.data.objects if o not in before]:
    bpy.data.objects.remove(o)
curves = list(getattr(act, "fcurves", []))
for lay in getattr(act, "layers", []):                   # Blender 4.4+ slotted actions keep their curves in channel bags
    for st in lay.strips:
        for cb in st.channelbags:
            curves += list(cb.fcurves)
for fc in curves:
    if fc.data_path.endswith("location") or fc.data_path.endswith("scale"):
        fc.mute = True
ad = arm.animation_data or arm.animation_data_create(); ad.action = act
try:
    ad.action_slot = act.slots[0]
except (AttributeError, IndexError):
    pass
arm.data.pose_position = 'POSE'
f0, f1 = (int(x) for x in act.frame_range)
print(f"[decal] {TAG}: clip {os.path.basename(CLIP)} frames {f0}-{f1}")
for i, fr in enumerate(np.linspace(f0, f1, 25)[:24]):
    sc.frame_set(int(round(fr)))
    hp = arm.matrix_world @ arm.pose.bones[P + "Hips"].head
    shot(f"{OUT}/{TAG}_run_{i:02d}.png", 160, 8, (hp.x, hp.y, zc - 0.05 * H), 0.62 * H, 420, 420)
    if i % 6 == 0:
        shot(f"{OUT}/{TAG}_game_run_{i:02d}.png", 135, 30, (hp.x, hp.y, 0.5 * H), g_ortho, GW, GH)
print(f"[decal] {TAG}: done")
