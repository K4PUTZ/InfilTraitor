## GlassVoxelFall3D — G-D55 as the Director refined it (2026-10-10): the glass that lost its support falls VOXEL BY VOXEL, each a small
## block of the pane carrying its own piece of the crack, and only becomes shards where it hits what is under it.
##
## *"Tudo acontecendo ao mesmo tempo, com variações internas de velocidade e ângulo […] voxels mais longes e mais baixos caem primeiro,
## voxels mais perto e mais altos caem depois. Mas é apenas uma leve influência […] Deixa os voxels +aprox 1/4 de segundo parados antes
## de cair […] randomizado entre 1/3 e 1/5."*
##
## THE MOTION IS CLOSED FORM, per voxel (B4: every number hashed off its base cell, never `randf`): it rests `wait` frames (1/5..1/3 s,
## minus a slight lead for the far and low ones), then falls under its own g (a spread of g), with its own small push (up, out along
## the pane's normal, sideways) and its own tumble (a hashed axis and speed); it stops at the first frame its lowest corner reaches the
## top of what stands under its column (the pane's base, a floor) — so the impact frame and the impact point are known at the start,
## and the shard rain for the whole event is ONE overlay whose flights start at those frames and points.
##
## DRAWING: a handful of MultiMeshes, never a node per voxel (the Mali pays per draw): per (material, pane orientation) the broad
## faces on the pane's material and the thickness on its edge twin (every edge marked broken: the rim ink), and per live crack one
## quad per voxel it covers, on the crack's own material in its per-voxel mode (`crack_per_voxel`: INSTANCE_CUSTOM.xy is the voxel's
## offset in the crack, so the ink is the pane's own). The body materials are copies with the opening cut off (a falling voxel is
## not in the pane any more) and the rim ink read in model space (it does not slide over a moving voxel).
##
## Aged in drawn frames, 60 per second, never seconds: a stalled frame must not swallow the fall.
class_name GlassVoxelFall3D
extends Node3D

static var WAIT_FRAMES: Vector2 = Vector2(12.0, 20.0)   ## 1/5 .. 1/3 s, hashed per voxel
static var ORDER_LEAD_FRAMES: float = 5.0               ## at most this much earlier for the farthest / lowest (a slight influence)
static var GRAVITY: float = 9.8                          ## GU / s² (1 GU ~ 1 m)
static var GRAVITY_SPREAD: float = 0.22                  ## a voxel's g is g × [1 - this, 1]
static var POP_UP: Vector2 = Vector2(-0.4, 0.7)          ## GU / s, the vertical push at release
static var PUSH_OUT: Vector2 = Vector2(0.05, 0.55)       ## GU / s along the pane's normal (the side hashed)
static var PUSH_SIDE: float = 0.3                        ## GU / s along the run, ±
static var TUMBLE: Vector2 = Vector2(1.5, 8.0)           ## rad / s about a hashed axis
const MAX_FALL_FRAMES: int = 240

var _unit: float = 0.125
var _voxels: Array = []           ## per voxel: {centre, start, impact, g, v, axis, w, x_normal, mm_body: [mm, i], cracks: [[mm, i]]}
var _bodies: Array = []           ## the body MultiMeshes
var _frame: int = 0
var _last: int = 0
var _on_impact: Callable          ## (Array of landings that hit this frame) -> void
var _started: bool = false
var _body_nodes: Array = []    ## shown at `start()` (the frame the board's chunks drop the voxels)
var _crack_nodes: Array = []   ## shown at `show_cracks()` (the step the board cuts them out of the pane's crack), or at `start()`


