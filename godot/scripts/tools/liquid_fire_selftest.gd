## liquid_fire_selftest — M6 F5: a flammable liquid on fire (`LiquidFire`). Headless: `godot --headless --script res://godot/scripts/tools/liquid_fire_selftest.gd`
## (the arbiter is `tools/persistent/run_selftests.py --only liquid_fire_selftest`).
extends SceneTree

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	print("  %s %s" % ["✓" if ok else "✗ FAILED:", label])
	if not ok:
		_failures += 1


## A closed pool, 0.5 GU cells, 2 voxels of oil everywhere inside: 8 GU wide, 20 GU long, the grid's corner at (10, 0).
func _pool(depth: float) -> RefCounted:
	var plane = load("res://godot/scripts/systems/fluid_plane.gd").new()
	plane.setup(18, 42, 0.5, Vector2(9.5, -0.5), 0.6)
	for r in range(plane.rows):
		for c in range(plane.cols):
			if plane.is_rim(c, r):
				plane.ground[plane.index(c, r)] = 8.0
			else:
				plane.depth[plane.index(c, r)] = depth
	plane.committed = plane.depth.duplicate()
	return plane


func _init() -> void:
	print("\n== LIQUID FIRE SELFTEST ==\n")
	var Fire = load("res://godot/scripts/systems/liquid_fire.gd")
	var plane: RefCounted = _pool(2.0)
	var fire = Fire.new()
	fire.setup(plane, {"speed": 3.0, "burn": 0.15, "dose_step": 0.5, "dose_turn": 0.5})
	_check(fire.count() == 0, "nothing burns until something lights it")
	var lit: int = fire.ignite(Vector2(13.0, 2.0), 0.6)
	_check(lit > 0 and lit == fire.count(), "a blast point lights the wet cells inside its reach (%d)" % lit)
	_check(fire.burning_at(Vector2i(13, 2)) and not fire.burning_at(Vector2i(13, 15)), "the GU under the flame burns, a far one does not")
	var before: int = fire.count()
	fire.tick()
	var after_one: int = fire.count()
	_check(after_one > before, "a turn spreads the front (%d -> %d cells)" % [before, after_one])
	## the front runs speed_gu a turn: from the ignition point, nothing farther than ~3 GU + the first reach
	var far: float = 0.0
	for i in range(fire.burning.size()):
		if fire.burning[i] == 1:
			far = maxf(far, fire.centre_of(i).distance_to(Vector2(13.0, 2.0)))
	_check(far <= 0.6 + 3.0 + 0.5 + 0.01 and far > 2.0, "after one turn the fire reached %.1f GU from the point (speed 3 GU a turn)" % far)
	for _t in range(4):
		fire.tick()
	_check(fire.count() > after_one, "it keeps spreading over the pool on the next turns (%d cells)" % fire.count())
	var eaten: bool = plane.committed[plane.index(9, 9)] < 2.0
	_check(eaten, "the flames eat the oil (the ignition cell's depth fell below 2.0: %.2f)" % plane.committed[plane.index(9, 9)])
	for _t in range(40):
		fire.tick()
	_check(fire.count() == 0, "with the oil burnt away the fire goes out by itself (%d cells left)" % fire.count())

	var wet_plane: RefCounted = _pool(2.0)
	var fire2 = Fire.new()
	fire2.setup(wet_plane, {})
	fire2.ignite(Vector2(13.0, 5.0), 5.0)
	var all_lit: int = fire2.count()
	var water_at := func(gu: Vector2) -> bool: return gu.y < 6.0
	fire2.tick(water_at)
	var left_over: int = 0
	for i in range(fire2.burning.size()):
		if fire2.burning[i] == 1 and fire2.centre_of(i).y < 6.0:
			left_over += 1
	_check(all_lit > 0 and left_over == 0, "water that stands on a burning cell puts it out (%d of %d still burning there)" % [left_over, all_lit])
	var ext: int = fire2.extinguish_rect(Rect2(0.0, 0.0, 100.0, 100.0))
	_check(fire2.count() == 0 and ext >= 0, "an extinguisher's rect puts out every cell inside it")

	var dry: RefCounted = _pool(0.0)
	var fire3 = Fire.new()
	fire3.setup(dry, {})
	_check(fire3.ignite(Vector2(13.0, 5.0), 10.0) == 0, "a dry floor does not burn")

	var a: RefCounted = _pool(2.0)
	var b: RefCounted = _pool(2.0)
	var fa = Fire.new()
	var fb = Fire.new()
	fa.setup(a, {})
	fb.setup(b, {})
	fa.ignite(Vector2(12.0, 3.0), 1.0)
	fb.ignite(Vector2(12.0, 3.0), 1.0)
	for _t in range(12):
		fa.tick()
		fb.tick()
	_check(fa.state() == fb.state() and fa.count() > 0, "the same ignitions and turns burn the same cells (a checkpoint can restore them)")
	var saved: PackedByteArray = fa.state()
	fa.extinguish_all()
	fa.restore(saved)
	_check(fa.state() == saved, "state() / restore() round-trip")

	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
