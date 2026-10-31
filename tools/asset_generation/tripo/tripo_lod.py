# tripo_lod.py — the GAME version of a dressed figure (ACTOR D91): every piece (slot or body part, variants included) is reduced OFFLINE to its own
# triangle budget, keeping its skin weights, so the game switches light pieces on the shared rig and never decimates at run time. Runs on a
# tripo_dress output, BEFORE tripo_uv / tripo_head_map (each light piece then gets clean UVs and its own painted head). The full mesh stays for the showcase.
# Per piece: collapse-decimate to BUDGET[piece] triangles (a piece already under budget is untouched), custom normals cleared (the look is
# faceted, tripo_look flattens it), weights re-cut to 4 influences and normalised. Prints per piece: before -> after, and the total / the visible set
# (the dressed set: coat, hat, coated shirt / trousers / belt, hat hair).
# Env: LOD_IN, LOD_OUT, LOD_WELD (metres, default 0.0003), LOD_SCALE (default 1.0, multiplies every budget). Usage: blender -b -P tripo_lod.py
import os, sys
import bpy, bmesh
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_lod"
IN, OUT = os.environ["LOD_IN"], os.environ["LOD_OUT"]
WELD_DIST = float(os.environ.get("LOD_WELD", "0.0003"))
SCALE = float(os.environ.get("LOD_SCALE", "1.0"))
BUDGET = {"Body_Head": 750, "Body_Hands": 450, "Body_Hair": 600, "Body_Hair_Hat": 400, "Outfit_Hat": 450, "Outfit_Coat": 1000,
          "Outfit_Shirt": 700, "Outfit_Shirt_Coated": 300, "Outfit_Trousers": 600, "Outfit_Trousers_Coated": 500, "Outfit_Shoes": 400,
          "Outfit_Tie": 150, "Outfit_Belt": 250, "Outfit_Belt_Coated": 150, "Outfit_Buckle": 100}
VISIBLE = ("Body_Head", "Body_Hands", "Body_Hair_Hat", "Outfit_Hat", "Outfit_Coat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated",
           "Outfit_Shoes", "Outfit_Tie", "Outfit_Belt_Coated", "Outfit_Buckle")

arm, P, B, meshes = tc.load(TAG, IN)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


before = after = vis = 0
keep = []
for o in meshes:
    name = o.name.split(".")[0]
    n0 = tris(o); before += n0
    if name not in BUDGET:
        print(f"[{TAG}] {name}: no budget, kept at {n0}"); keep.append(o); after += n0; continue
    target = int(BUDGET[name] * SCALE)
    if n0 > target:
        bpy.context.view_layer.objects.active = o
        for ob in bpy.data.objects:
            ob.select_set(ob is o)
        bpy.ops.object.mode_set(mode='OBJECT')
        o.data.free_normals_split() if hasattr(o.data, "free_normals_split") else None
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        # Tripo splits vertices at every hard edge: collapsing the shards apart opens cracks, so WELD them first (the weights of a merged pair are
        # near-identical); the figure is 1 m tall, so WELD_DIST is in metres
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD_DIST); bm.to_mesh(o.data); bm.free()
        n0 = tris(o)
        d = o.modifiers.new("lod", 'DECIMATE'); d.decimate_type = 'COLLAPSE'; d.ratio = target / n0; d.use_collapse_triangulate = True
        # modifier order: the decimate must run on the rest mesh, before the armature
        while o.modifiers[0].name != d.name:
            bpy.ops.object.modifier_move_up(modifier=d.name)
        bpy.ops.object.modifier_apply(modifier=d.name)
        W = tc.read_weights(o)
        tc.write_weights(o, [tc.top4(w, P + "Hips") for w in W])
    n1 = tris(o); after += n1
    if name in VISIBLE:
        vis += n1
    print(f"[{TAG}] {name}: {n0} -> {n1} (budget {target})"); keep.append(o)
print(f"[{TAG}] TOTAL {before} -> {after}; the dressed set {vis}")
tc.export(OUT, keep, arm)
