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
	"brick": 1.15,
	"earth": 1.0,
	"wood": 0.8,
	"plywood": 0.6,
	"glass": 0.4,
	"cardboard": 0.35,
	"fabric": 0.3,
	## G-D16 / V-B — the glass family. A screen is ordinary glass with a tint and
	## a behaviour class, so it takes glass's own row; only ARMORED changes the
	## number, and the number is DERIVED from the shatter curve rather than
	## picked, because "resists common shots" (G-D15) is a statement about
	## P_shatter and nothing else.
	##
	## `glass_punch = PUNCH_GAIN(3.0) · weapon.punch / RESISTANCE`, and
	## GlassShatter.p_shatter has a flat bottom below ~1.5. At 0.80 the shipped
	## arsenal reads: pistol 1.05 -> 0%, assault rifle 1.88 -> ~1.5%, sniper
	## 2.63 -> ~15% (against 5%/44%/81% on plain glass). That is the shape G-D15
	## asks for — a common round does not take an armored pane, a sniper
	## sometimes does — WITHOUT the pane becoming invulnerable, which a resistance
	## up at stone's 1.6 would have made it (every shipped round under the flat
	## bottom, and the rifle pierce-and-prime case then unreachable by
	## construction).
	"glass_armored": 0.8,
	"glass_screen_green": 0.4,
	"glass_screen_red": 0.4,
	"glass_screen_amber": 0.4,
}
static var DEFAULT_RESISTANCE: float = 1.3

## The ladder: punch -> what the impact voxel becomes. A stray shot ALWAYS
## leaves at least a mark (Director: *"O tiro errado sempre vai ter pelo menos
## uma marca de bala"*), so there is deliberately no "nothing happened" rung —
## below CRACK_MAX is the floor, not a miss.
static var PUNCH_DENT_MIN: float = 0.30      ## below this: CRACKED (simple mark)

