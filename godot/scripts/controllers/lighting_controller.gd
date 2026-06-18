extends Node
## LightingController — Manages the full lighting pipeline:
## LightRegistry, ShadowProjector, ExposureSystem.
##
## Emits lighting_rebuilt whenever a rebuild occurs, letting the
## VisionController refresh the lighting/heatmap overlays.

signal lighting_rebuilt()

# Preloads — moved from room.gd
const LightRegistryClass   = preload("res://godot/scripts/systems/lighting/light_registry.gd")
const ShadowProjectorClass = preload("res://godot/scripts/systems/lighting/shadow_projector.gd")
const ExposureSystemClass  = preload("res://godot/scripts/systems/lighting/exposure_system.gd")
const LightSourceClass     = preload("res://godot/scripts/systems/lighting/light_source.gd")
const LightAnchorClass     = preload("res://godot/scripts/systems/lighting/light_anchor.gd")
const ShadowResultClass    = preload("res://godot/scripts/systems/lighting/shadow_result.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")

var _room: Node2D
var _light_registry          ## LightRegistry instance
var _shadow_projector        ## ShadowProjector instance
var _exposure_system         ## ExposureSystem instance
var _tile_semantics_map: Dictionary = {}  ## cell -> TileSemantics
var _light_anchors: Array = []


func setup(room_ref: Node2D) -> void:
	_room = room_ref
	_init_systems()


## Public accessors for other controllers
func get_light_registry():
	return _light_registry


func get_exposure_system():
	return _exposure_system


func get_tile_semantics_map() -> Dictionary:
	return _tile_semantics_map


func get_light_anchors() -> Array:
	return _light_anchors


func rebuild() -> void:
	## Rebuild all shadows and exposure systems
	_rebuild_all_shadows_and_exposure()
	## Emit signal so overlays refresh themselves
	lighting_rebuilt.emit()


## Full re-derivation from the room's current (e.g. perspective-rotated) layout: re-registers
## map lights, rebuilds tile semantics, re-feeds the shadow projector, re-projects shadows/exposure.
## Use this when the underlying cells change (perspective switch); rebuild() only re-projects.
func rebuild_all() -> void:
	_setup_lights_from_layout()
	_setup_tile_semantics()
	_refresh_shadow_projector_inputs()
	_rebuild_all_shadows_and_exposure()
	lighting_rebuilt.emit()


func rebuild_deferred() -> void:
	call_deferred("rebuild")


func _init_systems() -> void:
	## L-IMP-01: Initialize light registry and overlay
	_light_registry = LightRegistryClass.new()
	_room.add_child(_light_registry)
	_setup_lights_from_layout()
	
	## L-IMP-02a: Initialize tile semantics BEFORE shadow projection (needs _tile_semantics_map for heights)
	_setup_tile_semantics()
	
	## L-IMP-02b: Setup shadow projector (depends on blocked cells from room)
	_setup_shadow_projector()
	
	## L-IMP-03: Initialize tactical exposure system (after shadow projector ready)
	_setup_exposure_system()


## Register the map's lights from the active (perspective-rotated) layout.
## Source: room._current_light_sources — entries {x, y, height, radius, intensity}.
## Replaces the old hardcoded debug lights so lighting follows the map and rotates with it.
func _setup_lights_from_layout() -> void:
	if _light_registry == null:
		return

	_light_registry.clear_all()

	var sources: Array = _room._current_light_sources
	for i in range(sources.size()):
		var src: Dictionary = sources[i]
		var light = LightSourceClass.new()
		light.cell = Vector2i(int(src.get("x", 0)), int(src.get("y", 0)))
		light.light_type = String(src.get("type", LightSourceClass.TYPE_OMNI))
		## Height: prefer explicit height_class; reconcile the legacy float "height"
		## (clamp 0–4); default OVERHEAD for ceiling lights.
		if src.has("height_class"):
			light.height_class = int(src["height_class"])
		elif src.has("height"):
			light.height_class = clampi(int(src["height"]), 0, 4)
		else:
			light.height_class = TileSemanticsClass.HEIGHT_OVERHEAD
		light.radius = int(src.get("radius", 6))
		light.tactical_energy = float(src.get("intensity", 1.0))
		## Direction / cone for directional & cone (spot / sun) lights.
		light.direction_angle = deg_to_rad(float(src.get("direction_deg", 0.0)))
		light.cone_angle = float(src.get("cone_deg", light.cone_angle))
		## Small/temporal sources (fire, candle, intermittent).
		if bool(src.get("flicker", false)):
			light.set_flicker(true, float(src.get("flicker_interval", 1.0)))
		light.active = true
		light.light_id = "map_light_%d" % (i + 1)
		light.owner_name = "map_light_%d" % (i + 1)
		_light_registry.register_light(light)

	var all_lights = _light_registry.get_all_lights()
	print("[Room] Light registry initialized with %d map lights:" % all_lights.size())
	for light in all_lights:
		print("  - %s @ cell(%d,%d) radius=%d type=%s" % [light.light_id, light.cell.x, light.cell.y, light.radius, light.light_type])


