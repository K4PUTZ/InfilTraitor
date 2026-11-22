"""The uniform's map of a light enemy (ENEMIES_MASTER_PLAN §12.14; installed 2026-11-22, the Director: "Pode instalar no game").

enemy_texture.py calls this for every face that is not Tripo's head piece. Blender's Python: numpy and mathutils only (no scipy,
no PIL).

Why. Measured on the FID male guard (2026-11-21), the smart projection this replaces:
- cut the uniform into 838 islands, 332 of them a single triangle;
- covered 26 % of a 1024 map: about 6 texels per figure-centimetre, against the face's 33.

Its paint also placed the pockets, the placket and the buttons by bone rules, beside the ones Tripo modelled. And the actor shader
lights only 0.72-1.0 of the albedo, so a uniform's volume must be painted into its map.

1. LAYOUT (`layout`). Tripo models a uniform as loose pieces. On the guard: the shirt, the trousers, two shoes, two hands, the
   pockets and their flaps, the epaulettes, the buttons, the laces and the right leg's piping.
   - Each piece gets a kind (`_kind_of`). The big ones are cut where a tailor sews: the sleeves (where the arm's bones outweigh the
     trunk's skin weights), the torso's front and back at the side seam, the collar, the trousers' two legs, the soles, the hands'
     back and palm, the sleeves' wrist caps.
   - Every panel is cut open along shortest paths until it is a disk; a sleeve is opened along its underside, a leg along its inside.
   - Each disk is unwrapped (angle based) and brought to one density, with less for what the game camera never sees (`SCALE`). It is
     stood upright, mirrored the right way round, and packed. The buttons share one patch, the laces another.
2. BAKE (`bake`). Tripo's source (19.7 k triangles on the guard) is baked selected-to-active onto the new layout with Cycles:
   - ambient occlusion at two reaches: 7 cm for the volume, 1.2 cm for the creases;
   - the source's normal, for the folds the decimation lost.
3. PAINT (`paint`).
   - Each piece's colour (the palette), times the occlusion, the fold detail (the source's normal against the light mesh's) and a
     sky term. Ridges come out a touch lighter, creases darker.
   - A grain: poplin on the shirt, twill on the trousers.
   - Stitches inside the edges of the pockets, the flaps, the epaulettes and the trousers' waist and hems, plus the placket's two
     lines either side of the buttons.
   - A highlight on each button.
   - A stripe along any slit Tripo left in place of a leg's piping (the guard's left leg).
   - No rule paints skin or white on the collar. The reference's white undershirt is not worn, because the head goes on other bodies
     (the Director, 2026-11-22).
   - Every empty texel takes its nearest island's colour, so no mip level reads black.

The kinds' thresholds are measured on the FID male guard (a figure 1 m tall, facing -Y, heights from the soles). A new body prints
its pieces, and the build stops when the shirt or the trousers are not found.
"""
import heapq
import math
from collections import defaultdict

import bmesh
import bpy
import numpy as np
from bpy_extras import bmesh_utils
from mathutils.kdtree import KDTree

TAG = "[enemy_uniform]"

# What the game camera never sees gets fewer texels: a fraction of the one density the rest has.
SCALE = {"sole": 0.35, "lace": 0.5, "hand": 0.8}
PACK_MARGIN = 0.003           # between islands, a fraction of the map (6 texels at 2048)
BAKE_SAMPLES = 48
AO_LONG, AO_SHORT = 0.07, 0.012      # the occlusion's two reaches (m): the volume, the creases
CAGE, RAY = 0.006, 0.02              # the bake's cage extrusion and ray reach (m): the light mesh lies on the source

# The paint, as it was ratified on the prototype (2026-11-21).
K_LONG, K_SHORT, K_HEMI = 0.75, 0.6, 0.14
STRIPE_HALF = 0.0042          # the left stripe's half width (m): the right piping's visible width
WAIST_BAND = 0.0235           # the trousers' waist stitch: boundary within this of their top (m)
HEM_BAND = 0.0298             # the hems' stitch: boundary within this of their bottom (m)
SLIT_FROM_HEM = 0.025         # a slit is the trousers' boundary between the hem band and the waist band...
SLIT_MIN_X = 0.06             # ...on a leg's outer half (|x|, m)
PLACKET_HALF = 0.0095         # the placket's stitch lines either side of the buttons' line (m)


def _bone(arm, name: str) -> np.ndarray:
    return np.array(arm.matrix_world @ arm.data.bones["mixamorig:" + name].head_local, np.float64)


class Layout:
    """the uniform's pieces on its map. `face_kind`: per face of the mesh, the index of its kind in `kind_names` (-1: the head)"""

    def __init__(self, face_kind: np.ndarray, kind_names: list, islands: int, size: int):
        self.face_kind = face_kind
        self.kind_names = kind_names
        self.islands = islands
        self.size = size

    def kind(self, name: str) -> int:
        return self.kind_names.index(name) if name in self.kind_names else -2


# --- 1. layout --------------------------------------------------------------------------------------------------------------
def _kind_of(d: dict) -> str:
    """a loose piece's kind, from its face count, extent, centroid and the bones that weigh most on it (measured on the guard)"""
    ext, c = d["hi"] - d["lo"], d["c"]
    if d["nf"] > 500 and c[2] > 0.55:
        return "shirt"
    if d["nf"] > 500 and 0.1 < c[2] < 0.55:
        return "trousers"
    if d["nf"] > 200 and c[2] < 0.1:
        return "shoe"
    if d["nf"] > 120 and any("Hand" in b for b in d["dom"]):
        return "hand"
    if ext[2] > 0.3:
        return "piping"
    if c[2] < 0.1:
        return "lace"
    if max(ext) < 0.016:
        return "button"
    if any("Shoulder" in b for b in d["dom"]) and c[2] > 0.8:
        return "epaulette"
    if 0.68 < c[2] < 0.78:
        return "pocket"
    return "misc"


