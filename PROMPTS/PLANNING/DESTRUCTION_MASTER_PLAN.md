# DESTRUCTION_MASTER_PLAN
## Destructible Voxels, Voxel Floors & Slabs, Solid Texturing, View Occlusion — v1.0

**Status:** 🔵 DRAFTED 2026-07-12, not started. Authored by the Overlord from a
Director brainstorm (2026-07-11/12), decisions ratified in that conversation.
**Baseline:** tag `verified/v0.8.2`.
**Companions:** `docs/technical/BAKE_SYSTEM_REFERENCE.md` (bake canon),
`docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` (container/dirty/TIC
canon — **not obsolete**; it describes what was actually built).
**Supersedes:** nothing. **Unblocks:** `TOP_TEXTURE_MASTER_PLAN` Part 3
(textured interiors), which has been blocked on this plan's existence.

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
that we bolt a new voxel class onto an architecture whose invariants were
written for walls only.

Named pains this serves:
- **Split-brain state** (DORES #2) — the single sharpest risk here, see §3.
- Legacy floor artwork from the pre-voxel era is still shipping.
- `TOP_TEXTURE_MASTER_PLAN` Part 3 has been blocked with no plan to unblock it.

---

## 2. Decision Register

| D | Decision | Status |
|---|---|---|
| **D1** | **`Slab` is the container sibling of `Slice`.** A wall voxel belongs to a `Slice` which belongs to an `Edge`; a floor voxel has no edge, so it needs its own container to hold voxels, count dirty, and be skipped when clean. Floor, ceiling and interior slab are **one class**: a ceiling *is* a Slab at level N. Occlusion cutaway of interiors comes free with it. | ✅ Ratified |
| **D2** | **Solid texturing.** A voxel's atom is a function of `(x, y, depth)` inside the material volume — the texture lives *in* the material, and every object is a carve out of it. **Implement by generalizing `_compose_junction_pages()`, not by writing a new compositor**: a junction column is already a 1×1 solid column composed from `(col_x, col_y, level)`; a block is an 8×8 grid of them. | ✅ Ratified |
| **D3** | **`usage_cells` extended to the volume.** Compose only the voxels some object in the map actually uses, plus a one-layer "destruction-readiness" shell. Load cost becomes ∝ objects present, **not** ∝ material volume. This — not disk cache — is the real mitigation. | ✅ Ratified |
| **D4** | **Deterministic FNV-1a hash (B4) drives per-voxel variation.** ~8 base "earth" tops × ~8 shade steps, selected by `hash(x, y, level)`. Never stored, never saved, recomputed identically forever ⇒ zero memory, zero save state, **zero popping when a neighbour is destroyed**. | ✅ Ratified |
| **D5** | **LOD by damage.** An intact GU is **one baked tile** — and that tile is baked *from the same atoms, with the same hash*, so it is literally the composite of the 64 voxels it would explode into. First damage swaps 1 cell → 64 cells showing **identical pixels**, minus what was dug. The explosion is invisible; cost is paid only where destruction happens. An intact map costs exactly what it costs today. | ✅ Ratified |
| **D6** | **B5 amended: "no bake per FRAME", not "no re-bake".** Newly exposed faces ARE composed — at the **turn tick**, never per frame — with a hard cap of N voxels per detonation. N is a **balancing lever**, not an engineering one: weapon design bounds the worst case. *(The old B5 would have made the player dig into a beautifully textured block and see flat grey. It would have killed the entire payoff of D2.)* | ✅ Ratified |
| **D7** | **Depth is read through shading.** Same top texture at every depth would make a 1-voxel crater and a 3-voxel crater look identical. Darken with depth via the existing per-tile `page_modulates`. Free, and it converts D4's variation into **information** rather than noise. | ✅ Ratified |
| **D8** | **Destruction is an information transaction, not a power fantasy.** Digging is **loud** (a breach trades a new path against alerting guards); a GU dug past 50% becomes a **cover point**; rubble is **noisy terrain** (destruction poisons the path it opens); a breach is a **permanent clue** guards can notice and re-route around. | ✅ Ratified |
| **D9** | **Speculative pre-compute is DEFERRED.** Player thinking time is free compute and could pre-compose likely blast zones — but the turn budget probably already suffices, and building a predictor to save nothing is the classic trap. Decide by measurement, not by intuition. | ⏸️ Deferred |
| **D10** | **Occlusion is VIEW, not STATE.** It does not use the dirty flag, does not write `Voxel.visible`, does not persist, and never enters the save. See §3 — this is the load-bearing decision of the whole plan. | ✅ Ratified |
| **D11** | **Generic material atlas: demoted, not deleted.** Kill it as a *silent fallback* (a baked-lookup MISS must **loud-fail** per B6 — a silent grey cell is exactly the class of bug that let `blit_rect`'s silent clipping ship twice). Keep it as `MATERIAL_ONLY`, an **explicit dev toggle** (F7) — it is the bisection tool that answers "is this a bake bug or a geometry bug?", which is the single most valuable question when the bake breaks. **The look the Director likes (material colour showing through texture) is `MULTIPLY`, a blend mode — it does not depend on this fallback and survives its demotion.** | ✅ Ratified |
| **D12** | **Bake is the product.** Shipped default flips to `BakeConfig.enabled = true`. Consequence, stated plainly: **BAKE-CACHE-01 becomes a release blocker.** Today a slow warm boot (730–770 ms vs a 150 ms target) is tolerable because we could always ship with bake off and boot fast-and-ugly. That escape hatch closes here. | ✅ Ratified |
| **D13** | **The floor is a 2-layer slab: top destructible, bottom fixed bedrock.** This single constraint dismantles most of the problem — max excavation depth is **1 voxel**, so there is no infinite digging, no falling through the world, and no multi-level crater geometry. The destructible floor volume collapses from 8 levels to **one** (64 voxels per GU). Cover from a crater is therefore **prone-only**, earned when >50% of a GU's top layer is destroyed (>32 of 64 voxels) — by explosives, or by dozens of shots. A constraint that buys gameplay clarity and engine cheapness at the same time. | ✅ Ratified |
| **D14** | **Floor variety = N baked slab variants × per-cell symmetry. NOT a unique composite per GU.** The arithmetic settles it: a floor tile is 256×128 px, so a unique composite per GU on a 26×26 map costs 676 × 256×128×4 B = **88.6 MB** — dead on arrival for mobile. **16 pre-baked variants cost 2.1 MB.** Godot's TileMap carries per-cell transform flags (flip H / flip V / transpose) that live in the cell data and cost **not one pixel**: 8 symmetries × 16 variants = **128 apparent arrangements at the memory of 16**. *Implementation trap: mirroring the composite tile must mirror the 64-voxel index mapping it explodes into, or D5's pixel-perfect explosion breaks.* *(No conflict with D10's ghost alternatives: the floor never sits between agent and camera, so "ghost" and "symmetry" never meet on the same cell.)* | ✅ Ratified |
| **D15** | **Destruction emits a signal; VFX subscribes.** `voxel_destroyed(grid_pos, level, material_id)`, emitted at the TIC alongside the dirty pass. Smoke, debris and sound are **not** the destruction system's business — with no subscriber the signal costs nothing, and the particle ceiling is the same N as D6. Add the signal **now**, while it is one line, rather than refactoring later for the hook nobody left. | ✅ Ratified |

| **D16** | **Atoms + dirty flag are a PRODUCER for Godot's TileMap, not an alternative to it.** There is no "our system vs. native Godot" choice to make — rendering is 100% native `TileMapLayer` on both planes: an intact GU is one cell on the coarse layer (256×128 tile, per-cell transform flags for variety); a dug GU is 64 cells on the fine layer (32×16 tiles) — the exact mechanism the walls already use. Our custom code is only (a) the compositor that produces the atlas and (b) the dirty/TIC that decides *which cells to rewrite*. Neither draws anything; both are bookkeeping. **The two planes are exactly commensurate:** an 8×8 block of 32×16 iso voxel tops spans corners `(0,0)`, `(+128,+64)`, `(−128,+64)`, `(0,+128)` — a bounding box of **256 × 128, precisely the floor tile size**. So a GU's 64 voxel tops tile the floor tile with **zero remainder and zero resampling**: replacing the legacy floor assets with a baked slab composite is *exact*, and D5's invisible explosion is **guaranteed by construction**, not approximated. **Godot terrain autotiling** is useless for the crater *interior* (which of 64 voxels are gone is a 2⁶⁴ state space — no bitmask enumerates it; the fine plane is mandatory) but is the right native tool for the **coarse debris/scorch ring** on the GUs *around* a crater. | ✅ Ratified |

*(Numbering note: D12 here is local to this plan and unrelated to the global D12 "mobile budget" decision in `OVERLORD_CONTEXT.md`.)*

---

## 3. The single-writer table — read this before writing any code

The recurring structural pain of this project is **split-brain state**: two live
copies of one truth. This plan introduces three new systems that all want to make
a voxel disappear, and **they must never share a bit**.

`Voxel.visible` **already has an owner**:

```gdscript
## Apply damage state; DESTROYED forces visible=false
func set_damage(new_state: int) -> void:
    ...
    if new_state == DamageState.DESTROYED:
        visible = false
```

| Concern | Owns | Persists? | Cadence | May write `Voxel.visible`? |
|---|---|---|---|---|
| **Destruction** | `Voxel.visible`, `damage_state`, `blocked_cells`, cover, noise | **Yes** — it is world state, it enters the save | Per detonation (rare, capped by D6) | ✅ **Sole writer** |
| **Occlusion** | `_occluded_cells` (its own set) | **No** — it is a camera artifact | Per agent step + per camera rotation (**frequent**) | ❌ **Never** |
| **Fog of war** | Scenery discovery | Yes | Per agent step | ❌ Never |
| **Actor visibility** | Owned by the **agent-knowledge system** (radar / noise / line of sight) — a separate front | Yes | Per turn | ❌ Never |

**The bug this table prevents:** occlusion fades a wall → `visible = false` → the
TIC erases the cell → the player **rotates the camera** → occlusion releases →
`visible = true` → **and a destroyed voxel resurrects.** Save-corrupting,
gameplay-breaking, and it only ever reproduces when someone rotates the camera
over a crater.

**Cross-plan contract (binding on the agent-knowledge front):** an actor the agent
does not know about **is not drawn**. Actor rendering is owned by the knowledge
system and never by geometry. This is what makes wall transparency *incapable* of
leaking enemy positions — the guarantee is structural, not incidental. If anyone
ever makes actor rendering depend on geometry occlusion, this guarantee dies
silently.

---

## 4. Occlusion — the three problems hiding inside one word

"Occlusion" is three different needs. Only the third is occlusion.

**(a) "I can't see my agent behind a wall."**
Draw the **agent on top of everything**, with a **stroke on the portion of his
silhouette that is behind geometry** — a whole silhouette behind a wall, legs-to-
waist behind a crate. Reveals exactly one thing: your own guy. Touches no voxel
state. *No character animations exist yet → ships as a placeholder bounding box at
standing-character dimensions; the real silhouette is a future milestone.*

**(b) "I can't see inside a building."**
**Slab cutaway by level** (`layer.visible = false` on the ceiling Slab). Costs one
property. Here the reveal is *intentional* — entering the building is the reward
for infiltrating it. Comes free with D1.

**(c) "Foreground geometry is covering the agent."**
This is real occlusion. Mechanism:

1. **Who occludes (CPU, tiny).** An **enlarged circle around the agent**, keeping
   only geometry that is between him and the camera. **Not "everything south of the
   agent"** — fading the whole southern half would reveal the *neighbouring* room's
   interior, contradicting the design goal ("the player sees what the agent sees").
   The criterion is *"is it covering him"*, not *"is it south"*. Recomputed on agent
   step and on camera rotation; a few dozen cells.
   **"South" must be evaluated in the current view's rotated frame** — the map has
   four views and the formula rotates with them.
   **Depth is NOT `z_index`.** `layer.z_index = _wall_base_z_index + level` encodes
   **storey**, not depth: a wall in front of the agent and a wall behind him on the
   same storey share a z-index. Depth in isometric comes from world position
   (`x + y` in the rotated frame) / y-sort. Selecting by z-index would fade every
   upper storey *including everything behind the agent* — the opposite of the goal.

2. **How to paint it (zero extra memory).** Godot `TileData` carries a `modulate`
   per **alternative tile**, and alternatives **reuse the same atlas region** — so a
   "ghost" alternative at 5% alpha costs **not one extra pixel**. Placement already
   passes the alternative index:
   ```gdscript
   _voxel_layers[level].set_cell(pos, source_id, atlas_coords, 0)   # ← this 0
   ```
   Ghosting that band is **changing one argument**. No shader, no per-fragment
   cost, no D12 (mobile budget) sign-off needed.

   **Feathered edge — the trade-off, stated once.** A true soft gradient is a
   **shader**, i.e. per-fragment, i.e. it needs explicit Director sign-off against
   the mobile budget. The middle path, and the recommended v1: **three ghost
   alternatives (5% / 25% / 50% alpha) applied in concentric rings** — a *stepped*
   feather, which at 32 px cells reads as smooth in isometric, still costs **zero
   memory and zero per-fragment work**. If headroom later proves plentiful, swapping
   the rings for a shader changes nothing else: the occluded-cell set is identical.

3. **Where the state lives.** In `_occluded_cells`, owned solely by the occlusion
   system. See §3.

*Future milestone (not this plan):* ceiling-hung props and decorative parallax
elements in front of the camera also need occluding. Same mechanism, different
layer. Not implemented yet.

---

## 5. Numbers — what we actually know

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
| Warm boot (BAKE-CACHE-01, open) | **730–770 ms** vs 150 ms target | prior session |
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

---

## 6. Parts

### Part 0 — The measurement spike *(blocks everything; no code ships from it)*
The only honest way to start. Force-render the worst cases and **measure on the
target device**, not on the Mac:
- A fully voxelised 26×26 floor (43 264 cells) — frame time, memory.
- `TileMapLayer` count scaling: 1 layer per level, with floors + slabs + ceilings.
  **This is the suspected real ceiling.** Find where it breaks.
- Bake + warm-boot time with block volumes added.
Deliverable: a number for each, and a go/no-go on the layer-per-level model. If
layers are the wall, the fix (fewer layers, cells carrying level in the atlas, or
level batching) must be known **before** Part 1 is written.

### Part 1 — `Slab`, the container sibling *(D1)*
Floor/ceiling voxels get a container with dirty counting and TIC skip, mirroring
`Slice`. No destruction yet. Renders the existing floor identically (D5: intact GU
= 1 tile). Legacy floor artwork stays in place, unused, until Part 4 retires it.

### Part 2 — Solid texturing *(D2, D3, D4, D7)*
Generalise `_compose_junction_pages()` to `(x, y, depth)`. Extend `usage_cells` to
the volume. FNV-1a variation, depth shading. Still no destruction — this part is
verified purely by looking at intact geometry and at a *manually* carved block.

### Part 3 — The trigger *(D5, D6, D8)*
Wire the idle motor: a detonation marks voxels destroyed → dirty → TIC → newly
exposed faces composed at the tick, capped. Cover rule (>50% of a GU), noise on
digging, rubble as noisy terrain, breach as a persistent clue. **B5 amended here.**

### Part 4 — Bake becomes the product *(D11, D12)*
Silent fallback removed (loud-fail on MISS). `MATERIAL_ONLY` kept as a dev toggle.
Shipped default flips to `enabled = true`. **BAKE-CACHE-01 resolved — this part
cannot close while warm boot is 5× over budget.** Legacy floor assets retired.

### Part 5 — Occlusion *(D10)*
The three problems of §4. (a) agent-on-top with silhouette stroke (placeholder
bounding box). (b) Slab cutaway. (c) the ghost-alternative band.

---

## 7. Wave sequencing

```
Wave 0:  Part 0 (spike)            → a number, and a go/no-go on layers-per-level
Wave 1:  Part 1 (Slab)             → depends on Wave 0
Wave 2:  Part 2 (solid texturing)  → depends on Slab existing
Wave 3:  Part 3 (the trigger)      → depends on solid texturing (nothing to expose otherwise)
Wave 4:  Part 4 (bake as product) + BAKE-CACHE-01
Wave 5:  Part 5 (occlusion)        → independent of 1–4; can be pulled earlier if the
                                      Director wants a visible win sooner
```

Per the prompt-sizing rule: **a novel geometric transform is always its own
prompt** — Part 2's `(x, y, depth)` generalisation lands and is verified *before*
anything consumes it. Part 3 must not be bundled with it.

---

## 8. Open questions

1. **`TileMapLayer` count** — the one real unknown. Part 0 answers it.
2. **D9 (speculative pre-compute)** — deferred; revisit only if Part 0/3 measurements demand it.
3. **Rule 8 amendment** — the inviolable architecture rules say `set_cell()` /
   `_set_voxel_cell()` are for *wall/block* voxels. Slab voxels are a new class and
   need an explicit canon amendment, not a silent widening. Author it with Part 1.
