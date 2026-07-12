extends Node2D
## Tactical room controller: input, UI wiring, agent turns and scene setup.

const MapCatalogClass    = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass   = preload("res://godot/scripts/world/maps/map_compiler.gd")
const LevelGraphClass    = preload("res://godot/scripts/world/level_graph.gd")
const GuardEnemyClass    = preload("res://godot/scripts/agents/guard_enemy.gd")
const GuardNoiseIndicatorClass = preload("res://godot/scripts/overlays/guard_noise_indicator.gd")
const CeilingPropOverlayClass = preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")
const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")
const DebugToolsControllerClass = preload("res://godot/scripts/world/controllers/debug_tools_controller.gd")
const InputControllerClass = preload("res://godot/scripts/world/controllers/input_controller.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const SelectionControllerClass = preload("res://godot/scripts/world/controllers/selection_controller.gd")
const WorldMarkersOverlayControllerClass = preload("res://godot/scripts/world/controllers/world_markers_overlay_controller.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const TurnControllerClass = preload("res://godot/scripts/world/controllers/turn_controller.gd")
const ShadowBoundaryOverlayClass = preload("res://godot/scripts/overlays/shadow_boundary_overlay.gd")
const LightRayOverlayClass = preload("res://godot/scripts/overlays/light_ray_overlay.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const VisionControllerClass = preload("res://godot/scripts/controllers/vision_controller.gd")
const HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
const LightingControllerClass = preload("res://godot/scripts/controllers/lighting_controller.gd")
const CameraControllerClass = preload("res://godot/scripts/controllers/camera_controller.gd")
const FowControllerClass = preload("res://godot/scripts/controllers/fow_controller.gd")
const GuardCoordinatorClass = preload("res://godot/scripts/controllers/guard_coordinator.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const DevVisionStatusPanelClass = preload("res://godot/scripts/debug/dev_vision_status_panel.gd")

## SLICE-02: Geometry module (Edge → Slice → Voxel pipeline)
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
const SliceGeneratorClass = preload("res://godot/scripts/geometry/slice_generator.gd")
const JunctionResolverClass = preload("res://godot/scripts/geometry/junction_resolver.gd")
const EdgeRegistryClass = preload("res://godot/scripts/geometry/edge_registry.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

## OCC-01: Occlusion system (geometry occlusion set, view-space computation)
const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const OcclusionOverlayClass = preload("res://godot/scripts/overlays/occlusion_overlay.gd")

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var turn_manager:        TacticalTurnManager = $TurnManager
@onready var enemy_phase_controller: EnemyPhaseController = $EnemyPhaseController
@onready var enemies_root:         Node2D       = $Enemies
@onready var movement_overlay:    MovementOverlay = $MovementOverlay
@onready var path_preview:        PathPreview  = $PathPreview
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
@onready var btn_view_h:          Button       = $HUD/TopBar/Row/BtnViewH
@onready var btn_view_l:          Button       = $HUD/TopBar/Row/BtnViewL
@onready var btn_view_v:          Button       = $HUD/TopBar/Row/BtnViewV
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

## Wall storeys (N-floor stacking). Walls are VOXELS, not sprites: VoxelRenderer creates one
## TileMapLayer per voxel level, z_index = WALL_BASE_Z_INDEX + level. WALL_FLOOR_STEP_PX is the
## per-storey height in px. Reserve z=100 band for a future overhead ceiling/light layer
## (below noise at z=140).
##
## The old sprite path (StructureWallLayer + runtime _wall_upper_layers) was deleted on
## 2026-07-12: the layers were created, cleared and then hidden on every build, and nothing
## was ever placed into them. Do not recreate them — see docs/technical/ASSET_MAP.md.
const WALL_BASE_Z_INDEX := 10
## One storey = the cube's side-face height. Measured from the art: opaque block height 286 −
## top-diamond 128 = 158 px (block_SE and wall_NE — sistema vértice-alinhado).
## Upper courses stack on this step so a cube seats exactly on the one below. Tunable.
const WALL_FLOOR_STEP_PX := 158.0
var _wall_tileset: TileSet = null

## Voxel render plane (VOXEL series): 1 storey = 8 voxel rows, each steps 20 px.
## 20 = 1.25 × VOXEL_TILE_SIZE.y (16). Must match generate_voxel.py SIDE_H.
## Invariant: storey height (160 px) consistency across voxel stack rendering. ✓
const VOXEL_STEP_PX: float = 20.0


## SLICE-02: New geometry module state
var _edge_registry: EdgeRegistry = null       ## EdgeRegistry of all edges and slices
var _junction_columns: Array = []             ## Array of JunctionResolver.JunctionColumn
var _voxel_renderer: VoxelRenderer = null     ## Voxel rendering engine

## Prop stacking (e.g. stacked crates). Each extra sprite seats on the one below,
## offset up by the crate body step. Must equal the crate sprite's CUBE_HEIGHT
## (tools/asset_generation/generate_*_crate.py) so stacked crates seat seamlessly.
var CRATE_STACK_STEP_PX: float = 128.0

## tile_name → TileSet source_id
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

## DEBUG-02: Voxel ruler overlay and nudge mode
var _debug_tools_controller: DebugToolsControllerClass = null

## INPUT-01: Input dispatcher
var _input_controller: InputControllerClass = null

## Selection state management
var _selection_controller: SelectionControllerClass = null

## World markers overlay (shadows, spill, light rays)
var _world_markers_controller: WorldMarkersOverlayControllerClass = null

## Room builder (map construction, tile placement, perspective transforms)
var _room_builder: RoomBuilderClass = null

## Turn controller (turn management, enemy phase, alert system)
var _turn_controller: TurnControllerClass = null

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

## DEV-HUD-01: dev vision status panel
var _dev_vision_status_panel: Control = null

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

## OCC-01: Occlusion module and debug overlay
var _occlusion_set: OcclusionSetClass = null
var _occlusion_overlay: Node2D = null

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
@export var map_id: String = "TEXTURES"  ## BAKE-FACADE-PLANE-02-b: Changed default from PLAYGROUND to TEXTURES 2.0
## Quick-test override for wall storeys (0 = use the map's own wall_height). Inspector-tweakable.
@export var wall_height_override: int = 8  ## Legacy, now ignored (FIX-EXTERIOR-WALLS-01: exterior walls have fixed EXTERIOR_WALL_STOREYS height)
## SLICE-00: Enable voxel alignment probe to measure and report world-space deltas.
@export var debug_probe_voxel_alignment: bool = true

const WHISTLE_RADIUS := 3


## Loads (or reloads) the given map into the already-initialized room. Safe to call
## after _ready() — used by _ready() itself and by the F2 debug panel.
func load_map(new_map_id: String, new_seed: int = 0) -> void:
	map_id = new_map_id
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
		"connections":      connections,
		"segment_grid_pos": segment_grid_pos,
		"seed":             level_seed,
	})
	if layout.is_empty():
		push_error("[Room] Map compilation failed for map_id '%s' — room state unchanged" % new_map_id)
		return
	_base_layout = layout.duplicate(true)
	_agent_start_cell_base = layout.get("agent_start_cell", Vector2i.ZERO)
	var room_size: Vector2i = layout.get("size", Vector2i.ZERO)
	if room_size == Vector2i.ZERO:
		push_error("Room layout did not provide a valid map size.")
		return

	var view_layout := _room_builder.layout_with_perspective(layout, _active_perspective)
	room_size = view_layout.get("size", room_size)
	_map_buffer = view_layout.get("buffer", 0)
	_room_builder.build_from_layout(view_layout, room_size)
	_room_size = room_size

	## SCREENSHOT-HOOK-01: persist the last successfully loaded map id so the
	## pre-commit auto-screenshot capture (a separate Godot process) knows
	## which map to boot into. Written only after a load actually succeeds
	## (past both error-return points above) so a failed load never
	## overwrites a good last-known value.
	var current_map_config := ConfigFile.new()
	current_map_config.set_value("state", "map_id", new_map_id)
	if new_map_id == "PROCEDURAL":
		current_map_config.set_value("state", "seed", new_seed)
	var save_err := current_map_config.save("user://current_map.cfg")
	if save_err != OK:
		push_warning("[Room] Could not persist current_map.cfg (error %d) — auto-screenshot will use its fallback map" % save_err)

	## Sync cached data from builder to room state
	_blocked_cells = _room_builder.get_blocked_cells()
	_prop_heights = _room_builder.get_prop_heights()
	_exit_cells = _room_builder.get_exit_cells()
	_current_light_sources = _room_builder.get_light_sources()

	## Reset turn/agent state so a reload doesn't leave stale AP/position/FOW from the
	## previous map. Reuse whatever _ready() already does after _build_room() for
	## agent placement, turn_manager reset, FOW rebuild, camera recenter.
	var agent_start_cell: Vector2i = view_layout.get("agent_start_cell", Vector2i.ZERO)
	_agent_start_cell = agent_start_cell
	_center_camera(agent_start_cell)

	## Give overlays their references.
	movement_overlay.z_index = 5
	movement_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, turn_manager.move_points_per_ap)
	movement_overlay.set_blocked_cells(_room_builder.build_navigation_blocked_cells(_guards))
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
	
	## Sync game state to TurnController
	if _turn_controller != null:
		_turn_controller.set_game_state(_guards, _blocked_cells, _current_blocked_edges, _room_size)
	
	_fow_controller.initialize_fog(floor_layer, VISUAL_GRID_OFFSET, room_size)
	_fow_controller.reveal_around(agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w = room_size.x
	tile_labels_overlay.room_h = room_size.y
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
	## Initialize registries via autoload (FIX-SHUTDOWN-CRASH-01: real autoload, not Engine.set_meta).
	## Material registry is used by baking; ensure it's ready before map compilation.
	Registries.ensure_material_registry()
	
	## Load user:// bake toggle before any map builds (BAKE-LIVE-BOOT-01).
	BakeConfigClass.load_config()

	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	floor_layer.z_index = 0
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

	## Initialize RoomBuilder (map construction orchestrator)
	_room_builder = RoomBuilderClass.new(self)
	_room_builder.setup(floor_layer, structure_layer, ts)
	_room_builder.build_registry(ts)

	## Initialize TurnController (turn phases, enemy AI, alert system)
	_turn_controller = TurnControllerClass.new(self)

	## SLICE-02: Initialize VoxelRenderer
	_voxel_renderer = VoxelRendererClass.new()
	add_child(_voxel_renderer)
	_voxel_renderer.setup(VISUAL_GRID_OFFSET, WALL_BASE_Z_INDEX)

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

	## Create shadow boundary overlay (dark edges of playable shadows)
	_shadow_boundary_overlay = Node2D.new()
	_shadow_boundary_overlay.set_script(ShadowBoundaryOverlayClass)
	_shadow_boundary_overlay.z_index = 4  ## Above _tile_game (z=3), well above fog_of_war (z=2)
	add_child(_shadow_boundary_overlay)
	_shadow_boundary_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

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

	## Initialize light ray overlay (before world markers controller, setup later with ceiling_lift)
	_light_ray_overlay = LightRayOverlayClass.new()
	_light_ray_overlay.z_index = 0
	_light_ray_overlay.visible = false  ## hidden by default; toggled by VisionController (L key)
	add_child(_light_ray_overlay)

	## Initialize world markers overlay controller (shadows, spill, light rays)
	## MUST be before signal connections to LightingController
	_world_markers_controller = WorldMarkersOverlayControllerClass.new(self)
	_world_markers_controller.setup(_tile_shadow, _lighting_controller, _shadow_boundary_overlay,
		_light_ray_overlay, _vision_controller, floor_layer, VISUAL_GRID_OFFSET, _room_size, _shadow_tiles)

	## Connect LightingController signal to VisionController for overlay updates
	_lighting_controller.lighting_rebuilt.connect(_vision_controller.request_redraw)
	## Geometric floor shadows are real-world elements → repaint the always-on
	## world shadow layer whenever lighting rebuilds (e.g. perspective rotation).
	_lighting_controller.lighting_rebuilt.connect(_world_markers_controller.repaint_world_shadows)

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

	## Connect HudController signals to turn controller handlers
	_hud_controller.end_turn_requested.connect(_turn_controller._on_hud_end_turn_requested)
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

	## MODULARIZE-08: Setup TurnController (turn management, enemy phase, alert system)
	_turn_controller.setup(
		turn_manager,
		enemy_phase_controller,
		agent,
		camera,
		floor_layer,
		_fow_controller,
		_hud_controller,
		_vision_controller,
		_guard_coordinator,
		_noise_system,
		_noise_overlay
	)
	_turn_controller.set_constants(
		VISUAL_GRID_OFFSET,
		FOW_REVEAL_RADIUS,
		vision_bonus_tiles,
		_alert_max,
		_alert_gain_full
	)

	turn_manager.ap_changed.connect(_on_ap_changed)
	turn_manager.player_turn_started.connect(_turn_controller._on_player_turn_started)
	turn_manager.enemy_phase_started.connect(_turn_controller._on_enemy_phase_started)
	agent.move_started.connect(_on_agent_move_started)
	agent.step_finished.connect(_on_agent_step_finished)
	agent.move_finished.connect(_on_agent_move_finished)
	## Perspective button connections now in CameraController

	## SCREENSHOT-HOOK-01: the auto-capture process boots straight into
	## whatever map was last actually worked on (persisted by load_map()
	## itself), instead of the @export default. Confined to the opt-in env
	## var so normal play — where map_id is whatever the scene/Director set
	## it to — is never affected.
	if OS.get_environment("INFILTRAITOR_AUTO_SCREENSHOT") == "1":
		var last_map_config := ConfigFile.new()
		if last_map_config.load("user://current_map.cfg") == OK:
			var last_map_id: String = last_map_config.get_value("state", "map_id", map_id)
			if last_map_id != "":
				map_id = last_map_id
				level_seed = int(last_map_config.get_value("state", "seed", level_seed))

	load_map(map_id, level_seed)

	## DEBUG-01: Create map loader toolbar button
	## Initialize debug tools controller
	_debug_tools_controller = DebugToolsControllerClass.new(self)
	_debug_tools_controller.create_map_loader_button()

	## INPUT-01: Create and setup input controller
	set_meta("_camera_controller", _camera_controller)
	_input_controller = InputControllerClass.new(self)
	add_child(_input_controller)
	_input_controller.posture_lower_requested.connect(_on_posture_lower_requested)
	_input_controller.posture_raise_requested.connect(_on_posture_raise_requested)
	_input_controller.view_mode_requested.connect(_on_view_mode_requested)
	_input_controller.peek_initiated.connect(_on_peek_initiated)
	_input_controller.movement_input_requested.connect(_on_movement_input_requested)
	_input_controller.debug_command_requested.connect(_on_debug_command_requested)
	_input_controller.screenshot_requested.connect(_on_screenshot_requested)

	## Initialize selection controller
	_selection_controller = SelectionControllerClass.new(self)

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

	## OCC-01: Create and setup occlusion module and debug overlay
	_occlusion_set = OcclusionSetClass.new()
	_occlusion_overlay = Node2D.new()
	_occlusion_overlay.set_script(OcclusionOverlayClass)
	_occlusion_overlay.z_index = 5  ## Above all other overlays for debugging
	add_child(_occlusion_overlay)
	_occlusion_overlay.set_occlusion_set(_occlusion_set)
	_occlusion_overlay.set_floor_layer(floor_layer)
	_occlusion_overlay.set_visual_offset(VISUAL_GRID_OFFSET)

	## Paint the initial always-on world shadows from the geometric exposure.
	_world_markers_controller.repaint_world_shadows()

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

	## DEV-HUD-01: Create and setup dev vision status panel
	_dev_vision_status_panel = DevVisionStatusPanelClass.new()
	_dev_vision_status_panel.name = "DevVisionStatusPanel"
	$HUD.add_child(_dev_vision_status_panel)
	_dev_vision_status_panel.setup(self)

	_update_perspective_button_state()

	## Centering camera/setup initial state
	_update_guard_los_data()
	_on_hud_viewport_toggled()

	## Initialize debug views (S1: FIX-BAKE-06)
	_initialize_debug_views()

	## SLICE-02: Run alignment probe if debug flag is set
	if debug_probe_voxel_alignment:
		print_debug("[DEBUG] _ready() complete, starting probe")
		_debug_probe_voxel_alignment()

	## SCREENSHOT-HOOK-01: opt-in auto-capture for the pre-commit hook's
	## dedicated Godot process (INFILTRAITOR_AUTO_SCREENSHOT=1). Never fires
	## during normal play — the env var is only set by the hook's own launch
	## command. Deferred a few frames past _ready() so the just-built map has
	## actually been rasterized before capture (SLICE-02's own probe above
	## proves _ready() completing does not by itself guarantee a drawn frame).
	if OS.get_environment("INFILTRAITOR_AUTO_SCREENSHOT") == "1":
		_run_auto_screenshot_capture()


func _set_perspective(direction: String) -> void:
	if not PerspectiveMapperClass.is_valid_direction(direction):
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
		var view_layout := _room_builder.layout_with_perspective(_base_layout, _active_perspective)
		var room_size: Vector2i = view_layout.get("size", _room_size)
		_room_builder.build_from_layout(view_layout, room_size)
		_room_size = room_size
		_agent_start_cell = view_layout.get("agent_start_cell", _agent_start_cell)
		
		# Clear legacy shadow layers (migrated to _tile_shadow, but kept for compatibility)
		shadow_full_layer.clear()
		shadow_partial_layer.clear()
		
		# Update cache data from builder
		_blocked_cells = _room_builder.get_blocked_cells()
		_prop_heights = _room_builder.get_prop_heights()
		_exit_cells = _room_builder.get_exit_cells()
		_current_light_sources = _room_builder.get_light_sources()
		
		# Update tile semantics and shadow heights for new layout (LIGHT-FIX-03)
		# Now delegated to LightingController
		
		_spawn_guards(view_layout.get("enemy_defs", []))
		movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
		var blocked_edges: Array[Dictionary] = []
		for e in view_layout.get("blocked_edges", []):
			blocked_edges.append(e)
		_current_blocked_edges = blocked_edges.duplicate(true)
		movement_overlay.set_blocked_edges(blocked_edges)
		
		## Sync new game state to TurnController after perspective change
		if _turn_controller != null:
			_turn_controller.set_game_state(_guards, _blocked_cells, _current_blocked_edges, _room_size)

		tile_labels_overlay.room_w = _room_size.x
		tile_labels_overlay.room_h = _room_size.y

		var next_agent := PerspectiveMapperClass.cell_from_base(base_agent, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
		if not _is_cell_inside_room(next_agent):
			next_agent = _agent_start_cell
		agent.set_cell(next_agent)

		if has_selected:
			var next_selected := PerspectiveMapperClass.cell_from_base(base_selected, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
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

		## OCC-01: Recompute occlusion set on perspective change
		if _occlusion_set != null:
			var voxel_cells := _collect_all_voxel_cells()
			_occlusion_set.recompute(agent.cell, voxel_cells, _room_size)
			if _occlusion_overlay != null:
				_occlusion_overlay.queue_redraw()

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


func _set_view_mode(which: String, btn: Button) -> void:
	if not _vision_controller:
		return
	match which:
		"dev": _vision_controller.toggle_dev()
		"light": _vision_controller.toggle_light()
		"heat": _vision_controller.toggle_heat()
	var enabled: bool = _vision_controller.dev_vision if which == "dev" \
		else (_vision_controller.light_vision if which == "light" else _vision_controller.heat_vision)
	btn.set_pressed_no_signal(enabled)
	btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(1.0, 1.0, 1.0, 0.35)


func _on_view_h_toggled(_is_enabled: bool) -> void:
	_set_view_mode("heat", btn_view_h)


func _on_view_l_toggled(_is_enabled: bool) -> void:
	_set_view_mode("light", btn_view_l)


func _on_view_v_toggled(_is_enabled: bool) -> void:
	_set_view_mode("dev", btn_view_v)


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
## MOVED TO: WorldMarkersOverlayController
var SHADOW_SPILL_MAX_RADIUS: int = 4        ## hard cap on density-extended reach
var SHADOW_SPILL_DENSITY_STEP: int = 2      ## +1 ring per this many clustered full cells
var SHADOW_SPILL_BASE_DARKEN: float = 0.18  ## ring-1 orthogonal darkening (1 - keeps)
var SHADOW_SPILL_FALLOFF: float = 0.5       ## darkening multiplier per further ring
var SHADOW_SPILL_DIAGONAL_FACTOR: float = 0.65  ## diagonal keeps lighter than orthogonal

## Paint the always-on world shadow layer from the geometric exposure result.
## MOVED TO: WorldMarkersOverlayController.repaint_world_shadows()


## Build the cosmetic spill halo around the FULL-shadow tiles.
## MOVED TO: WorldMarkersOverlayController._compute_shadow_spill()


## Spill reach (ring count) for a full cell: base radius + 1 per density step of clustered
## MOVED TO: WorldMarkersOverlayController._spill_reach_for()


## Multiply tint for a spill cell at ring `level` (1 = closest), orthogonal or diagonal.
## MOVED TO: WorldMarkersOverlayController._spill_color()


func _draw_shadow_debug() -> void:
	## DEPRECATED: Moved to WorldMarkersOverlayController.draw_shadow_debug()
	pass


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

	## OCC-01: Recompute occlusion set on agent step
	if _occlusion_set != null:
		var voxel_cells := _collect_all_voxel_cells()
		_occlusion_set.recompute(agent.cell, voxel_cells, _room_size)
		if _occlusion_overlay != null:
			_occlusion_overlay.queue_redraw()

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


## Wrapper: processes auditory detection for all guards
func _process_audio_detection() -> void:
	if _turn_controller != null:
		_turn_controller._process_audio_detection()
	elif _noise_system != null:
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


## Wrapper: processes the result of a detection tic for a guard
func _apply_tic_result(guard, result: TicSystem.TicResult) -> void:
	if _turn_controller != null:
		_turn_controller._apply_tic_result(guard, result)
	else:
		## Fallback: accumulate or decay the guard's detection field
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

		_update_alert_label()


## Processes detection decay based on guard state
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


## Processes the result of a detection tic for a guard.


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


func _refresh_tactical_state() -> void:
	movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
	movement_overlay.rebuild(agent.cell, turn_manager.get_max_move_points())
	_update_selected_preview()
	_update_enemy_visibility()
	_update_movement_highlight()





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





## Utility: converts a cell coordinate to world position
func _world_center_for_cell(cell: Vector2i) -> Vector2:
	return floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET


## Wrapper: updates the HUD alert label from alert meter value
func _update_alert_label() -> void:
	if _hud_controller == null:
		return
	if _turn_controller != null:
		var pct := float(_turn_controller.get_alert_meter()) / float(_alert_max)
		_hud_controller.update_alert(pct)
	else:
		var pct := float(_alert_meter) / float(_alert_max)
		_hud_controller.update_alert(pct)


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
	_world_markers_controller.draw_shadow_debug()

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
	if _selection_controller == null:
		return false
	return _selection_controller.is_selectable_cell(cell)


func _set_selected_cell(cell: Vector2i) -> void:
	if _selection_controller == null:
		return
	_selection_controller.set_selected_cell(cell)
	_selected_cell = _selection_controller.selected_cell


func _handle_tile_click(cell: Vector2i) -> void:
	if _selection_controller == null:
		return
	_selection_controller.handle_tile_click(cell)
	_selected_cell = _selection_controller.selected_cell


func _try_move_to(cell: Vector2i) -> bool:
	if _selection_controller == null:
		return false
	var result := _selection_controller.try_move_to(cell)
	_selected_cell = _selection_controller.selected_cell
	return result











func _debug_probe_voxel_alignment() -> void:
	## SLICE-02: measures world-space delta between the canonical GU diamond and the
	## voxel plane's 8x8 block. Diagnostic for block/voxel layer alignment.
	## Uses corrected formula: adjusted = map_to_local() - half_tile_size
	if not debug_probe_voxel_alignment:
		return
	if _voxel_renderer == null or _voxel_renderer.get_layer(0) == null:
		print_debug("[SLICE-02 probe] ABORT: no voxel renderer or layer 0")
		return

	print_debug("[SLICE-02 probe] ===== STARTING ALIGNMENT CHECK =====")

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

	print_debug("[SLICE-02 probe] floor_cell = %s  voxel_cell = %s" % [floor_cell, voxel_cell])
	print_debug("[SLICE-02 probe] floor_map=%s  voxel_map=%s" % [floor_map, voxel_map])
	print_debug("[SLICE-02 probe] floor_adjusted=%s  voxel_adjusted=%s" % [floor_adjusted, voxel_adjusted])
	print_debug("[SLICE-02 probe] canon_pos=%s  voxel_pos=%s  delta=%s px" % [canon_pos, voxel_pos, delta])

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
		print_debug("[SLICE-02 probe] INFO: no block_* tile found for footprint check")
		return

	print_debug("[SLICE-02 probe] === Block Footprint Check ===")
	print_debug("[SLICE-02 probe] block_cell (GU coords) = %s" % block_cell)

	## Get expected voxel positions for this GU
	var GeometryCoordinatesClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
	var expected_voxels: Array[Vector2i] = GeometryCoordinatesClass.gu_voxels(block_cell)

	## Check which voxel cells are actually painted at voxel layer 0
	var painted_voxels: Array[Vector2i] = []
	for vx in expected_voxels:
		if vlayer.get_cell_source_id(vx) != -1:
			painted_voxels.append(vx)

	print_debug("[SLICE-02 probe] expected voxel count = %d" % expected_voxels.size())
	print_debug("[SLICE-02 probe] painted voxel count = %d" % painted_voxels.size())

	if painted_voxels.size() == expected_voxels.size():
		print_debug("[SLICE-02 probe] result = MATCH (all expected voxels painted)")
	else:
		print_debug("[SLICE-02 probe] result = MISMATCH")
		var missing: Array[Vector2i] = []
		for ev in expected_voxels:
			if not painted_voxels.has(ev):
				missing.append(ev)
		if missing.size() > 0:
			print_debug("[SLICE-02 probe] missing voxels: %s" % missing)


func _tic_voxel_system() -> void:
	if _voxel_renderer != null and _edge_registry != null:
		_voxel_renderer.process_dirty(_edge_registry)
		return



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




func _cell_to_base(view_cell: Vector2i, direction: String, base_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var size := base_size
	if size == Vector2i.ZERO:
		size = _base_layout.get("size", Vector2i.ZERO)
	return PerspectiveMapperClass.cell_to_base(view_cell, direction, size)




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


## OCC-01: Collect all voxel cells currently placed in the renderer
## Returns an array of Vector2i voxel-grid cells (in view-space, already rotated).
func _collect_all_voxel_cells() -> Array:
	var voxel_cells: Array = []
	
	if _voxel_renderer == null:
		return voxel_cells
	
	# Iterate through all voxel levels and collect used cells
	for level in range(8):  # GeometryCoords.LEVELS_PER_STOREY = 8
		var layer: TileMapLayer = _voxel_renderer.get_layer(level)
		if layer != null:
			var used_cells := layer.get_used_cells()
			for cell in used_cells:
				if not voxel_cells.has(cell):
					voxel_cells.append(cell)
	
	return voxel_cells


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
## INPUT-01: Delegated to InputController via signals.
func _input(event: InputEvent) -> void:
	## Mouse motion: preview path on hover
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
	if turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton

	## ── Right button: execute movement to the selected tile ──────
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_selection_controller.try_execute_move()
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

	## Salva em Screenshots/ dentro do diretório do projeto (res://).
	## Mais acessível que user:// (app-data do Godot).
	var project_root := ProjectSettings.globalize_path("res://")
	var absolute_screenshots_dir := project_root + "Screenshots"
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


## SCREENSHOT-HOOK-01: entry point for the pre-commit hook's dedicated,
## off-screen Godot process. Waits for the just-loaded map to actually be
## rasterized, captures the real viewport (same mechanism as
## _capture_screenshot_to_file(), separate destination + retention policy),
## prunes Screenshots/history/ to the 50 most recent files, then
## quits the process itself — the hook does not need to kill it.
func _run_auto_screenshot_capture() -> void:
	## A few extra frames past _ready() so the GPU has actually drawn the
	## map before capture (see the SCREENSHOT-HOOK-01 comment at the call site).
	for _i in range(10):
		await get_tree().process_frame

	## Optional pre-capture action, for HUD states that only exist transiently
	## mid-turn and so cannot be caught by a plain boot capture.
	## INFILTRAITOR_CAPTURE_ACTION=end_turn really ends the player's turn (the
	## same call the End Turn button makes) and then waits, so the capture lands
	## while the enemy-phase banner is actually on screen. Needs a map with
	## guards — on a guardless map the enemy phase resolves in the same frame and
	## the banner is gone before any capture can see it.
	## INFILTRAITOR_CAPTURE_ACTION=busted shows the busted overlay through the
	## same HudController call the turn controller makes when a guard catches the
	## agent. Triggered directly, not reached through play — a real capture is
	## still the point (the overlay must be in the pixels), but reaching it
	## organically needs a guard to actually spot the agent across several turns.
	var capture_action := OS.get_environment("INFILTRAITOR_CAPTURE_ACTION")
	if capture_action == "end_turn" and turn_manager != null:
		turn_manager.end_turn()
		for _j in range(20):
			await get_tree().process_frame
	elif capture_action == "busted" and _hud_controller != null:
		_hud_controller.show_busted()
		for _j in range(20):
			await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("[SCREENSHOT-HOOK-01] Failed to capture auto-screenshot — image was null")
		get_tree().quit(1)
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var history_dir := project_root + "Screenshots/history"
	var dir_err := DirAccess.make_dir_recursive_absolute(history_dir)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_warning("[SCREENSHOT-HOOK-01] Could not create history dir (error %d)" % dir_err)
		get_tree().quit(1)
		return

	var timestamp := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		timestamp["year"],
		timestamp["month"],
		timestamp["day"],
		timestamp["hour"],
		timestamp["minute"],
		timestamp["second"],
	]
	var filename := "%s/auto_%s.png" % [history_dir, date_str]

	var save_err := image.save_png(filename)
	if save_err != OK:
		push_warning("[SCREENSHOT-HOOK-01] Failed to save auto-screenshot: %s (error %d)" % [filename, save_err])
		get_tree().quit(1)
		return

	print("[SCREENSHOT-HOOK-01] Captured: %s" % filename)
	_prune_auto_screenshot_history(history_dir)
	get_tree().quit(0)


## Keeps Screenshots/history/ at the 50 most recent auto_*.png
## files (oldest-first deletion by filename, which sorts chronologically
## since the timestamp format is zero-padded and lexicographic-safe).
func _prune_auto_screenshot_history(history_dir: String) -> void:
	const MAX_HISTORY_FILES := 50
	var dir := DirAccess.open(history_dir)
	if dir == null:
		push_warning("[SCREENSHOT-HOOK-01] Could not open history dir for pruning: %s" % history_dir)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.begins_with("auto_") and entry.ends_with(".png"):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	if files.size() <= MAX_HISTORY_FILES:
		return

	files.sort()  ## chronological: zero-padded timestamp in the filename
	var excess := files.size() - MAX_HISTORY_FILES
	for i in range(excess):
		var path := "%s/%s" % [history_dir, files[i]]
		var rm_err := DirAccess.remove_absolute(path)
		if rm_err != OK:
			push_warning("[SCREENSHOT-HOOK-01] Could not prune old screenshot: %s (error %d)" % [path, rm_err])
		else:
			print("[SCREENSHOT-HOOK-01] Pruned: %s" % files[i])


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


## ── INPUT-01: Signal handlers for InputController ──────────────────────────

func _on_posture_lower_requested() -> void:
	print_debug("[ROOM] Handler: posture lower")
	## Z lowers: STANDING -> CROUCHING -> PRONE
	var next_posture := agent.posture
	if agent.posture == DebugAgent.Posture.STANDING:
		next_posture = DebugAgent.Posture.CROUCHING
	elif agent.posture == DebugAgent.Posture.CROUCHING:
		next_posture = DebugAgent.Posture.PRONE
	
	if next_posture != agent.posture:
		_debug_tools_controller.try_change_posture(next_posture)


func _on_posture_raise_requested() -> void:
	print_debug("[ROOM] Handler: posture raise")
	## X raises: PRONE -> CROUCHING -> STANDING
	var next_posture := agent.posture
	if agent.posture == DebugAgent.Posture.PRONE:
		next_posture = DebugAgent.Posture.CROUCHING
	elif agent.posture == DebugAgent.Posture.CROUCHING:
		next_posture = DebugAgent.Posture.STANDING
	
	if next_posture != agent.posture:
		_debug_tools_controller.try_change_posture(next_posture)


func _on_view_mode_requested(mode: String) -> void:
	print_debug("[ROOM] Handler: view mode %s" % mode)
	## V/L/H: switch view modes
	var btn: Node = null
	match mode:
		"dev":
			btn = btn_view_v
		"light":
			btn = btn_view_l
		"heat":
			btn = btn_view_h
	
	if btn:
		_set_view_mode(mode, btn)


func _on_peek_initiated() -> void:
	print_debug("[ROOM] Handler: peek initiated")
	## P: set peek pending flag
	_peek_pending = true


func _on_movement_input_requested(direction: Vector2i, is_large_step: bool) -> void:
	print_debug("[ROOM] Handler: movement %s (large_step=%s)" % [direction, is_large_step])
	## Arrow keys: dual-purpose (nudge or peek, decided by state)
	if _debug_tools_controller.is_nudge_mode_active():
		var step := 8.0 if is_large_step else 1.0
		_debug_tools_controller.apply_nudge(Vector2(direction) * step)
	elif _peek_pending:
		_try_peek(direction)
		_peek_pending = false


func _on_debug_command_requested(command: String) -> void:
	print_debug("[ROOM] Handler: debug command %s" % command)
	## F2/F3/F4/F6/F7/F17/K/R: debug commands
	match command:
		"toggle_map_loader":
			_debug_tools_controller.toggle_map_loader_panel()
		"toggle_voxel_ruler":
			_debug_tools_controller.toggle_voxel_ruler_overlay()
		"toggle_nudge_mode":
			_debug_tools_controller.toggle_nudge_mode()
		"toggle_bake_mode":
			_debug_tools_controller.toggle_bake_mode()
		"cycle_blend_mode":
			_debug_tools_controller.cycle_blend_mode()
		"cycle_language":
			var localization: Variant = get_node_or_null("/root/Localization")
			if localization:
				localization.cycle_language()
		"toggle_occlusion":
			if _occlusion_overlay != null:
				_occlusion_overlay.visible = not _occlusion_overlay.visible
				print_debug("[OCC-01] Occlusion overlay toggled: %s" % _occlusion_overlay.visible)
		"nudge_reset":
			if _debug_tools_controller.is_nudge_mode_active():
				_debug_tools_controller.reset_nudge()


func _on_screenshot_requested() -> void:
	print_debug("[ROOM] Handler: screenshot requested (Shift+P)")
	## Shift+P: capture screenshot
	_capture_screenshot_to_file()


## Initialize debug views (S1: FIX-BAKE-06)
func _initialize_debug_views() -> void:
	# Only in debug builds
	if not (OS.is_debug_build() or Engine.is_editor_hint()):
		return

	print("[DEBUG] Initializing debug views...")
	print("""
	[DEBUG BINDINGS]
	F5:  Toggle Theme Matrix (saturation calibration grid)
	F6:  Toggle bake mode (BAKED / GENERIC), reloads current map
	F7:  Cycle bake blend mode (MULTIPLY/TEXTURE_ONLY/MATERIAL_ONLY/OVERLAY/LINEAR_LIGHT), reloads current map
	F12: (Reserved) Selftest — run headless:
	     godot --headless --script godot/scripts/tools/bake_selftest.gd
	""")

	# Theme Matrix (F5)
	var theme_matrix_class = preload("res://godot/scripts/debug/theme_matrix_debug_view.gd")
	var theme_matrix = theme_matrix_class.new()
	add_child(theme_matrix)
	print("[DEBUG] F5: Theme Matrix viewer initialized")
