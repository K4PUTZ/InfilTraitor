# TEX-CATALOG-01: Texture Catalog Contract & TextureResolver

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `TEXTURE_CATALOG.md` (reference), `texture_resolver.gd` module + selftest
**Companion:** `BAKING_MASTER_PLAN.md` §9, BAKING_SYSTEM master decisions D1–D11
**Status:** Ready for implementation
**PASS criteria:** All resolver fallback tiers exercised with literal console log lines; catalog contract dimensions verified against canonical constants

---

## Context

The baking system sources textures via a **resolver** that (a) defines the directory & file contract, (b) validates on load, and (c) implements a deterministic fallback chain. This prompt writes the contract and the resolver; it is the **first upstream module** the rest of the pipeline depends on.

Critical dependencies already closed:
- Multiply blend mode (D1)
- Render-time theme `modulate` (D2)
- Single-pass inverse mapping (D3)
- 1× screen-native authoring resolution (D8)
- Grayscale sources, hue from `base_color × theme` (D9)

---

## Part A: Texture Catalog — The Contract

### A.1 Four Categories

The system recognizes exactly four texture categories. A map spec may reference any category; unresolved references degrade per the fallback chain (§B.2).

#### Category 1: FACADE
**Role:** The infinite authorial plane (mirrored-repeat) that all vertical wall faces sample from.

**Authoring model:** Orthographic, flat (no skew). Grayscale only.

**Dimensions:** `(64N) × (32N)` pixels, where `N` = pinned "flat texels per voxel" constant, TBD in BAKE-01 after Tile Anatomy Audit.
- Concrete example (N=16): **1024 × 512** pixels.
- 8 edges (columns) × 4 storeys (rows) = 64 voxel-columns × 32 voxel-rows.

**Physical interpretation:** One edge = 8 voxels wide; one storey = 8 voxels tall (equals 1 GU, per BAKING_MASTER_PLAN D6).

**File format:** PNG, 8-bit grayscale preferred (RGB disallowed — enforced by resolver, see §B.2).

**Naming convention:** `facade_{material_id}_{variant}.png`
- `material_id` ∈ {stone, metal, wood, …} — extensible registry, no enum.
- `variant` ∈ {base, a, b, c, …} — semantic name or letter. Future: deterministic content-hash variant selection (deferred, v1.5).
- Example: `facade_stone_base.png`, `facade_wood_a.png`, `facade_metal_base.png`.

**Sourcing:** Downloaded facades land in `user://textures/`. Defaults ship in `res://textures/defaults/`.

**Fallback on missing/invalid:** → MATERIAL-only (see §B.2, tier fallthrough).

#### Category 2: MATERIAL
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
Pure, deterministic function. Returns a luminance multiplier. Seed is derived from the GU position (§C.3).

**K = 4 variants per material:** Each pattern generates 4 canonical tile variants (the pattern is sampled with seed offset by variant index). Variants are generated at boot into the material atlas (persistent, canonical geometry inherited from existing tileset).

**Fallback:** MATERIAL is always resident (no download, no fallback).

**Naming:** Registry ID only; no files. Examples: `stone`, `metal`, `wood`, `grass` (future).

#### Category 3: SLICE (Unified with FACADE, no separate handling)
**Role:** Individual, single-wall texture override. A facade that is 1 edge × 1 storey (8×8 voxels).

**Authoring model:** Same as FACADE — orthographic, flat, grayscale.

**Dimensions:** `8N × 8N` pixels.

**Naming convention:** `slice_{edge_key}_{variant}.png`
- `edge_key` = the canonical `WallEdgeData` hash (deterministic, unique per edge).
- `variant` as for facades (base, a, b, c).
- Example: `slice_0x3a2f1b_base.png`.

**Sourcing:** Same chain as FACADE — `user://textures/` → `res://textures/defaults/`.

**Fallback:** → MATERIAL-only.

**Implementation note:** SLICE is not a separate sampler. It reuses the FACADE sampler with `plane_window = (0, 0)` and `plane_size = (1, 1)` internally. One code path, two naming conventions (one for procedural run samplings, one for bespoke edge overrides).

#### Category 4: STICKER (Reserved, implementation deferred to v1.5)
**Role:** Optional alpha-over layer, applied after the multiply stack, before atlas capture.

