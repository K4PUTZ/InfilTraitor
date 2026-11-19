# tripo_head_edit_file.py — a working file for the Director to rebuild the female's skull top by hand (2026-11-05: "copia a cabeça do male e coloca no
# arquivo da female ao lado da cabeça dela. Vou editar manualmente o topo e depois emendamos no modelo base").
# Opens ASSETS/MODELS/actors/agent/female/base/AGENT_FEMALE_A.blend (never saved over), appends the male's Body_Head from AGENT_MALE_A.blend as a free mesh
# (`Body_Head_Male`: no armature, no parent, no vertex groups), set HE_SIDE metres to her right (+X, default 0.30) at her height, and saves HE_OUT
# (default ASSETS/MODELS/actors/agent/female/work/HEAD_EDIT_FEMALE.blend). Usage (repo root): blender -b --python-exit-code 1 -P tools/asset_generation/tripo/tripo_head_edit_file.py
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
import model_paths as mp  # where every model lives (ASSETS/MODELS layout)
import os
import bpy
from mathutils import Matrix
OUT = os.path.abspath(os.environ.get("HE_OUT", mp.agent("female", "work", "HEAD_EDIT_FEMALE.blend")))
SIDE = float(os.environ.get("HE_SIDE", "0.30"))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(mp.agent("female", "base", "AGENT_FEMALE_A.blend")))
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(os.path.abspath(mp.agent("male", "base", "AGENT_MALE_A.blend"))) as (src, dst):
    dst.objects = ["Body_Head"]
m = dst.objects[0]
world = m.matrix_world.copy()
o = bpy.data.objects.new("Body_Head_Male", m.data.copy())
bpy.context.scene.collection.objects.link(o)
o.data.transform(world)            # his rest shape in world space, then a plain object
o.vertex_groups.clear()
o.matrix_world = Matrix.Translation((SIDE, 0.0, 0.0))
print(f"[tripo_head_edit_file] Body_Head_Male ({len(o.data.vertices)} verts) set {SIDE} m to her side -> {OUT}")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
