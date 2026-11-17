## AttachmentRegistry — what mounts on a weapon (`attachments/*.json`, two tiers like `WeaponRegistry`: user:// wins on an id).
class_name AttachmentRegistry

const JsonFileRef = preload("res://godot/scripts/systems/json_file.gd")

const RES_DIR := "res://attachments"
const USER_DIR := "user://attachments"

var registry: Dictionary = {}  # id -> AttachmentDef
## Every row that could not be read, loudly (`JsonFile`, AUDIT 2026-10-07).
var load_errors: Array[String] = []

static var _shared: AttachmentRegistry = null


static func shared() -> AttachmentRegistry:
	if _shared == null:
		_shared = AttachmentRegistry.new()
		_shared._scan_dir(RES_DIR)
		_shared._scan_dir(USER_DIR)
	return _shared


func get_attachment(p_id: String) -> AttachmentDef:
	return registry.get(p_id, null)


## The attachments of `kind` that fit the weapon `weapon_id`, by id.
func fitting(weapon_id: String, kind: String = "muzzle") -> PackedStringArray:
	var ids: Array = []
	for id: String in registry:
		var a: AttachmentDef = registry[id]
		if a.kind == kind and a.fits.has(weapon_id):
			ids.append(id)
	ids.sort()
	return PackedStringArray(ids)


func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path: String = dir_path.path_join(fname)
			var parsed: Dictionary = JsonFileRef.read_object(path, "AttachmentRegistry", load_errors)
			if not parsed.is_empty() and not JsonFileRef.require_id(parsed, path, "AttachmentRegistry", load_errors).is_empty():
				var a: AttachmentDef = AttachmentDef.from_json(parsed)
				registry[a.id] = a
				print("[AttachmentRegistry] Registered: %s (%s, fits %s)" % [a.id, a.kind, ", ".join(a.fits)])
		fname = dir.get_next()
