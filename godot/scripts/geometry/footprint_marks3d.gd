## FootprintMarks3D — the prints an agent leaves after walking out of a liquid (M6 F4, `MATERIALS_MASTER_PLAN` §6).
##
## Each liquid names a colour and a lifetime in TURNS (`gameplay.footprint`); a mark is placed on every dry cell the agent steps onto for a few
## steps after leaving it and fades over its lifetime, one turn at a time (`age_turn`), until it is gone. Cosmetic and NOT saved, like every floor
## mark; a guard will read them later (a clue). The art is PROCEDURAL (a boot sole, two variants mirrored), so it needs no file: ASSETS is not in
## the repository. Later footprints (puddles, mud, dog droppings: the props milestone) join through `mark()`.
class_name FootprintMarks3D
extends RefCounted

const FloorPileRef = preload("res://godot/scripts/geometry/floor_pile3d.gd")
const SIZE_GU: float = 0.5
const PRIORITY: int = 4
const LIFT: float = 0.024

var _pile: RefCounted = null
var _marks: Dictionary = {}     ## id -> {"turns": int, "age": int, "tint": Color, "centre": Vector2, "rot": float, "variant": int}
var _next_id: int = 0


func attach(board: Node3D) -> void:
	detach()
	_pile = FloorPileRef.new()
	_pile.attach(board, [_sole(false), _sole(true)], PRIORITY, LIFT, SIZE_GU * 0.5)


func detach() -> void:
	if _pile != null:
		_pile.detach()
	_pile = null
	_marks.clear()


func count() -> int:
	return _marks.size()


## A print at `centre`, `strength` (0..1) how marked it starts (the first print after a liquid is the strongest, each next one lighter), (raw GU, world X/Z) walking toward `heading` (a direction, radians in the ground plane), of colour `tint`, lasting `turns`.
func mark(centre: Vector2, heading: float, tint: Color, turns: int, level: int, left_foot: bool, strength: float = 1.0) -> void:
	if _pile == null or turns <= 0:
		return
	var id: int = _next_id
	_next_id += 1
	_marks[id] = {"turns": turns, "age": 0, "tint": tint, "centre": centre, "rot": heading, "variant": 1 if left_foot else 0, "level": level, "strength": strength}
	_pile.place(id, centre, level, int(_marks[id]["variant"]), 0.9 * strength, tint, heading)


## One turn passes: every mark fades by its share, and goes when it is gone.
func age_turn() -> void:
	if _pile == null:
		return
	for id in _marks.keys():
		var m: Dictionary = _marks[id]
		m["age"] = int(m["age"]) + 1
		if int(m["age"]) >= int(m["turns"]):
			_pile.remove(id)
			_marks.erase(id)
		else:
			_pile.place(id, m["centre"], int(m["level"]), int(m["variant"]), 0.9 * float(m["strength"]) * (1.0 - float(m["age"]) / float(m["turns"])), m["tint"], float(m["rot"]))


func clear() -> void:
	if _pile != null:
		_pile.clear()
	_marks.clear()


## A boot sole, white on transparent, 64 x 64: a long oval for the sole and a smaller one for the heel, mirrored for the other foot.
static func _sole(mirror: bool) -> Texture2D:
	var size: int = 64
	var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u: float = (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(size) * 2.0 - 1.0
			if mirror:
				u = -u
			## the sole (front of the foot, up the image) and the heel
			var sole: float = pow((u - 0.05) / 0.34, 2.0) + pow((v + 0.22) / 0.62, 2.0)
			var heel: float = pow((u + 0.02) / 0.26, 2.0) + pow((v - 0.62) / 0.26, 2.0)
			var inside: float = minf(sole, heel)
			var alpha: float = clampf((1.0 - inside) * 6.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
