# PERFORMANCE_MASTER_PLAN
## Per-cell visual state leaves the TileSet — v1.0

**Status:** 🟢 **v1.0 — the spike PASSED all three gates on real geometry.**
Nothing is built yet. §6 is the task order; §5 is what could still sink it.
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

### 1.2 Where the remaining time is

```
[REPAINT-PROF] occupancy 29.9 · soot 150.9 · field.build 65.8 · apply 1112.1 ms
```

- **apply ~1 080 ms** — the walk over every placed cell on the board (205 760).
- **~2 000 ms outside the profiled function** across 7 frames — 2 179 TileSet
  alternatives minted, and the rebuild they trigger is charged once per FRAME
  THAT MINTS.
- **soot derivation 146 ms** — the map-wide walk over every Slice and Slab.

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

---

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

### 5.3 The shader change is not free, and main is deliberately untouched

Adding a `vertex()` stage to the shipped shader moved **14 pixels of 921 600
(max channel delta 5)** with the spike DISABLED — a real, if tiny, change, and
the residue-class face separation (mod 3, FACE-READ-03) is exactly what a
precision shift flips. So the spike's shader lives at
`godot/shaders/experimental/voxel_face_shading_cellindex.gdshader` and is swapped
in at runtime by the probe only. **P1 owns that decision explicitly.**

### 5.4 RAM

9.8 MB at 44×22 with 32 levels, and it scales with board area × level count. D42
names RAM as this project's real constraint, so a bigger board is a number to
re-measure, not to assume.

### 5.5 A capture harness fact this spike had to establish

A plain boot capture of PLAYGROUND is **NOT deterministic**: two boots of
identical code differ by **34 252 pixels** (the map has a flickering lamp and
temporal lights advance on delta). With `--fixed-fps 60` the same pair differs by
**0**. Any pixel-diff gate in this plan must use it, or it is measuring the lamp.

---

## 6. Task order

| # | Task | Depends on | Size |
|---|---|---|---|
| **P1** | Land cell recovery in `voxel_face_shading.gdshader` — the varying, the inverse-basis uniforms, and an explicit ruling on §5.3's 14 pixels | spike ✅ | Small |
| **P2** | **Soot** moves to the data texture, and the alternative id stops carrying it. Smallest real passenger, and it validates the whole pipeline end to end because soot is ALREADY a shader effect. Gate: a fired shot and a burn look identical (`--fixed-fps 60`) | P1 | Medium |
| **P3** | **The light bucket** moves. This is the one that kills the alternative space and the map-wide apply | P2 | Large |
| **P4** | Retire the alternative-id encoding and the mint cache; re-measure the burn AND the shot, and get §3's real GPU frame time | P3 | Medium |
| **P5** | The DERIVATION layer — the ~210 ms of map-wide walking (soot snapshot, occupancy, field). Only now, for §4's reason | P4 | Large |
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