**Status:** Slot reserved in the compositor (§BAKING_MASTER_PLAN §4.6). No files loaded in v1.

**Naming convention:** `sticker_{edge_key}_{variant}.png` (future).

**Fallback:** → no sticker (alpha-over is a no-op).

---

### A.2 Unified Directory Layout

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

Each tier reports its result to the log (evidence-friendly, §B.2).

---

### A.3 Dimension Derivation (BAKE-01 will pin N)

The pinnacle dimension constant is **N = flat texels per voxel**, derived from the Tile Anatomy Audit (BAKE-01). The entire catalog scales from this one value:

```
N = TBD (after Tile Anatomy Audit in BAKE-01)

Facade dimensions:
  width  = 64 voxels × N texels = 64N pixels
  height = 32 voxels × N texels = 32N pixels

Slice dimensions:
  width  = 8 voxels × N texels = 8N pixels
  height = 8 voxels × N texels = 8N pixels

VOXEL_TILE_SIZE (existing canon): 32×16 pixels (on-screen, isometric)
VOXEL_STEP_PX (existing canon): 20.0 pixels (pre-skew step size)
```

This prompt **assumes N is provided as a pinned constant**, `TEX_AUTHORING_N`, injected by BAKE-01. TextureResolver validates uploaded facades against this value and rejects mismatches (fallback to next tier).

**Current placeholder:** N = 16 (example: 1024×512 facades, 128×128 slices). **Do not bake this into code; use `TEX_AUTHORING_N` constant from a shared header.**

---

## Part B: TextureResolver Module

### B.1 Interface

```gdscript
class_name TextureResolver

# Single entry point: resolve by ID, return the image or null-with-log
func resolve(texture_id: String) -> ResolvedTexture:
    # ResolvedTexture = { image: Image, tier: Tier }
    # Tier ∈ { USER, DEFAULT, NONE }
    # image is null iff tier == NONE
```

Usage in baking pipeline:
```gdscript
var facade_stone = resolver.resolve("facade_stone_base")
if facade_stone.tier == TextureResolver.Tier.NONE:
    print("WARN: facade_stone_base unresolved; wall will be material-only")
else:
    print("INFO: facade_stone_base resolved from ", facade_stone.tier)
    # ... proceed to bake
```

### B.2 Resolution Algorithm (Deterministic Fallback Chain)

For a requested `texture_id`:

```
1. Attempt load from user://textures/{texture_id}.png
   ├─ Success → validate (B.3) → return { image, USER }
   ├─ File not found → proceed to step 2
   ├─ Decode fails → WARN + proceed to step 2
   └─ Validation fails (§B.3) → WARN + proceed to step 2

2. Attempt load from res://textures/defaults/{texture_id}.png
   ├─ Success → validate (B.3) → return { image, DEFAULT }
   ├─ File not found → proceed to step 3
   ├─ Decode fails → WARN + proceed to step 3
   └─ Validation fails → WARN + proceed to step 3

3. No texture available → return { null, NONE }
   └─ Log WARN: "texture_id unresolved; caller reverts to material-only"
```

Every transition logs a single evidence line:

```gdscript
# Step 1 hit:
"[RESOLVER] facade_stone_base resolved from USER (dims 1024×512, 512 KB)"

# Step 1 fail, step 2 hit:
"[RESOLVER] facade_stone_base SKIP user:// (not found); resolved from DEFAULT (dims 1024×512)"

# Both fail:
"[RESOLVER] facade_stone_base SKIP user://; SKIP default://; reverted to MATERIAL-ONLY"
```

### B.3 Validation (on every successful decode, regardless of tier)

For every loaded image, validate:

1. **Format check:** Grayscale PNG (luminance-only, no RGB channels used redundantly).
   - Accept: 8-bit grayscale.
   - Reject: RGB or RGBA colored (log WARN; next tier).
   - Rationale: D9 (grayscale sources only); multiply of color × color = mud.

2. **Dimension contract:** Must match the expected size for its category.
   - **FACADE**: `width == 64 * TEX_AUTHORING_N && height == 32 * TEX_AUTHORING_N`.
   - **SLICE**: `width == 8 * TEX_AUTHORING_N && height == 8 * TEX_AUTHORING_N`.
   - On mismatch: log WARN; next tier.

