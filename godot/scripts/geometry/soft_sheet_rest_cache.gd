## SoftSheetRestCache — the settled node positions of the cloths at rest, kept between runs (ROOF_MASTER_PLAN v0.45).
##
## A cloth that stands in the world from the first frame is settled at load (`SoftSheetSim.settle_now`, 80-350 ms of worker time each on the handsets). The result is a pure
## function of the sheet's setup (its grid, its pins, the walls round it, the material's numbers and the sim's own version), so it is computed once per device and read back
## afterwards: a level with many cloths (tents) loads without simulating any of them. A key that no longer matches (a map edit, a preset change, a new sim) simply misses and the
## sheet is settled again: nothing is ever invalidated by hand. `SOFT_REST_CACHE=0` turns it off. The file is a cache, never state: delete it freely.
class_name SoftSheetRestCache
extends RefCounted

## Bump when `SoftSheetSim`'s behaviour changes (a stale result would be a cloth that rests where the old sim put it).
const SIM_VERSION: int = 3
const PATH := "user://soft_sheet_rest_v1.bin"

static var _entries: Dictionary = {}   ## key String -> PackedFloat64Array (3 floats per node)
static var _loaded: bool = false
static var _dirty: bool = false
static var hits: int = 0
static var misses: int = 0


## The key of a sheet's setup (`params`: what `SoftSheetSim.new` takes).
static func key_of(params: Dictionary) -> String:
	var row: Dictionary = params["material"]
	var solid: Dictionary = params.get("solid", {})
	var parts: PackedStringArray = PackedStringArray()
	parts.append("v%d" % SIM_VERSION)
	parts.append("%d,%d,%.5f,%.5f" % [int(params["nx"]), int(params["nz"]), float(params["hx"]), float(params["hz"])])
	var o: Vector3 = params["origin"]
	parts.append("%.4f,%.4f,%.4f" % [o.x, o.y, o.z])
	var keys: Array = row.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(row[k])])
	parts.append("pins%d:%d" % [(params["pins"] as PackedByteArray).size(), hash(params["pins"])])
	parts.append("solid%d:%d" % [(solid.get("bits", PackedByteArray()) as PackedByteArray).size(), hash(solid.get("bits", PackedByteArray()))])
	parts.append("g%d,l%d,f%.3f" % [int(solid.get("x0", 0)) * 1000 + int(solid.get("y0", 0)), int(solid.get("l0", 0)), float(params.get("floor_y", 0.0))])
	if params.has("basis_u"):
		parts.append("b%s%s" % [str(params["basis_u"]), str(params["basis_v"])])
	parts.append("%f,%d" % [SoftSheetSim.GRAVITY, SoftSheetSim.ITERATIONS])
	return "|".join(parts)


static func lookup(key: String) -> PackedFloat64Array:
	_load()
	if _entries.has(key):
		hits += 1
		return _entries[key]
	misses += 1
	return PackedFloat64Array()


static func store(key: String, positions: PackedFloat64Array) -> void:
	_load()
	_entries[key] = positions
	_dirty = true


## Writes the file when something new was stored. Called once, after a load.
static func flush() -> void:
	if not _dirty:
		return
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SoftSheetRestCache] cannot write %s (%s): the cache stays in memory" % [PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_var(_entries)
	file.close()
	_dirty = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	file.close()
	if data is Dictionary:
		_entries = data