def layout(obj, head_faces: set, arm, size: int) -> Layout:
    """cut the uniform (every face of `obj` not in `head_faces`) into a tailor's pieces and pack them; writes their UVs into the
    mesh's active UV layer (the head's loops are left alone) and returns what the paint needs"""
    me = obj.data
    mw = obj.matrix_world
    rot = mw.to_3x3()
    B = {n: _bone(arm, n) for n in ("Neck", "LeftArm", "RightArm", "LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg",
                                    "LeftFoot", "RightFoot")}

    # a welded copy of the uniform for its topology (the import splits vertices); each face remembers the mesh face it came from
    bm = bmesh.new()
    bm.from_mesh(me)
    oid = bm.faces.layers.int.new("orig_face")
    for f in bm.faces:
        f[oid] = f.index
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in head_faces], context="FACES")
    n0 = len(bm.faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    for seq in (bm.verts, bm.edges, bm.faces):
        seq.index_update()
        seq.ensure_lookup_table()
    F = len(bm.faces)
    print(TAG, f"weld: {n0} uniform faces -> {F} (a degenerate face collapses and takes a neighbour's uv)")
    fc = np.array([tuple(mw @ f.calc_center_median()) for f in bm.faces])
    fnrm = np.array([tuple((rot @ f.normal).normalized()) for f in bm.faces])
    VP = np.array([tuple(mw @ v.co) for v in bm.verts])

    # loose pieces and their kinds
    part = np.full(F, -1, np.int64)
    npart = 0
    for f in bm.faces:
        if part[f.index] >= 0:
            continue
        st = [f]
        part[f.index] = npart
        while st:
            g = st.pop()
            for v in g.verts:
                for h in v.link_faces:
                    if part[h.index] < 0:
                        part[h.index] = npart
                        st.append(h)
        npart += 1
    dl = bm.verts.layers.deform.active
    if dl is None:
        raise SystemExit(f"{TAG} the uniform has no skin weights (the sleeves are cut by them)")
    gname = {g.index: g.name.replace("mixamorig:", "") for g in obj.vertex_groups}
    info = []
    for p in range(npart):
        fs = np.nonzero(part == p)[0]
        vs = sorted(set(v.index for i in fs for v in bm.faces[i].verts))
        w = defaultdict(float)
        for vi in vs:
            for gi, wt in bm.verts[vi][dl].items():
                w[gname[gi]] += wt
        dom = [k for k, _ in sorted(w.items(), key=lambda kv: -kv[1])[:3]]
        info.append(dict(nf=len(fs), c=VP[vs].mean(0), lo=VP[vs].min(0), hi=VP[vs].max(0), dom=dom))
    kinds = {p: _kind_of(info[p]) for p in range(npart)}
    for s in (-1, 1):   # pocket or flap: on each side the higher one is the flap
        pk = [p for p in kinds if kinds[p] == "pocket" and np.sign(info[p]["c"][0]) == s]
        if len(pk) == 2:
            kinds[max(pk, key=lambda p: info[p]["c"][2])] = "flap"
    count = defaultdict(int)
    for k in kinds.values():
        count[k] += 1
    for p in sorted(range(npart), key=lambda p: -info[p]["nf"])[:14]:
        print(TAG, f"piece {p} {kinds[p]}: {info[p]['nf']} faces at {np.round(info[p]['c'], 3).tolist()} {info[p]['dom']}")
    print(TAG, f"{npart} pieces:", dict(sorted(count.items())))
    if count["shirt"] != 1 or count["trousers"] != 1:
        raise SystemExit(f"{TAG} expected one shirt and one trousers piece, found {dict(count)}: check _kind_of on this body")
    fkind = np.array([kinds[p] for p in part])

    # panels: where a tailor would sew
    panel = np.array([f"{fkind[i]}{part[i]}" for i in range(F)], dtype=object)
    shirt = fkind == "shirt"
    side = np.sign(fc[:, 0])
    for f in bm.faces:            # sleeves: where the arm's bones outweigh the trunk's (the Agent's skin weights)
        if not shirt[f.index]:
            continue
        w = defaultdict(float)
        for v in f.verts:
            for gi, wt in v[dl].items():
                w[gname[gi]] += wt
        tot = sum(w.values())
        for pre, name in (("Left", "sleeve_L"), ("Right", "sleeve_R")):
            if sum(wt for b, wt in w.items() if b.startswith(pre) and ("Arm" in b or "Hand" in b)) > 0.5 * tot:
                panel[f.index] = name
    torso = shirt & ~np.isin(panel, ["sleeve_L", "sleeve_R"])
    # front / back at the side seam: the middle of the torso's depth at each height
    zs, ys = fc[torso, 2], fc[torso, 1]
    bins = np.linspace(zs.min(), zs.max(), 24)
    mid = []
    for z0, z1 in zip(bins[:-1], bins[1:]):
        m = (zs >= z0) & (zs <= z1)
        if m.sum() > 4:
            mid.append(((z0 + z1) / 2.0, (np.percentile(ys[m], 2) + np.percentile(ys[m], 98)) / 2.0))
    mid = np.array(mid)
    yc = np.interp(fc[:, 2], mid[:, 0], mid[:, 1])
    panel[torso & (fc[:, 1] < yc)] = "torso_front"
    panel[torso & (fc[:, 1] >= yc)] = "torso_back"
    tr = fkind == "trousers"
    panel[tr & (fc[:, 0] >= 0)] = "trou_L"
    panel[tr & (fc[:, 0] < 0)] = "trou_R"
    sh = fkind == "shoe"
    for i in np.nonzero(sh & (fnrm[:, 2] < -0.55))[0]:
        panel[i] = f"sole{part[i]}"
    for i in np.nonzero(fkind == "hand")[0]:      # the back looks outward in the A pose
        panel[i] = f"hand{part[i]}_{'back' if fnrm[i, 0] * side[i] > 0 else 'palm'}"
    for i in range(F):            # folded small pieces: their outer face apart, or the flattening squashes them
        if fkind[i] == "epaulette":
            panel[i] = f"epaulette{part[i]}_{'top' if fnrm[i, 2] > 0.25 else 'under'}"
        elif fkind[i] == "flap":
            panel[i] = f"flap{part[i]}_{'front' if fnrm[i, 1] < -0.25 else 'back'}"
    # the collar: the shirt round the neck above the yoke (band and turned-down points)
    rad = np.hypot(fc[:, 0] - B["Neck"][0], fc[:, 1] - B["Neck"][1])
    panel[shirt & ~np.isin(panel, ["sleeve_L", "sleeve_R"]) & (fc[:, 2] > B["Neck"][2] - 0.045) & (rad < 0.075)] = "collar"
    # smooth the panels' borders: a face whose neighbours (same piece) mostly carry another panel takes it (no spikes)
    nbr = [[h.index for e in f.edges for h in e.link_faces if h.index != f.index and part[h.index] == part[f.index]]
           for f in bm.faces]
    for _ in range(6):
        newp, changed = panel.copy(), 0
        for i in range(F):
            if fkind[i] not in ("shirt", "trousers", "shoe", "hand") or not nbr[i]:
                continue
            labs = [panel[j] for j in nbr[i]]
            best = max(set(labs), key=labs.count)
            if best != panel[i] and labs.count(best) >= 2:
                newp[i] = best
                changed += 1
        panel = newp
        if not changed:
            break
    # a sleeve is closed at the wrist: its cuff's cap is a panel of its own, so the sleeve is a tube
    for A, H, name in (("LeftArm", "LeftHand", "sleeve_L"), ("RightArm", "RightHand", "sleeve_R")):
        ad = B[H] - B[A]
        length = float(np.linalg.norm(ad))
        ad /= length
        t = (fc - B[A]) @ ad
        panel[(panel == name) & (t > length - 0.06) & (fnrm @ ad > 0.55)] = name + "_cap"
    for e in bm.edges:
        lf = e.link_faces
        e.seam = len(lf) == 2 and panel[lf[0].index] != panel[lf[1].index]
    print(TAG, "panels:", {k: int((panel == k).sum()) for k in sorted(set(panel.tolist()))
                           if not k.startswith(("lace", "button"))})

    def phi_fn(origin, axis, ref):
        axis = axis / np.linalg.norm(axis)
        ref = ref - (ref @ axis) * axis
        ref /= np.linalg.norm(ref)
        w = np.cross(axis, ref)

        def f(p):
            r = p - origin
            r = r - (r @ axis) * axis
            return math.atan2(r @ w, r @ ref)
        return f

    def loops_of(fs):
        """the boundary components of the face set `fs` cut open along its seams: a list of sets of vertex indices"""
        fs = set(fs)
        cid, nid = {}, 0          # a vertex's corner id: its faces in fs, grouped across interior edges that are not seams
        for f in fs:
            for v in bm.faces[f].verts:
                if (f, v.index) in cid:
                    continue
                st = [f]
                cid[(f, v.index)] = nid
                while st:
                    g = st.pop()
                    for e in bm.faces[g].edges:
                        if v not in e.verts or e.seam:
                            continue
                        for h in e.link_faces:
                            if h.index in fs and (h.index, v.index) not in cid:
                                cid[(h.index, v.index)] = nid
                                st.append(h.index)
                nid += 1
        par = list(range(nid))

        def find(x):
            while par[x] != x:
                par[x] = par[par[x]]
                x = par[x]
            return x
        used = set()
        for f in fs:
            for e in bm.faces[f].edges:
                if len([h for h in e.link_faces if h.index in fs]) == 2 and not e.seam:
                    continue
                a_, b_ = cid[(f, e.verts[0].index)], cid[(f, e.verts[1].index)]
                par[find(a_)] = find(b_)
                used.update((a_, b_))
        comps = defaultdict(set)
        for (f, v), c in cid.items():
            if c in used:
                comps[find(c)].add(v)
        return list(comps.values())

    def components(fs):
        fs, out, seen = set(fs), [], set()
        for f in fs:
            if f in seen:
                continue
            st, comp = [f], []
            seen.add(f)
            while st:
                g = st.pop()
                comp.append(g)
                for e in bm.faces[g].edges:
                    if e.seam:
                        continue
                    for h in e.link_faces:
                        if h.index in fs and h.index not in seen:
                            seen.add(h.index)
                            st.append(h.index)
            out.append(comp)
        return out

    def make_disk(fs, prefer=None, tag=""):
        """cut a face set open along shortest paths until each piece has ONE boundary (a disk, flattenable); a piece's first
        cut follows `prefer` (the angle off the tailor's line at a point), the others the shortest way"""
        cuts = 0
        for comp in components(fs):
            cs = set(comp)
            for it in range(40):
                L = loops_of(comp)
                if len(L) <= 1:
                    if not L:
                        print(TAG, f"a closed piece in {tag} ({len(comp)} faces) is left uncut")
                    break
                L.sort(key=len, reverse=True)
                src, others = L[0], set().union(*L[1:])
                adj = defaultdict(list)
                for f in comp:
                    for e in bm.faces[f].edges:
                        if e.seam or sum(1 for h in e.link_faces if h.index in cs) != 2:
                            continue
                        a_, b_ = e.verts[0].index, e.verts[1].index
                        adj[a_].append((b_, e))
                        adj[b_].append((a_, e))
                pf = prefer if (it == 0 and prefer is not None) else None
                dist, prev, end = {v: 0.0 for v in src}, {}, None
                pq = [(0.0, v) for v in src]
                heapq.heapify(pq)
                while pq:
                    dd, v = heapq.heappop(pq)
                    if dd > dist.get(v, 1e9):
                        continue
                    if v in others and v not in src:
                        end = v
                        break
                    for w, e in adj[v]:
                        c = float(np.linalg.norm(VP[w] - VP[v]))
                        if pf is not None:
                            c *= 1.0 + 14.0 * (abs(pf((VP[v] + VP[w]) / 2.0)) / math.pi) ** 2
                        c += dd
                        if c < dist.get(w, 1e9):
                            dist[w], prev[w] = c, (v, e)
                            heapq.heappush(pq, (c, w))
                if end is None:
                    raise SystemExit(f"{TAG} {tag}: no path between two of its boundaries")
                v = end
                while v in prev:
                    u, e = prev[v]
                    e.seam = True
                    cuts += 1
                    v = u
        return cuts

    cut = {}
    for s, A, H, name in ((1, "LeftArm", "LeftHand", "sleeve_L"), (-1, "RightArm", "RightHand", "sleeve_R")):
        under = np.array([-s * 1.0, 0.0, -0.6])                   # toward the body and down: the sleeve's underside
        cut[name] = make_disk(np.nonzero(panel == name)[0], phi_fn(B[A], B[H] - B[A], under), name)
    for s, UL, FT, name in ((1, "LeftUpLeg", "LeftFoot", "trou_L"), (-1, "RightUpLeg", "RightFoot", "trou_R")):
        cut[name] = make_disk(np.nonzero(panel == name)[0], phi_fn(B[UL], B[FT] - B[UL], np.array([-s * 1.0, 0.0, 0.0])), name)
    for name in sorted(set(panel.tolist())):
        if name not in cut:
            cut[name] = make_disk(np.nonzero(panel == name)[0], None, name)
    print(TAG, "cut open:", {k: v for k, v in cut.items() if v})

    # unwrap and pack on a scratch object
    tmp_me = bpy.data.meshes.new("UniformLayout")
    bm.to_mesh(tmp_me)
    tmp = bpy.data.objects.new("UniformLayout", tmp_me)
    bpy.context.scene.collection.objects.link(tmp)
    tmp.matrix_world = mw
    for o in bpy.context.scene.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = tmp
    tmp.select_set(True)
    if not tmp_me.uv_layers:
        tmp_me.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", fill_holes=True, correct_aspect=True, margin=0.001)
    bpy.ops.uv.average_islands_scale()
    ebm = bmesh.from_edit_mesh(tmp_me)
    ebm.faces.ensure_lookup_table()
    uvl = ebm.loops.layers.uv.active
    for isl in bmesh_utils.bmesh_linked_uv_islands(ebm, uvl):
        # upright (the figure's up = +v), the right way round, and at its visibility's share of the density
        U = np.array([[tuple(lo[uvl].uv) for lo in f.loops] for f in isl])
        P = np.array([[tuple(mw @ lo.vert.co) for lo in f.loops] for f in isl])
        g, wind = np.zeros(2), 0.0
        for Ut, Pt in zip(U, P):
            M = np.array([Ut[1] - Ut[0], Ut[2] - Ut[0]])
            det = float(np.linalg.det(M))
            if abs(det) < 1e-14:
                continue
            gz = np.linalg.solve(M, np.array([Pt[1][2] - Pt[0][2], Pt[2][2] - Pt[0][2]]))   # d z / d(u, v)
            ar = 0.5 * float(np.linalg.norm(np.cross(Pt[1] - Pt[0], Pt[2] - Pt[0])))
            if np.linalg.norm(gz) > 1e-9:
                g += ar * gz / np.linalg.norm(gz)
            wind += math.copysign(ar, det)
        c = U.reshape(-1, 2).mean(0)
        if wind < 0:                                              # mirrored: flip u
            U[..., 0] = 2.0 * c[0] - U[..., 0]
            g[0] = -g[0]
        r = math.pi / 2.0 - (math.atan2(g[1], g[0]) if np.linalg.norm(g) > 1e-9 else math.pi / 2.0)
        R = np.array([[math.cos(r), -math.sin(r)], [math.sin(r), math.cos(r)]])
        f0 = isl[0].index
        sc = SCALE.get("sole" if panel[f0].startswith("sole") else fkind[f0], 1.0)
        U = (U - c) @ R.T * sc + c
        for f, Ut in zip(isl, U):
            for lo, uv in zip(f.loops, Ut):
                lo[uvl].uv = tuple(uv)
    # first pack: every island apart (the unwrap leaves them on top of each other)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, rotate_method="CARDINAL", scale=True, merge_overlap=False, margin_method="FRACTION",
                            margin=PACK_MARGIN, shape_method="CONCAVE")
    # identical small pieces share one patch (planar on the piece's facing, stacked on the first one's spot and size)
    ebm = bmesh.from_edit_mesh(tmp_me)
    ebm.faces.ensure_lookup_table()
    uvl = ebm.loops.layers.uv.active
    for kname in ("button", "lace"):
        ps = sorted(p for p in kinds if kinds[p] == kname)
        if not ps:
            continue
        U0 = np.array([tuple(lo[uvl].uv) for i in np.nonzero(part == ps[0])[0] for lo in ebm.faces[i].loops])
        spot, half = U0.mean(0), max(float(np.ptp(U0[:, 0])), float(np.ptp(U0[:, 1]))) * 0.5
        for p in ps:
            fs = [ebm.faces[i] for i in np.nonzero(part == p)[0]]
            Pp = np.array([tuple(mw @ lo.vert.co) for f in fs for lo in f.loops])
            n = np.array([tuple(rot @ f.normal) for f in fs]).sum(0)
            n /= max(float(np.linalg.norm(n)), 1e-9)
            ax1 = np.cross(n, [0.0, 0.0, 1.0]) if abs(n[2]) < 0.9 else np.cross(n, [1.0, 0.0, 0.0])
            ax1 /= np.linalg.norm(ax1)
            ax2 = np.cross(n, ax1)
            c = Pp.mean(0)
            ext = max(float(np.abs((Pp - c) @ ax1).max()), float(np.abs((Pp - c) @ ax2).max()), 1e-6)
            for f in fs:
                for lo in f.loops:
                    q = np.array(tuple(mw @ lo.vert.co)) - c
                    lo[uvl].uv = (spot[0] + half * (q @ ax1) / ext, spot[1] + half * (q @ ax2) / ext)
    bmesh.update_edit_mesh(tmp_me)
    # second pack: each stack travels as one island
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, rotate_method="CARDINAL", scale=True, merge_overlap=True, margin_method="FRACTION",
                            margin=PACK_MARGIN, shape_method="CONCAVE")
    ebm = bmesh.from_edit_mesh(tmp_me)
    ebm.faces.ensure_lookup_table()
    uvl = ebm.loops.layers.uv.active
    islands = len(bmesh_utils.bmesh_linked_uv_islands(ebm, uvl))
    new_uv = [[tuple(lo[uvl].uv) for lo in f.loops] for f in ebm.faces]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(tmp_me)

    # the UVs back on the mesh, loop by loop (a collapsed face's corners take the uv of the welded vertex they merged into)
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvd = me.uv_layers.active.data
    welded_of = {f[oid]: f.index for f in bm.faces}
    vkd = KDTree(len(bm.verts))
    for v in bm.verts:
        vkd.insert(v.co, v.index)
    vkd.balance()
    vuv = {}
    for f in bm.faces:
        for k, lo in enumerate(f.loops):
            vuv.setdefault(lo.vert.index, new_uv[f.index][k])
    face_kind = np.full(len(me.polygons), -1, np.int16)
    kind_names = sorted(set(fkind.tolist()))
    collapsed = 0
    for p in me.polygons:
        if p.index in head_faces:
            continue
        wi = welded_of.get(p.index)
        if wi is None:
            collapsed += 1
            _co, vi, _d = vkd.find(me.vertices[p.vertices[0]].co)
            wi = next(iter(bm.verts[vi].link_faces)).index
            for li, v in zip(p.loop_indices, p.vertices):
                _co, vi, _d = vkd.find(me.vertices[v].co)
                uvd[li].uv = vuv[vi]
        else:
            wf = bm.faces[wi]
            wco = [lo.vert.co for lo in wf.loops]
            for li, v in zip(p.loop_indices, p.vertices):
                k = min(range(len(wco)), key=lambda j: (wco[j] - me.vertices[v].co).length)
                uvd[li].uv = new_uv[wi][k]
        face_kind[p.index] = kind_names.index(fkind[wi])
    bm.free()
    print(TAG, f"layout: {islands} islands; {collapsed} collapsed faces took their neighbours' uv")
    return Layout(face_kind, kind_names, islands, size)