3. **File size cap:** Reject files > 10 MB (guard against pathological downloads).
   - Log WARN; next tier.

4. **Corrupt decode:** If `Image.load_from_file()` fails or returns null, log WARN; next tier.

Validation happens synchronously on resolve; no lazy loads.

### B.4 Implementation Sketch

```gdscript
class_name TextureResolver

enum Tier { USER, DEFAULT, NONE }

class ResolvedTexture:
    var image: Image
    var tier: Tier

const TEX_AUTHORING_N = TEX_AUTHORING_N  # Injected from shared constants
const TEX_AUTHORING_N_USER = "user://textures/"
const TEX_AUTHORING_N_DEFAULT = "res://textures/defaults/"
const MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

var log_lines: PackedStringArray = []

func resolve(texture_id: String) -> ResolvedTexture:
    # Attempt user://
    var user_path = TEX_AUTHORING_N_USER.path_join(texture_id + ".png")
    var img = _try_load_and_validate(user_path)
    if img:
        _log("resolved from USER: %s (dims %dx%d)" % [texture_id, img.get_width(), img.get_height()])
        return ResolvedTexture.new(img, Tier.USER)
    
    # Attempt default://
    var default_path = TEX_AUTHORING_N_DEFAULT.path_join(texture_id + ".png")
    img = _try_load_and_validate(default_path)
    if img:
        _log("resolved from DEFAULT: %s (dims %dx%d)" % [texture_id, img.get_width(), img.get_height()])
        return ResolvedTexture.new(img, Tier.DEFAULT)
    
    # Fallback: material-only
    _log("UNRESOLVED: %s; reverting to MATERIAL-ONLY" % texture_id)
    return ResolvedTexture.new(null, Tier.NONE)

func _try_load_and_validate(path: String) -> Image:
    if not ResourceLoader.exists(path):
        _log("SKIP %s (not found)" % path)
        return null
    
    var file_size = ResourceLoader.get_resource_type(path)  # Check file size first
    if file_size > MAX_FILE_SIZE:
        _log("SKIP %s (exceeds size cap)" % path)
        return null
    
    var img = Image.new()
    var err = img.load(path)
    if err != OK:
        _log("SKIP %s (decode failed: %s)" % [path, error_string(err)])
        return null
    
    # Validate grayscale
    if not _is_grayscale(img):
        _log("SKIP %s (not grayscale; colored facades violate D9)" % path)
        return null
    
    # Validate dimensions (caller must set expected dims context)
    if not _validate_dimensions(path, img):
        _log("SKIP %s (dimension mismatch)" % path)
        return null
    
    return img

func _is_grayscale(img: Image) -> bool:
    # Check if image uses only luminance (R=G=B in every pixel, or 8-bit gray format)
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var pixel = img.get_pixel(x, y)
            if pixel.r != pixel.g or pixel.g != pixel.b:
                return false
    return true

func _validate_dimensions(path: String, img: Image) -> bool:
    # Infer category from filename pattern
    var filename = path.get_file()
    var expected_w: int
    var expected_h: int
    
    if filename.begins_with("facade_"):
        expected_w = 64 * TEX_AUTHORING_N
        expected_h = 32 * TEX_AUTHORING_N
    elif filename.begins_with("slice_"):
        expected_w = 8 * TEX_AUTHORING_N
        expected_h = 8 * TEX_AUTHORING_N
    else:
        _log("WARN: %s has unrecognized category prefix" % filename)
        return false
    
    if img.get_width() != expected_w or img.get_height() != expected_h:
        _log("WARN: %s dims %dx%d, expected %dx%d" % [filename, img.get_width(), img.get_height(), expected_w, expected_h])
        return false
    
    return true

func _log(msg: String) -> void:
    var line = "[RESOLVER] " + msg
    print(line)
    log_lines.append(line)

func get_log() -> PackedStringArray:
    return log_lines.duplicate()
```

### B.5 Selftest

In `texture_resolver_test.gd`:

```gdscript
# Create synthetic facades/slices in res://textures/defaults/ and user:// (temp) for the test

func test_tier_user_hit():
    # Place facade_stone_base.png in user://textures/
    var result = resolver.resolve("facade_stone_base")
    assert(result.tier == TextureResolver.Tier.USER)
    assert(result.image != null)
    assert("resolved from USER" in resolver.get_log()[-1])
    print("PASS: tier_user_hit")

func test_tier_default_fallthrough():
    # Do NOT place in user://; ensure it exists in res://textures/defaults/
    var result = resolver.resolve("facade_wood_base")
    assert(result.tier == TextureResolver.Tier.DEFAULT)
    assert(result.image != null)
    assert("resolved from DEFAULT" in resolver.get_log()[-1])
    print("PASS: tier_default_fallthrough")

func test_tier_none_unresolved():
    # Request a facade that exists in neither tier
    var result = resolver.resolve("facade_nonexistent_xyz")
    assert(result.tier == TextureResolver.Tier.NONE)
    assert(result.image == null)
    assert("UNRESOLVED" in resolver.get_log()[-1])
    print("PASS: tier_none_unresolved")

func test_validation_grayscale_rejection():
    # Place a colored (RGB) image as facade_rgb_bad.png in user://
    var result = resolver.resolve("facade_rgb_bad")
    assert(result.tier == TextureResolver.Tier.NONE)  # Rejected at user; fell through; not in default
    assert("not grayscale" in resolver.get_log()[-2])
    print("PASS: validation_grayscale_rejection")

func test_validation_dimension_rejection():
    # Place a grayscale image with wrong dims (e.g., 512×512 instead of 1024×512)
    var result = resolver.resolve("facade_wrong_dims")
    assert(result.tier == TextureResolver.Tier.NONE)
    assert("dimension mismatch" in resolver.get_log()[-2])
    print("PASS: validation_dimension_rejection")

func test_validation_oversized_rejection():
    # Place a valid grayscale, correct-dim image > 10MB (synthetic: generate or mock)
    var result = resolver.resolve("facade_huge")
    assert(result.tier == TextureResolver.Tier.NONE)
    assert("exceeds size cap" in resolver.get_log()[-1])
    print("PASS: validation_oversized_rejection")
```

**PASS criteria:**
- All six test cases log literal PASS lines.
- Every resolver tier (USER, DEFAULT, NONE) is exercised.
- Grayscale validation rejects colored images with logged evidence.
- Dimension validation rejects mismatches with logged evidence.
- Size cap rejects oversized files with logged evidence.

---

## Part C: TextureResolver Integration Points

### C.1 Caller Side (BakeCompositor, §BAKING_MASTER_PLAN §4.6)

In `bake_compositor.gd`:

```gdscript
# At map load, after geometry is built:

func _bake_facades(map_spec: MapSpec) -> void:
    var resolver = TextureResolver.new()
    
    # Collect all unique facade/slice IDs referenced by the map
    var texture_ids = _collect_texture_ids_from_map(map_spec)
    
    for tex_id in texture_ids:
        var resolved = resolver.resolve(tex_id)
        if resolved.tier == TextureResolver.Tier.NONE:
            print("WARN: %s unresolved; walls using it will be MATERIAL-ONLY" % tex_id)
        else:
            # Proceed to bake (BAKE-04)
            pass
```

### C.2 Map Spec Contract

Maps declare textures by ID:

```gdscript
# In the map data structure:
class MapSpec:
    var walls: Array[Wall]
    # ...

class Wall:
    var edge: WallEdgeData
    var material: String = "stone"        # Unique registry ID
    var facade: String = "facade_stone_base"  # Texture ID or null
    var theme: Color = Color.WHITE        # Applied at render time, not bake time
```

If `wall.facade == null`, the wall renders material-only (no bake). If facade is specified but unresolved, the same fallback applies (log warns).

### C.3 Seed Derivation (for MATERIAL variant selection)

When baking a wall face, the variant index is chosen deterministically:

```gdscript
func _choose_material_variant(edge: WallEdgeData, face: Face, material_id: String) -> int:
    # Seed is hash of the canonical edge key + face orientation
    var seed = hash_u32(edge.key_string() + "_" + face.to_string())
    var variant_k = seed % 4  # K=4 variants
    return variant_k
```

