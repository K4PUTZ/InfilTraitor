# tripo_coat_regions.py — the coat's INITIAL TEXTURE (ACTOR D87 / D89, 2026-11-02, Director: "vamos experimentar texturizar como está, para enxergar melhor o que é o que"). Every face of
# the finished coat gets a region and a colour, painted on the coat's own clean UVs together with the coat's grayscale detail (AGENT_SURFACE: leather, 14 repeats per UV unit):
#   body, sleeves, cuffs, skirt, collar, lapels, the LINING (the coat's second wall, the face that looks at the body), and each kind of LOOSE piece (an island apart from the main
#   surface: buttons, pocket flaps, cuff tabs, belt tabs, the pieces at the hips). A diagnostic palette on purpose: readable first, black later (the palette is the shader's albedo).
# It writes the PNG only (CR_MAP) and prints the legend; nothing is written to the model: tripo_coat_push embeds the map (COAT_TEX) in the last export.
# Run on the coat as it will ship (after tripo_coat_back_out, before tripo_coat_push): the UVs do not change after it. Faces made after the UV step (the pocket caps) have no UV: the
# background is the body colour so they read as body.
# CR_EDGES (1 with CR_PALETTE=ref), CR_GROOVE (0.55), CR_CATCH (1.30): the edges, step (4).
# Env: CR_IN (a finished Agent GLB), CR_MAP (PNG out), CR_RES (1024), CR_DETAIL (default ASSETS/MODELS/official/detail/leather.png), CR_TILE (14).  Usage: blender -b -P tripo_coat_regions.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import tripo_common as tc

TAG = "tripo_coat_regions"
arm, P, B, meshes = tc.load(TAG, os.environ["CR_IN"])
coat = next((o for o in meshes if o.name.split(".")[0] == "Outfit_Coat"), None)   # the base A carries it as Outfit_Coat.001
if coat is None or not coat.vertex_groups:
    tc.fail(TAG, "no skinned Outfit_Coat")
RES = int(os.environ.get("CR_RES", "1024")); TILE = float(os.environ.get("CR_TILE", "14"))
DETAIL = os.environ.get("CR_DETAIL", "ASSETS/MODELS/official/detail/leather.png")
H = float(max(tc.world_verts(o)[:, 2].max() for o in meshes if o.name in ("Outfit_Hat", "Body_Head")) - min(tc.world_verts(o)[:, 2].min() for o in meshes if o.name == "Outfit_Shoes"))
V = tc.world_verts(coat); W = tc.read_weights(coat); me = coat.data
polys = list(me.polygons)
COL = {"body": "#3A3A42", "sleeve": "#323A48", "cuff": "#5C5446", "skirt": "#403A34", "collar": "#50505C", "lapel": "#5A5A68", "lining": "#6A2E32",
       "button": "#C2A85A", "flap": "#9A6A34", "cufftab": "#4E8A5A", "belttab": "#3E8A8A", "hip": "#B040A0", "other": "#D0D0D0"}
# the REFERENCE look (Director, 2026-11-02, the black leather trench coat sheets): near-black faceted leather, the trims (collar, lapels, cuffs and their tabs, the belt's pieces, the
# flaps) a notch lighter and cooler, the buttons tone on tone, the inside black. CR_PALETTE=ref picks it; the default is the diagnostic one above.
REF = {"body": "#242428", "sleeve": "#242428", "cuff": "#303036", "skirt": "#222226", "collar": "#2E2E34", "lapel": "#2E2E34", "lining": "#0C0C0E",
       "button": "#34343A", "flap": "#2A2A30", "cufftab": "#303036", "belttab": "#2A2A30", "hip": "#0C0C0E", "other": "#242428"}
if os.environ.get("CR_PALETTE", "diag") == "ref":
    COL = REF
rgb = {k: np.array([int(v[i:i + 2], 16) for i in (1, 3, 5)], float) / 255.0 for k, v in COL.items()}
# (1) islands on the surface welded by position (a GLB splits vertices at seams)
key = {}; rep = np.zeros(len(V), int)
for i, q in enumerate(np.round(V / 1e-5).astype(np.int64)):
    rep[i] = key.setdefault(tuple(q), i)
par = list(range(len(V)))
def find(a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a
for e in me.edges:
    a, b = find(rep[e.vertices[0]]), find(rep[e.vertices[1]])
    if a != b:
        par[a] = b
isl = {}
for p in polys:
    isl.setdefault(find(rep[p.vertices[0]]), []).append(p.index)
main = max(isl, key=lambda k: len(isl[k]))
region = ["body"] * len(polys)
aw = lambda i: sum(x for n, x in W[i].items() if any(t in n for t in ("Shoulder", "Arm", "Hand")))
legend = []
for k, fl in isl.items():
    if k == main:
        continue
    vs = sorted({v for fi in fl for v in polys[fi].vertices}); pts = V[vs]; c = pts.mean(0); sz = (pts.max(0) - pts.min(0)) / H * 1000
    arm_w = float(np.mean([aw(v) for v in vs])); n = len(fl)
    if n <= 2 or max(sz) < 25:
        kind = "button"
    elif arm_w > 0.6:
        kind = "cufftab"
    elif abs(c[0]) / H < 0.12 and 0.6 < c[2] / H < 0.7 and max(sz) > 60:
        kind = "hip"
    elif abs(c[0]) / H < 0.12 and 0.40 < c[2] / H < 0.56 and max(sz) > 80:
        kind = "flap"
    elif c[1] / H > 0.02 and 0.5 < c[2] / H < 0.6:
        kind = "belttab"
    else:
        kind = "other"
    for fi in fl:
        region[fi] = kind
    legend.append((kind, n, c / H, sz))
# (2) the main surface: the lining first (a face that looks at the body, with a wall of the coat right outside it, the dress's own rule), then by bone and by height
bh = lambda n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:])                 # B holds only the bones tripo_common needs
SEGS = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
SEGS += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]
def away(q):
    best = None
    for a, b in SEGS:
        ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
        if best is None or d < best[0]:
            best = (d, (q - c) / max(d, 1e-12))
    return best[1]
tris = [tuple(t.vertices) for t in me.loop_triangles]
bvh = BVHTree.FromPolygons([tuple(q) for q in V], tris)
hz = float(bh("Hips")[2]); nz = float(bh("Neck")[2]); cz = float(bh("Spine2")[2])
R3 = coat.matrix_world.to_3x3()
n_lin = 0
for p in polys:
    if region[p.index] != "body" or find(rep[p.vertices[0]]) != main:
        continue
    c = np.array(p.center[:]); c = np.array((coat.matrix_world @ Vector(c))[:]); dv = away(c); nrm = np.array((R3 @ p.normal)[:])
    if nrm @ dv < -0.2 and bvh.ray_cast(Vector(c + dv * 1e-4), Vector(dv), 0.015 * H)[0] is not None:
        region[p.index] = "lining"; n_lin += 1; continue
    m_arm = float(np.mean([aw(v) for v in p.vertices])); hand = float(np.mean([sum(x for n, x in W[v].items() if "Hand" in n or "ForeArm" in n) for v in p.vertices]))
    if m_arm > 0.5:
        region[p.index] = "cuff" if (hand > 0.6 and min(np.linalg.norm(c - bh(sd + "Hand")) for sd in ("Left", "Right")) < 0.09 * H) else "sleeve"
    elif c[2] < hz:
        region[p.index] = "skirt"
    elif c[2] > nz - 0.01 * H:
        region[p.index] = "collar"
    elif c[2] > cz - 0.03 * H and nrm[1] < -0.3 and abs(c[0]) < 0.1 * H:
        region[p.index] = "lapel"
counts = {}
for r in region:
    counts[r] = counts.get(r, 0) + 1
print(f"[{TAG}] regions (faces): {counts}; lining {n_lin}")
for kind, n, c, sz in sorted(legend, key=lambda t: (t[0], -t[1])):
    print(f"[{TAG}]   loose {kind:8s} faces {n:3d} at x {c[0]:+.3f} y {c[1]:+.3f} z {c[2]:.3f} H, {sz[0]:.0f} x {sz[1]:.0f} x {sz[2]:.0f} mm")
# (3) the detail (grayscale, tileable) tiled over the UV square, then the regions painted on it
detail = tc.detail_tiled(DETAIL, RES, TILE)                                       # the grain, tiled over the UV square; the regions are painted on it below
img = np.empty((RES, RES, 3), np.float32); img[:] = rgb["body"]
drawn = np.zeros((RES, RES), bool)
rid = np.full((RES, RES), -1, np.int16); RIDS = {k: i for i, k in enumerate(COL)}
uvl = me.uv_layers[0]; n_nouv = 0
for p in polys:
    uv = np.array([uvl.data[l].uv[:] for l in p.loop_indices]); x = uv[:, 0] * RES; y = (1.0 - uv[:, 1]) * RES
    if np.ptp(x) < 1e-3 and np.ptp(y) < 1e-3:
        n_nouv += 1; continue
    for k in range(1, len(uv) - 1):
        ax, ay, bx, by, cx, cy = x[0], y[0], x[k], y[k], x[k + 1], y[k + 1]
        x0, x1 = int(max(0, np.floor(min(ax, bx, cx)))), int(min(RES - 1, np.ceil(max(ax, bx, cx))))
        y0, y1 = int(max(0, np.floor(min(ay, by, cy)))), int(min(RES - 1, np.ceil(max(ay, by, cy))))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den; w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den; w2 = 1 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        sub = img[y0:y1 + 1, x0:x1 + 1]; sub[inside] = rgb[region[p.index]]; drawn[y0:y1 + 1, x0:x1 + 1] |= inside
        rid[y0:y1 + 1, x0:x1 + 1][inside] = RIDS[region[p.index]]
