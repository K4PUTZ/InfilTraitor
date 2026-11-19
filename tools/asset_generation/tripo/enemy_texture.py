"""The guard's painted texture (ENEMIES_MASTER_PLAN §12.14): one atlas instead of five flat region colours.

Input: a light enemy from enemy_light.py (one material per region: Enemy_skin / _hair / _shirt / _trousers / _shoes).
The atlas is 2:1. Its LEFT square is the HEAD: a cylindrical projection about the neck's vertical axis, the face upright and frontal
at its centre, the seam down the back under the hair, so the Director can paint the face by hand in 2D or in Blender. Its RIGHT
square is the rest of the body (Blender's smart projection).

The paint is a function of each texel's position on the figure at rest (1 m tall, facing -Y), read from the bones, so the
reference sheet's details land on the right body part: the shirt's chest pockets with flaps, its button placket, epaulettes,
collar and cuffs, the white undershirt at the collar's opening; the trousers' waistband and white side stripe; the shoes; the hair.

The MASTER (2048 x 1024) goes to <master.png>; the GLB carries it at half size. A master that already exists keeps its HEAD square
(the Director's hand paint) unless ENEMY_TEX_FORCE=1; only the body is repainted. A face painted afterwards goes into the GLB with
glb_swap_image.py, never a Blender round trip of the GLB.

    Blender -b -P enemy_texture.py -- <light.glb> <out.glb> <palette.json> <master.png> [paint.blend]

palette.json: the region colours of enemy_light.py plus "stripe", "undershirt", "buttons" (optional, with defaults).
paint.blend: a file for hand painting, the mesh at rest wearing the master by path (Image > Save writes the master).
"""
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
region_of_mat = [m.name.replace("Enemy_", "") for m in mesh.data.materials]

# --- UVs ---------------------------------------------------------------------------------------------------------------
bm = bmesh.new()
bm.from_mesh(mesh.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.verify()
head_faces = set()
for f in bm.faces:
    c = mw @ f.calc_center_median()
    if (region_of_mat[f.material_index] in ("skin", "hair") and c.z > NECK_Z) or c.z > NECK_Z + 0.035:
        head_faces.add(f.index)
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
AX = np.array([B["Neck"][0], B["Neck"][1]])
HEAD_Z0, HEAD_Z1 = NECK_Z - 0.01, max(v.co.z for v in mesh.data.vertices) + 0.005
for f in bm.faces:
    if f.index in head_faces:
        us = []
        for lo in f.loops:
            p = mw @ lo.vert.co
            th = math.atan2(p.x - AX[0], -(p.y - AX[1]))         # 0 = the face (-Y), +-pi = the back
            us.append(0.5 + th / (2.0 * math.pi))
        if max(us) - min(us) > 0.5:                             # straddles the back seam: keep it on one side
            us = [u if u > 0.5 else 0.999 for u in us]
        for lo, u in zip(f.loops, us):
            p = mw @ lo.vert.co
            v = (p.z - HEAD_Z0) / (HEAD_Z1 - HEAD_Z0)
            lo[uv].uv = (0.004 + u * 0.492, 0.004 + v * 0.992)
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
COLLAR_TOP = NECK_Z + 0.035 + 0.02 * np.clip((np.abs(nth) - 0.9) / 0.8, 0.0, 1.0)   # it rises at the sides and back
upper = (reg == SH) | (reg == SK)
reg[upper & (Z > COLLAR_TOP)] = SK                                  # the jaw and the neck above the collar
zone = upper & (Z <= COLLAR_TOP) & (Z > NECK_Z - 0.04) & (rad < 0.09)
reg[zone] = SH
reg[zone & (np.abs(nth) < 0.35) & (Z > NECK_Z - 0.02) & (rad < 0.07)] = SK   # the collar's open front
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
vee = front & (reg != HA) & (Z > NECK_Z - 0.035) & (Z < NECK_Z + 0.01) & (AX_ < 0.004 + (Z - (NECK_Z - 0.035)) * 0.3) \
    & (Y < float(B["Neck"][1]) - 0.015)
put(vee & (reg == SH) | vee & (reg == SK) & (Z < NECK_Z), C["undershirt"])
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
img[head] = C["skin"]
put(hair, C["hair"])

# subtle low-frequency cloth variation (the reference's faceted panels) on the clothes only
rng = np.random.default_rng(7)
cloth = shirt | trou
img[cloth] *= (0.97 + 0.06 * rng.random((int(cloth.sum()), 1))).astype(np.float32) ** 0.15

# --- bleed past the islands so mip levels and bilinear filtering do not read black ------------------------------------------
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

# keep the Director's hand-painted head
if os.path.exists(master_path) and not FORCE:
    old = bpy.data.images.load(master_path)
    if tuple(old.size) == (W, H):
        o = np.array(old.pixels[:], np.float32).reshape(H, W, 4)[..., :3]
        img[:, : W // 2] = o[:, : W // 2]
        print(TAG, "kept the head square of", master_path)
    bpy.data.images.remove(old)

os.makedirs(os.path.dirname(master_path), exist_ok=True)
im = bpy.data.images.new("enemy_master", W, H)
im.pixels = np.concatenate([np.clip(img, 0, 1), np.ones((H, W, 1), np.float32)], -1).ravel()
im.filepath_raw = master_path
im.file_format = "PNG"
im.save()
print(TAG, "master", master_path)

# --- one material, the atlas at half size in the GLB ----------------------------------------------------------------------
game = bpy.data.images.new("enemy_atlas", W // 2, H // 2)
small = img.reshape(H // 2, 2, W // 2, 2, 3).mean((1, 3))
game.pixels = np.concatenate([np.clip(small, 0, 1), np.ones((H // 2, W // 2, 1), np.float32)], -1).ravel()
game.pack()
mat = bpy.data.materials.new("Enemy_atlas")
mat.use_nodes = True
nt = mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = game
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.material_index = 0
arm.data.pose_position = "POSE"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True)
print(TAG, "wrote", out)

if paint_blend:
    tex.image = bpy.data.images.load(master_path)               # by path: Image > Save writes the master
    arm.data.pose_position = "REST"
    bpy.ops.wm.save_as_mainfile(filepath=paint_blend)
    print(TAG, "paint file", paint_blend)
