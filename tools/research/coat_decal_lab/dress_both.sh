#!/bin/bash
# dress_both.sh — both figures dressed in the universal coat, as the coat-emblem test used them (ACTOR D90, 2026-10-30/31).
# tripo_assemble.py on each base (BELT_KEEP=1, as recorded 2026-10-29) and on each coat generation, then tripo_dress.py with the standalone
# COAT_BASE and the per-figure knobs of 2026-10-27 (female LAPEL_SIDE=R; male HAT_DY=0.005 HAT_DROP=0.01). Writes f_dressed.glb and
# m_dressed.glb (plus the assembled inputs and one log per step) into <out_dir>. The sources are git-ignored (ASSETS/MODELS/).
# Usage, from the repo root: tools/research/coat_decal_lab/dress_both.sh <out_dir>
set -e
OUT="${1:?usage: dress_both.sh <out_dir>}"
mkdir -p "$OUT"
B=/Applications/Blender.app/Contents/MacOS/Blender
T=tools/asset_generation/tripo
TRIPO_GLB=ASSETS/MODELS/FEMALE_BASE_edit.glb TRIPO_OUT="$OUT/f_base.glb" BELT_KEEP=1 "$B" -b -P "$T/tripo_assemble.py" > "$OUT/log_f_base.txt" 2>&1
TRIPO_GLB=ASSETS/MODELS/MALE_AGENT_BASE.glb TRIPO_OUT="$OUT/m_base.glb" BELT_KEEP=1 "$B" -b -P "$T/tripo_assemble.py" > "$OUT/log_m_base.txt" 2>&1
TRIPO_GLB="ASSETS/MODELS/female+detective+figure+3d+model.glb" TRIPO_OUT="$OUT/f_from.glb" "$B" -b -P "$T/tripo_assemble.py" > "$OUT/log_f_from.txt" 2>&1
TRIPO_GLB=ASSETS/MODELS/MaleCharacterHatAndCoat.glb TRIPO_OUT="$OUT/m_from.glb" "$B" -b -P "$T/tripo_assemble.py" > "$OUT/log_m_from.txt" 2>&1
DRESS_COAT=ASSETS/MODELS/COAT_BASE.glb DRESS_BASE="$OUT/f_base.glb" DRESS_FROM="$OUT/f_from.glb" DRESS_OUT="$OUT/f_dressed.glb" LAPEL_SIDE=R \
    "$B" -b -P "$T/tripo_dress.py" > "$OUT/log_f_dress.txt" 2>&1
DRESS_COAT=ASSETS/MODELS/COAT_BASE.glb DRESS_BASE="$OUT/m_base.glb" DRESS_FROM="$OUT/m_from.glb" DRESS_OUT="$OUT/m_dressed.glb" HAT_DY=0.005 HAT_DROP=0.01 \
    "$B" -b -P "$T/tripo_dress.py" > "$OUT/log_m_dress.txt" 2>&1
echo "[dress_both] wrote $OUT/f_dressed.glb and $OUT/m_dressed.glb"
