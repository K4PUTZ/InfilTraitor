# tripo_assemble.py — a Tripo character SEGMENTED and rigged (Tripo's segmentation + part completion + Mixamo auto-rig: one skinned mesh per part,
# 106 on the first female, 2026-10-26; ACTOR D85) -> ONE mesh per slot of ours, named, each detail weighted like the piece it sits on, the coat's
# weights fixed; exported as one GLB with the armature and every clip.
# Why: Tripo names the parts tripo_part_N; about half are hair locks, the rest buttons, pocket flaps, laces, cuff straps, a hat band..., and each part
# is skinned ON ITS OWN, so a detail drifts off its garment (the coat's pocket flaps followed the thighs while the skirt followed the hands).
# SLOTS (a slot with no part is skipped): Outfit_Coat, Outfit_Shirt, Outfit_Tie, Outfit_Belt (cut from the trousers, below), Outfit_Trousers, Outfit_Shoes, Outfit_Hat, Body_Head, Body_Hands,
# Body_Hair. The front is -Y (glTF's +Z forward, as Blender imports it).
# (1) ANCHORS, the big pieces, from each part's bone FAMILY (Head / Torso / Arm / Hand / Leg / Foot, by summed weight) and size:
#     coat = the largest part (bbox volume) weighted to both Arm and Leg (>= 5 % each); hands, shoes = the 2 largest Hand / Foot parts; trousers =
#     the Leg parts with >= 2 % of all vertices; hat = the Head part reaching highest among those >= 12 % of H wide; head = the other Head
#     part a ray from the front meets first at nose height (the face; the hair can be larger); shirt = the largest remaining Torso + Arm part with >= 2 % of the vertices; tie = a Torso + Arm part 3x taller than wide, centred
#     (|x| < 2 % H), >= 10 % of H tall.
# (2) DETAILS: a Head detail RESTING on the hat (its vertices' rays down meet the hat more than their rays up, by > 0.1: the band; measured on the first female: band +0.20 to +0.43, hair -1.00 to 0.00) is the hat's; one
#     in front of the face (centre within 30 % of the head's width of its axis, and in its front 30 %) is the head's (eyes, brows, lips); any other
#     Head detail is hair (its rays up meet the brim). A Hand detail is the hands' (a thumb). A Head detail nearer a garment than the head, or within 1 % of H of it, is that garment's (a collar).
#     Every other detail joins the nearest GARMENT anchor (median over its vertices) that shares
#     its bone family (>= 10 %): a forearm sleeve is neither a hand nor a trouser leg. SLOT_OVERRIDE="tripo_part_85=Body_Head,..." corrects a part by hand; check the table printed at the end.
# (3) WEIGHTS: the coat gets tripo_common.coat_fix; a detail of a GARMENT (coat, shirt, tie, trousers, shoes, hat) lying ON it (within 1 % of H) takes the weights of the
#     nearest point of its garment's anchors (a detail farther off, like a forearm sleeve, keeps Tripo's) (barycentric, after the coat fix); head, hands and hair details keep Tripo's (the fingers, the head).
# (4) Each slot is joined into one mesh named after it (vertex groups merge by name).
# Env: TRIPO_GLB, TRIPO_OUT, SLOT_OVERRIDE, RV_OUT (optional folder: slots.png, the slots coloured in rest pose, then without the coat, then the
# head without the hat; clip_<i>.png, 4 frames of each of RV_CLIPS at 3/4 and from the side), RV_CLIPS (default every action).
# Usage: blender -b -P tripo_assemble.py
import math, os, sys
import numpy as np
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_assemble"
GLB, OUT = os.environ["TRIPO_GLB"], os.environ["TRIPO_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
SLOTS = ("Outfit_Coat", "Outfit_Shirt", "Outfit_Tie", "Outfit_Belt", "Outfit_Buckle", "Outfit_Trousers", "Outfit_Shoes", "Outfit_Hat", "Body_Head", "Body_Hands", "Body_Hair")
GARMENTS = SLOTS[:8]
OVR = dict(kv.split("=", 1) for kv in os.environ.get("SLOT_OVERRIDE", "").split(",") if kv)
bad = [s for s in OVR.values() if s not in SLOTS]
if bad:
    tc.fail(TAG, f"SLOT_OVERRIDE names unknown slots {bad}; the slots are {SLOTS}")
FAMILIES = (("Hand", ("Hand",)), ("Head", ("Head", "Neck")), ("Foot", ("Foot", "Toe")), ("Leg", ("UpLeg", "Leg")),
            ("Arm", ("Shoulder", "Arm")), ("Torso", ("Spine", "Hips")))


def family(bone):
    for k, keys in FAMILIES:
        if any(s in bone for s in keys):
            return k
    return "Torso"


arm, P, B, parts = tc.load(TAG, GLB)
D = {}
for o in parts:
    V = tc.world_verts(o); W = tc.read_weights(o); fam = {}
    for w in W:
        for n, x in w.items():
            f = family(n[len(P):]); fam[f] = fam.get(f, 0.0) + x
    s_ = sum(fam.values()) or 1.0
    o.data.calc_loop_triangles(); tri = [tuple(t.vertices) for t in o.data.loop_triangles]
    lo, hi = V.min(0), V.max(0)
    D[o.name] = {"o": o, "V": V, "W": W, "fam": {k: v / s_ for k, v in fam.items()}, "tri": tri, "lo": lo, "hi": hi, "size": hi - lo,
                 "ctr": (lo + hi) / 2, "n": len(V), "bvh": BVHTree.FromPolygons([tuple(p) for p in V], tri)}
H = max(d["hi"][2] for d in D.values()) - min(d["lo"][2] for d in D.values())
NV = sum(d["n"] for d in D.values())


def famw(n, *ks): return sum(D[n]["fam"].get(k, 0.0) for k in ks)
def dom(n): return max(D[n]["fam"].items(), key=lambda kv: kv[1])[0]


# (1) anchors
slot, why, free = {}, {}, set(D)


def take(names, s, reason):
    for n in names:
        slot[n] = s; why[n] = reason; free.discard(n)


c = [n for n in free if famw(n, "Arm") >= 0.05 and famw(n, "Leg") >= 0.05]
coat = max(c, key=lambda n: float(np.prod(D[n]["size"]))) if c else None
if coat:
    take([coat], "Outfit_Coat", "anchor: largest, arms + legs")
for s, f in (("Body_Hands", "Hand"), ("Outfit_Shoes", "Foot")):
    take(sorted((n for n in free if dom(n) == f), key=lambda n: (-D[n]["n"], n))[:2], s, f"anchor: 2 largest {f}")
take([n for n in free if dom(n) == "Leg" and D[n]["n"] >= 0.02 * NV], "Outfit_Trousers", "anchor: Leg, >= 2 % of the vertices")
c = [n for n in free if dom(n) == "Head" and D[n]["size"][0] >= 0.12 * H]
hat = max(c, key=lambda n: D[n]["hi"][2]) if c else None
if hat:
    take([hat], "Outfit_Hat", "anchor: Head, highest, wide")
c = [n for n in free if dom(n) == "Head"]
head = None
if c:                                                    # the FACE: the first Head part a ray from the front meets at nose height (hair may be larger)
    hz_ = (arm.matrix_world @ arm.data.bones[P + "Head"].head_local).z + 0.03 * H
    hits = [(D[n]["bvh"].ray_cast(Vector((0.0, -2.0 * H, hz_)), Vector((0, 1, 0)), 4.0 * H), n) for n in c]
    hits = [(h[3], n) for h, n in hits if h[0] is not None]
    head = min(hits)[1] if hits else max(c, key=lambda n: D[n]["n"])
if head:
    take([head], "Body_Head", "anchor: the face")
c = [n for n in free if famw(n, "Torso", "Arm") >= 0.5 and D[n]["n"] >= 0.02 * NV]
if c:
    take([max(c, key=lambda n: D[n]["n"])], "Outfit_Shirt", "anchor: largest Torso + Arm")
c = [n for n in free if famw(n, "Torso", "Arm") >= 0.5 and D[n]["size"][2] >= 3 * D[n]["size"][0] and abs(D[n]["ctr"][0]) < 0.02 * H
     and D[n]["size"][2] >= 0.1 * H]
if c:
    take([max(c, key=lambda n: D[n]["n"])], "Outfit_Tie", "anchor: tall, narrow, centred")

# the BELT is not a part: Tripo fuses it into the trousers. It is the band between two of the strongest horizontal ledges (its bottom and top
# edges: faces facing up or down, binned by 2 mm; of the 8 strongest, the pair 1.2-5 % of H apart whose band stands proudest of the trousers) within -4 %..+5 % of H around the hips; that band of the
# trousers is cut out as an anchor of its own (first female: 0.562-0.590 with the coat, 0.554-0.597 without).
def part_entry(o):
    V = tc.world_verts(o); W = tc.read_weights(o); fam = {}
    for w in W:
        for n, x in w.items():
            f = family(n[len(P):]); fam[f] = fam.get(f, 0.0) + x
    s_ = sum(fam.values()) or 1.0
    o.data.calc_loop_triangles(); tri = [tuple(t.vertices) for t in o.data.loop_triangles]
    lo, hi = V.min(0), V.max(0)
    return {"o": o, "V": V, "W": W, "fam": {k: v / s_ for k, v in fam.items()}, "tri": tri, "lo": lo, "hi": hi, "size": hi - lo,
            "ctr": (lo + hi) / 2, "n": len(V), "bvh": BVHTree.FromPolygons([tuple(p) for p in V], tri)}


def weights_from(entry, pts):
    """skin weights for world points `pts`, interpolated from the nearest point of `entry`'s surface (barycentric)"""
    T = entry["bvh"]; AV = entry["V"]; out = []
    for p in pts:
        loc, _n, fi, _d = T.find_nearest(Vector(p)); tri = entry["tri"][fi]
        bc = np.clip(np.array(barycentric_transform(loc, Vector(AV[tri[0]]), Vector(AV[tri[1]]), Vector(AV[tri[2]]),
                                                    Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))[:]), 0.0, None); bc /= bc.sum() or 1.0
        mix = {}
        for k, wk in zip(tri, bc):
            for g, x in entry["W"][k].items():
                mix[g] = mix.get(g, 0.0) + x * wk
        out.append(tc.top4(mix, P + "Hips"))
    return out


