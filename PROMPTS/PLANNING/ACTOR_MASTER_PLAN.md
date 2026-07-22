# ACTOR_MASTER_PLAN
## Voxel Actors — Digital Twin, Pose Bakes, Damage States — v1.0

**Status:** 🔵 **PLANNED, not started.** Pure decision register from a
Director brainstorm — no code, no spike, no numbers measured yet. Explicitly
queued behind other in-flight work; written down now so the decisions are not
re-litigated when someone does pick it up.
**Baseline:** tag `verified/v0.9.0`. No `verified/` tag cut since — `main` is
ahead at VERSION 0.9.65 (includes the CC0 voxel-import feasibility spike and
the TEST-ZONE right-click "Detonar" context menu, both precedent for this plan
— see §1).
**Companions:** `DESTRUCTION_MASTER_PLAN.md` (owns the `Voxel`/dirty-flag/TIC
machinery this plan reuses for damage — see §3; also the origin of
`PropDef.layers`, which this plan is what finally needs it consumed — see D7),
`docs/technical/BAKE_SYSTEM_REFERENCE.md` (bake canon this plan's sprite-bake
step should follow, not reinvent), `docs/systems/AI_MASTER_PLAN.md` (guard
behavior/FSM — orthogonal to this plan, same actors).
**Authored by:** solo-mode agent, transcribing a Director brainstorm
(2026-07-21) into a decision register — every D below is something the
Director said "sim"/"ok" to in that conversation, not a proposal awaiting
ratification.

---

## 1. Why — the pains this serves

Two things collided this session and exposed the same gap from two sides:

- A feasibility spike imported a CC0 voxel grenade (OpenGameArt "Free Voxel
  Weapon Pack") and placed it as a real world prop. To be recognizable at all
  it had to be scaled up far beyond its real-world proportions relative to the
  wall/floor voxel grid — the project's voxel resolution (`VOXELS_PER_UNIT_AXIS
  = 8`, `LEVELS_PER_STOREY = 8`) is tuned for architecture, not small objects
  or characters.
- Characters have **no voxel representation at all** today — `agent.gd` and
  `guard_enemy.gd` draw a fixed vector silhouette via `_draw()`
  (`SILHOUETTE_WIDTH = 44`, `SILHOUETTE_HEIGHT = 61`), calibrated by hand, with
  zero connection to the material/damage system that already exists for walls.

The Director's ask: characters (and the props that ride with them — clothes,
weapons) should be made of the same "matter" as the environment — voxels that
carry damage state and change over time — without inheriting the wall/floor
system's constraints, because actors are not world-anchored architecture.

Named pains this serves:
- The grenade spike's scale problem generalizes to every future small prop
  and every character — solving it once, here, is cheaper than re-deriving a
  downsample heuristic per object forever.
- `PropDef.layers` has existed in the schema since the original prop system
  landed and has never been consumed by any renderer — this plan is the first
  real consumer, not a hypothetical future one.
- Actor damage today has no visual language at all (no wound states, no armor
  damage) — the terrain destruction system solved exactly this problem for
  walls and is sitting there unused for actors.

---

## 2. Decision Register

| D | Decision | Status |
|---|---|---|
| **D1** | **Actors render as pre-baked sprites, not live `TileMapLayer` voxel geometry.** Rule 8 ("Wall and Slab voxels reach the tilemap only through `set_cell()`/`_set_voxel_cell()`") governs *world-anchored* geometry and was never extended to actors — it stays that way. A moving actor re-writing hundreds of world-grid cells every step is the wrong shape; a sprite pre-composited from voxel data and displayed like any other `Sprite2D`-equivalent token is the right one. The voxel data is the source of truth; the frame-to-frame render is a cheap derived artifact. | ✅ Ratified |
| **D2** | **Source-model resolution is decoupled from runtime cost, once baked.** The `TileMapLayer`-count ceiling `DESTRUCTION_MASTER_PLAN` Part 0 identified as the real constraint on terrain voxels does not apply here — actors never occupy a `TileMapLayer`. Two resolution tiers, both **multiples of the current coarse voxel unit's linear subdivision, per axis**: **×8 for runtime/gameplay-visible tokens** (the in-world actor, at tactical camera zoom); **up to ×32 for large detail contexts** — inventory, abilities/skills screens, cosmetic item inspection — where the bake is shown large and close, not as a battlefield token. | ✅ Ratified (Director, 2026-07-21) |
| **D3** | **Pose library, not skeletal rigging.** A finite set of discrete poses per activity/animation type (~8, Director's figure) — idle, move, attack, take-cover, etc. — shared across most actor archetypes wherever their body plan allows it, rather than a runtime bone/skinning system deforming voxel data live. Matches the project's standing "bake once, reuse" instinct (`DESTRUCTION_MASTER_PLAN` D5/D12) rather than building a bespoke voxel animation engine at odds with the mobile budget (D12, `OVERLORD_CONTEXT.md`). | ✅ Ratified |
| **D4** | **A "digital twin" is the source of truth; poses are bakes derived from it.** One persistent, full-resolution per-atom model per actor (or per archetype) — not one independent voxel set per pose. Each (pose × damage-state × clothing × weapon) combination is a bake *from* the twin into a display sprite, mirroring `DESTRUCTION_MASTER_PLAN` D5 (an intact GU is one baked tile, literally the composite of the voxels it would explode into) and D12 ("bake is the product"). The twin is what accumulates damage; the sprite is what gets drawn. | ✅ Ratified |
| **D5** | **Damage reuses the existing `Voxel`/dirty-flag/TIC machinery — not a parallel system.** Actor atoms get their own container, sibling to `Slice`/`Slab` (same shape as `DESTRUCTION_MASTER_PLAN` D1: one new container class, not per-actor bespoke bookkeeping). **New single-writer boundary** (extends `DESTRUCTION_MASTER_PLAN` §3's rule, does not amend it): actor-atom visibility/color belongs to actor damage and nothing else; terrain-atom visibility stays owned by terrain destruction; neither system's `Voxel` instances are shared or cross-written. Not yet added to the inviolable-rules list in this repo's static core — do that when Part 3 (§5) actually lands. | ✅ Ratified |
| **D6** | **Damage is progressive and stateful per TIC, not a health-bar abstraction.** Director's example: clean → armor takes a hit and shows a hole → a further hit shows blood/wound — accumulating visibly over TICs, same "destruction is an information transaction" philosophy as `DESTRUCTION_MASTER_PLAN` D8, applied to actors instead of terrain. | ✅ Ratified |
| **D7** | **Clothing and weapons are atom layers over the base body, same digital-twin model.** This is the first real consumer of `PropDef.layers` (`godot/scripts/systems/prop_def.gd`) — present in the schema since the prop system's v1, explicitly documented as "authoring-forward; not consumed by v1 renderer." This plan is what makes building that consumer non-optional. | ✅ Ratified |
| **D8** | **Bake-combo count is an explicit, actively managed budget — not left to grow unbounded.** `poses × damage-states × clothing-variants × weapon-variants` is a combinatorial space that can explode fast; `DESTRUCTION_MASTER_PLAN` Part 0 already measured that wall-material cold-compose scales linearly with combo count (8 combos → 1170.5 ms, ~146 ms/combo; extrapolated 24 → ~3.5 s, 48 → ~7 s). Actor combos are higher-dimensional than wall materials and unmeasured at the ×8 source resolution — this is Part 0's job (§5), not a number to guess here. | ✅ Ratified (principle); exact cap is §7 open question |
| **D9** | **Fallback: hand-authored 2D sprite sheets per pose, if the pipeline above proves infeasible.** Acceptable because the game is already 2.5D / tile-sprite-composited at the terrain level — this is a difference in *authoring method* (drawn vs. baked-from-voxel), not a departure from the visual style. Named as an explicit escape hatch, not the default plan; taking it trades away the "actors are made of the same matter as the environment" property that motivated this whole plan (§1). | ✅ Ratified (fallback only) |

---

## 3. Single-writer: actor-atom visibility is its own domain

`DESTRUCTION_MASTER_PLAN` §3 already establishes `Voxel.visible` as
terrain-destruction's alone to write. D5 above adds a **parallel**, not
overlapping, rule for whatever container type actor atoms end up using:

- Actor damage is the sole writer of actor-atom visibility/color/damage-state.
- Terrain destruction never touches an actor's atoms; actor damage never
  touches a terrain `Voxel`.
- Occlusion, fog of war, and any future "actor highlight/selection" visual
  effect must keep their own state, exactly as `DESTRUCTION_MASTER_PLAN` §3
  already requires for terrain — the precedent carries over unchanged.

This costs nothing to state now and prevents the exact class of bug §3
documents for terrain (a second system silently fighting over one bit of
state) from recurring in the actor system.

---

## 4. Numbers — what we actually know

| Quantity | Value | Source |
|---|---|---|
| Coarse voxel atom (current wall/floor unit) | 32×16 px top face / 32×36 px total | `generate_voxel.py` |
| Voxels per GU footprint (coarse) | 8×8 | `VOXELS_PER_UNIT_AXIS = 8` |
| Levels per storey (coarse) | 8 | `LEVELS_PER_STOREY = 8` |
| Current agent silhouette (vector, no voxel) | 44×61 px | `agent.gd` `SILHOUETTE_WIDTH`/`SILHOUETTE_HEIGHT` |
| Runtime/gameplay actor tier | ×8 finer subdivision, per axis, vs. coarse unit | D2 |
| Large-detail UI tier (inventory/abilities/cosmetics) | up to ×32 finer subdivision, per axis | D2 |
| Volumetric implication of "×N per axis" | up to N³ more sub-cells in the same physical volume the coarse grid would use | linear-per-axis, cubic-in-volume — worth stating plainly since "×8" undersells it |
| Warm-boot bake cost, independent of combo count | ~32–35 ms | `BAKE-CACHE-01`, `DESTRUCTION_MASTER_PLAN` §4 — the reason D8's "budget it, don't guess it" is affordable to defer to a real spike rather than blocking this document |
| Cold-compose cost, wall materials (reference point only) | 146.3 ms/combo, linear in combo count | `DESTRUCTION_MASTER_PLAN` §4 — **not** actor numbers; actor combos are unmeasured at ×8 |

**Nothing about actor bake-time cost is measured yet.** Every number above
that isn't a wall/floor precedent is a target, not a result.

---

## 5. Parts *(none started — this is the skeleton, not a build log)*

### Part 0 — Measurement spike
Same discipline `DESTRUCTION_MASTER_PLAN` Part 0 used before committing to
anything: build one actor's digital twin at ×8, bake one pose, measure
compose time and texture memory for real. Go/no-go on ×8 as the runtime
default before Part 1 gets written in earnest.

### Part 1 — Digital twin data model + pose library scaffolding
The persistent per-atom source-of-truth structure (format TBD — §7) and the
pose-set contract (which activities get dedicated poses vs. shared ones).

### Part 2 — Bake pipeline (voxel atoms → sprite)
Reuses `BAKE_SYSTEM_REFERENCE.md` canon where it actually applies rather than
inventing a second bake mechanism; produces the display sprite for a given
(pose, damage-state) pair.

### Part 3 — Damage integration
The actor-atom container (§3), wired to the same dirty-flag/TIC pattern
`DESTRUCTION_MASTER_PLAN` Part 3 uses for terrain. Formalizes D5's
single-writer boundary in the inviolable-rules list once real code exists to
enforce it against.

### Part 4 — Clothing/weapon layering
Consumes `PropDef.layers` for real (D7) — the first renderer that does.

### Part 5 — Large-detail UI contexts (×32 tier)
Inventory, abilities/skills, cosmetic item inspection. Independent of Parts
3–4 in mechanism (same bake pipeline, different resolution and display
context) — the screens themselves are undesigned; this plan only reserves the
resolution budget for them.

---

## 6. Wave sequencing

```
Part 0 (spike)              → go/no-go on ×8, real bake-time number
Part 1 (twin + poses)        → depends on Part 0
Part 2 (bake pipeline)       → depends on Part 1 (nothing to bake without a twin)
Part 3 (damage integration)  → depends on Part 2 (nothing to swap without a baked pose)
Part 4 (clothing/weapons)    → depends on Part 1 + Part 2
Part 5 (×32 UI contexts)     → depends on Part 2 only; can run in parallel with 3/4
```

---

## 7. Open questions

1. **Digital-twin storage format** — JSON like `PropDef` (`props/*.json`), a
   binary format, or something else. Not decided.
2. **Real bake-time cost at ×8** — unmeasured; Part 0's actual job.
3. **Bake-combo budget/cap** (D8) — no number chosen yet; needs Part 0's
   measurement first, same order Destruction's Part 0 → D3 combo-budget
   reasoning followed.
4. **Exact pose count and activity list** — "~8 per activity" is the
   Director's working figure, not a final enumeration.
5. **Damage-state vocabulary** — how many discrete states (clean / breached /
   wounded / ... ), and whether it's uniform across armor types or
   material-dependent like `DESTRUCTION_MASTER_PLAN`'s D2 terrain palette.
6. **Per-archetype vs. shared pose libraries** — whether guard/player/future
   NPC types share one pose set or need their own.
7. **The ×32 UI screens themselves** — inventory, abilities, cosmetics are
   named destinations for the detail budget, not designed screens yet.
