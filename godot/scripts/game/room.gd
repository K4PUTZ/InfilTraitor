extends Node2D
## Minimal room — isometric grid with pink tile selection.
## Milestone 0: tile picking only. No agent, no AP, no popup.

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var selection_overlay:   Node2D       = $SelectionOverlay
@onready var tile_labels_overlay: Node2D       = $TileLabelsOverlay
@onready var camera:              Camera2D     = $Camera2D
@onready var btn_numbers:         Button       = $HUD/TopBar/Row/BtnNumbers
@onready var btn_fullscreen:      Button       = $HUD/TopBar/Row/BtnFullscreen
@onready var btn_viewport:        Button       = $HUD/TopBar/Row/BtnViewport

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"

const ROOM_W := 17   # columns
const ROOM_H := 17   # rows

## The TileMap renders the current 512px-tall source tiles lower than the
## logical grid used by map_to_local/local_to_map. Compensate with one fixed
## visual offset so camera, labels, selection and picking all agree.
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)

## tile_name → TileSet source_id
var _tile_ids: Dictionary = {}

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


func _ready() -> void:
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	_build_registry(ts)
	_build_room()

	## Center camera on the visual centre of the room.
	## map_to_local returns the TOP vertex; +Vector2(0,64) is the visual centre.
	@warning_ignore("integer_division")
	var centre_cell  := Vector2i(ROOM_W / 2, ROOM_H / 2)
	var centre_world := floor_layer.map_to_local(centre_cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	camera.global_position = centre_world

	## Give overlays their references.
	selection_overlay.floor_layer   = floor_layer
	selection_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w      = ROOM_W
	tile_labels_overlay.room_h      = ROOM_H

	btn_numbers.pressed.connect(_on_btn_numbers)
	btn_fullscreen.pressed.connect(_on_btn_fullscreen)
	btn_viewport.pressed.connect(_on_btn_viewport)

	## Start in desktop mode — _is_desktop_viewport is false, so one call switches to desktop.
	_on_btn_viewport()


func _on_btn_numbers() -> void:
	tile_labels_overlay.visible = not tile_labels_overlay.visible
	btn_numbers.modulate = Color.WHITE if tile_labels_overlay.visible else Color(1.0, 1.0, 1.0, 0.35)


func _on_btn_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_btn_viewport() -> void:
	_is_desktop_viewport = not _is_desktop_viewport
	var target := Vector2i(1280, 720) if _is_desktop_viewport else Vector2i(390, 844)
	btn_viewport.text   = "D" if _is_desktop_viewport else "M"

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
func _place(cell: Vector2i, tile_name: String) -> void:
	var sid: int = _tile_ids.get(tile_name, -1)
	if sid != -1:
		floor_layer.set_cell(cell, sid, Vector2i(0, 0))


## Fill grid: low slab border, floor_N interior.
## block_N is visually too tall for this debug room and makes the rendered
## board look detached from the logical grid / picking overlay.
func _build_room() -> void:
	for x in range(ROOM_W):
		for y in range(ROOM_H):
			var cell      := Vector2i(x, y)
			var is_border := x == 0 or x == ROOM_W - 1 or y == 0 or y == ROOM_H - 1
			_place(cell, "slab_N" if is_border else "floor_N")


## Convert a screen-space press position to the tile cell underneath it.
## local_to_map uses the TOP VERTEX as anchor, so it only gives the correct
## cell when clicking the top quadrant. The 3×3 search over visual CENTERs
## (map_to_local + Vector2(0,64)) finds the diamond that truly contains the
## click — this corrects the other three quadrants.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var lp: Vector2     = floor_layer.to_local(ct.affine_inverse() * screen_pos)
	var logical_lp := lp - VISUAL_GRID_OFFSET
	var tile_seed: Vector2i = floor_layer.local_to_map(logical_lp)
	var best            := tile_seed
	var best_dist       := INF
	var found_inside    := false
	for dc: int in [-1, 0, 1]:
		for dr: int in [-1, 0, 1]:
			var c      := tile_seed + Vector2i(dc, dr)
			var center := floor_layer.map_to_local(c) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
			var d      := lp - center
			var dist   := absf(d.x) / 128.0 + absf(d.y) / 64.0
			if dist <= 1.0 and dist < best_dist:
				best_dist = dist
				best = c
				found_inside = true
	if found_inside:
		return best
	return Vector2i(-9999, -9999)


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
			_left_down    = false
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
		var mm       := event as InputEventMouseMotion
		var moved_sq := (mm.position - _drag_start_mouse).length_squared()
		if not _drag_started and moved_sq > DRAG_THRESHOLD_SQ:
			_drag_started = true
		if _drag_started:
			var delta := (mm.position - _drag_start_mouse) / camera.zoom.x
			camera.global_position = _drag_start_cam - delta
			get_viewport().set_input_as_handled()


## Left mouse: only runs when no GUI Control consumed the event first.
## This lets HUD buttons work while still handling pan + tile selection.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or _touches.size() >= 2:
		return

	if mb.pressed:
		_left_down        = true
		_drag_started     = false
		_drag_start_mouse = mb.position
		_drag_start_cam   = camera.global_position
	else:
		if not _drag_started:
			var cell := _screen_to_tile(mb.position)
			if cell != Vector2i(-9999, -9999) and floor_layer.get_cell_source_id(cell) != -1:
				selection_overlay.set_selected(cell)
			else:
				selection_overlay.clear_selected()
		_left_down    = false
		_drag_started = false