def new_skinned(name, verts, faces, W, like):
    """a new mesh object skinned to the armature like `like` (parent, Armature modifier), with weights W"""
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.parent = like.parent; o.matrix_parent_inverse = like.matrix_parent_inverse.copy()
    o.matrix_world = Matrix.Identity(4) if like.parent is None else o.matrix_world
    mw_inv = o.matrix_world.inverted()
    for v, q in zip(o.data.vertices, verts):
        v.co = mw_inv @ Vector(q)
    md = o.modifiers.new("Armature", 'ARMATURE'); md.object = arm
    tc.write_weights(o, W)
    for p_ in o.data.polygons:
        p_.use_smooth = False
    return o


# The BELT is REBUILT, not kept (Director, 2026-10-27): buckles are sold, so the buckle is a slot of its own and the strap is ours.
# (1) BUCKLE: the band's faces in the front (|x| < BUCKLE_HALF_W of the waist axis, in front of it) standing proud of the band's own surface
#     by > BUCKLE_PROUD are copied out as Outfit_Buckle (its slot: BUCKLE_SLOT, the box a buckle must fit; a replacement comes from BUCKLE_SRC).
# (2) TROUSERS: the band's vertices are pulled IN to the HIP LINE (a slimmer waist, closed, no hole). The hip line is one line r = c + b z per
#     step around the waist, fitted to the trousers' radius at 6 heights 0.4-2.4 % of H under the belt's bottom edge (the band itself stands
#     proud), its radius averaged over +-3 steps and its lean over +-6: the body's taper there, measured per figure (Director, 2026-10-27: the
#     strap follows the hip; as a cylinder on the hip's widest point it stood 1.4 % of H off the waist at the sides and 1.7 % at the back on the
#     first female).
# (3) STRAP: a closed band of STRAP_T thickness, STRAP_GAP off the hip line (pushed out only where the trousers would come through its outer
#     face), LEANING with it, between the measured edges (each sector's low and high ledges), over STRAP_STEPS steps around the waist;
#     weighted from the trousers. The buckle is tilted with the strap's lean at its angle.
BUCKLE_HALF_W, BUCKLE_PROUD = 0.035, 0.004             # fractions of H
STRAP_T, STRAP_GAP = 0.004, 0.0015                     # fractions of H
STRAP_STEPS = 96
BUCKLE_SLOT = {"max_w": 0.060, "max_h": 0.045, "max_d": 0.015, "max_tris": 500}   # fractions of H (a 1.80 m figure: 10.8 x 8.1 x 2.7 cm)


