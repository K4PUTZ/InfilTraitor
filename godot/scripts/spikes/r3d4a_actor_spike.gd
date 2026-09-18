## R3D4AActorSpike — RENDER3D R3D-4a: an actor in depth, billboard (A) against composite (B).
##
## An instrument, never a mode. Run windowed:
##   godot --path . res://godot/scenes/spikes/r3d4a_actor_spike.tscn --resolution 720x1280
## It builds an occlusion fixture out of plain boxes, puts the REAL baked agent frame in it three
## ways, saves a contact sheet per case to `Screenshots/r3d4a/` and quits.
##
## THE THREE VARIANTS of every case:
##  - `truth`: a volumetric proxy (a capsule the agent's height). The occlusion a body really has.
##  - `A`: a camera-facing quad in the 3D scene, D17's relight ported to a spatial shader,
##    depth-tested by the pipeline.
##  - `B`: the shipped 2D Sprite2D, relit by the canvas shader, cut against a depth pass of the
##    same board (a second camera into a SubViewport, meshes duplicated on a second render layer).
##
## Nothing here reads a game system: the fixture is boxes, the light is a constant. The question is
## the mechanism, not the map.
extends Node3D

const PPU: float = 256.0 / sqrt(2.0)  ## screen px per world unit at zoom 1 (GU diamond = 256 px)
const FRAME_DIR: String = "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"
const FRAME_PX: float = 256.0
const AGENT_H: float = 200.0 / (PPU * 0.8660254)  ## world height of the baked figure
const DEPTH_RANGE: float = 100.0
const LAYER_MAIN: int = 1
const LAYER_DEPTH: int = 2
const OUT_DIR: String = "res://Screenshots/r3d4a/"
const LIGHT_DIR := Vector3(-0.3, 0.5, 0.8)

var _win: Vector2 = Vector2(720, 1280)
var _cam: Camera3D
var _depth_cam: Camera3D
var _depth_vp: SubViewport
var _fixture: Node3D
var _glass: Node3D
var _proxies: Node3D
var _billboards: Node3D
var _overlay: CanvasLayer
var _sprites2d: Array[Sprite2D] = []
var _agents: Array[Dictionary] = []  ## {feet: Vector3, facing: String}
var _tex: Dictionary = {}  ## facing -> {color, normal}
var _anchor: Vector2 = Vector2(128.0, 228.0)
var _bias: float = 0.0
var _slack: float = 0.004
var _flip: bool = false
var _billboard_mat: Dictionary = {}
var _only_case: String = ""


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_win = Vector2(get_window().size)
	_bias = float(OS.get_environment("INFILTRAITOR_R3D4A_BIAS")) if OS.get_environment("INFILTRAITOR_R3D4A_BIAS") != "" else 0.0
	_flip = OS.get_environment("INFILTRAITOR_R3D4A_FLIP") == "1"
	_only_case = OS.get_environment("INFILTRAITOR_R3D4A_CASE")
	if not _load_frames():
		get_tree().quit(1)
		return
	_build_scene()
	if _flag("R3D4A_BENCH") == "1":
		_bench.call_deferred()
	else:
		_run.call_deferred()


func _flag(flag_name: String) -> String:
	var flags: Node = get_node_or_null("/root/DevFlags")
	if flags != null:
		return flags.value(flag_name, "")
	return OS.get_environment("INFILTRAITOR_" + flag_name)


func _load_frames() -> bool:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRAME_DIR + "anchor.json"))
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("[R3D4AActorSpike] anchor.json unreadable")
		return false
	var a: Array = meta["anchor_px"]
	_anchor = Vector2(float(a[0]), float(a[1]))
	for d: String in ["N", "E", "S", "W"]:
		var c: Texture2D = ImageSource.load_texture(FRAME_DIR + "frame_%s_color.png" % d)
		var n: Texture2D = ImageSource.load_texture(FRAME_DIR + "frame_%s_normal.png" % d)
		if c == null or n == null:
			push_error("[R3D4AActorSpike] frame %s missing" % d)
			return false
		_tex[d] = {"color": c, "normal": n}
	return true


func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = _win.y / PPU  ## 1 world unit = PPU screen px, the sprite's native scale
	_cam.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_cam.near = 0.05
	_cam.far = 200.0
	_cam.cull_mask = LAYER_MAIN
	add_child(_cam)
	_cam.make_current()

	_depth_vp = SubViewport.new()
	_depth_vp.size = Vector2i(_win)
	_depth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_depth_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_depth_vp)
	_depth_cam = Camera3D.new()
	_depth_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_depth_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_depth_cam.size = _cam.size
	_depth_cam.near = _cam.near
	_depth_cam.far = _cam.far
	_depth_cam.cull_mask = LAYER_DEPTH
	var denv := Environment.new()
	denv.background_mode = Environment.BG_COLOR
	denv.background_color = Color(1, 1, 1)
	denv.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_depth_cam.environment = denv
	_depth_vp.add_child(_depth_cam)

	_fixture = Node3D.new()
	add_child(_fixture)
	_glass = Node3D.new()
	add_child(_glass)
	_proxies = Node3D.new()
	add_child(_proxies)
	_billboards = Node3D.new()
	add_child(_billboards)

	_overlay = CanvasLayer.new()
	add_child(_overlay)


## --- FIXTURE -----------------------------------------------------------------------------------

func _box(center: Vector3, size: Vector3, color: Color, depth_pass: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = center
	mi.layers = LAYER_MAIN
	_fixture.add_child(mi)
	if depth_pass:
		var dm := MeshInstance3D.new()
		dm.mesh = bm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://godot/shaders/r3d4a_depth_encode.gdshader")
		sm.set_shader_parameter("depth_range", DEPTH_RANGE)
		dm.material_override = sm
		dm.position = center
		dm.layers = LAYER_DEPTH
		_fixture.add_child(dm)


func _glass_pane(center: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.8, 1.0, 0.35)
	mi.material_override = m
	mi.position = center
	mi.layers = LAYER_MAIN  ## NOT in the depth pass: Board3DLive draws glass with depth_draw_never
	_glass.add_child(mi)


func _floor(center: Vector3) -> void:
	for ix: int in range(-6, 7):
		for iz: int in range(-6, 7):
			var c := Color(0.42, 0.44, 0.47) if (ix + iz) % 2 == 0 else Color(0.36, 0.38, 0.41)
			_box(center + Vector3(ix, -0.05, iz), Vector3(1.0, 0.1, 1.0), c)


## A case: name, patch centre, fixture builder key, agents as [Vector3 offset, facing].
func _cases() -> Array[Dictionary]:
	return [
		{"name": "wall", "p": Vector3(0, 0, 0), "agents": [
			[Vector3(-0.3, 0, -0.55), "S"],   # behind the low wall: legs hidden, head shows
			[Vector3(0.9, 0, 0.9), "S"],      # in front: must cover the wall
			[Vector3(-1.3, 0, 0.12), "S"],    # hard against the wall's front face
			[Vector3(-1.3, 0, -0.12), "S"],   # hard against the wall's back face
		]},
		{"name": "glass", "p": Vector3(30, 0, 0), "agents": [
			[Vector3(-0.3, 0, -0.55), "S"],   # behind the pane: seen THROUGH it, tinted
			[Vector3(0.7, 0, 0.8), "S"],      # in front: clean
		]},
		{"name": "roof", "p": Vector3(60, 0, 0), "agents": [
			[Vector3(-0.15, 0, 0.0), "S"],    # just under the roof edge
			[Vector3(0.45, 0, 0.0), "S"],     # just outside it
			[Vector3(-0.6, 0, 0.9), "S"],     # under the roof, beside the edge
		]},
		{"name": "column", "p": Vector3(90, 0, 0), "agents": [
			[Vector3(0.55, 0, 0.55), "S"],    # in front of the column
			[Vector3(-0.55, 0, -0.55), "S"],  # behind it
			[Vector3(0.45, 0, -0.45), "S"],   # left of it, level
			[Vector3(-0.45, 0, 0.45), "S"],   # right of it, level
			[Vector3(0.2, 0, -0.35), "S"],    # left, a little behind the column's near face
			[Vector3(-0.2, 0, 0.35), "S"],    # right, a little in front
		]},
		{"name": "facings", "p": Vector3(120, 0, 0), "agents": [
			[Vector3(0.9, 0, -0.9), "N"], [Vector3(0.3, 0, -0.3), "E"],
			[Vector3(-0.3, 0, 0.3), "S"], [Vector3(-0.9, 0, 0.9), "W"],
		]},
	]


func _build_case(c: Dictionary) -> void:
	for n: Node in _fixture.get_children():
		n.queue_free()
	for n: Node in _glass.get_children():
		n.queue_free()
	var p: Vector3 = c["p"]
	_floor(p)
	match String(c["name"]):
		"wall":
			_box(p + Vector3(0, 0.3, 0), Vector3(3.2, 0.6, 0.2), Color(0.62, 0.42, 0.34))
		"glass":
			_glass_pane(p + Vector3(0, 0.7, 0), Vector3(3.2, 1.4, 0.05))
		"roof":
			_box(p + Vector3(-1.2, 1.5, 0), Vector3(2.8, 0.15, 3.4), Color(0.4, 0.5, 0.6))
			for corner: Vector3 in [Vector3(-2.5, 0.7, -1.5), Vector3(-2.5, 0.7, 1.5)]:
				_box(p + corner, Vector3(0.15, 1.4, 0.15), Color(0.5, 0.5, 0.5))
		"column":
			_box(p + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3), Color(0.7, 0.7, 0.45))
		"facings":
			pass


## --- AGENTS ------------------------------------------------------------------------------------

func _clear_agents() -> void:
	for n: Node in _proxies.get_children():
		n.queue_free()
	for n: Node in _billboards.get_children():
		n.queue_free()
	for s: Sprite2D in _sprites2d:
		s.queue_free()
	_sprites2d.clear()


func _place_agents(c: Dictionary) -> void:
	_clear_agents()
	var p: Vector3 = c["p"]
	var basis_cam: Basis = _cam.global_transform.basis
	var fwd: Vector3 = -basis_cam.z
	var up: Vector3 = basis_cam.y
	for entry: Array in c["agents"]:
		var feet: Vector3 = p + (entry[0] as Vector3)
		var facing: String = entry[1]
		# truth: a capsule the agent's height
		var proxy := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.16
		cap.height = AGENT_H
		proxy.mesh = cap
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.95, 0.55, 0.1)
		proxy.material_override = pm
		proxy.position = feet + Vector3(0, AGENT_H * 0.5, 0)
		_proxies.add_child(proxy)
		# A: billboard
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * (FRAME_PX / PPU)
		quad.mesh = qm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://godot/shaders/r3d4a_actor_billboard.gdshader")
		sm.set_shader_parameter("albedo_tex", _tex[facing]["color"])
		sm.set_shader_parameter("normal_tex", _tex[facing]["normal"])
		sm.set_shader_parameter("light_dir", LIGHT_DIR)
		quad.material_override = sm
		# The anchor is the FEET pixel; the quad's centre is (anchor.y - 128) px above them.
		var centre: Vector3 = feet + up * ((_anchor.y - FRAME_PX * 0.5) / PPU) \
			+ basis_cam.x * ((FRAME_PX * 0.5 - _anchor.x) / PPU) - fwd * _bias
		quad.global_transform = Transform3D(basis_cam, centre)
		_billboards.add_child(quad)
		# B: the shipped 2D sprite
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = _tex[facing]["color"]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://godot/shaders/r3d4a_actor_depth_composite.gdshader")
		mat.set_shader_parameter("normal_tex", _tex[facing]["normal"])
		mat.set_shader_parameter("depth_tex", _depth_vp.get_texture())
		mat.set_shader_parameter("light_dir", LIGHT_DIR)
		mat.set_shader_parameter("depth_range", DEPTH_RANGE)
		mat.set_shader_parameter("depth_slack", _slack)
		mat.set_shader_parameter("flip_depth_y", _flip)
		mat.set_shader_parameter("sprite_depth", (feet - _cam.global_position).dot(fwd) - _bias)
		spr.material = mat
		var screen: Vector2 = _cam.unproject_position(feet)
		spr.position = screen - _anchor
		_overlay.add_child(spr)
		_sprites2d.append(spr)


