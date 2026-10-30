# tripo_waist.py — rebuild the WAIST of a base edited by hand (ACTOR D86: <NAME>_edit.blend, a belt GIVEN in the file as Outfit_Belt) so the
# shirt and the trousers never show through the belt or each other in motion. Director, 2026-10-30: "se a gente fizer algo assim com as
# calças [a mannequin's legs], mais a camisa cobrindo a cintura, o problema acaba"; "só queremos garantir que não vai dar nenhum problema
# gritante depois".
# Why: on MALE_BASE_edit the shirt's hem and the trousers' top both ended, RAGGED, right at the belt's top edge (no overlap to hide a slip),
# the trousers came as two halves overlapping in a flap at the back (the seam opened in every deep step), and holes had been closed by
# stretching their rims by hand. Measured with tripo_waist_check.py over every frame of both clips: cloth through the belt 296 (dive) and
# 1721 (heart_pose) vertex-frames, trousers through the shirt 2735 and 4012; after this script 0 everywhere.
# What it does, in the belt's own frame (BeltFrame: h along its axis, r out from it; lengths in metres, a ~1 m figure):
# (1) SHIRT: cut clean CUT_UP above the belt's top edge and carried down UNDER the belt as a plain band (4 rings, UVs read off the old shirt
#     inside one UV island per face) to a hem at HEM_AT of the belt's height, C_SHIRT inside its inner face. Under the belt it takes the
#     belt's weights, back to its own over SHIRT_WUP above it: the Spine joint sits AT the belt's top edge, and a shirt that leaves the belt
#     there swings ~4 cm down over it when the back arches (the dive's flight). Tripo's normals are kept wherever the shirt did not move.
# (2) TROUSERS: the parts joined into ONE closed mannequin (holes and openings filled, a plug up to TOP_UP above the belt inside the shirt,
#     voxel remesh: no seam, nothing inside), decimated to TRIS; under the belt C_TROU inside it (D_IN inside the shirt above the hem),
#     returning to their own shape over FALL below it; weights read off the old trousers, smoothed over the hips and around where the old
#     halves met (their weights jumped there: each half followed its own leg), the belt's under it and the shirt's above it; Tripo's
#     normals kept where the new skin lies on the old one, except near the old seam and the waist.
# Env: WAIST_OUT (output .blend; default <input>_waist.blend; the GLB is written beside it with every clip, in POSE), WAIST_SHIRT
# (default tripo_part_3), WAIST_TROUSERS (comma list, default tripo_part_5,tripo_part_6), WAIST="KEY=value,..." overrides P below.
# Usage: blender -b ASSETS/MODELS/MALE_BASE_edit.blend -P tripo_waist.py     (never writes the input)
import heapq, math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
from mathutils.kdtree import KDTree

TAG = "tripo_waist"
E0, E1_, E2_ = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def smooth(x):
    x = min(1.0, max(0.0, x)); return x * x * (3 - 2 * x)


def norm_top(acc, top=4):
    it = sorted(((g, w) for g, w in acc.items() if w > 1e-6), key=lambda t: -t[1])[:top]
    s = sum(w for g, w in it) or 1.0
    return {g: w / s for g, w in it}


def mix(ws, fs):
    acc = {}
    for w, f in zip(ws, fs):
        if f > 0:
            for g, x in w.items():
                acc[g] = acc.get(g, 0.0) + x * f
    return norm_top(acc)


def islands(me):
    """UV island id per polygon: faces sharing an edge whose two corners carry the same UVs on both sides"""
    bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.active
    par = list(range(len(bm.faces)))

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]; x = par[x]
        return x

    def uv_at(l, v):
        return l[uvl].uv if l.vert == v else l.link_loop_next[uvl].uv
    if uvl is not None:
        for e in bm.edges:
            ls = e.link_loops
            if len(ls) == 2 and all((uv_at(ls[0], v) - uv_at(ls[1], v)).length < 1e-5 for v in e.verts):
                a, b = find(ls[0].face.index), find(ls[1].face.index)
                if a != b:
                    par[a] = b
    out = [find(i) for i in range(len(bm.faces))]
    bm.free(); return out


