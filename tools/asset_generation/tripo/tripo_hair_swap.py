# tripo_hair_swap.py — model 2 (the figure generated WITH the coat) wearing model 1's HAIR (ACTOR D86, Director 2026-10-28). Mixing bodies
# seamed badly at the collar (2's collar sits high on a long neck, 1's low on the shoulders; a seam at the neck stepped), so the head, neck,
# collar and tie stay 2's as generated and only the hair is 1's: carried onto 2's rest skeleton by its own weights (rest2 @ rest1^-1 per bone),
# set on 2's SKULL (the top 45 % of the head: centre and size per axis), scaled HAIR_K about that centre, lowered HAIR_DROP and moved HAIR_FWD
# forward (-y) (ratified by eye on the female: 0.90, 2 cm, 1 cm, "ate encostar na orelha"). 2's hat stays where it was generated, its front
# turned HAT_TILT degrees up about its centre ("uma leve rotacionada com a ponta da frente pra cima"), and the hair under it is MASKED as
# tripo_dress does (a face goes when all its vertices are under the hat, or one comes out through it). Lengths in metres (a ~1 m figure).
# Out: model 2 with Body_Hair (1's, placed) and Body_Hair_Hat (masked), the hat turned, 2's armature and clips; RV_OUT: head.png (4 views).
# Env: HAIR_1, HAIR_2 (tripo_assemble outputs), HAIR_OUT; RV_OUT; HAIR_K, HAIR_DROP, HAIR_FWD, HAT_TILT.
# Usage: blender -b -P tripo_hair_swap.py
import os, sys
import numpy as np
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_hair_swap"
P1, P2, OUT = os.environ["HAIR_1"], os.environ["HAIR_2"], os.environ["HAIR_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
HAIR_K = float(os.environ.get("HAIR_K", "0.90")); HAIR_DROP = float(os.environ.get("HAIR_DROP", "0.014"))
HAIR_FWD = float(os.environ.get("HAIR_FWD", "0.01")); HAT_TILT = float(os.environ.get("HAT_TILT", "6"))
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
    return a, {o.name.split(".")[0]: o for o in new if o.type == 'MESH' and o.vertex_groups}, [x for x in bpy.data.actions if x not in acts]


def set_world(o, V):
    inv = o.matrix_world.inverted()
    for v, q in zip(o.data.vertices, V):
        v.co = inv @ Vector(q)
    o.data.update()


arm1, m1, acts1 = imp(P1)
arm2, m2, acts2 = imp(P2)
for need, m, f in (("Body_Hair", m1, P1), ("Body_Head", m1, P1), ("Body_Hair", m2, P2), ("Body_Head", m2, P2), ("Outfit_Hat", m2, P2)):
    if need not in m:
        tc.fail(TAG, f"{f} has no {need} (is it a tripo_assemble output?): {sorted(m)}")
for a in acts1:
    bpy.data.actions.remove(a)
bpy.context.view_layer.update()
DM = {b.name: (arm2.matrix_world @ arm2.data.bones[b.name].matrix_local) @ (arm1.matrix_world @ b.matrix_local).inverted()
      for b in arm1.data.bones if b.name in arm2.data.bones}


def carried(o):
    V = tc.world_verts(o)
    for i, w in enumerate(tc.read_weights(o)):
        acc = Vector((0, 0, 0)); ws = 0.0
        for g, x in w.items():
            if g in DM:
                acc += (DM[g] @ Vector(V[i])) * x; ws += x
        if ws:
            V[i] = (acc / ws)[:]
    return V


def skull(V):
    t = V[:, 2].max(); return V[V[:, 2] > t - 0.45 * np.ptp(V[:, 2])]


hair = m1["Body_Hair"]; HV = carried(hair); s1, s2 = skull(carried(m1["Body_Head"])), skull(tc.world_verts(m2["Body_Head"]))
c1, c2 = (s1.min(0) + s1.max(0)) / 2, (s2.min(0) + s2.max(0)) / 2; k = np.ptp(s2, axis=0) / np.ptp(s1, axis=0)
HV = (HV - c1) * k * HAIR_K + c2 - np.array([0.0, HAIR_FWD, HAIR_DROP])
# and turned HAIR_TILT degrees about its own centre, the front (-y) up ("rotacionar o cabelo ligeiramente no lugar pra ponta da frente
# ficar mais pra cima")
HAIR_TILT = float(os.environ.get("HAIR_TILT", "12")); hc_ = (HV.min(0) + HV.max(0)) / 2
HV = (HV - hc_) @ np.array(Matrix.Rotation(np.radians(-HAIR_TILT), 3, 'X')).T + hc_
set_world(hair, HV)
mw = hair.matrix_world.copy(); hair.parent = arm2; hair.matrix_world = mw
for md in hair.modifiers:
    if md.type == 'ARMATURE':
        md.object = arm2
print(f"[{TAG}] 1's hair on 2's skull: skull scale {np.round(k, 3).tolist()} x {HAIR_K}, {HAIR_DROP * 100:.0f} cm down, {HAIR_FWD * 100:.0f} cm forward")
bpy.data.objects.remove(m2.pop("Body_Hair"))
# the TORSO from 1 (Director, 2026-10-28: "tirar toda a camisa rosa do modelo 3 e deixar so a gravata e a gola com o colarinho. As maos
# tambem podem sair [...] colocar todo o torso, com ombros, bracos e maos (menos gravata e colarinho), do 1 no 3"): TORSO=1 cuts 2's shirt
# down to its collar (faces wholly above the Neck joint - COLLAR_DOWN of H) and drops 2's hands; TORSO=2 also brings 1's shirt WITHOUT its
# collar piece and 1's hands, carried onto 2's skeleton
TORSO = int(os.environ.get("TORSO", "0")); COLLAR_DOWN = float(os.environ.get("COLLAR_DOWN", "0.0"))
keep1 = set()


def cut(o, gone, keep=None):
    """drop the faces of o wholly on the gone side, unless every vertex of the face is in `keep` (a mask per vertex)"""
    V_ = tc.world_verts(o); bm_ = bmesh.new(); bm_.from_mesh(o.data); bm_.faces.ensure_lookup_table()
    d_ = [bm_.faces[p_.index] for p_ in o.data.polygons
          if all(gone(V_[v]) for v in p_.vertices) and not (keep is not None and all(keep[v] for v in p_.vertices))]
    bmesh.ops.delete(bm_, geom=d_, context='FACES')
    bmesh.ops.delete(bm_, geom=[v for v in bm_.verts if not v.link_faces], context='VERTS'); bm_.to_mesh(o.data); bm_.free(); o.data.update()
    return len(d_)


if TORSO >= 1:
    H2 = max(tc.world_verts(o)[:, 2].max() for o in m2.values())
    nz2 = (arm2.matrix_world @ arm2.data.bones["mixamorig:Neck"].head_local).z - COLLAR_DOWN * H2
    # the tie's KNOT stays: it is its own closed piece inside 2's shirt mesh (a welded island, 103 vertices on the female), the one nearest
    # the tie's top ("recorta so o no do modelo 2"; a box or a radius round the tie's top took collar flaps or chest triangles with it)
    sh2_ = m2["Outfit_Shirt"]; SV_ = tc.world_verts(sh2_); isl = tc.welded_islands(SV_, sh2_.data.edges, H2)
    TT = tc.world_verts(m2["Outfit_Tie"]); top_ = TT[np.argmax(TT[:, 2])]
    knot_isl = isl[np.argmin(np.linalg.norm(SV_ - top_, axis=1))]
    n_ = cut(sh2_, lambda q: q[2] < nz2, keep=(isl == knot_isl))
    print(f"[{TAG}] the tie's knot kept ({int((isl == knot_isl).sum())} vertices, its own island)")
    bpy.data.objects.remove(m2.pop("Body_Hands"))
    print(f"[{TAG}] 2's shirt cut to its collar (above z {nz2:.3f}, {n_} faces dropped), 2's hands dropped")
if TORSO >= 2:
    H1 = max(tc.world_verts(o)[:, 2].max() for o in m1.values())
    # and 1's BELT and buckle for 2's ("tirar o cinto tambem, e substituir pelo cinto do 1")
    for n in ("Outfit_Belt", "Outfit_Buckle"):
        bpy.data.objects.remove(m2.pop(n))
    for n in ("Outfit_Shirt", "Body_Hands", "Outfit_Belt", "Outfit_Buckle"):
        o = m1[n]
        if n == "Outfit_Shirt":                          # its COLLAR is its own piece (the welded island reaching highest): it goes whole,
            SV1 = tc.world_verts(o); isl1 = tc.welded_islands(SV1, o.data.edges, H1)     # so the neckline follows the model's own seam
            col1 = max(np.unique(isl1), key=lambda i: SV1[isl1 == i, 2].max())
            gone1 = isl1 == col1
            bm1 = bmesh.new(); bm1.from_mesh(o.data); bm1.faces.ensure_lookup_table()
            d1 = [bm1.faces[p_.index] for p_ in o.data.polygons if gone1[p_.vertices[0]]]
            bmesh.ops.delete(bm1, geom=d1, context='FACES')
            bmesh.ops.delete(bm1, geom=[v for v in bm1.verts if not v.link_faces], context='VERTS'); bm1.to_mesh(o.data); bm1.free(); o.data.update()
            print(f"[{TAG}] 1's shirt without its collar piece ({int(gone1.sum())} vertices, {len(d1)} faces)")
        set_world(o, carried(o)); mw_ = o.matrix_world.copy(); o.parent = arm2; o.matrix_world = mw_
        for md in o.modifiers:
            if md.type == 'ARMATURE':
                md.object = arm2
        keep1.add(o)
    m1["Outfit_Shirt"].name = "Outfit_Shirt_Body"
    # the belt BELT_DOWN lower and BELT_BACK toward the back (+y), metres ("desloca o cinto pra baixo uns 8mm e pra tras uns 4mm")
    BELT_DOWN = float(os.environ.get("BELT_DOWN", "0.008")); BELT_BACK = float(os.environ.get("BELT_BACK", "0.004"))
    # and BELT_GROW metres larger on every axis, about the strap's centre ("aumenta o cinto todo 4mm"); the buckle follows the strap
    BELT_GROW = float(os.environ.get("BELT_GROW", "0.004"))
    SB = tc.world_verts(m1["Outfit_Belt"]); bc_ = (SB.min(0) + SB.max(0)) / 2; kb = (np.ptp(SB, axis=0) + BELT_GROW) / np.ptp(SB, axis=0)
    for n in ("Outfit_Belt", "Outfit_Buckle"):
        BV = tc.world_verts(m1[n]); BV = bc_ + (BV - bc_) * kb; BV[:, 2] -= BELT_DOWN; BV[:, 1] += BELT_BACK; set_world(m1[n], BV)
    # 2's TROUSERS came through 1's shirt above the belt at the back, so their top is masked.
    # The line follows the SHIRT'S HEM ("a mascara tem que ser precisa para acompanhar a linha de baixo da camisa"): per azimuth about the
    # hips' vertical, the lowest point of 1's shirt body (arm-weighted vertices left out), and a trousers face wholly above it + TROUSER_TOP
    # (metres; negative = under the hem) goes; a level cut left the band the shirt's hem rises over at the back
    TROUSER_TOP = float(os.environ.get("TROUSER_TOP", "0.002")); NB_ = 48
    hp_ = np.array((arm2.matrix_world @ arm2.data.bones["mixamorig:Hips"].head_local)[:])
    SB_ = tc.world_verts(m1["Outfit_Shirt"])
    aw1 = np.array([sum(x for g, x in w.items() if any(k_ in g for k_ in ("Shoulder", "Arm", "Hand"))) / (sum(w.values()) or 1.0)
                    for w in tc.read_weights(m1["Outfit_Shirt"])])
    SB_ = SB_[aw1 < 0.5]
    azb = lambda P: (((np.arctan2(P[:, 1] - hp_[1], P[:, 0] - hp_[0]) + np.pi) / (2 * np.pi) * NB_).astype(int) % NB_)
    hem_ = np.full(NB_, np.inf); np.minimum.at(hem_, azb(SB_), SB_[:, 2])
    for _ in range(3):
        hem_ = np.where(np.isfinite(hem_), hem_, np.minimum(np.roll(hem_, 1), np.roll(hem_, -1)))
    n_ = cut(m2["Outfit_Trousers"], lambda q: q[2] > hem_[azb(q[None])[0]] + TROUSER_TOP)
    print(f"[{TAG}] trousers: {n_} faces above the shirt's hem (z {hem_.min():.3f}-{hem_.max():.3f}) + {TROUSER_TOP * 1000:.0f} mm masked")
for o in m1.values():
    if o is not hair and o not in keep1:
        bpy.data.objects.remove(o)
bpy.data.objects.remove(arm1)
hair.name = "Body_Hair"

# the COAT scaled COAT_SCALE about the Neck joint, so it stays hung on the shoulders ("resize no casaco inteiro pra 104%")
COAT_SCALE = float(os.environ.get("COAT_SCALE", "1"))
if COAT_SCALE != 1 and "Outfit_Coat" in m2:
    nk = np.array((arm2.matrix_world @ arm2.data.bones["mixamorig:Neck"].head_local)[:])
    CV_ = tc.world_verts(m2["Outfit_Coat"]); set_world(m2["Outfit_Coat"], nk + (CV_ - nk) * COAT_SCALE)
    print(f"[{TAG}] coat scaled x{COAT_SCALE} about the Neck joint")
# the coat's INNER NECK WALL pushed BACK (Director, 2026-10-28: "o modelo do casaco tem uma anomalia no interior, uma massa interna perto da
# gola [...] empurrar os vertices sobressaindo pra tras, tentando dessa vez nao mexer com o fundo do casaco"): the coat generation closes its
# neckline with a front-facing wall behind the opening (|x| < NECK_X, from 6 cm under the Spine2 joint to 2 cm over the Neck joint, within
# 3 cm in front of the Neck joint); each of its vertices goes back (+y) to NECK_BACK behind the Neck joint's plane, the move faded by a cosine
# over NECK_R onto the coat round it; nothing behind the Neck joint + 2 cm moves (the coat's back). It runs BEFORE the chest push: pushed
# out from the spine, that wall crossed the shirt's front under the tie
NECK_PUSH = os.environ.get("NECK_PUSH", "0") != "0"
if NECK_PUSH and "Outfit_Coat" in m2:
    from mathutils.kdtree import KDTree
    NECK_X = float(os.environ.get("NECK_X", "0.07")); NECK_BACK = float(os.environ.get("NECK_BACK", "0.0")); NECK_R = float(os.environ.get("NECK_R", "0.015"))
    coat = m2["Outfit_Coat"]; CV = tc.world_verts(coat)
    nk = arm2.matrix_world @ arm2.data.bones["mixamorig:Neck"].head_local; s2 = arm2.matrix_world @ arm2.data.bones["mixamorig:Spine2"].head_local
    front = np.zeros(len(CV), bool)
    for p_ in coat.data.polygons:
        if (coat.matrix_world.to_3x3() @ p_.normal).y < -0.2:
            front[list(p_.vertices)] = True
    wall = (front & (np.abs(CV[:, 0]) < NECK_X) & (CV[:, 2] > s2.z - 0.06) & (CV[:, 2] < nk.z + 0.02)
            & (CV[:, 1] > nk.y - 0.03) & (CV[:, 1] < nk.y + 0.02))
    need = np.where(wall, np.maximum(0.0, nk.y + NECK_BACK - CV[:, 1]), 0.0)
    src = np.nonzero(need > 0)[0]
    if len(src):
        kd = KDTree(len(src))
        for k_, i in enumerate(src):
            kd.insert(Vector(CV[i].tolist()), k_)
        kd.balance(); mv = np.zeros(len(CV))
        for i in np.nonzero(CV[:, 1] < nk.y + 0.02)[0]:
            for (_c, k_, r_) in kd.find_range(Vector(CV[i].tolist()), NECK_R):
                mv[i] = max(mv[i], need[src[k_]] * 0.5 * (1 + np.cos(np.pi * r_ / NECK_R)))
        CV[:, 1] += mv; set_world(coat, CV)
        print(f"[{TAG}] coat inner neck wall: {int(wall.sum())} vertices, pushed back up to {mv.max() * 1000:.1f} mm ({int((mv > 0).sum())} moved)")
# SLEEVE FIT (Director, 2026-10-28: "selecionar alguns vertices nas mangas [...] e puxar levemente pra fora, pra cobrir a camisa [...]
# alargando o tecido sem deformar o shape do casaco"): each of 1's shirt-sleeve vertices is cast from its arm bone outward; where it lies past
# the coat sleeve's OUTERMOST wall (or within SLEEVE_GAP of it) it makes a constraint, the excess. Every coat sleeve vertex (arm weight >= 0.5)
# then moves AWAY FROM ITS ARM BONE by the strongest constraint around it, faded by a cosine over SLEEVE_R; moving from the bone carries the
# outer wall and the lining the same way, so the thickness and the cut stay. Repeated SLEEVE_IT times. Lengths in metres.
SLEEVE_GAP = float(os.environ.get("SLEEVE_GAP", "0.002")); SLEEVE_R = float(os.environ.get("SLEEVE_R", "0.04"))
SLEEVE_IT = int(os.environ.get("SLEEVE_IT", "0"))
# the same push on the CHEST (CHEST_IT; "mais um pedacinho aqui que precisa do mesmo ajuste", under the lapel): 1's shirt BODY points (arm
# weight < 0.5) against the coat's torso, each coat torso vertex moved away from the SPINE chain
CHEST_IT = int(os.environ.get("CHEST_IT", "0"))
if (SLEEVE_IT > 0 or CHEST_IT > 0) and "Outfit_Shirt_Body" in [o.name for o in bpy.data.objects]:
    from mathutils.kdtree import KDTree
    coat = m2["Outfit_Coat"]; shirt = bpy.data.objects["Outfit_Shirt_Body"]
    bh = lambda n: np.array((arm2.matrix_world @ arm2.data.bones["mixamorig:" + n].head_local)[:])
    ARMS = [(bh(sd + a_), bh(sd + b_)) for sd in ("Left", "Right") for a_, b_ in (("Arm", "ForeArm"), ("ForeArm", "Hand"))]
    SPINE = [(bh(a_), bh(b_)) for a_, b_ in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
    armw = lambda o: np.array([sum(x for g, x in w.items() if any(k_ in g for k_ in ("Arm", "Hand"))) / (sum(w.values()) or 1.0)
                               for w in tc.read_weights(o)])
    cw, sw = armw(coat), armw(shirt)

    def push(segs, coat_mask, SQ, iters, label, cap=1.0, radius=None):
        R_ = radius or SLEEVE_R
        def bone_of(q):
            best = None
            for a_, b_ in segs:
                ab = b_ - a_; t = np.clip((q - a_) @ ab / (ab @ ab), 0, 1); c = a_ + t * ab; d = np.linalg.norm(q - c)
                if best is None or d < best[0]:
                    best = (d, c)
            return best
        for it in range(iters):
            CV = tc.world_verts(coat); coat.data.calc_loop_triangles()
            TC = BVHTree.FromPolygons([tuple(q) for q in CV], [tuple(t.vertices) for t in coat.data.loop_triangles])
            cons = []
            for q in SQ:
                dq, c = bone_of(q); u = (q - c) / max(dq, 1e-9); o = Vector(c.tolist()); far = 0.0; last = None
                while True:
                    r = TC.ray_cast(o, Vector(u.tolist()), dq + 0.03 - far)
                    if r[0] is None:
                        break
                    far += (r[0] - o).length + 1e-6; last = r[0]; o = r[0] + Vector(u.tolist()) * 1e-6
                if last is not None and far < dq + SLEEVE_GAP:        # a coat wall past it on that ray but too close: through
                    cons.append((q, dq + SLEEVE_GAP - far))
                elif last is None and coat_hit(TC, c, u, dq):         # the coat lies between the bone and it: it is outside
                    cons.append((q, 2 * SLEEVE_GAP))
            print(f"[{TAG}] {label} fit pass {it + 1}: {len(cons)} shirt points through the coat")
            if not cons:
                break
            kd = KDTree(len(cons))
            for k_, (q, _n) in enumerate(cons):
                kd.insert(Vector(q.tolist()), k_)
            kd.balance(); mv = 0.0
            for i in np.nonzero(coat_mask)[0]:
                best = 0.0
                for (_c, k_, r_) in kd.find_range(Vector(CV[i].tolist()), R_):
                    best = max(best, min(cons[k_][1], cap) * 0.5 * (1 + np.cos(np.pi * r_ / R_)))
                if best > 0:
                    dq, c = bone_of(CV[i]); CV[i] = CV[i] + (CV[i] - c) / max(dq, 1e-9) * best; mv = max(mv, best)
            set_world(coat, CV); print(f"[{TAG}]   largest push {mv * 1000:.1f} mm")

    def coat_hit(TC, c, u, dq):
        r = TC.ray_cast(Vector(c.tolist()), Vector(u.tolist()), dq)
        return r[0] is not None
    if SLEEVE_IT > 0:
        push(ARMS, cw >= 0.5, tc.world_verts(shirt)[sw >= 0.5], SLEEVE_IT, "sleeve")
    # the other way on the CHEST (SHIRT_IN; "fazer ao contrario e empurrar os vertices da camisa rosa em baixo da gola 2mm pra dentro"): 1's
    # shirt-body points above the Spine1 joint that come through the coat pull every shirt-body vertex within SHIRT_IN_R of them SHIRT_IN
    # metres toward the spine chain (cosine fade), the coat untouched
    SHIRT_IN = float(os.environ.get("SHIRT_IN", "0")); SHIRT_IN_R = float(os.environ.get("SHIRT_IN_R", "0.02"))
    SHIRT_IN_IT = int(os.environ.get("SHIRT_IN_IT", "1"))     # passes; each re-finds what still comes through ("so na regiao que ainda aparece")
    for _pass in range(SHIRT_IN_IT if SHIRT_IN > 0 else 0):
        def spine_pt(q):
            best = None
            for a_, b_ in SPINE:
                ab = b_ - a_; t = np.clip((q - a_) @ ab / (ab @ ab), 0, 1); c = a_ + t * ab; d = np.linalg.norm(q - c)
                if best is None or d < best[0]:
                    best = (d, c)
            return best
        CV = tc.world_verts(coat); coat.data.calc_loop_triangles()
        TC = BVHTree.FromPolygons([tuple(q) for q in CV], [tuple(t.vertices) for t in coat.data.loop_triangles])
        # what SHOWS: a shirt point above the Spine2 joint with no coat outward of it (away from the spine), off the front opening (where the
        # shirt shows between the lapels by design: |x| < 5 cm in front of the Neck joint)
        # what SHOWS from the SIDE views (the review cameras at 90 and 270 degrees, 8 degrees up): a shirt point above the Spine2 joint whose
        # ray toward that camera meets no coat (testing outward from the spine flagged the BACK, where nothing showed)
        SV = tc.world_verts(shirt); s2z = bh("Spine2")[2]; hits = []
        e8 = np.radians(8); cams = [Vector((np.cos(e8) * np.sin(np.radians(az)), -np.cos(e8) * np.cos(np.radians(az)), np.sin(e8))) for az in (90, 270)]
        for i in np.nonzero((sw < 0.5) & (SV[:, 2] > s2z))[0]:
            q = Vector(SV[i].tolist())
            if any(TC.ray_cast(q + d * 1e-4, d, 2.0)[0] is None and (q - Vector(bh("Neck").tolist())).dot(d) > 0 for d in cams):
                hits.append(SV[i].copy())
        if not hits:
            print(f"[{TAG}] shirt pull pass {_pass + 1}: nothing shows"); break
        if hits:
            kd = KDTree(len(hits))
            for k_, q in enumerate(hits):
                kd.insert(Vector(q.tolist()), k_)
            kd.balance(); moved = 0
            for i in np.nonzero(sw < 0.5)[0]:
                best = 0.0
                for (_c, _k, r_) in kd.find_range(Vector(SV[i].tolist()), SHIRT_IN_R):
                    best = max(best, SHIRT_IN * 0.5 * (1 + np.cos(np.pi * r_ / SHIRT_IN_R)))
                if best > 0:
                    dq, c = spine_pt(SV[i]); SV[i] = SV[i] - (SV[i] - c) / max(dq, 1e-9) * best; moved += 1
            set_world(shirt, SV)
        print(f"[{TAG}] shirt pull pass {_pass + 1}: {len(hits)} points showing, pulled {SHIRT_IN * 1000:.1f} mm")
    if CHEST_IT > 0:
        sv_ = tc.world_verts(shirt); nk_ = bh("Neck")[2]; sp_ = bh("Spine")[2]
        push(SPINE, cw < 0.5, sv_[(sw < 0.5) & (sv_[:, 2] > sp_) & (sv_[:, 2] < nk_)], CHEST_IT, "chest")
    # UNDER THE COLLAR only (COLLAR_IT; "puxar so aquela area do casaco pra fora (parede dupla)"): the shirt points between the Spine2 and the
    # Neck joints, each pass's push capped at COLLAR_CAP and spread over COLLAR_R (the chest push, uncapped, swelled the shoulder 40-55 mm)
    COLLAR_IT = int(os.environ.get("COLLAR_IT", "0"))
    if COLLAR_IT > 0:
        sv_ = tc.world_verts(shirt); nk_ = bh("Neck")[2]; s2_ = bh("Spine2")[2]
        push(SPINE, cw < 0.5, sv_[(sw < 0.5) & (sv_[:, 2] > s2_) & (sv_[:, 2] < nk_ + 0.01)], COLLAR_IT, "under-collar",
             cap=float(os.environ.get("COLLAR_CAP", "0.004")), radius=float(os.environ.get("COLLAR_R", "0.02")))
hat = m2["Outfit_Hat"]; TV = tc.world_verts(hat); pv = (TV.min(0) + TV.max(0)) / 2
TV = (TV - pv) @ np.array(Matrix.Rotation(np.radians(-HAT_TILT), 3, 'X')).T + pv        # the front (-y) up
TV[:, 1] += float(os.environ.get("HAT_BACK", "0.006"))   # metres toward the back (+y) ("desloca o chapeu pra tras 6mm")
TV[:, 2] -= float(os.environ.get("HAT_DOWN", "0.003"))   # metres down ("desce o chapeu todo 3 mm")
set_world(hat, TV); hat.data.calc_loop_triangles()
Th = BVHTree.FromPolygons([tuple(q) for q in TV], [tuple(t.vertices) for t in hat.data.loop_triangles])


def inside(q):
    n = 0; o = Vector(q); d = Vector((0.31, 0.17, 0.93)).normalized()
    for _ in range(64):
        r = Th.ray_cast(o, d)
        if r[0] is None:
            break
        n += 1; o = r[0] + d * 1e-6
    return n % 2 == 1


hv = tc.world_verts(hair)
cov = [(lambda r: r[0] is not None and q[2] > r[0].z - 0.002)(Th.ray_cast(Vector((q[0], q[1], q[2] - 1)), Vector((0, 0, 1)), 2)) for q in hv]
poke = [cov[i] and not inside(q) and Th.ray_cast(Vector((q[0], q[1], q[2] + 1e-5)), Vector((0, 0, 1)), 2)[0] is None for i, q in enumerate(hv)]
hh = hair.copy(); hh.data = hair.data.copy(); hh.name = hh.data.name = "Body_Hair_Hat"; bpy.context.scene.collection.objects.link(hh)
bm = bmesh.new(); bm.from_mesh(hh.data); bm.verts.ensure_lookup_table()
dead = [f for f in bm.faces if all(cov[v.index] for v in f.verts) or any(poke[v.index] for v in f.verts)]
bmesh.ops.delete(bm, geom=dead, context='FACES'); bm.to_mesh(hh.data); bm.free(); hh.data.update()
print(f"[{TAG}] hat turned {HAT_TILT:.0f} deg front up; hair mask: {len(dead)} of {len(hair.data.polygons)} faces ({sum(poke)} vertices came out through it)")

# the shirt MASK for the coated state (Director, 2026-10-28: "uma mascara pra camisa nao atravessar o casaco [...] o agente vai tirar o
# casaco durante o jogo, e a mascara precisa sair junto"): Outfit_Shirt_Body stays whole (coat off); Outfit_Shirt_Body_Coated is a copy
# without the faces that would show THROUGH the coat (see below). The game draws the coated copy while the
# coat is on, and the whole shirt when it comes off.
if os.environ.get("SHIRT_MASK", "1") != "0" and "Outfit_Shirt_Body" in [o.name for o in bpy.data.objects] and "Outfit_Coat" in m2:
    shirt = bpy.data.objects["Outfit_Shirt_Body"]; coat = m2["Outfit_Coat"]
    CV = tc.world_verts(coat); coat.data.calc_loop_triangles()
    TC = BVHTree.FromPolygons([tuple(q) for q in CV], [tuple(t.vertices) for t in coat.data.loop_triangles])
    e8 = np.radians(8)
    dirs = lambda azs: [Vector((np.cos(e8) * np.sin(np.radians(a_)), -np.cos(e8) * np.cos(np.radians(a_)), np.sin(e8))) for a_ in azs]
    # seen from ANY view (every 30 degrees) but outside the FRONT OPENING (|x| < MASK_OPEN in front of the Neck joint), where the shirt is
    # meant to show; sparing every face seen from the front kept the spots at the shoulders and under the lapel
    MASK_OPEN = float(os.environ.get("MASK_OPEN", "0.055"))
    allv = dirs(range(0, 360, 30)); nky_ = (arm2.matrix_world @ arm2.data.bones["mixamorig:Neck"].head_local).y
    SV = tc.world_verts(shirt)
    seen = lambda q, ds: any(TC.ray_cast(q + d * 1e-4, d, 2.0)[0] is None for d in ds)
    show = np.array([not (abs(q[0]) < MASK_OPEN and q[1] < nky_) and seen(Vector(q.tolist()), allv) for q in SV])
    sc_ = shirt.copy(); sc_.data = shirt.data.copy(); sc_.name = sc_.data.name = "Outfit_Shirt_Body_Coated"
    bpy.context.scene.collection.objects.link(sc_)
    bm = bmesh.new(); bm.from_mesh(sc_.data); bm.faces.ensure_lookup_table()
    d_ = [bm.faces[p_.index] for p_ in sc_.data.polygons if any(show[v] for v in p_.vertices)]
    bmesh.ops.delete(bm, geom=d_, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS'); bm.to_mesh(sc_.data); bm.free(); sc_.data.update()
    print(f"[{TAG}] shirt mask: Outfit_Shirt_Body_Coated drops {len(d_)} of {len(shirt.data.polygons)} faces ({int(show.sum())} vertices show through the coat)")
out_objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent is arm2]
for o in out_objs:                                       # 2's pieces came in second, as "Body_Head.001"
    o.name = o.name.split(".")[0]
if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    pal = {"Outfit_Hat": (0.30, 0.75, 0.70), "Outfit_Shirt": (0.85, 0.55, 0.85), "Outfit_Tie": (0.95, 0.85, 0.30), "Body_Head": (0.90, 0.70, 0.55),
           "Body_Hair_Hat": (0.45, 0.80, 0.35), "Outfit_Shirt_Body": (0.75, 0.45, 0.95), "Body_Hands": (0.95, 0.60, 0.45)}
    show = [o for o in out_objs if o.name in pal]
    for o in bpy.data.objects:
        if o.type == 'MESH' and o not in show:
            o.hide_render = True
    cam, co = tc.setup_renders(show, {o.name: pal[o.name] for o in show}); files = {}
    ctr = Vector(((s2.min(0) + s2.max(0)) / 2).tolist()) - Vector((0, 0, 0.05))
    for c_, az in enumerate((0, 90, 180, 270)):
        files[(0, c_)] = f"{RV_OUT}/hs_{c_}.png"; tc.shot(cam, co, files[(0, c_)], az, ctr, 0.32)
    tc.sheet(1, 4, files, f"{RV_OUT}/head.png"); print(f"[{TAG}] sheet {RV_OUT}/head.png")
tc.export(OUT, out_objs, arm2)
print(f"[{TAG}] wrote {OUT}")
