extends Node2D
class_name FogOfWarOverlay
## Segment-scoped fog of war.
## All tiles start hidden; revealed progressively as the agent explores.
## Uses _draw() to paint isometric diamonds over every unrevealed cell.
## Revealed state persists for the lifetime of the segment (not re-fogged on leave).

const TILE_HALF_W := 128.0
const TILE_HALF_H :=  64.0

## Semi-opaque dark colour that hides unrevealed terrain.
const FOG_COLOR := Color(0.04, 0.04, 0.09, 0.93)

var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2    = Vector2.ZERO
var _room_size: Vector2i       = Vector2i.ZERO

## Cells that have been revealed at least once (key = Vector2i, value = true).
var _revealed: Dictionary = {}


## Call once from room.gd _ready, after layout is built.
func setup(floor_layer: TileMapLayer, visual_offset: Vector2, room_size: Vector2i) -> void:
	_floor_layer  = floor_layer
	_visual_offset = visual_offset
	_room_size    = room_size
	_revealed.clear()
	queue_redraw()


## Reveal every tile within Euclidean distance `radius` of `center`.
## Euclidean gives a disc in tile-space that projects to a rounded ellipse on screen.
func reveal_around(center: Vector2i, radius: int) -> void:
	var r2 := radius * radius
	var changed := false
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cell := center + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= _room_size.x or cell.y >= _room_size.y:
				continue
			if not _revealed.has(cell):
				_revealed[cell] = true
				changed = true
	if changed:
		queue_redraw()


## Erase all revealed state (e.g. when loading a new segment).
func reset_fog() -> void:
	_revealed.clear()
	queue_redraw()


## Returns the alpha to use when drawing an unrevealed cell, based on the
## Chebyshev ring distance to the nearest revealed neighbour.
## 9 rings at 10 % increments (10 → 90 %), ring 10+ = 100 %.
## Very smooth 9-tile stepped gradient at the FOW boundary.
func _fog_alpha_for(cell: Vector2i) -> float:
	for ring: int in range(1, 10):
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) == ring:
					if _revealed.has(cell + Vector2i(dx, dy)):
						return FOG_COLOR.a * (float(ring) * 0.10)
	return FOG_COLOR.a


func _draw() -> void:
	if _floor_layer == null:
		return
	for x: int in range(_room_size.x):
		for y: int in range(_room_size.y):
			var cell := Vector2i(x, y)
			if _revealed.has(cell):
				continue
			## map_to_local returns the top vertex; add TILE_HALF_H to get the centre.
			var centre: Vector2 = (
				_floor_layer.map_to_local(cell)
				+ Vector2(0.0, TILE_HALF_H)
				+ _visual_offset
			)
			var pts := PackedVector2Array([
				centre + Vector2(        0.0, -TILE_HALF_H),   ## top
				centre + Vector2( TILE_HALF_W,         0.0),   ## right
				centre + Vector2(        0.0,  TILE_HALF_H),   ## bottom
				centre + Vector2(-TILE_HALF_W,         0.0),   ## left
			])
			var alpha  := _fog_alpha_for(cell)
			var colour := Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, alpha)
			draw_polygon(pts, PackedColorArray([colour]))
