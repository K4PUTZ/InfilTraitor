# tripo_surface.py — the Agent's pieces in their FABRIC (ACTOR D87, 2026-11-02, Director: the hat in the coat's leather, fabrics for the shirt, trousers and tie, the shoes in a darker leather).
# For each piece named in AGENT_SURFACE.json (the Agent's surface per slot: palette colour x the grayscale detail map of its material, `tile` repeats per UV unit) it paints a PNG on the
# piece's own UVs (a piece with none, the hat, is smart-projected) and gives the piece a material with only that image; tc.export embeds it. The coated variants (the masked shirt /
# trousers) share their slot's fabric. The coat has its own step (tripo_coat_regions + tripo_coat_push). The board's shader draws albedo x texture: there is no sheen in it yet.
# TX-1 (2026-11-06): the head, hands, hair, belt and buckle too (the game drew them white); a piece whose entry has `map` takes that PNG
# (SF_MAP_SUFFIX, e.g. _light, picks the LIGHT's own map).
# Env: SF_IN, SF_OUT, SF_FIGURE (female | male), SF_MAPS (PNG folder), SF_PIECES (comma list, default the five below), SF_SPEC, SF_DETAIL, SF_RES (512).  Usage: blender -b -P tripo_surface.py
import json, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import tripo_common as tc

TAG = "tripo_surface"
arm, P, B, meshes = tc.load(TAG, os.environ["SF_IN"])
FIG, MAPS = os.environ["SF_FIGURE"], os.environ["SF_MAPS"]
SPEC = json.load(open(os.environ.get("SF_SPEC", "ASSETS/MODELS/official/AGENT_SURFACE.json")))[FIG]
DET = os.environ.get("SF_DETAIL", "ASSETS/MODELS/official/detail"); RES = int(os.environ.get("SF_RES", "512"))
PIECES = os.environ.get("SF_PIECES", "Outfit_Hat,Outfit_Shirt,Outfit_Trousers,Outfit_Tie,Outfit_Shoes,Outfit_Belt,Outfit_Buckle,Body_Head,Body_Hands,Body_Hair").split(",")
made = {}
for o in meshes:
    key = o.name.split(".")[0]
    if key.endswith("_Coated"):
        key = key[:-len("_Coated")]
    if key == "Body_Hair_Hat":                                        # the hair cut under the hat shares the hair's surface
        key = "Body_Hair"
    if key not in PIECES or key not in SPEC:
        continue
    sp = SPEC[key]
    if not o.data.uv_layers:                                          # the hat has no UVs: a smart projection (a rigid piece, the grain only needs a layout)
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')
        print(f"[{TAG}] {o.name}: no UVs, smart-projected")
    if key not in made and "map" in sp:                               # a painted piece (the head, D87 (3)): its own map, already on its UVs
        png = os.path.join(MAPS, os.path.basename(sp["map"]).replace(".png", os.environ.get("SF_MAP_SUFFIX", "") + ".png"))
        if not os.path.isfile(png):
            tc.fail(TAG, f"{key}: painted map {png} missing")
        made[key] = png
        print(f"[{TAG}] {key}: painted {png}")
    if key not in made:
        col = np.array([int(sp["colour"][i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0
        det = tc.detail_tiled(os.path.join(DET, sp["material"] + ".png"), RES, float(sp.get("tile", 12)))
        png = os.path.join(MAPS, f"{FIG}_{key}.png")
        tc.write_png(png, (np.clip(col[None, None, :] * det[:, :, None], 0, 1) * 255 + 0.5).astype(np.uint8))
        made[key] = png
        print(f"[{TAG}] {key}: {sp['material']} {sp['colour']} x{sp.get('tile', 12)} -> {png}")
    o.data.materials.clear(); o.data.materials.append(tc.textured_material(f"{key}_tex", made[key]))
tc.export(os.environ["SF_OUT"], meshes, arm)