def stats(obj, lay: Layout, tex) -> None:
    """the layout's measures, printed: coverage, texels per figure-centimetre, stretch"""
    me = obj.data
    mw = obj.matrix_world
    me.calc_loop_triangles()
    uvd = me.uv_layers.active.data
    P, U = [], []
    for t in me.loop_triangles:
        if lay.face_kind[t.polygon_index] >= 0:
            P.append([tuple(mw @ me.vertices[v].co) for v in t.vertices])
            U.append([tuple(uvd[li].uv) for li in t.loops])
    P, U = np.array(P), np.array(U) * lay.size
    e1, e2 = P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]
    n = np.cross(e1, e2)
    a3 = 0.5 * np.linalg.norm(n, axis=1)
    du1, du2 = U[:, 1] - U[:, 0], U[:, 2] - U[:, 0]
    auv = 0.5 * np.abs(du1[:, 0] * du2[:, 1] - du1[:, 1] * du2[:, 0])
    ok = a3 > 1e-12
    dens = np.sqrt(auv[ok] / (a3[ok] * 1e4))                    # texels per figure-centimetre
    x = e1[ok] / np.linalg.norm(e1[ok], axis=1, keepdims=True)
    y = np.cross(n[ok] / np.linalg.norm(n[ok], axis=1, keepdims=True), x)
    A = np.stack([np.stack([(e1[ok] * x).sum(1), (e2[ok] * x).sum(1)], 1), np.stack([(e1[ok] * y).sum(1), (e2[ok] * y).sum(1)], 1)], 1)
    Bm = np.stack([np.stack([du1[ok, 0], du2[ok, 0]], 1), np.stack([du1[ok, 1], du2[ok, 1]], 1)], 1)
    det = A[:, 0, 0] * A[:, 1, 1] - A[:, 0, 1] * A[:, 1, 0]
    good = np.abs(det) > 1e-14
    inv = np.stack([np.stack([A[:, 1, 1], -A[:, 0, 1]], 1), np.stack([-A[:, 1, 0], A[:, 0, 0]], 1)], 1) / np.where(good, det, 1.0)[:, None, None]
    J = Bm @ inv
    E, Fq = (J[:, 0, 0] + J[:, 1, 1]) / 2.0, (J[:, 0, 0] - J[:, 1, 1]) / 2.0
    G, Hq = (J[:, 1, 0] + J[:, 0, 1]) / 2.0, (J[:, 1, 0] - J[:, 0, 1]) / 2.0
    Q, R = np.hypot(E, Hq), np.hypot(Fq, G)
    aniso = ((Q + R) / np.maximum(np.abs(Q - R), 1e-12))[good]
    cov = float((tex.fid >= 0).mean())
    print(TAG, f"map {lay.size}: {lay.islands} islands, coverage {cov * 100:.1f} %, texels per figure-cm median "
               f"{np.median(dens):.1f} (p10 {np.percentile(dens, 10):.1f}), stretch median {np.median(aniso):.2f} "
               f"p90 {np.percentile(aniso, 90):.2f}, > 2: {(aniso > 2).mean() * 100:.1f} %")


