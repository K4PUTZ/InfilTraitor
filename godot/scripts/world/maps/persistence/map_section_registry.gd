## MapSectionRegistry — Anti-breakage core for tolerant round-trip serialization
##
## A section owner encapsulates everything the engine knows about a given section's
## internal shape: serialization, deserialization, and the migration chain from
## prior versions. The registry is the ONLY code that special-cases sections by name;
## the core load/save loop (MapFileService) is generic and never touches section internals.
##
## Adding a new section = one registration; adding a field to an existing section = one
## migration lambda. This mechanism satisfies requirement 4: "hard to break; keeps saving
## correctly after new sections are invented."

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

## Migrate one section's raw dict up to current_version.
## Applies the chain in order. Fails loudly (returns null + push_error) if a required
## migration step is missing.
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
