extends Node2D
class_name CeilingPropOverlay

## CeilingPropOverlay — overhead (5th-floor) ceiling layer.
##
## VIS-01 render slice: draws the map's lights as placeholder ceiling fixtures,
## raised above the wall stack so they read as mounted on the ceiling. Driven by
## the room's active (perspective-rotated) `light_sources`, so it follows the
## scenery on rotation. Real sprites/scenes (lamps, chandeliers, spots) replace
## the placeholders later; other ceiling props (conduits, pipes, vents) join here.
##
## Placeholder draw style matches the agent/guard (draw-based, no assets yet).

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO   ## received, never hardcoded (rule #2)
var _ceiling_lift: float = 0.0                ## px to raise props to ceiling height
var _lights: Array = []                       ## active light_sources dicts {x,y,radius,intensity}

func setup(floor_layer: TileMapLayer, visual_offset: Vector2, ceiling_lift: float) -> void:
	_floor_layer = floor_layer
	_visual_offset = visual_offset
	_ceiling_lift = ceiling_lift

## Feed the active (rotated) light sources; redraws.
func set_lights(light_sources: Array) -> void:
	_lights = light_sources
	queue_redraw()

func _draw() -> void:
	if _floor_layer == null:
		return
	for light in _lights:
		var cell := Vector2i(int(light.get("x", 0)), int(light.get("y", 0)))
		var pos: Vector2 = _floor_layer.map_to_local(cell) + TILE_CENTER_OFFSET + _visual_offset
		pos.y -= _ceiling_lift
		_draw_lamp(pos, float(light.get("intensity", 1.0)), float(light.get("radius", 6)))

## Placeholder ceiling lamp: a soft glow, a bright bulb, a dark rim, and a mount stem.
func _draw_lamp(p: Vector2, intensity: float, radius: float) -> void:
	var glow_r: float = clampf(34.0 + radius * 3.0, 40.0, 72.0)
	draw_circle(p, glow_r, Color(1.0, 0.93, 0.62, 0.30 * intensity))
	draw_circle(p, glow_r * 0.55, Color(1.0, 0.93, 0.62, 0.22 * intensity))
	draw_circle(p, 20.0, Color(1.0, 0.90, 0.52, clampf(0.7 + 0.3 * intensity, 0.0, 1.0)))
	draw_arc(p, 20.0, 0.0, TAU, 28, Color(0.14, 0.12, 0.08, 1.0), 3.5)
	draw_line(p + Vector2(0.0, -20.0), p + Vector2(0.0, -40.0), Color(0.26, 0.26, 0.28, 1.0), 4.0)
