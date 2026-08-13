## E-PLAN — DetonationPlanBuilder selftest (EXPLOSION_REBUILD_MASTER_PLAN
## Task 4, 2026-08-07).
## Rodar: godot --headless --script res://godot/scripts/tools/detonation_plan_selftest.gd
##
## Boots the REAL PLAYGROUND map through the exact room.gd::load_map() path
## (mirrors damage_atom_bake_selftest.gd's own MinimalRoom scaffold), runs
## DetonationPlanBuilder.build_plan() against a REAL grenade throw at a real
## wall's own GU, and proves:
##   1. The Task 4 gate itself — a printed wave census (cell counts per
##      ring, per wave kind) from a real detonation, not a synthetic fixture.
##   2. Every dented/cracked/expose entry carries a real, resolved
##      (source_id, atlas_coords, alt) triple — never a placeholder.
##   3. build_plan() never mutates the live TileMapLayer — every placed
##      cell's (source_id, atlas_coords, alt) is BYTE-IDENTICAL before and
##      after, proven by a real snapshot diff, not by re-reading the code's
##      own claim.
##   4. The exposure fallback (§2/B5) fires for real: at least one destroy
##      entry carries a non-empty `expose` array once the crater opens the
##      floor.
##   5. smoke_ring_weights is consumed for real (duration/scale fall off
##      with ring, matching the JSON's own weights) — the "still unread"
##      gap Task 3's closure note flagged.
##   6. The per-tier ring gates from the REAL frag_grenade.json hold on real
##      data: crack_ring_weights[0]=0.0 means ring 0 never has a cracked
##      entry, dent_ring_weights[2]=0.0 means ring 2 never has a dented one.
##   7. E-EMBER-01: a real blast at PLAYGROUND's own WOOD wall queues embers,
##      every one on a SURVIVING combustible voxel 6-adjacent to a hole this
##      same blast opens — cell->material read off the live registries, not
##      assumed. Non-zero on real data is the point: this is the exact shape
##      of failure the floor-dent case (69 on a fixture, 0 on PLAYGROUND) is
##      remembered for.
##   8. E-SMOKE-TINT-01: every per-voxel smoke entry carries the material it
##      came from, without which the choreographer cannot tint the puff.
##   9. E-EMBER-02: fire creeps UPWARD one level at a time (every rung sits
##      directly above another lit voxel and burns shorter than it), the creep
##      is FNV-1a-deterministic across two builds of the same blast, and an
##      ember COOLS yellow-hot -> deep red while dimming — the one detail the
##      Director first described inverted and then corrected.
##
## Every expectation is checked against the REAL plan/registry/renderer
## state — never read back from the code under test's own success claim.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const BombRegistryClass = preload("res://godot/scripts/systems/destruction/bomb_registry.gd")
const WallEdgeDataClass = preload("res://godot/scripts/world/wall_edge_data.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const EmberOverlayClass = preload("res://godot/scripts/overlays/ember_overlay.gd")

var passed: int = 0
var failed: int = 0


class MinimalRoom extends Node:
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
	var map_id: String = "TEST"


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-PLAN — DETONATION PLAN BUILDER SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	bake_config.enabled = true

	var built := _build_playground()
	if not built.is_empty():
		var bomb_def := _load_frag_grenade()
		if bomb_def != null:
			var ctx := _build_ctx(built)
			var source_gu: Vector2i = _pick_source_gu(built)
			var before := _snapshot_layers(built["renderer"])
			var plan: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, source_gu, ctx).waves
			var after := _snapshot_layers(built["renderer"])

			test_1_wave_census(plan, source_gu)
			test_2_resolved_triples(plan)
			test_3_no_live_layer_mutation(before, after)
			test_4_exposure_fallback(plan)
			test_5_smoke_ring_weights_consumed(plan, bomb_def)
			test_6_real_ring_gates(plan, bomb_def)
			test_7_ember_wave_on_real_wood(built, bomb_def, ctx)
			test_8_smoke_entries_carry_material(plan)
			test_9_ember_climb_and_cooling_ramp(built, bomb_def, ctx)
		else:
			_fail("could not load frag_grenade.json — nothing else can run")

	bake_config.enabled = saved_enabled

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ DETONATION PLAN SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DETONATION PLAN SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Mirrors damage_atom_bake_selftest.gd's own _build_playground() exactly —
## the established real-PLAYGROUND-without-a-full-game-boot scaffold.
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
	var bomb_def: BombDef = registry.get_bomb("frag_grenade")
	if bomb_def == null:
		_fail("BombRegistry could not load frag_grenade.json")
	return bomb_def


