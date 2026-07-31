## ACTOR_MASTER_PLAN D17/D21/D14 — flat-3D + normal-map + shadow bake
## TEMPLATE for a FloatingCollectible. Renders N rotation frames of an
## imported mesh (D12's path, proven by shotgun_preview_spike.gd) from the
## SAME fixed isometric camera the rest of the game uses — the OBJECT
## rotates around its own vertical axis between frames, the camera never
## moves, matching how a spinning collectible would actually be seen by the
## game's one fixed view. Each frame gets THREE renders:
##  - color: a flat, unlit pass (today's D13-style ambient-only look,
##    intentionally not baking any directional light in)
##  - normal: view-space surface normal encoded as RGB (the standard
##    normal-bake technique) — the pair a runtime CanvasItem shader needs to
##    relight the flat sprite per-pixel against the world's real light data,
##    without any voxel geometry at runtime
##  - shadow: a SEPARATE straight-down (top-view) silhouette pass, NOT the
##    color frame reused — squashing the oblique color view on Y to fake a
##    ground shadow shears diagonal silhouettes and visibly rotates their
##    apparent angle (Director-reported, 2026-07-28). A true top-down view
##    has no directional foreshortening, so it can be squashed on Y to fit
##    the isometric ground diamond without distortion. Dilated + blurred at
##    bake time (cheaper once than every runtime frame) for a soft blob edge.
##
## STANDARDIZED (Director, 2026-07-28): this was the shotgun's own bake
## script; frame count, rotation speed, and the fixed bake-camera/shadow
## conventions now live in CollectibleBakeConfig (godot/scripts/systems/
## collectible_bake_config.gd) so every future collectible reuses the same
## tuned sweet spot instead of re-deriving it — see that file for the
## frame-swap-rate and shadow-squash reasoning. To bake a NEW collectible:
## copy this file, change MODEL_PATH/OUT_DIR and re-tune the per-object
## knobs below (MESH_SCALE/VIEWPORT_SIZE/ORTHO_SIZE/SHADOW_* — always a
## visual judgment call, same convention MESH_SCALE always has been); never
## touch the CollectibleBakeConfig-sourced values.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/actor_frame_bake_spike.gd
extends SceneTree

const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")

## --- Per-object knobs: change these when baking a different collectible ---
const MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Shotgun Short Stock.glb"
const OUT_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/"
const VIEWPORT_SIZE := Vector2i(160, 160)
const ORTHO_SIZE := 4.0
## First-guess world scale for the imported mesh — visually tuned, not derived.
const MESH_SCALE := 0.5
## Top-down shadow pass — deliberately smaller canvas (cheap to dilate/blur)
## and a generous ortho size (an elongated object's longest axis, seen from
## directly above, needs more frustum room than the oblique 3/4 view does).
const SHADOW_VIEWPORT_SIZE := Vector2i(80, 80)
const SHADOW_ORTHO_SIZE := 5.0
const SHADOW_CAMERA_DISTANCE := 12.0
## --- End per-object knobs ---

