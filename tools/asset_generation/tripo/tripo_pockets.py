# tripo_pockets.py — the coat's pocket openings are closed (Director, 2026-11-01: small holes in the coat's sides, seen walking and running, both figures: "eu removeria bolsos, se houver tecido
# costurado ali [...] deixar a abertura do bolso sugerindo que ele existe"). A pocket here is an open loop in the coat at the hip's side that shows the lining and what lies under it. Each
# such loop (|x| > SIDE_X, hip height, 4-15 cm across) is capped with a fan to a centre pushed DENT_MM into the coat: the opening still reads as a pocket, nothing shows through it.
# Runs after tripo_chains_to_hips, before tripo_back_trim / tripo_coat_push. Env: PK_IN, PK_OUT, DENT_MM (12).  Usage: blender -b -P tripo_pockets.py
import os, sys
from collections import defaultdict
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import tripo_common as tc

TAG = "tripo_pockets"
arm, P, B, meshes = tc.load(TAG, os.environ["PK_IN"])
coat = bpy.data.objects["Outfit_Coat"]
V = tc.world_verts(coat); W = tc.read_weights(coat)
H = float(max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name in ("Outfit_Hat", "Body_Head")) - min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name == "Outfit_Shoes"))
hz = float(B["Hips"][2]); DENT = float(os.environ.get("DENT_MM", "12")) / 1000.0
bm = bmesh.new(); bm.from_mesh(coat.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
key = {}; rep = {}
for v in bm.verts:
    rep[v.index] = key.setdefault(tuple(np.round(np.array(v.co) / 1e-4).astype(int)), v.index)
cnt = defaultdict(int)
for f in bm.faces:
    vs = [rep[v.index] for v in f.verts]
    for i in range(len(vs)):
        a, b = vs[i], vs[(i + 1) % len(vs)]; cnt[(min(a, b), max(a, b))] += 1
adj = defaultdict(list)
for (a, b), c in cnt.items():
    if c == 1:
        adj[a].append(b); adj[b].append(a)
seen = set(); loops = []
for s in adj:
    if s in seen:
        continue
    comp = []; st = [s]
    while st:
        x = st.pop()
        if x in seen:
            continue
        seen.add(x); comp.append(x); st += adj[x]
    loops.append(comp)
n_closed = 0; new_w = []
for comp in loops:
    if any(len(adj[x]) != 2 for x in comp):
        continue
    p = np.array([V[i] for i in comp]); c = p.mean(0); ext = float(np.ptp(p, axis=0).max())
    if abs(c[0]) < 0.07 * H or not (hz - 0.12 * H < c[2] < hz + 0.02 * H) or not (0.04 * H < ext < 0.15 * H):
        continue
    order = [comp[0]]; prev = None
    while len(order) < len(comp):
        nxt = [y for y in adj[order[-1]] if y != prev and y not in order]
        if not nxt:
            break
        prev = order[-1]; order.append(nxt[0])
    out = np.sign(c[0]); centre = c + np.array([-out * DENT, 0, 0])
    bm.verts.ensure_lookup_table(); ring = [bm.verts[i] for i in order]
    cv = bm.verts.new(centre)
    near = min(comp, key=lambda i: np.linalg.norm(V[i] - c)); new_w.append(W[near])
    for i in range(len(ring)):
        a, b = ring[i], ring[(i + 1) % len(ring)]
        f = bm.faces.new((a, b, cv))
        if (np.array(f.normal) @ np.array([out, 0, 0])) < 0:
            f.normal_flip()
    n_closed += 1
bm.to_mesh(coat.data); bm.free()
if n_closed:
    tc.write_weights(coat, W + new_w)
print(f"[{TAG}] {n_closed} pocket opening(s) capped, dent {DENT * 1000:.0f} mm")
tc.export(os.environ["PK_OUT"], meshes, arm)