## ⚠️ BREACHING IS A SEPARATE MATERIAL PROPERTY FROM MARKING, and collapsing the
## two into one divisor is what made every weapon read the same on every wall.
##
## W-TUNE-02 (Director, 2026-08-20): *"Metal e pedra precisamos diferenciar fuzil
## de pistol, não dá pros dois deixarem a mesma marca... O importante é
## diferenciar as armas em cada material, de maneira que não fiquem sempre
## iguais."*
##
## WHY ONE GLOBAL NUMBER COULD NOT DO IT, measured rather than argued. `punch`
## already divides by RESISTANCE, so one threshold was supposed to serve every
## material. It cannot, because LUCK spans only 1.41x (0.85..1.20) while
## RESISTANCE spans 2.75x (0.8..2.2): each material's punch band is NARROW and
## the four bands barely overlap, so any single threshold falls either entirely
## above a band or entirely below it. You get 0% or 100%, never "a few". Real
## bands, one shotgun pellet: metal [0.28,0.39] · stone [0.38,0.54] ·
## concrete [0.47,0.67] · wood [0.77,1.08]. A threshold that gives concrete the
## three holes the Director asked for (0.64) puts EVERY wood pellet through.
##
## So RESISTANCE keeps meaning "how much punch does a mark on this cost", and
## this table means "how much punch does a HOLE in it cost" — two questions the
## same wall is entitled to answer differently. Concrete resists marking less
## than stone but breaches at a similar cost; wood marks easily and breaches
## easily; metal dents under anything and opens only to a rifle.
##
## Calibrated against the four PLAYGROUND blocks with the three shipped
## firearms — see the matrix in the session summary, not a formula.
static var DESTROY_MIN: Dictionary = {
	"metal": 0.55,     ## a rifle round defeats sheet metal; a pistol only dents it
	"stone": 0.80,     ## the rifle opens it, the shotgun and pistol never do
	"concrete": 0.63,  ## buckshot breaches on its best 3 pellets of 24
	"wood": 1.03,      ## the soft outlier: a pistol goes through, buckshot tears
	"glass": 0.30,     ## shatters to anything that reaches it
	## The screens share it; armored glass does not — a hole in it is a real
	## event, not the default outcome (G-D15's rifle pierce is the case that
	## PRIMES a pane, and it lands in V-C).
	"glass_screen_green": 0.30,
	"glass_screen_red": 0.30,
	"glass_screen_amber": 0.30,
	## V-D — DERIVED, not picked. `glass_punch = 3.0 · weapon.punch / 0.80`, so the
	## shipped arsenal lands at: smg 0.83 · shotgun pellet 0.90 · pistol 1.05 ·
	## revolver 1.31 · assault rifle 1.88 · sniper 2.63. A breach at **1.50** is
	## the only value that splits that list where G-D15 says it splits — *"resists
	## common shots"*, and *"a RIFLE round may pierce a single voxel"*. Below it
	## the round only CRACKS the pane (never DENTS — see damage_state_for), and
	## piercing without taking the pane is exactly the event that PRIMES it.
	##
	## ⚠️ It was 0.75 from V-B, which put every shipped round above the threshold:
	## a pistol holed armoured glass as readily as a sniper, and the pierce-and-
	## prime case could never be reached by anything but the whole arsenal at once.
	"glass_armored": 1.50,
	"earth": 0.75,
	## MAT-REG-01 (2026-08-21). These four are NOT hand-tuned against captures
	## the way the six above were — they are DERIVED, and the derivation is the
	## Director's own spec: *"os mais moles não vão destruir muito mais durante
	## os tiros, mas na explosão o fogo pega."* Softness is a FIRE property here,
	## not a bullet property.
	##
	## `punch` already divides by RESISTANCE, so halving a material's resistance
	## doubles its punch and would double what a shot destroys. Scaling the
	## breach threshold by the SAME factor cancels exactly that, holding the
	## destroyed fraction near its calibrated reference while the material still
	## marks more easily. Two references, one per family:
	##
	##     soft:    dm = 1.03 * 0.80 / r   (from wood)
	##     mineral: dm = 0.63 * 1.30 / r   (from concrete)
	##
	## They are placeholders in the same sense every row here is — the Director
	## calibrates against real captures once the facades land and the blocks are
	## placed. What they are NOT is a guess at what looks right.
	"brick": 0.71,     ## mineral, from concrete: 0.63 * 1.30/1.15
	##
	## MAT-SOFT-01 (2026-08-21) RETIRED the other three derived rows — plywood
	## 1.37, cardboard 2.35, fabric 2.75, all `1.03 * 0.80/r` from wood. They are
	## gone rather than zeroed because HOLE_ONLY_MATERIALS is now the single
	## source of that rule and destroy_min() answers 0.0 from it; a row here as
	## well would be a second place to change and a second place to forget. The
	## derivation itself was not wrong — it held the destroyed FRACTION near
	## wood's calibrated reference — it was answering a question the Director has
	## since closed differently: a soft material has no below-breach case at all.
}
## Fallback for a material with no row, and the value every non-firearm caller
## of damage_state_for() still gets. Between stone and earth on purpose: an
## unlisted material should be hard to breach, not free.
static var PUNCH_DESTROY_MIN: float = 0.80

## MAT-SOFT-01 (Director, 2026-08-21): *"Não vamos ter decals nos materiais moles
## porque eles não ficam cracked e nem dented, apenas furam ou queimam."*
##
## A material listed here has exactly TWO states under a projectile — INTACT and
## DESTROYED. It is not an art omission dressed up as data: a material with no
## authored decal family is NOT unmarked, it falls to the material-agnostic
## GENERIC family (VoxelRenderer._generic_flat_mark_plan), so leaving the tiers
## alone would have kept marking cardboard with a grey dent the Director had
## just ruled out.
##
## WHY THE THRESHOLD ALONE COULD NOT EXPRESS IT, which is the whole reason this
## array exists instead of three more rows in DESTROY_MIN. damage_state_for()
## returns CRACKED below PUNCH_DENT_MIN *before* it ever reads breach_min, so a
## breach of 0.0 still leaves the CRACKED floor underneath it — a weak hit on
## fabric would have gone on marking. The rule is a TIER capability, and the
## threshold is downstream of it.
##
## Director, same session, on what a weak hit does: **"sempre fura"** — a round
## that reaches fabric, cardboard or plywood goes through it. There is no
## below-breach case for these three, which is why destroy_min() answers 0.0 for
## them and their derived DESTROY_MIN rows were retired rather than kept as dead
## data disagreeing with this array.
##
## ⚠️ GLASS IS NOT HERE, deliberately. D22 gives it the same "no mark" half but
## the OTHER answer to the weak hit — *"é buraco feito, ou não feito"* — which
## needs an INTACT return this ladder has never produced and whose callers do not
## yet handle. Glass is M4b in MATERIALS_MASTER_PLAN, explicitly last, with its
## own crack/hole algorithm; it joins this mechanism there. Until then its
## recorded contradiction (a far shotgun pellet CRACKS glass) stands recorded,
## not silently half-fixed.
static var HOLE_ONLY_MATERIALS: Array[String] = ["fabric", "cardboard", "plywood"]

