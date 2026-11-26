# Session summary 2026-11-24/25 — the long guns kept out of the body, the snipers' scene, the documentation and a health review

Language: the conversation was in Portuguese; this record is in English (CLAUDE.md). The MV-6 work of this session is told in full in
`PROMPTS/RESUMO_SESSAO_2026-11-22_SHOTGUN_DRAW_IN_GAME.md` (its sections "night" to "2026-11-25 (later)"); this file closes the session.

## 1. The long guns (MV-6), in short

- **Female sawed-off:** built in step (`family_lab.py in_step`), its raise rebuilt from the gun (`raise`); the Director re-posed her draw (8, 9,
  11, 12); her coat no longer crosses the gun at 13 (the hand and the gun 1.5 cm to her left). Commits `bff2b1b3`, `a540bba9`.
- **Male short stock:** his save, its raise rebuilt; read back. **A gun-through-body check** (the gun's triangles crossing the figure's away
  from the hands) found every long-gun draw passing through the waist at 13-15 and some through the coat in the slide; videos with the gun
  orange and the cut triangles red showed it to the Director; the short stock and both bullpups fixed by moving the left hand with the gun by
  the smallest offset that leaves 0.6 cm. The family shotguns stay as they are: their fix (the stock swung 30°) shows below the coat from
  the game camera, while the cut is hidden there. Commit `6f30a529`.
- **The snipers' scene** (`FAMILY_H3_SNIPERS_aim_MALE.blend`, a lab file, not in git): the rifles' grip as built; one neck and head turn lifts
  the eye to the scopes (found by their glass lenses); the two sci-fi snipers pass through the head (a size for him). Opened in Blender for
  his ratification tomorrow (he keeps it open). Commit `66f5ffc6`.
- The scratch tools of this work were copied to `temp/h3_family/scripts/` (disposable).

## 2. The documentation, checked and brought up to date (commit `417d7786`)

An audit of the live docs (dead relative links, repo paths in backticks that no longer exist, each master plan's newest dated entry against
its `CLAUDE.md` row, docs missing from `docs/README.md`):
- Dead links: one, a false positive in the generated `CODEMAP.md`. Missing paths in the index docs: none.
- `CLAUDE.md`'s map: rows brought up to their plans (MOVEMENT, ACTOR, CAPTURE_RAILS, COSMETICS, DEVICE_DIAGNOSTICS, PERFORMANCE_BUDGET, ROOF,
  HERITAGE, WEAPON) and rows added for ITEMS, ENEMIES and INTERFACE (three active plans had none).
- Three plan subtitles contradicted their own status blocks: CAPTURE_RAILS ("planning, nothing built", but CR-1 to CR-6 are built),
  PERFORMANCE_BUDGET (v0.3 for v0.5), HERITAGE ("v0.1 DRAFT", ratified as v0.2 on 2026-11-11).
- `README.md`: Godot 4.6 -> 4.7, the project's status after 2026-10-04 (the materials, the roofs, the characters and their motion, the
  checks), `ASSETS/MODELS/` in the asset tree. `docs/README.md`: seven stale status labels, three missing entries.
- `docs/production/current_state.md`: "where the project stands" rewritten for 2026-11-25 (the 2026-11-10 section moved to
  `docs/history/CURRENT_STATE_TO_2026-11-11.md`); `docs/production/milestones.md`: a status reconciliation for 2026-11-25 above the
  2026-10-02 one.
- Not touched: `DESIGN_MASTER_PLAN`'s "2036-08-11" is right (a patent's term, not a typo); the per-plan status lines of `docs/README.md` for
  plans whose rows were current; the closed plans in `PROMPTS/DONE/` (history).

## 3. The memory

Four files: the long-gun memory condensed from a 20 KB day log into its rulings, method, tools and where each model stands; the enemies'
memory freed of "the shotgun draw was paused"; the open threads re-checked (T4 built at MV-4, the faces painted, the long guns' items
added); the index regrouped by theme with short hooks (11.1 KB -> 7.8 KB, every memory still indexed).

## 4. Code health

- **Checks:** `verify.py` (smoke) green, 53 s; `project_lint.py`: no real compile error (two "partially validated" notes: autoloads are not
  resolvable headless). Every selftest, the parked ones included (`run_selftests.py --all`): 95 clean, 0 failed (the
  parked blast / glass / shot suites have not rotted since 2026-11-12).
- **Size:** 359 GDScript files, about 104 000 lines (348 files on 2026-11-10); 193 Python tools, about 41 000 lines. `room.gd` went from
  13 197 lines (2026-11-10) to 10 505 (the heritage tracks moved code out); it is still three times the next file (`board3d_live.gd` 3 579,
  `detonation_plan_builder.gd` 3 569, `voxel_board.gd` 2 728). `agent_shot_controller.gd` grew from 1 307 to 1 635 lines (the shot in stages).
  TODO / FIXME / HACK markers: 40 in GDScript, 22 in Python.
