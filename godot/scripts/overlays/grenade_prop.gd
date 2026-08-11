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
const SHADOW_SHADER_PATH := "res://godot/shaders/object_ground_shadow.gdshader"
const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")

## grenade_frame_bake_spike.gd's own printed anchor_px (96x96 canvas) — the
## pixel that should land on the target world point, same convention the old
## GRENADE_ANCHOR_PX constant (TestZoneController) used.
const ANCHOR_PX: Vector2 = Vector2(48.0, 73.15551)

## Visual judgment call, same convention as FloatingCollectible's SPRITE_SCALE
## / actor_frame_bake_spike.gd's MESH_SCALE — tuned down from the 1.0 first
## guess (Director, 2026-07-28: read too large next to the rest of the test
## zone).
const SPRITE_SCALE := 0.75

## Fixed bake-camera convention (grenade_frame_bake_spike.gd) — must match
## exactly, since the normal maps were encoded in this camera's view space.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

## Ground shadow — Director, 2026-08-10: "durante o vôo da granada, a sombra
## precisa acompanhar no chão, aumentando e diminuindo a opacidade e a difusão,
## de acordo com a distância vertical. Quando a granada encosta no chão a sombra
## é muito bem definida e bem menor, por baixo do asset. Durante o vôo ela
## aumenta um pouquinho e fica mais difusa."
##
## One height drives all three terms, so they cannot disagree about how high the
## grenade is. Height 0 = small, sharp, opaque, directly under the asset.
##
## SHADOW_HEIGHT_REF_PX is where the flight look is fully reached, and it is
## derived rather than picked: `ThrowArcOverlay.arc_height_for()` floors every
## apex at `launch_px * 1.4`, which for a standing throw (Agent.HEAD_OFFSET,
## 64 px) is 89.6 px. Saturating there means even the SHORTEST throw the geometry
## allows reaches the full effect at its own apex, and longer throws simply hold
## it instead of pumping — monotone in real height, and guaranteed to read.
const SHADOW_HEIGHT_REF_PX := 90.0

## The ground alpha is FloatingCollectible's own ratified SHADOW_ALPHA_SHARP_AT_
## BOTTOM rather than a third opinion about how dark a shadow in this project is.
##
## Its airborne partner (SHADOW_ALPHA_SOFT_AT_TOP, 0.28) was tried and MEASURED
## too faint here, and the reason is a real difference between the two objects
## rather than taste: the collectible's shadow is a BAKED, dilated blob under an
## object that hovers 60 px, while this one is a squashed 22 px silhouette under
## one that flies past 90 px — half the footprint, spread over more penumbra, on
## the same textured floor. Proven by forcing strength to 1.0 and the scale to
## 3.0, which rendered a perfectly placed black grenade (so the wiring was never
## the problem), then walking the alpha back to where the shape still reads.
const SHADOW_STRENGTH_AT_GROUND := 0.55
const SHADOW_STRENGTH_IN_FLIGHT := 0.35
const SHADOW_SCALE_AT_GROUND := 0.80
const SHADOW_SCALE_IN_FLIGHT := 1.05
## Blur radius in TEXELS of the 96 px frame (the shader's 5x5 box reaches
## +/- blur_px). The body is ~30 texels across, so this is a sixth of its width
## of penumbra at full height.
const SHADOW_BLUR_MAX_PX := 5.0

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
var base_cell: Vector2i = Vector2i.ZERO

var _material: ShaderMaterial
var _color_frames: Dictionary = {}   ## direction (String) -> Texture2D
var _normal_frames: Dictionary = {}  ## direction (String) -> Texture2D

var _shadow: Sprite2D
var _shadow_material: ShaderMaterial
## How far above its own ground point the body currently is, in world px. The
## thrown grenade's flight writes it; the four resting test-zone props never do,
## which is the "encosta no chão" look for free.
var _flight_height_px: float = 0.0

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


## The grenade's colour frames, by compass direction.
##
## Static, and the ONLY place the art's location is written down, because the
## aiming cursor has to show the same object the throw will actually put on the
## ground — Director, 2026-08-10: "vamos modificar a silhueta da granada-cursor
## para exibir o verdadeiro asset da granada, já que vamos ter outros tipos de
## explosivos. Carregue dinamicamente o que quer que tenha sido definido como
## granada." A hand-drawn silhouette beside a baked prop is two definitions of
## the same object, and the second explosive type is when they diverge.
##
## When explosives DO become plural, this is the seam: the frames directory
## becomes a BombDef field and this takes a bomb id. Nothing else has to move,
## because nothing else knows where the art lives.
static func load_color_frames() -> Dictionary:
	var frames: Dictionary = {}
	for direction: String in DIRECTIONS:
		frames[direction] = _load_texture_raw("%sframe_%s_color.png" % [FRAMES_DIR, direction])
	return frames


func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i) -> void:
	room = p_room
	gu_cell = p_gu_cell
	base_cell = p_base_cell

	_color_frames = load_color_frames()
	for direction in DIRECTIONS:
		_normal_frames[direction] = _load_texture_raw("%sframe_%s_normal.png" % [FRAMES_DIR, direction])

	centered = false
	offset = -ANCHOR_PX
	scale = Vector2.ONE * SPRITE_SCALE

	var shader := load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material

	_build_shadow()

	_apply_direction(room._active_perspective)
	_apply_z_index()
	_sync_shadow_transform()
	set_process(true)


