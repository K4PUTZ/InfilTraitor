# SURFACES_MASTER_PLAN — what lies on the floor

**v1.2 — 2026-10-06 (SM-2 scatter BUILT except its handset rows; v1.1: the Director's answers to §7, DS-11..DS-14).** Status: 🟢 floors, transitions, tags, colour and the art rooms are BUILT; 🟡 the floor-mark classes (marking, scatter,
stroke, dense layer) are RATIFIED IN PRINCIPLE (Director, 2026-10-06, "Perfeito") and NOT built; nothing in §5-§7 exists yet.

This plan owns **everything that makes a floor look like a place**: the base materials (facade or photographic), the borders between them,
the marks on top (stains, leaves, paint, tracks), the colour system and the rooms where the art is judged. It continues
**R3D-SURFACES** of [`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md) (S1-S5, 2026-09-26 to 2026-10-02), which stays the record of the
mechanism; the content inventory is [`docs/systems/SURFACES_CATALOG.md`](../../docs/systems/SURFACES_CATALOG.md). Map format:
[`MAPFILE_REFERENCE`](../../docs/technical/MAPFILE_REFERENCE.md) (`ground_decals`, `material_tints`).

## 1. Principles (each one cost something to learn)

1. **Colour is data, not art.** Facades are grayscale; a colour is a number. Fixed colour rows (A) plus a per-map tint (B,
   `material_tints`). Per-cell colour (C) is deferred until a map needs many colours of one pattern at once or the player customises.
2. **Material is gameplay, colour and mark are cosmetic.** A material row carries resistance, tags and family; a colour variant borrows
   its pattern's facade (`facade_from`: one PNG, one texture in VRAM, any number of rows). Marks and tints are never saved.
3. **Two routes for a floor.** *Facade* (1024x512 grayscale, mirrored, 16 px per voxel, man-made and regular) and *photo*
   (1024x1024 colour plane in world space, organic, cap 8 per map). A pattern feature must be >= 16 px to survive in play.
4. **The shader MIRRORS the facade, so a directional pattern becomes rings.** A 45 degree hazard stripe turned into concentric rectangles
   (measured). Facades must be symmetric under mirroring; anything directional is a MARK, not a floor.
5. **A mark never outlives its floor.** A mark whose floor-top voxels are gone ends (`bump_world_revision`), so a crater never wears a
   leaf floating over it.
6. **Loud, never silent (B6).** An unknown tag, a patch kind with no rule or no art, a malformed tint, a placement the rules forbid, a
   cell outside the light plane: `push_error`. The art-room harness fails on ANY `ERROR: [` line.
7. **No per-fragment cost in the shared opaque shader.** Borders and marks are geometry with their own shader (a border cell, a quad),
   never a branch every floor fragment pays (the untaken-branch cost on Mali). Every new overlay gets a handset A/B before it is closed.
8. **A map is at most ~46 GU per side.** The cell plane that carries light and soot is 512 voxels from an origin 8 GU before the map
   (`CellPlaneStore.SOOT_TEX_SIZE`); past it a cell draws with no light or soot and logs `outside the 512x512 cell plane`.
9. **Art that is git-ignored is reproduced by its generator.** `ASSETS/materials/*/*.png` is not in git; the procedural facades come from
   seeded scripts (`tools/asset_generation/gen_*_floors.py`), photographs from CC0 sources recorded in `docs/PHOTO_SOURCES.md`.

## 2. What is built

| Item | Where | Record |
|---|---|---|
| Photographic surface per ROLE, `ground_decals` section, roofs, `check_surface.py` | R3D-SURFACES S1-S5 | `RENDER3D_MASTER_PLAN` (2026-10-02) |
| **Feathered ground transitions** (organic <-> organic, symmetric, 1 GU per side, world-noise iso-line) | `GroundTransitions3D`, `ground_transition3d.gdshader`, flag `GROUND_TRANSITIONS=0` | `ff7cb900`, `a7185255`; Galaxy A16: 74 -> 78 draw calls, no measurable frame cost; Moto owed |
| **Patches on the voxel lattice** (any multiple of 1/8 GU, free rotation) | `MapCompiler`, `GroundDecals3D.pick_variant` | `82b7778e` |
| **Floor tags and patch rules** (closed vocabulary of 15 tags, `requires` / `forbids`, loud) | `surfaces/rules.json`, `SurfaceRules`, `MaterialDef.tags`, check in `GroundDecals3D.attach`, `surface_rules_selftest` | `82b7778e` |
| **Corporate floors**: `tile` (+ `tile_beige`, `tile_grey`), `parquet` (herringbone), `carpet` | `tools/asset_generation/gen_corporate_floors.py` | `abe419a6`, `e927ea9d` |
| **Carpet set**: 5 patterns (plain, stripe, basket, diamond, check) x 10 colours = 50 materials, 5 PNGs | same generator, `facade_from` | `a2dee218`, `f9963550`, `0df2ceee` |
| **Industrial floors**: `steel_plate` (grey, dark, rust, green), `grating` (grey, dark, rust, yellow) | `gen_industrial_floors.py` | `e927ea9d` |
| **Per-map colour**: `material_tints` (target albedo, compensated by `facade_mean`) | section, `MapCompiler`, `Board3DLive._make_material`, `material_tints_selftest` | `29262a6e` |
| **Art rooms** `SURFACES_GALLERY` and `SURFACES_LAB`, generated, judged by a harness that fails on any engine ERROR | `gen_surfaces_gallery.py`, `surfaces_gallery.py`, `maps/SURFACES_*.map.json` | `ff7cb900` ... `29262a6e` |

| **SM-2 Scatter** (engine) | `ground_scatter` section, `GroundScatter` (deterministic jittered grid, FNV-1a, voxel lattice, scale and rotation jitter, floor-tag rules and the avoid mask applied quietly and counted), per-kind `size` / `priority` / `class` in `surfaces/rules.json`, per-instance `scale` in `FloorPile3D`, sampled `refresh` for stamps, a loud (not refusing) budget warning at 600 stamps; dev flags `GROUND_SCATTER=0` and `GROUND_SCATTER_X=<n>` (a density multiplier) | `ground_scatter_selftest` (determinism, zone, lattice, scale range, density, desert, sterile, wall, bad kind, compiler: 17 checks) |
| **Cluster stamps** (art): `leaf_litter` (built from the leaf art), `pebbles`, `dirt`, `oil`, three macro-patterns each, 512 px, zero alpha at every edge | `tools/asset_generation/gen_scatter_stamps.py` (procedural, seeded; PLACEHOLDER art, to be judged and redrawn by the Director) | |
| **`SURFACES_SCATTER` room**: forest, yard, office (the leaf rule places NOTHING on the carpet), a density ladder 0.06 / 0.16 / 0.40 | `gen_surfaces_gallery.py`, `surfaces_gallery.py` (retries once on an engine hang and says so) | harness PASSED, 41 captures |

Not built, on purpose: hazard stripes as a floor (principle 4), the floor-grating underlay (§7), human transitions (§7), per-cell colour.

## 3. Decisions (Director unless noted)

| # | Date | Ruling | Why |
|---|---|---|---|
| DS-1 | 2026-10-06 | Organic transitions are **symmetric**, one GU of each material, no priority table | each side shows the other at alpha 0.5 on the edge, continuous by construction |
| DS-2 | 2026-10-06 | Patches anchor on the **voxel lattice** (1/8 GU), rotation free | `FloorPile3D` already took any centre; the half-GU limit was validation only |
| DS-3 | 2026-10-06 | **Tags** (closed vocabulary) are the one mechanism for what may lie where; coexistence is the default, exclusivity is `forbids` | scales without an N x M table; an unknown tag is loud |
| DS-4 | 2026-10-06 | **Art order**: man-made floors of the MVP chapters first, then threshold and spill transitions, then the natural photo floors, spaceship last | the MVP (Agency, Militia, Corporation) is almost all man-made |
| DS-5 | 2026-10-06 | **Grating is cosmetic**: one storey, nobody below, nothing passes, shots never hit the floor; a grenade may remove it; what lies BELOW (water, lava, steam) comes later | vents on pavements and roofs, effects below |
| DS-6 | 2026-10-06 | **Colour = A (fixed rows) + B (`material_tints`)**; per-cell tint deferred | cheapest, covers per-level and per-theme colour |
| DS-7 | 2026-10-06 | **Four classes of floor mark**, by PLACEMENT behaviour, not by who made it (§4); a tyre mark is a stroke although a person made it | tyre marks, footprints and stains behave as organic |
| DS-8 | 2026-10-06 | The art rooms are **two maps** and the harness fails on any `ERROR: [` | the cell-plane limit (principle 8) was found by accident |
| DS-9 | 2026-10-06 | Hazard stripes are a **marking**, not a floor | the facade mirror (principle 4) |
| DS-10 | 2026-10-06 | The Director redraws the leaf art himself (it is too large); the engine treats it as a placeholder | |
| DS-11 | 2026-10-06 | **No hard scatter cap. Scatter places CLUSTERS**: a few (about three per kind) MACRO-PATTERNS, each several decals composited into ONE stamp, instanced many times at varied positions, rotations and scales | the cost of a scatter is quads and alpha overdraw; a stamp of 8 leaves is 1 quad, so the budget is spent where it is seen; and a stamp is authored, so the look is controlled. A per-map BUDGET in quads is reported and warns loudly (measured on the handsets, SM-2); it is not a limit on the author |
| DS-12 | 2026-10-06 | **Scatter is the first stage** (SM-2), before marking | it unlocks forest, yards and stains |
| DS-13 | 2026-10-06 | **Blood and bodily marks are in** ("qualquer coisa pode ter"): spatter and pools are scatter, drag marks are strokes. Each such kind carries `"mature": true` in `rules.json` so a build or a setting can drop them without touching a map | a rating or a setting may need to switch them off |
| DS-14 | 2026-10-06 | **Liquids are a parked track** (no liquid materials yet). Under a grating, for now, only a STEAM VENT effect that rises through it, to see the place; water and lava wait for the liquid materials | the Director |

## 4. The four classes of floor mark (DS-7)

| Class | Placement | Rules | Examples | Rendering |
|---|---|---|---|---|
| **MARKING** (human-made, on the grid) | GU-exact, size in whole GUs, rotation in 90 degree steps, authored one by one; never random, never stacked on another marking | `ground_decals` item with `class: marking` kinds; a free `rot`, a fractional size or an off-grid `at` is an error | hazard stripe, road line (solid / dashed), crosswalk, parking bay + number, arrow, chevron, helipad H, fire-lane, floor tape, doorway threshold, manhole and drain cover, doormat, rectangular rug and runner, expansion joint, cable cover | `FloorPile3D` quads as today (crisp edges, full alpha) |
| **SCATTER** (organic, free) | any voxel, any rotation, scale jitter (~0.6-1.4), several per GU, may STACK (priority orders them); generated per ZONE from a density and a seed, never typed item by item; the unit is a CLUSTER STAMP (DS-11): several decals baked into one image, so one quad is a handful of leaves | `class: scatter` kinds; tag rules apply per placed item; never under a wall, block or prop footprint | leaves, pine needles, grass tufts, moss, flowers, weeds in cracks, mud, puddle, snow patch, ice, sand drift, pebbles, twigs, mushrooms, dirt, dust, ash, oil / rust / grease stain, paint splash, paper, can, cigarette butt, crack, chip, pothole, coffee / liquid stain, cobweb | batched per kind (one mesh per kind), z-ordered by a small LIFT per priority |
| **STROKE** (a line with width) | a polyline with a width; the texture runs along it | `class: stroke` kinds; `ground_strokes` items `{points, width, kind}` | tyre marks, skid marks, footprints, drag marks, cables on the floor, worn paths, rivulets | a strip mesh per stroke, UV along the length |
| **DENSE LAYER** (fills a zone) | not items: a world-space alpha texture masked by noise over a zone | `ground_layers` `{zone, kind, coverage, seed}` | forest litter, uneven snow, wind-blown sand | one quad per zone, per-pixel cost not per-leaf cost |

**Why stamps and the dense layer.** A thousand leaves as separate items is a thousand alpha quads, and the Moto is GPU-bound. A stamp makes a quad worth a
handful of leaves; the dense layer pays per pixel for a whole forest floor. **The budgets are MEASURED on the handsets before they are promised** (§6, SM-2).

## 5. Schemas and algorithms (proposed, not built)

**`surfaces/rules.json`** gains, per patch kind: `"class": "marking" | "scatter" | "stroke" | "layer"`, and for scatter `"stack": true`,
`"scale": [min, max]`, `"density": <per GU>` (a default the zone may override), `"priority": <int>` (draw order among stacked kinds), `"size": <GU>` (the quad's side; 1 for a plain decal, 2-3 for a cluster stamp), `"mature": true` on blood and bodily marks (DS-13).

**`ground_scatter`** (new map section, v1):
```json
{"items": [{"zone": [x, y, w, h], "kind": "leaf", "density": 3.0, "seed": 11, "scale": [0.7, 1.3], "avoid": ["walls", "props"]}]}
```
Positions come from a deterministic jittered grid (FNV-1a of `kind|seed|cell`, B4: the same in every run and on every machine), at the
voxel lattice; an item is dropped when the tags forbid it on the floor under it, when it would lie under a wall / block / prop footprint
(read from the store's occupancy), or when the map's quad budget is passed (a loud warning, once, not a refusal). A scatter item's footprint is its quad's
floor-top voxels; `refresh()` ends an item whose footprint lost any, like `GroundDecals3D` does.

**`ground_strokes`**: `{points: [[x, y], ...], width, kind}`; **`ground_layers`**: `{zone, kind, coverage, seed}`. Both after scatter.

**Marking enforcement**: in `GroundDecals3D.attach` / `MapCompiler`, a `class: marking` kind with a `rot` that is not a multiple of pi/2, or an
`at` off the GU or half-GU grid its size needs, is a `push_error` and is skipped.

## 6. Build plan (stages, each with its acceptance gate)

Each stage ends with `verify.py smoke`, the art-room harness PASSED, and a handset row where it says so. `full` only to close a stage that
rewires the board.

| Stage | Content | Gate |
|---|---|---|
| **SM-1 Marking** (after SM-2) | `class` in `rules.json`; marking enforcement; `gen_markings.py` (procedural, seeded): hazard stripe, road lines, crosswalk, arrows, chevrons, bay + numbers; a gallery band | a selftest per rule (off-grid / bad rot refused); the harness PASSED; **Galaxy + Moto idle row** |
| **SM-2 Scatter** (FIRST, DS-12; ✅ BUILT 2026-10-06, handset rows OWED) | `ground_scatter` section; the cluster STAMPS (`gen_scatter_stamps.py`, procedural and seeded: `leaf_litter`, `pebbles`, `dirt`, `oil`, three macro-patterns each, 2-3 GU); `size`, `class` per kind in `rules.json`; per-item `scale`; the avoid mask (nothing under a wall, block or prop); batching per kind; a `SURFACES_SCATTER` room (forest, yard, office) | determinism (the same expansion twice), avoid and tag rules in a selftest; the harness PASSED; **handset rows at 50 / 200 / 800 instances, which set the per-map QUAD BUDGET (a loud warning, not a cap)** |
| **SM-3 Stroke** | `ground_strokes`; tyre marks, footprints, cables | selftest + capture; handset row |
| **SM-4 Dense layer** | `ground_layers`; litter, snow, sand | per-pixel cost A/B on the Moto |
| **SM-5 Human transitions** | the regular right-angled border (the same mechanism with no noise) and an optional threshold strip; the ONE-SIDED spill (organic onto human, not the reverse) | capture + A/B |
| **SM-6 Grating** | first (DS-14): a STEAM VENT effect rising through a grating (a world-space VFX emitter, `ground_vents` / a prop, existing VFX path); later, with the liquid materials: see-through holes and a plane below (water, lava), a shader decision ruled BEFORE it is built | the Director's eye; a handset row for the emitter |
| **SM-7 Natural photo floors** | mud, dry clay, forest floor, snow, rock (CC0, `PHOTO_SOURCES.md`, `check_surface.py`) with their patch groups; <= 8 per map | `check_surface.py` PASS; a transition capture per new pair |
| **SM-8 Themes** | laboratory, spaceship, domestic floor sets (SURFACES_CATALOG §2.5-2.7), recolour with A + B | gallery rows |
| **E-1 Experiment** | hide the cell grid beyond the agent's perimeter (Director's idea): does it play better or worse? An interface experiment, not a surface stage | the Director's eye |

## 7. Open decisions (for the Director)

0. **Handset rows for SM-2 (owed; no device was connected):** `GROUND_SCATTER=0` against `GROUND_SCATTER_X=1 / 4 / 8` (about 170 / 700 / 1400 stamps) on `SURFACES_SCATTER`, both handsets, FRAME_PROBE; they set the quad budget (the warning is a placeholder 600).
1. **Per-cell tint (C)** (Director: "precisamos pensar nos diferentes cenários"). Scenarios that would need it, to be weighed when the procedural-maps milestone arrives: (a) a level with colour-coded zones of ONE pattern (red wing, blue open office): covered by fixed rows (A) while the palette is finite; (b) procedural maps picking a colour per room from a finite palette: covered by A; (c) the player customising a hideout; (d) factions or teams painting zones at runtime; (e) a colour that changes during play. Only (c)-(e), or a palette that must be unbounded, need C. Undecided.
2. The unverified delivery of `surfaces/rules.json` inside the APK (`FileAccess` on `res://`, like `props/*.json`): to be proven on the next handset run.

## 8. Known limits and debts

- **Intermittent engine hang (2026-10-06):** twice in about twelve desktop boots the process sat at ~100 % CPU after the scenario's `quit` and never exited (once on SURFACES_SCATTER, once inside the harness); eight reruns did not reproduce it, and I did not find the cause. The harness retries once and warns. If it ever shows on a handset or in `verify.py`, it needs a real investigation.

- Facade mirror (principle 4); the map-size limit (principle 8); organic transitions only between two `photo` floors.
- `material_tints` reaches walls, floors and roofs of a material, NOT props or voxel fragments made of the same material.
- Handset rows owed: transitions on the Moto; the dent bowl was never isolated (ruled irrelevant 2026-10-06); every SM stage adds its own.
- The carpet set keeps the old fine-weave `carpet` (it nearly vanishes in play); remove it when the Director says so.
- `surfaces/rules.json` has one rule (`leaf`); every new kind with art needs one (a kind with art and no rule is a loud error in `surface_rules_selftest`).

## 9. Instruments

`check_facade.py`, `check_surface.py`, `surface_rules_selftest`, `material_tints_selftest`, `ground_decals_selftest`, `material_tree_selftest`,
`gen_surfaces_gallery.py --check`, `surfaces_gallery.py` (fails on any `ERROR: [`), `verify.py smoke`. Planned: a marking-rule selftest (SM-1), a
scatter determinism gate (SM-2).

## 10. Session record

2026-10-06: transitions, tags, voxel lattice, the corporate and industrial floors, the carpet set and its palette, `facade_from`,
`material_tints`, the two art rooms; see the commits in §2. Chat record: the Director's rulings in §3 are quoted from that session.
