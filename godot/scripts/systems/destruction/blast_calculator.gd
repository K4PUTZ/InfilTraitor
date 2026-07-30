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
		for voxel in dent_set:
			voxel.set_damage(Voxel.DamageState.DENTED)
		for voxel in crack_set:
			voxel.set_damage(Voxel.DamageState.CRACKED)


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


## VL-D1 — Soot rings around blast holes.
##
## After damage is applied, the surviving voxels ringing each hole get scorched:
## a multi-source BFS outward from every DESTROYED cell tags neighbours with a
## ring index (0 = touching the hole, darkest; rising outward, fainter), which
## VoxelLightField reads as a per-voxel darkening. This is what makes a crater
## read as a crater — the hole plus the soot halo around it, not bare removed
## voxels. Applied on the blast event only (not per frame): the full-field
## re-derive it triggers is the same one a detonation already paid for.
##
## cell_to_voxel: Vector3i(x, y, level) → Voxel, over every voxel in the blast's
## affected containers (walls + floors + roofs) — the BFS navigates only through
## these, so soot stays local to the blast and never walks the whole map.
## n_rings: how many rings to paint (Director: up to 3). min-ring wins, so a
## voxel near two holes takes the darker scorch.
static func compute_soot_rings(cell_to_voxel: Dictionary, destroyed_cells: Array, n_rings: int) -> void:
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
				if voxel.soot_ring < 0 or ring < voxel.soot_ring:
					voxel.soot_ring = ring
				next_frontier.append(ncell)
		frontier = next_frontier
		if frontier.is_empty():
			break
