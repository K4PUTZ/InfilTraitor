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
		"sprite": sprite,
		"detonated": false,
	})


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
	room._context_menu.open_at(_top_screen_pos(_grenades[index]), MENU_GAP_ABOVE_PX)


func detonate_active() -> void:
	if _active_index < 0 or _active_index >= _grenades.size():
		return
	var g: Dictionary = _grenades[_active_index]
	if not g["detonated"]:
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false
		g["detonated"] = true
	_active_index = -1


func cancel_active() -> void:
	_active_index = -1
