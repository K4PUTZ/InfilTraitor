# tripo_sleeve_root_close.py — close the sleeve's open root in the T pose (ACTOR D97, 2026-11-03, Director: "tem um buraco ali, na área vermelha", the male's right armpit, seen from the side).
# The shirt's sleeves are tubes OPEN at the shoulder end; in the A rest that end lies inside the torso and nothing shows. Skinned to the arm alone, in the T it turns away with the arm and the opening shows under it (the male's loops: two per side, arm weight 0.9-1.0, ~8 cm).
# Per side: the boundary loops whose places are bound to the arm (mean arm weight > 0.8) near the shoulder are grouped; the places within DOME (m) along the arm of the loop's plane, and within 1.7 loop radii of its axis, have their distance to the axis scaled by sqrt(1 - ((DOME - s) / DOME)^2): 0 at the plane (closed to a point),
# 1 at DOME (untouched), the profile of a sphere; what lies behind the plane collapses onto the axis (inside the torso). Places are welded by their A position (a copy of a place moves with it). The movement is mostly inside the torso: the visible surface changes by a few mm.
# Works IN PLACE on a T file (plain mesh). Env: TC_IN (T .blend), TC_REF (the A .blend), TC_DOME (0.04), TC_SIDES ("1,-1": +1 = the figure's left arm, +x).   Usage: blender -b -P tripo_sleeve_root_close.py
import os
from collections import defaultdict
import numpy as np
import bpy

TAG = "tripo_sleeve_root_close"
DOME = float(os.environ.get("TC_DOME", "0.04"))
SIDES = [float(v) for v in os.environ.get("TC_SIDES", "1,-1").split(",")]
OBJ = "Outfit_Shirt"
ARM = ("mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand", "mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand")


def world_positions(o):
    mw = np.array(o.matrix_world)
    return np.array([v.co[:] for v in o.data.vertices]) @ mw[:3, :3].T + mw[:3, 3]


bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["TC_REF"]))
A = world_positions(bpy.data.objects[OBJ])
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["TC_IN"]))
o = bpy.data.objects[OBJ]; me = o.data
T = world_positions(o)
names = {g.index: g.name for g in o.vertex_groups}
a_own = np.array([min(sum(g.weight for g in v.groups if names[g.group] in ARM), 1.0) for v in me.vertices])
key = np.round(A * 1e5).astype(np.int64)
_, place = np.unique(key, axis=0, return_inverse=True); place = place.ravel(); NP = place.max() + 1
PT = np.zeros((NP, 3)); pw = np.zeros(NP); c = np.zeros(NP)
np.add.at(PT, place, T); np.add.at(pw, place, a_own); np.add.at(c, place, 1); PT /= c[:, None]; pw /= c
cnt = defaultdict(int)
for p in me.polygons:
    vs = [place[i] for i in p.vertices]
    for k in range(len(vs)):
        a, b = vs[k], vs[(k + 1) % len(vs)]
        if a != b:
            cnt[(min(a, b), max(a, b))] += 1
adj = defaultdict(list)
for (a, b), n in cnt.items():
    if n == 1:
        adj[a].append(b); adj[b].append(a)
seen = set(); loops = []
for s in adj:
    if s in seen:
        continue
    st = [s]; comp = []
    while st:
        u = st.pop()
        if u in seen:
            continue
        seen.add(u); comp.append(u); st += adj[u]
    loops.append(comp)
move = np.zeros((NP, 3))
for sx in SIDES:
    roots = [l for l in loops if len(l) >= 6 and pw[l].mean() > 0.8 and 0.07 < sx * PT[l, 0].mean() < 0.16 and 0.74 < PT[l, 2].mean() < 0.88]
    if not roots:
        print(f"[{TAG}] side {sx:+.0f}: no sleeve root loop found"); continue
    pts = np.concatenate([PT[l] for l in roots])
    cy, cz = pts[:, 1].mean(), pts[:, 2].mean()
    s0 = (sx * pts[:, 0]).min()
    rad = np.linalg.norm(pts[:, 1:] - np.array([cy, cz]), axis=1).max()
    s = sx * PT[:, 0] - s0
    r = PT[:, 1:] - np.array([cy, cz]); rn = np.linalg.norm(r, axis=1)
    sel = (pw > 0.5) & (s < DOME) & (s > -0.06) & (sx * PT[:, 0] > 0.0) & (rn < 1.7 * rad)
    sc = np.clip(s, 0.0, DOME)
    g = np.sqrt(np.clip(1.0 - ((DOME - sc) / DOME) ** 2, 0.0, 1.0)); g[s < 0] = 0.0
    new = PT.copy()
    new[sel, 1:] = np.array([cy, cz]) + r[sel] * g[sel, None]
    move[sel] = (new - PT)[sel]
    print(f"[{TAG}] side {sx:+.0f}: {len(roots)} loop(s), {len(pts)} loop places, radius {rad:.3f}, {int(sel.sum())} places moved (largest {np.linalg.norm(move[sel], axis=1).max() * 1000:.1f} mm)")
newT = T + move[place]
mw = np.array(o.matrix_world); inv = np.linalg.inv(mw)
me.vertices.foreach_set("co", ((newT - mw[:3, 3]) @ inv[:3, :3].T).ravel().astype(np.float32)); me.update()
bpy.ops.wm.save_mainfile()
print(f"[{TAG}] wrote {os.environ['TC_IN']}")
