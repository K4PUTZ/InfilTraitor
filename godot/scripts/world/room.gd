extends Node2D
## Tactical room controller: input, UI wiring, agent turns and scene setup.

const MapCatalogClass    = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass   = preload("res://godot/scripts/world/maps/map_compiler.gd")
const SubcubeGeometryClass = preload("res://godot/scripts/world/maps/subcube_geometry.gd")
const SubcubeCoordsClass = preload("res://godot/scripts/world/subcube_coords.gd")
const LevelGraphClass    = preload("res://godot/scripts/world/level_graph.gd")
const WallContainerClass = preload("res://godot/scripts/world/wall_container.gd")
const GuardEnemyClass    = preload("res://godot/scripts/agents/guard_enemy.gd")
const GuardNoiseIndicatorClass = preload("res://godot/scripts/overlays/guard_noise_indicator.gd")
const CeilingPropOverlayClass = preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")
const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")
const ShadowBoundaryOverlayClass = preload("res://godot/scripts/overlays/shadow_boundary_overlay.gd")
const LightRayOverlayClass = preload("res://godot/scripts/overlays/light_ray_overlay.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const VisionControllerClass = preload("res://godot/scripts/controllers/vision_controller.gd")
const HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
const LightingControllerClass = preload("res://godot/scripts/controllers/lighting_controller.gd")
const CameraControllerClass = preload("res://godot/scripts/controllers/camera_controller.gd")
const FowControllerClass = preload("res://godot/scripts/controllers/fow_controller.gd")
const GuardCoordinatorClass = preload("res://godot/scripts/controllers/guard_coordinator.gd")
const VoxelRegistryClass = preload("res://godot/scripts/world/voxel_registry.gd")
const VoxelRefClass = preload("res://godot/scripts/world/voxel_ref.gd")
const WallSliceClass = preload("res://godot/scripts/world/wall_slice.gd")
const HighWallClass = preload("res://godot/scripts/world/high_wall.gd")

## SLICE-02: Geometry module (Edge → Slice → Voxel pipeline)
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
const SliceGeneratorClass = preload("res://godot/scripts/geometry/slice_generator.gd")
const JunctionResolverClass = preload("res://godot/scripts/geometry/junction_resolver.gd")
const EdgeRegistryClass = preload("res://godot/scripts/geometry/edge_registry.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var turn_manager:        TacticalTurnManager = $TurnManager
@onready var enemy_phase_controller: EnemyPhaseController = $EnemyPhaseController
@onready var enemies_root:         Node2D       = $Enemies
@onready var movement_overlay:    MovementOverlay = $MovementOverlay
@onready var path_preview:        PathPreview  = $PathPreview
@onready var structure_wall_layer:       TileMapLayer = $StructureWallLayer
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
@onready var toolbar_row:         HBoxContainer = $HUD/TopBar/Row
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
@onready var lbl_end_turn:        Label           = $HUD/TopBar/Row/BtnEndTurn/Content/LblEndTurn
@onready var lbl_enemy_turn:      Label           = $HUD/EnemyTurnBanner/LblEnemyTurn
@onready var fog_of_war:          Node2D          = $FogOfWarOverlay
@onready var _fog_rect:           ColorRect       = $VisionFogOverlay/FogRect

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const INVALID_CELL := Vector2i(-9999, -9999)

## The TileMap renders the current 512px-tall source tiles lower than the
## logical grid used by map_to_local/local_to_map. Compensate with one fixed
## visual offset so camera, labels, selection and picking all agree.
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)

## Wall storeys (N-floor stacking). Ground course is StructureWallLayer at WALL_BASE_Z_INDEX;
## each higher course is a runtime TileMapLayer offset up by WALL_FLOOR_STEP_PX and drawn one
## z above the previous so its top occludes sprites. WALL_FLOOR_STEP_PX is the per-storey cube
## height in px — calibrated visually (one block tall). Reserve z=100 band for a future overhead
## ceiling/light layer (below noise at z=140).
const WALL_BASE_Z_INDEX := 10
## One storey = the cube's side-face height. Measured from the art: opaque block height 286 −
## top-diamond 128 = 158 px (block_SE and wall_NE — sistema vértice-alinhado).
## Upper courses stack on this step so a cube seats exactly on the one below. Tunable.
const WALL_FLOOR_STEP_PX := 158.0
var _wall_tileset: TileSet = null
var _wall_upper_layers: Array[TileMapLayer] = []

## Subcube render plane (phase SUB-01): 1 storey = 4 subcube rows, each row steps by 39.5 px.
## This stack is separate from the gameplay plane and uses the subcube tiles registered in the
## shared tileset.
const SUBCUBE_STEP_PX: float = 40.0

## Ponto de origem base para todos os tiles de subcubo no tileset (inalterado).
const SUBCUBE_BASE_ORIGIN := Vector2i(0, -40)

## Straddle offset por face de parede. Keys seguem o sistema vértice-alinhado
## (N=topo do diamante). Ver DIRECTION_GLOSSARY.md §5.
## NW = cima-esquerda | NE = cima-direita | SE = baixo-direita | SW = baixo-esquerda
const SUBCUBE_FACE_OFFSETS: Dictionary = {
	"NW": Vector2i(-16,  8),   ## cima-esquerda: edge_delta (-1, 0)
	"NE": Vector2i(-16, -8),   ## cima-direita:  edge_delta ( 0,-1)
	"SE": Vector2i( 16, -8),   ## baixo-direita: edge_delta (+1, 0)
	"SW": Vector2i( 16,  8),   ## baixo-esquerda: edge_delta (0,+1)
}

## Voxel render plane (VOXEL series): 1 storey = 8 voxel rows, each steps 20 px.
## 20 = 1.25 × VOXEL_TILE_SIZE.y (16). Must match generate_voxel.py SIDE_H.
## Invariant: 8 × VOXEL_STEP_PX (160) == 4 × SUBCUBE_STEP_PX (160). ✓
const VOXEL_STEP_PX: float = 20.0

var _subcube_tileset: TileSet = null
var _subcube_layers: Array[TileMapLayer] = []
var _subcube_tile_ids: Dictionary = {}

## Voxel render plane (VOXEL-02). TileSet separado (tile_size 32×16), sem offsets empíricos.
var _voxel_tileset: TileSet = null
var _voxel_layers: Array[TileMapLayer] = []
var _voxel_tile_ids: Dictionary = {}
## Slices de parede voxel actuais (VOXEL-04). Indexados pelo VoxelRegistry em VOXEL-06.
var _voxel_wall_slices: Array = []
## VoxelRefs de corner extra (VOXEL-05). Um por nível por corner de V-junction descoberto.
var _voxel_junction_extras: Array = []
## VoxelRegistry — centralized index of all WallSlice/HighWall instances (VOXEL-06).
var _voxel_registry: RefCounted = null

## SLICE-02: New geometry module state
var _edge_registry: EdgeRegistry = null       ## EdgeRegistry of all edges and slices
var _junction_columns: Array = []             ## Array of JunctionResolver.JunctionColumn
var _voxel_renderer: VoxelRenderer = null     ## Voxel rendering engine

## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
## para faces de parede; blocos sólidos ainda usam TileMapLayer.
var _wall_containers: Array = []

## Prop stacking (e.g. stacked crates). Each extra sprite seats on the one below,
## offset up by the crate body step. Must equal the crate sprite's CUBE_HEIGHT
## (tools/asset_generation/generate_*_crate.py) so stacked crates seat seamlessly.
var CRATE_STACK_STEP_PX: float = 128.0
var _prop_stack_layers: Array[TileMapLayer] = []

## tile_name → TileSet source_id
var _tile_ids: Dictionary = {}
var _room_size: Vector2i = Vector2i.ZERO
var _map_buffer: int = 0   ## Buffer offset from MapCompiler (SLICE-00)
var _blocked_cells: Dictionary = {}
var _prop_heights: Dictionary = {}  ## rotated cell → prop shadow height class (1-4)
var _base_layout: Dictionary = {}
var _current_blocked_edges: Array[Dictionary] = []
var _guards: Array = []

var _shadow_tiles: Dictionary = {}     ## Vector2i → float (multiplicador)
var _exit_cells: Array[Vector2i] = []  ## Segment exit tiles (doorOpen_*)
var _current_light_sources: Array = []  ## Active (rotated) map lights for LightingController
var _ceiling_overlay: Node2D = null  ## VIS-01: overhead ceiling props/lights (CeilingPropOverlay)
const SHADOW_MULT   := GuardEnemy.SHADOW_MULT
const PENUMBRA_MULT := GuardEnemy.PENUMBRA_MULT

## M2-13: Obstacle heights (in tiles above the floor plane)
const OBSTACLE_HEIGHTS: Dictionary = {
	"crate":     1.0,
	"wall":      2.0,
	"block":     2.0,
	"column":    3.0,
	"half_wall": 1.0,
}
const OBSTACLE_HEIGHT_DEFAULT := 1.5

## Vision & FOW radii — independent of each other:
## VISION_TILE_RADIUS  controls only the shader gradient (live clear-circle around agent).
## FOW_REVEAL_RADIUS   controls how many tiles get permanently revealed each move.
const VISION_TILE_RADIUS := 5      ## shader gradient radius (tiles)
const FOW_REVEAL_RADIUS  := 9      ## FOW reveal radius (tiles)
const WORLD_TILE_PX      := 128.0  ## horizontal px per isometric tile step (used by vision fog shader)

## Viewport toggle state
var _is_desktop_viewport: bool = false
var _pending_auto_end_turn: bool = false
var _selected_cell: Vector2i = INVALID_CELL
var _active_perspective: String = "N"
var _alert_meter: int = 0

var _alert_max: int = 100
var _alert_gain_full: int = 45

## ID-01: Detection meter thresholds for state transitions
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


## M2-10: Peek mechanic state
var _peek_active: bool = false
var _peek_timer: int   = 0
var _peek_pending: bool = false

## Dev 03: tile hover info
var _dev_hover_label: Label = null
var _hovered_cell: Vector2i = Vector2i(-1, -1)

## DEBUG-01: Map loader panel
var _map_loader_panel: Node = null

## Dev 04: agent trail overlay
const TRAIL_MAX := 5
var _agent_trail: Array[Vector2i] = []
var _tile_shadow: Node2D = null  ## TileOverlay for shadows (z=1, multiply)
var _light_ray_overlay: Node2D = null  ## LightRayOverlay — golden shafts from lamps (z=0, additive)
var _shadow_boundary_overlay: Node2D = null  ## ShadowBoundaryOverlay — edges of playable shadows (z=4)
var _tile_game: Node2D = null   ## TileOverlay for visual gameplay (z=3, mix)
var _trail_overlay: Node2D = null

## M2-04: noise system and overlay
var _noise_system = null
var _noise_overlay: Node2D = null

## M2-14: Guard noise indicator — flutuante ao redor do agente
var _guard_noise_indicator: Node2D = null

## MODULARIZE-01: VisionController to manage debug/analysis overlays
var _vision_controller: Node2D = null

## MODULARIZE-02: HudController to manage UI wiring
var _hud_controller: Node = null

## MODULARIZE-04: CameraController to manage drag, zoom, perspective
var _camera_controller: Node = null

## MODULARIZE-03: LightingController to manage lighting systems
var _lighting_controller: Node = null

## MODULARIZE-05: FowController to manage reveal and shader parameters
var _fow_controller: Node = null

## MODULARIZE-06: GuardCoordinator to route coordination signals between guards
var _guard_coordinator: Node = null

## M2-14: Noise chance per guard state
const GUARD_NOISE_CHANCE_BY_STATE := {
	"patrol": 0.15,
	"suspicious": 0.40,
	"alert": 0.60,
	"chase": 0.70,
	"search": 0.50,
}

## M2-14: Noise intensity per guard state
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
## Which map MapCatalog resolves for this room: "PLAYGROUND", "SIGMA_01", "PROCEDURAL".
@export var map_id: String = "PLAYGROUND"
## Quick-test override for wall storeys (0 = use the map's own wall_height). Inspector-tweakable.
@export var wall_height_override: int = 0
## SLICE-00: Enable voxel alignment probe to measure and report world-space deltas.
@export var debug_probe_voxel_alignment: bool = false

const WHISTLE_RADIUS := 3


## Loads (or reloads) the given map into the already-initialized room. Safe to call
## after _ready() — used by _ready() itself and by the F2 debug panel.
func load_map(new_map_id: String, new_wall_height_override: int = 0, new_seed: int = 0) -> void:
	map_id = new_map_id
	wall_height_override = new_wall_height_override
	if new_map_id == "PROCEDURAL":
		level_seed = new_seed

	var graph: LevelGraph = LevelGraphClass.new()
	var connections: Dictionary = graph.generate(level_seed)

	var spec: Dictionary = MapCatalogClass.get_spec(map_id, {
		"connections":      connections,
		"segment_grid_pos": segment_grid_pos,
		"seed":             level_seed,
	})
	var layout: Dictionary = MapCompilerClass.compile(spec, {
		"connections":         connections,
		"segment_grid_pos":    segment_grid_pos,
		"seed":                level_seed,
		"wall_height_override": wall_height_override,
	})
	_base_layout = layout.duplicate(true)
	_agent_start_cell_base = layout.get("agent_start_cell", Vector2i.ZERO)
	_room_size = layout.get("size", Vector2i.ZERO)
	if _room_size == Vector2i.ZERO:
		push_error("Room layout did not provide a valid map size.")
		return

	var view_layout := _layout_with_perspective(_base_layout, _active_perspective)
	_room_size = view_layout.get("size", _room_size)
	_map_buffer = view_layout.get("buffer", 0)
	_build_room(view_layout)

	## Reset turn/agent state so a reload doesn't leave stale AP/position/FOW from the
	## previous map. Reuse whatever _ready() already does after _build_room() for
	## agent placement, turn_manager reset, FOW rebuild, camera recenter.
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
	_fow_controller.initialize_fog(floor_layer, VISUAL_GRID_OFFSET, _room_size)
	_fow_controller.reveal_around(agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w = _room_size.x
	tile_labels_overlay.room_h = _room_size.y
	tile_labels_overlay.visible = false
	btn_numbers.modulate = Color(1.0, 1.0, 1.0, 0.35)
	camera.ignore_rotation = true
	camera.rotation_degrees = 0.0

	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	turn_manager.reset_player_turn()
	_update_alert_label()
	enemy_turn_banner.visible = false

	tile_labels_overlay.queue_redraw()
	_lighting_controller.rebuild_all()
	if _ceiling_overlay != null:
		_ceiling_overlay.set_lights(_current_light_sources)
	_agent_trail.clear()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()
	if _noise_system != null:
		_noise_system.clear()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()

	_alert_meter = 0
	_update_alert_label()
	_update_guard_los_data()


func _ready() -> void:
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	floor_layer.z_index = 0
	structure_wall_layer.tile_set = ts
	structure_wall_layer.z_index = WALL_BASE_Z_INDEX
	structure_layer.tile_set = ts
	structure_layer.z_index = 10
	_wall_tileset = ts
	## M2-13: Initialize shadow layers
	shadow_full_layer.tile_set = ts
	shadow_partial_layer.tile_set = ts
	shadow_full_layer.z_index = 1
	shadow_partial_layer.z_index = 1
	shadow_full_layer.modulate = Color(0.58, 0.58, 0.58, 1.0)
	shadow_partial_layer.modulate = Color(0.78, 0.78, 0.78, 1.0)
	_build_registry(ts)
	
	## SLICE-02: Initialize VoxelRenderer (legacy builders retained for now)
	_voxel_renderer = VoxelRendererClass.new()
	add_child(_voxel_renderer)
	_voxel_renderer.setup(VISUAL_GRID_OFFSET, WALL_BASE_Z_INDEX)
	
	_subcube_tileset = _build_subcube_tileset()
	_voxel_tileset   = _build_voxel_tileset()    ## VOXEL-02: null-safe if PNGs missing

	## MODULARIZE-03: Initialize LightingController (before VisionController, which connects to its signals)
	_lighting_controller = LightingControllerClass.new()
	_lighting_controller.name = "LightingController"
	add_child(_lighting_controller)
	_lighting_controller.setup(self)

	## MODULARIZE-01: Initialize VisionController (after systems ready, before final _ready() wiring)
	_vision_controller = VisionControllerClass.new()
	_vision_controller.name = "VisionController"
	add_child(_vision_controller)
	_vision_controller.setup(self, fog_of_war)
	set_meta("vision_controller", _vision_controller)

	## Connect LightingController signal to VisionController for overlay updates
	_lighting_controller.lighting_rebuilt.connect(_vision_controller.request_redraw)
	## Geometric floor shadows are real-world elements → repaint the always-on
	## world shadow layer whenever lighting rebuilds (e.g. perspective rotation).
	_lighting_controller.lighting_rebuilt.connect(_repaint_world_shadows)

	## MODULARIZE-02: Initialize HudController (after nodes ready)
	_hud_controller = HudControllerClass.new()
	_hud_controller.name = "HudController"
	add_child(_hud_controller)
	_hud_controller.setup({
		"btn_end_turn": btn_end_turn,
		"btn_reset": btn_reset,
		"btn_fullscreen": btn_fullscreen,
		"btn_viewport": btn_viewport,
		"btn_numbers": btn_numbers,
		"chk_auto_end_turn": chk_auto_end_turn,
		"lbl_ap": lbl_ap,
		"lbl_alert": lbl_alert,
		"busted_dialog": busted_dialog,
		"enemy_turn_banner": enemy_turn_banner,
		"lbl_end_turn": lbl_end_turn,
		"lbl_enemy_turn": lbl_enemy_turn,
	})

	## Connect HudController signals to room handlers
	_hud_controller.end_turn_requested.connect(_on_hud_end_turn_requested)
	_hud_controller.reset_requested.connect(_on_hud_reset_requested)
	_hud_controller.fullscreen_toggled.connect(_on_hud_fullscreen_toggled)
	_hud_controller.viewport_toggled.connect(_on_hud_viewport_toggled)
	_hud_controller.numbers_toggled.connect(_on_hud_numbers_toggled)

	## MODULARIZE-04: Initialize CameraController (after camera ready)
	_camera_controller = CameraControllerClass.new()
	_camera_controller.name = "CameraController"
	add_child(_camera_controller)
	_camera_controller.setup(camera, self)

	## MODULARIZE-05: Initialize FowController (before fog operations)
	_fow_controller = FowControllerClass.new()
	_fow_controller.name = "FowController"
	add_child(_fow_controller)
	_fow_controller.setup(self, fog_of_war, _fog_rect)

	## MODULARIZE-06: Initialize GuardCoordinator (after fow controller)
	_guard_coordinator = GuardCoordinatorClass.new()
	_guard_coordinator.name = "GuardCoordinator"
	add_child(_guard_coordinator)
	_guard_coordinator.setup(self)

	turn_manager.ap_changed.connect(_on_ap_changed)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.enemy_phase_started.connect(_on_enemy_phase_started)
	agent.move_started.connect(_on_agent_move_started)
	agent.step_finished.connect(_on_agent_step_finished)
	agent.move_finished.connect(_on_agent_move_finished)
	## Perspective button connections now in CameraController

	load_map(map_id, wall_height_override, level_seed)

	## DEBUG-01: Create map loader toolbar button
	_create_map_loader_button()

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

	## Create shadow boundary overlay (dark edges of playable shadows)
	_shadow_boundary_overlay = Node2D.new()
	_shadow_boundary_overlay.set_script(ShadowBoundaryOverlayClass)
	_shadow_boundary_overlay.z_index = 4  ## Above _tile_game (z=3), well above fog_of_war (z=2)
	add_child(_shadow_boundary_overlay)
	_shadow_boundary_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

	_tile_game = Node2D.new()
	_tile_game.set_script(TileOverlayClass)
	_tile_game.z_index = 3  ## Renders above noise/detection
	add_child(_tile_game)
	_tile_game.material = CanvasItemMaterial.new()
	_tile_game.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_tile_game.setup(floor_layer, VISUAL_GRID_OFFSET)

	## Paint the initial always-on world shadows from the geometric exposure.
	_repaint_world_shadows()

	## M2-14 Quickfix: Z-index ordering — floor(0) < shadow(1) < fog(2) < structures(3) < sprites(4+)
	## Ensure fog_of_war is properly layered above shadow overlay
	fog_of_war.z_index = 2

	## M2-14: Create and setup guard noise indicator — as child of agent so it orbits naturally
	_guard_noise_indicator = GuardNoiseIndicatorClass.new()
	agent.add_child(_guard_noise_indicator)
	_guard_noise_indicator.setup(floor_layer, VISUAL_GRID_OFFSET)

	## VIS-01 Slice 3: overhead ceiling layer (lights as placeholders for now),
	## raised above the wall stack and drawn above the top storey.
	_ceiling_overlay = CeilingPropOverlayClass.new()
	add_child(_ceiling_overlay)
	var ceil_floors: int = int(_base_layout.get("max_floors", 1))
	_ceiling_overlay.z_index = WALL_BASE_Z_INDEX + ceil_floors + 1
	## Lift to ceiling height: top of the wall stack + ~0.75 storey so fixtures read
	## as mounted overhead. True "5th-floor" verticality needs taller storeys (pairs
	## with the view-occlusion slice, else taller walls hide the interior).
	var ceiling_lift: float = WALL_FLOOR_STEP_PX * (float(ceil_floors) + 0.75)
	_ceiling_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, ceiling_lift)
	_ceiling_overlay.set_lights(_current_light_sources)

	## Light ray overlay — always-visible golden shafts, MIX blend, below shadow MUL (z=1).
	## Created here (after ceil_floors) so ceiling_lift matches the CeilingPropOverlay exactly.
	_light_ray_overlay = LightRayOverlayClass.new()
	_light_ray_overlay.z_index = 0
	_light_ray_overlay.visible = false  ## hidden by default; toggled by VisionController (L key)
	add_child(_light_ray_overlay)
	_light_ray_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, ceiling_lift)
	## Initial populate: _repaint_world_shadows() ran before this node existed, so feed it now.
	_light_ray_overlay.refresh(_lighting_controller.get_shadow_results())

	## Dev 03: Create hover label for tile coordinates
	_dev_hover_label = Label.new()
	_dev_hover_label.add_theme_font_size_override("font_size", 13)
	_dev_hover_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	_dev_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_dev_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	_dev_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	## Black 80% backplate for contrast (matches other DEV/UI panels)
	var _hover_bg := StyleBoxFlat.new()
	_hover_bg.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	_hover_bg.content_margin_left = 8.0
	_hover_bg.content_margin_right = 8.0
	_hover_bg.content_margin_top = 6.0
	_hover_bg.content_margin_bottom = 6.0
	_hover_bg.corner_radius_top_left = 4
	_hover_bg.corner_radius_top_right = 4
	_hover_bg.corner_radius_bottom_left = 4
	_hover_bg.corner_radius_bottom_right = 4
	_dev_hover_label.add_theme_stylebox_override("normal", _hover_bg)
	_dev_hover_label.position = Vector2(12.0, 80.0)   ## below TopBar
	_dev_hover_label.z_index = 200
	_dev_hover_label.visible = false
	$HUD.add_child(_dev_hover_label)
	_update_perspective_button_state()

	## Centering camera/setup initial state
	_update_guard_los_data()
	_on_hud_viewport_toggled()


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
		
		# Update tile semantics and shadow heights for new layout (LIGHT-FIX-03)
		# Now delegated to LightingController
		
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

		_fow_controller.initialize_fog(floor_layer, VISUAL_GRID_OFFSET, _room_size)
		_fow_controller.reveal_around(agent.cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
		_update_guard_los_data()
		_center_camera(agent.cell)

		## Re-derive the per-cell overlays for the rotated layout so they follow the scenery:
		## numbers redraw, lighting (lights/semantics/shadows/exposure) rebuilds from the rotated
		## cells and emits lighting_rebuilt → VisionController refreshes its analysis overlays.
		tile_labels_overlay.queue_redraw()
		_lighting_controller.rebuild_all()
		_ceiling_overlay.set_lights(_current_light_sources)
		## Dev agent trail cells are now stale under the rotation — clear it.
		_agent_trail.clear()
		if _trail_overlay != null:
			_trail_overlay.queue_redraw()

		_refresh_tactical_state()
	_update_perspective_button_state()


func _update_perspective_button_state() -> void:
	var active_mod := Color(1.0, 1.0, 1.0, 1.0)
	var inactive_mod := Color(1.0, 1.0, 1.0, 0.45)
	btn_perspective_nw.modulate = active_mod if _active_perspective == "W" else inactive_mod
	btn_perspective_ne.modulate = active_mod if _active_perspective == "N" else inactive_mod
	btn_perspective_sw.modulate = active_mod if _active_perspective == "S" else inactive_mod
	btn_perspective_se.modulate = active_mod if _active_perspective == "E" else inactive_mod


func _toggle_map_loader_panel() -> void:
	if _map_loader_panel == null:
		var MapLoaderPanelClass = preload("res://godot/scripts/debug/map_loader_panel.gd")
		_map_loader_panel = ConfirmationDialog.new()
		_map_loader_panel.set_script(MapLoaderPanelClass)
		add_child(_map_loader_panel)
		_map_loader_panel.setup(self)
	_map_loader_panel.popup_centered_ratio(0.5)
	print("DEBUG: Map loader panel opened")


func _create_map_loader_button() -> void:
	if toolbar_row == null:
		return
	var btn_map := Button.new()
	btn_map.text = "🗺️"
	btn_map.add_theme_font_size_override("font_size", 16)
	btn_map.custom_minimum_size = Vector2(40.0, 32.0)
	btn_map.pressed.connect(_toggle_map_loader_panel)
	toolbar_row.add_child(btn_map)


func _center_camera(focus_cell: Vector2i) -> void:
	var centre_world := floor_layer.map_to_local(focus_cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	camera.global_position = centre_world


func _on_hud_numbers_toggled() -> void:
	tile_labels_overlay.visible = not tile_labels_overlay.visible
	_hud_controller.set_numbers_button_active(tile_labels_overlay.visible)


func _on_hud_fullscreen_toggled(enabled: bool) -> void:
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(target_mode)


func _on_hud_end_turn_requested() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	turn_manager.end_turn()


func _on_hud_reset_requested() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	_hud_controller.hide_enemy_banner()
	agent.set_cell(_agent_start_cell)
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)
	_fow_controller.reset_fog()
	_fow_controller.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
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


func _on_hud_viewport_toggled() -> void:
	_is_desktop_viewport = not _is_desktop_viewport
	var target := Vector2i(1280, 720) if _is_desktop_viewport else Vector2i(390, 844)
	_hud_controller.set_viewport_button_text("D" if _is_desktop_viewport else "M")

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
	## Purple diamond on each segment exit tile.
	## Drawn in the Room node's _draw() — renders below fog_of_war.
	## Revealed naturally when the FOW uncovers the area. Visible in DEV_VISION
	## because the fog is hidden (fog_of_war.visible = false).
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
	## Dark diamond on the spawn point — DEV_VISION only.
	## Lets you quickly identify the AGENT_START_CELL when testing maps.
	if not _vision_controller.dev_vision:
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


func _draw_playable_boundary() -> void:
	## Linha vermelha fina ao redor da área JOGÁVEL (excluindo o buffer ring).
	## Visível apenas em DEV_VISION.
	if not _vision_controller.dev_vision:
		return
	if floor_layer == null or _base_layout.is_empty():
		return

	## playable_rect: Rect2i(offset, inner_size) — injetado pelo MapCompiler.
	## Fallback para _room_size inteiro quando não disponível (mapas legados).
	var pr: Rect2i = _base_layout.get("playable_rect", Rect2i(Vector2i.ZERO, _room_size))
	var origin: Vector2i = pr.position
	var size:   Vector2i = pr.size
	var off:    Vector2  = VISUAL_GRID_OFFSET

	var n: Vector2 = floor_layer.map_to_local(origin) + off
	var e: Vector2 = floor_layer.map_to_local(origin + Vector2i(size.x, 0)) + off
	var s: Vector2 = floor_layer.map_to_local(origin + size) + off
	var w: Vector2 = floor_layer.map_to_local(origin + Vector2i(0, size.y)) + off

	draw_polyline(
		PackedVector2Array([n, e, s, w, n]),
		Color(1.0, 0.15, 0.15, 0.90),
		2.5,
		true
	)

## Artistic shadow spill: a full-shadow tile bleeds a soft halo onto its neighbours.
## COSMETIC only — never feeds gameplay (detection reads ExposureSystem), so the spill
## has no hiding value. Shaped two ways:
##   • density — denser real-shadow clusters (e.g. tall crate stacks) push the halo out
##     one extra ring per SHADOW_SPILL_DENSITY_STEP neighbours, up to SHADOW_SPILL_MAX_RADIUS.
##   • direction — orthogonal spill tiles read slightly darker than diagonal ones, which
##     softens the hard concentric rings.
## All tunable (var, not gameplay stat). See _compute_shadow_spill / _spill_color.
const SHADOW_SPILL_RADIUS := 2
var SHADOW_SPILL_MAX_RADIUS: int = 4        ## hard cap on density-extended reach
var SHADOW_SPILL_DENSITY_STEP: int = 2      ## +1 ring per this many clustered full cells
var SHADOW_SPILL_BASE_DARKEN: float = 0.18  ## ring-1 orthogonal darkening (1 - keeps)
var SHADOW_SPILL_FALLOFF: float = 0.5       ## darkening multiplier per further ring
var SHADOW_SPILL_DIAGONAL_FACTOR: float = 0.65  ## diagonal keeps lighter than orthogonal

## Paint the always-on world shadow layer from the geometric exposure result.
## Floor shadows are real-world elements (always visible), not a debug overlay:
## the multiply-blend `_tile_shadow` darkens shadowed floor under every vision mode.
func _repaint_world_shadows() -> void:
	if _tile_shadow == null:
		return
	var exposure = _lighting_controller.get_exposure_system()
	if exposure == null:
		return
	_tile_shadow.clear_all()
	var full_cells: Array[Vector2i] = exposure.get_shadow_cells()
	var penumbra_cells: Array[Vector2i] = exposure.get_penumbra_cells()
	## Cosmetic halo first (lowest visual weight), real shadow tiles on top so the
	## geometric silhouette stays crisp where it matters.
	var spill: Dictionary = _compute_shadow_spill(full_cells, penumbra_cells)
	_tile_shadow.set_cells_colored(spill, TileOverlayClass.PRIO_SHADOW)
	_tile_shadow.set_cells_named(penumbra_cells, "shadow_lite", TileOverlayClass.PRIO_SHADOW)
	_tile_shadow.set_cells_named(full_cells, "shadow_full", TileOverlayClass.PRIO_SHADOW)

	## Update shadow boundary overlay with separate full and lite shadow cells
	if _shadow_boundary_overlay != null:
		_shadow_boundary_overlay.set_full_shadow_cells(full_cells)
		_shadow_boundary_overlay.set_lite_shadow_cells(penumbra_cells)

	## Refresh light ray overlay with the latest per-light shadow projections
	if _light_ray_overlay != null:
		_light_ray_overlay.refresh(_lighting_controller.get_shadow_results())


## Build the cosmetic spill halo around the FULL-shadow tiles.
## Returns Vector2i → Color (multiply tint). Each spill cell's tone comes from its ring
## distance to the nearest full cell and whether that offset is orthogonal (darker) or
## diagonal (lighter); the reach grows with local cluster density. Cells already shadowed
## (full/penumbra) are excluded so the halo never lightens a real shadow; clamped to room.
func _compute_shadow_spill(full_cells: Array[Vector2i], penumbra_cells: Array[Vector2i]) -> Dictionary:
	var occupied: Dictionary = {}  ## cells that must NOT receive spill
	for c: Vector2i in full_cells:
		occupied[c] = true
	for c: Vector2i in penumbra_cells:
		occupied[c] = true
	var full_set: Dictionary = {}
	for c: Vector2i in full_cells:
		full_set[c] = true
	## best[cell] = {"level": ring, "ortho": bool}; darkest wins (lowest ring, ortho on tie).
	var best: Dictionary = {}
	for c: Vector2i in full_cells:
		var reach: int = _spill_reach_for(c, full_set)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx == 0 and dy == 0:
					continue
				var level: int = maxi(absi(dx), absi(dy))  ## Chebyshev ring
				if level > reach:
					continue
				var cell := c + Vector2i(dx, dy)
				if occupied.has(cell):
					continue
				if cell.x < 0 or cell.y < 0 or cell.x >= _room_size.x or cell.y >= _room_size.y:
					continue
				var ortho: bool = (dx == 0 or dy == 0)
				if not best.has(cell):
					best[cell] = {"level": level, "ortho": ortho}
				else:
					var b: Dictionary = best[cell]
					if level < b["level"] or (level == b["level"] and ortho and not b["ortho"]):
						best[cell] = {"level": level, "ortho": ortho}
	var out: Dictionary = {}
	for cell: Vector2i in best:
		out[cell] = _spill_color(best[cell]["level"], best[cell]["ortho"])
	return out


## Spill reach (ring count) for a full cell: base radius + 1 per density step of clustered
## full neighbours, capped. Denser real-shadow masses (e.g. tall crate stacks) glow wider.
func _spill_reach_for(cell: Vector2i, full_set: Dictionary) -> int:
	var density: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if full_set.has(cell + Vector2i(dx, dy)):
				density += 1
	return clampi(
		SHADOW_SPILL_RADIUS + int(float(density) / SHADOW_SPILL_DENSITY_STEP),
		SHADOW_SPILL_RADIUS, SHADOW_SPILL_MAX_RADIUS)


## Multiply tint for a spill cell at ring `level` (1 = closest), orthogonal or diagonal.
## Darkening falls off geometrically per ring; diagonals keep lighter than orthogonals.
## Cool-blue tone (blue darkens least), matching the shadow ramp. Returns a >0.8 keeps value.
func _spill_color(level: int, ortho: bool) -> Color:
	var darken: float = SHADOW_SPILL_BASE_DARKEN * pow(SHADOW_SPILL_FALLOFF, float(level - 1))
	if not ortho:
		darken *= SHADOW_SPILL_DIAGONAL_FACTOR
	var keeps: float = clampf(1.0 - darken, 0.0, 1.0)
	return Color(keeps, keeps, minf(1.0, keeps + 0.05), 1.0)


func _draw_shadow_debug() -> void:
	## M2-13: ShadowOverlay now handles the permanent visualization.
	## Kept only for technical debug in DEV_VISION (translucent blue overlay).
	if not _vision_controller.dev_vision:
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
		## Direct shadow: dark blue. Penumbra: lighter blue.
		var alpha := 0.35 if mult < PENUMBRA_MULT else 0.15
		var color := Color(0.1, 0.4, 1.0, alpha)
		draw_colored_polygon(diamond, color)


func _on_ap_changed(current_ap: int, max_ap: int) -> void:
	_hud_controller.update_ap(current_ap, max_ap, turn_manager.is_enemy_phase)
	movement_overlay.set_remaining_ap(current_ap)
	if not agent.is_moving:
		_refresh_tactical_state()
	
	if current_ap == 0 and not turn_manager.is_enemy_phase:
		_peek_pending = false


## Peek mechanic: look past an adjacent obstacle without moving
func _try_peek(direction: Vector2i) -> void:
	if turn_manager.current_ap < 1:
		return
	
	var target_cell := agent.cell + direction
	if not _blocked_cells.has(target_cell):
		return # Peeking only makes sense against obstacles

	## Reveal 3 tiles ahead in the peek direction
	for i in range(1, 4):
		var peek_cell := agent.cell + direction * i
		if not _is_cell_inside_room(peek_cell):
			break
		_fow_controller.add_peek_reveal(peek_cell)
		
	turn_manager.consume_ap(1)
	_peek_active = true
	_peek_timer = 1
	_update_guard_los_data()


func _on_agent_move_started(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	selection_overlay.set_selected(to_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()


func _on_agent_step_finished(step_cell: Vector2i) -> void:
	_fow_controller.reveal_around(step_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Dev 04: register trail — last position when stepping in
	if _agent_trail.is_empty() or _agent_trail.back() != step_cell:
		_agent_trail.append(step_cell)
		if _agent_trail.size() > TRAIL_MAX:
			_agent_trail.pop_front()

	if _vision_controller.dev_vision and _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## M2-04: Generate noise per tic — roll the dice on each step
	if _noise_system != null:
		if randf() < NoiseSystem.NOISE_CHANCE_WALK:
			_noise_system.emit(step_cell, NoiseSystem.NOISE_INTENSITY_WALK)
		if _noise_overlay != null:
			_noise_overlay.queue_redraw()

	## M2-05: Immediate auditory detection after generating noise
	_process_audio_detection()

	## Detection tic — the agent crossed an edge
	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var result: TicSystem.TicResult = TicSystem.evaluate(
			guard, step_cell, _blocked_cells, blocked_edges
		)
		_apply_tic_result(guard, result)

	## Process voxel system dirty flags (VOXEL-07)
	_tic_voxel_system()


## Processes the result of a detection tic for a guard.
func _apply_tic_result(guard, result: TicSystem.TicResult) -> void:
	## Accumulate or decay the guard's detection field
	if result.visible:
		guard.detection = clampf(
			guard.detection + result.raw_chance * TicSystem.DETECTION_GAIN_PER_TIC,
			0.0, 1.0
		)
	else:
		## Decay outside the cone
		var decay := _get_detection_decay(guard.state)
		guard.detection = clampf(guard.detection + decay, 0.0, 1.0)

	## M2-04: Noise amplifies detection if the guard already sees the tile
	if _noise_system != null:
		var noise_intensity: float = _noise_system.get_intensity(agent.cell)
		if noise_intensity > 0.0 and result.visible:
			var bonus: float = noise_intensity * 0.3
			guard.detection = clampf(guard.detection + bonus, 0.0, 1.0)

	if _vision_controller.dev_vision:
		guard.queue_redraw()

	## ID-01: Gradual threshold-based escalation — only when the agent is visible
	if result.visible:
		if guard.detection >= DETECTION_THRESHOLD_CHASE:
			guard.observe_player(true, 3, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max:
				_guard_coordinator._on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_ALERT:
			guard.observe_player(true, 2, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max:
				_guard_coordinator._on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
			guard.observe_player(true, 1, agent.cell)
		## Below DETECTION_THRESHOLD_SUSPICIOUS: meter accumulates, no state change

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


## M2-05: Processes auditory detection for all guards
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
			_fow_controller.reset_peek_reveals()


func _on_enemy_phase_started() -> void:
	if _guards.is_empty():
		turn_manager.finish_enemy_phase()
		return
	_update_guard_los_data()
	_hud_controller.show_enemy_banner()
	movement_overlay.clear_overlay()
	path_preview.clear_path()
	selection_overlay.set_selected(agent.cell)
	## M2-14: Lock the camera on the agent during the enemy turn
	_center_camera(agent.cell)
	await _hold_actor_end_pause()
	await _run_enemy_phase()
	_hud_controller.hide_enemy_banner()
	if _alert_meter >= _alert_max:
		await _show_busted_dialog()
		_reset_room_state()
	_update_alert_label()

	## M2-04: Decay noise at end of enemy phase
	if _noise_system != null:
		_noise_system.decay_all()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()

	## Return the camera to the agent at the end of the enemy turn
	_center_camera(agent.cell)

	turn_manager.finish_enemy_phase()


func _run_enemy_phase() -> void:
	## M2-05: Process persistent noise before the guards act
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
			_guard_coordinator._on_guard_emits_noise   ## M2-14: noise callback
		)
		max_severity = maxi(max_severity, int(report.get("max_severity", 0)))

		## Camera follows the guard only if its tile is revealed by the FOW
		if _fow_controller.is_cell_revealed(guard.cell):
			await _focus_camera_for_enemy_phase(guard.cell)

		await _hold_actor_end_pause()

	## Alert accumulation now happens in _apply_tic_result() during the tics
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


## M2-14: Emit a sound indicator toward the noise direction (with ±2 tile imprecision)
func _emit_guard_noise_indicator(guard_cell: Vector2i, intensity: float) -> void:
	if _guard_noise_indicator == null:
		return
	
	## Imprecision: random ±2 tile offset to avoid revealing the exact position
	var fuzzy_cell := guard_cell + Vector2i(
		randi_range(-2, 2),
		randi_range(-2, 2)
	)
	var agent_world  := floor_layer.map_to_local(agent.cell) + VISUAL_GRID_OFFSET
	var noise_world  := floor_layer.map_to_local(fuzzy_cell) + VISUAL_GRID_OFFSET
	
	_guard_noise_indicator.add_indicator(agent_world, noise_world, intensity)


## M2-14: Callback: runs when a guard emits noise after moving


func _update_alert_label() -> void:
	var pct := float(_alert_meter) / float(_alert_max)
	_hud_controller.update_alert(pct)


func _show_busted_dialog() -> void:
	_hud_controller.show_busted("ui.banner.busted")
	await get_tree().create_timer(1.2).timeout
	_hud_controller.hide_busted()


## ID-02: Full memory flush — resets all state when the room needs to restart
func _reset_room_state() -> void:
	## Zero the global alert
	_alert_meter = 0

	## Reset the agent position
	agent.set_cell(_agent_start_cell)
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)

	## Reset all guards to their starting routes
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()

	## Clear the agent trail
	_agent_trail.clear()

	## Reset FOW
	_fow_controller.reset_fog()
	_fow_controller.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Clear the noise system
	if _noise_system != null:
		_noise_system.clear()

	## Reset visual overlays
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## Center the camera on the agent
	_center_camera(agent.cell)

	## Force UI update
	_update_alert_label()


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

	_dev_hover_label.visible = _vision_controller.dev_vision

	if not _vision_controller.dev_vision or _hovered_cell == INVALID_CELL:
		return

	var cell := _hovered_cell
	var info := "tile  %d , %d" % [cell.x, cell.y]
	info += "\nblocked: %s" % ("yes" if _blocked_cells.has(cell) else "no")

	## Lighting / shadow semantics (ExposureSystem)
	var exposure = _lighting_controller.get_exposure_system()
	if exposure != null:
		info += "\nlight: %s" % exposure.get_tile_debug_info(cell)
		info += "\nshadow: depth %d · %s · conf %.2f" % [
			exposure.get_shadow_depth(cell),
			exposure.get_shadow_stability(cell),
			exposure.get_exposure_confidence(cell)]

	if _exit_cells.has(cell):
		info += "\nexit tile"

	for light in _current_light_sources:
		if int(light.get("x", 0)) == cell.x and int(light.get("y", 0)) == cell.y:
			info += "\nlight source (r%d)" % int(light.get("radius", 0))
			break

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
		
		_guard_coordinator.register_guard(guard)
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





func _update_enemy_visibility() -> void:
	# Update enemy alpha/saturation each frame while moving.
	# Visibility is driven by the player's vision radius + ability bonuses.
	# At vision distance the guard starts to desaturate, then fades out one tile later.
	if _vision_controller.dev_vision:
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
	_draw_playable_boundary()
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
	if _vision_controller.dev_vision:
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
	_pending_auto_end_turn = _hud_controller.is_auto_end_turn_enabled() and int(turn_manager.current_ap) <= 0
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


## Ensure `count` runtime wall layers exist above the base course (storeys 1..count).
## Each higher layer is offset up by one cube and drawn one z above the previous so its top
## occludes sprites. Idempotent — reuses existing layers across rebuilds/perspective switches.
func _ensure_wall_upper_layers(count: int) -> void:
	while _wall_upper_layers.size() < count:
		var level := _wall_upper_layers.size() + 1
		var layer := TileMapLayer.new()
		layer.tile_set = _wall_tileset
		layer.y_sort_origin = 1
		layer.position = Vector2(0.0, -WALL_FLOOR_STEP_PX * float(level))
		layer.z_index = WALL_BASE_Z_INDEX + level
		add_child(layer)
		_wall_upper_layers.append(layer)
	## Surplus layers (shorter map after a taller one) are cleared by the caller; hide them.
	for i in range(_wall_upper_layers.size()):
		_wall_upper_layers[i].visible = i < count


## Ensure `count` runtime prop-stack layers exist above structure_layer (crate stacks 1..count).
## Mirrors _ensure_wall_upper_layers but steps by CRATE_STACK_STEP_PX so a crate seats on the
## one below. Idempotent — reuses layers across rebuilds/perspective switches.
func _ensure_prop_stack_layers(count: int) -> void:
	while _prop_stack_layers.size() < count:
		var level := _prop_stack_layers.size() + 1
		var layer := TileMapLayer.new()
		layer.tile_set = _wall_tileset
		layer.y_sort_origin = 1
		layer.position = Vector2(0.0, -CRATE_STACK_STEP_PX * float(level))
		layer.z_index = structure_layer.z_index + level
		add_child(layer)
		_prop_stack_layers.append(layer)
	for i in range(_prop_stack_layers.size()):
		_prop_stack_layers[i].visible = i < count


func _build_subcube_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var source_id: int = 0
	var materials: Array[String] = ["subcube_concrete", "subcube_metal", "subcube_stone", "subcube_wood"]
	var directions: Array[String] = ["NW", "NE", "SE", "SW"]

	for mat in materials:
		var path := "res://ASSETS/ISOMETRIC/source_assets/subcubes/%s.png" % mat
		var texture: Texture2D = load(path)
		if texture == null:
			push_warning("Room: missing subcube texture: %s" % path)
			continue

		## Tile base — blocos sólidos (sem offset direcional)
		var src_base := TileSetAtlasSource.new()
		src_base.texture = texture
		src_base.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		src_base.create_tile(Vector2i(0, 0))
		ts.add_source(src_base, source_id)
		var td_base: TileData = src_base.get_tile_data(Vector2i(0, 0), 0)
		if td_base != null:
			td_base.texture_origin = SUBCUBE_BASE_ORIGIN
			td_base.set_custom_data("tile_name", mat)
		_subcube_tile_ids[mat] = source_id
		source_id += 1

		## Variantes direcionais — faces de parede (mesmo PNG, texture_origin diferente)
		for dir in directions:
			var variant_name := "%s_%s" % [mat, dir]
			var src_dir := TileSetAtlasSource.new()
			src_dir.texture = texture
			src_dir.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
			src_dir.create_tile(Vector2i(0, 0))
			ts.add_source(src_dir, source_id)
			var td_dir: TileData = src_dir.get_tile_data(Vector2i(0, 0), 0)
			if td_dir != null:
				td_dir.texture_origin = SUBCUBE_BASE_ORIGIN + SUBCUBE_FACE_OFFSETS[dir]
				td_dir.set_custom_data("tile_name", variant_name)
			_subcube_tile_ids[variant_name] = source_id
			source_id += 1

	if source_id == 0:
		push_warning("Room: subcube tileset could not be built; subcube render will stay on fallback.")
		return null
	return ts


func _ensure_subcube_layers(count: int) -> void:
	if _subcube_tileset == null:
		return
	while _subcube_layers.size() < count:
		var level := _subcube_layers.size()
		var layer := TileMapLayer.new()
		layer.tile_set = _subcube_tileset
		layer.y_sort_origin = 1
		layer.position = Vector2(
				VISUAL_GRID_OFFSET.x,
				VISUAL_GRID_OFFSET.y - SUBCUBE_STEP_PX * float(level))
		layer.z_index = WALL_BASE_Z_INDEX + level
		add_child(layer)
		_subcube_layers.append(layer)
	for i in range(_subcube_layers.size()):
		_subcube_layers[i].visible = i < count


## ── Voxel render plane (VOXEL series) ────────────────────────────────────────

func _build_voxel_tileset() -> TileSet:
	## Builds the voxel TileSet at runtime from source_assets/voxels/*.png.
	## tile_size = 32×16, texture_origin = (0,10) — derived from atom layout (SLICE-00).
	## One source per material, no directional variants.
	## Returns null (with push_warning) if any PNG is missing; safe to call always.
	var ts := TileSet.new()
	ts.tile_shape  = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size   = Vector2i(32, 16)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var source_id: int = 0
	var materials: Array[String] = ["concrete", "metal", "stone", "wood"]

	for mat in materials:
		var path     := "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png" % mat
		var texture: Texture2D = load(path)
		if texture == null:
			push_warning("Room._build_voxel_tileset: missing %s — run VOXEL-01 first." % path)
			continue

		var src := TileSetAtlasSource.new()
		src.texture             = texture
		src.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, source_id)

		var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
		if td != null:
			## Derived from Canon 3: (atom_h - tile_h) / 2 = (36 - 16) / 2 = 10 (SLICE-00)
			td.texture_origin = Vector2i(0, (36 - 16) / 2.0)
			td.set_custom_data("tile_name", "voxel_%s" % mat)

		_voxel_tile_ids["voxel_%s" % mat] = source_id
		source_id += 1

	if source_id == 0:
		push_warning("Room._build_voxel_tileset: no voxel textures loaded.")
		return null
	return ts


func _ensure_voxel_layers(count: int) -> void:
	## Creates TileMapLayers for the voxel render plane, one per vertical level.
	## SLICE-00 fix: Compensate for tile_size difference (floor 256×128, voxel 32×16).
	## Voxel layer must be offset by (floor_half_size - voxel_half_size) = (128-16, 64-8) = (112, 56)
	## to align N-vertices after set_cell() placement.
	## Layer k: position = (VISUAL_GRID_OFFSET + offset) - (0, VOXEL_STEP_PX × k)
	##          z_index  = WALL_BASE_Z_INDEX + k
	if _voxel_tileset == null:
		return
	
	const TILE_OFFSET: Vector2 = Vector2(112.0, 56.0)
	
	while _voxel_layers.size() < count:
		var level := _voxel_layers.size()
		var layer := TileMapLayer.new()
		layer.tile_set     = _voxel_tileset
		layer.y_sort_origin = 1
		layer.position     = Vector2(
				VISUAL_GRID_OFFSET.x + TILE_OFFSET.x,
				VISUAL_GRID_OFFSET.y + TILE_OFFSET.y - VOXEL_STEP_PX * float(level))
		layer.z_index      = WALL_BASE_Z_INDEX + level
		add_child(layer)
		_voxel_layers.append(layer)
	for i in range(_voxel_layers.size()):
		_voxel_layers[i].visible = i < count


func _render_subcube_geometry(subcube_geometry: Dictionary, max_floors: int) -> void:
	if _subcube_tileset == null:
		return

	var layer_count: int = maxi(1, max_floors * SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS)
	_ensure_subcube_layers(layer_count)
	if _subcube_layers.is_empty():
		return
	for layer in _subcube_layers:
		layer.clear()

	var tile_name := "subcube_concrete"
	if not _subcube_tile_ids.has(tile_name):
		tile_name = String(_subcube_tile_ids.keys()[0]) if not _subcube_tile_ids.is_empty() else ""
	var source_id: int = _subcube_tile_ids.get(tile_name, -1)
	if source_id < 0:
		return

	var blocks: Array = subcube_geometry.get("solid_blocks", [])
	## Wall faces são renderizadas por WallContainers (ver _build_wall_containers).
	## Blocos sólidos continuam no TileMapLayer.
	for block: Dictionary in blocks:
		_paint_subcube_descriptor(block, source_id, layer_count)


## ── Voxel wall placement (VOXEL-04) ──────────────────────────────────────────

func _voxel_slice_positions(from_cell: Vector2i, edge_delta: Vector2i,
		slice_index: int) -> Array[Vector2i]:
	## Retorna as 8 posições voxel para um slice de uma aresta de parede.
	## slice_index 0 = inner (no from_cell), 1 = outer (no to_cell adjacente).
	## Usa VOXELS_PER_UNIT_AXIS (= 8) de SubcubeCoordsClass.
	## Ver VOXEL_MASTER_PLAN.md §5 e DIRECTION_GLOSSARY.md §5 para geometria.
	var positions: Array[Vector2i] = []
	var to_cell: Vector2i = from_cell + edge_delta
	var vpu: int = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS  ## 8

	match edge_delta:
		Vector2i(-1, 0):   ## NW: col fixo, j varia em from_cell ou to_cell
			var col: int = (from_cell.x * vpu) if slice_index == 0 \
					else (to_cell.x * vpu + vpu - 1)
			for j in vpu:
				positions.append(Vector2i(col, from_cell.y * vpu + j))

		Vector2i(0, -1):   ## NE: row fixo, i varia
			var row: int = (from_cell.y * vpu) if slice_index == 0 \
					else (to_cell.y * vpu + vpu - 1)
			for i in vpu:
				positions.append(Vector2i(from_cell.x * vpu + i, row))

		Vector2i(1, 0):    ## SE: col fixo (extremidade oposta a NW)
			var col: int = (from_cell.x * vpu + vpu - 1) if slice_index == 0 \
					else (to_cell.x * vpu)
			for j in vpu:
				positions.append(Vector2i(col, from_cell.y * vpu + j))

		Vector2i(0, 1):    ## SW: row fixo (extremidade oposta a NE)
			var row: int = (from_cell.y * vpu + vpu - 1) if slice_index == 0 \
					else (to_cell.y * vpu)
			for i in vpu:
				positions.append(Vector2i(from_cell.x * vpu + i, row))

	return positions


## SLICE-02: A-T2 — Render solid blocks at their correct storeys
func _render_solid_blocks(blocks: Array) -> void:
	if blocks.is_empty():
		return
	
	var groups: Dictionary = {}
	for block in blocks:
		var gu_cell: Vector2i = block.get("gu_cell", Vector2i.ZERO)
		var storey: int = int(block.get("storey", 0))
		var material_name: String = block.get("material", "concrete")
		var key := "%d,%d,%s" % [gu_cell.x, gu_cell.y, material_name]
		
		if key not in groups:
			groups[key] = {"gu_cell": gu_cell, "material_name": material_name, "storeys": []}
		groups[key]["storeys"].append(storey)
	
	for key in groups:
		var group = groups[key]
		var gu_cell: Vector2i = group["gu_cell"]
		var material_name: String = group["material_name"]
		var storeys: Array = group["storeys"]
		
		storeys.sort()
		var runs: Array = []
		var current_run: Array = []
		
		for i in range(storeys.size()):
			var storey: int = storeys[i]
			if i == 0:
				current_run.append(storey)
			else:
				var prev_storey: int = storeys[i - 1]
				if storey == prev_storey + 1:
					current_run.append(storey)
				else:
					runs.append(current_run.duplicate())
					current_run = [storey]
		
		if not current_run.is_empty():
			runs.append(current_run)
		
		for run in runs:
			var run_start: int = run[0]
			var run_span: int = run.size()
			_voxel_renderer.render_block(gu_cell, run_start, run_span, material_name)


func _place_wall_voxels(subcube_geometry: Dictionary) -> void:
	## Renderiza arestas de parede como tiles voxel via set_cell() em _voxel_layers[].
	## Substitui _build_wall_containers() (arquivada — NÃO apagar).
	## Sem junction extras ainda — vem em VOXEL-05.
	## Cria WallSlice + VoxelRef; acumula em _voxel_wall_slices.
	if _voxel_tileset == null:
		push_warning("_place_wall_voxels: _voxel_tileset null — correr VOXEL-01/02 primeiro.")
		return

	## Limpar estado anterior
	for layer in _voxel_layers:
		layer.clear()
	_voxel_wall_slices.clear()
	_voxel_junction_extras.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
	if faces.is_empty():
		return

	## Agrupar faces por edge key para obter max_storey por aresta
	var edge_groups: Dictionary = {}
	for face in faces:
		var edge: Dictionary     = face.get("edge", {})
		var from_cell: Vector2i  = Vector2i(edge.get("from", Vector2i.ZERO))
		var to_cell:   Vector2i  = Vector2i(edge.get("to",   Vector2i.ZERO))
		var edge_delta: Vector2i = to_cell - from_cell
		var storey: int          = maxi(0, int(face.get("storey", 0)))
		var key: String = "%d,%d,%d,%d" % [from_cell.x, from_cell.y,
				edge_delta.x, edge_delta.y]
		if not edge_groups.has(key):
			edge_groups[key] = {"from": from_cell, "delta": edge_delta,
				"max_storey": storey}
		else:
			edge_groups[key]["max_storey"] = maxi(
					edge_groups[key]["max_storey"], storey)

	## Colocar voxels: 2 slices por aresta (S0 inner + S1 outer)
	var vpu: int       = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
	if source_id < 0:
		push_warning("_place_wall_voxels: 'voxel_concrete' não encontrado no tileset.")
		return
	var tile_coord := Vector2i(0, 0)

	for key: String in edge_groups:
		var grp: Dictionary      = edge_groups[key]
		var from_cell: Vector2i  = Vector2i(grp["from"])
		var edge_delta: Vector2i = Vector2i(grp["delta"])
		var storey_count: int    = int(grp["max_storey"]) + 1
		var layer_count: int     = storey_count * vpu
		var wall_dir: String     = _edge_delta_to_dir(edge_delta)
		if wall_dir.is_empty():
			continue
		_ensure_voxel_layers(layer_count)

		for si in 2:   ## 0 = inner (S0), 1 = outer (S1)
			var positions: Array[Vector2i] = \
					_voxel_slice_positions(from_cell, edge_delta, si)

			## Colocar tiles em todas as layers verticais
			for level in layer_count:
				for pos in positions:
					_voxel_layers[level].set_cell(pos, source_id, tile_coord)

			## Criar WallSlice + VoxelRefs (ordem posição-maior para o BakeSystem)
			var ws := WallSlice.new()
			ws.id           = "%s_%s_S%d" % [key, wall_dir, si]
			ws.direction    = wall_dir
			ws.slice_index  = si
			ws.gu_cell      = from_cell
			ws.storey_count = storey_count
			for pos in positions:
				for level in layer_count:
					var voxel := VoxelRef.new(pos, level)
					voxel._set_parent_slice(ws)
					ws.voxels.append(voxel)
			_voxel_wall_slices.append(ws)
			_voxel_registry.register_slice(ws)

	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)

	## Aggregate into HighWall instances (VOXEL-06)
	_build_high_walls()
	
	## SLICE-00: measure world-space alignment of voxel plane vs canonical grid
	push_error("[DEBUG] About to call probe, debug_probe_voxel_alignment=%s" % debug_probe_voxel_alignment)
	_debug_probe_voxel_alignment()
	push_error("[DEBUG] Probe complete")


func _debug_probe_voxel_alignment() -> void:
	## SLICE-02: measures world-space delta between the canonical GU diamond and the
	## voxel plane's 8x8 block. Diagnostic for block/voxel layer alignment.
	## Uses corrected formula: adjusted = map_to_local() - half_tile_size
	if not debug_probe_voxel_alignment:
		return
	if _voxel_renderer == null or _voxel_renderer.get_layer(0) == null:
		push_error("[SLICE-02 probe] ABORT: no voxel renderer or layer 0")
		return

	push_error("[SLICE-02 probe] ===== STARTING ALIGNMENT CHECK =====")

	# Find a floor layer cell that exists
	var floor_cell = Vector2i.ZERO
	var floor_found = false
	for x in range(-5, 10):
		for y in range(-5, 10):
			if floor_layer.get_cell_source_id(Vector2i(x, y)) != -1:
				floor_cell = Vector2i(x, y)
				floor_found = true
				break
		if floor_found: break

	if not floor_found:
		print("[SLICE-02 probe] ABORT: no floor tile found")
		return

	var floor_ts = floor_layer.tile_set
	var floor_tile_size = floor_ts.tile_size
	var floor_half_size = Vector2(floor_tile_size) / 2.0

	var vlayer = _voxel_renderer.get_layer(0)
	var voxel_ts = vlayer.tile_set
	var voxel_tile_size = voxel_ts.tile_size
	var voxel_half_size = Vector2(voxel_tile_size) / 2.0

	## Corrected formula: adjusted = map_to_local - half_tile_size
	var floor_map = floor_layer.map_to_local(floor_cell)
	var floor_adjusted = floor_map - floor_half_size

	var voxel_cell = floor_cell * 8
	var voxel_map = vlayer.map_to_local(voxel_cell)
	var voxel_adjusted = voxel_map - voxel_half_size

	## Compare adjusted positions
	var canon_pos = floor_adjusted + VISUAL_GRID_OFFSET
	var voxel_pos = voxel_adjusted + vlayer.position
	var delta = voxel_pos - canon_pos

	push_error("[SLICE-02 probe] floor_cell = %s  voxel_cell = %s" % [floor_cell, voxel_cell])
	push_error("[SLICE-02 probe] floor_map=%s  voxel_map=%s" % [floor_map, voxel_map])
	push_error("[SLICE-02 probe] floor_adjusted=%s  voxel_adjusted=%s" % [floor_adjusted, voxel_adjusted])
	push_error("[SLICE-02 probe] canon_pos=%s  voxel_pos=%s  delta=%s px" % [canon_pos, voxel_pos, delta])

	## I2: Check painted voxels for solid blocks
	if _base_layout.is_empty():
		return

	var structure_tiles: Array = _base_layout.get("structure_tiles", [])
	var block_found = false
	var block_cell = Vector2i.ZERO

	for entry in structure_tiles:
		var tile_name: String = entry.get("tile_name", "")
		if tile_name.begins_with("block_"):
			block_cell = entry.get("cell", Vector2i.ZERO)
			block_found = true
			break

	if not block_found:
		push_error("[SLICE-02 probe] INFO: no block_* tile found for footprint check")
		return

	push_error("[SLICE-02 probe] === Block Footprint Check ===")
	push_error("[SLICE-02 probe] block_cell (GU coords) = %s" % block_cell)

	## Get expected voxel positions for this GU
	var GeometryCoordinatesClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
	var expected_voxels: Array[Vector2i] = GeometryCoordinatesClass.gu_voxels(block_cell)

	## Check which voxel cells are actually painted at voxel layer 0
	var painted_voxels: Array[Vector2i] = []
	for vx in expected_voxels:
		if vlayer.get_cell_source_id(vx) != -1:
			painted_voxels.append(vx)

	push_error("[SLICE-02 probe] expected voxel count = %d" % expected_voxels.size())
	push_error("[SLICE-02 probe] painted voxel count = %d" % painted_voxels.size())

	if painted_voxels.size() == expected_voxels.size():
		push_error("[SLICE-02 probe] result = MATCH (all expected voxels painted)")
	else:
		push_error("[SLICE-02 probe] result = MISMATCH")
		var missing: Array[Vector2i] = []
		for ev in expected_voxels:
			if not painted_voxels.has(ev):
				missing.append(ev)
		if missing.size() > 0:
			push_error("[SLICE-02 probe] missing voxels: %s" % missing)


func _build_high_walls() -> void:
	## Build HighWall aggregates from WallSlices.
	## Grouping strategy: 1 HighWall per unique (edge_from, direction).
	## Multiple storeys on the same edge group into one HighWall.
	var hw_groups: Dictionary = {}  # (from_cell_str, direction) → Array[WallSlice]

	for slice in _voxel_wall_slices:
		var key: String = "%s_%s" % [slice.gu_cell, slice.direction]
		if not hw_groups.has(key):
			hw_groups[key] = []
		hw_groups[key].append(slice)

	## Create HighWall for each group
	for group_key: String in hw_groups:
		var slices: Array = hw_groups[group_key]
		var hw := HighWallClass.new()
		hw.id = "HW_%s" % group_key.replace(" ", "_")
		
		## Set parent references for dirty propagation (VOXEL-07)
		for slice in slices:
			slice._set_parent_hw(hw)
		
		hw.slices = slices
		hw.junction_extras = []
		hw.baked = false
		hw.dirty_count = 0
		_voxel_registry.register_high_wall(hw)


func _build_voxel_junction_extras(edge_groups: Dictionary) -> void:
	## Detecta corners de vértice não cobertos por nenhum outer slice e coloca
	## uma coluna extra de voxel. Um corner está descoberto quando as suas 2 arestas
	## cobertas estão AMBAS ausentes do edge_groups.
	## Dual-key: cada aresta física pode ser representada por qualquer dos 2 lados.
	## Ver VOXEL_MASTER_PLAN.md §5 e DIRECTION_GLOSSARY.md §5.
	if _voxel_tileset == null:
		return
	var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
	if source_id < 0:
		return
	var tile_coord := Vector2i(0, 0)
	var vpu: int = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS   ## 8

	## Recolher todos os vértices tocados por arestas presentes
	var vertices: Dictionary = {}
	for key: String in edge_groups:
		var from_cell: Vector2i = Vector2i(edge_groups[key]["from"])
		var delta: Vector2i     = Vector2i(edge_groups[key]["delta"])
		match delta:
			Vector2i(-1,  0):  ## NW: aresta esquerda
				vertices[from_cell] = true
				vertices[from_cell + Vector2i(0, 1)] = true
			Vector2i( 1,  0):  ## SE: aresta direita
				vertices[from_cell + Vector2i(1, 0)] = true
				vertices[from_cell + Vector2i(1, 1)] = true
			Vector2i( 0, -1):  ## NE: aresta topo
				vertices[from_cell] = true
				vertices[from_cell + Vector2i(1, 0)] = true
			Vector2i( 0,  1):  ## SW: aresta base
				vertices[from_cell + Vector2i(0, 1)] = true
				vertices[from_cell + Vector2i(1, 1)] = true

	## Para cada vértice, verificar os 4 corners diagonais
	for vtx: Vector2i in vertices:
		var vx: int = vtx.x
		var vy: int = vtx.y

		## As 4 arestas físicas do vértice, cada uma checável por 2 chaves
		## (a aresta pode ser emitida pelo mapa de qualquer um dos lados adjacentes).
		var eA_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy,    0, -1],   ## NE de GU(vx,vy)
			"%d,%d,%d,%d" % [vx,   vy-1,  0,  1]]   ## SW de GU(vx,vy-1)
		var eB_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy,   -1,  0],   ## NW de GU(vx,vy)
			"%d,%d,%d,%d" % [vx-1, vy,    1,  0]]   ## SE de GU(vx-1,vy)
		var eC_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx-1, vy,    0, -1],   ## NE de GU(vx-1,vy)
			"%d,%d,%d,%d" % [vx-1, vy-1,  0,  1]]   ## SW de GU(vx-1,vy-1)
		var eD_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy-1, -1,  0],   ## NW de GU(vx,vy-1)
			"%d,%d,%d,%d" % [vx-1, vy-1,  1,  0]]   ## SE de GU(vx-1,vy-1)

		var eA: bool = _has_any(edge_groups, eA_keys)
		var eB: bool = _has_any(edge_groups, eB_keys)
		var eC: bool = _has_any(edge_groups, eC_keys)
		var eD: bool = _has_any(edge_groups, eD_keys)

		if not (eA or eB or eC or eD):
			continue   ## nenhuma aresta neste vértice

		## storey_count: máximo de todas as arestas presentes neste vértice
		var sc: int = _max_storey_of(edge_groups,
				eA_keys + eB_keys + eC_keys + eD_keys)

		## GU_TL corner — coberto por eC ou eD
		if not (eC or eD):
			_add_junction_extra(
				Vector2i((vx-1)*vpu + vpu-1, (vy-1)*vpu + vpu-1),
				sc, source_id, tile_coord)

		## GU_BR corner — coberto por eA ou eB
		if not (eA or eB):
			_add_junction_extra(
				Vector2i(vx*vpu, vy*vpu),
				sc, source_id, tile_coord)

		## GU_BL corner — coberto por eB ou eC
		if not (eB or eC):
			_add_junction_extra(
				Vector2i((vx-1)*vpu + vpu-1, vy*vpu),
				sc, source_id, tile_coord)

		## GU_TR corner — coberto por eA ou eD
		if not (eA or eD):
			_add_junction_extra(
				Vector2i(vx*vpu, (vy-1)*vpu + vpu-1),
				sc, source_id, tile_coord)


func _tic_voxel_system() -> void:
	if _voxel_renderer != null and _edge_registry != null:
		_voxel_renderer.process_dirty(_edge_registry)
		return   ## <-- do not fall through to the legacy dirty loop
	
	## Legacy path — only reached if the new system was never wired for this room
	## (mirrors the elif in _build_room; should not happen on any current map).
	if _voxel_registry == null:
		return

	for hw in _voxel_registry.all_high_walls():
		if hw.dirty_count == 0:
			continue
		
		for slice in hw.slices:
			if slice.dirty_count == 0:
				continue
			_process_voxel_slice(slice)
		
		for extra in hw.junction_extras:
			if extra.dirty:
				_apply_voxel_state(extra)
				extra.clear_dirty()
		
		hw.clear_dirty()


func _process_voxel_slice(slice: WallSlice) -> void:
	## Iterate slice voxels; apply state changes for dirty ones.
	for voxel in slice.voxels:
		if not voxel.dirty:
			continue
		_apply_voxel_state(voxel)
		voxel.clear_dirty()
	slice.dirty_count = 0


func _apply_voxel_state(voxel: VoxelRef) -> void:
	## Render or erase voxel based on visible + damage_state.
	## Renders: visible AND damage_state < DESTROYED
	## Erases: not visible OR damage_state == DESTROYED
	var layer := _voxel_layers[voxel.level]
	if voxel.visible and voxel.damage_state < VoxelRefClass.DAMAGE_DESTROYED:
		## Render voxel at the face_atlas_rect coordinates
		var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
		var tile_coord: Vector2i = voxel.face_atlas_rect.position
		layer.set_cell(voxel.grid_pos, source_id, tile_coord)
	else:
		## Erase voxel (either invisible or destroyed)
		layer.erase_cell(voxel.grid_pos)


func _has_any(edge_groups: Dictionary, keys: Array[String]) -> bool:
	## Retorna true se alguma das chaves existir em edge_groups.
	for k: String in keys:
		if edge_groups.has(k):
			return true
	return false


func _max_storey_of(edge_groups: Dictionary, keys: Array[String]) -> int:
	## Retorna o max storey_count das arestas presentes na lista de chaves.
	var sc: int = 1
	for k: String in keys:
		if edge_groups.has(k):
			sc = maxi(sc, int(edge_groups[k]["max_storey"]) + 1)
	return sc


func _add_junction_extra(voxel_pos: Vector2i, storey_count: int,
		source_id: int, tile_coord: Vector2i) -> void:
	## Coloca 1 coluna voxel extra num corner de V-junction descoberto.
	## Regista VoxelRefs em _voxel_junction_extras para TIC e BakeSystem.
	var layer_count: int = storey_count * SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	_ensure_voxel_layers(layer_count)
	for level in layer_count:
		_voxel_layers[level].set_cell(voxel_pos, source_id, tile_coord)
	for level in layer_count:
		_voxel_junction_extras.append(VoxelRef.new(voxel_pos, level))


func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
		if is_instance_valid(wc):
			wc.hide()
			wc.queue_free()
	_wall_containers.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
	if faces.is_empty():
		return

	var atom_image: Image = Image.load_from_file(
		"res://ASSETS/ISOMETRIC/source_assets/subcubes/subcube_concrete.png"
	)
	if atom_image == null:
		push_warning("WallContainer: atom image not found.")
		return

	if _subcube_layers.is_empty():
		push_warning("WallContainer: subcube layers not initialized.")
		return
	var ref_layer: TileMapLayer = _subcube_layers[0]

	## ── Agrupar faces por (from_cell, wall_dir) ─────────────────────────────────
	## Cada grupo = 1 WallContainer com todos os storeys dessa face.
	var face_groups: Dictionary = {}   ## key → {face_subcells, wall_dir, max_storey}

	for face: Dictionary in faces:
		var edge: Dictionary   = face.get("edge", {})
		var from_cell: Vector2i = Vector2i(edge.get("from", Vector2i.ZERO))
		var to_cell:   Vector2i = Vector2i(edge.get("to",   Vector2i.ZERO))
		var edge_delta: Vector2i = to_cell - from_cell
		var wall_dir: String   = _edge_delta_to_dir(edge_delta)
		if wall_dir.is_empty():
			continue
		var storey: int = maxi(0, int(face.get("storey", 0)))

		var key: String = "%d,%d,%s" % [from_cell.x, from_cell.y, wall_dir]

		if not face_groups.has(key):
			face_groups[key] = {
				"face_subcells": _subcubes_on_edge(from_cell, edge_delta),
				"wall_dir":      wall_dir,
				"max_storey":    storey,
			}
		else:
			face_groups[key]["max_storey"] = maxi(
					face_groups[key]["max_storey"], storey)

	## ── Criar 1 WallContainer por grupo ────────────────────────────────────────
	for key: String in face_groups:
		var grp: Dictionary  = face_groups[key]
		var storey_count: int = grp["max_storey"] + 1
		var wc := WallContainerClass.new()
		wc.build(ref_layer, atom_image,
				grp["face_subcells"], grp["wall_dir"], storey_count)
		add_child(wc)
		_wall_containers.append(wc)

	## ── Corner fills ────────────────────────────────────────────────────────
	## Offsets de corner fill = média dos FACE_CENTER_OFFSETs das duas faces
	## adjacentes no subcubo compartilhado. Ver DIRECTION_GLOSSARY.md §5.
	const _FILL_OFFSET: Dictionary = {
		"NE_NW": Vector2(  0.0, 36.0),   ## sort: NE < NW
		"NW_SW": Vector2(-16.0, 36.0),   ## sort: NW < SW
		"NE_SE": Vector2( 16.0, 36.0),   ## sort: NE < SE
		"SE_SW": Vector2(  0.0, 36.0),   ## sort: SE < SW
	}

	## Subcubo local compartilhado por corner (em coords de subcubo relativos à origin).
	## Y-varying (NW/SE): contribui com x. X-varying (NE/SW): contribui com y.
	const _FILL_SHARED_LOCAL: Dictionary = {
		"NE_NW": Vector2i(0, 0),   ## sort: NE < NW
		"NW_SW": Vector2i(0, 3),   ## sort: NW < SW  (inalterado)
		"NE_SE": Vector2i(3, 0),   ## sort: NE < SE
		"SE_SW": Vector2i(3, 3),   ## sort: SE < SW  (inalterado)
	}

	## Agrupar dirs por cell (em UNIT coords) para detectar corners (2 faces).
	var cell_dirs: Dictionary = {}  ## "x,y" → {unit, dirs[], max_storey}

	for key: String in face_groups:
		var grp: Dictionary = face_groups[key]
		var unit: Vector2i  = Vector2i()
		# Extrair unit da key (formato: "x,y,dir")
		var parts: PackedStringArray = key.split(",")
		if parts.size() >= 2:
			unit = Vector2i(int(parts[0]), int(parts[1]))
		else:
			continue

		var cell_key: String = "%d,%d" % [unit.x, unit.y]
		if not cell_dirs.has(cell_key):
			cell_dirs[cell_key] = {"unit": unit, "dirs": [], "max_storey": 0}
		cell_dirs[cell_key]["dirs"].append(grp["wall_dir"])
		cell_dirs[cell_key]["max_storey"] = maxi(
				cell_dirs[cell_key]["max_storey"], grp["max_storey"])

	## Criar 1 corner fill por célula com 2 faces (corner cell).
	for cell_key: String in cell_dirs:
		var cd: Dictionary = cell_dirs[cell_key]
		if cd["dirs"].size() != 2:
			continue  ## não é corner

		## Ordenar dirs para obter key canônica do dict de fill.
		var sorted_dirs: Array = cd["dirs"].duplicate()
		sorted_dirs.sort()
		var fill_key: String = "%s_%s" % [sorted_dirs[0], sorted_dirs[1]]

		if not _FILL_OFFSET.has(fill_key):
			push_warning("WallContainer: corner fill key não reconhecida: %s" % fill_key)
			continue

		## Subcubo compartilhado em coords de subcubo absolutos.
		var unit: Vector2i    = cd["unit"]
		var origin: Vector2i  = SubcubeCoordsClass.unit_to_subcube_origin(unit)
		var local: Vector2i   = _FILL_SHARED_LOCAL[fill_key]
		var shared_sc: Vector2i = origin + local

		var fill_off: Vector2   = _FILL_OFFSET[fill_key]
		var storey_count: int   = cd["max_storey"] + 1

		var wc_fill := WallContainerClass.new()
		wc_fill.build_corner_fill(ref_layer, atom_image, shared_sc, fill_off, storey_count)
		add_child(wc_fill)
		_wall_containers.append(wc_fill)


func _subcubes_on_edge(unit: Vector2i, edge_delta: Vector2i) -> Array[Vector2i]:
	## Returns the 4 subcubes along the specified edge of a gameplay unit.
	## edge_delta tells which direction (sistema vértice-alinhado):
	## (-1,0)=NW(cima-esq), (0,-1)=NE(cima-dir), (1,0)=SE(baixo-dir), (0,1)=SW(baixo-esq).
	var origin: Vector2i = SubcubeCoordsClass.unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []

	if edge_delta == Vector2i(-1, 0):  # NW edge — left col (x=0, y-varying)
		for j in SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(0, j))
	elif edge_delta == Vector2i(0, -1):  # NE edge — top row (y=0, x-varying)
		for i in SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, 0))
	elif edge_delta == Vector2i(1, 0):  # SE edge — right col (x=3, y-varying)
		for j in SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(3, j))
	elif edge_delta == Vector2i(0, 1):  # SW edge — bottom row (y=3, x-varying)
		for i in SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, 3))

	return out


func _edge_delta_to_dir(delta: Vector2i) -> String:
	## Converte edge_delta → sufixo de face (sistema vértice-alinhado, N=topo).
	## NW=cima-esq(-1,0) | NE=cima-dir(0,-1) | SE=baixo-dir(+1,0) | SW=baixo-esq(0,+1)
	## Ver DIRECTION_GLOSSARY.md §3.
	match delta:
		Vector2i(-1,  0): return "NW"
		Vector2i( 0, -1): return "NE"
		Vector2i( 1,  0): return "SE"
		Vector2i( 0,  1): return "SW"
	return ""


func _paint_subcube_descriptor(desc: Dictionary, source_id: int, layer_count: int) -> void:
	var base_cell: Vector2i = INVALID_CELL
	var edge_delta: Vector2i = INVALID_CELL
	var is_wall_face: bool = false

	if desc.has("unit"):
		base_cell = Vector2i(desc["unit"])
	elif desc.has("edge"):
		var edge: Dictionary = desc["edge"]
		base_cell = Vector2i(edge.get("from", INVALID_CELL))
		var to_cell: Vector2i = Vector2i(edge.get("to", INVALID_CELL))
		edge_delta = to_cell - base_cell
		is_wall_face = true
	else:
		return

	## Seleciona tile: variante direcional para faces de parede, base para blocos.
	var active_source_id: int = source_id  ## fallback = tile base passado pelo caller
	if is_wall_face:
		var dir: String = _edge_delta_to_dir(edge_delta)
		if dir != "":
			var tile_name := "subcube_concrete_%s" % dir
			var dir_id: int = _subcube_tile_ids.get(tile_name, -1)
			if dir_id >= 0:
				active_source_id = dir_id

	var storey: int = maxi(0, int(desc.get("storey", 0)))
	var footprint: Array[Vector2i] = SubcubeCoordsClass.unit_subcubes(base_cell)

	## Wall faces paint only subcubes along the edge; solid blocks fill the footprint
	if is_wall_face:
		footprint = _subcubes_on_edge(base_cell, edge_delta)

	for local_level in range(SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS):
		var layer_index := storey * SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS + local_level
		if layer_index < 0 or layer_index >= layer_count:
			continue
		var layer := _subcube_layers[layer_index]
		for subcell in footprint:
			layer.set_cell(subcell, active_source_id, Vector2i(0, 0))


func _build_room(layout: Dictionary) -> void:
	floor_layer.clear()
	structure_wall_layer.clear()
	structure_layer.clear()
	for layer in _wall_upper_layers:
		layer.clear()
		layer.visible = true
	for layer in _subcube_layers:
		layer.clear()
		layer.visible = true

	var floor_tile_name := String(layout.get("floor_tile_name", "floor_SE"))
	## Fills exactly the MAP_SIZE grid. The 5-tile buffer in the layout builder
	## replaces the old negative extension — no coordinates outside the range [0, MAP_SIZE).
	for x in range(0, _room_size.x):
		for y in range(0, _room_size.y):
			_place(Vector2i(x, y), floor_tile_name)

	## Subcube render plane: wall/block descriptors become stacked subcube presence.
	## The old wall-storey layers remain as a fallback path, but the active render
	## now comes from the seam's subcube geometry.
	
	## SLICE-02: New geometry module integration — edges → slices → voxels
	var extraction: Dictionary = EdgeExtractor.extract(layout)
	var subcube_geometry: Dictionary = layout.get("subcube_geometry", {})
	
	if not extraction.get("edges", []).is_empty():
		## New geometry path — the only active renderer when it has data.
		_edge_registry = EdgeRegistry.new()
		SliceGenerator.generate(extraction["edges"], _edge_registry)
		_junction_columns = JunctionResolver.resolve(_edge_registry)
		_voxel_renderer.clear()
		_voxel_renderer.render(_edge_registry, _junction_columns)
		_render_solid_blocks(extraction.get("solid_blocks", []))
		structure_wall_layer.visible = false
		for layer in _wall_upper_layers:
			layer.visible = false
	
	elif not subcube_geometry.is_empty() and _subcube_tileset != null:
		## Legacy subcube path — only reached if the new extractor found nothing
		## (should not happen on any current map; kept as a safety fallback until
		## Stage B, per the original SLICE-01/02 plan).
		var max_floors: int = maxi(1, int(layout.get("max_floors", 1)))
		if _voxel_registry == null:
			_voxel_registry = VoxelRegistryClass.new()
			_voxel_registry.setup(max_floors * SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS)
		_render_subcube_geometry(subcube_geometry, max_floors)   ## blocos sólidos (TileMapLayer)
		_place_wall_voxels(subcube_geometry)                     ## VOXEL-04: faces de parede (voxels)
		structure_wall_layer.visible = false
		for layer in _wall_upper_layers:
			layer.visible = false
	
	else:
		## Oldest fallback: wall_levels painted directly (pre-VOXEL-01 era).
		var wall_levels: Array = layout.get("wall_levels", [layout.get("wall_tiles", [])])
		_ensure_wall_upper_layers(maxi(0, wall_levels.size() - 1))
		for layer in _wall_upper_layers:
			layer.clear()
			layer.visible = true
		structure_wall_layer.visible = true
		for level in range(wall_levels.size()):
			var target: TileMapLayer = structure_wall_layer if level == 0 else _wall_upper_layers[level - 1]
			for entry in wall_levels[level]:
				var tile_name: String = String(entry.get("tile_name", ""))
				## Wall tiles são renderizadas por WallContainers — pular aqui.
				if tile_name.begins_with("wall_"):
					continue
				_place(entry.get("cell", INVALID_CELL), tile_name, target)

	## Props: base sprite on structure_layer; stacks render extra sprites on prop-stack
	## layers offset up by the crate body step (visual stacking). The taller stack also
	## drives a longer real shadow via _prop_heights (see _cache_blocked_cells).
	var max_stack := 1
	for structure_entry in layout.get("structure_tiles", []):
		max_stack = maxi(max_stack, int(structure_entry.get("stack", 1)))
	_ensure_prop_stack_layers(maxi(0, max_stack - 1))
	for stack_layer in _prop_stack_layers:
		stack_layer.clear()
	for structure_entry in layout.get("structure_tiles", []):
		var cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var tile_name := String(structure_entry.get("tile_name", ""))
		_place(cell, tile_name, structure_layer)
		var stack: int = maxi(1, int(structure_entry.get("stack", 1)))
		for level in range(1, stack):
			_place(cell, tile_name, _prop_stack_layers[level - 1])

	_cache_blocked_cells(layout)


func _cache_blocked_cells(layout: Dictionary) -> void:
	_blocked_cells.clear()
	for cell in layout.get("blocked_cells", []):
		_blocked_cells[cell] = true
	## Per-prop shadow heights (rotated cell → height class 1-4) from structure_tiles.
	## Consumed by LightingController._setup_tile_semantics so stacked props cast taller
	## (longer) shadows. Built here so it follows perspective rotation with the layout.
	_prop_heights.clear()
	for entry in layout.get("structure_tiles", []):
		if entry is Dictionary and entry.has("height"):
			_prop_heights[Vector2i(entry["cell"])] = int(entry["height"])
	## Segment exits — used by the purple overlay in _draw()
	_exit_cells.clear()
	for raw in layout.get("exit_cells", []):
		_exit_cells.append(Vector2i(raw))
	## Active (perspective-rotated) map lights — consumed by LightingController.
	_current_light_sources = layout.get("light_sources", [])
	print("[Room] Cache: %d blocked_cells, %d exit_cells, %d lights" % [
		_blocked_cells.size(), _exit_cells.size(), _current_light_sources.size()])
	print("[Room] Border check: (0,0)=%s (17,0)=%s (0,35)=%s (17,35)=%s (9,0)=%s (9,35)=%s" % [
		_blocked_cells.has(Vector2i(0,0)), _blocked_cells.has(Vector2i(17,0)),
		_blocked_cells.has(Vector2i(0,35)), _blocked_cells.has(Vector2i(17,35)),
		_blocked_cells.has(Vector2i(9,0)), _blocked_cells.has(Vector2i(9,35))
	])


## M2-13: Quantized isometric directions (8 directions)
const SHADOW_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const SHADOW_LENGTH_MAX := 5


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

	for key in ["wall_tiles", "structure_tiles"]:
		var src: Array = layout.get(key, [])
		var dst: Array = []
		for entry in src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = _cell_from_base(out.get("cell", INVALID_CELL), direction, base_size)
			out["tile_name"] = _remap_tile_name_for_perspective(String(out.get("tile_name", "")), direction)
			dst.append(out)
		mapped[key] = dst

	## Rotate every wall storey (wall_levels[f]); wall_tiles above stays == wall_levels[0].
	var rotated_levels: Array = []
	for level_src in layout.get("wall_levels", []):
		var level_dst: Array = []
		for entry in level_src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = _cell_from_base(out.get("cell", INVALID_CELL), direction, base_size)
			out["tile_name"] = _remap_tile_name_for_perspective(String(out.get("tile_name", "")), direction)
			level_dst.append(out)
		rotated_levels.append(level_dst)
	mapped["wall_levels"] = rotated_levels
	mapped["subcube_geometry"] = SubcubeGeometryClass.build(mapped)

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

	## Exit markers rotate with the room.
	var exit_cells: Array[Vector2i] = []
	for cell in layout.get("exit_cells", []):
		exit_cells.append(_cell_from_base(cell, direction, base_size))
	mapped["exit_cells"] = exit_cells

	## Map lights rotate by cell; directional/cone lights also rotate their angle
	## by the same quarter-turn so the cone covers the same (rotated) cells.
	var angle_delta_deg := _perspective_angle_delta_deg(direction)
	var light_sources: Array = []
	for light in layout.get("light_sources", []):
		var out := (light as Dictionary).duplicate(true)
		var rotated := _cell_from_base(Vector2i(int(out.get("x", 0)), int(out.get("y", 0))), direction, base_size)
		out["x"] = rotated.x
		out["y"] = rotated.y
		if out.has("direction_deg"):
			out["direction_deg"] = fmod(float(out["direction_deg"]) + angle_delta_deg + 360.0, 360.0)
		light_sources.append(out)
	mapped["light_sources"] = light_sources
	return mapped


## Quarter-turn applied to directional light angles, matching `_cell_from_base`.
func _perspective_angle_delta_deg(direction: String) -> float:
	match direction:
		"E": return 90.0
		"S": return 180.0
		"W": return -90.0
		_: return 0.0


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




func _process(_delta: float) -> void:
	# Update temporal lighting effects (flicker, pulse, rotation)
	_update_temporal_lights(_delta)
	
	_update_vision_fog()
	if _has_moving_guards():
		_update_enemy_visibility()


## Update temporal state for all lights and trigger rebuilds if needed (L-IMP-06)
func _update_temporal_lights(delta: float) -> void:
	if _lighting_controller == null:
		return
	
	var light_registry = _lighting_controller.get_light_registry()
	if light_registry == null:
		return
	
	var changed_lights: Array = light_registry.update_temporal_all(delta)
	
	# If any lights changed this frame, trigger rebuild via LightingController
	if changed_lights.size() > 0:
		_lighting_controller.rebuild_deferred()


func _has_moving_guards() -> bool:
	for guard in _guards:
		if is_instance_valid(guard) and guard.is_moving:
			return true
	return false


## Update the distance-fog shader uniforms every frame so the gradient tracks
## the agent's screen position and scales correctly with zoom and viewport size.
func _update_vision_fog() -> void:
	if _fow_controller == null:
		return
	
	var agent_world := agent.global_position
	var canvas_t    := get_viewport().get_canvas_transform()
	var vp_size     := get_viewport().get_visible_rect().size
	var screen_px   := canvas_t * agent_world
	var screen_uv   := screen_px / vp_size
	var zoom        := camera.zoom.x
	var vision_r_tiles := float(VISION_TILE_RADIUS + vision_bonus_tiles)
	
	_fow_controller.update_vision_center(agent_world, screen_uv, vision_r_tiles, zoom, vp_size)


## Unified input: keyboard · wheel zoom · motion drag.
## Camera input handled first; if CameraController consumes it, done.
func _input(event: InputEvent) -> void:
	## Camera has priority
	if _camera_controller and _camera_controller.handle_input(event):
		return
	
	## Keyboard gameplay input
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_F2:
					_toggle_map_loader_panel()
					return
				KEY_Z:
					## Z lowers: STANDING -> CROUCHING -> PRONE
					var next_z := agent.posture
					if agent.posture == DebugAgent.Posture.STANDING:
						next_z = DebugAgent.Posture.CROUCHING
					elif agent.posture == DebugAgent.Posture.CROUCHING:
						next_z = DebugAgent.Posture.PRONE
					
					if next_z != agent.posture:
						_try_change_posture(next_z)
					return
				KEY_X:
					## X raises: PRONE -> CROUCHING -> STANDING
					var next_x := agent.posture
					if agent.posture == DebugAgent.Posture.PRONE:
						next_x = DebugAgent.Posture.CROUCHING
					elif agent.posture == DebugAgent.Posture.CROUCHING:
						next_x = DebugAgent.Posture.STANDING
					
					if next_x != agent.posture:
						_try_change_posture(next_x)
					return
				KEY_V:
					_vision_controller.toggle_dev()
					return
				KEY_L:
					_vision_controller.toggle_light()
					return
				KEY_H:
					_vision_controller.toggle_heat()
					return
				KEY_K:
					## Cycle UI language (debug helper for localization).
					## Dynamic lookup so it resolves regardless of autoload indexing.
					var localization: Variant = get_node_or_null("/root/Localization")
					if localization:
						localization.cycle_language()
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

	## ── Mouse motion: preview path on hover ─────────────────────────────
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var new_hover := _screen_to_tile(mm.position)
		if new_hover != _hovered_cell:
			_hovered_cell = new_hover
			if _vision_controller.dev_vision:
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


## Left mouse: only runs when no GUI Control consumed the event first.
## This lets HUD buttons work while still handling pan + tile selection.
func _unhandled_input(event: InputEvent) -> void:
	## Screenshot hotkey (Shift+P only)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P and event.shift_pressed:
			_capture_screenshot_to_file()
			get_viewport().set_input_as_handled()
			return

	if turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton

	## ── Right button: execute movement to the selected tile ──────
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if _selected_cell != INVALID_CELL and _selected_cell != agent.cell:
			_try_move_to(_selected_cell)
		get_viewport().set_input_as_handled()
		return

	## ── Left button: click to select (camera pan delegated to CameraController) ──────────
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mb.pressed:
		## Left mouse released: check if it was just a click (not a drag handled by CameraController)
		var cell := _screen_to_tile(mb.position)

		## UI-02: If clicking outside the zone, just select (no move)
		if cell != INVALID_CELL:
			_set_selected_cell(cell)


func _capture_screenshot_to_file() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Failed to capture screenshot")
		return

	## Salva em REFERENCES/Screenshots/ dentro do diretório do projeto (res://).
	## Mais acessível que user:// (app-data do Godot).
	var project_root := ProjectSettings.globalize_path("res://")
	var absolute_screenshots_dir := project_root + "REFERENCES/Screenshots"
	DirAccess.make_dir_absolute(absolute_screenshots_dir)

	## Generate filename with timestamp
	var timestamp := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		timestamp["year"],
		timestamp["month"],
		timestamp["day"],
		timestamp["hour"],
		timestamp["minute"],
		timestamp["second"],
	]
	var filename := "%s/screenshot_%s.png" % [absolute_screenshots_dir, date_str]

	## Save PNG
	var error := image.save_png(filename)
	if error != OK:
		push_error("Failed to save screenshot: %s (error code: %d)" % [filename, error])
		return

	var short_name := filename.get_file()
	print("Screenshot saved: %s" % filename)
	_show_screenshot_toast("💾 %s" % short_name)


## Exibe uma mensagem temporária no HUD (CanvasLayer $HUD).
## Aparece no canto inferior-esquerdo e desvanece em 2 s.
func _show_screenshot_toast(message: String) -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return

	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_bottom = -24.0
	lbl.offset_left   =  16.0
	hud.add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)
