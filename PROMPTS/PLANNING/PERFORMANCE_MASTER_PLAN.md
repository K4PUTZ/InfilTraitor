# PERFORMANCE_MASTER_PLAN
## Per-cell visual state leaves the TileSet — v1.0

**Status:** 🟠 **v1.6 — §8.11 IS ANSWERED AND THE ANSWER IS NO (§8.12): a
committing frame costs ~350 ms whether it mints 694 alternatives or 275.** The
fire's dominant term does not count mints, which is also why P2 cut them 93% for
nothing (§1.1b). ⚠️ The follow-up probe returned NULL and says so (§8.12b) — every
committing frame mints, so the control group is empty and "one rebuild per minting
frame" cannot be separated here; the pre-mint experiment is what settles it, and
P3 is the only change in this plan that produces a committing frame minting
nothing. §8.13 is a profiler reset defect that would have corrupted this run.
Earlier: **v1.5 — THE FIRE IS 69% TWELVE FRAMES (§8.10), and half of it
runs outside every function this project has instrumented.** P7a is done and
confirmed its mechanism (submission is 95.1% of `_draw`, §8.8) — but the same run
capped P7 at 3.8% of the fire's wall clock, and the frame-kind split says why: the
VFX lives in the cheap 31%. **P7b is ON HOLD behind §8.11's two-fires run**, which
is cheap, decisive, and may put P3 back on the table. Earlier: **v1.4 — THIS PLAN
RE-SCOPES ITSELF (§8). Its own thesis was
falsified by its own instruments:** the fire's cost is 80% draw submission, not
per-cell state, so **§3.3 and P3 FREEZE where they are** (documented, nothing
reverted) and **P7 — the VFX delivery channel — goes first**. §8.3 argues the
25 ms/frame parked *"awaiting a ruling"* is probably not a LOOK decision at all,
and §8.6's P7a is the measurement that confirms or kills that before anything is
rewritten. §8.5 is why this runs ahead of MATERIALS M3-6 rather than after it.
Earlier: **v1.3 — P5a IS BUILT (§3.4), and the fire's real cost turns out not to
be the destruction system at all.** Earlier: **v1.2 — TWO CORRECTIONS, BOTH MEASURED (2026-08-22).**
**(a) P3's premise was wrong by ~40x** — the map-wide apply is derivation plus a
walk, and the writes-and-mints half that P3 removes is 0.7–30 ms of ~1 200 on
every repaint after the boot (§1.5). P5 now runs BEFORE P3, Director-ratified.
**(b) The cell recovery was reading `cell mod 16`, minus one cell** — so P2's
soot has been landing on the wrong cell since it shipped, and its gates could not
see it (§3.2). Both defects are fixed; a residual on the floor is open and blocks
P3, not P5. §6 is the task order; §5 is what could still sink it.
**Written:** 2026-08-22, against `12225c84`, at the Director's instruction —
*"vamos testar primeiro, e se estiver tudo OK pode abrir esse masterplan de
performance"*.
**Opened because of** the Director's reading of the burn stall (2026-08-22):
*"estamos derivando a fuligem e não simplesmente aplicando… a prioridade sempre
vai ser a performance. Queremos voxels ágeis e inteligentes, uma arquitetura
sólida que permita implementar efeitos sem se preocupar com desempenho."*
**Companions:** `VOXEL_LIGHT_MASTER_PLAN` (owns what the light VALUES are),
`MATERIALS_MASTER_PLAN` (M3-6 is the next feature this unblocks),
`DESTRUCTION_MASTER_PLAN`, `docs/systems/LIGHT_MASTER_PLAN.md`.

---

## 0. The one sentence

**Every per-cell visual property in this engine is delivered by minting a
TileSet alternative and rewriting the cell.** Soot rides in the alpha of that
alternative's `modulate`; the light bucket rides in its RGB. That is the reason
a cosmetic effect can cost seconds, and it is the reason the NEXT effect will
cost the same.

This plan moves per-cell state out of the TileSet and into a **data texture the
voxel shader samples by cell**. Changing light or soot becomes writing pixels.

**Rule 8 is not touched.** Voxels still reach the tilemap only through
`set_cell()`; what changes is where their COLOUR comes from.

---

## 1. The measurements this plan is built on

All from 2026-08-22, real boots of the real map, fabric block at gu (31,5).

### 1.1 What the burn cost, and what fixed part of it

| | frames | inside `_advance_burn` | wall clock |
|---|---|---|---|
| before MAT-PERF-01/02 | 11 | 14 281 ms | **16 964 ms** |
| after MAT-PERF-02 | 7 | 697 ms | 2 734 ms + 1 401 ms final repaint ≈ **4 100 ms** |

For a fire whose own schedule spans **1.90 s**. MAT-PERF-02 removed the
map-wide repaint from the burn's frames; it did not remove the repaint.

### 1.1b ⚠️ What P2 measured, including the part that corrects §1.2 below

```
TileSet alternatives minted during one burn:   2 175  ->  150   (-93%)
cells the scoped frames left stale:            1 288  ->  135
picture, real detonation, harness earned:      0 differing pixels (blast AND shot)
```

**And the burn's wall clock did not move** — 2 734 ms before, 2 776 ms after. So
§1.2's reading of the ~2 000 ms outside `_advance_burn` as *"2 179 mints, and the
rebuild they trigger"* **is wrong**, and it was mine. Mints fell 93% and the time
stayed. Whatever that time is, it is not the TileSet rebuild; P4 owes the real
frame-time attribution and the honest statement today is that it is unexplained.
The two figures that DID move are the ones P3 inherits.

### 1.2 Where the remaining time is

```
[REPAINT-PROF] occupancy 29.9 · soot 150.9 · field.build 65.8 · apply 1112.1 ms
```

- **apply ~1 080 ms** — the walk over every placed cell on the board (205 760).
- **~2 000 ms outside the profiled function** across 7 frames — 2 179 TileSet
  alternatives minted, and the rebuild they trigger is charged once per FRAME
  THAT MINTS.
- **soot derivation 146 ms** — the map-wide walk over every Slice and Slab.

### 1.5 ⚠️ WHAT THE APPLY IS ACTUALLY MADE OF — and it inverts §4

`INFILTRAITOR_APPLY_SPLIT_PROBE=1` (`VoxelRenderer._apply_split_probe()`). Three
phases ordered so each can only measure itself: WARM forces the light field's
lazy per-cell derivation, APPLY runs against a warm cache, APPLY AGAIN is the
walk alone because every cell is already at its target.

Real PLAYGROUND boot, post-P2, 205 704 placed cells:

| repaint | derivation | walk | **writes + mints** |
|---|---|---|---|
| boot | 753.9 ms | 458.3 ms | **692.1 ms** (189 343 written, 49 947 minted) |
| CONTROL, nothing destroyed | 744.5 | 443.2 | **29.6 ms** (0 written, 0 minted) |
| ONE VOXEL destroyed | 754.9 | 467.2 | **1.5 ms** |
| WALLS, 2 111 voxels | 758.1 | 477.2 | **0.7 ms** |

**On every repaint after the boot — the ones a burn and a shot actually pay — the
half P3 removes is 0.7 to 30 ms out of ~1 200.** The rest is `bucket_for()`'s
first-touch derivation plus the walk over every placed cell, and P3 touches
neither.

**This inverts §4's reason for deferring P5.** That section defers the derivation
layer because "today it is masked by a delivery cost five times larger". The
delivery cost is not five times larger; it is ~40x SMALLER. The masked term was
the one being deferred.

What P3 is still worth, stated so the ledger is honest rather than to rescue it:
the boot's 692 ms and its 49 947 mints, the shot path's mints (the whole reason
W-PRECOOK exists), and the architecture — a future effect becomes a channel, not
a multiplier on the alternative space. None of that is a burn or a shot getting
faster today.

### 1.3 ⚠️ The soot hypothesis was tested and is WRONG, and that matters

The Director's read was that soot is the villain. Measured directly — how many
minted alternatives exist ONLY because the soot code rides in the alternative id:

```
53 623 alternatives minted map-wide
51 059 distinct by (tile, bucket, flip)
→ 1.1x — only 4.8% are soot-code duplicates
```

The multiplier that explodes the alternative space is **(source, atlas coords) ×
light bucket**, not the soot code. Soot rides along. Removing it alone would buy
~146 ms per repaint and ~5% of the mints — real, small, and not the problem.

**But the diagnosis was right one level up**, and that is what this plan is: the
DELIVERY CHANNEL is the defect, and light is the same channel with 12× the
weight.

### 1.4 The alternative space, as arithmetic

```
LIGHT_BUCKET_COUNT   12
FACE_SOOT_CODE_COUNT 125     (base-5, three faces: top*25 + se*5 + sw)
flip                   2
                    ----
per (source, atlas coords):  12 x 125 x 2 = 3 000 possible alternatives
```

Every one that is ever needed calls `create_alternative_tile()` and rebuilds the
TileSet. With per-cell state in a texture the same tile needs **2** (the flip,
which is geometry and cannot leave the alternative — see §5.2).

---

## 2. The mechanism

One texture per LEVEL, one texel per CELL, sampled by
`voxel_face_shading.gdshader`, which already runs on every voxel layer.

```
today          set_cell(cell, source, coords, alt_id)
               alt_id encodes (bucket, soot, flip)
               a new (bucket, soot) pair => create_alternative_tile() => TileSet rebuild
               changing anything => walk every placed cell and re-set it

proposed       set_cell(cell, source, coords, flip_alt)        <- geometry only, ~never changes
               data_tex[level].set_pixel(cell, bucket|soot|...) <- the visual state
               changing anything => write pixels in the affected rectangle
```

Consequences, in the order they matter:

1. **Minting stops being a function of visual state.** No TileSet rebuild for a
   light change, a soot change, or any future effect.
2. **The apply becomes O(cells that changed)** instead of O(every placed cell).
3. **A new effect is a new CHANNEL in the same texture**, not a new multiplier on
   the alternative space. This is the Director's *"implementar efeitos sem se
   preocupar com desempenho"*, stated as a property of the architecture rather
   than as an aspiration.

---

## 3. PERF-SPIKE-01 — the three gates, all passed

Run through `INFILTRAITOR_CAPTURE_ACTION=cell_index_spike`
(`INFILTRAITOR_SPIKE_MODE=1|2`), `Room._capture_cell_index_spike()`.

### Gate 1 — is cell → position invertible?

The shader today knows only ATLAS space (`UV / TEXTURE_PIXEL_SIZE`); it has no
idea which cell it is drawing. Recovering the cell requires inverting
`map_to_local()`, which only works if the mapping is affine — Godot staggers some
isometric layouts, and a stagger would sink the whole route.

```
level 0 · layer.position (112.0, 576.0) · origin (16.0, 8.0) · e1 (16.0, 8.0) · e2 (-16.0, 8.0)
  affine? worst error 0.000000 px over 100 cells (worst at (0, 0)) — AFFINE
  basis determinant 256.0000 — invertible
  inverse round-trip on real placed cells: 200 checked, 0 wrong
```

Identical on levels 0, 1 and −8, i.e. across the positive and the negative
(floor) layers. Tested out to cell (350, 350), where an accumulated half-offset
could not hide. **Only `layer.position` differs per level, and `VERTEX` is
layer-local, so it cancels** — each level is its own 2D problem, which is what
removes the third dimension for free.

### Gate 2 — can the SHADER recover it per fragment?

The route: the fragment's offset inside its own quad is exactly the atom-local
pixel the shader already computes, so `VERTEX - local` is the quad's TOP-LEFT and
is **constant across the quad** — which is what makes the answer per-TILE rather
than per-pixel. The three faces of one voxel must resolve to ONE cell, and this
is why they do.

Evidence: [`Screenshots/history/spike_cell_index_parity_zoom.png`](../../Screenshots/history/spike_cell_index_parity_zoom.png)
— the recovered cell's parity painted red/blue. Every diamond is one cell, solid
colour, alternating on the isometric lattice, seams exactly on voxel edges. A
wrong recovery reads as noise or as bands that ignore the geometry; this reads as
neither.

### Gate 3 — does the per-cell fetch work, and what does writing cost?

[`Screenshots/history/spike_cell_index_datatex_zoom.png`](../../Screenshots/history/spike_cell_index_datatex_zoom.png)
— a 512×512 nearest-filtered checkerboard sampled by cell and applied as a
multiply over the real art. Per-voxel brightness modulation with **zero TileSet
alternatives involved**.

```
32 level(s) of 384x208 RGBA8 = 9.8 MB · built in 1.5 ms
ONE level, every cell rewritten (79 872 set_pixel): 2.2 ms
a 64x64 cell patch:                                 0.1 ms
ALL 32 levels re-uploaded:                          1.1 ms
```

Against **~1 080 ms** for the map-wide apply it would replace.

⚠️ **The honest limit of that last block:** these are CPU-side timers.
`ImageTexture.update()` returns before the GPU upload lands, so "0.0 ms to
upload" means *not charged here*, not *free*. The real figure is a FRAME TIME in
a built system, and P4 owes it.

### 3.1 ⚠️ P3 was attempted on 2026-08-22 and REVERTED — what the attempt measured

The change itself was small and went in cleanly: the plane grew a second channel
(R = soot, G = bucket), the ladder went to the shader as `uniform float
bucket_lum[12]`, and the alternative id was left carrying nothing but the flip
(`alt_for_flip()`), which makes minting **zero** because `_ensure_light_alt()`
already returns early on 0 and TRANSFORM_FLIP_H.

**The picture came out visibly wrong** — the board crushed to near-black with the
lit cones still correct — so it was reverted whole. P2 is unaffected and stands.

RULED OUT BY MEASUREMENT, not by reading:

- **the uniform**: `bucket_lum` reads back as the exact 12-value ladder;
- **the data**: the plane was compared against the light field on 300 real placed
  cells across three levels — **0 wrong**.

WHAT THE `lum`-ONLY DEBUG RENDER ACTUALLY SHOWS: large flat regions of the
correct value, plus **white sawteeth along atom edges**. White is 1.0, which in
that build is either bucket 11 (the fill value — a cell never written) or the
`in_plane ? … : 1.0` fallback. So the leading suspect is those fragments taking
the out-of-plane branch or reading an unwritten texel — **not** the cell
recovery.

⚠️ **AND A CORRECTION TO THE FIRST READING OF THAT EVIDENCE.** `fract(cellf)`
measured 0.03–0.28 instead of 0, which looked like the recovery being broken and
was the reason for reverting. It is not sufficient evidence: every one of those
values is **below 0.5**, so `floor(cellf + 0.5)` rounds to the same integer
regardless. P2's own detonation gate is positive evidence the other way — max
delta 4 means **no cell resolved to the wrong soot ring anywhere**, which a
broken recovery could not produce. The offset is real and worth eliminating, but
it is not what broke P3.

**What gate 2 could NOT have caught, and this is the lesson for the next
attempt.** A parity checkerboard is invariant under a CONSTANT cell offset: shift
every cell by one and the picture is an equally perfect checkerboard. Gate 2
proved "one cell per quad, consistent across the lattice" — it never proved "the
RIGHT cell". The next attempt needs a gate that can only pass for the correct
mapping: paint `cell.x mod 3` and `cell.y mod 3` into separate channels and check
a KNOWN cell's screen position against a value computed in GDScript.

---

### 3.2 ✅ THE GATE EXISTS, AND IT FOUND TWO REAL DEFECTS (2026-08-22)

`INFILTRAITOR_CAPTURE_ACTION=cell_index_gate` (`Room._capture_cell_index_gate()`).

**The shape, and why this one cannot pass for the wrong mapping.** Every pixel
names itself. Capture A fills each level's plane with `level + 100` and paints
what the shader read, so a pixel names the LEVEL that drew it — robust even to a
totally broken cell recovery, because the whole level carries one value. Capture
B paints the recovered CELL exactly. The only question asked is whether a pixel
lies inside the quad of the (level, cell) IT CLAIMS, with that rect built from
`map_to_local()`, `texture_region_size` and the TileData's own `texture_origin` —
Godot's numbers, never the shader's `quad_to_map` literal.

⚠️ **The obvious shape was built first and thrown away.** Marking N known cells
with unique codes needs to know which cell OWNS a pixel, and in an isometric
scene that is exactly what you do not know — a wall to the south covers the floor
to the north. It reported recovery "offsets" of (31, -80) and (46, -81) cells
with a broad spread; those numbers were occlusion. Two further hours went to
things that were not the mapping either: an ADDITIVE floor overlay corrupting the
readback (325 059 px came back as (3, 9, 255) instead of (code, 0, 255)), and an
analysis that required `g == 0` on a capture whose green channel carries data.

**DEFECT 1 — the rendering quadrant.** `TileMapLayer` batches tiles into
quadrants of `rendering_quadrant_size` cells (default **16**) and pushes each
quadrant's own transform, which makes `VERTEX` QUADRANT-local. The shader inverts
`map_to_local()` on `VERTEX - local`, so it recovered `cell mod 16`. Measured by
painting the recovered cell: a horizontal scan reads `... (13,8) (14,7) (-2,7)
(-1,6) ...`, a clean wrap of exactly 16. **This is why PERF-SPIKE-01's parity
checkerboard passed** — a per-quadrant offset is exactly what parity is invariant
under. Fixed: one quadrant per layer, sized from `SOOT_TEX_SIZE`.

**DEFECT 2 — the quadrant origin.** With one quadrant its position is
`map_to_local(cell 0,0)` = (16, 8), not zero, so `VERTEX` is still short by one
cell step. `quad_to_map` (0, 20) → **(16, 28)**.

```
recovery correct:  ~0%  ->  42% (quadrant)  ->  82% (origin)
per level:  walls L0..L15  96-100%   ·   floor L-1  81%
```

**AND THIS CORRECTS PERF-P2-FIX.** That commit read "12% of fragments fall
outside the plane" as the map buffer putting geometry at negative cells.
PLAYGROUND has no negative cells; the negatives were the quadrant-local recovery
going negative near every quadrant boundary. `SOOT_PLANE_ORIGIN` did not fix
that — it moved those fragments off the clean fallback and onto a WRONG TEXEL
inside the plane, which is worse, because it looks like an answer.

**So P2's soot was reading the wrong cell, and here is why its gates were blind:**

```
boot, no soot anywhere:        0 differing pixels
real detonation, soot present: 38 743 px differ, max channel delta 81
control, same code twice:      0 differing pixels  (the diff is earned)
```

With the plane uniformly clean, reading the wrong cell returns the right answer.
Every P2 gate that ran on a clean board was structurally incapable of failing.
Evidence: `Screenshots/history/p3_quadrant_soot_{before,after}.png`.

### 3.3 ⚠️ STILL OPEN — the floor's last 18%, and it blocks P3

The walls are 96–100%; the floor is 81% and it is 92% of the pixels on screen.
Characterised, not guessed:

- the misses are **±1 cell in all eight directions, roughly evenly** — a boundary
  effect, NOT a constant shift (a shift would be one bucket);
- 65% land 2–8 world px outside their claimed quad, none past 16;
- `Screenshots/history/p3_gate_mask.png` shows them as regular wedges at the
  left and right VERTICES of the floor diamonds, plus hairlines;
- **interior pixels** (all four neighbours claiming the same cell) are 84.6%,
  so it is not only seams — there are solid interior patches;
- ruled out by measurement: the TileSet is uniform (all 55 sources region
  (32, 36), all 32 907 tiles `texture_origin` (0, 10)); snapping `local` to the
  texel grid changed nothing (81.985% vs 82.007%) and was reverted;
- ruled out earlier: H-flip inverting `UV.x` — real mechanically, but PLAYGROUND
  mints **0** flipped alternatives, so no cell on this map is flipped.

Containment ought to hold for every drawn fragment by construction, so a
violation means the computed rect is not Godot's draw rect for that tile. The
next lead is the per-cell alternative: `debug_cell_quad_rect()` reads TileData
for the cell's ACTUAL alternative, and a `get_tile_data()` that returns null for
a transform-only id would silently give `texture_origin` (0, 0) — a 10 px error,
inside the observed spread.

**P5 does not depend on any of this.** The residual blocks P3 only.

## 3.4 ✅ P5a DONE, and ⚠️ the fire's real cost is somewhere nobody has looked

**P5a — the burn's final repaint went incremental** (2026-08-22). `build()`'s
`geometry_only` path has existed since PERF-03 and `_burn_final_repaint()` was
passing `false`, emptying both caches so the apply re-derived all 205 704 cells.
A fire changes occupancy and soot and touches no light, no shadow, no cover —
which is exactly that path's documented precondition.

```
final repaint, same fire (354 voxels, fabric at gu 31,3):
  geometry_only = false   1630 ms   (apply 1240.7)
  geometry_only = true     866 ms   (apply  509.7)     -47%
correctness: [LIGHT-EQUIV] 205 063 cells, 0 differ
```

⚠️ **And the probe that says so was blind until the same commit.**
`_perf_snapshot_alts()` captured the alternative id, which WAS a cell's whole
visual state until P2 moved soot into the plane and did not tell it. The shot's
scope gate, the light equivalence probe and the burn's "corrected N cells" all
sat on it. It snapshots the pair now.

### THE FIRE'S WALL CLOCK, ATTRIBUTED — and this is a NEW problem, not P3's

`INFILTRAITOR_FRAME_PROBE=1` (a standing probe, prints once a second) plus the
burn profiler's new frame-time block. Real fire, 354 voxels:

```
baseline, no fire:      16.7 ms/frame ·  4 206 draw calls
during the fire:        64.5 ms/frame · 13 145 draw calls
after the fire ends:    16.7 ms/frame · 13 145 draw calls   <- SAME draw calls
```

**The draw-call count is not the cost.** It triples across a detonation and
never comes back down, and the frame is 16.7 ms on both sides of the fire.

Where the fire's ~48 ms/frame goes, measured by removal rather than by reading:

| term | per frame | how it was measured |
|---|---|---|
| VFX overlay **drawing** | ~24 ms | hiding ember/smoke/debris/flash/shrapnel: 64.5 → 40.2 ms |
| those overlays' `_process` | ~0 ms | `set_process(false)` on top of hiding changed nothing |
| `_advance_burn`, ALL frames | 6.0 ms | timed from the caller; its own counter only ever accumulated on the 14 frames that COMMIT |
| the rest of `Room._process` | ~0.1 ms | temporal lights, vision fog, enemy visibility, each timed |
| **the VOXEL LAYERS** | **19.0 ms** | hiding the 32 `TileMapLayer`s: 64.0 → 45.0 ms |
| the guards | 5.0 ms | hiding the 9 of them: 64.0 → 59.0 ms |

So a 3.33 s fire costs 11 s of wall clock, and **the destruction system is not
what makes it expensive** — 1.2 s of 12.8 s is `_advance_burn`, and the 185
frames that commit nothing cost more than the 14 that do.

**THE ATTRIBUTION CLOSES.** 25.1 + 19.0 + 5.0 + 6.0 = **55.1 ms**, against a
measured excess of 64.0 − 8.9 = **55.1 ms**. (Each term is a hiding experiment
run on its own, so they are only additive to the extent the costs are
independent; that they sum exactly is evidence they are.)

### ⚠️ 3.4b — EVERY NUMBER UNDER 16.7 ms IN THIS PLAN WAS THE 60 Hz PACE

Found while chasing the term above, and it invalidates the way half of these
figures were read. With the voxel layers, the VFX, the guards, the agent and the
entire UI hidden — **90 draw calls, 0.3 ms of renderer CPU** — the frame probe
still reported **16.7 ms/frame**. The idle board is not 16.7 ms; it is **8.9 ms**
under `--disable-vsync`. The cap never touched the fire's own numbers (they are
far above it), but it means "baseline 16.7 ms" was a floor wearing a measurement.

**Any frame-time work in this project runs with `--disable-vsync`.**

And a second correction from the same chase: an earlier run that hid everything
but the voxel layers and reported a 17 ms fire frame **had no fire in it** —
hiding the UI before the detonation broke the synthetic click path the capture
drives. It is only a measurement if the event actually happened.

### 3.4c — a detonation makes the board permanently more expensive

```
before any blast:        8.9 ms/frame ·  4 206 draw calls · render cpu 2.0 ms
after the blast + fire: 12.7 ms/frame · 13 145 draw calls · render cpu 4.3 ms
```

+43% per frame, forever, from one grenade — the damage variants split the
batches. Small beside the fire's 55 ms, and it never comes back down, so it
compounds with every blast a mission takes. Recorded here rather than fixed.

### 3.4d — where a fix would go, ranked by what was measured

1. **The VFX overlays' `_draw` — 25 ms/frame, 45% of it.** Per-particle GDScript
   `draw_*` calls. Their `_process` costs nothing, so it is purely submission.
2. **The voxel layers — 19 ms/frame.** 13 145 draw calls after a blast.
3. **The guards — 5 ms/frame** across nine of them.

None of this is P3's, and none of it is the derivation. It is a THIRD cost
centre this plan did not know it had.

## 4. What this does NOT solve, stated up front

**The derivation stays.** `_build_soot_snapshot()` still walks every Slice and
Slab (146 ms), `build_occupancy()` still runs (30 ms), `field.build()` still
recomputes buckets (33 ms). Those decide WHAT the values are; this plan only
changes how they REACH a pixel. ~210 ms of map-wide walking survives untouched,
and it is P5 — deliberately last, because today it is masked by a delivery cost
five times larger, and optimising the masked term first is how a project ends up
with two half-measurements and no win.

**It does not make fire cheaper by itself.** MAT-M3-6 (lateral propagation) will
multiply the number of burning voxels. This plan makes that multiplication cheap;
it does not pre-pay for it.

---

## 5. Risks, and the two that are real

### 5.1 Every consumer of the alternative id has to move

`decode_light_bucket()` / `decode_face_soot_code()` are read by the occlusion
ghost store (which remembers `prev_alt` to restore a cell exactly), W-PRECOOK,
`_perf_snapshot_alts()`, the burn and shot scope gates, and several selftests.
The alternative id is currently the project's *record* of a cell's visual state,
not only its delivery. **Something has to keep being that record** — the data
texture itself is the obvious answer, but every reader must be moved
deliberately, and the ghost store is the one with real teeth.

### 5.2 The flip bit cannot leave the alternative

`decode_light_flipped()` drives `TileData.flip_h`, which is GEOMETRY, not colour.
It has to stay in the alternative id. So alternatives do not disappear — they go
from up to 3 000 per tile to **2**, and they stop changing when the light does.

### 5.3 The shader change is nearly free — measured twice, and the first number misled

The spike's shader, with the spike DISABLED, moved **14 pixels of 921 600 (max
channel delta 5)**. That number was attributed to the added `vertex()` stage and
it was wrong. Isolated afterwards — vertex stage and varying ONLY, no cell
maths, no branch:

```
VERTEX STAGE ALONE: 1 differing pixel, max delta 1
```

So the cost of giving this shader a vertex stage is nil, and the 14 pixels came
from the spike's own fragment code. The residue-class face separation (mod 3,
FACE-READ-03) is still what turns a sub-LSB precision shift into a visible
integer, so any change here gets a `--fixed-fps 60` A/B and a stated number,
never a "should be identical".

`godot/shaders/experimental/voxel_face_shading_cellindex.gdshader` holds the
proven code and is swapped in at runtime by the probe; main's shader is
untouched until P2 lands the consumer.