## room.gd's own blocked_edges/blocked_cells derivation (room.gd:609/633-636),
## reproduced against this scaffold's layout/builder instead of a live room.
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
		"lights": _real_light_sources(builder),
		"shadow_results": [],
		## E-JUNCTION-01: real coverage, not a defaulted-empty ctx — matches
		## test_zone_controller.gd's real _build_detonation_ctx() shape.
		"junction_columns": built["room"]._junction_columns,
	}


## RoomBuilder.get_light_sources() returns raw map-data Dictionaries
## ({x,y,height,radius,intensity,...}); a real room only ever feeds
## VoxelLightField real LightSource objects, converted by
## LightingController._setup_lights_from_layout(). This scaffold has no
## LightingController, so it replicates that exact conversion — same field
## reads, same defaults — rather than passing dicts DetonationPlanBuilder's
## real contract (ctx["lights"] = LightRegistry.get_active_lights()'s own
## shape) was never meant to accept.
func _real_light_sources(builder) -> Array:
	var out: Array = []
	var sources: Array = builder.get_light_sources()
	for i in range(sources.size()):
		var src: Dictionary = sources[i]
		var light = LightSourceClass.new()
		light.cell = Vector2i(int(src.get("x", 0)), int(src.get("y", 0)))
		light.light_type = String(src.get("type", LightSourceClass.TYPE_OMNI))
		if src.has("height_class"):
			light.height_class = int(src["height_class"])
		elif src.has("height"):
			light.height_class = clampi(int(src["height"]), 0, 4)
		else:
			light.height_class = TileSemanticsClass.HEIGHT_OVERHEAD
		light.radius = int(src.get("radius", 6))
		light.tactical_energy = float(src.get("intensity", 1.0))
		light.visual_energy = float(src.get("visual_intensity", src.get("intensity", 1.0)))
		light.direction_angle = deg_to_rad(float(src.get("direction_deg", 0.0)))
		light.cone_angle = float(src.get("cone_deg", light.cone_angle))
		light.active = true
		light.light_id = "map_light_%d" % (i + 1)
		light.owner_name = "map_light_%d" % (i + 1)
		out.append(light)
	return out


## The GU of the first real concrete wall slice — guaranteed to exist
## (Task 1a/1b's own real-coverage proof), so the blast is guaranteed to
## reach at least one real wall regardless of PLAYGROUND's exact layout,
## rather than a hand-picked coordinate that could silently miss everything
## the next time the map is edited.
func _pick_source_gu(built: Dictionary) -> Vector2i:
	var edge_registry = built["room"]._edge_registry
	for slice in edge_registry.all_slices():
		if slice.material == "concrete":
			return slice.gu_cell
	return Vector2i.ZERO


## Every placed cell's (source_id, atlas_coords, alt), across every wall and
## floor layer this renderer holds — the ground truth test_3 diffs against.
func _snapshot_layers(renderer) -> Dictionary:
	var out: Dictionary = {}
	for level in range(renderer._voxel_layers.size()):
		var layer: TileMapLayer = renderer._voxel_layers[level]
		for cell in layer.get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = [layer.get_cell_source_id(cell),
				layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)]
	for level in renderer._negative_voxel_layers.keys():
		var nlayer: TileMapLayer = renderer._negative_voxel_layers[level]
		for cell in nlayer.get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = [nlayer.get_cell_source_id(cell),
				nlayer.get_cell_atlas_coords(cell), nlayer.get_cell_alternative_tile(cell)]
	return out


func test_1_wave_census(plan: Dictionary, source_gu: Vector2i) -> void:
	print("[1] Wave census — the Task 4 gate itself (real detonation at gu=%s)\n" % source_gu)
	var any_content := false
	for kind in ["destroy", "dented", "cracked", "smoke", "soot"]:
		var by_ring: Dictionary = plan[kind]
		var rings: Array = by_ring.keys()
		rings.sort()
		var parts: Array = []
		var total := 0
		for ring in rings:
			var n: int = by_ring[ring].size()
			total += n
			parts.append("ring%d=%d" % [ring, n])
		print("  %-8s %s (total=%d)" % [kind + ":", ", ".join(parts) if not parts.is_empty() else "(empty)", total])
		if total > 0:
			any_content = true
	if any_content:
		_pass("at least one wave produced real cells from a real detonation")
	else:
		_fail("every wave was empty — the plan builder produced nothing for a real blast")
	print("")


func test_2_resolved_triples(plan: Dictionary) -> void:
	print("[2] dented/cracked entries carry real resolved (source_id, atlas_coords, alt)\n")
	var checked := 0
	var ok := true
	for kind in ["dented", "cracked"]:
		for ring in plan[kind].keys():
			for entry in plan[kind][ring]:
				checked += 1
				if not (entry.has("source_id") and entry.has("atlas_coords") and entry.has("alt")):
					ok = false
				elif int(entry["source_id"]) < 0:
					ok = false
	if checked == 0:
		_pass("no dented/cracked entries this blast (nothing to check — real data, not assumed)")
	elif ok:
		_pass("%d dented/cracked entries all carry a real non-negative source_id + atlas_coords + alt" % checked)
	else:
		_fail("at least one dented/cracked entry is missing a resolved field or has source_id < 0")
	print("")


func test_3_no_live_layer_mutation(before: Dictionary, after: Dictionary) -> void:
	print("[3] build_plan() never touches the live TileMapLayer\n")
	if before.size() != after.size():
		_fail("placed-cell COUNT changed (%d -> %d) — build_plan() painted or erased something" %
			[before.size(), after.size()])
		return
	var mismatches := 0
	for key in before.keys():
		if not after.has(key) or after[key] != before[key]:
			mismatches += 1
	if mismatches == 0:
		_pass("%d placed cells are byte-identical before and after build_plan() — zero live mutation" % before.size())
	else:
		_fail("%d placed cells changed during build_plan() — it touched the live layer" % mismatches)
	print("")


func test_4_exposure_fallback(plan: Dictionary) -> void:
	print("[4] Exposure fallback (§2/B5) — a destroyed floor voxel exposes the deep plane below it\n")
	var found := false
	var expose_count := 0
	for ring in plan["destroy"].keys():
		for entry in plan["destroy"][ring]:
			var expose: Array = entry.get("expose", [])
			if not expose.is_empty():
				found = true
				expose_count += expose.size()
	if found:
		_pass("%d expose entries resolved (real tiles, not applied) under real destroy waves" % expose_count)
	else:
		_fail("no destroy entry carried an `expose` array — floor exposure never fired on a real blast")
	print("")


