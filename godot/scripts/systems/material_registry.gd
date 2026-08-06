## MaterialRegistry — Material definitions, pattern algorithms, and resistance
## (destroy/dent/crack) — D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06):
## material properties are registered dynamic data, never hardcoded and never
## map-coupled. Two-tier disk load (res:// then user://, user wins on
## collision), same pattern as BombRegistry/PropRegistry/WeaponRegistry.
##
## D19/D20: one row per material, surface-independent for behavior (this
## file). Texture identity is a SEPARATE, surface-keyed axis
## (BakePolicy.facade_for_material / slab_for_material) — a material's
## `pattern_algorithm`/`base_color` here still feed the SLICE (wall) render
## path only; the SLAB (floor/ceiling) path's WHITE-vs-tinted modulate is
## decided by the texture id's own prefix at bake time, not by a field on
## this class (see bake_compositor.gd's _modulate_for_mode).

class_name MaterialRegistry

# Import constants
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const StonePatternClass = preload("res://godot/scripts/systems/stone_pattern.gd")
const WoodPatternClass = preload("res://godot/scripts/systems/wood_pattern.gd")
const MetalPatternClass = preload("res://godot/scripts/systems/metal_pattern.gd")

const RES_MATERIALS_DIR := "res://materials"
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
	## Whether this material has a SLICE (wall) facade at all — false for the
	## floor-only materials (grass/dirt/gravel/sand today), which have no
	## `facade_<id>` asset and only ever render via the SLAB path.
	var has_facade: bool = true
	## Whether this material's SLAB (floor/ceiling) render is a full-color
	## photographic source (BAKE_SYSTEM_REFERENCE.md B2's exception) — read
	## by the compositor's modulate decision for `slab_<id>` pages only, never
	## for `facade_<id>` (SLICE) pages regardless of this value (see
	## bake_compositor.gd's _modulate_for_mode). NOT the retired
	## `MaterialDef.full_color`, which was read uniformly across both surfaces
	## and could not represent a material (concrete) that is tinted on walls
	## and full-color on floors at once.
	var slab_full_color: bool = false

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
		def.has_facade = bool(data.get("has_facade", false))
		def.slab_full_color = bool(data.get("slab_full_color", false))
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


func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file := FileAccess.open(dir_path.path_join(fname), FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					var material_def := MaterialDef.from_json(parsed)
					if not material_def.id.is_empty():
						register(material_def)
		fname = dir.get_next()
