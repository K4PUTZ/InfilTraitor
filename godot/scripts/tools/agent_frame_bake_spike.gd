## CHARACTER_MASTER_PLAN Part 2 — bake the posed agent for placement in the room.
##
## A sibling of grenade_frame_bake_spike.gd, copied per that file's own stated
## convention, and it differs from it in exactly two ways. Both differences exist
## because this object is a CHARACTER whose size is a ratified number, not a prop
## whose size is a judgement call.
##
## 1. MESH_SCALE IS 1.0 AND ORTHO_SIZE IS DERIVED, NOT TUNED.
##    Every other bake in this project carries the comment "first-guess world
##    scale, visually tuned, not derived from a formula" — correct for a grenade,
##    and disqualifying here: the whole point of putting the agent in the scene is
##    to judge his PROPORTIONS, and a scale tuned by eye would make that judgement
##    circular. §4.7 fixes 1 voxel at 0.20 m (the figure ships at 2.00 m = 10.0
##    voxels, the Director's 2026-08-16 call — see p2_grip_spike.py's
##    scale_to_target_height for what that costs), and QUICK_REFERENCE fixes
##    VOXEL_STEP_PX at 20, so the frame's pixels-per-metre
##    is pinned at 20 / (0.20 * cos 30) = 115.47 and nothing else reproduces the
##    game's size. The source GLB is authored in real metres, so MESH_SCALE is
##    1.0 and ORTHO_SIZE follows from the viewport. The bake then MEASURES the
##    rendered figure and fails loudly if it missed.
##
## 2. RECENTRED IN Y ONLY, NOT ON THE FULL AABB.
##    The grenade recentres on its whole AABB, which puts the AABB bottom-centre
##    on the yaw axis and makes one anchor valid for all four frames. That works
##    because a grenade is symmetric. This figure HOLDS A SHOTGUN sticking 0.6 m
##    forward, so its AABB centre is not its footprint centre, and recentring on
##    X/Z too would stand him off his own tile by the length of the weapon.
##    Shifting in Y alone keeps the figure's own vertical axis on the yaw axis —
##    still rotation-invariant, still one anchor — while the ground point stays
##    where the model was authored: under the FEET. The exported GLB's origin is
##    that point (p1_agent_model.py loud-fails if the figure does not stand on
##    z=0), which is why no measurement is needed to find it.
##
## Source: tools/asset_generation/p2_grip_spike.py with P2_EXPORT_GLB, so what
## gets baked is the same pose the Director judged on the grip matrix, not a
## second pose that merely resembles it.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/agent_frame_bake_spike.gd
extends SceneTree

## Overridable so ONE script bakes every variant of the suit bracket — the
## alternative is a copied file per value, which is how two bakes drift apart.
##   AGENT_BAKE_MODEL=<res://...glb> AGENT_BAKE_OUT=<res://.../dir/> godot ...
const DEFAULT_MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_posed_shotgun_ready.glb"
const DEFAULT_OUT_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"


static func model_path() -> String:
	var env := OS.get_environment("AGENT_BAKE_MODEL")
	return env if env != "" else DEFAULT_MODEL_PATH


static func out_dir() -> String:
	var env := OS.get_environment("AGENT_BAKE_OUT")
	return env if env != "" else DEFAULT_OUT_DIR


## What the source GLB must measure. Overridable because Part 3 bakes THREE
## postures and only standing is 2.00 m — crouch ships at 1.22 m and prone at
## 0.57 m, both measured and gated at export time by p3_posture_export.py.
##
## It stays a hard gate rather than becoming "whatever the model happens to be":
## its job is to catch a source that lost its scale, and a gate that adopts the
## value it is checking would catch nothing. The caller states the height it
## expects and the bake refuses anything else.
static func figure_height_m() -> float:
	var env := OS.get_environment("AGENT_BAKE_HEIGHT_M")
	return float(env) if env != "" else FIGURE_HEIGHT_M

## Same convention as grenade_frame_bake_spike.gd: one render per ROOM
## perspective, matching PerspectiveMapper's own angle deltas, so the frame shown
## for an active perspective matches how the rest of the scene visually rotated.
const DIRECTIONS := ["N", "E", "S", "W"]
const YAW_BY_DIRECTION := {"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}

const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0
const CAMERA_DISTANCE := 12.0

## --- The derived scale chain. See note 1 in the header. ---
const VOXEL_M := 0.20
const VOXEL_STEP_PX := 20.0
const FIGURE_HEIGHT_M := 2.00
const VIEWPORT_SIZE := Vector2i(256, 256)
const MESH_SCALE := 1.0
## Fails the bake if a 0.20 m rise does not draw as VOXEL_STEP_PX. A quarter of a
## pixel is projection round-off, not slack.
const SCALE_TOLERANCE_PX := 0.25
## Share of opaque pixels allowed to clip to pure white. Earned: the broken bake
## measured 53.3%, and a correct flat pass of this palette peaks at the 0.90
## sock, which lands nowhere near 255.
const MAX_WHITE_FRACTION := 0.10

const NORMAL_BAKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
"""


static func px_per_screen_m() -> float:
	return VOXEL_STEP_PX / (VOXEL_M * cos(deg_to_rad(ELEVATION_DEG)))


static func ortho_size() -> float:
	return float(VIEWPORT_SIZE.y) / px_per_screen_m()


## What the figure MUST measure in the baked frame: its world height foreshortened
## by the camera's elevation, at the pinned pixel scale.
static func expected_height_px() -> float:
	return figure_height_m() * cos(deg_to_rad(ELEVATION_DEG)) * px_per_screen_m()


## The entry currently being baked. Set per model in the manifest loop; the
## single-model path fills it from the environment. It exists because
## `figure_height_m()` used to be the only source and a static env read cannot
## describe a SEQUENCE, where every phase has its own measured height.
var _model_path: String = ""
var _out_dir: String = ""
var _height_m: float = 0.0


func expected_height_px_for(height_m: float) -> float:
	return height_m * cos(deg_to_rad(ELEVATION_DEG)) * px_per_screen_m()


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("Agent frame bake — %d perspectives, DERIVED scale (%s)" % [DIRECTIONS.size(), Time.get_date_string_from_system()])
	print("=".repeat(78))
	print("  %.2f px per screen-metre -> ortho %.4f over %d px; a %.2f m voxel draws %.1f px" % [
		px_per_screen_m(), ortho_size(), VIEWPORT_SIZE.y, VOXEL_M,
		VOXEL_M * cos(deg_to_rad(ELEVATION_DEG)) * px_per_screen_m()])

	## AGENT_BAKE_MANIFEST=<path to a p3_*_export.py manifest.json> bakes a whole
	## SEQUENCE in ONE boot. The walk cycle is 8 phases and the single-model path
	## would have cost 8 windowed Godot boots for work that shares a camera, a
	## viewport and a scale chain. Each entry carries its own `out_dir` and its
	## own MEASURED `height_m`, which is the only way the height gate survives a
	## sequence: a walk bobs, so the phases are 9.72 to 10.02 voxels and a single
	## expected height would reject most of them.
	var manifest_path := OS.get_environment("AGENT_BAKE_MANIFEST")
	var jobs: Array = []
	if manifest_path != "":
		jobs = _load_manifest(manifest_path)
		if jobs.is_empty():
			quit(1)
			return
	else:
		jobs = [{"glb": model_path(), "out": out_dir(), "height": figure_height_m()}]

	var ok_count := 0
	for job: Dictionary in jobs:
		var ok := await _bake_one(String(job["glb"]), String(job["out"]), float(job["height"]))
		if not ok:
			quit(1)
			return
		ok_count += 1

	print("\n[AgentBake] Done — %d model(s) x %d perspectives\n" % [ok_count, DIRECTIONS.size()])
	quit(0)


## Reads the `postures` array every p3_*_export.py manifest writes: `glb` is
## repo-relative, `out_dir` is a res:// path, `height_m` was measured off the
## exported file. Loud-fails on a missing key rather than defaulting one, because
## a defaulted height is a gate that passes everything.
func _load_manifest(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[AgentBake] manifest %s is missing or empty" % path)
		return []
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("postures"):
		push_error("[AgentBake] %s is not a p3 export manifest (no `postures`)" % path)
		return []
	var jobs: Array = []
	for entry in parsed["postures"]:
		for required in ["glb", "out_dir", "height_m"]:
			if not entry.has(required):
				push_error("[AgentBake] manifest entry %s has no `%s`" % [entry, required])
				return []
		jobs.append({
			"glb": "res://" + String(entry["glb"]),
			"out": String(entry["out_dir"]),
			"height": float(entry["height_m"]),
		})
	print("  manifest: %d model(s) from %s" % [jobs.size(), path])
	return jobs


func _bake_one(glb: String, out: String, height_m: float) -> bool:
	_model_path = glb
	_out_dir = out
	_height_m = height_m
	## The figure's vertical REACH — how many pixels of height it occludes, which
	## is §4.7's 196 px number. NOT the silhouette's pixel height, which is larger
	## because the body's depth projects into screen-Y too. See _render_direction.
	print("\n  %s -> %s (%.3f m, occludes %.1f px of vertical)" % [
		glb.get_file(), out, height_m, expected_height_px_for(height_m)])

	if not ResourceLoader.exists(glb) and not FileAccess.file_exists(glb):
		push_error("[AgentBake] posed model missing: %s — run the matching p3_*_export.py first" % glb)
		return false

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("[AgentBake] could not create output dir (error %d)" % dir_err)
		return false

	var anchor_px: Vector2 = await _compute_anchor_px()
	if anchor_px == Vector2.ZERO:
		return false

	for direction in DIRECTIONS:
		var ok := await _render_direction(direction, YAW_BY_DIRECTION[direction])
		if not ok:
			return false

	var anchor_file := FileAccess.open((out + "anchor.json"), FileAccess.WRITE)
	anchor_file.store_string(JSON.stringify({
		"anchor_px": [anchor_px.x, anchor_px.y],
		"viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"px_per_screen_m": px_per_screen_m(),
		"expected_height_px": expected_height_px_for(height_m),
	}))
	anchor_file.close()
	print("    anchor_px=%s" % anchor_px)
	return true


func _render_direction(direction: String, object_yaw_deg: float) -> bool:
	var color_img := await _render_pass(object_yaw_deg, false)
	var normal_img := await _render_pass(object_yaw_deg, true)

	## The frame is checked for EMPTY and for CROPPED, and its silhouette is
	## reported. It is deliberately NOT checked against the figure's height x
	## cos(elevation): an isometric silhouette is TALLER than that, because the
	## body's own depth projects into screen-Y as well. That comparison was tried
	## first and failed every frame at 205 px against a 189.8 px "ideal" — the
	## second time the same mistake was made in one day (p2_grip_spike.py made it
	## first, at 207 px). An analytic expectation that models less than the render
	## does will keep reporting false failures. Scale is gated where it can be
	## gated exactly, in _compute_anchor_px: a 0.20 m rise must draw 20 px.
	var used := color_img.get_used_rect()
	if used.size.y <= 0 or used.size.x <= 0:
		push_error("[AgentBake] direction %s rendered an EMPTY frame" % direction)
		return false
	if used.position.x <= 0 or used.position.y <= 0 \
			or used.end.x >= VIEWPORT_SIZE.x or used.end.y >= VIEWPORT_SIZE.y:
		push_error("[AgentBake] direction %s is CROPPED (used rect %s in %s)" % [direction, used, VIEWPORT_SIZE])
		return false

	## THE ALBEDO GATE. The first bake of this figure was 53% pure white and
	## looked entirely plausible until it was measured — the palette had never
	## left Blender (p2_grip_spike.py::materialise_for_export) and the pass was
	## not actually flat. D31's lesson is that no runtime light can recover a
	## colour that was never captured, so a blown-out albedo has to fail HERE,
	## where it is cheap, rather than on screen, where it reads as "the lighting
	## looks wrong". The white shirt and sock are the brightest things in the
	## costume at 0.86/0.90 albedo, so a truly flat pass cannot legitimately clip.
	var stats := _albedo_stats(color_img)
	var white_fraction: float = stats["white_fraction"]
	print("  %s (yaw=%.1f) -> silhouette %dx%d at (%d,%d) | albedo mean %s, %.1f%% pure white" % [
		direction, object_yaw_deg, used.size.x, used.size.y, used.position.x, used.position.y,
		stats["mean"], white_fraction * 100.0])
	if white_fraction > MAX_WHITE_FRACTION:
		push_error("[AgentBake] direction %s is BLOWN OUT — %.1f%% of opaque pixels are pure white (ceiling %.1f%%). The colour pass is not flat albedo, or the model exported without its materials." % [
			direction, white_fraction * 100.0, MAX_WHITE_FRACTION * 100.0])
		return false

	var color_path := "%sframe_%s_color.png" % [_out_dir, direction]
	var normal_path := "%sframe_%s_normal.png" % [_out_dir, direction]
	color_img.save_png(color_path)
	normal_img.save_png(normal_path)
	return true


## Mean opaque colour and the share of opaque pixels that have clipped to white.
func _albedo_stats(img: Image) -> Dictionary:
	var total := Vector3.ZERO
	var opaque := 0
	var white := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.78:
				continue
			opaque += 1
			total += Vector3(c.r, c.g, c.b)
			if c.r >= 0.98 and c.g >= 0.98 and c.b >= 0.98:
				white += 1
	if opaque == 0:
		return {"mean": Vector3i.ZERO, "white_fraction": 0.0}
	var mean := total / float(opaque)
	return {
		"mean": Vector3i(int(mean.x * 255.0), int(mean.y * 255.0), int(mean.z * 255.0)),
		"white_fraction": float(white) / float(opaque),
	}


## Ground-contact anchor. Y-only recentring (header note 2) puts the model's own
## origin — authored under the feet — on the pivot's yaw axis, so one projection
## is valid for all four directions and the weapon cannot pull it sideways.
func _compute_anchor_px() -> Vector2:
	var model_root := _load_model()
	if model_root == null:
		return Vector2.ZERO

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
	root.add_child(sub)

	var pivot := Node3D.new()
	sub.add_child(pivot)
	pivot.add_child(model_root)
	model_root.scale = Vector3.ONE * MESH_SCALE

	await process_frame
	var aabb := _compute_aabb(model_root)
	if abs(aabb.size.y - _height_m) > 0.05:
		push_error("[AgentBake] the model is %.3f m tall, expected %.3f — this is not the posed agent, or the export lost its scale" % [aabb.size.y, _height_m])
		sub.queue_free()
		return Vector2.ZERO
	if abs(aabb.position.y) > 0.03:
		push_error("[AgentBake] the model does not stand on its own origin (feet at y=%.3f) — the Y-only recentring assumes it does" % aabb.position.y)
		sub.queue_free()
		return Vector2.ZERO

	model_root.position.y -= aabb.get_center().y

	var cam := _make_camera(sub)
	for _i in range(3):
		await process_frame

	## The feet, after the Y shift, sit here — and it is on the yaw axis.
	var feet := Vector3(0.0, -aabb.get_center().y, 0.0)
	var anchor_px: Vector2 = cam.unproject_position(feet)

	## THE SCALE GATE, measured through the real camera on a known length rather
	## than inferred from a silhouette: one voxel of world HEIGHT must draw
	## exactly VOXEL_STEP_PX. This is the game's own constant, so if it holds the
	## bake is at the game's size by construction, whatever shape the figure is.
	var one_voxel_up: Vector2 = cam.unproject_position(feet + Vector3(0.0, VOXEL_M, 0.0))
	var drawn_px: float = absf(anchor_px.y - one_voxel_up.y)
	print("  scale check: a %.2f m rise draws %.3f px (VOXEL_STEP_PX is %.1f)" % [VOXEL_M, drawn_px, VOXEL_STEP_PX])
	if absf(drawn_px - VOXEL_STEP_PX) > SCALE_TOLERANCE_PX:
		push_error("[AgentBake] a %.2f m rise draws %.3f px, the game draws it %.1f — the bake is NOT at the game's scale" % [
			VOXEL_M, drawn_px, VOXEL_STEP_PX])
		sub.queue_free()
		return Vector2.ZERO

	sub.queue_free()
	for _i in range(2):
		await process_frame
	return anchor_px


func _render_pass(object_yaw_deg: float, normal_pass: bool) -> Image:
	var model_root := _load_model()
	if model_root == null:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
	sub.transparent_bg = true
	sub.msaa_3d = Viewport.MSAA_4X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)

	## TRULY FLAT, and that is a departure from the sibling bakes worth stating.
	## They pair ambient 0.9 with a DirectionalLight3D at 0.8 while their own
	## headers describe the colour pass as "flat, unlit [...] intentionally not
	## baking any directional light in" — harmless on a dark grenade, and not on
	## this figure, whose shirt albedo is 0.86: the first agent bake measured mean
	## RGB (234,233,233) with 53% of opaque pixels PURE WHITE. §4.8 is explicit
	## that the runtime shader applies the lighting, so anything baked in here is
	## lighting applied twice and albedo that can no longer be recovered.
	## Ambient exactly 1.0 and no directional light means the frame IS the albedo.
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	world_env.environment = env
	sub.add_child(world_env)

	var pivot := Node3D.new()
	sub.add_child(pivot)
	pivot.add_child(model_root)
	model_root.scale = Vector3.ONE * MESH_SCALE

	## global_transform/AABB are invalid for one frame after parenting — the
	## pitfall that bit actor_part0_spike, showcase_panel and
	## actor_frame_bake_spike in turn.
	await process_frame
	var aabb := _compute_aabb(model_root)
	model_root.position.y -= aabb.get_center().y

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


func _load_model() -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_model_path, state)
	if err != OK:
		push_error("[AgentBake] failed to load %s (error %d)" % [_model_path, err])
		return null
	return doc.generate_scene(state)


func _make_camera(sub: SubViewport) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_size()
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
