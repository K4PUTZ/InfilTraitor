# INFILTRAITOR — Voxel Light Projection Master Plan

> **Status:** 🟡 DRAFT — canon below ratified by the Director 2026-07-23;
> architecture decisions surfaced here await ratification before VL-01 starts.
> **Authored:** 2026-07-23 (solo mode).
> **Prerequisite for:** resuming `DESTRUCTION_MASTER_PLAN.md` (paused 2026-07-22
> precisely because destruction is invisible while every voxel renders fully lit).

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

### VL-D — Destruction visuals (Director backlog, 2026-07-24)

1. **Soot rings around blast holes ✅ LANDED 2026-07-24 (VL-D1).**
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
3. **Under-wall floor darkening.** Floor-slab voxels whose top was covered by a
   wall should read darker when the wall above is blown open — either shade the
   newly-exposed top at damage time, OR (Director's cleaner idea) **darken at
   load** every slab voxel that has any wall voxel above it, so exposure
   naturally reveals the pre-shaded surface. The floor↔wall skirting line is
   where lighting coherence is judged.
4. **Wood:** accentuate destruction on the grenade-facing side; ember animation
   at blast → darken over a few seconds.
5. **Stone:** barely changes, but still wants soot to show a blast happened.
6. **Metal:** cannot shatter into removed voxels — model as **denting/warping**
   (some zones sink) + soot; ember flash faster than wood and cool faster.

Notes: items 4–6 imply a per-voxel **temporal darkening** channel (ember→char)
distinct from the light bucket — likely a second modulate/alt dimension or a
short-lived overlay. Ember animation shares the Regime-A cost concern (VL-03).

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
