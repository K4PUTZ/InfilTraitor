## ACTOR_MASTER_PLAN D1/D2 prototype v2 (2026-07-21) — one-off bake tool, not
## production tooling yet. Director's proposal: instead of a hand-rolled 2D
## painter's-algorithm rasterizer (bake_grenade_sprite.py, v1 — the "esquisito"
## result), build real BoxMesh cubes in a SubViewport, light them with a real
## Camera3D at the angle that matches the existing flat atom's 2:1 top-face
## ratio (30° elevation solves sin(theta)=TILE_H/TILE_W=0.5), and let the GPU
## depth buffer handle occlusion + MSAA handle edges — both weak points of v1.
##
## Must run WINDOWED (real GPU rasterizer), not --headless (dummy driver,
## confirmed by SCREENSHOT-HOOK-01's own auto_screenshot.py — same
## constraint applies here). Run via:
##   godot --path . --position 4000,4000 --quit-after 30 \
##     --script res://godot/scripts/tools/bake_voxel_sprite_3d.gd
##
## VOXEL_JSON_PATH is NOT checked in (ASSETS/ is gitignored) — regenerate it
## from the CC0 "Free Voxel Weapon Pack" .qb (OpenGameArt) via the scratchpad
## parse_qb.py: json.dump([{'x','y','z','r','g','b'} per solid voxel]).
## Output is raw (untrimmed, oversized canvas) — autocrop + downscale to the
## target sprite size afterward (transparent-margin trim + ~0.25x LANCZOS
## resize got the shipped grenade_bake_x8.png to 38×68px, matching the
## agent's own silhouette scale, agent.gd SILHOUETTE_WIDTH/HEIGHT=44/61).
extends SceneTree

const VOXEL_JSON_PATH := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_voxels.json"
const OUT_PATH := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8_3d.png"
const ANCHOR_OUT_PATH := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8_3d_anchor.json"

const VIEWPORT_SIZE := Vector2i(240, 400)
const ORTHO_SIZE := 26.0          ## world-units of vertical frustum height — generous on purpose, autocropped after
const ELEVATION_DEG := 30.0       ## sin(30deg) = 0.5 = TILE_H/TILE_W (2:1 diamond, matches generate_voxel.py)
const AZIMUTH_DEG := 45.0
const CAMERA_DISTANCE := 40.0
const CUBE_SIZE := 1.0


func _init() -> void:
	var file := FileAccess.open(VOXEL_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("bake_voxel_sprite_3d: could not open %s" % VOXEL_JSON_PATH)
		quit(1)
		return
	var voxels: Array = JSON.parse_string(file.get_as_text())
	file.close()
	if voxels == null or voxels.is_empty():
		push_error("bake_voxel_sprite_3d: no voxels parsed")
		quit(1)
		return

	## Bounding-box center, in voxel-index space — the pivot the camera looks at.
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for v in voxels:
		var p := Vector3(v.x, v.y, v.z)
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	var center := (min_v + max_v) * 0.5

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

	## Soft key light roughly co-located with the camera (near-headlight),
	## on purpose — an off-angle key would darken one visible side face much
	## more than the other, at odds with generate_voxel.py's flat, EQUALLY
	## darkened left/right convention. Kept soft (0.6) since ambient already
	## carries most of the exposure.
	var light := DirectionalLight3D.new()
	light.light_energy = 0.6
	sub.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sub.add_child(cam)
	## look_at() errors with "Node not inside tree" here even after add_child()
	## — look_at_from_position() sets position+orientation atomically instead.
	cam.look_at_from_position(center + dir * CAMERA_DISTANCE, center, Vector3.UP)
	cam.current = true

	for v in voxels:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * CUBE_SIZE
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(v.r / 255.0, v.g / 255.0, v.b / 255.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_inst.material_override = mat
		mesh_inst.position = (Vector3(v.x, v.y, v.z) - center) * CUBE_SIZE
		sub.add_child(mesh_inst)

	## Anchor: base-level (y=0) footprint centroid, projected through the SAME
	## camera — the pixel a Sprite2D should align to the target world point.
	var base_cells: Array = []
	for v in voxels:
		if int(v.y) == 0:
			base_cells.append(v)
	var acx := 0.0
	var acz := 0.0
	for v in base_cells:
		acx += v.x
		acz += v.z
	acx /= base_cells.size()
	acz /= base_cells.size()
	var anchor_world := (Vector3(acx, 0.0, acz) - center) * CUBE_SIZE

	for _i in range(5):
		await process_frame

	var anchor_px: Vector2 = cam.unproject_position(anchor_world)

	var img := sub.get_texture().get_image()
	var save_err := img.save_png(OUT_PATH)
	if save_err != OK:
		push_error("bake_voxel_sprite_3d: save_png failed (%d)" % save_err)
		quit(1)
		return

	var anchor_file := FileAccess.open(ANCHOR_OUT_PATH, FileAccess.WRITE)
	anchor_file.store_string(JSON.stringify({"anchor_px": [anchor_px.x, anchor_px.y], "viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y]}))
	anchor_file.close()

	print("[BAKE-3D] Saved %s (%dx%d), anchor_px=%s" % [OUT_PATH, img.get_width(), img.get_height(), anchor_px])
	quit(0)
