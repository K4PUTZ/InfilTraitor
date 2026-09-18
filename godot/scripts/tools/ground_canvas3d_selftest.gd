## Ground-canvas selftest — RENDER3D R3D-5b.
## Run: python3 tools/persistent/run_selftests.py --only ground_canvas3d_selftest
##
## The claim: an overlay drawn through `GroundCanvas3D` lands on the SAME PIXELS it would have drawn in
## 2D — every vertex of every polygon, line quad and circle, carried onto the ground plane and projected
## through a real `Camera3D`, comes out at the 2D point it came from. If that holds, moving the overlay
## onto the ground changes its depth and nothing else. The camera and the 2D→ground affine are built
## exactly as `Board3DLive._make_camera()` builds them; a comparison against the canvas's own maths would
## pass whatever the constants said.

extends SceneTree

const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
const PPU: float = 256.0 / sqrt(2.0)
const EPS_PX: float = 0.05

var passed: int = 0
var failed: int = 0
var _cam: Camera3D = null
var _board: Node3D = null


## A stand-in for `Board3DLive`: the two accessors the canvas reads.
class StubBoard extends Node3D:
	var to_gu: Transform2D = Transform2D.IDENTITY
	var origin_2d: Vector2 = Vector2.ZERO

	func ground_affine() -> Transform2D:
		return to_gu

	func ground_origin() -> Vector2:
		return origin_2d


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GROUND-CANVAS — 2D overlay onto the ground plane SELFTEST")
	print("=".repeat(70) + "\n")
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_cam.size = 10.0
	_cam.near = 0.05
	_cam.far = 500.0
	root.add_child(_cam)
	_cam.position = Vector3(20.0, 30.0, 20.0)
	await process_frame
	_cam.make_current()
	await process_frame
	var measured: float = (_cam.unproject_position(_cam.global_transform.basis.x)
		- _cam.unproject_position(Vector3.ZERO)).length()
	_cam.size = _cam.size * measured / PPU
	await process_frame

	## The 2D→ground affine, built the way Board3DLive builds it: from where three ground points land.
	_board = StubBoard.new()
	root.add_child(_board)
	var o: Vector2 = _cam.unproject_position(Vector3(0.5, 0.0, 0.5))
	var ex: Vector2 = _cam.unproject_position(Vector3(1.5, 0.0, 0.5)) - o
	var ez: Vector2 = _cam.unproject_position(Vector3(0.5, 0.0, 1.5)) - o
	_board.to_gu = Transform2D(ex, ez, Vector2.ZERO).affine_inverse()
	_board.origin_2d = o

	test_polygon_vertices_land_on_their_pixels()
	test_line_is_a_quad_of_the_asked_width()
	test_circle_and_polyline()
	test_owner_transform_is_applied()
	test_empty_draw_publishes_nothing()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	quit(0 if failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		print("  ✗ FAIL: ", msg)


func _canvas() -> RefCounted:
	var c: RefCounted = GroundCanvas3DRef.new()
	c.attach(_board, 0, 0.0)
	return c


func _worst_error(c: RefCounted, expected: Array) -> float:
	var v: PackedVector3Array = c.vertices()
	var worst: float = 0.0
	for i: int in range(mini(v.size(), expected.size())):
		worst = maxf(worst, (_cam.unproject_position(v[i]) - (expected[i] as Vector2)).length())
	return worst


## [1] A tile's diamond, as the movement overlay draws it: four corners, 256x128 px.
func test_polygon_vertices_land_on_their_pixels() -> void:
	print("[1] a polygon's vertices project onto the 2D points it was given")
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var c: RefCounted = _canvas()
	c.begin(owner_node)
	var top := Vector2(300.0, 200.0)
	var diamond := PackedVector2Array([top, top + Vector2(128, 64), top + Vector2(0, 128), top + Vector2(-128, 64)])
	c.draw_colored_polygon(diamond, Color(0.2, 0.5, 1.0, 0.3))
	var worst: float = _worst_error(c, [diamond[0], diamond[1], diamond[2], diamond[3]])
	_check(c.vertices().size() == 4, "a diamond is four vertices")
	_check(worst < EPS_PX, "worst vertex error %.5f px (limit %.2f)" % [worst, EPS_PX])
	owner_node.queue_free()


## [2] A 3 px selection line is a quad 3 px thick ON SCREEN, whichever way it runs.
func test_line_is_a_quad_of_the_asked_width() -> void:
	print("[2] a line is a quad exactly as thick, on screen, as the 2D line was")
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var c: RefCounted = _canvas()
	c.begin(owner_node)
	var a := Vector2(100.0, 150.0)
	var b := Vector2(228.0, 214.0)  ## a diamond edge, the case that matters
	c.draw_line(a, b, Color.WHITE, 4.0)
	var v: PackedVector3Array = c.vertices()
	var p0: Vector2 = _cam.unproject_position(v[0])
	var p1: Vector2 = _cam.unproject_position(v[1])
	var p3: Vector2 = _cam.unproject_position(v[3])
	_check(absf((p1 - p0).length() - 4.0) < EPS_PX, "thickness %.4f px, wanted 4.0" % (p1 - p0).length())
	_check(absf((p3 - p0).length() - (b - a).length()) < EPS_PX, "length %.4f px, wanted %.4f" % [(p3 - p0).length(), (b - a).length()])
	## The projection is exact to ~0.005 px and the width is only 4 px, so the angle is good to ~0.002 rad.
	var cos_angle: float = absf((p1 - p0).normalized().dot((b - a).normalized()))
	_check(cos_angle < 0.01, "the width is perpendicular to the line on screen (cos %.5f)" % cos_angle)
	owner_node.queue_free()


## [3] A circle is a fan whose rim stays on the 2D circle; a polyline is one quad per segment.
func test_circle_and_polyline() -> void:
	print("[3] a circle's rim and a polyline's segments land on their pixels")
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var c: RefCounted = _canvas()
	c.begin(owner_node)
	var centre := Vector2(400.0, 260.0)
	c.draw_circle(centre, 60.0, Color.RED)
	var v: PackedVector3Array = c.vertices()
	var worst: float = 0.0
	for i: int in range(1, v.size()):
		worst = maxf(worst, absf((_cam.unproject_position(v[i]) - centre).length() - 60.0))
	_check(v.size() == 1 + GroundCanvas3DRef.CIRCLE_SEGMENTS, "a fan: centre + %d rim vertices" % GroundCanvas3DRef.CIRCLE_SEGMENTS)
	_check(worst < EPS_PX, "every rim vertex 60 px from the centre (worst %.5f px off)" % worst)
	c.begin(owner_node)
	c.draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(50, 20), Vector2(90, 90)]), Color.WHITE, 2.0)
	_check(c.vertices().size() == 8, "two segments are two quads (8 vertices), got %d" % c.vertices().size())
	owner_node.queue_free()


## [4] An overlay under a moved parent draws in its own local space: the owner's transform is applied.
func test_owner_transform_is_applied() -> void:
	print("[4] the owner's global transform is applied to local points")
	var owner_node := Node2D.new()
	owner_node.position = Vector2(50.0, -30.0)
	root.add_child(owner_node)
	var c: RefCounted = _canvas()
	c.begin(owner_node)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]), Color.WHITE)
	var got: Vector2 = _cam.unproject_position(c.vertices()[0])
	_check((got - Vector2(50.0, -30.0)).length() < EPS_PX, "local (0,0) lands at the owner's origin (%.5f px off)" % (got - Vector2(50.0, -30.0)).length())
	owner_node.queue_free()


func test_empty_draw_publishes_nothing() -> void:
	print("[5] an overlay that draws nothing leaves nothing on the board")
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var c: RefCounted = _canvas()
	c.begin(owner_node)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]), Color.WHITE)
	c.end()
	c.clear()
	_check(c.vertices().is_empty(), "cleared: no vertices")
	owner_node.queue_free()
