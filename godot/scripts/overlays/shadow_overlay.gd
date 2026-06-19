## ShadowOverlay — Debug visualization of shadow projection
##
## Shows computed shadow topology from ShadowProjector.
## Only visible in DEV_VISION mode.
##
## Display includes:
## - Directly lit tiles (bright green)
## - Penumbra/dim zone (yellow)
## - Shadow tiles (dark blue)
## - Deep shadow tiles (very dark)
## - Occlusion boundaries (red outline)

extends Node2D

const ShadowResultClass = preload("res://godot/scripts/systems/lighting/shadow_result.gd")

@export var shadow_projector = null
@export var light_registry = null
@export var tile_size: Vector2 = Vector2(128, 64)
@export var visual_offset: Vector2 = Vector2(0, 0)

var _dev_vision_enabled: bool = false
var _current_results: Array = []  ## Array of ShadowResult
var _playable_shadow_cells: Dictionary = {}  ## Merged shadow_tiles + deep_shadow_tiles

# Color palette for shadow visualization
var _shadow_colors: Dictionary = {
	"fully_lit": Color(0.2, 1.0, 0.2, 0.5),    # Bright green
	"dim": Color(1.0, 1.0, 0.2, 0.4),         # Yellow
	"penumbra": Color(1.0, 0.8, 0.2, 0.3),    # Orange-yellow
	"shadow": Color(0.2, 0.4, 1.0, 0.6),      # Dark blue
	"deep_shadow": Color(0.1, 0.1, 0.3, 0.7), # Very dark blue
	"shadow_edge": Color(0.15, 0.15, 0.15, 0.9), # Dark grey for playable shadow boundaries
}

func _ready() -> void:
	if shadow_projector == null or light_registry == null:
		push_error("ShadowOverlay: shadow_projector and light_registry must be assigned")
		return

func set_dev_vision(enabled: bool) -> void:
	_dev_vision_enabled = enabled
	_update_projections()
	queue_redraw()

func is_dev_vision_enabled() -> bool:
	return _dev_vision_enabled

## Recompute all shadow projections
func _update_projections() -> void:
	if not _dev_vision_enabled or shadow_projector == null or light_registry == null:
		_current_results.clear()
		_playable_shadow_cells.clear()
		return

	_current_results.clear()
	_playable_shadow_cells.clear()

	# Get all active lights and project each
	var lights = light_registry.get_active_lights()
	for light in lights:
		var result = shadow_projector.project_light(light)
		if result != null:
			_current_results.append(result)
			# Merge playable shadow cells (shadow + deep_shadow)
			for cell in result.get_tiles_by_class("shadow"):
				_playable_shadow_cells[cell] = true
			for cell in result.get_tiles_by_class("deep_shadow"):
				_playable_shadow_cells[cell] = true

func _draw() -> void:
	if not _dev_vision_enabled or _current_results.is_empty():
		return

	# Draw all projected tiles
	for result in _current_results:
		_draw_result(result)

	# Draw playable shadow edges (dark boundaries)
	_draw_shadow_edges()

func _draw_result(result) -> void:
	if result == null:
		return
	
	# Draw each visibility class
	for vis_class in ["fully_lit", "dim", "penumbra", "shadow", "deep_shadow"]:
		var tiles = result.get_tiles_by_class(vis_class)
		var color = _shadow_colors.get(vis_class, Color.MAGENTA)
		
		for cell in tiles:
			var world_pos = _cell_to_screen(cell)
			draw_circle(world_pos, 4.0, color)

## Draw dark edges around playable shadow cells (shadow + deep_shadow boundary)
func _draw_shadow_edges() -> void:
	if _playable_shadow_cells.is_empty():
		return

	var edge_color: Color = _shadow_colors.get("shadow_edge", Color.BLACK)

	for shadow_cell in _playable_shadow_cells.keys():
		var diamond: PackedVector2Array = _diamond_points(shadow_cell)

		# Edges: V0->V1 (UP), V1->V2 (RIGHT), V2->V3 (DOWN), V3->V0 (LEFT)
		# Draw edge if neighbor is NOT a shadow tile

		# Top-Right edge (V0 -> V1): Neighbor UP
		if not _playable_shadow_cells.has(shadow_cell + Vector2i.UP):
			draw_line(diamond[0], diamond[1], edge_color, 2.5, true)

		# Bottom-Right edge (V1 -> V2): Neighbor RIGHT
		if not _playable_shadow_cells.has(shadow_cell + Vector2i.RIGHT):
			draw_line(diamond[1], diamond[2], edge_color, 2.5, true)

		# Bottom-Left edge (V2 -> V3): Neighbor DOWN
		if not _playable_shadow_cells.has(shadow_cell + Vector2i.DOWN):
			draw_line(diamond[2], diamond[3], edge_color, 2.5, true)

		# Top-Left edge (V3 -> V0): Neighbor LEFT
		if not _playable_shadow_cells.has(shadow_cell + Vector2i.LEFT):
			draw_line(diamond[3], diamond[0], edge_color, 2.5, true)


## Get isometric diamond vertices for a cell (4 corners of the tile)
func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := _cell_to_screen(cell)
	return PackedVector2Array([
		top,                                    # Top vertex (V0)
		top + Vector2(tile_size.x * 0.5, tile_size.y * 0.5),  # Right vertex (V1)
		top + Vector2(0.0, tile_size.y),       # Bottom vertex (V2)
		top + Vector2(-tile_size.x * 0.5, tile_size.y * 0.5), # Left vertex (V3)
	])


## Convert grid cell to screen isometric position
func _cell_to_screen(cell: Vector2i) -> Vector2:
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset
