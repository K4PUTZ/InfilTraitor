extends Node2D
class_name AimBubbleOverlay

## AimBubbleOverlay / E-BUBBLE — Phase B aim-bubble showing grenade blast radius.
##
## Task 6 of E-FRAG-01/E-SHARD-01: flat translucent disc sized from BombDef's
## ring radii, shown while the player is previewing a grenade throw. No per-cell
## ray data needed for first version — it is a fixed geometric circle from
## `BombDef.destroy_ring_radius` to `BombDef.destroy_ring_radius` (the outermost
## ring), drawn semi-transparent so the map beneath reads through it.
##
## Future enhancement (deferred): rays radiating inward from the bubble's edge
## toward real predicted damage positions (depends on prediction cache).
##
## Phase B only — not triggered by test_zone_controller's current implementation.

var bubble_color: Color = Color(0.5, 0.7, 1.0, 0.2)  ## blue translucent
var ring_width: float = 2.0                          ## line thickness px

var _center: Vector2 = Vector2.ZERO
var _radius: float = 0.0
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the bubble at a given center and radius.
func show_bubble(center: Vector2, radius: float) -> void:
	_center = center
	_radius = radius
	_visible = true
	visible = true
	queue_redraw()


## Update the bubble's position (e.g., following the cursor).
func update_position(center: Vector2) -> void:
	_center = center
	queue_redraw()


func _draw() -> void:
	if not _visible or _radius < 0.001:
		return
	## Draw concentric rings showing damage zones.
	## For now, just the outermost ring; future versions can add inner rings.
	draw_circle(_center, _radius, bubble_color)
	var outline := bubble_color
	outline.a = 1.0
	draw_circle(_center, _radius, outline, false, ring_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
