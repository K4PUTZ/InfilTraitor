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

## EXPLOSION_REBUILD_MASTER_PLAN §4.2 (D1 rev, 2026-08-06) — per-tier ring
## gates, shared by floor/wall/ceiling. `ring_multipliers` above still gates
## *range* (flood_gu_rings() caps at ring_multipliers.size()-1); these gate
## *how much of each tier* a ring contributes — dented never appears in ring
## 2, cracked never in ring 0, that kind of shape. First-pass placeholders,
## same balancing-lever status as ring_multipliers.
var destroy_ring_weights: Array[float] = []
var dent_ring_weights: Array[float] = []
var crack_ring_weights: Array[float] = []
## Not consumed yet (Task 3/E-SOOT and the wave driver's job) — parsed now
## so the JSON schema is complete from the start.
var soot_ring_tones: Array[int] = []
var smoke_ring_weights: Array[float] = []

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

	def.destroy_ring_weights = []
	for m in data.get("destroy_ring_weights", []):
		def.destroy_ring_weights.append(float(m))

	def.dent_ring_weights = []
	for m in data.get("dent_ring_weights", []):
		def.dent_ring_weights.append(float(m))

	def.crack_ring_weights = []
	for m in data.get("crack_ring_weights", []):
		def.crack_ring_weights.append(float(m))

	def.soot_ring_tones = []
	for m in data.get("soot_ring_tones", []):
		def.soot_ring_tones.append(int(m))

	def.smoke_ring_weights = []
	for m in data.get("smoke_ring_weights", []):
		def.smoke_ring_weights.append(float(m))

	def.gameplay = data.get("gameplay", {})

	def.tags = []
	for tag in data.get("tags", []):
		def.tags.append(String(tag))

	return def
