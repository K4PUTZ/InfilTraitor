## Registries — Global autoload for MaterialRegistry and PropRegistry
## Replaces Engine.set_meta() pseudo-singletons with real Godot autoload.
## This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by
## Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup()
## after ScriptServer::finish_languages() has begun dismantling the script language.
##
## Strategy: Keep registries as WeakRef or initialize on-demand, avoid persistent
## strong references that survive to Main::cleanup().

extends Node

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")

# Store one instance per registry; weak refs would work better but complicate access
var _material_registry: MaterialRegistryClass = null
var _prop_registry: PropRegistryClass = null


func _ready() -> void:
	print("[Registries] Autoload initialized")


## Ensure material registry exists and is initialized
func ensure_material_registry() -> MaterialRegistryClass:
	if _material_registry == null:
		_material_registry = MaterialRegistryClass.new()
		_material_registry.register_defaults()
		print("[Registries] Material registry initialized with defaults")
	return _material_registry


## Ensure prop registry exists and is initialized
func ensure_prop_registry() -> PropRegistryClass:
	if _prop_registry == null:
		_prop_registry = PropRegistryClass.new()
		_prop_registry.load_from_disk()
		print("[Registries] Prop registry initialized from disk")
	return _prop_registry


## Get material registry (ensure called first, or handle null)
func get_material_registry() -> MaterialRegistryClass:
	return ensure_material_registry()


## Get prop registry (ensure called first, or handle null)
func get_prop_registry() -> PropRegistryClass:
	return ensure_prop_registry()


# Baked atlas storage (loaded during baking, used during render)
var _baked_atlas = null  # BakedAtlas object
var _baked_atlas_source_ids: Dictionary = {}  # page_idx → source_id
var _bake_timestamp: int = 0


## Store baked atlas (called by room_builder during baking)
func set_baked_atlas(atlas, source_ids: Dictionary, timestamp: int) -> void:
	_baked_atlas = atlas
	_baked_atlas_source_ids = source_ids
	_bake_timestamp = timestamp
	print("[Registries] Baked atlas stored: %d pages" % [source_ids.size()])


## Get baked atlas
func get_baked_atlas():
	return _baked_atlas


## Get baked atlas source IDs
func get_baked_atlas_source_ids() -> Dictionary:
	return _baked_atlas_source_ids


## Get bake timestamp
func get_bake_timestamp() -> int:
	return _bake_timestamp


# Expose direct property access for bake_compositor compatibility check
var material_registry: MaterialRegistryClass:
	get: return _material_registry
	set(val): _material_registry = val


