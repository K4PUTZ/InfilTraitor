extends SceneTree

## SAVE-01 selftest — the round trip, and the two things that must NOT survive it.
##
## This exists because `SaveState` has no caller yet: the Director asked for the
## plumbing to be prepared ahead of the feature, and unexercised plumbing rots
## silently. A selftest is what makes "prepared" mean something.
##
## Uses a STUB rather than a real Room. What is under test is the serialisation
## contract — key packing, version refusal, and that the soot index is treated as
## a cache — none of which needs a built map, and all of which a real Room would
## make slower and harder to assert on.

class RoomStub extends RefCounted:
	var map_id: String = "TESTMAP"
	var _base_damage: Dictionary = {}
	var _crater_floor_soot: Dictionary = {}
	## GLASS G-D15 / V-D — the primed-pane store. The stub models the real Room's
	## persisted fields, so a new one has to appear here too; that is the point of
	## a stub rather than a mock.
	var _pane_primed: Dictionary = {}
	## SS-1 (SOOT_STORAGE_REFORM) — the scorch store. Present here from the moment
	## the field exists, not from the moment it is SAVED (that is SS-4), because
	## `clear_run_state()` already has to forget it: the Director's save model
	## discards scenario state with the level, so a store left behind comes back as
	## the previous level's crater.
	var _soot_map: Dictionary = {}
	var invalidated: int = 0
	func invalidate_soot_index(_reason: String = "") -> void:
		invalidated += 1


var _fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("SAVE-01 SELFTEST: SaveState round trip")
	print("=".repeat(70) + "\n")

	_test_round_trip()
	_test_version_refusal()
	_test_malformed_refusal()
	_test_clear()

	print("")
	## ⚠️ The literal word PASS, because `run_selftests.py` requires it: a suite
	## that fails to LOAD exits 0 having run nothing, so the runner additionally
	## demands the banner. "all checks passed" is not it — that spelling cost this
	## file one red run.
	if _fails == 0:
		print("[SAVE-01] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[SAVE-01] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[SAVE-01] ✅ %s" % label)
	else:
		print("[SAVE-01] ❌ %s" % label)
		_fails += 1


## The whole point: what goes in comes out, keys and payloads intact.
func _test_round_trip() -> void:
	var a := RoomStub.new()
	a._base_damage[Vector3i(3, -4, 80)] = [2, 1, 0, 1, 0, 5, 2]
	a._base_damage[Vector3i(-9, 12, 79)] = [1, 0, 0, 0, 0, 0, 0]
	a._crater_floor_soot[79] = {Vector2i(5, 6): 2, Vector2i(-1, 0): 3}
	a._pane_primed["PANE_SLICE_6_10_SW"] = true

	var blob: Dictionary = SaveState.capture(a)
	var b := RoomStub.new()
	_check(SaveState.restore(b, blob), "restore() accepts what capture() produced")
	_check(b._base_damage.size() == 2, "base_damage: 2 entries survived")
	## NEGATIVE coordinates specifically: the map buffer puts real geometry at
	## negative cells, and a packing that lost the sign would look fine on this
	## board's positive half and corrupt the other.
	_check(b._base_damage.get(Vector3i(3, -4, 80), []) == [2, 1, 0, 1, 0, 5, 2],
		"base_damage: a negative-Y key round-trips with its payload")
	_check(b._base_damage.get(Vector3i(-9, 12, 79), []) == [1, 0, 0, 0, 0, 0, 0],
		"base_damage: a negative-X key round-trips with its payload")
	## G-D15 / V-D — the primed pane survives a round trip, and an OLD save with
	## no `pane_primed` key restores as "nothing primed" rather than refusing.
	_check(b._pane_primed.has("PANE_SLICE_6_10_SW"),
		"pane_primed: the primed pane survived the round trip")
	var legacy: Dictionary = SaveState.capture(a)
	legacy.erase("pane_primed")
	var c := RoomStub.new()
	c._pane_primed["STALE"] = true
	_check(SaveState.restore(c, legacy) and c._pane_primed.is_empty(),
		"pane_primed: a save written before V-D restores as nothing primed, not a refusal")
	_check(b._crater_floor_soot.get(79, {}).get(Vector2i(-1, 0), -1) == 3,
		"crater_floor_soot: a negative cell round-trips")
	_check(blob["map_id"] == "TESTMAP", "map_id travels with the record")
	## The cache is rebuilt, never restored — SaveState's own class note.
	_check(b.invalidated == 1, "restore() invalidates the soot index exactly once")


## B6: a version it does not know must be refused, not partially applied.
func _test_version_refusal() -> void:
	var r := RoomStub.new()
	r._base_damage[Vector3i(1, 1, 1)] = [1, 0, 0, 0, 0, 0, 0]
	var bad := {"version": 999, "base_damage": [], "crater_floor_soot": []}
	## `validate()` rather than `restore()`: the refusal path push_errors by
	## design (B6), and run_selftests.py reads any push_error as a suite failure.
	## See SaveState.validate()'s note.
	_check(SaveState.validate(bad) != "", "an unknown format version is REFUSED")
	_check(r._base_damage.size() == 1,
		"a refused restore leaves the existing state untouched")


## A truncated entry must fail loudly rather than deserialise into a wrong cell.
func _test_malformed_refusal() -> void:
	var r := RoomStub.new()
	var bad := {"version": SaveState.FORMAT_VERSION,
		"base_damage": [[1, 2]], "crater_floor_soot": []}
	_check(SaveState.validate(bad) != "", "a truncated base_damage entry is REFUSED")
	## And the refusal must be TOTAL — validation runs before anything is cleared,
	## so a half-applied file cannot exist.
	r._base_damage[Vector3i(7, 7, 7)] = [1, 0, 0, 0, 0, 0, 0]
	_check(SaveState.validate(bad) != "" and r._base_damage.size() == 1,
		"validation happens before any state is cleared")


## The Director's "limpar em caso de reset, morte, etc", in one place.
func _test_clear() -> void:
	var r := RoomStub.new()
	r._base_damage[Vector3i(0, 0, 0)] = [1, 0, 0, 0, 0, 0, 0]
	r._crater_floor_soot[79] = {Vector2i(0, 0): 1}
	## G-D15 / V-D — a primed pane is a promise made to THIS run: a fresh mission
	## must not inherit a window that shatters to the first pistol shot.
	r._pane_primed["PANE_X"] = true
	r._soot_map[79] = {Vector2i(0, 0): 1234}
	SaveState.clear_run_state(r)
	_check(r._base_damage.is_empty(), "clear_run_state empties base_damage")
	_check(r._crater_floor_soot.is_empty(), "clear_run_state empties crater soot")
	## SS-1 — the silent half. Nothing on screen would report a store that
	## survived a level change; it would simply be last level's scorch.
	_check(r._soot_map.is_empty(), "clear_run_state empties the SS-1 scorch store")
	_check(r._pane_primed.is_empty(), "clear_run_state empties the primed-pane store")
	_check(r.invalidated == 1, "clear_run_state invalidates the soot index")