## Neighbour destruction (D30.1): neighbours are DESTROYED or untouched, and
## NEVER take a mark of their own — that stays the projectile's alone. Count
## ramps linearly from 0 at NEIGHBOUR_PUNCH_START to all 8 at
## NEIGHBOUR_PUNCH_FULL, so "up to 8 voxels around" is the natural ceiling of a
## voxel's own 3x3 face patch rather than an arbitrary cap.
## W-TUNE-02: retuned together with WeaponDef.blowout below. The ramp now starts
## well under 1.0 because the weapons that must NOT widen a hole are held out of
## it by `blowout`, not by the threshold — which is the only way to satisfy both
## halves of the Director's spec at once. The conflict, in one line: a pistol in
## wood (punch 0.89-1.26) must take ONE voxel, and a rifle in concrete (punch
## 0.98-1.39) must take FIVE. The two bands overlap, so no function of punch
## alone can separate them.
static var NEIGHBOUR_PUNCH_START: float = 0.65
static var NEIGHBOUR_PUNCH_FULL: float = 1.60
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

## ⚠️ THE CEILING ABOVE IS A FALLBACK NOW, NOT THE RULE — A0b, Director-ratified
## 2026-08-21: *"Vamos com o teto por material."*
##
## WHY ONE GLOBAL NUMBER STOPPED WORKING, arithmetically rather than by taste.
## The arsenal's worst case is an elite sniper at point blank with max luck:
##
##     3.0 (PUNCH_GAIN) x 0.70 (sniper) x 1.4 (SKILL_ELITE) x 1.0 x 1.20 (LUCK_MAX)
##       = 3.528, then divided by the material's RESISTANCE
##
## So ANY material with RESISTANCE below 3.528 / 5.0 = **0.706** reaches the
## ceiling with a shipped weapon, which is exactly what D30.2 says must not
## happen. That was already true before this table existed: `glass` sits at
## resistance 0.4 -> punch 8.82, and the selftest carried a hardcoded
## `if material == "glass": continue` with the note that the exclusion goes the
## day glass gets a real rule. Adding cardboard (0.35), fabric (0.3) and plywood
## (0.6) would have grown that exclusion list to five and left the pin pinning
## nothing.
##
## THIS IS A FLOOR-LIFTING EXCEPTION TABLE, NOT A REPLACEMENT, and that
## distinction is the whole design. Only materials whose worst case exceeds the
## global 5.0 get a row; metal, stone, concrete, brick and wood are ABSENT on
## purpose, so W-TUNE-02's calibrated matrix is untouched by this change.
##
## It deliberately does NOT scale as 1/resistance. Doing so would cancel the
## resistance term outright and make every material need the same weapon to
## crater, which is the opposite of the point — a bazooka should open cardboard
## more readily than steel. Each row is its own worst case plus ~15% headroom
## (the same margin the global 5.0 already had over wood's 4.41), so softness
## still buys you the cascade earlier: on these numbers cardboard cascades to a
## weapon roughly 2.7x weaker than metal does.
static var CASCADE_MIN: Dictionary = {
	"plywood": 6.8,    ## worst case 5.88 (3.528/0.60)
	"glass": 10.2,     ## worst case 8.82 (3.528/0.40) — retires the selftest exclusion
	## Same resistance, same worst case, same row. ⚠️ `glass_armored` is ABSENT on
	## purpose and that absence is the table's own rule working: at resistance
	## 0.80 its worst case is 4.41, under the global 5.0, so it needs no
	## floor-lifting exception. A row here would be a number pretending to do
	## something.
	"glass_screen_green": 10.2,
	"glass_screen_red": 10.2,
	"glass_screen_amber": 10.2,
	"cardboard": 11.6, ## worst case 10.08 (3.528/0.35)
	"fabric": 13.5,    ## worst case 11.76 (3.528/0.30)
}


## The punch at which a projectile's DESTROYED neighbours cascade into the
## second layer, for `material`. See CASCADE_MIN for why this is per material
## and why most materials are deliberately not in it.
static func cascade_min(material: String) -> float:
	return float(CASCADE_MIN.get(material, NEIGHBOUR_CASCADE_PUNCH))

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


