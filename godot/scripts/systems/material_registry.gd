## MaterialRegistry — Material definitions and pattern algorithms
##
## Materials are code, not files. Each material couples a base color with a
## deterministic pattern algorithm that creates per-voxel luminance variation.
## This is the only place where pixels are created; all other baking stages
## operate on these pixels.

class_name MaterialRegistry

# Import constants
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")

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
	
	func _init(p_id: String, p_color: Color, p_algo: PatternAlgorithm) -> void:
		id = p_id
		base_color = p_color
		pattern_algorithm = p_algo

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
