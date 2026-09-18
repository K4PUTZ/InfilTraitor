## ParticleMath — the one place a 2D particle's screen displacement becomes a world displacement.
##
## RENDER3D R3D-4e-1. Every VFX overlay simulates in 2D canvas pixels, and folds a particle's height
## into screen y (smoke "rises" by decreasing y). That is fine on a 2D board and wrong on a 3D one:
## with no world position a particle cannot be depth-tested, so it draws over a wall it is behind.
##
## The fix does NOT rewrite the simulation. A particle keeps its 2D state; it also remembers the 3D
## point it was emitted from (its ANCHOR) and the 2D point that anchor projects to. Its world position
## is then the anchor plus its 2D displacement carried across EXACTLY:
##  - horizontal screen displacement → along the camera's right axis, ÷ px-per-unit;
##  - vertical screen displacement   → straight UP in the world, ÷ (px-per-unit × cos 30°), because a
##    vertical extent projects to cos(elevation) of its length on screen.
## Projected back through the camera the particle lands on the pixel the 2D path would have drawn, so
## the look is unchanged and only the DEPTH is new: a puff at the foot of a wall is behind the wall,
## and a plume that climbs above its top is in front of what is behind it.
class_name ParticleMath
extends RefCounted

## cos(30°): the camera's elevation is fixed (D26).
const COS_ELEVATION: float = 0.8660254
## "No floor point was given" / "no 3D anchor was given" — the trailing-parameter sentinels of the
## emitters, so every pre-existing caller keeps compiling and behaving as it did.
const NO_FLOOR: Vector2 = Vector2(INF, INF)
const NO_ANCHOR: Vector3 = Vector3(INF, INF, INF)


## World position of a particle whose 2D position is `pos_2d`, given the anchor pair.
static func to_world(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2,
		cam: Basis, px_per_unit: float) -> Vector3:
	return anchor_3d + displace(pos_2d - anchor_2d, cam, px_per_unit)


## A 2D screen displacement as a world displacement: horizontal along the camera's right, vertical
## straight up (÷ cos 30°). Linear, so it maps a shape's EXTENTS the same way it maps a position.
static func displace(d: Vector2, cam: Basis, px_per_unit: float) -> Vector3:
	return cam.x * (d.x / px_per_unit) - Vector3.UP * (d.y / (px_per_unit * COS_ELEVATION))


## A rectangle of half-extents `ax_2d` and `ay_2d` (2D screen vectors, so rotation is free): the basis
## whose x and y are those extents carried into the world, z the camera's. Lines, streaks and rotated
## chips are all this. The 2D drawing is symmetric about the centre, so the axis signs do not matter.
static func quad_basis(ax_2d: Vector2, ay_2d: Vector2, cam: Basis, px_per_unit: float) -> Basis:
	return Basis(displace(ax_2d, cam, px_per_unit), displace(ay_2d, cam, px_per_unit), cam.z)


## The 3D point an emission at `world_pos` (2D) comes from, given the ground point beneath it. The
## detonation calls already carry both `world_pos` and `floor_pos`, so the voxel's height is the
## difference between the two: this is `to_world()` anchored at the floor.
static func origin_from_floor(ground_3d: Vector3, floor_pos: Vector2, world_pos: Vector2,
		cam: Basis, px_per_unit: float) -> Vector3:
	return to_world(ground_3d, floor_pos, world_pos, cam, px_per_unit)


## A camera-facing disc of `radius_px` (2D pixels): the basis whose x and y span the camera's plane.
static func disc_basis(cam: Basis, radius_px: float, px_per_unit: float) -> Basis:
	var r: float = radius_px / px_per_unit
	return Basis(cam.x * r, cam.y * r, cam.z)


## The anchor for an emission at `pos` (2D): an explicit 3D anchor wins; otherwise the height comes from
## `floor_pos`; with neither, the emission is taken to be ON THE GROUND at `pos` (a puff on a wall face
## would then sit at the wall's foot, which is why the detonation calls pass their `floor_pos`).
## Vector3.ZERO when there is no board — nothing reads it then.
static func anchor(board: Node3D, pos: Vector2, floor_pos: Vector2 = NO_FLOOR,
		anchor_3d: Vector3 = NO_ANCHOR) -> Vector3:
	if board == null:
		return Vector3.ZERO
	if anchor_3d != NO_ANCHOR:
		return anchor_3d
	var floor_2d: Vector2 = pos if floor_pos == NO_FLOOR else floor_pos
	return board.call("particle_origin", pos, floor_2d)


## The current world position of a live particle (its anchor pair and its 2D position), for a
## consumer that has to spawn something AT it — an ember's burn-out puff.
static func world_of(board: Node3D, anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2) -> Vector3:
	if board == null:
		return Vector3.ZERO
	return to_world(anchor_3d, anchor_2d, pos_2d, board.call("camera_basis"), board.call("px_per_unit"))