## W-TUNE-02: the punch a single projectile needs to BREACH `material`, as
## opposed to merely mark it. See DESTROY_MIN's own note for why this is not
## derivable from resistance().
static func destroy_min(material: String) -> float:
	## MAT-SOFT-01: a hole-only material always breaches, so its threshold is
	## zero rather than absent — the fallback (0.80) would make the shot
	## diagnostic print a number that contradicts the tier the same shot
	## produced, and that print is what the Director calibrates off.
	if HOLE_ONLY_MATERIALS.has(material):
		return 0.0
	return float(DESTROY_MIN.get(material, PUNCH_DESTROY_MIN))


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
## `breach_min` is the material's own DESTROY_MIN; the default keeps every
## caller that has no material in hand on the global fallback.
## V-D — `glass_class` is `Slice.glass_class`, the map's per-placement override
## (G-D16: a screen is a control interface or a TV *per placement*). CLASS_UNSET
## means "use the material's default", which is every caller that has no slice.
static func damage_state_for(punch: float, breach_min: float = PUNCH_DESTROY_MIN,
		material: String = "", glass_class: int = GlassMaterials.CLASS_UNSET) -> int:
	## MAT-SOFT-01 — ahead of the CRACKED floor, because that floor is exactly
	## what a breach threshold cannot reach. `material` defaults to "" so every
	## caller that has no material in hand keeps the ladder it always had.
	if HOLE_ONLY_MATERIALS.has(material):
		return Voxel.DamageState.DESTROYED
	## G-D16 / V-C — an INDESTRUCTIBLE glass (a control interface) is the exact
	## opposite capability, and it is a TIER CEILING no threshold can express
	## either: *"trinca mas o tiro para"*. It never reaches DESTROYED and it never
	## DENTS (glass fractures, it does not deform — G-D3), so the whole ladder
	## collapses to its one rung. Ahead of the punch tests for the same reason
	## HOLE_ONLY is: a capability outranks a threshold.
	## ── GLASS: THE DENTED RUNG DOES NOT EXIST, AND NOW IT CANNOT (G-D3, V-D) ──
	##
	## D22 ruled glass DESTROYED-only; G-D3 amended it so CRACKED returns and
	## **DENTED stays impossible** — glass fractures, it does not deform. That was
	## true until V-D only by COINCIDENCE: `DESTROY_MIN["glass"]` and
	## `PUNCH_DENT_MIN` were both 0.30, so the band between them was empty.
	## §6.1 flagged that exact equality as needing a pin rather than trust, and
	## V-D is where it would have broken: raising `glass_armored`'s breach to 1.50
	## opens a band from 0.30 to 1.50 that every common round lands in, and an
	## armoured pane would have started DENTING — a tier glass has no art for and
	## no physics for.
	##
	## So the family's ladder is written out in full instead of inherited:
	## CRACKED below the breach, DESTROYED at or above it, and nothing else ever.
	if GlassMaterials.is_glass(material):
		if GlassMaterials.stops_a_round(material, glass_class):
			## A control interface: *"trinca mas o tiro para"*. A capability
			## outranks a threshold, exactly as HOLE_ONLY does at the other end.
			return Voxel.DamageState.CRACKED
		return Voxel.DamageState.CRACKED if punch < breach_min \
			else Voxel.DamageState.DESTROYED
	if punch < PUNCH_DENT_MIN:
		return Voxel.DamageState.CRACKED
	if punch < breach_min:
		return Voxel.DamageState.DENTED
	return Voxel.DamageState.DESTROYED


## punch -> how many of the 8 face-plane neighbours go with it.
##
## W-TUNE-02: `blowout` is the WEAPON's share of this — 1.0 for a round that
## fragments the wall around its hole (a rifle), 0.0 for one that punches a
## clean single-voxel hole (a pistol, and each individual shotgun pellet). It is
## a separate axis because punch alone cannot express it: see
## NEIGHBOUR_PUNCH_START's note for the two overlapping bands that force it.
static func neighbour_count_for(punch: float, blowout: float = 1.0) -> int:
	if punch < NEIGHBOUR_PUNCH_START or blowout <= 0.0:
		return 0
	var span: float = maxf(NEIGHBOUR_PUNCH_FULL - NEIGHBOUR_PUNCH_START, 0.001)
	var t: float = clampf((punch - NEIGHBOUR_PUNCH_START) / span, 0.0, 1.0)
	return clampi(int(roundf(t * float(MAX_NEIGHBOURS) * blowout)), 0, MAX_NEIGHBOURS)
