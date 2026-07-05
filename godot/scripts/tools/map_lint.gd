## map_lint.gd — Headless tool to validate all .map.json files
##
## Scans res://maps/ and user://maps/ for *.map.json files, loads each through
## MapFileService with full registry, and reports pass/fail with error details.
## Exit code: 0 if all pass, 1 if any fail.

extends SceneTree

var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MAP LINT")
	print("=".repeat(70) + "\n")

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)

	# Hardcoded paths for testing; in production, could use project.godot detection
	var res_maps_dir = "res://maps"
	var user_maps_dir = "user://maps"
	
	var dirs = [
		{"path": res_maps_dir, "label": "res://maps"},
		{"path": user_maps_dir, "label": "user://maps"}
	]
	var total := 0
	var failed := 0

	for dir_info in dirs:
		var dir_path = dir_info["path"]
		var dir_label = dir_info["label"]
		var dir = DirAccess.open(dir_path)
		if dir == null:
			print("[LINT] (no directory: %s)" % dir_label)
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname != "." and fname != "..":
				if fname.ends_with(".map.json"):
					total += 1
					var full_path = dir_path.path_join(fname)
					var result = service.load_file(full_path)
					if result["ok"]:
						print("  ✓ %s" % full_path)
					else:
						failed += 1
						print("  ✗ %s" % full_path)
						for e in result["errors"]:
							print("      - %s" % e)
			fname = dir.get_next()

	print("\n%d checked, %d failed" % [total, failed])
	quit(0 if failed == 0 else 1)
