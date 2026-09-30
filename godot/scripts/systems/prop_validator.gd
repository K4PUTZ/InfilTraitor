## PropValidator — does this model fit its slot? PURE: plain data in, a list of problems out (empty = it fits).
##
## PROP_PIPELINE_PLAN PP1 / `ACTOR` D66, D69. A rejection is never fatal and never silent: the registry walks its fallback chain
## (model -> the slot's default -> the slot's generic -> the `generic` box) and logs the FIRST problem once. This class only answers;
## it reads no file and no registry (the selftest feeds it literals; `family_of` is a Callable so a test needs no autoload).
##
## `stats` is `PropModelFit.stats(model)`: {"ok", "size": Vector3 (the fitted box), "triangles", "surfaces": Array[String], "finite"}.
class_name PropValidator


## `def`: {"slot": String, "mesh_size": Vector3, "mesh_tier": int, "footprint": Array[Vector2i], "surface_materials": Dictionary}.
## `family_of`: Callable(material_id) -> String (the registry's family, resolved through its fallback chain).
static func validate(def: Dictionary, slot: SlotDef, stats: Dictionary, family_of: Callable) -> Array[String]:
	var problems: Array[String] = []
	var size: Vector3 = def["mesh_size"]
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 or not (is_finite(size.x) and is_finite(size.y) and is_finite(size.z)):
		problems.append("mesh_size %s is not a positive box" % [size])
	elif size.x > slot.max_size.x + 1.0e-4 or size.y > slot.max_size.y + 1.0e-4 or size.z > slot.max_size.z + 1.0e-4:
		problems.append("mesh_size %s is larger than slot '%s' allows (%s)" % [size, slot.id, slot.max_size])
	if int(def["mesh_tier"]) != slot.mesh_tier:
		problems.append("mesh_tier %d is not slot '%s' tier %d" % [int(def["mesh_tier"]), slot.id, slot.mesh_tier])
	if (def["footprint"] as Array) != slot.footprint_gus:
		problems.append("footprint %s is not slot '%s' footprint %s" % [def["footprint"], slot.id, slot.footprint_gus])
	if not bool(stats.get("ok", false)):
		problems.append("the model could not be loaded")
		return problems
	if not bool(stats.get("finite", true)):
		problems.append("the model has a NaN or infinite vertex")
	if int(stats["triangles"]) > slot.max_triangles:
		problems.append("%d triangles exceed slot '%s' budget of %d" % [int(stats["triangles"]), slot.id, slot.max_triangles])
	var surfaces: Array = stats["surfaces"]
	if surfaces.size() > slot.max_surfaces:
		problems.append("%d surfaces exceed slot '%s' budget of %d" % [surfaces.size(), slot.id, slot.max_surfaces])
	var mapped: Dictionary = def["surface_materials"]
	for authored in mapped:
		if not surfaces.has(String(authored)):
			problems.append("surface_materials names '%s', which the model does not have (a typo?)" % authored)
	if not slot.allowed_families.is_empty():
		for authored in mapped:
			var family: String = String(family_of.call(String(mapped[authored])))
			if not slot.allowed_families.has(family):
				problems.append("surface '%s' is '%s' (family %s), not allowed in slot '%s' (%s)"
					% [authored, mapped[authored], family, slot.id, slot.allowed_families])
	return problems
