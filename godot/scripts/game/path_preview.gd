extends Node2D
class_name PathPreview
## Visual preview of the currently hovered movement path.

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var _cells: Array[Vector2i] = []
var _ap_cost: int = 0

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
const PREVIEW_LINE := Color(1.0, 0.79, 0.18, 0.95)
const PREVIEW_FILL := Color(1.0, 0.76, 0.20, 0.22)
const TARGET_LINE := Color(1.0, 0.45, 0.10, 0.95)


func setup(tile_layer: TileMapLayer, offset: Vector2) -> void:
	floor_layer = tile_layer
	visual_offset = offset


func set_path(cells: Array[Vector2i], ap_cost: int) -> void:
	_cells = cells.duplicate()
	_ap_cost = ap_cost
	queue_redraw()


func clear_path() -> void:
	if _cells.is_empty() and _ap_cost == 0:
		return
	_cells.clear()
	_ap_cost = 0
	queue_redraw()


func _draw() -> void:
	if floor_layer == null or _cells.size() < 2:
		return

	var centers := PackedVector2Array()
	for cell in _cells:
		centers.append(_cell_to_center(cell))
		draw_colored_polygon(_diamond_points(cell), PREVIEW_FILL)

	draw_polyline(centers, PREVIEW_LINE, 6.0, true)

	var target := _diamond_points(_cells.back())
	draw_polyline(target + PackedVector2Array([target[0]]), TARGET_LINE, 3.0, true)


func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := floor_layer.map_to_local(cell) + visual_offset
	return PackedVector2Array([
		top,
		top + Vector2(128.0, 64.0),
		top + Vector2(0.0, 128.0),
		top + Vector2(-128.0, 64.0),
	])


func _cell_to_center(cell: Vector2i) -> Vector2:
	return floor_layer.map_to_local(cell) + TILE_CENTER_OFFSET + visual_offset