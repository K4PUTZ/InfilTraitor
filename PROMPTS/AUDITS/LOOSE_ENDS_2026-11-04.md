# Audit 2026-11-04 — loose ends and bare wires in the whole code

**Asked by the Director:** "dar mais uma geral no código todo, e ver se não tem nenhuma ponta solta ou fio desencapado." **Read-only: nothing here was fixed.** Commit audited: `bd6f3f11`. Each finding names its proposal; nothing is removed or rewired until the Director rules.

**In one line:** the game is sound (every map boots with no error and every gate passes). The real exposure is outside the code: git alone cannot run the game, and most of its art exists only on this disk. Inside the code there were one certain crash in a tool and a few small tool bugs, fixed the same day (findings 3, 4, 5); a modest amount of dead code remains.

## Method
- **Static, over everything tracked:** 343 GDScript files (100 819 lines), 148 Python, 5 shell, the scenes, the data rows, the live docs. What was looked for: paths that resolve to nothing, scripts and resources nothing reaches, names called by string, signals, input actions, stubs, markers, flags, translations, broken imports, names bound nowhere, dead links, secrets (reported by location, never by value).
- **Compiler:** a clean clone with every GDScript warning raised to an error (`override.cfg`, never in the working tree), read through `project_lint_validator.gd`.
- **Runtime:** every map booted and rotated; `map_lint.gd`; `verify.py --baseline`, then `verify.py full --keep-going`. A clean clone booted with git's files only.
- **Every finding below was read in context; the dead-code lists are word-search results** with the false positives I could spot removed, so each entry still wants its grep before it goes. A name found once is not proof: `_process_modification_with_delta` is an engine virtual, `aim_dome3d_*` are loaded by a built string, `room._pane_primed` is used from another file (the compiler's own warning about it is wrong, the CLAUDE.md lesson). Those were dropped. **Not covered:** a handset run, gameplay logic against the design, and shaders beyond who loads them.

## What came back clean
| Check | Result |
|---|---|
| Boot and rotate each map | **27 of 27, exit 0, 0 error lines** |
| `map_lint.gd` | 27 checked, 0 failed (2 s) |
| `verify.py full` on a fresh baseline | **PASSED, 19 of 19 steps, 701 s.** The baseline is today's code: it proves the harness and the gates, not "no change since an older commit" |
| Selftests | 92, all discovered, all able to fail |
| Scene connections, input actions, autoloads | every one resolves and is used |
| Names called by string in game code | none missing |
| `printerr`, `assert()` with a side effect | 0 |
| `print` in a per-frame function | only behind dev probes |
| Python: syntax, imports | 0 errors, 0 broken imports |
| Tools naming a file that is not there, in code | 0 |
| Translations | 31 keys, none missing, no empty cell, no hard-coded widget text |
| Secrets, key files in tracked text | none found in `HEAD` (history was not scanned) |
| `.uid` sidecars without a script | 0 |

**Corrected on the way:** the 2026-08-30 note that the game's noise and passages were severed is out of date. `NoiseSystem.emit()` is called from the walk (20 % of the steps) and guards hear through `TicSystem.evaluate_audio()`; the alarm works (`GuardCoordinator` calls each guard directly, so its four signals having no listener is cosmetic).

## Findings, most serious first

### 1. Git alone cannot run the game; the art exists only on this disk (RISK)
A clean clone boots PLAYGROUND and GLASS with exit 0 and 40 and 27 error lines: no agent, no guards, no grenade, no wall facades, no glass decals. Outside git, without sidecars: `ASSETS/materials` 36.8 MB (184 art files, 3 versioned), `ASSETS/ISOMETRIC` 7.8 MB (the rig's `.blend` and `.glb`), `ASSETS/props` 0.6 MB (0 of 34 files), `ASSETS/AUDIO` 49.2 MB, `ASSETS/TEXTURES` 12.2 MB, `ASSETS/photo_src` 177.9 MB. `tools/persistent/BACKUP.py` excludes `ASSETS/`. The `.gitignore` comment that generators "reproduce everything on demand" stopped being true with the photographic facades.
**Proposal:** version `ASSETS/materials/**` art, `ASSETS/props/**` and the rig's sources (about 45 MB; the repo is 2.8 GB). The Director's question first: does another backup of this disk exist?

### 2. A breached opaque wall opens no passage and no sight (OPEN DECISION, known)
`build_movement_edge_set()` asks `PassageQuery` about glass only, and `_current_blocked_edges`, which feeds vision, detection, noise and light, is never updated by destruction. A hole a grenade opened is a hole only for the next grenade's flood. Recorded as question 3 in `docs/production/current_state.md`: "a real behaviour change, not a correction". **Proposal:** decide it with the stealth loop (roadmap A2).

### 3. `tripo_coat_decal.py` died at line 35 (FIXED, same day)
`len(V)` in a progress line, and `V` was bound nowhere in the file. Before: exit 1, `NameError`, nothing written, on its real input. After `len(mask)`: exit 0, the GLB and four store renders, the emblem on the coat's back.

### 4. The menu showed a Load button with nothing behind it (FIXED, same day)
`main_menu_panel.gd`'s handler is `pass`, and `SaveState.save_to_file()` / `load_from_file()` have no caller (owed with roadmap A2). **Correction:** this report first said a player could press it; the button was already disabled, greyed out. It is now hidden until A2, seen in a 1280x720 and a 390x844 capture.

### 5. Three small tool bugs (FIXED, same day)
The bench refused `_nocoat_tint`: its three state suffixes now combine in any order, with the same counts both ways (3 997 and 5 262 tris), and `actor_video.py --model ..._nocoat` records. A rejected scenario left the game running until a 120 s timeout: it now ends with code 1, in 4 s. `actor_video.py`'s crop cut head and feet: the default shows the whole figure, and `--crop 0.112 --crop-y 0.666` is the old torso close-up.

### 6. Posture promises what movement ignores (UNBUILT)
`agent.gd`: `POSTURE_MOVE_AP_COST` says crouching costs +1 AP per tile and prone cannot move; nothing reads it, so a crouched or prone agent walks at full speed. `POSTURE_HIT_MULT` and `POSTURE_AIM_MULT` say "not used yet"; `POSTURE_DETECTION_MULT` is live. **Proposal:** delete the unread tables or wire them with `DESIGN` §8.2; the decision belongs to the stealth loop.

### 7. A shipped build would obey `dev_flags.cfg` (FOR THE LAUNCH)
`DevFlags` reads the file from external storage, `user://` and `res://` in a release APK, and the flag `SCENARIO` runs scripted steps. The fix is already written in its own comment and awaits a sign-off: a measurement preset and `OS.has_feature("dev_flags")`. **Proposal:** a row in `LAUNCH_MASTER_PLAN`; nothing before the launch, because the handset tools depend on it.

### 8. Art debt the log repeats (ART)
Ground debris exists only for `wood` and `plywood`; 11 materials borrow wood's under a tint, with one warning each boot: `cardboard`, `concrete`, `fabric`, `iron_bar`, `metal`, `painted_metal`, `paper`, `plastic`, `steel_dark`, `steel_plate_rust`, `upholstery`. The guard's noise indicator is also unwired (`technical_debt.md`). **Proposal:** an art order when props matter.

### 9. Dead code (CLEANUP)
Never named again in any code (a word search of the whole repo): **38 functions, 30 class-level members, 14 signals with no listener** (lists below), plus 14 unused locals and parameters in live code. The three empty stubs in `turn_controller.gd` (`_update_guard_los_data`, `_update_enemy_visibility`, `_refresh_tactical_state`) shadow the real ones in `room.gd`; checked that no stale data follows, because guards hold `_blocked_cells` by reference and it is edited in place. **Proposal:** a single pass, with a grep of the whole repo per item and `verify.py smoke`.

### 10. Noise that buries real warnings (LOG)
Every desktop boot prints "Loaded resource as image file, this will not work on export" per facade (2 to 15 lines a map). Harmless: in an export `ImageSource` takes the imported resource, the path every APK has run on. **Proposal:** read the raw file by its global path so the warning stops.

### 11. Compiler warnings (TIDY)
With every warning as an error: 73 shadowed names, 55 integer divisions, 22 unused locals, 6 unused parameters, 10 others (compatible ternaries, a local declared later in the parent block; read, none a bug); `room.gd` holds 41. The rule is zero in a file touched. **Proposal:** keep the rule, no pass of its own.

### 12. Pointers and leftovers (TIDY)
- **7 dead links in live plans**, listed below.
- **21 dev flags nothing sets and no doc names** (below), and `build_filmstrip.py`'s comment points at `BURN_PROFILE`, which nothing reads.
- **The `p3_*` exports** still print a hint to `agent_frame_bake_spike.gd`, deleted at R3D-ACTORS. They go at MV-4.
- **Tools nothing mentions:** `tripo_coat_alone.py`, `tripo_compose.py`, `tripo_hair_swap.py` (D86's experiments), `music_generate.py`, two `tools/research/cloth_lab/` figures.
- **`map_lint.gd` is in no tier** though it takes 2 s. **Proposal:** add it to `verify.py quick`. A `maps` tier booting all 27 (3.5 min) would have caught today's kind of break.
- **Git:** local `main` is 650+ commits behind (a `git checkout main` lands in the past); 3 stashes from June and August; `NEW_MAP` from June; 5 stale `origin/claude/*` branches, 4 merged and one a duplicate of `cd5a0f58`; 103 tracked files the ignore rules would exclude (`ASSETS/TEXTURES/source` 66, `docs/measurements` 16, `.vscode` 4). **Proposal:** fast-forward local `main`, delete the merged remote branches on the Director's word, leave the rest.

---

## Lists

### Functions never named again (38)
```
agents/actor_pose.gd:142  clear_head_yaw
geometry/board3d_live.gd:2137  crack_mirror
geometry/edge.gd:183  key_string
geometry/soft_sheet3d.gd:208  node_positions
geometry/soft_sheet_sim.gd:356  node_index
geometry/soft_sheet_sim.gd:385  steps_run
geometry/voxel_board.gd:1963  set_glass_cracks_visible
geometry/voxel_board.gd:1977  set_glass_opening_void
geometry/voxel_board.gd:2021  glass_crack_count
geometry/voxel_board.gd:828  light_apply_job_pending
geometry/voxel_board.gd:833  levels_in_gus
geometry/voxel_board.gd:865  apply_warm_gus
overlays/floating_collectible.gd:57  billboard_height_px
overlays/grenade_prop.gd:80  billboard_height_px
systems/cell_plane_store.gd:149  warm_at
systems/destruction/material_resistance_table.gd:213  is_combustible
systems/destruction/voxel_weakness.gd:32  is_weak_key
systems/destruction/weapon_def.gd:118  has_range
systems/image_source.gd:41  load_texture
systems/lighting/light_anchor.gd:87  debug_string
systems/lighting/light_source.gd:255  affects_cell
systems/lighting/voxel_light_field.gd:463  has_warm_lights
systems/lighting/voxel_light_field.gd:575  _occ_at
systems/prop_registry.gd:64  get_slot
systems/save_state.gd:289  save_to_file
systems/save_state.gd:316  load_from_file
systems/surface_rules.gd:89  kind_mature
systems/surface_rules.gd:94  kinds_of_class
systems/voxel_store.gd:425  mark_dirty
systems/voxel_store.gd:432  unmark_dirty
world/room.gd:1164  _respawn_base_rim_shards
world/room.gd:1561  _respawn_base_crazes
world/room.gd:3218  view_yaw_deg
world/room.gd:4204  scenario_reload
world/room.gd:4285  scenario_skylight_hit
world/room.gd:5621  scenario_relight
world/room.gd:6409  _vfx_count_take
world/tile_semantics.gd:139  debug_string
```

### Class-level members never named again (30)
```
agents/agent.gd:37  const POSTURE_MOVE_AP_COST
agents/agent.gd:44  const POSTURE_HIT_MULT
agents/agent.gd:49  const POSTURE_AIM_MULT
agents/agent.gd:58  var vision_mode
agents/guard_enemy.gd:22  const COLOR_BODY
agents/guard_enemy.gd:23  const COLOR_BODY_DARK
agents/guard_enemy.gd:24  const COLOR_HEAD
geometry/geometry_coords.gd:58  const VOXEL_ATOM_W
overlays/elite_exposure_overlay.gd:46  var show_risk_zones
systems/enemy_phase_controller.gd:5  const DEFAULT_VISION_RANGE
systems/lighting/exposure_system.gd:56  const STABILITY_NAMES
systems/lighting/light_source.gd:113  const STATE_OFF
systems/lighting/light_source.gd:123  var last_angle
systems/lighting/light_source.gd:20  const TYPE_DIRECTIONAL
systems/lighting/light_source.gd:21  const TYPE_CONE
systems/lighting/light_source.gd:23  const TYPE_INTERMITTENT
systems/lighting/light_source.gd:24  const TYPE_EMERGENCY
systems/lighting/light_source.gd:25  const TYPE_MOBILE
systems/noise_system.gd:10  const NOISE_INTENSITY_RUN
systems/noise_system.gd:16  const NOISE_RADIUS
systems/noise_system.gd:8  const NOISE_CHANCE_RUN
systems/prediction/world_delta.gd:52  const P_VARIANT
systems/prediction/world_delta.gd:53  const P_SUBSTRATE
world/controllers/capture_controller.gd:154  const EASE_FN
world/controllers/test_zone_controller.gd:224  const STROBE_SEQUENCE
world/level_graph.gd:18  const SEG_SIZE
world/room.gd:2058  const AIM_Z_GRENADE
world/tile_semantics.gd:62  var blocks_shadow
world/tile_semantics.gd:65  var stealth_modifier
world/tile_semantics.gd:66  var acoustic_dampening
```

### Signals with no listener (14)
```
ui/detonate_context_menu.gd:25  action_requested  (emitted, nobody listens)
ui/window_base.gd:7  close_requested  (emitted, nobody listens)
world/room.gd:5631  scenario_detonation_done  (emitted, nobody listens)
agents/agent.gd:18  posture_changed  (emitted, nobody listens)
geometry/board3d_live.gd:37  remesh_committed  (emitted, nobody listens)
geometry/edge_registry.gd:5  edge_registered  (emitted, nobody listens)
geometry/edge_registry.gd:6  slice_registered  (emitted, nobody listens)
geometry/slab_registry.gd:6  slab_registered  (emitted, nobody listens)
systems/lighting/light_registry.gd:24  light_registered  (emitted, nobody listens)
systems/lighting/light_registry.gd:25  light_removed  (emitted, nobody listens)
controllers/guard_coordinator.gd:7  guard_whistled  (emitted, nobody listens)
controllers/guard_coordinator.gd:8  guard_radioed  (emitted, nobody listens)
controllers/guard_coordinator.gd:9  alarm_raised  (emitted, nobody listens)
controllers/guard_coordinator.gd:10  all_guards_alerted  (emitted, nobody listens)
```

### Unused locals and parameters in live code (14)
```
geometry/board3d_live.gd:2932  The parameter "claim" is never used in the function "_glass_rim_record()". If this is int
geometry/prop_fragment_sim.gd:294  The parameter "i" is never used in the function "char_amount()". If this is intended,
overlays/glass_rain_overlay.gd:311  The local variable "pos" is declared but never used in the block. If this is intende
overlays/layout_overlay3d.gd:38  The local variable "tall" is declared but never used in the block. If this is intended,
systems/destruction/detonation_plan_builder.gd:1528  The local variable "cell_to_voxel" is declared but never used in th
systems/destruction/detonation_plan_builder.gd:1644  The parameter "deadline" is never used in the function "_phase_walk
systems/destruction/detonation_plan_builder.gd:1888  The local variable "delta" is declared but never used in the block.
systems/destruction/detonation_plan_builder.gd:696  The local variable "delta" is declared but never used in the block. 
systems/destruction/detonation_plan_builder.gd:782  The local variable "edge_registry" is declared but never used in the
systems/destruction/detonation_plan_builder.gd:783  The local variable "bomb_def" is declared but never used in the bloc
world/controllers/test_zone_controller.gd:816  The parameter "origin_gu" is never used in the function "_flight_clears()
world/roof_sheet_release.gd:90  The parameter "room" is never used in the function "wall_entities()". If this is intende
world/room.gd:4536  The local variable "material" is declared but never used in the block. If this is intended, prefix i
world/room.gd:9803  The local variable "written" is declared but never used in the block. If this is intended, prefix it
```

### Dead links (7)
```
PROMPTS/PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md:195  DETONATION_PERFORMANCE_MASTER_PLAN.md
PROMPTS/PLANNING/GLASS_MASTER_PLAN.md:64  RENDER_ORDER_MASTER_PLAN.md
PROMPTS/PLANNING/GLASS_MASTER_PLAN.md:2161  RENDER_ORDER_MASTER_PLAN.md
PROMPTS/PLANNING/GLASS_MASTER_PLAN.md:4192  ../../godot/scripts/overlays/shard_field.gd
PROMPTS/PLANNING/GLASS_MASTER_PLAN.md:4522  RENDER_ORDER_MASTER_PLAN.md
PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md:375  SOOT_STORAGE_REFORM.md
PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md:60  SOOT_STORAGE_REFORM.md
```

### Dev flags nothing sets and no doc names (21)
```
CAPTURE_EXTRA_WAIT_FRAMES CAPTURE_FACING CAPTURE_FOCUS_CELL CAPTURE_OVERLAY CAPTURE_POSTURE GLASS_CRACK_OPACITY GLASS_CRAZE_SHEET GLASS_CRAZE_TILE_VOXELS GLASS_SHARD RAIN_CROP RAIN_FRAMES
SCALE_3D_MODE SHOT_CONTROL SHOT_IMPACT_CELL SHOT_IMPACT_ZOOM SHOT_TRACER_FRAMES SHOT_WAIT_FRAMES SMOKE_FEATHER TEL_FILE TEL_LOGCAT WALK_PHASES
```
