## GLASS G-D16a — WHERE A SHARD LANDS.
##
## GLASS_MASTER_PLAN §5.4 / §18.5. G-D13b answers "does this shard survive where
## it is"; this answers the other half, "where does the glass that fell end up",
## and it is deliberately ONE rule rather than one feature per surface:
##
##     A destroyed glass voxel SCATTERS a few cells from its own column and then
##     falls until it meets the first horizontal surface, and lands there.
##
## Base pile, counter top, windowsill, and a skylight dropping a whole storey are
## then the same code with different geometry underneath — no per-case branch.
##
## ── G4-4 / G-D41 + G-D42 — THE SCATTER ──────────────────────────────────────
##
## (Director, 2026-09-05: *"A maior parte dos elementos fica na primeira sub-GU
## mais próxima […] Alguns cacos conseguem vencer até 3 sub-GUs de distância […]
## uma força vetor que desloca todo o conjunto de cacos mais pra longe, baseado na
## força e na distância da granada."*)
##
## A pane is a vertical sheet, so its voxels project onto a LINE of grid cells —
## and until G4-4 that line was the whole pile. The scatter spreads it into a
## band: most shards on the pane's own column, fewer one cell out, a tail reaching
## `SCATTER_MAX_CELLS` (G-D41's "3 sub-GUs"). A sub-GU is one voxel cell (G-D41),
## so every distance here is in cells, not GUs.
##
## The symmetric draw covers "perpendicular to the pane BOTH ways and along the
## run" by construction — for any pane orientation one grid axis is the run and
## the other is perpendicular, and an isotropic symmetric offset spreads both the
## same. So this file never needs the pane's face; it only needs a DIRECTION for
## the shockwave, and the caller hands that in `impulse`.
##
## `impulse` — `{dir: Vector2, strength: float, lift: float}` in GRID space, from
## the bomb's own `ring_multipliers` falloff (G-D42 — no second force model). At
## zero impulse the scatter is symmetric; a near grenade shifts the band's mean
## downrange and, per-shard-scaled, spreads it wider ("caírem mais longe, mais
## espalhados"). `lift` is the skylight term and is UNEXERCISED by any real map —
## G-D16c/d is unbuilt, CEILING glass renders opaque and has no `pane_id`, so no
## skylight can shatter yet. It is authored with a synthetic test rather than
## quietly, so it does not become a fourth built-but-never-triggered feature.
##
## ⚠️ THE SCATTER OFFSET IS HASHED IN GRID SPACE, NOT BASE SPACE, and that is
## correct here rather than a shortcut. The result becomes STATE at `commit()` —
## the G6 pile is recorded in base coords and never recomputed, only re-laid
## (`Room._respawn_base_shards()`) — exactly as the un-scattered landing already
## was. The hash only has to be stable across the many `build_plan()` calls of one
## event, and the cursor is on one target throughout, so the grid key is.
##
## PURE, and that is not decoration. It takes a surface INDEX, never the
## SlabRegistry, so the selftest can hand it a synthetic counter and prove the
## rule without building a map — the same contract PREDICTION_MASTER_PLAN holds
## `build_plan()` to, and the same one `GlassShatter.collect_anchor_positions()`
## already follows.
##
## ⚠️ This module decides WHERE, never WHETHER anything is drawn. G6
## (`Room.record_glass_shards()`) turns a landing into a floor pile decal and
## G6b-2 (`Room.spawn_glass_rain()`) into the falling shards; both are BUILT and
## consume this file's output. This module stays pure and knows about neither.

class_name GlassFall

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

## A shard that reaches the bottom of the built world without meeting anything.
## Not an error: a pane on the outer face of a building genuinely has nothing
## under it on that side, and the honest answer is "this shard is gone", not a
## landing invented at level 0.
const NO_LANDING: int = -1

## ── G4-4 / G-D41 + G-D42 — SCATTER TUNABLES, ALL `var` (architecture Rule 1) ──
##
## The Director records timing/scatter videos and dials these against them — a
## `const` here would be a balance value frozen by accident.

## P(|offset| == index) on ONE axis, drawn independently for each of grid-X and
## grid-Y. Index 0 is "stays on the pane's own column"; the last entry is the
## tail. Must sum to 1.0 and its length fixes `SCATTER_MAX_CELLS`.
static var SCATTER_WEIGHTS: Array[float] = [0.55, 0.30, 0.11, 0.04]

