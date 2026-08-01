# INFILTRAITOR — Voxel Light Projection Master Plan

> **Status:** ✅ SHIPPED (VL-01 → VL-D5, 2026-07-23 → 2026-07-26) — "Alpha
> Temporal Light Foundation"; extended by FACE-READ-01 (2026-07-31) and
> FACE-READ-02 (2026-08-01) — "Alpha Face Light System Foundation." This is the
> geometry/mechanism reference for the voxel FACE lighting plane (buckets, blast
> visuals, persistence, temporal repaint, per-face shading) — read it before
> touching `VoxelLightField`, `VoxelRenderer.apply_light_field*()`,
> `godot/shaders/voxel_face_shading.gdshader`, `EmberOverlay`, or the
> destruction↔lighting seam in `test_zone_controller.gd`. Item 6 (metal
> denting/warping), the 4-view prebuild optimization, and per-FACE soot CONTENT
> are the pieces still open — see their own sections below for status.
> **Authored:** 2026-07-23 (solo mode).
> **Was prerequisite for:** resuming `DESTRUCTION_MASTER_PLAN.md` (paused
> 2026-07-22 precisely because destruction was invisible while every voxel
> rendered fully lit) — that blocker is now closed.

This plan connects the tactical lighting pipeline (`LightRegistry →
ShadowProjector → ExposureSystem`, GU resolution, floor-only shadows) to the
voxel render plane, painting every voxel face according to lamp position and
distance. It is the **visual brightness** side of the canonical split — the
tactical side (5 visibility classes, detection multipliers) is owned by
`docs/systems/LIGHT_MASTER_PLAN.md` and does not change here.

---

## 1. Ratified Canon (Director, 2026-07-23)

1. **6 brightness buckets** — discrete, deterministic, per voxel. No continuous
   shading.
2. **Bucket 0 (face full-shadow) is very dark but textures stay readable** —
   near-black is banned; facade detail must survive.
3. **`MULTIPLY_LUMA_LIFT` default → `0.0`, variable kept** — brightness
   authority transfers to the bucket table (as anticipated by the 2026-07-10
   blend decision in `BAKE_SYSTEM_REFERENCE.md`). The lift stays available as a
   tunable var in case MULTIPLY needs compensation again.
4. **Binary-dominant expectation** — in practice most voxels resolve to
   full-lit or full-shadow, with distance falloff providing the intermediate
   buckets near lamps. Multi-lamp additive blending is NOT an initial goal.
5. **Two temporal regimes**, both first-class:
   - **Regime A — short loops.** Broken lamp flicking in a corridor
     (two states alternating fast), emergency strobes, moving occluders
     (e.g. a turbine alternately passing/blocking light). The scenery animates
     continuously in real time for as long as the player deliberates, until an
     action/turn-end fires TICs.
   - **Regime B — gameplay consequences.** Switch toggles light → re-render
     that region immediately; lamp shot → permanently off; moving walls and
     light-based puzzles re-derive on structure change. Event/TIC-driven.
6. **Vision modes are future plumbing only** — thermal (heat), night vision,
   X-ray (enemies/elements through walls) and other lighting-influenced
   overlays will alter the information the player gets. Nothing is built now;
   the per-voxel light data must be exposed through one queryable seam they
   can consume later.
7. **Boot resumes the last worked map** (VL-00, landed 2026-07-23): the
   `user://current_map.cfg` restore in `room.gd` is now unconditional; the
   `@export` default (`PLAYGROUND`) applies only when no cfg exists.

---

## 2. Current-State Facts (verified 2026-07-23)

- `LightSource` already carries everything sampling needs: `cell`,
  `height_class` (0–4), `radius`, type, temporal state machine
  (flicker/pulse/rotation), and a **`visual_energy` field that nothing
  consumes today** — reserved for exactly this system. `tactical_energy`
  stays gameplay-only (canon: visual brightness ≠ tactical visibility).
- `LightingController.rebuild_all()` already re-derives lights per perspective
  rotation and emits `lighting_rebuilt` — the natural rebuild hook.
- The per-cell tint mechanism is proven in production: occlusion ghosts are
  **alternative tiles with per-alternative `modulate`**
  (`VoxelRenderer._mint_ghost_alternatives()`, `GHOST_ALT_IDS = [1,2,3]`),
  applied per cell via `set_cell()`. `BAKE_SYSTEM_REFERENCE.md` names this
  same lever for per-wall tints.
- Baked pages are grayscale; blend rides per-tile modulate (`MULTIPLY` +
  `MULTIPLY_LUMA_LIFT = 0.25`).
- **PLAYGROUND has zero authored lights** (`Light registry initialized with
  0 map lights`, real boot 2026-07-23). VL-01 must author lamps in the
  PLAYGROUND MapSpec or nothing will visibly change.

---

## 3. Architecture

### 3.1 VoxelLightField (new module, `godot/scripts/systems/lighting/`)

The single seam between tactical lighting and every visual consumer.

- Built on every `lighting_rebuilt` (and by localized rebuilds, §3.5).
- Owns per-voxel bucket data: `get_bucket(level: int, cell: Vector2i) -> int`
  (0 = darkest … 5 = full lit) plus an influence-set query per light id.
- **This is the future vision-mode seam** (canon #6): thermal/night/X-ray
  overlays read this field (and `ExposureSystem`), never the tilemaps.

### 3.2 Sampling model (v1)

For each voxel cell, intensity = max over active lights (no additive blending,
canon #4) of:

```
lamp_term = visual_energy
          × radial_falloff(GU distance lamp→voxel column, radius)
          × vertical_falloff(|voxel level − lamp anchor level|)
          × facing_factor(slice direction vs lamp bearing)
          × occlusion_gate (ShadowProjector: 0 if a wall blocks lamp→column)
```

- GU-level occlusion reuses `ShadowProjector` results — no new LoS math.
- `height_class → anchor level` mapping is a **new canon value** (§6 Q1).
- `facing_factor`: each cell belongs to a `WallSlice` with a known direction
  (or a Slab top) — faces pointing away from the lamp read darker. Simple two
  ratio vars (lit-side / dark-side), tunable.
- Ambient/directional types contribute a floor intensity to every voxel
  (keeps unlit maps readable; the value is the effective "no lamps" default).

### 3.3 Quantizer

`intensity → bucket 0..5` by thresholds; bucket → modulate luminance by table.
All values `var`, never `const` (Rule 1). Starting proposal (Director tunes
visually in VL-01):

```
BUCKET_LUMINANCE := [0.16, 0.30, 0.45, 0.62, 0.80, 1.00]   # bucket 0..5
```

0.16 keeps facade texture readable under MULTIPLY (canon #2); ratify or retune
against a real capture, not in code review.

### 3.4 Application — unified alternative-tile state space

Alternative tiles encode **(light bucket × ghost ring)** in one scheme:

```
alt_id(ghost g ∈ 0..3, bucket b ∈ 0..5) = g * 6 + (5 − b)
```

- `alt 0` = full-lit, unghosted = today's base tile. Total 24 states/tile.
- **Supersedes `GHOST_ALT_IDS = [1,2,3]`.** One encoder/decoder function
  (single source of truth) used by BOTH occlusion and lighting — the occlusion
  "restore exactly the alternative it had" contract keeps working because
  restore goes through the same encoder.
- Modulate composition per state: `Color(base.rgb × BUCKET_LUMINANCE[b],
  GHOST_ALPHAS[g])` — ghost alpha and light luminance are orthogonal.
- Repaint = `set_cell()` with the same source/atlas and a new alt id. **Never
  re-bake** (B5 intact; per-frame procedural cost stays zero — every variant
  is a load-time modulate, no new textures).
- Destruction interplay: exposed geometry falls back to the generic material
  atlas (B5) — generic sources mint the same 24 states (they already mint
  ghosts today), so newly exposed faces light correctly on the next rebuild.
- **Minting cost is the open risk**: 23 alts × 4608 tiles × 16 pages ≈ 1.7M
  `create_alternative_tile()` calls if minted eagerly (ghosts today: ~220k,
  inside a 1.4s bake). VL-01 measures first; fallback design is lazy minting
  per (page, combo) on first use. Loud-fail if an unminted alt is requested
  (B6 spirit).

### 3.5 Temporal regimes

- **Regime A (loops):** at rebuild time, precompute the light's phase fields
  (ON field, OFF field — canon #5 says two states suffice) and their diff set.
  The `_process` animation (existing `update_temporal_state()`) only swaps
  alternatives for cells in the diff set. Zero per-frame derivation; bounded
  by the lamp's influence set. Runs for as long as the player deliberates.
- **Regime B (consequences):** `set_light_active(id, on, permanent)` API on
  `LightingController` → localized `VoxelLightField` rebuild of that light's
  influence set → immediate repaint. Wired to switches, lamp-shot, and (later)
  moving walls; a blast that destroys a lamp calls the same API. Structure
  changes (moving walls) invalidate occlusion → full `rebuild_all()`.

---

## 4. Phases

### VL-01 — Static projection (first visible light) ✅ LANDED 2026-07-23
Author omni lamps in PLAYGROUND MapSpec · `VoxelLightField` + quantizer +
application on `lighting_rebuilt` · unified alt encoder replacing
`GHOST_ALT_IDS` · `MULTIPLY_LUMA_LIFT` default → 0.0.
**Acceptance — all met:** (1) real captures show the falloff —
`auto_2026-07-23_17-48-29.png` (floor light-pool fading to dark) and
`occ_view_E.png` (pool + lit block faces after rotation); headless field
query confirms a block voxel by lamp 1 = bucket 5, far wood block = bucket 1,
floor 5 near / 1 far. (2) ghost restore round-trip **IDENTICAL** in all four
views (`[OCC-02]` real-map check). (3) perspective rotation coherent —
`occ_view_N/E/S/W.png`. (4) bake **1323 ms** (was 1384 ms baseline; 10 light
alts/tile absorbed with no regression — eager mint is fine, lazy minting NOT
needed). (5) lint 0 real errors; bake_selftest 19/19, roof_bake 8/8,
floor_integration 9/9, roof_integration 5/5.

**Landed tuning (all `var`, Director tunes further from here):**
`bucket_luminance = [0.16, 0.30, 0.45, 0.62, 0.80, 1.00]`,
`ambient_intensity = 0.10`, `facing_dark_ratio = 0.60`,
`vertical_gu_per_storey = 0.5`, `inner_full_ratio = 0.45` (binary-dominant
plateau falloff — full strength out to 45% of radius, then a fast ramp to 0,
per canon #4). OVERHEAD lamps anchor at the **built wall-stack top**
(`get_layer_count()-1`), NOT the 8-storey ceiling-fixture height — the latter
placed lamps so high the vertical falloff zeroed every contribution (the first
bug found and fixed this session).

**Map-source note (load-bearing):** PLAYGROUND loads from
`maps/PLAYGROUND.map.json` via `FileMapSource`, NOT `playground_map.gd` (the
code spec is only a fallback when no file exists — `MapCatalog.get_spec()`
checks the file source first). Lamps therefore live in the JSON's
`legacy_compiler.lights` array (the bridge section `FileMapSource` translates
into the runtime spec). Adding lights to the code spec does nothing.

### VL-02a/b/c — Readability pass ✅ LANDED 2026-07-23

Director feedback on the VL-01 build: overhead fixtures sorted wrong, blast
damage was invisible, and grenades spared the ground.

- **VL-02a — overhead z-order.** Ray shafts sat at `z = 0` and lamp fixtures at
  `WALL_BASE_Z_INDEX + ceil_floors + 1 = 19`, while wall voxels reach
  `10 + level = 33`. Both are DRAWN at `ceiling_lift` (above the stack on
  screen) so walls covered them. Now derived from the built stack like the
  agent's: rays `max+2`, lamps `max+3` — measured **rays=35 lamps=36 vs max
  voxel z=33**. Recomputed per map load (layer count is map-dependent).
- **VL-02b — surface shading (the real fix for invisible craters).** Light
  alone could never show a hole: two voxels centimetres apart get the same lamp
  distance, and the only occlusion available (`ShadowProjector`) is
  GU-resolution — 8×8 voxels. Added per-voxel **axis factors** (top 1.00 /
  SE 0.78 / SW 0.56 / enclosed 0.30, by which neighbour is empty) plus
  **contact AO**. Buckets widened **6 → 12**; six collapsed the new terms into
  their neighbours' bucket. VL-01's border-guess `_facing_factor` was removed —
  it only held for slice-built walls and could not see destruction.
  - *AO subtlety, found and corrected mid-implementation:* counting a voxel's
    OWN lateral neighbours darkens a flush wall exactly as much as a recess
    (a wall voxel already has solid neighbours along its plane). AO must sample
    the geometry ringing the EMPTY cell the face looks out into. Verified on a
    synthetic wall: flush face **0.780**, notch interior **0.566**, flush top
    **1.000**, deep interior **0.300**.
- **VL-02c — the ground takes the blast.** `find_affected_containers()` skipped
  every non-CEILING slab, so floors were pristine; now FLOOR/INTERIOR slabs are
  collected in their own bucket (different vertical ring step — a floor's
  destructible plane is one level, D13). **24 floor slabs** hit with correct
  falloff (ring1 22/64, ring2 11/64, ring3 3/64). Also triggered D18's lazy
  fixed-level reveal for the first time (`render_fixed_earth_level`, whose own
  docstring said "Part 3, not built yet") — without it the crater had no bottom
  and the legacy floor plane showed through as untouched ground.
- Destruction now re-derives the light field, so new cavity walls pick up their
  shading instead of keeping the intact voxels' values.

**Evidence:** lint 0 real errors; blast_calculator 11/11, bake 19/19,
roof_bake 8/8, floor_integration 9/9, roof_integration 5/5; ghost round-trip
IDENTICAL all four views; bake 1386 ms (vs 1323 at 6 buckets — 22 alts/tile
costs ~60 ms).

**Known limitation (honest):** a floor crater reads as SPECKLE, not a bowl.
The blast model removes a deterministic scattered subset of voxels per ring
(hash-and-rank, canon), so the hole has no contiguous volume to shade. Making
craters read as bowls is a DESTRUCTION-model change (contiguous removal), not
a lighting one — flagged for the Director, not silently worked around.

### VL-02d — Tuning + flicker viability probe ✅ 2026-07-24

- **Contrast/brightness tune (Director):** lateral face factors spread wider
  (`face_se 0.78→0.74`, `face_sw 0.56→0.48`) for a stronger 3D read, and the
  scene lifted (`ambient 0.10→0.15`, `bucket_luminance` floor 0.16→0.19 with
  raised mids, top pinned 1.00).
- **Flicker mechanism proven, NOT enabled.** The whole temporal chain already
  existed (`_process → update_temporal_all → rebuild_deferred → lighting_rebuilt
  → repaint`); the one missing link was the field reading
  `LightSource.energy_multiplier` (it consumed only `visual_energy`). Wired that
  (1 line). Verified two ways: a unit probe (a voxel by the lamp toggles bucket
  **11↔2** as `energy_multiplier` goes 1↔0) and a live run (log shows
  `energy 0.0↔1.0` firing rebuilds).
  - **Blocker measured:** each toggle re-derives the WHOLE field — **~675 ms on
    PLAYGROUND**. Fine for a one-off rotation, impossible twice a second. So
    flicker stays OFF in the map until VL-03's incremental repaint (only the
    changed lamp's influence set) lands. The `energy_multiplier` support stays
    in — re-enabling is one `"flicker": true` in the JSON once VL-03 exists.

### VL-03 — Incremental repaint ✅ LANDED 2026-07-26 — flicker ENABLED

The blocker above is closed. A temporal light's toggle now repaints ONLY its
own influence set, never the whole map.

- **`VoxelRenderer._placed_by_gu`**: GU → `[{level, cell}]` for every placed
  voxel, built as a free side-effect of each FULL `apply_light_field()` pass
  (which already visits every cell). `apply_light_field_gus(field, gus)` uses
  it to repaint only the given GUs — skips entirely for a GU with nothing
  placed. Invalidated by `clear()` (rotation/reload); rebuilt by the next full
  pass, which always follows any geometry change.
- **`VoxelLightField.clear_caches()`**: clears only the LAMP-dependent caches
  (`_bucket_cache`, `_lamp_cache`) — NOT `_static_factor_cache` (new: surface ×
  soot × under-structure, per voxel). That split is the real win: those three
  terms never depend on which lights are on, so a toggle reuses them instead of
  re-deriving surface_factor's several occupancy lookups for every voxel in the
  influence set. First cut (bucket-cache-only split) still cost ~84ms/toggle on
  the demo lamp; adding the static-factor split cut it to the number below.
- **`gus_in_light_range(light)`**: every GU within the light's radius (a flat
  2D query — the vertical term in `_lamp_intensity` only ever makes the
  effective distance LARGER, so 2D radius never misses a GU the light could
  reach). `room._update_temporal_lights()` unions this over every light
  `update_temporal_all()` reports changed, then calls
  `apply_light_field_gus()` — replacing the old `rebuild_deferred()` (full).
- **Correctness, not just speed:** confirmed `_rebuild_all_shadows_and_exposure()`
  (tactical shadow/exposure) reads only `light.active`, never
  `energy_multiplier` — a flicker toggle was ALWAYS a no-op for the tactical
  layer, so skipping it loses nothing (canon: visual brightness ≠ tactical
  visibility). The old full-rebuild path was doing genuinely wasted work on
  every flicker tick, not just slow work.
- **Measured** on PLAYGROUND's demo lamp — the worst case tested: radius 7,
  149 GUs, 29,180 voxels, fully overlapping a dense 2-storey wall row:
  **~75 ms/toggle steady-state**, down from ~590–675 ms for the same event
  (~88% reduction). A smaller or more open-area light costs proportionally
  less. Not "microseconds" — flagged honestly, not oversold.
- **Flicker is now ENABLED** in `maps/PLAYGROUND.map.json` (lamp 0,
  `flicker_interval=0.6`) as the landed demonstration.

**Evidence:** new `voxel_light_incremental_selftest.gd`, 5/5 — (1) incremental
toggle buckets match an independent from-scratch rebuild, both directions
(pre-computed by hand: bucket 2 off / 11 on, matched exactly); (2) a GU outside
`gus_in_light_range()` is proven bucket-identical regardless of this light's
state (safe to skip, not just untested); (3) `clear_caches()` leaves
`_occupancy`-derived shading intact (hand-computed 0.480, matched exactly).
Real capture pair (`auto_2026-07-26_11-51-08.png` ON / `auto_2026-07-26_11-50-49.png`
OFF-phase): lamp-region mean brightness 43.1 vs 20.0, delta 23.1, confined to
the lamp's own area — the rest of the scene (lit by other static lamps) is
visually unchanged between the two captures. Full regression green: bake
19/19, blast 14/14, floor_integration 9/9, voxel_persist 2/2; lint clean.

**Unblocks:** VL-D items 4–6 (wood/stone/metal ember→char decay) need exactly
this mechanism — a short-lived, localized per-voxel temporal effect. Their
footprint (the blast's own affected voxels) is typically far smaller than a
room-filling lamp radius, so expect lower cost than the 75ms worst-case above.

### VL-D — Destruction visuals (Director backlog, 2026-07-24)

1. **Soot rings around blast holes ✅ LANDED 2026-07-24 (VL-D1).**
   > **SUPERSEDED 2026-07-30 by `DESTRUCTION_MASTER_PLAN.md` D24.** `Voxel.soot_ring`
   > and `compute_soot_rings()` no longer exist: soot is DERIVED fresh every repaint
   > from which voxels are currently absent (`derive_soot_rings()` writing into a
   > caller-supplied snapshot), never stored on the voxel, and it therefore survives
   > rotation for free — which retires the "known limitation" recorded at the end of
   > this very item. Firearm impacts feed the same mechanism as blasts. The original
   > text is kept below as the record of what shipped first.

   `Voxel.soot_ring` (rides on the voxel, beside `damage_state`) +
   `BlastCalculator.compute_soot_rings()` — a multi-source BFS out of every
   DESTROYED cell tags surviving neighbours ring 0/1/2 (min wins). The field
   multiplies the light term by `soot_darkening = [0.10, 0.28, 0.55]`, and the
   two darkest buckets (0.07, 0.13) are reserved for it so scorch reaches near
   black without touching the approved light range (ambient still bucket 2 =
   0.33). Detonate collects the holes + affected voxels and re-derives the
   field in the same pass it already runs. Walls AND floor rim both scorch.
   - *Evidence:* `auto_2026-07-24_18-23-18.png` (blast zone reads as a burned
     halo); blast_calculator_selftest 13/13 (2 new soot tests: rings spread by
     distance, min-ring-wins between two holes); lint clean.
   - *Known limitation (inherited, not introduced):* soot dies on perspective
     rotation — but so does ALL destruction, because `build_from_layout()`
     rebuilds the registries (and thus every Voxel) from the MapSpec on each
     rotation. `damage_state` and `soot_ring` share that fate exactly. Fixing
     it is a destruction-persistence task (rotate/replay damage), out of scope
     for the soot work.
   - *Texture note:* with the current scattered hash-ranked destruction, many
     small holes' halos merge into one burned patch rather than crisp per-hole
     rings — will read as distinct rings once item 2 (contiguous crater) lands.
2. **Deeper crater ✅ LANDED 2026-07-24 (VL-D2).** The floor no longer uses the
   ring/hash-rank scatter (which stippled ~half a GU away with no shape); it's
   carved RADIALLY from the grenade epicentre by `BlastCalculator.
   apply_crater_damage()` — a solid core out to `core_radius`, a crumbling rim
   (deterministic FNV threshold falling to 0) out to `max_radius`, nothing
   beyond. Radii derive from the bomb's range: `max = n_rings × 8 × 0.55`,
   `core = max × 0.4` (frag → core 7, max 17.6 voxels). Epicentre = centre voxel
   of the source GU, fed identically to every affected floor slab so the disc is
   contiguous across GU borders. Walls/roofs keep the ring model (their holes
   read against the wall silhouette). Verified: centre GU 51/64 destroyed
   falling radially to 36 → 12 → 5 → 0 (was a flat ~32 scattered). Soot rings
   now halo one contiguous hole instead of merging into stipple.
   - *Evidence:* `auto_2026-07-24_19-31-45.png`; blast_calculator_selftest 14/14
     (new: core solid / rim ragged / beyond intact); lint clean.
   - *Open polish (Director's call):* the revealed crater floor and the soot are
     both dark, so bowl-depth and scorch can blend. Distinguishing them wants
     either a lighter revealed-substrate colour or stronger cavity AO on the
     revealed level — a tuning pass, flagged not silently taken.
3. **Under-wall floor darkening ✅ LANDED 2026-07-24 (VL-D3).** Took the
   Director's cleaner idea: darken the floor that was under structure, so
   exposure reveals the difference naturally. `VoxelRenderer.
   columns_with_structure()` returns every column with a wall/block/roof voxel
   (positive levels); `room._under_structure` is computed from it after each
   build FROM THE INTACT geometry (before reapply_damage), so it reflects the
   ORIGINAL cover and survives detonation + rotation (recomputed per build).
   `VoxelLightField` multiplies floor voxels (level<0) in those columns by
   `under_structure_factor = 0.68`. When a blast opens a wall base, the exposed
   floor beneath reads darker than always-open floor — the skirting line now
   reads coherent.
   - *Evidence:* unit probe (exposed floor bucket 11 → 7 under structure); A/B
     capture with a grenade at the concrete base — 501 px darkened along the
     exposed under-wall floor, mean −14; bake 19/19, blast 14/14, floor 9/9,
     persist 2/2; lint clean. All `var`, tunable.
4. **Wood ✅ LANDED 2026-07-26 (VL-D4).** Two independent mechanisms:
   - **Directional destruction bias** (general-purpose, not wood-only —
     wood is just where destroy_factor=0.9 makes it read strongest).
     `BlastCalculator._select_deterministic()` gained an optional
     `bias_epicenter` (voxel-space; `NO_EPICENTER_BIAS` sentinel = the
     original pure-hash path, byte-identical for every existing caller/test).
     When set, candidates within a ring group are ranked by distance to the
     epicenter FIRST (hash only as a tie-break among equidistant voxels) — so
     a slice's lateral span skews destruction toward whichever end is nearer
     the blast, instead of scattering uniformly. `apply_container_damage()`
     passes it through for both DESTROY and CRACK selection; `test_zone_
     controller` feeds the SAME epicenter already used for the floor crater
     (VL-D2), so walls/roofs/floor agree on one point. 2D-only by design (x/y
     of `grid_pos`, ignoring level) — vertical falloff is already the ring
     system's own job; mixing it in here would double-count height as facing.
     *Caveat found and documented, not hidden:* for a THIN wall edge, the
     inner/outer slice pair is only ~1 voxel apart — at real epicenter
     distances that's negligible, so the bias is most visible on solid
     blocks / long runs (a slice's own 8-wide lateral span) rather than
     making paired thin slices visibly diverge.
   - **Ember → char glow** (`EmberOverlay`, `godot/scripts/overlays/
     ember_overlay.gd`): a screen-space, purely-visual glow (O1 precedent —
     "occlusion is VIEW not STATE"; not gameplay state, doesn't survive
     rotation/reload by design, cleared alongside `_agent_trail` on both).
     Why an overlay and not the light-bucket tile system: a bucket
     alternative's modulate is SHARED by every voxel placed at that
     `(source, atlas_coords, alt_id)` — the exact sharing that makes VL-01/
     VL-03 cheap — so it structurally cannot carry one voxel's own
     independent, time-varying colour. `VoxelRenderer.voxel_world_position()`
     (new, analytic — reuses the real `TileMapLayer.position +
     map_to_local()`, no empirical offset) gives the overlay a draw point.
     Seeded from wood-material ring-0 (`soot_ring == 0`) survivors right
     after `compute_soot_rings()` in the detonate flow: `ADD`-blended circle,
     `glow_duration=3.0s`, eased fade (`pow(1-t, 1.6)`). The tile underneath
     is ALREADY in its final charred state from VL-D1's soot the instant the
     blast lands — the glow just obscures it briefly, so "cooling" is really
     "revealing," not a second darkening pass.
   - *Evidence:* new `blast_calculator_selftest` cases 13–14 (bias prefers the
     epicenter-facing side; the `NO_EPICENTER_BIAS` sentinel path is
     byte-identical to omitting the argument) — blast suite 16/16. Real
     capture pair via the generalized `test_zone_detonate` dev hook (now
     accepts `INFILTRAITOR_CAPTURE_DETONATE_INDEX` to target any of the 4
     test-zone grenades, reusing that grenade's own cell for camera framing
     instead of the fixed row-centre, which put wood off-screen):
     `auto_2026-07-26_13-27-43.png` (~0.75s post-blast — vivid glow across the
     hit face) vs `auto_2026-07-26_13-28-42.png` (~2.6s post-blast — glow
     essentially gone, revealing the charred, ragged wood silhouette
     underneath). Full regression green: bake 19/19, blast 16/16,
     floor_integration 9/9, roof_bake 8/8, voxel_persist 2/2, voxel_light_
     incremental 5/5; lint clean.
5. **Stone ✅ LANDED 2026-07-26 (VL-D5) — turned out to already be built.**
   The Director's ask ("barely changes, but we want soot too") was checked
   against the EXISTING material-agnostic VL-D1 soot system before writing
   anything new — `compute_soot_rings()` never reads material, so stone was
   already receiving real soot rings from every blast, with no code change
   required. Verified two ways: (1) a bucket-math probe under full light —
   ring 0/1/2 pull a voxel from bucket 11 down to 2/4/7 (a real, strong
   relative darkening: 67%/53%/31% less bright before this session's tuning);
   (2) a real detonation's soot histogram — **1134 stone voxels** tagged
   across rings 0-2 from one blast (438/373/323). Destruction stayed
   appropriately minimal (~15-16% of any one face, `destroy_factor=0.3`),
   matching "quase não muda."
   - *Visibility finding, reported not silently patched:* the wall-face soot
     is mathematically strong but hard to SEE on stone specifically — its
     texture is dark and highly detailed to begin with, and the specific
     faces captured were already dim from axis/AO shading before soot even
     applied, so the multiplicative darkening compounds onto an
     already-low base. The floor crater + floor soot stain (same mechanism,
     lighter earth material) reads as the dominant "an explosion happened
     here" signal in every capture, walls included. Director's call, given
     this: no per-material soot system — instead ease the GLOBAL
     `soot_darkening` a little further in the same direction VL-D2 already
     moved it (Director: "menos escura, deixa ver a textura"):
     `[0.16, 0.36, 0.60] → [0.20, 0.40, 0.63]`. Confirms this arc's running
     theme — most of the "material-specific" backlog items are really the
     EXISTING general machinery, checked and reported rather than
     reimplemented.
6. **Metal (deferred, not started):** cannot shatter into removed voxels —
   model as **denting/warping** (some zones sink) + soot; ember flash faster
   than wood and cool faster. Can reuse VL-D4's `EmberOverlay` directly (same
   glow-then-reveal mechanism, different duration/colour) — no new visual
   plumbing expected. The denting/warping GEOMETRY is the one open question
   this arc didn't answer (wood/stone destroy into holes; metal is asked to
   deform in place instead) — needs its own design pass before implementation.

---

### FACE-READ-01 — Per-face voxel shading ✅ LANDED 2026-07-31

**Director:** *"Eu queria garantir que nunca as três faces de um voxel vão ter
exatamente a mesma aparência [...] isso faz com que fique completamente
explícita a arquitetura do game, cada dimensão fica totalmente visível."*
Runs of voxels were fusing into flat blobs because a voxel had at most TWO
tones (top, and both sides sharing one).

**Shipped:** `godot/shaders/voxel_face_shading.gdshader`, one shared
`ShaderMaterial` on every voxel `TileMapLayer`. It derives the atom-local pixel
as `mod(UV / TEXTURE_PIXEL_SIZE, atom_size)` — valid because BOTH tile paths lay
atoms on an exact 32×36 grid aligned to the texture origin (per-material sources
are a single 32×36 texture with one tile at (0,0); `register_baked_atlas_page()`
sets `texture_region_size = (32, 36)`, zero margins, zero separation) — then
classifies top / SE / SW from the atom's canon geometry and multiplies the
colour. Because it multiplies, the light bucket, the soot term and every tile
modulate survive untouched underneath. Values deliberately tiny (1.00 / 0.975 /
0.945): *"o grande segredo é só diferenciar as 3 faces de cada voxel."*

**Why a shader and not art** — measured, not assumed: the same idea expressed in
`generate_voxel.py`'s atom art moved **0.25%** of a real capture, because the
atom art only ever reaches voxels that bypass the baked lookup (impact marks and
D25 carved half-voxels); every photographically baked wall takes its pixels from
a facade page. The shader moved **60.8%**. Only the shader covers both paths, and
it needs no re-bake.

**Rejected: per-voxel brightness jitter** (`VoxelLightField.micro_jitter_buckets`,
kept in code at 0 with its measurements attached). Stepping the quantised bucket
index cannot be "micro" in shadow, because `bucket_luminance` is compressed at
its dark end — 0.12 → 0.20 → 0.33 is +67%, +65% per step against +8% at the top.
Measured relative impact, stratified by brightness band: jitter 6.7% (darkest) →
4.1% (brightest), i.e. strongest exactly where the Director reported it reading
as noise; the shader, being multiplicative, is perceptually flat at 1.6% → 3.3%.
A second measurement killed an earlier variant: jittering SOOTED voxels erased
the crater rings outright (mean luminance 41.1 → 26.6, mid-tone band 9% → 0% of
pixels), because soot lives in the same 12-bucket channel and only spans buckets
0-2. **Soot and micro-variation compete for one quantised channel, and the
gradient has to win.**

**Process note worth keeping:** an intermediate capture was reported to the
Director as a UV-mapping bug and the shader was reverted on that basis. It was
not a bug — a debug build writing the atom-local coordinate out as a red/green
gradient (`auto_2026-07-31_22-57-30.png`) showed it restarting exactly once per
atom on both paths. The mapping had been correct all along; the values were
simply far too strong to read as shading. The genuinely wrong formula,
`fract(UV) * atom_size`, stays recorded in the shader header as the rejected
alternative. Cost of the error: one revert plus one re-land.

---

### FACE-READ-02 — The separation is now GUARANTEED, not proportional ✅ LANDED 2026-08-01

**Director:** *"vamos forçar a fuligem de destruição e tiros a seguir o mesmo
princípio de nunca deixar um voxel existir com as 3 faces totalmente iguais. Não
precisa ter quase nada de diferença, mas garantir que as 3 faces tem uma micro
diferença."*

**The defect FACE-READ-01 still had, measured before touching anything.** Its
face factors are MULTIPLIES, so their effect shrinks with the pixel value and
disappears entirely into 8-bit quantisation — exactly where soot lives. Scanned
over the real canon grid (`VoxelRenderer.bucket_luminance` ×
`VoxelLightField.soot_darkening` × `FLOOR_DEPTH_DIM`, art pixel 4..255):

| | collapsed to <3 distinct face values | brightest top face still collapsing |
|---|---|---|
| before | **63.0%** of combinations | **38/255** — a clearly visible mid-tone |
| after | 4.7% | 2/255 — black on screen |

The reported case, a ring-0 sooted voxel in the darkest light bucket, rendered
literally **`[4, 4, 4]`** — three identical faces, the precise state this shader
exists to prevent. It now renders `[4, 3, 2]`.

**Shipped:** `face_min_sep` (default `1.0/255`), an ABSOLUTE offset subtracted
per face index (top 0, SE 1, SW 2) alongside the existing multiplies. Deliberately
an offset and not a steeper multiply: a multiply large enough to survive at 4/255
would read as noise at 200/255 — the same failure the retired bucket-jitter
experiment hit, so the lesson above is what chose this shape. Blast soot and
firearm soot share one mechanism (D24), so both are covered with no separate path.

**The guarantee is bounded, and stated rather than overclaimed:** three distinct
faces wherever a voxel renders above 2/255. Below that it is black and nothing is
distinguishable anyway.

**Evidence.** `voxel_face_separation_selftest.gd` (new) reads the canon values
from their real owners and PARSES the shader's constants out of the `.gdshader`
rather than copying them, so retuning either side fails the test instead of
drifting; it carries its own teeth-check (`face_min_sep = 0` must collapse
43727/60480 with worst visible 38/255, so test 1 can never pass vacuously). Real
pixels, against a measured noise floor — two captures of the same build differ on
13.3% of pixels from the ember/flicker tweens but contain **zero** pixels at
delta −1 or −2, while before→after contains **375 641 px at exactly −1 and
142 215 px at exactly −2** (the SE and SW faces, 56% of the frame) with the same
temporal tail. Scene brightness is unmoved (sooted-region mean 32.7 → 32.6).
Captures `auto_2026-08-01_01-05-08.png` (before) and `auto_2026-08-01_01-16-47.png`
(after).

**Not this, and still open:** per-face soot *content* — different soot amounts on
different faces — remains the unspiked R/G/B-channel mechanism described under
"OPEN — Per-FACE soot and light" below. This guarantees the three faces stay
distinct under soot; it does not make soot itself directional.

---

### 🔖 OPEN — Per-FACE soot and light (Director, 2026-07-31)

Asked directly at session close: *"então agora a fuligem pode ser aplicada por
face?"* **Not yet, and the blocker is identified.** The shader differentiates
faces by a GLOBAL uniform; soot needs per-CELL, per-FACE data, and the only
per-cell channel today is `TileData.modulate`, delivered through a pre-minted
alternative and carrying ONE scalar replicated across R/G/B
(`_ensure_light_alt`: `Color(base.r * lum, base.g * lum, base.b * lum, base.a)`).

**The mechanism that would work, unspiked:** those three channels are the wasted
capacity. Encode top/SE/SW brightness in R/G/B, and have the shader pick ONE
channel and apply it to all of RGB — so the modulate never tints, it stays a
grayscale multiply, just chosen per face:

```glsl
vec4 tex = texture(TEXTURE, UV);
float f = (diamond <= 1.0) ? MODULATE.r : (local.x >= half ? MODULATE.g : MODULATE.b);
COLOR = vec4(tex.rgb * f, tex.a * MODULATE.a);
```

This would serve LIGHT per face as well as soot — the face turned toward a lamp
reading brighter, which is the Director's original framing.

**Costs to weigh before building it:** (a) the alternative-id space multiplies —
today 12 buckets × 2 flips ≈ 24 ids; per-face soot patterns push it to roughly
384–1536 possible, mitigated but not eliminated by the existing LAZY minting
(`_ensure_light_alt` only creates what is actually placed, and most of a map is
unsooted); (b) it **redefines what `modulate` means** in §3.4's unified
alternative-tile state space, from "one light bucket per cell" to "three per-face
brightnesses" — a canon change, not an implementation detail. Director's call at
session close: **spike and measure before committing to it.**

---

## Session close (2026-07-26) — "Alpha Temporal Light Foundation"

VL-01 through VL-D5 close here as one coherent arc: voxel face lighting
(brightness buckets, GU-resolution occlusion reuse) → destruction visuals
(soot, crater, directional bias, under-wall darkening, ember→char) →
persistence through rotation → the incremental-repaint mechanism that makes
temporal effects (flicker, ember) affordable → the rotation-performance
investigation that fell out of chasing that same cost. Item 6 (metal) is the
only explicitly deferred piece; the 4-view prebuild optimization is
deliberately deferred to the project's finishing pass (see VL-PERF above).
Full evidence trail for every landed item is inline above, in commit order;
nothing here is asserted without a real capture, probe, or selftest cited
next to it.

### VL-PERF — Rotation performance (Director flagged, 2026-07-24)

Rotation felt far too slow (~5.7s off-screen throttled — worse on mobile). Full
profile of one rotation:

| Stage | Before | After VL-PERF |
|---|---|---|
| layout_with_perspective | 1ms | 1ms |
| build: floor slabs | 112ms | 112ms |
| build: border fixed levels (dev scaffold) | 92ms | 92ms |
| build: slice+junction gen | 46ms | 46ms |
| build: **bake (compositor ~100ms + tile registration ~730ms)** | ~830ms | ~830ms |
| build: render walls | 372ms | 372ms |
| lighting: tactical (shadow+exposure) | 4ms | 4ms |
| lighting: **light-field repaint** | ~675ms | **~590ms** |
| lighting: overlays | ~270ms | ~270ms |
| **minting light alternatives (VL-01 eager)** | **~3000ms** | **~0 (lazy)** |

**Landed optimizations:**
1. **Lazy alt minting** (VL-03-PERF, committed 0.9.74): −3000ms. Was over half
   the rotation — VL-01 eager-minted 22 alternatives on all 13k tiles.
2. **Lamp-term cache per (GU, level)**: −220ms. The lamp falloff is a
   GU-resolution quantity; all 64 voxels of a column share it. Was recomputed
   (sqrt per light) 108k× when ~5k distinct pairs exist.
3. **surface_factor level-set hoist**: −110ms. Fetched each level's occupancy
   set once instead of ~9× per voxel.

Net: rotation ~5.7s → ~2.0s off-screen (proportionally faster with focus).
Light-field repaint down from ~675ms to ~590ms; ghost round-trip still
IDENTICAL, lighting visually unchanged, bake 19/19 + blast 14/14.

**Bake source cache (VL-PERF-BAKE, Director-approved 2026-07-24): −~730ms.**
The baked pages/tiles depend only on the (material, facade) combos present, not
on the view — a rotation produces byte-identical sources. Cache `baked_atlas` +
`source_ids` keyed by `(map_id, blend_mode, sorted combo set)`; on a matching
rotation, skip prune + compositor bake + ~9k `create_tile`, and rebuild only the
cheap `BakedTileLookup` from the rotated runs (`_wire_baked_lookup`). Full
rebake on map (re)load (`invalidate_bake_cache()` — a reload may intend to pick
up changed facades), blend-mode change, or a new combo. Verified: bake 19/19,
blast 14/14, roof_bake 8/8, ghost round-trip IDENTICAL all views, detonation +
crater + soot render correctly through a cached-rotation build.

**Rotation journey: ~5.7s → ~1.15s off-screen throttled** (−80%):
lazy minting −3.0s, bake cache −0.73s, lamp cache −0.22s, surface_factor
−0.11s. Proportionally faster with window focus (likely ~0.6–0.8s). Remaining
cost is base geometry gen + render + the lighting re-derive.

**Destruction persistence through rotation** — being done now as "light
persistence" (VL-PERSIST, below).

### 🔖 DEFERRED to final optimization pass — Prebuild 4 views (Director, 2026-07-24)

Instant rotation via prebuilding all 4 perspectives at load and toggling
visibility. **Explicitly deferred to the game's finishing/optimization stage**,
NOT now. Rationale (Director-ratified): prebuilding turns "1 world state → 1
render" into "1 world state → 4 synchronized renders", a permanent sync tax on
every future world-mutation feature (moving walls, light puzzles, fire/smoke,
rubble, breach-as-clue…). The destruction system is still immature, so freezing
the render architecture around 4 views now is premature. Rotation at ~1s is
good enough for development. Revisit when world mechanics are mature AND
instant rotation proves a real gameplay need. The VL-PERSIST base-coord damage
registry (now) is the shared prerequisite — prebuild would swap "re-apply on
rebuild" for "apply to all 4 copies", no rework of the registry itself.
Cost estimate when taken: ~1.6s extra load (4 views share one cached bake),
~7MB extra tilemap memory.

### VL-PERSIST — Light destruction persistence through rotation ✅ LANDED 2026-07-24

Destruction now survives perspective rotation, without prebuilding views.

- **Authoritative registry in BASE (N-frame) voxel coords**: `room._base_damage`
  / `_base_soot` keyed `Vector3i(base_vx, base_vy, level)`. A blast records every
  affected voxel's `damage_state` + `soot_ring`, converting the view coord to
  base via `PerspectiveMapper.cell_to_base(pos, active_view, base_size × 8)`.
- **Key insight**: a voxel's perspective rotation is the SAME 90° rotation as
  its GU, at 8× resolution — the mapper works directly at voxel scale, no new
  math. Proven by `voxel_persist_selftest.gd` (round-trip exact all dirs; all 64
  voxels of a GU land inside the rotated GU).
- **Re-apply after rotation** (`_reapply_base_damage`, in `_set_perspective`
  before the lighting rebuild): index the freshly rebuilt voxels by
  (grid_pos, level), convert each base key to the current view, stamp
  `set_damage` + `soot_ring`, re-reveal the crater floor under destroyed floor
  voxels, `process_dirty`. Then the light repaint sees the holes.
- Cleared on map load. The 4-view prebuild (deferred) will reuse this same
  registry, applying it to all 4 copies instead of re-applying on rebuild.

**Evidence:** detonate-on-N then rotate → **510/510 damaged voxels + 2180 soot
re-applied in every view** (E/S/W); `occ_view_E` shows the crater/holes/soot
in the rotated frame; voxel_persist_selftest 2/2; blast 14/14, bake 19/19,
floor_integration 9/9; lint clean. New dev hook
`INFILTRAITOR_CAPTURE_DETONATE_FIRST=1` (with CAPTURE_VIEWS) for regression.

### VL-02 — Gameplay consequences (Regime B) status note

### VL-02 — Gameplay consequences (Regime B)
`set_light_active()` + localized rebuild/repaint · permanent-off state
(persists across rebuilds) · TEST-ZONE trigger to toggle a lamp (context-menu
family, like the grenade trigger).
**Acceptance:** (1) toggle repaints only the influence set, same TIC; (2)
permanent-off survives perspective rotation and full rebuilds; (3) real
capture pair ON/OFF; (4) lint + suite green.

### VL-03 — Looping lights (Regime A)
Phase-field precompute + diff-set swap in `_process` · one flickering corridor
lamp authored in PLAYGROUND as the demo.
**Acceptance:** (1) flicker animates continuously while idle, stops costing
anything when out of influence; (2) frame cost of a swap measured (report
number); (3) TIC actions during flicker land on a coherent state; (4) lint +
suite green.

### VL-04 — Plumbing & hardening
`VoxelLightField` query API documented for vision modes (thermal/night/X-ray
consume the field, not tilemaps) · selftest for encoder round-trip, quantizer
thresholds, field determinism · docs cross-links (this plan ↔
LIGHT_MASTER_PLAN ↔ BAKE_SYSTEM_REFERENCE).
**Acceptance:** (1) selftest green headless; (2) docs updated; (3) no vision
mode implemented (explicit non-goal).

---

## 5. Non-Goals (v1)

- Additive multi-lamp blending (canon #4 — max() wins).
- Colored light (buckets scale luminance only; grayscale discipline B2 holds).
- Per-pixel shading/shaders — quantized per-voxel modulate only.
- Vision modes themselves (VL-04 leaves the seam, nothing more).
- Tactical semantics changes — detection math untouched.

## 6. Canon Questions — RESOLVED (Director, 2026-07-23)

- **Q1 ✅** `height_class → anchor voxel level`: FLOOR=0, LOW_COVER=2, HUMAN=4,
  TALL_STRUCTURE=6; OVERHEAD → top of the **built wall stack**
  (`get_layer_count()-1`), corrected from "ceiling fixture height" during
  implementation (see VL-01 note).
- **Q2 ✅** `bucket_luminance = [0.16, 0.30, 0.45, 0.62, 0.80, 1.00]` — landed;
  still a `var`, retune from captures.
- **Q3 ✅** facing factor kept, `facing_dark_ratio = 0.60`.
