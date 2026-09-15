# RENDER3D_MASTER_PLAN
## The board in 3D — one packed voxel store, one depth-tested renderer, the 2D board retired — v1.0

**Status:** 📋 **PLANNED 2026-09-15 — direction ratified by the Director, no stage started.**

**Authority:**
- **The render path.** After DIAG-23 (`DEVICE_DIAGNOSTICS_MASTER_PLAN` §15.15), the Director
  wrote: *"Me parece que o 3D é o caminho mais efetivo. E aí nesse caso, precisamos
  reconfirmar a arquitetura."*
- **The data model.** The Director proposed *"paredes maciças com fachadas inteiras, e
  somente substituir zonas menores por voxels conforme elas ficam sujas"*. Shown the
  mechanism and the measurement in §0.2, the Director answered: *"Certo então vamos fazer
  isso. Faça o planejamento de todas as etapas e deixe documentado."*

**Owner:** engine. The track spans the render, the voxel data, destruction's writer, the
prediction plan's entries, glass rendering, actors, overlays and occlusion.

**Evidence plan:** `DEVICE_DIAGNOSTICS_MASTER_PLAN` §15 (DIAG-19 to DIAG-23). Every
number below comes from there or from §1.

**Companions:** each plan below keeps its own subject. This one owns the migration of its
drawing, and of the voxel storage underneath it.
- `PREDICTION_MASTER_PLAN`, `DESTRUCTION_MASTER_PLAN`, `GLASS_MASTER_PLAN` and
  `VOXEL_LIGHT_MASTER_PLAN`;
- `OCCLUSION_MASTER_PLAN` and `RENDER_ORDER_MASTER_PLAN`;
- `ACTOR_MASTER_PLAN` and `CHARACTER_MASTER_PLAN`;
- `SOOT_STORAGE_REFORM`, `MATERIALS_MASTER_PLAN` (M5) and `PERFORMANCE_MASTER_PLAN`.

---

## 0. The decision

### 0.1 What is ratified

1. **The board is drawn by Godot 3D.** A depth-tested orthographic scene replaces the 32
   opaque + 16 glass `TileMapLayer`s. The engine does not change: DIAG-20 found nothing
   showing that Godot is the limit, and the representation was the anchor (§15.6).
2. **Voxels stay the unit of simulation.** That covers every voxel, the destruction tiers,
   the tenth-shot rule, prediction, glass physics, the light field, TIC, passages and AI.
   Nothing about what the game computes changes.
3. **Voxels stop being objects.** Each `Voxel` is a GDScript object of ~1.5 KB, and
   PLAYGROUND holds 215 432 of them: **316 MB** measured on desktop (§1). A packed store
   holds the same facts in a few bytes per voxel. It is the only authority, and every
   system reads it.
4. **The 2D board retires at parity, and only then.**
   - The rules that describe drawing with tiles stay in force for as long as the 2D path
     is the one that ships: canon rule 8, B1/B3/B5, and VOXEL_MASTER_PLAN's "1 voxel = 1
     tile".
   - They retire at **R3D-8**, on the Director's ratification.

### 0.2 The proposal that was not taken, and the half of it that was

The Director asked whether walls should be solid bodies with whole facades, with voxels
materialised only in the zones that get dirty or damaged. That question has two halves,
and they have different answers.

- **The render half is right, and it is already how the prototype draws.**
  - A greedy merge turns PLAYGROUND's 108 772 visible faces into **367 quads** for the
    whole map, so an intact wall IS one quad carrying its facade.
  - After grenade #1 the 5 touched chunks hold 350 quads: voxel granularity appears
    around the crater and nowhere else.
  - Soot and light never needed geometry. The fragment reads them per voxel from a
    texture over the big quad (§15.11), and each recolour is a 10–22 ms upload.
