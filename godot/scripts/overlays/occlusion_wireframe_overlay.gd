## Occlusion Wireframe Overlay — OCC-07-b
##
## Draws a crisp white BOX outline (real width AND depth, OCC-14 — not a flat
## plane) over each occluded edge's translucent band, reproducing that wall's own
## real one-voxel thickness. VoxelRenderer.apply_occlusion() ghosts the band this
## outlines (ring alpha, OCC-08/O6); the edge's own base band underneath is left
## fully opaque and untouched (OCC-10) — solid enough on its own that it needs no
## outline.
##
## OCC-07-b (2026-07-14): no longer a single Node2D drawing at one flat elevated
## z_index (150). That always won against nearer, unoccluded geometry that should
## have covered part of it — e.g. a ghosted back wall's outline showing straight
## through the box's own solid front walls, which are unaffected and nearer the
## camera. Director's fix: each wireframe segment must carry the z_index of the
## voxel layer whose slice it stands in for, not a value picked to "clear everything".
##
## Levels, not one shape: this manager splits each edge's rectangle into one
## horizontal band per voxel LEVEL it spans, and spawns one OcclusionSlicePanel
## child per band, each stamped with THAT level's real voxel-layer z_index (read
## directly off VoxelRenderer.get_layer(level), the same TileMapLayer the real wall
## cells are placed on — never re-derived). A single flat rectangle could only ever
## carry one z_index, which would still be wrong for any level range it didn't
## match; per-level bands is what lets a tall slice interleave correctly against
## blockers that only exist at some of its levels.
##
## Reads OcclusionSet.get_occluded_edges() — pre-computed, not raw Slice objects.
## "min_level" is where the TRANSLUCENT band starts (OCC-10: the edge's true base
## plus OcclusionSet.BASE_VISIBLE_LEVELS) — this overlay only ever needs to draw
## that band, never the always-visible base underneath it.
##
## OCC-10 (2026-07-14): disabled by default (see `visible = false` in room.gd) —
## the diagonal-seam artifact reported live is a real bug in this overlay's own
## per-level panel geometry, not investigated yet. Turn back on once that's
## fixed; the recompute-and-refresh cadence below is unaffected either way.

extends Node2D

const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const SlicePanelClass = preload("res://godot/scripts/overlays/occlusion_slice_panel.gd")

var occlusion_set: OcclusionSetClass = null
var voxel_renderer = null

var _panels: Array = []


func set_occlusion_set(occ_set: OcclusionSetClass) -> void:
	occlusion_set = occ_set


func set_voxel_renderer(renderer) -> void:
	voxel_renderer = renderer


## Called by room.gd wherever it used to call queue_redraw() on this node directly.
## Rebuilds the whole set of per-level panel children — the occluded set only
## changes on map load, agent step and view change (O1's cadence), never per frame,
## so tearing down and respawning a few dozen small nodes here is not a hot path.
func refresh() -> void:
	for panel in _panels:
		panel.queue_free()
	_panels.clear()

	if occlusion_set == null or voxel_renderer == null:
		return

	for edge in occlusion_set.get_occluded_edges():
		_spawn_edge_panels(edge)


## Edge dict fields (OCC-14): "near_a"/"near_b"/"far_a"/"far_b" — the box's four
## real footprint corners in fine-voxel space ("near" the edge's true shared
## grid vertex, "far" that same point shifted by the wall's real one-voxel
## thickness — see OcclusionSet.compute_edge_occlusion()'s depth_offset), plus
## "min_level" (where the translucent band starts) and "max_level" (the edge's
## own true top).
func _spawn_edge_panels(edge: Dictionary) -> void:
	var near_a: Vector2i = edge["near_a"]
	var near_b: Vector2i = edge["near_b"]
	var far_a: Vector2i = edge["far_a"]
	var far_b: Vector2i = edge["far_b"]
	var min_level: int = edge["min_level"]
	var max_level: int = edge["max_level"]
	var ring: int = edge.get("ring", 0)
	if min_level > max_level:
		return  ## degenerate span — nothing to draw

	## OCC-18 (2026-07-14): real VOXEL counts for the width (near_a→near_b) and
	## depth (near_a→far_a) edges — dot markers below are spaced one per voxel
	## boundary on every axis, never by an arbitrary pixel length. A fixed pixel
	## dash (OCC-17) looked visually incoherent: the same absolute pixel length
	## reads as widely-spaced on a short axis and tightly-packed on a long one,
	## since screen-px-per-voxel already differs by axis under isometric
	## projection. Computed from the raw fine-voxel corners, before projection.
	var width_voxels: int = maxi(absi(near_a.x - near_b.x), absi(near_a.y - near_b.y))
	var depth_voxels: int = maxi(absi(near_a.x - far_a.x), absi(near_a.y - far_a.y))

	## One band per level the slice actually occupies, each its own panel node at
	## that level's own z_index — see this file's header for why. Only the very top
	## and very bottom band draw their horizontal cap edge; every level boundary in
	## between is an internal seam, not a real silhouette edge — see
	## occlusion_slice_panel.gd's header for why that was producing a "venetian
	## blind" of rungs down every tall occluded span.
	for level in range(min_level, max_level + 1):
		var panel := Node2D.new()
		panel.set_script(SlicePanelClass)
		panel.bottom_near_a = _voxel_to_screen(near_a, level)
		panel.bottom_near_b = _voxel_to_screen(near_b, level)
		panel.bottom_far_a = _voxel_to_screen(far_a, level)
		panel.bottom_far_b = _voxel_to_screen(far_b, level)
		panel.top_near_a = _voxel_to_screen(near_a, level + 1)
		panel.top_near_b = _voxel_to_screen(near_b, level + 1)
		panel.top_far_a = _voxel_to_screen(far_a, level + 1)
		panel.top_far_b = _voxel_to_screen(far_b, level + 1)
		panel.width_voxels = width_voxels
		panel.depth_voxels = depth_voxels
		panel.ring = ring
		panel.draw_top = (level == max_level)
		panel.draw_bottom = (level == min_level)
		panel.z_index = _layer_z_index(level)
		add_child(panel)
		_panels.append(panel)


## OCC-23 (2026-07-17): z_index of voxel layer MINUS ONE. The panel for level L
## must draw BEHIND visible voxels at its own level and above (OCC-21f's masking:
## occluded geometry is spatially behind visible geometry, so nearer walls at the
## same level must cover its wireframe), but IN FRONT of everything strictly below
## it — most visibly the edge's own opaque base band (OCC-10), which sits below
## min_level by construction. OCC-21f's old offset of 5 overshot: it dropped low
## panels below the base band's own layers (z = base+0..1), so the solid base ring
## covered the wireframe's lower bands. Offset 1 puts the panel exactly between
## its level's layer and the one below; the tie at level L-1 breaks in the panel's
## favor because this overlay sits after VoxelRenderer in room.gd's tree order.
func _layer_z_index(level: int) -> int:
	var layer: TileMapLayer = voxel_renderer.get_layer(level)
	var base_z: int
	if layer != null:
		base_z = layer.z_index
	else:
		var base_layer: TileMapLayer = voxel_renderer.get_layer(0)
		if base_layer == null:
			return 0
		base_z = base_layer.z_index + level
	return base_z - 1  ## OCC-23: in front of lower levels, behind own level's voxels


## Screen position of a VOXEL-grid coordinate at a given LEVEL. Same technique
## OCC-FIX-02 established for OcclusionOverlay: ask the layer that actually draws it,
## never hand-roll the isometric transform (Transform Canon has exactly one copy).
## Levels beyond what's currently built (e.g. max_level + 1 on the tallest existing
## layer) fall back to extrapolating from level 0 by VOXEL_STEP_PX per level — the
## same per-level offset every voxel layer is positioned with (see VoxelRenderer's
## _ensure_voxel_layers()), so this stays exact even one level past the last built one.
func _voxel_to_screen(voxel_cell: Vector2i, level: int) -> Vector2:
	var layer: TileMapLayer = voxel_renderer.get_layer(level)
	if layer != null:
		return layer.map_to_local(voxel_cell) + layer.position
	var base_layer: TileMapLayer = voxel_renderer.get_layer(0)
	if base_layer == null:
		return Vector2.ZERO
	var base_pos := base_layer.map_to_local(voxel_cell) + base_layer.position
	return base_pos + Vector2(0.0, -float(level) * GeometryCoords.VOXEL_STEP_PX)
