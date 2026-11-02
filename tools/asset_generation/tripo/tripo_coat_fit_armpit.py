# tripo_coat_fit_armpit.py — the coat's fine fit, the ARMPITS (ACTOR D96, 2026-11-02: "ajustar as axilas primeiro [...] tem uma dobra nas costas que é do modelo do casaco").
# COAT_BASE's back panel under the yoke is sculpted with pleats, and the sleeve's pull (tripo_coat_fit_relief) deepens them at the armpit. This smooths that panel: a Taubin filter (a Laplacian step, then a slightly larger
# inverse one, so the surface does not shrink) over the coat's own edges, each vertex moved by its own mask: 1 on the back between the waist and the shoulder joint and out to just past the arm, fading to 0 over FADE metres at its edges and
# toward the sleeve (arm weight), so the yoke, the belt, the sleeve and the front are untouched. The two walls of the double wall are separate surfaces of the same mesh, so each smooths on its own side and keeps its thickness.
# Env: ARMPIT_IN (the .blend), ARMPIT_OUT (default in place), ARMPIT_ITERS (12), ARMPIT_FADE (0.03 m), ARMPIT_PRE / ARMPIT_POST (render prefixes).
# Usage: blender -b -P tripo_coat_fit_armpit.py
import os, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector

TAG = "tripo_coat_fit_armpit"
IN = os.environ["ARMPIT_IN"]; OUT = os.environ.get("ARMPIT_OUT", IN)
ITERS, FADE = int(os.environ.get("ARMPIT_ITERS", "12")), float(os.environ.get("ARMPIT_FADE", "0.03"))
LAM, MU = 0.5, -0.53
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
coat = [o for o in bpy.data.objects if o.name.startswith("Outfit_Coat")][0]
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
sk = coat.data.shape_keys
MW = np.array(coat.matrix_world)
W = (MW[:3, :3] @ np.array([v.co[:] for v in sk.key_blocks["Fit"].data]).T).T + MW[:3, 3]
bone = lambda n: np.array((arm.matrix_world @ arm.data.bones["mixamorig:" + n].head_local)[:])
gn = {g.index: g.name for g in coat.vertex_groups}
aw = np.array([sum(g.weight for g in v.groups if any(k in gn[g.group] for k in ("Arm", "Hand", "Shoulder"))) for v in coat.data.vertices])
zlo, zhi = bone("Spine")[2], bone("LeftArm")[2] + 0.03
xmax = abs(bone("LeftArm")[0]) + 0.04
ymid = bone("Spine")[1]                                      # the back is +y (the front is -y)
ss = lambda a, b, x: np.clip((x - a) / (b - a), 0.0, 1.0) ** 2 * (3 - 2 * np.clip((x - a) / (b - a), 0.0, 1.0))
m = (ss(zlo, zlo + FADE, W[:, 2]) * (1 - ss(zhi - FADE, zhi, W[:, 2])) * (1 - ss(xmax - FADE, xmax, np.abs(W[:, 0]))) * ss(ymid, ymid + FADE, W[:, 1]) * (1 - np.clip(aw / 0.5, 0, 1)))
print(f"[{TAG}] mask: {int((m > 0.5).sum())} vertices at full strength, {int((m > 0).sum())} touched (z {zlo:.3f}..{zhi:.3f}, |x| < {xmax:.3f})")
nb = [[] for _ in W]
for e in coat.data.edges:
    a, b = e.vertices; nb[a].append(b); nb[b].append(a)


def step(P, f):
    Q = P.copy()
    for i in np.nonzero(m > 0)[0]:
        if nb[i]:
            Q[i] = P[i] + f * m[i] * (P[nb[i]].mean(0) - P[i])
    return Q


def render(prefix):
    if not prefix:
        return
    import math
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
    sc.render.resolution_x, sc.render.resolution_y = 800, 800; sc.view_settings.view_transform = 'Standard'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (0.9, 0.4, 0.05, 1) if o is coat else (0.55, 0.6, 0.7, 1); o.hide_render = o.name in ("Body_Hair", "Icosphere")
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector(bone("LeftArm") - np.array([0.03, 0, 0.09]))
    for tag, az in (("back", 180), ("back3", 215), ("side", 270), ("front3", 325)):
        a = math.radians(az); d = Vector((math.sin(a), -math.cos(a), 0.1)).normalized()
        cam.ortho_scale = 0.34; co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{prefix}_{tag}.png"; bpy.ops.render.render(write_still=True)


P = W.copy()
for _ in range(ITERS):
    P = step(step(P, LAM), MU)
# the right armpit mirrors the left: the mask above used |x|, the filter has no side
print(f"[{TAG}] largest move {np.linalg.norm(P - W, axis=1).max() * 1000:.1f} mm over {ITERS} iterations")
Wi = np.linalg.inv(MW); newco = (Wi[:3, :3] @ P.T).T + Wi[:3, 3]
bpy.context.view_layer.objects.active = coat
for o in bpy.data.objects:
    o.select_set(False)
coat.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')                          # a shape key written by foreach_set is not saved: the edit mesh writes keys and mesh together (see tripo_coat_fit_relief.py)
bm = bmesh.from_edit_mesh(coat.data); bm.verts.ensure_lookup_table()
lays = [bm.verts.layers.shape[k.name] for k in sk.key_blocks]
for v, q in zip(bm.verts, newco):
    for lay in lays:
        v[lay] = Vector(q)
    v.co = Vector(q)
bmesh.update_edit_mesh(coat.data)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
render(os.environ.get("ARMPIT_POST", ""))
print(f"[{TAG}] wrote {OUT}")
