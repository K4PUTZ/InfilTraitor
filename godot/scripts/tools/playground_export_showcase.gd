## playground_export_showcase.gd — Generate showcase map PLAYGROUND (28×18) with 6 districts
## Runs headless: godot --headless --script godot/scripts/tools/playground_export_showcase.gd

extends SceneTree

const MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
const MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
const MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

func _init() -> void:
	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)
	
	print("\n[PLAYGROUND-02] Generating showcase map (28×18, 6 districts)...")
	
	# Build the file_spec with 6 districts
	var file_spec: Dictionary = {
		"id": "PLAYGROUND",
		"meta": {
			"title": "Showcase Map — Districts A–F",
			"description": "Material gallery, theme row, junction museum, blocker field, crate yard, vignettes",
			"pending_districts": ["G"]
		},
		"sections": {
			"board": {
				"inner_size": [28, 18],
				"buffer": 1,
				"floor_tile": "floor_SE"
			},
			"actors": {
				"agent_start": [14, 16],
				"guards": [
					[  # Patrol through districts C-F
						[5, 5],
						[15, 5],
						[15, 15],
						[5, 15]
					]
				]
			},
			"blocks": {
				"items": _build_districts()["blocks"]
			},
			"props": {
				"items": _build_districts()["voxel_props"]
			},
			"legacy_compiler": {
				"wall_height": 1,
				"access_points": [],
				"dividers": []
			}
		}
	}
	
	var file_path = "res://maps/PLAYGROUND.map.json"
	
	# Save the map
	var save_result = service.save_file(file_path, file_spec)
	if not save_result["ok"]:
		push_error("[EXPORT] Failed to save '%s': %s" % [file_path, save_result["errors"]])
		quit(1)
		return
	
	print("[EXPORT] Saved to %s" % file_path)
	
	# Reload and verify
	var file_source = FileMapSourceClass.new()
	var reloaded_spec = file_source.get_runtime_spec("PLAYGROUND")
	if reloaded_spec.is_empty():
		push_error("[EXPORT] Round-trip: failed to reload PLAYGROUND")
		quit(1)
		return
	
	# Verify compile
	var layout = MapCompilerClass.compile(reloaded_spec)
	if layout.is_empty():
		push_error("[EXPORT] Compile failed for reloaded PLAYGROUND")
		quit(1)
		return
	
	var blocked_count = layout.get("blocked_cells", []).size()
	var voxel_props = layout.get("voxel_prop_instances", []).size()
	
	print("[EXPORT] ✓ Round-trip verified")
	print("  - inner_size: %s" % [reloaded_spec.get("inner_size", Vector2i.ZERO)])
	print("  - blocked_cells: %d" % blocked_count)
	print("  - voxel_props: %d" % voxel_props)
	print("[EXPORT] ✓ All exports succeeded")
	
	quit(0)

## Build all 6 districts as blocks and voxel_props
func _build_districts() -> Dictionary:
	var blocks: Array = []
	var voxel_props: Array = []
	
	# District A: Material Gallery — 4 parallel wall runs (5 GU each, 2 storeys)
	# cols 0-3, rows 0-4 (5×5 area)
	var materials = ["concrete", "stone", "wood", "metal"]
	for mat_idx in range(4):
		var col = mat_idx * 1 + 1  # 1, 2, 3, 4
		for run_idx in range(5):
			var row = run_idx
			blocks.append({
				"gu": [col, row],
				"material": materials[mat_idx],
				"storeys": 2
			})
	
	# District B: Theme Row — 1 stone run (5 GU, 2 storeys)
	# cols 6-11, rows 0-4
	for idx in range(5):
		blocks.append({
			"gu": [6 + idx, 0],
			"material": "stone",
			"storeys": 2
		})
	
	# District C: Junction Museum — corner/junction clusters
	# cols 12-20, rows 0-4
	# L-shape: 3 cells in row 1, 2 cells in row 0
	blocks.append({"gu": [13, 1], "material": "concrete", "storeys": 1})
	blocks.append({"gu": [13, 2], "material": "concrete", "storeys": 1})
	blocks.append({"gu": [14, 1], "material": "concrete", "storeys": 1})
	blocks.append({"gu": [15, 1], "material": "concrete", "storeys": 1})
	
	# T-shape: 3 across row 0, 1 below center
	blocks.append({"gu": [17, 0], "material": "stone", "storeys": 1})
	blocks.append({"gu": [18, 0], "material": "stone", "storeys": 1})
	blocks.append({"gu": [19, 0], "material": "stone", "storeys": 1})
	blocks.append({"gu": [18, 1], "material": "stone", "storeys": 1})
	
	# X-shape (4 blocks meeting)
	blocks.append({"gu": [21, 1], "material": "wood", "storeys": 1})
	blocks.append({"gu": [22, 1], "material": "wood", "storeys": 1})
	blocks.append({"gu": [21, 2], "material": "wood", "storeys": 1})
	blocks.append({"gu": [22, 2], "material": "wood", "storeys": 1})
	
	# District D: Blocker Field — mixed heights (left side, rows 5-17)
	# Single-storey blocks scattered
	blocks.append({"gu": [1, 6], "material": "concrete", "storeys": 1})
	blocks.append({"gu": [2, 6], "material": "concrete", "storeys": 1})
	blocks.append({"gu": [3, 6], "material": "concrete", "storeys": 1})
	
	# 2×2 cluster
	blocks.append({"gu": [1, 9], "material": "stone", "storeys": 1})
	blocks.append({"gu": [2, 9], "material": "stone", "storeys": 1})
	blocks.append({"gu": [1, 10], "material": "stone", "storeys": 1})
	blocks.append({"gu": [2, 10], "material": "stone", "storeys": 1})
	
	# 1×3 row
	blocks.append({"gu": [5, 12], "material": "wood", "storeys": 1})
	blocks.append({"gu": [6, 12], "material": "wood", "storeys": 1})
	blocks.append({"gu": [7, 12], "material": "wood", "storeys": 1})
	
	# 2-storey monolith
	blocks.append({"gu": [5, 14], "material": "metal", "storeys": 2})
	
	# Single-storey block adjacent to monolith (for storey-gap visual verification)
	blocks.append({"gu": [6, 14], "material": "concrete", "storeys": 1})
	
	# District E: Crate Yard — voxel props (crate_full)
	# Two crates: cover lane pair (Finding C allows this)
	voxel_props.append({
		"def": "crate_full",
		"gu": [12, 12],
		"storey": 0,
		"vox_offset": [0, 0],
		"rot": 0
	})
	voxel_props.append({
		"def": "crate_full",
		"gu": [14, 12],
		"storey": 0,
		"vox_offset": [0, 0],
		"rot": 0
	})
	
	# District F: Vignettes — dividers/rooms (bottom, rows 15-17)
	# Dividers are in legacy_compiler, not blocks
	# For now, leave empty; could add blocks as boundary markers
	
	return {
		"blocks": blocks,
		"voxel_props": voxel_props
	}
