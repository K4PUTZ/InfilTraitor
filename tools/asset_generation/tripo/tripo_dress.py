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
# off by default (Director, 2026-10-30, on COAT_BASE: placed, stretched, sleeves turned and skirt straightened, the coat hangs smooth on both
# figures; the fit and the cloth settle crumpled it, pushing its two walls apart)
COAT_FIT = os.environ.get("COAT_FIT", "0") != "0"
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
    # a GLB splits its vertices at every UV seam: welded back, or the coat comes in as hundreds of islands that the fit moves apart (cracks,
    # blotched shading) and the settle pins as loose pieces (COAT_BASE, 2026-10-30: 360 islands, 10 once welded); its UVs ride along per corner
    for o in loose:
        bm_ = bmesh.new(); bm_.from_mesh(o.data); bmesh.ops.remove_doubles(bm_, verts=bm_.verts[:], dist=1e-6); bm_.to_mesh(o.data); bm_.free()
    LV = np.concatenate([wverts(o) for o in loose]); LF = []; LUV = []; off = 0
    for o in loose:
        LF += [[off + v for v in p_.vertices] for p_ in o.data.polygons]; off += len(o.data.vertices)
        uvd = o.data.uv_layers.active.data if o.data.uv_layers.active else None
        LUV += [tuple(uvd[li].uv) if uvd else (0.0, 0.0) for p_ in o.data.polygons for li in p_.loop_indices]
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
    if any(u != (0.0, 0.0) for u in LUV):
        ul = me.uv_layers.new(name="UVMap")
        for li, u in enumerate(LUV):
            ul.data[li].uv = u
    nc = bpy.data.objects.new("Outfit_Coat_src", me); bpy.context.scene.collection.objects.link(nc)
    nc.parent = coat.parent; nc.matrix_world = Matrix.Identity(4); set_world(nc, LV)
    md = nc.modifiers.new("Armature", 'ARMATURE'); md.object = armA; tc.write_weights(nc, NW)
    for p_ in nc.data.polygons:                          # smooth (Director, 2026-10-30: the coat read faceted; COAT_BASE is clean)
        p_.use_smooth = True
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
# the coat's two walls SEWN into one cloth (Director, 2026-10-30: "costurar as duas camadas, pra virar realmente um tecido e andar junto"):
# a LINING vertex has another wall of the coat just outside it (a ray away from the body meets the coat within LINING_GAP of H); each is
# bound to the nearest point of the OUTER wall (its triangle, barycentric, the offset in that triangle's own frame), follows it through the
# settle and takes its weights, so the walls move together and keep the coat's thickness. COAT_BASE itself keeps both walls (the source
# is copied and modified for sale; masks and bindings live in the dressed piece only).
LINING_GAP = float(os.environ.get("LINING_GAP", "0.015"))
_ct = [tuple(t.vertices) for t in (coat.data.calc_loop_triangles() or coat.data.loop_triangles)]
_cb = BVHTree.FromPolygons([tuple(q) for q in CV], _ct)
LINING = np.zeros(len(CV), bool)
_R3 = coat.matrix_world.to_3x3()
for i, q in enumerate(CV):                               # facing the body (a cloth wall under a belt, a flap or a lapel faces out: kept)
    dv = Vector(away(q)); nv = (_R3 @ coat.data.vertices[i].normal).normalized()
    if nv.dot(dv) < -0.2:
        h_ = _cb.ray_cast(Vector(q) + dv * 1e-4, dv, LINING_GAP * H)
        LINING[i] = h_[0] is not None
