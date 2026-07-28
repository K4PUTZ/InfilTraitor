## ACTOR_MASTER_PLAN D21/D17/D14 — floating/rotating collectible, the
## reusable "simplification" display for any object (Part 6, still otherwise
## unspecified). First proven with the shotgun; STANDARDIZED (Director,
## 2026-07-28) to take its bake folder and visual scale per-instance via
## setup(), so every future collectible reuses this same class instead of a
## per-object copy.
##
## Cycles pre-rendered flat-color + normal-map frame pairs (produced by a
## bake tool following actor_frame_bake_spike.gd's template) through a
## per-pixel relighting shader (flat_normal_relight.gdshader) so the sprite
## shades directionally against the world's real light data — no voxel
## geometry, no live 3D scene at runtime, matching D16's "simplification"
## concept exactly. Floats with a vertical sine bob and spins continuously
## (Director, 2026-07-27).
##
## GROUND SHADOW (Director, 2026-07-28, re-tuned same day after the first
## attempt shed reused the oblique COLOR frame, squashed on Y — that shears
## diagonal silhouettes and visibly rotates their apparent angle away from
## the real object's angle). Uses a dedicated frame_%02d_shadow.png per
## frame instead: a true top-down bake (actor_frame_bake_spike.gd), which
## has no directional foreshortening to shear when squashed. Pinned to
## floor height independent of the bob, and scaled slightly larger when the
## object is at the bottom of its bob and slightly smaller at the top —
## "acentuando a sensação de distância entre o objeto e o chão." A fixed
## HOVER_HEIGHT_PX lift keeps a visible gap between object and shadow even
## at the bob's lowest point.
##
## Frame count and rotation speed come from CollectibleBakeConfig
## (godot/scripts/systems/collectible_bake_config.gd) — the bake tool that
## produced frames_dir MUST have used the exact same FRAME_COUNT/camera
## convention, or the frame index math and the light-direction math below
## both go wrong silently.
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

const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"

## Bumped 6.0 -> 18.0 (Director, 2026-07-28: "aumenta o BOB_AMPLITUDE_PX pra
## sombra ficar mais evidente") — the previous range was too subtle to read
## as real separation between the object and its ground shadow.
const BOB_AMPLITUDE_PX := 18.0
const BOB_PERIOD_SEC := 2.0

## Fixed lift above the floor GU point, independent of the bob — without
## this the sprite's resting position sits exactly ON the floor point, so
## even at the bottom of the bob there's no real gap for the shadow to read
## against (Director, 2026-07-28: "aumentar um poquinho a altura Y do
## objeto... pra dar mais um espacinho pra sombra ficar visível"). The
## shadow itself is NOT lifted — it stays pinned at the true floor Y.
const HOVER_HEIGHT_PX := 14.0

## Ground-shadow tuning, same visual-judgment-call convention as
## SPRITE_SCALE — first guess, tune once seen in a real capture.
const SHADOW_ALPHA := 0.45
## At the bottom of the bob (object nearest the floor) the shadow reads
## slightly WIDER; at the top (object at its highest) slightly smaller —
## "acentuando a sensação de distância entre o objeto e o chão" (Director).
## Kept close to 1.0 on purpose ("ligeiramente") — too wide a range reads as
## the shadow itself pulsing/breathing instead of a subtle depth cue.
const SHADOW_SCALE_AT_TOP := 0.85
const SHADOW_SCALE_AT_BOTTOM := 1.05

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
## Perspective-independent anchor (North orientation) — gu_cell is derived
## from this plus the room's active perspective, same pattern as
## TestZoneController's grenade registry.
var base_cell: Vector2i = Vector2i.ZERO

var _frames_dir: String = ""
var _sprite_scale: float = 1.0
## Corrects for the shadow bake using a different SHADOW_ORTHO_SIZE/
## SHADOW_VIEWPORT_SIZE than the color/normal bake (a top-down view of an
## elongated object needs more frustum room, with no perspective
## foreshortening to compensate) — see setup()'s docstring for the formula.
var _shadow_scale_factor: float = 1.0

