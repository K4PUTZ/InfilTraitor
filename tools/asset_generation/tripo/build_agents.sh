#!/bin/bash
# build_agents.sh — the two base Agents, end to end, from the official files (ACTOR D87, D89; closed 2026-10-31):
#   official/<FIG>_AGENT_BASE.glb -> tripo_assemble (slots) -> tripo_dress (COAT_BASE + the coat generation's hat, per-figure knobs)
#   -> tripo_uv (clean garment UVs) -> tripo_head_map (the head's own UVs + its painted map) -> official/AGENT_<FIG>.glb
# The painted map and the head's UVs are made in ONE run and written together: the head's smart-project UVs differ between runs on
# different files, so a map baked in one run garbles on another's head (seen 2026-10-31). Per-figure knobs (both figures always built):
#   female: LAPEL_SIDE=R SLEEVE_FIT=0 (the sleeve fit tore her cuffs) HAIR_PITCH=12 HAIR_UP/BACK=0.0035 (the fringe) HAT_DROP=0.0035
#   male:   HAT_DY=0.005 HAT_DROP=0.01
# Out: ASSETS/MODELS/official/AGENT_FEMALE.glb, AGENT_MALE.glb, painted/<fig>_head.png; work files in <work_dir>.
# Usage, from the repo root: tools/asset_generation/tripo/build_agents.sh <work_dir>
set -e
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
  echo "[build_agents] $f: $M/official/AGENT_${F}.glb + painted/${f}_head.png"
done
