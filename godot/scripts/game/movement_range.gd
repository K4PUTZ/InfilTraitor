class_name MovementRange
## Utility — compute reachable cells via Dijkstra, grouped by AP cost.
##
## Movement budget per turn:
##   1 AP  →  AP_MP movement points  (up to 3 tiles on normal terrain)
##   2 AP  →  2 × AP_MP              (two separate moves, up to 6 tiles total)
##   Dash  →  DASH_MP                (both AP spent on one move → bonus tile, up to 7)
##
## Terrain:  walkable dict  { Vector2i → int }
##   1 = normal tile    (costs 1 MP to enter)
##   2 = difficult tile (costs 2 MP to enter)

const AP_MP   := 3   ## Movement points granted per AP spent.
const DASH_MP := 7   ## Movement points when both AP spent as a single dash.

const DIRS := [
	Vector2i( 1,  0),
	Vector2i(-1,  0),
	Vector2i( 0,  1),
	Vector2i( 0, -1),
]


## Output of a range computation.
class Result:
	## Reachable with 1 AP      (path_cost ≤ AP_MP)
	var zone1: Dictionary = {}
	## Reachable with 2nd AP    (AP_MP < path_cost ≤ 2×AP_MP)
	var zone2: Dictionary = {}
	## Only reachable via dash  (2×AP_MP < path_cost ≤ DASH_MP)
	var dash:  Dictionary = {}


## Compute movement zones from `start` with `ap_remaining` AP.
## `walkable` maps Vector2i → int (movement cost per tile).
static func compute(start: Vector2i, walkable: Dictionary, ap_remaining: int) -> Result:
	var result := Result.new()
	if ap_remaining <= 0:
		return result

	var b1     := AP_MP
	var b2     := AP_MP * ap_remaining           # 3 if ap=1,  6 if ap=2
	var b_dash := DASH_MP if ap_remaining >= 2 else 0
	var b_max  := maxi(b2, b_dash)              # largest budget we ever explore

	# --- Dijkstra (small search area → sorted-array priority queue is fine) ---
	var dist: Dictionary = { start: 0 }
	var queue: Array     = [[0, start.x, start.y]]   # [cost, col, row]

	while not queue.is_empty():
		queue.sort()
		var item: Array = queue.pop_front()
		var cost: int   = item[0]
		var cur         := Vector2i(item[1], item[2])

		if cost > dist.get(cur, b_max + 1):
			continue   # stale entry

		for d: Vector2i in DIRS:
			var nb   := cur + d
			if not walkable.has(nb):
				continue
			var step: int = walkable[nb]
			var nc: int   = cost + step
			if nc > b_max:
				continue
			if nc < dist.get(nb, b_max + 1):
				dist[nb] = nc
				queue.append([nc, nb.x, nb.y])

	# --- Classify into zones ---
	for c: Vector2i in dist:
		if c == start:
			continue
		var v: int = dist[c]
		if v <= b1:
			result.zone1[c] = v
		elif v <= b2:
			result.zone2[c] = v
		elif b_dash > 0 and v <= b_dash:
			result.dash[c] = v

	return result