## The shadow is a CHILD of the body, drawn behind it, showing the body's own
## silhouette through object_ground_shadow.gdshader.
##
## SUBSTITUTION, STATED: FloatingCollectible's shadow is two BAKED passes per
## frame; this prop's `grenade_frames/` has none (only the COLLECTIBLE spike ever
## had a shadow pass). Reading the alpha of the colour frame already on screen
## gives both looks from one texture with no pipeline run, and it is still the
## object's real silhouette rather than a stand-in ellipse. Full rationale in the
## shader's own header and TARGETING_MASTER_PLAN §6.1 A.
##
## Anchoring mirrors the body exactly — `centered = false`, `offset = -ANCHOR_PX`
## — which puts the texture's ground-contact texel on this node's origin. That is
## what makes the vertical squash below correct for free: scaling about the origin
## flattens the silhouette ONTO its contact point instead of sliding it off.
func _build_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.centered = false
	_shadow.offset = -ANCHOR_PX
	_shadow.show_behind_parent = true

	var shadow_shader := load(SHADOW_SHADER_PATH)
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = shadow_shader
	_shadow.material = _shadow_material
	add_child(_shadow)


## Feed the shadow the body's height above its own ground point, in world px.
## Called every frame of the throw; 0 once the grenade settles.
func set_flight_height_px(px: float) -> void:
	_flight_height_px = maxf(px, 0.0)
	_sync_shadow_transform()


## Put the shadow on the ground, unrotated, squashed — whatever the body is doing.
##
## The body tumbles, and a child inherits the parent's WHOLE transform, so both
## the shadow's rotation and its offset have to be undone or the squash shears and
## the shadow orbits the grenade. Undoing both exactly:
##
##     parent = T(pos)·R(θ)·S(s)      child = T(p)·R(-θ)·S(m, m·squash)
##     with p = R(-θ)·(0, h)/s
##     parent·child = T(pos + (0,h)) · S(s·m, s·m·squash)
##
## — no rotation left, the ground offset lands as a straight screen-space drop of
## h px, and the uniform parent scale cancels out of the linear part. The /s on
## `p` is because a child's position is expressed in the parent's SCALED space.
func _sync_shadow_transform() -> void:
	if _shadow == null:
		return
	## 0 on the ground, 1 at the height where the flight look is fully reached.
	var k: float = clampf(_flight_height_px / SHADOW_HEIGHT_REF_PX, 0.0, 1.0)
	var size_mult: float = lerpf(SHADOW_SCALE_AT_GROUND, SHADOW_SCALE_IN_FLIGHT, k)

	_shadow.position = Vector2(0.0, _flight_height_px / SPRITE_SCALE).rotated(-rotation)
	_shadow.rotation = -rotation
	_shadow.scale = Vector2(size_mult, size_mult * CollectibleBakeConfig.SHADOW_SQUASH_Y)
	_shadow_material.set_shader_parameter("blur_px", SHADOW_BLUR_MAX_PX * k)
	_shadow_material.set_shader_parameter("strength",
		lerpf(SHADOW_STRENGTH_AT_GROUND, SHADOW_STRENGTH_IN_FLIGHT, k))


## Called by TestZoneController.reposition_for_perspective() alongside the
## sprite's own position update — swaps to the frame baked for the new
## direction. base_cell never changes (perspective-independent anchor); only
## gu_cell (view-space) does. Re-applies z_index too: _set_perspective()
## rebuilds every voxel TileMapLayer from scratch (room_builder.gd's
## build_from_layout), so a z_index cached before rotation could reference a
## layer that no longer matches the new view's structure.
func update_cell(p_gu_cell: Vector2i) -> void:
	gu_cell = p_gu_cell
	_apply_direction(room._active_perspective)
	_apply_z_index()


## D22-FOLLOWUP (2026-07-28, Director-reported): this prop sits at floor
## height (level 0) — it must sort like level-0 voxel geometry does, not
## "always above everything" (OCC-03's agent-only policy, wrongly copied here
## originally). Using the SAME z_index the ground layer itself uses lets any
## level>=1 wall/roof column that visually overlaps it on screen correctly
## draw on top, exactly like real voxel geometry would, instead of the prop
## punching through every wall and roof in the map after a perspective
## rotation moved it under one. No occlusion-ghosting involved on purpose —
## Director's call: these props should be hidden by geometry like anything
## else, not exempted from it.
func _apply_z_index() -> void:
	if room == null or room._voxel_renderer == null:
		return
	var ground_layer: TileMapLayer = room._voxel_renderer.get_layer(0)
	if ground_layer != null:
		z_index = ground_layer.z_index


func _apply_direction(direction: String) -> void:
	if not _color_frames.has(direction):
		return
	texture = _color_frames[direction]
	## The shadow reads the alpha of the SAME frame the body is showing, so it
	## can never fall a perspective flip behind the silhouette it belongs to.
	if _shadow != null:
		_shadow.texture = texture
	if _material != null:
		_material.set_shader_parameter("normal_tex", _normal_frames[direction])


## The throw calls `set_flight_height_px()` right after it writes `rotation`, so
## the shadow is already correct on those frames; this covers every other one —
## a resting prop, and any future rotation this node does not drive itself.
func _process(_delta: float) -> void:
	_sync_shadow_transform()
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
static func _load_texture_raw(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("[GrenadeProp] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