imp_n = 0
if os.environ.get("CR_IMPRINTS"):                                              # the merged pieces (tripo_coat_merge): their projected triangles, in UV, in the colour of their kind
    import json
    for it in json.load(open(os.environ["CR_IMPRINTS"])):
        for tri in it["tris"]:
            x = [t[0] * RES for t in tri]; y = [(1.0 - t[1]) * RES for t in tri]
            x0, x1 = int(max(0, np.floor(min(x)))), int(min(RES - 1, np.ceil(max(x)))); y0, y1 = int(max(0, np.floor(min(y)))), int(min(RES - 1, np.ceil(max(y))))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            den = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
            if abs(den) < 1e-9:
                continue
            w0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / den; w1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / den; w2 = 1 - w0 - w1
            inside = (w0 >= -0.05) & (w1 >= -0.05) & (w2 >= -0.05)
            img[y0:y1 + 1, x0:x1 + 1][inside] = rgb[it["kind"]]; drawn[y0:y1 + 1, x0:x1 + 1] |= inside; imp_n += 1
    print(f"[{TAG}] {imp_n} imprint triangles painted")
# (4) EDGES (CR_EDGES, default on with the reference palette; Director 2026-11-06, the leather references: blacks, the trims and the edges
# telling the pieces apart): where two regions meet, or a UV island ends (a hem, a lapel's edge, a side seam), a dark groove and, just
# inside it, a soft catch light, so each piece reads as a cut panel of leather. Widths scale with CR_RES (2048 = the master).
EDGES = os.environ.get("CR_EDGES", "1" if os.environ.get("CR_PALETTE", "diag") == "ref" else "0") == "1"
if EDGES:
    sc_ = RES / 2048.0
    # only a trim against the cloth (body / skirt / sleeve / lining meet along jagged face rows, and the coat's UV islands are cut anywhere: no line)
    TRIM = np.array([k in ("collar", "lapel", "cuff", "cufftab", "button", "flap", "belttab") for k in COL])
    border = np.zeros((RES, RES), bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.roll(np.roll(rid, dy, 0), dx, 1)
        border |= drawn & (nb >= 0) & (TRIM[np.clip(rid, 0, None)] ^ TRIM[np.clip(nb, 0, None)])
    dist = np.full((RES, RES), 99, np.int16); dist[border] = 0; front = border.copy()
    for d_ in range(1, int(round(8 * sc_)) + 1):
        grow = np.zeros_like(front)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            grow |= np.roll(np.roll(front, dy, 0), dx, 1)
        grow &= drawn & (dist == 99); dist[grow] = d_; front = grow
    g = float(os.environ.get("CR_GROOVE", "0.55")); hl = float(os.environ.get("CR_CATCH", "1.30"))
    shade = np.ones((RES, RES), np.float32)
    shade[dist <= round(2 * sc_)] = g
    band = (dist > round(2 * sc_)) & (dist <= round(6 * sc_))
    shade[band] = hl
    img *= shade[:, :, None]
    print(f"[{TAG}] edges: {int(border.sum())} border texels, groove x{g}, catch light x{hl}")
for _ in range(6):                                                             # bleed the painted islands past their edges (filtering, mipmaps)
    grown = drawn.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        sh = np.roll(np.roll(drawn, dy, 0), dx, 1); src = np.roll(np.roll(img, dy, 0), dx, 1)
        take = sh & ~grown; img[take] = src[take]; grown |= take
    drawn = grown
out = np.clip(img * detail[:, :, None], 0, 1)
out8 = (out * 255 + 0.5).astype(np.uint8)
tc.write_png(os.environ["CR_MAP"], out8)
print(f"[{TAG}] wrote {os.environ['CR_MAP']} ({RES} px, detail x{TILE:g}); {n_nouv} faces without a UV (they read as body)")
