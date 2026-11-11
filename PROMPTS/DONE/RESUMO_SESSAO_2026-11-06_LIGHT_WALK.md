# Session record 2026-11-06 (end) — the LIGHT is judged and corrected in motion; the walk of both figures (ACTOR D107)

Continues `RESUMO_SESSAO_2026-11-06_LIGHT_FROM_BASE.md`. Ends with both LIGHT Agents installed and the walk seen in Godot; the next step (Director) is the TEXTURE.

## Decided (Director)
- **D107:** the game's mesh (the LIGHT after the whole chain) is the one judged and corrected in motion; the FULL stays the source of the rest shape and the skin. The next clips (the dive...) are worked the same way; the face is left out.
- The session ends here; next the characters' textures, to judge the final look on the screen.

## Measured (read-only, Blender; LOD output against its FULL input)
- Skeleton identical (65 bones, names, rest matrices). Skin weights at the same surface point: mean difference 0.000-0.03 (hands 0.058), worst vertex 0.37-0.50.
- Every piece but the coat: median <= 0.7 mm, p95 <= 2 mm, the same in walk / run. The coat in `run`: p95 3.2 mm, worst vertex 18.8 mm (female) / 13.7 mm (male). Key transfer error: median 0.06-0.26 cm, worst vertex 10.25 cm (female `RunFix`).
- Walk, both figures, 16 frames x 4 views: LIGHT and FULL differ by 0.3-0.4 % of the visible garment pixels.

## Done
- Hand edits on the LIGHT, found by 4-view sheets at the game camera (SW = view 45 deg, SE = 315 deg): female walk frames 15 and 27 into `WalkFix` (`fit/LIGHT_FEMALE_WF2.blend`); male walk frames 20, 5, 35 into the BASIS of `fit/LIGHT_MALE.blend`. The cause of the male's specks: a slit at each coat cuff (hand showing through); the FULL has them too.
- `tripo_light_bake_frame.py` (a bank-clip frame baked for hand edits, then `tripo_pose_fix_back.py` with PF_A = the LIGHT). Its first version dropped the coat object's own location (male coat: ~1 cm off the origin) and moved the whole coat 1.4 cm in the key; fixed, null-tested (no edit = 0 vertices moved).
- LIGHT chain run from those files (`temp/work/light_final/`), installed in `ASSETS/MODELS/official/` (`AGENT_<FIG>_LIGHT.glb`, `painted/<fig>_head_light.png`, `<fig>_coat_light.png`; the shipped ones are in `temp/backup/official_light_2026-11-06/`), Godot reimport, `tripo_game_clips.gd`, `tripo_figure_selftest` green.
- The walk seen in Godot (PLAYGROUND `agent_walk`): `temp/videos/walk_<fig>_LIGHT_D107.mp4`, sheets `temp/takes/walk_<fig>_LIGHT_D107_sheet.png`. **The flag from the environment is `INFILTRAITOR_TRIPO_FIGURE`** (without the prefix both takes were the old rig, byte-identical).

## Open
1. **The Director saw several small defects in the Godot walk** (the chest beside the tie, the coat's lower front, 2026-11-06 screenshot). The game draws the untextured dev colours (white skin, dark coat, red lining), NOT the Blender diagnostic colours; whether they are real leaks or the flat look is undecided: the texture decides.
2. Next: texture the characters (CHARACTER / ACTOR), then judge the final look on the screen.
3. Not covered: idle and run (both figures), the female's cuff slits (coat vertices 0 / 376 and 1 / 126), the male's SE view at frames 1-14 and 28-37, the engine's `coat_push` look, the Moto with the new keys, how the game drives the corrective keys (D103), the stray `climb` / `dive` / `heart_pose` actions in the GLBs.
4. Nothing pushed; `ASSETS/` is git-ignored (the fit files and the installed GLBs exist only on this disk).

## Traps met
- The specks counter (isolated white / blue / skin pixels not near the FULL's) ignored skin until the end of the session and fails beside the tie: judge on a before / after sheet, never on the number.
- An object scale or location in a fix file is read as an edit by `tripo_pose_fix_back.py`.
- `capture.py` outputs overwrite `PLAYGROUND_agent_walk.*`: copy after each figure.
