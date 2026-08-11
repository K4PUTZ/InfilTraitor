## IsoProjection selftest — the aiming overlays' geometry, checked against the
## REAL TileSet instead of against itself.
## Run: python3 tools/persistent/run_selftests.py --only iso_projection_selftest
##
## Why this file exists. T-BUBBLE's first pass sized the aim bubble with
## `max_ring * 112.0 * 3.0`, drew it as a circle over a 2:1 perimeter ellipse,
## and clamped the cursor with a third shape again. Nothing was wrong in a way a
## compiler could see; it was wrong in a way only the screen showed. Every claim
## IsoProjection makes is therefore asserted here, and test [1] asserts the two
## horizontal basis vectors against `tileset_blocks.tres` itself — a
## self-comparison would pass no matter what the constants said.

extends SceneTree

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const EPS := 0.0001

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ISO-PROJECTION — aiming geometry SELFTEST")
	print("=".repeat(70) + "\n")

	await test_basis_matches_real_tileset()
	test_ellipses_are_axis_aligned()
	test_floor_ellipse_is_two_to_one()
	test_dome_is_a_real_hemisphere()
	test_arc_endpoints_seam_exactly()
	test_projection_preserves_grid_distance()
	test_dome_covers_three_by_three_gu()
	test_throw_perimeter_lands_on_cell_centres()
	test_throw_arc_goes_up()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ ISO-PROJECTION SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ ISO-PROJECTION SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## [1] The anti-tautology check: AXIS_X/AXIS_Y are what the game's own TileSet
## does, not what Godot's layout enum is documented to do.
func test_basis_matches_real_tileset() -> void:
	print("[1] The horizontal basis is the real TileSet's, not a reasoned one\n")
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		_fail("could not load %s — nothing to check the basis against" % TILESET_PATH)
		print("")
		return
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame

	var origin: Vector2 = layer.map_to_local(Vector2i(0, 0))
	var measured_x: Vector2 = layer.map_to_local(Vector2i(1, 0)) - origin
	var measured_y: Vector2 = layer.map_to_local(Vector2i(0, 1)) - origin

	if measured_x.is_equal_approx(IsoProjection.AXIS_X) \
			and measured_y.is_equal_approx(IsoProjection.AXIS_Y):
		_pass("map_to_local deltas %s / %s match AXIS_X / AXIS_Y exactly" % [measured_x, measured_y])
	else:
		_fail("TileSet says %s / %s but IsoProjection has %s / %s" %
			[measured_x, measured_y, IsoProjection.AXIS_X, IsoProjection.AXIS_Y])

	## And the basis has to stay linear over a real distance, not just one step.
	var far: Vector2 = layer.map_to_local(Vector2i(7, -3)) - origin
	var predicted: Vector2 = 7.0 * IsoProjection.AXIS_X - 3.0 * IsoProjection.AXIS_Y
	if far.is_equal_approx(predicted):
		_pass("cell (7,-3) projects to %s — the basis is linear across the map" % far)
	else:
		_fail("cell (7,-3): TileSet says %s, basis predicts %s" % [far, predicted])

	layer.queue_free()
	print("")


## [2] Zero off-diagonal is the reason every ellipse here is screen-axis-aligned
## and can be drawn from two semi-axes. If it ever stops being zero, the shapes
## need a rotation and the overlays are silently wrong.
func test_ellipses_are_axis_aligned() -> void:
	print("[2] The projection's M·Mᵀ off-diagonal is zero (no rotation)\n")
	var off: float = IsoProjection.off_diagonal()
	if absf(off) < EPS:
		_pass("off_diagonal() = %.6f — ellipses are screen-axis-aligned" % off)
	else:
		_fail("off_diagonal() = %.6f — the ellipses are rotated and both overlays lie" % off)
	print("")


## [3] The isometric floor ellipse, derived rather than hand-halved.
func test_floor_ellipse_is_two_to_one() -> void:
	print("[3] A floor circle projects to an exactly 2:1 ellipse\n")
	for radius_gu: float in [0.5, 1.5, 6.5]:
		var axes: Vector2 = IsoProjection.floor_circle_semi_axes(radius_gu)
		if absf(axes.x - axes.y * 2.0) < EPS:
			_pass("R=%.1f GU → (%.2f, %.2f) px, ratio exactly 2:1" % [radius_gu, axes.x, axes.y])
		else:
			_fail("R=%.1f GU → (%.2f, %.2f) px — not 2:1" % [radius_gu, axes.x, axes.y])
	print("")


