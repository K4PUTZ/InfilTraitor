## WorldMarkersOverlayController
## Manages shadow spill cosmetics and marker overlays (shadow boundary, light rays).
## Shadow spill is a cosmetic halo that bleeds from full-shadow tiles onto neighbours.
## Purely visual — never feeds gameplay (ExposureSystem reads raw geometry).

class_name WorldMarkersOverlayController

## Shadow spill constants: reach, density, and color falloff parameters.
const SHADOW_SPILL_RADIUS := 2
const SHADOW_SPILL_MAX_RADIUS := 4        ## hard cap on density-extended reach
const SHADOW_SPILL_DENSITY_STEP := 2      ## +1 ring per this many clustered full cells
const SHADOW_SPILL_BASE_DARKEN := 0.18    ## ring-1 orthogonal darkening (1 - keeps)
const SHADOW_SPILL_FALLOFF := 0.5         ## darkening multiplier per further ring
const SHADOW_SPILL_DIAGONAL_FACTOR := 0.65  ## diagonal keeps lighter than orthogonal
const PENUMBRA_MULT := 0.5  ## used in debug draws

var room: Node
var _tile_shadow: Node2D = null
var _lighting_controller: Node = null
var _shadow_boundary_overlay: Node = null
var _light_ray_overlay: Node = null
var _vision_controller: Node = null
var floor_layer: Node2D = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _room_size: Vector2i = Vector2i.ZERO
var _shadow_tiles: Dictionary = {}  ## used in debug draw


func _init(p_room: Node) -> void:
	room = p_room


func setup(tile_shadow: Node2D, lighting_controller: Node, shadow_boundary: Node,
		light_ray: Node, vision_controller: Node, floor_layer_ref: Node2D, visual_offset: Vector2,
		room_size: Vector2i, shadow_tiles: Dictionary) -> void:
	_tile_shadow = tile_shadow
	_lighting_controller = lighting_controller
	_shadow_boundary_overlay = shadow_boundary
	_light_ray_overlay = light_ray
	_vision_controller = vision_controller
	floor_layer = floor_layer_ref
	_visual_grid_offset = visual_offset
	_room_size = room_size
	_shadow_tiles = shadow_tiles


## Paint the always-on world shadow layer from the geometric exposure result.
## Floor shadows are real-world elements (always visible), not a debug overlay:
## the multiply-blend `_tile_shadow` darkens shadowed floor under every vision mode.
func repaint_world_shadows() -> void:
	if _tile_shadow == null:
		return
	var exposure = _lighting_controller.get_exposure_system()
	if exposure == null:
		return
	_tile_shadow.clear_all()
	var full_cells: Array[Vector2i] = exposure.get_shadow_cells()
	var penumbra_cells: Array[Vector2i] = exposure.get_penumbra_cells()
	## Cosmetic halo first (lowest visual weight), real shadow tiles on top so the
	## geometric silhouette stays crisp where it matters.
	var spill: Dictionary = _compute_shadow_spill(full_cells, penumbra_cells)
	var TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")
	_tile_shadow.set_cells_colored(spill, TileOverlayClass.PRIO_SHADOW)
	_tile_shadow.set_cells_named(penumbra_cells, "shadow_lite", TileOverlayClass.PRIO_SHADOW)
	_tile_shadow.set_cells_named(full_cells, "shadow_full", TileOverlayClass.PRIO_SHADOW)

	## Update shadow boundary overlay with separate full and lite shadow cells
	if _shadow_boundary_overlay != null:
		_shadow_boundary_overlay.set_full_shadow_cells(full_cells)
		_shadow_boundary_overlay.set_lite_shadow_cells(penumbra_cells)

	## Refresh light ray overlay with the latest per-light shadow projections
	if _light_ray_overlay != null:
		_light_ray_overlay.refresh(_lighting_controller.get_shadow_results())


## Build the cosmetic spill halo around the FULL-shadow tiles.
## Returns Vector2i → Color (multiply tint). Each spill cell's tone comes from its ring
## distance to the nearest full cell and whether that offset is orthogonal (darker) or
## diagonal (lighter); the reach grows with local cluster density. Cells already shadowed
## (full/penumbra) are excluded so the halo never lightens a real shadow; clamped to room.
func _compute_shadow_spill(full_cells: Array[Vector2i], penumbra_cells: Array[Vector2i]) -> Dictionary:
	var occupied: Dictionary = {}  ## cells that must NOT receive spill
	for c: Vector2i in full_cells:
		occupied[c] = true
	for c: Vector2i in penumbra_cells:
		occupied[c] = true
	var full_set: Dictionary = {}
	for c: Vector2i in full_cells:
		full_set[c] = true
	## best[cell] = {"level": ring, "ortho": bool}; darkest wins (lowest ring, ortho on tie).
	var best: Dictionary = {}
	for c: Vector2i in full_cells:
		var reach: int = _spill_reach_for(c, full_set)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx == 0 and dy == 0:
					continue
				var level: int = maxi(absi(dx), absi(dy))  ## Chebyshev ring
				if level > reach:
					continue
				var cell := c + Vector2i(dx, dy)
				if occupied.has(cell):
					continue
				if cell.x < 0 or cell.y < 0 or cell.x >= _room_size.x or cell.y >= _room_size.y:
					continue
				var ortho: bool = (dx == 0 or dy == 0)
				if not best.has(cell):
					best[cell] = {"level": level, "ortho": ortho}
				else:
					var b: Dictionary = best[cell]
					if level < b["level"] or (level == b["level"] and ortho and not b["ortho"]):
						best[cell] = {"level": level, "ortho": ortho}
	var out: Dictionary = {}
	for cell: Vector2i in best:
		out[cell] = _spill_color(best[cell]["level"], best[cell]["ortho"])
	return out


## Spill reach (ring count) for a full cell: base radius + 1 per density step of clustered
## full neighbours, capped. Denser real-shadow masses (e.g. tall crate stacks) glow wider.
func _spill_reach_for(cell: Vector2i, full_set: Dictionary) -> int:
	var density: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if full_set.has(cell + Vector2i(dx, dy)):
				density += 1
	return clampi(
		SHADOW_SPILL_RADIUS + int(float(density) / SHADOW_SPILL_DENSITY_STEP),
		SHADOW_SPILL_RADIUS, SHADOW_SPILL_MAX_RADIUS)


## Multiply tint for a spill cell at ring `level` (1 = closest), orthogonal or diagonal.
## Darkening falls off geometrically per ring; diagonals keep lighter than orthogonals.
## Cool-blue tone (blue darkens least), matching the shadow ramp. Returns a >0.8 keeps value.
func _spill_color(level: int, ortho: bool) -> Color:
	var darken: float = SHADOW_SPILL_BASE_DARKEN * pow(SHADOW_SPILL_FALLOFF, float(level - 1))
	if not ortho:
		darken *= SHADOW_SPILL_DIAGONAL_FACTOR
	var keeps: float = clampf(1.0 - darken, 0.0, 1.0)
	return Color(keeps, keeps, minf(1.0, keeps + 0.05), 1.0)


func draw_shadow_debug() -> void:
	## M2-13: ShadowOverlay now handles the permanent visualization.
	## Kept only for technical debug in DEV_VISION (translucent blue overlay).
	if not _vision_controller.dev_vision:
		return
	for shadow_cell in _shadow_tiles.keys():
		var mult: float = _shadow_tiles[shadow_cell]
		var world_pos: Vector2 = floor_layer.map_to_local(shadow_cell) + _visual_grid_offset
		var hw := 128.0   ## 256 / 2
		var hh := 64.0    ## 128 / 2
		var diamond := PackedVector2Array([
			world_pos + Vector2(0.0,  -hh),
			world_pos + Vector2(hw,   0.0),
			world_pos + Vector2(0.0,   hh),
			world_pos + Vector2(-hw,  0.0),
		])
		## Direct shadow: dark blue. Penumbra: lighter blue.
		var alpha := 0.35 if mult < PENUMBRA_MULT else 0.15
		var color := Color(0.1, 0.4, 1.0, alpha)
		room.draw_colored_polygon(diamond, color)
