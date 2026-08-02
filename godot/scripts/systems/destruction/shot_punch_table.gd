## ShotPunchTable — DESTRUCTION_MASTER_PLAN D30 (Director, 2026-08-02).
##
## ONE scalar decides everything a single projectile does to the scenery:
##
##     punch = PUNCH_GAIN x weapon_punch x skill x distance x luck / resistance
##
## Every factor is centred on 1.0, so a `punch` printed to the console is
## directly readable: 1.0 is "neutral shot, neutral agent, point blank, average
## luck, neutral material". That readability IS the requirement — Director:
## *"precisamos criar um coeficiente de destruição que seja fácil de mensurar e
## configurar."*
##
## WHY A NEW RESISTANCE TABLE INSTEAD OF MaterialResistanceTable's factors:
## those three numbers were calibrated as GROUP FRACTIONS ("what share of a ring
## group converts to this tier") and are consumed that way by
## apply_container_damage(). Reading them as a single-point divisor silently
## changes what they mean — metal's destroy_factor 0.05 would make a sniper
## round land below even the CRACKED threshold, i.e. bullets stop marking metal
## at all. Repurposing numbers tuned for another model is exactly the
## data-shape assumption CLAUDE.md's evidence rules warn about, so the point
## model gets its own explicit, separately tunable row set.
##
## All tunables are `static var`, not `const`: this whole file is a balancing
## lever (D6) and the Director asked for it to be configurable, which a `const`
## would prevent at runtime.
class_name ShotPunchTable

## Global calibration knob. Scales every weapon at once so the ladder below can
## be retuned without editing six JSONs.
static var PUNCH_GAIN: float = 3.0

## 1.0 = neutral. Ordering matches the canon resistance ordering already used by
## MaterialResistanceTable (metal > stone > concrete > wood), and glass is the
## soft outlier it is everywhere else. Placeholders, like every other balancing
## row in this project.
static var RESISTANCE: Dictionary = {
	"metal": 2.2,
	"stone": 1.6,
	"concrete": 1.3,
	"wood": 0.8,
	"glass": 0.4,
	"earth": 1.0,
}
static var DEFAULT_RESISTANCE: float = 1.3

## The ladder: punch -> what the impact voxel becomes. A stray shot ALWAYS
## leaves at least a mark (Director: *"O tiro errado sempre vai ter pelo menos
## uma marca de bala"*), so there is deliberately no "nothing happened" rung —
## below CRACK_MAX is the floor, not a miss.
static var PUNCH_DENT_MIN: float = 0.30      ## below this: CRACKED (simple mark)
static var PUNCH_DESTROY_MIN: float = 0.60   ## below this: DENTED (sunken mark)

## Neighbour destruction (D30.1): neighbours are DESTROYED or untouched, and
## NEVER take a mark of their own — that stays the projectile's alone. Count
## ramps linearly from 0 at NEIGHBOUR_PUNCH_START to all 8 at
## NEIGHBOUR_PUNCH_FULL, so "up to 8 voxels around" is the natural ceiling of a
## voxel's own 3x3 face patch rather than an arbitrary cap.
static var NEIGHBOUR_PUNCH_START: float = 1.0
static var NEIGHBOUR_PUNCH_FULL: float = 2.5
static var MAX_NEIGHBOURS: int = 8

## The second layer (the sibling slice's matching voxel) sees a reduced punch —
## it is behind a voxel that just absorbed the round.
static var PENETRATION_FALLOFF: float = 0.5

## D30.2 — neighbours cascade to the second layer only when the shot is
## enormous. Director: *"Não é algo para ser frequente, mas eventualmente vai
## ter uma bazuca, ou outra arma que deixa uma cratera na parede."*
##
## MEASURED, not reasoned: the arsenal's true worst case is an elite sniper on
## WOOD at point blank with max luck — 3.0 x 0.70 x 1.4 x 1.0 x 1.20 / 0.8 =
## 4.41, NOT the ~2.3 an earlier pass here estimated by only checking concrete.
## The threshold sits above that, so no shipped weapon can reach it and a future
## heavy one can. `test_no_shipped_weapon_reaches_the_cascade` pins this against
## the real JSONs, so adding a stronger weapon fails the suite rather than
## silently turning every rifle into a bazooka.
static var NEIGHBOUR_CASCADE_PUNCH: float = 5.0

