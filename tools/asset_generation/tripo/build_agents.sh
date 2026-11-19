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
# Out: each figure's game/AGENT_<FIG>.glb, textures/<fig>_head.png (model_paths.py) (+ AGENT_<FIG>_LIGHT.glb); work files in <work_dir>.
# Usage, from the repo root: tools/asset_generation/tripo/build_agents.sh <work_dir>
set -e
LIGHT_FIGS="${LIGHT_FIGS:-female male}"
W="${1:?usage: build_agents.sh <work_dir>}"; mkdir -p "$W"
B=/Applications/Blender.app/Contents/MacOS/Blender
T=tools/asset_generation/tripo; M=ASSETS/MODELS
run() { local log="$1"; shift; env "$@" "$B" -b --python-exit-code 1 -P "$T/$SCRIPT" > "$W/$log" 2>&1 || { echo "[build_agents] ERROR in $log"; tail -20 "$W/$log"; exit 1; }; }
for f in female male; do
  F=$(echo "$f" | tr a-z A-Z); c=${f:0:1}
  eval "$(python3 tools/asset_generation/model_paths.py --sh "$f")"   # SRC BASE WORK GAME TEX SHARED DETAIL: this figure's folders
  if [ "$f" = female ]; then from=$SRC/tripo_female_coat_hat.glb; knobs=(LAPEL_SIDE=R SLEEVE_FIT=0 HAIR_PITCH=12 HAIR_UP=0.0035 HAIR_BACK=0.0035 HAT_DROP=0.0035)
  else from=$SRC/tripo_male_coat_hat.glb; knobs=(HAT_DY=0.005 HAT_DROP=0.01); fi
  SCRIPT=tripo_assemble.py run "log_${c}_base.txt" TRIPO_GLB=$GAME/${F}_AGENT_BASE.glb TRIPO_OUT=$W/${c}_slots.glb BELT_KEEP=1
  # the shirt's sleeves drawn in 10 % toward the arms, the chest untouched (Director 2026-11-02): the coat's sleeves need not be widened so much; SLV_SHRINK=0 turns it off
  SCRIPT=tripo_shirt_sleeves.py run "log_${c}_sleeves.txt" SLV_IN=$W/${c}_slots.glb SLV_OUT=$W/${c}_slots_s.glb SLV_SHRINK="${SLV_SHRINK:-0.10}"
  mv "$W/${c}_slots_s.glb" "$W/${c}_slots.glb"
  SCRIPT=tripo_assemble.py run "log_${c}_from.txt" TRIPO_GLB=$from TRIPO_OUT=$W/${c}_from.glb
  SCRIPT=tripo_dress.py run "log_${c}_dress.txt" DRESS_COAT=$SHARED/COAT_BASE.glb DRESS_BASE=$W/${c}_slots.glb DRESS_FROM=$W/${c}_from.glb \
      DRESS_OUT=$W/${c}_dressed.glb "${knobs[@]}"
  SCRIPT=tripo_uv.py run "log_${c}_uv.txt" UV_IN=$W/${c}_dressed.glb UV_OUT=$W/${c}_uv.glb
  SCRIPT=tripo_head_map.py run "log_${c}_head.txt" HEAD_IN=$W/${c}_uv.glb HEAD_SRC=$SRC/tripo_${f}_base.glb \
      HEAD_MAP=$TEX/${f}_head.png HEAD_OUT=$GAME/AGENT_${F}.glb
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_lod.py run "log_${c}_lod.txt" LOD_IN=$W/${c}_dressed.glb LOD_OUT=$W/${c}_light.glb
    SCRIPT=tripo_uv.py run "log_${c}_luv.txt" UV_IN=$W/${c}_light.glb UV_OUT=$W/${c}_light_uv.glb
    SCRIPT=tripo_head_map.py run "log_${c}_lhead.txt" HEAD_IN=$W/${c}_light_uv.glb HEAD_SRC=$SRC/tripo_${f}_base.glb \
        HEAD_MAP=$TEX/${f}_head_light.png HEAD_OUT=$GAME/AGENT_${F}_LIGHT.glb
    echo "[build_agents] $f light: $GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the coat's weights, LAST, on each finished file: the dress leaves its hem bound to the hands, and only a cut made on the mesh the game draws holds (D91, 2026-11-01)
  SCRIPT=tripo_skirt_fix.py run "log_${c}_skirt.txt" SKIRT_IN=$GAME/AGENT_${F}.glb SKIRT_OUT=$W/${c}_final.glb SMOOTH_ITERS=10
  mv "$W/${c}_final.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_skirt_fix.py run "log_${c}_lskirt.txt" SKIRT_IN=$GAME/AGENT_${F}_LIGHT.glb SKIRT_OUT=$W/${c}_lfinal.glb SMOOTH_ITERS=6
    mv "$W/${c}_lfinal.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the skirt chains go (D88 -> D94, Director 2026-11-01 "tira as molas"): their weights to Hips, the 24 bones removed
  SCRIPT=tripo_chains_to_hips.py run "log_${c}_chains.txt" CH_IN=$GAME/AGENT_${F}.glb CH_OUT=$W/${c}_nochains.glb
  mv "$W/${c}_nochains.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_chains_to_hips.py run "log_${c}_lchains.txt" CH_IN=$GAME/AGENT_${F}_LIGHT.glb CH_OUT=$W/${c}_lnochains.glb
    mv "$W/${c}_lnochains.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the pocket openings are capped (a shallow dent): they showed the lining and what lay under it (Director 2026-11-01)
  SCRIPT=tripo_pockets.py run "log_${c}_pockets.txt" PK_IN=$GAME/AGENT_${F}.glb PK_OUT=$W/${c}_pk.glb
  mv "$W/${c}_pk.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_pockets.py run "log_${c}_lpockets.txt" PK_IN=$GAME/AGENT_${F}_LIGHT.glb PK_OUT=$W/${c}_lpk.glb
    mv "$W/${c}_lpk.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the shirt's collar / yoke flecked through the coat's back in a run, and under the lapel in a walk (Director 2026-11-01): back vertices inside the coat are tucked 12 mm deeper, front ones 18 mm (deleting them cut the collar's wings)
  SCRIPT=tripo_back_trim.py run "log_${c}_trim.txt" BT_IN=$GAME/AGENT_${F}.glb BT_OUT=$W/${c}_trim.glb
  mv "$W/${c}_trim.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_back_trim.py run "log_${c}_ltrim.txt" BT_IN=$GAME/AGENT_${F}_LIGHT.glb BT_OUT=$W/${c}_ltrim.glb
    mv "$W/${c}_ltrim.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the coat's back stands 4 mm further out where the shirt lies behind it (Director 2026-11-01)
  SCRIPT=tripo_coat_back_out.py run "log_${c}_out.txt" BO_IN=$GAME/AGENT_${F}.glb BO_OUT=$W/${c}_out.glb
  mv "$W/${c}_out.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_coat_back_out.py run "log_${c}_lout.txt" BO_IN=$GAME/AGENT_${F}_LIGHT.glb BO_OUT=$W/${c}_lout.glb
    mv "$W/${c}_lout.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # TEST (Director 2026-11-02): the coat's loose pieces take the main surface's weights (COAT_WELD=1)
  if [ "${COAT_WELD:-0}" = 1 ]; then
    SCRIPT=tripo_coat_weld.py run "log_${c}_weld.txt" WELD_IN=$GAME/AGENT_${F}.glb WELD_OUT=$W/${c}_weld.glb
    mv "$W/${c}_weld.glb" "$GAME/AGENT_${F}.glb"
    if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
      SCRIPT=tripo_coat_weld.py run "log_${c}_lweld.txt" WELD_IN=$GAME/AGENT_${F}_LIGHT.glb WELD_OUT=$W/${c}_lweld.glb
      mv "$W/${c}_lweld.glb" "$GAME/AGENT_${F}_LIGHT.glb"
    fi
  fi
  # the pieces in their fabric: the hat in the coat's leather, the shirt, trousers, tie, the shoes in a darker leather (AGENT_SURFACE.json)
  SCRIPT=tripo_surface.py run "log_${c}_surface.txt" SF_IN=$GAME/AGENT_${F}.glb SF_OUT=$W/${c}_surf.glb SF_FIGURE=$f SF_MAPS=$TEX
  mv "$W/${c}_surf.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_surface.py run "log_${c}_lsurface.txt" SF_IN=$GAME/AGENT_${F}_LIGHT.glb SF_OUT=$W/${c}_lsurf.glb SF_FIGURE=$f SF_MAPS=$TEX
    mv "$W/${c}_lsurf.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  # the coat's initial texture (Director 2026-11-02): regions painted on the coat's UVs with the leather grain; the push bake embeds it
  IMP=(); LIMP=()
  # TEST (Director 2026-11-02): the loose pieces merged into the surface, drawn in the texture (COAT_MERGE=1; tripo_coat_regions paints them)
  if [ "${COAT_MERGE:-0}" = 1 ]; then
    SCRIPT=tripo_coat_merge.py run "log_${c}_merge.txt" MERGE_IN=$GAME/AGENT_${F}.glb MERGE_OUT=$W/${c}_merge.glb IMPRINT_OUT=$W/${c}_imprints.json
    mv "$W/${c}_merge.glb" "$GAME/AGENT_${F}.glb"; IMP=(CR_IMPRINTS=$W/${c}_imprints.json)
    if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
      SCRIPT=tripo_coat_merge.py run "log_${c}_lmerge.txt" MERGE_IN=$GAME/AGENT_${F}_LIGHT.glb MERGE_OUT=$W/${c}_lmerge.glb IMPRINT_OUT=$W/${c}_limprints.json
      mv "$W/${c}_lmerge.glb" "$GAME/AGENT_${F}_LIGHT.glb"; LIMP=(CR_IMPRINTS=$W/${c}_limprints.json)
    fi
  fi
  SCRIPT=tripo_coat_regions.py run "log_${c}_regions.txt" CR_IN=$GAME/AGENT_${F}.glb CR_MAP=$TEX/${f}_coat.png "${IMP[@]}"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_coat_regions.py run "log_${c}_lregions.txt" CR_IN=$GAME/AGENT_${F}_LIGHT.glb CR_MAP=$TEX/${f}_coat_light.png "${LIMP[@]}"
  fi
  # what the legs' push needs (D94, 2026-11-01): the coat's per-vertex direction / mask / rest push and the capsule radii, baked onto the finished coat (no weight, no position changes)
  SCRIPT=tripo_coat_push.py run "log_${c}_push.txt" COAT_IN=$GAME/AGENT_${F}.glb COAT_OUT=$W/${c}_pushed.glb COAT_TEX=$TEX/${f}_coat.png
  mv "$W/${c}_pushed.glb" "$GAME/AGENT_${F}.glb"
  if [[ " $LIGHT_FIGS " == *" $f "* ]]; then
    SCRIPT=tripo_coat_push.py run "log_${c}_lpush.txt" COAT_IN=$GAME/AGENT_${F}_LIGHT.glb COAT_OUT=$W/${c}_lpushed.glb COAT_TEX=$TEX/${f}_coat_light.png
    mv "$W/${c}_lpushed.glb" "$GAME/AGENT_${F}_LIGHT.glb"
  fi
  echo "[build_agents] $f: $GAME/AGENT_${F}.glb + painted/${f}_head.png"
done
