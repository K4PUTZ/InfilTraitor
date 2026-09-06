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
const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
## CRACK-05 — the cook path's own producer, and the Delta it proposes into.
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const WorldDeltaClass = preload("res://godot/scripts/systems/prediction/world_delta.gd")
const BombDefClass = preload("res://godot/scripts/systems/destruction/bomb_def.gd")

## G4-2 — `plan_pane_shatter()` returns {"destroyed", "remnants"} now. Every test
## in this file was written about the destroyed half and still is; the remnant
## half has its own assertions in [12] rather than being retrofitted onto tests
## that were asking a different question.
func _destroyed(result: Dictionary) -> Array:
	return result.get("destroyed", [])


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
	test_blast_glass_punch_reliable_inside_zero_outside()
	test_banded_pane_never_destroys_its_own_frame_bands()
	test_unanchored_pane_keeps_nothing()
	test_layer_falloff_weakens_each_successive_pane()
	test_local_hole_does_not_wall_off_the_flood()
	test_armored_takes_the_whole_pane_and_leaves_fewer_remnants()
	test_indestructible_never_breaks_and_stops_the_round()
	test_glass_never_dents()
	test_per_placement_class_overrides_the_material()
	test_only_rifle_class_pierces_armored_glass()
	test_cook_proposes_the_opening_and_only_commit_claims_it()
	test_a_pane_the_blast_does_not_take_crazes()
	test_the_survivors_leave_the_function()
	test_a_remnant_is_orphaned_when_its_frame_is_destroyed()

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
func _pane(gu_x_lo: int, gu_x_hi: int, storeys: int, material: String = "glass") -> Array:
	var slices: Array = []
	var base: int = GeometryCoords.storey_level_base(0)
	for gx in range(gu_x_lo, gu_x_hi + 1):
		var s := Slice.new("PANE_S_%d" % gx, Vector2i(gx, 3), Face.SW, "PANE_E_%d" % gx, storeys, material)
		s.pane_id = "PANE_TEST"
		for lvl_off in range(storeys * 8):
			for i in range(8):
				var v := Voxel.new(Vector2i(gx * 8 + i, 3 * 8 + 7), base + lvl_off, s)
				s.voxels.append(v)
		slices.append(s)
	return slices


## A CONCRETE wall slice on the same face and the same run line as `_pane()` —
## the frame a pane is set into. `collect_anchor_positions()` finds it the way it
## finds a real one: same face, same plane coordinate, non-glass material.
func _wall(gu_x: int, storeys: int) -> Slice:
	var base: int = GeometryCoords.storey_level_base(0)
	var w := Slice.new("WALL_S_%d" % gu_x, Vector2i(gu_x, 3), Face.SW, "WALL_E_%d" % gu_x, storeys, "concrete")
	for lvl_off in range(storeys * 8):
		for i in range(8):
			w.voxels.append(Voxel.new(Vector2i(gu_x * 8 + i, 3 * 8 + 7), base + lvl_off, w))
	return w


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


## G-D13b, BOTH SIDES, on the same 1 GU x 1 storey pane and the same roll: the
## ONLY difference between the two halves is whether a concrete wall stands at
## the next GU. That is the whole rule, isolated — anything else that changed the
## outcome would show up here as both halves moving together.
func test_small_pane_is_binary_with_remnants() -> void:
	print("[7] G-D13b — a small pane keeps remnants IFF something is next to it\n")
	var base: int = GeometryCoords.storey_level_base(0)
	var hit := Vector2i(4 * 8 + 4, 0)

	## Free-standing: nothing to hang from, so nothing hangs.
	var lone := _pane(4, 4, 1)
	var lone_plan := _destroyed(GlassShatterClass.plan_pane_shatter(lone, Face.SW, hit, base + 3, 3.75,
		"SMALL:1", GlassShatterClass.collect_anchor_positions(lone, Face.SW, lone)))
	_apply(lone, lone_plan)
	var lone_left := _count_visible(lone)

	## The same pane with a concrete wall at gu 5 — its right-hand column is now
	## anchored, and the conditional floor applies to those voxels.
	var framed := _pane(4, 4, 1)
	var wall := _wall(5, 1)
	var world: Array = framed.duplicate()
	world.append(wall)
	var framed_plan := _destroyed(GlassShatterClass.plan_pane_shatter(framed, Face.SW, hit, base + 3, 3.75,
		"SMALL:1", GlassShatterClass.collect_anchor_positions(framed, Face.SW, world)))
	_apply(framed, framed_plan)
	var framed_left := _count_visible(framed)

	print("      64 voxels: free-standing -> %d destroyed / %d left;  wall at gu 5 -> %d destroyed / %d left" % [
		lone_plan.size(), lone_left, framed_plan.size(), framed_left])
	if lone_left == 0 and framed_left >= GlassShatterClass.SHATTER_REMNANT_MIN_COUNT:
		_pass("free-standing goes to 0; the framed one keeps %d shard(s) against the wall" % framed_left)
	else:
		_fail("free-standing left %d (want 0), framed left %d (want >= %d)" % [
			lone_left, framed_left, GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])
	print("")


func test_big_pane_partial_then_full() -> void:
	print("[8] a big pane (6 GU x 3 storeys) breaks PARTIALLY on a weak win, fully on a sniper\n")
	var total := 6 * 8 * 3 * 8   ## 1152
	var mid_col := 10 * 8         ## centre of GUs 7..12 in grid-x (56..103)
	var mid_lvl := GeometryCoords.storey_level_base(0) + 12

	var weak := _pane(7, 12, 3)
	var weak_plan := _destroyed(GlassShatterClass.plan_pane_shatter(weak, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 2.63, "BIG:weak"))
	var full := _pane(7, 12, 3)
	var full_plan := _destroyed(GlassShatterClass.plan_pane_shatter(full, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 5.25, "BIG:full"))
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


## G-D13b keeps G-D13's floor, CONDITIONALLY: while a pane has an anchor, no roll
## may strip it bare. Only the "always, even with nothing to hang from" half was
## dropped — and [7] and [12] pin that half's replacement.
func test_remnant_floor_never_leaves_zero_border() -> void:
	print("[9] G-D13b: while a pane IS anchored, no won roll ever strips it bare\n")
	var worst: int = 1 << 30
	for trial in range(60):
		var storeys: int = 1 + (trial % 3)
		var gu_hi: int = 2 + (trial % 4)
		var slices := _pane(2, gu_hi, storeys)
		var world: Array = slices.duplicate()
		world.append(_wall(gu_hi + 1, storeys))
		var anchors := GlassShatterClass.collect_anchor_positions(slices, Face.SW, world)
		var plan := _destroyed(GlassShatterClass.plan_pane_shatter(slices, Face.SW,
			Vector2i(2 * 8 + 4, 0), GeometryCoords.storey_level_base(0) + storeys * 4, 6.0,
			"REMNANT:%d" % trial, anchors))
		_apply(slices, plan)
		worst = mini(worst, _count_visible(slices))
	if worst >= GlassShatterClass.SHATTER_REMNANT_MIN_COUNT:
		_pass("across 60 full-shatter rolls on ANCHORED panes the fewest survivors was %d (floor is %d)"
			% [worst, GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])
	else:
		_fail("an anchored pane was stripped to %d survivors — the conditional floor did not hold" % worst)
	print("")


