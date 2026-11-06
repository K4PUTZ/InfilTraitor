#!/bin/bash
# build_light_base.sh — the LIGHT Agent FROM THE D99 BASE, one figure (ACTOR D106, 2026-11-06). Every step but the last ran by hand that day; this script is that order,
# NOT yet run end to end as one command (run it on one figure and compare with the stage renders before relying on it).
#   fit/HAT_CUT_<FIG>.blend (tripo_hair_brim_cut) -> tripo_hat_skin (hat rigid on Head, the cut hair bound to the hat) -> fit/HAT_SKIN_<FIG>.blend
#   -> tripo_coated_cut (Outfit_Shirt / Trousers / Belt _Coated, tripo_dress's rules) -> fit/COATED_<FIG>.blend
#   -> tripo_lod_base (every piece to its budget, the coat's corrective keys carried) -> tripo_uv -> tripo_head_map -> tripo_pockets -> tripo_back_trim
#   -> tripo_coat_back_out -> tripo_surface -> tripo_coat_regions -> tripo_coat_push.
# tripo_skirt_fix and tripo_chains_to_hips are NOT run: the base has no skirt chains and no hem bound to the hands (measured 2026-11-06), and skirt_fix would rewrite the
# coat's own skin (D101 / D104).
# Out: <work_dir>/<fig>_LIGHT_D106.glb. Nothing is written to ASSETS/MODELS/official/: installing it is a separate decision.
# Usage, from the repo root: tools/asset_generation/tripo/build_light_base.sh <female|male> <work_dir>
set -e
f="${1:?usage: build_light_base.sh <female|male> <work_dir>}"; W="${2:?usage: build_light_base.sh <female|male> <work_dir>}"
F=$(echo "$f" | tr a-z A-Z); B=/Applications/Blender.app/Contents/MacOS/Blender; T=tools/asset_generation/tripo; M=ASSETS/MODELS
mkdir -p "$W/painted"
step() { local log="$1"; shift; env "$@" "$B" -b --python-exit-code 1 -P "$T/$SCRIPT" > "$W/${f}_$log.txt" 2>&1 || { echo "ERROR in $log"; tail -15 "$W/${f}_$log.txt"; exit 1; }; echo "ok $log"; }
cp -R "$M/official/painted/." "$W/painted/"      # the maps first: the head step then writes its own light map over the old one
SCRIPT=tripo_hat_skin.py step 0hat HS_FIG=$f
SCRIPT=tripo_coated_cut.py step 0coated CC_FIG=$f
SCRIPT=tripo_lod_base.py step 0lod LB_FIG=$f LB_IN=$M/fit/COATED_$F.blend LB_OUT=$W/${f}_light_base.glb LB_BLEND=$W/${f}_light_base.blend
SCRIPT=tripo_uv.py step uv UV_IN=$W/${f}_light_base.glb UV_OUT=$W/${f}_1uv.glb
# the head wears its painted master on FaceUV (CHARACTER §7a TX-4; the master: tripo_face_uv.py -> tripo_face_paint.py, or the Director's retouch)
SCRIPT=tripo_face_apply.py step head FA_IN=$W/${f}_1uv.glb FA_OUT=$W/${f}_2head.glb FA_PARAMS=$M/official/painted/${f}_faceuv.json FA_MASTER=$M/official/painted/${f}_face_master.png FA_MAP_OUT=$W/painted/${f}_head_light.png FA_RES=512
SCRIPT=tripo_pockets.py step pockets PK_IN=$W/${f}_2head.glb PK_OUT=$W/${f}_3pk.glb
SCRIPT=tripo_back_trim.py step trim BT_IN=$W/${f}_3pk.glb BT_OUT=$W/${f}_4trim.glb
SCRIPT=tripo_coat_back_out.py step out BO_IN=$W/${f}_4trim.glb BO_OUT=$W/${f}_5out.glb
SCRIPT=tripo_surface.py step surface SF_IN=$W/${f}_5out.glb SF_OUT=$W/${f}_6surf.glb SF_FIGURE=$f SF_MAPS=$W/painted SF_MAP_SUFFIX=_light
SCRIPT=tripo_coat_regions.py step regions CR_IN=$W/${f}_6surf.glb CR_MAP=$W/painted/${f}_coat_light.png CR_PALETTE=${CR_PALETTE:-ref}
SCRIPT=tripo_coat_push.py step push COAT_IN=$W/${f}_6surf.glb COAT_OUT=$W/${f}_LIGHT_D106.glb COAT_TEX=$W/painted/${f}_coat_light.png
echo "[build_light_base] $f: $W/${f}_LIGHT_D106.glb"
