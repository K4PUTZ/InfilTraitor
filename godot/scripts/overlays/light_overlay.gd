## LightOverlay — Visual debug overlay for light sources
##
## Shows:
## - Light position and radius
## - Light type and height class
## - Direction vectors (for cone/directional types)
## - Active/inactive state
##
## Only visible in DEV_VISION mode.

extends Node2D

const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const LightRegistryClass = preload("res://godot/scripts/systems/lighting/light_registry.gd")

@export var light_registry = null
@export var tile_size: Vector2 = Vector2(128, 64)  # Isometric
@export var visual_offset: Vector2 = Vector2(0, 0)

var _dev_vision_enabled: bool = false

# Colors for different light types
var _type_colors: Dictionary = {
	"omni": Color(1.0, 1.0, 0.5, 0.6),  # Yellow
	"directional": Color(0.5, 1.0, 1.0, 0.6),  # Cyan
	"cone": Color(1.0, 0.5, 1.0, 0.6),  # Magenta
	"ambient": Color(0.8, 0.8, 0.8, 0.3),  # Gray
	"intermittent": Color(1.0, 0.5, 0.0, 0.6),  # Orange
	"emergency": Color(1.0, 0.0, 0.0, 0.8),  # Red
	"mobile": Color(0.0, 1.0, 0.0, 0.6),  # Green
}

func _ready() -> void:
	if light_registry == null:
		push_error("LightOverlay: light_registry not assigned")
		return

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("dev_toggle"):  # Assuming 'V' key mapped to dev_toggle
		_dev_vision_enabled = not _dev_vision_enabled
		queue_redraw()

func set_dev_vision(enabled: bool) -> void:
	_dev_vision_enabled = enabled
	queue_redraw()

func is_dev_vision_enabled() -> bool:
	return _dev_vision_enabled

func _draw() -> void:
	if not _dev_vision_enabled or light_registry == null:
		return
	
	var lights = light_registry.get_all_lights()
	for light in lights:
		_draw_light(light)

func _draw_light(light) -> void:
	var world_pos = _cell_to_screen(light.cell)
	var color = _type_colors.get(light.light_type, Color(0.5, 0.5, 0.5, 0.5))
	
	# Dim color if light is inactive
	if not light.active:
		color.a *= 0.3
	
	# Draw radius circle
	var radius_pixels = float(light.radius) * tile_size.x * 0.5
	draw_circle(world_pos, radius_pixels, Color(color.r, color.g, color.b, color.a * 0.3))
	
	# Draw radius outline
	draw_set_transform(world_pos, 0, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius_pixels, color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw center marker
	draw_circle(world_pos, 4, color)
	
	# Draw direction arrow for directional/cone lights
	if light.light_type in ["cone", "directional"]:
		_draw_direction_arrow(light, world_pos, color)
	
	# Draw label
	_draw_light_label(light, world_pos, color)

func _draw_direction_arrow(light, world_pos: Vector2, color: Color) -> void:
	var dir = light.get_direction_vector()
	var arrow_length = tile_size.x * 0.5
	var arrow_end = world_pos + dir * arrow_length
	
	# Main arrow line
	draw_line(world_pos, arrow_end, color, 2.0)
	
	# Arrow head
	var arrow_head_size = 8.0
	var perp = Vector2(-dir.y, dir.x)
	var head_left = arrow_end - dir * arrow_head_size + perp * arrow_head_size * 0.5
	var head_right = arrow_end - dir * arrow_head_size - perp * arrow_head_size * 0.5
	draw_line(arrow_end, head_left, color, 2.0)
	draw_line(arrow_end, head_right, color, 2.0)

func _draw_light_label(light, _world_pos: Vector2, _color: Color) -> void:
	var _label_text = "%s\n%s\nH:%d R:%d" % [
		light.light_id,
		light.light_type.to_upper(),
		light.height_class,
		light.radius
	]
	
	# For now, we'll skip font rendering since it requires a Font resource
	# This will be added in future iteration when debug UI is more complete
	# draw_string(font, world_pos + Vector2(10, -20), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Isometric projection: (x, y) -> (x * tile_width/2 - y * tile_width/2, x * tile_height/2 + y * tile_height/2)
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset
