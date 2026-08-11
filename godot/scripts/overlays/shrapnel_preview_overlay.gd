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
## Director, 2026-08-10, second revision: "não gostei dos raios pretos, vamos
## usar laranja avermelhado."
var ray_color: Color = Color(1.0, 0.42, 0.14, 1.0)
var line_width: float = 2.0
## Per-ring alpha, index = ring distance from the target GU. Index 0 is the
## target cell itself: its "ray" has zero length, so it is skipped outright and
## the 0.0 here only documents that.
var ring_alpha: PackedFloat32Array = PackedFloat32Array([0.0, 0.70, 0.45, 0.25])

## Where the fragments come FROM, in GU above the floor — "vamos subir só um
## pouquinho a altura do centro dos raios, pra ficar na posição aproximada da
## granada sobre o chão." Projected through AXIS_Z, so it is a real height, not
## a pixel nudge.
var ray_origin_lift_gu: float = 0.18

## How far the OUTERMOST fragments reach, as a multiple of the blast's own
## outer ring projected onto the screen. The dome's rim sits at 1.0, so anything
## above that overshoots it — "aumentar a extensão deles para além da bolha".
##
## THIS IS A LENGTH, NOT A SCALE ON THE CELL'S OWN DISTANCE, and that change is
## the fix for "alguns raios parecem muito longos e outros curtos" (Director,
## 2026-08-10, annotated capture). The BFS reaches an L1 diamond, so its cells
## are NOT all the same distance away: `(2,0)` is 2 GU out while `(1,1)` is only
## 1.41. Multiplying each cell's own delta therefore made the four screen
## diagonals 64% longer than the four axes — exactly the corners the Director
## circled as TOO LONG, with the short ones being the axes between them. Ray
## endpoints now land on an ELLIPSE instead, so the star is even by construction
## and its irregularity comes from the ring step and the jitter, on purpose.
var length_scale: float = 1.35

## How much of the isometric 2:1 squash to undo, 0 = none (rays end on the
## projected floor ellipse, so the star is twice as wide as it is tall), 1 =
## fully circular. The factor is `AXIS_X.x / AXIS_X.y` = 2.0, taken from the
## projection rather than typed in, so this stays correct if the tile ever
## changes shape.
var circularity: float = 1.0

## Extra reach on the horizontal only — "fazer os raios se estenderem mais um
## pouco lateralmente." Applied after `circularity`, so the star is a touch
## wider than tall rather than a perfect circle.
var lateral_scale: float = 1.3

## Ground braking — "os raios não podem ir totalmente para baixo, precisam ser
## menores na base, considerando que o chão vai frear o impacto." A fragment
## thrown straight down the screen (toward the camera, into the floor) keeps
## only this fraction of its reach; one going straight up keeps all of it, and
## everything between is interpolated by how downward it points.
var ground_brake: float = 0.42

## Fragments emitted per reached cell, fanned symmetrically around the cell's own
## direction by `spread_rad` per step out from centre.
##
## THE COUNT IS NOT THE NUMBER OF SPOKES, and that is worth knowing before
## tuning it. The BFS reaches 12 cells, but they only point in EIGHT distinct
## screen directions: (1,0) and (2,0) are the same bearing at different lengths,
## and so are the other three axis pairs, while ring 2's four diagonals add the
## up/down/left/right ones. So the fan is what fills the 45° gaps between those
## eight, and `spread_rad` has to be sized against that gap rather than picked
## for looks — at 3 rays and 15° apart the fan spans 30° of each 45°, which is
## near-even. Raising `rays_per_cell` without opening `spread_rad` to match just
## makes eight tight bundles.
##
## 2 → 3 and 0.13 → 0.26 for the Director's reference mock-up (2026-08-10):
## 36 rays across 24 distinct bearings.
var rays_per_cell: int = 3
var spread_rad: float = 0.26

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

	## The fragments leave the grenade, which is sitting slightly above the floor,
	## not the floor plane itself.
	var ground: Vector2 = _cell_to_screen(source_gu)
	var origin: Vector2 = ground + IsoProjection.AXIS_Z * ray_origin_lift_gu
	var y_scale: float = lerpf(1.0, IsoProjection.AXIS_X.x / IsoProjection.AXIS_X.y, circularity)
	var fan: int = maxi(rays_per_cell, 1)

	## The ellipse the OUTERMOST fragments end on. Its vertical semi-axis is the
	## blast's own outer ring, projected: under full circularity a grid circle of
	## R GU maps to a screen circle of `sqrt(2)·128·R`, and `lateral_scale` then
	## widens it. Everything after this is a direction and a fraction of it.
	var outer_ring: int = 1
	for ring_value in gu_rings.values():
		outer_ring = maxi(outer_ring, int(ring_value))
	var semi_y: float = IsoProjection.floor_circle_semi_axes(float(outer_ring)).x \
		* length_scale
	var semi_x: float = semi_y * lateral_scale

	for cell: Vector2i in gu_rings.keys():
		var ring: int = int(gu_rings[cell])
		if ring <= 0 or ring >= ring_alpha.size():
			continue
		var alpha: float = ring_alpha[ring]
		if alpha <= 0.0:
			continue

		## Undo the isometric squash so the fan of DIRECTIONS is even on screen —
		## without this the same angular spread reads twice as wide as it is tall.
		var delta: Vector2 = _cell_to_screen(cell) - ground
		var out := Vector2(delta.x, delta.y * y_scale)
		if out.length_squared() < 1.0:
			continue

		## Inner rings fall short of the rim rather than reaching it, which is
		## what keeps the star from being a perfectly uniform burst.
		var ring_reach: float = lerpf(0.72, 1.0,
			float(ring - 1) / maxf(float(outer_ring - 1), 1.0))

		for k: int in range(fan):
			## Symmetric fan: one ray dead-on when fan is odd, ±spread_rad
			## either side otherwise. Deterministic, so the star does not
			## shimmer while the cursor moves.
			var offset_index: float = float(k) - (float(fan) - 1.0) * 0.5
			var aimed: Vector2 = out.rotated(offset_index * spread_rad).normalized()
			var jitter: float = lerpf(0.82, 1.0, _hash01(cell, k))
			var reach: float = _ellipse_radius(aimed, semi_x, semi_y) \
				* ring_reach * jitter * _ground_factor(aimed)
			_ray_froms.append(origin)
			_ray_tos.append(origin + aimed * reach)
			_ray_alphas.append(alpha)

	visible = not _ray_froms.is_empty()
	queue_redraw()


func _draw() -> void:
	var c := ray_color
	for i: int in _ray_froms.size():
		draw_line(_ray_froms[i], _ray_tos[i],
			Color(c.r, c.g, c.b, _ray_alphas[i]), line_width)


## Distance from the centre of an axis-aligned ellipse to its rim, along a UNIT
## direction. Closed form from (x/a)² + (y/b)² = 1 — no intersection test, and it
## is what makes every ray land on the same curve regardless of bearing.
func _ellipse_radius(direction: Vector2, semi_x: float, semi_y: float) -> float:
	var nx: float = direction.x / maxf(semi_x, 0.001)
	var ny: float = direction.y / maxf(semi_y, 0.001)
	return 1.0 / maxf(sqrt(nx * nx + ny * ny), 0.000001)


## How much of its reach a fragment keeps, given the direction it left in.
## 1.0 straight up, `ground_brake` straight down, interpolated by the downward
## component in between — the floor is in the way on that side.
func _ground_factor(direction: Vector2) -> float:
	var length: float = direction.length()
	if length < 0.001:
		return 1.0
	## +Y is down the screen, so this is 1.0 for a fragment aimed at the floor.
	var downward: float = clampf(direction.y / length, 0.0, 1.0)
	return lerpf(1.0, ground_brake, downward)


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
