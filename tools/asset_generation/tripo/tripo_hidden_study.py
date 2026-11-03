# tripo_hidden_study.py — which faces of an Agent are NEVER seen (ACTOR D97 study, 2026-11-03, Director: "o que tem por baixo dos modelos base e nunca vão ser vistos ... se podemos deletar e simplificar toda a superfície").
# Director's scope (same day): the pieces that will be REPLACED by new models are hair, hat, coat, belt (+ buckle), shoes, tie; the ones that STAY are trousers, socks and shirt (a new texture only). So the candidates for deletion are the kept pieces
# (Shirt, Trousers; the hands are reported but were not named), and what the REPLACEABLE pieces hide today proves nothing about the new models. Three levels, each a set of hidden faces over every pose x view below:
#   SAFE   = hidden when the only things in the scene are the kept pieces (shirt, trousers, hands, head): occlusion by the figure's own surface, whatever is worn over it. Deleting these is safe whatever the new coat / belt / shoes are.
#   COND   = hidden only with today's replaceable pieces on (coat off: belt, shoes, tie; and coat on): valid only while the new models cover at least what the old ones do; re-run this tool when they exist.
# Reads `AGENT_<FIG>.glb` (the dressed full-resolution figure). A face is VISIBLE if, in at least one pose x view, a ray from a point of it toward the (orthographic) camera meets nothing. Poses: the A rest, the T (arms raised), and HS_CLIP_FRAMES frames of each clip the file
# carries (dive, heart_pose). Views: the board's four facings (yaw 0/90/180/270) x pitches 20/30/45 (the fixed 30 degree camera and a margin). Every game material is doubleSided, so a back face is seen like a front one: only OCCLUSION hides a face.
# Samples per triangle: centroid + 3 points (more on a large one); a face is hidden only if ALL samples are hidden (conservative). The `_Coated` variants are not candidates: they are the coat-dependent trim and get regenerated from the new coat.
# Out (HS_OUT, a directory): report.json, hidden_<level>_<mesh>.json (polygon indices), preview_*.png (red = SAFE, orange = COND, seen through the figure) when HS_PREVIEW=1.   Env: GLB, HS_OUT, HS_PITCHES ("20,30,45"), HS_CLIP_FRAMES (6), HS_PREVIEW (1).
# Usage: blender -b -P tripo_hidden_study.py
import json, math, os, random
import numpy as np
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_hidden_study"
OUT = os.environ["HS_OUT"]; os.makedirs(OUT, exist_ok=True)
PITCHES = [float(x) for x in os.environ.get("HS_PITCHES", "20,30,45").split(",")]
YAWS = [0.0, 90.0, 180.0, 270.0]
EPS = 1e-4
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.environ["GLB"]))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
CLIPS = {a.name: tuple(a.frame_range) for a in bpy.data.actions}      # the clips the file carries (dive, heart_pose...): real poses of the game, sampled below
CLIP_FRAMES = int(os.environ.get("HS_CLIP_FRAMES", "6"))
arm.animation_data_clear()                                        # an action left on the rig would override every pose set below (the first run drew the figure in `dive`)
meshes = {o.name: o for o in bpy.data.objects if o.type == 'MESH' and o.name != "Icosphere"}
CANDIDATES = {"Outfit_Shirt", "Outfit_Trousers", "Body_Hands"}
CFG_MESHES = {
    "kept_only": ["Body_Head", "Body_Hands", "Outfit_Shirt", "Outfit_Trousers"],
    "coat_off": ["Body_Hair", "Body_Hands", "Body_Head", "Outfit_Belt", "Outfit_Buckle", "Outfit_Shirt", "Outfit_Shoes", "Outfit_Tie", "Outfit_Trousers"],
    "coat_on": ["Body_Hair", "Body_Hands", "Body_Head", "Outfit_Belt_Coated", "Outfit_Buckle", "Outfit_Shirt_Coated", "Outfit_Shoes", "Outfit_Tie", "Outfit_Trousers_Coated", "Outfit_Coat"],
}
for o in meshes.values():
    o.hide_render = False
fig = "FEMALE" if "FEMALE" in os.path.basename(os.environ["GLB"]).upper() else "MALE"
SHARE = 0.5 if fig == "FEMALE" else 0.25
arm.data.pose_position = 'POSE'
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
rest = {b.name: Matrix(b.matrix_local) for b in arm.data.bones}


def pose(t):
    """The arms raised toward the T by t (0 = the A rest): the same turn `tripo_fit_tpose.py` makes, a share on the collarbone, the rest on the arm."""
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    if t <= 0:
        return
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        a = arm.data.bones[f"mixamorig:{side}Arm"]; f = arm.data.bones[f"mixamorig:{side}ForeArm"]; sb = arm.data.bones[f"mixamorig:{side}Shoulder"]
        d = (f.head_local - a.head_local).normalized(); q = d.rotation_difference(Vector((sx, 0, 0)))
        qs = Quaternion().slerp(q, SHARE * t); hs = sb.head_local
        pbs = arm.pose.bones[f"mixamorig:{side}Shoulder"]
        pbs.matrix = (Matrix.Translation(hs) @ qs.to_matrix().to_4x4() @ Matrix.Translation(-hs)) @ rest[sb.name]
        bpy.context.view_layer.update()
        pb = arm.pose.bones[f"mixamorig:{side}Arm"]; pf = arm.pose.bones[f"mixamorig:{side}ForeArm"]
        d2 = (pf.head - pb.head).normalized(); q2 = Quaternion().slerp(d2.rotation_difference(Vector((sx, 0, 0))), t); h2 = pb.head.copy()
        pb.matrix = (Matrix.Translation(h2) @ q2.to_matrix().to_4x4() @ Matrix.Translation(-h2)) @ pb.matrix
        bpy.context.view_layer.update()


def evaluated(names):
    """-> verts (world), tris (index triples), tri_owner [(mesh name, polygon index)], samples [(point, tri id)]"""
    dg = bpy.context.evaluated_depsgraph_get()
    verts, tris, owner = [], [], []
    for n in names:
        o = meshes[n]; me = o.evaluated_get(dg).to_mesh(); me.calc_loop_triangles()
        base = len(verts); mw = o.matrix_world
        verts.extend([mw @ v.co for v in me.vertices])
        for lt in me.loop_triangles:
            tris.append(tuple(base + i for i in lt.vertices)); owner.append((n, lt.polygon_index))
        o.evaluated_get(dg).to_mesh_clear()
    return verts, tris, owner


def sample_points(verts, tris):
    pts = []
    for ti, (a, b, c) in enumerate(tris):
        va, vb, vc = verts[a], verts[b], verts[c]
        area = ((vb - va).cross(vc - va)).length * 0.5
        pts.append((ti, (va + vb + vc) / 3.0))
        for w in ((0.7, 0.15, 0.15), (0.15, 0.7, 0.15), (0.15, 0.15, 0.7)):
            pts.append((ti, va * w[0] + vb * w[1] + vc * w[2]))
        for _ in range(min(12, int(area / 2e-4))):
            r1, r2 = random.random(), random.random()
            if r1 + r2 > 1:
                r1, r2 = 1 - r1, 1 - r2
            pts.append((ti, va + (vb - va) * r1 + (vc - va) * r2))
    return pts


per_state = {}                                                       # (mesh, polygon) -> {config name: seen}
polys_total = {n: len(meshes[n].data.polygons) for n in meshes}
seen = {n: {cfg: np.zeros(polys_total[n], bool) for cfg in CFG_MESHES} for n in meshes}
POSES = [("A", None, 0.0), ("T", None, 1.0)]
for cname, (f0, f1) in CLIPS.items():
    for k in range(CLIP_FRAMES):
        POSES.append((f"{cname}@{int(round(f0 + (f1 - f0) * k / max(CLIP_FRAMES - 1, 1)))}", cname, f0 + (f1 - f0) * k / max(CLIP_FRAMES - 1, 1)))
