extends Node2D
## Tactical room controller: input, UI wiring, agent turns and scene setup.

const RoomLayoutBuilder = preload("res://godot/scripts/world/room_layout_builder.gd")

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var turn_manager = $TurnManager
@onready var movement_overlay = $MovementOverlay
@onready var path_preview = $PathPreview
@onready var structure_wall_layer:       TileMapLayer = $StructureWallLayer
@onready var structure_layer:            TileMapLayer = $StructureLayer
@onready var selection_overlay:   Node2D       = $SelectionOverlay
@onready var agent = $Agent
@onready var tile_labels_overlay: Node2D       = $TileLabelsOverlay
@onready var camera:              Camera2D     = $Camera2D
@onready var btn_numbers:         Button       = $HUD/TopBar/Row/BtnNumbers
@onready var btn_fullscreen:      Button       = $HUD/TopBar/Row/BtnFullscreen
@onready var btn_viewport:        Button       = $HUD/TopBar/Row/BtnViewport
@onready var lbl_ap:              Label        = $HUD/TopBar/Row/LblAp
@onready var chk_auto_end_turn:   CheckBox     = $HUD/TopBar/Row/BtnEndTurn/Content/ChkAutoEndTurn
@onready var btn_end_turn:        Button       = $HUD/TopBar/Row/BtnEndTurn

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

## Pinch-zoom state (mobile two-finger)
var _touches:         Dictionary = {}   ## finger_index → screen position
var _pinch_last_dist: float      = 0.0

## Viewport toggle state
var _is_desktop_viewport: bool = false
var _pending_auto_end_turn: bool = false
var _selected_cell: Vector2i = INVALID_CELL


func _ready() -> void:
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	structure_wall_layer.tile_set = ts
	structure_layer.tile_set = ts
	_build_registry(ts)

	var layout_builder = RoomLayoutBuilder.new()
	var layout: Dictionary = layout_builder.build_layout()
	_room_size = layout.get("size", Vector2i.ZERO)
	if _room_size == Vector2i.ZERO:
		push_error("Room layout did not provide a valid map size.")
		return

	_build_room(layout)
	var agent_start_cell: Vector2i = layout.get("agent_start_cell", Vector2i.ZERO)
	_center_camera(agent_start_cell)

	## Give overlays their references.
	movement_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, turn_manager.MOVE_POINTS_PER_AP)
	movement_overlay.set_blocked_cells(_get_blocked_cells_array())
	movement_overlay.set_blocked_edges(layout.get("blocked_edges", []))
	path_preview.setup(floor_layer, VISUAL_GRID_OFFSET)
	selection_overlay.floor_layer = floor_layer
	selection_overlay.visual_offset = VISUAL_GRID_OFFSET

	agent.setup(floor_layer, VISUAL_GRID_OFFSET, agent_start_cell)
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w = _room_size.x
	tile_labels_overlay.room_h = _room_size.y
	tile_labels_overlay.visible = false
	btn_numbers.modulate = Color(1.0, 1.0, 1.0, 0.35)

	turn_manager.ap_changed.connect(_on_ap_changed)
	agent.move_started.connect(_on_agent_move_started)
	agent.move_finished.connect(_on_agent_move_finished)
	btn_end_turn.pressed.connect(_on_btn_end_turn)
	btn_numbers.pressed.connect(_on_btn_numbers)
	btn_fullscreen.pressed.connect(_on_btn_fullscreen)
	btn_viewport.pressed.connect(_on_btn_viewport)
	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	turn_manager.reset_player_turn()

	## Start in desktop mode — _is_desktop_viewport is false, so one call switches to desktop.
	_on_btn_viewport()


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
	if agent.is_moving:
		return
	_pending_auto_end_turn = false
	turn_manager.end_turn()


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


func _on_ap_changed(current_ap: int, max_ap: int) -> void:
	lbl_ap.text = "AP %d/%d" % [current_ap, max_ap]
	if not agent.is_moving:
		_refresh_tactical_state()


func _on_agent_move_started(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	selection_overlay.set_selected(to_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()


func _on_agent_move_finished(_cell: Vector2i) -> void:
	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	if _pending_auto_end_turn:
		_pending_auto_end_turn = false
		turn_manager.end_turn()
		return
	_refresh_tactical_state()


func _refresh_tactical_state() -> void:
	movement_overlay.rebuild(agent.cell, turn_manager.get_max_move_points())
	_update_selected_preview()


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


func _is_selectable_cell(cell: Vector2i) -> bool:
	if cell == INVALID_CELL or _blocked_cells.has(cell):
		return false
	return floor_layer.get_cell_source_id(cell) != -1


func _set_selected_cell(cell: Vector2i) -> void:
	if not _is_selectable_cell(cell):
		return
	_selected_cell = cell
	selection_overlay.set_selected(cell)
	_update_selected_preview()


func _handle_tile_click(cell: Vector2i) -> void:
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
	if agent.is_moving or cell == INVALID_CELL or cell == agent.cell:
		return false
	if not movement_overlay.is_reachable(cell):
		return false

	var path_cost: int = movement_overlay.get_cost(cell)
	if not turn_manager.spend_for_path_cost(path_cost):
		return false

	_selected_cell = cell
	_pending_auto_end_turn = chk_auto_end_turn.button_pressed and int(turn_manager.current_ap) <= 0
	agent.move_to_cell(cell)
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
	structure_layer.clear()

	var floor_tile_name := String(layout.get("floor_tile_name", "floor_N"))
	for x in range(_room_size.x):
		for y in range(_room_size.y):
			_place(Vector2i(x, y), floor_tile_name)

	for structure_entry in layout.get("wall_tiles", []):
		var wall_cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var wall_tile_name := String(structure_entry.get("tile_name", ""))
		_place(wall_cell, wall_tile_name, structure_wall_layer)

	for structure_entry in layout.get("structure_tiles", []):
		var cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var tile_name := String(structure_entry.get("tile_name", ""))
		_place(cell, tile_name, structure_layer)

	_cache_blocked_cells(layout)


func _cache_blocked_cells(layout: Dictionary) -> void:
	_blocked_cells.clear()
	for cell in layout.get("blocked_cells", []):
		_blocked_cells[cell] = true


func _get_blocked_cells_array() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		cells.append(cell)
	return cells


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


## Unified input: wheel zoom · pinch zoom · motion drag.
## Left mouse button (press/release) lives in _unhandled_input so GUI
## controls (Buttons) can consume their clicks before game logic runs.
func _input(event: InputEvent) -> void:

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

	## ── Mouse motion: pan when dragging ─────────────────────────────────
	if event is InputEventMouseMotion and _left_down and _touches.size() < 2:
		var mm := event as InputEventMouseMotion
		var moved_sq := (mm.position - _drag_start_mouse).length_squared()
		if not _drag_started and moved_sq > DRAG_THRESHOLD_SQ:
			_drag_started = true
		if _drag_started:
			var delta := (mm.position - _drag_start_mouse) / camera.zoom.x
			camera.global_position = _drag_start_cam - delta
			get_viewport().set_input_as_handled()
		return


## Left mouse: only runs when no GUI Control consumed the event first.
## This lets HUD buttons work while still handling pan + tile selection.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
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
			_handle_tile_click(cell)
		_left_down = false
		_drag_started = false