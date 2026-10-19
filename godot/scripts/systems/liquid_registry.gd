## LiquidRegistry — the liquids a designer can place: `liquids/<id>.json`, each a LOOK (and, later, the rules) as a table of named controls.
##
## M6 (2026-10-17). A liquid is data: `{id, note, params: {control: value}}`. The controls are the shader's uniforms (`water_study3d.gdshader`)
## under a schema (`PARAMS`: type, range, what it does), so a designer makes a variation by overriding a few of them on a placement, or a new
## liquid by copying a file, and a procedural generator can draw each control from its range. A bad row is reported with its path and lands in
## `load_errors` (`JsonFile`, AUDIT 2026-10-07); an unknown control or an out-of-range value is loud and never silent.
##
## Colours are `[r, g, b, a]` (or `[r, g, b]`), 0..1. `flow` is not a control: a placement carries it.
class_name LiquidRegistry

const DIR: String = "res://liquids"
const OWNER: String = "LiquidRegistry"

## control -> [type, min, max, what a designer gets]. Types: "int", "float", "color".
const PARAMS: Dictionary = {
	"mode": ["int", 0, 3, "which layers: 0 tint only, 1 + dots, 2 + surface (waves, foam, rings, bubbles), 3 both"],
	"flow_speed": ["float", 0.0, 1.5, "how fast the water (and what floats on it) travels along the flow, GU per second"],
	"time_scale": ["float", 0.0, 3.0, "the pace of the whole animation: 0 frozen (ice), 1 usual, 2 twice as fast"],
	"detail_strength": ["float", 0.0, 2.0, "how strongly dots, rings, bubbles, foam and glints read: low = soft, the bed shows through"],
	"wave_amount": ["float", 0.0, 2.0, "the colour bands and glints of the surface"],
	"ring_amount": ["float", 0.0, 2.0, "the ring ripples drifting on the surface"],
	"foam_amount": ["float", 0.0, 2.0, "the foam along the curbs"],
	"bubble_amount": ["float", 0.0, 2.0, "small bubbles on the surface: 0 none, 1 usual, 2 many"],
	"pop_bubbles": ["float", 0.0, 2.0, "slow bubbles that swell and burst with a ring"],
	"stipple_alive": ["float", 0.0, 1.0, "the dots (mode 1 or 3): HIGHER = FEWER dots; 0.42 is dense, 0.8 sparse"],
	"dot_cells": ["float", 4.0, 30.0, "the dots' grid per GU: lower = bigger dots"],
	"froth": ["float", 0.0, 1.5, "white foam patches, packed with tiny bubbles"],
	"scum": ["float", 0.0, 1.5, "floating clumps (algae, flesh, charred rock): how much of them"],
	"scum_cut": ["float", 0.3, 0.9, "clump threshold: HIGHER = sparser clumps"],
	"scum_scale": ["float", 1.0, 12.0, "clump size: LOWER = bigger clumps"],
	"junk": ["float", 0.0, 1.0, "floating rubbish (planks, cardboard, plastic, cans)"],
	"junk_skip": ["float", 0.0, 1.0, "HIGHER = fewer pieces of rubbish"],
	"oil": ["float", 0.0, 2.0, "iridescent oil slicks"],
	"oil_cut": ["float", 0.0, 1.0, "slick coverage: LOWER = the film covers more"],
	"glow": ["float", 0.0, 2.0, "slow pulsing bright patches (phosphorescence, heat)"],
	"caustics": ["float", 0.0, 2.0, "the sun's light network on the bed (clear shallows)"],
	"depth_shade": ["float", 0.0, 2.0, "the channel's depth: the curbs' shade and a deeper middle"],
	"crust": ["float", 0.0, 1.0, "plates covering the surface (cooled lava, ice floes): 0 none, 1 all"],
	"crack_scale": ["float", 1.0, 10.0, "plates per GU: HIGHER = smaller plates"],
	"rain": ["float", 0.0, 1.0, "rain rings on the surface (weather: any exposed water)"],
	"deep_color": ["color", 0.0, 1.0, "the colour of the deep part and its opacity (alpha)"],
	"shallow_color": ["color", 0.0, 1.0, "the colour of the shallow part and its opacity (alpha)"],
	"light_color": ["color", 0.0, 1.0, "foam, rings, bubbles, glints and glow"],
	"dirt_color": ["color", 0.0, 1.0, "the dots as specks of this colour (alpha 0 = the dots take light_color)"],
	"scum_color": ["color", 0.0, 1.0, "the floating clumps"],
	"scum_top_color": ["color", 0.0, 1.0, "the clumps' lit tops (alpha 0 = the clump colour brightened)"],
	"scum_rim_color": ["color", 0.0, 1.0, "a glowing rim on the clumps (alpha 0 = a dark rim)"],
	"crust_color": ["color", 0.0, 1.0, "the plates"],
	"crack_color": ["color", 0.0, 1.0, "the cracks between plates"],
}

## What a liquid DOES (data only for now; `FluidPlane` and the movement milestone consume it). Depth bands: SHALLOW is up to `SHALLOW_VOXELS`
## of depth, DEEP is above. EXPOSURE is a dose in 0..1 that grows each turn the agent is in the liquid (`shallow` / `deep` per turn: the more
## contact and the deeper, the worse), shrinks by `recovery` per turn out of it, and is lethal at 1. Director, 2026-10-17: lethal in the deep,
## much less on top.
const SHALLOW_VOXELS: int = 2
const GAMEPLAY_KEYS: PackedStringArray = ["fluidity", "wade_ap", "swim_ap", "noise", "smell", "slippery", "exposure", "status", "marks_agent", "footprint",
	"flammable", "fire", "ignites", "ignites_agent", "extinguishes", "corrodes", "corrode_turns", "light", "trap", "plates", "freezes_neighbours"]

static var load_errors: Array = []
static var _rows: Dictionary = {}     ## id -> {"note": String, "params": Dictionary}
static var _loaded: bool = false


static func reload() -> void:
	_rows.clear()
	load_errors.clear()
	_loaded = true
	for file_name: String in DirAccess.get_files_at(DIR):
		if not file_name.ends_with(".json"):
			continue
		var path: String = "%s/%s" % [DIR, file_name]
		var row: Dictionary = JsonFile.read_object(path, OWNER, load_errors)
		if row.is_empty():
			continue
		var id: String = JsonFile.require_id(row, path, OWNER, load_errors)
		if id.is_empty():
			continue
		var raw: Variant = row.get("params", {})
		if not (raw is Dictionary):
			push_error("[%s] %s: `params` must be an object; the row is skipped" % [OWNER, path])
			load_errors.append(path)
			continue
		var errors: Array = []
		var params: Dictionary = coerce(raw as Dictionary, path, errors)
		load_errors.append_array(errors)
		var gameplay: Variant = row.get("gameplay", {})
		if not (gameplay is Dictionary):
			push_error("[%s] %s: `gameplay` must be an object; ignored" % [OWNER, path])
			load_errors.append(path)
			gameplay = {}
		_rows[id] = {"note": String(row.get("note", "")), "params": params, "gameplay": check_gameplay(gameplay as Dictionary, path, load_errors)}


## THE RULES' SHAPE (consolidation, 2026-10-18): every reader of a `gameplay` block casts what it reads (`gameplay["exposure"] as Dictionary`, a footprint's
## colour as three numbers), so a value of the wrong shape was a SCRIPT ERROR in the middle of a step, far from the file. Each key is checked here, once,
## at load: a malformed one is loud (path, key, what it needs) and DROPPED, so the liquid behaves as if the file did not set it.
const _SCALAR: Dictionary = {"fluidity": "number", "wade_ap": "number", "swim_ap": "number", "noise": "signed", "smell": "signed", "slippery": "bool",
	"status": "string", "marks_agent": "bool", "flammable": "bool", "ignites": "bool", "ignites_agent": "bool", "extinguishes": "bool",
	"corrode_turns": "number", "freezes_neighbours": "bool"}
## A nested block: key -> {field: kind}; a field it does not name is loud too. "number" fields must be >= 0.
const _NESTED: Dictionary = {
	"exposure": {"shallow": "number", "deep": "number", "recovery": "number"},
	"footprint": {"color": "rgb", "turns": "number"},
	"fire": {"speed": "number", "burn": "number", "dose_step": "number", "dose_turn": "number", "light": "light", "base": "rgb", "base_share": "number"},
	"trap": {"escape_ap": "number", "sink_per_turn_when_still": "number"},
	"plates": {"walkable": "bool", "break_after_turns": "number"},
	"light": {"body": "light", "agent": "light"},
}
const _LIGHT: Dictionary = {"radius": "number", "spacing": "number", "energy": "number", "warmth": "number", "inner": "number", "tint": "tint"}
const CORRODE_TARGETS: PackedStringArray = ["metal", "paper", "cardboard", "cloth", "floor", "curb"]


static func check_gameplay(raw: Dictionary, where: String, errors: Array) -> Dictionary:
	var out: Dictionary = {}
	for key: String in raw:
		var value: Variant = raw[key]
		var problem: String = ""
		if value == null and GAMEPLAY_KEYS.has(key):
			continue    ## `null` says "none" (quicksand leaves no footprint): the key is simply not set
		if not GAMEPLAY_KEYS.has(key):
			problem = "unknown gameplay key (known: %s)" % ", ".join(GAMEPLAY_KEYS)
		elif _SCALAR.has(key):
			problem = _field_problem(value, String(_SCALAR[key]))
		elif key == "corrodes":
			if not (value is Array):
				problem = "needs a list of %s" % ", ".join(CORRODE_TARGETS)
			else:
				for item: Variant in value:
					if not (item is String) or not CORRODE_TARGETS.has(String(item)):
						problem = "'%s' is not one of %s" % [str(item), ", ".join(CORRODE_TARGETS)]
		elif _NESTED.has(key):
			problem = _block_problem(value, _NESTED[key])
		if problem != "":
			var message: String = "[%s] %s: gameplay '%s' = %s: %s; the key is dropped" % [OWNER, where, key, str(value), problem]
			push_error(message)
			errors.append(message)
			continue
		out[key] = value
	return out