## [4] The dome's two half-ellipses must share their horizontal semi-axis, or the
## silhouette and its floor section cross instead of meeting tangentially — the
## shape stops being a hemisphere and starts being two overlapping blobs.
func test_dome_is_a_real_hemisphere() -> void:
	print("[4] Sphere and floor ellipses are tangent at the left/right extremes\n")
	var radius_gu := 1.5
	var sphere: Vector2 = IsoProjection.sphere_semi_axes(radius_gu)
	var floor_axes: Vector2 = IsoProjection.floor_circle_semi_axes(radius_gu)
	if absf(sphere.x - floor_axes.x) < EPS:
		_pass("both share semi-axis x = %.2f px — the seam is exact" % sphere.x)
	else:
		_fail("sphere x=%.2f vs floor x=%.2f — the dome would not close" % [sphere.x, floor_axes.x])

	## A sphere must also stand taller than its own ground section, or there is
	## no dome above the floor at all.
	if sphere.y > floor_axes.y:
		_pass("dome rises %.2f px above a section only %.2f px deep" % [sphere.y, floor_axes.y])
	else:
		_fail("sphere y=%.2f is not above floor y=%.2f — no dome" % [sphere.y, floor_axes.y])
	print("")


## [5] The dome polygon is built from two arcs joined end to end. If their
## endpoints are not identical the fill has a notch in it.
func test_arc_endpoints_seam_exactly() -> void:
	print("[5] ellipse_arc endpoints land on the axes, so the two halves seam\n")
	var radius_gu := 1.5
	var sphere: Vector2 = IsoProjection.sphere_semi_axes(radius_gu)
	var floor_axes: Vector2 = IsoProjection.floor_circle_semi_axes(radius_gu)
	var center := Vector2(1000.0, 500.0)

	var top := IsoProjection.ellipse_arc(center, sphere, 0.0, PI, 16)
	var bottom := IsoProjection.ellipse_arc(center, floor_axes, PI, TAU, 16)

	if top[0].is_equal_approx(bottom[bottom.size() - 1]) \
			and top[top.size() - 1].is_equal_approx(bottom[0]):
		_pass("top arc ends where the bottom arc starts, both ways round")
	else:
		_fail("seam gap: top %s..%s vs bottom %s..%s" %
			[top[0], top[top.size() - 1], bottom[0], bottom[bottom.size() - 1]])

	## The top arc must be ABOVE the centre (screen Y grows downward).
	var apex: Vector2 = top[top.size() / 2]
	if apex.y < center.y:
		_pass("apex at %s is above the centre — the arc is the upper half" % apex)
	else:
		_fail("apex at %s is not above the centre %s" % [apex, center])
	print("")


## [6] The property that makes the dome's radius mean something in GU at all:
## the projection preserves the GRID metric exactly. A cell `d` GU away lands at
## normalised radius (d/R)² on the projected ellipse, whatever direction it is
## in. Without this, "a 2 GU dome" would be 2 GU in some directions and less in
## others, and every coverage claim below would be a coincidence.
func test_projection_preserves_grid_distance() -> void:
	print("[6] The projected ellipse preserves grid distance exactly\n")
	var radius_gu := 2.0
	var axes: Vector2 = IsoProjection.floor_circle_semi_axes(radius_gu)
	var ok := true
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(1, -1), Vector2i(2, 0), Vector2i(3, -2), Vector2i(-2, 1)]:
		var measured: float = _normalised_radius(offset.x, offset.y, axes)
		var grid_dist: float = Vector2(offset).length()
		var expected: float = (grid_dist * grid_dist) / (radius_gu * radius_gu)
		if absf(measured - expected) > EPS:
			_fail("offset %s: ellipse says %.6f, grid distance says %.6f" %
				[offset, measured, expected])
			ok = false
	if ok:
		_pass("normalised radius == (grid distance / R)² for every sampled offset")
	print("")


## [7] The Director's actual requirement, in the Director's own units. First
## "cobrindo uma área de 3x3 GU aproximadamente", then widened: "vamos fazer 2,
## para ficar uma sobrinha por cima de outras GUs nos cantos. A ideia é indicar
## que a granada é meio imprecisa" (2026-08-10). Tested where it matters — in
## SCREEN space, against the projected ellipse the player sees.
func test_dome_covers_three_by_three_gu() -> void:
	print("[7] A 2.0 GU dome clears the 3x3 block and spills onto its neighbours\n")
	var axes: Vector2 = IsoProjection.floor_circle_semi_axes(2.0)

	var inside_all := true
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if _normalised_radius(dx, dy, axes) >= 1.0:
				_fail("cell offset (%d,%d) of the 3x3 block is not inside the dome" % [dx, dy])
				inside_all = false
	if inside_all:
		_pass("all 9 cell centres of the 3x3 block sit inside, with margin")

	## THE SPILL, which is the whole reason for 2.0 over 1.5: the rim reaches the
	## centres of the cells two out along each axis. Anything less and the dome
	## stops at the block's own edge, which is the precision the Director does
	## NOT want it to imply.
	var spilled := true
	for offset: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		if absf(_normalised_radius(offset.x, offset.y, axes) - 1.0) > EPS:
			_fail("offset %s should sit ON the rim, got %.4f" %
				[offset, _normalised_radius(offset.x, offset.y, axes)])
			spilled = false
	if spilled:
		_pass("the rim passes through the 4 cells two out — the blast reads imprecise")

	var outside_all := true
	for offset: Vector2i in [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 0), Vector2i(-1, -2)]:
		if _normalised_radius(offset.x, offset.y, axes) <= 1.0:
			_fail("cell offset %s is beyond 2 GU but lands inside the dome" % offset)
			outside_all = false
	if outside_all:
		_pass("nothing past 2 GU is covered — the dome stays a dome, not a footprint")
	print("")


