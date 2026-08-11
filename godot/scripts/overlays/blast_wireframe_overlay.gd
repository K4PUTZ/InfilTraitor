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

## T-HATCH (Director, 2026-08-10): "assim como no Phoenix Point, vamos realçar
## as GUs afetadas pela granada, para indicar quais inimigos vão ser atingidos.
## Já temos o perímetro vermelho funcionando (...) só precisamos aplicar na base
## da bola e dar mais destaque com as hachuras." Ref. REFERENCES/granade.webp,
## whose target area is a lattice rather than a flat wash.
##
## OFF by default, so the two pre-existing callers (the grenade context menu and
## the weapon bench) keep the plain outline they were written for.
var hatch_color: Color = Color(1.0, 0.28, 0.18, 0.42)
var hatch_width: float = 2.0
## Lines per cell along EACH of the two grid axes. They are placed at the same
## fractions in every cell, so they join into continuous lines across the whole
## footprint instead of stopping at cell borders.
var hatch_lines_per_cell: int = 3

var _floor_layer: TileMapLayer = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _footprint: Dictionary = {}  ## Vector2i -> true, membership test only
var _hatched: bool = false


func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_grid_offset = visual_grid_offset


## cells: any Array/iterable of Vector2i (e.g. BlastCalculator.flood_gu_rings()'s
## keys()) — the whole max-range footprint, regardless of ring.
func show_footprint(cells, hatched: bool = false) -> void:
	_footprint.clear()
	for c in cells:
		_footprint[c] = true
	_hatched = hatched
	queue_redraw()


func clear() -> void:
	if _footprint.is_empty():
		return
	_footprint.clear()
	_hatched = false
	queue_redraw()


func _draw() -> void:
	if _floor_layer == null or _footprint.is_empty():
		return
	if _hatched:
		## Under the outline, so the perimeter still reads as the boundary.
		for cell in _footprint.keys():
			_draw_cell_hatch(cell)
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


## One cell's share of the lattice.
##
## A cell's diamond is exactly {centre + a·AXIS_X + b·AXIS_Y : a,b ∈ [-½,½]} —
## the four corners fall out at (±½,±½), which is why the hatch can be drawn in
## that basis instead of clipping screen-space lines against a polygon. Holding
## `b` fixed and sweeping `a` gives a line parallel to one grid axis; holding
## `a` gives the other. Both families are drawn, which is what makes it a
## lattice rather than stripes.
func _draw_cell_hatch(cell: Vector2i) -> void:
	if hatch_lines_per_cell < 1:
		return
	var centre := _floor_layer.map_to_local(cell) + _visual_grid_offset + Vector2(0.0, 64.0)
	var ax := IsoProjection.AXIS_X
	var ay := IsoProjection.AXIS_Y
	for i: int in range(hatch_lines_per_cell):
		var t: float = (float(i) + 0.5) / float(hatch_lines_per_cell) - 0.5
		draw_line(centre + ax * -0.5 + ay * t, centre + ax * 0.5 + ay * t,
			hatch_color, hatch_width)
		draw_line(centre + ax * t + ay * -0.5, centre + ax * t + ay * 0.5,
			hatch_color, hatch_width)


func _diamond_points_inset(cell: Vector2i) -> PackedVector2Array:
	var center := _floor_layer.map_to_local(cell) + _visual_grid_offset + Vector2(0.0, 64.0)
	var scale_factor := 1.0 - (PERIMETER_INSET_DISTANCE / 128.0)
	return PackedVector2Array([
		center + Vector2(0.0, -64.0) * scale_factor,
		center + Vector2(128.0, 0.0) * scale_factor,
		center + Vector2(0.0, 64.0) * scale_factor,
		center + Vector2(-128.0, 0.0) * scale_factor,
	])
