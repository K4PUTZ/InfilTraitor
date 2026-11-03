# tripo_coat_fit_rigid.py — the coat's RIGID LAPEL (ACTOR D96, 2026-11-02, Director: "deixar essa parte da lapela mais rígida, de maneira que não deforme, mesmo se a área em volta for puxada").
# Writes a vertex group `Rigid` on the coat of a `COAT_FIT_<FIG>.blend` and its `_T` twin (the same vertex indices): 1 in the lapel's core, falling to 0 over FALL metres of edge distance outward. The group is a PIN for everything that moves the coat:
# the fine-fit scripts (`tripo_coat_fit_relief.py`, `tripo_coat_fit_armpit.py`) scale their displacement by (1 - Rigid); in Blender's Edit Mode, select the group (Object Data > Vertex Groups > Select) and HIDE it (H) before pulling the sleeves or the
# armpit: hidden vertices are not moved, not even by proportional editing. The lapel = the front, facing -y, above the chest joint (Spine2 - 0.03 H), within |x| < 0.1 H of the centre line, below the collar (the regions script's rule, `tripo_coat_regions.py`).
# Env: RIGID_IN (the A .blend), RIGID_T (its _T twin, optional), RIGID_RENDER (optional prefix: a front render with the group painted red).   Usage: blender -b -P tripo_coat_fit_rigid.py
import math, os
import numpy as np
import bpy
from mathutils import Vector

TAG = "tripo_coat_fit_rigid"
FALL = float(os.environ.get("RIGID_FALL", "0.03"))


def load(path):
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(path))
    return [o for o in bpy.data.objects if o.name.startswith("Outfit_Coat")][0], [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]


def write_group(coat, w):
    vg = coat.vertex_groups.get("Rigid") or coat.vertex_groups.new(name="Rigid")
    vg.remove(list(range(len(w))))
    for i in np.nonzero(w > 1e-3)[0]:
        vg.add([int(i)], float(w[i]), 'REPLACE')


coat, arm = load(os.environ["RIGID_IN"])
bone = lambda n: np.array((arm.matrix_world @ arm.data.bones["mixamorig:" + n].head_local)[:])
sk = coat.data.shape_keys
MW = np.array(coat.matrix_world)
V = (MW[:3, :3] @ np.array([v.co[:] for v in (sk.key_blocks["Fit"].data if sk else coat.data.vertices)]).T).T + MW[:3, 3]
H = V[:, 2].max() - 0.0
zc, zn = bone("Spine2")[2], bone("Neck")[2]
core = (V[:, 2] > zc - 0.03 * H) & (V[:, 2] < zn - 0.01 * H) & (np.abs(V[:, 0]) < 0.1 * H) & (V[:, 1] < bone("Spine")[1] - 0.01)   # the front (-y) of the chest, under the collar
print(f"[{TAG}] core: {int(core.sum())} of {len(V)} vertices (z {zc - 0.03 * H:.3f}..{zn - 0.01 * H:.3f}, |x| < {0.1 * H:.3f})")
# the falloff: edge distance from the core over the coat's own edges
nb = [[] for _ in V]
for e in coat.data.edges:
    a, b = e.vertices; nb[a].append(b); nb[b].append(a)
dist = np.where(core, 0.0, 1e9); frontier = list(np.nonzero(core)[0])
import heapq
pq = [(0.0, int(i)) for i in frontier]; heapq.heapify(pq)
while pq:
    d, i = heapq.heappop(pq)
    if d > dist[i] or d > FALL:
        continue
    for j in nb[i]:
        nd = d + float(np.linalg.norm(V[i] - V[j]))
        if nd < dist[j]:
            dist[j] = nd; heapq.heappush(pq, (nd, j))
t = np.clip(1.0 - dist / FALL, 0.0, 1.0); w = t * t * (3 - 2 * t)
print(f"[{TAG}] group Rigid: {int((w >= 0.999).sum())} at 1, {int((w > 0.001).sum())} touched")
pre = os.environ.get("RIGID_RENDER", "")
if pre:
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
    sc.render.resolution_x, sc.render.resolution_y = 900, 900; sc.view_settings.view_transform = 'Standard'
    # paint the group on a copy of the coat: vertex colour red by weight, shown through the attribute
    me = coat.data
    ca = me.color_attributes.new("RigidShow", 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set("color", np.stack([0.9 + 0.1 * w, 0.4 * (1 - w), 0.05 * (1 - w), np.ones(len(w))], 1).ravel().astype(np.float32))
    sh.color_type = 'VERTEX'
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not coat:
            o.color = (0.55, 0.6, 0.7, 1); o.hide_render = o.name == "Icosphere"
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 0.75; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector((0, 0, 0.66)); d = Vector((0, -1, 0.1)).normalized()
    co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f"{pre}_front.png"; bpy.ops.render.render(write_still=True)
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(os.environ["RIGID_IN"]))     # the colour attribute was only for the picture
    coat, arm = load(os.environ["RIGID_IN"])
write_group(coat, w)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.environ["RIGID_IN"]))
tp = os.environ.get("RIGID_T", "")
if tp:
    coat_t, _ = load(tp)
    assert len(coat_t.data.vertices) == len(w)
    write_group(coat_t, w)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(tp))
print(f"[{TAG}] wrote the Rigid group")
