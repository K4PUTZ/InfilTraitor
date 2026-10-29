# tripo_compose.py — model 3: a body that fits INSIDE the coat of a coat generation (ACTOR D86, Director 2026-10-28: "montar uma versao do corpo
# que cabe dentro do casaco, misturando partes dos dois modelos"). 1 = the figure generated without the coat, 2 = the one generated with it
# (both tripo_assemble outputs, the same 65 joints). The coat and the skeleton are 2's, so the coat keeps the round fit it was generated with;
# from 1 come what 2 lacks or the Director prefers: the head and hair, the hands, the belt and buckle, the TIE, and the shirt's arms, chest,
# shoulders, COLLAR and back (the whole collar region is one model's, 1's: a seam at the neck with 2's collar stepped, Director 2026-10-28). Each piece of 1 is carried onto 2's rest
# skeleton by its own skin weights (a linear blend of rest2 @ rest1^-1 per bone, as tripo_dress does) and bound to 2's armature.
# From 2: the coat, the hat (placed on 1's head by the face, HAT_DY back and HAT_TILT, as tripo_dress), the shirt's belly front, the
# trousers and the shoes. 2's head, hair, hands, belt, buckle and tie are dropped.
# Out: one GLB (2's armature and clips); RV_OUT: hero.png and big4.png as tripo_dress.
# Env: COMP_1, COMP_2, COMP_OUT; RV_OUT; HAT_DY (default 0.015), ARM_MIN (default 0.3).
# Usage: blender -b -P tripo_compose.py
import math, os, sys
import numpy as np
import bpy
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_compose"
P1, P2, OUT = os.environ["COMP_1"], os.environ["COMP_2"], os.environ["COMP_OUT"]
RV_OUT = os.environ.get("RV_OUT", "").rstrip("/")
HAT_DY = float(os.environ.get("HAT_DY", "0.015")); HAT_TILT = 8.0; ARM_MIN = float(os.environ.get("ARM_MIN", "0.3"))
FROM_1 = ("Body_Head", "Body_Hair", "Body_Hands", "Outfit_Belt", "Outfit_Buckle", "Outfit_Shirt", "Outfit_Tie")
FROM_2 = ("Outfit_Coat", "Outfit_Hat", "Outfit_Shirt", "Outfit_Trousers", "Outfit_Shoes")
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


arm1, m1, acts1 = imp(P1)
arm2, m2, acts2 = imp(P2)
for need, m, f in [(n, m1, P1) for n in FROM_1] + [(n, m2, P2) for n in FROM_2]:
    if need not in m:
        tc.fail(TAG, f"{f} has no {need} (is it a tripo_assemble output?): {sorted(m)}")
for a in acts1:                                          # 2's skeleton and clips are the deliverable's
    bpy.data.actions.remove(a)
bpy.context.view_layer.update()
H = max(tc.world_verts(o)[:, 2].max() for o in m2.values())


def set_world(o, V):
    inv = o.matrix_world.inverted()
    for v, q in zip(o.data.vertices, V):
        v.co = inv @ Vector(q)
    o.data.update()


def rebind(o):
    mw = o.matrix_world.copy(); o.parent = arm2; o.matrix_world = mw
    for md in o.modifiers:
        if md.type == 'ARMATURE':
            md.object = arm2


DM = {b.name: (arm2.matrix_world @ arm2.data.bones[b.name].matrix_local) @ (arm1.matrix_world @ b.matrix_local).inverted()
      for b in arm1.data.bones if b.name in arm2.data.bones}


def carry(o):
    """o (a piece of 1) onto 2's rest skeleton by its own weights, bound to 2's armature"""
    V = tc.world_verts(o); W = tc.read_weights(o)
    for i, w in enumerate(W):
        acc = Vector((0, 0, 0)); ws = 0.0
        for g, x in w.items():
            M = DM.get(g)
            if M is not None:
                acc += (M @ Vector(V[i])) * x; ws += x
        if ws > 0:
            V[i] = (acc / ws)[:]
    set_world(o, V); rebind(o)


# 1's shirt: the arms, the whole chest, shoulders and upper back (above the Spine1 joint) and the whole BACK (behind the Spine joint)
# (Director, 2026-10-28: "melhorar as emendas no ombro, e completar as costas usando o modelo 1": 2's shirt is open at the back and its
# shoulders met 1's in a step); 2's shirt keeps only what 1's does not cover, the front of the belly
spine1 = arm1.matrix_world @ arm1.data.bones["mixamorig:Spine1"].head_local
spine0 = arm1.matrix_world @ arm1.data.bones["mixamorig:Spine"].head_local
sh1 = m1["Outfit_Shirt"]; V1 = tc.world_verts(sh1)
arm_w = np.array([sum(x for g, x in w.items() if any(k in g for k in ("Shoulder", "Arm", "Hand"))) / (sum(w.values()) or 1.0)
                  for w in tc.read_weights(sh1)])
keep_v = ((arm_w >= ARM_MIN) | (V1[:, 2] > spine1.z) | (V1[:, 1] > spine0.y))
dead = [p.index for p in sh1.data.polygons if not all(keep_v[v] for v in p.vertices)]
import bmesh
bm = bmesh.new(); bm.from_mesh(sh1.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in dead], context='FACES'); bm.to_mesh(sh1.data); bm.free(); sh1.data.update()
sh1.name = "Outfit_Shirt_Arms"
print(f"[{TAG}] 1's shirt: kept the arms, the chest and shoulders, the back ({len(sh1.data.polygons)} faces, {len(dead)} dropped)")
for n in FROM_1:
    carry(sh1 if n == "Outfit_Shirt" else m1[n])
fa = tc.world_verts(m1["Body_Head"])                     # 1's whole head on 2's skeleton (the hat is placed by it, before the neck seam)
for n in ("Body_Head", "Body_Hair", "Body_Hands", "Outfit_Belt", "Outfit_Buckle", "Outfit_Tie"):
    bpy.data.objects.remove(m2[n])
s1b = arm2.matrix_world @ arm2.data.bones["mixamorig:Spine1"].head_local; s0b = arm2.matrix_world @ arm2.data.bones["mixamorig:Spine"].head_local
sh2 = m2["Outfit_Shirt"]; V2 = tc.world_verts(sh2)
gone = ((V2[:, 2] > s1b.z) | (V2[:, 1] > s0b.y))
bm = bmesh.new(); bm.from_mesh(sh2.data); bm.faces.ensure_lookup_table()
d2 = [bm.faces[p.index] for p in sh2.data.polygons if all(gone[v] for v in p.vertices)]
bmesh.ops.delete(bm, geom=d2, context='FACES'); bm.to_mesh(sh2.data); bm.free(); sh2.data.update()
print(f"[{TAG}] 2's shirt: kept the front of the belly ({len(sh2.data.polygons)} faces, {len(d2)} dropped)")
# the BELT a little lower (Director, 2026-10-28: "descer um pouco o cinto"): BELT_DROP of H
# and BELT_BACK metres toward the back (+y; "deslocando o cinto 1 ou 2mm horizontalmente pra tras": 2's trousers came through it there)
# and BELT_GROW metres taller at its top and at its bottom (a z scale about the strap's mid height: "aumenta mais 1mm pra cada lado o scale
# do cinto no eixo Z"); the buckle follows the strap's scale
BELT_DROP = float(os.environ.get("BELT_DROP", "0.015")); BELT_BACK = float(os.environ.get("BELT_BACK", "0.006"))
BELT_GROW = float(os.environ.get("BELT_GROW", "0.001"))
# and BELT_WIDEN metres wider and deeper in all (an x / y scale about the strap's centre: "aumenta mais 2mm o size horizontal do cinto")
BELT_WIDEN = float(os.environ.get("BELT_WIDEN", "0.004"))
SV = tc.world_verts(m1["Outfit_Belt"]); zlo, zhi = SV[:, 2].min(), SV[:, 2].max(); zm = (zlo + zhi) / 2; kz = (zhi - zlo + 2 * BELT_GROW) / (zhi - zlo)
bc = (SV.min(0) + SV.max(0)) / 2; kxy = (np.ptp(SV[:, :2], axis=0) + BELT_WIDEN) / np.ptp(SV[:, :2], axis=0)
for n in ("Outfit_Belt", "Outfit_Buckle"):
    o = m1[n]; BV = tc.world_verts(o); BV[:, 2] = zm + (BV[:, 2] - zm) * kz; BV[:, :2] = bc[:2] + (BV[:, :2] - bc[:2]) * kxy
    BV[:, 2] -= BELT_DROP * H; BV[:, 1] += BELT_BACK; set_world(o, BV)
for n in set(m1) - set(FROM_1):
    bpy.data.objects.remove(m1[n])

# 2's hat on 1's head (tripo_dress's placement: by the face, HAT_DY back, the back tilted HAT_TILT down about the brow)
hat = m2["Outfit_Hat"]; HV = tc.world_verts(hat)
ar, mr, ac = imp(P2)                                     # a second, untouched copy of 2 for its head box (2's head was dropped above)
fb = tc.world_verts(mr["Body_Head"])
for o in list(mr.values()) + [ar]:
    bpy.data.objects.remove(o)
