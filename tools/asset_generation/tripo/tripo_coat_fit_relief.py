# tripo_coat_fit_relief.py — the coat's FINE FIT after the Director's hand fit (ACTOR D96, 2026-11-02: "ajuste fino nas areas que estão atravessando o casaco, começando pelos tríceps. Vamos puxar as paredes duplas do casaco um pouco pra fora").
# Reads the Director's saved `COAT_FIT_<FIG>.blend` (his sculpt is in the coat's Basis and Fit keys, equal) and, on each ARM, pulls the coat's walls OUT where the body's sleeve comes through them: around the arm's axis (the Arm -> ForeArm bones) the coat's vertices are binned
# by angle and by the position along the arm; a bin's push is the deepest the sleeve's OUTER surface (a ray from the axis, the last hit) reaches into the coat's inner wall, plus a small gap, capped; EVERY vertex of the bin (both walls, so the double wall keeps its
# thickness and its folds) moves radially by it; the grid is dilated and smoothed so no ridge is cut, and faded at the ends of the upper arm. Writes the new positions into Basis, Fit and the mesh (the key holds absolute coordinates).
# Env: RELIEF_IN (the .blend), RELIEF_OUT (default: in place), RELIEF_GAP (0.003 m), RELIEF_CAP (0.02 m), RELIEF_T0 / RELIEF_T1 (the part of the Arm -> ForeArm span, default 0.25 - 0.95: the triceps, Director's first area), RELIEF_PRE / RELIEF_POST (render prefixes).
# Usage: blender -b -P tripo_coat_fit_relief.py
import math, os, sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAG = "tripo_coat_fit_relief"
IN = os.environ["RELIEF_IN"]; OUT = os.environ.get("RELIEF_OUT", IN)
GAP, CAP = float(os.environ.get("RELIEF_GAP", "0.003")), float(os.environ.get("RELIEF_CAP", "0.02"))
T0, T1 = float(os.environ.get("RELIEF_T0", "0.25")), float(os.environ.get("RELIEF_T1", "0.95"))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
coat = [o for o in bpy.data.objects if o.name.startswith("Outfit_Coat")][0]
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
sk = coat.data.shape_keys
MW = np.array(coat.matrix_world)
fit = np.array([v.co[:] for v in sk.key_blocks["Fit"].data])
W = (MW[:3, :3] @ fit.T).T + MW[:3, 3]


