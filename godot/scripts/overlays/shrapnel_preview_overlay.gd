extends Node2D
class_name ShrapnelPreviewOverlay

## ShrapnelPreviewOverlay — the aiming preview's shrapnel rays.
##
## Director, 2026-08-10: "simular o mecanismo de estilhaços parcialmente,
## mostrando os raios partindo do centro da GU alvo e saindo para fora, usando o
## método de overlay das lâmpadas que já estamos utilizando no LIGHT VISION."
##
## So this is LightRayOverlay's mechanism pointed at a grenade instead of a lamp:
## one straight line from the source to the centre of every cell the source
## reaches, pre-computed into packed arrays in show_rays() and merely iterated in
## _draw(). Same shape, same zero-allocation redraw.
##
## The analogy carries further than the drawing. A lamp's rays stop at walls
## because they are built from its ShadowResult; these stop at walls because they
## are built from BlastCalculator.flood_gu_rings(), the SAME wall-aware BFS the
## real detonation floods with. That is the "parcialmente" in the Director's
## note: the dome beside this overlay is a clean geometric shape that promises
## nothing about cover, and these rays are where the cover actually shows —
## a cell behind a wall simply never gets a ray.
##
## SECOND PASS (Director, same day): "podem ser um pouquinho mais compridos para
## fora, principalmente para cima (compensando a proporção 2:1 pra ficar mais
## circular), com maior número, vamos duplicar a quantidade, e pintar de preto,
## afinal são estilhaços." All three are handled below — `circularity` undoes the
## isometric squash so the star reads round, `rays_per_cell` doubles the count,
## and the colour is now iron-dark rather than a warm glow.
##
## Distinct from ShrapnelOverlay (E-FRAG), which is the decorative debris thrown
## AFTER a real blast. This one is preview-only and never touches world state.

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

## Tuning — `var` per architecture Rule 1.
## Fragments, not light: dark iron, drawn MIX so it reads as a mark on the floor.
var ray_color: Color = Color(0.05, 0.05, 0.06, 1.0)
var line_width: float = 2.0
## Per-ring alpha, index = ring distance from the target GU. Index 0 is the
## target cell itself: its "ray" has zero length, so it is skipped outright and
## the 0.0 here only documents that.
var ring_alpha: PackedFloat32Array = PackedFloat32Array([0.0, 0.70, 0.45, 0.25])

## How far past the reached cell's own centre a fragment carries. Shrapnel does
## not stop politely at a grid line.
var length_scale: float = 1.15

## How much of the isometric 2:1 squash to undo, 0 = none (rays end on the
## projected floor ellipse, so the star is twice as wide as it is tall), 1 =
## fully circular. The factor is `AXIS_X.x / AXIS_X.y` = 2.0, taken from the
## projection rather than typed in, so this stays correct if the tile ever
## changes shape.
var circularity: float = 1.0

## Fragments emitted per reached cell, fanned symmetrically around the cell's own
## direction by `spread_rad` either side of centre.
var rays_per_cell: int = 2
var spread_rad: float = 0.13

var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO

## Pre-computed draw data, rebuilt only in show_rays().
var _ray_froms: PackedVector2Array = PackedVector2Array()
var _ray_tos: PackedVector2Array = PackedVector2Array()
var _ray_alphas: PackedFloat32Array = PackedFloat32Array()


func setup(floor_layer: TileMapLayer, visual_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_offset = visual_offset
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## gu_rings: BlastCalculator.flood_gu_rings()' own output, {Vector2i -> ring int}.
func show_rays(source_gu: Vector2i, gu_rings: Dictionary) -> void:
	_ray_froms.clear()
	_ray_tos.clear()
	_ray_alphas.clear()

	if _floor_layer == null:
		push_error("[ShrapnelPreviewOverlay] setup() never ran — no floor_layer to project with")
		return

	var origin: Vector2 = _cell_to_screen(source_gu)
	var y_scale: float = lerpf(1.0, IsoProjection.AXIS_X.x / IsoProjection.AXIS_X.y, circularity)
	var fan: int = maxi(rays_per_cell, 1)

	for cell: Vector2i in gu_rings.keys():
		var ring: int = int(gu_rings[cell])
		if ring <= 0 or ring >= ring_alpha.size():
			continue
		var alpha: float = ring_alpha[ring]
		if alpha <= 0.0:
			continue

		## Undo the isometric squash on the OUTWARD vector only — the ray still
		## starts and aims at the real cell, it just carries the extra distance
		## the flattened projection would otherwise hide.
		var delta: Vector2 = _cell_to_screen(cell) - origin
		var out := Vector2(delta.x, delta.y * y_scale)

		for k: int in range(fan):
			## Symmetric fan: one ray dead-on when fan is odd, ±spread_rad
			## either side otherwise. Deterministic, so the star does not
			## shimmer while the cursor moves.
			var offset_index: float = float(k) - (float(fan) - 1.0) * 0.5
			var angle: float = offset_index * spread_rad
			var jitter: float = lerpf(0.82, 1.0, _hash01(cell, k))
			_ray_froms.append(origin)
			_ray_tos.append(origin + out.rotated(angle) * length_scale * jitter)
			_ray_alphas.append(alpha)

	visible = not _ray_froms.is_empty()
	queue_redraw()


func _draw() -> void:
	var c := ray_color
	for i: int in _ray_froms.size():
		draw_line(_ray_froms[i], _ray_tos[i],
			Color(c.r, c.g, c.b, _ray_alphas[i]), line_width)


## Deterministic [0,1) from a cell and a fan index — fragments want uneven
## lengths, but a random one would re-roll on every hover and make the whole
## star crawl. Same input, same star, every frame.
func _hash01(cell: Vector2i, k: int) -> float:
	var raw: float = sin(float(cell.x) * 127.1 + float(cell.y) * 311.7 + float(k) * 74.7) * 43758.5453
	return raw - floor(raw)


func _cell_to_screen(cell: Vector2i) -> Vector2:
	return _floor_layer.map_to_local(cell) + TILE_CENTER_OFFSET + _visual_offset


func clear() -> void:
	if _ray_froms.is_empty() and not visible:
		return
	_ray_froms.clear()
	_ray_tos.clear()
	_ray_alphas.clear()
	visible = false
	queue_redraw()