for a in ac:
    bpy.data.actions.remove(a)
HV += ((fa.min(0) + fa.max(0)) - (fb.min(0) + fb.max(0))) / 2.0
HV[:, 1] += HAT_DY * H
lo_, hi_ = HV.min(0), HV.max(0); piv = np.array([(lo_[0] + hi_[0]) / 2, lo_[1] + 0.25 * (hi_[1] - lo_[1]), lo_[2] + 0.25 * (hi_[2] - lo_[2])])
R = np.array(Matrix.Rotation(math.radians(-HAT_TILT), 3, 'X')); HV = (HV - piv) @ R.T + piv
set_world(hat, HV); tc.write_weights(hat, [{"mixamorig:Head": 1.0}] * len(hat.data.vertices))

# INFLATE (Director, 2026-10-28: "aumentar (expandir) o casaco inteiro 5 mm em todas as direcoes, so pra ver se cobre a camisa"): every coat
# vertex moved COAT_INFLATE (metres; the figure is ~1 m) AWAY FROM ITS BONE (the nearest point of the spine chain or of an arm), so the outer
# wall and the lining move the same way and the coat keeps its thickness (along the normals the lining would move INTO the body)
COAT_INFLATE = float(os.environ.get("COAT_INFLATE", "0"))
if COAT_INFLATE > 0:
    bh = lambda n: np.array((arm2.matrix_world @ arm2.data.bones["mixamorig:" + n].head_local)[:])
    SEGS = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
    SEGS += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]
    hb = bh("Hips"); SEGS.append((hb, hb - np.array([0, 0, H])))         # the skirt below the hips moves out from the hips' vertical
    coat = m2["Outfit_Coat"]; CV = tc.world_verts(coat)
    for i, q in enumerate(CV):
        best = None
        for a, b in SEGS:
            ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(q - c)
            if best is None or d < best[0]:
                best = (d, (q - c) / max(d, 1e-12))
        CV[i] = q + best[1] * COAT_INFLATE
    set_world(coat, CV); print(f"[{TAG}] coat inflated {COAT_INFLATE * 1000:.1f} mm away from its bones")

# COLLISION (Director, 2026-10-28: "liga a colisao do casaco com o corpo pra gente ver se somem as manchas rosas"): a Blender cloth run on
# the coat with NO gravity, the body pieces as single-sided colliders at COAT_GAP: only the coat vertices near a body piece are free (within
# FREE_R of H of one, faded), everything else pinned, so the coat keeps its shape and only steps off what comes through it; COLLIDE frames
COLLIDE = int(os.environ.get("COLLIDE", "0")); COAT_GAP = float(os.environ.get("COAT_GAP", "0.004")); FREE_R = float(os.environ.get("FREE_R", "0.03"))
if COLLIDE > 0:
    from mathutils.bvhtree import BVHTree
    coat = m2["Outfit_Coat"]; CV = tc.world_verts(coat); sc = bpy.context.scene
    bodies = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent is arm2 and o.name.split(".")[0] in
              ("Outfit_Shirt_Arms", "Outfit_Shirt", "Outfit_Tie", "Outfit_Belt", "Outfit_Buckle", "Outfit_Trousers")]
    dist = np.full(len(CV), np.inf)
    for b in bodies:
        BV = tc.world_verts(b); b.data.calc_loop_triangles()
        T = BVHTree.FromPolygons([tuple(q) for q in BV], [tuple(t.vertices) for t in b.data.loop_triangles])
        for i, q in enumerate(CV):
            hit = T.find_nearest(Vector(q), FREE_R * H)
            if hit[0] is not None:
                dist[i] = min(dist[i], hit[3])
    pin = np.clip(dist / (FREE_R * H), 0.0, 1.0)
    me = bpy.data.meshes.new("settle"); me.from_pydata([tuple(q) for q in CV], [], [list(p_.vertices) for p_ in coat.data.polygons]); me.update()
    so = bpy.data.objects.new("settle", me); sc.collection.objects.link(so); vg = so.vertex_groups.new(name="pin")
    for i, w in enumerate(pin):
        if w > 0:
            vg.add([i], float(w), 'REPLACE')
    cm = so.modifiers.new("Cloth", 'CLOTH'); cs = cm.settings
    cs.quality = 15; cs.mass = 0.15; cs.tension_stiffness = cs.compression_stiffness = 300.0; cs.shear_stiffness = 200.0; cs.bending_stiffness = 20.0
    cs.vertex_group_mass = "pin"; cs.pin_stiffness = 5.0; cs.effector_weights.gravity = 0.0
    cm.collision_settings.distance_min = COAT_GAP * H; cm.collision_settings.use_self_collision = False
    cm.point_cache.frame_start = 1; cm.point_cache.frame_end = COLLIDE
    cols = []
    for b in bodies:
        c_ = b.modifiers.new("Collision", 'COLLISION'); cl = b.collision; cl.thickness_outer = COAT_GAP * H; cl.thickness_inner = 0.001 * H
        cl.use_culling = cl.use_normal = True; cols.append((b, c_))
    for f_ in range(1, COLLIDE + 1):
        sc.frame_set(f_)
    ev = so.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    NV = np.array([(so.matrix_world @ v.co)[:] for v in ev.vertices]); so.to_mesh_clear()
    for b, c_ in cols:
        b.modifiers.remove(c_)
    bpy.data.objects.remove(so); sc.frame_set(1); set_world(coat, NV)
    print(f"[{TAG}] collision: {COLLIDE} frames, {int((pin < 1).sum())} coat vertices free near the body, moved up to "
          f"{np.linalg.norm(NV - CV, axis=1).max() / H * 100:.2f} % of H")

# the TROUSERS' top is MASKED (Director, 2026-10-28: "afundar a calca pra dentro da camisa, ou fazer uma mascara. A modelo nunca fica sem
# camisa nem calca"): 2's trousers are wider than 1's shirt there and came through it above the belt (1's shirt hem 0.532, belt top 0.602
# on the female: the shirt does reach down), so every trousers face lying wholly more than TROUSER_TOP metres above the belt's TOP edge is
# dropped (cut at the bottom edge, a see-through gap opened between the shirt and the belt: "a calca acaba um pouco acima do cinto")
TROUSER_TOP = float(os.environ.get("TROUSER_TOP", "0.004"))
tr = m2["Outfit_Trousers"]; TV = tc.world_verts(tr); bbot = tc.world_verts(m1["Outfit_Belt"])[:, 2].max() + TROUSER_TOP
bm = bmesh.new(); bm.from_mesh(tr.data); bm.faces.ensure_lookup_table()
dt = [bm.faces[p.index] for p in tr.data.polygons if all(TV[v, 2] > bbot for v in p.vertices)]
bmesh.ops.delete(bm, geom=dt, context='FACES'); bm.to_mesh(tr.data); bm.free(); tr.data.update()
print(f"[{TAG}] trousers: {len(dt)} faces above z {bbot:.3f} ({TROUSER_TOP * 1000:.0f} mm over the belt's top) masked")

out_objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent is arm2]
for o in out_objs:                                       # 2's pieces came in second, as "Outfit_Shirt.001"
    o.name = o.name.split(".")[0]
print(f"[{TAG}] model 3: {sorted(o.name for o in out_objs)}")
if RV_OUT:
    os.makedirs(RV_OUT, exist_ok=True)
    pal = {"Outfit_Coat": (0.80, 0.35, 0.30), "Outfit_Hat": (0.30, 0.75, 0.70), "Outfit_Shirt": (0.85, 0.55, 0.85), "Outfit_Shirt_Arms": (0.75, 0.45, 0.95),
           "Outfit_Tie": (0.95, 0.85, 0.30), "Outfit_Belt": (0.95, 0.45, 0.10), "Outfit_Buckle": (0.95, 0.95, 0.95), "Outfit_Trousers": (0.35, 0.50, 0.85),
           "Outfit_Shoes": (0.45, 0.30, 0.20), "Body_Head": (0.90, 0.70, 0.55), "Body_Hands": (0.95, 0.60, 0.45), "Body_Hair": (0.45, 0.80, 0.35)}
    for nocoat in (False, True):
        show = [o for o in out_objs if not (nocoat and o.name.startswith("Outfit_Coat"))]
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.hide_render = False
        cam, co = tc.setup_renders(show, {o.name: pal.get(o.name.split(".")[0], (0.5, 0.5, 0.5)) for o in show})
        w0, h0 = bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y
        bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y = 3 * w0, 3 * h0
        big = {}
        tag = "nocoat" if nocoat else "big4"
        for c_, az in enumerate((0, 90, 180, 270)):
            big[(0, c_)] = f"{RV_OUT}/{tag}_{c_}.png"; tc.shot(cam, co, big[(0, c_)], az, Vector((0, 0, 0.5 * H)), 1.15 * H)
        tc.sheet(1, 4, big, f"{RV_OUT}/{tag}.png"); print(f"[{TAG}] sheet {RV_OUT}/{tag}.png")
        bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y = w0, h0
tc.export(OUT, out_objs, arm2)
print(f"[{TAG}] wrote {OUT}")