func test_blast_glass_punch_reliable_inside_zero_outside() -> void:
	print("[10] G3-C: a grenade breaks a pane inside its damage area, not one at the fringe\n")
	## frag_grenade's real falloff.
	var frag: Array = [1.0, 0.6, 0.25, 0.0]
	var p0: float = GlassShatterClass.p_shatter(GlassShatterClass.blast_glass_punch(frag, 0))
	var p1: float = GlassShatterClass.p_shatter(GlassShatterClass.blast_glass_punch(frag, 1))
	var p2: float = GlassShatterClass.p_shatter(GlassShatterClass.blast_glass_punch(frag, 2))
	var p3: float = GlassShatterClass.blast_glass_punch(frag, 3)
	var p_oob: float = GlassShatterClass.blast_glass_punch(frag, 9)
	print("      frag rings: p_shatter(0)=%.0f%%  (1)=%.0f%%  (2)=%.0f%%  punch(3)=%.2f  punch(oob)=%.2f" % [
		p0 * 100.0, p1 * 100.0, p2 * 100.0, p3, p_oob])
	## Inside (ring 0-1): reliable. Fringe (ring 2): unlikely. Edge/OOB: impossible.
	if p0 >= 0.9 and p1 >= 0.6 and p2 <= 0.2 and p3 == 0.0 and p_oob == 0.0:
		_pass("ring 0 ~%.0f%%, ring 1 ~%.0f%%, ring 2 ~%.0f%%, ring 3 and beyond = 0" % [
			p0 * 100.0, p1 * 100.0, p2 * 100.0])
	else:
		_fail("blast falloff wrong: p0=%.2f p1=%.2f p2=%.2f punch3=%.2f punchOOB=%.2f" % [p0, p1, p2, p3, p_oob])
	print("")


## A G-D9 BANDED pane: the same slices, with brick bands at the bottom two and
## top two RELATIVE levels — exactly maps/GLASS.map.json's window at gu 19..21
## (`"bands": [{levels [0,1] brick}, {levels [22,23] brick}]`). The bands live in
## the SAME Slice as the glass, reached through `Slice.material_at(rel_level)`.
func _banded_pane(gu_x_lo: int, gu_x_hi: int, storeys: int) -> Array:
	var slices: Array = _pane(gu_x_lo, gu_x_hi, storeys)
	var top: int = storeys * 8 - 1
	for s in slices:
		s.material_bands = {0: "brick", 1: "brick", top - 1: "brick", top: "brick"}
	return slices


## Every non-glass voxel of a banded pane that is still standing.
func _surviving_band_voxels(slices: Array) -> int:
	var base: int = GeometryCoords.storey_level_base(0)
	var n: int = 0
	for s in slices:
		for v in s.voxels:
			if GlassMaterials.is_glass(s.material_at(v.level - base)):
				continue
			if v.damage_state != Voxel.DamageState.DESTROYED:
				n += 1
	return n


func _band_voxel_total(slices: Array) -> int:
	var base: int = GeometryCoords.storey_level_base(0)
	var n: int = 0
	for s in slices:
		for v in s.voxels:
			if not GlassMaterials.is_glass(s.material_at(v.level - base)):
				n += 1
	return n


## G-D13b — THE FRAME IS NOT GLASS, AND THE CASCADE MUST NOT EAT IT.
##
## `plan_pane_shatter()` builds its lattice from every voxel of every slice
## sharing the `pane_id`, and a G-D9 banded window keeps its brick sill and head
## in those same slices. Nothing in the flood consulted `material_at()`, so a won
## roll floods straight through the brick and returns it for DESTROY — the pane
## takes its own frame with it.
func test_banded_pane_never_destroys_its_own_frame_bands() -> void:
	print("[11] G-D13b — a won roll never destroys the pane's own non-glass bands\n")

	var base: int = GeometryCoords.storey_level_base(0)
	var worst_survivors: int = 1 << 30
	var total_bands: int = 0
	for trial in range(30):
		var slices: Array = _banded_pane(19, 21, 3)
		total_bands = _band_voxel_total(slices)
		## Aim at the middle of the glass, with a radius big enough to reach both
		## bands — a sniper takes the whole pane.
		var hit_col: int = 20 * 8 + 4
		var plan: Array = _destroyed(GlassShatterClass.plan_pane_shatter(
			slices, Face.SW, Vector2i(hit_col, 3 * 8 + 7), base + 12, 5.25,
			"BANDED:%d" % trial))
		_apply(slices, plan)
		worst_survivors = mini(worst_survivors, _surviving_band_voxels(slices))

	if worst_survivors == total_bands:
		_pass("all %d brick band voxels stand in every one of 30 trials" % total_bands)
	else:
		_fail("the cascade destroyed the pane's own brick frame: worst trial left %d of %d band voxels"
			% [worst_survivors, total_bands])
	print("")


## G-D13b — REMNANTS ARE ANCHORED, NOT DECORATIVE.
##
## Director, 2026-09-01: *"como essa vidraça não tem nada em volta, todos os
## cacos precisam cair. Então na verdade a regra é: alguns cacos devem sempre
## ficar sobrando, QUANDO estiverem conectados com qualquer outro material (half
## slices inclusive)."* A pane with no non-glass neighbour anywhere — maps/
## GLASS.map.json's big pane is exactly that — must be able to go to ZERO.
## G-D13's old unconditional floor of 4 survivors made that impossible.
func test_unanchored_pane_keeps_nothing() -> void:
	print("[12] G-D13b — an unanchored pane can shatter to nothing\n")

	var base: int = GeometryCoords.storey_level_base(0)
	var left_standing: int = 0
	var trials: int = 30
	for trial in range(trials):
		var slices: Array = _pane(10, 15, 3)
		## The lattice runs cols 80..127; its CENTRE is 103, not 12*8+4. Aiming off
		## centre left one whole column outside a radius that otherwise covers the
		## pane, which reads as "remnants survived" and is nothing of the kind —
		## the first version of this test made exactly that mistake.
		var hit_col: int = 103
		var plan: Array = _destroyed(GlassShatterClass.plan_pane_shatter(
			slices, Face.SW, Vector2i(hit_col, 3 * 8 + 7), base + 12, 5.78,
			"UNANCHORED:%d" % trial,
			GlassShatterClass.collect_anchor_positions(slices, Face.SW, slices)))
		_apply(slices, plan)
		left_standing += _count_visible(slices)

	if left_standing == 0:
		_pass("%d trials, every voxel of the free-standing pane fell (0 left standing)" % trials)
	else:
		_fail("a pane with nothing around it still kept %d voxel(s) across %d trials — G-D13's unconditional floor"
			% [left_standing, trials])
	print("")