def render(prefix):
    if not prefix:
        return
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = True; sh.xray_alpha = 0.45
    sc.render.resolution_x, sc.render.resolution_y = 800, 900; sc.view_settings.view_transform = 'Standard'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (1.0, 0.45, 0.05, 1.0) if o is coat else (0.62, 0.62, 0.62, 1.0)
            o.hide_render = o.name in ("Body_Hair", "Icosphere")
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    lh = arm.matrix_world @ arm.data.bones["mixamorig:LeftArm"].head_local
    rh = arm.matrix_world @ arm.data.bones["mixamorig:RightArm"].head_local
    for tag, az, ctr, scale in (("left_back", 215, lh - Vector((0, 0, 0.12)), 0.6), ("left_side", 270, lh - Vector((0, 0, 0.12)), 0.6),
                                ("right_back", 145, rh - Vector((0, 0, 0.12)), 0.6), ("right_side", 90, rh - Vector((0, 0, 0.12)), 0.6)):
        a = math.radians(az); d = Vector((math.sin(a), -math.cos(a), 0.15)).normalized()
        cam.ortho_scale = scale; co.location = ctr + d * 6; co.rotation_euler = (ctr - co.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{prefix}_{tag}.png"; bpy.ops.render.render(write_still=True)


render(os.environ.get("RELIEF_PRE", ""))
# the body that must not come through: the shirt (its sleeves are the arms' skin here)
shirt = bpy.data.objects["Outfit_Shirt"]
SV = np.array([(shirt.matrix_world @ v.co)[:] for v in shirt.data.vertices]); shirt.data.calc_loop_triangles()
T = BVHTree.FromPolygons([tuple(p) for p in SV], [tuple(t.vertices) for t in shirt.data.loop_triangles])
gn = {g.index: g.name for g in coat.vertex_groups}
NA, NT = 32, 20
total = 0.0
for side in ("Left", "Right"):
    a0 = np.array((arm.matrix_world @ arm.data.bones[f"mixamorig:{side}Arm"].head_local)[:]); a1 = np.array((arm.matrix_world @ arm.data.bones[f"mixamorig:{side}ForeArm"].head_local)[:])
    ax = a1 - a0; L = np.linalg.norm(ax); u = ax / L
    aw = np.array([sum(g.weight for g in v.groups if side in gn[g.group] and "Arm" in gn[g.group]) for v in coat.data.vertices])
    p = (W - a0) @ u / L                                    # position along the span
    sel = np.nonzero((aw >= 0.5) & (p > T0 - 0.15) & (p < T1 + 0.15))[0]
    if not len(sel):
        continue
    ref = np.cross(u, [0, 0, 1.0]); ref /= np.linalg.norm(ref); ref2 = np.cross(u, ref)
    radial = (W[sel] - a0) - np.outer((W[sel] - a0) @ u, u); r = np.linalg.norm(radial, axis=1); rh_ = radial / np.maximum(r, 1e-9)[:, None]
    ang = np.arctan2(rh_ @ ref2, rh_ @ ref); ia = ((ang + math.pi) / (2 * math.pi) * NA).astype(int) % NA
    it = np.clip(((p[sel] - (T0 - 0.15)) / (T1 - T0 + 0.30) * NT).astype(int), 0, NT - 1)
    need = np.zeros((NT, NA)); seen = np.zeros((NT, NA), bool)
    for j, i in enumerate(sel):
        o = Vector(a0 + u * p[i] * L); d = Vector(rh_[j]); hit_r = 0.0; org = o
        for _ in range(8):
            h = T.ray_cast(org, d, 0.4)
            if h[0] is None:
                break
            hit_r = max(hit_r, (h[0] - o).length); org = h[0] + d * 1e-5
        n_ = hit_r + GAP - r[j]
        need[it[j], ia[j]] = max(need[it[j], ia[j]], n_); seen[it[j], ia[j]] = True
    need = np.clip(need, 0.0, CAP)
    for _ in range(2):                                      # dilate (the neighbours' 70 %), then blur: a push reaches round its bin, no ridge
        pad = np.pad(need, ((1, 1), (0, 0)), mode='edge')
        nb = np.maximum.reduce([np.roll(pad, s, axis=1)[dt:dt + NT] for s in (-1, 0, 1) for dt in (0, 1, 2)])
        need = np.maximum(need, nb * 0.7)
    for _ in range(2):
        pad = np.pad(need, ((1, 1), (0, 0)), mode='edge')
        need = (pad[:-2] + 2 * pad[1:-1] + pad[2:]) / 4.0; need = (np.roll(need, 1, 1) + 2 * need + np.roll(need, -1, 1)) / 4.0
    moved = 0
    for j, i in enumerate(sel):
        t = p[i]; fade = float(np.clip(min((t - (T0 - 0.15)) / 0.15, (T1 + 0.15 - t) / 0.15), 0.0, 1.0)); fade = fade * fade * (3 - 2 * fade)
        s_ = need[it[j], ia[j]] * fade
        if s_ > 1e-5:
            W[i] += rh_[j] * s_; moved += 1; total = max(total, s_)
    print(f"[{TAG}] {side} arm: {moved} of {len(sel)} sleeve vertices pulled out, largest {total * 1000:.1f} mm")
Wi = np.linalg.inv(MW)
newco = (Wi[:3, :3] @ W.T).T + Wi[:3, 3]
# written through the edit mesh: a foreach_set on a shape key's data holds in the session but is NOT saved (measured 2026-11-02, Blender 5.2: the file came back unchanged); the edit mesh writes the keys and the mesh together
import bmesh
bpy.context.view_layer.objects.active = coat
for o in bpy.data.objects:
    o.select_set(False)
coat.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(coat.data)
bm.verts.ensure_lookup_table()
lays = [bm.verts.layers.shape[k.name] for k in sk.key_blocks]
for v, q in zip(bm.verts, newco):
    for lay in lays:
        v[lay] = Vector(q)
    v.co = Vector(q)
bmesh.update_edit_mesh(coat.data)
bpy.ops.object.mode_set(mode='OBJECT')
back = np.array([v.co[:] for v in sk.key_blocks['Fit'].data]); print(f"[{TAG}] key readback: max change {abs(back - fit).max() * 1000:.1f} mm; asked {abs(newco - fit).max() * 1000:.1f} mm")
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
render(os.environ.get("RELIEF_POST", ""))
print(f"[{TAG}] wrote {OUT}")
