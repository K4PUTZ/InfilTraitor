## BombDef — bomb/grenade definition resource.
## DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Mirrors PropDef's shape
## exactly (plain object + from_json() factory, not a Godot Resource) so
## multiple bomb types can be authored as data instead of hardcoded per
## detonation — "outras bombas terão um alcance maior ou menor, de acordo
## com o tipo, tamanho e habilidades de cada personagem" (Director, this
## session).
class_name BombDef

var id: String
## index 0 = the grenade's own GU/slice (max damage), each further index one
## ring further away (GU-adjacency for floor/actors, wall-run + storey
## adjacency for Slices/roofs — see BlastCalculator). Same table drives both;
## ring count IS the bomb's range. First-pass placeholder values — a
## balancing lever (DESTRUCTION_MASTER_PLAN D6), not a researched constant.
var ring_multipliers: Array[float] = []
var gameplay: Dictionary = {}
var tags: Array[String] = []


## Factory: parse BombDef from a JSON dict (file format) — same contract as
## PropDef.from_json().
static func from_json(data: Dictionary) -> BombDef:
	var def := BombDef.new()
	def.id = String(data.get("id", ""))

	def.ring_multipliers = []
	for m in data.get("ring_multipliers", [1.0]):
		def.ring_multipliers.append(float(m))

	def.gameplay = data.get("gameplay", {})

	def.tags = []
	for tag in data.get("tags", []):
		def.tags.append(String(tag))

	return def