Same seed always produces the same variant, deterministic across sessions.

---

## Part D: Authoring Guidelines (TEXTURE_CATALOG.md)

The `TEXTURE_CATALOG.md` reference document includes authoring rules for each category:

### D.1 FACADE Authoring
- **Orthographic view** (no perspective distortion).
- **Grayscale** (enforce D9). Hue comes from MATERIAL base_color.
- **Veins/cracks**: design at the full width (8 edges = 64N pixels horizontally) so horizontal continuity is unambiguous. When a wall crops a window from the plane, veins flow consistently. "Book-matching" seams (mirror-reflected boundaries) are intentional and acceptable (real stone-finishing technique).
- **Vertical continuity** (4 storeys = 32N pixels): design veins to flow top-to-bottom, or break them deliberately at storey boundaries. Current system uses row 0; rows 1–3 are placeholders for future multi-storey support.
- **Resolution:** N will be pinned in BAKE-01. At that point, measure facade source files (e.g., N=16 → 1024×512). Keep final PNG size < 1 MB for friendly downloads.
- **Example workflow:** author at 2× or 4× working resolution (for crisp detail), then downsample to final N-pinned dimensions. Use NEAREST resampling to preserve pixel fidelity.

### D.2 MATERIAL Authoring (Pattern Algorithms)
- **Base color:** pick a representative hue for the material (stone gray, wood brown). This is the dominant color when facade is absent (caps, cores, destruction).
- **Pattern algorithm:** implement as a pure function. Seed is derived from position (§C.3); deterministic output.
  - **Stone:** per-voxel luminance jitter. Seeded randomness in ±5–10% range (example: `base_luminance * (0.9 + 0.2 * noise(seed))`). Creates granular texture.
  - **Wood:** columnar grooves. Periodic function with period = 2 voxels (coarse lines). Vertical is the axis of symmetry; horizontal grooves recede.
  - **Metal:** sheen band. Smooth gradient across the face, 8 steps per edge (banding intended; low-poly aesthetic). Could implement as `sin(voxel_x * 0.785) * 0.5 + 0.5` (8 steps in 64 pixels).
- Generate K=4 variants at boot by offset-seeding: variant 0 uses seed, variant 1 uses seed+1, etc. Offset is large enough to avoid visual similarity (use large prime; e.g., seed + 10007).

### D.3 THEME Color Guidelines (D9 discipline)
- **Saturation rule:** Themes are soft tints. Target HSV saturation < 0.3 for "normal" themes (office, basement), allowing the MATERIAL base color to dominate. Higher saturation (0.3–0.6) is acceptable if intended as a dominant filter (e.g., alarm-mode red, stealth-mode shadows).
- **Value (brightness):** Keep V ≥ 0.6 in normal modes. Darker values (V < 0.6) darken all surfaces; use sparingly.
- **Mathrules for testing:** `base_color × theme` should remain visually recognizable as the material. Test in the Theme Matrix debug view (BAKE-06).
- **Examples:**
  - Normal office: `Color(0.95, 0.95, 1.0)` (very slightly cool white) — multiply by any material keeps hue intact, slight cool cast.
  - Alarm/red filter: `Color(1.0, 0.2, 0.2)` (saturated red) — valid *if documented* as "alarm state visual feedback," not accidental.

### D.4 SLICE (Bespoke Edge Override)
- Same grayscale, orthographic rules as FACADE, but author at 8N × 8N (single voxel window, 1 edge × 1 storey).
- Useful for hand-crafted hero geometry (e.g., a scarred metal door frame, a carved stone entrance). Place at canonical edge hash location.
- Expected usage: rare (most walls use FACADE tiling). If you author many SLICEs, consider folding them into a FACADE variant instead.

---

## Part E: Rollout Checklist

Before BAKE-02 (MaterialRegistry) can start:

- [ ] `texture_resolver.gd` written and selftest PASS achieved (all tiers, all validations).
- [ ] `TEXTURE_CATALOG.md` finalized (contract locked, authoring guidelines documented).
- [ ] `TEX_AUTHORING_N` constant placeholder in place (BAKE-01 will pin the value).
- [ ] Evidence transcript appended to session archive.

---

*End of TEX-CATALOG-01.*
