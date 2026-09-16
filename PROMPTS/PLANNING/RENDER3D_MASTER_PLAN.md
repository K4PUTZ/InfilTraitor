# RENDER3D_MASTER_PLAN
## The board in 3D — one packed voxel store, one depth-tested renderer, the 2D board retired — v1.3

**Status:** 🟢 **R3D-0 CLOSED on its gate, 2026-09-16.** The direction was ratified by the
Director on 2026-09-15.
- **Built and gated:** `BoardProbe` and its identity gate; the `Voxel` cost on the Moto
  (~925 B); the baseline re-run on one APK; a paired Moto capture for every R3D-6 item.
- **Found while closing it:** R3D-6 item 1's dark "roof tops" are not roofs. They are 2D
  shadow overlays drawn over the 3D board. The Director moved the item to R3D-5
  (2026-09-16).
- **Next:** R3D-1a.

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
   PLAYGROUND holds 216 104 of them in 215 432 cells (R3D-0). 215 432 objects measured
   **316 MB** on a desktop debug build and **~190 MB on the Moto's release build**
   (§1). PLAYGROUND's voxels therefore cost ~191 MB on the device. A packed store
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
| `Voxel` objects on the Moto (release APK, R3D-0, 2 runs) | 215 432 × **~925 B = +190 MB** native heap alloc | 0.82 MB packed reads +1 MB; a 190.7 MB control reads +191 | DEVICE §15.18 |
| voxels vs cells on PLAYGROUND (R3D-0 `BoardProbe`) | 216 104 voxels in 2 713 containers | 215 432 distinct cells — 672 cells claimed by two slices | R3D-0 |
| the cook's LIGHT step (shared) | 234–408 ms | same | §15.13 |

**Not yet measured, and each has a stage:**
- ~~the `Voxel` cost on the Moto~~ — measured at R3D-0: ~925 B per object (§15.18);
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

#### R3D-0 — what was built, and the gate it earned (2026-09-15, commit `5988234f`)

**`BoardProbe`** (`godot/scripts/systems/board_probe.gd`), reached through the scenario
step `probe <name>`:
- It writes every container's voxels to a text dump: slices, junction columns and slabs.
  Per voxel it records the coordinates, `visible`, `damage_state`, `damage_is_blast`,
  the carved side, variant, substrate and material (bands resolved per level).
- It also writes every cell plane, level by level, as its raw RG8 bytes.
- It reads the containers and the planes, never a tile, so it outlives the 2D board.
- ⚠️ **It stores values, not the hashes this section asked for.** A hash says *that* two
  runs differ, never *where*, and the whole PLAYGROUND board is a few MB of text.
  `dirty` is left out on purpose (TIC bookkeeping, cleared within the frame), and so is
  `face_atlas_rect`, which retires with the atlas.
- Every packed field is range-checked. A value a byte cannot hold aborts the write and
  leaves no file, because a wrapped byte would match a voxel it does not match.
- `board_probe_selftest` pins the format: one damaged voxel moves exactly its
  container's line, and its bytes decode to the damage written.

**`tools/persistent/board_probe.py`** — the only place two dumps are compared.
- `diff A B` compares per voxel and per plane texel, grouped by container kind and by
  level, and prints the first N differences.
- `gate` boots each map twice through
  `probe load; detonate 0; probe g0; detonate 1; probe g1; quit`. It requires every
  probe to be identical across boots, and a **control**: `load` and `g0` must differ,
  or the probe cannot see a grenade.
- `--env KEY=VALUE` flips a flag on every boot, so each later stage runs the same gate
  with its own switch.
- GLASS ships no dev grenades, so the gate seeds two: `GRENADE_GUS=14,12;5,12`, at the
  big pane and at the small pane beside the variant row. `GRENADE_GUS` now reaches the
  APK through DevFlags.

**The gate, earned on the unchanged simulation** — desktop, 2 boots per map. It was run
before the commit, and again on `5988234f` with the same numbers.

| map | voxels · containers · plane levels | run 1 vs run 2 at load · g0 · g1 | control, load vs g0 |
|---|---|---|---|
| PLAYGROUND | 216 104 · 2 713 · 32 | **0 · 0 · 0** voxels, 0 plane bytes | 460 voxels, 2 246 plane bytes |
| GLASS | 114 280 · 1 363 · 32 | **0 · 0 · 0** voxels, 0 plane bytes | 3 867 voxels, 8 063 plane bytes |

- PLAYGROUND grenade #0 moves 460 voxels (380 floor-slab, 80 wall), inside §0.2's
  ~460–500.
- GLASS grenade #0 cracks the big pane (`SLICE_11_10_SW`…). Grenade #1 moves 1 252
  voxels in 36 containers around the small pane.

**What the probe found on its first read** — findings only, nothing changed:

1. **215 432 is the count of cells, not voxels.** PLAYGROUND holds **216 104 voxels**;
   the prototype's figure was its occupancy dictionary's size, which merges cells two
   containers claim. §0.1 and §1 now say so.
2. **The collision census R3D-1a asks for has its first number.**
   - PLAYGROUND has **672 cells claimed twice** and GLASS has 160.
   - Every one is a **slice × slice** pair at the corner where two faces of one GU meet
     — for example cell (8, 8) at levels 80+, claimed by `SLICE_1_1_NW` and
     `SLICE_1_1_NE`.
   - The two claims carry the same material in every case.
   - No slab or column collides.
   - Whether the two claims can take DIFFERENT damage, and which one a cell then shows,
     is the rule R3D-1a still has to write down.
3. **A junction column's id is not unique.**
   - On PLAYGROUND, 8 ids name two different columns each (`JCOL_26_2`, `JCOL_26_4`,
     `JCOL_30_2`, `JCOL_30_4`, `JCOL_34_2`, `JCOL_34_4`, `JCOL_38_2`, `JCOL_38_4`). In
     each pair the two columns are 7 cells apart, 16 voxels each.
   - `"JCOL_%d_%d" % gu_cell` assumes one column per GU, and those GUs hold two.
   - Any lookup by that id finds one of the pair. The probe compares them by
     occurrence.
   - R3D-1's container reference must not key by this id.

#### R3D-0 — the device half (2026-09-15, APK `fb867845…` from `5988234f`)

Full tables: `DEVICE_DIAGNOSTICS` §15.18. Moto g04s, 16 boots interleaved a / b.

**The `Voxel` cost** — scenario step `alloc objects|packed|bytes <count>`, read by
`device_run.py --mem-poll`, in the 3D `NO_BAKE` build so nothing swaps at idle:
- **215 432 objects add +190 MB of native heap in both runs: ~925 B per `Voxel`.**
  PLAYGROUND's 216 104 voxels cost ~191 MB on the device.
- §15.17's desktop-debug figure (~1 540 B, 316 MB) overstated the device by ~65 %.
- The instrument calibrates itself. The same count packed reads +1 MB (0.82 MB
  expected), and a known 190.7 MB byte array reads +191 MB in both runs.
- R3D-1's saving is smaller than §1 first said, but it still dominates the board's other
  per-cell costs: ~190 MB of objects against ~1 MB packed, and 3.2× the 59 MB the 2D
  board's cells free.

**The baseline tables** — one APK re-running DIAG-21/22/23. Every row lands inside the
earlier measurements, so later stages compare against these:

| | 2D (shipped) | 3D (2D writes skipped where noted) |
|---|---|---|
| idle frame, zoom 0.5 → 0.2 | 60.0 → 134.6 ms | 23.1 → 21.6 ms (flat) |
| grenade #0 · #1 wall clock (a / b) | 24.0 / 24.0 · 27.1 / 27.2 s | 10.9 / 10.9 · 11.2 / 11.3 s (skip) |
| grenade #1 worst frame | 1 922 / 2 024 ms (soot fade) | 280 / 308 ms (skip) |
| commit remesh #0 · #1 | — | 113–138 · 123–125 ms |
| memory at idle, PSS · swap | 2 176–2 200 MB · 739–1 246 MB | 1 084–1 094 MB · 0 (`NO_BAKE`) |
| boot → map loaded | 52.7–53.5 s | 23.0 s (`NO_BAKE`) |

- Grenade #0's commit remesh folds **460 voxels** on the device — the same count
  `BoardProbe` reads for that grenade on desktop.
- Run-a against run-b captures of the grenade scenario differ by 0 px in 6 of 8 pairs,
  and by 15 px and 9 px in two frames taken 3 s after a blast.

**The reference captures** — 2D and 3D pairs from the same APK, listed item by item in
`DEVICE_DIAGNOSTICS` §15.18.5:
- **Covered:** item 2 (glass — the PLAYGROUND trio and the GLASS map), 3 (decals), 4
  (dents), 5 (facades and the floor grid), and 6's soot and burnt voxels.
- **Two R3D-5 rows showed up on their own:**
  - the dark diamond under the agent;
  - a red line drawn only in 3D, probably a 2D overlay the board used to cover — not
    identified.
- ⛔ **Not covered, so the capture item of this stage's gate is open:**
  - **Item 1, roof tops dark in 3D.** The `roofs` framing shows a wall face. Its 3D side
    has a dark shape the 2D side does not, but nothing in the frame identifies it as a
    roof.
  - **Embers.** The `detonate` step waits for the blast to end, so the wood burn's first
    capture already comes after the fire.
  - Both need a framing, or a capture step inside the blast, before R3D-0 closes.

#### R3D-0 — the two missing pairs, and the gate closed (2026-09-16, commit `13562fba`)

**The instrument: `capture_at`.** The `detonate` step returns only once the blast is over,
so no step could photograph inside one.
- `capture_at <beat> <offset> <name>` arms a capture, taken `<offset>` after the Room names
  `<beat>`. The Room announces beats through the new `Room.blast_beat` signal, whether or
  not the frame probe is on.
- The offset is in frames (`2f`) or in seconds of process delta (`1.5s`).
  - Seconds are the clock the consequence channel and the embers age on.
  - So a 2D run and a 3D run photograph the same moment of the effect, even though their
    frames cost very different times.
- A capture still armed at `quit` is a `push_error`. A `NEVER_NAMED` arm proved that on
  desktop.

**The Moto run.** Full record: `DEVICE_DIAGNOSTICS` §15.18.6.
- The APK was built from `13562fba`; the installed APK's sha256 is `c3a1a6d3…`.
- 4 boots in order 2D a, 3D a, 2D b, 3D b. The 3D boots skip the 2D writes.
- PLAYGROUND, grenade #3 on the wood trio. When each capture landed:

| step | 2D, a / b | 3D, a / b |
|---|---|---|
| `SOOT_FADE 2f` | 0.269 / 0.241 s | 0.231 / 0.201 s |
| `CONSEQUENCE 0.4s` | 5 / 5 frames · 0.469 / 0.463 s | 10 / 9 frames · 0.419 / 0.408 s |
| `CONSEQUENCE 1s` | 12 / 12 · 1.048 / 1.066 s | 23 / 24 · 1.008 / 1.012 s |
| `CONSEQUENCE 2s` | 24 / 24 · 2.050 / 2.040 s | 51 / 53 · 2.011 / 2.008 s |

- **Framings with no blast running repeat exactly from run a to run b.**
  - The roof frames differ by 0 px in both renderers, except 1 px in 3D's close framing.
  - The closing frame differs by 0 px in 2D and by 0.37 % in 3D.
- **The frames inside the blast differ by 31–85 % of pixels from run a to run b**, in both
  renderers.
  - Every ember, smoke puff and spark rolls its own values with `randf_range()`.
  - ⚠️ **And `RNG_SEED` never reached the APK.** `Room._ready()` read it with
    `OS.get_environment()`, not through `DevFlags`. `[RNG] seeded` printed in the desktop
    log and in none of the 20 Moto logs from 2026-09-15 and 2026-09-16, so every device
    run that set it ran unseeded.
    - **Fixed in `9740116a`** (Director, 2026-09-16), and all 4 re-run boots print
      `[RNG] seeded 1`.
    - Seeded, the in-blast frames still differ by 32–42 % from run a to run b.
      `DEVICE_DIAGNOSTICS` §15.18.6 has the table.
- **What repeats inside the blast is the stage of the effect.** It is the same in runs
  a and b, and in 2D and 3D:
  - yellow-hot at 0.4 s;
  - orange at 1.0 s;
  - mostly dark coals at 2.0 s.

**What the new pairs show:**
- **Embers (item 6).** The 3D board shows them as 2D does: they are a 2D overlay, drawn
  over either board.
  - One difference: only in 3D, small brown flecks and clusters of white dots sit on top
    of them. In 2D the voxel layers cover those.
  - Their source is not identified. The debris overlay (z −8) is the first candidate.
    This is an R3D-5 row.
- **The soot fade (item 6).** Two frames into the fade, 2D is part-way through darkening,
  and 3D shows no scorch at all.
  - The 3D board recolours soot once, after the fade: `[BOARD3D] recolour soot` logs just
    after the capture.
  - The spike's header already says so: its soot fade lands at the end instead of
    stepping. The pair is now on record.
- **Floor depth dim (item 6).** Only the crater frames show it: `r3d0_g_*_after0/1` and
  `r3d0b_pg_*_after`. It has no framing of its own.
- **Item 1: the dark "roof tops" are not roofs.**
  - **What a block is.** A PLAYGROUND material "block" is a hollow box: walls two storeys
    tall (levels 80–95) under a CEILING slab at levels 96–97. The R3D-0 dump holds 54 such
    slabs, over 27 GUs.
  - **The new framing** is `centre 8,-1; zoom 0.5`, over the metal box and the stone box.
    Both roofs read lit in 3D, as in 2D, on the Moto and on desktop.
  - **The dark rhombus** is the size of a box's footprint, and it sits at ground level:
    the box's own interior floor, which no light reaches. In 2D the walls and the roof
    draw over it. In 3D it is drawn over them.
  - **Desktop bisection**, 3D, same framing, using a temporary patch that hid named Room
    nodes (reverted, never committed):
    - hiding `shadow_full_layer` changes nothing;
    - hiding `_tile_shadow` removes the fill;
    - hiding `_shadow_boundary_overlay` as well removes the outline, and the rhombus is
      gone;
    - the GU grid lines drawn across the walls leave with the group holding
      `_gu_grid_overlay` and `_tile_game`;
    - **the red line survives hiding 11 overlay nodes**, and is still not identified.
  - **So item 1 is an R3D-5 row:** a 2D ground-plane overlay drawn over 3D geometry. It is
    not a face-lighting defect. The Director moved it there the same day: *"pode mover o
    item 1"*.

**The gate:**
- ✅ `BoardProbe` reads 0 differences between two runs, on both maps and after both
  grenades (2026-09-15).
- ✅ The Moto `Voxel` number is recorded: ~925 B.
- ✅ The baseline tables are recorded: `DEVICE_DIAGNOSTICS` §15.18.2–15.18.4.
- ✅ Paired Moto captures exist for every R3D-6 item:
  - 1: this section;
  - 2–5: §15.18.5;
  - 6: soot and burnt voxels in §15.18.5; embers, the fade and the depth dim in this
    section;
  - 7: the rows found are listed under R3D-5.

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
  - **Rows R3D-0 found on the Moto (2026-09-16).** On the 3D board each of these is drawn
    over geometry that covers it in 2D:
    - `_tile_shadow` (fill) and `_shadow_boundary_overlay` (outline) over hollow boxes:
      the "dark roof tops", moved here from R3D-6 item 1 by the Director (2026-09-16);
    - the GU grid lines across wall faces;
    - brown flecks and white dots over the embers, not identified (debris overlay, z −8,
      is the first candidate);
    - a red line, not identified; it survives hiding 11 overlay nodes.
  - Dev and debug overlays may stay 2D.
- **The HUD does not move** (rule 11).

**Gate:**
- the inventory table is complete, with a capture per row;
- touch, pinch and pan run on the Moto through the TEL scenarios;
- the input and HUD seam selftests run clean.

### R3D-6 — Look parity

Each item below stays behind a flag until the Director ratifies it from paired Moto
captures, 2D against 3D.

1. ~~**Roof tops read dark** in 3D where 2D reads them lit.~~ **Moved to R3D-5 by the
   Director, 2026-09-16.**
   - The roofs read lit (R3D-0). The dark shape is a hollow box's interior floor:
     `_tile_shadow` and `_shadow_boundary_overlay`, drawn over the 3D walls.
   - The number stays, so items 2–7 keep theirs; the captures and `DEVICE_DIAGNOSTICS`
     cite them.
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
- **v1.1, 2026-09-15.** R3D-0 measured.
  - `BoardProbe` and `board_probe.py gate` were built, and the gate was earned at 0
    differences on PLAYGROUND and GLASS (commit `5988234f`).
  - A `Voxel` object costs ~925 B on the Moto, and the baseline was re-run on one APK.
  - Corrections: PLAYGROUND holds 216 104 voxels in 215 432 cells, and the §0.1 and §1
    figures say so.
  - Findings for R3D-1a: 672 corner cells claimed by two slices, and non-unique
    junction column ids.
  - Open before R3D-0 closes: captures for roof tops and embers.
- **v1.2, 2026-09-16.** R3D-0 closed on its gate.
  - The scenario step `capture_at` photographs inside a blast; commit `13562fba`.
  - The Moto pairs for embers, the soot fade and roof tops are recorded.
  - Item 1's dark shape was bisected to `_tile_shadow` and `_shadow_boundary_overlay`
    drawn over the 3D board. It is proposed as an R3D-5 row, and new R3D-5 rows are
    listed.
  - Found: `RNG_SEED` never reaches the APK.
- **v1.3, 2026-09-16.** The Director's two calls from v1.2.
  - R3D-6 item 1 moved to R3D-5. Its number stays, so items 2–7 keep theirs.
  - `RNG_SEED` is read through `DevFlags` (`9740116a`), and the fix was verified on the
    Moto. Seeded, the in-blast frames still do not repeat.
