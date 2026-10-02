# Session record — 2026-10-02 — R3D-ROT / WORLD / ACTORS loose-ends review, and the open roundtrip soot divergence

## What the review found closed
- No reference left to `ActorBillboard3D`, `Spike3D`, `LIT3D`, `VIEW_DIRS`, `_set_view_camera_only`, `INFILTRAITOR_CAMERA_ROT`; `_active_perspective` survives only in comments.
- `_set_perspective()` is the camera's yaw plus uniforms, the props' view re-pick and the occlusion recompute. No re-layout, no store rebuild, no replay, no relight.
- ~30 stale comments in 18 files rewritten (a rotation is no longer a rebuild; the `_base_*` records are CHECKPOINT persistence).
- `ground_gate.py` reformed: E, S and W give the SAME digest as N for all four maps (the N digests are the ones recorded at R3D-END, untouched by R3D-ROT). It records one digest per map and requires every view to equal it.
- `verify.py smoke` PASSED (lint, invariants, codemap, 58 selftests, PLAYGROUND + GLASS boot, rotation E then N kept on purpose: ~10 ms and the only end-to-end proof that turning breaks nothing).
- Full-tier gates run one by one (no baseline taken): `shot_3d_gate`, `occ_canonical_gate`, `mirror_gate --single`, `ground_gate` PASS. `pixel_gate` and `probe-gate` were not run.
- The guard noise indicator call (`GuardCoordinator` -> `Room._emit_guard_noise_indicator`, a method that never existed) was replaced by a comment. Noise stays a later track; when wired its direction must use the view's axes (R3D-ROT item 5).

## CLOSED (same day, SOOT-TRUTH — see the end of this file): `board_probe.py roundtrip --with-store` FAILED on PLAYGROUND (3-7 soot texels after a SaveState restore)
Not caused by R3D-ROT: it fails identically at `96e138a9` (before it). The gate read 0 texels on 2026-09-24; the CHARRED tone (soot base 6) landed 2026-09-29, the likeliest source (hypothesis, not proven).

Measured (temporary logs in `scenario_save_restore()`, removed):
- Voxels 0/216 400, light 0: only the SOOT plane differs, on cells the board reads.
- `_soot_map` and the soot plane disagree in BOTH directions before the restore:
  - plane has soot, map has none: L86/L87 (303,24) plane 215 (= CHARRED, digits 5,5,5 in base 6), L80 (216,24) plane 0 (tone 0);
  - map has CHARRED (5), plane is clean (172): (216,24) at L81, L87, L88, L89.
  The restore projects the map, so each side becomes what the map says.
- The affected cells are all CHARRED or tone 0 beside one, and the exact set changes between runs (embers use randf), so it is not a deterministic write bug.
- Two writers feed the plane: `stamp_soot()` (map + plane together; shots and `absorb_scorch`) and the presenter/`DetonationEntryWriter` entries (`expose`, `dented`, `cracked`, `soot`) plus `_collect_soot_ramp`/`_soot_tick`, which write the plane from plan face codes. The E-CHAR block in `DetonationPlanBuilder._phase_soot` (~1548-1562) feeds the map through `scorch_writes`.
- `Room._clear_orphaned_soot()` (SOOT-ORPHAN-01, 2026-09-27) erases the map entry when a voxel is destroyed and never touches the plane.
- A tried fix, kept out: making `_clear_orphaned_soot()` return when `store.has_cell()` (another claim still occupies the cell). The gate went 3 -> 4 texels (the map then held CHARRED entries on cells whose plane showed clean), so the orphan clear is part of it, not the whole cause. Reverted.

## NEXT SESSION — plan
1. Take a deterministic reproduction: fixed seed for the embers (or log the char cell set per run) so the diverging cells are the same every run. The gate already prints them with `--first 10`; add a debug print of the map-vs-plane diff before the restore (the one used here, in `scenario_save_restore`).
2. For each diverging cell, find the writer: log every `_write_cell_soot()` and every map write/erase (`stamp_soot`, `_clear_orphaned_soot`, `_soot_map.clear()` at room.gd ~3860) with level, cell, code and frame. Classify into: plane-only writes, map-only writes, erase-without-plane-clear.
3. Decide ONE rule (design, ask the Director if it changes a look): the map is the truth and the plane its projection, so (a) every plane write for a stamped cell must have gone through the map, (b) when the map entry is erased the plane cell is rewritten from the map in the same step (or the erase is skipped while a claim still occupies the cell), (c) the ramp must settle on the map's value.
4. Fix, then prove it: `board_probe.py roundtrip --with-store` strict on PLAYGROUND (0 texels, over several runs because of the embers), `save_state_selftest`, `blast_purity_selftest`, `verify.py smoke`. A selftest that stamps CHARRED on a shared cell, destroys one claim and restores would pin it.
5. GLASS keeps its documented 1 light texel (rim cut), separate and known.

## Decisions (Director, 2026-10-02)
- Work on `main`, saving at the end of every round that finishes without errors; a new branch only in specific cases.
- Design questions wait until rotation is complete; noise is not touched now.
- Models: Sonnet, low effort, unless told otherwise.

## Not done / still open from the review
- Gates without a gate: touch picking from E/S/W, roof reveal under yaw, the `S` overlays (aim dome, throw arc, tracer) were seen only in captures.
- `layout_with_perspective()` stays only as the fixture of 5 selftests (floor_zone_bake, slice_geometry, voxel_persist, roof_entity, roof_bake): coverage, not a runtime path.
- `_base_*` records stay until `SaveState` serialises the `VoxelStore` (a stage of its own).
- Rifle has no grip (holds the shotgun); crouched / prone throws do not exist.
- `agent_live*.glb` are git-ignored: a fresh clone runs `r3d_live_rig_export.py` twice.
- `verify.py full` was not run as a whole and no baseline was taken.

## RESOLUTION — SOOT-TRUTH (2026-10-02, Director: "uma unica verdade, que sobreviva a saves e checkpoints")
Rule: `Room._soot_map` is the one truth (it is what SaveState stores); the soot plane is its projection and every writer follows it.
Measured with temporary logs on the two diverging cells (216,24) and (303,24), removed afterwards. Three writers had broken the rule:
1. **Erase without a plane clear.** `_clear_orphaned_soot()` erased the map entry of a destroyed voxel and left its tone on the plane;
   a restore (which projects the map) then read clean where the live board read 215 / 0. The erase now clears the plane in the same
   step, and keeps the scorch while another claim still stands on the cell (the cell is the key, so it is not orphaned).
2. **Stamping cells that are already gone.** A blast commits its destruction BEFORE `absorb_scorch()` stamps, so the ember CHARRED rows of
   the voxels it burnt away landed in the map and outlived them (a restore replay erased them, the live plane never drew them).
   `stamp_soot()` now drops a write on a cell no voxel stands on (`VoxelStore.has_solid`).
3. **Stamped cells no wave carried.** Standing voxels the map held CHARRED had no destroy / dent / crack / soot entry, so the plane stayed
   clean live and went black after a restore. `Room.settle_soot()` (fed by `absorb_scorch()`'s changed cells) runs at the ladder's last
   step and gives every stamped cell the map's tone, idempotently, inside the one upload the ladder already owes
   (`Board3DLive.on_blast_soot(extra_levels)`).
Evidence: `roundtrip --with-store` PLAYGROUND 3 runs, 3 texels before (4 after fix 1+2, deterministic), **0 texels in 3 runs after all three**;
GLASS keeps its documented 1 light texel. `soot_truth_selftest` pins each rule (mutation of fixes 1 and 2: 3 checks fail). `verify.py smoke`
PASSED (59 selftests). Not run: `verify.py full`, `pixel_gate`, a device run (the settle writes only cells whose plane differs).
Look change to judge: a CHARRED cell no wave carried now turns black at the end of the fade instead of staying clean until a restore.
