## P-PURE / P-DELTA — prediction purity selftest (PREDICTION_MASTER_PLAN
## Tasks 2 and 3, 2026-08-09).
## Rodar: python3 tools/persistent/run_selftests.py --only blast_purity
##
## This is the test §11.4 calls "the test that makes the whole plan safe": it
## asserts that computing a detonation changes NOTHING about the world, so a
## prediction that is computed and thrown away costs nothing but the time.
##
## **Task 3 widened its subject from the two mutators to the whole pass.** It
## opened running a hand-written mirror of `build_plan()`'s damage phase, because
## `build_plan()` itself still committed and would have defeated a purity test
## outright. Now that P-DELTA made the builder pure, the mirror is gone and every
## test below runs the REAL `DetonationPlanBuilder.build_plan()` — which is both
## a stronger claim (the whole 170 ms pipeline is pure, not just its damage step)
## and one fewer copy of the pipeline free to drift out of sync with the original.
##
## Why it lives in its own file rather than inside blast_calculator_selftest.gd:
## that suite is Task 2's REGRESSION NET — its ~20 direct calls to the mutating
## `apply_*` functions pin today's behaviour, and the task's own gate is that it
## passes with **zero edits**. Adding to it would have compromised the one piece
## of evidence the refactor rests on.
##
## Everything here runs against the REAL PLAYGROUND map and the REAL frag
## grenade, not a synthetic patch — CLAUDE.md's own standing lesson (a floor-dent
## feature that passed its fixture with 69 dents and produced ZERO on the real
## map). Test 3 exists specifically to make a silently-inert simulate impossible
## to mistake for a clean one.
##
## RED-BEFORE-GREEN, recorded because a purity test that has never failed proves
## nothing. With one `voxel.set_damage(...)` added inside
## `BlastCalculator.damage_entry()` — the smallest edit that makes BOTH
## simulate functions impure at once — this run came back:
##
##     ✗ 167 voxel(s) changed state during build_plan() (e.g. (7, 11) level 0:
##       [0, false, 0, 0, 0, true, false] -> [2, true, 0, 0, 0, false, true])
##     ✗ 3 container(s) had their dirty_count moved by build_plan()
##     RESULT: 6 PASS, 2 FAIL
##
## Note what stayed green under that break, because it is the reason test 1 has
## to exist separately: determinism (2) and the tier census (3) both still
## passed, and test 4 still reported every entry landing correctly — it merely
## counted 167 no-ops instead of 0. An impure builder is invisible to every
## check here except this one.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const BombRegistryClass = preload("res://godot/scripts/systems/destruction/bomb_registry.gd")
const WallEdgeDataClass = preload("res://godot/scripts/world/wall_edge_data.gd")

var passed: int = 0
var failed: int = 0


