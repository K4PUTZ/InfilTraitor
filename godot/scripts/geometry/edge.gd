## Geometry Module — Edge: logical wall between two adjacent Gameplay Units
## Canonical identity model: anchor = lexicographically smaller cell; face_a ∈ {SE, SW}
class_name Edge

var id: String                 ## canonical format: "EDGE_%d_%d_%s" % [gu_a.x, gu_a.y, Face.to_string_name(face_a)]
var gu_a: Vector2i             ## anchor cell (lexicographically smaller: x first, then y)
var gu_b: Vector2i             ## gu_a + Face.delta(face_a) — the adjacent cell
var face_a: int                ## face of gu_a toward the edge (always SE or SW)
var face_b: int                ## opposite(face_a) — face of gu_b toward the edge (always NW or NE)
var storey_count: int          ## number of vertical levels (height in storeys)
var start_storey: int          ## starting storey level (0 for walls, >0 for blocks with lower gaps)
var material: String           ## material type: "concrete", "metal", "stone", "wood"
var slice_a_id: String = ""    ## backfilled by registry after slice A created
var slice_b_id: String = ""    ## backfilled by registry after slice B created

## GLASS G-D9 (GLASS_MASTER_PLAN §9) — MULTI-MATERIAL SLICES.
##
## A sparse per-level override on `material`: `{rel_level: int -> material: String}`.
## `rel_level` is 0-based from THIS edge's own bottom (0 … storey_count*8 − 1),
## exactly as the mapfile `panels.bands` authoring spells it (§9.6). Empty for
## every ordinary wall — a normal edge pays nothing. `material` stays the BASE
## (the majority / dominant surface); any level not named here renders as `material`.
var material_bands: Dictionary = {}


func has_material_bands() -> bool:
	return not material_bands.is_empty()


## The material at one panel-relative level. Falls back to the base `material`
## for any level a band does not cover — so a caller can ask unconditionally.
func material_at(rel_level: int) -> String:
	return material_bands.get(rel_level, material)

## MATERIALS_MASTER_PLAN §3.2b — HALF-THICKNESS ELEMENTS.
##
## A normal wall is two voxels thick (D16): one storey-face on each of the two
## adjacent GUs. Fabric, cardboard, glass and plywood are **half thickness** —
## one face only, on one of the two GUs, preferably the inner one in the context
## of a room. A glass window covers one face and leaves the opposite face empty
## inside the opening, and that emptiness is what gives the reveal its depth.
##
## ⚠️ NEVER FAKE THIS BY PRE-DESTROYING ONE SIDE. A DESTROYED voxel is a hole
## with soot, a damage atom and a history; an ABSENT voxel is geometry that was
## never there. Conflating them corrupts the per-material census, D24's
## soot-from-absence derivation, and `PassageQuery` itself. The slice must never
## be created — which is why this lives on Edge, the only input SliceGenerator
## reads.
enum OccupiedSides { BOTH, A_ONLY, B_ONLY }

## Default BOTH, so every edge that existed before this field is unchanged by
## construction rather than by an audit.
var occupied_sides: int = OccupiedSides.BOTH


func _init(p_gu_a: Vector2i, p_gu_b: Vector2i, p_storey_count: int = 1, p_material: String = "concrete", p_start_storey: int = 0):
	gu_a = p_gu_a
	gu_b = p_gu_b
	storey_count = p_storey_count
	start_storey = p_start_storey
	material = p_material
	
	# Determine face from cells
	var delta := p_gu_b - p_gu_a
	var face := Face.from_delta(delta)
	
	if face == -1:
		push_error("Edge: cells are not 4-adjacent: gu_a=%s, gu_b=%s" % [p_gu_a, p_gu_b])
		# Fallback (should not reach here in production)
		face_a = -1
		face_b = -1
		id = "EDGE_INVALID"
		return
	
	# face is the direction FROM gu_a TO gu_b
	# In canonical form, face_a is always SE or SW (pointing downward/rightward)
	# If the calculated face is NW or NE, we need to swap the cells
	if face == Face.NW or face == Face.NE:
		var temp := gu_a
		gu_a = gu_b
		gu_b = temp
		face = Face.opposite(face)
	
	face_a = face
	face_b = Face.opposite(face)
	id = "EDGE_%d_%d_%s" % [gu_a.x, gu_a.y, Face.to_string_name(face_a)]


