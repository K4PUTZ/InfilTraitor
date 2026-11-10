# Audit 2026-11-10 — the code, the 2D-to-3D inheritance, open items, engineering practice

**Asked by the Director:** a complete analysis of the code and of the project's evolution: loose pieces, bare wires, pending items, what the 2D-to-3D transition left behind, engineering practice. His example: the weapons spun in the air as sprites and must become real 3D objects, bouncing, at the size set by hand with the models. **Read-only: nothing here was fixed.** Commit audited: `2162a561`. The plan drafted from it: [`HERITAGE_AND_LOOSE_ENDS_PLAN`](../PLANNING/HERITAGE_AND_LOOSE_ENDS_PLAN.md).

**In one line:** what is drawn is 3D, but almost everything that says WHERE a thing is (camera, actors, effects, weapons) is still computed in pixels of the old isometric plane and converted back. The weapons are a direct symptom.

## Method and limits
- Static reading and text searches over `godot/scripts/` (348 scripts, 102 514 lines), `tools/` (183 Python files, 35 514 lines), the scenes, the data rows, the live plans and `docs/production/`.
- **Not done:** no boot, no gate, no handset (the 2026-11-04 audit booted all 27 maps and ran `verify.py full`; not repeated). Counts are word searches: every deletion candidate still wants its whole-repo grep. Shader internals and gameplay logic against `DESIGN` were not audited.
- The held pistol's size below is computed from the files, not measured on a capture.

## 1. The central inheritance: 3D drawing, 2D coordinates
Recorded as kept on purpose (`RENDER3D_MASTER_PLAN`, 2026-10-04: "What is left of the 2D is the COORDINATE SPACE"). No plan owns its retirement. What it costs today:

- **Root and camera.** `room.tscn` is a `Node2D` with a `Camera2D`; `Board3DLive._process()` copies its centre and zoom into the 3D camera every frame (`board3d_live.gd:966`). Drag, zoom and leash are computed in 2D pixels (`camera_controller.gd`).
- **38 scripts extend `Node2D`:** the agent, the guards, `VoxelBoard`, `room.gd`, the overlays. Overlays keep `_draw()` and are mirrored onto the board by `GroundCanvas3D` / `WorldCanvas3D`; one that is not attached paints the 2D canvas over everything (the reason `canvas_gate.py` exists: a fail-open design).
- **The cell centre is re-derived in 27 files (40 calls)** as `GroundGridRef.map_to_local(cell) + Vector2(0, 64) + offset`; 10 files declare their own `TILE_CENTER_OFFSET`, the literal `Vector2(0.0, 64.0)` appears 28 times, and the helper `GroundGrid.cell_center()` has zero callers. `Board3DLive.ground_point()` then maps the pixel back to `(x + 0.5, 0, y + 0.5)`.
- **One storey in pixels has three values:** 160 (`GeometryCoords.VOXEL_STOREY_HEIGHT_PX`, `IsoProjection.AXIS_Z`), 158 (`room.gd` `WALL_FLOOR_STEP_PX`), 156.8 (what the 3D camera projects). `WALL_FLOOR_STEP_PX` is also 20.0 in `room_builder.gd:579` (same name, another meaning); `VOXEL_STEP_PX` and `COS_ELEVATION` are each declared twice. `ROOF_MASTER_PLAN` already records a bug of this class (the shrapnel through roofs).
- **Actors:** the agent's step is a tween of a 2D `position` (`agent.gd:_step_next`); `ActorMesh3D._sync()` reads the parent's 2D position every frame and converts it.
- **Effects:** embers, debris, smoke, glass rain and shrapnel simulate in the 2D plane and are lifted through `lattice_basis()`. The rule "new VFX stores world-space state" covers new code only.
- **Inert bookkeeping:** 90 `z_index` assignments in 13 files, most on nodes that no longer draw on the canvas (`_apply_overhead_overlay_z`, `get_max_voxel_z_index`); 208 "if the board exists" guards in 53 files with 2D fallbacks (`_screen_to_tile_2d`, `_tile_to_screen_center_2d`) for a state the game no longer has.
- **Base / view vocabulary:** `perspective` is `"N"` for the life of a map, so `BlastCalculator.carved_side_to_base_dir()` / `carved_side_from_base()` rotate by identity; `CarvedSide.LEFT` / `RIGHT` are screen names for world faces.

## 2. Weapons (the Director's example)
A weapon has no single identity:

| Fact | Where it lives |
|---|---|
| Ballistics | `weapons/*.json` through `WeaponDef` (6 weapons); no model, no size |
| Model and hand placement | `TripoFigure.PROP_MODELS` / `PROP_DEFAULTS` (constants, the pistol only) |
| Which weapon the figure shows | a file-name suffix of the retired frame sets: `""` = shotgun, `"_pistol"`, `"_rifle"` falls to the shotgun (`actor_pose.gd:36`, `actor_mesh3d.gd:57`) |
| Pistol on a table | `props/pistol_prop.json` |
| Floating pickup | `TEST_ZONE_COLLECTIBLES` in `room.gd:11895`, off since 2026-07-29, PLAYGROUND only, another model file (the Quaternius pack's `Pistol.glb`) |
| Grenade | `bombs/frag_grenade.json`, constants in `grenade_prop.gd`, the whole mechanic in `test_zone_controller.gd` (1 918 lines; its header says "placeholder") |

- **Size.** The same pistol is **0.180 GU in the hand** (`pistol.glb` is 0.1468 long, times `STAND_HEIGHT_M / 1.6` = 1.225), **0.277 GU on the table** (`mesh_size`, +54 %), **0.25 GU as a pickup** (+39 %). The ruling of 2026-11-09 makes the hand's proportion permanent for every instance. The thrown grenade is 0.2 GU ("twice its real size").
- **Motion.** `FloatingCollectible` is a mesh already, but hovers (60 px), bobs (a sine of 18 px, no bounce) and spins (36 deg/s) through `screen_position` / `flight_px`. It is not a map entity and nothing picks it up. The static-facing mode went with the frames.
- **Muzzle.** The flash and the tracer start at `Agent.muzzle_origin()`: the head bone projected to 2D, lowered 18 %, with `muzzle_floor_drop_px = 96` commented as an estimate (`room.gd:6711`). The ballistic line leaves at `MUZZLE_LEVELS_ABOVE_GROUND = 4`. The 3D pistol sits on the eye line since 2026-11-08. Three answers to "where is the gun". `WEAPON_MASTER_PLAN` open item 6 (2026-10-18) records the 2D origin for an actor in a pit.
- **Grenade flight** is a 2D parabola in pixels (`ThrowArcOverlay`), the roll and hop driven by the controller; `ObjectMesh3D` keeps "the 2D contract".
- **Plan text:** `WEAPON_MASTER_PLAN` D3 / D4 / D10 still state frame bakes as decisions.

## 3. Code that exists only because of the old world

| Block | Size | State |
|---|---|---|
| Base-damage replay (`_reapply_base_damage`, `_respawn_base_*`, 13 `_base_*` records) | ~960 lines of `room.gd` | one caller: scenario step `save_restore`. Registered in `technical_debt.md`: goes when `SaveState` serialises the `VoxelStore` |
| `PerspectiveMapper.layout_with_perspective`, `remap_tile_name`, `remap_face`; `rotated_size`, `perspective_angle_delta_deg`, `_remap_suffix` | about half of 327 lines | no game caller; five selftests (floor_zone_bake, slice_geometry, voxel_persist, roof_entity, roof_bake) test a path the game never runs |
| Old capture harness (`_run_auto_screenshot_capture` 625 lines, `_capture_*`, 18 `capture_action` values) | 1 511 lines of `room.gd` | still driven by `auto_screenshot.py`, `build_filmstrip.py`, `build_material_matrix.py`, `p3_step_bracket.py`; lives beside `capture.py` |
| Flags read only by `OS.get_environment` | 88 names, 131 reads (87 in `room.gd`) | never reach an APK; DIAG-01's move to `DevFlags` stopped half-way |
| Tile-era tools | `generate_master_floor.py`, the atoms of `generate_voxel.py` (1 211 lines, only `build_decal_family()` live), four `d33_part*_fixture_gen.py`, `migrate_asset_tree.py` | no consumer |
| Orphan shaders | `actor_cloak3d`, `actor_cloth3d`, `actor_mask_eye3d`, `actor_mask_halo3d` | nothing loads them (hero v3 / v4, whose tools left on 2026-11-04) |
| Dead bench tables | `TEST_ZONE_GRENADE_GUS` and the weapon rows in `room.gd` | kept as "calibration history" |
| Names and headers | `DebugAgent`, `Agent.sprite`, `attach_sprite()`, `TestZoneController`, `billboard_height_px`, meshes under `overlays/`; the header of `board3d_live.gd` ("actors, props ... still draw in 2D", "only the three faces"), overlay headers naming tiles and z-bands, `throw_arc_overlay.gd`'s `GrenadeProp.SPRITE_SCALE` | describe the previous game |

## 4. Registered items still open
- **Audit 2026-11-04:** the dead-code list is untouched (47 of its names checked, all still defined and unnamed elsewhere; it waits on the Director's word); the dead links; `map_lint.gd` in no tier; the "Loaded resource as image file" boot warning; git (local `main` 759 commits behind, 3 stashes from June and August, `NEW_MAP`, `claude/unruffled-austin-9e2806` a duplicate of a fix already on `main`, and its worktree registered inside `temp/`).
- **Launch:** `DevFlags` obeys `dev_flags.cfg` in a release build; the debug keystore; package `com.example.$genname`, `version/code=1`; three versions that disagree (`VERSION` 0.9.107 since 2026-08-21, `project.godot` `0.1.0-pre-alpha`, the export empty); tags in three naming schemes; no iOS preset; no audio in code.
- **Gameplay (A2):** a breached opaque wall opens no passage and no sight; posture AP unread; the guard noise indicator; `SaveState` file I/O has no caller; no selftest on the stealth core (`tic_system.gd`, `noise_system.gd` last changed 2026-06-17).
- **Character:** on the Tripo figure only the pistol exists (shotgun, rifle, crouch, prone, throw open); guards and the officer run the old rig, so `ActorMesh3D` carries two paths.
- **Measurement:** the Galaxy round; `VoxelFire` at its 256 cap; the shot menu's 72-134 ms opening frame.
- **JAMES:** pre-commit gates 0 and 0.5, the pre-push gate, `QWEN.md`, the `CLAUDE.md` block and `origin/feat/design-interface-hud` (11 commits ahead since 2026-09-09) serve a suspended collaborator whose clone is deleted.

## 5. Engineering practice
**Sound:** ~95 % of declarations typed (11 277 against 580; 16 of 3 022 functions lack a return type), loud catalogue loading, hooks, `verify.py` tiers, 93 selftests.

**Weak:**
1. **`room.gd`: 13 197 lines, 368 functions, 290 member variables** (11 547 on 2026-10-09). 98 of its private members are reached from 14 other files in 374 places (`test_zone_controller.gd` 102, `save_state.gd` 58, `agent_shot_controller.gd` 53).
2. **No typed interface to the two central classes.** `room.gd` and `board3d_live.gd` have no type name; 229 calls go by string (`.call("ground_point")`, `.call("px_per_unit")`). A rename breaks at run time, the failure rule 11 exists to prevent on the HUD. A preloaded script constant can serve as the type.
3. **Dev tooling inside the main class:** capture 1 511 lines, scenario steps 877, 354 timer reads, 280 `print` calls.
4. **Flags:** about 170 names, no registry (name, default, description), two channels.
5. **Tests:** nothing on the stealth core; five on a dead path; 22 selftest headers still tell the reader to run `godot --headless --script`, which `CLAUDE.md` bans as evidence (27 say "Rodar:", against the English rule).
6. **Documents:** 95 855 Markdown lines against 102 514 of GDScript. `CLAUDE.md` went from 43.7 to 62.4 KB with stale rows (the TileSet row: `tileset_blocks` is deleted; R3D "v1.51" against v1.61; the generated-PNG note). `current_state.md` stacks 25 "where the project stands" sections over stale status blocks, and its generated block (date, branch, hash length) dirties the tree by itself. 184 session records sit at the root of `PROMPTS/`. The pre-commit header cites the retired `OPERATOR_CONTEXT.md`.
7. **No CI:** the gates are local hooks.

## 6. Evolution

| | 2026-07-12 | 2026-10-09 | 2026-11-10 |
|---|---:|---:|---:|
| Commits | 413 | 1 845 | 2 419 |
| GDScript files / lines | 147 / 26 318 | 280 / 83 201 | 348 / 102 514 |
| `room.gd` | 2 183 | 11 339 | 13 197 |
| Selftests | — | 74 | 93 |
| Python files / lines | — | 68 / 19 419 | 183 / 35 514 |
| Markdown files / lines (`docs/` + `PROMPTS/`) | — | 249 / 88 400 | 309 / 95 855 |

Each stage of the migration kept the 2D contract and replaced what was under it. That is why nothing broke on the way, and why the 2D contract is still everywhere.
