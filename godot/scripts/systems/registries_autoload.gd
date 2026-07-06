## Registries — Global autoload for MaterialRegistry and PropRegistry
## Replaces Engine.set_meta() pseudo-singletons with real Godot autoload.
## This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by
## Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup()
## after ScriptServer::finish_languages() has begun dismantling the script language.
##
## Strategy: Use weak references to avoid holding strong refs that prevent GC cleanup.

extends Node

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

# Store weak references to registries to avoid holding strong refs during shutdown
var _material_registry_ref: WeakRef = null
var _prop_registry_ref: WeakRef = null
var _file_map_source_ref: WeakRef = null


func _ready() -> void:
	print("[Registries] Autoload initialized")


## Ensure material registry exists and is initialized
func ensure_material_registry() -> MaterialRegistryClass:
	var reg = null
	if _material_registry_ref != null:
		reg = _material_registry_ref.get_ref()
	
	if reg == null:
		reg = MaterialRegistryClass.new()
		reg.register_defaults()
		_material_registry_ref = weakref(reg)
		print("[Registries] Material registry initialized with defaults")
	
	return reg


## Ensure prop registry exists and is initialized
func ensure_prop_registry() -> PropRegistryClass:
	var reg = null
	if _prop_registry_ref != null:
		reg = _prop_registry_ref.get_ref()
	
	if reg == null:
		reg = PropRegistryClass.new()
		reg.load_from_disk()
		_prop_registry_ref = weakref(reg)
		print("[Registries] Prop registry initialized from disk")
	
	return reg


## Get material registry (ensure called first, or handle null)
func get_material_registry() -> MaterialRegistryClass:
	return ensure_material_registry()


## Get prop registry (ensure called first, or handle null)
func get_prop_registry() -> PropRegistryClass:
	return ensure_prop_registry()


## Ensure the file-backed map source exists and is initialized.
## Moved here from MapCatalog's own `static var _file_source` (FIX-SHUTDOWN-CRASH-01b):
## a GDScript static var is owned by the Script resource itself, so its held RefCounted
## instance was being torn down during GDScriptLanguage::finish() (script-server teardown),
## the same unsafe window Engine.set_meta() writes were torn down in. Autoload Nodes are
## freed during normal SceneTree cleanup, well before ScriptServer::finish_languages() runs,
## so owning it here is lifecycle-safe the same way material/prop registries are.
func ensure_file_map_source() -> FileMapSourceClass:
	var src = null
	if _file_map_source_ref != null:
		src = _file_map_source_ref.get_ref()

	if src == null:
		src = FileMapSourceClass.new()
		_file_map_source_ref = weakref(src)
		print("[Registries] File map source initialized")

	return src


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


# Expose property for compatibility with existing checks
var material_registry: MaterialRegistryClass:
	get: 
		if _material_registry_ref != null:
			var ref = _material_registry_ref.get_ref()
			if ref != null:
				return ref
		return null
	set(val): 
		if val != null:
			_material_registry_ref = weakref(val)
		else:
			_material_registry_ref = null



