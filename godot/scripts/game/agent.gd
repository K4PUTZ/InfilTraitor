extends Node2D
## Agent controller — M1 prototype
##
## Visual: draws an isometric diamond (floor shadow) + body dot above it.
## Movement: teleports to target cell immediately (AP system comes in M1 proper).
##
## map_to_local() in DIAMOND_DOWN layout returns the TOP VERTEX of the cell diamond
## (the apex — which is also the junction of 4 tiles). The visual center is
## tile_size.y / 2 = 64 px below that vertex.

const CELL_OFFSET := Vector2(0, 64)  # top vertex → visual center of the diamond

# Diamond half-dimensions (slightly smaller than the full cell 128×64)
const SHADOW_W := 90
const SHADOW_H := 45
const BODY_RADIUS := 16

const COLOR_SHADOW := Color(0.15, 0.85, 0.50, 0.75)
const COLOR_BODY   := Color(0.15, 0.85, 0.50, 1.00)
const COLOR_HEAD   := Color(1.00, 1.00, 1.00, 0.95)

const MAX_AP := 2   ## Action Points per turn.

## Current grid cell the agent occupies.
var cell: Vector2i = Vector2i(0, 0)

## AP remaining this turn.  Managed by room.gd (it knows the path cost).
var ap: int = MAX_AP

## True while the position tween is running — blocks player input during movement.
var is_moving: bool = false
var _tween: Tween = null


## Called by room.gd at the start of each player turn.
func reset_turn() -> void:
	ap = MAX_AP


## Deduct AP.  Clamped at 0; room.gd guards against over-spending.
func spend_ap(amount: int) -> void:
	ap = maxi(0, ap - amount)


## Called by room.gd after the room is built.
func initialize(start_cell: Vector2i, floor_layer: TileMapLayer) -> void:
	cell     = start_cell
	position = floor_layer.map_to_local(start_cell) + CELL_OFFSET
	queue_redraw()


## Move agent to a new walkable cell.
## Animates position over 0.2 s; calls on_done when the tween finishes.
func move_to(target_cell: Vector2i, floor_layer: TileMapLayer, on_done: Callable = Callable()) -> void:
	cell = target_cell
	var target_pos := floor_layer.map_to_local(target_cell) + CELL_OFFSET
	if _tween != null and _tween.is_running():
		_tween.kill()
	is_moving = true
	_tween = create_tween()
	_tween.tween_property(self, "position", target_pos, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		is_moving = false
		if on_done.is_valid():
			on_done.call()
	)


func _draw() -> void:
	# Floor shadow — isometric diamond on the tile surface
	var shadow := PackedVector2Array([
		Vector2(0,          -SHADOW_H),
		Vector2(SHADOW_W,   0),
		Vector2(0,          SHADOW_H),
		Vector2(-SHADOW_W,  0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)
	draw_polyline(shadow + PackedVector2Array([shadow[0]]),
			Color(0, 0, 0, 0.35), 1.5)

	# Body — circle rising above the floor diamond
	# In screen space "up" is -Y; SHADOW_H is the diamond's top vertex
	var body_y := -SHADOW_H - BODY_RADIUS - 8
	draw_circle(Vector2(0, body_y), BODY_RADIUS + 3, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, body_y), BODY_RADIUS,     COLOR_BODY)
	draw_circle(Vector2(0, body_y), BODY_RADIUS - 5, COLOR_HEAD)
