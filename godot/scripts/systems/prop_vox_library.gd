## PropVoxLibrary — `.vox` models as destructible props: loads, builds and caches (PROP_PIPELINE_PLAN PP4, `ACTOR` D66/D69).
##
## A `PropDef` with `vox_model` is a VOXEL prop (mesh_tier 0): its `.vox` is scaled, mapped to registry materials, hollowed and centred
## on the footprint by `VoxPropBuilder`, then `VoxelBoard.register_vox_prop()` turns the result into `PropBlock`s — one per (GU, material),
## so every assumption the destruction code already makes (one material, one GU per block) still holds. They enter the `VoxelStore`, so
## light, soot, the charred tone, fire, blast and firearm damage, picking, rotation and save are the crate's, for free.
##
## Colour -> material: `vox_materials` maps a palette index (as a string) to a registry material id; an index with no entry takes the
## registry material whose `base_color` is nearest the palette colour (glass, ground, organic and generic rows are never candidates).
class_name PropVoxLibrary

static var _models: Dictionary = {}   ## path -> VoxModel
static var _builds: Dictionary = {}   ## def id -> build Dictionary


static func load_model(path: String) -> VoxModel:
	if _models.has(path):
		return _models[path]
	var model: VoxModel
	if not FileAccess.file_exists(path):
		model = VoxModel.new()
		model.error = "file not found"
	else:
		model = VoxModel.parse(FileAccess.get_file_as_bytes(path))
	if not model.is_ok():
		push_error("[PropVoxLibrary] '%s': %s" % [path, model.error])
	_models[path] = model
	return model


## The build for a def: {"ok", "materials": {id: Array[Vector3i]}, "claims", "size": Vector3i (voxels), "fits", "origin_gu": Vector2i}.
## `material_registry` is `Registries.get_material_registry()` (passed in: this class names no autoload).
static func build_for(def, material_registry) -> Dictionary:
	if _builds.has(def.id):
		return _builds[def.id]
	var failed := {"ok": false, "materials": {}, "claims": 0, "size": Vector3i.ZERO, "fits": false}
	var model: VoxModel = load_model(String(def.vox_model))
	if not model.is_ok():
		_builds[def.id] = failed
		return failed
	var fmin := Vector2i(1 << 20, 1 << 20)
	var fmax := Vector2i(-(1 << 20), -(1 << 20))
	for fp: Vector2i in def.footprint_gus:
		fmin = Vector2i(mini(fmin.x, fp.x), mini(fmin.y, fp.y))
		fmax = Vector2i(maxi(fmax.x, fp.x), maxi(fmax.y, fp.y))
	var per: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	var area := Vector2i((fmax.x - fmin.x + 1) * per, (fmax.y - fmin.y + 1) * per)
	var mapping: Dictionary = def.vox_materials
	var nearest := func(index: int, colour: Color) -> String:
		var own = mapping.get(str(index), "")
		return String(own) if own != "" else _nearest_material(colour, material_registry)
	var built: Dictionary = VoxPropBuilder.build(model, int(def.vox_scale), nearest, area)
	built["ok"] = true
	built["origin_gu"] = fmin
	_builds[def.id] = built
	return built


## What a validator needs about a voxel model: {"ok", "size" (GU), "triangles": 0, "surfaces": [], "finite": true, "claims", "materials"}.
static func stats(def, material_registry) -> Dictionary:
	var b: Dictionary = build_for(def, material_registry)
	var per: float = float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var size: Vector3i = b["size"]
	return {"ok": bool(b["ok"]) and bool(b["fits"]), "size": Vector3(size) / per, "triangles": 0, "surfaces": [], "finite": true,
		"claims": int(b["claims"]), "materials": (b["materials"] as Dictionary).size()}


static func clear_cache() -> void:
	_models.clear()
	_builds.clear()


static func _nearest_material(colour: Color, registry) -> String:
	var best: String = "generic"
	var best_d: float = 1.0e9
	if registry == null:
		return best
	var ids: Array = registry.registry.keys()
	ids.sort()
	for id in ids:
		var def = registry.registry[id]
		if ["glass", "soil", "organic", "generic"].has(String(def.family)):
			continue
		var c: Color = def.base_color
		var d: float = pow(c.r - colour.r, 2.0) + pow(c.g - colour.g, 2.0) + pow(c.b - colour.b, 2.0)
		if d < best_d:
			best_d = d
			best = String(id)
	return best
