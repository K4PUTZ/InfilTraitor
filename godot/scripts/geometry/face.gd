## Geometry Module — Face enum and helpers
## Single source for face semantics (per DIRECTION_GLOSSARY §3, §6)
class_name Face

enum { NW, NE, SE, SW }

## Face → cell delta mapping (DIRECTION_GLOSSARY §3 table)
## NW: (-1, 0) — top-left edge
## NE: (0, -1) — top-right edge
## SE: (+1, 0) — bottom-right edge
## SW: (0, +1) — bottom-left edge
static func delta(face: int) -> Vector2i:
	match face:
		NW: return Vector2i(-1, 0)
		NE: return Vector2i(0, -1)
		SE: return Vector2i(1, 0)
		SW: return Vector2i(0, 1)
		_: push_error("Face.delta: invalid face %d" % face); return Vector2i.ZERO


## Opposite face pairs (DIRECTION_GLOSSARY symmetry)
## NW ↔ SE, NE ↔ SW
static func opposite(face: int) -> int:
	match face:
		NW: return SE
		NE: return SW
		SE: return NW
		SW: return NE
		_: push_error("Face.opposite: invalid face %d" % face); return -1


## Delta → face (reverse lookup, -1 for invalid)
static func from_delta(d: Vector2i) -> int:
	match d:
		Vector2i(-1, 0): return NW
		Vector2i(0, -1): return NE
		Vector2i(1, 0): return SE
		Vector2i(0, 1): return SW
		_: return -1


## Face → string name (for diagnostics and IDs)
static func to_string_name(face: int) -> String:
	match face:
		NW: return "NW"
		NE: return "NE"
		SE: return "SE"
		SW: return "SW"
		_: return "INVALID_%d" % face