const NORMAL_BAKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
"""

enum PassType { COLOR, NORMAL, SHADOW }

## COLOR-GRADE-01 (Director, 2026-07-30) — mirrored from weapon_frames_bake.gd,
## see that file's header for the full "why" (measured: baked albedo dark AND
## nearly hueless, e.g. pistol frame_00 pre-grade mean RGB (47,46,45)/255;
## runtime light/ambient cannot inject a hue that was never captured). This
## script is the shotgun's own bake (WEAPONS array in the sibling script
## doesn't cover it), so it needs the same grade applied separately rather
## than silently staying the one ungraded gun on the bench.
const GRADE_BRIGHTNESS_GAIN := 1.9
const GRADE_BLACK_LIFT := 0.06
const GRADE_SATURATION_BOOST := 1.8
const GRADE_TINT_COLOR := Color(0.4, 0.55, 0.75)  ## cool gunmetal steel-blue
const GRADE_TINT_STRENGTH := 0.22


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Actor frame bake spike — color + normal + shadow, %d frames (%s)" % [CollectibleBakeConfig.FRAME_COUNT, Time.get_date_string_from_system()])
	print("=".repeat(78))

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("actor_frame_bake_spike: could not create output dir (error %d)" % dir_err)
		quit(1)
		return

	for i in range(CollectibleBakeConfig.FRAME_COUNT):
		var angle_deg := (360.0 / CollectibleBakeConfig.FRAME_COUNT) * i
		await _render_frame(i, angle_deg)

	print("\n[BAKE] Done — %d frame triples in %s\n" % [CollectibleBakeConfig.FRAME_COUNT, OUT_DIR])
	quit(0)


func _render_frame(index: int, object_yaw_deg: float) -> void:
	var color_img := await _render_pass(object_yaw_deg, PassType.COLOR)
	_grade_color_image(color_img)
	var normal_img := await _render_pass(object_yaw_deg, PassType.NORMAL)
	## ONE raw top-down render, post-processed TWICE (sharp/soft) — not two
	## separate 3D renders. FloatingCollectible crossfades between these by
	## the object's current bob height (Director, 2026-07-28): small+sharp
	## near the floor, big+diffuse at the top of the bob.
	var shadow_raw := await _render_pass(object_yaw_deg, PassType.SHADOW)
	var shadow_sharp_img: Image = shadow_raw.duplicate() as Image
	_dilate_alpha(shadow_sharp_img, CollectibleBakeConfig.SHADOW_SHARP_DILATE_ITERATIONS)
	_blur_alpha(shadow_sharp_img, CollectibleBakeConfig.SHADOW_SHARP_BLUR_ITERATIONS)
	var shadow_soft_img: Image = shadow_raw.duplicate() as Image
	_dilate_alpha(shadow_soft_img, CollectibleBakeConfig.SHADOW_SOFT_DILATE_ITERATIONS)
	_blur_alpha(shadow_soft_img, CollectibleBakeConfig.SHADOW_SOFT_BLUR_ITERATIONS)

	var color_path := "%sframe_%02d_color.png" % [OUT_DIR, index]
	var normal_path := "%sframe_%02d_normal.png" % [OUT_DIR, index]
	var shadow_sharp_path := "%sframe_%02d_shadow_sharp.png" % [OUT_DIR, index]
	var shadow_soft_path := "%sframe_%02d_shadow_soft.png" % [OUT_DIR, index]
	color_img.save_png(color_path)
	normal_img.save_png(normal_path)
	shadow_sharp_img.save_png(shadow_sharp_path)
	shadow_soft_img.save_png(shadow_soft_path)
	print("  frame %2d (yaw=%.1f deg) -> %s / %s / %s / %s" % [index, object_yaw_deg, color_path.get_file(), normal_path.get_file(), shadow_sharp_path.get_file(), shadow_soft_path.get_file()])


func _render_pass(object_yaw_deg: float, pass_type: PassType) -> Image:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(MODEL_PATH, state)
	if err != OK:
		push_error("actor_frame_bake_spike: failed to load model (error %d)" % err)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var model_root: Node = doc.generate_scene(state)

	var is_shadow := pass_type == PassType.SHADOW
	var viewport_size := SHADOW_VIEWPORT_SIZE if is_shadow else VIEWPORT_SIZE

	var sub := SubViewport.new()
	sub.size = viewport_size
	sub.transparent_bg = true
	sub.msaa_3d = Viewport.MSAA_4X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	world_env.environment = env
	sub.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.8
	sub.add_child(light)

	var pivot := Node3D.new()
	sub.add_child(pivot)
	pivot.add_child(model_root)
	model_root.scale = Vector3.ONE * MESH_SCALE

	## Center the model on the pivot's own origin BEFORE rotating it — global_
	## transform is only valid once the node has spent a frame inside the
	## tree (the same lesson actor_part0_spike.gd's tier-4 bug and
	## showcase_panel.gd's first draft both hit). Center on the pivot's
	## local origin so rotating the pivot spins the model in place instead
	## of having it orbit around whatever point its own GLTF origin used.
	await process_frame
	var aabb := _compute_aabb(model_root)
	model_root.position -= aabb.get_center()

	pivot.rotation_degrees.y = object_yaw_deg

	if pass_type == PassType.NORMAL:
		var shader := Shader.new()
		shader.code = NORMAL_BAKE_SHADER_CODE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		for inst in _all_visual_instances(model_root):
			inst.material_override = mat
	elif is_shadow:
		## Plain unshaded white — only the silhouette's alpha coverage matters;
		## color/lighting are irrelevant, FloatingCollectible tints via modulate.
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 1)
		for inst in _all_visual_instances(model_root):
			inst.material_override = mat

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sub.add_child(cam)
	if is_shadow:
		## Straight down — see file header for why a true top-down pass (not
		## the oblique color view, squashed) is what avoids the angle-shear
		## artifact. Up-vector is NOT arbitrary: it's (cos(AZIMUTH_DEG), 0,
		## sin(AZIMUTH_DEG)) — bakes in the same azimuthal rotation the
		## oblique color camera sees, so at runtime FloatingCollectible only
		## needs a plain uniform-ish squash (scale.y *=
		## CollectibleBakeConfig.SHADOW_SQUASH_Y, = sin(ELEVATION_DEG), the
		## game's own iso ratio) with NO further rotation and — this part
		## matters — NO mirror.
		##
		## VERIFIED (2026-07-28) by measuring the actual baked frames: PCA
		## principal-axis angle of each frame's alpha silhouette, color vs.
		## shadow, at 12 yaws spanning a full rotation. Plain squash (no
		## rotation, no mirror) on this up-vector's output gives 4.3° RMS
		## error against the color frame (consistent with PCA noise on the
		## hook-shaped silhouette, not a real offset) — confirming this
		## up-vector alone is correct. An earlier version of
		## FloatingCollectible additionally mirrored the shadow on X,
		## reasoned from an analytic derivation with an undiagnosed sign
		## error; measured the same way, that gave 46° RMS error AND made
		## the shadow spin the opposite direction from the object as it
		## rotates (Director-reported) — the mirror was pure regression,
		## not needed on top of this up-vector.
		var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
		cam.size = SHADOW_ORTHO_SIZE
		cam.look_at_from_position(Vector3(0.0, SHADOW_CAMERA_DISTANCE, 0.0), Vector3.ZERO, Vector3(cos(azim), 0.0, sin(azim)))
	else:
		cam.size = ORTHO_SIZE
		var elev := deg_to_rad(CollectibleBakeConfig.ELEVATION_DEG)
		var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
		var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
		cam.look_at_from_position(dir * CollectibleBakeConfig.CAMERA_DISTANCE, Vector3.ZERO, Vector3.UP)
	cam.current = true

	for _i in range(4):
		await process_frame

	var img := sub.get_texture().get_image()
	sub.queue_free()
	for _i in range(2):
		await process_frame
	return img


func _all_visual_instances(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_visual_instances(child))
	return found


func _compute_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for inst in _all_visual_instances(node):
		var world_box: AABB = inst.global_transform * inst.get_aabb()
		if first:
			result = world_box
			first = false
		else:
			result = result.merge(world_box)
	return result


## COLOR-GRADE-01: brightness lift+gain, HSV saturation boost, then a fixed
## tint blended underneath — see the constants above for the "why". Opaque
## pixels only (alpha gate), so the transparent margin never picks up a tinted
## halo baked into supposedly-empty pixels. Mirrors weapon_frames_bake.gd's
## function of the same name exactly.
func _grade_color_image(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var lifted := Color(
				clampf(c.r * GRADE_BRIGHTNESS_GAIN + GRADE_BLACK_LIFT, 0.0, 1.0),
				clampf(c.g * GRADE_BRIGHTNESS_GAIN + GRADE_BLACK_LIFT, 0.0, 1.0),
				clampf(c.b * GRADE_BRIGHTNESS_GAIN + GRADE_BLACK_LIFT, 0.0, 1.0),
			)
			var saturated := Color.from_hsv(lifted.h, clampf(lifted.s * GRADE_SATURATION_BOOST, 0.0, 1.0), lifted.v)
			var tinted := saturated.lerp(GRADE_TINT_COLOR, GRADE_TINT_STRENGTH)
			img.set_pixel(x, y, Color(tinted.r, tinted.g, tinted.b, c.a))


## Morphological max-filter on the alpha channel only — widens the
## silhouette a little each iteration ("mais gordinha," Director).
func _dilate_alpha(img: Image, iterations: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _iter in range(iterations):
		var src := img.duplicate()
		for y in range(h):
			for x in range(w):
				var max_a := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							max_a = maxf(max_a, src.get_pixel(nx, ny).a)
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, max_a))


## Box blur on the alpha channel only — softens the silhouette's edge
## ("difusa nas bordas," Director) without touching RGB (kept solid white;
## FloatingCollectible tints the whole shape via Sprite2D.modulate).
func _blur_alpha(img: Image, iterations: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _iter in range(iterations):
		var src := img.duplicate()
		for y in range(h):
			for x in range(w):
				var sum_a := 0.0
				var count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							sum_a += src.get_pixel(nx, ny).a
							count += 1
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, sum_a / count))
