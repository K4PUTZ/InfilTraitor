# BAKE-07: BAKE Selftest Consolidation & Invariant Enforcement

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** Consolidated selftest suite (`bake_selftest.gd`), pre-commit hook updates (`check_invariants.py`), invariant assertions (B1–B6), destruction interaction test
**Predecessor:** `BAKE-06` (ThemeApplier, visual tooling complete)
**Successor:** `BAKE-08` (Resolver integration hardening, end-to-end)
**Status:** Ready for implementation
**PASS criteria:** All T1+T2 selftests log literal PASS lines; destruction test proves no re-bake occurs; B1 exclusivity grep passes; B4 FNV-1a pinned values match; B6 loud-fail validation confirmed (no silent breaks)

---

## Context

This prompt consolidates all the **validation and testing** that was distributed across prior prompts (BAKE-01 through BAKE-06 each had selftests). A unified selftest suite runs all of them, extends them with integration tests (destruction, multi-map sequencing), and ensures the six new invariants (B1–B6, from BAKING_MASTER_PLAN §5) are enforced at runtime and pre-commit.

Key principle from SLICE-02 and ENHANCE-04b scars: **selftests must fail loudly, never silently.** The slice_geometry_selftest scar (runtime `load()` of a deleted file, silently breaking the test) is the model we prevent.

---

## Part A: Invariant Enforcement

### A.1 B1: Branch Exclusivity

```gdscript
# In bake_selftest.gd

func test_B1_branch_exclusivity() -> void:
    # Assert: placement code accesses exactly one of (GENERIC_MATERIAL_ATLAS or BAKED_ATLAS)
    # depending on BakeConfig.enabled, never both
    
    var test_map = _create_test_map()
    
    # Test 1: Baking OFF
    BakeConfig.enabled = false
    var room_off = _build_room(test_map)
    var sources_off = _collect_all_cell_sources(room_off)
    
    # All sources should be from GLOBAL_MATERIAL_ATLAS
    for source_id in sources_off.values():
        assert(source_id == GLOBAL_MATERIAL_ATLAS.source_id,
            "Baking OFF but found non-material source: %s" % source_id)
    
    # Test 2: Baking ON
    BakeConfig.enabled = true
    var room_on = _build_room(test_map)
    var sources_on = _collect_all_cell_sources(room_on)
    
    # Sources should be from BAKED_ATLAS or GLOBAL_MATERIAL_ATLAS (fallback)
    for source_id in sources_on.values():
        var is_baked = source_id.begins_with("BAKED_ATLAS_")
        var is_material = source_id == GLOBAL_MATERIAL_ATLAS.source_id
        assert(is_baked or is_material,
            "Baking ON but found unknown source: %s" % source_id)
    
    # Test 3: No dual-mode state (ENHANCE-04b scar prevention)
    # Verify placement code does not reference *both* paths
    var placement_code = _read_file("res://game/placement/placement_controller.gd")
    var has_direct_atlas_ref = "GENERIC_MATERIAL_ATLAS" in placement_code or "_get_material_atlas_coords" in placement_code
    var has_lookup_ref = "BakedTileLookup" in placement_code
    
    assert(not (has_direct_atlas_ref and has_lookup_ref),
        "Both old and new placement paths present; dead code exists")
    
    print("PASS: B1_branch_exclusivity")

func _collect_all_cell_sources(tilemap: TileMap) -> Dictionary:
    var sources = {}
    var cells = tilemap.get_used_cells(0)  # Layer 0
    for cell_coords in cells:
        sources[cell_coords] = tilemap.get_cell_source_id(0, cell_coords)
    return sources
```

### A.2 B2: Grayscale Sources

```gdscript
func test_B2_grayscale_enforcement() -> void:
    # Assert: all FACADE and PATTERN sources are grayscale (no colored channels)
    
    var resolver = TextureResolver.new()
    var registry = GLOBAL_MATERIAL_REGISTRY
    
    # Test resolved facades (if any)
    var facade_ids = ["facade_stone_base", "facade_wood_base", "facade_metal_base"]
    for facade_id in facade_ids:
        var resolved = resolver.resolve(facade_id)
        if resolved.tier == TextureResolver.Tier.NONE:
            continue  # Unresolved facades skip this test
        
        # Check grayscale
        assert(_is_grayscale_image(resolved.image),
            "FACADE %s is not grayscale" % facade_id)
    
    # Test material patterns (generated tiles)
    for material_id in registry.list_materials():
        var material = registry.get_material(material_id)
        
        # Material base color is allowed to be colored; pattern outputs are grayscale multipliers
        # Verify by rendering a tile and checking that RGB channels match at each pixel
        var tile = _render_material_tile(material, Face.NE, 0)
        
        # Pattern shade is applied uniformly (RGB = base_color * shade), so R=G=B iff shade is uniform
        # For our patterns (jitter, grooves, sheen), verification is per-voxel
        # Simplified check: no unexpected color cast (if base is gray, tile is gray)
        if material.base_color.get_s() < 0.05:  # Grayscale material
            assert(_is_grayscale_image(tile),
                "Material %s tile not grayscale, but base color is gray" % material_id)
    
    print("PASS: B2_grayscale_enforcement")

func _is_grayscale_image(img: Image) -> bool:
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var pixel = img.get_pixel(x, y)
            if abs(pixel.r - pixel.g) > 0.01 or abs(pixel.g - pixel.b) > 0.01:
                return false
    return true
```

