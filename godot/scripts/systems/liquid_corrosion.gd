## LiquidCorrosion — what a corrosive liquid does to the voxels it touches (M6 F5, Director 2026-10-18), counted in liquid turns of CONTACT.
##
## `gameplay.corrodes` lists what the liquid attacks, `gameplay.corrode_turns` how many turns of contact it takes:
## - `metal` (a voxel of the metal family: a grating's bars), `paper` / `cardboard` (the paper family), `cloth` (the fabric family): the voxel
##   DISSOLVES (destroyed, and what it held up falls by the support rule).
## - `floor` (the bed under the liquid) and `curb` (the sides that hold it), any other material: the voxel takes a CORROSION MARK (the crack decal)
##   and stays. Nothing opens by itself: the Director's rule that a body never spills over what holds it stands.
## The count of a voxel keeps what it reached while the level drops below it, and goes on when the liquid comes back.
##
## Pure: the room hands it, each turn, the voxels in contact (key -> category, `category_of`) and applies what it returns.
class_name LiquidCorrosion
extends RefCounted

const DISSOLVE: String = "dissolve"
const MARK: String = "mark"

var turns: int = 6
var _attacks: PackedStringArray = PackedStringArray()
var _count: Dictionary = {}     ## Vector3i (x, y, level) -> turns of contact so far
var _done: Dictionary = {}      ## Vector3i -> true once acted on


func setup(gameplay: Dictionary) -> void:
	_attacks = PackedStringArray(gameplay.get("corrodes", []))
	turns = maxi(int(gameplay.get("corrode_turns", 6)), 1)
	_count.clear()
	_done.clear()


func is_active() -> bool:
	return not _attacks.is_empty()


## What the liquid does to a voxel of `family` (`MaterialDef.family`), `on_bed` = it is the bed under the liquid: DISSOLVE, MARK or "" (untouched).
func category_of(family: String, on_bed: bool) -> String:
	match family:
		"metal":
			return DISSOLVE if _attacks.has("metal") else ""
		"paper":
			return DISSOLVE if _attacks.has("paper") or _attacks.has("cardboard") else ""
		"fabric":
			return DISSOLVE if _attacks.has("cloth") else ""
		"stone", "soil", "ceramic", "generic":
			if on_bed:
				return MARK if _attacks.has("floor") else ""
			return MARK if _attacks.has("curb") else ""
	return ""


## One liquid turn: `contacts` is every voxel in contact now (Vector3i -> DISSOLVE / MARK). Returns {DISSOLVE: [Vector3i], MARK: [Vector3i]}, the voxels
## whose count reached `turns` this turn (each one only once).
func tick(contacts: Dictionary) -> Dictionary:
	var out: Dictionary = {DISSOLVE: [], MARK: []}
	for key: Vector3i in contacts:
		if _done.has(key):
			continue
		var n: int = int(_count.get(key, 0)) + 1
		_count[key] = n
		if n >= turns:
			_done[key] = true
			_count.erase(key)
			(out[String(contacts[key])] as Array).append(key)
	return out


func count_of(key: Vector3i) -> int:
	return int(_count.get(key, 0))