# --- per texel ----------------------------------------------------------------------------------------------------------------
class Texels:
    """the uniform map's texels: each one's point on the figure at rest, the light mesh's normal there, its face (-1: empty);
    and per triangle of the uniform its corners and face"""

    def __init__(self, pos, nrm, fid, tri_pos, tri_face):
        self.pos, self.nrm, self.fid = pos, nrm, fid
        self.tri_pos, self.tri_face = tri_pos, tri_face


def raster(obj, lay: Layout) -> Texels:
    me = obj.data
    mw = obj.matrix_world
    rot = np.array(mw.to_3x3(), np.float32)
    N = lay.size
    me.calc_loop_triangles()
    uvd = me.uv_layers.active.data
    cn = np.empty(len(me.loops) * 3, np.float32)
    me.corner_normals.foreach_get("vector", cn)
    cn = cn.reshape(-1, 3) @ rot.T
    vco = np.array([tuple(mw @ v.co) for v in me.vertices], np.float32)
    pos = np.zeros((N, N, 3), np.float32)
    nrm = np.zeros((N, N, 3), np.float32)
    fid = np.full((N, N), -1, np.int32)
    tri_pos, tri_face = [], []
    for t in me.loop_triangles:
        if lay.face_kind[t.polygon_index] < 0:
            continue
        vi = list(t.vertices)
        tri_pos.append(vco[vi])
        tri_face.append(t.polygon_index)
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
        inside = (l0 >= -0.01) & (l1 >= -0.01) & (l2 >= -0.01)
        if not inside.any():
            continue
        lam = np.stack([l0, l1, l2], -1)[inside].astype(np.float32)
        yy, xx = (ys[inside] - 0.5).astype(int), (xs[inside] - 0.5).astype(int)
        pos[yy, xx] = lam @ vco[vi]
        nn = lam @ cn[list(t.loops)]
        nrm[yy, xx] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
        fid[yy, xx] = t.polygon_index
    return Texels(pos, nrm, fid, np.array(tri_pos, np.float32), np.array(tri_face, np.int64))


