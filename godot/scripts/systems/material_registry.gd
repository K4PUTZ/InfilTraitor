## MaterialRegistry — Material definitions and pattern algorithms
##
## Materials are code, not files. Each material couples a base color with a
## deterministic pattern algorithm that creates per-voxel luminance variation.
## This is the only place where pixels are created; all other baking stages
## operate on these pixels.

class_name MaterialRegistry

# Import constants
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const StonePatternClass = preload("res://godot/scripts/systems/stone_pattern.gd")
const WoodPatternClass = preload("res://godot/scripts/systems/wood_pattern.gd")
const MetalPatternClass = preload("res://godot/scripts/systems/metal_pattern.gd")

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
	## Floor-bake full-color exception (BAKE_SYSTEM_REFERENCE.md B2): when true,
	## the compositor forces a WHITE page modulate instead of tinting by
	## base_color, so a photographic facade source keeps its real RGB.
	var full_color: bool = false

	func _init(p_id: String, p_color: Color, p_algo: PatternAlgorithm, p_full_color: bool = false) -> void:
		id = p_id
		base_color = p_color
		pattern_algorithm = p_algo
		full_color = p_full_color

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

## Populate the registry with the four canon materials (MAP_MATTRESS D2).
## Call once at boot (and at the top of any test that needs materials).
func register_defaults() -> void:
	register(MaterialDef.new("concrete", Color(0.62, 0.62, 0.62), StonePatternClass.new()))
	register(MaterialDef.new("stone",    Color(0.55, 0.55, 0.58), StonePatternClass.new()))
	register(MaterialDef.new("wood",     Color(0.66, 0.47, 0.31), WoodPatternClass.new()))
	register(MaterialDef.new("metal",    Color(0.49, 0.53, 0.56), MetalPatternClass.new()))
	register_ground_defaults()


## Floor-zone bake materials (v1: 5 representative photographic ground
## textures, full color — see MaterialDef.full_color). base_color here is
## only a plausible placeholder for the unbaked/MATERIAL_ONLY fallback path;
## the baked page modulate ignores it (forced WHITE).
func register_ground_defaults() -> void:
	register(MaterialDef.new("ground_grass",    Color(0.42, 0.55, 0.29), PatternAlgorithm.new(), true))
	register(MaterialDef.new("ground_concrete", Color(0.60, 0.58, 0.53), PatternAlgorithm.new(), true))
	register(MaterialDef.new("ground_dirt",     Color(0.50, 0.38, 0.27), PatternAlgorithm.new(), true))
	register(MaterialDef.new("ground_gravel",   Color(0.55, 0.52, 0.49), PatternAlgorithm.new(), true))
	register(MaterialDef.new("ground_sand",     Color(0.76, 0.67, 0.51), PatternAlgorithm.new(), true))
