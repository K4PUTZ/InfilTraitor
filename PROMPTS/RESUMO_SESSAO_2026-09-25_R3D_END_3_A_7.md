# Session summary — 2026-09-25 — R3D-END END-3 to END-7 done

**Resume point:** R3D-END step **END-8 (the device gate)**. Read the plan's R3D-END block (`RENDER3D_MASTER_PLAN`, "Execution
order" and the "Gate" section). Nothing is edited. Before any change, re-take the identity set from the current commit
(`pixel_gate.py --keep`, `board_probe.py gate|roundtrip --out`; `ground_gate.py` carries its digests).

## What the Director asked, in order
1. "Vamos seguir com R3D-END." 2. "Sim, segue para a END-4." 3. "Sim, segue para a END-5." 4. "Sim, segue para a END-6. Sugira o
nome mais apropriado e pode seguir." (the class is now `VoxelBoard`) 5. "commita quando os gates passarem e segue para a END-7."

## Commits (all pushed, `main`)
| commit | what |
|---|---|
| `b00d8a96` | END-3: `apply_occlusion`, ghost records, the 2D wireframe overlay and panel |
| `1b7cb550` (+`21de56de`) | END-4: the compositors, the baked lookup, the damage baker, the light alternatives, the 2D face shader, the bake in `RoomBuilder`; 13 suites and the F5/F8 viewers |
| `9921d014` | END-5: `floor_layer` (the node and its plumbing in 30 classes); the pick and the ground check read `GroundGrid` |
| `1cffeaec` | END-6a: the level layers become arithmetic (`level_origin`, `level_z_index`, `has_level`), the tile readers and `BakeConfig` go |
| `3ca6f1d0` | END-6b: `VoxelRenderer` -> `VoxelBoard` (rename only) |
| END-7 commit | canon: rules 8 / 9 / L1 / R8, B1-B6, the docs |

Every step was held to the END-0 set: pixel 0 px above noise (GLASS g0/g1 136/63 strict is the known jitter), 31/31 `board_probe`
dumps identical, ground_gate 16/16 against the recorded digests, roundtrip / shadow / mirror / occ_canonical PASS, shot_3d PASSED,
`run_selftests` 51 clean (64 - 13 suites whose subject was deleted).

## Traps found
- **A removed side effect is not caught by lint, selftests or pixels.** END-4 deleted the layer material, which also created the
  level's cell plane; only the probe dumps' "plane levels" count (6 vs 5) saw it. Read a deleted function's side effects first.
- **`pixel_gate.py` times out at 600 s if ANY other Godot is alive, the editor included** (twice, and the first run after a code
  change can also time out: rerun alone).
- **zsh does not word-split a variable** (`FILES="a b"`): use an array. And a `sed s/e6/e6b/` over a script also rewrites the
  scratchpad path (`...4e65...` contains `e6`): the script silently wrote nowhere and a wait loop spun on a log that never came.
- **A new class name needs `godot --headless --import` once**, or the lint reports the whole tree broken (the class cache is stale).
- **A gate that reads a tile layer prints PASS on the 3D board** (the old ground_gate `tiles 0`, OCC-COMPARE, the level census).
- **Deleting a doc comment block:** a function's doc can be stacked directly on the next function's doc; delete by anchor, not by
  "contiguous ##".

## Left for later (not END-8)
`structure_layer` and the prop tiles (R3D-PROPS); `VISUAL_GRID_OFFSET` and the 2D overlays (R3D-PROPS / R3D-ACTORS); the unused
`tile_size` fallbacks on a few overlays; `occlusion_overlay.gd` (a dev diamond painter); `voxel_board.gd`'s `render*()` passes are
husks that only register levels (rename them when the level registry gets its own entry point); `docs/README.md` and
`docs/production/current_state.md` were not touched.
