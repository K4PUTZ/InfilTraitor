# MAPFILE-01: Schema, Service, Migrations & Lint

**Status:** Ready for implementation
**Predecessor:** MAP_MATTRESS_MASTER_PLAN v1.1 (Part 3, D6, D9, D10)
**Successor:** MAPFILE-02 (catalog wiring, golden exports) → BLOCK-01 / PROP-01 (consume the schema) → PLAYGROUND-02 (first real content)
**Scope:** The `.map.json` format, a section-registry-based `MapFileService`, per-section migrations, tolerant round-trip, loud-fail validation, and a headless `map_lint` tool.
**Effort:** ~5 hours
**Risk:** Medium (new subsystem, but purely additive — nothing currently reads `.map.json`; zero live-game impact until MAPFILE-02 wires the catalog)

---

## Context

This is infrastructure, not content — it does not touch VOXEL, BAKE, or gameplay code. Its entire job is to make map data **survive the invention of new features**. Read the requirements in the master plan §3.1 before coding; they are the acceptance bar, not just background:

1. Individual files, folder-loadable.
2. Save only essential/authorial data — the engine derives everything else.
3. Seed + patch model for procedural-with-authorial-control.
4. Hard to break; keeps saving correctly after new sections are invented.
5. Editor-ready without rework (not built now, but the patch model *is* the future editor's substrate — don't paint it into a corner).

**Stop-and-report rule applies:** if the JSON shape you need diverges from §3.2 of the master plan, stop and report rather than silently reconciling.

---

## Item 1 — File format & location

`res://maps/*.map.json` (shipped) and `user://maps/*.map.json` (custom/generated), mirroring the texture/prop tier convention already established. Same-id collision: user wins.

Canonical shape (master plan §3.2, reproduced here as the literal contract):

```json
{
  "format": "infiltraitor-map",
  "schema_version": 3,
  "id": "PLAYGROUND",
  "meta": { "title": "Playground 2.0", "author": "Matt", "created": "2026-07-05" },
  "sections": {
    "board":      { "v": 1, "inner_size": [28, 18], "buffer": 1, "floor_tile": "floor_SE" },
    "walls":      { "v": 2, "edges": [ { "a": [3,2], "b": [3,6], "material": "stone", "storeys": 2, "facade": null } ] },
    "blocks":     { "v": 1, "items": [ { "gu": [7,4], "storeys": 2, "material": "stone" } ] },
    "props":      { "v": 1, "items": [ { "def": "crate_full", "gu": [9,4], "vox_offset": [0,0], "rot": 0 } ] },
    "actors":     { "v": 1, "agent_start": [1,1], "guards": [ { "route": [[4,4],[4,9]], "class": "patrol" } ] },
    "procedural": null,
    "patches":    []
  }
}
```

`schema_version` is the **global** file version (bumped only when the top-level shape changes — adding/removing a section, changing the envelope). Each section's own `"v"` is independent and is what per-section migrations key off of. Do not conflate the two.

## Item 2 — Section registry (the anti-breakage core)

New file `godot/scripts/world/maps/persistence/map_section_registry.gd`:

```gdscript
class_name MapSectionRegistry
extends RefCounted

## A section owner: the ONLY code that knows a given section's internal shape.
class SectionOwner extends RefCounted:
	var section_id: String
	var current_version: int
	var serialize: Callable      # (spec_fragment) -> Dictionary
	var deserialize: Callable    # (Dictionary) -> spec_fragment
	var migrations: Dictionary   # {from_version: Callable(Dictionary) -> Dictionary}
	var default_value: Callable  # () -> Dictionary  (used when section absent in file)

	func _init(p_id: String, p_version: int, p_serialize: Callable, p_deserialize: Callable,
			p_migrations: Dictionary, p_default: Callable) -> void:
		section_id = p_id
		current_version = p_version
		serialize = p_serialize
		deserialize = p_deserialize
		migrations = p_migrations
		default_value = p_default

var _owners: Dictionary = {}  # section_id -> SectionOwner

func register(owner: SectionOwner) -> void:
	if _owners.has(owner.section_id):
		push_error("[MAPFILE] Section '%s' already registered — refusing duplicate" % owner.section_id)
		return
	_owners[owner.section_id] = owner

func get_owner(section_id: String) -> SectionOwner:
	return _owners.get(section_id, null)

func known_sections() -> Array:
	return _owners.keys()

## Migrate one section's raw dict up to current_version. Applies the chain in order.
## Fails loudly (returns null + push_error) if a required migration step is missing.
func migrate_section(section_id: String, raw: Dictionary) -> Variant:
	var owner = get_owner(section_id)
	if owner == null:
		# Unknown section: NOT an error. Preserve verbatim (tolerant round-trip, M3).
		return raw
	var version: int = raw.get("v", 0)
	var data = raw
	while version < owner.current_version:
		if not owner.migrations.has(version):
			push_error("[MAPFILE] Section '%s' has no migration from v%d to v%d — file cannot be safely loaded" %
				[section_id, version, version + 1])
			return null
		data = owner.migrations[version].call(data)
		version += 1
		data["v"] = version
	return data
```

