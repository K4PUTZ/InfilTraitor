## VersionInfo — Single source of truth for game version
##
## Reads VERSION file at startup and exposes version components.
## Autoload singleton: automatically initialized at engine boot.

extends Node

var version_string: String = "0.0.0-unknown"
var major: int = 0
var minor: int = 0
var patch: int = 0


func _ready() -> void:
	_load_version()
	print("[INFILTRAITOR] Version %s" % version_string)
	_set_window_title()


## Load version from canonical VERSION file
func _load_version() -> void:
	var version_file = FileAccess.open("res://VERSION", FileAccess.READ)
	if version_file == null:
		push_error("[VersionInfo] VERSION file not found at res://VERSION")
		version_string = "0.0.0-unknown"
		return

	var file_content = version_file.get_as_text().strip_edges()
	if file_content.is_empty():
		push_error("[VersionInfo] VERSION file is empty")
		version_string = "0.0.0-unknown"
		return

	# Parse MAJOR.MINOR.PATCH format
	var parts = file_content.split(".")
	if parts.size() != 3:
		push_error("[VersionInfo] VERSION format invalid (expected MAJOR.MINOR.PATCH): %s" % file_content)
		version_string = "0.0.0-unknown"
		return

	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		push_error("[VersionInfo] VERSION contains non-numeric components: %s" % file_content)
		version_string = "0.0.0-unknown"
		return

	major = int(parts[0])
	minor = int(parts[1])
	patch = int(parts[2])
	version_string = file_content


## Set OS window title to include version
func _set_window_title() -> void:
	DisplayServer.window_set_title("INFILTRAITOR v%s" % version_string)
