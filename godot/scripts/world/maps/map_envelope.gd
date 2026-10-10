## MapEnvelope — the segment's measured envelope, read from THE one file `maps/_spec/segment_envelope.json` (CAPTURE_RAILS_MASTER_PLAN
## §3.3; the same file `gen_segment_map.py` and `segment_budget.py` read). Footprint and buffer are the canon; `reserve` and
## `compose_storeys` are WARNING thresholds — guides for an author and a future editor, never limits the engine enforces.
class_name MapEnvelope
extends RefCounted

const PATH: String = "res://maps/_spec/segment_envelope.json"

static var _cache: Dictionary = {}


## The file as a Dictionary, read once per run; a missing or malformed file is a loud error and an empty Dictionary (callers fall
## back to the canon numbers below, so a broken file never breaks a map load — it breaks the warnings, loudly).
static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var errors: Array = []
	var d: Dictionary = JsonFile.read_object(PATH, "MapEnvelope", errors)
	for e in errors:
		push_error("[MapEnvelope] %s" % e)
	_cache = d
	return _cache


static func footprint() -> Vector2i:
	return JsonFile.vector2i(data().get("footprint", [18, 36]), Vector2i(18, 36), "footprint", [])


static func reserve() -> Vector2i:
	return JsonFile.vector2i(data().get("reserve", [24, 48]), Vector2i(24, 48), "reserve", [])


static func compose_storeys() -> int:
	return int(data().get("compose_storeys", 3))


static func playable_storeys() -> int:
	return int(data().get("playable_storeys", 1))


## The thresholds that apply to one map: the file's, overridden by the map's own `layout.envelope` (a special map such as GLASS).
static func for_map(layout_envelope: Dictionary) -> Dictionary:
	var res: Vector2i = reserve()
	if layout_envelope.has("reserve"):
		res = JsonFile.vector2i(layout_envelope["reserve"], res, "layout.envelope.reserve", [])
	return {
		"footprint": footprint(),
		"reserve": res,
		"playable_storeys": playable_storeys(),
		"compose_storeys": int(layout_envelope.get("compose_storeys", compose_storeys())),
	}
