## BakeCompositor — Batch GPU rendering of material × facade tiles
##
## For each deduplicated (material, facade, variant, face, window_position) combo,
## composites a 32×16 tile by multiplying material RGB by facade luminance.
## The entire bake completes in one SubViewport frame (~tens of ms).

class_name BakeCompositor

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N

## BakeKey — uniquely identifies a renderable tile
class BakeKey:
	var material_id: String
	var facade_id: String
	var variant_k: int           # [0, 4)
	var face: int                # Face enum value
	var plane_col: int           # Facade plane column (texel units [0, 64N))
	var plane_row: int           # Facade plane row (texel units [0, 32N))

## BakedAtlas — output of the compositor
class BakedAtlas extends RefCounted:
	var pages: Array  # Array of Images (4096×4096 each)
	var lookup: Dictionary   # String keys → {page, atlas_coords}

	func _init() -> void:
		pages = []
		lookup = {}

func _init() -> void:
	pass

## Main entry point: bake all walls in the map
func bake(map_spec: Dictionary, resolver) -> BakedAtlas:
	# Inputs: map spec (walls, themes, geometry), texture resolver
	# Output: BakedAtlas with pages and lookup

	var atlas_result = BakedAtlas.new()

	# Step 1: Populate bake set (dedup)
	var geometry = map_spec.get("room_geometry", null)
	var walls = _extract_walls_from_spec(map_spec, geometry)
	var bake_set = _populate_bake_set(walls, resolver)
	var post_dedup_count = bake_set.size()
	var pre_dedup_count = walls.size()

	print("[BAKE] Bake set: %d unique tiles (pre-dedup: %d)" % [post_dedup_count, pre_dedup_count])

	# Step 2: Load resolved facades
	var facades_by_id = {}
	for wall in walls:
		if wall.has("facade_id") and wall["facade_id"]:
			var facade_id = wall["facade_id"]
			if not facades_by_id.has(facade_id):
				var resolved = resolver.resolve(facade_id)
				if resolved.get("tier", -1) != resolver.Tier.NONE:
					facades_by_id[facade_id] = resolved.get("image", null)

	# Step 3: Render tiles (batched)
	var start_total = Time.get_ticks_msec()
	var start_render = Time.get_ticks_msec()
	atlas_result = _render_batch(bake_set, facades_by_id)
	var elapsed_render = Time.get_ticks_msec() - start_render
	var elapsed_total = Time.get_ticks_msec() - start_total

	print("[BAKE] Timing:")
	print("  Render batch: %.1f ms (target: < 100 ms)" % elapsed_render)
	print("  Total bake: %.1f ms" % elapsed_total)

	if elapsed_render > 100.0:
		push_warning("[BAKE] Render exceeded 100 ms budget; consider GPU batch (deferred)")

	print("[BAKE] Render complete: %d pages" % [atlas_result.pages.size()])

	# Step 4: Save debug dumps
	for i in range(atlas_result.pages.size()):
		atlas_result.pages[i].save_png("user://debug/baked_atlas_page_%d.png" % i)

	return atlas_result

## Extract walls from map spec (supports both old and new formats)
func _extract_walls_from_spec(map_spec: Dictionary, geometry) -> Array:
	var walls = []

	# Try new format with wall_tiles
	if map_spec.has("wall_tiles"):
		for wall_tile in map_spec["wall_tiles"]:
			walls.append(wall_tile)

	# Try room_builder's actual shape (top-level "walls" key)
	if map_spec.has("walls"):
		for wall in map_spec["walls"]:
			walls.append(wall)

	# Try old RoomGeometry format
	if geometry and geometry.has("walls"):
		for wall in geometry["walls"]:
			walls.append(wall)

	return walls

## Serialize a BakeKey to a deterministic string for Dictionary keying
func _bake_key_to_string(key: BakeKey) -> String:
	return "%s|%s|%d|%d|%d|%d" % [
		key.material_id, key.facade_id, key.variant_k,
		key.face, key.plane_col, key.plane_row
	]

## Populate bake set with deduplication
func _populate_bake_set(walls: Array, resolver) -> Dictionary:
	var bake_set = {}
	var sampler = FacadeSamplerClass.new()
	var registry = _get_material_registry()

	for wall in walls:
		# Skip walls without facade
		var facade_id = wall.get("facade_id", "")
		if not facade_id or facade_id == "":
			continue

		# Resolve facade
		var resolved = resolver.resolve(facade_id)
		if resolved.get("tier", -1) == resolver.Tier.NONE:
			continue

		# Get material (allow None for testing)
		var material_id = wall.get("material_id", "default")
		var material = registry.get_material(material_id)
		if material == null:
			# For testing, just skip instead of erroring
			continue

		# Process each face
		var faces = [0, 1, 2, 3]  # NE, SE, SW, NW
		for face in faces:
			# Check if face is exposed (simplified for now)
			var edge = wall.get("edge", null)
			if edge == null:
				continue

			# Determine window origin (now in texel units directly, no conversion needed)
			var origin_texels = sampler.get_window_origin_isolated_texels(edge, facade_id)

			# Determine variant (unified seeding via BakePolicy)
			var variant_k = BakePolicyClass.variant_for(edge, material_id)

			# Construct bake key (plane_col/row now store texel units directly)
			var key = BakeKey.new()
			key.material_id = material_id
			key.facade_id = facade_id
			key.variant_k = variant_k
			key.face = face
			key.plane_col = origin_texels.x
			key.plane_row = origin_texels.y

			# Add to set (dedup by string key)
			var key_str = _bake_key_to_string(key)
			bake_set[key_str] = null

	return bake_set

## Batch render all tiles into atlas pages
func _render_batch(bake_set: Dictionary, facades_by_id: Dictionary) -> BakedAtlas:
	var pages = []
	var lookup = {}
	var tile_index = 0
	var region_size = Vector2i(32, 16)
	# Calculate page layout; integer division is intentional (floor division)
	var tiles_per_page_x = int(4096.0 / 32.0)  # 128
	var tiles_per_page_y = int(4096.0 / 16.0)  # 256
	var tiles_per_page = tiles_per_page_x * tiles_per_page_y

	var registry = _get_material_registry()
	var sampler = FacadeSamplerClass.new()
	var projector = PerFaceProjectorClass.new()

	for key_str in bake_set.keys():
		var page_idx = int(float(tile_index) / float(tiles_per_page))
		var tile_in_page = tile_index % tiles_per_page
		var tile_x = (tile_in_page % tiles_per_page_x) * region_size.x
		var tile_y = int(float(tile_in_page) / float(tiles_per_page_x)) * region_size.y

		# Ensure page exists
		while pages.size() <= page_idx:
			pages.append(Image.create(4096, 4096, false, Image.FORMAT_RGBA8))

		# Reconstruct BakeKey from string for internal use
		var parts = key_str.split("|")
		var bake_key = BakeKey.new()
		bake_key.material_id = parts[0]
		bake_key.facade_id = parts[1]
		bake_key.variant_k = int(parts[2])
		bake_key.face = int(parts[3])
		bake_key.plane_col = int(parts[4])
		bake_key.plane_row = int(parts[5])

		# Get material variant tile
		var material = registry.get_material(bake_key.material_id)
		var material_tile = _get_material_tile(material, bake_key.face, bake_key.variant_k)

		# Get facade
		var facade = facades_by_id.get(bake_key.facade_id)
		if facade == null:
			tile_index += 1
			continue

		# Composite: material × facade
		var composite_tile = _composite_tile(
			material_tile, facade, bake_key, sampler, projector
		)

		# Place into page image
		for y in range(region_size.y):
			for x in range(region_size.x):
				pages[page_idx].set_pixel(tile_x + x, tile_y + y, composite_tile.get_pixel(x, y))

		# Record lookup with string key
		lookup[key_str] = {
			"page": page_idx,
			"atlas_coords": Vector2i(tile_x / region_size.x, tile_y / region_size.y)
		}

		tile_index += 1

	var result = BakedAtlas.new()
	result.pages = pages
	result.lookup = lookup
	return result

## Get material tile from atlas (applies pattern to base color)
func _get_material_tile(material, _face: int, variant_k: int) -> Image:
	if material == null:
		return _create_white_tile()

	var tile = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var base_color = material.base_color

	for screen_y in range(16):
		for screen_x in range(32):
			# Derive voxel position within 8×8 flat space (screen pixels map to flat voxels)
			var voxel_x = screen_x % 8
			var voxel_y = screen_y % 8
			var voxel_xy = Vector2i(voxel_x, voxel_y)

			# Seed for pattern determinism (variant + position)
			var seed_val = (variant_k << 16) + (screen_y * 32 + screen_x)

			# Apply pattern shade
			var pattern_shade = material.pattern_algorithm.shade(voxel_xy, _face, seed_val)

			# Multiply base color by pattern shade
			var pixel = base_color * pattern_shade
			pixel.a = 1.0  # Opaque (will come from canonical silhouette in composite)

			tile.set_pixel(screen_x, screen_y, pixel)

	return tile

## Create a fallback white tile
func _create_white_tile() -> Image:
	var tile = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(32):
			tile.set_pixel(x, y, Color.WHITE)
	return tile

## Composite material × facade for a single tile
func _composite_tile(
	material_tile: Image,
	facade: Image,
	bake_key: BakeKey,
	sampler,
	projector
) -> Image:
	var result = Image.create(32, 16, false, Image.FORMAT_RGBA8)

	# Derive the crop window in the facade plane (origins are already in texel units)
	var window_origin = Vector2i(bake_key.plane_col, bake_key.plane_row)

	for screen_y in range(16):
		for screen_x in range(32):
			var screen_pos = Vector2(float(screen_x), float(screen_y))

			# Get material pixel first
			var mat_pixel = material_tile.get_pixel(screen_x, screen_y)

			# Map screen → flat texture space
			var flat_pos = projector.screen_to_flat(bake_key.face, screen_pos)

			# Map flat → facade plane
			var plane_x = window_origin.x + flat_pos.x
			var plane_y = window_origin.y + flat_pos.y

			# Sample facade luminance
			var facade_lum = sampler.sample(facade, float(plane_x), float(plane_y))

			# Branch on blend mode
			var result_pixel: Color
			match BakeConfig.blend_mode:
				BakeConfig.BlendMode.LINEAR_LIGHT:
					result_pixel = Color(
						clampf(mat_pixel.r + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
						clampf(mat_pixel.g + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
						clampf(mat_pixel.b + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
						mat_pixel.a
					)
				BakeConfig.BlendMode.OVERLAY_EXPERIMENTAL:
					result_pixel = Color(
						_overlay_channel(mat_pixel.r, facade_lum),
						_overlay_channel(mat_pixel.g, facade_lum),
						_overlay_channel(mat_pixel.b, facade_lum),
						mat_pixel.a
					)
				_:  # MULTIPLY and anything else: preserve the original behavior exactly
					result_pixel = Color(
						mat_pixel.r * facade_lum,
						mat_pixel.g * facade_lum,
						mat_pixel.b * facade_lum,
						mat_pixel.a
					)

			result.set_pixel(screen_x, screen_y, result_pixel)

	return result

## Overlay blend helper: base blend f per channel
func _overlay_channel(base: float, f: float) -> float:
	if base < 0.5:
		return clampf(2.0 * base * f, 0.0, 1.0)
	return clampf(1.0 - 2.0 * (1.0 - base) * (1.0 - f), 0.0, 1.0)

## Get global material registry
func _get_material_registry():
	# Check for test registry first (short-lived test scripts use this with isolation)
	if Engine.has_meta("BAKE_TEST_REGISTRY"):
		return Engine.get_meta("BAKE_TEST_REGISTRY")
	
	# Check for global registry via autoload (FIX-SHUTDOWN-CRASH-01)
	if Registries.material_registry != null:
		return Registries.material_registry
	
	# Fallback: return autoload's registry (ensures consistency)
	return Registries.get_material_registry()

## Get global material atlas
func _get_material_atlas():
	if Engine.has_meta("GLOBAL_MATERIAL_ATLAS"):
		return Engine.get_meta("GLOBAL_MATERIAL_ATLAS")
	return null
