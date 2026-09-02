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
const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")

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

## G-D15 / V-C — armoured glass leaves FEWER hangers-on. Director: when it does
## go it *"usually shatters entirely at once, leaving many individual shards"* —
## many shards on the floor is the same statement as few remnants on the frame.
## Scales `keep_prob` only; G-D13b's conditional MIN_COUNT floor still applies,
## so an ANCHORED armoured pane still cannot be stripped completely bare.
static var SHATTER_REMNANT_ARMORED_SCALE: float = 0.35

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

## ── G-D17 — THE LAYER MODIFIER ───────────────────────────────────────────────
##
## Director, 2026-09-01: *"Precisamos implementar quebra em dois vidros seguidos,
## ou formalizar que vidros só podem ter meia espessura. Seria mais interessante
## pra engine a primeira opção, porque isso implica nos cubos sólidos de vidro.
## Adicionamos um modificador de destruição, de forma que cada camada de vidro a
## mais diminui a potência do projétil."*
##
## A LAYER is one thickness of glass the round passes through — the next pane
## along the ray, or the far face of a solid glass cube. The FIRST layer a round
## meets is depth 0 and is UNATTENUATED, so every number in the ratified arsenal
## table (§5.1) is untouched by construction: this only describes what is left
## after the round is already through some glass.
##
## GEOMETRIC, not subtractive, for two reasons that both matter:
##   · it can never go negative, so no clamp is hiding a sign error;
##   · it decays the way a real absorbing medium does — the same fraction per
##     layer — so a thick glass block stops a round by ARITHMETIC rather than by
##     a special case that says "blocks are different".
##
## At 0.62 a sniper (glass_punch 5.25, P 81%) reads 5.25 / 3.26 / 2.02 / 1.25
## across four layers: near-certain, likely, unlikely, and below SHATTER_C's flat
## bottom — it stops mattering at the fourth pane without any rule saying so.
## A `static var` like every other balance row here (architecture Rule 1).
static var SHATTER_LAYER_FALLOFF: float = 0.62


## The `glass_punch` that reaches the layer at `depth`, counting the first glass
## the round meets as depth 0.
##
## Used for BOTH halves of what a round does to a pane — the shatter roll and the
## region radius — because they are the same projectile: a round that arrives at
## the third pane too weak to shatter it must also be too weak to take a wide
## patch out of it. Feeding one and not the other is how a pane ends up "barely
## breaking" but taking half the wall with it.
static func punch_after_layers(glass_punch: float, depth: int) -> float:
	if depth <= 0:
		return glass_punch
	return glass_punch * pow(SHATTER_LAYER_FALLOFF, float(depth))


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
## ⚠️ `material` was the literal `"glass"` until the family existed (V-A left it
## as the last one standing), which quietly gave an ARMORED pane a common pane's
## odds against a grenade — the entire point of its RESISTANCE row is that it
## divides HERE. Defaulted to BASE so the pre-family callers and the selftest's
## own arsenal table are unchanged by construction.
static func blast_glass_punch(ring_multipliers: Array, ring: int,
		material: String = GlassMaterials.BASE) -> float:
	if ring < 0 or ring >= ring_multipliers.size():
		return 0.0
	var m: float = float(ring_multipliers[ring])
	if m <= 0.0:
		return 0.0
	return SHATTER_BLAST_GAIN * m / maxf(ShotPunchTableClass.resistance(material), 0.001)


## G-D12 — the flood radius (in voxels, Chebyshev on the pane surface) for a won
## shatter roll at this `glass_punch`. At least SHATTER_REGION_BASE.
static func region_radius(glass_punch: float) -> int:
	var r: float = SHATTER_REGION_BASE + SHATTER_REGION_GAIN * (glass_punch - SHATTER_REGION_PIVOT)
	return maxi(int(roundf(r)), int(roundf(SHATTER_REGION_BASE)))


## Lattice key of a voxel within its pane: (col, level), col along the run axis.
static func _pane_key(v: Voxel, run_is_x: bool) -> Vector2i:
	return Vector2i(v.grid_pos.x if run_is_x else v.grid_pos.y, v.level)


