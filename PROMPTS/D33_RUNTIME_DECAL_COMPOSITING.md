# D33 — Runtime decal compositing over the real baked facade

**Status:** ✅ **VIABLE — the Part 0 kill was WRONG and is retracted (§10).**
The spike measured a screen-space cache key, which is the wrong key, and the
wrong key produced the wrong verdict. With a per-view key the cost amortises:
97% cache hit on returning to a view already seen. §9 is kept verbatim as the
record of the mistake; **§10 supersedes it.**

---

## 1. Why — the one thing this buys that nothing else can

Today a damaged voxel on a photographically baked wall **throws its baked pixels
away**. `_set_voxel_cell()` short-circuits every impact mark past the baked
lookup (`voxel_renderer.gd:1040,1052`) and falls through to the generic material
atom, so a bullet hole in a concrete facade renders as a flat grey cube with a
hole in it, sitting in the middle of a photographic wall.

That was correct when an impact mark was a whole pre-drawn atom — it had no way
to know what it was sitting on. Under D32 the mark is a **decal**, and a decal
composited per cell can be stamped onto that cell's own baked atom.

The file-count saving (97 PNGs) and the iteration-speed saving (no generator run,
no reimport) are real but secondary. **The facade preservation is the reason to
do this.**

---

## 2. What is true today — measured, not recalled

| Fact | Value | Where |
|---|---|---|
| Baked atom size | 32×36 | `BakeCompositor.VOXEL_ATOM_W/H` |
| Baked page | `PAGE_W` 4096 × (tile_rows × 36) | `bake_compositor.gd:54` |
| Page → TileSet source | one `TileSetAtlasSource` per page, `texture_region_size (32,36)`, tiles created per used coord | `VoxelRenderer.register_baked_atlas_page()` |
| Baked sources are **transient** | `_baked_source_ids` is cleared on every rebuild; **every rotation re-bakes** | `voxel_renderer.gd:524-529` |
| `BakeConfig.enabled` | **`true`** today (canon says flip to `false` before release) | `bake_config.gd:12` |
| Damaged cells already carry what `resolve()` needs | `process_dirty` passes `edge`, `voxel_xy`, `slice.face` | `voxel_renderer.gd:1438` |
| Alternative-id space | 1536 of 4096 used (12 buckets × 64 soot × 2 flips); light alts minted **lazily** | `voxel_renderer.gd`, `_ensure_light_alt` |

**Scale, measured on a real PLAYGROUND detonation (bomb index 0):**

```
one grenade:  wall dented 54 · wall cracked 44 · floor dented 99  = 197 cells
197 × 32×36 RGBA (4608 B) = 886 KB of unique composites, per grenade
```

That is the number the design has to survive, and it is why "one TileSet source
per damaged cell" is not an option.

---

## 3. The constraint nobody has priced yet

**Baked sources are rebuilt on every rotation, and damage persists across
rotations.** So the composite work is not paid once per detonation — it is paid
**again for every accumulated damaged voxel, on every camera rotation**.

Late in a mission at ~2000 damaged cells that is 2000 composites per rotation.
Rotation cost is already a tracked regression surface: VL-03-PERF moved light
alternatives to lazy minting precisely because eager minting dominated it.

**This is the risk that decides whether D33 ships at all, and it is unmeasured.**
Hence Part 0.

---

## 4. Part 0 — The measurement spike *(blocks everything; no code ships from it)*

Same discipline as `DESTRUCTION_MASTER_PLAN` Part 0. Throwaway branch,
throwaway code, three numbers.

**S1 — Cost of one composite in GDScript.** Build one 32×36 composite the real
way (read the baked atom region out of the page `Image`, `blit_rect` the
pre-sheared decal, clamp alpha to the substrate) and time 1000 of them.
*Needed because the shear decomposes into per-column `blit_rect` calls (16 for a
lateral face, 16+32 for a top face) — cheap in principle, unmeasured in
GDScript.*

**S2 — Reuse rate of baked atoms among damaged cells.** For a real detonation,
count `distinct (page, atlas_coords)` among damaged cells vs. total damaged
cells. A facade page has 64 atom columns with mirrored-repeat wrapping, so the
same atom may back many cells. **If reuse is high, a cache keyed on
`(page, atlas_coords, composite_name)` collapses the 197 into far fewer** and the
rotation cost in §3 largely evaporates. If reuse is ~1.0, it does not.

**S3 — Real rotation cost at scale.** Detonate N grenades, rotate, measure. Do
it at N = 1, 5, 15 to get the slope, not one point.

**Kill criterion:** if S1 × (cells after S2 reuse) exceeds **~150 ms** added to a
rotation at 15 grenades, the per-cell approach is dead in this form and the
fallback is §7.

---

## 5. Parts, assuming Part 0 clears

### Part 1 — The composite cache and its page
- One `TileSetAtlasSource` backed by a **dynamic page** (start 2048×2048 →
  64 cols × 56 rows = 3584 slots at 32×36), mirroring how baked pages already
  work rather than inventing a second mechanism.
- `DamageCompositeCache`: key `(page_idx, atlas_coords, composite_name)` →
  slot coords. Owns allocation, eviction (if ever needed) and the reset that
  `prune_baked_sources()` already does for baked pages.
- Reuses `register_baked_atlas_page()`'s exact registration shape so light/soot
  alternatives keep minting lazily through the existing path.

### Part 2 — The GDScript compositor
- Port `generate_voxel.py`'s three primitives: lateral shear
  (resize ×20/16 + per-column shift), top shear (H-shear then V-shear), and the
  B3 alpha clamp to the substrate.
- **The port must be proven equal, not assumed.** A selftest composites the same
  (substrate, decal, face) in GDScript and compares against the Python output
  byte-for-byte within a stated tolerance. This is the single highest-risk step:
  the Python side was verified numerically against the parametric
  `0 ≤ s,t < 1` region, and a silent divergence here is a visual bug with no
  error attached.
- Sub-pixel: `blit_rect` has no supersampling. Compose at 4× and downscale, or
  accept harder edges — decide against a real capture, not in advance.

### Part 3 — Wire it into the seam
- `_set_voxel_cell()`: for an impact mark **whose cell resolves to a baked
  atom**, take the composite path; otherwise keep today's generic path verbatim.
  The generic path stays the fallback forever — glass, `ground_*`, unbaked maps
  and `BakeConfig.enabled = false` all still need it.
- Half voxels: the carve is geometry, not a decal. The substrate for a DENTED
  cell is `baked atom masked by the kept polygons` + the cut face. The cut face
  has no baked source (it is interior) — it keeps the material's own side tone,
  exactly as `generate_half_voxel()` does today.

### Part 4 — Retire the pre-composited PNGs
- `composites/` is deleted wholesale (this is what ASSET-LAYOUT-01 was
  structured for). `materials/`, `halves/`, `decals/` stay — they become the
  runtime's inputs instead of the generator's.
- `generate_voxel.py` keeps producing `materials/` and `halves/`; its composite
  stage goes away.
- `VoxelRenderer.MATERIALS` loses the 97 generated entries and
  `impact_decal_names()` with them.

---

## 6. Kill criteria / what makes me stop and report

- Part 0 S3 over budget (§4).
- The GDScript↔Python equality test in Part 2 cannot be made to pass within a
  defensible tolerance.
- Any need to place a decal through anything other than `set_cell()` — that is
  **inviolable Rule 8** and ends the approach, not the rule.

---

## 7. Fallback if Part 0 fails

Keep pre-composited PNGs for the **generic** path (today's behaviour, unchanged)
and composite **only baked cells** at runtime, lazily, capped at N per frame with
the uncomposited remainder showing today's generic atom until it catches up.
Uglier, but it buys the facade preservation without paying it on every rotation.

---

## 8. Acceptance

- A real capture of a bullet hole and a blast dent **on a photographically baked
  concrete wall**, showing facade texture continuing around the mark — the thing
  that does not exist today. Side by side with the same shot before the change.
- Rotation timing at 1 / 5 / 15 grenades, before and after, from a real run.
- `run_selftests.py` clean, including the Part 2 equality test.
- `project_lint`, `check_invariants`, `gen_codemap --check` clean.
- Rule 8 untouched: every voxel still reaches the tilemap through `set_cell()`.


---

## 9. Part 0 result — measured 2026-08-03, and the verdict

Spike ran on the real PLAYGROUND with the real bake enabled. All spike code
(`d33_spike.gd`, instrumentation in `test_zone_controller.gd` and `room.gd`) was
reverted; nothing shipped, exactly as Part 0 specified.

### S1 — cost of one composite, in GDScript, 1000 iterations

| Scale | Per composite | Notes |
|---|---|---|
| 1× (blit only) | **0.31 ms** | harder edges, no supersampling |
| 4× (compose big, downscale) | **1.10 ms** | smooth edges |

Feasibility itself is confirmed: reading a baked atom back out of its page
(`TileSetAtlasSource.texture.get_image().get_region()`), column-wise
`blend_rect` as the shear, and the B3 alpha clamp all work at runtime.

### S2 — reuse of baked atoms among damaged cells

One real grenade: **197 damaged cells, 197 of them baked, 0 on the generic
path.** Backed by **167 distinct atoms** and needing **190 distinct composites**.

**Reuse factor 1.04×.** By substrate pixel content it improves to 1.44× on the
98 wall cells (68 distinct hashes), which is still nowhere near enough. *The
cache that was supposed to rescue the approach saves essentially nothing.*

### S2b — does a composite survive a rotation? *(the decisive one)*

Substrate pixel hashes, before and after a rotation to E, same 197 damaged cells:

```
before:       68 distinct substrates
after:        68 distinct substrates
intersection:  0     ← zero
to recompose: 68 (all of them)
```

**0% overlap.** A re-bake under a new perspective genuinely re-samples every
facade run, so every damaged cell's substrate is new pixels. The cost is
therefore **per rotation**, structurally, and no cache key can avoid it — this
is not a tuning problem.

### S3 — rotation baseline

`_set_perspective()` = **1918 ms** today, with one grenade's damage on the map.

### Verdict

| Damage on map | Cells | Added per rotation @1× | vs. the 150 ms criterion |
|---|---|---|---|
| 1 grenade | 197 | 61 ms | under |
| 5 grenades | ~985 | 305 ms | **2× over** |
| 15 grenades | ~2955 | 916 ms | **6× over** |

At 4× it is 220 ms / 1.1 s / 3.3 s — over the criterion before the first
grenade finishes.

**The criterion in §4 is exceeded by 6× at the stated worst case, so the
approach is dead in this form.** I am not moving that criterion after the fact
to make the result pass: the baseline being slow (§S3) is context the Director
may weigh, not grounds for me to rewrite the bar I set before measuring.

### What is worth keeping from this

1. **`_set_perspective()` costs ~1.9 s.** That is the more interesting number
   this spike produced, and it is not a D33 problem — it is a rotation problem
   that existed before and will outlive this decision. Nobody had measured it.
2. **The §7 fallback remains technically viable** and was not killed: composite
   only baked cells, lazily, capped at N per frame. At 0.31 ms, 20 per frame is
   6 ms/frame and 2955 cells fill in over ~2.5 s of progressive catch-up, with
   damaged cells showing today's generic atom until they land. It buys the
   facade preservation without blocking the rotation — at the cost of a whole
   caching + progressive-fill subsystem for a visual that only appears on
   damaged cells of baked walls. **Not recommended on its own merits**; recorded
   so the option is not rediscovered from scratch.
3. Runtime compositing is confirmed *possible*. If the rotation re-bake ever
   stops being per-view — or if damage ever stops persisting across rotations —
   the arithmetic changes completely and this plan is worth re-reading.


---

## 10. Correction — the kill in §9 was wrong, and why

The Director pushed back ("*se a gente derrubar a rotação, daria pra colocar o
decal por cima dos baked voxels?*") and the pushback exposed a defect in the
spike, not in the idea.

### What §9 got wrong

S2b measured whether a damaged cell's substrate changes across a rotation. It
does — and I read that as *"a re-bake re-samples every facade run, so the cost is
per-rotation structurally."* **That inference does not follow.** The substrate
changes because rotating shows a **different physical face** of the wall, which
is correct behaviour, not resampling noise.

The cache key I planned in §5 — `(page_idx, atlas_coords, composite_name)` — is
**screen-space**. Screen-space keys cannot survive a rotation by construction, so
measuring one and concluding the approach is dead was circular.

### The measurement that settles it — N → E → N

Same 197 damaged cells, hashing each cell's substrate at each stop:

```
view N          68 distinct substrates
view E          68 distinct substrates      N∩E = 0    → 68 new composites
view N (back)   69 distinct substrates      N∩N' = 67  → 97% CACHE HIT
```

Substrates are **stable per view**. Returning to a view already visited costs
essentially nothing. The correct key is per-view (equivalently, base-space cell +
physical face + decal).

### Corrected cost

| Event | Cost |
|---|---|
| Rotation into a view that has not seen this damage | cells × 0.31 ms — e.g. **61 ms** for one grenade's 197 cells |
| Rotation into a view that has | **~0** (cache hit) |
| Steady state after all 4 views seen | **0** |

The 916 ms figure in §9 assumed every rotation recomposites everything. It does
not; it recomposites only what *that view* has not seen. **The kill criterion is
not breached.** Rotation does not need to be dropped.

### The real binding constraint, and it is a different one

Not time — **memory**. Worst case is `damaged cells × views visited × 4.6 KB`;
at 2955 cells across all four views that is **~54 MB**, against a bake budget
D21 already measured at 75.9 MB. Realistic figures are far lower (a wall face is
not visible from all four views), but this needs a cap with eviction, and that
cap — not the timing — is what Part 1 must design around.

### Still unmeasured, and it is a real design point

The composite cache must **outlive the room rebuild**. Rotation rebuilds every
Voxel from the MapSpec and clears `_baked_source_ids`; a cache that lives on the
renderer dies with it. It has to hang off something with room lifetime, keyed in
base space, and it must invalidate correctly when the *map* changes rather than
when the *view* does. Part 1 owns this and it is the next thing to prove.

### Process note

Two lessons, recorded because they cost a full spike:

1. **Measuring the thing you designed proves only that you designed it that
   way.** The spike validated my cache key instead of the question.
2. The Director's "*me parece tão trivial*" was the correct instinct. When a
   measured result says an obviously-simple thing is impossible, the measurement
   is the more likely suspect.
