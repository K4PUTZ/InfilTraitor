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
static func apply_container_damage(voxels: Array, container_id: String, material: String,
		base_ring: int, base_level: int, is_roof: bool, ring_multipliers: Array[float]) -> void:
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
		var destroy_n: int = int(round(mult * MaterialResistanceTable.destroy_factor(material) * group.size()))
		var crack_n: int = int(round(mult * MaterialResistanceTable.crack_factor(material) * group.size()))

		var destroy_set: Array = _select_deterministic(group, container_id, "DESTROY", destroy_n)
		var destroyed_lookup: Dictionary = {}
		for v in destroy_set:
			destroyed_lookup[v] = true
		var remaining: Array = group.filter(func(v): return not destroyed_lookup.has(v))
		var crack_set: Array = _select_deterministic(remaining, container_id, "CRACK", crack_n)

		for voxel in destroy_set:
			voxel.set_damage(Voxel.DamageState.DESTROYED)
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


## Deterministic "which N of M" — hash-and-rank, mirroring
## EarthVariantSelector's use of FacadeSampler._fnv1a_hash (D4/B4): same
## inputs always produce the same subset, no RNG, nothing stored.
static func _select_deterministic(voxels: Array, container_id: String, salt: String, n: int) -> Array:
	if n <= 0 or voxels.is_empty():
		return []
	var ranked: Array = voxels.duplicate()
	ranked.sort_custom(func(a, b) -> bool:
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
