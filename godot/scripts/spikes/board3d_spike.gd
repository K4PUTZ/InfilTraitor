## Board3DSpike — PLAYGROUND's static board as depth-tested 3D meshes.
##
## DIAG-20 (DEVICE_DIAGNOSTICS_MASTER_PLAN §15.3). An instrument, never a mode:
## reachable only through `SPIKE=board3d`, which makes Room hand over to this scene
## before any map is built.
##
## THE QUESTION: is the 2D representation the anchor? The idle portrait board is
## ~42 000 primitives and costs the Moto 60 ms, and 36–47 ms of that is pixel
## shading (§10.17.4): 48 stacked TileMapLayers drawn back to front with no depth
## buffer, and a face shader on every covered pixel of every layer. This draws the
## same board the way a 3D pipeline would, and measures it with the same tools.
##
## WHAT IS HERE, and what each is for:
##  - the floor zones, blocks and panels of `maps/PLAYGROUND.map.json`, at the 2D
##    board's own geometry: 8 voxels per GU, 8 levels per storey, a storey as tall as
##    a GU is wide (158 px per storey on a 256 px tile is the 30° camera's cube);
##  - TWO MESHING MODES, because the answer depends on them. `voxel` emits every
##    exposed voxel face (hidden faces culled): the destructible granularity, the
##    worst case. `merged` emits one quad per exposed surface: intact geometry, the
##    best case;
##  - each material's facade texture tinted by its `base_color`, on a lit material
##    with one directional light — a per-pixel lit 3D look, not an unlit shortcut;
##  - an orthographic camera at the 2D projection's angles (30° down, 45° around),
##    with an ortho size that shows the same world area as the 2D portrait canvas
##    at each zoom, and a printed on-screen GU count to prove it (2D: 95 at 0.5);
##  - Telemetry `frame.window` records and `scenario.mark`s, so `bench_analyze.py`
##    reads it exactly like the 2D zoom ladder.
##
## NOT HERE — so nobody reads this as parity: the 12-bucket light, soot, decals,
## destruction, actors, fog and the HUD. It prices the REPRESENTATION.
extends Node3D

const MAP_PATH: String = "res://maps/PLAYGROUND.map.json"
const VOXELS_PER_GU: int = 8
const LEVELS_PER_STOREY: int = 8
## The 2D board's pixels per world unit along any screen axis at zoom 1: a GU
## diamond is 256 px wide and a GU's projected width is sqrt(2) units.
const PX_PER_UNIT: float = 256.0 / sqrt(2.0)
const ZOOMS: Array[float] = [0.5, 0.42, 0.35, 0.3, 0.25, 0.2]
const SETTLE_S: float = 4.0
const STOP_S: float = 15.0
const PROBE_FRAMES: int = 60

var _camera: Camera3D
var _board: Node3D
var _materials: Dictionary = {}  ## material id -> StandardMaterial3D
var _map: Dictionary = {}
var _zoom: float = 0.5
var _mode: String = ""
var _probe_n: int = 0
var _probe_last_us: int = 0
var _probe_sum_us: int = 0


