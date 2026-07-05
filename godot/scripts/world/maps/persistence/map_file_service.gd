## MapFileService — Load/save .map.json files with migration and validation
##
## Core responsibilities:
## 1. Load .map.json from res://maps/ or user://maps/ (user wins on ID collision)
## 2. Apply per-section migrations (registry delegates the heavy lifting)
## 3. Deserialize each section via its owner
## 4. Validate the result before returning
## 5. Save via serialize + re-emit unknown sections verbatim (tolerant round-trip)

class_name MapFileService
extends RefCounted

const FORMAT_TAG := "infiltraitor-map"
const CURRENT_SCHEMA_VERSION := 3

var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
var registry: Variant

func _init(p_registry) -> void:
	registry = p_registry

## Load a .map.json from disk. Returns {ok: bool, spec: Dictionary, errors: Array}.
## Never returns a half-loaded map: ok=false means spec is unusable, full errors list provided.
func load_file(path: String) -> Dictionary:
	var errors: Array = []

	if not FileAccess.file_exists(path):
		return {"ok": false, "spec": {}, "errors": ["File not found: %s" % path]}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "spec": {}, "errors": ["Could not open file: %s" % path]}
	
	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "spec": {}, "errors": ["Invalid JSON: %s" % path]}

	if parsed.get("format", "") != FORMAT_TAG:
		return {"ok": false, "spec": {}, "errors": ["Not an infiltraitor-map file (format tag mismatch): %s" % path]}

	var raw_sections: Dictionary = parsed.get("sections", {})
	var migrated_sections: Dictionary = {}

	# Migrate every section present in the file (known or unknown — tolerant round-trip)
	for section_id in raw_sections.keys():
		var raw = raw_sections[section_id]
		if raw == null:
			migrated_sections[section_id] = null
			continue
		var migrated = registry.migrate_section(section_id, raw)
		if migrated == null:
			errors.append("Section '%s' migration returned null — check logs for details" % section_id)
			continue
		migrated_sections[section_id] = migrated

	# Fill in defaults for known sections the file doesn't have
	for section_id in registry.known_sections():
		if not migrated_sections.has(section_id):
			var owner = registry.get_owner(section_id)
			migrated_sections[section_id] = owner.default_value.call()

	if not errors.is_empty():
		return {"ok": false, "spec": {}, "errors": errors}

	# Deserialize each known section into its runtime fragment; unknown sections stay raw dicts
	var spec: Dictionary = {
		"id": parsed.get("id", ""),
		"meta": parsed.get("meta", {}),
		"sections": {},
		"procedural": parsed.get("procedural", null),
		"patches": parsed.get("patches", []),
	}
	for section_id in migrated_sections.keys():
		var owner = registry.get_owner(section_id)
		if owner == null:
			spec["sections"][section_id] = migrated_sections[section_id]  # preserved verbatim
		else:
			spec["sections"][section_id] = owner.deserialize.call(migrated_sections[section_id])

	var validation = _validate(spec)
	if not validation["ok"]:
		return {"ok": false, "spec": {}, "errors": validation["errors"]}

	return {"ok": true, "spec": spec, "errors": []}

## Save a spec to disk. Serializes every known section via its owner;
## unknown/foreign sections carried on the spec are re-emitted verbatim (M3).
func save_file(path: String, spec: Dictionary) -> Dictionary:
	var sections_out: Dictionary = {}
	for section_id in spec.get("sections", {}).keys():
		var owner = registry.get_owner(section_id)
		var fragment = spec["sections"][section_id]
		if owner == null:
			sections_out[section_id] = fragment  # unknown: pass through untouched
		else:
			var serialized = owner.serialize.call(fragment)
			serialized["v"] = owner.current_version
			sections_out[section_id] = serialized

	var out := {
		"format": FORMAT_TAG,
		"schema_version": CURRENT_SCHEMA_VERSION,
		"id": spec.get("id", ""),
		"meta": spec.get("meta", {}),
		"sections": sections_out,
	}
	
	# Preserve procedural and patches as sibling keys (design fork: pre-processing, not content sections)
	if spec.has("procedural") and spec["procedural"] != null:
		out["procedural"] = spec["procedural"]
	if spec.has("patches") and spec["patches"] != null:
		out["patches"] = spec["patches"]

	# Ensure directory exists
	var file_dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(file_dir):
		var dir = DirAccess.open(file_dir.get_base_dir())
		if dir != null:
			dir.make_dir(file_dir.get_file())

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open for write: %s" % path]}
	file.store_string(JSON.stringify(out, "\t", false))
	file.close()
	return {"ok": true, "errors": []}

## Loud-fail structural validation. Extend as new sections register their own checks.
func _validate(spec: Dictionary) -> Dictionary:
	var errors: Array = []
	# Baseline checks
	if spec.get("id", "") == "":
		errors.append("Map has no id")
	return {"ok": errors.is_empty(), "errors": errors}
