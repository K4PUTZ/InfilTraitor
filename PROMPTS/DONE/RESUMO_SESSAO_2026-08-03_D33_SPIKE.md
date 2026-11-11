# RESUMO_SESSAO — 2026-08-03 (D33 SPIKE — measured, killed, retracted)

**Continues:** `RESUMO_SESSAO_2026-08-02_DAMAGE_DECALS.md` (D32, closed at
`ALPHA HALF VOXELS AND DECALS 0.9.88`).
**VERSION:** 0.9.88 at start **and at end — deliberately not bumped.** No
production code shipped this arc: the Director's art landed in gitignored
asset folders, the spike was reverted in full, and the three commits are
documentation. VERSION marks shipped state; nothing shipped.
**Mode:** Solo mode.

---

## Executive summary

Three things happened, and the third is the one worth reading.

1. **The Director's first art pass landed** and proved the D32 pipeline end to
   end on real photographic decals.
2. **D33 was planned properly**, and planning it surfaced a cost the original
   answer had not priced.
3. **The Part 0 spike killed D33 — and the kill was wrong.** The Director
   pushed back, the pushback found a defect in my measurement, and D33 is now
   viable. The process failure is documented at more length than the outcome,
   because it is the more transferable part.

---

## 1. Art pass — 18 decals, pipeline proven

18 of 33 decals replaced with real art. Generator re-ran, 97 composites rebuilt,
**84 verified with a silhouette byte-identical to their substrate** (B3 clean).
Bullet-on-concrete reads as a real hole; wood and stone dents and the floor
dents all land correctly, confirmed on a live PLAYGROUND capture.

**Five files were exported without a usable alpha channel** and paint the whole
face as a solid rectangle: `dent_metal_0`, `dent_metal_1`, `dent_concrete_0`,
`dent_earth_2`, `crack_stone_2`. Two more (`crack_concrete_0/1`) carry a
mean border alpha of ~57 and wash the face with a faint veil — visible, not
broken. Reported with the measurement (mean border alpha) rather than by eye,
so the Director could tell "broken" from "soft" without redoing good files.
He chose to improve the art later; the pipeline was the point and it is proven.

---

## 2. D33 planned — and the plan found a cost

Writing `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` surfaced what the original
D33 answer had missed: **baked sources are rebuilt on every rotation and damage
persists across rotations.** Measured scale, one real grenade: **197 damaged
cells** (54 wall dented + 44 wall cracked + 99 floor dented), 886 KB of unique
32×36 composites. That drove a Part 0 measurement spike with an explicit kill
criterion, written *before* any measurement.

---

## 3. The spike, the kill, and the retraction

### What was measured

| | Result |
|---|---|
| **S1** cost of one composite | 0.31 ms (1×) · 1.10 ms (4×) — feasible |
| **S2** reuse among damaged cells | 1.04× (190 composites for 197 cells) — the rescuing cache saves nothing |
| **S2b** substrate survival across a rotation | **0 of 68** overlap |
| **S3** rotation baseline | `_set_perspective()` = **1918 ms** |

From S2b I concluded the cost was per-rotation and structural, projected 916 ms
at fifteen grenades against a 150 ms criterion, and killed it. I explicitly
refused to relax the criterion after the fact, which was right.

### Why the kill was wrong

The Director asked whether dropping rotation would make it work, and added
*"me parece tão trivial isso"*. That instinct was correct.

S2b measured whether a damaged cell's substrate changes across a rotation. It
does — **because rotating shows a different physical face of the wall.** That is
correct behaviour, not resampling. And the cache key I had planned was
`(page_idx, atlas_coords)` — **screen-space**, which cannot survive a rotation
by construction. I measured my own key and concluded the idea was dead.

### The measurement that settles it

Same 197 cells, N → E → **back to N**:

```
view N          68 distinct substrates
view E          68 distinct       N∩E  = 0    → 68 new composites
view N (back)   69 distinct       N∩N' = 67   → 97% CACHE HIT
```

Substrates are **stable per view**. A rotation composites only what that view
has not seen: **61 ms once per view per detonation, ~0 thereafter.** The
criterion is not breached and rotation does not need to be dropped.

### What the constraint actually is

**Memory, not time.** Worst case `cells × views × 4.6 KB` ≈ **54 MB** at 2955
cells across four views, against the 75.9 MB of bake pages D21 measured. Needs a
cap with eviction — that, not the timing, is what Part 1 must design around.

**Still unproven:** the cache has to outlive the room rebuild, which clears
`_baked_source_ids` and rebuilds every Voxel from the MapSpec. It must hang off
something with room lifetime and be keyed in base space.

### Process lesson, recorded because it cost a full spike

**Measuring the thing you designed proves only that you designed it that way.**
The spike validated my cache key instead of the question. And when a measurement
says an obviously-simple thing is impossible, the measurement is the more likely
suspect than the simplicity.

---

## 4. Findings that belong to the engine review, not to D33

The Director's next step is a whole-system reassessment — opportunities and
threats. These came out of this arc and are inputs to it, not D33 items:

- **`_set_perspective()` costs ~1918 ms.** Nearly two seconds per camera
  rotation, with one grenade's damage on the map. Never measured before. The
  per-view re-bake is the obvious suspect; whether it is *necessary* per view is
  the question worth asking.
- **Bake budget:** 17 pages / 75.9 MB RGBA on PLAYGROUND, of which ~18 MB per
  baked ground material (D21). The ceiling is per-MATERIAL, not per-storey.
- **Alternative-id space:** 1536 of 4096 used (12 light buckets × 64 soot codes
  × 2 flips). Per-face light would need 3456+ and blow it. Any future per-cell
  visual axis competes for this same space — it is the scarcest resource in the
  renderer and nothing outside `voxel_renderer.gd` says so.
- **`docs/ARCHITECTURE.md`** is self-declared unreconciled since 2026-07-03 for
  bake closure, the screenshot hook, occlusion and destruction. 761 lines. A
  reconciliation task, not a sweep.
- **Evidence citations decay by design** — 16 of 23 captures cited across the
  docs are already gone to the 50-file rotation. Documented in CLAUDE.md this
  session with the fix (name long-lived captures without the `auto_` prefix).

---

## 5. State at close

- **VERSION 0.9.88**, unchanged and correct — no shipped code this arc.
- Working tree clean; spike reverted twice and verified (`grep` for `_d33_`
  returns 0).
- `project_lint` PASSED · `run_selftests` 20 clean / 0 failed ·
  `check_invariants` OK · `gen_codemap --check` clean.
- **D33 status: ✅ viable, Part 1 not started, awaiting the engine review.**
  `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` §9 is the wrong answer kept
  verbatim; **§10 supersedes it** and is what to read.
- 15 decals remain placeholders; 5 authored ones need re-export with alpha.

## 6. Next session starts here

**Engine reassessment — opportunities and threats, whole system.** Not started.
§4 above is the pre-loaded evidence for it. D33 Part 1 waits behind it by the
Director's own sequencing.
