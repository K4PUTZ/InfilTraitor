extends Node2D
class_name CircleGateProbe

## PERF-P7b §12.11 — the static scene `INFILTRAITOR_CAPTURE_ACTION=circle_gate`
## photographs through both circle paths.
##
## Deliberately NOT random and NOT time-dependent: the whole point is a frame
## that is bit-identical run to run, so the only thing a diff can be measuring is
## the difference between `draw_circle` and `CircleField`. Everything below is a
## closed-form function of the loop index.
##
## The circle set is chosen to exercise what the overlays actually do rather than
## a tidy grid: radii spanning the ember's 6-18 px and the smoke puff's much
## larger reach, heavy overlap (additive blending is where a winding or
## tessellation difference shows up), fractional centres (a circle at x.5 lands
## differently than one at x.0), and alpha well below 1.

## Flipped by the capture between the two passes.
var use_field: bool = false

## Populated on first use and never re-rolled — see the class note.
var _circles: Array = []
var _field: CircleField = null

var count: int = 220
var area: Vector2 = Vector2(1180.0, 620.0)


func _ready() -> void:
	position = Vector2(50.0, 50.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_build()
	_field = CircleField.new()
	_field.attach(self, CanvasItemMaterial.BLEND_MODE_ADD)


func circle_count() -> int:
	return _circles.size()


## A deterministic pseudo-random spread. `sin`-hashing rather than `randf()` so
## nothing here depends on the global RNG stream, which the rest of the boot
## consumes an unpredictable number of times before this runs.
func _build() -> void:
	_circles.clear()
	for i in range(count):
		var f: float = float(i)
		var hx: float = fposmod(sin(f * 12.9898) * 43758.5453, 1.0)
		var hy: float = fposmod(sin(f * 78.233) * 12345.6789, 1.0)
		var hr: float = fposmod(sin(f * 39.4265) * 24634.6345, 1.0)
		var hc: float = fposmod(sin(f * 4.7381) * 9873.1234, 1.0)
		_circles.append({
			"pos": Vector2(hx * area.x, hy * area.y),
			## 4..26 px — the ember's core and halo and the puff's growth, in one
			## population, so no radius band goes untested.
			"radius": 4.0 + hr * 22.0,
			"color": Color(0.35 + hc * 0.65, 0.20 + hr * 0.55, 0.10 + hy * 0.35,
				0.18 + hc * 0.55),
		})


func _draw() -> void:
	if use_field:
		_field.begin(_circles.size())
		for c in _circles:
			_field.push(c["pos"], c["radius"], c["color"])
		_field.flush()
		return
	_field.clear()
	for c in _circles:
		draw_circle(c["pos"], c["radius"], c["color"])
