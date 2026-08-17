# DESTRUCTION_MASTER_PLAN
## Destructible Voxels, Voxel Floors & Slabs, Solid Texturing — v1.1

> ## ✅ CLOSED 2026-08-13, Director-ratified
>
> *"Pode fechar como won't do e fechar os dois planos."* Explosive destruction
> is owned by `EXPLOSION_REBUILD_MASTER_PLAN` (also closed the same day) and
> firearm destruction by `WEAPON_MASTER_PLAN`; both shipped. The 2026-08-13
> sweep corrected what this document still carried as open: D9 was ANSWERED by
> the prediction layer, D18's lazy-reveal trigger was BUILT on 2026-08-07, and
> the segment-reset design was telling implementers to snapshot `_base_soot`, a
> field D24 deleted in this very document.
>
> Genuinely still open and NOT this plan's to finish: the segment-reset/rewind
> system (its own milestone — the design here stands, minus that correction),
> on-device GPU cost of many TileMapLayers, and the gameplay layer this Part
> always deferred (cover rule, noise-on-digging, rubble-as-terrain,
> breach-as-clue). Glass belongs to the **materials milestone**.

> ## 🟡 REOPENED 2026-08-16 — for the destructive MATERIALS, and only those
>
> Director: *"Nós vamos fazer agora só os materiais destrutivos, pra fechar essa
> milestone de destruição. […] Basicamente vamos construir o vidro agora, que é
> mais trabalhoso, e botar fogo/buracos de bala em papelão e tecido. A partir daí
> a gente já tem uma base bem sólida para construir os cenários e trabalhar mais
> no personagem."*
>
> **This reverses one line of the closing note above**, and the reversal is
> deliberate rather than an oversight: that note sent *"Glass […] to the materials
> milestone"*. Glass now comes forward to close destruction instead, because the
> thing it unblocks is **building scenarios**, which everything else waits on.
>
> **Brick is explicitly OUT**, with the Director's reason: *"entra quase na
> categoria de concreto, mudando um pouco a resistência, então não tem muita
> importância agora."* A dedicated **materials milestone still comes later** — this
> pass closes DESTRUCTION, it does not try to finish materials.
>
> ### The seam for both was already built and left empty on purpose
>
> Checked 2026-08-17 rather than assumed:
>
> - **Glass is already registered and already ratified.** D22 fixed it as
>   **DESTROYED-only** — *"não vai ter dented; é buraco feito, ou não feito"* —
>   with dent/crack forced to `0.0` so the rule reads as intentional data rather
>   than an unlisted material, and `destroy_factor` set high as a first-pass
>   placeholder. D32 reaffirmed it gets no DENTED/CRACKED tier at all.
>   **What is genuinely missing is the one thing that makes glass glass**, and
>   this document already names it as open (§7 item 4): the cascade beyond the
>   normal ring falloff — *"grandes chances de levar vários voxels em volta, ou
>   quebrar a janela inteira"*. That is why the Director calls it *"mais
>   trabalhoso"*: every other material's damage is local, and a window is not.
> - **Fabric and cardboard have a column waiting.** `MaterialResistanceTable`
>   carries `DEFAULT_FLAMMABILITY` with a comment that names them by name —
>   *"cardboard, fabric, awnings that block light until they burn"* — and states
>   it is *"the column those materials will fill in, nothing more"*. The gate
>   semantics are already fixed: `0.0` means does not catch at all, above that
>   scales how long the glow lives, wood is the reference at 1.0.
>
> **So this wave is: one hard problem (glass's non-local break) and one column to
> fill (flammability, plus bullet holes on two soft materials).** Sizing it as
> three equal materials would be wrong.
>
> ### Questions to settle before authoring, not during
>
> 1. **What is a "whole window"?** Glass's cascade needs a notion of a connected
>    pane. Voxels have no grouping today; the wall's own `Edge`/slice structure is
>    the nearest existing thing. Whether a pane is derived from contiguous glass
>    voxels or authored in the mapfile is a design question with a cost
>    difference, and it is the one that decides how big this is.
> 2. **Does a shot through glass keep travelling?** D28 already rules that a
>    fully-penetrated path leaves no mark anywhere. Glass is the first material
>    where penetration is the *expected* case rather than the extreme one.
> 3. **What does "fogo" mean mechanically for fabric/cardboard?** The existing
>    ember is a decorative glow with a lifetime. Burning *through* — the Director's
>    own wider intent quoted in the table — *"light wood walls that burn through
>    into a new passage"* — is a destructive state change and a much bigger claim.
>    Which of the two this wave delivers should be stated up front.
> 4. **Do fabric and cardboard block light before they burn?** The table's comment
>    says *"awnings that block light until they burn"*, which couples this to
>    `LIGHT_MASTER_PLAN`. Out of scope unless the Director wants it in.

**Status:** ✅ **CLOSED 2026-08-13** — previously: 🟡 **UNBLOCKED, 2026-07-26.** Paused at Alpha
Grenade Foundation, 2026-07-22, precisely because "every voxel currently
renders fully lit regardless of damage, so a crater's depth/shape reads as
close to invisible." `VOXEL_LIGHT_MASTER_PLAN.md` (VL-01 → VL-D5, "Alpha
Temporal Light Foundation") shipped 2026-07-23 → 2026-07-26 and explicitly
names this plan as the thing it was a prerequisite for — its own status
header says so directly: **"that blocker is now closed."** Destruction craters
now read visually (soot rings, contiguous radial floor crater, directional
blast bias, under-wall darkening, ember→char glow on combustible material) —
see `VOXEL_LIGHT_MASTER_PLAN.md` for the mechanism, **including that item 4's
ember half was dead code from 2026-08-05 to 2026-08-13** (deleted by the
`[RESET]`, not restored by the E-WAVE reconnect, and described as shipped by
three documents in between) and now runs off the material table's
`flammability` column rather than a hardcoded wood check. Part 0 (spike), Part 1
(`Slab`), Part 2 core+consumer (floor), Part 2b (roof/ceiling Slabs) and
**Part 3 (the trigger) DONE** — see Part 3's own status block below for the
full account. The idle motor D15/D6 described is no longer idle: a real
grenade in the real running game marks real voxels destroyed, through the
real dirty-flag/TIC pipeline, confirmed by direct `TileMapLayer` cell
readback (not code-reading). **Resumed 2026-07-30/31**, alongside the parallel
`WEAPON_MASTER_PLAN.md` firearms work: D22–D24 shipped (two non-destroyed
damage tiers per material, DENTED-before-CRACKED ring draw, blast marks in
their own irregular texture family distinct from bullets, soot derived fresh
every repaint for both explosions and firearms instead of stored). §7 item 6
closed the same arc with **D25** (a DENTED voxel is a carved half-voxel,
oriented by where the blast came from), and **2026-08-01 closed D25's own
loose end with D26**: the floor dents too, prevalence scaling from the product
of the destruction variables already in play, which finally makes the `_top`
carved variant reachable. The blast floods also stopped propagating through
solid `spec.blocks` obstacles that session — the consequence
`WEAPON_MASTER_PLAN.md` flagged rather than fixed on 2026-07-30.
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
| **D13** | ~~The floor is a 2-layer slab: top destructible, bottom fixed bedrock.~~ **CORRECTED 2026-07-16 (Director's design pass — see D17, D18).** The floor is a per-GU **8-level stack living in a new negative storey** (storey −1, levels −8..−1), not a 2-level shape. Only the **top level** (level −1, immediately below storey 0 where walls/world begin) is a real `Slab` — destructible, dirty-tracked. The other 7 levels (−8..−2) are fixed: never destructible, never even instantiated as a `Slab`/`Voxel` until D18 exposes them. Max excavation depth stays **1 voxel** (same gameplay clarity as the original constraint), and digging can never reveal a void — the fixed levels back-stop it *by construction* (there is no code path that ever marks them dirty), not merely by design discipline. Crater cover remains **prone-only**, earned when >50% of the top level's 64 voxels are destroyed. **AMENDED 2026-07-28 — see D19:** the destructible plane count is now 2 (levels −1 and −2), max excavation depth 2 voxels; the fixed-by-construction back-stop moves down to levels −8..−3 and is otherwise unchanged. | ✅ Ratified (corrected, amended) |
| **D14** | **Floor variety = N baked slab variants × per-cell symmetry. NOT a unique composite per GU.** The arithmetic settles it: a floor tile is 256×128 px, so a unique composite per GU on a 26×26 map costs 676 × 256×128×4 B = **88.6 MB** — dead on arrival for mobile. **16 pre-baked variants cost 2.1 MB.** Godot's TileMap carries per-cell transform flags (flip H / flip V / transpose) that live in the cell data and cost **not one pixel**: 8 symmetries × 16 variants = **128 apparent arrangements at the memory of 16**. *Implementation trap: mirroring the composite tile must mirror the 64-voxel index mapping it explodes into, or D5's pixel-perfect explosion breaks.* | ✅ Ratified |
| **D15** | **Destruction emits a signal; VFX subscribes.** `voxel_destroyed(grid_pos, level, material_id)`, emitted at the TIC alongside the dirty pass. Smoke, debris and sound are **not** the destruction system's business — with no subscriber the signal costs nothing, and the particle ceiling is the same N as D6. Add the signal **now**, while it is one line, rather than refactoring later for the hook nobody left. | ✅ Ratified |
| **D16** | **Atoms + dirty flag are a PRODUCER for Godot's TileMap, not an alternative to it.** There is no "our system vs. native Godot" choice to make — rendering is 100% native `TileMapLayer` on both planes: an intact GU is one cell on the coarse layer (256×128 tile, per-cell transform flags for variety); a dug GU is 64 cells on the fine layer (32×16 tiles) — the exact mechanism the walls already use. Our custom code is only (a) the compositor that produces the atlas and (b) the dirty/TIC that decides *which cells to rewrite*. Neither draws anything; both are bookkeeping. **The two planes are exactly commensurate:** an 8×8 block of 32×16 iso voxel tops spans corners `(0,0)`, `(+128,+64)`, `(−128,+64)`, `(0,+128)` — a bounding box of **256 × 128, precisely the floor tile size**. So a GU's 64 voxel tops tile the floor tile with **zero remainder and zero resampling**: replacing the legacy floor assets with a baked slab composite is *exact*, and D5's invisible explosion is **guaranteed by construction**, not approximated. **Godot terrain autotiling** is useless for the crater *interior* (which of 64 voxels are gone is a 2⁶⁴ state space — no bitmask enumerates it; the fine plane is mandatory) but is the right native tool for the **coarse debris/scorch ring** on the GUs *around* a crater. | ✅ Ratified |
| **D17** | **Floor lives in negative storey space; everything else stays exactly where it is.** Walls/blocks/props keep their existing storey-0-and-up placement completely unchanged. Audited and confirmed: the only two places a wall's base storey is decided are `edge_extractor.gd:97` (`"min_storey": 0` for ordinary walls) and `room_builder.gd:611` (per-block authored `storey` value, read as-is) — neither is touched by this decision. Occlusion's base band (`OcclusionSet.BASE_VISIBLE_LEVELS`) is already relative to each edge's own base level, not an absolute 0, so it follows for free. This confines the entire floor-geometry effort to `VoxelRenderer`'s own internal bookkeeping: `_voxel_layers` moves from a 0-based `Array[TileMapLayer]` to a `Dictionary[int, TileMapLayer]` keyed by the true (possibly negative) level — GDScript's `array[-1]` means *last element*, not *grow downward*, and `_set_voxel_cell()` previously hard-rejected `level < 0` outright. **Alternative considered and rejected:** shifting every wall/block/prop up a full storey so the floor could occupy storey 0 conventionally — rejected because it touches the tested, working wall/junction/occlusion pipeline across multiple files for no functional gain negative storey doesn't already deliver at lower risk. | ✅ Ratified |
| **D18** | **Lazy reveal: nothing below the top destructible level exists until digging exposes it.** Not the 7 fixed floor levels, not deeper cosmetic storeys (storey −2 and below — lava, water, smoke; purely decorative background, never interactive, never a `Slab`, glimpsed only through a crater with a small parallax offset selling depth). An intact map's floor cost is therefore **one level's worth of cells per GU** — matching the Part 0 spike's real measured baseline (43 264 cells / 34.84 ms / 10.70 MB for a full 26×26 map, Test B), **not** multiplied by 8 or by however many cosmetic storeys exist below. This is D3 (`usage_cells`) and D6 (tick-capped composition) applied to depth, not a new principle: cost follows what is actually visible, not what could theoretically exist. Deeper cosmetic storeys additionally need no `Slab`/`Voxel`/dirty-tracking machinery at all — low-detail, low-randomness "vector voxel" materials, rendered only for the small area an actual hole exposes. | ✅ Ratified |

| **D19** | **The destructible ground is TWO planes, and the deep one only cedes at the epicentre.** *(Director, 2026-07-28 — amends D13's "only the top level is a real `Slab`", leaves D17/D18 intact.)* `FLOOR_DEEP_LEVEL` (−2) is now a real `Slab` per GU alongside `FLOOR_TOP_LEVEL` (−1), so a crater has a second storey to dig into instead of bottoming out on bedrock the instant the surface goes. It is **harder to destroy**: it takes damage only inside the blast's own GU (ring 0) and only across `BlastCalculator.DEEP_FLOOR_CRATER_FACTOR` (0.5) of the surface crater's radii — the hole narrows with depth (a bowl, not a shaft), and one grenade can no longer strip the whole ground stack across every GU it merely reaches. The surface plane's behaviour is unchanged. Max excavation depth becomes **2 voxels**; D13's "digging can never reveal a void" still holds by construction — the 6 remaining fixed levels (−8..−3) are still never instantiated as `Slab`/`Voxel`. **D18 is respected, not weakened:** the deep plane is *generated* at build (it must be real `Voxel`s to take damage, persist through rotation, and re-render through the dirty-flag machinery) but **not rendered** — it is fully occluded by the plane above, so its cells are placed only when a hole actually exposes it (`VoxelRenderer.reveal_floor_slab()`). Intact-map cell cost is therefore still one level's worth per GU, exactly as D18 requires; the added cost is ~30 k `Voxel` objects and **+40–100 ms on a 3.2 s PLAYGROUND build** (measured, 26×18). | ✅ Ratified |
| **D20** | **The ground bake covers the two structural planes; below them is dirt.** *(Director, 2026-07-28.)* This **reverses FLOOR-ZONE-BAKE §3b's stated assumption** ("destruction always reveals plain `earth`, never a zone's declared surface"), which was explicitly flagged as an assumption to revisit "once destruction and floor zones are actually seen together in a real played room" — they were, and the exposed generic earth read as a bug. Both `Slab` planes (−1, −2) carry the zone material, painted through the same baked page, which `VoxelRenderer.set_floor_zone()` also makes reachable from the FIXED levels (they place cells directly and have no container to read a material off). **Amended within the day**: the paint floor moved from −3 to −2 — Director asked for "as duas primeiras camadas de cimento, e a terceira de terra", which is both the better read (a concrete slab sitting on dirt) and free (the earth variants are already in the material atlas; a *photographic* dirt would be another baked ground material — see D21's measured cost). Levels −3..−8 are plain earth. | ✅ Ratified (amended) |
| **D21** | **Depth reads as tone, and the ground-bake budget is per MATERIAL, not per level.** *(Director, 2026-07-28.)* `VoxelRenderer.FLOOR_DEPTH_DIM` = `[1.0, 0.70, 0.45, 0.34, 0.28]`, a node-level modulate per negative TileMapLayer. Ramp picked by measurement, not by eye (four candidates, same real detonation, map flicker held off so lighting was identical; level −2/−3 pixels segmented against a no-dim reference): with no dim the deeper level came out *brighter* than the one above it (the soot BFS reaches it with a fainter ring) — an inverted depth cue. Soot **adds** to this rather than being lightened out of the way (an attempt at the reverse, capping the exposed floor at the faintest ring, was tried and rejected the same day — "não ficou bom clareando pra dentro"); losing the texture to shadow at the bottom is accepted. Final strata on a real lit crater: **161 / 51 / 22 of 255** (100% / 32% / 14%). **Measured bake budget** (PLAYGROUND, real boot): 17 pages, **75.9 MB RGBA8** total, of which the single `ground_concrete` floor page is **18.0 MB** (4096×1152) and each wall facade page 20.3 MB. So D18's decorative storeys (water, smoke, lava) are nearly free as *levels* — cells exist only where a hole exposes them — but cost **~18 MB of atlas per new baked ground MATERIAL**. That, not the storey count, is the mobile ceiling to watch; the mitigations (smaller tiling period for flat ground pages, VRAM compression, on-demand material bake) are unexplored. **⚠️ NUMBERS SUPERSEDED 2026-08-08 by D34/E-SEAM-01 — the conclusion stands, the accounting changed.** There is no `ground_concrete` page any more: a structural material's floor and its roof now bake ONE shared `<material>|facade_<material>` page instead of two, so the per-material ground cost this bullet warns about is no longer paid twice for a material used on both surfaces. PLAYGROUND (which declares the same four materials as blocks AND as floor zones) composes **4** horizontal pages, not 8. The "~18 MB per new baked ground MATERIAL" ceiling still applies to genuinely floor-only materials (the `slab_*` organic ground — grass/dirt/sand/gravel), which have no roof to share with. Re-measure before citing these figures. Note also that this ramp will be wrong for a lava level, which is a light *source*. | ✅ Ratified |
| **D22** | **Non-destroyed damage is TWO tiers, not one, and every material can reach every tier.** *(Director, 2026-07-30, closing WEAPON_MASTER_PLAN §7a S2.)* `Voxel.DamageState` gains `DENTED` (sunken, its own "special piece" texture — *"1 voxel ficou meio afundado, pecinha especial com textura da bala"*) alongside the existing `CRACKED` (flat surface mark, no sinking — *"voxel atingido ficou só marcado com a textura especial da bala"*), both short of `DESTROYED` (*"2 voxels destruídos por inteiro (furou)"*). **This retracts S2's original framing** (stone stays whole, only metal dents) — *"a pedra não necessariamente precisa ficar intacta, pode afundar também, assim como o metal pode ser perfurado também. Todos os materiais podem ter todos os estados."* What decides which tier a given voxel lands in is **material durability × weapon punch × dice**, exactly D12's existing hit/damage roll model — no new probability concept, just a third bucket in it. `MaterialResistanceTable` gained `dent_factor` alongside `destroy_factor`/`crack_factor` for all four canon materials (placeholders, a balancing lever like the rest of the table); `BlastCalculator.apply_container_damage()` now draws `destroy_set` → `dent_set` → `crack_set` progressively from the same ring group's remaining pool, DENTED before CRACKED so a voxel qualifying for the harsher tier never falls through to the milder one. Every delivery shape gets this for free — `apply_container_damage()` is the single sink `RADIAL`, `CONE` and (once built) `LINE` all call. **Wired to a real visual same day** (§7 item 4 below): a dedicated impact-mark tile per material/tier, placeholder "vector" art now, real photographic bakes to drop in later with zero code changes — verified by real capture, not just selftests. **Glass added as the 5th wall material, DESTROYED-only by design** (*"não vai ter dented; é buraco feito, ou não feito"*) — registered in the data tables but not yet wired into a bench row or given its wider-cascade destruction behaviour, both explicitly deferred. | ✅ Ratified — logic AND placeholder-art layers shipped 2026-07-30 |
| **D23** | **A DENTED/CRACKED mark reads differently depending on cause: a bullet leaves a round puncture, a blast leaves an irregular chip/crack — never the same texture family.** *(Director, 2026-07-30: "a granada produzindo buracos de bala, que não faz sentido. A gente pode criar estados intermediários do material em explosões, mas não com furos redondos.")* `Voxel` gains `damage_is_blast: bool`, set once on the transition into DENTED/CRACKED via `set_damage(new_state, from_blast)` and left alone on a repeat hit into an already-marked voxel (same early-return discipline `damage_state` itself already had). `BlastCalculator.apply_container_damage()` (the RADIAL/blast sink) passes `from_blast=true`; `apply_point_impact()` (the CONE/LINE bullet sink, D28) leaves the default `false`. `VoxelRenderer.MATERIALS` gains 8 new entries — `<material>_blast_dented`/`<material>_blast_cracked` for concrete/metal/stone/wood — and `damage_variant_material(base_material, damage_state, blast_sourced)` picks the `_blast_` family when `blast_sourced` is true, wired at all 3 call sites (`_render_slice`, `process_dirty`, `process_dirty_slabs`) via `voxel.damage_is_blast`. Placeholder art (`generate_voxel.py`'s new `generate_blast_mark()`) is deliberately built from a jagged fixed polygon outline plus branching crack line segments, never `draw.ellipse` — the "não com furos redondos" constraint is structural in the generator, not a visual accident. **Real capture**: a grenade detonated against the concrete test-zone wall shows a blocky, irregular gouge pattern on the wall face (`Screenshots/history/auto_2026-07-30_23-31-40.png`) — visibly distinct from the round bullet marks D22 already shipped. **Amended 2026-07-31 — size, not distribution:** the Director still saw a "buracos de bala" scatter after this shipped, and the actual cause was upstream of the texture — `apply_container_damage()`'s ring-group scatter (D22, unchanged) picks many separate, non-adjacent voxels per blast (a real detonation log: ring 1 alone produced 13 DENTED + 10 CRACKED, 23 isolated single-voxel picks), so even a correctly-jagged mark still read as a pinprick spray at the original small size. Chose to widen each individual mark toward the top-face diamond's own edges (`_BLAST_DENT_OUTLINE`/`_BLAST_DENT_CHIP`/`_BLAST_CRACK_LINES` roughly doubled, crack line width 1→2) rather than touch the scatter algorithm — picks that land on neighbouring voxels now visually merge into one blotch instead of staying legible as separate dots. **Real capture, same wall/framing**: `Screenshots/history/auto_2026-07-31_00-45-40.png` shows contiguous connected damage instead of scattered pinpricks. `blast_calculator_selftest.gd` unaffected (35/35 — pixel art carries no tested logic). | ✅ Ratified & shipped 2026-07-30, amended 2026-07-31 |
| **D24** | **Soot for BOTH explosive and firearm damage is derived fresh every repaint from which voxels are currently absent — never stored on the Voxel.** *(Director, 2026-07-30, shipping §7 item 5 / WEAPON_MASTER_PLAN §7a S3: "queremos o sistema de derivar a fuligem de acordo com os voxels faltantes, em vez de guardar a informação de cada um.")* `Voxel.soot_ring` is deleted outright — `BlastCalculator.compute_soot_rings()` (which mutated it in place) becomes `derive_soot_rings(cell_to_voxel, destroyed_cells, n_rings, out_snapshot)`, the same multi-source BFS but writing into a caller-supplied `{level: {grid_pos: ring}}` map instead. `room._build_soot_snapshot()` no longer takes a seed list from the caller — every repaint it walks the WHOLE map fresh (every Slice/Slab voxel, both live registries), builds its own `cell_to_voxel` + `destroyed_cells` from current state, and calls `derive_soot_rings()` once, globally. `room._base_soot` is deleted — nothing extra needs to persist for soot to survive perspective rotation, since `_base_damage` already persists which voxels are destroyed and that alone is what soot re-derives from. Both callers (`TestZoneController.detonate_active()`, `WeaponBenchController.fire_active()`) dropped their local soot bookkeeping entirely; the ember "is this wood voxel freshly scorched" check (previously `v.soot_ring == 0`) became a direct 6-neighbour absence check (`_is_freshly_scorched()`) since the per-voxel field it used to read no longer exists. *(2026-08-13: that helper no longer exists either — deleted with the rest of the ember path by the 2026-08-05 `[RESET]`. E-EMBER-01 rebuilt the identical predicate inside `DetonationPlanBuilder._build_ember_wave()`, gated on `MaterialResistanceTable.flammability()` instead of a wood literal. The derivation described here is unchanged; only its address is.)* `VoxelLightField.soot_factor()` is unchanged — it already consumed the `{level: {cell: ring}}` shape, so nothing downstream of the snapshot moved. Firearm soot (`WEAPON_MASTER_PLAN.md` D17's "no rings, face-local only") is superseded: a bullet hole now shares the exact same up-to-3-ring BFS a blast uses, and self-limits to ~1 ring in practice only because an isolated hole has no further-out absent neighbours — not because of a separate, capped mechanism. **Verified**: `blast_calculator_selftest.gd` 35/35 (both soot tests rewritten against the new signature, reading the snapshot dict instead of a per-voxel field); real capture of a 24-pellet shotgun blast against the wood test-zone wall shows dark, diffuse scorch patches spreading past the impact marks themselves (`Screenshots/history/auto_2026-07-30_23-36-21.png`), not just the marks in isolation. **Amended 2026-08-01 (FACE-SOOT-01): soot is now derived PER VISIBLE FACE, not per voxel.** `derive_soot_rings()` gained `out_faces`, filling `{level: {cell: Vector3i(ring_top, ring_se, ring_sw)}}` alongside the unchanged isotropic ring map (proven byte-identical either way by a new selftest). The direction is free: the BFS already knows the step it reached a voxel through, so its negation points at the hole — that face keeps the voxel's ring, the other two fall one ring back, and ties merge per face so a corner voxel scorches on every side that saw a hole. Delivery is `TileData.modulate`'s ALPHA channel (a 6-bit code, 2 bits per face), NOT the R/G/B packing `VOXEL_LIGHT_MASTER_PLAN` proposed — measured before building: RGB already carries the material's colour on the baked path, so packing luminances there destroys it. Blast and firearm soot still share this one mechanism, so a bullet hole gets directional soot for free. Real PLAYGROUND detonation: 1606 sooted voxels, 70.0% with genuinely differing faces; SE/SW histograms swap correctly on rotation to E. **Amended 2026-08-03 (D33-SOOT-01): a DENTED/CRACKED voxel that never sits next to an actual hole still gets a faint self-soot on its own struck face.** Director report: shotgun on metal, pistol on stone/metal left dents and bullet-hole decals with zero soot — "precisamos adicionar um pouquinho de fuligem, só pra diferenciar do resto da parede." Root cause: `derive_soot_rings()` only ever seeds its BFS from `DESTROYED` voxels; pistol/metal, pistol/stone and shotgun/metal structurally never cross `PUNCH_DESTROY_MIN` given `RESISTANCE`'s current values (always land DENTED/CRACKED), so those combinations never produced a hole to seed from — a real, generalizable gap, not weapon/material-specific. `BlastCalculator.apply_self_soot()` (a small, non-propagating addition — no BFS, no neighbour spread) applies exactly one faint ring (`SELF_SOOT_RING = 2`, the lightest of the three, `0.63×`) directly on the damaged voxel's own visible face, mirroring the SAME face-selection rules the D33 decal system uses for the mark itself (a bullet's lateral face; a blast-CRACKED voxel's all three faces per D32.3; DENTED's carved_side IS the face, except BOTTOM/ceiling which stays clean). Merged into whatever the BFS already produced with min-wins, so a voxel beside a real hole keeps its stronger ring. Not a reversal of D17/D24's "a bullet marks its impact, it does not blacken the wall" — the mark still never propagates to neighbours, only reads as very slightly scorched itself instead of pristine. Verified: `blast_calculator_selftest.gd` 7 new tests (65/65 total) covering every face-selection case + the merge-never-weakens contract; real captures confirm all three reported combinations (`INFILTRAITOR_CAPTURE_ACTION=weapon_fire`, `INFILTRAITOR_FACE_SOOT_DIAG=1`): shotgun/metal 0→9 sooted voxels, pistol/metal 0→1, pistol/stone 0→1. | ✅ Ratified & shipped 2026-07-30 — supersedes `WEAPON_MASTER_PLAN.md` D17 for firearm soot; amended 2026-08-01, amended 2026-08-03 |

| **D25** | **A DENTED voxel is a HALF VOXEL carved on the side that faced the blast — not an intact cube wearing a mark.** *(Director diagram, 2026-07-31, closing §7 item 6: "o voxel fica com metade em alpha e acrescenta uma face pre-baked pra cada material".)* Four variants, named by which side the blast ate: **`_bottom`** (blast from below → ceiling voxel; keeps the top, bites the underside along a jagged edge, and is the ONLY variant with no broken-face texture at all — *"para os voxels do teto é só esconder a metade de baixo"*, and an isometric camera never sees a ceiling's underside); **`_top`** (blast from above → floor voxel; the whole top sinks and the new upper surface is broken material); **`_left`** and **`_right`** (a wall, cut by a vertical plane **parallel to the face that took the blast**, so the whole struck face goes and the opposite one is only halved — the diagram's "ALPHA LEFT FACE" + "HALF TOP FACE" + "HALF RIGHT FACE"; `_right` is the exact horizontal mirror, the diagram's own "flip horizontal", so the pair can never drift). *Cutting parallel to the OPPOSITE face was the first attempt here and preserved the struck face whole — the mirror of what a blast does; caught by rendering it and comparing against the diagram, not by reasoning.* **The broken face is a deliberately decoupled, swappable asset**, not a tinted copy of the material: *"a face quebrada não precisa ser igual ao restante do material [...] paredes de concreto com várias cores diferentes não vão ter o mesmo voxel quebrado por dentro."* One generic grey fracture (`broken_face_generic.png`, deterministic, B4-style hashed) serves every material until real art lands; a per-material `broken_face_<material>.png` drop-in overrides it with zero code changes. **Selection is by blast GEOMETRY, not container role** — `BlastCalculator.carved_side_for()`: a roof is by construction above whatever blast reached it, so it carves BOTTOM (this is the §7-item-6 fix); a wall resolves left/right in SCREEN space by the sign of (x − y), so any of the four horizontal faces — including back-facing NE/NW — still resolves to a carve the camera can see. **Fixes a second, pre-existing bug in passing**: `room._base_damage` stored only `damage_state`, so every rotation replayed `set_damage()` with default arguments and silently reverted D23's blast marks to the BULLET family. The record is now `[damage_state, is_blast, dir]` with `dir` in BASE space, and the carved side is re-derived per view — a hole stays on the physical side that faced the blast instead of following the screen. `_top` is generated and wired but not yet reachable at runtime: floors currently only ever DESTROY (`apply_crater_damage`), never dent. CRACKED and bullet marks are untouched — the Director is specifying their analogous mechanisms separately. **Evidence**: `blast_calculator_selftest.gd` 41/41, including a same-view round-trip across all four perspectives, a LEFT carve in view N reading RIGHT from view S (180°), and BOTTOM proven rotation-invariant — all against the real functions, not a reimplementation. Real capture `Screenshots/history/auto_2026-07-31_21-28-45.png`. | ✅ Ratified & shipped 2026-07-31 — closes §7 item 6 |

| **D26** | **The floor dents too, and how often is the product of every destruction variable already in play.** *(Director, 2026-08-01: "implementando o dent no chão também, sendo mais ou menos prevalente de acordo com a soma de todas as variáveis de destruição.")* Closes D25's own loose end — `_top` was generated and wired but unreachable, because `apply_crater_damage()` only ever DESTROYED. A floor voxel that **survives** the crater's destroy roll, plus any voxel in a band one rim-width **past** the crater, takes a second independent roll into `DENTED` with `CarvedSide.TOP` — a floor is only ever eaten from above, the exact mirror of D25's ceiling-only-BOTTOM rule. Prevalence multiplies the three variables that already exist: the material's `dent_factor` (`MaterialResistanceTable`), the bomb's size (`core_radius`/`max_radius` set both the band's width and where the falloff sits), and the voxel's distance (full factor out to `max_radius`, fading linearly to zero across one further rim-span). The dent roll uses its own salt, so surviving the crater does not correlate with denting, and it **never changes which voxels the destroy roll takes** (verified). `material` is a trailing defaulted parameter — absent means `dent_factor` 0.0, so every pre-existing caller and test is byte-for-byte unaffected. **The ground_\* zone materials were given table rows here, and that was not optional**: PLAYGROUND's floor is a single `ground_concrete` zone covering all 24×16 GUs, so with only `earth` in the table the feature produced **literally zero dents on the only map it is tested against** (measured across 42 affected floor slabs). **Render side — the trap that would have shipped silently**: a zoned floor composing `"ground_concrete_blast_dented_top"` misses `MATERIALS` entirely, and `_set_voxel_cell()`'s `MATERIALS.find()` returns −1 → `source_id` 0 → the voxel repaints as **flat concrete** in the middle of the crater rim. `VoxelRenderer.floor_damage_material()` routes every ground material's dent to the ONE shared carved-TOP asset instead, which is D25's existing decoupled-broken-face rule rather than a floor-specific shortcut. **⚠️ PARTIALLY REVERSED 2026-08-08 by D34/E-SEAM-02:** the render-side trap this bullet describes was real and is still avoided, but "ONE shared asset for every ground material" was only ever right while the floor was only ever earth. `decal_dent_concrete/metal/stone/wood_*` exist on disk and were already used by WALLS, so a concrete floor was wearing an earth pockmark for no reason. `floor_damage_material()` takes the material now and names by it (`concrete_blast_dented_top_N`); the shared earth family is demoted from the rule to the **fallback** for materials with no decal art of their own — where D25 was always correct, and where `earth`/`grass`/`dirt`/`sand`/`gravel` still land. The `ground_*` names in this bullet are also pre-D19 history: those ids were unified to bare `concrete`/etc. **Evidence**: `blast_calculator_selftest.gd` 48/48 (placement bounds, blast+TOP provenance, monotonic prevalence metal 129 > earth 69 > concrete 42, destroy count unchanged); `slab_render_selftest.gd` 12/12 including a `source_id`-level assertion on BOTH render branches that explicitly fails on the flat-concrete fallback; real captures `Screenshots/history/auto_2026-08-01_01-05-08.png` (crater with dents fading outward) and `auto_2026-08-01_01-09-55.png` (same damage after a rotation to view E, via the new `INFILTRAITOR_CAPTURE_ROTATE_AFTER` knob — rotation persistence proven, not assumed). | ✅ Ratified \& shipped 2026-08-01 — closes D25's `_top` gap |

| **D30** | **One readable coefficient, `punch`, decides everything a single projectile does — and neighbours may be DESTROYED but are NEVER marked.** *(Director, 2026-08-02, answering four questions posed before any code was written.)* `punch = PUNCH_GAIN x weapon_punch x skill x distance x luck / resistance`, every factor centred on 1.0 so the number printed on the `[SHOT]` line is directly readable; it replaces D28's three-way probability roll, because *"a marca vai afundando conforme a potência do tiro"* is a ramp, not a dice bucket. Ladder: below 0.30 CRACKED, below 0.60 DENTED, above that DESTROYED plus 0->8 neighbours ramping to `NEIGHBOUR_PUNCH_FULL`. There is deliberately NO "nothing happened" rung — *"o tiro errado sempre vai ter pelo menos uma marca de bala (a não ser que atravesse a parede)"*. **D30.1 — neighbours are destroyed, never marked**: *"vizinhos destruídos mas sem marca própria. Somente o projétil gera a marca no ponto de impacto."* This preserves the invariant D28 was actually written to protect (no spray of separate round holes) while letting a heavy round open ONE contiguous breach; a neighbour can only go INTACT -> DESTROYED. **D30.2 — neighbours cascade to the second layer only above `NEIGHBOUR_CASCADE_PUNCH`**: *"se a potência do tiro for gigantesca [...] não é algo para ser frequente, mas eventualmente vai ter uma bazuca."* Set to 5.0, above the arsenal's MEASURED worst case (elite sniper on wood, point blank, max luck = 4.41) — pinned by `test_no_shipped_weapon_reaches_the_cascade`, which reads the real JSONs so a future balance edit fails the suite instead of silently turning a rifle into a bazooka. An earlier pass set this from a concrete-only hand calculation and was wrong by 2x; glass is excluded from that ceiling test with a measured reason (punch 8.82) plus D22's ratified DESTROYED-only/deferred-cascade status, not as a convenience. **D30.3 — skill is the agent's**, and rides in the quotient rather than in weapon damage so there is exactly one place to read when a shot surprises you; no actor carries a skill stat yet, so `WeaponBenchController._agent_skill()` is the single seam and returns neutral 1.0 today. **D30.4 — luck is a spread on DESTRUCTION, never on hit/miss** (*"não confundir com a chance de acertar ou errar o alvo"*), 0.85-1.20 per projectile, and it also decides WHICH of the 8 neighbours go, so holes are irregular rather than always a cross or a square. Soot needs no equivalent knob: `derive_soot_rings()` is a deterministic BFS with no randomness of its own, so varying the hole varies the scorch for free — the Director's assumption that variation already lived in the soot was close, but the variation is upstream, in which voxels are absent. **Evidence**: `blast_calculator_selftest.gd` 55/55 (neighbour ladder monotonic `[0,0,3,5,8,8]`, zero marked strays at punch 2.5, cascade only above threshold, coefficient ordering across weapon/skill/material, LINE ray straightness); real PLAYGROUND bench shots, one capture each — sniper `punch 1.81` one large breach (`Screenshots/history/auto_2026-08-02_19-02-04.png`), pistol `0.63` a single-voxel hole (`auto_2026-08-02_19-02-13.png`), shotgun 24 pellets at `0.47-0.66` scattering small damage (`auto_2026-08-02_19-02-21.png`). | ✅ Ratified & shipped 2026-08-02 — amends D28's scope (neighbours) and supersedes its probability roll |
| **D30-CAL** | **CONE's step table stays UNREAD as a distance term, and that is a scope decision with a measured cause.** Wiring `step_multipliers` in as distance for CONE looked canon-correct (D2: *"distance = the step falloff itself"*) and MEASURED as a regression: the shotgun's `[1.0,0.85,0.6,0.35,0.15]` bottoms out at 4 GU, exactly where the bench stands it, so 24 pellets that punched ~7 holes through concrete under the old model produced **zero**. The old CONE path never read that table at all, so switching it on is a behaviour change nobody asked for in this pass. Distance is therefore neutral (1.0) for BOTH shapes today; `ShotPunchTable.cone_distance_multiplier()` is the tested seam firearm range lands on when `WEAPON_MASTER_PLAN` D29's deferred range/dispersion work is taken up. Shotgun `punch` calibrated to 0.24 to restore parity (8 of 24 pellets destroy, vs ~7 before). | ⏸ Moved to COMBAT (Director, 2026-08-02: *"o dano vamos trabalhar na parte de COMBATE"*) — not a weapon-plan follow-up |

| **D31** | **A shotgun's spread is a DISC on the target that grows with distance — never a horizontal line, and never capped in range.** *(Director, 2026-08-02, with a diagram: "ZONA DE DESTRUIÇÃO" as an ellipse on the wall, "TIROS DE LONGE ERRAM MAIS LONGE".)* Two independent bugs produced the streak in the Director's capture, and both are fixed here. **(a) No vertical axis existed at all** — `resolve_pellet_voxel()` pinned every pellet to `chest_level`, so 24 pellets landed on ONE voxel row by construction. **(b) The lateral angle was `lerp(-half, +half, unit)` with `unit` uniform**, which spreads pellets evenly across the FULL width: half of every blast sat past 12.5° of a 25° cone and the extremes were as likely as dead centre, smearing the pattern along the cone's edge instead of filling it. A real cone is uniform over AREA, so each pellet now draws a point in the **unit disc** (`theta` uniform, `rho = sqrt(u)`): the horizontal component steers the GU-space ray (keeping occlusion honest through the existing `_walk_pellet_ray`), the vertical component becomes a level offset, and the sub-GU horizontal position comes off the same disc instead of an unrelated hash. Both scale with `steps` travelled, so the widening-with-range in the diagram falls out of the cone's geometry rather than being a separate rule. **Shotgun `cone_half_angle_deg` 25° → 6°**: at 25° the disc's radius at the bench's 4 GU is 14.9 voxel rows against a storey only 8 rows tall, so every pellet clamped to the wall's edges — the measured form of *"está muito aberto em relação à arma"*. **Range stays uncapped** (Director: *"o alcance não é pra ter limite mesmo, o tiro acertou o fundo corretamente em relação à distância"*); a pellet that clears the near wall still travels on, it is simply now rare for one to stray that far. Each pellet keeps its own independent hit/miss and its own damage dice (D30.4), unchanged. **Evidence**: `blast_calculator_selftest.gd` 56/56 including a new disc test (near shot covers 5 rows / 15 distinct voxels, far shot 7 rows — an area, widening with range); real PLAYGROUND bench shot instrumented per pellet lands 24 pellets across rows 2–5 × cols 2–5 of a single GU face, versus one row before (`Screenshots/history/auto_2026-08-02_19-28-44.png`). | ✅ Ratified & shipped 2026-08-02 |

| **D32** | **Damage art is a FLAT SQUARE DECAL authored per material, projected onto the struck face — and every mark lands on the surface its cause could physically reach.** *(Director, 2026-08-02, two diagrams + a sample metal bullet hole.)* Replaces the D22/D23 model where each (material, tier, cause) was a whole hand-drawn 32×36 atom with the mark baked onto the **top face** — measured: `voxel_concrete_dented.png`'s dark pixels sat entirely inside the top diamond (bbox `(11,3)–(21,13)`, diamond spans `y = 0..15`), so **every firearm hit on a wall painted its bullet hole on the voxel's roof**. The Director's rule closes it: *"marcas de balas na face do topo não aparecem em voxels de parede (só de chão), marcas de bala em parede não aparecem em faces laterais de telhados. Cada tipo de marca no seu lugar."* **D32.1 — the decal is square, and the projection is the generator's job, never the art's.** `ASSETS/ART_SPECIFICATIONS.md` §1 already pinned this (*"never pre-stretch to compensate for projection — the compositor owns all projection math"*), and `bake_compositor.gd::_get_plane_source()` already does exactly it for facades. `generate_voxel.py` now applies the same two operations to a 256×256 RGBA decal: ×20/16 vertically onto a lateral face (16×20 native), nothing at all onto a top face (16×16 native, square in flat space — the same reason roof planes are laid "flat 1:1, NO ×20/16"). This also answers the Director's own constraint — *"não quero distorcer o círculo além do que é necessário para a perspectiva"* — by letting him draw a genuinely round hole. **D32.2 — half voxels are a shared substrate, generated from the material's own atom, and the exposed cut face is the MATERIAL, not a grey fracture.** Four per material (`left`/`right`/`top`/`bottom`); *"podem ser os mesmos das bullets inclusive"*. This narrows D25's decoupled `broken_face_generic` to the blast-only role it was designed for: under D32 a dented voxel reads as half a voxel of real material with a dent decal pressed into the cut, not as a window onto generic grey rubble. **D32.3 — CRACKED covers all three visible faces of a whole voxel.** *"Cracked aparece no voxel inteiro, nas 3 faces. Não existe voxel rachado só em uma face"* — a voxel that nearly became DENTED and is *"ainda se segurando ali, aos trancos e barrancos"* cannot read pristine on one side and shattered on the other. DENTED and CRACKED stay mutually exclusive; no voxel is both. **D32.4 — placement, per cause.** A bullet only ever hits a **wall** (*"vamos simplificar por enquanto e fazer só tiros que acertam paredes"*) and marks exactly the **one lateral face it struck**; a wall dents laterally only, a floor from above only, a ceiling from below only; a ceiling half voxel carries **no decal at all** — silhouette only, an isometric camera never sees a voxel's underside. The blast side already resolved this correctly via `carved_side_for()`; the bullet side did not resolve it at all (`apply_point_impact()` left `carved_side` at `NONE`). **D32.5 — three variants per family per material, fixed**, picked at runtime by hashing the voxel's BASE coordinates so the choice survives rotation and repaint with nothing new persisted. **Two defects the verification caught, both invisible to reasoning**: building the right-hand side with `Image.FLIP_LEFT_RIGHT` shifts the whole silhouette one pixel (the atom is not mirror-symmetric — `V_E` sits at x=32 in a 32-wide canvas; **30 alpha pixels differ** between `voxel_concrete.png` and its own pixel-mirror), which seams a flat wall voxel against its neighbours — right sides are now composed natively from mirrored **polygons**; and a decal reaching its canvas corners **grew** the substrate's silhouette under supersampling, violating **B3**, so composites are clamped to the substrate's alpha. **Evidence**: 96 composites carry a silhouette byte-identical to their substrate; decal pixels land inside the intended face measured against the same parametric `0 ≤ s,t < 1` region the compositor clips with, **zero outside**, across all four surfaces and both sides; ceiling half voxel diffs to **0 px** of decal. Glass and brick deferred by the Director (*"deixa pra depois"*); glass will get no DENTED/CRACKED tier at all, its cracks becoming a future multi-voxel system. **D32.6 — metal and wood do not crack** *(Director, 2026-08-02: "metal e madeira não ficam rachados, só dented ou balas")*: `MaterialResistanceTable` `crack_factor` 0.0 for both, and the crack decal family is gated to `concrete`/`stone` so no art is queued for a state the runtime cannot reach. Their `dent_factor` is deliberately NOT raised to absorb the freed share — that would be an unrequested balance change; the freed voxels simply stay intact. Bullets are unaffected: a firearm's CRACKED tier is a MARK on the struck face, not a fracture. **D32.7 — an explosion never produces a bullet hole** *(Director, 2026-08-02)*. This was already true when raised — all three blast writes in `BlastCalculator` pass `from_blast=true` — and is now pinned by `test_a_blast_never_resolves_to_a_bullet_mark` (210 combinations, exhaustive over material × tier × side × variant) because the guarantee otherwise lives in a DEFAULT PARAMETER that a future caller can forget silently. What the Director actually saw was the placeholder DENT decal reading round at 16×20 px; it was rebuilt structurally angular (7 vertices, wide radial swing, a core polygon rotated against the rim) rather than nearly-round, which is D23's *"não com furos redondos"* made structural in the generator. | ✅ Ratified — asset pipeline shipped 2026-08-02 (`d5f5d20`), runtime wiring same session, D32.6/D32.7 same session |
| **D33** | **Decal compositing moves from bake-time PNGs to load-time in-memory blits — AFTER the real art lands.** *(Director, 2026-08-02, asking the right question: "a gente é obrigada a fazer o bake dos decals no voxel? Não fica mais fácil colocar o decal por cima do meio voxel em runtime?")* Answer, with the numbers rather than a preference. **RAM is a wash**: composing at load produces the SAME 97 textures (32×36 RGBA ≈ 450 KB total), just in memory instead of on disk — the saving is 97 files in a folder, not bytes. **The shader/second-layer route is dead, measured**: the alternative-id space already holds 1536 of its 4096 ids (12 light buckets × 64 face-soot codes × 2 flips), and 4096 is where Godot's own transform bits begin; a decal axis of 3 variants × 5 destinations multiplies that to ~23000. Same ceiling already recorded in `voxel_renderer.gd` as the blocker for per-face LIGHT. **The route that works is composing into an `Image` at load and registering the TileSet source from it** — exactly what `bake_compositor.gd` already does, Rule 8 intact (still one `set_cell()` per voxel) — and it is cheap: a lateral shear decomposes into "resize vertically 16→20, then shift each column", 16 `blit_rect` calls per face, no per-pixel GDScript loop; the top face decomposes into the same two shears `generate_voxel.py` already uses. **What it actually buys, in order of value:** (1) a decal that is composited per-cell can be stamped onto that cell's BAKED atom, which today is discarded — a damaged voxel on a photographically baked wall currently reverts to a flat material atom and loses the facade; (2) combinations (a second hit adding a second mark, or a dented+cracked state) stop costing assets; (3) changing a decal stops requiring a generator run plus a Godot reimport. **What it costs**: the shear math migrates from Python — where it was verified numerically against the parametric `0 ≤ s,t < 1` region — into GDScript, a real reimplementation risk; and `blit_rect` has no supersampling, so edges harden unless composed at 4× and reduced. **Sequenced after the art** by the Director's own call: benefit (1) is a visual change, and judging it against placeholder decals would prove nothing. **Execution plan: `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md`** (2026-08-03), which opens on a Part 0 measurement spike rather than code. The spike exists because the plan surfaced a cost nobody had priced: **baked sources are rebuilt on every rotation and damage persists across rotations**, so per-cell composites are paid again for every accumulated damaged voxel on every camera rotation — not once per detonation. Measured scale, one real PLAYGROUND grenade: **197 cells needing a composite** (54 wall dented + 44 wall cracked + 99 floor dented), 886 KB of unique 32×36 RGBA. At ~2000 damaged cells late in a mission that is 2000 composites per rotation, against a rotation budget VL-03-PERF already had to defend by making light alternatives lazy. The spike measures one composite's cost, the **reuse rate of baked atoms among damaged cells** (a facade page has 64 atom columns with mirrored-repeat wrapping, so a cache keyed on `(page, atlas_coords, composite_name)` may collapse the 197 into far fewer), and the real rotation slope at 1/5/15 grenades. **PART 0 RAN 2026-08-03 AND KILLED IT.** S1: a composite costs 0.31 ms (1×) / 1.10 ms (4×) — feasible. S2: reuse among a real grenade's 197 damaged cells is **1.04×** (190 distinct composites for 197 cells; 1.44× even keyed on substrate pixel content), so the rescuing cache saves nothing. S2b, decisive: substrate pixel hashes before and after a rotation intersect at **ZERO of 68** — a re-bake re-samples every facade run under the new perspective, so the cost is per-rotation *structurally*, not by choice of cache key. Projected addition per rotation: 61 ms at one grenade, **916 ms at fifteen**, against a criterion of 150 ms set before measuring — exceeded 6×. Approach dead in this form; the criterion was not relaxed after the fact to make it pass. **Byproduct worth more than the decision**: `_set_perspective()` already costs **1918 ms**, unmeasured until now and not a D33 problem. The §7 lazy/progressive fallback survives on paper and is recorded, not recommended. Full data: `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` §9. **RETRACTED SAME DAY — the kill was wrong.** The spike keyed its cache in SCREEN space (`page_idx, atlas_coords`), which cannot survive a rotation by construction, so measuring it and concluding "per-rotation cost, structurally" was circular. Re-measured N→E→N on the same 197 cells: **returning to a view already visited hits the cache 97%** (67 of 69 substrates). Substrates are stable PER VIEW; a rotation only composites what that view has not seen. Corrected cost: **61 ms once per view per detonation**, ~0 thereafter — the 150 ms criterion is not breached and rotation does not need to be dropped. The real constraint is **memory** (~54 MB worst case at 2955 cells × 4 views, against D21's 75.9 MB bake budget), which needs a cap with eviction. Open design point: the cache must outlive the room rebuild and be keyed in base space. Full record incl. the process lesson: `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` §9 (wrong) and §10 (correct). **RESOLVED FURTHER, same day (§11)**: an unrelated performance decision (`ENGINE_PERFORMANCE_REVIEW.md`, ROTATE-KILL-01) killed player-facing camera rotation entirely — `build_from_layout()` now runs exactly once per mission for a player (verified: its only two call sites are `load_map()` and the now dev-only `_set_perspective()`), which makes "the cache must outlive the room rebuild" moot for the case that matters and shrinks the memory worst case from ~54 MB (4 views) to ~13.6 MB (1 view). Part 2 (Python↔GDScript equality) is the one open risk left. | ✅ Part 3 fully done 2026-08-03 (1, 2, 3a, 3b, 3c, 3d) — every impact-mark shape (full-voxel CRACKED, wall/floor/ceiling DENTED) composites onto the real baked facade in `_set_voxel_cell()` now, none of it losing the photographic texture to a flat generic fallback any more. A real bug (V_WB/V_EB mistyped 26 for 28) shipped in 3a and was found/fixed while building 3b's fixtures. 3c threaded a `zone_material` param through `_set_voxel_cell()` for floor's shared "earth" pseudo-name. 3d ported `_hash01()`/`_jagged_profile()` (FNV-1a) bit-exact for the ceiling's deterministic carve — verified against real Python output before it reached production code, no real-game capture behind it (PLAYGROUND has zero roof geometry), equality/seam proofs only. Part 4 split into 4a/4b/4c after a risk was caught before any deletion: `BakeConfig.enabled` ships `false` at release, so every Part 3 branch above goes inert then, and the original Part 4 scope (just delete `composites/`) would have silently regressed all damage rendering to flat concrete under that exact condition — undetected until now because dev testing always runs bake ON. Director's call: extend the live compositor to work without a baked substrate too, but a generic (flat, unbaked) voxel must never wear the photographic decal art — only a material-agnostic **vector** substitute ("condizente com o cenário low poly," "um pouco mais caprichado"). 4a (12 procedural vector-mark decals, material-independent, authored flat and projected through the same real `_paste_decal()` the photographic family uses) and 4b (wiring the flat/generic fallback path in `_set_voxel_cell()`) are both done — every impact-mark shape resolves through a live compositor with BakeConfig OFF now. Two real bugs were caught by the new path's own seam suite before shipping: an alpha=0 "cut" baked into the decal PNG did nothing against an opaque substrate (source-over blending only ever adds coverage), fixed by punching the real hole into the runtime composite instead; and the half-voxel/floor compositors picked a decal variant from a grid_pos hash instead of the plan's own already-parsed variant, collapsing 3 variants onto 1. Both fixes also forced 4 pre-existing seam tests to update stale "falls through to composites/" assertions — not regressions, same category as an earlier Part 3b fix. **4c (2026-08-03) — DONE, D33 complete.** `composites/` (252 files) deleted wholesale; `generate_voxel.py`'s own composite-writing stage retired with it. `BASE_MATERIALS` trimmed from ~144 down to 13 real base materials — more than the "97 generated entries" the plan named, since that count only covered the D32 decal-family names; the 33 older D22/D23/D25 hand-typed pseudo-materials needed removing too (confirmed every one structurally unreachable at runtime before touching any of them). Removing them surfaced a real bug: `_decal_material()`/`floor_damage_material()`'s `MATERIALS.has(composed)` guard had been doing double duty as both "asset exists" (obsolete) and "is this combination even valid" (e.g. a bullet can only strike a lateral face) — dropping it blindly let `_decal_material()` construct nonsense like a bullet mark on a horizontal face, caught immediately by `voxel_decal_selftest.gd`'s own existing tests with zero changes needed to catch it, fixed by making the validation explicit instead of a guard side effect. Evidence: real captures with BakeConfig ON and OFF, both taken AFTER the actual deletion, both showing a real detonation's damage rendering correctly (`Screenshots/history/d33_part4c_bake_{on,off}_post_composites_deletion.png`). |

| **D36** | **The FLOOR reaches CRACKED, on the same severity ladder as a wall.** *(Director, 2026-08-08: "um voxel que recebe muito é destruído (some), o que recebe um pouco menos fica dented, o próximo fica cracked, isto é está quase quebrando, mas ainda conseguiu resistir.")* D19 closed D10's `crack_factor` gap in the DATA — one `concrete` row, `crack_factor` 0.1, "floors crack like walls" — but never in the code: `apply_crater_damage()` had no crack roll at all, so **`FLOOR/cracked` measured 0 on every material on every real PLAYGROUND blast**, regardless of the table. Found by the new per-(surface, material) `[E-PLAN]` census, not by review; the old blended per-wave counts could not have shown it. `_roll_floor_dent()` became `_roll_floor_surface_damage()`: each voxel that survives the crater is offered DENTED first and CRACKED only if the dent roll passed it over — the same D22 pool order `apply_container_damage()` uses on a wall, applied per voxel because a crater is radial rather than ring-flooded. Three independent hash salts (`:CRATER:`, `:FLOORDENT:`, `:FLOORCRACK:`) so no tier's selection correlates with another's. The two tiers fall off over DIFFERENT spans — dent dies one `rim_span` past the crater, crack a `rim_span` later — so the ladder reads spatially as well as per voxel: near the hole a mark is almost always a dent, far out almost always a crack. The bomb's own `dent_ring_weights`/`crack_ring_weights` now reach the floor, so floor and wall finally read the same authored numbers instead of the floor carrying a private falloff. **Hybrid dented+cracked states are explicitly OUT** (Director, same message: *"acho que nesse momento isso não é tão importante"*) — D32.3's mutual exclusion stands. **D32.6 survives untouched on this surface**: metal and wood still reach zero floor cracks, because the tier is gated on `crack_factor` and theirs is 0.0. Asserted, not assumed. **One tuning attempt was reverted by a real capture, and the reason is a rendering fact worth carrying:** raising `crack_ring_weights[0]` above 0 put isolated bright full-voxel cubes standing inside the crater, because CRACKED is a 3-face composite (D32.3) while DENTED is a half-voxel carve — a cracked floor voxel whose neighbours were destroyed renders as a complete block where every other floor tile renders as a flat top face. §4.2's "cracked never in ring 0" is therefore load-bearing, not cosmetic (`Screenshots/history/e_crack_ring0_artifact.png`). Bake side: no new compositing — §3.2's roster always called CRACKED universal across floor/wall/ceiling (D6), and `DamageVariantBaker` now registers the wall's CRACKED-blast atom a second time under `"FLOOR"`, exactly as it already did for `"CEILING"`. Real PLAYGROUND, four grenades, before → after (destroyed / total decals): FLOOR/concrete 268→239 / 69→136 · FLOOR/stone 160→143 / 42→60 · FLOOR/metal 154→143 / 76→77 · FLOOR/wood 155→137 / 8→43. Every dent/crack tile resolved from a pre-baked atom, 0 live-composite fallbacks. **Known and NOT fixed:** the crack decal art (a 256×256 network of thin dark lines) barely survives the downsample to a voxel face — it reads as a faint tonal patch rather than a fracture. An art problem at voxel scale, not a wiring one. | ✅ Ratified & shipped 2026-08-08 (`fde80ce`) — full record in `EXPLOSION_REBUILD_MASTER_PLAN` |

*(Numbering note: D12 here is local to this plan and unrelated to the global D12 "mobile budget" decision in `OVERLORD_CONTEXT.md`. D25 here is likewise unrelated to `WEAPON_MASTER_PLAN.md`'s own D25.)*

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
- **Rule 8 amended** (`CLAUDE.md`, §7.3 of this plan)
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
  exists and will need retiring once the new floor is ratified. ~~D18's actual
  lazy-reveal *trigger*~~ (**built 2026-08-07** — the plan's `expose` entries;
  64 of them resolved on the real PLAYGROUND blast the plan selftest measures),
  deeper cosmetic storeys
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
Shipped default flips to `enabled = true`. ~~Legacy floor assets retired.~~
**DONE 2026-07-27** — `generate_master_floor.py` now emits a flat placeholder
(the sprite was provably always occluded by the voxel earth layer, z=-9 vs
z=0; see BAKE_SYSTEM_REFERENCE.md). `floor_layer`'s coordinate/occupancy
role stays load-bearing (~30 files depend on `map_to_local()`/
`get_cell_source_id()`) — only the never-seen pixel content was retired, not
the layer itself.
~~BAKE-CACHE-01 resolved — this part cannot close while warm boot is 5× over
budget.~~ **Already true as of 2026-07-11 — see §4.** That precondition is
cleared; Part 4's remaining scope is the fallback/loud-fail work and the
default flip, not the cache.

### Part 5 — Directional destruction: `CONE` and `LINE` *(NEW 2026-07-29 — `CONE` ✅ DONE same day, `LINE` open)*

**`CONE` shipped 2026-07-29** as `BlastCalculator.flood_gu_cone()`, exactly to
the contract below: same wall-aware BFS as `flood_gu_rings()` with an angular
gate, returning the same `{gu -> step}` dictionary, so
`find_affected_containers()`/`apply_container_damage()` and the entire soot /
VL-PERSIST / dirty-repaint chain downstream needed **zero changes**.
`apply_container_damage()` gained one trailing `destroy_multiplier` (defaulted
1.0, so every grenade call site is byte-for-byte unaffected) to carry the
weapon's calibre. 6 new selftests in `blast_calculator_selftest.gd`, 27/27 PASS.
Driven for real from `WeaponBenchController` — see
[`WEAPON_MASTER_PLAN.md`](WEAPON_MASTER_PLAN.md) Parts 1–3 for the captures.
**`LINE` remains unbuilt**, and open question #3 below (does a bullet stop where
a footstep stops?) is still unanswered — `CONE` currently reuses
`blocked_edges`, the movement gate, because consistency with the existing flood
beat inventing a second occlusion rule on no evidence.

*Original scoping text, kept:*

**The stub `docs/production/roadmap.md` has been asking for since 2026-07-26**
("shot-based wall destruction... needs its own Part in
`DESTRUCTION_MASTER_PLAN.md`). Now scoped, because the catalog that defines the
shapes exists: [`WEAPON_MASTER_PLAN.md`](WEAPON_MASTER_PLAN.md), D1.

Every destructive input this engine has ever had is **omnidirectional**:
`flood_gu_rings()` takes a source GU and expands outward. A fired weapon takes a
source GU **and a facing**, which is an input this path has never carried. Two
new shapes, siblings to `flood_gu_rings()`, not replacements:

- **`CONE`** — distance bands from a muzzle GU along a facing, widening with
  distance. Half-angle is the weapon's accuracy (tighter = more accurate).
  Shotguns.
- **`LINE`** — a ray from a muzzle GU, with penetration depth as its step axis.
  Pistols (one voxel at a time), rifles (deeper and wider). Depth and the
  multiplier over `MaterialResistanceTable.destroy_factor` are what "calibre"
  means mechanically.

**Contract that keeps this cheap:** both must return the same `{gu -> step}`
dictionary shape `find_affected_containers()` already consumes, so
`apply_container_damage()`, the soot BFS, VL-PERSIST recording and the whole
dirty/TIC repaint downstream need **zero changes**. Both must be as wall-aware
as `flood_gu_rings()` is — but see that plan's §7 #3: a bullet and a footstep do
not obviously agree on what blocks them, and `blocked_edges` is currently the
movement gate.

**Already reusable, audited 2026-07-29:** `BlastWireframeOverlay.show_footprint()`
takes an arbitrary `Array[Vector2i]` and outlines whatever cell set it is given —
nothing in it is ring-shaped, so a cone preview needs no new overlay.

**Not blocked by anything in this plan.** Part 4's fallback/loud-fail work and
this are independent.

---

## 6. Wave sequencing

```
Wave 0:  Part 0 (spike)            → a number, and a go/no-go on layers-per-level
Wave 1:  Part 1 (Slab)             → depends on Wave 0
Wave 2:  Part 2 (solid texturing)  → depends on Slab existing
Wave 3:  Part 3 (the trigger)      → depends on solid texturing (nothing to expose otherwise)
Wave 4:  Part 4 (bake as product) + BAKE-CACHE-01
Wave 5:  Part 5 (CONE/LINE)        → independent of Wave 4; needs WEAPON_MASTER_PLAN's
                                      WeaponDef (its Part 1) to carry facing + falloff
```

Per the prompt-sizing rule: **a novel geometric transform is always its own
prompt.** Part 2's `(x, y, depth)` generalisation lands and is verified *before*
anything consumes it; Part 3 must not be bundled with it.

---

## 7. Open questions

0. **✅ ANSWERED 2026-07-29 — destruction rewinds with the segment, and commits
   at two points.** *(Director; surfaced by the weapons work — see
   [`WEAPON_MASTER_PLAN.md`](WEAPON_MASTER_PLAN.md) D24 / S10. Full run-state
   model in [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §1.)*

   > *"Sim precisa de reset para o segmento todo, incluindo buracos e destruição.
   > O agente vai voltar no tempo."*

   **A segment IS a map**, one loaded at a time, connected to its neighbours by
   matching exits — and **some puzzles need the player to act in one segment and
   collect the result in another**, so a hole punched in segment A has to still
   be there when they come back to it. That is what forces a commit model rather
   than plain rollback:

   - **Commit points, and only these two:** stepping on a checkpoint, and leaving
     the segment.
   - **Death → rewind** to the last commit (the segment's load state, if no
     checkpoint has been reached).
   - **Quit → everything environmental is gone**; the whole segment set reloads.
     Only character RPG progression survives.

   **Implementation, and it is cheap — the shape is already right:**
   `room._base_damage` is a `Dictionary[Vector3i → int]` in
   **base (un-rotated) coordinates**, so a snapshot is `duplicate()` and a
   restore is a replace plus the `reapply_damage()` pass VL-PERSIST already runs
   after every perspective rotation. **The one real constraint:** the store
   cannot live on `room`, which is destroyed exactly when a segment unloads —
   it belongs in an autoload, the same lifecycle reason `Registries` owns the
   other registries (`FIX-SHUTDOWN-CRASH-01b`).

   *(Corrected 2026-08-13: this paragraph used to say "`room._base_damage` and
   `room._base_soot`". **`_base_soot` was deleted by D24 in this same
   document** — soot is derived fresh every repaint from which voxels are
   absent, so `_base_damage` alone is the whole payload and re-derivation does
   the rest. A future implementer following the old text would have gone looking
   for a field that has not existed since 2026-07-30.)*

   **Still open:** whether ember/soot decay, `_under_structure`, and any future
   fire state ride the same snapshot; and the full inventory of *other*
   segment-scoped state (fog of war is a known second payload; enemy state,
   doors and collected items are not inventoried anywhere yet).

1. **`TileMapLayer` count** — the one real unknown. **Part 0 answered the
   CPU/node-creation half 2026-07-15** (256 layers: 0.87 ms, 0.86 MB, headless
   Mac — not the wall). **Still open: real on-device GPU frame-time cost of
   many simultaneous layers** — headless has no display driver and cannot
   measure this. Carry forward as a non-blocking check before Part 1/2 ship
   broadly, not before Part 1 starts.
2. ~~**D9 (speculative pre-compute)**~~ **— ANSWERED 2026-08-09 by the
   prediction layer, and the answer was yes.** `PREDICTION_MASTER_PLAN` shipped
   all 6 tasks: `build_plan()` is pure, a plan is computed the moment a target is
   picked (P-COOK — "the prediction started when the menu opened and is normally
   already finished"), cached by `PredictionCache` on
   `(signature, world_revision)`, and thrown away when the cursor moves. That is
   exactly the "player thinking time is free compute" this item deferred. The
   trap it warned about — building a predictor to save nothing — was avoided by
   measurement: ~190 ms of synchronous work moved out of the frame the player
   clicks on.
3. ~~**Rule 8 amendment**~~ **DONE with Part 1, 2026-07-15** —
   Rule 8 (now in `CLAUDE.md`, originally `OPERATOR_CONTEXT.md`) explicitly
   covers Slab voxels alongside wall voxels.
4. **✅ CLOSED 2026-07-30 — D22's DENTED/CRACKED textures render as a
   dedicated, self-contained impact-mark tile that always bypasses the baked
   lookup, never joins it.** *(Director: the mark's photographic bake "vai
   caber exatamente na face aparente do voxel... de maneira que ele pode ser
   encaixado em qualquer lugar" — designed to be context-independent, not
   tied to whichever facade the surrounding wall happens to use.)* Resolves
   the question this item originally opened (which of the two branches
   `_set_voxel_cell()` already had) with a third option neither candidate
   named: skip both, every time, for these pseudo-materials.
   - **`Voxel.DamageState.DENTED`/`CRACKED` render through
     `VoxelRenderer.damage_variant_material()`**, which maps
     `(base_material, damage_state)` → a pseudo-material name
     (`"metal_dented"`, `"concrete_cracked"`, …) — every call site that used
     to pass `slice.material`/`slab.material` straight through
     (`_render_slice`, `process_dirty`, `process_dirty_slabs`'s solid branch)
     now resolves it first. `_set_voxel_cell()` checks `_is_impact_mark()`
     and short-circuits past BOTH the edge-baked and flat-baked branches when
     true, landing straight on the generic `MATERIALS.find()` path.
   - **Loaded through the exact same append-only mechanism `earth_0..7`
     already proved** (`MATERIALS` array, `source_id == array index`), just
     from a second folder: `IMPACT_ASSET_TEMPLATE` points at
     `ASSETS/ISOMETRIC/source_assets/voxels/impact_marks/`, the Director's
     dedicated drop point for the real photographic bakes
     (`voxel_<material>_dented.png` / `_cracked.png`, one pair per non-glass
     material — 8 files) — swapping in real art later is a pure file
     replacement, zero code changes, by construction.
   - **"Meio voxel" is a texture trick, not new geometry** — stays inside
     Rule 8: *"um voxel inteiro com a geometria modificada pra ter metade em
     alpha... que vai ter a marca do impacto bakeada mais pra dentro."* DENTED
     bakes get a true alpha-cut core so whatever renders behind the tile
     shows through (selling depth), CRACKED bakes stay fully opaque (a flat
     graze) — still one flat PNG through `set_cell()`, never a second
     geometry or a compositing layer.
   - **Placeholder "vector" marks ship now, real art lands later** — per the
     Director's explicit go-ahead (*"por enquanto pode usar só um material
     genérico com uma marca de bala em vetor"*), `generate_voxel.py` gained
     `generate_impact_mark()`: a dark rim + alpha-cut core for DENTED, a
     smaller opaque disc for CRACKED, composited onto each material's own
     existing base atom (not a flat generic blob — already material-tinted).
     Same script also now emits `voxel_glass.png`, the 5th base material.
   - **Real capture, not description**: `auto_2026-07-30_16-30-54.png`
     (metal, before — smooth, no marks) vs. `auto_2026-07-30_16-29-41.png`
     (metal, after firing — DENTED rings visible, alpha core showing the dark
     background through the hole) and `auto_2026-07-30_16-31-26.png`
     (concrete, after firing — a solid opaque CRACKED disc, no alpha cut).
     `project_lint.py` 162 files clean; `blast_calculator_selftest.gd` 28/28;
     `slab_render_selftest.gd` clean. (`bake_selftest.gd`'s 19/19 PASS is
     followed by an exit-time segfault during Godot's own engine cleanup —
     confirmed pre-existing and unrelated via `git stash`, same crash on the
     commit before this work.)
   - **Deliberately still open, not solved here**: the true low-end-device /
     bake-failure fallback the Director described (*"o fallback pra quando
     der erro no Baking System, ou o dispositivo do usuário for
     fraquíssimo"*) is a distinct, explicit-toggle concern (D11's `MATERIAL_ONLY`
     precedent, not a silent catch — B6) and deserves its own scoping rather
     than being backed into this pass. **`glass` is registered
     (`MaterialResistanceTable`, `MATERIALS`) but not wired into any bench
     row** — its "grandes chances de levar vários voxels em volta, ou quebrar
     a janela inteira" cascade is explicitly *not* modeled (`destroy_factor`
     0.7 placeholder only); building that mechanic and a bench column for it
     is separate follow-up work, named but not started.
   - **✅ CLOSED 2026-07-30, same-day follow-up — blast marks split into their
     own texture family, distinct from bullet marks.** See **D23**: a
     grenade was producing round bullet-hole marks, which read as nonsensical
     (*"a granada produzindo buracos de bala, que não faz sentido"*).
     `damage_is_blast` now routes DENTED/CRACKED to an irregular
     `_blast_dented`/`_blast_cracked` family instead of the round
     `_dented`/`_cracked` one bullets use, for RADIAL only.
5. **✅ CLOSED 2026-07-30 — soot for BOTH explosions and firearms is now
   derived, not stored.** *(Director, 2026-07-30.)* `soot_ring` was a
   per-voxel BFS ring (VL-D1, this session's grenade regression re-verified
   it intact) — S3 closed 2026-07-30 for FIREARM soot (see
   `WEAPON_MASTER_PLAN.md` §7a) with a cheaper model: soot is face-local and
   **derived at render/relight time from which neighbouring voxels are
   already absent**, not stored. *"Vamos aplicar a fuligem calibrada com
   facetas, derivadas dos voxels ausentes, nas granadas também, aprimorando o
   sistema de anéis que já existem."* This was a migration of an existing,
   shipped, tested system (`compute_soot_rings()`, `VL-PERSIST`, the grenade
   crater/soot/embers regression this session explicitly verified) — not a
   greenfield addition — so it needed its own pass rather than folding into
   D22's asset work by accident. **Shipped as D24**: `Voxel.soot_ring` is
   deleted; `derive_soot_rings()` writes into a caller-supplied snapshot;
   `room._build_soot_snapshot()` derives it fresh, globally, every repaint;
   `room._base_soot` is deleted (nothing left to persist beyond
   `_base_damage`, which soot already re-derives from). Firearm soot now
   shares the identical mechanism blast soot uses — no separate no-rings
   special case survives.
6. **✅ CLOSED 2026-07-31 by D25 — damage marks now know which face took the
   blast, and a DENTED voxel became a carved half-voxel rather than a marked
   cube.** The Director's diagram specified the mechanism (half the voxel in
   alpha plus a pre-baked broken face, four carved sides); `carved_side_for()`
   picks the side from the blast geometry, so a ceiling above an explosion
   carves its underside instead of stamping its outward top. *Original finding
   kept below.*

   **🟠 Was OPEN — damage marks ignore which face actually faced the
   blast; a slab above the epicentre takes its mark on the wrong side.**
   *(Director, real capture, two reference images.)* A grenade physically
   blasts outward in every direction, including upward — anything above the
   epicentre should show damage on the surface FACING the explosion (its
   underside), the same way a wall already shows damage on whichever slice
   faces the epicentre first. What actually renders instead: a slab's
   damage mark appears on its outward/upward-facing top, as if the blast had
   come from above it looking down, regardless of where the epicentre
   actually was. Not a texture-legibility issue — D23's same-day amendment
   (mark size) already addressed that; this is that the current mark
   pipeline has no concept of "which face of this voxel is the one that
   actually faced the source" to choose from in the first place. **Explicitly
   not being fixed here**: the Director is bringing a more detailed diagram
   to formally design a proper face-oriented "special marks" system (likely
   touching both slabs and walls) before this gets built, rather than a
   guessed patch now. Recorded so the finding and its real evidence aren't
   lost before that design lands.
