# SURFACES_MASTER_PLAN — what lies on the floor

**v1.7 — 2026-10-06 (DS-18: a grating is a REAL opening in the floor). v1.6 (SM-2 cost halved: tile culling + mipmaps, Moto re-measured). v1.5 (DS-17: customisation is a LATE milestone, photo ingestion rules). v1.4 (DS-16: the customisation vision; v1.3: DS-15, stamps are a load-time DERIVED cache).** **v1.2 — 2026-10-06 (SM-2 scatter BUILT except its handset rows; v1.1: the Director's answers to §7, DS-11..DS-14).** Status: 🟢 floors, transitions, tags, colour and the art rooms are BUILT; 🟡 the floor-mark classes (marking, scatter,
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
| **Singles and weighted mixes** (Director: "alguns single também"): five small single kinds (`leaf_single`, `pebble`, `twig`, `dirt_spot`, `oil_drop`, 0.3-0.8 GU, three variants each, made by the same script) and the scatter item's `kinds: [[kind, weight], ...]`, a weighted MIX of stamps and singles drawn per grid cell, each kind keeping its own size, scale and floor rules | `gen_scatter_stamps.py`, `GroundScatter`, `MapCompiler`; 5 more selftest checks (mix share, determinism, arid, unknown kind, bad weight) | |
| **SM-6 steam vent (first slice, DS-14)**: `ground_vents` section `{at, kind}` (`steam`), `VentEmitter` (a node: each vent releases a puff every 0.17 s through the existing `SmokeSparkOverlay.add_smoke`, one draw call, world-space depth-tested; a hash phase per vent, never a RNG), a vent on each grating of the gallery's industrial band | `vent_emitter_selftest` (8 checks: timing, determinism, phase, hitch, bad kind, section, compiler); the plume is a PLACEHOLDER SHAPE (narrow: the existing smoke barely widens), the Director tunes it; handset cost owed |
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
| DS-15 | 2026-10-06 | **The game is fully customisable, so a user supplies SINGLE decals, never clustered art. Cluster stamps are DERIVED at load by a regenerator** that composes the singles into the macro-patterns by a RECIPE (data), writes them to a cache and replaces the previous cache. The checked-in-by-script stamp PNGs of v1.2 are retired as a source of truth | the Director: a user cannot be asked for clustered art; also a clean clone has no stamps today (the PNGs are git-ignored) |
| DS-16 | 2026-10-06 | **The product is fully customisable: an OPEN folder tree of art that the player may overwrite (the game asks for a photo of wood, stone, ...). The folders are always open; what the game DISPLAYS is limited by what the player has earned: the permission to override each TYPE of texture is unlocked through gameplay (merit).** The game therefore ships a **default pack** (the PNGs, produced by the dev-time generators) and the **regenerators** for what derives from user art (DS-15); user art wins only where the permission is held | the Director. Consequences (§11): the access check is ONE gate in the resolvers, never scattered; user content is data only (images, never a resource that can carry a script); the validators of `check_facade.py` / `check_surface.py` have to exist IN the engine, because Python does not ship with the game |
| DS-17 | 2026-10-06 | **Customisation of the art is one of the LAST milestones** (not part of SM-2). When it comes: a player photo is **desaturated at the first load and cached** (a cheap pass, the facade route); the **alpha cut-out** of a photographed subject (a leaf photographed roughly centred, then cropped to its own outline) is FUTURE development; and a **separate application validates a mod pack** | the Director. The validator should reuse the engine's own checks (`TextureResolver` already validates size and grayscale, `check_facade.py` / `check_surface.py` are the dev-time twins): ONE rule set, as data, read by the game and by the app; the app could be a Godot headless / GUI build of the same GDScript validators (no second implementation to drift) |
| DS-18 | 2026-10-06 | **A grating is a real opening in the floor, bottomless: a built OBJECT with holes, not a dark texture** (the Director, with a street-drain reference: steam rises from BELOW, crosses the slats and keeps climbing, billowing into a cloud far larger than the grate). Built as: (1) a map section `floor_openings` that makes `SlabGenerator` skip voxel cells in whole GUs, through BOTH floor levels (the same state as the ring's missing deep plane and as a crater, so every downstream reader already copes), leaving 1-voxel bars (`slats`, with a pitch and an axis, and a 1-voxel frame) or nothing (`open`); (2) a vent that starts its plume INSIDE the shaft, so the bars hide and release it by depth; (3) a steam puff style that widens, drifts with a wind and lasts (the existing smoke barely widens) | the Director. Walkable by default (the bars are floor); an `open` pit is a hazard for the gameplay milestone, not built. What the camera sees through the gaps is the void colour of the board |
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
| **SM-2 Scatter** (FIRST, DS-12; ✅ BUILT 2026-10-06; Moto row measured, it says OPTIMISE before budgeting, §7.0; Galaxy owed) | `ground_scatter` section; the cluster STAMPS (`gen_scatter_stamps.py`, procedural and seeded: `leaf_litter`, `pebbles`, `dirt`, `oil`, three macro-patterns each, 2-3 GU); `size`, `class` per kind in `rules.json`; per-item `scale`; the avoid mask (nothing under a wall, block or prop); batching per kind; a `SURFACES_SCATTER` room (forest, yard, office) | determinism (the same expansion twice), avoid and tag rules in a selftest; the harness PASSED; **handset rows at 50 / 200 / 800 instances, which set the per-map QUAD BUDGET (a loud warning, not a cap)** |
| **SM-2b Stamp regenerator** (DS-15; proposed, NOT built) | at load, for each cluster kind with a `stamp` recipe in `rules.json` (`from` singles with weights, `variants`, `count`, `spread`, `scale`, `px`): compose the stamp variants from the singles (a deterministic list of sprite transforms from a seed, rendered on the GPU in a `SubViewport`, because GDScript cannot rotate a 512 px image fast enough on a handset), write `user://cache/stamps/<kind>_<n>_<key>.png`, key = hash of the singles' bytes + the recipe + a generator version; a changed key regenerates and REPLACES the old file, an unchanged one is a cache hit (no boot cost); `STAMPS_REFRESH=1` forces it. The same pass scans each stamp's alpha and records the opaque tiles of an 8 x 8 grid, so `FloorPile3D` draws only those (TILE CULLING, §7.0: the cost lever) | recipe + key selftests headless (the transform list is pure); the pixels verified by the windowed harness; a cold-boot cost row on the Moto (the first boot, no cache) and a warm row (a hit); the scatter rows re-measured with tile culling |
| **SM-3 Stroke** | `ground_strokes`; tyre marks, footprints, cables | selftest + capture; handset row |
| **SM-4 Dense layer** | `ground_layers`; litter, snow, sand | per-pixel cost A/B on the Moto |
| **SM-5 Human transitions** | the regular right-angled border (the same mechanism with no noise) and an optional threshold strip; the ONE-SIDED spill (organic onto human, not the reverse) | capture + A/B |
| **SM-6 Grating** (steam vent ✅ BUILT 2026-10-06, §2) | first (DS-14): a STEAM VENT effect rising through a grating (a world-space VFX emitter, `ground_vents` / a prop, existing VFX path); later, with the liquid materials: see-through holes and a plane below (water, lava), a shader decision ruled BEFORE it is built | the Director's eye; a handset row for the emitter |
| **SM-7 Natural photo floors** | mud, dry clay, forest floor, snow, rock (CC0, `PHOTO_SOURCES.md`, `check_surface.py`) with their patch groups; <= 8 per map | `check_surface.py` PASS; a transition capture per new pair |
| **SM-8 Themes** | laboratory, spaceship, domestic floor sets (SURFACES_CATALOG §2.5-2.7), recolour with A + B | gallery rows |
| **E-1 Experiment** | hide the cell grid beyond the agent's perimeter (Director's idea): does it play better or worse? An interface experiment, not a surface stage | the Director's eye |

## 7. Open decisions (for the Director)

0. **SM-2 handset rows. MOTO MEASURED 2026-10-06 (release APK, `SURFACES_SCATTER`, portrait zoom 0.26 = the whole map in view, `FRAME_PROBE`, a warm-up boot + two per row, boot-to-boot spread under 0.2 ms): scatter OFF 29.8-30.0 ms/frame (GPU 28.4, 139 draw calls); x1 = 597 stamps 35.6-35.8 ms (+5.8, GPU 34.2, 166 dc); x4 = 2408 stamps 51-54 ms (+21); x8 = 4826 stamps 74-75 ms (+44).** The cost is LINEAR IN QUAD AREA, not in count: the placed stamps cover about 1.1 / 4.5 / 9 layers of the floor and cost **~5 ms per full-screen layer** (4.7-5.3 across the three rows), because the quad is blended whole whatever its alpha, and the 2.5 GU `leaf_litter` quads (63 % of the area, 30 % opaque pixels) dominate. So (a) a stamp COUNT is the wrong budget (x1 sat just under the placeholder warning of 600 and already took the Moto over 33.3 ms in this whole-room view), the unit is **scatter layers over the visible floor**; (b) it does not depend on zoom (the floor covered on screen is what is paid); (c) the Galaxy row is still owed; (d) the first lever tried was to stop paying for transparent pixels. **RE-MEASURED on the Moto, two boots each, same scene: tile culling alone (8 x 8 grid, runs of tiles on a row are one quad; the leaf stamps keep 61 % of their tiles, dirt 87 %, pebbles 40 %) cut only 0.8 ms at x1 (35.6 -> 34.8) and ~4 ms at x4 (52 -> 48), and added primitives (37.7k -> 44.8k at x1): the transparent pixels were NOT the main cost.** The second lever, found by asking what a 512 px texture costs at ~80 px on screen: the decal shader sampled `filter_linear` with NO mipmaps (every pixel strides ~6 texels: a cache miss per fetch, and aliasing). **With a mipmap chain on the scatter textures and `filter_linear_mipmap` in `floor_decal3d.gdshader` (a texture with no mipmaps falls back to its base level, so the shard piles and Tier 4 debris are unchanged): x1 32.6-33.0 ms (scatter costs +2.9 over OFF 29.9, was +5.8), x4 40.4-40.8 (+10.8, was +21). Together the cost per full-screen scatter layer fell from ~5 to ~2.4 ms.** `floor_pile_tiles_selftest` pins the tile mask, the culled mesh and the mipmap chain. The budget unit stays "layers over the visible floor"; with ~2.4 ms per layer a typical map (scatter over a third of the floor, about one layer there) costs under 1 ms. Still owed: the Galaxy row, and a layer estimate in the loud warning instead of the 600-stamp count.
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

## 11. Customisation: the open tree, the merit gate, the ingestion of a photo (DS-16; designed, NOT built)

**What already exists.** `TextureResolver` resolves a texture through a chain: `user://textures/<folder>/` first, then the shipped `res://ASSETS/materials/<folder>/`, then `Tier.NONE` (a facade, a slab plane and the macro map go through it; `MaterialRegistry` and `PropRegistry` are two-tier the same way, user wins). The decals (`ART_DIR`), `surfaces/rules.json` and the stamp recipes are `res://` only.

**What DS-16 adds.**
1. **The tree.** `user://textures/<category>/<id>/...` for facades and photo planes (exists), `user://decals/<kind>/...` for the single decals, `user://surfaces/rules.json` merged over the shipped rules. All always present on disk, never hidden by the game.
2. **The gate.** ONE call, `CustomisationGate.allows(category) -> bool`, asked by the resolvers when they reach the user tier: a closed category is skipped and the SHIPPED default draws, silently and correctly (the default pack always renders; user art replaces it only where the permission is held). The permission set comes from the player's profile (progression), never from a file the player can edit. A category is a group of the catalog (`SURFACES_CATALOG`: e.g. natural grounds, corporate floors, industrial floors, scatter marks, `mature` marks), not a single material.
3. **The shipped default pack.** The procedural generators (`tools/asset_generation/gen_*`) are DEV-TIME producers of the pack that ships; a clean build must run them (an asset step in the build, since the PNGs are git-ignored today). The runtime regenerators are only for what derives from user art (the stamps of DS-15).
4. **Photo ingestion** ("send us a photo of wood"): a player photo is not a valid facade. The engine must NORMALISE it: for a FACADE, grayscale, resample to 1024 x 512, match mean and contrast to a target, enforce the mirror symmetry the shader assumes (mirror-tile the crop); for a PHOTO PLANE, make it seamless (offset-and-blend, or mirror-repeat when the Director accepts the symmetry) at 1024 x 1024. Then VALIDATE with the same rules as `check_facade.py` / `check_surface.py`, ported into the engine, and compute `facade_mean` itself (a player never writes a JSON row).
5. **Safety.** Images only, loaded with `Image.load_from_file`, never `ResourceLoader` (a `.tres` / `.res` can carry a script; ACTOR D69); a size and dimension cap; the photo-plane cap (8 per map, ~3 MB VRAM each) enforced at ingestion, not left to the artist.

**Order (revised, DS-17).** Customisation is a late milestone, so NOW: SM-2b (tile culling first, then the regenerator reading the SHIPPED singles through a resolver seam that the user tier plugs into later). LATER, in the customisation milestone: the gate, the ingestion (desaturate at first load and cache; alpha cut-out later), the mod-pack validator app, `SM-9`.

**Open decisions (Director).** (a) Unlock granularity: per catalog CATEGORY (proposed) or per material / kind? (b) A map that needs a locked override: the shipped default renders (proposed), or the thing is hidden? (c) **ANSWERED (DS-17): normalise IN the game** (desaturate at the first load, cache; the alpha cut-out later). (d) Does a locked category still list in the player's folder tree (visible, greyed) or not at all?