class Src:
    """a rest-pose source surface (world space, one or more objects) to read weights, UVs and normals off: nearest point, barycentric.
    UVs are read inside ONE island per face (the island of the source face nearest its centre): Tripo's atlas is a patchwork of small
    islands, and a face whose corners read two islands smears a strip of the atlas across itself"""

    def __init__(self, objs):
        self.V, self.W, self.T = [], [], []          # T: (3 vertex indices, 3 UVs, 3 corner normals, island)
        for k, o in enumerate(objs):
            me = o.data; M = o.matrix_world; R = M.to_3x3(); base = len(self.V)
            self.V += [M @ v.co for v in me.vertices]
            names = [g.name for g in o.vertex_groups]
            self.W += [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-6} for v in me.vertices]
            uvd = me.uv_layers.active.data if me.uv_layers.active else None
            cn = [(R @ Vector(x.vector)).normalized() for x in me.corner_normals]
            isl = islands(me)
            me.calc_loop_triangles()
            for t in me.loop_triangles:
                uv = [Vector((uvd[l].uv[0], uvd[l].uv[1], 0.0)) if uvd else Vector() for l in t.loops]
                self.T.append(([base + i for i in t.vertices], uv, [cn[l] for l in t.loops], (k, isl[t.polygon_index])))
        self.bvh = BVHTree.FromPolygons(self.V, [t[0] for t in self.T])
        by = {}
        for i, t in enumerate(self.T):
            by.setdefault(t[3], []).append(i)
        self.isl = {k: (BVHTree.FromPolygons(self.V, [self.T[i][0] for i in ids]), ids) for k, ids in by.items()}

    def bary(self, ti, p):
        a, b, c = (self.V[i] for i in self.T[ti][0])
        w = [max(0.0, x) for x in barycentric_transform(p, a, b, c, E0, E1_, E2_)]; s = sum(w) or 1.0
        return [x / s for x in w]

    def weights(self, p):
        loc, _, ti, _ = self.bvh.find_nearest(p); acc = {}
        for vi, x in zip(self.T[ti][0], self.bary(ti, loc)):
            for g, w in self.W[vi].items():
                acc[g] = acc.get(g, 0.0) + w * x
        return norm_top(acc)

    def normal(self, p):
        loc, _, ti, d = self.bvh.find_nearest(p)
        return sum((n * x for n, x in zip(self.T[ti][2], self.bary(ti, loc))), Vector()).normalized(), d

    def face_uvs(self, corners):
        ti = self.bvh.find_nearest(sum(corners, Vector()) / len(corners))[2]
        bvh, ids = self.isl[self.T[ti][3]]; out = []
        for p in corners:
            loc, _, j, _ = bvh.find_nearest(p); tj = ids[j]
            u = sum((uv * x for uv, x in zip(self.T[tj][1], self.bary(tj, loc))), Vector()); out.append((u.x, u.y))
        return out


class BeltFrame:
    """the belt ring's own frame: centre C, axis N (PCA), radial angle theta in (E1, E2), height h along N; per sector (NS around) the
    belt's bottom and top edges lo / hi. `up`: a direction N must agree with (the chest from the belt); without it world +Z, which is
    only right while the body stands (lying or upside down in the dive it flipped, and 'above the belt' read as below it)"""

    def __init__(self, pts, ns=72, up=None):
        A = np.array([p[:] for p in pts]); c = A.mean(0)
        _, _, vt = np.linalg.svd(A - c); u = np.array(up[:]) if up is not None else np.array([0.0, 0, 1])
        n = vt[2] * (1 if vt[2] @ u > 0 else -1)
        e1 = np.array([1.0, 0, 0]) - n[0] * n; e1 /= np.linalg.norm(e1)
        self.C, self.N, self.E1, self.E2 = Vector(c), Vector(n), Vector(e1), Vector(np.cross(n, e1))
        self.ns = ns; lo = np.full(ns, 1e9); hi = np.full(ns, -1e9)
        for p in pts:
            th, h, r = self.polar(p); k = int(round(th % (2 * math.pi) / (2 * math.pi) * ns)) % ns
            lo[k] = min(lo[k], h); hi[k] = max(hi[k], h)
        for arr in (lo, hi):                               # an empty sector takes its nearest neighbour's
            good = np.where(np.abs(arr) < 1e8)[0]
            for k in np.where(np.abs(arr) >= 1e8)[0]:
                arr[k] = arr[good[np.argmin(np.minimum(abs(good - k), ns - abs(good - k)))]]
        self.lo, self.hi = lo, hi

    def polar(self, p):
        d = p - self.C; h = d.dot(self.N); q = d - h * self.N
        return math.atan2(q.dot(self.E2), q.dot(self.E1)), h, q.length

    def dir(self, th):
        return math.cos(th) * self.E1 + math.sin(th) * self.E2

    def at(self, th, h, r):
        return self.C + self.N * h + self.dir(th) * r

    def sect(self, th):
        x = th % (2 * math.pi) / (2 * math.pi) * self.ns; k0 = int(math.floor(x)) % self.ns
        return k0, (k0 + 1) % self.ns, x - math.floor(x)

    def band(self, th):
        k0, k1, t = self.sect(th)
        return self.lo[k0] * (1 - t) + self.lo[k1] * t, self.hi[k0] * (1 - t) + self.hi[k1] * t


