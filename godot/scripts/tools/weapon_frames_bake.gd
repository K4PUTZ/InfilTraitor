## Weapon collectible bake — WEAPON_MASTER_PLAN Part 1 support (2026-07-29).
##
## Bakes N weapons in one run instead of N copy-pasted spike scripts. This is
## the first, deliberately small step of ACTOR_MASTER_PLAN Part 2b (D15's
## manifest-driven batch tool): a table here, not a JSON manifest, and scoped to
## weapons only. Everything past that — arbitrary object types, per-object
## config files, license bookkeeping — stays unbuilt until something actually
## needs it.
##
## ONE SHARED FRAMING FOR EVERY GUN, which is the point of doing them together.
## The Quaternius pack's models share a coordinate scale (measured 2026-07-29:
## pistol 1.8 native units long, shotgun 4.5, sniper up to 7.3), so a single
## MESH_SCALE/ORTHO_SIZE renders them all at TRUE RELATIVE SIZE — a sniper reads
## long and a pistol reads stubby, instead of every gun being auto-framed to
## fill its canvas and arriving on the bench the same apparent length.
##
## The numbers are chosen so px-per-world-unit matches the already-shipped
## shotgun bake EXACTLY (160/4.0 = 40 = 220/5.5), which is what lets the new
## weapons drop in beside it with the same SPRITE_SCALE, the same outline width
## in texels, and no re-tuning. The canvas is bigger only so the longest sniper
## fits with margin; a centred sprite treats the extra as transparent padding.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/weapon_frames_bake.gd
extends SceneTree

const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")

const MODEL_ROOT := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/"
const OUT_ROOT := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"

## Director's pick, 2026-07-29: one weapon per range band, covering the whole
## ladder from point-blank to long. Add a row to bake another.
const WEAPONS: Array[Dictionary] = [
	{"model": "Pistol.glb", "out": "pistol_frames"},
	{"model": "Revolver.glb", "out": "revolver_frames"},
	{"model": "Submachine Gun.glb", "out": "smg_frames"},
	{"model": "Assault Rifle.glb", "out": "assault_rifle_frames"},
	{"model": "Sniper Rifle.glb", "out": "sniper_rifle_frames"},
]

## Shared framing — see the header for why these are shared rather than
## per-object, and why they are these exact values.
const VIEWPORT_SIZE := Vector2i(220, 220)
const ORTHO_SIZE := 5.5
const MESH_SCALE := 0.5
## Top-down pass at the same px-per-unit as the colour pass (110/5.5 = 20), so
## the runtime shadow_scale_factor is a clean 2.0. A gun seen from directly
## above spans its true length with no foreshortening, and 5.5 units clears even
## the 7.3-unit sniper at MESH_SCALE 0.5.
const SHADOW_VIEWPORT_SIZE := Vector2i(110, 110)
const SHADOW_ORTHO_SIZE := 5.5
const SHADOW_CAMERA_DISTANCE := 12.0

const NORMAL_BAKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
"""

enum PassType { COLOR, NORMAL, SHADOW }

## COLOR-GRADE-01 (Director, 2026-07-30): "as armas estão muito escuras e
## tristes." Measured, not assumed: the Quaternius pack's baked albedo is
## both dark AND nearly hueless — pistol frame_00 measured mean RGB
## (47,46,45)/255, i.e. R≈G≈B. Runtime light/ambient (flat_normal_relight.gdshader)
## can only ever multiply that toward a BRIGHTER GRAY; it cannot inject a hue
## that was never captured. Confirmed by testing that route first (a bench
## light + a higher shader ambient floor) and measuring a ~0.5/255 real
## change on the actual sprite — not the fix.
##
## Grades the BAKED COLOR TEXTURE itself instead, at bake time, once, so
## nothing at runtime has to work around a flat source: brightness lift+gain,
## then an HSV saturation boost (amplifies whatever hue-bias a given model
## already has — the shotgun's frames read slightly warm before grading), then
## a fixed tint blended UNDER the result so a pixel with genuinely zero
## saturation (the pistol, measured above) still ends up with a real hue
## instead of "brighter gray." Applied to the colour pass ONLY — never
## normal_img (real geometry data) or the shadow images (alpha-only
## silhouettes); grading either would corrupt data other systems read as-is.
##
## One shared grade for every gun, same reasoning the file header already
## gives for one shared framing — per-weapon tint variety is a cheap follow-up
## (swap GRADE_TINT_COLOR per WEAPONS row) if more arsenal variety is wanted
## later, not a redesign.
const GRADE_BRIGHTNESS_GAIN := 1.9
const GRADE_BLACK_LIFT := 0.06
const GRADE_SATURATION_BOOST := 1.8
const GRADE_TINT_COLOR := Color(0.4, 0.55, 0.75)  ## cool gunmetal steel-blue
const GRADE_TINT_STRENGTH := 0.22

var _model_path: String = ""
var _out_dir: String = ""


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Weapon frames bake — %d weapons x %d frames (%s)" %
		[WEAPONS.size(), CollectibleBakeConfig.FRAME_COUNT, Time.get_date_string_from_system()])
	print("=".repeat(78))

	for weapon in WEAPONS:
		_model_path = MODEL_ROOT + String(weapon["model"])
		_out_dir = OUT_ROOT + String(weapon["out"]) + "/"
		var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
		if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
			push_error("weapon_frames_bake: could not create %s (error %d)" % [_out_dir, dir_err])
			quit(1)
			return
		print("\n[BAKE] %s -> %s" % [weapon["model"], weapon["out"]])
		for i in range(CollectibleBakeConfig.FRAME_COUNT):
			var angle_deg := (360.0 / CollectibleBakeConfig.FRAME_COUNT) * i
			await _render_frame(i, angle_deg)
		print("[BAKE]   done, %d frames" % CollectibleBakeConfig.FRAME_COUNT)

	print("\n[BAKE] ALL DONE — %d weapons\n" % WEAPONS.size())
	quit(0)


func _render_frame(index: int, object_yaw_deg: float) -> void:
	var color_img := await _render_pass(object_yaw_deg, PassType.COLOR)
	_grade_color_image(color_img)
	var normal_img := await _render_pass(object_yaw_deg, PassType.NORMAL)
	var shadow_raw := await _render_pass(object_yaw_deg, PassType.SHADOW)
	var shadow_sharp_img: Image = shadow_raw.duplicate() as Image
	_dilate_alpha(shadow_sharp_img, CollectibleBakeConfig.SHADOW_SHARP_DILATE_ITERATIONS)
	_blur_alpha(shadow_sharp_img, CollectibleBakeConfig.SHADOW_SHARP_BLUR_ITERATIONS)
	var shadow_soft_img: Image = shadow_raw.duplicate() as Image
	_dilate_alpha(shadow_soft_img, CollectibleBakeConfig.SHADOW_SOFT_DILATE_ITERATIONS)
	_blur_alpha(shadow_soft_img, CollectibleBakeConfig.SHADOW_SOFT_BLUR_ITERATIONS)

	color_img.save_png("%sframe_%02d_color.png" % [_out_dir, index])
	normal_img.save_png("%sframe_%02d_normal.png" % [_out_dir, index])
	shadow_sharp_img.save_png("%sframe_%02d_shadow_sharp.png" % [_out_dir, index])
	shadow_soft_img.save_png("%sframe_%02d_shadow_soft.png" % [_out_dir, index])


func _render_pass(object_yaw_deg: float, pass_type: PassType) -> Image:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(_model_path, state) != OK:
		push_error("weapon_frames_bake: failed to load %s" % _model_path)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var model_root: Node = doc.generate_scene(state)

	var is_shadow := pass_type == PassType.SHADOW
	var sub := SubViewport.new()
	sub.size = SHADOW_VIEWPORT_SIZE if is_shadow else VIEWPORT_SIZE
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

	## Centre on the pivot's own origin BEFORE rotating — global_transform is
	## only valid after a frame in the tree, and centring is what makes the
	## pivot spin the model in place instead of orbiting its GLTF origin.
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
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 1)
		for inst in _all_visual_instances(model_root):
			inst.material_override = mat

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sub.add_child(cam)
	if is_shadow:
		## Up-vector carries the colour camera's own azimuth, so at runtime the
		## shadow needs only a plain squash with no rotation and NO mirror — see
		## actor_frame_bake_spike.gd's shadow comment for the PCA measurement
		## that settled this.
		var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
		cam.size = SHADOW_ORTHO_SIZE
		cam.look_at_from_position(Vector3(0.0, SHADOW_CAMERA_DISTANCE, 0.0), Vector3.ZERO,
			Vector3(cos(azim), 0.0, sin(azim)))
	else:
		cam.size = ORTHO_SIZE
		var elev := deg_to_rad(CollectibleBakeConfig.ELEVATION_DEG)
		var azim2 := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
		var dir := Vector3(sin(azim2) * cos(elev), sin(elev), cos(azim2) * cos(elev))
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
## halo baked into supposedly-empty pixels.
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
