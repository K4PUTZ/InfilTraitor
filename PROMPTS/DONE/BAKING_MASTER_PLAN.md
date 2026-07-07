# BAKING SYSTEM MASTER PLAN

**Project:** INFILTRAITOR — Texture Baking Pipeline
**Status:** DRAFT FOR APPROVAL
**Version:** 1.0 — 2026-07-04
**Companion docs:** `VOXEL_MASTER_PLAN.md`, `ENHANCE_MASTER_PLAN.md`, `DIRECTION_GLOSSARY.md`, `OPERATOR_CONTEXT.md`

---

## 0. Purpose

The Baking System gives walls unique, art-directed surfaces (marble veins, wood grain, metal sheen) while preserving every property of the current voxel renderer: per-voxel destructibility, `set_cell()`-only placement, canonical tile geometry, and deterministic rendering. It does this by compositing textures into a **baked `TileSetAtlasSource`** at map load, which the placement code consumes as a drop-in replacement for the generic material tileset.

Design stance (canon, from authorial direction): *the texture is seasoning, not simulation.* The game does not hide that it is low-poly. Caps, wall cores, and destruction-exposed faces render as plain material voxels. Baking applies only where a facade exists.

---

## 1. Canonical Decision Register

All decisions below are CLOSED unless marked otherwise. This section supersedes scattered session notes.

| # | Decision | Canon |
|---|----------|-------|
| D1 | Blend operation | **MULTIPLY**, everywhere in the chain. Swappable/disable-able via `BakeConfig` (see §4.1). |
| D2 | Theme application point | **Render-time `modulate`** on the wall TileMapLayer(s). Never baked into the atlas. |
| D3 | Resampling | **Single-pass inverse mapping**, flat texture space → tile pixels. One resample total. NEAREST filtering. |
| D4 | Texture acquisition | **Hybrid**: progressive downloads land in `user://textures/`; `TextureResolver` falls back to `res://textures/defaults/`, then to material-only. Bake runs at map load, in GPU batch. Downloads take effect on next map load. No disk cache in v1 (measure first). |
| D5 | Facade model (replaces RUN) | One **FACADE** per material: 8 edges × 4 storeys = **64 × 32 face-voxels**, addressed as an **infinite deterministic plane via mirrored-repeat** on both axes. Every wall crops a window from this plane. RUN-5/RUN-8 debate is dissolved: window size is arbitrary. |
| D6 | Storey | **8 voxels tall = 1 GU proportion.** Real heights compose by stacking storeys. Facade covers 4 storeys. |
| D7 | MATERIAL category | Redefined: **not a texture file — a shading algorithm** (`shade(voxel_xy, face, seed) → multiplier`) plus a base color. Produces **K = 4 pre-rendered tile variants** per material. Caps, cores, and destruction-exposed faces use these tiles directly and **never enter the bake pipeline**. |
| D8 | Authoring resolution | **1× screen-native.** No camera zoom above 1×. Flat texel density chosen so shear offsets are integer source pixels (pinned in TEX-CATALOG-01 after the Tile Anatomy Audit, §9/BAKE-01). 4× cutscene assets: out of scope. |
| D9 | Color discipline | **FACADE and PATTERN sources carry luminance only (grayscale).** All hue comes from `base_color(material) × theme`. Themes authored as soft tints (moderate saturation, high value) OR a deliberate dominant-filter effect — documented per theme, never accidental. |
| D10 | SLICE category | Unified with FACADE: an individual slice texture is a facade whose plane is 1 edge × 1 storey. Same sampler, same addressing, no special case. |
| D11 | STICKER category | Compositor reserves an ordered **alpha-over pass** after the multiply stack, before capture. **Implementation deferred** (see §10). |

---

## 2. The Multiplicative Chain

Every rendered wall pixel is the product of four factors:

```
final(px) = C_mat  ⊙  P(voxel, face, seed)  ⊙  L_fac(u, v)  ⊙  T_theme
            └─ RGB     └─ scalar                └─ scalar        └─ RGB
```

| Factor | What | Lives where | Computed when |
|--------|------|-------------|---------------|
| `C_mat` | Material base color (stone gray, wood brown, metal blue-gray) | Material atlas | Boot (generated) |
| `P` | Pattern shade multiplier (stone jitter, wood grooves, metal sheen band) | Material atlas (K variants) | Boot (generated) |
| `L_fac` | Facade luminance sample (marble veins etc.) | Baked atlas | Map load (BakeCompositor) |
| `T_theme` | Map theme tint | `modulate` | Render time |

Properties this buys us — these are the load-bearing guarantees of the whole design:

1. **Commutativity/associativity.** Multiply factors can be grouped and cached at any stage; preview in an external editor matches the engine (Godot 2D operates in sRGB by default, matching Photoshop multiply).
2. **Per-factor kill-switch.** Each factor's identity element is `1.0` / `Color.WHITE`: pattern off → single flat variant; facade off → plain material wall; theme off → WHITE modulate. The global feature flag is just the outermost member of this family.
3. **Predictable failure.** Multiply only darkens. It never shifts hue on grayscale inputs and never clips. The one hazard — saturated × saturated = mud — is fenced by D9 and made visible by the Theme Matrix debug view (§4.9).

---

## 3. Pixel Journey — Stage by Stage

The life of one wall pixel, from authoring to screen. Each stage names its owning component (§4).

### Stage 0 — Authoring & acquisition
- **Facades** are authored flat (orthographic, no skew) as grayscale PNGs of `64N × 32N` px, where `N` = flat pixels per voxel (pinned in TEX-CATALOG-01). Small files by design — friendly to progressive download.
- **Materials** are code: a base color plus a pattern algorithm registered in `MaterialRegistry`. No files to download; nothing to resolve.
- **Themes** are color values in the map spec.
- Downloaded facades land in `user://textures/` (builds cannot write `res://`). Defaults ship in `res://textures/defaults/`.

### Stage 1 — Map load: resolution
`TextureResolver` maps each facade ID referenced by the map spec through the fallback chain:

```
user://textures/{id}.png  →  res://textures/defaults/{id}.png  →  material-only (no facade)
```

Every candidate is validated on resolve: PNG decodes, dimensions match the catalog contract, size under cap. An invalid file logs a warning and falls through one tier. **The game always renders something** — worst case is a clean material-only wall.

### Stage 2 — Bake set construction
After room geometry is built and the Edge Registry is populated, the compositor walks the wall set and derives, per wall face:

```
BakeKey = (material_id, facade_id, variant_k, face_orientation, plane_col, plane_row)
```

- `plane_col / plane_row` — the window position in the infinite facade plane (Stage 3 addressing).
- `variant_k` — material tile variant, seeded by position.
- Faces with no facade produce **no key** — they render straight from the material atlas.
- Keys are **deduplicated**: two walls sampling the same plane window with the same material/variant share one baked tile. This is the main memory lever (§6).

### Stage 3 — Facade addressing (the infinite plane)
The facade defines a deterministic infinite plane by mirrored repetition on both axes:

```
plane(i, j) = facade[ mirror(i, W), mirror(j, H) ]
mirror(k, S): fold k into [0, S) reflecting on every odd period (mirrored-repeat)
```

Window origin rules:
- **Contiguous run:** origin column = `FNV1a(canonical min WallEdgeData of the run) mod 8` edges; successive slices in the run consume consecutive plane columns → veins flow continuously across the run.
- **Isolated wall:** origin = `(FNV1a(edge) mod 8, FNV1a'(edge) mod 4)` — randomizes which patch of the facade a small wall shows, preventing the "clone stamp" look (authorial request, Q1).
- **Vertical:** plane row = storey index (v1: always row 0; see §11-I1).

Determinism invariant: hashing is **our own FNV-1a over the canonical edge key string** — never Godot's `hash()`, whose stability across engine versions is not guaranteed. Same map spec ⇒ same pixels, every session, every machine. Mirrored seams produce "book-matching" — a real stone-finishing technique — and preserve groove directionality on wood under horizontal flip. Accepted aesthetics, documented in the catalog.

### Stage 4 — Composite (single pass, GPU batch)
For each deduplicated `BakeKey`, one draw call into a shared `SubViewport`:

- Source A: the material variant tile (from the material atlas) — supplies **RGB (C⊙P)** and **alpha (canonical silhouette)**.
- Source B: the facade — sampled through the `PerFaceProjector` affine transform (uniforms: flat origin + axis vectors for this face orientation). Inverse mapping: for each tile pixel, compute its flat coordinate, fetch luminance. With integer-N (D8), every fetch lands on an exact texel — NEAREST, zero subpixel bleeding.
- Fragment result: `rgb = A.rgb × B.lum`, `a = A.a`.

The whole bake is **one frame**: draw all tiles → `render_target_update_mode = UPDATE_ONCE` → `await RenderingServer.frame_post_draw` → `get_texture().get_image()`. One await, one capture, expected cost tens of ms at map load.

**Alpha invariant:** the baked pipeline never generates silhouettes. Alpha always comes from the canonical material tile. The baked wall's shape is bit-identical to the generic wall's shape by construction — this is what makes the swap risk-free.

### Stage 5 — Atlas assembly
The captured `Image` becomes a `TileSetAtlasSource`:

- `texture_region_size = VOXEL_TILE_SIZE (32×16)` — identical to canon.
- `texture_origin` — identical to canon.
- `create_tile()` per baked region; `TEXTURE_FILTER_NEAREST`.
- Registered as an additional source on the existing TileSet. If the bake set overflows one texture page, additional atlas sources are created — paging is architecturally free because the lookup (Stage 6) already returns `(source_id, atlas_coords)`.

### Stage 6 — Placement (unchanged)
Placement code calls one lookup:

```gdscript
BakedTileLookup.resolve(edge, face, voxel) -> { source_id, atlas_coords, alternative }
```

- Baking enabled + key exists → baked tile.
- Baking disabled, or face has no facade → generic material tile.
- **Branch exclusivity is structural:** one lookup function, one flag, no code path where both sources render. (SLICE-02 scar: the dual-branch bug is designed out, not tested out.)
- Rule #8 intact: voxels placed via `set_cell()` only. Rule #2 intact: `VISUAL_GRID_OFFSET` via parameter.

### Stage 7 — Render time & destruction
- `ThemeApplier` sets `modulate = theme_color` on the wall layer(s). Disable = `Color.WHITE`. Because multiply commutes, ordering against shadow/lighting overlays is irrelevant.
- **Destruction never triggers baking.** `erase_cell()` removes a voxel; any newly exposed geometry (cores, cap edges) renders from the material atlas, which is always resident. There is no re-bake path, no destruction-time cost, no invalidation logic.

---

## 4. Component Architecture

All modules are **additive** (SLICE-01 pattern): new files, no rewrites of live systems until the swap prompt (BAKE-05). Target ≤ 300 lines per module.

### 4.1 `BakeConfig`
Single configuration surface. Proposed shape:

```gdscript
class_name BakeConfig
enabled: bool                # master kill-switch — branch-exclusive with generic tileset
blend_mode: BlendMode        # MULTIPLY | TEXTURE_ONLY | MATERIAL_ONLY | OVERLAY_EXPERIMENTAL
theme_enabled: bool
variants_enabled: bool       # false → K collapses to 1
facade_enabled: bool         # false → all walls material-only
```

`blend_mode` maps to a uniform in the compositor shader; swapping blend = changing one value; disabling = pass-through. This satisfies D1's "easy to swap or disable" requirement with zero architectural cost.

### 4.2 `TextureResolver`
- `resolve(facade_id) -> ResolvedTexture { image, tier }` with tier ∈ {USER, DEFAULT, NONE}.
- Validation on resolve: decode, dimension contract, size cap. Invalid → warn + next tier.
- Loads via `Image.load_from_file()` + `ImageTexture.create_from_image()` — no import pipeline, which is exactly right for us (NEAREST, no mipmaps).
- Logs one provenance line per resolved ID (evidence-friendly).
- Owns **no** download logic. The download system is a separate feature; the resolver only defines the directory contract it must satisfy.

### 4.3 `MaterialRegistry` + pattern algorithms
- Material definition: `{ id, base_color, pattern: PatternAlgorithm, flags }` (`flags` reserves `translucent` for v2 water — unused in v1).
- `PatternAlgorithm.shade(voxel_xy: Vector2i, face: Face, seed: int) -> float` — pure, deterministic.
- v1 algorithms: **stone** (per-voxel luminance jitter, seeded), **wood** (columnar periodic grooves), **metal** (smooth sheen band across the face — 8 steps per edge, banding accepted as low-poly aesthetic).
- **Generates** the material voxel atlas at boot: K = 4 variants × face types × materials, sharing canonical tile geometry with the existing tileset. Generation is deterministic and takes milliseconds (tiny tile count). *Rationale for generated-not-authored: patterns are code, so tweaking an algorithm should not require re-exporting art. Grass/dirt/water later become new registry entries, not new asset pipelines.* — **flagged for authorial veto, §11-V1.**

### 4.4 `FacadeSampler`
- Pure functions: mirrored-repeat addressing, window origin derivation (FNV-1a), `sample(facade, plane_uv) -> lum`.
- No rendering, no Godot node dependencies → fully headless-testable.

### 4.5 `PerFaceProjector`
- The mathematical heart: a family of affine transforms, one per face orientation (4 vertical orientations under the vertex-aligned compass, per `DIRECTION_GLOSSARY.md`) + the cap variant (both-axis diamond compression — implemented for completeness; unused by facades in v1 since caps are material-only, per D7).
- `tile_px_to_flat(face, tile_px) -> flat_px` and its forward inverse, both pure static.
- Integer-shear property is **asserted**, not assumed: the selftest verifies every per-column offset is an integer at the pinned N.
- Built on the outcome of the **Tile Anatomy Audit** (BAKE-01): the authoritative extraction of which tile pixels belong to which voxel face in the current canonical tileset. No transform is written before that ground truth exists. (SLICE-00 lesson: diagnose geometry before touching it.)

### 4.6 `BakeCompositor`
- Orchestrates Stages 2–5. Inputs: compiled map + Edge Registry + resolver + registry + projector. Output: registered atlas source(s) + populated lookup.
- One `SubViewport`, one frame, one capture (Stage 4).
- Logs: bake set size pre/post dedup, atlas page count, wall-clock time. These numbers gate the disk-cache decision (D4: measure first).

### 4.7 `BakedTileLookup`
- The drop-in seam (Stage 6). Owns the `BakeKey → (source_id, atlas_coords)` map and the enabled/disabled branch.
- The **only** module the live placement path touches. Everything else is upstream of it.

### 4.8 `ThemeApplier`
- `apply(color)` / `clear()`. Single call site on the wall layer(s). Future per-wall themes = alternative tiles with own `modulate` — noted, not built.

### 4.9 Debug & validation tooling
- **Theme Matrix view** (F-key, joining the F2/F3/F4 family): renders all materials × all themes in a grid. Calibrate D9 saturations by eye, not theory.
- **Bake Inspector:** dumps material atlas and baked atlas pages to `user://debug/*.png` on demand.
- **Probe pattern:** a synthetic facade (corner-marked texel grid) baked and asserted against analytically expected screen positions derived from `TILE_OFFSET (112, 64)` and canon constants — turning the old empirical F2/F3/F4 calibration into an **automated regression check**.

---

## 5. New Invariants (proposed additions to the project rule set)

| # | Invariant | Enforcement |
|---|-----------|-------------|
| B1 | Baked and generic rendering branches are mutually exclusive; the only branch point is `BakedTileLookup`. | Code review + grep check in `check_invariants.py` (no direct atlas-source references in placement code). |
| B2 | FACADE and PATTERN sources are grayscale; hue only from `base_color × theme`. | Resolver validation (reject colored facades) + authoring guideline. |
| B3 | Alpha/silhouette comes exclusively from the canonical material atlas. The bake pipeline never generates shape. | Compositor shader contract + BAKE selftest. |
| B4 | Bake determinism: window origins via project-owned FNV-1a over canonical `WallEdgeData` keys; never engine `hash()`. | Selftest with pinned expected values. |
| B5 | Destruction never re-bakes. Exposed geometry renders from the material atlas. | Design (no invalidation path exists) + BAKE-07 test. |
| B6 | Selftests fail loudly on missing dependencies — no silent `load()` of removable paths. | Selftest template rule (slice_geometry_selftest scar). |

B1 and B4 are candidates for the pre-commit hook; B2/B3/B5/B6 are runtime/selftest-enforced.

---

## 6. Capacity & Performance Analysis

- One baked tile: 32×16 RGBA8 = **2 KB**.
- Hard upper bound per (material, facade, variant, orientation): the plane itself = 64×32 = 2,048 tiles. Realistic maps sample a small fraction of the plane; dedup (Stage 2) collapses repeated windows.
- A 4096×4096 atlas page holds 128 × 256 = **32,768 tiles** (64 MB VRAM). One page covers any realistic map; overflow spawns additional sources at zero architectural cost (§3 Stage 5).
- Bake cost: one batched GPU frame + one readback. Budget: **< 100 ms** at map load; BAKE-04 logs actuals. If (and only if) measurements violate the budget, the deferred disk cache (D4) re-enters discussion.
- Facade file: `64N × 32N` grayscale PNG — small (illustratively, N=16 → 1024×512). Download-friendly by construction.
- Zoom-out + NEAREST produces decimation shimmer on fine facade detail. Accepted as low-poly aesthetic in v1; measured before any mitigation (mip-like pre-decimated variants would be the lever — deferred).

---

## 7. Risk Register (scar-informed)

| Risk | Scar it echoes | Mitigation |
|------|----------------|------------|
| Baked tiles misaligned vs canon geometry | `texture_region_size`/`texture_origin`/`TILE_OFFSET` calibration saga (SLICE-02) | Alpha-from-canon (B3), identical region/origin values by construction, automated probe regression (§4.9), BAKE-07 assertions. |
| Both rendering branches active simultaneously | SLICE-02 Stage A branch-exclusivity bug | Single lookup seam (B1); exclusivity asserted in BAKE-05 PASS evidence. |
| Selftest silently broken by future refactors | `slice_geometry_selftest` runtime `load()` of deleted file | B6: loud-fail template; no dynamic loads of deletable paths. |
| Blend produces mud (saturated × saturated) | Overlay/multiply analysis, this session | D9 discipline + Theme Matrix view; per-theme documentation of intended effect. |
| Method-extraction drift during swap | ENHANCE-04b rotation bug (dead correct code + live broken copy) | BAKE-05 is a *seam insertion*, not an extraction: placement keeps its code, gains one lookup call. Old direct-source references deleted in the same prompt, verified by grep. |
| SubViewport capture timing errors | — | Canon pattern: `UPDATE_ONCE` + single `await frame_post_draw`; BAKE-04 PASS requires capture evidence. |
| GDScript per-pixel loops too slow | — | GPU batch is canon (D4); CPU paths exist only inside headless selftests on tiny synthetic images. |
| Invalid/hostile files in `user://textures/` | — | Resolver validation: decode check, dimension contract, size cap, tier fallback (§4.2). |

---

## 8. Validation Strategy & Evidence

Three tiers, all subject to the OPERATOR_CONTEXT evidence rule (**PASS requires literal console output**):

- **T1 — Pure math (headless-safe):** projector transforms, integer-shear assertion, mirrored-repeat addressing, FNV-1a determinism with pinned expected hashes, window-origin derivation. Print explicit `PASS:` lines per case.
- **T2 — Render (runtime):** compositor capture completes; tile count matches deduped key count; probe-pattern alignment vs analytic expectation; branch-exclusivity toggle produces identical cell sets with different source IDs; destruction on a baked wall exposes material tiles without re-bake. PNG dumps to `user://debug/` accompany console evidence.
- **T3 — Visual (human):** Theme Matrix grid; side-by-side flag toggle screenshots; book-matching seam inspection on marble and wood.

The BAKE selftest suite extends the Transform Canon selftest family and must comply with B6.

---

## 9. Prompt Sequence

Each prompt is self-contained for K4PUTZ, follows OPERATOR_CONTEXT, and carries explicit PASS criteria. Estimated sizes assume the ≤300-line module targets.

| Prompt | Scope | Key deliverables | PASS evidence |
|--------|-------|------------------|---------------|
| **TEX-CATALOG-01** | The contract: category definitions (MATERIAL/FACADE(+SLICE)/STICKER-reserved), naming scheme, pinned dimensions & N, directory layout, grayscale rule, theme guidelines. Implements `TextureResolver`. | `TEXTURE_CATALOG.md`, `texture_resolver.gd` + selftest | Resolver tier-fallback log lines for: user hit, default hit, invalid-file fallthrough, material-only. |
| **BAKE-01** | **Tile Anatomy Audit** + `PerFaceProjector`. Extract authoritative tile-pixel→face mapping from the canonical tileset; then implement the transform family; pin N; assert integer shear. | `TILE_ANATOMY.md`, `per_face_projector.gd` + T1 selftest | Literal PASS lines: per-orientation transform round-trips; integer-offset assertions at pinned N. |
| **BAKE-02** | `MaterialRegistry` + stone/wood/metal algorithms + K=4 variant atlas generation (canonical geometry). | `material_registry.gd`, `pattern_*.gd`, atlas dump | Console: atlas dimensions/regions asserted; `user://debug/material_atlas.png` produced. |
| **BAKE-03** | `FacadeSampler`: mirrored-repeat, FNV-1a origins, run-continuity addressing. | `facade_sampler.gd` + T1 selftest | PASS lines incl. mirror-boundary cases and pinned hash values (synthetic corner-marked facade). |
| **BAKE-04** | `BakeCompositor`: bake set construction, dedup, SubViewport batch, capture, atlas assembly. | `bake_compositor.gd`, compositor shader | Console: pre/post-dedup counts, page count, timing < budget; atlas page dump. |
| **BAKE-05** | **Drop-in swap**: `BakedTileLookup` + `BakeConfig` wiring into placement; delete direct source references; resolve build→bake→placement sequencing against real `room_builder.gd` flow (§11-I2). | `baked_tile_lookup.gd`, `bake_config.gd`, placement diff | Toggle test: identical cell coordinate sets, differing source IDs, both directions; grep proof of no residual direct references. |
| **BAKE-06** | `ThemeApplier` + Theme Matrix debug view (next free F-key). | `theme_applier.gd`, debug view | Matrix screenshot + logged modulate values per cell. |
| **BAKE-07** | BAKE selftest consolidation: probe-pattern alignment regression, destruction interaction, B-invariant assertions. Extend `check_invariants.py` with B1/B4 greps. | Selftest suite, hook update | Full T1+T2 PASS transcript; destruction test log. |
| **BAKE-08** | Resolver integration hardening end-to-end with `user://` content: corrupt file, wrong dimensions, oversized, missing — every tier exercised in a live map load. | Hardening patch if needed | Log transcript showing each fallback tier hit during real bake. |
| **ARCHIVE** | Session archival per protocol: `PROMPTS/DONE/`, `CODEMAP.md`, session summary, `OPERATOR_CONTEXT.md` delta if any. | Archival commit | Standard archival checklist. |

Sequencing rationale: **math before pixels, pixels before swap.** BAKE-01..03 are pure and headless-testable — all risk is retired before the first SubViewport exists. BAKE-04 renders. BAKE-05 is the only prompt that touches live code, and by then every upstream component is proven. 06–08 are polish, tooling, and hardening on a working system.

---

## 10. Out of Scope (Deferred Register)

| Item | Earliest slot | Notes |
|------|---------------|-------|
| Multi-storey wall placement | Own feature series | Facade contract is forward-compatible (vertical axis exists); bake v1 consumes storey row 0 only. |
| STICKER implementation | v1.5 | Compositor slot reserved (alpha-over after multiply stack, before capture — one extra draw per sticker in the same pass). |
| Water / translucent materials | v2 | Requires relaxing B3 for `translucent`-flagged materials + likely tile animation. |
| Disk cache of baked atlases | Only if BAKE-04 timings demand | Measure first (D4). |
| Mid-mission texture hot-reload | Future enhancement | Downloads apply at next map load. |
| 4× cutscene assets | Not planned | Authorial position on cutscenes is… settled. |
| Per-wall theme tints | Future | Lever identified: alternative tiles with own `modulate`. |
| Zoom-out shimmer mitigation | Only if measured objectionable | Pre-decimated facade variants would be the mechanism. |

---

## 11. Open Integration Points & Authorial Vetoes

**Integration points (resolved during implementation, against real code):**

- **I1 — Storey row source.** Until multi-storey placement exists, `plane_row = 0` for runs; isolated walls may still hash the row for variety (Stage 3). Confirm no current system implies a storey index.
- **I2 — Build→bake→placement sequencing.** The compositor needs the Edge Registry populated before keys can be built, and placement needs the lookup populated before cells are set. Two viable shapes: (a) two-phase build (geometry pass → bake → placement pass), or (b) place with generic tiles, then re-`set_cell` with baked sources post-bake (cells are cheap to re-set; Rule #8 preserved either way). BAKE-05 decides against the actual `room_builder.gd` flow.

**Authorial vetoes requested before TEX-CATALOG-01 is written:**

- **V1 — Material atlas generated at boot** by the pattern algorithms (vs. authored/pre-rendered image files). Plan assumes *generated* (§4.3 rationale). Veto restores authored files with no structural change — the registry would load instead of generate.
- **V2 — K = 4 variants** per material in v1.
- **V3 — STICKER deferral** to v1.5 with the compositor slot reserved (D11).
- **V4 — Debug F-key assignment** for the Theme Matrix view (next free slot after F4 assumed).

---

*End of plan. Upon approval (and V1–V4 resolution), the next outputs are TEX-CATALOG-01 followed by BAKE-01, per §9.*

---

## ADDENDUM — 2026-07-07: BAKING_SYSTEM_MASTER_FIX Implementation Notes

This document served as the authoritative architectural specification for the baking system. However, implementation revealed that the original design required refinement:

### What Was Superseded

**Stage 5 (§3.5) Conflation:** The original plan stated `texture_region_size = VOXEL_TILE_SIZE (32×16)`, conflating this with the real atom size (32×36 pixels, the full voxel face height). Implementation clarified: the tile size stays 32×16 (canonical Godot cell size), but texture composition operates at the full voxel face scale. This is correctly reflected in `BAKING_SYSTEM_MASTER_FIX.md`.

**§4.5 (PerFaceProjector) Approach:** The per-face affine shear transforms described here were designed for per-wall-face baking at placement time. The actual implementation (BAKE-FIX-01/02) achieved the same result via a **master-strip baking approach**: facade sampler operates on infinite mirrored planes, edges are grouped into runs for continuity, and the junction column implementation (BAKE-FIX-02) handles multi-edge wall silhouettes. The mathematical foundation (D5 infinite plane + FNV-1a determinism) is identical; the orchestration is simpler.

**D5 Facade Model Refinement:** This document specified both "isolated" (per-wall) and "run" (contiguous) addressing modes. The implementation found that **run-continuity was the only mode wired** before BAKE-FIX-02; the isolated mode concept survived but was not previously functional. BAKE-FIX-02 completed the run grouping + junction column framework, making both modes available for future use.

### What Remains Canon

- **Decision D1 (MULTIPLY blend)** — Exact, implemented in `BakeCompositor`.
- **Decision D5 (infinite deterministic plane via mirrored-repeat)** — Exact, implemented in `FacadeSampler`.
- **Determinism via project-owned FNV-1a** — Exact, verified in multiple selftests.
- **Alpha from canonical material tiles** — Exact, B3 invariant enforced.
- **No re-bake on destruction** — Exact, never implemented a re-bake path.

### Reference Documentation

**Authoritative implementation spec:** `BAKING_SYSTEM_MASTER_FIX.md`
- BAKE-FIX-01: Strip baking + facade sampler + run grouping
- BAKE-FIX-02: Junction column implementation + run grouping completion
- BAKE-FIX-03: Pixel-identical shape comparison validation (B3 closure)
- Phase 5 (deferred): Secondary baking per HighWall (per-texture overlays)

This addendum does not alter the canonical decisions or risk analysis. It clarifies the orchestration path taken during implementation.
