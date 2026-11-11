# Session 2026-09-27 (evening) — R3D-PROPS started: barrel (mesh) built and measured, crate (voxel) blocked deeper than expected

Full record: `RENDER3D_MASTER_PLAN` v1.39 top block and the R3D-PROPS design block (§4).
Commits: this session's (see `git log`).

## Ask

"Segue com R3D-PROPS, tomando as decisões recomendadas... Vamos criar alguns objetos básicos: creates,
barrels, e testar o pipeline." R3D-PROPS' own design (`ACTOR` D65): static props are meshes, destructible
ones are voxels.

## Static-mesh half — BUILT, measured, works

- `godot/shaders/prop_mesh3d.gdshader`: promotes R3D-SPIKE-3D's `spike_mesh_planes.gdshader` out of its
  spike gate (that spike already measured +1.5 ms GPU for 20 props on the Moto, no shadow). Same uniform
  names `Board3DLive._build_plane()` sets on its own opaque materials, so a prop material can ride the
  same rebuild pass.
- `board3d_live.gd`: `register_prop_light_material()` / `unregister_prop_light_material()` — a small
  separate `_prop_materials` array (not `_shader_materials`, which other code indexes 1:1 against
  `_material_glass`/`_material_index`). `_build_plane()` now also refreshes any registered prop material.
- `godot/scripts/geometry/prop_mesh3d.gd`: places a real mesh at a voxel cell, resting on a level's TOP
  face, using the same convention `Board3DLive._emit_quad()` uses (1 world unit =
  `GeometryCoords.VOXELS_PER_UNIT_AXIS` voxels; a level's top sits at `(level + 1 - ground_level)`
  world-Y units).
- `voxel_board.gd::place_prop_demo()`: dev-only demo seam (`PROPS_MESH_DEMO` flag), same shape as
  `SURFACE_PATCH_DEMO` — a procedural `CylinderMesh` "barrel" (~0.5 m radius, ~0.9 m tall). Procedural
  geometry answers the plan's own "triangle cap" question trivially (a box/cylinder is a handful of
  triangles); deferred to whichever prop first needs real authored art.
- **Measured:** desktop capture (`FLOOR_ZONES_TEST`) shows the barrel correctly depth-tested against a
  wall and lit the same dim green as the grass floor it stands on. Moto (`ZF524T5TG5`, release APK,
  `PROPS_MESH_DEMO=1`, `FRAME_PROBE=1`): steady GPU ~21 ms, zero errors — no measurable cost from one
  prop at this scale, consistent with the earlier spike's number.

## Destructible/voxel half — a real gap, not fixed this session

Tried to test `crate_full` (`props/crate_full.json`, an 8×8×8-voxel wood box, already authored at PROP-01)
the same way, and found two problems stacked on top of each other:

1. **`RoomBuilder._get_prop_registry()` returned `null` unconditionally**, hard-disabled since before
   AUDIT-01 (`012eb159`, 2026-08-06) — that commit only corrected a stale comment, it did not change
   behaviour. Every shipped map places crates through the LEGACY sprite/tile path; only the SIGMA_01
   *code* spec (fallback-only) ever declared `voxel_props`, and it never rendered either. The code's own
   comment named re-enabling "a Director call, not a cleanup" — asked, and re-enabled.
   - Re-enabling via a bare `Registries.ensure_prop_registry()` **broke 7 selftests**
     (`blast_purity_selftest`, `detonation_plan_selftest`, `floor_integration_selftest`,
     `floor_zone_bake_selftest`, `roof_bake_selftest`, `roof_entity_selftest`,
     `roof_integration_selftest`) with `SCRIPT ERROR: Compile Error: Identifier not found: Registries` —
     these run `room_builder.gd` under a bare `godot --script` invocation, and autoloads are not up yet
     when GDScript resolves a global identifier at parse time (confirmed directly: `[Registries] Autoload
     initialized` prints AFTER the compile failure in the log). Fixed by going through `room`'s own tree
     (`room.get_node_or_null("/root/Registries")`), the same pattern `Room._dev_flag()` already uses for
     `DevFlags`, instead of the bare autoload name. `verify.py smoke` PASSED clean afterward (51/51
     selftests, PLAYGROUND+GLASS boot).
2. **With the registry live, nothing still renders.** Added a temporary `voxel_props` entry to
   `FLOOR_ZONES_TEST.map.json` for the test (reverted after — `git checkout --` on the map file, it is
   not part of this session's committed changes), confirmed via a debug print that `register_prop()` is
   reached with the right def/cell/material, and confirmed the store's voxel count is **byte-identical**
   with or without the prop (66944 either way). Root cause: `VoxelBoard.register_block_levels()`
   (`voxel_board.gd:375`) is **already a no-op since R3D-END** — its own comment says so ("nothing is
   placed here"): it is 2D-era code that used to write `TileMapLayer` cells, and was neutered rather than
   ported when the 3D board's real geometry moved to the `VoxelStore` (rule 8). `register_prop()` is the
   only caller left routing through it.

**Conclusion: D65's "destructible props are voxels" is not actually implemented on the 3D board today.**
Making it real needs `register_prop()` (or a replacement) rewritten to emit real store voxels from a
`PropDef`'s `size_vox`/`layers` bitmask — genuine, separate work, not a flag flip. `crate_full`'s shape
data is authored and sitting unread.

## What is live vs. what is still open

- **Live:** the static-mesh path (barrel), the re-enabled `PropRegistry` (harmless — it now resolves defs
  correctly, it is `register_block_levels()` underneath that draws nothing), the `--script`-safe autoload
  access pattern in `room_builder.gd`.
- **Open, real follow-on scope (Director's call to schedule):** rewrite the voxel half of the prop
  pipeline so `crate_full` actually places voxels; a real map-data schema for prop placement (today: one
  fixed dev-only barrel cell, mirroring `SURFACE_PATCH_DEMO`'s own dev-only pattern); the asset budget
  question (one mesh per prop, a triangle cap) stays open until a prop needs real authored geometry
  instead of a procedural primitive.

## Evidence

- `verify.py smoke` PASSED (lint, invariants, codemap, 51/51 selftests, PLAYGROUND+GLASS boot) — twice:
  once before finding the compile break, once clean after fixing it.
- Desktop captures: `props_barrel_demo2.png`, `props_barrel_final.png` (barrel, correct depth + lighting).
- Moto (`ZF524T5TG5`, release APK): `PROPS_MESH_DEMO=1`, `FRAME_PROBE=1`, zero errors, steady ~21 ms GPU.
  `dev_flags.cfg` cleared from the device after the run, per the device-harness protocol.
- The map file used for the crate test (`FLOOR_ZONES_TEST.map.json`) was reverted (`git checkout --`) —
  not part of this session's committed diff.
