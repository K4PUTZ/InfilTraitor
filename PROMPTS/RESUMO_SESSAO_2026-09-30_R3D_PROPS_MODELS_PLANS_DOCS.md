# Session 2026-09-30 — passage rule, firearms on props, real models, the Tier 4 and model-pipeline plans, the architecture rewritten

Commits `7cfc18dd..` (`git log 00e79a9a..HEAD`). Previous session: `RESUMO_SESSAO_2026-09-29_R3D_PROPS_DEBRIS_CHAR_THROW.md`.

## Ask (in order)
Continue R3D-PROPS from the open list: (1) a destroyed crate still blocks its GU; (2) firearm damage does not reach props; (5) `verify.py full` after the soot code went to base 6; (6) the new map on the Moto; (7) an old glass-demo crash. Then: the passage rule and plywood calibration; real models for the table and the pistol; a planning round (material source, colour, a generic voxel replacement, charred variety, shadows); then "formalise it, update the stale documentation, plan a model-input pipeline", and finally the answers to its four open questions.

## Built
- **Passage rule** (`7cfc18dd`, `6c2b85dc`): `Room._release_destroyed_prop_cells()` erases a collapsed crate's (or a shattered mesh prop's) GU from `_blocked_cells` IN PLACE (the turn controller and the guards share the dictionary); rule = at most 20% of the block's voxels standing (`prop_collapse_standing_fraction`, Director: "80% destroyed, usually more than one grenade"). Measured on PROPS: wood beside a grenade 65% destroyed (two grenades open it); plywood `destroy_factor` 1.0 -> 0.95 gives 85%; debris scatter 0.3 -> 0.45. The burn's consumption is inside the commit, so the percentages include it. The lamps' cached shadow map is not re-fed (same gap as a burnt wall).
- **Firearms on props** (`4ce8cd39`): `BlastCalculator.prop_shot_index` / `resolve_prop_voxel` / `plan_prop_impact` (one layer, never marked neighbours), wired into `AgentShotController` (plan, precook and fire); `_clear_orphaned_soot` no longer assigns null to a Dictionary (a latent error a prop voxel reached). Shotgun: 13 dented + 2 destroyed on a crate; pistol: 1 destroyed; the damage survives a rotation. `test_prop_shot_impact` covers the pure half.
- **Instruments:** `board_probe` now dumps `PropBlock`s (every map with a crate read "objects and store differ"); `ground_gate` PLAYGROUND `select` digests re-recorded (the map gained a crate at `086ddea2`; proved by disabling the prop pick: same digest).
- **Real models** (`ecf34cdc`): `PropDef.model` / `model_rotation_deg`, `MeshPropInstance`, `PropMesh3D.setup_model` (uniform fit into `mesh_size`, every surface keeps its colour/texture, registered with the board's light). Table: Poly Haven `wooden_table_02` (CC0, 1k); pistol: Quaternius Pistol_6 (CC0). Licences in `props/MODEL_SOURCES.md`; files in `ASSETS/props/` (local only).
- **Moto:** the release APK of `6c2b85dc` with the PROPS map ran (plywood blast: crate gone, soot crater, debris), `videos/props_moto_plywood.mp4` (local). The touch aim/pick tests are still manual.

## Verification
`verify.py smoke` PASSED after every code commit. `verify.py full` (editor closed, baseline re-taken after the probe fix): lint, invariants, codemap, selftests, ground, shot-3d, occ-canonical, mirror, probe-gate PASSED; **two reds**: (a) `board_probe roundtrip` PLAYGROUND rotation E-S-W-N, 2-4 soot texels at cell (216,24) — **bisected to `6d21893d`** (SOOT-ORPHAN-01; clean at its parent), 4 texels at HEAD with the charred tone; a `has_solid()` guard hypothesis did NOT fix it and was reverted; a task chip is open; (b) `pixel_gate` GLASS g1 2 px above the noise floor against a baseline of the SAME code (run-to-run variation; the other five captures 0 px). `_capture_glass_blast_demo` no longer crashes (already fixed).

## Decided (Director, 2026-09-30) — recorded as `ACTOR` D66-D69
- **D66** a prop model conforms to a SLOT (gameplay from the slot); colour/texture from OUR registry (surface -> material zone; `family`, `textured`, fallback own -> family generic -> `generic`; 8 materials to add); several models of one slot at once; a non-fitting model falls to the slot's generic; target scale the game's own.
- **D67** Tier 4 = 1/8 GU voxel fragments on a blast, ~0.5 s, persistent cosmetic charred pile (base-coord record, not store claims).
- **D68** `BoardLook.grade()` in the shaders, no full-screen LUT; contact shadows after the destruction exists.
- **D69** content is local and forgiving: cosmetic, never travels, no scripts in v1 (data-only `.iprop`; a scripted-mods tier is a possible later product decision), `.vox` = store containers, incompatible -> generic.
- **Charred variety:** shader-side `mix(c_min, c_max, h*h)` (defaults 0.10 / 0.30); the view-cell hash re-rolls on rotation until R3D-ROT.
- **First content:** a dormitory scene (`maps/DORM.map.json`), also the calibration room.

## Documentation done
`docs/ARCHITECTURE.md` rewritten (§0 layered picture, §1, §15, §16, appendix; the old file verbatim in `docs/history/ARCHITECTURE_PRE_R3D_2026-09-25.md`); `repo_structure.md` rewritten, `developer_setup.md` gained the day-to-day workflow; `ASSET_MAP`, `TEXTURE_CATALOG`, `rendering.md` bannered; new plans `PROPS_TIER4_PLAN` v0.3 and `PROP_PIPELINE_PLAN` v0.2; pointers/updates in `RENDER3D_MASTER_PLAN` (v1.50), `ACTOR_MASTER_PLAN` (D66-D69), `MATERIALS_MASTER_PLAN`, `DESTRUCTION_MASTER_PLAN`, `DEVICE_DIAGNOSTICS_MASTER_PLAN`, `MAP_MASTER_PLAN`, `MAPFILE_REFERENCE`, `VOXEL_MASTER_PLAN`, `ART_SPECIFICATIONS` (§5, §6), `DESIGN_MASTER_PLAN` (§17), `milestones.md` (ART-01), `technical_debt.md`, `current_state.md`, `docs/README.md`, `CLAUDE.md`.
Not re-audited: `ARCHITECTURE.md` §2-§14 and `docs/systems/*.md` (July 2026; bannered).

## Traps recorded
- A capture harness that quits after its own screenshot (`INFILTRAITOR_AUTO_SCREENSHOT=1` + `SCREENSHOT_ONCE`) never reaches a detonation: for a blast use `INFILTRAITOR_SCENARIO="...; detonate 0; frames 400; capture x; quit"` with `INFILTRAITOR_GRENADE_GUS` in VIEW coordinates, and the map named.
- `ground_gate.py --update` only PRINTS the new digests; the file is edited by hand.
- `verify.py` runs started in the background while another runs REFUSE ("another Godot is alive"); wait for the process, never overlap.
- `INFILTRAITOR_PROP_DEBUG` is an environment variable: it prints on the desktop, not in an APK (`DevFlags` does not carry it).
- Bisecting needs `git stash` for the working tree and the git-ignored `ASSETS/` stays put: it worked (each PLAYGROUND roundtrip ~2 min).

## Open
- The PLAYGROUND soot round-trip red (task chip). The build of everything in the two plans (none started). The weapon bench and the touch tests on the Moto. The 8 new materials' numbers (calibrated with the Director). The triangle cap (measured at PP1).

## Addendum — P1/P2: the voxelizer and the table replaced by voxels (Director: "pode seguir com o P1")
Built (`git log 960b2850..`): `PropModelFit` (the fit of a model into its box, shared by drawing and voxelizing), `PropVoxelizer` (Akenine-Moller triangle/box on the board's 1/8 GU lattice; a face lying exactly on a voxel boundary is slid a hair toward the model's inside, else a grid-aligned box grows a voxel on every side — found by the box selftest, not reasoned), `PropFragmentSim` (pure, deterministic by hash, fixed 1/60 s simulated steps), `PropFragments3D` (one MultiMesh, `prop_mesh3d.gdshader` + `use_color` + `soot_affects`), `Board3DLive` hooks, and in `Room` the trigger, the BASE-coord pile (`_base_prop_piles`, replayed after a rotation, `SaveState` round trip, running sims finished before a rotation/save). Selftests: `prop_voxelizer_selftest` (6), `prop_fragment_sim_selftest` (7), `save_state_selftest` (+pile). `verify.py smoke` PASSED.
- **Timeline as ruled:** logic at the commit, LOOK on the first frame after the flash (`Room.release_prop_breaks()` called by `TestZoneController` right after the flash clears; before that the cubes appeared BEFORE the flash peak, seen on the movie). The real table = 104 cubes (top + legs kept), ~0.57 s, 85% carved at ring 0, 16 cubes left.
- **Seen, on a desktop Movie Maker take** (`--fixed-fps 60 --write-movie`, frames extracted with `ffmpeg`): table intact -> flash (5 frames) -> the table as tan cubes in place, already tumbling -> carved and pushed -> a small heap of dark-brown charred cubes. Tuned by eye: outward push 3.0 -> 1.3 GU/s, and `soot_affects = 0` for fragments (the floor's soot darkened an already-charred cube a second time until it vanished against the crater).
- **Cost (desktop):** voxelize 2.5 ms once per model (warmed at board build), sim 0.02 ms/step, worst 0.07 ms. **Moto NOT measured.**
- **Not done / known:** the cubes are the material's flat colour (registry colour + facade = P5); the old chip/smoke burst still plays beside them; fragments land only on their own pile's lattice (they ignore the floor's holes and other props); the charred variety in the shader for walls (P4); prop shadows (P6).
- **Traps:** the `detonate` scenario step BLOCKS until the animation ends, so stills show only the end: use the Movie Maker take; `centre x,y; zoom z` must be repeated AFTER `detonate` (the camera refocuses on the blast); a new `class_name` file needs `godot --headless --path . --import` before the headless lint sees it; a `git stash` round trip is safe with untracked new files but the `update_docs.py` pre-commit step leaves `docs/` edits unstaged (and once re-tabbed `ARCHITECTURE.md`: reverted).

