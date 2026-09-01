## GLASS_MASTER_PLAN §5.1 / G-D11 — GlassShatter selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_shatter
##
## Pins `GlassShatter.p_shatter()` against the Director-approved target
## distribution BY READING THE SHIPPED WEAPON JSONS (res://weapons/*.json), the
## same discipline `test_no_shipped_weapon_reaches_the_cascade` uses for the
## cascade ceiling: a later balance edit to a weapon's `punch` fails this suite
## rather than silently turning a pistol into a pane-breaker.
##
## What each test catches:
##   1. The curve drifting off the target table for any shipped round.
##   2. The shotgun's 24-pellet compound odds drifting off ~38%.
##   3. The flat bottom eroding — a weak hit gaining a shatter chance.
##   4. The ceiling reaching 1.0 — a common round GUARANTEEING a full shatter
##      (only a primed armored pane may, G-D15).
##   5. Monotonicity — more punch must never mean less shatter chance.
##   6. The roll being deterministic and honouring the probability.

extends SceneTree

const GlassShatterClass = preload("res://godot/scripts/systems/destruction/glass_shatter.gd")
const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const WeaponDefClass = preload("res://godot/scripts/systems/destruction/weapon_def.gd")

var passed: int = 0
var failed: int = 0

## Director-approved P(shatter) per round at neutral skill / point blank /
## neutral luck (GLASS_MASTER_PLAN §5.1). Tolerance is generous — the constants
## are `var` placeholders the Director calibrates against real play; this pins
## the SHAPE, not a to-the-percent value.
const TARGETS: Dictionary = {
	"smg": 0.00,
	"pistol": 0.025,
	"revolver": 0.16,
	"assault_rifle": 0.44,
	"sniper_rifle": 0.81,
}
const SINGLE_TOL: float = 0.06
## The shotgun's single pellet, and the 24-pellet blast compound.
const PELLET_TARGET: float = 0.02
const BLAST_TARGET: float = 0.38
const BLAST_TOL: float = 0.08


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G-D11 — SHATTER ROLL SELFTEST")
	print("=".repeat(70) + "\n")

	test_curve_matches_the_arsenal_targets()
	test_shotgun_blast_compound_odds()
	test_flat_bottom_and_capped_ceiling()
	test_monotonic_in_punch()
	test_roll_is_deterministic_and_honours_probability()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS G-D11 SHATTER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS G-D11 SHATTER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## glass_punch for one weapon at neutral skill / point blank / neutral luck.
## Computed directly rather than through ShotPunchTable.compute() so LUCK is
## exactly 1.0 (compute()'s luck_for() midpoint is 1.025, not 1.0).
func _neutral_glass_punch(def: WeaponDef) -> float:
	return ShotPunchTableClass.PUNCH_GAIN * def.punch * ShotPunchTableClass.SKILL_NEUTRAL \
		* 1.0 * 1.0 / ShotPunchTableClass.resistance("glass")


func _load_weapons() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open("res://weapons")
	if dir == null:
		_fail("could not open res://weapons")
		return out
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://weapons/%s" % file_name)
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			_fail("could not parse weapons/%s" % file_name)
			continue
		var def := WeaponDefClass.from_json(data)
		out[def.id] = def
	return out


func test_curve_matches_the_arsenal_targets() -> void:
	print("[1] p_shatter() matches the Director's target for every shipped round\n")
	var weapons := _load_weapons()
	if weapons.is_empty():
		_fail("no weapons loaded")
		print("")
		return
	var all_ok := true
	for wid in TARGETS:
		if not weapons.has(wid):
			_fail("shipped arsenal no longer has '%s' — this test's premise changed" % wid)
			all_ok = false
			continue
		var gp: float = _neutral_glass_punch(weapons[wid])
		var p: float = GlassShatterClass.p_shatter(gp)
		var target: float = TARGETS[wid]
		var ok: bool = absf(p - target) <= SINGLE_TOL
		print("      %-14s glass_punch %.2f  target %5.1f%%  curve %5.1f%%  %s" % [
			wid, gp, target * 100.0, p * 100.0, "OK" if ok else "OFF"])
		all_ok = all_ok and ok
	if all_ok:
		_pass("every shipped round is within %.0f pts of its target" % (SINGLE_TOL * 100.0))
	else:
		_fail("a shipped round drifted off its target by more than %.0f pts" % (SINGLE_TOL * 100.0))
	print("")


func test_shotgun_blast_compound_odds() -> void:
	print("[2] the shotgun's 24-pellet blast compounds to ~38%\n")
	var weapons := _load_weapons()
	if not weapons.has("shotgun"):
		_fail("no shotgun.json")
		print("")
		return
	var sg: WeaponDef = weapons["shotgun"]
	var gp: float = _neutral_glass_punch(sg)
	var per_pellet: float = GlassShatterClass.p_shatter(gp)
	var n: int = maxi(sg.projectile_count, 1)
	var blast: float = 1.0 - pow(1.0 - per_pellet, float(n))
	print("      pellet glass_punch %.2f  per-pellet %.1f%% (target %.0f%%)  blast of %d %.1f%% (target %.0f%%)" % [
		gp, per_pellet * 100.0, PELLET_TARGET * 100.0, n, blast * 100.0, BLAST_TARGET * 100.0])
	var pellet_ok: bool = absf(per_pellet - PELLET_TARGET) <= SINGLE_TOL
	var blast_ok: bool = absf(blast - BLAST_TARGET) <= BLAST_TOL
	if pellet_ok and blast_ok:
		_pass("per-pellet ~%.0f%% compounds to ~%.0f%% over 24 rolls" % [PELLET_TARGET * 100.0, BLAST_TARGET * 100.0])
	else:
		_fail("pellet_ok=%s blast_ok=%s" % [pellet_ok, blast_ok])
	print("")


func test_flat_bottom_and_capped_ceiling() -> void:
	print("[3] the bottom is flat to zero; the ceiling never reaches 1.0\n")
	## Below the smg's own punch nothing shatters — the flat bottom the
	## Director asked for, and what keeps "none of the 24 pellets took it" real.
	var low_ok := true
	for gp in [0.0, 0.5, 1.0, 1.5]:
		if GlassShatterClass.p_shatter(gp) > 0.001:
			low_ok = false
	if low_ok:
		_pass("p_shatter is exactly 0 for glass_punch <= 1.5")
	else:
		_fail("p_shatter is non-zero below glass_punch 1.5 — the flat bottom eroded")

	## Even an absurd round never guarantees a full shatter (G-D15: only a primed
	## armored pane does).
	var top: float = GlassShatterClass.p_shatter(50.0)
	if top < 1.0 and top >= GlassShatterClass.SHATTER_P_MAX - 0.001:
		_pass("p_shatter tops out at SHATTER_P_MAX (%.2f), strictly below 1.0" % GlassShatterClass.SHATTER_P_MAX)
	else:
		_fail("p_shatter at glass_punch 50 is %.4f — expected ~SHATTER_P_MAX and < 1.0" % top)
	print("")


func test_monotonic_in_punch() -> void:
	print("[4] more punch never means a lower shatter chance\n")
	var prev: float = -1.0
	var mono := true
	var gp: float = 0.0
	while gp <= 12.0:
		var p: float = GlassShatterClass.p_shatter(gp)
		if p < prev - 0.0001:
			mono = false
			_fail("p_shatter DROPPED at glass_punch %.2f (%.4f < %.4f)" % [gp, p, prev])
			break
		prev = p
		gp += 0.1
	if mono:
		_pass("p_shatter is monotonic non-decreasing over glass_punch [0, 12]")
	print("")


func test_roll_is_deterministic_and_honours_probability() -> void:
	print("[5] rolls_shatter() is deterministic per salt and matches p_shatter over many salts\n")
	## Determinism: the same salt always rolls the same way.
	var a: bool = GlassShatterClass.rolls_shatter(3.75, "REV7:PELLET3")
	var b: bool = GlassShatterClass.rolls_shatter(3.75, "REV7:PELLET3")
	if a == b:
		_pass("the same (glass_punch, salt) rolls the same outcome")
	else:
		_fail("rolls_shatter is not deterministic for a fixed salt")

	## Frequency: over 4000 distinct salts the win rate tracks p_shatter.
	var gp := 3.75  ## assault rifle, target ~44%
	var expected: float = GlassShatterClass.p_shatter(gp)
	var wins: int = 0
	var trials: int = 4000
	for i in range(trials):
		if GlassShatterClass.rolls_shatter(gp, "FREQ:%d" % i):
			wins += 1
	var rate: float = float(wins) / float(trials)
	print("      glass_punch %.2f  p_shatter %.1f%%  observed %.1f%% over %d salts" % [
		gp, expected * 100.0, rate * 100.0, trials])
	if absf(rate - expected) <= 0.04:
		_pass("observed win rate is within 4 pts of p_shatter")
	else:
		_fail("observed %.1f%% vs expected %.1f%% — the roll does not honour the probability" % [rate * 100.0, expected * 100.0])

	## A weak hit never wins.
	var weak_wins: int = 0
	for i in range(2000):
		if GlassShatterClass.rolls_shatter(1.20, "WEAK:%d" % i):
			weak_wins += 1
	if weak_wins == 0:
		_pass("a glass_punch of 1.20 shatters 0 of 2000 panes")
	else:
		_fail("a weak hit shattered %d of 2000 panes" % weak_wins)
	print("")
