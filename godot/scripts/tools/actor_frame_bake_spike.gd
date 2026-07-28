## ACTOR_MASTER_PLAN D17/D21/D14 — flat-3D + normal-map bake TEMPLATE for a
## FloatingCollectible. Renders N rotation frames of an imported mesh (D12's
## path, proven by shotgun_preview_spike.gd) from the SAME fixed isometric
## camera the rest of the game uses — the OBJECT rotates around its own
## vertical axis between frames, the camera never moves, matching how a
## spinning collectible would actually be seen by the game's one fixed view.
## Each frame gets TWO renders: a flat, unlit color pass (today's D13-style
## ambient-only look, intentionally not baking any directional light in) and
## a normal-map pass (view-space surface normal encoded as RGB, the standard
## normal-bake technique) — the pair a runtime CanvasItem shader needs to
## relight the flat sprite per-pixel against whatever the world's real light
## data says for that GU, without any voxel geometry at runtime.
##
## STANDARDIZED (Director, 2026-07-28): this was the shotgun's own bake
## script; frame count, rotation speed, and the fixed bake-camera convention
## now live in CollectibleBakeConfig (godot/scripts/systems/
## collectible_bake_config.gd) so every future collectible reuses the same
## tuned sweet spot instead of re-deriving it — see that file for the
## frame-swap-rate reasoning. To bake a NEW collectible: copy this file,
## change MODEL_PATH/OUT_DIR and re-tune the per-object knobs below
## (MESH_SCALE/VIEWPORT_SIZE/ORTHO_SIZE — always a visual judgment call, same
## convention MESH_SCALE always has been); never touch the CollectibleBake
## Config-sourced values.
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
## --- End per-object knobs ---

const NORMAL_BAKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
"""


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Actor frame bake spike — flat color + normal map, %d frames (%s)" % [CollectibleBakeConfig.FRAME_COUNT, Time.get_date_string_from_system()])
	print("=".repeat(78))

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("actor_frame_bake_spike: could not create output dir (error %d)" % dir_err)
		quit(1)
		return

	for i in range(CollectibleBakeConfig.FRAME_COUNT):
		var angle_deg := (360.0 / CollectibleBakeConfig.FRAME_COUNT) * i
		await _render_frame(i, angle_deg)

	print("\n[BAKE] Done — %d frame pairs in %s\n" % [CollectibleBakeConfig.FRAME_COUNT, OUT_DIR])
	quit(0)


func _render_frame(index: int, object_yaw_deg: float) -> void:
	var color_img := await _render_pass(object_yaw_deg, false)
	var normal_img := await _render_pass(object_yaw_deg, true)

	var color_path := "%sframe_%02d_color.png" % [OUT_DIR, index]
	var normal_path := "%sframe_%02d_normal.png" % [OUT_DIR, index]
	color_img.save_png(color_path)
	normal_img.save_png(normal_path)
	print("  frame %2d (yaw=%.1f deg) -> %s / %s" % [index, object_yaw_deg, color_path.get_file(), normal_path.get_file()])


func _render_pass(object_yaw_deg: float, normal_pass: bool) -> Image:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(MODEL_PATH, state)
	if err != OK:
		push_error("actor_frame_bake_spike: failed to load model (error %d)" % err)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var model_root: Node = doc.generate_scene(state)

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
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

	if normal_pass:
		var shader := Shader.new()
		shader.code = NORMAL_BAKE_SHADER_CODE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		for inst in _all_visual_instances(model_root):
			inst.material_override = mat

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	var elev := deg_to_rad(CollectibleBakeConfig.ELEVATION_DEG)
	var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sub.add_child(cam)
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