**This is the mechanism that satisfies requirement 4.** A future feature (e.g. `waypoints` section) registers itself once, with its own version and migration chain. `MapFileService`'s core loop (Item 3) never special-cases any section by name — it only knows the registry API. Old files simply lack the new section and get `default_value()`.

## Item 3 — `MapFileService`

New file `godot/scripts/world/maps/persistence/map_file_service.gd`:

```gdscript
class_name MapFileService
extends RefCounted

const FORMAT_TAG := "infiltraitor-map"
const CURRENT_SCHEMA_VERSION := 3

var registry: MapSectionRegistry

func _init(p_registry: MapSectionRegistry) -> void:
	registry = p_registry

## Load a .map.json from disk. Returns {ok: bool, spec: Dictionary, errors: Array}.
## Never returns a half-loaded map: ok=false means spec is unusable, full errors list provided.
func load_file(path: String) -> Dictionary:
	var errors: Array = []

	if not FileAccess.file_exists(path):
		return {"ok": false, "spec": {}, "errors": ["File not found: %s" % path]}

	var file = FileAccess.open(path, FileAccess.READ)
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
			errors.append("Section '%s' failed migration" % section_id)
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

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not open for write: %s" % path]}
	file.store_string(JSON.stringify(out, "\t", false))  # sorted-key stringify (see Item 6 note)
	file.close()
	return {"ok": true, "errors": []}

## Loud-fail structural validation. Extend as new sections register their own checks
## via SectionOwner (v1.1+); v1 does coordinate/reference sanity only.
func _validate(spec: Dictionary) -> Dictionary:
	var errors: Array = []
	# Example baseline checks — extend per section as they're registered:
	if spec.get("id", "") == "":
		errors.append("Map has no id")
	return {"ok": errors.is_empty(), "errors": errors}
```

## Item 4 — Section owners for the five v1 sections

New file `godot/scripts/world/maps/persistence/map_sections_v1.gd`, registering `board`, `walls`, `blocks`, `props`, `actors`. Each owner is a thin adapter — serialize/deserialize are close to identity for v1 (no prior version to migrate from), but the **shape must exist now** so BLOCK-01 and PROP-01 have somewhere to register their richer fields later without touching the core service.

Example for `walls` (the one with the more interesting migration story — `"v": 2` is a **fictional but realistic** rehearsal migration, since real history starts at v1; use it to prove the chain mechanism works, not because a real v1 walls format ever shipped):

```gdscript
static func register_walls(registry: MapSectionRegistry) -> void:
	registry.register(MapSectionRegistry.SectionOwner.new(
		"walls",
		2,
		func(fragment: Dictionary) -> Dictionary:
			return { "edges": fragment.get("edges", []) },
		func(raw: Dictionary) -> Dictionary:
			return { "edges": raw.get("edges", []) },
		{
			# Rehearsal migration v1 -> v2: hypothetical old format lacked "storeys" per edge (defaulted to 1)
			1: func(old: Dictionary) -> Dictionary:
				var edges = old.get("edges", [])
				for e in edges:
					if not e.has("storeys"):
						e["storeys"] = 1
				return { "edges": edges }
		},
		func() -> Dictionary: return { "edges": [] }
	))
```

Register `board`, `blocks`, `props`, `actors` similarly at `"v": 1` (no migrations yet — empty `{}` migrations dict, which is correct and expected for a brand-new section).

`procedural` and `patches` (master plan §3.3) are **not sections in the registry** for v1 — they're top-level spec keys handled directly by the generator pipeline (MAPFILE-02+), since they don't describe static content but a *process*. Preserve them verbatim if present (pass through spec.sections is fine, or keep them as sibling keys to "sections" — pick one and document it; recommend: sibling keys, since "apply patches" is a pre-processing step before sections even exist, not a section itself). **This is a design fork — implement as sibling keys and note it explicitly in the completion report**, since it's a deviation-by-necessity from the master plan's literal JSON example (which nested them under `sections` for illustration only).

## Item 5 — `map_lint` headless tool

New file `godot/scripts/tools/map_lint.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MAP LINT")
	print("=".repeat(70) + "\n")

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)  # convenience wrapper registering board/walls/blocks/props/actors
	var service = MapFileServiceClass.new(registry)

	var dirs = ["res://maps/", "user://maps/"]
	var total := 0
	var failed := 0

	for dir_path in dirs:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			print("[LINT] (no directory: %s)" % dir_path)
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".map.json"):
				total += 1
				var full_path = dir_path.path_join(fname)
				var result = service.load_file(full_path)
				if result["ok"]:
					print("  ✓ %s" % full_path)
				else:
					failed += 1
					print("  ✗ %s" % full_path)
					for e in result["errors"]:
						print("      - %s" % e)
			fname = dir.get_next()
		dir.list_dir_begin()  # (list_dir_end not required in Godot 4 pattern; reuse loop var, adjust if API differs)

	print("\n%d checked, %d failed" % [total, failed])
	quit(0 if failed == 0 else 1)
```

## Item 6 — Golden round-trip test

`godot/scripts/tools/mapfile_roundtrip_test.gd`: build an in-memory spec matching the Item 1 example, `save_file()` to a temp path, `load_file()` it back, and assert the reloaded spec is structurally equal to the original (field-by-field; JSON key order is not guaranteed stable by `JSON.stringify`, so compare **parsed structures**, not raw text — note this explicitly, it's a common false-failure trap).

Second case in the same test: **tolerant round-trip proof (M3)** — hand-craft a `.map.json` string with an extra unknown section (`"future_section": {"v": 1, "mystery": true}`), load it, save it back, and assert the unknown section reappears unchanged. This is the test that proves requirement 4 mechanically, not just by architecture description.

Third case: **migration proof** — hand-craft a `walls` section at `"v": 1` (no `storeys` field on an edge), load it through the registered `walls` owner, and assert the loaded edge now has `storeys == 1` and the section reports `"v": 2`. Pair with a **red case**: strip the `1: func...` migration entry from a scratch copy of the registry, attempt to load the same v1 file, and assert `load_file()` returns `ok: false` with the "no migration from v1 to v2" error — this proves the loud-fail path, not just the happy path.

---

## Validation & Evidence (PASS criteria)

1. **Round-trip transcript** (Item 6, case 1): raw output showing saved → reloaded → structural equality assertion passing.
2. **Tolerant round-trip transcript** (case 2): unknown section preserved verbatim, pasted before/after.
3. **Migration RED + GREEN** (case 3): the red run (missing migration → loud fail) and green run (migration present → `storeys` backfilled, `v` bumped) both pasted verbatim.
4. **`map_lint` run** against an empty `res://maps/` (expect `0 checked, 0 failed`, not a crash) and against a folder with one hand-placed valid file and one hand-placed corrupt file (expect `1 checked... wait` — construct so totals are unambiguous: 2 checked, 1 failed, with the specific error printed).
5. `check_invariants.py` stays green (no interaction expected, but confirm no accidental breakage).
6. Design-fork note (Item 4, procedural/patches placement) explicitly written up in the completion report for authorial sign-off — this is a real deviation from the plan's literal example and should be seen, not buried.

## Implementation Checklist

- [ ] `map_section_registry.gd` — SectionOwner class + register/get_owner/migrate_section
- [ ] `map_file_service.gd` — load_file/save_file/_validate
- [ ] `map_sections_v1.gd` — board/walls/blocks/props/actors owners + `register_all()` convenience
- [ ] Decide & implement procedural/patches placement (sibling keys, recommended) — document the fork
- [ ] `map_lint.gd` headless tool
- [ ] `mapfile_roundtrip_test.gd` — 3 cases (plain round-trip, tolerant unknown-section, migration red+green)
- [ ] `res://maps/` and `user://maps/` directories created (empty is fine; `.gitkeep` for the res:// one)
- [ ] All transcripts captured verbatim
- [ ] Archive to `PROMPTS/DONE/`; bump VERSION

## Out of scope

`MapCatalog` wiring / `FileMapSource` (MAPFILE-02), exporting PLAYGROUND/SIGMA_01 as golden files (MAPFILE-02), the generator pipeline that actually consumes `procedural`/`patches` (post-MAPFILE-02), the map editor.

---

*End MAPFILE-01.*
