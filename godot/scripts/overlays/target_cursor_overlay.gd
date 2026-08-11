extends Node2D
class_name TargetCursorOverlay

## TargetCursorOverlay — the hatched grenade that marks the throw's target cell.
##
## Director, 2026-08-10: "o quadrado magenta que estamos usando para indicar a
## GU selecionada pode sumir, e o cursor assume temporariamente o formato da
## granada hachurada (ver referência)" — REFERENCES/granade.webp, whose target
## area is drawn as a lattice rather than a flat wash.
##
## So while a throw is being aimed, SelectionOverlay's magenta diamond is hidden
## and this stands in its place: the same job (here is the cell you picked),
## said in the verb of the action instead of the generic selection marker.
##
## Drawn rather than sprited on purpose. GrenadeProp's baked frames are the
## physical object — photoreal, per-perspective, and lit; this is a UI symbol
## that has to stay legible at any zoom and read as a diagram. Its one shared
## fact with the world is its SIZE, which is in GU and projected through
## IsoProjection.AXIS_Z, so it grows and shrinks with the map instead of
## floating free at a fixed pixel size.

## Tuning — `var` per architecture Rule 1.
var body_color: Color = Color(1.0, 0.86, 0.62, 0.95)
var hatch_color: Color = Color(1.0, 0.42, 0.14, 0.75)
var line_width: float = 2.0
var hatch_width: float = 1.5
## Icon height in GAME UNITS of world HEIGHT — a real size in the world's own
## vertical scale, not a pixel constant.
var icon_height_gu: float = 0.62
var hatch_lines: int = 7
var body_segments: int = 24

var _center: Vector2 = Vector2.ZERO
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the marker standing on a floor position.
func show_at(center: Vector2) -> void:
	_center = center
	_visible = true
	visible = true
	queue_redraw()


func _draw() -> void:
	if not _visible:
		return

	var h: float = absf(IsoProjection.AXIS_Z.y) * icon_height_gu
	## Body: an ellipse whose centre sits above the cell it marks, so the icon
	## stands on the target rather than being bisected by it.
	var body_center: Vector2 = _center + Vector2(0.0, -0.42 * h)
	var radii := Vector2(0.30 * h, 0.34 * h)

	_draw_hatch(body_center, radii)

	var outline := IsoProjection.ellipse_arc(body_center, radii, 0.0, TAU, body_segments)
	draw_polyline(outline, body_color, line_width)

	## Fuse cap and lever — the two silhouette details that make a circle read
	## as a grenade rather than as a ball.
	var cap_w: float = 0.13 * h
	var cap_top: float = body_center.y - radii.y - 0.16 * h
	var cap_bottom: float = body_center.y - radii.y + 0.04 * h
	draw_polyline(PackedVector2Array([
		Vector2(body_center.x - cap_w, cap_bottom),
		Vector2(body_center.x - cap_w, cap_top),
		Vector2(body_center.x + cap_w, cap_top),
		Vector2(body_center.x + cap_w, cap_bottom),
	]), body_color, line_width)
	draw_line(Vector2(body_center.x + cap_w, cap_top + 0.03 * h),
		Vector2(body_center.x + cap_w + 0.17 * h, body_center.y - 0.06 * h),
		body_color, line_width)


## Parallel 45° lines clipped to the ellipse, without clipping anything.
##
## The chord of a line across the UNIT CIRCLE at signed offset `c` from the
## centre is 2·sqrt(1 - c²) long — closed form, no intersection test. Scaling
## the result by the ellipse's radii maps circle to ellipse, and because that
## scaling is affine it takes straight lines to straight lines and parallel
## families to parallel families. So the hatch is built where the maths is easy
## and then stretched into place.
func _draw_hatch(center: Vector2, radii: Vector2) -> void:
	if hatch_lines < 1:
		return
	var diag: float = sqrt(0.5)
	var dir := Vector2(diag, diag)   ## 45°, unit length
	var normal := Vector2(-dir.y, dir.x)
	for i: int in range(hatch_lines):
		var c: float = ((float(i) + 0.5) / float(hatch_lines)) * 2.0 - 1.0
		var half: float = sqrt(maxf(1.0 - c * c, 0.0))
		var a: Vector2 = normal * c - dir * half
		var b: Vector2 = normal * c + dir * half
		draw_line(center + a * radii, center + b * radii, hatch_color, hatch_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
