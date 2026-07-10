# INFILTRAITOR — Bake System Reference

**Extracted 2026-07-08 from `tools/persistent/OPERATOR_CONTEXT.md`** (v0.5.0
context restructure). This document holds the full bake-pipeline architecture,
module checklist, file locations, closure evidence, and process learnings.
The compact canon (invariants B1–B6, the placement seam, the config default)
stays in `OPERATOR_CONTEXT.md`; consult this document on demand before
modifying the bake system.

---

## Overview

The baking system composites per-wall facade textures (marble, wood grain,
etc.) with material base colors at map load, producing baked
TileSetAtlasSource(s). The system is **transparent to placement logic** —
integration point is a single-call lookup (BakedTileLookup.resolve).
Implementation uses a **master-strip approach**: edges are grouped into runs
(contiguous walls) for facade continuity; the FacadeSampler addresses an
infinite mirrored facade plane using FNV-1a deterministic window origins; the
BakeCompositor multiplies material RGB × facade luminance in a single GPU
batch.

## Architecture (BAKE-FIX-01/02/03)

**Phase 1 — Master-Strip Baking** (BAKE-FIX-01):
- `TextureResolver`: Facade acquisition with user:// → default:// → material-only fallback
- `FacadeSampler`: Infinite plane addressing with mirrored-repeat and run-aware window origins
- `BakeCompositor`: Single-pass GPU batch composite; blend mode is
  configurable via `BakeConfig.blend_mode` (BAKE-LIVE-VERIFY-02, see below) —
  `MULTIPLY` / `TEXTURE_ONLY` / `MATERIAL_ONLY` / `OVERLAY_EXPERIMENTAL` /
  `LINEAR_LIGHT`, selected by `_apply_blend()`
- `MaterialRegistry`: Base color + pattern algorithms (K=4 variants per material)
- `BakedTileLookup`: Placement-time lookup seam (only module live code touches)
- `BakeConfig`: Master enable/disable toggle (default: false)

**Phase 2 — Junction Columns** (BAKE-FIX-02):
- `JunctionResolver`: Multi-edge wall detection + junction column data structure
- `VoxelRenderer._render_junction_column()`: Mirror-at-column silhouette rendering
- Junction column material overrides: `facade_enabled` flag + `override_material` for custom rendering
- Run grouping: Edges marked `.in_run` for continuity; isolated edges randomize via FNV-1a

**Phase 3 — Validation** (BAKE-FIX-03):
- Infrastructure validation: 5/5 tests verify both rendering paths exist and toggle correctly
- Smoke test: 3/3 tests verify BakeConfig persists across render cycles
- B3 closure: Baked wall shape is pixel-identical to generic wall (alpha from canonical material)

## Module Checklist

- [x] **TextureResolver**: user:// → default:// → material-only fallback chain
  * Validates: grayscale, dimensions (64N×32N for facades), file size cap (10 MB)
  * Selftest: all tier transitions + corrupt/oversized/mismatch rejection
- [x] **MaterialRegistry**: base_color + pattern algorithm registry
  * StonePattern, WoodPattern, MetalPattern: v1 algorithms
  * Generates K=4 variants per material at boot
  * Selftest: pattern determinism, atlas generation, tile lookup
- [x] **FacadeSampler**: Mirrored-repeat infinite plane addressing
  * FNV-1a deterministic window origins (run-aware + isolated)
  * Selftest: mirror boundaries, seams, FNV determinism
- [x] **BakeCompositor**: GPU batch composite pass
  * Bake set construction with deduplication
  * Per-pixel multiply: material RGB × facade luminance (NEAREST)
  * One SubViewport frame per map load; target < 100ms
  * Selftest: dedup, composite timing, atlas assembly
- [x] **JunctionResolver**: Multi-edge junction detection
  * V-junction identification (2 walls at corner)
  * Junction column data: position, material, facade_enabled flag, override_material
- [x] **BakedTileLookup**: Placement integration seam
  * Single call: resolve(edge, face, voxel) → (source_id, atlas_coords)
  * Branch-exclusive: placement uses exactly one atlas path (baked XOR generic)
  * Selftest: toggle identical cell coords, differing sources ON/OFF
- [x] **ThemeApplier**: Render-time modulate application
  * apply(color) sets TileMapLayer.modulate on all walls
  * clear() resets to white (identity multiply)
- [x] **ThemeMatrixDebugView**: F5-toggled calibration grid
  * Material × theme cell grid (4 materials × 4 themes)
  * inspect_cell(): HSV breakdown, saturation verdict
  * Visual calibration for D9 grayscale discipline
- [x] **BakeSelftest**: Consolidated T1+T2 suites + invariants
  * B1: Branch exclusivity (baked XOR generic)
  * B2: Grayscale enforcement (facades + patterns)
  * B3: Alpha-from-canon (shape invariant)
  * B4: FNV-1a determinism (pinned hash values)
  * B6: Loud-fail validation (missing deps detected)
- [x] **ResolverHardeningTests**: End-to-end tier fallback
  * All 3 tiers exercised with real file states
  * Corrupt, oversized, dimension mismatch rejection + fallthrough
  * Real map load with mixed facade states (2 resolved + 1 material-only)

## Key Invariants (B1–B6)

All enforced by selftests and pre-commit hook:

- **B1: Branch Exclusivity** — Placement uses exactly one atlas path (baked OR generic), never both
- **B2: Grayscale Enforcement** — All facade and pattern sources are grayscale (R==G==B)
- **B3: Alpha from Canon** — Silhouette never generated; alpha from material registry
- **B4: FNV-1a Determinism** — Hash values pinned; run vs. isolated wall origin identical
- **B5: No Re-bake on Destruction** — Exposed geometry uses material atlas fallback
- **B6: Loud-Fail Selftests** — Assertions on missing dependencies; no silent breaks

## Determinism Pinned Values

- **TEX_AUTHORING_N**: 16 flat texels per voxel (pinned by BAKE-01 audit)
- **FNV-1a test vectors**: See BAKE-03 selftest output (e.g., 0x95d22b71, 0x64879b49)
- **MaterialRegistry variant generation**: K=4 variants per material, seeded deterministically

## Integration Sequence (FIX-BAKE-05)

1. **Boot (game startup)**: MaterialRegistry initialized (on-demand, not at autoload)
2. **Map load - Geometry phase**: room_builder compiles walls → EdgeRegistry populated
3. **Map load - Bake phase (if BakeConfig.enabled)**: TextureResolver resolves facades → BakeCompositor bakes all walls → atlas pages registered with tileset
4. **Placement phase**: voxel_renderer._set_voxel_cell() → BakedTileLookup.resolve(edge, face, voxel) → returns (source_id_int, atlas_coords)
5. **Render phase**: TileMapLayer renders cells using baked or material-only sources per enable state
6. **Destruction**: erase_cell() only; no re-bake triggered

## Debug Views

- **F5**: Theme Matrix (in-game calibration grid; material × theme cells with saturation guidance)
- **F6**: Toggle `BakeConfig.enabled` (BAKED / GENERIC) and reload the current map
- **F7**: Cycle `BakeConfig.blend_mode` through all 5 modes and reload the current map
  (BAKE-LIVE-VERIFY-02) — for live A/B/C/D/E visual comparison without editing
  `user://bake_config.cfg` or restarting
- **F12**: Reserved (not bound in-game); selftest is headless-only
- **Selftest CLI**: `godot --headless --script godot/scripts/tools/bake_selftest.gd` (FIX-BAKE-07)
- (Existing F2/F3/F4 family remains available for geometry inspection)

## Verbose Pipeline Diagnostics (BAKE-DIAG-01)

`BakeConfig.debug_bake_set_dump` (a `user://bake_config.cfg` key that existed
but was dead code before BAKE-LIVE-VERIFY-02) now gates `[BAKE-DIAG]` console
checkpoints at every stage of a real map load, so a future "nothing renders"
or "wrong output" report can be localized without new instrumentation:

- `room_builder.gd::build_from_layout()` — edge count from `EdgeExtractor`,
  whether the geometry path was taken at all
- `room_builder.gd::_bake_textures()` — wall descriptor count + material
  histogram, sample of the compositor's populated lookup keys
- `voxel_renderer.gd::print_render_diagnostics()` — per-`render()` counters:
  total cells placed, baked-hit count, generic-fallback count, cells with a
  null edge, and live tileset source count
- `baked_tile_lookup.gd::_resolve_baked_strip()` — throttled (max 5) miss
  logging with the *specific* reason a lookup missed (no baked atlas, empty
  lookup dict, edge not in any run, edge not found in its own run, key not in
  dict, or no source id for the page) — previously a miss just silently fell
  through to the generic path with no trace of why

Enable with `debug_bake_set_dump=true` in `user://bake_config.cfg`.

## File Locations (Baking System)

**Source modules:**
- `res://godot/scripts/systems/texture_resolver.gd`
- `res://godot/scripts/systems/per_face_projector.gd`
- `res://godot/scripts/systems/facade_sampler.gd`
- `res://godot/scripts/systems/material_registry.gd`
- `res://godot/scripts/systems/bake_compositor.gd`
- `res://godot/scripts/systems/baked_tile_lookup.gd`
- `res://godot/scripts/systems/bake_config.gd`
- `res://godot/scripts/systems/theme_applier.gd`
- `res://godot/scripts/systems/stone_pattern.gd`
- `res://godot/scripts/systems/wood_pattern.gd`
- `res://godot/scripts/systems/metal_pattern.gd`
- `res://godot/scripts/systems/material_atlas_generator.gd`

**Debug & Test:**
- `res://godot/scripts/debug/theme_matrix_debug_view.gd`
- `res://godot/scripts/tools/bake_selftest.gd`
- `res://godot/scripts/tools/resolver_hardening_tests.gd`
- `res://godot/scripts/tools/per_face_projector_test.gd`
- `res://godot/scripts/tools/facade_sampler_test.gd`
- `res://godot/scripts/tools/material_registry_test.gd`
- `res://godot/scripts/tools/bake_compositor_test.gd`
- `res://godot/scripts/tools/baked_tile_lookup_test.gd`
- `res://godot/scripts/tools/texture_resolver_selftest.gd`
- `res://godot/scripts/tools/theme_matrix_debug_test.gd`

**Data directories:**
- `res://textures/defaults/` — bundled default facades
- `user://textures/` — downloaded/custom facades
- `user://debug/` — bake artifacts (material_atlas_page_*.png, baked_atlas_page_*.png)
- `user://bake_config.cfg` — master configuration (enabled, blend_mode, feature toggles)

## GO-LIVE BLOCKERS

✅ **B3 CLOSED (2026-07-08, Overlord-implemented directly, BAKE-FIX-14): Alpha-from-Canon, Real Pixel Evidence**

**Closure basis (real pixel comparison, not structural/contract check):**

`godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd` compares every baked atom's alpha
channel, pixel-by-pixel, against the canonical voxel texture loaded **independently**
via `load(VoxelRenderer.VOXEL_ASSET_TEMPLATE % material).get_image()` — the exact same
resource-loading mechanism `VoxelRenderer._build_voxel_tileset()` uses for the generic
(non-baked) path. No SubViewport is required: `Texture2D.get_image()` decodes an
already-imported resource without any GPU/rendering-server draw call, so this works in
`--headless` mode.

**Correction applied same-day (post-implementation code review):** the first version of
this closure compared the baked atom against `BakeCompositor.get_canonical_voxel_atom()`,
which read the *same in-memory `Image`* (`_voxel_atoms[material]`, loaded once via raw
`Image.load()`) that `_get_canonical_alpha()` already reads from to **write** each baked
atom's alpha in the first place — a tautological self-comparison that was mathematically
guaranteed to report 0 mismatches regardless of whether the real generic rendering path
ever diverged. An 8-angle parallel code review (line-by-line, removed-behavior,
cross-file trace, reuse, simplification, efficiency, altitude, conventions) caught this
before it shipped. Fixed by loading the canonical side through `VoxelRenderer`'s own
`load()` path instead — a genuinely independent code path (subject to Godot's resource
import pipeline) that could, in principle, diverge from BakeCompositor's raw pixel data
if import settings ever changed. `BakeCompositor.get_canonical_voxel_atom()` was removed
(it had exactly one caller, and that caller no longer needs it). The same fix was applied
to `bake_selftest.gd`'s `test_B3_alpha_from_canonical()`, which the same review found had
never actually called `bake()` or compared anything — it only measured a histogram of the
source PNG's own alpha and could not fail either.

