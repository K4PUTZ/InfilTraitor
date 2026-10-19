## LiquidAgentStatus — what a liquid leaves ON the agent after the dose (M6 F5, the per-liquid rules ratified by the Director on 2026-10-18):
##
## - BURNING (oil in flames, lava: `ignites_agent` / `ignites`): `BURN_TURNS` turns, each turn's end adds `BURN_DOSE` to the dose; a liquid that
##   `extinguishes` (clean water, caribe) under the agent puts it out at once.
## - CHILLED (cryogenic: `status` "chilled"): every turn ENDED in it adds one point of chill, at most `CHILL_MAX`; a turn ended out of it takes one
##   away; the next turn starts with that many AP fewer.
## - MARKED (biohazard: `marks_agent`): the agent carries the stain for `MARK_TURNS` turns after the last contact (a guard's reaction is the AI milestone).
## - GLOWING (nuclear: `light.agent`): while the dose that liquid gave is above zero, the agent is a small cool light (a TACTICAL one: it counts for
##   the exposure).
## - SINKING (quicksand: `trap.sink_per_turn_when_still`): every turn ended in it WITHOUT having moved sinks the agent that many voxels; leaving
##   the liquid resets it. The sink is the depth the rules read for that liquid (so above `LiquidExposure.SHALLOW_VOXELS` it holds and is deep).
##
## Pure: the room feeds it the liquid under the agent at each step and at each turn's end and reads back what to apply. No node, no autoload.
class_name LiquidAgentStatus
extends RefCounted

const BURN_TURNS: int = 2
const BURN_DOSE: float = 0.25
const CHILL_MAX: int = 2
const MARK_TURNS: int = 5

var burning: int = 0           ## turns of fire left on the agent
var chill: int = 0             ## AP the next turn loses
var marked: int = 0            ## turns of biohazard stain left
var glow_kind: String = ""     ## the liquid whose dose makes the agent glow ("" = none)
var glow_spec: Dictionary = {} ## that liquid's `light.agent` ({radius, energy, warmth, tint})
var sink: float = 0.0          ## voxels sunk into a quicksand
var sink_kind: String = ""     ## the quicksand the agent stands in ("" = none)
var moved: bool = false        ## the agent stepped this turn (a still turn is what sinks it)


func reset() -> void:
	burning = 0
	chill = 0
	marked = 0
	glow_kind = ""
	glow_spec = {}
	sink = 0.0
	sink_kind = ""
	moved = false


## A quicksand's rule, or {} for any other liquid.
static func sink_rule(gameplay: Dictionary) -> Dictionary:
	var trap: Variant = gameplay.get("trap", null)
	if trap is Dictionary and float((trap as Dictionary).get("sink_per_turn_when_still", 0.0)) > 0.0:
		return trap
	return {}


## The `light.agent` block of a liquid ({} when it makes nobody glow).
static func agent_light(gameplay: Dictionary) -> Dictionary:
	var light: Variant = gameplay.get("light", null)
	if light is Dictionary and (light as Dictionary).get("agent", null) is Dictionary:
		return (light as Dictionary)["agent"]
	return {}


## The depth the rules must read for the agent in `info` (the liquid under it, `LiquidField.at_cell`): a quicksand's is how far the agent sank.
func rule_depth(info: Dictionary) -> float:
	if info.is_empty():
		return 0.0
	if not sink_rule(info["gameplay"]).is_empty():
		return sink if String(info["kind"]) == sink_kind else 0.0
	return float(info["depth"])


## One step onto the cell whose liquid is `info` ({} = dry); `on_fire` = that cell burns. Returns true when the agent caught fire on this step.
func on_step(info: Dictionary, on_fire: bool) -> bool:
	moved = true
	var caught: bool = false
	if info.is_empty():
		sink = 0.0
		sink_kind = ""
		return false
	var gameplay: Dictionary = info["gameplay"]
	if not sink_rule(gameplay).is_empty():
		if String(info["kind"]) != sink_kind:
			sink = 0.0
			sink_kind = String(info["kind"])
	else:
		sink = 0.0
		sink_kind = ""
	if bool(gameplay.get("extinguishes", false)):
		burning = 0
	elif (on_fire and bool(gameplay.get("ignites_agent", false))) or bool(gameplay.get("ignites", false)):
		caught = burning == 0
		burning = BURN_TURNS
	if bool(gameplay.get("marks_agent", false)):
		marked = MARK_TURNS
	var glow: Dictionary = agent_light(gameplay)
	if not glow.is_empty():
		glow_kind = String(info["kind"])
		glow_spec = glow
	return caught


## The turn spent STILL in a quicksand sinks the agent (call it before the turn's dose: the dose is the depth the agent ends the turn at).
func settle(info: Dictionary) -> void:
	if info.is_empty():
		return
	var rule: Dictionary = sink_rule(info["gameplay"])
	if not rule.is_empty() and String(info["kind"]) == sink_kind and not moved:
		sink += float(rule["sink_per_turn_when_still"])


## The dose of this turn's end is already applied by `LiquidExposure`; this adds the statuses. `info` is the liquid under the agent ({} = dry), `on_fire`
## that its cell burns, `dose` the dose after `LiquidExposure.after_turn`. Returns the dose to add on top (the fire on the agent).
func on_turn_end(info: Dictionary, on_fire: bool, dose: float) -> float:
	var extra: float = 0.0
	var gameplay: Dictionary = info["gameplay"] if not info.is_empty() else {}
	if bool(gameplay.get("extinguishes", false)):
		burning = 0
	elif not info.is_empty() and ((on_fire and bool(gameplay.get("ignites_agent", false))) or bool(gameplay.get("ignites", false))):
		burning = BURN_TURNS
	if burning > 0:
		extra += BURN_DOSE
		burning -= 1
	if String(gameplay.get("status", "")) == "chilled":
		chill = mini(chill + 1, CHILL_MAX)
	else:
		chill = maxi(chill - 1, 0)
	if bool(gameplay.get("marks_agent", false)):
		marked = MARK_TURNS
	elif marked > 0:
		marked -= 1
	var glow: Dictionary = agent_light(gameplay)
	if not glow.is_empty():
		glow_kind = String(info["kind"])
		glow_spec = glow
	if dose + extra <= 0.0:
		glow_kind = ""
		glow_spec = {}
	return extra


## A new turn: the AP the chill takes, and the agent has not moved yet.
func on_turn_start() -> int:
	moved = false
	return chill


func is_glowing() -> bool:
	return glow_kind != ""
