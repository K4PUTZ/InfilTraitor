# coat_decal_lab — a faction's emblem on the coat: does it blur, does it distort?

Research for `ACTOR_MASTER_PLAN` D90 (Director, 2026-10-30: "testar fazer uma 'tatuagem' (decal) por cima do sobretudo com um símbolo de
cada facção [...] se não vai ficar distorcido ou borrado"). NOT engine code: Blender renders of both figures dressed in `COAT_BASE`. They are a
substitution that proves form and sharpness, not the runtime (Godot, the Moto).

## The method (`decal_render.py` header has the details)
The emblem is projected from behind onto the coat AT REST and kept in a UV channel of its own (`DecalUV`). A per-vertex mask (`DecalMask`)
limits it to the outer back. The shader lays it over the palette colour. It needs none of the garment's UVs and rides the skin. One small
emblem texture per faction serves every coat.

## What it showed (2026-10-30/31; the record is D90)
- **Sharp** up close and at the game camera (30 deg / 45 deg, a ~190 px figure). Baked into the coat's own 1024 texture, the same emblem's edges
  step.
- **Round at rest**, apart from a fold modelled into `COAT_BASE` under it. **In motion it waves and folds**: little in the walk, strongly in a
  run with the arms swinging. The cause is the coat's back weights, pulled by the shoulders and arms. The plain coat hid it.
- **The look, ruled:** the logo alone, no medallion, no white ground (`emblems.py`'s default). Readability at the game camera is owed: the
  orange flask vanishes on the mustard coat, and line art weakens.

## Run it (from the repo root; the sources in `ASSETS/` are git-ignored)
```bash
OUT=/tmp/coat_decal; LAB=tools/research/coat_decal_lab; B=/Applications/Blender.app/Contents/MacOS/Blender; K=ASSETS/ANIMATIONS/bank
$LAB/dress_both.sh $OUT                                   # f_dressed.glb, m_dressed.glb (~1 min)
python3 -I $LAB/emblems.py $OUT                           # the logo alone; add "medallion" for the first test's look
CLIP=correr_furtivamente_segurando_uma_pistola_aponta.glb # the stealth run, a pair in the bank
$B -b -P $LAB/decal_render.py -- $OUT/f_dressed.glb $OUT $OUT/r f $K/female/$CLIP
$B -b -P $LAB/decal_render.py -- $OUT/m_dressed.glb $OUT $OUT/r m $K/male/$CLIP
ONLY_MOTION=1 $B -b -P $LAB/decal_render.py -- $OUT/m_dressed.glb $OUT $OUT/r m_walk $K/male/walk.glb
ONLY_MOTION=1 $B -b -P $LAB/decal_render.py -- $OUT/m_dressed.glb $OUT $OUT/r m_run $K/male/run.glb
python3 -I $LAB/decal_sheets.py full $OUT/r $OUT          # sheets 1-4 + run_costas.gif
# the stills alone (every emblem from behind, up close, at the game camera): STILLS_ONLY=1 for f and m, then decal_sheets.py stills
```
The clip argument is still required with `STILLS_ONLY=1`, though it is not read.
