# DESTRUCTION_MASTER_PLAN
## Destructible Voxels, Voxel Floors & Slabs, Solid Texturing — v1.1

**Status:** 🟢 **PAUSED at Alpha Grenade Foundation, 2026-07-22.** Part 0
(spike), Part 1 (`Slab`), Part 2 core+consumer (floor), Part 2b (roof/ceiling
Slabs) and now **Part 3 (the trigger) DONE** — see Part 3's own status block
below for the full account. The idle motor D15/D6 described is no longer
idle: a real grenade in the real running game marks real voxels destroyed,
through the real dirty-flag/TIC pipeline, confirmed by direct `TileMapLayer`
cell readback (not code-reading). **Paused here, Director's call
(2026-07-22):** lighting is the next real blocker — every voxel currently
renders fully lit regardless of damage, so a crater's depth/shape reads as
close to invisible even though the underlying geometry is genuinely gone.
Destruction work resumes once lighting can actually sell the damage;
continuing to build more destruction mechanics (blast tuning, cover/noise
integration, fire) before that would be building on top of an effect nobody
can see yet.
**Runs AFTER `OCCLUSION_MASTER_PLAN`** (Director's call, 2026-07-12) —
occlusion paused at Alpha Foundation 2026-07-15, this plan picked up next
and is now itself paused, first at its own Alpha Ceiling Foundation
(2026-07-16), then again here at Alpha Grenade Foundation (2026-07-22).
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
| **D13** | ~~The floor is a 2-layer slab: top destructible, bottom fixed bedrock.~~ **CORRECTED 2026-07-16 (Director's design pass — see D17, D18).** The floor is a per-GU **8-level stack living in a new negative storey** (storey −1, levels −8..−1), not a 2-level shape. Only the **top level** (level −1, immediately below storey 0 where walls/world begin) is a real `Slab` — destructible, dirty-tracked. The other 7 levels (−8..−2) are fixed: never destructible, never even instantiated as a `Slab`/`Voxel` until D18 exposes them. Max excavation depth stays **1 voxel** (same gameplay clarity as the original constraint), and digging can never reveal a void — the fixed levels back-stop it *by construction* (there is no code path that ever marks them dirty), not merely by design discipline. Crater cover remains **prone-only**, earned when >50% of the top level's 64 voxels are destroyed. | ✅ Ratified (corrected) |
| **D14** | **Floor variety = N baked slab variants × per-cell symmetry. NOT a unique composite per GU.** The arithmetic settles it: a floor tile is 256×128 px, so a unique composite per GU on a 26×26 map costs 676 × 256×128×4 B = **88.6 MB** — dead on arrival for mobile. **16 pre-baked variants cost 2.1 MB.** Godot's TileMap carries per-cell transform flags (flip H / flip V / transpose) that live in the cell data and cost **not one pixel**: 8 symmetries × 16 variants = **128 apparent arrangements at the memory of 16**. *Implementation trap: mirroring the composite tile must mirror the 64-voxel index mapping it explodes into, or D5's pixel-perfect explosion breaks.* | ✅ Ratified |
| **D15** | **Destruction emits a signal; VFX subscribes.** `voxel_destroyed(grid_pos, level, material_id)`, emitted at the TIC alongside the dirty pass. Smoke, debris and sound are **not** the destruction system's business — with no subscriber the signal costs nothing, and the particle ceiling is the same N as D6. Add the signal **now**, while it is one line, rather than refactoring later for the hook nobody left. | ✅ Ratified |
| **D16** | **Atoms + dirty flag are a PRODUCER for Godot's TileMap, not an alternative to it.** There is no "our system vs. native Godot" choice to make — rendering is 100% native `TileMapLayer` on both planes: an intact GU is one cell on the coarse layer (256×128 tile, per-cell transform flags for variety); a dug GU is 64 cells on the fine layer (32×16 tiles) — the exact mechanism the walls already use. Our custom code is only (a) the compositor that produces the atlas and (b) the dirty/TIC that decides *which cells to rewrite*. Neither draws anything; both are bookkeeping. **The two planes are exactly commensurate:** an 8×8 block of 32×16 iso voxel tops spans corners `(0,0)`, `(+128,+64)`, `(−128,+64)`, `(0,+128)` — a bounding box of **256 × 128, precisely the floor tile size**. So a GU's 64 voxel tops tile the floor tile with **zero remainder and zero resampling**: replacing the legacy floor assets with a baked slab composite is *exact*, and D5's invisible explosion is **guaranteed by construction**, not approximated. **Godot terrain autotiling** is useless for the crater *interior* (which of 64 voxels are gone is a 2⁶⁴ state space — no bitmask enumerates it; the fine plane is mandatory) but is the right native tool for the **coarse debris/scorch ring** on the GUs *around* a crater. | ✅ Ratified |
| **D17** | **Floor lives in negative storey space; everything else stays exactly where it is.** Walls/blocks/props keep their existing storey-0-and-up placement completely unchanged. Audited and confirmed: the only two places a wall's base storey is decided are `edge_extractor.gd:97` (`"min_storey": 0` for ordinary walls) and `room_builder.gd:611` (per-block authored `storey` value, read as-is) — neither is touched by this decision. Occlusion's base band (`OcclusionSet.BASE_VISIBLE_LEVELS`) is already relative to each edge's own base level, not an absolute 0, so it follows for free. This confines the entire floor-geometry effort to `VoxelRenderer`'s own internal bookkeeping: `_voxel_layers` moves from a 0-based `Array[TileMapLayer]` to a `Dictionary[int, TileMapLayer]` keyed by the true (possibly negative) level — GDScript's `array[-1]` means *last element*, not *grow downward*, and `_set_voxel_cell()` previously hard-rejected `level < 0` outright. **Alternative considered and rejected:** shifting every wall/block/prop up a full storey so the floor could occupy storey 0 conventionally — rejected because it touches the tested, working wall/junction/occlusion pipeline across multiple files for no functional gain negative storey doesn't already deliver at lower risk. | ✅ Ratified |
| **D18** | **Lazy reveal: nothing below the top destructible level exists until digging exposes it.** Not the 7 fixed floor levels, not deeper cosmetic storeys (storey −2 and below — lava, water, smoke; purely decorative background, never interactive, never a `Slab`, glimpsed only through a crater with a small parallax offset selling depth). An intact map's floor cost is therefore **one level's worth of cells per GU** — matching the Part 0 spike's real measured baseline (43 264 cells / 34.84 ms / 10.70 MB for a full 26×26 map, Test B), **not** multiplied by 8 or by however many cosmetic storeys exist below. This is D3 (`usage_cells`) and D6 (tick-capped composition) applied to depth, not a new principle: cost follows what is actually visible, not what could theoretically exist. Deeper cosmetic storeys additionally need no `Slab`/`Voxel`/dirty-tracking machinery at all — low-detail, low-randomness "vector voxel" materials, rendered only for the small area an actual hole exposes. | ✅ Ratified |

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
- ~~**Director's diagram (2026-07-16):** one GU's floor is `8×2×8` voxels.~~
  **SUPERSEDED same day, second design pass — see D13/D17/D18.** The floor is
  `8×8×8` (a full storey) living in **negative storey −1**, not stacked on top
  of storey 0: only the top level is destructible, the other 7 are fixed and
  lazily instantiated. The builder still assigns the hash-picked variant per
  voxel at load time for whatever level actually gets built — there is still
  no per-map compose step for this material class, that part is unchanged.
- **Future, explicitly deferred (Director, 2026-07-16):** non-random decorative
  slabs (tile/patterned floors that follow a visual layout instead of a hash) —
  a different, later variability tier, scoped to the procedural-maps phase, not
  this plan.

**Consumer wave landed 2026-07-16, same session, Overlord direct
implementation.** The core above now actually renders:
- `voxel_renderer.gd`'s `MATERIALS` extended with `earth_0`..`earth_7`,
  appended after the 4 wall materials (source_id = array index, so wall
  material ids 0–3 are untouched). They load through the exact same
  `_build_voxel_tileset()` loop and `_set_voxel_cell()`'s `MATERIALS.find()`
  fallback as the wall materials — zero new loader or resolution code, per D2.
  Earth voxels never reach the baked-lookup branch (floor voxels have no
  edge, D1), same as any other material-only placement.
- `voxel_renderer.gd`'s new `render_slab(slab)` — iterates a `Slab`'s voxels,
  calls `EarthVariantSelector.variant_for()` per voxel, places the cell.
  Idempotent by construction (same inputs, same hash, every call).
- `slab_generator.gd` (new) — mirrors `slice_generator.gd`: builds one
  Slab's 64 `Voxel`s from `GeometryCoords.gu_voxels()`, registers it.
  **D13 realized as two independent Slabs per GU**, not one 8×2×8 container —
  destructible top level and fixed bottom level each get their own `Slab`
  (own id, own `dirty_count`), so the bedrock level is structurally
  incapable of ever being marked dirty by anything that touches the top.
- **Evidence:** `slab_render_selftest.gd`, 8/8 PASS — 64-voxel generation
  matches `gu_voxels()` exactly; **the real round-trip**: every one of 64
  placed `TileMapLayer` cells' `source_id`, read back from the layer,
  matches an *independently re-derived* `EarthVariantSelector.variant_for()`
  call (not a tautological self-comparison against the writer's own choice);
  `render_slab()` is idempotent (two calls, identical output); the two-Slab
  D13 model has zero cross-contamination (damaging the top never touches the
  bottom's `dirty_count`, `dirty_slabs()` reports only the top).
  Full regression check, same session: `earth_variant_selftest.gd` 6/6,
  `slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19 — the
  `MATERIALS` extension and `FacadeSampler._fnv1a_hash` staticization broke
  nothing. `project_lint.py`: 126 files, 0 real errors.
**D17 (negative storey) landed 2026-07-16, same session, Overlord direct
implementation.** `VoxelRenderer` now supports both signs:
- `_negative_voxel_layers: Dictionary[int, TileMapLayer]` added alongside the
  existing `_voxel_layers: Array[TileMapLayer]` — a deliberate second
  structure, not a unification, so every existing positive-level caller
  (walls, junctions, props, occlusion) needed **zero changes**.
- `_build_voxel_layer_node(level)` extracted as the one formula both
  `_ensure_voxel_layers()` (positive) and the new `_ensure_negative_voxel_layer(level)`
  (negative, single-level, never contiguous-from-zero per D18) call — position
  and z-index math has exactly one owner for both signs.
- `get_layer(level)` and `_set_voxel_cell(level, ...)` are the two routing
  points; `_set_voxel_cell` no longer hard-rejects `level < 0`, it now warns
  only if the caller forgot to ensure the layer first (same contract as
  positive levels always had). `render_slab()` routes to the correct ensure
  function based on `slab.level`'s sign.
- **Evidence:** `negative_storey_selftest.gd`, 12/12 PASS — layer creation
  and idempotent re-ensure; position/z-index formula is sign-correct (level
  −1 renders visually below level 0, `z_index = wall_base + level` = 9 vs 10);
  **D18's lazy contract directly tested**: ensuring level −3 does **not**
  create −1 or −2 along the way; `render_block()` (walls) places all 64 cells
  correctly with negative layers present, `get_layer_count()` stays
  positive-only; `render_slab()` with `slab.level = −1` places 64
  independently-verified cells and creates **no** positive layer as a side
  effect; an unensured negative level still warns instead of silently
  no-op'ing or crashing. Full regression, same session: `slab_render_selftest.gd`
  8/8, `earth_variant_selftest.gd` 6/6, `slab_geometry_selftest.gd` 15/15,
  `bake_selftest.gd` 19/19 — the wall/bake/prop pipeline is untouched.
  `project_lint.py`: 127 files, 0 real errors.
**D13's 7 fixed levels landed 2026-07-16, same session, Overlord direct
implementation.** `VoxelRenderer.render_fixed_earth_level(gu_cell, level)` —
places one level's 64 cells directly (`GeometryCoords.gu_voxels()` +
`EarthVariantSelector.variant_for()` + `_set_voxel_cell()`), the same way
`render_block()` places wall material, just per-level instead of per-storey
and through the earth hash instead of one fixed material. **No `Slab`, no
`Voxel`, no registry — on purpose.** D13's "structurally incapable of being
marked dirty" claim now has a concrete reason: fixed levels never go through
`Voxel` at all, so there is no `dirty` flag to ever set. Reuses the same
earth-variant hash as the destructible top for material continuity, at zero
extra cost (pure function, already used).
- **Evidence:** `fixed_floor_selftest.gd`, 5/5 PASS — 64 cells on a fixed
  level match an independently re-derived variant (same round-trip discipline
  as the Slab render tests); an independent `SlabRegistry` stays empty after
  a fixed-level render (nothing registered, nothing to leak); one call builds
  only its own level, never neighbours (D18's lazy contract, same class of
  proof as `negative_storey_selftest.gd`'s level −3 test); and **the full
  D13 stack assembled and verified end-to-end**: one real `Slab` at level −1
  (destructible) plus `render_fixed_earth_level()` for levels −8..−2, all 8
  layers real, and after damaging the top voxel the registry holds **exactly
  one** `Slab` — the fixed levels cannot appear in `dirty_slabs()` because
  they were never able to register in the first place.
  Full regression, same session: `negative_storey_selftest.gd` 12/12,
  `slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
  `slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19.
  `project_lint.py`: 128 files, 0 real errors.
**Real map integration landed 2026-07-16, same session, Overlord direct
implementation.** `room_builder.gd::build_from_layout()` now builds the
destructible top level (storey −1) for every GU on every real map load —
not just in isolated tests:
- `room._slab_registry = SlabRegistry.new()` and `room._voxel_renderer.clear()`
  moved **out of** the `if not extraction.get("edges", []).is_empty():` block
  to run unconditionally, alongside the legacy floor loop. **Real latent bug
  fixed in passing:** both were previously nested inside that conditional, so
  any edge-less room (no walls) would have left `room._slab_registry` null
  forever — floor doesn't depend on walls existing, so it cannot depend on
  that branch either.
- A new unconditional loop, same `_room_size` coverage as the legacy floor
  loop right above it, calls `SlabGenerator.generate(gu, Slab.Role.FLOOR, -1,
  "earth", room._slab_registry)` + `room._voxel_renderer.render_slab(slab)`
  per GU. **Only the top level** — D18's lazy reveal holds even here: the 7
  fixed levels are not built at map load, only on an actual future dig
  (Part 3, not built).
- **Evidence — driven against the REAL PLAYGROUND map** (`FileMapSourceClass
  .get_runtime_spec("PLAYGROUND")` → `MapCompilerClass.compile()` → the exact
  same path `room.gd::load_map()` uses, not a synthetic `map_spec`), via
  `floor_integration_selftest.gd`, 6/6 PASS: `room._slab_registry` non-null;
  **exactly 600 Slabs** registered for the real 30×20 PLAYGROUND room (one
  per GU, matching `room_size.x × room_size.y` precisely), all at level −1;
  zero dirty immediately after build; 192 sample cells across 3 real GUs
  (both corners + center) match an independently re-derived
  `EarthVariantSelector.variant_for()` call; and the existing wall pipeline
  is confirmed unaffected — **151 real edges, 23 real junction columns**,
  same numbers the real bake pipeline produced (`[BAKE] Baked 4 combos × 2
  directions in 1073.0 ms` in the same run). Full regression, same session:
  `negative_storey_selftest.gd` 12/12, `fixed_floor_selftest.gd` 5/5,
  `slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
  `slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19 —
  `room_builder.gd`'s control-flow restructure broke nothing.
  `project_lint.py`: 129 files, 0 real errors.
- **Visually confirmed the same commit, unplanned.** A manual full-scene
  headless boot was unreliable this session (concurrently open Godot
  editor), but `SCREENSHOT-HOOK-01`'s own pre-commit auto-capture fired
  normally on this commit and produced real, comparable evidence:
  `Screenshots/history/auto_2026-07-16_14-10-30.png` (immediately prior
  commit, same PLAYGROUND/TEXTURES fixture) shows the plain grid-pattern
  placeholder floor; `auto_2026-07-16_14-29-06.png` (this commit) shows the
  ground fully covered in the mottled brown earth-voxel pattern — a real,
  unforced before/after from the exact same camera position. Not yet
  Director-ratified as a *finished look* (placeholder art, D14's coarse
  composite not built), but the negative-storey floor is confirmed
  **actually rendering in the real running game**, not just in isolated
  tests.
- **Still open:** legacy floor artwork (Part 4's retirement target) still
  exists and will need retiring once the new floor is ratified. D18's actual
  lazy-reveal *trigger* (Part 3, not built), deeper cosmetic storeys
  (storey −2 and below: lava/water/smoke), `usage_cells` (D3), depth shading
  (D7) and the 16-variant coarse composite (D14) remain open.

**D18 amendment — border GUs eagerly build the full 8-level block, dev-only
(Director, 2026-07-16).** The Director spotted this from the real screenshot:
the map's outer edge shows the floor's lateral cut, and D18's lazy reveal
left nothing built below the top level anywhere, including there — a thin
1-voxel edge instead of a solid-looking block. **In the shipped game this is
moot:** a buffer of non-playable GUs outside the camera's view will hide any
lateral cut, so lazy-reveal's border gap is invisible in production by
construction, not by this fix. But *during development* the border is
directly visible (no buffer built yet) and the deeper cosmetic storeys
(lava/water/smoke) need to be inspectable without waiting on Part 3's dig
trigger to exist. **Decision:** GUs on the outer perimeter of `_room_size`
eagerly build all 8 levels (`render_fixed_earth_level()` for −8..−2, in
addition to the top `Slab`) at map load; interior GUs stay lazy (top level
only). Cost is bounded by the map's *perimeter* (`O(room_size.x +
room_size.y)`), not its area — cheap regardless of map size. **Revisit once
the production camera buffer exists** — this eager-build becomes dead weight
the moment border GUs are no longer near a visible camera edge, and should
be removed then, not left as permanent scope creep.

### Part 2b — Roof/Ceiling Slabs ("Lajes") *(D1, new — 2026-07-16)*

**Director's request, same session:** build actual roof/ceiling slabs —
positioned above the existing block/prop structures already in the game,
using the SAME `Slab` geometry as the floor, but shaped differently:
"valores quebrados, como 2 ou mais slabs de altura, com todas as camadas
destrutíveis" (broken/irregular heights, 2+ levels, **every** level
destructible — unlike the floor's D13 model of 1 destructible level + 7
fixed). Reuses the *existing wall material voxels* (concrete/metal/stone/
wood), matched to whatever structure the roof sits above — not the earth
palette. Not walkable (no gameplay floor forms on top), but will need to be
occluded when the player is inside the room, and destructible in a way that
lets light/shadow pass or block. **Director's explicit phasing:** try the
existing wall-bake system (`facade_tops`/`_get_plane_top` — already baking
continuous-looking tops per individual wall/junction voxel, per
`BAKE_SYSTEM_REFERENCE.md`'s TOP-SHEAR-01 work) for the roof's appearance
*eventually*, but geometry first, without bake, since `_get_plane_top()` is
edge/perimeter-projected and was never built to fill an entire block's
interior footprint as one continuous surface — extending it is a real
open question, not assumed to just work.

**Geometry landed 2026-07-16, Overlord direct implementation.** No new
class needed — D1 already named `Role.CEILING` as one of Slab's three roles,
so an N-level roof is just `SlabGenerator.generate()` called N times (once
per level, each a fully independent, fully destructible `Slab`) — the
existing container model already fits. The one real addition:
`voxel_renderer.gd`'s `render_slab_solid(slab)`, a sibling to `render_slab()`
— places `slab.material` directly for every voxel (no per-voxel hash), for
Slabs that reuse one fixed existing wall material rather than picking among
a randomized palette. `render_block()` (walls) is unchanged and still the
right tool for a block's own body; `render_slab_solid()` is for the
Slab-tracked, independently-destructible layers sitting on top of it.

**Evidence:** `roof_slab_selftest.gd`, 8/8 PASS — a 3-level roof produces 3
distinct, independently-registered `Slab`s (no new geometry class needed);
`render_slab_solid()` places a real, fixed material with zero per-voxel
variance (64/64 cells); **all levels independently destructible**, proven
by damaging one level and confirming the other two stay at `dirty_count 0`,
then damaging all three and confirming `SlabRegistry.dirty_slabs()` reports
all 3 simultaneously — the exact opposite of the floor's one-destructible-
level constraint, on purpose; and a roof positioned above a simulated
wood block (via the existing, proven `render_block()`) renders the same
"wood" material at the block's own top level and both roof levels above it,
confirmed by real cell inspection, not code reading. Full regression, same
session: `negative_storey_selftest.gd` 12/12, `fixed_floor_selftest.gd` 5/5,
`slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
`slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19.
`project_lint.py`: 130 files, 0 real errors.

**Real map integration landed 2026-07-16, same session, Overlord direct
implementation.** Every real block from a map's own `"blocks"` section now
gets a real roof at real map load — driven against the REAL PLAYGROUND map
(49 real concrete/stone/wood/metal blocks from `maps/PLAYGROUND.map.json`),
not a simulated one:
- `map_compiler.gd` forwards the *original* per-GU block declaration
  (`gu_cell` offset-adjusted, `size`, `storeys`, `material`) as
  `solid_block_instances` in its output — new key, additive, alongside the
  existing `voxel_prop_instances` precedent. **Why not re-derive from
  `extraction["edges"]`/`solidblock_occupancy` instead:** those represent
  the block's *walls*, not "this GU is a block worth roofing" as a directly
  iterable fact — re-deriving it would be a second, error-prone copy of
  logic `map_compiler.gd`'s own block-expansion loop already computes once.
- `room_builder.gd::build_from_layout()` iterates `solid_block_instances`
  (inside the same `if not extraction.edges.is_empty()` branch the wall/
  block render already lives in, since a block's existence implies edges
  exist) and calls `SlabGenerator.generate()` + `render_slab_solid()` for
  `ROOF_LEVEL_COUNT` (placeholder default: 2 — "2 ou mais," Director;
  tune later) levels starting at `storeys × LEVELS_PER_STOREY`, using the
  block's own material.
- **Known limitation, matching existing precedent, not a new gap:**
  `perspective_mapper.gd`'s `layout_with_perspective()` does not rotate
  `solid_block_instances`' `gu_cell` for non-N views — `voxel_prop_instances`
  has the exact same limitation today (verified: absent from that file
  entirely). Not fixed here; flagged for whoever eventually fixes it for
  voxel props, since it's the same underlying gap.
- **Evidence:** `roof_integration_selftest.gd`, 3/3 PASS — `map_compiler.gd`
  forwards exactly 49 `solid_block_instances` (matching the raw spec's block
  count 1:1); **all 49 real block-GUs have a real, registered, independently
  re-derived roof `Slab`** at the correct level (`storeys × 8`) with the
  correct material, confirmed by reading back real placed cells, not by
  trusting the writer's own choice; and a real roof `Slab` from the actual
  map is independently destructible (damaged 1/64 voxels, `dirty_count=1`,
  registry reports exactly 1 dirty). `floor_integration_selftest.gd` updated
  or reused stale assertion `("every Slab is at level -1")` — that was
  written before roofs existed and needed filtering by `Role.FLOOR` once the
  registry legitimately started holding `Role.CEILING` Slabs too; now 9/9
  PASS, including a new check that registry total == FLOOR + CEILING (no
  untracked third category, the two producers coexist cleanly). Full
  regression, same session: `roof_slab_selftest.gd` 8/8,
  `negative_storey_selftest.gd` 12/12, `fixed_floor_selftest.gd` 5/5,
  `slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
  `slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19.
  `project_lint.py`: 131 files, 0 real errors.
- **Still not done, deliberately:** the bake-system experiment for
  continuous top-surface texture (Director's explicit "a princípio vamos
  tentar," phased *after* geometry on purpose); occlusion participation
  (roofs hidden when the player is inside the room); the light/shadow
  pass-through-when-destroyed behavior; `voxel_prop_instances`-based
  structures (crates etc.) don't get roofs yet, only `"blocks"`-section
  structures. Each is its own real question, not assumed to fall out for
  free.

**Border fix, same session, 2026-07-16.** Director spotted from a real
screenshot: `SliceGenerator` puts a wall's two slices on the *own* boundary
column of each side (`slice_a` on `gu_a`, `slice_b` one voxel further out on
`gu_b` — see `slice_voxel_positions()`), so a roof sized to exactly its own
GU's 8×8 footprint only ever capped the near slice, never the far one —
visibly unfinished at every wall. **Ratified fix, real tracked geometry, not
a cosmetic fill:** `slab_generator.gd`'s new `generate_with_border()` grows
a roof's footprint by 1 voxel per side (8×8 → up to 10×10, origin shifted
toward `-1,-1`), reusing the *same* `Slab`/dirty-tracking machinery, not a
second untracked truth — Director: "a verdade nunca precisa ser lembrada."
Per-side, not uniform: a side is bordered only when nothing already roofed
sits there.

**Real bug found and fixed via the real map, not assumed safe.** The first
implementation computed "does this side face outside the block" only
*within one `solid_block_instances` entry* (correct for a genuine multi-GU
block's own internal seams) — but `roof_integration_selftest.gd`'s
independently re-derived geometry check caught **15 of 49 real PLAYGROUND
blocks with corrupted core voxels**: the map's own test fixture places 5
same-material blocks as 5 *separate* 1×1 declarations in a contiguous row,
not one multi-GU block, and GUs have **zero gap** between them — so each
side's border landed exactly on the neighbouring declaration's own core
row/column, not empty space. `room_builder.gd` corrected to compute
`roofed_gu_cells` **once, across every `solid_block_instances` entry on the
map**, then suppress a side whenever *any* roofed neighbour occupies it,
regardless of which declaration it came from — the same fix generalizes
correctly to both the multi-GU-single-block case and the
separate-adjacent-blocks case.
- **Evidence:** `roof_slab_selftest.gd` grew from 8/8 to **15/15 PASS** —
  new: `generate_with_border()` genuinely produces a 100-voxel (10×10)
  footprint at the correct offset; a single suppressed side produces exactly
  90 voxels, the other 3 sides unaffected; and the load-bearing one — two
  adjacent same-structure roof `Slab`s share **zero** voxel positions.
  `roof_integration_selftest.gd` (real PLAYGROUND map): the border-size
  and border-coverage checks now compute their *expected* footprint from the
  same map-wide adjacency the real code uses (not a blanket "every 1×1 block
  is 100 voxels" assumption, which stopped being true the moment the fix
  correctly started suppressing shared sides) — 5/5 PASS, including a direct
  check that **zero voxel positions are shared** between any two real,
  adjacent, roofed block-GUs on the actual map (the exact defect the fix
  targets). Full regression, same session: `floor_integration_selftest.gd`
  9/9, `negative_storey_selftest.gd` 12/12, `fixed_floor_selftest.gd` 5/5,
  `slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
  `slab_geometry_selftest.gd` 15/15, `bake_selftest.gd` 19/19.
  `project_lint.py`: 131 files, 0 real errors.

### Part 2c — Roof Surface Baking *(ROOF-BAKE-01/02, 2026-07-16, Overlord direct)*

**The "later experiment" from Part 2b's phasing, run and CLOSED as a
foundation.** Two commits, one session:

**ROOF-BAKE-01 (`c6edb71`)** proved the mechanism: `_get_plane_top()`'s
mapping `T(u−v, (u+v)/2)` was always an isometric projection of a flat 2-D
grid — walls consume it as `(column_in_run, level)`, a roof consumes the
same math as `(voxel_x, voxel_y)`. The screen offset between adjacent roof
voxels (±16, +8) equals the crop-window offset in the plane exactly, so a
roof top is seam-continuous **by construction**. First cut reused the wall
sheets keyed by global fine-grid position; the Director's visual review of
the real build (3 screenshots, 3 views) caught three real defects.

**ROOF-BAKE-02 (`f88d060`)** fixed all three:
- **02a** — `layout_with_perspective()` now rotates `solid_block_instances`
  (rectangle via two rotated corners) and `voxel_prop_instances` (points;
  all shipped PropDefs are 1×1). Roofs were being built in the N frame
  while their walls rotated — wood roofs on stone buildings in E/S views.
  Closes the old open item #7.
- **02b** — roof border adjacency is **level-aware**: suppress toward a
  neighbour roofed at the same level or higher (the taller wall's far-slice
  fills that seam column); grow an **eave** over a lower neighbour. Fixes
  the 1-voxel gap at every storey step.
- **02c** — dedicated `ROOF|mat|fac|col|row` page family: top diamonds
  project the **unscaled** facade (no wall ×20/16 pre-scale → isotropic,
  the 64×32 sheet covers the 1024×512 facade exactly), keyed by
  **structure-local** offsets (voxel − `Slab.texture_anchor`, one anchor
  per connected roofed-GU component, NW corner). Kills the world-line
  mirror folds (x=64k / y=32k) that crossed showcase roofs, makes
  same-material structures texture identically, and the pattern follows
  the structure across view rotations.

Full canon (projection math, key format, anchoring rule, fallback
contract): `docs/technical/BAKE_SYSTEM_REFERENCE.md` §"ROOF-BAKE".
Evidence: `roof_bake_selftest.gd` 8/8 — all expectations locally
re-derived (own fold, own flood-fill anchors, own E-rotation math); 2304
top-diamond pixels equal to a direct roof-plane read; 7778 real PLAYGROUND
roof voxels placed exactly as their local offset predicts; 49/49 blocks
roofed at their rotated E-view position with the correct material.

**Still open from this part** (visual polish, Director-judged): roof side
faces of border voxels still show dir-0 wall-plane content at arbitrary
rows (textured but wall-unaligned); per-material roof facades (metal's
facade laid flat is honest but may want dedicated art); occlusion
participation of roofs (Part 2b's original note stands).

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

**Status: ✅ DONE (foundation) 2026-07-22, "Alpha Grenade Foundation"
0.9.67.** Scope for this pass, ratified by the Director mid-session after a
web research round comparing Minecraft's ray/resistance model, XCOM 2's
ring-based falloff, Teardown's per-material toughness and Rainbow Six
Siege's soft/reinforced wall tiers: **GU-based ring falloff** (not exact
distance — ring 0 = the grenade's own GU, each further ring less damage),
applied identically to wall Slices and roof Slabs (same ring table, two
different adjacency graphs), **walls block/reduce propagation** (Director's
explicit choice over "ignore walls, distance only"), a **material resistance
table** converting ring damage into a destroy/crack voxel count, and
**deterministic** (FNV-1a hash-and-rank, no RNG) selection of which voxels.
Cover rule, noise-on-digging, rubble-as-terrain and the breach-as-clue
gameplay layer (this Part's own original scope) are **explicitly deferred**
— out of scope for this pass, not forgotten. Fire/smoke deferred to a later
session by the same Director call that scoped this pass.

- **Two real gaps found and closed, not assumed away:**
  - `VoxelRenderer.process_dirty()` existed (walls only); **nothing consumed
    `SlabRegistry.dirty_slabs()` on the render side at all** —
    `room.gd::_tic_slab_system()` only cleared dirty flags. Without a new
    `process_dirty_slabs()`, roof destruction (explicitly in scope —
    "incluindo os telhados," Director) would silently no-op. Added, with a
    landmine avoided in the process: `process_dirty()`'s own erase branch
    indexes `_voxel_layers[level]` raw (not the sign-aware `get_layer()`
    helper) — safe today only because it is fed exclusively by `Slice`s,
    whose levels are never negative. `process_dirty_slabs()` must not repeat
    that pattern (GDScript's Python-style negative array indices would
    silently erase the wrong layer for a negative/floor level) — routes
    through `get_layer()` instead.
  - D15's `voxel_destroyed(grid_pos, level, material_id)` signal was
    "✅ Ratified" in this plan's own decision register but had zero call
    sites anywhere in the codebase — never actually added. Added now, on
    `VoxelRenderer`, emitted from both erase branches.
- **New files** (`godot/scripts/systems/destruction/`): `bomb_def.gd` +
  `bomb_registry.gd` (mirror `PropDef`/`PropRegistry` exactly — two-tier
  `res://bombs` + `user://bombs`, plain objects with a `from_json()`
  factory, wired into `Registries` the same way material/prop registries
  are), `material_resistance_table.gd` (fixed table, not two-tier — engine
  tuning data, not content), `blast_calculator.gd` (the pipeline: wall-aware
  GU-ring BFS reusing `movement_overlay.gd`'s blocked-edge gate;
  `find_affected_containers()` — no separate "wall-run adjacency" mechanism
  needed, the GU flood's own sideways step already IS the wall-run step, via
  `EdgeRegistry.edges_touching_gu()`/`slices_of_edge()`; deterministic
  hash-and-rank voxel selection mirroring `EarthVariantSelector`'s FNV-1a
  pattern generalized from "pick 1 of 8" to "pick top N of M"). One real
  bomb type shipped: `bombs/frag_grenade.json`
  (`ring_multipliers: [1.0, 0.7, 0.35, 0.1]`, explicitly first-pass/tunable).
- **Vertical ring-step asymmetry, a deliberate judgment call, not an
  oversight:** walls advance one ring per storey (`LEVELS_PER_STOREY`, 8
  levels); roofs advance one ring per raw level, because `ROOF_LEVEL_COUNT`
  is only ~2 levels total — a whole-storey step would collapse every roof
  level into ring 0 and roofs would never show falloff at all. Flagged for
  review, not silently resolved.
- **`BlastWireframeOverlay`** (`godot/scripts/overlays/`): red outer-
  perimeter preview of the max-range GU footprint, shown while a grenade's
  context menu is open (Director: outer perimeter only, not per-ring
  opacity). Deliberately its own file, not folded into `movement_overlay.gd`
  (that overlay owns unrelated player-turn AP-zone state) — reuses its
  diamond-corner math and "draw an edge only if the neighbor isn't in the
  same set" perimeter rule verbatim, both already proven correct.
- **White screen flash** on detonation: the entire visual budget for the
  moment itself, by design — "por enquanto fica só a explosão," fire/smoke
  deferred. `room._flash_white()`, ~10 lines, no new class.
- **Evidence:** `blast_calculator_selftest.gd`, 11/11 PASS — unobstructed
  BFS ring distance, wall-blocked-edge exclusion, range capping, a real
  `Slice` picked up at ring 0 via `SliceGenerator`-built fixtures,
  determinism (two calls → identical subset) and non-degeneracy (different
  salt/container → different subset) of the hash-and-rank selector, metal
  producing mostly `CRACKED` not `DESTROYED` (38 vs 3 of 64), wood producing
  91% `DESTROYED` at ring 0, and a voxel group beyond the bomb's own range
  staying untouched (not clamped to the last ring). Full regression, same
  session: `slab_geometry_selftest.gd` 15/15, `roof_slab_selftest.gd` 15/15,
  `slab_render_selftest.gd` 8/8, `earth_variant_selftest.gd` 6/6,
  `floor_integration_selftest.gd` 9/9, `roof_integration_selftest.gd` 5/5,
  `negative_storey_selftest.gd` 12/12, `fixed_floor_selftest.gd` 5/5,
  `bake_selftest.gd` 19/19 — nothing broken. `project_lint.py`: 143 files,
  0 real errors.
  **Real-map proof, not just synthetic fixtures**: driven against the real
  PLAYGROUND grenades via `INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate`
  — direct `TileMapLayer.get_cell_source_id()` readback on 18 real destroyed
  voxels across 18 real `Slice`s, all `-1` (erased), matching a real,
  monotonically-decreasing-by-ring damage pattern (33/128 at ring 1, 14/128
  at ring 2, 3/128 at ring 3). One honest miss: no screenshot conclusively
  *shows* a crater — the grenade's omnidirectional blast reached a nearer,
  unanticipated wall (a `PLAYGROUND` partition between GU (3,3)-(3,4), not
  the intended row-2 test pillar) before several camera-reframing attempts
  could land a frame on it. Not treated as resolved — the cell-level
  readback is real evidence the mechanism works; the visual claim itself is
  unverified pending either a better camera pass or, per the Director, the
  lighting work below.
- **Why paused here and not carried further this session (Director,
  2026-07-22):** every voxel currently renders fully lit regardless of
  damage state — a crater is real (proven above) but reads as nearly
  invisible without shading to sell the depth/shape. Continuing to layer on
  more destruction mechanics (cover/noise integration, blast tuning, fire)
  before lighting can actually show the effect would be building on top of
  something nobody can see yet. Resume destruction work once lighting is
  addressed.

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