**Result (2026-07-08 run, PLAYGROUND map, 4 materials × 9 atoms × 32×36px, both
`bake_fix_11_pixel_diff_tool.gd` and `bake_selftest.gd`'s B3 sub-test):**
```
Material: concrete — 10368 pixels, 0 alpha mismatches (RGB diffs: 10368, 100% — facade shading, expected)
Material: stone    — 10368 pixels, 0 alpha mismatches (RGB diffs: 10368, 100% — facade shading, expected)
Material: wood     — 10368 pixels, 0 alpha mismatches (RGB diffs: 10368, 100% — facade shading, expected)
Material: metal    — 10368 pixels, 0 alpha mismatches (RGB diffs: 10368, 100% — facade shading, expected)
Grand total: 41472 pixels, 0 alpha mismatches, 41472 RGB differences (expected — facade luminance/
pattern shading is intentionally baked into RGB; B3 only requires alpha/silhouette invariance)
```

**Junction mirroring, verified via the real public entry point (no simulation, no
private-method reach-in):**
`bake_fix_02_test.gd` Test 3 calls `VoxelRenderer.render(registry, [column])` — the same
public method `room_builder.gd` calls, not the private `_render_junction_column()`
directly (the review's Altitude angle flagged the earlier version for bypassing the
public API) — and reads back the real `TileMapLayer` cell via a new `get_tileset()`
getter (replacing a direct read of the private `_tileset` field):
```
Case 1 (default mirror):             alternative_id=891, flip_h=true
Case 2 (override + facade_enabled):  alternative_id=891, flip_h=true
Case 3 (override, facade disabled):  alternative_id=0 (flat, no mirror, as expected)
```
The test now also picks the first column with `storey_count > 0` (guards against a
degenerate zero-height column producing a misleading failure) and prints an up-front
diagnostic on whether the chosen column has a discoverable neighbor, so a future
mirroring failure reads as "mirroring is broken" rather than "this column has no
neighbor in this map" — those are different bugs with the same symptom.
Results: 3 / 3 PASS.

**Known residual limitation (documented, not hidden):** since `BakeConfig.enabled` stays
`false` in this run (as it does in production by default), Test 3 exercises the
material-only H-flip fallback path in `_render_junction_column()`, not the
`_baked_lookup.resolve()` branch — that branch is covered separately by
`bake_fix_09_e2e_test.gd`. Also, because each material has only one atlas tile, Test 3
cannot distinguish "correct neighbor mirrored" from "some other same-material adjacent
voxel mirrored" — a wrong-neighbor-selection bug would not be caught by this test alone.

**Prior false closures (retracted in sequence, for the record):**
BAKE-FIX-04/09/09b, BAKE-SILHOUETTE-01, BAKE-FIX-03, BAKE-FIX-07, and BAKE-FIX-11 each
claimed closure via structural/config/contract checks with zero pixel data — most
recently BAKE-FIX-11's "CLOSED" (dictionary-key comparison, 16 vs 16 keys, no `Image`
reference), retracted 2026-07-07. BAKE-FIX-13's own follow-up attempt also fell short:
`_try_get_generic_image()` was hardcoded to always `return null`, so the comparison
branch never ran, and the mirroring test simulated `_render_junction_column()` in a
parallel `VoxelTestHarness` class rather than calling it. BAKE-FIX-14's first pass (same
day) fixed those two but introduced the tautological-comparison issue described above,
caught and fixed by the same day's code review pass before this was reported final.

