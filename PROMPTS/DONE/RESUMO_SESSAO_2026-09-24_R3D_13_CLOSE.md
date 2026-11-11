# Session summary — 2026-09-24 (second session) — R3D-13 closed, the shot pre-cook restored, R3D-END's entry gate written, R3D-14 built

**Resume point:** R3D-8 to R3D-14 are BUILT and gated (plan v1.25). **R3D-END is NOT started: it needs only the Director's ratification** on the deletion list (`RENDER3D_MASTER_PLAN` §R3D-END).
Its entry gate, `python3 tools/persistent/independence_gate.py`, reads PASS. First step of R3D-END, when ratified: split `VoxelRenderer` (`ground_plane_level`, `relative_level`, `top_wall_level`, the light apply and the level registry
move to a neutral owner), before anything is deleted. The earlier session of the day is `RESUMO_SESSAO_2026-09-24_R3D_8_A_13.md`.

## What the Director asked, in order
1. Continue with R3D → chose "close R3D-13 first" over starting R3D-END or R3D-ACTORS. 2. The Galaxy A16 was connected → record its row and explain the 3D shot tail. 3. "Religa o pre-cook na 3D e checa se precisa de mais alguma coisa antes do END."
4. "Sim, começa a R3D-14." 5. "Vamos documentar tudo e encerrar a sessão."

## Commits (all pushed, `main`)
| commit | what |
|---|---|
| `e5b5f9ca` | [R3D-13] the three finished spikes deleted (`board3d_spike`, `r3d4a_actor_spike`, `store_layout_spike`, scenes, the `SPIKE=` hand-overs, the `store_spike` step); `spike3d.gd` stays for R3D-ACTORS |
| `b0f73d6b` | [R3D-13] the cook's light from a per-CLAIM occupancy; the cook gate reads the planes on 3D; `board_probe roundtrip` compares planes where the board reads them; `relight` scenario step |
| `01188e6a`, `e1d4225b` | [DOCS] plan v1.22 / v1.23, decals measured on 3D, the Galaxy baseline and the shot-tail explanation |
| `2d88472e` | [R3D-13] the shot pre-cook runs on the 3D board again |
| `b438309e` | [R3D-13] `independence_gate.py` written, RED on GLASS, plan v1.24 (R3D-14 named) |
| `8c8723c0` | [R3D-14] the glass state lives in the `VoxelStore`; the hidden glass layers are never built or written under the 3D board |
| `8f7ce12d` | [DOCS] plan v1.25, the Galaxy R3D-14 A/B |
| (this close) | [DOCS] `CLAUDE.md` rows, `current_state.md`, this file, memory |

## 1. The two plane findings of R3D-8, traced (`b0f73d6b`)
- **Cause.** `DetonationPlanBuilder._phase_light` built the post-blast occupancy by erasing every CELL in `blast_cells`. A box corner or junction column is held by two claims and the plan destroys them one at a time, so the first claim destroyed emptied a cell the committed world still holds:
  cook vs a full relight **21 and 13 cells apart** on PLAYGROUND's two grenades (predicted vs real occupancy 9 and 17 cells apart). Now `VoxelStore.occupancy_dict_after(gone)`, per claim, from the Delta's projections: **0 and 0**. `voxel_store_selftest` TEST 6, sabotaged.
- **The gate that could not fail.** `INFILTRAITOR_LIGHT_COOK_GATE`, `LIGHT_EQUIV` and the shot-scope probe snapshot through `Room._perf_snapshot_alts()`, which walked `TileMapLayer` cells: on the 3D board it read the 2 240 glass cells and printed `0 of 2240 ... PASS`.
  It reads the planes now (211 154 cells). **Any instrument that reads a tile layer is vacuous on the 3D board.**