## G-D17 — THE LAYER MODIFIER.
##
## Director, 2026-09-01: *"Adicionamos um modificador de destruição, de forma que
## cada camada de vidro a mais diminui a potência do projétil."*
##
## Two halves, and the first is the one that protects everything already ratified:
## depth 0 must be BIT-IDENTICAL to no attenuation at all, or every number in §5.1's
## arsenal table silently moves. The second is the mechanic itself — strictly
## decreasing, and reaching the flat bottom on its own rather than by a rule that
## says "stop after N panes".
func test_layer_falloff_weakens_each_successive_pane() -> void:
	print("[13] G-D17 — each glass layer weakens the round, and depth 0 changes nothing\n")

	var sniper: float = 5.25   ## §5.1's own sniper glass_punch
	if is_equal_approx(GlassShatterClass.punch_after_layers(sniper, 0), sniper):
		_pass("depth 0 is the unattenuated punch — the ratified arsenal table is untouched")
	else:
		_fail("depth 0 changed the punch: %.4f vs %.4f"
			% [GlassShatterClass.punch_after_layers(sniper, 0), sniper])

	var row: Array = []
	var probs: Array = []
	var strictly_down: bool = true
	var prev: float = INF
	for depth in range(5):
		var p: float = GlassShatterClass.punch_after_layers(sniper, depth)
		var pr: float = GlassShatterClass.p_shatter(p)
		row.append("%.2f" % p)
		probs.append("%.0f%%" % (pr * 100.0))
		if p >= prev:
			strictly_down = false
		prev = p
	if strictly_down:
		_pass("punch decays strictly: %s  ->  P(shatter) %s" % [", ".join(row), ", ".join(probs)])
	else:
		_fail("punch is not strictly decreasing across layers: %s" % [", ".join(row)])

	## The point of a geometric decay: a deep stack stops the round by ARITHMETIC,
	## not by a special case. A sniper must fall under SHATTER_C's flat bottom
	## somewhere in a handful of layers, without any rule naming a limit.
	var died_at: int = -1
	for depth in range(12):
		if GlassShatterClass.p_shatter(GlassShatterClass.punch_after_layers(sniper, depth)) <= 0.0:
			died_at = depth
			break
	if died_at > 0:
		_pass("a sniper stops being able to shatter at layer %d, by the curve alone" % died_at)
	else:
		_fail("a sniper never reaches zero shatter chance within 12 layers (died_at=%d)" % died_at)

	## And it must never go negative — the reason the decay is geometric and not
	## a subtraction with a clamp hiding a sign error.
	var deep: float = GlassShatterClass.punch_after_layers(sniper, 40)
	if deep > 0.0:
		_pass("40 layers deep the punch is still positive (%.12f) — no clamp is hiding a sign" % deep)
	else:
		_fail("punch went non-positive at depth 40: %f" % deep)
	print("")


## ⛔ REGRESSION — THE SHOT'S OWN HOLE MUST NOT WALL OFF ITS OWN FLOOD.
##
## Found on the REAL MAP on 2026-09-01, with Stage B green in this very suite for
## a day: a won sniper roll on maps/GLASS.map.json's big pane flooded ZERO
## voxels. `plan_pane_shatter`'s BFS queues a neighbour only `if lattice.has(nb)`,
## and `lattice` holds SURVIVING glass, so the walk cannot step across a hole —
## and the origin IS this shot's own fresh hole. A rifle-class round takes 2–4
## voxels plus the cascade (G-D14), so every cell around the origin is gone too
## and the queue empties at step one:
##
##     lattice=1143  own_frame=0  origin=(114, 84)  origin_in_lattice=false
##     neighbours_in_lattice=0/8  flood=0  radius=23
##
## The failure scales the WRONG WAY — a wider hole strangles the flood harder —
## so it bites worst on the round most likely to win the roll.
##
## ⚠️ WHY EVERY EXISTING TEST HERE PASSED THROUGH IT. Tests [7], [8] and [9] all
## aim at an INTACT lattice cell, so their origin is in `lattice` and the walk
## starts alive. The real path destroys the local hole BEFORE calling
## `plan_pane_shatter` — `agent_shot_controller` applies `plan_entries` and only
## then calls `_maybe_shatter_pane`. A synthetic fixture that skips that step
## cannot see this, which is CLAUDE.md's floor-dent lesson in a new costume: the
## fixture was built with the data that works.
##
## So this test does what the shot does: punch the hole FIRST, then roll.
func test_local_hole_does_not_wall_off_the_flood() -> void:
	print("[14] the shot's own local hole must not wall off its own flood\n")
	var mid_col: int = 10 * 8
	var mid_lvl: int = GeometryCoords.storey_level_base(0) + 12
	var total: int = 6 * 8 * 3 * 8

	## CONTROL — the same win with no pre-existing hole, so the assertion below
	## compares against a measured number rather than a guessed one.
	var intact := _pane(7, 12, 3)
	var intact_plan := _destroyed(GlassShatterClass.plan_pane_shatter(intact, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 5.25, "HOLE:control"))

	## THE REAL SHAPE — the round's local hole, punched before the roll. Chebyshev
	## radius 1 is all it takes (the real map measured 0 of 8 neighbours surviving)
	## and it is the SMALLEST hole a rifle-class round makes.
	var holed := _pane(7, 12, 3)
	var punched: int = 0
	for s in holed:
		for v in s.voxels:
			if absi(v.grid_pos.x - mid_col) <= 1 and absi(v.level - mid_lvl) <= 1:
				v.set_damage(Voxel.DamageState.DESTROYED, false, 0, 0, 0)
				punched += 1
	var holed_plan := _destroyed(GlassShatterClass.plan_pane_shatter(holed, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 5.25, "HOLE:control"))

	print("      %d voxels, sniper win: intact origin -> %d flooded;  after a %d-voxel local hole -> %d flooded"
		% [total, intact_plan.size(), punched, holed_plan.size()])
	## The holed pane has `punched` fewer candidates by construction, so the bar is
	## "essentially the same flood", not "identical".
	var floor_size: int = int(float(intact_plan.size()) * 0.9)
	if holed_plan.size() >= floor_size and holed_plan.size() > 0:
		_pass("a %d-voxel hole around the origin costs the flood %d voxel(s), not all of them (%d >= %d)"
			% [punched, intact_plan.size() - holed_plan.size(), holed_plan.size(), floor_size])
	else:
		_fail("the local hole strangled the flood: %d flooded vs %d on an intact origin — the BFS cannot step across a hole"
			% [holed_plan.size(), intact_plan.size()])
	print("")


