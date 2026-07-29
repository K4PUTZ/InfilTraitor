# ACTOR_MASTER_PLAN
## Voxel Actors — Digital Twin, Pose Bakes, Damage States — v1.6

**Status:** 🟡 **Part 0 DONE (2026-07-26). Part 5a (Showcase) first cut DONE
2026-07-27 — a real shotgun renders live, auto-spinning, in a main-menu
screen with a verified adaptive layout. Part 6's first exercise (floating/
rotating collectible with real normal-map lighting) also DONE 2026-07-27 —
see D22. 2026-07-28: open question #16 closed (D23, perspective-aware
light-direction), the grenade moved onto the same real-3D-bake pipeline as
the shotgun (D24), TEST-ZONE props fixed to sort by real depth instead of
"always on top" (D25), the bake/rotation sweet spot standardized into
`CollectibleBakeConfig` for reuse by future collectibles (D26), and a
silhouette-accurate ground shadow with a sharp/soft depth crossfade shipped
for the floating collectible (D27).** Objects track continues (Part 6's
formal design is still open);
living-beings track (character twin, pose library, damage/clothing
integration) deliberately deferred to a second phase, per the Director
(2026-07-26). Started as a pure decision register from Director
brainstorms; now has three real, working pieces behind it. Written down now
so the decisions are not re-litigated when someone does pick each track up.
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
(2026-07-21, D1–D9; 2026-07-26, D10–D21) into a decision register — every D
below is something the Director said "sim"/"ok" to in the corresponding
conversation, not a proposal awaiting ratification.

**v1.1 (2026-07-26):** added D10–D15 and Parts 2b/5-revised from a Director
session on the asset pipeline specifically — live 3D inspection windows,
voxel-twin-vs-imported-mesh source flexibility, lighting reuse from
`VoxelLightField`, rotation frame-count budget, and mass-import automation.
D1–D9 and Parts 0–4 are unchanged; Part 5 is revised (not renumbered) because
the live-render insight supersedes its original "bake at ×32" framing — see
Part 5's own note.

**v1.2 (2026-07-26, same-day continuation):** Part 0's real numbers (§4 —
~500ms/pose, ~360MB at ×8) directly motivated a bigger revision, decided in
the same session: **the digital twin no longer needs multiple pose bakes at
all.** It becomes a showcase-only, mostly-static asset; a *separate*,
deliberately simpler "simplification" system (D16) carries every runtime
angle/pose/situation, referenced against Moonwalker (Arcade) and Sonic's
in-game sprite as the target art direction. This **supersedes D2's gameplay
tier and D3's pose-library-from-the-twin framing, and revises D1/D4** — see
each D's own inline flag; **original text is kept, not deleted**, per this
project's standing no-silent-rewrite policy. Also added: normal-map lighting
for flat simplification sprites without voxel geometry (D17), an explicit
objects-before-living-beings sequencing call (D18), "authoring time doesn't
matter, only runtime cost does" as a named principle (D19), the Showcase
main-menu screen as Part 5's first concrete application (D20, Part 5a), and
the shotgun collectible's render path (D21). New Part 6 (simplification
system) is deliberately left unspecified — the next real open question, not
solved today.

**v1.3 (2026-07-27):** Part 5a built and verified for real — a CC0 shotgun
(Quaternius "Ultimate Guns Pack," license recorded) renders live via D12's
imported-mesh path (first exercise of that decision), auto-spinning, in a
new Showcase screen off the main menu. D20's adaptive layout (bottom strip
portrait / side panel landscape) confirmed with real captures at both the
project's actual mobile viewport (390×844) and its desktop default
(1280×720) — not code-reading. D17 (normal-map lighting) intentionally not
touched yet, per the Director: prove the rest of the mechanism first, test
lighting after. No decisions changed; D10/D12/D20 are now demonstrated, not
just ratified.

**v1.4 (2026-07-27, same-day continuation):** D17's normal-map lighting
tested for real — Part 6's first concrete exercise, a floating/rotating
shotgun collectible (D21) instantiated in the PLAYGROUND test zone. New
`actor_frame_bake_spike.gd` (24 frames × flat-color + view-space-normal-map
pair, same fixed isometric camera as gameplay) and
`flat_normal_relight.gdshader` (continuous per-pixel N·L + specular,
deliberately not bucket-quantized like `VoxelLightField`) feed a new
`FloatingCollectible` node wired to the real `LightRegistry`/`LightSource`
data (D13's same source). Frame count/rate decided: 24 frames at 24fps (a
round one-rotation-per-second, and the rate future character pose animation
is expected to share — not 60, per D14's "budget it, don't assume it").
Confirmed by real captures, isolating shader correctness from the
grid→world light-direction mapping's current limits — see D22 for the full
finding. **New:** D22 (test result), open question #16 (perspective-aware
light-direction mapping). No prior decision changed.