- **The data half points at the real cost, but zones are the wrong shape for it.** The
  memory is the object overhead, not the voxel count: packing all 215 432 voxels costs
  ~1 MB. Zones would introduce two representations of one wall:
  - every system (destruction, prediction, light, glass, AI, passages) would have to ask
    "solid or zone?";
  - the boundary between the two would be a new place for drift — the pattern that cost
    the glass crack three rebuilds;
  - prediction simulates per voxel without committing, so it would have to materialise
    zones speculatively;
  - a grenade touches ~460–500 voxels, and each materialised zone would pay the object
    cost again;
  - two thirds of the voxels are floors and roofs (145 992 slab voxels against 69 440
    wall voxels), so "solid walls" alone covers a third.

What the proposal keeps: **intact surfaces show whole facades** (§9 Q1 asks whether floors
follow walls), and **fine detail — decals, dents, per-voxel art — is spent only around
damage** (R3D-6).

---

## 1. The evidence this plan rests on

Moto g04s, portrait, world render scale 1.0, release APK, unless marked desktop.

| | 2D board (shipped) | 3D board | source |
|---|---|---|---|
| idle frame, zoom 0.5 | 60.0 ms · 1 641 draws | 17.9 ms (step 1) · **22.9 ms** after step 2c · 225 draws | §15.7, §15.15 |
| idle frame, zoom 0.2 (pinch floor) | 134.5 ms | 17.1 ms | §15.7 |
| grenade #1 · wall clock | 28.5 s | 11.8 s (2D writes skipped) | §15.11 |
| grenade #1 · worst frame | ~1 800 ms (the 2D soot-fade rebuild) | 265–279 ms (after DIAG-22) | §15.13 |
| commit remesh, 5–6 chunks, GDScript | — | 118–146 ms | §15.11 |
| memory at the shipped look | 2.17–2.20 GB PSS, 0.7–1.4 GB swapped | ≤ 1.04–1.10 GB, 0 swapped | §15.15 |
| boot → map loaded | 52–54 s | 22.8–22.9 s | §15.15 |
| the 2D board's own cells | 205 704 opaque + 2 240 glass → 59 MB native heap, 0 graphics | — | §15.15 |
| `Voxel` objects (desktop debug, 2 runs) | 215 432 × ~1 540 B = **316.4 MB** | the same count as `PackedInt32Array`: 0.8 MB | §15.17 |
| the cook's LIGHT step (shared) | 234–408 ms | same | §15.13 |

**Not yet measured, and each has a stage:**
- the `Voxel` cost on the Moto (R3D-0);
- a 3D-only load and its peak (after R3D-2);
- the web export's Compatibility renderer running the 3D board (R3D-3);
- the Galaxy A16 (R3D-8).

---

## 2. What stays, what changes, what retires

| System | Fate | Where |
|---|---|---|
| `Edge`, `Slice`, `Slab`, `JunctionColumn`, the registries, `JunctionResolver`, `WallEdgeData` | **stay** — they keep identity and API; their `voxels` arrays become views over the store | R3D-1 |
| destruction tiers, `BlastCalculator`, `PassageQuery`, glass physics, the damage tables | **stay** — they read and write the store | R3D-1 |
| `VoxelLightField`, the prediction pipeline (`build_plan` → `WorldDelta` → `commit`), TIC, turns, AI | **stay** — their occupancy comes from the store, not from layer cells | R3D-1, R3D-2 |
| the cell planes (`_soot_images`: R = face soot code, G = light bucket) | **stay** — move to a render-neutral owner that both renderers read | R3D-2 |
| `TextureResolver`, `MaterialRegistry`, `FacadeSampler` (FNV-1a window origins), facades | **stay** — a 3D face samples the facade through UVs | R3D-3, R3D-6 |
| the prediction plan's tile-shaped entries (`source_id` / `atlas_coords` / `alt` / `prev_alt`) | **change** to voxel key + target state + light bucket + soot code | R3D-2 |
| `_glass_layers` as the occupancy authority glass systems read | **changes** to the store | R3D-2 |
| `Board3DLive` (a spike under `RENDER3D=1`) | **becomes** the production renderer | R3D-3 |
| agent, guards, props, in-world VFX (2D nodes) | **replaced** by depth-correct equivalents (spike first) | R3D-4 |
| ground-plane overlays, picking, `floor_layer` | **re-expressed** per overlay; picking by camera ray | R3D-5 |
| OCC-21 erase, OCC-27 wireframe | **replaced** by a 3D cutaway mechanism | R3D-7 |
| `VoxelRenderer` tile placement and layers, TileSet atlas pages, `BakedTileLookup`, damage composite pages, light alternatives and the mint cache, glass tiles, render-order clip / seam cull, the voxel face shader | **retire** | R3D-8 |
| HUD (`CanvasLayer`, `hud_controller.gd`, canon rule 11) | **untouched** | — |
| the camera angle D26 (30° down / 45° around), four facings D44, the character bake pipeline | **untouched** — D26 is the 3D camera | — |

---

## 3. Principles — binding on every stage

1. **One authority per fact.** The store is the only place voxel state lives. A mirror
   exists only inside its own stage's shadow phase and is deleted when that stage closes
   (`two-authorities-remove-one`).
2. **Shadow, then flip, then delete.** Each migration runs the new path beside the old
   one, with an identity gate. It flips behind a same-binary flag, and code is deleted
   only after the gate holds on the real maps. This is `SOOT_STORAGE_REFORM` SS-0…SS-3,
   which already worked here.
3. **Assert identity, not absence.** Gates compare per voxel and per cell, and print the
   first differences. "No errors" is not a gate.
4. **The Moto is the arbiter of cost; the desktop is the arbiter of correctness.** Every
   stage closes with a same-APK A/B on the Moto. From R3D-8, the Galaxy A16 and the web
   export join.
5. **A green selftest is not the feature on the real map.** Every gate runs PLAYGROUND and
   GLASS: two dev grenades, a shot, a pane shatter, an F2 reload, a `SaveState` restore.
6. **Staged migration, never a sweep.** `.voxels` has 135 call sites in 15 runtime files,
   `damage_state` has 136 sites in 17, and 20 selftests construct or read them. They move
   subsystem by subsystem.
7. **Rotation must not be foreclosed.** Every key that outlives a frame is base-space
   (`rotation-is-coming-back`).
8. **Canon retires only on ratification, at R3D-8.** Until then rule 8, the L1 hook and
   B1–B6 hold for the 2D path, and a 3D stage that needs to bend one stops and asks.
9. **No look change without paired Moto captures and the Director's eye.** A look item
   stays behind a flag until it is ratified.

---

## 4. The stages

### R3D-0 — Baseline and instruments

Nothing moves until the gates that judge the moves exist and are proven deterministic.

- **The `Voxel` cost on the device.** A DevFlags instrument allocates N `Voxel` objects
  after the load, and `device_run.py --mem-poll` reads PSS before and after. Build it
  twice, once with the objects and once with the same count packed, so the instrument
  calibrates itself.
  - This confirms or corrects the 316 MB desktop-debug figure on an ARM release build.
- **`BoardProbe`, a renderer-independent identity instrument.**
  - Per voxel it hashes visible, `damage_state`, carved side, variant, substrate and
    material, grouped by container and by level.
  - Per level it hashes the cell planes.
  - It prints totals and the first N differences.
  - Every later gate uses it. It takes over the role `INFILTRAITOR_CELL_PROBE` plays
    today, which reads the tilemap and therefore dies with it.
- **The reference set.**
  - One APK re-runs DIAG-21/22/23's tables as this plan's baseline: idle ladder, two
    grenades, memory.
  - Paired 2D/3D Moto captures cover every R3D-6 look item.
- **Gate:**
  - `BoardProbe` reads 0 differences between two runs of the same code, on both maps,
    after both grenades (earn the gate first);
  - the Moto `Voxel` number is recorded;
  - the baseline tables are recorded.

### R3D-1 — The packed voxel store (the data half)

**R3D-1a, the spike that picks the layout, with its decision rule written first:**

- **(A) A dense per-level cell grid.** Per level: a `PackedByteArray` for state, one for
  material index, and a `PackedInt32Array` for container reference and index, sized to the
  map bounds. Containers compute their cells from their geometry.
- **(B) Per-container packed arrays**, with a separate derived occupancy grid.

The rule weighs:
1. memory on PLAYGROUND and on the largest map;
2. the read cost of the three hot readers — the light field's `.has(cell)`, the mesher,
   and the prediction WALK, which is 66 % of a plan's cost (`PREDICTION` §8.8) — timed
   in GDScript on the Moto;
3. **the collision census**: how many cells two containers claim.
   - The prototype's `_put()` silently lets the last writer win, so the count is
     unknown.
   - The chosen layout must either show zero collisions or write down the rule.
- (A) makes the store and the occupancy one thing, which is why it is the favourite. It
  does not win until the numbers say so.

**The state per voxel**, from `voxel.gd`. The widths of variant and substrate are measured
from the data, not assumed.

| field | values | bits |
|---|---|---|
| `visible` | bool | 1 |
| `dirty` | bool (TIC) | 1 |
| `damage_state` | INTACT, CRACKED, DESTROYED, DENTED | 2 |
| `damage_is_blast` | bool | 1 |
| `damage_carved_side` | NONE, TOP, BOTTOM, LEFT, RIGHT | 3 |
| `damage_variant`, `damage_substrate` | measured in R3D-1a | measured |
| material | index into `MaterialRegistry` | 8 |
| container ref + index | replaces `_parent_container_id` | 32 |
| `face_atlas_rect` | 2D bake only | **not carried** — retires with the atlas |

**R3D-1b — the store in shadow.**
- It is built at load beside the objects, and written through the one seam destruction
  already owns (the sole writer of `Voxel.visible` and the damage setters).
- `BoardProbe` compares the store against the objects on PLAYGROUND and GLASS: both
  grenades, a shot, a pane shatter, F2 reload, `SaveState` restore, and
  `_capture_all_four_views()`.

**R3D-1c — readers move one subsystem at a time**, each behind a flag and a 0-difference
gate:
1. `VoxelLightField` occupancy;
2. the prediction plan builder;
3. glass (shatter, crack, fall, occupancy);
4. `BlastCalculator`, `PassageQuery`, the occlusion set;
5. `Board3DLive`.

**R3D-1d — the objects go.**
- `Slice`, `Slab` and `JunctionColumn` answer per-voxel questions from the store; the
  `Voxel` class becomes an index or a transient view, or is deleted, as R3D-1a decides.
- Memory is re-measured on the Moto against §1.

**Risks, and how each is caught:**
- **Packed-array access in GDScript can be slower than an object field read in a hot
  loop.** The light field build and the prediction WALK are timed before and after, on
  the Moto.
- **`_base_damage` and the soot store are keyed by base coordinates.** Their formats do
  not change, and `SaveState` round-trips are in the gate.
- **20 selftests build `Voxel` objects.** Each moves or is replaced in the stage that
  moves its subsystem, never in a batch at the end.

**Gate:**
- `BoardProbe` reads 0 differences on every scenario above, for each R3D-1c flip;
- the Moto memory table and the hot-loop timings are recorded;
- the selftests run clean;
- the 2D captures are 0 px against R3D-0, with a fixed FPS and a 400-frame detonation wait.

### R3D-2 — Render-neutral world state: the plan, the light, the glass

After this stage, no simulation or prediction code reads a tile.

- **`WorldDelta` and plan entries** carry a voxel key, the target state, the light bucket
  and the soot code.
  - `source_id`, `atlas_coords`, `alt` and `prev_alt` leave the plan.
  - While the 2D board exists, its writer resolves its own tiles from the entry.
- **`build_occupancy()` becomes a store read plus the predicted-destroyed overlay.** This
  is `DEVICE_DIAGNOSTICS` §15.14 item 1: the cook's LIGHT step, 234–408 ms. The 2D build
  gains it too.
- **Plane writes, at load and on every apply, iterate the store, not
  `layer.get_used_cells()`.** This is what blocked a 3D-only load in DIAG-23.
- **The cell planes move to a render-neutral owner** (name decided at build time), which
  both renderers read.
- **Glass occupancy leaves `_glass_layers`.** The plan builder, the entry writer, the
  occlusion set and the glass selftests read the store.

**Gate:**
- the 2D build is pixel-identical (0 px, same binary, flag A/B, both grenades);
- the plan census is identical;
- `BoardProbe` and the planes read 0 differences;
- the LIGHT step and both grenades are timed on the Moto;
- **the first true 3D-only load**, with 2D placement never run: DIAG-23's clean number
  and its load peak.

### R3D-3 — The 3D board becomes the production renderer

- **`Board3DLive` leaves `spikes/`** and reads the store directly, so the per-load
  dictionary collect (2.2 s on the Moto) is gone.
- **Geometry:**
  - faces merge by material, and light and soot come per voxel from the planes (§15.11);
  - chunk size (16 vs 32 voxels) is chosen by measurement;
  - the remesh builds from a store snapshot on a `WorkerThreadPool` task and swaps in on
    the main thread;
  - recolour uploads only the levels and rows a change touched.
- **Camera:** orthographic, D26's 30° down and 45° around.
  - An orthographic view pitched θ below the horizon foreshortens the ground by sin θ,
    and sin 30° = 0.5 — the 2:1 diamond exactly. `DESIGN_MASTER_PLAN` §1's 26.57° is the
    tile edge slope, atan ½, the same projection.
  - The ground-plane map between 2D and 3D stays measured from Room, not reasoned.
- ⚠️ **Vertical scale is a measurement to settle here.**
  - The 2D board steps **20 px per level** (`VOXEL_STEP_PX`).
  - A true cube in this camera projects 32 px/√2 × cos 30° = **19.6 px**, and the
    prototype draws cubes. Over a storey that is 156.8 px against 160 px (gameplay
    `WALL_FLOOR_STEP_PX` is 158).
  - The actor bakes were taken at the true 30°. So compare a cube board and a
    2D-matched board against the baked agent's feet and head, and let the Director pick
    from paired captures.
- **The hidden 2D board stops being built** when the 3D board is on (a flag for the A/B,
  removed at R3D-8).
- **The web export is checked NOW, not at R3D-8.** The Compatibility renderer must boot
  the 3D board: `Texture2DArray`, the custom spatial shaders, `MultiMesh`.

**Gate (Moto):**
- the idle frame against 22.9 ms;
- the commit frame against 262–279 ms;
- both grenades' worst frame;
- load time and memory;
- 3D run-a against run-b captures at 0 px;
- the web export boots and draws the board.

### R3D-4 — Actors, props and in-world VFX in depth

**R3D-4a, a spike with its decision rule written before measuring:**

- **(A) Billboards in the 3D scene.** Quads carry the baked frames, with D17's normal-map
  relight in a spatial shader.
- **(B) 2D sprites composited over the board against its depth buffer**, at a world-space
  depth per sprite.

The criteria:
1. an occlusion fixture: the agent behind a wall, behind glass, under a roof edge, on
   each side of a junction column;
2. Moto frame cost;
3. relight looks identical in paired captures;
4. D44's four facings and D47's GU-boundary snap intact.

**Scope:**
- the agent, the guards and their vision cones;
- the grenade prop, its throw flight and settle;
- the collectible and the showcase props;
- glass shards, rain, remnants and the crack sprite;
- smoke, debris, embers, tracers and shrapnel. `CircleField` becomes a 3D `MultiMesh`, and
  keeps the `custom_aabb` lesson.

The screen flash and the negative strobe stay screen-space.

**Gate:** the fixture captures, the Moto frame cost, and the Director's look call.

### R3D-5 — Overlays, picking and the floor layer

- **Picking** casts a camera ray against the ground plane, and against the store for
  walls. It replaces `floor_layer.map_to_local()` / `local_to_map()` in input.
  - `IsoProjection` keeps its measured basis wherever an overlay stays 2D.
- **`floor_layer`'s readers** move to store or grid queries, and `floor_layer` retires:
  `selection_controller`, `movement_overlay`, `ViewContext` (`gu_visible` / `gu_total`),
  and `room.gd`.
- **Per-overlay decision table.** There are ~45 scripts that draw in 2D today, and each
  gets a row with a decision and a capture.
  - The ground-plane gameplay overlays go to depth-tested ground quads or stay
    screen-space, decided per group by R3D-5a: movement range, path preview, the
    selection diamond, the aim dome, the throw perimeter and arc, the noise rings, fog of
    war.
  - The dark diamond under the agent that DIAG-21 showed is one of these rows.
  - Dev and debug overlays may stay 2D.
