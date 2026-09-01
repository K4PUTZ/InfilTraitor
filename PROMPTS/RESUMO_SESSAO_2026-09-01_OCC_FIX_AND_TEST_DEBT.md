# Session 2026-09-01 — the occlusion wedge, and what pulling on it unravelled

> ⚠️ **This is PART 1 of the day.** The session continued straight into the glass
> track and G3 closed. The current state is
> [`RESUMO_SESSAO_2026-09-01_PART2_GLASS_G3_COMPLETE.md`](RESUMO_SESSAO_2026-09-01_PART2_GLASS_G3_COMPLETE.md)
> — the "State at close" table below is superseded by that file's (the suite grew
> 48 → 49 and the glass work landed after this was written).

Started as one visual bug report and ended as a sweep of two defect classes that
had been quietly disabling parts of the project for weeks. Six commits, all on
`main`, all pushed.

| | commit |
|---|---|
| OCC-FIX-03 | the wireframe's top cap no longer collapses onto the scene origin |
| OCC-FIX-03b | the rest of the `get_layer(0)` sweep, pinned by invariant L1 |
| OCC-FIX-03c | widen L1 to any literal level, and the four sites that found |
| MAT-COHERENCE-01 | nothing is instantiated without art — and a gate that keeps it that way |
| TEST-DEBT-01/02/03 | the invisible tier: eight ungated test files, two of them red for weeks |

---

## 1. The reported bug

Director, on GLASS: *"temos uma questão com a oclusão. Parece que ela está se
confundindo com a iluminação e projetando um rastro pro teto."*

A translucent grey wedge fanning from a ghosted wall's top rim up past the top of
the screen. It reads as a light shaft, which is why it looked like lighting. It
was not: `INFILTRAITOR_WF_HIDE=1` removed 100% of it.

**Cause — LEVEL-RENUMBER residue.** `OcclusionWireframeOverlay._voxel_to_screen()`
falls back to extrapolating for levels with no layer built — in practice
`max_level + 1`, exactly where the ghost band's TOP CAP lives. That fallback
anchored on `get_layer(0)` and offset by the ABSOLUTE level, both written when the
ground plane WAS level 0. With it at `PLAYABLE_LEVEL` (80) the lookup is null on
every map, the guard returned `Vector2.ZERO`, and every cap point landed on the
scene origin. Each cap quad became a triangle from the wall's real rim to (0, 0).

Fixed by asking the renderer where its own origin is: `ground_plane_level()` and
`relative_level()`.

**Measured** (GLASS, agent (11,16), zoom 0.28, erase-diff against a same-boot
`WF_HIDE` control): the ghosted wall's own pixels span y 153..475; the wireframe's
went from y 0..478 (81 564 px) to y 153..478 (28 053 px). 53 511 phantom pixels,
every one above the wall it claimed to outline.

Full write-up, with the arithmetic check of the corrected fallback:
[`docs/systems/occlusion.md`](../docs/systems/occlusion.md) §OCC-FIX-03.

## 2. The class it belonged to

`get_layer(0)` survived at ten more sites. The two that mattered visually were in
the occlusion system; the rest were silent:

- `grenade_prop::_apply_z_index()` — a no-op, so `set_airborne(false)` restored
  nothing and a **landed** grenade kept the flight z_index, drawn over every wall.
  D22-FOLLOWUP's own bug, reintroduced by a number rather than a decision.
- `floating_collectible` / `agent_probe_prop` `_apply_z_index()` — same no-op.
- `room::_debug_probe_voxel_alignment()` — aborted on every map.
- `damage_gallery_debug::_gallery_ceiling()` — looked for the roof Slab at level
  16 instead of 96, reporting **8 of 8 CEILING probes as "no Slab"**.
- four selftests passing against fixtures 72–80 levels from the geometry they
  were named for.

**Pinned by a new invariant, L1 `level-never-a-literal`** (CLAUDE.md rule 9,
pre-commit-hook checked): any integer literal passed to `get_layer()` outside
`voxel_renderer.gd`. It started narrow (0 / −N) and that was the wrong half — a
stale POSITIVE literal resolves to a real layer eighty levels from where it means,
so nothing is null, nothing warns, and the code quietly describes a different
building. Widening it is what found the last four.

## 3. "Is anything instantiated without art?"

Director's question, on reading the gallery's CEILING row. **Answer: no**, and my
"art gap" line in the OCC-FIX-03c report was wrong and is retracted. Metal and
wood have `crack_factor == 0.0` (D32.6) — the tier is unreachable by data, so
there is nothing to bake. And the gallery's `MISS` only means "no PRE-BAKED atom";
it calls the swap directly and never reaches the D33 fallback every production
caller has.

Gated from now on by `voxel_decal_selftest` **[12]**, which enumerates materials
by walking `ASSETS/materials/<id>/<id>.json` — the same scan the resistance table
does — so a material added tomorrow is covered the day it lands.

## 4. The invisible tier

`run_selftests.py` globbed `*_selftest.gd` only. Eight `*_test.gd` files sat
outside it, ungated, **exiting 0 whether they passed or failed**:

- `bake_cache_test` had been **1 PASS / 6 FAIL** since the 2026-08-21 asset-tree
  reform gave `TextureResolver.resolve()` a material-folder argument.
- `occlusion_set_test` had been **2/5 on an EMPTY set** since the 2026-08-24 level
  renumber, one of its two "passes" reading
  `✓ Cardinality reasonable: 0 cells (expect dozens)` — a guard that accepted the
  degenerate answer.
- `prop_01_tests` 4/7; `panel_base_test` leaking two orphan nodes.

Both regressions predate this session and both files had a written record of
passing months earlier. Nothing regressed them on purpose; nothing could say so.

All eight are now **inside the glob**. The last two needed the harness to change
rather than the code: Godot registers autoload names as parse-time globals only
for a MAIN SCENE run, so `prop_01_selftest` and `version_info_selftest` became
`*_selftest.tscn` and the runner launches those as scenes. `version_info` had
never run once since it was written (it failed to LOAD); `prop_01`'s criterion 7
had only ever skipped itself while counting the skip as a pass.

⚠️ **`SceneTree.quit(code)` is DEFERRED** — a failing branch must `return` too.
`version_info_selftest` did not: a deliberately inverted TEST 2 printed ❌, fell
through the remaining tests, printed the PASS banner and exited **0**. Measured,
then fixed; the other 46 were swept and call `quit(1)` only as their terminal
verdict.

## 5. Maps

Director: *"não existem mapas autorados ainda, tudo é apenas ambiente de testes."*

- `SIGMA_01`: 9 `crate_*` sprite props removed — they stopped existing when
  scenery became voxels, and were 9 `push_error`s per boot with nothing drawn.
- `SIGMA_01` / `TEXTURES` / `TEST_BLOCKS` / `FLOOR_ZONES_TEST`: `damage_materials`
  added. `FLOOR_ZONES_TEST`'s grass/sand/dirt turned out to have real
  `slab_<id>.png` art (1024×1024) that was simply never asked for.

**All six maps boot with zero errors and zero warnings.**

## 6. Also fixed along the way

- `check_decal.py` and `check_facade.py` **crashed on their own usage path**
  (`__doc__` is `None` — the headers are `##` comments, not docstrings).
- `slice_geometry_selftest`'s "Check 1: E1 (layer transform)" asserted nothing and
  printed a formula that omitted `TILE_OFFSET`. Now builds a real renderer; the
  historical 8 px error produces 3 mismatches.
- One genuinely dead docs link (`detonation_choreographer.gd`, deleted by D-6),
  found by sweeping all 276 relative links.

---

## State at close

| gate | result |
|---|---|
| `project_lint.py` | PASS, 224 files |
| `run_selftests.py` | **48 clean, 0 failed**, NOT RUN section empty |
| `check_invariants.py` | PASS (R1–R5, B1, B4, **L1**) |
| `gen_codemap.py --check` | fresh |
| `check_facade.py --all` | 10/10 |
| `check_decal.py --all` | 54/54 |
| all six maps | 0 errors, 0 warnings |

The suite was 40 gated plus 8 invisible when the session started.

## Open, needing nothing

Nothing is blocked. The one thing deliberately left alone: `project_lint.py`
still whitelists 9 files for headless autoload false positives. That is a real
limitation of `--script` compilation, not a defect — and the two tests that
actually needed autoloads now run as scenes instead of fighting it.
