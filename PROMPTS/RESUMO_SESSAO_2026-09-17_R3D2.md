# SESSION SUMMARY — 2026-09-17
## RENDER3D: R3D-2 CLOSED — store-only occupancy, cell planes moved, plan-entry rekey deferred

**Director's request:** *"Vamos seguir com R3D-2."* R3D-1d had closed the day before with
`VoxelStore` as the sole writer and `Voxel` a thin `claim:int` wrapper; its steps 2-4 were
deferred to R3D-2 on the reasoning that R3D-2 re-keys the plan/`WorldDelta` around a store
read anyway.

**Full record:** [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md), the R3D-2
section and the status block above it.

---

## Step 1 — `build_occupancy()` is store-only (commit `a6436cd1`)

`STORE_OCCUPANCY` was already default ON; the tile-walk fallback (`get_used_cells()` +
`_ghosted_cells` + `_glass_layers` unions) was still live and was the exact pattern
DIAG-23 named as blocking a 3D-only load. Confirmed 0 differences against the fallback
(`Room.scenario_occupancy_compare`) at load and across both PLAYGROUND grenades before
deleting it — neither ghosted cells nor glass needed a separate fold-in: occlusion never
marks a claim invisible (O1) and glass voxels are ordinary claims in the store regardless
of render sublayer, so the store already reported both. One selftest fixture that never
built a `VoxelStore` over its registry was fixed the same way R3D-1d fixed its own
casualties.

## Step 2 — glass occupancy leaves `_glass_layers` (no code change, commit `f77cb2f5`)

Already satisfied. `detonation_plan_builder.gd`/`detonation_entry_writer.gd` only mention
`_glass_layers` in comments or WRITE to it (`erase_glass_cell()`, keeping the 2D board's
own draw layer in sync — legitimate until R3D-8); `occlusion_set.gd`'s O7 exclusion already
checks `GlassMaterials.is_glass()` on the geometry directly. Step 1 removed the one real
occupancy read. Remaining `_glass_layers` readers are the 2D renderer's own tile-placement
tests, out of scope until R3D-8.

## Step 3 — cell planes move to `CellPlaneStore` (commit `bc8e1ca9`)

`_soot_images`/`_soot_textures`/`_soot_dirty` and their read/write API relocated verbatim
to `godot/scripts/systems/cell_plane_store.gd` — a relocation, not a redesign. Made
domain-agnostic by construction (owner supplies the clean-fill/max-bucket values at
construction) specifically to avoid a circular class dependency with `VoxelRenderer`.
`VoxelRenderer` keeps every public method name as a thin forwarder — zero external caller
changed. Cross-class const aliasing needed an explicit `preload()`: GDScript does not
resolve `OtherClassName.CONST` in a top-level const initializer, only a preloaded script's
members. `board_probe.py gate` reported the same 3867 voxel / 8063 plane-texel counts as
Step 1's baseline, confirming the move is behaviour-neutral.

## Step 4 — plan-entry rekey, DEFERRED

Mapped both sides (writers in `detonation_plan_builder.gd`/`agent_shot_controller.gd`,
consumers in `detonation_entry_writer.gd`/`test_zone_controller.gd`/`voxel_renderer.gd`'s
ghost bookkeeping and light-apply passes) before touching code. Finding: every current
reader of `source_id`/`atlas_coords`/`alt` is 2D-board-internal (`DetonationEntryWriter
.apply()` is confirmed the only place that turns them into real tile writes; the only
other reader is a read-only diagnostic). R3D-2's stated goal ("no simulation code reads a
tile") was already satisfied by steps 1-3. Worse, resolving material/atom during the PLAN
build and minting/writing only at APPLY time is a *documented, deliberate* performance
design (pre-warming the TileSet alternative cache during the aim window, avoiding 412
`create_alternative_tile()` calls landing on the impact frame) — a full rekey would either
reintroduce that stall or double the resolve cost, for a data shape no consumer needs yet
(no 3D reader exists). Deferred to whenever R3D-3/R3D-4 build the actual 3D consumer of
per-voxel target state, which can say precisely what shape it needs instead of guessing
ahead of a reader.

## R3D-2 is CLOSED

Steps 1 and 3 shipped; step 2 was already satisfied; step 4 is deferred with the reasoning
on record — same call the Director made on R3D-1d's own steps 2-4.

## Next session

**R3D-3 — the 3D board becomes the production renderer** (master plan §R3D-3):
`Board3DLive` reads the store directly, faces merge by material with light/soot per voxel
from the planes, chunk size chosen by measurement, orthographic camera at D26's 30°/45°,
and the vertical-scale measurement (20px/level 2D vs a true-cube projection) is settled
here with paired captures for the Director.
