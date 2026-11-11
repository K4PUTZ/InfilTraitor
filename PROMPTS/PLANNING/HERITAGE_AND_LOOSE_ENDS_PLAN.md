# HERITAGE_AND_LOOSE_ENDS_PLAN
## Closing what the 2D-to-3D transition left, and the registered loose ends — v0.1 DRAFT

> 🟢 **v0.2 · 2026-11-11 · RATIFIED (Director: "Pode seguir com todas as etapas"), except T4 beyond the storey evaluation.** His
> rulings are §5. Drafted 2026-11-10 from the audit [`CODE_AND_HERITAGE_2026-11-10`](../AUDITS/CODE_AND_HERITAGE_2026-11-10.md),
> which holds the evidence for every item; this file holds only the work. Items owned by another plan stay there and are only pointed
> at.
>
> v0.1 (2026-11-10): the draft, nothing ratified.

## 0. Rules for every track
- A track changes no behaviour unless it says so. Behaviour-neutral stages close with `verify.py smoke`; a stage that moves where something is drawn takes a `--baseline` first and closes with `verify.py look` (or `full` when it rewires the board, the state or the ground).
- A deletion is preceded by a whole-repo grep of the name, per item (the 2026-07-12 lesson).
- One commit per stage. No stage is measured on a handset unless it could move a cost by more than 5 % (the 2026-11-10 rule); T4's camera stage is the one that could.

## 1. The tracks

| Track | Content | Size | Needs from the Director |
|---|---|---|---|
| **T1 — safe cleanup** | The 2026-11-04 dead-code list; the dead half of `PerspectiveMapper` with its five selftests rewritten on the base layout or removed; the four orphan shaders; the tile-era tools; the dead bench tables; stale names and headers; dead links; `map_lint.gd` into `verify.py quick`; git (fast-forward local `main`, drop merged and duplicate branches, the worktree under `temp/`, the stashes) | small, several commits | his word on the dead-code list, on each rename (`DebugAgent`, `sprite`, `TestZoneController`) and on the git deletions |
| **T2 — the weapon as one object** | Stages W1-W5 below | medium | the readings in §2 |
| **T3 — one path for captures and flags** | Move `auto_screenshot.py`, `build_filmstrip.py`, `build_material_matrix.py`, `p3_step_bracket.py` onto `capture.py` / scenario steps; delete the old harness (~1 500 lines of `room.gd`); a flag registry (name, default, description; an unknown name is a loud error) and every read through `DevFlags`; scenario steps out of `room.gd` into a controller | medium | none beyond the go |
| **T4 — world coordinates, in stages** | Stages C1-C5 below | large, spread over the work that touches each consumer | the ruling in §3 (2026-10-04 kept the 2D space on purpose) |
| **T5 — at the door of A2** | A selftest pinning the stealth core as it behaves today (thresholds, decay, FSM transitions, noise); the controller seam AI-02 / AI-03 land in; the save writes the `VoxelStore` and the replay (~960 lines, 13 records) retires | medium | the save's format is a design call (`roadmap` A2) |
| **T6 — documents, version, release identity** | One owner per number; `CLAUDE.md` without stale rows and without the JAMES block if he stays suspended; `current_state.md` cut to the current section, its generated block made stable; session records to `PROMPTS/DONE/`; one version source and one tag scheme. The release items (`DevFlags` in a release build, the keystore, the package id) stay in `LAUNCH_MASTER_PLAN` | small | the docs are his curation; the JAMES decision |

**Proposed order:** T1, then T2, then T3; T4's stage C1 early (it is cheap and stops the duplication growing), its later stages with `MOVEMENT` and the combat wave; T5 before A2; T6 at any time.

## 2. T2 — the weapon as one object
- **W1, identity.** A weapon row names its model, its hand placement and its floor / pickup presentation; `TripoFigure.PROP_MODELS`, the suffix strings (`""`, `"_pistol"`, `"_rifle"`) and the table in `room.gd` read it. Whether that row is `weapons/<id>.json` itself or a linked prop row is a design choice to settle first (`WEAPON` D7, `PROP_PIPELINE_PLAN` slots).
- **W2, one size.** The hand's proportion (ruled 2026-11-09) is the weapon's size everywhere; the table prop and the pickup stop carrying their own. ⚠️ Today the pistol is 0.180 GU in the hand and 0.277 on the table: a small object was enlarged on purpose to read on the floor. **Open:** does the floor copy keep a readability factor (one number for all weapons), or is it the hand's size exactly?
- **W3, the pickup in the world.** `FloatingCollectible` in world units (height, travel, spin), a real bounce in place of the sine, placed by the map (a section or a slot), switched back on. **Open:** "bouncing in the air" is read as the hovering pickup rising and falling; a dropped weapon tumbling to the floor is a different object (it would use the prop fragment's fall).
- **W4, the muzzle.** The flash, the tracer and the ballistic line start at the gun's muzzle point on the mesh; `muzzle_origin()`'s 2D head offset, `muzzle_floor_drop_px` and `MUZZLE_LEVELS_ABOVE_GROUND` go. This is `WEAPON_MASTER_PLAN` open item 6 built for every case. It changes where a shot starts, so it is a behaviour change with a capture before and after.
- **W5, the grenade's flight in the world.** The arc, the hop and the roll as world state; the preview drawn from the same function. With it the grenade mechanic leaves `TestZoneController` for a controller named for what it is.
- Not in T2: the shotgun, the rifle and the throw on the new figure (`MOVEMENT`), each weapon's hand scale (the Director's, per weapon).

## 3. T4 — world coordinates
- **C1, one answer.** `Room` / the board expose `cell_world(cell) -> Vector3` and a typed board interface (a preloaded script constant as the type, no string calls). The 27 files that re-derive the cell centre call it. One storey-height constant; the duplicates go. No visual change (pixel gate 0 px).
- **C2, free objects.** `ObjectMesh3D` takes a world position; the grenade and the pickups stop passing `screen_position` / `flight_px` (lands with T2 W3 / W5).
- **C3, actors.** The agent and the guards hold a world position; `ActorMesh3D` stops reading a parent `Node2D`. With `MOVEMENT`, which is rewriting the step anyway.
- **C4, effects.** The old emitters store ground + height, as the rule already asks of new ones; the 2D fallbacks and the "board exists" guards go.
- **C5, the camera and the root.** The 3D camera is driven directly; `Camera2D`, `VISUAL_GRID_OFFSET` (rule 2 retires here) and the `Node2D` root go; the HUD and the flash stay 2D. The one stage that touches input and every capture tool: `verify.py full`, both handsets.
- **What this buys is correctness and less code, not frame time.** The conversions are a few multiplications per object per frame; no measurement attributes a cost to them, and none was taken for this draft. Decide T4 on maintenance grounds.

### 3.1 The storey height, evaluated (2026-11-11; the Director: "vamos avaliar a possibilidade de unificar o valor dos andares")

Read from the code, not measured on a capture. One storey has three heights in screen pixels:

| Value | Where it comes from | Who still reads it |
|---|---|---|
| **160 px** (20 px a level) | the 2D voxel atom (`SIDE_H` 20 = 1.25 x 16): `GeometryCoords.VOXEL_STEP_PX` / `VOXEL_STOREY_HEIGHT_PX`, `IsoProjection.AXIS_Z`, a copy `room.VOXEL_STEP_PX` | `VoxelBoard.voxel_world_position()` and through it the debris, the glass rain and the shards' landings, the shot / blast spark origins (`room.gd`), the shrapnel and occlusion overlays, the shrapnel preview, `OcclusionSet`'s band bounds |
| **158 px** | measured off the retired 2D block art (286 - 128): `room.WALL_FLOOR_STEP_PX` | the ceiling fixtures' and light rays' lift, the temporal overlay's fixtures, `prop_top_px()` (a throw's clearance over a prop), `Board3DLive.VERTICAL_SCALE_MATCHED` (a dev look option, off) |
| **156.8 px** (19.6 a level) | what the 3D camera really draws: a true cube, 32 px / sqrt 2 x cos 30 deg | implicitly, every 2D height lifted into the world (`ParticleMath`: / (px per unit x cos 30 deg)) |

**The consequence.** Whatever is placed with 160 or 158 and then lifted into the 3D world lands **2.0 % / 0.8 %** above the true
voxel: at the third storey 9.6 px (0.061 GU, half a voxel) for the 160 family, 3.6 px (0.023 GU) for the 158 one. Small, and
it grows with height. Also found: `room_builder.gd` declares a `WALL_FLOOR_STEP_PX` of 20.0 that nothing reads (the same name,
another meaning), and `COS_ELEVATION` is declared twice (`ParticleMath`, `ObjectMesh3D`).

**Proposal (nothing done, the Director's call):** one value, the camera's, derived once in `GeometryCoords` from the camera's
geometry (19.6 px a level, 156.8 a storey), read by all three families; the copies and the unused `room_builder` constant go.
It is a LOOK change (things placed by level come down to the voxel they name): a `--baseline`, `verify.py look`, and
captures before and after of a blast's debris at the third storey and of the ceiling fixtures. It is cheap (one constant,
about fifteen call sites) and independent of C2-C5; it also removes the reason `VERTICAL_SCALE_MATCHED` exists. C2-C5 would
later replace these pixel heights with world units altogether.

## 4. Not in this plan
The Galaxy round, `VoxelFire` at its cap and the shot menu's opening frame (`PERFORMANCE_BUDGET`, M7.0); the breached-wall passage, posture AP and the noise indicator (GAMEPLAY); audio; iOS.

## 5. Rulings (2026-11-11)

1. **T1:** the 2026-11-04 dead-code list, the renames (`DebugAgent`, `sprite`, `TestZoneController`) and the git deletions are
   approved ("Ok").
2. **T2 W2 — one size, the hand's.** A weapon is ALWAYS the size it was given in the Agent's hands, on the floor, on a table and as a
   pickup; no readability factor. Only the pistol is certified (2026-11-09); every other weapon is certified the same way later, and a
   newly imported weapon carries a WARNING until it is. Recorded as owed in `MOVEMENT_MASTER_PLAN` §9 item 7.
3. **T2 W3 — the pickup floats.** "O item subindo e descendo, flutuando no ar, para evidenciar que é um objeto coletável." Rolling on the
   floor is the grenade's alone. Weapons also exist as SCENERY (on the floor, on a table): a prop, not a pickup, at the same hand size.
4. **T4 — not ratified.** "A princípio foi concluído que o espaço 2D pra 3D custa muito pouco, e que a mudança não traria muitos
   benefícios, mas podemos rever essa decisão. De qualquer forma, vamos avaliar a possibilidade de unificar o valor dos andares." So:
   evaluate one storey height (C1's last sentence) and report; C1-C5 wait on his review.
5. **JAMES is retired** (T6): "Pode remover, vamos trabalhar no Claude, porém no PC para fazer as músicas. O resto da engine continua
   aqui." His charter, gates, `CLAUDE.md` block and branch go; the HUD seam (rule 11 / L3) stays as architecture. The music is worked
   with Claude on the PC, on its own branch.

## 6. Progress

### T1 — DONE 2026-11-11 (`verify.py smoke` green, 130 s)
- **Dead code:** 33 functions, 23 members and 11 unlistened signals of the 2026-11-04 list deleted, each grepped over the whole repo
  first. **Kept, because the grep found them alive:** `scenario_reload`, `scenario_skylight_hit`, `scenario_relight` (the scenario
  runner calls `"scenario_" + op`); the signals `scenario_detonation_done`, `remesh_committed`, `close_requested` (awaited / listened).
  **Kept on purpose:** the posture tables (`POSTURE_MOVE_AP_COST` …) and the run noise constants (the stealth loop's data, GAMEPLAY
  milestone), `SaveState.save_to_file()` / `load_from_file()` (T5). `TEST_ZONE_GRENADE_GUS` is LIVE (the dev captures seed their
  grenades from it); the "weapon rows" were already gone, only a stale comment remained.
- **Renames:** `DebugAgent` -> `Agent`; `Agent.sprite` / `attach_sprite()` -> `pose` / `attach_pose()` (agent and guard);
  `TestZoneController` -> `GrenadeController` (`grenade_controller.gd`; the grenade record's `"sprite"` key -> `"prop"`).
- **`PerspectiveMapper`:** 327 -> 74 lines (the cell maps and `is_valid_direction()` stay); `floor_zone_bake` and `roof_bake` test the
  base layout, `roof_entity` checks the roof's placement, `slice_geometry` and `voxel_persist` lost their layout-rotation checks.
- **Files:** the four orphan actor shaders; `generate_master_floor.py`, `migrate_asset_tree.py`, the four `d33_part*_fixture_gen.py`
  and their fixtures (no selftest read them); `generate_voxel.py` 1 211 -> 665 lines, only the decal family (output diffed identical,
  44 files and the manifest). ⚠️ Found on the way: the committed `ASSETS/materials/manifest.json` lists `brick`, which the script does
  not know: running it would drop `brick` from the manifest (not fixed: the manifest's owner should say which is right).
- **Gates:** `tools/persistent/map_lint.py` (27 maps, ~1 s, proven red on a broken user map) is in `verify.py quick`.
- **Links:** the seven dead links repointed.
- **Git:** local `main` fast-forwarded; the worktree under `temp/` and `claude/unruffled-austin-9e2806` (local + remote) removed; the
  merged `origin/claude/{jolly-feynman-nynib1, project-thread-o218nn, project-thread-qtb3s4}` deleted; the three stashes dropped
  (`a06b1a21`, `df2a7598`, `4ef40530`, recoverable with `git stash apply <hash>` until git collects them).
  **Not deleted, a question for the Director:** `NEW_MAP` (local only) is NOT merged or duplicate: 23 commits of 2026-06-15/17 (the
  MODULARIZE / REDUCE / NEW_MAP WorldRenderer line) that never reached `main`. `origin/feat/music-composition` is the PC's music, left
  alone.

### T6 — DONE 2026-11-11 (`verify.py smoke` green, 130 s)
- **JAMES out:** `QWEN.md`, `.README_WORKSPACE.md`, `check_design_scope.py`, `hud_map.py`, the pre-commit gates 0 / 0.5 and the
  pre-push gate deleted; `origin/feat/design-interface-hud` deleted (tip `febcc430`, 11 commits never merged); `CLAUDE.md`'s
  Engine-Only block replaced by one rule (Claude owns the interface; rule 11 / L3 stays); the live plans mark him retired.
- **`CLAUDE.md`:** the TileSet row and the generated-PNG note (no on-disk TileSet since R3D-RETIRE-2D), R3D v1.51 -> v1.61; the
  pre-commit header cites `CLAUDE.md`, not the retired `OPERATOR_CONTEXT.md`.
- **`current_state.md`:** 1 772 -> 249 lines (the current section + the generated blocks); everything older moved verbatim to
  `docs/history/CURRENT_STATE_TO_2026-11-11.md`. The generated header is the version alone and the version history uses a fixed
  8-character hash, so the file no longer changes by itself (date, branch and hash length did).
- **Session records:** 183 of 187 moved from `PROMPTS/` to `PROMPTS/DONE/` (the root keeps 2026-11-09 onward); 210 links and paths
  rewritten in 112 files (the memory included), zero dead references after.
- **Version:** `project.godot` `config/version` 0.1.0-pre-alpha -> 0.9.107 (what an APK reports, since the preset leaves
  `version/name` empty), hook-checked as V1 (red on the old value, green after). One tag scheme: `verified/vX.Y.Z`; the old names
  stay as history. `version/code` and the package id stay `LAUNCH_MASTER_PLAN`'s.

### T3 — DONE 2026-11-11
- **Captures on one path:** `auto_screenshot.py` now runs `capture.py --still map` on the last map (13 s, shown); `build_filmstrip.py`
  (-> `capture.py --take blast_<m> | shot_<m> --sheet 1`), `build_material_matrix.py` (-> `material_videos.py`) and
  `p3_step_bracket.py` (-> the `agent_walk` take) deleted, with room.gd's old harness: `_run_auto_screenshot_capture()` and its 18
  capture actions, the filmstrip / shot / walk / glass-rain capture functions, the cell probe and the glass diagnostic backdrop
  (orphaned by the cut), `RAIN_TIMING_PRESETS` and `GlassRainOverlay.timing_overrides` (the glass track is closed). Shift+P, the
  benchmark (`BENCHMARK=1`), `HIDE_NON_VOXEL` and the dev grenade seeding stay.
- **One reader for dev flags:** `DevFlag` (`godot/scripts/systems/dev_flag.gd`): the registry (145 flags, each with its default and
  what it does), the resolution order (environment, `dev_flags.cfg`, default), safe on worker threads; the `DevFlags` autoload only
  finds the file and delegates. The 59 raw `OS.get_environment("INFILTRAITOR_*")` reads in 15 files and the two hand-made fallbacks
  (`ActorMesh3D`, `VoxelBoard`) go through it, so those flags reach an APK for the first time. **F1** (pre-commit) fails a raw read,
  an unregistered name, or a row nothing reads (red proven on a probe file, and on seven flags read through
  `room.call("_dev_flag", ...)` that the first extractor missed); `dev_flags_selftest` test 5 pins the registry at runtime.
- **Scenario steps out of the room:** the 30 `scenario_<op>()` (877 lines) and `scenario_detonation_done` live in
  `controllers/scenario_steps.gd` (`Room.scenario_steps()`, created on first use); `ScenarioRunner` dispatches to it.
- `room.gd`: 13 197 (audit) -> 10 588 lines over T1 and T3.

### T5 — findings before the work (2026-11-11, read from the code)
- **Two `_apply_tic_result()`, two sets of thresholds.** `Room._apply_tic_result()` only delegates to
  `TurnController._apply_tic_result()` (the controller always exists), so the game runs **0.25 / 0.50 / 0.75**; Room's own
  fallback and its constants **0.30 / 0.60 / 1.00** never run. `docs/systems/AI_MASTER_PLAN.md` says it re-verified 0.30 / 0.60 /
  1.00 "against the code" on 2026-10-02: it read the dead copy. Which numbers are canon is the Director's call.
- **Two alert meters.** `TurnController._alert_meter` accumulates, feeds the HUD bar and decides "busted"; `Room._alert_meter` was
  the one the three reset paths zeroed (`load_map`, the HUD's Reset, `_reset_room_state` after busted) and the alarm filled.

### T5 — first part DONE 2026-11-11 (`verify.py smoke` green)
- **The meter bug, red then green on the real room:** the scenario op `alert_reset` (fill the live meter, press the HUD's Reset through
  its handler, read the meter) printed `after the HUD's Reset the live meter reads 100 of 100` before the fix and `0 of 100` after,
  on PLAYGROUND. It now runs in every `smoke_boot` (both maps).
- **The seam:** the TurnController owns the one meter (`reset_alert_meter()`, `raise_alarm()`); Room lost its meter, its dead
  thresholds, its fallback copy of the tic result and of the audio pass, and its decay table; `GuardCoordinator`'s alarm calls the
  controller. AI-02 / AI-03 land in `TurnController._apply_tic_result()`, the one place.
- **The pin:** `stealth_core_selftest` (a scene selftest, 48 checks): noise emit / decay, audio radius / distance / walls, the tic's
  multipliers, the live thresholds 0.25 / 0.50 / 0.75 with the meter (+45 of 100, the cap, one alarm), the per-state decay, the
  noise bonus, the FSM's escalation, timers, de-escalation and hearing. It pins what IS, not what is right.
- **Open, the Director's:** which thresholds are canon (`AI_MASTER_PLAN` carries 0.30 / 0.60 / 1.00); the save's format (the
  `VoxelStore` in the save, and the ~960-line replay retiring with it) is a design call of `roadmap` A2 and is not started.

### T2 — W1, W2, W3 DONE 2026-11-11 (`verify.py smoke` green); W4, W5 open
- **W1, identity:** a weapon row carries its `model` (path, surfaces, hand bone / offset / scale, `size_certified`) and `held_as`
  (the old rig's grip; "" = none, the rifle keeps being refused exactly as before). `TripoFigure.PROP_MODELS` / `PROP_DEFAULTS`,
  the suffix strings (`ActorPose.WEAPONS`, `ActorMesh3D.WEAPON_BY_SUFFIX`, `AgentShotController.WEAPON_BAKE_SUFFIX`) are gone;
  `ActorPose.set_weapon(id)`. `WeaponRegistry.shared()` is the one registry (the autoload hands it out). An uncertified model WARNS.
- **W2, one size:** `WeaponDef.world_size()` = the model's own box x `TripoFigure.WORLD_SCALE` (1.225) x the hand scale; a prop row
  naming `"weapon"` takes model, surfaces and size from it (`props/pistol_prop.json`). The table pistol went 0.277 -> 0.180 GU
  (captures `PROPS` POI `pistols`, before and after).
- **W3, the pickup:** map section `pickups` (`{gu, weapon}`, compiled to `pickup_instances`); `FloatingCollectible` hovers 0.38 GU,
  bobs 0.115 GU, spins, in world units (`ObjectMesh3D.place_world`); PLAYGROUND places a pistol at (25, 11), POI `pickup`. The
  hard-coded strip (`TEST_ZONE_COLLECTIBLES`, the pack guns) is deleted. ⚠️ Its ground shadow did not show in the captures: owed.
- **Found:** a map whose `layout` POI is off the 1/8 lattice is refused at load, and the capture run then HANGS (Movie Maker kept
  writing frames for 5 min) instead of aborting: the scenario never starts. Worth a timeout in `capture.py`.
- **W4 DONE 2026-11-11 (Director: "o local de onde o tiro sai precisa ser vinculado com a abertura de cada arma, e não em uma
  coordenada do mundo"):** a weapon row's `model.muzzle` is a point of the MODEL (the pistol: (0.1266, 0.0349, 0), the front face of
  the slide, measured off the mesh); `ActorMesh3D.muzzle_global()` carries it by the gun's real placement in the hand (the aim poses
  / the draw timeline), `Board3DLive.lift_pair_of_global()` hands the flash and the tracer that exact point and the floor under it.
  Take `pistol_shot` (PLAYGROUND): the flash moved from the waist (the old head-based anchor) to the muzzle, before / after on one
  frame. Falls back to the old anchor when no measured weapon is drawn (the old rig's shotgun; the other weapons need their muzzle
  measured with their certification, `MOVEMENT` §9 item 7). Unchanged on purpose: the BALLISTIC line is still the grid walk from
  the shooter's GU (`select_line_impact`), and the target's height `MUZZLE_LEVELS_ABOVE_GROUND` (a misnomer now: it is the target
  point's height) — moving the shot's gameplay origin to the muzzle is a rule change for GAMEPLAY.
- **Open:** W5 (the grenade's flight in world state, out of the 2D parabola).
