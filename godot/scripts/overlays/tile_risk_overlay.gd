## TileRiskOverlay — Tactical Threat Heatmap Visualization
##
## Displays per-tile risk/threat assessment based on tactical exposure.
## Shows detection probability heatmap (red = danger, blue = safe).
##
## Color gradient: Blue (safe) → Green → Yellow → Orange → Red (danger)

extends Node2D

## References
var exposure_system
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

## Risk color gradient (Blue → Red)
var _risk_gradient := [
	Color(0.0, 0.0, 1.0, 0.5),      # Blue: 0.0 risk (deep shadow)
	Color(0.0, 1.0, 1.0, 0.5),      # Cyan: 0.2 risk
	Color(0.0, 1.0, 0.0, 0.5),      # Green: 0.4 risk
	Color(1.0, 1.0, 0.0, 0.5),      # Yellow: 0.6 risk
	Color(1.0, 0.5, 0.0, 0.5),      # Orange: 0.8 risk
	Color(1.0, 0.0, 0.0, 0.5),      # Red: 1.0 risk (full light)
]

## ============================================================================
## Lifecycle
## ============================================================================

func _ready() -> void:
	set_visibility_layer(20)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

## ============================================================================
## Control Interface
## ============================================================================

func set_dev_vision(enabled: bool) -> void:
	visible = enabled

## ============================================================================
## Visualization
## ============================================================================

func _draw() -> void:
	if not exposure_system:
		return
	
	# Draw all tiles by risk (no guard; loop+check handles empty grid)
	# Iterate over approximate room bounds
	for x in range(-5, 50):  # Approximate room coverage
		for y in range(-5, 50):
			var cell = Vector2i(x, y)
			var risk = exposure_system.get_tile_risk(cell)
			if risk > 0.0:  # Only draw if not completely safe
				_draw_risk_tile(cell, risk)

## Draw a single tile with risk color based on detection multiplier.
func _draw_risk_tile(cell: Vector2i, risk: float) -> void:
	var screen_pos = _cell_to_screen(cell)
	var color = _get_risk_color(risk)
	
	# Draw filled rectangle
	var rect = Rect2(screen_pos, tile_size)
	draw_rect(rect, color)

## Get color from risk value (0.0-1.0).
func _get_risk_color(risk: float) -> Color:
	# Clamp risk to 0-1
	var clamped = clampf(risk, 0.0, 1.0)
	
	# Map to gradient array index
	var gradient_index = clamped * (float(_risk_gradient.size()) - 1.0)
	var lower_idx = int(gradient_index)
	var upper_idx = mini(lower_idx + 1, _risk_gradient.size() - 1)
	var blend = fmod(gradient_index, 1.0)
	
	# Interpolate between colors
	var color_low = _risk_gradient[lower_idx]
	var color_high = _risk_gradient[upper_idx]
	
	return color_low.lerp(color_high, blend)

## Convert grid cell to screen position (isometric projection).
func _cell_to_screen(cell: Vector2i) -> Vector2:
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset

## ============================================================================
## Debugging
## ============================================================================

func _to_string() -> String:
	if exposure_system:
		return "TileRiskOverlay: [visible=%s]" % [visible]
	return "TileRiskOverlay: [no exposure system]"
