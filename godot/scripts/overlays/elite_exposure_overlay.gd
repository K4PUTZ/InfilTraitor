## EliteExposureOverlay — Advanced Tactical Vision for Stealth Mastery
##
## Displays sophisticated shadow semantics:
## - Shadow depth (gradient 0-6)
## - Exposure confidence (reliability of darkness)
## - Structural vs temporal shadows
## - Risk contours and safe corridors
## - Temporal instability zones
##
## NOT visible in normal gameplay. Appears in:
## - DEV_VISION overlay
## - Spectator modes
## - Future elite HUD (equipment unlock)
##
## Purpose: Enable high-skill stealth mastery and tactical reading.

extends Node2D

const ExposureSystemClass = preload("res://godot/scripts/systems/lighting/exposure_system.gd")

# Color palettes for elite vision
var depth_gradient: Dictionary = {
	5: Color.RED,              # FULL_LIT (danger)
	4: Color.ORANGE,           # DIM
	3: Color.YELLOW,           # PENUMBRA
	2: Color.GREEN,            # SHADOW
	1: Color.CYAN,             # DEEP_SHADOW
	0: Color.BLUE,             # OCCLUDED_VOID (extreme stealth)
}

var stability_colors: Dictionary = {
	"static": Color.LIGHT_GREEN,     # Structural: reliable
	"temporal": Color.YELLOW,        # Flicker: unreliable
	"dynamic": Color.ORANGE,         # Moving: temporary
	"occluded": Color.BLUE,          # Structural void: ultimate
}

var confidence_gradient_low: Color = Color.RED          # Low confidence (unreliable)
var confidence_gradient_high: Color = Color.GREEN       # High confidence (reliable)

# Visualization modes
var show_depth: bool = true
var show_confidence: bool = true
var show_stability: bool = false
var show_contours: bool = false
var show_risk_zones: bool = false
var show_safe_corridors: bool = false

# Opacity control
var overlay_opacity: float = 0.4

# Reference to exposure system (set externally)
var exposure_system = null

# Tile size and offset (for isometric projection)
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass

func set_dev_vision(enabled: bool) -> void:
	visible = enabled

func load_exposure_system(sys) -> void:
	exposure_system = sys

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not visible or exposure_system == null:
		return
	
	if show_depth:
		_draw_depth_map()
	if show_confidence:
		_draw_confidence_map()
	if show_stability:
		_draw_stability_map()
	if show_contours:
		_draw_risk_contours()
	if show_safe_corridors:
		_draw_safe_corridors()

func _draw_depth_map() -> void:
	# Visualize shadow depth as color gradient
	# Iterate all cells in exposure grid
	var cells_by_depth: Dictionary = {}
	
	# Group cells by depth
	for cell in exposure_system._exposure_grid.keys():
		var depth = exposure_system.get_shadow_depth(cell)
		if depth not in cells_by_depth:
			cells_by_depth[depth] = []
		cells_by_depth[depth].append(cell)
	
	# Draw depth zones
	for depth in cells_by_depth.keys():
		var color = depth_gradient.get(depth, Color.GRAY)
		color.a = overlay_opacity
		
		for cell in cells_by_depth[depth]:
			_draw_tile_rect(cell, color)

func _draw_confidence_map() -> void:
	# Visualize exposure confidence as gradient overlay
	for cell in exposure_system._exposure_grid.keys():
		var confidence = exposure_system.get_exposure_confidence(cell)
		
		# Gradient from red (low confidence) to green (high confidence)
		var color = confidence_gradient_low.lerp(confidence_gradient_high, confidence)
		color.a = overlay_opacity * 0.5  # Lighter overlay
		
		_draw_tile_rect(cell, color)

func _draw_stability_map() -> void:
	# Visualize shadow stability classification
	for cell in exposure_system._exposure_grid.keys():
		var stability = exposure_system.get_shadow_stability(cell)
		var color = stability_colors.get(stability, Color.GRAY)
		color.a = overlay_opacity
		
		_draw_tile_rect(cell, color)

func _draw_risk_contours() -> void:
	# Draw lines separating different risk zones
	# Uses simple grid-based contours
	
	for cell in exposure_system._exposure_grid.keys():
		var current_depth = exposure_system.get_shadow_depth(cell)
		var screen_pos = _cell_to_screen(cell)
		
		# Check adjacent cells for depth changes
		var neighbors = [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
		]
		
		for neighbor in neighbors:
			if neighbor not in exposure_system._exposure_grid:
				continue
			
			var neighbor_depth = exposure_system.get_shadow_depth(neighbor)
			
			# Draw contour line if depth changes
			if current_depth != neighbor_depth:
				var neighbor_screen_pos = _cell_to_screen(neighbor)
				
				# Color based on risk gradient
				var contour_color = Color.WHITE
				if current_depth > neighbor_depth:
					contour_color = Color.RED  # Entering danger
				else:
					contour_color = Color.GREEN  # Entering safety
				
				draw_line(screen_pos, neighbor_screen_pos, contour_color, 2.0)

func _draw_safe_corridors() -> void:
	# Highlight continuous zones of shadow/deep_shadow
	# Use flood fill to identify safe corridors
	
	var safe_tiles: Array = []
	for cell in exposure_system._exposure_grid.keys():
		var depth = exposure_system.get_shadow_depth(cell)
		if depth <= 1:  # DEEP_SHADOW or OCCLUDED_VOID
			safe_tiles.append(cell)
	
	# Draw safe corridor indicators
	for cell in safe_tiles:
		var screen_pos = _cell_to_screen(cell)
		var color = Color.GREEN
		color.a = 0.6
		
		draw_circle(screen_pos, 8.0, color)

func toggle_mode(mode: String) -> void:
	match mode:
		"depth":
			show_depth = not show_depth
		"confidence":
			show_confidence = not show_confidence
		"stability":
			show_stability = not show_stability
		"contours":
			show_contours = not show_contours
		"corridors":
			show_safe_corridors = not show_safe_corridors

func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Isometric projection: (x-y)*256/2, (x+y)*128/2
	var x: float = float(cell.x)
	var y: float = float(cell.y)
	var screen_x: float = (x - y) * tile_size.x * 0.5
	var screen_y: float = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset

func _draw_tile_rect(cell: Vector2i, color: Color) -> void:
	var screen_pos = _cell_to_screen(cell)
	
	# Draw isometric tile
	# Tile is 256x128 in screen space
	var half_w = tile_size.x * 0.5
	var half_h = tile_size.y * 0.5
	
	var points = PackedVector2Array([
		screen_pos + Vector2(half_w, 0),      # Right
		screen_pos + Vector2(0, half_h),      # Bottom
		screen_pos + Vector2(-half_w, 0),     # Left
		screen_pos + Vector2(0, -half_h),     # Top
	])
	
	draw_colored_polygon(points, color)

func debug_info() -> String:
	var safe_count = exposure_system.get_structurally_hidden_tiles().size()
	var total_count = exposure_system._exposure_grid.size()
	var confidence_avg = 0.0
	
	for confidence in exposure_system._exposure_confidence.values():
		confidence_avg += confidence
	
	if exposure_system._exposure_confidence.size() > 0:
		confidence_avg /= float(exposure_system._exposure_confidence.size())
	
	return "[EliteExposureOverlay safe=%d total=%d confidence=%.2f depth_layers=6 stability_types=4]" % [
		safe_count,
		total_count,
		confidence_avg
	]
