## MapSectionsV1 — Registration of board, walls, blocks, props, actors sections (v1)

class_name MapSectionsV1
extends RefCounted

static func register_all(registry) -> void:
	register_board(registry)
	register_walls(registry)
	register_blocks(registry)
	register_floor_zones(registry)
	register_props(registry)
	register_actors(registry)
	register_legacy_compiler(registry)

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
	var migrations = {}
	# BAKE-FACADE-PLANE-02-b: Blocks v1 → v2 migration: add size field
	migrations[1] = func(old: Dictionary) -> Dictionary:
		var items = old.get("items", [])
		for item in items:
			# v1 items implicitly have size [1, 1]
			if not item.has("size"):
				item["size"] = [1, 1]
		return { "items": items }
	
	registry.register(SectionOwner.new(
		"blocks",
		2,  # BAKE-FACADE-PLANE-02-b: Bumped from v1 to v2
		func(fragment: Dictionary) -> Dictionary:
			var items = fragment.get("items", [])
			# Validate and provide defaults
			for item in items:
				if not item.has("size"):
					item["size"] = [1, 1]
			return { "items": items },
		func(raw: Dictionary) -> Dictionary:
			var items = raw.get("items", [])
			for item in items:
				if not item.has("size"):
					item["size"] = [1, 1]
			return { "items": items },
		migrations,
		func() -> Dictionary:
			return { "items": [] }
	))

## floor_zones: author-declared floor material rects (floor-zone bake).
## Shape mirrors "blocks" ({gu, size, material}); v1, no migration needed —
## "size" is always present from the start, unlike blocks' v1->v2 history.
static func register_floor_zones(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"floor_zones",
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

static func register_legacy_compiler(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"legacy_compiler",
		1,
		func(fragment: Dictionary) -> Dictionary: return fragment.duplicate(true),
		func(raw: Dictionary) -> Dictionary: return raw.duplicate(true),
		{},
		func() -> Dictionary: return {}
	))
