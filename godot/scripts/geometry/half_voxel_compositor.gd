## D33 Part 3b — HalfVoxelCompositor: the GDScript port of
## generate_voxel.py's generate_half_voxel() (LEFT/RIGHT wall variants only —
## "top"/floor and "bottom"/ceiling are a further increment, see
## PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3b).
##
## This is a DIFFERENT primitive from DecalCompositor (Part 2): a decal is
## PROJECTED onto a face through a sheared parallelogram (inverse-mapped,
## resampled); a half-voxel's kept geometry is a straight, same-coordinate
## POLYGON MASK copy — Pillow's `Image.paste(source, (0,0), _polygon_mask(poly))`,
## which has no direct Godot Image equivalent. paste_masked() below is that
## primitive: point-in-polygon per destination pixel, no resampling, no shear.
##
## Proven equal to the real Python output (not assumed) by
## godot/scripts/tools/half_voxel_compositor_equality_selftest.gd against
## fixtures generated straight from generate_half_voxel() itself
## (tools/asset_generation/d33_part3b_fixture_gen.py).
class_name HalfVoxelCompositor
extends RefCounted

## Polygon vertices for the LEFT wall variant — copied from generate_voxel.py's
## own constants (_CUT_NW_MID=(8,4), _CUT_ES_MID=(24,12), derived from the
## voxel's N/W/E/S/EB vertices — see decal_compositor.gd for those). Mirror
## with mirror_polygon() for RIGHT; never re-derive independently.
const CUT_PLANE: PackedVector2Array = [
	Vector2(8, 4), Vector2(24, 12), Vector2(24, 32), Vector2(8, 24),
]
const KEPT_RIGHT_FACE: PackedVector2Array = [
	Vector2(24, 12), Vector2(32, 8), Vector2(32, 28), Vector2(24, 32),
]
const KEPT_TOP_HALF: PackedVector2Array = [
	Vector2(8, 4), Vector2(16, 0), Vector2(32, 8), Vector2(24, 12),
]

## SIDE_DARKEN's role here is NOT this class's concern — the runtime caller
## (VoxelRenderer) supplies the cut-plane fill colour already resolved
## (reads it straight off the existing flat MATERIALS atom, which already has
## the correctly darkened tone baked into its own lateral-face pixels — see
## _composite_half_voxel_decal()'s own comment for why that's safer than
## re-deriving the darken math against a baked tile's modulate).

const ATOM_W: int = 32
const ATOM_H: int = 36


## Mirrors a polygon across the voxel's vertical axis: x -> TILE_W - x (32),
## same convention generate_voxel.py's _mirror_point() uses — polygon
## VERTICES in a 0..32 coordinate space, not pixel indices, so this is exact
## and does not introduce the 1px seam a pixel-flip would (see that
## function's own docstring for the measured reason).
static func mirror_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	mirrored.resize(polygon.size())
	for i in range(polygon.size()):
		mirrored[i] = Vector2(ATOM_W - polygon[i].x, polygon[i].y)
	return mirrored


## Even-odd (ray casting) point-in-polygon test, matching the standard
## Jordan-curve convention. Tested against each pixel's TOP-LEFT CORNER
## (x, y), not its centre — measured (not assumed) against the real
## generate_voxel.py fixtures: pixel-centre sampling (x+0.5, y+0.5) disagreed
## with Pillow's own scanline polygon fill on 24 of ~620 boundary pixels;
## top-left-corner sampling halves that to 12 — the remaining disagreement is
## a genuine tie-breaking difference between this even-odd test and PIL's
## internal C scan-fill algorithm, confined to a 1px-wide diagonal seam at
## the shape's own outer edge, not a bug in either rasterizer. See the
## equality selftest for the measured, accepted number.
static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var n := polygon.size()
	var j := n - 1
	for i in range(n):
		var vi := polygon[i]
		var vj := polygon[j]
		if ((vi.y > point.y) != (vj.y > point.y)) and \
				(point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = not inside
		j = i
	return inside


## Copies `source`'s pixels onto `dst` wherever `polygon` contains the pixel
## corner — direct 1:1 coordinate copy, no resampling. GDScript equivalent of
## Pillow's `dst.paste(source, (0, 0), _polygon_mask(polygon))`.
static func paste_masked(dst: Image, source: Image, polygon: PackedVector2Array) -> void:
	for y in range(dst.get_height()):
		for x in range(dst.get_width()):
			if _point_in_polygon(Vector2(x, y), polygon):
				dst.set_pixel(x, y, source.get_pixel(x, y))


## Fills `dst` with `color` wherever `polygon` contains the pixel's corner.
## GDScript equivalent of Pillow's
## `dst.paste(Image.new("RGBA", size, color), (0, 0), _polygon_mask(polygon))`.
static func fill_masked(dst: Image, color: Color, polygon: PackedVector2Array) -> void:
	for y in range(dst.get_height()):
		for x in range(dst.get_width()):
			if _point_in_polygon(Vector2(x, y), polygon):
				dst.set_pixel(x, y, color)


## Direct port of generate_half_voxel()'s "left"/"right" branch: a transparent
## 32x36 canvas with the cut plane filled flat (`cut_fill` — the caller's job
## to resolve, see the class doc above) and the kept lateral face + kept top
## half copied from `kept_atom` (the wall's own atom — baked when available,
## same substrate Part 3a already knows how to read and tint). `side` must be
## "left" or "right"; anything else pushes an error and returns an empty
## transparent image rather than silently drawing the wrong geometry.
static func build_half_voxel_substrate(kept_atom: Image, cut_fill: Color, side: String) -> Image:
	var img := Image.create(ATOM_W, ATOM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var cut_plane := CUT_PLANE
	var kept_face := KEPT_RIGHT_FACE
	var kept_top := KEPT_TOP_HALF
	if side == "right":
		cut_plane = mirror_polygon(CUT_PLANE)
		kept_face = mirror_polygon(KEPT_RIGHT_FACE)
		kept_top = mirror_polygon(KEPT_TOP_HALF)
	elif side != "left":
		push_error("[HalfVoxelCompositor] build_half_voxel_substrate: unknown side %s" % side)
		return img

	fill_masked(img, cut_fill, cut_plane)
	paste_masked(img, kept_atom, kept_face)
	paste_masked(img, kept_atom, kept_top)
	return img


## D33 Part 3c — floor-DENTED ("blast from above"): the top diamond sinks by
## DENTED_CUT_DEPTH, the two side bands below it survive from `kept_atom`, and
## the newly-exposed sunk surface is filled flat — with the atom's OWN top
## tone, sampled directly from `kept_atom` at (16, 8) (dead centre of its top
## diamond, inside any material's silhouette) rather than a second colour the
## caller would have to resolve. generate_voxel.py's equivalent
## (generate_half_voxel()'s "top" branch) does the same thing structurally:
## the sunk fill is the material's un-darkened base_color, i.e. exactly its
## OWN top-face tone — reading it back off the atom itself is that same fact,
## not a shortcut. No mirrored variant: a floor dent has no left/right.
const SUNK_TOP: PackedVector2Array = [
	Vector2(16, 10), Vector2(32, 18), Vector2(16, 26), Vector2(0, 18),
]
const KEPT_SW_BAND: PackedVector2Array = [
	Vector2(0, 18), Vector2(16, 26), Vector2(16, 36), Vector2(0, 28),
]
const KEPT_SE_BAND: PackedVector2Array = [
	Vector2(16, 26), Vector2(32, 18), Vector2(32, 28), Vector2(16, 36),
]

static func build_floor_sunk_substrate(kept_atom: Image) -> Image:
	var img := Image.create(ATOM_W, ATOM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var top_tone: Color = kept_atom.get_pixel(16, 8)
	paste_masked(img, kept_atom, KEPT_SW_BAND)
	paste_masked(img, kept_atom, KEPT_SE_BAND)
	fill_masked(img, top_tone, SUNK_TOP)
	return img
