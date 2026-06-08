extends Node2D
## Mostra barulhos persistentes no grid como ondas sonoras.
## Visível sempre (não só em DEV_VISION) — é informação de gameplay.

var _room_ref: Node2D = null
var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO
var _noise_system = null


func setup(
	room_ref: Node2D,
	floor_layer: TileMapLayer,
	visual_offset: Vector2,
	noise_system
) -> void:
	_room_ref       = room_ref
	_floor_layer    = floor_layer
	_visual_offset  = visual_offset
	_noise_system   = noise_system
	z_index = 140   ## abaixo do trail (150) mas acima do movement overlay


func _draw() -> void:
	if _noise_system == null:
		return

	for tile in _noise_system.get_noisy_tiles():
		var intensity: float = _noise_system.get_intensity(tile)
		if intensity <= 0.0:
			continue

		var world_pos := _cell_to_world(tile)

		## Ondas sonoras concêntricas: 3 círculos com fading
		var base_radius := 8.0
		var alpha_mult := intensity

		## Onda 1: maior, mais desbotada
		var r1 := base_radius + 6.0
		var c1 := Color(0.4, 0.9, 1.0, 0.15 * alpha_mult)
		draw_circle(world_pos, r1, c1)

		## Onda 2: média
		var r2 := base_radius + 3.0
		var c2 := Color(0.2, 0.8, 1.0, 0.35 * alpha_mult)
		draw_circle(world_pos, r2, c2)

		## Onda 3: menor, mais brilhante (núcleo)
		var r3 := base_radius
		var c3 := Color(0.0, 0.7, 1.0, 0.55 * alpha_mult)
		draw_circle(world_pos, r3, c3)


func _cell_to_world(cell: Vector2i) -> Vector2:
	if _floor_layer == null:
		return Vector2.ZERO
	return _floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + _visual_offset
