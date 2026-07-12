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

## Radius of the occlusion circle in voxel cells (not gameplay units).
## Governs how far beyond the agent the ghost region extends.
## Tuning note: isometric projection squashes y by 2×, so a "round" circle on
## screen requires elliptical math; this is exposed for manual tuning.
var circle_radius_voxels: float = 20.0

## Ring widths in voxel cells (distance from agent)
## Ring 0: [0, ring_0_width) — most transparent alpha
## Ring 1: [ring_0_width, ring_0_width + ring_1_width) — medium alpha
## Ring 2: [ring_1_width + ring_2_width, ∞) — least transparent alpha
var ring_0_width: float = 8.0   # Nearest ring: alpha will be 5%
var ring_1_width: float = 8.0   # Middle ring: alpha will be 25%
var ring_2_width: float = 4.0   # Outer ring: alpha will be 50%

## ============================================================================
## STATE (owned solely by this module)
## ============================================================================

## The set of voxel cells that occlude the agent, mapped to ring index.
## Key: Vector2i voxel cell (gameplay grid coordinate space)
## Value: int ring index (0, 1, or 2)
var _occluded_cells: Dictionary = {}

## Recomputation counter (for verification of cadence)
var _recompute_count: int = 0

## ============================================================================
## API
## ============================================================================

## Query the occluded-cell set.
## Returns: Dictionary of voxel cells → ring index
func get_occluded_cells() -> Dictionary:
	return _occluded_cells.duplicate()

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
##   voxel_cells: Array of Vector2i — all voxel cells currently placed
##   room_size: Vector2i — size of room in gameplay grid units
func recompute(agent_cell: Vector2i, voxel_cells: Array, room_size: Vector2i) -> void:
	var new_occluded := compute_occluded_cells(agent_cell, voxel_cells, room_size)
	
	# Only update if the set changed
	if new_occluded != _occluded_cells:
		_occluded_cells = new_occluded
		_recompute_count += 1
		if _recompute_count % 10 == 0 or new_occluded.size() > 0:
			print_debug("[OcclusionSet] Recomputed: %d cells in occlusion set (count=%d)" % [
				_occluded_cells.size(), _recompute_count
			])

## ============================================================================
## CORE COMPUTATION (pure geometry, no I/O)
## ============================================================================

## Compute the set of voxel cells between the agent and the camera inside the circle.
##
## Algorithm:
##  1. Convert agent gameplay cell → voxel origin
##  2. For each voxel cell in the placement:
##     a. Check if it's inside the circle (Euclidean distance with isometric squash)
##     b. Check if it's on the camera side: (cell.x + cell.y) > (agent.x + agent.y)
##     c. If both true, assign ring index by distance from agent
##
## Returns: Dictionary of voxel cells → ring index
func compute_occluded_cells(agent_cell: Vector2i, voxel_cells: Array, _room_size: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	
	# Agent position in voxel grid (gameplay → voxel origin)
	var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell)
	var agent_depth := agent_voxel.x + agent_voxel.y
	
	# Precompute ring distance thresholds (squared, to avoid sqrt in loop)
	var ring_0_dist_sq := ring_0_width * ring_0_width
	var ring_1_dist_sq := (ring_0_width + ring_1_width) * (ring_0_width + ring_1_width)
	var ring_2_dist_sq := circle_radius_voxels * circle_radius_voxels
	
	# Isometric squash factor: y is halved on screen
	const ISOMETRIC_SQUASH := 0.5
	
	# For each voxel cell in the layout
	for voxel_cell in voxel_cells:
		# Skip if not on camera side (depth test)
		var cell_depth: int = voxel_cell.x + voxel_cell.y
		if cell_depth <= agent_depth:
			continue
		
		# Distance from agent in isometric space
		var dx := float(voxel_cell.x - agent_voxel.x)
		var dy := (float(voxel_cell.y - agent_voxel.y)) * ISOMETRIC_SQUASH
		var dist_sq := dx * dx + dy * dy
		
		# Skip if outside the circle
		if dist_sq > ring_2_dist_sq:
			continue
		
		# Assign ring based on distance
		var ring := 2
		if dist_sq <= ring_0_dist_sq:
			ring = 0
		elif dist_sq <= ring_1_dist_sq:
			ring = 1
		
		result[voxel_cell] = ring
	
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
