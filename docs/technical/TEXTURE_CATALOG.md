# Texture Catalog — Baking System Contract

**Companion docs:** `BAKING_MASTER_PLAN.md`, `DIRECTION_GLOSSARY.md`, `VOXEL_MASTER_PLAN.md`

---

## Overview

The Texture Catalog defines the contract for all textures consumed by the baking pipeline. It specifies four categories (FACADE, MATERIAL, SLICE, STICKER), their authoring model, dimensions, naming conventions, and sourcing rules. This document is the **definitive reference** for texture validation and authoring.

---

## Part A: Texture Categories

### Category 1: FACADE

**Role:** The infinite authorial plane (via mirrored-repeat) that all vertical wall faces sample from.

**Authoring model:** Orthographic, flat (no skew). Grayscale only.

**Dimensions:** `(64N) × (32N)` pixels, where `N` = flat texels per voxel (constant `TEX_AUTHORING_N`, pinned by BAKE-01).
- Concrete example (N=16): **1024 × 512** pixels.
- 8 edges (columns) × 4 storeys (rows) = 64 voxel-columns × 32 voxel-rows.

**Physical interpretation:** One edge = 8 voxels wide; one storey = 8 voxels tall (equals 1 GU, per BAKING_MASTER_PLAN D6).

**File format:** PNG, 8-bit grayscale (RGB channels forbidden — enforced by resolver).

**Naming convention:** `facade_{material_id}_{variant}.png`
- `material_id` ∈ {stone, metal, wood, …} — extensible registry, no enum.
- `variant` ∈ {base, a, b, c, …} — semantic name or letter.
- Example: `facade_stone_base.png`, `facade_wood_a.png`, `facade_metal_base.png`.

**Sourcing:** Downloaded facades land in `user://textures/`. Defaults ship in `res://textures/defaults/`.

**Fallback on missing/invalid:** → MATERIAL-only (no facade overlay).

---

### Category 2: MATERIAL

**Role:** Base color + pattern algorithm for the voxel tiles of a given material (stone, wood, metal, etc.).

**Authoring model:** Not a file. A code registry entry: `{ id, base_color, pattern_alg, flags }`.

**Examples:**
- Stone: `{ id="stone", base_color=Color(0.7, 0.7, 0.7), pattern_alg=StonePattern(), flags=0 }`
- Wood: `{ id="wood", base_color=Color(0.6, 0.35, 0.15), pattern_alg=WoodPattern(), flags=0 }`
- Metal: `{ id="metal", base_color=Color(0.5, 0.55, 0.6), pattern_alg=MetalPattern(), flags=0 }`

**Pattern algorithm signature:**
```gdscript
pattern_alg.shade(voxel_xy: Vector2i, face: Face, seed: int) -> float  # [0, 1]
```
Pure, deterministic function. Returns a luminance multiplier. Seed is derived from the GU position.

**K = 4 variants per material:** Each pattern generates 4 canonical tile variants (the pattern is sampled with seed offset by variant index). Variants are generated at boot into the material atlas (persistent, canonical geometry inherited from existing tileset).

**Fallback:** MATERIAL is always resident (no download, no fallback).

**Naming:** Registry ID only; no files. Examples: `stone`, `metal`, `wood`, `grass` (future).

---

### Category 3: SLICE (Unified with FACADE)

**Role:** Individual, single-wall texture override. A facade that is 1 edge × 1 storey (8×8 voxels).

**Authoring model:** Same as FACADE — orthographic, flat, grayscale.

**Dimensions:** `8N × 8N` pixels.

**Naming convention:** `slice_{edge_key}_{variant}.png`
- `edge_key` = the canonical `WallEdgeData` hash (deterministic, unique per edge).
- `variant` as for facades (base, a, b, c).
- Example: `slice_0x3a2f1b_base.png`.

**Sourcing:** Same chain as FACADE — `user://textures/` → `res://textures/defaults/`.

**Fallback:** → MATERIAL-only.

**Implementation note:** SLICE is not a separate sampler. It reuses the FACADE sampler with plane_window = (0, 0) and plane_size = (1, 1) internally. One code path, two naming conventions.

---

### Category 4: STICKER (Reserved)

**Role:** Optional alpha-over layer, applied after the multiply stack, before atlas capture.

**Status:** Slot reserved in the compositor. Implementation deferred to v1.5.

**Naming convention:** `sticker_{edge_key}_{variant}.png` (future).

**Fallback:** → no sticker (alpha-over is a no-op).

---

## Part B: Directory Layout

```
res://textures/defaults/
├── facade_stone_base.png
├── facade_wood_base.png
├── facade_metal_base.png
└── (other default facades)

user://textures/  (downloaded content, runtime-created)
├── facade_stone_base.png
├── facade_wood_a.png
├── facade_metal_custom.png
├── slice_0x3a2f1b_base.png
└── (dynamic downloads)
```

**Resolution logic:**
1. Check `user://textures/{filename}`.
2. If missing or invalid → check `res://textures/defaults/{filename}`.
3. If missing or invalid → material-only (no facade applied).

Each tier reports its result to the log (evidence-friendly for validation).

---

## Part C: Dimension Derivation

The pinnacle constant is **N = flat texels per voxel**, derived from the Tile Anatomy Audit (BAKE-01):

```
N = TBD (after Tile Anatomy Audit in BAKE-01)
    Currently pinned as: TEX_AUTHORING_N = 16 (example: 1024×512 facades)

Facade dimensions:
  width  = 64 voxels × N texels = 64N pixels
  height = 32 voxels × N texels = 32N pixels

Slice dimensions:
  width  = 8 voxels × N texels = 8N pixels
  height = 8 voxels × N texels = 8N pixels

VOXEL_TILE_SIZE (existing canon): 32×16 pixels (on-screen, isometric)
VOXEL_STEP_PX (existing canon): 20.0 pixels (pre-skew step size)
```

**TextureResolver validates uploaded facades against the TEX_AUTHORING_N constant and rejects mismatches** (fallback to next tier).

---

## Part D: Authoring Guidelines

### D.1 FACADE Authoring

**Orthographic view:** No perspective distortion. Render flat, as if viewing the wall surface head-on.

**Grayscale enforcement (D9):** Facades must be purely luminance; hue comes from MATERIAL base_color. This preserves the multiplicative chain: `base_color × pattern_shade × facade_lum × theme_color`. Colored facades will be rejected by the resolver.

**Veins/cracks:**
- Design at the full width (8 edges = 64N pixels horizontally) so horizontal continuity is unambiguous. When a wall crops a window from the plane, veins flow consistently.
- "Book-matching" seams (mirror-reflected boundaries) are intentional and acceptable — a real stone-finishing technique, part of the intended aesthetic.

**Vertical continuity (4 storeys = 32N pixels):**
- Design veins to flow top-to-bottom, or break them deliberately at storey boundaries.
- Current system uses row 0; rows 1–3 are placeholders for future multi-storey support.

**Resolution:**
- Measure facade source files once N is pinned in BAKE-01. Example: N=16 → 1024×512.
- Keep final PNG size < 1 MB for friendly downloads.
- Workflow: author at 2× or 4× working resolution (for crisp detail), then downsample to final N-pinned dimensions using NEAREST resampling to preserve pixel fidelity.

---

### D.2 MATERIAL Authoring (Pattern Algorithms)

**Base color:** Pick a representative hue for the material (stone gray, wood brown). This dominates when facade is absent (caps, cores, destruction).

**Pattern algorithm:** Implement as a pure function. Seed is derived from position; deterministic output.

**Algorithm examples:**
- **Stone:** Per-voxel luminance jitter. Seeded randomness in ±5–10% range (e.g., `base_luminance * (0.9 + 0.2 * noise(seed))`). Creates granular texture.
- **Wood:** Columnar grooves. Periodic function with period = 2 voxels (coarse lines). Vertical is the axis of symmetry; horizontal grooves recede.
- **Metal:** Sheen band. Smooth gradient across the face, 8 steps per edge (banding intended; low-poly aesthetic). Implement as `sin(voxel_x * 0.785) * 0.5 + 0.5` (8 steps in 64 pixels).

**Variant generation:** K = 4 variants per material. Generate at boot by offset-seeding: variant 0 uses seed, variant 1 uses seed+1, etc. Offset is large enough to avoid visual similarity (use large prime; e.g., seed + 10007).

---

### D.3 THEME Color Guidelines (Discipline D9)

**Saturation rule:** Themes are soft tints. Target HSV saturation < 0.3 for "normal" themes (office, basement), allowing the MATERIAL base color to dominate. Higher saturation (0.3–0.6) is acceptable if intended as a dominant filter (e.g., alarm-mode red, stealth-mode shadows) — **document per theme**.

**Value (brightness):** Keep V ≥ 0.6 in normal modes. Darker values (V < 0.6) darken all surfaces; use sparingly.

**Math test:** `base_color × theme` should remain visually recognizable as the material. Test in the Theme Matrix debug view (BAKE-06).

**Examples:**
- Normal office: `Color(0.95, 0.95, 1.0)` (very slightly cool white) — multiply by any material keeps hue intact, slight cool cast.
- Alarm/red filter: `Color(1.0, 0.2, 0.2)` (saturated red) — valid **only if documented** as "alarm state visual feedback," not accidental.

---

### D.4 SLICE (Bespoke Edge Override)

Same grayscale, orthographic rules as FACADE, but author at `8N × 8N` (single voxel window, 1 edge × 1 storey).

Useful for hand-crafted hero geometry (e.g., a scarred metal door frame, a carved stone entrance). Place at canonical edge hash location.

**Expected usage:** Rare. If authoring many SLICEs, consider folding them into a FACADE variant instead.

---

## Part E: Validation Rules (Resolver Enforcement)

Every texture loaded by the resolver is validated on resolve:

1. **Format check:** Grayscale PNG (luminance-only, no RGB channels used redundantly).
   - Accept: 8-bit grayscale.
   - Reject: RGB or RGBA colored (log WARN; next tier).

2. **Dimension contract:** Must match the expected size for its category.
   - **FACADE**: `width == 64 * TEX_AUTHORING_N && height == 32 * TEX_AUTHORING_N`.
   - **SLICE**: `width == 8 * TEX_AUTHORING_N && height == 8 * TEX_AUTHORING_N`.
   - On mismatch: log WARN; next tier.

3. **File size cap:** Reject files > 10 MB (guard against pathological downloads).
   - Log WARN; next tier.

4. **Corrupt decode:** If `Image.load_from_file()` fails or returns null, log WARN; next tier.

---

*End of Texture Catalog. This document is the authoritative contract for baking system texture sources.*
