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
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer


@export var light_registry = null
@export var tile_size: Vector2 = Vector2(128, 64)  # Set by VisionController; the lamp radius and the direction arrow scale with it
@export var visual_offset: Vector2 = Vector2(0, 0)

## Offset from a cell's map_to_local() to its visual rhombus center (canonical placement)
const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

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

func set_dev_vision(enabled: bool) -> void:
	_dev_vision_enabled = enabled
	queue_redraw()


## RENDER3D R3D-5b, the dev overlays (2026-10-02): when a 3D board is set this overlay's drawing goes to a `GroundCanvas3D`
## (the same calls, on the ground plane, depth-tested) instead of the 2D canvas, so under a camera yaw it stays on its cells.
const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
var _ground: RefCounted = null
var _c: Object = self  ## where the draw calls go: this node, or `_ground` while a 3D board is set


func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board == null:
		queue_redraw()
		return
	_ground = GroundCanvas3DRef.new()
	_ground.attach(board, 6, 0.014, false)
	_ground.follow_visibility_of(self)
	queue_redraw()


func _draw() -> void:
	if _ground == null:
		return  ## no 3D board to draw on: nothing to paint (the 2D canvas fallback is gone)
	_c = _ground
	_ground.begin(self)
	_draw_into()
	_ground.end()
	_c = self


func _draw_into() -> void:
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
	_c.draw_circle(world_pos, radius_pixels, Color(color.r, color.g, color.b, color.a * 0.3))
	
	# Draw radius outline
	_c.draw_set_transform(world_pos, 0, Vector2.ONE)
	_c.draw_circle(Vector2.ZERO, radius_pixels, color)
	_c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw center marker
	_c.draw_circle(world_pos, 4, color)
	
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
	_c.draw_line(world_pos, arrow_end, color, 2.0)
	
	# Arrow head
	var arrow_head_size = 8.0
	var perp = Vector2(-dir.y, dir.x)
	var head_left = arrow_end - dir * arrow_head_size + perp * arrow_head_size * 0.5
	var head_right = arrow_end - dir * arrow_head_size - perp * arrow_head_size * 0.5
	_c.draw_line(arrow_end, head_left, color, 2.0)
	_c.draw_line(arrow_end, head_right, color, 2.0)

func _draw_light_label(light, _world_pos: Vector2, _color: Color) -> void:
	var _label_text = "%s\n%s\nH:%d R:%d" % [
		light.light_id,
		light.light_type.to_upper(),
		light.height_class,
		light.radius
	]
	
	# For now, we'll skip font rendering since it requires a Font resource
	# This will be added in future iteration when debug UI is more complete
	# _c.draw_string(font, world_pos + Vector2(10, -20), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Canonical projection (matches lamps & floor): the ground lattice, no tile layer
	return GroundGridRef.map_to_local(cell) + TILE_CENTER_OFFSET + visual_offset
