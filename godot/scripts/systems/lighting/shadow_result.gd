## ShadowResult — Grid-based shadow projection result
##
## Stores computed shadow topology from a single light source.
## Designed for:
## - auditability (can inspect exact tile classifications)
## - determinism (same light always produces same result)
## - extensibility (supports all 5 visibility classes)
##
## Does NOT:
## - render (that's ShadowOverlay's job)
## - cache (caller manages lifetime)
## - perform physics (discrete grid only)

class_name ShadowResult
extends RefCounted

## Visibility class storage
## Each set contains Vector2i cells with that classification
var fully_lit_tiles: Dictionary = {}     # Full light exposure
var dim_tiles: Dictionary = {}           # Reduced light (penumbra edge)
var penumbra_tiles: Dictionary = {}      # Transitional zone
var shadow_tiles: Dictionary = {}        # Blocked from direct light
var deep_shadow_tiles: Dictionary = {}   # Fully occluded

## Metadata
var source_light: LightSource = null
var computed_tile_count: int = 0

## Debug info
var _occlusion_count: int = 0

func _init(light: LightSource = null) -> void:
	source_light = light

## Add a tile to a visibility class
## Prevents duplicate entries (uses dict for O(1) lookup)
func add_tile(cell: Vector2i, visibility_class: String) -> void:
	match visibility_class:
		"fully_lit":
			if not fully_lit_tiles.has(cell):
				fully_lit_tiles[cell] = true
				computed_tile_count += 1
		"dim":
			if not dim_tiles.has(cell):
				dim_tiles[cell] = true
				computed_tile_count += 1
		"penumbra":
			if not penumbra_tiles.has(cell):
				penumbra_tiles[cell] = true
				computed_tile_count += 1
		"shadow":
			if not shadow_tiles.has(cell):
				shadow_tiles[cell] = true
				computed_tile_count += 1
				_occlusion_count += 1
		"deep_shadow":
			if not deep_shadow_tiles.has(cell):
				deep_shadow_tiles[cell] = true
				computed_tile_count += 1
				_occlusion_count += 1

## Query: is this tile in shadow?
func is_shadowed(cell: Vector2i) -> bool:
	return shadow_tiles.has(cell) or deep_shadow_tiles.has(cell)

## Query: any shadow classification for this tile
func get_visibility_class(cell: Vector2i) -> String:
	if fully_lit_tiles.has(cell):
		return "fully_lit"
	if dim_tiles.has(cell):
		return "dim"
	if penumbra_tiles.has(cell):
		return "penumbra"
	if shadow_tiles.has(cell):
		return "shadow"
	if deep_shadow_tiles.has(cell):
		return "deep_shadow"
	return "unknown"

## Get all tiles of a classification
func get_tiles_by_class(visibility_class: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dict: Dictionary = {}
	
	match visibility_class:
		"fully_lit":
			dict = fully_lit_tiles
		"dim":
			dict = dim_tiles
		"penumbra":
			dict = penumbra_tiles
		"shadow":
			dict = shadow_tiles
		"deep_shadow":
			dict = deep_shadow_tiles
	
	for cell in dict.keys():
		result.append(cell)
	return result

## Merge another result into this one
## Used for combining multiple light sources
func merge(other: ShadowResult) -> void:
	if other == null:
		return
	
	# Simple strategy: if a tile is already darker, keep it
	# Otherwise adopt the classification from other
	for cell in other.fully_lit_tiles.keys():
		if not (shadow_tiles.has(cell) or deep_shadow_tiles.has(cell)):
			add_tile(cell, "fully_lit")
	
	for cell in other.dim_tiles.keys():
		if not (shadow_tiles.has(cell) or deep_shadow_tiles.has(cell)):
			add_tile(cell, "dim")
	
	for cell in other.penumbra_tiles.keys():
		if not (shadow_tiles.has(cell) or deep_shadow_tiles.has(cell)):
			add_tile(cell, "penumbra")
	
	for cell in other.shadow_tiles.keys():
		add_tile(cell, "shadow")
	
	for cell in other.deep_shadow_tiles.keys():
		add_tile(cell, "deep_shadow")

## Debug output
func _to_string() -> String:
	return "[ShadowResult light_id=%s tiles=%d lit=%d shadow=%d]" % [
		source_light.light_id if source_light else "null",
		computed_tile_count,
		fully_lit_tiles.size(),
		_occlusion_count
	]

## Clear all classifications
func clear() -> void:
	fully_lit_tiles.clear()
	dim_tiles.clear()
	penumbra_tiles.clear()
	shadow_tiles.clear()
	deep_shadow_tiles.clear()
	computed_tile_count = 0
	_occlusion_count = 0
