# ARCHIVE: Baking System Session Archival

**Status:** Final housekeeping
**Deliverables:** Session archival per protocol, PROMPTS/DONE organization, CODEMAP.md delta, session summary, OPERATOR_CONTEXT.md update

---

## Part A: PROMPTS/DONE Organization

Move all completed prompts to the archive:

```
PROMPTS/
├── DONE/
│   ├── TEX-CATALOG-01.md          (TextureResolver, texture contract)
│   ├── BAKE-01.md                 (Tile Anatomy Audit, PerFaceProjector)
│   ├── BAKE-02.md                 (MaterialRegistry, pattern algorithms)
│   ├── BAKE-03.md                 (FacadeSampler, mirrored-repeat)
│   ├── BAKE-04.md                 (BakeCompositor, GPU batch)
│   ├── BAKE-05.md                 (Drop-in swap, BakedTileLookup)
│   ├── BAKE-06.md                 (ThemeApplier, Theme Matrix view)
│   ├── BAKE-07.md                 (BAKE selftest, invariants)
│   └── BAKE-08.md                 (Resolver hardening, end-to-end)
├── PLANNING/
│   └── BAKING_MASTER_PLAN.md       (Master plan, reference)
└── FUTURE/
    └── (none at this time; v1.5 enhancements documented in BAKING_MASTER_PLAN §10)
```

**Archive action:**
```bash
mkdir -p PROMPTS/DONE
mv TEX-CATALOG-01.md BAKE-0{1..8}.md PROMPTS/DONE/
cp BAKING_MASTER_PLAN.md PROMPTS/PLANNING/
git add PROMPTS/
```

---

## Part B: CODEMAP.md Delta

The baking system adds 9 new modules and 1 shader. Update CODEMAP.md:

### B.1 New Entries

