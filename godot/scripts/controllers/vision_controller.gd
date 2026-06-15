extends Node2D

## Gerencia os três modos de visualização (DEV, LIGHT, HEAT) e todos os overlays
## de debug e análise. É filho de room.gd na scene tree.
## Comunicação: room.gd chama métodos diretamente; este módulo não emite signals.

# ── Preloads ──────────────────────────────────────────────────────────────────
const LightOverlayClass = preload("res://godot/scripts/overlays/light_overlay.gd")
const ShadowOverlayClass = preload("res://godot/scripts/overlays/shadow_overlay.gd")
const ExposureOverlayClass = preload("res://godot/scripts/overlays/exposure_overlay.gd")
const TileRiskOverlayClass = preload("res://godot/scripts/overlays/tile_risk_overlay.gd")
const HeightOverlayClass = preload("res://godot/scripts/overlays/height_overlay.gd")
const TemporalOverlayClass = preload("res://godot/scripts/overlays/temporal_overlay.gd")
const EliteExposureOverlayClass = preload("res://godot/scripts/overlays/elite_exposure_overlay.gd")

# ── Estado de visão ───────────────────────────────────────────────────────────
var dev_vision: bool = false
var light_vision: bool = false
var heat_vision: bool = false

# ── Referências externas ──────────────────────────────────────────────────────
var _room: Node2D          ## referência ao room.gd — acesso somente leitura
var _fog_of_war: Node2D    ## node FogOfWarOverlay da cena

# ── Instâncias dos overlays ───────────────────────────────────────────────────
var _light_overlay: Node2D = null
var _shadow_overlay: Node2D = null
var _exposure_overlay: Node2D = null
var _tile_risk_overlay: Node2D = null
var _height_overlay: Node2D = null            ## DEV visualization of height classes
var _temporal_overlay: Node2D = null          ## DEV visualization of temporal light states
var _elite_exposure_overlay: Node2D = null    ## DEV visualization of shadow depth and confidence

# ── API pública ───────────────────────────────────────────────────────────────

func setup(room_ref: Node2D, fog_of_war_ref: Node2D) -> void:
	_room = room_ref
	_fog_of_war = fog_of_war_ref
	_init_overlays()

func toggle_dev() -> void:
	dev_vision = not dev_vision
	_apply_dev_vision()

func toggle_light() -> void:
	light_vision = not light_vision
	_apply_light_vision()

func toggle_heat() -> void:
	heat_vision = not heat_vision
	_apply_heat_vision()
	_apply_fow_visibility()

func request_redraw() -> void:
	## Chamado por room.gd após qualquer rebuild de iluminação.
	## Força todos os overlays ativos a se redesenharem.
	if light_vision:
		_apply_light_vision()
	if heat_vision:
		_apply_heat_vision()

# ── Privado ───────────────────────────────────────────────────────────────────

func _init_overlays() -> void:
	## Instancia os overlays, adiciona à scene tree com z-order correto,
	## e faz o setup inicial de cada um.
	_setup_light_overlay()
	_setup_shadow_overlay()
	_setup_exposure_overlay()
	_setup_tile_risk_overlay()
	_setup_height_overlay()
	_setup_temporal_overlay()
	_setup_elite_exposure_overlay()

func _apply_dev_vision() -> void:
	## Toggle FOW when dev_vision, light_vision, or heat_vision is active
	_apply_fow_visibility()

	## Notify each guard of dev_vision state
	for guard in _room._get_all_guards():
		guard.set_dev_vision(dev_vision)

	_room._update_enemy_visibility()
	_room.queue_redraw()  ## Dev 04: redraw trail when toggling dev_vision
	if _room._trail_overlay != null:
		_room._trail_overlay.queue_redraw()
	## M2-14: Update overlay markers for dev_vision
	if _room._tile_game != null:
		if dev_vision:
			## Paint exit cells with purple marker
			_room._tile_game.set_cells_named(_room._exit_cells, "exit", _room.TileOverlayClass.PRIO_NAV)
			## Paint spawn position with gray marker
			_room._tile_game.paint_named(_room._agent_start_cell_base, "spawn_dev", _room.TileOverlayClass.PRIO_DEV)
		else:
			## Clear all dev-only markers when exiting dev_vision
			_room._tile_game.clear_priority(_room.TileOverlayClass.PRIO_NAV)

func _apply_light_vision() -> void:
	## Toggle FOW when dev_vision, light_vision, or heat_vision is active
	_apply_fow_visibility()
	
	## L-IMP-01: Toggle light overlay with light_vision
	if _light_overlay != null:
		_light_overlay.visible = light_vision
		_light_overlay.queue_redraw()
	## L-IMP-02: Toggle shadow overlay with light_vision
	if _shadow_overlay != null:
		_shadow_overlay.visible = light_vision
		_shadow_overlay.set_dev_vision(light_vision)
	## L-IMP-05: Toggle height overlay with light_vision
	if _height_overlay != null:
		_height_overlay.visible = light_vision
		_height_overlay.set_dev_vision(light_vision)
	
	## L-IMP-06: Toggle temporal overlay with light_vision
	if _temporal_overlay != null:
		_temporal_overlay.visible = light_vision
		_temporal_overlay.set_dev_vision(light_vision)

func _apply_heat_vision() -> void:
	if _exposure_overlay != null:
		_exposure_overlay.visible = heat_vision
		_exposure_overlay.set_dev_vision(heat_vision)
		_exposure_overlay.queue_redraw()
	if _tile_risk_overlay != null:
		_tile_risk_overlay.visible = heat_vision
		_tile_risk_overlay.set_dev_vision(heat_vision)
		_tile_risk_overlay.queue_redraw()
	if _elite_exposure_overlay != null:
		_elite_exposure_overlay.visible = heat_vision
		_elite_exposure_overlay.set_dev_vision(heat_vision)
		_elite_exposure_overlay.queue_redraw()

