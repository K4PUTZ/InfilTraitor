extends Node2D
## BlastWireframeOverlay — DESTRUCTION_MASTER_PLAN Part 3 blast-radius
## preview. Shown while a grenade's context menu is open: a red outline
## around the OUTER perimeter of the max-range GU footprint (Director, this
## session: only the outer boundary, not per-ring opacity).
##
## Deliberately its own file, not folded into MovementOverlay: that overlay
## owns player-turn AP-zone state (highlighted AP, blue/orange per-cost
## fill) with no meaning here — the only shared surface is the diamond-draw
## math below, reused verbatim rather than re-derived.
##
## Diamond corner math and the "only draw an edge if the neighbor is NOT in
## the same set" perimeter rule are copied from movement_overlay.gd's
## _diamond_points_inset()/_should_draw_edge() — both already proven correct
## in this codebase. Do NOT reuse the OTHER approach (a per-voxel line
## family filtered down to boundary-only lines, as voxel_ruler_overlay.gd
## uses for its dense debug grid): that approach visibly failed when tried
## for gu_grid_overlay.gd on 2026-07-22 — extra lines crossed through the
## middle of each cell instead of closing cleanly. See gu_grid_overlay.gd's
## own header for the same warning.
class_name BlastWireframeOverlay

const LINE_COLOR := Color(1.0, 0.15, 0.15, 0.9)
const LINE_WIDTH := 3.0
const PERIMETER_INSET_DISTANCE := 6.0  ## reused verbatim from movement_overlay.gd

var _floor_layer: TileMapLayer = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _footprint: Dictionary = {}  ## Vector2i -> true, membership test only


func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_grid_offset = visual_grid_offset


## cells: any Array/iterable of Vector2i (e.g. BlastCalculator.flood_gu_rings()'s
## keys()) — the whole max-range footprint, regardless of ring.
func show_footprint(cells) -> void:
	_footprint.clear()
	for c in cells:
		_footprint[c] = true
	queue_redraw()


func clear() -> void:
	if _footprint.is_empty():
		return
	_footprint.clear()
	queue_redraw()


func _draw() -> void:
	if _floor_layer == null or _footprint.is_empty():
		return
	for cell in _footprint.keys():
		var diamond := _diamond_points_inset(cell)
		if not _footprint.has(cell + Vector2i.UP):
			draw_line(diamond[0], diamond[1], LINE_COLOR, LINE_WIDTH, true)
		if not _footprint.has(cell + Vector2i.RIGHT):
			draw_line(diamond[1], diamond[2], LINE_COLOR, LINE_WIDTH, true)
		if not _footprint.has(cell + Vector2i.DOWN):
			draw_line(diamond[2], diamond[3], LINE_COLOR, LINE_WIDTH, true)
		if not _footprint.has(cell + Vector2i.LEFT):
			draw_line(diamond[3], diamond[0], LINE_COLOR, LINE_WIDTH, true)


func _diamond_points_inset(cell: Vector2i) -> PackedVector2Array:
	var center := _floor_layer.map_to_local(cell) + _visual_grid_offset + Vector2(0.0, 64.0)
	var scale_factor := 1.0 - (PERIMETER_INSET_DISTANCE / 128.0)
	return PackedVector2Array([
		center + Vector2(0.0, -64.0) * scale_factor,
		center + Vector2(128.0, 0.0) * scale_factor,
		center + Vector2(0.0, 64.0) * scale_factor,
		center + Vector2(-128.0, 0.0) * scale_factor,
	])