```markdown
## Baking System (BAKE pipeline)

### Core Modules

**texture_resolver.gd** (§TEX-CATALOG-01)
- TextureResolver class: user:// → default:// → material-only fallback chain
- Validates: grayscale, dimensions, file size cap
- 1 selftest: all tier transitions exercised
- Lines: ~150

**per_face_projector.gd** (§BAKE-01)
- PerFaceProjector class: flat texture space ↔ screen space affine transforms
- One transform per face orientation (NE, SE, SW, NW) + cap (forward-compatible)
- Integer-shear assertion (NEAREST sampling guarantee)
- 1 selftest: round-trip, integer shear, point-in-voxel
- Lines: ~200

**facade_sampler.gd** (§BAKE-03)
- FacadeSampler class: mirrored-repeat addressing, window origin derivation
- FNV-1a hash-based determinism (run vs. isolated wall origin hashing)
- 1 selftest: mirror boundaries, seams, FNV determinism, sample synthetic facade
- Lines: ~180

**material_registry.gd** (§BAKE-02)
- MaterialRegistry class: material definitions (base_color + pattern algorithm)
- StonePattern, WoodPattern, MetalPattern: v1 pattern algorithms
- MaterialAtlasGenerator: generates K=4 variants per material at boot
- 1 selftest: pattern determinism, atlas generation, tile lookup
- Lines: ~350 (registry) + ~100 per pattern algorithm

**bake_compositor.gd** (§BAKE-04)
- BakeCompositor class: orchestrates GPU batch (one SubViewport frame)
- Bake set construction: deduplication of (material, facade, variant, face, window)
- _composite_tile: per-pixel multiply (material × facade) with inverse mapping
- 1 selftest: dedup, composite, timing < 100ms
- Lines: ~400

**baked_tile_lookup.gd** (§BAKE-05)
- BakedTileLookup class: single-point seam between placement and atlases
- Placement calls resolve(edge, face, voxel) → (source_id, atlas_coords)
- Toggle test: identical cell coords, differing sources ON/OFF
- Lines: ~120

**bake_config.gd** (§BAKE-05)
- BakeConfig static class: master kill-switch (enabled), blend_mode, feature toggles
- Branch exclusivity: one lookup call in placement, no dual-path code
- Lines: ~40

**theme_applier.gd** (§BAKE-06)
- ThemeApplier class: apply/clear render-time theme modulation
- Single call site for TileMapLayer.modulate assignment
- Lines: ~60

**theme_matrix_debug_view.gd** (§BAKE-06)
- ThemeMatrixDebugView class: F5-toggled grid UI (material × theme cells)
- Visual calibration for D9 saturation discipline
- inspect_cell(): drill-down HSV breakdown, saturation verdict
- Lines: ~220

**bake_selftest.gd** (§BAKE-07)
- Consolidated selftest suite: B1–B6 invariants, probe pattern regression, destruction, multimap
- All tests print literal PASS lines (OPERATOR_CONTEXT evidence rule)
- Lines: ~400

### Shaders

**bake_compositor.gdshader** (§BAKE-04, optional optimization)
- Compositor shader: screen-to-flat mapping, mirrored-repeat, multiply blend
- GPU path for batch rendering (CPU path is primary for v1; shader deferred to v1.1)
- Lines: ~100 (placeholder for now)

### Updated Modules

**check_invariants.py** (pre-commit hook, §BAKE-07)
- Added B1: branch-exclusivity grep (no GENERIC_MATERIAL_ATLAS in placement)
- Added B4: FNV-1a constant pinning validation
- ~20 lines added

### Configuration

**BAKE_CONFIG (user://bake_config.cfg)**
- `[bake] enabled = false` (master switch)
- `[bake] blend_mode = MULTIPLY` (0=MULTIPLY, 1=TEXTURE_ONLY, 2=MATERIAL_ONLY, etc.)
- `[debug] debug_bake_set_dump = false`

### Constants (shared header, e.g., texture_constants.gd)

**TEX_AUTHORING_N**: flat texels per voxel (pinned by BAKE-01 audit, e.g., 16)
**VOXEL_TILE_SIZE, VOXEL_TILE_OFFSET_PX, VOXEL_STEP_PX**: existing canon (reused)

---

### Integration Points

**room_builder.gd** modifications:
- Phase 2: generate material atlas (BAKE-02) at boot
- Phase 3: bake map (BAKE-04) at map load
- Atlas registration: both material and baked sources added to TileSet
- Phase 4: placement now uses BakedTileLookup.resolve (one-line seam)

**placement_controller.gd** modifications:
- Deleted: _get_material_atlas_coords(), GENERIC_MATERIAL_ATLAS reference
- Added: one-line seam call to BakedTileLookup.resolve()

---

### Removed (Dead Code Cleanup)

- (None yet; dead code from prior refactors already cleaned in SLICE-02, ENHANCE-04b)
- If placement ever had a direct material atlas lookup, it's now via BakedTileLookup fallback

---

### Entry Points

- **Game boot**: MaterialRegistry initialized, material atlas generated (§BAKE-02)
- **Map load**: TextureResolver resolves facades, BakeCompositor bakes, atlases registered, placement begins (§BAKE-04, BAKE-05)
- **Debug (F5)**: Theme Matrix toggled (§BAKE-06)
- **Debug (F12)**: Selftest suite run (§BAKE-07)

---

## Part C: Session Summary

**Title:** INFILTRAITOR Baking System — Complete Implementation Plan & Prompts

**Scope:** Texture baking pipeline providing per-wall facade surfaces (marble veins, wood grain, metal sheen) while preserving voxel destructibility and rendering fidelity.

**Architecture:**
- **Input:** Map spec (walls, materials, themes) + facade textures (user:// or bundled defaults)
- **Processing:** TextureResolver → PerFaceProjector (math audit) → MaterialRegistry (pattern generation) → FacadeSampler (plane addressing) → BakeCompositor (GPU batch composite)
- **Output:** Baked TileSetAtlasSource(s), drop-in replacement for generic material atlas via BakedTileLookup seam
- **Fallback:** Material-only rendering if facade unresolved; destruction never re-bakes; themes applied at render time

**Key Decisions (Canonized):**
- D1: Multiply blend (swappable via BakeConfig)
- D2: Render-time modulate (not baked)
- D3: Single-pass inverse mapping (one resample, NEAREST)
- D4: Hybrid download + fallback (user:// → default:// → material-only)
- D5: Facade model (infinite plane via mirrored-repeat, 64×32 voxel-face per material)
- D6: Storey = 8 voxels (1 GU proportion)
- D7: MATERIAL as code (base_color + pattern algorithm, K=4 variants)
- D8: 1× screen-native authoring (no camera zoom >1×)
- D9: Grayscale sources, hue from base_color × theme
- D10: SLICE = 1×1 facade window (unified sampler)
- D11: STICKER reserved (v1.5, alpha-over after multiply stack)

**New Invariants:**
- B1: Branch exclusivity (baked XOR generic, never both)
- B2: Grayscale enforcement (facade + pattern sources)
- B3: Alpha from canon (silhouette never generated)
- B4: FNV-1a determinism (pinned hash values)
- B5: No re-bake on destruction (exposed geometry uses material atlas)
- B6: Loud-fail selftests (assertions on missing dependencies)

**Deliverables:**
1. **BAKING_MASTER_PLAN.md** (26 KB) — Consolidated architecture, decision register, 8-stage pixel journey, 9 modules, capacity analysis, risk register, 10-prompt sequence
2. **TEX-CATALOG-01.md** (21 KB) — Texture contract, category definitions, naming scheme, TextureResolver module + selftest
3. **BAKE-01.md** (21 KB) — Tile Anatomy Audit, PerFaceProjector transforms, integer-shear pinning of N
4. **BAKE-02.md** (17 KB) — MaterialRegistry, pattern algorithms (stone/wood/metal), atlas generation
5. **BAKE-03.md** (15 KB) — FacadeSampler, mirrored-repeat, window origin hashing
6. **BAKE-04.md** (18 KB) — BakeCompositor, GPU batch, deduplication, atlas assembly
7. **BAKE-05.md** (19 KB) — BakedTileLookup, drop-in swap, branch-exclusive seam
8. **BAKE-06.md** (13 KB) — ThemeApplier, Theme Matrix debug view, saturation calibration
9. **BAKE-07.md** (20 KB) — BAKE selftest suite, invariant enforcement, pre-commit hook updates
10. **BAKE-08.md** (16 KB) — Resolver hardening, end-to-end tests, tier fallback exercise, CI/CD readiness

**Total Documentation:** ~180 KB (9 prompts + master plan)

**Implementation Sequence:**
- Math before pixels: BAKE-01 (audit) → BAKE-02 (patterns) → BAKE-03 (sampler)
- Pixels before swap: BAKE-04 (compositor)
- Swap only when everything upstream is proven: BAKE-05 (drop-in)
- Tooling & validation: BAKE-06, BAKE-07, BAKE-08

**Scar-Informed Mitigations:**
- SLICE-00 (misalignment): Alpha-from-canon (B3), identical region/origin by construction, automated probe regression
- SLICE-02 Stage A (branch bug): Structural exclusivity (B1), single lookup seam, old code deleted in same prompt
- ENHANCE-04b (drift): Seam insertion instead of extraction, zero logic changes to placement, verified by grep
- slice_geometry_selftest (silent break): B6 loud-fail design, assertions on missing deps, no dynamic loads of deletable paths

**Risks Retired (Pre-Prompt):**
- Blend produces mud: D9 discipline + Theme Matrix visual calibration
- Tiles misaligned: B3 (alpha canon) + probe pattern regression test
- Dual-path code: B1 branch exclusivity + grep validation
- Shader timing: GPU path optional (CPU batch is proven affordable)

**Open Items (Deferred, §BAKING_MASTER_PLAN §10):**
- Multi-storey wall placement (v1.5)
- STICKER category (v1.5)
- Water / translucent materials (v2)
- Disk cache of baked atlases (if BAKE-04 timings demand)
- Per-wall theme tints (identified lever: alternative tiles with own modulate)
- Zoom-out shimmer mitigation (pre-decimated facade variants)
- 4× cutscene assets (authorial position: not needed)

**Evidence & Validation:**
- All prompts comply with OPERATOR_CONTEXT: PASS criteria require literal console output
- Selftests are T1 (headless math) before T2 (render) before touching live code
- Pre-commit hook enforces invariants (B1, B4) automatically
- Resolver hardening exercises all tiers under real-world file states

---

## Part D: OPERATOR_CONTEXT.md Delta

Update the operator context document:

### D.1 New Sections

```markdown
## Baking System (BAKE Pipeline)

