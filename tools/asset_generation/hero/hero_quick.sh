#!/bin/bash
# hero_quick.sh — the Director's 3-D edit loop (2026-10-25: "modify the model, render, open it in the conversation, done"): build the hero master with
# hero_tailor.py into a scratch folder (never over the game's GLBs) and render its views with hero_review.py; then post the PNGs in the chat.
# Usage: hero_quick.sh TAG "FEATURES" [TAG "FEATURES" ...]      any other hero_tailor knob by env, e.g. NOSE=0.3 AGE=0.5 hero_quick.sh N1 "hawk_nose:0.25"
# Env: HERO_SRC (a hero master that carries the 43 UAL tracks and the fitted hair, read as HERO_UAL_GLB and HERO_HAIR_GLB while the CC0 packs are not on
#      disk; default ARCHIVE/hero_sources/hero_source_v51.glb), HERO_OUT_DIR (default ${TMPDIR}hero_quick/), RV_PARTS (default face), RV_SAMPLES (32).
# Output: $HERO_OUT_DIR/hero_<TAG>.glb, $HERO_OUT_DIR/<TAG>.log and $HERO_OUT_DIR/rv/<TAG>_<part>_<view>.png
HERE=$(cd "$(dirname "$0")" && pwd)
export HERO_REPO="$(cd "$HERE/../../.." && pwd)/"
SRC="${HERO_SRC:-${HERO_REPO}ARCHIVE/hero_sources/hero_source_v51.glb}"
[ -f "$SRC" ] || { echo "hero_quick: no source master at $SRC (see PROMPTS/RESUMO_SESSAO_2026-10-25_HERO_FACE_COAT_HAT.md)"; exit 1; }
export HERO_UAL_GLB="${HERO_UAL_GLB:-$SRC}" HERO_HAIR_GLB="${HERO_HAIR_GLB:-$SRC}" HERO_HAIR_DIR="${HERO_HAIR_DIR:-}"
HERO_OUT_DIR="${HERO_OUT_DIR:-${TMPDIR:-/tmp/}hero_quick/}"; export HERO_OUT_DIR="${HERO_OUT_DIR%/}/"; mkdir -p "${HERO_OUT_DIR}rv"
B=/Applications/Blender.app/Contents/MacOS/Blender
while [ $# -ge 2 ]; do
  tag=$1; feat=$2; shift 2
  FEATURES=$feat OUT_SUFFIX=_$tag PREVIEW=none "$B" -b -P "$HERE/hero_tailor.py" > "$HERO_OUT_DIR/$tag.log" 2>&1 || echo "BUILD FAIL $tag"
  grep -E "Error|Traceback" "$HERO_OUT_DIR/$tag.log" | grep -v INFO
  RV_GLB="${HERO_OUT_DIR}hero_$tag.glb" RV_OUT="${HERO_OUT_DIR}rv" RV_TAG=$tag RV_PARTS="${RV_PARTS:-face}" RV_SAMPLES="${RV_SAMPLES:-32}" \
    "$B" -b -P "$HERE/hero_review.py" 2>&1 | grep -E "Error|Trace"
  echo "ok $tag -> ${HERO_OUT_DIR}rv/${tag}_*.png"
done
