## LiquidField — the liquids of the open map as the rules see them: a lookup from a GU cell to the liquid standing in it and how deep.
##
## M6 F3. It owns nothing: each body is a `FluidPlane` (the turn's truth, ticked by its `LiquidSheet3D`) plus the liquid's id; the field only
## READS the planes, so there is one truth. It reads the plane's COMMITTED depths (the last complete tick), never the live ones the sheet draws. A cell is wet when the deepest plane cell inside that GU holds more than `LiquidExposure.NO_DEPTH`.
class_name LiquidField
extends RefCounted

const LiquidRegistryRef = preload("res://godot/scripts/systems/liquid_registry.gd")

var _bodies: Array = []     ## {"kind": String, "rect": Rect2 (the interior, raw GU), "plane": FluidPlane}


func clear() -> void:
	_bodies.clear()


func add_body(kind: String, rect: Rect2, plane: RefCounted) -> void:
	if plane != null:
		_bodies.append({"kind": kind, "rect": rect, "plane": plane})


func count() -> int:
	return _bodies.size()


## `{}` for a dry cell, else `{"kind", "depth" (voxels, the deepest plane cell in the GU), "gameplay", "body" (index)}`.
func at_cell(cell: Vector2i) -> Dictionary:
	var centre := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	for b in range(_bodies.size()):
		var body: Dictionary = _bodies[b]
		if not (body["rect"] as Rect2).has_point(centre):
			continue
		var plane = body["plane"]
		var depth: float = 0.0
		var c0: int = maxi(int(floor((float(cell.x) - plane.origin.x) / plane.cell_gu)), 1)
		var c1: int = mini(int(ceil((float(cell.x + 1) - plane.origin.x) / plane.cell_gu)) - 1, plane.cols - 2)
		var r0: int = maxi(int(floor((float(cell.y) - plane.origin.y) / plane.cell_gu)), 1)
		var r1: int = mini(int(ceil((float(cell.y + 1) - plane.origin.y) / plane.cell_gu)) - 1, plane.rows - 2)
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				depth = maxf(depth, plane.committed[plane.index(c, r)])
		if depth > 0.05:
			return {"kind": body["kind"], "depth": depth, "gameplay": LiquidRegistryRef.gameplay(String(body["kind"])), "body": b}
		return {}
	return {}


## Dev / the player's valve: the rate of a body's `source` (0 = shut).
func set_source_rate(body: int, source: int, rate: float) -> bool:
	if body < 0 or body >= _bodies.size():
		return false
	return (_bodies[body]["plane"] as RefCounted).set_source_rate(source, rate)
