# BAKE-04: BakeCompositor

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `bake_compositor.gd` module, compositor shader (glsl/gdshader), batch orchestration + T2 selftest
**Predecessor:** `BAKE-03` (FacadeSampler), `BAKE-02` (MaterialRegistry), `BAKE-01` (PerFaceProjector), `TEX-CATALOG-01` (TextureResolver)
**Successor:** `BAKE-05` (Drop-in swap, BakedTileLookup)
**Status:** Ready for implementation
**PASS criteria:** Bake set construction yields correct pre/post-dedup counts; SubViewport capture completes in < 100ms; atlas pages created with correct tile count; console logs timing and page counts; `user://debug/baked_atlas_page_*.png` produced and visually inspects

---

## Context

The BakeCompositor is where **pixels are rendered**. It orchestrates the GPU batch: for each deduplicated bake key (material, facade, variant, face, window position), it draws one tile — compositing the material voxel atlas with the facade luminance, multiplying them together via the NEAREST-sampled shear transform.

This is the heaviest computational work in the pipeline, but because it's **one batched GPU frame** (not N separate renders), it stays affordable. The entire bake at map load should complete in tens of milliseconds.

---

## Part A: Bake Set Construction (Deduplication)

### A.1 BakeKey

A bake key uniquely identifies a renderable tile:

```gdscript
class BakeKey:
    var material_id: String
    var facade_id: String
    var variant_k: int                # [0, 4)
    var face: Face                    # NE, SE, SW, NW
    var plane_col: int                # Column in the infinite facade plane (in voxels)
    var plane_row: int                # Row (v1: always 0; multi-storey uses 1+)
    
    func _hash() -> int:
        # Required for Dictionary use
        var h = 0
        h = hash(h ^ material_id.hash())
        h = hash(h ^ facade_id.hash())
        h = hash(h ^ variant_k)
        h = hash(h ^ int(face))
        h = hash(h ^ plane_col)
        h = hash(h ^ plane_row)
        return h
    
    func _is_equal(other: BakeKey) -> bool:
        return (material_id == other.material_id and
                facade_id == other.facade_id and
                variant_k == other.variant_k and
                face == other.face and
                plane_col == other.plane_col and
                plane_row == other.plane_row)
```

### A.2 Bake Set Population

Walk the Edge Registry and the map's wall set:

```gdscript
func _populate_bake_set(room_geometry: RoomGeometry, resolver: TextureResolver) -> Dictionary:
    # Returns: { BakeKey → null } (dict used as a set for dedup)
    # Later, the compositor will assign each key an atlas position
    
    var bake_set = {}
    var sampler = FacadeSampler.new()
    var registry = GLOBAL_MATERIAL_REGISTRY  # From BAKE-02
    
    for wall in room_geometry.walls:
        # Skip walls with no facade
        if wall.facade_id == null or wall.facade_id == "":
            continue
        
        # Resolve facade; skip if unresolved
        var resolved = resolver.resolve(wall.facade_id)
        if resolved.tier == TextureResolver.Tier.NONE:
            # No facade; wall renders material-only (no bake key)
            continue
        
        # Get material
        var material = registry.get_material(wall.material_id)
        if material == null:
            push_error("Unknown material: %s" % wall.material_id)
            continue
        
        # Iterate over faces of this wall
        for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
            # Check if this face is exposed (has an edge)
            var edge = wall.get_edge_for_face(face)
            if edge == null:
                continue
            
            # Determine window origin (run vs. isolated)
            var origin = _determine_window_origin(edge, wall.facade_id, sampler)
            
            # Determine variant (seeded by edge position)
            var seed = hash_u32("%s_%s" % [edge.key_string(), wall.material_id])
            var variant_k = seed % 4
            
            # Construct bake key
            var key = BakeKey.new()
            key.material_id = wall.material_id
            key.facade_id = wall.facade_id
            key.variant_k = variant_k
            key.face = face
            key.plane_col = origin.x / TEX_AUTHORING_N  # Convert to voxel coords
            key.plane_row = origin.y / TEX_AUTHORING_N
            
            # Add to set (dedup by key)
            bake_set[key] = null
    
    return bake_set

func _determine_window_origin(edge: WallEdgeData, facade_id: String, sampler: FacadeSampler) -> Vector2i:
    # TODO: Check if edge is part of a run; if so, use run origin; else use isolated origin
    # For v1, fallback to isolated (correct but not optimal for contiguous walls)
    return sampler.get_window_origin_isolated(edge, facade_id)
```

**Deduplication result:** If 100 walls reference the same material+facade+variant+face+window combo, the bake set has 1 key. The compositor generates 1 tile, and the lookup (BAKE-05) reuses it 100 times.

---

## Part B: BakeCompositor Module

### B.1 Interface

```gdscript
class_name BakeCompositor

func bake(map_spec: MapSpec, resolver: TextureResolver) -> BakedAtlas:
    # Main entry point: bake all walls in the map
    # Inputs: map spec (walls, themes, geometry), texture resolver
    # Output: BakedAtlas { pages: [Image], lookup: { BakeKey → (page_idx, atlas_coords) } }
    
    var atlas_result = BakedAtlas.new()
    
    # Step 1: Populate bake set (dedup)
    var bake_set = _populate_bake_set(map_spec.room_geometry, resolver)
    var pre_dedup_count = ... # (track this for logging)
    var post_dedup_count = bake_set.size()
    
    print("[BAKE] Bake set: %d unique tiles (pre-dedup: %d)" % [post_dedup_count, pre_dedup_count])
    
    # Step 2: Load resolved facades
    var facades_by_id = {}
    for wall in map_spec.room_geometry.walls:
        if wall.facade_id and not facades_by_id.has(wall.facade_id):
            var resolved = resolver.resolve(wall.facade_id)
            if resolved.tier != TextureResolver.Tier.NONE:
                facades_by_id[wall.facade_id] = resolved.image
    
    # Step 3: Render tiles into SubViewport (batched, one frame)
    var start_time = Time.get_ticks_msec()
    atlas_result = _render_batch(bake_set, facades_by_id)
    var elapsed_ms = Time.get_ticks_msec() - start_time
    
    print("[BAKE] Render complete: %d pages, %.1f ms" % [atlas_result.pages.size(), elapsed_ms])
    
    # Step 4: Save debug dumps
    for i in range(atlas_result.pages.size()):
        atlas_result.pages[i].save_png("user://debug/baked_atlas_page_%d.png" % i)
    
    return atlas_result

class BakedAtlas:
    var pages: Array[Image]  # One or more atlas pages
    var lookup: Dictionary   # BakeKey → { page_idx, atlas_coords }
```

### B.2 Batch Rendering via SubViewport

```gdscript
func _render_batch(bake_set: Dictionary, facades_by_id: Dictionary) -> BakedAtlas:
    # Create a SubViewport for rendering tiles
    var subvp = SubViewport.new()
    subvp.size = Vector2i(4096, 4096)  # One page; larger bakes spawn multiple
    subvp.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(subvp)
    
    # Create a Canvas (2D rendering surface)
    var canvas = CanvasLayer.new()
    subvp.add_child(canvas)
    
    # Material registry and sampler
    var registry = GLOBAL_MATERIAL_REGISTRY
    var sampler = FacadeSampler.new()
    var projector = GLOBAL_PER_FACE_PROJECTOR  # From BAKE-01
    
    # Compositor shader (see Part C)
    var compositor_shader = load("res://shaders/bake_compositor.gdshader")
    var compositor_mat = ShaderMaterial.new()
    compositor_mat.shader = compositor_shader
    
    # Pack tiles into pages
    var pages = []
    var lookup = {}
    var tile_index = 0
    var region_size = Vector2i(32, 16)
    var tiles_per_page_x = 4096 / 32  # 128
    var tiles_per_page_y = 4096 / 16  # 256
    var tiles_per_page = tiles_per_page_x * tiles_per_page_y
    
    for bake_key in bake_set.keys():
        var page_idx = tile_index / tiles_per_page
        var tile_in_page = tile_index % tiles_per_page
        var tile_x = (tile_in_page % tiles_per_page_x) * region_size.x
        var tile_y = (tile_in_page / tiles_per_page_x) * region_size.y
        
        # Ensure page exists
        while pages.size() <= page_idx:
            pages.append(Image.create(4096, 4096, false, Image.FORMAT_RGB8))
        
        # Get material variant tile
        var material = registry.get_material(bake_key.material_id)
        var material_tile = _get_material_tile(material, bake_key.face, bake_key.variant_k)
        
        # Get facade
        var facade = facades_by_id.get(bake_key.facade_id)
        if facade == null:
            # Shouldn't happen (filtered earlier), but guard
            tile_index += 1
            continue
        
        # Composite: material × facade (§B.3)
        var composite_tile = _composite_tile(
            material_tile, facade, bake_key, sampler, projector
        )
        
        # Place into page image
        for y in range(region_size.y):
            for x in range(region_size.x):
                pages[page_idx].set_pixel(tile_x + x, tile_y + y, composite_tile.get_pixel(x, y))
        
        # Record lookup
        lookup[bake_key] = {
            "page": page_idx,
            "atlas_coords": Vector2i(tile_x / region_size.x, tile_y / region_size.y)
        }
        
        tile_index += 1
    
    # Cleanup
    subvp.queue_free()
    
    var result = BakedAtlas.new()
    result.pages = pages
    result.lookup = lookup
    return result

func _get_material_tile(material: Material, face: Face, variant_k: int) -> Image:
    # Fetch from the material atlas (BAKE-02)
    # This is a lookup; the tile was pre-generated at boot
    var atlas = GLOBAL_MATERIAL_ATLAS
    return atlas.get_tile(material.id, face, variant_k)

func _composite_tile(
    material_tile: Image,
    facade: Image,
    bake_key: BakeKey,
    sampler: FacadeSampler,
    projector: PerFaceProjector
) -> Image:
    # Composite material × facade for this specific tile
    # Process: for each pixel in the tile:
    # 1. Map pixel → flat facade coordinate (inverse mapping via projector)
    # 2. Sample facade luminance at that coordinate
    # 3. Multiply material pixel by facade luminance
    
    var result = Image.create(32, 16, false, Image.FORMAT_RGB8)
    
    # Derive the crop window in the facade plane
    var window_origin = Vector2i(bake_key.plane_col * TEX_AUTHORING_N, bake_key.plane_row * TEX_AUTHORING_N)
    
    for screen_y in range(16):
        for screen_x in range(32):
            var screen_pos = Vector2(screen_x, screen_y)
            
            # Check silhouette (inside the voxel face?)
            if not projector.is_inside_voxel(bake_key.face, screen_pos):
                # Outside; use alpha from material (should be 0)
                result.set_pixel(screen_x, screen_y, material_tile.get_pixel(screen_x, screen_y))
                continue
            
            # Map screen → flat texture space
            var flat_pos = projector.screen_to_flat(bake_key.face, screen_pos)
            
            # Map flat → facade plane (add window origin)
            var plane_x = window_origin.x + flat_pos.x
            var plane_y = window_origin.y + flat_pos.y
            
            # Sample facade
            var facade_lum = sampler.sample(facade, plane_x, plane_y)
            
            # Get material pixel
            var mat_pixel = material_tile.get_pixel(screen_x, screen_y)
            
            # Multiply: RGB × facade_lum; keep alpha
            var result_pixel = Color(
                mat_pixel.r * facade_lum,
                mat_pixel.g * facade_lum,
                mat_pixel.b * facade_lum,
                mat_pixel.a
            )
            
            result.set_pixel(screen_x, screen_y, result_pixel)
    
    return result
```

### B.3 Compositor Shader (GPU Alternative, Optional)

For performance, the compositor can run on GPU instead of per-pixel loops. A GDShader variant (more efficient for large batches):

```glsl
// bake_compositor.gdshader

shader_type canvas_item;

// Uniforms passed per draw call
uniform sampler2D material_tile_sampler;
uniform sampler2D facade_sampler;
uniform vec2 facade_uv_origin;      // In facade plane coordinates (voxels)
uniform vec2 facade_plane_dims;     // (64, 32) in voxels
uniform int face_orientation;       // 0=NE, 1=SE, 2=SW, 3=NW
uniform int blend_mode = 0;         // 0=MULTIPLY, 1=TEXTURE_ONLY, etc.

void fragment() {
    // For each fragment (pixel):
    
    // 1. Silhouette check (is this pixel inside the voxel face?)
    // This requires the inverse of PerFaceProjector.is_inside_voxel()
    // Skipped in v1; assume all fragments are inside (tilemat handles alpha)
    
    // 2. Map fragment → flat texture space (via PerFaceProjector.screen_to_flat)
    vec2 flat_uv = screen_to_flat(UV, face_orientation);  // [0, 1] in tile space
    
    // 3. Map flat → facade plane
    vec2 facade_plane_uv = facade_uv_origin + flat_uv * facade_plane_dims;
    
    // 4. Mirrored-repeat addressing on facade
    vec2 facade_sampled_uv = mirror_repeat(facade_plane_uv, facade_plane_dims);
    
    // 5. Sample material and facade
    vec4 mat_color = texture(material_tile_sampler, UV);
    vec4 facade_color = texture(facade_sampler, facade_sampled_uv);
    
    // 6. Blend (multiply)
    vec4 result;
    if (blend_mode == 0) {  // MULTIPLY
        result = mat_color * facade_color.r;  // facade provides luminance
    } else if (blend_mode == 1) {  // TEXTURE_ONLY
        result = facade_color;
    } else {  // MATERIAL_ONLY
        result = mat_color;
    }
    
    COLOR = result;
}

// Helper: screen-to-flat mapping (per orientation)
vec2 screen_to_flat(vec2 screen_uv, int orientation) {
    // Invert the PerFaceProjector transform for this orientation
    // Implementation depends on pinned transforms from BAKE-01
    // Placeholder; filled in after audit
    return screen_uv;  // TODO
}

// Helper: mirrored-repeat addressing
vec2 mirror_repeat(vec2 uv, vec2 dims) {
    uv = mod(uv, 2.0 * dims);
    if (uv.x >= dims.x) uv.x = 2.0 * dims.x - uv.x;
    if (uv.y >= dims.y) uv.y = 2.0 * dims.y - uv.y;
    return uv / dims;  // Normalize to [0, 1] for sampling
}
```

**Note:** The shader version is an optimization path; the CPU loop (B.2) is correct and sufficient for v1. GPU path can be added after v1 benchmarking shows it's worthwhile.

---

## Part C: Selftest (T2, Render)

In `bake_compositor_test.gd`:

```gdscript
func test_bake_set_dedup() -> void:
    # Create a synthetic map with 10 walls, but only 3 unique (material, facade, variant, face, window)
    # Expected post-dedup count: 3
    
    var map_spec = _create_synthetic_map()
    var resolver = TextureResolver.new()
    
    var compositor = BakeCompositor.new()
    var bake_set = compositor._populate_bake_set(map_spec.room_geometry, resolver)
    
    assert(bake_set.size() == 3, "Dedup failed: expected 3, got %d" % bake_set.size())
    print("PASS: bake_set_dedup")

func test_composite_simple() -> void:
    # Create a material tile (all white) and a facade (all gray)
    # Composite should be gray (white × gray = gray)
    
    var material_tile = Image.create(32, 16, false, Image.FORMAT_RGB8)
    for y in range(16):
        for x in range(32):
            material_tile.set_pixel(x, y, Color.WHITE)
    
    var facade = Image.create(64, 32, false, Image.FORMAT_L8)
    for y in range(32):
        for x in range(64):
            facade.set_pixel(x, y, Color(0.5, 0.5, 0.5))  # 50% gray
    
    var compositor = BakeCompositor.new()
    var sampler = FacadeSampler.new()
    var projector = GLOBAL_PER_FACE_PROJECTOR
    
    var bake_key = BakeKey.new()
    bake_key.material_id = "test_mat"
    bake_key.facade_id = "test_facade"
    bake_key.variant_k = 0
    bake_key.face = Face.NE
    bake_key.plane_col = 0
    bake_key.plane_row = 0
    
    var composite = compositor._composite_tile(material_tile, facade, bake_key, sampler, projector)
    
    # Sample a pixel (should be ~0.5, 0.5, 0.5)
    var pixel = composite.get_pixel(16, 8)  # Center
    assert(abs(pixel.r - 0.5) < 0.1, "Composite failed: expected ~0.5, got %.2f" % pixel.r)
    
    print("PASS: composite_simple")

func test_render_batch_timing() -> void:
    # Full bake of a small map; should complete < 100ms
    
    var map_spec = _create_synthetic_map()
    var resolver = TextureResolver.new()
    
    var compositor = BakeCompositor.new()
    var start = Time.get_ticks_msec()
    var result = compositor.bake(map_spec, resolver)
    var elapsed = Time.get_ticks_msec() - start
    
    assert(elapsed < 100, "Bake too slow: %d ms" % elapsed)
    assert(result.pages.size() > 0, "No atlas pages created")
    assert(result.lookup.size() > 0, "Empty lookup")
    
    print("PASS: render_batch_timing (%.1f ms)" % elapsed)
```

**PASS criteria:**
- `test_bake_set_dedup`: Pre/post-dedup counts logged; dedup correct.
- `test_composite_simple`: Material × facade multiply produces expected result.
- `test_render_batch_timing`: Full bake < 100ms; atlas pages created; lookup populated.
- Debug dumps saved to `user://debug/baked_atlas_page_*.png`.
- Console evidence: tile counts, page counts, timing.

---

## Part D: Integration Points

### D.1 Entry from map load (room_builder.gd, later in BAKE-05)

```gdscript
# In room_builder.gd (pseudocode, after geometry is built)

func _build_room_bake() -> void:
    if not BakeConfig.enabled:
        return
    
    var resolver = TextureResolver.new()
    var compositor = BakeCompositor.new()
    var atlas = compositor.bake(map_spec, resolver)
    
    # Register atlas (BAKE-05 will show how)
    GLOBAL_BAKED_ATLAS = atlas
```

### D.2 Material atlas assumption

The compositor assumes `GLOBAL_MATERIAL_ATLAS` is already populated (from BAKE-02 at boot). If not, it fails loudly (assertion on access).

---

## Part E: Rollout Checklist

Before BAKE-05 can start:

- [ ] `bake_compositor.gd` written with bake set population, deduplication, batch rendering.
- [ ] Compositor shader placeholder in place (or GPU path deferred to v1.1).
- [ ] Selftest `bake_compositor_test.gd` PASS achieved (dedup, composite, timing < 100ms).
- [ ] Debug dumps confirm correct composite results (visual inspection of baked_atlas_page_*.png).
- [ ] Console logs: pre/post-dedup counts, page count, timing in ms.
- [ ] Evidence transcript appended to session archive.

---

*End of BAKE-04.*
