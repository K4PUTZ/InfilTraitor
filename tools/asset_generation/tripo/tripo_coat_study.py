# tripo_coat_study.py — where and why the coat misbehaves, measured on the base files (Director, 2026-11-05: "julgando pelos vertices que eu movi, talvez seja possível identificar aonde estão os problemas mais complexos"; "o interior ali do casaco, e toda a região do torax tem bastante 'liquidez'"). Read-only: it never saves the .blend.
# Per coat vertex, by band of the body and per clip: the hand edits (the corrective keys against Fit), STRETCH (edge length against the rest), BEND (dihedral angle against the rest; the "liquid" look), SLIP (the coat's skin against the skin of what lies under it, at the coat's own position), the weight ROUGHNESS (L1 step between neighbours per cm), the rest CLEARANCE to what lies under it.
# Per vertex of the shirt, belt and trousers covered by the coat at rest: EXPOSED on a frame when the ray along its normal meets no coat at all (a test the coat's inner folds cannot fool, unlike a signed distance), and how far it pokes past the coat. Skins are computed here with the same linear blend as tripo_pose_fix_back.py and checked against Blender's own on one frame.
# Output: the tables on stdout, CS_OUT/study_<fig>.json, and one flat render per metric and view (heat_<metric>_v<k>.png) on the rest pose.
# Env: CS_A (the A .blend), CS_FIG (female | male), CS_OUT (folder), CS_CLIPS (idle,walk,run), CS_SAMPLES (29).
# Usage (from the repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_coat_study.py
import json
import math
import os
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

TAG = "tripo_coat_study"
FIG = os.environ["CS_FIG"]
OUT = os.path.abspath(os.environ["CS_OUT"])
CLIPS = os.environ.get("CS_CLIPS", "idle,walk,run").split(",")
SAMPLES = int(os.environ.get("CS_SAMPLES", "29"))
PFX = "mixamorig:"
UNDER = ("Outfit_Shirt", "Outfit_Belt", "Outfit_Trousers")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["CS_A"]))
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
coat = next(o for o in bpy.data.objects if o.type == 'MESH' and "Coat" in o.name)
bones = [b.name for b in arm.pose.bones]
col = {b: k for k, b in enumerate(bones)}
aw = np.array(arm.matrix_world)
awi = np.linalg.inv(aw)
head = lambda n: np.array((arm.matrix_world @ arm.data.bones[PFX + n].head_local)[:])
hip_h = head("Hips")[2]
cx, cy = head("Hips")[:2]
Z_NECK, Z_S2, Z_S1, Z_HIP = head("Neck")[2], head("Spine2")[2], head("Spine1")[2], head("Hips")[2]


def evaluated(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    m = e.to_mesh()
    mw = o.matrix_world
    r = np.array([(mw @ v.co)[:] for v in m.vertices])
    e.to_mesh_clear()
    return r


def weights(o):
    names = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(o.data.vertices), len(bones)))
    for v in o.data.vertices:
        for g in v.groups:
            k = col.get(names[g.group])
            if k is not None:
                w[v.index, k] = g.weight
    return w / np.maximum(w.sum(1, keepdims=True), 1e-12)


class Piece:
    def __init__(self, o):
        self.o = o
        self.rest = evaluated(o)
        self.W = weights(o)
        self.loose = self.W.sum(1) <= 1e-9
        o.data.calc_loop_triangles()
        self.tris = np.array([t.vertices[:] for t in o.data.loop_triangles], dtype=np.int64)

    def matrices(self, S):
        M = np.einsum('nb,bij->nij', self.W, S)
        M[self.loose] = np.eye(4)
        return M

    def skin(self, S):
        return np.einsum('nij,nj->ni', self.matrices(S), np.c_[self.rest, np.ones(len(self.rest))])[:, :3]


def normals(p, tris):
    fn = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def band(p, sleeve=False):
    x, y, z = p
    if sleeve:
        return "sleeve"
    if z > Z_NECK - 0.01:
        return "collar"
    ang = abs(math.degrees(math.atan2(x - cx, -(y - cy))))
    side = "front" if ang < 50 else ("back" if ang > 130 else "side")
    if z > Z_S1:
        return "chest_" + side
    if z > Z_HIP:
        return "waist_" + side
    return ("skirt_hi_" if z > HEM_MID else "skirt_lo_") + side


def bvh_of(p, tris):
    return BVHTree.FromPolygons([tuple(q) for q in p], [tuple(t) for t in tris.tolist()], all_triangles=True)


