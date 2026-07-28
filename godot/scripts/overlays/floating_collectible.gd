## ACTOR_MASTER_PLAN D21/D17/D14 — floating/rotating collectible, first real
## test of the simplification system (Part 6, still otherwise unspecified).
##
## Cycles pre-rendered flat-color + normal-map frame pairs
## (actor_frame_bake_spike.gd's output) through a per-pixel relighting
## shader (flat_normal_relight.gdshader) so the sprite shades directionally
## against the world's real light data — no voxel geometry, no live 3D scene
## at runtime, matching D16's "simplification" concept exactly. Floats with
## a gentle vertical sine bob and spins continuously (Director, 2026-07-27).
##
## Light-direction simplification, stated plainly rather than hidden: the
## game has no real 3D world space — gameplay is a 2D grid + an isometric
## screen projection. To relight a normal map baked from a fixed 3D camera,
## this maps grid-x -> bake-world-x and grid-y -> bake-world-z (an explicit,
## documented choice, not a derived one).
##
## PERSPECTIVE-AWARE FIX (Director, 2026-07-28, closes ACTOR_MASTER_PLAN
## open question #16 / D22): the grid delta between light and object is
## computed in the room's CURRENT view-space cells, then de-rotated back to
## base (North) orientation via PerspectiveMapper.cell_to_base() before the
## grid-x/grid-y -> world-x/world-z mapping is applied — the bake camera's
## fixed azimuth was always derived against a canonical N view, so feeding
## it a raw view-space delta from a rotated (E/S/W) perspective silently
## picked the wrong world direction. Same idea as
## TestZoneController.reposition_for_perspective(): this object also now
## tracks its own base_cell and re-derives its view-space gu_cell on every
## perspective flip (see reposition_for_perspective() below), so gu_cell
## never goes stale the way it used to before this fix.
class_name FloatingCollectible
extends Node2D

const FRAMES_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/"
const FRAME_COUNT := 24
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

## Matches showcase_panel.gd's SPIN_DEG_PER_SEC exactly (Director,
## 2026-07-27: the collectible's spin read far too fast at the bake's own
## 24fps frame-advance rate — 360 deg/sec, a full turn per second — next to
## the Showcase's slow, deliberate spin). This is the angular speed the
## object visually rotates at; FRAME_COUNT (24, D14's bake budget) stays a
## separate, unrelated decision about how many discrete angles were baked.
const ROTATION_DEG_PER_SEC := 14.0

## A modest bump over the bake's native 160x160 px (Director, 2026-07-27) —
## the collectible read a little small next to the rest of the test zone.
const SPRITE_SCALE := 1.15

const BOB_AMPLITUDE_PX := 6.0
const BOB_PERIOD_SEC := 2.0

## Fixed bake-camera convention (actor_frame_bake_spike.gd) — must match
## exactly, since the normal maps were encoded in this camera's view space.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
## Perspective-independent anchor (North orientation) — gu_cell is derived
## from this plus the room's active perspective, same pattern as
## TestZoneController's grenade registry.
var base_cell: Vector2i = Vector2i.ZERO

var _sprite: Sprite2D
var _material: ShaderMaterial
var _color_frames: Array[Texture2D] = []
var _normal_frames: Array[Texture2D] = []
var _frame_time := 0.0
var _bob_time := 0.0
var _base_y := 0.0

## Fixed camera basis (world-space), derived once from ELEVATION_DEG/
## AZIMUTH_DEG — see file header for the exact derivation this mirrors.
var _cam_right := Vector3.ZERO
var _cam_up := Vector3.ZERO
var _cam_toward_viewer := Vector3.ZERO


func _init() -> void:
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var to_camera := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev)).normalized()
	var forward := -to_camera  ## direction the camera looks, into the screen
	_cam_right = forward.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(forward).normalized()
	_cam_toward_viewer = to_camera


func setup(p_room: Node, p_gu_cell: Vector2i) -> void:
	room = p_room
	gu_cell = p_gu_cell
	base_cell = room._cell_to_base(gu_cell, room._active_perspective)


## Mirrors TestZoneController.reposition_for_perspective(): called from
## room.gd::_set_perspective() so this runtime-instantiated overlay follows
## rotation the same way the test-zone grenades do, instead of gu_cell
## silently going stale (pre-fix behavior).
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	gu_cell = PerspectiveMapperClass.cell_from_base(base_cell, direction, base_size)
	if room != null and room.agent != null:
		position = room.agent._cell_to_world(gu_cell)
		_base_y = position.y


func _ready() -> void:
	for i in range(FRAME_COUNT):
		var color_path := "%sframe_%02d_color.png" % [FRAMES_DIR, i]
		var normal_path := "%sframe_%02d_normal.png" % [FRAMES_DIR, i]
		_color_frames.append(_load_texture_raw(color_path))
		_normal_frames.append(_load_texture_raw(normal_path))

	_sprite = Sprite2D.new()
	_sprite.texture = _color_frames[0]
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * SPRITE_SCALE

	var shader := load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("normal_tex", _normal_frames[0])
	_sprite.material = _material
	add_child(_sprite)

	if room != null and room.agent != null:
		position = room.agent._cell_to_world(gu_cell)
	_base_y = position.y

	set_process(true)


func _process(delta: float) -> void:
	_frame_time += delta
	var rotation_deg := fmod(_frame_time * ROTATION_DEG_PER_SEC, 360.0)
	var frame_index := int(rotation_deg / (360.0 / FRAME_COUNT)) % FRAME_COUNT
	_sprite.texture = _color_frames[frame_index]
	_material.set_shader_parameter("normal_tex", _normal_frames[frame_index])

	_bob_time += delta
	var bob := sin((_bob_time / BOB_PERIOD_SEC) * TAU) * BOB_AMPLITUDE_PX
	position.y = _base_y + bob

	_update_light_uniform()


## D17: find the strongest active light affecting this cell and express its
## direction in the bake camera's fixed view space (see file header for the
## grid->world simplification and the perspective-rotation caveat).
func _update_light_uniform() -> void:
	if room == null or room._lighting_controller == null:
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
		## No active light reaches this cell — flat ambient only, matching
		## the flat baseline the color frames were rendered with.
		_material.set_shader_parameter("light_intensity", 0.0)
		return

	## De-rotate both cells from the room's CURRENT view-space back to base
	## (North) orientation before taking the delta — the bake camera's fixed
	## azimuth was derived against a canonical N view, so the grid-x/grid-y
	## -> world-x/world-z mapping below is only valid in that same base
	## orientation (see file header, D22/open question #16).
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	var base_light_cell: Vector2i = room._cell_to_base(best_light.cell, room._active_perspective, base_size)
	var grid_delta: Vector2i = base_light_cell - base_cell
	## Explicit grid->bake-world mapping (file header): grid-x -> world-x,
	## grid-y -> world-z, light assumed roughly floor-height (no Y term).
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


## actor_frame_bake_spike.gd's output has never been through the Godot
## editor's import scan (generated by --script CLI runs, not an editor
## session) — plain load() fails with "No loader found" for an unimported
## resource. Image.load() reads the raw file directly, sidestepping the
## import cache entirely; ImageTexture.create_from_image() wraps it as a
## normal Texture2D from there. Same fix needed if this ever runs on a
## machine where the editor hasn't reimported these frames.
func _load_texture_raw(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("[FloatingCollectible] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
