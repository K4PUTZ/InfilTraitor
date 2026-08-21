## MATERIALS_MASTER_PLAN M3-3 — BurnScheduler selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only burn_scheduler
##
## The scheduler is the clock fire burns on: `DetonationPlanBuilder` decides
## which voxels burn away and when (pure, hashed, replayable), and this walks
## that schedule one `advance()` at a time.
##
## What is worth pinning, and why each one would hurt:
##
##   - **advance() WRITES NOTHING.** It returns the due voxels and the room
##     commits them, so `commit_damage()` stays the single writer. A scheduler
##     that destroyed voxels itself would be a second one, and would also be
##     untestable without a room.
##   - **A hole is not a target.** The blast that lit the fire may already have
##     destroyed a scheduled voxel; re-marking it is the defect W-FIX-01 closed
##     on the shot path, and `set_damage()` still does not clamp on purpose.
##   - **ONE advance call** (§3.3). All the delta arithmetic lives in it, so
##     swapping `_process(delta)` for `player_turn_started` is a call-site edit.
##     A test that advanced by wall-clock or by frame count would quietly bless
##     a second timeline.

extends SceneTree

const BurnSchedulerClass = preload("res://godot/scripts/systems/destruction/burn_scheduler.gd")

var passed: int = 0
var failed: int = 0

## LEAK-CYCLE-01: a Voxel does not keep its container alive, so the fixture
## Slabs have to outlive the voxels handed out of them.
var _fixtures: Array = []


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MATERIALS M3-3 — BURN SCHEDULER SELFTEST")
	print("=".repeat(70) + "\n")

	test_nothing_scheduled_is_never_burning()
	test_voxels_come_due_in_time_order()
	test_advance_writes_nothing()
	test_an_already_destroyed_voxel_is_skipped()
	test_ring_grouping_does_not_survive_as_ordering()
	test_cancel_drops_the_schedule()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ BURN SCHEDULER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ BURN SCHEDULER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## N voxels on one fixture Slab, and a `burn` wave scheduling them at the given
## times — shaped exactly like the plan's, `{ring: [entry]}`.
func _wave(times: Array, ring_of: Array = []) -> Dictionary:
	var slab := Slab.new("BURN_FIXTURE_%d" % _fixtures.size(), Vector2i.ZERO,
		Slab.Role.FLOOR, 0, "fabric")
	_fixtures.append(slab)
	var wave: Dictionary = {}
	for i in range(times.size()):
		var voxel := Voxel.new(Vector2i(i, 0), 0, slab)
		slab.voxels.append(voxel)
		var ring: int = int(ring_of[i]) if i < ring_of.size() else 0
		if not wave.has(ring):
			wave[ring] = []
		wave[ring].append({"voxel": voxel, "cell": voxel.grid_pos,
			"level": voxel.level, "at": float(times[i])})
	return wave


func _voxels_of(wave: Dictionary) -> Array:
	var out: Array = []
	var rings: Array = wave.keys()
	rings.sort()
	for ring in rings:
		for entry in wave[ring]:
			out.append(entry["voxel"])
	return out


func test_nothing_scheduled_is_never_burning() -> void:
	print("TEST: an empty schedule never burns, and advance() on it is free")
	var s := BurnSchedulerClass.new()
	if not s.is_burning() and s.advance(10.0).is_empty():
		_pass("is_burning() false, advance(10s) returns []")
	else:
		_fail("an empty scheduler reported work")
	print("")


