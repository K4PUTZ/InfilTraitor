# tripo_assemble.py — a Tripo character SEGMENTED and rigged (Tripo's segmentation + part completion + Mixamo auto-rig: one skinned mesh per part,
# 106 on the first female, 2026-10-26; ACTOR D85) -> ONE mesh per slot of ours, named, each detail weighted like the piece it sits on, the coat's
# weights fixed; exported as one GLB with the armature and every clip.
# Why: Tripo names the parts tripo_part_N; about half are hair locks, the rest buttons, pocket flaps, laces, cuff straps, a hat band..., and each part
# is skinned ON ITS OWN, so a detail drifts off its garment (the coat's pocket flaps followed the thighs while the skirt followed the hands).
# SLOTS (a slot with no part is skipped): Outfit_Coat, Outfit_Shirt, Outfit_Tie, Outfit_Trousers, Outfit_Shoes, Outfit_Hat, Body_Head, Body_Hands,
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
# (3) WEIGHTS: the coat gets tripo_common.coat_fix; a detail of a GARMENT (coat, shirt, tie, trousers, shoes, hat) takes the weights of the nearest
#     point of its garment's anchors (barycentric, after the coat fix); head, hands and hair details keep Tripo's (the fingers, the head).
# (4) Each slot is joined into one mesh named after it (vertex groups merge by name).
# Env: TRIPO_GLB, TRIPO_OUT, SLOT_OVERRIDE, RV_OUT (optional folder: slots.png, the slots coloured in rest pose, then without the coat, then the
# head without the hat; clip_<i>.png, 4 frames of each of RV_CLIPS at 3/4 and from the side), RV_CLIPS (default every action).
# Usage: blender -b -P tripo_assemble.py
import os, sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_assemble"
GLB, OUT = os.environ["TRIPO_GLB"], os.environ["TRIPO_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
SLOTS = ("Outfit_Coat", "Outfit_Shirt", "Outfit_Tie", "Outfit_Trousers", "Outfit_Shoes", "Outfit_Hat", "Body_Head", "Body_Hands", "Body_Hair")
GARMENTS = SLOTS[:6]
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
    orig = {o.name: (list(o.data.materials), [p.use_smooth for p in o.data.polygons]) for o in joined}
    pal = {"Outfit_Coat": (0.80, 0.35, 0.30), "Outfit_Shirt": (0.85, 0.55, 0.85), "Outfit_Tie": (0.95, 0.85, 0.30), "Outfit_Trousers": (0.35, 0.50, 0.85),
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
        for p, sm in zip(o.data.polygons, orig[o.name][1]):
            p.use_smooth = sm
tc.export(OUT, joined, arm)
print(f"[{TAG}] wrote {OUT}: {[o.name for o in joined]}")
