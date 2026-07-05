## Geometry Module — Edge: logical wall between two adjacent Gameplay Units
## Canonical identity model: anchor = lexicographically smaller cell; face_a ∈ {SE, SW}
class_name Edge

var id: String                 ## canonical format: "EDGE_%d_%d_%s" % [gu_a.x, gu_a.y, Face.to_string_name(face_a)]
var gu_a: Vector2i             ## anchor cell (lexicographically smaller: x first, then y)
var gu_b: Vector2i             ## gu_a + Face.delta(face_a) — the adjacent cell
var face_a: int                ## face of gu_a toward the edge (always SE or SW)
var face_b: int                ## opposite(face_a) — face of gu_b toward the edge (always NW or NE)
var storey_count: int          ## number of vertical levels (height in storeys)
var material: String           ## material type: "concrete", "metal", "stone", "wood"
var slice_a_id: String = ""    ## backfilled by registry after slice A created
var slice_b_id: String = ""    ## backfilled by registry after slice B created


func _init(p_gu_a: Vector2i, p_gu_b: Vector2i, p_storey_count: int = 1, p_material: String = "concrete"):
	gu_a = p_gu_a
	gu_b = p_gu_b
	storey_count = p_storey_count
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
static func between(cell_1: Vector2i, cell_2: Vector2i, p_storey_count: int = 1, p_material: String = "concrete") -> Edge:
	# Normalize to canonical order (lexicographically smaller first)
	var canonical_a := cell_1
	var canonical_b := cell_2

	if (canonical_a.x > canonical_b.x) or (canonical_a.x == canonical_b.x and canonical_a.y > canonical_b.y):
		var temp := canonical_a
		canonical_a = canonical_b
		canonical_b = temp

	var edge := Edge.new(canonical_a, canonical_b, p_storey_count, p_material)
	
	# Validate that after canonicalization, face_a is SE or SW
	if edge.face_a != Face.SE and edge.face_a != Face.SW:
		push_error("Edge.between: canonicalization failed to set face_a ∈ {SE, SW}. face_a=%d" % edge.face_a)
	
	return edge


## Canonical string identity for hashing (baking, sampling).
## MUST be stable across runs: derived from GU coordinates, never from instance identity.
func key_string() -> String:
	return "E_%d_%d__%d_%d" % [gu_a.x, gu_a.y, gu_b.x, gu_b.y]


## For debugging
func _to_string() -> String:
	return "Edge{id='%s', gu_a=%s, gu_b=%s, face=%s, storeys=%d}" % [
		id, gu_a, gu_b, Face.to_string_name(face_a), storey_count
	]
