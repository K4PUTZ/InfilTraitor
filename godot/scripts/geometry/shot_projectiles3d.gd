## ShotProjectiles3D — the bodies a shot throws that are not a round's streak (MOVEMENT §11.6 step 5, Director 2026-11-17).
##
## One per board, a child of it (board-local space, which is the base space since rotation is camera-only), made on the first use
## (`of()`), like `ShellCasings3D`. Four kinds, chosen by the weapon row's `fx.projectile` (`WeaponDef`):
##   · `dart`   — the model's own dart (`fx.part`) flies the whole way to the impact the shot resolved and BITES there, tip first.
##   · `probes` — the taser's two probes fly on two wires, spark where they bite; the wires go, the probes stay.
##   · `hook`   — the grapple's hook (`fx.part`) flies on its line, bites, holds, and is wound back to the muzzle; the caller's
##                handle reads `winding` (the drum turns) and `done` (the hook is back on the gun).
##   · `flare`  — a burning flare flies to the wall, drops to the floor at its foot, burns with its own glow and goes out (no light
##                on the board: the Director's ruling).
## WEAPON D21's second amendment: decoration that STAYS. The impact was resolved before anything flies; nothing here decides it.
## The darts and probes are RECORDED (`records_for_save()` / `restore()`): the record is kept on every device and only drawing
## them follows `CosmeticDensity` (below `persist_min_factor` they go once their bite has been seen), so one save is one world on
## every handset. A dart whose wall voxel is destroyed falls to the floor and lies there (`on_voxel_destroyed`).
class_name ShotProjectiles3D
extends Node3D

const NODE_NAME := "ShotProjectiles"
const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const WeaponRegistryRef = preload("res://godot/scripts/systems/destruction/weapon_registry.gd")

## Stats are `var` (rule 1). Speeds in board units (GU) per second; sizes in metres, scaled by the gun's `units_per_m`.
var dart_speed: float = 22.0
var probe_speed: float = 20.0
var hook_speed: float = 16.0
var hook_hold_s: float = 0.45
var hook_wind_speed: float = 9.0
var flare_speed: float = 18.0
var flare_burn_s: float = 6.0
var bite_m: float = 0.02               ## how deep a tip goes into what it struck
var gravity_m: float = 9.8
var wire_life_s: float = 1.4
var spark_life_s: float = 0.35
var probe_spread_m: float = 0.05       ## the two probes' vertical spread at the target
var line_radius_m: float = 0.006
var wire_radius_m: float = 0.0035
var flare_glow_m: float = 0.035
## Drawn only on a device whose `CosmeticDensity.factor` reaches this; the record is kept everywhere.
var persist_min_factor: float = 0.7
var persist_show_s: float = 2.0        ## below the factor, how long a bitten dart is still shown

var _board: Node3D = null
var _flights: Array = []               ## live flights (Dictionaries, see the launch functions)
var _stuck: Array = []                 ## [{"rec": Dictionary, "node": Node3D or null}]
var _part_protos: Dictionary = {}      ## "weapon|part" -> MeshInstance3D prototype with board-lit materials
var _lit: Dictionary = {}              ## source Material -> ShaderMaterial (one board-lit copy each)


## The board's projectiles, made on first use.
static func of(board: Node3D) -> Node3D:
	var found := board.get_node_or_null(NODE_NAME) as Node3D
	if found != null:
		return found
	var made = load("res://godot/scripts/geometry/shot_projectiles3d.gd").new()
	made.name = NODE_NAME
	made._board = board
	board.add_child(made)
	return made


## ---------------------------------------------------------------------------------------------------------------------------
## Model surgery, shared with `ActorMesh3D` (the gun in the hand splits the same pieces off, so they can be hidden or turned).

## The piece of `model` named `part_name`: a node of that name, or a surface whose material bears that name, split off into a
## MeshInstance3D of its own (a child of the mesh it came from, so it keeps its place). Null when neither exists.
static func split_part(model: Node, part_name: String) -> Node3D:
	if part_name == "":
		return null
	var by_name := model.find_child(part_name, true, false) as Node3D
	if by_name != null:
		return by_name
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mesh := m.mesh as ArrayMesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(s)
			if mat == null or mat.resource_name != part_name:
				continue
			var piece := ArrayMesh.new()
			var rest := ArrayMesh.new()
			for k in range(mesh.get_surface_count()):
				var into: ArrayMesh = piece if k == s else rest
				into.add_surface_from_arrays(mesh.surface_get_primitive_type(k), mesh.surface_get_arrays(k))
				into.surface_set_material(into.get_surface_count() - 1, mesh.surface_get_material(k))
			m.mesh = rest
			var out := MeshInstance3D.new()
			out.name = part_name
			out.mesh = piece
			m.add_child(out)
			return out
	return null