## G-D15 / V-C — ARMORED GLASS HAS NO REGION.
##
## G-D12's partial break is the model for ordinary glass: a weak win takes a
## patch and a big pane keeps standing where the round did not reach. Armoured
## glass is the exception the Director stated directly — once breached it
## *"usually shatters entirely at once, leaving many individual shards"* — so the
## test that matters is the one on a WEAK win: the same revolver-grade punch that
## takes a patch out of plain glass must take an armoured pane whole.
##
## The remnant half is measured against the plain pane rather than a fixed
## number, because "fewer" is a comparison and the absolute count moves with the
## luck roll.
func test_armored_takes_the_whole_pane_and_leaves_fewer_remnants() -> void:
	print("[15] G-D15: armoured glass breaks WHOLE on a weak win, and leaves fewer remnants\n")
	var mid_col: int = 10 * 8
	var mid_lvl: int = GeometryCoords.storey_level_base(0) + 12
	var total: int = 6 * 8 * 3 * 8
	## A weak win — the punch at which plain glass takes a PATCH (test [8]).
	var weak: float = 2.63

	var plain := _pane(7, 12, 3)
	var plain_world: Array = plain.duplicate()
	plain_world.append(_wall(13, 3))
	var plain_anchors := GlassShatterClass.collect_anchor_positions(plain, Face.SW, plain_world)
	var plain_plan := _destroyed(GlassShatterClass.plan_pane_shatter(plain, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, weak, "ARM:cmp", plain_anchors))

	var armored := _pane(7, 12, 3, "glass_armored")
	var armored_world: Array = armored.duplicate()
	armored_world.append(_wall(13, 3))
	var armored_anchors := GlassShatterClass.collect_anchor_positions(armored, Face.SW, armored_world)
	var armored_plan := _destroyed(GlassShatterClass.plan_pane_shatter(armored, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, weak, "ARM:cmp", armored_anchors))

	print("      %d voxels at glass_punch %.2f: plain -> %d destroyed (%.0f%%);  armoured -> %d (%.0f%%)"
		% [total, weak, plain_plan.size(), 100.0 * plain_plan.size() / total,
			armored_plan.size(), 100.0 * armored_plan.size() / total])
	if plain_plan.size() < total / 2 and armored_plan.size() > int(total * 0.9):
		_pass("the same weak win takes a PATCH of plain glass (%d) and nearly all of the armoured pane (%d of %d)"
			% [plain_plan.size(), armored_plan.size(), total])
	else:
		_fail("plain=%d (expected a patch) armoured=%d of %d (expected >90%%)"
			% [plain_plan.size(), armored_plan.size(), total])

	## Remnants: same salt, same anchors, so only the class differs. Compared on
	## a FULL win for both, or the plain pane's survivors would include everything
	## its smaller region never reached.
	var plain_full := _pane(7, 12, 3)
	var plain_full_world: Array = plain_full.duplicate()
	plain_full_world.append(_wall(13, 3))
	var pfa := GlassShatterClass.collect_anchor_positions(plain_full, Face.SW, plain_full_world)
	_apply(plain_full, _destroyed(GlassShatterClass.plan_pane_shatter(plain_full, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 9.0, "ARM:rem", pfa)))
	var armored_full := _pane(7, 12, 3, "glass_armored")
	var armored_full_world: Array = armored_full.duplicate()
	armored_full_world.append(_wall(13, 3))
	var afa := GlassShatterClass.collect_anchor_positions(armored_full, Face.SW, armored_full_world)
	_apply(armored_full, _destroyed(GlassShatterClass.plan_pane_shatter(armored_full, Face.SW,
		Vector2i(mid_col, 0), mid_lvl, 9.0, "ARM:rem", afa)))
	var plain_left: int = _count_visible(plain_full)
	var armored_left: int = _count_visible(armored_full)
	print("      full win, same salt: plain leaves %d remnant(s), armoured leaves %d"
		% [plain_left, armored_left])
	if armored_left < plain_left and armored_left >= GlassShatterClass.SHATTER_REMNANT_MIN_COUNT:
		_pass("armoured leaves fewer remnants (%d < %d) and still honours G-D13b's floor of %d"
			% [armored_left, plain_left, GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])
	else:
		_fail("armoured=%d plain=%d floor=%d" % [armored_left, plain_left,
			GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])
	print("")


## G-D16 / V-C — AN INDESTRUCTIBLE SCREEN NEVER BREAKS, AND THE ROUND STOPS.
##
## Director, 2026-08-31: *"trinca mas o tiro para"*. Two independent claims, and
## the second is the one that makes it read as armoured rather than merely tough
## — it is the ONE glass G-D5's pass-through does not apply to.
##
## Both are checked against a plain-glass CONTROL at the same punch and on the
## same ray, so a pass means "the class changed the outcome" rather than "the
## number happened to land there".
func test_indestructible_never_breaks_and_stops_the_round() -> void:
	print("[16] G-D16: a control interface caps at CRACKED, and the round stops at it\n")

	## 1. THE TIER CEILING. A punch far past every breach threshold.
	var punch: float = 9.0
	var screen_state: int = ShotPunchTableClass.damage_state_for(
		punch, ShotPunchTableClass.destroy_min("glass_screen_green"), "glass_screen_green")
	var glass_state: int = ShotPunchTableClass.damage_state_for(
		punch, ShotPunchTableClass.destroy_min("glass"), "glass")
	if screen_state == Voxel.DamageState.CRACKED and glass_state == Voxel.DamageState.DESTROYED:
		_pass("at glass_punch %.1f a screen is CRACKED where plain glass is DESTROYED" % punch)
	else:
		_fail("screen=%d glass=%d (expected CRACKED=%d and DESTROYED=%d)"
			% [screen_state, glass_state, Voxel.DamageState.CRACKED, Voxel.DamageState.DESTROYED])

	## 2. THE ROUND STOPS. One ray, one glass edge four cells out, run twice: as a
	## PASSABLE pane and as a STOPPING one. `blocked_edges` is empty on purpose —
	## a half-thickness panel never populates it, which is exactly why absence
	## cannot express a stop.
	var source := Vector2i(2, 10)
	var forward := Vector2i(1, 0)
	var pane_at := Vector2i(6, 10)
	var key: String = WallEdgeData.edge_key(pane_at, pane_at + forward)
	var passable := BlastCalculatorClass.select_line_impact(
		source, forward, 12, {}, {}, 0.0, {key: "PANE_TEST"}, {})
	var stopping := BlastCalculatorClass.select_line_impact(
		source, forward, 12, {}, {}, 0.0, {}, {key: "PANE_TEST"})

	var passed_through: bool = passable.has("glass_passed") and not passable.has("gu")
	if passed_through:
		_pass("a BREAKABLE pane is crossed and recorded — the round runs out of map beyond it (G-D5)")
	else:
		_fail("the passable case did not read as a crossing: %s" % [passable])

	if stopping.get("gu", Vector2i(-1, -1)) == pane_at:
		_pass("an INDESTRUCTIBLE pane is TERMINAL — the round stops at %s instead of crossing"
			% [pane_at])
	else:
		_fail("the round did not stop at the screen: %s" % [stopping])

	## The failure this pairing exists to catch: dropping a screen from
	## `glass_edges` WITHOUT a stop set is not a stop at all — a half-thickness
	## panel is in neither dictionary, so the round sails through recording
	## nothing.
	var neither := BlastCalculatorClass.select_line_impact(source, forward, 12, {}, {}, 0.0, {}, {})
	if not neither.has("gu") and not neither.has("glass_passed"):
		_pass("absence is NOT a stop — with the edge in neither set the round records nothing, "
			+ "which is why glass_stop_edge_keys() is a second set and not a filter")
	else:
		_fail("the empty-dictionary control was not a clean miss: %s" % [neither])
	print("")