def belt_from_band(tn, to, band, LO, HI, ax, ang, NS, zlo, zhi):
    mw = to.matrix_world; V = np.array([(mw @ v.co)[:] for v in to.data.vertices])
    rad = np.linalg.norm(V[:, :2] - ax, axis=1); sec = np.array([int(ang(q)) % NS for q in V])

    def lohi(q):
        t_ = ang(q); i0 = int(t_) % NS; f_ = t_ - int(t_); i1 = (i0 + 1) % NS
        return LO[i0] * (1 - f_) + LO[i1] * f_, HI[i0] * (1 - f_) + HI[i1] * f_
    LH = np.array([lohi(q) for q in V])
    bandv = sorted({v for i in band for v in to.data.polygons[i].vertices})
    inb = np.zeros(len(V), bool); inb[bandv] = True
    # a belt is a TILTED RING: each edge is fitted with one harmonic around the waist (z = c + a cos + b sin) instead of the per-sector ledges,
    # which follow pocket edges and folds (the strap came out wavy)
    th = (np.arange(NS) + 0.5) / NS * 2 * math.pi; A_ = np.stack([np.ones(NS), np.cos(th), np.sin(th)], 1)
    for arr in (LO, HI):
        c_ = np.linalg.lstsq(A_, arr, rcond=None)[0]
        for _ in range(3):                                 # drop the sectors far off the fit, refit
            r_ = arr - A_ @ c_; keep = np.abs(r_) <= max(1e-6, 2.0 * np.median(np.abs(r_)))
            c_ = np.linalg.lstsq(A_[keep], arr[keep], rcond=None)[0]
        arr[:] = A_ @ c_
    LH = np.array([lohi(q) for q in V])
    # the trousers' radius just outside the band, per sector
    ref = np.zeros(NS)
    for i in range(NS):
        m = (sec == i) & ~inb & (((V[:, 2] < LH[:, 0]) & (V[:, 2] > LH[:, 0] - 0.015 * H)) | ((V[:, 2] > LH[:, 1]) & (V[:, 2] < LH[:, 1] + 0.015 * H)))
        ref[i] = np.median(rad[m]) if m.sum() >= 3 else np.nan
    good = ~np.isnan(ref); idx = np.arange(NS)
    ref = np.interp(idx, idx[good], ref[good], period=NS)
    rref = lambda q: np.interp(ang(q), np.arange(NS + 1), np.append(ref, ref[0]))
    # the hip line (header, (2)), read on the trousers before they are flattened
    edge = lambda arr, a: float(np.interp(a / (2 * math.pi) * NS % NS, np.arange(NS + 1), np.append(arr, arr[0])))
    hip = np.zeros((STRAP_STEPS, 2)); T0 = D[tn]["bvh"]
    for k in range(STRAP_STEPS):
        a = 2 * math.pi * k / STRAP_STEPS; d2 = np.array([math.cos(a), math.sin(a)]); zs, rs = [], []
        for z in edge(LO, a) - H * np.linspace(0.004, 0.024, 6):
            h = T0.ray_cast(Vector((ax[0] + d2[0] * 0.5 * H, ax[1] + d2[1] * 0.5 * H, z)), Vector((-d2[0], -d2[1], 0)), 0.5 * H)
            if h[0] is not None:
                zs.append(z); rs.append(0.5 * H - h[3])
        hip[k] = np.polyfit(zs, rs, 1) if len(zs) >= 3 else (0.0, rref(np.array([ax[0] + d2[0], ax[1] + d2[1], 0.0])))
    # averaged as (radius at the band's mid-height, lean): the radius over +-3 steps, the lean over +-6 (the pockets' openings under the belt
    # bend the fit, and the strap kinked where the front's upright lean met the sides')
    zm = np.array([(edge(LO, a) + edge(HI, a)) / 2.0 for a in 2 * math.pi * np.arange(STRAP_STEPS) / STRAP_STEPS])
    rm = sum(np.roll(hip[:, 1] + hip[:, 0] * zm, s) for s in range(-3, 4)) / 7.0
    hip[:, 0] = sum(np.roll(hip[:, 0], s) for s in range(-6, 7)) / 13.0; hip[:, 1] = rm - hip[:, 0] * zm
    hgrid = np.linspace(0, 2 * math.pi, STRAP_STEPS + 1); hb, hc = np.append(hip[:, 0], hip[0, 0]), np.append(hip[:, 1], hip[0, 1])
    hipr = lambda q: (lambda a: np.interp(a, hgrid, hb) * q[2] + np.interp(a, hgrid, hc))(math.atan2(q[1] - ax[1], q[0] - ax[0]) % (2 * math.pi))
    lean = np.degrees(np.arctan(-hip[:, 0]))
    print(f"[{TAG}] hip line: the strap leans in {lean.min():.1f} to {lean.max():.1f} deg (front {lean[STRAP_STEPS * 3 // 4]:.1f}, "
          f"sides {lean[0]:.1f} / {lean[STRAP_STEPS // 2]:.1f}, back {lean[STRAP_STEPS // 4]:.1f})")
    # (1) buckle
    front = -1.0                                        # glTF forward: the front is -Y
    bfaces = []
    for i in band:
        pts = [V[v] for v in to.data.polygons[i].vertices]; c = np.mean(pts, axis=0)
        if abs(c[0] - ax[0]) < BUCKLE_HALF_W * H and (c[1] - ax[1]) * front > 0 and np.linalg.norm(c[:2] - ax) > rref(c) + BUCKLE_PROUD * H:
            bfaces.append(i)
    buckle = None
    if bfaces:
        vids = sorted({v for i in bfaces for v in to.data.polygons[i].vertices}); remap = {v: k for k, v in enumerate(vids)}
        bverts = V[vids]; bf = [[remap[v] for v in to.data.polygons[i].vertices] for i in bfaces]
    # (2) flatten the band into the trousers, down to the hip line
    for v in bandv:
        q = V[v]; r = rad[v]; r0 = hipr(q)
        if r > r0:
            d = (q[:2] - ax) / max(r, 1e-9); V[v, :2] = ax + d * r0
    inv = mw.inverted()
    for v in bandv:
        to.data.vertices[v].co = inv @ Vector(V[v])
    # the band under the belt is as stiff as the belt (its leg shares to the Hips), or the thigh bends it out through the strap on a deep
    # step; blended in over 1.5 % of H below the belt so the trousers do not crease at its edge
    TW = tc.read_weights(to)
    for v in range(len(V)):
        k = 1.0 if inb[v] else float(tc.sstep(LH[v, 0] - 0.015 * H, LH[v, 0], V[v, 2])) * (V[v, 2] <= LH[v, 1])
        if k > 0:
            m = {}
            for g, x in TW[v].items():
                m[g] = m.get(g, 0.0) + x * (1 - k) if family(g[len(P):]) == "Leg" else m.get(g, 0.0) + x
                if family(g[len(P):]) == "Leg":
                    m[P + "Hips"] = m.get(P + "Hips", 0.0) + x * k
            TW[v] = tc.top4({g: x for g, x in m.items() if x > 1e-6}, P + "Hips")
    tc.write_weights(to, TW)
    to.data.update(); D[tn] = part_entry(to)
    print(f"[{TAG}] belt band: {len(band)} faces of {tn} flattened into the trousers (sector radii {ref.min():.3f}-{ref.max():.3f})")
    strap_out = make_strap(tn, LO, HI, ax, edge, hip)
    if bfaces:                                          # seated ON the new strap: tilted with its lean, its back on the strap's outer face, at its own angle
        bc_ = bverts.mean(0); a_ = math.atan2(bc_[1] - ax[1], bc_[0] - ax[0]); d2 = np.array([math.cos(a_), math.sin(a_)])
        c_, b_ = strap_out(a_); phi = -math.atan(b_)    # upright -> the strap's slope dr/dz, about the buckle's centre
        u = (bverts[:, :2] - ax) @ d2; z = bverts[:, 2]; side = bverts[:, :2] - ax - np.outer(u, d2); du, dz = u - u.mean(), z - z.mean()
        u = u.mean() + du * math.cos(phi) - dz * math.sin(phi); z = z.mean() + du * math.sin(phi) + dz * math.cos(phi)
        u += 0.0005 * H - float((u - (c_ + b_ * z)).min())
        bverts = np.column_stack([ax + side + np.outer(u, d2), z])
        bW = weights_from(D["Belt_strap"], bverts); buckle = new_skinned("Buckle_src", bverts, bf, bW, to)
        D[buckle.name] = part_entry(buckle); slot[buckle.name] = "Outfit_Buckle"; why[buckle.name] = f"the band's front faces standing proud ({len(bfaces)})"
        bs = D[buckle.name]["size"] / H; tris = len(D[buckle.name]["tri"])
        fits = bs[0] <= BUCKLE_SLOT["max_w"] and bs[2] <= BUCKLE_SLOT["max_h"] and bs[1] <= BUCKLE_SLOT["max_d"] and tris <= BUCKLE_SLOT["max_tris"]
        print(f"[{TAG}] buckle: {len(bfaces)} faces, {bs[0]*100:.1f} x {bs[2]*100:.1f} x {bs[1]*100:.1f} % of H, {tris} tris -> "
              f"{'fits' if fits else 'DOES NOT FIT'} the slot {BUCKLE_SLOT}")


