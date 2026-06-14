extends Node2D
## Tactical room controller: input, UI wiring, agent turns and scene setup.

const RoomLayoutBuilder = preload("res://godot/scripts/world/room_layout_builder.gd")
const LevelGraphClass    = preload("res://godot/scripts/world/level_graph.gd")
const GuardEnemyClass    = preload("res://godot/scripts/agents/guard_enemy.gd")
const GuardNoiseIndicatorClass = preload("res://godot/scripts/overlays/guard_noise_indicator.gd")
const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")

## M2-13: Fonte de luz para cálculo de sombras direcionais
class LightSource:
	var cell: Vector2i
	var height: float
	var radius: int
	var intensity: float
	var active: bool = true
	var direction: Vector2
	
	func _init(p_cell: Vector2i, p_height: float, p_radius: int,
	           p_intensity: float = 0.9, p_dir: Vector2 = Vector2.ZERO) -> void:
		cell = p_cell
		height = p_height
		radius = p_radius
		intensity = p_intensity
		direction = p_dir

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var turn_manager:        TacticalTurnManager = $TurnManager
@onready var enemy_phase_controller: EnemyPhaseController = $EnemyPhaseController
@onready var enemies_root:         Node2D       = $Enemies
@onready var movement_overlay:    MovementOverlay = $MovementOverlay
@onready var path_preview:        PathPreview  = $PathPreview
@onready var structure_wall_layer:       TileMapLayer = $StructureWallLayer
@onready var structure_wall_upper_layer: TileMapLayer = $StructureWallUpperLayer
@onready var structure_layer:            TileMapLayer = $StructureLayer
@onready var shadow_full_layer:    TileMapLayer = $ShadowFullLayer
@onready var shadow_partial_layer: TileMapLayer = $ShadowPartialLayer
@onready var selection_overlay:   Node2D       = $SelectionOverlay
@onready var agent:               DebugAgent   = $Agent
@onready var tile_labels_overlay: Node2D       = $TileLabelsOverlay
@onready var camera:              Camera2D     = $Camera2D
@onready var btn_numbers:         Button       = $HUD/TopBar/Row/BtnNumbers
@onready var btn_fullscreen:      Button       = $HUD/TopBar/Row/BtnFullscreen
@onready var btn_viewport:        Button       = $HUD/TopBar/Row/BtnViewport
@onready var btn_reset:           Button       = $HUD/TopBar/Row/BtnReset
@onready var btn_perspective_nw:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveNW
@onready var btn_perspective_ne:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveNE
@onready var btn_perspective_sw:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveSW
@onready var btn_perspective_se:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveSE
@onready var lbl_ap:              Label        = $HUD/TopBar/Row/LblAp
@onready var chk_auto_end_turn:   CheckBox        = $HUD/TopBar/Row/BtnEndTurn/Content/ChkAutoEndTurn
@onready var btn_end_turn:        Button          = $HUD/TopBar/Row/BtnEndTurn
@onready var lbl_alert:           Label           = $HUD/TopBar/Row/LblAlert
@onready var busted_dialog:       Label           = $HUD/BustedDialog
@onready var enemy_turn_banner:   Control         = $HUD/EnemyTurnBanner
@onready var fog_of_war:          Node2D          = $FogOfWarOverlay
@onready var _fog_rect:           ColorRect       = $VisionFogOverlay/FogRect

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const INVALID_CELL := Vector2i(-9999, -9999)

## The TileMap renders the current 512px-tall source tiles lower than the
## logical grid used by map_to_local/local_to_map. Compensate with one fixed
## visual offset so camera, labels, selection and picking all agree.
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)

## tile_name → TileSet source_id
var _tile_ids: Dictionary = {}
var _room_size: Vector2i = Vector2i.ZERO
var _blocked_cells: Dictionary = {}
var _base_layout: Dictionary = {}
var _current_blocked_edges: Array[Dictionary] = []
var _guards: Array = []

var _shadow_tiles: Dictionary = {}     ## Vector2i → float (multiplicador)
var _exit_cells: Array[Vector2i] = []  ## Tiles de saída do segmento (doorOpen_*)
const SHADOW_MULT   := GuardEnemy.SHADOW_MULT
const PENUMBRA_MULT := GuardEnemy.PENUMBRA_MULT

## M2-13: Altura de obstáculos (em tiles acima do plano do chão)
const OBSTACLE_HEIGHTS: Dictionary = {
	"crate":     1.0,
	"wall":      2.0,
	"block":     2.0,
	"column":    3.0,
	"half_wall": 1.0,
}
const OBSTACLE_HEIGHT_DEFAULT := 1.5

## M2-13: Fontes de luz e alturas de obstáculos
var _light_sources: Array[LightSource] = []
var _obstacle_heights: Dictionary = {}

## Camera drag state (left mouse — drag vs click distinguished by threshold)
const DRAG_THRESHOLD_SQ := 64.0   ## 8 px squared

var _left_down:        bool    = false
var _drag_started:     bool    = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam:   Vector2 = Vector2.ZERO

## Zoom limits and step
const ZOOM_MIN  := 0.20
const ZOOM_MAX  := 1.20
const ZOOM_STEP := 0.06

## Vision & FOW radii — independent of each other:
## VISION_TILE_RADIUS  controls only the shader gradient (live clear-circle around agent).
## FOW_REVEAL_RADIUS   controls how many tiles get permanently revealed each move,
##                     and is also the hard limit of the camera leash.
const VISION_TILE_RADIUS := 5      ## shader gradient radius (tiles)
const FOW_REVEAL_RADIUS  := 9      ## FOW reveal radius + camera leash hard limit (tiles)
const CAMERA_SOFT_ZONE_TILES := 2  ## tiles of ease-out damping before leash hard stop
const CAMERA_MAX_BORDER_TILES := 4  ## max tiles camera can see outside scenario boundary
const WORLD_TILE_PX          := 128.0  ## horizontal px per isometric tile step

## Pinch-zoom state (mobile two-finger)
var _touches:         Dictionary = {}   ## finger_index → screen position
var _pinch_last_dist: float      = 0.0

## Viewport toggle state
var _is_desktop_viewport: bool = false
var _pending_auto_end_turn: bool = false
var _selected_cell: Vector2i = INVALID_CELL
var _active_perspective: String = "N"
var _alert_meter: int = 0

var _alert_max: int = 100
var _alert_gain_full: int = 45

## ID-01: Thresholds do detection meter para transições de estado
const DETECTION_THRESHOLD_SUSPICIOUS := 0.30
const DETECTION_THRESHOLD_ALERT      := 0.60
const DETECTION_THRESHOLD_CHASE      := 1.00

const ENEMY_INTER_TURN_DELAY := 1.0
const ENEMY_CAMERA_TWEEN_DURATION := 0.45
const ENEMY_PHASE_MAX_OPEN_ZOOM := 0.65
const ACTOR_END_HOLD_DELAY := 0.5

var _actor_end_pause_active: bool = false

const _PERSPECTIVE_SUFFIX_MAP := {
	"N": {"NE": "NE", "SE": "SE", "SW": "SW", "NW": "NW"},
	"E": {"NE": "SE", "SE": "SW", "SW": "NW", "NW": "NE"},
	"S": {"NE": "SW", "SE": "NW", "SW": "NE", "NW": "SE"},
	"W": {"NE": "NW", "SE": "NE", "SW": "SE", "NW": "SW"},
}

## Vision bonus added by agent abilities; combined with the player vision radius.
var vision_bonus_tiles: int = 0
var _agent_start_cell: Vector2i = Vector2i.ZERO
var _agent_start_cell_base: Vector2i = Vector2i.ZERO
var dev_vision: bool = false

## M2-10: Peek mechanic state
var _peek_active: bool = false
var _peek_timer: int   = 0
var _peek_pending: bool = false

## Dev 03: tile hover info
var _dev_hover_label: Label = null
var _hovered_cell: Vector2i = Vector2i(-1, -1)

## Dev 04: agent trail overlay
const TRAIL_MAX := 5
var _agent_trail: Array[Vector2i] = []
var _tile_shadow: Node2D = null  ## TileOverlay para sombras (z=1, multiply)
var _tile_game: Node2D = null   ## TileOverlay para jogo visual (z=3, mix)
var _trail_overlay: Node2D = null

## M2-04: noise system and overlay
var _noise_system = null
var _noise_overlay: Node2D = null

## M2-14: Guard noise indicator — flutuante ao redor do agente
var _guard_noise_indicator: Node2D = null

## M2-14: Chance de ruído por estado do guarda
const GUARD_NOISE_CHANCE_BY_STATE := {
	"patrol": 0.15,
	"suspicious": 0.40,
	"alert": 0.60,
	"chase": 0.70,
	"search": 0.50,
}

## M2-14: Intensidade de ruído por estado do guarda
const GUARD_NOISE_INTENSITY_BY_STATE := {
	"patrol": 0.4,
	"suspicious": 0.6,
	"alert": 0.9,
	"chase": 1.0,
	"search": 0.7,
}

## Position of this segment in the 3×3 level grid (gx, gy in 0..2).
## Set before _ready() runs (e.g. by the level controller or via the Inspector).
## Controls which exits LevelGraph assigns; default (1,1) = centre segment (all exits open).
@export var segment_grid_pos: Vector2i = Vector2i(1, 1)
## Seed for the level graph random generator. Match across all 9 segments in a level.
@export var level_seed: int = 0

const WHISTLE_RADIUS := 3


func _ready() -> void:
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	floor_layer.z_index = 0
	structure_wall_layer.tile_set = ts
	structure_wall_layer.z_index = 10
	structure_wall_upper_layer.tile_set = ts
	structure_wall_upper_layer.z_index = 11
	structure_layer.tile_set = ts
	structure_layer.z_index = 10
	## M2-13: Initialize shadow layers
	shadow_full_layer.tile_set = ts
	shadow_partial_layer.tile_set = ts
	shadow_full_layer.z_index = 1
	shadow_partial_layer.z_index = 1
	shadow_full_layer.modulate = Color(0.58, 0.58, 0.58, 1.0)
	shadow_partial_layer.modulate = Color(0.78, 0.78, 0.78, 1.0)
	_build_registry(ts)

	var graph: LevelGraph = LevelGraphClass.new()
	var connections: Dictionary = graph.generate(level_seed)
	var access_points: Array = LevelGraphClass.access_points_for(connections, segment_grid_pos)

	var layout_builder = RoomLayoutBuilder.new()
	var layout: Dictionary = layout_builder.build_layout(access_points)
	_base_layout = layout.duplicate(true)
	_agent_start_cell_base = layout.get("agent_start_cell", Vector2i.ZERO)
	_room_size = layout.get("size", Vector2i.ZERO)
	if _room_size == Vector2i.ZERO:
		push_error("Room layout did not provide a valid map size.")
		return

	var view_layout := _layout_with_perspective(_base_layout, _active_perspective)
	_room_size = view_layout.get("size", _room_size)
	_build_room(view_layout)
	var agent_start_cell: Vector2i = view_layout.get("agent_start_cell", Vector2i.ZERO)
	_agent_start_cell = agent_start_cell
	_center_camera(agent_start_cell)

	## Give overlays their references.
	movement_overlay.z_index = 5
	movement_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, turn_manager.move_points_per_ap)
	movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
	var blocked_edges: Array[Dictionary] = []
	for e in view_layout.get("blocked_edges", []):
		blocked_edges.append(e)
	_current_blocked_edges = blocked_edges.duplicate(true)
	movement_overlay.set_blocked_edges(blocked_edges)
	path_preview.setup(floor_layer, VISUAL_GRID_OFFSET)
	path_preview.z_index = 6
	selection_overlay.floor_layer = floor_layer
	selection_overlay.visual_offset = VISUAL_GRID_OFFSET
	selection_overlay.z_index = 7

	agent.setup(floor_layer, VISUAL_GRID_OFFSET, agent_start_cell)
	agent.z_index = 10
	_spawn_guards(view_layout.get("enemy_defs", []))
	enemies_root.z_index = 10
	fog_of_war.setup(floor_layer, VISUAL_GRID_OFFSET, _room_size)
	fog_of_war.reveal_around(agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w = _room_size.x
	tile_labels_overlay.room_h = _room_size.y
	tile_labels_overlay.visible = false
	btn_numbers.modulate = Color(1.0, 1.0, 1.0, 0.35)
	camera.ignore_rotation = true
	camera.rotation_degrees = 0.0

	turn_manager.ap_changed.connect(_on_ap_changed)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.enemy_phase_started.connect(_on_enemy_phase_started)
	agent.move_started.connect(_on_agent_move_started)
	agent.step_finished.connect(_on_agent_step_finished)
	agent.move_finished.connect(_on_agent_move_finished)
	btn_end_turn.pressed.connect(_on_btn_end_turn)
	btn_numbers.pressed.connect(_on_btn_numbers)
	btn_fullscreen.pressed.connect(_on_btn_fullscreen)
	btn_viewport.pressed.connect(_on_btn_viewport)
	btn_reset.pressed.connect(_on_btn_reset)
	btn_perspective_nw.pressed.connect(func() -> void: _set_perspective("W"))
	btn_perspective_ne.pressed.connect(func() -> void: _set_perspective("N"))
	btn_perspective_sw.pressed.connect(func() -> void: _set_perspective("S"))
	btn_perspective_se.pressed.connect(func() -> void: _set_perspective("E"))
	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	turn_manager.reset_player_turn()
	_update_alert_label()
	enemy_turn_banner.visible = false
	_apply_dev_vision()
	## Dev 04: Create and setup trail overlay
	var TrailOverlayClass = preload("res://godot/scripts/overlays/trail_overlay.gd")
	_trail_overlay = Node2D.new()
	_trail_overlay.set_script(TrailOverlayClass)
	add_child(_trail_overlay)
	_trail_overlay.setup(self, floor_layer, VISUAL_GRID_OFFSET)

	## M2-04: Create and setup noise system and overlay
	var NoiseSystemClass = preload("res://godot/scripts/systems/noise_system.gd")
	_noise_system = NoiseSystemClass.new()

	var NoiseOverlayClass = preload("res://godot/scripts/overlays/noise_overlay.gd")
	_noise_overlay = Node2D.new()
	_noise_overlay.set_script(NoiseOverlayClass)
	add_child(_noise_overlay)
	_noise_overlay.setup(self, floor_layer, VISUAL_GRID_OFFSET, _noise_system)

	## M2-14: Create and setup TileOverlay instances for shadow and game visuals
	_tile_shadow = Node2D.new()
	_tile_shadow.set_script(TileOverlayClass)
	_tile_shadow.z_index = 1  ## Renders below (shadow)
	add_child(_tile_shadow)
	_tile_shadow.material = CanvasItemMaterial.new()
	_tile_shadow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tile_shadow.setup(floor_layer, VISUAL_GRID_OFFSET)

	_tile_game = Node2D.new()
	_tile_game.set_script(TileOverlayClass)
	_tile_game.z_index = 3  ## Renders above noise/detection
	add_child(_tile_game)
	_tile_game.material = CanvasItemMaterial.new()
	_tile_game.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_tile_game.setup(floor_layer, VISUAL_GRID_OFFSET)

	## M2-14 Quickfix: Z-index ordering — floor(0) < shadow(1) < fog(2) < structures(3) < sprites(4+)
	## Ensure fog_of_war is properly layered above shadow overlay
	fog_of_war.z_index = 2

	## M2-14: Create and setup guard noise indicator — as child of agent so it orbits naturally
	_guard_noise_indicator = GuardNoiseIndicatorClass.new()
	agent.add_child(_guard_noise_indicator)
	_guard_noise_indicator.setup(floor_layer, VISUAL_GRID_OFFSET)

	## Dev 03: Create hover label for tile coordinates
	_dev_hover_label = Label.new()
	_dev_hover_label.add_theme_font_size_override("font_size", 13)
	_dev_hover_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	_dev_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_dev_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	_dev_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	_dev_hover_label.position = Vector2(12.0, 80.0)   ## below TopBar
	_dev_hover_label.z_index = 200
	_dev_hover_label.visible = false
	$HUD.add_child(_dev_hover_label)
	_update_perspective_button_state()

	## Centering camera/setup initial state
	_update_guard_los_data()
	_on_btn_viewport()


func _set_perspective(direction: String) -> void:
	if not _PERSPECTIVE_SUFFIX_MAP.has(direction):
		return
	if _active_perspective == direction:
		_update_perspective_button_state()
		return

	var prev_direction := _active_perspective
	var base_agent := _cell_to_base(agent.cell, prev_direction)
	var has_selected := _selected_cell != INVALID_CELL
	var base_selected := _cell_to_base(_selected_cell, prev_direction) if has_selected else INVALID_CELL

	_active_perspective = direction
	if not _base_layout.is_empty():
		var view_layout := _layout_with_perspective(_base_layout, _active_perspective)
		_room_size = view_layout.get("size", _room_size)
		_agent_start_cell = view_layout.get("agent_start_cell", _agent_start_cell)
		_build_room(view_layout)
		_spawn_guards(view_layout.get("enemy_defs", []))
		movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
		var blocked_edges: Array[Dictionary] = []
		for e in view_layout.get("blocked_edges", []):
			blocked_edges.append(e)
		_current_blocked_edges = blocked_edges.duplicate(true)
		movement_overlay.set_blocked_edges(blocked_edges)

		tile_labels_overlay.room_w = _room_size.x
		tile_labels_overlay.room_h = _room_size.y

		var next_agent := _cell_from_base(base_agent, _active_perspective)
		if not _is_cell_inside_room(next_agent):
			next_agent = _agent_start_cell
		agent.set_cell(next_agent)

		if has_selected:
			var next_selected := _cell_from_base(base_selected, _active_perspective)
			_selected_cell = next_selected if _is_selectable_cell(next_selected) else next_agent
		else:
			_selected_cell = next_agent
		selection_overlay.set_selected(_selected_cell)

		fog_of_war.setup(floor_layer, VISUAL_GRID_OFFSET, _room_size)
		fog_of_war.reveal_around(agent.cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
		_apply_dev_vision()
		_update_guard_los_data()
		_center_camera(agent.cell)
		_refresh_tactical_state()
	_update_perspective_button_state()


func _update_perspective_button_state() -> void:
	var active_mod := Color(1.0, 1.0, 1.0, 1.0)
	var inactive_mod := Color(1.0, 1.0, 1.0, 0.45)
	btn_perspective_nw.modulate = active_mod if _active_perspective == "W" else inactive_mod
	btn_perspective_ne.modulate = active_mod if _active_perspective == "N" else inactive_mod
	btn_perspective_sw.modulate = active_mod if _active_perspective == "S" else inactive_mod
	btn_perspective_se.modulate = active_mod if _active_perspective == "E" else inactive_mod


func _center_camera(focus_cell: Vector2i) -> void:
	var centre_world := floor_layer.map_to_local(focus_cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	camera.global_position = centre_world


func _on_btn_numbers() -> void:
	tile_labels_overlay.visible = not tile_labels_overlay.visible
	btn_numbers.modulate = Color.WHITE if tile_labels_overlay.visible else Color(1.0, 1.0, 1.0, 0.35)


func _on_btn_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_btn_end_turn() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	turn_manager.end_turn()


func _on_btn_reset() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	enemy_turn_banner.visible = false
	agent.set_cell(_agent_start_cell)
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)
	fog_of_war.reset_fog()
	fog_of_war.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	_center_camera(_agent_start_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()
	_alert_meter = 0
	_update_alert_label()
	## Dev 04: clear trail on reset
	_agent_trail.clear()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()
	## M2-04: clear noise on reset
	if _noise_system != null:
		_noise_system.clear()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	turn_manager.reset_player_turn()


func _on_btn_viewport() -> void:
	_is_desktop_viewport = not _is_desktop_viewport
	var target := Vector2i(1280, 720) if _is_desktop_viewport else Vector2i(390, 844)
	btn_viewport.text = "D" if _is_desktop_viewport else "M"

	## Exit fullscreen first — can't resize while in fullscreen.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	## Resize the OS window.
	DisplayServer.window_set_size(target)

	## Change the logical canvas resolution so the camera sees the right world area.
	## Without this, canvas_items stretch just scales the fixed 390×844 base to fill the window.
	get_tree().root.content_scale_size = target

	## Center on screen after resize.
	var screen_size := DisplayServer.screen_get_size()
	var centered := Vector2(screen_size - target) / 2.0
	DisplayServer.window_set_position(Vector2i(centered.round()))


func _update_guard_los_data() -> void:
	var blocked_edges := enemy_phase_controller.build_blocked_edge_set(
		_current_blocked_edges
	)
	for guard in _guards:
		if is_instance_valid(guard):
			guard.set_los_data(_blocked_cells, blocked_edges, _room_size, _shadow_tiles)


func _draw_exit_markers() -> void:
	## Diamante roxo em cada tile de saída do segmento.
	## Desenhado em _draw() do nó Room — renderiza abaixo do fog_of_war.
	## Revelado naturalmente quando o FOW descobre a área. Visível em DEV_VISION
	## porque o fog fica oculto (fog_of_war.visible = false).
	if _exit_cells.is_empty():
		return
	for cell: Vector2i in _exit_cells:
		var world := _world_center_for_cell(cell)
		var hw := 90.0
		var hh := 45.0
		var pts := PackedVector2Array([
			world + Vector2(0.0, -hh),
			world + Vector2(hw,  0.0),
			world + Vector2(0.0,  hh),
			world + Vector2(-hw, 0.0),
		])
		draw_colored_polygon(pts, Color(0.55, 0.10, 0.90, 0.28))
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.72, 0.25, 1.00, 0.82), 3.0
		)

func _draw_spawn_marker() -> void:
	## Diamante escuro no ponto de spawn — DEV_VISION apenas.
	## Permite identificar rapidamente o AGENT_START_CELL ao testar mapas.
	if not dev_vision:
		return
	if _agent_start_cell == INVALID_CELL:
		return
	var world := _world_center_for_cell(_agent_start_cell)
	var hw := 55.0
	var hh := 28.0
	var pts := PackedVector2Array([
		world + Vector2(0.0, -hh),
		world + Vector2(hw,  0.0),
		world + Vector2(0.0,  hh),
		world + Vector2(-hw, 0.0),
	])
	draw_colored_polygon(pts, Color(0.05, 0.05, 0.05, 0.45))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.22, 0.22, 0.22, 0.80), 2.0
	)

