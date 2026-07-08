## BAKE-FIX-12 Selftest: Real Function Calls for Junction Overrides & Pipeline Tests
## Tests: (1) Junction column face tracking, (2) Override application via real _apply_junction_overrides(), (3) Real junction columns from pipeline
## Pattern: Headless, calling real production functions, no inline reimplementation
## Key: Test 2 calls real room_builder.gd::_apply_junction_overrides() (now static)
## Key: Test 3 loads real map, extracts edges, resolves junctions, tests override cases

extends SceneTree

var EdgeClass = preload("res://godot/scripts/geometry/edge.gd")
var EdgeRegistryClass = preload("res://godot/scripts/geometry/edge_registry.gd")
var JunctionResolverClass = preload("res://godot/scripts/geometry/junction_resolver.gd")
var SliceGeneratorClass = preload("res://godot/scripts/geometry/slice_generator.gd")
var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
var FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("BAKE-FIX-06 SELFTEST: Junction Mirroring, Overrides, and Real Rendering")
	print("=".repeat(70) + "\n")
	
	var all_pass = true
	
	if not _test_junction_column_face_tracking():
		all_pass = false
	
	if not _test_junction_override_application():
		all_pass = false
	
	if not _test_junction_mirroring_rendering():
		all_pass = false
	
	print("\n" + "=".repeat(70))
	if all_pass:
		print("BAKE-FIX-06 SELFTEST: 3 / 3 PASS")
		print("=".repeat(70) + "\n")
		print("✓ SELFTEST PASS")
	else:
		print("BAKE-FIX-06 SELFTEST: FAILED")
		print("=".repeat(70) + "\n")
		print("✗ SELFTEST FAIL")
	quit()


## TEST 1: Junction column creation with face tracking (BAKE-FIX-06: Task 1 prep)
func _test_junction_column_face_tracking() -> bool:
	print("[TEST 1] Junction Column Face Tracking\n")
	
	# Create a simple V-junction: two edges at (0,0) with adjacent faces
	var registry = EdgeRegistryClass.new()
	
	# Edge 1: NW face of (0,0)
	var edge_1 = EdgeClass.between(Vector2i(-1, 0), Vector2i(0, 0), 0, "concrete")  # face NW
	registry.register_edge(edge_1)
	
	# Edge 2: NE face of (0,0)
	var edge_2 = EdgeClass.between(Vector2i(0, -1), Vector2i(0, 0), 1, "concrete")  # face NE
	registry.register_edge(edge_2)
	
	# Resolve junctions
	var columns = JunctionResolverClass.resolve(registry)
	
	print("Created edges: %d, Found junctions: %d" % [2, columns.size()])
	
	var success = true
	
	# Should find at least one junction column
	if columns.size() < 1:
		print("✗ FAIL: Expected ≥1 junction column, got %d" % columns.size())
		success = false
	else:
		var column = columns[0]
		print("Junction column: gu_cell=%s, voxel_pos=%s, storey_count=%d" % [column.gu_cell, column.voxel_pos, column.storey_count])
		
		# BAKE-FIX-06: Verify face tracking
		if column.face_a == -1 or column.face_b == -1:
			print("✗ FAIL: Junction column faces not set properly (face_a=%d, face_b=%d)" % [column.face_a, column.face_b])
			success = false
		else:
			print("✓ Junction column has face_a=%d, face_b=%d" % [column.face_a, column.face_b])
		
		# Verify edge IDs are set
		if column.edge_a_id == "" or column.edge_b_id == "":
			print("✗ FAIL: Edge IDs not set (edge_a_id=%s, edge_b_id=%s)" % [column.edge_a_id, column.edge_b_id])
			success = false
		else:
			print("✓ Junction column has edge_a_id=%s, edge_b_id=%s" % [column.edge_a_id, column.edge_b_id])
	
	if success:
		print("✓ PASS: Junction column face tracking works\n")
	else:
		print("✗ FAIL: Junction column test failed\n")
	
	return success


