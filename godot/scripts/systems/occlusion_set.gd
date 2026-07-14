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

## ============================================================================
## TUNING (exposed as adjustable, for Director to dial against screenshots)
## ============================================================================

## OCC-06 (2026-07-14): half-width, in screen pixels, of the corridor directly
## between the agent and the fixed camera. Replaces circle_radius_voxels — see
## Decision O3′. Widened 2026-07-14 (Director, live test): 32px caught only the
## one or two slices directly behind him and read as too narrow — a believable
## "he's covered" needs a bit more margin than his own raw sprite half-width.
var silhouette_half_width_px: float = 48.0

## OCC-07-b (2026-07-14): maximum depth distance, in voxels, a slice may be ahead
## of the agent and still qualify. The corridor test alone is unbounded in depth —
## a slice on the far side of the map that happens to line up with the agent's
## screen-x (an outer boundary wall, say) satisfies "camera side" + "in the
## corridor" just as well as one right next to him, since orthographic isometric
## projection never converges distant things toward centre the way perspective
## would. Director-reported live: a distant map-boundary wall was ghosting despite
## being nowhere near the agent. This is a real distance cap again — unlike O3's
## retired circle, it only limits DEPTH, not the corridor's width.
var max_depth_voxels: float = 48.0

## ============================================================================
## STATE (owned solely by this module)
## ============================================================================

## The set of voxel cells that occlude the agent.
## Key: Vector2i voxel cell (gameplay grid coordinate space)
## Value: int — vestigial (always 0), kept only for Dictionary-shape stability.
## See get_occluded_slices() for the shape-aware view OcclusionWireframeOverlay uses.
var _occluded_cells: Dictionary = {}

## The Slice objects that qualified this recompute — OCC-07's unit of decision.
## Owned solely by this module, rebuilt every recompute, never persisted (O1).
var _occluded_slices: Array = []

## Recomputation counter (for verification of cadence)
var _recompute_count: int = 0

## ============================================================================
## API
## ============================================================================

## Query the occluded-cell set.
## Returns: Dictionary of voxel cells → ring index
func get_occluded_cells() -> Dictionary:
	return _occluded_cells.duplicate()

## The Slice objects currently occluded — for consumers that need real shape data
## (OcclusionWireframeOverlay), not just the flat per-voxel ghosting dictionary.
func get_occluded_slices() -> Array:
	return _occluded_slices.duplicate()

## Get the ring index for a given voxel cell, or -1 if not occluded.
func get_ring_index(voxel_cell: Vector2i) -> int:
	return _occluded_cells.get(voxel_cell, -1)

## Check if a voxel cell is occluded.
func is_occluded(voxel_cell: Vector2i) -> bool:
	return _occluded_cells.has(voxel_cell)

## Get the recomputation counter for verification.
func get_recompute_count() -> int:
	return _recompute_count

## ============================================================================
## RECOMPUTATION (called from room.gd on agent step + view change)
## ============================================================================

## Recompute the occluded-cell set given current agent position and geometry.
## Called on: agent.step_finished signal, _set_perspective()
##
## Args:
##   agent_cell: Vector2i — gameplay grid cell (from agent.cell)
##   slices: Array[Slice] — every Slice currently rendered (room._edge_registry.all_slices())
##   room_size: Vector2i — size of room in gameplay grid units
func recompute(agent_cell: Vector2i, slices: Array, room_size: Vector2i) -> void:
	var occluded_slices := compute_occluded_slices(agent_cell, slices, room_size)

	var new_occluded: Dictionary = {}
	for slice in occluded_slices:
		for voxel in slice.voxels:
			new_occluded[voxel.grid_pos] = 0

	# Only update if the set changed
	if new_occluded != _occluded_cells:
		_occluded_cells = new_occluded
		_occluded_slices = occluded_slices
		_recompute_count += 1
		if _recompute_count % 10 == 0 or new_occluded.size() > 0:
			print_debug("[OcclusionSet] Recomputed: %d cells, %d slices in occlusion set (count=%d)" % [
				_occluded_cells.size(), _occluded_slices.size(), _recompute_count
			])

## ============================================================================
## CORE COMPUTATION (pure geometry, no I/O)
## ============================================================================

## OCC-07 (2026-07-14): decide occlusion per SLICE — the actual wall-panel unit
## the render pipeline already uses (one face, one gameplay cell, real voxels) —
## not per gameplay cell and not per voxel column. Replaces O3′ — see Decision O3″.
##
## O3′ (per-gameplay-cell) fixed the worst of the circle's problems but still over-
## selected: a wide wall's every cell within the corridor ghosted together, and a
## generic per-cell diamond footprint doesn't match a wall's real (thin, one-axis)
## shape. The Director's ask, illustrated directly: only the ONE slice actually
## standing between the agent and the camera disappears — a wide wall's other
## slices, and a tall wall's other faces, stay solid.
##
## A Slice already carries its own real voxels (Slice.voxels: Array[Voxel], each
## with a real grid_pos) — using their actual min/max bounds instead of a generic
## cell-diamond gives the slice's true screen footprint, thin axis and all.
##
## Returns: Array[Slice] — every slice that qualifies, whole (never a clipped
## subset of one — a slice IS the atomic unit now, so there is nothing left to clip).
func compute_occluded_slices(agent_cell: Vector2i, slices: Array, _room_size: Vector2i) -> Array:
	var result: Array = []

	## OCC-FIX-02 (a): anchor on the agent's CENTRE, not his cell's corner.
	var half_gu := int(GeometryCoordsMod.VOXELS_PER_UNIT_AXIS / 2.0)
	var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell) + Vector2i(half_gu, half_gu)
	var agent_depth := agent_voxel.x + agent_voxel.y

	const VOXEL_HALF_W := 16.0   ## GeometryCoords.VOXEL_TILE_SIZE.x * 0.5
	var agent_screen_x := float(agent_voxel.x - agent_voxel.y) * VOXEL_HALF_W

	for slice in slices:
		if slice.voxels.is_empty():
			continue

		## The slice's real footprint bounds, from its own actual voxels — a Slice
		## is one face of one gameplay cell, so this is thin along one grid axis
		## and spans ~8 voxels along the other; taking min/max here (rather than a
		## generic cell-diamond) is what makes the outline match the wall's real
		## shape instead of a box.
		var min_gx: int = slice.voxels[0].grid_pos.x
		var max_gx: int = min_gx
		var min_gy: int = slice.voxels[0].grid_pos.y
		var max_gy: int = min_gy
		for voxel in slice.voxels:
			min_gx = mini(min_gx, voxel.grid_pos.x)
			max_gx = maxi(max_gx, voxel.grid_pos.x)
			min_gy = mini(min_gy, voxel.grid_pos.y)
			max_gy = maxi(max_gy, voxel.grid_pos.y)

		var center_x := float(min_gx + max_gx) * 0.5
		var center_y := float(min_gy + max_gy) * 0.5

		## Camera side: the slice's own footprint centre must be nearer the camera.
		var depth_delta := (center_x + center_y) - agent_depth
		if depth_delta <= 0.0:
			continue

		## Depth cap: orthographic isometric projection never converges distant
		## things toward the agent's screen column the way perspective would, so
		## the corridor test alone is unbounded — a slice clear across the map that
		## happens to line up on screen (an outer boundary wall, say) would qualify
		## exactly as well as one right next to him without this.
		if depth_delta > max_depth_voxels:
			continue

		## Screen-space overlap with the corridor directly behind the agent's own
		## silhouette. The slice's own real half-width (from its actual corner
		## voxels, not a guessed generic span) is what keeps a wide wall's OTHER
		## slices — a few voxels further along the same wall — out of the set.
		var corner_a_x := (float(min_gx) - float(min_gy)) * VOXEL_HALF_W
		var corner_b_x := (float(max_gx) - float(max_gy)) * VOXEL_HALF_W
		var slice_screen_x := (corner_a_x + corner_b_x) * 0.5
		var slice_half_width_px := absf(corner_b_x - corner_a_x) * 0.5

		if absf(slice_screen_x - agent_screen_x) > silhouette_half_width_px + slice_half_width_px:
			continue

		result.append(slice)

	return result

## ============================================================================
## DEBUG HELPERS
## ============================================================================

## Print occlusion set statistics
func debug_print_stats() -> void:
	if _occluded_cells.is_empty():
		print_debug("[OcclusionSet] Empty (no occluders)")
		return
	
	var ring_counts := [0, 0, 0]
	for cell in _occluded_cells.values():
		if cell >= 0 and cell <= 2:
			ring_counts[cell] += 1
	
	print_debug("[OcclusionSet] Total: %d cells | Ring 0: %d | Ring 1: %d | Ring 2: %d | Recomputes: %d" % [
		_occluded_cells.size(), ring_counts[0], ring_counts[1], ring_counts[2], _recompute_count
	])
