"""The guard's painted texture (ENEMIES_MASTER_PLAN §12.14): one atlas instead of five flat region colours.

Input: a light enemy from enemy_light.py (one material per region: Enemy_skin / _hair / _shirt / _trousers / _shoes).
The atlas is 2:1. Its LEFT square is the HEAD: a cylindrical projection about the neck's vertical axis, the face upright and frontal
at its centre, the seam down the back under the hair, so the Director can paint the face by hand in 2D or in Blender. Its RIGHT
square is the rest of the body (Blender's smart projection).

The paint is a function of each texel's position on the figure at rest (1 m tall, facing -Y), read from the bones, so the
reference sheet's details land on the right body part: the shirt's chest pockets with flaps, its button placket, epaulettes,
collar and cuffs, the white undershirt at the collar's opening; the trousers' waistband and white side stripe; the shoes; the hair.

The painting is TWO maps since 2026-11-20 (1024 x 1024 each): <stem>_head.png (the head on FaceUV) and <stem>_body.png (the
uniform), so a head and a uniform swap apart; the GLB carries each at half size as its own material. Once they exist they are the
Director's: a re-run keeps them and only rebuilds the GLB
around them (ENEMY_TEX_FORCE=1 repaints them). The HEAD square uses the male Agent's FaceUV
(face_uv_map.py), so the face is drawn on his master's layout: a 2048 x 2048 `<master>_face.png` beside the master is the face (the
Director's, drawn from the Agent's `male_face_master.png`); without it a `<master>_face_guide.png` is written to draw on.

    Blender -b -P enemy_texture.py -- <light.glb> <out.glb> <palette.json> <master.png> [paint.blend]

palette.json: the region colours of enemy_light.py plus "stripe", "undershirt", "buttons" (optional, with defaults).
paint.blend: a file for hand painting, the mesh at rest wearing the master by path (Image > Save writes the master).
"""
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
import model_paths as mp  # where every model lives (ASSETS/MODELS layout)
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, out, palette_path, master_path = args[0], args[1], args[2], os.path.abspath(args[3])
paint_blend = os.path.abspath(args[4]) if len(args) > 4 else ""
FORCE = os.environ.get("ENEMY_TEX_FORCE", "") == "1"
REPAINT_BODY = os.environ.get("ENEMY_REPAINT_BODY", "") == "1"   # carry only the head map; the uniform is painted afresh
W, H = 2048, 1024
TAG = "[enemy_texture]"


def rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


pal = json.load(open(palette_path))
C = {k: rgb(v) for k, v in pal.items()}
C.setdefault("stripe", rgb("#e8ecf2"))
C.setdefault("undershirt", rgb("#eeeeea"))
C.setdefault("buttons", rgb("#2c568a"))

head_path = master_path.replace("_master.png", "_head.png")
body_path = master_path.replace("_master.png", "_body.png")
HAND = os.path.exists(head_path) and os.path.exists(body_path) and not FORCE


# The PREVIOUS layout, read from the GLB this run replaces (2026-11-20): when the layout changes under the Director's maps, his
# paint is carried across triangle by triangle (same rest geometry, matched by centroid), never lost or left misaligned.
def _old_layout(path: str):
    if not (HAND and os.path.exists(path)):
        return None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for a in [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]:
        a.data.pose_position = "REST"
    P, U, M = [], [], []
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        d = o.data
        if not d.uv_layers:
            continue
        d.calc_loop_triangles()
        ud = d.uv_layers.active.data
        for t in d.loop_triangles:
            mat = d.materials[t.material_index].name if d.materials else ""
            if mat not in ("Enemy_head", "Enemy_body"):
                continue
            P.append([tuple(o.matrix_world @ d.vertices[v].co) for v in t.vertices])
            U.append([tuple(ud[li].uv) for li in t.loops])
            M.append(0 if mat == "Enemy_head" else 1)
    return np.array(P, np.float64), np.array(U, np.float64), np.array(M, np.int8)


OLD = None if os.environ.get("ENEMY_NO_CARRY", "") == "1" else _old_layout(out)   # 1: the maps already fit this layout
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
arm.data.pose_position = "REST"


def bone(name: str) -> np.ndarray:
    b = arm.data.bones["mixamorig:" + name]
    return np.array(arm.matrix_world @ b.head_local, dtype=np.float32)


B = {n: bone(n) for n in ("Hips", "Spine2", "Neck", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg",
                          "RightFoot", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand")}
NECK_Z = float(B["Neck"][2])
WAIST_Z = float(B["Spine"][2]) if "Spine" in B else float(B["Hips"][2]) + 0.05
mw = mesh.matrix_world
mat_of = [m.name.replace("Enemy_", "") for m in mesh.data.materials]   # skin / hair = the head piece (enemy_light.py)
region_of_mat = ["skin" if r == "hands" else r for r in mat_of]

# The head takes the male Agent's FaceUV (face_uv_map.py with his params): the enemies share his silhouette, so his painted
# face master is the layout an enemy's face is drawn on (the Director, 2026-11-19), at half scale in the left square.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import face_uv_map as fm
FACEUV = json.load(open(os.environ.get("ENEMY_FACEUV", mp.agent("male", "textures", "male_faceuv.json"))))
# The enemy's head is not where the Agent's is (the FID guard's: 2.0 cm higher, 1.3 cm forward): FaceUV moves by the offset between
# the two nose tips, so the face's features land on the enemy's. The Agent's tip, measured on AGENT_MALE_LIGHT.glb at rest
# (2026-11-19): the head's most forward point above 0.84 m within 5 cm of the middle.
AGENT_NOSE = (-0.0040, -0.0684, 0.8965)
_hv = [mw @ v.co for v in mesh.data.vertices if (mw @ v.co).z > 0.84 and abs((mw @ v.co).x) < 0.05]
_nose = min(_hv, key=lambda c: c.y)
FACEUV = dict(FACEUV, xc=FACEUV["xc"] + (_nose.x - AGENT_NOSE[0]), yc=FACEUV["yc"] + (_nose.y - AGENT_NOSE[1]),
              z0=FACEUV["z0"] + (_nose.z - AGENT_NOSE[2]), z1=FACEUV["z1"] + (_nose.z - AGENT_NOSE[2]))
print(TAG, "FaceUV moved by the nose", tuple(round(a - b, 4) for a, b in zip(tuple(_nose), AGENT_NOSE)))

# --- UVs ---------------------------------------------------------------------------------------------------------------
bm = bmesh.new()
bm.from_mesh(mesh.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.verify()
# The HEAD map holds Tripo's head piece, whole (its faces are skin or hair, enemy_light.py), and nothing else; the body map the
# rest (2026-11-20). Its neck below the chin and the jaw's underside fall on the face's own texels on FaceUV's cylinder (the
# streaks of 2026-11-19), so they get a band of their own at the bottom of the head map: the same angle, the height along the
# neck squeezed below the face.
CHIN_Z = _nose.z - 0.055
# FaceUV's axis runs just behind the throat (the guard's at y -0.022, the neck's front at -0.028): a face within a few centimetres
# of it that looks DOWN, the jaw's underside, is a sliver across a third of the map's width and shows as a flat triangle without
# texture under the chin (2026-11-20); those join the neck's band. The ones that look OUT, the jaw's sides beside the chin, are
# in the painted face and stay on FaceUV: the Director's red and blue test spots on the jaw's sides showed nowhere on the head
# while every near face left (2026-11-20). Measured on the guard: the underside's normals run z -0.76 to -0.99, the sides' -0.17 to
# -0.58. The chin's front and the lips start at 4.3 cm and stay on FaceUV.
NEAR_AXIS = 0.042
UNDER_JAW_NZ = -0.7
head_faces, neck_faces, lower_faces = set(), set(), set()
for f in bm.faces:
    if mat_of[f.material_index] not in ("skin", "hair"):
        continue
    head_faces.add(f.index)
    c = mw @ f.calc_center_median()
    p0, p1, p2 = (mw @ lo.vert.co for lo in f.loops)
    nz = (p1 - p0).cross(p2 - p0).normalized().z
    # measured from the face's midline (the nose's x), not FaceUV's axis 4 mm aside, so both sides of the chin cut alike
    near = math.hypot(c.x - _nose.x, c.y - FACEUV["yc"]) < NEAR_AXIS and c.z < _nose.z - 0.03
    if c.z < CHIN_Z or near:
        lower_faces.add(f.index)
    if c.z < CHIN_Z or (near and nz < UNDER_JAW_NZ):   # never every downward face under the nose: the lips' and the chin's undersides are seen
        neck_faces.add(f.index)
bm.to_mesh(mesh.data)
bm.free()

bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(mesh.data)
bm.faces.ensure_lookup_table()
for f in bm.faces:
    f.select = f.index not in head_faces
bmesh.update_edit_mesh(mesh.data)
bpy.ops.uv.smart_project(angle_limit=math.radians(72), island_margin=0.008, area_weight=0.0, correct_aspect=True,
                         scale_to_bounds=True)
bm = bmesh.from_edit_mesh(mesh.data)
uv = bm.loops.layers.uv.verify()
face_v_min = 1.0
for f in bm.faces:
    if f.index in head_faces and f.index not in neck_faces:
        P = np.array([[tuple(mw @ lo.vert.co) for lo in f.loops]], np.float64)
        face_v_min = min(face_v_min, float(fm.tri_uv(P, FACEUV)[0][:, 1].min()))
NECK_TOP = max(face_v_min - 0.012, 0.05)
# The band is unrolled about the NECK's own axis (between the Neck and Head bones), far from every face it holds, and its height
# runs along the profile, up the neck and then out under the jaw (z plus the distance from that axis), so the jaw's underside is
# a strip and not a line.
NECK_AXIS = dict(FACEUV, xc=float(B["Neck"][0] + B["Head"][0]) / 2.0, yc=float(B["Neck"][1] + B["Head"][1]) / 2.0)


def _profile(P: np.ndarray) -> np.ndarray:
    return P[..., 2] + fm.radius(P, NECK_AXIS)


# The band's height range is the profile's over the whole lower head (below the chin or near the axis, whichever way a face looks),
# not over the faces it holds: which near faces join it never rescales it, so the Director's paint in it stays put (2026-11-20).
_np = np.array([[tuple(mw @ lo.vert.co) for lo in f.loops] for f in bm.faces if f.index in lower_faces], np.float64)
S0, S1 = (float(_profile(_np).min()), float(_profile(_np).max())) if len(_np) else (0.0, 1.0)
for f in bm.faces:
    if f.index in head_faces:
        P = np.array([[tuple(mw @ lo.vert.co) for lo in f.loops]], np.float64)
        if f.index in neck_faces:
            U = fm.tri_uv(P, NECK_AXIS)[0]
            U[:, 1] = 0.004 + (_profile(P[0]) - S0) / max(S1 - S0, 1e-6) * (NECK_TOP - 0.004)
        else:
            U = fm.tri_uv(P, FACEUV)[0]
        for lo, (u, v) in zip(f.loops, U):
            lo[uv].uv = (min(float(u), 0.999) * 0.5, min(max(float(v), 0.004), 0.996))   # past the back seam / above the Agent's crown: the edge (hair)
    else:
        for lo in f.loops:
            u, v = lo[uv].uv
            lo[uv].uv = (0.5 + 0.004 + u * 0.492, 0.004 + v * 0.992)
bmesh.update_edit_mesh(mesh.data)
bpy.ops.object.mode_set(mode="OBJECT")

# --- rasterise: each texel's position, normal and region ----------------------------------------------------------------
me = mesh.data
me.calc_loop_triangles()
uvd = me.uv_layers.active.data
pos = np.zeros((H, W, 3), np.float32)
nrm = np.zeros((H, W, 3), np.float32)
reg = np.full((H, W), -1, np.int16)
tid = np.full((H, W), -1, np.int32)       # the triangle each texel belongs to (loop_triangles' order), and where in it
lam_of = np.zeros((H, W, 3), np.float32)
vco = np.array([tuple(mw @ v.co) for v in me.vertices], np.float32)
rot = mw.to_3x3()
vno = np.array([tuple((rot @ v.normal).normalized()) for v in me.vertices], np.float32)
for t in me.loop_triangles:
    puv = np.array([uvd[li].uv for li in t.loops], np.float32) * np.array([W, H], np.float32)
    x0, y0 = np.floor(puv.min(0)).astype(int) - 1
    x1, y1 = np.ceil(puv.max(0)).astype(int) + 1
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = puv
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        continue
    l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    l2 = 1.0 - l0 - l1
    inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
    if not inside.any():
        continue
    vi = list(t.vertices)
    lam = np.stack([l0, l1, l2], -1)[inside]
    yy, xx = (ys[inside] - 0.5).astype(int), (xs[inside] - 0.5).astype(int)
    pos[yy, xx] = lam @ vco[vi]
    nn = lam @ vno[vi]
    nrm[yy, xx] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
    reg[yy, xx] = ["skin", "hair", "shirt", "trousers", "shoes"].index(region_of_mat[t.material_index])
    tid[yy, xx] = t.index
    lam_of[yy, xx] = lam

# --- paint ----------------------------------------------------------------------------------------------------------------
img = np.zeros((H, W, 3), np.float32)
X, Y, Z = pos[..., 0], pos[..., 1], pos[..., 2]
NX, NY, NZ = nrm[..., 0], nrm[..., 1], nrm[..., 2]
AX_ = np.abs(X)
SK, HA, SH, TR, SO = 0, 1, 2, 3, 4
# The regions of enemy_light.py are per FACE; settle the neck and the wrists per TEXEL. Above the collar it is the head (the
# jaw weighs on the neck bone); round the neck the collar stands out from the neck's axis and closes at the back.
# the neck's axis leans forward to the head; the outer radius about it, measured on the source (2026-11-19): the collar stands
# 0.06-0.10 out up to 0.855, the bare neck above it about 0.05
HEAD_Z = float(B["Head"][2])
ky = np.clip((Z - NECK_Z) / (HEAD_Z - NECK_Z), 0.0, 1.0)
rad = np.hypot(X - float(B["Neck"][0]), Y - (float(B["Neck"][1]) + (float(B["Head"][1]) - float(B["Neck"][1])) * ky))
nth = np.arctan2(X - float(B["Neck"][0]), -(Y - float(B["Neck"][1])))
COLLAR_TOP = NECK_Z + 0.035 + 0.025 * np.clip((np.abs(nth) - 0.35) / 0.5, 0.0, 1.0)   # it rises at the sides and back
upper = reg == SH                    # the head piece is skin and hair by itself (enemy_light.py): only the shirt is reshaped here
zone = upper & (Z <= COLLAR_TOP) & (Z > NECK_Z - 0.04) & (rad < 0.09)
# the collar's open front is a narrow V between the two collar points (the Director, 2026-11-19): its apex where the points meet,
# the white undershirt at its bottom, the neck's skin above; everything else round the neck is the collar
V_APEX = NECK_Z - 0.012
vmask = zone & (np.abs(nth) < 1.2) & (Z > V_APEX) & (np.abs(X - float(B["Neck"][0])) < np.minimum(0.002 + (Z - V_APEX) * 0.6, 0.024))
reg[vmask] = SK
# the waist: the shirt's hem weighs on the hips bone; above the trousers' top it is shirt, below it trousers
trunk = ((reg == SH) | (reg == TR)) & (np.abs(X) < 0.105)
reg[trunk & (Z > WAIST_Z + 0.008)] = SH
reg[trunk & (Z <= WAIST_Z + 0.008) & (Z > WAIST_Z - 0.08)] = TR
for hb, fb in ((B["LeftHand"], B["LeftForeArm"]), (B["RightHand"], B["RightForeArm"])):
    axis = (hb - fb) / np.linalg.norm(hb - fb)
    t = (pos - hb) @ axis
    near = ((reg == SH) | (reg == SK)) & (np.linalg.norm(pos - hb, axis=-1) < 0.09)
    reg[near & (t > 0.004)] = SK
    reg[near & (t <= -0.002)] = SH
for k, name in enumerate(("skin", "hair", "shirt", "trousers", "shoes")):
    img[reg == k] = C[name]

front = NY < -0.35
shirt = reg == SH
trou = reg == TR
top = float(pos[..., 2][reg >= 0].max())


def put(mask, col, a=1.0):
    img[mask] = img[mask] * (1.0 - a) + np.asarray(col) * a


def shade(mask, f):
    img[mask] = np.clip(img[mask] * f, 0.0, 1.0)


chest_z0, chest_z1 = NECK_Z - 0.12, NECK_Z - 0.055                 # the pockets (the reference: from the 2nd to the 3rd button)
torso = shirt & (Z > WAIST_Z) & (Z < NECK_Z) & (AX_ < 0.095)
# placket and buttons down the middle of the front
plk = torso & front & (AX_ < 0.006)
shade(plk, 0.85)
for bz in np.arange(NECK_Z - 0.04, WAIST_Z + 0.01, -0.042):
    put(torso & front & (np.hypot(X, Z - bz) < 0.0045), C["buttons"] * 0.8)
# chest pockets with a flap, both sides
pk = torso & front & (AX_ > 0.024) & (AX_ < 0.068) & (Z > chest_z0) & (Z < chest_z1)
shade(pk, 0.93)
pk_edge = pk & ((AX_ < 0.027) | (AX_ > 0.065) | (Z < chest_z0 + 0.003))
shade(pk_edge, 0.72)
flap = torso & front & (AX_ > 0.022) & (AX_ < 0.070) & (Z > chest_z1 - 0.018) & (Z < chest_z1 + 0.002)
shade(flap, 1.05)
shade(flap & (np.abs(Z - (chest_z1 - 0.018)) < 0.0025), 0.65)
for side in (-1.0, 1.0):
    put(torso & front & (np.hypot(X - side * 0.046, Z - (chest_z1 - 0.010)) < 0.0035), C["buttons"] * 0.8)
# epaulettes: a strap along each shoulder's top, from the collar to the arm
for side, arm_b in ((1.0, B["LeftArm"]), (-1.0, B["RightArm"])):
    ep = shirt & (NZ > 0.45) & (X * side > 0.035) & (X * side < abs(arm_b[0]) + 0.005) & (np.abs(Y - arm_b[1]) < 0.013)
    shade(ep, 0.88)
    shade(ep & (np.abs(np.abs(Y - arm_b[1]) - 0.012) < 0.0025), 0.7)
# collar: the shirt above the neck's base, a little darker, with the undershirt's V at its opening
collar = shirt & (Z > NECK_Z + 0.005) & (rad < 0.09)
shade(collar, 0.9)
vee = (reg == SK) & (Z > V_APEX) & (Z < V_APEX + 0.022) & (np.abs(X - float(B["Neck"][0])) < 0.002 + (Z - V_APEX) * 0.6) & (NY < 0.0)
put(vee, C["undershirt"])
# cuffs: a band above each wrist, its upper edge a seam
for hb, fb in ((B["LeftHand"], B["LeftForeArm"]), (B["RightHand"], B["RightForeArm"])):
    axis = (hb - fb) / np.linalg.norm(hb - fb)
    t = (pos - hb) @ axis                                           # 0 at the wrist, negative up the forearm
    cuff = shirt & (t > -0.035) & (t < 0.01) & (np.linalg.norm(pos - hb, axis=-1) < 0.06)
    shade(cuff, 0.9)
    shade(cuff & (np.abs(t + 0.035) < 0.003), 0.7)
# trousers: waistband with its tab, the side stripe, a front crease
band = trou & (Z > WAIST_Z - 0.022)
shade(band, 0.82)
shade(band & (np.abs(Z - (WAIST_Z - 0.022)) < 0.003), 0.7)
put(band & front & (AX_ < 0.018) & (Z > WAIST_Z - 0.018), C["trousers"] * 0.95)
for side, ul, lg, ft in ((1.0, B["LeftUpLeg"], B["LeftLeg"], B["LeftFoot"]), (-1.0, B["RightUpLeg"], B["RightLeg"], B["RightFoot"])):
    leg = trou & (X * side > 0.0) & (Z < WAIST_Z - 0.03)
    # the leg's axis at this height: the thigh above the knee, the shin below
    ax = np.where((Z > lg[2])[..., None], ul + (lg - ul) * ((Z - ul[2]) / (lg[2] - ul[2]))[..., None],
                  lg + (ft - lg) * ((Z - lg[2]) / (ft[2] - lg[2]))[..., None])
    ang = np.arctan2(Y - ax[..., 1], (X - ax[..., 0]) * side)       # 0 = straight outward
    put(leg & (np.abs(ang) < 0.11), C["stripe"])
    put(leg & (np.abs(ang) >= 0.11) & (np.abs(ang) < 0.15), C["trousers"] * 0.7)
    shade(leg & (np.abs(np.arctan2(Y - ax[..., 1], X - ax[..., 0]) + math.pi / 2.0) < 0.05), 1.12)   # the crease, front
# shoes: a darker sole, a lighter toe cap
sh = reg == SO
shade(sh & (NZ < -0.3), 0.6)
put(sh & (NZ > 0.4) & (Y < -0.03), C["shoes"] * 1.8)
# hair: a short crop, the hairline per texel (smoother than the faces of enemy_light.py)
head = (reg == SK) | (reg == HA)
# the hairline: a smooth function of the angle round the head, low at the nape, high on the forehead
th = np.arctan2(X - float(B["Head"][0]), -(Y - float(B["Head"][1])))
line = top - 0.036 - 0.045 * (1.0 - np.cos(th)) / 2.0
hair = head & (Z > line)
img[head & ~vee] = C["skin"]
put(hair, C["hair"])

# subtle low-frequency cloth variation (the reference's faceted panels) on the clothes only
rng = np.random.default_rng(7)
cloth = shirt | trou
img[cloth] *= (0.97 + 0.06 * rng.random((int(cloth.sum()), 1))).astype(np.float32) ** 0.15

# --- bleed past the islands so mip levels and bilinear filtering do not read black ------------------------------------------
def _bleed() -> None:
    filled = reg >= 0
    for _ in range(6):
        acc = np.zeros_like(img)
        cnt = np.zeros((H, W, 1), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sf = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(img, (dy, dx), (0, 1)) * sf[..., None]
            cnt += sf[..., None]
        grow = (~filled) & (cnt[..., 0] > 0)
        img[grow] = acc[grow] / cnt[grow]
        filled = filled | grow


_bleed()

# the face: the Director's own 2048 x 2048 image on the male Agent's FaceUV layout (<master>_face.png beside the master), dropped
# into the head square at half size; without it the head keeps the generated skin and hair, and that square is written out at
# full size as the guide to draw the face on (<master>_face_guide.png)
# The MASTER is the Director's once it exists (2026-11-19): he edits it in Photoshop, Godot reimports it and the game reads it
# (ActorMesh3D `atlas`); this script then only rebuilds the GLB around it. ENEMY_TEX_FORCE=1 repaints it, losing his edits.
def _load_square(path: str) -> np.ndarray:
    _m = bpy.data.images.load(path)
    if tuple(_m.size) != (W // 2, H):
        raise SystemExit(f"{TAG} {path}: {tuple(_m.size)}, expected {(W // 2, H)}")
    a = np.array(_m.pixels[:], np.float32).reshape(H, W // 2, 4)[..., :3].copy()
    bpy.data.images.remove(_m)
    return a


def _carry(old, maps) -> int:
    """the Director's paint onto this run's layout: each texel finds its triangle in the old GLB (same rest geometry, nearest
    centroid) and reads the old map where that triangle's point was. A head-piece triangle the old layout drew on the BODY map
    (the neck under the jaw, painted as the collar until 2026-11-20) takes the skin of his lower face instead. Returns how many
    triangles found no twin (they keep the generated paint)."""
    from mathutils.kdtree import KDTree
    P, U, M = old
    cen = P.mean(1)
    kd = KDTree(len(cen))
    for i, c in enumerate(cen):
        kd.insert(c, i)
    kd.balance()
    tris = list(me.loop_triangles)
    match = np.full(len(tris), -1, np.int64)
    for t in tris:
        c = vco[list(t.vertices)].mean(0)
        _co, j, d = kd.find(c)
        if d < 1e-4:
            match[t.index] = j
    on = tid >= 0
    on[on] = match[tid[on]] >= 0
    ys, xs = np.nonzero(on)
    j = match[tid[ys, xs]]
    q = pos[ys, xs].astype(np.float64)
    a, b, c = P[j, 0], P[j, 1], P[j, 2]
    v0, v1, v2 = b - a, c - a, q - a
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
    l1 = (d11 * d20 - d01 * d21) / den
    l2 = (d00 * d21 - d01 * d20) / den
    lam = np.clip(np.stack([1 - l1 - l2, l1, l2], 1), 0.0, 1.0)
    lam /= lam.sum(1, keepdims=True)
    ouv = (lam[:, :, None] * U[j]).sum(1)
    sx = np.clip((ouv[:, 0] * (W // 2)).astype(int), 0, W // 2 - 1)
    sy = np.clip((ouv[:, 1] * H).astype(int), 0, H - 1)
    keep = np.ones(len(j), bool)
    if REPAINT_BODY:
        keep = np.isin(tid[ys, xs], [t.index for t in tris if mat_of[t.material_index] in ("skin", "hair")])
    img[ys[keep], xs[keep]] = np.where((M[j] == 0)[:, None], maps[0][sy, sx], maps[1][sy, sx])[keep]
    # the head piece's neck that the old layout painted on the body map: skin, the median of the lower face
    head_tri = np.zeros(len(tris), bool)
    head_tri[[t.index for t in tris if mat_of[t.material_index] in ("skin", "hair")]] = True
    from_body = head_tri[tid[ys, xs]] & (M[j] == 1)
    low_face = (reg == SK) & (tid >= 0) & (Z > CHIN_Z) & (Z < _nose.z - 0.02) & (np.arange(W)[None, :] < W // 2)
    low_face &= ~np.isin(tid, [t.index for t in tris if t.polygon_index in neck_faces])
    tone = np.median(img[low_face], 0) if low_face.any() else C["skin"]
    img[ys[from_body], xs[from_body]] = tone
    # the head piece's back of the neck, which the old rules painted as the collar on the head map itself: closer to the shirt's
    # colour than to his skin, it takes the skin (or the hair where the nape's hair is)
    hy, hx = ys[head_tri[tid[ys, xs]]], xs[head_tri[tid[ys, xs]]]
    col = img[hy, hx]
    shirtish = np.linalg.norm(col - C["shirt"], axis=1) < np.linalg.norm(col - tone, axis=1)
    img[hy[shirtish], hx[shirtish]] = np.where((reg[hy[shirtish], hx[shirtish]] == HA)[:, None], C["hair"], tone)
    return int((match < 0).sum())


KEEP = HAND
if HAND:
    maps = (_load_square(head_path), _load_square(body_path))
    if OLD is None:
        img = np.concatenate(maps, 1)
        print(TAG, "kept the head and body maps (the Director's):", head_path, body_path)
    else:
        lost = _carry(OLD, maps)
        _bleed()
        print(TAG, f"carried the Director's maps onto this layout ({lost} triangles without a twin keep the generated paint)")
else:
    face_path = os.path.abspath(os.environ.get("ENEMY_FACE", master_path.replace("_master.png", "_face.png")))   # ENEMY_FACE: another file
    if os.path.exists(face_path):
        fimg = bpy.data.images.load(face_path)
        if tuple(fimg.size) != (W // 2 * 2, H * 2):
            fimg.scale(W // 2 * 2, H * 2)
        f = np.array(fimg.pixels[:], np.float32).reshape(H * 2, W, 4)[..., :3]
        hs = img[:, : W // 2]
        keep = ~((reg[:, : W // 2] == 0) | (reg[:, : W // 2] == 1) | (reg[:, : W // 2] < 0))   # the collar stays the shirt's
        face = f.reshape(H, 2, W // 2, 2, 3).mean((1, 3))
        hs[~keep] = face[~keep]
        hs[hair[:, : W // 2]] = C["hair"]          # the crown: a face image that paints only the hairline band still gets a full crop
        # the clamped edges (the back seam's column, the crown's row) are hair above the nape
        m = FACEUV["margin"]
        v_nape = m + (top - 0.081 - FACEUV["z0"]) / (FACEUV["z1"] - FACEUV["z0"]) * (1.0 - 2.0 * m)
        hs[int(v_nape * H):, W // 2 - 10:] = C["hair"]
        hs[H - 12:, :] = C["hair"]
        print(TAG, "face from", face_path)
        bpy.data.images.remove(fimg)
    else:
        g = bpy.data.images.new("guide", W, H * 2)
        up = np.repeat(np.repeat(img[:, : W // 2], 2, 0), 2, 1)
        g.pixels = np.concatenate([np.clip(up, 0, 1), np.ones((H * 2, W, 1), np.float32)], -1).ravel()
        g.filepath_raw = master_path.replace("_master.png", "_face_guide.png"); g.file_format = "PNG"; g.save()
        print(TAG, "no face yet; guide", g.filepath_raw)


if not HAND or OLD is not None:   # a carried layout rewrites his maps in place (backups: git)
    os.makedirs(os.path.dirname(master_path), exist_ok=True)
    for path, sq in ((head_path, img[:, : W // 2]), (body_path, img[:, W // 2:])):
        im = bpy.data.images.new(os.path.basename(path), W // 2, H)
        im.pixels = np.concatenate([np.clip(sq, 0, 1), np.ones((H, W // 2, 1), np.float32)], -1).ravel()
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
        print(TAG, "wrote", path)

# --- two materials: the HEAD map (left square) and the BODY map (right square), each at half size in the GLB -----------------
# Split 2026-11-20 (the Director): a head's map and a uniform's map are swapped apart (N faces x M uniforms, no N x M atlases).
# Each face lies wholly in one square (they are separate islands); its u is stretched back to 0..1 within its own map.
uvl = me.uv_layers.active.data
mats = []
for name, sq in (("Enemy_head", img[:, : W // 2]), ("Enemy_body", img[:, W // 2:])):
    game = bpy.data.images.new(name.lower() + "_map", W // 4, H // 2)
    small = sq.reshape(H // 2, 2, W // 4, 2, 3).mean((1, 3))
    game.pixels = np.concatenate([np.clip(small, 0, 1), np.ones((H // 2, W // 4, 1), np.float32)], -1).ravel()
    game.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = game
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    mats.append((mat, tex))
me.materials.clear()
for mat, _t in mats:
    me.materials.append(mat)
straddle = 0
for p in me.polygons:
    us = [uvl[li].uv[0] for li in p.loop_indices]
    side = 0 if sum(us) / len(us) < 0.5 else 1
    if (min(us) < 0.5 - 1e-4 and max(us) > 0.5 + 1e-4):
        straddle += 1
    p.material_index = side
    for li in p.loop_indices:
        uvl[li].uv[0] = min(max((uvl[li].uv[0] - 0.5 * side) * 2.0, 0.0), 1.0)
if straddle:
    raise SystemExit(f"{TAG} {straddle} faces cross the head / body line")
# the head and the uniform are two meshes on one skeleton (2026-11-20): a head is swapped on its own, map and mesh
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.mesh.separate(type="MATERIAL")
for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]:
    ob.name = ob.data.name = "Head" if ob.active_material and ob.active_material.name == "Enemy_head" else "Body"
arm.data.pose_position = "POSE"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True)
print(TAG, "wrote", out)

if paint_blend:
    for (mat, tex), path in zip(mats, (head_path, body_path)):
        tex.image = bpy.data.images.load(path)                  # by path: Image > Save writes the map
    arm.data.pose_position = "REST"
    bpy.ops.wm.save_as_mainfile(filepath=paint_blend)
    print(TAG, "paint file", paint_blend)
