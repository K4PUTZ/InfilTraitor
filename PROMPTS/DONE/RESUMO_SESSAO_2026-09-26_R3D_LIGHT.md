# Session 2026-09-26 (later) — R3D-LIGHT, criterion 100 ms

Director: "Vamos com R3D-Light, usando o criterio de 100ms". Closed by the Director ("Vamos deixar assim por agora. Pode fechar."), with the caveat below. Full record: `RENDER3D_MASTER_PLAN` v1.30 block. Logs local `docs/measurements/device_2026-09-26_moto_*` (git-ignored).

## Result on the Moto g04s (PLAYGROUND, two grenades + shot; original -> final)
- Shot tail 526 -> **68 ms**. Detonation worst frame 256 -> **~101-107 ms** (four grenades, two boots).
- COMMIT 238 -> 94-101; presenter start 228 -> 81-98; LIGHT first frame 155-170 -> 77-90; cook pump max 143 -> 80-96.
- Not met to the letter: the worst frame sits at 100.7-107 ms (the second grenade's first soot-fade frame).

## What was built (commits `ad5ba534` .. `a2523a24`)
1. Incremental occupancy (store journal, live dictionary, stale set from changes, `occupancy_live_after`).
2. `print_census` / passage report off in release (`BLAST_REPORT=1`); `PredictionReaper` (releases the cook state 3 ms/frame; drains ONLY `cell_to_voxel`); `GlassOpening.warm_coverage()`.
3. Cook LIGHT phase resumable; soot ramp and VFX schedule prepared ahead of the commit; VFX dispatch budgeted (8 ms/frame).
4. Bucket journal in `VoxelBoard` (no plane walks in `play_consequence_light`); soot wave derives the buckets the apply reads.
5. Shot: light field names occupancy differences by flips (`TRACKED_LIVE/PRED`, `_stale_from_parity`); pre-cook warms the stale set's buckets; predicted copy released by the reaper.
6. Glass flush in the channel's second frame, with a second remesh only when rims shaped glass; crater stays in the commit frame (Director rejected the crater two frames late).

## Lessons (each cost a wrong step)
- Step 1 regressed the shot's `field.build` (12.5 -> 23.8 ms) and was called noise; it was a full-diff fallback. A number that moves is a finding.
- The 143 ms frame was the reaper's own single `erase()` of a 200 000-entry dictionary; `keys()` on it was also ~100 ms. Iterate the first keys.
- Draining a dictionary EMPTIES it: a shared member broke `LIGHT_COOK_GATE` (5 295 / 206 cells). Allow-list only what the builder alone holds. Removing "redundant" `note_external_write()` broke the same gate.
- Two uploads of the cell planes in one frame waited 375 ms on the Moto.
- Frame labels of `[E-FRAME]` do not name the heavy frame; a per-frame hitch timeline with timestamps did.

## Open / not done
- **`verify.py full` was NOT re-run on the final ordering** (a run on `3d31bfeb` PASSED, 442 s, against a baseline older than the session; the Director declined a re-run at close). The pixel gate cannot see timing changes.
- The Galaxy A16 was not measured. Only one boot per intermediate step.
- Remaining over-100 frames: second grenade soot fade first frame (~107), first grenade COMMIT (~100). Options in the plan.
- Tools left behind: `INFILTRAITOR_OCC_LIVE_PROBE`, `REPAINT_PROFILE` as a DevFlag, `BLAST_REPORT`.
