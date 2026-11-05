# tripo_export_base.py — the D99 base FULL of one figure as a GLB the engine can load, for MEASUREMENT (MOVEMENT MV-4, 2026-11-05).
# The base (`ASSETS/MODELS/base/AGENT_<FIG>_A.blend`, ACTOR D99-D104) carries what the game's LIGHT Agents do not have yet: the coat's corrective
# shape keys (IdleFix / WalkFix / RunFix, D103), the coat's torso skin (D101) and, on the male, the flap skin (D104). No game build reads it
# (`build_agents.sh` still makes the LIGHT ones); this export lets the bench measure what those keys cost on a handset
# (`actor_bench agent_base_<fig>[_nokeys]_clip_<id>`). It keeps the skin and every shape key, no animation, every piece but the importer's
# bone sphere (`Icosphere`). The .blend is opened and never saved (D99/D102: the Director's files).
# TB_KEYS=0 writes the A / B twin instead (`AGENT_<FIG>_BASE_A_NOKEYS.glb`): every shape key applied at its current value (the coat's `Fit` at 1,
# the correctives at 0) and removed, so the coat has the same shape and no keys at all.
# Env: TB_FIG (female | male), TB_KEYS (1 | 0, default 1), TB_OUT (default ASSETS/MODELS/official/AGENT_<FIG>_BASE_A[_NOKEYS].glb).
# Usage (from the repo root): /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_export_base.py
import os
import sys
import bpy

TAG = "tripo_export_base"
FIG = os.environ.get("TB_FIG", "")
if FIG not in ("female", "male"):
    sys.exit(f"[{TAG}] TB_FIG must be female or male")
SRC = os.path.abspath(f"ASSETS/MODELS/base/AGENT_{FIG.upper()}_A.blend")
KEYS = os.environ.get("TB_KEYS", "1") != "0"
OUT = os.path.abspath(os.environ.get("TB_OUT", f"ASSETS/MODELS/official/AGENT_{FIG.upper()}_BASE_A{'' if KEYS else '_NOKEYS'}.glb"))
SKIP = {"Icosphere"}

bpy.ops.wm.open_mainfile(filepath=SRC)
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
if len(arms) != 1:
    sys.exit(f"[{TAG}] expected one armature in {SRC}, found {len(arms)}")
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name not in SKIP]
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in [arms[0]] + meshes:
    o.hide_set(False)          # in memory only: the file is never saved
    o.hide_viewport = False
    o.select_set(True)
if not KEYS:
    for o in meshes:
        if o.data.shape_keys is not None:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
bpy.context.view_layer.objects.active = arms[0]
tris = 0
for o in meshes:
    me = o.data
    tris += sum(len(p.vertices) - 2 for p in me.polygons)
    keys = [(k.name, round(k.value, 3)) for k in me.shape_keys.key_blocks[1:]] if me.shape_keys else []
    print(f"[{TAG}] {o.name:<20} {len(me.vertices):>6} verts {sum(len(p.vertices) - 2 for p in me.polygons):>6} tris keys {keys}")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_skins=True, export_morph=True,
                          export_animations=False, export_apply=False, export_yup=True)
print(f"[{TAG}] wrote {OUT}: {len(meshes)} pieces, {tris} tris, {os.path.getsize(OUT)} bytes")
