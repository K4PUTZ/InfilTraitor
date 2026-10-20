# Session record — M6 liquids CLOSED, 2026-10-18 / 10-19

Resume point for the next session: **M6 (liquids) is CLOSED by the Director (2026-10-19).** The materials part owes no liquid work; what is left belongs to other milestones (below) or is recorded as open in `MATERIALS_MASTER_PLAN` (its v1.5 top block). The master record is `MATERIALS_MASTER_PLAN` §6 (the F-table and the blocks under it); this file is the index of what this session decided, built and measured. It continues `RESUMO_SESSAO_2026-10-18_LIQUIDS_M6.md`.

## Director rulings (all recorded in the plans)
- **Dig the channel** instead of raising curbs: floor openings take `dig` 2..8, a shell (bed + wall ring) is generated under the two floor slabs.
- **Fire lights its surroundings by construction**, tactical (registered, on/off re-projects exposure), warm and flickering; the glow grows half a GU a step with a fade, shrinks when put out.
- **Secondary materials:** a material that `inherits` a primary takes its stats and keeps its own texture (`iron_bar` <- `steel_dark`); every behaviour table answers a secondary as its primary (`SecondaryTables`).
- **LIGHT-ENGINE parked:** the frame budget stays 33.3 ms; lateral light propagation / per-face light wait for the light milestone; light changes belong to the "consequence" window after an action.
- **The nine per-liquid rules** approved with the proposed defaults; the nuclear liquid also glows faintly (phosphorescent).
- **Universal gravity for actors:** an actor rests on what is under its feet.
- **Items of other milestones are planned there, not built now** ("estamos chegando num momento que vai envolver muitas areas simultaneamente").
- **A body spreads through its container** instead of a predefined size; the liquid works **by construction, not by definition**, more VFX than geometry.
- Waterfall look: as wide as the opening at the water's level, the water in the pipe about a third up the bore, a hint of steam where the curtain lands, feathered transitions, the curtain drawn over the lower sheet.

## Built (by commit, newest last)
- Shell under dug openings, PIPE_LAB channel dug 4 under both pipes, grates from the bed (`d335362e`, `a2176a36`, `7e6cb2c0`).
- Fire light: warm cell plane (A channel), tactical lights, sliced repaint, stepped glow (`3bf0c33d` .. `2f0309e2`).
- Secondary materials and `iron_bar`; below-floor props no longer dropped (`12af756c`, `ffe98bad`, `912b198d`).
- **F5, the nine rules** (`041a9acd`): `LiquidAgentStatus` (fire on the agent, chill, stain, glow, sink), `LiquidSurfaceState` (crust plates, ice), `LiquidCorrosion`, `LiquidGlow`, `LiquidRulesController`; the cell plane's A byte holds one hue (warm / cool); bench `maps/LIQUIDS_LAB.map.json`.
- **Actors under gravity** (`2a539428`): `Board3DLive.stand_height`, `Room.liquid_stand_y`.
- **Consolidation** (`b782521f`): `LiquidRegistry.check_gameplay` (the rules' schema), `FluidPlane.MAX_CELLS`, loud no-op zones, NaN guards, overlap warning, the dev walk fixed.
- **Waterfalls by construction** (`b782521f` .. `712e470c`): `FluidPlane.falls()`, weirs (`WEIR_C`), the sheet drawn per cell (never bridging a step), `LiquidFalls3D` (one curtain a chain of edges, foam band, steam), raised pipe A on PIPE_LAB (`pipe_n_hi_*`).
- **A body takes the shape of what holds it** (`bd95c198`): `FluidContainer` (flood from a `seed` over voxel columns, under a `brim`; floors, roofs, bores, gratings read from the world; re-read on every committed event); PIPE_LAB and LIQUIDS_LAB seeded; `pit_divider`.
- **Closing pass** (`918445cf`): flames on the oil's surface, stand height on raised ground, container refresh fixes, `LIQUID_FALLS` A/B flag.

## Measured (Moto g04s, release APK, uncapped)
- Fire light: 82 / 136 ms at first, then sliced to 17.9 / 26.2 (idle / burning, 2026-10-18).
- Closing pass (2026-10-19): **waterfall 18.8 ms with and without the falls**; **PIPE_LAB oil 19.8 idle / 29.2 burning** (25.2 with the fire light off; the body is now the dug channel's 2 GU); **LIQUIDS_LAB 21.7-23.0** (21.3-21.4 with the bodies' lights off). Runs the analyzer flagged as "touched" (a finger on the screen) were discarded and re-run.
- Not measured: the Galaxy A16 for any of this.

## Selftests added
`liquid_status_selftest`, `liquid_guards_selftest`, `fluid_container_selftest`; the liquid selftests that read the maps' typed rectangles now build PIPE_LAB-like / LIQUIDS_LAB-like worlds from voxels (`tools/liquid_test_world.gd`). `verify.py` (smoke) green at every commit.

## Open (recorded, not loose)
- Materials: a body growing past its birth grid. ~~lava setting voxels on fire~~ (`VoxelFire`), ~~corrosion weakening a voxel~~ (`VoxelWeakness`) and ~~a crust's late cells~~ (already plates) were CLOSED later on 2026-10-19: see `MATERIALS_MASTER_PLAN`'s block "THREE M6 TAILS CLOSED". Not measured: the Moto cost of the voxel fire.
- Other milestones (planned in their plans): guards and liquids, evidence (AI, `DESIGN_MASTER_PLAN` §4.7); pits, poses in liquid, the agent on fire, the shot's height (`MOVEMENT_MASTER_PLAN` §7a, `WEAPON_MASTER_PLAN` §7b item 6); valve and extinguishers (props); liquids in the checkpoint (gameplay); rain (weather); gases (a decision); segment flooding (shelved).
- ~~Intermittent crash~~ **FIXED after this record, in a side session (2026-10-19):** the `propagate_notification()` + exit -6 crash was Godot 4.6.1's crash handler tripping from a worker; the fault was a GDScript race on UNTYPED operators patched on first run while several worker threads ran the same code (`VoxelLightField._anchor_level` on the parallel light-bucket pass at map load). Fixed `f3d8a74c` (typed), stress 2/3 crashes -> 0/3; gate `tools/persistent/worker_typing_check` in `verify.py quick` (`4f75ac3f`). **The project then switched to Godot 4.7.2** (`6f3ea21b` evaluation on a copy, `ce4cc053` switch; 4.6.1 kept as `/Applications/Godot_4.6.1.app`; `verify.py look` baseline retaken; Moto A/B equal; the Galaxy not measured; JAMES's clone still on 4.6). Record: `PERFORMANCE_BUDGET_MASTER_PLAN` top block.
- Balance: the cryogenic chill takes up to 2 AP from an agent who has 2.