func _aim_cameras(p: Vector3) -> void:
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var target: Vector3 = p + Vector3(0, 0.6, 0)
	_cam.global_position = target - fwd * 60.0
	_depth_cam.global_transform = _cam.global_transform


func _variant(name: String) -> void:
	_proxies.visible = name == "truth"
	_billboards.visible = name == "A"
	_overlay.visible = name == "B"


## --- DRIVER ------------------------------------------------------------------------------------

func _shot(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(ProjectSettings.globalize_path(path))
	return img


func _settle() -> void:
	for i: int in range(4):
		await get_tree().process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var report: Array[String] = []
	for c: Dictionary in _cases():
		if _only_case != "" and String(c["name"]) != _only_case:
			continue
		_build_case(c)
		await _settle()
		_aim_cameras(c["p"])
		_place_agents(c)
		await _settle()
		var name: String = c["name"]
		# noagent baseline: the board alone, for "how many pixels did the actor change".
		_proxies.visible = false
		_billboards.visible = false
		_overlay.visible = false
		await _settle()
		var base: Image = await _shot(OUT_DIR + "%s_base.png" % name)
		var shots: Dictionary = {}
		for v: String in ["truth", "A", "B"]:
			_variant(v)
			await _settle()
			shots[v] = await _shot(OUT_DIR + "%s_%s.png" % [name, v])
		if name == "wall":
			await _depth_control(c)
		report.append(_stats(name, base, shots))
		_sheet(name, base, shots)
	for line: String in report:
		print(line)
	get_tree().quit(0)


func _changed(a: Image, b: Image) -> int:
	var n: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				n += 1
	return n


func _stats(name: String, base: Image, shots: Dictionary) -> String:
	return "[R3D4A] %s bias=%.2f  actor px: truth=%d A=%d B=%d   A-vs-B differing px=%d" % [
		name, _bias, _changed(base, shots["truth"]), _changed(base, shots["A"]),
		_changed(base, shots["B"]), _changed(shots["A"], shots["B"])]


## The depth pass has to be read back BEFORE any B capture is trusted: a control against a known
## distance, so "B matches A" cannot come from two broken things agreeing.
func _depth_control(c: Dictionary) -> void:
	await _settle()
	var img: Image = _depth_vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "depth_control.png"))
	var p: Vector3 = c["p"]
	var top: Vector3 = p + Vector3(0, 0.6, 0)  # wall top centre
	var expect: float = (top - _cam.global_position).dot(-_cam.global_transform.basis.z)
	var s: Vector2 = _cam.unproject_position(top)
	var px: Color = img.get_pixel(int(s.x), int(s.y - (0.0 if not _flip else 0.0)))
	var got: float = (round(px.r * 255.0) * 256.0 + round(px.g * 255.0)) / 65535.0 * DEPTH_RANGE
	print("[R3D4A] depth control: wall-top expected %.4f, decoded %.4f (flip=%s)" % [expect, got, str(_flip)])


func _sheet(name: String, base: Image, shots: Dictionary) -> void:
	var crop := Rect2i(int(_win.x * 0.5) - 240, int(_win.y * 0.5) - 300, 480, 600)
	var cols: Array[Image] = [base, shots["truth"], shots["A"], shots["B"]]
	var sheet := Image.create(crop.size.x * 5, crop.size.y, false, Image.FORMAT_RGBA8)
	for i: int in range(4):
		sheet.blit_rect(cols[i], crop, Vector2i(i * crop.size.x, 0))
	var diff := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	for y: int in range(crop.size.y):
		for x: int in range(crop.size.x):
			var ca: Color = (shots["A"] as Image).get_pixel(crop.position.x + x, crop.position.y + y)
			var cb: Color = (shots["B"] as Image).get_pixel(crop.position.x + x, crop.position.y + y)
			var d: float = absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			diff.set_pixel(x, y, Color(1, 0, 0) if d > 0.06 else Color(0, 0, 0))
	sheet.blit_rect(diff, Rect2i(Vector2i.ZERO, crop.size), Vector2i(4 * crop.size.x, 0))
	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + "sheet_%s.png" % name))


## --- DEVICE BENCH ------------------------------------------------------------------------------
## `R3D4A_BENCH=1` (DevFlags on the handset). Three variants over the same fixture, each read in
## 60-frame windows through the same `frame.window` telemetry the board spike uses:
##  - `none`:  the board alone (depth pass off, no agents) — the floor both are charged against;
##  - `A`:     the six-agent column case as billboards;
##  - `B`:     the same six as 2D sprites, depth pass ON.
## The fixture's floor is 169 boxes, each drawn twice in B (main + depth layer).
const BENCH_SETTLE_S: float = 3.0
const BENCH_HOLD_S: float = 12.0
const PROBE_FRAMES: int = 60
var _probe_n: int = 0
var _probe_last_us: int = 0
var _probe_sum_us: int = 0
var _bench_variant: String = ""


func _bench() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var c: Dictionary = {}
	for k: Dictionary in _cases():
		if String(k["name"]) == "column":
			c = k
	_build_case(c)
	await _settle()
	_aim_cameras(c["p"])
	_place_agents(c)
	await _settle()
	Telemetry.event("scenario.start", {"steps": 3, "spike": "r3d4a"})
	for v: String in ["none", "A", "B", "none"]:
		_bench_variant = v
		_proxies.visible = false
		_billboards.visible = v == "A"
		_overlay.visible = v == "B"
		_depth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v == "B" \
			else SubViewport.UPDATE_DISABLED
		Telemetry.event("camera.zoom_end", {"zoom": 1.0, "via": "spike"})
		await get_tree().create_timer(BENCH_SETTLE_S).timeout
		Telemetry.event("scenario.mark", {"label": "R3D4A_%s" % v})
		print("[R3D4A] variant %s" % v)
		if v == "B":
			# The depth pass is only trusted on THIS GPU after a control against a known distance.
			_depth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			await _settle()
			var img: Image = _depth_vp.get_texture().get_image()
			var top: Vector3 = (c["p"] as Vector3) + Vector3(0, 1.0, 0)  # column top-centre
			var expect: float = (top - _cam.global_position).dot(-_cam.global_transform.basis.z)
			var s: Vector2 = _cam.unproject_position(top)
			var px: Color = img.get_pixel(int(s.x), int(s.y + 2.0))
			var got: float = (round(px.r * 255.0) * 256.0 + round(px.g * 255.0)) / 65535.0 * DEPTH_RANGE
			print("[R3D4A] device depth control: column-top expected %.3f, decoded %.3f, fmt %d"
				% [expect, got, img.get_format()])
		await get_tree().create_timer(BENCH_HOLD_S).timeout
	Telemetry.event("scenario.end")
	get_tree().quit(0)


func _process(_delta: float) -> void:
	if _bench_variant == "":
		return
	var now: int = Time.get_ticks_usec()
	if _probe_last_us > 0:
		_probe_sum_us += now - _probe_last_us
		_probe_n += 1
	_probe_last_us = now
	if _probe_n < PROBE_FRAMES:
		return
	var vrid: RID = get_viewport().get_viewport_rid()
	var fields: Dictionary = {
		"frames": _probe_n,
		"ms": float(_probe_sum_us) / 1000.0 / float(_probe_n),
		"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(vrid),
		"render_gpu": RenderingServer.viewport_get_measured_render_time_gpu(vrid),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"framing": "r3d4a_%s" % _bench_variant,
		"zoom": 1.0,
		"visible": Vector2(get_viewport().get_visible_rect().size),
		"gu_visible": 0,
	}
	print("[FRAME-PROBE] %.1f ms/frame · render cpu %.1f ms · render gpu %.1f ms · %d draw call(s) · %d primitive(s) · %d object(s) · view %s"
		% [fields["ms"], fields["render_cpu"], fields["render_gpu"], fields["draws"],
		fields["primitives"], fields["objects"], fields["framing"]])
	Telemetry.event("frame.window", fields)
	_probe_n = 0
	_probe_sum_us = 0
