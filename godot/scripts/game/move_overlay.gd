extends Node2D
class_name MoveOverlay
## Draws semi-transparent colored diamonds over reachable grid cells.
##
## Zone colors:
##   zone1 (1 AP)    → light blue
##   zone2 (2nd AP)  → dark blue
##   dash  (2 AP)    → orange
##
## Must be placed in the scene at position (0,0), same local space as FloorLayer.

const MovementRange = preload("res://godot/scripts/game/movement_range.gd")

# Fill colors — semi-transparent tint over each reachable zone
const COLOR_FILL_ZONE1 := Color(0.25, 0.65, 1.00, 0.22)
const COLOR_FILL_ZONE2 := Color(0.10, 0.30, 0.90, 0.18)
const COLOR_FILL_DASH  := Color(1.00, 0.55, 0.05, 0.22)
# Perimeter line colors — bright outline drawn only at zone boundary edges
const COLOR_LINE_ZONE1 := Color(0.40, 0.82, 1.00, 0.95)
const COLOR_LINE_ZONE2 := Color(0.25, 0.55, 1.00, 0.90)
const COLOR_LINE_DASH  := Color(1.00, 0.68, 0.10, 0.95)
## LINE_W is in world pixels; camera zoom 0.35 → LINE_W × 0.35 = screen pixels
const LINE_W := 9.0

## Diamond half-extents (inset from tile edge; tile half = 128 × 64)
const HW := 118   ## horizontal half-width
const HH :=  56   ## vertical half-height

## Neighbor directions in DIAMOND_DOWN grid (+x = lower-right, +y = lower-left)
const DIRS   := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Perimeter edge endpoints (local, relative to cell center) for each direction.
## The edge is drawn when the neighbor in that direction is NOT in the same zone.
const EDGE_A := [Vector2(118, 0),   Vector2(-118, 0), Vector2(0, 56),    Vector2(0, -56)]
const EDGE_B := [Vector2(0, 56),    Vector2(0, -56),  Vector2(-118, 0),  Vector2(118, 0)]

var _floor_layer: TileMapLayer = null
var _result                    = null


func setup(floor_layer: TileMapLayer) -> void:
	_floor_layer = floor_layer


## Show the three zones.  Call after each agent move.
func show_range(result) -> void:
	_result  = result
	visible  = true
	queue_redraw()


## Hide the overlay (enemy turn, or agent has no AP left).
func hide_range() -> void:
	_result  = null
	visible  = false
	queue_redraw()


func _draw() -> void:
	if _result == null or _floor_layer == null:
		return
	# Draw dash → zone2 → zone1 so closer zones render on top.
	_draw_zone(_result.dash,  COLOR_FILL_DASH,  COLOR_LINE_DASH)
	_draw_zone(_result.zone2, COLOR_FILL_ZONE2, COLOR_LINE_ZONE2)
	_draw_zone(_result.zone1, COLOR_FILL_ZONE1, COLOR_LINE_ZONE1)


func _draw_zone(zone: Dictionary, fill: Color, line: Color) -> void:
	for c: Vector2i in zone:
		var center: Vector2 = _floor_layer.map_to_local(c) + Vector2(0, 64)
		# Faint fill
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(   0, -HH),
			center + Vector2(  HW,   0),
			center + Vector2(   0,  HH),
			center + Vector2( -HW,   0),
		]), fill)
		# Perimeter: draw only edges that face a cell outside this zone
		for i in 4:
			if not zone.has(c + DIRS[i]):
				var a: Vector2 = center + EDGE_A[i]
				var b: Vector2 = center + EDGE_B[i]
				# Wide glow halo (faint) + sharp core line, both antialiased
				draw_line(a, b, Color(line.r, line.g, line.b, line.a * 0.28), LINE_W * 2.8, true)
				draw_line(a, b, line, LINE_W, true)
