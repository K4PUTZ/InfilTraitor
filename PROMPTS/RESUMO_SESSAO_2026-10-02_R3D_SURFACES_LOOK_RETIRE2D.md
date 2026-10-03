# Session record — 2026-10-02 (later): R3D-SURFACES built, R3D-LOOK started, the 2D audit

Branch work lands on `origin/main`. `verify.py full` PASSED (453 s) at the end, against a baseline taken at `5f642d03` (current code; see "Verification").

## Built
- **R3D-SURFACES S1-S5** (`RENDER3D_MASTER_PLAN`, R3D-SURFACES block): a material declares its upward-face surface per role (`surfaces.floor` / `surfaces.roof`: `photo` or `facade`, wall always facade); the `ground_decals` map section (`GroundDecals3D`: GU-sized floor marks on a half-GU lattice, a corner holds a quarter of the decal on each of four GUs; dropped with their floor via `Room.bump_world_revision()`, NOT via `voxel_destroyed`, which a blast never raises); roofs need no code (the plane is world-space); `check_surface.py` rejects a mirror-authored plane and runs in `verify.py quick`; Moto row (idle GPU 25.7-25.9 ms, FLOOR_ZONES_TEST, zoom 0.50; the decals' own cost NOT isolated).
- **ScenarioRunner:** an aborted scenario ends the desktop process with code 1 (a `shoot 0` on GLASS, which has no guard, used to hang until the harness timeout).
- **R3D-LOOK, shot marks:** the soot of a SHOT is one tone lighter (`SHOT_SOOT_LIGHTEN`); the halo (tried at 0.5) and the stronger bullet decal (tried x2.5 / x0.7) were reverted at the Director's request (the ladder stopped being centred, the struck voxel read lighter); both knobs stay neutral in code.
- **PLAYGROUND glass:** the three glass blocks became a box of 8 single panes + a glass roof (same 3x1 GU, 2 storeys). Two panes on one edge are refused by `EdgeExtractor`. Grenade and shots (pistol, shotgun, assault, sniper) take the pane physics (shatter, craze, fall).

## Rulings of the day (Director)
- Develop in LANDSCAPE desktop at the camera's NATIVE zoom; portrait for handset / performance / UI work, zoom only for bug hunts and design detail (memory `develop-in-landscape-desktop`).
- Fine tuning of decals and soot waits; the engine close comes first.
- Glass is REOPENED for the materials milestone: structural collapse (a pane or roof that loses its support falls, also after the impact), real blocks, the shard that left the world (`GLASS_MASTER_PLAN`, top block).

## Verification
`verify.py full` PASSED 453 s. Before that: `ground_gate` failed on PLAYGROUND's `select` digest (the glass box; walk, reach, paths and view counts unchanged; the old map still gave the old digest) and was re-recorded on purpose; the probe/pixel gates differed from the 2026-10-02 morning baseline (the box; the shot soot, 442 px) and were re-baselined at `5f642d03`; one `roof-yaw` boot hung 300 s and the gate alone passed in 16 s (a flaky boot, not reproduced). With the OLD map and the new code the probe gate passed against the old baseline.

## Open (planned, not started) — the 2D is NOT fully retired
Audit of 2026-10-02, code-verified. Plan: `RENDER3D_MASTER_PLAN`, block "R3D-RETIRE-2D".
1. The structure layer (`StructureLayer` in `godot/scenes/game/room.tscn`, `_prop_stack_layers`, `RoomBuilder._place`, `tile_registry.gd`, `tileset_blocks.tres`, the `structure_tiles` path of `MapCompiler`, `Room._wall_tileset`) is hidden and EMPTY: no shipped map and no code map feeds it. Delete it with a whole-repo grep per removal, selftests and `verify full`.
2. `GrenadeProp`, `FloatingCollectible`, `AgentProbeProp`, `TargetCursorOverlay` are still `Sprite2D` / `Node2D`; the grenade and the collectible reach the 3D board through `PropBillboard3D` from baked frames (`grenade_frames`; the export warning "Loaded resource as image file"). A 3D mesh replaces them (R3D-PROPS item).
3. Stay 2D on purpose for now: `explosion_flash_overlay` (full-screen), `guard_noise_indicator` (never shown, no emitter), `light_ray_overlay` (the golden shafts, R3D-LOOK L6, "a line from the lamp to the centre of each GU", easy).
Also open: R3D-LOOK L1-L5 (the marks, fine tuning, the per-run facade origin decision), the Moto row for the glass box and for turn cost after the final code, a decals on/off A/B.
