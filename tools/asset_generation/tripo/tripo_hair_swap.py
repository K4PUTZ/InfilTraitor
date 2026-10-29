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
