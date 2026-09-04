## GLASS CRACK-04 — print the opening family as JSON, for the sheet generator.
##
## Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##            --script godot/scripts/tools/dump_glass_openings.gd
##
## ⚠️ THE FAMILY HAS ONE AUTHORITY AND IT IS `glass_opening.gd`. The fracture
## sheets are generated in Python, and a Python copy of the twelve polygons would
## be a second definition of the shape the whole track exists to keep single —
## drifting silently the first time a member is retuned, with the art quietly
## describing a hole the engine no longer cuts.
##
## So the generator ASKS. This prints, and `gen_fracture_sheet.py` runs it and
## reads stdout; nothing is stored in the repo to go stale.
##
## Output: one JSON object, `{"openings": [{id, size, r_max, radii: [...]}, ...]}`,
## with `radii` sampled at `SAMPLES` evenly spaced angles from +run
## counter-clockwise — the boundary distance the generator starts each crack from.
extends SceneTree

const GlassOpeningClass = preload("res://godot/scripts/systems/destruction/glass_opening.gd")

## Enough to resolve a spike's flank; the generator interpolates between them.
const SAMPLES: int = 180


func _init() -> void:
	var out: Array = []
	for id in GlassOpeningClass.ids():
		var poly: PackedVector2Array = GlassOpeningClass.polygon(id)
		if poly.is_empty():
			continue
		var radii: Array = []
		var r_max: float = 0.0
		for i in range(SAMPLES):
			var a: float = TAU * float(i) / float(SAMPLES)
			var r: float = _boundary_radius(poly, a)
			radii.append(snappedf(r, 0.0001))
			r_max = maxf(r_max, r)
		out.append({
			"id": id,
			"size": String(GlassOpeningClass.FAMILY[id].get("size", "small")),
			"r_max": snappedf(r_max, 0.0001),
			"radii": radii,
		})
	print(JSON.stringify({"openings": out}))
	quit(0)


## How far the boundary is from the centre along `ang`. Walks outward and takes
## the LAST crossing, so a spike's tip is reported rather than a near lobe — the
## crack has to start outside the whole opening, not inside one of its arms.
func _boundary_radius(poly: PackedVector2Array, ang: float) -> float:
	var dir := Vector2(cos(ang), sin(ang))
	var step: float = 0.01
	var last_inside: float = 0.0
	var r: float = step
	while r < 8.0:
		if Geometry2D.is_point_in_polygon(dir * r, poly):
			last_inside = r
		r += step
	return last_inside + step
