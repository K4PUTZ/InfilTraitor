## TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click
## "Detonar" on a test prop.
##
## ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a single
## baked sprite — a "digital twin" (the CC0 "Free Voxel Weapon Pack" Grenade
## matrix, OpenGameArt, license CC0) rendered once via a real Camera3D/BoxMesh
## SubViewport bake (godot/scripts/tools/bake_voxel_sprite_3d.gd — v2;
## superseded a hand-rolled 2D painter's-algorithm rasterizer, v1, whose
## flat shading and approximate depth-sort read as "esquisito") into
## ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8.png — displayed
## via Sprite2D, NOT live TileMapLayer voxel cells. Proves the mechanism
## ACTOR_MASTER_PLAN D1/D2 describes for one object before Parts 0-2 of that
## plan get built for real.
##
## Registry stays a plain Array[Dictionary] on purpose — scaffolding for the
## PLAYGROUND rebuild, not a permanent prop-interaction architecture.
## Delegates to room for shared state, same extraction pattern as
## SelectionController.
class_name TestZoneController

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

var room: Node
var _grenades: Array[Dictionary] = []
var _active_index: int = -1

const HIT_RADIUS_PX: float = 40.0
const MENU_GAP_ABOVE_PX: float = 30.0
const GRENADE_SPRITE_PATH: String = "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8.png"
## Ground-contact anchor inside the baked PNG — bake_voxel_sprite_3d.gd's own
## printed anchor_px (adjusted for the autocrop + downscale post-process),
## the pixel that should land on the target world point.
const GRENADE_ANCHOR_PX: Vector2 = Vector2(19.19, 59.06)

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
	var texture: Texture2D = load(GRENADE_SPRITE_PATH)
	if texture == null:
		push_error("TestZoneController: missing grenade bake at %s" % GRENADE_SPRITE_PATH)
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -GRENADE_ANCHOR_PX
	sprite.position = room.agent._cell_to_world(gu_cell)
	sprite.z_index = room._voxel_renderer.get_max_voxel_z_index() + 1
	room.add_child(sprite)
	_grenades.append({
		"gu_cell": gu_cell,
		"base_cell": room._cell_to_base(gu_cell, room._active_perspective),
		"sprite": sprite,
		"detonated": false,
	})


## PERSPECTIVE-01: called from room.gd::_set_perspective() alongside the
## existing agent/selection-cursor reposition block. Every live (undetonated)
## grenade's gu_cell and sprite world position are re-derived from its
## base_cell for the new direction — the same cell_from_base() round-trip the
## agent already uses, generalized to any runtime-instantiated prop that
## isn't rebuilt fresh from _base_layout on rotation.
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	for g in _grenades:
		if g["detonated"]:
			continue
		var new_cell: Vector2i = PerspectiveMapperClass.cell_from_base(g["base_cell"], direction, base_size)
		g["gu_cell"] = new_cell
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.position = room.agent._cell_to_world(new_cell)


## The sprite's own drawn rect, in world/global space — centered=false with a
## custom offset, so this is exactly (global_position + offset, texture_size),
## no reconstruction of the anchor math needed here.
func _sprite_global_rect(grenade: Dictionary) -> Rect2:
	var sprite: Sprite2D = grenade["sprite"]
	return Rect2(sprite.global_position + sprite.offset, sprite.texture.get_size())


## Screen-space center of the sprite — hit-test target.
func _center_screen_pos(grenade: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(grenade)
	return room.get_viewport().get_canvas_transform() * (rect.position + rect.size / 2.0)


## Screen-space top-center of the sprite — context menu anchor.
func _top_screen_pos(grenade: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(grenade)
	var world_top := rect.position + Vector2(rect.size.x / 2.0, 0.0)
	return room.get_viewport().get_canvas_transform() * world_top


## Index of the grenade whose sprite center is within HIT_RADIUS_PX of
## screen_pos, or -1. Approximate circular hit-test — good enough for one
## small prop, not a pixel-exact silhouette test.
func hit_test(screen_pos: Vector2) -> int:
	for i in range(_grenades.size()):
		var g: Dictionary = _grenades[i]
		if g["detonated"]:
			continue
		if _center_screen_pos(g).distance_to(screen_pos) <= HIT_RADIUS_PX:
			return i
	return -1


func open_menu_for(index: int) -> void:
	if index < 0 or index >= _grenades.size():
		return
	_active_index = index
	var g: Dictionary = _grenades[index]
	room._context_menu.open_at(_top_screen_pos(g), MENU_GAP_ABOVE_PX)

	## DESTRUCTION_MASTER_PLAN Part 3: preview the max-range GU footprint as
	## a red wireframe while the menu is open (Director, this session).
	if room._blast_wireframe_overlay != null:
		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null:
			var gu_rings := BlastCalculatorClass.flood_gu_rings(g["gu_cell"], bomb_def, _blocked_edges_dict())
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
	var g: Dictionary = _grenades[_active_index]
	if not g["detonated"]:
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false
		g["detonated"] = true

		if room.has_method("_flash_white"):
			room._flash_white()

		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null and room._edge_registry != null and room._slab_registry != null:
			var gu_rings := BlastCalculatorClass.flood_gu_rings(g["gu_cell"], bomb_def, _blocked_edges_dict())
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
			## VL-D1: index every affected voxel by cell so the soot BFS can walk
			## the blast's neighbourhood, and collect the holes as its seeds.
			var cell_to_voxel: Dictionary = {}
			var destroyed_cells: Array = []
			## VL-D4: wood voxels only, tracked separately — Voxel itself carries
			## no material (that lives on the Slice/Slab), and soot_ring isn't
			## populated until compute_soot_rings() runs below, so this is the
			## seed list the ember pass reads from AFTER that call.
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
				var c := 0
				for v in slice.voxels:
					_index_voxel_for_soot(cell_to_voxel, destroyed_cells, v)
					if v.damage_state == Voxel.DamageState.DESTROYED: d += 1
					elif v.damage_state == Voxel.DamageState.CRACKED: c += 1
				if slice.material == "wood":
					wood_voxels.append_array(slice.voxels)
				print_debug("[BLAST]   slice=%s material=%s ring=%d destroyed=%d cracked=%d/%d" %
					[slice.id, slice.material, affected["slices"][slice_id], d, c, slice.voxels.size()])
			for slab_id in affected["roofs"]:
				var slab: Slab = room._slab_registry.get_slab(slab_id)
				BlastCalculatorClass.apply_container_damage(
					slab.voxels, slab.id, slab.material, affected["roofs"][slab_id],
					slab.level, true, bomb_def.ring_multipliers, epicenter)
				for v in slab.voxels:
					_index_voxel_for_soot(cell_to_voxel, destroyed_cells, v)
			## VL-02c/D2: the ground takes the blast — as a CONTIGUOUS crater, not a
			## ring-scattered stipple. Radii derive from the bomb's range (its ring
			## count): a solid core, a crumbling rim, nothing beyond.
			## Director 2026-07-24: crater was too wide — narrowed from 0.55 to 0.40.
			var crater_max: float = float(n_rings) * float(GeometryCoords.VOXELS_PER_UNIT_AXIS) * 0.40
			var crater_core: float = crater_max * 0.4
			for slab_id in affected.get("floors", {}):
				var floor_slab: Slab = room._slab_registry.get_slab(slab_id)
				BlastCalculatorClass.apply_crater_damage(
					floor_slab.voxels, floor_slab.id, epicenter, crater_core, crater_max)
				var fd := 0
				for v in floor_slab.voxels:
					_index_voxel_for_soot(cell_to_voxel, destroyed_cells, v)
					if v.damage_state == Voxel.DamageState.DESTROYED: fd += 1
				print_debug("[BLAST]   floor=%s crater core=%.1f max=%.1f destroyed=%d/%d" %
					[floor_slab.id, crater_core, crater_max, fd, floor_slab.voxels.size()])
				## D18 lazy reveal, finally triggered: the floor's destructible plane
				## is ONE level, and nothing had ever built the fixed level beneath
				## it ("Part 3, not built yet" in render_fixed_earth_level's own
				## docstring). Without this the crater has no bottom — the voxels
				## vanish and the legacy floor plane shows through, so a real hole
				## read as untouched ground. One level, on demand, per D18 — never
				## a range.
				if fd > 0:
					var revealed_level: int = floor_slab.level - 1
					room._voxel_renderer.render_fixed_earth_level(
						floor_slab.gu_cell, revealed_level)
					## VL-D2 (Director 2026-07-24): scorch the crater FLOOR too. The
					## revealed level has no Voxel objects (render_fixed_earth_level
					## places cells directly, D13), so its soot can't ride on a Voxel
					## like the walls' does — it goes in room._crater_floor_soot, a
					## plain cell→ring map the snapshot merges. Ring 0 (darkest): the
					## bottom of a blast crater is the most burned surface there is.
					for v in floor_slab.voxels:
						if v.damage_state == Voxel.DamageState.DESTROYED:
							room.add_crater_floor_soot(revealed_level, v.grid_pos, 0)

			## VL-D1: scorch the surviving voxels ringing every hole (up to 3
			## rings, darkest at the hole). Must run AFTER all damage is applied so
			## the seed set is complete, and BEFORE the repaint so the field picks
			## the soot up in the same re-derive the detonation already triggers.
			BlastCalculatorClass.compute_soot_rings(cell_to_voxel, destroyed_cells, 3)

			## VL-D4 — wood: "ficar em brasa no momento da explosão, e depois de
			## alguns segundos escurecer". Ring 0 is the wood ringing a fresh hole
			## (already burned per VL-D1's soot); the glow overlay draws on TOP of
			## that for a few seconds, then fades — revealing the tile's already-
			## charred state underneath. Purely visual (EmberOverlay's own doc);
			## no gameplay state, so no persistence/rotation concern.
			if room._ember_overlay != null:
				for v in wood_voxels:
					if v.visible and v.soot_ring == 0:
						var world_pos: Vector2 = room._voxel_renderer.voxel_world_position(v.grid_pos, v.level)
						room._ember_overlay.add_ember(world_pos)

			## VL-PERSIST: record this blast's damage + soot into the base-coord
			## registry so it survives perspective rotation (which rebuilds every
			## Voxel from the MapSpec). Every affected voxel is already indexed in
			## cell_to_voxel; record after soot so both states are final.
			for key in cell_to_voxel:
				var av: Voxel = cell_to_voxel[key]
				room.record_voxel_damage_to_base(av.grid_pos, av.level, av.damage_state, av.soot_ring)

			room._voxel_renderer.process_dirty(room._edge_registry)
			room._voxel_renderer.process_dirty_slabs(room._slab_registry)
			## VL-02b/c: geometry just changed — re-derive the light field so the
			## new cavity walls pick up their surface/AO shading and the crater
			## reads as depth instead of a flat recolour of intact voxels.
			if room.has_method("_repaint_voxel_light_buckets"):
				room._repaint_voxel_light_buckets()

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


## VL-D1: register one voxel for the soot BFS — index it by its (x, y, level)
## cell and, if it's a hole, record it as a BFS seed.
func _index_voxel_for_soot(cell_to_voxel: Dictionary, destroyed_cells: Array, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v
	if v.damage_state == Voxel.DamageState.DESTROYED:
		destroyed_cells.append(key)


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
