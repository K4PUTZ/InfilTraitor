# Session summary — 2026-09-24 (later) — R3D-13 CLOSED (Galaxy row recorded, shot tail explained); the plane findings traced

**Resume point:** R3D-13 and R3D-14 are CLOSED (plan v1.25): the independence gate reads PASS. **R3D-END is NOT started: it needs only the Director's ratification on the deletion list** (`RENDER3D_MASTER_PLAN` §R3D-END).

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

## The last round (Director: "Religa o pre-cook na 3D e checa se precisa de mais alguma coisa antes do END")
- **Pre-cook back on 3D** (`2d88472e`): Galaxy tail 418.8 -> 223.3 ms (settled pair; two noisy pairs 663 -> 418, 756 -> 221), SHOT_SCOPE_PROBE 0 differ of 210 749 cells (real on 3D now), desktop tail 164 -> 113-117 ms.
- **The R3D-END entry gate, `tools/persistent/independence_gate.py`, is RED.** With the hidden 2D board emptied after every step: PLAYGROUND identical (10 dumps, 3 frames); GLASS identical in voxels and read planes but the PICTURE loses the crack/craze webs after a blast (19 391 px g0, 10 881 g1, reproduced exactly).
  Cause: `_build_crack_occupancy()` reads `_glass_layers`. **R3D-14** (plan v1.24) is the stage that moves the glass state to the store; R3D-END's entry condition is now R3D-8..14 closed + this gate PASS + the Director.
- R3D-END's size, measured: `floor_layer` 202 refs in 25 files (a conversion refactor, not a delete), 15 `room.gd` instrument functions that read tile layers (listed in the plan), the 3D decal catalog's loud-fail.

## R3D-14 (Director: "Sim, começa a R3D-14") — BUILT, `8c8723c0`
- The glass state (which pane cells stand, their face, which have had an opening applied) now lives in the `VoxelStore` (`pane` per claim, `glass_pane_face_at()`); under the 3D board the hidden glass layers are never built or written. `GLASS_STATE_LAYER=1` = the A/B control (kept until R3D-END: the gate's control).
- **`independence_gate.py` reads PASS** (it was red: GLASS lost the crack/craze webs, 19 391 / 10 881 px): the hidden board holds 0 cells at all 19 drop steps, 19 state dumps identical, 0 px above noise on 6 frames, and its layer-mode control still loses [19 391, 10 881] px.
- A/B store vs layer, same binary: 19/19 dumps identical; pictures 0 px above noise incl. a pistol shot at glass + a rotation E and back; Galaxy GLASS commit frame ~700 vs ~930 ms.
- Also: the 3D decal catalog is loud on a partial family. Open (not blockers): GLASS rim texel, `_soot_map` glass tone, SE face, the Moto halves, GLASS COMMIT ~700 ms.
- **R3D-END needs only the Director's ratification now.**

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
