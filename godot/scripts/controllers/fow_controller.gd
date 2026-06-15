extends Node

## MODULARIZE-05: Gerencia quais tiles foram revelados pelo agente e os
## parâmetros do vision fog shader. NÃO controla visibilidade do node FOW —
## isso é responsabilidade do VisionController.

var _room: Node2D
var _fog_of_war: FogOfWarOverlay
var _fog_rect: ColorRect


func setup(room_ref: Node2D, fog_of_war_ref: FogOfWarOverlay, fog_rect_ref: ColorRect) -> void:
	_room = room_ref
	_fog_of_war = fog_of_war_ref
	_fog_rect = fog_rect_ref


## Inicializa o fog overlay para uma nova sala.
func initialize_fog(floor_layer: TileMapLayer, visual_offset: Vector2, room_size: Vector2i) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.setup(floor_layer, visual_offset, room_size)


## Revela todos os tiles num raio Euclidiano ao redor do centro.
func reveal_around(center: Vector2i, radius: int) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reveal_around(center, radius)


## Limpa todas as reveals permanentes (ex: ao carrega uma nova sala).
func reset_fog() -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reset_fog()


## Adiciona uma reveal temporária para o mechanic de peek.
func add_peek_reveal(cell: Vector2i) -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.add_peek_reveal(cell)


## Remove todas as reveals temporárias de peek.
func reset_peek_reveals() -> void:
	if _fog_of_war == null:
		return
	_fog_of_war.reset_peek_reveals()


## Verifica se um tile foi revelado permanentemente.
func is_cell_revealed(cell: Vector2i) -> bool:
	if _fog_of_war == null:
		return false
	return _fog_of_war.is_cell_revealed(cell)


## Atualiza os parâmetros do shader do vision fog para rastrear a posição
## do agente na tela, com gradiente de visão que escala com zoom e viewport.
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
