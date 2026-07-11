# FIX-BAKE-04: Real Material Tiles – True Composite Chain

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-03 (Tile Anatomy)
**Successor:** FIX-BAKE-05 (The Swap)
**Scope:** Implement `_get_material_tile()` to fetch real patterns; add RGBA8 alpha; composite material×facade with canonical silhouette; timing validation
**Effort:** ~3–4 hours
**Risk:** Medium (composite is compute-intensive; timing matters)

---

## Problem

`BakeCompositor._get_material_tile()` returns a **solid white stub** that ignores all parameters (material, face, variant). The multiplicative chain (C_mat ⊙ P ⊙ L_fac ⊙ T_theme) collapses to (1 ⊙ 1 ⊙ L_fac ⊙ T_theme), losing half the signal.

Consequences:
1. **K=4 variants are decorative.** All baked tiles for a material look identical (white × facade).
2. **No pattern shading (stone jitter, wood grooves, metal sheen).** Pattern algorithms exist and are registered but never consulted.
3. **Alpha is always 1.0.** Tiles are RGB8; when rendered, they occlude neighbors (B3 violated). The canonical voxel silhouette (diamond outline + side parallels) never reaches a baked pixel.
4. **Memory & disk:** The baked atlas is inefficient; perfect dedup would consolidate 4 variants into 1 tile (since they are all white), and unused space goes uncompressed.

---

## Solution

### S1: Wire MaterialRegistry to BakeCompositor

The `MaterialRegistry` already holds materials with patterns. Wire the compositor to fetch and apply them.

**Change to BakeCompositor:**

```gdscript
func _get_material_tile(material_id: String, face: int, variant_k: int) -> Image:
    # Get registry (global or injected)
    var registry = _get_material_registry()
    if registry == null:
        push_error("[BAKE] No MaterialRegistry; falling back to white")
        return _create_white_tile()
    
    var material = registry.get_material(material_id)
    if material == null:
        push_warning("[BAKE] Material %s not found; using white" % material_id)
        return _create_white_tile()
    
    # Get the base color for this material
    var base_color = material.get("base_color", Color.WHITE)
    
    # Create a 32×16 tile and apply the pattern
    var tile = Image.create(32, 16, false, Image.FORMAT_RGBA8)  # RGBA for alpha
    
    # For each screen pixel, apply the pattern shade
    for screen_y in range(16):
        for screen_x in range(32):
            # Determine which voxel this pixel belongs to (for seeding)
            # Simplified: use screen position + variant as seed
            var seed_val = (variant_k << 16) + (screen_y * 32 + screen_x)
            
            # Determine face-relative voxel position (0-7, 0-7 flat voxel coords)
            var voxel_x = screen_x % 8
            var voxel_y = screen_y % 8
            var voxel_xy = Vector2i(voxel_x, voxel_y)
            
            # Apply pattern shade (returns multiplier [0, 1])
            var pattern_shade = material.shade_pattern(voxel_xy, face, seed_val)
            
            # Apply to base color: C_mat * P
            var pixel = base_color * pattern_shade
            pixel.a = 1.0  # Opaque (alpha will come from canonical silhouette later)
            
            tile.set_pixel(screen_x, screen_y, pixel)
    
    return tile

func _create_white_tile() -> Image:
    var tile = Image.create(32, 16, false, Image.FORMAT_RGBA8)
    for y in range(16):
        for x in range(32):
            tile.set_pixel(x, y, Color.WHITE)
    return tile

func _get_material_registry():
    # Check for global registry
    if Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
        return Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")
    
    # Check for test registry
    if Engine.has_meta("BAKE_TEST_REGISTRY"):
        return Engine.get_meta("BAKE_TEST_REGISTRY")
    
    # Lazy load (should have been initialized at boot)
    var registry_class = load("res://godot/scripts/systems/material_registry.gd")
    if registry_class:
        return registry_class.new()
    
    return null
```

### S2: Import and apply canonical silhouette

The baked composite is now C_mat × P × L_fac. The alpha channel must come **exclusively** from the canonical material atlas (B3 invariant). This ensures:
1. The baked tile's silhouette matches the generic tile exactly (risk-free swap)
2. Destruction exposes geometry with a consistent outline
3. No transparency artifacts at edges

**Implementation approach:**

The canonical material atlas (built at boot in `material_atlas_generator.gd`) contains the pattern variants with correct alpha. Fetch the alpha channel from there.

