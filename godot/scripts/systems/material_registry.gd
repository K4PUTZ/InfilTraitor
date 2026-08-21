## MaterialRegistry — Material definitions, pattern algorithms, and resistance
## (destroy/dent/crack) — D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06):
## material properties are registered dynamic data, never hardcoded and never
## map-coupled. Two-tier disk load (res:// then user://, user wins on
## collision), same pattern as BombRegistry/PropRegistry/WeaponRegistry.
##
## D19/D20: one row per material, surface-independent for behavior (this
## file). Texture identity is a SEPARATE axis, owned by
## BakePolicy.texture_for_material().
##
## D34/E-SEAM-01 (Director, 2026-08-08): that axis is no longer surface-keyed
## either. A `has_facade` material renders EVERY surface — wall, roof and
## floor — from `facade_<id>`, tinted by `base_color` under MULTIPLY, so the
## three read as one material; only `has_facade == false` (organic ground)
## keeps the photographic `slab_<id>` source at WHITE. The WHITE-vs-tinted
## modulate is still decided by the texture id's own prefix at bake time
## (bake_compositor.gd's _modulate_for_mode), never by a field on this class —
## what changed is which ids reach it.

class_name MaterialRegistry

# Import constants
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const StonePatternClass = preload("res://godot/scripts/systems/stone_pattern.gd")
const WoodPatternClass = preload("res://godot/scripts/systems/wood_pattern.gd")
const MetalPatternClass = preload("res://godot/scripts/systems/metal_pattern.gd")

const RES_MATERIALS_DIR := "res://ASSETS/materials"
const USER_MATERIALS_DIR := "user://materials"

## Base class for pattern algorithms
class PatternAlgorithm:
	## Pure, deterministic function
	## Returns a multiplier in [0, 1] (or slightly outside for artistic range)
	## Applied to base_color to produce final voxel RGB
	func shade(_voxel_xy: Vector2i, _face: int, _seed_val: int) -> float:
		return 1.0  # Override in subclasses

## Material definition (renamed from Material to avoid builtin conflict)
class MaterialDef:
	var id: String
	var base_color: Color
	var pattern_algorithm: PatternAlgorithm
	var flags: int = 0
	## D19: resistance/behavior — surface-independent, one row per material.
	## Same semantics as the retired MaterialResistanceTable.TABLE rows.
	var destroy_factor: float = 0.5
	var dent_factor: float = 0.0
	var crack_factor: float = 0.0
	## E-EMBER-01 (Director, 2026-08-13): does this material catch, and for how
	## long. A multiplier centred on 1.0, NOT a 0-1 probability — 0.0 is the one
	## value with structural meaning (never catches). Authoritative semantics and
	## the reason it lives in two readers: MaterialResistanceTable's own
	## DEFAULT_FLAMMABILITY note. Kept in sync here from the same JSON row so an
	## inspector/debug view of a MaterialDef is not missing a column the
	## destruction side acts on.
	var flammability: float = 0.0
	var burn_consumption: float = 0.0   ## M3-3 — how much of what catches burns away
	## Whether this material has a SLICE (wall) facade at all — false for the
	## floor-only materials (grass/dirt/gravel/sand today), which have no
	## `facade_<id>` asset and only ever render via the SLAB path.
	##
	## D34/E-SEAM-01 (Director, 2026-08-08) gave this field a second job: it is
	## now the WHOLE texture-family rule. `true` means every surface of this
	## material — wall, roof AND floor — bakes through `facade_<id>`, grayscale
	## + multiply; `false` means its floor bakes through the photographic
	## `slab_<id>` exception (organic ground, where hue IS the identity). See
	## BakePolicy.texture_for_material(), which owns the decision for both
	## sides of the seam.
	##
	## E-SEAM-03 retired `slab_full_color` here, which tried to express the
	## same split as a second field and was **never read by anything** — the
	## compositor decided from the texture id's own prefix, so the flag was
	## dead data that silently disagreed with the doc comment describing it.
	## Two fields could also encode a contradiction (has_facade false + not
	## full_color = a material with neither source); one cannot.
	var has_facade: bool = true

	func _init(p_id: String, p_color: Color, p_algo: PatternAlgorithm) -> void:
		id = p_id
		base_color = p_color
		pattern_algorithm = p_algo

	## Factory: parse MaterialDef from a JSON dict (res://materials/*.json),
	## same contract as BombDef.from_json()/PropDef.from_json().
	static func from_json(data: Dictionary) -> MaterialDef:
		var algo_key := String(data.get("pattern_algorithm", "flat"))
		var algo: PatternAlgorithm
		match algo_key:
			"stone": algo = StonePatternClass.new()
			"wood": algo = WoodPatternClass.new()
			"metal": algo = MetalPatternClass.new()
			_: algo = PatternAlgorithm.new()

		var color_arr: Array = data.get("base_color", [1.0, 1.0, 1.0])
		var color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2])) \
				if color_arr.size() >= 3 else Color.WHITE

		var def := MaterialDef.new(String(data.get("id", "")), color, algo)
		def.destroy_factor = float(data.get("destroy_factor", 0.5))
		def.dent_factor = float(data.get("dent_factor", 0.0))
		def.crack_factor = float(data.get("crack_factor", 0.0))
		def.flammability = float(data.get("flammability", 0.0))
		## M3-3: the AMOUNT axis. Parsed here as well as in
		## MaterialResistanceTable for D21's reason — one file per material, two
		## readers, no duplicated data. This reader serves render/inspection; the
		## table's serves destruction and runs autoload-free in selftests.
		def.burn_consumption = float(data.get("burn_consumption", 0.0))
		def.has_facade = bool(data.get("has_facade", false))
		return def

## Material registry
var registry: Dictionary = {}  # id → MaterialDef

func _init() -> void:
	pass

## Register a material
func register(material: MaterialDef) -> void:
	registry[material.id] = material
	print("[MaterialRegistry] Registered: %s (color: %.2f,%.2f,%.2f)" %
		[material.id, material.base_color.r, material.base_color.g, material.base_color.b])

## Get a material by ID
func get_material(p_id: String) -> MaterialDef:
	return registry.get(p_id, null)

## List all material IDs
func list_materials() -> Array:
	return registry.keys()

## Get material count
func count() -> int:
	return registry.size()

## D21: load the roster from registered data instead of hardcoding it.
## Two-tier (res:// then user://, user wins on id collision), same pattern as
## BombRegistry/PropRegistry/WeaponRegistry. Call once at boot (and at the
## top of any test that needs materials).
func register_defaults() -> void:
	load_from_disk()


func load_from_disk() -> void:
	_scan_dir(RES_MATERIALS_DIR)
	_scan_dir(USER_MATERIALS_DIR)


## ASSET_TREE_REFORM (2026-08-21): one folder per material, so a row lives at
## `<root>/<id>/<id>.json` beside that material's art rather than in a flat
## directory of 14 files.
##
## The walk is deliberately ONE level and name-matched — it opens `concrete/` and
## looks for `concrete.json`, not for any `*.json` it can find. A recursive glob
## would happily load a stray copy left in the wrong folder, and D21's whole
## point is one row per material with no duplicates: the `ground_concrete` /
## `concrete` disagreement is exactly what a lenient scan re-creates.
func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var row_path := dir_path.path_join(entry).path_join(entry + ".json")
			var file := FileAccess.open(row_path, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					var material_def := MaterialDef.from_json(parsed)
					if not material_def.id.is_empty():
						register(material_def)
		entry = dir.get_next()
