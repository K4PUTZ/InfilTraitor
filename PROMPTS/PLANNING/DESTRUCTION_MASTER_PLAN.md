# DESTRUCTION_MASTER_PLAN
## Destructible Voxels, Voxel Floors & Slabs, Solid Texturing — v1.1

**Status:** 🟢 Part 0 (spike) and Part 1 (`Slab`) both DONE 2026-07-15. Part 2
(solid texturing) not started. **Runs AFTER `OCCLUSION_MASTER_PLAN`**
(Director's call, 2026-07-12) — occlusion paused at Alpha Foundation
2026-07-15, this plan is next.
**Baseline:** tag `verified/v0.8.2`.
**Companions:** `OCCLUSION_MASTER_PLAN.md` (occlusion lives there now — it must
never write `Voxel.visible`, see §3), `docs/technical/BAKE_SYSTEM_REFERENCE.md`
(bake canon), `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`
(container/dirty/TIC canon — **not obsolete**; it describes what was actually
built).
**Unblocks:** `TOP_TEXTURE_MASTER_PLAN` Part 3 (textured interiors), which has
been blocked on this plan's existence.

**v1.1 (2026-07-12):** occlusion split out into its own master plan and moved
ahead of this one. D10 is retired here and lives on as O1–O2 there. All other
D-numbers keep their identity — the register is a ledger, not a list, and
renumbering would break the traceability of today's commits.

---

## 1. Why — the pains this serves

The engine already contains a destruction motor that **has never been switched
on**. `Voxel.set_visible(false)` marks the voxel dirty → `Slice` propagates to
its container → `EdgeRegistry.dirty_slices()` returns only the dirty ones →
`VoxelRenderer.process_dirty()` rewrites *only the changed cells* → and the TIC
already runs every turn (`room.gd::_tic_voxel_system()`). Containers with
`dirty_count == 0` are skipped whole.

**Nothing in the project ever calls it.** Zero call sites for `set_visible(false)`
or `set_damage()`. The motor is built and idling.

So this plan is not "build destruction". It is **build the trigger, the floor,
and the interior** — and the largest single risk is not the render cost, it is
that we bolt a new voxel class onto an architecture whose invariants were written
for walls only.

Named pains this serves:
- **Split-brain state** (DORES #2) — the sharpest risk here, see §3.
- Legacy floor artwork from the pre-voxel era is still shipping.
- `TOP_TEXTURE_MASTER_PLAN` Part 3 has been blocked with no plan to unblock it.

---

## 2. Decision Register

| D | Decision | Status |
|---|---|---|
| **D1** | **`Slab` is the container sibling of `Slice`.** A wall voxel belongs to a `Slice` which belongs to an `Edge`; a floor voxel has no edge, so it needs its own container to hold voxels, count dirty, and be skipped when clean. Floor, ceiling and interior slab are **one class**: a ceiling *is* a Slab at level N. The interior cutaway of `OCCLUSION_MASTER_PLAN` Part 4 is blocked on this and comes free with it. | ✅ Ratified |
| **D2** | ~~Solid texturing via generalizing `_compose_junction_pages()`.~~ **CORRECTED 2026-07-16 (Director's diagram).** Floor/slab voxels have no corners and no continuous facade plane to project — unlike walls, the junction compositor's shear/plane math (`_get_plane`, `_get_plane_top`, mirror-fold) **does not apply here at all**, and generalizing it would have been solving the wrong problem. The real mechanism is D4's, and D2 is now the same decision as D4: a small pre-authored palette (~8 flat voxel atoms per terrain material, same 32×36 format as the 4 wall materials) plus a deterministic FNV-1a hash of `(x, y, level)` picking one atom per voxel. **No compositor, no per-map bake step.** Placement reuses `_set_voxel_cell()` exactly as walls do — selecting among 8 sources instead of 1 fixed one. Consequence for §4: the linear bake-combo-scaling risk Part 0 flagged (the one real cost finding) **does not apply to floor/slab** — that risk lives entirely in the wall/junction compositor this mechanism never touches. | ✅ Ratified (corrected; see D4) |
| **D3** | **`usage_cells` extended to the volume.** Compose only the voxels some object in the map actually uses, plus a one-layer "destruction-readiness" shell. Load cost becomes ∝ objects present, **not** ∝ material volume. This — not disk cache — is the real mitigation. *(Cache is already the bottleneck, not the solution: BAKE-CACHE-01 is 5× over budget.)* | ✅ Ratified |
| **D4** | **Deterministic FNV-1a hash (B4) drives per-voxel variation.** ~8 base "earth" tops × ~8 shade steps, selected by `hash(x, y, level)`. Never stored, never saved, recomputed identically forever ⇒ zero memory, zero save state, **zero popping when a neighbour is destroyed**. | ✅ Ratified |
| **D5** | **LOD by damage.** An intact GU is **one baked tile** — baked *from the same atoms, with the same hash*, so it is literally the composite of the 64 voxels it would explode into. First damage swaps 1 cell → 64 cells showing **identical pixels**, minus what was dug. The explosion is invisible; cost is paid only where destruction happens. An intact map costs exactly what it costs today. | ✅ Ratified |
| **D6** | **B5 amended: "no bake per FRAME", not "no re-bake".** Newly exposed faces ARE composed — at the **turn tick**, never per frame — with a hard cap of N voxels per detonation. N is a **balancing lever**, not an engineering one: weapon design bounds the worst case. *(The old B5 would have made the player dig into a beautifully textured block and see flat grey. It would have killed the entire payoff of D2.)* | ✅ Ratified |
| **D7** | **Depth is read through shading.** The same top texture at every depth would make a 1-voxel crater and a 3-voxel crater look identical. Darken with depth via the existing per-tile `page_modulates`. Free, and it turns D4's variation into **information** rather than noise. | ✅ Ratified |
| **D8** | **Destruction is an information transaction, not a power fantasy.** Digging is **loud** (a breach trades a new path against alerting guards); a GU dug past 50% becomes a **cover point**; rubble is **noisy terrain** (destruction poisons the path it opens); a breach is a **permanent clue** guards can notice and re-route around. | ✅ Ratified |
| **D9** | **Speculative pre-compute is DEFERRED.** Player thinking time is free compute and could pre-compose likely blast zones — but the turn budget probably already suffices, and building a predictor to save nothing is the classic trap. Decide by measurement. | ⏸️ Deferred |
| **D10** | *Retired here — occlusion moved to `OCCLUSION_MASTER_PLAN` (O1–O2). The binding half remains: **occlusion may never write `Voxel.visible`.** See §3.* | ↗️ Relocated |
| **D11** | **Generic material atlas: demoted, not deleted.** Kill it as a *silent fallback* (a baked-lookup MISS must **loud-fail** per B6 — a silent grey cell is exactly the class of bug that let `blit_rect`'s silent clipping ship twice). Keep it as `MATERIAL_ONLY`, an **explicit dev toggle** (F7) — the bisection tool that answers "is this a bake bug or a geometry bug?", the most valuable question there is when the bake breaks. **The look the Director likes (material colour showing through texture) is `MULTIPLY`, a blend mode — it does not depend on this fallback and survives its demotion.** | ✅ Ratified |
| **D12** | **Bake is the product.** Shipped default flips to `BakeConfig.enabled = true`. Original consequence as stated 2026-07-12: "BAKE-CACHE-01 becomes a release blocker... today's slow warm boot is tolerable because we could always ship with bake off; that escape hatch closes here." **CORRECTED 2026-07-15: BAKE-CACHE-01 was already fixed 2026-07-11, a day before this was written** — warm boot is ~32–35 ms, not 730–770 ms (see §4). The escape-hatch argument no longer applies because there is no open cache problem to escape from. D12 itself (bake as shipped default) stands on its own merits and remains ratified — it just no longer needs BAKE-CACHE-01 as its justification. | ✅ Ratified (rationale corrected) |
| **D13** | **The floor is a 2-layer slab: top destructible, bottom fixed bedrock.** This single constraint dismantles most of the problem — max excavation depth is **1 voxel**, so there is no infinite digging, no falling through the world, and no multi-level crater geometry. The destructible floor volume collapses from 8 levels to **one** (64 voxels per GU). Crater cover is therefore **prone-only**, earned when >50% of a GU's top layer is destroyed (>32 of 64 voxels) — by explosives, or by dozens of shots. A constraint that buys gameplay clarity and engine cheapness at the same time. | ✅ Ratified |
| **D14** | **Floor variety = N baked slab variants × per-cell symmetry. NOT a unique composite per GU.** The arithmetic settles it: a floor tile is 256×128 px, so a unique composite per GU on a 26×26 map costs 676 × 256×128×4 B = **88.6 MB** — dead on arrival for mobile. **16 pre-baked variants cost 2.1 MB.** Godot's TileMap carries per-cell transform flags (flip H / flip V / transpose) that live in the cell data and cost **not one pixel**: 8 symmetries × 16 variants = **128 apparent arrangements at the memory of 16**. *Implementation trap: mirroring the composite tile must mirror the 64-voxel index mapping it explodes into, or D5's pixel-perfect explosion breaks.* | ✅ Ratified |
| **D15** | **Destruction emits a signal; VFX subscribes.** `voxel_destroyed(grid_pos, level, material_id)`, emitted at the TIC alongside the dirty pass. Smoke, debris and sound are **not** the destruction system's business — with no subscriber the signal costs nothing, and the particle ceiling is the same N as D6. Add the signal **now**, while it is one line, rather than refactoring later for the hook nobody left. | ✅ Ratified |
| **D16** | **Atoms + dirty flag are a PRODUCER for Godot's TileMap, not an alternative to it.** There is no "our system vs. native Godot" choice to make — rendering is 100% native `TileMapLayer` on both planes: an intact GU is one cell on the coarse layer (256×128 tile, per-cell transform flags for variety); a dug GU is 64 cells on the fine layer (32×16 tiles) — the exact mechanism the walls already use. Our custom code is only (a) the compositor that produces the atlas and (b) the dirty/TIC that decides *which cells to rewrite*. Neither draws anything; both are bookkeeping. **The two planes are exactly commensurate:** an 8×8 block of 32×16 iso voxel tops spans corners `(0,0)`, `(+128,+64)`, `(−128,+64)`, `(0,+128)` — a bounding box of **256 × 128, precisely the floor tile size**. So a GU's 64 voxel tops tile the floor tile with **zero remainder and zero resampling**: replacing the legacy floor assets with a baked slab composite is *exact*, and D5's invisible explosion is **guaranteed by construction**, not approximated. **Godot terrain autotiling** is useless for the crater *interior* (which of 64 voxels are gone is a 2⁶⁴ state space — no bitmask enumerates it; the fine plane is mandatory) but is the right native tool for the **coarse debris/scorch ring** on the GUs *around* a crater. | ✅ Ratified |

*(Numbering note: D12 here is local to this plan and unrelated to the global D12 "mobile budget" decision in `OVERLORD_CONTEXT.md`.)*

---

## 3. Single-writer: `Voxel.visible` belongs to destruction, and to nothing else

`Voxel.visible` **already has an owner**:

```gdscript
## Apply damage state; DESTROYED forces visible=false
func set_damage(new_state: int) -> void:
    ...
    if new_state == DamageState.DESTROYED:
        visible = false
```

**Destruction is the sole writer.** Occlusion, fog of war and actor visibility all
have their own state and never touch this bit. The full ownership table, and the
resurrect-on-camera-rotation bug it prevents, live in `OCCLUSION_MASTER_PLAN` §2 —
because occlusion is the system that would break it.

The rule as it binds *this* plan: destruction writes `visible` and `damage_state`,
persists them, and lets them drive `blocked_cells`, cover and noise. Anything else
that wants a voxel to disappear must keep its own set.

---

## 4. Numbers — what we actually know

Measured, not estimated:

| Quantity | Value | Source |
|---|---|---|
| Voxels per GU | 8 × 8 = **64** | `VOXELS_PER_UNIT_AXIS = 8` |
| Levels per storey | **8** | `LEVELS_PER_STOREY = 8` |
| Atoms per storey per material (solid volume) | 8 × 8 × 8 = **512** | D2 |
| Atoms per atlas page | 128 × 16 = **2 048** | `PAGE_TILE_COLS`, `PAGE_H` |
| Page memory | **9.4 MB** | 4096 × 576 × RGBA8 |
| ⇒ 4 materials × 1 storey | ≈ **one page** | — |
| ⇒ 4 materials × 3 storeys | ≈ 3 pages ≈ **28 MB** | ← where mobile starts to hurt |
| Bake time, 4 combos × 2 dirs (TEXTURES) | **1 104 ms** | measured 2026-07-12 |
| Warm boot (BAKE-CACHE-01) | ~~730–770 ms~~ **~32–35 ms**, budget cleared | **CORRECTED 2026-07-15** — resolved `2026-07-11` (`366bed9`+`3ca1d33`), one day *before* this plan was drafted; the 730–770 ms figure was already stale when D12 (below) was written. Reconfirmed live via `bake_cache_test.gd`: 35 ms. |
| Floor cells, 26×26 map, fully voxelised | 676 GU × 64 = **43 264** | worst case only |
| Floor cells, 26×26 map, intact (D5) | **676** | = today's cost |
| Floor tile size | **256 × 128 px** | Transform Canon (SLICE-00) |
| Floor: unique composite **per GU** (676) | **88.6 MB** | ❌ dead on arrival (D14) |
| Floor: **16 baked slab variants** | **2.1 MB** | ✅ × 8 symmetries = 128 apparent (D14) |
| Floor destructible volume | **1 level**, 64 voxels/GU | D13 (bedrock below) |

**"Thousands of unique voxels" is bounded and small.** The number that actually
threatens mobile is not cells and not atoms — it is **`TileMapLayer` count**
(`_ensure_voxel_layers()` creates one layer per level, and floors/slabs/ceilings
add levels). That is the one thing in this plan still resting on a guess.
*(D13 already helped: a 2-level floor slab instead of an 8-level one is six layers
we no longer have to ask for.)*

---

## 5. Parts

### Part 0 — The measurement spike *(blocks everything; no code ships from it)*
The only honest way to start. Force the worst cases and **measure on the target
device**, not on the Mac:
- A fully voxelised 26×26 floor (43 264 cells) — frame time, memory.
- **`TileMapLayer` count scaling** — 1 layer per level, with floors + slabs +
  ceilings. **This is the suspected real ceiling.** Find where it breaks.
- Bake + warm-boot time with block volumes added.

Deliverable: a number for each, and a go/no-go on the layer-per-level model. If
layers are the wall, the fix (fewer layers, level encoded in the atlas, level
batching) must be known **before** Part 1 is written.

**Status: ✅ RAN 2026-07-15, Overlord direct implementation.** Headless
Mac/CPU pass — see honesty boundary below before treating this as closing the
device question. Tool: `res://godot/scripts/tools/destruction_part0_spike.gd`
(one-shot investigation script, not a standing gate — mirrors the existing
`bake_cache_test.gd` pattern). Raw run:

```
--- TEST A: TileMapLayer count scaling ---
  layers=256  cum_time=0.87ms  cum_mem=+0.86MB   (8 layers: 0.10ms / +0.02MB)
--- TEST B: Fully voxelised 26x26 floor, 1 destructible level (D13) ---
  GUs=676, cells placed=43264 (matches §4 worst case)
  placement wall time: 34.84 ms total (0.00081 ms/cell)
  static memory delta: 10.70 MB (0.25 KB/cell)
--- TEST C: Bake cold-compose cost, measured today ---
  8 combos (4 materials x 2 dirs): 1170.5 ms total, 146.3 ms/combo
  (2026-07-12 plan baseline for the same shape was ~1104 ms — same order of
  magnitude, reproducible)
  EXTRAPOLATION ONLY, no block-volume bake path exists yet to measure directly:
    24 combos -> ~3.5 s cold-compose (linear projection)
    48 combos -> ~7.0 s cold-compose (linear projection)
```

**Go/no-go: GO on Part 1.** Node-creation cost for `TileMapLayer` and raw
cell-placement cost at the §4 worst case are both cheap on CPU — neither is
the wall Part 0 suspected. **Honesty boundary:** headless `--headless` has no
display driver, so this measures CPU bookkeeping only, never GPU draw/composite
cost of many simultaneous layers — the plan's own instruction to measure "on
the target device, not on the Mac" is **not yet satisfied** by this run. That
on-device frame-time check is carried forward as a non-blocking follow-up
before Part 1/2 ship broadly (see §7.1), not a blocker for starting Part 1's
plumbing today.

**The one real finding: bake cold-compose scales linearly with combo count**,
and is the one number here that could become a user-visible stall (a few
seconds at 48 combos) on a first boot or after a content change — **not** on
a warm/cached boot, which BAKE-CACHE-01's disk cache already keeps at ~35 ms
regardless of combo count. This sharpens D3 (`usage_cells` restriction) from
"the real mitigation" to a load-bearing one: Part 2 should carry an explicit
combo-count budget once solid texturing's real atom/page shape is known,
rather than letting combo count grow unbounded.

### Part 1 — `Slab`, the container sibling *(D1)*
Floor/ceiling voxels get a container with dirty counting and TIC skip, mirroring
`Slice`. No destruction yet. Renders the existing floor identically (D5: intact GU
= 1 tile). Legacy floor artwork stays in place, unused, until Part 4 retires it.
**Also unblocks `OCCLUSION_MASTER_PLAN` Part 4 (interior cutaway).**

**Status: ✅ DONE 2026-07-15, Overlord direct implementation. VERSION 0.9.32.**

- `godot/scripts/geometry/slab.gd` — `Slab`, container sibling of `Slice`: same
  `dirty_count`/`mark_all_dirty()`/`increment_dirty()`/`decrement_dirty()`/
  `clear_all_dirty()` contract, none of `Slice`'s edge-specific fields (`face`,
  `edge_id`). `Role` enum (`FLOOR`/`CEILING`/`INTERIOR`) — one class per D1, not
  three.
- `godot/scripts/geometry/slab_registry.gd` — `SlabRegistry`, mirrors
  `EdgeRegistry`'s slice-half (`register_slab`/`get_slab`/`all_slabs`/
  `dirty_slabs`/`clear`/`is_empty`); no edge-linking half, because Slab voxels
  have no edge.
- `godot/scripts/geometry/voxel.gd` — `Voxel._parent_slice: Slice` widened to
  untyped `_parent_container` (GDScript has no shared interface; both `Slice`
  and `Slab` implement `increment_dirty()`/`decrement_dirty()`). **`Voxel` itself
  is unmodified otherwise** — one class serves both containers, per D1. Single
  call site (`slice_generator.gd:49`) needed no change.
- `godot/scripts/world/room.gd` — `_slab_registry: SlabRegistry` member next to
  `_edge_registry`; `_tic_voxel_system()` now also calls `_tic_slab_system()`,
  which clears any dirty slabs (no renderer consumer yet — that's Part 3/4).
- `godot/scripts/world/builders/room_builder.gd` — publishes
  `room._slab_registry = SlabRegistry.new()` the same way and for the same
  reason `_edge_registry` is published (see that comment) — never null, empty
  until Part 2 gives it a producer.
- **Rule 8 amended** (`tools/persistent/OPERATOR_CONTEXT.md`, §7.3 of this plan)
  — widened from "wall voxels" to "wall AND Slab voxels via `set_cell()`/
  `_set_voxel_cell()` only," written now so Part 4's renderer has no excuse to
  invent a parallel path.
- **Evidence:** `godot/scripts/tools/slab_geometry_selftest.gd`, 15/15 PASS —
  voxel count (64/GU), dirty propagation, `clear_all_dirty()` resets flags
  without touching `damage_state`, the same `Voxel` class working unmodified
  under both `Slice` and `Slab` with no cross-contamination, and the
  `SlabRegistry.dirty_slabs()` skip contract (empty when clean, exact set when
  dirty). `project_lint.py`: 122 files, 0 real errors.
- **No visual/gameplay change** — by construction: nothing calls
  `_voxel_layers`/`_set_voxel_cell` for floor/ceiling yet, `_slab_registry`
  starts empty on every map load, so `_tic_slab_system()` early-returns every
  tick today. D5's "renders identically" holds because nothing renders through
  Slab yet, not because it was verified pixel-for-pixel.

### Part 2 — Floor/slab texturing *(D2/D4, D3, D7, D14)*
**Re-scoped 2026-07-16** — see corrected D2. Not a compositor generalization:
a small pre-authored voxel palette (~8 per terrain material) placed by a
deterministic FNV-1a hash of `(x, y, level)`, same placement call
(`_set_voxel_cell()`) walls already use. `usage_cells` (D3), depth shading
(D7) and the 16-variant coarse composite (D14) still apply on top of this.
Still no destruction — verified purely on intact geometry and on a *manually*
carved block.

**Core landed 2026-07-16, Overlord direct implementation (isolated, no
consumer yet — matches the Part 0/1 pattern):**
- `tools/asset_generation/generate_voxel.py` extended with an `EARTH_VARIANTS`
  palette (8 flat-lit tone variants, same generator as the 4 wall materials) →
  `voxel_earth_0.png`..`voxel_earth_7.png`. Not committed to git — `ASSETS/` is
  gitignored project-wide; only the generator is source of truth, matching how
  the 4 existing material atoms already work.
- `godot/scripts/systems/earth_variant_selector.gd` — `EarthVariantSelector.
  variant_for(grid_pos, level) -> int`, the D4 hash-selector. Reuses
  `FacadeSampler._fnv1a_hash()` (made `static`, zero behavior change for
  existing callers) rather than a second copy of the pinned B4 algorithm.
- **Evidence:** `godot/scripts/tools/earth_variant_selftest.gd`, 6/6 PASS —
  determinism (same input forever), range, non-degenerate (not returning one
  constant index), full 8-variant coverage across one real 8×8 GU footprint,
  all 8 placeholder atoms load at canon 32×36, and the static/instance FNV-1a
  refactor produces identical hashes (one algorithm, not two). `project_lint.py`:
  124 files, 0 real errors.
- **Not done yet, deliberately** (next wave, consumes this core): wiring
  `variant_for()` into `VoxelRenderer`'s `TileSet` (registering the 8 earth
  sources) and into `Slab` population from a real map — this wave is the
  selector in isolation only, same discipline as Part 0→Part 1.
- **Director's diagram (2026-07-16), captured for the next wave:** one GU's
  floor is `8×2×8` voxels — matches D13 exactly (destructible top level +
  fixed bottom level, 8×8 footprint each). The builder assigns the hash-picked
  variant per voxel **at load time**, not at bake time — there is no per-map
  compose step to run at all for this material class.
- **Future, explicitly deferred (Director, 2026-07-16):** non-random decorative
  slabs (tile/patterned floors that follow a visual layout instead of a hash) —
  a different, later variability tier, scoped to the procedural-maps phase, not
  this plan.

### Part 3 — The trigger *(D5, D6, D8, D15)*

> **⚠️ Corrected 2026-07-12 — the motor was not "idle", it was severed.**
>
> This plan (and the retrospective) said the dirty-flag/TIC motor was *fully built and
> wired, just never switched on*. That was **wrong in a way that would have cost this part
> a whole debugging cycle.**
>
> `room.gd::_tic_voxel_system()` guards on `_edge_registry != null` and **`_edge_registry`
> was always null.** `room_builder.build_from_layout()` declared the registry as a
> **function local** (`var _edge_registry = EdgeRegistry.new()`), which shadowed
> `room.gd`'s member of the same name and was discarded on return. The room's only
> assignment lived in `room.gd::_build_room()` — a dead duplicate that was never called.
>
> So the wire was cut at **both** ends: no producer marked voxels dirty, **and**
> `process_dirty()` could not have run even if one had. Part 3 would have marked voxels
> destroyed, seen nothing happen, and hunted the bug in the wrong system.
>
> **Fixed:** `room_builder` now publishes `room._edge_registry` / `room._junction_columns`.
> `_tic_voxel_system()` is called every TIC (`room.gd:1073`) and now has a registry to
> process. The motor is genuinely connected and genuinely idle — the only thing still
> missing is a producer, which is what this Part adds.

Wire the idle motor: a detonation marks voxels destroyed → dirty → TIC → newly
exposed faces composed at the tick, capped. Cover rule (>50% of a GU), noise on
digging, rubble as noisy terrain, breach as a persistent clue, `voxel_destroyed`
signal. **B5 amended here.**

### Part 4 — Bake becomes the product *(D11, D12)*
Silent fallback removed (loud-fail on MISS). `MATERIAL_ONLY` kept as a dev toggle.
Shipped default flips to `enabled = true`. Legacy floor assets retired.
~~BAKE-CACHE-01 resolved — this part cannot close while warm boot is 5× over
budget.~~ **Already true as of 2026-07-11 — see §4.** That precondition is
cleared; Part 4's remaining scope is the fallback/loud-fail work and the
default flip, not the cache.

---

## 6. Wave sequencing

```
Wave 0:  Part 0 (spike)            → a number, and a go/no-go on layers-per-level
Wave 1:  Part 1 (Slab)             → depends on Wave 0
Wave 2:  Part 2 (solid texturing)  → depends on Slab existing
Wave 3:  Part 3 (the trigger)      → depends on solid texturing (nothing to expose otherwise)
Wave 4:  Part 4 (bake as product) + BAKE-CACHE-01
```

Per the prompt-sizing rule: **a novel geometric transform is always its own
prompt.** Part 2's `(x, y, depth)` generalisation lands and is verified *before*
anything consumes it; Part 3 must not be bundled with it.

---

## 7. Open questions

1. **`TileMapLayer` count** — the one real unknown. **Part 0 answered the
   CPU/node-creation half 2026-07-15** (256 layers: 0.87 ms, 0.86 MB, headless
   Mac — not the wall). **Still open: real on-device GPU frame-time cost of
   many simultaneous layers** — headless has no display driver and cannot
   measure this. Carry forward as a non-blocking check before Part 1/2 ship
   broadly, not before Part 1 starts.
2. **D9 (speculative pre-compute)** — deferred; revisit only if Part 0/3 measurements demand it.
3. ~~**Rule 8 amendment**~~ **DONE with Part 1, 2026-07-15** —
   `tools/persistent/OPERATOR_CONTEXT.md` Rule 8 now explicitly covers Slab
   voxels alongside wall voxels.