class MinimalRoom extends Node:
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	@warning_ignore("unused_private_class_variable")
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	var map_id: String = "TEST"


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("P-PURE — BLAST CALCULATOR PURITY SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	bake_config.enabled = true

	var built := _build_playground()
	if not built.is_empty():
		var bomb_def := _load_frag_grenade()
		if bomb_def == null:
			_fail("could not load frag_grenade.json — nothing else can run")
		else:
			var ctx := _build_ctx(built)
			var source_gu: Vector2i = _pick_source_gu(built)
			print("  (real PLAYGROUND, frag_grenade, source GU %s)\n" % source_gu)

			var edge_registry = built["room"]._edge_registry
			var slab_registry = built["room"]._slab_registry

			var before := _snapshot_world(edge_registry, slab_registry)
			var delta_a: WorldDelta = DetonationPlanBuilderClass.build_plan(
				bomb_def, source_gu, ctx)
			var after := _snapshot_world(edge_registry, slab_registry)

			test_1_simulate_writes_nothing(before, after)
			test_2_simulate_is_deterministic(delta_a,
				DetonationPlanBuilderClass.build_plan(bomb_def, source_gu, ctx))
			test_3_the_delta_is_not_empty_on_the_real_map(delta_a)
			## Mutating — must be last. Everything above assumes an untouched world.
			test_4_commit_realises_the_delta(delta_a, edge_registry, slab_registry)

	bake_config.enabled = saved_enabled

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ BLAST PURITY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ BLAST PURITY SELFTEST FAILED\n")
		quit(1)


## ---------------------------------------------------------------------------
## Tests
## ---------------------------------------------------------------------------

## §11.4, the load-bearing one. All SEVEN mutable fields of §2.1's inventory,
## across EVERY voxel in the map — not just the blast's affected set. The wider
## scope is deliberate: a simulate that wrote outside its own reach is exactly
## the failure a purity test exists to catch, and scoping the snapshot to the
## affected set would make that failure invisible. The containers' `dirty_count`
## is checked too, because it is the one piece of mutable state that does NOT
## live on a Voxel (`Voxel._set_dirty()` propagates upward).
func test_1_simulate_writes_nothing(before: Dictionary, after: Dictionary) -> void:
	print("[1] §11.4 — build_plan() leaves all 7 mutable fields of every voxel untouched\n")
	var voxels_before: Dictionary = before["voxels"]
	var voxels_after: Dictionary = after["voxels"]

	if voxels_before.size() != voxels_after.size():
		_fail("the voxel set itself changed size: %d -> %d"
			% [voxels_before.size(), voxels_after.size()])
		return

	var changed: int = 0
	var first_example: String = ""
	for key in voxels_before:
		var a: Array = voxels_before[key]
		var b: Array = voxels_after.get(key, [])
		if a != b:
			changed += 1
			if first_example.is_empty():
				first_example = "%s: %s -> %s" % [key, a, b]
	if changed == 0:
		_pass("%d voxel(s) x 7 fields — not one changed during build_plan()" % voxels_before.size())
	else:
		_fail("%d voxel(s) changed state during build_plan() (e.g. %s)" % [changed, first_example])

	var dirty_before: Dictionary = before["dirty"]
	var dirty_after: Dictionary = after["dirty"]
	var dirty_changed: int = 0
	for cid in dirty_before:
		if int(dirty_before[cid]) != int(dirty_after.get(cid, -1)):
			dirty_changed += 1
	if dirty_changed == 0:
		_pass("%d container dirty_count(s) unchanged — nothing was queued for repaint either"
			% dirty_before.size())
	else:
		_fail("%d container(s) had their dirty_count moved by build_plan()" % dirty_changed)


## §11.5. Determinism is what makes pre-production safe at all: a Delta computed
## on hover and committed on landing is only trustworthy if the same world
## produces the same Delta. §2.4 argues this already holds (every roll is an
## FNV-1a hash of a stable key, never randf()); this is what keeps it holding.
func test_2_simulate_is_deterministic(da: WorldDelta, db: WorldDelta) -> void:
	print("[2] §11.5 — two build_plan() calls on an unchanged world return the same Delta\n")
	var a: Array = da.damage
	var b: Array = db.damage
	if a.size() != b.size():
		_fail("Delta sizes differ: %d vs %d" % [a.size(), b.size()])
		return
	var mismatches: int = 0
	var first_example: String = ""
	for i in range(a.size()):
		var ea: Dictionary = a[i]
		var eb: Dictionary = b[i]
		if ea["voxel"] != eb["voxel"] or ea["state"] != eb["state"] \
				or ea["from_blast"] != eb["from_blast"] \
				or ea["carved_side"] != eb["carved_side"] \
				or ea["variant"] != eb["variant"] \
				or ea["substrate"] != eb["substrate"]:
			mismatches += 1
			if first_example.is_empty():
				first_example = "entry %d: %s vs %s" % [i, _entry_str(ea), _entry_str(eb)]
	if mismatches == 0:
		_pass("%d entries, identical in order and in all 5 payload fields" % a.size())
	else:
		_fail("%d entr(ies) differ between two runs (e.g. %s)" % [mismatches, first_example])


## CLAUDE.md's own standing lesson, as an assertion. A simulate that returned an
## empty Delta would pass tests 1 and 2 perfectly — purity and determinism are
## both trivially true of a function that does nothing. This is the test that
## tells the difference.
func test_3_the_delta_is_not_empty_on_the_real_map(wd: WorldDelta) -> void:
	print("[3] The Delta the REAL map produces is real — not a clean-but-inert simulate\n")
	var delta: Array = wd.damage
	var by_state: Dictionary = {}
	for e in delta:
		var s: int = int(e["state"])
		by_state[s] = int(by_state.get(s, 0)) + 1
	var destroyed: int = int(by_state.get(Voxel.DamageState.DESTROYED, 0))
	var dented: int = int(by_state.get(Voxel.DamageState.DENTED, 0))
	var cracked: int = int(by_state.get(Voxel.DamageState.CRACKED, 0))
	print("      destroyed %d · dented %d · cracked %d   (%d entries total)"
		% [destroyed, dented, cracked, delta.size()])
	if destroyed > 0 and dented > 0 and cracked > 0:
		_pass("all three damage tiers are present on the real PLAYGROUND blast")
	else:
		_fail("a tier came back empty on the real map — destroyed %d, dented %d, cracked %d"
			% [destroyed, dented, cracked])

	## §3.4's queryable surface, as an assertion rather than a promise. A HUD or
	## a preview reads these three and never walks `damage`, so a Delta that
	## silently shipped them empty would break a consumer that has no other way
	## to notice.
	var wave_entries: int = 0
	for kind in wd.waves:
		for ring in wd.waves[kind]:
			wave_entries += (wd.waves[kind][ring] as Array).size()
	print("      waves %d entries · census %d row(s) · touched %d cell(s) · cost %.1f ms"
		% [wave_entries, wd.census.size(), wd.touched.size(), wd.cost_ms])
	if wave_entries > 0 and not wd.census.is_empty() \
			and wd.touched.size() == wd.touched_voxels.size() and wd.cost_ms > 0.0:
		_pass("§3.4 surface populated — waves, census, touched (cells == voxels) and cost_ms")
	else:
		_fail("§3.4 surface incomplete — waves %d, census %d, touched %d vs voxels %d, cost %.1f"
			% [wave_entries, wd.census.size(), wd.touched.size(),
				wd.touched_voxels.size(), wd.cost_ms])


## The other half of the contract: the Delta must be a FAITHFUL description of
## the mutation, not merely a harmless one. After commit, every entry's voxel
## must hold exactly what its entry said — otherwise a consumer reading a Delta
## (the HUD's damage estimate, a preview) would be shown something the commit
## does not actually produce.
##
## The one legitimate exception is `Voxel.set_damage()`'s early return: an entry
## targeting a voxel ALREADY in that state writes nothing and keeps its older
## provenance fields. On a first blast against an intact map that set should be
## empty, and it is counted rather than waved through so a future non-empty one
## shows up as a number instead of as silence.
func test_4_commit_realises_the_delta(wd: WorldDelta, edge_registry, slab_registry) -> void:
	print("[4] delta.commit() writes exactly what the Delta described\n")
	var delta: Array = wd.damage
	var no_ops: int = 0
	for e in delta:
		if e["voxel"].damage_state == e["state"]:
			no_ops += 1

	wd.commit()

	var wrong: int = 0
	var first_example: String = ""
	var destroyed_hidden: int = 0
	for e in delta:
		var v = e["voxel"]
		if v.damage_state != e["state"] or v.damage_is_blast != e["from_blast"] \
				or v.damage_carved_side != e["carved_side"] \
				or v.damage_variant != e["variant"] \
				or v.damage_substrate != e["substrate"]:
			wrong += 1
			if first_example.is_empty():
				first_example = "%s wanted %s got state=%d side=%d var=%d sub=%d blast=%s" % [
					v.grid_pos, _entry_str(e), v.damage_state, v.damage_carved_side,
					v.damage_variant, v.damage_substrate, v.damage_is_blast]
		if e["state"] == Voxel.DamageState.DESTROYED and not v.visible:
			destroyed_hidden += 1
	if wrong == 0:
		_pass("%d entries committed, every one landed exactly as described (%d no-op entr(ies))"
			% [delta.size(), no_ops])
	else:
		_fail("%d committed entr(ies) do not match their Delta (e.g. %s)" % [wrong, first_example])

	var destroy_total: int = 0
	for e in delta:
		if e["state"] == Voxel.DamageState.DESTROYED:
			destroy_total += 1
	if destroyed_hidden == destroy_total:
		_pass("all %d DESTROYED entries also cleared `visible` — the 7th field travels too"
			% destroy_total)
	else:
		_fail("%d of %d DESTROYED entries left `visible` true" % [
			destroy_total - destroyed_hidden, destroy_total])

	## Guards against the opposite failure of test 1: a commit whose reach is
	## WIDER than its Delta. Anything dirty that no entry named is a write from
	## somewhere this Delta never described.
	var named: Dictionary = {}
	for e in delta:
		named[e["voxel"]] = true
	var unnamed_dirty: int = 0
	for v in _all_voxels(edge_registry, slab_registry):
		if v.dirty and not named.has(v):
			unnamed_dirty += 1
	if unnamed_dirty == 0:
		_pass("no voxel outside the Delta came out dirty — the commit's reach is the Delta's")
	else:
		_fail("%d voxel(s) outside the Delta were dirtied by the commit" % unnamed_dirty)


## ---------------------------------------------------------------------------
## Scaffold — mirrors detonation_choreographer_selftest.gd's own, deliberately
## as an independent copy (same precedent that file records: a selftest must run
## without a real Room).
## ---------------------------------------------------------------------------

## §2.1's complete mutable surface, per voxel, plus the container counter the
## 7th field propagates into. Keyed by the Voxel itself so identity, not
## position, decides what is being compared.
func _snapshot_world(edge_registry, slab_registry) -> Dictionary:
	var voxels: Dictionary = {}
	for v in _all_voxels(edge_registry, slab_registry):
		voxels[v] = [v.damage_state, v.damage_is_blast, v.damage_carved_side,
			v.damage_variant, v.damage_substrate, v.visible, v.dirty]
	var dirty: Dictionary = {}
	for slice in edge_registry.all_slices():
		dirty[slice.id] = slice.dirty_count
	for slab in slab_registry.all_slabs():
		dirty[slab.id] = slab.dirty_count
	return {"voxels": voxels, "dirty": dirty}


func _all_voxels(edge_registry, slab_registry) -> Array:
	var out: Array = []
	for slice in edge_registry.all_slices():
		out.append_array(slice.voxels)
	for slab in slab_registry.all_slabs():
		out.append_array(slab.voxels)
	return out


func _entry_str(e: Dictionary) -> String:
	return "state=%d side=%d var=%d sub=%d blast=%s" % [
		e["state"], e["carved_side"], e["variant"], e["substrate"], e["from_blast"]]


func _build_playground() -> Dictionary:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty")
		return {}
	var layout: Dictionary = MapCompilerClass.compile(spec)

	var room := MinimalRoom.new()
	root.add_child(room)
	var floor_tileset: TileSet = load("res://godot/resources/tilesets/tileset_blocks.tres")
	var floor_layer := TileMapLayer.new()
	var structure_layer := TileMapLayer.new()
	floor_layer.tile_set = floor_tileset
	structure_layer.tile_set = floor_tileset
	room.add_child(floor_layer)
	room.add_child(structure_layer)
	var voxel_renderer := VoxelRendererClass.new()
	room.add_child(voxel_renderer)
	voxel_renderer.setup(Vector2.ZERO)
	room._voxel_renderer = voxel_renderer
	var builder := RoomBuilderClass.new(room)
	builder.setup(floor_layer, structure_layer, TileSet.new())
	builder.build_registry(floor_tileset)
	builder.build_from_layout(layout, layout.get("size", Vector2i.ZERO))
	return {"room": room, "renderer": voxel_renderer, "builder": builder, "layout": layout}


func _load_frag_grenade() -> BombDef:
	var registry := BombRegistryClass.new()
	registry.load_from_disk()
	return registry.get_bomb("frag_grenade")


func _build_ctx(built: Dictionary) -> Dictionary:
	var layout: Dictionary = built["layout"]
	var builder = built["builder"]
	var blocked_edges: Dictionary = {}
	for e in layout.get("blocked_edges", []):
		blocked_edges[WallEdgeDataClass.edge_key(e["from"], e["to"])] = true
	return {
		"edge_registry": built["room"]._edge_registry,
		"slab_registry": built["room"]._slab_registry,
		"voxel_renderer": built["renderer"],
		"blocked_edges": blocked_edges,
		"blocked_cells": builder.get_blocked_cells(),
	}


func _pick_source_gu(built: Dictionary) -> Vector2i:
	var edge_registry = built["room"]._edge_registry
	for slice in edge_registry.all_slices():
		if slice.material == "concrete":
			return slice.gu_cell
	return Vector2i.ZERO


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1
