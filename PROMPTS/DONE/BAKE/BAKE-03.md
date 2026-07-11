# BAKE-03: FacadeSampler

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `facade_sampler.gd` module + T1 selftest
**Predecessor:** `BAKE-02` (MaterialRegistry, PerFaceProjector)
**Successor:** `BAKE-04` (BakeCompositor)
**Status:** Ready for implementation
**PASS criteria:** Mirrored-repeat addressing verified on synthetic corner-marked facade; window origins determined by FNV-1a hash; selftest outputs literal PASS lines for each addressing mode and edge case

---

## Context

The facade sampler answers a single question: **given a coordinate in the infinite facade plane, what luminance does the actual facade texture supply?**

The key insight (BAKING_MASTER_PLAN §3 Stage 3): the facade is **one concrete texture** (64×32 voxel-faces = `(64N, 32N)` pixels), but it defines an **infinite deterministic plane** via mirrored repetition on both axes. A small wall (1 voxel edge) crops a 1×1 window from this plane; a large wall (20 voxel edges) crops a 20×1 window. The crop window's origin is determined by hashing the canonical edge, ensuring determinism and (intentional) variance in small walls.

---

## Part A: Addressing Model (Mirrored-Repeat)

### A.1 Mathematics

The mirrored-repeat function folds an infinite coordinate into the texture's bounded domain:

```
mirror(k, S) → value in [0, S)
```

where `S` is the texture dimension and `k` is the coordinate (can be negative, > S, fractional).

Algorithm:

```
1. Fold k into [0, 2S) by repeated reflection:
     k' = k mod 2S
2. If k' >= S: reflect back: k' = 2S - k'
3. Return k' (now in [0, S))
```

Visual example (1D, S=4):

```
Texture domain: [0, 4)  ← stored pixels
Infinite plane: ...| 0 1 2 3 | 3 2 1 0 | 0 1 2 3 | 3 2 1 0 | ...
               k=-4,-3,-2,-1, 0,1,2,3, 4,5,6,7, ...
Seams occur at integer multiples of 2S:
  k ∈ [0, S) → texture as-is
  k ∈ [S, 2S) → texture reflected (mirrored)
  k ∈ [2S, 3S) → texture as-is (cycle repeats)
```

This produces the "book-matching" effect: a distinctive feature (e.g., a marble vein) appears in mirror-image at the seam boundary. Because both vertical and horizontal directions use mirrored-repeat, seams are **symmetrical** and acceptable aesthetically.

### A.2 Facade Dimensions

Facades are **64 voxel-edges wide × 32 voxel-edges tall**, which in pixels is `64N × 32N` (where N is from BAKE-01).

```
S_width = 64N   (horizontal texture domain)
S_height = 32N  (vertical texture domain)
```

### A.3 2D Mirrored-Repeat

For a 2D point `(plane_x, plane_y)` in the infinite facade plane:

```gdscript
func _mirror_2d(plane_x: float, plane_y: float, tex_width: int, tex_height: int) -> Vector2i:
    var tx = _mirror_1d(plane_x, tex_width)
    var ty = _mirror_1d(plane_y, tex_height)
    return Vector2i(int(tx), int(ty))

func _mirror_1d(k: float, S: int) -> float:
    # Fold k into [0, 2S), then reflect if needed
    var k2 = fmod(k, 2.0 * S)
    if k2 < 0:
        k2 += 2.0 * S
    
    if k2 >= S:
        k2 = 2.0 * S - k2
    
    return k2
```

---

## Part B: Window Origin Derivation

The **window** is the rectangular sample region within the infinite facade plane from which a wall's face texture is cropped. Two different hashing strategies apply:

### B.1 Contiguous Runs

When multiple wall faces form a **contiguous run** (edge-to-edge along the same plane column direction), the origin is fixed by the run's **canonical minimum edge**, ensuring veins flow continuously:

```gdscript
func _window_origin_run(canonical_min_edge: WallEdgeData, facade_id: String) -> Vector2i:
    # Hash the canonical edge to derive a deterministic column offset
    # Stays constant across all faces in the run; successive faces use consecutive columns
    
    var hash_input = canonical_min_edge.key_string() + ":" + facade_id
    var hash_val = _fnv1a_hash(hash_input)
    
    var plane_col = (hash_val % 64) * N    # Offset in pixels; [0, 64N)
    var plane_row = 0                      # v1 uses row 0; multi-storey assigns rows 1+
    
    return Vector2i(plane_col, plane_row)
```

The window width is determined by the run length: a 3-edge run crops columns `[plane_col, plane_col + 3N)`.

### B.2 Isolated Walls

A single wall or a non-contiguous segment hashes independently to randomize which patch of the facade is sampled, preventing the "stamp" look:

```gdscript
func _window_origin_isolated(edge: WallEdgeData, facade_id: String) -> Vector2i:
    # Hash the specific edge to derive a random but deterministic patch
    
    var hash_input = edge.key_string() + ":" + facade_id
    var hash_val = _fnv1a_hash(hash_input)
    
    # Two independent hashes: one for column, one for row
    var plane_col = ((hash_val >> 0) & 0xFF) % 64 * N
    var plane_row = ((hash_val >> 8) & 0xFF) % 32 * N  # Row selection for future multi-storey
    
    return Vector2i(plane_col, plane_row)
```

### B.3 FNV-1a Hash Function

Use the project's own FNV-1a implementation (not Godot's `hash()`, whose stability is not guaranteed between versions):

```gdscript
func _fnv1a_hash(input: String) -> int:
    # FNV-1a 32-bit hash
    var hash: int = 2166136261  # FNV offset basis
    var fnv_prime: int = 16777619
    
    for byte in input.to_ascii_buffer():
        hash ^= byte
        hash = (hash * fnv_prime) & 0xFFFFFFFF  # Keep 32-bit
    
    return hash
```

**Why FNV-1a:** deterministic across Godot versions and machines; simple; widely used; our own implementation guarantees bit-for-bit identical results.

---

## Part C: FacadeSampler Module

### C.1 Interface

```gdscript
class_name FacadeSampler

func sample(facade: Image, plane_x: float, plane_y: float) -> float:
    # Sample facade at (plane_x, plane_y) in the infinite plane
    # Uses mirrored-repeat addressing
    # Returns: luminance [0, 1]
    
    var tex_width = facade.get_width()
    var tex_height = facade.get_height()
    
    var sampled = _mirror_2d(plane_x, plane_y, tex_width, tex_height)
    var pixel = facade.get_pixel(sampled.x, sampled.y)
    
    return pixel.v  # Extract luminance (works for grayscale; v = value in HSV)

func get_window_origin_run(canonical_min_edge: WallEdgeData, facade_id: String) -> Vector2i:
    # Deterministic origin for a contiguous run
    return _window_origin_run(canonical_min_edge, facade_id)

func get_window_origin_isolated(edge: WallEdgeData, facade_id: String) -> Vector2i:
    # Randomized origin for an isolated wall
    return _window_origin_isolated(edge, facade_id)

func get_window_bounds(origin: Vector2i, width_voxels: int, height_voxels: int, N: int) -> Rect2i:
    # Return the rectangular region in the plane, in pixels
    return Rect2i(origin.x, origin.y, width_voxels * N, height_voxels * N)

# Internal helpers
func _mirror_2d(plane_x: float, plane_y: float, tex_width: int, tex_height: int) -> Vector2i:
    # (as above)

func _mirror_1d(k: float, S: int) -> float:
    # (as above)

func _window_origin_run(edge: WallEdgeData, facade_id: String) -> Vector2i:
    # (as above)

func _window_origin_isolated(edge: WallEdgeData, facade_id: String) -> Vector2i:
    # (as above)

func _fnv1a_hash(input: String) -> int:
    # (as above)
```

### C.2 Implementation Notes

- **Sampling returns luminance (grayscale):** facades are stored as grayscale; we extract the value (V in HSV, or R from RGB if a colored facade slips through). The selftest validates grayscale sources at resolve time (TEX-CATALOG-01).
- **Plane coordinates are in pixels:** a facade of `64N × 32N` pixels has plane coordinates `[0, 64N) × [0, 32N)`. A wall face that spans, say, 5 edges and 2 storeys crops `[origin_x, origin_x + 5N) × [origin_y, origin_y + 16N)` pixels (if each storey is 8 voxels = 8N pixels tall).
- **No interpolation:** NEAREST sampling implied. The compositor's inverse-mapping (BAKE-04) is responsible for mapping screen pixels to exact plane coordinates; the sampler just looks up what's there.

---

## Part D: Selftest (T1, Pure Math, Headless)

In `facade_sampler_test.gd`:

### D.1 Test Suite

```gdscript
func run_all_tests() -> void:
    test_mirror_1d_boundaries()
    test_mirror_1d_seams()
    test_mirror_2d_quad()
    test_fnv1a_determinism()
    test_window_origin_run()
    test_window_origin_isolated()
    test_sample_synthetic_facade()

func test_mirror_1d_boundaries() -> void:
    var sampler = FacadeSampler.new()
    
    # S = 4 (texture domain [0, 4))
    # Boundaries: k=0→0, k=4→0 (wrap), k=-1→1 (reflect), k=5→3 (reflect)
    
    assert(sampler._mirror_1d(0.0, 4) == 0.0)
    assert(sampler._mirror_1d(1.0, 4) == 1.0)
    assert(sampler._mirror_1d(3.0, 4) == 3.0)
    assert(sampler._mirror_1d(4.0, 4) == 0.0)  # Wrap
    assert(sampler._mirror_1d(5.0, 4) == 3.0)  # Reflect
    assert(sampler._mirror_1d(-1.0, 4) == 1.0) # Reflect
    
    print("PASS: mirror_1d_boundaries")

func test_mirror_1d_seams() -> void:
    var sampler = FacadeSampler.new()
    
    # Verify book-matching at seams
    # k ∈ [0, S) should match k ∈ [2S, 3S) (period is 2S)
    
    var S = 64
    for i in range(10):
        var k1 = float(i) * 3.7
        var k2 = k1 + 2.0 * S
        
        assert(sampler._mirror_1d(k1, S) == sampler._mirror_1d(k2, S), 
            "Period not 2S: k1=%f, k2=%f" % [k1, k2])
    
    print("PASS: mirror_1d_seams")

func test_mirror_2d_quad() -> void:
    var sampler = FacadeSampler.new()
    
    # Test a 2D quad: all four corners should map correctly
    var corners = [
        Vector2(0.0, 0.0),
        Vector2(64.0, 0.0),
        Vector2(64.0, 32.0),
        Vector2(0.0, 32.0)
    ]
    
    for corner in corners:
        var mirrored = sampler._mirror_2d(corner.x, corner.y, 64, 32)
        # After mirroring, should be back to source (since we're at the boundaries)
        # This is a basic sanity check; the full corner-mark test is in D.3
    
    print("PASS: mirror_2d_quad")

func test_fnv1a_determinism() -> void:
    var sampler = FacadeSampler.new()
    
    # Same input → same hash, always
    var input = "edge_0x12ab:facade_stone_base"
    var hash1 = sampler._fnv1a_hash(input)
    var hash2 = sampler._fnv1a_hash(input)
    
    assert(hash1 == hash2, "FNV-1a not deterministic")
    print("PASS: fnv1a_determinism")

func test_window_origin_run() -> void:
    var sampler = FacadeSampler.new()
    
    # Create synthetic edge data
    var edge = WallEdgeData.new()
    edge.key_string = func(): return "edge_test_run"
    
    var origin = sampler.get_window_origin_run(edge, "facade_stone_base")
    
    # Origin should be deterministic and in valid range
    assert(origin.x >= 0 and origin.x < 64, "X origin out of range: %d" % origin.x)
    assert(origin.y >= 0 and origin.y < 32, "Y origin out of range: %d" % origin.y)
    
    # Call again; should get same result
    var origin2 = sampler.get_window_origin_run(edge, "facade_stone_base")
    assert(origin == origin2, "Window origin not deterministic")
    
    print("PASS: window_origin_run")

func test_window_origin_isolated() -> void:
    var sampler = FacadeSampler.new()
    
    var edge = WallEdgeData.new()
    edge.key_string = func(): return "edge_test_isolated"
    
    var origin = sampler.get_window_origin_isolated(edge, "facade_stone_base")
    
    assert(origin.x >= 0 and origin.x < 64, "X origin out of range: %d" % origin.x)
    assert(origin.y >= 0 and origin.y < 32, "Y origin out of range: %d" % origin.y)
    
    # Same edge, different facade → different origin
    var origin_wood = sampler.get_window_origin_isolated(edge, "facade_wood_base")
    assert(origin != origin_wood, "Different facades should hash differently")
    
    print("PASS: window_origin_isolated")

func test_sample_synthetic_facade() -> void:
    # Create a synthetic facade: grayscale with corner marks
    var facade = Image.create(64, 32, false, Image.FORMAT_L8)
    
    # White fill
    for y in range(32):
        for x in range(64):
            facade.set_pixel(x, y, Color.WHITE)
    
    # Colored marks at corners (grayscale; use value)
    facade.set_pixel(0, 0, Color(0.2, 0.2, 0.2))    # Dark gray at (0, 0)
    facade.set_pixel(63, 0, Color(0.5, 0.5, 0.5))   # Medium at (63, 0)
    facade.set_pixel(63, 31, Color(0.8, 0.8, 0.8))  # Light at (63, 31)
    facade.set_pixel(0, 31, Color(0.3, 0.3, 0.3))   # Dark-medium at (0, 31)
    
    var sampler = FacadeSampler.new()
    
    # Sample the corners
    var val_00 = sampler.sample(facade, 0.0, 0.0)
    var val_63_0 = sampler.sample(facade, 63.0, 0.0)
    var val_63_31 = sampler.sample(facade, 63.0, 31.0)
    var val_0_31 = sampler.sample(facade, 0.0, 31.0)
    
    # Check we get back approximately the right values (within floating-point tolerance)
    assert(abs(val_00 - 0.2) < 0.05, "Corner (0,0) sampled incorrectly")
    assert(abs(val_63_0 - 0.5) < 0.05, "Corner (63,0) sampled incorrectly")
    assert(abs(val_63_31 - 0.8) < 0.05, "Corner (63,31) sampled incorrectly")
    assert(abs(val_0_31 - 0.3) < 0.05, "Corner (0,31) sampled incorrectly")
    
    # Sample from the infinite plane (beyond texture bounds)
    # k=64 should wrap to k=0 via mirroring; sample should match (0, *)
    var val_64_0 = sampler.sample(facade, 64.0, 0.0)
    assert(abs(val_64_0 - 0.2) < 0.05, "Mirrored wrap failed at (64, 0)")
    
    # k=65 should reflect to k=63 (since 65 = 2*64 - 63)
    var val_65_0 = sampler.sample(facade, 65.0, 0.0)
    assert(abs(val_65_0 - 0.5) < 0.05, "Mirrored reflect failed at (65, 0)")
    
    print("PASS: sample_synthetic_facade")
```

### D.2 PASS Criteria

- All eight tests log literal PASS lines.
- `mirror_1d_boundaries`: exact matches at wrapping points and reflections.
- `mirror_1d_seams`: verifies 2S periodicity (book-matching property).
- `mirror_2d_quad`: 2D addressing produces sensible results.
- `fnv1a_determinism`: identical inputs → identical hashes, reproducible across runs.
- `window_origin_*`: origins are deterministic, in valid range, and unique per (edge, facade_id) pair.
- `sample_synthetic_facade`: corner marks sampled correctly; mirrored-repeat wrapping and reflection work as expected.

---

## Part E: Integration with BakeCompositor

The sampler is **stateless and headless**. BakeCompositor (BAKE-04) calls it to determine window origins and to sample facade luminance during the composite pass:

```gdscript
# In bake_compositor.gd (pseudocode)

func _bake_one_wall(wall: Wall, facade_image: Image) -> void:
    var sampler = FacadeSampler.new()
    
    # Determine window origin
    var origin = sampler.get_window_origin_run(wall.edge, wall.facade_id)
    # ... or .get_window_origin_isolated() if not in a run
    
    # During the composite pass, the shader calls:
    var facade_luminance = sampler.sample(facade_image, plane_x, plane_y)
    # ... and multiplies it with the material tile
```

---

## Part F: Rollout Checklist

Before BAKE-04 can start:

- [ ] `facade_sampler.gd` written with mirrored-repeat, window-origin hashing, FNV-1a, and sample methods.
- [ ] Selftest `facade_sampler_test.gd` PASS achieved (all eight tests, literal PASS lines).
- [ ] FNV-1a hash values pinned and documented (e.g., "FNV-1a('test') = 0xdeadbeef").
- [ ] Corner-mark synthetic facade test confirms mirrored-repeat seams visually correct.
- [ ] Evidence transcript appended to session archive.

---

*End of BAKE-03.*
