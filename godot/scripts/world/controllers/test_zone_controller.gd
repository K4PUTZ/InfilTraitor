## TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click
## "Detonar" on a test prop.
##
## ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a
## "digital twin" (Quaternius' CC0 "Grenade" model, poly.pizza) rendered via
## the real-3D-model + normal-map bake technique proven for the shotgun
## (godot/scripts/tools/grenade_frame_bake_spike.gd, 2026-07-28) — displayed
## via GrenadeProp (godot/scripts/overlays/grenade_prop.gd), NOT live
## TileMapLayer voxel cells. Superseded the original single-angle
## bake_voxel_sprite_3d.gd bake (grenade_bake_x8.png, a hand-placed BoxMesh
## voxel reconstruction of a CC0 .qb — itself already a v2 over a hand-rolled
## 2D painter's-algorithm rasterizer, v1) once that was shown to read flat
## from some angles and to ignore the room's active N/E/S/W perspective
## entirely, the same class of bug D22 found and fixed for the shotgun.
## Proves the mechanism ACTOR_MASTER_PLAN D1/D2 describes for one object
## before Parts 0-2 of that plan get built for real.
##
## Registry stays a plain Array[Dictionary] on purpose — scaffolding for the
## PLAYGROUND rebuild, not a permanent prop-interaction architecture.
## Delegates to room for shared state, same extraction pattern as
## SelectionController.
class_name TestZoneController

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const GrenadePropClass = preload("res://godot/scripts/overlays/grenade_prop.gd")

var room: Node
var _grenades: Array[Dictionary] = []
var _active_index: int = -1

const MENU_GAP_ABOVE_PX: float = 30.0

## DESTRUCTION_MASTER_PLAN Part 3: every TEST-ZONE grenade is this one bomb
## type for now — BombRegistry/BombDef exist so a future prop/inventory
## system can vary this per grenade instance instead of hardcoding it here.
const BOMB_ID: String = "frag_grenade"


func _init(p_room: Node) -> void:
	room = p_room


func clear() -> void:
	for g in _grenades:
		var sprite: Sprite2D = g.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_grenades.clear()
	_active_index = -1


## Place one placeholder grenade at gu_cell as a baked sprite (ground-contact
## anchored to the cell's center), and register it as right-click detonatable.
## PERSPECTIVE-01: gu_cell is a view-space cell for the room's CURRENT
## perspective at add-time — also stored converted to a base (pre-rotation)
## cell, so reposition_for_perspective() can follow rotation the same way
## room.gd already does for the agent and the selection cursor.
func add_grenade(gu_cell: Vector2i) -> void:
	var base_cell: Vector2i = room._cell_to_base(gu_cell, room._active_perspective)
	var sprite := GrenadePropClass.new()
	sprite.setup(room, gu_cell, base_cell)
	sprite.position = room.agent._cell_to_world(gu_cell)
	room.add_child(sprite)
	_grenades.append({
		"gu_cell": gu_cell,
		"base_cell": base_cell,
		"sprite": sprite,
		"detonated": false,
	})


## PERSPECTIVE-01: called from room.gd::_set_perspective() alongside the
## existing agent/selection-cursor reposition block. Every live (undetonated)
## grenade's gu_cell and sprite world position are re-derived from its
## base_cell for the new direction — the same cell_from_base() round-trip the
## agent already uses, generalized to any runtime-instantiated prop that
## isn't rebuilt fresh from _base_layout on rotation. GrenadeProp.update_cell()
## also swaps to the frame baked for the new compass direction (D22 fix).
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	for g in _grenades:
		if g["detonated"]:
			continue
		var new_cell: Vector2i = PerspectiveMapperClass.cell_from_base(g["base_cell"], direction, base_size)
		g["gu_cell"] = new_cell
		var sprite: GrenadePropClass = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.position = room.agent._cell_to_world(new_cell)
			sprite.update_cell(new_cell)


## The sprite's own drawn rect, in world/global space — centered=false with a
## custom offset, so this is exactly (global_position + offset, texture_size),
## no reconstruction of the anchor math needed here.
func _sprite_global_rect(grenade: Dictionary) -> Rect2:
	var sprite: Sprite2D = grenade["sprite"]
	return Rect2(sprite.global_position + sprite.offset, sprite.texture.get_size())


