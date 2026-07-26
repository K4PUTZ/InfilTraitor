## LightRegistry — Centralized light source management
##
## Responsibilities:
## ✓ Register/unregister lights
## ✓ Query lights by position/properties
## ✓ Track ownership and state
##
## Does NOT:
## ✗ Render lights
## ✗ Calculate shadows
## ✗ Compute exposure
## ✗ Manage visual effects
##
## Pure data storage and queries for the lighting system.

class_name LightRegistry
extends Node

const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

var _lights: Dictionary = {}  # light_id -> LightSource
var _lights_by_cell: Dictionary = {}  # Vector2i -> Array[LightSource]
var _next_id: int = 0

signal light_registered(light)
signal light_removed(light)

func _ready() -> void:
	# Registry is passive; initialization only
	_lights.clear()
	_lights_by_cell.clear()

## Register a new light source
func register_light(light) -> void:
	if light.light_id.is_empty():
		light.light_id = "light_%d" % _next_id
		_next_id += 1
	
	_lights[light.light_id] = light
	
	# Index by cell for spatial queries
	if not _lights_by_cell.has(light.cell):
		_lights_by_cell[light.cell] = []
	_lights_by_cell[light.cell].append(light)
	
	light_registered.emit(light)

## Remove a light source
func remove_light(light_id: String) -> void:
	if not _lights.has(light_id):
		return
	
	var light = _lights[light_id]
	_lights.erase(light_id)
	
	# Remove from spatial index
	if _lights_by_cell.has(light.cell):
		_lights_by_cell[light.cell].erase(light)
		if _lights_by_cell[light.cell].is_empty():
			_lights_by_cell.erase(light.cell)
	
	light_removed.emit(light)

## Get all registered lights
func get_all_lights() -> Array:
	var result: Array = []
	for light in _lights.values():
		result.append(light)
	return result

## Get all active lights
func get_active_lights() -> Array:
	var result: Array = []
	for light in _lights.values():
		if light.active:
			result.append(light)
	return result

## Check if registry is empty
func is_empty() -> bool:
	return _lights.is_empty()

## ============================================================================
## Temporal Updates (L-IMP-06) — Per-frame animation
## ============================================================================

## Update temporal state for all registered lights.
##
## Called every frame from room._process() to animate flicker, pulse, rotation.
## Returns array of lights that changed this frame (for rebuild triggering).
func update_temporal_all(delta: float) -> Array:
	var changed_lights: Array = []
	
	for light in _lights.values():
		light.update_temporal_state(delta)
		if light.changed_this_frame:
			changed_lights.append(light)
	
	return changed_lights

## Clear all lights
func clear_all() -> void:
	var light_ids = _lights.keys()
	for light_id in light_ids:
		remove_light(light_id)

## Debug output
func _to_string() -> String:
	var active_count = get_active_lights().size()
	var total_count = _lights.size()
	return "[LightRegistry total=%d active=%d]" % [total_count, active_count]
