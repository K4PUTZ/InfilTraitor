## LiquidExposure — what standing in a liquid does to an agent, as pure functions of a liquid's `gameplay` block (`LiquidRegistry`).
##
## M6 F3 (`MATERIALS_MASTER_PLAN` §6). Director, 2026-10-17: lethal in the DEEP, much less on top, and the more contact the worse. So the agent
## carries a DOSE in 0..1: every step taken into a liquid and every turn ended inside one adds the liquid's rate for the depth (`shallow` up to
## `LiquidRegistry.SHALLOW_VOXELS` of depth, `deep` above), a turn spent out of it lowers the dose by `recovery`, and a dose of 1 is lethal. Deep
## water of a lethal liquid is not walkable at all (a blocked path: the player resolves it from outside, with a valve, a grate, a blast).
class_name LiquidExposure

const SHALLOW_VOXELS: float = 2.0     ## = LiquidRegistry.SHALLOW_VOXELS, kept as a float for the comparisons below
## One step is a third of an AP (`TacticalTurnManager.move_points_per_ap` = 3): a step into a liquid carries that share of its per-turn rate.
const STEP_SHARE: float = 0.34
## The share of a turn's dose an agent has taken when it merely walks THROUGH a liquid in one go versus standing in it at the turn's end.
const NO_DEPTH: float = 0.05


static func in_liquid(depth: float) -> bool:
	return depth > NO_DEPTH


static func is_deep(depth: float) -> bool:
	return depth > SHALLOW_VOXELS


## The dose per turn of `gameplay` at `depth` (0 for a harmless liquid, or when dry).
static func rate(gameplay: Dictionary, depth: float) -> float:
	if not in_liquid(depth) or not gameplay.has("exposure"):
		return 0.0
	var exposure: Dictionary = gameplay["exposure"]
	return float(exposure.get("deep" if is_deep(depth) else "shallow", 0.0))


## The dose after ONE STEP into the liquid.
static func after_step(dose: float, gameplay: Dictionary, depth: float) -> float:
	return clampf(dose + rate(gameplay, depth) * STEP_SHARE, 0.0, 1.0)


## The dose after a TURN that ended in the liquid (`depth` > 0) or out of it (`depth` = 0, the dose recovers).
static func after_turn(dose: float, gameplay: Dictionary, depth: float) -> float:
	if in_liquid(depth):
		return clampf(dose + rate(gameplay, depth), 0.0, 1.0)
	var recovery: float = float((gameplay.get("exposure", {}) as Dictionary).get("recovery", 0.0))
	return clampf(dose - recovery, 0.0, 1.0)


static func is_lethal(dose: float) -> bool:
	return dose >= 1.0


## The movement points ONE STEP into the liquid costs on top of the step's own point (a third of an AP each): the liquid's `wade_ap` is how
## slow it is, doubled in the deep, and a slippery liquid costs one more.
static func wade_points(gameplay: Dictionary, depth: float) -> int:
	if not in_liquid(depth):
		return 0
	var extra: int = int(gameplay.get("wade_ap", 0)) * (2 if is_deep(depth) else 1)
	if bool(gameplay.get("slippery", false)):
		extra += 1
	return extra


## A path may not enter this cell: deep water of a liquid that is lethal in the deep.
static func is_blocked(gameplay: Dictionary, depth: float) -> bool:
	return is_deep(depth) and rate(gameplay, depth) > 0.0


## AP lost at the start of a turn spent stuck in a trap liquid (mud, quicksand) that is deep enough to hold.
static func trap_ap(gameplay: Dictionary, depth: float) -> int:
	if not gameplay.has("trap") or not is_deep(depth):
		return 0
	return int((gameplay["trap"] as Dictionary).get("escape_ap", 0))