## `entries`: {x, y, level, material, face, score (0..1, 1 = falls first), floor_y (geometry-root y of what stands under it),
## landing}. `live` is the Board3DLive (materials, ground). `cracks`: the VoxelBoard's live crack records. Builds the meshes now (at
## rest) and computes every voxel's whole fall. Returns the shard flights for one rain: {landing fields…, from3, t0, pop}.
func setup(live: Node, entries: Array, cracks: Array, on_impact: Callable) -> Array:
	name = "GlassVoxelFall"
	_unit = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	_on_impact = on_impact
	var groups: Dictionary = {}   ## Vector2i(material, x_normal) -> Array of voxel indices
	var flights: Array = []
	var root_xf: Transform3D = live.call("geometry_root_transform")
	for e: Dictionary in entries:
		var vx: Dictionary = _motion(e)
		vx["centre"] = live.call("voxel_centre_local", int(e["x"]), int(e["y"]), int(e["level"]))
		vx["x_normal"] = int(e["face"]) == 0 or int(e["face"]) == 2
		vx["landing"] = e["landing"]
		vx["cell"] = Vector3i(int(e["x"]), int(e["y"]), int(e["level"]))
		vx["cracks"] = []
		_solve_impact(vx, float(e["floor_y"]))
		var gk := Vector2i(int(e["material"]), 1 if vx["x_normal"] else 0)
		if not groups.has(gk):
			groups[gk] = []
		(groups[gk] as Array).append(_voxels.size())
		_voxels.append(vx)
		_last = maxi(_last, int(vx["start"]) + int(vx["impact"]))
		if not (e["landing"] as Dictionary).is_empty():
			var row: Dictionary = (e["landing"] as Dictionary).duplicate()
			row["from3"] = root_xf * (_transform_at(vx, int(vx["impact"])).origin)
			row["t0"] = int(vx["start"]) + int(vx["impact"])
			row["pop"] = 1.6
			flights.append(row)
	## Bodies: per (material, orientation) the broad faces and the thickness, sharing instance indices.
	for gk: Vector2i in groups:
		var mats: Array = live.call("glass_fall_materials", gk.x)
		if mats.is_empty():
			continue
		var members: Array = groups[gk]
		var broad: MultiMesh = _multimesh(_cube(gk.y == 1, true), members.size())
		var edge: MultiMesh = _multimesh(_cube(gk.y == 1, false), members.size())
		for k: int in range(members.size()):
			(_voxels[members[k]] as Dictionary)["body"] = [broad, edge, k]
		_add_instance(broad, mats[0], 0.0)
		_add_instance(edge, mats[1], -0.05)
		_bodies.append(broad)
		_bodies.append(edge)
	## Cracks: per live crack, a quad on every voxel it covers.
	for rec: Dictionary in cracks:
		_add_crack(rec)
	var never: int = 0
	var impacts := PackedInt32Array()
	for vx: Dictionary in _voxels:
		impacts.append(int(vx["impact"]))
		if int(vx["impact"]) >= MAX_FALL_FRAMES:
			never += 1
	impacts.sort()
	print_debug("[GLASS-FALL] %d voxel(s): impact after %d..%d frame(s) (median %d), %d never meet a floor; %d crack layer(s)"
		% [_voxels.size(), impacts[0], impacts[impacts.size() - 1], impacts[impacts.size() / 2], never, get_child_count() - _bodies.size()])
	_update(0)
	return flights


## The hashed motion of one voxel.
func _motion(e: Dictionary) -> Dictionary:
	var h: int = FacadeSampler._fnv1a_hash("GLASSVOXFALL:%d,%d,%d" % [int(e["x"]), int(e["y"]), int(e["level"])])
	var u := func(salt: String) -> float: return float(FacadeSampler._fnv1a_continue(h, salt) % 100000) / 100000.0
	var wait: float = lerpf(WAIT_FRAMES.x, WAIT_FRAMES.y, u.call("wait")) + ORDER_LEAD_FRAMES * (1.0 - float(e.get("score", 0.5)))
	var x_normal: bool = int(e["face"]) == 0 or int(e["face"]) == 2
	var n: Vector3 = Vector3(1, 0, 0) if x_normal else Vector3(0, 0, 1)
	var run: Vector3 = Vector3(0, 0, 1) if x_normal else Vector3(1, 0, 0)
	var side: float = 1.0 if u.call("side") < 0.5 else -1.0
	var v: Vector3 = n * side * lerpf(PUSH_OUT.x, PUSH_OUT.y, u.call("out")) + run * (u.call("run") * 2.0 - 1.0) * PUSH_SIDE \
		+ Vector3.UP * lerpf(POP_UP.x, POP_UP.y, u.call("up"))
	var axis := Vector3(u.call("ax") * 2.0 - 1.0, u.call("ay") * 2.0 - 1.0, u.call("az") * 2.0 - 1.0)
	if axis.length() < 0.05:
		axis = run
	return {
		"start": int(roundf(wait)),
		"g": GRAVITY * (1.0 - GRAVITY_SPREAD * u.call("g")) / 3600.0,
		"v": v / 60.0,
		"axis": axis.normalized(),
		"w": lerpf(TUMBLE.x, TUMBLE.y, u.call("w")) * (1.0 if u.call("ws") < 0.5 else -1.0) / 60.0,
	}


## The voxel's transform `f` frames after it was released (geometry-root space).
func _transform_at(vx: Dictionary, f: int) -> Transform3D:
	var t: float = float(f)
	var basis := Basis(vx["axis"], float(vx["w"]) * t)
	var c: Vector3 = vx["centre"] + (vx["v"] as Vector3) * t + Vector3(0.0, -0.5 * float(vx["g"]) * t * t, 0.0)   ## GU (1 unit = 1 GU)
	return Transform3D(basis, c)


## The first frame the voxel's lowest corner is at or below `floor_y`.
func _solve_impact(vx: Dictionary, floor_y: float) -> void:
	## A cube's lowest corner under a rotation is the centre less half × (|row y| of the basis), summed: no corner loop.
	var half: float = _unit * 0.5
	var axis: Vector3 = vx["axis"]
	var w: float = float(vx["w"])
	var c0: Vector3 = vx["centre"]
	var v: Vector3 = vx["v"]
	var g: float = float(vx["g"])
	for f: int in range(1, MAX_FALL_FRAMES):
		var t: float = float(f)
		var b := Basis(axis, w * t)
		var reach: float = half * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))
		if c0.y + v.y * t - 0.5 * g * t * t - reach <= floor_y:
			vx["impact"] = f
			return
	vx["impact"] = MAX_FALL_FRAMES


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


func _add_instance(mm: MultiMesh, mat: Material, sort: float, crack: bool = false) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.sorting_offset = sort
	mmi.custom_aabb = AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4))
	mmi.visible = false
	(_crack_nodes if crack else _body_nodes).append(mmi)
	add_child(mmi)


## One voxel as a cube centred on the origin. `broad` = only the two faces along the pane's normal (the pane's material); otherwise
## the other four (the thickness, the top, the bottom: the edge twin, marked broken, COLOR.b = 0). Triangles wound as the board's.
func _cube(x_normal: bool, broad: bool) -> ArrayMesh:
	var h: float = _unit * 0.5
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var normal_axis: Vector3 = Vector3.RIGHT if x_normal else Vector3.BACK
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for d: Vector3 in dirs:
		var is_broad: bool = absf(d.dot(normal_axis)) > 0.5
		if is_broad != broad:
			continue
		var a: Vector3 = Vector3(d.y, d.z, d.x) if absf(d.x) < 0.5 else Vector3(0, 1, 0)
		var b: Vector3 = d.cross(a)
		var base: int = verts.size()
		for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			verts.append((d + a * k.x + b * k.y) * h)
			norms.append(d)
			cols.append(Color(1, 1, 1.0 if broad else 0.0, 1))
		var tri: Array = [[0, 1, 2], [0, 2, 3]]
		for t: Array in tri:
			var p0: Vector3 = verts[base + t[0]]
			var p1: Vector3 = verts[base + t[1]]
			var p2: Vector3 = verts[base + t[2]]
			if (p1 - p0).cross(p2 - p0).dot(d) > 0.0:   ## the board's convention (`SurfaceData.add_tri`)
				idx.append_array([base + t[0], base + t[2], base + t[1]])
			else:
				idx.append_array([base + t[0], base + t[1], base + t[2]])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## One live crack: a one-voxel quad on the front face of every falling voxel inside its pane rectangle, on its own material in
## per-voxel mode. The quad is built in the voxel's frame (centred), on the record's face, run and up as the crack's own quad.
func _add_crack(rec: Dictionary) -> void:
	if not rec.has("params") or not bool(rec.get("visible", true)):
		return
	var p: Dictionary = rec["params"]
	var run_is_x: bool = int(rec["run_axis"]) == 0
	var cell: Vector2i = rec["impact_cell"]
	var cross: int = cell.y if run_is_x else cell.x
	var run_c: int = cell.x if run_is_x else cell.y
	var lo: Vector2 = p.get("crack_pane_lo", Vector2(-1000, -1000))
	var hi: Vector2 = p.get("crack_pane_hi", Vector2(1000, 1000))
	var members: Array = []
	for i: int in range(_voxels.size()):
		var c: Vector3i = (_voxels[i] as Dictionary)["cell"]
		if (c.y if run_is_x else c.x) != cross:
			continue
		var off := Vector2(float((c.x if run_is_x else c.y) - run_c), float(c.z - int(rec["impact_level"])))
		if off.x < lo.x - 0.5 or off.x > hi.x + 0.5 or off.y < lo.y - 0.5 or off.y > hi.y + 0.5:
			continue
		members.append([i, off])
	if members.is_empty():
		return
	var face: int = int(rec.get("face", Face.SW))
	var normal: Vector3 = {Face.SW: Vector3.BACK, Face.SE: Vector3.RIGHT, Face.NE: Vector3.FORWARD, Face.NW: Vector3.LEFT}.get(face, Vector3.BACK)
	var run_dir: Vector3 = Vector3.RIGHT if run_is_x else Vector3.BACK
	var h: float = _unit * 0.5
	var lift: float = _unit * 0.05
	var centre: Vector3 = normal * (h + lift)
	var verts := PackedVector3Array([centre - run_dir * h + Vector3.UP * h, centre + run_dir * h + Vector3.UP * h,
		centre + run_dir * h - Vector3.UP * h, centre - run_dir * h - Vector3.UP * h])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm: MultiMesh = _multimesh(quad, members.size())
	var mat := ShaderMaterial.new()
	mat.shader = load(GlassCrackMirror3D.SHADER_PATH) as Shader
	for param: String in GlassCrackMirror3D.MIRRORED:
		if p.get(param) != null:
			mat.set_shader_parameter(param, p[param])
	mat.set_shader_parameter("crack_per_voxel", true)
	mat.render_priority = 1
	for k: int in range(members.size()):
		var off: Vector2 = members[k][1]
		mm.set_instance_custom_data(k, Color(off.x, off.y, 0.0, 0.0))
		((_voxels[members[k][0]] as Dictionary)["cracks"] as Array).append([mm, k])
	_add_instance(mm, mat, 0.05, true)


func show_cracks() -> void:
	for n: Node3D in _crack_nodes:
		n.visible = true


func start() -> void:
	_started = true
	show_cracks()
	for n: Node3D in _body_nodes:
		n.visible = true


func _process(_delta: float) -> void:
	if not _started:
		return
	_frame += 1
	_update(_frame)
	if _frame > _last + 2:
		queue_free()


func _update(frame: int) -> void:
	var hits: Array = []
	for vx: Dictionary in _voxels:
		var f: int = frame - int(vx["start"])
		var xf: Transform3D
		if f <= 0:
			xf = Transform3D(Basis.IDENTITY, vx["centre"])
		elif f < int(vx["impact"]):
			xf = _transform_at(vx, f)
		else:
			xf = Transform3D(Basis().scaled(Vector3.ZERO), vx["centre"])   ## shattered: the rain carries it now
			if f == int(vx["impact"]) and not (vx["landing"] as Dictionary).is_empty():
				hits.append(vx["landing"])
		if vx.has("body"):
			var b: Array = vx["body"]
			(b[0] as MultiMesh).set_instance_transform(int(b[2]), xf)
			(b[1] as MultiMesh).set_instance_transform(int(b[2]), xf)
		for c: Array in vx["cracks"]:
			(c[0] as MultiMesh).set_instance_transform(int(c[1]), xf)
	if not hits.is_empty() and _on_impact.is_valid():
		_on_impact.call(hits)
