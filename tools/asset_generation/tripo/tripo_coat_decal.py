# tripo_coat_decal.py — the emblem DECAL on the coat's back, on the standalone COAT_BASE (ACTOR D90, 2026-11-02, Director: "incorporar um decal nas costas do modelo pra servir de referencia desde a loja ate o produto final in-game").
# D90's method, on the coat alone (rest pose, front -y): the emblem is projected from behind onto the coat and kept in a UV map of its own (`DecalUV`: u runs right to left as seen from behind so the emblem reads true), with a per-vertex
# mask (`DecalMask`) that is 1 on the OUTER back and 0 where a ray out of the back meets the coat again (the lining, the front panels) or where the surface turns away from the back. The shader lays the emblem over the colour by
# alpha x mask and nothing outside the rectangle (CLIP); the coat's own UVs are not read, and the decal rides the skin like any vertex. The rectangle keeps the emblem's aspect: DEC_W metres wide, centred on x = DEC_X0 at height DEC_ZC.
# Writes the coat (DecalUV as the second UV map, DecalMask as the active colour) to DEC_OUT and, with DEC_RENDER (a path prefix), the store renders (Blender EEVEE: the form, not Godot's shader) in a matte leather (ROUGH).
# Env: DEC_IN (COAT_BASE.glb), DEC_PNG (the emblem, RGBA), DEC_OUT, DEC_W (0.22), DEC_ZC (0.64), DEC_X0 (0), ROUGH (0.55), DEC_RENDER.  Usage: blender -b -P tripo_coat_decal.py
import math, os, sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_coat_decal"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.environ["DEC_IN"])
coat = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = coat.data
img = bpy.data.images.load(os.path.abspath(os.environ["DEC_PNG"])); img.colorspace_settings.name = 'sRGB'; img.alpha_mode = 'STRAIGHT'
iw, ih = img.size
W_, X0, ZC = float(os.environ.get("DEC_W", "0.22")), float(os.environ.get("DEC_X0", "0")), float(os.environ.get("DEC_ZC", "0.64"))
H_ = W_ * ih / iw
V = np.array([(coat.matrix_world @ v.co)[:] for v in me.vertices])
# (1) DecalUV: an orthographic projection along y; seen from behind the screen's right is -x
for u in list(me.uv_layers)[1:]:
    me.uv_layers.remove(u)
uv = me.uv_layers.new(name="DecalUV")
for l in me.loops:
    p = V[l.vertex_index]; uv.data[l.index].uv = (0.5 - (p[0] - X0) / W_, 0.5 + (p[2] - ZC) / H_)
# (2) DecalMask per vertex: facing the back, nothing of the coat behind it (a ray along +y), inside the rectangle (with a margin)
verts = [tuple(v) for v in V]; tris = [tuple(t.vertices) for t in me.loop_triangles]
bvh = BVHTree.FromPolygons(verts, tris)
nrm = np.array([(coat.matrix_world.to_3x3() @ v.normal)[:] for v in me.vertices])
mask = np.zeros(len(V), np.float32)
for i, p in enumerate(V):
    if abs(p[0] - X0) > 0.62 * W_ or abs(p[2] - ZC) > 0.62 * H_ or nrm[i][1] < 0.1:
        continue
    if bvh.ray_cast(Vector(p + np.array([0, 2e-4, 0])), Vector((0, 1, 0)), 0.5)[0] is not None:
        continue
    t = float(np.clip((nrm[i][1] - 0.1) / 0.5, 0, 1)); mask[i] = t * t * (3 - 2 * t)
for ca in list(me.color_attributes):
    me.color_attributes.remove(ca)
ca = me.color_attributes.new("DecalMask", 'FLOAT_COLOR', 'POINT')
ca.data.foreach_set("color", np.stack([mask, mask, mask, np.ones(len(mask), np.float32)], 1).ravel())
me.color_attributes.active_color = ca
print(f"[{TAG}] decal {W_:.3f} x {H_:.3f} m at x {X0:+.3f} z {ZC:.3f}; {int((mask > 0.5).sum())} of {len(V)} vertices carry the mask")
# (3) the store material: matte leather (a procedural grain for the render only) with the emblem laid over it by alpha x mask
ROUGH = float(os.environ.get("ROUGH", "0.55"))
mat = bpy.data.materials.new("leather_decal"); nt = mat.node_tree; bs = nt.nodes["Principled BSDF"]
bs.inputs["Roughness"].default_value = ROUGH
if "Specular IOR Level" in bs.inputs:
    bs.inputs["Specular IOR Level"].default_value = 0.3
tcn = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 260; nz.inputs["Detail"].default_value = 5
bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.28; bp.inputs["Distance"].default_value = 0.002
nt.links.new(tcn.outputs["Object"], nz.inputs["Vector"]); nt.links.new(nz.outputs["Fac"], bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = "DecalUV"
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = img; tx.extension = 'CLIP'
nt.links.new(uvn.outputs["UV"], tx.inputs["Vector"])
am = nt.nodes.new("ShaderNodeAttribute"); am.attribute_name = "DecalMask"; am.attribute_type = 'GEOMETRY'
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'
nt.links.new(tx.outputs["Alpha"], mul.inputs[0]); nt.links.new(am.outputs["Fac"], mul.inputs[1])
mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.inputs["A"].default_value = (0.04, 0.04, 0.045, 1)
nt.links.new(mul.outputs["Value"], mix.inputs["Factor"]); nt.links.new(tx.outputs["Color"], mix.inputs["B"]); nt.links.new(mix.outputs["Result"], bs.inputs["Base Color"])
me.materials.clear(); me.materials.append(mat)
bpy.ops.object.select_all(action='DESELECT'); coat.select_set(True)
if os.environ.get("DEC_OUT"):
    bpy.ops.export_scene.gltf(filepath=os.environ["DEC_OUT"], use_selection=True, export_extras=True, export_vertex_color='ACTIVE')
    print(f"[{TAG}] wrote {os.environ['DEC_OUT']}")
pre = os.environ.get("DEC_RENDER", "")
if pre:
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not coat:
            o.hide_render = True
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE'; sc.render.film_transparent = True; sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1300
    wd = bpy.data.worlds.new("w"); sc.world = wd; wd.use_nodes = True; wd.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.037, 0.045, 1)
    for nm, en, rot in (("key", 5.4, (50, 0, -35)), ("fill", 1.9, (60, 0, 140)), ("rim", 3.2, (70, 0, 200))):
        lt = bpy.data.lights.new(nm, 'SUN'); lt.energy = en; lo = bpy.data.objects.new(nm, lt); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(x) for x in rot]
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    ctr = Vector((0, 0, 0.5)); Hc = 1.0
    for tag, az, el, scale, c in (("back", 180, 4, 1.12, ctr), ("backthree", 145, 8, 1.12, ctr), ("game", 225, 30, 1.12, ctr), ("close", 180, 4, 0.52, Vector((X0, 0, ZC + 0.06)))):
        a_, e_ = math.radians(az), math.radians(el); d_ = Vector((math.cos(e_) * math.sin(a_), -math.cos(e_) * math.cos(a_), math.sin(e_)))
        cam.ortho_scale = scale * Hc; co.location = c + d_ * 10; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{pre}_{tag}.png"; bpy.ops.render.render(write_still=True)
