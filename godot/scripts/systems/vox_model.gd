## VoxModel — a MagicaVoxel `.vox` file, parsed. PURE data in, data out; every read is bounds-checked and every count is capped,
## so a truncated, hostile or simply odd file ends in `error`, never a crash, a hang or a huge allocation (PROP_PIPELINE_PLAN PP4, D69).
##
## The format (little endian): "VOX " + version, then a MAIN chunk whose children are chunks `id(4) content_size(4) children_size(4)`
## + content + children. We read SIZE (x, y, z), XYZI (n, then n x (x, y, z, colour index)) and RGBA (256 colours); everything else
## (the scene graph of newer files, materials, layers) is skipped. ONLY THE FIRST MODEL of a file is read. Axes are MagicaVoxel's:
## z is UP. A colour index is 1..255 and maps to `palette[index - 1]`.
class_name VoxModel
extends RefCounted

const MAX_DIM: int = 256
const MAX_VOXELS: int = 200000

var size: Vector3i = Vector3i.ZERO
## One entry per voxel: Vector4i(x, y, z, colour index 1..255).
var voxels: Array[Vector4i] = []
## 256 entries; `palette[i - 1]` is the colour of index i.
var palette: PackedColorArray = PackedColorArray()
var error: String = ""


static func parse(bytes: PackedByteArray) -> VoxModel:
	var m := VoxModel.new()
	m._parse(bytes)
	return m


func is_ok() -> bool:
	return error == "" and size.x > 0 and size.y > 0 and size.z > 0


func _parse(b: PackedByteArray) -> void:
	if b.size() < 20 or b.slice(0, 4).get_string_from_ascii() != "VOX ":
		error = "not a .vox file"
		return
	var off: int = 8
	## The MAIN chunk: its own content is empty, its children are the file.
	if b.slice(off, off + 4).get_string_from_ascii() != "MAIN":
		error = "no MAIN chunk"
		return
	var main_content: int = _u32(b, off + 4)
	var main_children: int = _u32(b, off + 8)
	if main_content < 0 or main_children < 0:
		error = "truncated MAIN chunk"
		return
	off += 12 + main_content
	var end: int = mini(off + main_children, b.size())
	var have_size: bool = false
	var have_voxels: bool = false
	palette = _default_palette()
	var guard: int = 0
	while off + 12 <= end and guard < 100000:
		guard += 1
		var id: String = b.slice(off, off + 4).get_string_from_ascii()
		var n: int = _u32(b, off + 4)
		var m: int = _u32(b, off + 8)
		if n < 0 or m < 0 or off + 12 + n > b.size():
			error = "a chunk runs past the end of the file"
			return
		var body: int = off + 12
		if id == "SIZE" and not have_size:
			if n < 12:
				error = "short SIZE chunk"
				return
			size = Vector3i(_i32(b, body), _i32(b, body + 4), _i32(b, body + 8))
			if size.x <= 0 or size.y <= 0 or size.z <= 0 or size.x > MAX_DIM or size.y > MAX_DIM or size.z > MAX_DIM:
				error = "model size %s is outside 1..%d" % [size, MAX_DIM]
				return
			have_size = true
		elif id == "XYZI" and have_size and not have_voxels:
			var count: int = _u32(b, body)
			if count < 0 or count > MAX_VOXELS or 4 + count * 4 > n:
				error = "XYZI claims %d voxels (cap %d, chunk holds %d)" % [count, MAX_VOXELS, int((n - 4) / 4.0)]
				return
			for i in range(count):
				var o: int = body + 4 + i * 4
				var v := Vector4i(b[o], b[o + 1], b[o + 2], b[o + 3])
				if v.x >= size.x or v.y >= size.y or v.z >= size.z or v.w == 0:
					continue   ## a voxel outside the declared box, or colour 0 (empty): dropped
				voxels.append(v)
			have_voxels = true
		elif id == "RGBA" and n >= 1024:
			var colours := PackedColorArray()
			for i in range(256):
				var o2: int = body + i * 4
				colours.append(Color8(b[o2], b[o2 + 1], b[o2 + 2], b[o2 + 3]))
			palette = colours
		off += 12 + n + m
	if not have_size or not have_voxels:
		error = "no model (SIZE + XYZI) in the file"


static func _u32(b: PackedByteArray, o: int) -> int:
	if o < 0 or o + 4 > b.size():
		return -1
	return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


static func _i32(b: PackedByteArray, o: int) -> int:
	var v: int = _u32(b, o)
	return v - 0x100000000 if v >= 0x80000000 else v


## A neutral grey ramp when the file has no RGBA chunk (MagicaVoxel's own default palette is a rainbow we would not want).
static func _default_palette() -> PackedColorArray:
	var p := PackedColorArray()
	for i in range(256):
		var g: float = float(i) / 255.0
		p.append(Color(g, g, g, 1.0))
	return p


## A `.vox` file's bytes from cells: the writer the tests and tools use. `cells`: Array of Vector4i(x, y, z, colour index), `palette`
## up to 256 colours (missing ones are white).
static func write(dim: Vector3i, cells: Array, colours: PackedColorArray) -> PackedByteArray:
	var size_chunk := PackedByteArray()
	size_chunk.append_array(_le32(dim.x))
	size_chunk.append_array(_le32(dim.y))
	size_chunk.append_array(_le32(dim.z))
	var xyzi := PackedByteArray()
	xyzi.append_array(_le32(cells.size()))
	for c: Vector4i in cells:
		xyzi.append(c.x)
		xyzi.append(c.y)
		xyzi.append(c.z)
		xyzi.append(c.w)
	var rgba := PackedByteArray()
	for i in range(256):
		var col: Color = colours[i] if i < colours.size() else Color.WHITE
		rgba.append(col.r8)
		rgba.append(col.g8)
		rgba.append(col.b8)
		rgba.append(col.a8)
	var children := PackedByteArray()
	children.append_array(_chunk("SIZE", size_chunk))
	children.append_array(_chunk("XYZI", xyzi))
	children.append_array(_chunk("RGBA", rgba))
	var out := PackedByteArray()
	out.append_array("VOX ".to_ascii_buffer())
	out.append_array(_le32(150))
	out.append_array("MAIN".to_ascii_buffer())
	out.append_array(_le32(0))
	out.append_array(_le32(children.size()))
	out.append_array(children)
	return out


static func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(id.to_ascii_buffer())
	out.append_array(_le32(content.size()))
	out.append_array(_le32(0))
	out.append_array(content)
	return out


static func _le32(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, v & 0xFFFFFFFF)
	return out
