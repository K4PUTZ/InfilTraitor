## ACTOR_MASTER_PLAN objects track — grenade re-bake (2026-07-28), replacing
## TestZoneController's old single-angle grenade_bake_x8.png (bake_voxel_
## sprite_3d.gd, a hand-placed BoxMesh voxel reconstruction of a CC0 .qb) with
## the SAME real-3D-model + dual color/normal-map technique proven for the
## shotgun (actor_frame_bake_spike.gd). Unlike the shotgun's FloatingCollectible
## (a spinning pickup, 24 frames), the grenade is a STATIC ground prop — it
## never spins on its own, but the game's N/E/S/W perspective toggle visually
## rotates the whole scene, so it still needs one real render per compass
## direction (4 frames, not 24) to look correct from every perspective instead
## of showing a frozen single angle regardless of view (D22 finding, same root
## cause the FloatingCollectible perspective fix addressed).
##
## Ground-anchor technique borrowed from bake_voxel_sprite_3d.gd: the pivot
## recenters the mesh so its AABB center sits at the pivot's local origin,
## which means the AABB's bottom-center (the ground-contact point) always
## lands exactly on the pivot's own Y (vertical) rotation axis — invariant
## under yaw, so one cam.unproject_position() call gives an anchor pixel valid
## for all 4 frames.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/grenade_frame_bake_spike.gd
extends SceneTree

const MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"
const OUT_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/"
const ANCHOR_OUT_PATH := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/anchor.json"

## direction -> object yaw, matching PerspectiveMapper.perspective_angle_delta_deg
## exactly (room.gd/floating_collectible.gd's own convention) so the frame
## picked for a given active perspective always matches how the rest of the
## scene visually rotated for that same perspective.
const DIRECTIONS := ["N", "E", "S", "W"]
const YAW_BY_DIRECTION := {"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}

const VIEWPORT_SIZE := Vector2i(96, 96)
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0
const CAMERA_DISTANCE := 12.0
const ORTHO_SIZE := 2.0
## First-guess world scale, same visual-judgment-call convention as
## actor_frame_bake_spike.gd's MESH_SCALE — tuned against the shotgun's own
## in-scene size, not derived from a formula.
const MESH_SCALE := 2.0

const NORMAL_BAKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
"""


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Grenade frame bake spike — flat color + normal map, %d directions (%s)" % [DIRECTIONS.size(), Time.get_date_string_from_system()])
	print("=".repeat(78))

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("grenade_frame_bake_spike: could not create output dir (error %d)" % dir_err)
		quit(1)
		return

	var anchor_px: Vector2 = await _compute_anchor_px()

	for direction in DIRECTIONS:
		await _render_direction(direction, YAW_BY_DIRECTION[direction])

	var anchor_file := FileAccess.open(ANCHOR_OUT_PATH, FileAccess.WRITE)
	anchor_file.store_string(JSON.stringify({
		"anchor_px": [anchor_px.x, anchor_px.y],
		"viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
	}))
	anchor_file.close()

	print("\n[BAKE] Done — %d direction pairs in %s, anchor_px=%s\n" % [DIRECTIONS.size(), OUT_DIR, anchor_px])
	quit(0)


func _render_direction(direction: String, object_yaw_deg: float) -> void:
	var color_img := await _render_pass(object_yaw_deg, false)
	var normal_img := await _render_pass(object_yaw_deg, true)

	var color_path := "%sframe_%s_color.png" % [OUT_DIR, direction]
	var normal_path := "%sframe_%s_normal.png" % [OUT_DIR, direction]
	color_img.save_png(color_path)
	normal_img.save_png(normal_path)
	print("  direction %s (yaw=%.1f deg) -> %s / %s" % [direction, object_yaw_deg, color_path.get_file(), normal_path.get_file()])


## Ground-contact anchor (world Y=aabb-bottom, X/Z=aabb-center), projected
## through the same fixed camera used for every frame. Rotation-invariant
## (see file header) so this is computed once, at yaw=0, and reused for all
## 4 directions.
func _compute_anchor_px() -> Vector2:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(MODEL_PATH, state)
	if err != OK:
		push_error("grenade_frame_bake_spike: failed to load model for anchor pass (error %d)" % err)
		return Vector2.ZERO
	var model_root: Node = doc.generate_scene(state)

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
	root.add_child(sub)

	var pivot := Node3D.new()
	sub.add_child(pivot)
	pivot.add_child(model_root)
	model_root.scale = Vector3.ONE * MESH_SCALE

	await process_frame
	var aabb := _compute_aabb(model_root)
	var half_height := aabb.size.y * 0.5
	model_root.position -= aabb.get_center()

	var cam := _make_camera(sub)
	for _i in range(3):
		await process_frame

	var anchor_px: Vector2 = cam.unproject_position(Vector3(0.0, -half_height, 0.0))
	sub.queue_free()
	for _i in range(2):
		await process_frame
	return anchor_px


func _render_pass(object_yaw_deg: float, normal_pass: bool) -> Image:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(MODEL_PATH, state)
	if err != OK:
		push_error("grenade_frame_bake_spike: failed to load model (error %d)" % err)
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

	## Center on the pivot's own origin BEFORE rotating (actor_frame_bake_
	## spike.gd's lesson) — global_transform only valid once the node has
	## spent a frame inside the tree.
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

	var cam := _make_camera(sub)

	for _i in range(4):
		await process_frame

	var img := sub.get_texture().get_image()
	sub.queue_free()
	for _i in range(2):
		await process_frame
	return img


func _make_camera(sub: SubViewport) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sub.add_child(cam)
	cam.look_at_from_position(dir * CAMERA_DISTANCE, Vector3.ZERO, Vector3.UP)
	cam.current = true
	return cam


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