def outer_gap(bvh, q, n, reach=0.25):
    """the distance along n to the LAST coat wall, None if there is none"""
    o, last, travelled = Vector(q) + Vector(n) * 1e-4, None, 0.0
    for _ in range(8):
        hit = bvh.ray_cast(o, Vector(n), reach - travelled)
        if hit[0] is None:
            break
        travelled += hit[3]
        last = travelled
        o = hit[0] + Vector(n) * 1e-4
    return last


def play(clip):
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.context.view_layer.objects.active = None       # the male's file was saved with the buckle in Edit Mode: with it active, the importer's 42-vertex bone sphere lands inside that mesh (measured, 88 -> 130 vertices)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/ANIMATIONS/bank/{FIG}/{clip}.glb"))
    act = [a for a in bpy.data.actions if a not in before_a][0]
    for o in [o for o in bpy.data.objects if o not in before_o]:
        bpy.data.objects.remove(o)
    curves = [fc for la in act.layers for s in la.strips for cb in s.channelbags for fc in cb.fcurves] if getattr(act, "layers", None) else list(act.fcurves)
    for fc in curves:
        if fc.data_path.endswith(".location") and "Hips" in fc.data_path:
            for k in fc.keyframe_points:
                k.co.y *= hip_h; k.handle_left.y *= hip_h; k.handle_right.y *= hip_h
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if len(getattr(act, "slots", [])):
        ad.action_slot = act.slots[0]
    arm.data.pose_position = 'POSE'
    return act


def pose_matrices():
    return np.stack([aw @ np.array(arm.pose.bones[b].matrix @ arm.data.bones[b].matrix_local.inverted()) @ awi for b in bones])


C = Piece(coat)
Us = {n: Piece(bpy.data.objects[n]) for n in UNDER}
HEM = float(C.rest[:, 2].min())
HEM_MID = 0.5 * (HEM + Z_HIP)
arm_w = sum(C.W[:, col[b]] for b in bones if any(t in b for t in ("Shoulder", "Arm", "Hand")))
sleeve = arm_w > 0.5
bands = np.array([band(p, s) for p, s in zip(C.rest, sleeve)])
edges = sorted({tuple(sorted(e.vertices)) for e in coat.data.edges})
E = np.array(edges)
nbr = [[] for _ in C.rest]
for a, b in edges:
    nbr[a].append(b); nbr[b].append(a)
L0 = np.linalg.norm(C.rest[E[:, 0]] - C.rest[E[:, 1]], axis=1)
inc_e = [[] for _ in C.rest]
for k, (a, b) in enumerate(edges):
    inc_e[a].append(k); inc_e[b].append(k)


def per_vertex(edge_values):
    return np.array([edge_values[i].mean() if i else 0.0 for i in inc_e])


# pairs of triangles for the bend
te = {}
for t, (a, b, c) in enumerate(C.tris.tolist()):
    for u, v in ((a, b), (b, c), (c, a)):
        te.setdefault((min(u, v), max(u, v)), []).append(t)
hinges = [(k, v) for k, v in te.items() if len(v) == 2]
H_E = np.array([k for k, _ in hinges])
H_T = np.array([v for _, v in hinges])
inc_h = [[] for _ in C.rest]
for k, (a, b) in enumerate(H_E.tolist()):
    inc_h[a].append(k); inc_h[b].append(k)


def tri_normals(p):
    n = np.cross(p[C.tris[:, 1]] - p[C.tris[:, 0]], p[C.tris[:, 2]] - p[C.tris[:, 0]])
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def dihedral(p):
    n = tri_normals(p)
    return np.degrees(np.arccos(np.clip((n[H_T[:, 0]] * n[H_T[:, 1]]).sum(1), -1, 1)))


D0 = dihedral(C.rest)
# the wall: a vertex with coat right outside it is the lining's (approximate: a horizontal radial ray)
bvh0 = bvh_of(C.rest, C.tris)
inner = np.zeros(len(C.rest), bool)
for i, p in enumerate(C.rest):
    if sleeve[i]:
        continue
    d = Vector((p[0] - cx, p[1] - cy, 0.0))
    if d.length < 1e-6:
        continue
    d.normalize()
    if bvh0.ray_cast(Vector(p) + d * 0.002, d, 0.05)[0] is not None:
        inner[i] = True
# what lies under each coat vertex
under_p = np.vstack([Us[n].rest for n in UNDER])
under_W = np.vstack([Us[n].W for n in UNDER])
kd = KDTree(len(under_p))
for i, p in enumerate(under_p):
    kd.insert(p, i)