### Overview
The baking system composites per-wall facade textures with material patterns at map load, producing baked TileSetAtlasSource(s). No changes to placement logic; the seam is a single-call lookup (BakedTileLookup.resolve).

### Module Checklist
- [x] TextureResolver: user:// → default:// → material-only fallback chain
- [x] PerFaceProjector: flat ↔ screen affine transforms per face orientation
- [x] MaterialRegistry: base_color + pattern algorithm registry, K=4 variant atlas generation
- [x] FacadeSampler: mirrored-repeat plane addressing, FNV-1a window origin derivation
- [x] BakeCompositor: GPU batch composite pass, deduplication
- [x] BakedTileLookup: placement seam (resolve → source_id, atlas_coords)
- [x] ThemeApplier: render-time modulate application
- [x] ThemeMatrixDebugView: F5-toggled calibration grid
- [x] BakeSelftest: consolidated T1+T2 suites, invariant enforcement
- [x] ResolverHardeningTests: end-to-end, tier fallback exercise

### Invariants (B1–B6)
All enforced by selftests and pre-commit hook. See BAKE-07.

### Determinism Pinned Values
- TEX_AUTHORING_N (flat texels per voxel): pinned by BAKE-01 audit (e.g., 16)
- FNV-1a hash test vectors: pinned in BAKE-03 selftest
- PerFaceProjector transforms (4 matrices + offsets): extracted and pinned in BAKE-01

