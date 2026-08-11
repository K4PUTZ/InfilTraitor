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

## T-FILL (Director, 2026-08-10): "assim como no Phoenix Point, vamos realçar as
## GUs afetadas pela granada, para indicar quais inimigos vão ser atingidos",
## then, on the first attempt at it: "vamos tirar a hachura do chão e pintar o
## interior do perímetro de vermelho com opacidades variadas, usando o mesmo
## mecanismo visual que estamos usando para indicar o perímetro de movimentação
## do agente."
##
## That mechanism is MovementOverlay's — a flat `draw_colored_polygon` per cell
## diamond under the perimeter lines, with alpha carrying the grading. Here the
## grade is by blast ring instead of by AP cost, which is the same idea said in
## the grenade's units: the closer to the epicentre, the denser the red.
##
## OFF unless a caller passes ring data, so the two pre-existing callers (the
## grenade context menu and the weapon bench) keep the plain outline they were
## written for.
var ring_fill_alphas: PackedFloat32Array = PackedFloat32Array([0.34, 0.22, 0.13])

var _floor_layer: TileMapLayer = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _footprint: Dictionary = {}  ## Vector2i -> true, membership test only
var _ring_by_cell: Dictionary = {}  ## Vector2i -> int, empty when unfilled


func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_grid_offset = visual_grid_offset


## cells: any Array/iterable of Vector2i (e.g. BlastCalculator.flood_gu_rings()'s
## keys()) — the whole max-range footprint, regardless of ring.
## `ring_by_cell` is optional: pass flood_gu_rings()' own {Vector2i -> ring}
## output to get the graded fill, or leave it out for the bare outline.
func show_footprint(cells, ring_by_cell: Dictionary = {}) -> void:
	_footprint.clear()
	for c in cells:
		_footprint[c] = true
	_ring_by_cell = ring_by_cell
	queue_redraw()


func clear() -> void:
	if _footprint.is_empty():
		return
	_footprint.clear()
	_ring_by_cell = {}
	queue_redraw()


func _draw() -> void:
	if _floor_layer == null or _footprint.is_empty():
		return
	## Fills first, so the perimeter still reads as the boundary on top of them —
	## the same order MovementOverlay._draw() uses.
	for cell in _ring_by_cell.keys():
		var ring: int = int(_ring_by_cell[cell])
		if ring < 0 or ring >= ring_fill_alphas.size():
			continue
		var fill := LINE_COLOR
		fill.a = ring_fill_alphas[ring]
		draw_colored_polygon(_diamond_points(cell), fill)
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


## The cell's full diamond, un-inset — the fill has to meet its neighbours or
## the graded area reads as loose tiles instead of one region. Copied in shape
## from MovementOverlay._diamond_points() for the same reason the inset version
## below was: that one is already proven correct in this codebase.
func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := _floor_layer.map_to_local(cell) + _visual_grid_offset
	return PackedVector2Array([
		top,
		top + Vector2(128.0, 64.0),
		top + Vector2(0.0, 128.0),
		top + Vector2(-128.0, 64.0),
	])


func _diamond_points_inset(cell: Vector2i) -> PackedVector2Array:
	var center := _floor_layer.map_to_local(cell) + _visual_grid_offset + Vector2(0.0, 64.0)
	var scale_factor := 1.0 - (PERIMETER_INSET_DISTANCE / 128.0)
	return PackedVector2Array([
		center + Vector2(0.0, -64.0) * scale_factor,
		center + Vector2(128.0, 0.0) * scale_factor,
		center + Vector2(0.0, 64.0) * scale_factor,
		center + Vector2(-128.0, 0.0) * scale_factor,
	])
