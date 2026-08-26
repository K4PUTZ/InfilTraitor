extends RefCounted
class_name CircleField

## PERF-P7b — MANY ADDITIVE CIRCLES, IN ONE DRAW CALL.
##
## `PERFORMANCE_MASTER_PLAN` §8.8 measured the VFX overlays' `_draw()` at 95.1%
## canvas-command SUBMISSION and 4.9% GDScript loop, and §12.10 split that by
## population on the P3 build:
##
##   SmokeSpark/puffs  13.26 ms/frame · 1 325 cmd/frame · 68.9%   draw_circle
##   EmberOverlay       4.61 ms/frame ·   450 cmd/frame · 24.0%   draw_circle x2
##   SmokeSpark/sparks  0.02 ms/frame ·    46 cmd/frame ·  0.1%   draw_line
##
## ⚠️ **§8.6's task order says "ember first — the largest population". It is not.**
## The smoke PUFFS are, by three to one, and both they and the ember draw the same
## primitive — which is why this is one shared helper rather than the per-overlay
## rewrite the plan sketched. Together they are 92.9% of the cost.
##
## **The cost is per-VERTEX, not per-command**, and the sparks are the control that
## says so: 46 `draw_line` commands cost 0.4 us each while 1 325 `draw_circle`
## commands cost 10 us each. A filled circle is a tessellated polygon; a line is
## two vertices. So the fix is to stop rebuilding those polygons on the CPU every
## frame, which is exactly what a `MultiMesh` is for: the circle is uploaded ONCE
## as a mesh, and a frame ships only a transform and a colour per instance.
##
## ⚠️ **THIS DOES NOT REDUCE OVERDRAW.** The same circles cover the same pixels
## with the same additive blend, so the GPU fill is unchanged — §8.8b's claim that
## MultiMesh "also removes" the rasterization is wrong, and §12.10 corrects it.
## What this removes is the CPU submission, measured at 69% of the VFX frame-time
## delta. Fewer or smaller particles is a LOOK decision and remains the Director's.
##
## SEGMENTS is 64 to match Godot's own `canvas_item_add_circle` tessellation, so
## the conversion has a chance of being pixel-identical rather than merely close —
## §8.6's gate asks for 0 differing pixels. It is a `var` (Rule 1: never `const`).

## Godot's own filled-circle tessellation. Lowering this is a cheaper picture, not
## a cheaper CPU — the mesh is built once, so segment count costs nothing per frame.
static var segments: int = 64

## 8 floats of TRANSFORM_2D + 4 floats of colour, the layout `MultiMesh.buffer`
## expects when `use_colors` is on and the format is 2D.
const FLOATS_PER_INSTANCE: int = 12

var _node: MultiMeshInstance2D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0


## Build the instance node under `parent`, inheriting nothing: the caller's own
## `material` (additive, on every overlay that uses this) does NOT propagate to a
## child CanvasItem, so the blend mode is set here from the same enum rather than
## assumed. `z_index` 0 keeps it exactly where the parent's own `_draw()` output
## sat in the sibling order.
func attach(parent: Node2D, blend: CanvasItemMaterial.BlendMode,
		behind: bool = false) -> void:
	if _node != null:
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.mesh = _build_unit_circle()
	_node = MultiMeshInstance2D.new()
	_node.name = "CircleFieldMM"
	_node.multimesh = _mm
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = blend
	_node.material = mat
	## ⚠️ ORDER IS PART OF THE PICTURE under a non-additive blend. A child
	## CanvasItem draws AFTER its parent's own `_draw()`, so moving one population
	## into a child would silently lift it above the ones left behind. Under ADD
	## the compositing is order-independent and this does not matter; under MIX it
	## does, and `show_behind_parent` is the property that puts it back.
	_node.show_behind_parent = behind
	parent.add_child(_node)


## A unit circle (radius 1) as a triangle fan, so an instance's scale IS its
## radius. Built once per overlay and never touched again.
##
## The winding and the starting angle both matter for the pixel gate: Godot's
## `draw_circle` walks from angle 0 counter-clockwise, and a mesh that starts
## elsewhere rasterizes the same shape from different triangles — same coverage,
## but not necessarily the same pixels on the boundary.
static func _build_unit_circle() -> ArrayMesh:
	var n: int = maxi(segments, 3)
	var verts := PackedVector2Array()
	verts.resize(n * 3)
	var i: int = 0
	for s in range(n):
		var a0: float = TAU * float(s) / float(n)
		var a1: float = TAU * float(s + 1) / float(n)
		verts[i] = Vector2.ZERO
		verts[i + 1] = Vector2(cos(a0), sin(a0))
		verts[i + 2] = Vector2(cos(a1), sin(a1))
		i += 3
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Start a frame. `capacity` is an upper bound on how many circles will follow —
## the buffer is resized to it once instead of grown per push.
func begin(capacity: int) -> void:
	_count = 0
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## One circle. No allocation, no `Transform2D` object — the eight floats are
## written straight into the buffer in the order `MultiMesh` reads them:
## row 0 is (basis.x.x, basis.y.x, 0, origin.x), row 1 is (basis.x.y, basis.y.y,
## 0, origin.y). A circle needs no rotation and no skew, so the off-diagonal
## terms are zero and the diagonal is the radius.
func push(pos: Vector2, radius: float, color: Color) -> void:
	var o: int = _count * FLOATS_PER_INSTANCE
	_buf[o] = radius
	_buf[o + 1] = 0.0
	_buf[o + 2] = 0.0
	_buf[o + 3] = pos.x
	_buf[o + 4] = 0.0
	_buf[o + 5] = radius
	_buf[o + 6] = 0.0
	_buf[o + 7] = pos.y
	_buf[o + 8] = color.r
	_buf[o + 9] = color.g
	_buf[o + 10] = color.b
	_buf[o + 11] = color.a
	_count += 1


## Publish the frame. ONE engine call for every circle pushed.
##
## `instance_count` is set BEFORE the buffer, and the buffer is sliced to exactly
## the live instances: `MultiMesh` rejects a buffer whose length disagrees with
## `instance_count * FLOATS_PER_INSTANCE`, and the buffer is deliberately kept
## larger than the frame needs so it never reallocates.
func flush() -> void:
	if _mm == null:
		return
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


## Drop everything on screen (map load, overlay clear).
func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0