## E-SMOKE-01 (2026-08-08) rewrote what this test can assert. It used to demand
## `duration == scale == smoke_ring_weights[ring]` EXACTLY, which was provable
## only while smoke was one flat descriptor per GU. The Director's per-voxel smoke
## ("praticamente todo voxel afetado pode soltar um pouquinho de fumaça, com
## intensidades diferentes e durações diferentes") makes that equality false BY
## DESIGN — every puff is the product of its voxel's damage tier, its ring
## weight, and a per-cell hash. The test's own title is still the right intent, so
## the three properties below replace the equality rather than the test being
## dropped or weakened:
##   (a) a ring whose weight is 0.0 emits NOTHING — the weight still gates;
##   (b) every puff stays inside the envelope its ring weight allows — the weight
##       still SCALES, which an equality check proved and a "> 0" check would not;
##   (c) puffs within one ring actually differ from each other — the variation the
##       Director asked for is real, not a constant dressed up as one.
func test_5_smoke_ring_weights_consumed(plan: Dictionary, bomb_def) -> void:
	print("[5] smoke_ring_weights still gates and scales every per-voxel puff (E-SMOKE-01)\n")
	var by_ring: Dictionary = plan["smoke"]
	if by_ring.is_empty():
		_fail("no smoke entries at all — smoke_ring_weights cannot be proven consumed")
		print("")
		return

	## SIZE is still ring-weight-scaled: the largest scale _append_voxel_smoke()
	## can produce for a ring is the strongest tier, at full jitter, on that
	## ring's own weight. The GU-level remainder puffs (scale == weight) sit well
	## inside it.
	var scale_envelope := func(ring: int) -> float:
		var weight: float = bomb_def.smoke_ring_weights[ring] if ring < bomb_def.smoke_ring_weights.size() else 0.0
		return DetonationPlanBuilderClass.SMOKE_SCALE_BASE \
			* DetonationPlanBuilderClass.DESTROY_SMOKE_INTENSITY * weight \
			* (1.0 + DetonationPlanBuilderClass.SMOKE_JITTER)

	## LIFETIME deliberately is NOT, since 2026-08-08's second smoke pass. Scaling
	## duration on strength like size and alpha made an outer cracked voxel's puff
	## last ~0.1 s — the thinning outer edge vanished first, which is exactly what
	## the Director wanted to keep ("deixar a fumaça mais tempo no final").
	## SMOKE_DURATION_FLOOR decouples the two: a far puff is small and faint but
	## not instantaneous, so its envelope is global rather than per-ring. Asserting
	## the old per-ring bound here would be asserting a rule the code deliberately
	## no longer follows.
	var duration_limit: float = 1.0 + DetonationPlanBuilderClass.SMOKE_DURATION_JITTER

	var gated_ok := true
	var scaled_ok := true
	var varied_rings := 0
	var uniform_rings: Array[String] = []
	for ring in by_ring.keys():
		var weight: float = bomb_def.smoke_ring_weights[ring] if ring < bomb_def.smoke_ring_weights.size() else 0.0
		var entries: Array = by_ring[ring]
		if weight <= 0.0 and not entries.is_empty():
			gated_ok = false
			continue
		var limit: float = scale_envelope.call(ring) + 0.0001
		var distinct: Dictionary = {}
		for entry in entries:
			var scale: float = float(entry["scale"])
			var duration: float = float(entry["duration"])
			if scale <= 0.0 or scale > limit:
				scaled_ok = false
			if duration <= 0.0 or duration > duration_limit + 0.0001:
				scaled_ok = false
			distinct["%.3f|%.3f" % [scale, duration]] = true
		if entries.size() >= 8:
			if distinct.size() > 1:
				varied_rings += 1
			else:
				uniform_rings.append("ring %d (%d identical puffs)" % [ring, entries.size()])

	if gated_ok:
		_pass("no smoke entry exists in a ring frag_grenade.json weights at 0.0 — the gate holds")
	else:
		_fail("a ring with smoke_ring_weights 0.0 still produced puffs — the gate is not applied")
	if scaled_ok:
		_pass("every puff's size stays inside its ring weight's envelope, and every lifetime inside the global one")
	else:
		_fail("at least one puff fell outside its size or lifetime envelope")
	if uniform_rings.is_empty() and varied_rings > 0:
		_pass("%d ring(s) with 8+ puffs each carry genuinely different intensities/durations" % varied_rings)
	else:
		_fail("per-voxel variation missing: %s" % ", ".join(uniform_rings))
	print("")