static func _block_problem(value: Variant, fields: Dictionary) -> String:
	if not (value is Dictionary):
		return "needs an object with %s" % ", ".join(fields.keys())
	for field: String in value:
		if not fields.has(field):
			return "unknown field '%s' (known: %s)" % [field, ", ".join(fields.keys())]
		var problem: String = ""
		var kind: String = String(fields[field])
		if kind == "light":
			problem = _block_problem(value[field], _LIGHT)
		else:
			problem = _field_problem(value[field], kind)
		if problem != "":
			return "'%s' %s" % [field, problem]
	return ""


static func _field_problem(value: Variant, kind: String) -> String:
	match kind:
		"number":
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
				return "needs a number >= 0"
		"signed":   ## a noise or a smell may be negative: mud MUFFLES a step
			if not (value is float or value is int) or not is_finite(float(value)):
				return "needs a number"
		"bool":
			if not (value is bool):
				return "needs true or false"
		"string":
			if not (value is String):
				return "needs a text"
		"tint":
			if not (value is String) or not (String(value) in ["warm", "cool"]):
				return "needs \"warm\" or \"cool\""
		"rgb":
			if not (value is Array) or (value as Array).size() < 3:
				return "needs [r, g, b] in 0..1"
			for c: Variant in value:
				if not (c is float or c is int) or float(c) < 0.0 or float(c) > 1.0:
					return "needs [r, g, b] in 0..1"
	return ""


static func ids() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray(_rows.keys())
	out.sort()
	return out


static func has(id: String) -> bool:
	_ensure()
	return _rows.has(id)


## The rules of liquid `id` (see `GAMEPLAY_KEYS`), `{}` for a look with none.
static func gameplay(id: String) -> Dictionary:
	_ensure()
	return (_rows.get(id, {}) as Dictionary).get("gameplay", {})


## How freely the liquid flows, 0 (tar, quicksand) .. 1 (water): `FluidPlane` takes its acceleration and friction from it, and a grate lets
## only a thin liquid through. A look with no `gameplay` is as fluid as water.
static func fluidity(id: String) -> float:
	return float(gameplay(id).get("fluidity", 1.0))


static func note(id: String) -> String:
	_ensure()
	return String((_rows.get(id, {}) as Dictionary).get("note", ""))


## The controls of liquid `id` with `overrides` laid over them, each checked: `{control: float | int | Color}`. An unknown liquid is a loud error
## and answers `{}`.
static func resolve(id: String, overrides: Dictionary = {}) -> Dictionary:
	_ensure()
	if not _rows.has(id):
		push_error("[%s] unknown liquid '%s' (known: %s)" % [OWNER, id, ", ".join(ids())])
		return {}
	var out: Dictionary = (_rows[id]["params"] as Dictionary).duplicate()
	var errors: Array = []
	out.merge(coerce(overrides, "override of '%s'" % id, errors), true)
	return out


## Every control checked against `PARAMS`: a number clamped into its range (a warning when it was out), a colour read from 3 or 4 numbers.
## An unknown control or a malformed value is a loud error naming `where`, appended to `errors`, and dropped.
static func coerce(raw: Dictionary, where: String, errors: Array) -> Dictionary:
	var out: Dictionary = {}
	for key: String in raw:
		if not PARAMS.has(key):
			var message: String = "[%s] %s: unknown control '%s' (known: %s)" % [OWNER, where, key, ", ".join(PARAMS.keys())]
			push_error(message)
			errors.append(message)
			continue
		var spec: Array = PARAMS[key]
		var value: Variant = raw[key]
		match String(spec[0]):
			"color":
				var colour: Variant = _colour(value)
				if colour == null:
					var message_c: String = "[%s] %s: '%s' needs [r, g, b] or [r, g, b, a] in 0..1, got %s" % [OWNER, where, key, str(value)]
					push_error(message_c)
					errors.append(message_c)
					continue
				out[key] = colour
			_:
				if not (value is float or value is int):
					var message_n: String = "[%s] %s: '%s' needs a number, got %s" % [OWNER, where, key, str(value)]
					push_error(message_n)
					errors.append(message_n)
					continue
				var number: float = float(value)
				var clamped: float = clampf(number, float(spec[1]), float(spec[2]))
				if not is_equal_approx(clamped, number):
					push_warning("[%s] %s: '%s' = %s is outside %s..%s; clamped to %s" % [OWNER, where, key, str(number), str(spec[1]), str(spec[2]), str(clamped)])
				out[key] = int(round(clamped)) if String(spec[0]) == "int" else clamped
	return out


static func _colour(value: Variant) -> Variant:
	if value is Color:
		return value
	if not (value is Array):
		return null
	var items: Array = value
	if items.size() != 3 and items.size() != 4:
		return null
	for item: Variant in items:
		if not (item is float or item is int) or float(item) < 0.0 or float(item) > 1.0:
			return null
	return Color(float(items[0]), float(items[1]), float(items[2]), float(items[3]) if items.size() == 4 else 1.0)


static func _ensure() -> void:
	if not _loaded:
		reload()