def make_strap(tn, LO, HI, ax, edge, hip):
    """(3) the strap, leaning on the hip line; returns, for an angle around the waist, its outer face as (c, b): radius = c + b z"""
    N = STRAP_STEPS; T = D[tn]["bvh"]; rings = []; outer = []; off = np.zeros(N)
    # pushed out only where the trousers would come THROUGH it, over its own height: what stays inside it is hidden, and a belt loop's end
    # under it (0.4-0.5 % of H proud on the first female; it pushed the whole front out) is the loop
    for k in range(N):
        a = 2 * math.pi * k / N; d2 = np.array([math.cos(a), math.sin(a)]); b, c = hip[k]
        for z in np.linspace(edge(LO, a), edge(HI, a), 7):
            h = T.ray_cast(Vector((ax[0] + d2[0] * 0.5 * H, ax[1] + d2[1] * 0.5 * H, z)), Vector((-d2[0], -d2[1], 0)), 0.5 * H)
            if h[0] is not None:
                off[k] = max(off[k], 0.5 * H - h[3] - (c + b * z) - (STRAP_GAP + STRAP_T - 0.0005) * H)
    off = np.maximum.reduce([np.roll(off, s) for s in range(-2, 3)])     # a stiff strap: the running max, then its average (never below
    off = sum(np.roll(off, s) for s in range(-2, 3)) / 5.0               # any step's own need)
    for k in range(N):
        a = 2 * math.pi * k / N; d2 = np.array([math.cos(a), math.sin(a)]); b, c = hip[k]; c = c + off[k] + STRAP_GAP * H
        n = np.array([1.0, -b]) / math.hypot(1.0, b)     # the strap's outward normal in (radius, z): the thickness is square to its lean
        ring = []
        for z in (edge(LO, a), edge(HI, a)):
            for t in (0.0, STRAP_T * H):
                r_ = c + b * z + t * n[0]; ring.append((ax[0] + d2[0] * r_, ax[1] + d2[1] * r_, z + t * n[1]))
        rings.append([ring[0], ring[1], ring[3], ring[2]])   # inner-low, outer-low, outer-high, inner-high
        outer.append((c + STRAP_T * H * math.hypot(1.0, b), b))
    sv = [p for r in rings for p in r]; sf = []
    for k in range(N):
        a_, b_ = 4 * k, 4 * ((k + 1) % N)
        for j in range(4):
            sf.append([a_ + j, a_ + (j + 1) % 4, b_ + (j + 1) % 4, b_ + j])
    # a belt is STIFF: the trousers' thigh weights bent it into a U at the back on a deep step, so every leg share goes to their parent,
    # the Hips; the Spine shares stay (it follows the torso as it bends)
    sW = []
    for w in weights_from(D[tn], sv):
        m = {}
        for g, x in w.items():
            g = P + "Hips" if family(g[len(P):]) == "Leg" else g; m[g] = m.get(g, 0.0) + x
        sW.append(tc.top4(m, P + "Hips"))
    strap = new_skinned("Belt_strap", sv, sf, sW, to)
    D[strap.name] = part_entry(strap); slot[strap.name] = "Outfit_Belt"; why[strap.name] = "generated: the measured belt curve"
    print(f"[{TAG}] strap: {len(sf)} quads, height {np.mean(HI - LO) * 100:.1f} % of H, {STRAP_T * 100:.1f} % thick, "
          f"pushed off the hip line by up to {off.max() / H * 100:.2f} % of H")
    oa = np.array(outer + [outer[0]]); grid = np.linspace(0, 2 * math.pi, N + 1)
    return lambda a: (float(np.interp(a % (2 * math.pi), grid, oa[:, 0])), float(np.interp(a % (2 * math.pi), grid, oa[:, 1])))


