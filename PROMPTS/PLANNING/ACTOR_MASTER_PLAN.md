# ACTOR_MASTER_PLAN
## Voxel Actors — Digital Twin, Pose Bakes, Damage States — v1.1

**Status:** 🔵 **PLANNED, not started.** Pure decision register from Director
brainstorms — no code, no spike, no numbers measured yet. Explicitly queued
behind other in-flight work; written down now so the decisions are not
re-litigated when someone does pick it up. **The pipeline (Parts 0–2b) is now
fully specified end-to-end, deliberately not started** — mass import (Part
2b) is explicitly sequenced *after* other engine fundamentals close, per the
Director (2026-07-26); everything through Part 2b is written in enough detail
to execute without re-deciding anything when that time comes.
**Baseline:** tag `verified/v0.9.0`. No `verified/` tag cut since — `main` is
ahead at VERSION 0.9.81+ (includes the CC0 voxel-import feasibility spike,
the TEST-ZONE right-click "Detonar" context menu, and the full Voxel Light
Foundation, all precedent for this plan — see §1 and D13).
**Companions:** `DESTRUCTION_MASTER_PLAN.md` (owns the `Voxel`/dirty-flag/TIC
machinery this plan reuses for damage — see §3; also the origin of
`PropDef.layers`, which this plan is what finally needs it consumed — see D7),
`VOXEL_LIGHT_MASTER_PLAN.md` (the per-face brightness-bucket mechanism D13
reuses for actor/object bakes — see D13), `docs/technical/BAKE_SYSTEM_REFERENCE.md`
(bake canon this plan's sprite-bake step should follow, not reinvent),
`docs/systems/AI_MASTER_PLAN.md` (guard behavior/FSM — orthogonal to this
plan, same actors), `ASSETS/ART_SPECIFICATIONS.md` §5 (the planned `.vox`
import pipeline D12/D15 generalize).
**Authored by:** solo-mode agent, transcribing Director brainstorms
(2026-07-21, D1–D9; 2026-07-26, D10–D15) into a decision register — every D
below is something the Director said "sim"/"ok" to in the corresponding
conversation, not a proposal awaiting ratification.

**v1.1 (2026-07-26):** added D10–D15 and Parts 2b/5-revised from a Director
session on the asset pipeline specifically — live 3D inspection windows,
voxel-twin-vs-imported-mesh source flexibility, lighting reuse from
`VoxelLightField`, rotation frame-count budget, and mass-import automation.
D1–D9 and Parts 0–4 are unchanged; Part 5 is revised (not renumbered) because
the live-render insight supersedes its original "bake at ×32" framing — see
Part 5's own note.

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
| **D10** | **Dialogue/inventory/inspection screens are live 3D windows, not scene changes.** A `SubViewport` + orthographic `Camera3D` overlaid on the existing 2D isometric gameplay via a `Control`/`SubViewportContainer` panel, kept rendering (`UPDATE_ALWAYS`) instead of captured-once-and-discarded. This is the *same rig* `bake_voxel_sprite_3d.gd` already builds for the one-shot bake (§5 Part 2) — the only change is not calling `quit()` after the first frame, and letting player input orbit the camera or auto-spin it. No new architecture; a live variant of a rig that already exists and works. | ✅ Ratified (Director, 2026-07-26) |
| **D11** | **D2's ×32 "large-detail UI tier" is superseded for any screen using D10's live rendering.** A live twin/mesh is real geometry — it scales for free by moving the camera closer, no separate high-resolution bake needed. The ×8/×32 split in D2 still applies **only** to the baked world-token sprite (D1), which must stay cheap per-frame; it does not apply to a live inspection window, which is not a per-frame-repainted world object and carries none of D1's cost constraint. Read literally, this shrinks Part 5's original scope from "bake at ×32" to "render the twin live" — see Part 5's revision. | ✅ Ratified (Director, 2026-07-26) |
| **D12** | **Object source is a per-object choice: voxel twin (`BoxMesh` per voxel) or an imported low-poly mesh (glTF/.obj) — same pipeline either way.** The camera/lighting/projection rig (§5 Part 2) is identical regardless of what geometry sits inside the `SubViewport`; only the object-population step differs (place voxel cubes vs. instance a loaded mesh). **Recommendation, not a rule:** actors and anything meant to be destructible-as-terrain (D5/D6) → voxel twin, so damage can eventually ride the same `Voxel`/dirty-flag machinery; standalone props/weapons whose damage is handled by other means (e.g. a grenade's blast is computed by `blast_calculator.gd`, not by its own geometry breaking apart) → imported mesh, for authoring speed and definition. Both are "the same matter" in the sense that matters — same bake rig, same lighting (D13), same output contract — even when the source asset isn't literally voxels. | ✅ Ratified (Director, 2026-07-26) |
| **D13** | **Bake/live lighting must reuse `VoxelLightField`, not the flat ambient-only lighting `bake_voxel_sprite_3d.gd` currently uses.** That tool's flat lighting was a *correct* decision when written (2026-07-21) — matching the flat, equally-darkened left/right convention `generate_voxel.py` used at the time. It is now stale: `VOXEL_LIGHT_MASTER_PLAN.md` (shipped 2026-07-23→26) gives every wall voxel face a directional brightness bucket from real lamp position/distance/facing. An actor/object bake (or D10 live window) at a given world GU should sample the **same light-field data** for that position — one side brighter than the other, coherent with the walls around it — rather than reinventing a separate lighting model. No new mapping needed: the object already sits in real 3D space during the bake: light direction for that scene's `DirectionalLight3D`/ambient mix is derived from whichever `LightSource`(s) affect that GU in the world, the same inputs `VoxelLightField` already consumes. | ✅ Ratified (Director, 2026-07-26) |
| **D14** | **Rotation frame count is cheap per-object, expensive in aggregate — budget it like D8, don't assume it.** N discrete azimuth-angle frames (Director's figure: 60, for a showcase/collectible object) is affordable as a one-time bake cost and trivial in texture memory for a single small object (an order of magnitude below a single wall facade page). **This adds a new dimension to D8's combo space** (`poses × damage-states × clothing-variants × weapon-variants × azimuth-frames`) — fine to assume for one hero object, not to be rolled out to every object by default without Part 0's real measurement. A spinning-collectible object (not a directional actor tied to gameplay facing) does not need the same 8-direction quantization guards/agents use (`_snap_to_8dir`) — its frame count is a pure visual-read choice, independent of gameplay facing. | ✅ Ratified (Director, 2026-07-26) |
| **D15** | **Mass-import automation generalizes `bake_voxel_sprite_3d.gd` from one hardcoded object into a manifest-driven batch tool — not a new tool.** Today's script hardcodes one source path, one fixed camera angle, one output. The batch version accepts a manifest (JSON) listing N source objects (voxel JSON per D12's voxel-twin path, or a mesh file per D12's imported-mesh path), each with its own per-object config (azimuth frame count per D14, resolution/source type per D12), reusing the exact same camera/lighting rig (now D13-corrected) and the existing post-process (autocrop, downscale, ground-contact anchor) untouched. Connects to `ASSETS/ART_SPECIFICATIONS.md` §5's already-planned `.vox` → `PropDef` converter — this generalizes that same idea to also accept regular meshes, through one shared bake step instead of two separate pipelines. | ✅ Ratified (Director, 2026-07-26); **deliberately not started** — sequenced after other engine fundamentals close, see Part 2b |

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
| Shipped grenade bake (one object, one frame, reference point only) | 38×68 px final sprite; SubViewport 240×400 canvas, autocropped/downscaled | `bake_voxel_sprite_3d.gd` — the closest real precedent for D14's per-object frame cost, though single-frame, flat-lit (pre-D13), and never batch-timed |
| Azimuth-frame count for a showcase/collectible object (D14) | 60 (Director's figure) | Not yet measured in aggregate — one small object × 60 frames is expected cheap by extrapolation from the row above, not confirmed by a real batch run |

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

### Part 2 — Bake pipeline (voxel atoms or imported mesh → sprite)
Reuses `BAKE_SYSTEM_REFERENCE.md` canon where it actually applies rather than
inventing a second bake mechanism; produces the display sprite for a given
(pose, damage-state) pair. Generalizes the shipped `bake_voxel_sprite_3d.gd`
spike (SubViewport + orthographic Camera3D at the elevation/azimuth that
matches the flat atom's 2:1 diamond ratio) rather than replacing it:
- **Source flexibility (D12):** the object-population step accepts either a
  voxel-JSON twin (`BoxMesh` per voxel, today's path) or an imported low-poly
  mesh (glTF/.obj, `PackedScene` instanced directly) — same camera/lighting
  rig either way, per-object choice.
- **Lighting correction (D13):** replaces the tool's current flat
  ambient-only lighting (correct when written, stale since Voxel Light
  shipped) with a sample of the same `VoxelLightField` data the world's
  walls already use at that GU — the object's bake picks up the same
  brighter-side/darker-side read as its surroundings, no new lighting model.
- Still produces one sprite for one (pose, damage-state) pair, per D4.

### Part 2b — Mass-import automation *(specified now, deliberately not started)*
**Sequencing (Director, 2026-07-26): do not execute before other engine
fundamentals close.** Written here in full so nothing needs re-deciding when
it's picked up — see §6 for what it depends on.

Generalizes Part 2's tool from one hardcoded object/angle into a
manifest-driven batch tool (D15):
1. **Manifest format** — JSON (or a folder convention) listing N source
   objects, each declaring: source type (voxel-JSON or mesh path, D12),
   azimuth frame count (D14, default 60 for a hero/showcase object, subject
   to Part 0's real per-object budget for anything rolled out broadly),
   output resolution tier if still using a baked tier (D2/D11 — most objects
   now only need the D1 gameplay-token tier; D11 retired the ×32 tier for
   anything using a D10 live window instead).
2. **Batch driver** — a Python or GDScript `SceneTree`-script runner (mirrors
   `tools/asset_generation/`'s existing convention) that iterates the
   manifest, invokes Part 2's rig once per (object × azimuth frame), and
   reuses the existing autocrop/downscale/ground-contact-anchor post-process
   completely unchanged.
3. **Output contract** — one sprite sheet (or frame folder) + anchor metadata
   per object, in the same shape `grenade_bake_x8_3d_anchor.json` already
   establishes, so nothing downstream (Part 2/3/4 consumers) needs to know
   whether an asset came from the single-object tool or the batch one.
4. **Palette/license bookkeeping** — for the mesh-import path, carries
   forward `ASSETS/ART_SPECIFICATIONS.md` §5's already-planned per-asset
   license record (only CC0/redistributable sources); for the voxel-twin
   path, the same palette-curation step already planned there.

### Part 3 — Damage integration
The actor-atom container (§3), wired to the same dirty-flag/TIC pattern
`DESTRUCTION_MASTER_PLAN` Part 3 uses for terrain. Formalizes D5's
single-writer boundary in the inviolable-rules list once real code exists to
enforce it against. Applies to the voxel-twin source path (D12); an
imported-mesh object without a voxel twin needs its own damage
representation (swap-mesh/texture damage states) if it needs damage at all —
out of scope for this Part, noted so it isn't assumed for free.

### Part 4 — Clothing/weapon layering
Consumes `PropDef.layers` for real (D7) — the first renderer that does.

### Part 5 — Live 3D inspection windows (dialogue, inventory, abilities, cosmetics) *(revised 2026-07-26)*
**Revision note:** originally scoped as "bake at the ×32 UI tier" (D2). D10/D11
supersede that: these screens render the digital twin or imported mesh
**live** in an overlaid `SubViewport` (D10) instead of consuming a pre-baked
sprite — real geometry scales to any zoom for free, so there is no separate
high-resolution bake to produce. Mechanism, not a baked asset: a
`Control`/`SubViewportContainer` panel opened over the existing 2D gameplay
scene (no scene change), the same camera/lighting rig as Part 2 kept
rendering continuously instead of captured once. Depends on Part 1 (a twin
to show) or a D12 imported mesh; does **not** depend on Part 2's bake output,
since nothing is baked for this path. The screens themselves (inventory
layout, dialogue UI) remain undesigned — this Part only specifies the
render mechanism they'd use.

---

## 6. Wave sequencing

```
Part 0 (spike)              → go/no-go on ×8, real bake-time number
Part 1 (twin + poses)        → depends on Part 0
Part 2 (bake pipeline,
        source + lighting)   → depends on Part 1 (nothing to bake without a twin)
Part 3 (damage integration)  → depends on Part 2 (nothing to swap without a baked pose)
Part 4 (clothing/weapons)    → depends on Part 1 + Part 2
Part 5 (live 3D windows)     → depends on Part 1 (or a D12 imported mesh) only;
                                can run in parallel with 2/3/4 — no bake dependency
Part 2b (mass-import
         automation)         → depends on Part 2 existing and proven on ≥1 real
                                object; ALSO gated on "other engine fundamentals"
                                closing first (Director, 2026-07-26) — not a
                                technical dependency, a sequencing one. Candidates
                                for what that means in practice, not decided here:
                                shot-based destruction (see technical_debt.md /
                                DESTRUCTION_MASTER_PLAN), AI-02 tuning resume,
                                and/or Parts 0-4 of this plan itself.
```

**On the deferral:** Part 2b is fully specified (§5) precisely so it does not
need re-deciding later — "prepare the pipeline, don't run it yet" per the
Director. Nothing blocks starting Parts 0–1 now if that work is picked up;
only the *batch/mass* step (2b) waits.

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
7. **The live 3D inspection screens themselves** *(revised 2026-07-26, was "the
   ×32 UI screens")* — inventory, abilities, cosmetics are named destinations
   for Part 5's live-render mechanism, not designed screens yet.
8. **Per-object source decision (D12) isn't a rule, so who decides per object?**
   — voxel-twin vs. imported-mesh is a per-object judgment call for now; no
   catalog yet of which of the game's planned objects/actors should go which
   way.
9. **Part 2b manifest schema** — not designed, only its required fields are
   named (§5 Part 2b item 1). Format (JSON vs. folder convention) undecided.
10. **What exactly gates Part 2b** — §6 names candidates (shot-based
    destruction, AI-02 resume, this plan's own Parts 0-4) but the Director
    has not picked which "engine fundamentals" specifically must close first.