## L-IMP-02b: Setup shadow projector for visibility calculations
func _setup_shadow_projector() -> void:
	_shadow_projector = ShadowProjectorClass.new()
	_room.add_child(_shadow_projector)
	_refresh_shadow_projector_inputs()
	print("[Room] Shadow projector initialized")


## (Re)feed the shadow projector with the room's current geometry. Called at setup and on
## every rebuild (e.g. perspective change), so projections match the active layout.
func _refresh_shadow_projector_inputs() -> void:
	if _shadow_projector == null:
		return
	_shadow_projector.set_blocked_cells(_room._blocked_cells)
	_shadow_projector.set_blocked_edges(_room.enemy_phase_controller.build_blocked_edge_set(_room._current_blocked_edges))
	_shadow_projector.set_obstacle_heights(_get_obstacle_heights())
	_shadow_projector.set_room_size(_room._room_size)


## Helper: Build obstacle heights dictionary from blocked cells
func _get_obstacle_heights() -> Dictionary:
	var heights: Dictionary = {}
	
	# A blocked cell is a solid object → at least HUMAN height for shadow casting.
	# Use a richer semantic height only when one is actually known (>0). Today
	# blocked_cells carry no per-tile height (stored as bare `true`), so most
	# resolve to HUMAN. TODO(VIS-01): derive real per-prop heights from tile type
	# (column = tall, crate = human) so columns cast longer shadows than crates.
	for cell in _room._blocked_cells.keys():
		var h: int = TileSemanticsClass.HEIGHT_HUMAN
		if _tile_semantics_map.has(cell):
			var sem_h: int = _tile_semantics_map[cell].height_class
			if sem_h > 0:
				h = sem_h
		heights[cell] = h

	return heights


## L-IMP-03: Setup exposure system for tactical visibility classification
func _setup_exposure_system() -> void:
	if _shadow_projector == null or _light_registry == null:
		return
	
	_exposure_system = ExposureSystemClass.new()
	_exposure_system.set_room_size(_room._room_size)
	
	# Provide structural data for OCCLUDED_VOID detection (LIGHT-FIX-04)
	var blocked_edges = _room.enemy_phase_controller.build_blocked_edge_set(_room._current_blocked_edges)
	_exposure_system.set_structural_data(_room._blocked_cells, blocked_edges)
	
	_room.add_child(_exposure_system)
	
	# Rebuild exposure from first available shadow result
	# For now, we generate a single merged result from all lights
	var all_lights = _light_registry.get_all_lights()
	var all_results: Array = []
	
	for light in all_lights:
		var result = _shadow_projector.project_light(light)
		if result:
			all_results.append(result)
	
	if all_results.size() > 0:
		_exposure_system.rebuild_from_results(all_results)
		var stats = _exposure_system.get_exposure_stats()
		print("[Room] Exposure system rebuilt: full_lit=%d, dim=%d, penumbra=%d, shadow=%d, deep_shadow=%d" % [
			stats["full_lit"], stats["dim"], stats["penumbra"], stats["shadow"], stats["deep_shadow"]
		])
	
	print("[Room] Exposure system initialized with %d light projections" % all_results.size())


## L-IMP-05: Initialize tile semantics for worldbuilding
func _setup_tile_semantics() -> void:
	_tile_semantics_map.clear()
	_light_anchors.clear()
	
	# Populate semantics from blocked_cells and structural data
	for cell in _room._blocked_cells.keys():
		var semantics = TileSemanticsClass.make_floor()  # Default: floor
		
		# Infer from blocked_cells flags
		var blocked = _room._blocked_cells[cell]
		if blocked is Dictionary:
			# Extract semantic data if available
			if blocked.get("blocks_los", false):
				if blocked.get("height", 1) >= 3:
					semantics = TileSemanticsClass.make_wall()
				else:
					semantics = TileSemanticsClass.make_low_cover()
			if blocked.get("blocks_light", false):
				semantics.blocks_light = true
		
		_tile_semantics_map[cell] = semantics
	
	# Find and register light anchor points from all registered lights
	# Create LightAnchorClass objects with proper structure
	if _light_registry != null:
		for light in _light_registry.get_all_lights():
			# Create anchor at light position with appropriate height class
			var anchor = LightAnchorClass.make_ceiling(light.cell, light.height_class)
			anchor.description = "Light anchor: %s" % light.owner_name
			_light_anchors.append(anchor)
	
	print("[Room] Tile semantics initialized with %d tiles, %d light anchors" % [
		_tile_semantics_map.size(), _light_anchors.size()
	])


## Rebuild shadow and exposure projections for all lights.
## Called when any light's temporal state changes or when explicitly needed.
func _rebuild_all_shadows_and_exposure() -> void:
	if _shadow_projector == null or _exposure_system == null:
		return
	
	# Rebuild shadows for all active lights
	var all_shadow_results: Array = []
	for light in _light_registry.get_active_lights():
		var shadow_result = _shadow_projector.project_light(light)
		all_shadow_results.append(shadow_result)
	
	# Rebuild exposure from merged shadows
	_exposure_system.rebuild_from_results(all_shadow_results)
