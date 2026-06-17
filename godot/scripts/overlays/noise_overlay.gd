extends Node2D
## Shows persistent noise on the grid as sound waves.
## Always visible (not only in DEV_VISION) — it is gameplay information.

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
	z_index = 140   ## below the trail (150) but above the movement overlay


func _draw() -> void:
	if _noise_system == null:
		return

	for tile in _noise_system.get_noisy_tiles():
		var intensity: float = _noise_system.get_intensity(tile)
		if intensity <= 0.0:
			continue

		var world_pos := _cell_to_world(tile)

		## Concentric sound waves: 3 circles with fading
		var base_radius := 8.0
		var alpha_mult := intensity

		## Wave 1: largest, most faded
		var r1 := base_radius + 6.0
		var c1 := Color(0.4, 0.9, 1.0, 0.15 * alpha_mult)
		draw_circle(world_pos, r1, c1)

		## Wave 2: medium
		var r2 := base_radius + 3.0
		var c2 := Color(0.2, 0.8, 1.0, 0.35 * alpha_mult)
		draw_circle(world_pos, r2, c2)

		## Wave 3: smallest, brightest (core)
		var r3 := base_radius
		var c3 := Color(0.0, 0.7, 1.0, 0.55 * alpha_mult)
		draw_circle(world_pos, r3, c3)


func _cell_to_world(cell: Vector2i) -> Vector2:
	if _floor_layer == null:
		return Vector2.ZERO
	return _floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + _visual_offset
