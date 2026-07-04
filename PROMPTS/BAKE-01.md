# BAKE-01: Tile Anatomy Audit & PerFaceProjector

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `TILE_ANATOMY.md` (diagnostic reference), `per_face_projector.gd` module + T1 selftest
**Predecessor:** `TEX-CATALOG-01` (TextureResolver in place)
**Successor:** `BAKE-02` (MaterialRegistry, consumes projector transforms)
**Status:** Ready for implementation
**PASS criteria:** Integer-shear assertion at pinned N passes for all four vertical face orientations; round-trip transforms match expected behavior within floating-point tolerance; selftest outputs literal PASS lines with per-orientation results

---

## Context: Why This Prompt Exists

The baking pipeline's single-pass inverse mapping (§BAKING_MASTER_PLAN D3, §3 Stage 4) requires an authoritative mathematical model of how flat texture-space maps to on-screen tile pixels. This model must account for two things:

1. **The actual tile geometry** that the current renderer uses (including the legacy `TILE_OFFSET = (112, 64)` empirical calibration from SLICE-02).
2. **The affine transform** that collapses facade crop + isometric skew into one operation.

Both are already implicit in the running game; this prompt makes them explicit, tests them, and **derives the N constant** (flat texels per voxel) such that the transform produces integer pixel offsets — guaranteeing NEAREST sampling with zero subpixel aliasing.

SLICE-00 lesson: *diagnose geometry before touching it.* We are not designing a transform; we are **extracting it from the canonical system that already works**, then proving the extraction is faithful.

---

## Part A: Tile Anatomy Audit

### A.1 Reference Frame

The current voxel system places walls via `TileMapLayer.set_cell(coords, source_id, atlas_coords)`, where `atlas_coords` is a Vector2i into a `TileSetAtlasSource`. Each tile occupies a **region** of pixels in the atlas, defined by:

```
texture_region = Rect2i(
    origin_px + atlas_coords * region_size,
    region_size
)
```

Properties already canon (from VOXEL_MASTER_PLAN, validated in VOXEL-04/VOXEL-05):
- `VOXEL_TILE_SIZE = (32, 16)` — screen-space isometric tile dimensions.
- `VOXEL_TILE_OFFSET_PX = (112, 64)` — offset from the origin of a TileMapLayer cell to the top-left of the rendered tile (screen-space, isometric).
- `VOXEL_STEP_PX = 20.0` — the "unstretched" distance (pre-skew) in flat texture space. Derived analytically.
- `VOXELS_PER_UNIT_AXIS = 8` — voxel granularity per GU (also the storey height per BAKING_MASTER_PLAN D6).
- `VOXEL_TILE_SIZE_FLAT = (32, 32)` — flat texture space dimensions (square, before shear transform).

### A.2 Four Face Orientations

The vertex-aligned compass (DIRECTION_GLOSSARY.md) yields four vertical wall faces under 90° rotations of perspective. We label them by their cardinal vertex facing (the vertex pointing toward the camera):

| Label | Cardinal | Visual orientation | Shear axis | Shear direction |
|-------|----------|-------------------|------------|-----------------|
| **NE** | Northeast | tilted right | horizontal | rightward |
| **SE** | Southeast | tilted down | vertical | downward |
| **SW** | Southwest | tilted left | horizontal | leftward |
| **NW** | Northwest | tilted up | vertical | upward |

Each face has its own affine transform from flat texture space → screen space (the isometric shear). The four transforms are **not free parameters**; they are determined by the 2D isometric projection geometry.

### A.3 Canonical Tile Pixel Mapping

For each face orientation, identify which on-screen pixel regions (within the `VOXEL_TILE_SIZE = (32, 16)` cell) correspond to which voxel-face texels.

**Example (NE face, one 8×8 voxel quad):**

```
Flat texture space (8×8 voxels × N texels/voxel = 8N × 8N pixels):
  ┌────────────────┐
  │                │
  │   8N × 8N      │
  │  (one voxel    │
  │   quad)        │
  └────────────────┘

Screen space (isometric, 32×16 pixels):
  ╱╲
 ╱  ╲  ← tilted right (shear rightward)
│    │
╲  ╱
 ╲╱
```

The **audit** task: for the NE face, enumerate which ranges of flat pixels map to which on-screen coordinates. This is a **matrix extraction** from the canonical tileset that already renders correctly.

**Procedure:**

