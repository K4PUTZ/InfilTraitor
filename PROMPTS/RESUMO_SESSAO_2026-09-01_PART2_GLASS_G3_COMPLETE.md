# Session 2026-09-01, part 2 — the glass arc: G3 closes

Part 1 is
[`RESUMO_SESSAO_2026-09-01_OCC_FIX_AND_TEST_DEBT.md`](RESUMO_SESSAO_2026-09-01_OCC_FIX_AND_TEST_DEBT.md)
(the occlusion wedge, the `get_layer(0)` sweep, invariant L1, and the invisible
test tier). The session continued straight into glass; **this file is the current
state**, and part 1's "State at close" is superseded by the table at the bottom.

| | commit |
|---|---|
| G-D13b | a remnant is ANCHORED or it is not a remnant |
| §5.4 | where a shard LANDS — the proposed architecture |
| G-D16a | `GlassFall` — one fall rule for base piles, counters, sills and skylights |
| G-D17 | a round loses power through every glass layer it crosses |
| G-D19/G-D20 | the 50% is not an alpha; a pane fracture is not a baked sheet |
| G-D21 | …it is a facade sheet RE-ANCHORED onto the impact |
| G-D23/G-D24 | the crack clamps instead of mirroring; where two fractures cross, the glass falls out |
| G-D23 | the pane-size ceiling, enforced in `GlassPaneGrouper` |
| G3-D | **Stage D — the movement/vision split, and the passage opening** |

---

## What the Director corrected, and it is most of the value here

Three of my proposals were wrong and were replaced by theirs. Recording that
plainly, because the reasoning is what the next session needs:

1. **The remnant rule.** G-D13 spared survivors on the pane's own bounding box
   and forced at least four. GLASS's big pane has nothing around it, so it kept
   shards hanging in mid-air. → **G-D13b:** a shard survives only where an
   orthogonal neighbour is non-glass. Measured on the reported pane, same shot,
   same salt: **848 destroyed before, 882 after** — 34 floating shards now fall.

2. **The pane fracture.** I proposed the facade path — one sheet anchored to the
   pane. The Director's objection was decisive: a facade is anchored to the
   STRUCTURE, a fracture to the EVENT, and the hole has to sit on the voxel the
   round actually hit. I then proposed a tile mosaic (G-D20); the Director
   pointed out that assembling tiles is doing by hand what the bake already does
   with an offset. → **G-D21:** re-anchor the sheet by offsetting
   `(column_in_run, level)`. It is a subtraction, the atoms compose once at load,
   and a shot mints nothing.

3. **The second shot.** I proposed a per-voxel "nearest impact wins" tiebreak
   with no answer for two fractures crossing. → **G-D24:** where they cross, the
   glass falls out. Free (DESTROYED is native), physically right, and it deletes
   the bookkeeping before it was written.

## What was built

**G-D13b — anchored remnants.** `collect_anchor_positions()` is pure (takes slice
lists, never the registry). Fixing it exposed a real defect on the way in:
`plan_pane_shatter` built its lattice from every voxel of every slice sharing the
`pane_id`, and a G-D9 banded window keeps its brick sill and head in those same
slices — nothing consulted `material_at()`, so a won roll **destroyed 91 of 96
brick voxels**, taking the pane's own frame with it. Proved red first.

**G-D16a — `GlassFall`.** One rule: a destroyed glass voxel falls straight down
its column to the first horizontal surface. Base pile, counter top, sill and a
skylight dropping a storey are then the same code. Wired into BOTH real paths on
day one and reported there, because §7.1's own risk note is that this project has
shipped two features that were built and never triggered. Real map:
`882 of 882 shard(s) landed, on 37 cell(s), deepest pile 24`.

**G-D17 — the layer modifier.** `punch · 0.62^depth`, applied to the whole
projectile. Depth 0 unattenuated, so §5.1's ratified arsenal table is untouched
by construction. Sniper: `5.25 → 3.25 → 2.02 → 1.25`, P(shatter)
`81% → 29% → 4% → 0%` — it stops mattering at the fourth pane by the curve alone.
⚠️ The GLASS map had **no line crossing two panes** (every panel on row y=9), so
the mechanic was unverifiable on it; a second row was added and the map's
description says why.

**G-D23's ceiling.** `GlassPaneGrouper` unioned panels with no size bound at all.
Now `oversize_panes()` (the decision) + `_check_pane_size()` (the loud report,
naming the fix). ⚠️ **Testing it corrected the documented fix:** a G-D9 `bands`
entry does NOT split a pane — a banded window is still base-glass and the
union-find never reads `material_bands`. Found by widening GLASS's big pane,
which then merged with the brick-capped window into one 12 GU pane. A real
divider is a non-glass panel or a gap.

**G3 Stage D.** The problem was a conflation: one edge set fed movement, vision,
detection, noise and light, and glass entered none of it. A second set
(`build_movement_edge_set`) is consulted only where feet are involved, and asks
`PassageQuery` rather than a boolean — so a broken pane stops being added and the
passage opens with no second record of what is broken. Real map:

    boot          glass edges=14 | vision blocks=88 | movement blocks=102 (+14 glass)
    after break   5 of 6 pane edge(s) OPEN [NONE, STANDING x5] | still blocking: 9

## Deliverable for the Director's art pass

**Glass Fracture Plates** — procedural vector simulations of every glass decal
family, each drawn at the 256 px authoring canvas and, beside it every time, at
the **16×20 px** the player actually sees. One generator feeds both boxes, so the
small render is provably the same artwork. Published as an artifact.

The Stable Diffusion answer is in §7.3: realism yes; opacity via *generate on
black, alpha = luminance* (no matting model); and SD will **not** produce
edge-matching tiles — generate one large fracture and cut the grid out of it.

## Three of my own mistakes, kept in the files that carry them

- `glass_fall_selftest [2]` asserted 5 shards on the floor; the right answer is 6
  (a shard level-with a counter top is beside it, not on it). My arithmetic.
- `glass_shatter_selftest [12]` aimed at `12*8+4` instead of the lattice centre
  103, leaving a column outside the radius that read as "remnants survived".
- `passage_query_selftest [10]` passed a bare `0` as the storey to clear and
  cleared nothing (a storey-0 wall sits at levels 80..87). **L1, written this same
  session, only guards `get_layer()` literals — a bare storey walked past it.**

---

## State at close

| gate | result |
|---|---|
| `project_lint.py` | PASS, 226 files |
| `run_selftests.py` | **49 clean, 0 failed**, NOT RUN section empty |
| `check_invariants.py` | PASS (R1–R5, B1, B4, L1) |
| `gen_codemap.py --check` | fresh |
| `check_facade.py --all` / `check_decal.py --all` | 10/10 · 54/54 |
| all six maps | 0 errors, 0 warnings |
| docs relative links | 276 checked, 0 dead |

## Where to pick up

`GLASS_MASTER_PLAN` is **v1.14 — G3 COMPLETE**. Its status header now carries the
full "what is left and what each is blocked on" table; the short version:

1. **G-D8's last third** — light bump + 1 detection step when a passage opens.
   Needs the opening as an EVENT; Stage D landed a per-turn recomputed SET.
2. **The crack itself** (G-D19/G-D21/G-D23's clamp/G-D24) — blocked on
   `glass.crack_factor` still being 0.0 **and** on the art. `voxel_decal_selftest`
   [12] will require data, wiring and art together.
3. **G-D16b** — shards on screen, blocked on the `shard_floor` art.
4. **G-D16c/d** — skylights and sub-GU slab regions. CEILING glass still renders
   opaque (`voxel_renderer.gd:3676`) and there is no horizontal `pane_id`.
5. **A solid glass CUBE** — `PANE_BLOCK_*` has no run axis, and
   `_note_glass_crossing()` dedupes by `pane_id`, so entering and leaving a block
   counts as one layer.
