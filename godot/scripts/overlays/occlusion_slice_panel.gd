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
## OCC-18 (2026-07-14): every edge drawn as DOTS at real voxel boundaries
## (90% alpha), with a full line underneath at 20% alpha connecting them —
## Director's refinement after OCC-17's dashed-line attempt looked visually
## incoherent (fixed pixel dash length reads sparse on a tall axis, dense on a
## short one, since screen-px-per-voxel differs by axis under isometric
## projection). Dots spaced by real VOXEL COUNT (width_voxels/depth_voxels,
## computed upstream from real grid coordinates, never pixels) are equal on
## every axis by construction. Verticals need no count — each panel is already
## exactly one voxel LEVEL tall (see below), so they're always a 2-dot line.
##
## OCC-19 (2026-07-14): a translucent glass FILL on the box's front and top
## faces, at VoxelRenderer.GHOST_ALPHAS[ring] — the SAME alpha the real
## ghosted material already uses, not a second independently-tuned value, so
## the wireframe's fill reads as a continuation of the material's own
## occlusion rather than a competing effect.
##
## draw_top/draw_bottom default true but the manager sets them false on every band
## except the very top and very bottom of a slice's occluded span. A tall slice
## spans many levels, each its OWN z_index band (necessary — see above) — drawing
## every band's own top+bottom edge produced a "venetian blind" of horizontal rungs
## down the whole span, since each level boundary is really just an INTERNAL seam,
## not a real silhouette edge. The four verticals still draw on every band (that is
## what keeps each level individually maskable by nearer geometry), and consecutive
## bands' verticals share exact endpoints, so their dots never double up.

extends Node2D

var bottom_near_a: Vector2
var bottom_near_b: Vector2
var bottom_far_a: Vector2
var bottom_far_b: Vector2
var top_near_a: Vector2
var top_near_b: Vector2
var top_far_a: Vector2
var top_far_b: Vector2
var width_voxels: int = 1   ## real voxel count along near_a→near_b / far_a→far_b
var depth_voxels: int = 1   ## real voxel count along near_a→far_a / near_b→far_b
var ring: int = 0           ## edge-graph hop distance — indexes VoxelRenderer.GHOST_ALPHAS
var draw_top: bool = true
var draw_bottom: bool = true

const LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)  ## pure white, no cyan tint
const DOT_ALPHA := 0.5
const UNDERLINE_ALPHA := 0.3
## OCC-24 (2026-07-17, Director): dots drawn as VECTOR circles (draw_circle),
## not pre-blurred texture sprites. 1.5px thick strokes (same thickness as
## the underline) — dots and line now share same thickness. No blur, removes
## visual pollution and simplifies rendering.
const DOT_WIDTH := 1.5  ## screen pixels, matches UNDERLINE width
const FILL_COLOR := Color(0.7, 0.7, 0.7)   ## neutral gray, no cyan
## OCC-25 (2026-07-17, Director): FILL_ALPHAS reduced to minimal values for
## testing ring opacity visibility. Reduce visual pollution from overlapping
## translucent faces on tall slices.
const FILL_ALPHAS := [0.05, 0.08, 0.1]   ## ring 0, 1, 2 (minimum test)


func _draw() -> void:
	## OCC-19: glass fill first, so the dotted/underlined outline draws on top
	## of it. Front face always (it's this band's own real geometry); the top
	## cap only where a real cap edge is drawn (see header) — filling every
	## internal level boundary would double up cumulative alpha and read far
	## stronger than the ring alpha actually calls for.
	##
	## OCC-21d (2026-07-14): Ring-based alpha restored, gray fill (no cyan).
	## 30% center (ring 0), 50% mid (ring 1), 70% edge (ring 2).
	##
	## OCC-21g (2026-07-15): Added lateral faces (left/right sides) to fill,
	## so the box reads as a complete solid volume, not just a front plane.
	##
	## OCC-21h (2026-07-15): Lateral faces use one ring level lower alpha than
	## front face (more transparent), creating depth gradient within same box.
	##
	## OCC-21i (2026-07-15): Lateral alpha further reduced by 50% (multiply by 0.5)
	## since overlapping lateral polygons accumulate visually and read too strong.
	##
	## OCC-21j (2026-07-15): Top cap filled at 25% of ring alpha (experiment).
	##
	## OCC-21k (2026-07-15): Top cap alpha same as lateral (both use same formula).
	var front_alpha: float = FILL_ALPHAS[clampi(ring, 0, FILL_ALPHAS.size() - 1)]
	var lateral_alpha: float = FILL_ALPHAS[clampi(ring - 1, 0, FILL_ALPHAS.size() - 1)] * 0.5
	var top_alpha: float = lateral_alpha  ## same as lateral faces
	
	var fill_front: Color = FILL_COLOR
	fill_front.a = front_alpha
	var fill_lateral: Color = FILL_COLOR
	fill_lateral.a = lateral_alpha
	var fill_top: Color = FILL_COLOR
	fill_top.a = top_alpha
	
	## Front face (near edge) - uses edge's own ring alpha
	draw_colored_polygon(
		PackedVector2Array([bottom_near_a, bottom_near_b, top_near_b, top_near_a]), fill_front)
	## Left lateral face - one ring level more transparent
	draw_colored_polygon(
		PackedVector2Array([bottom_near_a, bottom_far_a, top_far_a, top_near_a]), fill_lateral)
	## Right lateral face - one ring level more transparent
	draw_colored_polygon(
		PackedVector2Array([bottom_near_b, bottom_far_b, top_far_b, top_near_b]), fill_lateral)
	if draw_top:
		## Top cap - uses same alpha as lateral faces
		draw_colored_polygon(
			PackedVector2Array([top_near_a, top_near_b, top_far_b, top_far_a]), fill_top)

	## Four verticals — the box's real corners, every band. Each panel is
	## exactly one voxel LEVEL tall, so this is always a 2-dot line.
	_draw_voxel_edge(top_near_a, bottom_near_a, 1)
	_draw_voxel_edge(top_near_b, bottom_near_b, 1)
	_draw_voxel_edge(top_far_a, bottom_far_a, 1)
	_draw_voxel_edge(top_far_b, bottom_far_b, 1)

	## Top/bottom caps — each a full rectangle (near edge, two depth
	## connectors, far edge), only at the band(s) that are a real silhouette
	## edge (see header).
	if draw_top:
		_draw_voxel_edge(top_near_a, top_near_b, width_voxels)
		_draw_voxel_edge(top_near_a, top_far_a, depth_voxels)
		_draw_voxel_edge(top_near_b, top_far_b, depth_voxels)
		_draw_voxel_edge(top_far_a, top_far_b, width_voxels)
	if draw_bottom:
		_draw_voxel_edge(bottom_near_a, bottom_near_b, width_voxels)
		_draw_voxel_edge(bottom_near_a, bottom_far_a, depth_voxels)
		_draw_voxel_edge(bottom_near_b, bottom_far_b, depth_voxels)
		_draw_voxel_edge(bottom_far_a, bottom_far_b, width_voxels)


## One edge: a faint full line (20% alpha) underneath, then a dot (90% alpha)
## at every real voxel boundary between `from` and `to` — voxel_count+1 points
## (fencepost), evenly interpolated in SCREEN space. voxel_count is a real
## grid-unit count, never derived from pixel length.
## OCC-24: dots drawn as vector circles (1.5px strokes), not textured sprites.
func _draw_voxel_edge(from: Vector2, to: Vector2, voxel_count: int) -> void:
	var underline := LINE_COLOR
	underline.a = UNDERLINE_ALPHA
	draw_line(from, to, underline, 1.5, true)

	var dot := LINE_COLOR
	dot.a = DOT_ALPHA
	var steps := maxi(voxel_count, 1)
	for i in range(steps + 1):
		var center := from.lerp(to, float(i) / float(steps))
		## Draw a circle outline (hollow) at this voxel boundary.
		## DOT_WIDTH is the stroke thickness (1.5px, same as underline).
		draw_circle(center, DOT_WIDTH * 0.5, dot)