## Static constructor: normalizes input cell order, validates adjacency
static func between(cell_1: Vector2i, cell_2: Vector2i, p_storey_count: int = 1, p_material: String = "concrete", p_start_storey: int = 0) -> Edge:
	# Normalize to canonical order (lexicographically smaller first)
	var canonical_a := cell_1
	var canonical_b := cell_2

	if (canonical_a.x > canonical_b.x) or (canonical_a.x == canonical_b.x and canonical_a.y > canonical_b.y):
		var temp := canonical_a
		canonical_a = canonical_b
		canonical_b = temp

	var edge := Edge.new(canonical_a, canonical_b, p_storey_count, p_material, p_start_storey)
	
	# Validate that after canonicalization, face_a is SE or SW
	if edge.face_a != Face.SE and edge.face_a != Face.SW:
		push_error("Edge.between: canonicalization failed to set face_a ∈ {SE, SW}. face_a=%d" % edge.face_a)
	
	return edge


## §3.2c — resolve an AUTHORED ABSOLUTE GU CELL to a side, AFTER canonicalisation.
##
## ⚠️ THIS IS WHY THE MAPFILE MUST NOT CARRY A BOOLEAN. `_init()` canonicalises:
## if the face points NW or NE it SWAPS gu_a and gu_b so that gu_a sorts first
## and face_a ∈ {SE, SW}. So `slice_a` is not "the side the author meant" — it is
## whichever GU won the sort. A `side_a: true` field on the mapfile would
## therefore mean different things for different walls, silently, depending on
## which way the author drew them. That is the same defect class as the
## `P3_WEAPON`/`GRIP_SUFFIX` output collisions: a value correct at the author's
## end and wrong after a normalisation nobody remembers.
##
## An absolute cell survives the swap, because the swap moves the labels and not
## the cells. Returns false and changes nothing if the cell is not one of the
## two — a typo in a mapfile must not silently pick a side.
func set_occupied_gu(gu_cell: Vector2i) -> bool:
	if gu_cell == gu_a:
		occupied_sides = OccupiedSides.A_ONLY
		return true
	if gu_cell == gu_b:
		occupied_sides = OccupiedSides.B_ONLY
		return true
	push_error("[Edge] %s: occupied GU %s is neither gu_a %s nor gu_b %s — leaving both sides occupied."
		% [id, gu_cell, gu_a, gu_b])
	return false


## The absolute GU cell this edge's geometry sits on, or a sentinel when both do.
## The inverse of set_occupied_gu(), so a round trip through a mapfile is
## expressible without the caller re-deriving the canonicalisation.
func occupied_gu() -> Vector2i:
	match occupied_sides:
		OccupiedSides.A_ONLY:
			return gu_a
		OccupiedSides.B_ONLY:
			return gu_b
		_:
			return Vector2i(-1, -1)


## Does this edge have a storey-face on `gu_cell`? False for the cell a
## half-thickness element left empty, and false for a cell that is not one of
## the edge's two at all.
func occupies_cell(gu_cell: Vector2i) -> bool:
	if gu_cell == gu_a:
		return occupies_a()
	if gu_cell == gu_b:
		return occupies_b()
	return false


func occupies_a() -> bool:
	return occupied_sides != OccupiedSides.B_ONLY


func occupies_b() -> bool:
	return occupied_sides != OccupiedSides.A_ONLY


## True when this edge carries only one storey-face — a window pane, a curtain,
## a cardboard panel. Reads better at call sites than comparing the enum.
func is_half_thickness() -> bool:
	return occupied_sides != OccupiedSides.BOTH


## Canonical string identity for hashing (baking, sampling).
## MUST be stable across runs: derived from GU coordinates, never from instance identity.
func key_string() -> String:
	return "E_%d_%d__%d_%d" % [gu_a.x, gu_a.y, gu_b.x, gu_b.y]


## For debugging
func _to_string() -> String:
	if start_storey > 0:
		return "Edge{id='%s', gu_a=%s, gu_b=%s, face=%s, storeys=%d, start=%d}" % [
			id, gu_a, gu_b, Face.to_string_name(face_a), storey_count, start_storey
		]
	return "Edge{id='%s', gu_a=%s, gu_b=%s, face=%s, storeys=%d}" % [
		id, gu_a, gu_b, Face.to_string_name(face_a), storey_count
	]
