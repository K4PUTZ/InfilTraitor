# Session record — 2026-10-03 / 04: R3D-RETIRE-2D built

Work landed on `origin/main`. `verify.py full` PASSED (470 s, 16 steps) after RETIRE-7; after the two device-found performance fixes (below) a final `full` was run at the end of the session (result in the last section).

## Built (commit order; each has a block in `RENDER3D_MASTER_PLAN`)
- **RETIRE-1** the structure layer, `RoomBuilder`'s tile path, `tile_registry`, `tileset_blocks.tres`, `build_tileset` (7 builder selftests lost their layer setup; `ground_grid` / `iso_projection` build the 256x128 isometric `TileSet` in code, so they still prove `GroundGrid` against Godot's own `TileMapLayer`).
- **RETIRE-2** `ObjectMesh3D` (a free-moving model on the board, driven by the same `screen_position` / `flight_px` the sprite got): the grenade (`Grenade.glb`), the pickups (the pack's guns) and the virtual grenade cursor are meshes. `PropBillboard3D`, `AgentProbeProp`, the frame cache and the billboard shaders deleted. New dev step `throw <i> <x,y>`.
- **RETIRE-3** the bake tooling (9 Godot spikes, `CollectibleBakeConfig`, 8 `s2_*.py`), `WeaponBenchController`, `GuardNoiseIndicator`, `AgentSprite` -> `ActorPose` (a `Node`); `actor_bakes/` (56 MB, never in git) deleted at the Director's word.
- **RETIRE-4** the guard's smooth cone is computed on request, not inside a 2D node's `_draw()` (hiding the node had removed the 3D cone).
- **RETIRE-5** `canvas_check` / `aim` steps and `canvas_gate.py` (in `full`); it found a REAL bug (tracer, trail, noise, ceiling lamps, occlusion overlay and the F3 ruler were never attached to the board on a first boot); the overlays' 2D fallbacks and `CircleField` / `ShardField` deleted.
- **RETIRE-6** the agent's and the guard's direct draws (cover ring, patrol route and detection label now on the board). **RETIRE-7** `VisionTiles` and the light shafts.
- Also: `PaintPalette` (`material@paint`, olive-drab grenade; a repaint is one shader parameter write), a per-material light `contrast` (grenade 1.8), ground overlays fade behind glass (stencil: the pane writes 1, a second overlay pass draws at 30 %), the `look` tier and the retry of a boot step in `verify.py`, `NODE_CENSUS` flags an overlay painting the canvas.

## Rulings and findings of the session
- The boot gates hung about every other run while the Mac was reached through Chrome Remote Desktop; with it closed, three runs in a row passed (a hypothesis, written in `verify.py`'s header). The host process runs all the time, so a process check cannot detect a session.
- `hint_screen_texture` is copied before the transparent pass: a glass pane covers a transparent overlay drawn before it entirely. Hence the stencil.
- The Director wants fewer repeated gates now: default is `smoke`; `look` for a look change; `full` to close a stage.
- Kept 2D by design: the HUD, the explosion flash, `VfxDrawProbe` (a perf probe) and the 2D COORDINATE SPACE.

## The Moto g04s with the final code (2026-10-04; the numbers are in `DEVICE_DIAGNOSTICS_MASTER_PLAN`'s top block)
- Idle +0.7 ms (zoom 0.75 / 1.0) and +1.5 ms (0.5) against END-8: the overlays' second pass and the stencil, inside the budget.
- **Two blast regressions that pre-date this session, found because the handset was finally run:** (1) the commit frame recomputed the GU ring flood for the Tier 4 prop effects, 545 ms (R3D-PROPS, 09-28): now carried on the `WorldDelta`; grenade 0 worst frame 650 -> 100-117 ms (END-8: 263). (2) `GlassFall.build_surface_index` once per shattered pane, a 1 111 ms step in the cook next to the glass box: one index per blast, ~540 ms; the rain's FNV-1a hashes continue from the shared prefix. State and pixels identical after each.
- Added to the code on the way: `_prof` labels in the Tier 4 prop block (`THROW_PROFILE`).

## Open (none blocks R3D)
1. **Glass track:** the second grenade's COMMIT, 648-769 ms on the Moto (desktop: `claim_glass_craze` 73 ms, `spawn_glass_rain` 83 ms for 712 flights, rim shards 10 ms): spread the rain and the crazes over frames (changes the effect's timing: the Director's call). Waits until R3D is closed.
2. **Devices:** the Galaxy A16 (`R5CY8122K7D`) was not run; on the Moto still owed: a camera turn with the final code, heat vision's tile-risk overlay (dev only), PSS against END-8 (the `MEM-POLL` lines are in the logs).
3. The detection label above a guard (dev vision) was verified numerically, not in a capture.
4. R3D-LOOK L1-L5 (fine tuning waits), R3D-CLAIMS (~100 MB of `Voxel` wrappers on the Moto), R3D-BUFFER.
5. Housekeeping: `docs/production/current_state.md` carries a modification that is not from this session (it was committed once by `git add -A docs`, 7 lines; check it); `export/retire2d.apk` is left on disk; the string "10 voxel TileSet built" in `voxel_board.gd` is cosmetic.

## Final verification
`verify.py full` PASSED (467 s, 16 steps, including `canvas`) at the end of the session, after the two performance fixes; the pixel gate 0 px at all six points against the baseline of `b63ebb20+dirty` (re-taken after the lamp's 3D edge).