def hits(bvh, o, d, far=0.5):
    """every hit distance along a ray, nearest first"""
    out, s = [], 0.0
    for _ in range(16):
        hit = bvh.ray_cast(o + d * (s + 1e-5), d, far - s)
        if hit[0] is None:
            break
        s = s + 1e-5 + hit[3]; out.append(s)
    return out


def fail(msg):
    print(f"[{TAG}] ERROR: {msg}"); sys.exit(1)


def parts():
    """(armature, shirt, [trousers parts], belt) of the open .blend, by the env's names"""
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    names = [os.environ.get("WAIST_SHIRT", "tripo_part_3")] + os.environ.get("WAIST_TROUSERS", "tripo_part_5,tripo_part_6").split(",") \
        + ["Outfit_Belt"]
    missing = [n for n in names if n not in bpy.data.objects]
    if len(arms) != 1 or missing:
        fail(f"{bpy.data.filepath}: expected one armature and the meshes {names}; {len(arms)} armatures, missing {missing}")
    objs = [bpy.data.objects[n] for n in names]
    keyed = [o.name for o in objs if o.data.shape_keys]
    if keyed:
        fail(f"{keyed} carry shape keys: their rest mesh is not their base mesh")
    return arms[0], objs[0], objs[1:-1], objs[-1]


def main():
    P = dict(C_SHIRT=0.002,   # the shirt band this far inside the belt's inner face
             C_TROU=0.0025,   # the trousers under the belt, below the shirt's new hem
             D_IN=0.003,      # the trousers this far inside the shirt
             CUT_UP=0.006,    # the shirt cut this far above the belt's top edge (its highest point)
             HEM_AT=0.4,      # the shirt's new hem: this fraction of the belt's height up from its bottom edge
             TOP_UP=0.025,    # the trousers reach this far above the belt's top edge, inside the shirt
             FALL=0.015,      # below the belt the trousers return to their own shape over this height
             WFALL=0.015,     # ... and to their own weights over this one
             SHIRT_WUP=0.035, # above the belt the shirt returns to its own weights over this height
             VOXEL=0.0025,    # the remesh (4 mm lost the pocket and fly; Tripo's normals bring them back as shading, below)
             TRIS=3600,       # the trousers' budget (the two halves were 3685)
             SMOOTH_IT=6,     # Taubin passes over the hips and the plug: the old waist's dents and folds come through the remesh
             WSMOOTH_IT=4,    # weight-smoothing passes over the hips and around the old seam
             SEAM_FADE=0.015) # Tripo's normals fade back in over this much surface walked from the old seam
    for kv in os.environ.get("WAIST", "").split(","):
        if kv:
            k, v = kv.split("=")
            if k not in P:
                fail(f"WAIST names an unknown key {k}; the keys are {sorted(P)}")
            P[k] = float(v)
    out = os.environ.get("WAIST_OUT") or bpy.data.filepath.replace(".blend", "_waist.blend")
    if os.path.abspath(out) == os.path.abspath(bpy.data.filepath):
        fail("WAIST_OUT is the input: this script never writes its source")
    arm, SH, TR, BELT = parts()
    arm.data.pose_position = 'REST'; bpy.context.view_layer.update()

    BV = [BELT.matrix_world @ v.co for v in BELT.data.vertices]
    F = BeltFrame(BV); NS = F.ns
    bvh_belt = BVHTree.FromPolygons(BV, [p.vertices[:] for p in BELT.data.polygons])
    src_sh, src_tr, src_belt = Src([SH]), Src(TR), Src([BELT])
    bvh_parts = [Src([o]).bvh for o in TR]
    bnd = []                                             # the old trousers' open edges (their seam, their ragged top), every mm
    for o in TR:
        M = o.matrix_world; bm_ = bmesh.new(); bm_.from_mesh(o.data)
        for e in bm_.edges:
            if e.is_boundary:
                a, b = M @ e.verts[0].co, M @ e.verts[1].co; k = max(1, int((b - a).length / 0.001))
                bnd += [a.lerp(b, i / k) for i in range(k + 1)]
        bm_.free()
    kd = KDTree(max(1, len(bnd)))
    for i, p in enumerate(bnd):
        kd.insert(p, i)
    kd.balance()
    print(f"[{TAG}] belt axis {tuple(round(x, 3) for x in F.N)}, its edges lo {F.lo.min():.4f}..{F.lo.max():.4f} "
          f"hi {F.hi.min():.4f}..{F.hi.max():.4f} (belt frame)")

    # the belt's inner face r_in(theta, h) and the old shirt above the belt r_s(theta, h), sampled per sector
    TS = [0.03, 0.25, 0.5, 0.75, 0.97]; SO = [0.0, 0.003, 0.006, 0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04]
    RIN = np.full((NS, len(TS)), np.nan); RS = np.full((NS, len(SO)), np.nan)
    for k in range(NS):
        d = F.dir(2 * math.pi * k / NS)
        for j, t in enumerate(TS):
            hs = hits(bvh_belt, F.C + F.N * (F.lo[k] + t * (F.hi[k] - F.lo[k])), d)
            RIN[k, j] = hs[0] if hs else np.nan
        for j, s in enumerate(SO):
            hs = hits(src_sh.bvh, F.C + F.N * (F.hi[k] + s), d)
            RS[k, j] = hs[0] if hs else np.nan
    for tab in (RIN, RS):
        for j in range(tab.shape[1]):
            col = tab[:, j]; good = np.where(~np.isnan(col))[0]
            if len(good) == 0:
                fail("a ray column out of the belt's axis met nothing: the belt does not ring the waist")
            for k in np.where(np.isnan(col))[0]:
                col[k] = col[good[np.argmin(np.minimum(abs(good - k), NS - abs(good - k)))]]
    H_CUT = float(F.hi.max()) + P['CUT_UP']

    def tab_at(tab, xs, th, x_of):
        k0, k1, t = F.sect(th)
        return float(np.interp(x_of(k0), xs, tab[k0])) * (1 - t) + float(np.interp(x_of(k1), xs, tab[k1])) * t

    def r_in(th, h):
        return tab_at(RIN, TS, th, lambda k: (h - F.lo[k]) / max(F.hi[k] - F.lo[k], 1e-6))

    def r_s(th, h):
        return tab_at(RS, SO, th, lambda k: h - F.hi[k])

    def r_shirt(th, h, top=None):
        """the shirt's radius after the rebuild; `top`: the cut loop vertex's own radius, so the band starts exactly on it"""
        lo, hi = F.band(th)
        if h >= H_CUT:
            return r_s(th, h)
        a = r_in(th, hi) - P['C_SHIRT']
        if h >= hi:
            return a + ((top if top is not None else r_s(th, H_CUT)) - a) * smooth((h - hi) / (H_CUT - hi))
        return r_in(th, h) - P['C_SHIRT']

    def hem(th):
        lo, hi = F.band(th); return lo + P['HEM_AT'] * (hi - lo)

    def r_trou(th, h):
        """the trousers' radius at and above the belt's bottom edge"""
        a = r_in(th, h) - P['C_TROU']; hm = hem(th)
        if h < hm:
            return a
        b = r_shirt(th, h) - P['D_IN']
        return a + (b - a) * smooth((h - hm) / 0.003) if h < hm + 0.003 else b

    # ------------------------------------------------------------ (1) the SHIRT: cut clean above the belt, a band down under it
    Msh, Mish = SH.matrix_world, SH.matrix_world.inverted()
    bm = bmesh.new(); bm.from_mesh(SH.data); n0 = len(bm.verts)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-7, plane_co=Mish @ (F.C + F.N * H_CUT),
                           plane_no=(Mish.to_3x3() @ F.N).normalized(), clear_inner=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    hw = lambda v: F.polar(Msh @ v.co)
    adj = {}
    for e in bm.edges:
        if e.is_boundary and all(abs(hw(v)[1] - H_CUT) < 2e-5 for v in e.verts):
            a, b = e.verts; adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    loops, seen = [], set()
    for v0 in adj:
        if v0 in seen:
            continue
        lp, prev, cur = [v0], None, v0; seen.add(v0)
        while True:
            nb = [x for x in adj[cur] if x is not prev and x not in seen]
            if not nb:
                break
            prev, cur = cur, nb[0]; lp.append(cur); seen.add(cur)
        if len(lp) > 2 and v0 in adj[lp[-1]]:
            loops.append(lp)
    if not loops:
        fail(f"the shirt's cut at h {H_CUT:.4f} left no closed loop")
    loop = max(loops, key=lambda lp: sum(hw(v)[2] for v in lp) / len(lp))   # the outermost: the shirt, not a lining
    dl = bm.verts.layers.deform.verify(); uvl = bm.loops.layers.uv.active
    names = [g.name for g in SH.vertex_groups]; gi = {n: i for i, n in enumerate(names)}
    own = {v: {names[g]: w for g, w in v[dl].items()} for v in bm.verts}
    rings = [loop]
    for fh in (lambda th: F.band(th)[1] + 0.0025, lambda th: F.band(th)[1] - 0.001, lambda th: 0.5 * (F.band(th)[1] + hem(th)), hem):
        ring = []
        for v in loop:
            th, h, r = hw(v); hj = fh(th)
            nv = bm.verts.new(Mish @ F.at(th, hj, r_shirt(th, hj, top=r))); own[nv] = own[v]; ring.append(nv)
        rings.append(ring)
    K = len(loop)
    band = [bm.faces.new((A[i], A[(i + 1) % K], Bq[(i + 1) % K], Bq[i])) for A, Bq in zip(rings[:-1], rings[1:]) for i in range(K)]
    bm.normal_update()
    f0 = band[len(band) // 2]
    if (Msh.to_3x3() @ f0.normal).dot(F.dir(F.polar(Msh @ f0.calc_center_median())[0])) < 0:
        bmesh.ops.reverse_faces(bm, faces=band)
    for f in band:
        f.smooth = True
        for l, uv in zip(f.loops, src_sh.face_uvs([Msh @ l.vert.co for l in f.loops])):
            l[uvl].uv = uv
    n_bw = 0
    for v in bm.verts:
        p = Msh @ v.co; th, h, r = F.polar(p); lo, hi = F.band(th); wup = P['SHIRT_WUP']
        fb = 1.0 if h < hi - 0.002 else (smooth((hi + wup - h) / (wup + 0.002)) if h < hi + wup else 0.0)
        if fb > 0:
            w = mix([own[v], src_belt.weights(p)], [1 - fb, fb]); v[dl].clear(); n_bw += 1
            for g, x in w.items():
                v[dl][gi[g]] = x
    bm.to_mesh(SH.data); bm.free()
    me = SH.data
    with bpy.context.temp_override(object=SH, active_object=SH, selected_objects=[SH], selected_editable_objects=[SH]):
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    auto = [Vector(x.vector) for x in me.corner_normals]; Ri3 = Mish.to_3x3(); nl = []; kept = 0
    for li, l in enumerate(me.loops):
        n, d = src_sh.normal(Msh @ me.vertices[l.vertex_index].co)
        if d < 3e-4:
            nl.append((Ri3 @ n).normalized()); kept += 1
        else:
            nl.append(auto[li])
    me.normals_split_custom_set(nl)
    print(f"[{TAG}] shirt: cut at h {H_CUT:.4f} ({n0} -> {len(me.vertices) - 4 * K} verts), a band of {4 * K} verts under the belt "
          f"to its hem; {n_bw} verts weighted toward the belt; Tripo's normals kept on {kept}/{len(me.loops)} corners")
    src_sh2 = Src([SH])

    # ------------------------------------------------------------ (2) the TROUSERS: one closed solid, plugged up inside the shirt
    verts, faces = [], []
    for o in TR:
        base = len(verts); M = o.matrix_world
        verts += [(M @ v.co)[:] for v in o.data.vertices]; faces += [[base + i for i in p.vertices] for p in o.data.polygons]
    me_t = bpy.data.meshes.new("waist_solid"); me_t.from_pydata(verts, [], faces)
    bm = bmesh.new(); bm.from_mesh(me_t)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0003)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    J, pr = 12, []
    for j in range(J):
        ring = []
        for k in range(NS):
            th = 2 * math.pi * k / NS; lo, hi = F.band(th); h = (lo - 0.002) + (hi + P['TOP_UP'] - lo + 0.002) * j / (J - 1)
            ring.append(bm.verts.new(F.at(th, h, r_trou(th, max(h, lo)) - 0.0005)))
        pr.append(ring)
    plug = [bm.faces.new((A[k], A[(k + 1) % NS], Bq[(k + 1) % NS], Bq[k])) for A, Bq in zip(pr[:-1], pr[1:]) for k in range(NS)]
    plug += [bm.faces.new(pr[0]), bm.faces.new(pr[-1])]
    bmesh.ops.recalc_face_normals(bm, faces=plug)
    bm.to_mesh(me_t); bm.free()
    ob = bpy.data.objects.new("waist_solid", me_t); bpy.context.scene.collection.objects.link(ob)

    def apply(mod):
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob], selected_editable_objects=[ob]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    m = ob.modifiers.new("r", 'REMESH'); m.mode = 'VOXEL'; m.voxel_size = P['VOXEL']; m.adaptivity = 0.0; apply(m)
    ntri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    m = ob.modifiers.new("d", 'DECIMATE'); m.ratio = min(1.0, P['TRIS'] / ntri); m.use_collapse_triangulate = True; apply(m)
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
    pre = [v.co.copy() for v in bm.verts]               # the remeshed skin, still on the old surface: weights, UVs, normals read here
    smw = {}
    for v in bm.verts:
        th, h, r = F.polar(v.co); lo, hi = F.band(th)
        w = smooth((h - (lo - 0.045)) / 0.015) * smooth((hi + P['TOP_UP'] + 0.01 - h) / 0.005)
        if w > 0:
            smw[v] = w
    for _ in range(int(P['SMOOTH_IT'])):
        for lam in (0.5, -0.53):                         # Taubin: smooths without shrinking
            nco = {v: v.co + (sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges) - v.co) * lam * w
                   for v, w in smw.items()}
            for v, c in nco.items():
                v.co = c
    bvh_cur = BVHTree.FromBMesh(bm)
    on_band, outer = set(), set()
    for v in bm.verts:                                   # each point radially onto its target, the cap scaled with it
        th, h, r = F.polar(v.co); lo, hi = F.band(th)
        if h < lo - P['FALL'] or h > hi + P['TOP_UP'] + 0.004:
            continue
        hs = hits(bvh_cur, F.C + F.N * h, F.dir(th)); R = max(hs[-1], r) if hs else r
        if h < lo:
            tgt = R + (r_in(th, lo) - P['C_TROU'] - R) * smooth((h - (lo - P['FALL'])) / P['FALL'])
        else:
            tgt = r_trou(th, h); on_band.add(v)
        if r > R - 0.0015:
            outer.add(v)
        q = v.co - F.C - F.N * h; v.co = F.C + F.N * h + q * (tgt / R)
    for _ in range(3):                                   # relax along the surface, then back onto the target
        nco = {v: v.co.lerp(sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges), 0.5) for v in on_band}
        for v, c in nco.items():
            v.co = c
            th, h, r = F.polar(c)
            if v in outer and h >= F.band(th)[0]:
                q = c - F.C - F.N * h; v.co = F.C + F.N * h + q * (r_trou(th, h) / r)
    # where the old halves met (two parts within 4 mm), walked out over the new skin
    seam_d = [math.inf] * len(bm.verts)
    if len(bvh_parts) > 1:
        for v in bm.verts:
            if sorted(b.find_nearest(pre[v.index])[3] for b in bvh_parts)[1] < 0.004:
                seam_d[v.index] = 0.0
    nbrs = [[(e.other_vert(v).index, e.calc_length()) for e in v.link_edges] for v in bm.verts]
    hq = [(0.0, i) for i, d in enumerate(seam_d) if d == 0.0]; heapq.heapify(hq)
    while hq:
        d, i = heapq.heappop(hq)
        if d <= seam_d[i]:
            for j, L in nbrs[i]:
                if d + L < seam_d[j]:
                    seam_d[j] = d + L; heapq.heappush(hq, (d + L, j))
    own = [src_tr.weights(pre[v.index]) for v in bm.verts]
    wsa = {}
    for v in bm.verts:
        th, h, r = F.polar(v.co); lo, hi = F.band(th)
        a_ = max(smooth((h - (lo - 0.16)) / 0.04), 1 - smooth(seam_d[v.index] / 0.03))
        if a_ > 0:
            wsa[v.index] = a_
    for _ in range(int(P['WSMOOTH_IT'])):
        upd = {}
        for i, a_ in wsa.items():
            acc = {}
            for j, L in nbrs[i]:
                for g, x in own[j].items():
                    acc[g] = acc.get(g, 0.0) + x / len(nbrs[i])
            upd[i] = mix([own[i], acc], [1 - 0.5 * a_, 0.5 * a_])
        own = [upd.get(i, w) for i, w in enumerate(own)]
    uvt = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l, uv in zip(f.loops, src_tr.face_uvs([pre[l.vert.index] for l in f.loops])):
            l[uvt].uv = uv
    W = []
    for v in bm.verts:                                   # the belt's weights under it, the shirt's above it
        th, h, r = F.polar(v.co); lo, hi = F.band(th); wb = ws = 0.0
        if h >= hi + 0.010:
            ws = 1.0
        elif h > hi:
            ws = smooth((h - hi) / 0.010); wb = 1 - ws
        elif h >= lo:
            wb = 1.0
        elif h > lo - P['WFALL']:
            wb = smooth((h - (lo - P['WFALL'])) / P['WFALL'])
        W.append(own[v.index] if wb == ws == 0 else
                 mix([own[v.index], src_belt.weights(v.co), src_sh2.weights(v.co) if ws else {}], [1 - wb - ws, wb, ws]))
    T0 = TR[0]; M5 = T0.matrix_world
    me_new = bpy.data.meshes.new(T0.data.name + "_waist"); bm.to_mesh(me_new); bm.free()
    me_new.transform(M5.inverted())
    for mat in T0.data.materials:
        me_new.materials.append(mat)
    T0.data = me_new
    for g in sorted({g for w in W for g in w} - set(T0.vertex_groups.keys())):   # a bone only another part was weighted to
        T0.vertex_groups.new(name=g)
    for i, w in enumerate(W):
        for g, x in w.items():
            T0.vertex_groups[g].add([i], x, 'REPLACE')
    auto = [Vector(x.vector) for x in me_new.corner_normals]; Ri = M5.inverted().to_3x3(); nl = []; kept = 0
    for li, l in enumerate(me_new.loops):                # Tripo's normals where the new skin lies on the old one
        vi = l.vertex_index; p = M5 @ me_new.vertices[vi].co; n_o, d = src_tr.normal(pre[vi])
        th, h, r = F.polar(p); lo, hi = F.band(th)
        w = (smooth((0.002 - d) / 0.0012) * smooth((0.0015 - (p - pre[vi]).length) / 0.001) * smooth((kd.find(pre[vi])[2] - 0.003) / 0.003)
             * smooth(seam_d[vi] / P['SEAM_FADE']) * smooth((lo - 0.02 - h) / 0.02))
        nl.append((auto[li] * (1 - w) + (Ri @ n_o).normalized() * w).normalized()); kept += w > 0.5
    me_new.normals_split_custom_set(nl)
    for o in TR[1:]:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(ob)
    print(f"[{TAG}] trousers: {len(TR)} parts -> one closed skin of {len(me_new.polygons)} tris (remesh {ntri}); {len(on_band)} verts set "
          f"on the waist rule; old seam {sum(d == 0.0 for d in seam_d)} verts; Tripo's normals kept on {kept}/{len(me_new.loops)} corners")

    arm.data.pose_position = 'POSE'
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    glb = os.path.splitext(out)[0] + ".glb"              # as the pipeline reads a base: armature unhidden, every clip, in POSE
    for o in bpy.data.objects:
        o.hide_set(False); o.hide_viewport = False; o.select_set(o.type in ('MESH', 'ARMATURE'))
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=glb, use_selection=True, export_animations=True, export_animation_mode='ACTIONS')
    print(f"[{TAG}] wrote {out} and {glb}")


if __name__ == "__main__":
    main()
