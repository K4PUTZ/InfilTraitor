## PassageQuery — MATERIALS_MASTER_PLAN M3-2. "Can the agent get through this
## wall, and how?"
##
## PURE. It reads `Voxel.damage_state` and writes nothing — no caches, no
## signals, no side effects — so a prediction can ask it about a hypothetical
## world exactly the way the committed one is asked (PREDICTION_MASTER_PLAN's
## split: `build_plan()` is pure, `delta.commit()` is the only writer).
##
## THE RULE, Director 2026-08-21:
##
## > *"uma parede comum é feita de um par de slices, uma em cada GU anexas. Para
## > o agente passar agachado (ou transpor uma janela), é necessário que as duas
## > estejam desobstruídas. Se tiver 4 slices destruídas (2 pares empilhados), o
## > agente consegue entrar em pé."*
##
## ⚠️ THE UNIT THAT STACKS IS THE **STOREY**, not the voxel level, and that
## correction is the whole of M3-0. The Director's "slice" is *one storey of wall
## on one GU face* — this file calls it a **storey-face**. The code's `Slice`
## class is the WHOLE face across every storey (128 voxels at storey_count 2), a
## different object with the same name. Confusing the two is what made three
## earlier readings of this rule wrong.
##
## Checked, not transcribed: the baked agent is 222 px against
## `WALL_FLOOR_STEP_PX` 158 — **1.41 storeys tall**. A one-storey opening is 0.71
## of him (crouch); two storeys is 1.41x (standing).
##
## ⚠️ THIS ANSWERS GEOMETRY, NOT REACHABILITY. `passage_class()` says an opening
## of a given size exists somewhere in this wall; it does NOT say the agent can
## stand in front of it. A hole two storeys up is a window, and whether he can
## reach it is the movement system's question — which is why `clear_storeys()`
## is public and returns WHICH storeys are open, rather than this file quietly
## deciding that only an opening at storey 0 counts. The Director's own wording
## covers both cases in one sentence (*"passar agachado (ou transpor uma
## janela)"*), so the distinction is real and is not this query's to make.
class_name PassageQuery

## NONE < CROUCH < STANDING, and the ordering is load-bearing: callers compare
## (`>= PassageClass.CROUCH`) rather than matching every case, so a future class
## between them does not break them.
enum PassageClass { NONE = 0, CROUCH = 1, STANDING = 2 }

## ⚠️ A PASSAGE IS AN OPENING, NOT A DEMOLITION — Director, 2026-08-21:
## *"Vamos habilitar passagens em destruição incompleta, não precisa estar
## totalmente destruído, desde que tenha uma lógica visual razoável."*
##
## The first version of this query required EVERY cell of a storey-face clear.
## Measured on the real map, that bar never fires: a grenade at a plywood wall's
## base left the storey **60 of 64 cells open** and the query still answered
## NONE, because four voxels survived. The second version read "lógica visual
## razoável" as a CONTIGUOUS RUN of fully-clear columns, on the argument that
## sixty scattered cells are damage while four adjacent columns are a doorway.
##
## ⚠️ **THAT ARGUMENT IS OVERRULED — Director, 2026-08-28:**
##
## > *"Quantos voxels sobram individualmente não é importante para definir se a
## > passagem está aberta ou não. Podem ficar sobras decorativas, porém precisamos
## > ter mais ou menos uma noção de quantos voxels foram removidos pra aplicar a
## > abertura."*
##
## So the criterion is HOW MUCH OF THE STOREY-FACE IS GONE, and survivors inside
## the opening are scenery. Three things follow, and each one is the point:
##
##  - **Leftovers stop vetoing a doorway.** The run rule let a single surviving
##    voxel in the middle of a hole split one 8-wide opening into two 3-wide ones
##    and answer NONE. That is the 60-of-64 defect wearing a different costume.
##  - **It accumulates for free.** Voxel damage persists, so three grenades on the
##    same concrete wall add up to one fraction — *"se o jogador gastar 3 granadas
##    no mesmo lugar com concreto, supostamente abriria uma passagem também"* —
##    with no per-edge store, no accumulator and nothing to keep base-keyed.
##  - **The material stays the difficulty.** The same ruling explicitly refused a
##    forced opening (*"o material duro destroi menos, como já funciona"*): a
##    fabric curtain in a door frame loses nearly all of itself and opens on the
##    first grenade, concrete does not. **Nothing here forces a voxel to break.**
##
## What does NOT change is the pair rule (`MATERIALS_MASTER_PLAN` §3.2): a cell
## counts as gone only when it is gone on EVERY storey-face this edge has.
##
## ⚠️ AND THE RUN RULE IS REPLACED, NOT OR-ED WITH THE NEW ONE. Answering "open"
## when either test passes would keep the strict test's failures invisible and
## make the pair impossible to judge — the exact shape of the lenient-OR-strict
## defect the atom gate cost a session to.
##
## ⚠️ THE NUMBER IS NOT NEW, AND THAT IS DELIBERATE. 0.50 is the SAME doorway the
## 2026-08-21 ruling already ratified, restated in the unit that survived:
## `PASSAGE_MIN_WIDTH_POSITIONS` was 4 of a face's 8 positions at full storey
## height — *"a GU face is 8 positions, the agent occupies one GU, and HALF a face
## is an opening nobody would mistake for damage"* — which is 32 of 64 cells,
## exactly half the storey-face.
##
## So this change does not move the bar, it removes the SHAPE requirement from it,
## which is the whole of what the Director overruled. Anything that opened before
## still opens; what is new is that survivors inside the hole no longer veto it.
## Picking a fresh number here would have quietly changed two things at once and
## made the selftests impossible to read.
##
## A STAT (Rule 1), tuned against `[E-PASSAGE]`'s printed fractions on the real
## map rather than against taste.
static var PASSAGE_MIN_REMOVED_FRACTION: float = 0.50


