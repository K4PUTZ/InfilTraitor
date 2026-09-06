extends RefCounted
class_name ShardField

## GLASS G6b-1 / G-D38 + G-D44 — MANY TEXTURED SHARDS, IN ONE DRAW CALL.
##
## The falling rain a shattered pane throws (G-D43): a crowd of small angular
## pieces, each one of `GlassShardShapes`' five members with its own flip, scale
## and rotation. `CircleField`'s shape exactly — `attach` / `begin` / `push` /
## `flush` / `clear` — because P7b's finding is the reason both exist and a second
## idiom for the same job would only be a second place to get it wrong.
##
## ⚠️ **THE COST IS PER-VERTEX SUBMISSION, NOT PER-PARTICLE** (PERF §8.8, measured:
## 1 325 `draw_circle` commands at 10 us each against 46 `draw_line` at 0.4 us).
## A shard is a QUAD — four vertices — so 2 600 of them are cheaper to submit than
## a few dozen filled circles were, and the whole population ships as one transform
## and one colour each.
##
## ⚠️ **WHAT THIS DOES NOT REDUCE IS OVERDRAW.** The same pixels are covered by the
## same blend. Fewer or smaller shards is a LOOK decision and stays the Director's.
##
## ── HOW A MEMBER IS CHOSEN ──────────────────────────────────────────────────
##
## `use_custom_data` carries the atlas cell index and `glass_shard_field.gdshader`
## slices the texture's U by it. So five shapes cost one texture and one draw call,
## and **flip, flop, scale and rotation are all free** — they are the instance's
## own `Transform2D`, which was going to be uploaded either way.

## 8 floats of TRANSFORM_2D + 4 of colour + 4 of custom data. ⚠️ `use_custom_data`
## is what makes this 16 and not `CircleField`'s 12; a buffer written at the wrong
## stride is accepted by `MultiMesh` and draws garbage.
const FLOATS_PER_INSTANCE: int = 16

const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const FIELD_SHADER_PATH: String = "res://godot/shaders/glass_shard_field.gdshader"

## The atlas is built once per run and shared by every field: it is five polygons
## rasterised at 64 px, identical for every pane on every map.
static var _atlas: ImageTexture = null

var _node: MultiMeshInstance2D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0


## The shared atlas texture, built on first use.
static func atlas_texture() -> ImageTexture:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(ShardShapes.atlas_image())
	return _atlas


## Build the instance node under `parent`.
func attach(parent: Node2D, behind: bool = false) -> void:
	if _node != null:
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _build_unit_quad()
	## ⛔ **WITHOUT THIS, EVERY INSTANCE FAR FROM THE NODE ORIGIN IS CULLED, AND
	## NOTHING SAYS SO.** Godot derives a MultiMesh's visibility bounds from its
	## BASE MESH, which here is a quad of half-extent 0.5; the per-instance
	## transforms carry the real positions and are not in that box. P7b shipped
	## this defect and lost whole plumes to it — 0 magenta pixels against 4 055
	## once the box was set — while its own 0-pixel gate passed, because that gate
	## draws near the origin and could never reach the failure.
	##
	## A shard rain is exactly the population that breaks it: a pane's shards land
	## across several GUs, hundreds of pixels from wherever the field's node sits.
	_mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1.0), Vector3(2e6, 2e6, 2.0))
	_node = MultiMeshInstance2D.new()
	_node.name = "ShardFieldMM"
	_node.multimesh = _mm
	_node.texture = atlas_texture()
	## ⚠️ NEAREST, not linear. These are 10-20 px pieces whose whole read is a hard
	## angular EDGE; linear filtering at that size turns the silhouette into a
	## gradient and the shard into a smudge. The atlas is supersampled at build
	## time, which is where the antialiasing belongs.
	_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load(FIELD_SHADER_PATH) as Shader
	if mat.shader == null:
		## B6 — a missing shader is a loud failure, not an invisible rain.
		push_error("[ShardField] %s failed to load — no shards will draw" % FIELD_SHADER_PATH)
	else:
		mat.set_shader_parameter("atlas_cells", float(ShardShapes.ids().size()))
	_node.material = mat
	_node.show_behind_parent = behind
	parent.add_child(_node)


## The unit quad, centred, with UVs 0..1. The shader slices U by the instance's
## atlas cell, so the mesh knows nothing about how many members there are.
static func _build_unit_quad() -> ArrayMesh:
	var verts := PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5),
		Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Start a frame. `capacity` is an upper bound on the pushes that follow.
func begin(capacity: int) -> void:
	_count = 0
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## One shard.
##
## `size_px` is the piece's LONG axis on screen, which is G-D44's band in pixels:
## a voxel face is `VOXEL_STEP_PX` tall, so the band is roughly 10 to 20.
## `flip` / `flop` mirror it across each axis — a NEGATIVE scale, free, and the
## reason five members cover far more than five silhouettes.
##
## No `Transform2D` object and no allocation: the sixteen floats go straight into
## the buffer in the order `MultiMesh` reads them — row 0 is
## (basis.x.x, basis.y.x, 0, origin.x), row 1 is (basis.x.y, basis.y.y, 0,
## origin.y), then RGBA, then the custom vec4 whose X the shader reads.
func push(pos: Vector2, size_px: float, rot: float, shape_index: int,
		color: Color, flip: bool = false, flop: bool = false) -> void:
	var o: int = _count * FLOATS_PER_INSTANCE
	var sx: float = -size_px if flip else size_px
	var sy: float = -size_px if flop else size_px
	var c: float = cos(rot)
	var s: float = sin(rot)
	_buf[o] = c * sx
	_buf[o + 1] = -s * sy
	_buf[o + 2] = 0.0
	_buf[o + 3] = pos.x
	_buf[o + 4] = s * sx
	_buf[o + 5] = c * sy
	_buf[o + 6] = 0.0
	_buf[o + 7] = pos.y
	_buf[o + 8] = color.r
	_buf[o + 9] = color.g
	_buf[o + 10] = color.b
	_buf[o + 11] = color.a
	_buf[o + 12] = float(shape_index)
	_buf[o + 13] = 0.0
	_buf[o + 14] = 0.0
	_buf[o + 15] = 0.0
	_count += 1


## Publish the frame. ONE engine call for every shard pushed.
func flush() -> void:
	if _mm == null:
		return
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


## How many shards the last `flush()` published — the board, not the counter.
func live_count() -> int:
	return 0 if _mm == null else _mm.instance_count


## Drop everything on screen.
func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0
