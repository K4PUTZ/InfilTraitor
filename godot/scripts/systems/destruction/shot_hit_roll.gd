## ShotHitRoll — WEAPON_MASTER_PLAN D12's FIRST roll: does the shot hit the
## actor it was aimed at? The second roll (how much damage) is ShotPunchTable's
## and has shipped since 2026-08-02; this is the half that never existed.
##
## WHY IT EXISTS AS A REAL SEAM RATHER THAN AN `if false`. §6c Part C, in the
## Director's own scoping of this wave: the agent *"erra sempre o alvo (por
## enquanto)"* — but the always-miss has to run THROUGH the roll and force its
## outcome, not around it. A caller that skipped straight to the wall-damage
## path would be a second code path to delete the day the hit lands, and the
## deletion is the part that goes wrong. Forcing the outcome instead means the
## hit path is one enum away.
##
## WHAT IS DELIBERATELY NOT HERE. D12 is explicit that hittability is a STATS
## concern decoupled from what the sprite looks like: agent skill, cover,
## shadow, weapon level, powerups. None of those stats exist on any actor yet,
## so `chance_for()` below is a single named seam returning a placeholder, in
## the same spirit as WeaponBenchController._agent_skill() — one obvious place
## for the real terms to land, rather than a literal smeared across call sites.
##
## D32 will make the number player-facing (the cyclable target list's hit
## percentage). That is combat-phase surface and explicitly NOT this wave; the
## function it will read is this one.
##
## Tunables are `static var`, never `const` — architecture rule 1, and this file
## is a balancing lever like every other table beside it.
class_name ShotHitRoll

## The outcome vocabulary. An int enum rather than a bool because D12's second
## roll and future graze/critical rungs belong on the same axis, and a bool
## would have to be widened by every caller at once.
enum Outcome {
	MISS = 0,
	HIT = 1,
}

## Placeholder hit chance, 0.0–1.0. Neutral-ish on purpose: it is not calibrated
## against anything, because none of D12's real inputs are modelled yet. It is
## live code rather than a comment so that clearing FORCE_OUTCOME produces a
## working roll instead of a crash.
static var BASE_CHANCE: float = 0.55

## THE DEV OVERRIDE, and the reason this whole file is not a stub.
##
## D21 already describes the shape: *"a dev override forces 0% or 100% so a
## scenario replays."* `Outcome.MISS` is this wave's setting and is what makes
## the Director's *"erra sempre"* true; set it to -1 to let the roll decide, or
## to `Outcome.HIT` to force the other side once a hit path exists.
static var FORCE_OUTCOME: int = Outcome.MISS


## The chance this shot connects, before the roll. The seam D12's real terms
## land on — skill, cover, shadow, weapon level, powerups (§7c's four open
## balance questions are all about what goes in here, none about its shape).
static func chance_for(_shooter_skill: float, _distance_gu: float) -> float:
	return clampf(BASE_CHANCE, 0.0, 1.0)


## Roll it. Deterministic from `salt` via the project's standard FNV-1a hash,
## never an RNG — same contract as every other roll in the destruction stack
## (D22), so a scenario replays identically from the same inputs.
##
## Returns an `Outcome`. `FORCE_OUTCOME` short-circuits it when set, and the
## roll still runs first so a forced run and a free one traverse the same code.
static func roll(shooter_skill: float, distance_gu: float, salt: String) -> int:
	var chance: float = chance_for(shooter_skill, distance_gu)
	var u: float = float(FacadeSampler._fnv1a_hash("%s:TO_HIT" % salt) % 10000) / 10000.0
	var natural: int = Outcome.HIT if u < chance else Outcome.MISS
	if FORCE_OUTCOME == Outcome.MISS or FORCE_OUTCOME == Outcome.HIT:
		return FORCE_OUTCOME
	return natural
