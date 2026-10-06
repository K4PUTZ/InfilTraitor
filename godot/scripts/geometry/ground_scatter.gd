## GroundScatter — expands the map's `ground_scatter` zones into placed stamps (R3D-SURFACES SM-2, 2026-10-06; SURFACES_MASTER_PLAN §4-§5).
##
## A scatter ITEM is `{zone, kind, density?, seed, scale?}`: the kind is a CLUSTER STAMP (several decals baked into one image), the zone a
## rectangle in raw GU. The expansion is a pure function of the item, so it is the same in every run and on every machine (B4: positions
## come from FNV-1a of `kind|seed|cell`, never from a RNG): a jittered grid of cell side `1 / sqrt(density)` GU, one stamp per cell at a
## jittered position (snapped to the voxel lattice, 1/8 GU), with a free rotation and a scale in the kind's range. A stamp is dropped when
## the floor rules forbid its kind under it (`SurfaceRules`: no leaf in the desert) or when something stands where it would lie (a wall, a
## block, a prop: `blocked`), both QUIETLY here and counted, because a zone of three thousand cells must not print three thousand errors.
## Stacking is allowed: two stamps may overlap, and so may two kinds in one zone.
class_name GroundScatter
extends RefCounted

const SurfaceRulesRef = preload("res://godot/scripts/systems/surface_rules.gd")


## `floor_tags_of`: `Callable(gu: Vector2i) -> PackedStringArray` (as for `GroundDecals3D.attach`). `blocked`: `Callable(at: Vector2, half: float)
## -> bool`, true when a standing thing is under (the centre of) a stamp whose half side is `half` GU. Returns the `GroundDecals3D`
## instances (`scatter: true`) and what was dropped, per kind.
static func expand(items: Array, floor_tags_of: Callable, blocked: Callable) -> Dictionary:
	var instances: Array = []
	var stats: Dictionary = {}   ## kind -> {"placed", "tags", "blocked"}
	for item in items:
		var kind: String = String(item.get("kind", ""))
		if not SurfaceRulesRef.has_rule(kind) or SurfaceRulesRef.kind_class(kind) != "scatter":
			push_error("[GroundScatter] kind '%s' is not a scatter kind in surfaces/rules.json: its zone places nothing" % kind)
			continue
		var zone: Rect2 = item["zone"]
		var density: float = float(item.get("density", 0.0))
		if density <= 0.0:
			density = SurfaceRulesRef.kind_density(kind)
		if density <= 0.0 or zone.size.x <= 0.0 or zone.size.y <= 0.0:
			push_error("[GroundScatter] zone %s of '%s' has no density or no area: it places nothing" % [str(zone), kind])
			continue
		var seed_text: String = str(int(item.get("seed", 0)))
		var scale_range: Vector2 = item.get("scale", SurfaceRulesRef.kind_scale(kind))
		var size: float = SurfaceRulesRef.kind_size(kind)
		var cell: float = 1.0 / sqrt(density)
		var s: Dictionary = stats.get(kind, {"placed": 0, "tags": 0, "blocked": 0})
		for i in range(int(ceil(zone.size.x / cell))):
			for j in range(int(ceil(zone.size.y / cell))):
				var key: String = "%s|%s|%d|%d" % [kind, seed_text, i, j]
				var at := Vector2(zone.position.x + (float(i) + _u(key + "x")) * cell, zone.position.y + (float(j) + _u(key + "y")) * cell)
				at = Vector2(round(at.x * 8.0) / 8.0, round(at.y * 8.0) / 8.0)
				if not zone.has_point(at):
					continue
				var scale: float = lerpf(scale_range.x, scale_range.y, _u(key + "s"))
				if _tags_forbid(kind, at, size * scale, floor_tags_of):
					s["tags"] += 1
					continue
				if blocked.is_valid() and blocked.call(at, size * scale * 0.5):
					s["blocked"] += 1
					continue
				s["placed"] += 1
				instances.append({"at": at, "kind": kind, "variant": -1, "rot": _u(key + "r") * TAU, "scale": scale, "scatter": true})
		stats[kind] = s
	return {"instances": instances, "stats": stats}


## A hash in [0, 1) of a string: FNV-1a (B4), the same everywhere.
static func _u(text: String) -> float:
	return float(FacadeSampler._fnv1a_hash(text) % 100003) / 100003.0


## Quiet twin of `GroundDecals3D._forbidden`: true when the rules forbid `kind` on any floor under the quad.
static func _tags_forbid(kind: String, at: Vector2, extent: float, floor_tags_of: Callable) -> bool:
	if not floor_tags_of.is_valid():
		return false
	var h: float = extent * 0.5
	var seen: Dictionary = {}
	for corner: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h), Vector2.ZERO]:
		var probe: Vector2 = at + corner * 0.999
		var gu := Vector2i(int(floor(probe.x)), int(floor(probe.y)))
		if seen.has(gu):
			continue
		seen[gu] = true
		var tags: PackedStringArray = floor_tags_of.call(gu)
		if not tags.is_empty() and SurfaceRulesRef.reason_against(kind, tags) != "":
			return true
	return false
