# tripo_coat_fit_round.py — ROUND the coat's armpits in the T-pose working file (ACTOR D96, 2026-11-02, Director: "tirar essas entradas tão agudas no casaco, e deixar mais redonda a curva nas axilas").
# In the T the coat's side meets the sleeve's underside at an acute notch. A Taubin filter (no shrink) over the coat's edges, strength 1 at ROUND_C (just under each arm joint, ROUND_DX toward the arm) falling to 0 at ROUND_R1, fills a concave V and rounds
# it: both walls of the double wall smooth on their own side. The lapel's `Rigid` pin is honoured. Works on a `COAT_FIT_<FIG>_T.blend` (the coat is a plain mesh there: its vertices ARE the pose); the way back to the A file is `tripo_fit_from_tpose.py`.
# Env: ROUND_OBJ (Outfit_Coat | Outfit_Shirt), ROUND_IN, ROUND_OUT (default in place), ROUND_ITERS (30), ROUND_R0 (0.06), ROUND_R1 (0.15), ROUND_DOWN (0.06 m under the joint), ROUND_DX (0.03), ROUND_RENDER (a prefix: a close front render).   Usage: blender -b -P tripo_coat_fit_round.py
import math, os
import numpy as np
import bpy
from mathutils import Vector

TAG = "tripo_coat_fit_round"
IN = os.environ["ROUND_IN"]; OUT = os.environ.get("ROUND_OUT", IN)
ITERS = int(os.environ.get("ROUND_ITERS", "30")); R0, R1 = float(os.environ.get("ROUND_R0", "0.06")), float(os.environ.get("ROUND_R1", "0.15"))
DOWN, DX = float(os.environ.get("ROUND_DOWN", "0.06")), float(os.environ.get("ROUND_DX", "0.03"))
LAM, MU = 0.5, -0.53


def render(prefix):
    if not prefix:
        return
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
    sc.render.resolution_x, sc.render.resolution_y = 1000, 600; sc.view_settings.view_transform = 'Standard'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (0.9, 0.4, 0.05, 1) if o is coat else (0.55, 0.6, 0.7, 1); o.hide_render = o.name == "Icosphere"
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 0.9; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector((0, 0, 0.74)); d = Vector((0, -1, 0.05)).normalized()
    co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f"{prefix}_front.png"; bpy.ops.render.render(write_still=True)


bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
OBJ = os.environ.get("ROUND_OBJ", "Outfit_Coat")          # the piece to round: the coat (default) or the shirt ("Outfit_Shirt", Director 2026-11-02: the shirt's armpit notch in the T)
coat = [o for o in bpy.data.objects if o.name.startswith(OBJ)][0]
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
render(os.environ.get("ROUND_PRE", ""))
MW = np.array(coat.matrix_world)
W = (MW[:3, :3] @ np.array([v.co[:] for v in coat.data.vertices]).T).T + MW[:3, 3]
rigid = np.zeros(len(W)); vg = coat.vertex_groups.get("Rigid")
if vg:
    for v in coat.data.vertices:
        for g in v.groups:
            if g.group == vg.index:
                rigid[v.index] = g.weight
m = np.zeros(len(W))
for sx, side in ((1.0, "Left"), (-1.0, "Right")):
    j = np.array((arm.matrix_world @ arm.data.bones[f"mixamorig:{side}Arm"].head_local)[:])
    c = j + np.array([sx * DX, 0.0, -DOWN])
    t = np.clip((R1 - np.linalg.norm(W - c, axis=1)) / (R1 - R0), 0, 1); m = np.maximum(m, t * t * (3 - 2 * t))
m *= (1 - rigid)
print(f"[{TAG}] {int((m > 0.5).sum())} vertices at full strength, {int((m > 0).sum())} touched")
nb = [[] for _ in W]
for e in coat.data.edges:
    a, b = e.vertices; nb[a].append(b); nb[b].append(a)
# a vertex averages only with neighbours that face its way (ROUND_NORMAL: the least dot of the two normals): on a thin piece whose layers lie close (the shirt's sleeve against its torso) a plain average pulls one layer into the other and tears it
THR = float(os.environ.get("ROUND_NORMAL", "-1"))
if THR > -1:
    N_ = np.array([(coat.matrix_world.to_3x3() @ v.normal)[:] for v in coat.data.vertices])
    nb = [[j for j in l if N_[i] @ N_[j] >= THR] for i, l in enumerate(nb)]
idx = np.nonzero(m > 0)[0]


def step(P, f):
    Q = P.copy()
    for i in idx:
        if nb[i]:
            Q[i] = P[i] + f * m[i] * (P[nb[i]].mean(0) - P[i])
    return Q


P = W.copy()
for _ in range(ITERS):
    P = step(step(P, LAM), MU)
print(f"[{TAG}] largest move {np.linalg.norm(P - W, axis=1).max() * 1000:.1f} mm over {ITERS} iterations")
Wi = np.linalg.inv(MW); newco = (Wi[:3, :3] @ P.T).T + Wi[:3, 3]
coat.data.vertices.foreach_set("co", newco.ravel().astype(np.float32)); coat.data.update()    # a plain mesh here (no shape key), so this is saved
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
render(os.environ.get("ROUND_RENDER", ""))
print(f"[{TAG}] wrote {OUT}")
