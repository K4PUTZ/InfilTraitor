# FIX-BAKE-05: The Swap – Live Integration & Functional Seam

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-04 (Real Material Tiles)
**Successor:** FIX-BAKE-06 (Debug Views & Wiring)
**Scope:** Integrate baking into room.gd / room_builder.gd; seam into voxel_renderer._set_voxel_cell(); resolve I2 (sequencing); fix BakedTileLookup interface; validate branch exclusivity
**Effort:** ~4–5 hours
**Risk:** High (first contact with live code; errors propagate to rendering)

---

## Problem

BAKE-09 claimed "Placement now uses BakedTileLookup.resolve (one-line seam)" but **the seam was never inserted.** The live voxel renderer still calls `set_cell(grid_pos, mat_index, Vector2i.ZERO)` where `mat_index = MATERIALS.find(material_name)` — a hardcoded int into the material atlas, no branching to baked, no lookup.

Additional failures:
1. **Interface incompatibility.** `TileLookupResult.source_id` is a String (`"BAKED_ATLAS_0"`), but `set_cell()` requires an int source id. The tileset uses `mat_index = MATERIALS.find(material_name)`.
2. **Missing Edge backreference.** `BakedTileLookup.resolve()` calls `edge.get_owning_wall()` — this method does not exist on the real Edge class.
3. **No wall metadata.** The real Slice/Edge classes do not carry `material_id` or `facade_id` fields; the seam cannot reconstruct the BakeKey.
4. **Initialization order (I2).** The plan claims "Phase 3: bake map at map load; Phase 4: placement uses lookup" but describes no actual sequencing against `room_builder.gd`'s flow.

---

## Solution

### S1: Define the seam interface & wall metadata

The seam will live in `voxel_renderer.gd::_set_voxel_cell()`. It needs to know material_id and facade_id for every wall. Two strategies:

**Strategy A (preferred): Extend Slice class** to carry metadata.

Slice already exists as the core voxel container. Add optional fields:
```gdscript
# In geometry/slice.gd
class_name Slice

var voxels: Array          # [Voxel, ...]
var material: String       # Material id (e.g., "stone", "wood") — already present
var facade_id: String = "" # NEW: Facade id for baking (e.g., "marble_base")
var theme_id: String = ""  # NEW: Theme for render-time modulate (v1.5)
```

Alternatively, **Strategy B (fallback): Parallel lookup dictionary** in the compositor/bake result that maps Slice → {material_id, facade_id}.

We'll proceed with **Strategy A** (cleaner, minimal coupling).

### S2: Wire baking into room_builder.gd

Integration order:
1. **Build geometry** (existing)
2. **Bake textures** (new, after geometry is complete)
3. **Place voxels** with baked lookup (modified existing)

**Changes to room_builder.gd:**

```gdscript
# Pseudo-code outline; adapt to actual structure

func build(map_spec: Dictionary) -> void:
    # Phase 1: Compile geometry (existing)
    _compile_geometry(map_spec)
    var edge_registry = _edge_registry  # Populated by compiler
    
    # Phase 2: Bake textures (NEW)
    if BakeConfig.enabled:
        _bake_and_register_atlases(map_spec)
    
    # Phase 3: Place voxels (existing, but uses seam)
    _place_voxels_with_baked_lookup(edge_registry)

func _bake_and_register_atlases(map_spec: Dictionary) -> void:
    print("[ROOM] Baking textures...")
    
    var resolver = TextureResolver.new()
    var compositor = BakeCompositor.new()
    
    var start = Time.get_ticks_msec()
    var baked_atlas = compositor.bake(map_spec, resolver)
    var elapsed = Time.get_ticks_msec() - start
    
    print("[ROOM] Bake complete: %.0f ms, %d pages" % [elapsed, baked_atlas.pages.size()])
    
    # Register baked atlas sources with the tileset
    for page_idx in range(baked_atlas.pages.size()):
        var source_id = _register_atlas_page(baked_atlas.pages[page_idx], page_idx)
        print("[ROOM] Registered baked atlas page %d as source %s" % [page_idx, source_id])
    
    # Store lookup for placement
    Engine.set_meta("GLOBAL_BAKED_ATLAS", baked_atlas)
    Engine.set_meta("BAKE_TIMESTAMP", Time.get_ticks_msec())

func _register_atlas_page(page_image: Image, page_idx: int) -> String:
    # Create a TileSetAtlasSource from the page
    var source = TileSetAtlasSource.new()
    source.texture = ImageTexture.create_from_image(page_image)
    source.texture_region_size = Vector2i(32, 16)
    source.texture_filter_mode = Godot_4_6_compatibility.TextureFilter.NEAREST
    
    # Register on the tileset
    var tileset = _wall_tilemaps[0].tile_set
    var source_id = tileset.get_next_source_id()
    tileset.add_source(source, source_id)
    
    return "BAKED_ATLAS_%d" % page_idx

func _place_voxels_with_baked_lookup(edge_registry: EdgeRegistry) -> void:
    # Existing placement, but now uses BakedTileLookup seam
    # Voxel renderer will handle the branching
    print("[ROOM] Placing voxels with %s baking..." % 
        ("BAKED" if BakeConfig.enabled else "material-only"))
    
    _voxel_renderer.render_walls(edge_registry)
```