1. **Create a diagnostic facade** — a corner-marked probe texture:
   - Flat space: `8N × 8N` pixels, white fill with colored 1-pixel marks at known positions (corners, edges, centers). Example: red at (0,0), green at (8N, 0), blue at (0, 8N), yellow at (8N, 8N), magenta at (4N, 4N).
   - This will be baked as if it were a single voxel face.

2. **Render the baked voxel** to the screen and capture a screenshot.

3. **Measure pixel positions** of the colored marks on-screen using the debug tools (F-key suite from SLICE-02).

4. **Solve for the transform** from flat coordinates → screen coordinates that maps the probe marks to their observed positions.

5. **Verify integer shear:** for each column of the flat texture, compute the vertical offset in screen space. All offsets must be integers (no fractional pixel boundaries). If not, N is wrong; iterate.

6. **Repeat for SE, SW, NW orientations.**

### A.4 Expected Transform Structure

Each orientation's transform is an affine map:

```
screen_xy = M_affine * flat_xy + offset
```

where `M_affine` is a 2×2 matrix (scale + shear) and `offset` is a translation. For isometric geometry:

```
NE: M = [[1,   0.5], [0, -0.5]]  (right-heavy shear)
SE: M = [[0.5, 0],   [0.5, 0.5]] (down-heavy shear)
SW: M = [[1,   -0.5],[0,  0.5]]  (left-heavy shear)
NW: M = [[-0.5, 0],  [-0.5, 0.5]](up-heavy shear)
```

(Exact coefficients depend on the empirical calibration; these are illustrative.)

The audit extracts the actual coefficients and offsets from the canonical tileset.

### A.5 Integer Shear Invariant

**Critical property (§BAKING_MASTER_PLAN §3 Stage 4, §4.5):**

For the chosen N, every column of the flat texture (x ∈ [0, 8N)) must map to screen y-offsets that are all integers. Formally:

```
For each flat_x in [0, 8N):
  screen_y_at_left  = M[1,0] * flat_x + offset_y
  screen_y_at_right = M[1,0] * flat_x + M[1,1] * flat_height + offset_y
  
  All in-between y values on the shear line must be integers.
```

**Why this matters:** NEAREST texture filtering works on integer boundaries. If a column's on-screen position is fractional, linear interpolation is needed, introducing subpixel bleeding and breaking the crisp voxel aesthetic. By pinning N such that shear offsets are integers, we guarantee **one-texel-to-one-pixel fidelity.**

**Testing:** the selftest asserts this property for each orientation:

```gdscript
func _assert_integer_shear(orientation: Face, N: int) -> void:
    var projector = PerFaceProjector.new()
    for flat_x in range(0, 8 * N):
        var top = projector.flat_to_screen(orientation, Vector2(flat_x, 0))
        var bot = projector.flat_to_screen(orientation, Vector2(flat_x, 8.0 * N))
        
        # Assert all intermediates are integer Y
        for flat_y in range(0, int(8 * N) + 1):
            var screen_pos = projector.flat_to_screen(orientation, Vector2(flat_x, flat_y))
            assert(int(screen_pos.y) == screen_pos.y, "Non-integer Y at flat (%d, %d) on %s" % [flat_x, flat_y, orientation])
```

If this assertion fails, N needs adjustment. E.g., if shear slope is 1:2, then N must be even so that `flat_x * 0.5` is always integral.

---

## Part B: PerFaceProjector Module

### B.1 Interface

```gdscript
class_name PerFaceProjector

# Transform a point in flat texture space → screen space (isometric)
func flat_to_screen(face: Face, flat_px: Vector2) -> Vector2:
    # face ∈ { NE, SE, SW, NW } (or enum equivalent)
    # flat_px: coordinates in the flat texture, [0, 8N) × [0, 8N) for a voxel quad
    # Returns: screen-space coordinates (float, before integer rounding)

# Inverse: screen space → flat texture space
func screen_to_flat(face: Face, screen_px: Vector2) -> Vector2:
    # screen_px: coordinates on the rendered tile
    # Returns: flat texture coordinates

# Check if a screen pixel is within the voxel face (silhouette check)
func is_inside_voxel(face: Face, screen_px: Vector2) -> bool:
    # Returns true if screen_px falls within the isometric parallelogram of the voxel face
```

### B.2 Transform Extraction (Audit Outcome)

After the Tile Anatomy Audit, the projector is populated with the pinned transforms. Pseudo-code:

```gdscript
class_name PerFaceProjector

const VOXEL_TILE_SIZE = Vector2i(32, 16)
const VOXEL_TILE_OFFSET_PX = Vector2i(112, 64)
const VOXEL_STEP_PX = 20.0

# The four orientations and their transforms
# (These will be filled in by the audit; placeholder structures below)

var transforms: Dictionary = {
    Face.NE: {
        "matrix": [[1.0, 0.5], [0.0, -0.5]],       # Illustrative; audit refines
        "offset": Vector2(0, 8 * N * 0.5),        # Illustrative
    },
    Face.SE: {
        "matrix": [[0.5, 0.0], [0.5, 0.5]],
        "offset": Vector2(0, 0),
    },
    # ... SW, NW similarly
}

var N: int  # Flat texels per voxel (pinned by audit)

func _init(audit_outcome: AuditOutcome) -> void:
    # audit_outcome is produced by the audit script and contains:
    # - N (pinned constant)
    # - transforms for each face (M_affine + offset)
    
    N = audit_outcome.N
    transforms = audit_outcome.transforms
    _assert_integer_shear_all_faces()

func flat_to_screen(face: Face, flat_px: Vector2) -> Vector2:
    var t = transforms[face]
    var M = t["matrix"]
    var offset = t["offset"]
    
    var screen_x = M[0][0] * flat_px.x + M[0][1] * flat_px.y + offset.x
    var screen_y = M[1][0] * flat_px.x + M[1][1] * flat_px.y + offset.y
    
    return Vector2(screen_x, screen_y)

func screen_to_flat(face: Face, screen_px: Vector2) -> Vector2:
    var t = transforms[face]
    var M = t["matrix"]
    var offset = t["offset"]
    
    # Invert the affine: flat = M^-1 * (screen - offset)
    var M_inv = _invert_2x2(M)
    var centered = screen_px - offset
    
    var flat_x = M_inv[0][0] * centered.x + M_inv[0][1] * centered.y
    var flat_y = M_inv[1][0] * centered.x + M_inv[1][1] * centered.y
    
    return Vector2(flat_x, flat_y)

func is_inside_voxel(face: Face, screen_px: Vector2) -> bool:
    # For isometric, the voxel face is a parallelogram
    # Corners in screen space (derived from the transform, pinned after audit):
    var corners = _get_corners(face)
    
    # Point-in-parallelogram test (barycentric or cross-product)
    return _point_in_quad(screen_px, corners)

func _assert_integer_shear_all_faces() -> void:
    for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
        for flat_x in range(0, 8 * N):
            var top_y = flat_to_screen(face, Vector2(flat_x, 0.0)).y
            var bot_y = flat_to_screen(face, Vector2(flat_x, 8.0 * N)).y
            
            # Check all intermediate y values are integers
            for flat_y in range(0, int(8 * N) + 1):
                var screen_pos = flat_to_screen(face, Vector2(flat_x, flat_y))
                assert(fmod(screen_pos.y, 1.0) < 0.0001, 
                    "Non-integer Y at (%d, %d) on %s: %.4f" % [flat_x, flat_y, face, screen_pos.y])
    
    print("PASS: integer_shear_all_faces")

func _invert_2x2(M: Array) -> Array:
    # M = [[a, b], [c, d]]
    # M^-1 = (1/(ad-bc)) * [[d, -b], [-c, a]]
    var a = M[0][0]
    var b = M[0][1]
    var c = M[1][0]
    var d = M[1][1]
    
    var det = a * d - b * c
    assert(abs(det) > 0.0001, "Singular matrix; no inverse")
    
    var inv_det = 1.0 / det
    return [
        [inv_det * d, -inv_det * b],
        [-inv_det * c, inv_det * a]
    ]

func _get_corners(face: Face) -> Array:
    # Return screen-space corners of the voxel face parallelogram
    # Derived from flat corners (0,0), (8N,0), (8N,8N), (0,8N)
    var corners = []
    for flat_corner in [Vector2(0, 0), Vector2(8.0*N, 0), Vector2(8.0*N, 8.0*N), Vector2(0, 8.0*N)]:
        corners.append(flat_to_screen(face, flat_corner))
    return corners

func _point_in_quad(pt: Vector2, corners: Array) -> bool:
    # Barycentric or cross-product test; standard in graphics
    # (assumes corners is a list of 4 points in order)
    # Placeholder: implement as cross-product sign consistency
    pass
```

### B.3 Cap Face (Forward-compatible, not used in v1)

