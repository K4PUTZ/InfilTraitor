# Session summary — 2026-11-15 (later): rising from the CROUCH into the RUN (both figures)

Milestone: MOVEMENT. In the game on the male AND the female, pushed to `main` (`0e9c2d63`, `94535d83`); `verify.py` (smoke) green.

## Built

1. **The timeline builder.** `pose_lab.py crouch_run_new` = `tripo_pose_lab.run_start_new(..., gait="crouch_run", run_blend)`: the rest pose is the crouch's LAST frame (`SEQ_crouch_<FIG>_fast.blend`, evaluated with its IK; the constraints are dropped, the builder makes its own). The left foot (flat, ahead) is the support and stays pinned; the right knee comes off the floor and swings through into the bank run's contact (frame 14). 17 frames, markers crouch / rise / drive / push / run. Coat keys: own `RiseFix_f<NN>`, `CrouchFix_f16 (inherited)` and `RunFix_f14 (next)` locked (the run key is copied from `SEQ_run_start_<FIG>_arm6.blend`, Basis checked equal). Measured: planted ball 0.0 mm, shins 0.0 mm short, lowest foot z 0.0201 (male) / 0.0005 (female).
2. **The Director's edit.** Male: an extra `RiseFix_f16` (the coat crossed the thigh at frame 16), added to his closed file by a headless script (backup `temp/backup/SEQ_crouch_run_MALE_before_f16.blend`). The female has no f16.
3. **Export.** `clip_out` -> `sequences/<fig>/crouch_run.json`; `RiseFix_*` byte-written into both LIGHT GLBs (`glb_add_morph.py`, backups `temp/backup/glb_before_rise/`); `tripo_game_clips.gd` rebuilt the game sets.
4. **In the game.** `TripoFigure.FOOTED_CLIPS["crouch_run"]` (prev `crouch`, prev_frame 15, next `run`; after `crouch` in the dict). `ActorMesh3D`: the run's gait row carries a `rise` start (len, handoff, morphs, fps, travel); a dash ordered with `_crouch_t` at the crouch's length (fully crouched) merges it over the gait's start fields. `ActorPose.dash_rise` + `is_crouched()`; `Agent._dash_start_profile` makes the same choice, so the first step follows the rise's travel. Any other move from a crouch (a walk, a move during the rise) still cuts.
5. **Take.** `agent_crouch_run` (PLAYGROUND, `MOVE_POINTS_PER_AP` 5, close rail). New scenario step `new_turn` (full AP again): a crouch costs 1 of the 2 AP a dash needs, so the take crouches in one turn and runs in the next.

## Open

- After the run the posture is still `crouch`: the actor re-kneels from the idle at the stop (as before; a gameplay call: does a run from a crouch end standing?).
- A crouch + dash in ONE turn is impossible (1 + 2 AP); AP costs are deferred to GAMEPLAY.
- Walk from a crouch (a `walk_start` equivalent) not built; `crouch_run_new` already takes `gait="walk"`-style rows to extend.
- No Moto measurement (below the 5 % rule); the light gate was not run (no look change).
