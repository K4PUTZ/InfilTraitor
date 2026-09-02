## GLASS G-D16a — WHERE A SHARD LANDS.
##
## GLASS_MASTER_PLAN §5.4. G-D13b answers "does this shard survive where it is";
## this answers the other half, "where does the glass that fell end up", and it is
## deliberately ONE rule rather than one feature per surface:
##
##     A destroyed glass voxel falls straight down its own column until it meets
##     the first horizontal surface, and lands there.
##
## Base pile, counter top, windowsill, and a skylight dropping a whole storey are
## then the same code with different geometry underneath — no per-case branch.
##
## PURE, and that is not decoration. It takes a surface INDEX, never the
## SlabRegistry, so the selftest can hand it a synthetic counter and prove the
## rule without building a map — the same contract PREDICTION_MASTER_PLAN holds
## `build_plan()` to, and the same one `GlassShatter.collect_anchor_positions()`
## already follows.
##
## ⚠️ This module decides WHERE, never WHETHER anything is drawn. G6 (§7.1) is the
## consumer that turns a landing into a visible floor decal, and it is blocked on
## the `shard_floor` art. Until then the landings are computed and reported but
## nothing renders them — stated here rather than discovered later, because §7.1's
## own risk note is precisely that unseen state rots.

class_name GlassFall

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")

## A shard that reaches the bottom of the built world without meeting anything.
## Not an error: a pane on the outer face of a building genuinely has nothing
## under it on that side, and the honest answer is "this shard is gone", not a
## landing invented at level 0.
const NO_LANDING: int = -1


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
##
## Returns Array[{"grid_pos", "from_level", "landing_level"}], one entry per shard
## that actually came to rest. Shards with no surface under them are DROPPED from
## the result rather than reported at a fake level — a caller counting entries is
## counting real piles.
##
## Two shards from the same pane landing in the same cell is normal and expected:
## that IS the pile, and G6 reads the multiplicity as density. Nothing is
## deduplicated here.
static func plan_landings(destroyed: Array, slabs: Array) -> Array:
	var columns: Dictionary = {}
	for d in destroyed:
		columns[d["grid_pos"]] = true
	if columns.is_empty():
		return []
	var index: Dictionary = build_surface_index(slabs, columns)

	var out: Array = []
	for d in destroyed:
		var gp: Vector2i = d["grid_pos"]
		var from_level: int = int(d["level"])
		var landed: int = landing_level(gp, from_level, index)
		if landed == NO_LANDING:
			continue
		out.append({
			"grid_pos": gp,
			"from_level": from_level,
			"landing_level": landed,
		})
	return out


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
