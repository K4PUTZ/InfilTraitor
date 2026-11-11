# Session record — 2026-10-05 (later): R3D-LOOK

**Outcome:** R3D-LOOK closed by the Director. Every item below was judged by the Director's eye on a real capture or a 60 fps video; the repo state is `main` at `5d7b9c3f` plus this record.

## Built
| Item | What | Where |
|---|---|---|
| L1 marks on a wall | `decal_wall <material> <gx,gy>` scenario step (every decal of a material on one wall); the DENTED pit is a bowl (octagon rim, 4 rings, `DENT_RINGS`); brick, concrete and stone decals filled with CC0 photo crops and a canvas-edge alpha window (`gen_brick_decals.py --material`, `gen_crack_decals.py`); contrast measured by compositing each decal over the wall's mean colour: brick 3-10 % -> 12-42 % | `room.gd`, `scenario_runner.gd`, `board3d_live.gd`, `tools/asset_generation/` |
| item 3 floor / burnt | side faces below the ground plane and tops below the walkable floor are flat colour and darker (`pit_dark`), `FLOOR_DEPTH_DIM` softened, a blast's top-face decals charred by the shader (`floor_char`), the soot of a floor top blends the 4 nearest cells (`soot_smooth`) | `board3d_live.gd`, `voxel_board.gd` |
| item 2 spark anchor | one impact point (`voxel_face_point`, `particle_pair`) for tracer, sparks, smoke, chips and decal; one burst per impact; sparks in a cone back at the shooter; brick profile; the sand trickle (grains as 1x4 px dashes at 50 %) on concrete, stone, brick | `room.gd`, `agent_shot_controller.gd`, `smoke_spark_overlay.gd`, `debris_overlay.gd` |
| item 7 reveal silhouette | colour by faction (`REVEAL_PALETTES`), `GuardEnemy.faction`, `GUARD_REVEAL` on by default | `actor_mesh3d.gd`, `guard_enemy.gd`, `room.gd` |

## Decisions of the Director worth keeping
- Metal and wood decals stay as authored: a vector redraw of the metal set was judged worse than the original and reverted (`ARCHIVE/metal_decals_2026-10-05_optionA/`). The wood originals already covered the proposal's option A.
- Rules are generic, never per material (crater flat colour, charred floor decals).
- Non-CC0 references carry a trailing `(c)` in the file name; scripted downloads from unverified sites are not done.
- Per-run facade origins: not built (the 3D board is already position-based).

## Instruments made on the way (in the scratchpad, not in the repo)
A crater capture (`INFILTRAITOR_GRENADE_GUS` + `detonate 0` + `place_guard` the nine guards away), a shot video (`--write-movie --fixed-fps 60`, `INFILTRAITOR_SHOT_SETTLE_FRAMES=1`), a per-decal contrast measure. The recipes are in `RENDER3D_MASTER_PLAN`'s F4 entries.

## Evidence discipline
- Two commits went out with a stale CODEMAP (the pre-commit hook regenerates it and leaves the working tree modified): read `verify.py`'s result BEFORE committing.
- A pixel gate cannot see any of this (all of it is look); the checks were captures, videos and measured contrast.

## Handset cost (measured at the very end)
See the F4 handset-cost entry in `RENDER3D_MASTER_PLAN`: the soot smoothing is the one expensive piece (+5.8 ms GPU as first written, +3.6 ms after the 2-fetch rework, first grenade 32.9 ms of 33.3). Closing R3D-LOOK before measuring was a mistake; the decision on the smoothing (keep, default off, or bake into the plane) is open.

## Open
Handset cost of the dent bowl and of the soot smoothing (unmeasured on the Moto and the Galaxy); metal / wood option B; the dent pits are vector blobs; R3D-SURFACES art; JAMES stays unused.
