## ACTOR_MASTER_PLAN objects track — grenade COLLECTIBLE bake (2026-07-29).
##
## Copy of actor_frame_bake_spike.gd following that file's own documented
## "to bake a NEW collectible" recipe: only the per-object knob block below
## changes, never the CollectibleBakeConfig-sourced values (frame count, camera
## elevation/azimuth/distance, shadow dilate/blur) — FloatingCollectible's
## light-direction math is derived against that exact camera convention and
## breaks SILENTLY if a bake drifts from it.
##
## Why a second grenade bake instead of reusing grenade_frames/: that folder
## holds the STATIC ground prop's 4 compass frames (N/E/S/W) and GrenadeProp
## still reads them — the thrown-grenade-on-the-ground representation stays,
## the Director wants it for "o agente arremessar as granadas ativamente".
## This one is the spinning pickup: the same model on the collectible's own
## 120-frame + shadow-pass convention, written to its own folder.
##
## This bake is also the evidence for a claim, not just an asset: the shotgun
## was the only object FloatingCollectible had ever displayed, so "the class
## works for any object" was asserted rather than shown. A second, very
## differently-shaped model (small, round, stubby vs. long and thin) going
## through the identical pipeline is what actually tests it.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/grenade_collectible_bake_spike.gd
extends SceneTree

const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")

## --- Per-object knobs: change these when baking a different collectible ---
const MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"
const OUT_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_collectible_frames/"
## Same 160x160 canvas as the shotgun deliberately: OUTLINE_WIDTH_TEXELS is in
## texels of this frame, so a different canvas size would silently change how
## thick the collectible outline (D28) reads on screen.
const VIEWPORT_SIZE := Vector2i(160, 160)
const ORTHO_SIZE := 4.0
## The static grenade bake (grenade_frame_bake_spike.gd) settled on 2.0 against
## the scene's own scale; kept, since it is the same model in the same world.
const MESH_SCALE := 2.0
## Top-down shadow pass. The shotgun needs a GENEROUS ortho here (5.0 against a
## 4.0 color pass) because an elongated object seen from directly above spans
## its full length with no foreshortening to shrink it. A grenade is roughly as
## wide as it is long, so it needs no such headroom — same 4.0 as the color
## pass, which makes shadow_scale_factor a clean 2.0 at the call site.
const SHADOW_VIEWPORT_SIZE := Vector2i(80, 80)
const SHADOW_ORTHO_SIZE := 4.0
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


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Grenade collectible bake — color + normal + shadow, %d frames (%s)" % [CollectibleBakeConfig.FRAME_COUNT, Time.get_date_string_from_system()])
	print("=".repeat(78))

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("grenade_collectible_bake_spike: could not create output dir (error %d)" % dir_err)
		quit(1)
		return

	for i in range(CollectibleBakeConfig.FRAME_COUNT):
		var angle_deg := (360.0 / CollectibleBakeConfig.FRAME_COUNT) * i
		await _render_frame(i, angle_deg)

	print("\n[BAKE] Done — %d frame quads in %s\n" % [CollectibleBakeConfig.FRAME_COUNT, OUT_DIR])
	quit(0)


func _render_frame(index: int, object_yaw_deg: float) -> void:
	var color_img := await _render_pass(object_yaw_deg, PassType.COLOR)
	var normal_img := await _render_pass(object_yaw_deg, PassType.NORMAL)
	## ONE raw top-down render, post-processed TWICE (sharp/soft) — not two
	## separate 3D renders. FloatingCollectible crossfades between these by the
	## object's current bob height.
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
		push_error("grenade_collectible_bake_spike: failed to load model (error %d)" % err)
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

	## Center the model on the pivot's own origin BEFORE rotating it —
	## global_transform is only valid once the node has spent a frame inside the
	## tree. Centering on the pivot's local origin makes the pivot's rotation
	## spin the model in place instead of orbiting whatever point its own GLTF
	## origin happened to use.
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
		## FloatingCollectible tints the whole shape via Sprite2D.modulate.
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 1)
		for inst in _all_visual_instances(model_root):
			inst.material_override = mat

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sub.add_child(cam)
	if is_shadow:
		## Straight down, with the up-vector carrying the SAME azimuthal
		## rotation the oblique color camera sees — so at runtime the shadow
		## needs only a plain squash (SHADOW_SQUASH_Y = sin(ELEVATION_DEG)) with
		## no further rotation and NO mirror. See actor_frame_bake_spike.gd's
		## shadow-pass comment for the PCA measurement that settled this.
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


## Morphological max-filter on the alpha channel only — widens the silhouette a
## little each iteration.
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


## Box blur on the alpha channel only — softens the silhouette's edge without
## touching RGB (kept solid white; FloatingCollectible tints via modulate).
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
