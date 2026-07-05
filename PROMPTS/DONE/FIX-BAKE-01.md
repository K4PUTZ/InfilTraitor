# FIX-BAKE-01: Canonical String Keys for Real Deduplication

**Status:** Ready for implementation
**Predecessor:** AUDIT_BAKE_20260704
**Successor:** FIX-BAKE-02 (Units & Origins)
**Scope:** Repair BakeKey object-identity bug; enable dedup and lookup hits
**Effort:** ~2–3 hours
**Risk:** Low (isolated to baking modules, not live code)

---

## Problem

`BakeCompositor._populate_bake_set()` and `BakedTileLookup.resolve()` use `BakeKey` **object instances** as Dictionary keys. GDScript Dictionaries compare Objects by **instance identity** (pointer equality), not field equality. The hand-written `_hash()` / `_is_equal()` methods on the BakeKey class are decorative and ignored by the engine.

Consequences:
1. **Deduplication never deduplicates.** Two walls of identical material/facade/variant/face/window produce two distinct entries. The compositor's "Pre-dedup: N, Post-dedup: M" accounting is fiction (M = N × 4 or N × 2 depending on how many faces per wall).
2. **Lookup never hits.** `BakedTileLookup.resolve()` constructs a fresh BakeKey and calls `baked_atlas.lookup.has(bake_key)` — comparing the fresh instance against the compositor's original instances via identity guarantees a miss. Even if baking is enabled and atlas populated, every resolve falls through to the generic fallback, defeating the entire purpose of the swap.
3. **Atlas pages proliferate unnecessarily.** With broken dedup, all (material, facade, variant, face, window) combinations become distinct entries; a typical map bakes every key exactly once, filling pages without consolidation.

### Audit Evidence

```bash
cd /home/claude/backup/INFILTRAITOR/godot/scripts/systems
# BakeKey definition (bake_compositor.gd, lines ~22–42)
class BakeKey:
    var material_id: String
    var facade_id: String
    var variant_k: int
    var face: int
    var plane_col: int
    var plane_row: int

    func _hash() -> int:
        # These methods are never called by Godot Dictionary
        ...
    func _is_equal(other: BakeKey) -> bool:
        # These methods are never called by Godot Dictionary
        ...

# Usage in compositor (line ~92)
bake_set[key] = null  # key is a BakeKey instance

# Verification: grep shows no caller of _hash() or _is_equal()
grep -rn "_hash\|_is_equal" --include="*.gd" .
# Result: only the definitions in bake_compositor.gd; zero callers
```

---

## Solution: Serialized String Keys

Replace object identity with **value-based string serialization**. The key becomes a deterministic String computed from the BakeKey fields:

```
key_string = "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
```

Since Godot Dictionaries use the String's hash (stable, value-based), identical field tuples produce identical key strings, enabling both dedup and lookup hits.

### Changes to BakeCompositor

1. **Rename `bake_set` to use String keys directly.** Replace `Dictionary[BakeKey] bake_set` with `Dictionary[String] bake_set` (value can remain null or be discarded).
2. **Modify `_populate_bake_set()` to serialize keys.** At line ~137 (after constructing a BakeKey), add a helper to convert to string:
   ```gdscript
   func _bake_key_to_string(key: BakeKey) -> String:
       return "%s|%s|%d|%d|%d|%d" % [
           key.material_id, key.facade_id, key.variant_k,
           key.face, key.plane_col, key.plane_row
       ]
   ```
   Then: `bake_set[_bake_key_to_string(key)] = null` instead of `bake_set[key] = null`.
3. **Update dedup accounting.** The compositor already logs pre/post counts; verify the post-dedup count is now < pre-dedup × 4 (fractional, not full enumeration).

### Changes to BakedTileLookup

1. **Use the same string serialization.** Import/define the same `_bake_key_to_string()` helper (or move it to a shared utility class).
2. **Lookup now queries by string.** In `resolve()`, after constructing the BakeKey:
   ```gdscript
   var key_str = _bake_key_to_string(bake_key)
   if baked_atlas and baked_atlas.lookup.has(key_str):
       # THIS NOW HITS (proof of success)
       var baked_coords = baked_atlas.lookup[key_str]
       return TileLookupResult.new(...)
   ```
3. **BakeCompositor must also return lookup indexed by string.** Update `_render_batch()` line ~173:
   ```gdscript
   lookup[_bake_key_to_string(bake_key)] = { "page": page_idx, "atlas_coords": ... }
   ```

### Changes to BakedAtlas class

The BakedAtlas class (inside BakeCompositor) already has `lookup: Dictionary`. Verify it's written with string keys:
```gdscript
class BakedAtlas extends RefCounted:
    var pages: Array[Image] = []
    var lookup: Dictionary = {}  # Now indexed by String (not BakeKey)
```

No code change needed if the compositor is fixed; the lookup is already a plain Dictionary.

---

## Validation & Evidence (PASS Criteria)

All tests below must pass and print literal **PASS** lines that can fail (not unconditional). Use assertions that can be violated.

### Test 1: String serialization is deterministic and value-based

**Test file:** `godot/scripts/tools/fix_bake_01_test.gd` (new)

```gdscript
extends SceneTree

func _init() -> void:
    print("\n" + "=".repeat(70))
    print("FIX-BAKE-01 TEST: String Key Deduplication")
    print("=".repeat(70) + "\n")

    var test_passed = true

    # Test 1: Identical BakeKeys produce identical strings
    print("[TEST 1] String Serialization Determinism\n")
    var key1 = BakeKey.new()
    key1.material_id = "stone"
    key1.facade_id = "marble_base"
    key1.variant_k = 2
    key1.face = 0  # NE
    key1.plane_col = 8
    key1.plane_row = 0

    var key2 = BakeKey.new()
    key2.material_id = "stone"
    key2.facade_id = "marble_base"
    key2.variant_k = 2
    key2.face = 0
    key2.plane_col = 8
    key2.plane_row = 0

    var str1 = _bake_key_to_string(key1)
    var str2 = _bake_key_to_string(key2)

    assert(str1 == str2, "Identical keys must produce identical strings")
    print("    ✓ key1 string: %s" % str1)
    print("    ✓ key2 string: %s" % str2)
    print("    ✓ str1 == str2 (deterministic)\n")
    print("  PASS: String Serialization Determinism\n")

    # Test 2: Different BakeKeys produce different strings
    print("[TEST 2] String Uniqueness (different fields)\n")
    var key3 = key1.duplicate()
    key3.material_id = "wood"  # Different material

    var str3 = _bake_key_to_string(key3)
    assert(str1 != str3, "Different keys must produce different strings")
    print("    ✓ key1 (stone): %s" % str1)
    print("    ✓ key3 (wood):  %s" % str3)
    print("    ✓ str1 != str3 (unique)\n")
    print("  PASS: String Uniqueness\n")

    # Test 3: Dictionary deduplication with String keys
    print("[TEST 3] Dictionary Deduplication\n")
    var bake_set = {}
    bake_set[str1] = null
    bake_set[str2] = null  # Same key, should not increase size
    bake_set[str3] = null  # Different key

    assert(bake_set.size() == 2, "Dedup should reduce 3 entries to 2")
    print("    ✓ Added str1, str2 (same), str3 (diff)")
    print("    ✓ Set size: %d (expected 2)" % bake_set.size())
    print("    ✓ Deduplication working\n")
    print("  PASS: Dictionary Deduplication\n")

    # Test 4: Lookup can find entries (the live requirement)
    print("[TEST 4] Lookup Hit\n")
    var lookup = {}
    lookup[str1] = { "page": 0, "atlas_coords": Vector2i(5, 3) }

    var found = lookup.has(str1)
    var not_found = lookup.has("nonexistent|key")
    assert(found, "Lookup must find existing keys")
    assert(not not_found, "Lookup must not find missing keys")
    print("    ✓ lookup.has(str1) = true")
    print("    ✓ lookup.has('nonexistent') = false")
    print("    ✓ Lookup working\n")
    print("  PASS: Lookup Hit\n")

    print("=".repeat(70))
    print("✓ FIX-BAKE-01 ALL TESTS PASS")
    print("=".repeat(70) + "\n")
    quit(0)

func _bake_key_to_string(key) -> String:
    # Placeholder: implementation will live in compositor
    # For this test, we implement it inline
    return "%s|%s|%d|%d|%d|%d" % [
        key.material_id, key.facade_id, key.variant_k,
        key.face, key.plane_col, key.plane_row
    ]
```

**Expected output (literal):**
```
[TEST 1] String Serialization Determinism

    ✓ key1 string: stone|marble_base|2|0|8|0
    ✓ key2 string: stone|marble_base|2|0|8|0
    ✓ str1 == str2 (deterministic)

  PASS: String Serialization Determinism

[TEST 2] String Uniqueness (different fields)

    ✓ key1 (stone): stone|marble_base|2|0|8|0
    ✓ key3 (wood):  wood|marble_base|2|0|8|0
    ✓ str1 != str3 (unique)

  PASS: String Uniqueness

[TEST 3] Dictionary Deduplication

    ✓ Added str1, str2 (same), str3 (diff)
    ✓ Set size: 2 (expected 2)
    ✓ Deduplication working

  PASS: Dictionary Deduplication

[TEST 4] Lookup Hit

    ✓ lookup.has(str1) = true
    ✓ lookup.has('nonexistent') = false
    ✓ Lookup working

  PASS: Lookup Hit

============================================================
✓ FIX-BAKE-01 ALL TESTS PASS
============================================================
```

### Test 2: Compositor dedup actually reduces count

**Test file:** Integrate into `bake_compositor_test.gd` or new `fix_bake_01_compositor_test.gd`

Create a mock scenario where 3 walls share the same (material, facade, variant, face, window):
```gdscript
var walls = [
    {"material_id": "stone", "facade_id": "base", "edge": mock_edge_1},
    {"material_id": "stone", "facade_id": "base", "edge": mock_edge_1},  # Duplicate key
    {"material_id": "stone", "facade_id": "base", "edge": mock_edge_1},  # Duplicate key
    {"material_id": "wood", "facade_id": "base", "edge": mock_edge_2},
]

var bake_set = compositor._populate_bake_set(walls, resolver)
var post_dedup = bake_set.size()

assert(post_dedup == 2, "3 walls with duplicates + 1 unique = 2 keys (got %d)" % post_dedup)
print("PASS: compositor dedup reduces 4 walls to 2 keys")
```

**Expected:** post_dedup **strictly less than** pre_dedup × 4 (currently always equals it).

### Test 3: Lookup hits on a baked key

**Test file:** `baked_tile_lookup_test.gd` (update existing)

```gdscript
# Setup: populate GLOBAL_BAKED_ATLAS with a string-keyed lookup
var baked_atlas = BakeCompositor.BakedAtlas.new()
var test_key = "stone|marble|2|0|8|0"  # String key
baked_atlas.lookup[test_key] = { "page": 0, "atlas_coords": Vector2i(2, 3) }
Engine.set_meta("GLOBAL_BAKED_ATLAS", baked_atlas)

# Now resolve a voxel whose BakeKey serializes to test_key
var lookup = BakedTileLookup.new()
var edge = MockEdge.new()  # With material_id, facade_id, etc. that produce test_key
var result = lookup.resolve(edge, 0, Vector2i(5, 5))

# The NEW behavior: should hit!
assert(result.source_id == "BAKED_ATLAS_0", "Lookup should hit baked atlas (got %s)" % result.source_id)
print("PASS: Lookup hits on baked key")
```

**Expected:** `result.source_id == "BAKED_ATLAS_0"` (not fallback).

---

## Implementation Checklist

- [ ] Add `_bake_key_to_string()` to BakeCompositor (lines ~230–240, before `_populate_bake_set()`)
- [ ] Update `_populate_bake_set()` to use string keys (line ~92 and line ~137)
- [ ] Update `_render_batch()` lookup assignment to string keys (line ~173)
- [ ] Add `_bake_key_to_string()` to BakedTileLookup (shared or imported)
- [ ] Update `BakedTileLookup.resolve()` lookup query to string keys (line ~90)
- [ ] Create `fix_bake_01_test.gd` and run headless: `godot --headless --script fix_bake_01_test.gd`
- [ ] Update `bake_compositor_test.gd` dedup assertion (expect post < pre × 4, not ==)
- [ ] Update `baked_tile_lookup_test.gd` with a hitting-case test
- [ ] Run both test files and capture output

---

## Deletions

- [ ] Remove BakeKey's `_hash()` and `_is_equal()` methods (dead code, confusing)
- [ ] Optionally: keep BakeKey class definition (for clarity) or retire it entirely once all code uses strings

---

## Downstream Impact

- **BAKE-02, BAKE-03:** No changes needed; they produce data consumed by BAKE-04, which now uses strings.
- **BAKE-04 (next fix):** Already receives string-keyed lookup from compositor.
- **BAKE-05:** BakedTileLookup.resolve() now returns hits; seam is ready for live wiring.
- **BAKE-07:** The dedup test will now legitimately validate that N identical walls → 1 key.

---

## Notes on Evidence Rule (process improvement)

This fix introduces a **new evidence standard:** tests must demonstrate both **red and green** — i.e., a failing assertion with a bad input, then passing with correct input. The old "unconditional PASS lines" are now known as an evasion pattern. Example:

```gdscript
# BAD (unconditional):
func test() -> void:
    print("  PASS: dedup")  # Always prints, test is lie

# GOOD (assertion-based):
func test() -> void:
    var bake_set = ...
    assert(bake_set.size() == 2, "Expected 2 keys, got %d" % bake_set.size())
    print("  PASS: dedup")  # Only prints if assertion passes
```

---

*End FIX-BAKE-01.*
