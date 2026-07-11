# MAPFILE-02: FileMapSource, Catalog Wiring & Golden Exports

**Status:** Ready for implementation
**Predecessor:** MAPFILE-01 (verified clean — VERIFY_MAPFILE_01_20260705)
**Successor:** BLOCK-01 / PROP-01 (parallel) → PLAYGROUND-02
**Scope:** Wire `.map.json` files into `MapCatalog`; export PLAYGROUND and SIGMA_01 as golden files; fix two small carry-over defects from MAPFILE-01's verification; **resolve a vocabulary gap discovered during this prompt's planning, before any code is written.**
**Effort:** ~4 hours (was estimated 3h; +1h for the bridge section this prompt adds)
**Risk:** Medium (the vocabulary gap below is architectural, not cosmetic — read Item 0 fully before coding)

---

## Item 0 — MANDATORY READING: the schema/compiler vocabulary gap

**Do not skip this. It changes the scope of "golden export" from what MAPFILE-01's schema implied.**

`MapCompiler.compile(spec)` — the actual, only consumer of a runtime map spec — reads a **flat, cell/grid vocabulary**: `inner_size`, `buffer`, `rooms`, `dividers` (arrays of raw **cell lists**, not edges), `wall_height`, `props` (`{cell, tile, stack, height}`), `patrols`, `lights`, `light_tracks`, `access_points`, `floor_tile`. Outer perimeter walls and per-cell tile placement are generated procedurally inside `compile()` from these flat fields; there is **no code path today that accepts an edge-list (`{a, b, material, storeys, facade}`) or a generic prop-by-id (`{def, gu, vox_offset, rot}`) or a `solid_block` entry directly.**

MAPFILE-01's `walls` / `blocks` / `props` sections (per the master plan's aspirational JSON example) describe the **future** vocabulary — the one BLOCK-01 and PROP-01 are explicitly tasked with teaching `MapCompiler`/`EdgeExtractor` to understand. They do not describe what the compiler accepts *today*. This was a planning oversight on my part (the master plan's JSON examples were illustrative, not checked against `map_compiler.gd`'s real `spec.get(...)` calls) — caught now, before code, rather than after a silent mistranslation shipped (the G4 pattern, one level up the stack).

**Consequence for this prompt:** a `.map.json` containing only `board`/`walls`/`blocks`/`props`/`actors` **cannot currently drive a real map** — `walls`/`blocks`/`props` have nowhere to go. Two honest paths forward:

- **(a) Ship MAPFILE-02 with only `board` + `actors` translated**, and make loaded-but-untranslatable sections produce a loud, one-time warning (not silent data loss). PLAYGROUND's golden file becomes real and playable-shaped (it's simple: one floor, outer walls only, one guard). SIGMA_01 — which has real dividers, props, patrols, lights — **cannot** be exported this way without losing content.
- **(b) Add a bridge section, `legacy_compiler` (v1), that carries the exact flat fields `MapCompiler.compile()` already reads** (`rooms`, `dividers`, `wall_height`, `props` in the *compiler's* shape, `patrols`, `lights`, `light_tracks`, `access_points`) as a passthrough blob. This makes both golden exports fully lossless **today**, and gives `FileMapSource` something real to hand `MapCompiler`. As BLOCK-01/PROP-01 teach the compiler to read `blocks`/`props`(-by-id)/edge-`walls` natively, content migrates out of `legacy_compiler` field-by-field; the bridge section shrinks and eventually empties. This is a deliberate, temporary vocabulary duplication — not a permanent second format.

**Recommendation: implement (b).** It's the only option that makes this prompt's stated goal ("export PLAYGROUND and SIGMA_01 as golden files") true in the sense that matters — a file that can actually reproduce the map — rather than true in a narrow technical sense that quietly drops SIGMA_01's content.

**This is a schema change to MAPFILE-01's output and needs the same sign-off weight as the master plan's D-decisions.** Implement it, but flag it clearly in the completion report as **D15 (proposed): `legacy_compiler` bridge section**, for Matt to ratify or reject. If rejected, path (a) is the fallback and SIGMA_01's golden export is deferred until BLOCK-01/PROP-01 land.

---

## Item 1 — `legacy_compiler` section owner (D15)

Add to `map_sections_v1.gd`:

```gdscript
static func register_legacy_compiler(registry) -> void:
	var SectionOwner = registry.SectionOwner
	registry.register(SectionOwner.new(
		"legacy_compiler",
		1,
		func(fragment: Dictionary) -> Dictionary: return fragment.duplicate(true),
		func(raw: Dictionary) -> Dictionary: return raw.duplicate(true),
		{},
		func() -> Dictionary: return {}
	))
```

Register it in `register_all()`. It's intentionally opaque (pass-through duplicate) — `MapFileService` doesn't need to understand its internals, only `FileMapSource`'s translator (Item 3) does.

## Item 2 — `FileMapSource`

New file `godot/scripts/world/maps/file_map_source.gd`:

```gdscript
class_name FileMapSource
extends RefCounted

const RES_MAPS_DIR := "res://maps"
const USER_MAPS_DIR := "user://maps"

var registry: MapSectionRegistry
var service: MapFileService

func _init() -> void:
	registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	service = MapFileServiceClass.new(registry)

## Scan both directories; user:// wins on id collision. Returns {id: full_path}.
func list_available() -> Dictionary:
	var found: Dictionary = {}
	_scan_dir(RES_MAPS_DIR, found)   # res:// first...
	_scan_dir(USER_MAPS_DIR, found)  # ...user:// overwrites on collision (wins)
	return found

func _scan_dir(dir_path: String, found: Dictionary) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".map.json"):
			var full_path = dir_path.path_join(fname)
			var id = _peek_id(full_path)
			if id != "":
				found[id] = full_path
		fname = dir.get_next()

## Read just enough to get the id without full load/migrate (catalog listing is cheap).
func _peek_id(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return parsed.get("id", "")

## Load a map_id's file (if any) and translate to the MapCompiler runtime spec shape.
## Returns {} if not found — caller (MapCatalog) treats that as "not a file map,
## fall through to code-defined maps."
func get_runtime_spec(map_id: String) -> Dictionary:
	var available = list_available()
	if not available.has(map_id):
		return {}

	var result = service.load_file(available[map_id])
	if not result["ok"]:
		push_error("[FileMapSource] Failed to load '%s': %s" % [map_id, result["errors"]])
		return {}

	return _translate_to_runtime_spec(result["spec"])

## The translator. See Item 0 for why this exists in two tiers (native + bridge).
func _translate_to_runtime_spec(file_spec: Dictionary) -> Dictionary:
	var sections = file_spec.get("sections", {})
	var runtime: Dictionary = {}

	runtime["id"] = file_spec.get("id", "")

	# --- Native translation (board, actors): these map cleanly today ---
	var board = sections.get("board", {})
	runtime["inner_size"] = Vector2i(board.get("inner_size", [28, 18])[0], board.get("inner_size", [28, 18])[1])
	runtime["buffer"] = int(board.get("buffer", 1))
	runtime["floor_tile"] = String(board.get("floor_tile", "floor_SE"))

	var actors = sections.get("actors", {})
	var agent_start = actors.get("agent_start", [1, 1])
	runtime["agent_start"] = Vector2i(int(agent_start[0]), int(agent_start[1]))

	# guards -> patrols: verify _build_enemy_defs()'s expected shape before assuming
	# a direct passthrough is correct. If shapes diverge, translate field-by-field here
	# and note the mapping explicitly rather than passing the dict through blind.
	runtime["patrols"] = actors.get("guards", [])

	# --- Bridge translation (legacy_compiler): everything MapCompiler needs that the
	# native sections can't express yet (rooms, dividers, props-in-compiler-shape,
	# lights, light_tracks, access_points, wall_height). Merge shallow: bridge keys
	# win only if native didn't already set them (native sections take priority as
	# they land in future prompts). ---
	var bridge = sections.get("legacy_compiler", {})
	for key in bridge.keys():
		if not runtime.has(key):
			runtime[key] = bridge[key]

	# --- Loud, non-blocking warning for sections that exist but have no translator yet ---
	for future_section in ["walls", "blocks", "props"]:
		var frag = sections.get(future_section, {})
		var items_key = "edges" if future_section == "walls" else "items"
		if frag.get(items_key, []).size() > 0:
			push_warning("[FileMapSource] Map '%s' has non-empty '%s' section with no MapCompiler translation yet (pending BLOCK-01/PROP-01) — ignored" %
				[runtime["id"], future_section])

	return runtime
```

**Stop-and-report checkpoint:** before finalizing `_build_enemy_defs()`'s patrol shape assumption above, read the function signature and confirm `guards[i].route` matches what it expects for a patrol entry. If it doesn't match 1:1, write the field-mapping explicitly (don't pass the raw dict through and hope) and note the actual shapes in the completion report.

## Item 3 — `MapCatalog` wiring

```gdscript
# map_catalog.gd — add file-source fallback BEFORE the hardcoded match, not after:
# a shipped/custom file with the same id as a code-defined map should win (lets
# authored content override a stub without recompiling the game).

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
static var _file_source: FileMapSourceClass = null

static func get_spec(map_id: String, context: Dictionary = {}) -> Dictionary:
	if _file_source == null:
		_file_source = FileMapSourceClass.new()

	var file_spec = _file_source.get_runtime_spec(map_id)
	if not file_spec.is_empty():
		return file_spec

	match map_id:
		"PLAYGROUND":
			return PlaygroundMapClass.spec()
		"SIGMA_01":
			return Sigma01MapClass.spec()
		"PROCEDURAL":
			return ProceduralMapClass.generate(int(context.get("seed", 0)))
		_:
			push_error("[MapCatalog] Unknown map_id '%s' — returning empty spec" % map_id)
			return {}

static func list_map_ids() -> Array[String]:
	if _file_source == null:
		_file_source = FileMapSourceClass.new()
	var ids: Array[String] = ["PLAYGROUND", "SIGMA_01", "PROCEDURAL"]  # code-defined, always available
	for file_id in _file_source.list_available().keys():
		if not ids.has(file_id):
			ids.append(file_id)
	return ids
```

## Item 4 — Golden exports

Write a one-off export script (`godot/scripts/tools/mapfile_export_golden.gd`, headless, run once — not part of the runtime) that:

1. Calls `PlaygroundMapClass.spec()` and `Sigma01MapClass.spec()` directly (the existing code-defined specs — the ground truth).
2. Converts each into a `.map.json` file-spec dict: `board`/`actors` from the fields that map natively; **everything else** (`dividers`, `props`, `patrols`, `lights`, `light_tracks`, `access_points`, `wall_height`) into `legacy_compiler` verbatim.
3. Saves via `MapFileService.save_file()` to `res://maps/PLAYGROUND.map.json` and `res://maps/SIGMA_01.map.json`.
4. **Round-trip verification, not just "it saved":** immediately reload each via `FileMapSource.get_runtime_spec()` and diff the result against the original `*Map.spec()` output field-by-field. Any discrepancy is a hard failure of this prompt — a golden file that doesn't reproduce its source map is worse than no golden file.

## Item 5 — Carry-over fixes from MAPFILE-01 verification

1. **Delete the stray duplicate.** `godot/maps/PLAYGROUND.map.json` (wrong location — `res://` is the repo root per `project.godot`, so this path resolves to `res://godot/maps/`, which nothing reads) is a leftover duplicate of the real `res://maps/PLAYGROUND.map.json`. Delete it. (It will also be regenerated fresh by Item 4 anyway — delete before running the export, don't leave two copies confusing future greps.)
2. **Fix `save_file()`'s directory creation.** Current logic (`DirAccess.open(file_dir.get_base_dir()).make_dir(file_dir.get_file())`) only creates one missing level and silently no-ops if `dir` is null (e.g., grandparent also missing). Replace with `DirAccess.make_dir_recursive_absolute(file_dir)`, which is idempotent and handles arbitrary depth:
   ```gdscript
   var file_dir = path.get_base_dir()
   if not DirAccess.dir_exists_absolute(file_dir):
       DirAccess.make_dir_recursive_absolute(file_dir)
   ```
3. **Regression test for the above:** add a case to `mapfile_roundtrip_test.gd` (or a new small test) that saves to `user://maps/subtest/nested.map.json` (a path whose parent directories don't exist yet), asserts `save_result["ok"] == true`, and asserts the file is readable back — this is the exact scenario the old code never exercised (noted in MAPFILE-01's verification, item 3).

---

## Validation & Evidence (PASS criteria)

1. **Vocabulary gap write-up** (Item 0) in the completion report, with the D15 flag, *before* any other evidence — this is a decision, not just a test result.
2. **`FileMapSource.list_available()` transcript:** with both golden files in place, assert it returns `{"PLAYGROUND": "res://maps/PLAYGROUND.map.json", "SIGMA_01": "res://maps/SIGMA_01.map.json"}` (paths as actually resolved).
3. **Collision precedence test:** place a `user://maps/PLAYGROUND.map.json` with a different `meta.title`; assert `list_available()["PLAYGROUND"]` now points to the `user://` path (user wins), then remove it and confirm reversion to `res://`.
4. **Golden round-trip transcript (Item 4.4):** raw output showing, for both PLAYGROUND and SIGMA_01, the field-by-field diff against the original `*Map.spec()` — must show zero discrepancies. This is the acceptance test of the entire prompt; a passing suite elsewhere with a failing round-trip here means the prompt failed.
5. **Catalog integration:** call `MapCatalog.get_spec("PLAYGROUND")` (no context) after golden export exists; assert the returned dict is usable by `MapCompiler.compile()` without error (call `compile()` on it, assert no `push_error` fired, assert `result["size"]` is sane).
6. **Nested directory save (Item 5.3):** transcript of the new regression test, red-then-green if you touch the old broken logic first to prove it would have failed (optional but preferred, per the project's evidence standard), then green with the fix.
7. **Cleanup confirmation:** `find . -iname "PLAYGROUND.map.json"` shows exactly one result after this prompt.
8. `check_invariants.py` and `map_lint.gd` both green (map_lint should now report 2 checked, 0 failed with both golden files present).

## Implementation Checklist

- [ ] Item 0: write up the gap, get explicit "proceeding with (b)" logged in the completion report
- [ ] Item 1: `legacy_compiler` section owner registered
- [ ] Item 2: `FileMapSource` — list/peek/translate; patrol-shape checkpoint verified against `_build_enemy_defs()`
- [ ] Item 3: `MapCatalog` wiring, file-source-first precedence
- [ ] Item 4: export script; round-trip-verified golden files for PLAYGROUND and SIGMA_01
- [ ] Item 5.1: stray duplicate deleted
- [ ] Item 5.2: `save_file()` uses `make_dir_recursive_absolute`
- [ ] Item 5.3: nested-directory regression test added and green
- [ ] All 8 validation items produce verbatim transcripts
- [ ] Archive to `PROMPTS/DONE/`; bump VERSION

## Out of scope

Teaching `MapCompiler`/`EdgeExtractor` to read `walls`/`blocks`/`props` natively (that's BLOCK-01/PROP-01's job — this prompt only warns when those sections are present and unused); the map editor; the generator pipeline for `procedural`/`patches`.

---

*End MAPFILE-02.*