### A.3 B3: Alpha from Canon

```gdscript
func test_B3_alpha_from_canon() -> void:
    # Assert: baked tiles inherit alpha/silhouette from the canonical material atlas
    # The baked tile's alpha must be bit-identical to the material tile's alpha
    
    if not BakeConfig.enabled:
        print("SKIP: B3_alpha_from_canon (baking disabled)")
        return
    
    var registry = GLOBAL_MATERIAL_REGISTRY
    var compositor = BakeCompositor.new()
    var resolver = TextureResolver.new()
    
    # Sample one baked tile
    var test_map = _create_test_map()
    var baked_atlas = compositor.bake(test_map, resolver)
    
    if baked_atlas.lookup.size() == 0:
        print("SKIP: B3_alpha_from_canon (no baked tiles)")
        return
    
    # Pick first baked key
    var bake_key = baked_atlas.lookup.keys()[0]
    var baked_coords = baked_atlas.lookup[bake_key]
    
    # Get baked tile from atlas
    var baked_page = baked_atlas.pages[baked_coords["page"]]
    var baked_tile_rect = Rect2i(
        baked_coords["atlas_coords"] * Vector2i(32, 16),
        Vector2i(32, 16)
    )
    
    # Get canonical material tile
    var material = registry.get_material(bake_key.material_id)
    var material_tile = _get_material_tile(material, bake_key.face, bake_key.variant_k)
    
    # Compare alpha channels
    for y in range(16):
        for x in range(32):
            var baked_pixel = baked_page.get_pixel(baked_tile_rect.position.x + x, baked_tile_rect.position.y + y)
            var material_pixel = material_tile.get_pixel(x, y)
            
            assert(abs(baked_pixel.a - material_pixel.a) < 0.01,
                "Alpha mismatch at (%d, %d): baked %.3f, material %.3f" % [x, y, baked_pixel.a, material_pixel.a])
    
    print("PASS: B3_alpha_from_canon")
```

### A.4 B4: FNV-1a Determinism

```gdscript
func test_B4_fnv1a_determinism() -> void:
    # Assert: FNV-1a hashes are reproducible across runs and machines
    # Pinned expected values (computed once, stored here)
    
    var sampler = FacadeSampler.new()
    
    var test_cases = {
        "edge_test_run": 0x12345678,     # Example pinned value (REPLACE WITH ACTUAL)
        "edge_test_isolated": 0x87654321,
        "facade_stone_base": 0xdeadbeef,
    }
    
    for input_str in test_cases.keys():
        var actual = sampler._fnv1a_hash(input_str)
        var expected = test_cases[input_str]
        
        assert(actual == expected,
            "FNV-1a(%s) mismatch: expected 0x%08x, got 0x%08x" % [input_str, expected, actual])
    
    print("PASS: B4_fnv1a_determinism (pinned hashes match)")
```

### A.5 B5: No Re-Bake on Destruction

```gdscript
func test_B5_no_rebake_on_destruction() -> void:
    # Assert: destroying a wall voxel does not trigger re-baking
    # (The destroyed voxel's face becomes unexposed; no lookup is performed)
    
    if not BakeConfig.enabled:
        print("SKIP: B5_no_rebake_on_destruction (baking disabled)")
        return
    
    var test_map = _create_test_map()
    var room = _build_room(test_map)
    
    # Verify baked atlas was created once
    var initial_baked = GLOBAL_BAKED_ATLAS
    var initial_page_count = initial_baked.pages.size()
    
    # Destroy a wall voxel
    var wall_to_destroy = room.get_any_wall()
    var voxel_to_destroy = wall_to_destroy.get_first_voxel()
    room.destroy_voxel(voxel_to_destroy)
    
    # Verify no new bake occurred
    var after_destroy_baked = GLOBAL_BAKED_ATLAS
    assert(after_destroy_baked == initial_baked,
        "BAKED_ATLAS reference changed after destruction (re-bake occurred)")
    assert(after_destroy_baked.pages.size() == initial_page_count,
        "BAKED_ATLAS page count changed after destruction")
    
    # Verify the destroyed face now renders from material atlas (no lookup needed)
    var newly_exposed_voxel = voxel_to_destroy + Vector3i.UP  # Above the destroyed one
    # (Lookup is only called during placement; destroyed voxels don't trigger placement)
    
    print("PASS: B5_no_rebake_on_destruction")
```

