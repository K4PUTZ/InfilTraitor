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
	test_region_radius_scales_with_punch()
	test_small_pane_is_binary_with_remnants()
	test_big_pane_partial_then_full()
	test_remnant_floor_never_leaves_zero_border()

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


## One SW-face glass panel pane: `gu_x` GUs wide along X at y=3, `storeys` tall,
## every voxel visible, `pane_id` stamped. Mirrors what GlassPaneGrouper +
## SliceGenerator produce for a `panels` entry.
func _pane(gu_x_lo: int, gu_x_hi: int, storeys: int) -> Array:
	var slices: Array = []
	var base: int = GeometryCoords.storey_level_base(0)
	for gx in range(gu_x_lo, gu_x_hi + 1):
		var s := Slice.new("PANE_S_%d" % gx, Vector2i(gx, 3), Face.SW, "PANE_E_%d" % gx, storeys, "glass")
		s.pane_id = "PANE_TEST"
		for lvl_off in range(storeys * 8):
			for i in range(8):
				var v := Voxel.new(Vector2i(gx * 8 + i, 3 * 8 + 7), base + lvl_off, s)
				s.voxels.append(v)
		slices.append(s)
	return slices


func _count_visible(slices: Array) -> int:
	var n: int = 0
	for s in slices:
		for v in s.voxels:
			if v.visible and v.damage_state != Voxel.DamageState.DESTROYED:
				n += 1
	return n


func _apply(slices: Array, plan: Array) -> void:
	for e in plan:
		var s: Slice = e["slice"]
		s.voxels[int(e["voxel_index"])].set_damage(Voxel.DamageState.DESTROYED, false, 0, 0, 0)


## Every voxel on the pane's outer frame (col 0 of the leftmost GU, col 7 of the
## rightmost, bottom and top level) that is still standing.
func _surviving_border(slices: Array, gu_x_lo: int, gu_x_hi: int, storeys: int) -> int:
	var base: int = GeometryCoords.storey_level_base(0)
	var col_min: int = gu_x_lo * 8
	var col_max: int = gu_x_hi * 8 + 7
	var lvl_min: int = base
	var lvl_max: int = base + storeys * 8 - 1
	var n: int = 0
	for s in slices:
		for v in s.voxels:
			if v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			if v.grid_pos.x == col_min or v.grid_pos.x == col_max or v.level == lvl_min or v.level == lvl_max:
				n += 1
	return n


func test_region_radius_scales_with_punch() -> void:
	print("[6] region_radius() is monotonic and at least the base\n")
	var prev: int = -1
	var mono := true
	for gp in [0.0, 2.0, 2.63, 3.75, 5.25, 9.0]:
		var r: int = GlassShatterClass.region_radius(gp)
		if r < prev:
			mono = false
		if r < int(round(GlassShatterClass.SHATTER_REGION_BASE)):
			mono = false
		prev = r
	var r_rev: int = GlassShatterClass.region_radius(2.63)
	var r_snp: int = GlassShatterClass.region_radius(5.25)
	if mono and r_snp > r_rev:
		_pass("radius grows with punch (revolver %d < sniper %d), never below base %d" % [
			r_rev, r_snp, int(round(GlassShatterClass.SHATTER_REGION_BASE))])
	else:
		_fail("radius not monotonic / below base (rev %d, sniper %d)" % [r_rev, r_snp])
	print("")


func test_small_pane_is_binary_with_remnants() -> void:
	print("[7] a small pane (1 GU x 1 storey) breaks whole, minus frame remnants\n")
	var slices := _pane(4, 4, 1)
	var total := _count_visible(slices)
	## Rifle-class win, hit dead centre.
	var plan := GlassShatterClass.plan_pane_shatter(slices, Face.SW,
		Vector2i(4 * 8 + 4, 0), GeometryCoords.storey_level_base(0) + 3, 3.75, "SMALL:1")
	_apply(slices, plan)
	var left := _count_visible(slices)
	var border := _surviving_border(slices, 4, 4, 1)
	print("      64 voxels -> %d destroyed, %d left, %d border survivors" % [plan.size(), left, border])
	if left > 0 and left <= total - 40 and border >= GlassShatterClass.SHATTER_REMNANT_MIN_COUNT:
		_pass("the small pane is mostly gone (%d/64 destroyed) with %d frame remnants" % [plan.size(), border])
	else:
		_fail("small pane: destroyed=%d left=%d border=%d (want most gone, border >= %d)" % [
			plan.size(), left, border, GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])
	print("")


func test_big_pane_partial_then_full() -> void:
	print("[8] a big pane (6 GU x 3 storeys) breaks PARTIALLY on a weak win, fully on a sniper\n")
	var total := 6 * 8 * 3 * 8   ## 1152
	var mid_col := 10 * 8         ## centre of GUs 7..12 in grid-x (56..103)
	var mid_lvl := GeometryCoords.storey_level_base(0) + 12

	var weak := _pane(7, 12, 3)
	var weak_plan := GlassShatterClass.plan_pane_shatter(weak, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 2.63, "BIG:weak")
	var full := _pane(7, 12, 3)
	var full_plan := GlassShatterClass.plan_pane_shatter(full, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 5.25, "BIG:full")
	print("      %d voxels: revolver win -> %d destroyed (%.0f%%);  sniper win -> %d destroyed (%.0f%%)" % [
		total, weak_plan.size(), 100.0 * weak_plan.size() / total,
		full_plan.size(), 100.0 * full_plan.size() / total])
	var partial_ok: bool = weak_plan.size() > 0 and weak_plan.size() < total / 2
	var full_ok: bool = full_plan.size() > total * 0.75 and full_plan.size() < total
	if partial_ok and full_ok:
		_pass("revolver takes a patch (%d/%d), sniper takes almost the lot (%d/%d) but not every voxel" % [
			weak_plan.size(), total, full_plan.size(), total])
	else:
		_fail("partial_ok=%s (%d) full_ok=%s (%d)" % [partial_ok, weak_plan.size(), full_ok, full_plan.size()])
	print("")


func test_remnant_floor_never_leaves_zero_border() -> void:
	print("[9] G-D13: no won roll ever leaves a pane with zero surviving border voxels\n")
	var worst_border: int = 1 << 30
	for trial in range(60):
		var storeys: int = 1 + (trial % 3)
		var slices := _pane(2, 2 + (trial % 4), storeys)
		var plan := GlassShatterClass.plan_pane_shatter(slices, Face.SW,
			Vector2i(2 * 8 + 4, 0), GeometryCoords.storey_level_base(0) + storeys * 4, 6.0, "REMNANT:%d" % trial)
		_apply(slices, plan)
		var b := _surviving_border(slices, 2, 2 + (trial % 4), storeys)
		worst_border = mini(worst_border, b)
	if worst_border >= 1:
		_pass("across 60 full-shatter rolls the fewest border survivors was %d (never 0)" % worst_border)
	else:
		_fail("a full shatter left a pane with 0 border voxels — G-D13 violated")
	print("")