hz = float(B["Hips"][2])
waist = [n for n in slot if slot[n] == "Outfit_Trousers" and D[n]["lo"][2] < hz - 0.04 * H and D[n]["hi"][2] > hz]
if waist:
    tn = max(waist, key=lambda n: D[n]["n"]); to = D[tn]["o"]; mw = to.matrix_world; m3 = mw.to_3x3()
    bins = {}
    for p in to.data.polygons:
        c = mw @ p.center
        if hz - 0.04 * H < c.z < hz + 0.05 * H and abs((m3 @ p.normal).normalized().z) > 0.7:
            k = int(round(c.z / (0.002 * H))); bins[k] = bins.get(k, 0) + 1
    led = [k for k, _ in sorted(bins.items(), key=lambda kv: -kv[1])[:8]]
    TV = np.array([(mw @ v.co)[:] for v in to.data.vertices]); ax = TV[(TV[:, 2] > hz - 0.04 * H) & (TV[:, 2] < hz + 0.05 * H)][:, :2].mean(0)
    rad = np.linalg.norm(TV[:, :2] - ax, axis=1)

    def bulge(k1, k2):                                   # the band's radius over the trousers' just above and below it: a belt stands proud
        z1, z2 = min(k1, k2) * 0.002 * H, max(k1, k2) * 0.002 * H
        inb = (TV[:, 2] > z1) & (TV[:, 2] < z2); out = ((TV[:, 2] > z1 - 0.012 * H) & (TV[:, 2] < z1)) | ((TV[:, 2] > z2) & (TV[:, 2] < z2 + 0.012 * H))
        return (np.percentile(rad[inb], 90) - np.percentile(rad[out], 90)) if inb.sum() > 8 and out.sum() > 8 else -1.0
    pairs = [(bulge(k1, k2), k1, k2) for i, k1 in enumerate(led) for k2 in led[i + 1:] if 0.012 <= abs(k1 - k2) * 0.002 <= 0.05]
    if pairs:
        _bg, a_, b_ = max(pairs)
        if True:
            zlo, zhi = min(a_, b_) * 0.002 * H - 0.002 * H, max(a_, b_) * 0.002 * H + 0.002 * H
            # the belt is not level (it rides higher at the back): each of 24 sectors around the waist finds its own two ledges within 2 % of H
            # of the global ones, smoothed around the circle; a face is cut when all its vertices lie inside its sector's band
            NS = 24; ang = lambda q: (math.atan2(q[1] - ax[1], q[0] - ax[0]) % (2 * math.pi)) / (2 * math.pi) * NS
            sb = [dict() for _ in range(NS)]
            for p in to.data.polygons:
                c = mw @ p.center
                if zlo - 0.025 * H < c.z < zhi + 0.025 * H and abs((m3 @ p.normal).normalized().z) > 0.7:
                    k = int(round(c.z / (0.002 * H))); d_ = sb[int(ang(c)) % NS]; d_[k] = d_.get(k, 0) + 1
            def ledge(d_, z0):
                ks = [(n_, k) for k, n_ in d_.items() if abs(k * 0.002 * H - z0) <= 0.02 * H]
                return max(ks)[1] * 0.002 * H if ks else z0
            LO = np.array([ledge(d_, zlo + 0.002 * H) - 0.002 * H for d_ in sb]); HI = np.array([ledge(d_, zhi - 0.002 * H) + 0.002 * H for d_ in sb])
            LO = np.maximum(LO, HI - 1.15 * (zhi - zlo))   # the belt keeps its width: a pocket's edge below it is not its bottom
            for arr in (LO, HI):
                arr[:] = (np.roll(arr, 1) + arr + np.roll(arr, -1)) / 3.0
            def inband(q):
                t_ = ang(q); i0 = int(t_) % NS; f_ = t_ - int(t_); i1 = (i0 + 1) % NS
                return LO[i0] * (1 - f_) + LO[i1] * f_ <= q[2] <= HI[i0] * (1 - f_) + HI[i1] * f_
            band = [p.index for p in to.data.polygons if all(inband(mw @ to.data.vertices[v].co) for v in p.vertices)]
            print(f"[{TAG}] belt band per sector: low {LO.min():.3f}-{LO.max():.3f}, high {HI.min():.3f}-{HI.max():.3f}")
            if band:
                belt_from_band(tn, to, band, LO, HI, ax, ang, NS, zlo, zhi)
    if "Outfit_Belt" not in slot.values():
        print(f"[{TAG}] WARNING: no belt band found on {tn}")
