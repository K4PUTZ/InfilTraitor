# Session summary 2026-11-22 — the shotgun's draw in the game (H3, both figures)

Picks up `RESUMO_SESSAO_2026-11-18_LONG_GUN_DRAW.md` (paused for ENEMIES since then). The full record is `MOVEMENT_MASTER_PLAN` §11.6
step 3 ("IN THE GAME on both figures, 2026-11-22").

## Where it stood

- `SEQ_draw_shotgun_MALE.blend`: the Director's save of 2026-11-18 02:49 has the same keys, coat shapes and mesh as the session's last
  write of 02:22 (only the playhead moved, 1 -> 31). His keys in it (against the builder's reference): the lapel (12), a key at 13,
  the shoulders at the hip (23) and `LongDrawFix_f12` (the right flap opened, 304 vertices). His fine adjustment was still to come.
- `SEQ_draw_shotgun_FEMALE.blend`: the builder's plus the 11-18 session's edits (the aim at the eye); no key of his.
- Neither file was edited this session.

## Built

- Read-back of both timelines (`pose_lab.py sequence draw_shotgun --figure both`); the game set carries the poses.
- `LongDrawFix_f12` byte-added to `AGENT_MALE_LIGHT.glb` (`glb_add_morph.py`); the empty keys stay out.
- `weapons/shotgun.json` has a model (`ASSETS/props/shotgun/shotgun.glb`, the pack's file byte for byte; `tripo_pose_lab.PROP_GLB` reads
  the same file), the left hand at x0.085, the muzzle at the bore's front face, no spent case.
- `ActorMesh3D`: aim sets per hold family and posture (`FAMILY_DRAWS`); the gun node takes the timeline's bone; the draw stops at the
  `hip` marker or runs to the aim (`ActorPose.shot_stance`); a long draw drives its own coat keys; `weapon_at_stance()`.
- The menu: two shots for a long gun standing ("Atirar do quadril (Enter)", "Atirar mirando"), the aimed one alone kneeling / prone / for
  a sniper; the aimed shot waits for the figure at the shoulder (`AgentShotController._reach_stance`).
- Takes `shotgun_draw`, `shotgun_shot` (PLAYGROUND), scenario step `shoot_aimed`. Filmed on both figures; `verify.py smoke` green.

## Found on the way

- The controller starts on the shotgun, so `weapon shotgun` changes nothing and `ActorPose.weapon_id` stays "": the figure did not draw.
  "" now means the family's reference row.
- 8 load warnings "the male coat has no 'DrawFix' morph" on PLAYGROUND come from the guards: they wear the male figure with their own
  rig (`ActorMesh3D.TRIPO_BY_FAMILY` "enemy", `ENEMY_FID_MALE_LIGHT`), which has no such morph; the Agent's GLB has it. The warning's code
  did not move this session; not chased. Only the agent ever takes the aimed grip, so the guards never draw.

## Next

1. The Director's look at the takes: approve, or fine-tune the male in Blender (then `pose_lab.py sequence draw_shotgun --figure male`).
2. The female in step with his keys (12, 13, the shoulders at 23, the right flap), in a new file beside hers.
3. The shotgun's size certified by him (`size_certified`; a load warning says it is not).
4. Then §11.6: the kneeling long-gun draw (step 4), the H3 family lab, the pump / case (step 5).

## Later the same day: his fine adjustment, the female in step, the recoil

Items 1 and 2 of the list above are done. The plan's record is `MOVEMENT_MASTER_PLAN` §11.6 step 3, its last bullet.

- **His crooked fingers were joints moved with G.** The rig's zero is Tripo's bent hand, so Alt+R never gives a straight one; the
  neutral is frame 1 (the game's idle, `lab_base`). What made the fingers look "deslocados e tortos" even in the idle were 20 bones
  moved with G where no location curve exists: not keyed by autokey, held on every frame, never read by the game. Cleared with his OK
  (Alt+G on those bones, never the Hips) in a new file beside his (`_clean`), which he then finished. His final save carries 22 new such
  moves (fingers, up to 1 cm); the game plays those fingers without them, rendered for him side by side. Check: a bone whose
  `pose.location` is not zero and has no location curve.
- **The male:** his save of 21:32 is `SEQ_draw_shotgun_MALE.blend` (his 17:58 save and every step since are in `temp/h3/`), read back:
  stops 11 (new, passing), 12 (rests), 13, 16, 18, 20 (passing), 23, 31 (rests). The coat's flap is the 11-18 one byte for byte.
- **The female in step:** at every one of his stops but her idle, his rotations as they are (as the crouch was, `6eb531a1`), the gun
  at his placement against the left hand's bone, her right hand put back on the grip at 23 and 31 by a two-bone solve to his hand's
  place on the gun, his flap carried by nearest vertex onto her coat and byte-added to `AGENT_FEMALE_LIGHT.glb`. A delta of his changes on
  her own poses was tried first and missed his gun angles through the draw. Her 11-18 file is in `temp/h3/`.
- **The recoil:** `ActorRecoil3D` profiles per hold family and stance: the pistol's unchanged; the shotgun at the hip and aimed rock the
  trunk back with the arms and the gun on it (the hands stay on the gun), the arms adding the climb. First values, his to tune.

### Next

1. The Director's look at the films: the recoil's strength, the female's draw; the 22 G-moved fingers redone with R where he wants
   what his Blender shows.
2. The shotgun's size certified by him (`size_certified`).
3. Then §11.6: the kneeling long-gun draw (step 4), the H3 family lab, the pump / case (step 5).