func _ready() -> void:
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("[Board3DSpike] cannot open %s (%d)" % [MAP_PATH, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("sections"):
		push_error("[Board3DSpike] %s is not a MAPFILE" % MAP_PATH)
		get_tree().quit(1)
		return
	_map = (parsed as Dictionary)["sections"]

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.13, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_camera.far = 400.0
	add_child(_camera)
	var start: Array = (_map["actors"] as Dictionary)["agent_start"]
	var target := Vector3(float(start[0]) + 0.5, 0.0, float(start[1]) + 0.5)
	_camera.position = target + _camera.global_transform.basis.z * 150.0
	_camera.make_current()

	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Telemetry.event("scenario.start", {"steps": 2 * ZOOMS.size(), "spike": "board3d"})
	_run_ladder()


func _run_ladder() -> void:
	for mode: String in ["voxel", "merged"]:
		_build(mode)
		for zoom: float in ZOOMS:
			_set_zoom(zoom)
			await get_tree().create_timer(SETTLE_S).timeout
			var label: String = "S3D_%s_z%03d" % [mode, roundi(zoom * 100.0)]
			Telemetry.event("scenario.mark", {"label": label})
			print("[SPIKE3D] %s · on-screen GUs %d" % [label, _visible_gu_count()])
			## One real frame per meshing mode, so the geometry and the camera are checked
			## by looking, not by assuming the numbers mean the board is on screen.
			if zoom == ZOOMS[0]:
				await RenderingServer.frame_post_draw
				_capture("spike3d_%s" % mode)
			await get_tree().create_timer(STOP_S).timeout
	Telemetry.event("scenario.end")
	get_tree().quit(0)


func _set_zoom(zoom: float) -> void:
	_zoom = zoom
	## Closes the previous segment in `bench_analyze.py` at the moment the view changes;
	## without it the settle windows of the NEXT zoom were read into the previous row.
	Telemetry.event("camera.zoom_end", {"zoom": zoom, "via": "spike"})
	## Same world area as the 2D board at this zoom: the 2D canvas shows
	## `visible height / (PX_PER_UNIT * zoom)` world units vertically, whatever the
	## device's canvas is (390×873 on the Moto).
	_camera.size = get_viewport().get_visible_rect().size.y / (PX_PER_UNIT * zoom)


func _process(_delta: float) -> void:
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
		"framing": "spike3d_%s" % _mode,
		"zoom": _zoom,
		"visible": Vector2(get_viewport().get_visible_rect().size),
		"gu_visible": _visible_gu_count(),
	}
	print("[FRAME-PROBE] %.1f ms/frame · render cpu %.1f ms · render gpu %.1f ms · %d draw call(s) · %d primitive(s) · %d object(s) · view %s zoom %.2f gu %d"
		% [fields["ms"], fields["render_cpu"], fields["render_gpu"], fields["draws"],
		fields["primitives"], fields["objects"], fields["framing"], _zoom, fields["gu_visible"]])
	Telemetry.event("frame.window", fields)
	_probe_n = 0
	_probe_sum_us = 0


## GU centres on the ground plane that project inside the viewport — the 2D probe's
## `gu_visible` metric, so the two representations are compared at the same world area.
func _visible_gu_count() -> int:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var inner: Array = (_map["board"] as Dictionary)["inner_size"]
	var count: int = 0
	for gy in range(int(inner[1])):
		for gx in range(int(inner[0])):
			var p := Vector3(float(gx) + 0.5, 0.0, float(gy) + 0.5)
			if _camera.is_position_behind(p):
				continue
			var s: Vector2 = _camera.unproject_position(p)
			if s.x >= 0.0 and s.y >= 0.0 and s.x < size.x and s.y < size.y:
				count += 1
	return count


# ── building ──────────────────────────────────────────────────────────────────

func _build(mode: String) -> void:
	_mode = mode
	if _board != null:
		_board.queue_free()
	_board = Node3D.new()
	add_child(_board)
	var t0: int = Time.get_ticks_usec()
	var solid: Dictionary = _solid_voxels()
	var tools: Dictionary = {}  ## material -> SurfaceTool
	var quads: int = 0
	if mode == "voxel":
		quads = _emit_voxel_faces(solid, tools)
	else:
		quads = _emit_merged_faces(tools)
	for material: String in tools:
		var st: SurfaceTool = tools[material]
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = _material(material)
		_board.add_child(mesh)
	print("[SPIKE3D] built %s mode — %d quad(s), %d material surface(s), %.0f ms"
		% [mode, quads, tools.size(), float(Time.get_ticks_usec() - t0) / 1000.0])
	Telemetry.event("view.framing", {"framing": "spike3d_%s" % mode, "quads": quads})


## Every solid voxel of the board, keyed Vector3i(x, level, z) in voxel units, with
## its material. The floor is one level of slab under the playable ground.
func _solid_voxels() -> Dictionary:
	var solid: Dictionary = {}
	var zones: Array = (_map["floor_zones"] as Dictionary)["items"]
	for zone: Dictionary in zones:
		var gu: Array = zone["gu"]
		var size: Array = zone["size"]
		for vx in range(int(gu[0]) * VOXELS_PER_GU, (int(gu[0]) + int(size[0])) * VOXELS_PER_GU):
			for vz in range(int(gu[1]) * VOXELS_PER_GU, (int(gu[1]) + int(size[1])) * VOXELS_PER_GU):
				solid[Vector3i(vx, -1, vz)] = str(zone["material"])
	for block: Dictionary in (_map["blocks"] as Dictionary)["items"]:
		var bgu: Array = block["gu"]
		for vx in range(int(bgu[0]) * VOXELS_PER_GU, (int(bgu[0]) + 1) * VOXELS_PER_GU):
			for vz in range(int(bgu[1]) * VOXELS_PER_GU, (int(bgu[1]) + 1) * VOXELS_PER_GU):
				for level in range(int(block["storeys"]) * LEVELS_PER_STOREY):
					solid[Vector3i(vx, level, vz)] = str(block["material"])
	for panel: Dictionary in (_map["panels"] as Dictionary)["items"]:
		var pgu: Array = panel["gu"]
		var face: String = panel["face"]
		## A panel is a 2-voxel-thick wall (D16) along one edge of its GU.
		for i in range(VOXELS_PER_GU):
			for t in range(2):
				var vx: int = int(pgu[0]) * VOXELS_PER_GU + (i if face == "SE" else VOXELS_PER_GU - 1 - t)
				var vz: int = int(pgu[1]) * VOXELS_PER_GU + (VOXELS_PER_GU - 1 - t if face == "SE" else i)
				for level in range(int(panel["storeys"]) * LEVELS_PER_STOREY):
					solid[Vector3i(vx, level, vz)] = str(panel["material"])
	return solid


const FACE_DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


func _emit_voxel_faces(solid: Dictionary, tools: Dictionary) -> int:
	var quads: int = 0
	var unit: float = 1.0 / float(VOXELS_PER_GU)
	for key: Vector3i in solid:
		var material: String = solid[key]
		for dir: Vector3i in FACE_DIRS:
			if solid.has(key + dir):
				continue
			if key.y == -1 and dir.y == -1:
				continue  ## the underside of the floor is never seen
			_quad_box(_tool(tools, material), Vector3(key) * unit, Vector3(unit, unit, unit), dir)
			quads += 1
	return quads


## One quad per exposed surface: the floor zones' tops, each block's top and four
## sides, each panel's two faces and top. Adjacent blocks keep their shared sides —
## still hundreds of times fewer quads than per-voxel.
func _emit_merged_faces(tools: Dictionary) -> int:
	var quads: int = 0
	for zone: Dictionary in (_map["floor_zones"] as Dictionary)["items"]:
		var gu: Array = zone["gu"]
		var size: Array = zone["size"]
		_box_faces(_tool(tools, str(zone["material"])),
			Vector3(float(gu[0]), -1.0 / float(LEVELS_PER_STOREY), float(gu[1])),
			Vector3(float(size[0]), 1.0 / float(LEVELS_PER_STOREY), float(size[1])), true)
		quads += 1
	for block: Dictionary in (_map["blocks"] as Dictionary)["items"]:
		var bgu: Array = block["gu"]
		_box_faces(_tool(tools, str(block["material"])), Vector3(float(bgu[0]), 0.0, float(bgu[1])),
			Vector3(1.0, float(block["storeys"]), 1.0), false)
		quads += 5
	for panel: Dictionary in (_map["panels"] as Dictionary)["items"]:
		var pgu: Array = panel["gu"]
		var thick: float = 2.0 / float(VOXELS_PER_GU)
		var origin := Vector3(float(pgu[0]), 0.0, float(pgu[1]) + 1.0 - thick)
		var extent := Vector3(1.0, float(panel["storeys"]), thick)
		if str(panel["face"]) != "SE":
			origin = Vector3(float(pgu[0]) + 1.0 - thick, 0.0, float(pgu[1]))
			extent = Vector3(thick, float(panel["storeys"]), 1.0)
		_box_faces(_tool(tools, str(panel["material"])), origin, extent, false)
		quads += 5
	return quads


func _box_faces(st: SurfaceTool, origin: Vector3, extent: Vector3, top_only: bool) -> void:
	_quad_box(st, origin, extent, Vector3i(0, 1, 0))
	if top_only:
		return
	for dir: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		_quad_box(st, origin, extent, dir)


## One face of the axis-aligned box `origin`..`origin + extent`, two triangles, with
## UVs in world space so the facade tiles identically in both meshing modes
## (1024×512 px at 16 texels per voxel = 64 × 32 voxels = 8 × 4 GU).
func _quad_box(st: SurfaceTool, origin: Vector3, extent: Vector3, dir: Vector3i) -> void:
	var o: Vector3 = origin
	var e: Vector3 = extent
	var corners: Array[Vector3] = []
	if dir == Vector3i(0, 1, 0):
		corners = [o + Vector3(0, e.y, 0), o + Vector3(e.x, e.y, 0), o + Vector3(e.x, e.y, e.z), o + Vector3(0, e.y, e.z)]
	elif dir == Vector3i(0, -1, 0):
		corners = [o, o + Vector3(0, 0, e.z), o + Vector3(e.x, 0, e.z), o + Vector3(e.x, 0, 0)]
	elif dir == Vector3i(1, 0, 0):
		corners = [o + Vector3(e.x, 0, 0), o + Vector3(e.x, 0, e.z), o + Vector3(e.x, e.y, e.z), o + Vector3(e.x, e.y, 0)]
	elif dir == Vector3i(-1, 0, 0):
		corners = [o, o + Vector3(0, e.y, 0), o + Vector3(0, e.y, e.z), o + Vector3(0, 0, e.z)]
	elif dir == Vector3i(0, 0, 1):
		corners = [o + Vector3(0, 0, e.z), o + Vector3(0, e.y, e.z), o + Vector3(e.x, e.y, e.z), o + Vector3(e.x, 0, e.z)]
	else:
		corners = [o, o + Vector3(e.x, 0, 0), o + Vector3(e.x, e.y, 0), o + Vector3(0, e.y, 0)]
	var normal := Vector3(dir)
	for i: int in [0, 1, 2, 0, 2, 3]:
		var c: Vector3 = corners[i]
		## World-space planar UV on the face's two in-plane axes.
		var uv: Vector2
		if dir.y != 0:
			uv = Vector2(c.x, c.z)
		elif dir.x != 0:
			uv = Vector2(c.z, -c.y)
		else:
			uv = Vector2(c.x, -c.y)
		st.set_normal(normal)
		st.set_uv(Vector2(uv.x / 8.0, uv.y / 4.0))
		st.add_vertex(c)


func _tool(tools: Dictionary, material: String) -> SurfaceTool:
	if not tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[material] = st
	return tools[material]


func _material(material: String) -> StandardMaterial3D:
	if _materials.has(material):
		return _materials[material]
	var m := StandardMaterial3D.new()
	var info_path: String = "res://ASSETS/materials/%s/%s.json" % [material, material]
	var color := Color(0.6, 0.6, 0.6)
	if FileAccess.file_exists(info_path):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		if typeof(info) == TYPE_DICTIONARY and (info as Dictionary).has("base_color"):
			var c: Array = info["base_color"]
			color = Color(float(c[0]), float(c[1]), float(c[2]))
	m.albedo_color = color
	var facade_path: String = "res://ASSETS/materials/%s/facade_%s.png" % [material, material]
	if ResourceLoader.exists(facade_path):
		m.albedo_texture = load(facade_path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if GlassMaterials.is_glass(material):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.7, 0.9, 0.35)
	_materials[material] = m
	return m


## The viewport to `captures/<file_name>.png` — the external files dir on Android, so
## `adb pull` reaches it from the shipped APK, `user://` elsewhere.
func _capture(file_name: String) -> void:
	var dir: String = DevFlags.external_files_dir()
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://")
	var path: String = "%s/captures/%s.png" % [dir.trim_suffix("/"), file_name]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: int = get_viewport().get_texture().get_image().save_png(path)
	print("[SPIKE3D] capture %s (%s)" % [path, error_string(err)])