## The best passage this edge offers. See `clear_storeys()` for where it is.
static func passage_class(edge: Edge, registry: EdgeRegistry) -> int:
	var open: Array[int] = clear_storeys(edge, registry)
	if open.is_empty():
		return PassageClass.NONE
	## Two STACKED storeys, not merely two clear ones: an opening at storey 0 and
	## another at storey 3 is two windows, not a doorway. `clear_storeys()` returns
	## ascending, so adjacency is a neighbour check.
	##
	## ⚠️ AND THEIR OPENINGS MUST STILL LINE UP — the overlap test SURVIVES the
	## 2026-08-28 ruling, restated in the new unit.
	##
	## What that ruling overruled is survivors INSIDE an opening vetoing it. Two
	## openings in DIFFERENT PLACES are a different claim and it is still false:
	## storey 0 open on the left and storey 1 open on the right is two windows, not
	## something to walk through upright, however much of the wall is gone in total.
	## A version of this without the check answered STANDING to exactly that
	## fixture, which is how the distinction was caught.
	##
	## Expressed with the same stat rather than a second one: a face POSITION
	## counts for a storey when most of its cells there are gone, and STANDING
	## wants the two storeys to share enough of them.
	var faces: Array = registry.slices_of_edge(edge.id)
	for i in range(open.size() - 1):
		if open[i + 1] != open[i] + 1:
			continue
		var lower: Dictionary = _open_positions(faces, open[i])
		var upper: Dictionary = _open_positions(faces, open[i + 1])
		var shared: int = 0
		for position in lower:
			if upper.has(position):
				shared += 1
		if float(shared) >= float(GeometryCoords.VOXELS_PER_UNIT_AXIS) \
				* PASSAGE_MIN_REMOVED_FRACTION:
			return PassageClass.STANDING
	return PassageClass.CROUCH


## The face POSITIONS (0..7) at which `storey` is mostly gone, as {position: true}.
##
## Position is `index % VOXELS_PER_UNIT_AXIS` — `SliceGenerator` builds each face
## as `for level: for position`, so the index is `level * 8 + position` and the
## modulo recovers the column. A cell counts as gone under the pair rule, same as
## everywhere else here.
static func _open_positions(faces: Array, storey: int) -> Dictionary:
	var width: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	var per_storey: int = GeometryCoords.LEVELS_PER_STOREY
	var intact: Dictionary = {}
	var present: Dictionary = {}
	for slice in faces:
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(per_storey))) != storey:
				continue
			var position: int = i % width
			present[position] = int(present.get(position, 0)) + 1
			if voxel.damage_state != Voxel.DamageState.DESTROYED:
				intact[i] = true
	var gone: Dictionary = {}
	for slice in faces:
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(per_storey))) != storey:
				continue
			if not intact.has(i):
				var position: int = i % width
				gone[position] = int(gone.get(position, 0)) + 1
	var out: Dictionary = {}
	for position in present:
		if float(gone.get(position, 0)) >= float(present[position]) \
				* PASSAGE_MIN_REMOVED_FRACTION:
			out[position] = true
	return out


