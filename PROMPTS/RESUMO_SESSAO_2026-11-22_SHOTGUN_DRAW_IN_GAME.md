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
  trunk back with the arms and the gun on it (the hands stay on the gun), the arms adding the climb. Ratified by him as they are (*"Está bom assim"*).

### Next

1. The Director's look at the female's draw (the recoil's strength is ratified); the 22 G-moved fingers redone with R where he wants
   what his Blender shows.
2. The shotgun's size certified by him (`size_certified`).
3. Then §11.6: the kneeling long-gun draw (step 4), the H3 family lab, the pump / case (step 5).

## 2026-11-23: the recoil ratified, the shot in stages

- **The recoil:** the Director ratified the long gun's recoil as it is (*"Está bom assim"*), recorded in `MOVEMENT_MASTER_PLAN`
  §11.6 step 3 (`a8856af5`).
- **The shot in stages** (Director: *"Durante o jogo vamos pausar em cada etapa"*), ruled in `WEAPON_MASTER_PLAN` D43 with his four
  answers (aimed stays at the shoulder; the pistol follows stages 2-4; no hit percentage until GAMEPLAY-01; stage 1's choice is a menu over
  the agent until the HUD has its buttons). Gameplay statement in `DESIGN_MASTER_PLAN` §8.7, the figure's part in `MOVEMENT` §11.6 step 3,
  the HUD buttons in `INTERFACE_MASTER_PLAN` Part 5.
- **Built:** `AgentShotController.Flow` (IDLE, STANCE, TARGET, FIRING): the weapon's key draws it (`choose_weapon`), a long gun standing
  stops at the hip with the menu over the agent (*Atirar do quadril* / *Mirar*), the target is the nearest enemy (D33) or the one clicked,
  the body turns in place to it (`ActorPose.shot_aim_dir`, `ActorMesh3D.facing_aim()`, the throw's turn), the trigger is the menu's button,
  Enter or a second click on the same enemy, and after the shot the weapon stays where it fired until a walk (`Agent.move_along_path`
  lowers the grip) or another item (`put_away`: another weapon, the grenade). Scenario steps `draw`, `stance`, `trigger`; take
  `shot_stages` on PLAYGROUND (profile `ui`; guards 4 and 6 placed beside the agent at the POIs `shot_target_left` / `_right`).
- **Checked:** the take filmed on both figures (sheets and videos shown), the pistol through `holster_walk`, `verify.py smoke` green.

### Next

1. The Director's look at the stages in the game (the films), and the HUD buttons for stage 1 when INTERFACE Part 5 starts.
2. Still open from before: the 22 G-moved fingers, the shotgun's `size_certified`, §11.6 steps 4-5.

## 2026-11-23 (later): the shotgun's size certified, H3's lab file

- **The Director:** *"Não vamos fazer playtest por enquanto. Se tiver algum erro corrigimos depois. A certificação do tamanho da escopeta
  está ok. Vamos conferir as demais armas da família."* The stages of the shot are left unplayed by hand for now.
- **Certified:** `weapons/shotgun.json` `model.size_certified` 2026-11-23 (x0.085 of the pack's units, the size his timeline holds at every
  sample on both figures); the load warning is gone.
- **H3's lab file** (`MOVEMENT` §11.6 step 2): `family_lab.py build H3 male` -> `ASSETS/MODELS/actors/agent/male/work/FAMILY_H3_aim_MALE.blend`,
  21 Agents frozen in the long gun's aim (his `SEQ_draw_shotgun_MALE.blend` at frame 31, read and never saved: its md5 unchanged), one
  long gun each on the LEFT hand with its trigger guard on the certified shotgun's: the pack's 3 other shotguns, 3 assault rifles, the
  bullpup and 4 snipers; the sci-fi set's 3 rifles, 2 snipers and the lightning gun; the 3 grenade launchers. Frames and trigger guards are
  explicit per model (the H1 guesses fail on long guns: measured on side renders). The read-back reads them; checked on the untouched file
  and, for no regression, on H1's file (all 14 rows reproduced exactly). Tiles: `temp/h3_family/h3_male_start_tiles_sheet.png`.
- **Found on the way:** H1's lab file names its sources by the layout before 2026-11-19 (`ASSETS/MODELS/sources/...`), so its read-back
  stops at the taser until the paths are mapped to `props/` (done for the check in a scratch wrapper, not in the tool).

### Next

1. The Director sizes and grips each long gun in `FAMILY_H3_aim_MALE.blend` and saves (to judge: the bullpup and the two P90-style sci-fi
   rifles, whose butt goes into the body with the hand on the trigger; the three without a shoulder stock, whose aim is H2's way).
2. The read-back, the female's file from the male's sizes, then the H3 rows (`family_rows.py` H3 table) and the engine's long-gun holder for
   `held_like`; a take drawing each one.
3. Still open: the 22 G-moved fingers, §11.6 steps 4-5, the stages played by hand (later, by his word).

## 2026-11-23 (later still): H3 split into five, the aim's grip re-checked first

- **The Director:** *"Certo, vamos separar um pouco as armas porque as animações vão ter que ser um pouco diferentes. Shotguns, rifles,
  sniper, scyfi e grenade launcher. Este último não tem posição mirada, vai ser só cintura, e provavelmente usando outra empunhadura.
  Antes de abrir as cenas separadas, eu quero dar uma olhada na posição da mira certificada, acho que o cabo da arma não está bem
  posicionado."*
- Recorded in `MOVEMENT` §11.6 step 2: five lab scenes (shotguns, rifles, snipers, sci-fi, grenade launchers) in place of the one H3 file
  (nothing was sized in it); the launchers fire from the hip only, probably on a grip of their own.
- His `SEQ_draw_shotgun_MALE.blend` (his save of 2026-11-22 21:32, md5 unchanged) opened for him in a new Blender at `aim` = 31; Claude
  saves nothing in it.

### Next

1. His verdict on the grip at the aim. If he moves it and saves: the shotgun read back again (both figures, the female in step), then the
   five scenes built on the new aim.
2. The groups are set (Director, on the two sci-fi snipers: *"Com os snipers"*), by the numbers of `FAMILY_H3_aim_MALE.blend`:
   shotguns 01-04, rifles 05-08, snipers 09-12 and 16-17, sci-fi 13-15 and 18, grenade launchers 19-21 (their scene at the hip, `hip` =
   23, on the shotgun's grip until theirs exists: Claude's reading, stated to him).
3. Then as before: he sizes each scene, the read-back, the female's files, the H3 rows, the engine's long-gun holder.

## 2026-11-23 (night): his grip at the aim in the game, the female in step, H3's five scenes

- **The Director:** *"Ajustei e salvei"* (the grip at the certified aim). His save of 19:20 changed the keys at frame 31 only: both hands
  turned 32-33° (the gun on the left hand re-angles with it, its placement in the hand unchanged), the forearms, arms, shoulders, neck and
  head, the right index finger and thumb on the trigger. The hip (23) is unchanged; the passing stops 18 and 20 move up to 3.6° (Bézier
  handles). The right middle and ring fingers also moved about 1 mm more with G, not keyed, not read by the game.
- **In the game on both figures:** `pose_lab.py sequence draw_shotgun --figure both` (the sequences, the pose files, the clip libraries).
  The female by the 11-22 recipe (`female_from_male` copygun + `right_on_gun` at 4 cm), proven first: on his 21:32 save it gives her 11-22
  file key for key. Filmed: `shotgun_shot`, both figures.
- **H3's five scenes,** built on the new aim (`family_lab.py build H3_<GROUP> male`): `FAMILY_H3_SHOTGUNS_aim_MALE.blend`,
  `FAMILY_H3_RIFLES_aim_MALE.blend`, `FAMILY_H3_SNIPERS_aim_MALE.blend`, `FAMILY_H3_SCIFI_aim_MALE.blend`, `FAMILY_H3_LAUNCHERS_hip_MALE.blend`.
  Every model sits, relative to the reference, as in the one H3 file (50 comparisons, turn 0.0000°). Tiles:
  `temp/h3_family/h3s_male_groups_sheet.png`.

### Next

1. The Director sizes and grips each of the five scenes and saves.
2. Each read-back, the female's five files from the male's sizes, the H3 rows (`family_rows.py`), the engine's long-gun holder, a take
   drawing each one.
3. Still open: the 22 G-moved fingers, §11.6 steps 4-5, the stages played by hand (later, by his word), the launchers' own grip.

## 2026-11-23 (night, later): her hip and aim by his hand

- **The Director:** *"Primeiro eu vou ter que ajustar o hip e a mira feminina também"* (before sizing the five scenes), then *"Ajustei e
  salvei"*. Her timeline was opened for him at the hip; he started from the recipe's file (`b112d762`). His save of 21:57 changed her
  body's keys at 23 and 31 only: the arms, the hands, the right fingers and the trunk at both, the neck and the shoulders at the aim. The
  gun's placement in the left hand, the coat and the markers are unchanged; her other stops did not move. Three right fingers were moved
  with G (up to 2.6 mm): not keyed, not read by the game.
- **In the game:** `pose_lab.py sequence draw_shotgun --figure female`; the male's files unchanged byte for byte. Filmed: `shotgun_shot`
  on the female (`temp/videos/femfix_shotgun_shot_female.mp4`).
- **Her 23 and 31 are his from now on:** the in-step recipe never runs over those two stops again (his file is never overwritten).

### Next

1. The Director sizes and grips each of the five scenes and saves.
2. Each read-back, the female's five files from the male's sizes (on her hip and aim as he left them), the H3 rows
   (`family_rows.py`), the engine's long-gun holder, a take drawing each one.
3. Still open: the G-moved fingers (22 on the male, 3 on the female), §11.6 steps 4-5, the stages played by hand (later, by his word),
   the launchers' own grip.

## 2026-11-23 (night, late): the grip per weapon to the polish, the shotguns as built

- **The Director asked** whether a skeleton changed in a lab scene is adapted per weapon, and whether rotated fingers reach the game.
  Answered from the code: the lab's read-back reads the guns only, every model of a family plays the family's one body; on a timeline
  a rotation keyed at its frame is read, fingers included, while G and S on any bone but the Hips, and a rotation left unkeyed, are not.
- **Ruled:** *"Vamos colocar essa questão da pegada individual por arma pra fase de polimento e seguir como está."* The body per weapon
  is a POLISH-01 deliverable (`docs/production/milestones.md`; MOVEMENT §11.6 step 2). The lab scenes size and place the guns only.
- **The shotguns' scene:** his save of 22:43 changed no gun and no bone; the four stay as built (`readback`:
  `temp/h3_family/readback_H3_SHOTGUNS_male_2243.json`). The rifles' scene opened next.

### Next

1. The Director sizes the rifles, then the snipers, the sci-fi and the launchers, and saves each.
2. Each read-back, the female's five files, the H3 rows (`family_rows.py`), the engine's long-gun holder, a take drawing each one.
3. Still open: as above, plus the grip per weapon (POLISH-01).

## 2026-11-24: the rifles sized, the bullpup's own grip saved, the rifles' hip scene

- **His save of the rifles' scene (00:37):** the three assault rifles moved 4-9 mm at their built size; the bullpup x0.75 of the
  reference's units (0.68 of the shotgun's length) on a body of its own, 26 bones (both arms, both hands, the fingers); nine finger
  joints also moved with G, which the game ignores.
- **The Director:** *"A última arma especificamente tem um design diferente, então eu tive que modificar o esqueleto. Vamos já deixar
  essa empunhadura salva. Precisamos checar o hip em seguida."* Saved, the polish ruling standing:
  `ASSETS/ANIMATIONS/poses/male/grip_bullpup_aim.json` (`family_lab.py grip <lab .blend> 08 <out>`): that Agent's 65 bones, the Hips,
  the bullpup in its own left hand. Proven on Agent 01, which gives back `seq_draw_shotgun_f31.json` (bones and Hips identical, the
  shotgun within 6·10⁻⁸). For POLISH-01: nothing in the game reads it yet.
- **The read-back** gives a re-posed Agent's model twice: `rel_*` on the family's body (what the one body shows), `own_grip` in its own
  hand. Nothing read before changes: the H1 files (both figures) and the shotguns' save hold no re-posed Agent.
- **The rifles' hip:** `family_lab.py build H3_RIFLES male <out> <read-back> --marker hip` -> `FAMILY_H3_RIFLES_hip_MALE.blend`
  (frame 23, his sizes, every Agent on the family's hip), opened for him; read back as built it gives the aim's placements exactly.

### Next

1. The Director checks the rifles at the hip (the bullpup's hands at least) and saves; a re-posed bullpup is kept as
   `grip_bullpup_hip.json`.
2. Then the snipers, the sci-fi and the launchers (and the shotguns' hip, if he wants it: they fire from the hip too).
3. As before: each read-back, the female's files, the H3 rows (`rel_*`, the family's body), the engine's long-gun holder, a take.
