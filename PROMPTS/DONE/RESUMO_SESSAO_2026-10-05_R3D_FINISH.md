# Session record — 2026-10-04 / 05: R3D-FINISH (the engine closed before gameplay)

Work landed on `origin/main` (last commit `4571ebd4`). Every code round closed with `verify.py full` PASSED and the pixel gate at 0 px.

## Ordered with the Director
Close the engine before gameplay. The table of the next rounds is the top block of `docs/production/roadmap.md` (single source); the engine half is `RENDER3D_MASTER_PLAN` v1.61 (R3D-FINISH, F1-F4).

## Built
- **Round 0 (handsets):** Moto turn and PSS with the final code (no regression); Galaxy A16 measured and a blast regression found: the NEGATIVE flash drawn cold cost ~190 ms on the first blast of a session. Fixed with a 2 s invisible warm draw (`ExplosionFlashOverlay.warm()`): Galaxy grenade 0 worst frame 231-343 -> 74-108 ms; confirmed on the Moto.
- **Round 1 (the last 2D):** nothing to build; the light shafts were 3D since RETIRE-2D and `GuardNoiseIndicator` was deleted in RETIRE-3. `canvas_gate` PASSED. Docs corrected.
- **Round 2 (R3D-BUFFER, simplified):** every map `buffer 5`, each ring cell takes the ground of the nearest playable cell (`MapCompiler._buffer_floor_zones`), no objects. Every raw coordinate moved +4 per axis: 11 tools and gates corrected and re-recorded with evidence. Step 2: the ring gets no deep slab (-48 640 claims on PLAYGROUND).
- **Round 3 (R3D-CLAIMS, C1-C4):** `VoxelContainer` (FULL / RELEASED / CELLS), handles with one identity per claim, `ClaimGrid` instead of `cell_to_voxel`, generators write cells. Moto: PSS peak in the blast scenario 1 169-1 210 -> 945-967 MB, load peak 1 143-1 158 -> 914-934 MB, `[VOXEL-STORE] built` 1 264-1 829 -> 781-807 ms, frame times unchanged.

## Lessons recorded
- A "resources still in use at exit" line is a leak signal (a RefCounted cycle), not noise: `smoke-boot` caught the one this session made.
- A pixel difference after a change that should not move pixels needs its cause found by a control (the facade forced flat, buffer 1 vs 5); two hypotheses were tested and one change reverted.
- A boot gate that reads hard-coded raw cells goes silently vacuous or wrong when the map's buffer changes: the grenades of PLAYGROUND would have landed inside the blocked ring.
- A `Monitor` whose command contains the text it waits for (`pgrep -f verify.py`) matches itself and never ends.

## Open
1. **Galaxy A16:** not measured with the ring and R3D-CLAIMS.
2. **Glass track:** the second grenade's COMMIT, 632-660 ms on the Moto and 269-331 ms on the Galaxy (the PLAYGROUND glass box of 2026-10-02); changes the effect's timing, the Director's call.
3. **Round 4 (next):** R3D-LOOK L1-L5 and R3D-SURFACES art; the Director's eye, graded against captures.
4. Observation, unverified: a gun mesh floats over the ring in desktop captures, most likely the target cursor following the offscreen mouse.
5. Calls still open: archive the closed plans to `PROMPTS/DONE/`; JAMES stays unused for now (Director, 2026-10-04).