## G-D3 / V-D — GLASS FRACTURES, IT DOES NOT DEFORM, AND NOW IT CANNOT.
##
## D22 ruled glass DESTROYED-only; G-D3 amended it so CRACKED returns and DENTED
## stays impossible. Until V-D that was true only by COINCIDENCE —
## `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN` were both 0.30, so the DENTED band
## between them was exactly empty. §6.1 flagged that equality as *"a coincidence
## of two equal numbers"* that must be pinned rather than trusted, and V-D is the
## edit that would have broken it: raising `glass_armored`'s breach to 1.50 opens
## a 0.30–1.50 band that every common round lands in.
##
## Swept across the WHOLE family and a punch range that spans every threshold,
## with a concrete CONTROL at the same punch to prove the sweep can see a DENT at
## all — a test that only ever looks at glass would pass just as happily if
## `damage_state_for` had stopped returning DENTED for everything.
func test_glass_never_dents() -> void:
	print("[17] G-D3: no glass material EVER reaches DENTED, at any punch\n")
	var offenders: Array = []
	var saw_cracked: bool = false
	var saw_destroyed: bool = false
	for material in GlassMaterials.FAMILY:
		var breach: float = ShotPunchTableClass.destroy_min(material)
		for step in range(0, 61):
			var punch: float = float(step) * 0.1
			var st: int = ShotPunchTableClass.damage_state_for(punch, breach, material)
			if st == Voxel.DamageState.DENTED:
				offenders.append("%s at punch %.1f" % [material, punch])
			elif st == Voxel.DamageState.CRACKED:
				saw_cracked = true
			elif st == Voxel.DamageState.DESTROYED:
				saw_destroyed = true
	## The control: the same sweep on concrete MUST produce a DENT, or the sweep
	## is not looking at anything.
	var control_dented: bool = false
	for step in range(0, 61):
		var punch: float = float(step) * 0.1
		if ShotPunchTableClass.damage_state_for(punch,
				ShotPunchTableClass.destroy_min("concrete"), "concrete") == Voxel.DamageState.DENTED:
			control_dented = true
			break
	if offenders.is_empty() and saw_cracked and saw_destroyed and control_dented:
		_pass("across %d glass materials x 61 punches: only CRACKED and DESTROYED, "
			% GlassMaterials.FAMILY.size()
			+ "and the same sweep DOES dent concrete")
	else:
		_fail("dented=%s saw_cracked=%s saw_destroyed=%s control_dented=%s"
			% [offenders, saw_cracked, saw_destroyed, control_dented])
	print("")


## G-D16 / V-D — THE CLASS IS A PROPERTY OF THE PLACEMENT, NOT ONLY OF THE
## MATERIAL. A `glass_screen_*` is a control interface or a TV *per placement*,
## so `panels[].glass_class` overrides the material default all the way down to
## `Slice.glass_class`.
##
## The pairing is what matters: the SAME material must answer differently under
## the two overrides, and answer the material default under CLASS_UNSET.
func test_per_placement_class_overrides_the_material() -> void:
	print("[18] G-D16: panels[].glass_class overrides the material's own class\n")
	var U: int = GlassMaterials.CLASS_UNSET
	var rows: Array = [
		## material, override, stops_a_round, shatters_whole_pane, what it is
		["glass_screen_red", U, true, false, "a screen's own default: a control interface"],
		["glass_screen_red", GlassMaterials.Class.BREAKABLE, false, false, "the same screen authored as a TV"],
		["glass", GlassMaterials.Class.INDESTRUCTIBLE, true, false, "plain glass authored as a control interface"],
		["glass_armored", U, false, true, "armoured glass, unoverridden"],
		["glass_armored", GlassMaterials.Class.BREAKABLE, false, false, "armoured glass authored as ordinary"],
	]
	var bad: Array = []
	for r in rows:
		var stops: bool = GlassMaterials.stops_a_round(r[0], r[1])
		var whole: bool = GlassMaterials.shatters_whole_pane(r[0], r[1])
		if stops != r[2] or whole != r[3]:
			bad.append("%s (%s): stops=%s want %s, whole=%s want %s"
				% [r[4], r[0], stops, r[2], whole, r[3]])
	if bad.is_empty():
		_pass("all %d placement/material combinations answer as authored" % rows.size())
	else:
		_fail("%s" % [bad])

	## And the tier ceiling follows the override, not the material.
	var as_tv: int = ShotPunchTableClass.damage_state_for(9.0,
		ShotPunchTableClass.destroy_min("glass_screen_red"), "glass_screen_red",
		GlassMaterials.Class.BREAKABLE)
	var as_panel: int = ShotPunchTableClass.damage_state_for(9.0,
		ShotPunchTableClass.destroy_min("glass_screen_red"), "glass_screen_red", U)
	if as_tv == Voxel.DamageState.DESTROYED and as_panel == Voxel.DamageState.CRACKED:
		_pass("the same screen is DESTROYED as a TV and CRACKED as a control interface")
	else:
		_fail("as_tv=%d as_panel=%d" % [as_tv, as_panel])

	## The authoring vocabulary, and its loud failure.
	if GlassMaterials.class_from_name("breakable") == GlassMaterials.Class.BREAKABLE \
			and GlassMaterials.class_from_name("") == U:
		_pass("`breakable` parses, and an absent tag is CLASS_UNSET (the material default)")
	else:
		_fail("class_from_name is not round-tripping the authoring names")
	print("")