## [9] Director, 2026-08-10: "o perímetro precisa passar pelo centro das últimas
## GUs que o arremesso alcança." That only happens at a WHOLE number of GU, and
## the failure mode is invisible — a fractional radius still draws a perfectly
## good ellipse, it just runs through empty space between two rings. Pinned so
## the next person to tune `throw_range_gu` finds out from a test rather than
## from a screenshot.
func test_throw_perimeter_lands_on_cell_centres() -> void:
	print("[9] The throw perimeter passes through the last reachable GU centres\n")
	var whole := 7.0
	var axes: Vector2 = IsoProjection.floor_circle_semi_axes(whole)
	var on_rim := true
	for offset: Vector2i in [Vector2i(7, 0), Vector2i(-7, 0), Vector2i(0, 7), Vector2i(0, -7)]:
		if absf(_normalised_radius(offset.x, offset.y, axes) - 1.0) > EPS:
			_fail("at R=%.1f GU, cell %s is not on the perimeter" % [whole, offset])
			on_rim = false
	if on_rim:
		_pass("at R=7 GU the ellipse runs exactly through those 4 cell centres")

	## The counter-case, which is why this test exists: 6.5² = 42.25 is not a sum
	## of two squared integers, so no cell centre can sit on that rim at all.
	var half: float = 6.5
	var half_axes: Vector2 = IsoProjection.floor_circle_semi_axes(half)
	var any_hit := false
	for dx: int in range(-7, 8):
		for dy: int in range(-7, 8):
			if absf(_normalised_radius(dx, dy, half_axes) - 1.0) <= EPS:
				any_hit = true
	if any_hit:
		_fail("a 6.5 GU perimeter touches a cell centre — the premise of this test is wrong")
	else:
		_pass("a 6.5 GU perimeter touches no cell centre at all — keep the radius whole")
	print("")


## [8] The throw parabola, pinned because its first version was upside down —
## it sagged BELOW the chord instead of arcing over it, and a grenade does not
## fall upward on the way out.
func test_throw_arc_goes_up() -> void:
	print("[8] The throw arc rises above its own chord, and lands where aimed\n")
	var from_pos := Vector2(400.0, 600.0)
	var to_pos := Vector2(900.0, 640.0)
	var height: float = ThrowArcOverlay.arc_height_for(from_pos, to_pos, 0.35)

	if not ThrowArcOverlay.arc_point(from_pos, to_pos, 0.0, height).is_equal_approx(from_pos) \
			or not ThrowArcOverlay.arc_point(from_pos, to_pos, 1.0, height).is_equal_approx(to_pos):
		_fail("the arc does not start at the hand or end at the target cell")
	else:
		_pass("t=0 is the hand and t=1 is the target — endpoints are exact")

	var above := true
	for i: int in range(1, 20):
		var t: float = float(i) / 20.0
		var on_arc: Vector2 = ThrowArcOverlay.arc_point(from_pos, to_pos, t, height)
		var on_chord: Vector2 = from_pos.lerp(to_pos, t)
		if on_arc.y >= on_chord.y:
			_fail("at t=%.2f the arc is at y=%.1f, not above the chord's %.1f" %
				[t, on_arc.y, on_chord.y])
			above = false
			break
	if above:
		_pass("every interior point is above the chord — the grenade rises, then falls")

	## A throw straight down the screen must still arc. The first version scaled
	## its height by the horizontal distance alone, so this case was a flat line.
	var vertical_height: float = ThrowArcOverlay.arc_height_for(
		Vector2(500.0, 200.0), Vector2(500.0, 800.0), 0.35)
	if vertical_height > 1.0:
		_pass("a purely vertical throw still gets %.1f px of apex" % vertical_height)
	else:
		_fail("a purely vertical throw arcs by %.1f px — that is a straight line" % vertical_height)

	## The bounce leaves and rejoins the floor without a step at either end.
	if absf(ThrowArcOverlay.bounce_lift(0.0, 50.0)) < EPS \
			and absf(ThrowArcOverlay.bounce_lift(1.0, 50.0)) < EPS \
			and ThrowArcOverlay.bounce_lift(0.5, 50.0) > 0.0:
		_pass("the landing hop starts and ends on the ground, peaking in between")
	else:
		_fail("the landing hop does not return to the ground")
	print("")


## Where a cell centre `offset` cells away lands on the ellipse: <= 1.0 is inside.
func _normalised_radius(dx: int, dy: int, axes: Vector2) -> float:
	var p: Vector2 = float(dx) * IsoProjection.AXIS_X + float(dy) * IsoProjection.AXIS_Y
	return (p.x * p.x) / (axes.x * axes.x) + (p.y * p.y) / (axes.y * axes.y)
