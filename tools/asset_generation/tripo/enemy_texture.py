"""The guard's painted maps (ENEMIES_MASTER_PLAN §12.14): a HEAD map and a UNIFORM map instead of five flat region colours.

Input: a light enemy from enemy_light.py (one material per region: Enemy_skin / _hair / _shirt / _trousers / _shoes / _hands), and
the Tripo source it was decimated from (unrigged, at rest, aligned with it).

Two maps, so a head and a uniform swap apart (2026-11-20):
- The HEAD map, <stem>_head.png (1024 x 1024), holds Tripo's head piece, whole. The face lies on the male Agent's FaceUV
  (face_uv_map.py), so his painted face master is the layout an enemy's face is drawn on (the Director, 2026-11-19). The neck
  hangs below the jaw line (_neck_layout). The Director paints this map by hand.
- The UNIFORM map, <stem>_body.png (2048 x 2048 since 2026-11-22), holds every other face. It is cut where a tailor sews, the
  Tripo source is baked onto it, and it is painted by Tripo's own pieces (enemy_uniform.py).

Once a map exists it is the Director's: a re-run keeps it and only rebuilds the GLB around it.
- ENEMY_TEX_FORCE=1 repaints both maps; ENEMY_REPAINT_BODY=1 repaints the uniform only.
- When the layout changes under a kept map, the map is CARRIED across triangle by triangle from the GLB being replaced.
  ENEMY_NO_CARRY=1 skips the carry: the maps already fit this layout.

Without a head map, the head is painted skin and hair. A 2048 x 2048 `<master>_face.png` beside the master is then dropped onto
FaceUV (ENEMY_FACE names another file); without it, a `<master>_face_guide.png` is written to draw on.

The GLB carries two meshes on one skeleton, Head (material Enemy_head) and Body (material Enemy_body). Each material holds a
512 x 512 copy of its map, a preview only: the game reads the full maps itself (ActorMesh3D `maps`).

    Blender -b -P enemy_texture.py -- <light.glb> <out.glb> <palette.json> <master.png> <source.glb> [paint.blend]

palette.json: the region colours of enemy_light.py plus "stripe", "buttons" and "laces" (optional, with defaults).
master.png: names the maps (<stem>_head.png and <stem>_body.png beside it); the file itself need not exist.
source.glb: the Tripo model the light one was decimated from, baked onto the uniform map.
paint.blend: a file for hand painting, the mesh at rest wearing both maps by path (Image > Save writes the map).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
import model_paths as mp  # where every model lives (ASSETS/MODELS layout)
import heapq
import json
import math
import os
import sys
from collections import defaultdict

import bmesh
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, out, palette_path, master_path = args[0], args[1], args[2], os.path.abspath(args[3])
source_glb = os.path.abspath(args[4])
paint_blend = os.path.abspath(args[5]) if len(args) > 5 else ""
FORCE = os.environ.get("ENEMY_TEX_FORCE", "") == "1"
REPAINT_BODY = os.environ.get("ENEMY_REPAINT_BODY", "") == "1"   # the uniform is painted afresh; the head map is kept (or carried)
HEAD_N = 1024        # the head map (on FaceUV: the Director's PSD is this size)
BODY_N = 2048        # the uniform map (2026-11-22: 2.8 times the density of the 1024 smart projection it replaced)
PREVIEW_N = 512      # each map's copy inside the GLB
TAG = "[enemy_texture]"


def rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


pal = json.load(open(palette_path))
C = {k: rgb(v) for k, v in pal.items()}
C.setdefault("stripe", rgb("#e8ecf2"))
C.setdefault("buttons", rgb("#2c568a"))
C.setdefault("laces", rgb("#0d0d0d"))

head_path = master_path.replace("_master.png", "_head.png")
body_path = master_path.replace("_master.png", "_body.png")
KEEP_HEAD = os.path.exists(head_path) and not FORCE
KEEP_BODY = os.path.exists(body_path) and not FORCE and not REPAINT_BODY


# The PREVIOUS layout, read from the GLB this run replaces (2026-11-20): when the layout changes under the Director's maps, his
# paint is carried across triangle by triangle (same rest geometry, matched by centroid), never lost or left misaligned.
def _old_layout(path: str):
    if not ((KEEP_HEAD or KEEP_BODY) and os.path.exists(path)):
        return None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for a in [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]:
        a.data.pose_position = "REST"
    P, U, M = [], [], []
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        d = o.data
        if not d.uv_layers:
            continue
        d.calc_loop_triangles()
        ud = d.uv_layers.active.data
        for t in d.loop_triangles:
            mat = d.materials[t.material_index].name if d.materials else ""
            if mat not in ("Enemy_head", "Enemy_body"):
                continue
            P.append([tuple(o.matrix_world @ d.vertices[v].co) for v in t.vertices])
            U.append([tuple(ud[li].uv) for li in t.loops])
            M.append(0 if mat == "Enemy_head" else 1)
    return np.array(P, np.float64), np.array(U, np.float64), np.array(M, np.int8)


OLD = None if os.environ.get("ENEMY_NO_CARRY", "") == "1" else _old_layout(out)   # 1: the maps already fit this layout
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
arm.data.pose_position = "REST"


def bone(name: str) -> np.ndarray:
    b = arm.data.bones["mixamorig:" + name]
    return np.array(arm.matrix_world @ b.head_local, dtype=np.float32)


B = {n: bone(n) for n in ("Neck", "Head")}
mw = mesh.matrix_world
mat_of = [m.name.replace("Enemy_", "") for m in mesh.data.materials]   # skin / hair = the head piece (enemy_light.py)
region_of_mat = ["skin" if r == "hands" else r for r in mat_of]

# The head takes the male Agent's FaceUV (face_uv_map.py with his params): the enemies share his silhouette, so his painted
# face master is the layout an enemy's face is drawn on (the Director, 2026-11-19), at half scale in the left square.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import face_uv_map as fm
import enemy_uniform as eu
FACEUV = json.load(open(os.environ.get("ENEMY_FACEUV", mp.agent("male", "textures", "male_faceuv.json"))))
# The enemy's head is not where the Agent's is (the FID guard's: 2.0 cm higher, 1.3 cm forward): FaceUV moves by the offset between
# the two nose tips, so the face's features land on the enemy's. The Agent's tip, measured on AGENT_MALE_LIGHT.glb at rest
# (2026-11-19): the head's most forward point above 0.84 m within 5 cm of the middle.
AGENT_NOSE = (-0.0040, -0.0684, 0.8965)
_hv = [mw @ v.co for v in mesh.data.vertices if (mw @ v.co).z > 0.84 and abs((mw @ v.co).x) < 0.05]
_nose = min(_hv, key=lambda c: c.y)
FACEUV = dict(FACEUV, xc=FACEUV["xc"] + (_nose.x - AGENT_NOSE[0]), yc=FACEUV["yc"] + (_nose.y - AGENT_NOSE[1]),
              z0=FACEUV["z0"] + (_nose.z - AGENT_NOSE[2]), z1=FACEUV["z1"] + (_nose.z - AGENT_NOSE[2]))
print(TAG, "FaceUV moved by the nose", tuple(round(a - b, 4) for a, b in zip(tuple(_nose), AGENT_NOSE)))

# --- UVs ---------------------------------------------------------------------------------------------------------------
bm = bmesh.new()
bm.from_mesh(mesh.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.verify()
# The HEAD map holds Tripo's head piece, whole (its faces are skin or hair, enemy_light.py), and nothing else; the body map the
# rest (2026-11-20). Its neck below the chin and the jaw's underside fall on the face's own texels on FaceUV's cylinder (the
# streaks of 2026-11-19), so they leave FaceUV and hang below the jaw line instead (_neck_layout, below).
CHIN_Z = _nose.z - 0.055
# FaceUV's axis runs just behind the throat (the guard's at y -0.022, the neck's front at -0.028): a face within a few centimetres
# of it that looks DOWN, the jaw's underside, is a sliver across a third of the map's width and shows as a flat triangle without
# texture under the chin (2026-11-20); those join the neck's band. The ones that look OUT, the jaw's sides beside the chin, are
# in the painted face and stay on FaceUV: the Director's red and blue test spots on the jaw's sides showed nowhere on the head
# while every near face left (2026-11-20). Measured on the guard: the underside's normals run z -0.76 to -0.99, the sides' -0.17 to
# -0.58. The chin's front and the lips start at 4.3 cm and stay on FaceUV.
NEAR_AXIS = 0.042
UNDER_JAW_NZ = -0.7
head_faces, neck_faces = set(), set()
for f in bm.faces:
    if mat_of[f.material_index] not in ("skin", "hair"):
        continue
    head_faces.add(f.index)
    c = mw @ f.calc_center_median()
    p0, p1, p2 = (mw @ lo.vert.co for lo in f.loops)
    nz = (p1 - p0).cross(p2 - p0).normalized().z
    # measured from the face's midline (the nose's x), not FaceUV's axis 4 mm aside, so both sides of the chin cut alike
    near = math.hypot(c.x - _nose.x, c.y - FACEUV["yc"]) < NEAR_AXIS and c.z < _nose.z - 0.03
    if c.z < CHIN_Z or (near and nz < UNDER_JAW_NZ):   # never every downward face under the nose: the lips' and the chin's undersides are seen
        neck_faces.add(f.index)
bm.to_mesh(mesh.data)
bm.free()

# the uniform's UVs: every face outside the head piece, cut where a tailor sews (enemy_uniform.py, 2026-11-22)
LAY = eu.layout(mesh, head_faces, arm, BODY_N)

bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(mesh.data)
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.verify()
VB = 0.004                                                              # the head square's foot (FaceUV's own clamp)
K_V = (1.0 - 2.0 * FACEUV["margin"]) / (FACEUV["z1"] - FACEUV["z0"])    # FaceUV's v per metre of height
NECK_AXIS = (float(B["Neck"][0] + B["Head"][0]) / 2.0, float(B["Neck"][1] + B["Head"][1]) / 2.0)


def _face_uv(P: np.ndarray) -> np.ndarray:
    """FaceUV of triangles P (T, 3, 3) as a face's loops get it: past the back seam / above the Agent's crown, the edge (hair)"""
    U = fm.tri_uv(P, FACEUV)
    U[..., 0] = np.minimum(U[..., 0], 0.999)
    U[..., 1] = np.clip(U[..., 1], VB, 0.996)
    return U


def _winding(U: np.ndarray) -> float:
    (ax, ay), (bx, by), (cx, cy) = U
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)


def _neck_layout(head_faces: set, neck_faces: set):
    """The neck HANGS BELOW THE JAW LINE on the head map (2026-11-20, the Director: "a imagem está correta, mas não existem os
    polígonos certos mapeados"). His map paints the skin under the jaw's outline, where no triangle read it, while the jaw's
    underside and the neck were drawn on a band of their own at the map's foot: the paint stopped dead along the jaw on the
    model. Now the neck is one piece with the face. The vertices of the seam between them (the jaw's lower border, then round
    the nape) keep their FaceUV texels on both sides, and the neck unrolls downward from that line into the painted area:
    - the seam must run one way across the map; where it turns back, the face triangle wedged into the neck there (two of its
      sides on the seam) joins the neck (on the guard: the neck's side under each jaw angle);
    - round the neck, a Tutte embedding with mean-value weights: the seam at its FaceUV u, the neck's open foot at the u the
      seam has at the same angle round the neck's axis, the cut down the nape on the map's two edges;
    - down the neck, a vertex hangs below the seam's curve at its own u by its distance from the seam in metres: FaceUV's own
      height scale where it leaves the seam, squeezed toward the map's foot below (the collar hides the lower neck),
      v = VB + A exp(-K_V d / A), A = the seam's v at that u minus VB;
    - a vertex that still turns a triangle over moves to the nearest point from which its whole ring is seen.
    Returns {face index: (3, 2) uv in head-square units} and the faces that joined the neck. Fails loudly when the neck is not
    an annulus under one seam, or when a triangle stays turned over or overlaps another."""
    neck = set(neck_faces)
    wid, pts = {}, []
    tri = {}
    for f in bm.faces:                       # the import splits vertices: weld them by position to read the topology
        if f.index not in head_faces:
            continue
        t = []
        for lo in f.loops:
            k = tuple(round(c, 6) for c in (mw @ lo.vert.co))
            if k not in wid:
                wid[k] = len(pts)
                pts.append(k)
            t.append(wid[k])
        tri[f.index] = tuple(t)
    X = np.array(pts, np.float64)
    fuv = {fi: _face_uv(X[np.array(t)][None])[0] for fi, t in tri.items()}
    e2f = defaultdict(list)
    for fi, t in tri.items():
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            e2f[(min(a, b), max(a, b))].append(fi)

    def seam_of(nk: set):
        """the seam as an ordered loop starting on FaceUV's back seam, u increasing; its uv (both ends: the start vertex)"""
        S = [e for e, fs in e2f.items() if len(fs) == 2 and ((fs[0] in nk) != (fs[1] in nk))]
        adj = defaultdict(list)
        for a, b in S:
            adj[a].append(b)
            adj[b].append(a)
        if not adj or any(len(n) != 2 for n in adj.values()):
            raise SystemExit(f"{TAG} the neck's seam with the face is not one simple loop")
        loop, prev = [S[0][0]], None
        while True:
            nxt = [n for n in adj[loop[-1]] if n != prev][0]
            if nxt == loop[0]:
                break
            prev = loop[-1]
            loop.append(nxt)
        if len(loop) != len(adj):
            raise SystemExit(f"{TAG} the neck's seam with the face is more than one loop")
        cu = defaultdict(list)
        for fi, t in tri.items():
            if fi not in nk:
                for k, w in enumerate(t):
                    cu[w].append(fuv[fi][k])
        spread = [np.ptp(np.array(cu[w])[:, 0]) for w in loop]
        if max(spread) < 0.5:
            raise SystemExit(f"{TAG} no vertex of the neck's seam lies on FaceUV's back seam")
        i0 = int(np.argmax(spread))
        loop = loop[i0:] + loop[:i0]
        if np.array(cu[loop[1]])[:, 0].min() > np.array(cu[loop[-1]])[:, 0].min():
            loop = [loop[0]] + loop[1:][::-1]
        c0 = np.array(cu[loop[0]])
        lo_, hi_ = c0[np.argmin(c0[:, 0])], c0[np.argmax(c0[:, 0])]
        suv = np.array([lo_] + [cu[w][0] for w in loop[1:]] + [hi_], np.float64)
        return loop, suv

    absorbed = []
    for _ in range(64):
        loop, suv = seam_of(neck)
        seq = loop + [loop[0]]
        ear = None
        for i in range(1, len(seq) - 1):
            ua, ub, uc = suv[i - 1, 0], suv[i, 0], suv[i + 1, 0]
            if (ub - ua) * (uc - ub) < 0:
                ear = next((fi for fi, t in tri.items() if fi not in neck and set(t) == {seq[i - 1], seq[i], seq[i + 1]}), None)
                if ear is not None:
                    break
        if ear is None:
            break
        neck.add(ear)
        absorbed.append(ear)
    loop, suv = seam_of(neck)
    if not np.all(np.diff(suv[:, 0]) > 0):
        raise SystemExit(f"{TAG} the neck's seam turns back across the map with no face to absorb: u {np.round(suv[:, 0], 3).tolist()}")
    start, seam = loop[0], set(loop)
    uL, uR, v0 = float(suv[0, 0]), float(suv[-1, 0]), float(suv[0, 1])
    # the neck must be one annulus under the seam: Euler characteristic 0, one piece, an open foot
    nv = set(w for fi in neck for w in tri[fi])
    ne = set(e for fi in neck for e in ((min(tri[fi][0], tri[fi][1]), max(tri[fi][0], tri[fi][1])),
                                         (min(tri[fi][1], tri[fi][2]), max(tri[fi][1], tri[fi][2])),
                                         (min(tri[fi][2], tri[fi][0]), max(tri[fi][2], tri[fi][0]))))
    foot = set(w for e, fs in e2f.items() if len(fs) == 1 and fs[0] in neck for w in e)
    if len(nv) - len(ne) + len(neck) != 0 or not foot:
        raise SystemExit(f"{TAG} the neck is not an annulus under the seam (chi {len(nv) - len(ne) + len(neck)}, foot {len(foot)})")
    nadj = defaultdict(set)
    for fi in neck:
        t = tri[fi]
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            nadj[a].add(b)
            nadj[b].add(a)
    # the cut: from the seam's back vertex down the nape to the foot, close to the back's midline
    x0 = X[start, 0]
    dist, prev, pq, end = {start: 0.0}, {}, [(0.0, start)], None
    while pq:
        dd, w = heapq.heappop(pq)
        if dd > dist[w]:
            continue
        if w in foot:
            end = w
            break
        for n in nadj[w]:
            if n in seam:
                continue
            c = dd + float(np.linalg.norm(X[n] - X[w])) + 2.0 * abs(X[n, 0] - x0)
            if c < dist.get(n, 1e9):
                dist[n], prev[n] = c, w
                heapq.heappush(pq, (c, n))
    if end is None:
        raise SystemExit(f"{TAG} no path down the nape from the seam to the neck's foot")
    cut = [end]
    while cut[-1] != start:
        cut.append(prev[cut[-1]])
    cut.reverse()
    cutset = set(cut[1:])
    side = {fi: int(X[np.array(tri[fi])].mean(0)[0] > x0) for fi in neck}     # 0: the figure's right, u from uL; 1: its left, u to uR
    # pinned (t, s): the seam on top, the cut on the map's edges, the foot at the seam's u for the same angle round the neck
    def phi(p):
        return math.degrees(math.atan2(p[0] - NECK_AXIS[0], -(p[1] - NECK_AXIS[1])))
    sp = np.array([phi(X[w]) for w in loop[1:]])
    o = np.argsort(sp)
    PHI = np.concatenate([[-180.0], sp[o], [180.0]])
    UPH = np.maximum.accumulate(np.concatenate([[uL], suv[1:-1, 0][o], [uR]]))
    arc = np.cumsum([0.0] + [float(np.linalg.norm(X[a] - X[b])) for a, b in zip(cut[:-1], cut[1:])])
    arc /= arc[-1]
    pin = {}
    for k, w in enumerate(loop[1:], 1):
        pin[(w, 0)] = pin[(w, 1)] = (suv[k, 0], 0.0)
    pin[(start, 0)], pin[(start, 1)] = (uL, 0.0), (uR, 0.0)
    for w, s in zip(cut[1:], arc[1:]):
        pin[(w, 0)], pin[(w, 1)] = (uL, float(s)), (uR, float(s))
    for w in foot:
        if (w, 0) not in pin:
            pin[(w, 0)] = pin[(w, 1)] = (float(np.interp(phi(X[w]), PHI, UPH)), 1.0)
    free = sorted(w for w in nv if (w, 0) not in pin)
    ix = {w: i for i, w in enumerate(free)}
    A = np.zeros((len(free), len(free)))
    rhs = np.zeros((len(free), 2))
    for fi in neck:
        t = tri[fi]
        for k in range(3):
            i, j, l = t[k], t[(k + 1) % 3], t[(k + 2) % 3]
            if i not in ix:
                continue
            for a, b in ((j, l), (l, j)):            # edge i-a, the angle at i between a and b
                e1, e2 = X[a] - X[i], X[b] - X[i]
                ang = math.acos(float(np.clip(e1 @ e2 / (np.linalg.norm(e1) * np.linalg.norm(e2)), -1.0, 1.0)))
                wgt = math.tan(ang / 2.0) / float(np.linalg.norm(e1))
                A[ix[i], ix[i]] += wgt
                if a in ix:
                    A[ix[i], ix[a]] -= wgt
                else:
                    rhs[ix[i]] += wgt * np.array(pin[(a, side[fi])])
    TS = np.linalg.solve(A, rhs) if free else np.zeros((0, 2))
    seg_a = np.array([X[w] for w in loop])
    seg_b = np.roll(seg_a, -1, 0)

    def hang(u: float, p: np.ndarray) -> float:
        ab = seg_b - seg_a
        tt = np.clip(((p - seg_a) * ab).sum(1) / np.maximum((ab * ab).sum(1), 1e-18), 0.0, 1.0)
        d = float(np.linalg.norm(seg_a + tt[:, None] * ab - p, axis=1).min())
        top = max(float(np.interp(u, suv[:, 0], suv[:, 1])) - VB, 1e-4)
        return VB + top * math.exp(-K_V * d / top)

    out = {}
    for fi in neck:
        row = []
        for w in tri[fi]:
            if w == start:
                row.append((uL if side[fi] == 0 else uR, v0))
            elif w in seam:
                row.append(tuple(suv[loop.index(w)]))
            elif w in cutset:
                u = uL if side[fi] == 0 else uR
                row.append((u, hang(u, X[w])))
            else:
                u = float(TS[ix[w], 0]) if w in ix else pin[(w, 0)][0]
                row.append((u, hang(u, X[w])))
        out[fi] = np.array(row, np.float64)
    # the winding the face's triangles have on the map; a neck triangle turned the other way moves its free vertex into its ring
    sign = 1.0 if sum(_winding(fuv[fi]) > 0 for fi in tri if fi not in neck) * 2 > len(tri) - len(neck) else -1.0

    def clip(poly, a, b, margin):
        n = np.array([-(b - a)[1], (b - a)[0]]) * sign
        n /= max(float(np.linalg.norm(n)), 1e-12)
        kept = []
        for i in range(len(poly)):
            p, q = poly[i], poly[(i + 1) % len(poly)]
            dp, dq = float((p - a) @ n) - margin, float((q - a) @ n) - margin
            if dp >= 0:
                kept.append(p)
            if (dp >= 0) != (dq >= 0):
                kept.append(p + (q - p) * (dp / (dp - dq)))
        return kept

    moved = []
    for _ in range(10):
        bad = [fi for fi in neck if _winding(out[fi]) * sign <= 1e-9]
        if not bad:
            break
        for fi in bad:
            if _winding(out[fi]) * sign > 1e-9:
                continue
            for w in sorted((w for w in tri[fi] if w not in seam and w not in cutset), key=lambda w: w in foot):
                ring = [(fj, tri[fj].index(w)) for fj in neck if w in tri[fj]]
                poly = [np.array(p, np.float64) for p in ((-1.0, -1.0), (2.0, -1.0), (2.0, 2.0), (-1.0, 2.0))]
                for fj, k in ring:
                    poly = clip(poly, out[fj][(k + 1) % 3], out[fj][(k + 2) % 3], 0.002)
                    if len(poly) < 3:
                        break
                if len(poly) < 3:
                    continue
                P = np.array(poly)
                cur = out[fi][tri[fi].index(w)].copy()
                best = min((P[i] + np.clip((cur - P[i]) @ (P[(i + 1) % len(P)] - P[i]) /
                                           max(float((P[(i + 1) % len(P)] - P[i]) @ (P[(i + 1) % len(P)] - P[i])), 1e-12), 0.0, 1.0)
                            * (P[(i + 1) % len(P)] - P[i]) for i in range(len(P))), key=lambda c: float(np.linalg.norm(c - cur)))
                best = best + 0.15 * (P.mean(0) - best)
                for fj, k in ring:
                    out[fj][k] = best
                moved.append(w)
                break
    bad = [fi for fi in neck if _winding(out[fi]) * sign <= 1e-9]
    if bad:
        raise SystemExit(f"{TAG} {len(bad)} neck triangles stay turned over on the head map: {bad}")
    # nothing of the neck may cover another triangle of the head map (FaceUV's own folds, the nose's underside, are not this one's)
    N = 1024
    cover = {0: np.zeros((N, N), np.int16), 1: np.zeros((N, N), np.int16)}
    for fi in tri:
        Pq = (out[fi] if fi in neck else fuv[fi]) * N
        x_0, y_0 = np.floor(Pq.min(0)).astype(int)
        x_1, y_1 = np.ceil(Pq.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(max(x_0, 0), min(x_1, N - 1) + 1) + 0.5, np.arange(max(y_0, 0), min(y_1, N - 1) + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = Pq
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        inside = (l0 > 0.02) & (l1 > 0.02) & (1.0 - l0 - l1 > 0.02)
        cover[int(fi in neck)][ys[inside].astype(int), xs[inside].astype(int)] += 1
    over = int(((cover[1] > 1) | ((cover[1] > 0) & (cover[0] > 0))).sum())
    if over:
        raise SystemExit(f"{TAG} the neck overlaps the head map on {over} texels")
    print(TAG, f"neck below the jaw line: seam {len(loop)} vertices, {len(absorbed)} face triangles joined the neck, cut "
          f"{len(cut)} vertices down the nape, {len(moved)} vertices moved into their ring, {int((cover[1] > 0).sum())} texels")
    return out, absorbed


NECK_UV, _absorbed = _neck_layout(head_faces, neck_faces)
neck_faces |= set(_absorbed)
for f in bm.faces:
    if f.index not in head_faces:
        continue                                 # the uniform's, laid out above
    if f.index in neck_faces:
        U = NECK_UV[f.index]
    else:
        U = _face_uv(np.array([[tuple(mw @ lo.vert.co) for lo in f.loops]], np.float64))[0]
    for lo, (u, v) in zip(f.loops, U):
        lo[uv].uv = (min(float(u), 0.999), min(max(float(v), VB), 0.996))
bmesh.update_edit_mesh(mesh.data)
bpy.ops.object.mode_set(mode="OBJECT")

# --- the head map: each texel's position, normal and region ------------------------------------------------------------------
me = mesh.data
me.calc_loop_triangles()
if len(me.loop_triangles) != len(me.polygons):     # a texel's triangle (loop_triangles' order) is its face (polygons' order)
    raise SystemExit(f"{TAG} the mesh is not triangulated: {len(me.loop_triangles)} triangles, {len(me.polygons)} faces")
uvd = me.uv_layers.active.data
N = HEAD_N
pos = np.zeros((N, N, 3), np.float32)
nrm = np.zeros((N, N, 3), np.float32)
reg = np.full((N, N), -1, np.int16)
tid = np.full((N, N), -1, np.int32)       # the triangle each texel belongs to (loop_triangles' order), and where in it
lam_of = np.zeros((N, N, 3), np.float32)
vco = np.array([tuple(mw @ v.co) for v in me.vertices], np.float32)
rot = mw.to_3x3()
vno = np.array([tuple((rot @ v.normal).normalized()) for v in me.vertices], np.float32)
REGIONS = ("skin", "hair", "shirt", "trousers", "shoes")
for t in me.loop_triangles:
    if t.polygon_index not in head_faces:
        continue
    puv = np.array([uvd[li].uv for li in t.loops], np.float32) * N
    x0, y0 = np.floor(puv.min(0)).astype(int) - 1
    x1, y1 = np.ceil(puv.max(0)).astype(int) + 1
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, N - 1), min(y1, N - 1)
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = puv
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        continue
    l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    l2 = 1.0 - l0 - l1
    inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
    if not inside.any():
        continue
    vi = list(t.vertices)
    lam = np.stack([l0, l1, l2], -1)[inside]
    yy, xx = (ys[inside] - 0.5).astype(int), (xs[inside] - 0.5).astype(int)
    pos[yy, xx] = lam @ vco[vi]
    nn = lam @ vno[vi]
    nrm[yy, xx] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
    reg[yy, xx] = REGIONS.index(region_of_mat[t.material_index])
    tid[yy, xx] = t.index
    lam_of[yy, xx] = lam

# --- the head map's generated paint: skin and a short crop of hair (the Director's map replaces it, below) ---------------------
img = np.zeros((N, N, 3), np.float32)
X, Y, Z = pos[..., 0], pos[..., 1], pos[..., 2]
SK, HA = REGIONS.index("skin"), REGIONS.index("hair")
top = float(Z[reg >= 0].max())
head = (reg == SK) | (reg == HA)
# the hairline: a smooth function of the angle round the head, low at the nape, high on the forehead
th = np.arctan2(X - float(B["Head"][0]), -(Y - float(B["Head"][1])))
line = top - 0.036 - 0.045 * (1.0 - np.cos(th)) / 2.0
hair = head & (Z > line)
img[head] = C["skin"]
img[hair] = C["hair"]


# --- bleed past the islands so mip levels and bilinear filtering do not read black ------------------------------------------
def _bleed() -> None:
    filled = reg >= 0
    for _ in range(6):
        acc = np.zeros_like(img)
        cnt = np.zeros((N, N, 1), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sf = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(img, (dy, dx), (0, 1)) * sf[..., None]
            cnt += sf[..., None]
        grow = (~filled) & (cnt[..., 0] > 0)
        img[grow] = acc[grow] / cnt[grow]
        filled = filled | grow


_bleed()


def _load_map(path: str, n: int = 0) -> np.ndarray:
    """a square map as (n, n, 3) floats, row 0 = v 0; n = 0 takes the file's own size"""
    _m = bpy.data.images.load(path)
    w, h = tuple(_m.size)
    if w != h or (n and w != n):
        hint = " (a uniform map of an older layout: ENEMY_REPAINT_BODY=1 paints it afresh)" if path == body_path else ""
        raise SystemExit(f"{TAG} {path}: {w} x {h}, expected {n or 'a square'}{hint}")
    a = np.empty(w * h * 4, np.float32)
    _m.pixels.foreach_get(a)
    bpy.data.images.remove(_m)
    return a.reshape(h, w, 4)[..., :3].copy()


def _write_map(path: str, a: np.ndarray) -> None:
    n = a.shape[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = bpy.data.images.new(os.path.basename(path), n, n)
    im.pixels.foreach_set(np.concatenate([np.clip(a, 0, 1), np.ones((n, n, 1), np.float32)], -1).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    print(TAG, "wrote", path)


def _carry(old, maps, tid_map: np.ndarray, pos_map: np.ndarray):
    """the Director's paint onto this run's layout, for one map's texels (`tid_map`: each texel's triangle, -1 empty). Each texel
    finds its triangle's twin in the old GLB (same rest geometry, nearest centroid) and reads the old map that twin lay on
    (maps[0] the head's, maps[1] the uniform's, each at its own size; None: not read) where that triangle's point was.
    Returns the colours, the texels (ys, xs), the old map each one's twin lay on, which ones were read, and how many of this
    map's triangles found no twin (they keep the generated paint)."""
    from mathutils.kdtree import KDTree
    P, U, M = old
    cen = P.mean(1)
    kd = KDTree(len(cen))
    for i, c in enumerate(cen):
        kd.insert(c, i)
    kd.balance()
    tris = me.loop_triangles
    used = np.unique(tid_map[tid_map >= 0])
    match = np.full(len(tris), -1, np.int64)
    for ti in used.tolist():
        _co, j, d = kd.find(vco[list(tris[ti].vertices)].mean(0))
        if d < 1e-4:
            match[ti] = j
    on = tid_map >= 0
    on[on] = match[tid_map[on]] >= 0
    ys, xs = np.nonzero(on)
    j = match[tid_map[ys, xs]]
    q = pos_map[ys, xs].astype(np.float64)
    a, b, c = P[j, 0], P[j, 1], P[j, 2]
    v0, v1, v2 = b - a, c - a, q - a
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
    l1 = (d11 * d20 - d01 * d21) / den
    l2 = (d00 * d21 - d01 * d20) / den
    lam = np.clip(np.stack([1 - l1 - l2, l1, l2], 1), 0.0, 1.0)
    lam /= lam.sum(1, keepdims=True)
    ouv = (lam[:, :, None] * U[j]).sum(1)
    col = np.zeros((len(j), 3), np.float32)
    got = np.zeros(len(j), bool)
    for mi, src_map in enumerate(maps):
        sel = M[j] == mi
        if src_map is None or not sel.any():
            continue
        n = src_map.shape[0]
        sx = np.clip((ouv[sel, 0] * n).astype(int), 0, n - 1)
        sy = np.clip((ouv[sel, 1] * n).astype(int), 0, n - 1)
        col[sel] = src_map[sy, sx]
        got[sel] = True
    return col, ys, xs, M[j], got, int((match[used] < 0).sum())


# The head map is the Director's once it exists (2026-11-19): he edits it in Photopea, Godot reimports it and the game reads it
# (ActorMesh3D `maps`); this script then only rebuilds the GLB around it. ENEMY_TEX_FORCE=1 repaints it, losing his edits.
if KEEP_HEAD:
    his = _load_map(head_path, HEAD_N)
    if OLD is None:
        img = his
        print(TAG, "kept the head map (the Director's):", head_path)
    else:
        col, ys, xs, src_of, got, lost = _carry(OLD, (his, None), tid, pos)
        img[ys[got], xs[got]] = col[got]
        # the head piece's neck that an old layout painted on the body map: skin, the median of the lower face
        low_face = (reg == SK) & (tid >= 0) & (Z > CHIN_Z) & (Z < _nose.z - 0.02)
        low_face &= ~np.isin(tid, [t.index for t in me.loop_triangles if t.polygon_index in neck_faces])
        tone = np.median(img[low_face], 0) if low_face.any() else C["skin"]
        img[ys[src_of == 1], xs[src_of == 1]] = tone
        # the back of the neck, which the old rules painted as the collar on the head map itself: closer to the shirt's colour
        # than to his skin, it takes the skin (or the hair where the nape's hair is)
        cc = img[ys, xs]
        shirtish = np.linalg.norm(cc - C["shirt"], axis=1) < np.linalg.norm(cc - tone, axis=1)
        img[ys[shirtish], xs[shirtish]] = np.where((reg[ys[shirtish], xs[shirtish]] == HA)[:, None], C["hair"], tone)
        _bleed()
        print(TAG, f"carried the head map onto this layout ({lost} triangles without a twin keep the generated paint)")
else:
    # the face: the Director's own 2048 x 2048 image on the male Agent's FaceUV layout (<master>_face.png beside the master),
    # dropped onto the head map at half size; without it the head keeps the generated skin and hair, and the map is written out
    # at full size as the guide to draw the face on (<master>_face_guide.png)
    face_path = os.path.abspath(os.environ.get("ENEMY_FACE", master_path.replace("_master.png", "_face.png")))   # ENEMY_FACE: another file
    if os.path.exists(face_path):
        fimg = bpy.data.images.load(face_path)
        if tuple(fimg.size) != (2 * N, 2 * N):
            fimg.scale(2 * N, 2 * N)
        f = np.array(fimg.pixels[:], np.float32).reshape(2 * N, 2 * N, 4)[..., :3]
        keep = ~((reg == SK) | (reg == HA) | (reg < 0))   # only the head piece takes the face
        face = f.reshape(N, 2, N, 2, 3).mean((1, 3))
        img[~keep] = face[~keep]
        img[hair] = C["hair"]          # the crown: a face image that paints only the hairline band still gets a full crop
        # the clamped edges (the back seam's column, the crown's row) are hair above the nape
        m = FACEUV["margin"]
        v_nape = m + (top - 0.081 - FACEUV["z0"]) / (FACEUV["z1"] - FACEUV["z0"]) * (1.0 - 2.0 * m)
        img[int(v_nape * N):, N - 10:] = C["hair"]
        img[N - 12:, :] = C["hair"]
        print(TAG, "face from", face_path)
        bpy.data.images.remove(fimg)
    else:
        g = bpy.data.images.new("guide", 2 * N, 2 * N)
        up = np.repeat(np.repeat(img, 2, 0), 2, 1)
        g.pixels = np.concatenate([np.clip(up, 0, 1), np.ones((2 * N, 2 * N, 1), np.float32)], -1).ravel()
        g.filepath_raw = master_path.replace("_master.png", "_face_guide.png"); g.file_format = "PNG"; g.save()
        print(TAG, "no face yet; guide", g.filepath_raw)
if not KEEP_HEAD or OLD is not None:   # a carried layout rewrites his map in place (backups: git)
    _write_map(head_path, img)

# --- the uniform map (enemy_uniform.py): kept, or baked from the Tripo source and painted (then his paint carried onto it) -----
if KEEP_BODY and OLD is None:
    body = _load_map(body_path, BODY_N)
    print(TAG, "kept the uniform map (the Director's):", body_path)
else:
    UTEX = eu.raster(mesh, LAY)
    eu.stats(mesh, LAY, UTEX)
    body = eu.paint(UTEX, LAY, eu.bake(mesh, LAY, source_glb), C, arm)
    if KEEP_BODY:
        # the uniform's triangles were never on the head map (the head piece alone is, 2026-11-20): only the old uniform is read
        col, ys, xs, _src, got, lost = _carry(OLD, (None, _load_map(body_path)), UTEX.fid, UTEX.pos)
        body[ys[got], xs[got]] = col[got]
        body = eu.nearest_fill(body, UTEX.fid >= 0)
        print(TAG, f"carried the uniform map onto this layout ({lost} triangles without a twin keep the generated paint)")
if not KEEP_BODY or OLD is not None:
    _write_map(body_path, body)

# --- two materials, each holding a 512 x 512 copy of its map (a preview: the game reads the maps themselves) ----------------
# Split 2026-11-20 (the Director): a head's map and a uniform's map are swapped apart (N faces x M uniforms, no N x M atlases).
# The copy stays 512 for the 2048 uniform too: Godot extracts it uncompressed and keeps it loaded with the scene.
uvl = me.uv_layers.active.data
mats = []
for name, sq in (("Enemy_head", img), ("Enemy_body", body)):
    k = sq.shape[0] // PREVIEW_N
    game = bpy.data.images.new(name.lower() + "_map", PREVIEW_N, PREVIEW_N)
    small = sq.reshape(PREVIEW_N, k, PREVIEW_N, k, 3).mean((1, 3))
    game.pixels.foreach_set(np.concatenate([np.clip(small, 0, 1), np.ones((PREVIEW_N, PREVIEW_N, 1), np.float32)], -1).ravel())
    game.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = game
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    mats.append((mat, tex))
me.materials.clear()
for mat, _t in mats:
    me.materials.append(mat)
outside = 0
for p in me.polygons:
    p.material_index = 0 if p.index in head_faces else 1
    for li in p.loop_indices:
        u, v = uvl[li].uv
        outside += not (0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)
if outside:
    raise SystemExit(f"{TAG} {outside} face corners lie outside their map")
# the head and the uniform are two meshes on one skeleton (2026-11-20): a head is swapped on its own, map and mesh
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.mesh.separate(type="MATERIAL")
for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]:
    ob.name = ob.data.name = "Head" if ob.active_material and ob.active_material.name == "Enemy_head" else "Body"
arm.data.pose_position = "POSE"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True)
print(TAG, "wrote", out)

if paint_blend:
    for (mat, tex), path in zip(mats, (head_path, body_path)):
        tex.image = bpy.data.images.load(path)                  # by path: Image > Save writes the map
    arm.data.pose_position = "REST"
    bpy.ops.wm.save_as_mainfile(filepath=paint_blend)
    print(TAG, "paint file", paint_blend)
