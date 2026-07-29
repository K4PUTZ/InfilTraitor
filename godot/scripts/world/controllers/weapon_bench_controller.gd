## WeaponBenchController — WEAPON-FIRE-01 (Director, 2026-07-29): right-click
## "Atirar" on a placed weapon, producing a directional cone of destruction
## against whatever material it is aimed at.
##
## Sibling of TestZoneController, not an extension of it. That class is the
## GRENADE controller — its own header calls itself "scaffolding for the
## PLAYGROUND rebuild, not a permanent prop-interaction architecture" — and a
## weapon differs from a grenade in every part that matters: it has a FACING, it
## is not consumed when used, and its damage is a wedge rather than rings. What
## the two share (screen-space hit-test, context-menu anchoring) is ~40 lines of
## geometry, which is cheaper to mirror than a premature generalisation of two
## things that are both explicitly temporary.
##
## The weapons themselves are FloatingCollectible instances in static-facing
## mode (see that class's header) — this controller owns the registry and the
## interaction, not the rendering.
class_name WeaponBenchController

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const FloatingCollectibleClass = preload("res://godot/scripts/overlays/floating_collectible.gd")

## Compass edge -> GU-space step, per docs/DIRECTION_GLOSSARY.md §3. The same
## four deltas edge_extractor.gd's _EDGE_BY_SUFFIX uses; a weapon's declared
## facing is resolved through this to get the direction its cone points.
const FACING_DELTA := {
	"NW": Vector2i(-1, 0),
	"NE": Vector2i(0, -1),
	"SE": Vector2i(1, 0),
	"SW": Vector2i(0, 1),
}

const HIT_RADIUS_PX: float = 40.0
const MENU_GAP_ABOVE_PX: float = 30.0

var room: Node
var _weapons: Array[Dictionary] = []
var _active_index: int = -1


func _init(p_room: Node) -> void:
	room = p_room


func clear() -> void:
	for w in _weapons:
		var sprite = w.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_weapons.clear()
	_active_index = -1


## Place one weapon prop at gu_cell, aimed along `facing`, and register it as
## right-click firable. Mirrors TestZoneController.add_grenade()'s perspective
## handling: gu_cell is a VIEW-space cell for the room's current perspective and
## is also stored converted to base, so reposition_for_perspective() can follow
## rotation instead of going stale.
func add_weapon(gu_cell: Vector2i, facing: String, weapon_id: String,
		frames_dir: String, sprite_scale: float, shadow_scale_factor: float) -> void:
	if not FACING_DELTA.has(facing):
		push_error("[WeaponBenchController] unknown facing '%s' — expected one of %s" %
			[facing, FACING_DELTA.keys()])
		return
	var base_cell: Vector2i = room._cell_to_base(gu_cell, room._active_perspective)
	var sprite = FloatingCollectibleClass.new()
	## COLLECTIBLE-OUTLINE-02: the stroke means "you can pick this up"; a placed
	## weapon is scenery, not loot.
	sprite.outline_color = FloatingCollectibleClass.OUTLINE_DISABLED
	sprite.setup(room, gu_cell, frames_dir, sprite_scale, shadow_scale_factor, facing)
	room.add_child(sprite)
	_weapons.append({
		"gu_cell": gu_cell,
		"base_cell": base_cell,
		"facing": facing,
		"weapon_id": weapon_id,
		"sprite": sprite,
	})


## Called from room.gd::_set_perspective(). The sprite re-derives its own cell
## and baked frame (FloatingCollectible.reposition_for_perspective); this only
## has to keep the registry's own view-space cell in step, since that is what
## the cone is fired from.
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	for w in _weapons:
		w["gu_cell"] = PerspectiveMapperClass.cell_from_base(w["base_cell"], direction, base_size)
		var sprite = w["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.reposition_for_perspective(direction)


func _sprite_global_rect(weapon: Dictionary) -> Rect2:
	var sprite = weapon["sprite"]
	return Rect2(sprite.global_position - Vector2(sprite._sprite_half_w, sprite._sprite_half_h),
		Vector2(sprite._sprite_half_w, sprite._sprite_half_h) * 2.0)


func _center_screen_pos(weapon: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(weapon)
	return room.get_viewport().get_canvas_transform() * (rect.position + rect.size / 2.0)


func _top_screen_pos(weapon: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(weapon)
	var world_top := rect.position + Vector2(rect.size.x / 2.0, 0.0)
	return room.get_viewport().get_canvas_transform() * world_top


## Index of the weapon whose sprite center is within HIT_RADIUS_PX of
## screen_pos, or -1. Approximate circular hit-test, same as the grenades'.
func hit_test(screen_pos: Vector2) -> int:
	for i in range(_weapons.size()):
		if _center_screen_pos(_weapons[i]).distance_to(screen_pos) <= HIT_RADIUS_PX:
			return i
	return -1


func open_menu_for(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	_active_index = index
	var w: Dictionary = _weapons[index]
	room._context_menu.open_at(_top_screen_pos(w), MENU_GAP_ABOVE_PX,
		"ui.context_menu.fire", fire_active)

	## Preview the cone the shot will actually cover, through the SAME overlay
	## the grenade's radial footprint uses — it outlines an arbitrary GU cell
	## set and has never been ring-specific, so a wedge needs no new overlay.
	if room._blast_wireframe_overlay != null:
		var cells := _cone_cells(w)
		if not cells.is_empty():
			room._blast_wireframe_overlay.show_footprint(cells)


func cancel_active() -> void:
	_active_index = -1
	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()


## The GU cells this weapon's shot would cover, in the room's CURRENT
## perspective. Shared by the preview and the shot itself so the wireframe can
## never promise a footprint the shot does not deliver.
func _cone_cells(weapon: Dictionary) -> Array:
	var weapon_def = Registries.get_weapon_registry().get_weapon(weapon["weapon_id"])
	if weapon_def == null or not weapon_def.has_range():
		return []
	## The facing is stored in BASE space (it is a property of how the prop was
	## placed), so it has to be rotated into the active view the same way the
	## cell is — otherwise the cone would keep pointing at the base-north wall
	## after the map turns, while the sprite correctly follows the rotation.
	var facing_delta: Vector2i = _view_facing_delta(weapon["facing"])
	return BlastCalculatorClass.flood_gu_cone(
		weapon["gu_cell"], facing_delta, weapon_def.cone_half_angle_deg,
		weapon_def.step_multipliers.size() - 1, _blocked_edges_dict()).keys()


## Rotate a base-space compass edge into the active perspective. A perspective
## flip turns the world by 90 deg per step, and the compass edges are exactly
## those 90 deg steps, so this is an index rotation rather than any angle math.
func _view_facing_delta(base_facing: String) -> Vector2i:
	const ORDER: Array[String] = ["NE", "SE", "SW", "NW"]
	const STEPS := {"N": 0, "E": 1, "S": 2, "W": 3}
	var i: int = ORDER.find(base_facing)
	if i < 0:
		return Vector2i.ZERO
	var steps: int = int(STEPS.get(String(room._active_perspective), 0))
	return FACING_DELTA[ORDER[(i + steps) % ORDER.size()]]


## The real trigger. Marks the wall Slices and roof Slabs inside the cone
## damaged via BlastCalculator (the only writer of Voxel.set_damage(), per
## DESTRUCTION_MASTER_PLAN §3), then re-renders synchronously through the
## existing dirty-flag pipeline — same reasoning TestZoneController.
## detonate_active() gives: a context-menu action is a discrete player action
## with no turn boundary to wait for.
##
## Deliberately NOT consumed on use, unlike a grenade: the whole point of the
## bench is firing the same weapon at four materials and comparing, so a shot
## that removed its own weapon would make the experiment single-use.
##
## Deliberately does NOT crater the FLOOR, also unlike a grenade: a shot hits
## what it is aimed at. apply_crater_damage() is not called here at all.
func fire_active() -> void:
	if _active_index < 0 or _active_index >= _weapons.size():
		return
	var w: Dictionary = _weapons[_active_index]
	var weapon_def = Registries.get_weapon_registry().get_weapon(w["weapon_id"])
	if weapon_def == null:
		push_error("[WeaponBenchController] no WeaponDef for id '%s'" % w["weapon_id"])
		cancel_active()
		return
	if room._edge_registry == null or room._slab_registry == null:
		cancel_active()
		return

	var gu_cone := BlastCalculatorClass.flood_gu_cone(
		w["gu_cell"], _view_facing_delta(w["facing"]), weapon_def.cone_half_angle_deg,
		weapon_def.step_multipliers.size() - 1, _blocked_edges_dict())
	var affected := BlastCalculatorClass.find_affected_containers(
		gu_cone, room._edge_registry, room._slab_registry)

	print_debug("[SHOT] weapon=%s gu=%s facing=%s cone_cells=%d slices=%d roofs=%d" %
		[w["weapon_id"], w["gu_cell"], w["facing"], gu_cone.size(),
		affected["slices"].size(), affected["roofs"].size()])

	## Epicentre in VOXEL coords, at the MUZZLE — so VL-D4's directional bias
	## chews the wall face actually pointed at, rather than spreading evenly
	## through it.
	var epicenter: Vector2i = w["gu_cell"] * GeometryCoords.VOXELS_PER_UNIT_AXIS \
		+ Vector2i(GeometryCoords.VOXELS_PER_UNIT_AXIS / 2, GeometryCoords.VOXELS_PER_UNIT_AXIS / 2)

	var cell_to_voxel: Dictionary = {}
	var destroyed_cells: Array = []
	for slice_id in affected["slices"]:
		var slice: Slice = room._edge_registry.get_slice(slice_id)
		BlastCalculatorClass.apply_container_damage(
			slice.voxels, slice.id, slice.material, affected["slices"][slice_id],
			slice.start_storey * GeometryCoords.LEVELS_PER_STOREY, false,
			weapon_def.step_multipliers, epicenter, weapon_def.destroy_multiplier)
		for v in slice.voxels:
			_index_voxel_for_soot(cell_to_voxel, destroyed_cells, v)
	for slab_id in affected["roofs"]:
		var slab: Slab = room._slab_registry.get_slab(slab_id)
		BlastCalculatorClass.apply_container_damage(
			slab.voxels, slab.id, slab.material, affected["roofs"][slab_id],
			slab.level, true, weapon_def.step_multipliers, epicenter,
			weapon_def.destroy_multiplier)
		for v in slab.voxels:
			_index_voxel_for_soot(cell_to_voxel, destroyed_cells, v)

	## VL-D1: scorch what survives around each new hole. One ring, not the
	## grenade's three — a bullet strike marks its impact, it does not blacken
	## the whole wall.
	BlastCalculatorClass.compute_soot_rings(cell_to_voxel, destroyed_cells, 1)

	## VL-PERSIST: record into base coords so the damage survives a perspective
	## flip, which rebuilds every Voxel from the MapSpec.
	for key in cell_to_voxel:
		var av: Voxel = cell_to_voxel[key]
		room.record_voxel_damage_to_base(av.grid_pos, av.level, av.damage_state, av.soot_ring)

	room._voxel_renderer.process_dirty(room._edge_registry)
	room._voxel_renderer.process_dirty_slabs(room._slab_registry)
	if room.has_method("_repaint_voxel_light_buckets"):
		room._repaint_voxel_light_buckets()

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


func _index_voxel_for_soot(cell_to_voxel: Dictionary, destroyed_cells: Array, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v
	if v.damage_state == Voxel.DamageState.DESTROYED:
		destroyed_cells.append(key)


## Same conversion TestZoneController._blocked_edges_dict() does — room's
## {"from","to"} pairs folded into the keyed shape WallEdgeData queries.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked
