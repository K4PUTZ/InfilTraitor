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

const DEFAULT_MAP_ID := "PLAYGROUND"


## Returns all map ids the catalog can resolve, in display order.
static func list_map_ids() -> Array[String]:
	return ["PLAYGROUND", "SIGMA_01", "PROCEDURAL"]


## Returns the MapSpec for map_id. Unknown ids fall back to the default.
## context: {connections, segment_grid_pos, seed} — forwarded to procedural/graph maps.
static func get_spec(map_id: String, context: Dictionary = {}) -> Dictionary:
	match map_id:
		"PLAYGROUND":
			return PlaygroundMapClass.spec()
		"SIGMA_01":
			return Sigma01MapClass.spec()
		"PROCEDURAL":
			return ProceduralMapClass.generate(int(context.get("seed", 0)))
		_:
			push_error("MapCatalog: unknown map_id '%s' — falling back to %s" % [map_id, DEFAULT_MAP_ID])
			return PlaygroundMapClass.spec()
