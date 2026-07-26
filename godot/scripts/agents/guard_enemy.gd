extends Node2D
class_name GuardEnemy
const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")
## Patrol guard placeholder: draw-based enemy with directional vision checks.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)

## Emitted in _enter_state() at the right moments
signal whistled(origin_cell: Vector2i, last_known: Vector2i)
signal radioed(origin_cell: Vector2i, last_known: Vector2i)

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
const STEP_DURATION_BASE := 0.13

const COLOR_BODY := Color(0.86, 0.26, 0.22, 1.0)
const COLOR_BODY_DARK := Color(0.58, 0.12, 0.10, 1.0)
const COLOR_HEAD := Color(1.0, 0.87, 0.80, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

## Base probabilities by distance, indexed by tile distance
const FOV_DISTANCE_CURVE: Array[float] = [
	1.00, 1.00, 0.95, 0.88, 0.70, 0.48, 0.20, 0.06, 0.01
]

## Lateral multiplier by distance to the cone's central axis (in tiles)
## offset 0 = center column, offset 1 = ±1 column, offset 2 = ±2 columns
const FOV_LATERAL_FALLOFF: Array[float] = [1.0, 0.50, 0.10]

const COLOR_VISION_SMOOTH := Color(1.0, 0.9, 0.2, 0.5)

const CARDINAL_DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const VISION_RANGE := 6
const STATE_PATROL := "patrol"
const STATE_SUSPICIOUS := "suspicious"
const STATE_ALERT := "alert"
const STATE_CHASE := "chase"
const STATE_SEARCH := "search"
const INVALID_CELL: Vector2i = Vector2i(-9999, -9999)

const SHADOW_MULT      := 0.30   ## probability multiplier on a shadow tile
const PENUMBRA_MULT    := 0.55   ## tile adjacent to shadow (penumbra edge)

## State timers — M2-11
const TIMER_ALERT_TO_CHASE       := 3
const TIMER_SUSPICIOUS_TO_PATROL := 4
const TIMER_CHASE_TO_SEARCH      := 3
const TIMER_SEARCH_TO_SUSPICIOUS := 2
const TIMER_NOISE_SUSPICIOUS     := 3
const TIMER_NOISE_SUSPICIOUS_MED := 2

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var enemy_id: String = ""

var _vision_tiles_node: Node2D = null
var _vision_smooth_node: Node2D = null

var cell: Vector2i = Vector2i.ZERO
var patrol_route: Array[Vector2i] = []
var patrol_index: int = 0
var facing: Vector2i = Vector2i.UP
var state: String = STATE_PATROL
var state_timer: int = 0
var last_known_agent_cell: Vector2i = INVALID_CELL
var is_moving: bool = false
var _path_queue: Array[Vector2i] = []

## Angular FOV detection
var fov_degrees: float = 90.0      ## full cone width in degrees
var fov_range: int = 8             ## max detection range in tiles
var facing_angle_deg: float = 0.0  ## 0=UP 90=RIGHT 180=DOWN 270=LEFT

## Continuous angles — visual only
var body_angle: float   = 0.0
var vision_angle: float = 0.0
const TURN_SPEED := 4.0

## Contextual attention
var attention: GuardAttention = GuardAttention.new()

## Foundation for shadows (empty for now)
var _shadow_tiles: Dictionary = {}

## A* path caching
var _cached_target: Vector2i = INVALID_CELL
var _cached_path: Array[Vector2i] = []
var _path_index: int = 1

## Dev vision mode
var dev_vision: bool = false

## LOS data provided by room.gd
var _los_blocked_cells: Dictionary = {}
var _los_blocked_edges: Dictionary = {}
var _room_size_cached: Vector2i = Vector2i(32, 32) ## default fallback

## Dev 05: detection meter — 0.0 to 1.0, placeholder until M2 fills it
var detection: float = 0.0

## M2-03: Organic Patrol — idle behavior and look rotation
var idle_turns_remaining: int = 0
var _look_angles: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
var _target_facing_angle: float = 0.0     ## target angle of the rotation
var _is_rotating: bool = false            ## rotation in progress

## M2-07: Active Search Behavior
var _search_queue: Array[Vector2i] = []
var _search_origin: Vector2i = INVALID_CELL
const SEARCH_RADIUS := 2          ## tiles around last_known
const SEARCH_TURNS_MAX := 5       ## turns before de-escalating
var _search_turns_remaining: int = 0

## M2-08: Guard-to-Guard Communication
var _comms_label_timer: float = 0.0
const COMMS_LABEL_DURATION := 2.0

## Debug label for dev_vision mode
var _debug_label_container: Panel = null
var _debug_label: Label = null


func set_dev_vision(enabled: bool) -> void:
	dev_vision = enabled
	_update_debug_label()
	queue_redraw()
	if _vision_tiles_node:
		_vision_tiles_node.visible = enabled
		_vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()


func set_los_data(blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i = Vector2i.ZERO, shadow_tiles: Dictionary = {}) -> void:
	_los_blocked_cells = blocked_cells
	_los_blocked_edges = blocked_edges
	_shadow_tiles      = shadow_tiles
	if room_size != Vector2i.ZERO:
		_room_size_cached = room_size


func _build_search_queue(origin: Vector2i, blocked_cells: Dictionary, room_size: Vector2i) -> void:
	_search_origin = origin
	_search_queue.clear()

	## Square spiral around the origin, distance 1 to SEARCH_RADIUS
	for r in range(1, SEARCH_RADIUS + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  ## only the ring edge
				var candidate := origin + Vector2i(dx, dy)
				if candidate.x < 0 or candidate.y < 0 or candidate.x >= room_size.x or candidate.y >= room_size.y:
					continue
				if blocked_cells.has(candidate):
					continue
				_search_queue.append(candidate)

	## Shuffle for a non-deterministic sweep
	_search_queue.shuffle()
	if _vision_tiles_node: _vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()


func _ready() -> void:
	## Initialize visual angles
	body_angle = deg_to_rad(facing_angle_deg)
	vision_angle = body_angle

	_vision_tiles_node = Node2D.new()
	_vision_tiles_node.name = "VisionTiles"
	_vision_tiles_node.show_behind_parent = true
	_vision_tiles_node.z_index = -5
	var mat_mix := CanvasItemMaterial.new()
	mat_mix.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_vision_tiles_node.material = mat_mix
	_vision_tiles_node.visible = dev_vision
	add_child(_vision_tiles_node)
	_vision_tiles_node.draw.connect(_draw_vision_tiles)

	_vision_smooth_node = Node2D.new()
	_vision_smooth_node.name = "VisionSmooth"
	_vision_smooth_node.show_behind_parent = true
	_vision_smooth_node.z_index = -4
	add_child(_vision_smooth_node)
	_vision_smooth_node.draw.connect(_draw_vision_smooth)


func _rotate_towards(current: float, target: float, speed: float, delta: float) -> float:
	return lerp_angle(current, target, clampf(speed * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	attention.update(delta)

	if _comms_label_timer > 0.0:
		_comms_label_timer -= delta
		_update_debug_label()

	## Body follows facing_angle_deg (discrete → continuous)
	body_angle = _rotate_towards(body_angle, deg_to_rad(facing_angle_deg), TURN_SPEED, delta)

	## Head/vision: follows the body by default, diverges with active attention
	var target_vision := body_angle
	if attention.active() and is_instance_valid(floor_layer):
		var target_world_pos: Vector2 = floor_layer.map_to_local(attention.target_cell) + visual_offset
		var to_focus: Vector2 = (target_world_pos - position)
		if to_focus.length_squared() > 1.0:
			target_vision = to_focus.angle()
			## In Godot's 2D isometric space, angle 0 rad is RIGHT (+X), PI/2 is DOWN (+Y).
			## Our grid logical angle 0 deg is UP (-Y grid).
			## to_focus.angle() gives us the visual angle in the Room (isometric).
			## This is correct because vision_angle is used purely for visual drawing.

	vision_angle = _rotate_towards(vision_angle, target_vision, TURN_SPEED * 1.35, delta)

	if _vision_tiles_node: _vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()
	queue_redraw()


func setup(
		tile_layer: TileMapLayer,
		offset: Vector2,
		id: String,
		route: Array[Vector2i],
		start_index: int = 0
) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	enemy_id = id
	patrol_route = route.duplicate()
	if patrol_route.is_empty():
		patrol_route = [Vector2i.ZERO]

	patrol_index = wrapi(start_index, 0, patrol_route.size())
	cell = patrol_route[patrol_index]
	position = _cell_to_world(cell)
	_set_facing_from_route()
	_update_facing_angle()

	## Create debug label container with background for dev_vision mode
	_debug_label_container = Panel.new()
	_debug_label_container.custom_minimum_size = Vector2(250, 200)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)  ## Dark gray background
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(30)
	_debug_label_container.add_theme_stylebox_override("panel", panel_style)
	_debug_label_container.z_index = 100
	_debug_label_container.visible = false
	add_child(_debug_label_container)

	## Create debug label inside container
	_debug_label = Label.new()
	_debug_label.set_position(Vector2(+15, 0))
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_debug_label_container.add_child(_debug_label)

	queue_redraw()


func reset_to_route_start() -> void:
	if patrol_route.is_empty():
		return
	patrol_index = 0
	cell = patrol_route[patrol_index]
	position = _cell_to_world(cell)
	_set_facing_from_route()
	_update_facing_angle()
	queue_redraw()


func evaluate_detection(
		player_cell: Vector2i,
		_vision_range: int = VISION_RANGE,
		blocked_cells: Dictionary = {},
		blocked_edges: Dictionary = {},
		_close_warning_range: int = 2,
		agent_ref: DebugAgent = null
) -> Dictionary:
	var delta := player_cell - cell
	if delta == Vector2i.ZERO:
		return {"visible": true, "severity": 2, "distance": 0, "angle_ratio": 1.0}

	var dist := absi(delta.x) + absi(delta.y)
	if dist > fov_range:
		return {"visible": false, "severity": 0}

	var to_target_angle := rad_to_deg(atan2(float(delta.x), float(-delta.y)))
	var angle_diff := wrapf(to_target_angle - facing_angle_deg, -180.0, 180.0)
	var half_fov := fov_degrees / 2.0
	if absf(angle_diff) > half_fov:
		return {"visible": false, "severity": 0}

	if blocked_cells != null and blocked_edges != null:
		if not can_see_cell(player_cell, blocked_cells, blocked_edges):
			return {"visible": false, "severity": 0}

	var angle_ratio := 1.0 - (absf(angle_diff) / half_fov)

	## Compute base probability and modifiers (shadows and cover)
	var base_prob: float = FOV_DISTANCE_CURVE[dist] if dist < FOV_DISTANCE_CURVE.size() else 0.01

	## Lateral multiplier
	var lateral_offset := absf(angle_diff) / half_fov
	var lateral_idx := mini(int(lateral_offset * FOV_LATERAL_FALLOFF.size()), FOV_LATERAL_FALLOFF.size() - 1)
	var lateral_mult := FOV_LATERAL_FALLOFF[lateral_idx]

	var final_prob := base_prob * lateral_mult

	## Shadows
	if _shadow_tiles.has(player_cell):
		final_prob *= _shadow_tiles[player_cell]

	## M2-12b: Agent Posture
	if agent_ref != null:
		var posture_mult: float = DebugAgent.POSTURE_DETECTION_MULT.get(agent_ref.posture, 1.0)
		final_prob *= posture_mult

	## M2-10: Cover
	if agent_ref != null and agent_ref.cover_state != DebugAgent.CoverType.NONE:
		var cover_mult := 1.0
		if agent_ref.cover_state == DebugAgent.CoverType.FULL:
			cover_mult = DebugAgent.COVER_FULL_MULT
		elif agent_ref.cover_state == DebugAgent.CoverType.PARTIAL:
			cover_mult = DebugAgent.COVER_PARTIAL_MULT

		## Flanking: a guard on the opposite side of the obstacle ignores cover
		var flank_dir := -agent_ref.cover_direction  ## exposed side
		var guard_dir := (cell - agent_ref.cell)
		## If the guard is in the 90° arc of the exposed side (dot product > 0), cover does not protect
		if (guard_dir.x * flank_dir.x + guard_dir.y * flank_dir.y) > 0:
			cover_mult = 1.0

		final_prob *= cover_mult

	## Severity based on final probability threshold
	var severity := 1
	if final_prob > 0.7 or dist <= 2:
		severity = 2

	return {"visible": true, "severity": severity, "distance": dist, "angle_ratio": angle_ratio, "final_prob": final_prob}


func pick_next_patrol_cell(
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> Vector2i:
	if patrol_route.size() < 2:
		return cell

	for i in range(1, patrol_route.size() + 1):
		var idx := (patrol_index + i) % patrol_route.size()
		var candidate: Vector2i = patrol_route[idx]
		if not _is_inside(candidate, room_size):
			continue
		if blocked_cells.has(candidate):
			continue
		if occupied_cells.has(candidate):
			continue
		if _is_edge_blocked(cell, candidate, blocked_edges):
			continue
		if candidate == cell:
			continue
		patrol_index = idx

		## Visual anticipation: briefly focus on the next waypoint before moving
		attention.focus(candidate, 0.8, 0.35)

		return candidate

	return cell


func move_to_cell_animated(
		new_cell: Vector2i,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> void:
	if new_cell == cell:
		return
	var path: Array[Vector2i] = GuardPathfinder.find_path(cell, new_cell, blocked_cells, blocked_edges, room_size)
	if path.size() < 2:
		return
	move_along_path(path)


func move_along_path(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	is_moving = true
	move_started.emit(path[0], path.back())
	_path_queue = path.duplicate()
	_path_queue.pop_front()
	_step_next()


func _step_next() -> void:
	if _path_queue.is_empty():
		is_moving = false
		move_finished.emit(cell)
		queue_redraw()
		return

	var next_cell: Vector2i = _path_queue.pop_front()
	var previous_cell: Vector2i = cell
	cell = next_cell
	facing = _snap_to_8dir(next_cell - previous_cell)
	_update_facing_angle()
	_update_debug_label()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _cell_to_world(next_cell), _get_step_duration())
	await tween.finished
	step_finished.emit(next_cell)
	queue_redraw()
	if _vision_tiles_node: _vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()
	_step_next()



func _cell_to_world(map_cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


func _set_facing_from_route() -> void:
	if patrol_route.size() < 2:
		facing = Vector2i.UP
		_update_facing_angle()
		return
	var next_idx := (patrol_index + 1) % patrol_route.size()
	var dir := patrol_route[next_idx] - patrol_route[patrol_index]
	if dir == Vector2i.ZERO:
		facing = Vector2i.UP
		_update_facing_angle()
		return
	facing = _snap_to_8dir(dir)
	_update_facing_angle()


func _get_step_duration() -> float:
	match state:
		STATE_PATROL:
			return STEP_DURATION_BASE * 2.2
		STATE_SUSPICIOUS:
			return STEP_DURATION_BASE * 1.4
		STATE_ALERT:
			return STEP_DURATION_BASE * 1.0
		STATE_CHASE:
			return STEP_DURATION_BASE * 0.75
	return STEP_DURATION_BASE


func _snap_to_8dir(v: Vector2i) -> Vector2i:
	if v == Vector2i.ZERO:
		return facing  ## no movement, keep facing
	## Normalize to components -1, 0, 1
	var sx := signi(v.x)
	var sy := signi(v.y)
	return Vector2i(sx, sy)


func _update_facing_angle() -> void:
	if facing == Vector2i.UP:           facing_angle_deg = 0.0    ## N
	elif facing == Vector2i(1, -1):     facing_angle_deg = 45.0   ## NE
	elif facing == Vector2i.RIGHT:      facing_angle_deg = 90.0   ## E
	elif facing == Vector2i(1, 1):      facing_angle_deg = 135.0  ## SE
	elif facing == Vector2i.DOWN:       facing_angle_deg = 180.0  ## S
	elif facing == Vector2i(-1, 1):     facing_angle_deg = 225.0  ## SW
	elif facing == Vector2i.LEFT:       facing_angle_deg = 270.0  ## W
	elif facing == Vector2i(-1, -1):    facing_angle_deg = 315.0  ## NW


func _update_facing_from_angle() -> void:
	var snapped_angle := snappedf(facing_angle_deg, 45.0)
	match int(snapped_angle) % 360:
		0:
			facing = Vector2i.UP
		45:
			facing = Vector2i(1, -1)
		90:
			facing = Vector2i.RIGHT
		135:
			facing = Vector2i(1,  1)
		180:
			facing = Vector2i.DOWN
		225:
			facing = Vector2i(-1, 1)
		270:
			facing = Vector2i.LEFT
		315:
			facing = Vector2i(-1, -1)
	queue_redraw()
	if _vision_tiles_node: _vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()


## Converts detection probability into a cone color (red → green)
## alpha_mult: opacity multiplier by guard state (0.4 relaxed → 1.0 chase)
static func _prob_to_color(prob: float, alpha_mult: float = 1.0) -> Color:
	## Unified TileOverlay palette — BLEND_MODE_MIX → vivid colors over the tile.
	## 5 bands: detect_0 (green) → detect_4 (red).
	var c: Color = TileOverlayClass.detect_color_for(prob)
	c.a *= alpha_mult
	return c


## Returns the cone's visual parameters by guard state
## The visual cone is intentionally smaller than the real detection cone:
## the player sees less than the guard perceives, creating a margin of hidden risk.
func _get_cone_visual_params() -> Dictionary:
	match state:
		STATE_PATROL:
			return {"range": 4, "fov": 70.0, "alpha": 0.4, "prob_mult": 0.55}
		STATE_SUSPICIOUS:
			return {"range": 6, "fov": 90.0, "alpha": 0.8, "prob_mult": 1.60}
		STATE_ALERT:
			return {"range": 7, "fov": 100.0, "alpha": 0.95, "prob_mult": 2.00}
		STATE_CHASE:
			return {"range": 7, "fov": 110.0, "alpha": 1.0, "prob_mult": 2.80}
		STATE_SEARCH:
			return {"range": 5, "fov": 120.0, "alpha": 0.7, "prob_mult": 0.80}
	## Default (relaxed)
	return {"range": 4, "fov": 70.0, "alpha": 0.4, "prob_mult": 0.55}


## Returns an Array of {delta: Vector2i, prob: float} for every tile in the vision cone
func _get_cone_tiles(p_range: int = -1, p_fov: float = -1, p_facing_deg: float = -1.0) -> Array:
	var params       := _get_cone_visual_params()
	var vis_range: int   = p_range if p_range > 0 else int(params["range"])
	var vis_fov: float   = p_fov if p_fov > 0 else float(params["fov"])
	var vis_facing: float = p_facing_deg if p_facing_deg >= 0 else facing_angle_deg

	var prob_mult: float = params["prob_mult"]
	var half_fov := vis_fov / 2.0
	var tiles := []

	for dx in range(-vis_range, vis_range + 1):
		for dy in range(-vis_range, vis_range + 1):
			if dx == 0 and dy == 0:
				continue
			var delta := Vector2i(dx, dy)
			var dist := absi(dx) + absi(dy)
			if dist > vis_range:
				continue

			## Angular check
			var to_angle := rad_to_deg(atan2(float(dx), float(-dy)))
			var angle_diff := wrapf(to_angle - vis_facing, -180.0, 180.0)
			if absf(angle_diff) > half_fov:
				continue

			## Base probability by distance
			var base_prob: float = FOV_DISTANCE_CURVE[dist] if dist < FOV_DISTANCE_CURVE.size() else 0.0

			## Lateral multiplier by distance to the central axis
			var lateral_offset := absf(angle_diff) / half_fov  ## 0.0 at center, 1.0 at edge
			var lateral_idx := mini(int(lateral_offset * FOV_LATERAL_FALLOFF.size()), FOV_LATERAL_FALLOFF.size() - 1)
			var lateral_mult := FOV_LATERAL_FALLOFF[lateral_idx]

			var final_prob := base_prob * lateral_mult * prob_mult

			## Apply shadow modifier if tile is in penumbra
			var target_cell := cell + delta
			if _shadow_tiles.has(target_cell):
				final_prob *= _shadow_tiles[target_cell]

			## Clamp to avoid negatives from multiplier accumulation (unlikely here)
			final_prob = maxf(final_prob, 0.0)

			tiles.append({"delta": delta, "prob": final_prob})

	return tiles


func _update_debug_label() -> void:
	if _debug_label_container == null:
		return

	_debug_label_container.visible = dev_vision

	if not dev_vision:
		return

	## Position: well above the guard's head in local coordinates
	## -320 in Y places label far above the sprite, no overlap
	_debug_label_container.position = Vector2(-150.0, -350.0)

	var last := "—"
	if last_known_agent_cell != INVALID_CELL:
		last = "%d,%d" % [last_known_agent_cell.x, last_known_agent_cell.y]

	_debug_label.text = (
		"id: %s\n" % enemy_id +
		"state: %s\n" % state +
		"cell: %d,%d\n" % [cell.x, cell.y] +
		"facing: %s\n" % _facing_name() +
		"last_known: %s" % last
	)

	if _comms_label_timer > 0.0:
		_debug_label.text += "\n📡 COMMS"


func _facing_name() -> String:
	match facing:
		Vector2i.UP:         return "N"
		Vector2i(1, -1):     return "NE"
		Vector2i.RIGHT:      return "E"
		Vector2i(1, 1):      return "SE"
		Vector2i.DOWN:       return "S"
		Vector2i(-1, 1):     return "SW"
		Vector2i.LEFT:       return "W"
		Vector2i(-1, -1):    return "NW"
	return "?"


func _is_inside(pos: Vector2i, room_size: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < room_size.x and pos.y < room_size.y


func _is_edge_blocked(from_cell: Vector2i, to_cell: Vector2i, blocked_edges: Dictionary) -> bool:
	var key := WallEdgeData.edge_key(from_cell, to_cell)
	return blocked_edges.has(key)


func can_see_cell(target_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary) -> bool:
	var current: Vector2i = cell
	var dx := target_cell.x - current.x
	var dy := target_cell.y - current.y
	var step_x: int = signi(dx)
	var step_y: int = signi(dy)
	var abs_dx: int = abs(dx)
	var abs_dy: int = abs(dy)
	var err: int = abs_dx - abs_dy

	while current != target_cell:
		var e2 := err * 2
		var next_cell := current
		var move_x := false
		var move_y := false

		if e2 > -abs_dy:
			next_cell.x += step_x
			err -= abs_dy
			move_x = true
		if e2 < abs_dx:
			next_cell.y += step_y
			err += abs_dx
			move_y = true

		## Check the direct edge of this step
		if _is_edge_blocked(current, next_cell, blocked_edges):
			return false

		## NEW: if the step is diagonal, also check the two split edges
		## Prevents diagonal rays from "slipping" through wall corners
		if move_x and move_y:
			var split_h := Vector2i(current.x + step_x, current.y)  ## horizontal-only step
			var split_v := Vector2i(current.x, current.y + step_y)  ## vertical-only step
			if _is_edge_blocked(current, split_h, blocked_edges):
				return false
			if _is_edge_blocked(current, split_v, blocked_edges):
				return false

		if blocked_cells.has(next_cell) and next_cell != target_cell:
			return false
		current = next_cell
	return true


func _enter_state(new_state: String) -> void:
	state = new_state
	if new_state != STATE_PATROL:
		idle_turns_remaining = 0
		_is_rotating = false

	if new_state == STATE_SEARCH:
		_search_turns_remaining = SEARCH_TURNS_MAX
		if last_known_agent_cell != INVALID_CELL:
			_build_search_queue(last_known_agent_cell, _los_blocked_cells, _room_size_cached)
	elif new_state == STATE_ALERT:
		whistled.emit(cell, last_known_agent_cell)
	elif new_state == STATE_CHASE:
		radioed.emit(cell, last_known_agent_cell)

	queue_redraw()
	if _vision_tiles_node: _vision_tiles_node.queue_redraw()
	if _vision_smooth_node: _vision_smooth_node.queue_redraw()


func receive_alert(known_cell: Vector2i, target_state: String) -> void:
	## Do not downgrade state — only escalate
	var priority := {
		STATE_PATROL:    0,
		STATE_SUSPICIOUS: 1,
		STATE_SEARCH:    2,
		STATE_ALERT:     3,
		STATE_CHASE:     4,
	}

	var current_prio: int = priority.get(state, 0)
	var target_prio: int = priority.get(target_state, 0)

	if target_prio > current_prio:
		last_known_agent_cell = known_cell
		_enter_state(target_state)
		state_timer = TIMER_ALERT_TO_CHASE if target_state == STATE_ALERT else 3
		_comms_label_timer = COMMS_LABEL_DURATION

		## React immediately (external vision/AI may override later)
		attention.focus(known_cell, 0.9, 0.5)

		if _vision_tiles_node: _vision_tiles_node.queue_redraw()
		if _vision_smooth_node: _vision_smooth_node.queue_redraw()
		_update_debug_label()


## ID-01: Receives a visual detection notification with severity-based escalation.
## severity 1 → SUSPICIOUS · severity 2 → ALERT · severity 3 → CHASE
## Never downgrades the state — only escalates (or refreshes the timer at the same level).
func observe_player(player_visible: bool, severity: int, player_cell: Vector2i) -> void:
	if not player_visible:
		_update_debug_label()
		return

	last_known_agent_cell = player_cell

	var _state_priority := {
		STATE_PATROL:     0,
		STATE_SUSPICIOUS: 1,
		STATE_SEARCH:     2,
		STATE_ALERT:      3,
		STATE_CHASE:      4,
	}

	var target_state: String
	var target_timer: int
	match severity:
		3:
			target_state = STATE_CHASE
			target_timer = TIMER_CHASE_TO_SEARCH
		2:
			target_state = STATE_ALERT
			target_timer = TIMER_ALERT_TO_CHASE
		_:  ## severity 1
			target_state = STATE_SUSPICIOUS
			target_timer = TIMER_SUSPICIOUS_TO_PATROL

	var current_prio: int = _state_priority.get(state, 0)
	var target_prio: int  = _state_priority.get(target_state, 0)

	if target_prio > current_prio:
		## Escalate to the new state
		_enter_state(target_state)
		state_timer = target_timer
	elif target_prio == current_prio:
		## Same state: refreshing the timer prevents de-escalation while the agent is visible
		state_timer = target_timer
	## target_prio < current_prio: never downgrade

	_update_debug_label()


## M2-05: Reacts to perceived noise — auditory detection
## perceived_intensity: intensity after attenuation by distance and walls
func hear_noise(noise_tile: Vector2i, perceived_intensity: float) -> void:
	## Accumulate auditory detection — always, regardless of the threshold
	detection = clampf(detection + perceived_intensity * 0.5, 0.0, 1.0)

	if perceived_intensity >= 0.6:
		## Loud noise — guard will investigate directly
		last_known_agent_cell = noise_tile
		if state == STATE_PATROL:
			_enter_state(STATE_SUSPICIOUS)
			state_timer = TIMER_NOISE_SUSPICIOUS
	elif perceived_intensity >= 0.25:
		## Medium noise — guard gets tense but does not know where
		if state == STATE_PATROL:
			_enter_state(STATE_SUSPICIOUS)
			state_timer = TIMER_NOISE_SUSPICIOUS_MED
	## Faint noise (< 0.25): ignored

	_update_debug_label()
	if dev_vision:
		queue_redraw()
		if _vision_tiles_node: _vision_tiles_node.queue_redraw()
		if _vision_smooth_node: _vision_smooth_node.queue_redraw()


func tick_state() -> void:
	if state == STATE_PATROL:
		return

	if state == STATE_SEARCH:
		_search_turns_remaining -= 1
		if _search_turns_remaining <= 0:
			_enter_state(STATE_SUSPICIOUS)
			state_timer = TIMER_SEARCH_TO_SUSPICIOUS
			_search_queue.clear()
		return

	state_timer -= 1
	if state_timer <= 0:
		if state == STATE_ALERT:
			_enter_state(STATE_CHASE)
			state_timer = TIMER_ALERT_TO_CHASE
		elif state == STATE_SUSPICIOUS:
			_enter_state(STATE_PATROL)
			last_known_agent_cell = INVALID_CELL
		elif state == STATE_CHASE:
			if last_known_agent_cell != INVALID_CELL:
				_enter_state(STATE_SEARCH)
			else:
				_enter_state(STATE_SUSPICIOUS)
				state_timer = TIMER_CHASE_TO_SEARCH

	if dev_vision:
		queue_redraw()


func _do_idle_behavior() -> void:
	if state != STATE_PATROL:
		return

	## If already rotating, advance 45° toward the destination
	if _is_rotating:
		var diff := wrapf(_target_facing_angle - facing_angle_deg, -180.0, 180.0)
		if absf(diff) < 1.0:
			_is_rotating = false
		else:
			facing_angle_deg = wrapf(facing_angle_deg + signf(diff) * 45.0, 0.0, 360.0)
			_update_facing_from_angle()
		return

	## Pick a new random destination if not rotating
	if randf() < 0.3:
		var candidates := []
		for a in _look_angles:
			var diff := wrapf(a - facing_angle_deg, -180.0, 180.0)
			if absf(diff) >= 45.0:
				candidates.append(a)
		if not candidates.is_empty():
			_target_facing_angle = candidates[randi() % candidates.size()]
			_is_rotating = true

			## Visual scan: move the head slightly before the body
			var scan_dir := Vector2i(roundi(sin(deg_to_rad(_target_facing_angle))), roundi(-cos(deg_to_rad(_target_facing_angle))))
			attention.focus(cell + scan_dir, 0.9, 0.45)

	## Chance of an extra pause (~20%)
	if randf() < 0.2:
		idle_turns_remaining = randi_range(1, 2)


func choose_next_cell(
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		player_cell: Vector2i,
		room_size: Vector2i
) -> Vector2i:
	if state == STATE_PATROL:
		if idle_turns_remaining > 0:
			idle_turns_remaining -= 1
			_do_idle_behavior()
			return cell

		var next := pick_next_patrol_cell(occupied_cells, blocked_cells, blocked_edges, room_size)

		if next == cell:
			_do_idle_behavior()

		return next

	if state == STATE_SUSPICIOUS:
		if last_known_agent_cell != INVALID_CELL:
			return _step_toward(last_known_agent_cell, occupied_cells, blocked_cells, blocked_edges, room_size)
		return cell
	if state == STATE_ALERT or state == STATE_CHASE:
		var target := player_cell
		if last_known_agent_cell != INVALID_CELL:
			target = last_known_agent_cell
		return _step_toward(target, occupied_cells, blocked_cells, blocked_edges, room_size)

	if state == STATE_SEARCH:
		## Empty queue: already swept everything, stay put until tick_state de-escalates
		if _search_queue.is_empty():
			return cell

		var target := _search_queue[0]

		## Not there yet: move one step toward the target tile
		if cell != target:
			attention.focus(target, 0.85, 1.0)
			return _step_toward(target, occupied_cells, blocked_cells, blocked_edges, room_size)

		## Reached the tile: observe for one turn, then remove it from the queue
		_search_queue.remove_at(0)
		if not _search_queue.is_empty():
			attention.focus(_search_queue[0], 0.9, 1.2)
		return cell

	return cell


func _step_toward(
		target_cell: Vector2i,
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> Vector2i:
	## Replan if target changed or path exhausted
	if target_cell != _cached_target or _path_index >= _cached_path.size():
		_cached_target = target_cell
		_cached_path = GuardPathfinder.find_path(cell, target_cell, blocked_cells, blocked_edges, room_size)
		_path_index = 1

	## No path found
	if _cached_path.is_empty():
		return cell

	## Path exhausted (shouldn't happen, but failsafe)
	if _path_index >= _cached_path.size():
		return cell

	## Get next step from path
	var next_cell: Vector2i = _cached_path[_path_index]
	_path_index += 1

	## Skip if occupied
	if occupied_cells.has(next_cell):
		return cell

	return next_cell




func _draw_vision_tiles() -> void:
	## Vision cone colored by probability — tile-by-tile (MUL blending)
	var params: Dictionary = _get_cone_visual_params()
	var visual_facing_deg := wrapf(rad_to_deg(vision_angle) + 90.0, 0.0, 360.0)

	var alpha_mult: float = params["alpha"]
	var cone_tiles  := _get_cone_tiles(params["range"], fov_degrees, visual_facing_deg)

	## Dimensions of the full isometric diamond (256px horizontal base)
	var hw := 128.0   ## horizontal half-width
	var hh := 64.0    ## vertical half-height

	for entry in cone_tiles:
		var delta: Vector2i = entry["delta"]
		var prob: float     = entry["prob"]
		var target_cell     := cell + delta

		if not can_see_cell(target_cell, _los_blocked_cells, _los_blocked_edges):
			continue

		var world_pos := _cell_to_world(target_cell) - position
		var diamond := PackedVector2Array([
			world_pos + Vector2(0.0,  -hh),
			world_pos + Vector2(hw,   0.0),
			world_pos + Vector2(0.0,   hh),
			world_pos + Vector2(-hw,  0.0),
		])

		var color := _prob_to_color(prob, alpha_mult)
		## M2-05: If in multiply mode, drop the debug outline and paint the full color
		_vision_tiles_node.draw_colored_polygon(diamond, color)


func _draw_vision_smooth() -> void:
	var params: Dictionary = _get_cone_visual_params()
	var v_fov: float  = params["fov"]
	var visual_facing_deg := wrapf(rad_to_deg(vision_angle) + 90.0, 0.0, 360.0)

	var points := PackedVector2Array()
	var colors  := PackedColorArray()

	points.append(Vector2.ZERO)
	colors.append(COLOR_VISION_SMOOTH)

	var steps := 32   ## smoother than 24
	var half_fov := v_fov / 2.0

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		## Grid angle: -half_fov to +half_fov
		var grid_ang_deg: float = visual_facing_deg + lerp(-half_fov, half_fov, t)
		var grid_ang_rad: float = deg_to_rad(grid_ang_deg)

		## Grid direction: 0=North uses atan2(dx, -dy), so:
		## dx = sin(grid_ang_rad)
		## dy = -cos(grid_ang_rad)
		var gdx := sin(grid_ang_rad)
		var gdy := -cos(grid_ang_rad)

		## Check LOS along this ray — use the nearest blocked tile
		var hw := 128.0
		var hh := 64.0
		var effective_range := 0.0

		## Compute v_range in pixels for this specific direction
		var max_iso_vec := Vector2((gdx - gdy) * (params["range"] - 0.5) * hw, (gdx + gdy) * (params["range"] - 0.5) * hh)
		var max_dist := max_iso_vec.length()
		effective_range = max_dist

		for step in range(1, params["range"] + 1):
			var check_cell := cell + Vector2i(roundi(gdx * step), roundi(gdy * step))
			if not can_see_cell(check_cell, _los_blocked_cells, _los_blocked_edges):
				## Cut the visual range on this ray: stop at the edge (0.5 tiles away)
				var cut_iso_vec := Vector2((gdx - gdy) * (float(step) - 0.5) * hw, (gdx + gdy) * (float(step) - 0.5) * hh)
				effective_range = cut_iso_vec.length()
				break

		var iso_dir := Vector2(gdx - gdy, (gdx + gdy) * 0.5).normalized()
		points.append(iso_dir * effective_range)

		var edge_color := COLOR_VISION_SMOOTH
		edge_color.a = 0.0
		colors.append(edge_color)

	_vision_smooth_node.draw_polygon(points, colors)


func _draw() -> void:
	var shadow := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(26.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-26.0, 0.0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)

	var body := PackedVector2Array([
		Vector2(0.0, -54.0),
		Vector2(20.0, -30.0),
		Vector2(0.0, -8.0),
		Vector2(-20.0, -30.0),
	])
	draw_colored_polygon(body, COLOR_BODY)
	draw_polyline(body + PackedVector2Array([body[0]]), COLOR_BODY_DARK, 3.0)
	draw_circle(Vector2(0.0, -62.0), 9.0, COLOR_HEAD)

	var p1 := Vector2(0.0, -82.0)
	var fang := deg_to_rad(facing_angle_deg)
	var fdx  := sin(fang)
	var fdy  := -cos(fang)
	var iso  := Vector2((fdx - fdy) * 128.0, (fdx + fdy) * 64.0).normalized()
	var p2   := p1 + iso * 22.0
	draw_line(p1, p2, Color(1.0, 0.9, 0.5, 0.95), 3.0)

	## DEV_VISION extras — only visible when dev_vision mode is active
	if not dev_vision:
		return

	## Draw patrol route as dashed line connecting waypoints
	if patrol_route.size() >= 2:
		for i in range(patrol_route.size()):
			var a := _cell_to_world(patrol_route[i]) - position
			var b := _cell_to_world(patrol_route[(i + 1) % patrol_route.size()]) - position
			draw_dashed_line(a, b, Color(0.4, 0.8, 1.0, 0.6), 2.0, 8.0)
			draw_circle(a, 5.0, Color(0.4, 0.8, 1.0, 0.8))

	## Dev 05: detection meter arc
	var arc_center := Vector2(0.0, -82.0)
	var arc_radius := 18.0
	var arc_start := PI * 1.1        ## ~200° — opens at bottom
	var arc_end := PI * 1.9          ## ~340° — closes at bottom
	var arc_steps := 24

	## Gray background arc
	draw_arc(arc_center, arc_radius, arc_start, arc_end, arc_steps,
		 Color(0.2, 0.2, 0.2, 0.7), 4.0, true)

	## Colored detection fill proportional to detection value
	if detection > 0.0:
		var filled_end := arc_start + (arc_end - arc_start) * detection
		var fill_color: Color
		if detection <= 0.35:
			fill_color = Color(1.0, 0.7, 0.1, 0.85)  ## Orange for suspicious
		elif detection <= 0.65:
			fill_color = Color(1.0, 0.5, 0.1, 0.85)  ## Orange-red for alert
		else:
			fill_color = Color(1.0, 0.2, 0.2, 0.85)  ## Red for chase
		draw_arc(arc_center, arc_radius, arc_start, filled_end, arc_steps,
			fill_color, 4.0, true)

		## Percentage text
		var pct_text := "%d%%" % roundi(detection * 100.0)
		draw_string(
			ThemeDB.fallback_font,
			arc_center + Vector2(-12.0, 8.0),
			pct_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			10,
			Color(1.0, 1.0, 1.0, 0.95)
		)
