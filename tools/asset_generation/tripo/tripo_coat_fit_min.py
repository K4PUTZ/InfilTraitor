# tripo_coat_fit_min.py — the coat's MINIMAL FIT, the starting point of the Director's hand fit (ACTOR D96, 2026-11-02: "o casaco mais bem ajustado. Eu vou ajudar a fazer isso manualmente").
# `tripo_dress.py` fits COAT_BASE with ~1500 lines of pushes and smoothings that deform it; this takes only what the coat needs to exist on the figure: COAT_BASE scaled uniformly to the generation's coat (hem to collar top), set on its hem height and
# centre, its weights from the nearest point of the generation's coat (barycentric), bound to the base figure's armature. NO push-out, no sleeve turn, no straight skirt, no relax. The coat carries two shape keys, Basis and
# "Fit" (value 1): the Director sculpts the Fit key in Blender (Edit Mode on the coat, the figure in REST pose); the build reads the key back (a later step) and applies it to the finished coat as data, so it survives a rebuild.
# Env: FIT_BASE (a tripo_assemble output: the base figure's slots, the build's `<c>_slots.glb`), FIT_FROM (the generation with the coat, `<c>_from.glb`), FIT_COAT (COAT_BASE.glb), FIT_BLEND (the .blend written), FIT_GLB (optional, a GLB of it).
# Usage: blender -b -P tripo_coat_fit_min.py
import math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Matrix, Quaternion, Vector
from mathutils.geometry import barycentric_transform
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc

TAG = "tripo_coat_fit_min"
BASE, FROM, COAT, BLEND = os.environ["FIT_BASE"], os.environ["FIT_FROM"], os.environ["FIT_COAT"], os.environ["FIT_BLEND"]
bpy.ops.wm.read_factory_settings(use_empty=True)


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arms = [o for o in new if o.type == 'ARMATURE']
    if len(arms) != 1:
        tc.fail(TAG, f"{path}: expected one armature, found {len(arms)}")
    a = arms[0]
    if a.animation_data:
        a.animation_data.action = None
    a.data.pose_position = 'REST'
    return a, {o.name.split(".")[0]: o for o in new if o.type == 'MESH' and o.vertex_groups}, new


def wverts(o):
    return np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])


def set_world(o, V):
    inv = o.matrix_world.inverted()
    for v, q in zip(o.data.vertices, V):
        v.co = inv @ Vector(q)
    o.data.update()


armB, mB, _ = imp(BASE)
armA, mA, newA = imp(FROM)
if "Outfit_Coat" not in mA:
    tc.fail(TAG, f"{FROM} has no Outfit_Coat")
bpy.context.view_layer.update()
# the generation's coat carried onto the base's rest skeleton (a linear blend of base_rest @ dresser_rest^-1 per bone, as tripo_dress does)
DM = {b.name: (armB.matrix_world @ armB.data.bones[b.name].matrix_local) @ (armA.matrix_world @ b.matrix_local).inverted() for b in armA.data.bones if b.name in armB.data.bones}
gen = mA["Outfit_Coat"]; gn = {g.index: g.name for g in gen.vertex_groups}; CV = wverts(gen)
for i, v in enumerate(gen.data.vertices):
    acc, ws = Vector((0, 0, 0)), 0.0
    for g in v.groups:
        M = DM.get(gn[g.group])
        if M is not None and g.weight > 0:
            acc += (M @ Vector(CV[i])) * g.weight; ws += g.weight
    if ws > 0:
        CV[i] = (acc / ws)[:]
set_world(gen, CV)
gen.data.calc_loop_triangles()
Tg = BVHTree.FromPolygons([tuple(p) for p in CV], [tuple(t.vertices) for t in gen.data.loop_triangles])
GW = tc.read_weights(gen); GT = [tuple(t.vertices) for t in gen.data.loop_triangles]
# COAT_BASE: welded (a GLB splits its vertices at every UV seam), scaled uniformly to the generation's coat length, set on its hem height and centre
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=COAT)
loose = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
if not loose:
    tc.fail(TAG, f"{COAT}: no mesh")
for o in loose:
    bm_ = bmesh.new(); bm_.from_mesh(o.data); bmesh.ops.remove_doubles(bm_, verts=bm_.verts[:], dist=1e-6); bm_.to_mesh(o.data); bm_.free()
LV = np.concatenate([wverts(o) for o in loose]); LF = []; LUV = []; off = 0
for o in loose:
    LF += [[off + v for v in p_.vertices] for p_ in o.data.polygons]; off += len(o.data.vertices)
    uvd = o.data.uv_layers.active.data if o.data.uv_layers.active else None
    LUV += [tuple(uvd[li].uv) if uvd else (0.0, 0.0) for p_ in o.data.polygons for li in p_.loop_indices]
glo, ghi = CV.min(0), CV.max(0); llo, lhi = LV.min(0), LV.max(0); k = (ghi[2] - glo[2]) / (lhi[2] - llo[2])
gc, lc = (glo + ghi) / 2, (llo + lhi) / 2
LV = (LV - [lc[0], lc[1], llo[2]]) * k + [gc[0], gc[1], glo[2]]
for o in loose:
    bpy.data.objects.remove(o)
u3 = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
NW = []
for q in LV:
    loc, _n, fi, _d = Tg.find_nearest(Vector(q)); tri = GT[fi]
    bc = np.clip(np.array(barycentric_transform(loc, Vector(CV[tri[0]]), Vector(CV[tri[1]]), Vector(CV[tri[2]]), *u3)[:]), 0.0, None); bc /= bc.sum() or 1.0
    mix = {}
    for vi, wk in zip(tri, bc):
        for g, x in GW[vi].items():
            mix[g] = mix.get(g, 0.0) + x * wk
    NW.append(tc.top4(mix, "mixamorig:Hips"))
# each SLEEVE turned about its shoulder onto the base's arm (the standalone's sleeves splay wider than the figure's arms: the cuffs stood far from the wrists)
for side in ("Left", "Right"):
    aw = np.array([sum(x for g, x in w.items() if side in g and any(k_ in g for k_ in ("Arm", "Hand", "Shoulder"))) for w in NW])
    sl = LV[aw >= 0.9]
    if len(sl) < 20:
        continue
    sh = np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + side + "Arm"].head_local)[:])
    wr = np.array((armB.matrix_world @ armB.data.bones["mixamorig:" + side + "Hand"].head_local)[:])
    c_ = sl.mean(0); ev = np.linalg.eigh(np.cov((sl - c_).T))[1][:, -1]
    if ev @ (c_ - sh) < 0:
        ev = -ev
    tgt = (wr - sh) / np.linalg.norm(wr - sh); q = Vector(ev).rotation_difference(Vector(tgt))
    for i in np.nonzero(aw > 0)[0]:
        LV[i] = sh + np.array((Quaternion().slerp(q, float(aw[i])) @ Vector(LV[i] - sh))[:])
    print(f"[{TAG}] {side} sleeve turned {math.degrees(q.angle):.1f} deg onto the arm ({len(sl)} sleeve vertices)")
me = bpy.data.meshes.new("Outfit_Coat"); me.from_pydata([tuple(q) for q in LV], [], LF); me.update()
if any(u != (0.0, 0.0) for u in LUV):
    ul = me.uv_layers.new(name="UVMap")
    for li, u in enumerate(LUV):
        ul.data[li].uv = u
coat = bpy.data.objects.new("Outfit_Coat", me); bpy.context.scene.collection.objects.link(coat)
for p_ in me.polygons:
    p_.use_smooth = True
coat.parent = armB; coat.matrix_world = Matrix.Identity(4); set_world(coat, LV)
md = coat.modifiers.new("Armature", 'ARMATURE'); md.object = armB; tc.write_weights(coat, NW)
coat.shape_key_add(name="Basis", from_mix=False)
fit = coat.shape_key_add(name="Fit", from_mix=False); fit.value = 1.0   # the Director sculpts THIS key
# the generation's figure goes (its coat, hat and skeleton); the base figure, its slots and the new coat stay
for o in newA:
    if o.name in bpy.data.objects:
        bpy.data.objects.remove(o, do_unlink=True)
armB.data.pose_position = 'REST'
os.makedirs(os.path.dirname(os.path.abspath(BLEND)), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
print(f"[{TAG}] coat {len(LV)} vertices, {len(LF)} faces, scaled x{k:.3f} (length {ghi[2] - glo[2]:.3f} m, hem z {glo[2]:.3f}); weights from the generation's coat; wrote {BLEND}")
