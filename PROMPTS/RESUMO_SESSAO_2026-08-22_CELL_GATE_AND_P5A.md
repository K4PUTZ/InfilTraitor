# RESUMO_SESSAO — 2026-08-22 · THE CELL GATE, AND WHERE THE FIRE'S TIME REALLY GOES

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-22_BURN_PERF_AND_CELL_PLANE.md`
**Commits:** `e25d25bc`, `6d88886c`, `a90f8f3c`, `2e224825`, `dbb2a95e`,
`3c6ece19`, `009e9625` — all pushed to `main`.
**Gates at close:** lint 216 ✅ · selftests **39 clean / 0 failed** ✅ ·
invariants ✅ · CODEMAP ✅.

---

## Read this first if you are resuming

The Director ratified a reordering: **gate → P5 → P3**. The gate is built and
found two shipped defects. P5a is done. **P3 is blocked** on the gate's residual
(§3.3 of the plan), and that is **where work resumes** — it needs no decision.

One thing IS waiting on the Director: §3.4d's VFX term (25 ms/frame), because
fixing it changes how fire LOOKS. See "Next" at the bottom.

⚠️ Before running any frame-time measurement, read §4's cap warning: the 16.7 ms
"baseline" this project has been quoting is the 60 Hz pace, not the work.

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

## 4. The fire's real cost, fully attributed (`dbb2a95e`, `009e9625`)

Each term is its own hiding experiment on a real fire (354 voxels, fabric at
gu 31,3), run with `--disable-vsync`:

| term | ms/frame | measured by |
|---|---|---|
| VFX overlays' `_draw` | **25.1** | hiding the five: 64.0 → 38.9 |
| the 32 voxel `TileMapLayer`s | **19.0** | hiding them: 64.0 → 45.0 |
| the 9 guards | **5.0** | hiding them: 64.0 → 59.0 |
| `_advance_burn`, ALL frames | **6.0** | timed from the caller |
| | **55.1** | vs a measured excess of 64.0 − 8.9 = **55.1** |

The terms are only additive if the costs are independent; **that they sum exactly
is the evidence that they are.** The voxel layers were the last group left
untested and they were the answer.

A 3.33 s fire spends 12 841 ms in frames, and **the destruction system is 1.2 s
of it**. The 185 frames that commit nothing cost more than the 14 that do.

### ⚠️ Every number under 16.7 ms in this repo was the 60 Hz pace

With the voxel layers, the VFX, the guards, the agent and the whole UI hidden —
**90 draw calls, 0.3 ms of renderer CPU** — the frame probe still read
**16.7 ms/frame**. The idle board is **8.9 ms** under `--disable-vsync`. The
fire's own figures sit far above the cap and were never affected, which is
exactly why this stayed invisible until something was measured BELOW it.

**Any frame-time work in this project runs with `--disable-vsync`.**

Two more traps, recorded so they are not re-run: `Performance.TIME_PROCESS`
reported 316 ms on a 64 ms frame; and a CanvasItem's `_draw()` is NOT counted in
the engine's `render cpu` (the VFX cost 25 ms/frame and moved it by nothing).

And one invalid measurement caught: an earlier run that hid everything but the
voxel layers and reported a 17 ms fire frame **had no fire in it** — hiding the
UI before the detonation broke the synthetic click path the capture drives. It is
only a measurement if the event actually happened.

### A detonation makes the board permanently more expensive

```
before any blast:        8.9 ms/frame ·  4 206 draw calls · render cpu 2.0 ms
after the blast + fire: 12.7 ms/frame · 13 145 draw calls · render cpu 4.3 ms
```

+43% per frame, forever, from one grenade — the damage variants split the
batches. Small beside the fire's 55 ms, and it compounds with every blast a
mission takes. Measured and left alone (§3.4c).

---

## Next, in order — the Director's ratified sequence

1. ⏸️ **AWAITING A RULING: the VFX overlays' `_draw`, 25 ms/frame.** The largest
   single term. Fixing it means fewer particles or batching `draw_*`, which is a
   LOOK decision, not a repair — so it needs Director sign-off before anyone
   touches it. The other two terms (voxel layers 19 ms, guards 5 ms) are pure
   optimisation and need no ruling.
2. **§3.3's floor residual** — the gate reads 81% on the floor against 96–100%
   on the walls, and it is the only thing blocking P3. **This is where work
   resumes**; it needs no decision from anyone.
3. The rest of P5: the walk (458 ms), the soot snapshot (146 ms), occupancy
   (31 ms).

## Carried forward, unrelated

- **MATERIALS M3-6** — fire propagating laterally through internal slices.
- **M3-7** — the per-material passage table as a measured acceptance.
- **MAT-DECAL-01** — decal presence across all materials.
- The rifle's and pistol's posed frames; the ~500 ms aim warm.
