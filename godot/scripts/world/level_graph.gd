class_name LevelGraph
extends RefCounted
## Generates connectivity between the 9 segments of a 3×3 level grid.
##
## Grid positions: Vector2i(gx, gy) where gx, gy in [0, 2].
## Exit sides use the same naming convention as wall tiles: NW / NE / SW / SE.
##
## Level border restrictions (sides that face outside the level):
##   gx == 0  →  SW side locked
##   gx == 2  →  NE side locked
##   gy == 0  →  NW side locked
##   gy == 2  →  SE side locked
##
## generate() returns: Dictionary { Vector2i(gx,gy): Array[{"side": String, "cell": Vector2i}] }
## A segment with 1 exit entry is a dead end.
## A segment absent from the dict has no exits (isolated — content system should add a hatch).

const SEG_SIZE := Vector2i(18, 36)

## Canonical exit cell for each border side — midpoint of that border edge.
const EXIT_CELLS: Dictionary = {
	"NW": Vector2i(9, 0),
	"SE": Vector2i(9, 35),
	"SW": Vector2i(0, 17),
	"NE": Vector2i(17, 17),
}

var _rng    := RandomNumberGenerator.new()
var _parent: Dictionary = {}


## Generates a random spanning tree over all 9 segments, guaranteeing full connectivity.
## Same seed always produces the same layout.
func generate(seed_input: int) -> Dictionary:
	_rng.seed = seed_input
	_parent.clear()

	## Initialise Union-Find
	for gy: int in 3:
		for gx: int in 3:
			var pos := Vector2i(gx, gy)
			_parent[pos] = pos

	## All valid adjacent pairs: [seg_a, seg_b, side_on_a, side_on_b]
	## Horizontal neighbours share NE (right of a) / SW (left of b).
	## Vertical neighbours share SE (bottom of a) / NW (top of b).
	var edges: Array = []
	for gy: int in 3:
		for gx: int in 3:
			if gx < 2:
				edges.append([Vector2i(gx, gy), Vector2i(gx + 1, gy), "NE", "SW"])
			if gy < 2:
				edges.append([Vector2i(gx, gy), Vector2i(gx, gy + 1), "SE", "NW"])

	## Fisher-Yates shuffle
	for i in range(edges.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = edges[i]; edges[i] = edges[j]; edges[j] = tmp

	## Kruskal's — add edge only when it merges two disjoint components
	var connections: Dictionary = {}
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if _find(a) == _find(b):
			continue
		_union(a, b)
		var side_a: String = edge[2]
		var side_b: String = edge[3]
		if not connections.has(a): connections[a] = []
		if not connections.has(b): connections[b] = []
		connections[a].append({"side": side_a, "cell": EXIT_CELLS[side_a]})
		connections[b].append({"side": side_b, "cell": EXIT_CELLS[side_b]})

	return connections


## Returns the access_points array for a segment, ready to pass to build_layout().
## connections: the dict returned by generate().
## seg_pos: Vector2i(gx, gy) of the segment being built.
static func access_points_for(connections: Dictionary, seg_pos: Vector2i) -> Array[Dictionary]:
	var exits: Array[Dictionary] = []
	if connections.has(seg_pos):
		for exit: Dictionary in connections[seg_pos]:
			exits.append({"cell": exit["cell"]})
	return exits


## Returns true if the segment is a dead end (exactly 1 exit).
static func is_dead_end(connections: Dictionary, seg_pos: Vector2i) -> bool:
	return connections.has(seg_pos) and connections[seg_pos].size() == 1


## --- Union-Find -------------------------------------------------------------

func _find(x: Vector2i) -> Vector2i:
	if _parent[x] != x:
		_parent[x] = _find(_parent[x])
	return _parent[x]


func _union(a: Vector2i, b: Vector2i) -> void:
	_parent[_find(a)] = _find(b)
