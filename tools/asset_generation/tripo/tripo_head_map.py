# tripo_head_map.py — the head's PAINTED map (ACTOR D87 (3), decided 2026-10-31: a map of ours for the head, Tripo's colour as the start):
# a cell-shaded face needs eyes, brows and lips that palette x detail cannot draw. Tripo's base colour is one 4096 atlas for the whole figure
# with the head's islands scattered in it, so the head gets a UV of its own (smart project, the head only) and Tripo's colour is BAKED into a
# HEAD_RES map on it (Cycles, emission through Tripo's UVMap). Only the base colour is taken: the female's normal map draws facets and a stain
# her mesh does not have (D87). The map is the start of a painted map: retouch it by hand in its PNG, the pipeline reads the file.
# Also prints the median skin colour of the map (the face's central pixels), for the hands' palette entry.
# In: HEAD_IN (a tripo_uv output: the head still on Tripo's UVs), HEAD_SRC (the raw Tripo GLB of the same figure, which carries the atlas).
# Out: HEAD_MAP (the PNG), HEAD_OUT (the GLB, the head on its new UVMap). Env: HEAD_RES (default 1024), HEAD_SMOOTH (1: weld + smooth shading only: not
# enough, the female's lines are folds of the mesh), HEAD_SUBDIV (1 for the female, chosen 2026-10-31: the folds go, the drawing softens a little), HEAD_KEEP_ABOVE ("lo,hi": the original
# shape back above hi, see the code; the female: 0.40,0.50). Usage: blender -b -P tripo_head_map.py
import os, sys
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_head_map"
IN, SRC, MAP, OUT = os.environ["HEAD_IN"], os.environ["HEAD_SRC"], os.environ["HEAD_MAP"], os.environ["HEAD_OUT"]
RES = int(os.environ.get("HEAD_RES", "1024"))

# the atlas first (its import is thrown away after the image is kept)
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
atlas = [im for im in bpy.data.images if "basecolor" in im.name.lower()]
if not atlas:
    tc.fail(TAG, f"{SRC}: no base colour image in {[im.name for im in bpy.data.images]}")
atlas_path = os.path.join(os.path.dirname(MAP) or ".", "_atlas_tmp.png")
atlas[0].filepath_raw = atlas_path; atlas[0].file_format = 'PNG'; atlas[0].save()

arm, P, B, meshes = tc.load(TAG, IN)
head = [o for o in meshes if o.name.split(".")[0] == "Body_Head"]
if not head:
    tc.fail(TAG, f"{IN}: no Body_Head")
head = head[0]; me = head.data
src = bpy.data.images.load(atlas_path)
if "UVMap" not in me.uv_layers:
    tc.fail(TAG, f"{IN}: Body_Head has no UVMap")
SUBDIV = int(os.environ.get("HEAD_SUBDIV", "0")); SMOOTH = os.environ.get("HEAD_SMOOTH", "0") == "1"
if SUBDIV or SMOOTH:
    # a low-poly head (the female's: 750 tris) shades its facets as lines on the nose, the eyes and the chin (Director, 2026-10-31, the
    # marked render): one Catmull-Clark level (UVs interpolated linearly, so Tripo's colour still samples right; weights interpolated) and
    # smooth shading without Tripo's corner normals
    for x in bpy.data.objects:
        x.select_set(x is head)
    bpy.context.view_layer.objects.active = head
    import bmesh                                          # weld first: the GLB splits the head at every seam, and Catmull-Clark shrinks each
    bm = bmesh.new(); bm.from_mesh(me)                    # loose piece on its own (holes all over the face, tried 2026-10-31)
    H_ = max((head.matrix_world @ v.co).z for v in me.vertices)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5 * H_); bm.to_mesh(me); bm.free()
    if SUBDIV:
        md = head.modifiers.new("subd", 'SUBSURF'); md.levels = md.render_levels = SUBDIV; md.uv_smooth = 'NONE'
        from mathutils.bvhtree import BVHTree             # the original surface, to give the upper face its own drawing back
        orig = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p_.vertices) for p_ in me.polygons])
        bpy.ops.object.modifier_move_to_index(modifier="subd", index=0); bpy.ops.object.modifier_apply(modifier="subd")
        # KEEP_ABOVE (Director, 2026-10-31: "o olho de uma e a boca da outra"): the subdivided face below z_lo (the mouth, the chin) and the
        # original face above z_hi (the eyes, the brows), as fractions of the head's height; between them a smooth blend toward each
        # vertex's nearest point on the original surface
        ka = os.environ.get("HEAD_KEEP_ABOVE", "")
        if ka:
            lo_, hi_ = (float(x) for x in ka.split(","))
            zs_ = [v.co.z for v in me.vertices]; z0, z1 = min(zs_), max(zs_)
            for v in me.vertices:
                t = min(1.0, max(0.0, ((v.co.z - z0) / (z1 - z0) - lo_) / (hi_ - lo_))); t = t * t * (3 - 2 * t)
                if t > 0:
                    q = orig.find_nearest(v.co)[0]
                    if q is not None:
                        v.co = v.co.lerp(q, t)
            me.update()
    if hasattr(me, "has_custom_normals") and me.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for poly in me.polygons:
        poly.use_smooth = True
    print(f"[{TAG}] head welded and smooth-shaded, subdivided x{SUBDIV}: {len(me.polygons)} faces")
new = me.uv_layers.new(name="HeadUV"); me.uv_layers.active = new
for x in bpy.data.objects:
    x.select_set(x is head)
bpy.context.view_layer.objects.active = head
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')
# bake: emission = the atlas read through Tripo's UVMap, written into the new map through HeadUV
img = bpy.data.images.new("head_map", RES, RES); img.colorspace_settings.name = 'sRGB'
m = bpy.data.materials.new("bake"); nt = m.node_tree; n, L = nt.nodes, nt.links
uvs = n.new("ShaderNodeUVMap"); uvs.uv_map = "UVMap"; tx = n.new("ShaderNodeTexImage"); tx.image = src
em = n.new("ShaderNodeEmission"); L.new(uvs.outputs["UV"], tx.inputs["Vector"]); L.new(tx.outputs["Color"], em.inputs["Color"])
L.new(em.outputs[0], n["Material Output"].inputs["Surface"])
tgt = n.new("ShaderNodeTexImage"); tgt.image = img; n.active = tgt
me.materials.clear(); me.materials.append(m)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 4; sc.cycles.device = 'CPU'
sc.render.bake.margin = 16
bpy.ops.object.bake(type='EMIT')
img.filepath_raw = MAP; img.file_format = 'PNG'; img.save()
os.remove(atlas_path)
# the head now carries only its own UVs, under the name every tool reads
me.uv_layers.remove(me.uv_layers["UVMap"]); me.uv_layers["HeadUV"].name = "UVMap"; me.materials.clear()
px = np.array(img.pixels[:], np.float32).reshape(RES, RES, 4)
skin = px[px[..., 3] > 0][:, :3]
if len(skin):
    lum = skin.mean(1); mid = skin[(lum > np.percentile(lum, 40)) & (lum < np.percentile(lum, 80))]
    c = np.median(mid, 0)
    print(f"[{TAG}] median skin (sRGB) #{''.join(f'{int(round(min(1, v) * 255)):02X}' for v in c)}")
tc.export(OUT, meshes, arm)
print(f"[{TAG}] wrote {MAP} ({RES} px) and {OUT}")
