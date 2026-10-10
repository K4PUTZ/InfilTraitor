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
##   {size, agent_start_cell, floor_tile_name, wall_tiles,
##    blocked_cells, blocked_edges, enemy_defs, light_sources, exit_cells}

const LevelGraphClass = preload("res://godot/scripts/world/level_graph.gd")
const MapGeometryClass = preload("res://godot/scripts/world/maps/map_geometry.gd")
const FloorOpeningsRef = preload("res://godot/scripts/geometry/floor_openings.gd")  ## R3D-SURFACES SM-6b: a real opening through the floor
## Legacy geometry computation integrated into EdgeExtractor (SLICE-02 refactor)

const REQUIRED_KEYS: Array[String] = ["inner_size", "agent_start"]

## Exterior perimeter walls are always this many storeys tall (fixed height, no config).
## Exterior walls are 3 storeys. No N-floor stacking.
## See FIX-EXTERIOR-WALLS-01 for rationale (deletion of legacy N-floor stacking).
const EXTERIOR_WALL_STOREYS: int = 3

## Ceiling height for lighting/scene composition, independent of wall height.
## Maps without explicit ceiling_floors use this default.
const DEFAULT_CEILING_FLOORS: int = 8


## Compiles a MapSpec into a render-ready layout dict.
## context: {connections: Dictionary, segment_grid_pos: Vector2i, seed: int} — only
## consulted when the spec opts into access_from_graph.
## Returns empty Dictionary if validation fails (caller must check).
static func compile(spec: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not _validate(spec):
		return {}

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
		var material: String = String(divider.get("material", "concrete"))
		for raw_cell in divider.get("cells", []):
			var cell: Vector2i = Vector2i(raw_cell) + offset
			if blocked_map.has(cell):
				continue
			wall_tiles.append({"cell": cell, "tile_name": "solidblock_%s" % material})
			blocked_map[cell] = true
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0,  1)})

	## --- exterior walls (fixed height, no stacking) ------------------------------------
	## FIX-EXTERIOR-WALLS-01: exterior walls are now first-class Edges with fixed EXTERIOR_WALL_STOREYS
	## storey height. Deleted legacy N-floor stacking mechanism (wall_height, wall_levels duplication).
	## wall_tiles is the ground course (doors + dividers + inner rooms); it's the only course.
	## EdgeExtractor assigns EXTERIOR_WALL_STOREYS to every exterior-wall Edge.
	var wall_levels: Array = [wall_tiles]

	## --- solid GU blockers (full-cell, multi-storey, material-aware) ---------
	## BAKE-FACADE-PLANE-02-b: Support size field for rectangular blocks
	## DESTRUCTION D1-ROOF: also collected into solid_block_instances (below) —
	## the ORIGINAL per-GU declaration (gu, size, storeys, material), offset-
	## adjusted, forwarded in the return dict so room_builder.gd can place a
	## roof above each real block without re-deriving footprint/height/material
	## from the edge registry solidblock_ produces (which represents the
	## block's WALLS, not "this GU is a block worth roofing" directly).
	var solid_block_instances: Array[Dictionary] = []
	for block: Dictionary in spec.get("blocks", []):
		var base_gu: Vector2i = Vector2i(block.get("gu", Vector2i.ZERO))
		var size_raw = block.get("size", [1, 1])
		var size: Vector2i = size_raw if size_raw is Vector2i else Vector2i(int(size_raw[0]), int(size_raw[1]))
		var storeys: int = maxi(1, int(block.get("storeys", 1)))
		var material: String = String(block.get("material", "concrete"))
		solid_block_instances.append({
			"gu_cell": base_gu + offset,
			"size": size,
			"storeys": storeys,
			"material": material,
		})

		# Expand size to fill rectangle [gu.x, gu.y] to [gu.x + size.x, gu.y + size.y)
		for x in range(size.x):
			for y in range(size.y):
				var cell: Vector2i = base_gu + Vector2i(x, y) + offset
				if blocked_map.has(cell):
					continue
				for storey in range(storeys):
					while wall_levels.size() <= storey:
						wall_levels.append([])
					wall_levels[storey].append({"cell": cell, "tile_name": "solidblock_%s" % material})
				blocked_map[cell] = true

	## --- free-standing roofs (R3D-7): a roof is an entity of its own ----------
	## Same {gu, size, storeys, material} rectangle as a block, without the walls: `storeys` is the height the roof
	## sits on top of. Forwarded as `roof_instances`; room_builder generates their slabs through the very code a
	## block's roof uses. `kind` ("flat" today) is the seam for pointed and diagonal roofs.
	var roof_instances: Array[Dictionary] = []
	for roof: Dictionary in spec.get("roofs", []):
		var roof_gu: Vector2i = Vector2i(roof.get("gu", Vector2i.ZERO))
		var roof_size_raw = roof.get("size", [1, 1])
		var roof_size: Vector2i = roof_size_raw if roof_size_raw is Vector2i else Vector2i(int(roof_size_raw[0]), int(roof_size_raw[1]))
		roof_instances.append({
			"gu_cell": roof_gu + offset,
			"size": roof_size,
			"storeys": maxi(1, int(roof.get("storeys", 1))),
			"material": String(roof.get("material", "concrete")),
			"kind": String(roof.get("kind", "flat")),
		})

	## --- floor-zone bake regions (author-declared ground material rects) -----
	## Mirrors solid_block_instances' shape exactly (gu_cell + size + one
	## property), kept as a rectangle list — not pre-expanded per-GU — so
	## perspective_mapper.gd can rotate it with the same two-corner math
	## blocks already use. room_builder.gd expands this into a per-GU dict
	## and flood-fills same-material regions into anchored components.
	var floor_zone_instances: Array[Dictionary] = []
	for zone: Dictionary in spec.get("floor_zones", []):
		var zone_gu: Vector2i = Vector2i(zone.get("gu", Vector2i.ZERO))
		var zone_size_raw = zone.get("size", [1, 1])
		var zone_size: Vector2i = zone_size_raw if zone_size_raw is Vector2i else Vector2i(int(zone_size_raw[0]), int(zone_size_raw[1]))
		floor_zone_instances.append({
			"gu_cell": zone_gu + offset,
			"size": zone_size,
			"material": String(zone.get("material", "")),
		})
	floor_zone_instances.append_array(_buffer_floor_zones(spec.get("floor_zones", []), inner_size, buffer))

	## --- ground decals (R3D-SURFACES S2): `at` is GU on the voxel lattice (multiples of 1/8 GU), shifted by the buffer like every other position ---
	var ground_decal_instances: Array = []
	for decal in spec.get("ground_decals", []):
		var at_raw = decal.get("at", null)
		var kind: String = String(decal.get("kind", ""))
		if not (at_raw is Array) or at_raw.size() != 2 or kind.is_empty() \
				or not is_equal_approx(float(at_raw[0]) * 8.0, round(float(at_raw[0]) * 8.0)) \
				or not is_equal_approx(float(at_raw[1]) * 8.0, round(float(at_raw[1]) * 8.0)):
			push_error("[MapCompiler] ground_decals: %s needs `at` [x, y] on the voxel lattice (multiples of 1/8 GU) and a `kind`; skipped" % str(decal))
			continue
		ground_decal_instances.append({
			"at": Vector2(float(at_raw[0]), float(at_raw[1])) + Vector2(offset),
			"kind": kind,
			"variant": int(decal.get("variant", -1)),
			"rot": float(decal.get("rot", 0.0)),
		})

	## --- floor_openings (R3D-SURFACES SM-6b): whole-GU rectangles, shifted by the buffer; `FloorOpenings.normalise` validates the rest ---
	var floor_opening_instances: Array = []
	for opening in spec.get("floor_openings", []):
		var o_gu = opening.get("gu", null)
		var o_size = opening.get("size", [1, 1])
		if not (o_gu is Array) or o_gu.size() != 2 or not (o_size is Array) or o_size.size() != 2:
			push_error("[MapCompiler] floor_openings: %s needs `gu` [x, y] and `size` [w, h] in whole GU; skipped" % str(opening))
			continue
		var normalised: Dictionary = FloorOpeningsRef.normalise({
			"gu_cell": Vector2i(int(o_gu[0]), int(o_gu[1])) + offset, "size": Vector2i(int(o_size[0]), int(o_size[1])),
			"pattern": opening.get("pattern", "slats"), "axis": opening.get("axis", "x"), "pitch": opening.get("pitch", FloorOpeningsRef.DEFAULT_PITCH),
			"material": opening.get("material", FloorOpeningsRef.DEFAULT_MATERIAL)})
		if not normalised.is_empty():
			floor_opening_instances.append({"gu_cell": Vector2i(int(o_gu[0]), int(o_gu[1])) + offset, "size": Vector2i(int(o_size[0]), int(o_size[1])),
				"pattern": normalised["pattern"], "axis": normalised["axis"], "pitch": normalised["pitch"], "material": normalised["material"]})

	## --- ground_vents (R3D-SURFACES SM-6): `at` in GU on the voxel lattice, shifted by the buffer; the kind is checked by `VentEmitter` ---
	var ground_vent_instances: Array = []
	for vent in spec.get("ground_vents", []):
		var vent_at = vent.get("at", null)
		var vent_kind: String = String(vent.get("kind", ""))
		if not (vent_at is Array) or vent_at.size() != 2 or vent_kind.is_empty() \
				or not is_equal_approx(float(vent_at[0]) * 8.0, round(float(vent_at[0]) * 8.0)) \
				or not is_equal_approx(float(vent_at[1]) * 8.0, round(float(vent_at[1]) * 8.0)):
			push_error("[MapCompiler] ground_vents: %s needs `at` [x, y] on the voxel lattice and a `kind`; skipped" % str(vent))
			continue
		ground_vent_instances.append({"at": Vector2(float(vent_at[0]), float(vent_at[1])) + Vector2(offset), "kind": vent_kind,
			"depth": "shaft" if String(vent.get("depth", "floor")) == "shaft" else "floor"})

	## --- ground_scatter (R3D-SURFACES SM-2): zones in raw GU (the buffer applied, like every position); expanded later, in `GroundScatter` ---
	var ground_scatter_items: Array = []
	for item in spec.get("ground_scatter", []):
		var zone_raw = item.get("zone", null)
		var scatter_kind: String = String(item.get("kind", ""))
		var kinds_raw = item.get("kinds", null)
		var kinds_ok: bool = kinds_raw == null
		if kinds_raw is Array and kinds_raw.size() > 0:
			kinds_ok = true
			for k in kinds_raw:
				kinds_ok = kinds_ok and k is Array and k.size() == 2 and k[0] is String and (k[1] is float or k[1] is int) and float(k[1]) > 0.0
		var ok_zone: bool = zone_raw is Array and zone_raw.size() == 4
		if ok_zone:
			for v in zone_raw:
				ok_zone = ok_zone and (v is float or v is int)
		if not ok_zone or not kinds_ok or (scatter_kind.is_empty() and kinds_raw == null) or float(zone_raw[2]) <= 0.0 or float(zone_raw[3]) <= 0.0:
			push_error("[MapCompiler] ground_scatter: %s needs `zone` [x, y, w, h] (w, h > 0) and a `kind` or `kinds` [[kind, weight], ...]; skipped" % str(item))
			continue
		var entry: Dictionary = {
			"zone": Rect2(Vector2(float(zone_raw[0]), float(zone_raw[1])) + Vector2(offset), Vector2(float(zone_raw[2]), float(zone_raw[3]))),
			"kind": scatter_kind,
			"seed": int(item.get("seed", 0)),
			"density": float(item.get("density", 0.0)),
		}
		if kinds_raw is Array:
			var mix: Array = []
			for k in kinds_raw:
				mix.append([String(k[0]), float(k[1])])
			entry["kinds"] = mix
		var scale_raw = item.get("scale", null)
		if scale_raw is Array and scale_raw.size() == 2:
			entry["scale"] = Vector2(float(scale_raw[0]), float(scale_raw[1]))
		ground_scatter_items.append(entry)

	## --- material_tints (R3D-SURFACES): material id -> Color (a target albedo), validated here, never shifted or rotated ---
	var material_tints: Dictionary = {}
	var tints_raw = spec.get("material_tints", {})
	if tints_raw is Dictionary:
		for material_id in tints_raw:
			var rgb = tints_raw[material_id]
			var ok: bool = rgb is Array and rgb.size() == 3
			if ok:
				for channel in rgb:
					ok = ok and (channel is float or channel is int) and float(channel) >= 0.0 and float(channel) <= 1.0
			if not ok:
				push_error("[MapCompiler] material_tints: '%s' needs [r, g, b] with each channel 0..1 (got %s); skipped" % [material_id, str(rgb)])
				continue
			material_tints[String(material_id)] = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))

	## --- damage_materials (D13): flat pass-through, no offset/rotation to apply ---
	var damage_materials: Array[String] = []
	for m in spec.get("damage_materials", []):
		damage_materials.append(String(m))

	## Ceiling-fixture height (lamp + temporal knob), independent of the physical
	## wall storeys. Defaults to DEFAULT_CEILING_FLOORS for tall scene composition.
	var ceiling_floors: int = maxi(1, int(spec.get("ceiling_floors", DEFAULT_CEILING_FLOORS)))

	## --- voxel props (crates etc.) — native PropDef-driven, distinct from legacy sprite "props" ---
	var voxel_prop_instances: Array = []
	for prop_item: Dictionary in spec.get("voxel_props", []):
		var gu_raw = prop_item.get("gu", Vector2i.ZERO)
		var gu_cell: Vector2i = Vector2i(gu_raw) if gu_raw is Vector2i else Vector2i(int(gu_raw[0]), int(gu_raw[1]))
		var cell: Vector2i = gu_cell + offset
		if blocked_map.has(cell):
			continue
		var vox_offset_raw = prop_item.get("vox_offset", [0, 0])
		var vox_offset: Vector2i = vox_offset_raw if vox_offset_raw is Vector2i else Vector2i(int(vox_offset_raw[0]), int(vox_offset_raw[1]))
		voxel_prop_instances.append({
			"gu_cell": cell,
			"def_id": String(prop_item.get("def", "")),
			"storey": int(prop_item.get("storey", 0)),
			"vox_offset": vox_offset,
			"rot": int(prop_item.get("rot", 0)),
		})
		blocked_map[cell] = true

	var agent_start_raw: Vector2i = Vector2i(spec.get("agent_start", Vector2i.ZERO)) + offset

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

	## --- half-thickness panels (M3-2b) ---------------------------------------
	## Offset-adjusted here and nowhere else (architecture Rule 7: maps use
	## internal coords, the buffer is applied only in MapCompiler). The face
	## string travels as authored; EdgeExtractor resolves it to a Face and builds
	## the one-sided Edge, because that is where every other edge is born.
	var panel_instances: Array[Dictionary] = []
	for panel: Dictionary in spec.get("panels", []):
		var panel_gu: Vector2i = Vector2i(panel.get("gu", Vector2i.ZERO))
		panel_instances.append({
			"gu_cell": panel_gu + offset,
			"face": String(panel.get("face", "")),
			"material": String(panel.get("material", "glass")),
			"storeys": maxi(1, int(panel.get("storeys", 1))),
			"start_storey": maxi(0, int(panel.get("start_storey", 0))),
			## GLASS G-D9 (§9.6): expand the sparse `bands` authoring into a
			## dense {rel_level: material} override dict here, once. `levels` is
			## an inclusive [lo, hi] pair — FileMapSource's JSON converter folds a
			## 2-int array into a Vector2i, so accept either shape.
			"material_bands": _compile_panel_bands(panel.get("bands", [])),
			## GLASS G-D16 / V-D (§9.6): the per-placement behaviour class, as the
			## authored NAME. Parsed (and loud-failed) once, in EdgeExtractor, so a
			## typo is reported against the panel rather than swallowed here.
			"glass_class": String(panel.get("glass_class", "")),
		})

	var result: Dictionary = {
		"size":             map_size,
		"buffer":           buffer,                ## tile margin per edge; used by room.gd for voxel layer alignment
		"playable_rect":    Rect2i(offset, inner_size),   ## inner playable area in grid coords
		"agent_start_cell": agent_start_raw,
		"floor_tile_name":  String(spec.get("floor_tile", "floor_SE")),
		"wall_tiles":       wall_tiles,        ## == wall_levels[0] (back-compat)
		"wall_levels":      wall_levels,        ## [floor] -> Array[{cell, tile_name}], floor 0 = ground
		"max_floors":       ceiling_floors,    ## ceiling-fixture height (lamp / temporal knob), independent of physical wall storeys
		"voxel_prop_instances": voxel_prop_instances,  ## PropDef-driven voxel props (PROP-01)
		"solid_block_instances": solid_block_instances,  ## Original per-GU block declarations, offset-adjusted (DESTRUCTION D1-ROOF)
		"roof_instances": roof_instances,  ## R3D-7: free-standing roofs (an entity of their own), offset-adjusted
		"floor_zone_instances": floor_zone_instances,  ## Author-declared floor material rects, offset-adjusted (floor-zone bake)
		"panel_instances":  panel_instances,   ## M3-2b: half-thickness elements, offset-adjusted
		"ground_decal_instances": ground_decal_instances,  ## R3D-SURFACES S2: floor marks, offset-adjusted, base grid only (never rotated)
		"damage_materials":  damage_materials,  ## D13: map's declared damage-atom-bake material list
		"floor_opening_instances": floor_opening_instances,  ## R3D-SURFACES SM-6b: real openings through the floor (raw GU), carved by SlabGenerator
		"ground_vent_instances": ground_vent_instances,  ## R3D-SURFACES SM-6: floor vents (raw GU), a cosmetic plume each
		"layout":           _compile_layout(spec, offset),  ## CAPTURE_RAILS CR-1: the map's anchors (raw GU), read by `MapLayout.load_compiled()`
		"capture":          _compile_capture(spec, offset),  ## CAPTURE_RAILS CR-3: rails and takes (dev only); explicit centres shifted
		"ground_scatter_items": ground_scatter_items,  ## R3D-SURFACES SM-2: scatter zones (raw GU), expanded by GroundScatter at attach
		"material_tints":   material_tints,    ## R3D-SURFACES: material id -> Color, the colour it reads as in this map (cosmetic)
		"blocked_cells":    _dict_keys_to_vec2i_array(blocked_map),
		"blocked_edges":    blocked_edges,
		"enemy_defs":       enemy_defs,
		"light_sources":    light_sources,
		"exit_cells":       exit_cells,
		"junction_overrides": _compile_junction_overrides(spec, offset),  ## BAKE-FIX-02: junction column overrides
	}
	## Voxel geometry integration via EdgeExtractor (see SLICE-02 refactor)
	## Legacy direct computation replaced by edge-driven seam building
	return result


## --- private helpers --------------------------------------------------------


## GLASS G-D9 (§9.6): expand a panel's sparse `bands` array into a dense
## {rel_level: int -> material: String} override dict. Each band is
## `{"levels": [lo, hi], "material": "brick"}` with an INCLUSIVE level range,
## panel-relative (0 … storeys*8 − 1). FileMapSource's JSON converter turns a
## 2-int `[lo, hi]` into a Vector2i, so both shapes are accepted. A later band
## wins over an earlier one on an overlapping level. Returns {} for no bands —
## an ordinary panel is byte-for-byte unchanged.
static func _compile_panel_bands(bands) -> Dictionary:
	var out: Dictionary = {}
	if not (bands is Array):
		return out
	for band in bands:
		if not (band is Dictionary):
			continue
		var raw = band.get("levels", null)
		var lo: int
		var hi: int
		if raw is Vector2i:
			lo = raw.x
			hi = raw.y
		elif raw is Array and raw.size() >= 2:
			lo = int(raw[0])
			hi = int(raw[1])
		else:
			push_error("[MapCompiler] panel band has no valid `levels` [lo, hi]: %s" % [band])
			continue
		var mat := String(band.get("material", ""))
		if mat == "":
			push_error("[MapCompiler] panel band %s has no `material`" % [band])
			continue
		for lvl in range(mini(lo, hi), maxi(lo, hi) + 1):
			out[lvl] = mat
	return out


## CAPTURE_RAILS CR-1 — the `layout` section (inner GU, validated at load by `MapLayout.validate_section()`) shifted by the buffer
## into raw GU: THE place rule 7 applies it. Points become `Vector3(x, y, z)` (z in storeys); a region's box becomes `min` / `max`.
## `tallest_storeys` is `@map`'s height, from the geometry that is declared (blocks, panels, roofs).
static func _compile_layout(spec: Dictionary, offset: Vector2i) -> Dictionary:
	var section: Dictionary = spec.get("layout", {})
	var shift := Vector3(offset.x, offset.y, 0.0)
	var out: Dictionary = {
		"envelope": (section.get("envelope", {}) as Dictionary).duplicate(true),
		"tallest_storeys": tallest_storeys_of(spec.get("blocks", []), spec.get("panels", []),
			spec.get("roofs", [])),
		"poi": [], "regions": [], "objectives": [],
	}
	for p in section.get("poi", []):
		var prow: Dictionary = {"id": str(p["id"]), "at": _layout_point(p["at"]) + shift, "tags": p.get("tags", []).duplicate()}
		if p.has("extent"):
			prow["extent"] = _layout_point(p["extent"])   ## a SIZE: never shifted
		(out["poi"] as Array).append(prow)
	for r in section.get("regions", []):
		(out["regions"] as Array).append({"id": str(r["id"]), "min": _layout_point(r["box"]["min"]) + shift,
			"max": _layout_point(r["box"]["max"]) + shift, "tags": r.get("tags", []).duplicate()})
	for o in section.get("objectives", []):
		var row: Dictionary = {"id": str(o["id"]), "kind": str(o["kind"]), "tags": o.get("tags", []).duplicate()}
		if o.has("region"):
			row["region"] = str(o["region"])
		else:
			row["at"] = _layout_point(o["at"]) + shift
		(out["objectives"] as Array).append(row)
	return out


