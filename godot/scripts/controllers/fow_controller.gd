extends Node

## MODULARIZE-05: Manages which tiles have been revealed by the agent and the
## vision fog shader parameters. Does NOT control the FOW node visibility —
## that is the VisionController's responsibility.

var _room: Node2D
var _fog_of_war: FogOfWarOverlay
var _fog_rect: ColorRect


func setup(room_ref: Node2D, fog_of_war_ref: FogOfWarOverlay, fog_rect_ref: ColorRect) -> void:
	_room = room_ref
	_fog_of_war = fog_of_war_ref
	_fog_rect = fog_rect_ref


## Initializes the fog overlay for a new room.
func initialize_fog(floor_layer: TileMapLayer, visual_offset: Vector2, room_size: Vector2i) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.setup(floor_layer, visual_offset, room_size)


## Reveals all tiles within a Euclidean radius around the center.
func reveal_around(center: Vector2i, radius: int) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reveal_around(center, radius)


## Clears all permanent reveals (e.g. when loading a new room).
func reset_fog() -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reset_fog()


## Adds a temporary reveal for the peek mechanic.
func add_peek_reveal(cell: Vector2i) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.add_peek_reveal(cell)


## Removes all temporary peek reveals.
func reset_peek_reveals() -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reset_peek_reveals()


## Checks whether a tile has been permanently revealed.
func is_cell_revealed(cell: Vector2i) -> bool:
	if _fog_of_war == null:
		return false
	return _fog_of_war.is_cell_revealed(cell)


## Updates the vision fog shader parameters to track the agent's on-screen
## position, with a vision gradient that scales with zoom and viewport.
func update_vision_center(_agent_world_pos: Vector2, agent_screen_uv: Vector2,
                         vision_radius_tiles: float, zoom: float,
                         vp_size: Vector2) -> void:
	var mat := _fog_rect.material as ShaderMaterial
	if mat == null:
		return

	## Gradient: tight clear center (3 tiles), outer boundary pushes 9 tiles
	## beyond the FOW reveal for a very long, gradual fade into darkness.
	var vision_r_px: float = vision_radius_tiles * _room.WORLD_TILE_PX * zoom
	var outer_uv: float = (vision_r_px + 9.0 * _room.WORLD_TILE_PX * zoom) / vp_size.y
	var inner_uv: float = maxf(0.0, vision_r_px - 3.0 * _room.WORLD_TILE_PX * zoom) / vp_size.y

	mat.set_shader_parameter("agent_screen_uv", agent_screen_uv)
	mat.set_shader_parameter("fog_inner_uv", inner_uv)
	mat.set_shader_parameter("fog_outer_uv", outer_uv)