func _draw_shadow_debug() -> void:
	## M2-13: ShadowOverlay agora lida com a visualização permanente.
	## Mantido apenas para debug técnico em DEV_VISION (azul translúcido sobreposto).
	if not dev_vision:
		return
	for shadow_cell in _shadow_tiles.keys():
		var mult: float = _shadow_tiles[shadow_cell]
		var world_pos := floor_layer.map_to_local(shadow_cell) + VISUAL_GRID_OFFSET
		var hw := 128.0   ## 256 / 2
		var hh := 64.0    ## 128 / 2
		var diamond := PackedVector2Array([
			world_pos + Vector2(0.0,  -hh),
			world_pos + Vector2(hw,   0.0),
			world_pos + Vector2(0.0,   hh),
			world_pos + Vector2(-hw,  0.0),
		])
		## Sombra direta: azul escuro. Penumbra: azul mais claro.
		var alpha := 0.35 if mult < PENUMBRA_MULT else 0.15
		var color := Color(0.1, 0.4, 1.0, alpha)
		draw_colored_polygon(diamond, color)


func _on_ap_changed(current_ap: int, max_ap: int) -> void:
	lbl_ap.text = "INIMIGOS" if turn_manager.is_enemy_phase else "AP %d/%d" % [current_ap, max_ap]
	movement_overlay.set_remaining_ap(current_ap)
	if not agent.is_moving:
		_refresh_tactical_state()
	
	if current_ap == 0 and not turn_manager.is_enemy_phase:
		_peek_pending = false


## Peek mechanic: espreitar além de um obstáculo adjacente sem mover
func _try_peek(direction: Vector2i) -> void:
	if turn_manager.current_ap < 1:
		return
	
	var target_cell := agent.cell + direction
	if not _blocked_cells.has(target_cell):
		return # Só faz sentido dar peek em obstáculos
		
	## Revela 3 tiles adiante na direção do peek
	for i in range(1, 4):
		var peek_cell := agent.cell + direction * i
		if not _is_cell_inside_room(peek_cell):
			break
		fog_of_war.add_peek_reveal(peek_cell)
		
	turn_manager.consume_ap(1)
	_peek_active = true
	_peek_timer = 1
	_update_guard_los_data()


func _on_agent_move_started(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	selection_overlay.set_selected(to_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()


func _on_agent_step_finished(step_cell: Vector2i) -> void:
	fog_of_war.reveal_around(step_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Dev 04: register trail — last position when stepping in
	if _agent_trail.is_empty() or _agent_trail.back() != step_cell:
		_agent_trail.append(step_cell)
		if _agent_trail.size() > TRAIL_MAX:
			_agent_trail.pop_front()

	if dev_vision and _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## M2-04: Gerar barulho por tic — rola dado a cada passo
	if _noise_system != null:
		if randf() < NoiseSystem.NOISE_CHANCE_WALK:
			_noise_system.emit(step_cell, NoiseSystem.NOISE_INTENSITY_WALK)
		if _noise_overlay != null:
			_noise_overlay.queue_redraw()

	## M2-05: Detecção auditiva imediata após gerar barulho
	_process_audio_detection()

	## Tic de detecção — agente cruzou uma aresta
	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var result: TicSystem.TicResult = TicSystem.evaluate(
			guard, step_cell, _blocked_cells, blocked_edges
		)
		_apply_tic_result(guard, result)


## Processa resultado de um tic de detecção para um guarda.
func _apply_tic_result(guard, result: TicSystem.TicResult) -> void:
	## Acumula ou decai o campo detection do guarda
	if result.visible:
		guard.detection = clampf(
			guard.detection + result.raw_chance * TicSystem.DETECTION_GAIN_PER_TIC,
			0.0, 1.0
		)
	else:
		## Decaimento fora do cone
		var decay := _get_detection_decay(guard.state)
		guard.detection = clampf(guard.detection + decay, 0.0, 1.0)

	## M2-04: Barulho amplifica detecção se o guarda já vê o tile
	if _noise_system != null:
		var noise_intensity: float = _noise_system.get_intensity(agent.cell)
		if noise_intensity > 0.0 and result.visible:
			var bonus: float = noise_intensity * 0.3
			guard.detection = clampf(guard.detection + bonus, 0.0, 1.0)

	if dev_vision:
		guard.queue_redraw()

	## ID-01: Escalação gradual por threshold — só quando agente está visível
	if result.visible:
		if guard.detection >= DETECTION_THRESHOLD_CHASE:
			guard.observe_player(true, 3, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max:
				_on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_ALERT:
			guard.observe_player(true, 2, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max:
				_on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
			guard.observe_player(true, 1, agent.cell)
		## Abaixo de DETECTION_THRESHOLD_SUSPICIOUS: meter acumula, sem mudança de estado

	_update_alert_label()


func _get_detection_decay(state: String) -> float:
	match state:
		"patrol":
			return -0.15
		"suspicious":
			return -0.06
		"alert":
			return -0.04
		"chase":
			return -0.01
	return -0.10


## M2-05: Processa detecção auditiva para todos os guardas
func _process_audio_detection() -> void:
	if _noise_system == null:
		return

	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(
		_current_blocked_edges
	)

	for guard in _guards:
		if not is_instance_valid(guard):
			continue

		for noise_tile in _noise_system.get_noisy_tiles():
			var intensity: float = _noise_system.get_intensity(noise_tile)
			if intensity <= 0.0:
				continue

			var perceived: float = TicSystem.evaluate_audio(
				guard, noise_tile, intensity, blocked_edges
			)
			if perceived > 0.0:
				guard.hear_noise(noise_tile, perceived)


func _on_agent_move_finished(_cell: Vector2i) -> void:
	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	
	## M2-10: Update cover
	agent.update_cover(_blocked_cells)
	
	_update_enemy_visibility()
	movement_overlay.set_remaining_ap(turn_manager.current_ap)
	if _pending_auto_end_turn:
		_pending_auto_end_turn = false
		turn_manager.end_turn()
		return
	_refresh_tactical_state()


func _try_change_posture(new_posture: DebugAgent.Posture) -> void:
	if agent.posture == new_posture:
		return
	if turn_manager.is_enemy_phase:
		return
	if turn_manager.current_ap < DebugAgent.POSTURE_CHANGE_AP:
		return
		
	turn_manager.consume_ap(DebugAgent.POSTURE_CHANGE_AP)
	agent.set_posture(new_posture)
	_refresh_tactical_state()
	_update_guard_los_data()


func _refresh_tactical_state() -> void:
	movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
	movement_overlay.rebuild(agent.cell, turn_manager.get_max_move_points())
	_update_selected_preview()
	_update_enemy_visibility()
	_update_movement_highlight()


func _on_player_turn_started() -> void:
	_update_guard_los_data()
	if _peek_active:
		_peek_timer -= 1
		if _peek_timer <= 0:
			_peek_active = false
			fog_of_war.reset_peek_reveals()


func _on_enemy_phase_started() -> void:
	if _guards.is_empty():
		turn_manager.finish_enemy_phase()
		return
	_update_guard_los_data()
	enemy_turn_banner.visible = true
	movement_overlay.clear_overlay()
	path_preview.clear_path()
	selection_overlay.set_selected(agent.cell)
	## M2-14: Travar câmera no agente durante turno inimigo
	_center_camera(agent.cell)
	await _hold_actor_end_pause()
	await _run_enemy_phase()
	enemy_turn_banner.visible = false
	if _alert_meter >= _alert_max:
		await _show_busted_dialog()
		_reset_room_state()
	_update_alert_label()

	## M2-04: Decay noise at end of enemy phase
	if _noise_system != null:
		_noise_system.decay_all()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()

	## Retornar câmera para o agente ao final do turno inimigo
	_center_camera(agent.cell)

	turn_manager.finish_enemy_phase()


func _run_enemy_phase() -> void:
	## M2-05: Processar barulhos persistentes antes dos guardas agirem
	_process_audio_detection()

	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)
	var occupied: Dictionary = {}
	for guard in _guards:
		if is_instance_valid(guard):
			occupied[guard.cell] = guard

	var max_severity := 0
	for i in range(_guards.size()):
		var guard = _guards[i]
		if not is_instance_valid(guard):
			continue

		var report: Dictionary = await enemy_phase_controller.run_single_guard_turn(
			guard,
			agent.cell,
			_blocked_cells,
			blocked_edges,
			_room_size,
			occupied,
			_apply_tic_result,   ## passa o callback
			_on_guard_emits_noise   ## M2-14: callback de ruído
		)
		max_severity = maxi(max_severity, int(report.get("max_severity", 0)))

		## Câmera segue guard apenas se o tile dele está revelado pelo FOW
		if fog_of_war.is_cell_revealed(guard.cell):
			await _focus_camera_for_enemy_phase(guard.cell)

		await _hold_actor_end_pause()

	## Acumulação de alerta agora acontece em _apply_tic_result() durante os tics
	_update_enemy_visibility()


func _enemy_inter_turn_pause_with_camera(target_cell: Vector2i) -> void:
	var tween_time := minf(ENEMY_CAMERA_TWEEN_DURATION, ENEMY_INTER_TURN_DELAY)
	await _focus_camera_for_enemy_phase(target_cell, tween_time)
	var remain := ENEMY_INTER_TURN_DELAY - tween_time
	if remain > 0.0:
		await get_tree().create_timer(remain).timeout


func _hold_actor_end_pause() -> void:
	_actor_end_pause_active = true
	await get_tree().create_timer(ACTOR_END_HOLD_DELAY).timeout
	_actor_end_pause_active = false


func _focus_camera_for_enemy_phase(target_cell: Vector2i, duration: float = ENEMY_CAMERA_TWEEN_DURATION) -> void:
	if target_cell == INVALID_CELL:
		return
	var target_world := _world_center_for_cell(target_cell)
	var target_zoom := camera.zoom.x
	if target_zoom > ENEMY_PHASE_MAX_OPEN_ZOOM:
		target_zoom = ENEMY_PHASE_MAX_OPEN_ZOOM

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_world, duration)
	tween.tween_property(camera, "zoom", Vector2(target_zoom, target_zoom), duration)
	await tween.finished


func _world_center_for_cell(cell: Vector2i) -> Vector2:
	return floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET


## M2-14: Emitir indicador sonoro na direção do ruído (com imprecisão de ±2 tiles)
func _emit_guard_noise_indicator(guard_cell: Vector2i, intensity: float) -> void:
	if _guard_noise_indicator == null:
		return
	
	## Imprecisão: offset aleatório de ±2 tiles para não revelar posição exata
	var fuzzy_cell := guard_cell + Vector2i(
		randi_range(-2, 2),
		randi_range(-2, 2)
	)
	var agent_world  := floor_layer.map_to_local(agent.cell) + VISUAL_GRID_OFFSET
	var noise_world  := floor_layer.map_to_local(fuzzy_cell) + VISUAL_GRID_OFFSET
	
	_guard_noise_indicator.add_indicator(agent_world, noise_world, intensity)


## M2-14: Callback: executado quando um guarda emite ruído após se mover
func _on_guard_emits_noise(guard, guard_cell: Vector2i) -> void:
	if _noise_system == null or guard == null:
		return
	
	## Chance de ruído por estado do guarda
	var noise_chance: float = GUARD_NOISE_CHANCE_BY_STATE.get(guard.state, 0.10) as float
	if randf() < noise_chance:
		## Intensidade de ruído por estado
		var noise_intensity: float = GUARD_NOISE_INTENSITY_BY_STATE.get(guard.state, 0.5) as float
		## Emitir no sistema de ruído global
		_noise_system.emit(guard_cell, noise_intensity)
		## Emitir indicador sonoro para o agente
		_emit_guard_noise_indicator(guard_cell, noise_intensity)
		## Redraw dos overlays para atualizar visual
		if _noise_overlay != null:
			_noise_overlay.queue_redraw()


func _update_alert_label() -> void:
	lbl_alert.text = "ALERTA %d%%" % _alert_meter
	var t := float(_alert_meter) / float(_alert_max)
	lbl_alert.modulate = Color(1.0, 1.0 - 0.55 * t, 1.0 - 0.75 * t, 1.0)


func _show_busted_dialog() -> void:
	busted_dialog.text = "Busted"
	busted_dialog.visible = true
	await get_tree().create_timer(1.2).timeout
	busted_dialog.visible = false


## ID-02: Flush completo de memória — reseta todos os estados quando a sala precisa reiniciar
func _reset_room_state() -> void:
	## Zera alerta global
	_alert_meter = 0

	## Reseta posição do agente
	agent.set_cell(_agent_start_cell)
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)

	## Reseta todos os guardas para rotas iniciais
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()

	## Limpa trail do agente
	_agent_trail.clear()

	## Reseta FOW
	fog_of_war.reset_fog()
	fog_of_war.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Limpa sistema de ruído
	if _noise_system != null:
		_noise_system.clear()

	## Reseta overlays visuais
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## Centra câmera no agente
	_center_camera(agent.cell)

	## Force UI update
	_update_alert_label()


func _toggle_dev_vision() -> void:
	dev_vision = not dev_vision
	_apply_dev_vision()


func _apply_dev_vision() -> void:
	## Toggle FOW when dev_vision is active
	fog_of_war.visible = not dev_vision
	_fog_rect.visible = not dev_vision

	## Notify each guard of dev_vision state
	for guard in _get_all_guards():
		guard.set_dev_vision(dev_vision)

	_update_enemy_visibility()
	queue_redraw()  ## Dev 04: redraw trail when toggling dev_vision
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()
	
	## M2-14: Update overlay markers for dev_vision
	if _tile_game != null:
		if dev_vision:
			## Paint exit cells with purple marker
			_tile_game.set_cells_named(_exit_cells, "exit", TileOverlayClass.PRIO_NAV)
			## Paint spawn position with gray marker
			_tile_game.paint_named(_agent_start_cell_base, "spawn_dev", TileOverlayClass.PRIO_DEV)
		else:
			## Clear all dev-only markers when exiting dev_vision
			_tile_game.clear_priority(TileOverlayClass.PRIO_NAV)
			_tile_game.clear_priority(TileOverlayClass.PRIO_DEV)
		_tile_game.queue_redraw()


func _get_all_guards() -> Array:
	## Returns all GuardEnemy children in the enemies_root node.
	var result: Array = []
	for child in enemies_root.get_children():
		if child is GuardEnemy:
			result.append(child)
	return result


func _update_dev_hover_label() -> void:
	if _dev_hover_label == null:
		return

	_dev_hover_label.visible = dev_vision

	if not dev_vision or _hovered_cell == INVALID_CELL:
		return

	var cell := _hovered_cell
	var info := "tile  %d , %d" % [cell.x, cell.y]
	info += "\nblocked: %s" % ("yes" if _blocked_cells.has(cell) else "no")

	for guard in _guards:
		if is_instance_valid(guard) and guard.cell == cell:
			info += "\nguard: %s  [%s]" % [guard.enemy_id, guard.state]

	if agent.cell == cell:
		info += "\nagent here"

	_dev_hover_label.text = info


func _spawn_guards(enemy_defs: Array) -> void:
	for child in enemies_root.get_children():
		child.queue_free()
	_guards.clear()

	for i in range(enemy_defs.size()):
		var entry: Dictionary = enemy_defs[i]
		var route: Array[Vector2i] = []
		for c in entry.get("route", []):
			route.append(c)
		if route.size() < 2:
			continue

		var guard = GuardEnemyClass.new()
		enemies_root.add_child(guard)
		guard.setup(
			floor_layer,
			VISUAL_GRID_OFFSET,
			String(entry.get("id", "guard_%d" % (i + 1))),
			route,
			int(entry.get("start_index", 0))
		)
		
		guard.whistled.connect(_on_guard_whistled)
		guard.radioed.connect(_on_guard_radioed)
		
		_guards.append(guard)

	_update_enemy_visibility()


func _build_navigation_blocked_cells() -> Array[Vector2i]:
	var nav: Array[Vector2i] = _get_blocked_cells_array()
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.cell == agent.cell:
			continue
		nav.append(guard.cell)
	return nav


func _is_guard_cell(cell: Vector2i) -> bool:
	for guard in _guards:
		if is_instance_valid(guard) and guard.cell == cell:
			return true
	return false


func _on_guard_whistled(origin_cell: Vector2i, last_known: Vector2i) -> void:
	## Apito: guards a até WHISTLE_RADIUS tiles entram em STATE_SEARCH
	if last_known == INVALID_CELL:
		return
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var dist: float = float((guard.cell - origin_cell).length())
		if dist <= WHISTLE_RADIUS:
			guard.receive_alert(last_known, GuardEnemy.STATE_SEARCH)


func _on_guard_radioed(_origin_cell: Vector2i, last_known: Vector2i) -> void:
	## Rádio: todos os guards da sala entram em STATE_ALERT
	if last_known == INVALID_CELL:
		return
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.state == GuardEnemy.STATE_PATROL or \
		   guard.state == GuardEnemy.STATE_SUSPICIOUS:
			guard.receive_alert(last_known, GuardEnemy.STATE_ALERT)


func _on_guard_alarmed(_origin_cell: Vector2i) -> void:
	## Alarme global: todos os guards entram em STATE_CHASE
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.state != GuardEnemy.STATE_CHASE:
			guard.receive_alert(agent.cell, GuardEnemy.STATE_CHASE)
	_alert_meter = _alert_max
	_update_alert_label()


func _update_enemy_visibility() -> void:
	# Update enemy alpha/saturation each frame while moving.
	# Visibility is driven by the player's vision radius + ability bonuses.
	# At vision distance the guard starts to desaturate, then fades out one tile later.
	if dev_vision:
		for guard in _guards:
			if not is_instance_valid(guard):
				continue
			guard.modulate = Color.WHITE
		queue_redraw()
		return

	var enemy_vision := float(agent.get_vision_radius() + vision_bonus_tiles)
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var d: float = (guard.cell - agent.cell).length()
		var tile_distance: int = int(floor(d + 0.5))
		if tile_distance <= int(enemy_vision) - 1:
			guard.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif tile_distance == int(enemy_vision):
			guard.modulate = Color(0.85, 0.85, 0.85, 1.0)
		elif tile_distance == int(enemy_vision) + 1:
			guard.modulate = Color(0.65, 0.65, 0.65, 0.5)
		else:
			guard.modulate = Color(1.0, 1.0, 1.0, 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_exit_markers()
	_draw_spawn_marker()
	_draw_shadow_debug()

	## Draw enemy last_known markers
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.last_known_agent_cell == INVALID_CELL:
			continue
		if guard.state == guard.STATE_PATROL:
			continue
		var world := _world_center_for_cell(guard.last_known_agent_cell)
		draw_circle(world, 18.0, Color(1.0, 0.72, 0.18, 0.24))
		draw_circle(world, 18.0, Color(1.0, 0.9, 0.2, 0.82), 3.0)
		draw_line(world + Vector2(-8.0, 0.0), world + Vector2(8.0, 0.0), Color(1.0, 1.0, 1.0, 0.92), 2.5)
		draw_line(world + Vector2(0.0, -8.0), world + Vector2(0.0, 8.0), Color(1.0, 1.0, 1.0, 0.92), 2.5)


func _update_selected_preview() -> void:
	if _selected_cell == INVALID_CELL or _selected_cell == agent.cell:
		path_preview.clear_path()
		return

	if not movement_overlay.is_reachable(_selected_cell):
		path_preview.clear_path()
		return

	var path: Array[Vector2i] = movement_overlay.build_path_to(_selected_cell)
	if path.size() < 2:
		path_preview.clear_path()
		return

	path_preview.set_path(path, movement_overlay.get_ap_cost(_selected_cell))


func _update_movement_highlight() -> void:
	if turn_manager.is_enemy_phase or agent.is_moving:
		return

	var hovered_ap: int = movement_overlay.get_ap_cost(_hovered_cell)
	if hovered_ap > 0:
		movement_overlay.set_highlight_ap(hovered_ap)
	else:
		# If hovering origin or unreachable, default to 1 AP zone
		# (which is usually visible at the start of the turn)
		movement_overlay.set_highlight_ap(1)


func _is_selectable_cell(cell: Vector2i) -> bool:
	if cell == INVALID_CELL or _blocked_cells.has(cell) or _is_guard_cell(cell):
		return false
	return floor_layer.get_cell_source_id(cell) != -1


func _set_selected_cell(cell: Vector2i) -> void:
	if not _is_selectable_cell(cell):
		return
	_selected_cell = cell
	selection_overlay.set_selected(cell)
	_update_selected_preview()
	
	## Dev 03: update hover label manually on selection change if needed
	if dev_vision:
		_hovered_cell = cell
		_update_dev_hover_label()


func _handle_tile_click(cell: Vector2i) -> void:
	if turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	if not _is_selectable_cell(cell):
		path_preview.clear_path()
		return

	if _selected_cell != cell:
		_set_selected_cell(cell)
		return

	if cell != agent.cell and _try_move_to(cell):
		return

	_update_selected_preview()


func _try_move_to(cell: Vector2i) -> bool:
	if _actor_end_pause_active:
		return false
	if turn_manager.is_enemy_phase:
		return false
	if agent.is_moving or cell == INVALID_CELL or cell == agent.cell:
		return false
	if not movement_overlay.is_reachable(cell):
		return false

	var path_cost: int = movement_overlay.get_cost(cell)
	## Build path before spending AP — spend triggers ap_changed → rebuild → clears _costs.
	var path: Array[Vector2i] = movement_overlay.build_path_to(cell)
	if path.size() < 2:
		return false
	if not turn_manager.spend_for_path_cost(path_cost):
		return false

	_selected_cell = cell
	_pending_auto_end_turn = chk_auto_end_turn.button_pressed and int(turn_manager.current_ap) <= 0
	agent.move_along_path(path)
	return true


## Build a name → source_id dictionary from TileSet custom data.
func _build_registry(ts: TileSet) -> void:
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var td := src.get_tile_data(Vector2i(0, 0), 0)
		if td:
			_tile_ids[td.get_custom_data("tile_name")] = sid
	print("[Room] %d tiles registered." % _tile_ids.size())


## Place a named tile at cell. Silent no-op for unknown names.
func _place(cell: Vector2i, tile_name: String, layer: TileMapLayer = floor_layer) -> void:
	var sid: int = _tile_ids.get(tile_name, -1)
	if sid != -1:
		layer.set_cell(cell, sid, Vector2i(0, 0))


func _build_room(layout: Dictionary) -> void:
	floor_layer.clear()
	structure_wall_layer.clear()
	structure_wall_upper_layer.clear()
	structure_layer.clear()

	var floor_tile_name := String(layout.get("floor_tile_name", "floor_SE"))
	## Preenche exatamente o grid MAP_SIZE. O buffer de 5 tiles no layout builder
	## substitui a antiga extensão negativa — sem coordenadas fora do range [0, MAP_SIZE).
	for x in range(0, _room_size.x):
		for y in range(0, _room_size.y):
			_place(Vector2i(x, y), floor_tile_name)

	for structure_entry in layout.get("wall_tiles", []):
		var wall_cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var wall_tile_name := String(structure_entry.get("tile_name", ""))
		_place(wall_cell, wall_tile_name, structure_wall_layer)

	## Place upper-layer wall tiles for double-height walls
	for structure_entry in layout.get("wall_tiles_upper", []):
		var wall_cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var wall_tile_name := String(structure_entry.get("tile_name", ""))
		_place(wall_cell, wall_tile_name, structure_wall_upper_layer)

	for structure_entry in layout.get("structure_tiles", []):
		var cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var tile_name := String(structure_entry.get("tile_name", ""))
		_place(cell, tile_name, structure_layer)

	_cache_blocked_cells(layout)


func _cache_blocked_cells(layout: Dictionary) -> void:
	_blocked_cells.clear()
	for cell in layout.get("blocked_cells", []):
		_blocked_cells[cell] = true
	## Saídas do segmento — usadas pelo overlay roxo em _draw()
	_exit_cells.clear()
	for raw in layout.get("exit_cells", []):
		_exit_cells.append(Vector2i(raw))
	print("[Room] Cache: %d blocked_cells, %d exit_cells" % [_blocked_cells.size(), _exit_cells.size()])
	print("[Room] Border check: (0,0)=%s (17,0)=%s (0,35)=%s (17,35)=%s (9,0)=%s (9,35)=%s" % [
		_blocked_cells.has(Vector2i(0,0)), _blocked_cells.has(Vector2i(17,0)),
		_blocked_cells.has(Vector2i(0,35)), _blocked_cells.has(Vector2i(17,35)),
		_blocked_cells.has(Vector2i(9,0)), _blocked_cells.has(Vector2i(9,35))
	])
	_setup_light_sources(layout)
	_populate_obstacle_heights()
	_compute_shadow_tiles()
	_bake_shadow_tiles()


## M2-13: Direções isométricas quantizadas (8 direções)
const SHADOW_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const SHADOW_LENGTH_MAX := 5


## M2-13: Setup light sources from layout or defaults
func _setup_light_sources(layout: Dictionary) -> void:
	_light_sources.clear()
	
	var lights: Array = layout.get("light_sources", [])
	if lights.is_empty():
		lights = _default_light_sources()
	
	for entry in lights:
		_light_sources.append(LightSource.new(
			Vector2i(entry.get("x", 0), entry.get("y", 0)),
			float(entry.get("height", 4.5)),
			int(entry.get("radius", 7)),
			float(entry.get("intensity", 0.9)),
		))


## M2-13: Default light sources for playtest mockup (3 ceiling lamps)
func _default_light_sources() -> Array:
	return [
		{"x": 9, "y": 4, "height": 5.0, "radius": 8, "intensity": 0.9},
		{"x": 9, "y": 18, "height": 5.0, "radius": 7, "intensity": 0.85},
		{"x": 9, "y": 30, "height": 5.0, "radius": 7, "intensity": 0.85},
	]


## M2-13: Populate obstacle heights from tile types
func _populate_obstacle_heights() -> void:
	_obstacle_heights.clear()
	for blocked_cell in _blocked_cells.keys():
		var tile_name := _get_tile_name_at(blocked_cell)
		var height := OBSTACLE_HEIGHT_DEFAULT
		for key in OBSTACLE_HEIGHTS.keys():
			if tile_name.begins_with(key):
				height = OBSTACLE_HEIGHTS[key]
				break
		_obstacle_heights[blocked_cell] = height


## M2-13: Get tile name at cell (from structure layers)
func _get_tile_name_at(cell: Vector2i) -> String:
	for layer in [structure_layer, structure_wall_layer]:
		var sid: int = layer.get_cell_source_id(cell)
		if sid >= 0:
			var src = layer.tile_set.get_source(sid)
			if src:
				return str(src.resource_name)
	return ""


## M2-13: Compute shadow tiles with directional casting from light sources
func _compute_shadow_tiles() -> void:
	_shadow_tiles.clear()
	
	if _light_sources.is_empty():
		_compute_shadow_tiles_fallback()
		return
	
	for light in _light_sources:
		if not light.active:
			continue
		_cast_shadows_from_light(light)


## M2-13: Cast shadows from a single light source
func _cast_shadows_from_light(light: LightSource) -> void:
	for blocked_cell in _blocked_cells.keys():
		var dist_vec: Vector2i = blocked_cell - light.cell
		var dist: float = dist_vec.length()
		if dist > light.radius or dist < 0.1:
			continue
		
		## Obstacle height from dictionary
		var obs_height: float = _obstacle_heights.get(blocked_cell, OBSTACLE_HEIGHT_DEFAULT) as float
		if obs_height >= light.height:
			obs_height = light.height - 0.1
		
		## Shadow length by cone projection geometry
		var shadow_len: float = obs_height * (light.height - obs_height) / maxf(dist, 0.1)
		shadow_len = minf(shadow_len * light.intensity, float(SHADOW_LENGTH_MAX))
		
		## Quantize direction to 8 directions
		var dir: Vector2i = _quantize_dir(dist_vec)
		
		## Project shadow along quantized direction
		for i in range(1, int(ceil(shadow_len)) + 1):
			var shadow_cell: Vector2i = blocked_cell + dir * i
			if not _is_cell_inside_room(shadow_cell):
				break
			if _blocked_cells.has(shadow_cell):
				break
			
			## Linear falloff: SHADOW_MULT_DIRECT → 1.0
			var t: float = float(i) / shadow_len
			var mult: float = lerpf(SHADOW_MULT, 1.0, clampf(t, 0.0, 1.0))
			
			## Darker shadow prevails (min)
			if _shadow_tiles.has(shadow_cell):
				_shadow_tiles[shadow_cell] = minf(_shadow_tiles[shadow_cell], mult)
			else:
				_shadow_tiles[shadow_cell] = mult


## M2-13: Quantize direction to nearest 8-direction
func _quantize_dir(v: Vector2i) -> Vector2i:
	var angle := atan2(float(v.y), float(v.x))
	var idx := int(round(angle / (PI / 4.0))) % 8
	return SHADOW_DIRS[((idx % 8) + 8) % 8]


## M2-13: Fallback shadow computation (omnidirectional, no light sources)
func _compute_shadow_tiles_fallback() -> void:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for blocked_cell in _blocked_cells.keys():
		for dir in dirs:
			var candidate: Vector2i = blocked_cell + dir
			if not _is_cell_inside_room(candidate) or _blocked_cells.has(candidate):
				continue
			if _shadow_tiles.has(candidate):
				_shadow_tiles[candidate] = minf(_shadow_tiles[candidate], SHADOW_MULT)
			else:
				_shadow_tiles[candidate] = SHADOW_MULT
			var penumbra: Vector2i = candidate + dir
			if _is_cell_inside_room(penumbra) and not _blocked_cells.has(penumbra):
				if not _shadow_tiles.has(penumbra):
					_shadow_tiles[penumbra] = PENUMBRA_MULT


## M2-13: Bake shadow tiles onto ShadowFullLayer and ShadowPartialLayer
func _bake_shadow_tiles() -> void:
	if _tile_shadow == null:
		return
	
	_tile_shadow.clear_priority(TileOverlayClass.PRIO_SHADOW)
	
	for shadow_cell: Vector2i in _shadow_tiles.keys():
		var mult: float = _shadow_tiles[shadow_cell]
		var shadow_color := TileOverlayClass.shadow_color_for(mult)
		_tile_shadow.paint(shadow_cell, shadow_color, TileOverlayClass.PRIO_SHADOW)



func _get_blocked_cells_array() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		cells.append(cell)
	return cells


func _is_cell_inside_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _room_size.x and cell.y < _room_size.y


func _layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	var mapped := layout.duplicate(true)
	var base_size: Vector2i = layout.get("size", Vector2i.ZERO)
	var rotated_size: Vector2i = _rotated_size(base_size, direction)
	mapped["size"] = rotated_size
	mapped["agent_start_cell"] = _cell_from_base(layout.get("agent_start_cell", Vector2i.ZERO), direction, base_size)
	mapped["floor_tile_name"] = _remap_tile_name_for_perspective(
		String(layout.get("floor_tile_name", "floor_SE")), direction)

	for key in ["wall_tiles", "wall_tiles_upper", "structure_tiles"]:
		var src: Array = layout.get(key, [])
		var dst: Array = []
		for entry in src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = _cell_from_base(out.get("cell", INVALID_CELL), direction, base_size)
			out["tile_name"] = _remap_tile_name_for_perspective(String(out.get("tile_name", "")), direction)
			dst.append(out)
		mapped[key] = dst

	var blocked_cells: Array[Vector2i] = []
	for cell in layout.get("blocked_cells", []):
		blocked_cells.append(_cell_from_base(cell, direction, base_size))
	mapped["blocked_cells"] = blocked_cells

	var blocked_edges: Array[Dictionary] = []
	for edge in layout.get("blocked_edges", []):
		blocked_edges.append({
			"from": _cell_from_base(edge.get("from", Vector2i.ZERO), direction, base_size),
			"to": _cell_from_base(edge.get("to", Vector2i.ZERO), direction, base_size),
		})
	mapped["blocked_edges"] = blocked_edges

	var enemy_defs: Array[Dictionary] = []
	for enemy in layout.get("enemy_defs", []):
		var out := (enemy as Dictionary).duplicate(true)
		var route: Array[Vector2i] = []
		for cell in enemy.get("route", []):
			route.append(_cell_from_base(cell, direction, base_size))
		out["route"] = route
		enemy_defs.append(out)
	mapped["enemy_defs"] = enemy_defs
	return mapped


func _rotated_size(base_size: Vector2i, direction: String) -> Vector2i:
	if direction == "E" or direction == "W":
		return Vector2i(base_size.y, base_size.x)
	return base_size


func _cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	if base_cell == INVALID_CELL:
		return INVALID_CELL
	var size := base_size
	if size == Vector2i.ZERO:
		size = _base_layout.get("size", Vector2i.ZERO)
	var w := size.x
	var h := size.y
	match direction:
		"E":
			return Vector2i(h - 1 - base_cell.y, base_cell.x)
		"S":
			return Vector2i(w - 1 - base_cell.x, h - 1 - base_cell.y)
		"W":
			return Vector2i(base_cell.y, w - 1 - base_cell.x)
		_:
			return base_cell


func _cell_to_base(view_cell: Vector2i, direction: String, base_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	if view_cell == INVALID_CELL:
		return INVALID_CELL
	var size := base_size
	if size == Vector2i.ZERO:
		size = _base_layout.get("size", Vector2i.ZERO)
	var w := size.x
	var h := size.y
	match direction:
		"E":
			return Vector2i(view_cell.y, h - 1 - view_cell.x)
		"S":
			return Vector2i(w - 1 - view_cell.x, h - 1 - view_cell.y)
		"W":
			return Vector2i(w - 1 - view_cell.y, view_cell.x)
		_:
			return view_cell


func _remap_tile_name_for_perspective(tile_name: String, direction: String) -> String:
	if tile_name.is_empty():
		return tile_name
	var i := tile_name.rfind("_")
	if i < 0:
		return tile_name
	var base := tile_name.substr(0, i)
	var suffix := tile_name.substr(i + 1)
	if not _PERSPECTIVE_SUFFIX_MAP.has(direction):
		return tile_name
	var suffix_map: Dictionary = _PERSPECTIVE_SUFFIX_MAP[direction]
	if not suffix_map.has(suffix):
		return tile_name
	return "%s_%s" % [base, String(suffix_map[suffix])]


## Convert a screen-space press position to the tile cell underneath it.
## local_to_map uses the TOP VERTEX as anchor, so it only gives the correct
## cell when clicking the top quadrant. The 3×3 search over visual CENTERs
## (map_to_local + Vector2(0,64)) finds the diamond that truly contains the
## click — this corrects the other three quadrants.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var lp: Vector2 = floor_layer.to_local(ct.affine_inverse() * screen_pos)
	var logical_lp := lp - VISUAL_GRID_OFFSET
	var tile_seed: Vector2i = floor_layer.local_to_map(logical_lp)
	var best := tile_seed
	var best_dist := INF
	var found_inside := false
	for dc: int in [-1, 0, 1]:
		for dr: int in [-1, 0, 1]:
			var c := tile_seed + Vector2i(dc, dr)
			var center := floor_layer.map_to_local(c) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
			var d := lp - center
			var dist := absf(d.x) / 128.0 + absf(d.y) / 64.0
			if dist <= 1.0 and dist < best_dist:
				best_dist = dist
				best = c
				found_inside = true
	if found_inside:
		return best
	return INVALID_CELL


## Apply zoom clamped between ZOOM_MIN and ZOOM_MAX.
func _apply_zoom(new_z: float) -> void:
	camera.zoom = Vector2(new_z, new_z)


func _process(_delta: float) -> void:
	_update_vision_fog()
	if _has_moving_guards():
		_update_enemy_visibility()


func _has_moving_guards() -> bool:
	for guard in _guards:
		if is_instance_valid(guard) and guard.is_moving:
			return true
	return false


## Update the distance-fog shader uniforms every frame so the gradient tracks
## the agent's screen position and scales correctly with zoom and viewport size.
func _update_vision_fog() -> void:
	var mat := _fog_rect.material as ShaderMaterial
	if mat == null:
		return
	## Use global_position so the gradient tracks the visual agent during step animation.
	var agent_world := agent.global_position
	var canvas_t    := get_viewport().get_canvas_transform()
	var vp_size     := get_viewport().get_visible_rect().size
	var screen_px   := canvas_t * agent_world
	var screen_uv   := screen_px / vp_size
	var zoom        := camera.zoom.x
	## Gradient: tight clear center (3 tiles), outer boundary pushes 9 tiles
	## beyond the FOW reveal for a very long, gradual fade into darkness.
	var vision_r_px := float(VISION_TILE_RADIUS + vision_bonus_tiles) * WORLD_TILE_PX * zoom
	var outer_uv    := (vision_r_px + 9.0 * WORLD_TILE_PX * zoom) / vp_size.y
	var inner_uv    := maxf(0.0, vision_r_px - 3.0 * WORLD_TILE_PX * zoom) / vp_size.y
	mat.set_shader_parameter("agent_screen_uv", screen_uv)
	mat.set_shader_parameter("fog_inner_uv",    inner_uv)
	mat.set_shader_parameter("fog_outer_uv",    outer_uv)


## Return a camera position constrained to the vision leash around the agent.
## Inside the soft zone the camera decelerates (quadratic ease-out);
## beyond the hard limit it is clamped to the boundary.
## In DEV_VISION mode, no constraints are applied.
func _get_leashed_pos(proposed: Vector2) -> Vector2:
	## DEV_VISION: liberar todas as travas
	if dev_vision:
		return proposed
	
	var hard_radius := float(CAMERA_MAX_BORDER_TILES) * WORLD_TILE_PX
	var soft_radius := hard_radius - float(CAMERA_SOFT_ZONE_TILES) * WORLD_TILE_PX
	var agent_world := floor_layer.map_to_local(agent.cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	var offset      := proposed - agent_world
	var dist        := offset.length()
	if dist <= soft_radius:
		return proposed
	if dist >= hard_radius:
		return agent_world + offset.normalized() * hard_radius
	## Soft zone: quadratic ease-out — slows as camera approaches the hard limit.
	var t      := (dist - soft_radius) / (hard_radius - soft_radius)   ## 0..1
	var damped := soft_radius + (hard_radius - soft_radius) * t * (2.0 - t)
	return agent_world + offset.normalized() * damped


## Unified input: wheel zoom · pinch zoom · motion drag.
## Left mouse button (press/release) lives in _unhandled_input so GUI
## controls (Buttons) can consume their clicks before game logic runs.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_Z:
					## Z abaixa: STANDING -> CROUCHING -> PRONE
					var next_z := agent.posture
					if agent.posture == DebugAgent.Posture.STANDING:
						next_z = DebugAgent.Posture.CROUCHING
					elif agent.posture == DebugAgent.Posture.CROUCHING:
						next_z = DebugAgent.Posture.PRONE
					
					if next_z != agent.posture:
						_try_change_posture(next_z)
					return
				KEY_X:
					## X sobe: PRONE -> CROUCHING -> STANDING
					var next_x := agent.posture
					if agent.posture == DebugAgent.Posture.PRONE:
						next_x = DebugAgent.Posture.CROUCHING
					elif agent.posture == DebugAgent.Posture.CROUCHING:
						next_x = DebugAgent.Posture.STANDING
					
					if next_x != agent.posture:
						_try_change_posture(next_x)
					return
				KEY_V:
					_toggle_dev_vision()
					return
				KEY_P:
					_peek_pending = true
					return
				KEY_UP:
					if _peek_pending: 
						_try_peek(Vector2i.UP)
						_peek_pending = false
						return
				KEY_DOWN:
					if _peek_pending: 
						_try_peek(Vector2i.DOWN)
						_peek_pending = false
						return
				KEY_LEFT:
					if _peek_pending: 
						_try_peek(Vector2i.LEFT)
						_peek_pending = false
						return
				KEY_RIGHT:
					if _peek_pending: 
						_try_peek(Vector2i.RIGHT)
						_peek_pending = false
						return

	## ── Touch: track fingers for pinch-zoom ─────────────────────────────
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			_pinch_last_dist = 0.0
		if _touches.size() >= 2:
			_left_down = false
			_drag_started = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var keys := _touches.keys()
			var dist := (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
			if _pinch_last_dist > 0.0:
				var delta := (dist - _pinch_last_dist) * 0.001
				_apply_zoom(clampf(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX))
			_pinch_last_dist = dist
			get_viewport().set_input_as_handled()
		return

	## ── Mouse wheel zoom ─────────────────────────────────────────────────
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(clampf(camera.zoom.x + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX))
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(clampf(camera.zoom.x - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX))
			get_viewport().set_input_as_handled()
		return

	## ── Mouse motion: preview path on hover ─────────────────────────────
	if event is InputEventMouseMotion and not (_left_down and _touches.size() < 2):
		var mm := event as InputEventMouseMotion
		var new_hover := _screen_to_tile(mm.position)
		if new_hover != _hovered_cell:
			_hovered_cell = new_hover
			if dev_vision:
				_update_dev_hover_label()
			_update_movement_highlight()
			
			## UI-01: Update selection and path preview on hover
			if _is_selectable_cell(_hovered_cell):
				_selected_cell = _hovered_cell
				selection_overlay.set_selected(_hovered_cell)
				_update_selected_preview()
			elif _hovered_cell == agent.cell or not movement_overlay.is_reachable(_hovered_cell):
				## Hide preview if hovering agent or unreachable zone
				_selected_cell = agent.cell
				selection_overlay.set_selected(agent.cell)
				path_preview.clear_path()

	## ── Mouse motion: pan when dragging ─────────────────────────────────
	if event is InputEventMouseMotion and _left_down and _touches.size() < 2:
		var mm := event as InputEventMouseMotion
		var moved_sq := (mm.position - _drag_start_mouse).length_squared()
		if not _drag_started and moved_sq > DRAG_THRESHOLD_SQ:
			_drag_started = true
		if _drag_started:
			var delta := (mm.position - _drag_start_mouse) / camera.zoom.x
			camera.global_position = _get_leashed_pos(_drag_start_cam - delta)
			get_viewport().set_input_as_handled()
		return


## Left mouse: only runs when no GUI Control consumed the event first.
## This lets HUD buttons work while still handling pan + tile selection.
func _unhandled_input(event: InputEvent) -> void:
	if turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton

	## ── Botão direito: executar movimento para o tile selecionado ──────
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if _selected_cell != INVALID_CELL and _selected_cell != agent.cell:
			_try_move_to(_selected_cell)
		get_viewport().set_input_as_handled()
		return

	## ── Botão esquerdo: pan (comportamento existente intacto) ──────────
	if mb.button_index != MOUSE_BUTTON_LEFT or _touches.size() >= 2:
		return

	if mb.pressed:
		_left_down = true
		_drag_started = false
		_drag_start_mouse = mb.position
		_drag_start_cam = camera.global_position
	else:
		if not _drag_started:
			var cell := _screen_to_tile(mb.position)
			
			## UI-02: Se clicar fora da zona, apenas selecionar (sem mover)
			if cell != INVALID_CELL:
				_set_selected_cell(cell)
				
		_left_down = false