func test_voxels_come_due_in_time_order() -> void:
	print("TEST: voxels come due in TIME order, and only when their time has come")
	## Deliberately scheduled out of order (1.0, 0.2, 0.6): the plan groups by
	## ring, and ring is not time.
	var wave := _wave([1.0, 0.2, 0.6])
	var voxels: Array = _voxels_of(wave)
	var s := BurnSchedulerClass.new()
	s.schedule(wave)

	if s.scheduled_count() == 3 and s.is_burning():
		_pass("3 scheduled, is_burning() true")
	else:
		_fail("scheduled_count=%d is_burning=%s" % [s.scheduled_count(), s.is_burning()])

	var t1: Array = s.advance(0.1)
	if t1.is_empty():
		_pass("at 0.10s nothing is due (earliest is 0.20s)")
	else:
		_fail("at 0.10s %d voxel(s) came due early" % t1.size())

	var t2: Array = s.advance(0.15)
	if t2.size() == 1 and t2[0] == voxels[1]:
		_pass("at 0.25s exactly the 0.20s voxel is due")
	else:
		_fail("at 0.25s got %d voxel(s), expected the 0.20s one" % t2.size())

	var t3: Array = s.advance(1.0)
	if t3.size() == 2 and t3[0] == voxels[2] and t3[1] == voxels[0]:
		_pass("at 1.25s the remaining two arrive together, still in time order (0.60 then 1.00)")
	else:
		_fail("at 1.25s got %d voxel(s) in the wrong order" % t3.size())

	if not s.is_burning() and s.consumed_count() == 3:
		_pass("fire out: consumed_count() == scheduled_count() == 3")
	else:
		_fail("is_burning=%s consumed=%d" % [s.is_burning(), s.consumed_count()])
	print("")


func test_advance_writes_nothing() -> void:
	print("TEST: advance() WRITES NOTHING — commit_damage() stays the single writer")
	var wave := _wave([0.1, 0.1])
	var voxels: Array = _voxels_of(wave)
	var s := BurnSchedulerClass.new()
	s.schedule(wave)
	var due: Array = s.advance(1.0)
	var untouched := 0
	for v in voxels:
		if v.damage_state == Voxel.DamageState.INTACT and v.visible:
			untouched += 1
	if due.size() == 2 and untouched == 2:
		_pass("2 voxels returned as due, and both are still INTACT and visible")
	else:
		_fail("due=%d untouched=%d — the scheduler mutated the world" % [due.size(), untouched])
	print("")


func test_an_already_destroyed_voxel_is_skipped() -> void:
	print("TEST: a voxel the blast already destroyed is dropped, not re-marked")
	## The real case: the ember wave lights voxels EDGING the holes, but a second
	## grenade — or the same blast's own cascade — can take one before its burn
	## time arrives. `set_damage()` does not clamp (the segment-rewind system
	## needs to walk voxels back), so the check has to live with whoever knows a
	## hole when it sees one.
	var wave := _wave([0.1, 0.2])
	var voxels: Array = _voxels_of(wave)
	voxels[0].set_damage(Voxel.DamageState.DESTROYED, true)
	var s := BurnSchedulerClass.new()
	s.schedule(wave)
	var due: Array = s.advance(1.0)
	if due.size() == 1 and due[0] == voxels[1]:
		_pass("the destroyed voxel is skipped; the intact one still comes due")
	else:
		_fail("got %d due voxel(s), expected only the intact one" % due.size())
	if s.consumed_count() == 1:
		_pass("consumed_count() counts what actually burned (1), not what was scheduled (2)")
	else:
		_fail("consumed_count()=%d" % s.consumed_count())
	print("")


func test_ring_grouping_does_not_survive_as_ordering() -> void:
	print("TEST: RING grouping carries no ordering — `at` does")
	## Every wave in a Delta is `{ring: [entry]}`, and for playback waves the
	## ring IS the order the front expands in. For burn it is not: a voxel in
	## ring 3 can be consumed before one in ring 0 if it caught sooner. Flatten
	## and re-sort, or the fire eats outward in rings like a second blast.
	var wave := _wave([0.9, 0.1], [0, 3])
	var voxels: Array = _voxels_of(wave)
	var s := BurnSchedulerClass.new()
	s.schedule(wave)
	var due: Array = s.advance(0.5)
	if due.size() == 1 and due[0] == voxels[1]:
		_pass("the ring-3 voxel at 0.10s beats the ring-0 voxel at 0.90s")
	else:
		_fail("ring order leaked into burn order: %d due at 0.5s" % due.size())
	print("")


func test_cancel_drops_the_schedule() -> void:
	print("TEST: cancel() drops everything — the seam a perspective flip needs")
	## VL-PERSIST rebuilds every Voxel from the MapSpec on a rotation, so a
	## schedule that survived one would hold objects belonging to no container.
	var wave := _wave([0.1, 0.2, 0.3])
	var s := BurnSchedulerClass.new()
	s.schedule(wave)
	s.cancel()
	if not s.is_burning() and s.advance(10.0).is_empty():
		_pass("after cancel(): is_burning() false, advance(10s) returns []")
	else:
		_fail("cancel() left work pending")
	print("")
