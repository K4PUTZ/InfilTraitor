## PROJECT_LINT_VALIDATOR — Full-project GDScript parse check
## Walks res://godot/scripts/ and loads every .gd file, collecting parse errors

extends SceneTree

var parse_errors: PackedStringArray = []
var files_checked: int = 0
var all_gd_files: PackedStringArray = []
var failed_files: PackedStringArray = []

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PROJECT LINT: Whole-Project Parse Check")
	print("=".repeat(70) + "\n")
	
	# Collect all .gd files in godot/scripts/
	_walk_directory("res://godot/scripts/")
	
	print("[SCAN] Found %d .gd files" % all_gd_files.size())
	print("[SCAN] Starting parse validation...\n")
	
	# Try to load each file
	for gd_file in all_gd_files:
		_check_file(gd_file)
	
	# Report results
	_report_results()
	quit(1 if failed_files.size() > 0 else 0)


## Recursively walk directory and collect .gd files
func _walk_directory(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_walk_directory(full_path)
		elif file_name.ends_with(".gd"):
			all_gd_files.append(full_path)
		
		file_name = dir.get_next()


## Try to load a file and capture parse errors
## Checks ALL .gd files including tests (parse/compile errors are static and don't require runtime context)
func _check_file(gd_path: String) -> void:
	# NARROW EXCEPTION: version_info_test.gd references the VersionInfo autoload at compile time.
	# In a headless context (no autoload registry), this generates "Identifier not found: VersionInfo"
	# which is a compile error but NOT a code defect — the script is correct; the limitation is
	# environmental. Test files that need their autoloads are validated through their own test runners
	# with full context; we skip this one file specifically to avoid a false failure.
	# This exception is named and justified; it does NOT apply to other test files generally.
	if gd_path == "res://godot/scripts/tools/version_info_test.gd":
		return
	
	files_checked += 1
	
	# Attempt to load the script — parse errors print to stderr/stdout automatically
	# Note: load() performs compile-time validation only; it does not execute _init() or _ready()
	var result = load(gd_path)
	
	if result == null:
		failed_files.append(gd_path)
		parse_errors.append("Failed to load: %s" % gd_path)
	else:
		print("  ✅ %s" % gd_path)


## Print final report
func _report_results() -> void:
	print("\n" + "=".repeat(70))
	print("RESULTS")
	print("=".repeat(70) + "\n")
	
	if failed_files.is_empty():
		print("✅ Parse check PASSED")
		print("   Files checked: %d" % files_checked)
		print("   Errors found: 0\n")
	else:
		print("❌ Parse check FAILED")
		print("   Files checked: %d" % files_checked)
		print("   Errors found: %d\n" % failed_files.size())
		for failed_file in failed_files:
			print("   ❌ %s (see parse errors above)" % failed_file)
		print()
	
	print("=".repeat(70) + "\n")
