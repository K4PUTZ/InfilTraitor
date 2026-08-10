extends Node2D
class_name AnimatedRayOverlay

## AnimatedRayOverlay / E-RAY — Generic animated ray/streak overlay.
##
## Sibling to LightRayOverlay (light_ray_overlay.gd), not a subclass.
## Light rays are static between relights and blend gold; animated rays
## travel/fade on their own timeline and support different blend modes and
## colours.
##
## Each ray is a precomputed origin→destination with its own lifetime:
## elapsed time marches forward via _process(delta), alpha ramps via a
## supplied easing function, and the ray draws over the fire as a 2 px line
## (no soft passes — different look target than LightRayOverlay).
##
## Contract (same as EmberOverlay/SmokeSparkOverlay):
## - Purely visual; nothing here writes Voxel state.
## - Lost on map reload, perspective rotation — nothing in a reload cares.

@export var visual_offset: Vector2 = Vector2.ZERO
@export var ray_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var line_width: float = 2.0

## Ray data: {from, to, elapsed, duration, alpha_at(t)}
var _rays: Array = []

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Add one ray traveling from `from_pos` to `to_pos` over `duration` seconds.
## `alpha_func` is a callable(t: float) -> float where t ∈ [0, 1].
## Simplest forms: func(t): return 1.0 - t  (linear fade)
##                func(t): return 1.0         (no fade).
func add_ray(from_pos: Vector2, to_pos: Vector2, duration: float,
		alpha_func: Callable = Callable()) -> void:
	if duration <= 0.0:
		return
	if alpha_func.is_null():
		alpha_func = func(t): return 1.0 - t  ## Default: linear fade
	_rays.append({
		"from": from_pos,
		"to": to_pos,
		"elapsed": 0.0,
		"duration": duration,
		"alpha_func": alpha_func,
	})
	set_process(true)


func _process(delta: float) -> void:
	if _rays.is_empty():
		set_process(false)
		return
	var alive: Array = []
	for ray in _rays:
		ray["elapsed"] += delta
		if ray["elapsed"] < ray["duration"]:
			alive.append(ray)
	_rays = alive
	queue_redraw()


func _draw() -> void:
	for ray in _rays:
		var t: float = ray["elapsed"] / ray["duration"]
		var alpha: float = ray["alpha_func"].call(t)
		var c := ray_color
		c.a *= alpha
		draw_line(ray["from"] + visual_offset, ray["to"] + visual_offset, c, line_width)


## Discard every in-flight ray (map reload, perspective change).
func clear() -> void:
	_rays.clear()
	set_process(false)
	queue_redraw()