# --- 2. bake ------------------------------------------------------------------------------------------------------------------
def bake(obj, lay: Layout, source_glb: str) -> dict:
    """Tripo's source baked onto the uniform's layout (Cycles, selected to active): {"ao_long", "ao_short": (N, N) in 0..1,
    "normal": (N, N, 3) the source's world-space normal}. Every object the bake adds is removed again."""
    sc = bpy.context.scene
    N = lay.size
    before = {k: set(getattr(bpy.data, k)) for k in ("objects", "meshes", "materials", "images", "worlds")}
    engine = sc.render.engine
    # the uniform alone, in world space (so the normal's object space is the world's)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if lay.face_kind[f.index] < 0], context="FACES")
    bmesh.ops.transform(bm, matrix=obj.matrix_world, verts=bm.verts[:])
    tme = bpy.data.meshes.new("UniformBake")
    bm.to_mesh(tme)
    bm.free()
    tob = bpy.data.objects.new("UniformBake", tme)
    sc.collection.objects.link(tob)
    mat = bpy.data.materials.new("UniformBake")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = node
    tme.materials.clear()
    tme.materials.append(mat)
    for p in tme.polygons:
        p.material_index = 0
    bpy.ops.import_scene.gltf(filepath=source_glb)
    hi = [o for o in bpy.data.objects if o not in before["objects"] and o.type == "MESH" and o != tob]
    if not hi:
        raise SystemExit(f"{TAG} {source_glb}: no mesh to bake from")
    print(TAG, f"bake source {source_glb}: {sum(len(o.data.polygons) for o in hi)} faces")
    seen = []                     # only the source is seen by the rays
    for o in sc.objects:
        if o in hi:
            continue
        seen.append((o, o.visible_camera, o.visible_diffuse, o.visible_glossy, o.visible_transmission,
                     o.visible_volume_scatter, o.visible_shadow))
        o.visible_camera = o.visible_diffuse = o.visible_glossy = o.visible_transmission = False
        o.visible_volume_scatter = o.visible_shadow = False
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = BAKE_SAMPLES
    if sc.world is None:
        sc.world = bpy.data.worlds.new("UniformBake")
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = CAGE
    bk.max_ray_distance = RAY
    bk.margin = 24
    bk.margin_type = "EXTEND"
    bk.use_clear = True
    for o in sc.objects:
        o.select_set(False)
    for o in hi:
        o.select_set(True)
    tob.select_set(True)
    bpy.context.view_layer.objects.active = tob
    out = {}

    def run(name, kind, **kw):
        im = bpy.data.images.new("UniformBake_" + name, N, N, float_buffer=True)
        node.image = im
        bpy.ops.object.bake(type=kind, **kw)
        a = np.empty(N * N * 4, np.float32)
        im.pixels.foreach_get(a)
        out[name] = a.reshape(N, N, 4)[..., :3].copy()
        print(TAG, "baked", name)

    sc.world.light_settings.distance = AO_LONG
    run("ao_long", "AO")
    sc.world.light_settings.distance = AO_SHORT
    run("ao_short", "AO")
    run("normal", "NORMAL", normal_space="OBJECT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z")
    for o, *vis in seen:
        (o.visible_camera, o.visible_diffuse, o.visible_glossy, o.visible_transmission, o.visible_volume_scatter,
         o.visible_shadow) = vis
    sc.render.engine = engine
    for o in [o for o in bpy.data.objects if o not in before["objects"]]:
        bpy.data.objects.remove(o)
    for k in ("meshes", "materials", "images", "worlds"):
        coll = getattr(bpy.data, k)
        for d in [d for d in coll if d not in before[k]]:
            coll.remove(d)
    n = out["normal"] * 2.0 - 1.0
    out["normal"] = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    out["ao_long"], out["ao_short"] = out["ao_long"][..., 0], out["ao_short"][..., 0]
    return out


