# INFILTRAITOR — Bake System Reference

**Extracted 2026-07-08 from `tools/persistent/OPERATOR_CONTEXT.md`** (v0.5.0
context restructure). This document holds the full bake-pipeline architecture,
module checklist, file locations, closure evidence, and process learnings.
The compact canon (invariants B1–B6, the placement seam, the config default)
stays in `CLAUDE.md`; consult this document on demand before modifying the
bake system.

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
- **B2: Grayscale Enforcement** — All WALL/CEILING facade and pattern sources are grayscale (R==G==B); color comes from `MaterialDef.base_color` at bake time. Floor-zone bake (`MaterialDef.full_color`, see room_builder.gd's floor_zones flood-fill) is an intentional, scoped exception: photographic `ground_*` sources keep their real RGB (page modulate forced to `Color.WHITE`, never tinted). `TextureResolver._is_grayscale()` enforces B2 at load time for everything except `ground_`-prefixed filenames.
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

> **Verified against the tree on 2026-07-12.** Every path below exists. The previous
> version of this list named `per_face_projector.gd`, `material_atlas_generator.gd`,
> `per_face_projector_test.gd`, `material_registry_test.gd` and `bake_compositor_test.gd`
> — **none of which were in the repo.** If you add a module, add it here; if a path here
> does not resolve, that is a bug in this doc, not a missing file.

**Source modules** (`res://godot/scripts/systems/`):
- `texture_resolver.gd` · `facade_sampler.gd` · `material_registry.gd`
- `bake_compositor.gd` · `baked_tile_lookup.gd` · `bake_config.gd`
- `theme_applier.gd` · `stone_pattern.gd` · `wood_pattern.gd` · `metal_pattern.gd`

**Debug & Test:**
- `res://godot/scripts/debug/theme_matrix_debug_view.gd`
- `res://godot/scripts/tools/bake_selftest.gd` — **the standing bake gate**
- `res://godot/scripts/tools/resolver_hardening_tests.gd`
- `res://godot/scripts/tools/texture_resolver_selftest.gd`
- `res://godot/scripts/tools/bake_cache_test.gd` — acceptance gate for BAKE-CACHE-01

> **One-off tools purged 2026-07-12.** The `bake_fix_*` / `fix_bake_*` /
> `block_01*` / `*_verification` scripts cited elsewhere in this document were
> per-prompt evidence tools, not standing gates. They were deleted (33 scripts,
> ~5,900 lines). **Their findings, recorded in this document, stand** — the tool was
> the scaffold, the invariant is the product. `git show <sha>:godot/scripts/tools/<name>.gd`
> recovers any of them.

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
handling *contract* itself now lives in `CLAUDE.md`.

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
the junction's own projected column — one past the run's end. (The original
claim that "mirrored-repeat naturally yields the mirrored last column" was
wrong in practice: `_mirror_index()` drops the fold's reflection bit, so a
reflected raw column sampled the plane VERBATIM and lateral V-junction
columns repeated the adjacent wall column. Fixed by JUNCTION-MIRROR-02,
2026-07-18 — see TOP-JUNCTION-06's section below.) Composed per
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

**Legacy-test debt retired (2026-07-11; deleted 2026-07-12):**
`baked_tile_lookup_test.gd` and `block_01b_baking_e2e_test.gd` were BAKE-05-era
tests calling APIs (`_make_bake_key`, `atlas.pages`) that no longer exist. Never
wired into any lint/CI gate; their coverage is superseded by `bake_selftest` and
`bake_cache_test` (both green). First quarantined to `_archive/`, then deleted
outright in the 2026-07-12 sweep — **an `_archive/` folder in a git repo is
redundant with git.** `bake_selftest.gd` pins the sheet canon
(SHEET_COLS×SHEET_ROWS = 64×32, replacing STRIP_LENGTH = 9), 19/19.

**Disk-cache hash fix (2026-07-11):** `_fnv1a_64()` was a home-grown
XOR/shift function mislabeled "FNV-1a" (no multiply by the FNV prime) —
a second, non-canonical hash living beside the real, B4-tested one in
`FacadeSampler._fnv1a_hash()`. Rewritten to the actual FNV-1a algorithm
(offset basis 2166136261, prime 16777619) so B4's "one hash, project-wide"
invariant holds for the disk cache too. This invalidated all previously
written `user://bake_cache/*.png` files (different keys); harmless —
they regenerate on next miss.

---

## Horizontal Facades (Voxel Tops) — TOP-SHEAR-01 / TOP-CROP-02 /
## TOP-JUNCTION-03 (2026-07-11), closing TOP_TEXTURE_MASTER_PLAN Part 1

Voxel tops (slices + junction columns) now project the same facade files as
the side planes, seamless with them and with each other, using the same
"pure blits, no per-pixel sampling" architecture. First attempt (`TOP-01`)
shipped an unsheared top ("upright squares" — the same failure class the
side faces had before OVERLORD-FIX-01) while its own completion report
certified all criteria PASS; caught by Director screenshot, corrected via a
4-prompt sequence (see the master plan §3 for the full sequencing rationale
— this is also the incident that tightened the OVERLORD_CONTEXT prompt-
sizing rule to 3–5 criteria/mechanism).

**The construction.** A horizontal plane in the iso projection is the facade
rotated 45° and squashed 2:1 — the same fact that makes the side-plane shear
work, applied to the other axis. Factors into two strip-blit passes with a
proven mapping contract:

```
pass 1 (row strips):    (u, v) → (u − v + X_OFF, v)      X_OFF = source height − 1
pass 2 (column strips): (x, y) → (x, y + floor(x/2))
contract:  T(u − v + X_OFF, (u+v)/2 + Y_MARGIN) == S_ext(u, v)  for every texel
```

Built once per (facade, direction) into image **T** (`_get_plane_top()`),
cached beside the side planes P⁰/P¹ in `_plane_top_cache`, reusing
`_get_plane_source()` (the same alpha-flattened, mirror-wrapped source the
side planes build — one source builder, not two). dir 1 = T built from the
mirrored source, exactly like P¹.

**Per-atom top crop** (in `_compose_sheet_page()` / `_compose_junction_pages()`):
for atom (col, row), ground window `u₀ = col·16, v₀ = row·16`; plane vertex
`sx₀ = u₀ − v₀ + X_OFF, sy₀ = (u₀+v₀)/2 + Y_MARGIN`; crop
`Rect2i(sx₀ − 16, sy₀, 32, 16)` pasted through the diamond mask (derived
from `_get_diamond_overlay()`'s edge geometry — one diamond definition, not
two). Junction tops continue the **X-leg (dir 0)** by fixed convention.
Replaces the flat base-color diamond fill when `BakeConfig.facade_tops` is
true (dev default); bit-identical to pre-TOP-01 output when false.

**Evidence:** composed-transform pixel identity (≥64 samples, ≥16 atoms,
both directions, independently-loaded facade, ±1-texel tolerance, 0
mismatches — run red against the pre-fix unsheared T first, confirmed
failing, per red-before-green discipline); marker-facade slope witness
(white row line crosses a diamond at screen slope −1/2, both directions);
top-overlap byte-identity (≥500 px, 0 mismatches, same construction
argument as the side-face overlap-identity check); full regression suite
green (`bake_fix_02` 3/3, `09` 5/5, `11` 7/7 — 0/9,437,184 alpha mismatches,
`12` 10/10, `selftest` 19/19). Director visual ratification: TEXTURES tops
read as one continuous slab flowing through junction corners.

**Milestone-closure state (2026-07-11):** `MULTIPLY` set as the shipped dev
default blend mode (was `TEXTURE_ONLY`) per the Director's ratified canon —
`BakeConfig.blend_mode` static default and the local `bake_config.cfg`
override both updated; `MULTIPLY_LUMA_LIFT = 0.25` still compensates the
darkening. `TOP_TEXTURE_MASTER_PLAN.md` Parts 1–2 close here; Part 3
(textured interiors) stays open, blocked on the destruction system.

---

## TOP-JUNCTION-06 — Junction columns sample the folded column (2026-07-11, Overlord direct)

**This is the canon rule for junction half-face sampling. It supersedes
TOP-JUNCTION-04 and TOP-JUNCTION-05.**

### The rule

A junction column's two half-faces are cropped from their legs' plane images at
the **mirrored-repeat–folded** column index, and that single folded value is used
in **both** the horizontal crop offset and the vertical shear term:

```gdscript
var col_x := _mirror_index(raw_col_x, SHEET_COLS)   # SHEET_COLS = 64
var col_y := _mirror_index(raw_col_y, SHEET_COLS)
var y0_x: int = (SHEET_ROWS - 1 - row) * 20 + col_x * 8 + V_MARGIN
atom_content.blit_rect(plane0, Rect2i(col_x * TEX_AUTHORING_N, y0_x, 16, 28), Vector2i(0, 8))
var y0_y: int = (SHEET_ROWS - 1 - row) * 20 + col_y * 8 + V_MARGIN
atom_content.blit_rect(plane1, Rect2i(FACADE_W - col_y * TEX_AUTHORING_N + 16, y0_y, 16, 28), Vector2i(16, 8))
```

**JUNCTION-MIRROR-02 addendum (2026-07-18, `067ec70`, bake v8):** the fold
alone is not enough — `_mirror_index()` drops the fold's REFLECTION bit.
When the raw column lands in a reflected segment (`_is_reflected_fold()`:
e.g. raw `−1`, one before the run start — every lateral V-junction at a box
silhouette corner — or a long perimeter's far corner, raw 208 → fold 47),
the crop must sample the plane **mirrored in texture space**
(`_blit_half_mirrored()`: per-column blits taking the mirrored source
column with its shear delta compensated — a plain `flip_x` of the
pre-sheared crop would flip the face's slope too). Verbatim sampling made
lateral junction columns repeat the adjacent wall column (Director's
red-circled seam, TEXTURES stone tower); center corners (raw 24,
unreflected) were always correct and are untouched.

### Why — and why this is not a clamp

`_compose_sheet_page()` (the straight-run path, shipping and Director-ratified)
is the reference. It uses the **same in-range `col`** in `x0` and in `y0`, and
that `col` is inside `[0, SHEET_COLS)` by construction. The shear term is a
function of *the texture column being sampled*, not of physical distance along
the wall — the plane image `P` already has the shear baked in per column
(`_get_plane()`: `shift = x >> 1`).

A straight-run neighbour at distance `d` along the run samples
`_mirror_index_1d(d, 64)` (`BakedTileLookup._compute_facade_key`). Therefore a
junction column at distance `d` **must sample that same folded column** to be
seam-continuous with its own neighbours. Bounds-safety is a *consequence*, not
the goal: folded ∈ `[0, 64)` ⇒ source x ∈ `[0, 1024]` ⇒ always inside
`PLANE_W = 1056`.

### What went wrong before (and the trap to remember)

`room_builder.gd` projects a junction onto its leg's run axis as an **unbounded**
distance (`col_x`/`col_y`, OVERLORD-FIX-02 — correct by design). Feeding that raw
value straight into `blit_rect` as a pixel offset produced two distinct on-screen
defects from one cause:

| raw col | source x | on-screen |
|---|---|---|
| `-1`, or `≥ 66` | outside `[0, 1056)` | half-face **blank** → serrated column, only tops visible |
| `64` | `1024` — lands *inside* the 32 px mirrored wrap margin | half-face reads the wrap strip at the wrong shear → **displaced** column |

**`Image.blit_rect` silently clips an out-of-range source rect.** No error, no
warning — a direct violation of B6 (loud-fail) at the Godot API boundary, and the
reason this shipped unnoticed through two "PASSED" prompts. Any new code that
computes a `Rect2i` into a plane image from map-derived data must bound it
explicitly or fold it, and should assert.

TOP-JUNCTION-04's insight — "the same value must appear in the crop and the shear
term" — was correct, but it satisfied that with the *raw* value: self-consistent,
yet unbounded and not what the neighbours sample. Folding satisfies the same
constraint, matches the neighbours, and is bounds-safe.

### Verification (real bake, real map, real pixels)

- Junctions with blank side pixels: **24/32 → 0** real.
  The only survivors are the single atom pixel `(0, 7)`, canonical alpha
  `4/255`, on `col == 0` atoms — and `_compose_sheet_page()` produces that exact
  pixel on every straight run (64 occurrences in one TEXTURES bake). Junctions
  now **match the shipping reference** rather than deviating from it; this pixel
  is a pre-existing, universal, sub-visible AA artifact and is out of scope.
- Screenshot diff before/after: 4 056 changed pixels, confined to exactly the two
  defective columns. No collateral change.
- Junction materials verified, not assumed: all 32 satisfy
  `jc.material == leg_a.material == leg_b.material`.

### Diagnostics left in place (both gated, both earn their keep)

- **`BakeConfig.debug_bake_set_dump`** now also prints, per junction:
  the projected `col_x`/`col_y`, the resulting source x for each half-face, and
  whether both land inside the plane (`in_plane`); plus a `blank_side_px` count
  of pixels the canonical silhouette says are solid but that no plane crop
  reached. A non-zero `blank_side_px` beyond the `(0,7)` baseline means a crop is
  falling outside the plane again.
- **`INFILTRAITOR_SKIP_JUNCTIONS=1`** (`VoxelRenderer.render()`) renders a map
  with the filler columns omitted. Diffing two captures isolates exactly which
  screen pixels belong to junction columns — the only cheap way to answer "is
  this column doing anything?" for a given map.

### Junction columns are NOT map artifacts — do not try to delete them

Established while chasing an apparent "displaced column" defect that turned out
to be map layout: `JunctionResolver` emits a filler column at **every** elbow, in
every map — TEXTURES 32, SIGMA_01 24, PLAYGROUND 23, TEST_BLOCKS 4 — placed one
cell diagonally out from the elbow, on a voxel that is **never** already occupied
by a wall voxel (0 redundant across all four maps). In SIGMA they fill real
notches at the wall elbows and are invisible because the material matches. They
are load-bearing. Turning the feature off would break SIGMA.

## ROOF-BAKE — Roof Slab Baking (ROOF-BAKE-01/02, 2026-07-16, Overlord direct)

The bake system extends to HORIZONTAL surfaces (roof/ceiling `Slab`s,
`Slab.Role.CEILING`). Canon after ROOF-BAKE-02 (`f88d060`):

### The projection

`_get_roof_plane_top(facade_id, facade)` builds a dedicated roof plane with
the SAME two-pass isometric mapping as `_get_plane_top()` —
`T(u−v+x_off, (u+v)/2+V_MARGIN) = S(u, v)` — but from
`_get_roof_plane_source()`: the facade **unscaled** (1:1, no wall ×20/16
vertical pre-scale), grayscale-flattened, with the standard mirrored wrap
strip + mirrored vertical margins (source = 1056×576 vs the wall source's
1056×704). Consequences, all load-bearing:

- **Isotropic**: 16 texels per voxel on BOTH ground axes (the wall source
  reads 25% stretched along y when laid flat — the original "stones look
  wrong" defect).
- **Full period**: the 64×32 sheet windows cover the 1024×512 facade
  EXACTLY, so the mirrored-repeat fold coincides with the texture's own
  natural boundary.
- Screen offset between adjacent roof voxels (±16, +8) equals the
  crop-window offset in T, so the assembled top surface is a pure
  translation of the roof plane — **seam-continuous by construction**
  (verified at pixel level, `roof_bake_selftest.gd` test 3).

### Keys and anchoring

- Lookup key: `"ROOF|<material>|<facade>|<col>|<row>"` — **no direction
  component** (a horizontal surface has none; each side half samples its
  own wall plane, see Composition below).
- `(col, row)` = mirrored fold of the **STRUCTURE-LOCAL offset**
  `voxel.grid_pos − Slab.texture_anchor` — **BOTH axes period 64** since
  ROOF-SIDE-03 (`006c854`): the SE half consumes y as a dir-1 run
  position, which a period-32 y-fold cannot carry (fold-32 is derivable
  from fold-64, never the reverse). The 32-band indices each half needs
  are re-derived per axis via `_band_index()`.
- `texture_anchor` = voxel origin of the bounding-box NW corner of the
  slab's **connected roofed-GU component** (4-adjacency over all
  `solid_block_instances` GUs, level- and material-blind), computed by
  `room_builder` at generation and stored ON the Slab so re-renders need no
  builder context. Global keying (ROOF-BAKE-01's first cut) is banned: it
  put mirror folds at fixed world lines (x=64k, y=32k — every 8×4 GUs)
  through roof interiors.
- Placement: `render_slab_solid()` → `_set_voxel_cell(..., flat_baked)` →
  `BakedTileLookup.resolve_flat(material, local_pos)`. Fallback contract
  identical to walls: any miss (bake off, MATERIAL_ONLY, unmapped material,
  no atlas, key absent) lands on the generic material atlas. B5 unchanged:
  destruction-exposed geometry falls back to the material atlas, never
  re-bakes.

### Composition

`_compose_roof_pages()` runs in `bake()` after junction pages (and also on
the wall-less early path — a blocks-only map still bakes roofs). Cells
arrive RAW LOCAL from `room_builder` (read off the real Slab voxels — the
single footprint truth per D1-ROOF-b); the fold happens in the compositor,
the one module owning sheet periods. Atom recipe: side halves (below) +
roof-plane top crop (diamond-masked) + canonical silhouette mask + B3 AA
fixup; pages sized to atom count (junction-page pattern). Session-cached
under `"ROOF|mat|fac"`.

**Side halves — ROOF-SIDE-01→04 (2026-07-16→18), Director's diagram
ratified:** a slab's two visible side faces must run in the same texture
direction as the walls below.

- LEFT (SW-facing) half: dir-0 wall plane at the atom's own fold — run
  position along the SW edge is x, exactly the wall sheet's `(col, row)`
  roles. Always was correct.
- RIGHT (SE-facing) half: dir-1 wall plane with the roles TRANSPOSED
  (ROOF-SIDE-03, `006c854`, bake v6) — run position = y (dir-1 formula
  `x0 = FACADE_W − y·16`, right half at `+16`), 20px band index = x, `·8`
  half-step stagger = y: the exact math `_compose_sheet_page` uses for
  dir-1 wall atoms. Its two predecessors were wrong twice over:
  ROOF-SIDE-01 (`0fe9914`, v4) mirrored the atom's own left half — right
  shear, wrong progression (along the SE edge only y advances; a dir-0
  crop never consumes y), reading as a flat "lid". ROOF-SIDE-02
  (`8d72ee8`, v5) then masked side halves to border-exposed cells only,
  curing that misdiagnosis but leaving slabs HOLLOW — reverted in full by
  ROOF-SIDE-04 (`16ac6cd`, v7): **every roof atom paints both side
  halves; slabs are solid** (interior faces are visible whenever
  occlusion ghosts the front walls, and destruction will expose them for
  real).

### Rotation (ROOF-BAKE-02a, closes old open item #7)

`PerspectiveMapper.layout_with_perspective()` rotates
`solid_block_instances` (rectangle: two rotated corners → min-corner origin
+ `rotated_size()`) and `voxel_prop_instances` (points — all shipped
PropDefs are 1×1; multi-GU props need footprint-aware rotation IN THE
MAPPER when they exist). Before this, roofs were built in the N frame while
the walls they capped rotated — roofs landed on the wrong structures in
E/S/W views.

### Borders at storey steps (ROOF-BAKE-02b)

Roof border adjacency is LEVEL-AWARE: suppress a side only toward a
neighbour roofed at the SAME base level (flat continuity) or HIGHER (the
taller wall's far-slice already fills that seam column at our level —
growing into it would double-write Slice-owned cells); grow an **eave**
over a LOWER neighbour (never collides: storey gap ≥ 5 levels >
ROOF_LEVEL_COUNT = 2). The old boolean adjacency left a 1-voxel gap at
every storey step.

### Known limitations / Director-judged polish (open)

- ~~Border voxels' SIDE faces show dir-0 wall-plane content at arbitrary
  rows — not aligned with the walls below.~~ **RESOLVED** by
  ROOF-SIDE-03/04 (2026-07-18, Director: "faces laterais resolvidas") —
  both halves now run in the wall-below direction; see Composition above.
- Roof tops show the WALL facade laid flat. Honest projection; per-material
  dedicated roof art is a possible future step (metal reads most odd).
- Slab-vs-solid-block overlap at storey steps: a lower roof's CORE column
  overlaps the taller block's wall far-slice cells at the step (pre-existing
  since D1-ROOF, unrelated to 02b's border rule). Invisible today;
  a latent Part 3 (destruction trigger) conflict to resolve there.
- ~~Roof occlusion participation: accidental/partial, not yet deliberately
  scoped (Part 2b note stands).~~ **RESOLVED** by ROOF-OCC-01
  (2026-07-18) — see [occlusion.md § Roof Occlusion](../systems/occlusion.md#roof-occlusion-roof-occ-01).

### Evidence

`roof_bake_selftest.gd` 8/8 — every expectation locally re-derived (own
mirror fold, own component flood fill, own E-rotation math): 324 local
cells incl. negative border coords; resolve_flat vs derivation incl.
out-of-period folds; isotropy (576 vs 704 px sources); 2304 opaque
top-diamond pixels ALL equal to a direct roof-plane read; 7778 real
PLAYGROUND roof voxels placed exactly as predicted, 2 real storey-step
sides exercising the eave rule; 49/49 blocks roofed at their
independently-rotated E-view position with correct material.

## FLOOR-ZONE-BAKE — Author-Declared Ground Material Zones (FLOOR-BAKE-01, 2026-07-28, Director direct)

The bake system extends to FLOOR voxels (`Slab.Role.FLOOR`), reusing
ROOF-BAKE's flat-plane projection verbatim — same camera, same horizontal-
surface math, LITERALLY the same `"ROOF|..."` lookup-key family and
`_compose_roof_pages()`/`_compose_roof_page()` functions (floor specs merge
into the same `roof_specs`-shaped array `room_builder.gd` already builds;
namespaced material/facade ids prevent key collisions with wall/ceiling
combos). The one geometric departure is the plane's own aspect ratio (Color
model below is the other). Motivation: the earth-hash floor
(`EarthVariantSelector`) reads as generic dirt everywhere and seams visually
against baked walls/ceiling; the project's newly-catalogued photographic
ground textures (`ASSETS/TEXTURES/source/ground/`) needed a real placement
mechanism, but author-controlled by region (concrete over here, grass
there), not random per-cell noise.

### Color model — the one real departure from B2

Walls/ceiling sample `FacadeSampler`-style GRAYSCALE facades, tinted by
`MaterialDef.base_color` at bake time (B2). Floor-zone materials are
photographic and keep their REAL RGB instead — `MaterialDef.full_color`
(default `false`) short-circuits `_modulate_for_mode()` to return
`Color.WHITE` unconditionally, before the blend_mode switch. This required
**no per-pixel compositing change**: `_get_plane_source()`'s "grayscale
flatten" is actually just an `Image.convert(RGB8)→convert(RGBA8)` round-trip
that strips alpha but never collapses RGB to luminance — real color already
survived that step for walls too. The tint was always a GPU-side per-PAGE
`TileData.modulate`, applied at registration time
(`voxel_renderer.gd::register_baked_atlas_page`), never a page-pixel write —
so forcing it to WHITE for `full_color` materials is the entire mechanism.
B2's grayscale text is scoped to wall/ceiling facades; `full_color` sources
are the documented exception, and `TextureResolver._is_grayscale()`
enforces this split at load time (a `ground_`-prefixed filename bypasses
the check; everything else still must pass it).

### The projection — isotropic at the source's own square aspect

Floor's photographic sources are 1024×1024 (square, seamless), not the wall
facade's inherited 1024×512. `_get_roof_plane_source()` gained an optional
`target_h` parameter (default `FACADE_H`=512, unchanged for
wall/ceiling) — floor callers pass `FACADE_W`=1024 instead, so the plane
built is genuinely isotropic on both axes rather than stretched 2:1.
`resolve_flat()` folds BOTH axes at period `SHEET_COLS`=64, and at
`TEX_AUTHORING_N`=16 px/GU-cell, `64×16=1024` is exactly this target — no
coincidence, the size was chosen to match the addressable domain. Side
faces (visible only at destruction-crater edges) are a deliberate v1
exception: they still crop from the wall-style ×20/16-prescaled plane
(unchanged, mildly resampled aspect on a low-visibility feature) rather
than getting their own isotropic variant — revisit only if it reads badly
on screen.

### Data model — author-declared rectangular zones

New MapSpec section `floor_zones`, shape identical to `blocks`:
`{"gu": [x,y], "size": [w,h], "material": "ground_grass"}`. Compiled into
`layout.floor_zone_instances` (kept as rectangles, not pre-expanded per-GU —
this is what lets `PerspectiveMapper` rotate it with the exact two-corner
math `solid_block_instances` already has). `room_builder.gd` expands the
rects into a per-GU dict (last rect in the list wins on overlap) and
flood-fills 4-adjacent GUs into connected components — the SAME BFS as
roof's `texture_anchor` pass, substituting "same declared zone material"
for "both roofed" as the sole membership test. A GU outside every declared
zone keeps the pre-feature behavior: `Slab.material = "earth"`,
`texture_anchor = Vector2i.ZERO`, rendered via `EarthVariantSelector` as
before — `render_slab()` branches on `slab.material != "earth"`.

Persistence: `map_sections_v1.gd::register_floor_zones()` (v1, no
migration, literal copy of `register_blocks()`'s shape), and
`file_map_source.gd` needs its own `runtime["floor_zones"] = ...`
translation block — registering a MAPFILE section is NOT sufficient by
itself, `_translate_to_runtime_spec()` only forwards sections it explicitly
knows about.

### A real sequencing bug, and the lesson (fixed 2026-07-27)

Floor Slab GENERATION happens early and unconditionally (before the
edges-conditional block, so floor exists even in an edge-less room) — but
the first implementation also RENDERED immediately in that same loop,
before `_bake_textures()` had run. Every zoned voxel's `resolve_flat()`
lookup MISSed (queried before the page existed), silently falling back to
`MATERIALS.find("ground_grass")` = -1 → `MATERIALS[0]` = flat gray
"concrete". A real capture (not code reading) caught it: two adjacent
zones rendered as one undifferentiated flat gray patch instead of distinct
photographic materials. Fixed by deferring floor's `render_slab()` calls to
the same point roof's own render loop already uses — after `render()` and
`_bake_textures()`, right after the edges-conditional block closes (still
running unconditionally, so an edge-less room's floor renders too — bake
just never ran for it, and any zone declared there falls back to `earth`,
a documented v1 limitation, not a crash).

**Process note**: `_set_voxel_cell()`'s flat_baked branch was already
correctly gated — the bug was pure timing, invisible to a lint/invariant
pass, only a real windowed capture + console log surfaced it
(`[BAKE] Composed roof page ROOF|ground_grass|ground_grass` in the log
proved the page existed; the screenshot proved the renderer wasn't
finding it yet).

### Known limitations / Director-judged polish (open)

- v1 ships 5 representative materials (`ground_grass`, `ground_concrete`,
  `ground_dirt`, `ground_gravel`, `ground_sand`) from the 66 catalogued
  ground textures — the rest, plus a global material-naming pass, are an
  explicitly deferred later phase (Director, 2026-07-27).
- Edge-less rooms never bake floor zones (no `edge_registry`/junction
  infrastructure to bake against) — a zone declared there silently
  degrades to `earth`. Every real room in the project has walls; not
  chased further for v1.
- ~~Destruction always reveals plain `earth`, never the zone's declared
  surface.~~ **REVERSED 2026-07-28 (Director) — the revisit this bullet
  asked for happened:** seen together in a real room, the exposed generic
  earth read as a bug, not as a design. The zone now goes **three levels
  deep** (`DESTRUCTION_MASTER_PLAN` D20): both destructible `Slab` planes
  (−1, −2) carry the zone material, and the first FIXED level below them
  (−3) is painted through the same baked page via
  `VoxelRenderer.set_floor_zone()` — a per-GU `{material, anchor}` table,
  needed because the fixed levels place cells directly and so have no
  container to read a material off. Levels −4..−8 stay plain earth: they
  are only ever seen on the map's outer lateral cut, where reading as raw
  bedrock is correct. `process_dirty_slabs()` was fixed in the same pass —
  it sent *every* `Role.FLOOR` voxel down the earth-variant path, so a
  dirty-but-surviving voxel of a zoned floor would have come back generic
  (latent: nothing cracks floors today, only destroys).
- Side faces at zone edges use the wall-style anisotropic plane (see The
  projection above) — correct image, imperfect aspect, on a rarely-visible
  feature.

### Evidence

`floor_zone_bake_selftest.gd` 8/8 — same rigor as roof's, every expectation
locally re-derived: 324 local cells incl. negative border coords;
resolve_flat vs derivation incl. out-of-period folds; isotropy (1088 vs
576px sources, confirming the 1024-vs-512 target split) plus 2304 opaque
top-diamond pixels equal to a direct plane read AND genuinely non-grayscale
(2299/2304 colored pixels — rules out an accidental luminance-collapse
regression); 3072 real zoned voxels on `maps/FLOOR_ZONES_TEST.map.json`
placed exactly as predicted, 20 unzoned Slabs sampled clean; 3/3 zones
floored at their independently-rotated E-view position with correct
material. Real capture: `Screenshots/history/auto_2026-07-27_23-20-51.png`
— true photographic grass/dirt/sand, correct boundaries, unzoned floor
unchanged.
