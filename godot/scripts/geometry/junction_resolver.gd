## Geometry Module — Junction Resolver: fills V-junction corner columns.
## Rewritten (JUNCTION-02): the previous version reconstructed GU cells from
## voxel-index vertex coordinates and divided them back down by 8. That broke
## whenever a vertex used the "+7" near-edge offset (true for one axis of
## almost every vertex _get_edge_vertices produced) instead of a clean
## multiple of 8 — integer division silently floored into the wrong bucket,
## so the resolver picked a cell adjacent to the elbow instead of the true
## diagonal notch. This version never touches voxel coordinates for the
## detection step: it stays in GU-cell space the whole time, using the faces
## already recorded on each Edge.
## Scope: V-junctions (2 walls) and free-standing wall ends (3 walls, all
## genuinely open — e.g. a divider stopping next to a gate) both get filler
## columns, one per adjacent (non-opposite) pair of occupied faces at the
## cell. A true T-junction (a wall butting flush into another, already-solid
## wall) also presents as 3 faces on a naive count, but EdgeExtractor's
## exposure culling (see edge_extractor.gd) already removes the spurious
## flush-contact face before this ever sees it, so it correctly reduces to 2
## opposite (straight-through) faces — 0 columns, nothing to fill. This only
## works because that culling fix landed first; see JUNCTION-01b prompt.
## X-junctions (4 walls) are intentionally skipped — assumed already covered
## by surrounding wall geometry; revisit only if a real gap is reported there.
class_name JunctionResolver


## Container for a corner column at a V-junction.
class JunctionColumn:
	var id: String                ## E-JUNCTION-01: "JCOL_%d_%d" % gu_cell — one column per
	                               ## diagonal GU (resolve()'s own cells_seen guarantees that),
	                               ## so this is unique without a counter. The destruction
	                               ## pipeline keys every container by id (affected dict,
	                               ## container_of, census) the same way it does for Slice/Slab.
	var gu_cell: Vector2i         ## the diagonal GU that owns this column (outside the elbow)
	var voxel_pos: Vector2i       ## the voxel position of the column
	var storey_count: int         ## height (span between start_storey and end)
	var start_storey: int         ## starting storey level
	var material: String          ## material of the walls this column completes (or derived material)
	var facade_enabled: bool      ## whether this column should use baked facade (default true; BAKE-FIX-02: D-BAKE-3)
	var override_material: String ## optional override material; empty string = use derived material from edges
	var face_a: int               ## face of first edge (NW/NE/SE/SW) — BAKE-FIX-06: for mirroring neighbor lookup
	var face_b: int               ## face of second edge — BAKE-FIX-06: for mirroring neighbor lookup
	var edge_a_id: String         ## first edge's ID — BAKE-FIX-06: for neighbor voxel resolution
	var edge_b_id: String         ## second edge's ID — BAKE-FIX-06: for neighbor voxel resolution
	var voxels: Array[Voxel]      ## the voxel objects
	var dirty_count: int = 0      ## E-JUNCTION-01: sum of child Voxel dirty flags — Voxel's own
	                               ## contract (see voxel.gd's _parent_container_id doc) needs
	                               ## increment_dirty()/decrement_dirty() on whatever owns it,
	                               ## the same as Slice/Slab already provide. LEAK-CYCLE-01: the
	                               ## voxels point back by instance id, so this column must stay
	                               ## alive (room._junction_columns holds it) while they are used.

	func _init(p_gu: Vector2i, p_voxel_pos: Vector2i, p_storey_count: int, p_start_storey: int = 0, p_material: String = "concrete", p_facade_enabled: bool = true, p_override_material: String = "", p_face_a: int = 0, p_face_b: int = 1, p_edge_a_id: String = "", p_edge_b_id: String = ""):
		id = "JCOL_%d_%d" % [p_gu.x, p_gu.y]
		gu_cell = p_gu
		voxel_pos = p_voxel_pos
		storey_count = p_storey_count
		start_storey = p_start_storey
		material = p_material
		facade_enabled = p_facade_enabled
		override_material = p_override_material
		face_a = p_face_a
		face_b = p_face_b
		edge_a_id = p_edge_a_id
		edge_b_id = p_edge_b_id
		## E-JUNCTION-01 (2026-08-13): a JunctionColumn used to be voxel
		## POSITIONS only — `_render_junction_column()` writes tiles straight
		## from `voxel_pos`/`storey_count`, never through a Voxel object, so
		## there was never any per-voxel damage state to read or write. One
		## real Voxel per level, mirroring SliceGenerator._create_slice()'s
		## own loop (a Slice gets 8 positions per level; a column is one
		## position, stacked).
		voxels = []
		for level_offset in range(storey_count * GeometryCoords.LEVELS_PER_STOREY):
			var level: int = start_storey * GeometryCoords.LEVELS_PER_STOREY + level_offset
			voxels.append(Voxel.new(voxel_pos, level, self))

	func increment_dirty() -> void:
		dirty_count += 1

	func decrement_dirty() -> void:
		if dirty_count > 0:
			dirty_count -= 1

	func _to_string() -> String:
		var facade_str = " (no facade)" if not facade_enabled else ""
		var override_str = " [override: %s]" % override_material if override_material != "" else ""
		if start_storey > 0:
			return "JunctionColumn{gu=%s, voxel=%s, storeys=%d, start=%d, material=%s%s%s}" % [gu_cell, voxel_pos, storey_count, start_storey, material, facade_str, override_str]
		return "JunctionColumn{gu=%s, voxel=%s, storeys=%d, material=%s%s%s}" % [gu_cell, voxel_pos, storey_count, material, facade_str, override_str]


