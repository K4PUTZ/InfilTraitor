# tripo_mesh_audit.py — is every piece of a figure ONE finished mesh? (ACTOR D87, 2026-10-31: floor pixels leaked through the Agents on the board.)
# Per skinned piece, on the mesh as the game would read it (the GLB's split vertices WELDED first, as the engine's importer cannot):
#   split      vertices that sit at the same place but are separate in the file (glTF splits at every UV seam and hard edge: the weld count)
#   comps      connected components after the weld (a unified garment is few; hundreds are floating shards)
#   boundary   edges used by ONE face (an open rim: a collar, a hem, a sleeve end are fine; a hole in the middle of a surface is not)
#   nonman     edges used by 3+ faces (a fold glued into the surface)
#   flipped    faces whose winding disagrees with their neighbours' (a cull_back shader drops them: the floor shows through)
#   w_mismatch places holding vertices with DIFFERENT skin weights (must be 0: they drift apart in motion and pinhole)
#   degen      zero-area faces; loose  vertices with no face
#   tiny       faces smaller than TINY_M2 (square metres, the figure is 1 m tall)
# Env: AUDIT_IN (a GLB), AUDIT_JSON (optional: the numbers to a file). Usage: blender -b -P tripo_mesh_audit.py
import json, os, sys
import bpy, bmesh
from collections import deque

TAG = "tripo_mesh_audit"
IN = os.environ["AUDIT_IN"]
TINY_M2 = 2e-7
WELD = 1e-5

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
rows = {}
# the glTF importer adds an 80-face "Icosphere" bone shape of its own (not in the file): not a piece of the figure
for o in sorted((o for o in bpy.data.objects if o.type == 'MESH' and o.vertex_groups), key=lambda o: o.name):
    # SKIN CONSISTENCY, read before the weld: vertices at ONE place that carry DIFFERENT weights drift apart once the rig moves (or even by rounding
    # in the skinning at rest), and the pixels between them show what is behind the figure (a pinhole, not a crack the render at rest can see)
    gname = {g.index: g.name for g in o.vertex_groups}
    at = {}
    for v in o.data.vertices:
        w = tuple(sorted((gname[g.group], round(g.weight, 4)) for g in v.groups if g.weight > 1e-4))
        at.setdefault((round(v.co.x / 2e-6), round(v.co.y / 2e-6), round(v.co.z / 2e-6)), set()).add(w)
    wmis = sum(1 for ws in at.values() if len(ws) > 1)
    bm = bmesh.new(); bm.from_mesh(o.data)
    v0 = len(bm.verts); f0 = len(bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table(); bm.edges.ensure_lookup_table()
    split = v0 - len(bm.verts)
    degen = sum(1 for f in bm.faces if f.calc_area() < 1e-12)
    tiny = sum(1 for f in bm.faces if 1e-12 <= f.calc_area() < TINY_M2)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    # components over face adjacency
    seen = set(); comps = []
    for f in bm.faces:
        if f.index in seen:
            continue
        n = 0; q = deque([f]); seen.add(f.index)
        while q:
            c = q.popleft(); n += 1
            for e in c.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); q.append(g)
        comps.append(n)
    comps.sort(reverse=True)
    # winding agreement across every 2-face edge: two faces that share an edge should traverse it in OPPOSITE directions
    flipped_edges = 0
    for e in bm.edges:
        if len(e.link_faces) == 2:
            a, b = e.link_faces
            def dirn(face):
                for l in face.loops:
                    if l.edge is e:
                        return (l.vert.index, l.link_loop_next.vert.index)
            if dirn(a) == dirn(b):
                flipped_edges += 1
    rows[o.name] = {"faces": f0, "split": split, "comps": len(comps), "biggest": comps[0] if comps else 0, "shards<20": sum(1 for c in comps if c < 20),
                    "boundary": boundary, "nonman": nonman, "flipped_edges": flipped_edges, "degen": degen, "tiny": tiny, "loose": loose, "w_mismatch": wmis}
    bm.free()
print(f"[{TAG}] {IN}")
hdr = ("faces", "split", "comps", "biggest", "shards<20", "boundary", "nonman", "flipped_edges", "degen", "tiny", "loose", "w_mismatch")
print(f"[{TAG}] {'piece':26s}" + "".join(f"{h:>14s}" for h in hdr))
for n, r in rows.items():
    print(f"[{TAG}] {n:26s}" + "".join(f"{r[h]:>14d}" for h in hdr))
if os.environ.get("AUDIT_JSON"):
    json.dump(rows, open(os.environ["AUDIT_JSON"], "w"), indent=1)
