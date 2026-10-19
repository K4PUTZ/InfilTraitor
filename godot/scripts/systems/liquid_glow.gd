## LiquidGlow — a body that is ITSELF a light (M6 F5, Director 2026-10-18): lava glows warm wherever it stands, a nuclear liquid glows faintly cool
## (phosphorescent). It is the source `LiquidFireLights` reads for a fire (a `plane` and a `visual` level per plane cell), so the lights, their growth
## and their tactical flip are the fire's own mechanism: a cell is lit while it is wet (`refresh`, once a liquid turn), at the full level.
class_name LiquidGlow
extends RefCounted

const NO_DEPTH: float = 0.05

var plane: RefCounted = null
var visual: PackedFloat32Array = PackedFloat32Array()


func setup(fluid_plane: RefCounted) -> void:
	plane = fluid_plane
	visual.resize(plane.cols * plane.rows)
	refresh()


## The wet cells glow, the dry ones do not (the committed depths: a turn's truth).
func refresh() -> void:
	for i in range(visual.size()):
		visual[i] = 1.0 if plane.committed[i] > NO_DEPTH else 0.0


## The `light.body` block of a liquid ({} when the body is no light).
static func body_light(gameplay: Dictionary) -> Dictionary:
	var light: Variant = gameplay.get("light", null)
	if light is Dictionary and (light as Dictionary).get("body", null) is Dictionary:
		return (light as Dictionary)["body"]
	return {}
