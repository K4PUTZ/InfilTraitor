## Particle-space selftest — RENDER3D R3D-4e-1.
## Run: python3 tools/persistent/run_selftests.py --only particle_space_selftest
##
## The claim under test is the one the whole of R3D-4e rests on: a particle carried into the world by
## `ParticleMath` projects, through the REAL board camera's own projection, to the pixel its 2D
## simulation put it on. If that holds, moving the VFX into 3D changes their depth and nothing else.
## The projection is asked of a real `Camera3D` configured the way `Board3DLive._make_camera()`
## configures it — a self-comparison against `ParticleMath` would pass whatever the constants said.

extends SceneTree

const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
const QuadField3DRef = preload("res://godot/scripts/geometry/quad_field3d.gd")
const CircleField3DRef = preload("res://godot/scripts/geometry/circle_field3d.gd")
const PPU: float = 256.0 / sqrt(2.0)
const EPS_PX: float = 0.05

var passed: int = 0
var failed: int = 0
var _cam: Camera3D = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PARTICLE-SPACE — 2D displacement to world SELFTEST")
	print("=".repeat(70) + "\n")
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.rotation_degrees = Vector3(-30.0, 45.0, 0.0)  ## D26, as Board3DLive._make_camera()
	_cam.size = float(root.get_visible_rect().size.y) / PPU
	_cam.near = 0.05
	_cam.far = 500.0
	root.add_child(_cam)
	_cam.position = Vector3(20.0, 30.0, 20.0)
	await process_frame
	_cam.make_current()
	await process_frame
	## The viewport a headless run projects through is not `root.get_visible_rect()` (100 px tall here,
	## 844 in the projection), so the camera's scale is MEASURED and `size` is corrected until one
	## world unit along the camera's right axis is exactly PPU pixels, as in the game.
	var measured: float = (_cam.unproject_position(_cam.global_transform.basis.x)
		- _cam.unproject_position(Vector3.ZERO)).length()
	_cam.size = _cam.size * measured / PPU
	await process_frame
	var check: float = (_cam.unproject_position(_cam.global_transform.basis.x)
		- _cam.unproject_position(Vector3.ZERO)).length()
	print("camera calibrated: %.3f px per unit (want %.3f)" % [check, PPU])

	test_displacement_projects_to_the_same_pixels()
	test_rise_is_world_up()
	test_origin_from_floor_reads_the_height()
	test_field_buffer_layout()
	test_field_survives_an_empty_frame()
	test_line_ends_land_on_their_pixels()
	test_rotated_chip_corners_land_on_their_pixels()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	quit(0 if failed == 0 else 1)


func _pass(msg: String) -> void:
	passed += 1
	print("  ✓ PASS: ", msg)


func _fail(msg: String) -> void:
	failed += 1
	print("  ✗ FAIL: ", msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass(msg)
	else:
		_fail(msg)


## [1] The whole claim. A particle displaced by (dx, dy) screen px from its anchor lands (dx, dy) px
## from where the anchor projects — for several anchors and displacements, including rises and drifts.
func test_displacement_projects_to_the_same_pixels() -> void:
	print("[1] a displaced particle lands on the pixel the 2D path would draw")
	var basis: Basis = _cam.global_transform.basis
	var anchors: Array[Vector3] = [Vector3(3.0, 0.0, 4.0), Vector3(10.5, 1.2, -2.0), Vector3(-6.0, 0.4, 7.5)]
	var moves: Array[Vector2] = [Vector2(0, 0), Vector2(30, 0), Vector2(0, -80), Vector2(-45, -120), Vector2(12, 33)]
	var worst: float = 0.0
	for a: Vector3 in anchors:
		var anchor_2d: Vector2 = _cam.unproject_position(a)
		for m: Vector2 in moves:
			var world: Vector3 = ParticleMathRef.to_world(a, anchor_2d, anchor_2d + m, basis, PPU)
			var got: Vector2 = _cam.unproject_position(world)
			worst = maxf(worst, (got - (anchor_2d + m)).length())
	_check(worst < EPS_PX, "worst screen error %.4f px over %d cases (limit %.2f)" % [worst, anchors.size() * moves.size(), EPS_PX])


## [2] What "rises" means: a pure upward screen move is a pure world-up move, of the length that
## projects to that many pixels.
func test_rise_is_world_up() -> void:
	print("[2] a screen rise is world-up, not a slide across the floor")
	var basis: Basis = _cam.global_transform.basis
	var world: Vector3 = ParticleMathRef.to_world(Vector3.ZERO, Vector2.ZERO, Vector2(0.0, -100.0), basis, PPU)
	_check(absf(world.x) < 1e-5 and absf(world.z) < 1e-5, "no horizontal drift (%.6f, %.6f)" % [world.x, world.z])
	var expect: float = 100.0 / (PPU * ParticleMathRef.COS_ELEVATION)
	_check(absf(world.y - expect) < 1e-5, "rise %.5f units, expected %.5f" % [world.y, expect])


## [3] The detonation calls carry `world_pos` and `floor_pos`; their difference is the voxel's height.
func test_origin_from_floor_reads_the_height() -> void:
	print("[3] the origin of an emission reads its height from world_pos and floor_pos")
	var basis: Basis = _cam.global_transform.basis
	var ground: Vector3 = Vector3(5.5, 0.0, 6.5)
	var floor_pos: Vector2 = _cam.unproject_position(ground)
	var height_units: float = 1.5
	var elevated: Vector3 = ground + Vector3.UP * height_units
	var world_pos: Vector2 = _cam.unproject_position(elevated)
	var origin: Vector3 = ParticleMathRef.origin_from_floor(ground, floor_pos, world_pos, basis, PPU)
	_check((origin - elevated).length() < 1e-4, "recovered %s, expected %s" % [str(origin), str(elevated)])


## [4] One disc's instance transform is what MultiMesh reads: rows of (x, y, z, origin), then colour.
func test_field_buffer_layout() -> void:
	print("[4] CircleField3D writes the instance the way MultiMesh reads it")
	var holder := Node3D.new()
	root.add_child(holder)
	var field: RefCounted = CircleField3DRef.new()
	field.attach(holder, false, 0.5)
	var basis: Basis = _cam.global_transform.basis
	field.begin(2, basis, PPU)
	var a := Vector3(2.0, 1.0, 3.0)
	var a2: Vector2 = _cam.unproject_position(a)
	field.push(a, a2, a2 + Vector2(10.0, -20.0), 8.0, Color(0.25, 0.5, 0.75, 0.5))
	field.flush()
	var buf: PackedFloat32Array = field.buffer()
	var expect_pos: Vector3 = ParticleMathRef.to_world(a, a2, a2 + Vector2(10.0, -20.0), basis, PPU)
	_check(field.live_count() == 1, "one disc live")
	_check(absf(buf[3] - expect_pos.x) < 1e-5 and absf(buf[7] - expect_pos.y) < 1e-5 and absf(buf[11] - expect_pos.z) < 1e-5,
		"origin column is the world position")
	var r: float = 8.0 / PPU
	_check(absf(buf[0] - basis.x.x * r) < 1e-6 and absf(buf[4] - basis.x.y * r) < 1e-6 and absf(buf[8] - basis.x.z * r) < 1e-6,
		"x axis is the camera's right, scaled to the radius")
	_check(absf(buf[12] - 0.25) < 1e-6 and absf(buf[15] - 0.5) < 1e-6, "colour follows the transform")
	holder.queue_free()


func test_field_survives_an_empty_frame() -> void:
	print("[5] an empty frame is not an error")
	var holder := Node3D.new()
	root.add_child(holder)
	var field: RefCounted = CircleField3DRef.new()
	field.attach(holder, true)
	field.begin(0, _cam.global_transform.basis, PPU)
	field.flush()
	field.clear()
	_check(field.live_count() == 0, "no discs, no error")
	holder.queue_free()


## [6] A line is a thin rectangle: its two ends, carried into the world and projected, are the two
## screen points the 2D `draw_line` was given, and its thickness is the line width on screen.
func test_line_ends_land_on_their_pixels() -> void:
	print("[6] a QuadField3D line lands on the pixels the 2D draw_line would")
	var holder := Node3D.new()
	root.add_child(holder)
	var field: RefCounted = QuadField3DRef.new()
	field.attach_rect(holder)
	var basis: Basis = _cam.global_transform.basis
	field.begin(1, basis, PPU)
	var a := Vector3(4.0, 0.5, 5.0)
	var a2: Vector2 = _cam.unproject_position(a)
	var p0: Vector2 = a2 + Vector2(-12.0, -30.0)
	var p1: Vector2 = a2 + Vector2(40.0, 18.0)
	field.push_line(a, a2, p0, p1, 4.0, Color.WHITE)
	var buf: PackedFloat32Array = field.buffer()
	var centre := Vector3(buf[3], buf[7], buf[11])
	var bx := Vector3(buf[0], buf[4], buf[8])
	var by := Vector3(buf[1], buf[5], buf[9])
	var c2: Vector2 = _cam.unproject_position(centre)
	var end0: Vector2 = _cam.unproject_position(centre - bx)
	var end1: Vector2 = _cam.unproject_position(centre + bx)
	_check((c2 - (p0 + p1) * 0.5).length() < EPS_PX, "centre is the segment's midpoint (%.4f px off)" % (c2 - (p0 + p1) * 0.5).length())
	_check((end0 - p0).length() < EPS_PX and (end1 - p1).length() < EPS_PX,
		"both ends land on their pixels (%.4f, %.4f px off)" % [(end0 - p0).length(), (end1 - p1).length()])
	var thickness: float = (_cam.unproject_position(centre + by) - _cam.unproject_position(centre - by)).length()
	_check(absf(thickness - 4.0) < EPS_PX, "thickness %.4f px, wanted 4.0" % thickness)
	## A zero-length line (a resting spark) is a square of the line's width, not a degenerate quad.
	field.begin(1, basis, PPU)
	field.push_line(a, a2, a2, a2, 2.0, Color.WHITE)
	var d: PackedFloat32Array = field.buffer()
	var dx := Vector3(d[0], d[4], d[8])
	_check(dx.length() > 1e-6, "a zero-length line still has extent")
	holder.queue_free()


## [7] A rotated chip: the four corners the 2D `draw_colored_polygon` was given.
func test_rotated_chip_corners_land_on_their_pixels() -> void:
	print("[7] a rotated chip's corners land on the pixels the 2D polygon would")
	var holder := Node3D.new()
	root.add_child(holder)
	var field: RefCounted = QuadField3DRef.new()
	field.attach_rect(holder)
	var basis: Basis = _cam.global_transform.basis
	field.begin(1, basis, PPU)
	var a := Vector3(1.0, 0.2, 2.0)
	var a2: Vector2 = _cam.unproject_position(a)
	var pos: Vector2 = a2 + Vector2(7.0, -25.0)
	var half_w: float = 3.0
	var half_h: float = 2.0
	var rot: float = 0.9
	field.push_axes(a, a2, pos, Vector2(half_w, 0.0).rotated(rot), Vector2(0.0, half_h).rotated(rot), Color.WHITE)
	var buf: PackedFloat32Array = field.buffer()
	var centre := Vector3(buf[3], buf[7], buf[11])
	var bx := Vector3(buf[0], buf[4], buf[8])
	var by := Vector3(buf[1], buf[5], buf[9])
	var worst: float = 0.0
	for corner: Vector2 in [Vector2(-half_w, -half_h), Vector2(half_w, -half_h), Vector2(half_w, half_h), Vector2(-half_w, half_h)]:
		var want: Vector2 = pos + corner.rotated(rot)
		var sx: float = signf(corner.x)
		var sy: float = signf(corner.y)
		var got: Vector2 = _cam.unproject_position(centre + bx * sx + by * sy)
		worst = maxf(worst, (got - want).length())
	_check(worst < EPS_PX, "worst corner error %.4f px" % worst)
	holder.queue_free()