var _sprite: Sprite2D
var _shadow: Sprite2D
var _material: ShaderMaterial
var _color_frames: Array[Texture2D] = []
var _normal_frames: Array[Texture2D] = []
var _shadow_frames: Array[Texture2D] = []
var _frame_time := 0.0
var _bob_time := 0.0
## Floor GU world Y — the shadow's fixed anchor. Distinct from _base_y
## (the sprite's own resting Y, lifted above the floor by HOVER_HEIGHT_PX).
var _floor_y := 0.0
var _base_y := 0.0

## Fixed camera basis (world-space), derived once from
## CollectibleBakeConfig.ELEVATION_DEG/AZIMUTH_DEG — see file header for the
## exact derivation this mirrors.
var _cam_right := Vector3.ZERO
var _cam_up := Vector3.ZERO
var _cam_toward_viewer := Vector3.ZERO


func _init() -> void:
	var elev := deg_to_rad(CollectibleBakeConfig.ELEVATION_DEG)
	var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
	var to_camera := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev)).normalized()
	var forward := -to_camera  ## direction the camera looks, into the screen
	_cam_right = forward.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(forward).normalized()
	_cam_toward_viewer = to_camera


## frames_dir: folder containing frame_%02d_{color,normal,shadow}.png,
## CollectibleBakeConfig.FRAME_COUNT of each, produced by a bake tool
## following actor_frame_bake_spike.gd's template. sprite_scale: per-object
## visual judgment call (same convention as the bake's own MESH_SCALE).
## shadow_scale_factor: corrects for the shadow pass's own
## SHADOW_ORTHO_SIZE/SHADOW_VIEWPORT_SIZE differing from the color pass's —
## compute as (SHADOW_ORTHO_SIZE / SHADOW_VIEWPORT_SIZE.y) / (ORTHO_SIZE /
## VIEWPORT_SIZE.y) using the SAME bake script that produced frames_dir; 1.0
## if a future object's shadow bake happens to use identical framing.
func setup(p_room: Node, p_gu_cell: Vector2i, p_frames_dir: String, p_sprite_scale: float, p_shadow_scale_factor: float) -> void:
	room = p_room
	gu_cell = p_gu_cell
	_frames_dir = p_frames_dir
	_sprite_scale = p_sprite_scale
	_shadow_scale_factor = p_shadow_scale_factor
	base_cell = room._cell_to_base(gu_cell, room._active_perspective)
	_apply_z_index()


## Mirrors TestZoneController.reposition_for_perspective(): called from
## room.gd::_set_perspective() so this runtime-instantiated overlay follows
## rotation the same way the test-zone grenades do, instead of gu_cell
## silently going stale (pre-fix behavior).
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	gu_cell = PerspectiveMapperClass.cell_from_base(base_cell, direction, base_size)
	if room != null and room.agent != null:
		var world_pos: Vector2 = room.agent._cell_to_world(gu_cell)
		_floor_y = world_pos.y
		position = Vector2(world_pos.x, _floor_y - HOVER_HEIGHT_PX)
		_base_y = position.y
	_apply_z_index()


## D22-FOLLOWUP (2026-07-28, Director-reported): floats at floor height —
## must sort like level-0 voxel geometry (any level>=1 wall/roof column
## draws over it wherever they visually overlap on screen), not "always
## above everything" (OCC-03's agent-only policy, wrongly copied here
## originally, same fix as GrenadeProp._apply_z_index()). _set_perspective()
## rebuilds every voxel TileMapLayer from scratch, so this must be
## re-applied on every rotation, not just once at setup.
func _apply_z_index() -> void:
	if room == null or room._voxel_renderer == null:
		return
	var ground_layer: TileMapLayer = room._voxel_renderer.get_layer(0)
	if ground_layer != null:
		z_index = ground_layer.z_index


