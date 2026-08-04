# DETONATION_PERFORMANCE_MASTER_PLAN
## Closing the post-detonation stall — v1.0

**Status:** 🟢 **PERF-01 SHIPPED (commit `5c533d1`). PERF-02 SHIPPED
2026-08-04 — A1/A2/A3 + B1/B2/B3/B4 all landed, measured 3717ms → 1251ms on
the same real detonation.** Two ideas (colored-flash choreography,
real-explosion video overlay) remain in §6 as explicit future work,
deliberately deferred past PERF-02 by the Director.

**Follow-up round, same day (B3-2 / B2b), both Director-initiated:**
- **D13 — four soot tones, not three-stretched-over-five.** The Director
  rejected the flat outer band B3 shipped: *"não dá pra fazer 5 intensidades
  por 5 células? Me parece que dividir 3 por 5 vai dar mais trabalho do que
  fazer 5 por 5."* Right on the outcome, and it forced the real constraint
  into the open — see D13's row.
- **D14 — B2 retune.** Wood 0.6 → 0.75 and metal dent 0.3 → 0.35, walking
  back the two places the flat ×0.65 hurt. See D14's row.

**Two planned decisions did not survive contact with the code and were
changed during implementation — both measured, not argued:**
- **D6's byte-buffer rewrite of `paste_decal()` was a REGRESSION** (901ms →
  981ms) and was reverted; the real win in that function was elsewhere. See
  D6's own row.
- **D9's premise was false**: `Voxel.damage_is_blast` was NOT set on
  DESTROYED voxels, and a soot ring of 5 is not representable in the
  per-face encoding. See D9's own row.

**Companions:** `PROMPTS/ENGINE_PERFORMANCE_REVIEW.md` (closed 2026-08-03,
ROTATE-KILL-01 — a *different* stall, camera rotation, not detonation; that
review's Q1 "is destruction worth its resource cost" is partially answered
here in practice rather than argued). `docs/technical/BAKE_SYSTEM_REFERENCE.md`
(the baked-atlas/decal-compositing machinery this plan optimizes without
touching its architecture). `godot/scripts/tools/decal_compositor_equality_selftest.gd`
and `half_voxel_compositor_equality_selftest.gd` (the pixel-identity proofs
every Part A fix in §4 leans on instead of writing new ones).

---

## 1. Why

Director, 2026-08-04: detonating a grenade freezes the game for several
seconds — anything the player tries during that window appears to hang the
program. Two requirements, both hard: (1) it must never look like a hang
regardless of remaining raw cost, (2) the raw cost itself has to come down,
including by making the explosion physically smaller/less dense, not only by
making the same-size explosion faster.

This is the same class of problem `ENGINE_PERFORMANCE_REVIEW.md` named for
rotation — "almost every cost that matters is a discrete-event hitch, not a
sustained per-frame cost" — applied to a second, independent stall this
project has now measured for the first time. Nothing about that review's
Option B (killing rotation) touches this one: detonation still runs
mid-play, unconditionally, on the tap that matters most (destroying cover).

---

## 2. Decision Register