## Every storey (absolute, matching `Voxel.level / LEVELS_PER_STOREY`) at which
## EVERY storey-face this edge actually has is clear. Ascending.
##
## ⚠️ "every storey-face this edge ACTUALLY has" is deliberate and is what makes
## this forward-compatible with half-thickness elements (§3.2b, M3-2b). A
## full-thickness wall has two; a fabric panel or a glass window will have ONE,
## and then "both sides clear" is satisfied by clearing the one that exists.
## Writing this against `slice_a` and `slice_b` by name would have had to be
## rewritten the day that lands — and worse, would have reported NONE forever for
## a half-thickness wall with a hole straight through it.
static func clear_storeys(edge: Edge, registry: EdgeRegistry) -> Array[int]:
	var out: Array[int] = []
	if edge == null or registry == null:
		push_error("[PassageQuery] clear_storeys() needs an edge and a registry.")
		return out
	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.is_empty():
		## FAIL CLOSED. An edge with no slice at all is not "wide open" — it is a
		## registry that has not been populated, and reporting STANDING here
		## would hand the movement system a passage through geometry nobody has
		## built yet. A real half-thickness element still has ONE slice.
		push_error("[PassageQuery] edge %s has no registered slice — reporting NONE rather than guessing." % edge.id)
		return out

	## ONE walk of the faces for every storey at once — the alternative (a
	## per-storey call into `_storey_cells()`) re-reads the same 128 voxels per
	## candidate storey, which is what this function's original note said a hot
	## movement query cannot afford, and what the run rule quietly did anyway.
	var table: Dictionary = _storey_table(faces)
	var storeys: Array = table.keys()
	storeys.sort()
	for storey in storeys:
		## A storey counts as passable when enough of it is GONE — see
		## PASSAGE_MIN_REMOVED_FRACTION for the ruling that replaced the run rule.
		var counts: Array = table[storey]
		if int(counts[1]) > 0 \
				and float(counts[0]) / float(counts[1]) >= PASSAGE_MIN_REMOVED_FRACTION:
			out.append(int(storey))
	return out


## How much of a storey-face is gone, 0.0 .. 1.0 — the criterion itself, public
## because it is also the diagnostic: a wall that did not open is only readable
## against how close it came, and `[E-PASSAGE]` prints this rather than a boolean.
##
## A storey nothing was ever built at returns 0.0, not 1.0. An absent wall is not
## an opening, which is `clear_storeys()`'s own fail-closed rule per cell.
static func removed_fraction(edge: Edge, registry: EdgeRegistry, storey: int) -> float:
	var counts: Array = _storey_cells(edge, registry, storey)
	var present: int = counts[1]
	if present <= 0:
		return 0.0
	return float(counts[0]) / float(present)


## DIAGNOSTIC — how OPEN a storey is, as a count of through-cells out of the 64
## in a storey-face (8 face positions x 8 levels).
##
## Kept alongside `removed_fraction()` rather than folded into it: this is the
## number the logs have quoted since M3-4 (*"widest base storey 60/64 cells
## open"*), and a fraction printed on its own hides how big the face it came from
## was. Both read the same count — see `_storey_cells()`.
static func clear_cells_in_storey(edge: Edge, registry: EdgeRegistry, storey: int) -> int:
	return _storey_cells(edge, registry, storey)[0]


## `[cells gone, cells present]` for one storey-face pair.
##
## A cell counts as GONE only when it is destroyed on EVERY storey-face the edge
## has — `MATERIALS_MASTER_PLAN` §3.2's pair rule, per cell, and the one part of
## this file the 2026-08-28 ruling did not touch. Indices are compared across
## faces because `SliceGenerator` builds every face the same way
## (`for level: for position`, index = level * 8 + position), so index i is the
## same physical spot on both sides of the wall.
static func _storey_cells(edge: Edge, registry: EdgeRegistry, storey: int) -> Array:
	if edge == null or registry == null:
		return [0, 0]
	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.is_empty():
		return [0, 0]
	return _storey_table(faces).get(storey, [0, 0])


## `{storey: [gone, present]}` for every storey these faces have, in one walk.
static func _storey_table(faces: Array) -> Dictionary:
	var intact: Dictionary = {}   ## storey -> {index: true} if ANY face still has geometry
	var present: Dictionary = {}  ## storey -> {index: true}
	var per_storey: int = GeometryCoords.LEVELS_PER_STOREY
	for slice in faces:
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			var storey: int = int(floor(float(voxel.level) / float(per_storey)))
			if not present.has(storey):
				present[storey] = {}
				intact[storey] = {}
			(present[storey] as Dictionary)[i] = true
			if voxel.damage_state != Voxel.DamageState.DESTROYED:
				(intact[storey] as Dictionary)[i] = true
	var out: Dictionary = {}
	for storey in present:
		var here: Dictionary = present[storey]
		var standing: Dictionary = intact[storey]
		var gone: int = 0
		for i in here:
			if not standing.has(i):
				gone += 1
		out[storey] = [gone, here.size()]
	return out


## Human-readable, for diagnostics and selftest output. Not a player-facing
## string — those go through `tr()` (CLAUDE.md), and nothing shows this to a
## player yet.
static func class_name_of(passage: int) -> String:
	match passage:
		PassageClass.CROUCH:
			return "CROUCH"
		PassageClass.STANDING:
			return "STANDING"
		_:
			return "NONE"
