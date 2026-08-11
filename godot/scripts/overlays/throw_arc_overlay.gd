extends Node2D
class_name ThrowArcOverlay

## ThrowArcOverlay — the grenade's throw trajectory, preview and animation.
##
## T-ARC. Owns the SHAPE of a thrown grenade's path, for both users: the yellow
## preview curve drawn here, and the sprite's own flight, which calls the statics
## below rather than re-deriving a second parabola that could disagree with the
## line the player was shown.
##
## Director, 2026-08-10: "a parábola de lançamento precisa ser uma curva pra
## cima, de forma que a granada sobe e depois cai, e dá um bounce no chão de
## leve." The first pass arced DOWNWARD — its lift term was
## `-h·4·(t-0.5)² + h`, which is `+h` at the apex, and screen Y grows downward,
## so the curve sagged like a dropped rope. It also scaled the height by the
## HORIZONTAL distance alone, so a throw straight up or down the screen came out
## as a flat line.

## Tuning — `var` per architecture Rule 1. Read by TestZoneController so the
## flown path and the drawn path cannot drift apart.
var arc_color: Color = Color(1.0, 0.8, 0.3, 0.7)
var line_width: float = 2.0
var arc_segments: int = 24
## Apex height as a fraction of the throw's screen distance.
var arc_height_ratio: float = 0.35
## The landing hop, as a fraction of the arc's own apex height, and how long it
## lasts. "De leve" — this is a settle, not a second throw.
var bounce_height_ratio: float = 0.12
var bounce_duration_s: float = 0.18

## Tumble during the flight — "incluir uma pequena rotação no asset durante o
## vôo." One whole turn: enough to read as a tumble, and it lands upright, which
## a fractional count would not.
var flight_turns: float = 1.0

## The settle roll while the fuse burns — Director: "assim que bate no chão,
## enquanto está 'cooking', a granada pode rolar um pouquinho (1/16 de volta) pra
## frente (em relação ao arremesso), e depois rolar 1/32 de volta pra trás, e
## parar." Forward means the direction the throw was travelling.
var roll_forward_turns: float = 1.0 / 16.0
var roll_back_turns: float = 1.0 / 32.0
var roll_forward_s: float = 0.20
var roll_back_s: float = 0.14

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _launch_px: float = 0.0
var _visible: bool = false


## Apex height above the LANDING plane, in pixels, for a throw between two screen
## points. Distance-based, not x-based, so a throw along the screen's vertical
## still arcs. Floored just above the launch height, because an "apex" at or
## below the hand is not an arc at all.
static func arc_height_for(from_pos: Vector2, to_pos: Vector2, ratio: float,
		launch_px: float = 0.0) -> float:
	return maxf(from_pos.distance_to(to_pos) * ratio, launch_px * 1.4)


## A point on the throw's ballistic path. `t` in [0,1] is normalised FLIGHT TIME;
## endpoints are exact.
##
## Director, 2026-08-10: "a gente consegue melhorar a física do arremesso para
## desacelerar a granada até o ápice da parábola, e acelerar até o chão?"
##
## The honest answer is that constant gravity already does that — the previous
## `4·h·t·(1−t)` lift has a constant second derivative, so vertical speed falls
## to zero at the apex and builds again on the way down. What it did NOT model is
## that the grenade LEAVES THE HAND ABOVE THE FLOOR IT LANDS ON. That is what
## makes a real throw asymmetric: the apex arrives before halfway, and the drop
## is longer and ends faster than the rise. `launch_px` is that height, and with
## it zero this reduces exactly to the old symmetric parabola.
##
## Solving z(t) = launch + b·t − c·t² for "starts at launch, ends at 0, peaks at
## apex":
##     z(1) = 0            → c = launch + b
##     z(b/2c) = apex      → b = 2k + 2·sqrt(k² + k·launch),  k = apex − launch
## Horizontal travel stays linear in t, which is also just physics: nothing
## accelerates the grenade sideways once it is out of the hand.
static func arc_point(from_pos: Vector2, to_pos: Vector2, t: float,
		apex_px: float, launch_px: float = 0.0) -> Vector2:
	## The point on the ground directly under the hand — the horizontal path runs
	## from there, and the height term puts the hand back where it belongs at t=0.
	var ground_from := from_pos + Vector2(0.0, launch_px)
	var k: float = maxf(apex_px - launch_px, 0.001)
	var b: float = 2.0 * k + 2.0 * sqrt(k * k + k * launch_px)
	var c: float = launch_px + b
	var height: float = launch_px + b * t - c * t * t
	return ground_from.lerp(to_pos, t) - Vector2(0.0, height)


## When the apex happens, as a fraction of flight time. Exactly 0.5 for a throw
## that starts and ends at the same height, earlier for one thrown from above it.
static func apex_time(apex_px: float, launch_px: float) -> float:
	var k: float = maxf(apex_px - launch_px, 0.001)
	var b: float = 2.0 * k + 2.0 * sqrt(k * k + k * launch_px)
	return b / (2.0 * (launch_px + b))


## Height above the ground during the landing hop. Same 0-at-both-ends shape as
## the arc, so the grenade leaves and rejoins the floor without a step.
static func bounce_lift(t: float, height_px: float) -> float:
	return height_px * 4.0 * t * (1.0 - t)


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	visible = false


## Show the arc from a starting position to a target position.
func show_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	_from = from_pos
	_to = to_pos
	_visible = true
	visible = true
	queue_redraw()


## `launch_px` is how far above its own ground point the throw starts — the
## agent's hand height. Kept as state so the preview curve and the flown path
## are the same shape from the same numbers.
func set_launch_height(launch_px: float) -> void:
	_launch_px = launch_px
	queue_redraw()


func _draw() -> void:
	if not _visible:
		return
	var apex: float = arc_height_for(_from, _to, arc_height_ratio, _launch_px)
	var points := PackedVector2Array()
	for i: int in range(arc_segments + 1):
		points.append(arc_point(_from, _to, float(i) / float(arc_segments), apex, _launch_px))
	draw_polyline(points, arc_color, line_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
