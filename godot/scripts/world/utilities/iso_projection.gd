class_name IsoProjection

## IsoProjection — the one analytic home for "a shape measured in GAME UNITS,
## drawn on the isometric screen plane".
##
## Exists because T-BUBBLE's first pass sized its aim bubble with a stack of
## magic pixels (`max_ring * 112.0 * 3.0`) and then drew it as a perfect circle
## on top of a 2:1 perimeter ellipse. Both numbers were guesses, and the shape
## the clamp used was a third geometry again. This class replaces all three with
## the projection itself, per CLAUDE.md's rule that projected positions are
## derived, never eyeballed.
##
## THE BASIS. The two horizontal vectors were MEASURED against the real TileSet
## rather than reasoned from Godot's layout enum (2026-08-10, headless probe on
## `tileset_blocks.tres` — tile_shape=1 ISOMETRIC, tile_layout=5 DIAMOND_DOWN,
## tile_size=(256,128)):
##
##     map_to_local(1, 0) - map_to_local(0, 0) = (128, 64)
##     map_to_local(0, 1) - map_to_local(0, 0) = (-128, 64)
##
## The vertical one is GeometryCoords.VOXEL_STOREY_HEIGHT_PX: one GU of HEIGHT
## is VOXELS_PER_UNIT_AXIS (8) voxel layers of VOXEL_STEP_PX (20) each, drawn
## upward — hence the negative Y. A GU is therefore a cube, and a sphere of
## radius R GU is a real sphere in that cube's units.
##
## WHY THE ELLIPSES BELOW ARE AXIS-ALIGNED, since it is not obvious and the
## whole class leans on it. Writing the projection as the 2x3 matrix
## M = [AXIS_X | AXIS_Y | AXIS_Z], the image of a unit sphere is the ellipse
## whose shape matrix is M·Mᵀ. Its off-diagonal term is
##
##     AXIS_X.x·AXIS_X.y + AXIS_Y.x·AXIS_Y.y + AXIS_Z.x·AXIS_Z.y
##       = 128·64 + (-128)·64 + 0·(-160) = 0
##
## — the two horizontal axes cancel exactly and the vertical one has no X
## component at all. Zero off-diagonal means no rotation: both ellipses are
## screen-axis-aligned, and their semi-axes are just the square roots of the
## diagonal. `off_diagonal()` below is that term, kept callable so the selftest
## asserts it instead of trusting this comment.

## Screen pixels per +1 GU along each world axis. See the header — measured for
## X/Y, GeometryCoords.VOXEL_STOREY_HEIGHT_PX for Z.
const AXIS_X: Vector2 = Vector2(128.0, 64.0)
const AXIS_Y: Vector2 = Vector2(-128.0, 64.0)
const AXIS_Z: Vector2 = Vector2(0.0, -160.0)


## The M·Mᵀ off-diagonal term. Zero for this projection, which is what makes
## every ellipse here screen-axis-aligned. Asserted by iso_projection_selftest.
static func off_diagonal() -> float:
	return AXIS_X.x * AXIS_X.y + AXIS_Y.x * AXIS_Y.y + AXIS_Z.x * AXIS_Z.y


## Semi-axes of the screen ellipse that a circle of `radius_gu` lying FLAT ON
## THE FLOOR projects to — the ground section of a dome, and the shape a "throw
## range" perimeter has to be to mean a real GU distance.
##
## Works out to (181.02, 90.51) per GU: the familiar 2:1 isometric ellipse,
## arrived at from the basis rather than by halving a radius by hand.
static func floor_circle_semi_axes(radius_gu: float) -> Vector2:
	return Vector2(
		sqrt(AXIS_X.x * AXIS_X.x + AXIS_Y.x * AXIS_Y.x),
		sqrt(AXIS_X.y * AXIS_X.y + AXIS_Y.y * AXIS_Y.y)) * radius_gu


## Semi-axes of the screen ellipse that a SPHERE of `radius_gu` projects to.
##
## (181.02, 183.83) per GU — very nearly a circle, and that is a property of
## this projection rather than a coincidence to design around: the vertical
## foreshortening of the isometric floor is almost exactly cancelled by the
## 160 px storey height. The horizontal semi-axis is IDENTICAL to
## floor_circle_semi_axes()' one, which is why a dome and its floor section
## meet cleanly at the left and right extremes — they are tangent there,
## exactly as a real hemisphere is.
static func sphere_semi_axes(radius_gu: float) -> Vector2:
	return Vector2(
		sqrt(AXIS_X.x * AXIS_X.x + AXIS_Y.x * AXIS_Y.x + AXIS_Z.x * AXIS_Z.x),
		sqrt(AXIS_X.y * AXIS_X.y + AXIS_Y.y * AXIS_Y.y + AXIS_Z.y * AXIS_Z.y)) * radius_gu


## Screen offset for a single point `gu_xyz` GU away from this projection's
## origin, along the same linear basis the ellipse helpers share. Unlike them
## this is one 3D point, not a silhouette — for anything that needs a real
## position on the sphere rather than its outline (E-BUBBLE's wall-sectioned
## grid: each grid vertex is cast in 3D against nearby wall planes, then
## projected here). Add the result to a screen-space centre; no further sign
## flip needed, AXIS_Z already encodes "up the screen" for +height.
static func project_point(gu_xyz: Vector3) -> Vector2:
	return AXIS_X * gu_xyz.x + AXIS_Y * gu_xyz.y + AXIS_Z * gu_xyz.z


## Points of an axis-aligned ellipse arc, `segments` spans from `start_rad` to
## `end_rad`. Y is negated so that a positive angle reads as "up the screen",
## which keeps the dome assembly in aim_bubble_overlay.gd readable.
static func ellipse_arc(center: Vector2, semi_axes: Vector2,
		start_rad: float, end_rad: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if segments < 1:
		return points
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: float = lerpf(start_rad, end_rad, t)
		points.append(center + Vector2(semi_axes.x * cos(a), -semi_axes.y * sin(a)))
	return points