## G-D13b — every lattice position, ANYWHERE in the world, that holds NON-GLASS
## wall material and could anchor one of this pane's shards.
##
## Two sources, and the second is the reason this is not just "the pane's own
## bands": a pane set INTO a wall is anchored by the wall's slices at the GUs
## either side of it, which are different Slices on a different edge and never
## appear in `pane_slices`. `all_slices` is the whole registry
## (`room._edge_registry.all_slices()`); only slices on the SAME face and the
## same run line can be in the pane's plane at all, so the rest are skipped.
##
## Pure by construction — it takes slice lists, never the registry — so the
## selftest can hand it a synthetic frame and `plan_pane_shatter` stays a
## function of its arguments (the same rule PREDICTION_MASTER_PLAN holds
## `build_plan()` to).
static func collect_anchor_positions(pane_slices: Array, face: int, all_slices: Array) -> Dictionary:
	var anchors: Dictionary = {}
	if pane_slices.is_empty():
		return anchors
	var run_is_x: bool = (face == Face.SW or face == Face.NE)
	## The pane's own plane: same face, and the same coordinate on the axis the
	## run does NOT travel along.
	var plane_coord: int = pane_slices[0].gu_cell.y if run_is_x else pane_slices[0].gu_cell.x
	var pane_ids: Dictionary = {}
	for ps in pane_slices:
		pane_ids[ps.id] = true
	for s in all_slices:
		if s.face != face:
			continue
		var s_plane: int = s.gu_cell.y if run_is_x else s.gu_cell.x
		if s_plane != plane_coord:
			continue
		var s_base: int = GeometryCoordsMod.storey_level_base(s.start_storey)
		for v in s.voxels:
			if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			## A half-thickness element has ONE slice instead of two and is just as
			## much a frame — nothing here asks how thick the neighbour is, which
			## is what makes "half slices inclusive" true by construction.
			if GlassMaterials.is_glass(s.material_at(v.level - s_base)):
				continue
			anchors[_pane_key(v, run_is_x)] = true
	return anchors


## G-D12 + G-D13b — plan the whole-pane (or region) shatter for a WON roll.
##
## `pane_slices` — every Slice sharing the hit's `pane_id` (a panel pane; glass
##   BLOCKS are deferred, they have no single run axis). `face` is the shared
##   face orientation, which fixes the pane's run axis: X for SW/NE, Y for SE/NW.
## `hit_grid_pos` / `hit_level` — the impact voxel, the flood origin.
## `glass_punch` — scales the region radius (region_radius()).
## `salt` — the shot's salt; the per-voxel survival rolls and the luck-driven
##   keep probability both hash off it, so the remnant pattern replays exactly.
## `anchor_positions` — `collect_anchor_positions()`'s output. EMPTY means the
##   pane is free-standing, and then it may shatter to nothing.
##
## ── G-D13b (Director, 2026-09-01) supersedes G-D13's unconditional floor ──
##
## G-D13 spared survivors on the pane's own BOUNDING BOX (col_min/col_max/
## lvl_min/lvl_max) and forced at least MIN_COUNT of them, on the reading that a
## pane always has a frame. maps/GLASS.map.json's big pane does not: it is six
## GUs of glass with nothing around it, and it kept shards hanging in mid-air.
## Director: *"como essa vidraça não tem nada em volta, todos os cacos precisam
## cair. Então na verdade a regra é: alguns cacos devem sempre ficar sobrando,
## QUANDO estiverem conectados com qualquer outro material (half slices
## inclusive)."*
##
## So a remnant is ANCHORED or it is not a remnant. A flooded glass voxel is a
## survival candidate iff one of its four ORTHOGONAL lattice neighbours holds
## non-glass material — the pane's own G-D9 bands, or a neighbouring wall on the
## same edge line. Diagonals do not count: a corner is not something a shard
## hangs from. Glass never anchors glass. With no candidates the floor has
## nothing to apply to and the pane goes completely, which is the case that
## started this.
##
## ⚠️ THE FLOOR THE PANE STANDS ON IS NOT AN ANCHOR, deliberately. It is not in
## the pane's plane — it is a Slab below the wall — and counting it would keep a
## row of shards along the bottom of exactly the free-standing pane this rule
## exists to empty. Stated because it is an assumption, not a derivation.
##
## Returns Array[{"slice": Slice, "voxel_index": int}] — the voxels to DESTROY.
static func plan_pane_shatter(pane_slices: Array, face: int, hit_grid_pos: Vector2i,
		hit_level: int, glass_punch: float, salt: String,
		anchor_positions: Dictionary = {}) -> Array:
	## Run axis of the pane: X for {SW, NE}, Y for {SE, NW} — matches
	## GlassPaneGrouper's `Vector2i(absi(fd.y), absi(fd.x))`.
	var run_is_x: bool = (face == Face.SW or face == Face.NE)
	## G-D16 / V-C — the pane's BASE material, and it is safe to read from any one
	## slice: `GlassPaneGrouper` only unions slices that share it (two glass
	## materials are two panes), so a pane is single-material by construction.
	## Base, not `material_at()`: a G-D9 banded window is base glass with brick
	## bands, and the bands are frame here, never pane.
	var pane_material: String = pane_slices[0].material if not pane_slices.is_empty() \
		else GlassMaterials.BASE

	## Build the pane's own lattice of VISIBLE voxels, keyed by (col, level) where
	## `col` runs along the pane. A destroyed voxel is already a hole and is not a
	## flood candidate.
	## G-D13b: a banded pane (G-D9) keeps its brick sill and head in these SAME
	## slices, reached through `material_at()`. Those voxels are FRAME, not glass:
	## they are not flood candidates, the BFS does not travel through them, and
	## they anchor the shards next to them. Nothing consulted the material before,
	## so a sniper on the GLASS map's brick-capped window took 91 of its 96 brick
	## voxels with it — measured by glass_shatter_selftest [11] before this fix.
	var lattice: Dictionary = {}   ## Vector2i(col, level) -> {"slice", "voxel_index"} — GLASS only
	var own_frame: Dictionary = {} ## Vector2i(col, level) -> true — this pane's non-glass bands
	for slice in pane_slices:
		var slice_base: int = GeometryCoordsMod.storey_level_base(slice.start_storey)
		for vi in range(slice.voxels.size()):
			var v: Voxel = slice.voxels[vi]
			## Already a hole (this shot's own local hole, or an earlier one) — not
			## a flood candidate, and nothing left to anchor.
			if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			var key := _pane_key(v, run_is_x)
			if not GlassMaterials.is_glass(slice.material_at(v.level - slice_base)):
				own_frame[key] = true
				continue
			## ⚠️ THE LATTICE KEY DROPS THE THICKNESS AXIS. `_pane_key()` is
			## (col, level) — for an SW/NE pane that is (grid_pos.x, level), and the
			## row (grid_pos.y) is gone. Today that is safe and load-bearing: a glass
			## PANEL is half-thickness and has exactly ONE slice per GU (G7's own
			## note in blast_calculator), so no two voxels of a pane share a key —
			## verified on the real map, where the 6 GU x 3 storey pane is 48 cols x
			## 24 levels = 1152 voxels, one slice's worth per GU.
			##
			## The day a FULL-thickness glass wall or a PANE_BLOCK_* exists, two
			## voxels would collide here and the second would silently overwrite the
			## first — half the pane would never break, with no error anywhere. B6:
			## fail loudly at that seam instead of shattering half a wall.
			if lattice.has(key):
				push_error("[GlassShatter] pane %s has two glass voxels on lattice key %s — the (col, level) key drops the thickness axis and only holds for a HALF-THICKNESS pane. A full-thickness or block pane needs a 3-D key before it can shatter." % [slice.pane_id, key])
				return []
			lattice[key] = {"slice": slice, "voxel_index": vi}
	if lattice.is_empty():
		return []

	var origin_col: int = hit_grid_pos.x if run_is_x else hit_grid_pos.y
	var origin := Vector2i(origin_col, hit_level)

	## BFS from the hit, Chebyshev radius. A small radius takes a patch, a large
	## one takes the lot.
	##
	## ⛔ THE WALK TRAVELS THROUGH HOLES AND STOPS AT FRAME, AND THOSE ARE TWO
	## DIFFERENT ABSENCES FROM `lattice` (fix 2026-09-01).
	##
	## It used to queue a neighbour only `if lattice.has(nb)` — i.e. only onto
	## SURVIVING glass — with a comment claiming the walk "still starts there and
	## expands into the surviving voxels around it". That holds for a ONE-voxel
	## hole and collapses for any other: the origin is this shot's own fresh hole,
	## a rifle-class round takes 2–4 voxels plus the cascade (G-D14), so every cell
	## around the origin is gone too, the queue empties at step one, and a WON roll
	## floods NOTHING. Measured on maps/GLASS.map.json's big pane, sniper, roll won:
	##
	##     lattice=1143  own_frame=0  origin=(114, 84)  origin_in_lattice=false
	##     neighbours_in_lattice=0/8  flood=0  radius=23
	##
	## 1143 surviving voxels, radius 23, zero destroyed — and the failure scaled the
	## WRONG WAY, since a wider hole strangled the flood harder. It bit worst on the
	## round most likely to win the roll in the first place.
	##
	## An already-broken area does not stop a fracture from propagating past it, so
	## the walk expands through everything inside the radius; `flood` only RECORDS a
	## cell the lattice actually holds. What still stops it is `own_frame` — the
	## pane's own non-glass band (G-D9's brick sill and head), which was blocking
	## the walk only as a side effect of not being in `lattice` and now says so
	## outright. Pinned from both sides: [14] is the hole, [11] is the frame.
	var radius: int = region_radius(glass_punch)
	var flood: Dictionary = {}   ## Vector2i(col, level) -> true (voxels to destroy)

	## G-D15 / V-C — ARMORED GLASS HAS NO REGION. Director: once breached it
	## *"usually shatters entirely at once"*, so G-D12's partial break — whose
	## whole point is that a big pane keeps standing where the round did not reach
	## — is precisely what armoured glass does NOT do. It takes the lattice whole.
	##
	## ⚠️ Written as "take the lattice" rather than "use a huge radius", and that
	## is a measured decision rather than a stylistic one. Since the 2026-09-01
	## flood fix the walk expands through HOLES as well as glass, so its cost is
	## the AREA OF THE DISC — about (2r+1)^2 cells — and is no longer bounded by
	## the pane. A sentinel radius would make a maximum 8x4 GU pane cost a walk
	## over tens of thousands of cells to reach 2048 voxels it can simply
	## enumerate.
	var whole_pane: bool = GlassMaterials.shatters_whole_pane(pane_material)
	if whole_pane:
		for k in lattice.keys():
			flood[k] = true
	else:
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
					if own_frame.has(nb):
						continue   ## a real frame stops the fracture; a hole does not
					dist[nb] = d + 1
					queue.append(nb)
					if lattice.has(nb):
						flood[nb] = true

	## G-D13b — spare ANCHORED shards only. A flooded glass voxel is a candidate
	## iff one of its four orthogonal neighbours is non-glass: this pane's own
	## band (`own_frame`) or a neighbouring wall in the same plane
	## (`anchor_positions`). `keep_prob` from the shot's luck, unchanged.
	var luck_unit: float = float(FacadeSamplerClass._fnv1a_hash("%s:REMNANT_LUCK" % salt) % 100000) / 100000.0
	var keep_prob: float = lerpf(SHATTER_REMNANT_KEEP_MIN, SHATTER_REMNANT_KEEP_MAX, luck_unit)
	if whole_pane:
		keep_prob *= SHATTER_REMNANT_ARMORED_SCALE
	var anchored: Array = []
	for k in flood.keys():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = k + d
			if own_frame.has(nb) or anchor_positions.has(nb):
				anchored.append(k)
				break
	var spared: Dictionary = {}
	for k in anchored:
		var u: float = float(FacadeSamplerClass._fnv1a_hash("%s:REMNANT:%d:%d" % [salt, k.x, k.y]) % 100000) / 100000.0
		if u < keep_prob:
			spared[k] = true
	## The floor is CONDITIONAL now: at least SHATTER_REMNANT_MIN_COUNT survive
	## AMONG THE ANCHORED ONES, and an unanchored pane has none to apply it to —
	## which is exactly the free-standing case that has to reach zero. Ranked by
	## distance from the anchored set's own centre, so the forced survivors read
	## as fragments clinging at the extremities rather than a random speckle.
	if spared.size() < SHATTER_REMNANT_MIN_COUNT and not anchored.is_empty():
		var sum_col: float = 0.0
		var sum_lvl: float = 0.0
		for k in anchored:
			sum_col += float(k.x)
			sum_lvl += float(k.y)
		var mid_col: float = sum_col / float(anchored.size())
		var mid_lvl: float = sum_lvl / float(anchored.size())
		var ranked: Array = anchored.duplicate()
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
