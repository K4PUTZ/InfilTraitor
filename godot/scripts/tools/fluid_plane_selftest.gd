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


func _golden_channel() -> RefCounted:
	var plane = load("res://godot/scripts/systems/fluid_plane.gd").new()
	var rect := Rect2(11.25, 1.0, 1.5, 10.0)
	plane.setup(int(rect.size.x / 0.25) + 2, int(rect.size.y / 0.25) + 2, 0.25, rect.position - Vector2(0.25, 0.25), 0.55)
	for r in range(plane.rows):
		for c in range(plane.cols):
			if plane.is_rim(c, r):
				plane.ground[plane.index(c, r)] = 2.0
	for w in [Rect2(11.0, 0.75, 2.0, 0.25), Rect2(11.0, 11.0, 2.0, 0.25), Rect2(11.0, 1.0, 0.25, 2.0), Rect2(12.75, 1.0, 0.25, 2.0), Rect2(11.0, 9.0, 0.25, 2.0), Rect2(12.75, 9.0, 0.25, 2.0)]:
		plane.set_ground_rect(w, 8.0)
	plane.set_ceiling_rect(Rect2(11.25, 1.0, 1.5, 2.0), 6.0)
	plane.set_ceiling_rect(Rect2(11.25, 9.0, 1.5, 2.0), 6.0)
	plane.add_source(Rect2(11.25, 1.0, 1.5, 0.25), 2.0)
	plane.add_sink(Rect2(11.25, 10.75, 1.5, 0.25), 1.0)
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
	## The loop was rewritten for speed (M6 F8, 2026-10-17); a digest taken from the FIRST form (a channel with walls, roofs, grates, a valve shut at tick 60)
	## must still come out of it, bit for bit. A change that is meant to alter the flow has to re-take these numbers on purpose.
	var gold = _golden_channel()
	var digest: int = 2166136261
	var seen: Array = []
	for t in range(1, 121):
		if t == 60:
			gold.set_source_rate(0, 0.0)
		gold.tick()
		if t % 40 == 0:
			for i in range(gold.depth.size()):
				digest = ((digest ^ int(round(gold.depth[i] * 10000.0))) * 16777619) & 0xFFFFFFFF
			seen.append(digest)
	_check(seen == [2507004377, 449335435, 984992381] and is_equal_approx(gold.spilled, 193.9446), "the lean loop gives the first form's digests bit for bit (%s, spilled %.4f)" % [str(seen), gold.spilled])
	## The incremental tick (rounds spread over frames) must land on the same depths as the synchronous one, and the rules' `committed` depths must not move
	## while it runs (they change only when the NEXT tick begins), whatever the number of rounds a frame.
	var sync = _golden_channel()
	var spread = _golden_channel()
	var frozen: bool = true
	for _t in range(30):
		sync.tick()
		spread.begin_tick()
		var seen_committed: PackedFloat32Array = spread.committed.duplicate()
		while spread.has_pending():
			spread.step_rounds(3)
			frozen = frozen and spread.committed == seen_committed
	spread.finish_tick()
	_check(frozen, "the committed depths hold still while a tick's rounds run, three at a time")
	var same: bool = true
	for i in range(sync.depth.size()):
		same = same and sync.depth[i] == spread.depth[i]
	_check(same and sync.spilled == spread.spilled, "30 ticks run as spread rounds end on exactly the synchronous depths")
	_check(spread.committed != spread.depth, "committed is one tick behind the live depths between ticks (it moves when the next tick begins)")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
