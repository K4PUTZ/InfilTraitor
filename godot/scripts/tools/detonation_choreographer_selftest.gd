## E-WAVE — DetonationChoreographer selftest (EXPLOSION_REBUILD_MASTER_PLAN
## Task 5, 2026-08-07).
## Rodar: godot --headless --script res://godot/scripts/tools/detonation_choreographer_selftest.gd
##
## Boots the REAL PLAYGROUND map (Task 1b/4's own MinimalRoom scaffold),
## builds a REAL DetonationPlanBuilder.build_plan() result, then drives
## DetonationChoreographer._apply_wave() directly in the SAME order
## WAVE_TABLE fires them — proving the one thing a real-time capture cannot
## isolate on its own: that each wave's application logic is CORRECT (right
## cells, right values, right layer), separately from whether Godot's own
## SceneTimer scheduling fires them at the right real-world moment (that half
## is what the real windowed capture proves — timer scheduling is engine
## behavior, not this task's own code, so it is not re-proven here).
##
## Every expectation is checked against the REAL TileMapLayer/overlay state
## after each wave — never read back from the choreographer's own claim.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const DetonationChoreographerClass = preload("res://godot/scripts/systems/destruction/detonation_choreographer.gd")
const BombRegistryClass = preload("res://godot/scripts/systems/destruction/bomb_registry.gd")
const WallEdgeDataClass = preload("res://godot/scripts/world/wall_edge_data.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const SmokeSparkOverlayClass = preload("res://godot/scripts/overlays/smoke_spark_overlay.gd")

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
	print("E-WAVE — DETONATION CHOREOGRAPHER SELFTEST")
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
			var plan: Dictionary = DetonationPlanBuilderClass.build_plan(bomb_def, source_gu, ctx).waves
			var renderer = built["renderer"]
			var smoke_overlay := SmokeSparkOverlayClass.new()
			root.add_child(smoke_overlay)

			test_1_waves_apply_in_order(plan, renderer, smoke_overlay)
			test_2_work_queue(plan)
		else:
			_fail("could not load frag_grenade.json — nothing else can run")

	bake_config.enabled = saved_enabled

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ DETONATION CHOREOGRAPHER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DETONATION CHOREOGRAPHER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Mirrors detonation_plan_selftest.gd's own scaffold exactly.
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


func _pick_source_gu(built: Dictionary) -> Vector2i:
	var edge_registry = built["room"]._edge_registry
	for slice in edge_registry.all_slices():
		if slice.material == "concrete":
			return slice.gu_cell
	return Vector2i.ZERO


func test_1_waves_apply_in_order(plan: Dictionary, renderer, smoke_overlay) -> void:
	print("[1] Every wave, applied in WAVE_TABLE order, writes exactly what the plan says\n")
	var choreographer := DetonationChoreographerClass.new()
	var table: Array = DetonationChoreographerClass.WAVE_TABLE

	var destroy_erased := 0
	var expose_placed := 0
	var dented_placed := 0
	var cracked_placed := 0
	var soot_placed := 0
	var mismatches := 0

	for i in range(table.size()):
		var kind: String = table[i][0]
		var ring: int = table[i][1]
		choreographer._apply_wave(i, kind, ring, plan, renderer, smoke_overlay)

		match kind:
			"destroy":
				for entry in plan["destroy"].get(ring, []):
					var layer: TileMapLayer = renderer.get_layer(entry["level"])
					if layer == null or layer.get_cell_source_id(entry["cell"]) != -1:
						mismatches += 1
					else:
						destroy_erased += 1
					for exp in entry.get("expose", []):
						var elayer: TileMapLayer = renderer.get_layer(exp["level"])
						if elayer == null or elayer.get_cell_source_id(exp["cell"]) != exp["source_id"] \
								or elayer.get_cell_atlas_coords(exp["cell"]) != exp["atlas_coords"] \
								or elayer.get_cell_alternative_tile(exp["cell"]) != exp["alt"]:
							mismatches += 1
						else:
							expose_placed += 1
			"dented", "cracked", "soot":
				for entry in plan[kind].get(ring, []):
					var layer2: TileMapLayer = renderer.get_layer(entry["level"])
					if layer2 == null or layer2.get_cell_source_id(entry["cell"]) != entry["source_id"] \
							or layer2.get_cell_atlas_coords(entry["cell"]) != entry["atlas_coords"] \
							or layer2.get_cell_alternative_tile(entry["cell"]) != entry["alt"]:
						mismatches += 1
					else:
						match kind:
							"dented": dented_placed += 1
							"cracked": cracked_placed += 1
							"soot": soot_placed += 1

	if mismatches == 0:
		_pass("all %d waves applied — %d destroy erasures, %d exposed reveals, %d dented, %d cracked, %d soot cells all match the plan exactly" %
			[table.size(), destroy_erased, expose_placed, dented_placed, cracked_placed, soot_placed])
	else:
		_fail("%d cells did not match their plan entry after their wave applied" % mismatches)

	var smoke_total := 0
	for ring in plan["smoke"].keys():
		smoke_total += plan["smoke"][ring].size()
	if smoke_total > 0 and smoke_overlay._smoke.size() > 0:
		_pass("smoke waves queued %d real puffs on SmokeSparkOverlay (plan had %d smoke entries)" %
			[smoke_overlay._smoke.size(), smoke_total])
	elif smoke_total == 0:
		_fail("plan had no smoke entries at all — cannot prove the smoke wave path")
	else:
		_fail("plan had %d smoke entries but SmokeSparkOverlay queued none" % smoke_total)
	print("")


## E-RADIAL-01 (2026-08-09) — the queue is ordered by DISTANCE FROM THE
## EPICENTRE, not by category, asserted against a REAL PLAYGROUND plan.
##
## The assertion that used to live here checked that steps never ran backwards
## through WAVE_TABLE. That is now false BY DESIGN and had to be replaced rather
## than relaxed: WAVE_TABLE order is exactly what produced the Director's
## "soquinhos por categoria" — every destruction everywhere, then every dent
## everywhere, then every crack. Assertion 3 below is the one that pins the fix
## down, because it fails the moment the ordering goes back to categorical.
func test_2_work_queue(plan: Dictionary) -> void:
	print("[2] The plan flattens into one radially-ordered queue of single-cell steps\n")
	var queue: Array = DetonationChoreographerClass.flatten_plan(plan)
	var table: Array = DetonationChoreographerClass.WAVE_TABLE

	## 1. Nothing is dropped: every plan entry, plus every exposure reveal,
	##    becomes exactly one step.
	var expected := 0
	for pair in table:
		var entries: Array = plan.get(pair[0], {}).get(pair[1], [])
		expected += entries.size()
		if pair[0] == "destroy":
			for entry in entries:
				expected += entry.get("expose", []).size()
	if queue.size() == expected and queue.size() > 0:
		_pass("%d steps queued — every plan entry and every exposure reveal, nothing dropped" % queue.size())
	else:
		_fail("queue has %d steps, expected %d" % [queue.size(), expected])

	## 2. The front only ever expands. Sorted on the same key flatten_plan()
	##    sorted by, so this is the monotonicity of the real ordering, not a
	##    restatement of the sort call.
	var backwards := 0
	var last_key: float = -1000000.0
	for step in queue:
		var key: float = float(step["sort"])
		if key < last_key:
			backwards += 1
		last_key = key
	if backwards == 0:
		_pass("the front never travels inward — %d steps, monotonically expanding" % queue.size())
	else:
		_fail("%d steps run backwards toward the epicentre" % backwards)

	## 3. Categories INTERLEAVE instead of arriving in blocks. Measured as: how
	##    many times the queue switches kind. Under the old WAVE_TABLE ordering
	##    this was at most one switch per (kind, ring) bucket — about 15. Sorted
	##    radially it should be in the hundreds, because at any given radius
	##    whatever is physically there fires together.
	var switches := 0
	var prev := ""
	for step in queue:
		var kind := String(step["kind"])
		if kind != prev:
			switches += 1
		prev = kind
	if switches > table.size() * 3:
		_pass("%d category switches across the queue — effects interleave by radius, not in per-category blocks" % switches)
	else:
		_fail("only %d category switches: the queue is still arriving in blocks (WAVE_TABLE ordering?)" % switches)

	## 4. "Terminando no círculo mais largo" (Director) — the last steps really
	##    are the outermost ones, so the blast ends at its own rim.
	var first_r: float = float(queue[0]["entry"].get("r", 0.0))
	var last_r: float = float(queue[queue.size() - 1]["entry"].get("r", 0.0))
	if last_r > first_r:
		_pass("queue runs from r=%.1f at the epicentre out to r=%.1f at the rim" % [first_r, last_r])
	else:
		_fail("queue does not expand outward: first r=%.1f, last r=%.1f" % [first_r, last_r])

	## 5. The pacing rule — REPLACED 2026-08-09 (P-PLAY,
	##    PREDICTION_MASTER_PLAN Task 1), not relaxed. What stood here asserted
	##    three properties of the wall-clock deadline, and the third of them
	##    ("past the deadline the whole queue is due at once — the blast finishes
	##    on time at any frame rate") was pinning THE BUG: on a real PLAYGROUND
	##    blast that rule put 2 057 of 2 185 steps on a single frame, because one
	##    slow frame is all it takes to push `elapsed` past the deadline. The
	##    blast was three frames long and E-RADIAL-01's expanding front was
	##    invisible behind that.
	##
	##    The front advances by FRAME INDEX now. The four assertions below are
	##    the new contract, and 5b is the direct red-before-green for the
	##    collapse.
	var total: int = queue.size()
	var chor := DetonationChoreographerClass.new()
	var frames: int = chor.front_frames
	var band: float = chor.band_voxels
	var max_r: float = float(queue[queue.size() - 1]["sort"])

	## 5a. The blast is exactly `front_frames` frames long — and, the property
	##     that actually matters, it cannot be otherwise, because no elapsed
	##     time is an input at all.
	var simulated_frames := 0
	var cursor := 0
	while cursor < total and simulated_frames < frames * 4:
		var fr: float = DetonationChoreographerClass.front_radius_for(
			simulated_frames, frames, max_r, band)
		cursor = DetonationChoreographerClass.steps_within(queue, cursor, fr)
		simulated_frames += 1
	if simulated_frames == frames and cursor == total:
		_pass("the front drains all %d steps in exactly %d frames, with no wall-clock input" % [total, frames])
	else:
		_fail("drained %d/%d steps in %d frames, expected all of them in %d" %
			[cursor, total, simulated_frames, frames])

	## 5b. No single frame may swallow the blast. Under the retired rule frame 2
	##     took 94% of the queue on a real detonation.
	##
	##     THE BOUND IS DELIBERATELY LOOSE, and the reason matters more than the
	##     number. This assertion first shipped at 50% while `front_frames` was
	##     24, where an even split is 4.2% and the measured worst frame was
	##     13.5%. At `front_frames` = 5 (Director, 2026-08-09) an even split is
	##     20% and the measured worst frame is ~46% on the real map, 53.7% on
	##     this fixture — so a flat 50% fails a perfectly healthy sequence.
	##
	##     That is a defect in the threshold, not in the pacing. A radial front
	##     is INHERENTLY uneven: the front advances at a constant rate through
	##     SPACE (which is what makes it read as a shockwave), while the cell
	##     count in each band follows the annulus area, so the middle bands
	##     genuinely dominate. Pacing by equal WORK per frame would flatten this
	##     and was rejected — it would make the wave crawl through dense regions
	##     and jump through sparse ones, which is not what an explosion does.
	##
	##     So this stays a guard against the COLLAPSE (94% on one frame),
	##     anchored there rather than at any particular even-split multiple, and
	##     it is the secondary guard: **5a is the real one**, because the
	##     collapse's actual signature was a frame count that ignored
	##     `front_frames` entirely.
	var worst := 0
	var prev_cursor := 0
	cursor = 0
	var profile: Array[String] = []
	for f in range(frames):
		var fr2: float = DetonationChoreographerClass.front_radius_for(f, frames, max_r, band)
		cursor = DetonationChoreographerClass.steps_within(queue, cursor, fr2)
		worst = maxi(worst, cursor - prev_cursor)
		profile.append(str(cursor - prev_cursor))
		prev_cursor = cursor
	var worst_pct: float = 100.0 * float(worst) / float(total)
	if worst_pct < 70.0:
		_pass("per-frame profile [%s] of %d steps — heaviest frame %.1f%%, nowhere near the 94%% collapse" %
			[", ".join(profile), total, worst_pct])
	else:
		_fail("one frame carries %d/%d steps (%.1f%%) — the sequence is collapsing again" %
			[worst, total, worst_pct])

	## 5c. The front only ever moves outward. A front that retreated would
	##     re-apply cells an earlier frame already painted.
	var receded := 0
	var last_front: float = -1000000.0
	for f in range(frames):
		var fr3: float = DetonationChoreographerClass.front_radius_for(f, frames, max_r, band)
		if fr3 < last_front:
			receded += 1
		last_front = fr3
	if receded == 0:
		_pass("the front radius is monotonic across all %d frames" % frames)
	else:
		_fail("the front receded on %d frame(s)" % receded)

	## 5d. Banding is real: each frame's front lands on a band boundary, so the
	##     wave advances in discrete visible steps (the Director's "ondas na
	##     água", 2026-08-09) instead of a continuous smear. The final frame is
	##     INF by design — it flushes the remainder — and is excluded.
	var off_band := 0
	for f in range(frames - 1):
		var fr4: float = DetonationChoreographerClass.front_radius_for(f, frames, max_r, band)
		if not is_equal_approx(fr4, floor(fr4 / band) * band):
			off_band += 1
	if off_band == 0:
		_pass("every frame's front sits on a %.1f-voxel band boundary — the wave advances in steps" % band)
	else:
		_fail("%d frame(s) landed off the band grid" % off_band)
	print("")
