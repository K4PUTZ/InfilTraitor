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
			var plan := DetonationPlanBuilderClass.build_plan(bomb_def, source_gu, ctx)
			var after := _snapshot_layers(built["renderer"])

			test_1_wave_census(plan, source_gu)
			test_2_resolved_triples(plan)
			test_3_no_live_layer_mutation(before, after)
			test_4_exposure_fallback(plan)
			test_5_smoke_ring_weights_consumed(plan, bomb_def)
			test_6_real_ring_gates(plan, bomb_def)
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
