# tripo_coated_cut.py — the coat-cut variants of the shirt, trousers and belt, made ON THE BASE (ACTOR D106 step 3; the rules are tripo_dress.py's,
# 2026-10-27..31, ported unchanged: nothing here is a new design). Reads fit/HAT_SKIN_<FIG>.blend (never saved over): the base's FULL pieces and
# its fitted coat `Outfit_Coat.001` (the coat's `Fit` key at its value, evaluated). Adds, as copies that keep their skin and shape keys:
#   Outfit_Shirt_Coated    the shirt without the faces deep inside the coat (COAT_GAP) or out through it, never the front strip (FRONT_KEEP), never the
#                          collar ring, shards between the armpits and the shoulders cut (SHARD_*);
#   Outfit_Trousers_Coated the same at the hips only (the hips' height less 8 % of H);
#   Outfit_Belt_Coated     only the faces in front of the hips (the buckle's side).
# The full pieces stay: the coat's state picks which set shows (D106 swap rule). Prints each mask's count. Cut at full resolution; tripo_lod reduces them.
# Out: CC_OUT (default ASSETS/MODELS/fit/COATED_<FIG>.blend). Env: CC_FIG (female | male), CC_OUT, COAT_GAP, FRONT_KEEP, TROUSERS_KEEP, SHARD_X, SHARD_Z.
# Usage (repo root): CC_FIG=female blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_coated_cut.py
import os, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_coated_cut"
FIG = os.environ.get("CC_FIG", "")
if FIG not in ("female", "male"):
    sys.exit(f"[{TAG}] CC_FIG must be female or male")
OUT = os.path.abspath(os.environ.get("CC_OUT", f"ASSETS/MODELS/fit/COATED_{FIG.upper()}.blend"))
COAT_GAP = float(os.environ.get("COAT_GAP", "0.004"))
FRONT_KEEP = float(os.environ.get("FRONT_KEEP", "0.05"))
# the trousers keep a WIDER front strip than the shirt (2026-11-06: with the strip at 5 % of H the coat opening of a walk showed a dark slit down the thigh, where
# trouser faces just outside it had been cut): TROUSERS_KEEP, default 0.10
TROUSERS_KEEP = float(os.environ.get("TROUSERS_KEEP", "0.10"))
SHARD_X = float(os.environ.get("SHARD_X", "0.072"))
SHARD_Z0, SHARD_Z1 = (float(x) for x in os.environ.get("SHARD_Z", "0.60,0.80").split(","))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/fit/HAT_SKIN_{FIG.upper()}.blend"))
bpy.context.view_layer.update()
armB = bpy.data.objects["Armature"]; coat = bpy.data.objects["Outfit_Coat.001"]
for n in ("Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated"):
    if n in bpy.data.objects:
        sys.exit(f"[{TAG}] {FIG}: {n} already exists")
mB = {o.name: o for o in bpy.data.objects if o.type == 'MESH' and o.name not in ("Outfit_Coat.001", "Outfit_Hat", "Icosphere", "Body_Hair_Hat")}


def wverts(o):
    """world vertices as the base SHOWS them: the evaluated mesh (the coat's Fit key at its value; the armature is in REST)"""
    ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh()
    V = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices]); ev.to_mesh_clear(); return V


def shell(o):
    ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh(); me.calc_loop_triangles()
    V = [tuple((o.matrix_world @ v.co)[:]) for v in me.vertices]; T = [tuple(t.vertices) for t in me.loop_triangles]; ev.to_mesh_clear()
    return BVHTree.FromPolygons(V, T)


def inside(T, p):
    """ray parity on a closed shell (Tripo's part completion makes every part one)"""
    n = 0; o = Vector(p); d = Vector((0.31, 0.17, 0.93)).normalized()
    for _ in range(64):
        h = T.ray_cast(o, d)
        if h[0] is None:
            break
        n += 1; o = h[0] + d * 1e-6
    return n % 2 == 1


H = max(wverts(o)[:, 2].max() for o in mB.values())
bh = lambda n: np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + n].head_local)[:])
SEGS = [(bh(a), bh(b)) for a, b in (("Hips", "Spine"), ("Spine", "Spine1"), ("Spine1", "Spine2"), ("Spine2", "Neck"))]
SEGS += [(bh(sd + a), bh(sd + b)) for sd in ("Left", "Right") for a, b in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"))]


def to_bone(q):
    best_ = None
    for a, b in SEGS:
        ab = b - a; t = np.clip((q - a) @ ab / (ab @ ab), 0, 1); c = a + t * ab; d = np.linalg.norm(c - q)
        if best_ is None or d < best_[0]:
            best_ = (d, (c - q) / max(d, 1e-12))
    return best_


def away(q):
    return -to_bone(q)[1]


Tc = shell(coat)


def through_coat(q):                                     # the coat met BEFORE the bone: a hit past it is the coat's collar behind the neck
    d, n_ = to_bone(q)
    return Tc.ray_cast(Vector(q), Vector(n_), min(0.03 * H, d))[0] is not None


def covered(q):                                          # the coat really over it, seen from outside (a ray away from the spine meets it)
    dv = Vector(away(q)); return Tc.ray_cast(Vector(q) + dv * 1e-4, dv, 0.08 * H)[0] is not None


def behind(q):                                           # the coat right behind it toward the spine (shoulder blades)
    dv = -Vector(away(q)); return Tc.ray_cast(Vector(q) + dv * 1e-4, dv, 0.05 * H)[0] is not None


def masked_copy(o, name, dead_vert):
    c = o.copy(); c.data = o.data.copy(); c.name = name; c.data.name = name
    for col in o.users_collection:
        col.objects.link(c)
    bm = bmesh.new(); bm.from_mesh(c.data); bm.verts.ensure_lookup_table()
    dead = [f for f in bm.faces if dead_vert(f)]; bmesh.ops.delete(bm, geom=dead, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS'); bm.to_mesh(c.data); bm.free(); c.data.update()
    return c, len(dead)


# ---- the shirt
shirt = mB["Outfit_Shirt"]; SV = wverts(shirt)
deep = [inside(Tc, q) and Tc.find_nearest(Vector(q))[3] > COAT_GAP * H for q in SV]
out_ = [not inside(Tc, q) and through_coat(q) for q in SV]
deep = [d_ or covered(q) for d_, q in zip(deep, SV)]       # what the coat COVERS seen from outside: the shirt showed between the coat's large triangles
out_ = [o_ or (not covered(q) and behind(q)) for o_, q in zip(out_, SV)]
# the COLLAR is never masked: from 4 % of H under the neck bone up, inside a ring round the neck
keep = (SV[:, 2] > bh("Neck")[2] - 0.04 * H) & (np.linalg.norm(SV[:, :2] - bh("Neck")[:2], axis=1) < 0.06 * H)
deep = [d_ and not k_ for d_, k_ in zip(deep, keep)]; out_ = [o_ and not k_ for o_, k_ in zip(out_, keep)]
hips_ = bh("Hips")
front = lambda Q, keep=FRONT_KEEP: (np.abs(Q[:, 0] - hips_[0]) < keep * H) & (Q[:, 1] < hips_[1] + 0.03 * H)       # the figure faces -Y
pro_s = front(SV)
deep = [d_ and not p_ for d_, p_ in zip(deep, pro_s)]; out_ = [o_ and not p_ for o_, p_ in zip(out_, pro_s)]
if SHARD_Z1 > SHARD_Z0:                                  # a shirt vertex outside the coat, off the front strip and the collar ring, between armpits and shoulders
    shard_ = [(not inside(Tc, q)) and SHARD_Z0 * H < q[2] < SHARD_Z1 * H and abs(q[0] - hips_[0]) >= SHARD_X * H for q in SV]
    out_ = [o_ or (s_ and not k_ and not p_) for o_, s_, k_, p_ in zip(out_, shard_, keep, pro_s)]
sc_, nd = masked_copy(shirt, "Outfit_Shirt_Coated", lambda f: all(deep[v.index] for v in f.verts) or any(out_[v.index] for v in f.verts))
print(f"[{TAG}] {FIG}: shirt mask: {nd} of {len(shirt.data.polygons)} faces deep inside the coat or out through it ({sum(out_)} vertices out)")

# ---- the trousers, at the hips only
if "Outfit_Trousers" in mB:
    trs = mB["Outfit_Trousers"]; TV = wverts(trs); hipz = bh("Hips")[2] - 0.08 * H
    tdeep = [q[2] > hipz and inside(Tc, q) and Tc.find_nearest(Vector(q))[3] > COAT_GAP * H and covered(q) for q in TV]
    tout = [q[2] > hipz and not inside(Tc, q) and through_coat(q) for q in TV]
    pro_t = front(TV, TROUSERS_KEEP)
    tdeep = [d_ and not p_ for d_, p_ in zip(tdeep, pro_t)]; tout = [o_ and not p_ for o_, p_ in zip(tout, pro_t)]
    tc_, nd = masked_copy(trs, "Outfit_Trousers_Coated", lambda f: all(tdeep[v.index] for v in f.verts) or any(tout[v.index] for v in f.verts))
    print(f"[{TAG}] {FIG}: trousers mask: {nd} of {len(trs.data.polygons)} faces at the hips deep inside the coat or out through it ({sum(tout)} vertices out)")

# ---- the belt behind the hips
if "Outfit_Belt" in mB:
    belt = mB["Outfit_Belt"]; BV = wverts(belt); hy = bh("Hips")[1]
    bc_, nd = masked_copy(belt, "Outfit_Belt_Coated", lambda f: all(BV[v.index][1] > hy for v in f.verts))
    print(f"[{TAG}] {FIG}: belt mask: {nd} of {len(belt.data.polygons)} faces behind the hips")

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"[{TAG}] {FIG}: -> {OUT}")
