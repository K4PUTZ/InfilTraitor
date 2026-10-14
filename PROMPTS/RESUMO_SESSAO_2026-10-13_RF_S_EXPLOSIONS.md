# Session summary — 2026-10-13: RF-S in explosions (a seasoning of the shot), doors in hole-only walls

Resume point for the next session. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.20 (record in §5); architecture: `docs/ARCHITECTURE.md` §0.4.

## 1. What a blast adds now, per material (Director: "uma temperada do tiro no anel de dentro")
The shot's machinery, reused, never a second one. `DetonationPlanBuilder._plan_blast_pellets` (end of PHASE_PACKAGE, resumable, one cone per
visit) fires SIMULATED shotgun pellets from the epicentre (8 cones: axes + diagonals, 24 pellets each, 2 GU) through the shot's PURE plan
(`select_cone_pellet_impacts`, `resolve_pellet_voxel`, `plan_point_impact`). Nothing is applied. It proposes on the `WorldDelta`:

| Field | What | Spawned by |
|---|---|---|
| `blast_rubble` | a voxel the plan reaches that the blast DESTROYS -> the shot's block (crumble / splinters) | `Room.spawn_blast_rubble` (on the commit frame) |
| `blast_impacts` | a struck face left standing -> the shot's impact effects (dust, chips + stamps, trickle, sparks) | `Room.season_blast_impacts` (4 per frame after it) |
| `blast_trickles` | a few dented / cracked wall voxels (concrete, brick, stone) -> the bullet hole's sand trickle, material colour | `Room.season_blast_trickles` (spread over 1.2 s) |
| `blast_breaches` | the DOOR of a hole-only wall (below) -> the shot's forward throw | `Room.spawn_blast_breaches` |

Per material (`RubblePresets.BLAST_*`): concrete and brick trickle on every impact, stone on half and is picked half as often; wood throws 3x the
chips. Punch-out materials take no pellet blocks (they get the door).

## 2. Doors and passages
- **Blast:** `_plan_blast_breaches` (end of PHASE_SLICES: real damage, the walk / soot / light see it) cuts plywood, cardboard and fabric edges in
  rings 0-1: 7 of 8 columns x 13 of 16 levels from the floor (~3/4 of the wall, Director). `[E-PASSAGE]` STANDING on all three. The rule is per
  storey over the WHOLE face (32 of 64 cells): 6 columns x 13 levels left storey 1 at 30/64 = CROUCH, which is why the door is 7 wide.
- **Shot on plywood** (the agent will squeeze through head first, Director): `ZONE_RADIUS_OF` plywood 3.2 x 3.2, `TEAR_SIZE` plywood 6.
  `[SHOT-PASSAGE]` CROUCH at shooter cells 40,11 / 40,10 / 41,11 / 39,12 (61 / 53 / 53 / 67%); at 41,11 a side hole also counts. Stone's shot
  trickle 0.25 -> 0.35.

## 3. Moto g04s (one APK, `BLAST_SEASON=0` as the A/B, `MAX_FPS=0`)
Logs `docs/measurements/device_2026-10-13_moto_ab3_*.log` (git-ignored). First version +28 to +43 ms on the worst blast frame (the rubble
shader's pipeline compiled in the flash frame: 54 ms; the pellet plan in one 64-78 ms step). Fixed: `Board3DLive._warm_rubble` draws the
rubble material once at load (54 -> 25 ms), the plan is sliced, the impacts spread. Now grenade 114 / 121 vs 107 / 110 ms, concrete 99.5
vs 94.9, PSS unchanged (0.67-0.69 GB). Open: `_movement_edge_set()` rebuilt on every rubble call.

## 4. Tooling
- Takes on PLAYGROUND (`capture` section): `blast_<material>` for concrete, wood, brick, stone, plywood, cardboard, fabric; `shot_concrete`,
  `shot_plywood`, `shot_stone` (shooter via `INFILTRAITOR_SHOT_AGENT_CELL` / `SHOT_GUARD_CELL`, internal coords, see each take's note).
- `capture.py` prints `[BLAST-RUBBLE]`, `[SHOT-RUBBLE]` and the `-PASSAGE]` lines.
- Director's working mode this session: record, watch, fix, repeat; tests and commits held until the look was final, then `verify.py full`.

## 5. NEXT (Director)
The roofs: step 5 (the roof shot), shots at the ceiling, the falling-rubble animation adapted. Still owed from before: `side` on `panels`,
the one-layer selftests, stamp art for cardboard / fabric, the Galaxy A16 round.