### 5.4 RAM

9.8 MB at 44×22 with 32 levels, and it scales with board area × level count. D42
names RAM as this project's real constraint, so a bigger board is a number to
re-measure, not to assume.

### 5.5 A capture harness fact this spike had to establish

A plain boot capture of PLAYGROUND is **NOT deterministic**: two boots of
identical code differ by **34 252 pixels**. With `--fixed-fps 60` the same pair
differs by **0**. Any pixel-diff gate in this plan must use it.

⚠️ **And the obvious culprit is not the culprit.** The map carries `"flicker":
true` on the lamp at (5,3), which made the flickering lamp the natural
explanation — it is wrong twice over. Measured: **0 of 12 active lights have
`flicker_enabled`**, because `LightingController._setup_lights_from_layout()`
deliberately does not honour the map's `flicker` key (*"Flicker disabled while
the destruction visual system is rebuilt — brightness variation was contaminating
diagnostic captures"*). The differing pixels, masked and looked at, fall
**exactly on the guards' vision cones** and their stippled fill. MAT-MAP-01 went
from 4 guards to 9, so this session enlarged the non-deterministic area itself.

Two consequences worth carrying: removing the lamp from the map would change
nothing, and **the VL-03 incremental temporal repaint in
`Room._update_temporal_lights()` is currently unreachable** — `changed_lights` is
always empty, so the whole "repaint only the changed light's influence set" path
has never run on a real map. It is correct code waiting for a caller, and it is
exactly the shape P3 will have to trust.

---

## 6. Task order

| # | Task | Depends on | Size |
|---|---|---|---|
| ~~**P1**~~ | ~~Land cell recovery on its own~~ — **FOLDED INTO P2, 2026-08-22.** Landing the recovery with no consumer is dead code by construction, and this project has already paid for built-but-never-triggered features twice (the noise indicator, the exposure labels; and the VL-03 incremental temporal repaint below). §5.3's measurement removed the only reason to stage it separately: the vertex stage costs 1 pixel, not 14 | — | — |
| ✅ **P2** | **DONE 2026-08-22** (`fdbd3258` + `2268d3ac`), staged as P2a reader / P2b writer so a broken pixel would name its own half. **Soot** moves to the data texture — cell recovery, the data texture and its first consumer, together. Smallest real passenger, and it validates the whole pipeline end to end because soot is ALREADY a shader effect (it rides in `modulate.a` and `voxel_face_shading.gdshader` decodes it). The alternative id stops carrying soot. Gate: a fired shot and a burn look identical at `--fixed-fps 60`, and the burn's mint count drops | spike ✅ | Medium |
| ✅ **P-GATE** | **DONE 2026-08-22** — the gate §3.1 asked for, plus the two defects it found (§3.2). Its own residual (§3.3) is open and blocks P3 | P2 | Medium |
| ⏸️ **P7** | **P7a DONE and P7b ON HOLD 2026-08-23 — §8.10.** 69% of the fire is 12 committing frames at 359 ms each, and the VFX lives in the cheap 31%; P7b's ceiling is 3.8% of wall clock (§8.8b). **§8.11's two-fires run comes first.** Earlier: ⬆️ **NEXT, added 2026-08-23 — §8. The VFX delivery channel.** 80% of the fire's per-frame excess is draw submission (25.1 ms VFX + 19.0 ms voxel layers of 55.1). One ember per affected voxel, 2 `draw_circle` each, and M3-6 multiplies that count — §8.5. **P7a MEASURES before anything is rewritten** and may return NO (§8.3) | — | Medium |
| 🟡 **P5** | ⬆️ **MOVED AHEAD OF P3, Director-ratified 2026-08-22, on §1.5's measurement. P5a IS DONE (§3.4): the burn's final repaint 1630 → 866 ms at 0 cells differing.** Open: the walk (458 ms), the soot snapshot (146 ms), occupancy (31 ms), and §3.4's cost centre: the VFX overlays' `_draw` (25 ms/frame) and the voxel layers (19 ms/frame), now fully attributed. The DERIVATION layer: `bucket_for()`'s first-touch derivation (754 ms) and the walk over every placed cell (458 ms). This is where the map-wide repaint's ~1 200 ms actually is. `VoxelLightField._stale_cells()` already has the incremental shape and, per §5.5, has never run on a real map | — | Large |
| ❄️ **P3** | **FROZEN 2026-08-23 (§8.2b)** — measured at ~0 for a burn or a shot today, so the §3.3 residual that blocks it is not worth unblocking yet. Earlier: ⚠️ **ATTEMPTED AND REVERTED 2026-08-22 — see §3.1**, and BLOCKED on §3.3. **The light bucket** moves. Worth the boot's 692 ms and 49 947 mints and the architecture, NOT a faster burn today (§1.5) | P5, §3.3 | Large |
| **P4** | Retire the alternative-id encoding and the mint cache; re-measure the burn AND the shot, and get §3's real GPU frame time | P3 | Medium |
| **P6** | MAT-PERF-03's 198 stale floor cells — carried here from MAT-PERF-02 because P3 may delete the mechanism that causes them | P3 | Unknown |

### Explicitly OUT

- Actor and prop rendering. Different pipeline, different constraint (D42 RAM,
  not per-cell state).
- The light MODEL. What a bucket should be is `VOXEL_LIGHT_MASTER_PLAN`'s; this
  plan only changes how it is delivered.
- Any new effect. The point of the architecture is that adding one later is
  cheap; adding one now would be scope masquerading as validation.

---

## 7. Where the fire milestone stands meanwhile

MAT-PERF-02 already took the burn from 16 964 ms to ~4 100 ms, so nothing here is
an emergency. **MATERIALS_MASTER_PLAN M3-6** (fire propagating through the wall's
internal slices, laterally, and chaining from consumed voxels — Director,
2026-08-22) is the next FEATURE and is not blocked by this plan; it will simply
be more comfortable to judge after P3.

---

## 8. P7 — THE VFX DELIVERY CHANNEL, and why this plan re-scopes itself

**Added 2026-08-23, v1.4.** The Director's reading, opening the session:
*"empacamos na questão do fogo e entramos numa espiral de performance que
parece estar cada vez abrindo mais buracos novos"* — then, on the diagnosis
below: *"pode seguir na ordem que achar mais adequada, mas deixe o plano
registrado."* This section is that registration.

### 8.1 The ledger this plan has been keeping against itself

Nothing here is new measurement. It is the existing measurements read together,
which had not been done:

| § | what it measured | what it cost this plan's premise |
|---|---|---|
| 1.3 | soot is 4.8% of the alternative space | the first suspect, cleared |
| 1.1b | P2 cut mints 93%; wall clock 2 734 → 2 776 ms | mints are not time |
| 1.5 | the half P3 removes is 0.7–30 ms of ~1 200 | P3's premise, off by ~40x |
| 3.4 | the fire is 45% VFX `_draw`, 34% voxel layers, 9% guards, **11% `_advance_burn`** | the cost is not per-cell state at all |
| 3.4b | the "16.7 ms baseline" was the 60 Hz pace | every sub-cap reading here |