# --- 3. paint -----------------------------------------------------------------------------------------------------------------
def _lin(c) -> np.ndarray:
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(np.float32)


def _srgb(c) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055).astype(np.float32)


def _nearest(points: np.ndarray, queries: np.ndarray):
    """for each query its nearest point: (distance, index)"""
    kd = KDTree(len(points))
    for i, p in enumerate(points.tolist()):
        kd.insert(p, i)
    kd.balance()
    d, ix = [], []
    for q in queries.tolist():
        _co, i, dist = kd.find(q)
        ix.append(i)
        d.append(dist)
    return np.array(d, np.float32), np.array(ix, np.int64)


def _boundary(P: np.ndarray, step: float):
    """points along the open edges (used by one triangle) of the triangles P (T, 3, 3), every `step` metres, with their arc
    length"""
    cnt = {}
    for t in np.round(P.astype(np.float64), 5):
        for k in range(3):
            a, b = tuple(t[k]), tuple(t[(k + 1) % 3])
            e = (a, b) if a < b else (b, a)
            cnt[e] = cnt.get(e, 0) + 1
    pts, arcs, s = [], [], 0.0
    for (a, b), c in cnt.items():
        if c != 1:
            continue
        a, b = np.array(a), np.array(b)
        L = float(np.linalg.norm(b - a))
        n = max(int(L / step), 1)
        for i in range(n + 1):
            pts.append(a + (b - a) * i / n)
            arcs.append(s + L * i / n)
        s += L
    return np.array(pts).reshape(-1, 3), np.array(arcs)