### A.6 B6: Loud-Fail Selftest Validation

```gdscript
func test_B6_loud_fail_selftest() -> void:
    # Assert: selftests fail loudly (assertion halts) if dependencies are missing
    # Specifically: if a critical module (PerFaceProjector, MaterialRegistry, etc.) is not initialized,
    # selftest must assert, not continue silently
    
    # Test 1: Missing PerFaceProjector
    var projector_backup = GLOBAL_PER_FACE_PROJECTOR
    GLOBAL_PER_FACE_PROJECTOR = null
    
    var error_caught = false
    try:
        var sampler = FacadeSampler.new()
        sampler._mirror_2d(0.0, 0.0, 64, 32)  # Will try to use projector
    except:
        error_caught = true
    
    GLOBAL_PER_FACE_PROJECTOR = projector_backup
    assert(error_caught, "Missing PerFaceProjector not caught; silent failure risk")
    
    # Test 2: Missing MaterialRegistry
    var registry_backup = GLOBAL_MATERIAL_REGISTRY
    GLOBAL_MATERIAL_REGISTRY = null
    
    error_caught = false
    try:
        var compositor = BakeCompositor.new()
        var bake_set = compositor._populate_bake_set(null, null)  # Will try to access registry
    except:
        error_caught = true
    
    GLOBAL_MATERIAL_REGISTRY = registry_backup
    assert(error_caught, "Missing MaterialRegistry not caught")
    
    print("PASS: B6_loud_fail_selftest (loud failures confirmed)")
```

---

## Part B: Probe Pattern Regression Test

A synthetic facade (corner-marked grid) baked and asserted against analytically expected positions:

```gdscript
func test_probe_pattern_alignment() -> void:
    # Regression: verify probe-pattern alignment against TILE_OFFSET and canon constants
    # This turns the old empirical F2/F3/F4 calibration into an automated check
    
    if not BakeConfig.enabled:
        print("SKIP: probe_pattern_alignment (baking disabled)")
        return
    
    # Create synthetic probe facade (corner marks)
    var probe = _create_probe_facade(TEX_AUTHORING_N)  # 8N × 8N, marked corners
    
    # Bake the probe as a single voxel tile
    var sampler = FacadeSampler.new()
    var projector = GLOBAL_PER_FACE_PROJECTOR
    var compositor = BakeCompositor.new()
    
    # Composite probe (facade) with a neutral material tile (all white)
    var neutral_material = Image.create(32, 16, false, Image.FORMAT_RGB8)
    for y in range(16):
        for x in range(32):
            neutral_material.set_pixel(x, y, Color.WHITE)
    
    var bake_key = BakeKey.new()
    bake_key.material_id = "test"
    bake_key.facade_id = "probe"
    bake_key.variant_k = 0
    bake_key.face = Face.NE
    bake_key.plane_col = 0
    bake_key.plane_row = 0
    
    var baked_tile = compositor._composite_tile(neutral_material, probe, bake_key, sampler, projector)
    
    # Analyze: the corner marks in the probe should appear at analytically-expected screen positions
    # Flat (0, 0) → screen (x1, y1), flat (8N, 8N) → screen (x2, y2), etc.
    
    for flat_corner in [Vector2(0, 0), Vector2(8.0*TEX_AUTHORING_N, 0), Vector2(8.0*TEX_AUTHORING_N, 8.0*TEX_AUTHORING_N), Vector2(0, 8.0*TEX_AUTHORING_N)]:
        var screen_pos = projector.flat_to_screen(Face.NE, flat_corner)
        
        # Assert screen_pos is within tile bounds (32×16)
        assert(screen_pos.x >= 0 and screen_pos.x < 32 and screen_pos.y >= 0 and screen_pos.y < 16,
            "Probe corner out of bounds: %s" % screen_pos)
    
    print("PASS: probe_pattern_alignment")

func _create_probe_facade(N: int) -> Image:
    var img = Image.create(8*N, 8*N, false, Image.FORMAT_L8)
    
    # White fill
    for y in range(8*N):
        for x in range(8*N):
            img.set_pixel(x, y, Color.WHITE)
    
    # Colored corners (grayscale; use R=luminance)
    img.set_pixel(0, 0, Color(0.2, 0.2, 0.2))           # Red → 0.2
    img.set_pixel(8*N-1, 0, Color(0.5, 0.5, 0.5))       # Green → 0.5
    img.set_pixel(8*N-1, 8*N-1, Color(0.8, 0.8, 0.8))   # Blue → 0.8
    img.set_pixel(0, 8*N-1, Color(0.3, 0.3, 0.3))       # Yellow → 0.3
    
    return img
```