- **The HUD does not move** (rule 11).

**Gate:**
- the inventory table is complete, with a capture per row;
- touch, pinch and pan run on the Moto through the TEL scenarios;
- the input and HUD seam selftests run clean.

### R3D-6 — Look parity

Each item below stays behind a flag until the Director ratifies it from paired Moto
captures, 2D against 3D.

1. **Roof tops read dark** in 3D where 2D reads them lit. Seen since step 1, unexplained.
2. **Glass:** the strong blue with facets, pane edges, the crack sprite and the craze
   family, and a pane's side sliver.
3. **Damage decals** from `ART_SPECIFICATIONS` §7 families, per voxel: a decal/variant
   channel beside the planes, and a texture array per material family.
4. **Dents:** a DENTED voxel's carved side becomes a real inset in the mesh.
5. **Whole facades on intact surfaces**, per wall run. `FacadeSampler`'s window origins
   replace the prototype's world-space UVs. Floors per §9 Q1.
6. **Floor depth dim, embers and burnt voxels, the soot fade's look.**
7. **Anything the R3D-0 reference set shows that this list missed** — it is added, not
   waved through.

**Gate:** each item has a pair of captures and a ratification line in this plan.

### R3D-7 — Occlusion and cutaway in 3D

- **`OCCLUSION` O1 holds:** occlusion is VIEW, not STATE, and it never writes the store.
- **OCC-21's cell erase and OCC-27's wireframe are replaced by a 3D mechanism**, chosen
  from a spike and the Director's look call. The candidates:
  - a world-space clip or dither of the geometry between camera and agent;
  - a storey cutaway for roofs;
  - an outline.
- **`OCCLUSION` §7's X-ray mask becomes world-space by construction** (depth), which
  resolves the defect recorded at the head of §7.
- **`OCCLUSION` Part 4 (interior cutaway) resumes on this renderer.**

**Gate:** the fixture captures, the Moto frame cost, and the Director's look call.

### R3D-8 — Retire the 2D board (the canon change)

**Entry condition:** R3D-4 to R3D-7 are ratified. **The Director ratifies the retirement
itself.**

**Deleted:**
- `VoxelRenderer`'s tile placement and its layers;
- the TileSet atlas composition (`BakeCompositor` pages) and `BakedTileLookup`;
- the damage composite pages and `DamageCompositeCache`;
- light alternatives and the mint cache;
- glass tiles, the render-order clip and the seam cull;
- the 2D face shader and its soot textures;
- OCC-21 / OCC-27;
- the 2D-only instruments.

**Selftests:**
- 19 read tilemap cells and 17 call `get_layer()`;
- each is migrated to `BoardProbe` or the store, or deleted with a written reason.

**Canon, edited in `CLAUDE.md` and the docs:**
- Rule 8 is rewritten for the store: voxel state reaches the screen only through the store
  and the mesher.
- L1 is retargeted, since levels stay absolute and the store is keyed by level. Rule 9
  holds.
- B1, B3 and B5 retire. B2, B4 and B6 survive wherever facades, FNV-1a origins and loud
  failure still apply.
- These become historical: `VOXEL_MASTER_PLAN`'s "1 VOXEL = 1 Godot Tile" and
  `RENDER_ORDER_MASTER_PLAN`.
- `PERFORMANCE_MASTER_PLAN` P4 and P6 become moot.

**Gate:**
- full matrices on the Moto **and the Galaxy A16** — idle ladder, both grenades, memory,
  load — against §1;
- the web export plays a grenade;
- every remaining selftest is clean, and invariants and CODEMAP pass.

### R3D-9 — Rotation returns

- **A 90° camera yaw replaces `_set_perspective()`'s full re-layout for drawing.**
- **Whether the gameplay layout still rotates with the view is the Director's call** (§9
  Q3). `MAP_MASTER_PLAN`'s `_layout_with_perspective()` rotates it today.