def _gauss(a: np.ndarray, sigma: float) -> np.ndarray:
    r = int(4.0 * sigma + 0.5)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    p = np.pad(a, r, mode="symmetric")
    t = sum(k[i] * p[i:i + a.shape[0], :] for i in range(2 * r + 1))
    return sum(k[i] * t[:, i:i + a.shape[1]] for i in range(2 * r + 1))


def _vnoise(P: np.ndarray, cell: float) -> np.ndarray:
    """value noise on a 3-D lattice (smooth trilinear), about -1..1"""
    g = P / cell
    i0 = np.floor(g).astype(np.int64)
    f = g - i0
    f = f * f * (3.0 - 2.0 * f)

    def h(ix, iy, iz):
        v = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
        v = (v ^ (v >> 13)) * 1274126177
        return ((v & 0xFFFF) / 65535.0) * 2.0 - 1.0
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = ((f[..., 0] if dx else 1.0 - f[..., 0]) * (f[..., 1] if dy else 1.0 - f[..., 1])
                     * (f[..., 2] if dz else 1.0 - f[..., 2]))
                out = out + w * h(i0[..., 0] + dx, i0[..., 1] + dy, i0[..., 2] + dz)
    return out


def nearest_fill(img: np.ndarray, filled: np.ndarray) -> np.ndarray:
    """every empty texel takes the colour of its nearest filled one (jump flooding), so no mip level reads black"""
    H, W = filled.shape
    yy, xx = np.mgrid[0:H, 0:W]
    yy, xx = yy.astype(np.int32), xx.astype(np.int32)
    sy = np.where(filled, yy, -1).astype(np.int32)
    sx = np.where(filled, xx, -1).astype(np.int32)
    d2 = np.where(filled, 0, np.iinfo(np.int32).max).astype(np.int32)
    step = 1 << max(int(math.log2(max(H, W))) - 1, 0)
    steps = []
    while step >= 1:
        steps.append(step)
        step //= 2
    for step in steps + [1]:
        for dy in (-step, 0, step):
            for dx in (-step, 0, step):
                if dy == 0 and dx == 0:
                    continue
                y0, y1, x0, x1 = max(0, -dy), H - max(0, dy), max(0, -dx), W - max(0, dx)
                csy, csx = sy[y0 + dy:y1 + dy, x0 + dx:x1 + dx], sx[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
                ty, tx = yy[y0:y1, x0:x1], xx[y0:y1, x0:x1]
                cd = (csy - ty) ** 2 + (csx - tx) ** 2
                better = (csy >= 0) & (cd < d2[y0:y1, x0:x1])
                if not better.any():
                    continue
                vy, vx = csy[better], csx[better]
                sy[y0:y1, x0:x1][better] = vy
                sx[y0:y1, x0:x1][better] = vx
                d2[y0:y1, x0:x1][better] = cd[better]
    out = img.copy()
    empty = ~filled & (sy >= 0)
    out[empty] = img[sy[empty], sx[empty]]
    return out


def paint(tex: Texels, lay: Layout, bakes: dict, C: dict, arm) -> np.ndarray:
    """the uniform's map (N, N, 3), sRGB 0..1, row 0 = v 0. `C`: the palette, sRGB 0..1 (shirt, trousers, shoes, skin, stripe,
    buttons, laces)"""
    pos, nlo, fid = tex.pos, tex.nrm, tex.fid
    on = fid >= 0
    K = np.full(fid.shape, -1, np.int16)
    K[on] = lay.face_kind[fid[on]]
    kid = lay.kind
    tri_kind = lay.face_kind[tex.tri_face]
    Pt = tex.tri_pos
    X, Y, Z = pos[..., 0], pos[..., 1], pos[..., 2]
    neck_z = float(_bone(arm, "Neck")[2])
    spine_z = float(_bone(arm, "Spine")[2])
    col = {"shirt": _lin(C["shirt"]), "trousers": _lin(C["trousers"]), "shoe": _lin(C["shoes"]), "skin": _lin(C["skin"]),
           "stripe": _lin(C["stripe"]), "button": _lin(C["buttons"]), "lace": _lin(C["laces"])}
    base_of = {"trousers": "trousers", "piping": "stripe", "shoe": "shoe", "lace": "lace", "hand": "skin", "button": "button"}
    img = np.zeros(pos.shape, np.float32)
    for i, k in enumerate(lay.kind_names):
        img[K == i] = col[base_of.get(k, "shirt")]   # shirt, pockets, flaps, epaulettes, misc: the shirt's
    shirtish = np.isin(K, [kid(k) for k in ("shirt", "pocket", "flap", "epaulette")])
    trou = K == kid("trousers")
    shoe = K == kid("shoe")

    # a leg's stripe: a piping piece where Tripo modelled one; along the slit it left in its place on the other leg
    ttri = tri_kind == kid("trousers")
    tz_lo, tz_hi = float(Pt[ttri][..., 2].min()), float(Pt[ttri][..., 2].max())
    bp, _arc = _boundary(Pt[ttri], 0.0008)
    piping = Pt[tri_kind == kid("piping")].reshape(-1, 3)
    for s, leg in ((1.0, "left"), (-1.0, "right")):
        if len(piping) and np.sign(piping[:, 0].mean()) == s:
            print(TAG, f"{leg} leg: the stripe is Tripo's piping piece")
            continue
        sl = bp[(bp[:, 0] * s > SLIT_MIN_X) & (bp[:, 2] > tz_lo + SLIT_FROM_HEM) & (bp[:, 2] < tz_hi - WAIST_BAND)]
        if len(sl) < 20:
            print(TAG, f"{leg} leg: no piping and no slit, no stripe")
            continue
        cl = []                   # the slit's centre line: its two edges averaged per height, then densified
        for z0 in np.arange(sl[:, 2].min(), sl[:, 2].max() + 0.004, 0.004):
            q = sl[np.abs(sl[:, 2] - z0) < 0.003]
            if len(q):
                cl.append(q.mean(0))
        cl = np.array(cl)
        dense = np.concatenate([np.linspace(cl[i], cl[i + 1], 8, endpoint=False) for i in range(len(cl) - 1)] + [cl[-1:]])
        reach = STRIPE_HALF + 0.001
        m = trou & (X * s > SLIT_MIN_X) & np.all((pos >= dense.min(0) - reach) & (pos <= dense.max(0) + reach), axis=-1)
        ys, xs = np.nonzero(m)
        dd, _ = _nearest(dense, pos[ys, xs])
        a = np.clip((STRIPE_HALF + 0.0003 - dd) / 0.0006, 0.0, 1.0)[:, None]
        img[ys, xs] = img[ys, xs] * (1.0 - a) + col["stripe"] * a
        print(TAG, f"{leg} leg: stripe along Tripo's slit, {int((a > 0.5).sum())} texels, centre line {len(cl)} points")

    # shading from the source: the occlusion (volume and creases) and the fold detail the light mesh lost
    nhi = bakes["normal"]
    up_detail = np.clip(nhi[..., 2] - nlo[..., 2], -0.6, 0.6)
    k_long = np.where(shoe | (K == kid("lace")), 0.85, K_LONG).astype(np.float32)
    hemi = 1.0 - K_HEMI + K_HEMI * (nhi[..., 2] * 0.5 + 0.5) * 1.15
    shade = ((1.0 - k_long * (1.0 - bakes["ao_long"])) * (1.0 - K_SHORT * (1.0 - bakes["ao_short"])) * (1.0 + 0.45 * up_detail)
             * hemi)
    # convexity from the source's normals: ridges a touch lighter, creases darker
    g = np.zeros(Z.shape, np.float32)
    for ax in (1, 0):
        pn, pp, same = np.roll(nhi, -1, ax), np.roll(pos, -1, ax), np.roll(fid, -1, ax) >= 0
        dp = pp - pos
        l2 = (dp * dp).sum(-1)
        ok = on & same & (l2 > 1e-12) & (l2 < 4e-6)
        g[ok] += ((pn - nhi) * dp).sum(-1)[ok] / l2[ok] * 0.004
    shade *= 1.0 + np.clip(_gauss(g, 0.8), -0.25, 0.25) * 0.6
    img *= shade[..., None].astype(np.float32)

    # cloth: a fine grain (poplin on the shirt), a twill on the trousers along the island's upright axis
    grain = np.zeros(Z.shape, np.float32)
    P64 = pos[on].astype(np.float64)
    grain[on] = (_vnoise(P64, 0.0011) * 0.7 + _vnoise(P64, 0.006) * 0.5).astype(np.float32)
    grain /= max(float(grain[on].std()), 1e-6)
    vv, uu = np.mgrid[0:fid.shape[0], 0:fid.shape[1]]
    twill = np.sin((uu + vv) * (2.0 * math.pi / 3.0)).astype(np.float32)
    img[shirtish] *= (1.0 + 0.025 * grain[shirtish])[:, None]
    img[trou] *= (1.0 + 0.03 * twill[trou] + 0.015 * grain[trou])[:, None]
    img[shoe] *= (1.0 + 0.02 * grain[shoe])[:, None]

    # stitches: a dashed tone-on-tone line just inside the edges
    def stitch(kinds, inset, where=None, pitch=0.0028, width=0.00045, dark=0.78) -> int:
        ids = [kid(k) for k in kinds]
        pts, arc = _boundary(Pt[np.isin(tri_kind, ids)], 0.0004)
        if where is not None:
            keep = where(pts)
            pts, arc = pts[keep], arc[keep]
        if not len(pts):
            return 0
        reach = inset + width
        m = np.isin(K, ids) & np.all((pos >= pts.min(0) - reach) & (pos <= pts.max(0) + reach), axis=-1)
        ys, xs = np.nonzero(m)
        dd, ii = _nearest(pts, pos[ys, xs])
        a = np.clip(1.0 - np.abs(dd - inset) / width, 0.0, 1.0) * (((arc[ii] / pitch) % 1.0) < 0.6)
        img[ys, xs] *= (1.0 - a[:, None] * (1.0 - dark))
        return int((a > 0.5).sum())

    print(TAG, "stitch texels: pockets", stitch(["pocket", "flap"], 0.0016), "epaulettes", stitch(["epaulette"], 0.0014),
          "waist", stitch(["trousers"], 0.0022, where=lambda p: p[:, 2] > tz_hi - WAIST_BAND),
          "hems", stitch(["trousers"], 0.0022, where=lambda p: p[:, 2] < tz_lo + HEM_BAND))
    # the placket: two stitch lines either side of the buttons' line, from the collar down to the waist
    bc = Pt[tri_kind == kid("button")].reshape(-1, 3)
    front_b = bc[(np.abs(bc[:, 0]) < 0.02) & (bc[:, 1] < -0.03)]
    if len(front_b) > 3:
        fit = np.polyfit(front_b[:, 2], front_b[:, 0], 1)
        xl = np.polyval(fit, Z)
        band = (K == kid("shirt")) & (Y < -0.02) & (Z > spine_z) & (Z < neck_z - 0.02)
        for off in (-PLACKET_HALF, PLACKET_HALF):
            a = np.clip(1.0 - np.abs(X - xl - off) / 0.00045, 0.0, 1.0) * (((Z / 0.0028) % 1.0) < 0.6) * band
            img *= (1.0 - a[..., None] * 0.22)
        img[band & (np.abs(X - xl) < PLACKET_HALF)] *= 1.03
        print(TAG, "placket on the buttons' line x(z) =", np.round(fit, 4).tolist())
    else:
        print(TAG, "no front buttons: no placket")
    # buttons: a highlight on the dome
    bt = K == kid("button")
    img[bt] *= (1.0 + 0.5 * np.clip(nhi[bt][:, 2] * 0.5, 0.0, 1.0) - 0.1 * (nhi[bt][:, 1] > 0))[:, None]

    return _srgb(nearest_fill(img, on))
