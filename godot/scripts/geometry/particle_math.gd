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


## World position of a particle whose 2D position is `pos_2d`, given the anchor pair.
static func to_world(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2,
		cam: Basis, px_per_unit: float) -> Vector3:
	var d: Vector2 = pos_2d - anchor_2d
	return anchor_3d + cam.x * (d.x / px_per_unit) - Vector3.UP * (d.y / (px_per_unit * COS_ELEVATION))


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