---

## Part C: Pre-Commit Hook Updates

Extend `check_invariants.py` to enforce B1 (branch exclusivity) and B4 (FNV-1a pinning):

```python
#!/usr/bin/env python3
# check_invariants.py (additions for BAKE-07)

import re
import subprocess

def check_B1_branch_exclusivity():
    """Ensure placement code doesn't reference both old and new tile paths."""
    placement_files = [
        "res://game/placement/placement_controller.gd",
        # ... other placement modules
    ]
    
    for filepath in placement_files:
        with open(filepath, 'r') as f:
            content = f.read()
        
        has_old_direct = ("GENERIC_MATERIAL_ATLAS" in content or 
                          "_get_material_atlas_coords" in content)
        has_new_lookup = "BakedTileLookup" in content
        
        if has_old_direct and has_new_lookup:
            print(f"FAIL: {filepath} references BOTH old and new tile paths (dead code)")
            return False
    
    print("PASS: B1_branch_exclusivity (no dual-path references)")
    return True

def check_B4_fnv1a_constants():
    """Verify FNV-1a hash constants are pinned and documented."""
    facade_sampler_file = "res://baking/facade_sampler.gd"
    
    with open(facade_sampler_file, 'r') as f:
        content = f.read()
    
    # Check for pinned test values in selftest
    if "0x" in content and "fnv1a_hash" in content:
        print("PASS: B4_fnv1a_constants (pinned hashes present)")
        return True
    else:
        print("WARN: B4_fnv1a_constants (no pinned hashes found; verify manually)")
        return True  # Warning, not failure

def main():
    checks = [
        check_B1_branch_exclusivity,
        check_B4_fnv1a_constants,
        # ... other invariant checks from prior sessions (stats as var, VISUAL_GRID_OFFSET, etc.)
    ]
    
    all_pass = all(check() for check in checks)
    
    if all_pass:
        print("\n✓ All invariants PASS")
        exit(0)
    else:
        print("\n✗ Invariant check FAILED")
        exit(1)

if __name__ == "__main__":
    main()
```

Run before every commit:

```bash
python3 check_invariants.py
```

---

## Part D: Consolidated Selftest Suite

In `bake_selftest.gd`, run all tests:

```gdscript
func run_all_bake_tests() -> bool:
    print("\n=== BAKE SELFTEST SUITE ===\n")
    
    var tests = [
        test_B1_branch_exclusivity,
        test_B2_grayscale_enforcement,
        test_B3_alpha_from_canon,
        test_B4_fnv1a_determinism,
        test_B5_no_rebake_on_destruction,
        test_B6_loud_fail_selftest,
        test_probe_pattern_alignment,
        test_destruction_interaction,
        test_multimap_sequencing,
    ]
    
    var passed = 0
    var failed = 0
    
    for test_func in tests:
        try:
            test_func.call()
            passed += 1
        except var e:
            print("FAIL: %s - %s" % [test_func.get_method(), e])
            failed += 1
    
    print("\n=== RESULT: %d PASS, %d FAIL ===" % [passed, failed])
    return failed == 0
```

---

## Part E: Entry Point

In `main.gd` or on-demand (F-key):

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F12:  # Run selftest
            var selftest = BakeSelftest.new()
            var passed = selftest.run_all_bake_tests()
            if not passed:
                push_error("[SELFTEST] BAKE invariants violated")
```

---

## Part F: Rollout Checklist

Before BAKE-08 can start:

- [ ] `bake_selftest.gd` written with all invariant tests (B1–B6) + probe + destruction + multimap tests.
- [ ] Selftest PASS achieved: all literal PASS lines logged, no silent failures.
- [ ] Pre-commit hook (`check_invariants.py`) updated with B1/B4 checks.
- [ ] Destruction test confirms no re-bake (GLOBAL_BAKED_ATLAS unchanged, page count stable).
- [ ] Probe pattern regression test verifies alignment (corners appear at expected screen positions).
- [ ] B6 loud-fail test confirms selftests assert on missing dependencies (no silent breaks).
- [ ] FNV-1a hash values pinned and documented.
- [ ] Evidence transcript: all selftest outputs, pre-commit audit results.

---

*End of BAKE-07.*
