## Occlusion Wireframe Overlay — OCC-27 (2026-07-21)
##
## Draws the wireframe over each occluded (erased) voxel's translucent band,
## reading OcclusionSet.get_wireframe_by_level() — geometry already unified
## across walls, junctions and roofs by OcclusionSet's own hidden-face-
## culling pass (see occlusion_set.gd::_build_wireframe_geometry() for why).
## VoxelRenderer.apply_occlusion() ghosts the band this outlines (ring alpha,
## OCC-08/O6); the edge's own base band underneath is left fully opaque and
## untouched (OCC-10) — solid enough on its own that it needs no outline.
##
## History: OCC-07-b through OCC-23 built this as one independent box PER
## STRUCTURAL UNIT (one per wall Edge, one per roof GU or later GU-rectangle,
## one disabled per junction column), each spawning its own OcclusionSlicePanel
## per level. OCC-27 supersedes that architecture: since the geometry is now
## ALREADY organized per level (one merged set of lines+fills per level, not
## per unit), this spawns exactly one panel PER LEVEL — no structural-unit
## grouping left to reason about, and far fewer nodes than before.
##
## z_index still tracks the real voxel layer per level (OCC-23): a panel for
## level L must draw BEHIND visible voxels at level L+1 and above, but IN
## FRONT of everything strictly below it (most visibly the edge's own opaque
## base band, OCC-10). Offset -1 puts the panel exactly between its level's
## layer and the one below.

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
## so tearing down and respawning a handful of small nodes here is not a hot path.
func refresh() -> void:
	for panel in _panels:
		panel.queue_free()
	_panels.clear()

	if occlusion_set == null or voxel_renderer == null:
		return

	var by_level: Dictionary = occlusion_set.get_wireframe_by_level()
	for level in by_level:
		var data: Dictionary = by_level[level]
		if data["lines"].is_empty() and data["fills"].is_empty():
			continue

		var panel := Node2D.new()
		panel.set_script(SlicePanelClass)
		panel.z_index = _layer_z_index(level)

		for line in data["lines"]:
			panel.lines.append({
				"a": _voxel_to_screen(line["a"], line["level_a"]),
				"b": _voxel_to_screen(line["b"], line["level_b"]),
				"solid": line["solid"],
			})

		for fill in data["fills"]:
			var quad: PackedVector2Array
			if fill["kind"] == "side":
				var a: Vector2i = fill["a"]
				var b: Vector2i = fill["b"]
				var lvl: int = fill["level"]
				quad = PackedVector2Array([
					_voxel_to_screen(a, lvl), _voxel_to_screen(b, lvl),
					_voxel_to_screen(b, lvl + 1), _voxel_to_screen(a, lvl + 1),
				])
			else:  ## "top" — flat footprint quad, all 4 corners at the same level
				var a2: Vector2i = fill["a"]
				var b2: Vector2i = fill["b"]
				var lvl2: int = fill["level"]
				quad = PackedVector2Array([
					_voxel_to_screen(Vector2i(a2.x, a2.y), lvl2),
					_voxel_to_screen(Vector2i(b2.x, a2.y), lvl2),
					_voxel_to_screen(Vector2i(b2.x, b2.y), lvl2),
					_voxel_to_screen(Vector2i(a2.x, b2.y), lvl2),
				])
			panel.fills.append({"p": quad, "ring": fill["ring"]})

		add_child(panel)
		_panels.append(panel)

	## OCC-26 capture instrument: INFILTRAITOR_WF_HIDE=1 hides only this overlay,
	## so an unattended capture pair (wireframe on/off, same agent cell) isolates
	## exactly the wireframe's own pixels for alignment forensics.
	if OS.get_environment("INFILTRAITOR_WF_HIDE") == "1":
		visible = false


## OCC-23 (2026-07-17): z_index of voxel layer MINUS ONE. The panel for level L
## must draw BEHIND visible voxels at its own level and above (nearer walls at
## the same level must cover its wireframe), but IN FRONT of everything strictly
## below it — most visibly the edge's own opaque base band (OCC-10), which sits
## below min_level by construction. Offset 1 puts the panel exactly between its
## level's layer and the one below; the tie at level L-1 breaks in the panel's
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