_ot = [t for t in _ct if not LINING[list(t)].any()]
SEW = {}
if LINING.any() and _ot:
    _ob = BVHTree.FromPolygons([tuple(q) for q in CV], _ot)


    def _frame(P, t):
        a, b, c = (Vector(P[k]) for k in t); n_ = (b - a).cross(c - a).normalized(); t1 = (b - a).normalized()
        return a, b, c, t1, n_.cross(t1), n_
    _otb = {t: k for k, t in enumerate(_ot)}
    for i in np.nonzero(LINING)[0]:
        # the outer wall right OUTSIDE it (the ray that made it lining), not merely the nearest: at a cuff resting on the skirt the nearest
        # outer face was the skirt's, and the cuff's lining shot down to the hip in motion (2026-10-30)
        dv = Vector(away(CV[i])); h_ = _ob.ray_cast(Vector(CV[i]) + dv * 1e-4, dv, LINING_GAP * H)
        if h_[0] is not None:
            loc, fi = h_[0], h_[2]
        else:
            loc, _n, fi, _d = _ob.find_nearest(Vector(CV[i]))
        t = _ot[fi]; a, b, c, t1, t2, n_ = _frame(CV, t)
        bc = barycentric_transform(loc, a, b, c, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        off = Vector(CV[i]) - loc; SEW[int(i)] = (t, tuple(bc), (off.dot(t1), off.dot(t2), off.dot(n_)))


def sew_follow(P_old, P_new):
    """each lining vertex back on its outer-wall point, the offset carried in the triangle's moved frame"""
    for i, (t, bc, o3) in SEW.items():
        a, b, c, t1, t2, n_ = _frame(P_new, t); loc = a * bc[0] + b * bc[1] + c * bc[2]
        P_new[i] = loc + t1 * o3[0] + t2 * o3[1] + n_ * o3[2]
    return P_new
print(f"[{TAG}] coat walls: {int(LINING.sum())} lining vertices sewn to the outer wall ({len(_ot)} outer triangles)")
# SHOULDER_FIT (Director, 2026-10-30: the coat SUSPENDED on the shoulders, without the cloth settle that tore it): above the chest every
# outer-wall point inside the torso or nearer it than COAT_GAP gets a push out to COAT_GAP (along away()); the pushes are spread as one
# smooth field (gaussian, SFIT_R of H) over the whole outer wall above the chest, fading to nothing over SETTLE_FADE below Spine2, so the
# shoulders lift as a piece; the lining rides it through the seam
if os.environ.get("SHOULDER_FIT", "1") != "0" and SEW is not None:
    SFIT_R = float(os.environ.get("SFIT_R", "0.03")); SETTLE_FADE = float(os.environ.get("SETTLE_FADE", "0.08"))
    top_ = (armB.matrix_world @ armB.data.bones["mixamorig:Spine2"].head_local).z
    neck_ = (armB.matrix_world @ armB.data.bones["mixamorig:Neck"].head_local).z
    # SFIT_LOW (fraction of H under the Hips joint; empty = the chest only): how far down the fit reaches, fading over SETTLE_FADE above it
    # (the female's hips are wider than the coat at the belt: the trousers showed at her back and sides)
    _lw = os.environ.get("SFIT_LOW", "")       # 2026-10-30: reaching the hips ballooned the coat at the waist (the field piles up over the passes)
    z_low = ((armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local).z - float(_lw) * H) if _lw else top_ - SETTLE_FADE * H
    zone = (CV[:, 2] > z_low) & (CV[:, 2] < neck_) & ~LINING     # the collar is not pushed (the head lifted it 5 % of H)
    for _pass in range(int(os.environ.get("SFIT_IT", "5"))):           # each pass finds again what still comes through
        src_i, src_d = [], []
        for i in np.nonzero(zone)[0]:
            q = CV[i]; dv = away(q); best = None
            # a sleeve tests the arms; the coat's body the torso, and the arms too only above the chest (the shoulder tops are the
            # sleeves' shells; lower, the arms hang beside the waist and, tested there, ballooned the coat)
            for kT, T in (body_a if coat_arm[i] else (body if q[2] > top_ - SETTLE_FADE * H else body_t)).items():
                if "Head" in kT or "Hair" in kT:
                    continue
                loc, nrm, _f, d_ = T.find_nearest(Vector(q), 0.05 * H)
                if loc is None:
                    continue
                sd = (Vector(q) - loc).dot(Vector(nrm))      # signed: < 0 inside the body (the shoulder tops are the sleeves' shells)
                best = sd if best is None else min(best, sd)
            if best is not None and best < COAT_GAP * H:
                src_i.append(i); src_d.append(dv * (COAT_GAP * H - best))
        if src_i:
            P0 = CV.copy(); S_ = CV[src_i]; D_ = np.array(src_d); SA_ = coat_arm[src_i]; moved = 0
            for i in np.nonzero(zone)[0]:                # spread within its kind (sleeve / body)
                w_ = np.exp(-np.sum((S_ - CV[i]) ** 2, axis=1) / (2 * (SFIT_R * H) ** 2)) * (SA_ == coat_arm[i])
                if w_.sum() < 1e-6:
                    continue
                fade = np.clip((CV[i, 2] - z_low) / (SETTLE_FADE * H), 0.0, 1.0)
                d_ = (w_[:, None] * D_).sum(0) / max(w_.sum(), 1.0) * fade
                # never less than the vertex's own push (a source keeps its full lift)
                CV[i] = CV[i] + d_; moved += 1
            for k, i in enumerate(src_i):
                need = P0[i] + D_[k]
                if np.linalg.norm(need - P0[i]) > np.linalg.norm(CV[i] - P0[i]):
                    CV[i] = need
            CV = sew_follow(P0, CV); set_world(coat, CV)
            print(f"[{TAG}] shoulder fit: {len(src_i)} outer points through or against the torso, {moved} moved, largest push "
                  f"{np.linalg.norm(D_, axis=1).max() / H * 100:.2f} % of H")
# SLEEVE_FIT (2026-10-30): the male's hands came through his cuffs at REST (the coat's cuff, turned onto the arm, is narrower than his
# wrist): every sleeve point (coat_arm, not the lining) inside or against the shirt's sleeves or the HANDS (never tested before: not
# under the coat) is pushed out from the arm bone to COAT_GAP, the pushes spread over the sleeve only (SFIT_R), in passes; the lining rides
if os.environ.get("SLEEVE_FIT", "1") != "0" and SEW is not None:
    arm_sh = dict(body_a)
    if "Body_Hands" in mB:
        arm_sh["Body_Hands"] = sub_shell(mB["Body_Hands"], np.ones(len(mB["Body_Hands"].data.vertices), bool))
    arm_sh = {k: v for k, v in arm_sh.items() if v}
    slz = coat_arm & ~LINING; SR = float(os.environ.get("SFIT_R", "0.03")) * 0.7
    for _pass in range(int(os.environ.get("SLEEVE_IT", "3"))):
        si_, sd2 = [], []
        for i in np.nonzero(slz)[0]:
            q = Vector(CV[i]); best = None
            for T in arm_sh.values():
                loc, nrm, _f, d_ = T.find_nearest(q, 0.04 * H)
                if loc is not None:
                    sgn = (q - loc).dot(Vector(nrm)); best = sgn if best is None else min(best, sgn)
            if best is not None and best < COAT_GAP * H:
                si_.append(i); sd2.append(away(CV[i]) * (COAT_GAP * H - best))
        if not si_:
            break
        P0 = CV.copy(); S_ = CV[si_]; D_ = np.array(sd2)
        for i in np.nonzero(slz)[0]:
            w_ = np.exp(-np.sum((S_ - CV[i]) ** 2, axis=1) / (2 * (SR * H) ** 2))
            if w_.sum() > 1e-6:
                CV[i] = CV[i] + (w_[:, None] * D_).sum(0) / max(w_.sum(), 1.0)
        for k, i in enumerate(si_):
            if np.linalg.norm(D_[k]) > np.linalg.norm(CV[i] - P0[i]):
                CV[i] = P0[i] + D_[k]
        CV = sew_follow(P0, CV); set_world(coat, CV)
        print(f"[{TAG}] sleeve fit pass {_pass + 1}: {len(si_)} sleeve points through or against the arms / hands, largest push "
              f"{np.linalg.norm(D_, axis=1).max() / H * 100:.2f} % of H")
# SKIRT_GAP (2026-10-30, "bloquear o contato"): the skirt kept SKIRT_GAP of H off the trousers at rest. The female's front panels lay ON her
# thighs, and any step put the thigh through them. One pass (several piled up into a balloon at the waist), skirt only (below the hips,
# not a sleeve), the pushes spread as a smooth field over the skirt and capped at SKIRT_CAP; the lining rides it
SKIRT_GAP = float(os.environ.get("SKIRT_GAP", "0.012"))
if SKIRT_GAP > 0 and SEW is not None and "Outfit_Trousers" in mB:
    SKIRT_CAP = float(os.environ.get("SKIRT_CAP", "0.03")); hz2 = (armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local).z
    Ttr = shell(mB["Outfit_Trousers"])
    skz = (CV[:, 2] < hz2) & ~LINING & ~coat_arm
    si, sd_ = [], []
    for i in np.nonzero(skz)[0]:
        q = Vector(CV[i]); loc, nrm, _f, d_ = Ttr.find_nearest(q, 0.06 * H)
        if loc is None:
            continue
        sgn = (q - loc).dot(Vector(nrm))                 # < 0: inside the trousers
        if sgn < SKIRT_GAP * H:
            n_ = Vector(nrm).normalized(); si.append(i); sd_.append(np.array(n_[:]) * (SKIRT_GAP * H - sgn))
    if si:
        P0 = CV.copy(); S_ = CV[si]; D_ = np.array(sd_)
        for i in np.nonzero(skz)[0]:
            w_ = np.exp(-np.sum((S_ - CV[i]) ** 2, axis=1) / (2 * (0.025 * H) ** 2))
            if w_.sum() > 1e-6:
                d_ = (w_[:, None] * D_).sum(0) / max(w_.sum(), 1.0)
                n_ = np.linalg.norm(d_)
                CV[i] = CV[i] + (d_ if n_ <= SKIRT_CAP * H else d_ / n_ * SKIRT_CAP * H)
        for k, i in enumerate(si):                       # a source gets at least its own push (capped)
            need = D_[k] if np.linalg.norm(D_[k]) <= SKIRT_CAP * H else D_[k] / np.linalg.norm(D_[k]) * SKIRT_CAP * H
            if np.linalg.norm(need) > np.linalg.norm(CV[i] - P0[i]):
                CV[i] = P0[i] + need
        CV = sew_follow(P0, CV); set_world(coat, CV)
        print(f"[{TAG}] skirt gap: {len(si)} skirt points nearer the trousers than {SKIRT_GAP * 100:.1f} % of H, pushed (largest "
              f"{np.linalg.norm(D_, axis=1).max() / H * 100:.2f} % of H, capped {SKIRT_CAP * 100:.1f})")
HEM_MASK = None                                           # the hem band's coat vertices, painted in the review renders
COAT_SETTLE = int(os.environ.get("COAT_SETTLE", "0")); SETTLE_FADE = float(os.environ.get("SETTLE_FADE", "0.08"))
if COAT_SETTLE > 0:
    sc = bpy.context.scene; me = bpy.data.meshes.new("settle")
    me.from_pydata([tuple(q) for q in CV], [], [list(p_.vertices) for p_ in coat.data.polygons if not LINING[list(p_.vertices)].any()])
    me.update()
    so = bpy.data.objects.new("settle", me); sc.collection.objects.link(so)
    top = (armB.matrix_world @ armB.data.bones["mixamorig:Spine2"].head_local).z
    pin = np.clip(1.0 - (top - CV[:, 2]) / (SETTLE_FADE * H), 0.0, 1.0); pin[coat_arm] = 1.0
    # SHOULDER_PIN (Director, 2026-10-30: "suspendendo o casaco nos ombros de maneira mais detalhada"): above the chest only what RESTS on
    # the body is held (within PIN_GAP of H of a body shell, fading over PIN_FADE); the rest of the top drapes from it
    if os.environ.get("SHOULDER_PIN", "0") != "0":
        PIN_GAP = float(os.environ.get("PIN_GAP", "0.012")); PIN_FADE = float(os.environ.get("PIN_FADE", "0.02"))
        db = np.array([min(T.find_nearest(Vector(q))[3] for T in body_t.values()) if q[2] > top - SETTLE_FADE * H else 1.0 for q in CV])
        pin = np.where(CV[:, 2] > top - SETTLE_FADE * H, np.clip(1.0 - (db - PIN_GAP * H) / (PIN_FADE * H), 0.0, 1.0), 0.0)
        pin[coat_arm] = 1.0
    pin[LINING] = 1.0                                     # not simulated: it rides the outer wall
    # without the lining's faces some outer panels hang from nothing (the hem fell 6 m): a piece of the simulated wall with no held vertex
    # is held whole and rides the coat afterwards, as a loose island does
    spar = list(range(len(CV)))

    def sroot(a):
        while spar[a] != a:
            spar[a] = spar[spar[a]]; a = spar[a]
        return a
    for p_ in coat.data.polygons:
        vs = list(p_.vertices)
        if not LINING[vs].any():
            for a_ in vs[1:]:
                spar[sroot(a_)] = sroot(vs[0])
    sid = np.array([sroot(i) for i in range(len(CV))]); free_piece = np.zeros(len(CV), bool)
    for r_ in np.unique(sid[~LINING]):
        m_ = (sid == r_) & ~LINING
        if pin[m_].max() < 0.5:
            pin[m_] = 1.0; free_piece |= m_
    print(f"[{TAG}] settle: {int(free_piece.sum())} vertices of outer pieces with nothing held, held whole")
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
    cs.bending_stiffness = float(os.environ.get("SETTLE_BEND", "20")); cs.vertex_group_mass = "pin"; cs.pin_stiffness = 5.0
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
    # the loose islands were pinned through the settle (they hang from nothing) but must ride on the coat: each takes the move of the
    # main body's vertex nearest it (2026-10-30: pinned in place, the back belt and the pocket flaps stood off the settled coat)
    mi = np.nonzero((isl == main_) & ~LINING & ~free_piece)[0]; kdm = KDTree(len(mi))
    for j, i in enumerate(mi):
        kdm.insert(Vector(CV[i]), j)
    kdm.balance()
    for i in np.nonzero(((isl != main_) | free_piece) & ~LINING)[0]:
        j = mi[kdm.find(Vector(CV[i]))[1]]; NV[i] = CV[i] + (NV[j] - CV[j])
    NV = sew_follow(CV, NV)
    print(f"[{TAG}] settle: {COAT_SETTLE} frames, {int((pin >= 1).sum())} pinned; moved up to {np.linalg.norm(NV - CV, axis=1).max() / H * 100:.2f} % of H, "
          f"hem {CV[:, 2].min():.3f} -> {NV[:, 2].min():.3f}")
    for o_, c_ in cols:
        o_.modifiers.remove(c_)
    bpy.data.objects.remove(so); sc.frame_set(1); CV = NV; set_world(coat, CV)
# C4 (D86, Director 2026-10-30: "minimamente se comportar como casacos quando o agente corre"): the coat's weights read off the BASE, not
# off the generation's coat (the female's is 25 Tripo parts, each skinned on its own: the standalone coat took a patchwork of weights and
# shattered in the climb). A SLEEVE (coat_arm, or near an arm bone above the hips) takes the weights of the shirt's sleeve under it; the
# BODY above the hips the shirt's torso under it; the SKIRT, below the hips, hangs from them (Hips 0.85 / Spine 0.15) and follows each
# thigh by side, more toward the knee (SKIRT_FOLLOW at the knee), the front panels more (+ SKIRT_FRONT: they lie on the legs), the side
# split smooth over SKIRT_SPLIT of H; then the weights are SMOOTHED over the coat's own surface (C4_SMOOTH passes, sleeves and body apart),
# and every loose island (a flap, a button, the back belt) takes the weights of the coat point it sits on
if os.environ.get("COAT_C4", "1") != "0":
    def _bh(n):
        return np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + n].head_local)[:])
    _Ws = tc.read_weights(mB["Outfit_Shirt"]) if "Outfit_Shirt" in mB else []
    _arm_v = armness(_Ws) >= 0.5 if _Ws else None

    def _src(o, W_, keep_v):
        V_ = wverts(o); o.data.calc_loop_triangles()
        T_ = [tuple(t.vertices) for t in o.data.loop_triangles if all(keep_v[k] for k in t.vertices)]
        return (BVHTree.FromPolygons([tuple(q) for q in V_], T_), V_, T_, W_) if T_ else None
    SRC_ARM, SRC_BODY = [], []
    if _Ws:
        SRC_ARM.append(_src(mB["Outfit_Shirt"], _Ws, _arm_v)); SRC_BODY.append(_src(mB["Outfit_Shirt"], _Ws, ~_arm_v))
    if "Outfit_Trousers" in mB:
        _Wt = tc.read_weights(mB["Outfit_Trousers"]); SRC_BODY.append(_src(mB["Outfit_Trousers"], _Wt, np.ones(len(_Wt), bool)))
    SRC_ALL = [x for x in [_src(mB["Outfit_Shirt"], _Ws, np.ones(len(_Ws), bool))] if x] if _Ws else []
    SRC_ARM = [x for x in SRC_ARM if x]; SRC_BODY = [x for x in SRC_BODY if x]
    SRC_LEGS = [_src(mB["Outfit_Trousers"], _Wt, np.ones(len(_Wt), bool))] if "Outfit_Trousers" in mB else []

    def _wat(srcs, q, with_d=False):
        best = None
        for bvh_, V_, T_, W_ in srcs:
            loc, _n, fi, d = bvh_.find_nearest(Vector(q))
            if loc is not None and (best is None or d < best[0]):
                best = (d, loc, T_[fi], V_, W_)
        if best is None:
            return ({"mixamorig:Hips": 1.0}, 1e9) if with_d else {"mixamorig:Hips": 1.0}
        d, loc, t, V_, W_ = best; mix_ = {}
        bc = barycentric_transform(loc, *(Vector(V_[k]) for k in t), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        for k, x in zip(t, bc):
            for g, w in W_[k].items():
                mix_[g] = mix_.get(g, 0.0) + w * max(0.0, x)
        return (mix_, d) if with_d else mix_
    hz_ = _bh("Hips")[2]; kz_ = (_bh("LeftLeg")[2] + _bh("RightLeg")[2]) / 2; hy_ = _bh("Hips")[1]; lx_ = np.sign(_bh("LeftUpLeg")[0])
    d_arm = np.minimum.reduce([tc.segd(CV, _bh(sd + a), _bh(sd + b)) for sd in ("Left", "Right")
                               for a, b in (("Arm", "ForeArm"), ("ForeArm", "Hand"))])
    d_sp = np.minimum.reduce([tc.segd(CV, _bh(a), _bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"),
                                                                        ("Spine2", "Neck"))])
    # how much a coat point is SLEEVE, soft: by how much nearer an arm bone it is than the spine (a hard line, coat_arm or a radius, cut
    # into the back panel by the shoulder blade and the coat cracked along it in the run, 2026-10-30); under the hips only what hugs the
    # forearm (a skirt reading the hands is Tripo's original fault)
    # the sleeve TUBE: grown along the coat's edges from points well inside the upper sleeve, through points within 6 % of H of an arm bone;
    # the skirt beside a hand is near the arm too but not on that tube (by distance alone the female's low cuffs half-left the sleeve and
    # the skirt by her hands joined it)
    GROW_RATIO = float(os.environ.get("GROW_RATIO", "0.45"))
    grown = (d_arm < 0.035 * H) & (d_arm < GROW_RATIO * d_sp) & (CV[:, 2] > hz_) & ~LINING; nbr_ = [[] for _ in CV]
    for e_ in coat.data.edges:
        a_, b_ = e_.vertices; nbr_[a_].append(b_); nbr_[b_].append(a_)
    stack_ = list(np.nonzero(grown)[0])
    while stack_:
        i_ = stack_.pop()
        for j_ in nbr_[i_]:
            # and clearly nearer the arm than the spine (GROW_RATIO): the female's arms hang close to her body, and by distance alone the
            # tube grew down her coat's side from the armpit to the waist, which then swung with the arm as a loose strip (2026-10-30)
            if not grown[j_] and not LINING[j_] and d_arm[j_] < 0.06 * H and d_arm[j_] < GROW_RATIO * d_sp[j_]:
                grown[j_] = True; stack_.append(j_)
    # what hangs OFF the tube only (a strap's tab beyond the cuff: off the tube it is a small piece touching nothing but the tube) is
    # sleeve too: it stood out of the male's cuff as a blade, following the hip (2026-10-30); the skirt and the body are one big piece
    TAB_MAX = int(os.environ.get("TAB_MAX", "60")); parT = list(range(len(CV)))

    def rT(a):
        while parT[a] != a:
            parT[a] = parT[parT[a]]; a = parT[a]
        return a
    for e_ in coat.data.edges:
        a_, b_ = e_.vertices
        if not grown[a_] and not grown[b_] and not LINING[a_] and not LINING[b_]:
            parT[rT(a_)] = rT(b_)
    compT = np.array([rT(i) for i in range(len(CV))]); free_ = ~grown & ~LINING
    sizeT = np.bincount(compT[free_], minlength=len(CV)); touch = np.zeros(len(CV), bool)
    for e_ in coat.data.edges:
        a_, b_ = e_.vertices
        if grown[a_] and free_[b_]:
            touch[compT[b_]] = True
        if grown[b_] and free_[a_]:
            touch[compT[a_]] = True
    tab = free_ & (sizeT[compT] <= TAB_MAX) & touch[compT]
    grown |= tab
    # above the armpits the body side of the armhole is soft too (by the same ratio): the back panel 100 % body beside a sleeve 100 % arm
    # opened at the seam when the arm swung back (2026-10-30); lower only the tube is sleeve (the skirt by the hands is not)
    pit_m = min(_bh("LeftArm")[2], _bh("RightArm")[2]) - 0.05 * H
    MEM = np.where(grown | (CV[:, 2] > pit_m), 1.0 - tc.sstep(0.5, 0.85, d_arm / np.maximum(d_sp, 1e-6)), 0.0)
    MEM[tab] = 1.0
    MEM[LINING] = 0.0
    SLEEVE = (MEM >= 0.5) & ~LINING
    # above the armpits the sleeve and the body read the WHOLE shirt and are smoothed together: read off its sleeve and its torso apart,
    # the coat's weights stepped at the armhole and it cracked across the upper back in the run (2026-10-30)
    pit_z = min(_bh("LeftArm")[2], _bh("RightArm")[2]) - 0.05 * H
    FMAX = float(os.environ.get("SKIRT_FOLLOW", "0.45")); FFRONT = float(os.environ.get("SKIRT_FRONT", "0.25"))
    SPLIT = float(os.environ.get("SKIRT_SPLIT", "0.10"))
    LEG_NEAR = float(os.environ.get("LEG_NEAR", "0.015")); LEG_FAR = float(os.environ.get("LEG_FAR", "0.05"))
    LEG_MAX = float(os.environ.get("LEG_MAX", "0"))
    FRONT_FOLLOW = float(os.environ.get("FRONT_FOLLOW", "0.85"))
    W4 = []
    # C4_UPPER=gen: above the hips keep the weights the coat got from the generation's coat (Tripo's own rig of a coat on that body); only
    # the skirt takes the rules below
    W_gen = tc.read_weights(coat) if os.environ.get("C4_UPPER", "body") == "gen" else None
    for i, q in enumerate(CV):
        if W_gen is not None and q[2] > hz_ + 0.03 * H:
            W4.append(tc.top4(W_gen[i], "mixamorig:Hips")); continue
        if q[2] > pit_z and SRC_ALL and os.environ.get("C4_ALL_ABOVE", "0") != "0":
            # (off: read off the whole shirt the female's back took the shirt's patches of shoulder weights, and in the run the back
            # opened between them; the soft sleeve share below does the armhole instead)
            W4.append(tc.top4(_wat(SRC_ALL, q), "mixamorig:Hips")); continue
        m_ = float(MEM[i])
        if m_ >= 0.999:
            W4.append(tc.top4(_wat(SRC_ARM or SRC_BODY, q), "mixamorig:Hips")); continue
        wb = _wat(SRC_BODY, q); k = float(tc.sstep(hz_ + 0.02 * H, hz_ - 0.03 * H, q[2]))
        if k > 0:
            t = float(np.clip((hz_ - q[2]) / max(hz_ - kz_, 1e-6), 0, 1))
            front = float(tc.sstep(hy_ - 0.02 * H, hy_ - 0.08 * H, q[1]))       # -y is the front
            # the BACK hangs from the hips and follows the legs toward the knee; the FRONT panels turn with their thigh about the hip, as a
            # panel pushed by the knee does (FRONT_FOLLOW, reached a third of the way down to the knee): following them only toward the
            # knee, the female's thigh came through them mid-way in every step of the climb
            f = 0.10 + (FMAX - 0.10) * t
            s_l = float(tc.sstep(-SPLIT * H, SPLIT * H, q[0] * lx_))
            sk = {"mixamorig:Hips": (1 - f) * 0.85, "mixamorig:Spine": (1 - f) * 0.15, "mixamorig:LeftUpLeg": f * s_l,
                  "mixamorig:RightUpLeg": f * (1 - s_l)}
            # a FRONT panel lies on the trousers and deforms like them: their hip / thigh weights under it (the knee's and the shin's left
            # out: they tore it), blended in by how far in front it is; following the thigh only toward the knee, or by a rule, the thigh
            # still came through it just under the hip crease (the female's run and climb, 2026-10-30)
            if SRC_LEGS and front > 0:
                wl = {g: x for g, x in _wat(SRC_LEGS, q).items() if g.endswith(("UpLeg", "Hips", "Spine"))} or {"mixamorig:Hips": 1.0}
                tl = sum(wl.values()) or 1.0; Fk = FRONT_FOLLOW * front
                sk = {g: x * (1 - Fk) for g, x in sk.items()}
                for g, x in wl.items():
                    sk[g] = sk.get(g, 0.0) + x / tl * Fk
            # where the skirt lies ON a leg it goes with it (the female's thigh came through the front panels in the climb): the trousers'
            # weights under it, by how near it is (LEG_FAR -> LEG_NEAR of H), more toward the knee
            if SRC_LEGS and LEG_MAX > 0:
                wl, dl = _wat(SRC_LEGS, q, with_d=True)
                wl = {g: x for g, x in wl.items() if g.endswith(("UpLeg", "Hips"))} or {"mixamorig:Hips": 1.0}   # the thigh, not the
                L = LEG_MAX * float(tc.sstep(LEG_FAR * H, LEG_NEAR * H, dl)) * (0.4 + 0.6 * t)                   # knee: it tore the panel
                if L > 0:
                    tl = sum(wl.values()) or 1.0; sk = {g: x * (1 - L) for g, x in sk.items()}
                    for g, x in wl.items():
                        sk[g] = sk.get(g, 0.0) + x / tl * L
            tot = sum(wb.values()) or 1.0; mix_ = {g: x / tot * (1 - k) for g, x in wb.items()}
            for g, x in sk.items():
                mix_[g] = mix_.get(g, 0.0) + x * k
            wb = mix_
        if m_ > 0:                                      # part sleeve: the arm's weights by its share
            wa = _wat(SRC_ARM or SRC_BODY, q); ta = sum(wa.values()) or 1.0; tb = sum(wb.values()) or 1.0
            mix_ = {g: x / tb * (1 - m_) for g, x in wb.items()}
            for g, x in wa.items():
                mix_[g] = mix_.get(g, 0.0) + x / ta * m_
            wb = mix_
        W4.append(tc.top4(wb, "mixamorig:Hips"))
    # smoothing over the coat's own edges, a sleeve with sleeves and the body with the body (a sleeve's weights bled into the skirt are
    # what Tripo's rig did: the skirt followed the hands)
    nb_ = [[] for _ in CV]
    for e_ in coat.data.edges:
        a_, b_ = e_.vertices
        if min(CV[a_, 2], CV[b_, 2]) > pit_z or SLEEVE[a_] == SLEEVE[b_]:  # across sleeve and body only at the armhole: lower, a cuff
            # by the hip took 30 % of the Hips from the coat's side and tore in the run (2026-10-30)
            nb_[a_].append(b_); nb_[b_].append(a_)
    for _ in range(int(os.environ.get("C4_SMOOTH", "6"))):
        nxt = []
        for i, w in enumerate(W4):
            if not nb_[i] or LINING[i]:
                nxt.append(w); continue
            acc = {g: x * 0.5 for g, x in w.items()}
            for j in nb_[i]:
                for g, x in W4[j].items():
                    acc[g] = acc.get(g, 0.0) + x * 0.5 / len(nb_[i])
            nxt.append(tc.top4(acc, "mixamorig:Hips"))
        W4 = nxt
    # FLAPS: a part of the coat lying ON another part of it (the back cape, the lapels, the storm flap) takes the weights of the layer under
    # it, as the lining takes the outer wall's: the cape's corner read the arm and lifted off the back in the run, opening a dark gap
    # (2026-10-30). Under = the first coat face a ray toward the spine meets within FLAP_GAP of H that is not the lining's nor the vertex's own
    # (the first try, on every vertex, glued the sleeves' undersides to the body: only the body's own layers now, above the hips: the
    # back cape's corner read the arm and lifted off the back by the armhole when the arm swung back)
    FLAP_GAP = float(os.environ.get("FLAP_GAP", "0.02"))
    _tri4 = [tuple(t.vertices) for t in (coat.data.calc_loop_triangles() or coat.data.loop_triangles)]
    _bv4 = BVHTree.FromPolygons([tuple(q) for q in CV], _tri4); n_flap = 0
    for _ in range(2 if FLAP_GAP > 0 else 0):            # twice: a flap on a flap
        W5 = list(W4)
        for i in np.nonzero(~LINING & (MEM < 0.5) & (CV[:, 2] > hz_))[0]:
            q = Vector(CV[i]); dv = -Vector(away(CV[i])); o_ = q + dv * 1e-4; travelled = 0.0
            for _h in range(4):
                h_ = _bv4.ray_cast(o_, dv, FLAP_GAP * H - travelled)
                if h_[0] is None:
                    break
                t_ = _tri4[h_[2]]; travelled += h_[3]
                if i in t_ or LINING[list(t_)].all():
                    o_ = h_[0] + dv * 1e-5; continue
                if (MEM[list(t_)] >= 0.5).any():                # a sleeve under it: not a flap of the body
                    break
                bc = barycentric_transform(h_[0], *(Vector(CV[k]) for k in t_), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
                mix_ = {}
                for k, x in zip(t_, bc):
                    for g, w in W4[k].items():
                        mix_[g] = mix_.get(g, 0.0) + w * max(0.0, x)
                W5[i] = tc.top4(mix_, "mixamorig:Hips"); n_flap += 1
                break
        W4 = W5
    # loose islands ride the coat point under them
    par4 = list(range(len(CV)))

    def r4(a):
        while par4[a] != a:
            par4[a] = par4[par4[a]]; a = par4[a]
        return a
    for e_ in coat.data.edges:
        par4[r4(e_.vertices[0])] = r4(e_.vertices[1])
    is4 = np.array([r4(i) for i in range(len(CV))]); main4 = np.bincount(is4).argmax()
    mi4 = np.nonzero((is4 == main4) & ~LINING)[0]; kd4 = KDTree(len(mi4))
    for j, i in enumerate(mi4):
        kd4.insert(Vector(CV[i]), j)
    kd4.balance(); n_isl = 0
    # an island is ONE piece: it votes sleeve or body by its vertices' nearest coat points, then each vertex takes the nearest coat point
    # of that kind (the cuff strap, at the hip, went half with the skirt and stood out as a blade in the run, 2026-10-30)
    armd4 = np.array([sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) >= 0.5 for w in W4])
    kdf = {}
    for fam in (True, False):
        ids_ = mi4[armd4[mi4] == fam]
        if len(ids_):
            kd_ = KDTree(len(ids_))
            for j, i in enumerate(ids_):
                kd_.insert(Vector(CV[i]), j)
            kd_.balance(); kdf[fam] = (kd_, ids_)
    # each island vertex votes by the coat point it LIES ON (a ray along its normal, both ways, within 3 % of H), the nearest one only
    # when no layer is under it: the female's hip pocket flap has her hanging hand's cuff nearer than the panel under it, voted sleeve,
    # took RightForeArm and flew off beside her in every kick (2026-10-30)
    mainf_ = [tuple(p_.vertices) for p_ in coat.data.polygons if all(is4[v] == main4 for v in p_.vertices)]
    bvm_ = BVHTree.FromPolygons([tuple(q) for q in CV], mainf_); nm3 = coat.matrix_world.to_3x3()

    def lies_on(i):
        n_ = (nm3 @ coat.data.vertices[i].normal).normalized(); best_ = None
        for s_ in (1, -1):
            h_ = bvm_.ray_cast(Vector(CV[i]) - n_ * s_ * 1e-4, -n_ * s_, 0.03 * H)
            if h_[0] is not None and (best_ is None or h_[3] < best_[1]):
                best_ = (h_[2], h_[3])
        return None if best_ is None else mainf_[best_[0]]

    # a band round a sleeve (the cuff strap) is sleeve whatever lies under it: its points circle an arm bone (no gap over 150 degrees
    # round the nearest arm segment, the centre within 6 % of H of it); the female's right cuff strap voted body, took Hips and stayed at
    # her hip while the arm moved (2026-10-30)
    _asegs = [(_bh(sd + a), _bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Arm", "ForeArm"), ("ForeArm", "Hand"))]

    def wraps_arm(mem_):
        c_ = CV[mem_].mean(0); best_ = None
        for a_, b_ in _asegs:
            ab_ = b_ - a_; t_ = np.clip((c_ - a_) @ ab_ / (ab_ @ ab_), 0, 1); d_ = np.linalg.norm(c_ - (a_ + t_ * ab_))
            if best_ is None or d_ < best_[0]:
                best_ = (d_, a_, ab_ / np.linalg.norm(ab_))
        if best_[0] > 0.06 * H:
            return False
        _d, a_, u_ = best_; r_ = CV[mem_] - a_; r_ -= np.outer(r_ @ u_, u_)
        e1 = np.cross(u_, [0, 0, 1.0]) if abs(u_[2]) < 0.9 else np.cross(u_, [1.0, 0, 0]); e1 /= np.linalg.norm(e1); e2 = np.cross(u_, e1)
        ang_ = np.sort(np.arctan2(r_ @ e2, r_ @ e1))
        gaps_ = np.diff(np.concatenate([ang_, [ang_[0] + 2 * math.pi]]))
        return gaps_.max() < math.radians(150)

    def vote(i):
        f_ = lies_on(i)
        return armd4[mi4[kd4.find(Vector(CV[i]))[1]]] if f_ is None else sum(armd4[v] for v in f_) * 2 > len(f_)
    for r_ in np.unique(is4[is4 != main4]):
        mem_ = np.nonzero(is4 == r_)[0]
        votes = [vote(i) for i in mem_]
        fam = sum(votes) * 2 > len(votes) or wraps_arm(mem_)
        kd_, ids_ = kdf.get(fam, (kd4, mi4))
        # and it moves as ONE rigid piece: the mean of what it rests on (a strap's tip read the hand while its band read the forearm, and
        # stood out of the cuff as a blade when the wrist bent, 2026-10-30)
        # read off the face it LIES ON when that face is of its kind (the female's hip flap read the nearest point, Hips 0.99 off the
        # trousers, while the panel under it follows the spine: it swung 20 cm out whenever the hips turned against the chest, 2026-10-30)
        acc = {}
        for i in mem_:
            f_ = lies_on(i)
            src_ = [v for v in f_ if armd4[v] == fam] if f_ is not None else []
            src_ = src_ or [ids_[kd_.find(Vector(CV[i]))[1]]]
            for v in src_:
                for g, x in W4[v].items():
                    acc[g] = acc.get(g, 0.0) + x / len(mem_) / len(src_)
        w_ = tc.top4(acc, "mixamorig:Hips")
        for i in mem_:
            W4[i] = dict(w_); n_isl += 1
    tc.write_weights(coat, W4)
    print(f"[{TAG}] C4: {int(tab.sum())} tab vertices hang off the sleeves; weights off the base: {int(SLEEVE.sum())} sleeve, {int((~SLEEVE & (CV[:, 2] < hz_)).sum())} skirt vertices; "
          f"{n_isl} island vertices ride the coat; {n_flap // 2} flap vertices take the layer under them")
if SEW:
    _W = tc.read_weights(coat)
    for i, (t, bc, o3) in SEW.items():
        mix_ = {}
        for k, x in zip(t, bc):
            for g, w in _W[k].items():
                mix_[g] = mix_.get(g, 0.0) + w * max(0.0, x)
        _W[i] = tc.top4(mix_, "mixamorig:Hips")
    tc.write_weights(coat, _W)
# no coat point ties an ARM to a LEG (a cuff resting on the thigh took both, and shot to the hip in the run, 2026-10-30): the side with
# the larger share keeps the vertex. And a coat's cuff never bends with the WRIST: a hand's (or finger's) share goes to its forearm (the
# tip of the male's cuff strap read the hand and stood out of the cuff as a blade when he clenched his fist)
_W = tc.read_weights(coat); n_cut = 0
for i, w in enumerate(_W):
    if any("Hand" in g for g in w):
        acc = {}
        for g, x in w.items():
            if "Hand" in g:
                g = "mixamorig:" + ("Left" if "Left" in g else "Right") + "ForeArm"
            acc[g] = acc.get(g, 0.0) + x
        _W[i] = tc.top4(acc, "mixamorig:Hips")
for i, w in enumerate(_W):
    a_ = sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder")))
    l_ = sum(x for g, x in w.items() if any(k in g for k in ("UpLeg", "Leg", "Foot")))
    if a_ > 0.02 and l_ > 0.02:
        drop = ("UpLeg", "Leg", "Foot") if a_ >= l_ else ("Arm", "Hand", "Shoulder")
        _W[i] = tc.top4({g: x for g, x in w.items() if not any(k in g for k in drop)} or {"mixamorig:Hips": 1.0}, "mixamorig:Hips"); n_cut += 1
# ONE PLACE, ONE WEIGHT: coat vertices within WELD_W of H of each other at rest (a fold, a hem's turn, the decimation's slivers) take the
# same weights, or they part in motion as needles (the front hem's corner, 30x stretched in the run); never across an arm and a body
WELD_W = float(os.environ.get("WELD_W", "0.004"))
_arm_dom = np.array([sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) >= 0.5 for w in _W])
if WELD_W > 0:
    kdw = KDTree(len(CV))
    for i, q in enumerate(CV):
        kdw.insert(Vector(q), i)
    kdw.balance(); parw = list(range(len(CV)))

    def rw(a):
        while parw[a] != a:
            parw[a] = parw[parw[a]]; a = parw[a]
        return a
    for i, q in enumerate(CV):
        for (_co, j, _d) in kdw.find_range(Vector(q), WELD_W * H):
            if j != i and _arm_dom[i] == _arm_dom[j]:
                parw[rw(i)] = rw(j)
    groups = {}
    for i in range(len(CV)):
        groups.setdefault(rw(i), []).append(i)
    n_w = 0
    for g_ in groups.values():
        if len(g_) > 1:
            acc = {}
            for i in g_:
                for g, x in _W[i].items():
                    acc[g] = acc.get(g, 0.0) + x / len(g_)
            w_ = tc.top4(acc, "mixamorig:Hips")
            for i in g_:
                _W[i] = w_
            n_w += len(g_)
tc.write_weights(coat, _W)
# the CUFF FUSED to the coat's side (Tripo made the coat with the hands at the hips): a face joining a sleeve (arm-led) to the body below
# the hips tore whatever weights it took (196x in the male's run), and cut out it left a hole in the coat's side. Each such face now
# belongs to the BODY: its sleeve corners are duplicated in place with the body corners' weights, so the coat's side stays whole and
# follows the hips while the cuff keeps its own vertices and follows the arm; at rest nothing moves
hz3 = (armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local).z
bm_ = bmesh.new(); bm_.from_mesh(coat.data); bm_.verts.ensure_lookup_table(); bm_.faces.ensure_lookup_table()
dl_ = bm_.verts.layers.deform.verify(); uvl_ = bm_.loops.layers.uv.active; gidx = {g.name: g.index for g in coat.vertex_groups}
# up to the elbows: the male's sleeve was fused at the ELBOW to the coat's back too (16x in the run); higher, under the armholes, the
# sleeve's join to the back is the coat's own, and cutting it there opened the back by the armpit (2026-10-30)
pit3 = max((armB.matrix_world @ armB.data.bones["mixamorig:" + sd + "ForeArm"].head_local).z for sd in ("Left", "Right")) + 0.02 * H
bridge = [f for f in bm_.faces if len({bool(_arm_dom[v.index]) for v in f.verts}) == 2 and max(CV[v.index][2] for v in f.verts) < pit3]
# a fused face that SPANS the gap from the coat's side to the cuff (its sleeve corners more than SPAN_GAP of H off the coat's body) is
# neither the body's nor the sleeve's: it is cut (given to the body it stood out of the male's cuff as a blade when the arm swung, 2026-10-30);
# one lying on the coat's side stays the body's
SPAN_GAP = float(os.environ.get("SPAN_GAP", "0.01"))
bridge_set = set(bridge)
body_faces = [tuple(v.index for v in f.verts) for f in bm_.faces if f not in bridge_set and not any(_arm_dom[v.index] for v in f.verts)]
bvb_ = BVHTree.FromPolygons([tuple(q) for q in CV[:len(_arm_dom)]], body_faces) if body_faces else None
span = [f for f in bridge if bvb_ is not None and max(bvb_.find_nearest(Vector(CV[v.index]))[3] for v in f.verts if _arm_dom[v.index]) > SPAN_GAP * H]
bmesh.ops.delete(bm_, geom=span, context='FACES_ONLY'); bm_.faces.ensure_lookup_table()
bridge = [f for f in bridge if f.is_valid]
dup = {}; body_w = {}; vlist_ = list(bm_.verts)                 # new vertices outdate the index table
for f in bridge:                                         # the body corners' weights, pooled per sleeve corner they replace
    bw_ = [ _W[v.index] for v in f.verts if not _arm_dom[v.index] ]
    for v in f.verts:
        if _arm_dom[v.index]:
            body_w.setdefault(v.index, []).extend(bw_)
for vi, ws in body_w.items():
    acc = {}
    for w in ws:
        for g, x in w.items():
            acc[g] = acc.get(g, 0.0) + x / len(ws)
    nv = bm_.verts.new(vlist_[vi].co); nv[dl_].clear()
    for g, x in tc.top4(acc, "mixamorig:Hips").items():
        if g not in gidx:
            gidx[g] = coat.vertex_groups.new(name=g).index
        nv[dl_][gidx[g]] = x
    dup[vi] = nv
for f in bridge:
    vs = [dup.get(v.index, v) for v in f.verts]; uvs = [tuple(l[uvl_].uv) for l in f.loops] if uvl_ else None; sm = f.smooth
    try:
        nf = bm_.faces.new(vs)
    except ValueError:
        continue
    nf.smooth = sm
    if uvl_:
        for l, uv in zip(nf.loops, uvs):
            l[uvl_].uv = uv
    bm_.faces.remove(f)
bm_.to_mesh(coat.data); bm_.free(); coat.data.update()
print(f"[{TAG}] coat: {n_cut} vertices weighted to an arm AND a leg, cut to one; {n_w} vertices share weights with a neighbour within "
      f"{WELD_W * 100:.1f} % of H; fused sleeve / body faces: {len(span)} spanning the gap cut, {len(bridge)} on the body given to it ({len(dup)} corners duplicated)")
rebind(coat)
# SKIRT BONES (ACTOR D88, Director 2026-10-30: "Aceito ossos no casaco, acho que é uma ótima forma de adaptar ao corpo"): SKB_N chains of
# SKB_SEG bones hang from Hips round the skirt, each joint ON the cloth at its azimuth and height (the mean radius of the skirt's points
# there), the azimuths offset half a step so no chain sits in the open front. The game runs them as springs colliding with capsules on the
# legs (SpringBoneSimulator3D); the clips never key them, so in Blender they stay at rest on the hips. A skirt point (below the hips, not a
# sleeve) takes the two chains beside it (by angle) and the bones along them (a tent per bone), blended over its C4 weights from 0 at the
# hips to 1 at SKB_RAMP of the skirt's length. SKB_N=0 turns it off.
SKB_N = int(os.environ.get("SKB_N", "8")); SKB_SEG = int(os.environ.get("SKB_SEG", "3")); SKB_RAMP = float(os.environ.get("SKB_RAMP", "0.3"))
if SKB_N > 0:
    KV = wverts(coat); KW = tc.read_weights(coat)
    hipj = np.array((armB.matrix_world @ armB.data.bones["mixamorig:Hips"].head_local)[:]); hz4 = hipj[2]
    k_arm = np.array([sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) >= 0.5 for w in KW])
    # no thigh weight at or above the hips (the female's side pocket flap, at the hips, took her trousers' RightUpLeg 0.9 and flew off
    # beside her when the leg kicked, 2026-10-30): a leg's share fades to nothing over LEG_TOP of H below the Hips joint, given to Hips
    LEG_TOP = float(os.environ.get("LEG_TOP", "0.04")); n_top = 0
    for i, w in enumerate(KW):
        f_ = min(1.0, max(0.0, (hz4 - KV[i, 2]) / (LEG_TOP * H)))
        leg_ = {g: x for g, x in w.items() if "Leg" in g or "Foot" in g}
        if leg_ and f_ < 1.0:
            w2 = {g: x for g, x in w.items() if g not in leg_}
            w2["mixamorig:Hips"] = w2.get("mixamorig:Hips", 0.0) + sum(leg_.values()) * (1 - f_)
            for g, x in leg_.items():
                w2[g] = x * f_
            KW[i] = tc.top4({g: x for g, x in w2.items() if x > 0}, "mixamorig:Hips"); n_top += 1
    print(f"[{TAG}] coat: {n_top} vertices near or above the hips lose their leg weight to Hips")
    # below the elbows a point is sleeve OR body, never both (the female's hand hangs on her coat's side: the smoothing gave the panel there
    # a quarter of RightForeArm, it was dragged off with the arm in the kick and the Hips-only flap in it was left floating, 2026-10-30)
    elb4 = max((armB.matrix_world @ armB.data.bones["mixamorig:" + sd + "ForeArm"].head_local).z for sd in ("Left", "Right")); n_ab = 0
    for i, w in enumerate(KW):
        if KV[i, 2] < elb4:
            a_ = {g: x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))}
            if a_ and len(a_) < len(w):
                keep_ = a_ if sum(a_.values()) >= 0.5 else {g: x for g, x in w.items() if g not in a_}
                KW[i] = tc.top4(keep_, "mixamorig:Hips"); n_ab += 1
    print(f"[{TAG}] coat: {n_ab} vertices below the elbows cut to sleeve or body")
    # a body point nearer a FOREARM than the body under the coat is sleeve (within 8 % of H of it, past its first third): Tripo fused the
    # female's right cuff strap to her coat's side, it took the skirt's weights and stayed at her hip while the arm moved, floating off the
    # coat (2026-10-30; measured: the strap 6-7 cm off the forearm and 10-14 cm off the trousers, the side panel by her hand 1-2 cm off them)
    _bodyV = [wverts(mB["Outfit_Trousers"])] if "Outfit_Trousers" in mB else []        # the shirt's TORSO only: its sleeve lies under the cuff
    if "Outfit_Shirt" in mB:
        _bodyV.append(wverts(mB["Outfit_Shirt"])[armness(tc.read_weights(mB["Outfit_Shirt"])) < 0.5])
    _bodyV = np.concatenate(_bodyV); kdb_ = KDTree(len(_bodyV))
    for j, q in enumerate(_bodyV):
        kdb_.insert(Vector(q), j)
    kdb_.balance(); n_band = 0
    for sd in ("Left", "Right"):
        fa_, fb_ = (np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + sd + n].head_local)[:]) for n in ("ForeArm", "Hand"))
        L_ = np.linalg.norm(fb_ - fa_); u_ = (fb_ - fa_) / L_; tq = np.clip((KV - fa_) @ u_ / L_, 0, 1)
        dq = np.linalg.norm(KV - (fa_ + np.outer(tq * L_, u_)), axis=1)
        for i in np.nonzero((dq < 0.08 * H) & (tq > 0.3))[0]:
            if sum(x for g, x in KW[i].items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) < 0.5 and dq[i] < kdb_.find(Vector(KV[i]))[2]:
                KW[i] = {"mixamorig:" + sd + "ForeArm": 1.0}; n_band += 1
    # and the faces Tripo fused between such a band and the body are cut (they stretched into a blade from her hip to her hand)
    n_bcut = 0
    if n_band:
        armq = [sum(x for g, x in w.items() if any(k in g for k in ("Arm", "Hand", "Shoulder"))) >= 0.5 for w in KW]
        bmq = bmesh.new(); bmq.from_mesh(coat.data); bmq.faces.ensure_lookup_table()
        cutq = [f for f in bmq.faces if len({armq[v.index] for v in f.verts}) == 2 and min(KV[v.index, 2] for v in f.verts) < elb4]
        n_bcut = len(cutq); bmesh.ops.delete(bmq, geom=cutq, context='FACES_ONLY'); bmq.to_mesh(coat.data); bmq.free(); coat.data.update()
    print(f"[{TAG}] coat: {n_band} body vertices nearer a forearm than the body made sleeve, {n_bcut} faces joining them to the body cut")
    sk = (KV[:, 2] < hz4) & ~k_arm; hem4 = KV[sk, 2].min(); L4 = hz4 - hem4
    rel = KV[:, :2] - hipj[:2]; ang = np.arctan2(rel[:, 1], rel[:, 0]); rad = np.linalg.norm(rel, axis=1)
    tt = np.clip((hz4 - KV[:, 2]) / L4, 0.0, 1.0); step = 2 * math.pi / SKB_N
    azs = [(k + 0.5) * step - math.pi for k in range(SKB_N)]
    def joint(k, j):                                     # the mean radius of the skirt's points within half a step / segment of the joint
        da = np.abs((ang - azs[k] + math.pi) % (2 * math.pi) - math.pi)
        m_ = sk & (da < step / 2) & (np.abs(tt - j / SKB_SEG) < 0.5 / SKB_SEG)
        r_ = float(rad[m_].mean()) if m_.any() else float(rad[sk].mean())
        return Vector((hipj[0] + r_ * math.cos(azs[k]), hipj[1] + r_ * math.sin(azs[k]), hz4 - L4 * j / SKB_SEG))
    bpy.context.view_layer.objects.active = armB; bpy.ops.object.mode_set(mode='EDIT')
    inv = armB.matrix_world.inverted(); eb_ = armB.data.edit_bones; names = {}
    for k in range(SKB_N):
        par = eb_["mixamorig:Hips"]
        for j in range(SKB_SEG):
            b_ = eb_.new(f"coat_skirt_{k}_{j}"); b_.head = inv @ joint(k, j); b_.tail = inv @ joint(k, j + 1)
            b_.parent = par; b_.use_connect = j > 0; b_.use_deform = True; par = b_; names[(k, j)] = b_.name
    bpy.ops.object.mode_set(mode='OBJECT')
    for i in np.nonzero(sk)[0]:
        a_ = (ang[i] + math.pi) / step - 0.5; k0 = int(math.floor(a_)) % SKB_N; fa_ = a_ - math.floor(a_)
        w_ = {}
        for k_, wk in ((k0, 1 - fa_), ((k0 + 1) % SKB_N, fa_)):
            for j in range(SKB_SEG):
                x = max(0.0, 1 - abs(tt[i] * SKB_SEG - (j + 0.5)))
                if j == 0 and tt[i] * SKB_SEG < 0.5 or j == SKB_SEG - 1 and tt[i] * SKB_SEG > SKB_SEG - 0.5:
                    x = 1.0
                if x * wk > 0:
                    w_[names[(k_, j)]] = w_.get(names[(k_, j)], 0.0) + x * wk
        s_ = min(1.0, tt[i] / SKB_RAMP); mix_ = {g: x * (1 - s_) for g, x in KW[i].items()}
        for g, x in w_.items():
            mix_[g] = mix_.get(g, 0.0) + x * s_
        KW[i] = tc.top4(mix_, "mixamorig:Hips")
    tc.write_weights(coat, KW)
    print(f"[{TAG}] skirt bones: {SKB_N} chains x {SKB_SEG} bones from Hips (z {hz4:.3f}) to the hem (z {hem4:.3f}); {int(sk.sum())} skirt "
          f"vertices weighted to them, full from {SKB_RAMP * 100:.0f} % of the skirt down")
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
    # and what the coat COVERS seen from outside (a ray away from the spine meets it within 8 % of H; between the lapels it does not): on the
    # male's shoulders the shirt showed between the coat's large triangles, neither deep in it nor out through it (2026-10-30)
    def covered(q):
        dv = Vector(away(q)); return Tc.ray_cast(Vector(q) + dv * 1e-4, dv, 0.08 * H)[0] is not None
    deep = [d_ or covered(q) for d_, q in zip(deep, SV)]
    # and what pokes OUT on the shoulder blades: the coat right behind it toward the spine (the toward-the-bone ray runs sideways there)
    def behind(q):
        dv = -Vector(away(q)); return Tc.ray_cast(Vector(q) + dv * 1e-4, dv, 0.05 * H)[0] is not None
    out_ = [o_ or (not covered(q) and behind(q)) for o_, q in zip(out_, SV)]
    # the COLLAR is never masked: from 4 % of H under the neck bone up (the female's shirt collar lies over her coat's collar stand, which
    # reads locally exactly like a spot coming through the coat, and both rules took it)
    keep = (SV[:, 2] > bh("Neck")[2] - 0.04 * H) & (np.linalg.norm(SV[:, :2] - bh("Neck")[:2], axis=1) < 0.06 * H)   # the collar ring only:
    # the band alone also kept the male's shoulder blades, which sit in it, and they showed through the coat (2026-10-30)
    deep = [d_ and not k_ for d_, k_ in zip(deep, keep)]; out_ = [o_ and not k_ for o_, k_ in zip(out_, keep)]
    sc_, nd = masked_copy(mB["Outfit_Shirt"], "Outfit_Shirt_Coated", lambda f: all(deep[v.index] for v in f.verts) or any(out_[v.index] for v in f.verts))
    print(f"[{TAG}] shirt mask: {nd} of {len(mB['Outfit_Shirt'].data.polygons)} shirt faces deep inside the coat or out through it ({sum(out_)} vertices out)"); extra.append(sc_)
    # the TROUSERS the same way, at the hips only (2026-10-30: the female's hips are wider than the coat at the belt, her trousers showed at
    # its back and sides; reaching the coat down there instead ballooned it): Outfit_Trousers_Coated
    if "Outfit_Trousers" in mB:
        TV_ = wverts(mB["Outfit_Trousers"]); hipz = bh("Hips")[2] - 0.08 * H
        def covered(q):                                  # the coat really over it, seen from outside (a ray away from the spine meets it):
            dv = Vector(away(q)); return Tc.ray_cast(Vector(q) + dv * 1e-4, dv, 0.08 * H)[0] is not None   # the open front is not
        tdeep = [q[2] > hipz and inside(Tc, q) and Tc.find_nearest(Vector(q))[3] > COAT_GAP * H and covered(q) for q in TV_]
        tout = [q[2] > hipz and not inside(Tc, q) and through_coat(q) for q in TV_]
        tc_, nd = masked_copy(mB["Outfit_Trousers"], "Outfit_Trousers_Coated",
                              lambda f: all(tdeep[v.index] for v in f.verts) or any(tout[v.index] for v in f.verts))
        print(f"[{TAG}] trousers mask: {nd} of {len(mB['Outfit_Trousers'].data.polygons)} trouser faces at the hips deep inside the coat or out through it ({sum(tout)} vertices out)")
        extra.append(tc_)
    # the BELT behind the side line (2026-10-31: the female's belt came through the coat's back at the waist): its back half lies under the
    # coat in every view, so Outfit_Belt_Coated keeps only the faces in front of the hips (the buckle's side); Outfit_Buckle is in front anyway
    if "Outfit_Belt" in mB:
        BV_ = wverts(mB["Outfit_Belt"]); hy = bh("Hips")[1]
        bc_, nd = masked_copy(mB["Outfit_Belt"], "Outfit_Belt_Coated", lambda f: all(BV_[v.index][1] > hy for v in f.verts))
        print(f"[{TAG}] belt mask: {nd} of {len(mB['Outfit_Belt'].data.polygons)} belt faces behind the hips")
        extra.append(bc_)
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
    dressed = [o for o in out_objs if o.name not in ("Body_Hair", "Outfit_Shirt", "Outfit_Trousers")]
    orig = {o.name: (list(o.data.materials), [p.use_smooth for p in o.data.polygons], [p.material_index for p in o.data.polygons]) for o in out_objs}
    base_of = {"Body_Hair_Hat": "Body_Hair", "Outfit_Shirt_Coated": "Outfit_Shirt", "Outfit_Trousers_Coated": "Outfit_Trousers"}
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
