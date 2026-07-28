## ACTOR_MASTER_PLAN objects track — grenade re-bake (2026-07-28). Replaces
## TestZoneController's old plain Sprite2D (a single frozen-angle bake,
## bake_voxel_sprite_3d.gd) with a relit prop driven by
## grenade_frame_bake_spike.gd's real per-direction 3D renders (one flat-color
## + one view-space-normal-map pair per N/E/S/W compass direction).
##
## Deliberately NOT a FloatingCollectible: this is a static ground prop, not a
## spinning pickup — no continuous rotation timer, no bob. The only thing that
## changes which of the 4 baked frames is shown is the room's active N/E/S/W
## perspective (the whole scene visually rotates on a perspective flip; this
## prop follows by swapping to the frame baked at the matching yaw, same
## PerspectiveMapper convention floating_collectible.gd's reposition_for_
## perspective() uses). Per-pixel relighting (flat_normal_relight.gdshader)
## and its perspective-aware light-direction math are otherwise identical to
## FloatingCollectible's fixed version — see that file for the fuller
## rationale (ACTOR_MASTER_PLAN D22 / open question #16).
class_name GrenadeProp
extends Sprite2D

const FRAMES_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/"
const DIRECTIONS := ["N", "E", "S", "W"]
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"

## grenade_frame_bake_spike.gd's own printed anchor_px (96x96 canvas) — the
## pixel that should land on the target world point, same convention the old
## GRENADE_ANCHOR_PX constant (TestZoneController) used.
const ANCHOR_PX: Vector2 = Vector2(48.0, 73.15551)

## First-guess visual scale, not derived — tune once seen in a real capture
## next to the rest of the test zone (same convention as FloatingCollectible's
## SPRITE_SCALE / actor_frame_bake_spike.gd's MESH_SCALE).
const SPRITE_SCALE := 1.0

## Fixed bake-camera convention (grenade_frame_bake_spike.gd) — must match
## exactly, since the normal maps were encoded in this camera's view space.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
var base_cell: Vector2i = Vector2i.ZERO

var _material: ShaderMaterial
var _color_frames: Dictionary = {}   ## direction (String) -> Texture2D
var _normal_frames: Dictionary = {}  ## direction (String) -> Texture2D

var _cam_right := Vector3.ZERO
var _cam_up := Vector3.ZERO
var _cam_toward_viewer := Vector3.ZERO


func _init() -> void:
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var to_camera := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev)).normalized()
	var forward := -to_camera
	_cam_right = forward.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(forward).normalized()
	_cam_toward_viewer = to_camera


func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i) -> void:
	room = p_room
	gu_cell = p_gu_cell
	base_cell = p_base_cell

	for direction in DIRECTIONS:
		_color_frames[direction] = _load_texture_raw("%sframe_%s_color.png" % [FRAMES_DIR, direction])
		_normal_frames[direction] = _load_texture_raw("%sframe_%s_normal.png" % [FRAMES_DIR, direction])

	centered = false
	offset = -ANCHOR_PX
	scale = Vector2.ONE * SPRITE_SCALE

	var shader := load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material

	_apply_direction(room._active_perspective)
	set_process(true)


## Called by TestZoneController.reposition_for_perspective() alongside the
## sprite's own position update — swaps to the frame baked for the new
## direction. base_cell never changes (perspective-independent anchor); only
## gu_cell (view-space) does.
func update_cell(p_gu_cell: Vector2i) -> void:
	gu_cell = p_gu_cell
	_apply_direction(room._active_perspective)


func _apply_direction(direction: String) -> void:
	if not _color_frames.has(direction):
		return
	texture = _color_frames[direction]
	if _material != null:
		_material.set_shader_parameter("normal_tex", _normal_frames[direction])


func _process(_delta: float) -> void:
	_update_light_uniform()


## Same perspective-aware mapping as FloatingCollectible._update_light_uniform
## (ACTOR_MASTER_PLAN D22 fix) — de-rotate both cells to base (North)
## orientation before applying the grid-x/grid-y -> world-x/world-z mapping,
## since the bake camera's fixed azimuth was derived against a canonical N
## view.
func _update_light_uniform() -> void:
	if room == null or room._lighting_controller == null or _material == null:
		return
	var registry = room._lighting_controller.get_light_registry()
	if registry == null:
		return

	var best_light = null
	var best_energy := -1.0
	for light in registry.get_active_lights():
		if not light.affects_cell(gu_cell):
			continue
		var energy: float = light.get_effective_tactical_energy()
		if energy > best_energy:
			best_energy = energy
			best_light = light

	if best_light == null:
		_material.set_shader_parameter("light_intensity", 0.0)
		return

	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	var base_light_cell: Vector2i = room._cell_to_base(best_light.cell, room._active_perspective, base_size)
	var grid_delta: Vector2i = base_light_cell - base_cell
	var light_dir_world := Vector3(float(grid_delta.x), 0.0, float(grid_delta.y)).normalized()
	if grid_delta == Vector2i.ZERO:
		light_dir_world = _cam_toward_viewer

	var light_dir_view := Vector3(
		light_dir_world.dot(_cam_right),
		light_dir_world.dot(_cam_up),
		light_dir_world.dot(_cam_toward_viewer)
	).normalized()

	_material.set_shader_parameter("light_dir", light_dir_view)
	_material.set_shader_parameter("light_intensity", clampf(best_energy, 0.0, 3.0))


## actor_frame_bake_spike.gd-style output has never been through the editor's
## import scan (generated by --script CLI runs) — plain load() fails with "No
## loader found" for an unimported resource. Same fix floating_collectible.gd
## uses.
func _load_texture_raw(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("[GrenadeProp] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