## Resolve V-junctions from a registry of edges.
## Returns an Array of JunctionColumn objects, one per detected elbow.
##
## BAKE-FIX-10 Architecture Decision (Option B — Deliberate Post-hoc Application):
## Junction override application is deliberately implemented as a post-processing step
## in room_builder.gd::_apply_junction_overrides(), NOT within resolve() itself.
## The columns are created with hardcoded facade_enabled=true, override_material=""
## here; room_builder then applies the layout["junction_overrides"] entries after
## resolution completes. This is a conscious architectural choice:
## - Pro: clean separation between detection (resolve) and application (room_builder)
## - Pro: overrides are applied consistently alongside other layout processing
## - Pro: simpler merge of multiple data sources (map_compiler output → layout → application)
## The post-hoc pipeline (map_compiler → room_builder::_apply_junction_overrides) is
## now verified end-to-end by BAKE-FIX-10::Test 2.
static func resolve(registry: EdgeRegistry) -> Array:
	var result: Array = []
	var cells_seen: Dictionary = {}  ## Vector2i -> true; each edge touches 2 cells, visit each once

	for edge in registry.all_edges():
		for gu in [edge.gu_a, edge.gu_b]:
			if cells_seen.has(gu):
				continue
			cells_seen[gu] = true

			## Which faces of THIS cell have a wall, and which Edge put it there.
			var faces_at_cell: Dictionary = {}  ## face(int) -> Edge
			for e in registry.edges_touching_gu(gu):
				var face_here: int = e.face_a if e.gu_a == gu else e.face_b
				faces_at_cell[face_here] = e

			## V-junction (2 walls) and free-standing wall ends (3 walls,
			## all genuinely open — see class doc comment) both close
			## notches, one filler column per adjacent (non-opposite) pair
			## of occupied faces. X-junction (4 walls) stays out of scope.
			if faces_at_cell.size() < 2 or faces_at_cell.size() > 3:
				continue

			var faces: Array = faces_at_cell.keys()
			for i in range(faces.size()):
				for j in range(i + 1, faces.size()):
					var fa: int = faces[i]
					var fb: int = faces[j]

					## Opposite faces (NW-SE or NE-SW) = a straight wall
					## passing through the cell, not a turn — including the
					## real-T case (see class doc comment), which reduces
					## to exactly this after EdgeExtractor's culling fix.
					if fb == Face.opposite(fa):
						continue

					var edge_a: Edge = faces_at_cell[fa]
					var edge_b: Edge = faces_at_cell[fb]

					## fa, fb adjacent and non-opposite → their deltas sum
					## to a clean (±1, ±1): the cell diagonal to the elbow,
					## outside both walls — the visual notch that needs the
					## filler column.
					var d: Vector2i = Face.delta(fa) + Face.delta(fb)
					var diagonal_cell: Vector2i = gu + d

					# Compute storey span: from min(start_storey) to max(start_storey + storey_count)
					var min_start := mini(edge_a.start_storey, edge_b.start_storey)
					var max_end := maxi(edge_a.start_storey + edge_a.storey_count, edge_b.start_storey + edge_b.storey_count)
					var junction_storey_count := max_end - min_start

					## The one voxel inside diagonal_cell nearest the elbow
					## — the corner of its 8×8 block that actually touches
					## `gu`.
					var origin := GeometryCoords.gu_to_voxel_origin(diagonal_cell)
					var last := GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
					var local_x := last if d.x < 0 else 0
					var local_y := last if d.y < 0 else 0
					var voxel_pos := origin + Vector2i(local_x, local_y)

					# BAKE-FIX-06: Pass face_a, face_b, and edge IDs for mirroring and override lookup
					result.append(JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start, edge_a.material, true, "", fa, fb, edge_a.id, edge_b.id))

	return result
