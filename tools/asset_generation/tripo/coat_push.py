# coat_push.py — THE LEGS PUSH THE COAT (ACTOR D94, 2026-11-01; D88 gave the coat its skirt chains). The numpy half of a pair: this file is the reference the vertex shader
# (`godot/shaders/coat_push.gdshaderinc`) is ported from, and what bakes the per-vertex data it reads (`tripo_coat_push.py`).
#
# WHY. The long coat's skirt is a tube 3 cm off the trousers at the hem, and a stride sweeps the legs 25 cm through it: in a walk the trailing leg came out through the
# back panel and the leading knee through the front flaps (Director, 2026-11-01: "a perna atravessando o casaco, tanto na frente quanto atras, mesmo apenas caminhando").
# Chains of spring bones (D88) soften it, but a bone only pushes the cloth at its own joint, the top of the skirt hangs from the body, and what a spring remembers is a
# state (a yaw snap of the grid whips it). The Director's picture of what it should do: "o esqueleto do ator empurrar o tecido na parte de tras e formar um calombo na
# perna; na frente, a fenda do casaco simplesmente se abre mais, com as pontas das saias pendendo pros dois lados, enquanto os joelhos e as pernas se movimentam
# livremente".
#
# WHAT. Each skirt vertex has an OUTWARD DIRECTION d, baked from the rest pose: lateral (away from the centre line) on the front and the sides, turning to backward on the
# back. The legs are capsules (thigh, shin, foot, both sides). A vertex whose ray p + t d passes through a capsule is moved along d to the capsule's FAR side: the cloth lies
# over the leg like a sheet draped over it, so on the back the leg raises a bulge, and on the front the part of each flap in front of the knee slides sideways off it (the
# slit opens, the flaps hang to the two sides). Outside the capsule's silhouette the push falls off in a tent whose width follows its height, so there is no cliff; a vertex the first pass moved out of one capsule into another leaves that one in a second pass. Every
# quantity is a function of the CURRENT pose only (no state): the same pose draws the same coat, a yaw snap or a teleport cannot whip it.
# What the coat already does at rest (its inner side touches the thighs at a few places) is its own shape: the push the REST pose would give each vertex is baked and
# subtracted, so an idle figure is untouched.
#
# DATA (per Outfit_Coat vertex; names are Blender's, the importer hands them to Godot as): colour "CoatPush" -> COLOR (r = 1 - mask, so a piece with no colour attribute, which
# Godot gives (1,1,1,1), is never pushed; g = the rest push / REST_SCALE), UV map "CoatPushDir" -> UV2 (the rest direction in the glTF axes: x lateral, y = the glTF Z, the
# front being +Z), and the object's custom property `coat_push` (JSON: the capsule radii and the tent's numbers, read by `CoatPush3D`).
# All lengths are fractions of the figure's height H (Tripo exports a 1 m figure).
import json, math
import numpy as np

R_THIGH, R_SHIN, R_FOOT = 0.062, 0.060, 0.045     # capsule radii: the trousers' own (thigh 0.05-0.065, calf 0.06, ankle 0.04) plus what keeps the cloth off the leg's lumps
DELTA = 0.006                                    # the cloth's offset from the capsule
ZON_UP, ZOFF_UP = 0.065, 0.125                   # the push applies below the hips + ZON_UP and fades out by ZOFF_UP: a thigh raised to the belt still reaches the coat, the chest never
BACK0, BACK1 = 105.0, 150.0                      # degrees from the front: lateral below BACK0, backward past BACK1
DEAD = 0.03                                      # the width of the centre line over which a front vertex turns from "left" to "right"
W_MIN, W_MAX, K_W = 0.03, 0.12, 0.5              # the tent outside a silhouette: width = K_W x its height, between W_MIN and W_MAX
PASSES = int(__import__('os').environ.get('COAT_PUSH_PASSES', '2'))   # how many times a vertex is pushed: the shader does two (the second only for a vertex the first moved)
REST_SCALE = 0.1                                 # the rest push is stored as metres / REST_SCALE in one colour channel (8 bits on the handset: 0.4 mm)
NAMES = ("LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase")


def spec(H, **over):
    """the numbers a figure of height H is pushed with, in metres (also what `CoatPush3D` reads from the model)"""
    s = {"version": 1, "r_thigh": R_THIGH * H, "r_shin": R_SHIN * H, "r_foot": R_FOOT * H, "delta": DELTA * H,
         "w_min": W_MIN * H, "w_max": W_MAX * H, "k_w": K_W}
    s.update(over)
    return s


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _dot(a, b):
    return np.einsum('ij,ij->i', a, b)


def capsule_far(p, d, A, B, r):
    """the ray p + t d (d unit) against the capsule A-B of radius r -> (hit, t_out): where it leaves the capsule"""
    n = len(p)
    ba = B - A; baba = float(ba @ ba)
    oa = p - A
    bard = d @ ba; baoa = oa @ ba
    rdoa = _dot(d, oa); oaoa = _dot(oa, oa)
    cand = np.full((n, 6), -np.inf)
    a = baba - bard ** 2                                                       # the infinite cylinder, valid between the caps
    b = baba * rdoa - baoa * bard
    c = baba * oaoa - baoa ** 2 - r * r * baba
    h = b * b - a * c
    ok = (h >= 0) & (np.abs(a) > 1e-9)
    sq = np.sqrt(np.where(ok, h, 0.0)); aa = np.where(np.abs(a) > 1e-9, a, 1.0)
    for k, s in enumerate((-1.0, 1.0)):
        t = (-b + s * sq) / aa
        y = baoa + t * bard
        cand[:, k] = np.where(ok & (y >= 0) & (y <= baba), t, -np.inf)
    disc = rdoa ** 2 - (oaoa - r * r)                                          # the sphere at A, valid beyond A's cap
    sq = np.sqrt(np.maximum(disc, 0.0))
    for k, s in enumerate((-1.0, 1.0)):
        t = -rdoa + s * sq
        cand[:, 2 + k] = np.where((disc >= 0) & (baoa + t * bard <= 0), t, -np.inf)
    ob = p - B; rdob = _dot(d, ob)                                             # the sphere at B, valid beyond B's cap
    disc = rdob ** 2 - (_dot(ob, ob) - r * r)
    sq = np.sqrt(np.maximum(disc, 0.0))
    for k, s in enumerate((-1.0, 1.0)):
        t = -rdob + s * sq
        cand[:, 4 + k] = np.where((disc >= 0) & (baoa + t * bard >= baba), t, -np.inf)
    t_out = cand.max(axis=1)
    return np.isfinite(t_out), t_out


def silhouette(p, d, A, B):
    """seen along d: the distance from p to the segment A-B, and where along d the segment's closest point lies"""
    a = A - p; a = a - _dot(a, d)[:, None] * d
    b = B - p; b = b - _dot(b, d)[:, None] * d
    ab = b - a; ab2 = np.maximum(_dot(ab, ab), 1e-12)
    u = np.clip(-_dot(a, ab) / ab2, 0.0, 1.0)
    return np.linalg.norm(a + u[:, None] * ab, axis=1), _dot((A + u[:, None] * (B - A)) - p, d)


def push_distance(p, d, caps, s, tent_on=True):
    """how far each vertex goes along d: the largest over the capsules caps [(A, B, r)] of the far exit (inside the silhouette) or the tent (outside it)"""
    D = np.zeros(len(p))
    for (A, B, r) in caps:
        R = r + s["delta"]
        hit, t_out = capsule_far(p, d, A, B, R)
        rho, tau = silhouette(p, d, A, B)
        Dc = np.zeros(len(p))
        inside = hit & (t_out > 0)
        Dc[inside] = t_out[inside]
        w = np.clip(s["k_w"] * np.maximum(tau, 0.0) + s["w_min"], s["w_min"], s["w_max"])
        L = rho - R
        tent = (~hit) & (L > 0) & (L < w) & (tau > 0) & tent_on
        Dc[tent] = (tau * (1.0 - sstep(0.0, 1.0, L / w)))[tent]
        D = np.maximum(D, Dc)
    return D


def capsules(joint, s):
    """the leg capsules [(A, B, r)] from `joint(name) -> position` (a Mixamo joint name without the prefix)"""
    out = []
    for side in ("Left", "Right"):
        out.append((joint(side + "UpLeg"), joint(side + "Leg"), s["r_thigh"]))
        out.append((joint(side + "Leg"), joint(side + "Foot"), s["r_shin"]))
        out.append((joint(side + "Foot"), joint(side + "ToeBase"), s["r_foot"]))
    return out


def rest_field(V0, arm_w, hips, hips_z, H):
    """from the rest pose: each vertex's outward direction d (N, 3, in Blender's axes: front -y) and mask. Lateral on the front and the sides, backward on the back."""
    ang = np.degrees(np.arctan2(V0[:, 0] - hips[0], -(V0[:, 1] - hips[1])))              # 0 = front, +-180 = back
    back = sstep(BACK0, BACK1, np.abs(ang))
    dx = np.clip((V0[:, 0] - hips[0]) / (DEAD * H), -1.0, 1.0)
    d = np.stack([dx * (1 - back), back, np.zeros(len(V0))], axis=1)
    d /= np.maximum(np.linalg.norm(d, axis=1), 1e-6)[:, None]
    mask = (1.0 - sstep(hips_z + ZON_UP * H, hips_z + ZOFF_UP * H, V0[:, 2])) * (arm_w < 0.5)
    return d, mask


def push(p, d, mask, caps, s, rest, passes=PASSES):
    """the pushed positions and the distances: `rest` (N,) is each vertex's push at the rest pose, which is its own shape and is taken off"""
    D = np.maximum(push_distance(p, d, caps, s) - rest, 0.0) * mask
    for _ in range(passes - 1):                                    # a vertex that was moved out of one capsule into another leaves that one too (no tent; a vertex that stayed keeps its rest overlaps)
        moved = D > 1e-6
        D = D + push_distance(p + d * D[:, None], d, caps, s, tent_on=False) * mask * moved
    return p + d * D[:, None], D


def bake(coat, arm, P, H, hips_z):
    """write the coat's per-vertex push data (the header says which) and its `coat_push` property; the armature is in REST pose. -> (spec, the rest push (N,), the mask)"""
    import bpy
    from mathutils import Vector
    s = spec(H)
    V0 = np.array([(coat.matrix_world @ v.co)[:] for v in coat.data.vertices])
    gname = {g.index: g.name for g in coat.vertex_groups}
    arm_w = np.array([sum(g.weight for g in v.groups if any(k in gname[g.group] for k in ("Arm", "Hand", "Shoulder"))) for v in coat.data.vertices])
    hips = np.array((arm.matrix_world @ arm.data.bones[P + "Hips"].head_local)[:])
    d, mask = rest_field(V0, arm_w, hips, hips_z, H)
    head = lambda n: np.array((arm.matrix_world @ arm.data.bones[P + n].head_local)[:])
    rest = np.maximum(push_distance(V0, d, capsules(head, s), s), 0.0) * mask
    me = coat.data
    me.materials.clear()                                      # the importer gives a mesh with COLOR_0 a material using it; with one, the exporter writes the colour twice (COLOR_0 and COLOR_1)
    tex = __import__("os").environ.get("COAT_TEX", "")
    if tex:                                                   # the coat's initial texture (tripo_coat_regions): one material with ONLY the image, no vertex colour node (tc.export writes the active colour itself)
        mat = bpy.data.materials.new("coat_tex"); nt = mat.node_tree; bsdf = nt.nodes["Principled BSDF"]
        tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = bpy.data.images.load(__import__("os").path.abspath(tex)); tx.image.colorspace_settings.name = 'sRGB'
        nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 1.0
        me.materials.append(mat)
    for ca in list(me.color_attributes):                      # a re-run (or an importer's "Col") must leave exactly one colour and one extra UV map
        me.color_attributes.remove(ca)
    for layer in list(me.uv_layers)[1:]:
        me.uv_layers.remove(layer)
    ca = me.color_attributes.new("CoatPush", 'FLOAT_COLOR', 'POINT')
    col = np.stack([1.0 - mask, np.clip(rest / REST_SCALE, 0.0, 1.0), np.zeros(len(V0)), np.ones(len(V0))], axis=1)
    ca.data.foreach_set("color", col.ravel().astype(np.float32))
    me.color_attributes.active_color = ca
    uv = me.uv_layers.new(name="CoatPushDir")
    # glTF flips V on export; the direction is stored in the glTF axes: x lateral, y = glTF Z = Blender -y (the front is +1)
    vert = np.array([l.vertex_index for l in me.loops])
    u_, v_ = d[vert, 0], 1.0 - (-d[vert, 1])
    uv.data.foreach_set("uv", np.stack([u_, v_], axis=1).ravel().astype(np.float32))
    for u in me.uv_layers:
        if u.name != "CoatPushDir":
            me.uv_layers.active = u
            break
    coat["coat_push"] = json.dumps(s)
    return s, rest, mask