## D30.4 — luck is a spread on DESTRUCTION, never on hit/miss (that is a
## separate roll the Director explicitly told us not to conflate). Its job is to
## stop every hole from looking identical; because soot is DERIVED from which
## voxels are absent (D24), varying destruction varies the scorch for free —
## derive_soot_rings() itself is a deterministic BFS with no randomness of its
## own.
static var LUCK_MIN: float = 0.85
static var LUCK_MAX: float = 1.20

## D30.3 — agent skill. A novice barely scratches, an elite punches through.
## The Director left the placement open (*"pode se refletir no dano da arma
## [...] ou ser refletido diretamente no quociente"*); it rides here, in the
## quotient, so there is exactly ONE place to read when a shot surprises you.
static var SKILL_NOVICE: float = 0.6
static var SKILL_NEUTRAL: float = 1.0
static var SKILL_ELITE: float = 1.4


static func resistance(material: String) -> float:
	return float(RESISTANCE.get(material, DEFAULT_RESISTANCE))


## Deterministic per-shot luck in [LUCK_MIN, LUCK_MAX], from the same FNV-1a
## the rest of the destruction stack uses (B4-pinned, so replays match).
static func luck_for(salt: String) -> float:
	var unit: float = float(FacadeSampler._fnv1a_hash("%s:LUCK" % salt) % 10000) / 10000.0
	return lerpf(LUCK_MIN, LUCK_MAX, unit)


## WHAT `step_multipliers` MEANS DEPENDS ON THE DELIVERY SHAPE — D1, ratified:
## for CONE the steps are DISTANCE BANDS from the muzzle, for LINE they are
## PENETRATION DEPTH through the wall's thickness. The two helpers below keep
## that distinction explicit at the call site, because collapsing them is a real
## bug that already happened once here: reading a rifle's table as distance made
## a sniper WEAKER at range than a pistol (measured on the bench, punch 0.54 at
## 11 GU), which inverts the entire point of the weapon.
##
## Indexed lookup for a CONE's distance bands. Past the table's end it holds the
## last entry rather than dropping to zero — a shot that outranges its falloff
## table still arrives, just weakly (D26: a miss keeps travelling regardless of
## distance).
static func cone_distance_multiplier(step_multipliers: Array, steps: int) -> float:
	if step_multipliers.is_empty():
		return 1.0
	var i: int = clampi(steps, 0, step_multipliers.size() - 1)
	return float(step_multipliers[i])


## How much punch survives reaching layer `depth` of a wall. For LINE this IS
## the weapon's step_multipliers (D1's penetration axis); for anything else the
## table means something different, so the flat PENETRATION_FALLOFF applies.
## depth 0 is the struck face and never attenuates.
static func penetration_multiplier(step_multipliers: Array, depth: int) -> float:
	if depth <= 0:
		return 1.0
	if depth < step_multipliers.size():
		return float(step_multipliers[depth])
	return PENETRATION_FALLOFF


## The whole coefficient, in one place. `distance_mult` arrives already resolved
## by the caller, because only the caller knows which delivery shape it is and
## therefore what its step table means.
##
## NOTE — LINE currently has NO distance falloff (callers pass 1.0). That is the
## honest state of the ratified data, not an oversight: a rifle's step table is
## spoken for by penetration, and no per-weapon RANGE curve exists in the
## schema. WEAPON_MASTER_PLAN D29 deferred the rifled weapons' range/dispersion
## modelling explicitly ("vamos trabalhar isso melhor depois"), and this is the
## seam it lands on when the Director takes it up.
static func compute(weapon_punch: float, material: String, skill: float,
		distance_mult: float, salt: String) -> float:
	return PUNCH_GAIN \
		* weapon_punch \
		* skill \
		* distance_mult \
		* luck_for(salt) \
		/ maxf(resistance(material), 0.001)


## punch -> DamageState for the IMPACT voxel (never for neighbours).
static func damage_state_for(punch: float) -> int:
	if punch < PUNCH_DENT_MIN:
		return Voxel.DamageState.CRACKED
	if punch < PUNCH_DESTROY_MIN:
		return Voxel.DamageState.DENTED
	return Voxel.DamageState.DESTROYED


## punch -> how many of the 8 face-plane neighbours go with it.
static func neighbour_count_for(punch: float) -> int:
	if punch < NEIGHBOUR_PUNCH_START:
		return 0
	var span: float = maxf(NEIGHBOUR_PUNCH_FULL - NEIGHBOUR_PUNCH_START, 0.001)
	var t: float = clampf((punch - NEIGHBOUR_PUNCH_START) / span, 0.0, 1.0)
	return clampi(int(roundf(t * float(MAX_NEIGHBOURS))), 0, MAX_NEIGHBOURS)
