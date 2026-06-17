class_name ProceduralMap
extends RefCounted
## Procedural map generator — STUB for the next phase.
##
## The real generator will algorithmically emit a MapSpec (same vocabulary as the
## hand-authored maps in this folder) from a seed, then hand it to MapCompiler exactly
## like a permanent map. For now it returns a minimal empty room so "PROCEDURAL" is a
## valid, runnable map_id while the generator is built.


static func generate(seed_input: int) -> Dictionary:
	## TODO(next phase): derive rooms / dividers / props / patrols from seed_input.
	var _seed := seed_input
	return {
		"id":            "PROCEDURAL",
		"inner_size":    Vector2i(18, 36),
		"buffer":        5,
		"floor_tile":    "floor_SE",
		"agent_start":   Vector2i(9, 33),
		"access_from_graph": true,   ## doors come from LevelGraph connections
		"dividers":      [],
		"props":         [],
		"lights":        [{"x": 9, "y": 17, "height": 5.0, "radius": 9, "intensity": 0.85}],
		"patrols":       [],
	}