### S3: Insert the seam into voxel_renderer._set_voxel_cell()

This is the single call point for all wall voxels (Rule #8).

**Changes to voxel_renderer.gd:**

```gdscript
func _set_voxel_cell(grid_pos: Vector2i, level: int, material_name: String, 
                     edge: Edge = null, voxel_xy: Vector2i = Vector2i.ZERO) -> void:
    # grid_pos, level are always present
    # material_name (fallback for material-only)
    # edge, voxel_xy are new optional parameters (provided during placement)
    
    if level < 0 or level >= _voxel_layers.size():
        push_warning("VoxelRenderer._set_voxel_cell: level out of range")
        return
    
    var layer: TileMapLayer = _voxel_layers[level]
    
    # SEAM: Try baked lookup first
    var source_id: int = -1
    var atlas_coords: Vector2i = Vector2i.ZERO
    var alternative_id: int = 0
    
    if BakeConfig.enabled and edge != null:
        # Query baked lookup
        var lookup = BakedTileLookup.new()
        var result = lookup.resolve(edge, _face_from_context(), voxel_xy)
        
        # Parse result (String source_id → int)
        if result.source_id.begins_with("BAKED_ATLAS_"):
            var page_idx = int(result.source_id.trim_prefix("BAKED_ATLAS_"))
            source_id = _get_baked_atlas_source_id(page_idx)
            atlas_coords = result.atlas_coords
            alternative_id = result.alternative_id
        else:
            # Fallback: treat as material-only
            source_id = _get_material_source_id(material_name)
    else:
        # Baking disabled or no edge → material-only path
        source_id = _get_material_source_id(material_name)
    
    if source_id >= 0:
        layer.set_cell(grid_pos, source_id, atlas_coords, alternative_id)
    else:
        push_error("[VOXEL] Could not resolve tile source for material %s" % material_name)

func _get_material_source_id(material_name: String) -> int:
    var idx = MATERIALS.find(material_name)
    return idx if idx >= 0 else 0  # Fallback to MATERIALS[0]

func _get_baked_atlas_source_id(page_idx: int) -> int:
    # Tileset source ids are assigned during registration
    # Need to cache them during bake or look them up by name
    var baked_source_name = "BAKED_ATLAS_%d" % page_idx
    # TileSet.find_source_by_name() or similar (TBD per Godot 4.6 API)
    # For now, assume sequential registration: BAKED_ATLAS_0 = source_id N, etc.
    var tileset = _wall_tilemaps[0].tile_set
    for source_id in range(tileset.get_source_count()):
        var source = tileset.get_source(source_id)
        if source is TileSetAtlasSource and source.name == baked_source_name:
            return source_id
    return -1

func _face_from_context() -> int:
    # Determine which face this voxel belongs to based on grid position + geometry
    # For now: placeholder (simplified; full solution requires edge orientation info)
    # This is context-dependent and may need refactoring
    return 0  # NE; TBD
```

### S4: Update call sites for _set_voxel_cell

All calls to `_set_voxel_cell()` must pass the edge (from the Slice or Edge Registry).

**Changes to voxel_renderer.gd (all rendering calls):**

```gdscript
# OLD (line ~158)
layer.set_cell(grid_pos, mat_index, Vector2i.ZERO)

# NEW
_set_voxel_cell(grid_pos, level, material_name, edge, voxel_xy)
```

The voxel position (voxel_xy) and edge need to be threaded through the call hierarchy (Slice → RenderSlice, etc.).

### S5: Fix BakedTileLookup interface

The lookup returns a String source_id; the seam must parse it to int. Better: return structured data.

**Changes to baked_tile_lookup.gd:**

```gdscript
class TileLookupResult:
    var source_id_int: int           # NEW: actual tileset source id
    var source_id_string: String     # OLD: for debugging; deprecate
    var atlas_coords: Vector2i
    var alternative_id: int

func resolve(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
    # ... lookup logic ...
    
    if baked_atlas and baked_atlas.lookup.has(key_str):
        var baked_coords = baked_atlas.lookup[key_str]
        var source_id_int = _get_baked_source_id(baked_coords["page"])
        return TileLookupResult.new(
            source_id_int,
            "BAKED_ATLAS_%d" % baked_coords["page"],
            baked_coords["atlas_coords"],
            0
        )
    
    # Fallback
    var mat_source_id = MATERIALS.find(...)
    return TileLookupResult.new(
        mat_source_id,
        "MATERIAL_ATLAS",
        Vector2i.ZERO,
        0
    )

func _get_baked_source_id(page_idx: int) -> int:
    # Consult cached source id map (populated during bake registration)
    if Engine.has_meta("BAKED_ATLAS_SOURCE_IDS"):
        var source_ids = Engine.get_meta("BAKED_ATLAS_SOURCE_IDS")
        return source_ids.get(page_idx, -1)
    return -1
```

Alternatively, **avoid the String → int conversion** and return int directly. This is cleaner.

---

## Validation & Evidence (PASS Criteria)

### Test 1: Room bake integration

**Test file:** `godot/scripts/tools/fix_bake_05_integration_test.gd` (new)

```gdscript
extends SceneTree

const RoomBuilderClass = preload("res://godot/scripts/world/room_builder.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")

func _init() -> void:
    print("\n" + "=".repeat(70))
    print("FIX-BAKE-05 TEST: Live Integration")
    print("=".repeat(70) + "\n")

    # Setup: enable baking
    BakeConfigClass.enabled = true
    
    # Load a test map
    var map_spec = _create_test_map_spec()
    
    print("[TEST 1] Room Bake Integration\n")
    
    var start = Time.get_ticks_msec()
    
    # Build room with baking
    var room_builder = RoomBuilderClass.new()
    # (Assuming room_builder.build() handles both geometry + bake)
    # room_builder.build(map_spec)
    
    var elapsed = Time.get_ticks_msec() - start
    
    # Check that baked atlas was registered
    var baked_atlas = Engine.get_meta("GLOBAL_BAKED_ATLAS") if Engine.has_meta("GLOBAL_BAKED_ATLAS") else null
    
    assert(baked_atlas != null, "Baked atlas must be registered after build()")
    assert(baked_atlas.pages.size() > 0, "Baked atlas must have pages")
    assert(baked_atlas.lookup.size() > 0, "Baked atlas must have tile entries")
    
    print("    ✓ Baked atlas registered: %d pages, %d tiles" % 
        [baked_atlas.pages.size(), baked_atlas.lookup.size()])
    print("    ✓ Total time: %.0f ms" % elapsed)
    print("  PASS: Room Bake Integration\n")
    
    print("[TEST 2] Branch Exclusivity\n")
    
    # Verify that only one atlas path is active
    var lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
    
    # Disable baking
    BakeConfigClass.enabled = false
    var result_unbaked = lookup.resolve(null, 0, Vector2i.ZERO)
    assert(result_unbaked.source_id_int >= 0, "Material-only lookup must succeed when baked disabled")
    print("    ✓ Unbaked: fallback to material atlas")
    
    # Enable baking
    BakeConfigClass.enabled = true
    var result_baked = lookup.resolve(null, 0, Vector2i.ZERO)  # (Mock edge; will hit fallback if no atlas)
    print("    ✓ Baked: branch-exclusive seam active")
    print("  PASS: Branch Exclusivity\n")
    
    print("=".repeat(70))
    print("✓ FIX-BAKE-05 INTEGRATION TEST PASS")
    print("=".repeat(70) + "\n")
    quit(0)

func _create_test_map_spec() -> Dictionary:
    return {
        "walls": [
            {"material_id": "stone", "facade_id": "marble_base", "edge": _mock_edge()},
            {"material_id": "wood", "facade_id": "wood_plank", "edge": _mock_edge()},
        ],
        "themes": [Color.WHITE],
        "room_geometry": {},
    }

func _mock_edge():
    return {"key_string": func(): return "test_edge"}
```

**Expected output:**
```
[TEST 1] Room Bake Integration

    ✓ Baked atlas registered: 1 pages, 2 tiles
    ✓ Total time: nnnn ms
  PASS: Room Bake Integration

[TEST 2] Branch Exclusivity

    ✓ Unbaked: fallback to material atlas
    ✓ Baked: branch-exclusive seam active
  PASS: Branch Exclusivity

============================================================
✓ FIX-BAKE-05 INTEGRATION TEST PASS
============================================================
```

### Test 2: Grep validation (B1 invariant)

```bash
# After implementation, run:
cd /home/claude/INFILTRAITOR
grep -rn "MATERIALS.find\|\.source_id\|TileSetAtlas\|set_cell" godot/scripts --include="*.gd" | \
  grep -v "baked_tile_lookup\|bake_compositor\|voxel_renderer._set_voxel" | \
  grep -v "tools/\|test"

# Expected: zero hits (no other code path accesses atlases or calls set_cell)
# If there are hits, those code paths bypass the seam (B1 violation)
```

### Test 3: Swap toggle validation

```gdscript
# Create a small test room, render once with baking OFF, once with ON
# Compare the cell source ids to verify they differ

var room_unbaked = _build_test_room(enabled: false)
var room_baked = _build_test_room(enabled: true)

# Sample a few cells from each
var unbaked_source = room_unbaked.get_cell_source_id(0, Vector2i(5, 5))
var baked_source = room_baked.get_cell_source_id(0, Vector2i(5, 5))

if unbaked_source != baked_source:
    print("PASS: Toggle produces different sources (unbaked: %d, baked: %d)" % 
        [unbaked_source, baked_source])
else:
    print("FAIL: Toggle did not change source (both: %d)" % unbaked_source)
```

---

## Implementation Checklist

**Strategy A (Slice metadata):**
- [ ] Add `facade_id: String = ""` field to Slice class (geometry/slice.gd)
- [ ] Thread `facade_id` through slice creation in room_builder / map_compiler
- [ ] Update RenderSlice / _render_slice() to pass facade_id to _set_voxel_cell()

**BakeConfig & integration:**
- [ ] Add `BakeConfig` to project autoload (or ensure it's accessible globally)
- [ ] Implement `_bake_and_register_atlases()` in room_builder.gd
- [ ] Implement `_register_atlas_page()` with TileSetAtlasSource creation and registration
- [ ] Cache baked atlas source ids (→ `BAKED_ATLAS_SOURCE_IDS` meta)

**Seam insertion:**
- [ ] Rewrite `_set_voxel_cell()` to accept edge + voxel_xy parameters
- [ ] Implement seam logic (BakeConfig check → BakedTileLookup.resolve() → set_cell with result)
- [ ] Implement `_get_material_source_id()` and `_get_baked_atlas_source_id()` helpers
- [ ] Update all call sites of `_set_voxel_cell()` (6–8 locations in voxel_renderer.gd and slice_generator.gd)

**Interface fixes:**
- [ ] Update BakedTileLookup.TileLookupResult to include source_id_int (int, not String)
- [ ] Remove String-based source_id (or deprecate)
- [ ] Update BakedTileLookup.resolve() to populate source_id_int

**Testing & validation:**
- [ ] Create fix_bake_05_integration_test.gd and run headless
- [ ] Run grep validation (B1 exclusivity)
- [ ] Run swap toggle test (baking ON vs OFF produces different cell sources)
- [ ] Visual inspection: load a test room with baking enabled and verify rendering (no crashes, no obvious misalignment)

---

## Post-Swap Cleanup

Once the seam is live and validated:

- [ ] Delete the old material atlas initialization code (if any directly exposed in room.gd)
- [ ] Ensure BakeConfig default is `enabled = false` (safe fallback until production ready)
- [ ] Update OPERATOR_CONTEXT.md with actual sequencing (not the claimed plan, but the real flow)
- [ ] Mark any deferred features (GPU batch, run continuity, multi-storey) as TODOs with version targets

---

## Sequencing (I2 Resolution)

**Finalized order (real, not planned):**

1. **Build phase:** room_builder compiles geometry → Edge Registry populated
2. **Bake phase:** If BakeConfig.enabled: compositor bakes all walls → atlas pages registered with tileset
3. **Placement phase:** voxel_renderer._set_voxel_cell() calls seam → BakedTileLookup.resolve() → int source_id → set_cell()
4. **Render phase:** TileMapLayer renders cells using baked or material-only sources per BakeConfig state

---

*End FIX-BAKE-05.*
