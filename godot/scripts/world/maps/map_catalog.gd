class_name MapCatalog
extends RefCounted
## Resolves a map_id into a MapSpec. The single registry of permanent maps plus
## the routing point for the (future) procedural generator.
##
## room.gd calls get_spec(map_id, context); the returned spec is fed to
## MapCompiler.compile(). To add a permanent map: author a *_map.gd definition and
## add one branch here.

const PlaygroundMapClass = preload("res://godot/scripts/world/maps/definitions/playground_map.gd")
const Sigma01MapClass    = preload("res://godot/scripts/world/maps/definitions/sigma_01_map.gd")
const ProceduralMapClass = preload("res://godot/scripts/world/maps/definitions/procedural_map.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

const DEFAULT_MAP_ID := "PLAYGROUND"

static var _file_source: FileMapSourceClass = null


## Returns all map ids the catalog can resolve, in display order.
static func list_map_ids() -> Array[String]:
	if _file_source == null:
		_file_source = FileMapSourceClass.new()
	var ids: Array[String] = ["PLAYGROUND", "SIGMA_01", "CALIB", "PROCEDURAL"]  # code-defined, always available
	for file_id in _file_source.list_available().keys():
		if not ids.has(file_id):
			ids.append(file_id)
	return ids


## Returns the MapSpec for map_id. Unknown ids trigger error (no silent fallback).
## context: {connections, segment_grid_pos, seed} — forwarded to procedural/graph maps.
static func get_spec(map_id: String, context: Dictionary = {}) -> Dictionary:
	if _file_source == null:
		_file_source = FileMapSourceClass.new()

	var file_spec = _file_source.get_runtime_spec(map_id)
	if not file_spec.is_empty():
		return file_spec

	match map_id:
		"PLAYGROUND":
			return PlaygroundMapClass.spec()
		"CALIB":
			return PlaygroundMapClass.spec()
		"SIGMA_01":
			return Sigma01MapClass.spec()
		"PROCEDURAL":
			return ProceduralMapClass.generate(int(context.get("seed", 0)))
		_:
			push_error("[MapCatalog] Unknown map_id '%s' — returning empty spec" % map_id)
			return {}
