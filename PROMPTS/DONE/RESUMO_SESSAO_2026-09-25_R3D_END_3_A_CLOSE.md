# Session summary — 2026-09-25 — R3D-END END-3 to the close (R3D-END IS CLOSED)

**Resume point:** R3D-END is done and documented. **The next stage is the Director's call** (none blocks another): R3D-LIGHT (the
hitch frames of a blast and a shot), R3D-WORLD, R3D-PROPS / R3D-ACTORS, R3D-ROT, R3D-LOOK, R3D-CLAIMS, R3D-BUFFER. Read the top block
of `PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md` (v1.28) first. Nothing is edited. **Verify with `python3 tools/persistent/verify.py`
(auto: docs / quick / smoke). Do NOT run `verify.py full` or the individual identity gates unless the Director asks** (his rule of
2026-09-25: stop replaying the same explosions and shots).

## What the Director asked, in order
1. "Vamos seguir com R3D-END." 2. "Sim, segue para a END-4." 3. "...END-5." 4. "...END-6. Sugira o nome mais apropriado" (the class is `VoxelBoard`).
5. "commita quando os gates passarem e segue para a END-7." 6. "E esses testes eternos...?" -> the tiered `verify.py`. 7. "Faz os dois,
rápido/completo e boot único." 8. "Sim, segue para o END-8" (Moto, then the Galaxy). 9. "Vamos fazer uma revisão no R3D-END" -> the review sweep.
10. "Sim, faz a limpeza" 11. "Sim, faz a troca de nomes nos docs e o renome" + stop repeating the tests; confirm the transition, that we can go on
in 3D and that we reach 30 fps, or at least 24. 12. "vamos atualizar os masterplans, e o restante da documentação. Depois pode encerrar a sessão."

## Commits (all pushed, `main`)
| commit | what |
|---|---|
| `b00d8a96` | END-3: the 2D cutaway (`apply_occlusion`, ghost records, the 2D wireframe overlay and panel) |
| `1b7cb550` (+`21de56de`) | END-4: the compositors, baked lookup, damage baker, light alternatives, 2D face shader, the bake in `RoomBuilder`; 13 suites and the F5/F8 viewers |
| `9921d014` | END-5: `floor_layer` (the node and its plumbing in 30 classes); the pick and the ground check read `GroundGrid` |
| `1cffeaec` | END-6a: the level layers become arithmetic, the tile readers and `BakeConfig` go |
| `3ca6f1d0` | END-6b: `VoxelRenderer` -> `VoxelBoard` (rename only) |
| `0ee2fdba` | END-7: the canon (rule 8 / hook R8, L1 retargeted, B1/B3/B5 retired) and the docs marked history or rewritten |
| `ac2eebce` | `verify.py`: tiered, fail-fast, a stored baseline, `roundtrip --with-store`, 180-300 s boot timeouts |
| `242ca168`, `824f64d8` | END-8: the R3D-13 matrix on the Moto g04s and the Galaxy A16, no regression; R3D-END closed |
| `9242d169` | the review sweep: dead code and stale comments the END left, the stale F6/F7/F8 help, two dead links, `voxel_variant_registry.gd` |
| `39a1caa6`, `5ffbe282` | the `register_*` renames, the docs renamed, a `smoke` tier as the default, the empty shadow layers, the final verdict |
| this close | the master plans and the rest of the documentation brought to the 2026-09-25 state |

## The state at the close
- **The 2D board is deleted; `34881f81` is the last commit that builds it.** The only tile writer left is `RoomBuilder._place()` for prop tiles.
  Still 2D on purpose: the structure layer (props), actors, the 2D overlays and `VISUAL_GRID_OFFSET` (R3D-PROPS / R3D-ACTORS).
- **Device (release APK, PLAYGROUND, scripted, no finger):** Moto load 15 s (2D 54), PSS 1.1 GB (2.3), idle 19 ms (54), detonation mean
  28-31 ms (102-129); Galaxy load 7 s, PSS 1.3 GB. **30 fps at idle on both and on a detonation's average on the Moto; 24 fps everywhere but a
  hot, charging Galaxy (21-25 fps, the old APK reads the same). Not met: the hitch frames of a blast and a shot, 112-526 ms (R3D-LIGHT).**
  A hand-play check on both handsets is the Director's confirmation.
- **Verification:** 51 selftests; `verify.py` docs / quick / smoke / full; `full` measured 419-433 s (used only to close END-7, END-8 and the cleanup).

## Traps found (worth keeping)
- **A removed side effect is not caught by lint, selftests or pixels.** END-4 deleted the layer material, which also created the level's cell
  plane; only the `board_probe` dump count ("plane levels 6 vs 5") saw it. List a deleted function's side effects first.
- **`pixel_gate.py` times out at 600 s if ANY other Godot is alive, the editor included**; `verify.py` now refuses to start instead.
- **`pixel_gate.py` is blind under 8/255** (a face-tone change of 0.975 -> 0.900 moved ~16 000 px and failed by 5 px): a look change needs a real capture.
- **zsh does not word-split a variable**; a `sed s/e6/e6b/` over a script also rewrote the scratchpad path (`...4e65...`), so the script wrote nowhere and a wait
  loop spun on a log that never came. Two orphaned wait loops ran 2.5 h until the Director noticed.
- **A new class name needs `godot --headless --import` once**, or the lint reports the whole tree broken.
- **The Galaxy's idle swings 23-26 <-> 40-47 ms with heat and USB charging on BOTH APKs**: compare only with an alternating A/B, never a new row against an old table.
- **A gate that reads a tile layer prints PASS on the 3D board** (the old `ground_gate` `tiles 0`, OCC-COMPARE, the level census): read the population it prints.
- **Deleting a doc comment block:** a function's doc can be stacked directly on the next function's doc; delete by anchor, not by "contiguous ##".
- **Zero-warnings rule cannot be checked from the command line** (`project_lint.py` reports errors only; headless Godot prints no script warnings, tested with a bad script).
- **`occ_canonical_gate` failed once (46 s, no digest) and passed alone and in the rerun:** an unexplained flake, not reproduced.

## Left for later
Dead code that predates the END (`_glass_neighbour`, `FacadeSampler.get_window_origin_*`, `GlassCrack.has_craze_art`, `GlassMaterials.fracture_texture_id`,
`OcclusionSet._is_exposed`, `theme_applier.gd`, five dev-tool paths); the 17 `voxel_*.png` atoms and `halves/` folders that no runtime code reads (`ASSETS/materials` is not
in git: the Director's art); no selftest pins the FNV-1a OUTPUT values; `occlusion_overlay.gd` (a dev diamond painter); the unused `tile_size` fallbacks on a few overlays;
dated records, audits and session summaries keep the old `VoxelRenderer` name (`DIRECTION_GLOSSARY` §10 maps it).
