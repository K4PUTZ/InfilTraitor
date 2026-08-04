# RESUMO_SESSAO — 2026-08-04 (PERF-02)

**Continues:** `RESUMO_SESSAO_2026-08-04_VFX01_DETONATION_PERFORMANCE.md`
(PERF-01 shipped, PERF-02 fully planned and zero code written).
**VERSION:** 0.9.89 at start → **0.9.89 at close** (no bump — that's asked for
explicitly, "push with tag," and wasn't this session).
**Mode:** Solo mode.

---

## Executive summary

PERF-02 shipped end to end: all three Part A performance items and all four
Part B explosion-reduction items. One real detonation on PLAYGROUND went from
**3716.7 ms to 1250.9 ms — 66% faster**, with the whole Part A verified
pixel-identical to the pre-session capture.

Three of the plan's decisions did not survive contact with the code. All three
were caught by running the real path, not by reading it, and two of them
needed a Director ruling before they could be finished.

Full decision-by-decision record, the measured stage table, and the acceptance
evidence: `PROMPTS/PLANNING/DETONATION_PERFORMANCE_MASTER_PLAN.md` (§3 table,
§7 results, D4-D10 rows).

---

## 1. What shipped

| Item | Result |
|---|---|
| **A1** batch composite uploads | 197 uploads / 876ms → **5 / 8.1ms** |
| **A2** cached half-voxel polygon masks | 362ms → **17.2ms** (same 459 ops) |
| **A3** cached decal pre-resize *(substituted — see §2)* | `paste_decal` 972ms → **774ms** |
| **B1** rings 4 → 3 | slices 14 → **6**, floors 42 → **24** |
| **B2** resistances ×0.65 | wall voxel churn down across all four materials |
| **B3** bomb-only wider soot | grenade soot 925 → **1477** voxels, weapon **unchanged** |
| **B4** one floor depth layer per blast | deep plane skipped in the same blast, reachable in the next |

---

## 2. The three plan corrections

**A3 (D6) — the specified fix was a regression.** The byte-buffer rewrite of
`paste_decal()` was built exactly as planned and measured **slower**: 901ms →
981ms across the same 285 calls. Timing the pre-resize separately explained
why: the function is dominated by the 4×4 supersample *arithmetic* (~845ms),
not by pixel fetch, and in GDScript one native `get_pixel()` call beats ~10
interpreted byte/LUT operations. No pixel-access mechanism can fix an
arithmetic-bound loop. Reverted verbatim, and replaced with the win that was
actually there and that the plan never noticed: the per-call Lanczos
pre-resize, re-run 285 times on the same handful of (decal, native) pairs, is
now cached — 133.8ms → 5.7ms. Same Part A discipline (mechanism only), and
the equality selftest reports identical numbers before and after.

**B2 (D8) — the new numbers broke two selftests encoding older Director
statements.** Wood fell to 59% destroyed against a hardcoded `>=70%` ("quase
toda destruída"), and metal's dent_factor (0.5 → 0.3) landed exactly level
with earth's untouched 0.3, breaking a strict-ordering check *on a tie that is
correct behaviour*. Not resolved unilaterally — weakening an acceptance test to
close a task is banned. Director ruled: keep ×0.65, update the tests. Both were
rewritten to assert the property instead of one session's numbers: wood's
threshold moved to 55% **and** gained a new assertion pinning it as the highest
destroy_factor in the table; the dent check now reads the live factors and
requires equal factors to produce equal counts.

**B3 (D9) — two false premises, and the first one made the feature inert.**
The plan stated `Voxel.damage_is_blast` already separates bomb from weapon
damage. It does not, for holes: `set_damage(DESTROYED)` was called with no
`from_blast` argument on every bomb path, so every crater read as firearm
damage. Since holes are exactly the soot BFS's seeds, the first implementation
did **nothing** — 925 sooted voxels with the wider radius, 925 without,
byte-identical. That is the "green selftest, inert on the real map" failure
this project already documented once (the floor-dent lesson); it was caught
the same way, by running the real path and comparing real counts. Second
premise: 5 rings are not representable at all — the per-face soot encoding is
2 bits (0/1/2 real, 3 = CLEAN), so rings 3-4 would clamp to CLEAN and render
as *no soot*. Director ruled: keep 3 intensities, spread them over 5 cells.
Implemented as an additive `intensity_rings` parameter defaulting to `n_rings`,
so every pre-existing caller stays bit-identical.

---

## 3. Evidence discipline notes

- Baseline was **re-measured this session** with the same instrumentation used
  for the "after" numbers, rather than compared against the previous session's
  recorded figures — so before/after are strictly comparable. The per-cost-centre
  breakdown reproduced the previous session's table almost exactly (972 vs 975ms
  `paste_decal`, 876 vs 883ms upload, 362 vs 362ms half-voxel), which is itself
  a check that the instrumentation measures the same thing.
- Part A's three captures were diffed against the baseline capture: **0 pixels
  differing by more than 8**, max channel diff ≤ 3. That is the proof A1's
  deferred upload does not leave voxels transparent — a real risk, since an
  un-uploaded composite slot samples transparent rather than stale.
- A1's flush therefore runs before every frame yield, not only at the end of a
  pass as the plan specified; batching purely to the end would have made every
  damaged voxel invisible for the ~2s the async spread takes.
- The four-material captures are hand-named (`Screenshots/history/perf02_*.png`)
  so the 50-file `auto_` rotation cannot eat them, per CLAUDE.md's own rule about
  citations decaying.
- `ERROR: 3 resources still in use at exit` on capture runs was checked against a
  stashed HEAD build and appears there too — pre-existing, not introduced here.
- All temporary instrumentation reverted: `grep PERF-DEBUG` returns nothing
  outside documentation prose.

---

## 4. State at close

- **VERSION 0.9.89** (unchanged).
- `project_lint` PASSED · `run_selftests` **29 clean / 0 failed** ·
  `check_invariants` OK · `gen_codemap --check` clean.
- Master plan updated in place with results, the three corrections, and the
  measured stage table.

## 5. Next session starts here

**The light repaint is now the bottleneck.** `_repaint_voxel_light_buckets()`
sits at ~648ms — **52% of what a detonation now costs** — because nothing in
PERF-01 or PERF-02 touched it. It was never in this plan's scope and is the
obvious next target.

After that (or instead, at the Director's call) the two deliberately deferred
ideas in the master plan's §6 are still waiting, in the Director's own
sequencing: **D11** the three-stage destruction with the red/yellow/white
flash cascade, and **D12** the real-explosion video/flipbook overlay. Neither
has been started; D12 still needs the Director to hand over the source footage.
