# RENDER3D_MASTER_PLAN
## The board in 3D — one packed voxel store, one depth-tested renderer, the 2D board retired — v1.8

**2026-09-19 update (v1.8) — `RENDER3D` IS NOW THE DEFAULT** (`RENDER3D=0` = the 2D board, until R3D-8; the selftest
harness pins `RENDER3D=0` because 19 suites read tilemap cells). Session summary:
`PROMPTS/RESUMO_SESSAO_2026-09-19_R3D6_R3D7.md`.
- **R3D-6 item 2 (glass): look RATIFIED by the Director** (the pane, the crack decals, their removal with the
  destroyed glass). The rim wedge is built (`[R3D-6h]`). Root causes found and fixed this session: a chunk-size
  mismatch (`>> 5` vs 16) that left the blast's remesh on the wrong chunks (it was NEVER `touched_voxels`), the glass
  erase and crack re-cut skipped under `SKIP_BOARD_WRITES`, and a soot wave that read the empty tilemap.
- **R3D-6 items 3 (decals) and 4 (dents): BUILT, ratification pending.** Items 5 (whole facades), 6 (embers, burnt
  voxels, floor shards) and the floor-light jump at the end of a blast are look tuning: **deferred by the Director until
  the port is complete** ("o ajuste fino só importa quando toda a mecânica já existir").
- **R3D-7 (cutaway): BUILT and APPROVED** ("Maravilha tudo certo"), with the ORIGINAL 2D mechanism (see R3D-7).
  Not measured on the Moto.
- **Open register additions:** wall picking by ray still needs the Director's call; guards behind walls are not
  revealed by the cutaway and glass is not ghosted; the cutaway's Moto cost (mesh rebuild per agent step, a
  half-voxel ray march per line piece) is unmeasured; the R3D-6 decal/dent/cutaway captures are desktop only.

**Status (2026-09-18, v1.7):** 🟡 **R3D-0 to R3D-5 are built. Everything that draws in the game world now
draws in the 3D board's world, depth-tested: the board (R3D-3), the actors, props and every
in-world VFX (R3D-4), and the ground overlays, the fog and the picking (R3D-5).** The 2D board
still ships underneath, behind `RENDER3D=1`, until R3D-8. **Next: R3D-6 (look parity, ratified per
item from paired captures), R3D-7 (the 3D cutaway), R3D-8 (retire the 2D board and its canon),
R3D-9 (rotation returns).**

**The register of what is still OPEN** (each is written up in its own section; nothing here blocks
starting R3D-6):
- **R3D-4:** `AgentProbePropRef` has no production instance and no capture; the collectible was
  verified by flipping `TEST_ZONE_COLLECTIBLES_ENABLED` locally; the muzzle flash's floor is an
  estimate (`muzzle_floor_drop_px`); shrapnel has no capture of its own; the glass **crack sprite**
  moved to R3D-6 (it draws nothing under `RENDER3D=1`).
- **R3D-5:** `floor_layer` is NOT retired — it still owns TILE DATA (walkable, used cells,
  `set_cell`), which retires with the 2D board at R3D-8; picking a WALL by ray is not built and needs
  the Director's call; the movement/picking checks on the Moto (and touch/pinch/pan through the TEL
  scenarios) were not run — no device was connected.
- **By decision, staying in screen space:** the aim dome, the throw arc, the shrapnel preview rays,
  the tracer, the noise icons and the cursor.
- **Measured, not from these stages:** the detonation's worst frame is ~1 s on the Moto in both the 2D
  and the 3D VFX (the light/consequence cost).
- **Rules set on the way:** any new VFX stores world-space state (ground + height); a level is asked of
  `ground_plane_level()`, never a literal (a literal `0` had silently broken four VFX callers).

*Earlier status (kept):* 🟡 **R3D-1d CLOSED 2026-09-17: `VoxelStore` is the writer, `Voxel` is a thin
`claim:int` wrapper, and the Moto remeasure confirms the win.** R3D-0/1a/1b/1c closed in
turn from 2026-09-15 to 2026-09-16 (packed store built, layout B confirmed, shadow
gated, all five readers moved onto the store); R3D-1d step 1 (2026-09-17) removed the
objects themselves. Full narrative below and in the revision history.
- **R3D-1b:** at every stage the objects' dump and the store's are identical. The derived
  grid matches, no write is lost, and the flag changes 0 px.
- **R3D-1a:** on the Moto, B is fastest on all three hot readers, and uses 13.5 MB against
  the objects' 191 MB.
  - A (the dense grid) fails the speed gate: its full walk is 16 % slower than the
    objects.
  - Ac (chunked A) passes every gate, but scores 69 % worse than B.
- **Built and gated:** `BoardProbe` and its identity gate; the `Voxel` cost on the Moto
  (~925 B); the baseline re-run on one APK; a paired Moto capture for every R3D-6 item.
- **Found while closing it:** R3D-6 item 1's dark "roof tops" are not roofs. They are 2D
  shadow overlays drawn over the 3D board. The Director moved the item to R3D-5
  (2026-09-16).
- **Found by R3D-1b's controls (not caused by the store):** a rotation round trip, and the
  SaveState restore, lose the damage of 21 voxels on PLAYGROUND — junction columns and
  box corners (see R3D-1b). Offered as a separate task.
- **R3D-1c step 1 FLIPPED** (Director, option A): the light field's occupancy reads the
  store by default. The voxels are identical, and the light changes only in the three
  ratified classes.
  - On the Moto: play costs the same, the load +0.9–1.0 s and the native heap +15–18 MB,
    until R3D-1d.
- **R3D-1c step 2 DONE:** the prediction WALK reads the store.
  - The plans are identical.
  - On the Moto: the WALK is −43 % and each grenade is 1.3–1.5 s shorter.
- **R3D-1c step 3 DONE:** glass reads its voxel state from the store, identical on/off.
  This is proven live by a sabotage, because the probe alone could not see a path
  difference that ended in the same voxel set.
- **R3D-1c step 4 DONE:** `PassageQuery` and the point impact read the store,
  identically. The soot BFS was measured +11–16 % through the store and stays on the
  objects until its input map is keyed by claim.
- **R3D-1c CLOSED:** all five readers are on the store.
  - Moto, from the step 5 A/B: load 24.4 → 22.8 s, commit remesh −20 %.
  - Moto, from step 2: grenades −1.3–1.5 s.
- **R3D-1d step 1 DONE (2026-09-17, commit `75b97af6`):** `VoxelStore` is the writer
  (`set_damage()`/`set_visible()`), and `Voxel` is a thin wrapper (`claim:int` + the
  store) — the seven duplicated damage/visibility fields are gone from every real
  voxel. A detached `WorldDelta` projection (no claim) still works through a lazy
  `_LocalState` side object that costs nothing on a real voxel. 57/57 selftests,
  `board_probe.py gate`, `check_invariants` and `gen_codemap --check` all pass.
- **R3D-1d steps 2-4 DEFERRED to R3D-2** (Director, 2026-09-17). Once `Voxel` is thin,
  its properties already dispatch through `VoxelStore` by claim — reading
  `voxel.damage_state` off a `Voxel` held in `cell_to_voxel`/`damaged_voxels` already
  *is* a claim-keyed read, wearing a clean accessor. Migrating those dicts' VALUES from
  `Voxel` to a bare `claim:int` would only move the bit-unpacking into every call site
  by hand, for memory that is not where PLAYGROUND's ~191 MB was (that dict holds tens
  of entries per shot/detonation, not 215 432). Worse, `detonation_plan_builder.gd`'s
  `damaged_voxels` can legitimately hold claim==-1 detached projections
  (`WorldDelta.project_voxel()`, W-PRECOOK-02) that have no claim to read from at all —
  migrating it would need either a claim→Voxel resolver on `VoxelStore` or a small
  struct carrying the projected fields, for a stage whose own header already says "so a
  repaint and a detonation cannot disagree" (i.e. `BlastCalculator`'s
  `derive_soot_rings()`/`apply_self_soot()` must stay one shared implementation, not
  fork per caller). `WorldDelta`'s own plan/Delta keys (Step 3's actual target) are the
  same story: R3D-2 re-keys the plan and `WorldDelta` around a render-neutral store
  read anyway, so this rides along with that redesign instead of doing it twice.
- **R3D-1d step 5 MEASURED (2026-09-17), Moto g04s, `com.example.infiltraitor`, the
  same `alloc objects|packed|bytes <count>` scenario instrument R3D-0 used
  (§15.18.1).** 3 single boots (not R3D-0's 16 interleaved — the Director connected the
  device mid-session; a tight median would need more runs):

  | run | `alloc packed 215432` (control, ~0.82 MB expected) | `alloc objects 215432` |
  |---|---|---|
  | b | +0.83 MB | **+87.2 MB** |
  | c | +0.85 MB | **+140.2 MB** |
  | d | +0.84 MB | **+100.4 MB** |

  - The control reads +0.83–0.85 MB every run — the instrument is calibrated, same as
    R3D-0.
  - **215 432 thin `Voxel` wrappers cost 87–140 MB, median ~100 MB (~424–682 B each,
    median ~465 B) — against R3D-0's ~190 MB / ~925 B for the old object.** Roughly
    half. PLAYGROUND's 216 104 voxels now cost an estimated ~90–100 MB on the device
    instead of ~191 MB, which is the real number R3D-1a's decision rested on.
  - The spread (87–140 MB) is real run-to-run variance on a single boot each, not
    measurement error in either direction — R3D-0 hit the same zram-compression
    confound (§15.18.1's own note) and used 16 interleaved boots to median through it.
    This is a confirmatory remeasure, not a new headline number to re-cite elsewhere.
  - **Hot-loop risk (packed-array access vs. object field read) not adversely
    measured:** one PLAYGROUND grenade detonation (`RNG_SEED=1`, 4 dev-seeded
    grenades, `EVENT_FRAMES=1`) ran 220 frames / 20.1 s wall clock, mean 91.3 ms, worst
    298.3 ms — same order as R3D-1c step 5's closing table (18.0–18.4 s per grenade,
    22.9–23.3 ms idle), not an exact A/B (different grenade seed/count, one boot, no
    interleaving) so not diffable line-for-line against that table, but no regression
    signal.
  - Logs (local, not tracked): `/tmp/r3d1d_step1_memcheck_{b,c,d}.log`,
    `/tmp/r3d1d_step1_grenade2.log`.
- **Next:** R3D-1d is closed at step 1 (steps 2-4 deferred to R3D-2, step 5 measured
  above) — proceed to R3D-2.

**R3D-2 progress (2026-09-17, commit `a6436cd1`):**
- **Step 1 CLOSED — `build_occupancy()` is store-only.** The `STORE_OCCUPANCY` flag and its
  tile-walk fallback (`get_used_cells()` + `_ghosted_cells` + `_glass_layers` unions) are
  deleted; the function now always answers from `VoxelStore.occupancy_dict()`. Confirmed 0
  differences against the old tile-walk (`Room.scenario_occupancy_compare`) at load and
  across both PLAYGROUND grenades before deleting the fallback. Neither ghosted cells nor
  glass needed a separate fold-in: occlusion never marks a claim invisible (O1) and glass
  voxels are ordinary claims in the store regardless of render sublayer, so the store
  already reported both. One selftest fixture that never built a `VoxelStore` over its
  registry was fixed the same way R3D-1d fixed its own casualties.
- **Step 2 ("glass occupancy leaves `_glass_layers`") is ALREADY SATISFIED, no code
  change.** Grepped every non-renderer reader named by the plan text:
  `detonation_plan_builder.gd`/`detonation_entry_writer.gd` only *mention* `_glass_layers`
  in comments or *write* to it (`erase_glass_cell()`, keeping the 2D board's own draw layer
  in sync per the destroy entry — legitimate until R3D-8) — neither reads it as an
  occupancy authority. `occlusion_set.gd`'s O7 exclusion already checks
  `GlassMaterials.is_glass(slice.material)` on the geometry directly, never `_glass_layers`.
  The remaining `_glass_layers` readers (`glass_transparency_selftest.gd`,
  `glass_crack_selftest.gd`, `glass_rim_capture.gd`) inspect the 2D board's own tile
  placement/atom masks — they test the 2D renderer, not simulation/prediction, so they stay
  until R3D-8 retires that renderer. Step 1 already removed the one real occupancy read
  (`build_occupancy()`'s old fallback). No commit for this step — nothing to change.
- **Step 3 CLOSED (commit `bc8e1ca9`) — cell planes moved to `CellPlaneStore`.**
  `_soot_images`/`_soot_textures`/`_soot_dirty` and their read/write API relocated
  verbatim to `godot/scripts/systems/cell_plane_store.gd`, domain-agnostic by
  construction (its owner supplies the clean-fill/max-bucket values, so no reference
  back to `VoxelRenderer` and no circular class dependency). `VoxelRenderer` keeps
  every public method name as a thin forwarder — zero external caller changed.
  `board_probe.py gate` reported the same 3867 voxel / 8063 plane-texel counts as
  Step 1's baseline, confirming the move is behaviour-neutral.
- **Step 4 DEFERRED (Director, 2026-09-17) — the plan-entry rekey buys nothing today.**
  Mapped both sides before touching code:
  - **Every current reader of `source_id`/`atlas_coords`/`alt` is 2D-board-internal.**
    `DetonationEntryWriter.apply()` is confirmed the ONLY place that turns them into
    `_ensure_light_alt()` + `set_cell()`/`erase_cell()` calls; the only other reader is
    `test_zone_controller.gd`'s `_plan_light_alt_triples()`, a read-only diagnostic. No
    simulation, prediction, AI or occupancy code reads these fields — R3D-2's stated goal
    ("no simulation or prediction code reads a tile") was already satisfied by steps 1-3.
  - **The fields exist in the PLAN, not just the writer, for a documented perf reason:**
    `voxel_renderer.gd`'s own comment on `build_occupancy()`'s neighbour, the alternative-
    tile warm-up: *"the measured cost of a shot is 412 `create_alternative_tile()` calls
    landing on the impact frame, and an alternative minted early is one not minted late."*
    Resolving the material/atom during the PLAN build (aim window) and minting/writing
    only at APPLY time is deliberate, validated architecture — not an accident the rekey
    would just be tidying up.
  - **A full rekey would either reintroduce that impact-frame stall or double the resolve
    cost for no present benefit.** Removing `source_id`/`atlas_coords` from the entry
    means `DetonationEntryWriter.apply()` would have to re-run `_resolve_damaged_tile()`'s
    material/atom resolution itself, at apply time — the exact frame the pre-warm exists to
    protect. The alternative (build still resolves+warms, apply re-resolves from the
    voxel key to get a writable id) computes the same resolution twice per cell for zero
    consumer that needs the new shape: no 3D reader exists yet.
  - **Deferred to whenever R3D-3/R3D-4 build the actual 3D consumer** of per-voxel target
    state — that stage will say precisely what shape it needs (voxel key + damage state +
    bucket + soot, or something else), instead of this stage guessing ahead of a reader
    and paying a real performance cost to guess right.
- **R3D-2 CLOSED, 2026-09-17.** Step 1 (store-only occupancy) and step 3 (cell planes to
  `CellPlaneStore`) shipped; step 2 (glass occupancy) was already satisfied by step 1;
  step 4 (plan-entry rekey) is deferred with the reasoning above, same call the Director
  made on R3D-1d's own steps 2-4.
- **R3D-3 CLOSED, 2026-09-18.** All 7 steps built and measured on the Moto — production
  renderer relocated out of `spikes/`, vertical scale ratified (true-cube, `VERTICAL_SCALE
  = 1.0`), chunk size (16), threaded remesh, the web export checked on the real
  Compatibility renderer, the hidden 2D board now skips its own build under `RENDER3D=1`
  (a ~24% cut in load-to-3D-ready time), and the full device gate (idle frame, commit
  frame, both grenades' worst frame, load time, memory, pixel-identity). **Next: R3D-4
  and R3D-5 can run in either order** (§5's own dependency graph).
- **R3D-4 BUILT, 2026-09-18.** The agent and the guards as depth-tested billboards (`ActorBillboard3D`,
  D17's relight ported to a spatial shader; +0.2 ms on the Moto), the guards' vision cones on the
  ground (`VisionCone3D`), the props (`PropBillboard3D`: the grenade with flight and ground shadow, the
  floating collectible with its outline), and every in-world VFX in world space (`ParticleMath`,
  `CircleField3D` / `QuadField3D` / `ShardField3D`): a blast behind a wall no longer paints its face, and
  the Moto detonation is 2.1 ms lighter than the 2D VFX (30.2 ms vs 32.3 ms). R3D-4a's spike chose the
  billboard over a depth-composited sprite (Director ratified). Sections below.
- **R3D-5 BUILT, 2026-09-18.** **5b** the ground overlays on the ground plane through one mechanism
  (`GroundCanvas3D`): the movement outline no longer cuts the agent, and the "dark roof tops" and GU grid
  lines no longer paint across block faces; **5c** the fog of war; **5a** picking by camera ray
  (`PICK_CHECK`: 35 840 points, 0 disagreements) and the cell lattice without a TileMapLayer
  (`GroundGrid`). The per-overlay decision table is in the R3D-5 section.
- **Parked, to investigate after R3D-9:** real 3D objects (GLB meshes) in the scene — see "To
  investigate at the end of R3D".

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

#### R3D-1a — the decision rule, written before any measurement (2026-09-16)

This rule was committed before the spike ran, so its order is in git.

**Candidates:**
- **O — today's `Voxel` objects.** The reference, not a candidate.
- **A — a dense per-level grid over the map's cell bounds.** Per cell: a state byte, an
  aux byte (variant and substrate), a material byte and an `int32` container reference.
- **A-c — A allocated per (level, 32×32-cell chunk), only where a voxel exists.**
  - The spike adds this variant: A's memory grows with the map's VOLUME, not its voxel
    count.
  - `DESIGN_MASTER_PLAN` §14.1's mission map is a 3×3 grid of 18×36 GU segments, 54×108
    GU: 5.3× PLAYGROUND's inner area.
- **B — per-container packed arrays** (state and aux per voxel, material per container
  or band), plus a derived dense grid holding the container reference per cell.
  - Every layout needs cell → voxel: `cell_to_voxel`, point impacts, glass.

**What is measured:**
- **M — memory.** Bytes computed from the sizes of the arrays the spike builds:
  - on PLAYGROUND, GLASS and the largest shipped map (by cell volume);
  - on the §14.1 mission map, as a labelled ESTIMATE at PLAYGROUND's per-GU occupancy.
  - R3D-0 showed that a packed array costs its size on the Moto: 0.82 MB read as +1 MB.
- **T1 — the light field's occupancy reads.** `bucket_for()`'s pattern, once per
  visible voxel over the whole map: `surface_factor()`'s 3 neighbour reads, then
  `_face_occlusion()`'s ring for the chosen face.
- **T2 — the mesher's scan.** Every chunk: 3 neighbour reads and a material read per
  occupied cell, faces collected into a flat array.
  - Merging and mesh upload are the same for every layout, so they are left out.
- **T3 — the prediction WALK's reads.** Every voxel's cell, visible flag, damage state,
  blast flag and material, classified into the WALK's buckets: blast seed, weapon seed,
  damaged, occupied.
  - The Delta projection and the dictionaries the WALK builds today are left out. They
    exist because there is no store.
- **Where the timings count:** in GDScript on the Moto's release APK, over 2 boots, each
  timing the median of 5 repetitions after 1 warm-up. Desktop timings are recorded, and
  decide nothing.
- **C — collisions.** How many cells two containers claim, and whether the two claims
  ever DIVERGE in state. Read from `BoardProbe` dumps at load, after grenades #0 and #1,
  and after a shot, on PLAYGROUND and GLASS.

**The rule:**
1. **Identity first.** On every map, each kernel must reproduce O's answer:
   - T1's per-voxel neighbour-read results;
   - T2's face count (108 772 on PLAYGROUND);
   - T3's bucket counts.

   A layout whose kernel does not reproduce O is fixed or dropped, and never timed.
2. **Memory gate.** A layout must cost ≤ 10 % of O's objects on the same map, on every
   measured map. The §14.1 estimate counts too, against O at the same occupancy.
3. **Speed gate (§7's risk).** On the Moto, a layout is out if any of T1, T2 or T3 is more
   than 10 % slower than O's same kernel.
4. **The score.** Among layouts that pass, the lowest T2 + T3 on PLAYGROUND on the Moto
   wins: the mesher and the walk are the per-event costs a player waits on.
   - If another passing layout is within 10 % of that score, the preference order is A,
     then A-c, then B. It counts the structures that must be kept in sync: A is one
     authority; A-c adds a chunk directory; B adds a derived grid that every write must
     update (principle 1).
5. **Collisions.** Only A and A-c are affected, since B keeps both claims.
   - If the two claims never diverge in any scenario above, the cell is stored once and
     written through either claim. The spike writes that rule down.
   - If they diverge, A and A-c need a written rule for which claim a cell shows, plus a
     `BoardProbe` check that it reproduces today's outcome. Failing that, the choice goes
     to the Director before R3D-1b.
6. **If no layout passes gates 1–3, nothing is picked.** The numbers go to the Director.

#### R3D-1a — measured, and what the rule picks (2026-09-16)

**The spike:** `godot/scripts/spikes/store_layout_spike.gd`, reached through the scenario
step `store_spike <reps>`. Commits `54b98629` and `8c7b2e55`.
- It reads the registries after a real load and builds O's dictionaries, A, Ac and B
  beside the objects.
- It checks every kernel against O, then times each kernel. The layouts are interleaved
  inside every repetition, with a yielded frame between kernels outside the timed window.
- **What the spike measured differently from the rule's text, and why:**
  - **A is one flat array with a level stride**, not one array per level: the same bytes,
    without a per-level fetch in the hot loop.
  - **A and Ac keep a cell's second claim in an overflow table** (6 ints per entry), so
    they can answer per claim, as T3 asks.
  - **B's per-container arrays are one flat array per field**, contiguous per container,
    with an offset table.
  - **Every grid is padded by 2 cells and 2 levels**, so no kernel carries a bounds check.
    The memory below includes the padding.

**Gate 1 — identity: every kernel on every layout equals O.**
- On desktop:
  - PLAYGROUND, after two grenades placed beside box corners, where the two claims of a
    cell diverge: T1 214 718 cells; T2 109 219 faces; T3 736 blast seeds and 467 damaged;
  - GLASS, after its two grenades, including a weapon seed and banded slices;
  - SIGMA_01, TEXTURES and RENDER_ORDER, at load.
- On the Moto: the same PLAYGROUND answers, in both boots.
- ⚠️ **What the checks do not cover:**
  - No scenario put a shot into T3's weapon bucket on PLAYGROUND.
  - At load, T2's 108 772 faces equal `Board3DLive`'s own count. After damage, T2 is
    compared with O's kernel only.

**Gate 2 — memory**, computed from the arrays the spike builds:

| map | cells, unpadded | O objects (925 B) | A | Ac | B (without xyz) |
|---|---|---|---|---|---|
| PLAYGROUND | 1 837 056 | 190.6 MB | 14.62 MB | 7.94 MB | 13.54 (11.07) MB |
| GLASS | 931 840 | 100.8 MB | 7.49 MB | 5.30 MB | 6.99 (5.69) MB |
| **SIGMA_01** (largest shipped, by cell volume) | 2 143 232 | 191.3 MB | 16.99 MB | 6.26 MB | 15.26 (12.78) MB |
| TEXTURES | 1 404 928 | 181.1 MB | 11.19 MB | 6.52 MB | 10.89 (8.54) MB |
| §14.1 mission map, **ESTIMATE** | 11 987 040 padded | ~1 064 MB | ~80.0 MB | ~39.6 MB | ~74.4 (60.6) MB |

- Every layout is under 10 % of O on every map. A comes closest: 16.99 MB against
  SIGMA_01's 19.1 MB.
- **How the estimate was made:** 54×108 GU plus a 1-GU buffer, with PLAYGROUND's densities
  — 195.7 claims per GU, 45.9 % of chunk-levels allocated, and 30 padded levels.
  PLAYGROUND is a test zone full of walls, so the estimate is high where walls are
  sparse.
- Most of B is its derived grid: an occupancy byte and an `int32` owner per cell, 10.4 MB
  on PLAYGROUND. The claims themselves are 0.64 MB.

**Gate 3 and the score — the Moto.**
- Release APK sha256 `908934e5…` (commit `8c7b2e55`), 3D board, `NO_BAKE`, `RNG_SEED=1`.
- Each boot ran after the two corner grenades. Times are medians of 5, in ms, run a / run b.

| | T1 light reads | T2 mesher scan | T3 walk reads | T2 + T3 |
|---|---|---|---|---|
| O (today) | 1 364 / 1 382 | 788 / 803 | 362 / 362 | — |
| A | 481 / 481 | 593 / 605 | **422 / 421 · +16 % — fails gate 3** | — |
| Ac | 1 045 / 1 044 | 641 / 640 | 292 / 292 | 933 / 932 |
| **B** | **481 / 480** | **417 / 415** | **134 / 135** | **551 / 550** |

- Desktop, for the record, decides nothing. In ms: T1 O 261, A 106, Ac 219, B 105; T2 O 138,
  A 129, Ac 137, B 83; T3 O 46, A 92, Ac 63, B 28.
- **A fails gate 3 on T3.** Its walk visits every one of the 2.19 M padded cells to find
  216 104 claims.
- **Ac passes every gate**, but its T2 + T3 is 69 % above B's, far outside the 10 % tie
  band.
- **§7's risk, measured:** packed access in GDScript is not slower than object fields.
  Only A's full-grid scan loses, and it loses to the number of cells it visits, not to
  the reads.

**Collisions (gate 5), measured.** It does not decide the pick, because B keeps both
claims.
- **The census:** 672 cells on PLAYGROUND (40 corner columns) and 160 on GLASS.
  - Every such cell is claimed by two slices of one GU, where two faces meet.
  - Both claims always hold the same material.
  - TEXTURES holds 3 880 extra claims. Whether any of its cells has three is not
    counted.
- **The two claims DIVERGE under a blast.** With grenades at internal GUs (25,2) and
  (37,2), beside the brick, cardboard, plywood and glass boxes:
  - after #0, 16 of the 18 damaged corner cells hold two different states;
  - after #1, 24 of 29.
  - Example: cell (207, 24, 83) is intact and visible in `SLICE_25_3_NE`, and destroyed
    in `SLICE_25_3_SE`.
- ⚠️ R3D-0's grenades never reached a corner, so their "0 divergences" read nothing.
- **What each reader shows at such a cell today:**
  - light occupancy, the WALK and `Board3DLive` treat it as occupied while either claim
    is visible;
  - the 2D renderer erases the cell when one claim is destroyed, and does not re-place the
    other until a repaint does (read from the code, not captured).
  - B reproduces the first group by construction: the derived grid's owner is the first
    visible claim. That is what gate 1 checked.

**What the rule picks: B.** A fails gate 3. Ac and B pass gates 1–3, and B's score is the
lowest by 69 %. ✅ **Confirmed by the Director, 2026-09-16:** *"pode confirmar o B e
seguir com o R3D-1b"*.

**What B carries into R3D-1b, as measured:**
- **Variant and substrate never exceed 2 on any dump** (3 values;
  `IMPACT_DECAL_VARIANTS` = `DAMAGE_SUBSTRATE_VARIANTS` = 3). They share one aux byte as
  two 4-bit fields, because the two counts are independent.
- **Coordinates:** stored as `xyz` in the spike (2.47 MB on PLAYGROUND). Every container
  has regular geometry, so R3D-1b decides whether to compute them instead (−2.47 MB).
- **Every write must update the derived grid.** That is B's cost under principle 1, and
  R3D-1b's `BoardProbe` gate is where it gets checked.
- **The spike's load cost on the Moto:** it collected 216 104 claims in 532–538 ms, and
  built O's dictionaries plus all three layouts in 8.6–8.8 s. B's own share of that time
  was not separated, so R3D-1b has to time it alone.

**The state per voxel**, from `voxel.gd`. The widths of variant and substrate are measured
from the data, not assumed.

| field | values | bits |
|---|---|---|
| `visible` | bool | 1 |
| `dirty` | bool (TIC) | 1 |
| `damage_state` | INTACT, CRACKED, DESTROYED, DENTED | 2 |
| `damage_is_blast` | bool | 1 |
| `damage_carved_side` | NONE, TOP, BOTTOM, LEFT, RIGHT | 3 |
| `damage_variant`, `damage_substrate` | 0–2 each on every R3D-1a dump (3 values today, independent counts) | 4 + 4 (one aux byte) |
| material | index into `MaterialRegistry` | 8 |
| container ref + index | replaces `_parent_container_id` | 32 |
| `face_atlas_rect` | 2D bake only | **not carried** — retires with the atlas |

**R3D-1b — the store in shadow.**
- It is built at load beside the objects, and written through the one seam destruction
  already owns (the sole writer of `Voxel.visible` and the damage setters).
- `BoardProbe` compares the store against the objects on PLAYGROUND and GLASS: both
  grenades, a shot, a pane shatter, F2 reload, `SaveState` restore, and
  `_capture_all_four_views()`.

#### R3D-1b — built and gated (2026-09-16, commit `eaa191e8`)

**`VoxelStore`** (`godot/scripts/systems/voxel_store.gd`), behind `VOXEL_STORE=1`
(DevFlags):
- **The arrays, per claim** in the WALK's container order (slices, slabs, junction
  columns): `state`, `aux` (variant and substrate nibbles), `mat` and `xyz`.
- **The derived grid** over the bounds, padded by 2: `occ` (any claim visible) and `owner`
  (the first visible claim, else the first). A cell with several claims is listed, so a
  write can resolve it again.
- **Finding a claim adds no field to `Voxel`.** The claim comes from the container's box
  geometry (offset + level/y/x arithmetic), and that is VERIFIED for every voxel at
  build.
  - A container that breaks the order gets a lookup table and is counted. PLAYGROUND and
    GLASS have 0 such containers.
- **Writes it cannot place are counted, never dropped silently:** an unknown container, or
  a claim whose cell disagrees. A container-less `WorldDelta` projection is not a claim.
- **The one write seam:** `Voxel.set_damage()` and `set_visible()` mirror into
  `VoxelStore.active` (nothing else writes voxel state; the only other field writes are
  `WorldDelta.project_voxel()`'s container-less copies).
- **When it is built:** `Room._rebuild_voxel_store()` runs right after both
  `build_from_layout()` calls (map load and rotation). Both callers clear
  `VoxelStore.active` first, so a write during a build never lands in the previous
  board's store.
- **Its size:** PLAYGROUND 216 104 claims, 672 multi-claim cells, 13.59 MB, built in
  ~560 ms on desktop.

**The instrument:**
- `BoardProbe.write_store()` writes the objects' dump format from the store, in
  `write()`'s container order, so the existing `board_probe.py diff` compares the two
  directly.
- Scenario steps: `probe_store`, `shoot`, `reload`, `save_restore` and `perspective`.
- `board_probe.py shadow` boots each map once and dumps objects and store together at
  every stage.
- **The `save_restore` step's path, stated because the game has no load flow yet:**
  SaveState is plumbing, so the step takes the path a rotation already runs — capture, a
  fresh `load_map()`, `SaveState.restore()`, then `_reapply_base_damage()`.

**The gate:**

| map | stages, each objects vs store | result |
|---|---|---|
| PLAYGROUND | load · grenade #0 and #1 beside four box corners · a shot · views E, S, W, N · SaveState round trip · F2 reload | **IDENTICAL at all 10**: 216 104 voxels and every plane texel; grid mismatches 0; unknown and misplaced writes 0 (up to 1 222 writes mirrored) |
| GLASS | load · grenades #0 and #1 (pane shatter: shards fell) · views E, S, W, N · SaveState round trip · F2 reload | **IDENTICAL at all 9**: 114 280 voxels; grid mismatches 0; unknown and misplaced writes 0 (up to 5 120 writes mirrored) |

- **The controls, so the identity is not empty:** the objects changed between load and
  grenade #0 (611 and 3 867 voxels), and between grenade #1 and the shot (19).
- **`voxel_store_selftest`**, 5 tests, each checked against `BoardProbe`'s dump of the
  objects: a build with a banded slice, slabs, a column, a shared cell and an out-of-order
  slab; a mirrored write; ownership moving between two claims; a write through the lookup
  table; unplaceable writes counted.
  - With the mirror sabotaged, 4 of 5 fail.
- **Pixels** (desktop, `--fixed-fps 60`, framed on the corner crater 400 frames after both
  grenades): the flag off vs on differs by **0 px**, and a control of off vs off by 0 px.
- Lint 0 errors, 57 selftests clean, invariants OK.

**What the gate did NOT cover:**
- no Moto run — the desktop is the arbiter of correctness (principle 4);
- the store's build time on the Moto;
- a shot on GLASS, which has no guards.

**Found by the controls, and not caused by the store:**
- Rotating PLAYGROUND away and back (shot → E → S → W → N) **loses the damage of 21
  voxels**:
  - 11 in junction columns, e.g. `JCOL_26_2~2` at (215, 23), DESTROYED → INTACT;
  - 10 at box corners, e.g. `SLICE_27_3_NW` at (216, 24).
- The SaveState round trip loses the same 21.
- The store mirrors the loss faithfully.
- Read from the code, not yet confirmed: `_reapply_base_damage()` indexes only slices and
  slabs, and keys by cell, so a corner cell gets one claim's damage back and a column none.
  Rotation is suspended but coming back, and the save path depends on the same function.
- Offered to the Director as a separate task.

**R3D-1c — readers move one subsystem at a time**, each behind a flag and a 0-difference
gate:
1. `VoxelLightField` occupancy;
2. the prediction plan builder;
3. glass (shatter, crack, fall, occupancy);
4. `BlastCalculator`, `PassageQuery`, the occlusion set;
5. `Board3DLive`.

#### R3D-1c step 1 — the light field's occupancy: NOT a 0-difference flip (2026-09-16, commit `07194b55`)

**Built, off by default:** `VoxelStore.occupancy_dict()`, the flag `STORE_OCCUPANCY=1`
(`build_occupancy()` answers from the store), and the scenario step
`occupancy_compare`. That step compares tile and store occupancy per level, then builds
one light field per occupancy and compares every placed cell's bucket.

**Measured, desktop:** today the field reads what the 2D board DREW, not the voxels. The
two differ for three reasons, and each is a draw decision, not a simulation fact.

| class | tiles vs store | light buckets that differ (PLAYGROUND · GLASS) |
|---|---|---|
| 1 · the map buffer's L72–77 columns: tiles with no voxel (8 704 cells per level on PLAYGROUND = exactly the buffer ring) | tile-only | ~8 490 per level · ~5 600 per level |
| 2 · the deep floor, L78: the store holds all 70 656 claims visible; the 2D board draws it only in the buffer and where a crater reveals it (D18) | store-only 61 952 | 248–293 · 112–196 |
| 3 · a corner cell whose two claims diverged: one claim's destroy erased the tile while the other still stands | store-only 1–2 per wall level | 1–5 per wall level after the grenades · 0 |

**On screen** (paired desktop captures, `--fixed-fps 60`):
- the map-edge strata: 16 103 px, max delta 6/255;
- a crater's corner: 130 px, 3/255;
- a wide framing: 33 px.

**The options put to the Director:**
- **(A)** the voxels are the truth: accept these three differences, ratified from captures;
- **(B)** teach the store the drawn set, for 0 px: static claims for the buffer strata, a
  "revealed" bit on the deep floor, and the corner erase;
- **(C)** the buffer strata become real geometry in the store, and classes 2 and 3 are
  accepted.

✅ **Ratified: option A** — *"pode seguir com a opção A"* (Director, 2026-09-16).

#### R3D-1c step 1 — flipped (2026-09-16, commits `c511af14`, `3b7a5655`)

**The flip:** `VOXEL_STORE` and `STORE_OCCUPANCY` default ON. `=0` on either is the old
path, kept for comparison only.

**Desktop, both maps:**
- `board_probe.py gate` PASSES on the new default.
- New vs `STORE_OCCUPANCY=0`:
  - the voxels are identical at load, g0 and g1;
  - only light(G) differs;
  - at load, exactly the measured classes: PLAYGROUND 49 648 (L72–77 and L78), GLASS
    33 254;
  - after the grenades, plus the revealed deep floor (L78) and 2–6 cells at L79.
- `board_probe.py shadow` PASSES, and all 57 selftests are clean.

**Two regressions found and fixed before the flip closed:**
1. **The cook's LIGHT step.** `occupancy_dict()` first cost 45 → 82 ms on desktop. It is
   now 38–40 ms, against the tile read's 44–46: predicted cells are erased after the pass,
   and a level's set is found by index. The output is IDENTICAL to the first version at
   every gate stage.
2. **The store build at load.** It took 3.26 s on the Moto. It is now 555 → 192 ms on
   desktop and 1.25–1.27 s on the Moto: one box pass, a material once per container,
   inlined packing, and the grid filled in the same pass.

**The Moto, same APK per pair, 3D board, `NO_BAKE`:**

| | old path (`=0`) | new default |
|---|---|---|
| idle frame | 23.1 · 23.3 ms | 23.1 · 23.1 ms |
| grenade #0 · #1, wall clock | 19.6 · 16.3 s (both boots) | 19.6 · 16.3–16.4 s |
| the cook's LIGHT step | 242 · 235 / 237 · 232 ms | 236 · 229 / 230 · 227 ms |
| boot → map loaded (after the build fix) | 22.8 · 23.0 s | 23.8 · 23.9 s (**+0.9–1.0 s**) |
| native heap at idle | 749 · 749 MB | 764 · 767 MB (**+15–18 MB**) |

- The load and memory costs are the store existing BESIDE the objects. They are paid back
  at R3D-1d, when the objects (~191 MB on the Moto) go.
- Logs (local): `docs/measurements/device_2026-09-16_moto_g04s_r3d1c_*.log`. APKs:
  `a97b1213…` (grenade A/B), `241b53de…` (the load re-measure).

#### R3D-1c step 2 — the prediction WALK reads the store (2026-09-16, commit `3b298025`)

**What moved:**
- `DetonationPlanBuilder._phase_walk_store()` reads state, visible, blast and cell from
  the store. The Delta's projection is re-keyed by claim once
  (`WorldDelta.projections()`).
- **The WALK's `occupancy` is no longer built.** Its only reader since D-7 was
  `_commit_burn_to_delta()`, erasing burnt cells from a dictionary nothing read
  afterwards.
- `STORE_WALK` defaults on; `=0` is the object walk. The object walk also runs, with one
  warning, when the active store does not hold exactly the plan's containers.
- **Still objects:** `cell_to_voxel` and `damaged_voxels`, which later phases hand to
  `BlastCalculator` (shared with the room's repaint). They move with the soot derivation
  (step 4) and the Delta's keys (R3D-2).

**Identity (desktop), `STORE_WALK` on vs off:**
- `board_probe.py gate` passes both ways.
- PLAYGROUND and GLASS are IDENTICAL at load, g0 and g1 (voxels and plane texels).
- PLAYGROUND with corner grenades and a shot: IDENTICAL at g0, g1 and the shot.
- The cook's printed counts match: commit cells and effects by kind.

**Cost:**

| | objects (`=0`) | store |
|---|---|---|
| WALK, desktop PLAYGROUND · GLASS | 256/248 · 138/125 ms | 157/152 · 90/78 ms |
| WALK, Moto (APK `f1344d64…`, 2 boots per side) | 1 651–1 662 ms | **941–956 ms (−43 %)** |
| the cook's total, #0 · #1, Moto | 10.2–10.3 · 7.7 s | 9.5 · 7.0 s |
| grenade wall clock, #0 · #1, Moto | 19.7 · 16.3 s | **18.2 · 15.0–15.1 s** |
| commit frame, #0 · #1, Moto | 245–258 · 279–280 ms | 176–198 · 196–208 ms |
| idle frame, Moto | 22.9–23.3 ms | 22.9–23.1 ms |

⚠️ **Found for R3D-2:** the cook's PACKAGE phase costs **~7.9 s** per grenade on the Moto
(worst visit 2.07 s), even on the 3D board. It resolves 2D atlas tiles for every entry.
That is R3D-2's "tile-shaped plan entries", and it is now the cook's largest cost on the
device.

#### R3D-1c step 3 — glass reads the store (2026-09-16, commit `386d122b`)

**The seam:** `VoxelStore.cells_of(container)` returns x, y, level and state per voxel.
`damage_of(v)` and `visible_of(v)` answer for one voxel.
- They read the store when it holds the container, and the objects otherwise (selftest
  fixtures).
- `STORE_GLASS` defaults on; `=0` reads the objects.

**What moved:** every glass state read.
- `GlassShatter`: the craze and anchors, the shatter lattice, and the frame and glass
  keys.
- `GlassCrack`: the field, the crack plan, and the checks in `apply`.
- `GlassFall`'s surface index.
- The room's crack count, its remnant reaper and its crack respawn.
- The shot controller's pane checks, and the plan builder's shatter origin and entries.
- The renderer's glass seam index.

**What did not move:**
- Writes still go through the objects, which mirror into the store.
- Reads that only re-read a voxel just written, to record `_base_damage`, stay with the
  write seam until R3D-1d.

**Identity, `STORE_GLASS` on vs off (desktop):**
- PLAYGROUND with corner grenades (one beside the glass box), two shots through
  `PANE_SLICE_26_9_SE` (crack, shatter, G-D24 crossings), and a rotation E and back: every
  probe IDENTICAL, and the 31 `[GLASS-*]` log lines identical.
- GLASS with both grenades and the rotation: IDENTICAL, and the 105 lines identical.

⚠️ **The probe alone is not this step's gate.** With the store's visible bit sabotaged
inside `cells_of()`:
- the pane did not shatter, and the crossings went 19 → 52;
- that is the SAME final voxel set (33 + 19), so `BoardProbe` read IDENTICAL, and only the
  log digest changed;
- so the gate is both checks, and the sabotage proves the store path is live.

**No Moto run:** these are per-pane reads on a shot or blast, not per-frame or map-wide
work.

#### R3D-1c step 4 — blast, passage and occlusion (2026-09-16, commit `c4c6c6e2`)

**Moved:**
- `PassageQuery` reads level and damage through `VoxelStore.cells_of()`.
- `BlastCalculator.plan_point_impact()`'s destroyed check reads through `damage_of()`.
- `STORE_BLAST` defaults on; `=0` reads the objects.

**Moved, measured, and put back on the objects:** `derive_soot_rings()` and
`apply_self_soot()`.
- A claim lookup per BFS neighbour cost the SOOT phase **+11–16 %** on desktop
  (34.2 → 39.5 and 68.7 → 79.6 ms).
- It removed no dependency: `cell_to_voxel` is a map of objects.
- They move with that map, keyed by claim (R3D-2 / R3D-1d).

**Nothing to move:** `OcclusionSet` reads edges and tiles, never voxel state.

**New instrument:** the scenario step `passages <label>` gives every edge's passage class,
counted and digested. `BoardProbe` cannot see a passage.

**Identity (desktop), `STORE_BLAST` on vs off:**
- PLAYGROUND with corner grenades, two shots through a pane, and a rotation E and back:
  every probe IDENTICAL.
  - The glass, shot and consequence log lines are identical, apart from frame counts.
  - The passages are identical: an edge opens to CROUCH at g1, and another with the shots.
- GLASS with both grenades: probes and passages identical (STANDING 5 → 7, CROUCH
  1 → 8).
- **Live-path control:** with the store's damage bits sabotaged in `cells_of()`, every
  edge reads NONE.

**Cost:**
- SOOT and SLICES are unchanged (28.7/57.8 vs 28.2/58.0 ms).
- SETUP is +2.3 ms on PLAYGROUND's first grenade only.

#### R3D-1c step 5 — `Board3DLive` meshes straight from the store (2026-09-16, commit `8f47fc6a`)

**What moved:**
- **The load index:** the store's claims grouped by WORLD chunk with one counting sort
  into packed arrays. There is no `Vector3i` dictionary.
- **The chunk faces:** each cell is drawn by its owner claim, with neighbours read from
  `occ` and the glass rule applied through the owner's material.
- **The blast commit:** nothing is folded, only the chunks to rebuild are marked.
- `STORE_BOARD3D` is read at `build()` through the Room's DevFlags: default on, `=0` for
  the objects.

**Identity (desktop, `--fixed-fps 60`):**
- PLAYGROUND: faces, quads and chunks identical, and the default grenades' remesh
  identical. Captures differ by 0 px at load, after both grenades, and on the crater.
- GLASS: identical, and 0 px.
- **The ratified difference (option A),** seen only with corner grenades. The object path
  erased a corner cell whose other claim stood — a one-voxel "hole" column at the glass
  box. The store keeps it solid: 1 364 px, max delta 16, and quads 363/474 → 360/467.

**The Moto, APK `329c69d8…`, 2 boots per side:**

| | objects (`=0`) | store |
|---|---|---|
| 3D board collect at load | 2 397 / 2 285 ms | **953 / 966 ms** |
| 3D board mesh at load | 1 349 / 1 319 ms | 1 069 / 1 060 ms |
| boot → map loaded | 24.4 / 24.5 s | **22.8 / 22.8 s** |
| commit remesh | 122–126 ms | 100–101 ms |
| grenades · idle frame | 18.4·15.1 s / 18.1·15.0 s · 23.1 ms | 18.3·15.0 s / 18.0·15.0 s · 22.9–23.3 ms |

- The load is 1.6 s shorter. It now sits under even the pre-store baseline (22.8–23.0 s,
  step 1), so the store's +1 s build is paid back.

#### R3D-1c — CLOSED (2026-09-16)

All five readers now read the store by default, each behind its own `=0`, each gated
against the objects.

| step | reader | result |
|---|---|---|
| 1 | the light field's occupancy | ratified look change (option A); Moto: play equal, LIGHT −3 % |
| 2 | the prediction WALK | identical plans; Moto WALK −43 %, each grenade −1.3–1.5 s |
| 3 | glass | identical (probe and glass log); proven live by sabotage |
| 4 | `PassageQuery`, the point impact | identical (probe, log, passages); the soot BFS stays on objects (+11–16 % through the store) |
| 5 | `Board3DLive` | identical except the ratified corner cells; Moto load −1.6 s |

**Still on the objects, and why:**
- the soot BFS and self-soot, whose input map is objects;
- the plan's entries and the `WorldDelta`, which are keyed by `Voxel`;
- every write — `set_damage` on the object, mirrored into the store;
- the reads that re-read a just-written voxel for `_base_damage`.

R3D-1d has to move these, or R3D-2 absorbs the plan/Delta keys. The rotation/SaveState
damage loss found at R3D-1b is still open, as a separate task.

**R3D-1d — the objects go.**
- `Slice`, `Slab` and `JunctionColumn` answer per-voxel questions from the store; the
  `Voxel` class becomes an index or a transient view, or is deleted, as R3D-1a decides.
- Memory is re-measured on the Moto against §1.

**Step 1 DONE (2026-09-17, commit `75b97af6`).** `VoxelStore.set_damage()`/
`set_visible()` write the packed arrays directly (range-validated, never a silent wrap
into the packing) — THE write seam. `Voxel` is now `claim:int` + a `VoxelStore`
reference; its public surface (`grid_pos`, `visible`, `damage_state`, ...,
`set_damage()`, `set_visible()`) is unchanged, so every caller (`room.gd`,
`agent_shot_controller.gd`, `blast_calculator.gd`, `glass_crack.gd`, `Slice`/`Slab`/
`JunctionColumn`) needed no change. The Director's call: a thin wrapper, not deletion —
see the open question this closed, below. A detached `WorldDelta` projection (no
container, no claim) reads/writes a lazy `_LocalState` side object instead, so the
~216 000 real voxels pay nothing for it. 10 of the ~20 selftests named above turned out
to be 16 once counted precisely (`Voxel.new(` grep undercounted fixtures built through
real generators); every one moved in this same step, never batched — each now builds a
`VoxelStore` over its own fixture before calling `set_damage()`/`set_visible()`, since a
`Voxel` with no store/claim has nothing to write into and refuses loudly (matching the
project's loud-fail contract) rather than silently no-opping.

**Steps 2-4 (the soot BFS's input map, the plan/`WorldDelta` keys) DEFERRED to R3D-2**
(Director, 2026-09-17). Once `Voxel` is thin, its properties already dispatch through
`VoxelStore` by claim — reading `voxel.damage_state` off a `Voxel` held in
`cell_to_voxel`/`damaged_voxels` already *is* a claim-keyed read, wearing a clean
accessor instead of hand-unpacked bits. Migrating those dicts' VALUES to a bare
`claim:int` would only move that unpacking into every call site, for memory that was
never there (tens of entries per shot/detonation, not 215 432). It would also have to
solve a real problem for no gain right now:
`detonation_plan_builder.gd`'s `damaged_voxels` can legitimately hold claim==-1
detached projections (`WorldDelta.project_voxel()`, W-PRECOOK-02's precook path) that
have no claim to read a bare int from at all, and `BlastCalculator`'s
`derive_soot_rings()`/`apply_self_soot()` are explicitly ONE shared implementation
("so a repaint and a detonation cannot disagree") — forking their input shape per
caller is exactly the drift risk that file's own header warns against. R3D-2 re-keys
the plan and `WorldDelta` around a render-neutral store read anyway, so this rides
along with that redesign instead of paying for it twice.

**Step 5 — the Moto remeasure — MEASURED (2026-09-17), device connected mid-session.**
See the status block above for the full table. 215 432 thin `Voxel` wrappers cost
87–140 MB (median ~100 MB) against R3D-0's ~190 MB for the old object — roughly half,
across 3 single boots (not R3D-0's 16 interleaved). One PLAYGROUND grenade detonation
showed no hot-loop regression signal against R3D-1c step 5's numbers. **R3D-1d is
closed** at this point — steps 2-4 stay deferred to R3D-2 (see the status block).

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
  - chunk size (16 vs 32 voxels) is chosen by measurement — **MEASURED (Moto g04s,
    2026-09-17): 16 wins.** Initial load is a wash either way (collect/mesh ~1013-1056 ms,
    dominated by the store walk, not chunk count), but a blast's remesh — the part that
    stalls the main thread on the impact frame until step 4 threads it — dropped from
    108.4/104.4 ms (32) to 38.9/0.2 ms (16) across both PLAYGROUND grenades: a smaller
    chunk means less unaffected geometry gets re-merged alongside the cells a blast
    actually touched. `CHUNK_VOXELS` default is now 16;
  - the remesh builds from a store snapshot on a `WorkerThreadPool` task and swaps in on
    the main thread — **BUILT (2026-09-17).** `_collect_and_merge_chunk()` (pure data:
    `SurfaceData` is a plain GDScript class of `Packed*Array`s, not a `Resource`, so
    building it off-thread is safe) runs in the task; `_commit_chunk_mesh()`
    (`ArrayMesh`/`MeshInstance3D`, scene-tree touch) stays on the main thread, polled from
    `_process()`. Only one task is ever in flight — a request that arrives mid-task
    coalesces into a queue instead of starting a second concurrent reader of `_store`.
    Measured on the Moto: the background work itself is genuinely cheap (30.6 ms then
    0.5 ms across both PLAYGROUND grenades) — the real win, since the old synchronous path
    measured 108.4/104.4 ms (chunk 32) and 38.9/0.2 ms (chunk 16) added IN-LINE to
    whichever frame ran it. ⚠️ **First pass conflated background compute time with poll
    latency** (an 1100 ms "merge" that was actually the main thread not polling
    `_process()` until a slow unrelated frame — this scene's own smoke/ember consequence
    effects run 100–500 ms/frame independent of board3d) — fixed by timing merge inside
    the task itself and reporting `poll-latency`/`background` separately in the
    `[BOARD3D] remesh` line. The remaining poll latency (up to ~1 s in the worst sample)
    is real but is the SAME pre-existing per-frame cost the synchronous path also ran
    inside — threading does not fix that scene's own smoke/ember cost, it only stops
    board3d's own remesh from adding to it inline;
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
  - **RATIFIED (Director, 2026-09-17): the true-cube variant, `VERTICAL_SCALE = 1.0`.**
    Paired captures (`Screenshots/history/render3d_vscale_cube_A.png` /
    `..._matched_B.png`, a fixed 1-storey magenta marker standing in for the baked agent,
    which isn't wired into the 3D scene yet) showed the two ~0.8% apart and visually
    close. The Director's call: *"Me parece que as duas versões estão baixas, se
    considerarmos o chapéu. Mas vamos trabalhar de novo no modelo então acho que tanto
    faz. Usa o valor mais inteiro, que facilita o cálculo."* — both read a little short
    once you account for the hat, the character model is getting reworked anyway, so the
    round number wins. `VERTICAL_SCALE` stays `1.0` (the code's existing default);
    `VERTICAL_SCALE_MATCHED` (158/156.8) stays defined in `board3d_live.gd` for a future
    A/B if the reworked model needs it, but is not the active value.
- **The hidden 2D board stops being built** when the 3D board is on (a flag for the A/B,
  removed at R3D-8). **NOT STARTED.**
- **The web export is checked NOW, not at R3D-8.** The Compatibility renderer must boot
  the 3D board: `Texture2DArray`, the custom spatial shaders, `MultiMesh`. **✅ CHECKED
  (2026-09-17).**

**Progress (2026-09-17):** steps 1 (relocate), 2 (vertical scale, ratified 1.0) and 3
(chunk size, 16) closed — commits `9ed0f809`, `642a2d9f`, `a54b804a`. Step 4 (`WorkerThreadPool`
remesh) closed — commit `73fa10dc`; background collect+merge measured at 30.6/0.5 ms on the
Moto (both PLAYGROUND grenades) against the old synchronous path's 108.4/104.4 ms (chunk 32)
or 38.9/0.2 ms (chunk 16) added in-line to whichever frame ran it.

**Step 6 CHECKED (2026-09-17).** Re-exported `export/web` (`--export-release "Web"`,
no code changes at export time), served it locally and booted it in a real browser
(Chromium via the Claude Code browser pane). No `MultiMesh` yet at this stage (that's
R3D-4 scope), so the check covers `Texture2DArray` and the custom spatial shader only.
Console (the pasted literal, not a description):

```
[BOARD3D] 114120 voxel(s) (slices 41920, columns 160, slabs 72200; the 2D board holds
77928 cell(s)) → 61454 face(s) → 232 quad(s) in 35 chunk(s), 9 material(s), plane levels
78..103; collect 108 ms, mesh 142 ms; skip 2D writes false; source store
```

No shader-compile or WebGL errors in the console. `MobileTesting.md` already documents that
the web export always runs the Compatibility (WebGL2) renderer regardless of
`renderer/rendering_method` in `project.godot` (currently `"mobile"`) — so this is the
renderer R3D-6/R3D-8's web gate will always exercise, confirmed rather than assumed.

⚠️ **Side finding, not fixed here (out of step 6's scope):** `DevFlags`
(`godot/scripts/systems/dev_flags.gd`) resolves `OS.get_environment()` → the Android
overrides file → the caller's default — and neither of the first two exists on the Web
platform (no env, no filesystem at that path), so **no `INFILTRAITOR_*` flag, including
`RENDER3D`, can be toggled on a web build today.** This check only ran with `RENDER3D`
forced on by temporarily editing `room.gd`'s call-site fallback to `"1"`, exporting,
testing, then reverting the source and re-exporting the real build (`git diff` on
`room.gd` came back clean before the final export). A third resolution branch reading
the URL query string (mirroring the Android overrides-file precedent) would fix this
generally; flagged for whoever next needs to toggle a flag on web, not scheduled here.

Steps 5 (skip the hidden 2D build) and 7 (the full Moto gate above) remain. Step 5 needs
its own session: research found the load-time placement path
(`VoxelRenderer._process_dirty_slice_voxel()` / `_set_voxel_cell()`, not the existing
`SKIP_2D_BOARD_WRITES` instrument, which only gates per-cell light writes and the plane
flush) is what actually builds the hidden 2D geometry, and two real readers would break
silently if it stopped: the whole glass subsystem (`_glass_layers` reads — cracks,
shatter, remnants, rim) and `columns_with_structure()` (VL-D3 sun exposure).

**Step 5 planning session (2026-09-17) — a second, deeper pass superseded the "both are
R3D-5 scope" call above.** Read `_set_voxel_cell()`, `apply_damage_voxel_swap()`,
`columns_with_structure()`, `VoxelStore.occupancy_dict()`/`cell_index()`, and every
render-time glass function (`_glass_cell_present`, `_glass_face_mask`,
`_glass_side_covered`, `erase_glass_cell`, the crack/rim/remnant family), file by file,
to find exactly which reader needs what. The scope is smaller than first assessed:

- **`columns_with_structure()` is NOT a blocker — it's a five-minute fix, ready now.** It
  currently scans `get_used_cells()` per opaque `TileMapLayer`
  (`voxel_renderer.gd:3751`) for VL-D3 sun exposure. `VoxelStore.occupancy_dict()`
  (`voxel_store.gd:410`) already returns the exact same shape — `level -> {Vector2i:
  true}` — built from the store's own claims, no tile involved. Swap the body to flatten
  `VoxelStore.active.occupancy_dict()`'s levels into one dict and this reader stops caring
  whether a single tile was ever placed. **Land this on its own, ahead of the rest** — it
  de-risks everything else and needs no A/B flag.
- **Glass PLACEMENT never read the opaque layer — checked, not assumed.** `_glass_face_mask()`
  → `_glass_side_covered()` reads `_glass_seam_index` (its own dict, built as glass voxels
  place) to decide which side faces are exposed, never `_layers`. So the glass branch inside
  `_set_voxel_cell()` (the `GlassMaterials.is_glass(material_name) and not flat_baked` block
  that writes `_glass_layers[level]`) can keep running **completely unchanged** — it has zero
  dependency on the opaque branch executing first, in the same function or otherwise.
- **The real blocker is narrower than "the whole glass subsystem": it's specifically the
  render-time "is glass still here" query, `_glass_cell_present()` /
  `glass_cell_present()`** (`voxel_renderer.gd:6258`, `:7319`) — its own docstring calls
  `_glass_layers` "the live authority". Everything downstream of it (`erase_glass_cell`,
  `refresh_glass_rims`, `refresh_glass_crack_occupancy`, `restamp_glass_shards`,
  `spawn_glass_crack`/`spawn_glass_craze`, `apply_glass_remnant_at`/`apply_glass_opening_at`)
  asks this question or writes the same sublayer directly — none of it touches the OPAQUE
  layer this step wants to stop building. **So skipping the opaque placement does not
  require migrating glass at all** — glass keeps its own tilemap regardless of what this
  step does, because R3D-6 (glass look parity in 3D) hasn't given the 3D board real glass
  rendering yet anyway. The R3D-2 note that "glass occupancy leaves `_glass_layers`,
  satisfied by step 1" was about the PREDICTION/plan-builder's read of glass state
  (`STORE_GLASS`, already store-backed) — a different consumer from this render-time query,
  which the plan text conflated. Migrating `_glass_cell_present()` itself to
  `VoxelStore.active.occ[cell_index(...)]` looks mechanically straightforward (the store
  already tracks visibility per (x,y,level) for every voxel, glass included) but is
  genuinely **R3D-5/R3D-6 scope** (it needs an A/B selftest proving 0 differences against
  the tile read, including the ~160 multi-claim cells on PLAYGROUND where `owner[cell]`
  picks one claim and a caller asking about a *specific* glass voxel could get the wrong
  answer) — **not required for step 5, so left alone.**
- **`apply_damage_voxel_swap()` is a pure opaque-layer `set_cell()`** (`voxel_renderer.gd:7741`)
  — no glass path, no side bookkeeping beyond the layer write. Skippable outright under the
  same guard as the main opaque branch.
- **The bookkeeping calls riding along the opaque erase/set
  (`note_external_write`, `forget_ghost_record`, `note_opaque_erased`) are all 2D-only
  housekeeping** — ghost records exist for the (currently suspended, `[[rotation-suspended-for-perf]]`)
  2D rotation restore; `note_opaque_erased` only feeds the glass-crack-clip overlay, a
  render-order trick with no 3D counterpart. Skippable along with the branch they sit in.

**Revised step 5 plan for the dedicated session:**
1. Land `columns_with_structure()` → `VoxelStore.occupancy_dict()` first, alone, verified by
   a same-map A/B (`INFILTRAITOR_STORE_WALK`-style: old vs new body, 0 differences on
   PLAYGROUND) — this is safe to ship even before the rest starts.
2. Add a guard at the top of the opaque branch in `_process_dirty_slice_voxel()` and
   `_process_dirty_slab_voxel()` (before the `apply_damage_voxel_swap()` call, and before
   the `_set_voxel_cell()` fallback) that returns early when `RENDER3D=1` and a new A/B
   override flag (name TBD, mirroring `SKIP_2D_BOARD_WRITES`'s "instrument only meaningful
   with RENDER3D=1" convention) is NOT forcing the old path. The glass branch inside
   `_set_voxel_cell()` is unaffected either way — this guard sits before it in the caller,
   not inside the shared function, so a glass voxel still reaches `_set_voxel_cell()`
   normally.
3. Confirm `voxel_destroyed` still emits on the skipped path where VFX depends on it
   (`_process_dirty_slice_voxel()`'s erase branch) — the signal, not the tile write, is
   what downstream listeners need; keep the emit, drop only the tile calls around it.
4. Verify the 21 selftests that read `get_layer()`/tile cells (`tools/persistent/`) build
   their own isolated `VoxelRenderer` + `process_dirty()` fixtures rather than going through
   `Room` with `RENDER3D=1` — spot-checked several during this session (`slab_render_selftest.gd`,
   `roof_integration_selftest.gd`) and found no `RENDER3D` reference in any of them, so they
   should be unaffected by a flag-gated change; **confirm this for all 21 in the dedicated
   session rather than assuming it holds project-wide**, since a selftest calling
   `process_dirty()` directly never routes through this guard regardless (the guard lives in
   `Room`'s dev-flag read, not in `VoxelRenderer` itself, unless the flag is read as a static
   the way `SKIP_BOARD_WRITES` is — the exact wiring point is an implementation decision for
   that session, not fixed here).
5. Gate: an A/B Moto run (`RENDER3D=1` skip-on vs skip-off) measuring the load-time gap
   this session's step 7 data already flagged (~15 s between `VOXEL-STORE built` and
   `BOARD3D` ready, consistent with the hidden 2D build still running in between) — expect
   it to shrink substantially; `BoardProbe` diffed 0 against the skip-off run (the 3D mesh
   reads the store either way, so skipping the 2D placement must not change it); glass
   mechanics (crack, shatter, a bullet through a pane) exercised live and unaffected.

**Left alone, explicitly out of step 5's scope:** migrating `_glass_cell_present()` and the
rest of the render-time glass query surface off `_glass_layers` (R3D-5/R3D-6 — glass still
needs its own 3D look and a store-backed per-cell state richer than a visibility bit before
that migration is worth doing).

**Step 5 BUILT and CLOSED (2026-09-18).** Implemented the plan above, in order:

1. **`columns_with_structure()`** now reads `VoxelStore.active.occupancy_dict()`, filtered
   to `level >= _ground_plane_level` (the same threshold `wall_level_keys()` uses) instead
   of scanning `get_used_cells()`.
2. **`VoxelRenderer.SKIP_BOARD_WRITES`** auto-engages whenever `RENDER3D=1` (unless
   `RENDER3D_2D_BUILD=1` forces the old build back on, for the A/B) — wired in
   `dev_flags.gd`, replacing the old "set both by hand" contract.
3. **Every opaque-placement call site now guards on `SKIP_BOARD_WRITES`**, glass routed
   around it exactly as scoped: `_process_dirty_slice_voxel()`, `_process_dirty_slab_voxel()`
   (the dirty-reprocess path) and — found only by actually profiling the load, not assumed —
   `_render_slice()`, `render_slab()`, `render_slab_solid()`, `render_fixed_earth_level()`,
   `render_block()`, `_render_junction_column()` (the INITIAL BUILD path, a completely
   separate set of functions `process_dirty()` never touches). **`voxel_destroyed`
   idempotence** (previously read off the tile's `get_cell_source_id()`) has a tile-free
   equivalent, `_render3d_gone_cells` (Vector3i → bool, cleared by `clear()`), so a
   stale-dirty-flag double-emit stays impossible under `RENDER3D` too — the exact class the
   2026-08-19 bug fixed on the tile side.
4. **`apply_light_field()`'s full/initial pass** got a store-backed counterpart,
   `_apply_light_field_pass_store()` — without it, Board3DLive's first load would have read
   empty cell planes, since the existing `apply_light_field_cells()`'s `SKIP_BOARD_WRITES`
   branch only ever ran off an incremental stale set, never the full pass this step also
   needed. Same soot/bucket writes, sourced from `occupancy_dict()` instead of
   `layer.get_used_cells()`.

**A real bug, found and fixed before closing.** The first version of steps 2–3 moved each
guard's early-return *before* that function's `_ensure_layer()`/`_ensure_voxel_layers()`
call, on the reasoning that skipping the write meant nothing needed the layer *node*.
Wrong: `DetonationPlanBuilder._resolve_damaged_tile()` (the render-neutral plan's own
resolve-only seam — R3D-2's step 4, "plan-entry rekey," was explicitly *deferred*, so
`source_id`/`atlas_coords` are still load-bearing there) calls `_set_voxel_cell()` directly,
bypassing every guarded wrapper, and needs the layer node to exist even though it never
writes to it. Reproduced **deterministically** on the Moto — `RENDER3D=1` + two grenades on
PLAYGROUND produced `WARNING: ObjectDB instances leaked at exit` and `ERROR: 3 resources
still in use at exit` on both of two separate runs — and root-caused on desktop with
`--verbose` in minutes once moved there: `VoxelRenderer._set_voxel_cell: level 79 has no
layer` followed by `SCRIPT ERROR: Invalid access to property or key 'source_id' on a base
object of type 'Dictionary'` at `detonation_plan_builder.gd:2178`, aborting a cook phase
mid-execution and leaving state (and resources) partially built — the "3 resources"'s
plausible cause, though this session did not trace the exact objects. **Fix:** every
`_ensure_layer()`/`_ensure_voxel_layers()` call now runs unconditionally, first, in all six
guarded functions; only the per-voxel cell write is skippable. Re-verified after the fix:
0 `SCRIPT ERROR`/leak lines on desktop `--verbose`, 0 on the Moto across two repeat runs,
57/57 selftests clean, invariants clean.

**Moto evidence (`ZF524T5TG5`, PLAYGROUND, `NO_BAKE=1`):**
- **The 2D board shrinks from 151 240 cells to 64** (`[BOARD3D]` log line's own count) — the
  64 is glass-adjacent residue, not a miss (glass keeps building by design).
- **The mesh is byte-for-byte the same work either way**: 108 772 faces → 367 quads in 72
  chunks, both with and without the skip — `BoardProbe` diffs 0 real differences (the only
  diff is 6 cosmetically-present-but-empty plane levels, 72–77, the D13 fixed-bedrock
  levels neither the old nor the new Board3DLive mesh ever reads — confirmed by both runs'
  `[BOARD3D]` line reporting the identical `plane levels 78..103`).
- **The real win is in the segment before `VOXEL-STORE built`, not after it** — this
  session's step 7 write-up guessed wrong about where the ~15 s gap was. Measured: `DevFlags`
  read → `VOXEL-STORE built` drops from **~11.0 s to ~4.4 s** (skip on vs the `RENDER3D_2D_BUILD=1`
  control, same binary) — that segment is `_room_builder.build_from_layout()`, which runs
  the INITIAL BUILD functions this step guards, *before* the voxel store even exists. The
  segment *after* `VOXEL-STORE built` (~15 s either way) is the full light/soot apply pass —
  real cost, but not this step's target; a future perf pass, not R3D-3 step 5.
- **Total DevFlags-to-3D-ready time: ~19.8 s (skip) vs ~26.1 s (forced old)** — a real
  ~6.3 s / ~24% cut for this map, from eliminating exactly the work step 5 named.
- Two grenades detonated live, glass mechanics exercised, both clean (0 script errors, 0
  leaked-resource warnings) after the fix.

Logs (local, gitignored): `docs/measurements/device_2026-09-18_moto_g04s_r3d3_step5_*.log`.

R3D-3 is now fully closed: steps 1–7 all built, measured and verified.

**Step 7 — Moto gate, PARTIAL (2026-09-17).** Ran on the physical Moto g04s (serial
`ZF524T5TG5`), package `com.example.infiltraitor`, `MAP=PLAYGROUND` (which now seeds
4 dev grenades, not 2 — `scenario_runner.gd`'s own log line: *"seeded 4 dev grenade(s) —
PLAYGROUND no longer ships them"*), `SCENARIO=wait 3; mark boot; detonate 0; wait 3;
mark g1; detonate 1; wait 3; mark g2; quit`, `device_run.py --mem-poll 5`, both with and
without `NO_BAKE=1`. Logs (local, gitignored):
`docs/measurements/device_2026-09-17_moto_g04s_r3d3_step7*.log`.

- **Commit frame ✅ within budget.** `NO_BAKE=1`, `RENDER3D=1`: grenade 1 COMMIT
  181 ms, grenade 2 COMMIT 219 ms — both under the 262–279 ms reference. The
  `BOARD3D` remesh commit itself: grenade 1 background 133.6 ms (poll-latency 494.2 ms),
  grenade 2 background 116.5 ms (poll-latency 479.6 ms) — the same "background is cheap,
  poll can land on an expensive unrelated frame" pattern step 4 already documented, not a
  new cost.
- **⚠️ Both grenades' WORST frame is enormous — 2934.9 ms (grenade 1) and 944.8 ms
  (grenade 2), both in the PUMP phase** (`TestZoneController._pump_prediction()`'s
  pre-production loop, which runs BEFORE the board ever touches a voxel). **Isolated with
  a same-scenario 2D control run (`RENDER3D` unset, `NO_BAKE=1`): WORST 3548.1 ms, also in
  PUMP, on grenade 1** — so this is a **pre-existing cost shared by both renderers, not a
  3D regression.** `PREDICTION_MASTER_PLAN`'s own `P-COOK` log line names it directly:
  *"pre-production was short by 1218 ms"* — the pump loop's per-frame budget (14 ms) ran
  out before the scenario's `wait` gave it enough real frames, so the cook finishes the
  rest synchronously in one big catch-up frame. Real, but out of R3D-3's scope — flagged
  for whoever owns `PREDICTION_MASTER_PLAN`'s pump/cook budget, not fixed here.
- **Load time.** `VOXEL-STORE built` (voxel data ready): ~10.7 s after `DevFlags` read on
  both 2D and 3D. **3D's own mesh isn't ready until ~15 s later** (`BOARD3D` log line),
  which is consistent with the hidden 2D board (`skip 2D writes false` in the log — step 5
  not done yet) still being built underneath in that gap — corroborating evidence, not
  proof, that step 5's win is real and roughly this size.
- **Memory.** `NO_BAKE=1` + `RENDER3D=1`: TOTAL PSS 321 → 1230 → 1403 MB across the run
  (median 1230). The 2D control (`NO_BAKE=1`, no `RENDER3D`): 328 → 1171 → 1225 MB (median
  1171). Close, not identical — a real per-material-count comparison needs the same
  ablation table DIAG-23 built, not this scenario, which was tuned for frame timing.
- **Idle frame ✅ found and matches, exactly.** The instrument is `FRAME_PROBE=1`
  (`room.gd`'s `_process()`, §PERF — a standing frame probe already in the codebase,
  not something new): prints `[FRAME-PROBE] … ms/frame · render cpu … · render gpu … ·
  N draw call(s) …` every 60 frames — this is where DIAG-21/23's "idle frame · gpu ·
  cpu · draws" column always came from. `SCENARIO=framing portrait; zoom 0.5; wait 20;
  mark idle; quit`, `NO_BAKE=1`, portrait zoom 0.5:
  - **3D (`RENDER3D=1`): 22.9 ms/frame · render cpu 4.2–4.4 ms · render gpu 21.3–21.6 ms
    · 225 draw calls** — matches §15.15's reference table (22.9 · 21.5 · 225) to within
    rounding.
  - **2D control (no `RENDER3D`): 76.0 ms/frame · render cpu 20.5–20.6 ms · render gpu
    74.5–74.6 ms · 11 308 draw calls** — matches §15.15's own 2D row (76.0 · 74.5 ·
    11 308) exactly.
  - Logs (local): `docs/measurements/device_2026-09-17_moto_g04s_r3d3_idleframe_3d.log`,
    `..._idleframe_2d.log`.
- **Pixel-identity run-a vs run-b ✅ 0 px.** Two independent cold boots, identical
  `SCENARIO=framing portrait; zoom 0.5; wait 3; capture run_a/run_b; quit`,
  `RENDER3D=1 NO_BAKE=1 MAP=PLAYGROUND`. Both PNGs pulled off the device
  (`/sdcard/Android/data/com.example.infiltraitor/files/captures/`), byte-identical file
  size (1 176 788 B) and a literal pixel diff (`PIL.ImageChops.difference`, RGB, no
  alpha): **`diff bbox: None`, 0 of 1 160 640 pixels differ, max channel delta 0.** The 3D
  board is deterministic across boots at this configuration.

**Step 7 CLOSED (2026-09-17).** Commit frame, both grenades' worst frame (with the PUMP
spike traced to a pre-existing, cross-renderer cause — not a 3D defect), load time,
memory, the idle-frame number (exact match to the reference table) and the pixel-identity
check (0 px) are all in hand.

**R3D-3 fully CLOSED (2026-09-18).** Step 5 (skip the hidden 2D build) built and verified
the same day — see its own entry above, right after the step 5 planning section, for the
implementation, the bug found and fixed, and the Moto evidence.

**Idea flagged for later, not started:** the Director asked whether detonating a HIDDEN
blast during load (never shown) could pre-warm whatever the first real detonation pays for
cold — the same trick this project already uses for the 2D board's TileSet alternative
cache during the aim window (`voxel_renderer.gd`'s own comment: *"an alternative minted
early is one not minted late"*). For the 3D board the analogous cold cost is shader
COMPILATION on first use of a `ShaderMaterial` (invisible in this session's headless
captures, real on a device GPU) — a hidden warm-up blast would only pre-pay for whichever
materials/cells it touched, not a general win, and costs real load time to buy it. Not
measured; a candidate for whenever R3D-3's steps 5-7 (or R3D-4's VFX work) make first-
detonation cost visible enough to be worth it.

**Gate (Moto):**
- the idle frame against 22.9 ms;
- the commit frame against 262–279 ms;
- both grenades' worst frame;
- load time and memory;
- 3D run-a against run-b captures at 0 px;
- the web export boots and draws the board.

### R3D-4 — Actors, props and in-world VFX in depth

**Status 2026-09-18 — R3D-4a CLOSED (Director ratified A, billboards); R3D-4b BUILT.**

- **R3D-4a** (`spikes/r3d4a_actor_spike.gd`, `SPIKE=r3d4a`). Wall, column and roof-edge fixtures:
  A and B agree. Glass: only A tints an actor standing behind a pane. Moto g04s medians, 6 agents:
  none 21.8 ms, A 22.2 ms, **B 31.7 ms**; B's depth pass also decoded 0.235 units off on the Mali
  (0.005 on desktop), cause not investigated. Captures:
  `Screenshots/history/r3d4a_sheet_{wall,glass}_bias0.png`.
- **R3D-4b — the agent.** `ActorBillboard3D` mirrors the `AgentSprite` (body + every layer) into
  world-vertical quads, `actor_billboard3d.gdshader` is D17's relight ported to spatial. The 2D
  actor keeps deciding what is shown; `ACTORS3D=0` keeps the 2D figure. Moto, PLAYGROUND,
  `RENDER3D=1`: **23.1 ms vs 22.9 ms** (+0.2 ms), 0 script errors; the on-device LOOK was not
  captured, only the desktop one.
  - **A camera-parallel quad (R3D-4a's shape) was wrong in the live board and was replaced.** One
    depth for the whole figure let a glass pane BEHIND the actor tint his hat, and the tilted floor
    cut his shoes off. The quad now stands vertical (stretched 1/cos 30° to stay 1:1 on screen) so
    depth is right at every height, plus a 0.15-unit lift along the view axis (`ACTORS3D_BIAS`).
  - **Known, owned elsewhere:** (1) 2D overlays (movement-range outline) now draw OVER the actor —
    R3D-5's overlay table; (2) on the GLASS map a glass roof between the camera and the actor tints
    him — the 3D board has no cutaway yet, R3D-7 (row above: OCC-21/OCC-27).
- **R3D-4c — guards and their vision cones. BUILT.** Each guard reuses `ActorBillboard3D`;
  `Room._attach_actor_billboards()` is idempotent and runs both when the board is built and when guards
  spawn. The smooth cone is now a `VisionCone3D` on the ground (depth-tested, so walls cover it): the
  guard's own `_draw_vision_smooth_body` still computes the polygon and, while `vision_3d` is on,
  publishes it through `vision_smooth_ready` instead of painting it — one authority for LOS, fov and
  range. The dev `tiles` cone stays 2D (dev overlay). Moto, PLAYGROUND, `RENDER3D=1`, 3 guards:
  **23.3 ms vs 23.1 ms** with everything 2D (+0.2 ms), 0 script errors; on-device look not captured.
  Captures: `Screenshots/history/r3d4c_playground_guards_cones_{3d,2d}.png`.
  - **Look difference, Director's call:** the 3D cone reads more saturated than the 2D one (alpha
    blends in linear space in 3D, in sRGB on the canvas). Not tuned.
- **R3D-4d — props. PART 1 BUILT: the grenade (rest, flight, tumble, ground shadow).**
  `PropBillboard3D` mirrors a 2D prop's sprites; props are caught as they enter the tree
  (`node_added`), so no creation site is touched. A body is a quad PARALLEL to the camera (it rotates
  in the screen plane, and its centre is raised by the flight height); a shadow is a quad ON THE GROUND
  built from its three screen corners, so walls cover it. The 2D sprites are hidden by swapping their
  material for `hidden_2d.gdshader`, not by `visible = false` — the throw code uses `visible` as logic.
  Dev seam `SEED_GRENADES=1` (+ `GRENADE_GUS`) seeds grenades on the board, on the Moto too.
  Moto, PLAYGROUND, `RENDER3D=1`, 4 seeded grenades: **23.3 ms vs 22.9 ms** (+0.4 ms, +3 draws),
  0 script errors. Capture: `Screenshots/history/r3d4d_grenade_flight_3d_vs_2d.png`.
  - **The movement-range outline (and any 2D overlay) draws OVER a 3D prop, as it does over the actor**
    (Director saw it on the grenade, 2026-09-18). R3D-5's overlay table owns it; not fixed in 4d.
  - **Imperfect:** the flight shadow is fainter in 3D than in 2D and is not visible in one frame
    where it falls under a glass pane. Not tuned.
  - **Attached but NOT verified by capture:** `AgentProbeProp` (the showcase prop).
- **R3D-4d part 2 — `FloatingCollectible`. BUILT.** `PropBillboard3D` now takes a `Node2D` root and
  centred sprites; the collectible's two baked shadows carry a `ground_shadow` meta (a black
  `modulate`, no material) and are drawn on the ground with their alpha as strength; its body uses
  `actor_billboard3d_outline.gdshader` (the silhouette stroke, alpha-scissored). The relight moved to
  `actor_relight.gdshaderinc`, shared by both shaders so the maths exists once; **the ratified actor
  is pixel-identical after the refactor (0 of 25 600 px differ).** Desktop capture of real
  collectibles shows them placed, outlined and shadowed.
  - **No production instance exists today:** `TEST_ZONE_COLLECTIBLES_ENABLED` is `false` and
    `TEST_ZONE_AGENT_PROBE_BRACKET` is empty, so the collectible was verified by flipping the constant
    locally (not committed) and the `AgentProbeProp` path is NOT verified by any capture.
- **R3D-4e — in-world VFX. ✅ BUILT 2026-09-18 for the 3D board (was: PENDING — BLOCKING).** The five
  systems draw in world space, depth-tested (`VFX3D=0` keeps them 2D). The rows below are the ruling,
  the spec and the history; the residuals are the last item of this block.
  Ruling: *particles cannot draw over a wall* — "sem condições de ficar por cima do muro". When it is
  built (now or later) is open; that it is built is not, and R3D-4 is not closed without it.
  - **The defect, measured.** A grenade detonated at gu (3,1), BEHIND the 2-storey concrete wall at
    row 2, with `RENDER3D=1`: the smoke puffs, dust and embers draw over the wall's faces, because
    every VFX overlay is a 2D `CanvasItem` on top of the 3D board. Only the plume above the wall's top
    is right. Capture: `Screenshots/history/r3d4e_vfx_over_wall_2d_particles.png`.
  - **Why a port is not a perf item:** the VFX are already `MultiMesh` 2D (P7b/P7c, `ShardField`), so
    CPU submission is solved; the fill is the same in 3D. This is a CORRECTNESS item, and the reason
    it must precede tall pieces and parallax: every particle simulates in 2D screen pixels with its
    "height" folded into screen y, so it has no world position to depth-test or to parallax with.
  - **What it needs:** particle state in WORLD space (ground point + height) for the five systems —
    `SmokeSparkOverlay` (puffs, sparks), `EmberOverlay`, `DebrisOverlay` (dust, chips),
    `ShrapnelOverlay`, `GlassRainOverlay`/`ShardField` — drawn as depth-tested `MultiMesh` in 3D;
    `CircleField` becomes the 3D helper and keeps the `custom_aabb` lesson (a MultiMesh's bounds
    come from its base mesh). The screen flash and the negative strobe stay screen-space.
  - **Interim option considered, NOT taken:** one depth per emitter (the blast's origin). Cheap, but a
    nearby wall would cut the whole plume where it rises above it — worse for the common case.
  - **STATUS (2026-09-18):** 4e-1 BUILT (`ParticleMath`, `CircleField3D`, `particle_space_selftest`:
    worst screen error 0.0005 px through a real `Camera3D`); **4e-2 BUILT** — smoke puffs, embers and
    dust specks draw in world space, depth-tested (`VFX3D=0` keeps them 2D). Evidence
    (`Screenshots/history/r3d4e2_vfx_depth_before_after_control.png`): the blast behind the wall no
    longer paints the wall's face; open-floor blasts match the 2D ones; an isolated control (red puffs
    in front of the wall, blue behind) shows the front ones and none of the back ones. 4e-3 (sparks,
    shrapnel, chips), 4e-4 (glass) and 4e-5 (retire the 2D draw, Moto) remain — **4e stays PENDING.**
  - **4e-3 BUILT** — spark streaks, shrapnel glows and trails, rotated debris chips. One new
    primitive, `QuadField3D` (a rectangle from a centre and two 2D half-extent vectors, carried into
    the world by the same `ParticleMath`): a line is a thin rectangle, a chip a rotated one; the disc
    field now extends it. The selftest proves a line's two ends and a rotated chip's four corners land
    on the pixels the 2D draw would (worst error 0.0004 px). An isolated control (red in front of the
    wall, blue behind; `Screenshots/r3d4e/e3_synth_N.png`, local) draws the red sparks and chips and
    none of the blue. **Shrapnel has no capture of its own**; it uses the two fields proven here.
  - **4e-4a BUILT — the glass rain.** `ShardField3D` (a MultiMesh with the shape's atlas cell in the
    custom data, `glass_shard_field3d.gdshader`); each shard travels between its two REAL 3D ends
    (pane voxel and landing, from `from_floor`/`to_floor`) with the arc lifted by height, instead of a
    carried 2D displacement, so a scattered landing stays on the floor it lands on. **Found on the way:
    under `RENDER3D=1` the 2D rain never drew at all** (its overlay is a child of the hidden
    `_voxel_renderer`): the demo measured 0 differing pixels mid-flight in 2D against 90 246 in 3D. The
    G-D43 control still holds (after the kill, 0 differing pixels). Capture:
    `Screenshots/history/r3d4e4_glass_rain_3d_midair.png`.
  - **4e-4b — the crack sprite — MOVED TO R3D-6 (glass look).** Measured under `RENDER3D=1`: the
    `glass_crack_demo` capture, before vs after the crack is applied, differs by **0 of 921 600 px**.
    The sprite is a child of the hidden `_voxel_renderer`, so it draws nothing today; there is no depth
    defect to fix, only a look to build (a 252-line canvas shader with occupancy, opening and hole-cut
    textures to port to a pane-plane quad).
  - **4e-5 GATE — PASSED.** (1) The blast behind the 2-storey wall no longer paints its face, particles
    behind it but above its silhouette still show, and particles in front show
    (`Screenshots/history/r3d4e5_vfx_wall_face_clean_top_visible.png`). (2) **Moto g04s, one detonation,
    PLAYGROUND, `RENDER3D=1` (`docs/measurements/device_2026-09-18_moto_g04s_r3d4e_vfx{0,1,1b}.log`):
    3D VFX mean 30.2 ms vs 32.3 ms in 2D (−2.1 ms), 350 vs 372 frames and 10.6 s vs 12.0 s wall clock,
    idle primitives 17 156 vs 21 072; 0 script errors.** The worst frame (~0.98–1.13 s) is the same in
    both: it is the light/consequence cost, not the VFX. (3) Measuring found idle MultiMeshes with zero
    instances still cost a draw call (+6); an empty field is now hidden (233 = 233 draws at idle).
  - **RESIDUALS, none blocking:** the 2D overlay nodes still exist and their `_draw()` is where the 3D
    frame is published (a hidden 2D node would stop the 3D VFX; retire together with the 2D board at
    R3D-8); the muzzle flash's floor is an ESTIMATE (`muzzle_floor_drop_px`); shrapnel has no capture of
    its own; four-view agreement is moot until rotation returns (R3D-9), where the anchors must be
    re-derived per view.
  - *Original ruling and spec, kept:*
  - **⚠️ A latent Rule-9 bug found and fixed on the way.** The VFX asked for the floor under a voxel
    with `voxel_world_position(grid, 0)`. Level `0` stopped existing at the level renumber, so it
    answered `Vector2.ZERO` and every caller took its "unbuilt column" fallback: **330 of 330** on a
    detonation. Four sites (two in `room.gd`, two in `DetonationPlanBuilder`) now use
    `ground_plane_level()`. Side effect, intended by the original design: the 2D dust now actually
    falls to the floor (it had not since the renumber), so a 2D detonation looks different from before.
  - **Rule in force from now:** any NEW VFX or particle code stores world-space state (ground +
    height), never screen pixels, so the debt does not grow.
  - **Done when:** the capture above, repeated, shows no particle on the wall's face; a plume
    rising above the wall's top still shows; the four-view captures agree; Moto frame cost recorded
    for a detonation against the 2D baseline.

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

**R3D-5b — STATUS 2026-09-18: BUILT for the ground overlays.** One mechanism, `GroundCanvas3D`: it has
the four `CanvasItem` calls the ground overlays use (`draw_colored_polygon`, `draw_line`,
`draw_polyline`, `draw_circle`), tessellates each in 2D (a line is a quad `width` px thick ON SCREEN),
carries every vertex onto the ground plane by the board's own 2D→ground affine, and publishes one
`ArrayMesh` per redraw, depth-tested, at a per-overlay `lift` and `render_priority` (which stand in
for the 2D `z_index`). The overlay's own drawing code is unchanged (`_draw()` → `_draw_into()` with the
draw target swapped); `GROUND3D=0` keeps them 2D. **Why the look is unchanged:** the ground plane maps to
the screen affinely, so a vertex placed on the ground from a 2D point projects back to that pixel —
`ground_canvas3d_selftest` proves it through a real `Camera3D` (worst error 0.005 px; line thickness
3.9999 of 4.0). What changes is depth.

Captures (`GROUND3D` 1 vs 0, PLAYGROUND, `RENDER3D=1`): the movement outline no longer cuts the agent's
hat, the pink selection diamond passes behind his legs, and **the two defects R3D-0 found on the Moto
are gone — the dark "roof tops" (`_tile_shadow` + `_shadow_boundary_overlay`) and the GU grid lines no
longer paint across the block's faces.**

**Decision table** (every script that draws in 2D; `G` = ground overlay → `GroundCanvas3D`,
`S` = stays screen-space, `D` = dev/debug, stays 2D, `V` = world VFX (R3D-4e, done), `→` = owned by
another stage):

| script | class | decision |
|---|---|---|
| `navigation/movement_overlay` (reachable bands) | G | **done** |
| `navigation/path_preview` | G | **done** |
| `ui/selection_overlay` (pink diamond) | G | **done** |
| `overlays/throw_perimeter_overlay` | G | **done** (built; not separately captured) |
| `overlays/noise_overlay` (rings) | G | **done** (built; not separately captured) |
| `overlays/gu_grid_overlay` | G | **done** |
| `overlays/shadow_boundary_overlay` | G | **done** |
| `overlays/tile_overlay` ×2 (shadow = MULTIPLY, gameplay = mix) | G | **done** (MUL as `blend_mul`) |
| `overlays/aim_bubble_overlay` (blast dome) | S | stays: a volumetric aiming affordance around the agent, not on the floor |
| `overlays/throw_arc_overlay` | S | stays: an in-air trajectory |
| `overlays/shrapnel_preview_overlay` | S | stays: aiming rays in the air |
| `overlays/tracer_overlay` | S | stays: an in-air projectile (z 4000, above everything) |
| `overlays/guard_noise_indicator` | S | stays: floating sound icons |
| `overlays/target_cursor_overlay` | S | stays: a cursor, not scenery |
| `overlays/explosion_flash_overlay` | S | stays screen-space (plan) |
| `ui/tile_labels_overlay`, `debug/voxel_ruler_overlay`, `debug/circle_gate_probe` | D | stay 2D |
| `overlays/height_overlay`, `temporal_overlay`, `light_overlay`, `shadow_overlay`, `exposure_overlay`, `elite_exposure_overlay`, `tile_risk_overlay`, `trail_overlay`, `blast_wireframe_overlay`, `occlusion_overlay` | D | stay 2D (dev visualisations) |
| `overlays/light_ray_overlay` (golden shafts) | → R3D-6 | light look, hidden by default |
| `overlays/ceiling_prop_overlay` (overhead layer) | → R3D-7 | cutaway/roof |
| `overlays/occlusion_slice_panel` (OCC-27) | → R3D-7 | replaced by the 3D cutaway |
| `ui/fog_of_war_overlay` | G | **done (R3D-5c)**: `draw_polygon` with per-vertex colours added to the canvas; the feathered diamonds land on their pixels (selftest [6]); capture 3D vs 2D shows the same gradient (mean luminance 76.4 vs 74.8). The `VisionFogOverlay/FogRect` is a separate screen-space rect and stays. |
| `smoke_spark`, `ember`, `debris`, `shrapnel`, `glass_rain`, `shard_field`, `glass_crack_sprite` | V | R3D-4e |
| `agents/agent.gd`, `agents/guard_enemy.gd` (`_draw`: vector fallback, dev cones) | — | actors are billboards (R3D-4b/c); the dev `tiles` cone stays 2D |
| `world/room.gd` `_draw` (spawn marker, playable boundary, shadow debug) | D | stay 2D |

**Layering.** The 2D `z_index` order is kept as `render_priority`: tile_shadow (MULTIPLY) 0, GU grid 1, fog 2,
tile_game 3, shadow boundary 4, movement 5, path 6, selection 7, throw perimeter 8, noise 9; each at its own
`lift` above the floor (0.004 … 0.022 units).

**R3D-5a — STATUS 2026-09-18: BUILT for picking and for the cell lattice; `floor_layer` is NOT retired.**
- **Picking by camera ray.** `Board3DLive.pick_cell(screen)` intersects the camera ray with the ground
  plane and takes `(floor(x), floor(z))` — the world's ground unit is the room's cell, so there is no
  lattice, no tilemap and no 2D canvas transform in the path. `Room._screen_to_tile()` and
  `_tile_to_screen_center()` use it under a 3D board; `PICK3D=0` keeps the 2D pick, and the 2D
  functions stay as the reference. **Differential check in the real game (`PICK_CHECK=1`): 35 840 screen
  points over 16 framings (4 zooms × 4 camera centres), pick AND its inverse, 0 disagreements.**
- **`GroundGrid` — the lattice without a TileMapLayer.** `map_to_local(c) = (128·(x−y)+128, 64·(x+y)+64)`,
  measured on `tileset_blocks.tres`. `ground_grid_selftest` asserts it against a REAL `TileMapLayer`:
  0 of 12 100 cells differ, and 0 of 20 000 random points pick a different cell than the room's own
  algorithm. **41 `floor_layer.map_to_local()` calls in 27 files** (actors, overlays, controllers, the
  room) now use it. Capture before/after (git stash): 37 px differ against a same-code control noise of
  2 100 px (flickering lights, top-right); **0 px differ outside that noise region**, so nothing moved.
- **What still reads `floor_layer` in production — all TILE DATA, none geometry:**
  `get_cell_source_id` / the TileSet's `walkable` custom data (`room`, `selection_controller`,
  `movement_overlay`, `view_context`), `get_used_cells`/`get_used_rect` (`room`, `view_context`),
  `to_local`/`to_global` (`room`, `view_context`), `local_to_map` (the 2D reference pick and
  `view_context`), and `set_cell` (`room_builder`, which builds the floor). Retiring the NODE means moving
  walkability and the floor's cell set into grid data; that belongs with R3D-8's deletion of the 2D
  board, not here.
- **Not built, on purpose:** picking a WALL by ray against the store. Nothing consumes it, and it raises a
  design question (should a click on a wall face select the wall's cell, or the floor cell behind it, as
  today?) that is the Director's. Today's behaviour is kept exactly.
- **NOT RUN:** the same `PICK_CHECK` on the Moto (no device connected at the time), and touch, pinch and
  pan through the TEL scenarios. Pan and pinch move the 2D camera the 3D camera follows; they do not go
  through the pick.

**Known, not built:** the 2D aliasing of a 1–2 px line differs slightly (the 2D lines were antialiased,
the ground quads are not); the aim dome and the throw arc still draw over actors, by decision.

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
   - **BUILT 2026-09-19 (`[R3D-6a..d]`), RATIFICATION PENDING — the Director's line goes here.**
   - One back-reading pass, `glass_pane3d.gdshader`: tint MULTIPLY with the body floor, frost,
     sheen, per-member tint. **The maths runs in sRGB** — the 3D screen texture is linear and
     ALBEDO is encoded on the way out, so the raw formula applied tint^(1/2.2) (measured effective
     multiply 0.81/0.87/0.96 against the asked 0.61/0.72/0.91). Force 0.60 → 0.68 on the 3D board
     only (Director: slightly more blue).
   - Pane caps: top 0.60 and thickness 0.78 through vertex `COLOR.r`; a face is a cap when it is
     at most 2 voxels across (`_glass_plane_dim`). A glass floor stays a main face.
   - Crack sprite: `GlassCrackMirror3D` mirrors every 2D `GlassCrackSprite` onto the pane plane;
     the shader is `glass_crack.gdshader`'s fragment. Crack before/after: 5 494 px in 3D (0 before),
     6 002 px in 2D. Only the SW face was captured; the blast craze field goes through the same mirror.
   - **Side sliver: no code.** A pane is real geometry, the mesher hides shared faces, and the
     thickness is a face; the 2D sliver existed to fill a tile seam that 3D does not have.
   - **Rim wedge BUILT 2026-09-19 (`[R3D-6h]`).** `GlassCrackMirror3D` rasterises each applied opening
     (`_glass_applied_openings`, last 16) into one layer of a `Texture2DArray`, and `glass_pane3d.gdshader`
     discards a fragment inside one, so the cells a hole touches are torn along its polygon.
     Proven on a synthetic opening at the crack demo's impact (1 526 px changed, all inside the star);
     `INFILTRAITOR_GLASS_OPENINGS3D=0` = rectangular, comparison only. On a real blast the voxel hole is
     usually larger than the polygon, so the cut barely shows there.
   - **Open (Director, 2026-09-19): a light jump at the end of every blast** — the forced light/soot
     refresh at the beat's end. Fine adjustment deferred until the port is complete.
   - **Found on the Moto: the 3D board drew the pane and the crater the blast destroyed.** FIXED
     2026-09-19 at the root, and the diagnosis below the first attempt was wrong: `delta.touched_voxels`
     was never incomplete. `_collect_store` grouped claims into chunks with a hard-coded `>> 5` (32)
     while `_chunk_of()` uses `CHUNK_VOXELS` (16, since R3D-3 step 3), so the commit remeshed the wrong
     chunks (5 chunks left stale: 2,2 · 3,1 · 3,2 · 3,3 · 4,2). Measured on the total vertex count of every
     chunk mesh, commit vs a full remesh: 928 vs 2 896 before; **3 808 vs 3 808 (GLASS, blast in the
     demo), 3 348 vs 3 348 (GLASS, `detonate 0`) and 4 172 vs 4 172 (PLAYGROUND)** after. The
     end-of-beat full remesh (`on_blast_consequence`, `CONSEQUENCE_REMESH`) is deleted.
     The Moto A/B below measured that workaround, which no longer exists.
   - **Moto g04s, GLASS + grenade #0, RENDER3D=1, the same APK, remesh on vs off:** mean 41.5 / 40.5
     ms against 41.4 / 41.2 ms, worst frame 2 556 / 2 513 ms against 2 504 / 2 530 ms (the
     cook, frames 62–63) — no difference. The remesh is 566 ms in the background, 6.4 ms of upload on
     the main thread. 2D on the same scenario: mean 120.6 ms, worst 3 998 ms, 23.3 s wall against
     11.9 s.
   - Captures: `Screenshots/history/glass_crack_demo_r3d6_{2d,3d_flat,3d_sat}_before.png`,
     `glass_crack_demo_r3d6c_{2d,3d}_after.png`, `glass_crack_demo_r3d6d_3d_before.png`,
     `r3d6e_blast_2d_after.png`, `r3d6e_blast_3d_after.png` (before the fix),
     `r3d6g_blast_3d_after.png`, and on the handset `moto_r3d6_glass_{2d,3d,3d_fix}.png`.
   - Not verified: the craze on a face other than SW, glass on a fixed unit-test of the new
     shader, the floor shards the 2D draws as tiles (absent in 3D), and no selftest was run.
3. **Damage decals** from `ART_SPECIFICATIONS` §7 families, per voxel: a decal/variant
   channel beside the planes, and a texture array per material family.
   - **BUILT 2026-09-19 (`[R3D-6j]`), ratification pending.** The variant already rides the store's
     `aux` nibble, so no new channel was needed. One `Texture2DArray` of the 42 decals on disk
     (bullet/dent/crack × concrete, metal, stone, wood, brick, earth; missing files are absent, never an
     error) and a pseudo-material `__decals__` whose shader is the opaque face shader's lighting and soot
     with the colour replaced by the decal (layer in vertex `COLOR.r`). Faces per `VoxelRenderer._decal_material()`'s
     table: blast CRACKED = all three visible faces of a crack-capable material; bullet = the one lateral
     face; DENTED = the carved face, on the pit floor. Quads sit 0.02 voxel off the face, unmerged.
     `INFILTRAITOR_DECALS3D=0` = none. A/B on PLAYGROUND `detonate 0`: 8 666 px changed; marks visible in the
     pits. Wall marks: with synthetic store damage (CRACKED blast, CRACKED bullet, DENTED) on one column of a
     PLAYGROUND block, dark bullet/dent marks appear on its SW face (before/after crop). **Not verified:** the crack
     art itself reads on a wall (only its layer choice was checked), a real firearm shot, and the 20/16
     lateral stretch the 2D applies.
4. **Dents:** a DENTED voxel's carved side becomes a real inset in the mesh.
   - **BUILT 2026-09-19 (`[R3D-6i]`), ratification pending.** `_emit_dent`: the carved face (LEFT = SW,
     RIGHT = SE, TOP = top; BOTTOM is never seen and stays flat; glass is exempt) leaves the greedy
     merge and becomes a 0.2-voxel frame, a floor 0.3 deep and four walls. Unmerged, so it cannot merge
     with its neighbours. The opaque shader's voxel lookup now offsets by 0.01 along the normal instead
     of 0.5, because an interior face is not on the voxel boundary. Capture: PLAYGROUND `detonate 0`
     (`dent3d.png`, floor pits with visible walls). Depth/margin are look numbers, not measured.
5. **Whole facades on intact surfaces**, per wall run. `FacadeSampler`'s window origins
   replace the prototype's world-space UVs. Floors per §9 Q1.
6. **Floor depth dim, embers and burnt voxels, the soot fade's look.**
7. **Anything the R3D-0 reference set shows that this list missed** — it is added, not
   waved through.

**Gate:** each item has a pair of captures and a ratification line in this plan.

### R3D-7 — Occlusion and cutaway in 3D

**BUILT 2026-09-19 (`[R3D-7c]`) — the ORIGINAL 2D mechanism, on 3D. LOOK CALL PENDING (Director).** The
Director's diagram (2026-09-19) is the spec: an occluded EDGE keeps its bottom 2 voxels solid (a fixed
8x2x2 block across the edge), and everything above it becomes a wireframe taking the shape of the slices
above, with a fill whose opacity varies (ring). Two earlier spikes were REJECTED and deleted: a
cylinder around the camera ray (it also cut the back wall, because the camera looks down and a wall
behind the agent counts as nearer in view depth), and a map-wide storey cut ("the player cannot know what
is behind the wall").
- **The set is the 2D board's own** (`OcclusionSet`, O1 — view, never state; nothing new decides what is
  occluded): `Room._recompute_occlusion()` hands it to `Board3DLive.on_occlusion()`, which writes one texel per
  grid column (min level, max level, ring + 1) and rebuilds the wireframe lines.
- **Fill:** the face shader ghosts a voxel whose column is in the set and whose level is in [min, max]:
  Bayer-dithered into discarded pixels and ghost diamonds, the diamonds' density the ring's opacity
  (0.14 / 0.24 / 0.36), a flat periwinkle tint with per-face contrast (top 1.0 / SE 0.80 / SW 0.60). The levels
  below min (the base) are untouched. Decals inherit it.
- **Lines:** `OcclusionSet.get_wireframe_by_level()` is already merged across walls and hidden-face culled, so
  its lattice lines become one line mesh (white, depth-tested); nothing is emitted per edge.
- **Look approved by the Director (2026-09-19)**, with three completions built the same day: the base's TOP is
  capped (the mesher hides those faces under the ghosted voxels, so the base read hollow — a flat periwinkle
  quad on each wall column's base top, walls only: `min_level - ground` is 2 mod 8, a roof slab starts on a
  storey boundary); the white outline now also runs along the bottom of the volume; and every line that is not
  near-facing (the far edges and the junctions) is dashed, 1 voxel on and 1 off.
- **Sides (Director, 2026-09-19):** a side face of the volume is filled where the cell across it holds a SOLID,
  non-glass voxel (a wall that carries on behind, a frame), per level, and left transparent where it holds glass
  or nothing — so a window slab is painted where it touches its frames and clear where it touches the pane.
  Read from the store at each occlusion change (`_solid_non_glass`), shaded by facing (SE 0.85 / SW 0.70 / far 0.55).
  Capture: `Screenshots/history/r3d7_cutaway_glass_map.png` (GLASS, agent at 16,15).
- **Fill and lines are two nodes (Director, 2026-09-19).** The fill (base caps and painted sides) is an opaque mesh that
  draws after the world (`render_priority` +10 — higher draws later) and WRITES depth, so the ground overlays (the hovered
  cell's outline) do not show through it. The lines are their own mesh, drawn over everything (`no_depth_test`, priority
  127), and WHICH pieces to draw is decided when the outline is built, not by the depth buffer: `_occ_hidden` marches a ray
  from each piece toward the camera through the store (half a voxel a step; ghosted voxels and glass do not stop it), and a
  piece behind a real solid voxel is dropped; a far edge (not near-facing: the back of the volume) keeps only its dashes; a
  near edge stays full. Unit edges are first joined into runs (`_occ_merge_edges`) because a dash (1 voxel) is as long as
  than the 1-voxel edges the set emits, and a corner shared by two faces is one edge, near-facing if either face is. Tried and
  dropped: a transparent-pass fill (speckled sides), a stencil to protect the lines (a material that reads stencil must
  be in the alpha queue), depth-tested lines (the fill covered them), depth-less lines with no classification (they showed
  through real walls).
- **Nested occlusion (two volumes, one inside the other's screen area):** each volume has its own cap and sides; the
  nearer one's opaque fill hides the farther one's fill (correct), and both sets of lines are drawn over everything.
  Seen on GLASS with the agent at 16,15 (`r3d7_cutaway_glass_map.png`). Not exercised: three or more levels of nesting.
- The 2D wireframe overlay is hidden while the 3D board is live. `INFILTRAITOR_CUTAWAY=0` = off.
- Capture: `Screenshots/history/r3d7_cutaway_dither_spike.png` (agent behind a PLAYGROUND block: 260 columns
  occluded; in open ground 0). **Not verified:** guards behind walls; glass (not ghosted); roofs and
  interiors; the Moto cost; the flat fill has no separate top tint yet.

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

### To investigate at the end of R3D — real 3D objects in the scene

**Not a stage. A question the Director raised on 2026-09-18, parked until R3D-9 closes.**
Now that the board is a Godot 3D scene, can imported 3D meshes (GLB) stand in it as real
geometry, instead of baked frames on billboards? Technically yes: a `MeshInstance3D` under
`Board3DLive` is depth-tested, covered by walls and tinted by glass with no extra work, and
`Board3DLive.ground_point()` already maps a grid cell to the world. What the investigation
has to answer before anyone builds it:

- **Light.** The board has no 3D lights: light and soot come from per-cell planes read by
  the board's own shader. A real mesh needs a shader that reads the same planes, or it will
  not match the scene.
- **Cost on the Moto.** One mesh with its own material per prop is a new bill. R3D-4b and
  R3D-4c billboards cost +0.2 ms each on the Moto g04s; a mesh has not been measured.
- **Direction.** The actor register (D35 rigged low-poly mesh, D42 RAM is the constraint,
  D44 four baked facings) chose baked frames. Replacing them at runtime changes that
  direction and needs the Director's ratification.
- **Where it likely pays first:** static scenery with no destruction (furniture, decoration),
  not the moving props R3D-4d covers.

Suggested shape: a short spike — one GLB, lit from the board's planes, measured on the Moto
against the billboard it would replace — before any decision.

---

## 5. Order, dependencies, and what folds in

```
R3D-0 ─► R3D-1 ─► R3D-2 ─► R3D-3 ─┬─► R3D-4 ─┐
                                   └─► R3D-5 ─┴─► R3D-6 ─► R3D-7 ─► R3D-8 ─► R3D-9
```

- **R3D-1 and R3D-2 pay the 2D build too**, in memory and in the LIGHT step. If the track
  stopped there, the game would still be better.
- **R3D-4 and R3D-5 can run in either order** once R3D-3 exists.

### Sequencing decided 2026-09-18 (the Director delegated the order and the steps)

Order: **R3D-4e → R3D-5b → R3D-5a → R3D-5c → R3D-6.** Each step is its own commit, gated by a
capture of the real path and by lint, selftests and invariants; the Moto is run when a step could
move frame cost or memory, not as a ritual (`[[r3d-focus-system-quality-not-cosmetics]]`).

Why this order:
1. **4e first.** The Director ruled particles over walls unacceptable, and world-space particle
   state is the prerequisite of tall pieces and parallax.
2. **5b before 5a.** Ground overlays as depth-tested ground quads reuse what 4c and 4d already
   proved (`VisionCone3D`, the ground shadow), and it removes the defect the Director has now seen
   three times (a 2D overlay drawn over an actor or a prop). Picking (5a) is the structural,
   riskiest step — it retires `floor_layer` from input — so it goes after the visible wins, with
   the input and HUD seam selftests as its net.
3. **5c last in R3D-5:** fog of war depends on what 5b decides for the other ground overlays.

**R3D-4e in steps** (the spec is in that section):
- **4e-1 — the space.** `ParticleSpace` on `Board3DLive`: `origin_3d(world_pos, floor_pos)` (height
  from the pair — the detonation calls already carry both) and `to_world()`, which maps a 2D
  screen displacement onto the world exactly (horizontal → camera right, vertical → up ÷ cos 30°),
  so the simulation stays as it is and only the projection changes. `CircleField3D`: a 3D
  `MultiMesh` of camera-facing discs, depth-tested, `custom_aabb` set. A selftest proves a particle
  at its origin lands on the same screen pixel as in 2D.
- **4e-2 — the CircleField users.** Smoke puffs, embers, dust (the three `CircleField` clients).
- **4e-3 — lines and quads.** Spark streaks, shrapnel lines and glows, debris chips.
- **4e-4 — glass.** `ShardField` and the rain: its atlas shader ported to spatial.
- **4e-5 — retire the 2D draw under `RENDER3D=1`, and gate.** The behind-the-wall capture repeated,
  the four views, the Moto detonation frame against the 2D baseline.

**R3D-5 in steps:** **5b** the ground overlays (movement range, path preview, selection diamond,
aim dome, throw perimeter and arc, noise rings) each with a row in the decision table; **5a**
picking by camera ray, `floor_layer` readers moved to the store or the grid; **5c** fog of war.

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
- **v1.4, 2026-09-16.** R3D-1a measured.
  - The decision rule was committed first (`43af4062`), then `StoreLayoutSpike`
    (`54b98629`, `8c7b2e55`).
  - Every layout reproduces O on 5 maps and after corner grenades. All are under 10 % of
    O's memory.
  - On the Moto, A fails the speed gate (T3 +16 %), and B beats Ac by 69 %.
  - The rule picks B, pending the Director.
  - Corner collisions diverge under a blast; B keeps both claims.
- **v1.5, 2026-09-16.** The Director confirmed B. R3D-1b built and gated.
  - `VoxelStore` in shadow behind `VOXEL_STORE=1`, mirrored from `Voxel.set_damage()`
    (commit `eaa191e8`).
  - `board_probe.py shadow` PASS: PLAYGROUND 10 stages and GLASS 9, identical per voxel.
    The flag changes 0 px.
  - Found: rotation and SaveState restore lose junction-column and corner damage (21
    voxels on PLAYGROUND).
- **v1.6, 2026-09-17.** R3D-1d step 1 done (commit `75b97af6`): `VoxelStore` is the
  writer, `Voxel` is a thin `claim:int` wrapper. 57/57 selftests, `board_probe.py gate`,
  `check_invariants` and `gen_codemap --check` pass.
  - The Director's call on `Voxel`'s fate: a thin index wrapper, not deletion and not a
    transient view — §4's R3D-1d text was open on this ("as R3D-1a decides").
  - Steps 2-4 (the soot BFS's input map, the plan/`WorldDelta` keys) DEFERRED to R3D-2
    on the Director's call, once implementation showed `Voxel`'s properties already
    dispatch through the store by claim, so migrating `cell_to_voxel`/`damaged_voxels`
    to a bare int now would trade a clean accessor for hand-unpacked bits at every call
    site, for memory that was never in that dict (tens of entries, not 215 432) — and
    would have to solve `detonation_plan_builder.gd`'s claim==-1 detached-projection
    case for no gain right now.
  - Step 5 (the Moto remeasure), same session, device connected mid-session: 3 boots,
    thin `Voxel` costs 87–140 MB (median ~100 MB) for 215 432 wrappers, against R3D-0's
    ~190 MB — roughly half. One grenade detonation showed no hot-loop regression
    signal. **R3D-1d closed.** Next: R3D-2.
- **v1.7, 2026-09-18.** R3D-4 and R3D-5 built (the Director delegated the order and the steps, and
  ratified: R3D-4a's billboard, the agent's and the guards' look, R3D-4e as a blocking item).
  R3D-4a spike (A billboard vs B depth composite; Moto: none 21.8 ms, A 22.2 ms, B 31.7 ms, and B's depth
  pass decoded 0.235 units off on the Mali). R3D-4b the agent, R3D-4c the guards and cones, R3D-4d props
  (grenade, collectible), R3D-4e in-world VFX in five steps (1 the particle space and its selftest, 2
  smoke/embers/dust, 3 sparks/shrapnel/chips via `QuadField3D`, 4a the glass rain via `ShardField3D`, 5
  the gate; 4e-4b, the crack sprite, moved to R3D-6). R3D-5b ground overlays and the decision table, R3D-5c
  the fog, R3D-5a picking and `GroundGrid`. Found on the way and fixed: four callers asked for the floor
  with a literal level `0` (330 of 330 fell back — Rule 9); the 2D glass rain never drew under
  `RENDER3D=1`; empty MultiMeshes cost a draw call on the Moto (hidden now). Parked: real 3D objects.
  Selftests 57 → 60; the register of what is still open is at the top of this file.
