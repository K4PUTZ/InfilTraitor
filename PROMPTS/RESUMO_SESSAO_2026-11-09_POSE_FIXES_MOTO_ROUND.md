# Session record 2026-11-09: the pistol's quarter turn found, the elbows closed, the owed Moto and desktop round

## Done (all on `main`)
- **PLAYGROUND lost its two loose glass panes** (gu 25,8 and 29,8; Director): glass is the block like every other material. The fabric panel at 33,8 stayed; POIs `pane_se` / `pane_sw` went with the panes.
- **The pistol came out rolled 90 degrees in the game, right in Blender.** `pistol.glb`'s mesh node is rotated -90 degrees about X, and the pose lab only divided its SCALE out (`prop_world_g`, `extract`), so the game, which instances the whole scene, applied the turn again. `prop_node_matrix()` now reads the node's whole transform from the glb. A first fix the same day (`daf0011d`, the draw stop's hand and grip) was real but did not address this.
- **The draw stop holds the pistol as the aim does**: same grip, same fingers, the barrel pitched up 46 degrees, on both figures. The forearm takes the twist so the wrist does not wring.
- **The gap at the elbows was a real displacement**: the aim `.blend`s had a location on both forearms (5.2 cm right, 4.6 left), already present in `POSE_aim_pistol_MALE_HAND_v1.blend` (origin not established). The game plays rotations only (and the Hips' place), so its arms differed from Blender's. Locations zeroed, arms re-solved with the true lengths on both figures (wrists and pistol moved 0.0, gaps 0.0), and `extract` now warns about any moved joint but the Hips.

## The owed round, Moto g04s, release APK of `2e0661c5`, `MAX_FPS=0`, portrait (raw logs were disposable, `temp/measure_2026-11-09/`)
| Item | Before | During | Reading |
|---|---|---|---|
| Aim layer + pistol, PLAYGROUND | 19.55 ms, GPU 17.9 | 19.55 ms, GPU 17.9, render CPU +0.55, PSS +0 | no measurable cost |
| Shot menu opening (A/B) | | process spike 72-130 ms per opening with the Tripo figure, 79-134 with `TRIPO_FIGURE=none` | the MENU's, not the layer's; once per opening; not investigated |
| Oil burning, PIPE_LAB | 19.8 ms, GPU 17.9 | 30.1 ms, GPU 20.0 | was 29.2 on 2026-10-19; about 3 ms under budget, the tightest thing measured |
| `VoxelFire`, LIQUIDS_LAB's box in the lava (43 voxels: 38 eaten, 5 charred, over 3 turns) | | turn frames 56-58 ms; the same lab's later turns with no fire 27-61 ms | no spike of its own. The 256-voxel cap is NOT measured |
| Fresh holes + rubble, 5 shotgun rounds on the concrete wall | 19.4 ms (first shot settled) | 19.7 ms, GPU +0.3, +4 300 prims | fits. A shot's tail 21-62 ms; 70-133 ms longest process in a shot's window |
| STRESS, sequential | | blast 1: commit 143, glass tail 11, worst 167 ms; blast 2: commit 162, glass tail 170; PSS peak 1 057 MiB | every hit-stop stage under its 200 ms ceiling |
| STRESS, overlap | | blast 1: commit 82, tail 24, worst 188 ms; blast 2: commit 135, tail 147; PSS peak 1 013 MiB | every stage under 200 ms; 0 ERROR |
| STRESS, `HIT_STOP=0` (control) | | blast 1 worst 96 ms; PSS peak 1 026 MiB; 0 ERROR | |

The 2026-10-07 baseline for the glass grenade was stages 475 / 207 / 740 / 803 ms, worst 907, control 1 869.

- ⚠️ The hole row's first-shot jump (17.7 -> 19.7 ms, +30 objects) is NOT the holes: `SHOT_AGENT_CELL` / `SHOT_GUARD_CELL` teleport the actors into the frame at the first `shoot`. Read the row from the first settled shot.
- ⚠️ `stress_scenario.py`'s `--device` path works (it was untested). It reports one `detonation` line per run, the first blast's; the second blast is read from its hit-stop lines.
- ⚠️ STRESS is denser than a segment (24 guards; a segment may not exceed HEAVY), so its PSS is not held to the 1.0 GiB ceiling, but the sequential run does cross it (1 057 MiB, polled every 5 s).

## Desktop
- The GLASS smoke boot: 16 boots in a row, 16 PASS. The intermittent failure did not reproduce (the only recorded one, 2026-10-12, predates the worker race fixed on 2026-10-19).
- `technical_debt.md`'s "GLASS g1 pixel gate is intermittent" was already found and fixed on 2026-10-09 (`pixel_gate.py` header); the entry is marked.

## Not done / not verified
- **The Galaxy A16** was not connected: everything above is the Moto only.
- **PB Q5** is the Director's decision (is a few seconds of load between segments acceptable), not a measurement; the numbers are in `PERFORMANCE_BUDGET` §0g.
- The hero v5 costume's handset cost is obsolete: that model is gone (`ACTOR` D85, D93, D105 measured its replacements).
- `verify.py full` was not run; `smoke` passed after the last code change.
- The pose values are a base for the Director's fine tuning; his Blender session was not reopened (the session closed first).

## Next
The Director's fine tuning of the aim (File > Revert first if a Blender holds the old file). Proposed, NOT ruled: one timeline `.blend` per figure (idle, draw, aim, the pistol keyed; the two stops saved as today) and a non-destructive NLA layer to edit Tripo clips (parked: "não vamos mexer nas tripo por enquanto"). Then the MV-4 transitions, the other weapons on the new figure, the Galaxy round.
