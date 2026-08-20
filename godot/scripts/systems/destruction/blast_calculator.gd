## BlastCalculator — DESTRUCTION_MASTER_PLAN Part 3 ("the trigger").
##
## Pure/static: everything it needs is passed in (no registry ownership,
## same statelessness as EarthVariantSelector) so it stays testable in
## isolation against synthetic fixtures, matching every other Part's
## selftest convention.
##
## Three-stage pipeline for one detonation:
##  1. flood_gu_rings() — wall-aware BFS from the source GU, one ring per
##     GU step, capped at the bomb's range. Director (this session): walls
##     block/reduce propagation — reuses the same blocked-edge gate
##     movement_overlay.gd already uses for movement, not a naive radius.
##  2. find_affected_containers() — every wall Slice and roof Slab (Role.
##     CEILING) touching a flooded GU, ring-tagged. The GU flood step IS the
##     "walk sideways along the wall" step (a wall's own footprint GU sits in
##     the flood like any other GU), so no separate wall-run adjacency walk
##     is needed here.
##  3. apply_container_damage() — combines a container's ring multiplier with
##     MaterialResistanceTable to get a destroy/crack voxel COUNT, then picks
##     WHICH voxels deterministically (FNV-1a hash-and-rank, mirroring
##     EarthVariantSelector — no RNG, same inputs always produce the same
##     result).
class_name BlastCalculator

## Ground-anchored detonation altitude. Real per-bomb/per-throw altitude is
## future scope — every grenade this session detonates at the wall's own
## base level.
const GRENADE_LEVEL := 0

## VL-D4 — sentinel meaning "no directional bias" for apply_container_damage()/
## _select_deterministic()'s optional epicenter parameter. Any real epicenter is
## a valid in-map voxel coordinate, so an out-of-range constant is safe to use
## as "absent" without an extra bool parameter.
const NO_EPICENTER_BIAS := Vector2i(-999999, -999999)

## FACE-SOOT-01 — the per-face ring meaning "this face takes NO soot". Sits one
## past the last real ring index so `ring + falloff` clamps onto it naturally;
## VoxelLightField.encode_face_soot() packs three faces in base (this + 1).
##
## PERF-02 B3-2 (Director, 2026-08-04): 3 → 4, i.e. FOUR real soot tones
## (0..3) instead of three. The Director asked for five; five does not fit,
## and the binding constraint is NOT the alpha carrier the code rides in
## (measured: a 216-level carrier decodes cleanly — a real capture with the
## finer packing came back pixel-identical to the 64-level one). It is the
## alternative-id ceiling documented on VoxelRenderer.FACE_SOOT_CODE_COUNT:
## 12 buckets × codes × 2 flips must stay under TileSetAtlasSource.
## TRANSFORM_FLIP_H (4096, read from the engine, not assumed). Five tones need
## 6³ = 216 codes and peak at id 5183 — over. Four need 5³ = 125 and peak at
## 2999.
const FACE_SOOT_CLEAN := 4


## GU cell -> ring index (0 = source GU). Wall-aware BFS, capped at
## bomb_def.ring_multipliers.size()-1 rings. blocked_edges must already be
## keyed via WallEdgeData.edge_key() (same shape room._current_blocked_edges
## produces once folded through that helper).
##
## blocked_cells (2026-08-01) — the same gap select_cone_pellet_impacts()
## closed on 2026-07-30: a solid GU block (`MapCompiler`'s `spec.blocks`, a
## bench's material walls) marks whole CELLS occupied (`room._blocked_cells`)
## and never touches `blocked_edges`, so the flood sailed straight through
## solid blocks and kept going. An occupied cell is never entered — the blast
## stops at its boundary, and the block's facing slices still take damage
## through the flooded cell's own edges (find_affected_containers() walks
## edges_touching_gu() of the FLOODED side). Trailing + defaulted so the
## pure-hash selftests are unaffected.
static func flood_gu_rings(source_gu: Vector2i, bomb_def, blocked_edges: Dictionary,
		blocked_cells: Dictionary = {}) -> Dictionary:
	var max_ring: int = bomb_def.ring_multipliers.size() - 1
	var rings: Dictionary = {source_gu: 0}
	var frontier: Array[Vector2i] = [source_gu]

	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for current in frontier:
			var current_ring: int = rings[current]
			if current_ring >= max_ring:
				continue
			for face in [Face.NW, Face.NE, Face.SE, Face.SW]:
				var neighbor: Vector2i = current + Face.delta(face)
				if rings.has(neighbor):
					continue
				if WallEdgeData.is_edge_blocked(current, neighbor, blocked_edges) \
						or blocked_cells.has(neighbor):
					continue
				rings[neighbor] = current_ring + 1
				next_frontier.append(neighbor)
		frontier = next_frontier

	return rings


## WEAPON_MASTER_PLAN D1 / DESTRUCTION_MASTER_PLAN Part 5 — the CONE shape.
##
## Same wall-aware BFS as flood_gu_rings(), gated to a wedge around a facing.
## Reusing the BFS rather than rasterising a cone directly is the whole point:
## wall-blocking, the step index, and the {gu -> step} output shape every
## downstream consumer already expects all come for free, so
## find_affected_containers()/apply_container_damage() need ZERO changes to
## accept a shot instead of a blast.
##
## Gating during the BFS is safe because a cone is CONVEX with its apex at the
## source: any cell inside it can be reached from the apex by going out along
## the axis and only then stepping sideways, and the cone is widest at the far
## end, so that path never leaves the region. A cell that is only reachable
## through cells outside the wedge is a cell behind a corner — which should be
## excluded anyway.
##
## facing_delta is a GU-space compass step (docs/DIRECTION_GLOSSARY.md §3 —
## NE is (0,-1)). The angle test is done in GU space, not screen space: the
## isometric projection is linear, so a GU-space wedge still projects to a
## wedge on screen, just with a transformed apex angle — the same reason
## movement range reads as a diamond and nobody rasterises it in pixels.
##
## KNOWN, deliberate: BFS depth is Manhattan distance, so a cell at the cone's
## edge gets a HIGHER step (weaker multiplier) than its Euclidean distance
## would give. That makes cone edges fall off faster than the centre, which is
## both physically reasonable for a spreading shot and consistent with how
## flood_gu_rings() already treats a grenade. Not a bug to fix later.
static func flood_gu_cone(source_gu: Vector2i, facing_delta: Vector2i, half_angle_deg: float,
		max_steps: int, blocked_edges: Dictionary, blocked_cells: Dictionary = {}) -> Dictionary:
	var cone: Dictionary = {source_gu: 0}
	if max_steps <= 0:
		return cone
	var axis := Vector2(facing_delta).normalized()
	if axis == Vector2.ZERO:
		push_error("[BlastCalculator] flood_gu_cone: facing_delta must not be zero")
		return cone
	var cos_limit := cos(deg_to_rad(clampf(half_angle_deg, 0.0, 180.0)))

	var frontier: Array[Vector2i] = [source_gu]
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for current in frontier:
			var current_step: int = cone[current]
			if current_step >= max_steps:
				continue
			for face in [Face.NW, Face.NE, Face.SE, Face.SW]:
				var neighbor: Vector2i = current + Face.delta(face)
				if cone.has(neighbor):
					continue
				if WallEdgeData.is_edge_blocked(current, neighbor, blocked_edges) \
						or blocked_cells.has(neighbor):
					continue
				var offset := Vector2(neighbor - source_gu)
				## Strictly in front of the muzzle, and inside the wedge. The
				## apex cell itself is already seeded, so offset is never zero.
				if offset.normalized().dot(axis) < cos_limit:
					continue
				cone[neighbor] = current_step + 1
				next_frontier.append(neighbor)
		frontier = next_frontier

	return cone


## WEAPON_MASTER_PLAN D26-D28 (Director, 2026-07-30) — replaces the
## flood-and-graduate-by-ring damage model for CONE/LINE weapons. A shot is
## `projectile_count` discrete pellets, each landing on exactly ONE wall
## voxel — never an area. Bullet marks exist only at that one impact point;
## everything else in the wedge is untouched by this call (soot, D17,
## spreads separately from whichever voxels end up DESTROYED).
##
## D26: no authored range cap — max_steps should be generous (comfortably
## past any real room), since the cone's own angular widening is what makes a
## far shot self-limiting (thinner pellet coverage over a wider spread), not
## a hard cutoff.
##
## NOT a flood-fill: an early version aggregated flood_gu_cone()'s ENTIRE
## reachable set and picked wall-adjacent cells from all of it — which let a
## pellet's "impact" be a wall reached by walking AROUND a narrow obstacle
## (e.g. a 3-GU-wide bench block) via some other open path, rather than the
## wall actually in front of that specific pellet. Real bench evidence
## 2026-07-30: every pellet aimed at the metal column landed on the ROOM'S
## OUTER WALL (uniformly "concrete") behind and beside it, because the flood
## slipped past the narrow block sideways and kept going. Each pellet now
## walks its OWN roughly-straight path (Bresenham-style lateral drift against
## a per-pellet angle within the half-angle cone) and stops at the FIRST
## blocked edge it personally meets — a pellet angled enough to clear an
## obstacle's lateral extent correctly can still find something behind it,
## but one aimed roughly at the obstacle cannot detour around it.
##
## `blocked_cells` (2026-07-30, added after the FIRST real-bench test of this
## function): a solid GU block (`MapCompiler`'s `spec.blocks`, this bench's
## own material walls) is NOT represented in `blocked_edges` at all — it
## marks whole cells occupied (`blocked_map`/`room._blocked_cells`, the same
## dict LOS already keys off, `guard.set_los_data()`) and never touches
## `blocked_edges`, which only "dividers"/perimeter walls populate. A pellet
## walking only the edge check sailed straight through the bench's own
## blocks and kept going to whatever real wall was behind them — caught by
## every impact coming back the SAME material (the room's outer wall)
## regardless of which column was fired at. A step is blocked now if EITHER
## the edge into the next cell is flagged OR that cell is itself occupied.
##
## Returns Array[Dictionary] of `projectile_count` {"gu": Vector2i, "face": int}
## picks — empty entries are dropped (a pellet that never meets a wall within
## max_steps is a clean miss, void, nothing happens, per D15). Deterministic
## via the project's standard FNV-1a hash (no RNG, D22): each pellet's angle
## is hashed from (salt, pellet index), not sampled from an RNG.
## `aim_offset_deg` (§6c Part A, 2026-08-19) BIASES the cone's centre line off
## `facing_delta`, instead of the cone always being centred on the grid axis.
##
## It exists because a shot fired BY AN ACTOR aims at another ACTOR, and two
## actors are almost never on a shared grid axis — the PLAYGROUND pair sit at
## (12,13) and (15,11), a delta of (3,-2). Every caller before this one fired
## from a static prop whose facing WAS an axis by construction, which is why the
## parameter is new rather than missing.
##
## Deliberately a bias on the existing angle term rather than a new ray walker:
## `_walk_pellet_ray()` already steers by an angle off a forward axis (that is
## what the cone's own spread is), so an off-axis aim is the same machinery with
## a non-zero centre. Default 0.0 leaves every existing caller bit-identical —
## and the hash inputs are untouched, so B4 determinism is unaffected.
static func select_cone_pellet_impacts(source_gu: Vector2i, facing_delta: Vector2i,
		half_angle_deg: float, max_steps: int, projectile_count: int,
		blocked_edges: Dictionary, blocked_cells: Dictionary, salt: String,
		aim_offset_deg: float = 0.0) -> Array:
	var picks: Array = []
	if facing_delta == Vector2i.ZERO or projectile_count <= 0:
		return picks
	## Perpendicular to facing_delta (a 90 deg rotation) — the axis a pellet
	## drifts along as it strays from dead-centre.
	var lateral := Vector2i(-facing_delta.y, facing_delta.x)
	for i in range(projectile_count):
		## CONE-DISC-01 (Director, 2026-08-02) — a shotgun's spread is a DISC on
		## the target, not a horizontal line. Two things were wrong before:
		##
		## 1. The lateral angle was `lerp(-half, +half, unit)` with `unit`
		##    uniform, which spreads pellets EVENLY ACROSS THE FULL WIDTH — half
		##    of every blast sat past 12.5 deg of a 25 deg cone, and the extremes
		##    were as likely as dead centre. A real cone is uniform over AREA, so
		##    the radius must be sqrt-distributed; that alone pulls the pattern
		##    into the cone instead of smearing it along the cone's edge.
		## 2. There was NO vertical axis at all — resolve_pellet_voxel() pinned
		##    every pellet to chest level, so 24 pellets landed on one voxel row.
		##    That is the horizontal streak in the Director's capture.
		##
		## So each pellet draws a point in the UNIT DISC (theta, rho=sqrt(u)):
		## the horizontal component steers the GU-space ray (which is what keeps
		## occlusion honest), and the vertical component rides in the pick for
		## resolve_pellet_voxel() to turn into a level offset. Both scale with
		## distance travelled, which is the diagram's *"tiros de longe erram mais
		## longe"* — and it falls out of the cone's geometry rather than being a
		## separate rule.
		##
		## Range is deliberately NOT capped (Director, 2026-08-02: *"o alcance
		## não é pra ter limite mesmo, o tiro acertou o fundo corretamente em
		## relação à distância"*) — a pellet that clears the near wall keeps
		## going and may legitimately mark the far one.
		var theta_key: String = "%s:PELLET_THETA:%d" % [salt, i]
		var rho_key: String = "%s:PELLET_RHO:%d" % [salt, i]
		var theta: float = TAU * float(FacadeSampler._fnv1a_hash(theta_key) % 10000) / 10000.0
		var rho: float = sqrt(float(FacadeSampler._fnv1a_hash(rho_key) % 10000) / 10000.0)
		var angle_deg: float = aim_offset_deg + half_angle_deg * rho * cos(theta)
		var hit := _walk_pellet_ray(source_gu, facing_delta, lateral, deg_to_rad(angle_deg),
			max_steps, blocked_edges, blocked_cells)
		if not hit.is_empty():
			## Carried so the impact voxel can be placed on the same disc the
			## lateral angle came from, instead of an unrelated hash.
			hit["v_unit"] = rho * sin(theta)
			hit["h_unit"] = rho * cos(theta)
			hit["half_angle_deg"] = half_angle_deg
			picks.append(hit)
	return picks


## One pellet's own path: mostly `forward`, drifting one `lateral` step
## whenever the accumulated tan(angle_rad) crosses a whole step (Bresenham's
## algorithm applied to a facing axis instead of a literal line). Stops and
## returns {"gu","face","steps"} at the FIRST blocked edge OR occupied cell this
## specific path meets; {} if it exhausts max_steps without meeting one
## (void, D15). `steps` is how far the pellet actually travelled, which is what
## the disc's radius scales with (CONE-DISC-01) and what LINE's distance term
## reads.
static func _walk_pellet_ray(source_gu: Vector2i, forward: Vector2i, lateral: Vector2i,
		angle_rad: float, max_steps: int, blocked_edges: Dictionary, blocked_cells: Dictionary) -> Dictionary:
	var current := source_gu
	var lateral_accum := 0.0
	var tan_angle := tan(angle_rad)
	for step in range(max_steps):
		lateral_accum += tan_angle
		if absf(lateral_accum) >= 1.0:
			var step_sign: int = 1 if lateral_accum > 0.0 else -1
			var lateral_step: Vector2i = lateral * step_sign
			var lateral_target: Vector2i = current + lateral_step
			if WallEdgeData.is_edge_blocked(current, lateral_target, blocked_edges) or blocked_cells.has(lateral_target):
				return {"gu": current, "face": Face.from_delta(lateral_step), "steps": step}
			current = lateral_target
			lateral_accum -= step_sign
		var forward_target: Vector2i = current + forward
		if WallEdgeData.is_edge_blocked(current, forward_target, blocked_edges) or blocked_cells.has(forward_target):
			return {"gu": current, "face": Face.from_delta(forward), "steps": step}
		current = forward_target
	return {}


## Resolve one pellet's {"gu","face"} pick (from select_cone_pellet_impacts())
## to the real Slice + voxel index it hits. Face-height placement is a
## placeholder for D18's "chest height" — the middle level of the wall's own
## base storey — pending a real chest-height derivation once an actor's
## height is modelled; horizontal position within the GU's 8-voxel-wide face
## is hash-picked for a little natural jitter rather than always dead-centre.
## Returns {"slice": Slice, "voxel_index": int} or {} if the wall/slice can't
## be resolved (should not happen for a pick select_cone_pellet_impacts()
## itself produced, but callers should still check).
static func resolve_pellet_voxel(pick: Dictionary, edge_registry: EdgeRegistry, salt: String) -> Dictionary:
	var gu: Vector2i = pick["gu"]
	var face: int = pick["face"]
	var neighbor: Vector2i = gu + Face.delta(face)
	## Resolve the real Edge by scanning gu's own edges for the one reaching
	## `neighbor` — WallEdgeData.edge_key() is only the blocked_edges lookup
	## key, not an Edge id.
	var target_slice: Slice = null
	for edge in edge_registry.edges_touching_gu(gu):
		if edge.gu_a == neighbor or edge.gu_b == neighbor:
			for slice in edge_registry.slices_of_edge(edge.id):
				if slice.gu_cell == gu:
					target_slice = slice
					break
			break
	if target_slice == null or target_slice.voxels.is_empty():
		return {}
	var chest_level: int = target_slice.start_storey * GeometryCoords.LEVELS_PER_STOREY \
		+ int(float(GeometryCoords.LEVELS_PER_STOREY) / 2.0)
	var max_level_offset: int = target_slice.storey_count * GeometryCoords.LEVELS_PER_STOREY - 1
	## CONE-DISC-01: the pellet's VERTICAL place on the wall, from the same unit
	## disc its lateral angle came from. The cone's radius at the impact is
	## `steps * tan(half_angle)` in GUs; multiplying by VOXELS_PER_UNIT_AXIS puts
	## it in voxel rows, which is the unit a level offset is measured in. A pick
	## without these keys (a LINE shot, or any older caller) falls through to
	## chest level exactly as before.
	var v_offset := 0
	if pick.has("v_unit") and pick.has("half_angle_deg"):
		var spread_gu: float = float(int(pick.get("steps", 0))) \
			* tan(deg_to_rad(float(pick["half_angle_deg"])))
		v_offset = int(roundf(float(pick["v_unit"]) * spread_gu
			* float(GeometryCoords.VOXELS_PER_UNIT_AXIS)))
	var level_offset: int = clampi(
		chest_level - target_slice.start_storey * GeometryCoords.LEVELS_PER_STOREY + v_offset,
		0, max_level_offset)
	## Horizontal place WITHIN the struck GU's 8-voxel face. For a cone pellet
	## this is the disc's own horizontal component, so the pattern is round
	## rather than a column of randomly-offset rows; the GU-level drift the ray
	## walk already applied carries the coarse part, this carries the remainder.
	## Anything without the disc keys keeps the original hashed jitter.
	var position_index: int
	if pick.has("h_unit") and pick.has("half_angle_deg"):
		var h_spread_vox: float = float(int(pick.get("steps", 0))) \
			* tan(deg_to_rad(float(pick["half_angle_deg"]))) \
			* float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
		position_index = clampi(
			int(roundf(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0
				+ float(pick["h_unit"]) * h_spread_vox)),
			0, GeometryCoords.VOXELS_PER_UNIT_AXIS - 1)
	else:
		var jitter_key: String = "%s:PELLET_JITTER:%s" % [salt, target_slice.id]
		position_index = FacadeSampler._fnv1a_hash(jitter_key) % GeometryCoords.VOXELS_PER_UNIT_AXIS
	var voxel_index: int = level_offset * GeometryCoords.VOXELS_PER_UNIT_AXIS + position_index
	return {"slice": target_slice, "voxel_index": voxel_index}


## WEAPON_MASTER_PLAN D28 (Director, 2026-07-30) — ONE voxel, ONE roll: the
## per-projectile point-impact counterpart to apply_container_damage()'s
## ring-group scatter (which stays correct for RADIAL — a blast genuinely is
## an area effect). destroy/dent/crack_factor are read as PROBABILITIES for
## this single voxel rather than group fractions — the same numbers mean the
## same thing at n=1.
##
## Cascades exactly once if the impact voxel is fully DESTROYED: the wall's
## sibling slice (edge_registry.sibling_slice(), same voxel index — verified
## 2026-07-30 that SliceGenerator builds both slices of an edge with matching
## per-level, per-position iteration order, so index i is the same physical
## row/column on the opposite face) becomes a second roll target. A wall is
## exactly 2 voxels thick (D16: "outer slice AND inner slice"), so the loop
## caps at 2 — if that second voxel also fully destroys, the shot penetrated
## clean through and there is no mark anywhere on this path, per *"se o tiro
## atravessar a parede não tem marca de bala porque ela continuou o
## caminho."*
##
## Returns Array[Voxel] actually touched (1 or 2), for the caller's soot/
## VL-PERSIST bookkeeping — same shape callers already build from
## destroy_set/dent_set/crack_set today.
## D30 (Director, 2026-08-02) — REPLACES D28's three-way probability roll with
## the single `punch` coefficient. `punch` arrives ALREADY COMPUTED (see
## ShotPunchTable.compute()), so this function is pure geometry + ladder and a
## selftest can drive an exact coefficient instead of hunting for a salt that
## happens to roll the tier it wants to observe.
##
## WHAT CHANGED FROM D28, and what deliberately did NOT:
## - The impact voxel's tier is now a DETERMINISTIC function of punch, not a
##   dice throw between three buckets. Director: *"A marca vai afundando
##   conforme a potência do tiro."* Randomness moved into punch itself (the luck
##   term), so it varies the RESULT without making the ladder unreadable.
## - There is no "nothing happened" outcome any more: *"O tiro errado sempre vai
##   ter pelo menos uma marca de bala (a não ser que atravesse a parede)."*
##   Below the DENTED threshold the floor is CRACKED, not INTACT.
## - **Neighbours may now be DESTROYED, but NEVER marked** (D30.1, Director:
##   *"vizinhos destruídos mas sem marca própria. Somente o projétil gera a
##   marca no ponto de impacto"*). This keeps D28's actual invariant — the one
##   it was written to protect — while letting a heavy round open one big
##   contiguous hole instead of a spray of separate round marks. A neighbour
##   only ever goes INTACT -> DESTROYED; it can never reach DENTED or CRACKED.
## - Full penetration still leaves no mark anywhere on the path (D28, unchanged).
##
## D30.2 — neighbours cascade into the second layer ONLY above
## ShotPunchTable.NEIGHBOUR_CASCADE_PUNCH, which is set above anything the
## current arsenal reaches. Director: *"Se a potência do tiro for gigantesca, os
## vizinhos destruídos podem cascatear para a próxima camada. Não é algo para
## ser frequente, mas eventualmente vai ter uma bazuca."*
##
## The centre column still cascades exactly as D28 specified: the wall's sibling
## slice (edge_registry.sibling_slice(), same voxel index — verified 2026-07-30
## that SliceGenerator builds both slices of an edge with matching per-level,
## per-position iteration order, so index i is the same physical row/column on
## the opposite face). A wall is exactly 2 voxels thick (D16), so depth caps
## at 2.
##
## Returns Array[Voxel] actually touched, for the caller's soot / VL-PERSIST
## bookkeeping — same shape callers already build from destroy_set/dent_set/
## crack_set today.
## `step_multipliers` is the weapon's own table and is consumed here ONLY as
## D1's PENETRATION axis (what survives into layer 2). Passing it is optional:
## an empty array falls back to ShotPunchTable.PENETRATION_FALLOFF, which is
## what every non-LINE shape wants, since for those shapes the same table means
## distance and has no business attenuating depth.
## D32 (Director, 2026-08-02) — `shooter_gu` is what finally lets the projectile's
## mark land on the face it actually struck. Until now this function called
## set_damage() with no side at all, so `carved_side` stayed NONE and the mark
## rendered from D22's top-face art: every firearm hit on a wall painted its
## bullet hole on the voxel's ROOF. The resolution reuses carved_side_for(), the
## same screen-space test the blast side has used since D25 — a bullet arriving
## from screen-left marks the SW face — rather than a second, parallel rule that
## could drift from it. NO_EPICENTER_BIAS keeps the pre-D32 behaviour, which is
## what every existing selftest passes and why the parameter is trailing.
static func apply_point_impact(slice: Slice, voxel_index: int, punch: float,
		edge_registry: EdgeRegistry, salt: String,
		step_multipliers: Array = [],
		shooter_gu: Vector2i = NO_EPICENTER_BIAS) -> Array:
	var touched: Array = []
	for entry in plan_point_impact(slice, voxel_index, punch, edge_registry, salt,
			step_multipliers, shooter_gu):
		var v: Voxel = entry["voxel"]
		v.set_damage(int(entry["state"]), bool(entry["is_blast"]),
			int(entry["carved_side"]), int(entry["variant"]), int(entry["substrate"]))
		touched.append(v)
	return touched


## PURE. Exactly what apply_point_impact() above WOULD do, as data — one entry
## per voxel it would touch, in the same order, carrying the exact damage tuple
## it would write. Not a single voxel is mutated here.
##
## W-PRECOOK-02 (2026-08-19): the shot's warm has to know WHICH ATOM each
## damaged voxel is about to land on. A DENTED or CRACKED voxel does not keep
## its atlas coords — it moves to the damage VARIANT atom, and the light
## alternative for THAT atom is a fresh mint on the very frame the wall breaks
## (measured: 17 of them, one TileSet rebuild, ~250 ms). Resolving the atom
## needs the real tuple — state, carved side, decal variant, substrate — and an
## earlier attempt that GUESSED it warmed 11 alternatives the shot did not want
## while still missing the 13 it did.
##
## So the ladder lives here, once, and the applier above is a loop over its
## result. That is the whole point: a prediction that runs the same code cannot
## disagree with what happens, and there is no second copy to drift.
##
## Entry: {"voxel": Voxel, "container": Slice, "state": int, "is_blast": bool,
## "carved_side": int, "variant": int, "substrate": int} — the five fields after
## `container` are set_damage()'s five arguments, in order.
static func plan_point_impact(slice: Slice, voxel_index: int, punch: float,
		edge_registry: EdgeRegistry, salt: String,
		step_multipliers: Array = [],
		shooter_gu: Vector2i = NO_EPICENTER_BIAS) -> Array:
	var plan: Array = []
	var current_slice := slice
	for depth in range(2):  ## a wall is exactly 2 voxels thick (D16): outer + inner
		if current_slice == null or voxel_index < 0 or voxel_index >= current_slice.voxels.size():
			break
		var current_punch: float = punch \
			* ShotPunchTable.penetration_multiplier(step_multipliers, depth)
		var voxel: Voxel = current_slice.voxels[voxel_index]
		var state: int = ShotPunchTable.damage_state_for(current_punch)
		if state != Voxel.DamageState.DESTROYED:
			## CRACKED or DENTED — the projectile's own mark, bullet family
			## (from_blast stays false, D23), on the face the shot came from
			## (D32.4), with one of the three authored decals (D32.5).
			plan.append({"voxel": voxel, "container": current_slice,
				"state": state, "is_blast": false,
				"carved_side": carved_side_for(voxel.grid_pos, false, shooter_gu),
				"variant": decal_variant_for(salt, voxel_index, depth),
				"substrate": substrate_for(salt, voxel_index, depth)})
			break
		plan.append(_destroyed_plan_entry(voxel, current_slice))
		var sibling := edge_registry.sibling_slice(current_slice.id)
		## D30.1: neighbours of the hole go too, but never marked.
		var neighbour_count: int = ShotPunchTable.neighbour_count_for(current_punch)
		var cascade_neighbours: bool = current_punch >= ShotPunchTable.NEIGHBOUR_CASCADE_PUNCH
		for ni in select_face_neighbours(current_slice, voxel_index, neighbour_count,
				"%s:NEIGHBOUR:%d" % [salt, depth]):
			plan.append(_destroyed_plan_entry(current_slice.voxels[ni], current_slice))
			if cascade_neighbours and sibling != null and ni < sibling.voxels.size():
				plan.append(_destroyed_plan_entry(sibling.voxels[ni], sibling))
		current_slice = sibling
	return plan


## The five set_damage() arguments a DESTROYED voxel gets, spelled out. They are
## set_damage()'s own defaults — written here rather than defaulted so the plan
## entry is a complete description of the call, and a reader never has to go and
## check what a bare set_damage(DESTROYED) leaves behind.
static func _destroyed_plan_entry(voxel: Voxel, container) -> Dictionary:
	return {"voxel": voxel, "container": container,
		"state": Voxel.DamageState.DESTROYED, "is_blast": false,
		"carved_side": Voxel.CarvedSide.NONE, "variant": 0, "substrate": 0}


## The up-to-8 face-plane neighbours of `voxel_index` inside its own Slice,
## ranked by hash so the hole's SHAPE varies shot to shot instead of always
## being the same cross or the same full square (D30.4 — *"pra não ficar o mesmo
## buraco repetitivo"*). Soot needs no equivalent knob: derive_soot_rings() is a
## deterministic BFS over whichever voxels are absent, so varying the hole
## varies the scorch for free.
##
## A Slice's voxels are a row-major grid of VOXELS_PER_UNIT_AXIS columns
## (index = row * 8 + col), so neighbours are the 3x3 patch minus the centre —
## computed in (row, col) space precisely so index+1 cannot wrap onto the next
## row and paint a hole on the far side of the wall.
static func select_face_neighbours(slice: Slice, voxel_index: int, count: int,
		salt: String) -> Array:
	if count <= 0 or slice == null or slice.voxels.is_empty():
		return []
	var w: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	var rows: int = int(float(slice.voxels.size()) / float(w))
	var row: int = int(float(voxel_index) / float(w))
	var col: int = voxel_index % w
	var candidates: Array = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var r: int = row + dr
			var c: int = col + dc
			if r < 0 or r >= rows or c < 0 or c >= w:
				continue
			candidates.append(r * w + c)
	candidates.sort_custom(func(a, b) -> bool:
		return FacadeSampler._fnv1a_hash("%s:%d" % [salt, a]) \
			< FacadeSampler._fnv1a_hash("%s:%d" % [salt, b])
	)
	return candidates.slice(0, mini(count, candidates.size()))


## D30 — LINE delivery: one straight ray from the muzzle GU along `facing_delta`,
## stopping at the first blocked edge or occupied cell it meets. This is the
## mechanic the five rifled weapons have declared truthfully and loud-failed on
## since D11 (WEAPON_MASTER_PLAN Part 3b).
##
## Deliberately reuses _walk_pellet_ray() at angle 0 rather than reimplementing
## a ray: a LINE shot IS a cone pellet with no angular deviation, and sharing
## the walk means the stop conditions (edge blocking, occupied cells, void
## fallthrough per D15) can never drift between the two delivery shapes.
##
## Returns {"gu","face","steps"} — `steps` is the GU distance travelled, which
## is what ShotPunchTable's distance term indexes — or {} if the ray reached
## max_steps without meeting anything (a miss into the void, D26: it keeps
## travelling, it does not stop at a range limit).
static func select_line_impact(source_gu: Vector2i, facing_delta: Vector2i,
		max_steps: int, blocked_edges: Dictionary, blocked_cells: Dictionary,
		aim_offset_deg: float = 0.0) -> Dictionary:
	if facing_delta == Vector2i.ZERO:
		return {}
	var lateral := Vector2i(-facing_delta.y, facing_delta.x)
	var hit := _walk_pellet_ray(source_gu, facing_delta, lateral,
		deg_to_rad(aim_offset_deg), max_steps, blocked_edges, blocked_cells)
	if hit.is_empty():
		return {}
	## Chebyshev distance, and it is EXACT ONLY ON AXIS. A zero-angle walk steps
	## purely along `facing_delta`, so the GU delta is a multiple of it and the
	## max-component distance is the real one. An off-axis aim also drifts along
	## `lateral`, and there the same expression is the Chebyshev distance of a
	## genuinely 2-D delta — still the right quantity for the penetration term,
	## which counts GU steps, but no longer a pure multiple of anything.
	var delta: Vector2i = hit["gu"] - source_gu
	hit["steps"] = maxi(absi(delta.x), absi(delta.y))
	return hit


## Every wall Slice and roof Slab touching a flooded GU, each tagged with the
## ring of the GU it was reached through (the minimum ring, if reachable from
## more than one side). Returns {"slices": Dictionary[String,int] (slice.id
## -> ring), "roofs": Dictionary[String,int] (slab.id -> ring)}.
##
## `junction_columns` (E-JUNCTION-01, 2026-08-13): explosion-only, by design —
## the Director's own call. A firearm's aim resolves to a face on whichever
## Slice happens to be there, never to the diagonal notch a JunctionColumn
## owns, so it has no way to select one on purpose; a grenade's flood is
## omnidirectional and reaches that same diagonal GU like any other. Default
## `[]` keeps every existing caller (firearms among them) exactly as it was.
static func find_affected_containers(gu_rings: Dictionary, edge_registry: EdgeRegistry,
		slab_registry: SlabRegistry, junction_columns: Array = []) -> Dictionary:
	var hit_slices: Dictionary = {}
	for gu in gu_rings:
		var ring: int = gu_rings[gu]
		for edge in edge_registry.edges_touching_gu(gu):
			for slice in edge_registry.slices_of_edge(edge.id):
				if not hit_slices.has(slice.id) or ring < hit_slices[slice.id]:
					hit_slices[slice.id] = ring

	## VL-02c (Director, 2026-07-23): a blast cracks the GROUND as well as the
	## walls and roof. FLOOR/INTERIOR slabs were skipped here, so a grenade left
	## the floor pristine — the crater had no bottom. Roofs and floors are kept
	## in separate buckets because they resolve through different
	## BlastCalculator entry points downstream: roofs through
	## apply_container_damage()'s ring/level model (same as walls, since D14
	## retired the roof-vs-wall ring-step asymmetry this comment used to cite),
	## floors through apply_crater_damage()'s radial-rim model (D2's two-layer
	## floor, D9's real-material lookup) — not a ring-step difference anymore.
	var hit_roofs: Dictionary = {}
	var hit_floors: Dictionary = {}
	for slab in slab_registry.all_slabs():
		if not gu_rings.has(slab.gu_cell):
			continue
		if slab.role == Slab.Role.CEILING:
			hit_roofs[slab.id] = gu_rings[slab.gu_cell]
		else:
			hit_floors[slab.id] = gu_rings[slab.gu_cell]

	## E-JUNCTION-01: one column per diagonal GU (JunctionResolver.resolve()'s
	## own cells_seen dictionary guarantees that), so membership in gu_rings is
	## the whole test — no edge-touching search needed, unlike slices.
	var hit_junctions: Dictionary = {}
	for column in junction_columns:
		if not gu_rings.has(column.gu_cell):
			continue
		hit_junctions[column.id] = gu_rings[column.gu_cell]

	return {"slices": hit_slices, "roofs": hit_roofs, "floors": hit_floors,
		"junctions": hit_junctions}