NV = sum(d["n"] for d in D.values())
ANCHORS = set(slot)
missing = [s for s in ("Body_Head", "Body_Hands", "Outfit_Shoes") if s not in slot.values()]
if missing:
    tc.fail(TAG, f"{GLB}: no anchor for {missing} (is this a segmented Tripo character?)")


# (2) details
def med_dist(n, m):
    pts = D[n]["V"][::max(1, D[n]["n"] // 60)]
    return float(np.median([D[m]["bvh"].find_nearest(Vector(p))[3] for p in pts]))


hd = D[head]
for n in sorted(free):
    d = D[n]; f = dom(n)
    gar = min((med_dist(n, m), m) for m in sorted(ANCHORS) if slot[m] in GARMENTS) if any(slot[m] in GARMENTS for m in ANCHORS) else None
    if f == "Head" and gar and slot[gar[1]] != "Outfit_Hat" and (gar[0] < med_dist(n, head) or gar[0] < 0.01 * H):
        take([n], slot[gar[1]], f"head-weighted, but nearest {gar[1]} (a collar)")
    elif f == "Head":
        score = 0.0
        if hat:
            T = D[hat]["bvh"]; eps = Vector((0, 0, 1e-4 * H)); up = dn = 0
            for p in d["V"]:
                v = Vector(p)
                dn += T.ray_cast(v - eps, Vector((0, 0, -1)), 0.06 * H)[0] is not None
                up += T.ray_cast(v + eps, Vector((0, 0, 1)), 0.06 * H)[0] is not None
            score = (dn - up) / d["n"]
        face = abs(d["ctr"][0] - hd["ctr"][0]) < 0.3 * hd["size"][0] and d["ctr"][1] < hd["lo"][1] + 0.3 * hd["size"][1]
        if hat and score > 0.1:
            take([n], "Outfit_Hat", f"rests on the hat (rays {score:+.2f})")
        elif face:
            take([n], "Body_Head", "in front of the face")
        else:
            take([n], "Body_Hair", f"head detail off the hat (rays {score:+.2f})")
    elif f == "Hand":
        take([n], "Body_Hands", "hand detail")
    else:
        cand = [m for m in sorted(ANCHORS) if slot[m] not in ("Body_Head", "Body_Hands")]          # a sleeve is not a hand
        cand = [m for m in cand if famw(m, f) >= 0.1] or cand                                    # nor a trouser leg: same bones
        dist, m = min((med_dist(n, m), m) for m in cand)
        take([n], slot[m], f"nearest {m} ({1000 * dist / H:.1f} per mille of H)")
for n, s in OVR.items():
    if n not in D:
        tc.fail(TAG, f"SLOT_OVERRIDE names {n}, which is not a part of {GLB}")
    slot[n] = s; why[n] = "SLOT_OVERRIDE"; ANCHORS.discard(n)

# (3) weights
W = {n: D[n]["W"] for n in D}
if coat:
    isl = tc.welded_islands(D[coat]["V"], D[coat]["o"].data.edges, H)
    handw = np.array([sum(x for k, x in w.items() if "Hand" in k) for w in W[coat]])
    fix = ~np.isin(isl, [u for u in np.unique(isl) if handw[isl == u].mean() > 0.5])
    W[coat], st = tc.coat_fix(D[coat]["V"], W[coat], B, P, H, fix)
    print(f"[{TAG}] coat {coat}: hips z {st['hz']:.3f} knee z {st['kz']:.3f} hem z {st['hem'] if st['hem'] is None else round(st['hem'], 3)}; "
          f"on the arm {st['on_arm']}; stripped of forearm/hand {st['stripped']}; skirt re-weighted {st['skirt']}")
    if st["hem"] is None:
        print(f"[{TAG}] WARNING: the coat has no skirt below the hips; only the arm rule applied")
n_moved = 0
for s in GARMENTS:
    an = sorted(n for n in ANCHORS if slot[n] == s); det = sorted(n for n in D if slot[n] == s and n not in ANCHORS)
    if not det:
        continue
    if not an:
        tc.fail(TAG, f"slot {s} has details {det} but no anchor to weight them from")
    AV, AT, AW = [], [], []
    for m in an:
        off = len(AV); AV += [Vector(p) for p in D[m]["V"]]; AT += [(a + off, b + off, c + off) for a, b, c in D[m]["tri"]]; AW += W[m]
    T = BVHTree.FromPolygons(AV, AT); u3 = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    for n in det:
        if med_dist(n, an[0]) > 0.01 * H and all(med_dist(n, m) > 0.01 * H for m in an):
            continue                                     # not ON the garment (a forearm sleeve 11 cm off the shirt's torso): keep its own weights
        new = []
        for p in D[n]["V"]:
            loc, _nrm, fi, _d = T.find_nearest(Vector(p)); tri = AT[fi]
            bc = np.clip(np.array(barycentric_transform(loc, AV[tri[0]], AV[tri[1]], AV[tri[2]], *u3)[:]), 0.0, None); bc /= bc.sum() or 1.0
            mix = {}
            for k, wk in zip(tri, bc):
                for g, x in AW[k].items():
                    mix[g] = mix.get(g, 0.0) + x * wk
            new.append(tc.top4(mix, P + "Hips"))
        W[n] = new; n_moved += 1
for n in D:
    if W[n] is not D[n]["W"]:
        tc.write_weights(D[n]["o"], W[n])
print(f"[{TAG}] {n_moved} garment details took their garment's weights")

# the table, then (4) one mesh per slot
print(f"[{TAG}] {len(D)} parts, {sum(len(d['tri']) for d in D.values())} tris, height {H:.3f}")
for s in SLOTS:
    names = sorted((n for n in D if slot[n] == s), key=lambda n: (n not in ANCHORS, -D[n]["n"]))
    if names:
        print(f"[{TAG}] {s}: {len(names)} parts, {sum(len(D[n]['tri']) for n in names)} tris")
        for n in names:
            print(f"[{TAG}]     {n:16s} {len(D[n]['tri']):5d} tris  {dom(n):5s}  {why[n]}")
joined = []
for s in SLOTS:
    names = [n for n in D if slot[n] == s]
    if not names:
        continue
    lead = D[max([n for n in names if n in ANCHORS] or names, key=lambda n: D[n]["n"])]["o"]
    bpy.ops.object.select_all(action='DESELECT')
    for n in names:
        D[n]["o"].select_set(True)
    bpy.context.view_layer.objects.active = lead
    if len(names) > 1:
        bpy.ops.object.join()
    lead.name = s; lead.data.name = s; joined.append(lead)

if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    clips = [c for c in os.environ.get("RV_CLIPS", "").split(",") if c] or [a.name for a in bpy.data.actions]
    unknown = [c for c in clips if c not in bpy.data.actions]
    if unknown:
        tc.fail(TAG, f"no action {unknown}; the file has {[a.name for a in bpy.data.actions]}")
    orig = {o.name: (list(o.data.materials), [p.use_smooth for p in o.data.polygons], [p.material_index for p in o.data.polygons]) for o in joined}
    pal = {"Outfit_Belt": (0.95, 0.45, 0.10), "Outfit_Buckle": (0.95, 0.95, 0.95), "Outfit_Coat": (0.80, 0.35, 0.30), "Outfit_Shirt": (0.85, 0.55, 0.85), "Outfit_Tie": (0.95, 0.85, 0.30), "Outfit_Trousers": (0.35, 0.50, 0.85),
           "Outfit_Shoes": (0.45, 0.30, 0.20), "Outfit_Hat": (0.30, 0.75, 0.70), "Body_Head": (0.90, 0.70, 0.55), "Body_Hands": (0.95, 0.60, 0.45),
           "Body_Hair": (0.45, 0.80, 0.35)}
    cam, co = tc.setup_renders(joined, {o.name: pal[o.name] for o in joined})
    full = Vector((0, 0, 0.5 * H)); headc = Vector((0, 0, 0.9 * H)); files = {}
    for r, (hide, ctr, ortho) in enumerate(((set(), full, 1.15 * H), ({"Outfit_Coat"}, full, 1.15 * H), ({"Outfit_Hat"}, headc, 0.32 * H))):
        for o in joined:
            o.hide_render = o.name in hide
        for c_, az in enumerate((0, 35, 90, 180)):
            files[(r, c_)] = f"{RV_OUT}/slots_{r}_{c_}.png"; tc.shot(cam, co, files[(r, c_)], az, ctr, ortho)
    for o in joined:
        o.hide_render = False
    tc.sheet(3, 4, files, f"{RV_OUT}/slots.png")
    print(f"[{TAG}] sheet {RV_OUT}/slots.png (rows: rest; without the coat; the head without the hat)")
    fr = tc.render_clips(arm, P, H, RV_OUT, "clip", clips, cam, co)
    for ci, cn in enumerate(clips):
        tc.sheet(1, 8, {(0, vi * 4 + fi): fr[(ci, vi, fi)] for vi in range(2) for fi in range(4)}, f"{RV_OUT}/clip_{ci}.png")
        print(f"[{TAG}] sheet {RV_OUT}/clip_{ci}.png ({cn})")
    for o in joined:
        o.data.materials.clear()
        for m in orig[o.name][0]:
            o.data.materials.append(m)
        for p, sm, mi in zip(o.data.polygons, orig[o.name][1], orig[o.name][2]):   # clearing the slots reset every face to slot 0
            p.use_smooth = sm; p.material_index = mi
tc.export(OUT, joined, arm)
print(f"[{TAG}] wrote {OUT}: {[o.name for o in joined]}")
