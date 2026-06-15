## HeightOverlay — DEV visualization of height classes and structural semantics
##
## Displays:
## - Height classes (FLOOR, LOW_COVER, HUMAN, TALL, OVERHEAD)
## - Structural categories
## - Occluders and light blockers
## - Light anchor sockets
## - Subfloor hazards
##
## Color coding makes semantic information immediately readable.
## Shows the "worldbuilding reality" independent of sprite appearance.

extends Node2D

const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const LightAnchorClass = preload("res://godot/scripts/systems/lighting/light_anchor.gd")

## References
var tile_semantics_map: Dictionary = {}   ## cell → TileSemantics
var light_anchors: Array = []             ## LightAnchor instances
var floor_layer: TileMapLayer = null
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

## Color palette for height classes
var height_colors := {
	0: Color(0.8, 0.7, 0.6, 0.6),           # Tan (FLOOR)
	1: Color(0.6, 0.8, 0.6, 0.6),           # Light green (LOW_COVER)
	2: Color(0.7, 0.7, 1.0, 0.6),           # Light blue (HUMAN)
	3: Color(0.9, 0.6, 0.6, 0.6),           # Light red (TALL)
	4: Color(0.8, 0.6, 0.9, 0.6),           # Light purple (OVERHEAD)
}

## Color palette for structural types
var struct_colors := {
	TileSemanticsClass.STRUCT_FLOOR: Color(0.9, 0.8, 0.7, 0.5),
	TileSemanticsClass.STRUCT_LOW_COVER: Color(0.5, 0.9, 0.5, 0.5),
	TileSemanticsClass.STRUCT_WALL: Color(0.8, 0.4, 0.4, 0.5),
	TileSemanticsClass.STRUCT_TALL: Color(0.9, 0.5, 0.4, 0.5),
	TileSemanticsClass.STRUCT_OVERHEAD: Color(0.7, 0.6, 0.9, 0.5),
}

## Visualization mode
var show_height: bool = true
var show_structural: bool = false
var show_blockers: bool = true
var show_anchors: bool = true

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

func toggle_mode(mode: String) -> void:
	match mode:
		"height":
			show_height = not show_height
			show_structural = false
		"structural":
			show_structural = not show_structural
			show_height = false
		"blockers":
			show_blockers = not show_blockers
		"anchors":
			show_anchors = not show_anchors

func load_semantics(semantics_map: Dictionary) -> void:
	tile_semantics_map = semantics_map

func load_anchors(anchors: Array) -> void:
	light_anchors = anchors

## ============================================================================
## Visualization
## ============================================================================

func _draw() -> void:
	if tile_semantics_map.is_empty():
		return
	
	# Draw height classes or structural types
	if show_height:
		_draw_height_grid()
	elif show_structural:
		_draw_structural_grid()
	
	# Draw blockers and special markers
	if show_blockers:
		_draw_blockers()
	
	# Draw light anchor sockets
	if show_anchors:
		_draw_anchors()

## Draw all tiles colored by height class
func _draw_height_grid() -> void:
	for cell in tile_semantics_map.keys():
		var semantics = tile_semantics_map[cell]
		var color = height_colors.get(semantics.height_class, Color.GRAY)
		_draw_tile_rect(cell, color)
		_draw_height_label(cell, semantics.height_class)

## Draw all tiles colored by structural type
func _draw_structural_grid() -> void:
	for cell in tile_semantics_map.keys():
		var semantics = tile_semantics_map[cell]
		var color = struct_colors.get(semantics.structural_type, Color.GRAY)
		_draw_tile_rect(cell, color)
		_draw_struct_label(cell, semantics.structural_type)

## Draw light/LOS blockers with distinctive markers
func _draw_blockers() -> void:
	for cell in tile_semantics_map.keys():
		var semantics = tile_semantics_map[cell]
		
		if semantics.blocks_los:
			# LOS blocker: red X in corner
			var screen_pos = _cell_to_screen(cell)
			draw_line(
				screen_pos,
				screen_pos + Vector2(20, 20),
				Color.RED, 2.0
			)
			draw_line(
				screen_pos + Vector2(20, 0),
				screen_pos + Vector2(0, 20),
				Color.RED, 2.0
			)
		
		if semantics.blocks_light:
			# Light blocker: yellow border
			var screen_pos = _cell_to_screen(cell)
			draw_rect(
				Rect2(screen_pos, tile_size),
				Color.TRANSPARENT,
				false,
				3.0
			)
			draw_set_transform(screen_pos, 0.0, Vector2.ONE)
			draw_rect(Rect2(Vector2.ZERO, tile_size), Color.TRANSPARENT, false, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Draw light anchor sockets
func _draw_anchors() -> void:
	for anchor in light_anchors:
		var screen_pos = _cell_to_screen(anchor.anchor_cell)
		var center = screen_pos
		
		# Draw anchor symbol based on type
		match anchor.anchor_type:
			LightAnchorClass.TYPE_CEILING:
				# Circle at top
				draw_circle(center - Vector2(0, tile_size.y * 0.3), 8.0, Color.YELLOW)
			
			LightAnchorClass.TYPE_WALL:
				# Square on side
				draw_rect(Rect2(center - Vector2(10, 5), Vector2(20, 10)), Color.YELLOW)
			
			LightAnchorClass.TYPE_FLOOR:
				# Circle at bottom
				draw_circle(center + Vector2(0, tile_size.y * 0.3), 8.0, Color.YELLOW)
			
			LightAnchorClass.TYPE_COLUMN:
				# Double circle
				draw_circle(center, 10.0, Color.YELLOW)
				draw_circle(center, 6.0, Color.YELLOW)
			
			LightAnchorClass.TYPE_SPOTLIGHT:
				# Triangle (directional)
				draw_circle(center, 8.0, Color.ORANGE)
				_draw_direction_arrow(center, anchor.emission_direction, Color.ORANGE)
		
		# Draw radius indicator (faint circle)
		draw_circle(center, float(anchor.light_radius) * 32.0, Color(1, 1, 0, 0.1))

## ============================================================================
## Helper Drawing Methods
## ============================================================================

func _draw_tile_rect(cell: Vector2i, color: Color) -> void:
	var screen_pos = _cell_to_screen(cell)
	var half_w = tile_size.x * 0.5
	var half_h = tile_size.y * 0.5
	var points = PackedVector2Array([
		screen_pos + Vector2(half_w, 0.0),
		screen_pos + Vector2(0.0, half_h),
		screen_pos + Vector2(-half_w, 0.0),
		screen_pos + Vector2(0.0, -half_h),
	])
	draw_colored_polygon(points, color)

func _draw_height_label(cell: Vector2i, height_class: int) -> void:
	var screen_pos = _cell_to_screen(cell)
	var label = TileSemanticsClass.HEIGHT_NAMES.get(height_class, "?")
	draw_string(
		ThemeDB.fallback_font,
		screen_pos,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		ThemeDB.fallback_font_size,
		Color.BLACK
	)

func _draw_struct_label(cell: Vector2i, struct_type: String) -> void:
	var screen_pos = _cell_to_screen(cell)
	var label = TileSemanticsClass.STRUCT_NAMES.get(struct_type, "?")
	draw_string(
		ThemeDB.fallback_font,
		screen_pos,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		ThemeDB.fallback_font_size,
		Color.BLACK
	)

func _draw_direction_arrow(center: Vector2, direction: Vector2i, color: Color) -> void:
	var dir_vec = Vector2(direction)
	var arrow_tip = center + dir_vec.normalized() * 20.0
	draw_line(center, arrow_tip, color, 2.0)

## ============================================================================
## Coordinate Conversion
## ============================================================================

func _cell_to_screen(cell: Vector2i) -> Vector2:
	if floor_layer != null:
		return floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + visual_offset
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset

## ============================================================================
## Debugging
## ============================================================================

func _to_string() -> String:
	return "HeightOverlay: [visible=%s, semantics:%d, anchors:%d]" % [
		visible, 
		tile_semantics_map.size(),
		light_anchors.size()
	]
