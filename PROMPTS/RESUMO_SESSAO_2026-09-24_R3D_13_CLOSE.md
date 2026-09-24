# Session summary — 2026-09-24 (later) — R3D-13 closed except its Galaxy row; the plane findings traced

**Resume point:** R3D-13 is closed except the Galaxy A16 baseline row (phone not attached) and its 3D shot-tail explanation. **R3D-END is NOT started: it needs the Director's
ratification** on the deletion list (`RENDER3D_MASTER_PLAN` §R3D-END, v1.22 block). The Director chose "Fechar o R3D-13 antes" over starting R3D-END or R3D-ACTORS.

## What changed (full detail and evidence: `RENDER3D_MASTER_PLAN` v1.22)
- **Spikes deleted** (`e5b5f9ca`): `board3d_spike`, `r3d4a_actor_spike`, `store_layout_spike`, their scenes, the two `SPIKE=` hand-overs and the `store_spike` step. `spike3d.gd` stays for R3D-ACTORS.
- **The light plane finding, traced and fixed** (`b0f73d6b`). The cook built the post-blast occupancy per CELL, so the first claim destroyed emptied a box corner / junction column that a second claim still holds:
  cook vs full relight 21 and 13 cells apart on PLAYGROUND's two grenades. Now per claim (`VoxelStore.occupancy_dict_after`, TEST 6): 0 and 0.
- **The gate that could not fail.** `LIGHT_COOK_GATE` and every probe on `_perf_snapshot_alts()` read TileMapLayer cells, so on the 3D board they read 2 240 glass cells and printed `0 of 2240 ... PASS`.
  They read the planes now. **Any instrument that reads a tile layer is vacuous on the 3D board.**
- **`board_probe roundtrip`:** planes compared where the board reads them (visible non-glass cells), the rest counted on the line; PLAYGROUND strict by default (rotation and restore IDENTICAL). New scenario step `relight`.
  The restore scenario now relights the way a rotation does.
- **Decals on 3D, measured:** a missing decal variant is SILENT on both boards; `check_decal.py` and `voxel_decal_selftest` catch it and must outlive R3D-END. Docs corrected.

## Traps this session found
- The decal art is **git-ignored** (`.gitignore:66 ASSETS/materials/*/*`): a `git checkout` cannot restore a file moved for a test. Copy first, verify with `cmp` after.
- zsh again: `set -- $M` did not word-split and a Godot run hung on a garbled map id; macOS has no `timeout`. Write each invocation out.
- A `cd` inside a command changes the session's working directory for later calls; use absolute paths.

## Open, not fixed
- GLASS: 1 light texel, L88 (39,103) 7 -> 8: the glass opening's rim cut destroys a pane voxel at commit that the Delta never projected (cook gate 1 of 106 809).
- The 2D board's cook gate passed with the same predicted-vs-real occupancy difference: unexplained (it retires).
- Galaxy A16 row and the 3D shot tail (357 vs 214 ms); the SE face of the reference set; `CLAUDE.md`'s RENDER3D row says v1.20 (edited at R3D-END).
- R3D-END's instrument list must decide each `get_used_cells()` / `get_cell_source_id()` reader in `room.gd` (port or delete with a reason).