## G-D41 — "até 3 sub-GUs de distância". Derived from the weight table's length so
## the two cannot drift; kept as a named constant for the callers and the gate.
const SCATTER_MAX_CELLS: int = 3

## Cells of downrange shift at `impulse.strength == 1.0`, before the per-shard
## fraction below. The shockwave BIASES the symmetric draw (G-D42), it does not
## replace it, and it is the one term allowed to carry a shard past
## `SCATTER_MAX_CELLS` — that is "vencer mais longe".
static var SCATTER_IMPULSE_GAIN: float = 3.0

## The least-pushed shard still moves this fraction of the full impulse; the rest
## is hashed per shard. This spread is what makes a near grenade land the pile
## "mais espalhados" and not just "mais longe".
static var SCATTER_IMPULSE_MIN_FRAC: float = 0.30

## Extra isotropic spread (cells) at `impulse.lift == 1.0`. Skylights only, and no
## real map exercises it yet — see the class note and selftest [9].
static var SCATTER_LIFT_GAIN: float = 2.0


## Build the surface index for a set of columns: `grid_pos -> sorted levels that
## hold a landable surface, ascending`.
##
## A surface is any VISIBLE, undestroyed voxel of any Slab — FLOOR, CEILING or
## INTERIOR alike. That is the point of using Slabs and not a bespoke list: the
## ground is a FLOOR slab, a block's roof and a counter top are CEILING slabs, and
## a glazed partition's ledge is an INTERIOR one, so all three land shards without
## this file naming any of them.
##
## GLASS IS NOT A SURFACE. A shard falling through a skylight must not stop on the
## next pane of glass under it — it goes through, exactly as the round does (G-D5).
## `columns` restricts the walk to the columns a shatter actually touched, so this
## stays proportional to the break rather than to the map.
static func build_surface_index(slabs: Array, columns: Dictionary) -> Dictionary:
	var index: Dictionary = {}   ## Vector2i grid_pos -> Array[int] levels, ascending
	for slab in slabs:
		if GlassMaterials.is_glass(slab.material):
			continue
		for v in slab.voxels:
			if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			if not columns.has(v.grid_pos):
				continue
			if not index.has(v.grid_pos):
				index[v.grid_pos] = []
			index[v.grid_pos].append(v.level)
	for key in index:
		index[key].sort()
	return index


## The level a shard dropped from `from_level` in column `grid_pos` comes to rest
## ON TOP OF — i.e. the level of the highest surface strictly below it.
##
## Returns NO_LANDING when the column holds no surface below the shard.
static func landing_level(grid_pos: Vector2i, from_level: int, surface_index: Dictionary) -> int:
	var levels: Array = surface_index.get(grid_pos, [])
	var best: int = NO_LANDING
	for lvl in levels:
		var l: int = int(lvl)
		if l < from_level and l > best:
			best = l
	return best


## Plan the landings for a whole shatter.
##
## `destroyed` — Array of {"grid_pos": Vector2i, "level": int}, the voxels the
##   break removed (GlassShatter's plan, resolved to positions by the caller).
## `slabs` — every Slab in the world (`room._slab_registry.all_slabs()`).
## `impulse` — `{dir: Vector2, strength: float, lift: float}` in GRID space, or
##   `{}` for a break with no shockwave (a bullet-shattered pane still scatters,
##   symmetrically — §18.5). See the class note.
##
## Returns Array[{"grid_pos", "from_level", "landing_level", "origin_pos"}], one
## entry per shard that came to rest. `grid_pos` is the SCATTERED cell — where the
## pile accumulates — and `origin_pos` is the voxel's own column, which the rain
## needs for the launch point of a now-diagonal fall. Shards with no surface under
## their scattered column are DROPPED rather than reported at a fake level.
##
## Two shards landing in the same cell is normal and expected: that IS the pile,
## and G6 reads the multiplicity as density. Nothing is deduplicated here.
static func plan_landings(destroyed: Array, slabs: Array, impulse: Dictionary = {}) -> Array:
	if destroyed.is_empty():
		return []

	## Pass 1 — scatter every shard's landing column, and collect the columns the
	## surface index has to cover (the SCATTERED ones, not the originals).
	var scattered: Array = []
	var columns: Dictionary = {}
	for d in destroyed:
		var src: Vector2i = d["grid_pos"]
		var from_level: int = int(d["level"])
		var target: Vector2i = scatter_target(src, from_level, impulse)
		scattered.append({"src": src, "from_level": from_level, "target": target})
		columns[target] = true
	var index: Dictionary = build_surface_index(slabs, columns)

	## Pass 2 — drop each shard down its SCATTERED column.
	var out: Array = []
	for sc in scattered:
		var landed: int = landing_level(sc["target"], int(sc["from_level"]), index)
		if landed == NO_LANDING:
			continue
		out.append({
			"grid_pos": sc["target"],
			"from_level": int(sc["from_level"]),
			"landing_level": landed,
			"origin_pos": sc["src"],
		})
	return out


