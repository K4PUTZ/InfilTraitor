## VoxelFire — a fire that lives on the VOXELS themselves, outside any blast's plan (M6, Director 2026-10-19: lava sets flammable voxels alight).
##
## The M3 fire is a blast's own plan (embers, char and consumption decided at the detonation). This is the small standalone one a liquid can start: a
## voxel that touches lava with `flammability` > 0 CATCHES, burns `burn_turns` liquid turns, and a burning voxel passes the fire to the flammable voxel
## beside it (the six neighbours) when that neighbour's flammability reaches `spread_min`, by a deterministic hash roll (`spread_chance`), never
## `randf()`. When its turns are up a voxel is either CONSUMED (the material's `burn_consumption` reaches `consume_min`: cardboard, cloth, carpet) or
## CHARRED (wood and plywood keep their body, blackened).
##
## Pure: the room hands it the lookups (`flammability_at`, `consumption_at`) and applies what `advance` returns, the way `LiquidCorrosion` works.
## `max_burning` caps the cost of a spreading fire (a fire is cheap per voxel, but a whole warehouse of crates is not free on the Moto).
extends RefCounted

const NEIGHBOURS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## Rule 1: stats are vars (difficulty scaling later).
var burn_turns: int = 2            ## liquid turns a voxel burns before it is consumed or charred
var spread_min: float = 0.8        ## the least flammability that catches from a burning neighbour (wood 1.4, plywood 1.5, cardboard 1.4, carpet 0.6)
var spread_chance: float = 0.6     ## the share of those that catch in a given turn
var consume_min: float = 0.5       ## `burn_consumption` at or above this: the voxel is eaten, below it: charred
var max_burning: int = 256

var _burning: Dictionary = {}      ## Vector3i -> turns burnt so far
var _spent: Dictionary = {}        ## Vector3i -> true once it burnt out (never lights twice)


func reset() -> void:
	_burning.clear()
	_spent.clear()


func burning_count() -> int:
	return _burning.size()


func is_burning(key: Vector3i) -> bool:
	return _burning.has(key)


## `key` catches fire (a voxel touching lava). Returns true when it is new.
func ignite(key: Vector3i) -> bool:
	if _burning.has(key) or _spent.has(key) or _burning.size() >= max_burning:
		return false
	_burning[key] = 0
	return true


## One liquid turn. `flammability_at` (Vector3i -> float, 0 for nothing flammable there / an empty cell) and `consumption_at` (Vector3i -> float) are the
## room's lookups. Returns {"lit": [keys that caught from a neighbour this turn], "consumed": [keys eaten], "charred": [keys blackened], "burning": [every key
## burning after the turn]}.
func advance(flammability_at: Callable, consumption_at: Callable) -> Dictionary:
	var lit: Array = []
	var consumed: Array = []
	var charred: Array = []
	## the spread first, from what was already burning before this turn (a fire never runs two cells in one turn)
	var sources: Array = _burning.keys()
	for key: Vector3i in sources:
		for d: Vector3i in NEIGHBOURS:
			var n: Vector3i = key + d
			if _burning.has(n) or _spent.has(n) or _burning.size() >= max_burning:
				continue
			if float(flammability_at.call(n)) < spread_min:
				continue
			if _roll(n) > spread_chance:
				continue
			_burning[n] = 0
			lit.append(n)
	for key: Vector3i in _burning.keys():
		var age: int = int(_burning[key]) + 1
		if age >= burn_turns:
			_burning.erase(key)
			_spent[key] = true
			if float(consumption_at.call(key)) >= consume_min:
				consumed.append(key)
			else:
				charred.append(key)
		else:
			_burning[key] = age
	return {"lit": lit, "consumed": consumed, "charred": charred, "burning": _burning.keys()}


## A deterministic unit roll per cell (FNV-1a, as every other pick that must repeat between runs).
static func _roll(key: Vector3i) -> float:
	return float(FacadeSampler._fnv1a_hash("VOXFIRE:%d:%d:%d" % [key.x, key.y, key.z]) % 1000) / 1000.0
