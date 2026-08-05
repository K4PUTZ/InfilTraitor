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

## 3b. Follow-up round (B3-2 / B2b) — both Director-initiated

**B3-2 — four soot tones instead of three stretched over five.** The Director
rejected the flat outer band B3 shipped and asked for five intensities over
five cells. Chasing it corrected *my own* earlier answer: I had said five was
blocked by the alpha carrier the per-face code rides in. That was wrong, and a
two-line probe proved it — packing 216 levels into the carrier and capturing a
real detonation came back pixel-identical to the 64-level build. The actual
limit is the **alternative-id ceiling**, read out of the engine
(`TRANSFORM_FLIP_H` = 4096) rather than assumed: 5 tones need 6³ = 216 codes
and peak at id 5183, over the ceiling; 4 tones need 5³ = 125 and peak at 2999.
So the encoding moved to base-5 and the blast reaches 4 cells — one cell per
available tone.

The measurement that shows why the Director was right on the outcome, same
index-0 blast:

| | r0 | r1 | r2 | r3 | total |
|---|---|---|---|---|---|
| original (3 rings) | 156 | 306 | 302 | — | 925 |
| B3 (3 tones over 5 cells) | 156 | 306 | **653** | — | 1477 |
| B3-2 (4 tones over 4 cells) | 156 | 306 | 302 | **267** | 1196 |

B3 was doubling the thickness of the faintest tone; B3-2 restores r0/r1/r2 to
their original counts and gives the extra reach its own step. The weapon path
is untouched — r3 is 0 on all three faces, r0/r1/r2 bit-identical. Minted tile
alternatives went *down* (1175 new vs 1378), since 4 cells soot fewer voxels
than 5. Face-separation guarantee re-verified across the larger code space:
0/1,890,000 collapses.

**B2b — resistance retune.** Wood 0.6 → 0.75 and metal dent 0.3 → 0.35: the
flat ×0.65 ignored what each material reads as, and the two places it hurt were
exactly the two the selftests caught. Wood measures 75% destroyed again, so the
70% threshold this session had lowered to 55% is **restored** rather than left
loose — a threshold that no longer matches the statement it encodes is worse
than no threshold. Metal's dent prevalence is strictly ordered again (83 >
earth 69 > concrete 34). Detonation timing unchanged: 1256.3 / 1245.9 ms
against the committed 1250.9 / 1282.9 — B1's ring cut, not this table, is what
made the explosion small.

---

## 3c. PERF-03 — the light repaint (Director-directed, after PERF-02 closed)

The repaint was 52% of a detonation and nothing had touched it. Profiling put
**573 of its ~648ms inside `apply_light_field()`**, and inside that:
**106,847 cells walked to change 1,303** — with `bucket_for()` alone at 362ms,
because `VoxelLightField.build()` had just cleared the cache that would have
answered for every unchanged cell.

The fix writes itself once you read `_static_factor`'s own doc, which had
already anticipated the reuse ("a detonation no longer has to invalidate the
light bucket of every voxel it scorches") — the unconditional clear in
`build()` is what defeated it. Added a `geometry_only` flag (default false, so
map load / rotation / light changes are untouched) that invalidates only the
cells the new occupancy and soot actually touch, with the neighbourhood derived
from what the cached values really read rather than guessed: ±1 in XY and +2 in
level, traced through `surface_factor()` and `_face_occlusion()`. `_lamp_cache`
survives entirely, since a detonation moves no light and never re-runs the
shadow projector.

**`bucket_for` 362ms → 42ms; detonation 1250.9/1282.9 → 920.7/925.3ms (-26%).**
Against this session's own starting baseline: **3716.7ms → 920.7ms, 75%
faster.**

**The verification is the part worth remembering.** A capture diff on the
weapon-bench path showed 273 pixels differing — which looks exactly like a
staleness bug. A control run of two IDENTICAL configurations differed by 259,
i.e. the same magnitude: VFX particle variance, not staleness. What actually
settled it was a cell-level equivalence probe — snapshot every cell's
alternative after the fast path, force a full rebuild, diff — which returned
**0 of 106,847 differing on the grenade path and 0 of 106,459 on the weapon
bench**. Kept as a standing env-gated tool
(`INFILTRAITOR_LIGHT_EQUIV_PROBE=1`), because it guards a regression nothing
else can see: widen `_face_occlusion()`'s sampling radius and the invalidation
neighbourhood silently becomes too small, with no visible symptom until someone
looks at the right voxel.

---

## 3d. D11 — the destruction cascade, and a self-inflicted regression caught and fixed

Director, continuing the same session: *"O sistema do frame a frame ainda
está esquisito, dando engasgadas... aplicar primeiro destruição total;
depois voxels dented; e por fim voxels cracked... com um frame vermelho, um
frame amarelo, um frame branco... soltamos a fumaça... enquanto ela ainda
está subindo, aplicamos a fuligem."* Built exactly that: three render stages
filtered by `Voxel.DamageState` (`process_dirty_async()`/
`process_dirty_slabs_async()` gained an optional `states` filter), a
red/yellow/white flash between stages, VFX-01's smoke/dust/spark/chip
dispatch buffered during the cascade and released as one moment afterward,
and the soot/light repaint deferred to land while that smoke is still
rising.

**Then the first real measurement was 8.9 SECONDS — a 10x regression**, worse
than the freeze PERF-01/02/03 exist to fix. Root cause, chased the same way
as everything else this session (measured, not reasoned): PERF-01's
`voxels_per_frame = 150` count had to become a time budget (staged batches
are wildly uneven — erasing a hole is free, compositing a decal is not), and
the naive 8ms guess ("half a 60fps frame") forced a yield almost every 1-2
decal voxels. Each yield re-uploads the touched damage-composite page
(PERF-02 A1's own contract), and — on this session's off-screen dev-capture
harness specifically — the frame that renders right after a page upload
measured ~150-190ms, against 16ms for an idle frame on the same scene. 47
such yields is where the 8.9s went.

Fixed by raising the budget, chosen from a measured curve rather than a
second guess: 8ms→8940ms, 40ms→2674ms, 100ms→1375ms, **200ms→995ms**,
unbounded→853ms. 200ms sits within ~8% of the unbounded floor while still
yielding when a stage genuinely needs it (this blast triggered exactly one
yield, not zero), so a much bigger future blast still spreads across frames
instead of freezing.

**Correctness was proven, not eyeballed.** A real capture of the final
cascade differed from a pre-D11 capture by 518 pixels (max diff 44) — too
much to wave off, not obviously a bug either. The real proof: a probe that
snapshots every touched voxel's placed tile, force-re-renders them through
the OLD single-sweep path, and diffs — **0 mismatch across all four
PLAYGROUND materials**. The 518 pixels were debris/dust particle timing
noise (smoke now releases as one buffered burst instead of trickling
per-voxel, so the same fixed wait-frame count catches the physics at a
different relative age), not a placement bug. Kept as a standing env-gated
tool (`INFILTRAITOR_CASCADE_EQUIV_PROBE=1`).

Result: **detonation ~950-1030ms**, barely more than the flat ~920ms PERF-03
baseline, now delivered as three organic stages with three screen beats
instead of one undifferentiated sweep.

---

## 4. State at close

- **VERSION 0.9.89** (unchanged).
- `project_lint` PASSED · `run_selftests` **29 clean / 0 failed** ·
  `check_invariants` OK · `gen_codemap --check` clean.
- Master plan updated in place with results, every correction (including
  D11's own regression-and-fix), and the measured stage tables.

## 5. Next session starts here

**The repaint bottleneck is closed** (see §3c) — a detonation is now
~950-1030ms with the full D11 cascade, down from 3717ms at this session's
start. The next available cut in that arc is scoping the light repaint's
cell walk to the blast's own GUs, reusing VL-03's existing
`apply_light_field_gus()` seam; it needs the `_placed_by_gu` placement index
kept current for the cells `reveal_floor_slab()` adds mid-blast.

D11 itself is shipped; the two still-deferred ideas from the earlier
planning session — D12 (real-explosion video/flipbook overlay, still
waiting on the Director's source footage) and the standing open items
(shotgun height-limit calibration, the 5th soot tone, per-face light) — are
unchanged by this session's work.

The two deliberately deferred
ideas in the master plan's §6 are still waiting, in the Director's own
sequencing: **D11** the three-stage destruction with the red/yellow/white
flash cascade, and **D12** the real-explosion video/flipbook overlay. Neither
has been started; D12 still needs the Director to hand over the source footage.
