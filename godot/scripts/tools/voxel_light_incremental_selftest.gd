## VL-03 selftest — incremental repaint must match a full rebuild exactly.
## Run: godot --headless --script res://godot/scripts/tools/voxel_light_incremental_selftest.gd
##
## A temporal light (flicker/pulse) toggles energy_multiplier on the SAME
## LightSource instance and repaints only VoxelLightField.gus_in_light_range()
## via clear_caches() + bucket_for() — never a full build(). The whole point of
## VL-03 is that this must be indistinguishable from re-deriving everything
## from scratch:
##   1. Every voxel INSIDE the toggled light's influence set must read the same
##      bucket as a fresh build() with the light at its new energy would give.
##   2. Every voxel OUTSIDE that influence set must be UNCHANGED by the toggle
##      (clear_caches() must not corrupt values a caller reads for cells the
##      incremental pass never touched).
##   3. The static factor (surface/soot/under-structure) must survive the
##      toggle unchanged — it does not depend on which lights are on.

extends SceneTree

const VLF = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("VL-03 — incremental repaint == full rebuild SELFTEST")
	print("=".repeat(70) + "\n")

	test_influence_set_matches_full_rebuild()
	test_cells_outside_influence_set_unchanged()
	test_static_factor_survives_toggle()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ VL-03 INCREMENTAL SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ VL-03 INCREMENTAL SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _make_lamp() -> LightSourceClass:
	var lamp = LightSourceClass.new()
	lamp.cell = Vector2i(6, 4)
	lamp.height_class = LightSourceClass.HEIGHT_TALL_STRUCTURE
	lamp.radius = 5
	lamp.visual_energy = 1.0
	lamp.active = true
	return lamp


## Property 1: for a voxel inside the light's range, toggling energy_multiplier
## via clear_caches()+bucket_for() must equal a completely fresh build() at the
## same energy — the exact contract a flicker relies on.
func test_influence_set_matches_full_rebuild() -> void:
	print("[1] Incremental toggle matches a from-scratch rebuild (in range)\n")
	var lamp := _make_lamp()
	var field := VLF.new()
	field.build([lamp], [], 15)

	var gus: Array = field.gus_in_light_range(lamp)
	var sample_cells: Array = [
		Vector2i(lamp.cell.x * 8 + 4, lamp.cell.y * 8 + 4),   ## lamp's own GU, level 8
		Vector2i((lamp.cell.x + 2) * 8, (lamp.cell.y + 1) * 8),  ## 2 GUs off
	]
	var level := 8

	## Toggle OFF via the incremental path.
	lamp.energy_multiplier = 0.0
	field.clear_caches()
	var incremental_off: Array = []
	for c in sample_cells:
		incremental_off.append(field.bucket_for(c, level))

	## Ground truth: a totally fresh field, built from scratch at energy 0.
	var lamp_off := _make_lamp()
	lamp_off.energy_multiplier = 0.0
	var field_fresh_off := VLF.new()
	field_fresh_off.build([lamp_off], [], 15)
	var fresh_off: Array = []
	for c in sample_cells:
		fresh_off.append(field_fresh_off.bucket_for(c, level))

	if incremental_off == fresh_off:
		_pass("OFF toggle buckets match fresh rebuild: %s" % [incremental_off])
	else:
		_fail("OFF toggle %s != fresh rebuild %s" % [incremental_off, fresh_off])

	## Toggle back ON via the incremental path.
	lamp.energy_multiplier = 1.0
	field.clear_caches()
	var incremental_on: Array = []
	for c in sample_cells:
		incremental_on.append(field.bucket_for(c, level))

	var lamp_on := _make_lamp()
	lamp_on.energy_multiplier = 1.0
	var field_fresh_on := VLF.new()
	field_fresh_on.build([lamp_on], [], 15)
	var fresh_on: Array = []
	for c in sample_cells:
		fresh_on.append(field_fresh_on.bucket_for(c, level))

	if incremental_on == fresh_on:
		_pass("ON toggle buckets match fresh rebuild: %s" % [incremental_on])
	else:
		_fail("ON toggle %s != fresh rebuild %s" % [incremental_on, fresh_on])

	if gus.has(Vector2i(6, 4)):
		_pass("lamp's own GU is inside its own gus_in_light_range()")
	else:
		_fail("lamp's own GU missing from gus_in_light_range() — influence set is wrong")
	print("")


## Property 2: the real safety guarantee behind skipping GUs outside
## gus_in_light_range() — a GU beyond the lamp's radius produces the SAME
## bucket regardless of this lamp's energy_multiplier, so the renderer never
## needs to repaint it on a toggle. Verified with two fully INDEPENDENT builds
## (lamp ON vs lamp OFF), not cache state, so this is a property of the falloff
## math itself, not an artifact of what clear_caches() happened to touch.
func test_cells_outside_influence_set_unchanged() -> void:
	print("[2] A GU outside gus_in_light_range() never depends on this lamp\n")
	var lamp_on := _make_lamp()
	lamp_on.energy_multiplier = 1.0
	var field_on := VLF.new()
	field_on.build([lamp_on], [], 15)

	var lamp_off := _make_lamp()
	lamp_off.energy_multiplier = 0.0
	var field_off := VLF.new()
	field_off.build([lamp_off], [], 15)

	## GU distance ~20 from the lamp, well outside radius 5.
	var far_cell := Vector2i((lamp_on.cell.x + 20) * 8, lamp_on.cell.y * 8)
	var far_gu := Vector2i(far_cell.x >> 3, far_cell.y >> 3)
	if field_on.gus_in_light_range(lamp_on).has(far_gu):
		_fail("test setup error: far_gu unexpectedly inside gus_in_light_range()")
		print("")
		return

	var bucket_on := field_on.bucket_for(far_cell, 8)
	var bucket_off := field_off.bucket_for(far_cell, 8)
	if bucket_on == bucket_off:
		_pass("far GU's bucket is identical ON vs OFF (%d) — safe to skip on toggle" % bucket_on)
	else:
		_fail("far GU's bucket DIFFERS ON (%d) vs OFF (%d) — gus_in_light_range() would miss a real change" % [bucket_on, bucket_off])
	print("")


## Property 3: clear_caches() touches ONLY the lamp-dependent caches — the
## geometry state (_occupancy → surface_factor) built by build() must survive
## it untouched. If clear_caches() ever regressed to wiping state instead of
## just memoization, surface shading would silently go flat on every temporal
## toggle (walls losing their axis/AO read every time a lamp flickers).
func test_static_factor_survives_toggle() -> void:
	print("[3] clear_caches() leaves geometry state (surface shading) intact\n")
	var lamp := _make_lamp()
	## A cell with a "ceiling" (blocks the top face) and a solid +X neighbour
	## (blocks SE) — only the SW-ish face is exposed, so surface_factor() must
	## read face_sw_factor (0.48), not the flat 1.0 a missing/cleared occupancy
	## would give.
	var occupancy := {
		0: {Vector2i(49, 32): true},
		1: {Vector2i(48, 32): true},
	}
	var field := VLF.new()
	field.build([lamp], [], 15, occupancy)

	var cell := Vector2i(48, 32)
	var before: float = field.surface_factor(cell, 0)

	lamp.energy_multiplier = 0.0
	field.clear_caches()

	var after: float = field.surface_factor(cell, 0)
	if is_equal_approx(before, after) and before < 1.0:
		_pass("surface_factor still reflects the built occupancy after clear_caches() (%.3f)" % after)
	else:
		_fail("surface_factor changed or went flat across clear_caches(): %.3f -> %.3f" % [before, after])
	print("")
