## Occlusion Module — Computes which geometry occludes the agent
##
## POLICY: O1 — Occlusion is VIEW, not STATE
## - _occluded_cells is owned solely by this module
## - Never writes Voxel.visible, never uses dirty flag, never persists
## - NEVER reads _active_perspective (coordinates already rotated when entering)
##
## POLICY: O4′ — One view-space formula, no rotation applied
## The map is rebuilt rotated; we compute in already-rotated coordinates.
##
## POLICY: O5 — Depth is (x + y) in view-space, never z_index
## Isometric diamond layout: screen-y ∝ (x + y). Greater sum = nearer camera.

class_name OcclusionSet

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FaceMod = preload("res://godot/scripts/geometry/face.gd")

## ============================================================================
## TUNING (exposed as adjustable, for Director to dial against screenshots)
## ============================================================================

## OCC-08 (2026-07-14): the agent's own screen silhouette — used for the trigger
## test (does an EDGE's whole slice tower visually overlap him). Should track
## agent.gd's SILHOUETTE_WIDTH/HEIGHT (44/61 at time of writing); kept as separate
## constants rather than importing agent.gd, to keep this a dependency-free "pure
## geometry" module — re-sync by hand if the agent's on-screen size ever changes.
var silhouette_half_width_px: float = 22.0
var silhouette_height_px: float = 61.0

## How many hops along the wall's own connectivity graph the ring falloff reaches
## from a triggering edge. Ring alphas themselves live in VoxelRenderer.GHOST_ALPHAS
## (3 entries) — this must stay one less than that array's size.
const MAX_RING: int = 2

## OCC-10 (2026-07-14): superseded the OCC-09 pixel-threshold reveal cutoff.
## Director's call after seeing it live: the OCC-09 reveal (lower storeys popping
## back to fully opaque, pixel-threshold-timed) looked worse than the ghost it
## replaced. Simpler rule, no agent-relative math needed: an occluded edge's own
## bottom BASE_VISIBLE_LEVELS levels (full width, both faces — a fixed 8×N×2
## footprint) are left COMPLETELY UNTOUCHED, always reading as solid ground-truth
## geometry; everything above that ghosts at the ring alpha exactly as it always
## has (OCC-08/O6). Fixed, not derived — no pixel math, no agent-relative
## geometry for this part any more.
const BASE_VISIBLE_LEVELS: int = 2

## ============================================================================
## STATE (owned solely by this module)
## ============================================================================

## The set of voxel cells that occlude the agent, mapped to ring index (0/1/2).
## Key: Vector2i voxel cell (voxel-grid coordinate space)
var _occluded_cells: Dictionary = {}

## Per-occluded-edge shape data — what OcclusionWireframeOverlay draws. Each entry:
##   {"corner_a": Vector2i, "corner_b": Vector2i, "min_level": int, "max_level": int}
## "min_level" here is where GHOSTING STARTS (the edge's true base plus
## BASE_VISIBLE_LEVELS) — the wireframe only ever needs to cover the translucent
## band, never the always-visible base underneath it (OCC-10).
## Deliberately NOT raw Slice objects (OCC-09): a Slice's own span is never
## partial — this is the atomic unit that can be, once part of it needs to draw
## differently (or not at all) from the rest.
var _occluded_edges: Array = []

## Recomputation counter (for verification of cadence)
var _recompute_count: int = 0

## ============================================================================
## API
## ============================================================================

## Query the occluded-cell set.
## Returns: Dictionary of voxel COLUMN (x,y only) → {"ring": int, "min_level": int}.
## "min_level" is where ghosting starts (OCC-10: the edge's true base plus
## BASE_VISIBLE_LEVELS) — a column key alone cannot tell
## VoxelRenderer.apply_occlusion() which of ITS levels are the always-visible
## base versus the ghosted rest, so the level floor has to travel with the cell.
func get_occluded_cells() -> Dictionary:
	return _occluded_cells.duplicate()