- **Repository hygiene (for the Director, not changed here):**
  - **19 weapon models are untracked while tracked rows point at them**: `ASSETS/props/<model>/<model>.glb` for the H1 family (the
    pistols, the revolvers, the three sci-fi pistols, the ray gun, the taser, the flare gun, the grapple gun, the hand crossbow) and eight
    suppressors, named by `weapons/*.json`. A clean clone has the rows without their models (a loud failure at load, B6). The assets rule of
    2026-11-08 versions models in git, so they want a commit, by whoever owns that work (this session was told to leave them).
  - Two `.gd.uid` files are untracked (`shot_projectiles3d.gd.uid`, `shot_projectiles_selftest.gd.uid`; their scripts were committed
    2026-11-17, and the other 358 `.gd.uid` files are tracked): a clean clone regenerates them with new UIDs.
  - Uncommitted work of other sessions: the modified `grapple_launcher.glb`, two deleted guard textures, the `FAMILY_H1_aim_*` lab files.

## 5. Where the project stands, and what I would watch

- Since 2026-11-11: about 215 commits in 15 days. The engine phase is closed; since 2026-10-27 the work is the characters, their motion, the
  items and the enemies (`docs/production/milestones.md`, the 2026-11-25 reconciliation).
- **Two queues grow without a date:** GAMEPLAY-01 (AP costs and restrictions, the hit chance, posture costs, confrontation, cover) has not
  started, and POLISH-01 collects the per-weapon grips and timelines, the model timelines in the game, the coat's slivers, the foley. Both
  are the Director's call; the risk is a long stretch of animation work with no playable loop to judge it in.
- **Read-backs with no reader yet:** the per-model draw timelines (`sequences/<fig>/draw_<model>.json`) and the grip files are not played by
  the game until POLISH-01; a format change before then would not be noticed. A cheap guard: a selftest that loads every sequence and pose
  file through the engine's own loader.
- **Owed measurements:** the Galaxy A16 for the 2026-11-09 items; nothing since MV-4 was measured on a handset (only a change that could
  move a cost by more than 5 % is, by the 2026-11-10 rule).
- **Scratch tools that will be wanted again:** the cut check and its fix, the head-to-scope fit (the snipers after his sizes, the female
  scenes): today in `temp/h3_family/scripts/`, worth a place in `family_lab.py`.

## 6. Next

1. The Director ratifies the snipers' sizes (the Blender window stays open); then the head fitted again, the read-back, the grip file.
2. Her short stock (`in_step` from the fixed male, `raise`, the cut check); the female scenes; then the sci-fi and the launchers; the H3 rows.
3. The repository items of §4 for whoever owns them.

## 7. 2026-11-25 (later) to 2026-11-26 — the snipers closed and the own grips in the game

- **Snipers:** the Director's sizes read back; the snipers' HIP scene built (his ruling: snipers get a hip shot too, "vão errar mais ainda",
  not wired in the game yet: the `sniper` tag still makes them aimed only). Sniper 12 without its bipod and its clamp (his edit;
  `ASSETS/props/sniper_rifle_no_bipod/`, commits `387428d7`, `9fd232fb`); the pack original keeps both for the prone stance (suspended).
  The female snipers' scenes built from his sizes with her head fitted to the scopes (lab files).
- **Own timelines posed by him and read back:** sci-fi 17 male (`70d5f673`), sci-fi 16 male / female and 17 female (`2659e660`). Model 16
  joined into one mesh (`ASSETS/props/scifi_sniper_46615jyfm7/`, same vertices): the timeline tools take one mesh.
- **The own grips installed in the game** (Director, 2026-11-26: "o polish vai ser só pra o que ainda não foi feito"; numbers copied from the
  family): five rows held as the shotgun with `model.draw` (bullpup, sawed-off, short stock, sci-fi 16, 17), `family_rows.py --h3`;
  `ActorMesh3D` plays each row's own timeline (the family's at `held_like` on a figure without one); take `long_own_draws`. Commit
  `3ef7efa3`; `verify.py` smoke green; filmed on both figures. MOVEMENT_MASTER_PLAN's top block has the record.
- Seen in passing, not touched: the male coat has no `DrawFix` morph (the pistol draw's lapel stays closed; it is lost on a
  `build_agents` rebuild, see the memory).

## 8. Next (the Director, 2026-11-26)

1. Check the result in the game; the female's short stock (her own timeline: `in_step` from the male's, `raise`, the cut check).
2. The grenade launchers.
3. Waiting: the snipers' hip shot in the engine (drop the aimed-only `sniper` rule, a wider miss); the H3 rows of the models without an own
   timeline (they play the family's at `held_like`).
