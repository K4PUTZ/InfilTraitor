extends Node2D

## LightRayOverlay — Golden light shafts from each lamp to the vertices of its lit tiles.
##
## Each ray is drawn as: two wider soft passes (simulated gaussian glow) + one sharp 1 px
## line on top. All MIX blend. The wide passes create the smoky/haze feel; the sharp line
## gives definition without looking like a solid triangle beam.
##
## Shared vertices between adjacent tiles keep the minimum alpha — zone-edge vertices
## read as dim (shadow-first aesthetic, zero overdraw).
##
## Performance: all geometry pre-computed in refresh() and stored in packed arrays.
## _draw() iterates those arrays — zero allocation per frame. rebuild only fires
## on lighting_rebuilt (static lights: once at startup; flickering lights: ~2-4 Hz).

@export var floor_layer: TileMapLayer = null
@export var visual_offset: Vector2 = Vector2.ZERO

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

## Tuning — all var per arch rule (gameplay/visual values must be tunable)
var ray_color: Color       = Color(1.0, 0.82, 0.30, 1.0)
var alpha_full_lit: float  = 1.0    ## line alpha for fully-lit tiles
var alpha_dim: float       = 1.0    ## line alpha for dim tiles
## y-lift of the lamp above its floor cell center (must match CeilingPropOverlay:
##   WALL_FLOOR_STEP_PX * (max_floors + 0.75) — passed from room.gd setup)
var ceiling_lift: float    = 0.0

## Pre-computed draw data (reset on every refresh())
var _ray_froms:  PackedVector2Array = PackedVector2Array()
var _ray_tos:    PackedVector2Array = PackedVector2Array()
var _ray_alphas: PackedFloat32Array = PackedFloat32Array()


func setup(fl_layer: TileMapLayer, v_offset: Vector2, lift: float) -> void:
	floor_layer   = fl_layer
	visual_offset = v_offset
	ceiling_lift  = lift
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat


## Rebuild ray geometry from the latest per-light ShadowResults.
## Call this whenever lighting_rebuilt fires (room._repaint_world_shadows does this).
func refresh(shadow_results: Array) -> void:
	_ray_froms.clear()
	_ray_tos.clear()
	_ray_alphas.clear()

	if floor_layer == null:
		return

	for result in shadow_results:
		if result == null or result.source_light == null:
			continue
		var light = result.source_light
		if not light.active:
			continue

		var energy_mult: float = clampf(light.get_effective_tactical_energy(), 0.0, 1.0)
		var lamp_pos: Vector2  = _cell_to_screen(light.cell) - Vector2(0.0, ceiling_lift)

		var a_full: float = alpha_full_lit * energy_mult
		var a_dim:  float = alpha_dim      * energy_mult

		# One ray per tile, to the tile center. fully_lit takes priority if a cell
		# somehow appears in both sets (shadow system should prevent this, but defensive).
		var seen: Dictionary = {}
		for cell: Vector2i in result.fully_lit_tiles:
			seen[cell] = a_full
		for cell: Vector2i in result.dim_tiles:
			if not seen.has(cell):
				seen[cell] = a_dim

		for cell: Vector2i in seen.keys():
			_ray_froms.append(lamp_pos)
			_ray_tos.append(_cell_to_screen(cell))
			_ray_alphas.append(seen[cell])

	queue_redraw()


func _draw() -> void:
	for i: int in _ray_froms.size():
		_draw_ray(_ray_froms[i], _ray_tos[i], _ray_alphas[i])



## Draw one ray: sharp 2 px line at full alpha.
func _draw_ray(from: Vector2, to: Vector2, alpha: float) -> void:
	if (to - from).length_squared() < 1.0:
		return
	var c := ray_color
	draw_line(from, to, Color(c.r, c.g, c.b, alpha), 2.0)


func _cell_to_screen(cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(cell) + TILE_CENTER_OFFSET + visual_offset