## The tallest storey any geometry reaches (blocks, panels with their start storey, roofs) — `@map`'s height.
static func tallest_storeys_of(blocks: Array, panels: Array, roofs: Array) -> float:
	var top: float = 1.0
	for b in blocks:
		top = maxf(top, float(b.get("storeys", 1)))
	for p in panels:
		top = maxf(top, float(p.get("start_storey", 0)) + float(p.get("storeys", 1)))
	for r in roofs:
		top = maxf(top, float(r.get("storeys", 1)))
	return top


## CAPTURE_RAILS CR-3 — the `capture` section as authored, an `explicit` key's `centre` (inner GU) shifted by the buffer like every
## other coordinate (rule 7). Anchors are named by id, so nothing else moves.
static func _compile_capture(spec: Dictionary, offset: Vector2i) -> Dictionary:
	var out: Dictionary = (spec.get("capture", {}) as Dictionary).duplicate(true)
	for r in out.get("rails", []):
		for k in r.get("keys", []):
			if k.has("centre") and k["centre"] is Array and (k["centre"] as Array).size() == 2:
				k["centre"] = [float(k["centre"][0]) + offset.x, float(k["centre"][1]) + offset.y]
	return out


static func _layout_point(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]) if v.size() == 3 else 0.0)


## CAPTURE_RAILS CR-1 — the ONLY inverse of the buffer shift (rule 7): a raw GU point back to the file's inner GU (the editor's path).
static func raw_to_inner(raw: Vector2, buffer: int) -> Vector2:
	return raw - Vector2(buffer, buffer)


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


