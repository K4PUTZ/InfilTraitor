## CaptureProfiles — the capture profiles of `capture/profiles.json` (CAPTURE_RAILS_MASTER_PLAN §5), the one file the game and
## `tools/persistent/capture.py` both read. A profile says the machine, whether the HUD shows (R5), the turn default of a rail (R9)
## and, per SHAPE (portrait / landscape), the framing and the window.
extends RefCounted

const PATH: String = "res://capture/profiles.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var errors: Array = []
		_cache = JsonFile.read_object(PATH, "CaptureProfiles", errors)
		for e in errors:
			push_error("[CaptureProfiles] %s" % e)
	return _cache


## The profile `name` resolved for one shape: `{ok, name, shape, framing, window: Vector2i, hud, dev_panels, fixed_fps, turn, error}`.
## `shape` "" = the profile's default shape (a profile whose default is "both" answers its first shape here; the HARNESS runs both).
static func resolve(name: String, shape: String = "") -> Dictionary:
	var profiles: Dictionary = data().get("profiles", {})
	if not profiles.has(name):
		return {"ok": false, "error": "[CaptureProfiles] unknown profile '%s' (%s)" % [name, ", ".join(PackedStringArray(profiles.keys()))]}
	var p: Dictionary = profiles[name]
	var shapes: Dictionary = p.get("shapes", {})
	var s: String = shape if not shape.is_empty() else str(p.get("default_shape", ""))
	if not shapes.has(s):
		s = str(shapes.keys()[0]) if not shapes.is_empty() else ""
	if not shapes.has(s):
		return {"ok": false, "error": "[CaptureProfiles] profile '%s' has no shape '%s'" % [name, shape]}
	var sh: Dictionary = shapes[s]
	return {"ok": true, "name": name, "shape": s, "framing": str(sh.get("framing", "desktop")),
		"window": JsonFile.vector2i(sh.get("window", [0, 0]), Vector2i.ZERO, "%s.%s.window" % [name, s], []),
		"hud": bool(p.get("hud", false)), "dev_panels": bool(p.get("dev_panels", false)), "fixed_fps": int(p.get("fixed_fps", 0)),
		"turn": str(p.get("turn", "cut")), "machine": str(p.get("machine", "desktop")), "error": ""}
