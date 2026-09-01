## GlassShatter — GLASS_MASTER_PLAN §5.1 (REWRITTEN 2026-08-31), G-D11.
##
## The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power, NOT a single
## `pane_shatter_punch` threshold. Every pellet or round that lands on a pane
## rolls its OWN chance `p_shatter(glass_punch)` to take the pane — or a region
## larger than its own hole (G-D12, the region flood — Stage B). A shotgun's 24
## pellets each roll and the pane's odds compound with the count, and it is
## legitimately possible that none of them shatter it.
##
## `glass_punch` is exactly `ShotPunchTable.compute(weapon.punch, "glass", …)` —
## the same coefficient the local hole already uses. At neutral skill / point
## blank / neutral luck it is `PUNCH_GAIN(3.0) · weapon.punch / RESISTANCE["glass"](0.4)`.
##
## THE CURVE: a shifted, renormalised logistic. The shift-and-clamp is what
## guarantees the "near-flat bottom" the Director asked for — a plain logistic's
## low tail never reaches zero, so an smg round would still shatter panes a few
## percent of the time. `s(p) - SHATTER_C` clamped at zero kills that tail
## outright; `/ (1 - SHATTER_C)` renormalises so the top still approaches
## `SHATTER_P_MAX`.
##
##     s(p) = 1 / (1 + e^(-SHATTER_K · (p - SHATTER_X0)))
##     p_shatter(p) = clamp( SHATTER_P_MAX · (s(p) - SHATTER_C) / (1 - SHATTER_C),
##                           0.0, SHATTER_P_MAX )
##
## DIRECTOR-APPROVED TARGET DISTRIBUTION (2026-08-31, neutral skill/luck), pinned
## by `glass_shatter_selftest` reading the shipped weapon JSONs within a
## tolerance — so a later balance edit to a weapon's `punch` fails the suite
## rather than silently turning a pistol into a pane-breaker:
##
##   | round               | glass_punch | P(shatter) target | this curve |
##   |---------------------|-------------|-------------------|------------|
##   | smg                 | 1.65        | ~0%               | 0.6%       |
##   | shotgun pellet (1)  | 1.80        | ~2%               | 2.0%       |
##   | pistol              | 2.10        | ~2.5%             | 5.5%       |
##   | revolver            | 2.63        | ~16%              | 14.3%      |
##   | assault rifle       | 3.75        | ~44%              | 43.8%      |
##   | sniper              | 5.25        | ~81%              | 81.1%      |
##   | shotgun blast (24×) | —           | ~38%              | 38.2%  = 1 - (1 - 0.020)^24 |
##
## The flat bottom is load-bearing: it is what keeps a shotgun's VOLUME (24 rolls
## at ~2%) its advantage over a pistol's single ~5% roll, and it is what keeps
## "none of the 24 shattered it" a real outcome. Pistol lands a touch high
## (5.5% vs 2.5%) — the target has a very sharp knee between punch 2.1 and 2.63
## that no smooth sigmoid catches; `SHATTER_C` is the knob for it and the
## Director calibrates against real play (Director, 2026-08-31: *"Boa — fixar
## como está"*).
##
## ALL TUNABLES ARE `static var`, not `const` (architecture Rule 1, and the same
## reason ShotPunchTable's are): this file is a balancing lever the Director
## dials at runtime.
class_name GlassShatter

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

static var SHATTER_K: float = 1.14       ## logistic steepness
static var SHATTER_X0: float = 3.79      ## logistic midpoint, in glass_punch units
static var SHATTER_C: float = 0.075      ## low-tail cut: s(p) below this rounds to 0 shatter chance
static var SHATTER_P_MAX: float = 0.98   ## ceiling — a common round never GUARANTEES a full shatter (only a primed armored pane does, G-D15)


## The probability that ONE projectile with this `glass_punch` shatters the whole
## pane (or, in Stage B, floods a region larger than its own hole). Monotonic in
## `glass_punch`, zero for a weak enough hit, capped at SHATTER_P_MAX.
static func p_shatter(glass_punch: float) -> float:
	var s: float = 1.0 / (1.0 + exp(-SHATTER_K * (glass_punch - SHATTER_X0)))
	var raw: float = SHATTER_P_MAX * (s - SHATTER_C) / maxf(1.0 - SHATTER_C, 0.001)
	return clampf(raw, 0.0, SHATTER_P_MAX)


## Deterministic per-projectile shatter roll. B4 FNV-1a on `salt` — the caller
## keys `salt` with `room._world_revision` and the projectile index (exactly as
## ShotPunchTable.luck_for does), so a replay of the same shot rolls the same
## outcome and two pellets of one blast roll independently.
##
## Returns true when this projectile takes the pane.
static func rolls_shatter(glass_punch: float, salt: String) -> bool:
	var p: float = p_shatter(glass_punch)
	if p <= 0.0:
		return false
	var unit: float = float(FacadeSamplerClass._fnv1a_hash("%s:GLASS_SHATTER" % salt) % 100000) / 100000.0
	return unit < p
