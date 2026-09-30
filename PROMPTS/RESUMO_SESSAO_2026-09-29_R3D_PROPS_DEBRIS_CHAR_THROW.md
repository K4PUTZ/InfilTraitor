# Session 2026-09-29 — plywood debris art, a blast's prop damage survives rotation, charred tone, hollow crates, grenades over props

Commits `40a6419c..f252e349` (`git log a72b4026..HEAD`). Previous session: `RESUMO_SESSAO_2026-09-28_R3D_PROPS_BLAST_AND_DEBRIS.md`.

## Ask

Continue the props/debris tests with the Director's new art (`ASSETS/TEXTURES/source/debris/Export`: `WOOD1-3`, `PLYWOOD1-3`), put it on the map, simulate a crate breaking.
Everything below was asked for, in this order, by looking at real captures (the Director marked up two of them).

## What was built

### 1. Art and the PROPS map
- `WOOD1-3` were already installed (`decal_debris_wood_*`, byte-identical). `PLYWOOD1-3` arrived COLOURED; the rule (`ART_SPECIFICATIONS` §7c) is grayscale + engine tint, so they were
  converted (luminance, matched to WOOD's mean) into `ASSETS/materials/_generic/decals/decal_debris_plywood_0..2.png`. The source files are untouched.
  A new PNG in a folder Godot has not scanned has NO `.import` and fails with "No loader found" — run `godot --headless --path . --import`.
- `props/crate_plywood.json`; `maps/PROPS.map.json` is now 18x12, turned 180 degrees (the default view faces the props); the test grenade goes on GU **(11,6) in MAP coordinates**; `INFILTRAITOR_GRENADE_GUS` takes VIEW coordinates (map + the 1-cell buffer), so the harness value is `12,7`.

### 2. Rotation was rebuilding the crates (found by rotating after the blast)
`Room._set_perspective()` still re-lays the whole map out and rebuilds every `Voxel`, then replays `_base_damage`. `_reapply_base_damage()` indexed slices, junction columns and slabs and never the
`PropBlock` voxels, so every rotation restored a blasted crate whole while its records sat unread. Fixed, and the same class fixed for the two things a blast does to a prop that are not voxel state:
`_base_shattered_props` (Tier 4) and `_base_debris` (ground pieces, replayed AFTER the 3D board is rebuilt because rebuilding drops the piles). ⚠️ **All of this is workaround for the re-layout**: it
goes away at R3D-ROT (camera-only rotation, one world, state recorded once) — see the R3D-ROT list in `RENDER3D_MASTER_PLAN`.

### 3. Blast rings around props
`flood_gu_rings()` never enters a blocked cell, and a prop's GU is one, so the floor under it took no damage and no soot (one clean GU beside the grenade; a Tier 3 prop, which reads the soot of
the floor cell under it, could not darken). `BlastCalculator.add_prop_boundary_rings()` (called from `DetonationPlanBuilder._phase_setup`): a prop GU takes the ring of its nearest flooded
neighbour, diagonals count as ring + 1, and the open cells beside a prop take the prop's ring + 1 (the blast wraps around it by one cell, never through a blocked edge or another blocked cell).
Props only — a wall block's footprint behaves as before.

### 4. Debris
- One piece per fallen voxel per cell (up to 8), landing 0.3 of the way to where the glass mechanism would throw it, every 5th thrown the full distance (`vfx_prop_debris_scatter`,
  `PROP_DEBRIS_FAR_EVERY`); Tier 4's spread 0.7 -> 0.35.
- Tint = material colour x `DEBRIS_TINT_SCALE` (wood 0.72) x the soot tone of the cell it lies on. ⚠️ The pile shader is `unshaded` and multiplies in LINEAR space: a plain 0.27 displays as ~0.55,
  so "sooted" debris stayed pale until the factor went through `pow(k, 2.2)`.

### 5. The charred tone
Director: what fire/embers touch ends black, walls included, through the soot map, "a tone much darker than the others". `FACE_SOOT_CHAR = 5`:
- the plane's per-face code went from base 5 to **base 6** (`top*36 + se*6 + sw`; clean 172, 216 codes, still the 8-bit R channel) — `VoxelBoard.FACE_SOOT_CODE_CLEAN/COUNT`, `VoxelLightField`, both
  shaders (`board3d_live.gd` OPAQUE_SHADER, `prop_mesh3d.gdshader`), `DetonationEntryWriter.lightened()` (a charred face stays settled at `by == 0`).
- `DetonationPlanBuilder._mark_charred()` marks every ember-lit voxel (seeds and climb) and `_phase_soot()` stamps them FIRST; `Room.stamp_soot()` lets CHAR win and never be overwritten.
- ⚠️ `CellPlaneStore.write_soot()` clamped to CLEAN, which turned every charred code into "clean" silently; it now has its own `_max_r`. Found because the log said 61 marked, the map said 61 stored and the picture
  showed nothing — measure each hop.
- `BoardLook.SOOT_CHAR_MULT` = **0.14** (tuned 0.03 -> 0.12 -> 0.18 -> 0.14 by the Director's eye: dark, the material's texture still reads through).
- Measured on PLAYGROUND blocks (`INFILTRAITOR_MAP=PLAYGROUND`, grenade at the centre of the trio, row 5): charred 304 (wood) / 313 (cardboard) / 315 (plywood); consumed 11% / 100% / 41%.

