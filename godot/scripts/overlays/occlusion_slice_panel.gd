## OCC-08-b: draws one LEVEL band of an occluded edge's wireframe BOX, at that
## band's own voxel-layer z_index — see occlusion_wireframe_overlay.gd for why
## a flat elevated z_index was wrong (it always won against opaque geometry nearer
## the camera at a lower level, which should have covered it).
##
## OCC-14 (2026-07-14): a real box (4 verticals: near_a, near_b, far_a, far_b —
## "far" is "near" shifted by the wall's real one-voxel thickness), not a flat
## plane. Director's correction after seeing OCC-13 live: single-quad panels
## read as "sheets of paper," and the junction-column unit (near == far
## degenerate before this) as "just a line" — both needed actual depth to look
## like the solid geometry they stand in for.
##
## draw_top/draw_bottom default true but the manager sets them false on every band
## except the very top and very bottom of a slice's occluded span. A tall slice
## spans many levels, each its OWN z_index band (necessary — see above) — drawing
## every band's own top+bottom edge produced a "venetian blind" of horizontal rungs
## down the whole span, since each level boundary is really just an INTERNAL seam,
## not a real silhouette edge. The four verticals still draw on every band (that is
## what keeps each level individually maskable by nearer geometry), and consecutive
## bands' verticals share exact endpoints, so they read as unbroken lines.

extends Node2D

var bottom_near_a: Vector2
var bottom_near_b: Vector2
var bottom_far_a: Vector2
var bottom_far_b: Vector2
var top_near_a: Vector2
var top_near_b: Vector2
var top_far_a: Vector2
var top_far_b: Vector2
var draw_top: bool = true
var draw_bottom: bool = true

const LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const LINE_WIDTH := 2.0


func _draw() -> void:
	## Four verticals — the box's real corners, every band.
	draw_line(top_near_a, bottom_near_a, LINE_COLOR, LINE_WIDTH, true)
	draw_line(top_near_b, bottom_near_b, LINE_COLOR, LINE_WIDTH, true)
	draw_line(top_far_a, bottom_far_a, LINE_COLOR, LINE_WIDTH, true)
	draw_line(top_far_b, bottom_far_b, LINE_COLOR, LINE_WIDTH, true)

	## Top/bottom caps — each a full rectangle (near edge, two depth
	## connectors, far edge), only at the band(s) that are a real silhouette
	## edge (see header).
	if draw_top:
		draw_line(top_near_a, top_near_b, LINE_COLOR, LINE_WIDTH, true)
		draw_line(top_near_a, top_far_a, LINE_COLOR, LINE_WIDTH, true)
		draw_line(top_near_b, top_far_b, LINE_COLOR, LINE_WIDTH, true)
		draw_line(top_far_a, top_far_b, LINE_COLOR, LINE_WIDTH, true)
	if draw_bottom:
		draw_line(bottom_near_a, bottom_near_b, LINE_COLOR, LINE_WIDTH, true)
		draw_line(bottom_near_a, bottom_far_a, LINE_COLOR, LINE_WIDTH, true)
		draw_line(bottom_near_b, bottom_far_b, LINE_COLOR, LINE_WIDTH, true)
		draw_line(bottom_far_a, bottom_far_b, LINE_COLOR, LINE_WIDTH, true)