## Screen-space top-center of the sprite — context menu anchor.
func _top_screen_pos(grenade: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(grenade)
	var world_top := rect.position + Vector2(rect.size.x / 2.0, 0.0)
	return room.get_viewport().get_canvas_transform() * world_top


## Index of the grenade standing on the clicked GU cell, or -1. Director
## (2026-07-30): the clickable hitbox for an interactive object is the FLOOR
## CELL it occupies, not its sprite — a ground grenade is an ordinary floor
## prop, not one of the direct-click exceptions (wall-mounted breakables,
## ceiling lamps).
func hit_test(screen_pos: Vector2) -> int:
	var cell: Vector2i = room._screen_to_tile(screen_pos)
	if cell == room.INVALID_CELL:
		return -1
	for i in range(_grenades.size()):
		var g: Dictionary = _grenades[i]
		if g["detonated"]:
			continue
		if g["gu_cell"] == cell:
			return i
	return -1


func open_menu_for(index: int) -> void:
	if index < 0 or index >= _grenades.size():
		return
	_active_index = index
	var g: Dictionary = _grenades[index]
	## WEAPON-FIRE-01: the menu is shared with the weapons bench now, so the
	## verb and its handler are passed per open instead of being wired once in
	## room.gd. Same button, same signal, different action.
	room._context_menu.open_at(_top_screen_pos(g), MENU_GAP_ABOVE_PX,
		"ui.context_menu.detonate", detonate_active)

	## DESTRUCTION_MASTER_PLAN Part 3: preview the max-range GU footprint as
	## a red wireframe while the menu is open (Director, this session).
	if room._blast_wireframe_overlay != null:
		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null:
			var gu_rings := BlastCalculatorClass.flood_gu_rings(g["gu_cell"], bomb_def,
				_blocked_edges_dict(), room._blocked_cells)
			room._blast_wireframe_overlay.show_footprint(gu_rings.keys())


## DESTRUCTION_MASTER_PLAN Part 3: the real trigger. Marks affected wall
## Slices and roof Slabs damaged via BlastCalculator (which is the only
## writer of Voxel.set_damage() here — see DESTRUCTION_MASTER_PLAN §3), then
## re-renders immediately through the existing dirty-flag pipeline
## (VoxelRenderer.process_dirty()/process_dirty_slabs()) rather than waiting
## for the next turn's TIC — a context-menu detonate is a discrete player
## action with no corresponding turn boundary, the same reasoning
## apply_occlusion() already uses to render synchronously on agent
## step/view-change instead of gating behind a tick.
func detonate_active() -> void:
	if _active_index < 0 or _active_index >= _grenades.size():
		return
	## PERF-01: a render pass from an earlier detonate/fire is still spread
	## across frames — refuse to start a second one racing on the same
	## TileMapLayers. Silent no-op, same idiom as the guards above.
	if room._destruction_render_busy:
		return
	var g: Dictionary = _grenades[_active_index]
	if not g["detonated"]:
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false
		g["detonated"] = true

		## D11: the white flash moved to the END of the cascade (it is the last
		## of the three beats); the immediate response on detonate is the red
		## one, fired below once the buffering is armed.

		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null and room._edge_registry != null and room._slab_registry != null:
			var gu_rings := BlastCalculatorClass.flood_gu_rings(g["gu_cell"], bomb_def,
				_blocked_edges_dict(), room._blocked_cells)
			var affected := BlastCalculatorClass.find_affected_containers(
				gu_rings, room._edge_registry, room._slab_registry)

			print_debug("[BLAST] gu=%s rings=%s affected_slices=%d affected_roofs=%d affected_floors=%d" %
				[g["gu_cell"], gu_rings, affected["slices"].size(), affected["roofs"].size(),
				affected.get("floors", {}).size()])
			## Epicentre in VOXEL coords (centre voxel of the source GU) — fed to
			## every container so a wall/roof/floor's near side (VL-D4 directional
			## bias) and the floor's own crater (VL-D2) agree on the same point.
			var n_rings: int = bomb_def.ring_multipliers.size()
			var epicenter: Vector2i = g["gu_cell"] * GeometryCoords.VOXELS_PER_UNIT_AXIS \
				+ Vector2i(GeometryCoords.VOXELS_PER_UNIT_AXIS / 2, GeometryCoords.VOXELS_PER_UNIT_AXIS / 2)
			## D24: index every voxel this blast touches, keyed by cell -- used
			## for VL-PERSIST below and the ember ring-0 check. Soot itself no
			## longer needs a seed list here: room._build_soot_snapshot()
			## derives it fresh, globally, at the repaint this function
			## triggers at the end.
			var cell_to_voxel: Dictionary = {}
			## VL-D4: wood voxels only, tracked separately -- Voxel itself
			## carries no material (that lives on the Slice/Slab).
			var wood_voxels: Array = []
			for slice_id in affected["slices"]:
				var slice: Slice = room._edge_registry.get_slice(slice_id)
				## VL-D4 (Director, 2026-07-26): bias the destroy/crack selection
				## toward the epicenter-facing side, so a wall's near face visibly
				## loses more material than its far face — the flat ring model
				## alone can't produce that (both faces of one edge share a ring).
				BlastCalculatorClass.apply_container_damage(
					slice.voxels, slice.id, slice.material, affected["slices"][slice_id],
					slice.start_storey * GeometryCoords.LEVELS_PER_STOREY, false, bomb_def.ring_multipliers,
					epicenter)
				var d := 0
				var n := 0
				var c := 0
				for v in slice.voxels:
					_index_voxel(cell_to_voxel, v)
					if v.damage_state == Voxel.DamageState.DESTROYED: d += 1
					elif v.damage_state == Voxel.DamageState.DENTED: n += 1
					elif v.damage_state == Voxel.DamageState.CRACKED: c += 1
				if slice.material == "wood":
					wood_voxels.append_array(slice.voxels)
				print_debug("[BLAST]   slice=%s material=%s ring=%d destroyed=%d dented=%d cracked=%d/%d" %
					[slice.id, slice.material, affected["slices"][slice_id], d, n, c, slice.voxels.size()])
			for slab_id in affected["roofs"]:
				var slab: Slab = room._slab_registry.get_slab(slab_id)
				BlastCalculatorClass.apply_container_damage(
					slab.voxels, slab.id, slab.material, affected["roofs"][slab_id],
					slab.level, true, bomb_def.ring_multipliers, epicenter)
				for v in slab.voxels:
					_index_voxel(cell_to_voxel, v)
			## VL-02c/D2: the ground takes the blast — as a CONTIGUOUS crater, not a
			## ring-scattered stipple. Radii derive from the bomb's range (its ring
			## count): a solid core, a crumbling rim, nothing beyond.
			## Director 2026-07-24: crater was too wide — narrowed from 0.55 to 0.40.
			var crater_max: float = float(n_rings) * float(GeometryCoords.VOXELS_PER_UNIT_AXIS) * 0.40
			var crater_core: float = crater_max * 0.4
			## PERF-02 B4 (Director, 2026-08-04): one explosion cracks one floor
			## depth layer. Which deep-plane voxels are eligible is decided from
			## holes that existed BEFORE this blast, captured here rather than
			## read inside the loop below: iteration order over
			## affected["floors"] is undefined (the loop's own comment says so),
			## so reading the shallow plane's visibility mid-loop could see the
			## crater this very blast just punched and let the deep plane through
			## on the same explosion — the exact thing this limits.
			var shallow_holes: Dictionary = {}
			for pre_slab_id in affected.get("floors", {}):
				var pre_slab: Slab = room._slab_registry.get_slab(pre_slab_id)
				if pre_slab == null or pre_slab.level > GeometryCoords.FLOOR_DEEP_LEVEL:
					continue
				var shallow_sibling: Slab = room._slab_registry.get_slab(
						Slab.make_id(pre_slab.gu_cell, Slab.Role.FLOOR,
							GeometryCoords.FLOOR_TOP_LEVEL))
				if shallow_sibling == null:
					continue
				for sv in shallow_sibling.voxels:
					if not sv.visible:
						shallow_holes[sv.grid_pos] = true

			for slab_id in affected.get("floors", {}):
				var floor_slab: Slab = room._slab_registry.get_slab(slab_id)
				var floor_ring: int = affected["floors"][slab_id]
				var is_deep: bool = floor_slab.level <= GeometryCoords.FLOOR_DEEP_LEVEL
				var core: float = crater_core
				var max_radius: float = crater_max
				## PERF-02 B4: the deep plane only takes damage where the plane
				## above it is ALREADY open — a later explosion over the same
				## spot reaches it, this one cannot. Defaults to the whole slab,
				## which is what every non-deep floor keeps using.
				var crater_voxels: Array = floor_slab.voxels
				if is_deep:
					## FLOOR-DEPTH-01: the deep plane survives outside the blast's
					## own GU entirely (ring 0 IS the source GU), and inside it takes
					## a tighter crater — see BlastCalculator.DEEP_FLOOR_CRATER_FACTOR.
					if floor_ring > 0:
						continue
					core *= BlastCalculatorClass.DEEP_FLOOR_CRATER_FACTOR
					max_radius *= BlastCalculatorClass.DEEP_FLOOR_CRATER_FACTOR
					crater_voxels = []
					for dv in floor_slab.voxels:
						if shallow_holes.has(dv.grid_pos):
							crater_voxels.append(dv)
					## Nothing above it is open yet: skip this slab entirely —
					## no reveal, no damage. It stays hidden until a blast that
					## actually has a hole to fall through.
					if crater_voxels.is_empty():
						print_debug("[BLAST]   floor=%s level=%d ring=%d SKIPPED (B4: no hole in the plane above yet)" %
							[floor_slab.id, floor_slab.level, floor_ring])
						continue
					## It is rendered on exposure, so it has to be on screen before it
					## can show a hole in itself. Idempotent if the plane above
					## already revealed it earlier in this same loop (dictionary
					## iteration order across the two planes is not defined).
					room._voxel_renderer.reveal_floor_slab(floor_slab)
				## FLOOR-DENT-01: material drives the dent roll (earth 0.3;
				## zoned ground_* floors have no table row and stay dent-free).
				BlastCalculatorClass.apply_crater_damage(
					crater_voxels, floor_slab.id, epicenter, core, max_radius,
					floor_slab.material)
				var fd := 0
				var fdent := 0
				for v in floor_slab.voxels:
					_index_voxel(cell_to_voxel, v)
					if v.damage_state == Voxel.DamageState.DESTROYED: fd += 1
					elif v.damage_state == Voxel.DamageState.DENTED: fdent += 1
				print_debug("[BLAST]   floor=%s level=%d ring=%d crater core=%.1f max=%.1f destroyed=%d dented=%d/%d" %
					[floor_slab.id, floor_slab.level, floor_ring, core, max_radius, fd, fdent,
					floor_slab.voxels.size()])
				## D18 lazy reveal, finally triggered: without this the crater has no
				## bottom — the voxels vanish and the legacy floor plane shows
				## through, so a real hole reads as untouched ground.
				if fd > 0:
					_expose_below(floor_slab, cell_to_voxel)

			## D24: soot is no longer computed here. room._build_soot_snapshot()
			## re-derives it globally (BlastCalculator.derive_soot_rings()) from
			## whichever voxels are absent at the repaint this function triggers
			## below -- nothing to seed or store at detonation time any more.

			## VL-D4 — wood: "ficar em brasa no momento da explosão, e depois de
			## alguns segundos escurecer". Ring 0 is the wood ringing a fresh hole
			## (already burned per VL-D1's soot); the glow overlay draws on TOP of
			## that for a few seconds, then fades — revealing the tile's already-
			## charred state underneath. Purely visual (EmberOverlay's own doc);
			## no gameplay state, so no persistence/rotation concern.
			if room._ember_overlay != null:
				for v in wood_voxels:
					if v.visible and _is_freshly_scorched(v, cell_to_voxel):
						var world_pos: Vector2 = room._voxel_renderer.voxel_world_position(v.grid_pos, v.level)
						room._ember_overlay.add_ember(world_pos)

			## VL-PERSIST: record this blast's damage into the base-coord registry
			## so it survives perspective rotation (which rebuilds every Voxel from
			## the MapSpec). Soot needs no entry here any more (D24) -- it re-derives
			## from _base_damage's absences on every repaint.
			for key in cell_to_voxel:
				var av: Voxel = cell_to_voxel[key]
				room.record_voxel_damage_to_base(av.grid_pos, av.level, av.damage_state,
					av.damage_is_blast, av.damage_carved_side, av.damage_variant)

			## PERF-01: the batch below used to run in one synchronous call and
			## measured ~3.6s on a big blast — spread across frames instead
			## (process_dirty_async()/process_dirty_slabs_async()) so the game
			## keeps rendering/responding while it catches up, rather than
			## freezing for the whole duration.
			room._destruction_render_busy = true
			## D11 (Director, 2026-08-04): the destruction lands in three
			## logical stages instead of one undifferentiated sweep — holes
			## first, then the sunken dents, then the surface marks — with a
			## screen beat between each. *"Assim da tempo de 'pensar com
			## calma'... vai deixar a explosão mais orgânica."* It also groups
			## like-for-like work: the DESTROYED pass is nearly free (erases),
			## so the hole appears immediately, and the expensive decal
			## composites fill in behind it.
			##
			## Smoke is buffered across all three stages and released as one
			## moment afterwards; the soot/light repaint is deferred again so
			## it lands while that smoke is still rising.
			room.begin_destruction_vfx_capture()
			await room._flash_frame(Color(1.0, 0.15, 0.05))
			await _render_damage_stage([Voxel.DamageState.DESTROYED])
			await room._flash_frame(Color(1.0, 0.85, 0.10))
			await _render_damage_stage([Voxel.DamageState.DENTED])
			room._flash_white()
			## Empty filter = "everything still dirty", which is CRACKED plus
			## any voxel the two named stages did not claim — so the sweep
			## cannot strand a dirty voxel for a later TIC to render out of
			## sequence.
			await _render_damage_stage([])
			## D11 equivalence probe — env-gated
			## (INFILTRAITOR_CASCADE_EQUIV_PROBE=1), same standing-dev-tool
			## precedent as INFILTRAITOR_LIGHT_EQUIV_PROBE (PERF-03) and
			## INFILTRAITOR_FACE_SOOT_DIAG. Snapshots (source_id, atlas_coords)
			## for every voxel this blast touched, force-dirties them again,
			## and re-renders through ONE unfiltered pass — the pre-D11 code
			## path — then diffs. Proves the three-stage sweep placed the same
			## tiles a single sweep would, independent of VFX-timing pixel
			## noise (a real capture diff after staging showed 518 differing
			## pixels against a pre-D11 capture; this probe is what proved
			## that was debris/dust particle timing, not a placement bug — 0
			## mismatch across all four PLAYGROUND test-wall materials).
			## Kept rather than deleted because it guards a real regression
			## class: a future change to the stage filters (e.g. reordering
			## which DamageState each stage claims) could silently leave a
			## voxel double-rendered or unrendered, with no visible symptom
			## until someone looks at the exact right voxel.
			if OS.get_environment("INFILTRAITOR_CASCADE_EQUIV_PROBE") == "1":
				var _before: Dictionary = {}
				for key in cell_to_voxel:
					var pv: Voxel = cell_to_voxel[key]
					var players: TileMapLayer = room._voxel_renderer.get_layer(pv.level)
					if players != null and players.get_cell_source_id(pv.grid_pos) != -1:
						_before[key] = [players.get_cell_source_id(pv.grid_pos),
							players.get_cell_atlas_coords(pv.grid_pos)]
					else:
						_before[key] = null
					pv._set_dirty()
				await room._voxel_renderer.process_dirty_async(room._edge_registry)
				await room._voxel_renderer.process_dirty_slabs_async(room._slab_registry)
				var _mismatch := 0
				for key in cell_to_voxel:
					var pv2: Voxel = cell_to_voxel[key]
					var players2: TileMapLayer = room._voxel_renderer.get_layer(pv2.level)
					var after = null
					if players2 != null and players2.get_cell_source_id(pv2.grid_pos) != -1:
						after = [players2.get_cell_source_id(pv2.grid_pos),
							players2.get_cell_atlas_coords(pv2.grid_pos)]
					if _before[key] != after:
						_mismatch += 1
				print("[CASCADE-EQUIV] %d voxels checked, %d mismatch" % [cell_to_voxel.size(), _mismatch])
			## D11: "Em seguida soltamos a fumaça. E enquanto ela ainda está
			## subindo, aplicamos a fuligem." — release every buffered puff/
			## spark/dust/chip as one moment now that all three stages are on
			## screen, THEN run the soot/light repaint immediately after (not
			## awaited past a delay) so it lands while that smoke is still
			## rising rather than before it exists.
			room.flush_destruction_vfx()
			## VL-02b/c: geometry just changed — re-derive the light field so the
			## new cavity walls pick up their surface/AO shading and the crater
			## reads as depth instead of a flat recolour of intact voxels.
			## PERF-03: geometry and soot are the only inputs this changed —
			## no light moved, and the shadow projector is not re-run here — so
			## the light field can keep its caches instead of rebuilding every
			## voxel's bucket from scratch. See VoxelLightField.build().
			if room.has_method("_repaint_voxel_light_buckets"):
				room._repaint_voxel_light_buckets(true)
			room._destruction_render_busy = false

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


## D11 — runs both dirty-flag pipelines (walls, then floors/roofs) filtered to
## `states`. Shared by every cascade stage in detonate_active() so the
## wall/slab ordering and the async-yield behaviour have exactly one owner.
## `states.is_empty()` means "everything still dirty" — VoxelRenderer's own
## contract for process_dirty_async()/process_dirty_slabs_async().
func _render_damage_stage(states: Array) -> void:
	await room._voxel_renderer.process_dirty_async(room._edge_registry, states)
	await room._voxel_renderer.process_dirty_slabs_async(room._slab_registry, states)


## FLOOR-DEPTH-01 — reveal whatever lies under a floor plane that just took holes.
##
## Two cases, and the difference is whether the level below is a real Slab:
##  - FLOOR_DEEP_LEVEL is one (generated at build, rendered only here): it draws
##    itself, and its exposed surface takes soot the ordinary way, on its own
##    Voxels — D24: room._build_soot_snapshot() derives it globally on repaint,
##    so every one of its voxels just needs to be indexed here, not just the
##    destroyed ones. That soot then persists through rotation for free, since
##    it's re-derived from _base_damage's absences rather than stored.
##  - Below that, D13's fixed ground places cells directly with no Voxel to hang
##    soot on, so it keeps the plain cell→ring side map (VL-D2), written at
##    EXPOSED_FLOOR_SOOT_RING — the same ring the BFS gives the Voxel-backed case,
##    so the two paths cannot drift apart.
func _expose_below(slab: Slab, cell_to_voxel: Dictionary) -> void:
	var below_level: int = slab.level - 1
	var below_slab: Slab = room._slab_registry.get_slab(
			Slab.make_id(slab.gu_cell, Slab.Role.FLOOR, below_level))
	if below_slab != null:
		room._voxel_renderer.reveal_floor_slab(below_slab)
		for v in below_slab.voxels:
			_index_voxel(cell_to_voxel, v)
		return

	room._voxel_renderer.render_fixed_earth_level(slab.gu_cell, below_level)
	for v in slab.voxels:
		if v.damage_state == Voxel.DamageState.DESTROYED:
			room.add_crater_floor_soot(below_level, v.grid_pos,
					BlastCalculatorClass.EXPOSED_FLOOR_SOOT_RING)


## D24: register one voxel by its (x, y, level) cell for VL-PERSIST and the
## ember ring-0 check below. No seed list any more — room._build_soot_snapshot()
## finds the holes itself by walking the whole map fresh on repaint.
func _index_voxel(cell_to_voxel: Dictionary, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v


## D24: true if `v` sits immediately next to a destroyed/absent voxel -- the
## "ring 0" case the old stored soot_ring used to answer directly. Checked
## right here, mid-detonation, because the ember glow needs the answer before
## room._build_soot_snapshot() runs on the repaint at the end of this function.
const _EMBER_NEIGHBOURS: Array = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
func _is_freshly_scorched(v: Voxel, cell_to_voxel: Dictionary) -> bool:
	var origin := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	for d in _EMBER_NEIGHBOURS:
		var n = cell_to_voxel.get(origin + d)
		if n != null and (not n.visible or n.damage_state == Voxel.DamageState.DESTROYED):
			return true
	return false


func cancel_active() -> void:
	_active_index = -1
	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()


## room._current_blocked_edges entries are {"from": Vector2i, "to": Vector2i}
## pairs (see map_geometry.gd's _wall_cell_blocked_edges()) — folds them into
## the keyed Dictionary shape WallEdgeData.is_edge_blocked() queries, same
## conversion MovementOverlay.set_blocked_edges() already does.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked
