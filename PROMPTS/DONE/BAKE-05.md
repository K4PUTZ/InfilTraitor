# BAKE-05: Drop-in Swap — BakedTileLookup & Branch-Exclusive Integration

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `baked_tile_lookup.gd` module, `bake_config.gd` unified config, integration diff into placement path (no rewrites), grep validation
**Predecessor:** `BAKE-04` (BakeCompositor produces atlas)
**Successor:** `BAKE-06` (ThemeApplier + Theme Matrix debug view)
**Status:** Ready for implementation
**PASS criteria:** Toggle test: identical cell coordinate sets, differing source IDs, both directions; grep audit proves no residual direct atlas-source references in placement; PASS evidence includes toggle-on/toggle-off cell comparisons

---

## Context

This is the **only prompt that touches live code**. Everything before (BAKE-01 to BAKE-04) is upstream preparation; everything after is polish. The swap is an **insertion of a seam**, not an extraction. The placement code keeps its structure; it gains one lookup call. Old direct source references are **deleted** in the same prompt, verified by grep.

ENHANCE-04b scar: the rotation bug happened because method extraction left dead correct code in the old module and a broken copy in the new module. Here, we avoid that by **not extracting**. The old code is deleted, the new code is a thin lookup layer.

---

## Part A: BakedTileLookup Module

### A.1 Interface

```gdscript
class_name BakedTileLookup

# Single lookup seam: placement code calls this once per set_cell()
func resolve(edge: WallEdgeData, face: Face, voxel_xy: Vector2i) -> TileLookupResult:
    # Returns { source_id, atlas_coords, alternative_id }
    # source_id ∈ { GENERIC_MATERIAL_SOURCE, BAKED_ATLAS_SOURCE_0, BAKED_ATLAS_SOURCE_1, ... }
    
    if not BakeConfig.enabled:
        # Feature off: always use generic material atlas
        return _resolve_generic(edge, face, voxel_xy)
    
    # Build bake key for this voxel face
    var bake_key = _make_bake_key(edge, face, voxel_xy)
    
    # Lookup in baked atlas
    if GLOBAL_BAKED_ATLAS.lookup.has(bake_key):
        var baked_coords = GLOBAL_BAKED_ATLAS.lookup[bake_key]
        return TileLookupResult.new(
            "BAKED_ATLAS_%d" % baked_coords["page"],
            baked_coords["atlas_coords"],
            0  # alternative_id unused
        )
    
    # Key not in baked set; fall back to generic material atlas
    return _resolve_generic(edge, face, voxel_xy)

func _make_bake_key(edge: WallEdgeData, face: Face, voxel_xy: Vector2i) -> BakeKey:
    # Reconstruct the BakeKey from placement arguments
    # This must match BakeCompositor's key construction exactly
    
    var wall = edge.get_owning_wall()  # Backreference to the wall object
    
    var material_id = wall.material_id
    var facade_id = wall.facade_id
    
    var sampler = FacadeSampler.new()
    var origin = sampler.get_window_origin_isolated(edge, facade_id)
    
    var seed = hash_u32("%s_%s" % [edge.key_string(), material_id])
    var variant_k = seed % 4
    
    var N = TEX_AUTHORING_N
    
    var key = BakeKey.new()
    key.material_id = material_id
    key.facade_id = facade_id
    key.variant_k = variant_k
    key.face = face
    key.plane_col = origin.x / N
    key.plane_row = origin.y / N
    
    return key

func _resolve_generic(edge: WallEdgeData, face: Face, voxel_xy: Vector2i) -> TileLookupResult:
    # Fallback: choose material variant based on voxel position
    var wall = edge.get_owning_wall()
    var material_id = wall.material_id
    
    var seed = hash_u32("%s_%s_%d_%d" % [edge.key_string(), material_id, voxel_xy.x, voxel_xy.y])
    var variant_k = seed % 4
    
    # Lookup in GLOBAL_MATERIAL_ATLAS (from BAKE-02)
    var atlas_coords = GLOBAL_MATERIAL_ATLAS.get_coords(material_id, face, variant_k)
    
    return TileLookupResult.new(
        GLOBAL_MATERIAL_ATLAS.source_id,
        atlas_coords,
        0
    )

class TileLookupResult:
    var source_id: String        # Identifier for the TileSetAtlasSource
    var atlas_coords: Vector2i   # (col, row) within that source
    var alternative_id: int      # For future use
```

### A.2 BakeConfig: Unified Configuration

```gdscript
class_name BakeConfig

# Master kill-switch: branch-exclusive (structural, not tested)
static var enabled: bool = false

# Blend mode: MULTIPLY | TEXTURE_ONLY | MATERIAL_ONLY | OVERLAY_EXPERIMENTAL
enum BlendMode { MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY_EXPERIMENTAL }
static var blend_mode: BlendMode = BlendMode.MULTIPLY

# Feature toggles
static var theme_enabled: bool = true
static var variants_enabled: bool = true
static var facade_enabled: bool = true
static var material_pattern_enabled: bool = true

# Debug
static var debug_bake_set_dump: bool = false  # Log every key in bake_set

func _static_init() -> void:
    # Load from config file if it exists
    var config = ConfigFile.new()
    var err = config.load("user://bake_config.cfg")
    if err == OK:
        enabled = config.get_value("bake", "enabled", false)
        blend_mode = config.get_value("bake", "blend_mode", BlendMode.MULTIPLY)
    
    print("[CONFIG] Bake enabled: %s" % enabled)
```

---

## Part B: Placement Integration

### B.1 The Single Lookup Seam

Current placement code (existing, from placement modules):

```gdscript
# Somewhere in placement_controller.gd or similar:

func _place_wall_voxel(edge: WallEdgeData, face: Face, voxel_xy: Vector2i) -> void:
    var source_id = GENERIC_MATERIAL_TILESET_SOURCE  # Hardcoded
    var atlas_coords = _get_material_atlas_coords(edge.get_owning_wall().material_id, face, voxel_xy)
    
    WALL_TILEMAP.set_cell(cell_coords, source_id, atlas_coords)
```

Modified placement code (after BAKE-05):

```gdscript
# After BAKE-05:

func _place_wall_voxel(edge: WallEdgeData, face: Face, voxel_xy: Vector2i) -> void:
    var lookup_result = BakedTileLookup.resolve(edge, face, voxel_xy)  # <-- THE SEAM
    
    WALL_TILEMAP.set_cell(cell_coords, lookup_result.source_id, lookup_result.atlas_coords)
```

**That's it.** One line. The placement code's logic and control flow are unchanged. The only modification is swapping the source of `source_id` and `atlas_coords` from a direct material atlas query to a lookup call.

### B.2 Deletion of Old Code

Immediately after wiring in the new lookup, **delete all direct references to the generic material atlas in placement code**:

```gdscript
# DELETE THIS ENTIRE FUNCTION:
func _get_material_atlas_coords(material_id: String, face: Face, voxel_xy: Vector2i) -> Vector2i:
    # OLD: direct material atlas lookup
    # This is now handled by BakedTileLookup (or its _resolve_generic fallback)
    pass  # <- DELETE

# DELETE THESE CONSTANTS IF ONLY USED HERE:
const GENERIC_MATERIAL_TILESET_SOURCE = "..."
const MATERIAL_ATLAS_VARIANT_COUNT = 4
```

The old code is **dead** after the seam is inserted. Deleting it ensures there's no branch where both old and new run simultaneously.

### B.3 Grep Validation

After the swap, verify no residual references:

```bash
# Should return ZERO matches (unless in comments or BAKE-05 documentation):
grep -r "GENERIC_MATERIAL_TILESET_SOURCE" res://
grep -r "_get_material_atlas_coords" res://
grep -r "direct.*material.*source" res://  # (loose pattern, inspect)
```

Run this as part of PASS criteria. Any matches are refactoring debt.

---

## Part C: Atlas Registration (Boot Sequence)

At game boot, after BAKE-02 (material atlas) and map load (BAKE-04 baked atlas), register both with the TileSet:

```gdscript
# In room_builder.gd (pseudocode, sequencing details in §D.2):

func _build_room() -> void:
    # Phase 1: Build geometry (existing)
    _build_geometry()
    
    # Phase 2: Generate material atlas (BAKE-02, once at boot)
    if GLOBAL_MATERIAL_ATLAS == null:
        var generator = MaterialAtlasGenerator.new()
        GLOBAL_MATERIAL_ATLAS = generator.generate_atlas(...)
        TILESET.add_source(GLOBAL_MATERIAL_ATLAS)
    
    # Phase 3: Bake map (BAKE-04, at map load)
    if BakeConfig.enabled:
        var compositor = BakeCompositor.new()
        var resolver = TextureResolver.new()
        GLOBAL_BAKED_ATLAS = compositor.bake(map_spec, resolver)
        
        # Register baked atlas sources with the TileSet
        for i in range(GLOBAL_BAKED_ATLAS.pages.size()):
            var source = TileSetAtlasSource.new()
            source.texture = ImageTexture.create_from_image(GLOBAL_BAKED_ATLAS.pages[i])
            source.texture_filter_mode = TextureFilter.FILTER_NEAREST
            source.texture_region_size = VOXEL_TILE_SIZE
            source.texture_origin = VOXEL_TILE_ORIGIN  # From canon
            
            # Create tiles (per entry in baked_atlas.lookup)
            for bake_key in GLOBAL_BAKED_ATLAS.lookup.keys():
                var coords = GLOBAL_BAKED_ATLAS.lookup[bake_key]
                if coords["page"] == i:
                    source.create_tile(coords["atlas_coords"])
            
            TILESET.add_source(source)
    
    # Phase 4: Place walls (existing, now using BakedTileLookup)
    _place_walls()
```

---

## Part D: Selftest (T2, Render)

In `baked_tile_lookup_test.gd`:

### D.1 Toggle Test

```gdscript
func test_toggle_identical_cells() -> void:
    # Place walls with baking OFF, then ON; verify same cell coords, different sources
    
    var map_spec = _create_test_map()
    var resolver = TextureResolver.new()
    
    # Place with baking OFF
    BakeConfig.enabled = false
    var room_off = _build_and_place_walls(map_spec, resolver)
    var cells_off = room_off.get_all_cell_coords()  # Set of (coords) placed
    var sources_off = {}
    for coords in cells_off:
        sources_off[coords] = room_off.get_cell_source_id(coords)
    
    # Place with baking ON
    BakeConfig.enabled = true
    var room_on = _build_and_place_walls(map_spec, resolver)
    var cells_on = room_on.get_all_cell_coords()
    var sources_on = {}
    for coords in cells_on:
        sources_on[coords] = room_on.get_cell_source_id(coords)
    
    # Assertions
    assert(cells_off == cells_on, "Cell coordinates differ between baking ON/OFF")
    
    # Sources may differ (baked vs. material), but all cells should resolve
    assert(sources_off.size() == sources_on.size(), "Cell count mismatch")
    
    # Log comparison
    var diff_count = 0
    for coords in cells_off:
        if sources_off[coords] != sources_on[coords]:
            diff_count += 1
    
    print("PASS: toggle_identical_cells (diff sources in %d cells)" % diff_count)

func test_baking_off_fallback() -> void:
    # With baking disabled, BakedTileLookup should fallback to generic material atlas
    
    BakeConfig.enabled = false
    
    var edge = _create_test_edge()
    var face = Face.NE
    var voxel = Vector2i(5, 3)
    
    var lookup = BakedTileLookup.new()
    var result = lookup.resolve(edge, face, voxel)
    
    # Should resolve to generic material source
    assert(result.source_id == GLOBAL_MATERIAL_ATLAS.source_id, "Wrong source when baking off")
    
    print("PASS: baking_off_fallback")

func test_baking_on_lookup() -> void:
    # With baking enabled and baked atlas populated, lookup should find baked tiles
    
    BakeConfig.enabled = true
    
    # (Assumes GLOBAL_BAKED_ATLAS is already populated from a prior bake)
    
    var edge = _create_test_edge()
    var face = Face.NE
    var voxel = Vector2i(0, 0)
    
    var lookup = BakedTileLookup.new()
    var result = lookup.resolve(edge, face, voxel)
    
    # Result should be valid (either baked or fallback)
    assert(result.source_id != null and result.source_id != "", "Lookup returned null source")
    assert(result.atlas_coords != Vector2i(-1, -1), "Lookup returned invalid coords")
    
    print("PASS: baking_on_lookup")

func test_grep_no_residual_references() -> void:
    # Verify no dead code remains in placement path
    
    var grep_patterns = [
        "GENERIC_MATERIAL_TILESET_SOURCE",
        "_get_material_atlas_coords",
        "direct.*material.*tileset"  # Loose pattern; inspect manually
    ]
    
    for pattern in grep_patterns:
        var cmd = "grep -r '%s' res://game/placement/ || echo 'OK'" % pattern
        var output = OS.execute("bash", ["-c", cmd])
        
        if output.contains("GENERIC_MATERIAL") or output.contains("_get_material"):
            push_error("Residual reference found: %s" % output)
        else:
            print("PASS: grep %s (no residual)" % pattern)
```

### D.2 PASS Criteria

- `test_toggle_identical_cells`: Cell coordinates identical ON/OFF; sources may differ.
- `test_baking_off_fallback`: Disabled baking routes to generic material atlas.
- `test_baking_on_lookup`: Enabled baking performs lookup successfully.
- `test_grep_no_residual_references`: Grep audit passes (no dead code).
- Console evidence: Toggle comparison dump (cell counts, source diffs).

---

## Part E: Integration Checklist

Sequencing is critical:

1. **BAKE-02 at boot:** material atlas generated (persistent, reused by all maps).
2. **Map load:** geometry built.
3. **BAKE-04 at map load:** baked atlas generated (map-specific).
4. **Atlas registration:** both material and baked sources added to TileSet.
5. **Placement:** uses BakedTileLookup to query (baked → fallback → generic).

If step 3 is skipped (baking disabled), step 4 is skipped, and step 5 fallbacks to material atlas (safe).

---

## Part F: Rollout Checklist

Before BAKE-06 can start:

- [ ] `baked_tile_lookup.gd` written with resolve logic, fallback chain, BakeKey reconstruction.
- [ ] `bake_config.gd` written with unified config (enabled, blend_mode, feature toggles, debug flags).
- [ ] Placement code modified: one-line seam insertion (BakedTileLookup.resolve call).
- [ ] Old material atlas lookup code deleted entirely from placement modules.
- [ ] Grep audit: zero residual references to deleted functions/constants.
- [ ] Selftest `baked_tile_lookup_test.gd` PASS achieved (toggle, fallback, lookup, grep).
- [ ] Boot sequence diagram updated (BAKE-02 at boot, BAKE-04 at map load, registration, placement).
- [ ] Evidence transcript: toggle comparison dump, grep results, selftest output.

---

*End of BAKE-05.*