For completeness, the projector includes a transform for the **cap** (top of the wall). The cap compresses both axes in the diamond projection:

```
Cap transform (illustrative; audit refines):
    M_cap = [[0.5, 0.5], [-0.5, 0.5]]  # Both axes compressed + rotated
```

The cap is not baked in v1 (caps are material-only per BAKING_MASTER_PLAN D7), but the transform is extracted and stored for forward compatibility with multi-storey walls.

---

## Part C: Selftest & Validation

### C.1 T1 Selftest (Pure math, headless)

In `per_face_projector_test.gd`:

```gdscript
func run_all_tests() -> void:
    test_round_trip_transforms()
    test_integer_shear_assertion()
    test_point_in_voxel()
    test_inverse_correctness()

func test_round_trip_transforms() -> void:
    var projector = PerFaceProjector.new(audit_outcome)
    
    for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
        # Pick some test points in flat space
        for flat_pt in [Vector2(0, 0), Vector2(4.0*N, 4.0*N), Vector2(8.0*N, 8.0*N)]:
            var screen_pt = projector.flat_to_screen(face, flat_pt)
            var recovered = projector.screen_to_flat(face, screen_pt)
            
            assert(recovered.distance_to(flat_pt) < 0.01, 
                "Round-trip failed for %s at %s" % [face, flat_pt])
    
    print("PASS: round_trip_transforms")

func test_integer_shear_assertion() -> void:
    var projector = PerFaceProjector.new(audit_outcome)
    # The projector's _init calls _assert_integer_shear_all_faces()
    # which prints PASS if it succeeds; if not, assertion failure halts.
    print("PASS: integer_shear_assertion (confirmed by init)")

func test_point_in_voxel() -> void:
    var projector = PerFaceProjector.new(audit_outcome)
    
    for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
        # Center of the voxel should be inside
        var center_flat = Vector2(4.0 * N, 4.0 * N)
        var center_screen = projector.flat_to_screen(face, center_flat)
        assert(projector.is_inside_voxel(face, center_screen), 
            "Center not inside voxel: %s" % face)
        
        # Far outside should be outside
        var outside_screen = center_screen + Vector2(100, 100)
        assert(not projector.is_inside_voxel(face, outside_screen), 
            "Outside point not rejected: %s" % face)
    
    print("PASS: point_in_voxel")

func test_inverse_correctness() -> void:
    var projector = PerFaceProjector.new(audit_outcome)
    
    # Test that screen_to_flat is the true inverse of flat_to_screen
    # by checking that M^-1 * M = I (identity)
    for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
        var M = projector.transforms[face]["matrix"]
        var M_inv = projector._invert_2x2(M)
        
        # M * M_inv should be identity (within tolerance)
        var product = _multiply_2x2(M, M_inv)
        assert(abs(product[0][0] - 1.0) < 0.0001, "M*M_inv not identity")
        assert(abs(product[0][1]) < 0.0001, "M*M_inv off-diagonal non-zero")
        assert(abs(product[1][0]) < 0.0001, "M*M_inv off-diagonal non-zero")
        assert(abs(product[1][1] - 1.0) < 0.0001, "M*M_inv not identity")
    
    print("PASS: inverse_correctness")

func _multiply_2x2(A: Array, B: Array) -> Array:
    var result = Array()
    result.resize(2)
    for i in range(2):
        result[i] = []
        result[i].resize(2)
        for j in range(2):
            result[i][j] = A[i][0] * B[0][j] + A[i][1] * B[1][j]
    return result
```

**PASS criteria:**
- `test_round_trip_transforms`: All test points recover within 0.01 pixel tolerance.
- `test_integer_shear_assertion`: No assertion failures; projector init completes.
- `test_point_in_voxel`: Center points marked as inside; far points marked as outside.
- `test_inverse_correctness`: M * M_inv = I within tolerance, for all four faces.
- **Console evidence:** Each test prints a literal PASS line.

### C.2 Audit Script (Extracted from TILE_ANATOMY_AUDIT.gd)

A companion script (not the main prompt, but part of the deliverable) performs the probe-texture audit:

```gdscript
# tile_anatomy_audit.gd (companion script, run manually or in CI)

func run_audit() -> AuditOutcome:
    # 1. Create probe facade (corner-marked 8N × 8N grayscale)
    var probe = _create_probe_facade(N)
    
    # 2. Bake the probe as a single voxel face (one-off bake, not using the full pipeline)
    var baked_voxel = _bake_probe_single_voxel(probe)
    
    # 3. Render baked voxel to screen, capture screenshot
    var screenshot = _render_and_capture(baked_voxel)
    
    # 4. Measure probe marks on-screen using color detection
    var measured_points = _detect_probe_marks_on_screen(screenshot)
    # measured_points = { "red": (x,y), "green": (x,y), ... }
    
    # 5. Solve for transforms (least-squares fit of measured → expected)
    var transforms = _solve_transforms_all_faces(measured_points, N)
    
    # 6. Validate integer shear
    var N_final = _validate_and_pin_N(transforms, N)
    
    return AuditOutcome.new(N_final, transforms)

func _create_probe_facade(N: int) -> Image:
    var img = Image.create(8*N, 8*N, false, Image.FORMAT_L8)
    
    # White fill
    for y in range(8*N):
        for x in range(8*N):
            img.set_pixel(x, y, Color.WHITE)
    
    # Colored corner marks (1-pixel, recognizable in rendered result)
    img.set_pixel(0, 0, Color.RED)            # top-left
    img.set_pixel(8*N-1, 0, Color.GREEN)      # top-right
    img.set_pixel(8*N-1, 8*N-1, Color.BLUE)   # bottom-right
    img.set_pixel(0, 8*N-1, Color.YELLOW)     # bottom-left
    img.set_pixel(4*N, 4*N, Color.MAGENTA)    # center
    
    return img
```

The audit script outputs a `TILE_ANATOMY.md` report and an `AuditOutcome` JSON/GDScript object that feeds into the projector init.

---

## Part D: TILE_ANATOMY.md Deliverable

A reference document (not executable) that records:

1. **Audit procedure:** step-by-step of how the transforms were extracted.
2. **Measured values:** the actual M matrices and offsets for each face (example N=16 case).
3. **Integer shear validation:** per-orientation affirmation that all column offsets are integers.
4. **Proof images:** screenshots of the probe voxel rendered under each orientation, with marked points annotated.

Format:

```markdown
# TILE ANATOMY AUDIT REPORT

## Audit Date & Environment
- Date: YYYY-MM-DD
- Godot version: 4.6+
- N (flat texels per voxel): 16 (PINNED)

## Extracted Transforms

### Face NE (Northeast)
Matrix:
```
[ 1.000   0.500 ]
[ 0.000  -0.500 ]
```
Offset: (0, 128)

Integer shear validation: ✓ (All column offsets [0, 128) are integers)

### Face SE, SW, NW
(similarly)

## Proof Images
- `tile_anatomy_probe_NE.png` (screenshot with marks annotated)
- `tile_anatomy_probe_SE.png`
- (etc.)

## Conclusion
N = 16 is the minimal value at which all four orientations produce integer shear.
```

---

## Part E: Rollout Checklist

Before BAKE-02 can start:

- [ ] Tile Anatomy Audit completed (probe rendered, transforms extracted, annotated screenshots captured).
- [ ] `per_face_projector.gd` written with extracted transforms (not placeholders).
- [ ] Selftest `per_face_projector_test.gd` PASS achieved (round-trip, integer shear, point-in-voxel, inverse correctness).
- [ ] `TILE_ANATOMY.md` finalized with measured values and proof images.
- [ ] N pinned as a constant in a shared header (e.g., `texture_constants.gd`), injected into TextureResolver (TEX-CATALOG-01) and all downstream modules.
- [ ] Evidence transcript (console PASS lines + audit report) appended to session archive.

---

*End of BAKE-01.*

---

## Appendix: Quick Reference — The Four Transforms (Placeholder)

**Replace with audit-extracted values after completing the Tile Anatomy Audit.**

```gdscript
# Placeholder; do not use until audit is complete
const TRANSFORM_NE = {
    "matrix": [[1.0, 0.5], [0.0, -0.5]],
    "offset": Vector2(0, 128)
}

const TRANSFORM_SE = {
    "matrix": [[0.5, 0.0], [0.5, 0.5]],
    "offset": Vector2(16, 0)
}

const TRANSFORM_SW = {
    "matrix": [[1.0, -0.5], [0.0, 0.5]],
    "offset": Vector2(32, 128)
}

const TRANSFORM_NW = {
    "matrix": [[-0.5, 0.0], [-0.5, 0.5]],
    "offset": Vector2(16, 0)
}
```

These values are **illustrative**. The audit **measures and refines** them against the canonical tileset geometry.