## Per-occluded-edge shape data (already vertically clipped) — see _occluded_edges.
func get_occluded_edges() -> Array:
	return _occluded_edges.duplicate()

## Get the ring index for a given voxel cell, or -1 if not occluded.
func get_ring_index(voxel_cell: Vector2i) -> int:
	if not _occluded_cells.has(voxel_cell):
		return -1
	return _occluded_cells[voxel_cell]["ring"]

## Check if a voxel cell is occluded.
func is_occluded(voxel_cell: Vector2i) -> bool:
	return _occluded_cells.has(voxel_cell)

## Get the recomputation counter for verification.
func get_recompute_count() -> int:
	return _recompute_count

## ============================================================================
## RECOMPUTATION (called from room.gd on agent step + view change)
## ============================================================================

## Recompute the occluded-cell set given current agent position(s) and geometry.
## Called on: agent.step_finished signal, _set_perspective(), hover cell change
##
## Args:
##   agent_cells: Array[Vector2i] — one or more origin cells (gameplay grid cells).
##     First entry is always the agent's real position; subsequent entries are
##     additional points of interest (e.g. hover cell for preview).
##   slices: Array[Slice] — every Slice currently rendered (room._edge_registry.all_slices())
##   room_size: Vector2i — size of room in gameplay grid units
##   junction_columns: Array[JunctionResolver.JunctionColumn] — corner filler columns
##     (room._junction_columns); ghosted only when BOTH walls they fill the elbow
##     between are themselves occluded (OCC-10, see the loop below).
func recompute(agent_cells, slices: Array, room_size: Vector2i, junction_columns: Array = []) -> void:
	## Backward compatibility: accept single Vector2i as well as Array[Vector2i]
	var origins: Array[Vector2i] = []
	if agent_cells is Vector2i:
		origins = [agent_cells]
	elif agent_cells is Array:
		origins = agent_cells
	else:
		push_error("[OCC-HOVER-01] recompute() expects Vector2i or Array[Vector2i], got %s" % type_string(typeof(agent_cells)))
		return
	
	var slices_by_edge := _group_slices_by_edge(slices)
	var occlusion := compute_edge_occlusion(origins, slices_by_edge, room_size)
	var edges: Array = occlusion["edges"]
	var new_segments: Array = occlusion["segments"].duplicate()

	var new_occluded: Dictionary = {}
	var ring_by_edge_id: Dictionary = {}
	for e in edges:
		ring_by_edge_id[e["edge_id"]] = e["ring"]
		for slice in slices_by_edge.get(e["edge_id"], []):
			for voxel in slice.voxels:
				## OCC-09/OCC-10: min_level travels WITH the cell — a column key
				## alone would leave VoxelRenderer.apply_occlusion() unable to tell
				## which of a column's levels are the always-visible base versus
				## the ghosted rest above it.
				## OCC-26 (2026-07-18): max_level travels too. The erase used to run
				## to the top of every layer, which also ate the ROOF's 1-voxel
				## border row sitting in the wall's own columns (levels above the
				## wall's top) — the visible roof edge then fell back one voxel
				## deeper, reading as a ~4-screen-px seam between the roofline and
				## the wireframe's top cap (Director's "wireframe shifted 3-4 px",
				## erase-diff measured). A cell claimed by two edges keeps the
				## wider vertical span.
				var span_min: int = e["min_level"]
				var span_max: int = e["max_level"]
				if new_occluded.has(voxel.grid_pos):
					var prev: Dictionary = new_occluded[voxel.grid_pos]
					span_min = mini(span_min, prev["min_level"])
					span_max = maxi(span_max, prev["max_level"])
				new_occluded[voxel.grid_pos] = {"ring": e["ring"], "min_level": span_min, "max_level": span_max}

	## OCC-10/OCC-13/OCC-14 (2026-07-14): junction filler columns aren't part of
	## any Slice/Edge of their own — Director's rule, confirmed on annotated
	## screenshots: ghost one only when BOTH edges it fills the elbow between are
	## occluded; a column with only one occluded neighbor stays fully visible.
	## Always ring 0 (the minimum alpha) — it has no ring of its own to inherit,
	## and picking between its two neighbors' rings would be an arbitrary
	## tie-break. It also gets its own thin "lightsaber" wireframe unit — a real
	## 1×1-voxel box (its own actual footprint), not a flat line, per the
	## Director's OCC-14 correction ("ainda parece que as paredes viraram folhas
	## de papel, e os lightsabers parecem apenas uma linha"). Director's diagram:
	## "EXTRA COLUMNS FILLING V JUNCTIONS MUST FOLLOW THE SAME DESIGN" (a base
	## band below, wireframe above, just like an edge's own unit).
	for column in junction_columns:
		if not (ring_by_edge_id.has(column.edge_a_id) and ring_by_edge_id.has(column.edge_b_id)):
			continue
		var col_base_level: int = column.start_storey * GeometryCoordsMod.LEVELS_PER_STOREY
		var col_max_level: int = col_base_level + column.storey_count * GeometryCoordsMod.LEVELS_PER_STOREY - 1
		var col_ghost_start: int = mini(col_base_level + BASE_VISIBLE_LEVELS, col_max_level + 1)
		## OCC-26: junction fillers cap their erase at their own top as well.
		new_occluded[column.voxel_pos] = {"ring": 0, "min_level": col_ghost_start, "max_level": col_max_level}
		## OCC-21e (2026-07-14): lightsaber wireframe disabled again — Director's
		## call after seeing it live. Fill ghosting above is untouched; only the
		## wireframe segment is disabled. Re-enable by uncommenting if needed.
		#new_segments.append({
		#	"near_a": column.voxel_pos, "near_b": column.voxel_pos + Vector2i(1, 0),
		#	"far_a": column.voxel_pos + Vector2i(0, 1), "far_b": column.voxel_pos + Vector2i(1, 1),
		#	"min_level": col_ghost_start, "max_level": col_max_level, "ring": 0,
		#})

	# Only update if the set changed
	if new_occluded != _occluded_cells:
		_occluded_cells = new_occluded
		_occluded_edges = new_segments
		_recompute_count += 1
		if _recompute_count % 10 == 0 or new_occluded.size() > 0:
			print_debug("[OcclusionSet] Recomputed: %d cells, %d segments (count=%d)" % [
				_occluded_cells.size(), _occluded_edges.size(), _recompute_count
			])

