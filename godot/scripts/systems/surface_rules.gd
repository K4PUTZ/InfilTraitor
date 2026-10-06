## SurfaceRules — which floor marks (patches) may lie on which floors (R3D-SURFACES, 2026-10-06; `docs/systems/SURFACES_CATALOG.md` §3).
##
## A floor material declares `tags` out of a CLOSED vocabulary, a patch kind declares `requires` (ALL of these tags on the floor) and
## `forbids` (ANY of these on the floor means no), all in `res://surfaces/rules.json`. Co-existence is the default; exclusivity is a
## `forbids` entry ("no leaf in the desert" = `leaf` forbids `arid`). A tag outside the vocabulary and a kind with no rule are loud
## errors (B6), never a silent pass.
class_name SurfaceRules
extends RefCounted

const PATH: String = "res://surfaces/rules.json"

static var _loaded: bool = false
static var _vocabulary: PackedStringArray = PackedStringArray()
static var _patches: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("[SurfaceRules] %s is missing: no patch can be checked" % PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SurfaceRules] %s is not a JSON object" % PATH)
		return
	_vocabulary = PackedStringArray(parsed.get("vocabulary", []))
	_patches = parsed.get("patches", {})
	for kind: String in _patches:
		for key in ["requires", "forbids"]:
			for tag in (_patches[kind] as Dictionary).get(key, []):
				if not _vocabulary.has(String(tag)):
					push_error("[SurfaceRules] patch '%s' %s '%s', which is not in the vocabulary" % [kind, key, tag])


static func vocabulary() -> PackedStringArray:
	_load()
	return _vocabulary


static func has_rule(kind: String) -> bool:
	_load()
	return _patches.has(kind)


## The tags of `owner` that are not in the vocabulary (each one a loud error), the rest returned.
static func checked_tags(owner: String, tags: Array) -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for tag in tags:
		if _vocabulary.has(String(tag)):
			out.append(String(tag))
		else:
			push_error("[SurfaceRules] %s declares tag '%s', which is not in the vocabulary %s" % [owner, tag, _vocabulary])
	return out


## Per-kind facts from the rules file (R3D-SURFACES scatter): `class` ("marking" | "scatter" | "stroke" | "layer"; "marking" when absent),
## `size` (the quad's side in GU, 1 when absent), `priority` (draw order among stacked kinds), `scale` ([min, max] jitter), `density`
## (instances per GU^2 in a scatter zone unless the zone says otherwise) and `mature` (blood and bodily marks, DS-13).
static func kind_class(kind: String) -> String:
	_load()
	return String((_patches.get(kind, {}) as Dictionary).get("class", "marking"))


static func kind_size(kind: String) -> float:
	_load()
	return float((_patches.get(kind, {}) as Dictionary).get("size", 1.0))


static func kind_priority(kind: String) -> int:
	_load()
	return int((_patches.get(kind, {}) as Dictionary).get("priority", 0))


static func kind_scale(kind: String) -> Vector2:
	_load()
	var s: Array = (_patches.get(kind, {}) as Dictionary).get("scale", [1.0, 1.0])
	return Vector2(float(s[0]), float(s[1]))


static func kind_density(kind: String) -> float:
	_load()
	return float((_patches.get(kind, {}) as Dictionary).get("density", 0.0))


static func kind_mature(kind: String) -> bool:
	_load()
	return bool((_patches.get(kind, {}) as Dictionary).get("mature", false))


static func kinds_of_class(cls: String) -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for kind: String in _patches:
		if kind_class(kind) == cls:
			out.append(kind)
	return out


## "" when `kind` may lie on a floor with these tags, else why not (one short sentence). A kind with no rule is never allowed.
static func reason_against(kind: String, floor_tags: PackedStringArray) -> String:
	_load()
	if not _patches.has(kind):
		return "patch kind '%s' has no rule in %s" % [kind, PATH]
	var rule: Dictionary = _patches[kind]
	for tag in rule.get("requires", []):
		if not floor_tags.has(String(tag)):
			return "'%s' needs a floor tagged '%s'" % [kind, tag]
	for tag in rule.get("forbids", []):
		if floor_tags.has(String(tag)):
			return "'%s' is forbidden on a floor tagged '%s'" % [kind, tag]
	return ""
