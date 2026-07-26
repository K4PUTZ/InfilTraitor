## Consolidated edge key generation and wall blocking logic.
## Centralizes edge handling to prevent duplication and enable consistent future enhancements.
class_name WallEdgeData


## Canonical edge key — always orders the smaller cell first.
## Ensures that edge(A, B) == edge(B, A) in storage.
static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


## Returns true if movement between two adjacent tiles is wall-blocked.
static func is_edge_blocked(
	from_cell: Vector2i,
	to_cell: Vector2i,
	blocked_edges: Dictionary
) -> bool:
	return blocked_edges.has(edge_key(from_cell, to_cell))


## Returns true if LOS between two adjacent tiles is wall-blocked.
## Identical to movement for now — M2 will add partial walls.
static func blocks_los(
	from_cell: Vector2i,
	to_cell: Vector2i,
	blocked_edges: Dictionary
) -> bool:
	return is_edge_blocked(from_cell, to_cell, blocked_edges)
