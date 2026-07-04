# BAKE-02: MaterialRegistry & Pattern Algorithms

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `material_registry.gd` module, pattern algorithm modules (stone, wood, metal), generated material voxel atlas, debug dump
**Predecessor:** `BAKE-01` (PerFaceProjector + pinned N)
**Successor:** `BAKE-03` (FacadeSampler)
**Status:** Ready for implementation
**PASS criteria:** All K=4 variants generated deterministically; console logs atlas dimensions and tile count; `user://debug/material_atlas.png` produced and visually inspects; algorithm shades are reproducible under fixed seed

---

## Context

Materials are not texture files — they are **code**. A material couples a base color with a pattern shading algorithm that creates per-voxel luminance variation. The registry generates K=4 canonical tile variants per material at boot, which serve as the baseline for the baking pipeline (they supply the RGB and alpha channels that get multiplied with the facade luminance).

This is the only place where **pixels are created**; all other baking stages operate on these pixels.

---

## Part A: MaterialRegistry Module

### A.1 Data Structure

```gdscript
class_name MaterialRegistry

class Material:
    var id: String                      # "stone", "wood", "metal", etc.
    var base_color: Color               # HSV-stable hue for the material
    var pattern_algorithm: PatternAlgorithm  # Callable or algorithm object
    var flags: int = 0                  # Future: TRANSLUCENT, etc.
    
    func _init(p_id: String, p_color: Color, p_algo: PatternAlgorithm) -> void:
        id = p_id
        base_color = p_color
        pattern_algorithm = p_algo

class PatternAlgorithm:
    # Pure, deterministic function
    func shade(voxel_xy: Vector2i, face: Face, seed: int) -> float:
        # Returns a multiplier in [0, 1] or slightly outside for artistic range
        # Applied to base_color to produce the final voxel RGB
        pass

var registry: Dictionary = {}  # id → Material

func register(material: Material) -> void:
    registry[material.id] = material

func get_material(id: String) -> Material:
    return registry.get(id, null)

func list_materials() -> Array:
    return registry.keys()
```

### A.2 Built-in Materials & Algorithms

Three v1 algorithms are provided as code; future materials (grass, dirt, water) are registered the same way.

#### A.2.1 Stone Pattern

```gdscript
class_name StonePattern
extends PatternAlgorithm

# Stone: per-voxel granular jitter
# Simulates natural surface granularity; grainy texture, high-frequency variation

func shade(voxel_xy: Vector2i, face: Face, seed: int) -> float:
    # Seed is derived from GU position + variant offset
    # Generate a deterministic hash-based "noise" per voxel
    
    var hash_input = seed + voxel_xy.x * 73 + voxel_xy.y * 131
    var noise_val = _hash_float(hash_input)  # [0, 1]
    
    # Jitter range: ±10% around base luminance
    var jitter = (noise_val - 0.5) * 0.2  # [-0.1, 0.1]
    
    return 1.0 + jitter  # [0.9, 1.1], will be clamped or allowed for artistic range

func _hash_float(x: int) -> float:
    # Deterministic hash function: int → [0, 1] float
    # Use FNV-1a style or similar; critical: **reproducible across runs**
    var hash = x
    hash ^= hash >> 16
    hash *= 0x85ebca6b
    hash ^= hash >> 13
    return float(hash & 0xFFFFFFFF) / 0xFFFFFFFF
```

**Visual result:** speckled, granular surface. Each voxel face has slightly different luminance, simulating porous stone. Combines well with marble facade veins (which provide large-scale structure).

#### A.2.2 Wood Pattern

```gdscript
class_name WoodPattern
extends PatternAlgorithm

# Wood: columnar periodic grooves
# Simulates wood grain with vertical groove directionality

func shade(voxel_xy: Vector2i, face: Face, seed: int) -> float:
    # Grooves run vertically; horizontal periodicity creates the grain
    # Period = 2 voxels (visible at isometric scale)
    
    var groove_period = 2.0  # voxels
    var phase = float(voxel_xy.x) / groove_period
    var wave = sin(phase * PI) * 0.5 + 0.5  # [0, 1], one period = one sine
    
    # Vary groove depth slightly with a subtle noise component
    var hash_input = seed + voxel_xy.x * 73 + voxel_xy.y * 131
    var micro_jitter = (_hash_float(hash_input) - 0.5) * 0.1  # ±5%
    
    var shade = 0.8 + wave * 0.3 + micro_jitter  # [0.8, 1.1]
    return shade

func _hash_float(x: int) -> float:
    # As StonePattern
    pass
```

**Visual result:** wood planks with visible grain lines (grooves). Horizontal stripes across the face at 2-voxel spacing. The micro-jitter breaks perfect periodicity for realism. Combine with wood facade (if authored) for veins and color variation.

#### A.2.3 Metal Pattern

```gdscript
class_name MetalPattern
extends PatternAlgorithm

# Metal: sheen band across the face
# Simulates reflective specular highlight; smooth gradient

func shade(voxel_xy: Vector2i, face: Face, seed: int) -> float:
    # Sheen band moves across the face based on orientation
    # For simplicity: always a gradient in one axis, producing 8 visible "steps" per edge (64 voxels)
    
    var steps_per_edge = 8.0
    var position_in_edge = float(voxel_xy.x % 8)  # [0, 8)
    var step_fraction = position_in_edge / 8.0    # [0, 1)
    
    # Smooth gradient; not stepped
    var shade = 0.7 + step_fraction * 0.4  # [0.7, 1.1]
    
    # Optional: add a subtle vertical variation to avoid flatness
    var vertical_mod = 0.95 + (_hash_float(seed + voxel_xy.y) - 0.5) * 0.1
    
    return shade * vertical_mod  # [~0.65, ~1.15]

func _hash_float(x: int) -> float:
    # As above
    pass
```

**Visual result:** brushed metal with a smooth sheen band across the face. The 8-step banding (coarse gradient) is intentional, fitting the low-poly aesthetic. Combine with metallic facade for surface detail.

---

## Part B: Atlas Generation

### B.1 Voxel Tile Geometry

Recall from BAKE-01: each voxel tile occupies `VOXEL_TILE_SIZE = (32×16)` pixels in screen space. The geometry of each tile **comes from the existing tileset** — we reuse its layout. The material atlas inherits:

- `texture_region_size = (32, 16)`
- `texture_origin = ` (existing canon value, e.g., (16, 8))
- Face orientation handling (the four cardinal orientations + cap, if any)

### B.2 Generation Process

At boot (or on demand), `MaterialAtlasGenerator` produces a texture atlas:

```gdscript
class_name MaterialAtlasGenerator

func generate_atlas(registry: MaterialRegistry, N: int, face_variants: Array) -> AtlasResult:
    # registry: the populated MaterialRegistry
    # N: pinned flat texels per voxel (from BAKE-01)
    # face_variants: [Face.NE, Face.SE, Face.SW, Face.NW, Face.CAP] or subset
    
    # Example: 3 materials × 5 faces × 4 variants = 60 tiles
    var materials = registry.list_materials()
    var num_tiles = materials.size() * face_variants.size() * 4  # 4 variants per material
    
    # Determine atlas layout: pack tiles into pages (each page is 4096×4096 or smaller)
    var page_size = Vector2i(4096, 4096)
    var region_size = Vector2i(32, 16)
    var tiles_per_page_x = page_size.x / region_size.x  # 128
    var tiles_per_page_y = page_size.y / region_size.y  # 256
    var tiles_per_page = tiles_per_page_x * tiles_per_page_y  # 32768
    
    var num_pages = ceili(float(num_tiles) / float(tiles_per_page))
    print("MaterialAtlas: %d tiles, %d page(s)" % [num_tiles, num_pages])
    
    # Generate pages
    var pages: Array[Image] = []
    var tile_lookup: Dictionary = {}  # (material_id, face, variant) → atlas_coords
    
    var tile_index = 0
    for material_id in materials:
        var material = registry.get_material(material_id)
        
        for face in face_variants:
            for variant_k in range(4):
                var tile_image = _render_material_tile(material, face, variant_k, N)
                
                # Place into atlas
                var page_idx = tile_index / tiles_per_page
                var tile_in_page = tile_index % tiles_per_page
                var tile_x = (tile_in_page % tiles_per_page_x) * region_size.x
                var tile_y = (tile_in_page / tiles_per_page_x) * region_size.y
                
                # Ensure page exists
                while pages.size() <= page_idx:
                    pages.append(Image.create(page_size.x, page_size.y, false, Image.FORMAT_RGB8))
                
                # Composite tile_image into page at (tile_x, tile_y)
                for y in range(region_size.y):
                    for x in range(region_size.x):
                        pages[page_idx].set_pixel(tile_x + x, tile_y + y, tile_image.get_pixel(x, y))
                
                # Record lookup
                tile_lookup[(material_id, face, variant_k)] = {
                    "page": page_idx,
                    "atlas_coords": Vector2i(tile_x / region_size.x, tile_y / region_size.y)
                }
                
                tile_index += 1
    
    return AtlasResult.new(pages, tile_lookup)

func _render_material_tile(material: Material, face: Face, variant_k: int, N: int) -> Image:
    # Render a single material voxel tile to an Image(32×16)
    # Process:
    # 1. Create a 32×16 image (screen-space isometric tile)
    # 2. For each pixel in the tile:
    #    a. Determine which voxel-space (x, y) it corresponds to (via inverse of PerFaceProjector)
    #    b. Call material.pattern_algorithm.shade() with the voxel coords + variant seed
    #    c. Multiply material.base_color by the shade multiplier
    #    d. Set the pixel
    # 3. Return the image
    
    var tile = Image.create(32, 16, false, Image.FORMAT_RGB8)
    var projector = PerFaceProjector.new()  # Assumes initialized from BAKE-01 audit
    
    for screen_y in range(16):
        for screen_x in range(32):
            var screen_pos = Vector2(screen_x, screen_y)
            
            # Check if this pixel is inside the voxel face (silhouette)
            if not projector.is_inside_voxel(face, screen_pos):
                # Outside the voxel face boundary; set to transparent or black
                tile.set_pixel(screen_x, screen_y, Color(0, 0, 0, 0))
                continue
            
            # Map screen → flat texture space
            var flat_pos = projector.screen_to_flat(face, screen_pos)
            var voxel_xy = Vector2i(int(flat_pos.x / N), int(flat_pos.y / N))  # Which voxel?
            
            # Get pattern shade multiplier
            var seed = hash_u32("%s_%d" % [material.id, variant_k])
            var shade = material.pattern_algorithm.shade(voxel_xy, face, seed)
            
            # Apply to base color
            var colored_pixel = material.base_color * Color(shade, shade, shade, 1.0)
            tile.set_pixel(screen_x, screen_y, colored_pixel)
    
    return tile
```

### B.3 Output & Caching

After generation, the atlas (one or more Image pages) is:

1. **Saved to disk** in `user://debug/material_atlas_page_{n}.png` for inspection.
2. **Registered with the TileSet** as a `TileSetAtlasSource` (persistent, reused by all maps until the game restarts).
3. **Indexed by `tile_lookup`** (a dictionary) for placement code to query.

---

## Part C: MaterialRegistry Integration

### C.1 Boot Sequence

In `main.gd` or a game-init scene:

```gdscript
func _ready() -> void:
    # Initialize material registry
    var registry = MaterialRegistry.new()
    registry.register(Material.new("stone", Color(0.7, 0.7, 0.7), StonePattern.new()))
    registry.register(Material.new("wood", Color(0.6, 0.35, 0.15), WoodPattern.new()))
    registry.register(Material.new("metal", Color(0.5, 0.55, 0.6), MetalPattern.new()))
    
    # Generate atlas
    var N = TEX_AUTHORING_N  # Pinned constant from BAKE-01
    var generator = MaterialAtlasGenerator.new()
    var atlas_result = generator.generate_atlas(registry, N, [Face.NE, Face.SE, Face.SW, Face.NW])
    
    # Register atlas with TileSet (global, persistent)
    GLOBAL_MATERIAL_ATLAS = atlas_result
    print("Material atlas generated: %d tiles" % atlas_result.tile_lookup.size())
```

The material atlas persists for the game session; it is not re-generated per map.

### C.2 Selftest (T1, Headless)

In `material_registry_test.gd`:

```gdscript
func test_pattern_determinism() -> void:
    var stone = StonePattern.new()
    var voxel = Vector2i(5, 7)
    var face = Face.NE
    var seed = 12345
    
    # Call the same pattern twice; results must be identical
    var shade1 = stone.shade(voxel, face, seed)
    var shade2 = stone.shade(voxel, face, seed)
    
    assert(shade1 == shade2, "Pattern not deterministic")
    print("PASS: pattern_determinism")

func test_atlas_generation() -> void:
    var registry = MaterialRegistry.new()
    registry.register(Material.new("stone", Color(0.7, 0.7, 0.7), StonePattern.new()))
    registry.register(Material.new("wood", Color(0.6, 0.35, 0.15), WoodPattern.new()))
    registry.register(Material.new("metal", Color(0.5, 0.55, 0.6), MetalPattern.new()))
    
    var N = 16  # Example from BAKE-01
    var generator = MaterialAtlasGenerator.new()
    var atlas = generator.generate_atlas(registry, N, [Face.NE, Face.SE, Face.SW, Face.NW])
    
    # Check counts
    var expected_tiles = 3 * 4 * 4  # 3 materials × 4 faces × 4 variants
    assert(atlas.tile_lookup.size() == expected_tiles, 
        "Expected %d tiles, got %d" % [expected_tiles, atlas.tile_lookup.size()])
    
    # Check that pages were created
    assert(atlas.pages.size() > 0, "No atlas pages created")
    
    print("PASS: atlas_generation (tiles: %d, pages: %d)" % [expected_tiles, atlas.pages.size()])

func test_tile_lookup() -> void:
    var registry = MaterialRegistry.new()
    registry.register(Material.new("stone", Color(0.7, 0.7, 0.7), StonePattern.new()))
    
    var atlas = MaterialAtlasGenerator.new().generate_atlas(registry, 16, [Face.NE])
    
    # Query a tile
    var key = ("stone", Face.NE, 0)
    var coords = atlas.tile_lookup[key]
    
    assert(coords != null, "Tile lookup failed")
    assert(coords["page"] >= 0, "Invalid page index")
    
    print("PASS: tile_lookup")
```

**PASS criteria:**
- Pattern determinism test passes (identical seed → identical shade).
- Atlas generation produces expected tile count.
- Page creation succeeds (> 0 pages).
- Tile lookup correctly returns atlas coordinates.
- Console logs: `user://debug/material_atlas_page_0.png` (or more) created, with all materials visible under magnification.

---

## Part D: Visual Inspection (T2, Render)

After generation, inspect the produced atlas:

1. Open `user://debug/material_atlas_page_0.png` in an image viewer.
2. Verify each material is visually distinct:
   - Stone: speckled, granular appearance.
   - Wood: columnar grooves, horizontal striping.
   - Metal: smooth sheen band, gradient across tiles.
3. Verify all 4 variants per material are present and slightly different (due to seed offset).
4. Verify all face orientations (NE, SE, SW, NW) are rendered correctly (isometric shape preserved).
5. Verify silhouettes are correct: all non-voxel areas (outside the isometric parallelogram) are transparent or black.

---

## Part E: Algorithm Extensibility

To add a new material (e.g., grass, dirt, water), follow this template:

```gdscript
class_name GrassPattern
extends PatternAlgorithm

func shade(voxel_xy: Vector2i, face: Face, seed: int) -> float:
    # Define grass-specific shading
    # Example: subtle jitter + vertical variation
    var jitter = _hash_float(seed + voxel_xy.x * 73 + voxel_xy.y * 131) - 0.5
    var vertical_fade = 1.0 - float(voxel_xy.y % 8) / 8.0  # Darker at bottom
    return (0.9 + jitter * 0.15) * vertical_fade

func _hash_float(x: int) -> float:
    # Reuse shared hash function
    pass
```

Register at boot:

```gdscript
registry.register(Material.new("grass", Color(0.4, 0.6, 0.3), GrassPattern.new()))
```

---

## Part F: Rollout Checklist

Before BAKE-03 can start:

- [ ] `material_registry.gd` written with Material and PatternAlgorithm base classes.
- [ ] Three v1 algorithms implemented (StonePattern, WoodPattern, MetalPattern) with deterministic hash-based shading.
- [ ] `material_atlas_generator.gd` written; atlas generation produces correct tile count and pages.
- [ ] Selftest `material_registry_test.gd` PASS achieved (pattern determinism, atlas generation, tile lookup).
- [ ] Atlas debug dumps to `user://debug/material_atlas_page_*.png`; visual inspection confirms expected appearance.
- [ ] Console evidence: tile count, page count, material list logged.
- [ ] Boot sequence integrates MaterialRegistry and calls generator (or deferred load module ready for BAKE-05).

---

*End of BAKE-02.*
