# tripo_hat_fit_file.py — a working file where the Director seats the hat on the D99 base by hand (2026-11-05).
# Opens ASSETS/MODELS/base/AGENT_<FIG>_A.blend (never saved over), imports the hat of the dressed FULL Agent (official/AGENT_<FIG>.glb, `Outfit_Hat`)
# as a FREE mesh (no armature, no parent, its world transform kept) so it can be moved, and saves the result as HF_OUT
# (default ASSETS/MODELS/fit/HAT_FIT_<FIG>.blend). The hat's skin to the head is redone by script after the Director's edit.
# Env: HF_FIG (female | male), HF_OUT. Usage: blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_hat_fit_file.py
import os, sys
import bpy
FIG = os.environ.get("HF_FIG", "")
if FIG not in ("female", "male"):
    sys.exit("[tripo_hat_fit_file] HF_FIG must be female or male")
OUT = os.path.abspath(os.environ.get("HF_OUT", f"ASSETS/MODELS/fit/HAT_FIT_{FIG.upper()}.blend"))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend"))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.objects.active = None
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(f"ASSETS/MODELS/official/AGENT_{FIG.upper()}.glb"))
new = [o for o in bpy.data.objects if o not in before]
hat = next(o for o in new if o.type == 'MESH' and o.name.startswith("Outfit_Hat"))
mw = hat.matrix_world.copy()
hat.parent = None
hat.matrix_world = mw
for m in list(hat.modifiers):
    hat.modifiers.remove(m)
hat.vertex_groups.clear()
for o in new:
    if o is not hat:
        bpy.data.objects.remove(o, do_unlink=True)
hat.name = "Outfit_Hat"
print(f"[tripo_hat_fit_file] hat at {tuple(round(v, 4) for v in hat.matrix_world.translation)}, {len(hat.data.vertices)} verts -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
