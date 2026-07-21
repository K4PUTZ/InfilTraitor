## Occlusion Wireframe Panel — OCC-27 (2026-07-21)
##
## Draws ALL wireframe geometry for ONE LEVEL, at that level's own z_index
## (see occlusion_wireframe_overlay.gd for why z_index must track the real
## voxel layer). Supersedes the old per-structural-unit box panel (OCC-08-b
## through OCC-23): geometry now comes from OcclusionSet's own unified
## hidden-face-culling pass (_build_wireframe_geometry) over the shared
## occluded-column set, so this script no longer needs to know whether a
## given line/fill came from a wall, a junction column, or a roof.
##
## Simplified line style (Director, 2026-07-21 — "menos linhas sobrepostas,
## foco em arestas externas"): a "solid" line (this volume's own near side,
## nothing of its own bulk between it and the camera) draws as a plain solid
## line, no dots. A "dots" line (the volume's far side, behind its own bulk)
## draws as dots only, no underline — hidden-line-removal convention (CAD
## tradition: visible edges solid, hidden edges dashed), replacing the old
## "underline + dots on every edge regardless" look that read as one
## continuous, cluttered mesh.
##
## Fill alpha comes straight from VoxelRenderer.GHOST_ALPHAS (3%/6%/9%,
## OCC-27) — restoring OCC-19's original intent that the wireframe's glass
## fill uses the SAME alpha the real ghosted material already uses, not a
## second, independently-tuned value.

extends Node2D

## Fill quads: {"p": PackedVector2Array (4 screen points), "ring": int}
var fills: Array = []
## Lines: {"a": Vector2, "b": Vector2, "solid": bool} (screen-space endpoints)
var lines: Array = []

const FILL_COLOR := Color(0.7, 0.7, 0.7)
const LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DOT_ALPHA := 0.5
## OCC-22b (2026-07-16): dots thinned to read at practically the line's own
## thickness (1.5px line -> 0.75px core radius), soft skirt.
const DOT_RADIUS := 0.75
const DOT_BLUR_SIGMA := 1.0
static var _dot_texture: ImageTexture = null


## Lazily build the shared blurred-dot sprite: alpha 1.0 inside DOT_RADIUS,
## falling off as a gaussian outside it — a cheap, close approximation of a
## disc convolved with a gaussian kernel, baked once (no per-frame cost).
static func _get_dot_texture() -> ImageTexture:
	if _dot_texture != null:
		return _dot_texture
	var half := int(ceil(DOT_RADIUS + DOT_BLUR_SIGMA * 3.0))
	var size := half * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var r := Vector2(float(x - half), float(y - half)).length()
			var d := maxf(r - DOT_RADIUS, 0.0)
			var a := exp(-(d * d) / (2.0 * DOT_BLUR_SIGMA * DOT_BLUR_SIGMA))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_dot_texture = ImageTexture.create_from_image(img)
	return _dot_texture


func _draw() -> void:
	for fill in fills:
		var color: Color = FILL_COLOR
		var ring: int = fill["ring"]
		color.a = VoxelRenderer.GHOST_ALPHAS[clampi(ring, 0, VoxelRenderer.GHOST_ALPHAS.size() - 1)]
		draw_colored_polygon(fill["p"], color)

	for line in lines:
		var a: Vector2 = line["a"]
		var b: Vector2 = line["b"]
		if line["solid"]:
			draw_line(a, b, LINE_COLOR, 1.5, true)
		else:
			var dot := LINE_COLOR
			dot.a = DOT_ALPHA
			var tex := _get_dot_texture()
			var tex_size := Vector2(tex.get_width(), tex.get_height())
			draw_texture_rect(tex, Rect2(a - tex_size * 0.5, tex_size), false, dot)
			draw_texture_rect(tex, Rect2(b - tex_size * 0.5, tex_size), false, dot)
