## ACTOR_MASTER_PLAN Part 2 (D12 imported-mesh path) — one-off preview render.
##
## Loads each shotgun variant from the Quaternius Ultimate Guns Pack (CC0,
## see ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/
## ATTRIBUTION.txt) through the SAME camera/lighting rig bake_voxel_sprite_3d.gd
## already ships for the grenade, using Godot's runtime GLTFDocument loader
## instead of a voxel-JSON twin — the D12 "imported mesh" path, not yet
## exercised by any script until this one.
##
## Purpose: a real look at each variant at the actual isometric bake angle,
## to pick one before committing to Part 5a (Showcase). Not a production
## tool — one-off, same spirit as bake_voxel_sprite_3d.gd's own header.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/shotgun_preview_spike.gd
extends SceneTree

const MODELS_DIR := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/"
const OUT_DIR := "res://Screenshots/history/"
const MODELS: Array[String] = [
	"Shotgun.glb",
	"Shotgun-ZmPTnh7njL.glb",
	"Shotgun Sawed Off.glb",
	"Shotgun Short Stock.glb",
]

const VIEWPORT_SIZE := Vector2i(480, 480)
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Shotgun variant preview — D12 imported-mesh bake path (%s)" % Time.get_date_string_from_system())
	print("=".repeat(78))

	for filename in MODELS:
		await _render_one(filename)

	print("\n[PREVIEW] Done.\n")
	quit(0)


func _render_one(filename: String) -> void:
	var path := MODELS_DIR + filename
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("shotgun_preview_spike: failed to load %s (error %d)" % [filename, err])
		return

	var scene_root: Node = doc.generate_scene(state)
	if scene_root == null:
		push_error("shotgun_preview_spike: generate_scene returned null for %s" % filename)
		return

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
	sub.transparent_bg = true
	sub.msaa_3d = Viewport.MSAA_8X
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

	sub.add_child(scene_root)

	## global_transform is invalid until the node has been through at least
	## one frame inside the tree (get_global_transform() errors otherwise,
	## which the first model in this batch hit — later ones only "worked" by
	## accident, borrowing frames the previous iteration's own waits produced).
	await process_frame

	## Bounding box from the imported mesh's visual instances — no fixed
	## voxel-grid assumption like bake_voxel_sprite_3d.gd, since this is an
	## arbitrary imported mesh with its own native scale.
	var aabb := _compute_aabb(scene_root)
	var center := aabb.get_center()
	var extent: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if extent <= 0.0:
		extent = 1.0

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = extent * 1.6
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sub.add_child(cam)
	cam.look_at_from_position(center + dir * extent * 3.0, center, Vector3.UP)
	cam.current = true

	for _i in range(6):
		await process_frame

	var img := sub.get_texture().get_image()
	var out_name: String = filename.get_basename().replace(" ", "_").to_lower()
	var out_path := "%sshotgun_preview_%s.png" % [OUT_DIR, out_name]
	img.save_png(out_path)
	print("  %-28s -> %s (bbox size=%s)" % [filename, out_path, aabb.size])

	sub.queue_free()
	for _i in range(3):
		await process_frame


func _compute_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in _all_visual_instances(node):
		var box: AABB = child.get_aabb()
		var xform: Transform3D = child.global_transform
		var world_box: AABB = xform * box
		if first:
			result = world_box
			first = false
		else:
			result = result.merge(world_box)
	return result


func _all_visual_instances(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_visual_instances(child))
	return found