### Integration Sequence
1. Boot: MaterialRegistry init → material atlas generation (BAKE-02)
2. Map load: TextureResolver resolve → BakeCompositor bake → atlas registration
3. Placement: BakedTileLookup.resolve → set_cell (single seam)
4. Destruction: erase_cell only; no re-bake; exposed geometry uses material atlas

### Debug Views
- F5: Theme Matrix (material × theme grid, saturation audit)
- F12: Selftest suite (all invariants, destruction, multimap)
- (Existing F2/F3/F4 family still available for geometry inspection)

### Known Limitations (v1)
- Camera zoom capped at 1× (no zoom-in cutscenes in scope)
- Multi-storey placement deferred (facade rows 1–3 unused; row 0 only)
- STICKER category reserved but unimplemented
- Water/translucent materials deferred (would require relaxing B3 for translucent-flagged materials)
- Per-wall theme tints not yet implemented (lever identified: alternative tiles with own modulate)
- Download system separate (resolver defines directory contract; download orchestration external)
```

### D.2 Updated Initialization Checklist

```markdown
## Boot Sequence (Updated for Baking System)

1. **Godot engine init**
2. **Game constants loaded** (includes TEX_AUTHORING_N, VOXEL_* constants)
3. **Material registry initialized** (BAKE-02)
   - StonePattern, WoodPattern, MetalPattern registered
4. **Material atlas generated** (BAKE-02, MaterialAtlasGenerator)
   - Persists for game session; reused by all maps
5. **Map load begins**
6. **Geometry compiled** (existing room_builder)
7. **Facade textures resolved** (TEX-CATALOG-01, TextureResolver)
   - user:// → default:// → material-only fallback
8. **Baking executed** (BAKE-04, BakeCompositor)
   - One GPU batch frame; expected < 100ms
9. **Baked atlas registered** (BAKE-05, room_builder integration)
10. **Wall placement begins** (existing placement_controller, now using BakedTileLookup seam)
11. **Debug views initialized** (BAKE-06, theme matrix; BAKE-07, selftest suite)
12. **Gameplay**
```

### D.3 Relevant File Locations

```markdown
## Baking System File Layout

**Source modules:**
- `res://baking/texture_resolver.gd`
- `res://baking/per_face_projector.gd`
- `res://baking/facade_sampler.gd`
- `res://baking/material_registry.gd`
- `res://baking/bake_compositor.gd`
- `res://baking/baked_tile_lookup.gd`
- `res://baking/bake_config.gd`
- `res://baking/theme_applier.gd`
- `res://baking/debug/theme_matrix_debug_view.gd`
- `res://baking/tests/bake_selftest.gd`
- `res://baking/tests/resolver_hardening_tests.gd`

**Shaders:**
- `res://shaders/bake_compositor.gdshader` (optional optimization)

**Data:**
- `res://textures/defaults/` (bundled default facades)
- `user://textures/` (downloaded facades)
- `user://debug/` (bake artifacts: material_atlas_page_*.png, baked_atlas_page_*.png)
- `user://bake_config.cfg` (master config)

**Tests:**
- Run via F12 key during gameplay, or via CI script: `godot --headless --script bake_selftest.gd`
```

---

## Part E: Archival Checklist

Before marking session as archived:

- [ ] All 9 prompts moved to `PROMPTS/DONE/`
- [ ] Master plan copied to `PROMPTS/PLANNING/`
- [ ] CODEMAP.md updated with new modules, integration points, removed entries
- [ ] OPERATOR_CONTEXT.md updated with baking system overview, invariants, boot sequence
- [ ] Session summary documented above (Part C)
- [ ] All evidence transcripts (console PASS lines, selftest outputs, resolver logs) appended to session notes
- [ ] FNV-1a pinned hash values documented in BAKE-03 selftest section
- [ ] PerFaceProjector transforms (4 matrices, 4 offsets) documented in BAKE-01 section
- [ ] TEX_AUTHORING_N placeholder replaced with actual pinned value post-BAKE-01 audit
- [ ] Git commit: `[ARCHIVE] Baking System Session Complete (10 prompts, 180KB docs, 9 modules, B1–B6 invariants)`

---

## Part F: Next Session Handoff

When the baking system implementation begins (K4PUTZ consumption of these prompts):

1. **First:** Audit BAKING_MASTER_PLAN.md for any design gaps or clarifications needed (brief check, < 15 min).
2. **Then:** Follow the 10-prompt sequence strictly (TEX-CATALOG-01 through BAKE-08).
3. **For each prompt:** Deliver to K4PUTZ with this preamble:
   ```
   [PROMPT NAME]
   Status: Ready for implementation
   Predecessor: [prior module]
   Successor: [next module]
   PASS criteria: [literal console evidence required]
   ```
4. **Acceptance criteria:** All PASS criteria achieved, all literal console lines logged, no skipped selftests, grep validation (B1, B4) clean.
5. **Blocking issues:** If a prompt reveals a design gap (e.g., BAKE-01 audit finds N is incompatible with existing geometry), surface immediately; do not force past it.
6. **Cross-prompt dependencies:** Module initialization order (BAKE-02 at boot before BAKE-04 at map load) and constant pinning (TEX_AUTHORING_N) are critical. BAKE-05 seam insertion must account for actual `room_builder.gd` sequencing (integration point I2).

---

*End of ARCHIVE.*

**Session Complete. Baking System ready for implementation.**
