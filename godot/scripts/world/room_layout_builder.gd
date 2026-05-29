extends RefCounted
## Builds the larger multi-room tactical test layout.

const MAP_SIZE := Vector2i(29, 23)
const AGENT_START_CELL := Vector2i(6, 18)
const FLOOR_TILE := "floor_N"
const BORDER_TILE := "slab_N"
const CRATE_VARIANTS := ["crate_N", "crate_E", "crate_S", "crate_W"]
const CRATE_CELLS := [
	Vector2i(6, 5),
	Vector2i(19, 5),
	Vector2i(8, 16),
	Vector2i(21, 15),
	Vector2i(12, 11),
	Vector2i(15, 17),
	Vector2i(23, 8),
]
const ROOM_LAYOUTS := [
	{
		"rect": Rect2i(3, 3, 8, 6),
		"doors": [
			{"side": "south", "offset": 3},
		],
	},
	{
		"rect": Rect2i(16, 3, 9, 6),
		"doors": [
			{"side": "west", "offset": 2},
			{"side": "south", "offset": 4},
		],
	},
	{
		"rect": Rect2i(4, 13, 7, 6),
		"doors": [
			{"side": "north", "offset": 3},
			{"side": "east", "offset": 2},
		],
	},
	{
		"rect": Rect2i(16, 12, 9, 7),
		"doors": [
			{"side": "west", "offset": 3},
			{"side": "north", "offset": 4},
		],
	},
]


func build_layout() -> Dictionary:
	var structure_map: Dictionary = {}
	var blocked_map: Dictionary = {}
	var blocked_edges_map: Dictionary = {}

	_add_border(structure_map, blocked_map)
	_add_crates(structure_map, blocked_map)

	return {
		"size": MAP_SIZE,
		"agent_start_cell": AGENT_START_CELL,
		"floor_tile_name": FLOOR_TILE,
		"wall_tiles": [],
		"structure_tiles": _to_structure_tiles(structure_map),
		"blocked_cells": _to_blocked_cells(blocked_map),
		"blocked_edges": _to_blocked_edges(blocked_edges_map),
	}


func _add_border(structure_map: Dictionary, blocked_map: Dictionary) -> void:
	for x in range(MAP_SIZE.x):
		for y in range(MAP_SIZE.y):
			if x != 0 and x != MAP_SIZE.x - 1 and y != 0 and y != MAP_SIZE.y - 1:
				continue
			_set_structure_tile(structure_map, blocked_map, Vector2i(x, y), BORDER_TILE, true)


func _add_crates(structure_map: Dictionary, blocked_map: Dictionary) -> void:
	for i in range(CRATE_CELLS.size()):
		var cell: Vector2i = CRATE_CELLS[i]
		if cell == AGENT_START_CELL or blocked_map.has(cell) or structure_map.has(cell):
			continue
		_set_structure_tile(
			structure_map,
			blocked_map,
			cell,
			CRATE_VARIANTS[i % CRATE_VARIANTS.size()],
			true
		)


func _add_blocked_edge(blocked_edges_map: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	blocked_edges_map[_edge_key(from_cell, to_cell)] = {
		"from": from_cell,
		"to": to_cell,
	}


func _set_structure_tile(structure_map: Dictionary, blocked_map: Dictionary, cell: Vector2i, tile_name: String, blocked: bool) -> void:
	structure_map[cell] = tile_name
	if blocked:
		blocked_map[cell] = true
	else:
		blocked_map.erase(cell)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


func _to_structure_tiles(structure_map: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for cell in structure_map.keys():
		entries.append({
			"cell": cell,
			"tile_name": String(structure_map[cell]),
		})
	return entries


func _to_blocked_cells(blocked_map: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in blocked_map.keys():
		cells.append(cell)
	return cells


func _to_blocked_edges(blocked_edges_map: Dictionary) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for edge_key in blocked_edges_map.keys():
		edges.append(blocked_edges_map[edge_key])
	return edges