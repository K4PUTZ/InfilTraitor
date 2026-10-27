# tripo_dress.py — dress a BASE figure in the COAT and HAT of another generation of the same character (ACTOR D85). Both inputs are outputs of
# tripo_assemble.py (one mesh per slot, the same Mixamo skeleton): the base is the figure without the coat (it has the shirt sleeves and the
# full hair), the dresser the one generated with the coat and the hat. The base is shared by every version and cosmetic, so the garment is
# fitted to the BODY, never the body to the garment (Director, 2026-10-27).
# (1) COAT: each vertex moved by its own skin weights from the dresser's rest skeleton to the base's (a linear blend of base_rest @ dresser_rest^-1
#     per bone), then PUSHED OUT wherever the base's body would come through it: a coat vertex inside a body part (shirt, tie, belt, buckle,
#     trousers; a ray-parity test on their closed shells) or nearer its surface than COAT_GAP is pushed to COAT_GAP outside it, the push
#     spread over the coat as a smooth field (see the code), repeated until nothing comes through
#     (first male, 2026-10-27: the no-coat body is broader than the coat generation's, 467 of 2 068 shirt-torso vertices came through).
#     It keeps the dresser's weights (tripo_assemble already fixed the coat's).
# (2) HAT: RIGID on the head, weighted to the Head bone alone; placed by the face (the head slot's box centre), HAT_DY back and its back tilted
#     HAT_TILT down about the brow (Director, 2026-10-27, on the female: 1.5 cm back, 8 degrees); then LIFTED, and only past HAT_MAX_LIFT also
#     SCALED, until no vertex of the base's head comes through it (the male's skull is larger than under the dresser's flattened hair).
# (3) MASKS for the dressed state: Body_Hair_Hat, the hair without what the hat covers (a vertex at or above the hat's underside at its x, y);
#     Outfit_Shirt_Coated, the shirt without the faces lying inside the coat by more than COAT_GAP (hidden in every pose but costing draws).
# Out: the base's slots, Outfit_Coat, Outfit_Hat, Body_Hair_Hat, Outfit_Shirt_Coated, the base's armature and clips, as one GLB.
# Env: DRESS_BASE, DRESS_FROM, DRESS_OUT; RV_OUT (optional folder: dressed.png, 4 views and the head; motion.png, a clip), RV_CLIP.
# Usage: blender -b -P tripo_dress.py
import math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_dress"
BASE, FROM, OUT = os.environ["DRESS_BASE"], os.environ["DRESS_FROM"], os.environ["DRESS_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
COAT_GAP, SMOOTH_ITERS = 0.004, 10                       # COAT_GAP a fraction of H
HAT_DY, HAT_TILT, HAT_MAX_LIFT = 0.015, 8.0, 0.012      # HAT_DY and HAT_MAX_LIFT fractions of H, HAT_TILT degrees
UNDER_COAT = ("Outfit_Shirt", "Outfit_Tie", "Outfit_Belt", "Outfit_Buckle", "Outfit_Trousers")

bpy.ops.wm.read_factory_settings(use_empty=True)


def imp(path):
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]; arms = [o for o in new if o.type == 'ARMATURE']
    if len(arms) != 1:
        tc.fail(TAG, f"{path}: expected one armature, found {len(arms)}")
    a = arms[0]
    if a.animation_data:
        for t in a.animation_data.nla_tracks:
            t.mute = True
        a.animation_data.action = None
    a.data.pose_position = 'REST'
    # the skinned meshes only, not the importer's bone shapes
    return a, {o.name.split(".")[0]: o for o in new if o.type == 'MESH' and o.vertex_groups}, [x for x in bpy.data.actions if x not in acts]


armB, mB, actsB = imp(BASE)
armA, mA, actsA = imp(FROM)
for need, m, f in (("Outfit_Coat", mA, FROM), ("Outfit_Hat", mA, FROM), ("Body_Head", mA, FROM), ("Body_Head", mB, BASE), ("Body_Hair", mB, BASE)):
    if need not in m:
        tc.fail(TAG, f"{f} has no {need} (is it a tripo_assemble output?): {sorted(m)}")
for a in actsA:                                         # the dresser's clips are not the deliverable's
    bpy.data.actions.remove(a)
bpy.context.view_layer.update()
H = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in mB.values())


def wverts(o):
    return np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])


def set_world(o, V):
    inv = o.matrix_world.inverted()
    for v, q in zip(o.data.vertices, V):
        v.co = inv @ Vector(q)
    o.data.update()


def shell(o):
    V = wverts(o); o.data.calc_loop_triangles()
    return BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t.vertices) for t in o.data.loop_triangles])


def inside(T, p):
    """ray parity on a closed shell (Tripo's part completion makes every part one)"""
    n = 0; o = Vector(p); d = Vector((0.31, 0.17, 0.93)).normalized()
    for _ in range(64):
        h = T.ray_cast(o, d)
        if h[0] is None:
            break
        n += 1; o = h[0] + d * 1e-6
    return n % 2 == 1


def rebind(o):                                          # onto the base's armature, keeping its world shape
    mw = o.matrix_world.copy(); o.parent = armB; o.matrix_world = mw
    for md in o.modifiers:
        if md.type == 'ARMATURE':
            md.object = armB


# (1) the coat
DM = {b.name: (armB.matrix_world @ armB.data.bones[b.name].matrix_local) @ (armA.matrix_world @ b.matrix_local).inverted()
      for b in armA.data.bones if b.name in armB.data.bones}
coat = mA["Outfit_Coat"]; gn = {g.index: g.name for g in coat.vertex_groups}; CV = wverts(coat)
for i, v in enumerate(coat.data.vertices):
    acc = Vector((0, 0, 0)); ws = 0.0
    for g in v.groups:
        M = DM.get(gn[g.group])
        if M is not None and g.weight > 0:
            acc += (M @ Vector(CV[i])) * g.weight; ws += g.weight
    if ws > 0:
        CV[i] = acc[:] if ws == 1.0 else (acc / ws)[:]
# (0) THE BASE FITTED TO THE COAT, once (Director, 2026-10-27: "a gente adaptaria o modelo sem casaco primeiro, pra ser a base universal, sem
# atrapalhar tanto o casaco"; the coat should keep the geometry it was generated with). The base's SHIRT is pulled in toward its bone
# where the coat covers it (a ray away from the bone meets the coat within BASE_REACH, nearer than COAT_GAP) or where it comes through
# the coat (a ray toward the bone meets the coat within BASE_REACH): a smooth field on the shirt's welded surface, like the coat's below.
# The shirt shown between the lapels and above the collar is touched by neither ray and stays. The tie rides the shirt (each tie vertex takes
# the move of the nearest shirt vertex). The fitted shirt IS the base from here on, in every version.
def welded(V_, edges):
    key_ = {}; r_ = np.zeros(len(V_), np.int64)
    for i, q in enumerate(np.round(V_ / (1e-5 * H)).astype(np.int64)):
        r_[i] = key_.setdefault(tuple(q), len(key_))
    E_ = np.array([(r_[e.vertices[0]], r_[e.vertices[1]]) for e in edges]); E_ = E_[E_[:, 0] != E_[:, 1]]
    return r_, len(key_), E_, np.bincount(E_.ravel(), minlength=len(key_)).astype(float)


def relax(field, floor_, E_, deg_, iters):
    for _ in range(iters):
        acc = np.zeros(len(field)); np.add.at(acc, E_[:, 0], field[E_[:, 1]]); np.add.at(acc, E_[:, 1], field[E_[:, 0]])
        field = np.maximum(0.5 * field + 0.5 * np.where(deg_ > 0, acc / np.maximum(deg_, 1), field), floor_)
    return field


BASE_REACH, FIT_MAX = 0.04, 0.03                        # fractions of H: a point never moves farther than FIT_MAX (past it the fit diverged)
base_moved = 0.0
if "Outfit_Shirt" in mB:
    set_world(coat, CV); Tcoat = shell(coat); shirt = mB["Outfit_Shirt"]; SV0 = wverts(shirt)
    sr, SNR, SE, sdeg = welded(SV0, shirt.data.edges); m3s = shirt.matrix_world.to_3x3()
    # the pull is TOWARD THE BONE (the nearest point of the spine chain or of an arm), not against the shirt's normal: the faces inside the
    # collar and the hem face inward, and a pull against their normal threw them OUT (a torn collar, frilled shoulders on the first male)
    bh = lambda n: np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + n].head_local)[:])
    segs = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"), ("Neck", "Head"))]
    segs += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]
    def outward(q):
        best_ = None
        for a, b in segs:
            ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
            if best_ is None or d < best_[0]:
                best_ = (d, (q - c) / max(d, 1e-12))
        return best_[1]
    SN = np.zeros((SNR, 3)); np.add.at(SN, sr, np.array([outward(q) for q in SV0])); SN /= np.maximum(np.linalg.norm(SN, axis=1), 1e-12)[:, None]
    # the pull fades out toward the belt: nothing at its top, all of it 4 % of H above (the hem pulled in over a belt and trousers that stay
    # left a step and a notch at the waist); below, the coat is fitted instead
    btop = max(wverts(mB[n])[:, 2].max() for n in ("Outfit_Belt", "Outfit_Trousers") if n in mB) if any(n in mB for n in ("Outfit_Belt", "Outfit_Trousers")) else -1e9
    SZ = np.zeros(SNR); np.maximum.at(SZ, sr, SV0[:, 2]); fade = tc.sstep(btop, btop + 0.04 * H, SZ)
    sfield = np.zeros(SNR); sfloor = np.zeros(SNR); SV = SV0.copy(); sbest = (None, np.zeros(SNR), 0)
    for it in range(10):
        need = {}
        for i, q in enumerate(SV):
            r = sr[i]; n_ = Vector(SN[r]); p = Vector(q)
            up = Tcoat.ray_cast(p + n_ * 1e-6, n_, BASE_REACH * H); dn = Tcoat.ray_cast(p - n_ * 1e-6, -n_, BASE_REACH * H)
            d = 0.0
            if dn[0] is not None and (up[0] is None or dn[3] < up[3]):
                d = dn[3] + COAT_GAP * H                 # through the coat: back inside it, by the gap
            elif up[0] is not None and up[3] < COAT_GAP * H:
                d = COAT_GAP * H - up[3]                 # under it but too near
            if d > need.get(r, 0.0):
                need[r] = d
        if sbest[0] is None or len(need) < sbest[0]:
            sbest = (len(need), sfield.copy(), it)
        elif it - sbest[2] >= 2:
            break
        if not need:
            break
        for r, d in need.items():
            sfloor[r] = min(FIT_MAX * H, max(sfloor[r], sfield[r] + d)) * fade[r]
        sfield = relax(np.maximum(sfield, sfloor), sfloor, SE, sdeg, SMOOTH_ITERS) * fade
        SV = SV0 - (sfield[:, None] * SN)[sr]
        print(f"[{TAG}] base fit pass {it + 1}: {len(need)} shirt points through or nearer than {COAT_GAP * 100:.1f} % of H under the coat; "
              f"deepest pull {sfield.max() / H * 100:.2f} % of H")
    sfield = sbest[1]; SV = SV0 - (sfield[:, None] * SN)[sr]
    print(f"[{TAG}] base fit kept pass {sbest[2]} ({sbest[0]} points left), deepest pull {sfield.max() / H * 100:.2f} % of H")
    move_s = SV - SV0; set_world(shirt, SV); base_moved = sfield.max()
    if "Outfit_Tie" in mB:
        kd_ = KDTree(len(SV0))
        for i, q in enumerate(SV0):
            kd_.insert(Vector(q), i)
        kd_.balance(); TV_ = wverts(mB["Outfit_Tie"])
        set_world(mB["Outfit_Tie"], np.array([q + move_s[kd_.find(Vector(q))[1]] for q in TV_]))


# by REGION: a coat vertex on the arm (arm-family weights >= 0.5) is fitted to the shirt's sleeves, every other one to the shirt's torso and the
# rest of UNDER_COAT. The base's arms hang nearer the body than the dresser's, so a sleeve of the shirt lies inside the coat's side under the
# arm; that contact inflated the whole coat (12 % of H and growing) when the coat's torso was fitted to the whole shirt.
ARMISH = ("Shoulder", "Arm", "Hand")


def armness(W_):
    return np.array([sum(x for g, x in w.items() if any(k in g for k in ARMISH)) / (sum(w.values()) or 1.0) for w in W_])


def sub_shell(o, keep):
    """a BVH of the faces of `o` whose vertices all satisfy `keep` (an open shell: inside = behind its normal)"""
    V = wverts(o); o.data.calc_loop_triangles(); tris = [tuple(t.vertices) for t in o.data.loop_triangles if all(keep[v] for v in t.vertices)]
    return BVHTree.FromPolygons([tuple(p) for p in V], tris) if tris else None


body_t, body_a = {}, {}
for n in UNDER_COAT:
    if n not in mB:
        continue
    if n == "Outfit_Shirt":
        am = armness(tc.read_weights(mB[n])) >= 0.5
        body_t[n + ":torso"] = sub_shell(mB[n], ~am); body_a[n + ":sleeves"] = sub_shell(mB[n], am)
    else:
        body_t[n] = sub_shell(mB[n], np.ones(len(mB[n].data.vertices), bool))
body_t = {k: v for k, v in body_t.items() if v}; body_a = {k: v for k, v in body_a.items() if v}
coat_arm = armness(tc.read_weights(coat)) >= 0.5
body = {**body_t, **body_a}
# the push is a SMOOTH field on the coat's welded surface (Tripo splits vertices along hard edges): each pass adds every coming-through
# point's push to the field, then relaxes the field over the surface (SMOOTH_ITERS Laplacian steps, a pushed point never below its own
# push), so the coat inflates evenly; a local push with a cosine falloff left lumps and tents on the first male. Small islands of the coat
# (buttons, epaulettes, the rest of its details) take the field of the nearest vertex of its main surface.
key = {}; rep_ = np.zeros(len(CV), np.int64)
for i, q in enumerate(np.round(CV / (1e-5 * H)).astype(np.int64)):
    rep_[i] = key.setdefault(tuple(q), len(key))
NR = len(key); E = np.array([(rep_[e.vertices[0]], rep_[e.vertices[1]]) for e in coat.data.edges]); E = E[E[:, 0] != E[:, 1]]
deg = np.bincount(E.ravel(), minlength=NR).astype(float)
isl = tc.welded_islands(CV, coat.data.edges, H); main = np.bincount(isl).argmax(); on_main = isl == main
mi = np.nonzero(on_main)[0]; kd = KDTree(len(mi))
for k, i in enumerate(mi):
    kd.insert(Vector(CV[i]), k)
kd.balance(); stick = np.array([i if on_main[i] else mi[kd.find(Vector(CV[i]))[1]] for i in range(len(CV))])
set_world(coat, CV); m3 = coat.matrix_world.to_3x3()        # the field is a DISTANCE along the coat's own outward normal: a vector field
NRM = np.zeros((NR, 3))                                         # smoothed across a thin sleeve mixed its two sides' opposite pushes and diverged
np.add.at(NRM, rep_, np.array([(m3 @ v.normal)[:] for v in coat.data.vertices])); NRM /= np.maximum(np.linalg.norm(NRM, axis=1), 1e-12)[:, None]
orig = CV.copy(); field = np.zeros(NR); floor_ = np.zeros(NR); best = (None, None, 0)    # the pass with the fewest left, its field
for it in range(12):
    need = {}
    for i in mi:
        q = CV[i]; p = Vector(q)
        for T in (body_a if coat_arm[i] else body_t).values():
            loc, nrm, _f, dist = T.find_nearest(p, 0.05 * H)
            if loc is None:
                continue
            ins = (p - loc).dot(Vector(nrm)) < 0
            if ins or dist < COAT_GAP * H:
                out_ = (p - loc).normalized() if not ins and dist > 1e-9 else Vector(nrm).normalized()
                if out_.dot(Vector(nrm)) < 0:
                    out_ = Vector(nrm).normalized()
                r = rep_[i]; d = float(np.array(((loc + out_ * COAT_GAP * H) - p)[:]) @ NRM[r])   # how far out along the coat's normal
                if d > need.get(r, 0.0):
                    need[r] = d
    if not need:
        break
    if best[0] is None or len(need) < best[0]:
        best = (len(need), field.copy(), it)
    elif it - best[2] >= 2:                              # no better for two passes: what is left does not yield to a push along the coat's
        break                                            # normal (its lining faces the body), keep the best
    if not any(d > 1e-6 * H for d in need.values()):
        break
    for r, d in need.items():
        floor_[r] = min(FIT_MAX * H, max(floor_[r], field[r] + d))
    field = np.maximum(field, floor_)
    for _ in range(SMOOTH_ITERS):
        acc = np.zeros(NR); np.add.at(acc, E[:, 0], field[E[:, 1]]); np.add.at(acc, E[:, 1], field[E[:, 0]])
        field = np.maximum(0.5 * field + 0.5 * np.where(deg > 0, acc / np.maximum(deg, 1), field), floor_)
    CV = orig + (field[:, None] * NRM)[rep_[stick]]
    print(f"[{TAG}] coat fit pass {it + 1}: {len(need)} surface points came through the body or sat nearer than {COAT_GAP * 100:.1f} % of H; "
          f"largest push {field.max() / H * 100:.2f} % of H")
field = best[1] if best[1] is not None else field; CV = orig + (field[:, None] * NRM)[rep_[stick]]
print(f"[{TAG}] coat fit kept pass {best[2]} ({best[0]} points left within {COAT_GAP * 100:.1f} % of H), largest push {field.max() / H * 100:.2f} % of H")
set_world(coat, CV); rebind(coat)
left = 0
for i in range(0, len(CV), 3):
    for T in (body_a if coat_arm[i] else body_t).values():
        loc, nrm, _f, _d = T.find_nearest(Vector(CV[i]), 0.05 * H)
        left += loc is not None and (Vector(CV[i]) - loc).dot(Vector(nrm)) < 0
print(f"[{TAG}] coat on the base: {left} sampled vertices still inside the body (every third vertex checked)")

# (2) the hat
hat = mA["Outfit_Hat"]; HV = wverts(hat)
fa, fb = wverts(mA["Body_Head"]), wverts(mB["Body_Head"])
HV += ((fb.min(0) + fb.max(0)) - (fa.min(0) + fa.max(0))) / 2.0
HV[:, 1] += HAT_DY * H
lo_, hi_ = HV.min(0), HV.max(0); piv = np.array([(lo_[0] + hi_[0]) / 2, lo_[1] + 0.25 * (hi_[1] - lo_[1]), lo_[2] + 0.25 * (hi_[2] - lo_[2])])
R = np.array(Matrix.Rotation(math.radians(-HAT_TILT), 3, 'X')); HV = (HV - piv) @ R.T + piv
headV = fb


def through(V_):
    """base head vertices above the hat's underside at their x, y that are not inside it"""
    set_world(hat, V_); T = shell(hat); n = 0
    for q in headV[::2]:
        h = T.ray_cast(Vector((q[0], q[1], q[2] - H)), Vector((0, 0, 1)), 2 * H)
        if h[0] is not None and q[2] > h[0].z and not inside(T, q):
            n += 1
    return n


base_hat = HV.copy(); lift = 0.0; scale = 1.0; n0 = through(HV)
while through(HV) > 0 and lift < HAT_MAX_LIFT * H:
    lift += 0.001 * H; HV = base_hat + np.array([0, 0, lift])
ctr = (HV.min(0) + HV.max(0)) / 2; bottom = HV[:, 2].min()
while through(HV) > 0 and scale < 1.3:
    scale += 0.01; HV = (base_hat + np.array([0, 0, lift]) - [ctr[0], ctr[1], bottom]) * scale + [ctr[0], ctr[1], bottom]
n1 = through(HV)
print(f"[{TAG}] hat: {n0} head vertices came through it as placed; lifted {lift / H * 100:.1f} % of H, scaled x{scale:.2f} -> {n1} left")
set_world(hat, HV); rebind(hat); tc.write_weights(hat, [{"mixamorig:Head": 1.0}] * len(hat.data.vertices))

# (3) the masks
def masked_copy(o, name, dead_vert):
    c = o.copy(); c.data = o.data.copy(); c.name = name; c.data.name = name; bpy.context.scene.collection.objects.link(c)
    bm = bmesh.new(); bm.from_mesh(c.data); bm.verts.ensure_lookup_table()
    dead = [f for f in bm.faces if dead_vert(f)]; bmesh.ops.delete(bm, geom=dead, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS'); bm.to_mesh(c.data); bm.free(); c.data.update()
    return c, len(dead)


Th = shell(hat); hairV = wverts(mB["Body_Hair"])
cov = [(lambda h: h[0] is not None and q[2] > h[0].z - 0.002 * H)(Th.ray_cast(Vector((q[0], q[1], q[2] - H)), Vector((0, 0, 1)), 2 * H)) for q in hairV]
hh, nd = masked_copy(mB["Body_Hair"], "Body_Hair_Hat", lambda f: any(cov[v.index] for v in f.verts))
print(f"[{TAG}] hair mask: {nd} of {len(mB['Body_Hair'].data.polygons)} hair faces under the hat")
extra = [hh]
if "Outfit_Shirt" in mB:
    Tc = shell(coat); SV = wverts(mB["Outfit_Shirt"])
    deep = [inside(Tc, q) and Tc.find_nearest(Vector(q))[3] > COAT_GAP * H for q in SV]
    sc_, nd = masked_copy(mB["Outfit_Shirt"], "Outfit_Shirt_Coated", lambda f: all(deep[v.index] for v in f.verts))
    print(f"[{TAG}] shirt mask: {nd} of {len(mB['Outfit_Shirt'].data.polygons)} shirt faces deep inside the coat"); extra.append(sc_)
for o in mA.values():
    if o not in (coat, hat):
        bpy.data.objects.remove(o)
bpy.data.objects.remove(armA)
coat.name = coat.data.name = "Outfit_Coat"; hat.name = hat.data.name = "Outfit_Hat"
out_objs = list(mB.values()) + [coat, hat] + extra

if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    pal = {"Outfit_Coat": (0.80, 0.35, 0.30), "Outfit_Hat": (0.30, 0.75, 0.70), "Outfit_Shirt": (0.85, 0.55, 0.85), "Outfit_Tie": (0.95, 0.85, 0.30),
           "Outfit_Belt": (0.95, 0.45, 0.10), "Outfit_Buckle": (0.95, 0.95, 0.95), "Outfit_Trousers": (0.35, 0.50, 0.85), "Outfit_Shoes": (0.45, 0.30, 0.20),
           "Body_Head": (0.90, 0.70, 0.55), "Body_Hands": (0.95, 0.60, 0.45), "Body_Hair": (0.45, 0.80, 0.35)}
    dressed = [o for o in out_objs if o.name not in ("Body_Hair", "Outfit_Shirt")]
    orig = {o.name: (list(o.data.materials), [p.use_smooth for p in o.data.polygons], [p.material_index for p in o.data.polygons]) for o in out_objs}
    base_of = {"Body_Hair_Hat": "Body_Hair", "Outfit_Shirt_Coated": "Outfit_Shirt"}
    show = {o.name: pal.get(base_of.get(o.name.split(".")[0], o.name.split(".")[0]), (0.5, 0.5, 0.5)) for o in dressed}
    cam, co = tc.setup_renders(dressed, show); files = {}
    for c_, az in enumerate((0, 35, 90, 180)):
        files[(0, c_)] = f"{RV_OUT}/d_0_{c_}.png"; tc.shot(cam, co, files[(0, c_)], az, Vector((0, 0, 0.5 * H)), 1.15 * H)
        files[(1, c_)] = f"{RV_OUT}/d_1_{c_}.png"; tc.shot(cam, co, files[(1, c_)], az, Vector((0, 0, 0.9 * H)), 0.32 * H)
    tc.sheet(2, 4, files, f"{RV_OUT}/dressed.png"); print(f"[{TAG}] sheet {RV_OUT}/dressed.png")
    clip = os.environ.get("RV_CLIP", "")
    if clip:
        if clip not in bpy.data.actions:
            tc.fail(TAG, f"no action {clip}; the base has {[a.name for a in actsB]}")
        fr = tc.render_clips(armB, "mixamorig:", H, RV_OUT, "m", [clip], cam, co)
        tc.sheet(1, 8, {(0, vi * 4 + fi): fr[(0, vi, fi)] for vi in range(2) for fi in range(4)}, f"{RV_OUT}/motion.png")
        print(f"[{TAG}] sheet {RV_OUT}/motion.png ({clip})")
        armB.data.pose_position = 'REST'
    for o in out_objs:
        o.data.materials.clear()
        for m in orig[o.name][0]:
            o.data.materials.append(m)
        for p, sm, mi in zip(o.data.polygons, orig[o.name][1], orig[o.name][2]):
            p.use_smooth = sm; p.material_index = mi
tc.export(OUT, out_objs, armB)
print(f"[{TAG}] wrote {OUT}: {[o.name for o in out_objs]}")
