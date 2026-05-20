extends Node2D
## Room controller — M1 prototype
##
## Grid math:
##   - 1 logical cell = Vector2i(col, row)
##   - Screen size: 256 × 128 px per cell (2:1 isometric diamond)
##   - map_to_local(cell) → world position at the CENTER of that diamond
##   - No sub-tiles: each cell is floor, wall, or empty
##   - wall_N/E/S/W = thin panel (~1/4 visual depth of a block cube)
##   - Wall orientation per edge:
##       top row (y=0)   → wall_N  (back-left face, visible to camera)
##       right col (x=W) → wall_E  (back-right face, visible to camera)
##       bottom/left     → wall_S/W (front-facing, add depth)
##       4 outer corners → wallCorner_N / _E / _S / _W
##
## TileMapLayer nodes expected as children:
##   FloorLayer     — walkable floor tiles  (y_sort_enabled = false)
##   StructureLayer — walls, obstacles, props (y_sort_enabled = true)
##   Agent          — plain Node2D child, rendered above both layers


@onready var floor_layer:     TileMapLayer = $FloorLayer
@onready var structure_layer: TileMapLayer = $StructureLayer
@onready var camera:          Camera2D     = $Camera2D
@onready var agent:           Node2D       = $Agent
@onready var move_overlay:    Node2D       = $MoveOverlay
@onready var end_turn_btn:    Button       = $UI/EndTurnBtn

## tile_name → TileSet source_id  (built from TileSet custom data at startup)
var tiles: Dictionary = {}

## Walkable cells → movement cost (1 = normal, 2 = difficult terrain)
var _walkable: Dictionary = {}

## Current movement range result (refreshed after each agent move).
var _range = null

const MovementRange = preload("res://godot/scripts/game/movement_range.gd")

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const ROOM_W := 55   # colunas  (W+H ≈ 110 → ~3 telas de altura a zoom 0.35)
const ROOM_H := 55   # linhas

## Floor tile variants (floor_N appears 4× more = 80% plain, 20% floorHalf)
const _FLOOR_VARS := ["floor_N", "floor_N", "floor_N", "floor_N", "floorHalf_N"]
## Decorative prop tiles scattered as visual landmarks (non-walkable)
const _PROPS := ["crate_N", "crate_E", "column_N", "poleGroup_N"]


func _ready() -> void:
	var tile_set: TileSet = load(TILESET_PATH)
	if tile_set == null:
		push_error("TileSet not found at %s — run build_tileset.gd first." % TILESET_PATH)
		return

	floor_layer.tile_set     = tile_set
	structure_layer.tile_set = tile_set

	_build_registry(tile_set)
	_make_test_room(ROOM_W, ROOM_H)

	# Place agent at room center
	var center := Vector2i(ROOM_W / 2, ROOM_H / 2)
	agent.initialize(center, floor_layer)

	# Snap camera to agent on first frame
	camera.global_position = agent.global_position

	# Wire up overlay and turn signals
	move_overlay.setup(floor_layer)
	TurnManager.phase_changed.connect(_on_phase_changed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	# Show movement range for the first player turn
	_refresh_overlay()


func _process(_delta: float) -> void:
	camera.global_position = agent.global_position


## Build name→id lookup from TileSet custom data.
func _build_registry(tile_set: TileSet) -> void:
	for i in tile_set.get_source_count():
		var sid := tile_set.get_source_id(i)
		var src := tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var td := src.get_tile_data(Vector2i(0, 0), 0)
		if td:
			tiles[td.get_custom_data("tile_name")] = sid
	print("[Room] Registry built: %d tiles loaded." % tiles.size())


## Place a single tile on a layer. Logs a warning for unknown names.
func place(layer: TileMapLayer, cell: Vector2i, tile_name: String) -> void:
	var sid: int = tiles.get(tile_name, -1)
	if sid == -1:
		push_warning("[Room] Unknown tile: '%s'" % tile_name)
		return
	layer.set_cell(cell, sid, Vector2i(0, 0))


## Choose the correct thin-wall tile for each border cell.
## N/E face the camera (most visible); S/W face forward (add depth at front).
func _wall_tile_for(x: int, y: int, W: int, H: int) -> String:
	var top    := (y == 0)
	var bottom := (y == H - 1)
	var left   := (x == 0)
	var right  := (x == W - 1)

	if top    and left:  return "wallCorner_N"
	if top    and right: return "wallCorner_E"
	if bottom and right: return "wallCorner_S"
	if bottom and left:  return "wallCorner_W"

	if top:    return "wall_N"
	if right:  return "wall_E"
	if bottom: return "wall_S"
	if left:   return "wall_W"
	return "floor_N"  # fallback (unreachable)


## Generate a rectangular room (W×H cells).
## Border → oriented thin wall tiles.  Interior → floor tiles + scattered props.
func _make_test_room(W: int, H: int) -> void:
	_walkable.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331  # fixed seed → reproducible layout
	for x in range(W):
		for y in range(H):
			var cell := Vector2i(x, y)
			var is_border := (x == 0 or x == W - 1 or y == 0 or y == H - 1)
			if is_border:
				place(structure_layer, cell, _wall_tile_for(x, y, W, H))
			else:
				# Mix floor variants for visual variety
				place(floor_layer, cell, _FLOOR_VARS[rng.randi() % _FLOOR_VARS.size()])
				# Scatter props as visual landmarks (Chebyshev distance > 5 from agent start)
				var dist := maxi(abs(x - W / 2), abs(y - H / 2))
				if dist > 5 and rng.randf() < 0.045:
					place(structure_layer, cell, _PROPS[rng.randi() % _PROPS.size()])
					# prop cell: not walkable (omit from _walkable)
				else:
					_walkable[cell] = 1
	print("[Room] Test room generated: %d×%d." % [W, H])


## Returns true if the agent may move to this cell.
func _is_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell)


## Recompute movement zones from agent's current position and show the overlay.
func _refresh_overlay() -> void:
	_range = MovementRange.compute(agent.cell, _walkable, agent.ap)
	move_overlay.show_range(_range)


## TurnManager callback.
func _on_phase_changed(new_phase: TurnManager.Phase) -> void:
	match new_phase:
		TurnManager.Phase.PLAYER:
			agent.reset_turn()
			end_turn_btn.disabled = false
			_refresh_overlay()
		TurnManager.Phase.ENEMY:
			move_overlay.hide_range()
			end_turn_btn.disabled = true


func _on_end_turn_pressed() -> void:
	TurnManager.end_player_turn()


## Click to move — resolves which AP zone was clicked and spends accordingly.
func _unhandled_input(event: InputEvent) -> void:
	if TurnManager.phase != TurnManager.Phase.PLAYER:
		return
	if agent.is_moving:
		return  # block clicks during movement animation
	if not (event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var world_pos := get_global_mouse_position()
	var local_pos := floor_layer.to_local(world_pos)
	var clicked   := floor_layer.local_to_map(local_pos)

	if _range == null:
		return

	# Determine AP cost from which zone was clicked.
	var ap_cost: int
	if _range.zone1.has(clicked):
		ap_cost = 1
	elif _range.zone2.has(clicked) or _range.dash.has(clicked):
		ap_cost = 2
	else:
		return   # cell not reachable this turn

	if agent.ap < ap_cost:
		return

	# Hide overlay during movement; show updated range once agent arrives.
	agent.spend_ap(ap_cost)
	move_overlay.hide_range()
	_range = null
	agent.move_to(clicked, floor_layer, func() -> void:
		if agent.ap > 0:
			_refresh_overlay()
	)
