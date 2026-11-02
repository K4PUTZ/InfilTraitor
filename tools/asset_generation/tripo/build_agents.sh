#!/bin/bash
# build_agents.sh — the two base Agents, end to end, from the official files (ACTOR D87, D89; closed 2026-10-31):
#   official/<FIG>_AGENT_BASE.glb -> tripo_assemble (slots) -> tripo_dress (COAT_BASE + the coat generation's hat, per-figure knobs)
#   -> tripo_uv (clean garment UVs) -> tripo_head_map (the head's own UVs + its painted map) -> official/AGENT_<FIG>.glb
# The painted map and the head's UVs are made in ONE run and written together: the head's smart-project UVs differ between runs on
# different files, so a map baked in one run garbles on another's head (seen 2026-10-31). Per-figure knobs (both figures always built):
#   female: LAPEL_SIDE=R SLEEVE_FIT=0 (the sleeve fit tore her cuffs) HAIR_PITCH=12 HAIR_UP/BACK=0.0035 (the fringe) HAT_DROP=0.0035
#   male:   HAT_DY=0.005 HAT_DROP=0.01
# GAME version (D91): for each figure in LIGHT_FIGS (default both, checked in Blender 2026-10-31: front / back / game camera, the climb and dive clips) tripo_lod reduces every piece to its budget
# right after the dress, then the same uv / head-map steps give AGENT_<FIG>_LIGHT.glb with its own painted/<fig>_head_light.png.
# Out: ASSETS/MODELS/official/AGENT_FEMALE.glb, AGENT_MALE.glb, painted/<fig>_head.png (+ AGENT_<FIG>_LIGHT.glb); work files in <work_dir>.
# Usage, from the repo root: tools/asset_generation/tripo/build_agents.sh <work_dir>
set -e
LIGHT_FIGS="${LIGHT_FIGS:-female male}"
W="${1:?usage: build_agents.sh <work_dir>}"; mkdir -p "$W"
B=/Applications/Blender.app/Contents/MacOS/Blender
T=tools/asset_generation/tripo; M=ASSETS/MODELS
run() { local log="$1"; shift; env "$@" "$B" -b -P "$T/$SCRIPT" > "$W/$log" 2>&1 || { echo "[build_agents] ERROR in $log"; tail -20 "$W/$log"; exit 1; }; }
for f in female male; do
  F=$(echo "$f" | tr a-z A-Z); c=${f:0:1}
  if [ "$f" = female ]; then from=$M/sources/tripo_female_coat_hat.glb; knobs=(LAPEL_SIDE=R SLEEVE_FIT=0 HAIR_PITCH=12 HAIR_UP=0.0035 HAIR_BACK=0.0035 HAT_DROP=0.0035)
  else from=$M/sources/tripo_male_coat_hat.glb; knobs=(HAT_DY=0.005 HAT_DROP=0.01); fi
  SCRIPT=tripo_assemble.py run "log_${c}_base.txt" TRIPO_GLB=$M/official/${F}_AGENT_BASE.glb TRIPO_OUT=$W/${c}_slots.glb BELT_KEEP=1
  SCRIPT=tripo_assemble.py run "log_${c}_from.txt" TRIPO_GLB=$from TRIPO_OUT=$W/${c}_from.glb
  SCRIPT=tripo_dress.py run "log_${c}_dress.txt" DRESS_COAT=$M/official/COAT_BASE.glb DRESS_BASE=$W/${c}_slots.glb DRESS_FROM=$W/${c}_from.glb \
      DRESS_OUT=$W/${c}_dressed.glb "${knobs[@]}"
  SCRIPT=tripo_uv.py run "log_${c}_uv.txt" UV_IN=$W/${c}_dressed.glb UV_OUT=$W/${c}_uv.glb
  SCRIPT=tripo_head_map.py run "log_${c}_head.txt" HEAD_IN=$W/${c}_uv.glb HEAD_SRC=$M/sources/tripo_${f}_base.glb \
      HEAD_MAP=$M/official/painted/${f}_head.png HEAD_OUT=$M/official/AGENT_${F}.glb
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_lod.py run "log_${c}_lod.txt" LOD_IN=$W/${c}_dressed.glb LOD_OUT=$W/${c}_light.glb
    SCRIPT=tripo_uv.py run "log_${c}_luv.txt" UV_IN=$W/${c}_light.glb UV_OUT=$W/${c}_light_uv.glb
    SCRIPT=tripo_head_map.py run "log_${c}_lhead.txt" HEAD_IN=$W/${c}_light_uv.glb HEAD_SRC=$M/sources/tripo_${f}_base.glb \
        HEAD_MAP=$M/official/painted/${f}_head_light.png HEAD_OUT=$M/official/AGENT_${F}_LIGHT.glb
    echo "[build_agents] $f light: $M/official/AGENT_${F}_LIGHT.glb"
  fi
  # the coat's weights, LAST, on each finished file: the dress leaves its hem bound to the hands, and only a cut made on the mesh the game draws holds (D91, 2026-11-01)
  SCRIPT=tripo_skirt_fix.py run "log_${c}_skirt.txt" SKIRT_IN=$M/official/AGENT_${F}.glb SKIRT_OUT=$W/${c}_final.glb SMOOTH_ITERS=10
  mv "$W/${c}_final.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_skirt_fix.py run "log_${c}_lskirt.txt" SKIRT_IN=$M/official/AGENT_${F}_LIGHT.glb SKIRT_OUT=$W/${c}_lfinal.glb SMOOTH_ITERS=6
    mv "$W/${c}_lfinal.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  # the skirt chains go (D88 -> D94, Director 2026-11-01 "tira as molas"): their weights to Hips, the 24 bones removed
  SCRIPT=tripo_chains_to_hips.py run "log_${c}_chains.txt" CH_IN=$M/official/AGENT_${F}.glb CH_OUT=$W/${c}_nochains.glb
  mv "$W/${c}_nochains.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_chains_to_hips.py run "log_${c}_lchains.txt" CH_IN=$M/official/AGENT_${F}_LIGHT.glb CH_OUT=$W/${c}_lnochains.glb
    mv "$W/${c}_lnochains.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  # the pocket openings are capped (a shallow dent): they showed the lining and what lay under it (Director 2026-11-01)
  SCRIPT=tripo_pockets.py run "log_${c}_pockets.txt" PK_IN=$M/official/AGENT_${F}.glb PK_OUT=$W/${c}_pk.glb
  mv "$W/${c}_pk.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_pockets.py run "log_${c}_lpockets.txt" PK_IN=$M/official/AGENT_${F}_LIGHT.glb PK_OUT=$W/${c}_lpk.glb
    mv "$W/${c}_lpk.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  # the shirt's collar / yoke flecked through the coat's back in a run (Director 2026-11-01): back vertices inside the coat are tucked 12 mm deeper (deleting them cut the collar's wings)
  SCRIPT=tripo_back_trim.py run "log_${c}_trim.txt" BT_IN=$M/official/AGENT_${F}.glb BT_OUT=$W/${c}_trim.glb
  mv "$W/${c}_trim.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_back_trim.py run "log_${c}_ltrim.txt" BT_IN=$M/official/AGENT_${F}_LIGHT.glb BT_OUT=$W/${c}_ltrim.glb
    mv "$W/${c}_ltrim.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  # the coat's back stands 4 mm further out where the shirt lies behind it (Director 2026-11-01)
  SCRIPT=tripo_coat_back_out.py run "log_${c}_out.txt" BO_IN=$M/official/AGENT_${F}.glb BO_OUT=$W/${c}_out.glb
  mv "$W/${c}_out.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_coat_back_out.py run "log_${c}_lout.txt" BO_IN=$M/official/AGENT_${F}_LIGHT.glb BO_OUT=$W/${c}_lout.glb
    mv "$W/${c}_lout.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  # what the legs' push needs (D94, 2026-11-01): the coat's per-vertex direction / mask / rest push and the capsule radii, baked onto the finished coat (no weight, no position changes)
  SCRIPT=tripo_coat_push.py run "log_${c}_push.txt" COAT_IN=$M/official/AGENT_${F}.glb COAT_OUT=$W/${c}_pushed.glb
  mv "$W/${c}_pushed.glb" "$M/official/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_coat_push.py run "log_${c}_lpush.txt" COAT_IN=$M/official/AGENT_${F}_LIGHT.glb COAT_OUT=$W/${c}_lpushed.glb
    mv "$W/${c}_lpushed.glb" "$M/official/AGENT_${F}_LIGHT.glb"
  fi
  echo "[build_agents] $f: $M/official/AGENT_${F}.glb + painted/${f}_head.png"
done