### 6. Material rows (Director asked for longer burning and more consumed voxels, "like the walls")
wood `flammability` 1.0 -> 1.4, `burn_consumption` 0.0 -> 0.2; plywood 1.1 -> 1.5 and 0.35 -> 0.6; plywood `destroy_factor` 0.8 -> 1.0 (wood 0.75). ⚠️ These are MATERIAL rows, so wood and plywood WALLS,
floors and firearm damage change with the crates (the destroy table is shared with firearms). Wood's 0.0 had been ratified ("VL-D4's look must not move"); this is the Director's explicit override.
`detonation_plan_selftest` pinned "no ember on a destroyed cell" with wood as the never-burning fixture; it now skips embers flagged `burnt`, which the code documents as sitting ON the hole.

### 7. Hollow crates
`PropDef.hollow_shell` (crates: 1): an N-voxel shell, interior empty; the `VoxelStore` keeps such a container in its per-voxel table (`_irregular`, 3 on PROPS). What a crate CONTAINS is later.

### 8. Grenades over props, and picking a prop
- `throw_line_clamp(..., over_blocked: Callable)`: a blocked cell the arc clears is crossed but never landed on; a cell the callback refuses (a wall block) stops the line exactly as before. The
  callback (`TestZoneController._flight_clears`) asks `ThrowArcOverlay.height_at()` (the exact curve the player sees) against `Room.prop_top_px()` (the prop's REAL top: its standing voxels' highest
  level, or a mesh prop's box) + `THROW_CLEARANCE_PX` (30). The apex depends on the landing, so `_clamp_gu_to_throw_range` iterates (at most 3).
  Measured on PROPS: target (8,8) behind the crates goes from (10,5) to (9,7); a cell right behind a crate stays shielded (the arc is already descending there).
- `Board3DLive.pick_cell()` also asks each prop's box (`PickMath.ray_box`, a pure class so a selftest can load it): the centre of a crate answered the cell BEHIND it, (-1,-1) off; it now answers the
  crate's GU. Walls are not asked (their cut-away/ghost views are what let the player click past them).
- **Found and fixed on the way:** every Tier 3/4 mesh prop was drawn within one GU of the map origin and one level in the air (`PropMesh3D.setup()` takes a VOXEL cell and the level below;
  `_build_mesh_props()` handed it a GU and the storey's first level). They had never appeared in a capture. Now centred on their GU.

### 9. Tools
`INFILTRAITOR_PROP_DEBUG=1` prints the ring/soot map around the epicentre, debris placement and tone histogram, mesh-prop world positions and `_soot_map`'s charred count.
`INFILTRAITOR_THROW_PROBE="x,y;x,y"` prints the aim clamp (with and without the flight-over rule) and a pick probe. `INFILTRAITOR_CAPTURE_VIEW=N|E|S|W` rotates BEFORE the blast (a video's tool;
`CAPTURE_ROTATE_AFTER` is a still's). A desktop video: `--fixed-fps 60 --write-movie x.avi` then ffmpeg (`videos/props_blast_front.mp4`); the Moto: `device_record.py` (`videos/props_moto.mp4`).

## Review pass (end of session)
A read of everything changed since `a72b4026` found four loose ends, all fixed with tests:
- **`SaveState`** did not save, restore or clear `_base_shattered_props` / `_base_debris` (a fresh mission would have inherited last level's shattered tables and debris; a checkpoint restore lost both). Now in `capture`/`restore`/`clear_run_state` (an old save reads as none; no version bump), `scenario_save_restore` replays them, `_reapply_base_shattered_props` drops the live node of a prop it marks shattered. `save_state_selftest` covers the round trip, an old save and the clear.
- **`pick_cell`** scanned every voxel of every prop on every pointer move; it now tests the block's box first and scans only on a hit.
- **Rings:** the Tier 4 shatter and the debris fall used a flood without the diagonal/wrap rule the plan's flood got. One helper now (`VoxelBoard.prop_gus()` + `add_prop_boundary_rings`) feeds both.
- **Untested new logic:** `blast_calculator_selftest` gained the charred soot code (base 6, round trip, `lightened`) and the boundary rings (diagonal, wrap, cap, unnamed cells, blocked edge).

## Traps recorded this session
- **A capture with no `INFILTRAITOR_MAP` opens the LAST map used** (`user://current_map.cfg`), which here was PROPS: the wall tests reported "no container reached" until `MAP=PLAYGROUND` was explicit.
- **Wall-block GUs on PLAYGROUND** are read in map coordinates for the grenade cell (`TEST_ZONE_GRENADE_GUS`): the trio at y=2 is hit from row 5.
- `verify.py` picks the tier from the changed files: a run whose only change is Markdown or `CODEMAP.md` is `docs`, so a code change needs `verify.py smoke` said out loud.
- A commit can go through with a failing selftest (the hook runs lint/invariants/codemap, not the selftests): run `verify.py smoke` BEFORE committing.

## Evidence
- `verify.py smoke` PASSED after every step that touched code (51 selftests; `blast_calculator_selftest` gained the flight-over and ray-box cases).
- Real detonations on PROPS/PLAYGROUND with the console read, captures reviewed by the Director; the Moto (`ZF524T5TG5`): the release APK exports, installs and boots PROPS with the props in place
  (`videos/props_moto.mp4`).
- **Not done:** the touch aim/selection on the Moto (no aim/throw step exists in `scenario_runner`; the Director tests by hand), `verify.py full` (the soot code is now base 6 across the board, so a
  `full` run is the honest closing gate for it — it needs the Director's word), and the new 18x12 PROPS map has not been re-exported to the Moto.

## Open threads
- A fully destroyed crate still blocks its GU (`_blocked_cells` is static).
- What a crate contains; cardboard/fabric debris art; ash decals.
- Firearm damage still does not reach props (only the blast path was wired).
- R3D-ROT retires `_base_shattered_props`, `_base_debris`, the `PropBlock` index in `_reapply_base_damage`, `_voxel_point_to_base/_from_base`.