## ============================================================================
## P-PURE (PREDICTION_MASTER_PLAN Task 2, 2026-08-09) — the two blast mutators
## became `commit(simulate(…))`.
##
## `simulate_*` computes a blast's damage and writes NOTHING; `commit_damage()`
## is the only thing in this pipeline that touches a Voxel. That split is what
## lets the engine answer "what would this grenade do" without doing it, which
## is the whole of PREDICTION_MASTER_PLAN §3.
##
## **The signatures, the rolls, the ring maths and every hash salt are byte for
## byte what they were.** `apply_*` keeps its old signature and its old
## behaviour exactly, which is why `blast_calculator_selftest.gd`'s ~20 direct
## call sites are the regression net for this refactor and were not edited.
##
## **The read-overlay the plan feared does not exist — a finding, not a
## shortcut.** §3.3 called it "the single highest-risk detail in the refactor",
## on the belief that these functions read `voxel.damage_state` as they go and
## that a voxel destroyed earlier in a pass changes what a later one does.
## Measured instead: the ONLY Voxel state access in either function is the
## `set_damage()` write itself — zero reads of `damage_state`, `visible`, or any
## other damage field — and no voxel is written twice in one call (ring groups
## partition the voxels; destroy/dent/crack are disjoint draws from one shrinking
## pool; a crater voxel takes at most one branch). There is no in-pass cascade to
## overlay, so the pure version needs no notion of "state as of this simulation
## so far".
##
## What DOES depend on prior state is `Voxel.set_damage()`'s own early return
## (`damage_state == new_state`) and the read-once rule for the other four
## fields. Those stay in the commit, exactly where they always were — so a Delta
## replayed onto a world that has moved on behaves identically to a direct call,
## instead of the prediction quietly baking in the world it was computed against.
## ============================================================================

## One pending `set_damage()` call. A damage Delta is an ordered Array of these.
## Ordered, because replaying them in the order the simulation produced them is
## what makes `commit_damage(simulate(…))` identical to the old direct calls by
## construction, rather than by an argument that order happens not to matter.
static func damage_entry(voxel, state: int, from_blast: bool,
		carved_side: int = Voxel.CarvedSide.NONE, variant: int = 0,
		substrate: int = 0) -> Dictionary:
	return {"voxel": voxel, "state": state, "from_blast": from_blast,
		"carved_side": carved_side, "variant": variant, "substrate": substrate}


## Applies a damage Delta — the single writer the blast pipeline has left.
## Deliberately dumb: no rolls, no lookups, no geometry. Everything that could
## be wrong was decided in the simulate.
static func commit_damage(entries: Array) -> void:
	for e in entries:
		e["voxel"].set_damage(e["state"], e["from_blast"], e["carved_side"],
			e["variant"], e["substrate"])


## Computes ring falloff + material resistance for one container's (Slice or
## Slab) voxels and returns the damage Delta — the `set_damage()` calls that
## WOULD be made. Writes nothing (P-PURE, above); `apply_container_damage()`
## below is this plus `commit_damage()`, and remains the only writer path, per
## DESTRUCTION_MASTER_PLAN §3.
##
## D14 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06 — spherical falloff,
## confirmed against real code 2026-08-06): the vertical ring step is now
## IDENTICAL for wall and roof — `absi(level_offset) / LEVELS_PER_STOREY` —
## retiring the deliberate asymmetry this comment used to document (roofs
## advancing one ring per RAW level). That asymmetry existed because
## ROOF_LEVEL_COUNT (~2 levels) is far smaller than LEVELS_PER_STOREY (8), so
## a whole-storey step looked like it would collapse every roof level into
## ring 0 — which, read as a SPHERE (one ring per 8 voxels in every
## direction, VOXELS_PER_UNIT_AXIS == LEVELS_PER_STOREY == 8 by construction),
## is exactly correct: a 2-level-thick roof genuinely sits at one distance
## from a blast at floor level, so uniform damage across both levels is the
## geometrically right answer, not a bug the old stepping was covering for.
## `absi` (not `maxi(0, …)`) makes the sphere symmetric below the blast's own
## floor level too — load-bearing for D15 (a grenade thrown onto a roof puts
## real, destructible geometry *below* the blast for the first time).
## is_roof is UNCHANGED for its other job: carved_side_for() still uses it to
## pick BOTTOM (a ceiling hit from below, the ring-group path) vs LEFT/RIGHT
## (a wall) — unrelated to the vertical-ring formula, not touched by D14.
##
## VL-D4 (Director, 2026-07-26): "acentuar destruição na face mais próxima da
## granada" — bias_epicenter (voxel-space; NO_EPICENTER_BIAS = off) makes
## _select_deterministic() prefer voxels CLOSER to it within each ring group,
## so of a wall's two faces (or a block's near/far side), the one actually
## facing the blast visibly loses more material than the far side — a real
## effect the flat ring model couldn't produce (ring is a per-GU distance, the
## SAME for both faces of one edge). General-purpose, not material-gated: it
## also sharpens concrete/stone/metal, wood is just where it reads strongest
## (destroy_factor 0.9).
## WEAPON_MASTER_PLAN D2 — destroy_multiplier is the calibre/punch knob: it
## scales MaterialResistanceTable's per-material destroy_factor, so a light
## round only scratches concrete where a heavy one bites into it. Trailing and
## defaulted to 1.0, so every pre-existing caller (all of them grenades) is
## byte-for-byte unaffected — the same technique bias_epicenter uses above.
## §4.2 (D1 rev, 2026-08-06) — destroy/dent/crack_ring_weights replace the
## single ring_multipliers[ring] scaling read: today every ring rolled all
## three tiers off ONE multiplier; the Director's table gates tiers BY ring
## (dented never in ring 2, cracked never in ring 0), which needs three
## independent per-tier arrays. ring_multipliers itself is UNCHANGED in its
## other job — flood_gu_rings()'s range cap, and the `ring >= size(): skip`
## gate just below, both still read its length, not the new arrays'.
## MaterialResistanceTable keeps multiplying in exactly as before (D1's own
## clarification) — this is an ADDITIONAL term, not a replacement of it.
static func simulate_container_damage(voxels: Array, container_id: String, material: String,
		base_ring: int, base_level: int, is_roof: bool, ring_multipliers: Array[float],
		destroy_ring_weights: Array[float], dent_ring_weights: Array[float],
		crack_ring_weights: Array[float],
		bias_epicenter: Vector2i = NO_EPICENTER_BIAS,
		destroy_multiplier: float = 1.0) -> Array:
	var entries: Array = []
	var by_ring: Dictionary = {}  # ring -> Array[Voxel]
	for voxel in voxels:
		var level_offset: int = voxel.level - base_level
		var ring: int = base_ring + vertical_ring_for(level_offset)
		if ring >= ring_multipliers.size():
			continue
		if not by_ring.has(ring):
			by_ring[ring] = []
		by_ring[ring].append(voxel)

	for ring in by_ring:
		var group: Array = by_ring[ring]
		var d_w: float = destroy_ring_weights[ring] if ring < destroy_ring_weights.size() else 0.0
		var n_w: float = dent_ring_weights[ring] if ring < dent_ring_weights.size() else 0.0
		var c_w: float = crack_ring_weights[ring] if ring < crack_ring_weights.size() else 0.0
		var destroy_n: int = int(round(d_w * MaterialResistanceTable.destroy_factor(material)
			* destroy_multiplier * group.size()))
		var dent_n: int = int(round(n_w * MaterialResistanceTable.dent_factor(material) * group.size()))
		var crack_n: int = int(round(c_w * MaterialResistanceTable.crack_factor(material) * group.size()))

		var destroy_set: Array = _select_deterministic(group, container_id, "DESTROY", destroy_n, bias_epicenter)
		var destroyed_lookup: Dictionary = {}
		for v in destroy_set:
			destroyed_lookup[v] = true
		var after_destroy: Array = group.filter(func(v): return not destroyed_lookup.has(v))

		## D22: DENTED (sunken, more severe) is drawn from the pool BEFORE
		## CRACKED (flat mark, less severe), so a voxel never lands in the
		## milder tier when it also qualified for the harsher one.
		var dent_set: Array = _select_deterministic(after_destroy, container_id, "DENT", dent_n, bias_epicenter)
		var dented_lookup: Dictionary = {}
		for v in dent_set:
			dented_lookup[v] = true
		var remaining: Array = after_destroy.filter(func(v): return not dented_lookup.has(v))
		var crack_set: Array = _select_deterministic(remaining, container_id, "CRACK", crack_n, bias_epicenter)

		## PERF-02 B3: DESTROYED now records its blast provenance too. It never
		## did before because a destroyed voxel is erased — there is no variant
		## to pick, so nothing read the flag — but soot is seeded from exactly
		## these holes, and the bomb-only wider radius cannot tell a crater from
		## a bullet hole without it. Measured, not assumed: with the flag left
		## false here, every hole fell into the FIREARM bucket and B3's wider
		## radius produced a byte-identical soot map (925 sooted voxels either
		## way) on the real PLAYGROUND blast.
		for voxel in destroy_set:
			entries.append(damage_entry(voxel, Voxel.DamageState.DESTROYED, true))
		## D23: this is the ring-group scatter model, used only by RADIAL — a
		## blast's DENTED/CRACKED voxels get the irregular chip/crack texture
		## family, never the bullet's round puncture.
		## D25: DENTED additionally carries WHICH SIDE the blast ate, so the
		## renderer can pick the matching carved half-voxel.
		## D32.5: the decal variant is drawn from the container's own id plus the
		## voxel's cell, so two voxels of the same blast rarely share art, and a
		## re-run of the same detonation reproduces it exactly.
		for voxel in dent_set:
			entries.append(damage_entry(voxel, Voxel.DamageState.DENTED, true,
				carved_side_for(voxel.grid_pos, is_roof, bias_epicenter),
				decal_variant_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level),
				substrate_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level)))
		for voxel in crack_set:
			entries.append(damage_entry(voxel, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE,
				decal_variant_for(container_id, voxel.grid_pos.y, voxel.grid_pos.x + voxel.level),
				substrate_for(container_id, voxel.grid_pos.y, voxel.grid_pos.x + voxel.level)))
	return entries


