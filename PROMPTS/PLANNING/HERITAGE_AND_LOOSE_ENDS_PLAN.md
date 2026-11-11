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