func _ready() -> void:
	for i in range(CollectibleBakeConfig.FRAME_COUNT):
		var color_path := "%sframe_%02d_color.png" % [_frames_dir, i]
		var normal_path := "%sframe_%02d_normal.png" % [_frames_dir, i]
		var shadow_path := "%sframe_%02d_shadow.png" % [_frames_dir, i]
		_color_frames.append(_load_texture_raw(color_path))
		_normal_frames.append(_load_texture_raw(normal_path))
		_shadow_frames.append(_load_texture_raw(shadow_path))

	## Added BEFORE _sprite so it draws underneath at the same z_index
	## (Godot resolves same-z siblings in tree order) — sits on the floor,
	## under the object, unaffected by the bob (see _process()).
	_shadow = Sprite2D.new()
	_shadow.texture = _shadow_frames[0]
	_shadow.centered = true
	_shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	var shadow_base_scale := _sprite_scale * _shadow_scale_factor
	## Negative X mirrors the shadow horizontally — required to match the
	## bake's up-vector convention (actor_frame_bake_spike.gd's shadow-pass
	## comment has the full derivation); dropping this mirror is what caused
	## the Director-reported angle mismatch even with a true top-down bake.
	_shadow.scale = Vector2(-shadow_base_scale, shadow_base_scale * CollectibleBakeConfig.SHADOW_SQUASH_Y)
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = _color_frames[0]
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * _sprite_scale

	var shader := load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("normal_tex", _normal_frames[0])
	_sprite.material = _material
	add_child(_sprite)

	if room != null and room.agent != null:
		var world_pos: Vector2 = room.agent._cell_to_world(gu_cell)
		_floor_y = world_pos.y
		position = Vector2(world_pos.x, _floor_y - HOVER_HEIGHT_PX)
	_base_y = position.y

	set_process(true)


func _process(delta: float) -> void:
	_frame_time += delta
	var rotation_deg := fmod(_frame_time * CollectibleBakeConfig.ROTATION_DEG_PER_SEC, 360.0)
	var frame_index := int(rotation_deg / (360.0 / CollectibleBakeConfig.FRAME_COUNT)) % CollectibleBakeConfig.FRAME_COUNT
	_sprite.texture = _color_frames[frame_index]
	_material.set_shader_parameter("normal_tex", _normal_frames[frame_index])
	## Same frame index as the sprite, every frame — the shadow always
	## matches the object's current rotation, "girando na mesma velocidade"
	## (Director), using its OWN true top-down bake (see file header).
	_shadow.texture = _shadow_frames[frame_index]

	_bob_time += delta
	var bob_phase := sin((_bob_time / BOB_PERIOD_SEC) * TAU)  ## -1 (top) .. +1 (bottom)
	var bob := bob_phase * BOB_AMPLITUDE_PX
	position.y = _base_y + bob
	## Counter the parent's (lifted + bobbing) position in local space so the
	## shadow's WORLD position stays pinned exactly at the floor regardless
	## of HOVER_HEIGHT_PX or the current bob — that fixed-vs-floating
	## contrast is the whole point (Director: "deixar claro onde está
	## posicionada a arma em relação ao chão").
	_shadow.position.y = _floor_y - position.y
	## Slightly wider at the bottom of the bob, slightly smaller at the top —
	## bob_phase is +1 at the bottom (sin peak = position.y at its max,
	## furthest down the screen = nearest the floor) and -1 at the top.
	var shadow_mult := lerpf(SHADOW_SCALE_AT_TOP, SHADOW_SCALE_AT_BOTTOM, (bob_phase + 1.0) * 0.5)
	var shadow_base_scale := _sprite_scale * _shadow_scale_factor * shadow_mult
	## Negative X mirror — see the matching comment in _ready().
	_shadow.scale = Vector2(-shadow_base_scale, shadow_base_scale * CollectibleBakeConfig.SHADOW_SQUASH_Y)

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
