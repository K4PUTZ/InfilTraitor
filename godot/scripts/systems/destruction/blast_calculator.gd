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


## GU cell -> ring index (0 = source GU). Wall-aware BFS, capped at
## bomb_def.ring_multipliers.size()-1 rings. blocked_edges must already be
## keyed via WallEdgeData.edge_key() (same shape room._current_blocked_edges
## produces once folded through that helper).
static func flood_gu_rings(source_gu: Vector2i, bomb_def, blocked_edges: Dictionary) -> Dictionary:
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
				if WallEdgeData.is_edge_blocked(current, neighbor, blocked_edges):
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
		max_steps: int, blocked_edges: Dictionary) -> Dictionary:
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
				if WallEdgeData.is_edge_blocked(current, neighbor, blocked_edges):
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
static func select_cone_pellet_impacts(source_gu: Vector2i, facing_delta: Vector2i,
		half_angle_deg: float, max_steps: int, projectile_count: int,
		blocked_edges: Dictionary, blocked_cells: Dictionary, salt: String) -> Array:
	var picks: Array = []
	if facing_delta == Vector2i.ZERO or projectile_count <= 0:
		return picks
	## Perpendicular to facing_delta (a 90 deg rotation) — the axis a pellet
	## drifts along as it strays from dead-centre.
	var lateral := Vector2i(-facing_delta.y, facing_delta.x)
	for i in range(projectile_count):
		var key: String = "%s:PELLET_ANGLE:%d" % [salt, i]
		var unit: float = float(FacadeSampler._fnv1a_hash(key) % 10000) / 10000.0  ## [0,1)
		var angle_deg: float = lerpf(-half_angle_deg, half_angle_deg, unit)
		var hit := _walk_pellet_ray(source_gu, facing_delta, lateral, deg_to_rad(angle_deg),
			max_steps, blocked_edges, blocked_cells)
		if not hit.is_empty():
			picks.append(hit)
	return picks


## One pellet's own path: mostly `forward`, drifting one `lateral` step
## whenever the accumulated tan(angle_rad) crosses a whole step (Bresenham's
## algorithm applied to a facing axis instead of a literal line). Stops and
## returns {"gu","face"} at the FIRST blocked edge OR occupied cell this
## specific path meets; {} if it exhausts max_steps without meeting one
## (void, D15).
static func _walk_pellet_ray(source_gu: Vector2i, forward: Vector2i, lateral: Vector2i,
		angle_rad: float, max_steps: int, blocked_edges: Dictionary, blocked_cells: Dictionary) -> Dictionary:
	var current := source_gu
	var lateral_accum := 0.0
	var tan_angle := tan(angle_rad)
	for _step in range(max_steps):
		lateral_accum += tan_angle
		if absf(lateral_accum) >= 1.0:
			var step_sign: int = 1 if lateral_accum > 0.0 else -1
			var lateral_step: Vector2i = lateral * step_sign
			var lateral_target: Vector2i = current + lateral_step
			if WallEdgeData.is_edge_blocked(current, lateral_target, blocked_edges) or blocked_cells.has(lateral_target):
				return {"gu": current, "face": Face.from_delta(lateral_step)}
			current = lateral_target
			lateral_accum -= step_sign
		var forward_target: Vector2i = current + forward
		if WallEdgeData.is_edge_blocked(current, forward_target, blocked_edges) or blocked_cells.has(forward_target):
			return {"gu": current, "face": Face.from_delta(forward)}
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
		+ GeometryCoords.LEVELS_PER_STOREY / 2
	var level_offset: int = clampi(chest_level - target_slice.start_storey * GeometryCoords.LEVELS_PER_STOREY,
		0, target_slice.storey_count * GeometryCoords.LEVELS_PER_STOREY - 1)
	var jitter_key: String = "%s:PELLET_JITTER:%s" % [salt, target_slice.id]
	var position_index: int = FacadeSampler._fnv1a_hash(jitter_key) % GeometryCoords.VOXELS_PER_UNIT_AXIS
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
static func apply_point_impact(slice: Slice, voxel_index: int, material: String,
		destroy_multiplier: float, edge_registry: EdgeRegistry, salt: String) -> Array:
	var touched: Array = []
	var current_slice := slice
	var d: float = MaterialResistanceTable.destroy_factor(material) * destroy_multiplier
	var n: float = MaterialResistanceTable.dent_factor(material)
	var c: float = MaterialResistanceTable.crack_factor(material)
	for depth in range(2):  ## a wall is exactly 2 voxels thick (D16): outer + inner
		if current_slice == null or voxel_index < 0 or voxel_index >= current_slice.voxels.size():
			break
		var voxel: Voxel = current_slice.voxels[voxel_index]
		touched.append(voxel)
		var key: String = "%s:IMPACT:%d" % [salt, depth]
		var roll: float = float(FacadeSampler._fnv1a_hash(key) % 10000) / 10000.0
		if roll < d:
			voxel.set_damage(Voxel.DamageState.DESTROYED)
			current_slice = edge_registry.sibling_slice(current_slice.id)
			continue
		elif roll < d + n:
			voxel.set_damage(Voxel.DamageState.DENTED)
		elif roll < d + n + c:
			voxel.set_damage(Voxel.DamageState.CRACKED)
		## else: roll missed every tier — INTACT, no mark. Matches "somente no
		## ponto de impacto [...] QUANDO o voxel inteiro não é destruído": a
		## clean miss on the tier roll just means nothing visible happened.
		break
	return touched


## Every wall Slice and roof Slab touching a flooded GU, each tagged with the
## ring of the GU it was reached through (the minimum ring, if reachable from
## more than one side). Returns {"slices": Dictionary[String,int] (slice.id
## -> ring), "roofs": Dictionary[String,int] (slab.id -> ring)}.
static func find_affected_containers(gu_rings: Dictionary, edge_registry: EdgeRegistry,
		slab_registry: SlabRegistry) -> Dictionary:
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
	## in separate buckets because they take different vertical ring steps in
	## apply_container_damage(): a roof advances one ring per raw level, while a
	## floor's destructible plane is a single level (D13) that must stay at the
	## source ring or its one layer would fall outside the multiplier table.
	var hit_roofs: Dictionary = {}
	var hit_floors: Dictionary = {}
	for slab in slab_registry.all_slabs():
		if not gu_rings.has(slab.gu_cell):
			continue
		if slab.role == Slab.Role.CEILING:
			hit_roofs[slab.id] = gu_rings[slab.gu_cell]
		else:
			hit_floors[slab.id] = gu_rings[slab.gu_cell]

	return {"slices": hit_slices, "roofs": hit_roofs, "floors": hit_floors}


## Applies ring falloff + material resistance to one container's (Slice or
## Slab) voxels and writes real damage via Voxel.set_damage() — the only
## writer of destruction state, per DESTRUCTION_MASTER_PLAN §3.
##
## is_roof selects the vertical ring step: walls advance one ring per
## LEVELS_PER_STOREY (a whole storey), roofs advance one ring per raw level
## (ROOF_LEVEL_COUNT is only ~2 levels total, so a whole-storey step would
## collapse every roof level into ring 0 and roofs would never show falloff
## at all). Deliberate asymmetry, not an oversight — flagged for review if a
## real capture shows it reading wrong.
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
static func apply_container_damage(voxels: Array, container_id: String, material: String,
		base_ring: int, base_level: int, is_roof: bool, ring_multipliers: Array[float],
		bias_epicenter: Vector2i = NO_EPICENTER_BIAS,
		destroy_multiplier: float = 1.0) -> void:
	var by_ring: Dictionary = {}  # ring -> Array[Voxel]
	for voxel in voxels:
		var level_offset: int = voxel.level - base_level
		var vertical_ring: int
		if is_roof:
			vertical_ring = level_offset
		else:
			vertical_ring = int(floor(float(level_offset) / float(GeometryCoords.LEVELS_PER_STOREY)))
		var ring: int = base_ring + maxi(0, vertical_ring)
		if ring >= ring_multipliers.size():
			continue
		if not by_ring.has(ring):
			by_ring[ring] = []
		by_ring[ring].append(voxel)

	for ring in by_ring:
		var group: Array = by_ring[ring]
		var mult: float = ring_multipliers[ring]
		var destroy_n: int = int(round(mult * MaterialResistanceTable.destroy_factor(material)
			* destroy_multiplier * group.size()))
		var dent_n: int = int(round(mult * MaterialResistanceTable.dent_factor(material) * group.size()))
		var crack_n: int = int(round(mult * MaterialResistanceTable.crack_factor(material) * group.size()))

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

		for voxel in destroy_set:
			voxel.set_damage(Voxel.DamageState.DESTROYED)
		## D23: this is the ring-group scatter model, used only by RADIAL — a
		## blast's DENTED/CRACKED voxels get the irregular chip/crack texture
		## family, never the bullet's round puncture.
		## D25: DENTED additionally carries WHICH SIDE the blast ate, so the
		## renderer can pick the matching carved half-voxel.
		for voxel in dent_set:
			voxel.set_damage(Voxel.DamageState.DENTED, true,
				carved_side_for(voxel.grid_pos, is_roof, bias_epicenter))
		for voxel in crack_set:
			voxel.set_damage(Voxel.DamageState.CRACKED, true)


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
static func apply_crater_damage(voxels: Array, container_id: String,
		epicenter: Vector2i, core_radius: float, max_radius: float) -> void:
	var rim_span: float = maxf(max_radius - core_radius, 0.001)
	for voxel in voxels:
		var d: float = Vector2(voxel.grid_pos - epicenter).length()
		if d <= core_radius:
			voxel.set_damage(Voxel.DamageState.DESTROYED)
		elif d <= max_radius:
			## Probability of removal falls 1→0 across the rim; a deterministic
			## per-voxel hash in [0,1) is compared against it, so the same voxels
			## always go and the boundary is ragged rather than a perfect circle.
			var keep_prob: float = 1.0 - (d - core_radius) / rim_span
			var key: String = "%s:CRATER:%d,%d,%d" % [container_id, voxel.grid_pos.x, voxel.grid_pos.y, voxel.level]
			var h: float = float(FacadeSampler._fnv1a_hash(key) % 10000) / 10000.0
			if h < keep_prob:
				voxel.set_damage(Voxel.DamageState.DESTROYED)


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
static func derive_soot_rings(cell_to_voxel: Dictionary, destroyed_cells: Array,
		n_rings: int, out_snapshot: Dictionary) -> void:
	if destroyed_cells.is_empty() or n_rings <= 0:
		return
	## Frontier BFS. Seeds are the holes themselves (they have no surviving voxel
	## to tag); their SURVIVING neighbours become ring 0, and so on outward.
	var visited: Dictionary = {}
	for c in destroyed_cells:
		visited[c] = true
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
				if visited.has(ncell):
					continue
				visited[ncell] = true
				var voxel = cell_to_voxel.get(ncell)
				## Only surviving, visible voxels take soot — a destroyed cell is a
				## hole (already a seed) and an absent one is empty air.
				if voxel == null or not voxel.visible or voxel.damage_state == Voxel.DamageState.DESTROYED:
					continue
				if not out_snapshot.has(voxel.level):
					out_snapshot[voxel.level] = {}
				var existing: int = int(out_snapshot[voxel.level].get(voxel.grid_pos, -1))
				if existing < 0 or ring < existing:
					out_snapshot[voxel.level][voxel.grid_pos] = ring
				next_frontier.append(ncell)
		frontier = next_frontier
		if frontier.is_empty():
			break
