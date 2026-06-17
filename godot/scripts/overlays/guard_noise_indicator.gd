extends Node2D
## Floating sound indicators: shows the direction of a guard's noise without revealing the exact position.
## Renders "(((" / ")))" floating around the agent, fading out.

## Color for low intensity (< 0.5)
const COLOR_LOW := Color(0.95, 0.65, 0.2, 1.0)   ## yellow-orange
## Color for high intensity (>= 0.5)
const COLOR_HIGH := Color(0.95, 0.3, 0.15, 1.0)  ## orange

const FONT_SIZE := 24
const INDICATOR_RADIUS := 120.0        ## orbit radius around the agent
const INDICATOR_FLOAT_DIST := 40.0     ## vertical movement distance
const INDICATOR_DURATION := 1.8        ## lifetime in seconds

var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO
var _indicators: Array[Dictionary] = []


func setup(floor_layer: TileMapLayer, visual_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_offset = visual_offset
	z_index = 100  ## Above movement_overlay


func add_indicator(agent_world_pos: Vector2, noise_world_pos: Vector2, intensity: float) -> void:
	"""
	Adds a sound indicator.

	:param agent_world_pos: Agent position in world space
	:param noise_world_pos: Noise position in world space (approximate, with offset)
	:param intensity: Noise intensity (0.0 to 1.0)
	"""
	var dir := (noise_world_pos - agent_world_pos).normalized()
	_indicators.append({
		"dir": dir,
		"intensity": intensity,
		"timer": INDICATOR_DURATION,
		"offset": 0.0,
	})
	queue_redraw()


func _process(delta: float) -> void:
	if _indicators.is_empty():
		return
	
	var expired: Array = []
	for ind in _indicators:
		ind["timer"] -= delta
		ind["offset"] = (1.0 - (ind["timer"] / INDICATOR_DURATION)) * INDICATOR_FLOAT_DIST
		if ind["timer"] <= 0.0:
			expired.append(ind)
	
	for ind in expired:
		_indicators.erase(ind)
	
	if expired.size() > 0:
		queue_redraw()


func _draw() -> void:
	if _indicators.is_empty():
		return
	
	for ind in _indicators:
		var t     := clampf(1.0 - (ind["timer"] / INDICATOR_DURATION), 0.0, 1.0)
		var alpha := 1.0 - (t * t)   ## quadratic fade out
		var pos: Vector2 = ind["dir"] * INDICATOR_RADIUS + Vector2(0.0, -ind["offset"])
		var color: Color = COLOR_HIGH if ind["intensity"] >= 0.5 else COLOR_LOW
		color.a = alpha
		
		## Symbol: "(((" or ")))" depending on horizontal direction
		var symbol := ")))" if ind["dir"].x >= 0.0 else "((("
		draw_string(
			ThemeDB.fallback_font,
			pos,
			symbol,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			FONT_SIZE,
			color
		)
