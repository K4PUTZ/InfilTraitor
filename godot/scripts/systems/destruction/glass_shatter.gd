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
const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")

static var SHATTER_K: float = 1.14       ## logistic steepness
static var SHATTER_X0: float = 3.79      ## logistic midpoint, in glass_punch units
static var SHATTER_C: float = 0.075      ## low-tail cut: s(p) below this rounds to 0 shatter chance
static var SHATTER_P_MAX: float = 0.98   ## ceiling — a common round never GUARANTEES a full shatter (only a primed armored pane does, G-D15)

## G-D12 — THE REGION. A won shatter roll floods DESTROYED outward from the hit,
## over the pane's own voxels, radius scaled by `glass_punch`: a weak win takes a
## patch, a sniper takes the lot. On a SMALL pane any of these radii cover the
## whole thing → binary; on a LARGE pane the rest survives (same `pane_id`, still
## shatterable by a later hit). `region_radius = BASE + GAIN · (glass_punch − PIVOT)`,
## clamped to at least BASE. Placeholders like every balance row here — the
## Director calibrates against the GLASS map capture.
static var SHATTER_REGION_BASE: float = 3.0
static var SHATTER_REGION_GAIN: float = 6.0
static var SHATTER_REGION_PIVOT: float = 2.0

## G-D13 — THE REMNANT FLOOR. The frame ring (the pane's outermost column each
## way + its bottom and top level) keeps luck-driven survivors: *"nunca queremos
## que todos os voxels quebrem, sempre deixamos umas sobrinhas nas molduras."*
## Each border voxel the flood would take is spared with probability
## `lerp(KEEP_MIN, KEEP_MAX, luck)` — so "mais ou menos sobras" varies per event
## and still replays exactly — and at least `MIN_COUNT` border voxels always
## survive. A pane left with zero surviving border voxels is a bug (pinned by the
## selftest).
static var SHATTER_REMNANT_KEEP_MIN: float = 0.10
static var SHATTER_REMNANT_KEEP_MAX: float = 0.40
static var SHATTER_REMNANT_MIN_COUNT: int = 4

## STAGE C — the grenade/cook path. A pane INSIDE a blast's damage area breaks
## effectively (Director: *"Quebrar efetivamente quando estiver [dentro da área
## de dano]"*); one near it but outside only CRACKS (G5, deferred). The cook has
## no per-projectile punch, so the pane's shatter roll runs off the blast's own
## per-ring falloff: `blast_glass_punch = SHATTER_BLAST_GAIN · ring_multipliers[ring]
## / RESISTANCE["glass"]`, fed to the same `p_shatter()` / `rolls_shatter()` as a
## bullet. For frag_grenade (`ring_multipliers [1.0, 0.6, 0.25, 0.0]`) that is
## ~98% at ring 0, ~78% at ring 1, ~6% at ring 2, 0% at ring 3 — reliable inside,
## fading at the edge where G5's crack takes over. Glass PANEL slices are pulled
## OUT of the cook's ring-scatter entirely (glass fractures, it does not deform —
## a pane breaks whole or not at all); glass BLOCKS keep the ring model.
static var SHATTER_BLAST_GAIN: float = 3.4


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


## STAGE C — the effective `glass_punch` for a pane at ring `ring` of a blast
## whose per-ring falloff is `ring_multipliers`. Off the table's end (or a 0.0
## entry) it is 0 — the blast does not reach.
static func blast_glass_punch(ring_multipliers: Array, ring: int) -> float:
	if ring < 0 or ring >= ring_multipliers.size():
		return 0.0
	var m: float = float(ring_multipliers[ring])
	if m <= 0.0:
		return 0.0
	return SHATTER_BLAST_GAIN * m / maxf(ShotPunchTableClass.resistance("glass"), 0.001)


## G-D12 — the flood radius (in voxels, Chebyshev on the pane surface) for a won
## shatter roll at this `glass_punch`. At least SHATTER_REGION_BASE.
static func region_radius(glass_punch: float) -> int:
	var r: float = SHATTER_REGION_BASE + SHATTER_REGION_GAIN * (glass_punch - SHATTER_REGION_PIVOT)
	return maxi(int(roundf(r)), int(roundf(SHATTER_REGION_BASE)))


## G-D12 + G-D13 — plan the whole-pane (or region) shatter for a WON roll.
##
## `pane_slices` — every Slice sharing the hit's `pane_id` (a panel pane; glass
##   BLOCKS are deferred, they have no single run axis). `face` is the shared
##   face orientation, which fixes the pane's run axis: X for SW/NE, Y for SE/NW.
## `hit_grid_pos` / `hit_level` — the impact voxel, the flood origin.
## `glass_punch` — scales the region radius (region_radius()).
## `salt` — the shot's salt; the per-border-voxel survival rolls and the
##   luck-driven keep probability both hash off it, so the remnant pattern
##   replays exactly.
##
## Returns Array[{"slice": Slice, "voxel_index": int}] — the voxels to DESTROY,
## with the G-D13 frame-ring remnants already spared. Never returns a set that
## would leave the pane with zero surviving border voxels.
static func plan_pane_shatter(pane_slices: Array, face: int, hit_grid_pos: Vector2i,
		hit_level: int, glass_punch: float, salt: String) -> Array:
	## Run axis of the pane: X for {SW, NE}, Y for {SE, NW} — matches
	## GlassPaneGrouper's `Vector2i(absi(fd.y), absi(fd.x))`.
	var run_is_x: bool = (face == Face.SW or face == Face.NE)

	## Build the pane's own lattice of VISIBLE voxels, keyed by (col, level) where
	## `col` runs along the pane. A destroyed voxel is already a hole and is not a
	## flood candidate.
	var lattice: Dictionary = {}   ## Vector2i(col, level) -> {"slice": Slice, "voxel_index": int}
	var col_min: int = 1 << 30
	var col_max: int = -(1 << 30)
	var lvl_min: int = 1 << 30
	var lvl_max: int = -(1 << 30)
	for slice in pane_slices:
		for vi in range(slice.voxels.size()):
			var v: Voxel = slice.voxels[vi]
			## Already a hole (this shot's own local hole, or an earlier one) — not
			## a flood candidate, and not part of the border bounds.
			if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			var col: int = v.grid_pos.x if run_is_x else v.grid_pos.y
			var key := Vector2i(col, v.level)
			lattice[key] = {"slice": slice, "voxel_index": vi}
			col_min = mini(col_min, col)
			col_max = maxi(col_max, col)
			lvl_min = mini(lvl_min, v.level)
			lvl_max = maxi(lvl_max, v.level)
	if lattice.is_empty():
		return []

	var origin_col: int = hit_grid_pos.x if run_is_x else hit_grid_pos.y
	var origin := Vector2i(origin_col, hit_level)

	## BFS from the hit, Chebyshev radius. The origin itself (this shot's own
	## fresh hole) is not in `lattice`, but the walk still starts there and
	## expands into the surviving voxels around it — so a small radius takes a
	## patch and a large one takes the lot.
	var radius: int = region_radius(glass_punch)
	var flood: Dictionary = {}   ## Vector2i(col, level) -> true (voxels to destroy)
	var queue: Array = [origin]
	var dist: Dictionary = {origin: 0}
	if lattice.has(origin):
		flood[origin] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = int(dist[cur])
		if d >= radius:
			continue
		for dc in [-1, 0, 1]:
			for dl in [-1, 0, 1]:
				if dc == 0 and dl == 0:
					continue
				var nb := Vector2i(cur.x + dc, cur.y + dl)
				if dist.has(nb):
					continue
				dist[nb] = d + 1
				if lattice.has(nb):
					flood[nb] = true
					queue.append(nb)

	## G-D13 — spare the frame ring. `keep_prob` from the shot's luck.
	var luck_unit: float = float(FacadeSamplerClass._fnv1a_hash("%s:REMNANT_LUCK" % salt) % 100000) / 100000.0
	var keep_prob: float = lerpf(SHATTER_REMNANT_KEEP_MIN, SHATTER_REMNANT_KEEP_MAX, luck_unit)
	var border_in_flood: Array = []
	for k in flood.keys():
		var is_border: bool = k.x == col_min or k.x == col_max or k.y == lvl_min or k.y == lvl_max
		if is_border:
			border_in_flood.append(k)
	var spared: Dictionary = {}
	for k in border_in_flood:
		var u: float = float(FacadeSamplerClass._fnv1a_hash("%s:REMNANT:%d:%d" % [salt, k.x, k.y]) % 100000) / 100000.0
		if u < keep_prob:
			spared[k] = true
	## Hard floor: at least SHATTER_REMNANT_MIN_COUNT border voxels survive. If the
	## rolls spared too few, spare more — the ones the flood is furthest into a
	## corner of, by |col-mid| + |lvl-mid|, so the survivors read as frame
	## fragments rather than a random speckle.
	if spared.size() < SHATTER_REMNANT_MIN_COUNT and not border_in_flood.is_empty():
		var mid_col: float = float(col_min + col_max) * 0.5
		var mid_lvl: float = float(lvl_min + lvl_max) * 0.5
		var ranked: Array = border_in_flood.duplicate()
		ranked.sort_custom(func(a, b) -> bool:
			var da: float = absf(float(a.x) - mid_col) + absf(float(a.y) - mid_lvl)
			var db: float = absf(float(b.x) - mid_col) + absf(float(b.y) - mid_lvl)
			return da > db)
		for k in ranked:
			if spared.size() >= SHATTER_REMNANT_MIN_COUNT:
				break
			spared[k] = true

	var out: Array = []
	for k in flood.keys():
		if spared.has(k):
			continue
		out.append(lattice[k])
	return out
