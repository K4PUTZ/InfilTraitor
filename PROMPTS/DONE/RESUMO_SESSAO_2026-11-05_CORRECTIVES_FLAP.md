# Session summary — 2026-11-05: the corrective keys, the coat study, the male's flap skin

## Done

- **The six corrective coat keys** (`ACTOR` D103): the female's `WalkFix` (three edits) joined her `IdleFix` and `RunFix`;
  the male got `IdleFix`, `WalkFix` and `RunFix` (run frames 26, 9, 16, 3). Each one is the Director's hand edit on a baked
  frame (`ASSETS/MODELS/fit/*_FIX*_<FIG>.blend`), written back by `tripo_pose_fix_back.py` into a key left at 0; each
  matches its edit to 0.0000 cm on its frame. Videos were judged by the Director (front, and the run in the game's 4 views).
- **The male's front flaps skin uniformly** (`ACTOR` D104): the flap's middle followed the thigh and folded under it in `run`.
  The male's `IdleFix` and `WalkFix` were made before it; the Director judged idle and walk good on the new skin.
- **The coat study** (`ACTOR` top block, tools `tripo_coat_study.py`, `tripo_coat_counterfactual.py`,
  `tripo_coat_render_score.py`): three structural causes of the leaks measured (skin, clearance, lining). The Director set
  the candidates aside to deliver; nothing of them is in the base.
- **`tripo_pose_fix_back.py`** leaves Edit Mode first and clears the active object before the glTF import (a male file saved
  in Edit Mode read the buckle as an edit, and the importer's bone sphere landed in the active mesh).

## Commits

`86afe283`, `9c927d8c`, `bb8bd843`, `598ffa28`, `de5a4133` (the male's run and D104), and this documentation close.

## Left on disk, untracked (dropped experiments)

`ASSETS/MODELS/fit/AGENT_*_A_STRUCT.blend`, `AGENT_MALE_A_FLAP.blend`, `RUN_FIX_MALE_DRAPE.blend`, `RUN_FIX_F8_MALE.blend`,
`RUN_FIX_F9_MALE.blend` (pre-flap), `tools/asset_generation/tripo/tripo_coat_structural.py`. Delete them on the Director's word.

## Next (Director's order)

1. The transitions between idle / walk / run (MOVEMENT).
2. Texturing (ACTOR).
3. The models in the game and on the Moto: how the game drives the corrective keys (per clip recommended) and their cost.

Later, by the Director's choice: the stiff lapel ("papelão") experiment; whether the female takes the flap skin too.
