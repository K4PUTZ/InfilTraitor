# PERFORMANCE_MASTER_PLAN
## Per-cell visual state leaves the TileSet — v1.0

**Status:** 🟢 **v2.3 — F8 SHIPPED (§9.9): the fire is 6 276 -> 1 885 ms (-70%),
`_advance_burn` is 11 ms, and the post-fire board is 0 pixels different.** The burn's
OWN region stops relighting for the burn's OWN duration — not F1's global cadence,
which the Director rejected — with a one-quad shader wash hiding the boundary. The
two-grenade filmstrip exists (§9.10). ⚠️ The Director's reported bug is NOT diagnosed, and
§9.11a corrects the repro: TWO grenades on DIFFERENT blocks, where the second
blast changes the FIRST one's soot. The ghost-restore mechanism found in §9.11 is
a real defect but almost certainly not that one.
Earlier: **v2.2 — THE FIRE BLOCK SHIPPED (§9.8): 6 276 -> 3 142 ms, span
3.34 -> 1.42 s, rebuilds 13 -> 4, and the post-fire board is 0 pixels different.**
F1 (the light tick) was BUILT, MEASURED and then REJECTED by the Director on look —
the light has to stay responsive — so the span became the lever instead (F6), the
blast takes 70% (F3/F4), and the agent is now locked while its own grenade resolves
(F7), which is what makes the burn's wall clock the player's wait. Acceptance is
scored honestly: criterion 2 FAILED and is recorded as failed, because it belonged
to the design that was rejected. F2 dropped with a reason; F5 held back.
Earlier: **v2.1 — §9 IS A WORK ORDER, AND IT IS THE ACTIVE WORK. §9.7 revises
it on the Director's answers: F1 becomes a light-repaint CADENCE pinned in seconds
rather than a suspension, and there is NO glow system — the FIRE BECOMES A LIGHT on
that same tick, because a glow that lights faces and a glow that is cheap are the
same trade re-entered from the other side. F3 is 70/30.**
Earlier: **v2.0 — §9 IS A WORK ORDER, AND IT IS THE ACTIVE WORK.** The
Director's proposal (suspend the light repaint during the burn, carry the fire's
light as an overlay glow, shorten what soft materials burn, and make fabric and
cardboard PROPS rather than walls) is aimed at the exact term §8.15 isolated:
**~90% of a committing frame is light** — ~224 ms of rebuild plus ~89 ms of
repaint out of ~350. F1 removes both at once and needs none of P3, the MultiMesh
or the recovery fix. Projected ~6 300 -> ~2 200 ms, to be confirmed by §9.6 and not
before. **Working mode, at the Director's instruction: build F1-F5 as one block,
verify ONCE (§9.5 is the acceptance list, written first).**
Still open and explicitly not in the block (§9.4): P3 built-and-gated-off (§8.19),
the shipped cell-recovery defect (§8.22), P7b, the 32 layers.
Earlier: 🔴 **v1.9 — THE CELL RECOVERY IS NOT PER-TILE (§8.22), AND IT SHIPS.**
16.4% of adjacent voxel fragments recover a DIFFERENT cell where a per-tile
recovery would change ~3%, and 10.8% of drawn fragments read a plane texel that
was never written. P3 is built and correct (§8.19) — its data is per-cell exact and
its arithmetic is provably identical (flat-light A/B: 0 px) — and it is blocked by a
defect that predates it. **§8.23: this is P2's recovery too, shipped since P2, and
soot hid it by being sparse.** Root cause still open (§8.24); the atlas grid,
`layer_origin`, float rounding, the CPU data and the arithmetic are all ruled out
BY MEASUREMENT. Earlier: **v1.8 — P3 IS BUILT AND GATED OFF (§8.19). Its DATA is verified
end to end — the alternative space collapses to `{11: 205704}`, i.e. ZERO light
alternatives, and the GPU sampler reads the full bucket spread — but the frame is
wrong: 165 754 px against a control proven at 0, on WALL FACADES, and the on/off
ratios are ratios of `bucket_luminance`, so the two paths apply DIFFERENT BUCKETS
to the same pixel.** §8.20 withdraws §8.18 and shows the gate's residual and P3's
are only 13.7% the same pixels — the floor and the walls, not one phenomenon.
Earlier: **v1.7 — THE TERM IS ISOLATED (§8.15). A committing frame that
mints costs ~360 ms; one that mints NOTHING costs ~126 ms. The difference is ONE
TileSet rebuild per frame, ~240 ms, and it does not count alternatives — 7 frames
minting 24 between them still paid 367 ms each.** That is ~3.1 s of a ~6.3 s fire,
the largest term this plan has ever isolated, and it is why P2 cut mints 93% for
nothing (§1.1b). **§8.2's freeze on P3 is RETRACTED on measurement (§8.16) — P3 is
the only change here that makes a committing frame mint nothing.** §8.17 is the
order. The burn precook is the INSTRUMENT that isolated this, not a fix: its warm
costs as much as it saves, and it stays env-gated off.
Earlier: **v1.6 — §8.11 IS ANSWERED AND THE ANSWER IS NO (§8.12): a
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
| 🟢 **P3** | ⬆️ **UNFROZEN 2026-08-23 (§8.16) — NEXT.** §8.15 measured the term P3 removes at ~240 ms x ~13 committing frames per fire; §8.2's freeze rested on §1.5, which timed the repaint and could not see a cost the engine charges after the frame's script work. Earlier: **FROZEN 2026-08-23 (§8.2b)** — measured at ~0 for a burn or a shot today, so the §3.3 residual that blocks it is not worth unblocking yet. Earlier: ⚠️ **ATTEMPTED AND REVERTED 2026-08-22 — see §3.1**, and BLOCKED on §3.3. **The light bucket** moves. Worth the boot's 692 ms and 49 947 mints and the architecture, NOT a faster burn today (§1.5) | P5, §3.3 | Large |
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

### 8.15 ✅ THE CONTROL GROUP EXISTS NOW, AND IT ANSWERS §8.12b (2026-08-23)

`Room._burn_precook()`, `INFILTRAITOR_BURN_PRECOOK=1` — W-PRECOOK's warm, pointed
at a fire. The whole burn wave is known at `start_burn()`, so the fire's world is
available before its first frame. **Soot-free only**, because `_advance_burn`
repaints each committing frame with `include_soot = false`.

Warming only the FINAL world was not enough — 11 of 12 committing frames still
minted, because a fire's intermediate worlds are not its destination. So the warm
walks the schedule in N stages (`INFILTRAITOR_BURN_PRECOOK_STAGES`), all inside one
frame, since the rebuild is charged per frame that mints.

```
INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_CAPTURE_ACTION=two_fires \
INFILTRAITOR_BURN_PROFILE=1 INFILTRAITOR_BURN_PRECOOK=1 \
INFILTRAITOR_BURN_PRECOOK_STAGES=16 godot --path . --disable-vsync
```

**MINT-SPLIT, fire 2, 16 stages — the control group is no longer empty:**

```
committing frames that MINTED:          7 x 367 ms = 2 568 ms
committing frames that minted NOTHING:  6 x 126 ms =   755 ms
```

Three independent samples of a non-minting committing frame, across two runs and
both fires: **112 ms · 126 ms · 131 ms.** Against ~360 ms for a minting one.

| a committing frame | ms |
|---|---|
| that mints | **~360** |
| that mints nothing | **~126** |
| **the minting** | **~240** |

### ⚠️ And it is ONE rebuild per frame, not per alternative — measured inside a single run

This is the part that closes it. In that same fire 2, **the 7 minting frames minted
24 alternatives between them** — about 3.4 each — **and still cost 367 ms apiece**,
the same as fire 1's frames minting 50+ each. §8.12 established volume-independence
ACROSS fires; this establishes it WITHIN one, against frames that mint almost
nothing at all.

**So the fire's dominant term is one TileSet rebuild per committing frame, ~240 ms,
and it does not care how many alternatives that frame mints.** That is exactly what
MAT-PERF-02's cadence comment and `technical_debt`'s standing note always said, now
measured on the burn instead of inferred from the shot.

It also explains, finally and completely, why §1.1b found P2 cutting mints 93% for
no wall clock at all: **P2 reduced the count on frames that were going to rebuild
anyway.**

### 8.16 What this is worth, and why the precook is NOT the fix

A fire has ~13 committing frames. At ~240 ms of rebuild each, **the rebuild is
~3.1 s of a ~6.3 s fire — roughly half of it**, and it is the single largest term
this plan has ever isolated.

Measured end to end on fire 2 (ATTRIB totals, same capture):

```
no precook        13 committing x 349 ms = 4 538   + 1 685 idle  = 6 223 ms
16-stage precook  13 committing x 256 ms = 3 323   + 1 913 idle  = 5 236 ms   -16%
```

⚠️ **But the warm itself costs 1 207–1 223 ms**, and that is not a rounding error —
it is a fire's worth of saving spent to buy a fire's worth of saving. As shipped,
`_burn_precook()` is roughly break-even, and it is kept as the **instrument that
isolated the term**, not as a fix. It is env-gated off by default.

**The fix that does not pay for itself twice is P3.** P3 is the only change in this
plan that makes a committing frame mint nothing at all — not by minting earlier,
but by removing the alternative as the delivery channel. §8.2 froze P3 on §1.5's
measurement that the writes-and-mints half of a REPAINT is 0.7–30 ms of ~1 200.
That measurement was correct and it was about the wrong thing: the cost is not in
the repaint's own timings, it is the rebuild the engine charges AFTER the frame's
script work, which no probe inside the repaint could ever see.

### 8.17 ⏭️ The order this leaves

| | task | why |
|---|---|---|
| 1 | **UNFREEZE P3**, and with it §3.3's floor residual which blocks it | ~240 ms x ~13 frames x every fire, plus the same term on every shot and blast. The largest isolated term in this plan |
| 2 | **P7b** (MultiMesh) | mechanism confirmed (§8.8), −42.8% frame time, 3.8% wall clock. Real, and second |
| 3 | MATERIALS **M3-6** | after 1, per §8.5 — it multiplies burning voxels, hence committing frames |

**§8.2's freeze is hereby retracted on measurement, not on preference.** It was
taken on the best number available at the time; §8.15 is a better one.


### 8.18 ❌ §3.3's NAMED LEAD IS DEAD, and the gate stops being P3's gatekeeper (2026-08-23)

§3.3 ended on one lead: `debug_cell_quad_rect()` falls back to `texture_origin`
(0, 0) when `get_tile_data()` returns null, every tile here carries (0, 10), and a
silent 10 px error sits squarely inside the observed 2–8 px spread. `alt 0` and
`TRANSFORM_FLIP_H` are native tiles no `create_alternative_tile()` ever produced,
which made them the obvious suspects.

`VoxelRenderer.debug_tiledata_census()`, run inside the gate:

```
[P3-GATE] TILEDATA CENSUS — 205704 placed cell(s) · 0 resolve to NULL TileData (0.00%)
          nulls by alt id: { } · texture_origin histogram: { (0, 10): 205704 }
```

**Zero.** The lead is dead, and the gate still reads:

```
judged 893 145 px · INSIDE 732 442 (82.007%) · OUTSIDE 160 703
inside% per level: L-1 81%(822 643) · L0 98% · L1 100% · L2 98% · L3 100% · L4 98% ...
```

Two things worth carrying:

- **The residual is the FLOOR and nothing else.** L-1 is 822 643 of 893 145 judged
  pixels (92%) at 81%; every wall level is 96–100% on samples of 2–6 k.
- **The wall levels alternate by parity** — even 96–98%, odd 100%, without exception
  across 16 levels. Unexplained, on small samples, recorded rather than chased.

**DECISION: the gate stops blocking P3.** It compares the shader's recovery against
a RECONSTRUCTION of Godot's draw rect, so a disagreement accuses both equally, and
two sessions have now gone into deciding which. P3's own failure mode is directly
observable in a rendered frame — §3.1's attempt was diagnosed from a picture, not
from this gate — and that attempt predates BOTH cell-recovery fixes (`20389fc1`
negative cells, `6d88886c` the quadrant). The cheaper decisive test is to re-attempt
P3 on the fixed recovery and look.

This is a change of instrument, not a claim that the recovery is fine. If P3's
picture is right, the gate was measuring its own reconstruction error; if it is
wrong, the debug render diagnoses it with a recovery that is now two fixes better.

### 8.19 🟠 P3 IS BUILT AND GATED OFF — the data is right, the picture is not (2026-08-23)

The whole change, and it is small because P2 already established the shape:

- the cell plane goes `FORMAT_R8` → **`FORMAT_RG8`**, R = soot code, G = light
  bucket, both writers read-modify-write so neither channel erases the other;
- `encode_light_alt()` returns **`alt_for_flip()`** under the switch — 0 or
  `TRANSFORM_FLIP_H`, both NATIVE tiles `_ensure_light_alt()` already refuses to
  mint, so minting goes to zero without that function changing;
- every apply site writes the bucket **before** the `alt_id == prev_alt`
  comparison, for the exact reason P2's comment gives about soot: once the bucket
  leaves the id, a light-only change leaves the id EQUAL and the caller
  `continue`s;
- the ghost store (§5.1's "reader with real teeth") keeps the plane in step;
- the shader reads G and applies `uniform float bucket_lum[12]`.

**The mechanism works.** `INFILTRAITOR_P3_CENSUS=1`, real boot:

```
P3 ON   205 704 cells · PLANE  {0:49805, 1:32653, 2:47504, 3:15569, ... 11:16361}
                        ALT-id {11: 205704}          <- ZERO light alternatives
P3 OFF  205 704 cells · PLANE  {0:49805, 1:32653, ...}   (identical)
                        ALT-id {0:49805, 1:32653, ...}   (identical)
```

The alternative space collapses to nothing and the plane carries the same
distribution the ids used to. And the GPU agrees — debug paint mode 3 paints the
sampler's own G byte:

```
G byte 0:8478 1:15307 2:20072 3:20243 4:42474 5:70707 6:3198 7:33215
       8:35788 9:18613 10:77330 11:348241 12:23
```

### ⚠️ But the frame is wrong, and the ratios say exactly how

```
CONTROL   P3 off  vs  committed HEAD :        0 px      <- the A/B is honest
          P3 on   vs  committed HEAD :  165 754 px (17.985%), max delta 105
```

- Every delta is a **multiple of 3** — FACE-READ-03's residue snap — so nothing
  here is antialiasing or filtering.
- The differences are on **WALL FACADES**, tracing the window rows.
  [`p3_bucket_mismatch_mask.png`](../../Screenshots/history/p3_bucket_mismatch_mask.png)
  (red = P3 brighter, 106 967 px; blue = darker, 58 787 px). The floor is almost
  entirely unchanged.
- **The on/off RATIOS are ratios of `bucket_luminance` entries**: 2.12 = 0.85/0.40,
  2.50 = 1.00/0.40, 2.09 = 0.69/0.33, 0.55 = 0.47/0.85, 0.92 = 0.92/1.00.

**So the two paths apply DIFFERENT BUCKETS to the same pixel.** Not different
arithmetic on the same bucket — a different bucket. The alternative path takes it
from the tile, which is always that cell's own; P3 takes it from the plane at the
cell the SHADER RECOVERED. Where those disagree, P3 renders a neighbour's light.

### 8.20 ⚠️ §8.18's decision was wrong, and the two residuals are NOT the same one

§8.18 stopped letting the gate block P3, reasoning that a disagreement between the
shader's recovery and a reconstructed draw rect accuses both equally. **The picture
has now implicated the recovery independently**, so that call has to be withdrawn.

But the obvious next inference is also wrong, and it was tested rather than
assumed. The two percentages are near-identical — 17.985% of the frame against the
gate's 17.99% of judged pixels — which invites treating them as one phenomenon.
Overlaid pixel by pixel:

```
gate-OUTSIDE and P3-differs : 22 043
gate-OUTSIDE only           : 138 660
P3-differs only             : 143 711
→ only 13.7% of the gate's failing pixels also differ under P3
```

**Two different populations.** The gate fails on the FLOOR; P3 fails on the WALLS.
The percentage match is a coincidence and is recorded here so nobody spends a
session rediscovering that it is one.

There is a reading that fits both: **a mis-recovered cell only becomes VISIBLE
where neighbouring cells hold different buckets.** A floor is large areas of one
bucket, so recovery errors there are invisible in the frame and only a gate can
see them; a wall column stacks contrasting buckets, so errors show as exactly the
banding on the facades. That predicts the gate under-reports the walls and the
picture under-reports the floor, which is what both instruments did. **Stated as
the working hypothesis, not as a finding** — it has not been tested.

### 8.21 Where P3 stands

**Built, complete, and `INFILTRAITOR_P3=1` to opt in. Default OFF, so nothing
broken ships.** The switch stays: it puts both sides of the A/B in one binary and
one map, which is stricter than §5.5's stash-and-rerun.

What it is worth is unchanged and now has a second confirmation — the ALT-id
histogram collapsing to a single value IS zero minting, which §8.15 measured at
~240 ms per committing frame, ~3.1 s of a ~6.3 s fire.

**The one thing standing between here and that: the cell recovery has to be right
on wall fragments.** That is a smaller, sharper question than §3.3's floor
residual, and it now has an instrument that answers in a picture rather than in a
containment statistic.

### 8.22 🔴 THE CELL RECOVERY IS NOT PER-TILE — and that is a SHIPPED defect, not a P3 one (2026-08-23)

Chasing §8.19's wrong buckets produced a diagnosis that is bigger than P3. In
order, each step killing the hypothesis before it:

**1. The CPU data is perfect.** The census gained a PER-CELL comparison (the first
version compared only histograms, which matched exactly and read as a pass):

```
[P3-CENSUS] PER-CELL disagreement (plane vs alt id): 0 of 205704 (0.0000%)
```

**2. The arithmetic is identical.** `INFILTRAITOR_FLAT_LIGHT=1` flattens
`bucket_luminance` to all 1.00 on BOTH delivery paths, so no fragment's value can
depend on WHICH bucket it read:

```
FLAT LIGHT   P3=1 vs P3=0:  0 px
```

So every face factor, the soot, the residue snap and the modulate path agree
exactly. **The entire difference is which bucket value reaches a fragment.**

**3. Nothing structural is misaligned.** Measured, not read:

- `debug_atlas_alignment()` — **55 sources, 0 misaligned** to the shader's
  `mod(32, 36)` grid (margins and region+separation are multiples of the atom).
- `debug_layer_origin_drift()` — **0 layers** whose `layer_origin` uniform no
  longer matches `get_global_transform().origin`.
- Snapping the quad origin to the pixel lattice before inverting changed the
  result by **exactly 0 pixels** (165 754 before and after), so the float32
  residue was never near a rounding boundary either.

**4. The plane's fill became a SENTINEL, and that is what finally spoke.** G is
filled with `BUCKET_UNWRITTEN = 255` instead of bucket 11, so "never written" stops
being the same byte as "genuinely full lit" — the exact ambiguity that let §3.3's
`hint_default_white` and PERF-P2's ~110 000 clean-fallback fragments hide. Debug
paint mode 3, real boot:

```
G=255 -> 75 119 px (10.83% of all drawn voxel fragments)   <-- NEVER WRITTEN
```

**A drawn fragment belongs to a placed cell by construction, and all 205 704
placed cells have a written bucket.** So those fragments recovered a cell that is
not the cell that drew them.
[`p3_unwritten_mask.png`](../../Screenshots/history/p3_unwritten_mask.png).

**5. And the recovery is not per-tile at all.** Debug paint mode 2 paints the
recovered cell itself; adjacent opaque voxel fragments were then compared
directly ([`p3_recovered_cells.png`](../../Screenshots/history/p3_recovered_cells.png)):

```
682 989 adjacent horizontal pairs, both voxel fragments
  same recovered cell : 571 011 (83.6%)
  DIFFERENT           : 111 978 (16.4%)
expected if the recovery were per-TILE: one change per 32 px, ~3%
```

Among the never-written fragments specifically, **46 285 of 46 300 disagree with
their immediate neighbour** — jumps of 2–3 cells across a single pixel.

**The recovery varies WITHIN a tile, and it is supposed to be constant across
one.** §3.2's whole mechanism is that `VERTEX - local` is the quad's top-left and
therefore per-tile; that premise does not hold on the real board.

### ⚠️ 8.23 This is P2's recovery too, and P2 is SHIPPED

`voxel_face_shading.gdshader` has ONE cell recovery and P2's soot has been riding
it since it landed. The soot gates passed at 0 differing pixels because **soot is
sparse**: a fragment that reads the wrong cell almost always reads a cell with no
soot either, and clean-vs-clean is invisible. Light has no such mercy — every cell
has a bucket, so the same defect that soot hid, light renders.

That reframes three earlier entries:

- **§3.3's floor residual is not a gate artefact.** §8.18 retired the gate on the
  reasoning that it might be measuring its own reconstruction; §8.20 already
  withdrew that, and this closes it — the recovery is genuinely wrong, and the
  gate was reporting a real thing all along.
- **§8.20's "two different populations" still stands** (13.7% overlap), and now has
  a mechanism: the gate judges CONTAINMENT, which a within-tile wobble often
  survives, while light is wrong the moment the cell changes at all.
- **P3 is not blocked by P3.** Nothing in §8.19's plumbing is wrong. It is blocked
  by a defect that predates it and currently ships.

### 8.24 What is NOT yet known

**The root cause.** Ruled out by measurement above: the atlas grid, `layer_origin`,
float32 rounding at the quad origin, the CPU data, and the arithmetic. What
remains untested is what `v_vertex` and `UV` actually carry per fragment on a
batched `TileMapLayer` — the varying's interpolation and its precision on the
wall sheets specifically, which are 2 048-atom pages whose atlas coordinates run
into the thousands while the floor's atlas is small.

**Recorded as the open question, not as a conclusion.** The instruments that
answer it now exist and are cheap: mode 2 (recovered cell), mode 3 (plane G with a
sentinel fill), `INFILTRAITOR_FLAT_LIGHT`, and the per-cell census.

---

# 9. THE FIRE WORK ORDER — build the whole block, verify once

**Opened 2026-08-23 at the Director's instruction**, and the instruction includes
the working mode: *"Coloca isso no plano, vamos formalizar todo o processo antes.
Priorizando fazer tudo que for necessário primeiro, e depois testando o resultado.
Já perdemos muito tempo medindo."*

**So this section is a WORK ORDER, not an investigation.** §§1–8 measured; this
builds. F1–F5 land as one block and §9.6 is the single verification pass. No
intermediate measurement runs, no stopping between items to re-derive a number
that is already written down above.

⚠️ **What that changes and what it does not.** It changes the CADENCE — one
verification instead of one per step. It does not change the standard: §9.6 is a
real pass with real numbers and a real capture, and if it fails, it fails out loud.

## 9.1 Where the Director's proposal came from, and why it outranks everything above

Director, 2026-08-23: *"Se a gente suspender a atualização da luz durante o fogo
ganhamos processamento? Por exemplo aplicando um clarão em volta do fogo e mantendo
aquela região estática?"* — and, on the materials: *"a explosão pode destruir mais
voxels de uma vez e queimar só o final do tecido e do papelão… esses materiais vão
ser mais usados como cortinas, caixas e objetos decorativos."*

Against §8.15's decomposition of a committing frame, that proposal is aimed
exactly at the term that dominates:

| inside one committing frame | ms | removed by |
|---|---|---|
| the TileSet rebuild the light repaint's minting triggers | **~224** | **F1** |
| the scoped light repaint itself | **~89** | **F1** |
| everything else (commit, geometry, the frame's own VFX) | ~36 | — |
| | **~350** | |

**~90% of a committing frame is light.** F1 removes both terms at once, because
the rebuild exists only as a consequence of the repaint.

Projected (from §8.15's measured parts, to be confirmed by §9.6 and not before):

```
today   13 x 350 ms = 4 550   + ~1 800 (non-committing)  + ~870 (final repaint)  = ~6 300 ms
F1      13 x  ~36   =  ~470   + ~1 800                   + ~870                  = ~2 200 ms
```

**And F1 needs no new architecture.** P3, the MultiMesh, and the cell-recovery
defect are all still real and all still open — F1 simply does not depend on any of
them.

## 9.2 The five items

### F1 — the burn stops repainting light

`_advance_burn()` stops calling `_repaint_voxel_light_buckets_scoped()` on its
committing frames. Geometry still commits and holes still appear on schedule —
that is `commit_damage()` plus the renderer's own erase, and neither is light.
Light catches up in the ONE map-wide repaint the fire already ends with
(`_burn_final_repaint()`, MAT-PERF-02).

Consequences to honour rather than discover:
- **Soot is already deferred** — burn frames pass `include_soot = false` and
  `_burn_soot_gus` accumulates for the final pass. F1 does not change that.
- **The occlusion ghost store** must not be left holding a stale `prev_alt` for a
  cell the burn erased; check before assuming.
- **`bump_world_revision()`** still fires per commit, so predictions stay honest.

### F2 — the fire's own glow, as an overlay

The region stops relighting, so the fire has to carry its own light or the burn
reads as holes appearing in a dead wall. A warm glow around the burning voxels,
drawn as a **CanvasItem overlay** — not voxel state, not a light, not an
alternative. Nothing it does can mint.

⚠️ **It goes on the existing VFX overlay path, and §8.8 measured what that path
costs**: `draw_*` submission is 95% of a `_draw`. So F2 is written for MultiMesh
or for a small fixed number of primitives from the start — a per-voxel
`draw_circle` glow would spend a slice of what F1 just saved.

Look is the Director's: extent, colour, whether it pulses, whether it fades with
the fire.

### F3 — soft materials burn only their remnant

*"queimar só o final do tecido e do papelão."* Fewer committing frames come from a
SHORTER fire, not from fewer voxels — the cadence is
`BURN_COMMIT_INTERVAL_S = 0.20 s`, so the count is duration/0.20 and nothing else.
This is therefore a direct, linear cut on the dominant term.

Needs one number the Director owns: **how much of a soft object the blast takes
outright versus what is left to burn.** Stated as a starting default so the work is
not blocked: the blast takes the object and the fire consumes the REMNANT, which
§3.1a already calls the thing fire operates on.

### F4 — the blast destroys more in one frame

Moving voxels out of the burn schedule and into the blast moves them from MANY
committing frames into ONE. Same total destruction, a fraction of the rebuilds.

### F5 — fabric and cardboard become props, not walls

Director: *"não vão ser usados em paredes inteiras… cortinas, caixas e objetos
decorativos."* A map/authoring change in PLAYGROUND and a `MATERIALS_MASTER_PLAN`
scope correction.

⚠️ **This retires a risk rather than accepting one.** §8.5 sequenced M3-6 (lateral
propagation) behind the performance work because it multiplies burning voxels. If
these materials are curtains and boxes, that multiplication has nowhere to run and
the risk mostly evaporates — record it in MATERIALS rather than leaving §8.5
standing as written.

## 9.3 Order

F1 → F3 → F4 → F2 → F5. F1 first because everything else is measured against it;
F2 after F3/F4 because the glow should be authored against the fire's final
timing, not the current one.

## 9.4 What this block explicitly does NOT do

- **P3** stays built and gated off (§8.19). F1 removes its urgency for the FIRE;
  it still pays on every shot and blast, and it stays a real architecture item.
- **The cell-recovery defect (§8.22)** is untouched and still ships. It affects
  P2's soot, which is sparse enough to be invisible, and it blocks P3. Open.
- **P7b (MultiMesh)** stays open; F2 is written not to make it worse.
- **The 32 `TileMapLayer`s' 19 ms/frame** stays open.

## 9.5 Acceptance criteria, written BEFORE the work

Stated now so §9.6 has something to check rather than something to narrate.

1. A fabric fire's wall clock is **under 3 000 ms** (from ~6 300).
2. A committing frame is **under 60 ms** (from ~350).
3. **Zero TileSet alternatives minted during the burn's committing frames** —
   `[BURN-PROF] … alternative(s) minted` reads 0.
4. The holes still appear on the fire's own schedule: `[E-BURN] … consumed over
   N.NNs` unchanged in shape, and a filmstrip shows the wall opening progressively
   rather than all at once.
5. The board after the fire is **visually identical to the board after the fire
   today** — the final repaint is unchanged, so the END STATE must be. A pixel diff
   at `--fixed-fps 60` against a same-binary control, and a stated number.
6. Gates: lint, selftests, invariants, CODEMAP.

⚠️ **Criterion 5 is the one that can fail quietly.** F1 removes intermediate
relighting; if anything other than the final repaint was depending on those
intermediate passes, the end state drifts and only a pixel diff will say so.

## 9.6 Verification — once, at the end

One pass, covering all six criteria above, with pasted output and a real capture.
Not per item, not deferred, not narrated as expected.

## 9.7 REVISED — the Director's answers, and F1 becomes a TICK rather than a suspension

Director, 2026-08-23, answering §9.2:

> *"F3 — Vamos testar inicialmente uns 70% da area afetada, e queima o que sobrar.
> F2 — Pode propor como preferir. Nao precisa necessariamente ter um clarão, eu
> pensei nisso mais pra delimitar onde começa e termina a suspensão da luz… mas não
> podemos trocar 6 por meia dúzia, tem que ser uma vantagem. Pensando no resto do
> sistema, poderíamos limitar o paint da luz por ticks, criando um caso à parte para
> iluminação piscando."*

**The tick idea supersedes F1's suspension, and it is better on three counts.**

### F1 (revised) — the light repaint gets a CADENCE, pinned in SECONDS

Not "off during the fire" but **`LIGHT_REPAINT_INTERVAL_S`** — a repaint happens
at most once per interval, whatever asks for it. The burn's committing frames then
mint on a handful of frames instead of all thirteen.

⚠️ **Pinned in SECONDS, not frames, and that is not a style choice.**
`BURN_COMMIT_INTERVAL_S` carries the same rule and the same comment explains why:
cheaper frames buy MORE of them, so a frame-counted budget silently spends itself
back the moment the frame gets faster. This project has already paid for that once.

What it costs, from §8.15's measured parts (projection, §9.6 confirms):

```
today                13 x 350 ms                       = 4 550 ms
suspend entirely     13 x  ~36                          =  ~470 ms
tick at 1.0 s         3 x 350 + 10 x ~36                = ~1 410 ms
```

The tick is ~940 ms dearer than a full suspension and **buys back the thing the
suspension was going to need a glow to hide**: the region keeps relighting, just
coarsely. It is also a SYSTEM policy rather than a fire special case — which is
what makes flicker its natural second caller.

### F2 (revised) — NO separate glow overlay, and here is the "6 por meia dúzia"

The Director's caution is exactly right, and it has a sharp form:

- a glow drawn as a **CanvasItem overlay** is cheap and **cannot light faces** — it
  draws ON TOP of the voxels, it does not change their shading;
- a glow that genuinely **lights nearer faces** has to go through the voxel light
  field, which is the per-cell path whose repaint and mint F1 just removed.

**So "a glow that lights faces" and "a glow that is cheap" are the same trade F1
is making, re-entered from the other side.** Building both is trading 6 for half a
dozen, precisely as the Director said.

**The proposal: there is no glow system. The FIRE BECOMES A LIGHT**, and it
repaints on F1's tick like everything else. One mechanism, not two: it lights
nearer faces properly, it can pulse (the pulse is a light property, not a new
system), and it costs exactly one tick — which is already budgeted.

And it lands on a seam that already exists and has **never run**: §5.5 recorded
that `Room._update_temporal_lights()`'s VL-03 incremental repaint is unreachable
because `changed_lights` is always empty — *"correct code waiting for a caller."*
A fire is that caller, and so is the flicker the Director wants as its own case.

⚠️ **Staged, because that path is unproven:**
- **F2a** — the tick alone, no fire light. The ember overlay already carries the
  fire's own read, so this is shippable on its own.
- **F2b** — the fire registers as a real light on the tick. If VL-03's incremental
  path does not hold up, F2b is DROPPED and F2a stands. It must not block the block.

### F3 (revised) — 70/30

**The blast destroys 70% of the affected area outright; the fire burns the
remaining 30%.** Director's number, to be tuned against the look.

Its value is duration, not voxel count: the committing-frame count is
`duration / BURN_COMMIT_INTERVAL_S`, so a fire with 30% of the fuel finishes sooner
and pays proportionally fewer rebuilds. F3 and F1 multiply rather than overlap.

### 9.7a Acceptance, amended

§9.5's criteria stand, with two changes:

- **Criterion 1** becomes **under 3 500 ms** (from ~6 300). The tick is dearer than
  the suspension it replaces, and the acceptance number moves with the design
  rather than the design being trimmed to fit the number.
- **Criterion 3** becomes: alternatives minted during the burn are **bounded by the
  tick** — at most one minting frame per `LIGHT_REPAINT_INTERVAL_S` — instead of
  zero. Zero was the suspension's number and is no longer the design.

### 9.7b Order, amended

**F1 → F3 → F4 → F2a → F2b (attempt) → F5.** F2b last inside the block because it
is the only item allowed to fail without failing the block.

## 9.8 ✅ THE BLOCK IS BUILT AND VERIFIED — and F1 was REJECTED on look before it shipped

Director, 2026-08-23, after seeing F1's measurement: *"não vamos trabalhar a luz por
tics, ela precisa ser mais rapida. Ok, vamos seguir e deixar o fogo mais rápido e
volátil."* And, changing what the burn's wall clock MEANS:

> *"o agente fica livre durante o lag da queima, quando na realidade, pela natureza
> do jogo ser por turnos, ele deve ficar travado até o fim do evento que originou o
> gasto dos AP (no caso jogar a granada). Então esse fogo é a continuação da
> explosão."*

**F1 (the light tick) is REVERTED.** It worked — measured below — and it was
rejected because the light has to stay responsive. The measurement is kept because
it is the thing that says how much the light costs, and it will be true again the
next time someone proposes coarsening it:

```
F1 at a 1.0 s tick, fire 1:  6 276 -> 4 027 ms · committing frames 13 x 346 -> 12 x 139
                             frames that MINT 13 -> 5 · a non-minting commit costs 45 ms
```

⚠️ And it exposed the ceiling that made it the wrong lever anyway: with the
committing frames 62% cheaper, the NON-committing frames grew from 28 to 44 and
became 58% of the fire. **Cheaper frames buy more frames** — the same effect
`BURN_COMMIT_INTERVAL_S`'s comment records and §8.8b measured on the VFX.

### What shipped instead

**F6 — the fire is faster and more volatile.** The span is the bill: committing
frames are `span / BURN_COMMIT_INTERVAL_S`. And most of the old span was not the
burn life at all — `EMBER_CLIMB_DELAY_S` staggers the flame UP the wall and
dominated it.

```
BURN_BASE_LIFE_S    1.4  -> 0.55      EMBER_CLIMB_DELAY_S   0.28 -> 0.10
BURN_LIFE_JITTER    0.45 -> 0.60      EMBER_SEED_STAGGER_S  0.45 -> 0.20
```

**F3/F4 — 70/30**, implemented in the SCHEDULE rather than the resistance model:
the `destroy` wave is choreography and the real damage comes from
`BlastCalculator`, so forcing a share through there would mean editing resistance
to get a scheduling outcome. The blast's share lands in the fire's first batch, on
its own FNV-1a domain (`BURNSHARE`) so tuning it cannot disturb which voxels burn
(`BURNROLL`) or how long the survivors take (`BURNLIFE`).

**F7 — agent actions are locked while the burn resolves.** `is_resolving_action()`,
guarded on movement, both postures, peek, grenade mode, grenade throw and weapon
select. Camera, view mode, pause, screenshots and debug tools stay live on purpose:
locking those makes a resolving turn feel frozen rather than busy.

### The numbers, fire 1, same fire throughout (354 voxels, fabric at gu 31,3)

| | before | after |
|---|---|---|
| fire span | 3.34 s | **1.42 s** |
| **wall clock** | ~6 276 ms | **3 142 ms** (−50%) |
| frames during the fire | 43 | **18** |
| committing frames | 13 × ~346 ms = 4 458 | **6** (5 gaps × 423) = **2 115** (−53%) |
| non-committing | 31 × 65 ms = 1 837 | 13 × 79 ms = **1 026** |
| frames that MINT (= rebuilds) | 13 | **4** |

### Acceptance, scored honestly

1. **Wall clock under 3 500 ms — PASS. 3 142 ms**, from ~6 276.
2. **A committing frame under 60 ms — FAIL, 423 ms.** ⚠️ **This criterion belonged
   to F1's suspension**, which the Director rejected; with the light repainting
   every commit, a committing frame cannot be cheap. F6 makes them FEWER and fatter
   instead — 6 × 423 beats 13 × 346 — so the criterion is wrong for the shipped
   design rather than the design failing it. **Recorded as failed rather than
   rewritten to fit.**
3. **Mints bounded by the tick — N/A.** The tick is gone. What did move is the
   rebuild count: **13 minting frames → 4.**
4. **Holes appear progressively — PASS by construction**, 6 batches across 1.42 s.
   ⚠️ **No filmstrip was run**, so this is structural, not photographed.
5. **End state identical — PASS. 0 differing pixels**, `--fixed-fps 60`, block vs
   HEAD, both post-fire.
6. **Gates — PASS.** lint 216 · selftests 39 clean / 0 failed · invariants · CODEMAP.

⚠️ **F7's behaviour is NOT verified.** The guards are placed and compile, and the
capture paths still drive the fire (they enter through `_unhandled_input` and the
test-zone controller, not through the guarded handlers) — but no run has actually
pressed a movement key during a burn and confirmed it was refused. Stated as built,
not as proven.

### Still not done in this block

**F2 (any glow) is dropped**, and with a reason rather than by omission: a
CanvasItem overlay cannot light faces, and anything that DOES light faces goes
through the per-cell path — and F2b's fire-as-a-light would additionally trigger
shadow projection, another map-scale computation. That is the Director's *"trocar 6
por meia dúzia"* exactly. **F5** (fabric and cardboard authored as props) is
deliberately held back: it changes the map, which would make this comparison
incomparable.

## 9.9 ✅ F8 — the fire's own region stops relighting, and the burn is 1.9 s

Director, 2026-08-23: *"embora a gente não vá trabalhar por tics, continuamos
querendo suspender a atualização da area de luz na região com fogo, usando o clarão
pra disfarçar a borda… o maior problema é o lag mesmo, tudo fica travando."*

**F8 is NOT F1, and the distinction is the whole design.** F1 was a GLOBAL cadence
and was rejected because the light has to stay responsive. F8 is confined to the
burn's own GUs and the burn's own duration — the burn's repaint was ALREADY scoped
to the fire's GUs, so this simply does not run it, and every other light in the game
is untouched.

```
fire 1, same fire throughout (354 voxels, fabric at gu 31,3)

                       original   after F3/F4/F6   after F8
  fire wall clock       6 276 ms      3 142 ms     1 885 ms     -70%
  _advance_burn         1 268 ms        691 ms        11 ms
    of it the repaint   1 247 ms        679 ms         0 ms
  committing frames   13 x ~346      6 (5 x 423)   6 (5 x 140)
  span                   3.34 s        1.42 s        1.31 s
```

**`_advance_burn` is 11 ms.** The destruction system was never the cost; the light
it asked for was, and §8.15 said so before any of this was built.

**Criterion 5 — PASS, 0 differing pixels**, `--fixed-fps 60`, F8 against the same
build with F8 off, same map, same grenade, both captured after the fire. The
map-wide `_burn_final_repaint()` still runs, so the end state is unchanged by
construction and this is the measurement that says the construction held.

### The glow, and what it is NOT

`FireGlowOverlay` — **one `draw_rect` and a fragment shader**, never a primitive per
voxel. §8.8 measured the existing VFX overlays at 95% `draw_*` submission, so a glow
built the usual way would have spent a slice of exactly what F8 saved: the
Director's *"trocar 6 por meia dúzia"*. It does not light faces, deliberately —
anything that does goes back through the per-cell path F8 just suspended.

⚠️ **A defect I introduced while chasing one.** The first version called
`release()` beside the final repaint, and a fire has TWO end paths — that one, and
the early return when the last batch is already all holes. A fire ending the other
way left the wash on screen permanently. It is released where the fire is DECLARED
OUT now. Recorded because it is the same class of bug as the one being investigated,
committed while investigating it.

## 9.10 ✅ P-FILM-2 — the two-grenade filmstrip exists

`INFILTRAITOR_FILMSTRIP_SECOND_AT=<frame>` fires a second grenade partway through
the strip, so both blasts and both fires land on ONE continuous timeline.

```
INFILTRAITOR_GRENADE_GUS="31,3;31,1" INFILTRAITOR_FILMSTRIP_SECOND_AT=55 \
INFILTRAITOR_FILMSTRIP_SECOND_INDEX=1 \
python3 tools/persistent/build_filmstrip.py --frames 120 --grenade 0 --cols 10
```

[`twogrenade_filmstrip.png`](../../Screenshots/history/twogrenade_filmstrip.png) —
kept under a non-`auto_` name so the rotation cannot take it.

⚠️ **The reported bug is NOT diagnosed yet.** The strip reads cleanly on the first
blast and fire; the washed-out tiles around frames 42–47 are the second blast's
NEGATIVE FLASH (`explosion_flash_overlay`), not the glow and not a defect. The
Director's symptoms — *"toda a fuligem está sendo repintada"* and *"algumas areas
queimam e soltam fumaça uma segunda vez"* — need the strip read against the second
fire's own frames, and the standing lead is theirs: a dirty flag finalised in the
wrong place, with `voxel_destroyed` firing again on a re-render and the smoke
following it.

## 9.11 🟠 THE DOUBLE-SMOKE MECHANISM — found by reading, NOT yet reproduced

The Director's lead was right about the shape: *"a gente ja teve um caso assim
antes onde a dirty flag nao era finalizada no lugar certo e a fumaça acontecia
duas vezes."*

**The mechanism, read out of the code:**

```
1. occlusion ghosts a cell — erased, its placement remembered in _ghosted_cells
2. a blast destroys that voxel: process_dirty() erases it, sees `already_gone`,
   and correctly does NOT emit voxel_destroyed
3. the agent moves on and _restore_ghosted_cells() PUTS THE CELL BACK — it
   restores from the saved record precisely so it need not consult live layer
   state (OCC-21), so it cannot know the voxel died
4. the next dirty pass finds geometry there, erases it, and emits
   voxel_destroyed — smoke, debris and sparks for a voxel killed in an
   earlier blast
```

⚠️ **Both emit guards are CORRECT and are not the bug.** In step 4 the cell really
was there. The ghost record is what was never finalised.

**The fix:** `forget_ghost_record(cell, level)`, called at both erase sites — a
destroyed voxel stops being restorable at the moment it dies, which is the only
place that knows.

### ⚠️ But this is NOT closed, and the reason is the honest one

**No red-before-green on the real symptom.** The one existing diagnostic that
counts dispatches was run both ways:

```
                         WITH the fix        WITHOUT the fix
grenade 0                350 dispatch(es)    350 dispatch(es)
grenade 1                184                 184
the shot                   3                   3
```

**Identical.** `grenade_then_shot` never moves the agent, so occlusion never ghosts
the walls it blows up, and step 1 of the sequence above never happens. The capture
cannot see this defect, and matching numbers here are evidence of nothing.

So the fix is **a correctness fix on a mechanism read out of the code**, not a
demonstrated repair of the reported symptom. Recorded that way deliberately: this
project's rule is that *"fixing a reported bug needs red-before-green on the REAL
symptom, not a constructed stand-in"*, and shipping it as closed would be exactly
the claim that rule exists to stop.

**What the repro needs:** a capture that (1) walks the agent so the target wall is
ghosted, (2) detonates, (3) walks the agent away so `_restore_ghosted_cells()`
runs, (4) detonates again — and counts dispatches at each step. Steps 1 and 3 are
the ones no existing capture does.

**And the soot half is still unexplained.** *"toda a fuligem está sendo repintada"*
is consistent with the map-wide `_burn_final_repaint()` doing exactly what
MAT-PERF-02 designed it to do, which would make it correct-but-visible rather than
a defect — that has not been established either way.

### 8.15b ⚠️ §8.15's HEADLINE NUMBER IS STALE, AND A PLAN ALMOST ARGUED FROM IT (2026-08-27)

§8.15 reads *"a committing frame that mints costs ~360 ms; one that mints NOTHING
costs ~126 ms. The difference is ONE TileSet rebuild per frame, ~240 ms"*, and it
is quoted across this file and out of it. **The wave in §12 shipped on 2026-08-26
and nobody re-read the sentences resting on it.**

Measured 2026-08-27, the two-fire run, `INFILTRAITOR_BURN_PROFILE=1`:

```
frames during the fire: 77 · mean 17.1 ms · max 26 ms · total 1 316 ms — 7 committed
ATTRIB — committing frames:      6 x 20.0 ms =   120 ms
         NON-committing frames: 71 x 16.8 ms = 1 196 ms
MINT-SPLIT — committing frames that MINTED: 0 · that minted NOTHING: 6 x 20 ms
```

**20 ms against 16.8 ms — a 3 ms difference, and zero mints.** The 360/126 split
describes a build that no longer exists.

The consequence is not just bookkeeping: **91% of the fire's wall clock (1 196 of
1 316 ms) is frames doing nothing but passing.** The fire is not expensive, it is
LONG, and duration is schedule rather than cost. `FIRE_REBUILD_MASTER_PLAN` §2.1
was drafted arguing from the old number and had to be rewritten before it shipped.

**The general rule this project keeps re-learning:** a perf wave invalidates every
sentence that quotes a cost, and those sentences do not announce themselves. The
same lesson as `front_frames` being silently retuned 5× — see §12's own note.

### 9.11e ⛔ §9.11 REPRODUCES. "Not reproduced" was wrong, and the cause is THE FIRE (2026-08-27)

Built a cell-level probe (`INFILTRAITOR_CELL_PROBE=1`, sampled from the
filmstrip's own frame loop so probe frame N is image frame N) after a 3× slow
capture showed voxel-shaped wall reappearing. It reads the TileMapLayer, which
can only answer one way.

**Fabric, gu (31,3), one build, the only difference being `INFILTRAITOR_NO_BURN`:**

```
with fire   27 928 armed · 1 163 erased · 350 RESTORED — all on ONE frame, f125
without     27 928 armed ·   813 erased ·   0 restored
```

`1 163 − 813 = 350`, exactly the restored count, and `[E-BURN]` reports **356**
voxels consumed. **The voxels the FIRE eats are the voxels that come back.** Cells
erased on f54 are re-placed on f125, and they stay.

**The blast alone is clean.** The no-burn run is not a vacuous green — its log
carries the whole consequence beat (`soot ramp — 4 step(s) x 8 frame(s)`, all four
`[E-FUME]` steps, `light ramp — 702 cell(s) moving`), identical to the fire run.
Same beat, same repaints, no restoration. Only the fire differs.

Where: the restorations land in one frame at the opening of the CONSEQUENCE beat,
between `[CONSEQUENCE] fire out — the beat owns the ending, burn repaint stands
down` and `[CONSEQUENCE] soot ramp`.

⚠️ **This is why §9.11a's correction pointed away from the ghost path and the
trail went cold: the repro needs a FIRE, and every instrument aimed at it since
has been aimed at two blasts.** §9.11's own claim — *"a destroyed voxel must not
be restorable"* — is the right claim and it is being violated on every flammable
detonation.

Director's call, same day: the fire is to be **rebuilt** rather than patched, and
normal (fireless) explosions are to be verified across every material first.

### 9.11a ⚠️ THE REPRO, CORRECTED BY THE DIRECTOR — and it is NOT the ghost path

2026-08-23, closing: *"são duas granadas em locais diferentes, por exemplo no bloco
de pano e depois no de madeirite. A segunda explosão influencia na fuligem da
primeira."*

**That is a different defect from §9.11's**, and §9.11's ghost-restore mechanism is
almost certainly not it — nothing in that sequence needs a second blast anywhere,
let alone one across the map. §9.11's fix stands on its own merits (a destroyed
voxel must not be restorable) and its "not reproduced" status is unchanged; it just
stops being a candidate explanation for what the Director actually saw.

**The lead this points at instead, stated as a lead:** `_build_soot_snapshot()` is
MAP-WIDE by design, and D24 derives soot from which voxels are ABSENT anywhere. So
blast 2's holes join the seed set that blast 1's region is re-derived against, and
`_burn_final_repaint()` is map-wide too — it re-applies the whole board. The
scoped-repaint comment says exactly why the snapshot cannot be scoped: *"a scoped
snapshot would be a second soot producer — the exact drift SOOT_MASTER_PLAN §1.2
found between two of them."*

So the question tomorrow is a fork, and both branches are real:
- the re-derivation is CORRECT and blast 1's soot legitimately deepens because the
  board genuinely has more holes in it — visible, not broken; or
- something in the derivation is seed-count or order dependent and blast 1's region
  comes back DIFFERENT rather than merely darker.

**What settles it:** two grenades on different materials (fabric, then plywood),
capture the board after each, and diff the FIRST block's region alone. §9.10's
two-grenade capture already does everything except place them on different blocks
and mask the diff to the first crater.

**Deferred to 2026-08-24 at the Director's instruction** — *"vamos testar com mais
detalhes amanha."*

### 9.11b ✅ §9.11a ANSWERED — the Director was right, and every before/after instrument was blind to it (2026-08-24)

Two grenades on different blocks, the Director's own repro: **fabric at gu (31,3),
then plywood at gu (35,3)**, four GUs apart, through
`INFILTRAITOR_CAPTURE_ACTION=two_fires` with `INFILTRAITOR_TWO_FIRES_GUS`.

**§9.11a's fork is answered NEITHER way, because it was the wrong fork.** The end
state is untouched:

```
[TWO-FIRES-SOOT] census: 205 162 cell(s) · 2 149 changed since fire 1
[TWO-FIRES-SOOT] NEAR FIRE 1: 0 changed — 0 soot codes, 0 alternative ids
```

and the board diff agrees — with `INFILTRAITOR_VFX_DRAW_NOOP=1` to take the
drifting smoke out of the picture, all 50 680 differing pixels sit in fire 2's own
block ([`twofires_after_1.png`](../../Screenshots/history/twofires_after_1.png) /
`_2`). Blast 1's region is bit-identical afterwards.

**The report is about the FLIGHT, not the destination.** *"Toda a fuligem está
sendo repintada"* is a sentence about a repaint being SEEN. Armed on fire 1's
settled region and sampled every frame through the whole of fire 2:

```
[TWO-FIRES-WATCH] 1 287 cell(s) disagreed at least once
                  — 180 FLICKERED and came back, 1 107 changed for good
  the flicker, by GU:  (31,3) 28 · (29,3) 27 · (32,4) 23 · (30,3) 23 · (32,3) 20
                       (31,4) 17 · (31,2) 16 · (32,2) 15 · (30,4) 12 · (30,2) 3
                       — every one 0-2 GU from fire 1, 0 permanent in any of them
  e.g. (262,23,0) settled soot 26 -> 119 on frames 55..59, back to 26
```

**Fire 1's crater goes to near-clean for five frames and comes back exactly.** The
1 107 permanent changes are all fire 2's own (gu 33-34). This is why §9.11's
diagnostic returned identical numbers both ways, and why a pixel diff of the two
boards says nothing happened: **nothing did happen, to the end state.**

### The mechanism, and the design note that predicted it

`DetonationChoreographer._fade_in_soot()`'s own header rejects a `soot_strength`
shader uniform because it *"would first wipe every existing scorch on the map to
clean and bring the lot back, so an older crater would visibly flash"*, and claims
the ring-code ladder *"fades only the cells this blast is changing, and touches
nothing else."*

**The second half is false, through the entry list rather than the uniform.**
`DetonationPlanBuilder._phase_soot_wave()` walks the WHOLE-MAP soot snapshot — by
design, §"Scope is the whole map… so a pre-existing hole elsewhere keeps its
scorch" — and admits a cell when `alt != prev_alt` **OR** its soot code moved. A
blast changes occupancy, so it changes shadow, so the light bucket of a cell in an
old crater across the map moves; that cell enters the wave on the **alt** half of
that OR, **with its soot completely unchanged**, and the ramp lightens it to
near-clean and walks it back.

**The fix:** a cell whose scorch already equals its target is not ramped. Its
`alt` is still applied up front, so the light correction the wave carries still
lands; only the ramp is skipped, and only where it had no business.

```
red    (262,23,0) settled soot 26 -> 119 for frames 55..59, back to 26
green  [E-FUME] soot fade: 180 of 2 123 entry cell(s) already carry their
                 target scorch and are NOT ramped
       (262,23,0) settled soot 26 -> 26   for frames 55..59
```

**180 skipped, against 180 measured flickering — the same cells, counted twice by
two independent instruments.**

### 9.11d ⛔ AND P3 KILLED THE DEFECT OUTRIGHT TWO DAYS LATER — the guard is now INERT (2026-08-27)

Found while arming this same instrument for the soot storage reform's SS-0, and
recorded here because this is where anyone will come looking.

**§12's `PERF-P3` shipped default-ON on 2026-08-26 and structurally removed
§9.11a's mechanism.** Under `P3_CELL_BUCKET` (`voxel_renderer.gd:637`, ON unless
the env var says `0`), `encode_light_alt()` returns `alt_for_flip()` — **the
light bucket does not travel in the alternative id at all.** §9.11a's route in
was *"that cell enters the wave on the **alt** half of that OR"*, and a light
change can no longer move the alt. Only the soot half is left, which is the
correct half.

Two runs of one build, the Director's own repro (fabric gu (31,3), plywood gu
(35,3)), differing only in `INFILTRAITOR_P3`:

```
                  guard skipped (fire 2)   flicker gu 29-32   flicker gu 33-34
                                            (fire 1's block)   (fire 2's own)
P3 ON (default)      0 of 1 985                    0                106
P3 OFF             175 of 2 160                  175                 84
```

175 and 175, by two instruments sharing no machinery — the same double count this
section got at 180/180, reproduced on the P3-OFF side and **absent on the default
one**. Every flickering GU in fire 1's block reports `0 permanent here`.

**The guard is not deleted.** `INFILTRAITOR_P3=0` is a live diagnostic path and
the defect is real whenever it is taken; inert-by-default is not dead. What
changes is what may be claimed: **the flicker is no longer a live defect, and no
plan should cite it as one.** `SOOT_STORAGE_REFORM` §1.1b demotes its own §1.1 on
this measurement.

⚠️ **And the watcher's headline VERDICT lies for this question.** It printed
*"fire 1's region IS disturbed mid-flight"* in BOTH runs, because `TF_WATCH_GU =
3` reaches gu 34 — fire 2's own block. `_tf_watch_union`'s own comment says so.
**Read the per-GU histogram, never the verdict line.**

### ⚠️ Two residuals, both found by this and neither fixed

1. **The ALT still flickers.** Post-fix the same cells read `alt 9 -> 7 -> 9` over
   frames 55..59: the wave applies the plan's PREDICTED bucket, and something
   later restores the true one. A 2-bucket brightness wobble on an old crater is
   visible. Not the reported symptom, same family, unmeasured as to cause.
2. **The fire's map-wide final repaint lands INSIDE the blast's own soot fade.**
   From the green log, fire 2: `soot fade step 1/4 · 2/4 · 3/4 ·
   [BURN-PROF] final repaint 1 059 ms · soot fade step 4/4`. F6 made the fire fast
   enough to finish before the fade that started it. Ordering, and it is the most
   likely author of residual 1.

### 9.12 ❌ F9 IS DROPPED — its recorded blocker is moot, and the pre-cook is aimed at the wrong term (2026-08-24)

F9 was carried as *"the whole fire in the pre-cook. Blocked: `_build_soot_snapshot()`
takes `predict_weapon_cells` only, and a burn's holes are BLAST provenance."*

**That blocker describes nothing that still exists.** PERF-P2 moved the scorch into
its own per-cell plane, and `VoxelRenderer.warm_light_alts_for_gus()` mints on
`encode_light_alt(field.bucket_for(cell, level), decode_light_flipped(prev_alt))` —
**soot is not an input to it at all**. Warming "the sooty world" was never the thing
F9 needed, so the provenance objection cannot block it. The pre-cook has been
soot-free on purpose and correct that way since it was written.

**But measured on today's build (post-F8), the pre-cook does not pay.** Fire 1,
fabric at gu (31,3), `INFILTRAITOR_BURN_PRECOOK_STAGES=16`:

```
                          no precook     16-stage precook
  frames during the fire   1 865 ms         1 815 ms
  committing frames        5 x 137          5 x 133
  of them, MINTING         3 x 193          4 x 153
  final repaint            1 058 ms         1 058 ms
  ---------------------------------------------------
  the fire                 2 923 ms         2 873 ms
  the warm itself                —        + 1 201 ms
  what the player waits    2 923 ms       4 074 ms  (+39%)
```

50 ms is inside this harness's noise, and the warm costs 1 201 ms of stall inside
`start_burn()`. §8.16 called the pre-cook *"roughly break-even… kept as the
instrument that isolated the term, not as a fix"* — after F8 it is not even that.
**It stays env-gated OFF and F9 is dropped as specified**, not deferred.

### ⚠️ And the fire's largest term is now the FINAL REPAINT, which no pre-cook can touch

`INFILTRAITOR_REPAINT_PROFILE=1`, the same run:

```
[REPAINT-PROF] occupancy 30.6 · soot 154.7 · field.build 63.7 · apply 651.0 ms
[BURN-PROF]    final repaint 1 058 ms · corrected 1 492 of 205 381 cell(s)
```

**1 058 ms of a 2 923 ms fire — 36% of it, and the single largest term left.** Of
that, `apply_light_field()` is 651 ms walking every one of 205 381 placed cells to
correct **1 492 of them, 0.73%**. Pre-minting cannot shorten a walk; at best it
removes the one ~240 ms rebuild inside it (§8.15).

That walk is map-wide for one stated reason, MAT-PERF-02's: the scoped burn frames
leave a residue a scoped pass cannot fix, **and the cause of that residue is still
open and still MAT-PERF-03's** — 198 cells, every one on a negative (floor) level,
with scope size, a stale `_placed_by_gu`, field staleness and the apply's reach all
ruled out by measurement. Closing it is what would let the fire end scoped, and it
is worth ~650 ms per fire. **That is the fire's next item, not the pre-cook.**

### 9.11c ✅ RESIDUAL 1 IS NOT A DEFECT — the light is right at both ends, and a control run proves it (2026-08-24)

§9.11b left the alt wobbling `9 -> 7 -> 9` over frames 55..59 on the same cells
whose soot had just been fixed. Two readings, and both were plausible: the blast's
predicted bucket is wrong, or it is right and something later undoes it.

**Three measurements, in the order they were taken.**

**1. The blast's bucket is right.** `INFILTRAITOR_TWO_FIRES_ALT_PROBE=1` forces the
map-wide repaint — the authority — on the first disturbed frame and asks which way
it moves the disturbed cells:

```
59 cell(s) had a disturbed bucket on that frame · a full map-wide repaint then:
   0 RESTORED to the settled value, 59 left as the blast wrote them, 0 moved elsewhere
```

⚠️ The first version of this probe compared all 13 005 WATCHED cells and reported
"12 874 left as the blast wrote them" — a majority made almost entirely of cells
the blast never touched. **A control group that large drowns the measurement**;
it is scoped to the actually-disturbed cells now.

**2. The end state is right too.** `INFILTRAITOR_LIGHT_EQUIV_PROBE=1` on both
fires' final repaints: `[LIGHT-EQUIV] 205 381 cells, 0 differ` and `205 160 cells,
0 differ`. The `geometry_only` path agrees exactly with a full rebuild, so the
stale-cache hypothesis — the obvious one, and the one this probe exists to catch —
is dead.

**3. So the world changed twice, and a control run says so directly.** The two
readings differ on one thing: whether the burn that FOLLOWS blast 2 is what moves
the light back. Put blast 2 on a material whose flammability is 0 and the fire
leaves the sequence without anything else leaving with it — `_capture_two_fires()`
now tolerates a second blast that never ignites and says so, instead of aborting.

```
fabric gu (31,3), then BRICK gu (23,3) — a blast with no burn

  [TWO-FIRES-WATCH] 184 cell(s) disagreed — 0 FLICKERED, 184 changed for good
  [TWO-FIRES-SOOT]  NEAR FIRE 1: 157 changed — 0 soot codes, 157 alternative-id only
```

**Nothing flickers when there is no second fire.** The blast changes the distant
crater's light and it STAYS changed. In the plywood run the burn that followed
changed the world a second time and the light followed it back.

**Verdict: residual 1 is the light being correct at every instant**, not a stale
value and not a wrong prediction. What remains is a look question — a five-frame
brightness wobble on a distant crater — and it is the Director's, not a bug.

**And the control carries a finding worth keeping on its own:** a blast permanently
moves the light of a crater **eight GUs away** — 157 cells, alternative id only,
soot untouched. Light in this game is global, which is the fact F8's region
suspension trades against and the reason F1's global cadence was rejected on look.

**The soot fix holds in the control too:** `[E-FUME] soot fade: 184 of 1 768 entry
cell(s) already carry their target scorch and are NOT ramped`, and **0 soot codes
moved** anywhere near fire 1.

### ⏭️ What §9.11's family leaves open

| | item | state |
|---|---|---|
| 1 | **residual 2** — the fire's map-wide final repaint lands INSIDE the blast's own soot fade (`fade 1/4 · 2/4 · 3/4 · final repaint · fade 4/4`) | real, harmless as measured: step 4 writes `lighten = 0`, the true target. Ordering to tidy, not a defect |
| 2 | **§9.11** — `forget_ghost_record()`, still not reproduced | needs a capture that walks the agent; unchanged |
| 3 | **MAT-PERF-03** — the final repaint's 651 ms map-wide apply correcting 0.73% of cells | §9.12. The fire's largest remaining term |

## 10. THE STALL — the fire's longest frame, and what is actually in it (2026-08-24)

Director, 2026-08-24: *"visualmente me parece que está tudo ok. O problema é só
esse travamento mesmo, tem um dos frames que está demorando bastante."*

**Which frame, measured rather than assumed.** Across a whole fire the profiler
reports `frames during the fire: 21 · mean 88.8 ms · max 266 ms`, and then
`final repaint 1 058 ms`. **The map-wide final repaint is the longest frame in the
game by a factor of four**, and everything below is about that one frame.

### 10.1 ✅ It is the WALK — not the mint, not the writes, not the derivation

`INFILTRAITOR_APPLY_SPLIT_PROBE=1`, the fire's own final repaint, both fires:

```
205 384 cells · derivation 70.1 ms · apply 646.2 ms (96 written, 64 minted)
              · walk-only 608.8 ms · writes+mints 37.4 ms
205 163 cells · derivation 67.5 ms · apply 610.6 ms (254 written, 22 minted)
              · walk-only 613.8 ms · writes+mints -3.3 ms
```

**~610 ms of the ~640 ms apply is the walk**, and the pass writes **96 cells out of
205 384** — 0.05%. Every hypothesis this plan has spent months on — the TileSet
rebuild (§8.15), the mint count (§1.1b), the soot snapshot (§8.8) — is priced here
at 37 ms and −3 ms. Two samples, one negative: the writes and the mints are inside
the noise of the walk they sit in.

This also retires the pre-cook question for good (§9.12): **no amount of pre-minting
shortens a walk.**

### 10.2 🔴 MAT-PERF-02's TWO "RULED OUT" CAUSES ARE THE ACTUAL CAUSES

MAT-PERF-02 recorded the residue that forces the ending to be map-wide — 198 cells,
all on negative levels — and ruled out, by measurement: scope size, **a stale
`_placed_by_gu` (*"all 198 are IN the index and IN the scope"*)**, field staleness,
and the apply's reach. *"Which leaves `alt_id == prev_alt` or the mint, and neither
has been proven."*

It is neither. `INFILTRAITOR_BURN_RESIDUE_PROBE=1` runs a scoped ending, snapshots,
runs the map-wide one, snapshots, and asks of every disagreeing cell the two
questions that can explain it — **reading index membership BEFORE the full pass
rebuilds it**, which is the one ordering that makes a stale index look present:

```
fire 1   scope 94 GU · 47 cell(s) differ · 47 on negative levels
         NOT in _placed_by_gu before the full pass: 47 · indexed but OUT of scope: 0
         · indexed AND in scope: 0

fire 2   scope 87 GU · 72 cell(s) differ · 52 on negative levels
         NOT in _placed_by_gu before the full pass: 45 · indexed but OUT of scope: 27
         · indexed AND in scope: 0
```

**0 of 119 are indexed and in scope.** The residue is two causes, both previously
dismissed:

- **`_placed_by_gu` is rebuilt ONLY by `_apply_light_field_pass()`, and the scoped
  apply only ever READS it.** A cell placed since the last full pass — *a crater
  floor revealed by the blast is exactly that, and exactly a negative level* — is
  invisible to the scoped apply. It cannot be caught after the fact either,
  because by then the full pass has put it back in the index. That is how the
  original measurement got the answer backwards.
- **The board drifts wherever an earlier SCOPED apply did not reach.** Fire 2's 27
  out-of-scope cells sit at gu (29,3) — fire ONE's crater, six GUs away, moved by
  blast 2's light (§9.11c measured a blast moving a crater's light eight GUs off).
  Growing the ring count could never fix the unindexed majority, which is exactly
  why *"identical 198 at 3, 6 and 10 rings"* read as ruling scope out.

### 10.3 ⏭️ THE FIX THIS POINTS AT — the apply is driven by the field's own dirty set

`VoxelLightField.build(geometry_only = true)` **already computes exactly the set the
apply needs**, and then throws it away:

```gdscript
var stale: Dictionary = {}
if geometry_only:
    stale = _stale_cells(occupancy, soot)
...
for key in stale:
    _bucket_cache.erase(key)
    _static_factor_cache.erase(key)
```

`_stale_cells()` is derived by INVERTING what `_static_factor()` reads — Chebyshev 1
in XY and levels `L-2 .. L+1` around every occupancy change, plus exactly
`(cell, level)` for every soot change. Its correctness already has a standing gate:
`INFILTRAITOR_LIGHT_EQUIV_PROBE=1` reports **`205 381 cells, 0 differ`** on both
fires, which is the statement that a value can only change if its cache was
invalidated — i.e. **changed ⟹ in the stale set**, which is precisely the guarantee
an apply driven by that set requires.

So the proposal, for ratification rather than built:

1. `VoxelLightField` keeps its stale set and exposes it.
2. `VoxelRenderer.apply_light_field_cells(field, cells)` — the identical per-cell
   body, over that set instead of `get_used_cells()` map-wide. It touches
   `_placed_by_gu` not at all, so **cause 1 of §10.2 stops existing** rather than
   being patched.
3. `_placed_by_gu` becomes incrementally maintained at the placement site, so every
   OTHER scoped consumer (the shot, the blast) stops inheriting the same defect.
4. The gate is the probe that found this: stale-driven ending vs map-wide ending
   must differ by **0 cells**, or it does not ship.

**Expected: ~610 ms off the longest frame in the game**, with the walk falling from
205 384 cells to the low hundreds. Not built — §"No design decisions or new systems
without Director sign-off".

### 10.4 ✅ BUILT — the fire's ending walks the work, and the longest frame drops 72%

```
                        map-wide ending    stale-driven ending
  fire 1 final repaint       1 024 ms            282 ms
  fire 2 final repaint         984 ms            297 ms
  fire 1, frames + ending    2 773 ms          1 999 ms      -28%
```

**THE GATE, and it is the one that counts: `0 of 205 379 cell(s) differ from a
map-wide ending`, both fires**, measured in-process on the same boot by
`INFILTRAITOR_BURN_END_GATE=1` — snapshot after the stale-driven ending, force the
map-wide pass, snapshot again, count.

⚠️ **The pixel diff is NOT the gate here, and saying so is the point.** Two boots of
the SAME code differ by **22 967 pixels**; the A/B differed by 228. The 228 is
noise wearing a number — exactly what this project's own rule warns about — and the
cause is structural: `BURN_COMMIT_INTERVAL_S` is pinned in SECONDS, so without
`--fixed-fps` real frame times decide which voxels commit on which frame, and the
ending's own speed-up changes them (42 frames vs 40). The CPU gate compares cell
state rather than a rendering of it, on one boot, and is the stronger instrument.

### Three defects, each found by the gate refusing to pass

The first version failed by **200 cells**. Each fix was made only after the gate
named the cells that survived the previous one.

**1. `_placed_by_gu` was rebuilt only by the full pass** (§10.2). Now maintained
incrementally by `_index_placed()`, backed by a `_placed_index` membership set so
an incremental add is O(1). A cell-driven pass indexes what it visits, so the fix
cannot rot the index it stops rebuilding.

**2. The choreographer writes the board behind the light field's back** — 200 of
the first failure. `DetonationChoreographer` is documented as *"the ONLY place a
plan ever reaches `set_cell()`"*, and it writes the plan's own alternative and
scorch straight onto the layer. The stale set rests on *"a cell whose value changed
was invalidated in the field"*, which covers every change the FIELD causes and none
that a direct write causes. `VoxelRenderer.note_external_write()` is the writer
naming what it wrote; the next full-coverage apply unions it in and clears it.
**The map-wide walk WAS this bookkeeping, done by brute force every time.**

**3. `_stale_cells()` diffed the ring map and never the face triples** — the last 7.
Its own doc is right that soot reaches the BUCKET only through the jitter
exemption, but the renderer does not write a bucket alone: it writes
`face_soot_code()`, which reads `_face_soot`. A cell whose per-face triple moved
while its isotropic ring stayed put was invisible. Harmless while every apply was
map-wide and re-derived everything; silently skipped the moment an apply is driven
by the set.

### ⚠️ Two pre-existing findings this surfaced, both measured against a stashed HEAD

Neither is caused by this change — `grenade_then_shot` reports them identically
with the work stashed:

- **`[SHOT-SCOPE] 206 491 cells checked, 3 144 differ from a full apply`.** The SHOT
  path has the same defect family the fire just shed, and at 3 144 cells it is
  larger. §10.3's step 3 aimed at this; it is now the next item and it is a
  correctness bug, not only a perf one.
- **§9.11's dispatch figures no longer reproduce.** The plan records `grenade 0 →
  350 dispatch(es)`; the capture now reports **0**, and `the shot` reports 1 against
  3. Something between 2026-08-23 and today changed what that capture measures.
  The citation is stale and any argument resting on those numbers has to be re-run.

### 10.5 ✅ THE SHOT TAKES THE SAME ROUTE — 3 144 stale cells to 0 (2026-08-24)

`[SHOT-SCOPE] 206 491 cells checked, 3 144 differ from a full apply` was §10.4's
parting finding, verified against a stashed HEAD so it is not this work's doing.
**It is a correctness bug, not a speed one**: a GU scope answers *"repaint where I
hit"*, and the board's staleness is not confined to where anything was hit —
§9.11c watched a blast move a crater's light eight GUs away.

The shot's soot pass now runs off the same stale set the fire's ending does:

```
                              before      after
  SHOT-SCOPE, soot pass       3 144         0
  shot repaint (no probe)    81.7 ms    75.4 ms
```

**The speed is not the point and the numbers say so** — the GU-scoped apply was
already cheap. What changed is that the board ends where a full apply would leave
it, every shot, instead of accumulating.

### The seam this needed, and why it belongs at the placement site

`VoxelRenderer._set_voxel_cell()` now calls `note_external_write()`. Rule 8 makes
it the only way a Wall or Slab voxel reaches the tilemap, which is precisely why
the note belongs there and not at its callers: damage variants, re-renders after
destruction and the shot's own dirty pass all funnel through it, and none of them
move occupancy or soot in a way `_stale_cells()` could see. The three `erase_cell()`
sites are noted for the same reason.

### ⚠️ `include_soot` is a PRECONDITION on the stale-driven route

A soot-free field answers "clean" for every cell. That is right for the caller's
OWN GUs — it defers their scorch deliberately — and catastrophic anywhere else:
driven by the stale set it would assert clean across every sooted cell on the board
and wipe the map's scorch until the next sooty repaint. **That is the Director's
§9.11a symptom rebuilt from the other end.**

No caller does that today, and the measurement is what says so rather than the
reading: **0 soot-free scoped repaints in a whole two-fire capture**, because the
burn's one sits behind `BURN_SUSPEND_REGION_LIGHT` (F8) and never runs. That is a
reason to write the guard, not to skip it — F8 is one constant away from being off.

With the guard, the shot's FIRST pass (geometry, soot-free) keeps the GU route and
leaves 3 144 cells stale for a few frames; its SECOND pass (the soot pass) is
stale-driven and pays the whole debt. **The shot ends at 0.**

### Where the fire stands after all of it

```
  fire 1 final repaint   1 024 ms -> 280 ms      gate: 0 of 205 381 cells
  fire 2 final repaint     984 ms -> 295 ms      gate: 0 of 205 160 cells
```

## 11. THE STOREY RENUMBER — every level is non-negative, and the playable storey is 10

Director, 2026-08-24: *"seria melhor a gente só usar valores positivos e convencionar
que o andar 10 vai ser sempre o jogável… e temos até o andar 0 para criar
possibilidades de efeitos subterrâneos."*

⚠️ **The premise needed one correction first, and it was mine to make.** §10.2's
residue was reported as "47 of them on negative levels", which reads as the sign
being at fault. It was not: the probe's discriminator was `indexed=false`, and a
revealed crater floor is a *newly placed* cell that happens to live downstairs.
**Renumbering would not have prevented that bug.** What the SIGN actually cost was a
second store — `_voxel_layers` an Array, `_negative_voxel_layers` a Dictionary,
`get_layer()` branching between them, and every map-wide walk arriving in pairs.

**Done in two stages so the gate could isolate each**, and `PLAYABLE_STOREY = 10`,
`PLAYABLE_LEVEL = 80` are the only new constants. The ground stack becomes storey 9,
the walls become storeys 10, 11 and 12.

### 11.1 The gate had to be earned, and then widened

`INFILTRAITOR_CAPTURE_ACTION=level_census` dumps every placed cell (source, atlas,
alternative, soot) plus each layer's z_index, modulate and position, sorted;
`INFILTRAITOR_CENSUS_LEVEL_SHIFT=-80` subtracts the offset so a renumbered board
compares line for line. Two boots of unchanged code are byte-identical — proven
before use, because §10.4 had just measured the pixel harness at 22 967 px of noise.

⚠️ **And the first version of it could not have failed.** It recorded what each cell
HOLDS and not where its layer SITS. `_build_voxel_layer_node()` positions a layer at
`-VOXEL_STEP_PX * level`; left absolute, every layer would draw eighty steps up and
the whole board would leave the screen **with a byte-identical census**. Found by
accident while chasing something else. `pos=` was added and the baseline re-taken.

### 11.2 A RENDER LEVEL IS NOT A TEXTURE ROW, and this cost four separate bugs

The lesson repeated until it was written down: several axes are *indexed by level*
and have their own origin at zero. `VoxelRenderer.relative_level()` is the single
conversion, and each of these was found by the gate refusing to pass:

| axis confused with a render level | measured cost |
|---|---|
| `BakedTileLookup` sheet rows — 4 call sites, the last being the MAIN wall path inside `_set_voxel_cell()` | 2 112 cells absent, **no warning, no error** — a resolve that finds nothing places nothing |
| `EarthVariantSelector` / `_generic_variant_for` — level-keyed hashes **pinned by invariant B4** | 52 224 floor cells with a different source id |
| light height classes (`0/2/4/6` were heights above the walkable plane, not levels) | 13 668 cells with a wrong light bucket |
| `OcclusionSet`'s level → screen Y | 2 112 cells ghosted that the baseline never ghosts |

`bake_compositor.gd`'s `start_level` and `room_builder`'s junction `level_start`
were correctly left alone — texture space, origin zero. The second of those was
shifted and reverted once the consumer was read: `_mirror_index(level, SHEET_ROWS)`.

### 11.3 What the CENSUS could never have caught, and the selftests did

The census is a boot snapshot: it detonates nothing and moves nobody. The suite
found a **real production bug** the gate is structurally blind to —
`DetonationPlanBuilder._phase_slices()` computed `base_level` from
`start_storey * LEVELS_PER_STOREY` unshifted, so `simulate_container_damage()` saw
offsets of ~80, the ring lookup ran off its table and **a grenade damaged nothing at
all**. Its siblings in the junction branch and in `OcclusionSet` went the same way.

`PassageQuery` groups by `floor(level / LEVELS_PER_STOREY)`, so the storey it answers
to moved with the levels — a deliberate, Director-ratified semantic change, and
`room.gd`'s caller asks for `PLAYABLE_STOREY` now instead of `0`.

⚠️ **A blanket regex over the fixtures was wrong twice**, and the suite caught both:
`_synthetic_voxels()` numbers its voxels 0..N literally, so those calls keep
`base_level = 0`. A fixture's own numbering is what it must match, not the map's.

### 11.4 Result

```
205 704 placed cells · 32 layers · shift -80 · 0 script errors
██ IDENTICAL to the pre-renumber baseline ██
   source, atlas, alternative, soot, z_index, modulate AND layer position

selftests 39 clean / 0 failed · invariants ✅ · fire end gate 0 and 0
```

---

## 12. THE ABLATION — what turning each system OFF actually buys (2026-08-26)

**The Director's hypothesis, in their words:** *"eu tenho a impressão que esse
problema decorre do nosso sistema de iluminação e/ou baking system, combinados.
Então eu queria testar desligando essas duas features por default."*

Built as `INFILTRAITOR_NO_LIGHT=1` (new — the light-side counterpart of the
`INFILTRAITOR_FAST_BOOT=1` that already existed for the bake) and run against the
Director's own two-grenade repro, fabric at gu (31,3) then plywood at gu (35,3),
through `INFILTRAITOR_CAPTURE_ACTION=two_fires`.

**The hypothesis is HALF right, and the wrong half is wrong in the opposite
direction: the bake is not a cost, it is a saving.**

### 12.1 The fire, six configurations, one board

| run | fire | designed span | wall clock | worst frame | mints |
|---|---|---|---|---|---|
| **baseline** | 1 | 1.38 s | **2 211 ms** | **271 ms** | 301 |
| | 2 | 1.18 s | **2 079 ms** | **275 ms** | 451 |
| vfx-noop | 1 | 1.37 s | 2 095 ms | 236 ms | 301 |
| | 2 | 1.17 s | 1 959 ms | 248 ms | 451 |
| bake-off | 1 | 1.41 s | 2 109 ms | 244 ms | **59** |
| | 2 | 1.20 s | 1 914 ms | 242 ms | **60** |
| **light-off** | 1 | 1.38 s | **1 319 ms** | **59 ms** | **0** |
| | 2 | 1.20 s | **1 140 ms** | **68 ms** | **0** |
| bare (light+bake off) | 1 | 1.38 s | 1 389 ms | 218 ms | 0 |
| | 2 | 1.21 s | 1 224 ms | 220 ms | 0 |
| floor (+vfx-noop) | 1 | 1.37 s | 1 383 ms | 221 ms | 0 |
| | 2 | 1.18 s | 1 181 ms | 218 ms | 0 |

**Read the first two columns together.** The fire's schedule is designed to span
1.38 s and the shipped build takes 2 211 ms to play it — a **60% overshoot**. With
the light system removed it takes **1 319 ms**, which is the designed span and
nothing else. *The overshoot is the light system in its entirety.*

### 12.2 And the whole event, not just the fire

`E-WAVE`'s own numbers say it more sharply than the fire's do. The destruction
wave applies 2 820 cells in **five frames** and its own apply is ~1.1 ms:

⚠️ **The wave is INSIDE the fire's window, not before it.** `start_burn()` is
called from `_start_detonation_sequence()` immediately after the commit and
BEFORE the wave animates, so the burn profiler's window already contains
`E-WAVE`'s frames. A first draft of this section added the two and overstated the
event by ~1 s; the table below does not.

| phase, fire 1 | shipped | light off | |
|---|---|---|---|
| `E-PLAN` census (before the burn) | 386 ms | 397 ms | — |
| fire window (contains the wave + the soot fade) | 1 928 ms | 1 319 ms | −32% |
| ↳ of which `E-WAVE`, 5 frames, 2 820 cells | **1 021 ms** | **173 ms** | **−83%** |
| final repaint (after) | 283 ms | 0 ms | −100% |
| **census → settled** | **~2 597 ms** | **~1 716 ms** | **−34%** |

The sharpest line is the indented one. The wave applies 2 820 cells in five
frames, its own apply is ~1.1 ms a frame, and it holds **1 021 of the fire's
1 928 ms** — better than half the event, to do 6 ms of its own work. Everything
between its five frames is the light repaint.

### 12.3 ⚠️ THE BAKE IS NOT A COST — TURNING IT OFF COSTS ~900 ms PER BLAST

`INFILTRAITOR_FAST_BOOT=1` takes the mints from 301 to 59 and buys **5%** of the
fire's wall clock. That much was only a null result. This is not:

```
E-PLAN census, bake ON :  386.1 ms · 414.0 ms
E-PLAN census, bake OFF: 1325.9 ms · 1110.7 ms   (+243%)
```

Four samples across two runs, both fires, consistent. The mechanism is D33 Part
4c: with the bake off, every decal that would have been resolved from a
pre-composited atlas is composited **live** in `_set_voxel_cell()` instead. It is
also where the bare runs' otherwise unexplained 218–221 ms worst frame comes from
— light-off ALONE peaks at 59 ms.

**So "turn both off" is not a direction. Turning the bake off is a regression.**

### 12.4 The VFX are a frame-rate problem, not a duration problem

`INFILTRAITOR_VFX_DRAW_NOOP=1` more than doubles the frame rate during the fire
(87.6 → 39.4 ms/frame, 22 frames → 46) and moves the wall clock by **5%**. This
independently re-confirms §8.8 and the standing note that MultiMesh *"buys frame
rate, not wall clock"* — and it means simplifying the effects, which the Director
explicitly offered (*"nenhuma granada faz isso na vida real"*), would not shorten
a single event.

### 12.5 ⚠️ AN IDLE FRAME IS 32 ms MORE EXPENSIVE WITH THE LIGHT ON

The number no existing section predicts. A **non-committing** frame of the fire
runs no light code at all — `BURN-PROF` prices the whole of `_process` on those
frames at ~0.5 ms — yet:

```
non-committing frames, shipped  :  17 x 72.3 ms
non-committing frames, light off:  25 x 40.4 ms
```

Thirty-two milliseconds a frame, on frames that do nothing, recovered by removing
a system that does not run on them. The board carries **49 947 TileSet
alternatives** when fire 1 starts and ~0 under the ablation, so the suspect was
the alternative count itself — §2's thesis, reached from an angle nothing in this
plan had measured from.

### 12.6 ✅ P3 IS THE WHOLE ANSWER — measured, not argued

`INFILTRAITOR_P3=1` is the discriminator §12.5 asked for: the light system stays
whole and correct, and only the minting goes to zero. It does not just explain the
idle frame. **It recovers the entire ablation, everywhere except the final
repaint.**

| fire 1 | shipped | **P3 on** | light OFF |
|---|---|---|---|
| `E-WAVE` (5 frames) | 1 021 ms | **168 ms** | 173 ms |
| committing frames | 5 x 140 ms | **6 x 51 ms** | 6 x 51 ms |
| non-committing frames | 17 x 72.3 ms | **26 x 40.2 ms** | 25 x 40.4 ms |
| worst frame | 271 ms | **58 ms** | 59 ms |
| fire wall clock | 1 928 ms | **1 352 ms** | 1 319 ms |
| final repaint | 283 ms | **281 ms** | 0 ms |
| **census → settled** | **~2 597 ms** | **~2 033 ms** | ~1 716 ms |

Every row lands on the ablation's value to within noise **except the final
repaint**, which P3 does not touch. **P3 buys −22% of the event and −79% of the
worst frame with the lighting intact** and its data verified per-cell at 0
disagreements in 205 704 (§8.22 step 1). Take the final repaint out — §10.3's
route is what sharpens it — and P3 is within 3% of the full ablation.

**The residue is the final repaint, and only that.** 281 ms of it survives P3
because it is a map-walk, not a mint — §10.4 already took it from 1 024 ms to 283
and §10.3's stale-driven route is what is left to sharpen.

### 12.7 What this settles, and what it does not

**Settled:**
- Turning the light system off is not a direction to ship — it is the measurement
  that priced it. `INFILTRAITOR_NO_LIGHT=1` stays as an instrument, default OFF.
- Turning the BAKE off is a regression (§12.3) and must not be pursued.
- Simplifying the VFX buys frame rate and no wall clock (§12.4).
- **The whole lighting bill is recoverable without touching the design**, and the
  code that recovers it is already written.

**Not settled — and it is the ONLY thing between here and the win:** §3.3's floor
residual. P3's cell recovery is 96–100% correct on walls and **82% on the floor**,
which is 92% of the pixels on screen; the misses are a ±1-cell boundary effect,
characterised in §3.3 and NOT explained. §8.18's named lead is dead and §8.20
separates the two residuals. **That defect, alone, is now worth ~0.56 s per
detonation on top of a worst frame cut from 271 ms to 58.**

---

## 12.8 🔎 §3.3's FLOOR RESIDUAL — three hypotheses dead, the gate exonerated, the bug localised (2026-08-26)

Director's call after §12.7: attack the residual rather than tune the cadence.

**Baseline re-taken on current HEAD first**, because every number in §3.3/§8.18/§8.22
predates the storey renumber (2026-08-24), which moved every layer's Y:

```
judged 893 145 px · INSIDE 732 442 (82.007%) · OUTSIDE 160 703
L79 (floor) 81% (822 643 px) · L80 98% · L81 100% · L82 98% ...
```

**Byte-identical to §8.18.** The renumber changed nothing here, and the parity
alternation across wall levels survives it. Deterministic across three boots.

### What is now DEAD, each killed by a measurement rather than an argument

**1. ❌ float32 precision — the hypothesis the shader's own comment records.**
Debug paint **mode 5** (new) paints `|q - round(q)|` for `q = v_vertex - local`,
the quantity `floor(q + 0.5)` is about to round. Ground-truth-free by construction.

```
FLOOR n=822 643 · residue byte 0-31: 100.0%
WALL  n= 98 957 · residue byte 0-31: 100.0%
```

**The residue is zero everywhere, on both surfaces.** The rounding is nowhere near
a boundary, so no amount of snapping could ever have helped — which retroactively
explains §3.3's snapping attempt moving the gate by 0.02 points. `quad_tl` is an
exact integer. It is simply the WRONG exact integer.

**2. ❌ Atlas origin off-grid.** `debug_atlas_alignment()` infers alignment from
each SOURCE's declared `margins` and `region + separation`. `debug_tile_atlas_origins()`
(new) stops inferring and reads `margins + coords * (region + separation)` for every
**placed cell**, histogrammed mod (32, 36), per level. **Not one cell off-grid.**

**3. ❌ Multi-cell atlas spans.** A tile spanning several atlas cells would make
`mod` wrap in the quad's INTERIOR, invisible to every check here. Measured
`get_tile_size_in_atlas()` per placed cell: **every tile is 1×1.**

### ✅ AND THE GATE IS EXONERATED — §8.18's decision is withdrawn on evidence

§8.18 stopped letting the gate block P3 because it compares the shader against a
*reconstruction* of Godot's draw rect, so a disagreement accuses both. **A
reconstruction-free test settles it.** Every pixel recovering the same cell must
fit inside ONE quad (38.4 × 43.2 screen px at this zoom). No model of ownership,
no rect, no camera:

```
FLOOR: 2 450 distinct recovered cells · 1 325 OVERSIZED (54.1%)
       worst — cell (204, 74) spans 65 x 39 px = 1.69 quads
WALL :   478 distinct recovered cells ·     8 OVERSIZED (1.7%)
       worst — 1.04 quads, i.e. rounding
```

**The shader really does hand one cell to pixels from two different quads.** The
gate was right; §8.20's suspicion that §8.18 was wrong is confirmed.

### Where the bug IS — the `mod` boundary, on a clean enrichment curve

Debug paint **mode 6** (new) paints `local` itself. Distance from the nearest
`mod` boundary against the failure mask, floor only:

| window | share of ALL wrong px | wrong-rate NEAR | wrong-rate FAR |
|---|---|---|---|
| 0.5 px | 13.6% | 44.5% | 17.8% |
| 1.5 px | 36.4% | 40.9% | 14.9% |
| 4.0 px | 74.1% | 34.0% | 8.7% |
| **8.0 px** | **95.4%** | 25.7% | **3.2%** |

Monotone in both directions. **95% of the floor's wrong pixels sit within 8 px of a
`mod` boundary, and a true interior fragment is wrong only 3.2% of the time.** A
scanline dissection of the worst cell shows it directly: `local.x` jumps −17.12
between two tiles while the recovered cell does not change, leaving two `quad_tl`
values **18 layer px apart — which is not a lattice vector**, so at least one of
them is not a real quad origin.

### The structural correlate of floor-vs-wall

`debug_tile_atlas_origins()` also inventories the texture behind each placed cell:

```
LEVEL 79 (floor): { (32, 36): 8 704 · (4096, 1152): 57 344 · (4096, 180): 4 608 }
LEVEL 80 (wall) : { (4096, 2376): 2 232 · (4096, 108): 1 016 · (4096, 72): 8 · (4096, 36): 32 }
```

Every region is (32, 36) and every texture size is an exact multiple of the atom,
so this is not a misalignment. It is a **density** difference: the floor is a
continuous field of heavily overlapping quads, so most of a floor tile is covered
by its neighbours and a large share of its *visible* fragments are the thin slivers
at its own edge — exactly where `mod` is ambiguous. A wall shows large
uninterrupted faces, so its edge fragments are a small fraction of its pixels.
That is why the same shader is 98% on walls and 81% on the floor.

### ⏭️ OPEN — the fix needs a decision, and it is not a small one

`local` is `mod(UV / TEXTURE_PIXEL_SIZE, atom_size)`, and `mod` is **discontinuous
at the region boundary**. A fragment that belongs to region R but samples at or
past `R + 32` folds to ~0, and `quad_tl` lands one quad width away.

**The definitive fix is to stop deriving `local` from the atlas at all** and carry
the quad's origin from the vertex shader as a `flat` varying — exact, no `mod`, no
residue, no boundary. **One obstacle is real and is stated rather than waved at:**
which corner is the provoking vertex is driver-dependent, and the four candidate
corners are `quad_tl + {(0,0), (32,0), (0,36), (32,36)}`. The lattice constraint
(`qx ≡ 0 mod 16`, `qy ≡ 0 mod 8`, matching parity) rejects the two that differ in
Y — but **(32, 0) IS a lattice vector** (it is `e1 - e2`, i.e. cell delta (+1,−1)),
so geometry alone cannot disambiguate X. That ambiguity is the same one the bug
exploits, and it needs a decision rather than a guess.

## 12.9 ✅ FIXED — the quad's corner is carried FLAT, and the gate reads 100.000% (2026-08-26)

§12.8 localised the bug to `mod`'s discontinuity at the atlas region boundary and
named one obstacle to the obvious fix: carrying the quad origin from the vertex
shader means depending on WHICH corner is the provoking vertex, which is
driver-dependent, and the lattice cannot disambiguate X because **(32, 0) is
`e1 - e2`** — a legitimate cell step of (+1, −1).

**The fragment can decide what the lattice cannot.** Relative to its own quad's
TOP-LEFT a fragment always sits in [0, 32) × [0, 36). So a negative component of
`v_vertex - v_corner` can only mean the provoking vertex was the right (or bottom)
corner:

```glsl
varying flat vec2 v_corner;                 // vertex(): v_corner = v_vertex

vec2 corner_shift = vec2(
    (v_vertex.x - v_corner.x) < 0.0 ? atom_size.x : 0.0,
    (v_vertex.y - v_corner.y) < 0.0 ? atom_size.y : 0.0);
vec2 quad_tl = floor(v_corner - corner_shift + 0.5);
```

No `mod`, no atlas arithmetic, no `local` in the recovery path at all — and
therefore no boundary for a fragment to fall the wrong side of.

### THE GATE, AND TWO INDEPENDENT CONFIRMATIONS

```
before:  judged 893 145 px · INSIDE 732 442 (82.007%) · 313 claims naming an EMPTY cell (28 455 px)
after :  judged 921 600 px · INSIDE 921 600 (100.000%) · OUTSIDE 0 · on empty cells 0
         every level 100% — L79 (floor) included
         VERDICT: PASS
```

⚠️ **A green gate is not proof, and the denominator moved**, so it was checked
twice more, both reconstruction-free:

- **Bounding box per recovered cell** (§12.8's own test): floor **1 325 oversized
  → 0**, walls **8 → 0**. Not one recovered cell spans more than one quad.
- **The empty-cell claims.** 28 455 px used to name cells that do not exist; now
  **zero**. A wrong recovery had to invent cells, and there are none left to invent.

### ✅ AND P3's PICTURE IS NOW CORRECT — on an EARNED comparison

§8.19 gated P3 off because its picture was wrong (165 754 px, 17.985%, max channel
delta 105). ⚠️ **The boot capture cannot judge this** — two identical boots measured
**3 366 px apart** (the agent, the fog and the temporal lights all move), a noise
floor no small difference reads through. The gate's frame is deterministic by
construction, so `p3_gate_plain.png` is captured there, before any debug paint:

```
CONTROL  P3 off vs P3 off :     0 px   <-- the diff is EARNED
TEST     P3 off vs P3 on  :   415 px (0.0450%) · max channel delta 3
```

**Max channel delta 3 is one FACE-READ-03 residue step** — the documented,
expected consequence of the multiply moving from an 8-bit-quantised modulate into
float, which this shader's own uniform note predicts. It is not a defect.

### The win, re-measured with the fixed shader

| fire 1 | shipped | **P3 on, recovery fixed** |
|---|---|---|
| `E-PLAN` census | 386 ms | 388 ms |
| `E-WAVE`, 5 frames / 2 820 cells | **1 021 ms** | **171 ms** |
| committing frames | 5 × 140 ms | **6 × 53 ms** |
| non-committing frames | 17 × 72.3 ms | **25 × 40.1 ms** |
| worst frame | **271 ms** | **58 ms** |
| fire wall clock | 1 928 ms | **1 320 ms** |
| final repaint | 283 ms | 287 ms |
| **census → settled** | **~2 597 ms** | **~1 995 ms** |

Identical to §12.6's numbers, which were taken with the recovery still broken —
minting was already zero there, so the fix costs nothing and buys correctness.

**§3.3 and §8.22 are CLOSED.** What is left of the light's bill is the final
repaint (~287 ms), which is a map-walk and not a mint; §10.3's stale-driven route
is where that gets sharpened.

### The look pass — and ⚠️ THE FILMSTRIP CANNOT JUDGE THIS, which is itself the answer

Director asked for a filmstrip with P3 on. Built, `--fixed-fps 60`, one detonation
at gu (13,5), 24 frames, P3 off and P3 on. **A third strip was run as a control**,
P3 off against P3 off, because the two sides come from separate boots:

```
CONTROL  P3 off vs P3 off :  25 855 px (1.26%) · max delta 200
TEST     P3 off vs P3 on  :  24 939 px (1.22%) · max delta 218
```

**The control is LARGER than the test.** Two runs of the SAME code differ more
than P3 differs from no-P3, so the whole 1.22% is boot-to-boot noise and P3 is
invisible in the strip. (The sheets are also LANCZOS-downscaled ~2:1 from a 0.55
centre crop, which amplifies any sub-pixel difference — a second reason not to
read a number off them.) The per-frame diff climbing monotonically 258 → 1 737 px
from frame 0 onward is the fire and smoke accumulating, not P3: frame 0 is
*before* the blast and already differs.

**The precision answer stays §12.9's**: 415 px at max channel delta 3 against a
0-px control, on the gate's deterministic frame. The strips are for the eye.

⏭️ **P3 still defaults OFF, and flipping it is a Director call.** Everything that
can be measured now says yes — the gate PASSes at 100.000%, the picture differs by
one residue step, the strip cannot tell the two apart, and the win is ~600 ms per
detonation with the worst frame cut 271 → 58 ms.

## 12.10 ✅ P7b BUILT — and §8.6 was pointing at the wrong overlay (2026-08-26)

Director's call after §12.9: attack P7b. Re-measured the ceiling on the **P3**
build first, because every number in §8.8b predates it:

| fire 1 | VFX full | VFX noop (ceiling) | |
|---|---|---|---|
| mean frame | 42.7 ms | **16.1 ms** | **−62%** |
| fire wall clock | 1 368 ms | 1 322 ms | −3% |

§8.8b's shape holds and is now sharper: **the VFX are 62% of the frame and 3% of
the duration.** Which is exactly the Director's remaining complaint — the stall is
gone (§12.9) and what is left is sustained frame rate.

### ⚠️ §8.6's "ember first — the largest population" is WRONG, measured

`VfxDrawProbe` gained a per-overlay split (and a puffs/sparks split inside
`SmokeSparkOverlay`, which the overlay-level row could not show):

| population | ms/frame | cmd/frame | share | primitive |
|---|---|---|---|---|
| **SmokeSpark/puffs** | **13.26** | 1 325 | **68.9%** | `draw_circle` |
| EmberOverlay | 4.61 | 450 | 24.0% | `draw_circle` ×2 |
| DebrisOverlay | 1.29 | 139 | 6.7% | |
| ShrapnelOverlay | 0.05 | 5 | 0.3% | |
| SmokeSpark/sparks | 0.02 | 46 | **0.1%** | `draw_line` |

The puffs are the largest by three to one. Ember is second. **Both draw the same
primitive**, so P7b became ONE shared helper (`CircleField`) serving both — 92.9%
of the cost — rather than the per-overlay rewrite §8.6 sketched.

**And the sparks are the control that names the mechanism.** 46 `draw_line`
commands cost 0.4 µs each; 1 325 `draw_circle` commands cost 10 µs each. **The
cost is per-VERTEX, not per-command** — a filled circle is a tessellated polygon
rebuilt on the CPU every frame, a line is two vertices.

### Result

```
                        before          after       
_draw() total        19.24 ms/frame   3.53 ms/frame   -82%
  SmokeSpark/puffs   13.26            1.51            -89%
  EmberOverlay        4.61            0.64            -86%
fire 1 mean frame    42.4 ms          19.5 ms         -54%   (24 -> 51 fps)
fire 1 worst frame   55 ms            31 ms
fire 1 wall clock    1 315 ms         1 328 ms        unchanged, as predicted
```

⚠️ **THIS DOES NOT REDUCE OVERDRAW, and §8.8b says otherwise.** The same circles
cover the same pixels with the same blend, so GPU fill is untouched; what P7b
removes is CPU submission. §8.8b's "MultiMesh also removes [the rasterization]"
is wrong and is corrected here. Fewer or smaller particles remains a LOOK
decision and remains the Director's.

### ⚠️ 12.11 The pixel gate §8.6 asked for is UNREACHABLE on a detonation — and why

§8.6: *"0 differing pixels at `--fixed-fps 60` against a same-binary control"*.
Two identical filmstrip boots differ by **219 234 px**. `INFILTRAITOR_RNG_SEED`
was added to pin the particle rolls and **did not help, because the RNG was never
the variable**: the prediction cook is budgeted in MILLISECONDS
(`job.step(cook_budget_ms)`), so it takes 42, 43, 47 or 48 frames depending on the
machine, and the blast lands on a different frame index every run. **Tile N of one
sheet is a different MOMENT than tile N of another.** No frame-indexed diff over a
detonation can be a gate while that is true.

So the gate moved to the question the conversion actually raises — *does the
MultiMesh path put the same pixels on screen as `draw_circle`?* —
`INFILTRAITOR_CAPTURE_ACTION=circle_gate`: 220 fixed circles, overlapping,
additive, fractional centres, radii 4–26 px, both paths in ONE boot, no fire and
no cook to drift.

```
220 circle(s) · 158 835 px painted by the probe (vs a hidden-probe frame)
0 of 921 600 px differ (0.0000%) · max channel delta 0
VERDICT: PASS — pixel-identical
```

⚠️ **The first run of this gate PASSED VACUOUSLY and the lesson is kept.** The
probe was a `Node2D` under Room at local (50, 50); Room is world space and the
capture camera sits near canvas origin (−2144, −2611), so every circle was drawn
thousands of pixels off screen and the gate compared two identical frames of empty
floor — **0 differing pixels, VERDICT PASS, nothing tested.** Found by looking at
the capture. The probe is now a `CanvasLayer` (screen space) and the gate counts
the pixels the probe actually painted against a hidden-probe frame, failing loudly
under 10 000. A gate that cannot fail is not a gate.

### ⏭️ What P7b leaves

`DebrisOverlay` is now the largest remaining row (1.29–2.42 ms, 37–57% of what is
left of `_draw`). That is P7c, and it is small. The frame's remaining ~19.5 ms is
no longer dominated by the VFX.

## 12.12 ✅ P7c, and the frame's last 15 ms found by ELIMINATION (2026-08-26)

**P7c — debris.** The dust specks are `draw_circle` and are the overlay's bulk
(`cmds += specks.size()` against one command per chip), so they took the same
`CircleField`. The CHIPS stayed on `draw_colored_polygon` — a rotated quad is not
a circle and at one command each they are not what costs.

```
DebrisOverlay   1.29 -> 0.09 ms/frame   (-93%)
_draw() total   3.53 -> 2.38 ms/frame
```

### Where the rest of the frame is NOT

With P3 + P7b + P7c a fire frame is ~17.6 ms. Two candidates the plan had named
were tested and both are dead:

- ❌ **The voxel layers.** §8.7 recorded them at 19.0 ms/frame and reserved an
  item for them "after P7". `INFILTRAITOR_HIDE_VOXELS=1` (new) removes all 32
  layers: the fire frame goes **19.5 → 19.7 ms — no change at all.** That 19.0 ms
  was measured when the TileSet carried ~50 000 alternatives; **P3 already paid
  it.** The frame probe's ~12 000 draw calls per frame are real and cost ~4.4 ms
  of engine `render cpu`, which is not where the time is either.
- ❌ **The overlays' `_process` aging walks**, which nothing had ever measured —
  every previous number in `VfxDrawProbe` was about `_draw()`. Now split:
  SmokeSpark 0.95 · Ember 0.20 · Debris 0.01 · Shrapnel 0.00 = **1.16 ms/frame.**

Accounted for a 17.6 ms fire frame: `render cpu` 4.4 · VFX `_draw` 2.38 · VFX
`_process` 1.16 · voxel layers ~0. **The ~9 ms remainder is the board's own idle
baseline** (§`_frame_probe`'s doc measured the idle board at 8.9 ms), not
anything the fire adds. That is a different, larger subject than this wave.

⚠️ **A measurement was discarded, and the reason is recorded.** A quadrant-size
sweep was launched and its second run booted while these overlay files were being
edited — the log is full of parse errors from a half-written tree. Killed and not
used. Never edit source while a capture is in flight.

## 12.13 ✅ THE WAVE IS SHIPPED — P3 and P7b default ON, and the last stall is named

Both flip to **default ON**, opt OUT with `INFILTRAITOR_P3=0` / `INFILTRAITOR_P7B=0`.
The opt-outs are kept rather than deleted: they put both sides of the A/B in ONE
binary and one map, which §5.5 argues is stricter than stashing and re-running.

**One boot each, same binary, the Director's own two-grenade repro:**

| fire 1 | opt-out (the old build) | **shipped** | |
|---|---|---|---|
| `E-WAVE`, 5 frames / 2 820 cells | 1 018 ms | **108 ms** | **−89%** |
| mean frame | 86.1 ms | **17.6 ms** | **12 → 57 fps** |
| worst frame | 267 ms | **31 ms** | **−88%** |
| committing frames | 5 × 138 ms | 6 × 21 ms | −85% |
| fire wall clock | 1 979 ms | **1 320 ms** | −33% |
| final repaint | 288 ms | 286 ms | unchanged |
| **fire, end to end** | **2 267 ms** | **1 606 ms** | **−29%** |

Fire 2 agrees: 2 079 → 1 416 ms, worst frame 273 → 44 ms.

Gates at the flip: lint ✅ · selftests **39 clean / 0 failed** ✅ · invariants ✅ ·
cell recovery **100.000% PASS** ✅ · circle gate **0/921 600 px PASS** ✅.

### ⏭️ THE ONE THING LEFT, and it is P5 rather than a loose end

The final repaint is the last stall in the event, and it is now fully attributed:

```
occupancy 39.0 · soot 154.2 · field.build 65.6 · apply 23.9 ms   = 283 ms
```

**The APPLY is solved** — 23.9 ms of 283, down from the 646 ms §10.1 measured. What
remains is the map-wide DERIVATION, which §8.7 explicitly kept out of P7 and which
P5 owns: the soot snapshot alone is 154 ms (§8.7 recorded 146 — unchanged).

⚠️ **And it is not a scoping problem.** `_repaint_voxel_light_buckets_scoped()`'s
own note says why: D24 derives soot from which voxels are absent ANYWHERE, so a
scoped snapshot becomes a SECOND soot producer — the exact drift SOOT_MASTER_PLAN
§1.2 found between two of them. The real answer is an INCREMENTAL soot map
maintained as voxels are destroyed instead of re-derived from scratch, and that is
a new system rather than a tuning pass. **Director's call before it is built.**

---

# 13. THE CONSEQUENCE BLOCK — the ending becomes a beat (2026-08-26)

§12 closed the wave: the event is fast and the frame is cheap. §13 is what the
Director asked for once it was, and it is **look first, performance second** —
though the two turned out to be the same work.

## 13.1 The measurement that shrank the job

P5's target was the final repaint's soot snapshot, 154 ms. Split before rewriting
(`INFILTRAITOR_SOOT_SPLIT=1`):

```
index walk        126 ms   (215 432 voxels visited to find ~2 000 seeds)
build_soot_field   17-35 ms
```

**82% is the WALK, not the propagation.** So the BFS stays and only the index
becomes incremental — a far smaller change than "replace the soot producer".

## 13.2 ✅ THE INCREMENTAL SOOT INDEX

`Voxel.set_damage()` records the cell KEY of every real damage transition;
`_build_soot_snapshot()` keeps the walk's result and folds only the dirty cells.

⚠️ **KEYS, NEVER VOXEL REFERENCES.** A static Array of Voxels would resurrect the
ownership cycle removed on 2026-08-17 and the leak gate would fail on it.

```
index walk     151 -> 1.2 ms
soot           154 -> 18.9 ms
final repaint  286 -> 149 ms
               (occupancy 39.3 · soot 18.9 · field.build 67.2 · apply 24.0)
```

Invalidated on **map load, room reset and perspective change**.
`INFILTRAITOR_SOOT_GATE=1` re-derives everything the slow way and compares.

### ⚠️ Two real defects, both found by the gate refusing to pass

- **A CELL KEY IS NOT UNIQUE.** A junction column's voxel can share
  `(grid_pos, level)` with a slice's. The walk has always tolerated it —
  `cell_to_voxel` keeps whichever is walked LAST while the seed lists append
  EVERY qualifying voxel — so a key can be a seed because of voxel A while the
  map holds voxel B. The first index stored one voxel per key and answered for
  the wrong object: **3 destroyed junction voxels reported as intact.** Collision
  keys are now recorded and the fold is the OR over all voxels at the key.
- **The index was stored with PREDICTIONS folded in.** `predict_weapon_cells`
  describes holes that do not exist yet; caching them as the board caches a guess
  about the future.

## 13.3 ✅ THE CONSEQUENCE BEAT — and it reverses F1 on new grounds

Director: *"o jogo por turno não exige que a física seja aplicada imediatamente…
a alteração no cenário por uma atividade do agente recebe ainda mais destaque ao
final do evento, assumindo como uma demonstração das consequências da ação."*

⚠️ **F1 was REJECTED on look in §9.8** — freezing light mid-event read as a bug.
What changed is not the freeze but that something is now DONE with it.

⚠️ **And most of the freeze already existed.** Measured: there is NO light repaint
during the destruction wave at all, and F8 already froze the fire's region. What
was actually wrong was the SOOT's position.

```
decals -> holes -> expose -> debris -> embers -> smoke
-> the fire burns out
-> soot arrives    (0.5 s — 4 steps x 8 frames)
-> light arrives   (2.0 s — 12 steps x 10 frames)
```

Order is the point: **soot, then light.** Scorch is what the light reveals.

## 13.4 ✅ THE HOLE OPENS CLEAN, AND THE DECALS LEAD IT

Director: *"a cena nasce suja e depois fica limpa… quando cavamos o buraco já tem
uma fuligem sendo aplicada imediatamente."*

**Correct, and §13.3's beat is what exposed it.** `expose` and the decal entries
carried a `soot` field and wrote it the instant the front reached the cell, so a
hole opened already scorched — then the end ramp lightened those same cells and
walked them back. Before the beat the fade ran seconds earlier and hid the wipe.
The wave now writes CLEAN and the scorch exists in exactly one place.

⚠️ **`KIND_RADIUS_BIAS` IS INVERTED FROM WHAT IT SAID.** `destroy` led at −0.60
with the marks following at −0.30/−0.20, so a hole opened into un-marked
neighbours and the dents caught up behind the front — *"não podem ser uma segunda
wave que entra depois"*. Now `dented` −0.70, `cracked` −0.65: a cell is already
marked when the hole beside it opens.

### The light ramp, and the refactor deliberately NOT done

The ramp lets the existing repaint compute the answer and **replays the
transition** — record where the moving cells are, let the normal path run, record
where they ended, rewind, walk across. Splitting
`_repaint_voxel_light_buckets()` into derive/apply halves would have been the
"clean" way and was refused: that function is the most heavily measured in
`room.gd` and every note in it is a number. Nothing is presented between the
apply and the rewind, so the final state never flashes.
Measured: **709 cells moving of 3 377, derive 147 ms.**

⚠️ **The ramp only exists under P3** — intermediate buckets go to the cell plane,
which is where the bucket lives only once it has left the alternative id. With
P3 off it applies instantly and says so rather than pretending.

## 13.5 ✅ E-FRAG-02 — the metal leaves first

Director: *"mais escuros, e voar muito mais rápido para mais longe… o frame
negativo já tem que acontecer logo em seguida."* Colour (0.20,0.20,0.22) →
(0.05,0.05,0.06); velocity 400 → 1 600 px/s; reach 160-320 → 720-1360 px; a
subtle trail reusing the spark-streak shape.

⚠️ **The ORDER was inverted**: shrapnel spawned after all seven flash frames, so
the flash was over before a fragment existed. Metal now leaves first and the
negative peak lands one frame later (5 flash frames, not 7). Director's verdict
on the result: *"os estilhaços parecem ok."*

## 13.6 ✅ SAVE-01 — the plumbing, and what must never be in it

**No save system existed.** `SaveState` captures and restores `_base_damage` and
`_crater_floor_soot` as versioned, loud-failing JSON, with `clear_run_state()`
carrying the Director's *"limpar em caso de reset, morte"* in one place.

⚠️ **The incremental soot index is deliberately NOT saved.** It is a CACHE keyed
by live `Voxel` references; a saved copy would deserialise into pointers at
objects that no longer exist. It rebuilds on the first snapshot after a load.

Two process notes worth keeping: `validate()` is split from `restore()` because
the refusal path `push_error`s by design (B6) and `run_selftests.py` reads any
`push_error` as a suite failure — a test of the refusal would have reported the
suite broken while proving it worked. And a selftest's banner must contain the
literal `PASS`; *"all checks passed"* is not it.

---

# 14. ⚠️ WHAT §12 COST THE LOOK — the bill arrived the next day (2026-08-27)

**This section exists because §12 and §13 both shipped green and both broke
something no gate in this plan could see.** Neither was a regression in the
ordinary sense: the code did what it said, the measurements were honest, the
selftests passed. What changed was the meaning of numbers written down elsewhere.

## 14.1 The rule: frame cost is a unit, and this plan changes it

`DetonationChoreographer.front_frames` is the blast's duration knob and it is
denominated in FRAMES. §12 cut the cost of a blast frame from 86.1 ms to 17.6 ms.
The front's wall clock fell by the same factor and nobody re-tuned it.

```
ratified 2026-08-09:   5 frames x 86.1 ms  =  430 ms
after §12 shipped:     5 frames x 17.6 ms  =   88 ms   <- 4.9x shorter, silently
restoring the ratio:   430 / 17.6          =   24 frames
```

Measured on the real thing: the entire destruction front — decals, holes, expose,
debris, embers, smoke — occupied **5 frames / 83 ms** of a 60 fps filmstrip,
immediately behind a 5-frame strobe covering **99.4% of the screen**. The
Director's report was that the ordering of the effects could not be read; at 83 ms
there was no ordering to read. Fixed in `037ea0e5`.

**The instruction this leaves for anyone working in this plan: a change that
alters frame cost silently retunes every frame-denominated look value in the
project.** Before closing a performance block, grep for look values counted in
frames and re-derive them from the seconds they were ratified in.
`front_frames` was one. `soot_fade_frames_per_step` and the light ramp's
`frames_per_step` are the others, and both are already computed from seconds
(`consequence_soot_seconds`, `consequence_light_seconds`) — which is the pattern
to copy, not the exception.

## 14.2 §13's light beat ran for 2 s and painted almost nothing

`play_consequence_light()` skipped every cell whose origin bucket was
`BUCKET_UNWRITTEN`, on the reasoning that a sentinel is not a value to lerp out
of. True of the integer, false of the picture: `voxel_face_shading.gdshader`
**clamps 255 down to 11**, so such a cell is already drawn at full light.

```
of 661 changed: 640 UNWRITTEN (skipped the ramp), 21 rampable
```

⚠️ **And the skipped cells did not "arrive at the end" — they arrived at the
START.** `_repaint_voxel_light_buckets()` applies the real light to everything;
the rewind that follows is what puts the ramp's cells back. A skipped cell is
never rewound, so it keeps the repaint's value — and there is no `await` between
the two, so that change is presented inside the repaint's own frame, folded into
the last step of the soot ladder. **96.8% of the ratified beat was not a beat.**

```
ramp steps that paint:   3  ->  10
final frame vs control:  0 differing px
```

Fixed in `037ea0e5`. The destination is provably untouched — a control run with
only that fix reverted produced a pixel-identical final frame.

## 14.3 ⚠️ `INFILTRAITOR_HIDE_VOXELS` DOES NOT WORK, and §12 used it

It sets `layer.visible = false` inside `VoxelRenderer._build_voxel_layer_node()`.
In a real PLAYGROUND capture with `INFILTRAITOR_HIDE_VOXELS=1`, **the walls,
crates and floor are all still drawn.** Verified visually 2026-08-27, not
investigated further.

The instrument is listed in §12's kept-instruments block and was used to price
the voxel layers ("hiding all 32 moves the frame by nothing — P3 had already paid
it", §12.4). **That conclusion rests on an instrument that does not do what its
own note claims and should be re-measured before it is cited again.**

## 14.4 The measurement discipline that failed three times in one session

All three were numbers reported before they were checked. Recorded here because
this plan is the one that keeps producing them.

- **"21 572 px of light land in one frame."** ONE boot. Did not reproduce on any
  later boot of the identical build. §12.7 already states why — the cook is
  budgeted in milliseconds so the blast lands on a different frame index every
  run — and the rule was written in this plan and then broken by its own author.
- **"The fire never goes out — 26 933 px frozen for 8 s."** The mask was counting
  static scenery (wooden crates, a light cone). The real figure was 2 839 px, and
  it was not fire: it was the scene background showing through a floor whose two
  voxel layers had both been destroyed. Not a defect at all.
- **"It is an overlay, not voxels."** Rested on §14.3's broken instrument.

**The cheap guard for all three: diff each frame against the settled END state
rather than thresholding on colour.** Static scenery cancels for free, no mask
tuning, and it needs no change to the map.