static func _validate(spec: Dictionary) -> bool:
	var is_valid := true
	for key in REQUIRED_KEYS:
		if not spec.has(key):
			push_error("[MapCompiler] spec '%s' is missing required key '%s'" \
					% [spec.get("id", "?"), key])
			is_valid = false
	return is_valid


## BAKE-FIX-02: Compile junction overrides from MapSpec
## Each entry in spec["junction_overrides"] contains:
##   {"gu": Vector2i (inner coords), "material"?: String, "facade_enabled"?: bool}
## R3D-FINISH F2 (2026-10-04, Director: "mesmo chão estendido"): the buffer ring is ground too, and it is the SAME ground as the
## playable edge it continues. Each ring cell takes the floor-zone material of the nearest playable cell (the zones are in INNER
## coordinates, last rect wins, as `RoomBuilder` expands them); a ring cell whose nearest playable cell declares no zone stays
## undeclared (the "earth" sentinel, as every undeclared GU). The result is returned as rects in RAW coordinates (buffer applied,
## here, like every other position), one per run of equal material along a row: `RoomBuilder` joins them to the playable zone by
## 4-adjacency, so the ring shares that zone's texture anchor and the ground reads as one surface. No objects: populating the
## ring is the procedural-maps milestone's.
static func _buffer_floor_zones(zones: Array, inner_size: Vector2i, buffer: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if buffer <= 0:
		return out
	var inner_material: Dictionary = {}  ## inner Vector2i -> material
	for zone: Dictionary in zones:
		var zone_gu: Vector2i = Vector2i(zone.get("gu", Vector2i.ZERO))
		var size_raw = zone.get("size", [1, 1])
		var zone_size: Vector2i = size_raw if size_raw is Vector2i else Vector2i(int(size_raw[0]), int(size_raw[1]))
		var material: String = String(zone.get("material", ""))
		if material == "":
			continue
		for zx: int in range(zone_size.x):
			for zy: int in range(zone_size.y):
				inner_material[zone_gu + Vector2i(zx, zy)] = material
	var map_size: Vector2i = inner_size + Vector2i(buffer, buffer) * 2
	for by: int in range(map_size.y):
		var run_start: int = -1
		var run_material: String = ""
		for bx: int in range(map_size.x + 1):
			var material: String = ""
			var in_ring: bool = false
			if bx < map_size.x:
				in_ring = bx < buffer or bx >= map_size.x - buffer or by < buffer or by >= map_size.y - buffer
				if in_ring:
					var nearest := Vector2i(clampi(bx - buffer, 0, inner_size.x - 1), clampi(by - buffer, 0, inner_size.y - 1))
					material = String(inner_material.get(nearest, ""))
			if run_start >= 0 and (material != run_material or not in_ring):
				out.append({"gu_cell": Vector2i(run_start, by), "size": Vector2i(bx - run_start, 1), "material": run_material})
				run_start = -1
			if material != "" and run_start < 0:
				run_start = bx
				run_material = material
	return out


## Returns array with gu_cell converted to raw coords (with buffer applied)
static func _compile_junction_overrides(spec: Dictionary, offset: Vector2i) -> Array:
	var result: Array = []
	for override in spec.get("junction_overrides", []):
		var gu_inner = Vector2i(override.get("gu", Vector2i.ZERO))
		var gu_raw = gu_inner + offset
		result.append({
			"gu_cell": gu_raw,
			"material": override.get("material", ""),
			"facade_enabled": override.get("facade_enabled", true),
		})
	return result
