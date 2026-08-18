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

## LAYER MODE. A layer (the head, the fedora) is rendered from this same camera
## into this same frame, but it must NOT be recentred on its own AABB: a head
## centred on itself lands in the middle of the frame instead of on the neck it
## belongs to. It inherits the BODY's Y shift instead, which is what makes the two
## PNGs register pixel for pixel with no offset to tune.
##
## INF means "recentre on my own AABB", i.e. the body path, unchanged.
const NO_RECENTRE_OVERRIDE := INF
var _recentre_y_override: float = NO_RECENTRE_OVERRIDE

## Where the head attaches: the TOP CENTRE of `seg_neck`, projected through the
## bake camera. It is measured off the body (the neck stays on the body when the
## head lifts off) and published per direction, so one head image set can serve
## any pose that MOVES the head without moving the head art — the crouch lowers
## it, the walk bobs it. Without this, sharing a head set across poses would be an
## approximation; with it, it is exact.
const NECK_MESH_NAME := "seg_neck"
const HEAD_MESH_NAME := "seg_head"

## The full circle at 15 degrees. NOT the +-60 sweep: the sweep is per FACING,
## and the union of the four facings' sweeps is the whole circle, so 24 is the
## number of distinct images and 9 was never a frame count.
const DEFAULT_LAYER_YAWS := 24
## The socket is reported PER DIRECTION and compared per direction, never
## collapsed to one point.
##
## AN EARLIER VERSION OF THIS FILE GATED ON THE FOUR AGREEING, on the theory that
## the neck sits on the figure's yaw axis so rotating the body cannot move its
## projection. Standing measures 0.000 px of spread and looks like proof. THE
## CROUCH MEASURES 17 px: it leans forward, so the neck top is off the axis and
## orbits as the body turns. The gate would have rejected a crouch layer that is
## in fact perfectly registerable — and, worse, the single-point version of the
## delta it was defending would have placed the crouched head up to 17 px off.
##
## What actually makes a layer registerable is weaker and always true: the layer
## GLB is rotated about the SAME axis by the SAME angle as the body, so at equal
## yaw the head lands exactly where the body left the neck, on or off the axis.
## The socket only earns its keep when a set is SHARED with a pose that moves the
## head — the walk's bob — and there a per-direction delta is the correct one.


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
	var layer_jobs: Array = []
	var verify: Array = []
	if manifest_path != "":
		var loaded := _load_manifest(manifest_path)
		if loaded.is_empty():
			quit(1)
			return
		jobs = loaded["postures"]
		layer_jobs = loaded["layers"]
		verify = loaded["verify"]
	elif OS.get_environment("AGENT_BAKE_LAYER") != "":
		var yaws_env := OS.get_environment("AGENT_BAKE_LAYER_YAWS")
		layer_jobs = [{
			"layer": OS.get_environment("AGENT_BAKE_LAYER"),
			"glb": model_path(), "out": out_dir(),
			"base_dir": OS.get_environment("AGENT_BAKE_LAYER_BASE"),
			"yaws": int(yaws_env) if yaws_env.is_valid_int() else DEFAULT_LAYER_YAWS,
		}]
	else:
		jobs = [{"glb": model_path(), "out": out_dir(), "height": figure_height_m()}]

	var ok_count := 0
	for job: Dictionary in jobs:
		var ok := await _bake_one(String(job["glb"]), String(job["out"]), float(job["height"]))
		if not ok:
			quit(1)
			return
		ok_count += 1

	## Layers come AFTER the bodies, and the order is load-bearing rather than
	## tidy: a layer inherits the body's Y shift and its socket, both read back
	## out of the body's own anchor.json. Bake them the other way round and the
	## layer registers against the PREVIOUS body — which, on a re-bake, is the
	## one that still had a head.
	var layer_count := 0
	for job: Dictionary in layer_jobs:
		var ok := await _bake_layer(String(job["layer"]), String(job["glb"]),
			String(job["out"]), String(job["base_dir"]), int(job["yaws"]))
		if not ok:
			quit(1)
			return
		layer_count += 1

	## THE GATE THAT MAKES THE REST MEAN ANYTHING, and it runs automatically in
	## the same boot so it cannot be skipped or forgotten on another machine.
	for entry: Dictionary in verify:
		if not await _verify_layers(String(entry["glb"]), float(entry["height"]),
				String(entry["body_dir"]), entry["layer_dirs"]):
			quit(1)
			return

	print("\n[AgentBake] Done — %d model(s) x %d perspectives, %d layer set(s)\n" % [
		ok_count, DIRECTIONS.size(), layer_count])
	quit(0)


## Reads the `postures` array every p3_*_export.py manifest writes: `glb` is
## repo-relative, `out_dir` is a res:// path, `height_m` was measured off the
## exported file. Loud-fails on a missing key rather than defaulting one, because
## a defaulted height is a gate that passes everything.
func _load_manifest(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[AgentBake] manifest %s is missing or empty" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed.has("postures") or parsed.has("layers")):
		push_error("[AgentBake] %s is not a p3 export manifest (no `postures`, no `layers`)" % path)
		return {}
	var jobs: Array = []
	for entry in parsed.get("postures", []):
		for required in ["glb", "out_dir", "height_m"]:
			if not entry.has(required):
				push_error("[AgentBake] manifest entry %s has no `%s`" % [entry, required])
				return {}
		jobs.append({
			"glb": "res://" + String(entry["glb"]),
			"out": String(entry["out_dir"]),
			"height": float(entry["height_m"]),
		})
	var layers: Array = []
	for entry in parsed.get("layers", []):
		for required in ["layer", "glb", "out_dir", "base_dir"]:
			if not entry.has(required):
				push_error("[AgentBake] layer entry %s has no `%s`" % [entry, required])
				return {}
		layers.append({
			"layer": String(entry["layer"]),
			"glb": "res://" + String(entry["glb"]),
			"out": String(entry["out_dir"]),
			"base_dir": String(entry["base_dir"]),
			"yaws": int(entry.get("yaws", DEFAULT_LAYER_YAWS)),
		})
	var verify: Array = []
	for v in parsed.get("verify", []):
		verify.append({
			"glb": "res://" + String(v["glb"]),
			"height": float(v["height_m"]),
			"body_dir": String(v["body_dir"]),
			"layer_dirs": v["layer_dirs"],
		})
	print("  manifest: %d model(s), %d layer set(s) from %s" % [jobs.size(), layers.size(), path])
	return {"postures": jobs, "layers": layers, "verify": verify}


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

	var measured: Dictionary = await _compute_anchor_px()
	if measured.is_empty():
		return false
	var anchor_px: Vector2 = measured["anchor_px"]

	for direction in DIRECTIONS:
		var ok := await _render_direction(direction, YAW_BY_DIRECTION[direction])
		if not ok:
			return false

	var sockets := {}
	for direction: String in (measured["head_socket_px"] as Dictionary):
		var v: Vector2 = measured["head_socket_px"][direction]
		sockets[direction] = [v.x, v.y]
	var anchor_file := FileAccess.open((out + "anchor.json"), FileAccess.WRITE)
	anchor_file.store_string(JSON.stringify({
		"anchor_px": [anchor_px.x, anchor_px.y],
		"viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"px_per_screen_m": px_per_screen_m(),
		"expected_height_px": expected_height_px_for(height_m),
		## The layer bake reads this back so its frames inherit the BODY's shift.
		"recentre_y_m": measured["recentre_y_m"],
		"head_socket_px": sockets,
		## AgentSprite reads this and nothing else to decide whether to draw the
		## layers at all — so the body and the head can never disagree about which
		## of the two is carrying the skull.
		"headless": measured["headless"],
	}))
	anchor_file.close()
	print("    anchor_px=%s | head socket %s | headless=%s" % [
		anchor_px, measured["head_socket_px"], measured["headless"]])
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
func _compute_anchor_px() -> Dictionary:
	var model_root := _load_model()
	if model_root == null:
		return {}

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
		return {}
	if abs(aabb.position.y) > 0.03:
		push_error("[AgentBake] the model does not stand on its own origin (feet at y=%.3f) — the Y-only recentring assumes it does" % aabb.position.y)
		sub.queue_free()
		return {}

	var recentre_y: float = aabb.get_center().y
	var neck := _find_mesh(model_root, NECK_MESH_NAME)
	if neck == null:
		push_error("[AgentBake] no `%s` in %s — the head socket cannot be measured, and every layer registers against it" % [NECK_MESH_NAME, _model_path])
		sub.queue_free()
		return {}
	var neck_box: AABB = neck.global_transform * neck.get_aabb()
	## The TOP of the neck, on the figure's own vertical axis: where the skull sits.
	var socket_model := Vector3(neck_box.get_center().x, neck_box.end.y - recentre_y,
		neck_box.get_center().z)

	model_root.position.y -= recentre_y

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
		return {}

	## The socket, projected once per direction. It rides the same yaw the frame
	## does, so a pose that swings the head off the axis (a walk's sway) is
	## reported honestly instead of being assumed away.
	var sockets := {}
	for direction: String in DIRECTIONS:
		var rotated: Vector3 = Basis(Vector3.UP, deg_to_rad(YAW_BY_DIRECTION[direction])) * socket_model
		sockets[direction] = cam.unproject_position(rotated)

	var headless := _find_mesh(model_root, HEAD_MESH_NAME) == null
	sub.queue_free()
	for _i in range(2):
		await process_frame
	return {
		"anchor_px": anchor_px, "head_socket_px": sockets,
		"recentre_y_m": recentre_y, "headless": headless,
	}


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
	if is_inf(_recentre_y_override):
		var aabb := _compute_aabb(model_root)
		model_root.position.y -= aabb.get_center().y
	else:
		model_root.position.y -= _recentre_y_override

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


## Bake one yaw-indexed layer: the head, or the fedora.
##
## Three things make this different from a body bake, and all three are why it is
## a separate function rather than a flag on `_bake_one`:
##
## 1. NO HEIGHT GATE, NO FLOOR GATE. A head is 0.19 m tall and floats 1.7 m up;
##    both body gates would reject it for being exactly what it is. The SCALE
##    gate — the one that actually proves the bake is at the game's size — is a
##    property of the camera, was already checked on the body this registers
##    against, and needs no model to re-state it.
## 2. THE BODY'S Y SHIFT, NOT ITS OWN. See `_recentre_y_override`.
## 3. THE FRAMES ARE CROPPED. A head occupies ~4% of a 256x256 frame, and D42
##    names RAM as this character's binding constraint. The crop origin is written
##    per frame, so cropping costs the runtime one vector add and nothing else.
func _bake_layer(layer: String, glb: String, out: String, base_dir: String, yaw_count: int) -> bool:
	_model_path = glb
	_out_dir = out
	print("\n  LAYER '%s': %s -> %s (%d yaws, registered against %s)" % [
		layer, glb.get_file(), out, yaw_count, base_dir])

	if not ResourceLoader.exists(glb) and not FileAccess.file_exists(glb):
		push_error("[AgentBake] layer model missing: %s — run p3_layer_export.py first" % glb)
		return false
	## The sweep closes for ANY count — the step is 360/count by construction. What
	## needs the count to divide 360 is the FILENAME: frames are `yaw_<000..359>`
	## in whole degrees, so a step of 7.5 would round two frames onto one name and
	## silently ship 47 of 48. Say that, rather than the geometry it is not.
	if yaw_count < 4 or 360 % yaw_count != 0:
		push_error("[AgentBake] %d yaws gives a step of %.3f deg, which is not a whole number — the yaw_<deg> filenames would collide. Use a count that divides 360 (24 = 15 deg, 36 = 10 deg, 72 = 5 deg)." % [
			yaw_count, 360.0 / float(yaw_count)])
		return false

	var base_path := base_dir + "anchor.json"
	if not FileAccess.file_exists(base_path):
		push_error("[AgentBake] %s missing — bake the BODY before the layer that registers against it" % base_path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(base_path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("recentre_y_m") or not parsed.has("head_socket_px"):
		push_error("[AgentBake] %s predates the layer system (no `recentre_y_m` / `head_socket_px`) — re-bake that body first" % base_path)
		return false

	var base_sockets := {}
	var mean := Vector2.ZERO
	for direction: String in DIRECTIONS:
		if not (parsed["head_socket_px"] as Dictionary).has(direction):
			push_error("[AgentBake] %s has no head socket for direction %s" % [base_path, direction])
			return false
		var v: Array = parsed["head_socket_px"][direction]
		base_sockets[direction] = [float(v[0]), float(v[1])]
		mean += Vector2(float(v[0]), float(v[1]))
	mean /= float(DIRECTIONS.size())
	var spread := 0.0
	for direction: String in DIRECTIONS:
		var v: Array = base_sockets[direction]
		spread = maxf(spread, Vector2(v[0], v[1]).distance_to(mean))
	## Diagnostic, not a gate — see the note on the constants above. A large
	## spread says the pose leans; it says nothing about whether the layer
	## registers, which the composite check at the end of the run measures.
	print("    base sockets spread %.3f px across the four facings%s" % [
		spread, " (this pose leans)" if spread > 1.0 else " (on the yaw axis)"])

	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("[AgentBake] could not create layer output dir (error %d)" % dir_err)
		return false

	_recentre_y_override = float(parsed["recentre_y_m"])
	var step := 360.0 / float(yaw_count)
	var frames: Array = []
	var total_px := 0
	for i in range(yaw_count):
		var yaw := float(i) * step
		var color_img := await _render_pass(yaw, false)
		var normal_img := await _render_pass(yaw, true)
		var used: Rect2i = color_img.get_used_rect().merge(normal_img.get_used_rect())
		if used.size.x <= 0 or used.size.y <= 0:
			push_error("[AgentBake] layer '%s' yaw %.0f rendered an EMPTY frame" % [layer, yaw])
			_recentre_y_override = NO_RECENTRE_OVERRIDE
			return false
		if used.position.x <= 0 or used.position.y <= 0 \
				or used.end.x >= VIEWPORT_SIZE.x or used.end.y >= VIEWPORT_SIZE.y:
			push_error("[AgentBake] layer '%s' yaw %.0f is CROPPED by the viewport (used rect %s in %s)" % [
				layer, yaw, used, VIEWPORT_SIZE])
			_recentre_y_override = NO_RECENTRE_OVERRIDE
			return false
		var stats := _albedo_stats(color_img)
		if float(stats["white_fraction"]) > MAX_WHITE_FRACTION:
			push_error("[AgentBake] layer '%s' yaw %.0f is BLOWN OUT — %.1f%% pure white (ceiling %.1f%%)" % [
				layer, yaw, float(stats["white_fraction"]) * 100.0, MAX_WHITE_FRACTION * 100.0])
			_recentre_y_override = NO_RECENTRE_OVERRIDE
			return false
		## ONE rect for both passes, and it is their UNION. Cropping them
		## independently would give the colour and the normal different origins,
		## and the relight would then read the normal of a neighbouring pixel —
		## a shading error that looks like a bad bake rather than a bad crop.
		var tag := int(round(fposmod(yaw, 360.0)))
		color_img.get_region(used).save_png("%syaw_%03d_color.png" % [out, tag])
		normal_img.get_region(used).save_png("%syaw_%03d_normal.png" % [out, tag])
		total_px += used.size.x * used.size.y
		frames.append({
			"yaw": yaw,
			"origin_px": [used.position.x, used.position.y],
			"size_px": [used.size.x, used.size.y],
		})
	_recentre_y_override = NO_RECENTRE_OVERRIDE

	var manifest := FileAccess.open(out + "layer.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"layer": layer,
		"yaw_step_deg": step,
		"base_dir": base_dir,
		"base_socket_px": base_sockets,
		"viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"frames": frames,
	}, "\t"))
	manifest.close()
	## MEASURED, so the RAM claim in the header is a number and not a hope.
	var cropped_mb := float(total_px * 2 * 4) / 1048576.0
	var full_mb := float(yaw_count * VIEWPORT_SIZE.x * VIEWPORT_SIZE.y * 2 * 4) / 1048576.0
	print("    %d frames, %.2f MB cropped (%.2f MB uncropped — %.1fx)" % [
		yaw_count, cropped_mb, full_mb, full_mb / maxf(cropped_mb, 0.001)])
	return true


## ============================================================================
## LAYER REGISTRATION GATE
## ============================================================================
## Composite `headless body + head + hat` with EXACTLY the arithmetic AgentSprite
## uses, and compare it against a bake of the whole figure. If the registration is
## wrong on any axis — the Y shift, the crop origin, the socket — the silhouettes
## come apart and this says by how many pixels.
##
## It is the only honest way to claim the layers line up. Two PNGs that look
## aligned in a contact sheet are an impression; this is the measurement, and it
## runs off the same numbers the game reads at runtime rather than off a second
## implementation of them.
##
## A PERFECT ZERO IS NOT EXPECTED and would be suspicious. The reference renders
## head and body in ONE rasteriser pass, so the seam where the skull meets the
## neck is antialiased against its neighbour; the layered version antialiases each
## against transparency and then blends. The error that matters is a SHIFT, which
## shows up as a band down one whole side, not as a fringe.
const VERIFY_CANVAS := Vector2i(512, 512)
## EARNED, not invented. Measured 2026-08-18 on the agent: worst 1.20% (standing
## N, 112 px of 9367), crouch worst 0.88%. The dump proves what those pixels are —
## an even red/blue speckle around the ENTIRE outline, feet and shotgun included,
## with the composite-only and reference-only counts balanced (55 vs 57, 38 vs 38)
## and sharing one x-range. That is two MSAA renders of the same geometry
## disagreeing at the edges, not a layer landing in the wrong place: a shift puts
## red down one side and blue down the other, in disjoint ranges.
##
## 1.5% is that measurement plus a quarter. A one-pixel head shift would add the
## head's own perimeter twice over — roughly 1.5 to 3 points on top — so this
## still separates the two cases by a wide margin. If a family ever exceeds it,
## AGENT_BAKE_VERIFY_DUMP answers "fringe or shift" in one look.
const VERIFY_MAX_MISMATCH_FRACTION := 0.015


func _verify_layers(full_glb: String, height_m: float, body_dir: String,
		layer_dirs: Array) -> bool:
	print("\n  VERIFY: composite vs. whole figure (%s)" % full_glb.get_file())
	if not ResourceLoader.exists(full_glb) and not FileAccess.file_exists(full_glb):
		push_error("[AgentBake] verification model missing: %s" % full_glb)
		return false

	var body_meta := _read_json(body_dir + "anchor.json")
	if body_meta.is_empty():
		return false
	var body_anchor := _json_vec2(body_meta["anchor_px"])

	## Every layer's frames + crop origins + the socket they were baked against.
	var layer_data: Array = []
	for dir_path in layer_dirs:
		var man := _read_json(String(dir_path) + "layer.json")
		if man.is_empty():
			return false
		layer_data.append({"dir": String(dir_path), "manifest": man})

	_model_path = full_glb
	_height_m = height_m
	_recentre_y_override = NO_RECENTRE_OVERRIDE
	var ref_measured: Dictionary = await _compute_anchor_px()
	if ref_measured.is_empty():
		return false
	var ref_anchor: Vector2 = ref_measured["anchor_px"]
	if not bool(ref_measured["headless"]):
		print("    reference carries its head, as it must for this comparison")
	else:
		push_error("[AgentBake] the verification model %s is HEADLESS — there is nothing to compare the layers against" % full_glb)
		return false

	var centre := VERIFY_CANVAS / 2
	var worst_fraction := 0.0
	for direction: String in DIRECTIONS:
		var yaw: float = YAW_BY_DIRECTION[direction]
		var ref_img := await _render_pass(yaw, false)

		var body_img := Image.new()
		if body_img.load(body_dir + "frame_%s_color.png" % direction) != OK:
			push_error("[AgentBake] cannot read %sframe_%s_color.png" % [body_dir, direction])
			return false

		var composite := Image.create(VERIFY_CANVAS.x, VERIFY_CANVAS.y, false, Image.FORMAT_RGBA8)
		var reference := Image.create(VERIFY_CANVAS.x, VERIFY_CANVAS.y, false, Image.FORMAT_RGBA8)
		composite.blend_rect(body_img, Rect2i(Vector2i.ZERO, body_img.get_size()),
			centre - Vector2i(body_anchor.round()))
		reference.blend_rect(ref_img, Rect2i(Vector2i.ZERO, ref_img.get_size()),
			centre - Vector2i(ref_anchor.round()))

		for entry: Dictionary in layer_data:
			var man: Dictionary = entry["manifest"]
			var frames: Array = man["frames"]
			var step := 360.0 / float(frames.size())
			var index: int = int(round(fposmod(yaw, 360.0) / step)) % frames.size()
			var frame: Dictionary = frames[index]
			var layer_img := Image.new()
			var tag: int = int(round(fposmod(float(frame["yaw"]), 360.0)))
			if layer_img.load("%syaw_%03d_color.png" % [entry["dir"], tag]) != OK:
				push_error("[AgentBake] cannot read %syaw_%03d_color.png" % [entry["dir"], tag])
				return false
			## The runtime's own three terms — see AgentSprite._apply_layers.
			var origin := _json_vec2(frame["origin_px"])
			var base_socket := _json_vec2((man["base_socket_px"] as Dictionary)[direction])
			var socket: Vector2 = base_socket
			if (body_meta["head_socket_px"] as Dictionary).has(direction):
				socket = _json_vec2(body_meta["head_socket_px"][direction])
			var place := -body_anchor + origin + (socket - base_socket)
			composite.blend_rect(layer_img, Rect2i(Vector2i.ZERO, layer_img.get_size()),
				centre + Vector2i(place.round()))

		var diff := _compare_silhouettes(composite, reference)
		## AGENT_BAKE_VERIFY_DUMP=<dir> writes what was compared. A percentage
		## alone cannot tell a 1-pixel SHIFT from an antialiased seam — the first
		## is a band down one side, the second a fringe all the way round — and
		## the difference decides whether the bake is wrong or merely rasterised
		## twice. Off by default; one env var when a number needs a face.
		var dump := OS.get_environment("AGENT_BAKE_VERIFY_DUMP")
		if dump != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dump))
			var tag := "%s_%s" % [body_dir.trim_suffix("/").get_file(), direction]
			composite.save_png("%s/%s_composite.png" % [dump, tag])
			reference.save_png("%s/%s_reference.png" % [dump, tag])
			_diff_image(composite, reference).save_png("%s/%s_diff.png" % [dump, tag])
		var fraction: float = float(diff["mismatch"]) / maxf(float(diff["reference_area"]), 1.0)
		worst_fraction = maxf(worst_fraction, fraction)
		print("    %s: reference %d px, silhouette mismatch %d px (%.2f%%), colour mismatch %d px" % [
			direction, diff["reference_area"], diff["mismatch"], fraction * 100.0,
			diff["colour_mismatch"]])

	if worst_fraction > VERIFY_MAX_MISMATCH_FRACTION:
		push_error("[AgentBake] LAYER REGISTRATION FAILED — worst silhouette mismatch %.2f%% (ceiling %.2f%%). The layers do not land on the body they were baked against." % [
			worst_fraction * 100.0, VERIFY_MAX_MISMATCH_FRACTION * 100.0])
		return false
	print("    registration OK — worst %.2f%% of the silhouette" % (worst_fraction * 100.0))
	return true


## Opaque-pixel disagreement between two canvases of the same size.
##
## `mismatch` counts pixels opaque in one and not the other — a SHIFT. It is the
## number that matters: a misregistered layer leaves the body's outline showing on
## one side and paints over it on the other, so a shift of n pixels costs roughly
## 2n times the silhouette's perimeter and cannot hide.
func _compare_silhouettes(a: Image, b: Image) -> Dictionary:
	var mismatch := 0
	var colour_mismatch := 0
	var reference_area := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var oa := ca.a >= 0.5
			var ob := cb.a >= 0.5
			if ob:
				reference_area += 1
			if oa != ob:
				mismatch += 1
			elif oa:
				var delta: float = maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
				if delta > 0.05:
					colour_mismatch += 1
	return {"mismatch": mismatch, "colour_mismatch": colour_mismatch,
		"reference_area": reference_area}


## Red where only the composite is opaque, blue where only the reference is, and
## the reference itself dimmed underneath for context. A SHIFT paints red down one
## edge and blue down the opposite one; antialiasing speckles both colours evenly
## around the whole outline.
func _diff_image(a: Image, b: Image) -> Image:
	var out := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var oa := ca.a >= 0.5
			var ob := cb.a >= 0.5
			if oa and not ob:
				out.set_pixel(x, y, Color(1.0, 0.1, 0.1, 1.0))
			elif ob and not oa:
				out.set_pixel(x, y, Color(0.1, 0.4, 1.0, 1.0))
			elif ob:
				out.set_pixel(x, y, Color(0.18, 0.18, 0.20, 1.0))
			else:
				out.set_pixel(x, y, Color(0.04, 0.04, 0.05, 1.0))
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[AgentBake] %s missing" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[AgentBake] %s is not a JSON object" % path)
		return {}
	return parsed


static func _json_vec2(v) -> Vector2:
	var a: Array = v
	return Vector2(float(a[0]), float(a[1]))


## First VisualInstance3D with this name, anywhere under `node`.
func _find_mesh(node: Node, mesh_name: String) -> VisualInstance3D:
	if node is VisualInstance3D and node.name == mesh_name:
		return node
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null


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