## ============================================================================
## CORE COMPUTATION (pure geometry, no I/O)
## ============================================================================

func _group_slices_by_edge(slices: Array) -> Dictionary:
	var by_edge: Dictionary = {}
	for slice in slices:
		if slice.voxels.is_empty():
			continue
		if not by_edge.has(slice.edge_id):
			by_edge[slice.edge_id] = []
		by_edge[slice.edge_id].append(slice)
	return by_edge


## OCC-08/OCC-09/OCC-10 (2026-07-14): decide occlusion per EDGE — the real
## wall-column object (one grid boundary, every storey it has) — with a genuine
## 2D (screen-X AND screen-Y) overlap test against the agent's own silhouette,
## spread outward along the wall's own connectivity graph up to MAX_RING hops.
## Replaces O3″ — see Decisions O3‴, O3⁗ and O3⁗′.
##
## OCC-HOVER-01 (2026-07-15): Multi-origin support — accepts array of agent cells
## (typically [agent_pos] or [agent_pos, hover_cell]), performs trigger test from
## EACH origin, union of seeds feeds BFS. This reveals geometry occluding ANY of
## the provided origins, enabling hover-based occlusion preview without duplicating
## the entire computation pipeline.
##
## Why per-edge, not per-slice (OCC-07): a slice is one storey of one face: a tall
## wall is several stacked slices on the SAME edge. Grouping by edge is what lets
## "does ANY storey of this wall reach the agent's height" be answered once, for the
## wall as a whole, instead of per storey.
##
## Why a real 2D overlap test, not corridor-width + depth-cap (O3″): those two
## ad-hoc tunables (silhouette_half_width_px as a corridor, max_depth_voxels as a
## distance cap) were both proxies for the same real question — "does this
## structure's own screen footprint overlap the agent's own screen footprint?" A
## short nearby wall and a distant but TALL structure both answer that question
## correctly under a real screen-Y (height) test; neither ad-hoc tunable could
## express "far away but tall enough to still reach over him", which is a real,
## reported case.
##
## Why a graph walk for the ring falloff, not distance: two edges are "adjacent"
## if they share a grid VERTEX (corner) — real wall topology, not a distance
## metric. This is what makes a corner or a 4-way junction propagate correctly
## (branching to every wall that actually meets there), and it is naturally
## bounded (no separate depth cap needed) since the walk only ever follows edges
## that physically connect to a trigger, however many hops that takes to reach.
##
## The vertical split (OCC-10, supersedes OCC-09's pixel-threshold reveal): each
## occluded edge's own bottom BASE_VISIBLE_LEVELS levels are left completely
## untouched (always full opacity); everything above ghosts at the ring alpha
## exactly as it always has — a fixed rule, not derived from the agent's screen
## position (see BASE_VISIBLE_LEVELS doc comment for why the pixel-threshold
## version was dropped).
##
## Returns: {"edges": Array, "segments": Array}
##   "edges" — one Dictionary per occluded edge, the FILL's source of truth:
##     {"edge_id", "ring", "corner_a", "corner_b", "min_level", "max_level"}
##     "min_level" is where ghosting STARTS (edge's true base + BASE_VISIBLE_LEVELS).
##   "segments" — the wireframe's source of truth (OCC-13/OCC-14/OCC-19): one
##     independent unit per occluded edge, a real box with both width and
##     depth: {"near_a", "near_b", "far_a", "far_b", "min_level", "max_level",
##     "ring"}, all four corners in fine-voxel space. "ring" travels with the
##     segment so the wireframe's own glass FILL can match VoxelRenderer.
##     GHOST_ALPHAS[ring] — the same alpha the real ghosted material already
##     uses, not a second, independently-tuned value. "near" is the edge's TRUE shared
##     grid vertex (`_edge_vertices`) — two adjacent edges can never disagree
##     about where their shared corner is; "far" is "near" shifted by the
##     wall's real one-voxel thickness (see depth_offset below), so the
##     wireframe box has actual depth instead of being a flat plane.
##     Junction-column units are appended separately in recompute().
func compute_edge_occlusion(agent_cells: Array, slices_by_edge: Dictionary, _room_size: Vector2i) -> Dictionary:
	var half_gu := int(GeometryCoordsMod.VOXELS_PER_UNIT_AXIS / 2.0)
	
	## OCC-HOVER-01: Convert all agent cells to voxel space and screen positions
	var agent_data: Array = []  ## [{"voxel": Vector2i, "depth": int, "screen_x": float, "screen_y_head": float, "screen_y_ground": float}]
	const VOXEL_HALF_W := 16.0   ## GeometryCoords.VOXEL_TILE_SIZE.x * 0.5
	const VOXEL_HALF_H := 8.0    ## GeometryCoords.VOXEL_TILE_SIZE.y * 0.5
	
	for agent_cell in agent_cells:
		var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell) + Vector2i(half_gu, half_gu)
		var agent_depth := agent_voxel.x + agent_voxel.y
		var agent_screen_x := float(agent_voxel.x - agent_voxel.y) * VOXEL_HALF_W
		## The agent "stands" at level 0, reaching up by his own height in pixels — same
		## relative depth*HALF_H formula every voxel layer's screen position uses.
		var agent_screen_y_ground := float(agent_depth) * VOXEL_HALF_H
		var agent_screen_y_head := agent_screen_y_ground - silhouette_height_px
		agent_data.append({
			"voxel": agent_voxel, "depth": agent_depth,
			"screen_x": agent_screen_x,
			"screen_y_head": agent_screen_y_head,
			"screen_y_ground": agent_screen_y_ground
		})

	## One geometry pass per edge: real footprint + screen-X/Y span, from its own
	## voxels across every storey it has (never a generic per-cell guess).
	var edge_geom: Dictionary = {}        ## edge_id -> geometry dict (see below)
	var vertex_to_edges: Dictionary = {}  ## Vector2i vertex -> Array[String edge_id]

	for edge_id in slices_by_edge.keys():
		var edge_slices: Array = slices_by_edge[edge_id]

		var min_gx: int = edge_slices[0].voxels[0].grid_pos.x
		var max_gx: int = min_gx
		var min_gy: int = edge_slices[0].voxels[0].grid_pos.y
		var max_gy: int = min_gy
		var min_level: int = edge_slices[0].voxels[0].level
		var max_level: int = min_level
		for slice in edge_slices:
			for voxel in slice.voxels:
				min_gx = mini(min_gx, voxel.grid_pos.x)
				max_gx = maxi(max_gx, voxel.grid_pos.x)
				min_gy = mini(min_gy, voxel.grid_pos.y)
				max_gy = maxi(max_gy, voxel.grid_pos.y)
				min_level = mini(min_level, voxel.level)
				max_level = maxi(max_level, voxel.level)

		var center_x := float(min_gx + max_gx) * 0.5
		var center_y := float(min_gy + max_gy) * 0.5
		var center_depth := center_x + center_y

		var corner_a_x := (float(min_gx) - float(min_gy)) * VOXEL_HALF_W
		var corner_b_x := (float(max_gx) - float(max_gy)) * VOXEL_HALF_W
		var screen_x := (corner_a_x + corner_b_x) * 0.5
		var half_width := absf(corner_b_x - corner_a_x) * 0.5

		## y_top is the SMALLER value (higher storeys sit higher on screen);
		## y_bottom is the LARGER value (ground level, nearer the bottom of screen).
		var y_bottom := center_depth * VOXEL_HALF_H - float(min_level) * GeometryCoordsMod.VOXEL_STEP_PX
		var y_top := center_depth * VOXEL_HALF_H - float(max_level + 1) * GeometryCoordsMod.VOXEL_STEP_PX

		## OCC-10: fixed always-visible base band — this edge's own bottom
		## BASE_VISIBLE_LEVELS levels are left untouched (full opacity); ghosting
		## starts right above them and runs to the edge's own top, at the ring
		## alpha, same as it always has. No agent-relative math any more (see
		## BASE_VISIBLE_LEVELS doc comment).
		var ghost_start_level := mini(min_level + BASE_VISIBLE_LEVELS, max_level + 1)

		## Adjacency graph: registered for EVERY edge, not just triggers — a
		## non-triggering edge can still be a ring-1/ring-2 stop on the path
		## outward from one.
		var anchor = edge_slices[0]
		var vertices := _edge_vertices(anchor.gu_cell, anchor.face)

		## OCC-14/OCC-15 (2026-07-14): the wireframe's real THICKNESS. A wall is
		## two Slices (A/B, one per adjacent GU) whose own real voxel COLUMNS sit
		## exactly one fine-voxel unit apart — SliceGenerator places them at that
		## fixed gap, never coincident (confirmed by construction: e.g. an
		## SE-face slice's own column is always exactly one less than the
		## matching NW-face slice's column on the neighboring GU). The scanned
		## min/max already captures that real 1-unit CENTER-to-CENTER gap on the
		## DEPTH axis (as opposed to the 8-unit-wide WIDTH axis). But the base
		## block's real physical footprint (Director's own "8x2x2") is TWO full
		## voxel cells deep, not the 1-unit gap between their centers — each
		## Slice's own voxel column is itself a full unit wide, so the true outer
		## span runs from slice A's own FAR edge to slice B's own FAR edge, one
		## extra unit past the naive center-to-center delta. Doubled here (2026
		## -07-14, Director's correction: the wireframe's depth undershot the
		## base it sits on by exactly one voxel).
		var depth_offset: Vector2i
		match anchor.face:
			FaceMod.NW, FaceMod.SE:
				depth_offset = Vector2i(2 * (min_gx - max_gx), 0)
			FaceMod.NE, FaceMod.SW:
				depth_offset = Vector2i(0, 2 * (min_gy - max_gy))
			_:
				depth_offset = Vector2i.ZERO

		edge_geom[edge_id] = {
			"corner_a": Vector2i(min_gx, min_gy), "corner_b": Vector2i(max_gx, max_gy),
			"depth": center_depth, "screen_x": screen_x, "half_width": half_width,
			"y_top": y_top, "y_bottom": y_bottom, "depth_offset": depth_offset,
			"min_level": ghost_start_level, "max_level": max_level,
			"face": anchor.face, "vertex_a": vertices[0], "vertex_b": vertices[1],
		}

		for v in vertices:
			if not vertex_to_edges.has(v):
				vertex_to_edges[v] = []
			vertex_to_edges[v].append(edge_id)

	## Trigger test: camera-side + real 2D (screen-X and screen-Y) overlap with the
	## agent's own silhouette rectangle. Uses the edge's UNCLIPPED y_bottom — the
	## vertical reveal cutoff only trims what gets ghosted afterward, it must not
	## change whether an edge counts as a trigger in the first place.
	##
	## OCC-HOVER-01: Test against EACH origin — an edge triggers if it overlaps ANY
	## of the provided agent positions. Seeds accumulate across all origins.
	var seeds: Array = []
	var seed_set: Dictionary = {}  ## deduplication: edge_id -> true
	for agent in agent_data:
		for edge_id in edge_geom.keys():
			if seed_set.has(edge_id):
				continue  ## already triggered by a previous origin
			var g: Dictionary = edge_geom[edge_id]
			if g["depth"] <= agent["depth"]:
				continue
			if absf(g["screen_x"] - agent["screen_x"]) > silhouette_half_width_px + g["half_width"]:
				continue
			if g["y_top"] > agent["screen_y_ground"] or g["y_bottom"] < agent["screen_y_head"]:
				continue
			seeds.append(edge_id)
			seed_set[edge_id] = true

	if seeds.is_empty():
		return {"edges": [], "segments": []}

	## Multi-source BFS along the wall's own connectivity graph, up to MAX_RING hops.
	## Every trigger is its own ring-0 seed — there is no special-cased "the agent's
	## own tile" seed; when he stands against a wall, its edges simply satisfy the
	## trigger test directly, same as any other.
	var ring_by_edge: Dictionary = {}
	var frontier: Array = seeds.duplicate()
	for edge_id in seeds:
		ring_by_edge[edge_id] = 0

	## Director refinement, 2026-07-14: propagate ONLY through a vertex that is a
	## simple pass-through — exactly one other edge touching it — and only onto that
	## edge if it continues in the SAME direction (face). A vertex with more than one
	## other edge is a junction (a corner, a T, a 4-way meeting); a single other edge
	## in a DIFFERENT face is a turn. Both stop the ring right there rather than
	## wrapping onto a wall that just happens to share a corner.
	for hop in range(1, MAX_RING + 1):
		var next_frontier: Array = []
		for edge_id in frontier:
			var anchor = slices_by_edge[edge_id][0]
			var my_face: int = anchor.face
			for v in _edge_vertices(anchor.gu_cell, my_face):
				var touching: Array = vertex_to_edges.get(v, [])
				var other_id: String = ""
				var other_count := 0
				for candidate_id in touching:
					if candidate_id != edge_id:
						other_count += 1
						other_id = candidate_id
				if other_count != 1:
					continue  ## dead end (0) or junction (2+) — do not propagate here
				if ring_by_edge.has(other_id):
					continue
				var other_anchor = slices_by_edge[other_id][0]
				if other_anchor.face != my_face:
					continue  ## direction change — do not propagate
				ring_by_edge[other_id] = hop
				next_frontier.append(other_id)
		frontier = next_frontier

	## OCC-13 (2026-07-14): one wireframe unit per occluded EDGE — Director's
	## formalization, replacing OCC-12's connectivity-walk merge: each edge is
	## its own self-contained unit (base band below, wireframe above, see
	## BASE_VISIBLE_LEVELS), and adjacent units at a V-junction are simply drawn
	## independently — the resulting overlap at the corner is expected, not a
	## defect, and the junction column's own unit (recompute(), see below) is
	## what visually resolves it, per the Director's diagram. Segment corners use
	## the edge's TRUE shared grid VERTEX (`_edge_vertices`), not its own
	## independently-scanned voxel min/max — that mismatch (two different faces
	## can each compute a slightly different point for what should be the same
	## shared corner) was the actual root cause of the reported diagonal-seam
	## artifact; fixed here regardless of the merge-vs-independent question.
	var result: Array = []
	var segments: Array = []
	for edge_id in ring_by_edge.keys():
		var g: Dictionary = edge_geom[edge_id]
		result.append({
			"edge_id": edge_id, "ring": ring_by_edge[edge_id],
			"corner_a": g["corner_a"], "corner_b": g["corner_b"],
			"min_level": g["min_level"], "max_level": g["max_level"],
		})
		## OCC-14: near = the true-vertex width-aligned edge (unchanged from
		## OCC-13); far = near shifted by the real one-voxel wall thickness, so
		## the wireframe reads as an actual box, not a flat plane.
		var near_a: Vector2i = GeometryCoordsMod.gu_to_voxel_origin(g["vertex_a"])
		var near_b: Vector2i = GeometryCoordsMod.gu_to_voxel_origin(g["vertex_b"])
		segments.append({
			"near_a": near_a, "near_b": near_b,
			"far_a": near_a + g["depth_offset"], "far_b": near_b + g["depth_offset"],
			"min_level": g["min_level"], "max_level": g["max_level"], "ring": ring_by_edge[edge_id],
		})
	return {"edges": result, "segments": segments}


