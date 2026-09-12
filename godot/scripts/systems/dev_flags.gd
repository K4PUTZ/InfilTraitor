## DevFlags — the one seam every diagnostic switch is asked through.
##
## DIAG-01. Autoload singleton, registered as `DevFlags`.
##
## WHY THIS EXISTS
##
## The project's diagnostic surface is ~200 `OS.get_environment("INFILTRAITOR_*")`
## reads. That works perfectly on desktop and is **completely inert inside an
## APK**: environment variables do not reach an Android application. So on the
## one platform the game actually ships to, `INFILTRAITOR_EVENT_FRAMES` — the
## instrument that reports the worst frame of a detonation, which is the number
## the whole device track exists to obtain — could not be turned on at all, and
## the build on the phone was a black box.
##
## RESOLUTION ORDER, and why it is this order:
##
##   1. `OS.get_environment("INFILTRAITOR_<name>")`
##   2. the overrides file (see below)
##   3. the caller's default
##
## The environment comes FIRST so that desktop behaviour is bit-identical to
## what it was before this file existed. Every capture harness, every
## `INFILTRAITOR_X=1 godot ...` invocation in the docs, and every selftest keeps
## working unchanged, and a stale flags file on a dev machine can never quietly
## override what a developer typed on the command line.
##
## THE OVERRIDES FILE — `/sdcard/Android/data/<package>/files/dev_flags.cfg`
##
## Measured 2026-09-12 on a Moto G04s, against the three alternatives:
##
##  - An intent extra (`am start --esa command_line_args …`) is **accepted by
##    Android and never reaches Godot** — `InitEngine with params:` came back
##    byte-identical and `--verbose` produced no extra output. Dead end.
##  - `adb push` to `user://` needs a **debuggable** build, and a debug template
##    is not a release template — it would change the very performance being
##    measured.
##  - `command_line/extra_args` in the export preset works, but is baked at
##    export time: ~40 s per flag change.
##
## The app's own EXTERNAL files directory has none of those problems. Android
## 11+ grants every app free access to it, `adb push` writes there in
## milliseconds with no declared permission, and the APK being measured stays
## the APK that ships. That is the whole reason this class reads a file at all.
##
## FORMAT — one `KEY=VALUE` per line, `#` comments and blank lines ignored. The
## KEY is the flag name WITHOUT the `INFILTRAITOR_` prefix:
##
##     # measure one detonation
##     EVENT_FRAMES=1
##     MAP=PLAYGROUND
##
## ⚠️ THE FILE IS READ ONCE, AT BOOT. Pushing a new one mid-run changes nothing
## until the next launch — deliberate, so a flag cannot change underneath a
## measurement that is already running.

extends Node

## Flag name -> raw string value, from the overrides file only. The environment
## is never copied in here; it is consulted live, so this dictionary can always
## be printed as "what the FILE asked for".
var _overrides: Dictionary = {}

## The file the overrides came from, or "" when none was found. Reported in the
## boot line so a device run's log says which channel was in play.
var _source: String = ""

const FLAG_PREFIX: String = "INFILTRAITOR_"
const FLAGS_BASENAME: String = "dev_flags.cfg"


func _ready() -> void:
	_load_overrides()
	if _overrides.is_empty():
		## Deliberately quiet-but-present: a device log that says nothing about
		## DevFlags is indistinguishable from a build that has no DevFlags.
		print("[DevFlags] no overrides (looked in: %s)"
			% ", ".join(_candidate_paths()))
		return
	var pairs: PackedStringArray = PackedStringArray()
	for key in _overrides:
		pairs.append("%s=%s" % [key, _overrides[key]])
	pairs.sort()
	print("[DevFlags] %d override(s) from %s — %s"
		% [_overrides.size(), _source, ", ".join(pairs)])


## True when the flag resolves to "1". The project's standing convention is
## `== "1"`, not "any non-empty value", and this preserves it exactly.
func on(flag_name: String) -> bool:
	return value(flag_name, "") == "1"


## The flag's raw string value, or `fallback` when it is set nowhere.
func value(flag_name: String, fallback: String = "") -> String:
	var from_env: String = OS.get_environment(FLAG_PREFIX + flag_name)
	if not from_env.is_empty():
		return from_env
	if _overrides.has(flag_name):
		return String(_overrides[flag_name])
	return fallback


## The flag as an integer. A value that is not a valid integer is a
## configuration error, not a zero — it is reported and the fallback stands.
func num(flag_name: String, fallback: int = 0) -> int:
	var raw: String = value(flag_name, "")
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		push_warning("[DevFlags] %s=%s is not an integer; using %d"
			% [flag_name, raw, fallback])
		return fallback
	return int(raw)


## The flag as a float, with the same contract as `num()`.
func real(flag_name: String, fallback: float = 0.0) -> float:
	var raw: String = value(flag_name, "")
	if raw.is_empty():
		return fallback
	if not raw.is_valid_float():
		push_warning("[DevFlags] %s=%s is not a float; using %f"
			% [flag_name, raw, fallback])
		return fallback
	return float(raw)


## Where the overrides came from — "" when no file was found. For the harness
## and for `dev_flags_selftest`.
func source_path() -> String:
	return _source


## Every location an overrides file is accepted from, most specific first.
##
## The Android path is DERIVED, never hardcoded: `OS.get_user_data_dir()` is
## `/data/user/0/<package>/files` there, so the package name is already in hand
## and the external twin is `/sdcard/Android/data/<package>/files`. Hardcoding
## the package would silently stop working the moment `package/unique_name`
## changes in the export preset.
func _candidate_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if OS.get_name() == "Android":
		var package: String = _android_package_name()
		if not package.is_empty():
			paths.append("/sdcard/Android/data/%s/files/%s" % [package, FLAGS_BASENAME])
	paths.append("user://" + FLAGS_BASENAME)
	paths.append("res://" + FLAGS_BASENAME)
	return paths


func _android_package_name() -> String:
	## `/data/user/0/com.example.infiltraitor/files` -> `com.example.infiltraitor`
	var parts: PackedStringArray = OS.get_user_data_dir().split("/")
	for i in range(parts.size()):
		if parts[i] == "files" and i > 0:
			return parts[i - 1]
	## Not a shape we recognise. Loud, because the external channel is the only
	## way to configure a diagnostic on a device, and silently losing it would
	## look like "the flag did nothing".
	push_warning("[DevFlags] could not derive the package name from '%s'; the "
		% OS.get_user_data_dir()
		+ "external flags file will not be found")
	return ""


func _load_overrides() -> void:
	for path in _candidate_paths():
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning("[DevFlags] %s exists but could not be opened (%d)"
				% [path, FileAccess.get_open_error()])
			continue
		_parse(file.get_as_text())
		_source = path
		return


func _parse(text: String) -> void:
	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var split_at: int = line.find("=")
		if split_at <= 0:
			push_warning("[DevFlags] ignoring malformed line: %s" % line)
			continue
		var key: String = line.substr(0, split_at).strip_edges()
		var val: String = line.substr(split_at + 1).strip_edges()
		## Tolerate a full `INFILTRAITOR_EVENT_FRAMES=1` line — that is what the
		## docs and every existing shell invocation look like, so a copied line
		## should work rather than silently name a flag nothing reads.
		if key.begins_with(FLAG_PREFIX):
			key = key.substr(FLAG_PREFIX.length())
		_overrides[key] = val