func _apply_fow_visibility() -> void:
	if _fog_of_war != null:
		_fog_of_war.visible = not (dev_vision or light_vision or heat_vision)
	if _room._fog_rect != null:
		_room._fog_rect.visible = not (dev_vision or light_vision or heat_vision)

# ── Setup de overlays ─────────────────────────────────────────────────────────

func _setup_light_overlay() -> void:
	var light_registry = _room._lighting_controller.get_light_registry()
	if light_registry == null:
		return
	
	_light_overlay = LightOverlayClass.new()
	_light_overlay.light_registry = light_registry
	_light_overlay.tile_size = Vector2(128, 64)
	_light_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_light_overlay)
	_light_overlay.z_index = 27  # Above HEAT overlays
	_light_overlay.visible = light_vision


func _setup_shadow_overlay() -> void:
	var light_registry = _room._lighting_controller.get_light_registry()
	if light_registry == null:
		return
	
	_shadow_overlay = ShadowOverlayClass.new()
	_shadow_overlay.shadow_projector = _room._lighting_controller._shadow_projector
	_shadow_overlay.light_registry = light_registry
	_shadow_overlay.tile_size = Vector2(128, 64)
	_shadow_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_shadow_overlay)
	_shadow_overlay.z_index = 28  # Above light overlay and HEAT overlays
	_shadow_overlay.visible = light_vision
	
	print("[VisionController] Shadow overlay initialized")


func _setup_exposure_overlay() -> void:
	var exposure_system = _room._lighting_controller.get_exposure_system()
	if exposure_system == null:
		return
	
	_exposure_overlay = ExposureOverlayClass.new()
	_exposure_overlay.exposure_system = exposure_system
	_exposure_overlay.floor_layer = _room.floor_layer
	_exposure_overlay.tile_size = Vector2(256, 128)
	_exposure_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_exposure_overlay)
	# Position HEAT overlay immediately after FloorLayer (below all structures/entities)
	_room.move_child(_exposure_overlay, _room.floor_layer.get_index() + 1)
	_exposure_overlay.z_index = 0
	_exposure_overlay.z_as_relative = true
	_exposure_overlay.visible = heat_vision
	
	print("[VisionController] Exposure overlay initialized")


func _setup_tile_risk_overlay() -> void:
	var exposure_system = _room._lighting_controller.get_exposure_system()
	if exposure_system == null:
		return
	
	_tile_risk_overlay = TileRiskOverlayClass.new()
	_tile_risk_overlay.exposure_system = exposure_system
	_tile_risk_overlay.floor_layer = _room.floor_layer
	_tile_risk_overlay.tile_size = Vector2(256, 128)
	_tile_risk_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_tile_risk_overlay)
	# Position HEAT overlay immediately after FloorLayer (below all structures/entities)
	_room.move_child(_tile_risk_overlay, _room.floor_layer.get_index() + 1)
	_tile_risk_overlay.z_index = 0
	_tile_risk_overlay.z_as_relative = true
	_tile_risk_overlay.visible = heat_vision
	
	print("[VisionController] Tile risk heatmap overlay initialized")


func _setup_height_overlay() -> void:
	var tile_semantics_map = _room._lighting_controller.get_tile_semantics_map()
	var light_anchors = _room._lighting_controller.get_light_anchors()
	
	if tile_semantics_map.is_empty():
		return
	
	_height_overlay = HeightOverlayClass.new()
	_height_overlay.load_semantics(tile_semantics_map)
	_height_overlay.load_anchors(light_anchors)
	_height_overlay.floor_layer = _room.floor_layer
	_height_overlay.tile_size = Vector2(256, 128)
	_height_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_height_overlay)
	_height_overlay.z_index = 24  # Above all other overlays for semantic visualization
	_height_overlay.visible = light_vision
	
	print("[VisionController] Height overlay initialized with %d anchors" % [light_anchors.size()])


func _setup_temporal_overlay() -> void:
	var light_registry = _room._lighting_controller.get_light_registry()
	if light_registry == null or light_registry.is_empty():
		return
	
	_temporal_overlay = TemporalOverlayClass.new()
	_temporal_overlay.load_lights(light_registry)
	_temporal_overlay.tile_size = Vector2(128, 64)
	_temporal_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_temporal_overlay)
	_temporal_overlay.z_index = 25  # Above height overlay for temporal visualization
	_temporal_overlay.visible = light_vision
	
	print("[VisionController] Temporal overlay initialized: %s" % [_temporal_overlay.debug_info()])


func _setup_elite_exposure_overlay() -> void:
	var exposure_system = _room._lighting_controller.get_exposure_system()
	if exposure_system == null:
		return
	
	_elite_exposure_overlay = EliteExposureOverlayClass.new()
	_elite_exposure_overlay.load_exposure_system(exposure_system)
	_elite_exposure_overlay.floor_layer = _room.floor_layer
	_elite_exposure_overlay.tile_size = Vector2(256, 128)
	_elite_exposure_overlay.visual_offset = _room.VISUAL_GRID_OFFSET
	_room.add_child(_elite_exposure_overlay)
	# Position HEAT overlay immediately after FloorLayer (below all structures/entities)
	_room.move_child(_elite_exposure_overlay, _room.floor_layer.get_index() + 1)
	_elite_exposure_overlay.z_index = 0
	_elite_exposure_overlay.z_as_relative = true
	_elite_exposure_overlay.visible = heat_vision
	
	print("[VisionController] Elite exposure overlay initialized: %s" % [_elite_exposure_overlay.debug_info()])