## A copy of the bow-string mesh `mi` FIRED: each vertex moved along the model's +X by how far the drawn V sits behind the line
## between the two cam tips, so the string lies straight across the bow's front and keeps its own thickness.
static func fired_string_mesh(mi: MeshInstance3D) -> ArrayMesh:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return null
	var out := ArrayMesh.new()
	for s in range(src.get_surface_count()):
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var x_min: float = INF
		var x_max: float = -INF
		var z_max: float = 0.0
		for v in verts:
			x_min = minf(x_min, v.x)
			x_max = maxf(x_max, v.x)
			z_max = maxf(z_max, absf(v.z))
		if z_max > 0.0:
			for i in range(verts.size()):
				var v: Vector3 = verts[i]
				var centre_x: float = lerpf(x_min, x_max, absf(v.z) / z_max)
				verts[i] = Vector3(v.x - centre_x + x_max, v.y, v.z)
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


## ---------------------------------------------------------------------------------------------------------------------------
## Launches. `from` / `to` are board-local; `normal` the struck face's outward direction (ZERO: none, a prop or the open floor);
## `host` the struck voxel (x, y, level), or Vector3i.MAX for none.

## A model piece (`dart`): `part` is the gun's piece in GLOBAL space at the shot (its look is copied, the gun's own is hidden by
## the caller). Returns false when the board cannot take it.
func launch_dart(def: WeaponDef, part: Node3D, from: Vector3, to: Vector3, normal: Vector3, host: Vector3i) -> bool:
	var body: Node3D = _body_from(def, part, from, to)
	if body == null:
		return false
	print_debug("[SHOT-PROJECTILE] dart from %s to %s (%.2f GU, host %s)" % [from, to, from.distance_to(to), host])
	_flights.append({"kind": "dart", "body": body, "from": from, "to": to + _dir(from, to) * bite_m * _gun_upm(part),
		"t": 0.0, "len": from.distance_to(to) / dart_speed, "weapon": def.id, "part": def.fx_part, "host": host})
	set_process(true)
	return true


## The hook on its line (`hook`): `muzzle` answers the live muzzle (board-local) every frame, so the line stays on the gun while
## the arm moves. Returns the handle the gun reads: {"winding": bool, "done": bool}; empty when the board cannot take it.
func launch_hook(def: WeaponDef, part: Node3D, from: Vector3, to: Vector3, muzzle: Callable, units_per_m: float) -> Dictionary:
	var body: Node3D = _body_from(def, part, from, to)
	if body == null:
		return {}
	var handle := {"winding": false, "done": false}
	var line := _line_node(Color(0.62, 0.58, 0.5), line_radius_m * units_per_m)
	print_debug("[SHOT-PROJECTILE] hook from %s to %s" % [from, to])
	_flights.append({"kind": "hook", "body": body, "line": line, "from": from, "to": to + _dir(from, to) * bite_m * units_per_m,
		"t": 0.0, "len": from.distance_to(to) / hook_speed, "muzzle": muzzle, "handle": handle, "phase": "out"})
	set_process(true)
	return handle


## The taser's two probes (`probes`), made here (the model carries none), on two wires from the live muzzle.
func launch_probes(def: WeaponDef, from: Vector3, to: Vector3, normal: Vector3, host: Vector3i, muzzle: Callable,
		units_per_m: float) -> bool:
	print_debug("[SHOT-PROJECTILE] probes from %s to %s" % [from, to])
	var spread := Vector3(0.0, probe_spread_m * units_per_m, 0.0)
	for k in range(2):
		var aim: Vector3 = to + spread * (0.5 if k == 0 else -0.5)
		var body: Node3D = _probe_node(units_per_m)
		add_child(body)
		body.transform = _flight_xform(body, from, aim)
		var wire := _line_node(Color(0.15, 0.15, 0.16), wire_radius_m * units_per_m)
		_flights.append({"kind": "probe", "body": body, "wire": wire, "from": from, "to": aim + _dir(from, aim) * bite_m * units_per_m,
			"t": 0.0, "len": from.distance_to(aim) / probe_speed, "muzzle": muzzle, "weapon": def.id, "part": "", "host": host,
			"color": def.fx_color, "upm": units_per_m, "wire_t": 0.0})
	set_process(true)
	return true


