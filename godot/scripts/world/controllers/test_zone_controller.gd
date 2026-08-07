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
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const DetonationChoreographerClass = preload("res://godot/scripts/systems/destruction/detonation_choreographer.gd")

var room: Node
var _grenades: Array[Dictionary] = []
var _active_index: int = -1

## EXPLOSION_REBUILD_MASTER_PLAN Task 5 (E-WAVE) — keeps the in-flight
## DetonationChoreographer (a RefCounted, not a Node) alive for its whole
## ~600ms wave sequence. `detonate_active()`'s own local variable is not
## enough on its own to guarantee this across every code path; holding it
## here ties its lifetime to this controller (the whole room's), the same
## explicit-ownership pattern _grenades already uses instead of leaning on
## implicit signal-connection keep-alive semantics.
var _active_choreographer = null

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


## EXPLOSION_REBUILD_MASTER_PLAN Task 5 (E-WAVE, 2026-08-07): the real
## trigger, reconnected — disconnected 2026-08-05 (commit `d412480`) while the
## destruction visual system was rebuilt from scratch (the prior patch-on-
## patch arc, PERF-01/02/03 + D11 + D-ARCH-01, was judged not worth its own
## cost/complexity). `DetonationPlanBuilder.build_plan()` (Task 4) does all
## resolution and exposure fallback up front; `DetonationChoreographer`
## (Task 5) is the only thing that actually paints it, as the real 15-wave
## sequence from §1's table. Firearm destruction
## (WeaponBenchController.fire_active()) is untouched by this — it still
## renders through VoxelRenderer.process_dirty()'s single-frame D-ARCH-01 swap.
##
## Gap, flagged not silently dropped: VFX-01's per-voxel dust/spark/chip
## debris (room._dispatch_destruction_vfx(), driven by the voxel_destroyed
## signal) does not fire for blast-caused destruction any more — the
## choreographer's destroy wave calls layer.erase_cell() directly rather than
## going through VoxelRenderer.process_dirty(), and the DetonationPlan's own
## destroy entries carry no material to dispatch debris VFX from (§6.1's
## literal shape is {cell, level} only). Firearms are unaffected (still the
## signal-driven path). Revisit if the Director wants blast debris back —
## needs material threaded onto destroy plan entries, not a quick patch here.
func detonate_active() -> void:
	if _active_index < 0 or _active_index >= _grenades.size():
		return
	var g: Dictionary = _grenades[_active_index]
	if not g["detonated"]:
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false
		g["detonated"] = true

		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null and room._edge_registry != null and room._slab_registry != null:
			var gu: Vector2i = g["gu_cell"]
			var ctx := _build_detonation_ctx(gu)
			var plan := DetonationPlanBuilderClass.build_plan(bomb_def, gu, ctx)
			room._gu_blast_count[gu] = int(room._gu_blast_count.get(gu, 0)) + 1

			## VL-PERSIST: record every voxel this blast actually changed so
			## rotation replays it — the exact set Task 4's own plan returns,
			## no second flood/find_affected_containers pass needed.
			for voxel in plan["touched_voxels"]:
				room.record_voxel_damage_to_base(voxel.grid_pos, voxel.level, voxel.damage_state,
					voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant,
					voxel.damage_substrate)

			var choreographer := DetonationChoreographerClass.new()
			_active_choreographer = choreographer
			choreographer.finished.connect(func(): _active_choreographer = null)
			choreographer.start(plan, room._voxel_renderer, room._smoke_spark_overlay, room.get_tree())

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


## The real ctx DetonationPlanBuilder.build_plan() needs, assembled from the
## live room — mirrors detonation_plan_selftest.gd's own MinimalRoom ctx
## builder, except lights/shadow_results come from the REAL LightingController
## instead of a hand-converted map-data dict (a real room already has one).
func _build_detonation_ctx(source_gu: Vector2i) -> Dictionary:
	var lights: Array = []
	var shadow_results: Array = []
	if room._lighting_controller != null:
		var registry = room._lighting_controller.get_light_registry()
		if registry != null:
			lights = registry.get_active_lights()
		shadow_results = room._lighting_controller.get_shadow_results()
	return {
		"edge_registry": room._edge_registry,
		"slab_registry": room._slab_registry,
		"voxel_renderer": room._voxel_renderer,
		"blocked_edges": _blocked_edges_dict(),
		"blocked_cells": room._blocked_cells,
		"lights": lights,
		"shadow_results": shadow_results,
		"under_structure": room._under_structure,
		## D2: unlocked from this GU's SECOND blast onward.
		"deep_layer_unlocked": int(room._gu_blast_count.get(source_gu, 0)) > 0,
	}


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
