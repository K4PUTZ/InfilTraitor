class_name MapCompiler
extends RefCounted
## Turns a high-level MapSpec into the render-ready layout dict consumed by room.gd.
##
## A MapSpec is authored in PLAYABLE / INNER coordinates (the 18×36 segment space,
## same as LevelGraph). This compiler is the ONLY place that applies the buffer
## offset, so map definitions never carry "+5" math.
##
## MapSpec schema (all coords inner/segment space unless noted):
##   {
##     "id":            String,
##     "inner_size":    Vector2i,                 # playable segment size (e.g. 18×36)
##     "buffer":        int,                       # tiles of blocked margin per edge
##     "floor_tile":    String,
##     "agent_start":   Vector2i,
##     "access_points": Array[{"cell": Vector2i}], # OR set "access_from_graph": true
##     "access_from_graph": bool,                  # pull doors from LevelGraph connections
##     "rooms":         Array[{"rect": Rect2i, "doors": Array}],  # optional inner rooms
##     "dividers":      Array[{"cells": Array[Vector2i]}],        # internal walls w/ gates
##     "props":         Array[{"cell": Vector2i, "tile": String,    # crates / pillars
##                        "stack"?, "height"?}],                     #   stacked sprites + shadow height
##     "light_tracks":  Array[{"id": String, "cells": Array[Vector2i]}], # rails (internal coords)
##     "lights":        Array[{                                          # one of {x,y} | {track,slot}
##                        "x","y" | "track","slot",                      #   placement
##                        "radius","intensity",                          #   common
##                        "type"?,            # omni(default)|cone|directional|...
##                        "height_class"?,    # 0-4 (default OVERHEAD); legacy float "height" clamps
##                        "direction_deg"?,"cone_deg"?,                   # for cone/directional
##                        "flicker"?,"flicker_interval"?,                 # small/temporal (fire/candle)
##                      }],
##     "patrols":       Array[Array[Vector2i]],
##   }
##
## Output layout dict (grid/raw coords) — identical contract to the old builder:
##   {size, agent_start_cell, floor_tile_name, wall_tiles, structure_tiles,
##    blocked_cells, blocked_edges, enemy_defs, light_sources, exit_cells}

const LevelGraphClass = preload("res://godot/scripts/world/level_graph.gd")
const MapGeometryClass = preload("res://godot/scripts/world/maps/map_geometry.gd")
const SubcubeGeometryClass = preload("res://godot/scripts/world/maps/subcube_geometry.gd")

const REQUIRED_KEYS: Array[String] = ["inner_size", "agent_start"]


## Compiles a MapSpec into a render-ready layout dict.
## context: {connections: Dictionary, segment_grid_pos: Vector2i, seed: int} — only
## consulted when the spec opts into access_from_graph.
static func compile(spec: Dictionary, context: Dictionary = {}) -> Dictionary:
	_validate(spec)

	var buffer: int          = int(spec.get("buffer", 5))
	var inner_size: Vector2i = spec.get("inner_size", Vector2i(18, 36))
	var map_size := inner_size + Vector2i(buffer, buffer) * 2
	var offset := Vector2i(buffer, buffer)

	## --- access points (inner coords) ---------------------------------------
	var access_inner: Array[Dictionary] = _resolve_access_points(spec, context)

	## --- outer room ---------------------------------------------------------
	var outer_rect := Rect2i(offset, inner_size)
	var doors_raw: Array[Dictionary] = []
	for ap: Dictionary in access_inner:
		doors_raw.append({"cell": Vector2i(ap["cell"]) + offset})

	var room := MapGeometryClass.build_room(outer_rect, doors_raw)
	var blocked_map: Dictionary       = room["_blocked_map"]
	var blocked_edges: Array          = room.get("blocked_edges", [])
	var wall_tiles: Array[Dictionary] = room["wall_tiles"].duplicate()

	## --- buffer ring: block every tile outside the playable segment ---------
	for bx: int in range(map_size.x):
		for by: int in range(map_size.y):
			if bx < buffer or bx >= map_size.x - buffer or \
			   by < buffer or by >= map_size.y - buffer:
				var buf_cell := Vector2i(bx, by)
				if not blocked_map.has(buf_cell):
					blocked_map[buf_cell] = true

	## --- optional inner rooms ----------------------------------------------
	for room_def: Dictionary in spec.get("rooms", []):
		var inner_rect: Rect2i = room_def.get("rect", Rect2i())
		var rect_raw := Rect2i(inner_rect.position + offset, inner_rect.size)
		var inner_doors_raw: Array[Dictionary] = []
		for d in room_def.get("doors", []):
			inner_doors_raw.append({"cell": Vector2i(d["cell"]) + offset})
		var inner := MapGeometryClass.place_inner_room(outer_rect, rect_raw, inner_doors_raw, blocked_map)
		if inner.is_empty():
			continue
		wall_tiles.append_array(inner["wall_tiles"])
		blocked_edges += inner.get("blocked_edges", [])

	## --- internal divider walls with door gaps ------------------------------
	for divider: Dictionary in spec.get("dividers", []):
		for raw_cell in divider.get("cells", []):
			var cell: Vector2i = Vector2i(raw_cell) + offset
			if blocked_map.has(cell):
				continue
			wall_tiles.append({"cell": cell, "tile_name": "block_SE"})
			blocked_map[cell] = true
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0,  1)})

	## --- wall storeys (N-floor stacking) ------------------------------------
	## Ground course (level 0) is the full wall_tiles above (doors + dividers + inner rooms).
	## Upper courses are the SOLID outer ring (no door gaps) so doorways stay normal height with
	## wall above them; dividers are never stacked. Height applies to the OUTER walls only.
	## wall_height_override (from context, > 0) wins over the map's spec value for quick testing.
	var wall_height: int = int(context.get("wall_height_override", 0))
	if wall_height <= 0:
		wall_height = int(spec.get("wall_height", 1))
	wall_height = maxi(1, wall_height)

	var wall_levels: Array = [wall_tiles]
	if wall_height > 1:
		var solid_ring: Array = MapGeometryClass.build_room(outer_rect, [])["wall_tiles"]
		for _level in range(1, wall_height):
			var course: Array[Dictionary] = []
			for entry: Dictionary in solid_ring:
				course.append({
					"cell": entry["cell"],
					"tile_name": _upper_course_tile(String(entry["tile_name"])),
				})
			wall_levels.append(course)

	## Ceiling-fixture height (lamp + temporal knob), independent of the physical
	## wall storeys. Defaults to wall_height so maps that don't set it are unchanged.
	var ceiling_floors: int = maxi(1, int(spec.get("ceiling_floors", wall_height)))

	## --- props (crates / pillars) -------------------------------------------
	var agent_start_raw: Vector2i = Vector2i(spec.get("agent_start", Vector2i.ZERO)) + offset
	var structure_tiles: Array[Dictionary] = []
	for prop: Dictionary in spec.get("props", []):
		var cell: Vector2i = Vector2i(prop["cell"]) + offset
		if cell == agent_start_raw or blocked_map.has(cell):
			continue
		var stack: int = maxi(1, int(prop.get("stack", 1)))
		## Shadow height class: explicit "height" wins, else derived from the stack
		## (1 crate ≈ HUMAN, taller stacks → TALL). Single place so it stays tunable.
		var height: int = clampi(int(prop.get("height", _prop_height_for_stack(stack))), 1, 4)
		structure_tiles.append({
			"cell": cell, "tile_name": String(prop.get("tile", "crate_SE")),
			"stack": stack, "height": height,
		})
		blocked_map[cell] = true

	## --- exits, lights, patrols ---------------------------------------------
	var exit_cells: Array[Vector2i] = []
	for ap: Dictionary in access_inner:
		exit_cells.append(Vector2i(ap["cell"]) + offset)

	## Light tracks ("rails"): canonical cells (internal coords) a light snaps to
	## via {"track": id, "slot": i} for uniform shadows. Special lights stay free
	## via {"x","y"}. Buffer is applied here only (never in the map definition).
	var light_tracks: Dictionary = {}
	for track: Dictionary in spec.get("light_tracks", []):
		light_tracks[String(track.get("id", ""))] = track.get("cells", [])

	var light_sources: Array[Dictionary] = []
	for light: Dictionary in spec.get("lights", []):
		var l := light.duplicate()
		if light.has("track"):
			var cells: Array = light_tracks.get(String(light["track"]), [])
			if cells.is_empty():
				push_warning("MapCompiler: light references unknown/empty track '%s'" % light["track"])
				continue
			var slot: int = clampi(int(light.get("slot", 0)), 0, cells.size() - 1)
			var src: Vector2i = Vector2i(cells[slot])
			l["x"] = src.x + buffer
			l["y"] = src.y + buffer
			l.erase("track")
			l.erase("slot")
		else:
			l["x"] = int(light.get("x", 0)) + buffer
			l["y"] = int(light.get("y", 0)) + buffer
		light_sources.append(l)

	var enemy_defs := _build_enemy_defs(spec.get("patrols", []), offset, agent_start_raw, blocked_map, map_size)

	var result: Dictionary = {
		"size":             map_size,
		"buffer":           buffer,                ## tile margin per edge; used by room.gd for subcube layer alignment
		"playable_rect":    Rect2i(offset, inner_size),   ## inner playable area in grid coords
		"agent_start_cell": agent_start_raw,
		"floor_tile_name":  String(spec.get("floor_tile", "floor_SE")),
		"wall_tiles":       wall_tiles,        ## == wall_levels[0] (back-compat)
		"wall_levels":      wall_levels,        ## [floor] -> Array[{cell, tile_name}], floor 0 = ground
		"max_floors":       ceiling_floors,    ## ceiling-fixture height (lamp / temporal knob), independent of physical wall storeys
		"structure_tiles":  structure_tiles,
		"blocked_cells":    _dict_keys_to_vec2i_array(blocked_map),
		"blocked_edges":    blocked_edges,
		"enemy_defs":       enemy_defs,
		"light_sources":    light_sources,
		"exit_cells":       exit_cells,
	}
	result["subcube_geometry"] = SubcubeGeometryClass.build(result)
	return result


## --- private helpers --------------------------------------------------------

## Tile used for a wall cell on an UPPER course (storey ≥ 1).
## Single switch point: if straight wall_* sprites draw a top cap that shows mid-wall when
## stacked, return the matching solid block_* here for intermediate courses instead.
static func _upper_course_tile(ground_tile_name: String) -> String:
	return ground_tile_name


## Shadow height class (1-4) for a prop stack of N sprites. Tunable single source:
## 1 crate ≈ HUMAN(2), each extra crate adds a tier up to TALL/OVERHEAD(4).
static func _prop_height_for_stack(stack: int) -> int:
	return clampi(stack + 1, 1, 4)


static func _resolve_access_points(spec: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if bool(spec.get("access_from_graph", false)):
		var connections: Dictionary = context.get("connections", {})
		var seg_pos: Vector2i = context.get("segment_grid_pos", Vector2i(1, 1))
		for ap in LevelGraphClass.access_points_for(connections, seg_pos):
			result.append({"cell": Vector2i(ap["cell"])})
		return result
	for ap in spec.get("access_points", []):
		result.append({"cell": Vector2i(ap["cell"])})
	return result


static func _build_enemy_defs(
		patrols: Array,
		offset: Vector2i,
		agent_start_raw: Vector2i,
		blocked_map: Dictionary,
		map_size: Vector2i
) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for i in range(patrols.size()):
		var route: Array[Vector2i] = []
		for raw in patrols[i]:
			var cell: Vector2i = Vector2i(raw) + offset
			if cell == agent_start_raw:
				continue
			if blocked_map.has(cell):
				continue
			if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
				continue
			route.append(cell)

		if route.size() < 2:
			continue

		defs.append({
			"id": "guard_%d" % (i + 1),
			"route": route,
			"start_index": 0,
		})

	return defs


static func _dict_keys_to_vec2i_array(d: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in d.keys():
		cells.append(cell)
	return cells


static func _validate(spec: Dictionary) -> void:
	for key in REQUIRED_KEYS:
		if not spec.has(key):
			push_warning("MapCompiler: spec '%s' is missing required key '%s'" \
					% [spec.get("id", "?"), key])