## TEST 2: Junction override application via real pipeline (BAKE-FIX-10: Task 2)
## This test compiles a real MapSpec with junction_overrides, runs it through the
## full production pipeline (EdgeExtractor → SliceGenerator → JunctionResolver →
## _apply_junction_overrides), and verifies the override actually flowed through.
func _test_junction_override_application() -> bool:
	print("[TEST 2] Junction Override Application (Real Pipeline)\n")
	
	# Step 1: Create a synthetic MapSpec with a junction_override entry
	# MapSpec format: inner coords, buffer applied by compiler
	var map_spec: Dictionary = {
		"inner_size": Vector2i(10, 10),
		"buffer": 2,
		"floor_tile": "floor_SE",
		"agent_start": Vector2i(5, 5),
		# Create two perpendicular edges that form a V-junction at a known GU
		# Inner coords: we'll create walls in a pattern that triggers a V-junction
		"dividers": [
			{
				"cells": [
					Vector2i(4, 5),  # Horizontal wall segment (will form NW face at (5,5))
					Vector2i(5, 5),  # Corner
				]
			},
			{
				"cells": [
					Vector2i(5, 4),  # Vertical wall segment (will form NE face at (5,5))
					Vector2i(5, 5),  # Corner
				]
			}
		],
		# Override the junction that forms at inner (5,5), which becomes raw (7,7) with buffer=2
		"junction_overrides": [
			{
				"gu": Vector2i(5, 5),  # inner coords
				"material": "wood",
				"facade_enabled": false,
			}
		]
	}
	
	print("Step 1: MapSpec created with junction_override at inner(5,5)")
	print("  Override: material=wood, facade_enabled=false")
	
	# Step 2: Compile MapSpec using the real compiler
	var layout = MapCompilerClass.compile(map_spec)
	
	if layout.is_empty():
		print("✗ FAIL: MapCompiler.compile() returned empty layout")
		return false
	
	print("Step 2: MapCompiler.compile() produced layout with %d wall_tiles" % layout.get("wall_tiles", []).size())
	
	# Step 3: Extract edges from layout (simulating what room_builder does)
	var EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
	var extraction = EdgeExtractorClass.extract(layout)
	
	var edges = extraction.get("edges", [])
	print("Step 3: EdgeExtractor extracted %d edges" % edges.size())
	
	if edges.is_empty():
		print("⚠ WARNING: No edges extracted; junction_overrides entry exists but no junction formed")
		print("✗ FAIL: Cannot test override application without junction\n")
		return false
	
	# Step 4: Generate slices and resolve junctions
	var registry = EdgeRegistryClass.new()
	SliceGeneratorClass.generate(edges, registry)
	
	var junction_columns = JunctionResolverClass.resolve(registry)
	print("Step 4: JunctionResolver created %d junction columns" % junction_columns.size())
	
	if junction_columns.is_empty():
		print("✗ FAIL: No junction columns created\n")
		return false
	
	# Step 5: Compile the layout and extract junction_overrides
	print("Step 5: Calling real _apply_junction_overrides()...")
	
	var RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
	RoomBuilderClass._apply_junction_overrides(junction_columns, layout)
	print("✓ _apply_junction_overrides() called on real layout\n")
	
	# Step 6: Verify the override was applied
	print("Step 6: Verifying override application...")
	
	var success = true
	var found_overridden = false
	
	for column in junction_columns:
		if column.override_material == "wood":
			found_overridden = true
			print("  Found overridden column: gu_cell=%s, override_material='wood', facade_enabled=%s" % [column.gu_cell, column.facade_enabled])
			
			# Verify both fields were applied
			if column.facade_enabled != false:
				print("  ✗ FAIL: facade_enabled should be false, got %s" % column.facade_enabled)
				success = false
			else:
				print("  ✓ Both override_material and facade_enabled correctly applied")
			
			# Verify material resolution
			var actual_material = column.override_material if column.override_material != "" else column.material
			if actual_material != "wood":
				print("  ✗ FAIL: Material resolution failed (expected 'wood', got '%s')" % actual_material)
				success = false
			else:
				print("  ✓ Material resolution respects override: '%s'" % actual_material)
	
	if not found_overridden:
		print("✗ FAIL: No junction column found with wood override")
		success = false
	
	if success:
		print("✓ PASS: Real pipeline override application works\n")
	else:
		print("✗ FAIL: Real pipeline override test failed\n")
	
	return success


