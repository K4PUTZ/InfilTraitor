extends Node
## LightingController — Gerencia o pipeline completo de iluminação:
## LightRegistry, ShadowProjector, ExposureSystem.
##
## Emite lighting_rebuilt quando qualquer rebuild ocorre, permitindo que
## VisionController atualize os overlays de iluminação/heatmap.

signal lighting_rebuilt()

# Preloads — movidos de room.gd
const LightRegistryClass   = preload("res://godot/scripts/systems/lighting/light_registry.gd")
const ShadowProjectorClass = preload("res://godot/scripts/systems/lighting/shadow_projector.gd")
const ExposureSystemClass  = preload("res://godot/scripts/systems/lighting/exposure_system.gd")
const LightSourceClass     = preload("res://godot/scripts/systems/lighting/light_source.gd")
const LightAnchorClass     = preload("res://godot/scripts/systems/lighting/light_anchor.gd")
const ShadowResultClass    = preload("res://godot/scripts/systems/lighting/shadow_result.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")

var _room: Node2D
var _light_registry          ## instância de LightRegistry
var _shadow_projector        ## instância de ShadowProjector
var _exposure_system         ## instância de ExposureSystem
var _light_anchors: Array = []


func setup(room_ref: Node2D) -> void:
	_room = room_ref
	_init_systems()


func get_exposure_system():
	return _exposure_system


func get_light_registry():
	return _light_registry


func rebuild() -> void:
	## Rebuild all shadows and exposure systems
	_rebuild_all_shadows_and_exposure()
	## Emitir signal para que overlays se atualizem
	lighting_rebuilt.emit()


func rebuild_deferred() -> void:
	call_deferred("rebuild")


func _init_systems() -> void:
	## L-IMP-01: Initialize light registry and overlay
	_light_registry = LightRegistryClass.new()
	_room.add_child(_light_registry)
	_setup_debug_lights()
	
	## L-IMP-02a: Initialize tile semantics BEFORE shadow projection (needs _tile_semantics_map for heights)
	_setup_tile_semantics()
	
	## L-IMP-02b: Setup shadow projector (depends on blocked cells from room)
	_setup_shadow_projector()
	
	## L-IMP-03: Initialize tactical exposure system (after shadow projector ready)
	_setup_exposure_system()


## L-IMP-01: Initialize debug test lights for tactical visualization
func _setup_debug_lights() -> void:
	if _light_registry == null:
		return
	
	# Test light 1: Overhead ambient at (10, 10)
	var light1 = LightSourceClass.new()
	light1.cell = Vector2i(10, 10)
	light1.height_class = 4  # HEIGHT_OVERHEAD
	light1.light_type = "omni"
	light1.radius = 6
	light1.tactical_energy = 1.0
	light1.active = true
	light1.light_id = "test_omni_1"
	light1.owner_name = "overhead_lamp_01"
	_light_registry.register_light(light1)
	
	# Test light 2: Cone light (directional) at (15, 8)
	var light2 = LightSourceClass.new()
	light2.cell = Vector2i(15, 8)
	light2.height_class = 2  # HEIGHT_HUMAN
	light2.light_type = "cone"
	light2.radius = 5
	light2.direction_angle = PI * 0.75  # 135 degrees
	light2.cone_angle = 60.0
	light2.tactical_energy = 0.8
	light2.active = true
	light2.light_id = "test_cone_1"
	light2.owner_name = "guard_spotlight"
	_light_registry.register_light(light2)
	
	# Test light 3: Directional light (guard torch) at (8, 15)
	var light3 = LightSourceClass.new()
	light3.cell = Vector2i(8, 15)
	light3.height_class = 2  # HEIGHT_HUMAN
	light3.light_type = "directional"
	light3.radius = 4
	light3.direction_angle = PI * 0.25  # 45 degrees
	light3.tactical_energy = 0.6
	light3.active = true
	light3.light_id = "test_directional_1"
	light3.owner_name = "torch_01"
	_light_registry.register_light(light3)
	
	var all_lights = _light_registry.get_all_lights()
	print("[Room] Light registry initialized with %d test lights:" % all_lights.size())
	for light in all_lights:
		print("  - %s @ cell(%d,%d) radius=%d type=%s" % [light.light_id, light.cell.x, light.cell.y, light.radius, light.light_type])


## L-IMP-02b: Setup shadow projector for visibility calculations
func _setup_shadow_projector() -> void:
	_shadow_projector = ShadowProjectorClass.new()
	_room.add_child(_shadow_projector)
	
	# Provide reference data from room
	_shadow_projector.set_blocked_cells(_room._blocked_cells)
	_shadow_projector.set_blocked_edges(_room.enemy_phase_controller.build_blocked_edge_set(_room._current_blocked_edges))
	_shadow_projector.set_obstacle_heights(_get_obstacle_heights())
	_shadow_projector.set_room_size(_room._room_size)
	
	print("[Room] Shadow projector initialized")


## Helper: Build obstacle heights dictionary from blocked cells
func _get_obstacle_heights() -> Dictionary:
	var heights: Dictionary = {}
	
	# Read heights from tile semantics map; fallback to HEIGHT_HUMAN if not in semantics
	for cell in _room._blocked_cells.keys():
		if _room._tile_semantics_map.has(cell):
			heights[cell] = _room._tile_semantics_map[cell].height_class
		else:
			heights[cell] = TileSemanticsClass.HEIGHT_HUMAN  # Fallback
	
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
	_room._tile_semantics_map.clear()
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
		
		_room._tile_semantics_map[cell] = semantics
	
	# Find and register light anchor points
	# These would normally come from structured data in the layout.
	# For now, we check if any existing lights are placed:
	if _light_registry != null:
		for light in _light_registry.get_all_lights():
			if not _light_anchors.has(light.cell):
				_light_anchors.append(light.cell)
	
	print("[Room] Tile semantics initialized with %d tiles, %d light anchors" % [
		_room._tile_semantics_map.size(), _light_anchors.size()
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
