# Session summary — 2026-11-15: the CROUCH, standing up, the crouched draw / aim / shot / holster (both figures)

Milestone: MOVEMENT (`PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md`). Everything below is in the game on the male AND the female and
pushed to `main` (`824d6f91` .. `e23d539d`); `verify.py` (smoke) green at each code step.

## Built

1. **The crouch** (posture `crouch`, the Z key; 1 AP per posture change, 2 per turn): the Director's timeline
   `ASSETS/MODELS/fit/SEQ_crouch_<FIG>_fast.blend` (16 frames: idle 1 -> step 9 -> crouch 16; the "knee" key removed at his request,
   `877d8d10`) read back by `pose_lab clip_out` into `sequences/<fig>/crouch.json`, a footed clip `"hold": true` in
   `TripoFigure.FOOTED_CLIPS` (no next clip, the last frame held). Coat morphs `CrouchFix_f09` / `CrouchFix_f16` byte-written into
   both `AGENT_<FIG>_LIGHT.glb` (`glb_add_morph.py`); the male's stale 21-frame `CrouchFix` removed with the new
   `glb_remove_morph.py`. The female crouch started as a transfer of the male's keys (`6eb531a1`); the cone variant was tried
   twice and REJECTED by the Director (`239173df`, `c2ad4496`; `crouch_new ... cone` stays in pose_lab, unused).
2. **Standing up = the crouch played BACKWARDS** (`ActorMesh3D`, coat keys too), ending on idle frame 90 (`f0b1258f`). A move
   ordered while crouched or rising still CUTS to it (no crouch -> walk / run passage yet).
3. **Crouched draw + aim** timelines `SEQ_draw_crouch_pistol_<FIG>.blend` (`pose_lab draw_crouch_new`, `ce16f934`): the crouch's
   last frame held on every bone but shoulders / arms / hands (the legs' IK baked to rotations), the arms from the standing draw
   (`SEQ_draw_pistol_<FIG>_arm6`) from frame 2, `CrouchFix_f16 (inherited)` held on the coat; the Director then edited both.
4. **In the game** (`e23d539d`): `sequences/<fig>/draw_crouch_pistol.json` + poses; `ActorMesh3D` keeps one aim set per posture
   (`_aim_sets`, `DRAW_CROUCH`), switches only with the gun away (`_aim_t` 0; a posture change while aimed lowers, then raises),
   and raises crouched only once fully down. The recoil (`ActorRecoil3D`) runs after both layers unchanged. **Holster** = the same
   travel read backwards (as standing): nothing new. Take `pistol_shot_crouch` (PLAYGROUND).

## Tooling: timeline coat keys (`docs/pipelines/timeline_coat_keys.md`, reminder at the top of MOVEMENT)

`coat_key_follow.py` (embedded in every `SEQ_*`): the active key follows the playhead, a key's frame READ from the animation;
only the clip's own key on the current frame is editable (`lock_shape`). Every key named by its frame: own `<Base>Fix_f<NN>`,
borrowed `... (inherited)` / `... (next)` with the OTHER clip's frame, always locked. All 30 `SEQ_*` renamed (backups
`temp/backup/seq_before_names/`); exporters send game names through `game_key()` (re-export checked identical). Builders still
write old names: run `unify_names()` on a new timeline.

## Open

- crouch -> walk / run passage (the stand-up for a move is a cut);
- the crouched aim leans with the torso (same arm angles as standing): judged acceptable, not measured against the target;
- `CHARACTER` §7a: the single-wall game coat (PROPOSED, post-Beta);
- the four `SEQ_walk_start/stop_*.blend` and `IDLE_FEMALE.blend` are untracked (the Director's call).
