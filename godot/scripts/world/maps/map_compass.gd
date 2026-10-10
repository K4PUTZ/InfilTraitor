## MapCompass — the compass of a map, DERIVED from its rectangle, never authored (CAPTURE_RAILS_MASTER_PLAN §3.2).
##
## `DIRECTION_GLOSSARY` §2-§4, at view N: the rectangle's corners are the compass VERTICES (N top, E right, S bottom, W left) and its
## sides carry the wall faces' names (NW = the x-min column, NE = the y-min row, SE = the x-max column, SW = the y-max row). These are
## BASE names: rotation is camera-only (R3D-ROT), so they never change with the view. Everything that names a direction of a map (an
## exit's side, the safe zone, a rail's framing) asks here; nobody writes `y == 0` again.
##
## Works on any `Rect2i` in any one space (the compiled `playable_rect` in raw GU is the usual one), so no buffer arithmetic lives here.
class_name MapCompass
extends RefCounted

const CORNERS: Array[String] = ["N", "E", "S", "W"]
const SIDES: Array[String] = ["NW", "NE", "SE", "SW"]

## The glossary's `edge_delta` per side: one GU step OUT of the rectangle across that side.
const OUTWARD: Dictionary = {"NW": Vector2i(-1, 0), "NE": Vector2i(0, -1), "SE": Vector2i(1, 0), "SW": Vector2i(0, 1)}


## The corner as a GU POINT (cell `i` spans `[i, i+1)`, so the far corners sit at `end`, not `end - 1`).
static func corner(name: String, rect: Rect2i) -> Vector2:
	match name:
		"N":
			return Vector2(rect.position)
		"E":
			return Vector2(rect.end.x, rect.position.y)
		"S":
			return Vector2(rect.end)
		"W":
			return Vector2(rect.position.x, rect.end.y)
	push_error("[MapCompass] corner: unknown corner '%s' (N, E, S, W)" % name)
	return Vector2(rect.position)


## The side a cell of the rectangle's border lies on; "" inside or outside. A corner cell lies on two sides: the first in `SIDES`
## order wins (NW, NE, SE, SW), so the answer is stable.
static func side_of(cell: Vector2i, rect: Rect2i) -> String:
	if not rect.has_point(cell):
		return ""
	if cell.x == rect.position.x:
		return "NW"
	if cell.y == rect.position.y:
		return "NE"
	if cell.x == rect.end.x - 1:
		return "SE"
	if cell.y == rect.end.y - 1:
		return "SW"
	return ""


## The side a cell OUTSIDE the rectangle faces (an access cell in the wall ring): the side whose outward step from the nearest
## border cell reaches it. "" when it is inside or diagonal to a corner.
static func side_facing(cell: Vector2i, rect: Rect2i) -> String:
	for side: String in SIDES:
		var inner: Vector2i = cell - (OUTWARD[side] as Vector2i)
		if side_of(inner, rect) != "" and _on_side(inner, side, rect):
			return side
	return side_of(cell, rect)


static func side_cells(side: String, rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not OUTWARD.has(side):
		push_error("[MapCompass] side_cells: unknown side '%s' (NW, NE, SE, SW)" % side)
		return out
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, y)
			if _on_side(c, side, rect):
				out.append(c)
	return out


static func outward(side: String) -> Vector2i:
	return OUTWARD.get(side, Vector2i.ZERO)


## A band `depth` GU deep along `side`, inside the rectangle, as a 2D rect in the same space (the safe zone of DESIGN §14.1).
static func band(side: String, rect: Rect2i, depth: int) -> Rect2i:
	var d: int = clampi(depth, 0, maxi(rect.size.x, rect.size.y))
	match side:
		"NW":
			return Rect2i(rect.position, Vector2i(mini(d, rect.size.x), rect.size.y))
		"NE":
			return Rect2i(rect.position, Vector2i(rect.size.x, mini(d, rect.size.y)))
		"SE":
			return Rect2i(Vector2i(rect.end.x - mini(d, rect.size.x), rect.position.y), Vector2i(mini(d, rect.size.x), rect.size.y))
		"SW":
			return Rect2i(Vector2i(rect.position.x, rect.end.y - mini(d, rect.size.y)), Vector2i(rect.size.x, mini(d, rect.size.y)))
	push_error("[MapCompass] band: unknown side '%s' (NW, NE, SE, SW)" % side)
	return Rect2i()


static func _on_side(cell: Vector2i, side: String, rect: Rect2i) -> bool:
	if not rect.has_point(cell):
		return false
	match side:
		"NW":
			return cell.x == rect.position.x
		"NE":
			return cell.y == rect.position.y
		"SE":
			return cell.x == rect.end.x - 1
		"SW":
			return cell.y == rect.end.y - 1
	return false
