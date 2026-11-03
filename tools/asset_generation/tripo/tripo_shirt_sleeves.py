# tripo_shirt_sleeves.py — the shirt's SLEEVES drawn in slightly toward the arms (ACTOR D96, 2026-11-02, Director: "encolhendo levemente toda a camisa pra dentro dos braços, desde os ombros até os punhos. Não mexer no chest",
# so the coat's sleeves need not be widened so much). Each shirt vertex moves toward the nearest point of its arm's axis (the Arm -> ForeArm -> Hand polyline of the skeleton's REST pose) by SLV_SHRINK of its distance, scaled by its own
# arm weight (Arm / ForeArm / Hand of that side, smoothstep 0.35 .. 0.85): the chest, whose vertices carry no arm weight, does not move, and the shoulder ramps in with the weights. Works on the rest pose of whatever file it reads: a
# GLB (a `tripo_assemble` output; the build runs it right after the assemble, before the dress) or a `.blend` (the hand-fit files, in place).
# Env: SLV_IN (.glb or .blend), SLV_OUT (default: in place for a .blend), SLV_SHRINK (0.10), SLV_RENDER (optional prefix: a front render of the sleeves).   Usage: blender -b -P tripo_shirt_sleeves.py
import math, os, sys
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_common as tc
from mathutils import Vector

TAG = "tripo_shirt_sleeves"
IN = os.environ["SLV_IN"]; OUT = os.environ.get("SLV_OUT", IN if IN.endswith(".blend") else "")
K = float(os.environ.get("SLV_SHRINK", "0.10"))
IS_BLEND = IN.endswith(".blend")
if IS_BLEND:
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(IN))
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; meshes = None
else:
    arm, P_, B_, meshes = tc.load(TAG, IN)
arm.data.pose_position = 'REST'
shirt = bpy.data.objects.get("Outfit_Shirt")
if shirt is None:
    tc.fail(TAG, f"{IN} has no Outfit_Shirt")
P = "mixamorig:"


def render(prefix):
    if not prefix:
        return
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_xray = False
    sc.render.resolution_x, sc.render.resolution_y = 1000, 500; sc.view_settings.view_transform = 'Standard'
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (0.6, 0.65, 0.75, 1); o.hide_render = o.name.startswith("Outfit_Coat") or o.name == "Icosphere"
    cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = 1.0; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    c = Vector((0, 0, 0.7)); d = Vector((0, -1, 0.08)).normalized()
    co.location = c + d * 6; co.rotation_euler = (c - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f"{prefix}_front.png"; bpy.ops.render.render(write_still=True)


render(os.environ.get("SLV_PRE", ""))
gn = {g.index: g.name for g in shirt.vertex_groups}
V = np.array([(shirt.matrix_world @ v.co)[:] for v in shirt.data.vertices])
new = V.copy(); total = 0
for side in ("Left", "Right"):
    pts = [np.array((arm.matrix_world @ arm.data.bones[f"{P}{side}{j}"].head_local)[:]) for j in ("Arm", "ForeArm", "Hand")]
    aw = np.array([sum(g.weight for g in v.groups if gn[g.group] in (f"{P}{side}Arm", f"{P}{side}ForeArm", f"{P}{side}Hand")) for v in shirt.data.vertices])
    t_ = np.clip((aw - 0.35) / 0.5, 0, 1); f = t_ * t_ * (3 - 2 * t_)
    for i in np.nonzero(f > 0)[0]:
        best = None
        for a, b in zip(pts[:-1], pts[1:]):
            ab = b - a; t = float(np.clip((V[i] - a) @ ab / (ab @ ab), 0, 1)); c = a + t * ab; d = float(np.linalg.norm(V[i] - c))
            if best is None or d < best[0]:
                best = (d, c)
        new[i] = best[1] + (V[i] - best[1]) * (1 - K * f[i]); total += 1
    print(f"[{TAG}] {side}: {int((f > 0).sum())} sleeve vertices drawn in (up to {K * 100:.0f} % of their distance to the arm's axis)")
Wi = np.linalg.inv(np.array(shirt.matrix_world)); co_ = (Wi[:3, :3] @ new.T).T + Wi[:3, 3]
shirt.data.vertices.foreach_set("co", co_.ravel().astype(np.float32)); shirt.data.update()
bpy.context.view_layer.update()
if IS_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT))
else:
    tc.export(OUT, meshes, arm)
render(os.environ.get("SLV_RENDER", ""))
print(f"[{TAG}] max move {np.linalg.norm(new - V, axis=1).max() * 1000:.1f} mm; wrote {OUT}")