## G-D41 + G-D42 — the scattered landing column for one destroyed glass voxel.
##
## Deterministic in `(src, from_level)` — a cell is unique within a pane, so no
## per-voxel index is needed and a reordering of `destroyed` cannot reshuffle it.
static func scatter_target(src: Vector2i, from_level: int, impulse: Dictionary) -> Vector2i:
	var salt := "gd41|%d,%d,%d" % [src.x, src.y, from_level]
	var off := Vector2(float(_axis_offset(salt + "|x")), float(_axis_offset(salt + "|y")))

	## G-D42 — the shockwave biases the draw. `dir` points away from the epicenter,
	## `strength` is the bomb's per-ring falloff; the per-shard fraction is what
	## turns "further" into "further AND more spread".
	var dir: Vector2 = impulse.get("dir", Vector2.ZERO)
	var strength: float = float(impulse.get("strength", 0.0))
	if strength > 0.0 and dir.length() > 0.001:
		var frac: float = lerpf(SCATTER_IMPULSE_MIN_FRAC, 1.0, _hash_unit(salt + "|push"))
		off += dir.normalized() * strength * SCATTER_IMPULSE_GAIN * frac

	## `lift` — a skylight's shards are tossed up and land wider on the way down
	## ("sobem um pouquinho mas sempre caem pra baixo"). UNEXERCISED — see the note.
	var lift: float = float(impulse.get("lift", 0.0))
	if lift > 0.0:
		var a: float = _hash_unit(salt + "|la") * TAU
		var r: float = _hash_unit(salt + "|lr") * lift * SCATTER_LIFT_GAIN
		off += Vector2(cos(a), sin(a)) * r

	return src + Vector2i(roundi(off.x), roundi(off.y))


## One signed axis offset in [-SCATTER_MAX_CELLS, SCATTER_MAX_CELLS], drawn from
## `SCATTER_WEIGHTS` and mirrored to a sign. FNV-1a via FacadeSampler, the same
## per-cell hash rule every other pick on this track uses — and safe here because
## each shard's salt is fully distinct (the "selected whole columns" failure in
## §16.13 came from a shared few-percent threshold, not from a per-cell bucket).
static func _axis_offset(salt: String) -> int:
	var u: float = _hash_unit(salt + "|m")
	var acc: float = 0.0
	var mag: int = SCATTER_WEIGHTS.size() - 1
	for i in range(SCATTER_WEIGHTS.size()):
		acc += float(SCATTER_WEIGHTS[i])
		if u < acc:
			mag = i
			break
	if mag <= 0:
		return 0
	return mag if _hash_unit(salt + "|s") < 0.5 else -mag


static func _hash_unit(salt: String) -> float:
	return float(FacadeSamplerClass._fnv1a_hash(salt) % 100000) / 100000.0


## Pile density per landing cell: `Vector3i(x, y, landing_level) -> shard count`.
## The shape G6 needs — a decal's intensity is how many shards reached that cell,
## and a six-storey pane emptying onto one tile is a deeper pile than a single
## voxel falling one level.
static func pile_by_cell(landings: Array) -> Dictionary:
	var piles: Dictionary = {}
	for l in landings:
		var gp: Vector2i = l["grid_pos"]
		var key := Vector3i(gp.x, gp.y, int(l["landing_level"]))
		piles[key] = int(piles.get(key, 0)) + 1
	return piles
