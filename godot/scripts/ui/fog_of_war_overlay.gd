extends Node2D
class_name FogOfWarOverlay
## Segment-scoped fog of war.
## All tiles start hidden; revealed progressively as the agent explores.
## Uses _draw() to paint isometric diamonds over every unrevealed cell.
## Revealed state persists for the lifetime of the segment (not re-fogged on leave).

const TILE_HALF_W := 128.0
const TILE_HALF_H :=  64.0
## Maximum height of wall/block sprites above the tile origin, measured from the
## tallest asset in the blocks-prototype pack (wall_E/S, windows = 158 px).
## This extends the fog hexagon upward so wall faces are fully hidden.
const WALL_HEIGHT_PX := 160.0

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
## Smoothstep ease-in/ease-out over 12 rings: t = ring/12, alpha = t²(3-2t)
##   ring  1 ≈  2 %   ring  5 ≈ 38 %   ring  9 ≈ 84 %
##   ring  2 ≈  7 %   ring  6 = 50 %   ring 10 ≈ 93 %
##   ring  3 ≈ 16 %   ring  7 ≈ 62 %   ring 11 ≈ 98 %
##   ring  4 ≈ 26 %   ring  8 ≈ 74 %   ring 12 = 100 %
## Near-transparent at the revealed edge (ease-in), then decelerates
## toward full darkness (ease-out) — no abrupt jump at the outer boundary.
func _fog_alpha_for(cell: Vector2i) -> float:
	for ring: int in range(1, 13):
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) == ring:
					if _revealed.has(cell + Vector2i(dx, dy)):
						var t := float(ring) / 12.0
						return FOG_COLOR.a * t * t * (3.0 - 2.0 * t)
	return FOG_COLOR.a


func _draw() -> void:
	if _floor_layer == null:
		return
	## Pre-compute alpha for every unrevealed cell so neighbour lookups are O(1).
	var alpha_map: Dictionary = {}
	for x: int in range(_room_size.x):
		for y: int in range(_room_size.y):
			var cell := Vector2i(x, y)
			if not _revealed.has(cell):
				alpha_map[cell] = _fog_alpha_for(cell)
	## Neighbour offsets that correspond to each diamond vertex:
	##   top → tile (0,-1), right → tile (+1,0), bottom → tile (0,+1), left → tile (-1,0)
	const NB := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	for x: int in range(_room_size.x):
		for y: int in range(_room_size.y):
			var cell := Vector2i(x, y)
			if _revealed.has(cell):
				continue
			var cell_a: float = alpha_map[cell]
			## Each vertex alpha = average of this cell and the neighbour in that direction.
			## Revealed neighbour → alpha 0   → feathered fade into the visible zone.
			## Same-ring neighbour → same alpha → no seam.
			## Different-ring     → smooth blend between ring values.
			var v_colors := PackedColorArray()
			for nb: Vector2i in NB:
				var nc := cell + nb
				var nb_a: float
				if _revealed.has(nc):
					nb_a = 0.0
				elif alpha_map.has(nc):
					nb_a = alpha_map[nc]
				else:
					nb_a = cell_a   ## out-of-bounds: no feather at room edge
				v_colors.append(Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b,
						(cell_a + nb_a) * 0.5))
			var centre: Vector2 = (
				_floor_layer.map_to_local(cell)
				+ Vector2(0.0, TILE_HALF_H)
				+ _visual_offset
			)
			## 6-vertex hexagon: floor diamond + wall volume above.
			## Shoulders (right-top / left-top) use the same alpha as the adjacent
			## floor vertex so the wall face gradient matches the floor fade.
			var top_c    := v_colors[0]
			var right_c  := v_colors[1]
			var bottom_c := v_colors[2]
			var left_c   := v_colors[3]
			var v_colors_hex := PackedColorArray([
				top_c,                                                           ## top-tip
				Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, right_c.a),       ## right-top
				right_c,                                                         ## right
				bottom_c,                                                        ## bottom
				left_c,                                                          ## left
				Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, left_c.a),        ## left-top
			])
			var pts := PackedVector2Array([
				centre + Vector2(        0.0, -TILE_HALF_H - WALL_HEIGHT_PX),  ## top-tip
				centre + Vector2( TILE_HALF_W,              -WALL_HEIGHT_PX),  ## right-top
				centre + Vector2( TILE_HALF_W,               0.0           ),  ## right
				centre + Vector2(        0.0,  TILE_HALF_H               ),  ## bottom
				centre + Vector2(-TILE_HALF_W,               0.0           ),  ## left
				centre + Vector2(-TILE_HALF_W,              -WALL_HEIGHT_PX),  ## left-top
			])
			draw_polygon(pts, v_colors_hex)