## The flare (`flare`): to the wall, then down to its foot, burning.
func launch_flare(def: WeaponDef, from: Vector3, to: Vector3, units_per_m: float) -> bool:
	var glow := _glow_node(def.fx_color, flare_glow_m * units_per_m)
	add_child(glow)
	glow.position = from
	print_debug("[SHOT-PROJECTILE] flare from %s to %s" % [from, to])
	_flights.append({"kind": "flare", "body": glow, "from": from, "to": to - _dir(from, to) * flare_glow_m * units_per_m,
		"t": 0.0, "len": from.distance_to(to) / flare_speed, "phase": "out", "vel": Vector3.ZERO, "upm": units_per_m, "burn": 0.0,
		"size": flare_glow_m * units_per_m})
	set_process(true)
	return true


## The prototypes are never in the tree: freed with the board.
func _exit_tree() -> void:
	for proto in _part_protos.values():
		if proto != null and is_instance_valid(proto):
			(proto as Node).free()
	_part_protos.clear()


## ---------------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var ended: Array = []
	for f: Dictionary in _flights:
		if _step(f, delta):
			ended.append(f)
	for f: Dictionary in ended:
		_flights.erase(f)
	for s: Dictionary in _stuck:
		if s.has("fall"):
			_fall_step(s, delta)
		elif s.has("hide_in"):
			s["hide_in"] = float(s["hide_in"]) - delta
			if float(s["hide_in"]) <= 0.0 and s["node"] != null:
				(s["node"] as Node3D).queue_free()
				s["node"] = null
				s.erase("hide_in")
	if _flights.is_empty() and not _stuck.any(func(s: Dictionary) -> bool: return s.has("fall") or s.has("hide_in")):
		set_process(false)


## One flight's frame; true when it is over.
func _step(f: Dictionary, delta: float) -> bool:
	var kind: String = f["kind"]
	if kind == "hook":
		return _hook_step(f, delta)
	if kind == "flare" and String(f["phase"]) != "out":
		return _flare_burn_step(f, delta)
	f["t"] = float(f["t"]) + delta
	var u: float = clampf(float(f["t"]) / maxf(float(f["len"]), 0.001), 0.0, 1.0)
	var body: Node3D = f["body"]
	body.position = (f["from"] as Vector3).lerp(f["to"], u)
	if kind == "probe":
		_wire_to(f["wire"], f["muzzle"], body.position)
	if u < 1.0:
		return false
	match kind:
		"dart":
			_stick(body, {"k": "dart", "w": f["weapon"], "p": f["part"], "h": f["host"]}, f["host"] == Vector3i.MAX)
			return true
		"probe":
			_stick(body, {"k": "probe", "w": f["weapon"], "p": "", "h": f["host"]}, f["host"] == Vector3i.MAX)
			_spark(body.position, f["color"], float(f["upm"]))
			f["kind"] = "wire"
			return _wire_only(f)
		"flare":
			f["phase"] = "drop"
			return false
	return true


## After the probes bite, the wires stay a moment, then go.
func _wire_only(f: Dictionary) -> bool:
	var wire: Node3D = f["wire"]
	var timer := get_tree().create_timer(wire_life_s)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(wire):
			wire.queue_free())
	return true


func _hook_step(f: Dictionary, delta: float) -> bool:
	var body: Node3D = f["body"]
	var muzzle: Vector3 = (f["muzzle"] as Callable).call()
	var handle: Dictionary = f["handle"]
	match String(f["phase"]):
		"out":
			f["t"] = float(f["t"]) + delta
			var u: float = clampf(float(f["t"]) / maxf(float(f["len"]), 0.001), 0.0, 1.0)
			body.position = (f["from"] as Vector3).lerp(f["to"], u)
			if u >= 1.0:
				f["phase"] = "hold"
				f["t"] = 0.0
		"hold":
			f["t"] = float(f["t"]) + delta
			if float(f["t"]) >= hook_hold_s:
				f["phase"] = "wind"
				handle["winding"] = true
		"wind":
			if muzzle == Vector3.INF:   ## the gun went away: the hook is simply back
				muzzle = body.position
			var to_gun: Vector3 = muzzle - body.position
			var step: float = hook_wind_speed * delta
			if to_gun.length() <= step:
				body.queue_free()
				(f["line"] as Node3D).queue_free()
				handle["winding"] = false
				handle["done"] = true
				return true
			body.position += to_gun.normalized() * step
	if muzzle != Vector3.INF:
		_wire_to(f["line"], f["muzzle"], body.position)
	return false


func _flare_burn_step(f: Dictionary, delta: float) -> bool:
	var glow: Node3D = f["body"]
	var upm: float = float(f["upm"])
	if String(f["phase"]) == "drop":
		var vel: Vector3 = f["vel"]
		vel.y -= gravity_m * delta
		var pos: Vector3 = glow.position + vel * upm * delta
		var floor_y: float = float(_board.call("stand_height", pos)) if _board.has_method("stand_height") else 0.0
		var rest_y: float = floor_y + float(f["size"])
		if pos.y <= rest_y:
			pos.y = rest_y
			f["phase"] = "burn"
		f["vel"] = vel
		glow.position = pos
	f["burn"] = float(f["burn"]) + delta
	var left: float = flare_burn_s - float(f["burn"])
	var flicker: float = 0.85 + 0.15 * sin(float(f["burn"]) * 37.0) * sin(float(f["burn"]) * 13.0)
	glow.scale = Vector3.ONE * flicker * clampf(left / 1.0, 0.0, 1.0)
	if left <= 0.0:
		glow.queue_free()
		return true
	return false


## A bitten body joins the record; drawn on while the device allows, else shown briefly.
func _stick(body: Node3D, rec: Dictionary, falls: bool = false) -> void:
	if body.get_child_count() == 1 and not body.has_meta("rel") and body.get_child(0).has_meta("rel"):
		var copy := body.get_child(0) as Node3D   ## the flight's pivot goes: the copy alone, at its place in the board
		var at: Transform3D = body.transform * copy.transform
		body.remove_child(copy)
		add_child(copy)
		copy.transform = at
		body.queue_free()
		body = copy
	rec["t"] = _xform_to_array(body.transform)
	print_debug("[SHOT-PROJECTILE] %s bit at %s (%s), %d on the map" % [rec["k"], body.position, "falls" if falls else "stays", _stuck.size() + 1])
	var entry := {"rec": rec, "node": body}
	if CosmeticDensity.factor < persist_min_factor:
		entry["hide_in"] = persist_show_s
	if falls:   ## it struck nothing (a void round, D15): it drops where its flight ended
		entry["fall"] = 0.0
		entry["vy"] = 0.0
	_stuck.append(entry)


## A voxel went: whatever bit it falls to the floor and lies there (its record follows).
func on_voxel_destroyed(grid_pos: Vector2i, level: int) -> void:
	var key := Vector3i(grid_pos.x, grid_pos.y, level)
	for s: Dictionary in _stuck:
		var rec: Dictionary = s["rec"]
		if rec["h"] is Vector3i and rec["h"] == key:
			rec["h"] = Vector3i.MAX
			print_debug("[SHOT-PROJECTILE] %s loses its voxel %s and falls" % [rec["k"], key])
			s["fall"] = 0.0
			s["vy"] = 0.0
			set_process(true)


func _fall_step(s: Dictionary, delta: float) -> void:
	var rec: Dictionary = s["rec"]
	var x: Transform3D = _array_to_xform(rec["t"])
	var rel: Transform3D = s["node"].get_meta("rel", Transform3D.IDENTITY) if s["node"] != null else Transform3D.IDENTITY
	var vy: float = float(s["vy"]) - gravity_m * delta
	x.origin.y += vy * delta
	var at: Vector3 = x * rel.origin   ## the piece itself, not the gun's origin its copy is framed by
	var floor_y: float = float(_board.call("stand_height", at)) if _board.has_method("stand_height") else 0.0
	if at.y <= floor_y:
		## lying: the barrel axis turned level about the piece, its heading kept
		var fwd: Vector3 = x.basis.x
		var flat := Vector3(fwd.x, 0.0, fwd.z)
		if flat.length() > 0.001:
			var level := Basis(Quaternion(fwd.normalized(), flat.normalized()))
			x = Transform3D(level, at - level * at) * x
		x.origin.y += floor_y - (x * rel.origin).y
		s.erase("fall")
		s.erase("vy")
	else:
		s["vy"] = vy
	rec["t"] = _xform_to_array(x)
	if s["node"] != null:
		(s["node"] as Node3D).transform = x


## ---------------------------------------------------------------------------------------------------------------------------
## The save (SaveState): plain arrays, board-local (= base) transforms. Restoring rebuilds each body from its weapon's model.

func records_for_save() -> Array:
	var out: Array = []
	for s: Dictionary in _stuck:
		var rec: Dictionary = s["rec"]
		var h: Vector3i = rec["h"]
		out.append({"k": rec["k"], "w": rec["w"], "p": rec["p"], "t": rec["t"],
			"h": [] if h == Vector3i.MAX else [h.x, h.y, h.z]})
	return out


func restore(records: Array) -> void:
	for s: Dictionary in _stuck:
		if s["node"] != null:   ## out of the tree now, so the restored world never shows both for a frame
			var old := s["node"] as Node3D
			remove_child(old)
			old.queue_free()
	_stuck.clear()
	for r in records:
		if not (r is Dictionary) or not (r as Dictionary).has("t") or (r["t"] as Array).size() != 12:
			push_error("[ShotProjectiles3D] a stuck projectile's record is malformed: %s (skipped)" % str(r))
			continue
		var h: Array = r.get("h", [])
		var rec := {"k": String(r.get("k", "")), "w": String(r.get("w", "")), "p": String(r.get("p", "")), "t": r["t"],
			"h": Vector3i(int(h[0]), int(h[1]), int(h[2])) if h.size() == 3 else Vector3i.MAX}
		var node: Node3D = null
		if CosmeticDensity.factor >= persist_min_factor:
			node = _probe_node(1.0) if rec["k"] == "probe" else _part_copy(rec["w"], rec["p"])
			if node != null:
				add_child(node)
				node.transform = _array_to_xform(rec["t"])
		_stuck.append({"rec": rec, "node": node})
	print_debug("[SHOT-PROJECTILE] restored %d stuck projectile(s), %d drawn" % [_stuck.size(), _stuck.filter(func(e: Dictionary) -> bool: return e["node"] != null).size()])


func stuck_count() -> int:
	return _stuck.size()


## ---------------------------------------------------------------------------------------------------------------------------
## Bodies.

## The flying body: a PIVOT at the muzzle (`from`, what the flight moves) holding a board-lit copy of the gun's piece placed where
## the piece is now, turned about the muzzle onto the flight's line (the gun points near the target already: a small turn).
func _body_from(def: WeaponDef, part: Node3D, from: Vector3, to: Vector3) -> Node3D:
	if part == null or from.is_equal_approx(to):
		return null
	var copy: Node3D = _part_copy(def.id, def.fx_part)
	if copy == null:
		return null
	var piece: Transform3D = global_transform.affine_inverse() * part.global_transform
	var rel: Transform3D = copy.get_meta("rel", Transform3D.IDENTITY)
	var fwd: Vector3 = (piece * rel.affine_inverse()).basis.x.normalized()   ## the model's barrel is +X (WeaponDef.muzzle)
	var d: Vector3 = _dir(from, to)
	var turn := Basis(Quaternion(fwd, d)) if fwd.dot(d) > -0.999 else Basis(Vector3.UP, PI)
	var about_muzzle := Transform3D(turn, from - turn * from)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = from
	pivot.add_child(copy)
	copy.transform = Transform3D(Basis.IDENTITY, -from) * about_muzzle * piece * rel.affine_inverse()
	return pivot


## Board units per metre of the gun `part` belongs to (its global basis carries the gun's scale; the model is in metres).
func _gun_upm(part: Node3D) -> float:
	return (global_transform.affine_inverse() * part.global_transform).basis.get_scale().x


## A board-lit copy of `weapon`'s piece `part_name` (its mesh only, its frame at the piece's own origin).
func _part_copy(weapon: String, part_name: String) -> Node3D:
	var key: String = weapon + "|" + part_name
	if not _part_protos.has(key):
		_part_protos[key] = _make_proto(weapon, part_name)
	var proto: MeshInstance3D = _part_protos[key]
	if proto == null:
		return null
	return proto.duplicate() as Node3D


func _make_proto(weapon: String, part_name: String) -> MeshInstance3D:
	var w: WeaponDef = WeaponRegistryRef.shared().get_weapon(weapon)
	var scene := load(w.model_path) as PackedScene if w != null and w.model_path != "" else null
	if scene == null:
		push_error("[ShotProjectiles3D] weapon '%s' has no row or no model: no '%s' can be drawn" % [weapon, part_name])
		return null
	var model := scene.instantiate()
	var piece: Node3D = split_part(model, part_name)
	var mi := piece as MeshInstance3D
	if mi == null and piece != null:
		mi = piece.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D
	if mi == null:
		push_error("[ShotProjectiles3D] weapon '%s' has no piece '%s' (fx.part): nothing flies" % [weapon, part_name])
		model.free()
		return null
	## The piece's mesh in the frame of the model's root, so the copy is placed by the gun's own transform.
	var proto := MeshInstance3D.new()
	proto.mesh = mi.mesh
	var rel: Transform3D = Transform3D.IDENTITY
	var n: Node = mi
	while n != model and n is Node3D:
		rel = (n as Node3D).transform * rel
		n = n.get_parent()
	_light(proto)
	model.free()
	var holder := MeshInstance3D.new()   ## the duplicate is the holder; its child carries the piece's offset in the model
	holder.add_child(proto)
	proto.transform = rel
	proto.owner = holder
	holder.set_meta("rel", rel)
	return holder


func _light(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in range(mi.mesh.get_surface_count()):
		var src: Material = mi.mesh.surface_get_material(s)
		if not _lit.has(src):
			var sm := ShaderMaterial.new()
			sm.shader = BoardLook.graded_shader(SHADER_PATH)
			var std := src as BaseMaterial3D
			if std != null:
				sm.set_shader_parameter("albedo", std.albedo_color)
				if std.albedo_texture != null:
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
					sm.set_shader_parameter("has_tex", 1.0)
			if _board.has_method("register_prop_light_material"):
				_board.call("register_prop_light_material", sm)
			_lit[src] = sm
		mi.set_surface_override_material(s, _lit[src])


## A taser probe: a small barbed cylinder, cartridge-yellow, in its own frame along +X.
func _probe_node(units_per_m: float) -> Node3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 0
	var sm := _flat_lit(Color(0.9, 0.78, 0.2))
	cyl.material = sm
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(0.006, 0.03, 0.006)), Vector3(-0.015, 0.0, 0.0))
	var holder := Node3D.new()
	holder.add_child(mi)
	holder.scale = Vector3.ONE * units_per_m
	return holder


func _flat_lit(c: Color) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = BoardLook.graded_shader(SHADER_PATH)
	sm.set_shader_parameter("albedo", c)
	if _board.has_method("register_prop_light_material"):
		_board.call("register_prop_light_material", sm)
	return sm


## A line (the grapple's, a taser wire): a thin cylinder stretched between two points each frame (`_wire_to`).
func _line_node(c: Color, radius: float) -> Node3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 0
	cyl.material = _flat_lit(c)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.visible = false
	return mi


func _wire_to(line: Node3D, muzzle: Callable, end: Vector3) -> void:
	var start: Vector3 = muzzle.call()
	if start == Vector3.INF or not is_instance_valid(line):
		return
	var span: Vector3 = end - start
	var length: float = span.length()
	if length < 0.0001:
		line.visible = false
		return
	var y: Vector3 = span / length
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	line.transform = Transform3D(Basis(x, y * length, z), start + span * 0.5)
	line.visible = true


## The flare's burning head and the probes' spark: an unshaded sphere (opaque: a transparent pass costs on the Mali).
func _glow_node(c: Color, radius: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c.lerp(Color.WHITE, 0.35)
	sphere.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _spark(at: Vector3, c: Color, units_per_m: float) -> void:
	var s := _glow_node(c, 0.018 * units_per_m)
	add_child(s)
	s.position = at
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 0.1, spark_life_s).from(Vector3.ONE * 1.6)
	tw.tween_callback(s.queue_free)


## ---------------------------------------------------------------------------------------------------------------------------

func _flight_xform(body: Node3D, from: Vector3, to: Vector3) -> Transform3D:
	var d: Vector3 = _dir(from, to)
	var turn := Basis(Quaternion(Vector3.RIGHT, d)) if d.dot(Vector3.RIGHT) > -0.999 else Basis(Vector3.UP, PI)
	return Transform3D(turn.scaled(body.scale), from)


static func _dir(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = to - from
	return d.normalized() if d.length() > 0.00001 else Vector3.RIGHT


static func _xform_to_array(x: Transform3D) -> Array:
	return [x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z,
		x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]


static func _array_to_xform(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(a[3]), float(a[4]), float(a[5])),
		Vector3(float(a[6]), float(a[7]), float(a[8]))), Vector3(float(a[9]), float(a[10]), float(a[11])))
