## LayoutOverlay3D — the map's anchors drawn ON the board (CAPTURE_RAILS_MASTER_PLAN §9, CR-4): bounds, buffer ring, envelope
## reserve, compass corners and side names, the agent's start, the exits, every POI (a pin + its id) and region (a wire box + its id),
## and one rail's path. A dev overlay (English labels), world space and depth-tested like every new VFX (RENDER3D rule: world-space
## state, never screen pixels). Built when switched on, freed when switched off: zero cost otherwise. The future editor's viewport layer.
extends Node3D

const MapLayoutRef = preload("res://godot/scripts/world/maps/map_layout.gd")
const MapCompassRef = preload("res://godot/scripts/world/maps/map_compass.gd")
const MapEnvelopeRef = preload("res://godot/scripts/world/maps/map_envelope.gd")

const COL_BOUNDS := Color(1.0, 1.0, 1.0, 0.9)
const COL_RING := Color(0.6, 0.6, 0.6, 0.6)
const COL_RESERVE := Color(1.0, 0.75, 0.2, 0.8)
const COL_REGION := Color(0.3, 0.9, 1.0, 0.95)
const COL_POI := Color(1.0, 0.3, 0.8, 1.0)
const COL_AGENT := Color(0.3, 1.0, 0.4, 1.0)
const COL_EXIT := Color(0.7, 0.4, 1.0, 1.0)
const COL_RAIL := Color(1.0, 1.0, 0.2, 1.0)
const LIFT: float = 0.02   ## a hair above the floor top, so ground lines are not z-fighting the slab

var _mesh := ImmediateMesh.new()


## `rail_id` "" = no rail drawn.
func build(ml: RefCounted, rail_id: String = "") -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var rect: Rect2i = ml.get("playable_rect")
	var size: Vector2i = ml.get("map_size")
	var tall: float = float(ml.get("tallest_storeys"))
	_rect_lines(Rect2(rect), 0.0, COL_BOUNDS)
	_rect_lines(Rect2(Vector2.ZERO, Vector2(size)), 0.0, COL_RING)
	## The envelope reserve, from the playable origin (a guide: dashed).
	var env: Dictionary = MapEnvelopeRef.for_map(ml.get("envelope"))
	_rect_lines(Rect2(Vector2(rect.position), Vector2(env["reserve"])), 0.0, COL_RESERVE, true)
	for corner: String in MapCompassRef.CORNERS:
		var c: Vector2 = MapCompassRef.corner(corner, rect)
		_label(corner, Vector3(c.x, 0.3, c.y), COL_BOUNDS, 96)
	for side: String in MapCompassRef.SIDES:
		var band: Rect2i = MapCompassRef.band(side, rect, 1)
		var mid: Vector2 = Vector2(band.position) + Vector2(band.size) * 0.5
		var out: Vector2 = Vector2(MapCompassRef.outward(side)) * 0.8
		_label(side, Vector3(mid.x + out.x, 0.2, mid.y + out.y), COL_BOUNDS, 64)
	var a: Vector2i = ml.get("agent_start_cell")
	_pin(Vector3(a.x + 0.5, 0.0, a.y + 0.5), 1.0, COL_AGENT)
	_label("agent_start", Vector3(a.x + 0.5, 1.15, a.y + 0.5), COL_AGENT, 40)
	for ex: Dictionary in ml.call("exits"):
		var ec: Vector2i = ex["cell"]
		_rect_lines(Rect2(Vector2(ec), Vector2.ONE), 0.0, COL_EXIT)
		_label("exit %s" % ex["side"], Vector3(ec.x + 0.5, 0.4, ec.y + 0.5), COL_EXIT, 40)
	for id in (ml.get("regions") as Dictionary).keys():
		var box: AABB = MapLayoutRef.to_world_box(ml.call("resolve", str(id))["box"])
		_box_lines(box, COL_REGION)
		_label(str(id), box.position + Vector3(box.size.x * 0.5, box.size.y + 0.15, 0.0), COL_REGION, 48)
	for id in (ml.get("poi") as Dictionary).keys():
		var r: Dictionary = ml.call("resolve", str(id))
		var p: Vector3 = MapLayoutRef.to_world(r["point"])
		_pin(p, 0.6, COL_POI)
		if (r["box"] as AABB).size != Vector3.ZERO:
			_box_lines(MapLayoutRef.to_world_box(r["box"]), COL_POI)
		_label(str(id), p + Vector3(0.0, 0.75, 0.0), COL_POI, 40)
	if not rail_id.is_empty():
		var rl: Dictionary = ml.call("rail", rail_id)
		var prev: Variant = null
		for i: int in range((rl.get("keys", []) as Array).size()):
			var k: Dictionary = rl["keys"][i]
			var tg: Array = k["target"] if k.get("target", null) is Array else [k.get("target", "@map")]
			var c := Vector3.ZERO
			for t in tg:
				c += MapLayoutRef.to_world_box(ml.call("resolve", str(t))["box"]).get_center()
			c /= float(tg.size())
			c.y = LIFT
			_pin(c, 0.4, COL_RAIL)
			_label("%s #%d %s %s" % [rail_id, i, k.get("frame", "wide"), k.get("view", "")], c + Vector3(0.0, 0.55, 0.0), COL_RAIL, 36)
			if prev != null:
				_line(prev, c, COL_RAIL)
			prev = c
	_mesh.surface_end()
	print("[LAYOUT-OVERLAY] %d region(s), %d poi, %d exit(s), rail '%s'" % [(ml.get("regions") as Dictionary).size(),
		(ml.get("poi") as Dictionary).size(), (ml.call("exits") as Array).size(), rail_id])


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


func _rect_lines(r: Rect2, y: float, c: Color, dashed: bool = false) -> void:
	var p: Array = [Vector3(r.position.x, y + LIFT, r.position.y), Vector3(r.end.x, y + LIFT, r.position.y),
		Vector3(r.end.x, y + LIFT, r.end.y), Vector3(r.position.x, y + LIFT, r.end.y)]
	for i: int in range(4):
		if dashed:
			_dashed(p[i], p[(i + 1) % 4], c)
		else:
			_line(p[i], p[(i + 1) % 4], c)


func _dashed(a: Vector3, b: Vector3, c: Color) -> void:
	var n: int = maxi(1, int(a.distance_to(b) / 0.5))
	for i: int in range(0, n, 2):
		_line(a.lerp(b, float(i) / float(n)), a.lerp(b, float(mini(i + 1, n)) / float(n)), c)


func _box_lines(box: AABB, c: Color) -> void:
	var lo: Vector3 = box.position + Vector3(0.0, LIFT, 0.0)
	var hi: Vector3 = box.end
	var xs: Array = [lo.x, hi.x]
	var ys: Array = [lo.y, hi.y]
	var zs: Array = [lo.z, hi.z]
	for y in ys:
		_line(Vector3(xs[0], y, zs[0]), Vector3(xs[1], y, zs[0]), c)
		_line(Vector3(xs[1], y, zs[0]), Vector3(xs[1], y, zs[1]), c)
		_line(Vector3(xs[1], y, zs[1]), Vector3(xs[0], y, zs[1]), c)
		_line(Vector3(xs[0], y, zs[1]), Vector3(xs[0], y, zs[0]), c)
	for x in xs:
		for z in zs:
			_line(Vector3(x, ys[0], z), Vector3(x, ys[1], z), c)


func _pin(p: Vector3, h: float, c: Color) -> void:
	var base := Vector3(p.x, maxf(p.y, 0.0) + LIFT, p.z)
	_line(base, base + Vector3(0.0, h, 0.0), c)
	_line(base + Vector3(-0.15, 0.0, 0.0), base + Vector3(0.15, 0.0, 0.0), c)
	_line(base + Vector3(0.0, 0.0, -0.15), base + Vector3(0.0, 0.0, 0.15), c)


func _label(text: String, at: Vector3, c: Color, px: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.modulate = c
	l.font_size = px
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 8
	l.no_depth_test = true
	add_child(l)
