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
## NO LONGER CONSUMED ANYWHERE (S-KILL-STAMP, 2026-08-12). This was the tone
## table `stamp_container_soot()`/`stamp_crater_soot()` read, and the Director
## rejected the stamp on sight: *"a fuligem parece um monte de quadradinhos (...)
## fica muito forte por GUs, mas de repente na GU do lado não tem nada"* — which
## is structural, since the stamp ran once per container and so once per GU. Soot
## is a per-VOXEL stamp by distance since 2026-09-22 (SOOT-STAMP,
## `DetonationPlanBuilder._soot_ring_by_distance()`), and does not read this either.
##
## KEPT, not deleted, and the distinction is deliberate: this is authored tuning
## data sitting in every bomb's JSON, and dropping the field would be a data
## migration nobody asked for. Same call as `room._wall_height_edges` earlier the
## same day — cheap, correct on its own, and exactly what a future soot rule
## keyed on distance would want back. It is parsed and then ignored; if that ever
## stops being true, this comment is the thing to delete.
var soot_ring_tones: Array[int] = []
var smoke_ring_weights: Array[float] = []

var gameplay: Dictionary = {}
var tags: Array[String] = []

## What the bomb LOOKS like, one row for every copy of it (`"model"` in `bombs/<id>.json`; MOVEMENT_MASTER_PLAN §11.6 step 0,
## 2026-11-16). The weapons' ruling (HERITAGE T2 W2) holds here too: a bomb is ALWAYS the size it has in the Agent's hand, in
## the hand, in flight, on the floor and as the aim's ghost. `height_gu` is that size (the model's height in world units, the
## model scaled uniformly to it); `size_certified` is the day it was set by hand with the figure holding it ("" = not yet,
## and such a row WARNS when it loads).
var model_path: String = ""
var surface_materials: Dictionary = {}
var height_gu: float = 0.0
var size_certified: String = ""


## Factory: parse BombDef from a JSON dict (file format) — same contract as
## PropDef.from_json().
## The widest a bomb may reach, in GU rings (0 = its own GU). `flood_gu_rings()` and every per-ring table grow with it, so a row asking
## for more (a typo, or a user-tier bomb) is cut here, loudly, instead of flooding the map (AUDIT 2026-10-07). The shipped frag grenade
## uses rings 0..3. A var, not a const (rule 1: tuning values stay scalable).
static var MAX_RING: int = 16


## `errors` collects a per-ring table cut to `MAX_RING` (`JsonFile` style: loud, and the row still loads).
static func from_json(data: Dictionary, errors: Array = []) -> BombDef:
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

	var model: Variant = data.get("model", null)
	if model is Dictionary:
		var m: Dictionary = model
		def.model_path = String(m.get("path", ""))
		def.surface_materials = m.get("surface_materials", {})
		def.height_gu = float(m.get("height_gu", 0.0))
		def.size_certified = String(m.get("size_certified", ""))
		if def.model_path != "" and def.height_gu <= 0.0:
			var message := "[BombDef] bomb '%s' has a model and no height_gu: it cannot be drawn at its size" % def.id
			push_error(message)
			errors.append(message)
		elif def.model_path != "" and def.size_certified == "":
			push_warning("[BombDef] '%s': its size in the Agent's hand is not certified yet (MOVEMENT_MASTER_PLAN §11.6 step 0)" % def.id)

	for key: String in ["ring_multipliers", "destroy_ring_weights", "dent_ring_weights", "crack_ring_weights",
			"soot_ring_tones", "smoke_ring_weights"]:
		var table: Array = def.get(key)
		if table.size() > MAX_RING + 1:
			var message := "[BombDef] bomb '%s' %s has %d rings, past MAX_RING %d: cut to %d" % [
				def.id, key, table.size() - 1, MAX_RING, MAX_RING]
			push_error(message)
			errors.append(message)
			table.resize(MAX_RING + 1)

	return def