func test_6_real_ring_gates(plan: Dictionary, bomb_def) -> void:
	print("[6] Per-tier ring gates hold on REAL data (frag_grenade.json's own zero-weight rings)\n")
	var all_ok := true
	for ring in range(bomb_def.crack_ring_weights.size()):
		if bomb_def.crack_ring_weights[ring] <= 0.0 and plan["cracked"].has(ring) and not plan["cracked"][ring].is_empty():
			_fail("crack_ring_weights[%d]=0.0 but ring %d produced %d cracked entries" %
				[ring, ring, plan["cracked"][ring].size()])
			all_ok = false
	for ring in range(bomb_def.dent_ring_weights.size()):
		if bomb_def.dent_ring_weights[ring] <= 0.0 and plan["dented"].has(ring) and not plan["dented"][ring].is_empty():
			_fail("dent_ring_weights[%d]=0.0 but ring %d produced %d dented entries" %
				[ring, ring, plan["dented"][ring].size()])
			all_ok = false
	for ring in range(bomb_def.destroy_ring_weights.size()):
		if bomb_def.destroy_ring_weights[ring] <= 0.0 and plan["destroy"].has(ring):
			for entry in plan["destroy"][ring]:
				if not entry.has("expose"):
					_fail("destroy_ring_weights[%d]=0.0 but ring %d produced a real (non-exposure) destroy entry" % [ring, ring])
					all_ok = false
					break
	if all_ok:
		_pass("no wave produced a cell in a ring its own JSON weight zeroes out")