## G-D15 / V-D — WHO CAN PIERCE ARMOURED GLASS, read off the SHIPPED ARSENAL.
##
## The pierce-and-prime rule has no threshold of its own: it fires when a round
## DESTROYS a voxel of an armoured pane and still loses the roll. That makes
## `DESTROY_MIN["glass_armored"]` the whole gate, so this pins it against the
## real weapon JSONs the way [1] pins the shatter curve — a later balance edit to
## a weapon's `punch`, or to the armoured resistance, fails here instead of
## quietly making a pistol able to prime a pane.
func test_only_rifle_class_pierces_armored_glass() -> void:
	print("[19] G-D15: only rifle-class rounds pierce armoured glass at all\n")
	var defs := _load_weapons()
	if defs.is_empty():
		_fail("no weapons loaded")
		return
	var breach: float = ShotPunchTableClass.destroy_min("glass_armored")
	var pierce: Array = []
	var craze: Array = []
	for wid in defs:
		var def: WeaponDef = defs[wid]
		var gp: float = ShotPunchTableClass.PUNCH_GAIN * def.punch \
			/ ShotPunchTableClass.resistance("glass_armored")
		var st: int = ShotPunchTableClass.damage_state_for(gp, breach, "glass_armored")
		if st == Voxel.DamageState.DESTROYED:
			pierce.append("%s %.2f" % [wid, gp])
		else:
			craze.append("%s %.2f" % [wid, gp])
	pierce.sort()
	craze.sort()
	print("      breach %.2f — pierces: %s" % [breach, ", ".join(pierce)])
	print("                  crazes only: %s" % ", ".join(craze))
	var want_pierce: Array = ["assault_rifle", "sniper_rifle"]
	var got: Array = []
	for e in pierce:
		got.append(String(e).split(" ")[0])
	got.sort()
	if got == want_pierce:
		_pass("exactly the rifle-class rounds pierce armoured glass (%s); everything "
			% ", ".join(want_pierce)
			+ "else only crazes it, so only they can PRIME a pane")
	else:
		_fail("pierced by %s, expected exactly %s — the armoured breach (%.2f) no "
			% [got, want_pierce, breach]
			+ "longer splits the arsenal where G-D15 says it does")
	print("")


## ── CRACK-05 (`GLASS_MASTER_PLAN` §14.5) ─────────────────────────────────────
##
## A stand-in for the room, holding exactly the one call `WorldDelta.commit()`
## makes on this path. It records rather than acts, because what is being tested
## is WHEN the claim happens, not what claiming does — and the real
## `claim_glass_opening_for_hit()` needs a VoxelRenderer, a PerspectiveMapper and
## a live map to do anything at all.
class RoomStub:
	extends RefCounted
	var claims: Array = []
	func claim_glass_opening_for_hit(grid_pos: Vector2i, level: int, wide: bool,
			record: bool = true) -> String:
		claims.append({"cell": grid_pos, "level": level, "wide": wide, "record": record})
		return "STUB"
	func absorb_scorch(_writes: Dictionary) -> void:
		pass
	## G-D45 — `commit()` now calls this UNCONDITIONALLY (a frame the blast broke
	## may hold an old remnant even when this delta has no glass of its own), so
	## the stub has to answer it. A no-op: the test's subject is the opening claim.
	func reap_orphaned_remnants() -> Dictionary:
		return {"reaped": 0, "landed": 0}


## CRACK-05 — THE COOK PROPOSES A HOLE'S SHAPE, AND ONLY `commit()` CLAIMS IT.
##
## Two halves, and the second is the one that would fail silently. §14.5 left the
## cook unable to name its hole, so every blast fell through to
## `GLASS_OPENING_DEFAULT` — a grenade repeating one shape. The fix has to live on
## the Delta rather than in the builder, because `build_plan()` runs on every
## cursor move: a claim made there is a WRITE for a hole that was never opened,
## and the next real blast anywhere on the map would wear it.
func test_cook_proposes_the_opening_and_only_commit_claims_it() -> void:
	print("[20] CRACK-05 — the cook PROPOSES a blast hole's opening; commit() claims it\n")
	var registry := EdgeRegistry.new()
	var pane: Array = _pane(2, 7, 3)
	for s in pane:
		registry.register_slice(s)
	var bomb := BombDefClass.from_json({
		"id": "frag_grenade",
		"ring_multipliers": [1.0, 0.6, 0.25, 0.0],
		"destroy_ring_weights": [0.85, 0.28, 0.06, 0.0],
		"dent_ring_weights": [1.0, 0.8, 0.25, 0.0],
		"crack_ring_weights": [0.0, 1.0, 0.6, 0.0],
	})
	var affected: Dictionary = {}
	for s in pane:
		affected[s.id] = 0
	## The epicenter, in the pane's own column space: the flood origin must be the
	## STANDING pane voxel nearest it, and picking one at the far end is what makes
	## "nearest" a real assertion instead of a coincidence of iteration order.
	var epicenter := Vector2i(pane[0].voxels[0].grid_pos.x, pane[0].voxels[0].grid_pos.y)
	var delta := WorldDeltaClass.new()
	var state: Dictionary = {
		"edge_registry": registry,
		"slab_registry": SlabRegistry.new(),
		"affected": {"slices": affected},
		"bomb_def": bomb,
		"delta": delta,
		"epicenter": epicenter,
		"source_gu": Vector2i(2, 4),
	}
	DetonationPlanBuilderClass._shatter_glass_panes(state)

	if delta.glass_openings.size() != 1:
		_fail("the cook proposed %d opening(s) for one shattered pane — expected exactly 1"
			% delta.glass_openings.size())
		print("")
		return
	var proposal: Dictionary = delta.glass_openings[0]
	## The nearest STANDING pane voxel to the epicenter, derived here the way the
	## builder derives it — from the pane, not from the builder's own answer.
	var want: Voxel = null
	var best: float = INF
	for s in pane:
		for v in s.voxels:
			if v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			var d: float = Vector2(v.grid_pos - epicenter).length()
			if d < best:
				best = d
				want = v
	if proposal["cell"] == want.grid_pos and int(proposal["level"]) == want.level \
			and bool(proposal["wide"]):
		_pass("the proposal names the flood's own origin %s level %d, size class LARGE"
			% [proposal["cell"], int(proposal["level"])])
	else:
		_fail("the proposal is %s level %d wide=%s — the flood started at %s level %d"
			% [proposal["cell"], int(proposal["level"]), proposal["wide"],
			want.grid_pos, want.level])

	## ⚠️ THE HALF THAT MATTERS. `_shatter_glass_panes()` runs inside `build_plan()`,
	## which is pure and speculative; a claim is a write. Nothing may have been
	## claimed yet, and the commit must make exactly the one call.
	var room := RoomStub.new()
	if not room.claims.is_empty():
		_fail("the builder claimed before any commit — build_plan() is not pure")
	var before: int = room.claims.size()
	delta.commit(room)
	if before == 0 and room.claims.size() == 1 \
			and room.claims[0]["cell"] == proposal["cell"] \
			and int(room.claims[0]["level"]) == int(proposal["level"]) \
			and bool(room.claims[0]["record"]):
		_pass("0 claims before commit(), exactly 1 after — and it is RECORDED, so the "
			+ "hole keeps its shape through a perspective flip")
	else:
		_fail("claims before=%d after=%d (%s) — the proposal did not reach the room"
			% [before, room.claims.size(), room.claims])
	print("")


## §6.2 / G-D35 B-1 — THE PANE THE BLAST DOES NOT TAKE.
##
## What this catches: the craze walking the pane's brick bands (the same trap
## [11] pins for the shatter), a won roll crazing as well as shattering, the
## intensity table losing its ring 3 (which is the *"perto de uma explosão mas
## fora da área de dano"* case §6.2 is named after), and the whole trigger going
## inert — which would leave G-D35's art with nothing to draw it.
func test_a_pane_the_blast_does_not_take_crazes() -> void:
	print("[21] §6.2 / B-1 — a pane the blast does NOT take goes CRACKED, whole\n")

	## ── The intensity table. ────────────────────────────────────────────────
	var ramp: Array = []
	for r in range(5):
		ramp.append("%d:%.2f" % [r, GlassShatterClass.blast_craze_intensity(r)])
	print("      ring intensity — %s" % ", ".join(ramp))
	var monotonic := true
	for r in range(1, GlassShatterClass.CRAZE_RING_INTENSITY.size()):
		if GlassShatterClass.blast_craze_intensity(r) > GlassShatterClass.blast_craze_intensity(r - 1):
			monotonic = false
	## ⚠️ RING 3 MUST CARRY A CRAZE. frag_grenade's `ring_multipliers` ends in 0.0,
	## so ring 3 is inside `affected` and takes NO damage — which is exactly
	## §6.2's *"perto de uma explosão, mas não dentro da área de dano"*. A table
	## that stopped at ring 2 would silently delete the case the feature is for.
	if monotonic and GlassShatterClass.blast_craze_intensity(3) > 0.0 \
			and GlassShatterClass.blast_craze_intensity(4) == 0.0:
		_pass("intensity falls with the ring, still bites at ring 3 (the blast's own "
			+ "damage stops at ring 2), and is 0 off the end of the table")
	else:
		_fail("the intensity ramp is wrong: %s" % ", ".join(ramp))

	## ── `plan_pane_craze` walks glass and nothing else. ─────────────────────
	var banded: Array = _banded_pane(2, 4, 3)
	var glass_total: int = 0
	var base: int = GeometryCoords.storey_level_base(0)
	for s in banded:
		for v in s.voxels:
			if GlassMaterials.is_glass(s.material_at(v.level - base)):
				glass_total += 1
	## One voxel destroyed and one already cracked — neither may be returned.
	banded[0].voxels[40].set_damage(Voxel.DamageState.DESTROYED, false, 0, 0, 0)
	banded[0].voxels[41].set_damage(Voxel.DamageState.CRACKED, false, 0, 0, 0)
	var craze: Array = GlassShatterClass.plan_pane_craze(banded)
	## ⚠️ THE FRAME SET IS BUILT FROM THE SLICES, NOT ASKED OF THE VOXEL. A Voxel
	## holds its container by INSTANCE ID rather than by reference (the RefCounted
	## cycle fix, 2026-08-17), so `v.container` is not a property — and reaching
	## for one is a SCRIPT ERROR that GDScript cannot catch in-process: the
	## function aborts, the remaining assertions never run, and the suite still
	## prints PASS with exit 0. Caught here by reading the output rather than the
	## exit code, which is the whole reason `run_selftests.py` is the arbiter.
	var frame_voxels: Dictionary = {}
	for s2 in banded:
		for v2 in s2.voxels:
			if not GlassMaterials.is_glass(s2.material_at(v2.level - base)):
				frame_voxels[v2.get_instance_id()] = true
	var frame_hits: int = 0
	for v in craze:
		if frame_voxels.has(v.get_instance_id()):
			frame_hits += 1
	if craze.size() == glass_total - 2 and frame_hits == 0:
		_pass("the whole pane crazes: %d of %d glass voxels (the destroyed one and the "
			% [craze.size(), glass_total]
			+ "already-cracked one skipped), and 0 of its brick bands")
	else:
		_fail("plan_pane_craze returned %d voxel(s) of %d glass (expected %d), %d of them frame"
			% [craze.size(), glass_total, glass_total - 2, frame_hits])

	## ── The cook: a LOST roll crazes, a WON roll does not. ──────────────────
	##
	## Ring 3 is the reliable loser — `blast_glass_punch` is 0 there because
	## `ring_multipliers` ends in 0.0 — so this needs no salt fishing.
	for ring in [3, 0]:
		var registry := EdgeRegistry.new()
		var pane: Array = _pane(2, 7, 3)
		for s in pane:
			registry.register_slice(s)
		var bomb := BombDefClass.from_json({
			"id": "frag_grenade",
			"ring_multipliers": [1.0, 0.6, 0.25, 0.0],
			"destroy_ring_weights": [0.85, 0.28, 0.06, 0.0],
			"dent_ring_weights": [1.0, 0.8, 0.25, 0.0],
			"crack_ring_weights": [0.0, 1.0, 0.6, 0.0],
		})
		var affected: Dictionary = {}
		for s in pane:
			affected[s.id] = ring
		var delta := WorldDeltaClass.new()
		DetonationPlanBuilderClass._shatter_glass_panes({
			"edge_registry": registry, "slab_registry": SlabRegistry.new(),
			"affected": {"slices": affected}, "bomb_def": bomb, "delta": delta,
			"epicenter": pane[0].voxels[0].grid_pos, "source_gu": Vector2i(2, 4),
			"crazed_voxels": [],
		})
		var cracked: int = 0
		var destroyed: int = 0
		for e in delta.damage:
			if int(e["state"]) == Voxel.DamageState.CRACKED:
				cracked += 1
			elif int(e["state"]) == Voxel.DamageState.DESTROYED:
				destroyed += 1
		if ring == 3:
			## ⚠️ `destroyed == 0` IS THE POINT OF THIS LINE, AND IT WENT AWAY ONCE.
			## G-D35 B-4 made a fraction of a crazed pane DESTROYED, so this read
			## B-4's hole rate for one day; the Director abandoned the
			## mechanic on the real pane (*"vamos usar o rachado sem furos"*) and
			## the strong form is correct again. A crazed pane STANDS — G-D2, the
			## intensity axis is granularity, never area — and one destroyed voxel
			## here means something started taking glass off a pane that held.
			if cracked > 0 and destroyed == 0 and delta.glass_openings.is_empty() \
					and delta.glass_crazes.size() == 1 \
					and float(delta.glass_crazes[0]["intensity"]) > 0.0:
				_pass("ring 3 (outside the damage area): %d voxel(s) CRACKED, 0 destroyed, "
					% cracked + "0 openings, 1 craze recorded at intensity %.2f"
					% float(delta.glass_crazes[0]["intensity"]))
			else:
				_fail("ring 3 gave cracked=%d destroyed=%d openings=%d crazes=%d — the "
					% [cracked, destroyed, delta.glass_openings.size(),
					delta.glass_crazes.size()]
					+ "pane should stand WHOLE and craze")
		else:
			## ⚠️ A WON ROLL MUST NOT ALSO CRAZE. The two are alternatives, and a
			## pane that shattered AND recorded a craze would hand G-D35's art a
			## field to draw over voxels that are gone.
			if destroyed > 0 and cracked == 0 and delta.glass_crazes.is_empty():
				_pass("ring 0 (a won roll): %d voxel(s) DESTROYED, 0 cracked, no craze "
					% destroyed + "recorded — the two are alternatives")
			else:
				_fail("ring 0 gave cracked=%d destroyed=%d crazes=%d"
					% [cracked, destroyed, delta.glass_crazes.size()])
	print("")