## The mutating call, unchanged for every caller that already had one:
## `commit(simulate(…))`. Kept — not deprecated — because DetonationPlanBuilder
## and ~20 selftest sites legitimately want the damage to happen, and because
## those sites are precisely the regression net that pins this refactor.
static func apply_container_damage(voxels: Array, container_id: String, material: String,
		base_ring: int, base_level: int, is_roof: bool, ring_multipliers: Array[float],
		destroy_ring_weights: Array[float], dent_ring_weights: Array[float],
		crack_ring_weights: Array[float],
		bias_epicenter: Vector2i = NO_EPICENTER_BIAS,
		destroy_multiplier: float = 1.0) -> void:
	commit_damage(simulate_container_damage(voxels, container_id, material, base_ring,
		base_level, is_roof, ring_multipliers, destroy_ring_weights, dent_ring_weights,
		crack_ring_weights, bias_epicenter, destroy_multiplier))


## D14's spherical vertical-ring step, extracted out of apply_container_damage()
## (EXPLOSION_REBUILD_MASTER_PLAN Task 3/E-SOOT, 2026-08-07) so the soot stamp
## functions below reuse the exact same formula textually instead of a second
## copy free to drift out of sync. Pure extraction — apply_container_damage()'s
## own behavior is unchanged (see D14's doc comment above for the formula's
## rationale). Kept public, not `_`-prefixed (Task 4/E-PLAN, 2026-08-07):
## DetonationPlanBuilder is a second, cross-file consumer that needs the exact
## same per-voxel ring a container's damage/soot calls already used, to group
## its plan entries by ring — a private name would invite a silently drifting
## second copy in that file instead.
static func vertical_ring_for(level_offset: int) -> int:
	return int(floor(float(absi(level_offset)) / float(GeometryCoords.LEVELS_PER_STOREY)))


## D32.5 — which of the three authored decals a mark uses.
##
## Deterministic over the caller's own identifiers, never `randi()`: the same
## detonation or the same shot reproduces the same art, which is what makes a
## capture comparable against the next one. The value is STORED on the Voxel
## (see Voxel.damage_variant) rather than re-derived at paint time, because
## grid_pos is view-space and re-deriving it would re-roll every mark on
## rotation.
static func decal_variant_for(salt: String, a: int, b: int) -> int:
	var count: int = VoxelRenderer.IMPACT_DECAL_VARIANTS
	if count <= 1:
		return 0
	return FacadeSampler._fnv1a_hash("%s:DECAL:%d:%d" % [salt, a, b]) % count


## D3/§3.3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) — which of the 3
## pre-baked substrate crops a mark's decal sits on. Line-for-line
## decal_variant_for()'s shape, deliberately keyed under a DIFFERENT hash
## salt segment ("SUBSTRATE" vs "DECAL") so substrate choice never
## correlates with decal choice — two marks that roll the same decal variant
## should not systematically also land on the same substrate. Stored on the
## Voxel (see Voxel.damage_substrate) for the identical reason decal_variant
## is stored: grid_pos is view-space, re-deriving at paint time would re-roll
## every mark's substrate on rotation.
static func substrate_for(salt: String, a: int, b: int) -> int:
	var count: int = VoxelRenderer.DAMAGE_SUBSTRATE_VARIANTS
	if count <= 1:
		return 0
	return FacadeSampler._fnv1a_hash("%s:SUBSTRATE:%d:%d" % [salt, a, b]) % count


## D25 (Director diagram, 2026-07-31) — which side of `voxel_cell` faced the
## explosion, as a Voxel.CarvedSide in VIEW space.
##
## Fixes the Director's 2026-07-31 report that a ceiling above a grenade showed
## its damage on the outward TOP, "por cima", when a blast that passes under a
## slab can only ever eat its underside: a roof container is by construction
## above the blast that reached it, so it carves BOTTOM — the diagram's
## "DENTED CEILING VOXEL", which is pure silhouette (an isometric camera never
## sees a ceiling's underside, hence no broken face on that variant).
##
## For a wall the choice is left/right, and it is decided in SCREEN space
## rather than by the slice's compass face: the isometric projection puts
## screen-x along (x − y), so the epicentre is to the screen-left of a voxel
## exactly when its (x − y) is the smaller one. Deriving it this way means any
## of the four horizontal faces resolves to a visible carve — a blast arriving
## from a back-facing NE/NW side still picks the side its direction leans
## toward on screen, instead of selecting a face the camera cannot see.
##
## Returns CarvedSide.NONE when no epicentre was supplied (the pure-hash
## callers and their tests), which renders the flat pre-D25 mark instead of
## inventing a direction.
static func carved_side_for(voxel_cell: Vector2i, is_roof: bool,
		bias_epicenter: Vector2i) -> int:
	if bias_epicenter == NO_EPICENTER_BIAS:
		return Voxel.CarvedSide.NONE
	if is_roof:
		return Voxel.CarvedSide.BOTTOM
	var epi_screen_x: int = bias_epicenter.x - bias_epicenter.y
	var vox_screen_x: int = voxel_cell.x - voxel_cell.y
	return Voxel.CarvedSide.LEFT if epi_screen_x < vox_screen_x else Voxel.CarvedSide.RIGHT


## D25 — VIEW-space CarvedSide → BASE-space unit direction pointing at the
## blast, and back. These live here, beside carved_side_for(), because the
## carved side is one concept with one owner: room.gd only persists what this
## class decides. TOP/BOTTOM are vertical and rotation-invariant; LEFT/RIGHT
## are a screen-space read of the two front-facing horizontal edges (SW and SE,
## grid deltas (0,+1) and (+1,0)) and therefore DO rotate.
##
## The rotation goes through PerspectiveMapper by taking the difference of two
## rotated points: the affine offsets cancel, so there is no second rotation
## formula here to drift out of sync with the one real one.
static func carved_side_to_base_dir(grid_pos: Vector2i, carved_side: int,
		perspective: String, base_size: Vector2i) -> Vector3i:
	match carved_side:
		Voxel.CarvedSide.TOP:
			return Vector3i(0, 0, 1)
		Voxel.CarvedSide.BOTTOM:
			return Vector3i(0, 0, -1)
		Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT:
			var view_dir := Vector2i(0, 1) if carved_side == Voxel.CarvedSide.LEFT else Vector2i(1, 0)
			var a := PerspectiveMapper.cell_to_base(grid_pos, perspective, base_size)
			var b := PerspectiveMapper.cell_to_base(grid_pos + view_dir, perspective, base_size)
			return Vector3i(b.x - a.x, b.y - a.y, 0)
		_:
			return Vector3i.ZERO


## Inverse of the above, for whichever perspective the room is in NOW.
## Horizontal directions are re-projected and classified by the sign of their
## screen-x ((x − y) under this isometric projection) — the same test
## carved_side_for() applies at detonation time, so a hole recorded in one view
## and read back in another lands on the side still facing the blast.
static func carved_side_from_base(base_xy: Vector2i, dir: Vector3i,
		perspective: String, base_size: Vector2i) -> int:
	if dir.z > 0:
		return Voxel.CarvedSide.TOP
	if dir.z < 0:
		return Voxel.CarvedSide.BOTTOM
	if dir.x == 0 and dir.y == 0:
		return Voxel.CarvedSide.NONE
	var a := PerspectiveMapper.cell_from_base(base_xy, perspective, base_size)
	var b := PerspectiveMapper.cell_from_base(base_xy + Vector2i(dir.x, dir.y), perspective, base_size)
	var view_dir := b - a
	return Voxel.CarvedSide.LEFT if (view_dir.x - view_dir.y) < 0 else Voxel.CarvedSide.RIGHT


## VL-D2 — Contiguous crater on the ground.
##
## The ring/hash-rank model (apply_container_damage) scatters holes across a GU,
## which never reads as a crater — half the floor stippled away, no shape. This
## carves the floor RADIALLY from the grenade's epicentre instead: a solid core
## out to core_radius (a real bowl bottom), a crumbling rim out to max_radius
## (deterministic FNV threshold falling to 0, so the edge is ragged not a drawn
## circle), nothing beyond. This is the "contiguous removal" flagged under
## VL-02c; it also makes the soot rings read as rings around one hole instead of
## merging into a stipple. Floors only — walls/roofs keep the ring model, their
## holes already read against the wall silhouette.
##
## epicenter is in VOXEL coords; each affected floor slab passes its own voxels
## and the SAME global epicentre, so the destroyed disc is contiguous across GU
## boundaries. Deterministic (no RNG), same inputs → same crater.
##
## FLOOR-DENT-01 (Director, 2026-08-01): "o dent no chão também, sendo mais ou
## menos prevalente de acordo com a soma de todas as variáveis de destruição."
## E-CRACK-01 — the outermost crater ring a surface mark can reach. Ring 0 is the
## crater itself (d <= max_radius) and each further ring is one rim_span-wide band
## (crater_ring_for()), so ring 2 puts the mark band's outer edge at
## `max_radius + 2*rim_span` — one band further out than the dent-only model
## reached, which is exactly the room CRACKED needs to sit outside DENTED. Rings
## past this are the blast's soot-only reach (§4.1's "ring 3 carries soot").
## `var`, not `const` — architecture rule 1, this is a tuning lever.
static var CRATER_DAMAGE_MAX_RING: int = 2

## A rim voxel that SURVIVES the destroy roll — and any voxel in a band one
## rim-width past the crater — takes a second, independent roll to become a
## carved-TOP DENTED pockmark (D25's half-voxel; a floor is only ever eaten
## from above, the mirror of a ceiling only ever carving BOTTOM). Prevalence is
## the product of every variable already in play: the material's dent_factor
## (MaterialResistanceTable — "earth" 0.3; a material with no row rolls 0 and
## stays dent-free, the table's own no-texture rule), the bomb's size (core/
## max radii and therefore rim_span set both the band's width and where the
## falloff sits), and the voxel's distance (full factor out to max_radius,
## fading linearly to zero across one further rim_span). material is trailing
## + defaulted to "" (dent_factor 0.0) so every pre-existing caller and test
## is byte-for-byte unaffected.
##
## D2 (EXPLOSION_REBUILD_MASTER_PLAN §4.4, 2026-08-06) — deep_layer_unlocked
## gates GeometryCoords.FLOOR_DEEP_LEVEL voxels out entirely (no destroy roll,
## no dent roll — left INTACT) when false, the principled replacement for the
## removed PERF-02 B4 hack ("skip FLOOR_-2 entirely"). Trailing + defaulted to
## false, matching D2's own rule ("the first blast on a GU only reaches
## FLOOR_TOP_LEVEL"); the caller flips it true from a GU's second blast
## onward via room._gu_blast_count — that state/wiring is Task 5 (E-WAVE)'s
## job, since no live caller exists yet to drive it (confirmed this task).
##
## D17 — slab_pierce_multiplier is a future calibration knob ("posteriormente
## podemos... deixar um multiplicador atrelado pra calibrar isso", Director)
## for punching further through an already-weakened slab. Scales BOTH the
## destroy probability (keep_prob) and the dent probability (dent_p) the same
## way destroy_multiplier scales apply_container_damage()'s tier counts.
## Trailing + defaulted to 1.0 (byte-for-byte inert) — no real caller drives a
## non-1.0 value yet, since no stacked-slab scenario exists in any real map
## today (confirmed this task); the knob exists so a future one can be added
## without touching this function's signature again.
##
## E-CRACK-01 (Director, 2026-08-08) — the floor finally reaches CRACKED, "seguindo
## o modelo da parede". Until now a crater produced DESTROYED and DENTED only, so
## FLOOR/cracked measured 0 on every real PLAYGROUND blast regardless of the
## material's crack_factor, and D19's "floors crack like walls" was closed in the
## DATA (one concrete row, crack_factor 0.1) but never in this function.
##
## The ladder is the Director's own, per voxel and in severity order — "um voxel
## que recebe muito é destruído, o que recebe um pouco menos fica dented, o
## próximo fica cracked, quase quebrando mas ainda resistiu". That is exactly
## apply_container_damage()'s D22 pool order (destroy → dent → crack, each drawn
## from what the previous tier left), applied here per voxel instead of per ring
## group because a crater is radial, not ring-flooded. HYBRID states (a voxel both
## dented AND cracked) are deliberately NOT built — the Director scoped them out
## explicitly ("acho que nesse momento isso não é tão importante").
##
## dent_ring_weights/crack_ring_weights are the bomb's OWN tables (§4.2), indexed
## by crater_ring_for() so the floor and the wall finally read the same authored
## numbers instead of the floor carrying a private falloff. Trailing + defaulted
## to `[]`, which means: dent → un-gated (weight 1.0, today's behaviour exactly),
## crack → 0.0 (off). Every pre-existing caller and selftest is therefore
## byte-for-byte unaffected, the same discipline D2/D17 used on this signature.
##
## P-PURE: the pure half. Returns the damage Delta and writes nothing — see the
## P-PURE block above apply_container_damage() for what that does and does not
## change. `apply_crater_damage()` below is this plus `commit_damage()`.
static func simulate_crater_damage(voxels: Array, container_id: String,
		epicenter: Vector2i, core_radius: float, max_radius: float,
		material: String = "", deep_layer_unlocked: bool = false,
		slab_pierce_multiplier: float = 1.0,
		dent_ring_weights: Array[float] = [],
		crack_ring_weights: Array[float] = []) -> Array:
	var entries: Array = []
	var rim_span: float = maxf(max_radius - core_radius, 0.001)
	var dent_f: float = MaterialResistanceTable.dent_factor(material)
	var crack_f: float = MaterialResistanceTable.crack_factor(material)
	for voxel in voxels:
		if voxel.level == GeometryCoords.FLOOR_DEEP_LEVEL and not deep_layer_unlocked:
			continue
		var d: float = Vector2(voxel.grid_pos - epicenter).length()
		## The SAME numbered ring soot and the wave choreography already use for a
		## radially-damaged container — never a second banding scheme.
		var ring: int = crater_ring_for(d, max_radius, rim_span)
		if d <= core_radius:
			## PERF-02 B3: blast provenance on the hole itself — see
			## apply_container_damage()'s own note for why it matters now.
			entries.append(damage_entry(voxel, Voxel.DamageState.DESTROYED, true))
		elif d <= max_radius:
			## Probability of removal falls 1→0 across the rim; a deterministic
			## per-voxel hash in [0,1) is compared against it, so the same voxels
			## always go and the boundary is ragged rather than a perfect circle.
			var keep_prob: float = clampf(
				(1.0 - (d - core_radius) / rim_span) * slab_pierce_multiplier, 0.0, 1.0)
			var key: String = "%s:CRATER:%d,%d,%d" % [container_id, voxel.grid_pos.x, voxel.grid_pos.y, voxel.level]
			var h: float = float(FacadeSampler._fnv1a_hash(key) % 10000) / 10000.0
			if h < keep_prob:
				entries.append(damage_entry(voxel, Voxel.DamageState.DESTROYED, true))
			else:
				_append_floor_surface_damage(entries, voxel, container_id, d, max_radius,
					rim_span, ring, dent_f, crack_f, dent_ring_weights, crack_ring_weights,
					slab_pierce_multiplier)
		elif ring <= CRATER_DAMAGE_MAX_RING:
			_append_floor_surface_damage(entries, voxel, container_id, d, max_radius,
				rim_span, ring, dent_f, crack_f, dent_ring_weights, crack_ring_weights,
				slab_pierce_multiplier)
	return entries


## The mutating call, unchanged for every caller: `commit(simulate(…))`. Same
## rationale as apply_container_damage()'s own wrapper.
static func apply_crater_damage(voxels: Array, container_id: String,
		epicenter: Vector2i, core_radius: float, max_radius: float,
		material: String = "", deep_layer_unlocked: bool = false,
		slab_pierce_multiplier: float = 1.0,
		dent_ring_weights: Array[float] = [],
		crack_ring_weights: Array[float] = []) -> void:
	commit_damage(simulate_crater_damage(voxels, container_id, epicenter, core_radius,
		max_radius, material, deep_layer_unlocked, slab_pierce_multiplier,
		dent_ring_weights, crack_ring_weights))


## FLOOR-DENT-01 + E-CRACK-01 — one surviving floor voxel's damage roll, in the
## Director's severity order: DENTED (a sunken TOP carve, harsher) is offered the
## voxel first, and only a voxel it passes over is offered to CRACKED (a flat
## surface fracture, milder — "quase quebrando, mas ainda resistiu"). Same order,
## same reason, as apply_container_damage()'s D22 pool draw on a wall.
##
## Three independent hash salts (":FLOORDENT:", ":FLOORCRACK:", and the destroy
## roll's own ":CRATER:") so no tier's selection correlates with another's —
## surviving the crater must not predict denting, and failing the dent roll must
## not predict cracking.
##
## The two tiers fall off over DIFFERENT spans, which is what makes the ladder
## read spatially as well as per-voxel: dent is full strength inside the crater
## and fades to nothing one rim_span past it, while crack only starts fading a
## rim_span later. Near the hole a mark is almost always a dent; far out it is
## almost always a crack; in between they mix. Each is then scaled by the bomb's
## own ring weight for that crater ring (§4.2's tables — the wall's numbers,
## reused, not a parallel set).
##
## Carved side: TOP for a dent (a floor is only ever eaten from above), NONE for
## a crack (D32.3 — "a blast cracks the whole voxel, one name, no side").
## pierce_multiplier: D17, see apply_crater_damage's own doc — trailing +
## defaulted to 1.0, byte-for-byte inert at default.
##
## P-PURE: renamed from `_roll_floor_surface_damage()` and given the Delta to
## append to instead of a Voxel to write. The name change is not cosmetic — a
## `_roll_*` that no longer rolls onto anything would misdescribe the one thing
## that matters about it now.
static func _append_floor_surface_damage(entries: Array, voxel, container_id: String,
		d: float, max_radius: float, rim_span: float, ring: int, dent_f: float,
		crack_f: float, dent_ring_weights: Array[float], crack_ring_weights: Array[float],
		pierce_multiplier: float = 1.0) -> void:
	var dent_p: float = clampf(dent_f
		* clampf(1.0 - (d - max_radius) / rim_span, 0.0, 1.0)
		* _ring_weight(dent_ring_weights, ring, 1.0) * pierce_multiplier, 0.0, 1.0)
	if dent_p > 0.0:
		var dent_key: String = "%s:FLOORDENT:%d,%d,%d" % [container_id, voxel.grid_pos.x, voxel.grid_pos.y, voxel.level]
		var dent_h: float = float(FacadeSampler._fnv1a_hash(dent_key) % 10000) / 10000.0
		if dent_h < dent_p:
			entries.append(damage_entry(voxel, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP,
				decal_variant_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level),
				substrate_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level)))
			return

	var crack_p: float = clampf(crack_f
		* clampf(1.0 - (d - (max_radius + rim_span)) / rim_span, 0.0, 1.0)
		* _ring_weight(crack_ring_weights, ring, 0.0) * pierce_multiplier, 0.0, 1.0)
	if crack_p <= 0.0:
		return
	var crack_key: String = "%s:FLOORCRACK:%d,%d,%d" % [container_id, voxel.grid_pos.x, voxel.grid_pos.y, voxel.level]
	var crack_h: float = float(FacadeSampler._fnv1a_hash(crack_key) % 10000) / 10000.0
	if crack_h < crack_p:
		entries.append(damage_entry(voxel, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE,
			decal_variant_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level),
			substrate_for(container_id, voxel.grid_pos.x, voxel.grid_pos.y + voxel.level)))


## One tier's ring weight, or `absent` when the caller passed no table at all
## (see apply_crater_damage's own doc for what each default means). A ring past
## the table's end weighs 0.0 — same rule apply_container_damage() applies to the
## identical tables, so "the bomb declares no 4th ring" means the same thing on a
## floor as on a wall.
static func _ring_weight(weights: Array[float], ring: int, absent: float) -> float:
	if weights.is_empty():
		return absent
	return weights[ring] if ring >= 0 and ring < weights.size() else 0.0


## FLOOR-DEPTH-01 (Director, 2026-07-28): "a segunda camada do chão mais difícil
## de destruir fora da GU 0,0" — the deep ground plane cedes ONLY inside the
## blast's own GU (ring 0), and even there only across this fraction of the
## surface crater's radii. Two effects in one number: the hole narrows with depth
## (a bowl, not a shaft — the same disc repeated at every level reads as a
## punched-out cylinder), and one grenade can no longer strip the whole ground
## stack across the GUs it merely reaches. The ring-0 gate itself lives at the
## call site, with the rest of the per-container ring logic.
const DEEP_FLOOR_CRATER_FACTOR := 0.5


## Soot ring stamped on a freshly exposed crater floor. Ring 0 = darkest, VL-D2's
## original call ("the bottom of a blast crater is the most burned surface there
## is", Director 2026-07-24).
##
## Briefly raised to 2 on 2026-07-28 to let the per-depth tone steps read against a
## brighter floor, and REVERTED the same day: lightening the crater inward looked
## wrong. Director's ruling — soot ADDS to the per-level tone instead of competing
## with it, everything gets darker downward, and losing the texture to shadow at
## the bottom is acceptable. The layer separation therefore comes entirely from
## VoxelRenderer.FLOOR_DEPTH_DIM, which was re-tuned for that job.
##
## Kept as a named constant rather than returning to a bare literal 0: the
## detonation path and the post-rotation replay both write it, and they must never
## disagree or the crater would change shade when the map turns.
const EXPOSED_FLOOR_SOOT_RING := 0


