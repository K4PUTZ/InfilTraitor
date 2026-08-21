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
## NONE, because four voxels survived.
##
## "Lógica visual razoável" is taken literally here, and it is what stops this
## from being a bare percentage: a passage is a CONTIGUOUS RUN of face positions
## where the WHOLE STOREY HEIGHT is clear. Sixty scattered cells are damage; four
## adjacent columns you can see daylight through are a doorway. A count alone
## cannot tell those apart, so this does not use one.
##
## The width, and why it is not derived from the sprite. The baked agent measures
## 104 x 187 px (N facing, standing) — but converting sprite pixels to face
## POSITIONS runs through the 30°/45° isometric projection, where a horizontal
## span mixes two world axes and there is no clean ratio to quote. So rather than
## dress a guess as a measurement: a GU face is 8 positions, the agent occupies
## one GU, and HALF a face is an opening nobody would mistake for damage. `var`
## per architecture Rule 1 — this is a stat, and difficulty scaling may move it.
static var PASSAGE_MIN_WIDTH_POSITIONS: int = 4


## The best passage this edge offers. See `clear_storeys()` for where it is.
static func passage_class(edge: Edge, registry: EdgeRegistry) -> int:
	var open: Array[int] = clear_storeys(edge, registry)
	if open.is_empty():
		return PassageClass.NONE
	## Two STACKED storeys, not merely two clear ones: an opening at storey 0 and
	## another at storey 3 is two windows, not a doorway. And their runs must
	## OVERLAP — two gaps of the right width at opposite ends of the wall are two
	## crouch holes, not something to walk through upright. `clear_storeys()`
	## returns ascending, so adjacency is a neighbour check.
	for i in range(open.size() - 1):
		if open[i + 1] != open[i] + 1:
			continue
		var lower: Dictionary = _clear_columns(edge, registry, open[i])
		var upper: Dictionary = _clear_columns(edge, registry, open[i + 1])
		var both: Dictionary = {}
		for position in lower:
			if upper.has(position):
				both[position] = true
		if _widest_run(both) >= PASSAGE_MIN_WIDTH_POSITIONS:
			return PassageClass.STANDING
	return PassageClass.CROUCH


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

	## Group each face's voxels by storey ONCE, then intersect. The alternative
	## (walk every voxel per candidate storey) re-reads the same 128 voxels per
	## storey and is what a hot movement query cannot afford.
	var intact_storeys: Dictionary = {}   ## storey -> true if ANY face still has geometry there
	var present_storeys: Dictionary = {}  ## storey -> true if ANY face has voxels there at all
	for slice in faces:
		for voxel in slice.voxels:
			var storey: int = int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY)))
			present_storeys[storey] = true
			if voxel.damage_state != Voxel.DamageState.DESTROYED:
				intact_storeys[storey] = true

	var storeys: Array = present_storeys.keys()
	storeys.sort()
	for storey in storeys:
		## A storey counts as passable when it offers a contiguous run of clear
		## columns at least PASSAGE_MIN_WIDTH_POSITIONS wide — not when every one
		## of its 64 cells is gone. See that constant for the measurement that
		## forced the change.
		if _widest_run(_clear_columns(edge, registry, int(storey))) >= PASSAGE_MIN_WIDTH_POSITIONS:
			out.append(int(storey))
	return out


## The face POSITIONS (0..7) at which `storey` is clear through its full height,
## on every storey-face this edge has. A set, as {position: true}.
##
## Position is `index % VOXELS_PER_UNIT_AXIS` — `SliceGenerator` builds each
## slice as `for level: for position`, so the index is `level * 8 + position`
## and the modulo recovers the column.
static func _clear_columns(edge: Edge, registry: EdgeRegistry, storey: int) -> Dictionary:
	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.is_empty():
		return {}
	var width: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	var blocked: Dictionary = {}
	var seen: Dictionary = {}
	for slice in faces:
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) != storey:
				continue
			var position: int = i % width
			seen[position] = true
			if voxel.damage_state != Voxel.DamageState.DESTROYED:
				blocked[position] = true
	var out: Dictionary = {}
	for position in seen:
		if not blocked.has(position):
			out[position] = true
	return out


## Longest run of CONSECUTIVE positions in a column set. This is the whole of
## "lógica visual razoável": it is what separates a hole you can walk through
## from the same number of cells scattered along a wall.
static func _widest_run(columns: Dictionary) -> int:
	if columns.is_empty():
		return 0
	var sorted_positions: Array = columns.keys()
	sorted_positions.sort()
	var best: int = 1
	var run: int = 1
	for i in range(1, sorted_positions.size()):
		if int(sorted_positions[i]) == int(sorted_positions[i - 1]) + 1:
			run += 1
			best = maxi(best, run)
		else:
			run = 1
	return best


## DIAGNOSTIC — how OPEN a storey is, as a count of through-cells out of the 64
## in a storey-face (8 face positions x 8 levels).
##
## `passage_class()` asks a yes/no question with a very high bar: EVERY cell of
## the storey clear on every face that exists. M3-4 measured a base grenade on
## plywood and got NONE, so "how close was it" became the question that matters,
## and a boolean cannot answer it. A cell counts only when it is clear on every
## storey-face the edge has — the same "both sides" rule, per cell.
static func clear_cells_in_storey(edge: Edge, registry: EdgeRegistry, storey: int) -> int:
	if edge == null or registry == null:
		return 0
	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.is_empty():
		return 0
	var intact: Dictionary = {}   ## index -> true if ANY face still has geometry
	var present: Dictionary = {}
	for slice in faces:
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) != storey:
				continue
			present[i] = true
			if voxel.damage_state != Voxel.DamageState.DESTROYED:
				intact[i] = true
	var open_cells: int = 0
	for i in present:
		if not intact.has(i):
			open_cells += 1
	return open_cells


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
