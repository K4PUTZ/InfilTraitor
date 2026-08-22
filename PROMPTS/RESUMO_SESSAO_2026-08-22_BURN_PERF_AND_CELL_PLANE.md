# RESUMO_SESSAO — 2026-08-22 · THE BURN'S STALL, AND WHERE PER-CELL STATE LIVES

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-21_MATERIALS_AND_ASSET_TREE.md`
**Commits:** `dc724b88`, `ca333169`, `12225c84`, `efd3dca6`, `f4d7ca9d`,
`fdbd3258`, `2268d3ac`, `4539c23c`, `ab19db1e`, `20389fc1` — all pushed to `main`.
**Gates at close:** lint 216 ✅ · selftests **39 clean / 0 failed** ✅ ·
invariants ✅ · CODEMAP ✅ · real boot, 0 ERROR.

---

## Read this first if you are resuming

**The burn went from 17 seconds to ~4.1**, and the reason it was 17 was one call.
**Soot no longer touches the TileSet** — a burn mints 150 alternatives instead of
2 175. **A new master plan is open**
([`PERFORMANCE_MASTER_PLAN`](PLANNING/PERFORMANCE_MASTER_PLAN.md), v1.1) and its
**P3 was attempted and reverted**; §3.1 there is the resume point and says
exactly what was ruled out.

The Director's standing ordering, given this session and worth carrying:
*"a prioridade sempre vai ser a performance. Queremos voxels ágeis e
inteligentes, uma arquitetura sólida que permita implementar efeitos sem se
preocupar com desempenho."*

---

## 1. MAT-MAP-01 — the test map (`dc724b88`)

Agent starts at (27,9), between the half-thickness glass panes, central enough
that `throw_range_gu` 7 reaches the brick, cardboard and fabric trios without
walking. Guards 4 → 9, one pair per previously unwatched material, standing ON
that material's own floor zone so a missed shot lands on the material under test.

⚠️ The camera centres on `agent_start`, so **every PLAYGROUND capture reframes**
across this commit. Older `auto_*.png` are not comparable across it.

## 2. MAT-PERF-01/02 — the fire's stall (`ca333169`, `12225c84`)

The Director's own clue was decisive: **the agent stays free to move during the
lag**, which rules out a blocked loop and points at heavy frames.

```
[BURN-PROF] 11 committing frame(s) · 340 voxel(s) · 14 281 ms inside
            _advance_burn, 14 264 ms of it the map-wide repaint · 16 964 ms wall
            clock for a fire whose own schedule spans 1.90 s
```

99.9% of it was `_repaint_voxel_light_buckets(false)` — the FULL, soot-included
repaint — called once per frame that had a voxel due. The firearm moved off that
on 2026-08-19; fire never inherited it.

Fixed with the shape the shot already uses (scoped, soot-free frames) plus **one
full repaint when the fire goes out**, which makes the board exact by
construction. **16 964 → ~4 100 ms**, same 340 voxels, same passage.

⚠️ **The middle change is a requirement, not an optimisation.** With the repaint
removed entirely the SAME fire got **27** committing frames instead of 11 —
cheaper frames buy more frames that mint. So `BURN_COMMIT_INTERVAL_S` is pinned
in GAME SECONDS (0.20). Never re-express it per frame.

**Still open (MAT-PERF-03):** 198 floor cells stay stale after the scoped apply.
Ruled out by measurement: scope size (same 198 at 3/6/10 rings), the
`_placed_by_gu` index, field staleness, and negative-level reach.

## 3. The soot hypothesis, and the plan it produced (`efd3dca6`, `f4d7ca9d`)

The Director read soot as the villain — third appearance of the same symptom.
**Measured, it is not:**

```
53 623 alternatives minted map-wide · 51 059 distinct by (tile, bucket, flip)
→ 1.1x — only 4.8% are soot-code duplicates
```

The multiplier is (source, atlas coords) × LIGHT BUCKET. **But the diagnosis was
right one level up**, and that is the plan: per-cell visual state is delivered by
minting a TileSet alternative and rewriting the cell, so every future effect pays
the same toll.

**PERF-SPIKE-01 passed three gates** — cell → position is exactly AFFINE on all
32 layers; the shader recovers the cell from `VERTEX - local`; a data texture
costs 9.8 MB and 1.1 ms to re-upload all levels against ~1 080 ms for the
map-wide apply.

Two things the spike corrected on its own: the vertex stage costs **1 pixel, not
14** (so P1 folded into P2 rather than landing dead code), and **the flickering
lamp does not flicker** — 0 of 12 lights have `flicker_enabled`, because
`LightingController` deliberately ignores the mapfile's key. The capture
non-determinism is the **guards' vision cones**; `--fixed-fps 60` gives 0.

## 4. P2 — soot leaves the TileSet (`fdbd3258`, `2268d3ac`, `20389fc1`)

Staged reader-then-writer so a broken pixel would name its own half.

```
minted per burn:  2 175 -> 150      stale cells: 1 288 -> 135
blast path: 0 differing pixels      shot path: 0 differing pixels
```

**P2a's proof is the max delta, not the count.** 35 pixels differed, max delta 4
— and the per-ring soot multipliers are 0.33/0.47/0.69/0.84/1.0, so a cell that
resolved to the WRONG RING would move by tens. Nothing did.

Two places where the old shape was load-bearing: the plan's soot wave was gated
on `alt != prev_alt`, which with scorch in its own plane compares EQUAL for every
cell that wave exists for (it would have come out empty, silently); and the soot
FADE stopped minting entirely — a rung is now a pixel write.

**And a defect P2 shipped, found later and fixed** (`20389fc1`): the plane was
indexed from cell (0,0) and **cells go negative**. 109 932 fragments of a 921 600
frame — 12% — were silently taking the clean fallback. Now `cell + ORIGIN`;
out-of-range fragments 0. It changes no pixels today, which is precisely why it
had to be measured rather than looked at.

## 5. P3 — attempted and REVERTED (`ab19db1e`)

The light bucket into the plane's G channel, the ladder as a shader uniform, the
alternative id reduced to the flip alone (which makes minting **zero**). The
picture came out crushed toward black; reverted whole.

Ruled out by measurement: the uniform (reads back exact), the data (300 cells vs
the field, 0 wrong). **The lesson is the gate**: PERF-SPIKE-01's parity
checkerboard is INVARIANT under a constant cell offset, so it proved "one cell
per quad, consistent on the lattice" and never "the RIGHT cell".

**Resume point:** the next attempt needs a gate that can only pass for the
correct mapping (paint `cell.x mod 3` / `cell.y mod 3` into separate channels and
check a KNOWN cell's screen position against a value computed in GDScript), and
it must explain why fragments along GU seams resolved to negative cells.

---

## Carried forward, unrelated

- **MATERIALS M3-6** — fire propagating through the wall's internal slices,
  laterally, chaining from consumed voxels. **The Director's feature request, and
  the two rulings it needs are already given:** fire crosses material boundaries
  gated by the neighbour's own flammability, and wood opens a passage by
  ACCUMULATED BLAST damage (VL-D4 untouched).
- **M3-7** — the per-material passage table as a measured acceptance.
- **MAT-DECAL-01** — decal presence across all materials, the Director's ask.
- The rifle's and pistol's posed frames; the ~500 ms aim warm.