| D | Decision | Status |
|---|---|---|
| **D1** | Async, frame-spread rendering (`process_dirty_async()`/`process_dirty_slabs_async()`) instead of one synchronous batch, used only by the two player-triggered big-batch paths (`TestZoneController.detonate_active()`, `WeaponBenchController.fire_active()`). Guarded by `room._destruction_render_busy` against re-entrant detonate/fire. Sync originals untouched for `_tic_voxel_system()`/`_reapply_base_damage()`/`slab_render_selftest.gd`, none of which showed the stall. | ✅ Shipped, PERF-01 |
| **D2** | `_baked_source_image_cache` (source_id → CPU Image, read once via `Texture2D.get_image()`, reused thereafter) — the real dominant cost inside `_tint_baked_atom()` was a GPU→CPU texture readback repeated per voxel (194/197 redundant re-reads of the same handful of pages in one blast), not the pixel-tint math. | ✅ Shipped, PERF-01 |
| **D3** | `_tint_image_rgb()` — the get_pixel()/set_pixel() tint loop rewritten as a raw `PackedByteArray` pass. Proven pixel-identical to the loop it replaced by a new selftest (`tint_baked_atom_selftest.gd`), which is also where two non-obvious facts got nailed down: `Image.set_pixel()` on an 8-bit format **truncates** float→byte (not round-half-up), and GDScript's 64-bit float arithmetic can disagree with the engine's internal 32-bit Color quantization by 1/255 at rare boundary values — both measured, not assumed, same discipline as the D33 Part 2 selftest's own tolerance. | ✅ Shipped, PERF-01 |
| **D4** | ✅ **Shipped.** Measured: 197 uploads/876ms → **5 uploads/8.1ms**. One correction to the plan below: the flush also runs BEFORE each frame yield in the two async paths, not only at the end — an un-uploaded slot samples transparent, so batching purely to the end of the pass would have made every damaged voxel invisible for the ~2s the async spread takes, trading a freeze for a hole. Original text: Batch the damage-composite texture upload: `ImageTexture.update()` currently re-uploads a whole 2048×2048 page on **every** new tile, even when several new tiles land on the same page in one blast (measured: 197 uploads, most redundant). Split `DamageCompositeCache.store()` into "blit + mark page dirty" and a new `flush_dirty_pages()` that uploads once per touched page, called at the end of `process_dirty()`/`process_dirty_slabs()` (both sync and async). | 🔵 Planned, PERF-02 (A1) |
| **D5** | ✅ **Shipped.** Measured: 362ms → **17.2ms** across the same 459 masked ops. `half_voxel_compositor_equality_selftest.gd`'s mismatch counts are byte-identical before and after (12/620, 41/641, 23/591, 8/574) — the rewrite is numerically the same image, not merely a passing one. Original text: Precompute `HalfVoxelCompositor`'s polygon masks once (the polygon set is fixed and small — `CUT_PLANE`, `KEPT_RIGHT_FACE`, `KEPT_TOP_HALF`, `SUNK_TOP`, `KEPT_SW_BAND`, `KEPT_SE_BAND` + mirrors), replacing the per-call, per-pixel `_point_in_polygon()` + get/set_pixel with a cached boolean mask + byte-buffer copy. Geometry/point-in-polygon logic untouched. | 🔵 Planned, PERF-02 (A2) |
| **D6** | ⚠️ **Rejected by measurement, replaced.** The byte-buffer rewrite was built exactly as specified and made the function **SLOWER**: 901ms → 981ms across the same 285 calls. Cause, measured after the fact by timing the pre-resize separately: `paste_decal()` is dominated by the 4×4 supersample ARITHMETIC (~845ms), not by pixel fetch, and in GDScript replacing one native `get_pixel()` call with ~10 interpreted byte/LUT operations costs more than it saves. No pixel-access mechanism can fix an arithmetic-bound loop. Reverted to the original get_pixel()/set_pixel() body verbatim. **Substituted** (same Part A discipline — mechanism only, identical output): the per-call Lanczos pre-resize is now cached by (decal identity, native size). Measured: resize 133.8ms → **5.7ms**, `paste_decal()` total 972ms → **774ms**; `decal_compositor_equality_selftest.gd` reports `max_channel_diff=1, 0/911` both before and after, identical. Original text: `DecalCompositor.paste_decal()` — replace `work.get_pixel()`/`dst.get_pixel()`/`dst.set_pixel()` with raw byte-buffer reads/writes, same coordinates/supersampling/premultiplied-alpha math, byte-for-byte. This is the file's own documented "single highest-risk step" (Lanczos + resampling numerics) — no new selftest needed, `decal_compositor_equality_selftest.gd` already compares real Python-reference fixtures pixel-by-pixel and is the correctness gate. | 🔵 Planned, PERF-02 (A3) |
| **D7** | ✅ **Shipped.** Measured on the real blast: `affected_slices` 14 → **6**, `affected_floors` 42 → **24**, `paste_decal` calls 285 → **133**. Original text: `frag_grenade.json` rings: 4 → 3 (`ring_multipliers` `[1.0, 0.7, 0.35, 0.1]` → `[1.0, 0.6, 0.2]`). Shrinks BFS wall/roof reach and floor crater radius together (`crater_max` already derives from `n_rings`). Director-set number, not a guess. | 🔵 Planned, PERF-02 (B1) |
| **D8** | ✅ **Shipped at the planned values**, plus a consequence the plan did not foresee: the new numbers broke two selftests that encoded EARLIER Director statements — wood fell to 59% destroyed against a hardcoded `>=70%` ("quase toda destruída"), and metal's dent_factor (0.5 → 0.3) landed exactly level with earth's untouched 0.3, breaking a strict-ordering check on a tie that is actually correct. Director ruled (2026-08-04): keep ×0.65, update the tests. Both were rewritten to assert the PROPERTY rather than one session's numbers — wood's threshold moved to 55% AND a new assertion pins wood as the highest destroy_factor in the table; the dent check now reads the live factors and requires equal factors to produce equal counts. Original text: `material_resistance_table.gd`: scale `destroy_factor`/`dent_factor`/`crack_factor` down **together**, ~×0.65, for concrete/stone/metal/wood — not `destroy_factor` alone. Flagged to the Director before planning it in: lowering only `destroy_factor` shifts more voxels into `dent_factor`/`crack_factor`, which is exactly the expensive decal-composite path (D4-D6) — scaling all three together reduces total voxel churn instead of just relabeling it. | 🔵 Planned, PERF-02 (B2) |
| **D9** | ⚠️ **Shipped, after TWO of its premises turned out false on the real map.** (1) *"`Voxel.damage_is_blast` already distinguishes bomb vs. weapon damage"* — **it did not, for holes.** `set_damage(DESTROYED)` was called with no `from_blast` argument on every bomb path, so every crater read as firearm damage; since holes are exactly the BFS seeds, the first implementation was completely inert (925 sooted voxels with the wider radius, 925 without — byte-identical). Fixed by passing `true` at the three bomb DESTROYED call sites. (2) *"run it at a wider radius (`blast_soot_rings := 5`)"* — **5 rings are not representable**: `VoxelLightField.encode_face_soot()` packs each face into 2 bits (0/1/2 real, 3 = CLEAN), so rings 3-4 would clamp to CLEAN and render as no soot at all. Director ruled (2026-08-04): keep 3 intensities, spread them over 5 cells. Implemented as an additive `intensity_rings` parameter on `derive_soot_rings()` (defaults to `n_rings`, so every pre-existing caller is bit-identical). Measured result: grenade 925 → **1477** sooted voxels with rings r0/r1 UNCHANGED (156/306 top, 76/382 se, 49/379 sw) and only the faintest r2 growing (302→653, 279→673, 298→713); weapon-bench shot **unchanged** at 72 voxels, identical histogram. Literally "not stronger, just farther." Original text: Soot radius, not intensity, bomb-specific and wider — **correction of an earlier draft** that proposed a uniform stronger/darker soot; Director: "a fuligem não é mais forte, é mais distante... só pra bombas." `Voxel.damage_is_blast` already distinguishes bomb vs. weapon damage. `derive_soot_rings()`'s internal ring-merge (nearer hole wins) does not compose correctly across two separate calls (checked by reading it — the second call cannot lower an already-recorded larger ring), so the fix runs it twice into separate scratch snapshots (`weapon_cells` at the current radius, `blast_cells` at a wider one) and merges externally in `_build_soot_snapshot()` by taking the min ring per cell/face — no change to the BFS itself. | 🔵 Planned, PERF-02 (B3) |
| **D10** | ✅ **Shipped**, with one hardening the plan did not specify: the shallow plane's holes are snapshotted BEFORE the floor loop runs, not read inside it — iteration order over `affected["floors"]` is undefined, so reading mid-loop could see the crater this very blast just punched and let the deep plane through on the same explosion. Measured on one real detonation: `SLAB_3_5_FLOOR_-1 destroyed=60` and `SLAB_3_5_FLOOR_-2 SKIPPED (B4: no hole in the plane above yet)`, and a probe of the post-blast state confirmed that same GU would now expose **60/64** deep voxels to a NEXT blast. Original text: Floor cratering limited to one depth layer per explosion. Today `detonate_active()` damages both `FLOOR_TOP_LEVEL` (-1) and `FLOOR_DEEP_LEVEL` (-2) in the same blast (deep one reduced-radius, ring-0-only). Director: destroy only the top layer per explosion; a *later*, separate explosion over the same spot should be able to reach the deep layer once it's exposed. Implementation: for a deep slab, look up its shallow sibling (`Slab.make_id(gu_cell, Role.FLOOR, FLOOR_TOP_LEVEL)`) and filter to only the deep voxels whose shallow counterpart is *already* `not visible` (destroyed by a prior blast) before calling `apply_crater_damage()` — empty filter result skips the deep slab entirely (no reveal, no damage) for this blast. `WeaponBenchController.fire_active()` untouched — firearms never crater floors. | 🔵 Planned, PERF-02 (B4) |
| **D13** | ✅ **Shipped (B3-2).** Per-face soot moved from base-4 (3 tones + clean, 64 codes) to **base-5 (4 tones + clean, 125 codes)**: `top*25 + se*5 + sw`, `blast_soot_rings` 5 → 4, one cell of reach per available tone. The Director asked for five; **five does not fit**, and finding out why corrected my own earlier answer as well. The limit is NOT the alpha carrier the code rides in — that was the reason I first gave, and it is wrong: a 216-level carrier was probed on a real capture and decoded pixel-identically (0 pixels differing by more than 8). The real limit is the alternative-id ceiling, read from the engine rather than assumed (`TileSetAtlasSource.TRANSFORM_FLIP_H` = 4096): 64 codes → max id 1535 · 125 → 2999 · 170 → 4079 · **216 → 5183, over**. Anyone wanting the 5th tone should target the flip axis (it consumes half the id space via `SOOT_ALT_FLIP_BASE`, where Godot's own transform bit could carry it) — not the alpha packing. Measured result on the same index-0 blast, and this is the whole point of the change: rings r0/r1/r2 come back **identical to the pre-B3 original** (156/306/302) with the new r3 carrying 267, where B3's cap had instead ballooned r2 from 302 to **653** — a flat band twice as thick, exactly what the Director objected to. Weapon shot untouched: r3 = **0** on all three faces, r0/r1/r2 bit-identical. Minted tile alternatives went *down* (1175 new vs B3's 1378), since 4 cells of reach soot fewer voxels than 5. Face-separation guarantee re-verified across the larger code space: **0/1,890,000** collapses. | ✅ Shipped, B3-2 |
| **D14** | ✅ **Shipped (B2b).** Two of the flat ×0.65 results walked back, because a flat scale ignores what each material is supposed to READ as — and the two places it hurt are exactly the two the selftests caught. **wood destroy 0.6 → 0.75** (still a real cut from 0.9; measures 75% destroyed, so the 70% threshold the earlier round had lowered to 55% is **restored** rather than left loose) and **metal dent 0.3 → 0.35** (off its accidental tie with earth's untouched 0.3; prevalence ordering is strict again at metal 83 > earth 69 > concrete 34). Stone and concrete keep their scaled values. Real map: wood 31 → 39 destroyed per slice, metal 16 → 17 dents. Detonation timing unchanged at 1256.3 / 1245.9 ms against the committed 1250.9 / 1282.9 — the explosion stays small because B1's ring cut, not this table, did the reduction. | ✅ Shipped, B2b |
| **D11** | Colored-flash choreography: stage destruction in three explicit passes across frames (DESTROYED → DENTED → CRACKED), with a full-screen flash between each stage (red, then yellow, then the existing white `_flash_white()` tween) — "gives it time to think calmly," reads more organic, and batching same-type work per stage may itself recover some fps. Smoke (VFX-01) released as one coordinated moment *after* all three stages instead of trickling out per-voxel-erased as it does today; soot/light repaint deferred to run *while* the smoke is still rising rather than immediately. | ⚪ Deferred — see §6, not part of PERF-02 |
| **D12** | Real-explosion video overlay: convert the Director's alpha-background fire/smoke footage into an image sequence (same baked-flipbook idiom already used for grenade/collectible/weapon props), play it centered on the epicenter while the async destruction resolves behind it, and gate the reveal on whichever finishes later (animation or render) so nothing pops in visibly mid-cover. Confirmed technically sound — the flipbook's own `_process()` advance and the destruction coroutine are independent per-frame work, neither blocks the other. Director: both D11 and D12 happen together, in a **later session**, after PERF-02 ships — no video files handed over yet, no flipbook code started. | ⚪ Deferred — see §6, not part of PERF-02 |

---

## 3. What is true today — measured, not recalled

Real detonation (`INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate`, PLAYGROUND
concrete test wall), temporary `Time.get_ticks_usec()` instrumentation,
reverted after each measurement — same discipline as
`ENGINE_PERFORMANCE_REVIEW.md`'s Part 0.

**Before PERF-01:**

| Stage | Cost |
|---|---|
| Damage application (`BlastCalculator`) | 65 ms |
| `process_dirty()` (walls) | 1896 ms |
| `process_dirty_slabs()` (floors) | 1654 ms |
| `_repaint_voxel_light_buckets()` | 654 ms |
| **Total `detonate_active()`** | **4270 ms** |

Isolated: 99.8% of the `process_dirty*` time was inside
`VoxelRenderer._set_voxel_cell()` (965 calls that blast); confirmed **not**
VFX-01 (the same session's smoke/dust/spark/chip/ember feature, shipped
commit `bc6972c`) by disconnecting its signal handler entirely and
re-measuring: 4275 ms, statistically identical.

**After PERF-01, before PERF-02** (D1-D3 above):

| Run | Total |
|---|---|
| 1 | 2872 ms |
| 2 | 2875 ms |

Deeper breakdown of what remains (D4-D6's targets, same detonation):

| Cost center | Time | Share of ~2875ms |
|---|---|---|
| `DecalCompositor.paste_decal()` | ~975 ms / 285 calls | 34% |
| `ImageTexture.update()` (texture upload) | ~883 ms / 197 calls | 31% |
| `HalfVoxelCompositor` masked ops | ~362 ms / 459 calls | 13% |
| `compose_decal_voxel()`'s B3 clamp loop | ~15 ms / 197 calls | 1% |
| **Accounted** | **~2235 ms** | **78%** |

**After PERF-02** — same detonation, same harness
(`INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate`, PLAYGROUND), instrumented
and reverted the same way. The baseline row is this session's own re-measure,
not the older numbers above, so before/after come from identical
instrumentation:

| Stage | Baseline | +A1 | +A2 | +A3 | +B1/B2/B4 | +B3 (final) |
|---|---|---|---|---|---|---|
| **Total `detonate_active()`** | **3716.7 ms** | 2564.4 | 2221.4 | 2047.4 | 1247.6 | **1250.9 / 1282.9 ms** |
| damage application | 65.1 | 64.4 | 67.0 | 65.1 | 33.5 | 32.8 |
| walls (`process_dirty_async`) | 1559.5 | 947.2 | 822.8 | 713.5 | 227.9 | 229.4 |
| slabs (`process_dirty_slabs_async`) | 1436.3 | 886.0 | 668.1 | 620.8 | 344.7 | 340.9 |
| light repaint | 655.5 | 666.7 | 663.5 | 648.3 | 641.0 | 647.8 |
| `paste_decal()` | 972ms / 285 | 900/285 | 902/285 | 774/285 | 367/133 | 368/133 |
| texture upload | 876ms / 197 | **8.1/5** | 8.0/5 | 8.3/5 | 5.0/3 | 5.0/3 |
| half-voxel masked ops | 362ms / 459 | 328/459 | **17.2/459** | 17.2/459 | 13.3/273 | 13.3/273 |

**66% faster overall.** The three A-phase captures were verified
pixel-identical to the baseline capture (0 pixels differing by more than 8,
max channel diff ≤ 3 — the residue is VFX particle randomness), so the whole
Part A is a pure speed change with no visual consequence.

**PERF-03 — the light repaint, done 2026-08-04.** It was the single largest
stage after PERF-02 (~648ms, 52% of the total), and it was never in this
plan's scope; the Director called it next. Profiled the same way, the cost was
not where "repaint the lighting" suggests:

| Stage of the repaint | Cost |
|---|---|
| `build_occupancy()` | 15 ms |
| `_build_soot_snapshot()` | 69 ms |
| `VoxelLightField.build()` | 27 ms |
| **`apply_light_field()`** | **573 ms** |

and inside that: **106,847 cells walked to change 1,303 of them** (1.2%), with
`VoxelLightField.bucket_for()` alone accounting for **362 ms** — because
`build()` had just emptied the cache that would have answered for every
unchanged cell.

`_static_factor`'s own doc had already anticipated exactly this reuse
("dropping soot from it makes the cache MORE reusable... a detonation no
longer has to invalidate the light bucket of every voxel it scorches") — the
unconditional clear in `build()` is what defeated it. Fixed by giving `build()`
a `geometry_only` flag (default **false**, so map load / rotation / real light
changes keep the full clear) that instead invalidates only the cells the new
occupancy and soot actually touch. The invalidation neighbourhood is derived
from what the cached values really read — traced in the code, not guessed:
`_static_factor` reaches ±1 in XY and +2 in level through `surface_factor()`
and `_face_occlusion()`, so a change at (c, L) invalidates Chebyshev-1 XY over
levels L-2..L+1; soot enters only through the micro-jitter exemption, at that
one cell. `_lamp_cache` survives untouched, since a detonation moves no light
and never re-runs the shadow projector.

Result: `bucket_for` 362 ms → **42 ms**, repaint ~648 ms → ~328 ms, and the
whole detonation **1250.9/1282.9 ms → 920.7/925.3 ms** (-26%).

**Proven, not argued:** an equivalence probe snapshots every cell's
alternative after the fast path, forces a full rebuild, and diffs — **0 of
106,847 cells differ** on the grenade path and **0 of 106,459** on the weapon
bench, and the forced full rebuild independently reported `changed=0`.
Captures are pixel-identical to pre-PERF-03 ones (0 pixels over 8). The
weapon-bench capture initially looked different (273 pixels over 8) until a
control run of two IDENTICAL configurations showed the same magnitude (259) —
VFX particle variance, not staleness; the cell-level probe is what settled it.
The probe is kept as a standing env-gated tool
(`INFILTRAITOR_LIGHT_EQUIV_PROBE=1`) because it guards a regression nothing
else can see: widen `_face_occlusion()`'s sampling and the invalidation
neighbourhood silently becomes too small.

**Where the remaining time is:** the repaint still walks all ~107k cells to
find the ~1.3k that changed (~50 ms rebuilding the `_placed_by_gu` index,
plus the per-cell lookups). Scoping that walk to the blast's own GUs — the
`apply_light_field_gus()` seam VL-03 already built for temporal lights — is
the next available cut, and it needs the placement index kept current for
cells `reveal_floor_slab()` adds mid-blast.

The remaining ~22% is presumed spread across baked-lookup resolution,
decal-plan string matching, `_load_decal_image()`, and similar smaller
per-voxel overhead — no single further dominant cost center found; not
worth chasing before D4-D6 land and change the baseline.

**The load-bearing fact, same shape as the rotation review's:** detonation
is a discrete-event hitch tied to one player action (right-click → confirm),
not a frame-budget problem — the async spread (D1) already converts it from
"the game visibly freezes" to "the game stays responsive for ~2.9s while a
big blast catches up." D4-D10 are about cutting that remaining ~2.9s further
and shrinking how much work a blast generates in the first place, not about
throughput.

---

## 4. PERF-02 — Part A: performance (no gameplay/visual change)

Same discipline throughout: rewrite the pixel-access **mechanism**
(GDScript `get_pixel()`/`set_pixel()` loop → raw byte buffer, or a cached
read instead of a repeated one), never the coordinates/math/blend formula.
The existing equality selftests
(`decal_compositor_equality_selftest.gd`, `half_voxel_compositor_equality_selftest.gd`,
`decal_seam_selftest.gd`, `half_voxel_seam_selftest.gd`) compare against
real Python-reference fixtures pixel-by-pixel and are the regression gate —
any real numerical drift shows up there.

**A1 (D4) — batch the damage-composite texture upload.**
`godot/scripts/geometry/damage_composite_cache.gd`,
`godot/scripts/geometry/voxel_renderer.gd`. `DamageCompositeCache.store()`
keeps doing the CPU-side `blit_rect()` but stops calling
`add_damage_composite_tile()` (hence `ImageTexture.update()`) immediately;
instead it marks the touched page dirty. A new
`VoxelRenderer.flush_damage_composite_pages()` uploads each dirty page
exactly once, called at the end of `process_dirty()`, `process_dirty_slabs()`,
`process_dirty_async()`, and `process_dirty_slabs_async()` (all four —
sync callers get the same win).

**A2 (D5) — precompute `HalfVoxelCompositor` polygon masks.**
`godot/scripts/geometry/half_voxel_compositor.gd`. The handful of polygon
constants never change at runtime; compute each one's 32×36 inside/outside
mask once (lazily, on first use, keyed by the `PackedVector2Array`'s
identity or a small fixed enum of the named constants) and reuse it from
`paste_masked()`/`fill_masked()` — copy/fill via byte buffer using the
cached mask instead of calling `_point_in_polygon()` per pixel per call.

**A3 (D6) — `DecalCompositor.paste_decal()` byte-buffer sampling.**
`godot/scripts/geometry/decal_compositor.gd`. Build `work.get_data()` once
per call; replace `work.get_pixel(sx, sy)` inside the 4×4 supersample loop,
and `dst.get_pixel(px, py)`/`dst.set_pixel(px, py, ...)` once per
destination pixel, with direct byte-array reads/writes. Identical
coordinates, identical accumulation math, identical premultiplied-alpha
blend — only the fetch/store mechanism changes.

## 5. PERF-02 — Part B: shrink the explosion (gameplay, Director-approved)

**B1 (D7).** `bombs/frag_grenade.json` — `ring_multipliers` → `[1.0, 0.6, 0.2]`.

**B2 (D8).** `godot/scripts/systems/destruction/material_resistance_table.gd`
— scale destroy/dent/crack together, ~×0.65, first-pass values (same
"placeholder, expect retuning" status the table already declares for every
row):

| material | destroy (now→new) | dent (now→new) | crack (now→new) |
|---|---|---|---|
| metal | 0.05→0.03 | 0.5→0.3 | 0.0→0.0 |
| stone | 0.3→0.2 | 0.3→0.2 | 0.2→0.1 |
| concrete | 0.5→0.3 | 0.2→0.15 | 0.15→0.1 |
| wood | 0.9→0.6 | 0.05→0.03 | 0.0→0.0 |

**B3 (D9).** `godot/scripts/world/room.gd`, `_build_soot_snapshot()`. Split
`destroyed_cells` by `Voxel.damage_is_blast`; call
`BlastCalculator.derive_soot_rings()` twice — `weapon_cells` at the current
radius (`var weapon_soot_rings := 3`, unchanged), `blast_cells` at a wider
one (`var blast_soot_rings := 5`, new, tunable) — into separate scratch
snapshots/face-dicts, then merge into the real `out_snapshot`/`out_faces`
by taking the min ring per `(level, grid_pos)` and min per face component.
`derive_soot_rings()` itself is untouched.

**B4 (D10).** `godot/scripts/world/controllers/test_zone_controller.gd`,
`detonate_active()`'s floor loop. For a `is_deep` slab: fetch the shallow
sibling slab, build a `grid_pos → visible` lookup from its voxels, filter
`floor_slab.voxels` down to only those whose shallow counterpart is
`not visible`; if that filtered set is empty, skip the deep slab entirely
this blast (no `reveal_floor_slab()`, no `apply_crater_damage()`); otherwise
pass only the filtered subset into `apply_crater_damage()`. Existing
`_expose_below()` (unrelated, damage-free reveal-for-rendering call) still
runs after the shallow layer's own crater and is what makes the deep layer
visible-but-undamaged for a *future* blast's filter to find already exposed.

---

## 6. Deferred — explicitly not part of PERF-02

Both ideas below were raised by the Director in the same conversation that
scoped PERF-02, and both were explicitly pushed to a later session:
*"vamos executar toda a sequência anterior de redução primeiro, depois a
gente segue com a ideia do vídeo num segundo momento."* Recorded here in
enough detail that a future session doesn't have to re-derive them.

**D11 — three-stage destruction + colored flash cascade.** Restructure the
async render passes so DESTROYED, DENTED, and CRACKED voxels apply as three
distinct stages (reusing PERF-01's `_process_dirty_slice_voxel()`/
`_process_dirty_slab_voxel()` helpers, filtered by `damage_state` per stage
instead of one unified sweep), with a screen flash between each transition:
red, then yellow, then the existing `_flash_white()` tween
(`room.gd:2915`, already generalizable — currently hardcodes white,
would need a color parameter or two sibling calls). VFX-01's smoke
currently fires **per-voxel**, synchronously, off the `voxel_destroyed`
signal the instant a voxel is erased (`_on_voxel_destroyed()`,
`room.gd`) — moving to "release smoke as one coordinated moment after all
three stages" means decoupling that signal-driven immediate trigger into a
collect-then-release model (buffer positions/materials during the three
stages, flush to `SmokeSparkOverlay` once, after the last flash). Soot/light
repaint (`_repaint_voxel_light_buckets()`) would need to move from
"immediately after the render passes" to "deferred to overlap with the
smoke's ~0.6-1.0s rise" — likely a short `await` keyed to
`SmokeSparkOverlay`'s own lifetime rather than a fixed frame count, so it
naturally tracks if smoke tuning changes later.

**D12 — real-explosion video/flipbook overlay.** Same baked-flipbook idiom
this project already uses for the grenade prop, weapon bench statics, and
spinning collectibles (`FloatingCollectible`'s frame-sequence + alpha
playback, `CollectibleBakeConfig`) — reuse that pattern rather than invent
a second one. Needs, when the Director hands over the source footage: (1) a
conversion step (video → PNG sequence with alpha — a `tools/asset_generation/`
script, mirroring how other bakes are produced offline), (2) a new overlay
node that plays the sequence centered on the blast epicenter, above the
voxel geometry, and (3) gating the reveal/fade on **whichever finishes
later** — the flipbook's own playback or the async destruction render —
so a slow/large blast never pops in visibly after the cover clears early.
Confirmed technically sound in conversation: the flipbook's per-frame
advance and the destruction coroutine (`process_dirty_async()`/
`process_dirty_slabs_async()`) are independent per-frame work on the same
main thread — neither blocks the other, matching how VFX-01's own overlays
(`SmokeSparkOverlay`, `DebrisOverlay`) already coexist with the render
passes today.

---

## 7. Acceptance (PERF-02) — RESULTS, 2026-08-04

All criteria below met. Evidence, in the order the criteria are listed:

- `project_lint.py` PASSED after every sub-item and at the end.
- `run_selftests.py`: **29 clean, 0 failed**, including
  `decal_compositor_equality_selftest.gd` (`max_channel_diff=1, 0/911`,
  unchanged from before A3) and
  `half_voxel_compositor_equality_selftest.gd` (mismatch counts unchanged
  from before A2).
- Real before/after timings: §3's "After PERF-02" table — instrumented,
  measured, reverted (`grep PERF-DEBUG` returns nothing outside docs).
- Four-material real detonation captures, hand-named so the 50-file rotation
  cannot eat them: `Screenshots/history/perf02_concrete.png`,
  `perf02_metal.png`, `perf02_stone.png`, `perf02_wood.png`. The metal one is
  the clearest read on the decal/half-voxel path — the epicentre-facing side
  carries its dents and carved half-voxels, the rest of the wall is clean.
- **B4**: `SLAB_3_5_FLOOR_-1 destroyed=60` and `SLAB_3_5_FLOOR_-2 SKIPPED` in
  the SAME blast; the second half of the criterion (reachable once exposed)
  was answered with a real post-blast probe rather than the code-level review
  the plan allowed as a fallback — that GU would now expose 60/64 deep voxels
  to a next blast.
- **B3**: grenade and weapon-bench shot measured in the same configuration —
  grenade soot 925 → 1477 voxels with the near rings untouched, weapon shot
  identical at 72. See D9's row.
- `check_invariants.py` ✓ · `gen_codemap.py --check` clean.

**Follow-up round (B3-2 / B2b), same gates:** `project_lint` PASSED ·
`run_selftests` 29 clean / 0 failed · `check_invariants` OK ·
`gen_codemap --check` clean · soot gradient capture
`Screenshots/history/perf02b_soot_gradient.png` (hand-named, rotation-proof).

**One pre-existing condition ruled out, not inherited:** the
`ERROR: 3 resources still in use at exit` line on a capture run was checked
against a stashed HEAD build and appears there too — it predates this work.

---

## 7b. Acceptance (PERF-02, as originally written)

- `python3 tools/persistent/project_lint.py` clean after every sub-item,
  not only at the end.
- `python3 tools/persistent/run_selftests.py` — all existing selftests
  stay green, in particular `decal_compositor_equality_selftest.gd` and
  `half_voxel_compositor_equality_selftest.gd` after A2/A3 — the real proof
  the byte-buffer rewrites didn't drift.
- Temporary profiling (instrument, measure, revert — same pattern as
  PERF-01 and `ENGINE_PERFORMANCE_REVIEW.md`'s Part 0) showing the real
  time drop after A1-A3, and the real affected-voxel-count drop after
  B1-B2, pasted here or into the follow-up session summary — no reasoned
  expectation standing in for a pasted number.
- Real detonation capture across all four PLAYGROUND test-wall materials,
  confirming no decal/half-voxel color regression.
- B4 specifically: one detonation's `[BLAST]` log shows `destroyed>0` on
  the `FLOOR_..._-1` slab and `destroyed=0` on the paired `_-2` slab in the
  *same* blast; a second detonation at the same spot (or a code-level
  review of the exposed-filter if the test bench can't place two grenades
  on one GU) confirming the `-2` slab is reachable once exposed.
- B3 specifically: a grenade and a weapon-bench shot in the same test
  session, captures comparing soot reach around each — only the grenade's
  radius should change.
- `python3 tools/persistent/check_invariants.py` and
  `python3 tools/persistent/gen_codemap.py --check` clean.
- Commit `[PERF-02] ...`, push.