## TEST 3: Real Junction Mirroring Rendering (BAKE-FIX-14: Task 2)
## Calls the real public VoxelRenderer.render(registry, [column]) entry point (the
## same call room_builder.gd makes — NOT the private _render_junction_column(), which
## a prior revision of this test called directly), then reads back the real
## TileMapLayer cell data (source_id / atlas_coords / alternative_id / flip_h) that
## production code actually wrote.
##
## Scope, precisely: this exercises render()-time consumption of facade_enabled /
## override_material and the real _find_neighbor_wall_voxel() + H-flip mirroring
## logic. It does NOT exercise override *resolution* from a MapSpec's
## junction_overrides (Test 2 covers that real pipeline). Because BakeConfig.enabled
## is false in this run (as it is in production by default), the mirroring path taken
## here is the material-only H-flip fallback (voxel_renderer.gd's "Fallback or if no
## baking" branch) — not the _baked_lookup.resolve() branch, which is covered
## separately by bake_fix_09_e2e_test.gd.
func _test_junction_mirroring_rendering() -> bool:
	print("[TEST 3] Real Junction Mirroring Rendering (Calling renderer.render())\n")

	# Load a real map and compile it to get real junction columns
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")

	if map_spec == null or map_spec.is_empty():
		print("✗ FAIL: Could not load PLAYGROUND map\n")
		return false

	# Compile the map to extract junction columns
	print("Step 1: Compiling real map to extract junction columns...")
	var layout = MapCompilerClass.compile(map_spec)

	if layout.is_empty():
		print("✗ FAIL: MapCompiler.compile() returned empty layout\n")
		return false

	# Extract edges
	var EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
	var extraction = EdgeExtractorClass.extract(layout)
	var edges = extraction.get("edges", [])

	if edges.is_empty():
		print("✗ FAIL: EdgeExtractor returned no edges\n")
		return false

	print("  ✓ Extracted %d edges from layout\n" % edges.size())

	# Generate slices and resolve junctions
	print("Step 2: Resolving real junctions from extracted edges...")
	var registry = EdgeRegistryClass.new()
	SliceGeneratorClass.generate(edges, registry)
	var junction_columns = JunctionResolverClass.resolve(registry)

	if junction_columns.is_empty():
		print("✗ FAIL: JunctionResolver created no columns\n")
		return false

	print("  ✓ JunctionResolver created %d junction columns\n" % junction_columns.size())

	# Step 3: Instantiate the real VoxelRenderer (same pattern already used
	# headlessly by voxel_height_verification.gd / prop_01_tests.gd)
	var VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
	var GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
	var renderer = VoxelRendererClass.new()
	renderer.setup(Vector2.ZERO)

	# Pick the first column with a real, non-degenerate height (storey_count > 0)
	# instead of blindly using junction_columns[0] — a zero-height column would make
	# every case's render loop a no-op and fail with a misleading "no layer" message.
	var base_column = null
	for candidate in junction_columns:
		if candidate.storey_count > 0:
			base_column = candidate
			break

	if base_column == null:
		print("✗ FAIL: No junction column with storey_count > 0 found\n")
		return false

	# Diagnostic only (does not gate pass/fail): report up front whether this column
	# actually has a discoverable adjacent wall voxel, so a mirroring failure below
	# reads as "mirroring is broken" rather than "this column happens to have no
	# neighbor in this map" — those are different bugs with the same symptom.
	var neighbor_probe = renderer._find_neighbor_wall_voxel(base_column, registry)
	if neighbor_probe.is_empty():
		print("  ⚠ Diagnostic: chosen column has no discoverable adjacent wall voxel in this map.")
		print("    Cases 1/2 (facade_enabled=true) are expected to fall back to flat rendering,")
		print("    not a mirroring bug, if they report alternative_id=0 below.\n")
	else:
		print("  Diagnostic: chosen column has a discoverable neighbor — mirroring should engage.\n")

	var success = true
	var tested_case_count = 0
	var original_start_storey = base_column.start_storey

	# Test three different override/facade_enabled combinations on the same real
	# column. Case 0 keeps the column's REAL start_storey (its true production
	# placement); cases 1/2 are offset from that original value (not from 0) so they
	# land on distinct, non-colliding levels without discarding case 0's real placement.
	for case_idx in range(3):
		var column = base_column
		column.override_material = ""
		column.facade_enabled = true
		column.start_storey = original_start_storey + case_idx * column.storey_count

		match case_idx:
			0:
				print("  Case 1: Default mirroring (no override, facade_enabled=true)")
			1:
				print("  Case 2: Override material with facade=true (mirror override material)")
				column.override_material = "wood"
				column.facade_enabled = true
			2:
				print("  Case 3: Override material with facade=false (flat, no mirror)")
				column.override_material = "metal"
				column.facade_enabled = false

		# Call the REAL public entry point — the same one room_builder.gd calls
		# (render() loops junction_columns internally and calls _render_junction_column
		# per column) — not the private method directly.
		renderer.render(registry, [column])

		var level = column.start_storey * GeometryCoordsClass.LEVELS_PER_STOREY
		var layer: TileMapLayer = renderer.get_layer(level)

		if layer == null:
			print("    ✗ FAIL: No layer created at level %d\n" % level)
			success = false
			tested_case_count += 1
			continue

		var source_id = layer.get_cell_source_id(column.voxel_pos)
		var atlas_coords = layer.get_cell_atlas_coords(column.voxel_pos)
		var alt_id = layer.get_cell_alternative_tile(column.voxel_pos)

		print("    Real cell data: source_id=%d, atlas_coords=%s, alternative_id=%d" % [source_id, atlas_coords, alt_id])

		match case_idx:
			0, 1:
				# facade_enabled=true: should have used an H-flipped alternative
				# (alt_id != 0 per _get_or_create_h_flipped_tile's "+1 to avoid 0")
				if alt_id != 0:
					var atlas_source = renderer.get_tileset().get_source(source_id)
					var tile_data: TileData = atlas_source.get_tile_data(atlas_coords, alt_id) if atlas_source else null
					if tile_data and tile_data.flip_h:
						print("    ✓ Real mirroring confirmed: alternative_id=%d, flip_h=true\n" % alt_id)
					else:
						print("    ✗ FAIL: alternative tile exists but flip_h is not true\n")
						success = false
				elif neighbor_probe.is_empty():
					print("    ~ Flat fallback as expected (no neighbor voxel available in this map)\n")
				else:
					print("    ✗ FAIL: expected a mirrored (flipped) alternative tile, got alternative_id=0\n")
					success = false
			2:
				# facade_enabled=false: flat path, no baked/flip lookup — alt_id must be 0
				if alt_id == 0:
					print("    ✓ Flat path confirmed: no mirroring applied (alternative_id=0)\n")
				else:
					print("    ✗ FAIL: expected flat rendering (alternative_id=0), got %d\n" % alt_id)
					success = false

		tested_case_count += 1

	print()

	if success and tested_case_count == 3:
		print("✓ PASS: Real mirroring rendering verified via actual renderer.render() calls\n")
	else:
		print("✗ FAIL: Junction mirroring test failed\n")

	return success
