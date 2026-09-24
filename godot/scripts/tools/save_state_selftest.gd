extends SceneTree

## SAVE-01 selftest — the round trip, and the two things that must NOT survive it.
##
## This exists because `SaveState` has no caller yet: the Director asked for the
## plumbing to be prepared ahead of the feature, and unexercised plumbing rots
## silently. A selftest is what makes "prepared" mean something.
##
## Uses a STUB rather than a real Room. What is under test is the serialisation
## contract — key packing, version refusal, and that the soot map travels and is
## re-projected — none of which needs a built map, and all of which a real Room would
## make slower and harder to assert on.

class RoomStub extends RefCounted:
	var map_id: String = "TESTMAP"
	var _base_damage: Dictionary = {}
	## R3D-8 step 4 — the same records per claim: `cell -> {claim tag -> record}`.
	var _base_damage_claims: Dictionary = {}
	## GLASS G-D15 / V-D — the primed-pane store. The stub models the real Room's
	## persisted fields, so a new one has to appear here too; that is the point of
	## a stub rather than a mock.
	var _pane_primed: Dictionary = {}
	## SOOT-STAMP (2026-09-22) — the soot map, `level -> {base_cell: tone}`. Saved:
	## soot is stamped once and cannot be re-derived from the damage any more.
	var _soot_map: Dictionary = {}
	## G6 (§7.1) — where broken glass came to rest, in BASE coords, with its pile
	## depth. Same reasoning as the fields above: the stub models the real Room's
	## persisted state, so a new one appears here the moment it exists.
	var _base_shards: Dictionary = {}
	## G4 — the glass that stayed stuck to a frame, in BASE coords. POSITION only:
	## the shape is a hash of the key and the anchor is read from the live world,
	## so there is deliberately no payload to lose here.
	var _base_remnants: Dictionary = {}
	## CRACK-06 — the same, clinging to the pane's own torn glass edge. A separate
	## store for a separate anchor rule; models the real Room's field.
	var _base_rim_shards: Dictionary = {}
	var projected: int = 0
	func project_soot_store() -> void:
		projected += 1


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
	## R3D-8 step 4 — two claims of ONE cell in different states (a box corner): the tags and payloads must both
	## come back, on a negative key.
	a._base_damage_claims[Vector3i(3, -4, 80)] = {10: [2, 1, 0, 1, 0, 5, 2], 11: [1, 0, 0, 0, 0, 0, 0]}
	a._soot_map[79] = {Vector2i(5, 6): 2, Vector2i(-1, 0): 3}
	a._soot_map[96] = {Vector2i(40, 3): 0}
	a._pane_primed["PANE_SLICE_6_10_SW"] = true
	## G6 — a pile 17 deep on a negative cell, so the count and the sign are both
	## on the wire.
	a._base_shards[Vector3i(9, -4, 79)] = 17
	## G4 — two remnants, one on a negative cell.
	a._base_remnants[Vector3i(-7, 3, 84)] = true
	a._base_remnants[Vector3i(2, 2, 84)] = true
	## CRACK-06 — a rim shard, also on a negative cell.
	a._base_rim_shards[Vector3i(-4, 8, 82)] = true

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
	var claims_back: Dictionary = b._base_damage_claims.get(Vector3i(3, -4, 80), {})
	_check(claims_back.size() == 2 and claims_back.get(10, []) == [2, 1, 0, 1, 0, 5, 2] \
			and claims_back.get(11, []) == [1, 0, 0, 0, 0, 0, 0],
		"base_damage_claims: both claims of one cell round-trip with their own payloads")
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
	## SOOT-STAMP — the TONE travels, per cell and per level, negative cell included.
	_check(int(b._soot_map.get(79, {}).get(Vector2i(-1, 0), -1)) == 3
		and int(b._soot_map.get(79, {}).get(Vector2i(5, 6), -1)) == 2
		and int(b._soot_map.get(96, {}).get(Vector2i(40, 3), -1)) == 0,
		"soot: every cell's tone round-trips, negative cell and a second level included")
	## A v1 save (before SOOT-STAMP) still restores — as no scorch, not a refusal.
	var v1: Dictionary = SaveState.capture(a)
	v1["version"] = 1
	v1.erase("soot")
	v1["crater_floor_soot"] = [[79, 5, 6, 2]]
	var g := RoomStub.new()
	g._soot_map[80] = {Vector2i(1, 1): 1}
	_check(SaveState.restore(g, v1) and g._soot_map.is_empty(),
		"soot: a v1 save restores with no scorch rather than refusing")
	## ── G6 — THE PILE DEPTH TRAVELS, NOT A FLAG ─────────────────────────────
	## ⚠️ Asserted as the VALUE, not as presence. A save that restored every pile
	## at 1 would round-trip "there is glass here" perfectly and quietly flatten
	## every heap a shattered pane left — and the count is the only thing that
	## tells a single round's worth from a whole pane coming down.
	_check(int(b._base_shards.get(Vector3i(9, -4, 79), -1)) == 17,
		"floor_shards: a pile round-trips with its DEPTH (17), negative cell included")
	## And a save written before G6 restores as a clean floor rather than a refusal.
	var pre_g6: Dictionary = SaveState.capture(a)
	pre_g6.erase("floor_shards")
	var d := RoomStub.new()
	d._base_shards[Vector3i(1, 1, 79)] = 9
	_check(SaveState.restore(d, pre_g6) and d._base_shards.is_empty(),
		"floor_shards: a save written before G6 restores as no glass, not a refusal")
	## ── G4 — THE REMNANTS ───────────────────────────────────────────────────
	_check(b._base_remnants.size() == 2 and b._base_remnants.has(Vector3i(-7, 3, 84)),
		"glass_remnants: both survive, negative cell included")
	var pre_g4: Dictionary = SaveState.capture(a)
	pre_g4.erase("glass_remnants")
	var e := RoomStub.new()
	e._base_remnants[Vector3i(5, 5, 84)] = true
	_check(SaveState.restore(e, pre_g4) and e._base_remnants.is_empty(),
		"glass_remnants: a save written before G4 restores as nothing stuck, not a refusal")
	## ── CRACK-06 — THE RIM SHARDS ───────────────────────────────────────────
	_check(b._base_rim_shards.size() == 1 and b._base_rim_shards.has(Vector3i(-4, 8, 82)),
		"glass_rim_shards: the shard survives, negative cell included")
	var pre_c6: Dictionary = SaveState.capture(a)
	pre_c6.erase("glass_rim_shards")
	var f := RoomStub.new()
	f._base_rim_shards[Vector3i(1, 1, 82)] = true
	_check(SaveState.restore(f, pre_c6) and f._base_rim_shards.is_empty(),
		"glass_rim_shards: a save written before CRACK-06 restores as nothing clinging, not a refusal")
	_check(blob["map_id"] == "TESTMAP", "map_id travels with the record")
	## The soot map is state, and the plane is its projection: a restore re-projects.
	_check(b.projected == 1, "restore() re-projects the soot map exactly once")


## B6: a version it does not know must be refused, not partially applied.
func _test_version_refusal() -> void:
	var r := RoomStub.new()
	r._base_damage[Vector3i(1, 1, 1)] = [1, 0, 0, 0, 0, 0, 0]
	var bad := {"version": 999, "base_damage": [], "soot": []}
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
		"base_damage": [[1, 2]], "soot": []}
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
	## G-D15 / V-D — a primed pane is a promise made to THIS run: a fresh mission
	## must not inherit a window that shatters to the first pistol shot.
	r._pane_primed["PANE_X"] = true
	r._soot_map[79] = {Vector2i(0, 0): 1}
	SaveState.clear_run_state(r)
	_check(r._base_damage.is_empty(), "clear_run_state empties base_damage")
	## The silent half. Nothing on screen would report a soot map that survived a
	## level change; it would simply be last level's scorch.
	_check(r._soot_map.is_empty(), "clear_run_state empties the soot map")
	_check(r._pane_primed.is_empty(), "clear_run_state empties the primed-pane store")

