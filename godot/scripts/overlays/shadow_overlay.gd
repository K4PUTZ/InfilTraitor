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

# Color palette for shadow visualization
var _shadow_colors: Dictionary = {
	"fully_lit": Color(0.2, 1.0, 0.2, 0.5),    # Bright green
	"dim": Color(1.0, 1.0, 0.2, 0.4),         # Yellow
	"penumbra": Color(1.0, 0.8, 0.2, 0.3),    # Orange-yellow
	"shadow": Color(0.2, 0.4, 1.0, 0.6),      # Dark blue
	"deep_shadow": Color(0.1, 0.1, 0.3, 0.7), # Very dark blue
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
		return
	
	_current_results.clear()
	
	# Get all active lights and project each
	var lights = light_registry.get_active_lights()
	for light in lights:
		var result = shadow_projector.project_light(light)
		if result != null:
			_current_results.append(result)

func _draw() -> void:
	if not _dev_vision_enabled or _current_results.is_empty():
		return
	
	# Draw all projected tiles
	for result in _current_results:
		_draw_result(result)

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

## Convert grid cell to screen isometric position
func _cell_to_screen(cell: Vector2i) -> Vector2:
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset
