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

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _visible: bool = false


## Apex height in pixels for a throw between two screen points. Distance-based,
## not x-based, so a throw along the screen's vertical still arcs.
static func arc_height_for(from_pos: Vector2, to_pos: Vector2, ratio: float) -> float:
	return from_pos.distance_to(to_pos) * ratio


## A point on the throw parabola. `t` in [0,1]; endpoints are exact.
## The lift term is 0 at both ends and `height_px` at t=0.5, SUBTRACTED from Y
## because up the screen is negative.
static func arc_point(from_pos: Vector2, to_pos: Vector2, t: float, height_px: float) -> Vector2:
	var lift: float = height_px * 4.0 * t * (1.0 - t)
	return from_pos.lerp(to_pos, t) - Vector2(0.0, lift)


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


func _draw() -> void:
	if not _visible:
		return
	var height: float = arc_height_for(_from, _to, arc_height_ratio)
	var points := PackedVector2Array()
	for i: int in range(arc_segments + 1):
		points.append(arc_point(_from, _to, float(i) / float(arc_segments), height))
	draw_polyline(points, arc_color, line_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
