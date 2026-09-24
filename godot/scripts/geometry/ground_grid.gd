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


## Where the tilemap puts cell `cell`: identical to `TileMapLayer.map_to_local(cell)`.
static func map_to_local(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y) * HALF_W + HALF_W, float(cell.x + cell.y) * HALF_H + HALF_H)


## The cell whose diamond CONTAINS `local` — the cell centre is `map_to_local(cell) + (0, HALF_H)` in the
## game's own convention (see Room._screen_to_tile). A point on a shared edge goes to the higher cell.
static func cell_containing(local: Vector2) -> Vector2i:
	return cell_containing_with_offset(local, Vector2.ZERO)


## As `cell_containing`, for a lattice shifted by `offset` (the room's `VISUAL_GRID_OFFSET`).
static func cell_containing_with_offset(local: Vector2, offset: Vector2) -> Vector2i:
	## Centre of cell (0, 0) in this convention, then solve x − y = u, x + y = v.
	var d: Vector2 = local - (map_to_local(Vector2i.ZERO) + Vector2(0.0, HALF_H) + offset)
	var u: float = d.x / HALF_W
	var v: float = d.y / HALF_H
	return Vector2i(floori((u + v) * 0.5 + 0.5), floori((v - u) * 0.5 + 0.5))


## R3D-11 — the ground's extent. The room builder fills EVERY cell of `[0, size)` with the one walkable floor tile and
## nothing else, so "the map has a floor here, and it is walkable" is exactly "the cell is inside the rectangle". This
## is the grid authority gameplay asks instead of reading a TileMapLayer's tile data.
static func has_cell(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The cell's centre in the game's convention.
static func cell_center(cell: Vector2i, offset: Vector2) -> Vector2:
	return map_to_local(cell) + Vector2(0.0, HALF_H) + offset