kd.balance()
near = np.array([kd.find(p)[1] for p in C.rest])
clear = np.linalg.norm(C.rest - under_p[near], axis=1)
# weights
rough = np.zeros(len(C.rest))
for i, ns in enumerate(nbr):
    if ns:
        rough[i] = np.mean([np.abs(C.W[i] - C.W[j]).sum() / max(np.linalg.norm(C.rest[i] - C.rest[j]) * 100, 1e-3) for j in ns])
influences = (C.W > 1e-3).sum(1)
edge_cm = per_vertex(L0) * 100
# the hand edits
key_d = {}
ks = coat.data.shape_keys.key_blocks if coat.data.shape_keys else {}
if "Fit" in ks or "Basis" in ks:
    base = ks["Fit"] if "Fit" in ks else ks["Basis"]
    b0 = np.array([d.co[:] for d in base.data])
    for name in ("RunFix", "IdleFix", "WalkFix"):
        if name in ks:
            if ks[name].value != 0.0:
                raise SystemExit(f"[{TAG}] {name} is not at 0: the study measures the coat without them")
            key_d[name] = (np.array([d.co[:] for d in ks[name].data]) - b0) @ np.array(coat.matrix_world)[:3, :3].T
# an edit against the outward radial direction
radial = C.rest[:, :2] - np.array((cx, cy))
radial = np.c_[radial, np.zeros(len(radial))]
radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
BANDS = ["collar", "chest_front", "chest_side", "chest_back", "waist_front", "waist_side", "waist_back", "skirt_hi_front", "skirt_hi_side", "skirt_hi_back", "skirt_lo_front", "skirt_lo_side", "skirt_lo_back", "sleeve"]
R = {"figure": FIG, "bands": {}, "clips": {}, "exposure": {}, "edits": {}, "bones": {}}
print(f"[{TAG}] {FIG}: coat {len(C.rest)} vertices, {len(C.tris)} triangles; hem z {HEM:.3f}, hips {Z_HIP:.3f}, spine1 {Z_S1:.3f}, spine2 {Z_S2:.3f}, neck {Z_NECK:.3f}")
print(f"[{TAG}] band                n   inner  clear_mm(med)  edge_cm  influences  rough/cm  top bones")
for b in BANDS:
    m = bands == b
    if not m.any():
        continue
    top = np.argsort(C.W[m].mean(0))[::-1][:4]
    tops = [(bones[k].replace(PFX, ""), round(float(C.W[m].mean(0)[k]), 2)) for k in top]
    R["bands"][b] = {"n": int(m.sum()), "inner": int(inner[m].sum()), "clear_mm": float(np.median(clear[m]) * 1000), "edge_cm": float(np.median(edge_cm[m])), "influences": float(influences[m].mean()), "rough": float(np.median(rough[m])), "top": tops}
    print(f"[{TAG}] {b:16s} {m.sum():5d} {inner[m].sum():5d} {np.median(clear[m]) * 1000:10.1f} {np.median(edge_cm[m]):10.2f} {influences[m].mean():9.2f} {np.median(rough[m]):10.3f}  {tops}")
for name, d in key_d.items():
    mag = np.linalg.norm(d, axis=1)
    moved = mag > 1e-3
    out = (d * radial).sum(1)
    print(f"[{TAG}] edit {name}: {int(moved.sum())} vertices over 1 mm; by band: n, median cm, max cm, % of them moved OUTWARD, inner wall")
    R["edits"][name] = {}
    for b in BANDS:
        m = (bands == b) & moved
        if m.any():
            row = {"n": int(m.sum()), "share": float(m.sum() / (bands == b).sum()), "median_cm": float(np.median(mag[m]) * 100), "max_cm": float(mag[m].max() * 100), "outward": float((out[m] > 0).mean()), "inner": int(inner[m].sum())}
            R["edits"][name][b] = row
            print(f"[{TAG}]   {b:16s} {row['n']:5d} ({row['share'] * 100:3.0f} %) {row['median_cm']:6.2f} {row['max_cm']:6.2f} {row['outward'] * 100:5.0f} % out, {row['inner']} inner")
metrics = {}
exposed_sum = {n: np.zeros(len(Us[n].rest)) for n in UNDER}
for clip in CLIPS:
    act = play(clip)
    a0, a1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = sorted({int(round(x)) for x in np.linspace(a0, a1, SAMPLES)})
    stretch, bend, slip = np.zeros(len(E)), np.zeros(len(H_E)), np.zeros(len(C.rest))
    covered = {}
    rest_gap = {}
    min_gap = {}
    poke = {}
    # who is covered at rest: judged with the rest pose of both pieces
    for n in UNDER:
        P = Us[n]
        nn = normals(P.rest, P.tris)
        g = [outer_gap(bvh0, q, d, 0.12) for q, d in zip(P.rest, nn)]
        covered[n] = np.array([x is not None for x in g])
        rest_gap[n] = np.array([x if x is not None else np.nan for x in g])
        min_gap[n] = rest_gap[n].copy()
        poke[n] = np.zeros(len(P.rest))
    per_frame = []
    checked = False
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        S = pose_matrices()
        Mc = C.matrices(S)
        p = np.einsum('nij,nj->ni', Mc, np.c_[C.rest, np.ones(len(C.rest))])[:, :3]
        if not checked:
            err = np.linalg.norm(p - evaluated(coat), axis=1).max() * 100
            print(f"[{TAG}] {clip}: frames {a0}-{a1}, {len(frames)} samples; own skin against Blender's on frame {f}: max {err:.4f} cm")
            if err > 0.01:
                raise SystemExit(f"[{TAG}] the skin here is not Blender's")
            checked = True
        L = np.linalg.norm(p[E[:, 0]] - p[E[:, 1]], axis=1)
        stretch = np.maximum(stretch, np.abs(L / np.maximum(L0, 1e-9) - 1))
        bend = np.maximum(bend, np.abs(dihedral(p) - D0))
        Mu = np.einsum('nb,bij->nij', under_W[near], S)
        slip = np.maximum(slip, np.linalg.norm(np.einsum('nij,nj->ni', Mc - Mu, np.c_[C.rest, np.ones(len(C.rest))])[:, :3], axis=1))
        bvh = bvh_of(p, C.tris)
        row = {"frame": f}
        for n in UNDER:
            P = Us[n]
            q = P.skin(S)
            nn = normals(q, P.tris)
            count = 0
            for i in np.nonzero(covered[n])[0]:
                g = outer_gap(bvh, q[i], nn[i])
                if g is None:
                    count += 1
                    exposed_sum[n][i] += 1.0 / (len(frames) * len(CLIPS))
                    d = bvh.find_nearest(Vector(q[i]))[3]
                    if d is not None:
                        poke[n][i] = max(poke[n][i], d)
                else:
                    min_gap[n][i] = min(min_gap[n][i], g)
            row[n] = count
        per_frame.append(row)
    sv, bv, = per_vertex(stretch), np.array([bend[i].mean() if i else 0.0 for i in inc_h])
    metrics[clip] = {"stretch": sv * 100, "bend": bv, "slip": slip * 1000}
    R["clips"][clip] = {}
    print(f"[{TAG}] {clip}: band: stretch % med/p95, bend deg med/p95, slip mm med/p95 (both walls)")
    for b in BANDS:
        m = bands == b
        if m.any():
            t = {k: (float(np.median(v[m])), float(np.percentile(v[m], 95))) for k, v in metrics[clip].items()}
            R["clips"][clip][b] = t
            print(f"[{TAG}]   {b:16s} {t['stretch'][0]:6.1f} {t['stretch'][1]:6.1f} | {t['bend'][0]:6.1f} {t['bend'][1]:6.1f} | {t['slip'][0]:6.1f} {t['slip'][1]:6.1f}")
    R["exposure"][clip] = {}
    for n in UNDER:
        P = Us[n]
        ub = np.array([band(q, False) for q in P.rest])
        worst = max(per_frame, key=lambda r: r[n])
        print(f"[{TAG}] {clip} {n}: covered at rest {int(covered[n].sum())}/{len(P.rest)}; exposed on the worst frame ({worst['frame']}): {worst[n]}; per band: covered, ever exposed, poke mm p50/p95/max, rest gap mm median, min gap mm p5")
        R["exposure"][clip][n] = {"covered": int(covered[n].sum()), "worst": worst[n], "worst_frame": worst["frame"], "per_frame": [r[n] for r in per_frame], "bands": {}}
        for b in BANDS:
            m = (ub == b) & covered[n]
            if not m.any():
                continue
            ever = poke[n][m] > 0
            pk = poke[n][m][ever] * 1000 if ever.any() else np.zeros(1)
            row = {"covered": int(m.sum()), "ever": int(ever.sum()), "poke": [float(np.median(pk)), float(np.percentile(pk, 95)), float(pk.max())], "rest_gap": float(np.nanmedian(rest_gap[n][m]) * 1000), "min_gap_p5": float(np.nanpercentile(min_gap[n][m], 5) * 1000)}
            R["exposure"][clip][n]["bands"][b] = row
            if row["ever"]:
                print(f"[{TAG}]   {b:16s} {row['covered']:5d} {row['ever']:5d} | {row['poke'][0]:6.1f} {row['poke'][1]:6.1f} {row['poke'][2]:6.1f} | {row['rest_gap']:6.1f} {row['min_gap_p5']:6.1f}")
    arm.animation_data.action = None
    bpy.data.actions.remove(act)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
arm.data.pose_position = 'REST'
bpy.context.view_layer.update()


def auc(values, flag):
    order = values.argsort().argsort() + 1.0
    n1, n0 = flag.sum(), (~flag).sum()
    return float((order[flag].sum() - n1 * (n1 + 1) / 2) / max(n1 * n0, 1))


# do the hand edits sit where a metric is high? 0.5 = no relation, 1 = perfectly so
body = ~sleeve
R["auc"] = {}
for name, clip in (("WalkFix", "walk"), ("RunFix", "run"), ("IdleFix", "idle")):
    if name in key_d and clip in metrics:
        moved = np.linalg.norm(key_d[name], axis=1) > 1e-3
        row = {k: auc(v[body], moved[body]) for k, v in metrics[clip].items()}
        row["rough"] = auc(rough[body], moved[body])
        row["tightness"] = auc(-clear[body], moved[body])
        row["edge_length"] = auc(edge_cm[body], moved[body])
        R["auc"][name] = row
        print(f"[{TAG}] AUC, {name} moved against {clip}: " + ", ".join(f"{k} {v:.2f}" for k, v in row.items()))
json.dump(R, open(f"{OUT}/study_{FIG}.json", "w"), indent=1)
# the pictures
STOPS = np.array([(0.04, 0.03, 0.18), (0.25, 0.05, 0.45), (0.65, 0.12, 0.35), (0.95, 0.40, 0.08), (1.0, 0.95, 0.35)])


def ramp(t):
    t = np.clip(t, 0, 1) * (len(STOPS) - 1)
    k = np.minimum(t.astype(int), len(STOPS) - 2)
    return STOPS[k] + (STOPS[k + 1] - STOPS[k]) * (t - k)[:, None]


c = bpy.data.objects.new("study_cam", bpy.data.cameras.new("study_cam"))
sc.collection.objects.link(c)
sc.camera = c
c.data.type = 'ORTHO'
c.data.ortho_scale = 1.0
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'VERTEX'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 420
sc.render.image_settings.file_format = 'PNG'


def paint(o, v, vmax):
    attr = o.data.color_attributes.get("study") or o.data.color_attributes.new("study", 'FLOAT_COLOR', 'POINT')
    rgb = ramp(np.asarray(v) / vmax)
    attr.data.foreach_set("color", np.c_[rgb, np.ones(len(rgb))].ravel())
    o.data.color_attributes.active_color = attr
    o.data.update()


def shoot(tag, shown):
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o not in shown
    for k, yaw in enumerate((0, 90, 180, 270)):
        d = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw)), 0.1)).normalized()
        c.location = Vector((cx, cy, 0.58)) + d * 5
        c.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.view_layer.update()
        sc.render.filepath = f"{OUT}/heat_{FIG}_{tag}_v{k}.png"
        bpy.ops.render.render(write_still=True)


union = np.max([np.linalg.norm(d, axis=1) for d in key_d.values()], axis=0) * 100 if key_d else np.zeros(len(C.rest))
pics = [("edits", union, 3.5), ("clear", np.maximum(0.0, 40.0 - clear * 1000), 40.0), ("rough", rough, 0.6)]
for clip in metrics:
    pics += [(f"bend_{clip}", metrics[clip]["bend"], 40.0), (f"stretch_{clip}", metrics[clip]["stretch"], 30.0), (f"slip_{clip}", metrics[clip]["slip"], 40.0)]
for tag, v, vmax in pics:
    paint(coat, v, vmax)
    shoot(tag, [coat])
for n in UNDER:
    paint(Us[n].o, exposed_sum[n], 0.25)
shoot("exposed", [Us[n].o for n in UNDER])
print(f"[{TAG}] wrote {OUT}/study_{FIG}.json and {len(pics) + 1} x 4 pictures")
