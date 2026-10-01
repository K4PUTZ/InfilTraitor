## GroundGrid — the game's isometric cell lattice as closed-form maths, with no TileMapLayer in it.
##
## RENDER3D R3D-5a. Until now every "which cell is here" and "where is this cell" went through
## `floor_layer.map_to_local()` / `local_to_map()`: a floor TileMapLayer was being asked a question that
## has one answer, fixed by the TileSet's 256×128 diamond. That kept a 2D tilemap in the middle of INPUT and
## of every actor's placement, which is what R3D-5 exists to remove. This is the same lattice, measured
## rather than assumed (2026-09-18, `tileset_blocks.tres`, tile_shape ISOMETRIC, layout DIAMOND_DOWN):
##
##     map_to_local(c) = ((c.x − c.y) · 128 + 128, (c.x + c.y) · 64 + 64)
##
## and `ground_grid_selftest` asserts it against a REAL TileMapLayer on the game's own TileSet, for a range
## of cells and for random points, so this can never quietly disagree with the tilemap it replaces.
##
## Coordinates here are FLOOR-LAYER-LOCAL, exactly as `map_to_local()` returns them; the caller applies the
## layer's transform and the room's `VISUAL_GRID_OFFSET`, as it always did.
class_name GroundGrid
extends RefCounted

const HALF_W: float = 128.0
const HALF_H: float = 64.0

## R3D-ROT-1 — THE VIEW. The world is one grid in BASE (north) coordinates and never re-lays itself out; a view
## is only a quarter turn of that grid about the map, applied here and nowhere else. Every cell this class takes
## or returns is a BASE cell; `view_cell()` / `base_cell()` are the two halves of the turn, for the few callers that
## need the lattice's own (view) coordinates. "N" is the identity, so a map that never rotates pays one string
## compare. The quarter turn is `PerspectiveMapper`'s (one table, never a second), and `base_size` is the BASE
## room size, set once per map load by `Room`.
static var _view_direction: String = "N"
static var _view_base_size: Vector2i = Vector2i.ZERO


## Point the lattice at `direction` ("N"/"E"/"S"/"W") for a map of `base_size` cells (base orientation).
static func set_view(direction: String, base_size: Vector2i) -> void:
	_view_direction = direction if PerspectiveMapper.is_valid_direction(direction) else "N"
	_view_base_size = base_size


static func view_direction() -> String:
	return _view_direction


## Base cell -> the cell the lattice sees it at, under the active view.
static func view_cell(base: Vector2i) -> Vector2i:
	if _view_direction == "N":
		return base
	return PerspectiveMapper.turn_from_base(base, _view_direction, _view_base_size)


## The inverse of `view_cell()`.
static func base_cell(view: Vector2i) -> Vector2i:
	if _view_direction == "N":
		return view
	return PerspectiveMapper.turn_to_base(view, _view_direction, _view_base_size)


## Where the tilemap puts cell `cell`: identical to `TileMapLayer.map_to_local(cell)` of its VIEW cell.
static func map_to_local(cell: Vector2i) -> Vector2:
	return lattice_local(view_cell(cell))


## The raw N lattice: `map_to_local()` of a VIEW cell, no turn. What a view-independent measurement (the 3D board's
## 2D -> ground affine) asks, because it composes the turn itself, in continuous coordinates.
static func lattice_local(view: Vector2i) -> Vector2:
	return Vector2(float(view.x - view.y) * HALF_W + HALF_W, float(view.x + view.y) * HALF_H + HALF_H)


## The turn on CONTINUOUS board coordinates (a cell `c` spans `[c, c + 1)`, its centre `c + 0.5`): a base point to the
## point the view lattice sees it at. The integer turn is `c -> turn(c)`, so a continuous point turns about the cell
## CENTRES, never about the integer corners (which would land half a cell off along one axis).
static func view_point(base: Vector2) -> Vector2:
	if _view_direction == "N":
		return base
	var q: Vector2 = base - Vector2(0.5, 0.5)
	var w: float = float(_view_base_size.x)
	var h: float = float(_view_base_size.y)
	match _view_direction:
		"E":
			return Vector2(h - 1.0 - q.y, q.x) + Vector2(0.5, 0.5)
		"S":
			return Vector2(w - 1.0 - q.x, h - 1.0 - q.y) + Vector2(0.5, 0.5)
		"W":
			return Vector2(q.y, w - 1.0 - q.x) + Vector2(0.5, 0.5)
	return base


## The inverse of `view_point()`.
static func base_point(view: Vector2) -> Vector2:
	if _view_direction == "N":
		return view
	var q: Vector2 = view - Vector2(0.5, 0.5)
	var w: float = float(_view_base_size.x)
	var h: float = float(_view_base_size.y)
	match _view_direction:
		"E":
			return Vector2(q.y, h - 1.0 - q.x) + Vector2(0.5, 0.5)
		"S":
			return Vector2(w - 1.0 - q.x, h - 1.0 - q.y) + Vector2(0.5, 0.5)
		"W":
			return Vector2(w - 1.0 - q.y, q.x) + Vector2(0.5, 0.5)
	return view


## The cell whose diamond CONTAINS `local` — the cell centre is `map_to_local(cell) + (0, HALF_H)` in the
## game's own convention (see Room._screen_to_tile). A point on a shared edge goes to the higher cell.
static func cell_containing(local: Vector2) -> Vector2i:
	return cell_containing_with_offset(local, Vector2.ZERO)


## As `cell_containing`, for a lattice shifted by `offset` (the room's `VISUAL_GRID_OFFSET`).
static func cell_containing_with_offset(local: Vector2, offset: Vector2) -> Vector2i:
	## Centre of cell (0, 0) in this convention, then solve x − y = u, x + y = v.
	## The lattice's own origin (view cell (0, 0)), never `map_to_local(ZERO)`, which a view turns.
	var d: Vector2 = local - (Vector2(HALF_W, HALF_H) + Vector2(0.0, HALF_H) + offset)
	var u: float = d.x / HALF_W
	var v: float = d.y / HALF_H
	return base_cell(Vector2i(floori((u + v) * 0.5 + 0.5), floori((v - u) * 0.5 + 0.5)))


## R3D-11 — the ground's extent. The room builder fills EVERY cell of `[0, size)` with the one walkable floor tile and
## nothing else, so "the map has a floor here, and it is walkable" is exactly "the cell is inside the rectangle". This
## is the grid authority gameplay asks instead of reading a TileMapLayer's tile data.
static func has_cell(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The cell's centre in the game's convention.
static func cell_center(cell: Vector2i, offset: Vector2) -> Vector2:
	return map_to_local(cell) + Vector2(0.0, HALF_H) + offset
