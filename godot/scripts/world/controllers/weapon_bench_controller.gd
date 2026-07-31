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

const MENU_GAP_ABOVE_PX: float = 30.0

## COLOR-GRADE-02 (Director, 2026-07-30): a runtime nudge on top of D31's
## baked grade, tunable without a windowed GPU re-bake — change these two
## numbers and re-capture. 1.0/1.0 would be a no-op (the shader's own
## default); values here are the "um pouquinho" starting point.
const WEAPON_GRADE_SATURATION := 1.3
const WEAPON_GRADE_CONTRAST := 1.15

## D26 (Director, 2026-07-30): "não pode ter esse limite de 5 GUs" — there is
## no authored range cap; a miss travels until it finds a wall, and the
## cone's own angular widening is what makes a far shot self-limiting. This
## replaces weapon_def.step_multipliers.size()-1 as the flood's max_steps
## (both for the wireframe preview and the real shot) with a generous,
## comfortably-past-any-real-room constant instead.
const PELLET_FLOOD_MAX_STEPS: int = 40

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
	sprite.grade_saturation = WEAPON_GRADE_SATURATION
	sprite.grade_contrast = WEAPON_GRADE_CONTRAST
	sprite.setup(room, gu_cell, frames_dir, sprite_scale, shadow_scale_factor, facing)
	room.add_child(sprite)
	_weapons.append({
		"gu_cell": gu_cell,
		"base_cell": base_cell,
		"facing": facing,
		"weapon_id": weapon_id,
		"sprite": sprite,
		"shots_fired": 0,
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


func _top_screen_pos(weapon: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(weapon)
	var world_top := rect.position + Vector2(rect.size.x / 2.0, 0.0)
	return room.get_viewport().get_canvas_transform() * world_top


## Index of the weapon standing on the clicked GU cell, or -1. Director
## (2026-07-30): the clickable hitbox for an interactive object is the FLOOR
## CELL it occupies, not its sprite — a bench weapon is an ordinary floor
## prop, not one of the direct-click exceptions (wall-mounted breakables,
## ceiling lamps), so it hit-tests the same way any other floor object would.
func hit_test(screen_pos: Vector2) -> int:
	var cell: Vector2i = room._screen_to_tile(screen_pos)
	if cell == room.INVALID_CELL:
		return -1
	for i in range(_weapons.size()):
		if _weapons[i]["gu_cell"] == cell:
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
	if weapon_def.delivery != WeaponDef.DELIVERY_CONE:
		return []
	## The facing is stored in BASE space (it is a property of how the prop was
	## placed), so it has to be rotated into the active view the same way the
	## cell is — otherwise the cone would keep pointing at the base-north wall
	## after the map turns, while the sprite correctly follows the rotation.
	var facing_delta: Vector2i = _view_facing_delta(weapon["facing"])
	return BlastCalculatorClass.flood_gu_cone(
		weapon["gu_cell"], facing_delta, weapon_def.cone_half_angle_deg,
		PELLET_FLOOD_MAX_STEPS, _blocked_edges_dict()).keys()


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
	## Dispatch on the declared delivery shape, and LOUD-FAIL on the ones that do
	## not exist yet rather than quietly firing the wrong geometry. The rifled
	## weapons on the bench honestly declare LINE (WEAPON_MASTER_PLAN D1) — a
	## ray with penetration depth, which is a different mechanic from CONE, not
	## a narrow cone. Firing a cone out of a sniper rifle because it is the only
	## shape implemented would be exactly the kind of silent substitution this
	## project's evidence rules ban.
	if weapon_def.delivery != WeaponDef.DELIVERY_CONE:
		push_error("[WeaponBenchController] '%s' declares delivery %s, which is not implemented yet — only CONE is (WEAPON_MASTER_PLAN Part 2 / DESTRUCTION_MASTER_PLAN Part 5)." %
			[w["weapon_id"], weapon_def.delivery])
		cancel_active()
		return
	if room._edge_registry == null or room._slab_registry == null:
		cancel_active()
		return

	## D26/D27 (Director, 2026-07-30): N discrete pellet impact points within
	## the (now uncapped) cone, never a flood-filled area — replaces the old
	## find_affected_containers()+apply_container_damage() ring-scatter for
	## CONE, which is exactly what was reading as "quase como uma granada,
	## desde o chão até o teto." A miss keeps travelling regardless of
	## distance (D26), so max_steps is a generous constant, not a range cap.
	var pellet_salt: String = "%s_%s_%d" % [w["weapon_id"], w["gu_cell"], int(w["shots_fired"])]
	w["shots_fired"] = int(w["shots_fired"]) + 1
	var pellet_picks := BlastCalculatorClass.select_cone_pellet_impacts(
		w["gu_cell"], _view_facing_delta(w["facing"]), weapon_def.cone_half_angle_deg,
		PELLET_FLOOD_MAX_STEPS, weapon_def.projectile_count, _blocked_edges_dict(),
		room._blocked_cells, pellet_salt)

	var cell_to_voxel: Dictionary = {}
	var pellets_landed := 0
	for i in range(pellet_picks.size()):
		var resolved := BlastCalculatorClass.resolve_pellet_voxel(
			pellet_picks[i], room._edge_registry, "%s:%d" % [pellet_salt, i])
		if resolved.is_empty():
			continue
		pellets_landed += 1
		var slice: Slice = resolved["slice"]
		var touched := BlastCalculatorClass.apply_point_impact(
			slice, resolved["voxel_index"], slice.material, weapon_def.destroy_multiplier,
			room._edge_registry, "%s:%d" % [pellet_salt, i])
		for v in touched:
			_index_voxel(cell_to_voxel, v)

	print_debug("[SHOT] weapon=%s gu=%s facing=%s pellets=%d/%d landed" %
		[w["weapon_id"], w["gu_cell"], w["facing"], pellets_landed, pellet_picks.size()])
	## No roof/ceiling branch: D18 shots are chest-height and horizontal, and
	## the per-pellet model only ever picks WALL-facing candidates
	## (select_cone_pellet_impacts() checks blocked_edges between horizontal
	## neighbours only) — this is what actually fixes "desde o chão até o
	## teto," not a parameter tweak on the old ring model.

	## D24: no explicit soot call here any more -- room._build_soot_snapshot()
	## derives it fresh (up to 3 rings) for the whole map from whichever
	## voxels are currently destroyed, every time _repaint_voxel_light_buckets()
	## runs below. An isolated bullet hole naturally reads as ~1 ring (nothing
	## further out is ALSO absent); a wide breach reads deeper on its own, no
	## bullet/blast distinction needed for this part.

	## VL-PERSIST: record into base coords so the damage survives a perspective
	## flip, which rebuilds every Voxel from the MapSpec.
	for key in cell_to_voxel:
		var av: Voxel = cell_to_voxel[key]
		room.record_voxel_damage_to_base(av.grid_pos, av.level, av.damage_state)

	room._voxel_renderer.process_dirty(room._edge_registry)
	room._voxel_renderer.process_dirty_slabs(room._slab_registry)
	if room.has_method("_repaint_voxel_light_buckets"):
		room._repaint_voxel_light_buckets()

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


## D24: soot no longer needs a destroyed_cells seed list here -- room's own
## repaint-time derivation (BlastCalculator.derive_soot_rings()) walks the
## whole map fresh. This just indexes which voxels THIS shot touched, for the
## VL-PERSIST loop above.
func _index_voxel(cell_to_voxel: Dictionary, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v


## Same conversion TestZoneController._blocked_edges_dict() does — room's
## {"from","to"} pairs folded into the keyed shape WallEdgeData queries.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked
