# RESUMO_SESSAO — 2026-08-22 · THE CELL GATE, AND WHERE THE FIRE'S TIME REALLY GOES

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-22_BURN_PERF_AND_CELL_PLANE.md`
**Commits:** `e25d25bc`, `6d88886c`, `a90f8f3c`, `2e224825`, `dbb2a95e` — all pushed to `main`.
**Gates at close:** lint 216 ✅ · selftests **39 clean / 0 failed** ✅ ·
invariants ✅ · CODEMAP ✅.

---

## Read this first if you are resuming

The Director ratified a reordering: **gate → P5 → P3**. The gate is built and
found two shipped defects. P5a is done. **P3 is blocked** on the gate's residual
(§3.3 of the plan). The biggest number on the board is now
[`PERFORMANCE_MASTER_PLAN`](PLANNING/PERFORMANCE_MASTER_PLAN.md) §3.4's
unattributed ~23 ms/frame during a fire.

## 1. P3's premise was wrong by ~40x (`e25d25bc`)

`INFILTRAITOR_APPLY_SPLIT_PROBE=1` splits the map-wide apply three ways. On every
repaint after the boot the half P3 removes is **0.7–30 ms of ~1 200**; the rest
is derivation (754 ms) plus the walk (458 ms). §4 of the plan defers P5 because
it is "masked by a delivery cost five times larger" — the delivery cost is ~40x
SMALLER. The Director ratified running P5 first.

## 2. The cell gate, and two defects it found (`6d88886c`, `a90f8f3c`)

`INFILTRAITOR_CAPTURE_ACTION=cell_index_gate`. Every pixel names itself: one
capture for the LEVEL, one for the recovered CELL, and the only question is
whether a pixel lies inside the quad of the (level, cell) it claims.

- **The rendering quadrant.** `TileMapLayer` batches into quadrants of 16 cells
  and pushes each one's transform, so `VERTEX` is quadrant-local and the shader
  recovered `cell mod 16`. A scan reads `... (14,7) (-2,7) ...`.
- **The quadrant origin**, one more cell on top.

**So P2's soot had been reading the wrong cell since it shipped**, and every gate
that ran on a clean board was structurally incapable of failing (0 differing
pixels at boot; **38 743** on a real detonation; 0 for the control).

⚠️ The obvious gate shape — mark N cells, look for them — needs to know which
cell OWNS a pixel, which under isometric occlusion you do not. It reported
"offsets" of (31,−80) cells. That was occlusion.

**Still open (§3.3):** the floor is 81%, walls 96–100%. ±1 cell in all eight
directions, interior pixels 84.6%, TileSet uniform, texel-snap changed nothing.

## 3. P5a, and a 45% regression caught by measuring (`2e224825`)

`_burn_final_repaint()` passed `geometry_only=false`, emptying the caches so the
apply re-derived all 205 704 cells. A fire is exactly that path's precondition.

```
final repaint:  false 1630 ms  ->  true 866 ms   (-47%)
[LIGHT-EQUIV] 205 063 cells, 0 differ
```

⚠️ **The probe was blind until this commit** — `_perf_snapshot_alts()` still only
captured the alternative id, so all three probes built on it could not see soot.

**And the quadrant fix was redone.** One quadrant per layer costs **15 928 ms vs
10 986 ms** of burn wall clock, +45%, because every `set_cell()` then rebuilds the
whole layer. The replacement takes the coordinate from `MODEL_MATRIX` (which
carries the quadrant transform folded in) minus a new `layer_origin` uniform —
quadrant-independent, engine defaults kept, 0 differing pixels against the
one-quadrant build.

## 4. The fire's real cost (`dbb2a95e`)

```
baseline, no fire:     16.7 ms/frame ·  4 206 draw calls
during the fire:       64.5 ms/frame · 13 145 draw calls
after the fire ends:   16.7 ms/frame · 13 145 draw calls   <- SAME draw calls
```

| term | per frame |
|---|---|
| VFX overlay **drawing** | ~24 ms |
| those overlays' `_process` | ~0 ms |
| `_advance_burn`, ALL frames | 6.0 ms |
| rest of `Room._process` | ~0.1 ms |
| **unattributed** | **~23 ms** |

A 3.33 s fire spends 12 841 ms in frames, and **the destruction system is 1.2 s
of it**. The 185 frames that commit nothing cost more than the 14 that do.

⚠️ `Performance.TIME_PROCESS` reported 316 ms on a 64 ms frame — it is not
measuring the frame; caller-side timing replaced it.

---

## Next, in order

1. **§3.4's ~23 ms/frame** — the largest single number, and unattributed.
   Half the fire's excess is particle `_draw`; this is the other half.
2. **§3.3's floor residual** — the only thing blocking P3.
3. The rest of P5: the walk (458 ms), the soot snapshot (146 ms), occupancy (31 ms).

## Carried forward, unrelated

- **MATERIALS M3-6** — fire propagating laterally through internal slices.
- **M3-7** — the per-material passage table as a measured acceptance.
- **MAT-DECAL-01** — decal presence across all materials.
- The rifle's and pistol's posed frames; the ~500 ms aim warm.