## ── G4-2 ─────────────────────────────────────────────────────────────────────
##
## ⚠️ RED BEFORE GREEN, AND THE RED WAS STRUCTURAL. Before this task
## `plan_pane_shatter()` returned a bare Array of voxels to destroy and `spared`
## was a local with exactly one use — `if spared.has(k): continue`. There was no
## channel for a remnant at ALL, so the count this test reads was not "low", it
## was unaskable: a remnant was a voxel that happened to be absent from the
## destroy list, indistinguishable from one the blast never reached.
##
## Both directions, on the same pane and the same roll, because a test that only
## checked the anchored case would pass just as well if the function reported
## every survivor everywhere.
func test_the_survivors_leave_the_function() -> void:
	print("[22] G4-2 — the anchored survivors LEAVE the function, with their anchor\n")
	var base: int = GeometryCoords.storey_level_base(0)
	var hit := Vector2i(4 * 8 + 4, 0)

	var lone := _pane(4, 4, 1)
	var lone_res: Dictionary = GlassShatterClass.plan_pane_shatter(lone, Face.SW, hit,
		base + 3, 3.75, "SMALL:1",
		GlassShatterClass.collect_anchor_positions(lone, Face.SW, lone))

	var framed := _pane(4, 4, 1)
	var world: Array = framed.duplicate()
	world.append(_wall(5, 1))
	var framed_res: Dictionary = GlassShatterClass.plan_pane_shatter(framed, Face.SW, hit,
		base + 3, 3.75, "SMALL:1",
		GlassShatterClass.collect_anchor_positions(framed, Face.SW, world))

	var lone_r: Array = lone_res["remnants"]
	var framed_r: Array = framed_res["remnants"]
	print("      free-standing: %d destroyed, %d remnant(s);  wall at gu 5: %d destroyed, %d remnant(s)"
		% [lone_res["destroyed"].size(), lone_r.size(),
			framed_res["destroyed"].size(), framed_r.size()])
	if lone_r.is_empty() and framed_r.size() >= GlassShatterClass.SHATTER_REMNANT_MIN_COUNT:
		_pass("nothing to hang from -> 0 reported; a wall next to it -> %d reported" % framed_r.size())
	else:
		_fail("free-standing reported %d (want 0), framed reported %d (want >= %d)"
			% [lone_r.size(), framed_r.size(), GlassShatterClass.SHATTER_REMNANT_MIN_COUNT])

	## ⚠️ THE COUNT ALONE WOULD PASS FOR A REMNANT WITH NO ANCHOR, which is the one
	## thing a remnant cannot be — G-D39 places the fragment AGAINST the material
	## it hangs from, and mask 0 has no placement at all.
	var maskless: int = 0
	var bits: Dictionary = {}
	for r in framed_r:
		var m: int = int(r["anchor_mask"])
		if m == 0:
			maskless += 1
		bits[m] = int(bits.get(m, 0)) + 1
	if maskless == 0:
		_pass("every reported remnant carries a non-zero anchor mask (masks seen: %s)" % [bits])
	else:
		_fail("%d of %d remnant(s) reported mask 0 — a fragment hanging from nothing" % [maskless, framed_r.size()])

	## And the two halves partition the flood: a voxel is destroyed or it is a
	## remnant, never both and never neither. Cheap, and it is what says the split
	## did not quietly drop anything on the floor between the two arrays.
	var seen: Dictionary = {}
	var dupes: int = 0
	for e in framed_res["destroyed"]:
		var k := "%d:%d" % [e["slice"].get_instance_id(), int(e["voxel_index"])]
		if seen.has(k):
			dupes += 1
		seen[k] = true
	for r2 in framed_r:
		var k2 := "%d:%d" % [r2["slice"].get_instance_id(), int(r2["voxel_index"])]
		if seen.has(k2):
			dupes += 1
		seen[k2] = true
	if dupes == 0:
		_pass("the two halves partition the flood — %d voxels, no voxel in both" % seen.size())
	else:
		_fail("%d voxel(s) appear in BOTH halves" % dupes)
	print("")


## ── G4-4 / G-D45 ────────────────────────────────────────────────────────────
##
## Director, 2026-09-05: *"Se a moldura for destruída o caco grudado cai/some
## junto."* `Room.reap_orphaned_remnants()` depends on ONE fact — that
## `remnant_anchor_mask()`, which reads the live world, returns 0 once the frame a
## fragment hung from is gone. This pins that fact without a room: it is the same
## call the reap makes, on the same geometry, before and after the frame falls.
func test_a_remnant_is_orphaned_when_its_frame_is_destroyed() -> void:
	print("[23] G-D45 — remnant_anchor_mask() goes to 0 when the frame is destroyed\n")
	var base: int = GeometryCoords.storey_level_base(0)
	var hit := Vector2i(4 * 8 + 4, 0)

	var pane := _pane(4, 4, 1)
	var wall := _wall(5, 1)
	var world: Array = pane.duplicate()
	world.append(wall)
	var res: Dictionary = GlassShatterClass.plan_pane_shatter(pane, Face.SW, hit,
		base + 3, 3.75, "ORPHAN:1",
		GlassShatterClass.collect_anchor_positions(pane, Face.SW, world))
	var remnants: Array = res["remnants"]
	if remnants.is_empty():
		_fail("the framed pane produced no remnant to orphan")
		print("")
		return

	## Pick the remnant nearest the wall — the one actually anchored to it.
	var target = null
	for r in remnants:
		var rv: Voxel = r["slice"].voxels[int(r["voxel_index"])]
		if target == null or rv.grid_pos.x > target.grid_pos.x:
			target = rv

	var mask_before: int = GlassShatterClass.remnant_anchor_mask(
		pane, Face.SW, world, target.grid_pos, target.level)

	## The frame falls.
	for v in wall.voxels:
		v.set_damage(Voxel.DamageState.DESTROYED, false, 0, 0, 0)

	var mask_after: int = GlassShatterClass.remnant_anchor_mask(
		pane, Face.SW, world, target.grid_pos, target.level)

	if mask_before != 0 and mask_after == 0:
		_pass("held (mask %d) -> orphaned (mask 0) the instant the concrete jamb is destroyed" % mask_before)
	else:
		_fail("mask %d -> %d — reap's orphan test would not fire (before must be non-zero, after must be 0)"
			% [mask_before, mask_after])
	print("")