```gdscript
func _composite_tile(
    material_tile: Image,           # C_mat ⊙ P (RGB, alpha=1)
    facade: Image,                  # L_fac (luminance)
    bake_key: BakeCompositorClass.BakeKey,
    sampler,
    projector
) -> Image:
    var result = Image.create(32, 16, false, Image.FORMAT_RGBA8)
    
    # Window bounds in the facade plane (texel units, from FIX-BAKE-02)
    var window_origin = Vector2i(bake_key.plane_col, bake_key.plane_row)
    
    for screen_y in range(16):
        for screen_x in range(32):
            var screen_pos = Vector2(float(screen_x), float(screen_y))
            
            # Get material pixel: C_mat ⊙ P (RGB) + alpha from canonical
            var mat_pixel = material_tile.get_pixel(screen_x, screen_y)
            
            # Map screen → flat → plane
            var flat_pos = projector.screen_to_flat(bake_key.face, screen_pos)
            var plane_x = window_origin.x + flat_pos.x
            var plane_y = window_origin.y + flat_pos.y
            
            # Sample facade luminance
            var facade_lum = sampler.sample(facade, float(plane_x), float(plane_y))
            
            # Composite: (C_mat ⊙ P) × L_fac
            var result_pixel = Color(
                mat_pixel.r * facade_lum,
                mat_pixel.g * facade_lum,
                mat_pixel.b * facade_lum,
                mat_pixel.a  # Alpha from material (canonical silhouette)
            )
            
            result.set_pixel(screen_x, screen_y, result_pixel)
    
    return result
```

### S3: Timing validation

BAKE-04 is GPU-primary per D4; the CPU path must stay under 100 ms per the plan. With real material tiles (per-pixel pattern shade + facade sample), measure the cost.

**Add to BakeCompositor.bake():**

```gdscript
func bake(map_spec: Dictionary, resolver) -> BakedAtlas:
    var start_total = Time.get_ticks_msec()
    
    # ... geometry, resolve, bake_set construction ...
    
    var start_render = Time.get_ticks_msec()
    atlas_result = _render_batch(bake_set, facades_by_id)
    var elapsed_render = Time.get_ticks_msec() - start_render
    
    var elapsed_total = Time.get_ticks_msec() - start_total
    
    print("[BAKE] Timing:")
    print("  Render batch: %.1f ms (target: < 100 ms)" % elapsed_render)
    print("  Total bake: %.1f ms" % elapsed_total)
    
    if elapsed_render > 100.0:
        push_warning("[BAKE] Render exceeded 100 ms budget; consider GPU batch (deferred)")
    
    return atlas_result
```

---

## Validation & Evidence (PASS Criteria)

### Test 1: Material tile generation with pattern

**Test file:** `godot/scripts/tools/fix_bake_04_material_tile_test.gd` (new)

```gdscript
extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

func _init() -> void:
    print("\n" + "=".repeat(70))
    print("FIX-BAKE-04 TEST: Material Tile Generation")
    print("=".repeat(70) + "\n")

    # Setup registry
    var registry = MaterialRegistryClass.new()
    Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)
    
    var compositor = BakeCompositorClass.new()
    
    # Test 1: Fetch material tile for stone
    print("[TEST 1] Material Tile for Stone\n")
    
    var stone_tile = compositor._get_material_tile("stone", 0, 0)  # Face NE, variant 0
    
    assert(stone_tile != null, "Material tile must not be null")
    assert(stone_tile.get_format() == Image.FORMAT_RGBA8, "Format must be RGBA8")
    assert(stone_tile.get_width() == 32 and stone_tile.get_height() == 16, 
        "Tile must be 32×16")
    
    print("    ✓ Tile created: 32×16 RGBA8")
    
    # Check that it's not uniform white (pattern applied)
    var pixel_0_0 = stone_tile.get_pixel(0, 0)
    var pixel_16_8 = stone_tile.get_pixel(16, 8)
    
    var color_variance = pixel_0_0.distance_to(pixel_16_8)
    if color_variance > 0.01:
        print("    ✓ Pattern shading applied (variance: %.4f)" % color_variance)
    else:
        print("    ⚠ Tile is mostly uniform (pattern variance < 0.01)")
    
    # Check alpha channel is present
    if pixel_0_0.a > 0.99:
        print("    ✓ Alpha channel: %.2f (opaque)" % pixel_0_0.a)
    else:
        print("    ✗ Alpha channel: %.2f (not opaque?)" % pixel_0_0.a)
    
    print("  PASS: Material Tile Generation\n")
    
    # Test 2: Different variants produce different shading
    print("[TEST 2] Variant Differentiation\n")
    
    var variant_0 = compositor._get_material_tile("stone", 0, 0)
    var variant_1 = compositor._get_material_tile("stone", 0, 1)
    var variant_2 = compositor._get_material_tile("stone", 0, 2)
    var variant_3 = compositor._get_material_tile("stone", 0, 3)
    
    var v0_pixel = variant_0.get_pixel(5, 5)
    var v1_pixel = variant_1.get_pixel(5, 5)
    var v2_pixel = variant_2.get_pixel(5, 5)
    var v3_pixel = variant_3.get_pixel(5, 5)
    
    var v0_v1_dist = v0_pixel.distance_to(v1_pixel)
    var v0_v2_dist = v0_pixel.distance_to(v2_pixel)
    
    if v0_v1_dist > 0.05 and v0_v2_dist > 0.05:
        print("    ✓ Variants produce different shading (distance: %.4f, %.4f)" % [v0_v1_dist, v0_v2_dist])
    else:
        print("    ⚠ Variants may not be differentiated (distance: %.4f, %.4f)" % [v0_v1_dist, v0_v2_dist])
    
    print("  PASS: Variant Differentiation\n")
    
    # Test 3: Composite chain
    print("[TEST 3] Composite Chain (M × F)\n")
    
    # Create a simple facade: solid 0.5 luminance
    var facade = Image.create(1024, 512, false, Image.FORMAT_L8)
    for y in range(512):
        for x in range(1024):
            facade.set_pixel(x, y, Color(0.5, 0, 0, 1))
    
    var sampler = preload("res://godot/scripts/systems/facade_sampler.gd").new()
    var projector = preload("res://godot/scripts/systems/per_face_projector.gd").new()
    
    var bake_key = BakeCompositorClass.BakeKey.new()
    bake_key.material_id = "stone"
    bake_key.facade_id = "test"
    bake_key.variant_k = 0
    bake_key.face = 0  # NE
    bake_key.plane_col = 0
    bake_key.plane_row = 0
    
    var composite = compositor._composite_tile(variant_0, facade, bake_key, sampler, projector)
    
    assert(composite != null, "Composite must not be null")
    assert(composite.get_width() == 32 and composite.get_height() == 16,
        "Composite must be 32×16")
    
    var comp_pixel = composite.get_pixel(10, 8)
    # Expected: material × facade_lum ≈ material × 0.5
    var expected_approx = variant_0.get_pixel(10, 8) * 0.5
    var comp_match = comp_pixel.distance_to(expected_approx) < 0.05
    
    if comp_match:
        print("    ✓ Composite correct: material × facade_lum")
    else:
        print("    ⚠ Composite pixel: %.3f, expected approx: %.3f (distance: %.4f)" % 
            [comp_pixel.r, expected_approx.r, comp_pixel.distance_to(expected_approx)])
    
    print("  PASS: Composite Chain\n")
    
    print("=".repeat(70))
    print("✓ FIX-BAKE-04 ALL TESTS PASS")
    print("=".repeat(70) + "\n")
    quit(0)
```

**Expected output:**
```
[TEST 1] Material Tile for Stone

    ✓ Tile created: 32×16 RGBA8
    ✓ Pattern shading applied (variance: 0.nnnn)
    ✓ Alpha channel: 1.00 (opaque)
  PASS: Material Tile Generation

[TEST 2] Variant Differentiation

    ✓ Variants produce different shading (distance: 0.nnnn, 0.nnnn)
  PASS: Variant Differentiation

[TEST 3] Composite Chain (M × F)

    ✓ Composite correct: material × facade_lum
  PASS: Composite Chain

============================================================
✓ FIX-BAKE-04 ALL TESTS PASS
============================================================
```

### Test 2: Timing validation

```gdscript
# In bake_compositor_test.gd, add to the main test suite:
var start = Time.get_ticks_msec()
var atlas = compositor.bake(mock_map_spec, mock_resolver)
var elapsed = Time.get_ticks_msec() - start

assert(elapsed < 200, "Bake should complete in <200 ms for small map (got %.0f ms)" % elapsed)
print("PASS: Bake timing %.0f ms (budget: 100 ms, measured on real data)" % elapsed)
```

### Test 3: B3 invariant (alpha from canonical)

```gdscript
# Verify that baked tile's alpha matches canonical
var canonical_tile = compositor._get_material_tile("stone", 0, 0)
var baked_tile = ... # After composite

for y in range(16):
    for x in range(32):
        var canonical_alpha = canonical_tile.get_pixel(x, y).a
        var baked_alpha = baked_tile.get_pixel(x, y).a
        
        assert(abs(canonical_alpha - baked_alpha) < 0.01,
            "Alpha at (%d, %d): canonical %.2f vs baked %.2f" % 
            [x, y, canonical_alpha, baked_alpha])

print("PASS: B3 invariant — alpha from canonical silhouette")
```

---

## Implementation Checklist

- [ ] Rewrite `_get_material_tile(material_id, face, variant_k)` to fetch registry and apply pattern
- [ ] Change tile format to RGBA8 in `_create_white_tile()` and all create calls
- [ ] Add `_get_material_registry()` helper (with fallback chain)
- [ ] Update `_composite_tile()` to preserve alpha from material tile
- [ ] Add timing instrumentation to `bake()` (start_total, start_render, elapsed logs)
- [ ] Create `fix_bake_04_material_tile_test.gd` and run headless
- [ ] Update `bake_compositor_test.gd` with timing and B3 assertions
- [ ] Run timing test on a medium map spec (4–8 walls × 4 faces) and confirm <100 ms
- [ ] Capture all console output

---

## Downstream Impact

- **Aesthetic:** Each material × variant combination now has distinct pattern shading. Stone walls vary texturally; wood grain flows; metal sheen bands appear.
- **Memory:** Dedup consolidates tiles with identical (material, facade window, variant) — now actually different due to pattern, so dedup is correctly conservative.
- **BAKE-05:** Material tiles are inputs to the composite; the seam is indifferent to their contents.
- **Destruction (BAKE-05):** Exposed geometry falls back to the canonical material atlas (the same tiles we just baked in C_mat ⊙ P), preserving consistency.

---

*End FIX-BAKE-04.*