**Implementation Record (BAKE-FIX-01 through BAKE-FIX-14):**
- BAKE-FIX-01: Master-strip pre-baking with alpha sourced from material registry + voxel PNG
- BAKE-FIX-02: Run grouping + per-junction overrides (facade_enabled, override_material fields)
- BAKE-FIX-03: Infrastructure foundation (configuration tests)
- BAKE-FIX-05: Dictionary lookup fix + field name corrections (Reader/Writer matching)
- BAKE-FIX-06: H-flip mirroring for junction columns + override application (3/3 tests PASS)
- BAKE-FIX-09: Lookup resolution verified (BAKE-FIX-09: Reader/Writer key matching)
- BAKE-FIX-10: Override authoring + real mirroring test (3/3 PASS)
- BAKE-FIX-11: Contract-level equivalence attempted, retracted (no pixel data)
- BAKE-FIX-12: Real offline pixel comparison + real function calls (11/11 PASS)
- BAKE-FIX-13: Follow-up attempt; generic-image accessor stubbed to null, mirroring test simulated rather than called — did not actually close B3
- **BAKE-FIX-14: Real alpha-from-canon pixel diff (0/41472 mismatches) + real `_render_junction_column()` mirroring evidence — B3 CLOSED**
- BAKE-LIVE-VERIFY-01/01-b/01-c: First real map-load verification; found + fixed
  the `map_spec["walls"]` combo-extraction gap (bug #1 above) and the
  shutdown-crash reintroduction (bug #2 above)
- BAKE-LIVE-VERIFY-02: Found + fixed the missing `create_tile()` registration
  (bug #3 above, the real cause of "walls vanish with bake on") and wired
  `BakeConfig.blend_mode` into real per-mode pixel math (bug #4 above), added
  F7 live blend-mode cycling. Facade visual calibration still open — see
  "First Live Verification Round" section above.

**Production Ready:**
- `BakeConfig.enabled` default remains `false` (Director's call to enable post-testing)
- Both generic and baked paths compile to identical layout structures (BAKE-FIX-07 Phase 3 validation)
- Alpha channel sourced directly from material registry (not PerFaceProjector, which is archived)
- Silhouette structure verified via dual-path layout comparison (full pixel-level comparison deferred to Phase 4)

**Next Step (Director):**
- To enable baking for shipped builds: create `user://bake_config.cfg` with `[bake] enabled=true`
- No code changes required; config-driven toggle suffices

---

## First Live Verification Round (BAKE-LIVE-VERIFY-01 through 02, 2026-07-08/09)

B3's closure above is real (alpha/silhouette invariant, verified with pixel
evidence) but it was still only ever exercised through headless synthetic
tests. **This was the first time the bake system was actually driven through
a real map load in the real running game** — and it surfaced four real,
independent structural bugs that no synthetic test had shape to catch,
because every synthetic test builds its own `map_spec` already in the shape
the code expects. Recorded here so the next round doesn't re-discover them:

1. **`BakeCompositor._extract_unique_combos()` never read `map_spec["walls"]`**
   (BAKE-LIVE-VERIFY-01-c) — it only read `map_spec["blocks"]`, a shape no
   production caller ever populates (`room_builder.gd::_bake_textures()`
   always builds `"walls"`). Every real map load found 0 combos and baked an
   empty atlas, silently, regardless of wall count. Fixed by adding a
   `"walls"` branch to the extraction loop.
2. **`BakedTileLookup.set_baked_atlas()` wrote `Engine.set_meta("GLOBAL_BAKED_ATLAS", ...)`**
   — the same GDScript-RefCounted-in-Engine-meta pattern `FIX-SHUTDOWN-CRASH-01`/`01b`
   already eliminated from production code, reintroduced here by a corrective
   prompt that called this pre-existing method without auditing its internals
   first. Caused a SIGABRT (exit 134) on shutdown. Fixed by removing the
   `Engine.set_meta` write; the instance-field storage added alongside it
   (`_baked_atlas`, `_source_ids`) was already sufficient and is what
   `_get_baked_atlas()` / `_get_baked_atlas_source_id()` check first.
3. **`VoxelRenderer.register_baked_atlas_page()` never called `create_tile()`**
   on the new `TileSetAtlasSource` — it set `.texture` and
   `.texture_region_size` and registered the source, but a
   `TileSetAtlasSource` has **zero valid tiles** until `create_tile(coords)`
   is called per atlas coordinate (exactly what `_build_voxel_tileset()`
   already does for the material-only sources). Without it, `set_cell()`
   silently accepts the baked `source_id`/`atlas_coords` — placement-side
   diagnostics report a 100% "baked hit" rate — but nothing draws. **This was
   the actual cause of "walls vanish entirely with bake enabled"**, not a
   lookup/dictionary problem (the dictionary was, by that point in the
   session, already correctly populated per bug #1's fix). Fixed by having
   `_bake_textures()` collect every `atlas_coords` the compositor wrote to
   (from `baked_atlas.lookup`) and passing that list into
   `register_baked_atlas_page()`, which now calls `create_tile()` +
   sets `texture_origin` (matching the generic-source convention) for each one.
4. **`BakeConfig.blend_mode` was pure dead config** — the enum
   (`MULTIPLY`/`TEXTURE_ONLY`/`MATERIAL_ONLY`/`OVERLAY_EXPERIMENTAL`/`LINEAR_LIGHT`)
   existed and was read from `user://bake_config.cfg`, but
   `_bake_master_strip()` always ran a hardcoded `base_color × pattern_shade × facade_lum`
   multiply regardless of the configured mode. Measured effect: baked
   concrete averaged **95/255** brightness vs. **194/255** for the same
   material's raw (unbaked) voxel texture — roughly half, which is why walls
   read as near-black even after bug #3 made them visible again. Fixed by
   implementing all 5 modes for real in `_apply_blend()` (measured average
   brightness per mode on the same input: MULTIPLY 95, TEXTURE_ONLY 155,
   MATERIAL_ONLY 157, OVERLAY_EXPERIMENTAL 178, LINEAR_LIGHT 210 — LINEAR_LIGHT
   was already the `blend_mode` default in the Director's `bake_config.cfg`
   before this fix, it just never took effect). Added an **F7** live keybind
   (`DebugToolsController.cycle_blend_mode()`) to cycle modes and reload the
   current map, so blend modes can be A/B compared in-editor without a
   restart.

**Open at end of this round:** bugs #1–#3 are confirmed fixed (walls render;
100% baked-hit placement rate in real headless boot logs). Bug #4's fix
makes the 5 blend modes genuinely distinct and F7-cyclable, and the Director
confirmed visible change when cycling — but the Director's stated bar
("see the facade texture") is **still not met**: cycling blend modes changes
overall brightness/tone but does not yet read as a textured facade with
visible pattern detail. Next round should investigate whether the facade
source images carry meaningful spatial detail at the 32×36 voxel-atom scale
in the first place (the `TextureResolver`-provided `res://textures/defaults/facade_*.png`
placeholders are the ones in play — no `user://textures/facade_*.png` exist
yet) and whether `_bake_master_strip()`'s texel-to-facade-pixel sampling math
(the `facade_col_texels`/`facade_pixel_x/y` block) preserves that detail or
averages it away per atom. `debug_bake_set_dump=true` and `enabled=true` were
left ON in the Director's local `user://bake_config.cfg` specifically so the
next round starts with diagnostics already live — see the "Verbose Pipeline
Diagnostics" section above.

## Known Limitations (v1)

- Camera zoom capped at 1× (no zoom-in cutscenes in scope)
- Multi-storey facade placement deferred (rows 1–3 unused; row 0 only)
- STICKER category reserved but unimplemented (v1.5)
- Water/translucent materials deferred (would require relaxing B2 for alpha channel)
- Per-wall theme tints not yet implemented (identified lever: alternative tiles with own modulate)
- Download system separate from resolver (resolver defines directory contract only)

## Entry Points

- **Game boot**: MaterialRegistry (initialized on-demand)
- **Map load**: room_builder.build_from_layout() → if BakeConfig.enabled, call _bake_textures() → TextureResolver → BakeCompositor → atlas registration
- **Placement**: voxel_renderer._set_voxel_cell() calls seam (BakedTileLookup.resolve() if enabled, else material-only)
- **Debug (F5)**: Theme Matrix (toggle with F5 key, in-game only)
- **Selftest (CLI)**: `godot --headless --script godot/scripts/tools/bake_selftest.gd` (15 PASS / 0 FAIL with real fail accounting)

---

## Process Learnings (BAKE-FIX-04 through BAKE-FIX-08 Cycle)

### Failure Pattern: Scope Creep Under Wrong Label

**Incident:** BAKE-FIX-04 was explicitly scoped as "documentation-only" with acceptance criteria `git diff --name-only` showing only `.md` files. The actual commit (c8a9467) modified production `.gd` files (junction_resolver.gd, voxel_renderer.gd, baked_tile_lookup.gd, room_builder.gd, map_compiler.gd) and tool files, directly breaching its stated scope.

**Root Cause:** Substantive work (junction mirroring, which rightfully belonged in BAKE-FIX-06) landed under the wrong commit label, making it untrackable in the history and causing stale/overstated claims to propagate (e.g., "BAKE-FIX-02: Junction column implementation: multi-edge silhouette handling + material overrides" when the actual implementation came later in BAKE-FIX-06).

**Prevention for Future Sprints:**
1. **Pre-commit scope check**: Before accepting a completion report, run `git diff --name-only` against the prompt's stated "DO NOT TOUCH" list. If any file on that list appears, reject the completion until separated.
2. **Label discipline**: A prompt's label (BAKE-FIX-NN) must describe what this specific prompt *delivers*, not what earlier prompts hoped would happen. Overstated claims should be rewritten in the next corrective prompt (as BAKE-FIX-08 did here).
3. **Honest status updates**: If infrastructure is complete but acceptance tests haven't run yet, say so (e.g., "B3 PENDING: Both rendering paths compile identical structures; pixel-level comparison deferred to Phase 4").
4. **Documentation reconciliation**: After each prompt, audit docs against actual code. A claim about a retired component (PerFaceProjector) is a red flag for stale documentation.

### Corrective Process (BAKE-FIX-08)
- Reverted all overstated claims to honest status
- Removed references to archived/unused code (PerFaceProjector)
- Mapped actual delivery (BAKE-FIX-05/06/07) to current_state.md and OPERATOR_CONTEXT.md
- Added process note (this section) so the same drift is easier to catch earlier

---

## Appendix — ENHANCE-02 Implementation Status (historical)

Moved here 2026-07-08 from `OPERATOR_CONTEXT.md` §Quality Standards; the error
handling *contract* itself remains in `OPERATOR_CONTEXT.md`.

- ✅ MapCatalog.get_spec() — returns empty dict on unknown map_id, logs push_error
- ✅ MapCompiler.compile() — _validate() uses push_error, returns empty dict on failure
- ✅ EdgeExtractor.extract() — guards for empty/malformed compiled maps, returns empty result
- ✅ load_map() — checks for empty layout after compile(), aborts early if invalid
- ✅ Negative test suite — 4 checks verify error contract (malformed specs handled cleanly)
- ✅ Zero INTEGER_DIVISION warnings
- ✅ Zero printerr calls (replaced with print_debug)

---

## OVERLORD-FIX-01 — Continuous-Plane Facade Model (2026-07-09, Overlord direct)

Replaces every previous half-face/strip mapping. Full rationale in
`bake_compositor.gd`'s header; canon summary:

**Model.** A wall run is ONE continuous inclined plane on screen. Each atom
carries a 32-texel window of that plane anchored at `u = col*16`; consecutive
atoms' windows overlap by 16 texels ON PURPOSE — occluded halves carry the
same plane content as the neighbor that covers them, so every visible mix of
atom fragments (including the 8-px sawtooth overlaps) is seamless by
construction. Atoms are baked **per direction** (dir 0 = plane descends
screen-right = SW-face/X-axis runs; dir 1 = mirrored = SE-face/Y-axis runs)
and direction is part of the lookup key: `mat|fac|col|row|dir`.

**Formulas** (side face; `row 31 = top storey`, v flipped so facade top = wall top):
```
dir 0:  u = col*16 + x          y_top(x) = 8 + x/2
dir 1:  u = col*16 + (31 - x)   y_top(x) = 8 + (31 - x)/2
v = (31 - row)*16 + (y - y_top(x)) * 16/20
```
Implementation is pure `blit_rect`: facade → ×20/16 vertical resize →
±x/2 shear (2-px strips) = plane image P per direction; every atom is an
axis-aligned 32×28 crop of P at `((col*16 or 1024−col*16), (31−row)*20 +
col*8 + margin)` — the x-terms cancel exactly. Blend modes ride per-tile
`modulate` on grayscale pages (TEXTURE_ONLY = white, MULTIPLY = base color;
LINEAR_LIGHT/OVERLAY render as TEXTURE_ONLY pending LUT variants;
MATERIAL_ONLY short-circuits placement to the generic atlas). Alpha =
canonical silhouette via `blit_rect_mask` + byte-exact AA fixup (B3); facade
PNG alpha is flattened before use (it is a luminance source only).

**Root causes killed this round** (all verified by probe, not report):
1. Run grouping chained via `gu_b` (the ACROSS-wall neighbor) → 320 edges
   became 264 single-edge runs → facade column never advanced past 7.
   Fixed: chain along the run axis (`gu_a ± (0,1)` for SE, `± (1,0)` for SW).
2. `_detect_run_axis` probed fields Edge doesn't have (pos_start/pos) →
   always axis 0. Fixed: axis is intrinsic to `face_a`.
3. The 02-b/02-c "second-direction mirror" never executed
   (`edge.has_method("id")` — `id` is a property). Superseded by per-dir sheets.
4. Facade PNG alpha (254-byte pixels in facade_concrete) leaked into atom
   alpha via masked blit. Fixed: RGB8 round-trip flattens facade alpha.

**Evidence (2026-07-09):** placement 128928/128928 baked hits, 0 generic
fallbacks (TEXTURES boot); bake 4 combos × 2 dirs ≈ 420 ms (was ~21 s);
B3 alpha 0/9,437,184 mismatches (bake_fix_11 7/7, page-derived atoms);
bake_fix_12 9/9 incl. 128/128 projection identity vs independent facade,
8-pair overlap-identity seam check (byte-exact), SE→dir1/SW→dir0 run-axis;
external Python probe vs marker facade: 23,130 checks, 3 half-texel
boundary quantization diffs, 0 structural. Dev boot defaults ratified:
`BakeConfig.enabled = true`, `blend_mode = TEXTURE_ONLY` (flip `enabled`
back to false before any release build — shipped-default canon unchanged).
Director visual ratification 2026-07-10 ("Alpha Baking Base").

**Diagnostic tooling** (cfg-gated via `user://bake_config.cfg [bake]`):
- `debug_marker_facade=true` — OVERLORD-PROBE-01: replaces every facade with
  a synthetic grayscale marker (brightness staircase per 16-px window, black
  window seams, white row lines). The rendered wall then *reads out* which
  window each atom shows, in which order, and whether the shear is applied.
  Use this first in any future mapping investigation.
- `debug_bake_set_dump=true` — checkpoint logging (extraction → compositor →
  registration → placement HIT with dir/col/level, reasoned MISSes) + atlas
  pages dumped to `user://bake_debug_page_*.png` for offline verification.

**OVERLORD-FIX-02 (2026-07-10) — junction leg continuation.** Junction
columns no longer restart a facade window: each half-face continues its
adjacent leg's plane (LEFT half = SW face, coplanar with the X-axis/dir-0
leg; RIGHT half = SE face, coplanar with the Y-axis/dir-1 leg), cropped at
the junction's own projected column — one past the run's end, so
mirrored-repeat naturally yields the mirrored last column. Composed per
bake() into per-material junction pages (map-dependent, not session-cached),
keyed `JUNCTION|x|y|level`; placement tries `resolve_junction()` first and
falls back to the legacy neighbor-mirror path (3 of TEXTURES' 32 junctions
have non-elbow leg pairs and use the fallback). `bake_fix_12` sampling is
now seeded (deterministic) and its identity contract covers true face pixels
only (the negative-v wedge above `y_top` is occluded by construction).

**Blend decision (Director, 2026-07-10):** **MULTIPLY is the chosen blend**
— it preserves each voxel's original material color under the facade detail.
It reads slightly dark (facade luminance averages < 1.0), compensated by
`BakeCompositor.MULTIPLY_LUMA_LIFT = 0.25` applied to the modulate; final
brightness authority belongs to the light/shadow projection system — retune
or zero the lift when that lands. Junction columns confirmed correct by the
Director in the same session ("Alpha Walls Textured" checkpoint).

**Known legacy-test debt** (pre-existing, fails loudly, not a regression):
`baked_tile_lookup_test.gd` calls `_make_bake_key` and
`block_01b_baking_e2e_test.gd` reads `atlas.pages` — BAKE-05-era APIs that
no longer exist (and already did not exist before OVERLORD-FIX-01).
Candidates for retirement or rewrite in a cleanup prompt. `bake_selftest.gd`
was updated to pin the new sheet canon (SHEET_COLS×SHEET_ROWS = 64×32,
replacing STRIP_LENGTH = 9) and passes 19/19.