## Deterministic "which N of M" — hash-and-rank, mirroring
## EarthVariantSelector's use of FacadeSampler._fnv1a_hash (D4/B4): same
## inputs always produce the same subset, no RNG, nothing stored.
##
## VL-D4: bias_epicenter (default NO_EPICENTER_BIAS — every existing caller/test
## is unaffected byte-for-byte) switches the sort to "closest to the epicenter
## first," hash-ranked only as a tie-break among voxels at the same integer
## distance — so the near side of a ring group is consistently selected before
## the far side, while voxels genuinely equidistant still scatter the same
## organic way the pure-hash path always has. 2D only (grid_pos.x/y): the
## vertical axis is already the ring system's own job (LEVELS_PER_STOREY
## steps), mixing it in here would double-count height as if it were facing.
static func _select_deterministic(voxels: Array, container_id: String, salt: String, n: int,
		bias_epicenter: Vector2i = NO_EPICENTER_BIAS) -> Array:
	if n <= 0 or voxels.is_empty():
		return []
	var ranked: Array = voxels.duplicate()
	if bias_epicenter == NO_EPICENTER_BIAS:
		ranked.sort_custom(func(a, b) -> bool:
			var key_a: String = "%s:%s:%d,%d,%d" % [container_id, salt, a.grid_pos.x, a.grid_pos.y, a.level]
			var key_b: String = "%s:%s:%d,%d,%d" % [container_id, salt, b.grid_pos.x, b.grid_pos.y, b.level]
			return FacadeSampler._fnv1a_hash(key_a) < FacadeSampler._fnv1a_hash(key_b)
		)
	else:
		ranked.sort_custom(func(a, b) -> bool:
			var da: int = (a.grid_pos - bias_epicenter).length_squared()
			var db: int = (b.grid_pos - bias_epicenter).length_squared()
			if da != db:
				return da < db
			var key_a: String = "%s:%s:%d,%d,%d" % [container_id, salt, a.grid_pos.x, a.grid_pos.y, a.level]
			var key_b: String = "%s:%s:%d,%d,%d" % [container_id, salt, b.grid_pos.x, b.grid_pos.y, b.level]
			return FacadeSampler._fnv1a_hash(key_a) < FacadeSampler._fnv1a_hash(key_b)
		)
	return ranked.slice(0, mini(n, ranked.size()))


## VL-D1/D24 — Soot rings around holes, DERIVED fresh every repaint from
## which voxels are currently absent — never stored on the Voxel itself.
## *(Director, 2026-07-30, confirming S3's closure: "queremos o sistema de
## derivar a fuligem de acordo com os voxels faltantes, em vez de guardar a
## informação de cada um.")*
##
## A multi-source BFS outward from every currently-DESTROYED cell tags
## surviving neighbours with a ring index (0 = touching the hole, darkest;
## rising outward, fainter) into `out_snapshot` — the exact
## `{level: {grid_pos: ring}}` shape `VoxelLightField.build()` already
## consumed when this lived on `Voxel.soot_ring`, so nothing downstream of
## the snapshot changed. Called once per repaint from `room._build_soot_snapshot()`
## over the WHOLE map's current voxels (not one blast's affected set) — a
## destroyed voxel's absence already survives rotation via `_base_damage`, so
## re-deriving from it fresh needs no separate soot persistence at all.
##
## cell_to_voxel: Vector3i(x, y, level) → Voxel, over every SURVIVING voxel to
## consider (destroyed ones are seeds, not entries — see destroyed_cells).
## n_rings: how many rings to paint (Director: up to 3, bullets effectively
## self-limit to ~1 since an isolated hole has no further-out neighbours that
## are ALSO absent). min-ring wins, so a voxel near two holes takes the
## darker scorch.
##
## FACE-SOOT-01 (Director, 2026-08-01) — `out_faces`, when supplied, additionally
## receives `{level: {grid_pos: Vector3i(ring_top, ring_se, ring_sw)}}`: the same
## scorch resolved PER VISIBLE FACE instead of one value for the whole voxel.
## `FACE_SOOT_CLEAN` (3) means that face takes no soot at all.
##
## Where the direction comes from, and why it costs nothing: the BFS already
## knows the step `d` it reached a voxel through, so `-d` points back at the hole
## — the face pointing that way is the one that faced the blast. That face keeps
## the voxel's own ring; the other two fall `face_soot_falloff` rings back
## (fainter), and past the last ring they come out clean. A voxel reached from
## BELOW or from BEHIND (-X/-Y/-Z) has NO visible face turned toward the hole, so
## all three of its faces take the fainter value — correct, and the reason a
## crater's outer slope reads lighter than its inner wall.
##
## Ties are merged, not raced: a voxel equidistant from two holes (a crater
## corner) takes the strong ring on BOTH the faces that see them, because the
## same-ring branch mins per face instead of keeping whichever direction the
## frontier happened to visit first. That is also what makes the result
## order-independent, hence stable across rebuilds and rotations.
## PERF-02 B3 (Director, 2026-08-04) — `intensity_rings` separates HOW FAR the
## scorch reaches (`n_rings`, a BFS distance) from HOW MANY distinct soot
## intensities exist (`intensity_rings`, a hard property of the encoding, not a
## tuning knob: `VoxelLightField.encode_face_soot()` packs each face into TWO
## BITS — 0/1/2 are real rings and 3 is FACE_SOOT_CLEAN, so a fourth intensity
## is not representable and would silently clamp to "clean", i.e. render as no
## soot at all). Capping the ring rather than widening the format is what makes
## the Director's "a fuligem não é mais forte, é mais distante" implementable:
## the same three tones cover 5 cells of distance instead of 3, with the
## faintest one simply reaching further out.
##
## Defaults to n_rings, which reproduces today's behaviour bit-for-bit for every
## pre-existing caller (with intensity == n_rings the cap is never binding).
## `also_visible` (S-DEEP, 2026-08-12) — cells that are NOT visible yet but will
## be by the time this soot is drawn, so the BFS must scorch them anyway.
##
## The case that forced it, reported by the Director: throwing twice on one GU
## unlocks D2's deep floor layer, and the revealed voxels came up pristine inside
## a blackened crater. They are still hidden at the moment soot is derived — the
## expose path reveals them afterwards — so `voxel.visible` is false and the
## check below skipped them, and `_alt_for()` then read a clean face code.
## Measured: on a second blast every other kind roughly doubles (destroy 244 ->
## 482, expose 640 -> 1280, smoke 484 -> 887) while soot HALVED, 512 -> 240.
##
## Empty by default, so every pre-existing caller — including room.gd's repaint,
## where those voxels are genuinely visible by then — is byte-for-byte unchanged.
static func derive_soot_rings(cell_to_voxel: Dictionary, destroyed_cells: Array,
		n_rings: int, out_snapshot: Dictionary, out_faces: Dictionary = {},
		face_soot_falloff: int = 1, intensity_rings: int = 0,
		also_visible: Dictionary = {}) -> void:
	if destroyed_cells.is_empty() or n_rings <= 0:
		return
	var intensity: int = intensity_rings if intensity_rings > 0 else n_rings
	## Frontier BFS. Seeds are the holes themselves (they have no surviving voxel
	## to tag); their SURVIVING neighbours become ring 0, and so on outward.
	var frontier: Array = destroyed_cells.duplicate()
	const NEIGHBOURS: Array = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	for ring in range(n_rings):
		var next_frontier: Array = []
		for cell in frontier:
			for d in NEIGHBOURS:
				var ncell: Vector3i = cell + d
				var voxel = cell_to_voxel.get(ncell)
				## Only surviving voxels take soot — a destroyed cell is a hole
				## (already a seed) and an absent one is empty air.
				if voxel == null or voxel.damage_state == Voxel.DamageState.DESTROYED:
					continue
				## ...and only ones that will be ON SCREEN. `also_visible` is how a
				## caller says "this one is about to be", see the parameter's note.
				if not voxel.visible and not also_visible.has(ncell):
					continue
				if not out_snapshot.has(voxel.level):
					out_snapshot[voxel.level] = {}
				var level_map: Dictionary = out_snapshot[voxel.level]
				var existing: int = int(level_map.get(voxel.grid_pos, -1))
				## PERF-02 B3: the INTENSITY this distance paints — identical to
				## `ring` whenever intensity == n_rings, which is every
				## pre-existing caller. Compared and stored instead of `ring` so
				## the two branches below keep meaning "a nearer hole already
				## claimed this" and "same tone, another direction" once
				## distances beyond the last intensity all share the faintest one.
				var capped: int = mini(ring, intensity - 1)
				## A nearer hole already claimed this voxel — its own ring wins, and
				## so do its faces. (This also replaces the old `visited` set: a voxel
				## is enqueued exactly once, on the pass that first tags it.)
				if existing >= 0 and existing < capped:
					continue
				var faces := _face_rings_for(capped, -d, intensity, face_soot_falloff)
				if existing < 0:
					level_map[voxel.grid_pos] = capped
					_write_face_rings(out_faces, voxel.level, voxel.grid_pos, faces, false)
					next_frontier.append(ncell)
				else:
					## Same ring, another direction: merge (min per face) so a corner
					## voxel scorches on every side that actually saw a hole.
					_write_face_rings(out_faces, voxel.level, voxel.grid_pos, faces, true)
		frontier = next_frontier
		if frontier.is_empty():
			break


## FACE-SOOT-01 — per-face rings for a voxel tagged at `ring`, reached from the
## direction `toward` (the offset from the voxel back to the cell the BFS came
## from, i.e. pointing at the hole).
##
## Only three faces can ever be seen at once with this camera (VL-02b, and the
## same three the shader classifies): +Z is the top diamond, +X the SE face, +Y
## the SW face. Any other `toward` means the hole is behind or below the voxel,
## and no visible face is turned toward it.
static func _face_rings_for(ring: int, toward: Vector3i, n_rings: int,
		falloff: int) -> Vector3i:
	var faint: int = ring + maxi(falloff, 0)
	if faint >= n_rings:
		faint = FACE_SOOT_CLEAN
	var out := Vector3i(faint, faint, faint)
	if toward == Vector3i(0, 0, 1):
		out.x = ring        ## top
	elif toward == Vector3i(1, 0, 0):
		out.y = ring        ## SE
	elif toward == Vector3i(0, 1, 0):
		out.z = ring        ## SW
	return out


## A caller that does not want per-face data passes nothing and the default dict
## is simply discarded — cheaper than branching on it at every write.
static func _write_face_rings(out_faces: Dictionary, level: int, cell: Vector2i,
		faces: Vector3i, merge: bool) -> void:
	if not out_faces.has(level):
		out_faces[level] = {}
	var level_faces: Dictionary = out_faces[level]
	if merge and level_faces.has(cell):
		var prev: Vector3i = level_faces[cell]
		level_faces[cell] = Vector3i(
			mini(prev.x, faces.x), mini(prev.y, faces.y), mini(prev.z, faces.z))
		return
	level_faces[cell] = faces


## Which numbered ring a floor voxel at distance `d` falls in. Floor voxels are
## damaged RADIALLY (apply_crater_damage(), no discrete ring), so this derives an
## equivalent numbered ring from the exact same distance unit that function
## already uses: ring 0 covers the crater itself (d <= max_radius), and each
## further ring is one more rim_span-wide band beyond it — `rim_span =
## max_radius - core_radius` is apply_crater_damage()'s own falloff unit, reused
## rather than inventing a second one.
##
## Extracted (Task 4/E-PLAN, 2026-08-07) so DetonationPlanBuilder can classify a
## floor voxel's destroy/dent OUTCOME into the same numbered ring — the wave
## choreography groups floor cells by ring exactly like wall/roof cells.
##
## ceil, not floor: floor would put an exact-multiple boundary (e.g. d ==
## max_radius + rim_span) one ring further out than every neighbouring distance a
## fraction closer. A boundary distance belongs to the CLOSER ring, matching every
## other `<=`-based band test in apply_crater_damage().
##
## S-KILL-STAMP (2026-08-12): this used to be documented as a by-product of
## stamp_crater_soot(), which is gone. The banding is unchanged — only its former
## co-owner is.
static func crater_ring_for(d: float, max_radius: float, rim_span: float) -> int:
	return 0 if d <= max_radius else int(ceil((d - max_radius) / rim_span))


## S-DEDUP (2026-08-12) — THE soot field, and the only place its sequence exists.
##
## Blast BFS, then firearm BFS, then min-wins merge, then self-soot. That order
## is load-bearing (self-soot must not beat a real hole's stronger ring) and it
## used to be written out twice: once in `DetonationPlanBuilder._phase_soot()`
## for detonations and once in `room._build_soot_snapshot()` for repaints. The
## two had already drifted apart in two measurable ways before this landed — the
## detonation path read its own literal ring count instead of room's, and only
## the repaint path scorched the revealed crater floor — so this is not tidying,
## it is removing the seam those bugs grew in.
##
## The two BFS passes run into SCRATCH dictionaries and merge afterwards rather
## than sharing one accumulator, and that is not an accident of style:
## `derive_soot_rings()`'s internal min-ring merge cannot compose across two
## calls into the same snapshot, because a second call can never LOWER a ring the
## first already recorded (PERF-02 B3's own finding).
##
## `also_visible` is passed only to the BLAST pass: it means "this blast is about
## to reveal these", which is a statement about the explosion in flight, not
## about old firearm holes. See derive_soot_rings() for the case that forced it.
##
## Callers keep their own indexing, because they genuinely differ — the plan
## builder folds it into its map-wide walk, room walks the two registries — and
## their own handling of non-Voxel cells, which have no entry in `cell_to_voxel`
## for any BFS to reach.
static func build_soot_field(cell_to_voxel: Dictionary, blast_cells: Array,
		weapon_cells: Array, damaged_voxels: Array,
		blast_rings: int, weapon_rings: int,
		out_snapshot: Dictionary, out_faces: Dictionary,
		also_visible: Dictionary = {}, predicted_damaged: Array = []) -> void:
	var blast_snapshot: Dictionary = {}
	var blast_faces: Dictionary = {}
	derive_soot_rings(cell_to_voxel, blast_cells, blast_rings,
		blast_snapshot, blast_faces, 1, FACE_SOOT_CLEAN, also_visible)
	var weapon_snapshot: Dictionary = {}
	var weapon_faces: Dictionary = {}
	derive_soot_rings(cell_to_voxel, weapon_cells, weapon_rings,
		weapon_snapshot, weapon_faces)
	merge_soot_field(out_snapshot, out_faces, blast_snapshot, blast_faces)
	merge_soot_field(out_snapshot, out_faces, weapon_snapshot, weapon_faces)
	apply_self_soot(damaged_voxels, out_snapshot, out_faces)
	## W-PRECOOK-02: damage the caller knows is coming but has not written yet.
	apply_self_soot_predicted(predicted_damaged, out_snapshot, out_faces)


## Merges one scratch soot pass into a snapshot/face pair, min-wins per cell and
## per face component — the same rule `derive_soot_rings()` applies internally,
## needed separately because that rule cannot compose across two calls.
##
## Was `DetonationPlanBuilder._merge_soot()` AND `room._merge_soot_into()`,
## byte-identical 23-line copies of each other (verified line by line before
## either was deleted).
static func merge_soot_field(out_snapshot: Dictionary, out_faces: Dictionary,
		src_snapshot: Dictionary, src_faces: Dictionary) -> void:
	for level in src_snapshot:
		if not out_snapshot.has(level):
			out_snapshot[level] = {}
		var level_map: Dictionary = out_snapshot[level]
		for cell in src_snapshot[level]:
			var ring: int = int(src_snapshot[level][cell])
			var existing: int = int(level_map.get(cell, -1))
			if existing < 0 or ring < existing:
				level_map[cell] = ring
	for level in src_faces:
		if not out_faces.has(level):
			out_faces[level] = {}
		var level_faces: Dictionary = out_faces[level]
		for cell in src_faces[level]:
			var faces: Vector3i = src_faces[level][cell]
			if level_faces.has(cell):
				var prev: Vector3i = level_faces[cell]
				level_faces[cell] = Vector3i(
					mini(prev.x, faces.x), mini(prev.y, faces.y), mini(prev.z, faces.z))
			else:
				level_faces[cell] = faces


## One floor cell scorched at `ring`, isotropic top-only — a floor cell has
## exactly one visible face. Shared by the two places that scorch cells with no
## Voxel behind them: the detonation's revealed FIXED earth level, and room's
## persistent `_crater_floor_soot` replay.
static func scorch_floor_cell(out_snapshot: Dictionary, out_faces: Dictionary,
		level: int, cell: Vector2i, ring: int) -> void:
	if not out_snapshot.has(level):
		out_snapshot[level] = {}
	var level_map: Dictionary = out_snapshot[level]
	if ring < int(level_map.get(cell, FACE_SOOT_CLEAN)):
		level_map[cell] = ring
	_write_face_rings(out_faces, level, cell,
		Vector3i(ring, FACE_SOOT_CLEAN, FACE_SOOT_CLEAN), true)


## D33-SOOT-01 (Director, 2026-08-03): "algumas armas... deixam tudo limpo.
## Precisamos adicionar um pouquinho de fuligem, só pra diferenciar do resto
## da parede." Measured root cause: derive_soot_rings() only ever seeds from
## DESTROYED voxels (holes) — a DENTED or CRACKED voxel that never happens to
## sit next to a hole gets no soot at all, regardless of weapon or material.
## Confirmed structural, not incidental: pistol/metal, pistol/stone and
## shotgun/metal can never cross PUNCH_DESTROY_MIN given RESISTANCE's current
## values (always land DENTED/CRACKED), so those combinations NEVER produced
## a hole to seed from.
##
## This is a deliberate, small extension of D17/D24's "a bullet marks its
## impact; it does not blacken the wall" — not a reversal. It adds a single
## FAINT ring (SELF_SOOT_RING, the lightest of the three — 0.63× brightness,
## `VoxelLightField.soot_darkening[2]`) directly on the struck face of the
## damaged voxel ITSELF. No propagation, no BFS: a dent/crack never darkens
## its neighbours, only its own mark reads as slightly scorched instead of
## pristine. Merged into whatever derive_soot_rings() already produced with
## min-wins (_write_face_rings' own semantics), so a voxel that ALSO happens
## to sit beside a real hole keeps that stronger ring — self-soot only fills
## in where nothing stronger already applies.
const SELF_SOOT_RING := 2


## Which face(s) a damaged (DENTED/CRACKED, not DESTROYED) voxel's own faint
## soot lands on. Mirrors the SAME face-selection rules
## VoxelRenderer's decal plan parsers encode for the visual mark itself
## (kept independent rather than importing VoxelRenderer here — this module
## already owns face-ring resolution, via _face_rings_for() above):
##  - a blast CRACKED voxel marks all three visible faces (D32.3 — "não
##    existe voxel rachado só em uma face");
##  - a bullet (CRACKED or DENTED) marks the one lateral face it struck;
##  - a DENTED voxel's carved_side IS the exposed/cut face, except BOTTOM
##    (ceiling) — no visible face ever faces the camera there, matching
##    derive_soot_rings()'s own reasoning for why a hole reached from below
##    scorches no single face preferentially;
##  - no resolvable side (the pre-D25/D32 fallback) marks the top face, same
##    as the flat mark itself.
static func _self_soot_faces(damage_state: int, blast_sourced: bool, carved_side: int) -> Vector3i:
	var clean := Vector3i(FACE_SOOT_CLEAN, FACE_SOOT_CLEAN, FACE_SOOT_CLEAN)
	if damage_state != Voxel.DamageState.DENTED and damage_state != Voxel.DamageState.CRACKED:
		return clean
	if damage_state == Voxel.DamageState.CRACKED and blast_sourced:
		return Vector3i(SELF_SOOT_RING, SELF_SOOT_RING, SELF_SOOT_RING)
	match carved_side:
		Voxel.CarvedSide.LEFT:
			return Vector3i(FACE_SOOT_CLEAN, FACE_SOOT_CLEAN, SELF_SOOT_RING)   ## SW
		Voxel.CarvedSide.RIGHT:
			return Vector3i(FACE_SOOT_CLEAN, SELF_SOOT_RING, FACE_SOOT_CLEAN)   ## SE
		Voxel.CarvedSide.TOP:
			return Vector3i(SELF_SOOT_RING, FACE_SOOT_CLEAN, FACE_SOOT_CLEAN)   ## top (floor)
		Voxel.CarvedSide.BOTTOM:
			return clean   ## ceiling underside — never visible
		_:
			return Vector3i(SELF_SOOT_RING, FACE_SOOT_CLEAN, FACE_SOOT_CLEAN)   ## NONE -> top, matches the flat mark


## Applies _self_soot_faces() for every voxel in `voxels` (expected: every
## DENTED/CRACKED, currently-visible voxel this room holds — see
## room.gd's _index_soot_voxel()), merging into both out-params exactly like
## derive_soot_rings() populates them: out_faces per-face (render-facing),
## out_snapshot the isotropic min-of-faces ring (soot_factor()/probes/tests).
## Call AFTER derive_soot_rings() so a stronger nearby-hole ring always wins.
static func apply_self_soot(voxels: Array, out_snapshot: Dictionary, out_faces: Dictionary) -> void:
	for v in voxels:
		_write_self_soot(v.level, v.grid_pos, v.damage_state, v.damage_is_blast,
			v.damage_carved_side, out_snapshot, out_faces)


## W-PRECOOK-02 (2026-08-19) — the same thing for damage that has NOT HAPPENED
## YET, from plan_point_impact() entries rather than from live Voxels.
##
## It exists because the shot's warm has to predict the SOOTY world, and reading
## the tuple off the Voxel is exactly what cannot work before the shot: the
## voxel is still INTACT, `_self_soot_faces()` returns clean for INTACT, and the
## whole prediction silently degrades to "no self-soot anywhere". That is not a
## hypothetical — `room._build_soot_snapshot()`'s `predict_damaged` list was
## being fed live Voxels and contributed exactly nothing for that reason, which
## is why the soot pass still minted 19 alternatives of its own.
static func apply_self_soot_predicted(entries: Array, out_snapshot: Dictionary,
		out_faces: Dictionary) -> void:
	for e in entries:
		var v: Voxel = e["voxel"]
		_write_self_soot(v.level, v.grid_pos, int(e["state"]), bool(e["is_blast"]),
			int(e["carved_side"]), out_snapshot, out_faces)


## One damaged voxel's faint own-face soot, merged into the pair of out-params
## min-wins. Shared by the live and the predicted entry points above so the two
## can only ever scorch a mark the same way.
static func _write_self_soot(level: int, grid_pos: Vector2i, damage_state: int,
		blast_sourced: bool, carved_side: int,
		out_snapshot: Dictionary, out_faces: Dictionary) -> void:
	var faces := _self_soot_faces(damage_state, blast_sourced, carved_side)
	if faces == Vector3i(FACE_SOOT_CLEAN, FACE_SOOT_CLEAN, FACE_SOOT_CLEAN):
		return
	_write_face_rings(out_faces, level, grid_pos, faces, true)
	var ring: int = mini(faces.x, mini(faces.y, faces.z))
	if not out_snapshot.has(level):
		out_snapshot[level] = {}
	var level_map: Dictionary = out_snapshot[level]
	var existing: int = int(level_map.get(grid_pos, 99))
	if ring < existing:
		level_map[grid_pos] = ring
