## PropRegistry — Prop definitions catalog (two-tier: res:// + user://)
## User-tier props override res:// props on id collision, same pattern as MaterialRegistry
## and TextureResolver.
##
## SLOTS (PROP_PIPELINE_PLAN PP1, `ACTOR` D66): `props/slots/*.json` (two tiers) are `SlotDef`s; a `PropDef` with `slot` is one MODEL of
## that slot and several models of one slot coexist. `resolve_placement()` turns what a map names (a prop id, or a slot id) into a prop
## that FITS, walking the fallback chain when it does not: the model -> the slot's default model -> the slot's GENERIC (a plain box of
## the slot's size in the `generic` material) -> the generic box of the prop's own size. A rejection is one `push_warning` per prop id.

class_name PropRegistry

const JsonFileRef = preload("res://godot/scripts/systems/json_file.gd")

const RES_PROPS_DIR := "res://props"
const USER_PROPS_DIR := "user://props"
const RES_SLOTS_DIR := "res://props/slots"
const USER_SLOTS_DIR := "user://props/slots"

var registry: Dictionary = {}  # id → PropDef (stored as Dict due to class_name limitations)
## Every row (prop or slot) that could not be read, loudly (`JsonFile`, AUDIT 2026-10-07).
var load_errors: Array[String] = []
var slots: Dictionary = {}     # id → SlotDef
## Callable(material_id) -> family String. Set by the `Registries` autoload (the material registry's fallback chain); a test sets its own.
var family_of: Callable = Callable()
## The material registry (for a voxel model's colour -> material mapping); null in a test that has none.
var material_registry = null
var _problem_logged: Dictionary = {}
var _stats_cache: Dictionary = {}


func _init() -> void:
	pass


## Register a prop definition
func register(prop_def) -> void:
	registry[prop_def.id] = prop_def
	print("[PropRegistry] Registered: %s (footprint: %s, storeys: %d, cover: %s)" % 
		[prop_def.id, prop_def.footprint_gus, prop_def.storeys, prop_def.gameplay.get("cover", "none")])


## Get a prop by ID; returns null if not found
func get_prop(p_id: String):
	return registry.get(p_id, null)


## Get prop count
func count() -> int:
	return registry.size()


## Load props from both tiers (res:// then user://; user wins on collision)
func load_from_disk() -> void:
	_scan_slots(RES_SLOTS_DIR)
	_scan_slots(USER_SLOTS_DIR)
	_scan_dir(RES_PROPS_DIR)
	_scan_dir(USER_PROPS_DIR)


func register_slot(slot: SlotDef) -> void:
	slots[slot.id] = slot


func get_slot(p_id: String) -> SlotDef:
	return slots.get(p_id, null)


func _scan_slots(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path: String = dir_path.path_join(fname)
			var parsed: Dictionary = JsonFileRef.read_object(path, "PropRegistry", load_errors)
			if not parsed.is_empty() and not JsonFileRef.require_id(parsed, path, "PropRegistry", load_errors).is_empty():
				register_slot(SlotDef.from_json(parsed, load_errors))
		fname = dir.get_next()


## Every model of a slot (every `PropDef` whose `slot` it is), sorted by id so a pick is stable.
func models_for_slot(slot_id: String) -> Array:
	var out: Array = []
	for id in registry:
		if String(registry[id].slot) == slot_id:
			out.append(registry[id])
	out.sort_custom(func(a, b) -> bool: return String(a.id) < String(b.id))
	return out


## What a map names -> a prop that fits. `name` is a prop id (that model) or a slot id (its default model, else a stable pick by `salt`).
## Returns {"def": PropDef, "gameplay": Dictionary, "fallback": "" | "slot_default" | "slot_generic" | "generic", "problems": Array[String]}. `gameplay` is
## the SLOT's whenever the prop has one (a model never decides cover, blocking or tier: D66); `def` is never null
## unless `name` matches nothing at all (then null, and the caller skips the placement loudly as before).
func resolve_placement(name: String, salt: String = "") -> Dictionary:
	var result: Dictionary = _resolve(name, salt)
	var def = result["def"]
	var slot: SlotDef = slots.get(String(def.slot), null) if def != null else null
	result["gameplay"] = slot.gameplay if slot != null else (def.gameplay if def != null else {})
	return result


func _resolve(name: String, salt: String) -> Dictionary:
	var def = registry.get(name, null)
	if def == null and slots.has(name):
		def = _pick_model(slots[name], salt)
		if def == null:
			return {"def": _generic_def(slots[name]), "fallback": "slot_generic", "problems": ["slot '%s' has no model" % name]}
	if def == null:
		return {"def": null, "fallback": "", "problems": ["no prop or slot named '%s'" % name]}
	if String(def.slot) == "" or (int(def.mesh_tier) == 0 and String(def.vox_model) == ""):
		return {"def": def, "fallback": "", "problems": []}   ## a legacy procedural voxel prop (the crates): no slot to fit
	var slot: SlotDef = slots.get(String(def.slot), null)
	if slot == null:
		var own_problems: Array[String] = ["prop '%s' names slot '%s', which does not exist" % [def.id, def.slot]]
		_log_once(def.id, own_problems)
		return {"def": _generic_box_def(def), "fallback": "generic", "problems": own_problems}
	var problems: Array[String] = problems_of(def, slot)
	if problems.is_empty():
		return {"def": def, "fallback": "", "problems": []}
	_log_once(def.id, problems)
	var default_def = registry.get(slot.default_model, null)
	if default_def != null and default_def != def and problems_of(default_def, slot).is_empty():
		return {"def": default_def, "fallback": "slot_default", "problems": problems}
	return {"def": _generic_def(slot), "fallback": "slot_generic", "problems": problems}


## The problems keeping `def` out of `slot` (empty = it fits). Cached per prop id (the model is what costs).
func problems_of(def, slot: SlotDef) -> Array[String]:
	var key := "%s@%s" % [def.id, slot.id]
	if _stats_cache.has(key):
		return _stats_cache[key]
	var stats: Dictionary
	var size: Vector3 = def.mesh_size
	if String(def.vox_model) != "":
		stats = PropVoxLibrary.stats(def, material_registry)
		## A voxel model has no `mesh_size`: its own scaled size is what must fit the slot's box (and when it could not be built there
		## is no size to judge: the slot's own box keeps "it could not be loaded" the first problem instead of a confusing 0-size one).
		size = stats["size"] if bool(stats["ok"]) else slot.max_size
	elif String(def.model_path) == "":
		stats = PropModelFit.stats(PropModelFit.box(def.mesh_size))
	else:
		stats = PropModelFit.stats(PropModelFit.fit(def.model_path, def.model_rotation_deg, def.mesh_size))
	var result: Array[String] = PropValidator.validate({"slot": slot.id, "mesh_size": size, "mesh_tier": def.mesh_tier,
		"footprint": def.footprint_gus, "surface_materials": def.surface_materials}, slot, stats,
		family_of if family_of.is_valid() else func(_m: String) -> String: return "generic")
	_stats_cache[key] = result
	return result


## The slot's default model if it has one, else a stable pick among its models (a hash of the salt, never `randf()`).
func _pick_model(slot: SlotDef, salt: String):
	var models: Array = models_for_slot(slot.id)
	if models.is_empty():
		return null
	var preferred = registry.get(slot.default_model, null)
	if preferred != null:
		return preferred
	return models[FacadeSampler._fnv1a_hash("%s:%s" % [slot.id, salt]) % models.size()]


## A slot's GENERIC: a plain box of the slot's size, in the slot's generic material (no model, so it voxelizes to a box of fragments).
func _generic_def(slot: SlotDef):
	var def = load("res://godot/scripts/systems/prop_def.gd").new()
	def.id = "generic_%s" % slot.id
	def.slot = slot.id
	def.mesh_tier = slot.mesh_tier
	def.mesh_size = slot.max_size
	def.footprint_gus = slot.footprint_gus
	def.gameplay = slot.gameplay
	def.material_zones = {"default": slot.generic_material}
	## A voxel slot's generic is a HOLLOW box (a crate's shell), never a solid cube: the claim budget of a slot is what a map is planned on.
	if slot.mesh_tier == 0:
		def.hollow_shell = 1
	return def


## The last rung: a generic box of the PROP'S OWN size (its slot is unknown, so there is nothing else to size it by).
func _generic_box_def(of):
	var def = load("res://godot/scripts/systems/prop_def.gd").new()
	def.id = "generic_%s" % of.id
	def.mesh_tier = of.mesh_tier
	def.mesh_size = of.mesh_size
	def.footprint_gus = of.footprint_gus
	def.gameplay = of.gameplay
	def.material_zones = {"default": "generic"}
	return def


func _log_once(prop_id: String, problems: Array[String]) -> void:
	if _problem_logged.has(prop_id):
		return
	_problem_logged[prop_id] = true
	push_warning("[PropRegistry] prop '%s' does not fit its slot (%s): using the fallback" % [prop_id, problems[0]])


## Scan a directory and register all .json files as PropDef
func _scan_dir(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path: String = dir_path.path_join(fname)
			var parsed: Dictionary = JsonFileRef.read_object(path, "PropRegistry", load_errors)
			if not parsed.is_empty() and not JsonFileRef.require_id(parsed, path, "PropRegistry", load_errors).is_empty():
				var PropDefClass = load("res://godot/scripts/systems/prop_def.gd")
				register(PropDefClass.from_json(parsed, load_errors))
		fname = dir.get_next()