bpy.ops.object.mode_set(mode='OBJECT')
for pname, clip, t in POSES:
    if clip is None:
        arm.animation_data_clear(); bpy.ops.object.mode_set(mode='POSE'); pose(t); bpy.ops.object.mode_set(mode='OBJECT')
    else:
        arm.animation_data_create(); arm.animation_data.action = bpy.data.actions[clip]; bpy.context.scene.frame_set(int(round(t))); bpy.context.view_layer.update()
    for cfg, names in CFG_MESHES.items():
        verts, tris, owner = evaluated(names)
        bvh = BVHTree.FromPolygons([v[:] for v in verts], [list(t_) for t_ in tris])
        pts = sample_points(verts, tris)
        tri_seen = np.zeros(len(tris), bool)
        for yaw in YAWS:
            for pit in PITCHES:
                y, p = math.radians(yaw), math.radians(pit)
                d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))).normalized()
                for ti, pt in pts:
                    if tri_seen[ti]:
                        continue
                    hit = bvh.ray_cast(pt + d * EPS, d)
                    if hit[0] is None:
                        tri_seen[ti] = True
        for ti, s in enumerate(tri_seen):
            if s:
                n, pi = owner[ti]; seen[n][cfg][pi] = True
        print(f"[{TAG}] pose {pname} {cfg}: {len(tris)} triangles, {int(tri_seen.sum())} seen")
arm.animation_data_clear(); bpy.ops.object.mode_set(mode='POSE'); pose(0.0); bpy.ops.object.mode_set(mode='OBJECT')
report = {}
for n in sorted(meshes):
    if n not in CANDIDATES:
        continue
    safe = ~seen[n]["kept_only"]
    cond = safe | (~seen[n]["coat_off"] & ~seen[n]["coat_on"])      # hidden in both worn states and in kept_only's superset sense: the union is what today's full figure hides
    cond = (~seen[n]["coat_off"]) & (~seen[n]["coat_on"]) | safe
    for lvl, m in (("safe", safe), ("cond", cond & ~safe)):
        json.dump(np.nonzero(m)[0].tolist(), open(os.path.join(OUT, f"hidden_{lvl}_{n}.json"), "w"))
    report[n] = {"faces": polys_total[n], "safe": int(safe.sum()), "safe_pct": round(100.0 * safe.sum() / polys_total[n], 1), "cond_extra": int((cond & ~safe).sum()), "cond_extra_pct": round(100.0 * (cond & ~safe).sum() / polys_total[n], 1)}
    print(f"[{TAG}] {n:18s} faces {polys_total[n]:5d}  SAFE {int(safe.sum()):5d} ({report[n]['safe_pct']:5.1f} %)  + only under today's replaceable pieces {int((cond & ~safe).sum()):5d} ({report[n]['cond_extra_pct']:5.1f} %)")
json.dump(report, open(os.path.join(OUT, "report.json"), "w"), indent=1)

if os.environ.get("HS_PREVIEW", "1") == "1":
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = True; sh.xray_alpha = 0.28
    sc.render.resolution_x, sc.render.resolution_y = 700, 900; sc.view_settings.view_transform = 'Standard'
    for o in meshes.values():
        o.color = (0.55, 0.6, 0.7, 1); o.hide_render = False
    dg = bpy.context.evaluated_depsgraph_get()
    reds = {}
    for lvl, col in (("safe", (1, 0.05, 0.05, 1)), ("cond", (1, 0.6, 0.0, 1))):
        rv, rf = [], []
        for n in CANDIDATES:
            h = set(json.load(open(os.path.join(OUT, f"hidden_{lvl}_{n}.json"))))
            o = meshes[n]; me = o.evaluated_get(dg).to_mesh(); mw = o.matrix_world
            for pi in h:
                poly = me.polygons[pi]; b0 = len(rv); rv.extend([tuple(mw @ me.vertices[i].co) for i in poly.vertices]); rf.append(list(range(b0, b0 + len(poly.vertices))))
        rme = bpy.data.meshes.new("hid_" + lvl); rme.from_pydata(rv, [], rf)
        ro = bpy.data.objects.new("hidden_" + lvl, rme); sc.collection.objects.link(ro); ro.color = col; reds[lvl] = ro
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.35; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector((0, 0, 0.62))
    for state in ("coat_off",):
        for n, o in meshes.items():
            o.hide_render = n not in CFG_MESHES[state]
        for tag, az in (("front", 0), ("three", 40), ("back", 180)):
            a_ = math.radians(az); d = Vector((math.sin(a_), -math.cos(a_), 0.5)).normalized()
            co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(OUT, f"preview_{state}_{tag}.png"); bpy.ops.render.render(write_still=True)
print(f"[{TAG}] done: {OUT}")