- Also: the SaveState restore scenario skipped the relight a rotation runs (fixed); the incremental light writers leave a bucket on cells a blast emptied (3 103 texels after PLAYGROUND's shot; never read; counted, not compared); `_soot_map` holds tone 0 on cracked glass the live wave never paints (never read: no glass shader samples either plane).
  `board_probe roundtrip`: PLAYGROUND rotation and restore IDENTICAL, planes included, strict by default; GLASS 1 light texel left.

## 2. Decals on the 3D board, measured
A decal variant missing from disk is SILENT on both boards (no message at boot; the old "hard error (B6)" lives on the baked path, which is off by default). `check_decal.py` and `voxel_decal_selftest` catch it. **`.gitignore:66` ignores `ASSETS/materials/*/*`: the art is not in git.**
R3D-14 gave `Board3DLive._build_decal_catalog()` its own loud-fail (`push_error` for a partial family, a file that is not 256x256, one that will not load; a clean boot prints none).

## 3. The Galaxy A16 baseline and the shot tail (`DEVICE_DIAGNOSTICS_MASTER_PLAN` top blocks)
- Same APK as the Moto's row, 3D vs 2D: load 7.9 / 8.0 s vs 23.3 s; PSS 1.30 / 1.33 vs 2.20 GB; idle 25.2-25.6 vs 39.5-42.4 ms/frame; a detonation mean of 32.0-36.7 ms vs 70.6 / 83.2. **The Galaxy is slower than the Moto on GPU-bound rows** (idle 25 vs 19 ms, 2.2x the pixels) and 2x faster on load.
- **The 2026-09-21 tail gap (357 vs 214 ms, one boot) does not reproduce** (pistol at brick, fresh board: 3D 188 vs 2D 164 ms, mean of three). **A real one does:** a shotgun after two grenades, 3D 413-439 vs 2D 223-261 ms. Cause, by an on-device A/B (same HEAD APK, one line changed, alternating installs, three boots each):
  R3D-10 made `Room._run_shot_precook()` return on the 3D board because it "mints 0 alternatives there", and it was also building the shared light field for the predicted world in the aim window: **419.0 / 420.8 / 413.7 -> 218.9 / 224.5 / 273.8 ms**, level with 2D's 223.0.
  Restored on the Director's word (`2d88472e`): final A/B 418.8 -> 223.3 (settled pair; two noisy pairs 663 -> 418 and 756 -> 221, cause not established), `SHOT_SCOPE_PROBE` 0 differ of 210 749 cells (real on 3D since §1), desktop tail 164 -> 113-117 ms; the pre-cook takes 383-406 ms in the aim window.

## 4. The R3D-END entry gate: `tools/persistent/independence_gate.py` (`b438309e`, reworked in `8c8723c0`)
Runs the real game twice per map, the second time with the hidden 2D board EMPTIED (`drop2d`) after every step that rebuilds or blasts it, and requires: STATE (roundtrip dumps, keep vs drop, identical), PIXELS (`pixel_gate`'s cases, 0 px above noise 8), EMPTY (every `drop2d` reports 0 cells) and a CONTROL (the same GLASS pixel case in `GLASS_STATE_LAYER=1` mode must lose >= 100 px, so the gate can fail).
**First run: RED.** PLAYGROUND identical; GLASS identical in every dump but the PICTURE lost the crack and craze webs after a blast (**19 391 px g0, 10 881 g1**, exact on a second run), because `_build_crack_occupancy()` and the opening walk read `_glass_layers`.

## 5. R3D-14: the glass state leaves the tile layers (`8c8723c0`)
- `VoxelStore.pane` (per claim: 0, or the pane's face + 1; a slice on its face band-resolved, a glass INTERIOR slab on NW, never a CEILING/FLOOR slab or a column) with `glass_pane_face_at()` / `has_glass_pane()`; a cell two panes hold answers for the LAST visible one (the layer's last-writer-wins). TEST 7, sabotaged.
- `VoxelRenderer.glass_state_from_store()` (3D board and not `GLASS_STATE_LAYER`): the crack occupancy, the presence queries, the opening walk, the remnants, `erase_glass_cell` and `count_glass_shards` read the store; the initial glass placements and both dirty passes skip glass like any other voxel and run `_render3d_glass_gone()` (light, ghost, the two glass seams, a once-only `voxel_destroyed`).
  `GLASS_STATE_LAYER=1` puts the layers back (the A/B control; **kept until R3D-END, the gate's control needs it**).
- **A/B store vs layer, same binary:** `glass_compare` identical at load on GLASS, PLAYGROUND, PLAYGROUND_2, RENDER_ORDER; 19/19 roundtrip dumps identical; pictures 0 px above noise on PLAYGROUND load/g0/shot, GLASS load/g0/g1 and a pistol shot at glass + a rotation E and back. The store keeps 3-6 corner cells the layer had lost when ONE of two panes was destroyed (the store is right).
- **Gate RED -> GREEN:** GLASS g0 19 391 -> 0 and g1 10 881 -> 0 px; the hidden board 2 240 + 2 240 / 6 240 + 6 240 cells -> **0 at all 19 `drop2d` steps**; 19 dumps identical; the layer-mode control still loses [19 391, 10 881].
- **Galaxy, GLASS, two grenades, same APK +/- flag, alternating x3:** the worst (COMMIT) frame **722 / 705, 695 / 689, 692 / 682 ms with the store vs 919 / 965, 910 / 962, 897 / 937 with the layers**; the 2nd grenade's mean 34.4-35.3 vs 37.3-38.7; load 3.9-4.4 vs 4.3 s; native heap 476-482 vs 487-491 MB.

## Evidence at close (last code commit `8c8723c0`)
`project_lint` clean; `run_selftests` 64 clean / 0 failed; `check_invariants` OK; `board_probe` gate, shadow, roundtrip PASS; `pixel_gate` PASS; `shot_3d_gate` PASSED; `mirror_gate` PASS; `occ_canonical_gate` all identical; `independence_gate` PASS with its control.

## Traps this session found
- **A gate can pass vacuously on the 3D board** (tile readers). Read the population it prints against the board's. A state gate needs a pixel gate beside it.
- **A skipped function has side effects the skip loses** (R3D-10 / the pre-cook). List them before skipping.
- **When a fix makes the probed thing not exist, the control inverts** (the gate's "drop2d emptied something" became "it holds 0 cells"): rebuild the control, do not delete it.
- The decal art is git-ignored: `git checkout` cannot restore a file moved for a test. Copy first, `cmp` after.
- Experiments that patch source: assert every replace matched (two silently did not and the runs were unpatched), diff the tree clean afterwards, and compare the compiled `.gdc` in two APKs to prove a patch is in. `REPAINT_PROFILE` is env-only (desktop).
- zsh does not word-split `set -- $M` (a Godot run hung on a garbled map id); macOS has no `timeout`; a `cd` inside a command moves the session's cwd. Put device runs in bash scripts. The first boot after an install is noisy.

## Open, not fixed (none blocks R3D-END)
- GLASS: 1 light texel, L88 (39,103) 7 -> 8: the glass opening's rim cut destroys a pane voxel at commit that the Delta never projects (cook gate 1 of 106 809 on grenade 2).
- A GLASS blast's COMMIT frame is still ~700 ms on the Galaxy with the store: not decomposed (R3D-LIGHT). The R3D-LIGHT list also holds `apply_light_field_cells()`'s buckets on cells with no visible voxel (-10 ms on desktop) and the map-wide `occupancy_dict()` walk (66 ms on 3D vs 40 on 2D after grenades, unexplained).
- The Moto halves of the pre-cook A/B and the R3D-14 A/B (the phone was not attached); the SE face of the reference set; `_soot_map` tone 0 on cracked glass (design call, unread).
- The 2D board's cook gate passed with the same predicted-vs-real occupancy difference: unexplained (it retires).

## Housekeeping
The Galaxy had `export/r3d14.apk` installed and every run script ended by removing `dev_flags.cfg` from it (the phone was unplugged at close: not re-verified; clear it before a hand run). `export/` (git-ignored) holds `r3d13.apk` (the Moto baseline APK) and `r3d14.apk`; the intermediate A/B APKs were deleted. Device logs are in `docs/measurements/` (git-ignored). `CLAUDE.md`'s RENDER3D and DEVICE rows and `docs/production/current_state.md` were brought up to date.
