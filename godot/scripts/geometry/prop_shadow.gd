## PropShadow — a prop's contact shadow, built from its voxels (PROPS_TIER4_PLAN P6, `ACTOR` D68).
##
## THE SHAPE comes from the prop's own voxel set (the same kind of data `PropVoxelizer` gives a mesh prop and the store gives a voxel
## prop), so a table casts a tabletop and four thin legs, a crate a block, a pile a small heap. Each vertical run of voxels in a column is
## swept along the key light onto the floor (a parallelogram), rasterised into a small image (`TEXELS_PER_VOXEL` per voxel), blurred a
## hair for a soft edge, and drawn as ONE flat quad with `prop_shadow3d.gdshader`. No shadow maps, no per-frame work: the image is built
## when a prop appears and again only when its voxels change (a blast or a shot), and a prop that is gone takes its shadow with it.
##
## Coordinates are ABSOLUTE board voxels (x, y = UP, z), the same lattice as everything else: world = voxel / 8.
class_name PropShadow

const TEXELS_PER_VOXEL: int = 2
const PAD_VOXELS: int = 2
## The board's key light, the direction the face shader's `key` term uses (`prop_mesh3d.gdshader`, `Board3DLive`): shadows fall away from it.
const KEY_DIR := Vector3(-0.45, 0.8, 0.4)
const SHADER_PATH := "res://godot/shaders/prop_contact_shadow3d.gdshader"
## How far above the floor the quad floats, in world units (a hair: enough not to fight the floor's depth).
const LIFT: float = 0.012

static var _shader: Shader = null


## Where one voxel of height throws the shadow on the floor, in voxels (x, z).
static func shift_per_voxel() -> Vector2:
	var k: Vector3 = KEY_DIR.normalized()
	return Vector2(-k.x, -k.z) / k.y


## `cells`: Array of Vector3i (x, y = UP level above the floor, z) in absolute board voxels; `floor_y` the floor's world height.
## Returns a MeshInstance3D holding the quad, or null when there is nothing to shade.
static func make(cells: Array, floor_y: float) -> MeshInstance3D:
	var built: Dictionary = build_image(cells)
	if built.is_empty():
		return null
	var image: Image = built["image"]
	var origin: Vector2 = built["origin"]   ## voxels (x, z) of the image's top-left texel corner
	var size: Vector2 = built["size"]       ## voxels
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var x0: float = origin.x * unit
	var z0: float = origin.y * unit
	var x1: float = (origin.x + size.x) * unit
	var z1: float = (origin.y + size.y) * unit
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _shader == null:
		_shader = load(SHADER_PATH)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("shadow", ImageTexture.create_from_image(image))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(0.0, floor_y + LIFT, 0.0)
	return node


## The shadow image of a voxel set: {"image": Image (L8), "origin": Vector2, "size": Vector2} or {} when `cells` is empty.
static func build_image(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	var shift: Vector2 = shift_per_voxel()
	## Vertical runs per (x, z) column: the shadow of a run is its footprint swept from the run's bottom to its top.
	var heights: Dictionary = {}   ## Vector2i -> sorted Array of y
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for c: Vector3i in cells:
		var col := Vector2i(c.x, c.z)
		if not heights.has(col):
			heights[col] = []
		(heights[col] as Array).append(c.y)
	var runs: Array = []   ## [x, z, y_bottom, y_top_exclusive]
	for col: Vector2i in heights:
		var ys: Array = heights[col]
		ys.sort()
		var start: int = int(ys[0])
		var prev: int = start
		for i in range(1, ys.size()):
			if int(ys[i]) != prev + 1:
				runs.append([col.x, col.y, start, prev + 1])
				start = int(ys[i])
			prev = int(ys[i])
		runs.append([col.x, col.y, start, prev + 1])
	for r: Array in runs:
		for t in [float(r[2]), float(r[3])]:
			lo.x = minf(lo.x, float(r[0]) + shift.x * t)
			hi.x = maxf(hi.x, float(r[0]) + 1.0 + shift.x * t)
			lo.y = minf(lo.y, float(r[1]) + shift.y * t)
			hi.y = maxf(hi.y, float(r[1]) + 1.0 + shift.y * t)
	lo -= Vector2.ONE * PAD_VOXELS
	hi += Vector2.ONE * PAD_VOXELS
	var tp: int = TEXELS_PER_VOXEL
	var w: int = int(ceil((hi.x - lo.x) * float(tp)))
	var h: int = int(ceil((hi.y - lo.y) * float(tp)))
	var data := PackedByteArray()
	data.resize(w * h)
	for r: Array in runs:
		var height: float = float(int(r[3]) - int(r[2]))
		## Step the swept footprint by less than a texel so the parallelogram has no gaps.
		var length: float = height * shift.length() * float(tp)
		var steps: int = maxi(1, int(ceil(length * 2.0)))
		for s in range(steps + 1):
			var t: float = float(r[2]) + height * float(s) / float(steps)
			var px: float = (float(r[0]) + shift.x * t - lo.x) * float(tp)
			var pz: float = (float(r[1]) + shift.y * t - lo.y) * float(tp)
			for dz in range(tp):
				for dx in range(tp):
					var ix: int = int(floor(px)) + dx
					var iz: int = int(floor(pz)) + dz
					if ix >= 0 and ix < w and iz >= 0 and iz < h:
						data[iz * w + ix] = 255
	return {"image": _blur(Image.create_from_data(w, h, false, Image.FORMAT_L8, data)), "origin": lo, "size": Vector2(w, h) / float(tp)}


## A 3x3 box blur: a soft edge instead of a stamped one (the texture is also filtered linearly).
static func _blur(src: Image) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var inp: PackedByteArray = src.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	for y in range(h):
		for x in range(w):
			var sum: int = 0
			var n: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and xx < w and yy >= 0 and yy < h:
						sum += inp[yy * w + xx]
						n += 1
			out[y * w + x] = int(float(sum) / float(maxi(n, 1)))
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, out)
