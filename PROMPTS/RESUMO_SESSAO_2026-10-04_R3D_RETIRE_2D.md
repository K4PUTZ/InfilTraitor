# Session record — 2026-10-03 / 04: R3D-RETIRE-2D built

Work landed on `origin/main` (last commit `607e9eea`). `verify.py full` PASSED (470 s, 16 steps) after the last change; the handset matrix with this code is NOT run (the Moto g04s was online at the end, nothing run).

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

## Open (none blocks R3D)
1. The handset matrix (Moto g04s, Galaxy A16) with the final code: the stencil and the second overlay pass on Mali, the meshes, the glass box. If a handset charges the overlays' second pass, the fix is local (a `next_pass` only where a pane can be).
2. The detection label above a guard (dev vision) was verified numerically, not in a capture.
3. R3D-LOOK L1-L5 (fine tuning waits), R3D-CLAIMS (~100 MB of `Voxel` wrappers on the Moto), R3D-BUFFER.
