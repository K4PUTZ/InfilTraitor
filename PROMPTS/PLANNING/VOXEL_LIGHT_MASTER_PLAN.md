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
