# hero_lean_export.py — Re-export the Quaternius Universal Base Superhero {Male,Female} as a lean GLB: colour texture only (1024 px JPEG), normal / roughness dropped.
# Dev tool, 2026-10-20 (CHARACTER_MASTER_PLAN viability work). Needs: HERO_REPO (repo root with trailing /), HERO_UBC_DIR (the unzipped
# Quaternius Universal Base Characters [Standard] "Godot - UE" folder, trailing /), HERO_UAL_GLB (UAL1_Standard.glb). Both packs are CC0;
# see ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/ATTRIBUTION.txt. Output lands in that folder (git-ignored).
import os
import bpy, sys
Q=""+os.environ.get("HERO_UBC_DIR","")+""
OUT=""+os.environ.get("HERO_REPO","")+"ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/"
import os; os.makedirs(OUT,exist_ok=True)
for sex in ("Male","Female"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=Q+f"Superhero_{sex}_FullBody.gltf")
    # keep only the colour texture, wired straight into Base Color; drop everything else
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        nt=mat.node_tree
        bsdf=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
        col=[n for n in nt.nodes if n.type=='TEX_IMAGE' and n.image and any(k in n.image.name for k in ("Dark","BaseColor","Brown"))]
        print("MAT",mat.name,[n.image.name for n in nt.nodes if n.type=='TEX_IMAGE'],"->",[n.image.name for n in col])
        for n in list(nt.nodes):
            if n.type=='TEX_IMAGE' and n not in col: nt.nodes.remove(n)
        if bsdf and col:
            for l in list(bsdf.inputs['Base Color'].links): nt.links.remove(l)
            nt.links.new(col[0].outputs['Color'],bsdf.inputs['Base Color'])
    for img in bpy.data.images:
        if img.size[0]>1024: img.scale(1024,1024)
    bpy.ops.export_scene.gltf(filepath=OUT+f"superhero_{sex.lower()}_lean.glb",export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=False,export_apply=False)
    print("DONE",sex)