**The plan's own thesis — per-cell visual state in TileSet alternatives is the
cost centre — has been falsified by the plan's own instruments.** P3 and P4 are
its two "Large" items and §1.5 measured them at ~0 for the burn and the shot
today. What survives of them is the boot (692 ms, 49 947 mints) and the
architecture, and both are real; neither is urgent.

Meanwhile **44 of the fire's 55 ms/frame excess — 80% — is draw submission**:
the VFX overlays (25.1 ms) plus the 32 voxel `TileMapLayer`s (19.0 ms). §3.4d
already ranked them and called them *"a THIRD cost centre this plan did not know
it had"*. The correct response to that sentence was to re-scope, not to continue
down §6.

### 8.2 The two decisions this section makes

**(a) §3.3 and P3 FREEZE where they are.** The floor residual (81% against
96–100% on the walls) is characterised, documented, and blocks P3 only. P3 was
measured at ~0 value for a burn or a shot today. Chasing the floor's last 18% is
paying full price to unblock the thing whose value the measurement withdrew.
Nothing is reverted and nothing is deleted — §3.3 stays exactly as written, as
the entry point for whenever the boot's 692 ms becomes the thing that matters.

**(b) P7 goes first**, ahead of the rest of P5.

### 8.3 ⚠️ The ruling §3.4d asked for may not be a ruling at all

§3.4d item 1 is parked *"AWAITING A RULING"* because fixing 25 ms/frame of
`draw_*` was taken to mean fewer particles — a LOOK decision. Read against the
real code, that framing is probably wrong, and if it is, the largest single term
in the fire needs no decision from the Director at all.

What the five overlays actually do, per frame, per particle, in GDScript:

| overlay | per frame | source |
|---|---|---|
| ember | **2 `draw_circle`** per ember (core + halo) | [`ember_overlay.gd:317`](../../godot/scripts/overlays/ember_overlay.gd) |
| debris | **7–12 `draw_circle`** per dust cloud, + one `draw_colored_polygon` per chip | [`debris_overlay.gd:175`](../../godot/scripts/overlays/debris_overlay.gd) |
| smoke/spark | 1 `draw_circle` per blob; per spark, a `draw_line` **per trail segment** | [`smoke_spark_overlay.gd:209`](../../godot/scripts/overlays/smoke_spark_overlay.gd) |
| shrapnel | 1 `draw_circle` per fragment | [`shrapnel_overlay.gd:111`](../../godot/scripts/overlays/shrapnel_overlay.gd) |
| flash | 2 `draw_rect`, whole-screen | [`explosion_flash_overlay.gd:192`](../../godot/scripts/overlays/explosion_flash_overlay.gd) |

And the population is not a tuning constant — it is the destruction plan.
[`detonation_choreographer.gd:701`](../../godot/scripts/systems/destruction/detonation_choreographer.gd)
spawns **one ember per affected voxel** (`return 1` per entry). 354 burning
voxels is 354 embers is 708 `draw_circle` per frame, each of which builds a
polygon of tens of vertices as its own canvas command.

**This is the same shape of defect this plan already diagnosed once.** §0's
sentence is *"the reason a cosmetic effect can cost seconds"* is the DELIVERY
CHANNEL, not the effect. Here the channel is `CanvasItem.draw_*`, one command per
particle per frame, and the effect riding it is innocent.

**The hypothesis, stated as a hypothesis:** a `MultiMeshInstance2D` per overlay,
carrying per-instance transform (position, and scale as the radius) and
per-instance colour, draws the SAME particles, at the SAME count, with the SAME
look, in ~1 draw call — and the per-frame GDScript becomes one loop filling a
`PackedFloat32Array` assigned to `multimesh.buffer` in a single call, instead of
N method calls into the canvas. If that holds, item 1 of §3.4d stops being a
look decision and becomes pure optimisation, exactly like items 2 and 3.

⚠️ **It is unproven, and this project does not build on plausible.** P7a below is
the measurement that confirms or kills it, and it runs before anything is
rewritten. The honest failure mode: the per-frame buffer fill is still N
iterations of GDScript, so if the cost turns out to be in the loop rather than in
the canvas commands, MultiMesh buys much less than this section assumes. That is
what P7a is for.

### 8.4 A second finding, from the same read — the spawn is O(N²)

`EmberOverlay.add_ember()` calls `_height_bias(world_pos.y)`
([`ember_overlay.gd:198`](../../godot/scripts/overlays/ember_overlay.gd)), which
walks **every ember already alive** to normalise the new one's height against
them. Spawning N embers is therefore N(N−1)/2 dictionary reads — ~62 000 for
today's 354-voxel fire.

This is NOT the 25 ms/frame (it is a one-off at the spawn frame, and §3.4's
hiding experiments would not have caught it). It is registered here because it
is quadratic in exactly the quantity M3-6 multiplies, and because the fix is
cheap: the bias needs the min/max of the live set, which is a running pair, not a
walk. Unmeasured so far — P7a picks it up.

### 8.5 Why this ordering, and not "finish the fire first"

**MATERIALS M3-6 — fire propagating laterally through internal slices — is the
next feature, and it multiplies the number of burning voxels.** §8.3 establishes
that embers are one-per-voxel and §8.4 that the spawn is quadratic in that count.
So M3-6 scales the fire's single largest per-frame term linearly and its spawn
cost quadratically.

Building M3-6 first means judging the propagation's LOOK through a frame time
that its own voxel count made worse. That is the same trap §4 named — *"optimising
the masked term first is how a project ends up with two half-measurements and no
win"* — pointed the other way.

### 8.6 P7 task order

| # | Task | Gate | Size |
|---|---|---|---|
| ✅ **P7a** | **DONE 2026-08-23 — §8.8. Submission is 95.1% of `_draw`, the loop 4.9%; §8.3 CONFIRMED and item 1 of §3.4d needs no ruling. ⚠️ And §8.8b: the same run bounds P7 at −3.8% of the fire's WALL CLOCK against −42.8% of its FRAME TIME.** Earlier: **MEASURE, before any rewrite.** Under `--disable-vsync`, on the same real fire §3.4 used (354 voxels, fabric at gu 31,3): split the 25.1 ms between canvas-command submission and the GDScript loop itself, by timing `_draw` from the inside and by a no-op `_draw` variant that keeps the loop and drops the `draw_*`. Also time `add_ember`'s spawn frame against §8.4 | a stated ms split, and a verdict on §8.3's hypothesis that can be NO | Small |
| **P7b** | The `MultiMesh` conversion, **ember first** — the largest population, the simplest particle (two circles), and the one M3-6 multiplies | 0 differing pixels at `--fixed-fps 60` against a same-binary control (§5.5), and a stated ms/frame delta | Medium |
| **P7c** | debris, smoke/spark, shrapnel — only if P7b's measured delta earns them, one at a time, each with its own pixel gate | as P7b | Medium |
| ❌ **P7d** | **DROPPED 2026-08-23 — §8.9.** Measured at 11 ms across the whole fire. Real, quadratic, and 0.2% | — | — |

⚠️ **`explosion_flash_overlay` is explicitly OUT of P7.** Two whole-screen
`draw_rect`s are two commands, not two-per-particle; it is on §3.4's list only
because it was hidden alongside the other four in one experiment.

### 8.7 What P7 does NOT touch

- **The voxel layers' 19.0 ms** (§3.4d item 2). Real, second-largest, and
  architectural — 32 `TileMapLayer` nodes, each its own `CanvasItem` doing its
  own culling every frame. It gets its own item after P7, measured, not now.
- **The guards' 5.0 ms** (§3.4d item 3).
- **§3.4c's permanent +43%.** Still recorded, still not fixed.
- **The derivation** — the rest of P5, unchanged and still open: the walk
  (458 ms), the soot snapshot (146 ms), occupancy (31 ms).

### 8.8 ✅ P7a MEASURED (2026-08-23) — §8.3 is CONFIRMED, and the NOOP run is also an UPPER BOUND that changes what P7 is worth

Two runs, same binary, same fire, `--disable-vsync`, `INFILTRAITOR_VFX_DRAW_PROBE=1`,
the second adding `INFILTRAITOR_VFX_DRAW_NOOP=1`:

```
INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate \
INFILTRAITOR_GRENADE_GUS="31,3" INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400 \
INFILTRAITOR_BURN_PROFILE=1 INFILTRAITOR_VFX_DRAW_PROBE=1 \
godot --path . --disable-vsync
```

Both runs report the SAME fire — `354 of 354 scheduled voxel(s) consumed`, 14
committing frames, 394/397 alternatives minted — so the two are comparable.

```
FULL (loop + submission)   17.15 ms/frame in _draw()   1 726.0 command(s)/frame
NOOP (loop alone)           0.92 ms/frame in _draw()   1 909.4 command(s)/frame
```

The two windows caught different frame counts (41 vs 69), so the honest
denominator is the COMMAND, not the frame:

| | µs per canvas command |
|---|---|
| FULL | 9.94 |
| NOOP | 0.48 |
| **submission** | **9.45** |

Normalised back to FULL's 1 726 commands/frame:

| term | ms/frame | share |
|---|---|---|
| the per-particle GDScript loop | **0.83** | 4.9% |
| **`draw_*` submission** | **16.32** | **95.1%** |
| total `_draw()` | 17.15 | |

**§8.3's hypothesis is CONFIRMED, and it is not close.** The cost is the delivery
channel, exactly as §0 says of the TileSet. A `MultiMesh` removes the 16.32 and
keeps the 0.83. **Item 1 of §3.4d is therefore NOT a LOOK decision** — the
particles, their count and their appearance are all innocent, and the Director's
ruling is not needed to fix it.

### ⚠️ 8.8b — and the same run bounds what fixing it can BUY

The NOOP run is not only the control. It is **P7's ceiling**: every VFX draw
call removed, which is strictly more than MultiMesh can save.

```
                frames   mean frame    fire wall clock
FULL               41      154.6 ms         6 337 ms
NOOP               69       88.4 ms         6 098 ms
                          -42.8%             -3.8%
```

**The fire did not get shorter. It got more frames.** `BURN_COMMIT_INTERVAL_S`
pins the fire's cadence in SECONDS (deliberately — see `_advance_burn`'s comment,
and MAT-PERF-02's reasoning that *"cheaper frames buy more of them"*), so making a
frame cheaper buys frame rate and not duration. Removing **all** VFX drawing moved
a 6.3-second fire by **239 ms**.

So the two readings of *"empacamos no fogo"* want different work:

- **"the fire is a slideshow"** — 6.5 fps → 11.3 fps, a **43% cut in frame time**.
  P7 is the right fix and it is large.
- **"the fire takes 6.3 s for a 3.3 s effect"** — P7 is worth **3.8%**. The wall
  clock is somewhere else, and the biggest single pieces this run names are the
  14 committing frames (1 286 ms inside `_advance_burn`, 1 265 of it the scoped
  repaint) and the final repaint (898 ms), which together are ~2.2 s of 6.3 s.

⚠️ **The remaining ~4 s is NOT attributed and this section does not guess at it.**
§3.4's voxel layers (19 ms) and guards (5 ms) account for roughly 1 s across 41
frames. What is left is unexplained, and writing down a plausible candidate here
(the 394 mints' TileSet rebuild is the obvious one) is exactly the move §1.2 made
and §1.1b had to retract.

**One cross-check that did hold.** §3.4 measured the VFX at 25.1 ms of a 64.0 ms
frame by HIDING them — 39%. This run's NOOP removes 66.2 ms of a 154.6 ms frame —
43%. The absolute scales differ (this run's camera frames gu (10,4) while the fire
is at (31,3); `test_zone_detonate` overrides the focus env var), so only the
PROPORTIONS are comparable — and they agree. Note also that 66.2 ms ≫ the 16.32 ms
of submission: the difference is GPU rasterization of ~1 726 circles per frame,
which `_draw()`'s own clock cannot see and MultiMesh also removes.

### 8.9 ❌ P7d IS DROPPED — §8.4's O(N²) is real and does not matter

Measured on the same runs, identically in both:

```
add_ember: 354 call(s), 11.19 ms total (31.6 us/call)
```

**11 ms across the whole fire.** The quadratic is real — it is right there in the
per-call figure rising with the live set — but at today's populations it is 0.2%
of the fire and 1.3% of a single committing frame. M3-6 multiplying the voxel
count 4x would make it ~180 ms, still not worth a change.

**Recorded as measured-and-declined, not as pending.** §8.4 asked for a number
before a fix and this is the number; if M3-6 ever pushes the count an order of
magnitude the running min/max is a ten-line change and this section is the
trigger.

### 8.10 ✅ THE FIRE'S WALL CLOCK, SPLIT BY FRAME KIND (2026-08-23) — and it is not the VFX, and it is not `_advance_burn`

`_advance_burn`'s own docstring has claimed since MAT-PERF-04 that the profiler
*"splits it by whether the frame committed, because those are two different costs
and averaging them together is how the last three sessions kept missing this."*
**The code never did the split.** It accumulated one total and printed one mean.
PERF-P7a-ATTRIB implements what the comment always described — the gap read at the
top of frame N is frame N−1's work, so the attribution remembers whether THAT
frame committed.

Same fire, same flags as §8.8:

```
[BURN-PROF] frames during the fire: 43 · mean 144.9 ms · total 6231 ms — of which 13 committed
[BURN-PROF] ATTRIB — committing frames: 12 x 359 ms = 4311 ms · NON-committing frames: 31 x 62.0 ms = 1921 ms
[BURN-PROF] 13 committing frame(s) · 1194 ms inside _advance_burn, 1174 ms of it the scoped repaint
```

| | frames | ms each | total | share of the fire |
|---|---|---|---|---|
| **committing** | 12 | **359** | **4 311 ms** | **69.2%** |
| non-committing | 31 | 62.0 | 1 921 ms | 30.8% |

And inside a committing frame, `_advance_burn` is 1 194 ms over 13 of them — about
**92 ms of the 359**. So:

```
per committing frame:   359 ms
  _advance_burn          92 ms   (of which the scoped repaint is ~90)
  OUTSIDE it            267 ms   <- x12 = 3 204 ms = 51% of the whole fire
```

**Half the fire is spent outside every function this project has instrumented, on
the 12 frames that commit.** §3.4 said *"the 185 frames that commit nothing cost
more than the 14 that do"* — measured this way, on this run, **the opposite is
true**: the committing frames are 69% and each one is 5.8x a non-committing one.
Both readings came from real runs; §3.4 read a mean where this reads the split,
and a mean over two populations 5.8x apart describes neither.

**This explains §8.8b's ceiling.** The VFX lives in the CHEAP 31% — 17.08 ms of
`_draw` on a 62 ms non-committing frame. Removing all of it cannot touch the 69%,
which is why the NOOP run bought 3.8% of wall clock while halving the mean frame.

### 8.11 The next measurement, named but NOT guessed at

What runs outside `_advance_burn` on a frame that COMMITS, and not on one that
does not, is where 51% of this fire is. The obvious candidate is the TileSet
rebuild the 396 minted alternatives trigger — **and this section deliberately does
not assert that**, because §1.1b already measured mints falling 93% with the wall
clock unmoved, and asserting a plausible mechanism without measuring it is exactly
what §1.2 did and had to retract.

**The test is cheap and decisive, and this project already owns it:** fire the same
fire TWICE in one boot. A cost that is minting is paid once and the second fire is
cheap; a cost that is the repaint is paid every time. Nothing here should be built
until that run exists.

⚠️ **And it moves P3 back onto the table.** P3 was frozen in §8.2 on §1.5's finding
that the writes-and-mints half is 0.7–30 ms of ~1 200 on a repaint. That measured
the REPAINT. It did not measure the 267 ms per committing frame that no probe in
this plan has ever been inside. The freeze stands until the two-fires run says
otherwise — but §8.2's reasoning is now known to rest on a term that was never
measured, and that has to be written down rather than discovered again later.

### 8.12 ✅ §8.11 ANSWERED (2026-08-23) — it is NOT the mints, and a committing frame costs ~350 ms whatever it does

`INFILTRAITOR_CAPTURE_ACTION=two_fires` (`Room._capture_two_fires()`). Two
grenades on OPPOSITE sides of the same fabric blocks — fabric burns 100%, so the
same fire cannot be run twice, and the second fire needs its own fuel.

```
INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_CAPTURE_ACTION=two_fires \
INFILTRAITOR_BURN_PROFILE=1 godot --path . --disable-vsync
```

| | fire 1 (31,3) | fire 2 (31,1) | |
|---|---|---|---|
| voxels consumed | 354 | 202 | **−43%** |
| alternatives minted | 694 | 275 | **−60%** |
| committing frames | 12 | 13 | — |
| **ms per committing frame** | **363** | **349** | **−4%** |
| non-committing | 31 × 63.1 ms | 29 × 58.1 ms | |
| fire wall clock | 6 310 ms | 6 223 ms | −1.4% |

Corroborated by the previous run of the same capture: 343 ms and 348 ms. Across
both runs a committing frame costs **343, 346, 349, 363 ms** while the work inside
it varies by 60%.

**The answer to §8.11 is NO.** The 267 ms is not proportional to minting. A fire
that minted 60% fewer alternatives and ate 43% fewer voxels paid the same price per
committing frame. This is also consistent with §1.1b, which is the point: P2 cut
mints 93% and the wall clock did not move, and the reason is that **the cost does
not count mints.**

### ⚠️ 8.12b — the second probe returned NULL, and that is reported rather than buried

The obvious refinement is that the TileSet rebuild is charged once per frame that
mints AT ALL, regardless of how many — the reading MAT-PERF-02's cadence comment
and the standing note on `_burn_prof_alts_at_start` both already carry. A
MINT-SPLIT probe was built to test it, separating committing frames that minted
from committing frames that minted nothing:

```
FIRE 1  MINTED: 12 x 363 ms   minted NOTHING: 0 x 0 ms
FIRE 2  MINTED: 13 x 349 ms   minted NOTHING: 0 x 0 ms
```

**Every committing frame mints. The control group is empty, so the probe cannot
answer its question** — "one rebuild per minting frame" and "some fixed cost per
committing frame" are indistinguishable on this data, and no amount of re-running
this capture will separate them.

Isolating it requires a committing frame that mints ZERO, which this map cannot
produce from a fire: fire 2 still minted 275 across 13 frames. The two things that
DO produce it are the two things already in this plan — **W-PRECOOK's pre-minting
(built, for the shot) and P3/P4 (which removes minting by construction)**. So the
next step is not another measurement of the fire; it is to pre-mint a fire's
alternatives the way the shot already does, and read the committing frame again.

### 8.13 ⚠️ A defect found while building this, and it would have corrupted the result

`_advance_burn`'s end-of-fire block reset **four** counters (`_burn_prof_frames`,
`_burn_prof_voxels`, `_burn_prof_total_us`, `_burn_prof_repaint_us`) and left
**eight** standing, including `_burn_prof_last_frame_us`. Invisible for as long as
a boot only ever held one fire.

With two fires in a boot, the several idle seconds between them would have been
read as ONE frame gap and charged to fire 2's non-committing bucket — destroying
exactly the split §8.10 is built on. Found by reading the reset block before
trusting it, not by the numbers looking wrong; a poisoned run here would have
looked entirely plausible.

Fixed in `start_burn()` rather than at the end of a fire, so a fire that never
finishes cannot leave anything stale for the next one.

### 8.14 Where P7 and P3 stand after all of this

| term | measured | share of the fire |
|---|---|---|
| 12–13 committing frames @ ~350 ms | 4 352–4 538 ms | **~70%** |
| ~30 non-committing frames @ ~60 ms | 1 685–1 958 ms | ~30% |
| — of which VFX `_draw` submission | 16.3 ms/frame | 8% of the fire |

- **P7b (MultiMesh) — still ON HOLD.** Confirmed mechanism (§8.8, 95% submission)
  and real for FRAME RATE (−42.8%, §8.8b), but it lives in the 30% and its wall-clock
  ceiling is 3.8%. Worth building; not worth building first.
- **P3 — the freeze is now questionable in the other direction.** §8.2 froze it on
  §1.5's measurement of the REPAINT. §8.12 has now measured that the fire's dominant
  term is a per-committing-frame cost that ignores mint volume, and §8.12b cannot
  separate it from the rebuild because every committing frame mints. **P3 is the
  only change in this plan that makes a committing frame mint nothing.** That is not
  a decision to unfreeze it — it is the pre-mint experiment §8.12b names, which is
  cheap and settles it either way.
