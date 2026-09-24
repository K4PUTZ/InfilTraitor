# Session summary — 2026-09-24 (later) — R3D-13 CLOSED (Galaxy row recorded, shot tail explained); the plane findings traced

**Resume point:** R3D-13 is CLOSED: the Galaxy A16 row is recorded and the 3D shot tail explained (v1.23). **R3D-END is NOT started: it needs the Director's
ratification** on the deletion list (`RENDER3D_MASTER_PLAN` §R3D-END). The Director chose "Fechar o R3D-13 antes" over starting R3D-END or R3D-ACTORS, then connected the Galaxy.

## What changed (full detail and evidence: `RENDER3D_MASTER_PLAN` v1.22)
- **Spikes deleted** (`e5b5f9ca`): `board3d_spike`, `r3d4a_actor_spike`, `store_layout_spike`, their scenes, the two `SPIKE=` hand-overs and the `store_spike` step. `spike3d.gd` stays for R3D-ACTORS.
- **The light plane finding, traced and fixed** (`b0f73d6b`). The cook built the post-blast occupancy per CELL, so the first claim destroyed emptied a box corner / junction column that a second claim still holds:
  cook vs full relight 21 and 13 cells apart on PLAYGROUND's two grenades. Now per claim (`VoxelStore.occupancy_dict_after`, TEST 6): 0 and 0.
- **The gate that could not fail.** `LIGHT_COOK_GATE` and every probe on `_perf_snapshot_alts()` read TileMapLayer cells, so on the 3D board they read 2 240 glass cells and printed `0 of 2240 ... PASS`.
  They read the planes now. **Any instrument that reads a tile layer is vacuous on the 3D board.**
- **`board_probe roundtrip`:** planes compared where the board reads them (visible non-glass cells), the rest counted on the line; PLAYGROUND strict by default (rotation and restore IDENTICAL). New scenario step `relight`.
  The restore scenario now relights the way a rotation does.
- **Decals on 3D, measured:** a missing decal variant is SILENT on both boards; `check_decal.py` and `voxel_decal_selftest` catch it and must outlive R3D-END. Docs corrected.

## The Galaxy A16 (`DEVICE_DIAGNOSTICS_MASTER_PLAN` top block, `RENDER3D_MASTER_PLAN` v1.23)
- Same APK as the Moto's row: load 7.9 / 8.0 s vs 23.3 s (2D), PSS 1.30 / 1.33 vs 2.20 GB, idle 25.2-25.6 vs 39.5-42.4 ms/frame. **Slower than the Moto on the GPU-bound rows** (2.2x the pixels), 2x faster on load.
- **The 357 vs 214 ms shot tail does not reproduce** (pistol at brick, fresh board: 3D 188 vs 2D 164 ms mean of three). **A real gap does:** a shotgun after two grenades, 3D 413-439 vs 2D 223-261 ms. Cause: R3D-10 turned the shot pre-cook off on 3D and it was also warming the light field
  in the aim window. On-device A/B, one line changed, three boots each: 419.0 / 420.8 / 413.7 -> 218.9 / 224.5 / 273.8 ms. No code changed (it moves ~430 ms into the aim window: the Director's call; the tail is R3D-LIGHT's).

## Traps this session found
- The decal art is **git-ignored** (`.gitignore:66 ASSETS/materials/*/*`): a `git checkout` cannot restore a file moved for a test. Copy first, verify with `cmp` after.
- The desktop `REPAINT_PROFILE` split is env-only (inert on an APK). Editing a source file for an experiment: assert every replace matched (two of my patches silently did not, and the runs were unpatched), diff the tree clean afterwards, and compare the compiled `.gdc` in the two APKs to prove the patch is in.
- zsh again: `set -- $M` did not word-split and a Godot run hung on a garbled map id; macOS has no `timeout`. Write each invocation out.
- A `cd` inside a command changes the session's working directory for later calls; use absolute paths.

## Open, not fixed
- GLASS: 1 light texel, L88 (39,103) 7 -> 8: the glass opening's rim cut destroys a pane voxel at commit that the Delta never projected (cook gate 1 of 106 809).
- The Moto half of the pre-cook A/B (phone not attached this session); the SE face of the reference set.
- The 2D board's cook gate passed with the same predicted-vs-real occupancy difference: unexplained (it retires).
- `CLAUDE.md`'s RENDER3D row says v1.20 (edited at R3D-END).
- R3D-END's instrument list must decide each `get_used_cells()` / `get_cell_source_id()` reader in `room.gd` (port or delete with a reason).
