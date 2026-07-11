# FIX-BAKE-03: Tile Anatomy – Real Extraction & N-Scaled Transforms

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-02 (Units & Origins)
**Successor:** FIX-BAKE-04 (Real Material Tiles)
**Scope:** Redo BAKE-01 audit empirically; extract true geometry from tileset; add N-scale term; validate integer shear; restore probe regression
**Effort:** ~4–5 hours (audit requires visual inspection + math validation)
**Risk:** High (geometry is foundational; errors here propagate to all downstream rendering)

---

## Problem

`TILE_ANATOMY.md` and `PerFaceProjector` both fail the SLICE-00 lesson: "diagnose geometry before touching it." The audit document contradicts itself, the pinned matrices lack an N-scale term despite the stated 128×128 → 32×16 compression, and the "integer shear" invariant is mathematically false yet asserted without proof.

### P1: Matrices do not match declared geometry

**Declared (TILE_ANATOMY.md Part A):**
- One voxel quad = **8N × 8N = 128×128 pixels** in flat texture space
- Screen-space isometric = **32×16 pixels**
- Transforms compress flat → screen

**Pinned (TILE_ANATOMY.md Part B):**
```
Matrix M_NE = [  1.0   0.5 ]     (no N-dependent term)
              [  0.0  -0.5 ]
Offset: (0.0, 64.0)
```

**Reality check:** Applying M_NE to a full 128×128 flat quad:
```
NW corner (0, 0):       screen = (0, 64)       ✓
NE corner (128, 0):     screen = (128, 64)     ✗ (should be ~32)
SW corner (0, 128):     screen = (64, 0)       ✗ (should be ~16)
SE corner (128, 128):   screen = (192, 0)      ✗ (should be ~48)
```

The resulting parallelogram is ~192×64, not 32×16. The matrices are **not extraction; they are reverse-fit to look isometric** (0.5 shears are characteristic of diamond rotation) but do not encode the canonical tileset's actual geometry.

### P2: Integer shear is false for odd coordinates

The invariant D8/D3 states: "All shear offsets are integer pixels, guaranteeing one-texel-to-one-pixel fidelity under NEAREST."

With M_NE = [[1, 0.5], [0, -0.5]]:
```
flat_x=0, flat_y=1  →  screen_y = 0 * 0 - 0.5 * 1 = -0.5  (HALF-PIXEL)
flat_x=0, flat_y=3  →  screen_y = 0 * 0 - 0.5 * 3 = -1.5  (HALF-PIXEL)
```

For **odd** flat coordinates, screen offsets are non-integer. The "integer shear" is only true for **even** flat coordinates (even × 0.5 = integer). The audit document hedges with "For even flat_y, offsets are integers" then falsely generalizes to "All columns map to integer screen positions."

Audit evidence:
```gdscript
# per_face_projector.gd lines ~109–113
# The _assert_integer_shear_all_faces() method exists but is NEVER CALLED
# per_face_projector_test.gd lines ~25–26
# Test 2: "✓ Transforms constructed with integer shear (by design)"
# — without calling any assertion, merely printing the label
```

### P3: Probe-pattern regression missing

The design (§4.9) promises an automated regression test: a synthetic facade (corner-marked texel grid) baked and asserted against analytically expected screen positions derived from `TILE_OFFSET (112, 64)` and canon constants. This **does not exist**.

This test would have caught P1 and P2 immediately by demonstrating that expected vs. actual screen pixels do not align. Its absence is why the broken matrices passed silently.

---

## Solution

### S1: Empirical extraction from canonical tileset

Instead of reverse-fitting matrices to look isometric, **extract the true geometry from the voxel tileset PNG or the builder that generates it.**

**Audit procedure:**

1. **Locate the canonical tileset** (one of these exists):
   - `godot/resources/tilesets/*.tres` — built-in TileSet
   - `build_voxel_tileset.gd` — TileSet generator (preferred; source of truth)

2. **Understand the tile structure.** A 32×16 screen-space tile encodes one voxel quad's three visible faces (isometric diamond):
   - **Top face** (diamond): flat region, typically pale (lit)
   - **Left face** (side): parallelogram, darkened ~80% (shadow)
   - **Right face** (side): parallelogram, darkened ~80% (shadow)
   - **Silhouette** (alpha): defines the diamond outline

3. **Measure pixel-to-face mapping.** For each screen pixel (screen_x, screen_y) in the 32×16 tile, determine which flat texture pixel it samples from:
   - Use the **inverse transform** (screen → flat)
   - The flat coordinate (flat_x, flat_y) ∈ [0, 128) × [0, 128)
   - Group by face (top diamond, left side, right side)

