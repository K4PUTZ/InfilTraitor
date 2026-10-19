## LiquidFalls3D — the WATERFALLS of one body of liquid (consolidation, 2026-10-18; Director: "a queda de uma cachoeira, derrubando liquido dentro do
## container"). Purely visual: the flow over a step is the plane's own (`FluidPlane` virtual pipes); this draws, at every edge `FluidPlane.falls()` finds,
## a curtain from the lip down to the surface below, arcing out a little as a jet leaves a mouth, and a ring of foam where it lands. One mesh a body,
## rebuilt from the live falls each frame while anything falls (a handful of edges: a few dozen vertices); empty and asleep otherwise.
class_name LiquidFalls3D
extends MeshInstance3D

const SHADER: Shader = preload("res://godot/shaders/liquid_fall3d.gdshader")
const UNIT: float = 1.0 / 8.0          ## a voxel of height in GU
const SEGMENTS: int = 6                ## rows of the curtain's arc
const THROW_GU: float = 0.06           ## how far the jet leaves the lip before it falls, per GU of drop (a parabola)
const SPLASH_GU: float = 0.42          ## the foam band's width across the fall
const FLOW_FULL: float = 0.12          ## the flow (voxels a round) that draws a full curtain; less is thinner
const SURFACE_LIFT: float = 0.01       ## the splash just over the sheet
const SHEET_PRIORITY: int = 0          ## `LiquidSheet3D`'s material (the default)
## FEATHERED ENDS (Director, 2026-10-18: "um feather ou um blur nessas regioes de transicao"): the curtain starts LIP_BACK_GU back over the water upstream
## (an extra row at UV.y = -LIP_UV, where the shader starts it transparent) and ends SINK_GU under the surface below, its foot fading into the froth.
const LIP_BACK_GU: float = 0.1
const LIP_UV: float = 0.15
const SINK_GU: float = 0.03

## STEAM where the curtain lands (Director, 2026-10-18: "uma fumacinha (vapor) onde a cortina atinge o container"): pale puffs through the room's
## `SmokeSparkOverlay`, anchored in 3D at the splash, a few a second a curtain, more as more falls.
## Director, 2026-10-18: "nao precisa de tanto vapor: e so uma lembranca, no local onde a cortina entra em contato com a pelicula de baixo, pra disfarcar a
## transicao": a few faint, small puffs that stay low on the contact line.
const STEAM: Color = Color(0.93, 0.95, 0.98, 0.2)
const STEAM_PER_SECOND: float = 2.5     ## puffs a second for a full curtain edge
const STEAM_SCALE: float = 0.6
const STEAM_STYLE: Dictionary = {"growth": 1.4, "damp": 3.5, "fade_in": 0.2}   ## swells a little and hardly rises

var plane: RefCounted = null
var smoke: Node = null                 ## the room's SmokeSparkOverlay (or null: no steam)
var _steam_carry: float = 0.0
var _base_y: float = 0.0
var count: int = 0                     ## the edges falling in the last frame (read by a selftest / the log)


## `base_y` is the body's bed height (the sheet's own), `params` the liquid's resolved controls (its colours).
func setup(fluid_plane: RefCounted, base_y: float, params: Dictionary) -> void:
	plane = fluid_plane
	_base_y = base_y
	name = "LiquidFalls3D"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if params.has("shallow_color"):
		material.set_shader_parameter("body_color", params["shallow_color"])
	if params.has("deep_color"):
		material.set_shader_parameter("deep_color", params["deep_color"])
	if params.has("light_color"):
		material.set_shader_parameter("light_color", params["light_color"])
	material.set_shader_parameter("time_scale", float(params.get("time_scale", 1.0)))
	## DRAWN AFTER THE SHEETS (Director, 2026-10-19: the curtain's foot was under the lower body's sheet). Both are transparent and never write depth, so Godot
	## orders them by their AABB centres: the channel's sheet (its centre mid-channel) often came AFTER the curtain and painted over its foot and its foam.
	## A higher render priority draws later; the sheets keep the default 0.
	material.render_priority = SHEET_PRIORITY + 1
	material_override = material
	set_process(plane != null)


func _process(delta: float) -> void:
	rebuild()
	_steam(delta)


var _landings: Array = []   ## [Vector3 where a curtain lands, amount] from the last rebuild


func _steam(delta: float) -> void:
	if smoke == null or not is_instance_valid(smoke) or _landings.is_empty():
		_steam_carry = 0.0
		return
	for landing: Array in _landings:
		_steam_carry += STEAM_PER_SECOND * float(landing[1]) * minf(delta, 0.1)
	while _steam_carry >= 1.0:
		_steam_carry -= 1.0
		var landing: Array = _landings[randi() % _landings.size()]
		var along: Vector3 = landing[2]
		var at: Vector3 = (landing[0] as Vector3) + along * randf_range(-0.5, 0.5) + Vector3(randf_range(-0.08, 0.08), 0.03, randf_range(-0.08, 0.08))
		smoke.add_smoke(Vector2.ZERO, STEAM, STEAM_SCALE * randf_range(0.7, 1.2), randf_range(0.6, 0.9), 1, 0.25, 0.0, Vector2.ZERO, at, STEAM_STYLE)


## The falls joined into CHAINS: neighbouring edges on one line, falling the same way, are one curtain (a mouth 1.5 GU wide is one sheet of water, not
## three strips with gaps). Each chain is its edges in order along the line.
static func _chains(falls: Array) -> Array:
	var lines: Dictionary = {}
	for fall: Dictionary in falls:
		var dir: Vector2 = fall["dir"]
		var across: float = (fall["a"] as Vector2).y if dir.y != 0.0 else (fall["a"] as Vector2).x
		var key: String = "%d,%d|%.3f" % [int(dir.x), int(dir.y), across]
		if not lines.has(key):
			lines[key] = []
		(lines[key] as Array).append(fall)
	var out: Array = []
	for key: String in lines:
		var line: Array = lines[key]
		var along_x: bool = (line[0]["dir"] as Vector2).y != 0.0
		line.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return _low(p, along_x) < _low(q, along_x))
		var chain: Array = [line[0]]
		for k in range(1, line.size()):
			if absf(_low(line[k], along_x) - _high(chain.back(), along_x)) < 0.001:
				chain.append(line[k])
			else:
				out.append(chain)
				chain = [line[k]]
		out.append(chain)
	return out


static func _low(fall: Dictionary, along_x: bool) -> float:
	var a: Vector2 = fall["a"]
	var b: Vector2 = fall["b"]
	return minf(a.x, b.x) if along_x else minf(a.y, b.y)


static func _high(fall: Dictionary, along_x: bool) -> float:
	var a: Vector2 = fall["a"]
	var b: Vector2 = fall["b"]
	return maxf(a.x, b.x) if along_x else maxf(a.y, b.y)


## One chain as one curtain: a column of vertices at each edge boundary (its top / bottom the mean of the edges it joins), SEGMENTS rows arcing out along the
## fall, UV.x 0..1 across the whole chain (the shader fades only its two ends), and one splash per edge where the water lands.
func _add_curtain(chain: Array, verts: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var dir: Vector2 = chain[0]["dir"]
	var along_x: bool = dir.y != 0.0
	var columns: Array = []   ## {"p": Vector2, "top": float, "bottom": float, "amount": float}
	for k in range(chain.size() + 1):
		var left: Dictionary = chain[k - 1] if k > 0 else {}
		var right: Dictionary = chain[k] if k < chain.size() else {}
		var near: Array = [left, right].filter(func(f: Dictionary) -> bool: return not f.is_empty())
		var top: float = 0.0
		var bottom: float = 0.0
		var amount: float = 0.0
		for f: Dictionary in near:
			top += _base_y + float(f["top"]) * UNIT
			bottom += _base_y + float(f["bottom"]) * UNIT
			amount += clampf(float(f["flow"]) / FLOW_FULL, 0.15, 1.0)
		var n: float = float(near.size())
		var edge: Dictionary = right if not right.is_empty() else left
		var low_end: bool = not right.is_empty()
		var a: Vector2 = edge["a"]
		var b: Vector2 = edge["b"]
		var p: Vector2 = (a if (a.x < b.x if along_x else a.y < b.y) == low_end else b)
		columns.append({"p": p, "top": top / n, "bottom": bottom / n, "amount": amount / n})
	## the jet is as wide as the water over the lip: an end column whose cell is shallower than the chain's deepest (the sides of a round bore) is pulled in
	## by up to half a cell, so the curtain matches the opening at the level the water stands at, not the whole row of cells
	var deepest: float = 0.0
	for f: Dictionary in chain:
		deepest = maxf(deepest, float(f["depth"]))
	if deepest > 0.0 and columns.size() >= 2:
		var line: Vector2 = Vector2(-dir.y, dir.x).abs()
		var half_cell: float = ((chain[0]["a"] as Vector2).distance_to(chain[0]["b"])) * 0.5
		var first_in: float = half_cell * (1.0 - clampf(float(chain[0]["depth"]) / deepest, 0.0, 1.0))
		var last_in: float = half_cell * (1.0 - clampf(float(chain.back()["depth"]) / deepest, 0.0, 1.0))
		columns[0]["p"] = (columns[0]["p"] as Vector2) + line * first_in
		columns[columns.size() - 1]["p"] = (columns.back()["p"] as Vector2) - line * last_in
	var first: int = verts.size()
	var width: int = columns.size()
	for s in range(-1, SEGMENTS + 1):   ## row -1 lies back over the upstream water: the curtain grows out of it, transparent there
		var u: float = maxf(float(s) / float(SEGMENTS), 0.0)
		for k in range(width):
			var col: Dictionary = columns[k]
			var drop: float = maxf(float(col["top"]) - float(col["bottom"]), 0.0)
			var p: Vector2 = (col["p"] as Vector2) + dir * ((THROW_GU + drop * 0.25) * sqrt(u))
			var y: float = float(col["top"]) - (drop + SINK_GU) * u
			if s < 0:
				p -= dir * LIP_BACK_GU
			verts.append(Vector3(p.x, y, p.y))
			uvs.append(Vector2(float(k) / float(width - 1), -LIP_UV if s < 0 else u))
			colors.append(Color(0.0, 0.0, float(width - 1) * float(chain[0]["a"].distance_to(chain[0]["b"])), float(col["amount"])))   ## B = the curtain's width (GU)
	for s in range(SEGMENTS + 1):
		for k in range(width - 1):
			var i0: int = first + s * width + k
			indices.append_array(PackedInt32Array([i0, i0 + 1, i0 + width + 1, i0, i0 + width + 1, i0 + width]))
	## ONE foam band a curtain (Director, 2026-10-19: per-edge bands ran past the curtain's ends, over the void beside it): from the curtain's first column to its
	## last (the narrowed ends included), where its foot lands, SPLASH_GU across the fall; the steam rises along the same line
	var c0: Dictionary = columns[0]
	var c1: Dictionary = columns[columns.size() - 1]
	var drop0: float = maxf(float(c0["top"]) - float(c0["bottom"]), 0.0)
	var drop1: float = maxf(float(c1["top"]) - float(c1["bottom"]), 0.0)
	var foot0: Vector2 = (c0["p"] as Vector2) + dir * (THROW_GU + drop0 * 0.25)
	var foot1: Vector2 = (c1["p"] as Vector2) + dir * (THROW_GU + drop1 * 0.25)
	var foam_y: float = minf(float(c0["bottom"]), float(c1["bottom"])) + SURFACE_LIFT
	var across: Vector2 = dir * (SPLASH_GU * 0.5)
	var amount_all: float = 0.0
	for col: Dictionary in columns:
		amount_all += float(col["amount"])
	amount_all /= float(columns.size())
	var s0: int = verts.size()
	for corner: Array in [[foot0, -1.0, Vector2(0, 0)], [foot1, -1.0, Vector2(1, 0)], [foot1, 1.0, Vector2(1, 1)], [foot0, 1.0, Vector2(0, 1)]]:
		var at: Vector2 = (corner[0] as Vector2) + across * float(corner[1])
		verts.append(Vector3(at.x, foam_y, at.y))
		uvs.append(corner[2])
		colors.append(Color(0.0, 1.0, (foot0.distance_to(foot1)), amount_all))   ## B = the band's length (GU): the shader keeps the churn's scale
	indices.append_array(PackedInt32Array([s0, s0 + 1, s0 + 2, s0, s0 + 2, s0 + 3]))
	var mid: Vector2 = (foot0 + foot1) * 0.5
	var span: Vector2 = foot1 - foot0
	_landings.append([Vector3(mid.x, foam_y, mid.y), amount_all, Vector3(span.x, 0.0, span.y)])


func rebuild() -> void:
	if plane == null:
		return
	var falls: Array = plane.falls()
	if falls.is_empty() and count == 0:
		return
	count = falls.size()
	_landings.clear()
	if falls.is_empty():
		mesh = null
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for chain: Array in _chains(falls):
		_add_curtain(chain, verts, uvs, colors, indices)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = new_mesh
