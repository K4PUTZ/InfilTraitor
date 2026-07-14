## OCC-08-b: draws one LEVEL band of an occluded slice's wireframe rectangle, at
## that band's own voxel-layer z_index — see occlusion_wireframe_overlay.gd for why
## a flat elevated z_index was wrong (it always won against opaque geometry nearer
## the camera at a lower level, which should have covered it).
##
## draw_top/draw_bottom default true but the manager sets them false on every band
## except the very top and very bottom of a slice's occluded span. A tall slice
## spans many levels, each its OWN z_index band (necessary — see above) — drawing
## every band's own top+bottom edge produced a "venetian blind" of horizontal rungs
## down the whole span, since each level boundary is really just an INTERNAL seam,
## not a real silhouette edge. The two verticals still draw on every band (that is
## what keeps each level individually maskable by nearer geometry), and consecutive
## bands' verticals share exact endpoints, so they read as one unbroken line.

extends Node2D

var bottom_a: Vector2
var bottom_b: Vector2
var top_a: Vector2
var top_b: Vector2
var draw_top: bool = true
var draw_bottom: bool = true

const LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const LINE_WIDTH := 2.0


func _draw() -> void:
	if draw_top:
		draw_line(top_a, top_b, LINE_COLOR, LINE_WIDTH, true)
	if draw_bottom:
		draw_line(bottom_a, bottom_b, LINE_COLOR, LINE_WIDTH, true)
	draw_line(top_a, bottom_a, LINE_COLOR, LINE_WIDTH, true)
	draw_line(top_b, bottom_b, LINE_COLOR, LINE_WIDTH, true)
