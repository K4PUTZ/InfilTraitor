## Registries — Global autoload for MaterialRegistry and PropRegistry
## Replaces Engine.set_meta() pseudo-singletons with real Godot autoload.
## This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by
## Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup()
## after ScriptServer::finish_languages() has begun dismantling the script language.
##
## Strategy: the AUTOLOAD is what fixes the crash — a real Node with a real
## lifetime, torn down before the script language is dismantled. The weak
## references below were belt-and-braces on top of that.
##
## REG-STRONG-01 (2026-08-13, measured): the belt was costing real work every
## frame it was worn. Nothing else in the game holds a registry, so each one was
## being collected between accesses and REBUILT FROM DISK on the next call —
## measured on one real grenade throw: the bomb registry re-read `bombs/*.json`
## **4 times**, the material registry re-scanned `materials/*.json` **twice**.
## They are strong refs now, which is what `_frame_cache` below already does for
## exactly the same reason (FRAME-MEM-01, and it shipped without bringing the
## shutdown crash back — the precedent is six lines down from the bug).

extends Node

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")
const BombRegistryClass = preload("res://godot/scripts/systems/destruction/bomb_registry.gd")
const WeaponRegistryClass = preload("res://godot/scripts/systems/destruction/weapon_registry.gd")
const CollectibleFrameCacheClass = preload("res://godot/scripts/systems/collectible_frame_cache.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

## REG-STRONG-01: strong, so a registry is read from disk ONCE per run. See the
## header for the measurement that changed these from WeakRef.
var _material_registry = null
var _prop_registry = null
var _bomb_registry = null
var _weapon_registry = null
## FRAME-MEM-01: a STRONG ref, unlike the registries above. A weak ref would let
## the shared frame set be collected the moment no prop happened to hold it, and
## the next prop would re-read 480 PNGs from disk — the exact cost this cache
## exists to pay once.
var _frame_cache = null
var _file_map_source_ref: WeakRef = null


func _ready() -> void:
	print("[Registries] Autoload initialized")


## Ensure material registry exists and is initialized
func ensure_material_registry() -> MaterialRegistryClass:
	var reg = _material_registry
	
	if reg == null:
		reg = MaterialRegistryClass.new()
		reg.register_defaults()
		_material_registry = reg
		print("[Registries] Material registry initialized with defaults")
	
	return reg


## Ensure prop registry exists and is initialized
func ensure_prop_registry() -> PropRegistryClass:
	var reg = _prop_registry
	
	if reg == null:
		reg = PropRegistryClass.new()
		reg.load_from_disk()
		_prop_registry = reg
		print("[Registries] Prop registry initialized from disk")
	
	return reg


## Get material registry (ensure called first, or handle null)
func get_material_registry() -> MaterialRegistryClass:
	return ensure_material_registry()


## Get prop registry (ensure called first, or handle null)
func get_prop_registry() -> PropRegistryClass:
	return ensure_prop_registry()


## Ensure bomb registry exists and is initialized
func ensure_bomb_registry() -> BombRegistryClass:
	var reg = _bomb_registry

	if reg == null:
		reg = BombRegistryClass.new()
		reg.load_from_disk()
		_bomb_registry = reg
		print("[Registries] Bomb registry initialized from disk")

	return reg


## Get bomb registry (ensure called first, or handle null)
func get_bomb_registry() -> BombRegistryClass:
	return ensure_bomb_registry()


## Ensure weapon registry exists and is initialized (WEAPON_MASTER_PLAN Part 1)
func ensure_weapon_registry() -> WeaponRegistryClass:
	var reg = _weapon_registry

	if reg == null:
		reg = WeaponRegistryClass.new()
		reg.load_from_disk()
		_weapon_registry = reg
		print("[Registries] Weapon registry initialized from disk")

	return reg


## Get weapon registry (ensure called first, or handle null)
func get_weapon_registry() -> WeaponRegistryClass:
	return ensure_weapon_registry()


## FRAME-MEM-01: shared baked-frame textures — see CollectibleFrameCache for the
## measured reason this is shared rather than per-instance.
func get_frame_cache() -> CollectibleFrameCacheClass:
	if _frame_cache == null:
		_frame_cache = CollectibleFrameCacheClass.new()
		print("[Registries] Collectible frame cache initialized")
	return _frame_cache


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


# Expose property for compatibility with existing checks
var material_registry: MaterialRegistryClass:
	get:
		return _material_registry
	set(val):
		_material_registry = val