**v1.5 (2026-07-27, same-day continuation):** Director feedback after
watching the live collectible in-game: the spin read far too fast, and the
sprite a little small. **Corrects a category error in v1.4's "24 frames at
24fps" framing** — that number was the *bake* frame count/budget (D14,
still correct and unchanged as a bake decision), not a visual rotation
speed; tying the on-screen spin rate directly to the bake's frame-advance
rate produced a full 360°/sec turn, since each of the 24 baked steps is
15° and all 24 were being cycled every second. Decoupled the two: the
object's visual angular speed is now its own constant
(`ROTATION_DEG_PER_SEC := 14.0`, `floating_collectible.gd`), set to match
`showcase_panel.gd`'s `SPIN_DEG_PER_SEC` exactly, so the twin and the
in-world collectible read at the same, deliberate pace. Also bumped
`SPRITE_SCALE := 1.15` (a first-guess visual nudge, same category as
`MESH_SCALE`, §7 #17). Part 6's "Frame count/rate" bullet below is revised
inline, not deleted — see its own flag. No decision register entry changed;
this is an implementation correction, not a new ratified choice.

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
| **D1** | **Actors render as pre-baked sprites, not live `TileMapLayer` voxel geometry.** Rule 8 ("Wall and Slab voxels reach the tilemap only through `set_cell()`/`_set_voxel_cell()`") governs *world-anchored* geometry and was never extended to actors — it stays that way. A moving actor re-writing hundreds of world-grid cells every step is the wrong shape; a sprite pre-composited from voxel data and displayed like any other `Sprite2D`-equivalent token is the right one. The voxel data is the source of truth; the frame-to-frame render is a cheap derived artifact. | ✅ Ratified · 🔄 **REVISED 2026-07-26, see D16** — still true that the runtime display is a cheap derived sprite, but it is no longer baked *from the twin's exact geometry per pose*; see D16 |
| **D2** | **Source-model resolution is decoupled from runtime cost, once baked.** The `TileMapLayer`-count ceiling `DESTRUCTION_MASTER_PLAN` Part 0 identified as the real constraint on terrain voxels does not apply here — actors never occupy a `TileMapLayer`. Two resolution tiers, both **multiples of the current coarse voxel unit's linear subdivision, per axis**: **×8 for runtime/gameplay-visible tokens** (the in-world actor, at tactical camera zoom); **up to ×32 for large detail contexts** — inventory, abilities/skills screens, cosmetic item inspection — where the bake is shown large and close, not as a battlefield token. | ✅ Ratified (Director, 2026-07-21) · 🔴 **SUPERSEDED 2026-07-26 for the gameplay tier, see D16** — the ×32 UI-tier half was already superseded by D11 (live rendering, no bake); the ×8 gameplay-tier half is now superseded too, since gameplay no longer bakes the twin per pose at all |
| **D3** | **Pose library, not skeletal rigging.** A finite set of discrete poses per activity/animation type (~8, Director's figure) — idle, move, attack, take-cover, etc. — shared across most actor archetypes wherever their body plan allows it, rather than a runtime bone/skinning system deforming voxel data live. Matches the project's standing "bake once, reuse" instinct (`DESTRUCTION_MASTER_PLAN` D5/D12) rather than building a bespoke voxel animation engine at odds with the mobile budget (D12, `OVERLORD_CONTEXT.md`). | ✅ Ratified · 🔴 **SUPERSEDED 2026-07-26, see D16** — the pose library still exists in spirit (the "~8 per activity" figure is still the working number), but it now belongs to the simplification system (Part 6, unspecified), not to bakes of the twin |
| **D4** | **A "digital twin" is the source of truth; poses are bakes derived from it.** One persistent, full-resolution per-atom model per actor (or per archetype) — not one independent voxel set per pose. Each (pose × damage-state × clothing × weapon) combination is a bake *from* the twin into a display sprite, mirroring `DESTRUCTION_MASTER_PLAN` D5 (an intact GU is one baked tile, literally the composite of the voxels it would explode into) and D12 ("bake is the product"). The twin is what accumulates damage; the sprite is what gets drawn. | ✅ Ratified · 🔄 **REVISED 2026-07-26, see D16** — the twin is still the source of truth for *state* (damage, equipment); it is no longer the source of *poses* — those are a separately authored, synchronized-by-convention representation, not a mechanical bake-per-pose derivation |
| **D5** | **Damage reuses the existing `Voxel`/dirty-flag/TIC machinery — not a parallel system.** Actor atoms get their own container, sibling to `Slice`/`Slab` (same shape as `DESTRUCTION_MASTER_PLAN` D1: one new container class, not per-actor bespoke bookkeeping). **New single-writer boundary** (extends `DESTRUCTION_MASTER_PLAN` §3's rule, does not amend it): actor-atom visibility/color belongs to actor damage and nothing else; terrain-atom visibility stays owned by terrain destruction; neither system's `Voxel` instances are shared or cross-written. Not yet added to the inviolable-rules list in this repo's static core — do that when Part 3 (§5) actually lands. | ✅ Ratified |
| **D6** | **Damage is progressive and stateful per TIC, not a health-bar abstraction.** Director's example: clean → armor takes a hit and shows a hole → a further hit shows blood/wound — accumulating visibly over TICs, same "destruction is an information transaction" philosophy as `DESTRUCTION_MASTER_PLAN` D8, applied to actors instead of terrain. | ✅ Ratified |
| **D7** | **Clothing and weapons are atom layers over the base body, same digital-twin model.** This is the first real consumer of `PropDef.layers` (`godot/scripts/systems/prop_def.gd`) — present in the schema since the prop system's v1, explicitly documented as "authoring-forward; not consumed by v1 renderer." This plan is what makes building that consumer non-optional. | ✅ Ratified |
| **D8** | **Bake-combo count is an explicit, actively managed budget — not left to grow unbounded.** `poses × damage-states × clothing-variants × weapon-variants` is a combinatorial space that can explode fast; `DESTRUCTION_MASTER_PLAN` Part 0 already measured that wall-material cold-compose scales linearly with combo count (8 combos → 1170.5 ms, ~146 ms/combo; extrapolated 24 → ~3.5 s, 48 → ~7 s). Actor combos are higher-dimensional than wall materials and unmeasured at the ×8 source resolution — this is Part 0's job (§5), not a number to guess here. | ✅ Ratified (principle); exact cap is §7 open question |
| **D9** | **Fallback: hand-authored 2D sprite sheets per pose, if the pipeline above proves infeasible.** Acceptable because the game is already 2.5D / tile-sprite-composited at the terrain level — this is a difference in *authoring method* (drawn vs. baked-from-voxel), not a departure from the visual style. Named as an explicit escape hatch, not the default plan; taking it trades away the "actors are made of the same matter as the environment" property that motivated this whole plan (§1). | ✅ Ratified (fallback only) · 📌 **Note 2026-07-26:** D16's simplification system may end up looking a lot like this fallback (a separately-authored 2D sprite set, not a mechanical voxel bake) — the difference is provenance (D16's is still meant to be produced from the same 3D bake rig, flattened + normal-mapped per D17, not hand-drawn from scratch), not appearance. Still not designed — Part 6. |
| **D10** | **Dialogue/inventory/inspection screens are live 3D windows, not scene changes.** A `SubViewport` + orthographic `Camera3D` overlaid on the existing 2D isometric gameplay via a `Control`/`SubViewportContainer` panel, kept rendering (`UPDATE_ALWAYS`) instead of captured-once-and-discarded. This is the *same rig* `bake_voxel_sprite_3d.gd` already builds for the one-shot bake (§5 Part 2) — the only change is not calling `quit()` after the first frame, and letting player input orbit the camera or auto-spin it. No new architecture; a live variant of a rig that already exists and works. | ✅ Ratified (Director, 2026-07-26) |
| **D11** | **D2's ×32 "large-detail UI tier" is superseded for any screen using D10's live rendering.** A live twin/mesh is real geometry — it scales for free by moving the camera closer, no separate high-resolution bake needed. The ×8/×32 split in D2 still applies **only** to the baked world-token sprite (D1), which must stay cheap per-frame; it does not apply to a live inspection window, which is not a per-frame-repainted world object and carries none of D1's cost constraint. Read literally, this shrinks Part 5's original scope from "bake at ×32" to "render the twin live" — see Part 5's revision. | ✅ Ratified (Director, 2026-07-26) |
| **D12** | **Object source is a per-object choice: voxel twin (`BoxMesh` per voxel) or an imported low-poly mesh (glTF/.obj) — same pipeline either way.** The camera/lighting/projection rig (§5 Part 2) is identical regardless of what geometry sits inside the `SubViewport`; only the object-population step differs (place voxel cubes vs. instance a loaded mesh). **Recommendation, not a rule:** actors and anything meant to be destructible-as-terrain (D5/D6) → voxel twin, so damage can eventually ride the same `Voxel`/dirty-flag machinery; standalone props/weapons whose damage is handled by other means (e.g. a grenade's blast is computed by `blast_calculator.gd`, not by its own geometry breaking apart) → imported mesh, for authoring speed and definition. Both are "the same matter" in the sense that matters — same bake rig, same lighting (D13), same output contract — even when the source asset isn't literally voxels. | ✅ Ratified (Director, 2026-07-26) |
| **D13** | **Bake/live lighting must reuse `VoxelLightField`, not the flat ambient-only lighting `bake_voxel_sprite_3d.gd` currently uses.** That tool's flat lighting was a *correct* decision when written (2026-07-21) — matching the flat, equally-darkened left/right convention `generate_voxel.py` used at the time. It is now stale: `VOXEL_LIGHT_MASTER_PLAN.md` (shipped 2026-07-23→26) gives every wall voxel face a directional brightness bucket from real lamp position/distance/facing. An actor/object bake (or D10 live window) at a given world GU should sample the **same light-field data** for that position — one side brighter than the other, coherent with the walls around it — rather than reinventing a separate lighting model. No new mapping needed: the object already sits in real 3D space during the bake: light direction for that scene's `DirectionalLight3D`/ambient mix is derived from whichever `LightSource`(s) affect that GU in the world, the same inputs `VoxelLightField` already consumes. | ✅ Ratified (Director, 2026-07-26) |
| **D14** | **Rotation frame count is cheap per-object, expensive in aggregate — budget it like D8, don't assume it.** N discrete azimuth-angle frames (Director's figure: 60, for a showcase/collectible object) is affordable as a one-time bake cost and trivial in texture memory for a single small object (an order of magnitude below a single wall facade page). **This adds a new dimension to D8's combo space** (`poses × damage-states × clothing-variants × weapon-variants × azimuth-frames`) — fine to assume for one hero object, not to be rolled out to every object by default without Part 0's real measurement. A spinning-collectible object (not a directional actor tied to gameplay facing) does not need the same 8-direction quantization guards/agents use (`_snap_to_8dir`) — its frame count is a pure visual-read choice, independent of gameplay facing. | ✅ Ratified (Director, 2026-07-26) |
| **D15** | **Mass-import automation generalizes `bake_voxel_sprite_3d.gd` from one hardcoded object into a manifest-driven batch tool — not a new tool.** Today's script hardcodes one source path, one fixed camera angle, one output. The batch version accepts a manifest (JSON) listing N source objects (voxel JSON per D12's voxel-twin path, or a mesh file per D12's imported-mesh path), each with its own per-object config (azimuth frame count per D14, resolution/source type per D12), reusing the exact same camera/lighting rig (now D13-corrected) and the existing post-process (autocrop, downscale, ground-contact anchor) untouched. Connects to `ASSETS/ART_SPECIFICATIONS.md` §5's already-planned `.vox` → `PropDef` converter — this generalizes that same idea to also accept regular meshes, through one shared bake step instead of two separate pipelines. | ✅ Ratified (Director, 2026-07-26); **deliberately not started** — sequenced after other engine fundamentals close, see Part 2b |
| **D16** | **Split the digital twin (showcase, mostly static, no multi-pose bake) from a separate "simplification" system (runtime gameplay, all angles/poses/situations).** Directly motivated by Part 0's real numbers (§4): baking a full-detail twin per pose at ×8 costs ~500ms and ~360MB *per combo* — real strain, confirmed by measurement, not assumption. The twin becomes a showcase-only asset (D20's Showcase screen, and later inventory/inspection) — large, well-defined, static or barely swaying, rendered live per D10 (never re-baked per pose). The simplification is a *separately authored* representation covering every runtime angle/pose/situation, art-directed toward Moonwalker (Arcade)'s pose/silhouette language and Sonic's small-but-well-drawn in-game sprite (with the twin playing Sonic's title-screen-model role). The two are **synchronized by convention through the same triggers, not by mechanical derivation**: a TIC hit that damages the actor marks a simple cue on the simplification sprite (e.g. a red mark) *and* a more detailed wound on the twin (D6 still governs the twin's side); equipping a helmet on the twin adds a simplified helmet cue to the simplification sprite. Both read the same state; each renders it at its own fidelity. This supersedes D2's gameplay tier and D3's pose-library-from-the-twin framing, and revises D1/D4 — see their inline flags. | ✅ Ratified (Director, 2026-07-26) |
| **D17** | **Simplification sprites get directional lighting without voxel geometry via a normal map + a custom shader — not Godot's built-in `Light2D`.** The same 3D bake pass that produces a flat, unlit albedo sprite for the simplification system also renders a normal map (per-pixel surface direction, captured from the real 3D geometry before flattening to 2D). A small custom `CanvasItem` shader reads that normal map at runtime and relights it per-pixel using the light direction the world already computes for that GU (`VoxelLightField`/`LightSource` — the same data D13 already reuses for the twin's bake). This gives real one-side-brighter-than-the-other shading *and* specular "shine" (the quality named from the Sonic reference) that a flat multi-variant-recolor approach cannot produce, without needing voxel data or live 3D geometry at runtime. **Godot's native `Light2D` is explicitly rejected** for this — it would stand up a second, parallel lighting system alongside the project's existing hand-rolled deterministic one, with no guarantee the two stay in sync; a custom shader fed directly by the existing light data has one source of truth. **Not yet cost-measured** — recommend a Part-0-style spike (shader cost on a real device/GPU) before this becomes the default technique for every simplification sprite, same discipline as D14/D8. | ✅ Ratified (Director, 2026-07-26); cost spike is a new open question, not resolved today |
| **D18** | **Sequencing: objects before living beings.** Start the whole pipeline (twin render, D16's split, D17's lighting, Showcase) on a standalone object (the shotgun) — no clothing layers, no pose library, no damage-state vocabulary, no multi-actor combo space. Validate the mechanism end-to-end on the simple case before spending it on the combinatorially harder character case (D8's concern). Concretely: Parts 1/3/4 (twin data model + pose scaffolding, damage integration, clothing/weapon layering — all character-specific) are deferred to a second phase; Part 2 (single-object bake), Part 5/5a (live window, Showcase), and the new Part 6 (simplification system) proceed now, object-first. | ✅ Ratified (Director, 2026-07-26) |
| **D19** | **Authoring time is not a constraint. Only runtime/mobile cost is.** Import, 3D assembly/adjustment, rendering, and sprite export can take months if needed — the only things that matter are (a) proving the method works and (b) proving it doesn't overload the mobile system at runtime. This reframes D8's combo-budget concern: the worry was never about human authoring time, only about what ships and runs on-device. Doesn't relax D8 itself (the runtime/memory budget still needs real numbers, per Part 0's discipline) — it removes a constraint that was never the real one. | ✅ Ratified (Director, 2026-07-26) |
| **D20** | **Showcase: a main-menu button opening a live 3D inspection screen — the first concrete Part 5 application.** The object fills most of the screen (D10's live `SubViewport`, D11's free-zoom); name and info occupy a separate area, laid out adaptively for portrait (9:16) vs. landscape (16:9) — bottom strip or side panel depending on orientation. This is Part 5's mechanism (already specified) getting its first named, designed screen; see Part 5a. | ✅ Ratified (Director, 2026-07-26) |
| **D21** | **The floating/rotating collectible (shotgun on a GU) renders through the simplification system (D16), not the twin.** Flat, unlit sprites (D17 — lighting applied at runtime via the normal-map shader, never baked in) at whatever angle/frame set the floating-and-rotating read needs (ties to D14's frame-count budget: cheap per-object, budget in aggregate). The twin (Showcase-quality) and the in-world collectible are visually related but not the same asset — the collectible is gameplay-facing and must stay cheap at all times it's on screen, unlike the Showcase twin which is only live while that one screen is open. | ✅ Ratified (Director, 2026-07-26) |
| **D22** | **D17's normal-map relighting is proven to work — via real captures that isolate shader correctness from the grid→view light-direction mapping's current limits.** Built `actor_frame_bake_spike.gd` (24 frames/15° steps, one flat-color + one view-space-normal-map render per frame, centered-before-rotated using the by-now-standard `await process_frame`-before-`AABB` fix) and `flat_normal_relight.gdshader` (continuous per-pixel N·L + Blinn-Phong specular — deliberately not bucket-quantized like `VoxelLightField`; a live per-pixel shader has no bake-time cost to economize on). Verified with three real captures at the same broadside rotation frame (`FloatingCollectible`, gu_cell (8,4), PLAYGROUND test zone): (a) the real light registry's computed direction (light at gu_cell (6,4), energy 1.0) — visually near-identical to ambient-only, because that light sits almost directly behind the object relative to the fixed bake camera at this particular cell-delta; (b) light forced off — matches (a), confirming the ambient-only floor; (c) a forced front-facing light direction — clearly visible directional shading and specular shine on the receiver. **Conclusion: the shader/bake technique is correct** (proven by (c)); the current grid-x→world-x/grid-y→world-z mapping (`floating_collectible.gd`'s file header, unchanged since D17) does not yet account for the fixed camera's azimuth, so it can pick an unfavorable (near-backlighting) direction for some light/object cell-deltas, as seen in (a). Not fixed here — perspective-correct light-direction mapping is follow-up work, see open question #16. | ✅ Confirmed (2026-07-27, real captures) — shader correct; grid→view mapping is a known, not-yet-solved limitation |
| **D23** | **Perspective-aware light-direction mapping (closes open question #16).** D22's grid-x→world-x/grid-y→world-z mapping was only valid at the default N perspective. Fix: both the light's cell and the object's own anchor cell are de-rotated to base (North) orientation via `PerspectiveMapper.cell_to_base()` before the grid→world mapping is applied — the bake camera's fixed azimuth was always derived against a canonical N view, so a raw view-space delta from a rotated (E/S/W) perspective silently picked the wrong world direction. `FloatingCollectible` now also tracks a perspective-independent `base_cell` and re-derives its view-space `gu_cell` on every perspective flip (`reposition_for_perspective()`, mirrored from `TestZoneController`'s grenade handling), so `gu_cell` no longer goes stale the way it used to. | ✅ Shipped (2026-07-28) |
| **D24** | **The grenade moved onto the shotgun's real-3D-bake pipeline, replacing `bake_voxel_sprite_3d.gd`'s single frozen-angle BoxMesh-voxel reconstruction.** That original bake (v2 over a hand-rolled 2D painter's-algorithm rasterizer, v1) was one fixed angle, unlit, and blind to the room's active N/E/S/W perspective — the same class of bug D22/D23 found and fixed for the shotgun. New source: Quaternius' CC0 "Grenade" model (poly.pizza), same provenance convention as the guns pack. `grenade_frame_bake_spike.gd` follows `actor_frame_bake_spike.gd`'s technique but bakes only 4 directions (N/E/S/W, not 24/120) since the grenade is a static ground prop, not a spinning pickup — reuses `bake_voxel_sprite_3d.gd`'s `cam.unproject_position()` ground-anchor technique, exploiting that the AABB bottom-center lands exactly on the pivot's own yaw axis (rotation-invariant, one anchor for all 4 frames). Runtime: `GrenadeProp` (`Sprite2D` drop-in), same `flat_normal_relight.gdshader` and D23's perspective-aware light math. `TestZoneController` swaps its frame on every perspective flip via `update_cell()`. | ✅ Shipped (2026-07-28) |
| **D25** | **TEST-ZONE props (grenades, the floating collectible) sort by real depth against voxel geometry — not OCC-03's "always above everything."** Both were originally z-indexed identically to the player agent (`get_max_voxel_z_index() + 1`), which is correct *only* for the agent, whose occlusion is instead solved by `OcclusionSet` ghosting walls in front of it. Props got no such ghosting, so they simply always rendered on top of any wall/roof regardless of actual depth — most visible after a perspective rotation moved a prop under a taller structure. An interim fix tried registering props as `OcclusionSet` origins (making walls ghost in front of them too); Director's explicit call: props must **not** create occlusion, they should be hidden by geometry like anything else. Final fix: both `GrenadeProp` and `FloatingCollectible` take their z_index from the room's own ground-level (level 0) voxel `TileMapLayer` (`_voxel_renderer.get_layer(0).z_index`) instead of the agent's formula, re-applied on every perspective flip (`_set_perspective()` rebuilds every voxel layer from scratch, so a cached z_index goes stale). **AMENDED 2026-07-29 — see D29.** The ground-level slot was right while a prop *rested* on the floor, and stopped being right the same week: `HOVER_HEIGHT_PX` went 14 → 60 at the Director's request, and a prop floating three voxel levels up, standing in the cell directly south of a 2-storey block, was drawn under all 16 of that block's levels — it read as sunk into the wall. The principle in this row survives untouched (props are hidden by geometry, they never create occlusion); only the mechanism moved from a fixed slot to a real depth test. `GrenadeProp` still uses the fixed slot, where this row's premise does hold. | ✅ Shipped (2026-07-28), amended 2026-07-29 |
| **D26** | **Collectible bake/animation parameters standardized into `CollectibleBakeConfig`** (`godot/scripts/systems/collectible_bake_config.gd`) so a future collectible reuses the shotgun's tuned baseline instead of re-deriving it. Holds: `FRAME_COUNT`/`ROTATION_DEG_PER_SEC` (120 frames @ 36°/s — see the frame-swap-rate finding below), the fixed bake-camera convention (`ELEVATION_DEG`/`AZIMUTH_DEG`/`CAMERA_DISTANCE`, must match exactly or the light-direction math in D17/D23 breaks silently), and the shadow-pass constants (D27). Per-object knobs (`MESH_SCALE`, `ORTHO_SIZE`, `VIEWPORT_SIZE`, `SPRITE_SCALE`) deliberately stay OUT of the shared config — those depend on each model's own real-world size, same visual-judgment-call convention `MESH_SCALE` always has been. **Frame-swap-rate finding** (Director-driven, three iterations): a baked flipbook's perceived smoothness is `FRAME_COUNT / rotation-period-in-seconds`, not frame count or speed in isolation — 24 frames at the original 360°/s spin read fine (~24Hz swap rate) but reading it at a slower, more deliberate 14°/s (Director's later ask, "not too fast") dropped the swap rate to ~2.8Hz regardless of bumping `FRAME_COUNT` alone to 72; only raising both together (120 frames @ 36°/s = 12Hz) cleared the ~10-12Hz threshold motion needs to read as continuous. `actor_frame_bake_spike.gd` is now a copyable template referencing `CollectibleBakeConfig` instead of duplicating these tuned constants; `FloatingCollectible.setup()` takes `frames_dir`/`sprite_scale`/`shadow_scale_factor` per instance instead of hardcoded shotgun paths. | ✅ Shipped (2026-07-28) |
| **D27** | **Ground shadow for the floating collectible: silhouette-accurate, angle-correct, depth-cued by bob height.** Three iterations, each Director-caught via a real running capture: (1) first attempt reused the oblique COLOR frame squashed on Y — squashing an already-foreshortened oblique view is a shear, not a flatten, and visibly rotated the silhouette's apparent angle; fixed with a dedicated TRUE top-down (`SHADOW_ELEVATION_DEG=90`) bake pass, squashed by `SHADOW_SQUASH_Y = sin(ELEVATION_DEG) = 0.5` (the game's own iso diamond ratio — not arbitrary). (2) The top-down bake's camera "up" vector still needed deriving from `AZIMUTH_DEG` (not a fixed world axis) to match the color camera's screen-space angle, plus a runtime mirror — the mirror turned out to be a regression from a sign error in the analytic derivation, caught by measuring the real baked frames' principal-axis angle (PCA over the alpha silhouette) at 12 yaws: mirrored gave 46° RMS error and spun opposite the object; removing the mirror gave 4.3° RMS (PCA noise, not a real offset) — the azimuth-derived up-vector was already correct alone. (3) Depth cue: two shadow layers per frame (`_shadow_sharp`/`_shadow_soft`, from ONE raw top-down render post-processed twice, not re-rendered) crossfade by the object's current bob height — small+sharp+higher-opacity near the floor, bigger+diffuse+lower-opacity at the top of the bob, both size and focus changing together (Director: "real depth needs size AND focus to change, not size alone"), narrowed twice after the first pass read as exaggerated at both extremes. Also: `HOVER_HEIGHT_PX` (a fixed lift above the floor GU point, independent of the bob — `3 * VOXEL_STEP_PX`, roughly a third of a storey) so the object visibly floats within the GU instead of hugging the floor; the shadow itself stays pinned at the true floor Y regardless. | ✅ Shipped (2026-07-28) |
| **D28** | **Collectibles carry a 1px silhouette stroke, and it is not relit.** *(Director, 2026-07-29: "a arma está muito escura em relação ao fundo... dá pra colocar um stroke azulzinho de 1 pixel?")* Drawn inside the baked frame's own transparent margin by a neighbourhood alpha test in `flat_normal_relight.gdshader` — not a scaled-up second sprite, which shears thin features and needs a copy of every frame. No new asset, no extra node, and it follows all 120 rotation frames for free because it derives from the current frame's alpha; the frames leave 43–68px of margin on every side (measured), so it can never be clipped. **Constant colour on purpose**: the whole reason it exists is that the lit sprite vanishes into a dark floor, so a stroke that dimmed with the room would fail exactly when needed. Width is in TEXELS (1.0 ≈ 1 screen px at the shotgun's 1.15 scale), so it stays proportional under zoom. Two real-capture corrections: a hard alpha cut left the stroke DASHED (non-integer sprite scale drops texels between screen pixels — replaced with `smoothstep` coverage), and the uniform now defaults to width 0 because this shader is SHARED — `GrenadeProp` relights through it too and would have been silently outlined as well. | ✅ Shipped (2026-07-29) |
| **D30** | **`FloatingCollectible` covers a second object and a second BEHAVIOUR — and both were tested, not asserted.** *(Director, 2026-07-29: "inverter" the test zone's two roles, plus "confirmar se o modelo serve pra qualquer objeto".)* Two independent generalisations landed together. **(a) Second object:** the spinning pickup is now a grenade, not the shotgun — the first time this class has displayed anything but the object it was written for. That exposed a real hidden coupling: `SPRITE_HALF_WIDTH_PX`/`SPRITE_HALF_HEIGHT_PX` (38×19) were the *shotgun's* measured extents, feeding D29's depth-sort rect, and the grenade fills 44×48 of its frame rather than 66×33. Both constants are now measured per instance from the baked frames' own alpha bounds (`Image.get_used_rect()`, union across frames, max distance from the frame CENTRE since the sprite is `centered=true` and the object need not be centred in its canvas), with the old numbers surviving only as a fallback. **(b) Static facing mode:** a prop that POINTS somewhere instead of spinning is the same flipbook frozen on one frame — `actor_frame_bake_spike.gd` already renders a full 360° turn, so every facing is on disk and a placed weapon needs no bake of its own. Pinning `bob_phase` to 0.0 is the entire static branch: the prop then rests at `HOVER_HEIGHT_PX` with its shadow crossfade at the midpoint, so the static path cannot drift out of sync with the spinning one. **The measurement discipline is the point, not the feature:** a GLB's own forward axis is arbitrary art data, so `FACING_YAW_DEG` was derived from the real frames (PCA principal axis + thin-end test for direction, matched against each grid edge's projected screen angle) — and that measurement caught `PERSPECTIVE_YAW_DEG` copied verbatim from `GrenadeProp.YAW_BY_DIRECTION` being **wrong for E/W**: 170.6°/178.2° off, aiming away from the target, with N and S correct. Flipping E/W: worst error across 4 views × 4 columns went **178.2° → 9.4°**. `GrenadeProp` left alone deliberately — a grenade doesn't point anywhere, so a 180° error is invisible on it; a weapon aiming at a specific block is the project's first object whose facing is falsifiable. Catalog and delivery-shape consequences live in [`WEAPON_MASTER_PLAN.md`](WEAPON_MASTER_PLAN.md) (D3/D4/D5). | ✅ Shipped (2026-07-29, `e98ad25`) |
| **D29** | **Floating props sort by REAL DEPTH against voxel geometry.** *(Director-reported 2026-07-29: "a arma está entrando dentro da parede".)* Amends D25's fixed ground-level slot. The object was not inside the wall — it stood in the cell directly SOUTH of a 2-storey block and was drawn under it, because `z_index` in this project encodes HEIGHT (`WALL_BASE + level`) while a prop needs DEPTH, and y-sorting is enabled nowhere (only `y_sort_origin` is set, which does nothing alone). `VoxelRenderer.classify_geometry_over_rect()` now reports, for the prop's own world-space sprite rect, the tallest z overlapping it from BEHIND and whether anything overlaps it from the FRONT (depth = O5, `(x + y)`, greater = nearer); the prop sits one z above the former, or below everything when the latter is true — so D25's principle (geometry hides props, props never create occlusion) is preserved exactly. **Two wrong versions preceded this, both caught by real runs rather than reasoning:** (1) a vertical-only overlap test let a block 384px off to the side — one depth step nearer — count as an occluder and bury the prop under the whole map, a capture showing it MORE hidden than before the fix; (2) a GU-granular geometry query reported the prop's own cell and every neighbour as "occupied to level 17", because walls are not per-GU columns — `SliceGenerator` puts a slice in a single 8-voxel ROW and an edge's far slice lands one voxel INSIDE the neighbour GU. The query works at voxel resolution. Verified both branches by instrumented run: in front of the wall → `behind_top_z=13`, z=14 (only levels 0–3 overlap the sprite at all, so this clears every frame of the spin); north of the block → `covered_from_front=true`, z=9, hidden. | ✅ Shipped (2026-07-29) |

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
| Azimuth-frame count for a showcase/collectible object (D14) | 60 (Director's figure) | Not yet measured in aggregate — one small object × 60 frames is expected cheap by extrapolation from the row below, not confirmed by a real batch run |

**Part 0 real measurement (2026-07-26)** — `actor_part0_spike.gd`, windowed
(real GPU), a synthetic placeholder humanoid (leg/torso/arm/head blocks, not
real art), same one-`MeshInstance3D`-per-voxel approach `bake_voxel_sprite_3d.gd`
already ships for the grenade:

| Tier (S) | Voxel count | Build | Compose (scene construction) | Capture | Raw image | Static memory delta |
|---|---:|---:|---:|---:|---:|---:|
| ×4 | 2,072 | ~1.0 ms | ~57 ms | ~3 ms | 1.17 MB | ~+51 MB |
| **×8 (D2 default)** | **16,576** | **~8 ms** | **~480–500 ms** | **~55 ms** | **1.17 MB** | **~+330–360 MB** |
| ×16 | 132,608 | — | — | — | — | **SKIPPED** — no established per-node cost data past 18k voxels; extrapolated ~8× tier-8 cost (~4 s compose, ~2.7 GB) is not something to run blind |

**Go/no-go on ×8 (D2): go, with a caveat.** ×8 itself completes in well under
a second and is not disqualifying for a one-time bake. But 16,576 individual
scene nodes for one pose of one object is not cheap, and the cost is
per-combo (D8) — an actor with even a modest 8-combo pose/damage/clothing
set would cost several seconds of cold-compose time with today's approach,
before D14's azimuth-frame multiplier is even applied. **Confirms D2's ×N³
warning in practice, not just in principle** — the ×16 tier is unmeasurable
without a different approach, and ×8 already shows real strain. Recommend
Part 2 evaluate `MultiMeshInstance3D` (one mesh + one material, instanced via
a transform array) instead of one node per voxel before committing to ×8 as
the shipping compose path — this is a node-creation-overhead problem
specific to the "one `MeshInstance3D` per voxel" pattern, not an inherent
cost of ×8 resolution itself; a design call for Part 2, not resolved here.
Real capture at both measured tiers: `Screenshots/history/actor_part0_spike_s4.png`,
`actor_part0_spike_s8.png` (recognizable humanoid silhouette — head, torso,
two legs — at ×8, once camera framing was corrected to the object's actual
scale; `bake_voxel_sprite_3d.gd`'s fixed framing constants, tuned for the
much smaller grenade, cropped to a close-up of the head at first attempt).

---

## 5. Parts *(Part 0 done 2026-07-26; objects track (2/5/5a/6) open to start now;
living-beings track (1/3/4) deferred per D18 — see each Part's own note)*

### Part 0 — Measurement spike — ✅ DONE 2026-07-26
Same discipline `DESTRUCTION_MASTER_PLAN` Part 0 used before committing to
anything: build one actor's digital twin at ×8, bake one pose, measure
compose time and texture memory for real. Go/no-go on ×8 as the runtime
default before Part 1 gets written in earnest. **Result: go, with a caveat**
— see §4's real measurement table and its go/no-go note. Script:
`godot/scripts/tools/actor_part0_spike.gd`.

### Part 1 — Digital twin data model + pose library scaffolding *(DEFERRED — living-beings track, D18)*
The persistent per-atom source-of-truth structure (format TBD — §7) and the
pose-set contract (which activities get dedicated poses vs. shared ones).
**Character-specific — objects don't need it.** A standalone object's
"twin" for Showcase purposes is just an imported mesh + display metadata
(Part 5a), not a pose-library-bearing data model; that model only matters
once characters (living beings) are picked up. Note this Part's own pose
library is *also* superseded in scope by D16 — even when picked back up,
poses belong to Part 6 (simplification), not to bakes from this twin.

### Part 2 — Bake/render pipeline (voxel atoms or imported mesh → twin display or simplification frame) *(OPEN — objects track, D18)*
Reuses `BAKE_SYSTEM_REFERENCE.md` canon where it actually applies rather than
inventing a second bake mechanism. **Available now for the shotgun** —
single-object use doesn't need Part 2b's batch tooling. Generalizes the
shipped `bake_voxel_sprite_3d.gd` spike (SubViewport + orthographic Camera3D
at the elevation/azimuth that matches the flat atom's 2:1 diamond ratio)
rather than replacing it:
- **Source flexibility (D12):** the object-population step accepts either a
  voxel-JSON twin (`BoxMesh` per voxel, today's path) or an imported low-poly
  mesh (glTF/.obj, `PackedScene` instanced directly) — same camera/lighting
  rig either way, per-object choice.
- **Lighting correction (D13):** the *live twin render* (D10, Part 5a) samples
  the same `VoxelLightField` data the world's walls already use at that GU —
  no new lighting model, real 3D geometry is already in the light's path.
- **Two distinct outputs, per D16/D17 (revised 2026-07-26):** (a) the twin
  itself, kept live for Showcase/inspection (D10), never baked to a flat
  sprite; (b) simplification frames — flat, **unlit** albedo + a normal map,
  captured from the same rig, for Part 6's runtime sprites. D4's original
  "one sprite per (pose, damage-state) pair, baked from the twin" framing no
  longer applies to (b) — see D16.

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

### Part 3 — Damage integration *(DEFERRED — living-beings track, D18)*
The actor-atom container (§3), wired to the same dirty-flag/TIC pattern
`DESTRUCTION_MASTER_PLAN` Part 3 uses for terrain. Formalizes D5's
single-writer boundary in the inviolable-rules list once real code exists to
enforce it against. Applies to the voxel-twin source path (D12); an
imported-mesh object without a voxel twin needs its own damage
representation (swap-mesh/texture damage states) if it needs damage at all —
out of scope for this Part, noted so it isn't assumed for free. Per D16, this
Part's damage now updates *both* the twin (detailed) and Part 6's
simplification sprite (a simple cue) from the same trigger — two renders,
one state.

### Part 4 — Clothing/weapon layering *(DEFERRED — living-beings track, D18)*
Consumes `PropDef.layers` for real (D7) — the first renderer that does. Per
D16, equipping something updates the twin's full layered representation and
adds a simplified cue on Part 6's sprite from the same trigger.

### Part 5 — Live 3D inspection windows (dialogue, inventory, abilities, cosmetics) *(revised 2026-07-26; OPEN — objects track)*
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
layout, dialogue UI) remain undesigned in general — **Showcase (Part 5a) is
the first one that is.**

### Part 5a — Showcase screen — ✅ FIRST CUT DONE 2026-07-27
The first named, designed Part 5 screen (D20). A button on the main menu
opens a live `SubViewport` window (Part 5's mechanism) showing one object
filling most of the screen. Name + info panel occupies a separate area, laid
out adaptively: bottom strip in portrait (9:16), side panel in landscape
(16:9) — orientation-driven layout, not a fixed one. Depended only on Part
2's twin-render output (D12 imported mesh accepted) and Part 5's mechanism —
no dependency on Part 1 (character twin data model), Part 6 (simplification),
or any damage/clothing integration, exactly as scoped.

**Shipped:** `godot/scripts/ui/showcase_panel.gd` (`ShowcasePanel extends
WindowBase`, same class hierarchy as `MainMenuPanel`/`ControlsPanel`), a
`MainMenuPanel.showcase_requested` signal + button, wired into `room.gd`
identically to the existing Controls panel (`ModalStack` push/remove on
open/close). The object is the **Shotgun Short Stock** (D18's first
objects-track case) — sourced from Quaternius' CC0 "Ultimate Guns Pack"
(`ASSETS/.../quaternius_ultimate_guns_pack/`, `ATTRIBUTION.txt` records
license), loaded at runtime via `GLTFDocument.append_from_file()` +
`generate_scene()` — Godot's native glTF import, no editor import step,
proving D12's imported-mesh path for real (first exercised by
`shotgun_preview_spike.gd`, a throwaway comparison render across the pack's
4 shotgun variants, kept alongside `bake_voxel_sprite_3d.gd` and
`destruction_part0_spike.gd` as a one-off investigation script per this
project's standing convention). Auto-spins slowly (D10's "auto-spin" option,
`SPIN_DEG_PER_SEC := 14.0`) around the same elevation/azimuth angle the
voxel bake rig uses, so the object reads consistently with the rest of the
game's isometric visual language.

**D20's adaptive layout verified with real captures, both orientations** —
not code-reading: a new dev capture action
(`INFILTRAITOR_CAPTURE_ACTION=open_showcase`, `INFILTRAITOR_CAPTURE_PORTRAIT=1`
to force the project's own 390×844 mobile viewport) drives the real
`MainMenuPanel._on_showcase_pressed()` handler — the same path a real click
takes — then captures through the existing `SCREENSHOT-HOOK-01` pipeline.
Landscape (1280×720, this build's desktop default): side panel, right.
Portrait (390×844, the project's actual configured mobile viewport):
bottom strip. Both showed the shotgun rendering correctly mid-spin, correct
title/description text, and (matching the existing Controls-over-Main-Menu
precedent) the Main Menu still faintly visible behind — intentional
`WindowBase` layering, not a bug.

**Known limitations, honestly scoped as first-cut, not blocking:**
- No `ShowcaseItem` registry — the object is hardcoded (`MODEL_PATH`
  constant), matching D19's "prove the mechanism, don't build the final data
  layer yet." A real registry is Part 2b/6 territory.
- Lighting is the tool's original flat ambient (pre-D17) — D17's normal-map
  technique was explicitly deferred by the Director ("vamos seguir com as
  outras etapas primeiro e depois testamos") until after the objects-track
  mechanism is proven; this Part is exactly that proof.
- `PORTRAIT_ASPECT_CUTOFF := 1.0` is a first guess, not validated against
  real device aspect ratios (§7 open question #14 — unchanged by this cut).
- Two nearly-identical bugs found and fixed while building this (both the
  same root cause as `actor_part0_spike.gd`'s tier-4 bug): reading a
  freshly-added `Node3D`'s `global_transform`/`AABB` before it had been
  through one frame inside the tree. Worth naming as a pattern: any new
  spike/tool in this codebase that computes geometry immediately after
  `add_child()` needs an `await get_tree().process_frame` first.

### Part 6 — Simplification sprite system *(new 2026-07-26; first exercise DONE 2026-07-27; formal design still UNSPECIFIED)*
The runtime, gameplay-facing representation D16 splits away from the twin:
covers every angle/pose/situation an object or actor needs in play, at
Moonwalker/Sonic-style fidelity — small, but well-drawn, with real
directional shading (D17) and shine. **Deliberately not designed in this
revision** — what exists so far: it is produced from the same Part 2 bake
rig (flat albedo + normal map, D17), not hand-drawn from scratch (unlike
D9's fallback, which this resembles in shape but not in provenance); for the
shotgun specifically, its first job is the floating/rotating collectible
frame set (D21), sized by D14's frame-count budget. Open: how many
angles/frames a *non-directional* collectible actually needs, how frames are
organized into a sprite sheet vs. individual files, and — once the
living-beings track resumes — how pose/damage/clothing cues layer onto a
simplification sprite without becoming Part 1's combo explosion by another
name. See §7 for the full list of what's undecided here.

**First exercise shipped 2026-07-27 (D22):** a real floating/rotating
shotgun collectible, in the PLAYGROUND test zone, proving the whole D16/D17/
D21 chain end-to-end for one object.

- **Bake:** `godot/scripts/tools/actor_frame_bake_spike.gd` — 24 rotation
  frames (15° steps) of the Showcase's own shotgun model, from the same
  fixed isometric camera (elevation 30°, azimuth 45°) gameplay always uses.
  Each frame gets two renders: a flat unlit color pass (today's D13-style
  ambient-only look) and a normal-map pass (`ALBEDO = NORMAL * 0.5 + 0.5`,
  view-space surface normal encoded as RGB via an inline unshaded override
  shader). Centers the model on the pivot's own origin *before* rotating it,
  computed only after `await process_frame` — `global_transform`/`AABB` on a
  freshly-parented `Node3D` is invalid for one frame, the same lesson
  `actor_part0_spike.gd` and `showcase_panel.gd` already hit this session.
- **Bake frame count (D14):** 24 frames (15° steps) — a round number and
  consistent with the frame rate future character pose animation is
  expected to use, rather than assuming 60 just because it was the first
  number discussed. 🔄 **REVISED 2026-07-27 (v1.5):** the original text
  here said "24 frames at 24fps — exactly one full rotation per second,"
  conflating the bake's frame *count* (D14, still 24, unchanged) with the
  collectible's on-screen rotation *speed* — driving visual spin directly
  from the bake's frame-advance rate made it turn a full 360°/sec, far
  faster than intended. The two are now separate: rotation speed is its own
  constant, see below.
- **Rotation speed (new, v1.5):** `ROTATION_DEG_PER_SEC := 14.0` in
  `floating_collectible.gd`, matching `showcase_panel.gd`'s
  `SPIN_DEG_PER_SEC` exactly, so the twin and the in-world collectible spin
  at the same deliberate pace. Frame selection is now angle-driven
  (`int(rotation_deg / (360/FRAME_COUNT)) % FRAME_COUNT`), not fps-driven —
  the 24 baked angles are shown as the object slowly turns through them,
  same frames, much slower reveal.
- **Scale:** `MESH_SCALE := 0.5` (bake-time), a first-guess visual judgment
  call ("shrink to the environment's scale, no need to change the mesh" —
  Director), tuned the same iterative way Showcase's camera framing was,
  **not yet validated** against the rest of the world's scale (§7 open
  question #17). **Also** (new, v1.5) a runtime `SPRITE_SCALE := 1.15` on
  top of the bake — the object read a little small in the test zone;
  another visual nudge, not a derived number.
- **Runtime shader:** `godot/shaders/flat_normal_relight.gdshader`
  (`canvas_item`) — reads the baked normal map, computes continuous
  (non-bucket-quantized — deliberately unlike `VoxelLightField`'s 12
  buckets, since a live per-pixel shader has no bake-time cost to economize
  on) N·L diffuse plus a Blinn-Phong specular term, driven by `light_dir`/
  `light_intensity` uniforms.
- **Runtime node:** `godot/scripts/overlays/floating_collectible.gd`
  (`FloatingCollectible extends Node2D`) — selects among the 24 frame pairs
  by accumulated rotation angle at `ROTATION_DEG_PER_SEC` (v1.5, see above),
  applies a gentle vertical sine bob (`BOB_AMPLITUDE_PX := 6.0`,
  `BOB_PERIOD_SEC := 2.0`), and each frame calls
  `_update_light_uniform()`: queries the real `LightRegistry` for the
  strongest active `LightSource` affecting its GU (`affects_cell()` +
  `get_effective_tactical_energy()` — the same query shape D13 already
  established), maps the light's grid-cell delta to a world direction
  (explicit simplification: grid-x→world-x, grid-y→world-z, no Y term),
  projects it into the bake camera's fixed view-space basis, and feeds the
  shader. Instantiated for real in `room.gd`'s
  `_populate_test_zone_if_playground()`, at gu_cell (8,4).
- **Verified with real captures, isolating two separate claims (D22 has the
  full account):** the shader/bake technique itself is correct — proven by
  forcing a favorable light direction and seeing clear, unambiguous
  directional shading + specular shine; the current grid→view mapping is
  **not** yet perspective-aware, and for this test's actual light position
  happened to compute a near-backlighting direction (visually close to
  ambient-only) — a known limitation, not a shader bug, and not fixed in
  this pass.
- **Known limitations, honestly scoped as a first exercise, not blocking:**
  - Grid→world light-direction mapping doesn't yet account for the active
    N/E/S/W perspective rotation (same rotation `TestZoneController`'s
    grenades needed `reposition_for_perspective()` for) — §7 open question
    #16.
  - `MESH_SCALE` is a visual first guess, not derived or validated (§7 #17).
  - No collectible/`ShowcaseItem`-style registry — hardcoded to one shotgun,
    one gu_cell, only in the PLAYGROUND test zone, matching D19's "prove the
    mechanism, don't build the final data layer yet."
  - CLI-baked PNGs never pass through the Godot editor's import scan, so
    plain `load()` fails on them — worked around with a raw `Image.load()` +
    `ImageTexture.create_from_image()` helper; needed again if this pattern
    is reused elsewhere.
  - Normal-map shader cost (D17's own open item, #13) still unmeasured on
    any real device.

**REVISED 2026-07-28 (D23-D27) — most of the above closed, plus a second
object on the same pipeline:**
- Perspective limitation above **closed** — D23.
- Frame count/rotation speed **retuned twice** on the real frame-swap-rate
  finding — now 120 frames @ 36°/s (`CollectibleBakeConfig.FRAME_COUNT`/
  `ROTATION_DEG_PER_SEC`), not the original 24 @ 14°/s — D26.
- `MESH_SCALE` (bake-time, shotgun still 0.5) and `SPRITE_SCALE` (runtime,
  now `1.15`) are unchanged from 2026-07-27's first-guess values — #17 still
  open, not revisited this pass.
- `FloatingCollectible.setup()` now takes `frames_dir`/`sprite_scale`/
  `shadow_scale_factor` per instance (no longer hardcoded to one shotgun
  path) — still no formal registry (#8/#12 still open), but the class
  itself is reusable now; `room.gd`'s `_populate_test_zone_if_playground()`
  still hardcodes the one call site and gu_cell (8,4).
- **Second object shipped on essentially the same pipeline: the grenade**
  (D24) — a static ground prop (`GrenadeProp`), not a `FloatingCollectible`
  (no bob/spin), but same bake technique, same relighting shader, same
  perspective-aware light math (D23).
- **New: a ground shadow** (D27) — silhouette-accurate (true top-down bake,
  not the color frame reused), angle-verified via real pixel measurement,
  crossfades sharp/small near the floor to soft/diffuse at the top of the
  bob.
- **New: real depth-sorting for TEST-ZONE props** (D25) — previously always
  rendered on top of walls/roofs regardless of actual position.

---

## 6. Wave sequencing

**Two tracks now (D18, 2026-07-26): objects open, living beings deferred.**
Part 0's real numbers made the character case's combo cost visible; validate
the whole mechanism on one simple object (the shotgun) before spending it on
characters.

```
OBJECTS TRACK — open now
Part 0 (spike) ✅ DONE       → go/no-go on ×8, real bake-time number (go, with caveat — §4)
Part 2 (bake/render,
        source + lighting)   ✅ imported-mesh path (D12) proven — single object
                                (shotgun) without Part 2b; lighting (D13/D17)
                                still the tool's original flat ambient
Part 5 (live 3D windows,
        mechanism)           ✅ DONE — proven by Part 5a below
Part 5a (Showcase screen)    ✅ FIRST CUT DONE 2026-07-27 — real captures,
                                both orientations, see Part 5a's own section
Part 6 (simplification
        system)               ✅ FIRST EXERCISE DONE 2026-07-27 — floating/
                                rotating shotgun collectible, real normal-map
                                lighting confirmed (D22); formal design
                                (registry, frame packaging, pose/damage
                                layering) still open, see Part 6's own section
Part 2b (mass-import
         automation)         → depends on Part 2 existing and proven on ≥1 real
                                object; ALSO gated on "other engine fundamentals"
                                closing first (Director, 2026-07-26) — not a
                                technical dependency, a sequencing one. Candidates
                                for what that means in practice, not decided here:
                                shot-based destruction (see technical_debt.md /
                                DESTRUCTION_MASTER_PLAN), AI-02 tuning resume,
                                and/or the living-beings track below.

LIVING-BEINGS TRACK — deferred (D18), fully specified so it doesn't need
re-deciding when picked up
Part 1 (twin + pose scaffolding, character-specific)
Part 3 (damage integration)  → depends on Part 1 + Part 2
Part 4 (clothing/weapons)    → depends on Part 1 + Part 2
```

**On the deferrals:** Part 2b is fully specified precisely so it does not
need re-deciding later — "prepare the pipeline, don't run it yet" per the
Director. The living-beings track (Parts 1/3/4) is deferred for a different
reason (D18's sequencing call, not a technical blocker) — nothing stops
picking it up early except the Director's own priority call.

---

## 7. Open questions

1. **Digital-twin storage format** *(living-beings track, deferred per D18)* —
   JSON like `PropDef` (`props/*.json`), a binary format, or something else.
   Not decided.
2. ~~**Real bake-time cost at ×8** — unmeasured; Part 0's actual job.~~
   **RESOLVED 2026-07-26** — see §4. ~500ms compose / ~360MB static memory
   for one 16,576-voxel pose; go, but recommend `MultiMeshInstance3D` over
   one node per voxel for Part 2 (new open question, not this one).
3. **Bake-combo budget/cap** (D8) *(living-beings track, deferred per D18)* —
   no number chosen yet; needs a character twin to measure against, same
   order Destruction's Part 0 → D3 combo-budget reasoning followed. D19
   clarifies this was always about runtime cost, never authoring time.
4. **Exact pose count and activity list** *(living-beings track, deferred per
   D18; also now Part 6's concern, not Part 1's — see D16)* — "~8 per
   activity" is the Director's working figure, not a final enumeration.
5. **Damage-state vocabulary** *(living-beings track, deferred per D18)* —
   how many discrete states (clean / breached / wounded / ... ), and whether
   it's uniform across armor types or material-dependent like
   `DESTRUCTION_MASTER_PLAN`'s D2 terrain palette.
6. **Per-archetype vs. shared pose libraries** *(living-beings track, deferred
   per D18)* — whether guard/player/future NPC types share one pose set or
   need their own.
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
11. **`MultiMeshInstance3D` vs. one node per voxel for Part 2's compose step**
    *(new, 2026-07-26, from Part 0's real numbers)* — the grenade's per-node
    approach measured ~500ms/pose at ×8 for 16,576 voxels; not disqualifying
    for a one-time bake, but heavy enough across D8's combo budget to be
    worth resolving before Part 2 is built, not after.
12. **Part 6 (simplification system)'s formal design is still open**
    *(2026-07-26; first concrete exercise DONE 2026-07-27, D22)* — how
    frames are authored is now answered for the one case tried (3D bake
    flattened via D17, 24 frames spun at 14deg/sec per v1.5), but the
    general registry/data
    layer, how many angles a non-directional floating collectible actually
    needs in general (D21 ties this to D14's budget but names no number),
    and how frame sets are packaged (sprite sheet vs. individual files) are
    all still undecided.
13. **Normal-map shader cost** *(new, 2026-07-26, D17)* — **shader
    correctness confirmed 2026-07-27 (D22)**; raw per-pixel cost on a real
    device is still unmeasured. Recommended before D17 becomes the default
    lighting technique for every simplification sprite; no spike run yet.
14. **Showcase layout breakpoints** *(new, 2026-07-26, D20)* — "adapt for
    9:16 vs. 16:9" is the ratified direction; exact breakpoint values, the
    info-panel's real content (stats shown? flavor text?), and whether other
    aspect ratios (tablets, foldables) get a third layout are undecided.
15. **How Part 3/4's dirty-flag trigger reaches two renderers** *(new,
    2026-07-26, D16)* — the plan says a TIC hit updates both the twin and
    the simplification sprite "from the same trigger," but the actual
    signal/call-site wiring for one state change to reach two independent
    display systems is not designed — deferred with the rest of the
    living-beings track (D18), but worth flagging now since D16 already
    assumes it works.
16. ~~**Perspective-aware light-direction mapping for simplification
    sprites**~~ **RESOLVED 2026-07-28 — see D23.**
17. **`MESH_SCALE` validation** *(new, 2026-07-27, Part 6)* — the floating
    collectible's `0.5` scale factor is a first-guess visual judgment call,
    not derived from or checked against the rest of the environment's actual
    scale. Needs an eyes-on pass once more objects go through this pipeline.
    Still open as of 2026-07-28 — not revisited when the other bake/runtime
    parameters were retuned (D26).
18. **Formal collectible/prop registry** *(new, 2026-07-28, D24/D26)* —
    `FloatingCollectible` and `GrenadeProp` are both reusable classes now,
    but there is still no data-driven catalog of which object goes where;
    `room.gd`'s `_populate_test_zone_if_playground()` remains a hardcoded
    TEST-ZONE call site (one shotgun, one gu_cell, four grenade cells). Same
    open item as #8/#12, sharper now that two real objects exist on the
    same pipeline.
19. **Ground-shadow constants tuned only against the shotgun's elongated
    silhouette** *(new, 2026-07-28, D27)* — `SHADOW_SCALE_AT_TOP/BOTTOM`,
    the alpha peaks, and the bake's dilate/blur iteration counts were all
    eyeballed against one hook-shaped object. Unvalidated for a
    rounder/smaller silhouette (e.g. the grenade, which does not currently
    use this shadow system at all — `GrenadeProp` has no shadow).
20. **`_render_pass()`'s per-frame model reload** *(new, 2026-07-28,
    performance note from D27's bake)* — `actor_frame_bake_spike.gd` calls
    `GLTFDocument.append_from_file()` fresh for every one of the 3 passes ×
    120 frames (360 reloads of the same file) rather than loading the model
    once and reusing/duplicating the scene tree. Never measured as a real
    bottleneck (full shotgun bake completes in well under a minute) but
    flagged here rather than silently normalized, since it is at minimum
    wasted I/O and would compound if `FRAME_COUNT` or the per-object frame
    count grows.
