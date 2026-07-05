## MapSectionsV1 — Registration of board, walls, blocks, props, actors sections (v1)

class_name MapSectionsV1
extends RefCounted

static func register_all(registry) -> void:
	register_board(registry)
	register_walls(registry)
	register_blocks(registry)
	register_props(registry)
	register_actors(registry)

static func register_board(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"board",
		1,
		func(fragment: Dictionary) -> Dictionary:
			return {
				"inner_size": fragment.get("inner_size", [28, 18]),
				"buffer": fragment.get("buffer", 1),
				"floor_tile": fragment.get("floor_tile", "floor_SE")
			},
		func(raw: Dictionary) -> Dictionary:
			return {
				"inner_size": raw.get("inner_size", [28, 18]),
				"buffer": raw.get("buffer", 1),
				"floor_tile": raw.get("floor_tile", "floor_SE")
			},
		{},
		func() -> Dictionary:
			return {
				"inner_size": [28, 18],
				"buffer": 1,
				"floor_tile": "floor_SE"
			}
	))

static func register_walls(registry) -> void:
	var SectionOwner = registry.SectionOwner
	var migrations = {}
	migrations[1] = func(old: Dictionary) -> Dictionary:
		var edges = old.get("edges", [])
		for e in edges:
			if not e.has("storeys"):
				e["storeys"] = 1
		return { "edges": edges }
	
	registry.register(SectionOwner.new(
		"walls",
		2,
		func(fragment: Dictionary) -> Dictionary:
			return { "edges": fragment.get("edges", []) },
		func(raw: Dictionary) -> Dictionary:
			return { "edges": raw.get("edges", []) },
		migrations,
		func() -> Dictionary:
			return { "edges": [] }
	))

static func register_blocks(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"blocks",
		1,
		func(fragment: Dictionary) -> Dictionary:
			return { "items": fragment.get("items", []) },
		func(raw: Dictionary) -> Dictionary:
			return { "items": raw.get("items", []) },
		{},
		func() -> Dictionary:
			return { "items": [] }
	))

static func register_props(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"props",
		1,
		func(fragment: Dictionary) -> Dictionary:
			return { "items": fragment.get("items", []) },
		func(raw: Dictionary) -> Dictionary:
			return { "items": raw.get("items", []) },
		{},
		func() -> Dictionary:
			return { "items": [] }
	))

static func register_actors(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"actors",
		1,
		func(fragment: Dictionary) -> Dictionary:
			return {
				"agent_start": fragment.get("agent_start", [0, 0]),
				"guards": fragment.get("guards", [])
			},
		func(raw: Dictionary) -> Dictionary:
			return {
				"agent_start": raw.get("agent_start", [0, 0]),
				"guards": raw.get("guards", [])
			},
		{},
		func() -> Dictionary:
			return {
				"agent_start": [0, 0],
				"guards": []
			}
	))
