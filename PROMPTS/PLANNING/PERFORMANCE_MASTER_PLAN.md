# PERFORMANCE_MASTER_PLAN
## Per-cell visual state leaves the TileSet — v1.0

**Status:** 🟠 **v1.2 — TWO CORRECTIONS, BOTH MEASURED (2026-08-22).**
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
| **P5** | ⬆️ **MOVED AHEAD OF P3, Director-ratified 2026-08-22, on §1.5's measurement.** The DERIVATION layer: `bucket_for()`'s first-touch derivation (754 ms) and the walk over every placed cell (458 ms). This is where the map-wide repaint's ~1 200 ms actually is. `VoxelLightField._stale_cells()` already has the incremental shape and, per §5.5, has never run on a real map | — | Large |
| **P3** | ⚠️ **ATTEMPTED AND REVERTED 2026-08-22 — see §3.1**, and now BLOCKED on §3.3. **The light bucket** moves. Worth the boot's 692 ms and 49 947 mints and the architecture, NOT a faster burn today (§1.5) | P5, §3.3 | Large |
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