- **Sprites pick their D44 facing relative to the camera's yaw.**
- **Base-space keys are audited:** the soot store's faces, D25's carved side, the glass
  craze variant key.

**Gate:**
- the four-view captures agree by identity;
- the Moto frame cost of a rotation is recorded;
- `SOOT_STORAGE_REFORM` SS-6's rotation proof runs on this renderer.

---

## 5. Order, dependencies, and what folds in

```
R3D-0 ─► R3D-1 ─► R3D-2 ─► R3D-3 ─┬─► R3D-4 ─┐
                                   └─► R3D-5 ─┴─► R3D-6 ─► R3D-7 ─► R3D-8 ─► R3D-9
```

- **R3D-1 and R3D-2 pay the 2D build too**, in memory and in the LIGHT step. If the track
  stopped there, the game would still be better.
- **R3D-4 and R3D-5 can run in either order** once R3D-3 exists.

**Open items elsewhere that this plan absorbs, so they are not built twice:**

| item | now lives in |
|---|---|
| `DEVICE_DIAGNOSTICS` §15.14 item 1 (cook LIGHT step) | R3D-2 |
| §15.14 item 2 (3D commit frame) | R3D-3 |
| `SOOT_STORAGE_REFORM` SS-6 (rotation) | R3D-9 |
| `SOOT_STORAGE_REFORM` SS-4 and SS-5 | unchanged, but the store they write is a plane both renderers read |
| `OCCLUSION` Part 4 and §7 | R3D-7 |
| `MATERIALS` M5 (voxel props, "blocked on renderer v2") | after R3D-3 — **this plan is renderer v2**; thin, half-thickness geometry is natural in 3D |
| `GLASS` look on the new renderer | R3D-6 |
| `PERFORMANCE` P4, P6 | moot at R3D-8 |
| `TOP_TEXTURE` Part 3 (textured interiors) | R3D-6, since an interior is a face with facade UVs |

## 6. What this plan does NOT do

- No engine migration.
- No gameplay or design change.
- No change to D26, D44, D47 or the character pipeline.
- No new materials.
- No HUD redesign.
- No detonation design change — `DETONATION_PRESENTATION` is closed and its event shape
  holds.

## 7. Risks

| risk | caught by |
|---|---|
| GDScript packed-array access slower than object fields in hot loops | R3D-1a / R3D-1d timings on the Moto |
| Compatibility renderer (web) lacks a feature the board uses | checked at R3D-3, not R3D-8 |
| Mali cost of shader branches (the 0.6–2.2 ms untaken-branch lesson) | debug paths behind `#define` builds from the start |
| two renderers drifting during the migration | both read one store; `BoardProbe` gates every flip |
| look regressions no gate sees | paired Moto captures per R3D-6 item, Director ratification |
| selftest rewrite volume | per-stage migration (principle 6), never a batch at R3D-8 |
| persisted state (`_base_damage`, soot store, `SaveState`) | base-space keys unchanged; round-trips in every gate |
| a stage that needs to bend canon before R3D-8 | principle 8: stop and ask |

## 8. Open questions for the Director

1. **Floors.** Should an intact floor show its whole facade the way walls will? Today the
   2D floor shows its 8×8 voxel pattern per GU.
2. **Actors.** Billboards or depth-composited 2D? R3D-4a measures both, and the look call
   is the Director's.
3. **Rotation.**
   - Four fixed views as today, or a free orbit?
   - Does the gameplay layout keep rotating with the view, or does only the camera turn?
4. **The web export.** Must it run the 3D board at parity — it is the phone-test path
   today — or does the APK become the phone test once 3D lands?
5. **Decals and dents in 3D.** Match the 2D atoms, or re-author for faces?
6. **The cutaway style in 3D** (R3D-7).
7. **The vertical scale** (R3D-3): true cubes, 19.6 px per level, or the 2D board's 20 px.

## 9. Revision history

- **v1.0, 2026-09-15.** Opened on the Director's ratification. Stages R3D-0 to R3D-9,
  written from `DEVICE_DIAGNOSTICS` §15 and the `Voxel` object measurement.
