extends Node2D
## Draws a pink diamond outline on the currently selected tile.
## Lives in world space as a sibling of FloorLayer — no camera or UI involved.

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var _cell: Vector2i = Vector2i(-9999, -9999)

const COLOR_PINK := Color(0.90, 0.10, 0.45, 1.0)
const LINE_W := 4.0


func set_selected(cell: Vector2i) -> void:
	_cell = cell
	queue_redraw()


func clear_selected() -> void:
	_cell = Vector2i(-9999, -9999)
	queue_redraw()


func _draw() -> void:
	if floor_layer == null:
		return
	if _cell == Vector2i(-9999, -9999):
		return

	## map_to_local returns the TOP vertex of the DIAMOND_DOWN diamond.
	## Tile size 256×128 → half-width = 128, half-height = 64.
	var top := floor_layer.map_to_local(_cell) + visual_offset
	var right := top + Vector2(128.0, 64.0)
	var bottom := top + Vector2(0.0, 128.0)
	var left := top + Vector2(-128.0, 64.0)

	draw_line(top, right, COLOR_PINK, LINE_W)
	draw_line(right, bottom, COLOR_PINK, LINE_W)
	draw_line(bottom, left, COLOR_PINK, LINE_W)
	draw_line(left, top, COLOR_PINK, LINE_W)