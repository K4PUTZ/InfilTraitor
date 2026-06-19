## TemporalOverlay — DEV Visualization of Temporal Lighting Effects
##
## Displays:
## - Light positions and temporal states (ON/OFF/FLICKER/PULSE)
## - Energy levels and multipliers
## - Rotation directions for spotlights
## - Frequency information (flicker intervals, pulse speeds)
##
## Updated every frame to show real-time temporal animation.
##
## Purpose: Validate stealth temporal behavior, debug timing, ensure auditability.

extends Node2D

const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

# Color scheme for temporal states
var state_colors: Dictionary = {
	"on": Color.WHITE,           # Fully on
	"off": Color(0.2, 0.2, 0.2), # Off/dark
	"flicker": Color.YELLOW,     # Flickering
	"pulse": Color.CYAN,         # Pulsing
}

# Visualization flags
var show_lights: bool = true
var show_state_labels: bool = true
var show_energy_bars: bool = true
var show_rotations: bool = true

## Overall size of the knob + label + energy bar + backplate cluster
var ui_scale: float = 1.5

# Reference to light registry (set externally)
var light_registry = null

## Offset from a cell's map_to_local() to its visual rhombus center (canonical placement)
const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

# Canonical projection source (matches lamps/floor); tile_size is fallback only
var floor_layer: TileMapLayer = null
# Tile size and offset (for isometric projection)
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

## Pixels to raise the state-knob so it reads just above the (lifted) lamp fixture
var fixture_lift: float = 0.0

# Storage
var all_lights: Array = []

# Animation for flickering indicator
var flicker_animation_phase: float = 0.0

func _ready() -> void:
	pass

func set_dev_vision(enabled: bool) -> void:
	visible = enabled

func load_lights(registry) -> void:
	light_registry = registry
	_refresh_lights()

func _refresh_lights() -> void:
	if light_registry == null:
		return
	all_lights = light_registry.get_all_lights()

func _process(delta: float) -> void:
	flicker_animation_phase += delta * 3.0  # Cycle flicker visualization every ~0.33s
	queue_redraw()

func _draw() -> void:
	if not visible or light_registry == null:
		return
	
	_refresh_lights()

	# Contrast backplate behind each knob cluster (drawn first, under everything)
	_draw_backplates()

	if show_lights:
		_draw_light_states()
	if show_energy_bars:
		_draw_energy_bars()
	if show_rotations:
		_draw_rotations()
	if show_state_labels:
		_draw_state_labels()

## Black 80% panel behind the knob cluster (label + energy bar + knob) for contrast
func _draw_backplates() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(round(10.0 * ui_scale))
	var pad: float = 4.0 * ui_scale
	for light in all_lights:
		if not light.active:
			continue

		var screen_pos: Vector2 = _cell_to_screen(light.cell)
		var text_w: float = font.get_string_size(
			_state_label_text(light), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		# Cluster bounds relative to screen_pos: label starts at x (grows right, ~y-40),
		# energy bar and knob are centered on x (down to ~y+9).
		var min_x: float = screen_pos.x - 12.0 * ui_scale
		var max_x: float = screen_pos.x + maxf(12.0 * ui_scale, text_w)
		var min_y: float = screen_pos.y - 42.0 * ui_scale
		var max_y: float = screen_pos.y + 12.0 * ui_scale

		var rect := Rect2(
			min_x - pad, min_y - pad,
			(max_x - min_x) + pad * 2.0, (max_y - min_y) + pad * 2.0)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.8))


## State label text shared by the backplate and the label pass
func _state_label_text(light) -> String:
	var state_text: String = light.current_state.to_upper()
	if light.flicker_enabled:
		state_text += " [%.1fHz]" % (1.0 / light.flicker_interval)
	elif light.pulse_enabled:
		state_text += " [%.1fHz]" % light.pulse_speed
	return state_text


func _draw_light_states() -> void:
	for light in all_lights:
		if not light.active:
			continue
		
		var screen_pos: Vector2 = _cell_to_screen(light.cell)
		var color: Color = _get_state_color(light)

		# Compact, readable knob: dark outline ring behind, state-color core on top.
		# Fixed size (no longer scaled by light radius, which made it cover the lamp).
		var core_radius: float = 7.0 * ui_scale
		draw_circle(screen_pos, core_radius + 2.0 * ui_scale, Color(0.0, 0.0, 0.0, 0.85))
		draw_circle(screen_pos, core_radius, color)

		# Subtle animated ring for flicker / pulse states
		if light.current_state == "flicker":
			var flicker_radius: float = core_radius + (4.0 + sin(flicker_animation_phase) * 1.5) * ui_scale
			_draw_circle_outline(screen_pos, flicker_radius, Color.YELLOW, 1.0)
		elif light.current_state == "pulse":
			var pulse_radius: float = core_radius + (3.0 + abs(cos(flicker_animation_phase)) * 3.0) * ui_scale
			_draw_circle_outline(screen_pos, pulse_radius, Color.CYAN, 1.0)

func _draw_energy_bars() -> void:
	for light in all_lights:
		if not light.active:
			continue
		
		var screen_pos: Vector2 = _cell_to_screen(light.cell)
		var bar_width: float = 20.0 * ui_scale
		var bar_height: float = 3.0 * ui_scale
		var bar_y_offset: float = 20.0 * ui_scale
		
		# Background bar
		var bar_rect: Rect2 = Rect2(screen_pos - Vector2(bar_width * 0.5, bar_height * 0.5) - Vector2(0, bar_y_offset), Vector2(bar_width, bar_height))
		draw_rect(bar_rect, Color(0.1, 0.1, 0.1))
		
		# Energy bar (filled)
		var energy_fraction: float = light.energy_multiplier
		var filled_width: float = bar_width * energy_fraction
		var filled_rect: Rect2 = Rect2(screen_pos - Vector2(bar_width * 0.5, bar_height * 0.5) - Vector2(0, bar_y_offset), Vector2(filled_width, bar_height))
		draw_rect(filled_rect, Color.WHITE)

func _draw_rotations() -> void:
	for light in all_lights:
		if not light.active or light.rotation_speed == 0.0:
			continue
		
		var screen_pos: Vector2 = _cell_to_screen(light.cell)
		
		# Draw rotation arrow
		var arrow_length: float = 25.0
		var arrow_end: Vector2 = screen_pos + Vector2(cos(light.direction_angle), sin(light.direction_angle)) * arrow_length
		
		draw_line(screen_pos, arrow_end, Color.MAGENTA, 2.0)
		
		# Draw arrowhead
		var arrow_tip_size: float = 5.0
		var back_angle: float = light.direction_angle + PI
		var left: Vector2 = arrow_end + Vector2(cos(back_angle - 0.3), sin(back_angle - 0.3)) * arrow_tip_size
		var right: Vector2 = arrow_end + Vector2(cos(back_angle + 0.3), sin(back_angle + 0.3)) * arrow_tip_size
		draw_line(arrow_end, left, Color.MAGENTA, 2.0)
		draw_line(arrow_end, right, Color.MAGENTA, 2.0)

func _draw_state_labels() -> void:
	for light in all_lights:
		if not light.active:
			continue
		
		var screen_pos: Vector2 = _cell_to_screen(light.cell)
		var label_offset: float = 30.0 * ui_scale

		var state_text: String = _state_label_text(light)

		var label_pos: Vector2 = screen_pos - Vector2(0, label_offset)
		draw_string(ThemeDB.fallback_font, label_pos, state_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(round(10.0 * ui_scale)), Color.WHITE)

func _get_state_color(light) -> Color:
	var base_color: Color = state_colors.get(light.current_state, Color.WHITE)
	
	# Modulate by energy level
	var energy: float = light.energy_multiplier
	return Color(
		base_color.r * energy,
		base_color.g * energy,
		base_color.b * energy,
		base_color.a
	)

func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Canonical projection (matches lamps & floor); raise by fixture_lift so the
	# knob reads just above the lifted lamp glyph.
	if floor_layer != null:
		return floor_layer.map_to_local(cell) + TILE_CENTER_OFFSET + visual_offset - Vector2(0.0, fixture_lift)
	# Fallback: legacy manual isometric projection (only if floor_layer unset)
	var x: float = float(cell.x)
	var y: float = float(cell.y)
	var screen_x: float = (x - y) * tile_size.x * 0.5
	var screen_y: float = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset - Vector2(0.0, fixture_lift)

func _draw_circle_outline(pos: Vector2, radius: float, color: Color, width: float) -> void:
	# Draw circle outline using arc segments
	var segments: int = 32
	var prev_point: Vector2 = pos + Vector2(radius, 0)
	
	for i in range(1, segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		var point: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius
		draw_line(prev_point, point, color, width)
		prev_point = point

func debug_info() -> String:
	var total_lights = all_lights.size()
	var animated_lights = 0
	var flickering = 0
	var pulsing = 0
	var rotating = 0
	
	for light in all_lights:
		if light.flicker_enabled or light.pulse_enabled or light.rotation_speed != 0.0:
			animated_lights += 1
		if light.flicker_enabled:
			flickering += 1
		if light.pulse_enabled:
			pulsing += 1
		if light.rotation_speed != 0.0:
			rotating += 1
	
	return "[TemporalOverlay total=%d animated=%d flicker=%d pulse=%d rotate=%d]" % [
		total_lights,
		animated_lights,
		flickering,
		pulsing,
		rotating
	]
