# tripo_dress.py — dress a BASE figure in the COAT and HAT of another generation of the same character (ACTOR D85). Both inputs are outputs of
# tripo_assemble.py (one mesh per slot, the same Mixamo skeleton): the base is the figure without the coat (it has the shirt sleeves and the
# full hair), the dresser the one generated with the coat and the hat. The base is shared by every version and cosmetic, so the garment is
# fitted to the BODY, never the body to the garment (Director, 2026-10-27).
# (1) COAT: each vertex moved by its own skin weights from the dresser's rest skeleton to the base's (a linear blend of base_rest @ dresser_rest^-1
#     per bone), then PUSHED OUT wherever the base's body would come through it: a coat vertex inside a body part (shirt, tie, belt, buckle,
#     trousers; a ray-parity test on their closed shells) or nearer its surface than COAT_GAP is pushed to COAT_GAP outside it, the push
#     carried to every wall around it by a field in space (see the code), repeated until nothing comes through
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
from mathutils import Matrix, Quaternion, Vector
from mathutils.geometry import barycentric_transform
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_dress"
BASE, FROM, OUT = os.environ["DRESS_BASE"], os.environ["DRESS_FROM"], os.environ["DRESS_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
# LIGHT (Director, 2026-10-27: "vamos usar como veio mesmo [...] deslocar essas zonas do casaco ligeiramente pra fora do corpo [...] coisa de
# milimetros"; the full fit, 0.4 % gap, 10 relax steps, no cap, swelled the coat out of character): a small gap, a short relax, a cap
COAT_GAP = float(os.environ.get("COAT_GAP", "0.004"))
COAT_MAX = float(os.environ.get("COAT_MAX", "0.012"))    # fractions of H; a coat point never moves farther than COAT_MAX
COAT_RADIUS = float(os.environ.get("COAT_RADIUS", "0.03"))   # a fraction of H: how far a push carries (see the coat fit)
# ONE LAPEL may go farther, to make room for a bust (Director, 2026-10-27, on the female: "deslocar a lapela da esquerda mais pra frente"):
# LAPEL_SIDE = R or L (the FIGURE's side; the female's is R, the viewer's left from the front), its coat points on the chest's front
# (in front of the waist axis, 62-82 % of H high, more than 0.5 % of H to that side) capped at LAPEL_MAX instead
LAPEL_SIDE = os.environ.get("LAPEL_SIDE", ""); LAPEL_MAX = float(os.environ.get("LAPEL_MAX", "0.03"))
HAT_DY = float(os.environ.get("HAT_DY", "0.015"))         # back (+) / forward (-), a fraction of H; per figure (the male: 0.005)
HAT_DROP = float(os.environ.get("HAT_DROP", "0"))         # down after the fit, a fraction of H (the male: 0.01, Director 2026-10-27)
HAT_TILT, HAT_MAX_LIFT = 8.0, 0.012                     # degrees; a fraction of H
COAT_FIT = os.environ.get("COAT_FIT", "1") != "0"
COAT_LONGER = float(os.environ.get("COAT_LONGER", "0.12"))   # how far the standalone coat's hem drops (C1b), a fraction of H
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
B_left_x = (armB.matrix_world @ armB.data.bones["mixamorig:LeftHand"].head_local).x
waist_y = (armB.matrix_world @ armB.data.bones["mixamorig:Spine"].head_local).y
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
# C1 (D86): a STANDALONE coat (DRESS_COAT, a Tripo garment with no rig) takes the generation's coat's place: scaled uniformly to its length
# (hem to collar top) and set on its hem height and its centre (the standalone's torso proportions match the generations' within a few % of
# its length: measured 2026-10-27, width 0.39-0.44, the waist belted to 0.34); its weights are, until C4, those of the nearest point of the
# generation's coat (barycentric), so it can be exported and animated
DRESS_COAT = os.environ.get("DRESS_COAT", "")
if DRESS_COAT:
    set_world(coat, CV); Tg = shell(coat); GW = tc.read_weights(coat); coat.data.calc_loop_triangles(); GT = [tuple(t.vertices) for t in coat.data.loop_triangles]
    before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=DRESS_COAT)
    loose = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    if not loose:
        tc.fail(TAG, f"{DRESS_COAT}: no mesh")
    LV = np.concatenate([wverts(o) for o in loose]); LF = []; off = 0
    for o in loose:
        LF += [[off + v for v in p_.vertices] for p_ in o.data.polygons]; off += len(o.data.vertices)
    glo, ghi = CV.min(0), CV.max(0); llo, lhi = LV.min(0), LV.max(0); k = (ghi[2] - glo[2]) / (lhi[2] - llo[2])
    gc = (glo + ghi) / 2; lc = (llo + lhi) / 2
    LV = (LV - [lc[0], lc[1], llo[2]]) * k + [gc[0], gc[1], glo[2]]
    for o in loose:
        bpy.data.objects.remove(o)
    u3 = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))); NW = []
    for q in LV:
        loc, _n, fi, _d = Tg.find_nearest(Vector(q)); tri = GT[fi]
        bc = np.clip(np.array(barycentric_transform(loc, Vector(CV[tri[0]]), Vector(CV[tri[1]]), Vector(CV[tri[2]]), *u3)[:]), 0.0, None); bc /= bc.sum() or 1.0
        mix = {}
        for vi, wk in zip(tri, bc):
            for g, x in GW[vi].items():
                mix[g] = mix.get(g, 0.0) + x * wk
        NW.append(tc.top4(mix, "mixamorig:Hips"))
    me = bpy.data.meshes.new("Outfit_Coat_src"); me.from_pydata([tuple(q) for q in LV], [], LF); me.update()
    nc = bpy.data.objects.new("Outfit_Coat_src", me); bpy.context.scene.collection.objects.link(nc)
    nc.parent = coat.parent; nc.matrix_world = Matrix.Identity(4); set_world(nc, LV)
    md = nc.modifiers.new("Armature", 'ARMATURE'); md.object = armA; tc.write_weights(nc, NW)
    for p_ in nc.data.polygons:
        p_.use_smooth = False
    bpy.data.objects.remove(coat); coat = nc; mA["Outfit_Coat"] = nc; CV = LV.copy()
    # C1b (Director, 2026-10-28: "extender toda a parte de baixo do casaco, pra nao ficar engruvinhado na altura do peito e da cintura"): the
    # coat below the base's neck (the Neck joint; Director, 2026-10-28, second pass: "esticar todo o comprimento", the chest and the waist
    # were still bunched with the pivot at Spine2) is stretched DOWN so its hem drops COAT_LONGER (a fraction of H); vertical only, linear
    # from the neck, so the folds keep their shape and spread; a sleeve vertex takes it by (1 - its arm weight), so the sleeves stay
    if COAT_LONGER > 0:
        piv = (armB.matrix_world @ armB.data.bones["mixamorig:Neck"].head_local).z; hem = CV[:, 2].min()
        s = COAT_LONGER * H / max(piv - hem, 1e-6)
        free = 1.0 - np.clip(np.array([sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) for w in NW]), 0, 1)
        below = CV[:, 2] < piv
        CV[below, 2] -= (piv - CV[below, 2]) * s * free[below]
        print(f"[{TAG}] coat below the neck (z {piv:.3f}) stretched x{1 + s:.3f}: hem {hem:.3f} -> {CV[:, 2].min():.3f}")
    # C2 (D86): each SLEEVE turned about its shoulder onto the base's arm (the standalone's sleeves splay wider than either figure's arms): the
    # sleeve's axis is the principal direction of its vertices (arm weight >= 0.9 on that side), the arm's the base's shoulder -> wrist line;
    # each vertex turns by that rotation scaled by its own arm weight on that side, so the torso stays and the shoulder bends smoothly
    for side in ("Left", "Right"):
        aw = np.array([sum(x for g, x in w.items() if side in g and any(k in g for k in ("Arm", "Hand", "Shoulder"))) for w in NW])
        sl = CV[aw >= 0.9]
        if len(sl) < 20:
            continue
        sh = np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + side + "Arm"].head_local)[:])
        wr = np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + side + "Hand"].head_local)[:])
        c_ = sl.mean(0); ev = np.linalg.eigh(np.cov((sl - c_).T))[1][:, -1]
        if ev @ (c_ - sh) < 0:
            ev = -ev
        tgt = (wr - sh) / np.linalg.norm(wr - sh); q = Vector(ev).rotation_difference(Vector(tgt))
        ang = math.degrees(q.angle)
        for i in np.nonzero(aw > 0)[0]:
            qi = Quaternion().slerp(q, float(aw[i]))
            CV[i] = sh + np.array((qi @ Vector(CV[i] - sh))[:])
        print(f"[{TAG}] {side} sleeve turned {ang:.1f} deg onto the arm ({len(sl)} sleeve vertices)")
    # STRAIGHT SKIRT (Director, 2026-10-28, toward the concept art: the coat falls straight from the hips, no belly): below the base's hip line
    # (the Hips joint) every skirt vertex is moved RADIALLY about the hips' vertical axis by the amount that puts the OUTER wall of its cell
    # (azimuth x height) on a straight cone: the outer radius at the hip line at that azimuth, opening SKIRT_FLARE per unit of drop. The same
    # displacement goes to every vertex of the cell, so the double wall (outer wall and lining) moves together and keeps its thickness and
    # its folds; it fades in over SKIRT_FADE of H under the hip line so the waist does not kink; sleeves (arm weight >= 0.5) are left
    SKIRT_FLARE = float(os.environ.get("SKIRT_FLARE", "0.15")); SKIRT_FADE = float(os.environ.get("SKIRT_FADE", "0.05"))
    if os.environ.get("SKIRT_STRAIGHT", "1") != "0":
        hp = np.array((armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local)[:])
        # SKIRT_FROM: the joint the straight line starts at (Hips by default; higher, e.g. Spine1, takes the waist into it: the female's front
        # edges bowed out at the waist, Director 2026-10-28)
        zh = (armB.matrix_world @ armB.data.bones["mixamorig:" + os.environ.get("SKIRT_FROM", "Hips")].head_local).z
        aw_ = np.array([sum(x for g, x in w.items() if any(k_ in g for k_ in ("Arm", "Hand", "Shoulder"))) for w in NW])
        sk = (CV[:, 2] < zh) & (aw_ < 0.5)
        d_ = CV[:, :2] - hp[:2]; r_ = np.linalg.norm(d_, axis=1); th = np.arctan2(d_[:, 1], d_[:, 0])
        NB, ZB = 48, 0.02 * H
        ab_ = ((th + math.pi) / (2 * math.pi) * NB).astype(int) % NB; zb_ = np.floor((zh - CV[:, 2]) / ZB).astype(int)
        hipr = np.zeros(NB)                                  # the outer radius at the hip line, per azimuth
        band_ = sk & (zb_ <= 1)
        np.maximum.at(hipr, ab_[band_], r_[band_])
        for _ in range(2):                                   # an empty azimuth (the front opening) takes its neighbours'
            hipr = np.where(hipr > 0, hipr, np.maximum(np.roll(hipr, 1), np.roll(hipr, -1)))
        outer = {}
        for i in np.nonzero(sk)[0]:
            key = (ab_[i], zb_[i]); outer[key] = max(outer.get(key, 0.0), r_[i])
        moved = 0.0
        for i in np.nonzero(sk)[0]:
            drop = zh - CV[i, 2]; tgt = hipr[ab_[i]] + SKIRT_FLARE * drop
            dr = (tgt - outer[(ab_[i], zb_[i])]) * min(1.0, drop / (SKIRT_FADE * H))
            CV[i, :2] += d_[i] / max(r_[i], 1e-9) * dr; moved = max(moved, abs(dr))
        # STRAIGHT SIDES (Director, 2026-10-28: "corrigir essas pregas nas laterais pra ficar mais retinho"): between the hip line and the
        # chest (Spine2) the coat's SIDES (weighted by cos^2 of the azimuth: full at the flanks, none at the front and back) take the same
        # cell displacement onto the straight line from the outer radius at the chest to the one at the hip line, fading at the chest
        zc = (armB.matrix_world @ armB.data.bones["mixamorig:Spine2"].head_local).z
        sd = (CV[:, 2] >= zh) & (CV[:, 2] < zc) & (aw_ < 0.5)
        if os.environ.get("SIDE_STRAIGHT", "1") != "0" and sd.any():
            d2 = CV[:, :2] - hp[:2]; r2 = np.linalg.norm(d2, axis=1); t2 = np.arctan2(d2[:, 1], d2[:, 0])
            a2 = ((t2 + math.pi) / (2 * math.pi) * NB).astype(int) % NB; z2 = np.floor((CV[:, 2] - zh) / ZB).astype(int)
            chr_ = np.zeros(NB); top_ = sd & (CV[:, 2] > zc - 2 * ZB); np.maximum.at(chr_, a2[top_], r2[top_])
            chr_ = np.where(chr_ > 0, chr_, hipr)
            out2 = {}
            for i in np.nonzero(sd)[0]:
                key = (a2[i], z2[i]); out2[key] = max(out2.get(key, 0.0), r2[i])
            sm = 0.0
            for i in np.nonzero(sd)[0]:
                t_ = (CV[i, 2] - zh) / (zc - zh); tgt = (1 - t_) * hipr[a2[i]] + t_ * chr_[a2[i]]
                dr = (tgt - out2[(a2[i], z2[i])]) * math.cos(t2[i]) ** 2 * min(1.0, (zc - CV[i, 2]) / (SKIRT_FADE * H))
                CV[i, :2] += d2[i] / max(r2[i], 1e-9) * dr; sm = max(sm, abs(dr))
            print(f"[{TAG}] straight sides: {int(sd.sum())} vertices between the hips and the chest, largest move {sm / H * 100:.2f} % of H")
        print(f"[{TAG}] straight skirt: {int(sk.sum())} vertices under the hip line (z {zh:.3f}), flare {SKIRT_FLARE}, largest move {moved / H * 100:.2f} % of H")
    set_world(nc, CV)
    print(f"[{TAG}] standalone coat {os.path.basename(DRESS_COAT)}: {len(LV)} vertices, scaled x{k:.3f} to the generation's coat "
          f"(length {ghi[2] - glo[2]:.3f}, hem z {glo[2]:.3f}); weights from it until C4")
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
# the push is a field IN SPACE, not on the surface (Director, 2026-10-27: "deslocando um conjunto de nós que incluam todas as paredes envolvidas
# simultaneamente, de maneira mais coesa"): a push along each vertex's normal moved the coat's walls apart (it is double: its inner wall faces
# the body) and rippled its surface. Each coat point that sits inside the body is a CONSTRAINT: how far it must go (out by COAT_GAP),
# AWAY FROM ITS BONE (the nearest point of the spine chain or of an arm). Every coat vertex then moves by the strongest constraint around it,
# faded over COAT_RADIUS (a cosine), so the outer wall, the inner wall and an edge at one place move as one; repeated while points remain,
# each point's total capped at COAT_MAX (LAPEL_MAX in the lapel zone).
bh_ = lambda n: np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + n].head_local)[:])
SEGS = [(bh_(a), bh_(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
SEGS += [(bh_(sd + a), bh_(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]


def away(q):
    best_ = None
    for a, b in SEGS:
        ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
        if best_ is None or d < best_[0]:
            best_ = (d, (q - c) / max(d, 1e-12))
    return best_[1]


orig = CV.copy(); RP = CV; cap = np.full(len(CV), COAT_MAX * H)
if LAPEL_SIDE:
    sgn = -np.sign(B_left_x) if LAPEL_SIDE.upper() == "R" else np.sign(B_left_x)
    lap = (CV[:, 0] * sgn > 0.005 * H) & (CV[:, 1] < waist_y) & (CV[:, 2] > 0.62 * H) & (CV[:, 2] < 0.82 * H)
    cap[lap] = LAPEL_MAX * H
    print(f"[{TAG}] lapel {LAPEL_SIDE}: {int(lap.sum())} coat vertices may move up to {LAPEL_MAX * 100:.1f} % of H")
total = np.zeros_like(CV); left_ = None
# FIT_BACK (Director, 2026-10-28, on the female's back: "empurrar (a parede dupla do casaco) um pouquinho pra longe do corpo [...] escondendo
# a camisa e a calca"): only coat points behind the spine or on the flanks (y > the Spine joint's - 3 % of H) are constraints, so the push
# stays on the back. A body piece can also come out BETWEEN the coat's vertices (its big faces), which no coat point sees: there the BODY's
# vertices are the test, each cast from its bone outward through the coat; one lying past the coat's OUTERMOST wall on that ray (or nearer
# it than COAT_GAP) makes a constraint at that outer hit, pushing it out by the excess
FIT_BACK = os.environ.get("FIT_BACK", "0") != "0"
BODY_Q = np.concatenate([wverts(mB[n])[::2] for n in UNDER_COAT if n in mB]) if FIT_BACK else np.zeros((0, 3))
hips_z = (armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local).z
BODY_Q = BODY_Q[(BODY_Q[:, 1] > waist_y - 0.03 * H) & (BODY_Q[:, 2] > hips_z - 0.05 * H)]   # the legs leave through the skirt's open bottom


def bone_pt(q):
    best_ = None
    for a, b in SEGS:
        ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
        if best_ is None or d < best_[0]:
            best_ = (d, c)
    return best_[1]
for it in range(12 if COAT_FIT else 0):
    cons = []                                            # (position, push vector)
    for i in range(len(CV)):
        if FIT_BACK and CV[i, 1] <= waist_y - 0.03 * H:          # the back and the flanks (the hip spots sat at the side)
            continue
        p = Vector(CV[i])
        for T in (body_a if coat_arm[i] else body_t).values():
            loc, nrm, _f, dist = T.find_nearest(p, 0.05 * H)
            if loc is None:
                continue
            ins = (p - loc).dot(Vector(nrm)) < 0                # INSIDE only: the lining lies near the body by design, and as a constraint
            if ins:                                              # it held ~1 000 points at the cap on the female
                u = away(CV[i]); need = COAT_GAP * H + dist      # out of the body, by the gap, along u
                if need > 1e-6 * H:
                    cons.append((CV[i].copy(), u * need))
                break
    if FIT_BACK:
        set_world(coat, CV); TC = shell(coat); nb = 0
        for q in BODY_Q:
            c = bone_pt(q); dv = q - c; dq = np.linalg.norm(dv)
            if dq < 1e-6:
                continue
            u = dv / dq; o = Vector(c.tolist()); last = None; far = 0.0
            while True:
                hit = TC.ray_cast(o, Vector(u.tolist()), dq + 0.05 * H - far)
                if hit[0] is None:
                    break
                far += (hit[0] - o).length + 1e-5; last = hit[0]; o = hit[0] + Vector(u.tolist()) * 1e-5
            if last is not None and far < dq + COAT_GAP * H:
                cons.append((np.array(last[:]), u * (dq + COAT_GAP * H - far))); nb += 1
        print(f"[{TAG}] coat fit pass {it + 1}: {nb} body points through the coat's outer wall")
    left_ = len(cons)
    print(f"[{TAG}] coat fit pass {it + 1}: {len(cons)} coat points inside the body")
    if not cons:
        break
    kdc = KDTree(len(cons))
    for k, (q, _v) in enumerate(cons):
        kdc.insert(Vector(q), k)
    kdc.balance(); move = np.zeros_like(CV)
    for i in range(len(CV)):
        best_ = 0.0
        for (_c, k, r) in kdc.find_range(Vector(CV[i]), COAT_RADIUS * H):
            w = 0.5 * (1 + math.cos(math.pi * r / (COAT_RADIUS * H))); v = cons[k][1] * w
            if np.linalg.norm(v) > best_:
                best_ = np.linalg.norm(v); move[i] = v
    room = np.maximum(cap - np.linalg.norm(total, axis=1), 0.0); ln = np.linalg.norm(move, axis=1)
    move *= np.minimum(1.0, room / np.maximum(ln, 1e-12))[:, None]
    if np.abs(move).max() < 1e-6 * H:
        break
    total += move; CV = orig + total
print(f"[{TAG}] coat fit: {left_} points left, largest move {np.linalg.norm(total, axis=1).max() / H * 100:.2f} % of H")
set_world(coat, CV)
# C3b SETTLE (Director, 2026-10-28: "a questao do peso, e bloquear a roupa de baixo pra nao atravessarem"): a Blender cloth run with gravity,
# the coat's rest lengths as fitted (so it keeps its cut), the shoulders, collar and sleeves PINNED (above the Spine2 joint, or arm weight
# >= 0.5, fading over SETTLE_FADE of H below it, and every loose island), the shirt, tie and trousers colliders at COAT_GAP, single sided
# (SETTLE_COLLIDE; NOT the belt: measured 2026-10-28, the belt alone threw the female's hem up 24 % of H, it rings the coat's belted waist);
# the cloth stiff (SETTLE_STIFF 600: at 40 it stretched 40 % of H under gravity alone); COAT_SETTLE frames (0 = off, the default
# until the male's skirt stops tearing open: 40 frames cleared the female's hips, 2026-10-28)
HEM_MASK = None                                           # the hem band's coat vertices, painted in the review renders
COAT_SETTLE = int(os.environ.get("COAT_SETTLE", "0")); SETTLE_FADE = float(os.environ.get("SETTLE_FADE", "0.08"))
if COAT_SETTLE > 0:
    sc = bpy.context.scene; me = bpy.data.meshes.new("settle")
    me.from_pydata([tuple(q) for q in CV], [], [list(p_.vertices) for p_ in coat.data.polygons]); me.update()
    so = bpy.data.objects.new("settle", me); sc.collection.objects.link(so)
    top = (armB.matrix_world @ armB.data.bones["mixamorig:Spine2"].head_local).z
    pin = np.clip(1.0 - (top - CV[:, 2]) / (SETTLE_FADE * H), 0.0, 1.0); pin[coat_arm] = 1.0
    # a loose ISLAND (the back belt, a strap, a pocket flap: the coat is 10 islands) hangs from nothing and falls away: it stays put
    par = list(range(len(CV)))

    def root(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for e_ in coat.data.edges:
        par[root(e_.vertices[0])] = root(e_.vertices[1])
    isl = np.array([root(i) for i in range(len(CV))]); main_ = np.bincount(isl).argmax()
    pin[isl != main_] = 1.0
    vg = so.vertex_groups.new(name="pin")
    for i, w in enumerate(pin):
        if w > 0:
            vg.add([i], float(w), 'REPLACE')
    # a weighted HEM BAND (Director, 2026-10-28: "colar uma tira de couro na parte de baixo toda, com peso puxando o casaco"): Blender cloth
    # has one mass for every vertex and its force fields did not move the hem (a plane FORCE field at 5 and 20: hem within 0.3 % of H), so the
    # band is a GOAL: the HEM PIECE (tripo_common.hem_plane: HEM_BAND of the coat's length above the hem, the front lowered HEM_FRONT) is pinned at HEM_PIN to a target that a Displace modifier (keyed 0 -> HEM_DROP
    # of H over the first half of the run) lowers under the cloth; the band is drawn down and the cloth above stretches by its stiffness
    HEM_BAND = float(os.environ.get("HEM_BAND", "0.06")); HEM_DROP = float(os.environ.get("HEM_DROP", "0"))
    HEM_PIN = float(os.environ.get("HEM_PIN", "0.5"))
    if HEM_DROP > 0:
        cl_ = np.ptp(CV[:, 2]); band = HEM_BAND * cl_
        hp0, hn = tc.hem_plane(CV, band, float(os.environ.get("HEM_FRONT", "0.02")) * cl_)
        bw = ((CV - hp0) @ hn < 0).astype(float); bw[pin >= 1] = 0.0; HEM_MASK = bw > 0
        vb = so.vertex_groups.new(name="band")
        for i in np.nonzero(bw > 0)[0]:
            vb.add([int(i)], float(bw[i]), 'REPLACE'); vg.add([int(i)], max(float(pin[i]), HEM_PIN * float(bw[i])), 'REPLACE')
        dm = so.modifiers.new("hem", 'DISPLACE'); dm.direction = 'Z'; dm.vertex_group = "band"; dm.mid_level = 0.0
        dm.strength = 0.0; dm.keyframe_insert("strength", frame=1)
        dm.strength = -HEM_DROP * H; dm.keyframe_insert("strength", frame=max(2, COAT_SETTLE // 2))
        print(f"[{TAG}] hem band: {int((bw > 0).sum())} coat vertices in the hem piece ({band / H * 100:.1f} % of H), drawn {HEM_DROP * 100:.1f} % of H down at pin {HEM_PIN}")
    cm = so.modifiers.new("Cloth", 'CLOTH'); cs = cm.settings
    # SETTLE_MASS, kg per vertex: Blender cloth has no per-vertex mass, so "a base mais pesada, pra esticar mais o tecido todo" (Director,
    # 2026-10-28) is a heavier coat against the same stiffness
    cs.quality = 15; cs.mass = float(os.environ.get("SETTLE_MASS", "0.15"))
    cs.tension_stiffness = cs.compression_stiffness = float(os.environ.get("SETTLE_STIFF", "600")); cs.shear_stiffness = 200.0
    cs.bending_stiffness = 20.0; cs.vertex_group_mass = "pin"; cs.pin_stiffness = 5.0
    cs.effector_weights.gravity = float(os.environ.get("SETTLE_GRAVITY", "1"))   # 0: collision alone, no weight (Director, 2026-10-28)
    cm.collision_settings.distance_min = COAT_GAP * H; cm.collision_settings.use_self_collision = False
    cm.point_cache.frame_start = 1; cm.point_cache.frame_end = COAT_SETTLE
    cols = []
    for n in (os.environ.get("SETTLE_COLLIDE", "Outfit_Shirt,Outfit_Tie,Outfit_Trousers").split(",")):
        if n in mB:
            c_ = mB[n].modifiers.new("Collision", 'COLLISION'); cl = mB[n].collision; cl.thickness_outer = COAT_GAP * H; cl.thickness_inner = 0.001 * H
            cl.use_culling = cl.use_normal = True                        # single sided: a point is only ever pushed OUT
            cols.append((mB[n], c_))
    for f_ in range(1, COAT_SETTLE + 1):
        sc.frame_set(f_)
    ev = so.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    NV = np.array([(so.matrix_world @ v.co)[:] for v in ev.vertices]); so.to_mesh_clear()
    print(f"[{TAG}] settle: {COAT_SETTLE} frames, {int((pin >= 1).sum())} pinned; moved up to {np.linalg.norm(NV - CV, axis=1).max() / H * 100:.2f} % of H, "
          f"hem {CV[:, 2].min():.3f} -> {NV[:, 2].min():.3f}")
    for o_, c_ in cols:
        o_.modifiers.remove(c_)
    bpy.data.objects.remove(so); sc.frame_set(1); CV = NV; set_world(coat, CV)
rebind(coat)
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
HV[:, 2] -= HAT_DROP * H; n1 = through(HV)
print(f"[{TAG}] hat: {n0} head vertices came through it as placed; lifted {lift / H * 100:.1f} % of H, scaled x{scale:.2f}, then {HAT_DY * 100:.1f} % back and {HAT_DROP * 100:.1f} % down -> {n1} left")
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
# a face goes only when ALL its vertices are covered: with ANY, the locks that start under the brim and rise into the crown went whole and the
# scalp showed in a band under the brim (the male, 2026-10-27); what is left inside the crown is hidden by it
# and a face goes when one of its vertices comes OUT through the hat: the hat below it, none above it, and not inside it (the female's locks
# came through the band once the rule kept half-covered faces); a vertex under the brim has the brim above it and stays
poke = [cov[i] and not inside(Th, q) and Th.ray_cast(Vector((q[0], q[1], q[2] + 1e-5 * H)), Vector((0, 0, 1)), 2 * H)[0] is None for i, q in enumerate(hairV)]
hh, nd = masked_copy(mB["Body_Hair"], "Body_Hair_Hat", lambda f: all(cov[v.index] for v in f.verts) or any(poke[v.index] for v in f.verts))
print(f"[{TAG}] hair mask: {nd} of {len(mB['Body_Hair'].data.polygons)} hair faces under the hat ({sum(poke)} vertices came out through it)")
extra = [hh]
if "Outfit_Shirt" in mB:
    Tc = shell(coat); SV = wverts(mB["Outfit_Shirt"])
    deep = [inside(Tc, q) and Tc.find_nearest(Vector(q))[3] > COAT_GAP * H for q in SV]
    # and what comes OUT through the coat where it covers the shirt: a ray from the vertex toward its bone (the nearest point of the spine
    # chain or of an arm) meets the coat within 3 % of H, the coat lying between it and the body (the male's upper back and shoulder kept a
    # few such spots under the light fit); the shirt shown between the lapels has no coat toward its bone and stays
    bh = lambda n: np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + n].head_local)[:])
    segs = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
    segs += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]
    def to_bone(q):
        best_ = None
        for a, b in segs:
            ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(c - q)
            if best_ is None or d < best_[0]:
                best_ = (d, (c - q) / max(d, 1e-12))
        return best_
    def through_coat(q):                                 # the coat met BEFORE the bone: a hit past it is the coat's collar behind the neck,
        d, n_ = to_bone(q)                               # which took the female's shirt collar (2026-10-27)
        h = Tc.ray_cast(Vector(q), Vector(n_), min(0.03 * H, d))
        return h[0] is not None
    out_ = [not inside(Tc, q) and through_coat(q) for q in SV]
    # the COLLAR is never masked: from 4 % of H under the neck bone up (the female's shirt collar lies over her coat's collar stand, which
    # reads locally exactly like a spot coming through the coat, and both rules took it)
    keep = SV[:, 2] > bh("Neck")[2] - 0.04 * H
    deep = [d_ and not k_ for d_, k_ in zip(deep, keep)]; out_ = [o_ and not k_ for o_, k_ in zip(out_, keep)]
    sc_, nd = masked_copy(mB["Outfit_Shirt"], "Outfit_Shirt_Coated", lambda f: all(deep[v.index] for v in f.verts) or any(out_[v.index] for v in f.verts))
    print(f"[{TAG}] shirt mask: {nd} of {len(mB['Outfit_Shirt'].data.polygons)} shirt faces deep inside the coat or out through it ({sum(out_)} vertices out)"); extra.append(sc_)
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
    if HEM_MASK is not None:                                 # the hem band in MAGENTA (Director, 2026-10-28: "pinta elas com alguma cor")
        bm_ = bpy.data.materials.new("rv_band"); bm_.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1.0, 0.0, 1.0, 1)
        coat.data.materials.append(bm_); bi = len(coat.data.materials) - 1
        for p_ in coat.data.polygons:
            if all(HEM_MASK[v] for v in p_.vertices):
                p_.material_index = bi
    for c_, az in enumerate((0, 35, 90, 180)):
        files[(0, c_)] = f"{RV_OUT}/d_0_{c_}.png"; tc.shot(cam, co, files[(0, c_)], az, Vector((0, 0, 0.5 * H)), 1.15 * H)
        files[(1, c_)] = f"{RV_OUT}/d_1_{c_}.png"; tc.shot(cam, co, files[(1, c_)], az, Vector((0, 0, 0.9 * H)), 0.32 * H)
    tc.sheet(2, 4, files, f"{RV_OUT}/dressed.png"); print(f"[{TAG}] sheet {RV_OUT}/dressed.png")
    # hero.png (Director, 2026-10-28: "um render grande frontal, e tres menores de lados e de costas"): the front at 3x, the left side, the
    # right side and the back at 1x in a column beside it
    sc_ = bpy.context.scene; w0, h0 = sc_.render.resolution_x, sc_.render.resolution_y
    small = []
    for az in (90, 270, 180):
        small.append(f"{RV_OUT}/h_{az}.png"); tc.shot(cam, co, small[-1], az, Vector((0, 0, 0.5 * H)), 1.15 * H)
    sc_.render.resolution_x, sc_.render.resolution_y = 3 * w0, 3 * h0
    tc.shot(cam, co, f"{RV_OUT}/h_front.png", 0, Vector((0, 0, 0.5 * H)), 1.15 * H)
    S_ = np.zeros((3 * h0, 4 * w0, 4), np.float32)
    im = bpy.data.images.load(f"{RV_OUT}/h_front.png"); S_[:, :3 * w0] = np.array(im.pixels[:], np.float32).reshape(3 * h0, 3 * w0, 4)
    for k, f_ in enumerate(small):                                 # top to bottom: left side, right side, back (pixel rows run bottom-up)
        im = bpy.data.images.load(f_); y = (2 - k) * h0
        S_[y:y + h0, 3 * w0:] = np.array(im.pixels[:], np.float32).reshape(h0, w0, 4)
    hi_ = bpy.data.images.new("hero", 4 * w0, 3 * h0, alpha=True); hi_.pixels = S_.ravel()
    hi_.filepath_raw = f"{RV_OUT}/hero.png"; hi_.file_format = 'PNG'; hi_.save()
    # big4.png (Director, 2026-10-28: "o render grande com os 4 lados"): front, left, back, right, each at 3x, side by side
    big = {}
    for c_, az in enumerate((0, 90, 180, 270)):
        big[(0, c_)] = f"{RV_OUT}/b_{c_}.png"; tc.shot(cam, co, big[(0, c_)], az, Vector((0, 0, 0.5 * H)), 1.15 * H)
    tc.sheet(1, 4, big, f"{RV_OUT}/big4.png")
    sc_.render.resolution_x, sc_.render.resolution_y = w0, h0; print(f"[{TAG}] sheet {RV_OUT}/hero.png, big4.png")
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
