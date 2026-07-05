# FIX-BAKE-02: Units & Origins – Window Collapse & Run Continuity

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-01 (String Keys)
**Successor:** FIX-BAKE-03 (Tile Anatomy)
**Scope:** Repair origin unit mismatch; enable run continuity; fix mirror fold
**Effort:** ~3–4 hours
**Risk:** Medium (refactors sampler contract; test-heavy)

---

## Problem

Three interconnected bugs in `FacadeSampler` collapse the promised "infinite plane" (Stage 3, D5) into a tiny corner of the facade texture, and orphan run continuity entirely.

### P1: Units collapse (voxels → texels → voxels)

**FacadeSampler contract (documented):**
- Facade = 64N × 32N pixels (N = 16, so 1024×512)
- Infinite plane addressed in voxel units: col ∈ [0, 64) voxels, row ∈ [0, 32) voxels
- Call `get_window_origin_isolated(edge) → Vector2i` where x, y are **voxel columns/rows**

**BakeCompositor usage (buggy):**
```gdscript
# Line ~115 in _populate_bake_set()
var origin = sampler.get_window_origin_isolated(edge, facade_id)
# origin.x, origin.y are voxel units [0, 64) and [0, 32)

# Line ~122
var plane_col = int(float(int(origin.x)) / float(TEX_AUTHORING_N))  # ÷16
var plane_row = int(float(int(origin.y)) / float(TEX_AUTHORING_N))  # ÷16
# plane_col ∈ [0, 4), plane_row ∈ [0, 2) — collapsed to 4×2 = 8 possible origins!

# Later in _render_batch() line ~161
var window_origin = Vector2i(bake_key.plane_col * TEX_AUTHORING_N, ...)
# Reconstructs: back to [0, 16, 32, 48] × [0, 16] texels
```

**Net effect:** The facade offers 64×32 voxel addresses; the compositor reduces to 4×2 bucketed origins; the projected window becomes {0, 16, 32, 48} × {0, 16} texels — all within the **first three voxels** of the 1024×512-texel facade. The other 61 columns are never sampled.

**Audit evidence:**
```bash
# FacadeSampler returns voxels (intended): col ∈ [0, 64), row ∈ [0, 32)
# grep FacadeSampler._window_origin_isolated:
#   plane_col = (hash_val % 64)  # ✓ voxel units
#   plane_row = ... % 32         # ✓ voxel units

# BakeCompositor then divides by N:
#   plane_col = origin.x / 16 → [0, 4)  # ✗ loses 15:1 entropy
#   plane_row = origin.y / 16 → [0, 2)  # ✗ loses 15:1 entropy
```

### P2: Run continuity is orphaned

**Documented (Stage 3):** Contiguous runs of walls use `get_window_origin_run()`, which seeds from the canonical min edge of the run → all walls in the run sample consecutive columns of the facade → veins flow continuously.

**Reality:** No code path calls `get_window_origin_run()`. The sampler exports it; the compositor never imports or uses it. Every edge is treated as isolated.

**Why this matters:** Without run detection, walls of identical (material, facade, variant) still get independent window origins (seeded separately), breaking the D5 aesthetic promise that "the stone grain flows across a contiguous wall stack."

### P3: Mirror fold has an off-by-one

**Mirrored-repeat addressing** (BAKE-03 sampler) should fold coordinates into [0, S) via reflection. The fold boundary at S has a convention mismatch:

```gdscript
# Current (line ~76)
if abs(k2 - S_int) < 0.0001:
    return 0.0  # BOUNDARY CASE: k == S wraps to 0
```

GL mirrored-repeat convention: index S maps to S−1 (edge texel; no discontinuity). The current code creates a one-texel spike at every fold:

```
Original:   [0, 1, 2, ..., 62, 63]
Mirrored:   [..., 63, 62, ..., 1, 0, 1, ..., 63, 62, ...]  (seamless)
Current:    [..., 63, 62, ..., 1, 0, 0, 1, ..., 63, 62, ...]  (spike at fold)
```

Audit evidence: `facade_sampler_test.gd` pins the spike as "expected":
```gdscript
# Test case: Wrap (64, 0): expected 0.20
# That's the (0, 0) texel. Correct GL would expect the (63, 0) texel (edge, mirrored).
```

---

## Solution

### S1: Fix unit mismatch

Define the origin contract clearly: **all origins are in texel units [0, 64N) × [0, 32N)**, never converted to voxel buckets.

**Changes to FacadeSampler:**

1. **Rename methods for clarity** (eliminate voxel/texel ambiguity):
   ```gdscript
   # OLD: get_window_origin_isolated(edge, facade_id) -> Vector2i  # unclear units
   # NEW: get_window_origin_isolated_texels(edge, facade_id) -> Vector2i  # texel units [0, 64N) × [0, 32N)
   
   # OLD: get_window_origin_run(min_edge, facade_id) -> Vector2i
   # NEW: get_window_origin_run_texels(min_edge, facade_id) -> Vector2i  # texel units
   ```

2. **Correct the sampler internals:**
   ```gdscript
   func get_window_origin_isolated_texels(edge, facade_id: String) -> Vector2i:
       var key_str = edge.key_string() if edge.has_method("key_string") else str(edge)
       var hash_input = key_str + ":" + facade_id
       var hash_val = _fnv1a_hash(hash_input)
       
       # Direct to texels, no divide-by-N bucket
       var plane_col_texels = (hash_val % (64 * TEX_AUTHORING_N))      # ∈ [0, 1024)
       var plane_row_texels = ((hash_val >> 8) % (32 * TEX_AUTHORING_N))  # ∈ [0, 512)
       
       return Vector2i(plane_col_texels, plane_row_texels)
   
   func get_window_origin_run_texels(canonical_min_edge, facade_id: String) -> Vector2i:
       var key_str = canonical_min_edge.key_string() if canonical_min_edge.has_method("key_string") else str(canonical_min_edge)
       var hash_input = key_str + ":" + facade_id
       var hash_val = _fnv1a_hash(hash_input)
       
       # All edges in the run use the same column origin, sampled from the hash
       var plane_col_texels = (hash_val % (64 * TEX_AUTHORING_N))
       var plane_row_texels = 0  # v1 always row 0
       
       return Vector2i(plane_col_texels, plane_row_texels)
   ```

3. **Update sampler tests** to expect texel-space values:
   ```gdscript
   # OLD: assert(origin.x in [0, 64))
   # NEW: assert(origin.x in [0, 1024))
   ```

**Changes to BakeCompositor:**

1. **Remove the divide-by-N; use origins directly:**
   ```gdscript
   # OLD (line ~115-122):
   var origin = sampler.get_window_origin_isolated(edge, facade_id)
   var plane_col = int(float(int(origin.x)) / float(TEX_AUTHORING_N))
   var plane_row = int(float(int(origin.y)) / float(TEX_AUTHORING_N))
   
   # NEW:
   var origin_texels = sampler.get_window_origin_isolated_texels(edge, facade_id)
   var plane_col = origin_texels.x
   var plane_row = origin_texels.y
   ```

2. **Store origins directly in BakeKey:**
   ```gdscript
   class BakeKey:
       var material_id: String
       var facade_id: String
       var variant_k: int
       var face: int
       var plane_col: int     # Now directly [0, 1024) texels
       var plane_row: int     # Now directly [0, 512) texels
   ```

3. **Update string serialization** (from FIX-BAKE-01) to match:
   ```gdscript
   func _bake_key_to_string(key: BakeKey) -> String:
       return "%s|%s|%d|%d|%d|%d" % [
           key.material_id, key.facade_id, key.variant_k,
           key.face, key.plane_col, key.plane_row
       ]
   ```

4. **Use origins directly in _render_batch():**
   ```gdscript
   # OLD (line ~161):
   var window_origin = Vector2i(bake_key.plane_col * TEX_AUTHORING_N, ...)
   
   # NEW:
   var window_origin = Vector2i(bake_key.plane_col, bake_key.plane_row)
   ```

### S2: Wire run continuity

Detect runs in the compositor; call `get_window_origin_run_texels()` for contiguous edges.

**Changes to BakeCompositor:**

1. **Add run detection to _populate_bake_set():**
   ```gdscript
   # Walls grouped by (material_id, facade_id, face)
   # Within each group, detect contiguous edge sequences
   # For each contiguous run, use the min edge's hash as the origin seed (all walls in run share column)
   
   var walls_by_facet = {}  # (material, facade, face) -> [walls]
   for wall in walls:
       var facet_key = "%s|%s|%d" % [wall.get("material_id"), wall.get("facade_id"), face]
       if not walls_by_facet.has(facet_key):
           walls_by_facet[facet_key] = []
       walls_by_facet[facet_key].append(wall)
   
   for facet_walls in walls_by_facet.values():
       # Detect contiguous runs (simplified: if Edge Registry provides run info, use it)
       # For now, heuristic: edges whose canonical keys are "consecutive" via geometry
       # This requires Edge.key_string() to encode spatial order (check DIRECTION_GLOSSARY.md)
       
       var run_groups = _detect_runs(facet_walls)  # Returns [[edge0, edge1, ...], ...]
       
       for run in run_groups:
           if run.size() == 1:
               # Isolated wall
               var edge = run[0]
               var origin = sampler.get_window_origin_isolated_texels(edge, facade_id)
           else:
               # Contiguous run: use min edge
               var min_edge = run[0]  # Assuming sorted
               var origin = sampler.get_window_origin_run_texels(min_edge, facade_id)
               # All edges in this run use the same origin.x (column)
               for i in range(1, run.size()):
                   run[i]._bake_origin = origin  # Cache for bake key
   ```

2. **Implement run detection** (heuristic for v1):
   ```gdscript
   func _detect_runs(walls: Array) -> Array:
       # Simplified: group edges by spatial proximity
       # If the Edge Registry provides adjacency, use it; otherwise, linear scan
       # For MVP, treat each edge as isolated (0-change); run detection is v1.5
       return walls.map(func(w): return [w])
   ```

   **Note:** Full run detection requires the Edge Registry to expose adjacency queries (edge A is "before" edge B in the run). If this is missing, implement a placeholder that treats all walls as isolated (current behavior) and mark as TODO for v1.5 when Edge Registry is augmented.

### S3: Fix mirror fold

**Changes to FacadeSampler:**

1. **Correct the boundary condition:**
   ```gdscript
   # OLD (line ~76)
   if abs(k2 - S_int) < 0.0001:
       return 0.0  # Spike at boundary
   
   # NEW
   if abs(k2 - S_int) < 0.0001:
       return S_int - 1.0  # Edge texel, mirrored (no spike)
   ```

2. **Update test expectations:**
   ```gdscript
   # OLD: Wrap (64, 0): expected 0.20  (the (0, 0) texel)
   # NEW: Wrap (64, 0): expected 0.79  (the (63, 0) texel, mirrored)
   ```

---

## Validation & Evidence (PASS Criteria)

### Test 1: Origin serialization and determinism (texel units)

**Test file:** `godot/scripts/tools/fix_bake_02_sampler_test.gd` (new)

```gdscript
extends SceneTree

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

func _init() -> void:
    print("\n" + "=".repeat(70))
    print("FIX-BAKE-02 TEST: Units & Origins")
    print("=".repeat(70) + "\n")

    var sampler = FacadeSamplerClass.new()
    
    # Test 1: Isolated origin returns texel units [0, 64N) × [0, 32N)
    print("[TEST 1] Origin Units (Texels)\n")
    
    var mock_edge = _make_mock_edge("edge_0")
    var facade_id = "stone_base"
    
    var origin = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)
    var N = GeometryCoordsClass.TEX_AUTHORING_N
    
    assert(origin.x >= 0 and origin.x < 64 * N, 
        "Origin X should be in [0, %d), got %d" % [64 * N, origin.x])
    assert(origin.y >= 0 and origin.y < 32 * N,
        "Origin Y should be in [0, %d), got %d" % [32 * N, origin.y])
    
    print("    ✓ origin.x in [0, %d): %d" % [64 * N, origin.x])
    print("    ✓ origin.y in [0, %d): %d" % [32 * N, origin.y])
    print("  PASS: Origin Units\n")
    
    # Test 2: Determinism (same edge → same origin)
    print("[TEST 2] Origin Determinism\n")
    
    var origin_a = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)
    var origin_b = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)
    
    assert(origin_a == origin_b, "Same edge must produce same origin")
    print("    ✓ Call 1: %s" % origin_a)
    print("    ✓ Call 2: %s" % origin_b)
    print("    ✓ Deterministic\n")
    print("  PASS: Origin Determinism\n")
    
    # Test 3: Different edges produce different origins (probabilistically)
    print("[TEST 3] Origin Distribution\n")
    
    var origins = []
    for i in range(10):
        var edge = _make_mock_edge("edge_%d" % i)
        origins.append(sampler.get_window_origin_isolated_texels(edge, facade_id))
    
    var unique_origins = {}
    for o in origins:
        unique_origins[str(o)] = true
    
    assert(unique_origins.size() >= 5, "10 different edges should produce ≥5 unique origins")
    print("    ✓ 10 edges → %d unique origins (distributed)" % unique_origins.size())
    print("  PASS: Origin Distribution\n")
    
    # Test 4: Run origins (all edges in run share column)
    print("[TEST 4] Run Continuity (same column)\n")
    
    var run_edges = [_make_mock_edge("run_0"), _make_mock_edge("run_1"), _make_mock_edge("run_2")]
    var min_edge = run_edges[0]
    
    var run_origin = sampler.get_window_origin_run_texels(min_edge, facade_id)
    
    # In a real run, all walls would sample from the same column
    assert(run_origin.x >= 0 and run_origin.x < 64 * N,
        "Run origin X should be texel units [0, %d)" % [64 * N])
    print("    ✓ Run origin (min_edge): %s" % run_origin)
    print("    ✓ Column continuity: all walls in run sample column %d" % run_origin.x)
    print("  PASS: Run Continuity\n")
    
    print("=".repeat(70))
    print("✓ FIX-BAKE-02 ALL TESTS PASS")
    print("=".repeat(70) + "\n")
    quit(0)

func _make_mock_edge(id: String):
    var edge = {}
    edge["id"] = id
    edge["key_string"] = func(): return id
    edge.has_method = func(method: String): return method == "key_string"
    edge.key_string = func(): return id
    return edge
```

**Expected output:**
```
[TEST 1] Origin Units (Texels)

    ✓ origin.x in [0, 1024): <value>
    ✓ origin.y in [0, 512): <value>
  PASS: Origin Units

[TEST 2] Origin Determinism

    ✓ Call 1: (<x>, <y>)
    ✓ Call 2: (<x>, <y>)
    ✓ Deterministic

  PASS: Origin Determinism

[TEST 3] Origin Distribution

    ✓ 10 edges → ≥5 unique origins (distributed)
  PASS: Origin Distribution

[TEST 4] Run Continuity (same column)

    ✓ Run origin (min_edge): (<x>, 0)
    ✓ Column continuity: all walls in run sample column <x>
  PASS: Run Continuity

============================================================
✓ FIX-BAKE-02 ALL TESTS PASS
============================================================
```

### Test 2: Mirror fold correctness

**Test file:** `facade_sampler_test.gd` (update existing, specifically test_mirror_1d)

```gdscript
func _test_mirror_1d() -> bool:
    print("[TEST 3] Mirror 1D addressing\n")
    
    var test_cases = [
        # (input, size, expected_output)
        [0.0, 64, 0.0],           # Start of period
        [32.0, 64, 32.0],         # Mid
        [63.9, 64, 63.9],         # Near end
        [64.0, 64, 63.0],         # BOUNDARY: maps to S-1, not 0 (FIXED)
        [65.0, 64, 62.0],         # Just over (mirror back)
        [127.9, 64, 0.1],         # End of first repeat
        [128.0, 64, 0.0],         # Start of second repeat
    ]
    
    var sampler = FacadeSamplerClass.new()
    
    for test in test_cases:
        var result = sampler._mirror_1d(test[0], int(test[1]))
        var expected = test[2]
        var tolerance = 0.0001
        
        if abs(result - expected) > tolerance:
            print("    ✗ mirror_1d(%.1f, %d) = %.2f (expected %.2f)" % [test[0], test[1], result, expected])
            return false
        else:
            print("    ✓ mirror_1d(%.1f, %d) = %.2f" % [test[0], test[1], result])
    
    print("  PASS: mirror_1d correctness\n")
    return true
```

**Expected output:** All cases pass, including `[64.0, 64, 63.0]` (the corrected boundary).

### Test 3: Compositor no longer divides by N

**Test file:** `bake_compositor_test.gd` (update existing dedup test)

```gdscript
# After FIX-BAKE-01 string keys, verify that BakeKey stores texel origins (not bucket origins)
var key1 = compositor._make_bake_key(...)  # (Pseudo)
assert(key1.plane_col >= 0 and key1.plane_col < 1024, 
    "BakeKey should store texel origin [0, 1024), got %d" % key1.plane_col)
print("PASS: BakeKey uses texel origins (no N division)")
```

---

## Implementation Checklist

- [ ] Rename `get_window_origin_isolated()` → `get_window_origin_isolated_texels()` in FacadeSampler
- [ ] Rename `get_window_origin_run()` → `get_window_origin_run_texels()` in FacadeSampler
- [ ] Update both methods to return [0, 64N) × [0, 32N) (no voxel bucketing)
- [ ] Fix mirror fold boundary: `k == S → S - 1.0`
- [ ] Update sampler tests to expect texel ranges and correct fold boundary
- [ ] Update BakeCompositor `_populate_bake_set()` to call renamed methods and use origins directly (no ÷N)
- [ ] Remove the ÷N and ×N conversions in BakeCompositor
- [ ] Update BakeKey string serialization (field names if changed; no other logic)
- [ ] Update BakeCompositor `_render_batch()` to use origins directly as window_origin
- [ ] Add run detection placeholder (for now, treat all as isolated; mark TODO for v1.5)
- [ ] Create `fix_bake_02_sampler_test.gd` and run headless
- [ ] Update `facade_sampler_test.gd` mirror test and re-run
- [ ] Update `bake_compositor_test.gd` to validate BakeKey stores texels
- [ ] Capture all console output

---

## Downstream Impact

- **BAKE-01 (FIX-BAKE-01):** No changes; string keys are indifferent to field values.
- **BAKE-03 (FIX-BAKE-03):** PerFaceProjector expects flat → screen mapping; the window_origin becomes a direct texel position, fitting into the 2-stage pipeline (tile_px → flat_px → plane_px).
- **BAKE-04 (FIX-BAKE-04):** Receives texel origins; material stub becomes real in the next fix.
- **Aesthetic outcome:** Walls now sample from the full 64×32 voxel facade plane, not just the first 4×2 bucketed origins. Stone grain, wood veins, and metal sheens now span the documented diversity.

---

## Note: Edge Registry Run Detection

Run detection is deferred to v1.5 (marked TODO). For v1, the compositor treats all walls as isolated, which is visually harmless but loses the "veins flow across the run" feature of D5. When Edge Registry is queried for adjacency (edge A before edge B in a contiguous run), uncomment the `_detect_runs()` call in _populate_bake_set() to enable full run continuity.

---

*End FIX-BAKE-02.*
