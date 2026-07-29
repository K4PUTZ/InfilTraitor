## NEON-FLICKER-01 — LightSource flicker selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/neon_flicker_selftest.gd
##
## The flicker is a TIME-SHAPED effect: no screenshot can show that a lamp stays
## lit longer than it stays dark, or that its dark stretches arrive in irregular
## bursts instead of on a metronome. So the shape is measured here, by driving the
## real update_temporal_state() at a real frame delta and reading the resulting
## energy trace — the same call room._process() makes every frame.
##
## The repaint-rate test is not decoration: every energy change schedules an
## incremental relight of the lamp's GUs (room._update_temporal_lights), so an
## over-eager flicker is a performance bug, not just a look. That ceiling is what
## keeps this effect event-driven instead of per-frame analog.

extends SceneTree

const FRAME_DELTA := 1.0 / 60.0
const SIM_SECONDS := 120.0
const INTERVAL := 0.6   ## PLAYGROUND's own map_light_1 flicker_interval

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("NEON-FLICKER-01 — LightSource flicker SELFTEST")
	print("=".repeat(70) + "\n")

	test_lit_far_longer_than_dark()
	test_durations_are_varied_not_binary()
	test_dark_arrives_in_bursts()
	test_deterministic_per_light_identity()
	test_repaint_rate_stays_sane()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ NEON FLICKER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ NEON FLICKER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## One flickering lamp, ready to be driven.
func _make_light(id: String = "map_light_1", cell: Vector2i = Vector2i(5, 3)) -> LightSource:
	var light := LightSource.new()
	light.light_id = id
	light.owner_name = id
	light.cell = cell
	light.set_flicker(true, INTERVAL)
	return light


## Drive `seconds` of frames, returning the per-frame energy_multiplier trace.
func _trace(light: LightSource, seconds: float) -> Array[float]:
	var out: Array[float] = []
	var frames := int(seconds / FRAME_DELTA)
	for _i in range(frames):
		light.update_temporal_state(FRAME_DELTA)
		out.append(light.energy_multiplier)
	return out


## Consecutive equal-energy runs, as [energy, seconds] pairs — the state machine's
## own events, recovered from the trace rather than from its internals.
func _runs(trace: Array[float]) -> Array:
	var out: Array = []
	if trace.is_empty():
		return out
	var current: float = trace[0]
	var count: int = 0
	for e in trace:
		if is_equal_approx(e, current):
			count += 1
		else:
			out.append([current, float(count) * FRAME_DELTA])
			current = e
			count = 1
	out.append([current, float(count) * FRAME_DELTA])
	return out


## Director: "ficando acesa mais tempo que apagada".
func test_lit_far_longer_than_dark() -> void:
	print("[1] Lit far longer than dark\n")
	var trace := _trace(_make_light(), SIM_SECONDS)
	var lit_frames := 0
	for e in trace:
		if e > 0.5:
			lit_frames += 1
	var lit_fraction := float(lit_frames) / float(trace.size())
	if lit_fraction > 0.85:
		_pass("Lit %.1f%% of %ds (old 50/50 square wave was exactly 50%%)" % [lit_fraction * 100.0, int(SIM_SECONDS)])
	else:
		_fail("Lit only %.1f%% of the time — expected > 85%%" % [lit_fraction * 100.0])
	print("")


## Director: "rápidas oscilações variadas ... em vez de ter um ritmo binário fixo".
func test_durations_are_varied_not_binary() -> void:
	print("[2] State durations are varied, not a fixed rhythm\n")
	var runs := _runs(_trace(_make_light(), SIM_SECONDS))
	var distinct: Dictionary = {}
	for r in runs:
		distinct[int(round(float(r[1]) * 1000.0))] = true   ## millisecond buckets
	if distinct.size() >= 20:
		_pass("%d distinct state durations across %d states (a fixed rhythm would yield 1-2)" % [distinct.size(), runs.size()])
	else:
		_fail("Only %d distinct durations across %d states — still reads as a metronome" % [distinct.size(), runs.size()])
	print("")


## Director: "apagando e acendendo de novo" — the dark part is a burst of blips
## separated by brief re-lights, not one long off half-cycle.
func test_dark_arrives_in_bursts() -> void:
	print("[3] Dark stretches arrive as bursts of short blips\n")
	var runs := _runs(_trace(_make_light(), SIM_SECONDS))
	var long_holds := 0     ## lit stretches at least 1.5 x the base interval
	var short_relights := 0 ## lit stretches under 0.3s = inside a burst
	var dark_blips := 0
	for r in runs:
		var energy: float = float(r[0])
		var seconds: float = float(r[1])
		if energy > 0.5:
			if seconds >= INTERVAL * 1.5:
				long_holds += 1
			elif seconds < 0.3:
				short_relights += 1
		else:
			dark_blips += 1
	if long_holds > 0 and short_relights > 0 and dark_blips > 0:
		_pass("%d long lit holds, %d in-burst re-lights, %d dark blips" % [long_holds, short_relights, dark_blips])
	else:
		_fail("Burst structure missing: long_holds=%d short_relights=%d dark_blips=%d" % [long_holds, short_relights, dark_blips])
	print("")


## Same lamp → same sequence every run (reproducible bug reports); two lamps in one
## room → different sequences (no unison blinking).
func test_deterministic_per_light_identity() -> void:
	print("[4] Deterministic per light identity\n")
	var a := _trace(_make_light("map_light_1", Vector2i(5, 3)), 20.0)
	var b := _trace(_make_light("map_light_1", Vector2i(5, 3)), 20.0)
	if a == b:
		_pass("Two lamps with the same id+cell produced byte-identical 20s traces")
	else:
		_fail("Same-identity lamps diverged — flicker is not reproducible")

	var c := _trace(_make_light("map_light_2", Vector2i(11, 8)), 20.0)
	if a != c:
		_pass("A different id+cell produced a different trace (no unison blinking)")
	else:
		_fail("Two different lamps produced identical traces — they will blink in unison")
	print("")


## Every energy change costs one incremental GU relight. The square wave this
## replaced ran at 2 changes per (2 x interval) = 1.67/s at INTERVAL 0.6.
func test_repaint_rate_stays_sane() -> void:
	print("[5] Repaint rate stays in the same order as the old square wave\n")
	var light := _make_light()
	var changes := 0
	var frames := int(SIM_SECONDS / FRAME_DELTA)
	for _i in range(frames):
		light.update_temporal_state(FRAME_DELTA)
		if light.changed_this_frame:
			changes += 1
	var per_second := float(changes) / SIM_SECONDS
	if per_second <= 6.0:
		_pass("%.2f energy changes/s (old square wave: 1.67/s; ceiling for this test: 6.0/s)" % per_second)
	else:
		_fail("%.2f energy changes/s — too many incremental relights" % per_second)
	print("")