4. **Derive the transform matrix** from measured coordinates:
   - Collect (screen_x, screen_y) → (flat_x, flat_y) mappings
   - Fit an affine: `flat = A * screen + b` (least-squares or exact, if data is perfect)
   - Store the inverse (`screen = A^-1 * flat + offset`)

**Practical approach (if visual inspection is too labor-intensive):**

Godot 4.6 provides `get_texture()` and pixel sampling on TileSets. Write a headless script:

```gdscript
# Pseudo-code: extract_tile_geometry.gd
extends SceneTree

func _init() -> void:
    var tileset = load("res://path/to/tileset.tres")
    var atlas_source = tileset.get_source(0)  # Assuming single source
    var tex = atlas_source.texture
    
    var measurements = []
    for screen_y in range(16):
        for screen_x in range(32):
            # Sample texture at canonical tile position
            var pixel = tex.get_pixel(screen_x, screen_y)  # (pixel space in atlas PNG)
            # If pixel is non-transparent (part of the tile):
            if pixel.a > 0:
                # Trace back to canonical flat origin
                # This requires knowledge of the shear/transform in the builder
                measurements.append({
                    "screen": Vector2(screen_x, screen_y),
                    "flat": _infer_flat_from_pixel(pixel, screen_x, screen_y)
                })
    
    var extracted_matrix = _fit_affine(measurements)
    print("Extracted transform: %s" % extracted_matrix)
    quit(0)
```

Alternatively, **use the builder code itself:** if `build_voxel_tileset.gd` composites tiles, its shear/transform parameters **are the ground truth**. Extract them directly.

### S2: Define the canonical contract explicitly

Once extraction is done, **formally document** the transform:

```markdown
## Canonical Tile Geometry (Post-Audit)

**Voxel Quad Flat Space:** 128×128 pixels (8N where N=16)

**Screen Space:** 32×16 pixels (isometric diamond)

**Transforms (screen = M * flat + offset):**

### Face NE
- Matrix: [extracted_m00, extracted_m01; extracted_m10, extracted_m11]
- Offset: (extracted_ox, extracted_oy)
- Validates: All screen_x ∈ [0, 32), all screen_y ∈ [0, 16) for flat ∈ [0, 128)

### Face SE / SW / NW
[similar]

**Integer Shear Validation:**
- For all flat_y in [0, 128): offset_y(flat_y) is an integer (or precisely 0.5-biased, with strategy)
- If 0.5 bias present: document mitigation (e.g., using 0.5-pixel precision in sampler, or pre-scaling)
```

### S3: Implement integer-shear assertion that actually runs

Update `PerFaceProjector._init()`:

```gdscript
func _init(p_N: int = -1) -> void:
    if p_N > 0:
        N = p_N
    else:
        N = GeometryCoordsClass.TEX_AUTHORING_N
    
    _setup_transforms()
    
    # NOW we actually run the assertion (was commented out before)
    _assert_integer_shear_all_faces()
```

Update `_assert_integer_shear_all_faces()` to be rigorous:

```gdscript
func _assert_integer_shear_all_faces() -> void:
    var tolerance = 0.0001  # Account for floating-point error
    
    for face_idx in [Face.NE, Face.SE, Face.SW, Face.NW]:
        _validate_face_integer_shear(face_idx, tolerance)
    
    print("[GEOMETRY] ✓ Integer shear validated for all faces")

func _validate_face_integer_shear(face: int, tolerance: float) -> void:
    var face_name = ["NE", "SE", "SW", "NW"][face]
    var failed = []
    
    # Test all flat coordinates in the voxel quad
    for flat_y in range(0, 8 * N + 1):
        for flat_x in range(0, 8 * N):
            var screen_pos = flat_to_screen(face, Vector2(float(flat_x), float(flat_y)))
            var y_frac = fmod(screen_pos.y, 1.0)
            
            # y_frac should be nearly 0 or nearly 1 (integer or edge case)
            if y_frac > tolerance and y_frac < (1.0 - tolerance):
                failed.append("  flat(%.0f, %.0f) → screen_y=%.4f (fractional)" % 
                    [float(flat_x), float(flat_y), screen_pos.y])
    
    if failed.is_empty():
        print("  ✓ [%s] All 128×129 points map to integer (or near-integer) Y" % face_name)
    else:
        push_error("[%s] %d points have non-integer Y offset:" % [face_name, failed.size()])
        for msg in failed.slice(0, 5):  # Print first 5 failures
            push_error(msg)
        assert(false, "Integer shear validation FAILED for face %s" % face_name)
```

The assertion now **fails loudly** if any coordinate breaks the contract.

### S4: Restore probe-pattern regression test

Create a synthetic facade and bake it; verify that specific screen pixels land on expected texel coordinates.

**Test file:** `godot/scripts/tools/fix_bake_03_probe_pattern_test.gd` (new)

```gdscript
extends SceneTree

const PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

func _init() -> void:
    print("\n" + "=".repeat(70))
    print("FIX-BAKE-03 TEST: Probe Pattern Regression")
    print("=".repeat(70) + "\n")

    # Create a probe facade: corner-marked grid
    var probe_facade = _create_probe_facade()
    
    # Composite a single tile with this facade through all four faces
    var projector = PerFaceProjectorClass.new()
    var sampler = FacadeSamplerClass.new()
    
    # Expected probe points (manually computed from TILE_OFFSET = (112, 64) and constants)
    var expected_probes = {
        PerFaceProjectorClass.Face.NE: [
            # (screen_x, screen_y) → expected flat_x, flat_y (from corner marks)
            [0, 0, 0, 64],      # NW corner screen → NW corner flat
            [32, 0, 128, 64],   # NE corner screen → NE corner flat
            [16, 8, 64, 0],     # Center screen → center flat (approximately)
        ],
        PerFaceProjectorClass.Face.SE: [
            [16, 0, 64, 128],
            [32, 8, 128, 64],
            [16, 16, 64, 0],
        ],
        # ... SE, SW, NW similarly
    }
    
    print("[TEST 1] Probe Pattern Alignment\n")
    
    var all_pass = true
    for face in [PerFaceProjectorClass.Face.NE, PerFaceProjectorClass.Face.SE]:
        print("  Testing face %d:" % face)
        var probes = expected_probes.get(face, [])
        
        for probe in probes:
            var screen_x = probe[0]
            var screen_y = probe[1]
            var expected_flat_x = probe[2]
            var expected_flat_y = probe[3]
            
            var screen_pos = Vector2(float(screen_x), float(screen_y))
            var flat_pos = projector.screen_to_flat(face, screen_pos)
            
            # Sample from probe facade
            var probe_val = sampler.sample(probe_facade, flat_pos.x, flat_pos.y)
            
            # Probe marks are 0.2 at corners, 0.5 elsewhere
            var is_corner_mark = abs(probe_val - 0.2) < 0.05
            var tolerance = 2.0  # ±2 pixels is acceptable for NEAREST
            var x_match = abs(flat_pos.x - expected_flat_x) < tolerance
            var y_match = abs(flat_pos.y - expected_flat_y) < tolerance
            
            if is_corner_mark and x_match and y_match:
                print("    ✓ screen(%d, %d) → flat(%.1f, %.1f) [corner mark, within tolerance]" % 
                    [screen_x, screen_y, flat_pos.x, flat_pos.y])
            else:
                print("    ✗ screen(%d, %d) → flat(%.1f, %.1f) [expected (%.0f, %.0f), corner=%s]" % 
                    [screen_x, screen_y, flat_pos.x, flat_pos.y, expected_flat_x, expected_flat_y, is_corner_mark])
                all_pass = false
    
    if all_pass:
        print("\n  PASS: Probe Pattern Regression\n")
    else:
        print("\n  FAIL: Probe Pattern Misaligned\n")
        assert(false, "Geometry regression detected")
    
    print("=".repeat(70))
    print("✓ FIX-BAKE-03 PROBE TEST PASS")
    print("=".repeat(70) + "\n")
    quit(0 if all_pass else 1)

func _create_probe_facade() -> Image:
    # Create a 1024×512 (64N×32N) facade with corner marks
    var facade = Image.create(1024, 512, false, Image.FORMAT_L8)
    
    # Fill with 0.5 (mid-gray)
    for y in range(512):
        for x in range(1024):
            facade.set_pixel(x, y, Color(0.5, 0, 0, 1))
    
    # Mark corners: (0,0), (1023,0), (1023,511), (0,511)
    var corner_color = Color(0.2, 0, 0, 1)
    var corner_size = 4
    for y in range(corner_size):
        for x in range(corner_size):
            facade.set_pixel(x, y, corner_color)  # NW
            facade.set_pixel(1023 - x, y, corner_color)  # NE
            facade.set_pixel(1023 - x, 511 - y, corner_color)  # SE
            facade.set_pixel(x, 511 - y, corner_color)  # SW
    
    return facade

func _create_probe_expected_values() -> Dictionary:
    # Derived from TILE_OFFSET = (112, 64) and canonical constants
    # These are computed manually (or extracted from build_voxel_tileset.gd)
    return {
        "TILE_OFFSET": Vector2(112, 64),
        "SCREEN_BOUNDS": Rect2(0, 0, 32, 16),
        "FLAT_BOUNDS": Rect2(0, 0, 128, 128),
    }
```

**Expected output:**
```
[TEST 1] Probe Pattern Alignment

  Testing face 0:
    ✓ screen(0, 0) → flat(0.1, 63.9) [corner mark, within tolerance]
    ✓ screen(32, 0) → flat(128.2, 63.8) [corner mark, within tolerance]
    ✓ screen(16, 8) → flat(64.0, 0.1) [corner mark, within tolerance]

  PASS: Probe Pattern Regression

============================================================
✓ FIX-BAKE-03 PROBE TEST PASS
============================================================
```

---

## Validation & Evidence (PASS Criteria)

### Test 1: PerFaceProjector initialization runs integer-shear assertion

```gdscript
# In per_face_projector_test.gd or new test:
var projector = PerFaceProjectorClass.new()
# If projector._init() is called and _assert_integer_shear_all_faces() fails,
# the constructor raises an assertion error, failing loudly.
# If successful, the assertion prints "[GEOMETRY] ✓ Integer shear validated..."

assert(true, "Constructor completed without assertion failure")
print("PASS: PerFaceProjector integer-shear assertion runs and passes")
```

### Test 2: Probe pattern regression (above)

### Test 3: Round-trip transforms still work

```gdscript
# per_face_projector_test.gd (existing Test 1, updated):
var projector = PerFaceProjectorClass.new()
for face in [0, 1, 2, 3]:
    var flat_in = Vector2(64.0, 64.0)
    var screen = projector.flat_to_screen(face, flat_in)
    var flat_out = projector.screen_to_flat(face, screen)
    
    assert(flat_in.distance_to(flat_out) < 0.1, 
        "Round-trip [%d]: %.4f error" % [face, flat_in.distance_to(flat_out)])
    print("✓ Face %d round-trip: distance = %.6f" % [face, flat_in.distance_to(flat_out)])

print("PASS: Round-trip transforms work")
```

---

## Implementation Checklist

- [ ] Review `build_voxel_tileset.gd` (or tileset source) to locate true geometry/shear parameters
- [ ] If parameters found: document them; measure against stated 128×128 → 32×16 compression
- [ ] If parameters unclear: run empirical extraction script (headless sampler from tileset PNG)
- [ ] Create `TILE_ANATOMY_CORRECTED.md` with actual extracted transforms and integer-shear analysis
- [ ] Update `PerFaceProjector._setup_transforms()` with correct matrices (with N-scale term if applicable)
- [ ] Uncomment and enable `_assert_integer_shear_all_faces()` in `PerFaceProjector._init()`
- [ ] Rewrite `_assert_integer_shear_all_faces()` with detailed per-point validation and explicit assert
- [ ] Create `fix_bake_03_probe_pattern_test.gd` with corner-marked facade and regression checks
- [ ] Run `per_face_projector_test.gd` and verify integer-shear assertion passes
- [ ] Run `fix_bake_03_probe_pattern_test.gd` and verify all probe corners hit
- [ ] Run `bake_compositor_test.gd` (should still pass; compositor is indifferent to projector internals)
- [ ] Capture all console output, including "[GEOMETRY] ✓ Integer shear validated..." line

---

## Downstream Impact

- **Geometry → Rendering:** PerFaceProjector is the mathematical foundation of facade sampling. Corrected transforms fix the texture-to-screen mapping for all baked tiles.
- **Probe regression:** Future changes to tileset structure or voxel constants will be caught by the probe test.
- **FIX-BAKE-04:** Material tile generation now receives correct screen-to-flat mappings.
- **Aesthetic outcome:** If the original matrices were reverse-fitted (likely), corrected matrices will align baked pixels with the canonical tile silhouette, fixing misalignment scars from SLICE-02.

---

## Note: N-Scale and Dimensions

If extraction reveals that the shear already encodes the N-scale (e.g., 0.25 instead of 0.5, accounting for the 8 voxels per GU × 2 = 16 spatial units), document this explicitly. The important invariant is: **whatever the geometry is, integer shear must hold for odd coordinates too** — or the sampling strategy must handle 0.5-pixel offsets (e.g., via rounding or fractional-sample fetch). Do not carry forward the "even only" hedge.

---

*End FIX-BAKE-03.*
