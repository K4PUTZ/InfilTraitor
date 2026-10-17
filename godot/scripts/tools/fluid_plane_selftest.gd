## M6 F1 — `FluidPlane`: mass is conserved, the same inputs give the same depths, a channel fills from its source toward its drain, a body whose
## level reaches the rim overflows (the level rises to the curb), and a GRATE lets a thin liquid through and stops a thick one.
extends SceneTree

const FluidPlaneClass = preload("res://godot/scripts/systems/fluid_plane.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


## PIPE_LAB's channel as the plane sees it: 1.5 GU wide and 10 GU long, cells of 0.25 GU, a pipe bore at each end (2 GU, rim = the pipe's
## shell), a curb two voxels high along the 6 GU between them, a grate 0.25 GU inside each mouth.
func _channel(fluidity: float, source_rate: float, with_sink: bool) -> RefCounted:
	var plane = FluidPlaneClass.new()
	plane.setup(8, 42, 0.25, Vector2(11.0, 0.75), fluidity)
	plane.set_ground_rect(Rect2(11.0, 0.75, 0.25, 10.5), 2.0)      # the curbs
	plane.set_ground_rect(Rect2(12.75, 0.75, 0.25, 10.5), 2.0)
	plane.set_ground_rect(Rect2(11.0, 0.75, 2.0, 0.25), 8.0)       # the back of each bore
	plane.set_ground_rect(Rect2(11.0, 11.0, 2.0, 0.25), 8.0)
	plane.set_ground_rect(Rect2(11.0, 1.0, 0.25, 2.0), 8.0)        # the pipes' shells
	plane.set_ground_rect(Rect2(12.75, 1.0, 0.25, 2.0), 8.0)
	plane.set_ground_rect(Rect2(11.0, 9.0, 0.25, 2.0), 8.0)
	plane.set_ground_rect(Rect2(12.75, 9.0, 0.25, 2.0), 8.0)
	plane.set_ceiling_rect(Rect2(11.25, 1.0, 1.5, 2.0), 6.0)       # the bore's roof (the pipe's inside radius is six voxels)
	plane.set_ceiling_rect(Rect2(11.25, 9.0, 1.5, 2.0), 6.0)
	plane.add_source(Rect2(11.25, 1.0, 1.5, 0.25), source_rate)
	if with_sink:
		plane.add_sink(Rect2(11.25, 10.75, 1.5, 0.25), source_rate)
	plane.add_grate("y", 2.75)
	plane.add_grate("y", 9.25)
	return plane


func _depth_at_y(plane: RefCounted, y: float) -> float:
	var sum: float = 0.0
	for c in range(1, plane.cols - 1):
		sum += plane.depth[plane.index(c, plane.cell_of(Vector2(12.0, y)).y)]
	return sum / float(plane.cols - 2)


func _init() -> void:
	print("\n== FLUID PLANE SELFTEST ==\n")
	var closed = FluidPlaneClass.new()
	closed.setup(6, 6, 0.25, Vector2.ZERO, 1.0)
	closed.set_ground_rect(Rect2(0, 0, 1.5, 0.25), 8.0)
	closed.set_ground_rect(Rect2(0, 1.25, 1.5, 0.25), 8.0)
	closed.set_ground_rect(Rect2(0, 0, 0.25, 1.5), 8.0)
	closed.set_ground_rect(Rect2(1.25, 0, 0.25, 1.5), 8.0)
	closed.add_source(Rect2(0.25, 0.25, 0.25, 0.25), 1.0)
	for _t in range(3):
		closed.tick()
	var injected: float = 3.0
	_check(absf(closed.total_volume() - injected) < 0.001 and closed.spilled == 0.0, "a closed basin keeps every drop it is given (%.3f of %.1f)" % [closed.total_volume(), injected])
	var settled: float = closed.depth[closed.index(1, 1)]
	for _t in range(20):
		closed.tick()
	var lo: float = 99.0
	var hi: float = 0.0
	for r in range(1, 5):
		for c in range(1, 5):
			lo = minf(lo, closed.depth[closed.index(c, r)])
			hi = maxf(hi, closed.depth[closed.index(c, r)])
	_check(settled > 0.0 and hi - lo < 0.05, "left alone, a basin settles flat (spread %.4f)" % (hi - lo))

	var a = _channel(1.0, 2.0, true)
	var b = _channel(1.0, 2.0, true)
	for _t in range(12):
		a.tick()
		b.tick()
	_check(a.depth == b.depth and a.spilled == b.spilled, "two runs of the same body give the same depths, cell for cell")

	var thin = _channel(1.0, 2.0, true)
	var near_a: float = 0.0
	var near_b: float = 0.0
	for t in range(60):
		thin.tick()
		if t == 5:
			near_a = _depth_at_y(thin, 4.0)
			near_b = _depth_at_y(thin, 8.0)
	print("    thin, tick 5: depth at y=4 %.2f, y=8 %.2f; tick 60: bore B %.2f, volume %.1f" % [near_a, near_b, _depth_at_y(thin, 10.0), thin.total_volume()])
	_check(near_a > near_b, "the channel fills from the source toward the drain (y=4: %.2f, y=8: %.2f at tick 5)" % [near_a, near_b])
	_check(_depth_at_y(thin, 10.0) > 0.05, "a thin liquid crosses the grates and reaches the far pipe (%.2f)" % _depth_at_y(thin, 10.0))

	var brim = _channel(1.0, 6.0, false)
	for _t in range(120):
		brim.tick()
	var mid: float = _depth_at_y(brim, 6.0)
	_check(mid >= 1.9 and brim.spilled > 0.0, "with the drain shut the level rises to the curb (%.2f voxels of 2) and spills over it (%.1f)" % [mid, brim.spilled])

	var tar = _channel(0.1, 6.0, false)
	for _t in range(60):
		tar.tick()
	var behind: float = _depth_at_y(tar, 2.0)
	var beyond: float = _depth_at_y(tar, 6.0)
	_check(behind > 0.1 and behind <= 6.0 and beyond < 0.01, "a thick liquid stops at the grate (behind %.2f, beyond %.4f)" % [behind, beyond])
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
