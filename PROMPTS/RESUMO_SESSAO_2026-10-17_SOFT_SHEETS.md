# Session summary — 2026-10-17: cloth and cardboard are sheets, roofs AND walls, sewn; the quitanda; the soft materials close

Resume point. Plans: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.41-v0.44 (every decision, number and trap), `PROMPTS/PLANNING/MATERIALS_MASTER_PLAN.md` v1.4, `docs/ARCHITECTURE.md` §0.5. Everything is on `main` (last code commit `af12ecf6`, then docs).

## What is true now
- **The rattle after a fall is gone** (`SoftSheetSim._collide`): the push-out of a contact was read as a velocity (a bounce), and a node only left a wall once inside it (it slid in, popped out 0.02 GU, again); now `_push` is taken out of the velocity and `_hold_off_solid` holds a node ON the margin. The real map settles by itself (4.8 s) where it never did.
- **Cloth and cardboard are drawn at rest from the first frame**: `Room._begin_resting_sheets` / `_finish_resting_sheets`, sims settled on workers (`SoftSheetSim.settle_now`), the board draws no face for those voxels (`Board3DLive._sheet_claim` 2, `Room.soft_sheet_voxels`). Switch `SOFT_REST=0`.
- **Cardboard = the cloth's mechanism as plates** (`plate` 3 / `crease` 0.004, thickness 0.05, ragged torn edge, no flaps, its old debris kept, the creeping voxel fire off for every soft material: the sheet's shader burns).
- **Walls are sheets** (`RoofSheetRelease.wall_entities` / `collect_wall` / `sim_params_wall`; `SoftSheetSim` `basis_u` / `basis_v` + a hair of out-of-plane seed so a falling wall folds). Switch `SOFT_WALLS=0`.
- **Seams** (`SoftSheetGroup`): the sheets one blast lets go are stepped together and sewn along touching edges; the group owns the worker; nodes sewn to a cloth that stays are pinned.
- **One release batch**: which sheets go is decided on paper first (`ignore`), prepared against the same final world, finished together; a cloth at rest is drawn by its own node so it falls without waiting for the chunk remesh (5.7 s -> 0.3 ms on the Moto).
- **Panels may `blocks`** (movement, sight, rounds; default off). A shot's hole shows in the sheet (`Board3DLive.shot_touched`) with a little soot.
- **Fixtures:** ROOF_LAB room C (cloth) and D (cardboard); new map `MARKET_LAB`; PLAYGROUND's cardboard / fabric trios are quitandas. **Videos:** `tools/persistent/material_videos.py` (shot + blast for nine materials).
- **Measured:** Moto g04s and Galaxy A16: load wait 0 ms; a quitanda release batch 256 + 22 + 66 ms (Moto) / 211 + 9 + 29 (Galaxy); fall window 35.6 / 34.1 ms per frame.
- **Glass:** left as it is (Director). The fall without support is right; the opening at the impact is regular. If ever reopened: smooth noise on `GlassSupport._reach` is the lever (tried, reverted); a Euclidean disc for a bullet's region changes nothing.

## Later the same day: the performance pass (`ROOF_MASTER_PLAN` v0.45)
Sheets are claims (no `Voxel` objects), settled positions are cached between runs (`SoftSheetRestCache`, bump `SIM_VERSION` when `SoftSheetSim` changes), a release builds its sims on a worker, cheaper skins at rest, takes may carry `env`. Bench `MARKET_STRESS` (40 sheets). Galaxy A16: load wait 0 ms, release ~100 ms main thread, PSS +15-35 MB over sheets-off. **Owed: the Moto g04s on MARKET_STRESS.** The full gate found and fixed a real bug: the blast's predicted light field overwrote the light a cloth release had repainted (`light_field_usable = false` after a release). `verify.py full` PASSED (597 s); the ground gate's PLAYGROUND `select` digest and the baselines were re-recorded for the quitanda reform.

## Later still: checkpoint persistence (`ROOF_MASTER_PLAN` v0.46)

Let-go cloths survive a save / restore (frozen, sewn, 0 ms); seams are one-way kinematic; the restore now redraws the props its replay destroyed (the posts came back whole before). Moto MARKET_STRESS: PSS 631-635 vs 631 off, load 714 / 330 ms.

## NEXT
1. **M6, fluids** (`MATERIALS_MASTER_PLAN` §6): water, lava, sewer, quicksand (ordinary `earth` as the base, a trap rule on top: the cheapest first slice), gases maybe. Research first; the old worries (TileSet rebuild) are history, `SoftSheetSim` + `SoftSheet3D` are the precedent for a dynamic surface on a worker.
2. Smaller, soft materials: a rail / counter for the quitanda's frame; walls of cardboard that fold as plates; persistence of a let-go cloth across a checkpoint; a per-plate bilinear skin (a crease reads as a soft bend); the roof shot (step 5) and metal (Q5).

## Traps (each cost an iteration)
`capture.py` hangs until its timeout when the map fails to load (an id used both as POI and take; a POI off the 1/8 lattice); a new `class_name` needs `godot --headless --path . --import`; `PLAYGROUND.map.json` is hand-formatted (compact `capture` / `layout`): edit it with the splice helper idea (replace one section's value via `json.JSONDecoder().raw_decode`), never re-dump the file; comparing a `String` key with a `Vector2i` key with `!=` is a script error (use `str()`); a stale `[SOFT-SHEET] ... DBG` print is how the shot hook was debugged (removed); an agent shot through a panel needs `blocks: true`; PLAYGROUND's north wall hides a camera from behind; `release_roof_sheet(roof, false)` is the bench's flat start, the game's is from rest.
