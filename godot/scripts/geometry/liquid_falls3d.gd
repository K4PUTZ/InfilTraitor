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
const SPLASH_GU: float = 0.42          ## the foam ring's size
const FLOW_FULL: float = 0.12          ## the flow (voxels a round) that draws a full curtain; less is thinner
const SURFACE_LIFT: float = 0.01       ## the splash just over the sheet

var plane: RefCounted = null
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
	if params.has("light_color"):
		material.set_shader_parameter("light_color", params["light_color"])
	material.set_shader_parameter("time_scale", float(params.get("time_scale", 1.0)))
	material_override = material
	set_process(plane != null)


func _process(_delta: float) -> void:
	rebuild()


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
	var first: int = verts.size()
	var width: int = columns.size()
	for s in range(SEGMENTS + 1):
		var u: float = float(s) / float(SEGMENTS)
		for k in range(width):
			var col: Dictionary = columns[k]
			var drop: float = maxf(float(col["top"]) - float(col["bottom"]), 0.0)
			var p: Vector2 = (col["p"] as Vector2) + dir * ((THROW_GU + drop * 0.25) * sqrt(u))
			verts.append(Vector3(p.x, float(col["top"]) - drop * u, p.y))
			uvs.append(Vector2(float(k) / float(width - 1), u))
			colors.append(Color(0.0, 0.0, float(width - 1) * float(chain[0]["a"].distance_to(chain[0]["b"])), float(col["amount"])))   ## B = the curtain's width (GU)
	for s in range(SEGMENTS):
		for k in range(width - 1):
			var i0: int = first + s * width + k
			indices.append_array(PackedInt32Array([i0, i0 + 1, i0 + width + 1, i0, i0 + width + 1, i0 + width]))
	for fall: Dictionary in chain:
		var top_y: float = _base_y + float(fall["top"]) * UNIT
		var bottom_y: float = _base_y + float(fall["bottom"]) * UNIT
		var land: Vector2 = ((fall["a"] as Vector2) + (fall["b"] as Vector2)) * 0.5 + dir * (THROW_GU + maxf(top_y - bottom_y, 0.0) * 0.25)
		var half: float = SPLASH_GU * 0.5
		var s0: int = verts.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			verts.append(Vector3(land.x + corner.x * half, bottom_y + SURFACE_LIFT, land.y + corner.y * half))
			uvs.append((corner + Vector2.ONE) * 0.5)
			colors.append(Color(0.0, 1.0, 0.0, clampf(float(fall["flow"]) / FLOW_FULL, 0.15, 1.0)))
		indices.append_array(PackedInt32Array([s0, s0 + 1, s0 + 2, s0, s0 + 2, s0 + 3]))


func rebuild() -> void:
	if plane == null:
		return
	var falls: Array = plane.falls()
	if falls.is_empty() and count == 0:
		return
	count = falls.size()
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
