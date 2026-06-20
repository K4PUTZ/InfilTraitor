extends Node
## CameraController — Manages the camera: drag, zoom, pinch-zoom, leash, perspective.
##
## Exposes handle_input() to consume events before room.gd processes gameplay input.
## room.gd calls this first; if it returns true, the event was consumed.

# Camera constants — moved from room.gd
const DRAG_THRESHOLD_SQ        := 64.0       ## 8 px squared
const ZOOM_MIN                 := 0.20
const ZOOM_MAX                 := 1.20
const ZOOM_STEP                := 0.06
const CAMERA_MAX_BORDER_TILES  := 4  ## max tiles camera can see outside scenario boundary
const CAMERA_SOFT_ZONE_TILES   := 2  ## tiles of ease-out damping before leash hard stop
const WORLD_TILE_PX            := 128.0  ## horizontal px per isometric tile step

# Camera state
var _camera: Camera2D
var _room: Node2D
var _vision_controller: Node = null

var _left_down: bool = false
var _drag_started: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}  ## finger_index → screen position
var _pinch_last_dist: float = 0.0

# UI buttons for perspective
var _btn_perspective_nw: Button
var _btn_perspective_ne: Button
var _btn_perspective_sw: Button
var _btn_perspective_se: Button


func setup(camera_ref: Camera2D, room_ref: Node2D) -> void:
	_camera = camera_ref
	_room = room_ref
	# Get reference to VisionController after it's ready
	call_deferred("_cache_vision_controller")
	_cache_perspective_buttons()
	_connect_perspective_buttons()


func _cache_vision_controller() -> void:
	if _room and _room.has_meta("vision_controller"):
		_vision_controller = _room.get_meta("vision_controller")


func handle_input(event: InputEvent) -> bool:
	## Processes camera events. Returns true if the event was consumed.
	## room.gd calls this before processing any other input.
	
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
		return true

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var keys := _touches.keys()
			var dist := (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
			if _pinch_last_dist > 0.0:
				var delta := (dist - _pinch_last_dist) * 0.001
				_apply_zoom(clampf(_camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX))
			_pinch_last_dist = dist
			get_viewport().set_input_as_handled()
		return true

	## ── Mouse wheel zoom ─────────────────────────────────────────────────
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(clampf(_camera.zoom.x + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX))
			get_viewport().set_input_as_handled()
			return true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(clampf(_camera.zoom.x - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX))
			get_viewport().set_input_as_handled()
			return true

	## ── Mouse motion: pan when dragging ─────────────────────────────────
	if event is InputEventMouseMotion and _left_down and _touches.size() < 2:
		var mm := event as InputEventMouseMotion
		var moved_sq := (mm.position - _drag_start_mouse).length_squared()
		if not _drag_started and moved_sq > DRAG_THRESHOLD_SQ:
			_drag_started = true
		if _drag_started:
			var delta := (mm.position - _drag_start_mouse) / _camera.zoom.x
			_camera.global_position = _get_leashed_pos(_drag_start_cam - delta)
			get_viewport().set_input_as_handled()
			return true

	## ── Left mouse button: pan (gesture start/end) ────────────────────────
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or _touches.size() >= 2:
			return false

		if mb.pressed:
			_left_down = true
			_drag_started = false
			_drag_start_mouse = mb.position
			_drag_start_cam = _camera.global_position
			return true
		else:
			_left_down = false
			if _drag_started:
				## Drag ended, input was handled
				get_viewport().set_input_as_handled()
				return true
			else:
				## Simple click without drag — let room.gd handle it
				return false

	return false


func focus_on(world_pos: Vector2) -> void:
	if _camera:
		_camera.position = world_pos


func _cache_perspective_buttons() -> void:
	_btn_perspective_nw = _room.btn_perspective_nw
	_btn_perspective_ne = _room.btn_perspective_ne
	_btn_perspective_sw = _room.btn_perspective_sw
	_btn_perspective_se = _room.btn_perspective_se


func _connect_perspective_buttons() -> void:
	if _btn_perspective_nw:
		_btn_perspective_nw.pressed.connect(func() -> void: _room._set_perspective("W"))
	if _btn_perspective_ne:
		_btn_perspective_ne.pressed.connect(func() -> void: _room._set_perspective("N"))
	if _btn_perspective_sw:
		_btn_perspective_sw.pressed.connect(func() -> void: _room._set_perspective("S"))
	if _btn_perspective_se:
		_btn_perspective_se.pressed.connect(func() -> void: _room._set_perspective("E"))


## Apply zoom clamped between ZOOM_MIN and ZOOM_MAX.
func _apply_zoom(new_z: float) -> void:
	_camera.zoom = Vector2(new_z, new_z)


## Get camera position with leash enforcement (agent-centered with soft/hard bounds).
## In DEV_VISION mode, no constraints are applied.
func _get_leashed_pos(desired_pos: Vector2) -> Vector2:
	if not is_instance_valid(_room) or not is_instance_valid(_room.agent):
		return desired_pos
	
	# Any analysis mode: release all constraints
	if _vision_controller and (_vision_controller.dev_vision or _vision_controller.light_vision or _vision_controller.heat_vision):
		return desired_pos
	
	var agent_world = _room.agent.global_position
	var offset = desired_pos - agent_world
	var dist = offset.length()
	
	var hard_radius := float(CAMERA_MAX_BORDER_TILES) * WORLD_TILE_PX
	var soft_radius := hard_radius - float(CAMERA_SOFT_ZONE_TILES) * WORLD_TILE_PX
	
	if dist < soft_radius:
		return desired_pos
	if dist >= hard_radius:
		return agent_world + offset.normalized() * hard_radius
	
	## Soft zone: quadratic ease-out — slows as camera approaches the hard limit.
	var t: float = (dist - soft_radius) / (hard_radius - soft_radius)   ## 0..1
	var damped: float = soft_radius + (hard_radius - soft_radius) * t * (2.0 - t)
	return agent_world + offset.normalized() * damped
