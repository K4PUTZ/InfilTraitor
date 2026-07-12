# TOP_TEXTURE_MASTER_PLAN
## Horizontal Facades, Textured Interiors & Bake Persistence — Master Plan v1.0

**Status:** Parts 1 & 2 ✅ CLOSED 2026-07-11 (Director visual ratification,
"ALPHA TOP TEXTURE" checkpoint). Part 1 was **reopened and re-closed the same
day** for the junction-column regression — see "Part 1 reopening" below.
**Part 3 remains explicitly BLOCKED** on the destruction system (no
implementation plan exists yet) — this master plan stays open at Part 3 only;
do not archive it. As-built bake canon:
`docs/technical/BAKE_SYSTEM_REFERENCE.md` §OVERLORD-FIX-01/02 and
§"TOP-JUNCTION-06".
**Baseline:** tag `verified/v0.5.1` ("Alpha Walls Textured") →
`verified/v0.6.0` ("Alpha Top Texture").

### Part 1 reopening — junction columns (TOP-JUNCTION-04 → 06), CLOSED 2026-07-11

The Director found, by manually inspecting a screenshot after Part 1 was marked
closed, that junction columns rendered with a **serrated silhouette** (only the
top faces solid) and, elsewhere, with **displaced** side faces. Both traced to a
single root cause and are now fixed (`TOP-JUNCTION-06`, Overlord direct
implementation, commit `ee2caaf`):

`_compose_junction_pages()` used the raw, unbounded run-axis projection of a
junction voxel (`col_x`/`col_y`, built by `room_builder.gd` per OVERLORD-FIX-02
— correct by design) directly as a pixel offset into the 1056 px plane image.
`Image.blit_rect` **silently clips** an out-of-range source rect, so a
half-face either baked blank (serration) or, at `col == 64`, read the mirrored
wrap strip at the wrong shear (displacement).

**The fix is reference-consistency, not a clamp.** `_compose_sheet_page()` —
the straight-run path — uses the *same in-range column* in both the horizontal
crop and the shear term, and a straight-run neighbour at distance `d` samples
`_mirror_index_1d(d, 64)`. A junction at distance `d` must sample that same
folded column to be continuous with its own neighbours; bounds-safety then
falls out for free (folded < 64 ⇒ source x ≤ 1024 < `PLANE_W`). This
**subsumes TOP-JUNCTION-04**, whose insight ("the same value in both terms")
was right but was satisfied with the *raw* value — self-consistent yet
unbounded.

Evidence (real bake, real map): junctions with blank side pixels **24/32 → 0**
real (the only survivors are the single `(0,7)` alpha-4/255 AA pixel that
`_compose_sheet_page()` produces identically on every straight run). Screenshot
diff: 4 056 changed pixels, confined to exactly the two reported columns.

**Two process notes worth keeping.** (a) `TOP-JUNCTION-05` shipped a completion
report whose pasted "fix" existed nowhere in the repo — its only code change
was a helper (`_get_shear_col()`) that was never called. Do not trust that
prompt's report; `TOP-JUNCTION-06` supersedes it. (b) The "displaced cement
columns" the Director reported *after* the fix turned out **not to be a code
defect at all** — the junction columns were correct. It was the TEXTURES map's
own layout (see `TEXTURES-3.0` below).

### TEXTURES map rebuilt to 3.0 (2026-07-11)

The 2.0 fixture was actively misleading: its four nested V-pairs were all
`storeys: 4`, each sitting 2 GU nearer the camera than the last — so in
isometric each nearer V's equal-height top rendered *lower* on screen and
exposed the one behind it, reading as "the concrete walls are shorter". And its
perimeter blocks were 2 GU thick, which extracts walls on both faces, reading as
"the outer wall has two layers at different heights". Both were pure layout.

3.0: 1 GU thick concrete perimeter + four isolated 3×3 GU towers (stone,
concrete, metal, wood), 3 storeys, clustered so all four are in frame at once.
**The 26 GU perimeter runs are kept deliberately** — they are the project's only
long runs and the only thing that drives junction column indices past the plane
width (`col_x` up to 208), i.e. the only thing that exercises the
TOP-JUNCTION-06 case. A fixture of 3×3 towers alone would silently stop testing
it.

---

## 0. Purpose & Scope

Extend the (now working, Director-ratified) continuous-plane facade bake from
wall side-faces to the remaining visible surfaces and lifecycle:

1. **Horizontal facades** — voxel tops of slices and junction columns read as
   a continuous "laje" (slab/ceiling) using the same facade files.
2. **Textured interiors** — destruction reveals logically-textured voxels,
   not a generic shell; horizontal slices of material volumes become the
   substrate for props (table tops, shelves).
3. **Bake persistence** — a content-addressed disk cache makes every boot
   after the first effectively instant, without shipping pre-baked packs.

**Founding insight (recorded so nobody re-litigates performance from fear):**
after baking, textured and flat-color tiles cost the GPU exactly the same —
all costs live in bake time (once), atlas memory, and download size. D12
(no per-frame procedural cost) is preserved by construction throughout.

## 1. Decision Register

| D | Decision | Status |
|---|---|---|
| D-TT1 | **MULTIPLY is the blend canon** — preserves voxel material color under facade detail; `MULTIPLY_LUMA_LIFT = 0.25` compensates darkening until the light/shadow projection system owns brightness | ✅ Ratified 2026-07-10, shipped in v0.5.1 |
| D-TT2 | **Tops phase 1 scope**: slice tops + junction-column tops only (junction top may continue either leg — "pode ficar pra qualquer lado"). Multi-GU volumes explicitly excluded from phase 1. Behind `BakeConfig.facade_tops` (dev default ON so the Director sees it; ratification decides the final default) | ✅ Ratified 2026-07-10 |
| D-TT3 | **Hybrid interior architecture**: exterior wall shells keep the continuous 64×32 plane mapping; interiors/props use a local-period atom set keyed (x%8, y%8, z%8) — 512 unique atoms per material, each carrying 3 faces (two sides + top). Preferred realization: **compose-on-demand at destruction time** (3 blits/atom, microseconds per event); the precomputed 512-page is the fallback if runtime atlas mutation proves awkward | ✅ Ratified 2026-07-10 (direction); realization choice = Operator finding, stop-and-report |
| D-TT4 | **B5 amendment**: "no re-bake on destruction" becomes "destruction may compose baked interior atoms from session-cached plane images; never per-frame, never silent-fallback (B6 unchanged)". The original B5 guarded against a cost explosion that the blit architecture eliminated | ⏳ PENDING — enters the context static cores only at this plan's closure, per the baton-pass protocol |
| D-TT5 | **Disk cache over shipped packs**: `user://bake_cache/` PNGs keyed by content hash (facade + canonical atom + bake code version). User textures (`user://textures` tier) make a runtime compositor mandatory anyway; shipped packs would create a second source of truth (pain #2). Offline pre-render is revisited only if measured numbers demand it | ✅ Ratified 2026-07-10 (in principle) |

## 2. Parts

### Part 1 — Horizontal facade (TOP-01)

A horizontal plane in iso is the facade rotated 45° and squashed 2:1. That
transform factors into **two strip-blit shear passes** — `(u,v) → (u−v, v)`
by rows, then `(x,y) → (x, y + x/2)` by columns — zero per-pixel work,
mirroring the side-face pre-shear architecture exactly:

- One "diamond-plane" image **T per facade** (built once per session, ~8 MB,
  session-cached beside P⁰/P¹; wrap margins mirrored like the side planes).
- Each atom's top = an axis-aligned 32×16 crop of T, pasted through a
  precomputed **diamond mask** (the top-face region above the side-face
  edges), replacing today's flat base-color fill when `facade_tops` is on.
- Continuity contract: along a run, top crops advance (+16, +8) in T exactly
  as atoms advance on screen → adjacent tops are seamless **by construction**
  (same overlap argument as OVERLORD-FIX-01; the byte-exact overlap-identity
  test pattern applies directly).
- Sheet keying is unchanged: top window u = col·16 along the run, v-band =
  row·16 (deterministic; cross-run band repetition accepted in phase 1, same
  standing as the side facade's world-position independence).
- Junction tops: continue either leg (D-TT2) — pick one, name it in code.

### Part 2 — Bake disk cache (BAKE-CACHE-01)

- Key: FNV-1a (reuse the project's pinned hash discipline, B4 spirit) over
  facade image bytes + canonical atom bytes + a `BAKE_CODE_VERSION` const
  bumped whenever compose logic changes.
- Store: `user://bake_cache/<key>.png` per composed page (sheets, junction
  pages excluded — they're map-dependent and cheap).
- Load path: cache hit = `Image.load_png_from_buffer`/`load()` + register
  (~50 ms total); miss = compose + save. Loud log either way
  (`[BAKE] disk cache HIT/MISS <key>`).
- Budgets: cold boot ≤ 1.5 s total bake; warm boot ≤ 150 ms for all pages.
- Invalidation is automatic by construction (content-addressed); a
  `clear_bake_cache` debug affordance for the Director.

### Part 3 — Textured interiors (INTERIOR-01, sequenced after destruction lands)

- The 512-atom local-period dictionary per material: atom (lx, ly, lz) ∈
  (0..7)³ carries LEFT half from P⁰ window at (lx-derived col, lz row band),
  RIGHT half from P¹ at (ly, lz), top from T at (lx, ly). All from the
  session-cached plane images — pure crops.
- Preferred: compose-on-demand when destruction exposes a voxel (D-TT3),
  appending tiles to a dynamic interior atlas source; precomputed page as
  fallback (one 4096×144 page, ~2.3 MB, ~150 ms per material).
- Horizontal slices of the dictionary = prop surfaces (table tops etc.) —
  consumed by the PROP system later; this part delivers the substrate only.
- **Blocked on:** the destruction system (MAP_MATTRESS §2.3 ladder, future
  phase). Do not prompt this part until destruction has an implementation
  plan; it exists here so the interface is designed before either side ships.

### Part 4 — Standing guards

- Perf ledger per wave: cold/warm bake ms + total atlas MB pasted in every
  completion report touching the compositor.
- Memory watch: pages currently ~12 × ≤9.4 MB worst case; Part 1 adds T
  images (~8 MB/facade); flag at 150 MB total.
- LINEAR_LIGHT / OVERLAY LUT variants remain parked (from v0.5.0, logged
  loudly at runtime); pick up only if the Director asks post-MULTIPLY-canon.
- Legacy-test debt (`baked_tile_lookup_test.gd`, `block_01b_baking_e2e_test.gd`)
  retired or rewritten in whichever prompt next touches their subject matter.

## 3. Prompt Sequence — as executed

```
Wave 1 (independent):  TOP-01  ·  BAKE-CACHE-01                    ✅ landed
  TOP-01's shear was skipped in practice (report certified PASS against an
  unsheared T) → escalated to a 4-prompt corrective sequence, one mechanism
  each (post-mortem: OVERLORD_CONTEXT prompt-sizing rule tightened):
    TOP-00-baseline (remove dead reverse-map code, restore green)  ✅
    TOP-SHEAR-01 (T-image two-pass shear, standalone contract test) ✅
    TOP-CROP-02 (consume T: diamond crops on sheet pages)           ✅
    TOP-JUNCTION-03 (junction tops from the X-leg's T)               ✅
  Director visual ratification: tops read as a continuous diamond-projected
  slab on TEXTURES, screenshot 2026-07-11.
Milestone-closure pass (2026-07-11, Overlord direct): MULTIPLY set as the
  shipped dev default (was TEXTURE_ONLY); disk-cache hash bug fixed (the
  function was mislabeled "FNV-1a" but never multiplied by the FNV prime —
  now delegates to the same constants as the canonical, B4-tested
  `FacadeSampler._fnv1a_hash()`, invalidating old cache files harmlessly);
  two dead BAKE-05-era test files deleted (2026-07-12 sweep);
  full suite re-verified green.
Wave 3 (blocked on destruction plan): INTERIOR-01 — NOT STARTED. No
  destruction system implementation plan exists yet; do not prompt this
  until one does.
Closure (deferred to Wave 3's completion): D-TT4 (B5 amendment) + permanent
  canon → context static cores + BAKE_SYSTEM_REFERENCE; plan archived only
  then.
```

**Known open item, not blocking:** disk-cache warm-boot budget (BAKE-CACHE-01
criterion 3) measures ~730–770 ms against a 150 ms target — PNG decode of
~20 MB across 8 sheet pages (2286–3175 KB each) is CPU-bound, not an I/O or
hashing problem (confirmed: hashing is µs-scale; `load_png_from_buffer` is
where the time goes). Options for a future pass: smaller per-page footprint,
a faster-to-decode format, or parallelizing page loads — none attempted yet,
none blocking Parts 1–2 closure since correctness (byte-identical round-trip)
is proven and cold-boot bake is already fast (~0.4–1.2 s).

Both Wave 1 prompts (and their corrective sequence) ran as Operator prompts
at **maximal explicitness** (standing trust level for this subsystem after
the 02-c incident): assertion-backed, probe-verifiable acceptance; completion
report appended to the prompt file with per-criterion verdicts including
NOT MET; numbers must satisfy their criteria arithmetically.

*Adopted 2026-07-10. Parts 1–2 closed 2026-07-11. Lives at
`PROMPTS/PLANNING/TOP_TEXTURE_MASTER_PLAN.md` — stays open at Part 3.*