## The two grid-VERTEX corners of a (gu_cell, face) wall segment. Both faces of the
## same physical edge (face_a on gu_a, and the complementary face_b on gu_b) resolve
## to the SAME two vertices by construction, so it never matters which side's
## (gu_cell, face) a caller has on hand — see Face.gd for the compass convention.
func _edge_vertices(gu_cell: Vector2i, face: int) -> Array:
	var x := gu_cell.x
	var y := gu_cell.y
	match face:
		FaceMod.NW:
			return [Vector2i(x, y), Vector2i(x, y + 1)]
		FaceMod.NE:
			return [Vector2i(x, y), Vector2i(x + 1, y)]
		FaceMod.SE:
			return [Vector2i(x + 1, y), Vector2i(x + 1, y + 1)]
		FaceMod.SW:
			return [Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
		_:
			return []


## ============================================================================
## DEBUG HELPERS
## ============================================================================

## Print occlusion set statistics
func debug_print_stats() -> void:
	if _occluded_cells.is_empty():
		print_debug("[OcclusionSet] Empty (no occluders)")
		return

	var ring_counts := [0, 0, 0]
	for entry in _occluded_cells.values():
		var ring: int = entry["ring"]
		if ring >= 0 and ring <= 2:
			ring_counts[ring] += 1

	print_debug("[OcclusionSet] Total: %d cells | Ring 0: %d | Ring 1: %d | Ring 2: %d | Recomputes: %d" % [
		_occluded_cells.size(), ring_counts[0], ring_counts[1], ring_counts[2], _recompute_count
	])