## E-EMBER-01 (2026-08-13) — the per-voxel ember glow on combustible material,
## restored after eight days in which three documents described it as shipped
## and no code had fired one since the 2026-08-05 `[RESET]`.
##
## Deliberately a SECOND build_plan() against the SAME already-built PLAYGROUND
## rather than a synthetic fixture, and rather than retargeting _pick_source_gu()
## (which would silently change the data tests 1-6 assert on). build_plan() is
## PURE — §3's whole contract — so calling it twice is free of side effects, and
## this way the ember gate is proven on the map's REAL wood, which is the exact
## failure mode CLAUDE.md's floor-dent case exists to catch: a fixture is built
## out of the material that works, so it cannot detect a feature made inert by
## real map data.
func test_7_ember_wave_on_real_wood(built: Dictionary, bomb_def, ctx: Dictionary) -> void:
	print("\n[7] E-EMBER-01: a real blast at PLAYGROUND's WOOD wall queues embers on the survivors\n")
	var edge_registry = built["room"]._edge_registry
	var wood_gu := Vector2i(-9999, -9999)
	for slice in edge_registry.all_slices():
		if slice.material == "wood":
			wood_gu = slice.gu_cell
			break
	if wood_gu.x == -9999:
		_fail("PLAYGROUND has no wood slice at all — this test cannot prove anything")
		return

	var plan: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, wood_gu, ctx).waves
	var embers: Array = []
	for ring in plan.get("ember", {}).keys():
		embers.append_array(plan["ember"][ring])
	if embers.is_empty():
		_fail("a real blast at the wood wall (gu=%s) queued ZERO embers — the feature is inert on real data" % wood_gu)
		return
	_pass("real wood blast at gu=%s queued %d ember(s)" % [wood_gu, embers.size()])

	## The holes this same plan opens — the ember's only legal seed.
	var holes: Dictionary = {}
	for ring in plan.get("destroy", {}).keys():
		for entry in plan["destroy"][ring]:
			holes[Vector3i(entry["cell"].x, entry["cell"].y, int(entry["level"]))] = true

	## Real cell -> material, read off the live registries rather than assumed,
	## so "only combustible material glows" is checked against the map itself.
	var material_of: Dictionary = {}
	for slice in edge_registry.all_slices():
		for v in slice.voxels:
			material_of[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = slice.material
	for slab in built["room"]._slab_registry.all_slabs():
		for v in slab.voxels:
			material_of[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = slab.material
	## JunctionColumn is the THIRD container class (E-JUNCTION-01), and leaving it
	## out is not a rounding error: PLAYGROUND has 20 columns and 4 of them are
	## wood, so the first run of this test reported 10 embers on "non-combustible"
	## material that were in fact on real wood the ground truth simply did not
	## know about. Their cells never collide with a Slice's or a Slab's (measured:
	## 0 overlaps), so a plain third pass is enough.
	for column in built["room"]._junction_columns:
		for v in column.voxels:
			material_of[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = column.material

	const NEIGHBOURS: Array = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var seen: Dictionary = {}
	var on_a_hole := 0
	var not_adjacent := 0
	var non_combustible := 0
	var duplicated := 0
	var wrong_scale := 0
	var expected_scale: float = MaterialResistanceTable.flammability("wood")
	## E-EMBER-02 split this set in two. A SEED is a survivor beside a hole (this
	## test's subject, `delay == 0`); a RUNG is a creep step the fire climbed to
	## afterwards, which by construction touches no hole and burns shorter than
	## whatever lit it. Rungs are not skipped here — test 9 owns them in full
	## (each must sit directly above another lit voxel and carry a strictly
	## smaller duration_scale), so narrowing these two checks to the seeds moves
	## coverage rather than dropping it. The other four checks below still run on
	## EVERY ember, seed or rung.
	var seeds := 0
	for e in embers:
		var key := Vector3i(e["cell"].x, e["cell"].y, int(e["level"]))
		var is_seed: bool = int(e.get("climb", 0)) == 0
		if seen.has(key):
			duplicated += 1
		seen[key] = true
		if holes.has(key):
			on_a_hole += 1
		if MaterialResistanceTable.flammability(String(material_of.get(key, ""))) <= 0.0:
			non_combustible += 1
		if not is_seed:
			continue
		seeds += 1
		var touches := false
		for d in NEIGHBOURS:
			if holes.has(key + d):
				touches = true
				break
		if not touches:
			not_adjacent += 1
		if absf(float(e.get("duration_scale", -1.0)) - expected_scale) > 0.0001:
			wrong_scale += 1
	if seeds == 0:
		_fail("every ember is a creep rung — no seed at all, which cannot happen if the creep works")
		return

	if on_a_hole == 0:
		_pass("no ember sits on a cell this blast destroys — every one is a SURVIVOR (VL-D4's predicate)")
	else:
		_fail("%d ember(s) sit on a destroyed cell — the glow is on the hole, not its edge" % on_a_hole)

	if not_adjacent == 0:
		_pass("every one of the %d SEED embers is 6-adjacent to a hole this blast opened" % seeds)
	else:
		_fail("%d SEED ember(s) touch no hole from this blast — seeded from the wrong set" % not_adjacent)

	if non_combustible == 0:
		_pass("every ember's own voxel is a combustible material on the real map (flammability > 0)")
	else:
		_fail("%d ember(s) landed on non-combustible material — the flammability gate leaks" % non_combustible)

	if duplicated == 0:
		_pass("no cell was queued twice (one ember per voxel, whatever its hole count)")
	else:
		_fail("%d duplicate ember cell(s) — a voxel beside two holes glows twice as bright" % duplicated)

	if wrong_scale == 0:
		_pass("every SEED ember carries wood's own flammability as duration_scale (%.2f)" % expected_scale)
	else:
		_fail("%d SEED ember(s) carry a duration_scale that is not the material table's value" % wrong_scale)

	## The negative half of the gate, on real data: a blast far from any wood
	## must produce no embers at all. Uses the same concrete GU tests 1-6 run on.
	var concrete_gu: Vector2i = _pick_source_gu(built)
	var concrete_plan: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, concrete_gu, ctx).waves
	var concrete_embers := 0
	for ring in concrete_plan.get("ember", {}).keys():
		concrete_embers += (concrete_plan["ember"][ring] as Array).size()
	var reaches_wood := false
	for ring in concrete_plan.get("destroy", {}).keys():
		for entry in concrete_plan["destroy"][ring]:
			var k := Vector3i(entry["cell"].x, entry["cell"].y, int(entry["level"]))
			for d in NEIGHBOURS:
				if MaterialResistanceTable.flammability(String(material_of.get(k + d, ""))) > 0.0:
					reaches_wood = true
					break
			if reaches_wood:
				break
		if reaches_wood:
			break
	if reaches_wood:
		_pass("concrete-wall blast reaches wood too (%d ember(s)) — no negative case available at this GU, and that is the map's shape, not a skip" % concrete_embers)
	elif concrete_embers == 0:
		_pass("a blast whose holes touch no combustible voxel queues ZERO embers")
	else:
		_fail("a blast touching no combustible voxel still queued %d ember(s)" % concrete_embers)


## E-SMOKE-TINT-01 (2026-08-13) — every per-voxel smoke puff carries the material
## it came from, which is what lets DetonationChoreographer tint it. The GU-level
## remainder puffs (_phase_smoke) legitimately carry none: they belong to a GU the
## flood reached but left intact, so there is no damaged voxel to take a material
## from. They are told apart by `blobs == 0`, the same flag the choreographer
## already uses to mean "GU remainder".
func test_8_smoke_entries_carry_material(plan: Dictionary) -> void:
	print("\n[8] E-SMOKE-TINT-01: per-voxel smoke entries carry their material\n")
	var per_voxel := 0
	var missing := 0
	var materials: Dictionary = {}
	for ring in plan.get("smoke", {}).keys():
		for entry in plan["smoke"][ring]:
			if int(entry.get("blobs", 0)) == 0:
				continue
			per_voxel += 1
			var m: String = String(entry.get("material", ""))
			if m.is_empty() or m == "?":
				missing += 1
			else:
				materials[m] = int(materials.get(m, 0)) + 1
	if per_voxel == 0:
		_fail("no per-voxel smoke entries at all — cannot prove the material rides along")
		return
	if missing == 0:
		var names: Array = materials.keys()
		names.sort()
		var summary: Array = []
		for n in names:
			summary.append("%s×%d" % [n, materials[n]])
		_pass("all %d per-voxel puffs carry a real material (%s)" % [per_voxel, ", ".join(summary)])
	else:
		_fail("%d of %d per-voxel smoke entries carry no material — those puffs cannot be tinted" %
			[missing, per_voxel])


## E-EMBER-02 (2026-08-13) — the upward creep and the cooling ramp.
##
## The ramp assertion lives in this file rather than in an overlay selftest of
## its own because it is the same feature and, more to the point, it pins the
## one detail the Director specified BACKWARDS and then corrected: the glow runs
## yellow-hot -> red -> out, not red -> yellow. A ramp that silently inverts
## would still look like fire in a screenshot, which is exactly why it gets an
## assertion instead of an eyeball.
func test_9_ember_climb_and_cooling_ramp(built: Dictionary, bomb_def, ctx: Dictionary) -> void:
	print("\n[9] E-EMBER-02: fire creeps upward, and an ember COOLS as it dies\n")
	var edge_registry = built["room"]._edge_registry
	var wood_gu := Vector2i(-9999, -9999)
	for slice in edge_registry.all_slices():
		if slice.material == "wood":
			wood_gu = slice.gu_cell
			break
	if wood_gu.x == -9999:
		_fail("PLAYGROUND has no wood slice — cannot exercise the creep")
		return

	var plan: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, wood_gu, ctx).waves
	var by_cell: Dictionary = {}
	var climbed: Array = []
	for ring in plan.get("ember", {}).keys():
		for e in plan["ember"][ring]:
			by_cell[Vector3i(e["cell"].x, e["cell"].y, int(e["level"]))] = e
			if int(e.get("climb", 0)) > 0:
				climbed.append(e)

	if climbed.is_empty():
		_fail("no ember carries a climb rank — the upward creep produced nothing on real data")
		return
	_pass("%d of %d ember(s) are creep rungs (climb > 0)" % [climbed.size(), by_cell.size()])

	## A rung must sit directly above another lit voxel — the creep is
	## continuous, never a light floating up a column on its own.
	var orphan := 0
	var not_shorter := 0
	for e in climbed:
		var here := Vector3i(e["cell"].x, e["cell"].y, int(e["level"]))
		var below: Dictionary = by_cell.get(Vector3i(here.x, here.y, here.z - 1), {})
		if below.is_empty():
			orphan += 1
			continue
		if float(e["duration_scale"]) >= float(below["duration_scale"]):
			not_shorter += 1
	if orphan == 0:
		_pass("every creep rung sits directly above another lit voxel — the climb is continuous")
	else:
		_fail("%d creep rung(s) have nothing lit below them — the climb is skipping levels" % orphan)
	if not_shorter == 0:
		_pass("every rung burns shorter than the voxel that lit it ('apagando logo em seguida')")
	else:
		_fail("%d rung(s) burn as long as or longer than the voxel below" % not_shorter)

	## Determinism: the creep is FNV-1a per cell, not randf(). Two builds of the
	## same blast must produce byte-identical delays, or the filmstrip and every
	## pixel-diff gate built on it stop meaning anything.
	var again: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, wood_gu, ctx).waves
	var mismatch := 0
	var second := 0
	for ring in again.get("ember", {}).keys():
		for e in again["ember"][ring]:
			second += 1
			var prior: Dictionary = by_cell.get(
				Vector3i(e["cell"].x, e["cell"].y, int(e["level"])), {})
			if prior.is_empty() or absf(float(prior["delay"]) - float(e["delay"])) > 0.000001:
				mismatch += 1
	if mismatch == 0 and second == by_cell.size():
		_pass("a second build of the same blast reproduces all %d embers and delays exactly" % second)
	else:
		_fail("re-building the same blast changed %d of %d ember(s) — the creep is not deterministic"
			% [mismatch, second])

	## The ramp itself, on a real EmberOverlay rather than a hand-built dict.
	var overlay := EmberOverlayClass.new()
	built["room"].add_child(overlay)
	overlay.add_ember(Vector2(100.0, 100.0))
	var e0: Dictionary = overlay._embers[0]
	var hot: Color = overlay.ember_color_at(e0, 0.0)
	var mid: Color = overlay.ember_color_at(e0, 0.5)
	var cold: Color = overlay.ember_color_at(e0, 1.0)
	var hot_h: float = hot.h
	var cold_h: float = cold.h
	if hot_h > cold_h:
		_pass("hue cools the physical way round: %.3f (yellow-hot) -> %.3f (deep red)" % [hot_h, cold_h])
	else:
		_fail("hue runs %.3f -> %.3f — that is red warming into yellow, the inverted ramp" % [hot_h, cold_h])
	if hot.v > mid.v and mid.v > cold.v:
		_pass("brightness falls monotonically across the life (%.2f -> %.2f -> %.2f)" % [hot.v, mid.v, cold.v])
	else:
		_fail("brightness is not monotonically falling: %.2f -> %.2f -> %.2f" % [hot.v, mid.v, cold.v])
	if cold.s > hot.s:
		_pass("saturation deepens as it dies (%.2f -> %.2f) — a dying coal, not a pale one" % [hot.s, cold.s])
	else:
		_fail("saturation does not deepen: %.2f -> %.2f" % [hot.s, cold.s])

	## E-EMBER-03 (Director: "passar de amarelo pra vermelho vivo mais rápido").
	## The two ramps are eased in OPPOSITE directions, and a future retune that
	## quietly linearizes either one would restore the slow orange drift without
	## breaking anything else — so both halves get pinned, not just the endpoints.
	var early: Color = overlay.ember_color_at(e0, 0.30)
	var hue_span: float = float(e0["hue_hot"]) - float(e0["hue_cold"])
	var travelled: float = (float(e0["hue_hot"]) - early.h) / maxf(hue_span, 0.0001)
	if travelled >= 0.6:
		_pass("hue is %.0f%% of the way to red by 30%% of the life — the yellow is a flash, not a drift" % (travelled * 100.0))
	else:
		_fail("hue is only %.0f%% cooled at t=0.30 — that is the slow orange drift E-EMBER-03 removed" % (travelled * 100.0))
	if early.v >= hot.v * 0.8:
		_pass("brightness still %.0f%% of full at that point — the red arrives VIVID, not already dim" % (early.v / maxf(hot.v, 0.0001) * 100.0))
	else:
		_fail("brightness already down to %.0f%% at t=0.30 — the red arrives dim" % (early.v / maxf(hot.v, 0.0001) * 100.0))
	overlay.queue_free()
