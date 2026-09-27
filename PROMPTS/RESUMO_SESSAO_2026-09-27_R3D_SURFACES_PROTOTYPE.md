# Session 2026-09-27 (afternoon/evening) — R3D-LIGHT's last open items closed; R3D-SURFACES prototype built end to end

Full record: `RENDER3D_MASTER_PLAN` v1.34-v1.38 blocks (the R3D-SURFACES design block, `## 4.` area).
Commits `cd5a0f58` .. `dfd9debf`.

## R3D-LIGHT — the two remaining open items, closed (`cd5a0f58`)

- **Fixed the pre-existing bug** (26 `'has' ... TypedArray of String` errors after `shoot 0` behind two
  grenades): `PredictionReaper.retire()` assumed every dictionary it drains has string keys (the cook's
  `s` state); `VoxelLightField` also retires `_occupancy`, keyed by LEVEL (int). One-line type guard in
  `prediction_reaper.gd:56`. Reproduced red (26 errors) then green (0) on the real scenario; `verify.py
  smoke` PASSED.
- **PACKAGE/FLOORS profiled inside** (desktop clocks, added then removed): FLOORS is dominated by
  `simulate_crater_damage` itself; PACKAGE's cost is the per-key walk, not its smoke/debris/resolve calls.
  Confirms the existing note rather than finding a new cut.
- **Left alone on purpose:** the Moto's COMMIT-frame persistence (~37 ms) — already inside the 100 ms
  criterion, Director's call not to spend the architectural surface fixing a number that already passes.

## R3D-SURFACES — the plan's own "first prototype" built and closed (`daffb6b9` .. `dfd9debf`)

The plan's design (photographic top-face plane + macro modulation + patch decals, `RENDER3D_MASTER_PLAN`
§ R3D-SURFACES) was PLANNED, not started, at session start. All three prototype pieces are now built,
measured on the Moto (`ZF524T5TG5`, connected this session), and all four organic-ground materials carry
real CC0 art.

### Mechanism (`daffb6b9`)
- `board3d_live.gd`'s `OPAQUE_SHADER`: a `has_surface`/`surface_tex` branch samples a REPEAT world-space
  plane on the top face when `has_facade == false` (organic ground), replacing the flat `base_color`.
- `_make_material()` resolves `slab_<id>` through the existing `TextureResolver` chain when `facade_<id>`
  doesn't resolve — inherits the `user://textures/` per-player override for free (confirmed live on the
  Moto's own log).
- `check_surface.py` built: dimensions, rejects alpha, border-match for REPEAT, imported. Run against the
  8 pre-existing `slab_<id>.png`: all PASS, but for the 4 organic ones the PASS is coincidental — MIRROR art
  matches its outer edge by construction while hiding the real seam at the image centre, which a
  border-only check can't see.

### Three unknowns measured before building further (Moto-connected this session)
1. Organic ground today draws flat colour (confirmed reading the shader).
2. A 1024² plane is ~3 MB VRAM under this project's Lossless import convention, not the 1-2 MB the plan
   estimated for ASTC. **Director's ruling: keep Lossless, cap at 8 photographic planes per map (~24 MB)**
   — sized against the Moto's already-measured GL mtrack (271-311 MB whole-game).
3. The macro sample's GPU cost, isolated by a throwaway shader ablation (measured, then reverted): +0.4-0.5
   ms steady-state idle GPU, same order as the R3D-LIGHT GPU floor's individual-fetch costs.

### Real art sourced (all ambientCG, CC0/public domain, no attribution required — D57)
- **grass** = "Grass001" (border diff 7.9/7.7)
- **dirt** = "Ground104" (10.5/10.1)
- **gravel** = "Ground110" (14.9/15.4 — closest to the 18 tolerance of the four)
- **sand** = "Ground080" (3.9/4.0 — best margin)

All replace the retired MIRROR-bake placeholders; all `check_surface.py` PASS on REAL edge continuity, not
the old files' coincidental 0.0. `gravel` has no placement in any existing map, so it's resolver-confirmed
only, not visually captured in-scene. Art itself is local-only: `ASSETS/materials/*/*.png` is gitignored by
design (Director's call, unchanged from before this session) — each folder's `SOURCES.md` (also local)
records what changed and where from.

### World-space period — RESOLVED, not left open
The shipped `v_world.xz / 8.0` is the literal 1:1 mapping to the plan's own authored spec (8×8 GU at
`TEX_AUTHORING_N`), no fudge factor. Tried rescaling it anyway (physically-literal `/ 1.6` for 1 GU = 1.6 m,
then `/ 2.0` and `/ 4.0`): all three washed out under `filter_linear_mipmap` at the same camera framing — a
filtering artifact from a smaller period's steeper per-pixel UV gradient, not evidence the period was wrong.
**Director's ruling: no artificial rescale in the shader — the system's whole point is swappable art
(`TextureResolver`'s `user://` tier) with zero code change, so the code stays at the plain default and a
better-framed CC0 photo (not this session's close-up sources) will read at correct scale through the same
`/ 8.0`.** The oversized blades on screen right now are a known placeholder-art property, not an open
engine defect.

### Macro modulation map (`410981d8`)
`TextureResolver` only recognised `facade_`/`slice_`/`fracture_`/`slab_` prefixes — an unrecognised one
fails closed with a WARN (`_validate_dimensions`'s own documented contract). Taught it a `macro_` category
(256×256, colour allowed like `slab_`). `ASSETS/materials/_generic/macro_ground.png`: synthetic (generated,
not photographed — no CC0 question, it depicts nothing), a blurred value-noise field decoded as three
near-1.0 RGB multipliers, sampled at a 61 GU period so it never repeats within any authored map.
`texture_resolver_selftest.gd` still PASSES.

### Leaf-patch decal (`410981d8`)
Rides `FloorPile3D` exactly as the plan said to ("the existing decal path") — the same class the
glass-shard piles already use. Its hardcoded shard half-size was parameterised (`half_px`, default
unchanged) so a GU-sized patch (`16.0`, no shard overlap) can share the class without a new renderer.
`VoxelBoard.set_patch_board3d()`/`place_patch_demo()`: a deliberately minimal DEV-ONLY seam
(`Room`'s `SURFACE_PATCH_DEMO` flag places one fixed decal after board build) — no map-data schema for real
per-GU patches, which is real follow-on scope. Art: ambientCG "Leaf001" (CC0), Color+Opacity composited
into one 256×256 RGBA.

### Measured on the Moto throughout
Every piece (surface plane alone, +macro, +leaf decal, then all four re-sourced materials together) was
exported, installed and run on the connected Moto g04s (`FLOOR_ZONES_TEST`, `FRAME_PROBE`): resolver
confirms each texture resolved, zero errors in every run, GPU steady in the 22-23.5 ms range throughout —
the macro sample and the one decal add nothing measurable at this scale. `verify.py smoke` PASSED after
every code-touching step (lint, invariants, codemap, 51/51 selftests, PLAYGROUND+GLASS boot).

## What is still open (real follow-on scope, not this prototype's)
- A real map-data schema for per-GU patch placement (today: one fixed dev-only cell).
- A better-framed `slab_grass.png` (and equivalent) at the right real-world distance — swap-only, no code
  change needed, per the period ruling above.
- `dirt`/`gravel`/`sand` art trusted at more than the map footprint actually tested (4×4 GU patches).
- R3D-SURFACES itself continues as a track alongside R3D-PROPS and R3D-ACTORS; none of the three is a R3D
  blocker (R3D already closed at R3D-LIGHT, 2026-09-27 morning).
